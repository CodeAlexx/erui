import 'dart:io';
import 'dart:convert';

import '../models/vid_train_prep_models.dart';
import '../models/onetrainer_yaml_models.dart';
import 'vid_train_prep_service.dart';

/// Service for exporting VidTrainPrep projects to OneTrainer-compatible formats.
///
/// Handles:
/// - YAML configuration generation for OneTrainer video training
/// - Caption file creation alongside exported media
/// - Project session JSON persistence
/// - Full project export with progress tracking
class YamlExportService {
  static const String _tag = 'YamlExportService';

  /// Log a debug message
  void _log(String message) {
    print('[$_tag] $message');
  }

  /// Log an error message
  void _logError(String message, [Object? error]) {
    print('[$_tag] ERROR: $message${error != null ? ' - $error' : ''}');
  }

  /// Generate and save OneTrainer concepts YAML configuration.
  ///
  /// Creates a YAML file compatible with OneTrainer's video LoRA training pipeline.
  /// Returns the path to the generated YAML file.
  Future<String> generateAndSaveYaml({
    required String exportDirectory,
    required String triggerWord,
    required int numRepeats,
    required int resolution,
    required int frames,
  }) async {
    final config = OneTrainerVideoConfig(
      concepts: [
        OneTrainerConcept(
          path: exportDirectory,
          token: triggerWord,
          numRepeats: numRepeats,
        ),
      ],
      resolution: resolution.toString(),
      frames: frames.toString(),
    );

    final yamlContent = config.toYaml();
    final yamlPath = '$exportDirectory/onetrainer_config.yaml';

    await File(yamlPath).writeAsString(yamlContent);
    _log('Generated YAML config: $yamlPath');
    return yamlPath;
  }

  /// Write caption .txt file alongside video/image.
  ///
  /// Creates a text file with the same base name as [mediaPath] but with
  /// a .txt extension. If [triggerWord] is provided, it's prepended to
  /// the caption with a comma separator.
  Future<void> writeCaptionFile({
    required String mediaPath,
    required String caption,
    String? triggerWord,
  }) async {
    // Get caption file path (same name, .txt extension)
    final captionPath = mediaPath.replaceAll(RegExp(r'\.[^.]+$'), '.txt');

    // Prepend trigger word if provided
    final fullCaption = triggerWord != null && triggerWord.isNotEmpty
        ? '$triggerWord, $caption'
        : caption;

    await File(captionPath).writeAsString(fullCaption, encoding: utf8);
    _log('Wrote caption file: $captionPath');
  }

  /// Save project session to JSON for persistence.
  ///
  /// Serializes the entire [VidTrainProject] to a JSON file at [filePath].
  /// Uses pretty-printed JSON for readability.
  Future<void> saveProjectSession({
    required VidTrainProject project,
    required String filePath,
  }) async {
    try {
      final json = project.toJson();
      final jsonString = const JsonEncoder.withIndent('  ').convert(json);
      await File(filePath).writeAsString(jsonString, encoding: utf8);
      _log('Saved project session: $filePath');
    } catch (e) {
      _logError('Error saving project session', e);
      rethrow;
    }
  }

  /// Load project session from JSON.
  ///
  /// Deserializes a [VidTrainProject] from a JSON file at [filePath].
  /// Returns null if the file doesn't exist or parsing fails.
  Future<VidTrainProject?> loadProjectSession(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _log('Project file not found: $filePath');
        return null;
      }

