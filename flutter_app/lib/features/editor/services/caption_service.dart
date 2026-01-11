import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../models/caption_models.dart';
import '../models/editor_models.dart';

/// Caption service provider
final captionServiceProvider = Provider<CaptionService>((ref) {
  return CaptionService();
});

/// Caption settings provider - persists caption configuration
final captionSettingsProvider = StateNotifierProvider<CaptionSettingsNotifier, CaptionSettings>((ref) {
  return CaptionSettingsNotifier();
});

/// Caption progress provider - tracks batch captioning progress
final captionProgressProvider = StateNotifierProvider<CaptionProgressNotifier, CaptionProgress>((ref) {
  return CaptionProgressNotifier();
});

/// Format for saving captions
enum CaptionFormat {
  /// One .txt file per image with same base name
  txt,

  /// Single JSON file containing all captions
  json,

  /// CSV file with path and caption columns
  csv,
}

/// Backend type for captioning
enum CaptionBackend {
  /// OneTrainer Qwen VL captioning (recommended)
  qwen,

  /// Local SwarmUI captioning endpoint
  local,

  /// Generic REST API for external services
  api,

  /// Placeholder that returns filename as caption (for testing)
  placeholder,
}

/// Settings for caption generation
class CaptionSettings {
  /// API endpoint URL for captioning
  final String apiEndpoint;

  /// Which captioning model to use
  final String modelName;

  /// Maximum caption length in characters
  final int maxLength;

  /// Optional prefix for all captions (e.g., "a photo of")
  final String prefix;

  /// Optional suffix for all captions
  final String suffix;

  /// Backend to use for captioning
  final CaptionBackend backend;

  /// Request timeout in seconds
  final int timeoutSeconds;

  /// Whether to include filename hints in caption prompt
  final bool useFilenameHints;

  /// Prompt for Qwen captioning
  final String captionPrompt;

  const CaptionSettings({
    this.apiEndpoint = 'http://localhost:8100',
    this.modelName = 'Qwen/Qwen2.5-VL-7B-Instruct',
    this.maxLength = 256,
    this.prefix = '',
    this.suffix = '',
    this.backend = CaptionBackend.qwen,
    this.timeoutSeconds = 120,
    this.useFilenameHints = false,
    this.captionPrompt = 'Describe this image in detail.',
  });

  CaptionSettings copyWith({
    String? apiEndpoint,
    String? modelName,
    int? maxLength,
    String? prefix,
    String? suffix,
    CaptionBackend? backend,
    int? timeoutSeconds,
    bool? useFilenameHints,
    String? captionPrompt,
  }) {
    return CaptionSettings(
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
      modelName: modelName ?? this.modelName,
      maxLength: maxLength ?? this.maxLength,
      prefix: prefix ?? this.prefix,
      suffix: suffix ?? this.suffix,
      backend: backend ?? this.backend,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      useFilenameHints: useFilenameHints ?? this.useFilenameHints,
      captionPrompt: captionPrompt ?? this.captionPrompt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiEndpoint': apiEndpoint,
      'modelName': modelName,
      'maxLength': maxLength,
      'prefix': prefix,
      'suffix': suffix,
      'backend': backend.name,
      'timeoutSeconds': timeoutSeconds,
      'useFilenameHints': useFilenameHints,
      'captionPrompt': captionPrompt,
    };
  }

  factory CaptionSettings.fromJson(Map<String, dynamic> json) {
    return CaptionSettings(
      apiEndpoint: json['apiEndpoint'] as String? ?? 'http://localhost:8100',
      modelName: json['modelName'] as String? ?? 'Qwen/Qwen2.5-VL-7B-Instruct',
      maxLength: json['maxLength'] as int? ?? 256,
      prefix: json['prefix'] as String? ?? '',
      suffix: json['suffix'] as String? ?? '',
      backend: CaptionBackend.values.firstWhere(
        (b) => b.name == json['backend'],
        orElse: () => CaptionBackend.qwen,
      ),
      timeoutSeconds: json['timeoutSeconds'] as int? ?? 120,
      useFilenameHints: json['useFilenameHints'] as bool? ?? false,
      captionPrompt: json['captionPrompt'] as String? ?? 'Describe this image in detail.',
    );
  }
}

