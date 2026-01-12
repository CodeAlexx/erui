import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/editor_models.dart';
import '../providers/editor_provider.dart';

/// Web-compatible video player using Flutter's video_player package
class WebPlaybackController {
  static const String _tag = 'WebPlaybackController';

  /// Reference to read Riverpod providers
  final Ref _ref;

  /// Flutter video_player controller
  VideoPlayerController? _controller;

  /// Currently active clip
  EditorClip? _activeClip;

  /// Timer for position sync during playback
  Timer? _positionSyncTimer;

  /// Whether the controller has been disposed
  bool _disposed = false;

  /// Current status
  bool _isPlaying = false;

  WebPlaybackController(this._ref);

  /// Whether playback is currently active
  bool get isPlaying => _isPlaying;

  /// Get the current video player controller for the Video widget
  VideoPlayerController? get controller => _controller;

  void _log(String message) {
    print('[$_tag] $message');
  }

  void _logError(String message, [Object? error]) {
    print('[$_tag] ERROR: $message${error != null ? ' - $error' : ''}');
  }

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
        _ref.read(editorProjectProvider.notifier).setPlayhead(nextClip.timelineStart);
        await _playClip(nextClip, nextClip.timelineStart);
      } else {
        _log('No clips available for playback');
        _ref.read(editorProjectProvider.notifier).stop();
      }
      return;
    }

    await _playClip(clipToPlay, playheadPosition);
  }

  /// Pause playback
  Future<void> pause() async {
    if (_disposed) return;

    _log('pause() called');

    await _controller?.pause();
    _isPlaying = false;
    _stopPositionSync();
    _ref.read(editorProjectProvider.notifier).pause();
  }

  /// Stop playback and reset
  Future<void> stop() async {
    if (_disposed) return;

    _log('stop() called');

    await _controller?.pause();
    await _controller?.seekTo(Duration.zero);
    _isPlaying = false;
    _activeClip = null;
    _stopPositionSync();
    _ref.read(editorProjectProvider.notifier).stop();

    final editorState = _ref.read(editorProjectProvider);
    final resetPosition = editorState.project.inPoint ?? const EditorTime.zero();
    _ref.read(editorProjectProvider.notifier).setPlayhead(resetPosition);
  }

  /// Toggle play/pause
  Future<void> togglePlayback() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Step forward or backward by frames
  Future<void> stepFrame(int frames) async {
    if (_disposed) return;

    _log('stepFrame() called: $frames frames');

    // Pause if playing
    if (_isPlaying) {
      await pause();
    }

    final editorState = _ref.read(editorProjectProvider);
    final frameRate = editorState.project.settings.frameRate;
    final frameDuration = EditorTime.fromFrames(frames.abs(), frameRate);
    final currentPosition = editorState.project.playheadPosition;

    EditorTime newPosition;
    if (frames >= 0) {
      newPosition = currentPosition + frameDuration;
    } else {
      newPosition = currentPosition - frameDuration;
      if (newPosition.microseconds < 0) {
        newPosition = const EditorTime.zero();
      }
    }

    _ref.read(editorProjectProvider.notifier).setPlayhead(newPosition);
    
    // If we have a controller and clip, seek to new position
    if (_controller != null && _activeClip != null) {
      final clip = _activeClip!;
      if (newPosition >= clip.timelineStart && newPosition <= clip.timelineEnd) {
        final sourceOffset = newPosition - clip.timelineStart;
        final seekTime = clip.sourceStart + sourceOffset;
        await _controller!.seekTo(Duration(microseconds: seekTime.microseconds));
      }
    }
  }

  Future<void> _playClip(EditorClip clip, EditorTime playheadPosition) async {
    if (clip.sourcePath == null) {
      _logError('Clip has no source path');
      return;
    }

    final sourceOffset = playheadPosition - clip.timelineStart;
    final sourcePosition = clip.sourceStart + sourceOffset;

    _log('Playing clip: ${clip.name} from ${clip.sourcePath}');

    // If different clip or no controller, create new one
    if (_activeClip?.id != clip.id || _controller == null) {
      await _openClip(clip);
    }

    if (_controller == null) {
      _logError('Failed to create video controller');
      return;
    }

    // Seek to correct position
    await _controller!.seekTo(Duration(microseconds: sourcePosition.microseconds));

    // Start playback
    await _controller!.play();

    _activeClip = clip;
    _isPlaying = true;
    _startPositionSync();
    _ref.read(editorProjectProvider.notifier).play();
  }

  Future<void> _openClip(EditorClip clip) async {
    if (clip.sourcePath == null) return;

    _log('Opening media: ${clip.sourcePath}');

    // Dispose old controller
    await _controller?.dispose();

    // Create new controller from network URL
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(clip.sourcePath!),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    try {
      await _controller!.initialize();
      _log('Video initialized: ${_controller!.value.duration}');
      
      // Listen for completion
      _controller!.addListener(_onVideoStateChanged);
    } catch (e) {
      _logError('Failed to initialize video', e);
      _controller = null;
    }
  }

  void _onVideoStateChanged() {
    if (_controller == null) return;
    
    final value = _controller!.value;
    
    // Check if playback completed
    if (value.position >= value.duration && value.duration > Duration.zero) {
      _log('Clip ended');
      _onClipEnded();
    }
    
    // Check for errors
    if (value.hasError) {
      _logError('Video error: ${value.errorDescription}');
    }
  }

  EditorClip? _findClipAtPosition(EditorProject project, EditorTime position) {
    for (final track in project.tracks) {
      if (track.type != TrackType.video) continue;
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

    _positionSyncTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _syncPosition(),
    );
  }

  void _stopPositionSync() {
    _positionSyncTimer?.cancel();
    _positionSyncTimer = null;
  }

  void _syncPosition() {
    if (_disposed || _activeClip == null || _controller == null) return;

    final playerPosition = _controller!.value.position;
    final clip = _activeClip!;

    // Calculate timeline position from player position
    final sourceOffset = EditorTime(playerPosition.inMicroseconds) - clip.sourceStart;
    final timelinePosition = clip.timelineStart + sourceOffset;

    // Check if we've reached the end of the clip
    if (timelinePosition >= clip.timelineEnd) {
      _onClipEnded();
      return;
    }

    // Update editor playhead
    _ref.read(editorProjectProvider.notifier).setPlayhead(timelinePosition);
  }

  void _onClipEnded() {
    _log('Clip ended, looking for next clip');

    final clip = _activeClip;
    if (clip == null) return;

    final editorState = _ref.read(editorProjectProvider);
    final nextClip = _findNextClip(editorState.project, clip.timelineEnd);

    if (nextClip != null) {
      _ref.read(editorProjectProvider.notifier).setPlayhead(nextClip.timelineStart);
      _playClip(nextClip, nextClip.timelineStart);
    } else {
      _log('No more clips, stopping playback');
      stop();
    }
  }

  /// Dispose the controller
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _log('Disposing WebPlaybackController');

    _stopPositionSync();
    _controller?.removeListener(_onVideoStateChanged);
    await _controller?.dispose();
  }
}

