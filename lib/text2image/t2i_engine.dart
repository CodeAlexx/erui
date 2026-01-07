import 'dart:async';
import 'dart:typed_data';

import '../utils/logging.dart';
import '../core/events.dart';
import '../core/program.dart';
import '../accounts/session.dart';
import '../accounts/gen_claim.dart';
import '../backends/backend_handler.dart';
import '../backends/comfyui/comfyui_backend.dart';
import 't2i_model.dart';

/// T2I Generation Engine
/// Orchestrates image generation across backends
class T2IEngine {
  /// Pre-generation event
  static final AsyncEvent preGenerateEvent = AsyncEvent('preGenerate');

  /// Post-generation event (per image)
  static final Event1<GenerationOutput> postGenerateEvent = Event1('postGenerate');

  /// Post-batch event (all images done)
  static final Event1<GenerationBatch> postBatchEvent = Event1('postBatch');

  /// Generate images from parameters
  static Future<GenerationBatch> generate({
    required Map<String, dynamic> params,
    required Session session,
    void Function(GenerationProgress)? onProgress,
    void Function(Uint8List)? onPreview,
    CancellationToken? cancel,
  }) async {
    final batch = GenerationBatch(
      sessionId: session.id,
      params: params,
    );

    final numImages = params['images'] as int? ?? 1;
    final claim = session.claim(gens: numImages);

    try {
      // Fire pre-generate event
      await preGenerateEvent.invoke();

      // Get model name
      final modelName = params['model'] as String?;
      if (modelName == null || modelName.isEmpty) {
        throw GenerationException('No model specified');
      }

      // Get backend
      claim.extend(backendWaits: 1);
      final access = await Program.instance.backends.getNextT2IBackend(
        modelName: modelName,
        cancel: cancel,
        notifyWillLoad: () {
          claim.extend(modelLoads: 1);
        },
      );

      if (access == null) {
        throw GenerationException('No backend available');
      }

      claim.complete(backendWaits: 1);

      try {
        // Load model if needed
        if (access.data.currentModelName != modelName) {
          await access.loadModel(modelName);
        }
        claim.complete(modelLoads: 1);

        // Generate with backend
        if (access.backend is ComfyUIBackend) {
          final comfyBackend = access.backend as ComfyUIBackend;

          final results = await comfyBackend.generate(
            params: params,
            onProgress: (current, total) {
              onProgress?.call(GenerationProgress(
                currentStep: current,
                totalSteps: total,
                currentImage: batch.outputs.length,
                totalImages: numImages,
              ));
            },
            onPreview: onPreview,
          );

          // Convert results to outputs
          for (final result in results) {
            final output = GenerationOutput(
              imageData: result.imageData,
              filename: result.filename,
              seed: result.seed,
              params: Map.from(params),
            );

            batch.outputs.add(output);
            claim.complete(gens: 1);

            // Fire per-image event
            postGenerateEvent.invoke(output);
          }
        } else {
          throw GenerationException('Unsupported backend type');
        }
      } finally {
        access.release();
      }

      batch.success = true;

      // Fire batch complete event
      postBatchEvent.invoke(batch);

      return batch;
    } catch (e) {
      batch.success = false;
      batch.error = e.toString();
      Logs.error('Generation error: $e');
      rethrow;
    } finally {
      claim.dispose();
    }
  }

