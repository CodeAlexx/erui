// Stub file for non-web platforms
// The web_video_player.dart is only used on web platform
// This stub provides empty implementations for native platforms

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';

/// Stub widget for non-web platforms (never used)
class WebVideoPlayer extends ConsumerStatefulWidget {
  const WebVideoPlayer({super.key});

  @override
  ConsumerState<WebVideoPlayer> createState() => _WebVideoPlayerState();
}

class _WebVideoPlayerState extends ConsumerState<WebVideoPlayer> {
  Future<void> playClip(EditorClip clip, EditorTime playheadPosition) async {}
  void pause() {}
  void stop() {}
  void seekTo(EditorTime position) {}
  void setVolume(double volume) {}
  void setPlaybackRate(double rate) {}
  
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Stub provider
final webVideoPlayerKeyProvider = StateProvider<GlobalKey<_WebVideoPlayerState>>((ref) {
  return GlobalKey<_WebVideoPlayerState>();
});
