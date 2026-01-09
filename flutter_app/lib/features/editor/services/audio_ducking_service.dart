import 'dart:async';
import 'dart:io';

import '../models/editor_models.dart';
import 'ffmpeg_service.dart';

/// Audio ducking settings
class DuckingSettings {
  /// Threshold in dB for voice detection
  final double voiceThreshold;

  /// Amount to reduce music volume (0-1)
  final double duckAmount;

  /// Attack time in ms (how fast ducking engages)
  final int attackMs;

  /// Release time in ms (how fast volume returns)
  final int releaseMs;

  /// Minimum silence duration to release ducking (ms)
  final int holdMs;

  /// Ratio of compression when ducking
  final double ratio;

  /// Knee width in dB for smooth transition
  final double knee;

  const DuckingSettings({
    this.voiceThreshold = -20.0,
    this.duckAmount = 0.3, // Duck to 30% volume
    this.attackMs = 50,
    this.releaseMs = 300,
    this.holdMs = 200,
    this.ratio = 4.0,
    this.knee = 6.0,
  });

  DuckingSettings copyWith({
    double? voiceThreshold,
    double? duckAmount,
    int? attackMs,
    int? releaseMs,
    int? holdMs,
    double? ratio,
    double? knee,
  }) {
    return DuckingSettings(
      voiceThreshold: voiceThreshold ?? this.voiceThreshold,
      duckAmount: duckAmount ?? this.duckAmount,
      attackMs: attackMs ?? this.attackMs,
      releaseMs: releaseMs ?? this.releaseMs,
      holdMs: holdMs ?? this.holdMs,
      ratio: ratio ?? this.ratio,
      knee: knee ?? this.knee,
    );
  }
}

/// A detected speech segment
class SpeechSegment {
  final EditorTime start;
  final EditorTime end;
  final double confidence;

  const SpeechSegment({
    required this.start,
    required this.end,
    this.confidence = 1.0,
  });

  EditorTime get duration => end - start;
}

/// A ducking keyframe (volume change point)
class DuckingKeyframe {
  final EditorTime time;
  final double volume; // 0-1

  const DuckingKeyframe({
    required this.time,
    required this.volume,
  });
}

/// Generated ducking curve
class DuckingCurve {
  final List<DuckingKeyframe> keyframes;
  final List<SpeechSegment> speechSegments;

  const DuckingCurve({
    required this.keyframes,
    required this.speechSegments,
  });

  /// Get volume at a specific time
  double volumeAt(EditorTime time) {
    if (keyframes.isEmpty) return 1.0;

    // Find surrounding keyframes
    for (int i = 0; i < keyframes.length - 1; i++) {
      if (time >= keyframes[i].time && time < keyframes[i + 1].time) {
        // Linear interpolation between keyframes
        final kf1 = keyframes[i];
        final kf2 = keyframes[i + 1];
        final progress = (time.microseconds - kf1.time.microseconds) /
            (kf2.time.microseconds - kf1.time.microseconds);
        return kf1.volume + (kf2.volume - kf1.volume) * progress;
      }
    }

    if (time < keyframes.first.time) return keyframes.first.volume;
    return keyframes.last.volume;
  }

  /// Generate FFmpeg volume filter expression
  String toFfmpegExpression() {
    if (keyframes.isEmpty) return 'volume=1';

    final parts = <String>[];
    for (int i = 0; i < keyframes.length - 1; i++) {
      final kf1 = keyframes[i];
      final kf2 = keyframes[i + 1];
      final t1 = kf1.time.inSeconds;
      final t2 = kf2.time.inSeconds;

      // Linear ramp between keyframes
      final slope = (kf2.volume - kf1.volume) / (t2 - t1);
      parts.add("if(between(t,$t1,$t2),${kf1.volume}+$slope*(t-$t1),");
    }

    // Final volume after last keyframe
    parts.add('${keyframes.last.volume}');

    // Close all conditionals
    parts.add(')' * (keyframes.length - 1));

    return "volume='${parts.join('')}'";
  }
}

