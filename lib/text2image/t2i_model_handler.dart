import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

import '../utils/logging.dart';
import 't2i_model.dart';
import 't2i_model_class.dart';

/// Manages models of a specific type
/// Equivalent to SwarmUI's T2IModelHandler
class T2IModelHandler {
  /// Model type (e.g., 'Stable-Diffusion', 'LoRA', 'VAE')
  final String modelType;

  /// Folder paths to scan for models
  final List<String> folderPaths;

  /// All loaded models
  final Map<String, T2IModel> models = {};

  /// Metadata database boxes (per folder)
  final Map<String, Box<Map>> _metadataBoxes = {};

  /// Valid model file extensions
  static const _validExtensions = [
    '.safetensors',
    '.ckpt',
    '.pt',
    '.pth',
    '.bin',
    '.gguf',
  ];

  T2IModelHandler({
    required this.modelType,
    required this.folderPaths,
  });

  /// Refresh model list by scanning folders
  Future<void> refresh() async {
    models.clear();

    for (final folderPath in folderPaths) {
      await _scanFolder(folderPath);
    }

    Logs.info('Loaded ${models.length} $modelType models');
  }

  /// Scan a folder for models
  Future<void> _scanFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      Logs.debug('Model folder does not exist: $folderPath');
      return;
    }

    // Open metadata database for this folder
    final metaBox = await _getMetadataBox(folderPath);

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      final ext = p.extension(entity.path).toLowerCase();
      if (!_validExtensions.contains(ext)) continue;

      try {
        final relativePath = p.relative(entity.path, from: folderPath);
        final name = relativePath.replaceAll('\\', '/');

        // Check for existing metadata
        final existing = metaBox.get(name);
        T2IModel model;

        if (existing != null) {
          // Load from cache
          model = T2IModel.fromJson(
            Map<String, dynamic>.from(existing),
            entity.path,
          );
        } else {
          // Create new entry
          model = T2IModel(
            name: name,
            type: modelType,
            filePath: entity.path,
          );

          // Extract metadata from file
          await _extractMetadata(model, entity);

          // Save to database
          await metaBox.put(name, model.toJson());
        }

        models[name] = model;
      } catch (e) {
        Logs.warning('Error loading model ${entity.path}: $e');
      }
    }
  }

  /// Extract metadata from model file
  Future<void> _extractMetadata(T2IModel model, File file) async {
    final ext = p.extension(file.path).toLowerCase();

    try {
      if (ext == '.safetensors') {
        await _extractSafetensorsMetadata(model, file);
      } else if (ext == '.ckpt' || ext == '.pt' || ext == '.pth') {
        // Pickle files - limited metadata extraction
        model.metadata = T2IModelMetadata();
        // Try to detect model class from file size
        final size = await file.length();
        model.modelClass = T2IModelClassSorter.detectFromSize(size);
      }
    } catch (e) {
      Logs.debug('Failed to extract metadata from ${model.name}: $e');
    }

    // Try to load preview image
    await _loadPreviewImage(model, file);

    // Try to load metadata JSON
    await _loadMetadataJson(model, file);
  }

  /// Extract metadata from safetensors file
  Future<void> _extractSafetensorsMetadata(T2IModel model, File file) async {
    final raf = await file.open(mode: FileMode.read);

    try {
      // Read header length (first 8 bytes, little-endian)
      final headerLenBytes = await raf.read(8);
      final headerLen = ByteData.view(Uint8List.fromList(headerLenBytes).buffer)
          .getUint64(0, Endian.little);

      // Sanity check header length (max 100MB)
      if (headerLen > 100 * 1024 * 1024) {
        Logs.warning('Safetensors header too large: $headerLen bytes');
        return;
      }

      // Read header JSON
      final headerBytes = await raf.read(headerLen.toInt());
      final headerStr = utf8.decode(headerBytes);
      final header = jsonDecode(headerStr) as Map<String, dynamic>;

      // Extract __metadata__ section
      final metadata = header['__metadata__'] as Map<String, dynamic>?;
      if (metadata != null) {
        model.metadata = T2IModelMetadata.fromSafetensors(metadata);

        // Extract title and author if present
        model.title = metadata['modelspec.title'] as String? ??
            metadata['ss_base_model_name'] as String?;
        model.author = metadata['modelspec.author'] as String? ??
            metadata['ss_training_user'] as String?;
        model.description = metadata['modelspec.description'] as String?;
      }

      // Detect model class from tensor shapes
      model.modelClass = T2IModelClassSorter.detectFromHeader(header);

    } finally {
      await raf.close();
    }
  }

  /// Load preview image for model
  Future<void> _loadPreviewImage(T2IModel model, File modelFile) async {
    final basePath = p.withoutExtension(modelFile.path);

    // Try various preview extensions
    for (final ext in ['.preview.png', '.png', '.jpg', '.jpeg', '.webp']) {
      final previewPath = '$basePath$ext';
      if (await File(previewPath).exists()) {
        model.previewImage = previewPath;
        return;
      }
    }

    // Also try in .preview folder
    final dir = p.dirname(modelFile.path);
    final name = p.basenameWithoutExtension(modelFile.path);
    for (final ext in ['.png', '.jpg', '.jpeg', '.webp']) {
      final previewPath = p.join(dir, '.preview', '$name$ext');
      if (await File(previewPath).exists()) {
        model.previewImage = previewPath;
        return;
      }
    }
  }

  /// Load metadata JSON file
  Future<void> _loadMetadataJson(T2IModel model, File modelFile) async {
    final basePath = p.withoutExtension(modelFile.path);

    // Try .swarm.json first (SwarmUI format)
    var jsonPath = '$basePath.swarm.json';
    var jsonFile = File(jsonPath);

    if (!await jsonFile.exists()) {
      // Try .json
      jsonPath = '$basePath.json';
      jsonFile = File(jsonPath);
    }

    if (await jsonFile.exists()) {
      try {
        final content = await jsonFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        // Apply JSON data
        model.title ??= data['title'] as String?;
        model.author ??= data['author'] as String?;
        model.description ??= data['description'] as String?;

        if (data['trigger_phrase'] != null) {
          model.metadata ??= T2IModelMetadata();
          model.metadata!.triggerPhrase = data['trigger_phrase'] as String?;
        }

      } catch (e) {
        Logs.debug('Failed to parse metadata JSON for ${model.name}: $e');
      }
    }
  }

  /// Get metadata database for a folder
  Future<Box<Map>> _getMetadataBox(String folderPath) async {
    if (_metadataBoxes.containsKey(folderPath)) {
      return _metadataBoxes[folderPath]!;
    }

    final boxName = 'model_meta_${folderPath.hashCode.abs()}';
    final box = await Hive.openBox<Map>(boxName);
    _metadataBoxes[folderPath] = box;
    return box;
  }

  /// Get a model by name
  T2IModel? getModel(String name) => models[name];

  /// Get models matching a pattern
  List<T2IModel> findModels(String pattern) {
    final lowerPattern = pattern.toLowerCase();
    return models.values
        .where((m) => m.name.toLowerCase().contains(lowerPattern))
        .toList();
  }

  /// Get all model names
  List<String> get modelNames => models.keys.toList()..sort();

  /// Get models in a specific folder
  List<T2IModel> getModelsInFolder(String folder) {
    return models.values
        .where((m) => m.name.startsWith(folder))
        .toList();
  }

  /// Get list of all folders
  Set<String> get folders {
    final result = <String>{};
    for (final name in models.keys) {
      final parts = name.split('/');
      for (var i = 0; i < parts.length - 1; i++) {
        result.add(parts.sublist(0, i + 1).join('/'));
      }
    }
    return result;
  }

  /// Shutdown and cleanup
  void shutdown() {
    for (final box in _metadataBoxes.values) {
      box.close();
    }
    _metadataBoxes.clear();
  }

  /// Get all models as list
  Future<List<T2IModel>> getModelsOfType(String type) async {
    if (modelType != type) {
      return [];
    }
    return models.values.toList();
  }
}

/// Composite model handler that searches across multiple types
class CompositeModelHandler {
  final Map<String, T2IModelHandler> handlers;

  CompositeModelHandler(this.handlers);

  /// Get models of a specific type
  Future<List<T2IModel>> getModelsOfType(String type) async {
    final handler = handlers[type];
    if (handler == null) {
      return [];
    }
    return handler.models.values.toList();
  }

  /// Get all models across all types
  Future<List<T2IModel>> getAllModels() async {
    final result = <T2IModel>[];
    for (final handler in handlers.values) {
      result.addAll(handler.models.values);
    }
    return result;
  }

  /// Get a specific model by name and type
  T2IModel? getModel(String type, String name) {
    return handlers[type]?.getModel(name);
  }

  /// Search models across all types
  List<T2IModel> searchModels(String pattern, {String? type}) {
    final results = <T2IModel>[];
    final lowerPattern = pattern.toLowerCase();

    for (final entry in handlers.entries) {
      if (type != null && entry.key != type) continue;

      for (final model in entry.value.models.values) {
        if (model.name.toLowerCase().contains(lowerPattern) ||
            (model.title?.toLowerCase().contains(lowerPattern) ?? false)) {
          results.add(model);
        }
      }
    }

    return results;
  }
}
