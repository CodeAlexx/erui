import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/editor_models.dart';
import '../providers/editor_provider.dart';

/// Playback state for the video editor
enum PlaybackStatus {
  /// Not playing, player may not have media loaded
  stopped,

  /// Actively playing media
  playing,

  /// Playback paused, can resume
  paused,

  /// Buffering/loading media
  buffering,
}

/// Information about the currently playing clip
class ActiveClipInfo {
  /// The clip being played
  final EditorClip clip;

  /// Position within the source media
  final Duration sourcePosition;

  /// Position on the timeline
  final EditorTime timelinePosition;

  const ActiveClipInfo({
    required this.clip,
    required this.sourcePosition,
    required this.timelinePosition,
  });
}

/// Playback controller that manages video playback using media_kit
/// Handles synchronization between the player and editor playhead
class PlaybackController {
  static const String _tag = 'PlaybackController';

  /// The media_kit player instance
  final Player _player;

  /// The video controller for rendering video frames
  late final VideoController _videoController;

  /// Reference to read Riverpod providers
  final Ref _ref;

  /// Current playback status
  PlaybackStatus _status = PlaybackStatus.stopped;

  /// Current playback rate (1.0 = normal speed)
  double _playbackRate = 1.0;

  /// Currently active clip being played
  EditorClip? _activeClip;

  /// Timer for position sync during playback
  Timer? _positionSyncTimer;

  /// Stream controller for position updates
  final StreamController<EditorTime> _positionController =
      StreamController<EditorTime>.broadcast();

  /// Stream controller for status updates
  final StreamController<PlaybackStatus> _statusController =
      StreamController<PlaybackStatus>.broadcast();

  /// Stream controller for active clip updates
  final StreamController<ActiveClipInfo?> _activeClipController =
      StreamController<ActiveClipInfo?>.broadcast();

  /// Subscriptions to player streams
  final List<StreamSubscription> _subscriptions = [];

  /// Whether the controller has been disposed
  bool _disposed = false;

  PlaybackController(this._ref) : _player = Player() {
    _videoController = VideoController(_player);
    _setupPlayerListeners();
  }

  // ============================================================
  // Public Getters
  // ============================================================

  /// Current playback status
  PlaybackStatus get status => _status;

  /// Whether playback is currently active
  bool get isPlaying => _status == PlaybackStatus.playing;

  /// Whether playback is paused
  bool get isPaused => _status == PlaybackStatus.paused;

  /// Whether playback is stopped
  bool get isStopped => _status == PlaybackStatus.stopped;

  /// Current playback rate
  double get playbackRate => _playbackRate;

  /// Currently active clip
  EditorClip? get activeClip => _activeClip;

  /// Stream of position updates (emits timeline position)
  Stream<EditorTime> get positionStream => _positionController.stream;

  /// Stream of status updates
  Stream<PlaybackStatus> get statusStream => _statusController.stream;

  /// Stream of active clip info updates
  Stream<ActiveClipInfo?> get activeClipStream => _activeClipController.stream;

  /// The underlying media_kit player (for video display)
  Player get player => _player;

  /// The video controller for rendering
  VideoController get videoController => _videoController;

  // ============================================================
  // Playback Control Methods
  // ============================================================

  /// Start playback from the current playhead position
  Future<void> play() async {
    if (_disposed) return;

    _log('play() called');

    final editorState = _ref.read(editorProjectProvider);
    final playheadPosition = editorState.project.playheadPosition;

    // Find the clip at the current playhead position
    final clipToPlay = _findClipAtPosition(editorState.project, playheadPosition);

    if (clipToPlay == null) {
      _log('No clip found at playhead position');
      // Try to find the next clip
      final nextClip = _findNextClip(editorState.project, playheadPosition);
      if (nextClip != null) {
        // Seek to the next clip and play
        _ref.read(editorProjectProvider.notifier).setPlayhead(nextClip.timelineStart);
        await _playClip(nextClip, nextClip.timelineStart);
      } else {
        _log('No clips available for playback');
        _updateStatus(PlaybackStatus.stopped);
      }
      return;
    }

    await _playClip(clipToPlay, playheadPosition);
  }

