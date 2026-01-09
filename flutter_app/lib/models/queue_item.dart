import 'package:uuid/uuid.dart';
import '../providers/generation_provider.dart';
import '../providers/lora_provider.dart';

/// Queue item status enum
enum QueueStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
}

/// Extension for QueueStatus display names and icons
extension QueueStatusExtension on QueueStatus {
  String get displayName {
    switch (this) {
      case QueueStatus.pending:
        return 'Pending';
      case QueueStatus.running:
        return 'Running';
      case QueueStatus.completed:
        return 'Completed';
      case QueueStatus.failed:
        return 'Failed';
      case QueueStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isTerminal =>
      this == QueueStatus.completed ||
      this == QueueStatus.failed ||
      this == QueueStatus.cancelled;
}

/// A queue item representing a pending or completed generation request
class QueueItem {
  final String id;
  final GenerationParams params;
  final List<SelectedLora>? loras;
  final QueueStatus status;
  final String? resultImageUrl;
  final List<String> resultImages;
  final String? error;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int priority;
  final double progress;
  final int currentStep;
  final int totalSteps;
  final String? batchId;
  final int batchIndex;
  final int batchTotal;

  const QueueItem({
    required this.id,
    required this.params,
    this.loras,
    this.status = QueueStatus.pending,
    this.resultImageUrl,
    this.resultImages = const [],
    this.error,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.priority = 0,
    this.progress = 0.0,
    this.currentStep = 0,
    this.totalSteps = 0,
    this.batchId,
    this.batchIndex = 0,
    this.batchTotal = 1,
  });

  /// Create a new queue item with a generated ID
  factory QueueItem.create({
    required GenerationParams params,
    List<SelectedLora>? loras,
    int priority = 0,
    String? batchId,
    int batchIndex = 0,
    int batchTotal = 1,
  }) {
    return QueueItem(
      id: const Uuid().v4(),
      params: params,
      loras: loras,
      createdAt: DateTime.now(),
      priority: priority,
      batchId: batchId,
      batchIndex: batchIndex,
      batchTotal: batchTotal,
    );
  }

  /// Create a copy with updated fields
  QueueItem copyWith({
    String? id,
    GenerationParams? params,
    List<SelectedLora>? loras,
    QueueStatus? status,
    String? resultImageUrl,
    List<String>? resultImages,
    String? error,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    int? priority,
    double? progress,
    int? currentStep,
    int? totalSteps,
    String? batchId,
    int? batchIndex,
    int? batchTotal,
  }) {
    return QueueItem(
      id: id ?? this.id,
      params: params ?? this.params,
      loras: loras ?? this.loras,
      status: status ?? this.status,
      resultImageUrl: resultImageUrl ?? this.resultImageUrl,
      resultImages: resultImages ?? this.resultImages,
      error: error,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      priority: priority ?? this.priority,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      batchId: batchId ?? this.batchId,
      batchIndex: batchIndex ?? this.batchIndex,
      batchTotal: batchTotal ?? this.batchTotal,
    );
  }

  /// Get a short summary of the prompt for display
  String get promptSummary {
    if (params.prompt.isEmpty) return 'No prompt';
    if (params.prompt.length <= 50) return params.prompt;
    return '${params.prompt.substring(0, 47)}...';
  }

  /// Check if this is part of a batch
  bool get isBatch => batchTotal > 1;

  /// Get batch progress string
  String get batchProgress => isBatch ? '${batchIndex + 1}/$batchTotal' : '';

  /// Check if item can be cancelled
  bool get canCancel =>
      status == QueueStatus.pending || status == QueueStatus.running;

  /// Check if item can be reordered
  bool get canReorder => status == QueueStatus.pending;

  /// Duration since creation
  Duration get age => DateTime.now().difference(createdAt);

  /// Duration of processing (if started)
  Duration? get processingTime {
    if (startedAt == null) return null;
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(startedAt!);
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
        'id': id,
        'params': _paramsToJson(params),
        'loras': loras?.map((l) => l.toJson()).toList(),
        'status': status.name,
        'resultImageUrl': resultImageUrl,
        'resultImages': resultImages,
        'error': error,
        'createdAt': createdAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'priority': priority,
        'progress': progress,
        'currentStep': currentStep,
        'totalSteps': totalSteps,
        'batchId': batchId,
        'batchIndex': batchIndex,
        'batchTotal': batchTotal,
      };

  /// Helper to convert GenerationParams to JSON
  static Map<String, dynamic> _paramsToJson(GenerationParams params) => {
        'prompt': params.prompt,
        'negativePrompt': params.negativePrompt,
        'model': params.model,
        'width': params.width,
        'height': params.height,
        'steps': params.steps,
        'cfgScale': params.cfgScale,
        'seed': params.seed,
        'sampler': params.sampler,
        'scheduler': params.scheduler,
        'batchSize': params.batchSize,
        'videoMode': params.videoMode,
        'videoModel': params.videoModel,
        'frames': params.frames,
        'fps': params.fps,
        'videoFormat': params.videoFormat,
      };

  @override
  String toString() => 'QueueItem(id: $id, status: $status, prompt: $promptSummary)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
