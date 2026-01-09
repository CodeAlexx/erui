import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/queue_item.dart';
import '../providers/generation_provider.dart';
import '../providers/lora_provider.dart';
import 'comfyui_service.dart';
import 'comfyui_workflow_builder.dart';

/// Generation queue service provider
final generationQueueServiceProvider = Provider<GenerationQueueService>((ref) {
  final comfyService = ref.watch(comfyUIServiceProvider);
  return GenerationQueueService(ref, comfyService);
});

/// Service for managing the generation queue
class GenerationQueueService {
  final Ref _ref;
  final ComfyUIService _comfyService;
  final ComfyUIWorkflowBuilder _workflowBuilder = ComfyUIWorkflowBuilder();

  /// List of queue items
  final List<QueueItem> _items = [];

  /// Whether the queue is currently processing
  bool _isProcessing = false;

  /// Whether the queue is paused
  bool _isPaused = false;

  /// Current item being processed
  QueueItem? _currentItem;

  /// Stream controller for queue updates
  final _queueController = StreamController<List<QueueItem>>.broadcast();

  /// Stream controller for processing state
  final _processingController = StreamController<bool>.broadcast();

  /// Subscription to ComfyUI progress stream
  StreamSubscription<ComfyProgressUpdate>? _progressSubscription;

  /// Current prompt ID being processed
  String? _currentPromptId;

  GenerationQueueService(this._ref, this._comfyService);

  /// Get all queue items
  List<QueueItem> get items => List.unmodifiable(_items);

  /// Get pending items
  List<QueueItem> get pendingItems =>
      _items.where((item) => item.status == QueueStatus.pending).toList();

  /// Get running items
  List<QueueItem> get runningItems =>
      _items.where((item) => item.status == QueueStatus.running).toList();

  /// Get completed items
  List<QueueItem> get completedItems =>
      _items.where((item) => item.status == QueueStatus.completed).toList();

  /// Get failed items
  List<QueueItem> get failedItems =>
      _items.where((item) => item.status == QueueStatus.failed).toList();

  /// Whether the queue is processing
  bool get isProcessing => _isProcessing;

  /// Whether the queue is paused
  bool get isPaused => _isPaused;

  /// Current item being processed
  QueueItem? get currentItem => _currentItem;

  /// Stream of queue updates
  Stream<List<QueueItem>> get queueStream => _queueController.stream;

  /// Stream of processing state updates
  Stream<bool> get processingStream => _processingController.stream;

  /// Number of pending items
  int get pendingCount => pendingItems.length;

  /// Number of running items
  int get runningCount => runningItems.length;

  /// Add a single item to the queue
  QueueItem addItem(GenerationParams params, {List<SelectedLora>? loras, int priority = 0}) {
    final item = QueueItem.create(
      params: params,
      loras: loras,
      priority: priority,
    );
    _items.add(item);
    _sortByPriority();
    _notifyUpdate();

    // Auto-start processing if not paused
    if (!_isPaused && !_isProcessing) {
      _processNext();
    }

    return item;
  }

  /// Add multiple items to the queue (batch)
  List<QueueItem> addBatch(
    GenerationParams params, {
    List<SelectedLora>? loras,
    int count = 1,
    int priority = 0,
  }) {
    if (count <= 1) {
      return [addItem(params, loras: loras, priority: priority)];
    }

    final batchId = const Uuid().v4();
    final items = <QueueItem>[];

    for (int i = 0; i < count; i++) {
      // Increment seed for each batch item (if not random)
      final batchParams = params.seed == -1
          ? params
          : params.copyWith(seed: params.seed + i);

      final item = QueueItem.create(
        params: batchParams,
        loras: loras,
        priority: priority,
        batchId: batchId,
        batchIndex: i,
        batchTotal: count,
      );
      _items.add(item);
      items.add(item);
    }

    _sortByPriority();
    _notifyUpdate();

    // Auto-start processing if not paused
    if (!_isPaused && !_isProcessing) {
      _processNext();
    }

    return items;
  }

  /// Remove an item from the queue
  bool removeItem(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return false;

    final item = _items[index];

    // Can only remove pending or terminal items
    if (item.status == QueueStatus.running) {
      return false;
    }

    _items.removeAt(index);
    _notifyUpdate();
    return true;
  }

  /// Cancel an item (if pending or running)
  Future<bool> cancelItem(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return false;

    final item = _items[index];

    if (!item.canCancel) return false;

    if (item.status == QueueStatus.running) {
      // Cancel the active generation
      await _cancelCurrentGeneration();
    }

    _items[index] = item.copyWith(
      status: QueueStatus.cancelled,
      completedAt: DateTime.now(),
    );

    _notifyUpdate();

    // Process next if we cancelled the running item
    if (item.status == QueueStatus.running) {
      _currentItem = null;
      _isProcessing = false;
      _processNext();
    }

    return true;
  }

