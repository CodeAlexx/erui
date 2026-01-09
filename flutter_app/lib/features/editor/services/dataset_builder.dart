import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// Dataset builder service provider
final datasetBuilderProvider = Provider<DatasetBuilder>((ref) {
  return DatasetBuilder();
});

/// Supported dataset output formats
enum DatasetFormat {
  /// kohya_ss format: {repeats}_{concept} folder structure with txt captions
  kohyaSs,

  /// OneTrainer format: expects specific metadata structure
  onetrainer,

  /// Simple format: flat folder with image/caption pairs
  simple,
}

/// Supported image resolutions for training
enum DatasetResolution {
  res512(512, '512x512'),
  res768(768, '768x768'),
  res1024(1024, '1024x1024');

  final int size;
  final String label;

  const DatasetResolution(this.size, this.label);
}

/// Configuration for creating a new dataset
class DatasetConfig {
  /// Dataset name
  final String name;

  /// Where to create the dataset
  final String outputPath;

  /// List of image paths to include
  final List<String> images;

  /// Map of image path to caption text
  final Map<String, String> captions;

  /// Target resolution for images
  final DatasetResolution resolution;

  /// Output format (kohya_ss, onetrainer, simple)
  final DatasetFormat format;

  /// Whether to create subfolders for concepts
  final bool createSubfolders;

  /// Number of repeats per image (for training weight)
  final int repeatCount;

  /// Optional concept name (used in kohya_ss folder naming)
  final String? conceptName;

  const DatasetConfig({
    required this.name,
    required this.outputPath,
    required this.images,
    this.captions = const {},
    this.resolution = DatasetResolution.res512,
    this.format = DatasetFormat.kohyaSs,
    this.createSubfolders = true,
    this.repeatCount = 1,
    this.conceptName,
  });

  /// Create a copy with updated values
  DatasetConfig copyWith({
    String? name,
    String? outputPath,
    List<String>? images,
    Map<String, String>? captions,
    DatasetResolution? resolution,
    DatasetFormat? format,
    bool? createSubfolders,
    int? repeatCount,
    String? conceptName,
  }) {
    return DatasetConfig(
      name: name ?? this.name,
      outputPath: outputPath ?? this.outputPath,
      images: images ?? this.images,
      captions: captions ?? this.captions,
      resolution: resolution ?? this.resolution,
      format: format ?? this.format,
      createSubfolders: createSubfolders ?? this.createSubfolders,
      repeatCount: repeatCount ?? this.repeatCount,
      conceptName: conceptName ?? this.conceptName,
    );
  }
}

/// Validation issue found during dataset validation
class DatasetIssue {
  /// Severity level of the issue
  final DatasetIssueSeverity severity;

  /// Description of the issue
  final String message;

  /// Optional path to the affected file
  final String? filePath;

  const DatasetIssue({
    required this.severity,
    required this.message,
    this.filePath,
  });

  @override
  String toString() => '[$severity] $message${filePath != null ? ' ($filePath)' : ''}';
}

/// Severity levels for validation issues
enum DatasetIssueSeverity {
  /// Critical issue that will prevent training
  error,

  /// Warning that may affect training quality
  warning,

  /// Informational note
  info,
}

/// Information about a created or loaded dataset
class DatasetInfo {
  /// Root path of the dataset
  final String path;

  /// Number of images in the dataset
  final int imageCount;

  /// Total effective repeats (imageCount * repeatCount)
  final int totalRepeats;

  /// Dataset format
  final DatasetFormat format;

  /// Whether the dataset passed validation
  final bool isValid;

  /// List of validation issues found
  final List<DatasetIssue> issues;

  /// Number of images with captions
  final int captionedCount;

  /// Target resolution of the dataset
  final DatasetResolution? resolution;

  /// Concept name if available
  final String? conceptName;

  /// Creation timestamp
  final DateTime? createdAt;

  const DatasetInfo({
    required this.path,
    required this.imageCount,
    required this.totalRepeats,
    required this.format,
    required this.isValid,
    this.issues = const [],
    this.captionedCount = 0,
    this.resolution,
    this.conceptName,
    this.createdAt,
  });

  /// Check if dataset has any errors
  bool get hasErrors => issues.any((i) => i.severity == DatasetIssueSeverity.error);

