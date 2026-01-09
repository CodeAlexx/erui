import 'dart:async';

import 'ffmpeg_service.dart';

/// Video noise reduction settings
class VideoNoiseSettings {
  /// Noise reduction method
  final VideoNoiseMethod method;

  /// Strength (0-100)
  final int strength;

  /// For hqdn3d: luma spatial (0-255)
  final double lumaSpatial;

  /// For hqdn3d: chroma spatial (0-255)
  final double chromaSpatial;

  /// For hqdn3d: luma temporal (0-255)
  final double lumaTemporal;

  /// For hqdn3d: chroma temporal (0-255)
  final double chromaTemporal;

  /// For nlmeans: denoising strength
  final double nlmeansStrength;

  /// For nlmeans: patch size
  final int nlmeansPatchSize;

  /// For nlmeans: search window size
  final int nlmeansSearchSize;

  const VideoNoiseSettings({
    this.method = VideoNoiseMethod.hqdn3d,
    this.strength = 50,
    this.lumaSpatial = 4.0,
    this.chromaSpatial = 3.0,
    this.lumaTemporal = 6.0,
    this.chromaTemporal = 4.5,
    this.nlmeansStrength = 3.0,
    this.nlmeansPatchSize = 7,
    this.nlmeansSearchSize = 15,
  });

  VideoNoiseSettings copyWith({
    VideoNoiseMethod? method,
    int? strength,
    double? lumaSpatial,
    double? chromaSpatial,
    double? lumaTemporal,
    double? chromaTemporal,
    double? nlmeansStrength,
    int? nlmeansPatchSize,
    int? nlmeansSearchSize,
  }) {
    return VideoNoiseSettings(
      method: method ?? this.method,
      strength: strength ?? this.strength,
      lumaSpatial: lumaSpatial ?? this.lumaSpatial,
      chromaSpatial: chromaSpatial ?? this.chromaSpatial,
      lumaTemporal: lumaTemporal ?? this.lumaTemporal,
      chromaTemporal: chromaTemporal ?? this.chromaTemporal,
      nlmeansStrength: nlmeansStrength ?? this.nlmeansStrength,
      nlmeansPatchSize: nlmeansPatchSize ?? this.nlmeansPatchSize,
      nlmeansSearchSize: nlmeansSearchSize ?? this.nlmeansSearchSize,
    );
  }

  /// Scale values based on strength
  VideoNoiseSettings withStrength(int newStrength) {
    final factor = newStrength / 50.0; // 50 is default/middle
    return copyWith(
      strength: newStrength,
      lumaSpatial: (4.0 * factor).clamp(0.0, 255.0),
      chromaSpatial: (3.0 * factor).clamp(0.0, 255.0),
      lumaTemporal: (6.0 * factor).clamp(0.0, 255.0),
      chromaTemporal: (4.5 * factor).clamp(0.0, 255.0),
      nlmeansStrength: (3.0 * factor).clamp(0.0, 20.0),
    );
  }

  /// Generate FFmpeg filter string
  String toFfmpegFilter() {
    switch (method) {
      case VideoNoiseMethod.hqdn3d:
        return 'hqdn3d=$lumaSpatial:$chromaSpatial:$lumaTemporal:$chromaTemporal';
      case VideoNoiseMethod.nlmeans:
        return 'nlmeans=s=$nlmeansStrength:p=$nlmeansPatchSize:r=$nlmeansSearchSize';
    }
  }
}

/// Video noise reduction methods
enum VideoNoiseMethod {
  /// High quality denoise 3D - fast, good for light noise
  hqdn3d,

  /// Non-local means - slower but better for heavy noise
  nlmeans,
}

extension VideoNoiseMethodExtension on VideoNoiseMethod {
  String get displayName {
    switch (this) {
      case VideoNoiseMethod.hqdn3d:
        return 'HQ Denoise 3D (Fast)';
      case VideoNoiseMethod.nlmeans:
        return 'Non-Local Means (Quality)';
    }
  }

  String get description {
    switch (this) {
      case VideoNoiseMethod.hqdn3d:
        return 'Fast, good for light to medium noise. Works in 3D (spatial + temporal).';
      case VideoNoiseMethod.nlmeans:
        return 'Higher quality, slower. Best for heavy noise but may soften details.';
    }
  }
}