/// Caption progress state
class CaptionProgress {
  /// Total number of images to caption
  final int total;

  /// Number of images completed
  final int completed;

  /// Number of images that failed
  final int failed;

  /// Current image being processed
  final String? currentImage;

  /// Whether captioning is in progress
  final bool isProcessing;

  /// Error message if any
  final String? error;

  /// List of failed image paths
  final List<String> failedPaths;

  const CaptionProgress({
    this.total = 0,
    this.completed = 0,
    this.failed = 0,
    this.currentImage,
    this.isProcessing = false,
    this.error,
    this.failedPaths = const [],
  });

  double get progress => total > 0 ? completed / total : 0.0;

  bool get hasErrors => failed > 0 || error != null;

  CaptionProgress copyWith({
    int? total,
    int? completed,
    int? failed,
    String? currentImage,
    bool? isProcessing,
    String? error,
    List<String>? failedPaths,
  }) {
    return CaptionProgress(
      total: total ?? this.total,
      completed: completed ?? this.completed,
      failed: failed ?? this.failed,
      currentImage: currentImage ?? this.currentImage,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
      failedPaths: failedPaths ?? this.failedPaths,
    );
  }
}

/// Result from a caption operation
class CaptionResult {
  /// Whether the operation was successful
  final bool success;

  /// Generated caption (if successful)
  final String? caption;

  /// Error message (if failed)
  final String? error;

  const CaptionResult({
    required this.success,
    this.caption,
    this.error,
  });

  factory CaptionResult.success(String caption) {
    return CaptionResult(success: true, caption: caption);
  }

  factory CaptionResult.failure(String error) {
    return CaptionResult(success: false, error: error);
  }
}

/// Caption service for auto-captioning images
class CaptionService {
  static const String _tag = 'CaptionService';

  late Dio _dio;
  CaptionSettings _settings = const CaptionSettings();