  /// Generate images with WebSocket streaming
  static Stream<GenerationEvent> generateStream({
    required Map<String, dynamic> params,
    required Session session,
    CancellationToken? cancel,
  }) async* {
    final numImages = params['images'] as int? ?? 1;
    final claim = session.claim(gens: numImages);

    try {
      yield GenerationEvent.started(numImages);

      // Fire pre-generate event
      await preGenerateEvent.invoke();

      // Get model name
      final modelName = params['model'] as String?;
      if (modelName == null || modelName.isEmpty) {
        throw GenerationException('No model specified');
      }

      // Get backend
      claim.extend(backendWaits: 1);
      yield GenerationEvent.waitingBackend();

      final access = await Program.instance.backends.getNextT2IBackend(
        modelName: modelName,
        cancel: cancel,
        notifyWillLoad: () {
          claim.extend(modelLoads: 1);
        },
      );

      if (access == null) {
        throw GenerationException('No backend available');
      }

      claim.complete(backendWaits: 1);

      try {
        // Load model if needed
        if (access.data.currentModelName != modelName) {
          yield GenerationEvent.loadingModel(modelName);
          await access.loadModel(modelName);
        }
        claim.complete(modelLoads: 1);

        yield GenerationEvent.generating();

        // Generate with backend
        if (access.backend is ComfyUIBackend) {
          final comfyBackend = access.backend as ComfyUIBackend;

          // Subscribe to WebSocket events
          final wsCompleter = Completer<void>();

          final progressSub = comfyBackend._webSocket?.progress.listen((p) {
            // Emit progress
          });

          final previewSub = comfyBackend._webSocket?.previews.listen((data) {
            // Emit preview
          });

          try {
            final results = await comfyBackend.generate(params: params);

            for (final result in results) {
              yield GenerationEvent.imageComplete(
                imageData: result.imageData,
                filename: result.filename,
                seed: result.seed,
              );
              claim.complete(gens: 1);
            }
          } finally {
            await progressSub?.cancel();
            await previewSub?.cancel();
          }
        }
      } finally {
        access.release();
      }

      yield GenerationEvent.complete();
    } catch (e) {
      yield GenerationEvent.error(e.toString());
      rethrow;
    } finally {
      claim.dispose();
    }
  }
}

/// Generation batch result
class GenerationBatch {
  final String sessionId;
  final Map<String, dynamic> params;
  final List<GenerationOutput> outputs = [];
  final DateTime startTime = DateTime.now();
  DateTime? endTime;
  bool success = false;
  String? error;

  GenerationBatch({
    required this.sessionId,
    required this.params,
  });

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'params': params,
        'outputs': outputs.map((o) => o.toJson()).toList(),
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'success': success,
        'error': error,
        'duration_ms': duration.inMilliseconds,
      };
}

/// Single generation output
class GenerationOutput {
  final Uint8List imageData;
  final String filename;
  final int seed;
  final Map<String, dynamic> params;
  final DateTime timestamp = DateTime.now();

  GenerationOutput({
    required this.imageData,
    required this.filename,
    required this.seed,
    required this.params,
  });

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'seed': seed,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Generation progress info
class GenerationProgress {
  final int currentStep;
  final int totalSteps;
  final int currentImage;
  final int totalImages;

  GenerationProgress({
    required this.currentStep,
    required this.totalSteps,
    required this.currentImage,
    required this.totalImages,
  });

  double get stepPercent => totalSteps > 0 ? currentStep / totalSteps : 0;
  double get overallPercent {
    if (totalImages == 0) return 0;
    return (currentImage + stepPercent) / totalImages;
  }

  Map<String, dynamic> toJson() => {
        'current_step': currentStep,
        'total_steps': totalSteps,
        'current_image': currentImage,
        'total_images': totalImages,
        'step_percent': stepPercent,
        'overall_percent': overallPercent,
      };
}

/// Generation event for streaming
abstract class GenerationEvent {
  final String type;
  final Map<String, dynamic> data;

  GenerationEvent(this.type, this.data);

  factory GenerationEvent.started(int totalImages) =>
      _GenerationEvent('started', {'total_images': totalImages});

  factory GenerationEvent.waitingBackend() =>
      _GenerationEvent('waiting_backend', {});

  factory GenerationEvent.loadingModel(String model) =>
      _GenerationEvent('loading_model', {'model': model});

  factory GenerationEvent.generating() =>
      _GenerationEvent('generating', {});

  factory GenerationEvent.progress(GenerationProgress progress) =>
      _GenerationEvent('progress', progress.toJson());

  factory GenerationEvent.preview(Uint8List data) =>
      _GenerationEvent('preview', {'data': data});

  factory GenerationEvent.imageComplete({
    required Uint8List imageData,
    required String filename,
    required int seed,
  }) =>
      _GenerationEvent('image_complete', {
        'filename': filename,
        'seed': seed,
      });

  factory GenerationEvent.complete() =>
      _GenerationEvent('complete', {});

  factory GenerationEvent.error(String message) =>
      _GenerationEvent('error', {'message': message});

  Map<String, dynamic> toJson() => {
        'type': type,
        ...data,
      };
}

class _GenerationEvent extends GenerationEvent {
  _GenerationEvent(super.type, super.data);
}

/// Generation exception
class GenerationException implements Exception {
  final String message;
  GenerationException(this.message);

  @override
  String toString() => 'GenerationException: $message';
}
