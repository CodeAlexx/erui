import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/queue_item.dart';
import '../services/generation_queue_service.dart';
import 'generation_provider.dart';
import 'lora_provider.dart';

/// Queue state for the UI
class LocalQueueState {
  final List<QueueItem> items;
  final bool isProcessing;
  final bool isPaused;
  final QueueItem? currentItem;
  final int pendingCount;
  final int runningCount;
  final int completedCount;
  final int failedCount;

  const LocalQueueState({
    this.items = const [],
    this.isProcessing = false,
    this.isPaused = false,
    this.currentItem,
    this.pendingCount = 0,
    this.runningCount = 0,
    this.completedCount = 0,
    this.failedCount = 0,
  });

  LocalQueueState copyWith({
    List<QueueItem>? items,
    bool? isProcessing,
    bool? isPaused,
    QueueItem? currentItem,
    int? pendingCount,
    int? runningCount,
    int? completedCount,
    int? failedCount,
  }) {
    return LocalQueueState(
      items: items ?? this.items,
      isProcessing: isProcessing ?? this.isProcessing,
      isPaused: isPaused ?? this.isPaused,
      currentItem: currentItem ?? this.currentItem,
      pendingCount: pendingCount ?? this.pendingCount,
      runningCount: runningCount ?? this.runningCount,
      completedCount: completedCount ?? this.completedCount,
      failedCount: failedCount ?? this.failedCount,
    );
  }

  /// Check if queue is empty
  bool get isEmpty => items.isEmpty;

  /// Check if queue has pending items
  bool get hasPending => pendingCount > 0;

  /// Total items in queue
  int get totalCount => items.length;

  /// Get items by status
  List<QueueItem> get pendingItems =>
      items.where((item) => item.status == QueueStatus.pending).toList();

  List<QueueItem> get runningItems =>
      items.where((item) => item.status == QueueStatus.running).toList();

  List<QueueItem> get completedItems =>
      items.where((item) => item.status == QueueStatus.completed).toList();

  List<QueueItem> get failedItems =>
      items.where((item) => item.status == QueueStatus.failed).toList();
}

/// Queue state notifier
class LocalQueueNotifier extends StateNotifier<LocalQueueState> {
  final GenerationQueueService _queueService;
  StreamSubscription<List<QueueItem>>? _queueSubscription;
  StreamSubscription<bool>? _processingSubscription;

  LocalQueueNotifier(this._queueService) : super(const LocalQueueState()) {
    _syncFromService();
    _setupSubscriptions();
  }

  /// Sync state from service
  void _syncFromService() {
    state = LocalQueueState(
      items: _queueService.items,
      isProcessing: _queueService.isProcessing,
      isPaused: _queueService.isPaused,
      currentItem: _queueService.currentItem,
      pendingCount: _queueService.pendingCount,
      runningCount: _queueService.runningCount,
      completedCount: _queueService.completedItems.length,
      failedCount: _queueService.failedItems.length,
    );
  }

  /// Setup stream subscriptions
  void _setupSubscriptions() {
    _queueSubscription = _queueService.queueStream.listen((items) {
      state = state.copyWith(
        items: items,
        currentItem: _queueService.currentItem,
        pendingCount: items.where((i) => i.status == QueueStatus.pending).length,
        runningCount: items.where((i) => i.status == QueueStatus.running).length,
        completedCount: items.where((i) => i.status == QueueStatus.completed).length,
        failedCount: items.where((i) => i.status == QueueStatus.failed).length,
      );
    });

    _processingSubscription = _queueService.processingStream.listen((isProcessing) {
      state = state.copyWith(
        isProcessing: isProcessing,
        isPaused: _queueService.isPaused,
      );
    });
  }

  /// Add a single item to the queue
  QueueItem add(GenerationParams params, {List<SelectedLora>? loras, int priority = 0}) {
    return _queueService.addItem(params, loras: loras, priority: priority);
  }

  /// Add multiple items to the queue (batch)
  List<QueueItem> addBatch(
    GenerationParams params, {
    List<SelectedLora>? loras,
    int count = 1,
    int priority = 0,
  }) {
    return _queueService.addBatch(params, loras: loras, count: count, priority: priority);
  }

  /// Remove an item from the queue
  bool remove(String id) {
    return _queueService.removeItem(id);
  }

  /// Cancel an item
  Future<bool> cancel(String id) async {
    return await _queueService.cancelItem(id);
  }

  /// Reorder items
  void reorder(List<String> newOrder) {
    _queueService.reorder(newOrder);
  }

  /// Move an item to a specific index
  void moveItem(String id, int newIndex) {
    _queueService.moveItem(id, newIndex);
  }

  /// Pause the queue
  void pause() {
    _queueService.pause();
    state = state.copyWith(isPaused: true);
  }

  /// Resume the queue
  void resume() {
    _queueService.resume();
    state = state.copyWith(isPaused: false);
  }

  /// Clear pending items
  void clearPending() {
    _queueService.clearPending();
  }

  /// Clear completed/failed items
  void clearCompleted() {
    _queueService.clearCompleted();
  }

  /// Clear all items
  void clearAll() {
    _queueService.clearAll();
  }

  /// Retry a failed item
  void retry(String id) {
    _queueService.retryItem(id);
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    _processingSubscription?.cancel();
    super.dispose();
  }
}

/// Local queue provider
final localQueueProvider =
    StateNotifierProvider<LocalQueueNotifier, LocalQueueState>((ref) {
  final queueService = ref.watch(generationQueueServiceProvider);
  return LocalQueueNotifier(queueService);
});

/// Convenience providers

/// Whether the queue is processing
final isQueueProcessingProvider = Provider<bool>((ref) {
  return ref.watch(localQueueProvider).isProcessing;
});

/// Whether the queue is paused
final isQueuePausedProvider = Provider<bool>((ref) {
  return ref.watch(localQueueProvider).isPaused;
});

/// Current item being processed
final currentQueueItemProvider = Provider<QueueItem?>((ref) {
  return ref.watch(localQueueProvider).currentItem;
});

/// Number of pending items
final pendingQueueCountProvider = Provider<int>((ref) {
  return ref.watch(localQueueProvider).pendingCount;
});

/// Number of running items
final runningQueueCountProvider = Provider<int>((ref) {
  return ref.watch(localQueueProvider).runningCount;
});

/// All queue items
final queueItemsProvider = Provider<List<QueueItem>>((ref) {
  return ref.watch(localQueueProvider).items;
});

/// Pending queue items only
final pendingQueueItemsProvider = Provider<List<QueueItem>>((ref) {
  return ref.watch(localQueueProvider).pendingItems;
});

/// Completed queue items only
final completedQueueItemsProvider = Provider<List<QueueItem>>((ref) {
  return ref.watch(localQueueProvider).completedItems;
});