  /// Pause playback
  Future<void> pause() async {
    if (_disposed) return;

    _log('pause() called');

    await _player.pause();
    _updateStatus(PlaybackStatus.paused);
    _stopPositionSync();
  }

  /// Stop playback and reset to start
  Future<void> stop() async {
    if (_disposed) return;

    _log('stop() called');

    await _player.stop();
    _activeClip = null;
    _activeClipController.add(null);
    _updateStatus(PlaybackStatus.stopped);
    _stopPositionSync();

    // Reset playhead to in-point or start
    final editorState = _ref.read(editorProjectProvider);
    final resetPosition = editorState.project.inPoint ?? const EditorTime.zero();
    _ref.read(editorProjectProvider.notifier).setPlayhead(resetPosition);
  }

  /// Toggle between play and pause
  Future<void> togglePlayback() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Seek to a specific timeline position
  Future<void> seekTo(EditorTime position) async {
    if (_disposed) return;

    _log('seekTo() called: $position');

    // Update the editor playhead
    _ref.read(editorProjectProvider.notifier).setPlayhead(position);

    // Find clip at new position
    final editorState = _ref.read(editorProjectProvider);
    final clip = _findClipAtPosition(editorState.project, position);

    if (clip != null && clip.sourcePath != null) {
      // Calculate position within source
      final sourceOffset = position - clip.timelineStart;
      final sourcePosition = clip.sourceStart + sourceOffset;

      // If it's a different clip, open it
      if (_activeClip?.id != clip.id) {
        await _openClip(clip);
      }

      // Seek within the player
      await _player.seek(Duration(microseconds: sourcePosition.microseconds));

      _activeClip = clip;
      _activeClipController.add(ActiveClipInfo(
        clip: clip,
        sourcePosition: Duration(microseconds: sourcePosition.microseconds),
        timelinePosition: position,
      ));
    } else {
      // No clip at position, just update playhead
      _activeClip = null;
      _activeClipController.add(null);
    }
  }

  /// Set the playback rate (speed)
  /// Supports values like 0.5, 1.0, 2.0, etc.
  /// For J/K/L shuttle control: negative values can indicate reverse
  Future<void> setPlaybackRate(double rate) async {
    if (_disposed) return;

    _log('setPlaybackRate() called: $rate');

    // Clamp to reasonable range
    final clampedRate = rate.clamp(0.1, 4.0);
    _playbackRate = clampedRate;

    await _player.setRate(clampedRate);
  }

  /// Step forward or backward by a number of frames
  /// Positive frames = forward, negative = backward
  Future<void> stepFrame(int frames) async {
    if (_disposed) return;

    _log('stepFrame() called: $frames frames');

    // Pause if playing
    if (isPlaying) {
      await pause();
    }

    // Get frame rate from project settings
    final editorState = _ref.read(editorProjectProvider);
    final frameRate = editorState.project.settings.frameRate;

    // Calculate time delta
    final frameDuration = EditorTime.fromFrames(frames.abs(), frameRate);
    final currentPosition = editorState.project.playheadPosition;

    EditorTime newPosition;
    if (frames >= 0) {
      newPosition = currentPosition + frameDuration;
    } else {
      newPosition = currentPosition - frameDuration;
      // Clamp to zero
      if (newPosition.microseconds < 0) {
        newPosition = const EditorTime.zero();
      }
    }

    await seekTo(newPosition);
  }

  /// Increase playback rate (for L key in J/K/L)
  Future<void> increaseSpeed() async {
    double newRate;
    if (_playbackRate < 1.0) {
      newRate = 1.0;
    } else if (_playbackRate < 2.0) {
      newRate = 2.0;
    } else {
      newRate = 4.0;
    }
    await setPlaybackRate(newRate);

    // Start playing if not already
    if (!isPlaying) {
      await play();
    }
  }

  /// Decrease playback rate (for J key in J/K/L)
  /// Note: media_kit doesn't support negative playback, so we simulate by stepping
  Future<void> decreaseSpeed() async {
    double newRate;
    if (_playbackRate > 2.0) {
      newRate = 2.0;
    } else if (_playbackRate > 1.0) {
      newRate = 1.0;
    } else {
      newRate = 0.5;
    }
    await setPlaybackRate(newRate);

    // Start playing if not already
    if (!isPlaying) {
      await play();
    }
  }