  CaptionService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(seconds: 30),
    ));
  }

  /// Configure the service with settings
  void configure(CaptionSettings settings) {
    _settings = settings;
    _dio.options.baseUrl = settings.apiEndpoint;
    _dio.options.receiveTimeout = Duration(seconds: settings.timeoutSeconds);
  }

  /// Get current settings
  CaptionSettings get settings => _settings;

  /// Log a debug message
  void _log(String message) {
    print('[$_tag] $message');
  }

  /// Log an error message
  void _logError(String message, [Object? error]) {
    print('[$_tag] ERROR: $message${error != null ? ' - $error' : ''}');
  }

  /// Caption a single image
  /// Returns the generated caption text
  Future<String> captionImage(String imagePath) async {
    _log('Captioning image: $imagePath');

    final result = await _captionImageInternal(imagePath);
    if (result.success) {
      return result.caption!;
    }
    throw Exception(result.error ?? 'Failed to caption image');
  }

  /// Caption a single image with result object
  Future<CaptionResult> captionImageWithResult(String imagePath) async {
    return _captionImageInternal(imagePath);
  }

  /// Internal captioning implementation
  Future<CaptionResult> _captionImageInternal(String imagePath) async {
    // Verify file exists
    final file = File(imagePath);
    if (!await file.exists()) {
      return CaptionResult.failure('Image file not found: $imagePath');
    }

    try {
      switch (_settings.backend) {
        case CaptionBackend.qwen:
          return _captionQwen(imagePath);
        case CaptionBackend.placeholder:
          return _captionPlaceholder(imagePath);
        case CaptionBackend.local:
          return _captionLocal(imagePath);
        case CaptionBackend.api:
          return _captionApi(imagePath);
      }
    } catch (e) {
      _logError('Caption failed for $imagePath', e);
      return CaptionResult.failure(e.toString());
    }
  }

  /// Placeholder captioning - returns filename as caption
  Future<CaptionResult> _captionPlaceholder(String imagePath) async {
    final filename = path.basenameWithoutExtension(imagePath);
    // Clean up filename to make it more caption-like
    final caption = filename
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final fullCaption = _applyPrefixSuffix(caption);
    _log('Placeholder caption: $fullCaption');
    return CaptionResult.success(fullCaption);
  }

  /// OneTrainer Qwen VL captioning - uses file path directly
  Future<CaptionResult> _captionQwen(String imagePath) async {
    _log('Calling OneTrainer Qwen captioning endpoint');

    try {
      // First check if model is loaded
      final stateResponse = await _dio.get(
        '${_settings.apiEndpoint}/caption/state',
      );

      if (stateResponse.statusCode == 200) {
        final stateData = stateResponse.data as Map<String, dynamic>;
        final isLoaded = stateData['loaded'] as bool? ?? false;

        if (!isLoaded) {
          // Load the model first
          _log('Loading Qwen model: ${_settings.modelName}');
          final loadResponse = await _dio.post(
            '${_settings.apiEndpoint}/caption/load',
            data: {
              'model_id': _settings.modelName,
              'quantization': '8-bit',
              'attn_impl': 'flash_attention_2',
            },
          );

          if (loadResponse.statusCode != 200) {
            return CaptionResult.failure('Failed to load Qwen model');
          }
          _log('Qwen model loaded successfully');
        }
      }

      // Generate caption - OneTrainer uses file path directly (not base64!)
      final response = await _dio.post(
        '${_settings.apiEndpoint}/caption/generate',
        data: {
          'media_path': imagePath,
          'prompt': _settings.captionPrompt,
          'max_tokens': _settings.maxLength,
          'resolution_mode': 'auto',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        String caption = data['caption'] as String? ?? '';

        if (caption.isEmpty) {
          return CaptionResult.failure('Empty caption returned from Qwen');
        }

        final fullCaption = _applyPrefixSuffix(caption);
        _log('Qwen caption result: ${fullCaption.substring(0, fullCaption.length.clamp(0, 50))}...');
        return CaptionResult.success(fullCaption);
      }

      return CaptionResult.failure('Qwen API returned status ${response.statusCode}');
    } on DioException catch (e) {
      _logError('Qwen captioning failed', e);
      if (e.type == DioExceptionType.connectionError) {
        return CaptionResult.failure(
          'Cannot connect to OneTrainer caption service at ${_settings.apiEndpoint}. '
          'Make sure EriUI is started with: python server_manager.py start'
        );
      }
      return CaptionResult.failure(e.message ?? 'Network error');
    }
  }

  /// Local SwarmUI captioning
  Future<CaptionResult> _captionLocal(String imagePath) async {
    _log('Calling local SwarmUI captioning endpoint');

    try {
      // Read image file as base64
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      // SwarmUI captioning endpoint
      final response = await _dio.post(
        '/API/CaptionImage',
        data: {
          'image': base64Image,
          'model': _settings.modelName,
          'max_length': _settings.maxLength,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        String caption = data['caption'] as String? ?? '';

        if (caption.isEmpty) {
          return CaptionResult.failure('Empty caption returned from API');
        }

        // Truncate if needed
        if (caption.length > _settings.maxLength) {
          caption = caption.substring(0, _settings.maxLength);
        }

        final fullCaption = _applyPrefixSuffix(caption);
        _log('Local caption result: $fullCaption');
        return CaptionResult.success(fullCaption);
      }

      return CaptionResult.failure('API returned status ${response.statusCode}');
    } on DioException catch (e) {
      _logError('Local captioning failed', e);
      return CaptionResult.failure(e.message ?? 'Network error');
    }
  }

  /// Generic REST API captioning
  Future<CaptionResult> _captionApi(String imagePath) async {
    _log('Calling external API for captioning');

    try {
      // Read image file as base64
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Generic API format - can be customized based on target API
      final response = await _dio.post(
        '/caption',
        data: {
          'image': base64Image,
          'model': _settings.modelName,
          'max_tokens': _settings.maxLength,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        String caption;

        // Handle different response formats
        if (data is String) {
          caption = data;
        } else if (data is Map<String, dynamic>) {
          caption = data['caption'] as String? ??
                    data['text'] as String? ??
                    data['description'] as String? ??
                    data['result'] as String? ?? '';
        } else {
          return CaptionResult.failure('Unexpected response format');
        }

        if (caption.isEmpty) {
          return CaptionResult.failure('Empty caption returned from API');
        }

        // Truncate if needed
        if (caption.length > _settings.maxLength) {
          caption = caption.substring(0, _settings.maxLength);
        }

        final fullCaption = _applyPrefixSuffix(caption);
        _log('API caption result: $fullCaption');
        return CaptionResult.success(fullCaption);
      }

      return CaptionResult.failure('API returned status ${response.statusCode}');
    } on DioException catch (e) {
      _logError('API captioning failed', e);
      return CaptionResult.failure(e.message ?? 'Network error');
    }
  }

  /// Apply prefix and suffix to caption
  String _applyPrefixSuffix(String caption) {
    final parts = <String>[];

    if (_settings.prefix.isNotEmpty) {
      parts.add(_settings.prefix);
    }

    parts.add(caption);

    if (_settings.suffix.isNotEmpty) {
      parts.add(_settings.suffix);
    }

    return parts.join(' ').trim();
  }

  /// Caption a batch of images
  /// Returns a map of image path to generated caption
  Future<Map<String, String>> captionBatch(
    List<String> imagePaths, {
    void Function(int completed, int total, String? currentPath)? onProgress,
  }) async {
    _log('Starting batch caption for ${imagePaths.length} images');

    final results = <String, String>{};

    for (int i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      onProgress?.call(i, imagePaths.length, imagePath);

      try {
        final caption = await captionImage(imagePath);
        results[imagePath] = caption;
      } catch (e) {
        _logError('Failed to caption $imagePath', e);
        // Continue with other images, store empty caption for failed ones
        results[imagePath] = '';
      }
    }

    onProgress?.call(imagePaths.length, imagePaths.length, null);
    _log('Batch caption complete: ${results.length} images processed');

    return results;
  }

  /// Caption a batch of images with detailed results
  Future<Map<String, CaptionResult>> captionBatchWithResults(
    List<String> imagePaths, {
    void Function(int completed, int total, String? currentPath)? onProgress,
  }) async {
    _log('Starting batch caption with results for ${imagePaths.length} images');

    final results = <String, CaptionResult>{};

    for (int i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      onProgress?.call(i, imagePaths.length, imagePath);

      final result = await _captionImageInternal(imagePath);
      results[imagePath] = result;
    }

    onProgress?.call(imagePaths.length, imagePaths.length, null);

    final successCount = results.values.where((r) => r.success).length;
    _log('Batch caption complete: $successCount/${results.length} succeeded');

    return results;
  }

  /// Save captions to files in the specified format
  Future<void> saveCaptions(
    Map<String, String> captions,
    CaptionFormat format, {
    String? outputDirectory,
    String? outputFilename,
  }) async {
    if (captions.isEmpty) {
      _log('No captions to save');
      return;
    }

    // Determine output directory
    final firstImagePath = captions.keys.first;
    final directory = outputDirectory ?? path.dirname(firstImagePath);

    _log('Saving ${captions.length} captions in $format format to $directory');

    switch (format) {
      case CaptionFormat.txt:
        await _saveCaptionsTxt(captions);
        break;
      case CaptionFormat.json:
        await _saveCaptionsJson(captions, directory, outputFilename);
        break;
      case CaptionFormat.csv:
        await _saveCaptionsCsv(captions, directory, outputFilename);
        break;
    }

    _log('Captions saved successfully');
  }

  /// Save captions as individual .txt files (one per image)
  Future<void> _saveCaptionsTxt(Map<String, String> captions) async {
    for (final entry in captions.entries) {
      final imagePath = entry.key;
      final caption = entry.value;

      if (caption.isEmpty) continue;

      // Create txt file with same name as image
      final directory = path.dirname(imagePath);
      final baseName = path.basenameWithoutExtension(imagePath);
      final txtPath = path.join(directory, '$baseName.txt');

      final file = File(txtPath);
      await file.writeAsString(caption, flush: true);
      _log('Saved caption: $txtPath');
    }
  }

  /// Save all captions to a single JSON file
  Future<void> _saveCaptionsJson(
    Map<String, String> captions,
    String directory,
    String? filename,
  ) async {
    final jsonPath = path.join(directory, filename ?? 'captions.json');

    // Create structured JSON
    final jsonData = <String, dynamic>{
      'generated_at': DateTime.now().toIso8601String(),
      'count': captions.length,
      'captions': captions.map((imagePath, caption) => MapEntry(
        path.basename(imagePath),
        {
          'path': imagePath,
          'caption': caption,
        },
      )),
    };

    final file = File(jsonPath);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(jsonData), flush: true);
    _log('Saved captions JSON: $jsonPath');
  }

  /// Save all captions to a CSV file
  Future<void> _saveCaptionsCsv(
    Map<String, String> captions,
    String directory,
    String? filename,
  ) async {
    final csvPath = path.join(directory, filename ?? 'captions.csv');

    final buffer = StringBuffer();

    // CSV header
    buffer.writeln('path,caption');

    // CSV rows
    for (final entry in captions.entries) {
      final imagePath = entry.key;
      final caption = entry.value;

      // Escape CSV values
      final escapedPath = _escapeCsvValue(imagePath);
      final escapedCaption = _escapeCsvValue(caption);

      buffer.writeln('$escapedPath,$escapedCaption');
    }

    final file = File(csvPath);
    await file.writeAsString(buffer.toString(), flush: true);
    _log('Saved captions CSV: $csvPath');
  }

  /// Escape a value for CSV format
  String _escapeCsvValue(String value) {
    // If value contains comma, quote, or newline, wrap in quotes and escape quotes
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Load captions from a JSON file
  Future<Map<String, String>> loadCaptionsJson(String jsonPath) async {
    _log('Loading captions from: $jsonPath');

    final file = File(jsonPath);
    if (!await file.exists()) {
      throw Exception('Captions file not found: $jsonPath');
    }

    final content = await file.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;

    final captionsData = data['captions'] as Map<String, dynamic>?;
    if (captionsData == null) {
      return {};
    }

    final result = <String, String>{};
    for (final entry in captionsData.entries) {
      final captionData = entry.value as Map<String, dynamic>;
      final imagePath = captionData['path'] as String?;
      final caption = captionData['caption'] as String?;

      if (imagePath != null && caption != null) {
        result[imagePath] = caption;
      }
    }

    _log('Loaded ${result.length} captions');
    return result;
  }

  /// Load captions from individual .txt files in a directory
  Future<Map<String, String>> loadCaptionsTxt(
    String directory, {
    List<String>? imageExtensions,
  }) async {
    _log('Loading txt captions from: $directory');

    final extensions = imageExtensions ?? ['.jpg', '.jpeg', '.png', '.webp', '.bmp'];
    final result = <String, String>{};

    final dir = Directory(directory);
    if (!await dir.exists()) {
      throw Exception('Directory not found: $directory');
    }

    await for (final entity in dir.list()) {
      if (entity is File) {
        final ext = path.extension(entity.path).toLowerCase();

        // Check if this is a caption file
        if (ext == '.txt') {
          final baseName = path.basenameWithoutExtension(entity.path);

          // Find corresponding image file
          for (final imgExt in extensions) {
            final imagePath = path.join(directory, '$baseName$imgExt');
            if (await File(imagePath).exists()) {
              final caption = await entity.readAsString();
              result[imagePath] = caption.trim();
              break;
            }
          }
        }
      }
    }

    _log('Loaded ${result.length} captions from txt files');
    return result;
  }

  /// Test connection to captioning backend
  Future<bool> testConnection() async {
    _log('Testing connection to ${_settings.apiEndpoint}');

    if (_settings.backend == CaptionBackend.placeholder) {
      return true;
    }

    try {
      String endpoint;
      switch (_settings.backend) {
        case CaptionBackend.qwen:
          endpoint = '${_settings.apiEndpoint}/caption/state';
          break;
        case CaptionBackend.local:
          endpoint = '${_settings.apiEndpoint}/API/GetServerInfo';
          break;
        default:
          endpoint = '${_settings.apiEndpoint}/health';
      }

      final response = await _dio.get(endpoint);
      return response.statusCode == 200;
    } catch (e) {
      _logError('Connection test failed', e);
      return false;
    }
  }

  /// Check if Qwen model is loaded
  Future<Map<String, dynamic>> getQwenState() async {
    if (_settings.backend != CaptionBackend.qwen) {
      return {'loaded': false, 'error': 'Not using Qwen backend'};
    }

    try {
      final response = await _dio.get('${_settings.apiEndpoint}/caption/state');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return {'loaded': false, 'error': 'API error'};
    } catch (e) {
      return {'loaded': false, 'error': e.toString()};
    }
  }

  /// Load Qwen model explicitly
  Future<bool> loadQwenModel({
    String? modelId,
    String quantization = '8-bit',
  }) async {
    if (_settings.backend != CaptionBackend.qwen) {
      return false;
    }

    try {
      _log('Loading Qwen model: ${modelId ?? _settings.modelName}');
      final response = await _dio.post(
        '${_settings.apiEndpoint}/caption/load',
        data: {
          'model_id': modelId ?? _settings.modelName,
          'quantization': quantization,
          'attn_impl': 'flash_attention_2',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      _logError('Failed to load Qwen model', e);
      return false;
    }
  }

  /// Unload Qwen model to free VRAM
  Future<bool> unloadQwenModel() async {
    if (_settings.backend != CaptionBackend.qwen) {
      return false;
    }

    try {
      final response = await _dio.post('${_settings.apiEndpoint}/caption/unload');
      return response.statusCode == 200;
    } catch (e) {
      _logError('Failed to unload Qwen model', e);
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
  }

  /// Transcribe audio using SwarmUI's Whisper API
  /// Returns a list of Caption objects with timestamps
  Future<List<Caption>> transcribeAudio(
    String audioPath, {
    String language = 'en',
    Function(double progress)? onProgress,
  }) async {
    _log('Transcribing audio: $audioPath (language: $language)');

    // Verify file exists
    final file = File(audioPath);
    if (!await file.exists()) {
      throw Exception('Audio file not found: $audioPath');
    }

    try {
      // Read audio file as base64
      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);

      onProgress?.call(0.1);

      // Call SwarmUI TranscribeAudio API
      final response = await _dio.post(
        '/API/TranscribeAudio',
        data: {
          'audio': base64Audio,
          'language': language,
          'task': 'transcribe',
          'word_timestamps': true,
        },
      );

      onProgress?.call(0.8);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final segments = data['segments'] as List<dynamic>? ?? [];

        final captions = <Caption>[];
        for (final segment in segments) {
          final segmentMap = segment as Map<String, dynamic>;
          final startSeconds = (segmentMap['start'] as num?)?.toDouble() ?? 0.0;
          final endSeconds = (segmentMap['end'] as num?)?.toDouble() ?? 0.0;
          final text = (segmentMap['text'] as String?)?.trim() ?? '';

          if (text.isNotEmpty) {
            captions.add(Caption.create(
              startTime: EditorTime.fromSeconds(startSeconds),
              endTime: EditorTime.fromSeconds(endSeconds),
              text: text,
            ));
          }
        }

        onProgress?.call(1.0);
        _log('Transcription complete: ${captions.length} segments');
        return captions;
      }

      throw Exception('API returned status ${response.statusCode}');
    } on DioException catch (e) {
      _logError('Transcription failed', e);
      throw Exception(e.message ?? 'Network error during transcription');
    }
  }

  /// Parse an SRT subtitle file
  static List<Caption> parseSrt(String content) {
    final captions = <Caption>[];
    final lines = content.split('\n');

    int i = 0;
    while (i < lines.length) {
      // Skip empty lines and index number
      while (i < lines.length && (lines[i].trim().isEmpty || int.tryParse(lines[i].trim()) != null)) {
        i++;
      }

      if (i >= lines.length) break;

      // Parse timing line (00:00:00,000 --> 00:00:00,000)
      final timingLine = lines[i].trim();
      final timingMatch = RegExp(r'(\d{2}):(\d{2}):(\d{2}),(\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2}),(\d{3})').firstMatch(timingLine);

      if (timingMatch != null) {
        final startMs = int.parse(timingMatch.group(1)!) * 3600000 +
                       int.parse(timingMatch.group(2)!) * 60000 +
                       int.parse(timingMatch.group(3)!) * 1000 +
                       int.parse(timingMatch.group(4)!);
        final endMs = int.parse(timingMatch.group(5)!) * 3600000 +
                     int.parse(timingMatch.group(6)!) * 60000 +
                     int.parse(timingMatch.group(7)!) * 1000 +
                     int.parse(timingMatch.group(8)!);

        i++;

        // Collect text lines until empty line or end
        final textLines = <String>[];
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          textLines.add(lines[i].trim());
          i++;
        }

        if (textLines.isNotEmpty) {
          captions.add(Caption.create(
            startTime: EditorTime.fromMilliseconds(startMs),
            endTime: EditorTime.fromMilliseconds(endMs),
            text: textLines.join('\n'),
          ));
        }
      } else {
        i++;
      }
    }

    return captions;
  }

  /// Export captions to SRT format
  static String exportToSrt(List<Caption> captions) {
    final buffer = StringBuffer();

    for (int i = 0; i < captions.length; i++) {
      final caption = captions[i];

      // Index
      buffer.writeln(i + 1);

      // Timing
      buffer.writeln('${_formatSrtTime(caption.startTime)} --> ${_formatSrtTime(caption.endTime)}');

      // Text
      buffer.writeln(caption.text);

      // Empty line
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Export captions to VTT format
  static String exportToVtt(List<Caption> captions) {
    final buffer = StringBuffer();

    buffer.writeln('WEBVTT');
    buffer.writeln();

    for (int i = 0; i < captions.length; i++) {
      final caption = captions[i];

      // Timing (VTT uses . instead of ,)
      buffer.writeln('${_formatVttTime(caption.startTime)} --> ${_formatVttTime(caption.endTime)}');

      // Text
      buffer.writeln(caption.text);

      // Empty line
      buffer.writeln();
    }

    return buffer.toString();
  }

  static String _formatSrtTime(EditorTime time) {
    final totalMs = time.inMilliseconds.round();
    final hours = (totalMs ~/ 3600000).toString().padLeft(2, '0');
    final minutes = ((totalMs % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((totalMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    final ms = (totalMs % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$ms';
  }

  static String _formatVttTime(EditorTime time) {
    final totalMs = time.inMilliseconds.round();
    final hours = (totalMs ~/ 3600000).toString().padLeft(2, '0');
    final minutes = ((totalMs % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((totalMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    final ms = (totalMs % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$ms';
  }
}

/// State notifier for caption settings
class CaptionSettingsNotifier extends StateNotifier<CaptionSettings> {
  CaptionSettingsNotifier() : super(const CaptionSettings());

  void updateSettings(CaptionSettings settings) {
    state = settings;
  }

  void setApiEndpoint(String endpoint) {
    state = state.copyWith(apiEndpoint: endpoint);
  }

  void setModelName(String modelName) {
    state = state.copyWith(modelName: modelName);
  }

  void setMaxLength(int maxLength) {
    state = state.copyWith(maxLength: maxLength);
  }

  void setPrefix(String prefix) {
    state = state.copyWith(prefix: prefix);
  }

  void setSuffix(String suffix) {
    state = state.copyWith(suffix: suffix);
  }

  void setBackend(CaptionBackend backend) {
    state = state.copyWith(backend: backend);
  }

  void setTimeoutSeconds(int seconds) {
    state = state.copyWith(timeoutSeconds: seconds);
  }

  void setUseFilenameHints(bool use) {
    state = state.copyWith(useFilenameHints: use);
  }

  void reset() {
    state = const CaptionSettings();
  }
}

/// State notifier for caption progress
class CaptionProgressNotifier extends StateNotifier<CaptionProgress> {
  CaptionProgressNotifier() : super(const CaptionProgress());

  void startProcessing(int total) {
    state = CaptionProgress(
      total: total,
      completed: 0,
      failed: 0,
      isProcessing: true,
    );
  }

  void updateProgress(int completed, String? currentImage) {
    state = state.copyWith(
      completed: completed,
      currentImage: currentImage,
    );
  }

  void recordFailure(String imagePath) {
    state = state.copyWith(
      failed: state.failed + 1,
      failedPaths: [...state.failedPaths, imagePath],
    );
  }

  void setError(String error) {
    state = state.copyWith(
      error: error,
      isProcessing: false,
    );
  }

  void complete() {
    state = state.copyWith(
      isProcessing: false,
      currentImage: null,
    );
  }

  void reset() {
    state = const CaptionProgress();
  }
}