  /// Reorder items by providing a new order of IDs
  void reorder(List<String> newOrder) {
    final pending = pendingItems;
    if (pending.isEmpty) return;

    // Create a map for quick lookup
    final itemMap = {for (var item in pending) item.id: item};

    // Reorder pending items based on new order
    final reordered = <QueueItem>[];
    for (final id in newOrder) {
      if (itemMap.containsKey(id)) {
        reordered.add(itemMap[id]!);
        itemMap.remove(id);
      }
    }

    // Add any remaining items not in the new order
    reordered.addAll(itemMap.values);

    // Remove old pending items and add reordered ones
    _items.removeWhere((item) => item.status == QueueStatus.pending);
    _items.insertAll(0, reordered);

    _notifyUpdate();
  }

  /// Move an item to a specific index
  void moveItem(String id, int newIndex) {
    final pendingIds = pendingItems.map((item) => item.id).toList();
    final currentIndex = pendingIds.indexOf(id);

    if (currentIndex == -1 || currentIndex == newIndex) return;

    pendingIds.removeAt(currentIndex);
    pendingIds.insert(newIndex.clamp(0, pendingIds.length), id);

    reorder(pendingIds);
  }

  /// Pause the queue
  void pause() {
    _isPaused = true;
    _processingController.add(_isProcessing);
    _notifyUpdate();
  }

  /// Resume the queue
  void resume() {
    _isPaused = false;
    _processingController.add(_isProcessing);
    _notifyUpdate();

    // Start processing if there are pending items
    if (!_isProcessing && pendingItems.isNotEmpty) {
      _processNext();
    }
  }

  /// Clear all pending items
  void clearPending() {
    _items.removeWhere((item) => item.status == QueueStatus.pending);
    _notifyUpdate();
  }

  /// Clear all completed/failed items
  void clearCompleted() {
    _items.removeWhere((item) => item.status.isTerminal);
    _notifyUpdate();
  }

  /// Clear all items
  void clearAll() {
    // Cancel running item first
    if (_currentItem != null) {
      _cancelCurrentGeneration();
    }

    _items.clear();
    _currentItem = null;
    _isProcessing = false;
    _notifyUpdate();
  }

  /// Retry a failed item
  void retryItem(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final item = _items[index];
    if (item.status != QueueStatus.failed) return;

    _items[index] = item.copyWith(
      status: QueueStatus.pending,
      error: null,
      progress: 0.0,
      currentStep: 0,
      startedAt: null,
      completedAt: null,
    );

    _sortByPriority();
    _notifyUpdate();

    // Auto-start processing if not paused
    if (!_isPaused && !_isProcessing) {
      _processNext();
    }
  }

  /// Process the next item in the queue
  Future<void> _processNext() async {
    if (_isPaused || _isProcessing) return;

    final nextItem = pendingItems.firstOrNull;
    if (nextItem == null) return;

    _isProcessing = true;
    _currentItem = nextItem;
    _processingController.add(true);

    // Update item status
    final index = _items.indexWhere((item) => item.id == nextItem.id);
    if (index != -1) {
      _items[index] = nextItem.copyWith(
        status: QueueStatus.running,
        startedAt: DateTime.now(),
      );
      _notifyUpdate();
    }

    try {
      await _executeGeneration(nextItem);
    } catch (e) {
      // Mark as failed
      final failIndex = _items.indexWhere((item) => item.id == nextItem.id);
      if (failIndex != -1) {
        _items[failIndex] = _items[failIndex].copyWith(
          status: QueueStatus.failed,
          error: e.toString(),
          completedAt: DateTime.now(),
        );
      }
    }

    _pollTimer?.cancel();
    _currentItem = null;
    _isProcessing = false;
    _processingController.add(false);
    _notifyUpdate();

    // Process next item
    if (!_isPaused && pendingItems.isNotEmpty) {
      _processNext();
    }
  }

  /// Execute a generation request
  Future<void> _executeGeneration(QueueItem item) async {
    if (_comfyService.currentConnectionState != ComfyConnectionState.connected) {
      throw Exception('Not connected to ComfyUI');
    }

    // Use video model if in video mode, otherwise regular model
    final modelToUse = item.params.videoMode
        ? (item.params.videoModel ?? item.params.model)
        : item.params.model;

    // Build LoRA configs if present
    List<LoraConfig>? loraConfigs;
    if (item.loras != null && item.loras!.isNotEmpty) {
      loraConfigs = item.loras!.map((l) => LoraConfig(
        name: l.name,
        modelStrength: l.strength,
        clipStrength: l.strength,
      )).toList();
    }

    // Build the appropriate workflow based on mode
    Map<String, dynamic> workflow;

    if (item.params.videoMode) {
      // Build video workflow
      workflow = _workflowBuilder.buildVideoAuto(
        model: modelToUse,
        prompt: item.params.prompt,
        negativePrompt: item.params.negativePrompt,
        width: item.params.width,
        height: item.params.height,
        frames: item.params.frames,
        fps: item.params.fps,
        steps: item.params.steps,
        cfg: item.params.cfgScale,
        seed: item.params.seed,
        initImageBase64: item.params.initImage,
        outputFormat: item.params.videoFormat,
      );
    } else {
      // Build image workflow
      workflow = _workflowBuilder.buildText2Image(
        model: modelToUse,
        prompt: item.params.prompt,
        negativePrompt: item.params.negativePrompt,
        width: item.params.width,
        height: item.params.height,
        steps: item.params.steps,
        cfg: item.params.cfgScale,
        seed: item.params.seed,
        sampler: item.params.sampler,
        scheduler: item.params.scheduler,
        loras: loraConfigs,
        initImageBase64: item.params.initImage,
        denoise: item.params.initImage != null ? item.params.initImageCreativity : 1.0,
      );
    }

    // Queue the workflow
    final promptId = await _comfyService.queuePrompt(workflow);
    if (promptId == null) {
      throw Exception('Failed to queue workflow');
    }

    _currentPromptId = promptId;

    // Wait for completion via progress stream
    await _waitForCompletion(item.id, promptId);
  }