  /// Stop/pause (for K key in J/K/L)
  Future<void> stopShuttle() async {
    await pause();
    _playbackRate = 1.0;
  }

  // ============================================================
  // Private Methods
  // ============================================================

  void _log(String message) {
    print('[$_tag] $message');
  }

  void _logError(String message, [Object? error]) {
    print('[$_tag] ERROR: $message${error != null ? ' - $error' : ''}');
  }

  void _setupPlayerListeners() {
    // Listen to player state changes
    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        if (_disposed) return;
        if (playing) {
          _updateStatus(PlaybackStatus.playing);
          _startPositionSync();
        } else if (_status == PlaybackStatus.playing) {
          _updateStatus(PlaybackStatus.paused);
          _stopPositionSync();
        }
      }),
    );

    // Listen to buffering state
    _subscriptions.add(
      _player.stream.buffering.listen((buffering) {
        if (_disposed) return;
        if (buffering) {
          _updateStatus(PlaybackStatus.buffering);
        } else if (_status == PlaybackStatus.buffering) {
          _updateStatus(PlaybackStatus.playing);
        }
      }),
    );

    // Listen to completion
    _subscriptions.add(
      _player.stream.completed.listen((completed) {
        if (_disposed) return;
        if (completed) {
          _onPlaybackCompleted();
        }
      }),
    );

    // Listen to errors
    _subscriptions.add(
      _player.stream.error.listen((error) {
        if (_disposed) return;
        _logError('Player error', error);
      }),
    );
  }

  void _updateStatus(PlaybackStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);

      // Sync with editor provider
      final notifier = _ref.read(editorProjectProvider.notifier);
      switch (newStatus) {
        case PlaybackStatus.playing:
          notifier.play();
          break;
        case PlaybackStatus.paused:
          notifier.pause();
          break;
        case PlaybackStatus.stopped:
          notifier.stop();
          break;
        case PlaybackStatus.buffering:
          // Keep current editor state during buffering
          break;
      }
    }
  }

  Future<void> _playClip(EditorClip clip, EditorTime playheadPosition) async {
    if (clip.sourcePath == null) {
      _logError('Clip has no source path');
      return;
    }

    // Calculate position within source
    final sourceOffset = playheadPosition - clip.timelineStart;
    final sourcePosition = clip.sourceStart + sourceOffset;

    _log('Playing clip: ${clip.name} at source position: $sourcePosition');

    // Open the media if it's a different clip
    if (_activeClip?.id != clip.id) {
      await _openClip(clip);
    }

    // Seek to the correct position
    await _player.seek(Duration(microseconds: sourcePosition.microseconds));

    // Set playback rate
    await _player.setRate(_playbackRate);

    // Start playback
    await _player.play();

    _activeClip = clip;
    _activeClipController.add(ActiveClipInfo(
      clip: clip,
      sourcePosition: Duration(microseconds: sourcePosition.microseconds),
      timelinePosition: playheadPosition,
    ));

    _updateStatus(PlaybackStatus.playing);
    _startPositionSync();
  }

  Future<void> _openClip(EditorClip clip) async {
    if (clip.sourcePath == null) return;

    _log('Opening media: ${clip.sourcePath}');

    await _player.open(Media(clip.sourcePath!), play: false);
  }

  EditorClip? _findClipAtPosition(EditorProject project, EditorTime position) {
    // Look for video clips first, then audio
    for (final track in project.tracks) {
      if (track.type != TrackType.video) continue;
      if (track.isMuted) continue;

      for (final clip in track.clips) {
        if (clip.sourcePath != null && clip.timelineRange.contains(position)) {
          return clip;
        }
      }
    }

    // If no video clip, try audio tracks
    for (final track in project.tracks) {
      if (track.type != TrackType.audio) continue;
      if (track.isMuted) continue;

      for (final clip in track.clips) {
        if (clip.sourcePath != null && clip.timelineRange.contains(position)) {
          return clip;
        }
      }
    }

    return null;
  }

  EditorClip? _findNextClip(EditorProject project, EditorTime afterPosition) {
    EditorClip? nextClip;
    EditorTime? nextStart;

    for (final track in project.tracks) {
      if (track.isMuted) continue;

      for (final clip in track.clips) {
        if (clip.sourcePath == null) continue;
        if (clip.timelineStart <= afterPosition) continue;

        if (nextStart == null || clip.timelineStart < nextStart) {
          nextClip = clip;
          nextStart = clip.timelineStart;
        }
      }
    }

    return nextClip;
  }

  void _startPositionSync() {
    _stopPositionSync();

    // Sync position every ~16ms (60fps)
    _positionSyncTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _syncPosition(),
    );
  }

  void _stopPositionSync() {
    _positionSyncTimer?.cancel();
    _positionSyncTimer = null;
  }

  void _syncPosition() {
    if (_disposed || _activeClip == null) return;

    final playerPosition = _player.state.position;
    final clip = _activeClip!;

    // Calculate timeline position from player position
    final sourceOffset = EditorTime(playerPosition.inMicroseconds) - clip.sourceStart;
    final timelinePosition = clip.timelineStart + sourceOffset;

    // Check if we've reached the end of the clip
    if (timelinePosition >= clip.timelineEnd) {
      _onClipEnded();
      return;
    }

    // Emit position update
    _positionController.add(timelinePosition);

    // Update editor playhead
    _ref.read(editorProjectProvider.notifier).setPlayhead(timelinePosition);

    // Update active clip info
    _activeClipController.add(ActiveClipInfo(
      clip: clip,
      sourcePosition: playerPosition,
      timelinePosition: timelinePosition,
    ));
  }

  void _onClipEnded() {
    _log('Clip ended, looking for next clip');

    final clip = _activeClip;
    if (clip == null) return;

    final editorState = _ref.read(editorProjectProvider);
    final nextClip = _findNextClip(editorState.project, clip.timelineEnd);

    if (nextClip != null) {
      // Seek to next clip
      _ref.read(editorProjectProvider.notifier).setPlayhead(nextClip.timelineStart);
      _playClip(nextClip, nextClip.timelineStart);
    } else {
      // No more clips, stop playback
      _log('No more clips, stopping playback');
      stop();
    }
  }

  void _onPlaybackCompleted() {
    _log('Player playback completed');
    _onClipEnded();
  }

  /// Dispose the controller and release resources
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _log('Disposing PlaybackController');

    _stopPositionSync();

    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    await _positionController.close();
    await _statusController.close();
    await _activeClipController.close();

    await _player.dispose();
  }
}

