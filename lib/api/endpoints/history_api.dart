import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

import '../../core/program.dart';
import '../api.dart';
import '../api_call.dart';
import '../api_context.dart';

/// History and output management API endpoints
class HistoryAPI {
  /// Register all history API endpoints
  static void register() {
    // Output browsing
    Api.registerCall(ApiCall(
      name: 'ListOutputFolders',
      description: 'List output folder structure',
      requiredPermissions: {'user'},
      handler: _listOutputFolders,
    ));

    Api.registerCall(ApiCall(
      name: 'ListOutputImages',
      description: 'List images in output folder',
      requiredPermissions: {'user'},
      handler: _listOutputImages,
    ));

    Api.registerCall(ApiCall(
      name: 'GetOutputImage',
      description: 'Get a specific output image',
      requiredPermissions: {'user'},
      handler: _getOutputImage,
    ));

    Api.registerCall(ApiCall(
      name: 'DeleteOutputImage',
      description: 'Delete an output image',
      requiredPermissions: {'user'},
      handler: _deleteOutputImage,
    ));

    // Generation history
    Api.registerCall(ApiCall(
      name: 'GetGenerationHistory',
      description: 'Get generation history',
      requiredPermissions: {'user'},
      handler: _getGenerationHistory,
    ));

    Api.registerCall(ApiCall(
      name: 'GetGenerationDetails',
      description: 'Get details of a generation',
      requiredPermissions: {'user'},
      handler: _getGenerationDetails,
    ));

    Api.registerCall(ApiCall(
      name: 'DeleteGenerationHistory',
      description: 'Delete generation history entry',
      requiredPermissions: {'user'},
      handler: _deleteGenerationHistory,
    ));

    Api.registerCall(ApiCall(
      name: 'ClearGenerationHistory',
      description: 'Clear all generation history',
      requiredPermissions: {'admin'},
      handler: _clearGenerationHistory,
    ));

    // Favorites and collections
    Api.registerCall(ApiCall(
      name: 'AddToFavorites',
      description: 'Add image to favorites',
      requiredPermissions: {'user'},
      handler: _addToFavorites,
    ));

    Api.registerCall(ApiCall(
      name: 'RemoveFromFavorites',
      description: 'Remove image from favorites',
      requiredPermissions: {'user'},
      handler: _removeFromFavorites,
    ));

    Api.registerCall(ApiCall(
      name: 'ListFavorites',
      description: 'List favorite images',
      requiredPermissions: {'user'},
      handler: _listFavorites,
    ));

    // Image operations
    Api.registerCall(ApiCall(
      name: 'GetImageMetadata',
      description: 'Get metadata embedded in image',
      requiredPermissions: {'user'},
      handler: _getImageMetadata,
    ));

    Api.registerCall(ApiCall(
      name: 'MoveImage',
      description: 'Move image to different folder',
      requiredPermissions: {'user'},
      handler: _moveImage,
    ));

    Api.registerCall(ApiCall(
      name: 'RenameImage',
      description: 'Rename an image',
      requiredPermissions: {'user'},
      handler: _renameImage,
    ));

    // Search
    Api.registerCall(ApiCall(
      name: 'SearchImages',
      description: 'Search images by metadata',
      requiredPermissions: {'user'},
      handler: _searchImages,
    ));
  }

  // ========== OUTPUT BROWSING ==========