/// Audio noise reduction settings
class AudioNoiseSettings {
  /// Noise reduction amount (0-100)
  final int noiseReduction;

  /// Noise floor in dB
  final double noiseFloor;

  /// Number of FFT bands for analysis
  final int bands;

  /// Track noise reduction - adaptive noise tracking
  final bool trackNoise;

  /// Residue output - only output the noise being removed
  final bool outputResidue;

  const AudioNoiseSettings({
    this.noiseReduction = 50,
    this.noiseFloor = -50.0,
    this.bands = 32,
    this.trackNoise = true,
    this.outputResidue = false,
  });

  AudioNoiseSettings copyWith({
    int? noiseReduction,
    double? noiseFloor,
    int? bands,
    bool? trackNoise,
    bool? outputResidue,
  }) {
    return AudioNoiseSettings(
      noiseReduction: noiseReduction ?? this.noiseReduction,
      noiseFloor: noiseFloor ?? this.noiseFloor,
      bands: bands ?? this.bands,
      trackNoise: trackNoise ?? this.trackNoise,
      outputResidue: outputResidue ?? this.outputResidue,
    );
  }

  /// Generate FFmpeg afftdn filter string
  String toFfmpegFilter() {
    final parts = <String>[
      'afftdn=',
      'nr=$noiseReduction',
      ':nf=$noiseFloor',
      ':bn=$bands',
    ];

    if (trackNoise) {
      parts.add(':tn=1');
    }

    if (outputResidue) {
      parts.add(':om=o');
    }

    return parts.join('');
  }
}

/// Service for noise reduction (video and audio)
class NoiseReductionService {
  final FFmpegService _ffmpeg;

  NoiseReductionService({FFmpegService? ffmpeg})
      : _ffmpeg = ffmpeg ?? FFmpegService();

  /// Apply video noise reduction
  Future<String> reduceVideoNoise(
    String inputPath,
    String outputPath,
    VideoNoiseSettings settings, {
    Function(double progress)? onProgress,
  }) async {
    final filter = settings.toFfmpegFilter();

    final command = [
      '-i', inputPath,
      '-vf', filter,
      '-c:a', 'copy',
      '-y',
      outputPath,
    ];

    await _ffmpeg.executeCommand(command, onProgress: onProgress);
    return outputPath;
  }

  /// Apply audio noise reduction
  Future<String> reduceAudioNoise(
    String inputPath,
    String outputPath,
    AudioNoiseSettings settings, {
    Function(double progress)? onProgress,
  }) async {
    final filter = settings.toFfmpegFilter();

    final command = [
      '-i', inputPath,
      '-af', filter,
      '-c:v', 'copy',
      '-y',
      outputPath,
    ];

    await _ffmpeg.executeCommand(command, onProgress: onProgress);
    return outputPath;
  }

  /// Apply both video and audio noise reduction
  Future<String> reduceNoise(
    String inputPath,
    String outputPath, {
    VideoNoiseSettings? videoSettings,
    AudioNoiseSettings? audioSettings,
    Function(double progress)? onProgress,
  }) async {
    final command = <String>['-i', inputPath];

    if (videoSettings != null) {
      command.addAll(['-vf', videoSettings.toFfmpegFilter()]);
    } else {
      command.addAll(['-c:v', 'copy']);
    }

    if (audioSettings != null) {
      command.addAll(['-af', audioSettings.toFfmpegFilter()]);
    } else {
      command.addAll(['-c:a', 'copy']);
    }

    command.addAll(['-y', outputPath]);

    await _ffmpeg.executeCommand(command, onProgress: onProgress);
    return outputPath;
  }

  /// Generate filter string for use in complex filter chain
  String getVideoFilterString(VideoNoiseSettings settings) {
    return settings.toFfmpegFilter();
  }

  /// Generate filter string for use in complex filter chain
  String getAudioFilterString(AudioNoiseSettings settings) {
    return settings.toFfmpegFilter();
  }