// ============================================================
// Riverpod Providers
// ============================================================

/// Provider for the PlaybackController instance
/// This is a singleton that persists across the editor session
final playbackControllerProvider = Provider<PlaybackController>((ref) {
  final controller = PlaybackController(ref);

  ref.onDispose(() {
    controller.dispose();
  });

  return controller;
});

/// Provider for the current playback status
final playbackStatusProvider = StreamProvider<PlaybackStatus>((ref) {
  final controller = ref.watch(playbackControllerProvider);
  return controller.statusStream;
});

/// Provider for the current timeline position during playback
final playbackPositionProvider = StreamProvider<EditorTime>((ref) {
  final controller = ref.watch(playbackControllerProvider);
  return controller.positionStream;
});

/// Provider for the currently active clip info
final activeClipInfoProvider = StreamProvider<ActiveClipInfo?>((ref) {
  final controller = ref.watch(playbackControllerProvider);
  return controller.activeClipStream;
});

/// Provider for the current playback rate
final playbackRateProvider = Provider<double>((ref) {
  final controller = ref.watch(playbackControllerProvider);
  return controller.playbackRate;
});

/// Provider for checking if playback is active
final isPlayingProvider = Provider<bool>((ref) {
  final controller = ref.watch(playbackControllerProvider);
  return controller.isPlaying;
});

/// Provider for the media_kit Player instance (for video display widgets)
final mediaPlayerProvider = Provider<Player>((ref) {
  final controller = ref.watch(playbackControllerProvider);
  return controller.player;
});

/// Provider for the video controller (for Video widget)
final videoControllerProvider = Provider<VideoController>((ref) {
  final controller = ref.watch(playbackControllerProvider);
  return controller.videoController;
});
