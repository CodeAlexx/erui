import 'dart:async';
import 'dart:ui';

import '../models/text_clip_models.dart';
import '../models/editor_models.dart';
import 'ffmpeg_service.dart';

/// Service for rendering text overlays via FFmpeg drawtext
class TextRenderer {
  final FFmpegService _ffmpeg;

  TextRenderer({FFmpegService? ffmpeg}) : _ffmpeg = ffmpeg ?? FFmpegService();

  /// Generate FFmpeg drawtext filter for a text clip
  String generateDrawtextFilter(
    TextClip clip,
    Size videoSize, {
    EditorTime? timeOffset,
  }) {
    final style = clip.style;
    final text = _escapeText(clip.text);

    // Calculate position in pixels
    final x = (clip.position.dx * videoSize.width).round();
    final y = (clip.position.dy * videoSize.height).round();

    // Start building filter
    final parts = <String>[
      "drawtext=text='$text'",
      'fontfile=${_getFontPath(style.fontFamily)}',
      'fontsize=${style.fontSize.round()}',
      'fontcolor=${_colorToFfmpeg(style.color)}',
    ];

    // Position based on alignment
    switch (style.textAlign) {
      case TextAlign.left:
        parts.add('x=$x');
        break;
      case TextAlign.center:
        parts.add('x=$x-(text_w/2)');
        break;
      case TextAlign.right:
        parts.add('x=$x-text_w');
        break;
      default:
        parts.add('x=$x-(text_w/2)');
    }
    parts.add('y=$y-(text_h/2)');

    // Stroke/border
    if (style.strokeColor != null && style.strokeWidth > 0) {
      parts.add('borderw=${style.strokeWidth.round()}');
      parts.add('bordercolor=${_colorToFfmpeg(style.strokeColor!)}');
    }

    // Shadow
    if (style.shadowColor != null && style.shadowBlur > 0) {
      parts.add('shadowcolor=${_colorToFfmpeg(style.shadowColor!)}');
      parts.add('shadowx=${style.shadowOffset.dx.round()}');
      parts.add('shadowy=${style.shadowOffset.dy.round()}');
    }

    // Timing - enable filter only during clip duration
    final startSec = (timeOffset?.inSeconds ?? 0) + clip.timelineStart.inSeconds;
    final endSec = startSec + clip.duration.inSeconds;
    parts.add("enable='between(t,$startSec,$endSec)'");

    // Animation (fade in/out)
    if (clip.animation != null) {
      final anim = clip.animation!;
      final filterParts = _generateAnimationFilter(anim, startSec, endSec, clip.opacity);
      if (filterParts.isNotEmpty) {
        parts.addAll(filterParts);
      }
    }

    return parts.join(':');
  }

  /// Generate filter for text animation
  List<String> _generateAnimationFilter(
    TextAnimation animation,
    double startSec,
    double endSec,
    double baseOpacity,
  ) {
    final parts = <String>[];

    switch (animation.type) {
      case TextAnimationType.fadeIn:
        final fadeEnd = startSec + animation.entranceDuration;
        parts.add("alpha='if(lt(t,$startSec),0,if(lt(t,$fadeEnd),(t-$startSec)/${animation.entranceDuration},$baseOpacity))'");
        break;

      case TextAnimationType.fadeOut:
        final fadeStart = endSec - animation.exitDuration;
        parts.add("alpha='if(lt(t,$fadeStart),$baseOpacity,if(lt(t,$endSec),$baseOpacity*(1-(t-$fadeStart)/${animation.exitDuration}),0))'");
        break;

      case TextAnimationType.fadeInOut:
        final fadeInEnd = startSec + animation.entranceDuration;
        final fadeOutStart = endSec - animation.exitDuration;
        parts.add(
          "alpha='if(lt(t,$startSec),0,"
          "if(lt(t,$fadeInEnd),(t-$startSec)/${animation.entranceDuration},"
          "if(lt(t,$fadeOutStart),$baseOpacity,"
          "if(lt(t,$endSec),$baseOpacity*(1-(t-$fadeOutStart)/${animation.exitDuration}),0))))'",
        );
        break;

      case TextAnimationType.typewriter:
        // Reveal text character by character
        final duration = endSec - startSec - animation.entranceDuration;
        parts.add("text='%{eif\\:clip((t-$startSec)/$duration*strlen($startSec),0,strlen($startSec))\\:d}'");
        break;

      default:
        // No animation filter needed
        break;
    }

    return parts;
  }

  /// Generate a filter chain for multiple text clips
  String generateFilterChain(
    List<TextClip> clips,
    Size videoSize, {
    EditorTime? timeOffset,
  }) {
    if (clips.isEmpty) return '';

    final filters = clips.map((clip) => generateDrawtextFilter(
      clip,
      videoSize,
      timeOffset: timeOffset,
    )).toList();

    return filters.join(',');
  }