  /// Analyze noise level in video
  Future<NoiseAnalysis> analyzeVideoNoise(
    String inputPath, {
    int sampleFrames = 30,
  }) async {
    // Use signalstats filter to analyze noise
    final command = [
      '-i', inputPath,
      '-vframes', sampleFrames.toString(),
      '-vf', 'signalstats,metadata=print:file=-',
      '-f', 'null',
      '-',
    ];

    // Note: Would need to parse output for actual noise values
    // This is a simplified placeholder
    try {
      await _ffmpeg.executeCommand(command);
      return const NoiseAnalysis(
        videoNoiseLevel: 0.5, // Would be parsed from output
        audioNoiseLevel: 0.3,
        recommendedVideoStrength: 50,
        recommendedAudioStrength: 50,
      );
    } catch (e) {
      return const NoiseAnalysis(
        videoNoiseLevel: 0.0,
        audioNoiseLevel: 0.0,
        recommendedVideoStrength: 25,
        recommendedAudioStrength: 25,
      );
    }
  }
}

/// Result of noise analysis
class NoiseAnalysis {
  /// Video noise level (0-1)
  final double videoNoiseLevel;

  /// Audio noise level (0-1)
  final double audioNoiseLevel;

  /// Recommended video denoise strength
  final int recommendedVideoStrength;

  /// Recommended audio denoise strength
  final int recommendedAudioStrength;

  const NoiseAnalysis({
    required this.videoNoiseLevel,
    required this.audioNoiseLevel,
    required this.recommendedVideoStrength,
    required this.recommendedAudioStrength,
  });
}

/// Preset noise reduction configurations
class NoiseReductionPreset {
  final String id;
  final String name;
  final String description;
  final VideoNoiseSettings? videoSettings;
  final AudioNoiseSettings? audioSettings;

  const NoiseReductionPreset({
    required this.id,
    required this.name,
    required this.description,
    this.videoSettings,
    this.audioSettings,
  });

  static const List<NoiseReductionPreset> presets = [
    // Video presets
    NoiseReductionPreset(
      id: 'video_light',
      name: 'Light Video Denoise',
      description: 'Subtle noise reduction, preserves detail',
      videoSettings: VideoNoiseSettings(
        method: VideoNoiseMethod.hqdn3d,
        strength: 25,
        lumaSpatial: 2.0,
        chromaSpatial: 1.5,
        lumaTemporal: 3.0,
        chromaTemporal: 2.0,
      ),
    ),
    NoiseReductionPreset(
      id: 'video_medium',
      name: 'Medium Video Denoise',
      description: 'Balanced noise reduction',
      videoSettings: VideoNoiseSettings(
        method: VideoNoiseMethod.hqdn3d,
        strength: 50,
      ),
    ),
    NoiseReductionPreset(
      id: 'video_heavy',
      name: 'Heavy Video Denoise',
      description: 'Strong noise reduction, may soften image',
      videoSettings: VideoNoiseSettings(
        method: VideoNoiseMethod.nlmeans,
        strength: 75,
        nlmeansStrength: 5.0,
      ),
    ),

    // Audio presets
    NoiseReductionPreset(
      id: 'audio_light',
      name: 'Light Audio Denoise',
      description: 'Remove background hiss',
      audioSettings: AudioNoiseSettings(
        noiseReduction: 30,
        noiseFloor: -60,
      ),
    ),
    NoiseReductionPreset(
      id: 'audio_medium',
      name: 'Medium Audio Denoise',
      description: 'Remove noticeable background noise',
      audioSettings: AudioNoiseSettings(
        noiseReduction: 50,
        noiseFloor: -50,
      ),
    ),
    NoiseReductionPreset(
      id: 'audio_heavy',
      name: 'Heavy Audio Denoise',
      description: 'Aggressive noise removal',
      audioSettings: AudioNoiseSettings(
        noiseReduction: 75,
        noiseFloor: -40,
      ),
    ),

    // Combined presets
    NoiseReductionPreset(
      id: 'both_light',
      name: 'Light Full Denoise',
      description: 'Subtle video and audio cleanup',
      videoSettings: VideoNoiseSettings(strength: 25),
      audioSettings: AudioNoiseSettings(noiseReduction: 30),
    ),
    NoiseReductionPreset(
      id: 'both_medium',
      name: 'Medium Full Denoise',
      description: 'Balanced video and audio cleanup',
      videoSettings: VideoNoiseSettings(strength: 50),
      audioSettings: AudioNoiseSettings(noiseReduction: 50),
    ),
  ];
}
