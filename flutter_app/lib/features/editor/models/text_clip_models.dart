import 'dart:ui';
import 'editor_models.dart';

/// A text clip that can be placed on the timeline
class TextClip extends EditorClip {
  /// Text content to display
  final String text;

  /// Text style settings
  final TextClipStyle style;

  /// Position on screen (normalized 0.0 - 1.0)
  final Offset position;

  /// Text animation settings
  final TextAnimation? animation;

  /// Background box settings
  final TextBackground? background;

  /// Title template used (if any)
  final EditorId? templateId;

  TextClip({
    super.id,
    required String name,
    required super.timelineStart,
    required super.duration,
    required this.text,
    this.style = const TextClipStyle(),
    this.position = const Offset(0.5, 0.5),
    this.animation,
    this.background,
    this.templateId,
    super.trackIndex = 0,
    super.isSelected = false,
    super.isLocked = false,
    super.opacity = 1.0,
  }) : super(
          type: ClipType.text,
          name: name,
        );

  @override
  TextClip copyWith({
    EditorId? id,
    ClipType? type,
    String? name,
    EditorTime? timelineStart,
    EditorTime? duration,
    String? sourcePath,
    EditorTime? sourceStart,
    EditorTime? sourceDuration,
    int? trackIndex,
    bool? isSelected,
    bool? isLocked,
    double? opacity,
    Color? color,
    String? text,
    TextClipStyle? style,
    Offset? position,
    TextAnimation? animation,
    TextBackground? background,
    EditorId? templateId,
  }) {
    return TextClip(
      id: id ?? this.id,
      name: name ?? this.name,
      timelineStart: timelineStart ?? this.timelineStart,
      duration: duration ?? this.duration,
      text: text ?? this.text,
      style: style ?? this.style,
      position: position ?? this.position,
      animation: animation ?? this.animation,
      background: background ?? this.background,
      templateId: templateId ?? this.templateId,
      trackIndex: trackIndex ?? this.trackIndex,
      isSelected: isSelected ?? this.isSelected,
      isLocked: isLocked ?? this.isLocked,
      opacity: opacity ?? this.opacity,
    );
  }
}

/// Text styling options
class TextClipStyle {
  final String fontFamily;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final Color? strokeColor;
  final double strokeWidth;
  final Color? shadowColor;
  final Offset shadowOffset;
  final double shadowBlur;
  final TextAlign textAlign;
  final double letterSpacing;
  final double lineHeight;
  final bool italic;
  final bool underline;

  const TextClipStyle({
    this.fontFamily = 'Arial',
    this.fontSize = 48.0,
    this.fontWeight = FontWeight.normal,
    this.color = const Color(0xFFFFFFFF),
    this.strokeColor,
    this.strokeWidth = 0.0,
    this.shadowColor,
    this.shadowOffset = Offset.zero,
    this.shadowBlur = 0.0,
    this.textAlign = TextAlign.center,
    this.letterSpacing = 0.0,
    this.lineHeight = 1.2,
    this.italic = false,
    this.underline = false,
  });

  TextClipStyle copyWith({
    String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    Color? strokeColor,
    double? strokeWidth,
    Color? shadowColor,
    Offset? shadowOffset,
    double? shadowBlur,
    TextAlign? textAlign,
    double? letterSpacing,
    double? lineHeight,
    bool? italic,
    bool? underline,
  }) {
    return TextClipStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      color: color ?? this.color,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowOffset: shadowOffset ?? this.shadowOffset,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      textAlign: textAlign ?? this.textAlign,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      lineHeight: lineHeight ?? this.lineHeight,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
    );
  }

  /// Convert to FFmpeg drawtext filter options
  String toFfmpegFilter(String text, Size videoSize, Offset position) {
    final x = (position.dx * videoSize.width).round();
    final y = (position.dy * videoSize.height).round();

    String filter = "drawtext=text='${_escapeText(text)}'"
        ":fontfile=/usr/share/fonts/truetype/$fontFamily.ttf"
        ":fontsize=${fontSize.round()}"
        ":fontcolor=${_colorToHex(color)}"
        ":x=$x:y=$y";

    if (strokeColor != null && strokeWidth > 0) {
      filter += ":borderw=${strokeWidth.round()}"
          ":bordercolor=${_colorToHex(strokeColor!)}";
    }

    if (shadowColor != null && shadowBlur > 0) {
      filter += ":shadowcolor=${_colorToHex(shadowColor!)}"
          ":shadowx=${shadowOffset.dx.round()}"
          ":shadowy=${shadowOffset.dy.round()}";
    }

    return filter;
  }

  String _escapeText(String text) {
    return text
        .replaceAll("'", "\\'")
        .replaceAll(":", "\\:")
        .replaceAll("\\", "\\\\");
  }

  String _colorToHex(Color c) {
    return '0x${c.red.toRadixString(16).padLeft(2, '0')}'
        '${c.green.toRadixString(16).padLeft(2, '0')}'
        '${c.blue.toRadixString(16).padLeft(2, '0')}'
        '@${(c.opacity).toStringAsFixed(2)}';
  }
}

/// Text animation types
enum TextAnimationType {
  none,
  fadeIn,
  fadeOut,
  fadeInOut,
  slideInLeft,
  slideInRight,
  slideInTop,
  slideInBottom,
  scaleIn,
  scaleOut,
  typewriter,
  wordByWord,
  bounce,
  shake,
}

