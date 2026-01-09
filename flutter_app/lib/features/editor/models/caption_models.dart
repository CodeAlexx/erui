import 'dart:ui';
import 'editor_models.dart';

/// A single caption/subtitle entry
class Caption {
  final EditorId id;

  /// Start time of caption
  final EditorTime startTime;

  /// End time of caption
  final EditorTime endTime;

  /// Caption text content
  final String text;

  /// Speaker identification (optional)
  final String? speaker;

  /// Caption style override (uses track default if null)
  final CaptionStyle? style;

  /// Position override (uses track default if null)
  final CaptionPosition? position;

  /// Whether this caption is selected in UI
  final bool isSelected;

  /// Confidence score from auto-transcription (0-1, null if manual)
  final double? confidence;

  const Caption({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.text,
    this.speaker,
    this.style,
    this.position,
    this.isSelected = false,
    this.confidence,
  });

  factory Caption.create({
    required EditorTime startTime,
    required EditorTime endTime,
    required String text,
    String? speaker,
    CaptionStyle? style,
    CaptionPosition? position,
    double? confidence,
  }) {
    return Caption(
      id: generateId(),
      startTime: startTime,
      endTime: endTime,
      text: text,
      speaker: speaker,
      style: style,
      position: position,
      confidence: confidence,
    );
  }

  Caption copyWith({
    EditorId? id,
    EditorTime? startTime,
    EditorTime? endTime,
    String? text,
    String? speaker,
    CaptionStyle? style,
    CaptionPosition? position,
    bool? isSelected,
    double? confidence,
  }) {
    return Caption(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      text: text ?? this.text,
      speaker: speaker ?? this.speaker,
      style: style ?? this.style,
      position: position ?? this.position,
      isSelected: isSelected ?? this.isSelected,
      confidence: confidence ?? this.confidence,
    );
  }

  /// Duration of this caption
  EditorTime get duration => endTime - startTime;

  /// Time range of this caption
  EditorTimeRange get timeRange => EditorTimeRange(startTime, endTime);

  /// Check if this caption is active at a given time
  bool isActiveAt(EditorTime time) =>
      time >= startTime && time < endTime;

  /// Convert to SRT format entry
  String toSrt(int index) {
    return '$index\n'
        '${_formatSrtTime(startTime)} --> ${_formatSrtTime(endTime)}\n'
        '$text\n';
  }

  String _formatSrtTime(EditorTime time) {
    final total = time.inSeconds;
    final hours = (total ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).floor().toString().padLeft(2, '0');
    final ms = ((total % 1) * 1000).round().toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$ms';
  }

  /// Convert to WebVTT format entry
  String toVtt(int index) {
    return '$index\n'
        '${_formatVttTime(startTime)} --> ${_formatVttTime(endTime)}\n'
        '$text\n';
  }

  String _formatVttTime(EditorTime time) {
    final total = time.inSeconds;
    final hours = (total ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).floor().toString().padLeft(2, '0');
    final ms = ((total % 1) * 1000).round().toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$ms';
  }
}

/// Style settings for captions
class CaptionStyle {
  final String fontFamily;
  final double fontSize;
  final FontWeight fontWeight;
  final Color textColor;
  final Color? backgroundColor;
  final double backgroundOpacity;
  final Color? outlineColor;
  final double outlineWidth;
  final bool italic;
  final bool underline;

  const CaptionStyle({
    this.fontFamily = 'Arial',
    this.fontSize = 24.0,
    this.fontWeight = FontWeight.normal,
    this.textColor = const Color(0xFFFFFFFF),
    this.backgroundColor,
    this.backgroundOpacity = 0.5,
    this.outlineColor = const Color(0xFF000000),
    this.outlineWidth = 2.0,
    this.italic = false,
    this.underline = false,
  });

