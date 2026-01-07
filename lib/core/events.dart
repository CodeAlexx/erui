import 'dart:async';
import '../utils/logging.dart';

/// Simple event system for EriUI - mirrors SwarmUI's event pattern
class Event {
  final List<void Function()> _handlers = [];
  final String? name;

  Event([this.name]);

  /// Add an event handler
  void add(void Function() handler) {
    _handlers.add(handler);
  }

  /// Remove an event handler
  void remove(void Function() handler) {
    _handlers.remove(handler);
  }

  /// Invoke all handlers
  void invoke() {
    for (final handler in List.from(_handlers)) {
      try {
        handler();
      } catch (e, stack) {
        Logs.error('Event handler error${name != null ? ' in $name' : ''}: $e', e, stack);
      }
    }
  }

  /// Clear all handlers
  void clear() {
    _handlers.clear();
  }

  /// Number of registered handlers
  int get handlerCount => _handlers.length;
}

/// Event with a single argument
class Event1<T> {
  final List<void Function(T)> _handlers = [];
  final String? name;

  Event1([this.name]);

  void add(void Function(T) handler) {
    _handlers.add(handler);
  }

  void remove(void Function(T) handler) {
    _handlers.remove(handler);
  }

  void invoke(T arg) {
    for (final handler in List.from(_handlers)) {
      try {
        handler(arg);
      } catch (e, stack) {
        Logs.error('Event handler error${name != null ? ' in $name' : ''}: $e', e, stack);
      }
    }
  }

  void clear() {
    _handlers.clear();
  }

  int get handlerCount => _handlers.length;
}

/// Event with two arguments
class Event2<T1, T2> {
  final List<void Function(T1, T2)> _handlers = [];
  final String? name;

  Event2([this.name]);

  void add(void Function(T1, T2) handler) {
    _handlers.add(handler);
  }

  void remove(void Function(T1, T2) handler) {
    _handlers.remove(handler);
  }

  void invoke(T1 arg1, T2 arg2) {
    for (final handler in List.from(_handlers)) {
      try {
        handler(arg1, arg2);
      } catch (e, stack) {
        Logs.error('Event handler error${name != null ? ' in $name' : ''}: $e', e, stack);
      }
    }
  }

  void clear() {
    _handlers.clear();
  }

  int get handlerCount => _handlers.length;
}

/// Async event that can be awaited
class AsyncEvent {
  final List<Future<void> Function()> _handlers = [];
  final String? name;

  AsyncEvent([this.name]);

  void add(Future<void> Function() handler) {
    _handlers.add(handler);
  }

  void remove(Future<void> Function() handler) {
    _handlers.remove(handler);
  }

  Future<void> invoke() async {
    for (final handler in List.from(_handlers)) {
      try {
        await handler();
      } catch (e, stack) {
        Logs.error('Async event handler error${name != null ? ' in $name' : ''}: $e', e, stack);
      }
    }
  }

  /// Invoke all handlers in parallel
  Future<void> invokeParallel() async {
    await Future.wait(
      _handlers.map((h) async {
        try {
          await h();
        } catch (e, stack) {
          Logs.error('Async event handler error${name != null ? ' in $name' : ''}: $e', e, stack);
        }
      }),
    );
  }

  void clear() {
    _handlers.clear();
  }

  int get handlerCount => _handlers.length;
}

/// Cancellation token source - equivalent to C#'s CancellationTokenSource
class CancellationTokenSource {
  bool _cancelled = false;
  final Completer<void> _completer = Completer<void>();

  /// Whether cancellation has been requested
  bool get isCancelled => _cancelled;

  /// Get the cancellation token
  CancellationToken get token => CancellationToken(this);

  /// Request cancellation
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  /// Future that completes when cancelled
  Future<void> get whenCancelled => _completer.future;
}

/// Cancellation token - pass this to async operations
class CancellationToken {
  final CancellationTokenSource _source;

  CancellationToken(this._source);

  /// Whether cancellation has been requested
  bool get isCancelled => _source.isCancelled;

  /// Future that completes when cancelled
  Future<void> get whenCancelled => _source.whenCancelled;

  /// Throw if cancellation was requested
  void throwIfCancelled() {
    if (isCancelled) {
      throw CancelledException();
    }
  }

  /// Create a "none" token that never cancels
  static CancellationToken get none => CancellationToken(CancellationTokenSource());

  /// Wait for a duration, respecting cancellation
  Future<void> delay(Duration duration) async {
    if (isCancelled) {
      throw CancelledException();
    }

    await Future.any([
      Future.delayed(duration),
      whenCancelled.then((_) => throw CancelledException()),
    ]);
  }
}

/// Exception thrown when an operation is cancelled
class CancelledException implements Exception {
  final String? message;

  CancelledException([this.message]);

  @override
  String toString() => message ?? 'Operation was cancelled';
}

/// Linked cancellation token source - cancels when any parent cancels
class LinkedCancellationTokenSource extends CancellationTokenSource {
  final List<CancellationToken> _parents = [];
  final List<StreamSubscription> _subscriptions = [];

  LinkedCancellationTokenSource(List<CancellationToken> parents) {
    for (final parent in parents) {
      _parents.add(parent);
      if (parent.isCancelled) {
        cancel();
        return;
      }
      _subscriptions.add(
        parent.whenCancelled.asStream().listen((_) => cancel()),
      );
    }
  }

  @override
  void cancel() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.cancel();
  }
}