/// State for the web video player
class WebVideoPlayerState {
  final VideoPlayerController? controller;
  final bool isInitialized;
  
  const WebVideoPlayerState({
    this.controller,
    this.isInitialized = false,
  });
  
  WebVideoPlayerState copyWith({
    VideoPlayerController? controller,
    bool? isInitialized,
  }) {
    return WebVideoPlayerState(
      controller: controller ?? this.controller,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

/// Notifier for web video player state
class WebVideoPlayerNotifier extends StateNotifier<WebVideoPlayerState> {
  final Ref _ref;
  EditorClip? _activeClip;
  Timer? _positionSyncTimer;
  bool _isPlaying = false;

  WebVideoPlayerNotifier(this._ref) : super(const WebVideoPlayerState());

  bool get isPlaying => _isPlaying;

  void _log(String message) {
    print('[WebVideoPlayer] $message');
  }

  void _logError(String message, [Object? error]) {
    print('[WebVideoPlayer] ERROR: $message${error != null ? ' - $error' : ''}');
  }

  Future<void> play() async {
    _log('play() called');

    final editorState = _ref.read(editorProjectProvider);
    final playheadPosition = editorState.project.playheadPosition;

    // Find clip at position
    EditorClip? clipToPlay;
    for (final track in editorState.project.tracks) {
      if (track.type != TrackType.video || track.isMuted) continue;
      for (final clip in track.clips) {
        if (clip.sourcePath != null && clip.timelineRange.contains(playheadPosition)) {
          clipToPlay = clip;
          break;
        }
      }
      if (clipToPlay != null) break;
    }

    if (clipToPlay == null) {
      _log('No clip at playhead, finding next...');
      // Find next clip
      for (final track in editorState.project.tracks) {
        for (final clip in track.clips) {
          if (clip.sourcePath != null && clip.timelineStart > playheadPosition) {
            clipToPlay = clip;
            _ref.read(editorProjectProvider.notifier).setPlayhead(clip.timelineStart);
            break;
          }
        }
        if (clipToPlay != null) break;
      }
    }

    if (clipToPlay == null) {
      _log('No clips available');
      return;
    }

    await _playClip(clipToPlay, _ref.read(editorProjectProvider).project.playheadPosition);
  }

  Future<void> pause() async {
    _log('pause() called');
    await state.controller?.pause();
    _isPlaying = false;
    _stopPositionSync();
    _ref.read(editorProjectProvider.notifier).pause();
  }

  Future<void> stop() async {
    _log('stop() called');
    await state.controller?.pause();
    await state.controller?.seekTo(Duration.zero);
    _isPlaying = false;
    _activeClip = null;
    _stopPositionSync();
    _ref.read(editorProjectProvider.notifier).stop();
  }

  Future<void> togglePlayback() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> stepFrame(int frames) async {
    if (_isPlaying) await pause();

    final editorState = _ref.read(editorProjectProvider);
    final frameRate = editorState.project.settings.frameRate;
    final frameDuration = EditorTime.fromFrames(frames.abs(), frameRate);
    final currentPosition = editorState.project.playheadPosition;

    EditorTime newPosition;
    if (frames >= 0) {
      newPosition = currentPosition + frameDuration;
    } else {
      newPosition = currentPosition - frameDuration;
      if (newPosition.microseconds < 0) {
        newPosition = const EditorTime.zero();
      }
    }

    _ref.read(editorProjectProvider.notifier).setPlayhead(newPosition);
  }

  Future<void> _playClip(EditorClip clip, EditorTime playheadPosition) async {
    if (clip.sourcePath == null) {
      _logError('Clip has no source path');
      return;
    }

    _log('Playing clip: ${clip.name} from ${clip.sourcePath}');

    // Calculate source position
    final sourceOffset = playheadPosition - clip.timelineStart;
    final sourcePosition = clip.sourceStart + sourceOffset;

    // Create new controller if needed
    if (_activeClip?.id != clip.id || state.controller == null) {
      await _openClip(clip);
    }

    if (state.controller == null) {
      _logError('No controller available');
      return;
    }

    // Seek and play
    await state.controller!.seekTo(Duration(microseconds: sourcePosition.microseconds.clamp(0, state.controller!.value.duration.inMicroseconds)));
    await state.controller!.play();

    _activeClip = clip;
    _isPlaying = true;
    _startPositionSync();
    _ref.read(editorProjectProvider.notifier).play();
  }

  Future<void> _openClip(EditorClip clip) async {
    if (clip.sourcePath == null) return;

    _log('Opening media: ${clip.sourcePath}');

    // Dispose old controller
    state.controller?.removeListener(_onVideoStateChanged);
    await state.controller?.dispose();

    // Create new controller
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(clip.sourcePath!),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    try {
      await controller.initialize();
      _log('Video initialized: duration=${controller.value.duration}');
      
      controller.addListener(_onVideoStateChanged);
      
      // Update state - this triggers widget rebuild
      state = WebVideoPlayerState(
        controller: controller,
        isInitialized: true,
      );
    } catch (e) {
      _logError('Failed to initialize video', e);
      state = const WebVideoPlayerState();
    }
  }

  void _onVideoStateChanged() {
    final controller = state.controller;
    if (controller == null) return;
    
    if (controller.value.hasError) {
      _logError('Video error: ${controller.value.errorDescription}');
    }
  }

  void _startPositionSync() {
    _stopPositionSync();
    _positionSyncTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _syncPosition(),
    );
  }

  void _stopPositionSync() {
    _positionSyncTimer?.cancel();
    _positionSyncTimer = null;
  }

  void _syncPosition() {
    if (_activeClip == null || state.controller == null || !_isPlaying) return;

    final playerPosition = state.controller!.value.position;
    final clip = _activeClip!;
    final videoDuration = state.controller!.value.duration;

    // Check if video ended
    if (playerPosition >= videoDuration && videoDuration > Duration.zero) {
      _log('Video ended at source position');
      stop();
      return;
    }

    // Calculate timeline position
    final sourceOffset = EditorTime(playerPosition.inMicroseconds) - clip.sourceStart;
    final timelinePosition = clip.timelineStart + sourceOffset;

    // Update playhead
    _ref.read(editorProjectProvider.notifier).setPlayhead(timelinePosition);
  }

  @override
  void dispose() {
    _log('Disposing');
    _stopPositionSync();
    state.controller?.removeListener(_onVideoStateChanged);
    state.controller?.dispose();
    super.dispose();
  }
}

/// Widget to display the video
class WebVideoPlayerWidget extends ConsumerWidget {
  const WebVideoPlayerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(webVideoPlayerProvider);

    if (playerState.controller == null || !playerState.isInitialized) {
      return const Center(
        child: Icon(Icons.videocam_off, size: 48, color: Colors.grey),
      );
    }

    return AspectRatio(
      aspectRatio: playerState.controller!.value.aspectRatio,
      child: VideoPlayer(playerState.controller!),
    );
  }
}

/// Provider for web video player state
final webVideoPlayerProvider = StateNotifierProvider<WebVideoPlayerNotifier, WebVideoPlayerState>((ref) {
  return WebVideoPlayerNotifier(ref);
});

/// Legacy provider for backward compatibility
final webPlaybackControllerProvider = Provider<WebVideoPlayerNotifier>((ref) {
  return ref.watch(webVideoPlayerProvider.notifier);
});