  CaptionStyle copyWith({
    String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
    Color? textColor,
    Color? backgroundColor,
    double? backgroundOpacity,
    Color? outlineColor,
    double? outlineWidth,
    bool? italic,
    bool? underline,
  }) {
    return CaptionStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      outlineColor: outlineColor ?? this.outlineColor,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
    );
  }

  /// Convert to ASS style string
  String toAssStyle(String name) {
    final bold = fontWeight == FontWeight.bold ? '-1' : '0';
    final italicStr = italic ? '-1' : '0';
    final underlineStr = underline ? '-1' : '0';
    final primary = _colorToAss(textColor);
    final outline = _colorToAss(outlineColor ?? const Color(0xFF000000));
    final back = _colorToAss(backgroundColor ?? const Color(0x80000000));

    return 'Style: $name,$fontFamily,${fontSize.round()},$primary,$primary,$outline,$back,'
        '$bold,$italicStr,$underlineStr,0,100,100,0,0,1,${outlineWidth.round()},0,2,10,10,10,1';
  }

  String _colorToAss(Color c) {
    // ASS uses &HAABBGGRR format
    final a = (255 - (c.alpha)).toRadixString(16).padLeft(2, '0');
    final b = c.blue.toRadixString(16).padLeft(2, '0');
    final g = c.green.toRadixString(16).padLeft(2, '0');
    final r = c.red.toRadixString(16).padLeft(2, '0');
    return '&H$a$b$g$r';
  }
}

/// Position settings for captions
class CaptionPosition {
  /// Horizontal alignment
  final CaptionAlignment horizontal;

  /// Vertical position (0.0 = top, 1.0 = bottom)
  final double vertical;

  /// Margin from edges (normalized 0-1)
  final double marginHorizontal;
  final double marginVertical;

  const CaptionPosition({
    this.horizontal = CaptionAlignment.center,
    this.vertical = 0.9,
    this.marginHorizontal = 0.05,
    this.marginVertical = 0.05,
  });

  CaptionPosition copyWith({
    CaptionAlignment? horizontal,
    double? vertical,
    double? marginHorizontal,
    double? marginVertical,
  }) {
    return CaptionPosition(
      horizontal: horizontal ?? this.horizontal,
      vertical: vertical ?? this.vertical,
      marginHorizontal: marginHorizontal ?? this.marginHorizontal,
      marginVertical: marginVertical ?? this.marginVertical,
    );
  }
}

/// Caption horizontal alignment
enum CaptionAlignment {
  left,
  center,
  right,
}

/// A track of captions
class CaptionTrack {
  final EditorId id;

  /// Display name for this track
  final String name;

  /// Language code (ISO 639-1)
  final String language;

  /// List of captions
  final List<Caption> captions;

  /// Default style for captions
  final CaptionStyle style;

  /// Default position for captions
  final CaptionPosition position;

  /// Whether this track is visible
  final bool isVisible;

  /// Whether this track is locked
  final bool isLocked;

  /// Track height in timeline
  final double height;

  const CaptionTrack({
    required this.id,
    this.name = 'Subtitles',
    this.language = 'en',
    this.captions = const [],
    this.style = const CaptionStyle(),
    this.position = const CaptionPosition(),
    this.isVisible = true,
    this.isLocked = false,
    this.height = 40.0,
  });

  factory CaptionTrack.create({
    String? name,
    String language = 'en',
    CaptionStyle? style,
    CaptionPosition? position,
  }) {
    return CaptionTrack(
      id: generateId(),
      name: name ?? 'Subtitles ($language)',
      language: language,
      style: style ?? const CaptionStyle(),
      position: position ?? const CaptionPosition(),
    );
  }

  CaptionTrack copyWith({
    EditorId? id,
    String? name,
    String? language,
    List<Caption>? captions,
    CaptionStyle? style,
    CaptionPosition? position,
    bool? isVisible,
    bool? isLocked,
    double? height,
  }) {
    return CaptionTrack(
      id: id ?? this.id,
      name: name ?? this.name,
      language: language ?? this.language,
      captions: captions ?? List.from(this.captions),
      style: style ?? this.style,
      position: position ?? this.position,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      height: height ?? this.height,
    );
  }

  /// Get sorted captions by start time
  List<Caption> get sortedCaptions => List.from(captions)
    ..sort((a, b) => a.startTime.microseconds.compareTo(b.startTime.microseconds));

  /// Get caption at a specific time
  Caption? captionAt(EditorTime time) {
    for (final caption in captions) {
      if (caption.isActiveAt(time)) return caption;
    }
    return null;
  }

  /// Add a caption
  CaptionTrack addCaption(Caption caption) {
    return copyWith(captions: [...captions, caption]);
  }

  /// Remove a caption
  CaptionTrack removeCaption(EditorId captionId) {
    return copyWith(
      captions: captions.where((c) => c.id != captionId).toList(),
    );
  }