/// Service for automatic audio ducking
class AudioDuckingService {
  final FFmpegService _ffmpeg;
  final String _tempDir;

  AudioDuckingService({
    FFmpegService? ffmpeg,
    String? tempDir,
  })  : _ffmpeg = ffmpeg ?? FFmpegService(),
        _tempDir = tempDir ?? Directory.systemTemp.path;

  /// Detect speech segments in audio track
  Future<List<SpeechSegment>> detectSpeech(
    String audioPath,
    DuckingSettings settings, {
    Function(double progress)? onProgress,
  }) async {
    // Use silencedetect filter to find speech
    final silenceFile = '$_tempDir/silence_${DateTime.now().millisecondsSinceEpoch}.txt';

    // Run silence detection
    final command = [
      '-i', audioPath,
      '-af', 'silencedetect=noise=${settings.voiceThreshold}dB:d=${settings.holdMs / 1000}',
      '-f', 'null',
      '-',
    ];

    // Execute and capture stderr (where silencedetect outputs)
    final result = await _ffmpeg.executeCommandWithOutput(command);

    // Parse silence detection output
    final segments = _parseSilenceOutput(result, settings);

    return segments;
  }

  /// Parse FFmpeg silencedetect output to find speech segments
  List<SpeechSegment> _parseSilenceOutput(String output, DuckingSettings settings) {
    final segments = <SpeechSegment>[];
    final silenceStarts = <double>[];
    final silenceEnds = <double>[];

    // Find all silence_start and silence_end markers
    final startPattern = RegExp(r'silence_start:\s*([\d.]+)');
    final endPattern = RegExp(r'silence_end:\s*([\d.]+)');

    for (final match in startPattern.allMatches(output)) {
      silenceStarts.add(double.parse(match.group(1)!));
    }

    for (final match in endPattern.allMatches(output)) {
      silenceEnds.add(double.parse(match.group(1)!));
    }

    // Convert silence periods to speech periods (inverse)
    double lastEnd = 0;
    for (int i = 0; i < silenceStarts.length; i++) {
      if (silenceStarts[i] > lastEnd) {
        // Speech between last silence end and this silence start
        segments.add(SpeechSegment(
          start: EditorTime.fromSeconds(lastEnd),
          end: EditorTime.fromSeconds(silenceStarts[i]),
        ));
      }
      if (i < silenceEnds.length) {
        lastEnd = silenceEnds[i];
      }
    }

    return segments;
  }

  /// Generate ducking curve from speech segments
  DuckingCurve generateDuckingCurve(
    List<SpeechSegment> speechSegments,
    DuckingSettings settings,
  ) {
    final keyframes = <DuckingKeyframe>[];

    if (speechSegments.isEmpty) {
      return DuckingCurve(keyframes: keyframes, speechSegments: speechSegments);
    }

    // Start at full volume
    keyframes.add(const DuckingKeyframe(
      time: EditorTime.zero(),
      volume: 1.0,
    ));

    for (final segment in speechSegments) {
      // Add attack keyframe (start ducking)
      final attackStart = EditorTime(
        (segment.start.microseconds - settings.attackMs * 1000).clamp(0, double.maxFinite.toInt()),
      );
      keyframes.add(DuckingKeyframe(
        time: attackStart,
        volume: 1.0,
      ));
      keyframes.add(DuckingKeyframe(
        time: segment.start,
        volume: settings.duckAmount,
      ));

      // Add release keyframe (return to full)
      final releaseEnd = EditorTime(
        segment.end.microseconds + settings.releaseMs * 1000,
      );
      keyframes.add(DuckingKeyframe(
        time: segment.end,
        volume: settings.duckAmount,
      ));
      keyframes.add(DuckingKeyframe(
        time: releaseEnd,
        volume: 1.0,
      ));
    }

    // Sort and remove duplicates
    keyframes.sort((a, b) => a.time.microseconds.compareTo(b.time.microseconds));

    return DuckingCurve(
      keyframes: keyframes,
      speechSegments: speechSegments,
    );
  }