  /// Wait for generation completion via ComfyUI progress stream
  Future<void> _waitForCompletion(String itemId, String promptId) async {
    final completer = Completer<void>();

    // Cancel any existing subscription
    await _progressSubscription?.cancel();

    // Listen to progress stream for this specific prompt
    _progressSubscription = _comfyService.progressStream.listen((update) {
      if (update.promptId != promptId) return;

      // Update progress
      if (update.totalSteps > 0) {
        _updateItemProgress(itemId, update.progress, update.currentStep, update.totalSteps);
      }

      if (update.isComplete && update.outputImages != null && update.outputImages!.isNotEmpty) {
        _updateItemStatus(
          itemId,
          status: QueueStatus.completed,
          resultImages: update.outputImages,
          resultImageUrl: update.outputImages!.first,
          progress: 1.0,
        );
        if (!completer.isCompleted) completer.complete();
      } else if (update.status == 'error') {
        _updateItemStatus(
          itemId,
          status: QueueStatus.failed,
          error: 'Generation failed',
        );
        if (!completer.isCompleted) {
          completer.completeError(Exception('Generation failed'));
        }
      } else if (update.status == 'interrupted') {
        _updateItemStatus(
          itemId,
          status: QueueStatus.cancelled,
        );
        if (!completer.isCompleted) completer.complete();
      }
    });

    // Also listen to error stream
    final errorSubscription = _comfyService.errorStream.listen((error) {
      if (error.promptId == promptId) {
        _updateItemStatus(
          itemId,
          status: QueueStatus.failed,
          error: error.message,
        );
        if (!completer.isCompleted) {
          completer.completeError(Exception(error.message));
        }
      }
    });

    // Wait for completion or timeout
    try {
      await completer.future.timeout(const Duration(minutes: 30));
    } on TimeoutException {
      throw Exception('Generation timed out');
    } finally {
      await _progressSubscription?.cancel();
      await errorSubscription.cancel();
    }
  }

  /// Update item status
  void _updateItemStatus(
    String itemId, {
    QueueStatus? status,
    List<String>? resultImages,
    String? resultImageUrl,
    String? error,
    double? progress,
  }) {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    _items[index] = _items[index].copyWith(
      status: status,
      resultImages: resultImages,
      resultImageUrl: resultImageUrl,
      error: error,
      progress: progress,
      completedAt: status?.isTerminal == true ? DateTime.now() : null,
    );

    _notifyUpdate();
  }

  /// Update item progress
  void _updateItemProgress(String itemId, double progress, int step, int total) {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    _items[index] = _items[index].copyWith(
      progress: progress,
      currentStep: step,
      totalSteps: total,
    );

    _notifyUpdate();
  }

  /// Cancel the current generation
  Future<void> _cancelCurrentGeneration() async {
    await _progressSubscription?.cancel();

    try {
      await _comfyService.interrupt();
    } catch (e) {
      // Ignore cancel errors
    }
  }

  /// Sort items by priority
  void _sortByPriority() {
    _items.sort((a, b) {
      // Running items first
      if (a.status == QueueStatus.running && b.status != QueueStatus.running) return -1;
      if (b.status == QueueStatus.running && a.status != QueueStatus.running) return 1;

      // Then pending items by priority (higher priority first)
      if (a.status == QueueStatus.pending && b.status == QueueStatus.pending) {
        if (a.priority != b.priority) return b.priority.compareTo(a.priority);
        return a.createdAt.compareTo(b.createdAt);
      }

      // Pending before terminal
      if (a.status == QueueStatus.pending) return -1;
      if (b.status == QueueStatus.pending) return 1;

      // Terminal items by completion time (most recent first)
      return (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt);
    });
  }

  /// Notify listeners of queue update
  void _notifyUpdate() {
    _queueController.add(List.unmodifiable(_items));
  }

  /// Dispose resources
  void dispose() {
    _progressSubscription?.cancel();
    _queueController.close();
    _processingController.close();
  }
}