extension TextAnimationTypeExtension on TextAnimationType {
  String get displayName {
    switch (this) {
      case TextAnimationType.none:
        return 'None';
      case TextAnimationType.fadeIn:
        return 'Fade In';
      case TextAnimationType.fadeOut:
        return 'Fade Out';
      case TextAnimationType.fadeInOut:
        return 'Fade In/Out';
      case TextAnimationType.slideInLeft:
        return 'Slide In Left';
      case TextAnimationType.slideInRight:
        return 'Slide In Right';
      case TextAnimationType.slideInTop:
        return 'Slide In Top';
      case TextAnimationType.slideInBottom:
        return 'Slide In Bottom';
      case TextAnimationType.scaleIn:
        return 'Scale In';
      case TextAnimationType.scaleOut:
        return 'Scale Out';
      case TextAnimationType.typewriter:
        return 'Typewriter';
      case TextAnimationType.wordByWord:
        return 'Word by Word';
      case TextAnimationType.bounce:
        return 'Bounce';
      case TextAnimationType.shake:
        return 'Shake';
    }
  }
}

/// Text animation settings
class TextAnimation {
  final TextAnimationType type;

  /// Duration of entrance animation (in seconds)
  final double entranceDuration;

  /// Duration of exit animation (in seconds)
  final double exitDuration;

  /// Delay before animation starts
  final double delay;

  /// Easing curve for animation
  final TextAnimationEasing easing;

  const TextAnimation({
    this.type = TextAnimationType.none,
    this.entranceDuration = 0.5,
    this.exitDuration = 0.5,
    this.delay = 0.0,
    this.easing = TextAnimationEasing.easeInOut,
  });

  TextAnimation copyWith({
    TextAnimationType? type,
    double? entranceDuration,
    double? exitDuration,
    double? delay,
    TextAnimationEasing? easing,
  }) {
    return TextAnimation(
      type: type ?? this.type,
      entranceDuration: entranceDuration ?? this.entranceDuration,
      exitDuration: exitDuration ?? this.exitDuration,
      delay: delay ?? this.delay,
      easing: easing ?? this.easing,
    );
  }
}

/// Animation easing types
enum TextAnimationEasing {
  linear,
  easeIn,
  easeOut,
  easeInOut,
  bounceIn,
  bounceOut,
  elastic,
}

/// Background box for text
class TextBackground {
  final Color color;
  final double padding;
  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;

  const TextBackground({
    this.color = const Color(0x80000000),
    this.padding = 8.0,
    this.borderRadius = 4.0,
    this.borderColor,
    this.borderWidth = 0.0,
  });

  TextBackground copyWith({
    Color? color,
    double? padding,
    double? borderRadius,
    Color? borderColor,
    double? borderWidth,
  }) {
    return TextBackground(
      color: color ?? this.color,
      padding: padding ?? this.padding,
      borderRadius: borderRadius ?? this.borderRadius,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
    );
  }
}

/// Pre-built title template
class TitleTemplate {
  final EditorId id;
  final String name;
  final String category;
  final TextClipStyle style;
  final TextAnimation? animation;
  final TextBackground? background;
  final Offset position;
  final String previewText;
  final String? thumbnailPath;

  const TitleTemplate({
    required this.id,
    required this.name,
    this.category = 'General',
    required this.style,
    this.animation,
    this.background,
    this.position = const Offset(0.5, 0.5),
    this.previewText = 'Sample Text',
    this.thumbnailPath,
  });

  /// Create a TextClip from this template
  TextClip createClip({
    required String text,
    required EditorTime timelineStart,
    required EditorTime duration,
  }) {
    return TextClip(
      name: text.length > 20 ? '${text.substring(0, 20)}...' : text,
      timelineStart: timelineStart,
      duration: duration,
      text: text,
      style: style,
      animation: animation,
      background: background,
      position: position,
      templateId: id,
    );
  }
}

/// Built-in title templates
class TitleTemplates {
  static final List<TitleTemplate> builtIn = [
    TitleTemplate(
      id: 'lower_third_simple',
      name: 'Simple Lower Third',
      category: 'Lower Thirds',
      style: const TextClipStyle(
        fontFamily: 'Arial',
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Color(0xFFFFFFFF),
      ),
      background: const TextBackground(
        color: Color(0xCC000000),
        padding: 12.0,
        borderRadius: 4.0,
      ),
      position: const Offset(0.1, 0.85),
      animation: const TextAnimation(
        type: TextAnimationType.slideInLeft,
        entranceDuration: 0.3,
        exitDuration: 0.3,
      ),
    ),
    TitleTemplate(
      id: 'center_title',
      name: 'Center Title',
      category: 'Titles',
      style: const TextClipStyle(
        fontFamily: 'Arial',
        fontSize: 64,
        fontWeight: FontWeight.bold,
        color: Color(0xFFFFFFFF),
        shadowColor: Color(0x80000000),
        shadowOffset: Offset(2, 2),
        shadowBlur: 4.0,
      ),
      position: const Offset(0.5, 0.5),
      animation: const TextAnimation(
        type: TextAnimationType.fadeInOut,
        entranceDuration: 0.5,
        exitDuration: 0.5,
      ),
    ),
    TitleTemplate(
      id: 'minimal_caption',
      name: 'Minimal Caption',
      category: 'Captions',
      style: const TextClipStyle(
        fontFamily: 'Arial',
        fontSize: 24,
        color: Color(0xFFFFFFFF),
        strokeColor: Color(0xFF000000),
        strokeWidth: 2.0,
      ),
      position: const Offset(0.5, 0.9),
      animation: const TextAnimation(
        type: TextAnimationType.fadeIn,
        entranceDuration: 0.2,
        exitDuration: 0.2,
      ),
    ),
  ];
}
