import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/queue_item.dart';
import '../providers/generation_provider.dart';
import '../providers/lora_provider.dart';
import '../providers/session_provider.dart';
import 'api_service.dart';

/// Generation queue service provider
final generationQueueServiceProvider = Provider<GenerationQueueService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return GenerationQueueService(ref, apiService);
});

/// Service for managing the generation queue
class GenerationQueueService {
  final Ref _ref;
  final ApiService _apiService;

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

  /// Poll timer for progress updates
  Timer? _pollTimer;

  GenerationQueueService(this._ref, this._apiService);

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
    final session = _ref.read(sessionProvider);

    if (session.sessionId == null) {
      throw Exception('Not connected to server');
    }

    // Use video model if in video mode, otherwise regular model
    final modelToUse = item.params.videoMode
        ? (item.params.videoModel ?? item.params.model)
        : item.params.model;

    final response = await _apiService.post<Map<String, dynamic>>(
      '/api/GenerateText2ImageWS',
      data: {
        'session_id': session.sessionId,
        'prompt': item.params.prompt,
        'negativeprompt': item.params.negativePrompt,
        'model': modelToUse,
        'width': item.params.width,
        'height': item.params.height,
        'steps': item.params.steps,
        'cfgscale': item.params.cfgScale,
        'seed': item.params.seed,
        'sampler': item.params.sampler,
        'scheduler': item.params.scheduler,
        'images': 1, // Process one at a time
        if (item.loras != null && item.loras!.isNotEmpty)
          'loras': item.loras!.map((l) => l.toJson()).toList(),
        // Video parameters
        if (item.params.videoMode) 'video_mode': true,
        if (item.params.videoMode) 'frames': item.params.frames,
        if (item.params.videoMode) 'fps': item.params.fps,
        if (item.params.videoMode) 'video_format': item.params.videoFormat,
        // Variation seed parameters
        if (item.params.variationSeed != null) 'variationseed': item.params.variationSeed,
        if (item.params.variationStrength > 0) 'variationseedstrength': item.params.variationStrength,
        // Init image (img2img) parameters
        if (item.params.initImage != null) 'initimage': item.params.initImage,
        if (item.params.initImage != null) 'initimagecreativity': item.params.initImageCreativity,
        // Refine/Upscale parameters
        if (item.params.refinerModel != null && item.params.refinerModel != 'None')
          'refinermodel': item.params.refinerModel,
        if (item.params.upscaleFactor > 1.0) 'upscale': item.params.upscaleFactor,
        // ControlNet parameters
        if (item.params.controlNetImage != null) 'controlnetimage': item.params.controlNetImage,
        if (item.params.controlNetModel != null && item.params.controlNetModel != 'None')
          'controlnetmodel': item.params.controlNetModel,
        if (item.params.controlNetModel != null && item.params.controlNetModel != 'None')
          'controlnetstrength': item.params.controlNetStrength,
        ...item.params.extraParams,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Generation request failed');
    }

    final data = response.data!;
    final generationId = data['generation_id'] as String?;

    if (data['status'] == 'generating' && generationId != null) {
      // Start polling for progress
      await _pollForCompletion(item.id, generationId);
    } else if (data['status'] == 'completed' && data['images'] != null) {
      // Synchronous completion
      final images = (data['images'] as List).cast<String>();
      final fullUrls = images.map((path) => '${_apiService.baseUrl}$path').toList();

      _updateItemStatus(
        item.id,
        status: QueueStatus.completed,
        resultImages: fullUrls,
        resultImageUrl: fullUrls.isNotEmpty ? fullUrls.first : null,
      );
    } else if (data['status'] == 'error') {
      throw Exception(data['error'] ?? 'Generation failed');
    }
  }

  /// Poll for generation completion
  Future<void> _pollForCompletion(String itemId, String generationId) async {
    final completer = Completer<void>();

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) async {
      try {
        final response = await _apiService.post<Map<String, dynamic>>(
          '/api/GetProgress',
          data: {'prompt_id': generationId},
        );

        if (!response.isSuccess || response.data == null) return;

        final data = response.data!;
        final status = data['status'] as String?;

        if (status == 'completed') {
          timer.cancel();
          final imagesList = data['images'] as List? ?? [];
          final fullUrls = imagesList
              .map((path) => '${_apiService.baseUrl}$path')
              .cast<String>()
              .toList();

          _updateItemStatus(
            itemId,
            status: QueueStatus.completed,
            resultImages: fullUrls,
            resultImageUrl: fullUrls.isNotEmpty ? fullUrls.first : null,
            progress: 1.0,
          );

          if (!completer.isCompleted) completer.complete();
        } else if (status == 'error') {
          timer.cancel();
          _updateItemStatus(
            itemId,
            status: QueueStatus.failed,
            error: data['error'] as String? ?? 'Generation failed',
          );

          if (!completer.isCompleted) {
            completer.completeError(Exception(data['error'] ?? 'Generation failed'));
          }
        } else if (status == 'generating' || status == 'queued') {
          final step = data['step'] as int? ?? 0;
          final total = data['total'] as int? ?? 0;
          final progress = total > 0 ? step / total : 0.0;

          _updateItemProgress(itemId, progress, step, total);
        }
      } catch (e) {
        // Ignore poll errors, will retry
      }
    });

    // Wait for completion or timeout
    try {
      await completer.future.timeout(const Duration(minutes: 30));
    } on TimeoutException {
      _pollTimer?.cancel();
      throw Exception('Generation timed out');
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
    final session = _ref.read(sessionProvider);
    _pollTimer?.cancel();

    try {
      await _apiService.post('/api/InterruptGeneration', data: {
        'session_id': session.sessionId,
      });
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
    _pollTimer?.cancel();
    _queueController.close();
    _processingController.close();
  }
}