  /// List output folders
  static Future<Map<String, dynamic>> _listOutputFolders(ApiContext ctx) async {
    final outputPath = Program.instance.serverSettings.paths.outputPath;
    final dir = Directory(outputPath);

    if (!await dir.exists()) {
      return {'folders': <Map<String, dynamic>>[]};
    }

    final folders = <Map<String, dynamic>>[];

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is Directory) {
        final name = path.basename(entity.path);
        final imageCount = await _countImagesInFolder(entity.path);

        folders.add({
          'name': name,
          'path': entity.path,
          'image_count': imageCount,
          'modified': (await entity.stat()).modified.toIso8601String(),
        });
      }
    }

    // Sort by modified date (newest first)
    folders.sort((a, b) => (b['modified'] as String).compareTo(a['modified'] as String));

    return {'folders': folders};
  }

  /// List images in folder
  static Future<Map<String, dynamic>> _listOutputImages(ApiContext ctx) async {
    final folder = ctx.getOr<String>('folder', '');
    final limit = ctx.getOr<int>('limit', 50);
    final offset = ctx.getOr<int>('offset', 0);
    final sortBy = ctx.getOr<String>('sort', 'date'); // date, name, size
    final sortOrder = ctx.getOr<String>('order', 'desc'); // asc, desc

    final outputPath = Program.instance.serverSettings.paths.outputPath;
    final targetPath = folder.isEmpty ? outputPath : path.join(outputPath, folder);
    final dir = Directory(targetPath);

    if (!await dir.exists()) {
      return {'images': <Map<String, dynamic>>[], 'total': 0};
    }

    final images = <Map<String, dynamic>>[];

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) {
        final ext = path.extension(entity.path).toLowerCase();
        if (['.png', '.jpg', '.jpeg', '.webp', '.gif'].contains(ext)) {
          final stat = await entity.stat();
          final name = path.basename(entity.path);

          images.add({
            'name': name,
            'path': entity.path,
            'size': stat.size,
            'modified': stat.modified.toIso8601String(),
            'thumbnail': _getThumbnailPath(entity.path),
          });
        }
      }
    }

    // Sort
    images.sort((a, b) {
      int result;
      switch (sortBy) {
        case 'name':
          result = (a['name'] as String).compareTo(b['name'] as String);
          break;
        case 'size':
          result = (a['size'] as int).compareTo(b['size'] as int);
          break;
        case 'date':
        default:
          result = (a['modified'] as String).compareTo(b['modified'] as String);
      }
      return sortOrder == 'asc' ? result : -result;
    });

    final total = images.length;
    final paged = images.skip(offset).take(limit).toList();

    return {
      'images': paged,
      'total': total,
      'offset': offset,
      'limit': limit,
    };
  }

  /// Get output image
  static Future<Map<String, dynamic>> _getOutputImage(ApiContext ctx) async {
    final imagePath = ctx.require<String>('path');
    final includeData = ctx.getOr<bool>('include_data', false);

    final file = File(imagePath);
    if (!await file.exists()) {
      return {'success': false, 'error': 'Image not found'};
    }

    final stat = await file.stat();
    final name = path.basename(imagePath);

    final result = <String, dynamic>{
      'success': true,
      'name': name,
      'path': imagePath,
      'size': stat.size,
      'modified': stat.modified.toIso8601String(),
    };

    if (includeData) {
      final bytes = await file.readAsBytes();
      result['data'] = base64Encode(bytes);
    }

    // Try to read metadata
    final metadata = await _readImageMetadata(file);
    if (metadata != null) {
      result['metadata'] = metadata;
    }

    return result;
  }

  /// Delete output image
  static Future<Map<String, dynamic>> _deleteOutputImage(ApiContext ctx) async {
    final imagePath = ctx.require<String>('path');
    final file = File(imagePath);

    if (!await file.exists()) {
      return {'success': false, 'error': 'Image not found'};
    }

    // Security check: ensure path is within output folder
    final outputPath = Program.instance.serverSettings.paths.outputPath;
    if (!path.isWithin(outputPath, imagePath)) {
      return {'success': false, 'error': 'Invalid path'};
    }

    await file.delete();

    // Also delete thumbnail if exists
    final thumbPath = _getThumbnailPath(imagePath);
    final thumbFile = File(thumbPath);
    if (await thumbFile.exists()) {
      await thumbFile.delete();
    }

    return {'success': true};
  }

  // ========== GENERATION HISTORY ==========

  /// In-memory history (would use database in production)
  static final List<GenerationRecord> _history = [];
  static final Set<String> _favorites = {};

  /// Get generation history
  static Future<Map<String, dynamic>> _getGenerationHistory(ApiContext ctx) async {
    final session = ctx.requireSession();
    final limit = ctx.getOr<int>('limit', 50);
    final offset = ctx.getOr<int>('offset', 0);

    // Filter to user's history
    final userHistory = _history.where((r) => r.userId == session.userId).toList();

    // Sort by date (newest first)
    userHistory.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final paged = userHistory.skip(offset).take(limit).toList();

    return {
      'history': paged.map((r) => r.toJson()).toList(),
      'total': userHistory.length,
      'offset': offset,
      'limit': limit,
    };
  }

  /// Get generation details
  static Future<Map<String, dynamic>> _getGenerationDetails(ApiContext ctx) async {
    final id = ctx.require<String>('id');

    final record = _history.firstWhere(
      (r) => r.id == id,
      orElse: () => throw ApiException('Record not found', 404),
    );

    return {
      'success': true,
      'record': record.toJson(),
    };
  }

  /// Delete generation history entry
  static Future<Map<String, dynamic>> _deleteGenerationHistory(ApiContext ctx) async {
    final id = ctx.require<String>('id');

    final index = _history.indexWhere((r) => r.id == id);
    if (index == -1) {
      return {'success': false, 'error': 'Record not found'};
    }

    _history.removeAt(index);
    return {'success': true};
  }

  /// Clear all generation history
  static Future<Map<String, dynamic>> _clearGenerationHistory(ApiContext ctx) async {
    final count = _history.length;
    _history.clear();
    return {'success': true, 'cleared': count};
  }

  // ========== FAVORITES ==========

  /// Add to favorites
  static Future<Map<String, dynamic>> _addToFavorites(ApiContext ctx) async {
    final imagePath = ctx.require<String>('path');
    _favorites.add(imagePath);
    return {'success': true};
  }

  /// Remove from favorites
  static Future<Map<String, dynamic>> _removeFromFavorites(ApiContext ctx) async {
    final imagePath = ctx.require<String>('path');
    _favorites.remove(imagePath);
    return {'success': true};
  }

  /// List favorites
  static Future<Map<String, dynamic>> _listFavorites(ApiContext ctx) async {
    final favorites = <Map<String, dynamic>>[];

    for (final imagePath in _favorites) {
      final file = File(imagePath);
      if (await file.exists()) {
        final stat = await file.stat();
        favorites.add({
          'path': imagePath,
          'name': path.basename(imagePath),
          'size': stat.size,
          'modified': stat.modified.toIso8601String(),
        });
      }
    }

    return {'favorites': favorites};
  }

  // ========== IMAGE OPERATIONS ==========

  /// Get image metadata
  static Future<Map<String, dynamic>> _getImageMetadata(ApiContext ctx) async {
    final imagePath = ctx.require<String>('path');
    final file = File(imagePath);

    if (!await file.exists()) {
      return {'success': false, 'error': 'Image not found'};
    }

    final metadata = await _readImageMetadata(file);

    return {
      'success': true,
      'metadata': metadata ?? {},
    };
  }

  /// Move image
  static Future<Map<String, dynamic>> _moveImage(ApiContext ctx) async {
    final sourcePath = ctx.require<String>('path');
    final destFolder = ctx.require<String>('destination');

    final file = File(sourcePath);
    if (!await file.exists()) {
      return {'success': false, 'error': 'Image not found'};
    }

    final outputPath = Program.instance.serverSettings.paths.outputPath;
    final destPath = path.join(outputPath, destFolder, path.basename(sourcePath));

    // Ensure destination folder exists
    await Directory(path.dirname(destPath)).create(recursive: true);

    // Move file
    await file.rename(destPath);

    return {'success': true, 'new_path': destPath};
  }

  /// Rename image
  static Future<Map<String, dynamic>> _renameImage(ApiContext ctx) async {
    final imagePath = ctx.require<String>('path');
    final newName = ctx.require<String>('name');

    final file = File(imagePath);
    if (!await file.exists()) {
      return {'success': false, 'error': 'Image not found'};
    }

    final ext = path.extension(imagePath);
    final newPath = path.join(path.dirname(imagePath), newName + ext);

    await file.rename(newPath);

    return {'success': true, 'new_path': newPath};
  }

  // ========== SEARCH ==========

  /// Search images by metadata
  static Future<Map<String, dynamic>> _searchImages(ApiContext ctx) async {
    final query = ctx.require<String>('query');
    final searchIn = ctx.getOr<List<String>>('search_in', ['prompt', 'model', 'filename']);
    final limit = ctx.getOr<int>('limit', 50);

    final outputPath = Program.instance.serverSettings.paths.outputPath;
    final dir = Directory(outputPath);

    if (!await dir.exists()) {
      return {'results': <Map<String, dynamic>>[], 'total': 0};
    }

    final results = <Map<String, dynamic>>[];
    final lowerQuery = query.toLowerCase();

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final ext = path.extension(entity.path).toLowerCase();
        if (!['.png', '.jpg', '.jpeg', '.webp'].contains(ext)) continue;

        bool matches = false;

        // Search in filename
        if (searchIn.contains('filename')) {
          if (path.basename(entity.path).toLowerCase().contains(lowerQuery)) {
            matches = true;
          }
        }

        // Search in metadata
        if (!matches && (searchIn.contains('prompt') || searchIn.contains('model'))) {
          final metadata = await _readImageMetadata(entity);
          if (metadata != null) {
            if (searchIn.contains('prompt')) {
              final prompt = metadata['prompt']?.toString().toLowerCase() ?? '';
              if (prompt.contains(lowerQuery)) matches = true;
            }
            if (searchIn.contains('model') && !matches) {
              final model = metadata['model']?.toString().toLowerCase() ?? '';
              if (model.contains(lowerQuery)) matches = true;
            }
          }
        }

        if (matches) {
          final stat = await entity.stat();
          results.add({
            'path': entity.path,
            'name': path.basename(entity.path),
            'size': stat.size,
            'modified': stat.modified.toIso8601String(),
          });

          if (results.length >= limit) break;
        }
      }
    }

    return {
      'results': results,
      'total': results.length,
      'query': query,
    };
  }

  // ========== HELPERS ==========

  static Future<int> _countImagesInFolder(String folderPath) async {
    int count = 0;
    final dir = Directory(folderPath);

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) {
        final ext = path.extension(entity.path).toLowerCase();
        if (['.png', '.jpg', '.jpeg', '.webp', '.gif'].contains(ext)) {
          count++;
        }
      }
    }

    return count;
  }

  static String _getThumbnailPath(String imagePath) {
    final dir = path.dirname(imagePath);
    final name = path.basenameWithoutExtension(imagePath);
    return path.join(dir, '.thumbnails', '$name.webp');
  }

  static Future<Map<String, dynamic>?> _readImageMetadata(File file) async {
    try {
      final bytes = await file.readAsBytes();

      // Check for PNG
      if (bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50) {
        return _readPngMetadata(bytes);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic>? _readPngMetadata(List<int> bytes) {
    // Simple PNG metadata reader
    // Look for tEXt chunks containing generation params

    try {
      int pos = 8; // Skip PNG signature

      while (pos + 12 < bytes.length) {
        // Read chunk length
        final length = (bytes[pos] << 24) |
            (bytes[pos + 1] << 16) |
            (bytes[pos + 2] << 8) |
            bytes[pos + 3];
        pos += 4;

        // Read chunk type
        final type = String.fromCharCodes(bytes.sublist(pos, pos + 4));
        pos += 4;

        if (type == 'tEXt' || type == 'iTXt') {
          // Read chunk data
          final data = bytes.sublist(pos, pos + length);
          final text = String.fromCharCodes(data);

          // Look for known metadata formats
          if (text.contains('parameters') || text.contains('prompt')) {
            // Parse SwarmUI/A1111 format
            return _parseGenerationParams(text);
          }
        } else if (type == 'IEND') {
          break;
        }

        pos += length + 4; // Skip data and CRC
      }
    } catch (e) {
      // Ignore parsing errors
    }

    return null;
  }

  static Map<String, dynamic>? _parseGenerationParams(String text) {
    final result = <String, dynamic>{};

    // Try to extract prompt
    final promptMatch = RegExp(r'(?:prompt[:\s]+)?(.+?)(?:Negative prompt:|Steps:|$)', dotAll: true).firstMatch(text);
    if (promptMatch != null) {
      result['prompt'] = promptMatch.group(1)?.trim();
    }

    // Extract negative prompt
    final negMatch = RegExp(r'Negative prompt:\s*(.+?)(?:Steps:|$)', dotAll: true).firstMatch(text);
    if (negMatch != null) {
      result['negative_prompt'] = negMatch.group(1)?.trim();
    }

    // Extract other parameters
    final paramsMatch = RegExp(r'Steps:\s*(\d+)').firstMatch(text);
    if (paramsMatch != null) {
      result['steps'] = int.parse(paramsMatch.group(1)!);
    }

    final cfgMatch = RegExp(r'CFG scale:\s*([\d.]+)').firstMatch(text);
    if (cfgMatch != null) {
      result['cfg_scale'] = double.parse(cfgMatch.group(1)!);
    }

    final seedMatch = RegExp(r'Seed:\s*(\d+)').firstMatch(text);
    if (seedMatch != null) {
      result['seed'] = int.parse(seedMatch.group(1)!);
    }

    final modelMatch = RegExp(r'Model:\s*([^,\n]+)').firstMatch(text);
    if (modelMatch != null) {
      result['model'] = modelMatch.group(1)?.trim();
    }

    final sizeMatch = RegExp(r'Size:\s*(\d+)x(\d+)').firstMatch(text);
    if (sizeMatch != null) {
      result['width'] = int.parse(sizeMatch.group(1)!);
      result['height'] = int.parse(sizeMatch.group(2)!);
    }

    return result.isEmpty ? null : result;
  }

  /// Add generation record
  static void addGenerationRecord(GenerationRecord record) {
    _history.add(record);

    // Limit history size
    if (_history.length > 10000) {
      _history.removeRange(0, 1000);
    }
  }
}

/// Generation record
class GenerationRecord {
  final String id;
  final String userId;
  final DateTime createdAt;
  final Map<String, dynamic> params;
  final List<String> outputPaths;
  final String status; // completed, failed, cancelled
  final int durationMs;
  final String? error;

  GenerationRecord({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.params,
    required this.outputPaths,
    required this.status,
    required this.durationMs,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'created_at': createdAt.toIso8601String(),
    'params': params,
    'output_paths': outputPaths,
    'status': status,
    'duration_ms': durationMs,
    'error': error,
  };
}
