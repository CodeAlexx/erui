/// OneTrainer YAML export models for VidTrainPrep feature.
///
/// These models generate YAML configuration compatible with OneTrainer's
/// video LoRA training pipeline.

/// OneTrainer concept configuration representing a single training data source.
class OneTrainerConcept {
  /// Path to the exported clips folder containing video frames/clips.
  final String path;

  /// Trigger word/token for this concept during training.
  final String token;

  /// Number of repeats (training weight) for this concept.
  final int numRepeats;

  /// Caption file extension, typically ".txt".
  final String captionFileExt;

  /// Whether this concept is enabled for training.
  final bool enabled;

  const OneTrainerConcept({
    required this.path,
    required this.token,
    this.numRepeats = 1,
    this.captionFileExt = '.txt',
    this.enabled = true,
  });

  /// Creates a copy with optional field overrides.
  OneTrainerConcept copyWith({
    String? path,
    String? token,
    int? numRepeats,
    String? captionFileExt,
    bool? enabled,
  }) {
    return OneTrainerConcept(
      path: path ?? this.path,
      token: token ?? this.token,
      numRepeats: numRepeats ?? this.numRepeats,
      captionFileExt: captionFileExt ?? this.captionFileExt,
      enabled: enabled ?? this.enabled,
    );
  }

  /// Converts this concept to a map suitable for YAML serialization.
  Map<String, dynamic> toYamlMap() {
    return {
      'path': path,
      'token': token,
      'num_repeats': numRepeats,
      'caption_file_ext': captionFileExt,
      'enabled': enabled,
    };
  }

  /// Creates a concept from a map (for loading saved configs).
  factory OneTrainerConcept.fromMap(Map<String, dynamic> map) {
    return OneTrainerConcept(
      path: map['path'] as String? ?? '',
      token: map['token'] as String? ?? '',
      numRepeats: map['num_repeats'] as int? ?? 1,
      captionFileExt: map['caption_file_ext'] as String? ?? '.txt',
      enabled: map['enabled'] as bool? ?? true,
    );
  }

  @override
  String toString() => 'OneTrainerConcept(path: $path, token: $token, '
      'numRepeats: $numRepeats, enabled: $enabled)';
}

/// Partial OneTrainer configuration for video training.
///
/// This generates YAML configuration that can be imported into OneTrainer
/// or used as a starting point for video LoRA training.
class OneTrainerVideoConfig {
  /// List of training concepts (data sources).
  final List<OneTrainerConcept> concepts;

  /// Training resolution (e.g., "512", "848", "1024").
  final String resolution;

  /// Number of frames per video clip (e.g., "21", "25", "49").
  final String frames;

  const OneTrainerVideoConfig({
    required this.concepts,
    this.resolution = '512',
    this.frames = '21',
  });

  /// Creates a copy with optional field overrides.
  OneTrainerVideoConfig copyWith({
    List<OneTrainerConcept>? concepts,
    String? resolution,
    String? frames,
  }) {
    return OneTrainerVideoConfig(
      concepts: concepts ?? this.concepts,
      resolution: resolution ?? this.resolution,
      frames: frames ?? this.frames,
    );
  }

  /// Generates YAML string for OneTrainer import.
  ///
  /// The output is formatted for readability and includes comments
  /// documenting the export source and compatibility.
  String toYaml() {
    final buffer = StringBuffer();

    // Header comments
    buffer.writeln('# VidTrainPrep Export - ${DateTime.now().toIso8601String()}');
    buffer.writeln('# Compatible with OneTrainer video LoRA training');
    buffer.writeln('');

    // Concepts section
    buffer.writeln('concepts:');
    for (final concept in concepts) {
      buffer.writeln('  - path: "${_escapeYamlString(concept.path)}"');
      buffer.writeln('    token: "${_escapeYamlString(concept.token)}"');
      buffer.writeln('    num_repeats: ${concept.numRepeats}');
      buffer.writeln('    caption_file_ext: "${concept.captionFileExt}"');
      buffer.writeln('    enabled: ${concept.enabled}');
    }

    buffer.writeln('');

    // Resolution and frames
    buffer.writeln('resolution: "$resolution"');
    buffer.writeln('frames: "$frames"');

    return buffer.toString();
  }

  /// Escapes special characters in YAML strings.
  String _escapeYamlString(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  /// Converts this config to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'concepts': concepts.map((c) => c.toYamlMap()).toList(),
      'resolution': resolution,
      'frames': frames,
    };
  }

  /// Creates a config from a map (for loading saved configs).
  factory OneTrainerVideoConfig.fromMap(Map<String, dynamic> map) {
    final conceptsList = map['concepts'] as List<dynamic>? ?? [];
    return OneTrainerVideoConfig(
      concepts: conceptsList
          .map((c) => OneTrainerConcept.fromMap(c as Map<String, dynamic>))
          .toList(),
      resolution: map['resolution'] as String? ?? '512',
      frames: map['frames'] as String? ?? '21',
    );
  }

  @override
  String toString() => 'OneTrainerVideoConfig(concepts: ${concepts.length}, '
      'resolution: $resolution, frames: $frames)';
}