  /// Check if dataset has any warnings
  bool get hasWarnings => issues.any((i) => i.severity == DatasetIssueSeverity.warning);

  /// Percentage of images that have captions
  double get captionCoverage => imageCount > 0 ? (captionedCount / imageCount) * 100 : 0;

  @override
  String toString() {
    return 'DatasetInfo(path: $path, images: $imageCount, repeats: $totalRepeats, '
        'format: $format, valid: $isValid, issues: ${issues.length})';
  }
}

/// Dataset builder service for creating LoRA training datasets from extracted frames
class DatasetBuilder {
  static const String _tag = 'DatasetBuilder';

  /// Supported image extensions
  static const List<String> _imageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.bmp',
  ];

  /// Log a debug message
  void _log(String message) {
    print('[$_tag] $message');
  }

  /// Log an error message
  void _logError(String message, [Object? error]) {
    print('[$_tag] ERROR: $message${error != null ? ' - $error' : ''}');
  }

  /// Create a new dataset from the provided configuration
  /// Returns DatasetInfo with the created dataset details
  Future<DatasetInfo> createDataset(DatasetConfig config) async {
    _log('Creating dataset: ${config.name} at ${config.outputPath}');
    _log('Format: ${config.format}, Resolution: ${config.resolution.label}, '
        'Images: ${config.images.length}, Repeats: ${config.repeatCount}');

    try {
      // Validate config
      if (config.name.isEmpty) {
        throw ArgumentError('Dataset name cannot be empty');
      }
      if (config.images.isEmpty) {
        throw ArgumentError('At least one image is required');
      }

      // Create output directory structure based on format
      final datasetPath = await _createDirectoryStructure(config);

      // Add images to the dataset
      await addImages(
        datasetPath,
        config.images,
        config.images.map((img) => config.captions[img] ?? '').toList(),
        format: config.format,
        resolution: config.resolution,
      );

      // Generate metadata files
      await generateMetadata(datasetPath, config: config);

      // Validate and return dataset info
      return await getDatasetInfo(datasetPath);
    } catch (e, stack) {
      _logError('Failed to create dataset', e);
      _log('Stack trace: $stack');
      rethrow;
    }
  }

  /// Create directory structure based on format
  Future<String> _createDirectoryStructure(DatasetConfig config) async {
    String datasetPath;

    switch (config.format) {
      case DatasetFormat.kohyaSs:
        // kohya_ss: dataset_name/{repeats}_{concept}/
        datasetPath = p.join(config.outputPath, config.name);
        final conceptName = config.conceptName ?? config.name;
        final conceptFolder = '${config.repeatCount}_$conceptName';
        final imagePath = p.join(datasetPath, conceptFolder);
        await Directory(imagePath).create(recursive: true);
        _log('Created kohya_ss structure: $imagePath');
        break;

      case DatasetFormat.onetrainer:
        // OneTrainer: dataset_name/ with metadata
        datasetPath = p.join(config.outputPath, config.name);
        await Directory(datasetPath).create(recursive: true);
        _log('Created OneTrainer structure: $datasetPath');
        break;

      case DatasetFormat.simple:
        // Simple: flat folder
        datasetPath = p.join(config.outputPath, config.name);
        await Directory(datasetPath).create(recursive: true);
        _log('Created simple structure: $datasetPath');
        break;
    }

    return datasetPath;
  }

  /// Add images to an existing dataset
  /// Images are copied and captions are created as txt files
  Future<void> addImages(
    String datasetPath,
    List<String> imagePaths,
    List<String> captions, {
    DatasetFormat format = DatasetFormat.kohyaSs,
    DatasetResolution? resolution,
  }) async {
    _log('Adding ${imagePaths.length} images to dataset at $datasetPath');

    if (imagePaths.length != captions.length) {
      throw ArgumentError(
          'Image paths and captions must have the same length '
          '(${imagePaths.length} vs ${captions.length})');
    }

    // Determine target directory
    String targetDir = datasetPath;
    if (format == DatasetFormat.kohyaSs) {
      // Find the concept folder (format: {repeats}_{concept})
      final dir = Directory(datasetPath);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is Directory) {
            final name = p.basename(entity.path);
            if (RegExp(r'^\d+_.+$').hasMatch(name)) {
              targetDir = entity.path;
              break;
            }
          }
        }
      }
    }

    await Directory(targetDir).create(recursive: true);

    for (int i = 0; i < imagePaths.length; i++) {
      final sourcePath = imagePaths[i];
      final caption = captions[i];

      try {
        final sourceFile = File(sourcePath);
        if (!await sourceFile.exists()) {
          _logError('Source image not found: $sourcePath');
          continue;
        }

        // Generate unique filename
        final ext = p.extension(sourcePath).toLowerCase();
        final baseName = p.basenameWithoutExtension(sourcePath);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uniqueName = '${baseName}_$timestamp$ext';

        // Copy image
        final destPath = p.join(targetDir, uniqueName);
        await sourceFile.copy(destPath);
        _log('Copied: $sourcePath -> $destPath');

        // Create caption file if caption is not empty
        if (caption.isNotEmpty) {
          final captionPath = p.join(
            targetDir,
            '${p.basenameWithoutExtension(uniqueName)}.txt',
          );
          await File(captionPath).writeAsString(caption);
          _log('Created caption: $captionPath');
        }
      } catch (e) {
        _logError('Failed to add image: $sourcePath', e);
      }
    }
  }

  /// Generate metadata files for the dataset
  /// Creates dataset.json and any format-specific metadata
  Future<void> generateMetadata(
    String datasetPath, {
    DatasetConfig? config,
  }) async {
    _log('Generating metadata for dataset at $datasetPath');

    try {
      // Scan for images
      final images = await _scanImages(datasetPath);

      // Create dataset.json
      final metadata = {
        'name': config?.name ?? p.basename(datasetPath),
        'format': config?.format.name ?? 'unknown',
        'resolution': config?.resolution.size ?? 512,
        'image_count': images.length,
        'repeat_count': config?.repeatCount ?? 1,
        'total_repeats': images.length * (config?.repeatCount ?? 1),
        'concept_name': config?.conceptName,
        'created_at': DateTime.now().toIso8601String(),
        'images': images.map((img) {
          final baseName = p.basenameWithoutExtension(img);
          final captionFile = p.join(p.dirname(img), '$baseName.txt');
          final hasCaption = File(captionFile).existsSync();
          return {
            'filename': p.basename(img),
            'has_caption': hasCaption,
          };
        }).toList(),
      };

      final metadataPath = p.join(datasetPath, 'dataset.json');
      await File(metadataPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(metadata),
      );
      _log('Created metadata file: $metadataPath');

      // Create format-specific files
      if (config?.format == DatasetFormat.onetrainer) {
        await _createOneTrainerMetadata(datasetPath, images, config);
      }
    } catch (e) {
      _logError('Failed to generate metadata', e);
      rethrow;
    }
  }

  /// Create OneTrainer-specific metadata files
  Future<void> _createOneTrainerMetadata(
    String datasetPath,
    List<String> images,
    DatasetConfig? config,
  ) async {
    // OneTrainer expects a specific structure
    // Create meta.json for OneTrainer compatibility
    final meta = {
      'dataset_type': 'IMAGE',
      'concept_type': 'STANDARD',
      'image_augmentations': {
        'crop_jitter': true,
        'random_flip': false,
      },
      'text_augmentations': {
        'shuffle_tokens': false,
        'token_dropout': 0.0,
      },
    };

    final metaPath = p.join(datasetPath, 'meta.json');
    await File(metaPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(meta),
    );
    _log('Created OneTrainer meta file: $metaPath');
  }

  /// Validate a dataset for training compatibility
  /// Returns DatasetInfo with validation issues
  Future<DatasetInfo> validateDataset(String datasetPath) async {
    _log('Validating dataset at $datasetPath');

    final issues = <DatasetIssue>[];
    int imageCount = 0;
    int captionedCount = 0;
    DatasetFormat format = DatasetFormat.simple;
    int repeatCount = 1;
    String? conceptName;

    try {
      final dir = Directory(datasetPath);
      if (!await dir.exists()) {
        issues.add(const DatasetIssue(
          severity: DatasetIssueSeverity.error,
          message: 'Dataset directory does not exist',
        ));
        return DatasetInfo(
          path: datasetPath,
          imageCount: 0,
          totalRepeats: 0,
          format: format,
          isValid: false,
          issues: issues,
        );
      }

      // Detect format
      final formatInfo = await _detectFormat(datasetPath);
      format = formatInfo['format'] as DatasetFormat;
      repeatCount = formatInfo['repeatCount'] as int? ?? 1;
      conceptName = formatInfo['conceptName'] as String?;

      // Scan for images
      final images = await _scanImages(datasetPath);
      imageCount = images.length;

      if (imageCount == 0) {
        issues.add(const DatasetIssue(
          severity: DatasetIssueSeverity.error,
          message: 'No images found in dataset',
        ));
      }

      // Check each image
      for (final imagePath in images) {
        final file = File(imagePath);

        // Check file size
        final stat = await file.stat();
        if (stat.size < 1024) {
          issues.add(DatasetIssue(
            severity: DatasetIssueSeverity.warning,
            message: 'Image file is very small (${stat.size} bytes)',
            filePath: imagePath,
          ));
        }

        // Check for caption
        final baseName = p.basenameWithoutExtension(imagePath);
        final captionPath = p.join(p.dirname(imagePath), '$baseName.txt');
        if (await File(captionPath).exists()) {
          captionedCount++;
          final captionContent = await File(captionPath).readAsString();
          if (captionContent.trim().isEmpty) {
            issues.add(DatasetIssue(
              severity: DatasetIssueSeverity.warning,
              message: 'Caption file is empty',
              filePath: captionPath,
            ));
          }
        }
      }

      // Check caption coverage
      if (imageCount > 0 && captionedCount == 0) {
        issues.add(const DatasetIssue(
          severity: DatasetIssueSeverity.warning,
          message: 'No captions found. Training may use generic prompts.',
        ));
      } else if (captionedCount < imageCount) {
        issues.add(DatasetIssue(
          severity: DatasetIssueSeverity.info,
          message: 'Only $captionedCount of $imageCount images have captions',
        ));
      }

      // Check for minimum image count
      if (imageCount > 0 && imageCount < 5) {
        issues.add(DatasetIssue(
          severity: DatasetIssueSeverity.warning,
          message: 'Very few images ($imageCount). Consider adding more for better results.',
        ));
      }

      _log('Validation complete: $imageCount images, ${issues.length} issues');
    } catch (e) {
      _logError('Validation failed', e);
      issues.add(DatasetIssue(
        severity: DatasetIssueSeverity.error,
        message: 'Validation error: $e',
      ));
    }

    final isValid = !issues.any((i) => i.severity == DatasetIssueSeverity.error);

    return DatasetInfo(
      path: datasetPath,
      imageCount: imageCount,
      totalRepeats: imageCount * repeatCount,
      format: format,
      isValid: isValid,
      issues: issues,
      captionedCount: captionedCount,
      conceptName: conceptName,
    );
  }

  /// Get information about an existing dataset
  Future<DatasetInfo> getDatasetInfo(String datasetPath) async {
    _log('Getting dataset info for: $datasetPath');

    // First validate to get all info
    final validationResult = await validateDataset(datasetPath);

    // Try to load additional metadata from dataset.json
    DatasetResolution? resolution;
    DateTime? createdAt;

    final metadataPath = p.join(datasetPath, 'dataset.json');
    if (await File(metadataPath).exists()) {
      try {
        final content = await File(metadataPath).readAsString();
        final metadata = json.decode(content) as Map<String, dynamic>;

        // Parse resolution
        final resValue = metadata['resolution'] as int?;
        if (resValue != null) {
          resolution = DatasetResolution.values.firstWhere(
            (r) => r.size == resValue,
            orElse: () => DatasetResolution.res512,
          );
        }

        // Parse creation date
        final createdAtStr = metadata['created_at'] as String?;
        if (createdAtStr != null) {
          createdAt = DateTime.tryParse(createdAtStr);
        }
      } catch (e) {
        _logError('Failed to parse metadata', e);
      }
    }

    return DatasetInfo(
      path: validationResult.path,
      imageCount: validationResult.imageCount,
      totalRepeats: validationResult.totalRepeats,
      format: validationResult.format,
      isValid: validationResult.isValid,
      issues: validationResult.issues,
      captionedCount: validationResult.captionedCount,
      resolution: resolution,
      conceptName: validationResult.conceptName,
      createdAt: createdAt,
    );
  }

  /// Scan directory for image files recursively
  Future<List<String>> _scanImages(String path) async {
    final images = <String>[];
    final dir = Directory(path);

    if (!await dir.exists()) {
      return images;
    }

    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (_imageExtensions.contains(ext)) {
            images.add(entity.path);
          }
        }
      }
    } catch (e) {
      _logError('Error scanning images', e);
    }

    return images;
  }

  /// Detect dataset format from directory structure
  Future<Map<String, dynamic>> _detectFormat(String path) async {
    final result = <String, dynamic>{
      'format': DatasetFormat.simple,
      'repeatCount': 1,
      'conceptName': null,
    };

    final dir = Directory(path);
    if (!await dir.exists()) {
      return result;
    }

    // Check for kohya_ss format: {repeats}_{concept} folders
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        final match = RegExp(r'^(\d+)_(.+)$').firstMatch(name);
        if (match != null) {
          result['format'] = DatasetFormat.kohyaSs;
          result['repeatCount'] = int.tryParse(match.group(1) ?? '1') ?? 1;
          result['conceptName'] = match.group(2);
          break;
        }
      }
    }

    // Check for OneTrainer format: meta.json presence
    final metaPath = p.join(path, 'meta.json');
    if (await File(metaPath).exists()) {
      result['format'] = DatasetFormat.onetrainer;
    }

    return result;
  }

  /// Update captions for existing images in a dataset
  Future<void> updateCaptions(
    String datasetPath,
    Map<String, String> captions,
  ) async {
    _log('Updating captions in dataset at $datasetPath');

    for (final entry in captions.entries) {
      final imagePath = entry.key;
      final caption = entry.value;

      final baseName = p.basenameWithoutExtension(imagePath);
      final captionPath = p.join(p.dirname(imagePath), '$baseName.txt');

      try {
        if (caption.isEmpty) {
          // Delete caption file if caption is empty
          final file = File(captionPath);
          if (await file.exists()) {
            await file.delete();
            _log('Deleted empty caption: $captionPath');
          }
        } else {
          await File(captionPath).writeAsString(caption);
          _log('Updated caption: $captionPath');
        }
      } catch (e) {
        _logError('Failed to update caption for $imagePath', e);
      }
    }

    // Regenerate metadata after caption updates
    await generateMetadata(datasetPath);
  }

  /// Remove images from a dataset
  Future<void> removeImages(
    String datasetPath,
    List<String> imagePaths,
  ) async {
    _log('Removing ${imagePaths.length} images from dataset at $datasetPath');

    for (final imagePath in imagePaths) {
      try {
        final imageFile = File(imagePath);
        if (await imageFile.exists()) {
          await imageFile.delete();
          _log('Deleted image: $imagePath');

          // Also delete associated caption
          final baseName = p.basenameWithoutExtension(imagePath);
          final captionPath = p.join(p.dirname(imagePath), '$baseName.txt');
          final captionFile = File(captionPath);
          if (await captionFile.exists()) {
            await captionFile.delete();
            _log('Deleted caption: $captionPath');
          }
        }
      } catch (e) {
        _logError('Failed to remove image: $imagePath', e);
      }
    }

    // Regenerate metadata after removal
    await generateMetadata(datasetPath);
  }

  /// Export dataset to a different format
  Future<DatasetInfo> exportDataset(
    String sourcePath,
    String destPath, {
    required DatasetFormat targetFormat,
    int repeatCount = 1,
    String? conceptName,
  }) async {
    _log('Exporting dataset from $sourcePath to $destPath (format: $targetFormat)');

    // Get current dataset info
    final sourceInfo = await getDatasetInfo(sourcePath);

    // Scan for images
    final images = await _scanImages(sourcePath);

    // Load captions
    final captions = <String, String>{};
    for (final imagePath in images) {
      final baseName = p.basenameWithoutExtension(imagePath);
      final captionPath = p.join(p.dirname(imagePath), '$baseName.txt');
      final captionFile = File(captionPath);
      if (await captionFile.exists()) {
        captions[imagePath] = await captionFile.readAsString();
      }
    }

    // Create new dataset with target format
    final config = DatasetConfig(
      name: p.basename(destPath),
      outputPath: p.dirname(destPath),
      images: images,
      captions: captions,
      format: targetFormat,
      resolution: sourceInfo.resolution ?? DatasetResolution.res512,
      repeatCount: repeatCount,
      conceptName: conceptName ?? sourceInfo.conceptName,
    );

    return await createDataset(config);
  }
}
