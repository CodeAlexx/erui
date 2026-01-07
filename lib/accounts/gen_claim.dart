import '../core/events.dart';
import 'session.dart';

/// Tracks a single generation request lifecycle
/// Equivalent to SwarmUI's GenClaim class
class GenClaim {
  static int _nextId = 0;

  /// Unique claim ID within this server instance
  final int id;

  /// Parent session
  final Session session;

  /// Token that gets cancelled when session is interrupted
  final CancellationToken interruptToken;

  /// Local cancellation token for this specific claim
  final CancellationTokenSource localClaimInterrupt = CancellationTokenSource();

  // Private state counters for this claim
  int _waitingGenerations;
  int _loadingModels;
  int _waitingBackends;
  int _liveGens;

  bool _disposed = false;

  /// Timestamp when claim was created
  final int createdTime = DateTime.now().millisecondsSinceEpoch;

  /// Extra data attached to this claim
  final Map<String, dynamic> data = {};

  GenClaim({
    required this.session,
    int waitingGenerations = 0,
    int loadingModels = 0,
    int waitingBackends = 0,
    int liveGens = 0,
  })  : id = _nextId++,
        interruptToken = session.sessInterrupt.token,
        _waitingGenerations = waitingGenerations,
        _loadingModels = loadingModels,
        _waitingBackends = waitingBackends,
        _liveGens = liveGens {
    // Update session counters
    session.waitingGenerations += waitingGenerations;
    session.loadingModels += loadingModels;
    session.waitingBackends += waitingBackends;
    session.liveGens += liveGens;
  }

  /// Should this claim be cancelled?
  bool get shouldCancel =>
      interruptToken.isCancelled || localClaimInterrupt.isCancelled;

  /// Get number of waiting generations in this claim
  int get waitingGenerations => _waitingGenerations;

  /// Get number of models loading in this claim
  int get loadingModels => _loadingModels;

  /// Get number of backend waits in this claim
  int get waitingBackends => _waitingBackends;

  /// Get number of live generations in this claim
  int get liveGens => _liveGens;

  /// Whether this claim has been disposed
  bool get isDisposed => _disposed;

  /// How long this claim has been active
  Duration get age =>
      Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - createdTime);

  /// Extend claim size
  void extend({
    int gens = 0,
    int modelLoads = 0,
    int backendWaits = 0,
    int liveGens = 0,
  }) {
    if (_disposed) {
      throw StateError('Cannot extend a disposed GenClaim');
    }

    _waitingGenerations += gens;
    _loadingModels += modelLoads;
    _waitingBackends += backendWaits;
    _liveGens += liveGens;

    session.waitingGenerations += gens;
    session.loadingModels += modelLoads;
    session.waitingBackends += backendWaits;
    session.liveGens += liveGens;
  }

  /// Mark steps as complete (decrements counters)
  void complete({
    int gens = 0,
    int modelLoads = 0,
    int backendWaits = 0,
    int liveGens = 0,
  }) {
    extend(
      gens: -gens,
      modelLoads: -modelLoads,
      backendWaits: -backendWaits,
      liveGens: -liveGens,
    );
  }

  /// Transition from waiting to live
  void transitionToLive({int count = 1}) {
    complete(gens: count);
    extend(liveGens: count);
  }

  /// Transition from live to done
  void transitionToDone({int count = 1}) {
    complete(liveGens: count);
  }

  /// Mark model as loaded
  void modelLoaded({int count = 1}) {
    complete(modelLoads: count);
  }

  /// Mark backend as acquired
  void backendAcquired({int count = 1}) {
    complete(backendWaits: count);
  }

  /// Cancel just this claim
  void cancel() {
    localClaimInterrupt.cancel();
  }

  /// Throw if cancellation requested
  void throwIfCancelled() {
    if (shouldCancel) {
      throw CancelledException('Generation claim was cancelled');
    }
  }

  /// Dispose and cleanup
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // Complete any remaining counts
    complete(
      gens: _waitingGenerations,
      modelLoads: _loadingModels,
      backendWaits: _waitingBackends,
      liveGens: _liveGens,
    );

    // Remove from session
    session.claims.remove(id);
  }

  @override
  String toString() =>
      'GenClaim($id, waiting: $_waitingGenerations, loading: $_loadingModels, '
      'backends: $_waitingBackends, live: $_liveGens)';
}

/// Extension to use GenClaim as a resource in a try-finally pattern
extension GenClaimResource on GenClaim {
  /// Use this claim in a function and automatically dispose when done
  Future<T> use<T>(Future<T> Function(GenClaim claim) action) async {
    try {
      return await action(this);
    } finally {
      dispose();
    }
  }

  /// Synchronous version
  T useSync<T>(T Function(GenClaim claim) action) {
    try {
      return action(this);
    } finally {
      dispose();
    }
  }
}