  /// Update a caption
  CaptionTrack updateCaption(Caption caption) {
    return copyWith(
      captions: captions.map((c) => c.id == caption.id ? caption : c).toList(),
    );
  }

  /// Export to SRT format
  String toSrt() {
    final buffer = StringBuffer();
    final sorted = sortedCaptions;
    for (int i = 0; i < sorted.length; i++) {
      buffer.write(sorted[i].toSrt(i + 1));
      buffer.write('\n');
    }
    return buffer.toString();
  }

  /// Export to WebVTT format
  String toVtt() {
    final buffer = StringBuffer();
    buffer.writeln('WEBVTT');
    buffer.writeln();

    final sorted = sortedCaptions;
    for (int i = 0; i < sorted.length; i++) {
      buffer.write(sorted[i].toVtt(i + 1));
      buffer.write('\n');
    }
    return buffer.toString();
  }

  /// Parse SRT file content
  static CaptionTrack fromSrt(String content, {String language = 'en'}) {
    final captions = <Caption>[];
    final blocks = content.trim().split(RegExp(r'\n\n+'));

    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 3) continue;

      // Parse timestamp line
      final timeLine = lines[1];
      final timeMatch = RegExp(
        r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})',
      ).firstMatch(timeLine);

      if (timeMatch == null) continue;

      final startTime = _parseTime(
        int.parse(timeMatch.group(1)!),
        int.parse(timeMatch.group(2)!),
        int.parse(timeMatch.group(3)!),
        int.parse(timeMatch.group(4)!),
      );

      final endTime = _parseTime(
        int.parse(timeMatch.group(5)!),
        int.parse(timeMatch.group(6)!),
        int.parse(timeMatch.group(7)!),
        int.parse(timeMatch.group(8)!),
      );

      // Join remaining lines as text
      final text = lines.sublist(2).join('\n');

      captions.add(Caption.create(
        startTime: startTime,
        endTime: endTime,
        text: text,
      ));
    }

    return CaptionTrack.create(
      language: language,
    ).copyWith(captions: captions);
  }

  static EditorTime _parseTime(int hours, int minutes, int seconds, int ms) {
    final totalMs = hours * 3600000 + minutes * 60000 + seconds * 1000 + ms;
    return EditorTime.fromMilliseconds(totalMs);
  }
}

/// SRT entry for import/export
class SRTEntry {
  final int index;
  final EditorTime startTime;
  final EditorTime endTime;
  final String text;

  const SRTEntry({
    required this.index,
    required this.startTime,
    required this.endTime,
    required this.text,
  });

  /// Convert to Caption
  Caption toCaption() {
    return Caption.create(
      startTime: startTime,
      endTime: endTime,
      text: text,
    );
  }
}

/// Caption state for the project
class CaptionState {
  /// All caption tracks
  final List<CaptionTrack> tracks;

  /// Currently active track ID
  final EditorId? activeTrackId;

  /// Currently selected caption IDs
  final Set<EditorId> selectedCaptionIds;

  /// Whether caption overlay is visible in preview
  final bool showInPreview;

  const CaptionState({
    this.tracks = const [],
    this.activeTrackId,
    this.selectedCaptionIds = const {},
    this.showInPreview = true,
  });

  CaptionState copyWith({
    List<CaptionTrack>? tracks,
    EditorId? activeTrackId,
    Set<EditorId>? selectedCaptionIds,
    bool? showInPreview,
  }) {
    return CaptionState(
      tracks: tracks ?? List.from(this.tracks),
      activeTrackId: activeTrackId ?? this.activeTrackId,
      selectedCaptionIds: selectedCaptionIds ?? Set.from(this.selectedCaptionIds),
      showInPreview: showInPreview ?? this.showInPreview,
    );
  }

  /// Get active track
  CaptionTrack? get activeTrack {
    if (activeTrackId == null) return null;
    for (final track in tracks) {
      if (track.id == activeTrackId) return track;
    }
    return null;
  }

  /// Get caption at time across all visible tracks
  Caption? captionAt(EditorTime time) {
    for (final track in tracks) {
      if (!track.isVisible) continue;
      final caption = track.captionAt(time);
      if (caption != null) return caption;
    }
    return null;
  }
}
