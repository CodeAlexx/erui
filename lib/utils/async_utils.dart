import 'dart:async';
import '../core/events.dart';

/// Async auto-reset event - similar to C#'s AutoResetEvent
/// Automatically resets after one waiter is released
class AsyncAutoResetEvent {
  Completer<void>? _completer;
  bool _signaled = false;

  /// Signal the event, releasing one waiter
  void set() {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete();
      _completer = null;
      _signaled = false;
    } else {
      _signaled = true;
    }
  }

  /// Wait for the event to be signaled
  Future<void> wait() async {
    if (_signaled) {
      _signaled = false;
      return;
    }
    _completer ??= Completer<void>();
    await _completer!.future;
  }

  /// Wait with timeout, returns true if signaled, false if timed out
  Future<bool> waitTimeout(Duration timeout) async {
    if (_signaled) {
      _signaled = false;
      return true;
    }
    _completer ??= Completer<void>();
    try {
      await _completer!.future.timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  /// Reset the event
  void reset() {
    _signaled = false;
  }
}

/// Async manual reset event - similar to C#'s ManualResetEvent
/// Stays signaled until explicitly reset
class AsyncManualResetEvent {
  Completer<void> _completer = Completer<void>();
  bool _signaled = false;

  AsyncManualResetEvent([bool initialState = false]) {
    if (initialState) {
      _signaled = true;
      _completer.complete();
    }
  }

  /// Signal the event, releasing all waiters
  void set() {
    if (!_signaled) {
      _signaled = true;
      if (!_completer.isCompleted) {
        _completer.complete();
      }
    }
  }

  /// Reset the event
  void reset() {
    if (_signaled) {
      _signaled = false;
      _completer = Completer<void>();
    }
  }

  /// Wait for the event to be signaled
  Future<void> wait() async {
    if (_signaled) return;
    await _completer.future;
  }

  /// Whether the event is currently signaled
  bool get isSignaled => _signaled;

  /// Whether the event has been completed
  bool get isCompleted => _signaled;
}

/// Lock object for mutual exclusion - similar to C#'s lock/SemaphoreSlim(1,1)
class LockObject {
  final _lock = Completer<void>();
  bool _isLocked = false;
  Completer<void>? _waiter;

  /// Acquire the lock
  Future<void> acquire() async {
    while (_isLocked) {
      _waiter ??= Completer<void>();
      await _waiter!.future;
    }
    _isLocked = true;
  }

  /// Release the lock
  void release() {
    _isLocked = false;
    if (_waiter != null && !_waiter!.isCompleted) {
      final w = _waiter;
      _waiter = null;
      w!.complete();
    }
  }

  /// Execute a function while holding the lock
  Future<T> withLock<T>(Future<T> Function() action) async {
    await acquire();
    try {
      return await action();
    } finally {
      release();
    }
  }

  /// Whether the lock is currently held
  bool get isLocked => _isLocked;
}

/// Semaphore for limiting concurrent access
class AsyncSemaphore {
  final int maxCount;
  int _currentCount;
  final List<Completer<void>> _waiters = [];

  AsyncSemaphore(this.maxCount) : _currentCount = maxCount;

  /// Wait to acquire a semaphore slot
  Future<void> wait() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
  }

  /// Wait with timeout, returns true if acquired
  Future<bool> waitTimeout(Duration timeout) async {
    if (_currentCount > 0) {
      _currentCount--;
      return true;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    try {
      await completer.future.timeout(timeout);
      return true;
    } on TimeoutException {
      _waiters.remove(completer);
      return false;
    }
  }

  /// Release a semaphore slot
  void release() {
    if (_waiters.isNotEmpty) {
      final waiter = _waiters.removeAt(0);
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    } else {
      _currentCount++;
    }
  }

  /// Current available count
  int get currentCount => _currentCount;
}

/// Many-read-one-write lock (reader-writer lock)
class ManyReadOneWriteLock {
  final int maxReaders;
  int _readers = 0;
  bool _writerActive = false;
  final List<Completer<void>> _writerQueue = [];
  final List<Completer<void>> _readerQueue = [];

  ManyReadOneWriteLock({this.maxReaders = 64});

  /// Enter read lock
  Future<void> enterRead() async {
    while (_writerActive || _writerQueue.isNotEmpty || _readers >= maxReaders) {
      final completer = Completer<void>();
      _readerQueue.add(completer);
      await completer.future;
    }
    _readers++;
  }

  /// Exit read lock
  void exitRead() {
    _readers--;
    _releaseWaiters();
  }

  /// Enter write lock
  Future<void> enterWrite() async {
    while (_writerActive || _readers > 0) {
      final completer = Completer<void>();
      _writerQueue.add(completer);
      await completer.future;
    }
    _writerActive = true;
  }

  /// Exit write lock
  void exitWrite() {
    _writerActive = false;
    _releaseWaiters();
  }

  void _releaseWaiters() {
    // Prefer writers over readers
    if (_writerQueue.isNotEmpty && _readers == 0 && !_writerActive) {
      final waiter = _writerQueue.removeAt(0);
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    } else if (!_writerActive && _writerQueue.isEmpty) {
      // Release readers
      while (_readerQueue.isNotEmpty && _readers < maxReaders) {
        final waiter = _readerQueue.removeAt(0);
        if (!waiter.isCompleted) {
          waiter.complete();
        }
      }
    }
  }

  /// Execute while holding read lock
  Future<T> withRead<T>(Future<T> Function() action) async {
    await enterRead();
    try {
      return await action();
    } finally {
      exitRead();
    }
  }

  /// Execute while holding write lock
  Future<T> withWrite<T>(Future<T> Function() action) async {
    await enterWrite();
    try {
      return await action();
    } finally {
      exitWrite();
    }
  }
}

/// Rate limiter for throttling operations
class RateLimiter {
  final Duration interval;
  final int maxCalls;

  final List<DateTime> _callTimes = [];

  RateLimiter({
    required this.interval,
    required this.maxCalls,
  });

  /// Wait until a call is allowed
  Future<void> acquire() async {
    final now = DateTime.now();
    final cutoff = now.subtract(interval);

    // Remove old calls
    _callTimes.removeWhere((t) => t.isBefore(cutoff));

    // If at limit, wait
    if (_callTimes.length >= maxCalls) {
      final oldest = _callTimes.first;
      final waitTime = oldest.add(interval).difference(now);
      if (waitTime > Duration.zero) {
        await Future.delayed(waitTime);
      }
      _callTimes.removeAt(0);
    }

    _callTimes.add(DateTime.now());
  }

  /// Check if a call would be allowed (without waiting)
  bool canCall() {
    final now = DateTime.now();
    final cutoff = now.subtract(interval);
    _callTimes.removeWhere((t) => t.isBefore(cutoff));
    return _callTimes.length < maxCalls;
  }
}

/// Debouncer - delays execution until no calls for a period
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  bool get isActive => _timer?.isActive ?? false;
}