  /// Apply ducking to music track
  Future<String> applyDucking(
    String musicPath,
    String outputPath,
    DuckingCurve curve, {
    Function(double progress)? onProgress,
  }) async {
    final filter = curve.toFfmpegExpression();

    final command = [
      '-i', musicPath,
      '-af', filter,
      '-y',
      outputPath,
    ];

    await _ffmpeg.executeCommand(command, onProgress: onProgress);
    return outputPath;
  }

  /// Apply sidechain compression (alternative ducking method)
  Future<String> applySidechainDucking(
    String musicPath,
    String voicePath,
    String outputPath,
    DuckingSettings settings, {
    Function(double progress)? onProgress,
  }) async {
    // Use sidechain compressor
    final command = [
      '-i', musicPath,
      '-i', voicePath,
      '-filter_complex',
      '[1:a]asplit[sc][voice];'
      '[0:a][sc]sidechaincompress='
      'threshold=${settings.voiceThreshold}dB:'
      'ratio=${settings.ratio}:'
      'attack=${settings.attackMs}:'
      'release=${settings.releaseMs}:'
      'knee=${settings.knee}'
      '[ducked];'
      '[ducked][voice]amix=inputs=2:duration=longest',
      '-y',
      outputPath,
    ];

    await _ffmpeg.executeCommand(command, onProgress: onProgress);
    return outputPath;
  }

  /// Full automatic ducking workflow
  Future<String> autoducking(
    String musicPath,
    String voicePath,
    String outputPath,
    DuckingSettings settings, {
    Function(String stage, double progress)? onProgress,
  }) async {
    // 1. Detect speech in voice track
    onProgress?.call('Detecting speech', 0.0);
    final speechSegments = await detectSpeech(
      voicePath,
      settings,
      onProgress: (p) => onProgress?.call('Detecting speech', p * 0.3),
    );

    // 2. Generate ducking curve
    onProgress?.call('Generating curve', 0.3);
    final curve = generateDuckingCurve(speechSegments, settings);

    // 3. Apply ducking to music
    onProgress?.call('Applying ducking', 0.5);
    await applyDucking(
      musicPath,
      outputPath,
      curve,
      onProgress: (p) => onProgress?.call('Applying ducking', 0.5 + p * 0.5),
    );

    return outputPath;
  }
}

/// Preset ducking configurations
class DuckingPreset {
  final String id;
  final String name;
  final String description;
  final DuckingSettings settings;

  const DuckingPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.settings,
  });

  static const List<DuckingPreset> presets = [
    DuckingPreset(
      id: 'subtle',
      name: 'Subtle',
      description: 'Light ducking, music stays present',
      settings: DuckingSettings(
        duckAmount: 0.5,
        attackMs: 100,
        releaseMs: 500,
      ),
    ),
    DuckingPreset(
      id: 'podcast',
      name: 'Podcast',
      description: 'Clear speech, background music',
      settings: DuckingSettings(
        duckAmount: 0.3,
        attackMs: 50,
        releaseMs: 300,
      ),
    ),
    DuckingPreset(
      id: 'dramatic',
      name: 'Dramatic',
      description: 'Strong ducking for impact',
      settings: DuckingSettings(
        duckAmount: 0.15,
        attackMs: 30,
        releaseMs: 200,
      ),
    ),
    DuckingPreset(
      id: 'interview',
      name: 'Interview',
      description: 'Quick response, natural feel',
      settings: DuckingSettings(
        duckAmount: 0.25,
        attackMs: 20,
        releaseMs: 400,
        holdMs: 150,
      ),
    ),
  ];
}