  /// Generate text overlay with background box
  String generateTextWithBackground(
    TextClip clip,
    Size videoSize, {
    EditorTime? timeOffset,
  }) {
    if (clip.background == null) {
      return generateDrawtextFilter(clip, videoSize, timeOffset: timeOffset);
    }

    final bg = clip.background!;
    final style = clip.style;

    // Calculate text dimensions (approximate)
    final textWidth = clip.text.length * style.fontSize * 0.6;
    final textHeight = style.fontSize * style.lineHeight;

    // Box dimensions with padding
    final boxWidth = (textWidth + bg.padding * 2).round();
    final boxHeight = (textHeight + bg.padding * 2).round();

    // Position
    final x = (clip.position.dx * videoSize.width).round();
    final y = (clip.position.dy * videoSize.height).round();

    // Timing
    final startSec = (timeOffset?.inSeconds ?? 0) + clip.timelineStart.inSeconds;
    final endSec = startSec + clip.duration.inSeconds;

    // Draw background box first, then text
    final boxFilter = "drawbox=x=${x - boxWidth ~/ 2}:y=${y - boxHeight ~/ 2}"
        ":w=$boxWidth:h=$boxHeight"
        ":color=${_colorToFfmpeg(bg.color)}"
        ":t=fill"
        ":enable='between(t,$startSec,$endSec)'";

    final textFilter = generateDrawtextFilter(clip, videoSize, timeOffset: timeOffset);

    return '$boxFilter,$textFilter';
  }

  /// Render text to an image file (for preview)
  Future<String> renderTextToImage(
    TextClip clip,
    Size videoSize,
    String outputPath,
  ) async {
    // Create a colored frame and overlay text
    final command = [
      '-f', 'lavfi',
      '-i', 'color=c=black:s=${videoSize.width.round()}x${videoSize.height.round()}:d=1',
      '-vf', generateDrawtextFilter(clip, videoSize),
      '-frames:v', '1',
      '-y',
      outputPath,
    ];

    await _ffmpeg.executeCommand(command);
    return outputPath;
  }

  /// Escape text for FFmpeg drawtext filter
  String _escapeText(String text) {
    return text
        .replaceAll('\\', '\\\\\\\\')
        .replaceAll("'", "'\\\\\\''")
        .replaceAll(':', '\\:')
        .replaceAll('%', '\\%');
  }

  /// Convert Color to FFmpeg format
  String _colorToFfmpeg(Color color) {
    final r = color.red.toRadixString(16).padLeft(2, '0');
    final g = color.green.toRadixString(16).padLeft(2, '0');
    final b = color.blue.toRadixString(16).padLeft(2, '0');
    final a = (color.opacity).toStringAsFixed(2);
    return '0x$r$g$b@$a';
  }

  /// Get path to font file
  String _getFontPath(String fontFamily) {
    // Map common font names to system font paths
    final fontMap = {
      'Arial': '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      'Helvetica': '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      'Times New Roman': '/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf',
      'Courier': '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
      'Courier New': '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
      'Georgia': '/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf',
      'Verdana': '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    };

    return fontMap[fontFamily] ?? fontMap['Arial']!;
  }
}

/// Builder for complex text compositions
class TextCompositionBuilder {
  final List<TextClip> _clips = [];
  final Size _videoSize;

  TextCompositionBuilder(this._videoSize);

  /// Add a text clip
  TextCompositionBuilder addClip(TextClip clip) {
    _clips.add(clip);
    return this;
  }

  /// Add a lower third title
  TextCompositionBuilder addLowerThird({
    required String title,
    String? subtitle,
    required EditorTime startTime,
    required EditorTime duration,
  }) {
    // Main title
    _clips.add(TextClip(
      name: title,
      timelineStart: startTime,
      duration: duration,
      text: title,
      style: const TextClipStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Color(0xFFFFFFFF),
      ),
      position: const Offset(0.05, 0.82),
      background: const TextBackground(
        color: Color(0xCC000000),
        padding: 10,
      ),
      animation: const TextAnimation(
        type: TextAnimationType.slideInLeft,
        entranceDuration: 0.3,
        exitDuration: 0.3,
      ),
    ));

    // Subtitle if provided
    if (subtitle != null) {
      _clips.add(TextClip(
        name: subtitle,
        timelineStart: EditorTime(startTime.microseconds + 100000), // Slight delay
        duration: EditorTime(duration.microseconds - 100000),
        text: subtitle,
        style: const TextClipStyle(
          fontSize: 24,
          color: Color(0xCCFFFFFF),
        ),
        position: const Offset(0.05, 0.88),
        animation: const TextAnimation(
          type: TextAnimationType.slideInLeft,
          entranceDuration: 0.4,
          exitDuration: 0.3,
        ),
      ));
    }

    return this;
  }

  /// Add a centered title
  TextCompositionBuilder addCenterTitle({
    required String text,
    required EditorTime startTime,
    required EditorTime duration,
    double fontSize = 64,
  }) {
    _clips.add(TextClip(
      name: text,
      timelineStart: startTime,
      duration: duration,
      text: text,
      style: TextClipStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFFFFFFF),
        shadowColor: const Color(0x80000000),
        shadowOffset: const Offset(2, 2),
        shadowBlur: 4,
      ),
      position: const Offset(0.5, 0.5),
      animation: const TextAnimation(
        type: TextAnimationType.fadeInOut,
        entranceDuration: 0.5,
        exitDuration: 0.5,
      ),
    ));

    return this;
  }

  /// Build the FFmpeg filter chain
  String build(TextRenderer renderer) {
    return renderer.generateFilterChain(_clips, _videoSize);
  }

  /// Get all clips
  List<TextClip> get clips => List.unmodifiable(_clips);
}