/// Throttler - ensures at most one execution per period
class Throttler {
  final Duration interval;
  DateTime? _lastRun;
  Timer? _pendingTimer;
  void Function()? _pendingAction;

  Throttler({required this.interval});

  void run(void Function() action) {
    final now = DateTime.now();

    if (_lastRun == null || now.difference(_lastRun!) >= interval) {
      _lastRun = now;
      action();
      _pendingAction = null;
      _pendingTimer?.cancel();
      _pendingTimer = null;
    } else {
      _pendingAction = action;
      _pendingTimer ??= Timer(interval - now.difference(_lastRun!), () {
        final pending = _pendingAction;
        _pendingAction = null;
        _pendingTimer = null;
        if (pending != null) {
          run(pending);
        }
      });
    }
  }

  void cancel() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
    _pendingAction = null;
  }
}

/// Retry helper with exponential backoff
class RetryHelper {
  static Future<T> retry<T>({
    required Future<T> Function() action,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 100),
    double backoffMultiplier = 2.0,
    Duration maxDelay = const Duration(seconds: 30),
    bool Function(Object error)? shouldRetry,
    CancellationToken? cancel,
  }) async {
    var delay = initialDelay;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        cancel?.throwIfCancelled();
        return await action();
      } catch (e) {
        if (attempt >= maxAttempts) rethrow;
        if (shouldRetry != null && !shouldRetry(e)) rethrow;
        if (e is CancelledException) rethrow;

        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * backoffMultiplier).toInt(),
        );
        if (delay > maxDelay) delay = maxDelay;
      }
    }

    throw StateError('Retry loop completed without result');
  }
}