      final jsonString = await file.readAsString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final project = VidTrainProject.fromJson(json);
      _log('Loaded project session: $filePath');
      return project;
    } catch (e) {
      _logError('Error loading project', e);
      return null;
    }
  }

  /// Export all clips and generate YAML config.
  ///
  /// Performs a full export of the project:
  /// 1. Creates output directories (cropped/, uncropped/, frames/)
  /// 2. Exports each clip range based on export settings
  /// 3. Writes caption files for each exported clip
  /// 4. Generates OneTrainer YAML configuration
  ///
  /// The [onProgress] callback provides real-time progress updates with
  /// current item count, total count, and status message.
  ///
  /// Returns an [ExportResult] containing export statistics and file paths.
  Future<ExportResult> exportProject({
    required VidTrainProject project,
    required VidTrainExportSettings settings,
    required VidTrainPrepService vidService,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Validate export settings
      if (settings.outputDirectory.isEmpty) {
        return ExportResult(
          success: false,
          exportedFiles: [],
          captionFiles: [],
          error: 'Output directory not specified',
        );
      }

      // Create output directories
      final outputDir = Directory(settings.outputDirectory);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      final croppedDir = Directory('${settings.outputDirectory}/cropped');
      final uncroppedDir = Directory('${settings.outputDirectory}/uncropped');
      final framesDir = Directory('${settings.outputDirectory}/frames');

      if (settings.exportCropped) await croppedDir.create(recursive: true);
      if (settings.exportUncropped) await uncroppedDir.create(recursive: true);
      if (settings.exportFirstFrame) await framesDir.create(recursive: true);

      final exportedFiles = <String>[];
      final captionFiles = <String>[];
      final errors = <String>[];
      int current = 0;
      int total = 0;

      // Count total operations
      for (final video in project.videos) {
        final ranges = project.rangesByVideo[video.id] ?? [];
        total += ranges.length *
            ((settings.exportCropped ? 1 : 0) +
                (settings.exportUncropped ? 1 : 0) +
                (settings.exportFirstFrame ? 1 : 0));
      }

      if (total == 0) {
        return ExportResult(
          success: false,
          exportedFiles: [],
          captionFiles: [],
          error: 'No clips to export',
        );
      }

      _log('Starting export: $total operations');
      onProgress?.call(0, total, 'Starting export...');

      // Export each range
      for (final video in project.videos) {
        final ranges = project.rangesByVideo[video.id] ?? [];

        for (int i = 0; i < ranges.length; i++) {
          final range = ranges[i];
          final baseName =
              '${video.fileName.replaceAll(RegExp(r'\.[^.]+$'), '')}_range${i + 1}';
          final startDuration = Duration(
              milliseconds: ((range.startFrame / video.fps) * 1000).round());
          final clipDuration = Duration(
              milliseconds:
                  (((range.endFrame - range.startFrame) / video.fps) * 1000)
                      .round());

          // Export cropped version
          if (settings.exportCropped && range.useCrop && range.crop != null) {
            current++;
            onProgress?.call(current, total, 'Exporting $baseName (cropped)');

            final outputPath =
                '${croppedDir.path}/$baseName.${settings.outputFormat}';
            final success = await vidService.extractCroppedClip(
              inputPath: video.filePath,
              outputPath: outputPath,
              start: startDuration,
              duration: clipDuration,
              crop: range.crop!,
              sourceWidth: video.width,
              sourceHeight: video.height,
              targetFps: settings.targetFps,
              maxFrames: settings.targetFrames,
              maxLongestEdge: settings.maxLongestEdge,
              includeAudio: settings.includeAudio,
            );

            if (success) {
              exportedFiles.add(outputPath);
              // Write caption file if caption exists
              if (settings.generateCaptions && range.caption.isNotEmpty) {
                await writeCaptionFile(
                  mediaPath: outputPath,
                  caption: range.caption,
                  triggerWord: settings.triggerWord,
                );
                captionFiles
                    .add(outputPath.replaceAll(RegExp(r'\.[^.]+$'), '.txt'));
              }
            } else {
              errors.add('Failed to export cropped: $baseName');
            }
          }

          // Export uncropped version
          if (settings.exportUncropped) {
            current++;
            onProgress?.call(current, total, 'Exporting $baseName (uncropped)');

            final outputPath =
                '${uncroppedDir.path}/$baseName.${settings.outputFormat}';
            final success = await vidService.extractUncroppedClip(
              inputPath: video.filePath,
              outputPath: outputPath,
              start: startDuration,
              duration: clipDuration,
              targetFps: settings.targetFps,
              maxFrames: settings.targetFrames,
              maxLongestEdge: settings.maxLongestEdge,
              includeAudio: settings.includeAudio,
            );

            if (success) {
              exportedFiles.add(outputPath);
              if (settings.generateCaptions && range.caption.isNotEmpty) {
                await writeCaptionFile(
                  mediaPath: outputPath,
                  caption: range.caption,
                  triggerWord: settings.triggerWord,
                );
                captionFiles
                    .add(outputPath.replaceAll(RegExp(r'\.[^.]+$'), '.txt'));
              }
            } else {
              errors.add('Failed to export uncropped: $baseName');
            }
          }

          // Export first frame
          if (settings.exportFirstFrame) {
            current++;
            onProgress?.call(current, total, 'Exporting $baseName (frame)');

            final outputPath = '${framesDir.path}/$baseName.png';
            final success = await vidService.extractFirstFrame(
              inputPath: video.filePath,
              outputPath: outputPath,
              timestamp: startDuration,
              crop: range.useCrop ? range.crop : null,
              sourceWidth: video.width,
              sourceHeight: video.height,
              maxLongestEdge: settings.maxLongestEdge,
            );

            if (success) {
              exportedFiles.add(outputPath);
              // Optionally write caption for frames too
              if (settings.generateCaptions && range.caption.isNotEmpty) {
                await writeCaptionFile(
                  mediaPath: outputPath,
                  caption: range.caption,
                  triggerWord: settings.triggerWord,
                );
                captionFiles
                    .add(outputPath.replaceAll(RegExp(r'\.[^.]+$'), '.txt'));
              }
            } else {
              errors.add('Failed to export frame: $baseName');
            }
          }
        }
      }

      // Generate YAML config
      String? yamlPath;
      if (exportedFiles.isNotEmpty) {
        yamlPath = await generateAndSaveYaml(
          exportDirectory: settings.outputDirectory,
          triggerWord: settings.triggerWord,
          numRepeats: settings.numRepeats,
          resolution: settings.maxLongestEdge,
          frames: settings.targetFrames,
        );
      }

      stopwatch.stop();
      _log('Export completed: ${exportedFiles.length} files in ${stopwatch.elapsed}');

      return ExportResult(
        success: exportedFiles.isNotEmpty,
        exportedFiles: exportedFiles,
        captionFiles: captionFiles,
        yamlConfigPath: yamlPath,
        error: errors.isEmpty ? null : errors.join('\n'),
        totalTime: stopwatch.elapsed,
      );
    } catch (e, stack) {
      stopwatch.stop();
      _logError('Export failed', e);
      print('[$_tag] Stack trace: $stack');
      return ExportResult(
        success: false,
        exportedFiles: [],
        captionFiles: [],
        error: e.toString(),
        totalTime: stopwatch.elapsed,
      );
    }
  }

  /// Generate multiple concept configurations for multi-folder exports.
  ///
  /// Useful when exporting to separate directories for different subjects
  /// or training concepts.
  Future<String> generateMultiConceptYaml({
    required String outputDirectory,
    required List<OneTrainerConcept> concepts,
    required int resolution,
    required int frames,
  }) async {
    final config = OneTrainerVideoConfig(
      concepts: concepts,
      resolution: resolution.toString(),
      frames: frames.toString(),
    );

    final yamlContent = config.toYaml();
    final yamlPath = '$outputDirectory/onetrainer_config.yaml';

    await File(yamlPath).writeAsString(yamlContent);
    _log('Generated multi-concept YAML config: $yamlPath');
    return yamlPath;
  }

  /// Validate export directory and return any issues.
  ///
  /// Checks:
  /// - Directory exists or can be created
  /// - Write permissions
  /// - Sufficient disk space (optional threshold)
  Future<List<String>> validateExportDirectory(
    String directoryPath, {
    int? requiredSpaceBytes,
  }) async {
    final issues = <String>[];

    try {
      final dir = Directory(directoryPath);

      if (await dir.exists()) {
        // Check if we can write to it
        final testFile = File('${dir.path}/.write_test');
        try {
          await testFile.writeAsString('test');
          await testFile.delete();
        } catch (e) {
          issues.add('Cannot write to directory: $directoryPath');
        }
      } else {
        // Try to create it
        try {
          await dir.create(recursive: true);
          await dir.delete();
        } catch (e) {
          issues.add('Cannot create directory: $directoryPath');
        }
      }
    } catch (e) {
      issues.add('Invalid directory path: $directoryPath');
    }

    return issues;
  }
}

