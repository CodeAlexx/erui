import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../providers/editor_provider.dart';

/// Web-specific video player using HTML5 video element
/// This bypasses media_kit which has issues on web
class WebVideoPlayer extends ConsumerStatefulWidget {
  const WebVideoPlayer({super.key});

  @override
  ConsumerState<WebVideoPlayer> createState() => _WebVideoPlayerState();
}

class _WebVideoPlayerState extends ConsumerState<WebVideoPlayer> {
  static const String _viewType = 'web-video-player';
  static int _instanceCount = 0;
  
  late final String _viewId;
  html.VideoElement? _videoElement;
  EditorClip? _currentClip;
  Timer? _positionTimer;
  bool _isPlaying = false;
  
  @override
  void initState() {
    super.initState();
    _viewId = '${_viewType}_${_instanceCount++}';
    _registerViewFactory();
  }
  
  void _registerViewFactory() {
    // Register the HTML view factory
    ui.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        _videoElement = html.VideoElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain'
          ..style.backgroundColor = 'black'
          ..autoplay = false
          ..controls = false  // We provide our own controls
          ..muted = false
          ..crossOrigin = 'anonymous';  // Enable CORS
        
        // Listen to video events
        _videoElement!.onPlay.listen((_) {
          setState(() => _isPlaying = true);
          _startPositionSync();
        });
        
        _videoElement!.onPause.listen((_) {
          setState(() => _isPlaying = false);
          _stopPositionSync();
        });
        
        _videoElement!.onEnded.listen((_) {
          print('[WebVideoPlayer] Playback ended');
          setState(() => _isPlaying = false);
          _stopPositionSync();
          ref.read(editorProjectProvider.notifier).stop();
        });
        
        _videoElement!.onError.listen((event) {
          print('[WebVideoPlayer] Video error: ${_videoElement!.error?.code}');
        });
        
        _videoElement!.onLoadedMetadata.listen((_) {
          print('[WebVideoPlayer] Metadata loaded, duration: ${_videoElement!.duration}s');
        });
        
        return _videoElement!;
      },
    );
  }
  
  void _startPositionSync() {
    _stopPositionSync();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (_videoElement != null && _currentClip != null && _isPlaying) {
        final currentTime = _videoElement!.currentTime;
        final timelinePosition = _currentClip!.timelineStart + 
            EditorTime.fromSeconds(currentTime - _currentClip!.sourceStart.inSeconds);
        ref.read(editorProjectProvider.notifier).setPlayhead(timelinePosition);
      }
    });
  }
  
  void _stopPositionSync() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }
  
  @override
  void dispose() {
    _stopPositionSync();
    super.dispose();
  }
  
  /// Load and play a clip
  Future<void> playClip(EditorClip clip, EditorTime playheadPosition) async {
    if (clip.sourcePath == null) {
      print('[WebVideoPlayer] Clip has no source path');
      return;
    }
    
    _currentClip = clip;
    
    // Calculate start position within source
    final sourceOffset = playheadPosition - clip.timelineStart;
    final startTime = (clip.sourceStart + sourceOffset).inSeconds;
    
    print('[WebVideoPlayer] Playing: ${clip.sourcePath} from ${startTime}s');
    
    if (_videoElement != null) {
      // Set source and start time
      _videoElement!.src = clip.sourcePath!;
      _videoElement!.currentTime = startTime;
      
      try {
        await _videoElement!.play();
        ref.read(editorProjectProvider.notifier).play();
      } catch (e) {
        print('[WebVideoPlayer] Play failed: $e');
      }
    }
  }
  
  /// Pause playback
  void pause() {
    _videoElement?.pause();
    ref.read(editorProjectProvider.notifier).pause();
  }
  
  /// Stop playback and reset
  void stop() {
    _videoElement?.pause();
    _videoElement?.currentTime = 0;
    _currentClip = null;
    ref.read(editorProjectProvider.notifier).stop();
  }
  
  /// Seek to a position within the current clip
  void seekTo(EditorTime position) {
    if (_currentClip == null || _videoElement == null) return;
    
    final clip = _currentClip!;
    if (position >= clip.timelineStart && position <= clip.timelineEnd) {
      final sourceOffset = position - clip.timelineStart;
      final seekTime = (clip.sourceStart + sourceOffset).inSeconds;
      _videoElement!.currentTime = seekTime;
    }
  }
  
  /// Set volume (0.0 to 1.0)
  void setVolume(double volume) {
    if (_videoElement != null) {
      _videoElement!.volume = volume.clamp(0.0, 1.0);
    }
  }
  
  /// Set playback rate
  void setPlaybackRate(double rate) {
    if (_videoElement != null) {
      _videoElement!.playbackRate = rate.clamp(0.25, 4.0);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}

/// Provider for the web video player widget key
final webVideoPlayerKeyProvider = StateProvider<GlobalKey<_WebVideoPlayerState>>((ref) {
  return GlobalKey<_WebVideoPlayerState>();
});