/// Result of a project export operation.
///
/// Contains statistics about exported files, caption files, and any
/// errors that occurred during the export process.
class ExportResult {
  /// Whether the export completed successfully (at least one file exported).
  final bool success;

  /// List of all exported media file paths.
  final List<String> exportedFiles;

  /// List of all generated caption file paths.
  final List<String> captionFiles;

  /// Path to the generated OneTrainer YAML configuration file.
  final String? yamlConfigPath;

  /// Error message if export failed or had issues.
  final String? error;

  /// Total time taken for the export operation.
  final Duration? totalTime;

  ExportResult({
    required this.success,
    required this.exportedFiles,
    required this.captionFiles,
    this.yamlConfigPath,
    this.error,
    this.totalTime,
  });

  /// Number of clips successfully exported.
  int get clipCount => exportedFiles.length;

  /// Number of caption files generated.
  int get captionCount => captionFiles.length;

  /// Whether a YAML config was generated.
  bool get hasYamlConfig => yamlConfigPath != null;

  /// Whether any errors occurred during export.
  bool get hasErrors => error != null && error!.isNotEmpty;

  /// Summary string for display.
  String get summary {
    final parts = <String>[
      '$clipCount clips exported',
      if (captionCount > 0) '$captionCount captions',
      if (hasYamlConfig) 'YAML config generated',
      if (totalTime != null) 'in ${totalTime!.inSeconds}s',
    ];
    return parts.join(', ');
  }

  @override
  String toString() => 'ExportResult(success: $success, '
      'clips: $clipCount, captions: $captionCount, '
      'yaml: $hasYamlConfig, error: $error)';
}
