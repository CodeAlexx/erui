import 'dart:async';
import 'dart:collection';
import 'dart:io';

import '../utils/logging.dart';
import '../utils/fds_parser.dart';
import '../utils/async_utils.dart';
import '../core/events.dart';
import 'abstract_backend.dart';
import 'backend_data.dart';
import 'backend_type.dart';
import 'comfyui/comfyui_backend.dart';

/// Central backend orchestrator
/// Equivalent to SwarmUI's BackendHandler
class BackendHandler {
  /// Path to save backends configuration
  final String saveFilePath;

  /// All registered backends
  final Map<int, BackendData> allBackends = {};

  /// Backend type registry
  final Map<String, BackendType> backendTypes = {};

  /// Pending backend requests
  final Map<int, T2IBackendRequest> t2iBackendRequests = {};

  /// Signal to check backends
  final AsyncAutoResetEvent checkBackendsSignal = AsyncAutoResetEvent();

  /// Signal for new backend initialization
  final AsyncAutoResetEvent newBackendInitSignal = AsyncAutoResetEvent();

  /// Backends waiting to be initialized
  final Queue<BackendData> backendsToInit = Queue();

  /// State tracking
  int _lastBackendId = 0;
  bool _backendsEdited = false;
  bool _hasShutdown = false;
  bool _isLoaded = false;

  /// Request handling timer
  Timer? _requestTimer;

  BackendHandler({required this.saveFilePath}) {
    _registerBuiltinTypes();
  }

  /// Register built-in backend types
  void _registerBuiltinTypes() {
    registerBackendType(BackendType(
      id: 'comfyui_api',
      name: 'ComfyUI API Backend',
      description: 'Connect to a ComfyUI instance',
      factory: (settings) => ComfyUIBackend(settings),
      settingsClass: ComfyUIBackendSettings,
    ));

    // TODO: Add more backend types
    // - ComfyUI Self-Start
    // - Remote Swarm
    // - Auto-scaling
  }

  /// Register a backend type
  void registerBackendType(BackendType type) {
    backendTypes[type.id] = type;
    Logs.debug('Registered backend type: ${type.id}');
  }

  /// Load backends from configuration file
  Future<void> load() async {
    if (_isLoaded) return;

    final file = File(saveFilePath);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final parsed = FdsParser.parse(content);

        for (final entry in parsed.entries) {
          final id = int.tryParse(entry.key);
          if (id == null) continue;

          final data = entry.value;
          if (data is! Map) continue;

          final typeId = data['type'] as String?;
          if (typeId == null) continue;

          final type = backendTypes[typeId];
          if (type == null) {
            Logs.warning('Unknown backend type: $typeId');
            continue;
          }

          await _loadBackend(id, type, Map<String, dynamic>.from(data));
        }
      } catch (e) {
        Logs.error('Failed to load backends: $e');
      }
    }

    // Start request handling
    _startRequestHandling();

    _isLoaded = true;
    Logs.info('Loaded ${allBackends.length} backends');
  }

  /// Load a single backend
  Future<void> _loadBackend(
    int id,
    BackendType type,
    Map<String, dynamic> data,
  ) async {
    final title = data['title'] as String? ?? 'Backend $id';
    final enabled = data['enabled'] as bool? ?? true;
    final settingsData = data['settings'] as Map<String, dynamic>? ?? {};

    final backend = type.factory(settingsData);
    final backendData = BackendData(
      id: id,
      title: title,
      type: type,
      backend: backend,
      enabled: enabled,
    );

    allBackends[id] = backendData;
    _lastBackendId = _lastBackendId > id ? _lastBackendId : id;

    if (enabled) {
      backendsToInit.add(backendData);
    }
  }

  /// Add a new backend
  Future<BackendData> addBackend({
    required String typeId,
    required String title,
    Map<String, dynamic>? settings,
    bool enabled = true,
  }) async {
    final type = backendTypes[typeId];
    if (type == null) {
      throw ArgumentError('Unknown backend type: $typeId');
    }

    final id = ++_lastBackendId;
    final backend = type.factory(settings ?? {});

    final backendData = BackendData(
      id: id,
      title: title,
      type: type,
      backend: backend,
      enabled: enabled,
    );

    allBackends[id] = backendData;
    _backendsEdited = true;

    if (enabled) {
      backendsToInit.add(backendData);
      newBackendInitSignal.set();
    }

    return backendData;
  }

  /// Remove a backend
  Future<void> removeBackend(int id) async {
    final backendData = allBackends.remove(id);
    if (backendData == null) return;

    await backendData.backend.shutdown();
    _backendsEdited = true;
  }

  /// Save backends to configuration file
  Future<void> save() async {
    final data = <String, dynamic>{};

    for (final entry in allBackends.entries) {
      data[entry.key.toString()] = {
        'type': entry.value.type.id,
        'title': entry.value.title,
        'enabled': entry.value.enabled,
        'settings': entry.value.backend.getSettings(),
      };
    }

    final file = File(saveFilePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(FdsParser.serialize(data));

    _backendsEdited = false;
  }

  /// Get next available T2I backend
  Future<T2IBackendAccess?> getNextT2IBackend({
    Duration maxWait = const Duration(minutes: 5),
    String? modelName,
    bool Function(BackendData)? filter,
    CancellationToken? cancel,
    void Function()? notifyWillLoad,
  }) async {
    final request = T2IBackendRequest(
      modelName: modelName,
      filter: filter,
      notifyWillLoad: notifyWillLoad,
    );

    t2iBackendRequests[request.id] = request;
    checkBackendsSignal.set();

    try {
      // Wait for completion or timeout
      final completed = await request.completedEvent.wait().timeout(
        maxWait,
        onTimeout: () => throw TimeoutException('Backend wait timeout'),
      );

      if (request.failure != null) {
        throw request.failure!;
      }

      return request.result;
    } catch (e) {
      request.failure = e is Exception ? e : Exception(e.toString());
      return null;
    } finally {
      t2iBackendRequests.remove(request.id);
    }
  }

  /// Start the request handling loop
  void _startRequestHandling() {
    _requestTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _processRequests();
    });

    // Also initialize pending backends
    _initializeBackends();
  }

  /// Process pending backend requests
  void _processRequests() {
    if (_hasShutdown) return;

    for (final request in t2iBackendRequests.values.toList()) {
      if (request.completedEvent.isSignaled) continue;

      _tryFindBackend(request);
    }
  }

  /// Try to find a backend for a request
  void _tryFindBackend(T2IBackendRequest request) {
    // Get available backends
    final available = allBackends.values
        .where((b) => b.enabled)
        .where((b) => b.backend.status == BackendStatus.running)
        .where((b) => !b.isInUse)
        .toList();

    if (available.isEmpty) {
      return; // No backends available, keep waiting
    }

    // Apply custom filter
    if (request.filter != null) {
      available.removeWhere((b) => !request.filter!(b));
    }

    if (available.isEmpty) {
      return; // No matching backends
    }

    // Find backend with model already loaded
    if (request.modelName != null) {
      final withModel = available
          .where((b) => b.currentModelName == request.modelName)
          .toList();

      if (withModel.isNotEmpty) {
        _claimBackend(request, withModel.first);
        return;
      }

      // Need to load model - find least busy backend
      request.notifyWillLoad?.call();
    }

    // Sort by least usage
    available.sort((a, b) => a.usageCount.compareTo(b.usageCount));

    // Claim first available
    _claimBackend(request, available.first);
  }

  /// Claim a backend for a request
  void _claimBackend(T2IBackendRequest request, BackendData backend) {
    backend.claim();
    request.result = T2IBackendAccess(backend);
    request.completedEvent.set();
  }

  /// Initialize pending backends
  void _initializeBackends() async {
    while (backendsToInit.isNotEmpty) {
      final backendData = backendsToInit.removeFirst();

      try {
        await backendData.backend.init();
        Logs.info('Initialized backend: ${backendData.title}');
      } catch (e) {
        Logs.error('Failed to initialize backend ${backendData.title}: $e');
        backendData.backend.status = BackendStatus.errored;
      }
    }
  }

  /// Interrupt all backends
  Future<void> interruptAll() async {
    for (final backend in allBackends.values) {
      try {
        await backend.backend.interrupt();
      } catch (e) {
        Logs.warning('Failed to interrupt backend ${backend.title}: $e');
      }
    }
  }

  /// Shutdown all backends
  Future<void> shutdown() async {
    if (_hasShutdown) return;
    _hasShutdown = true;

    _requestTimer?.cancel();

    // Cancel pending requests
    for (final request in t2iBackendRequests.values) {
      request.failure = Exception('Server shutting down');
      request.completedEvent.set();
    }
    t2iBackendRequests.clear();

    // Shutdown all backends
    for (final backend in allBackends.values) {
      try {
        await backend.backend.shutdown();
      } catch (e) {
        Logs.warning('Error shutting down backend ${backend.title}: $e');
      }
    }

    // Save if needed
    if (_backendsEdited) {
      await save();
    }

    allBackends.clear();
    Logs.info('Backend handler shutdown complete');
  }

  /// Get list of backend info for API
  List<Map<String, dynamic>> getBackendInfoList() {
    return allBackends.values.map((b) => {
      'id': b.id,
      'title': b.title,
      'type': b.type.id,
      'type_name': b.type.name,
      'enabled': b.enabled,
      'status': b.backend.status.name,
      'current_model': b.currentModelName,
      'is_in_use': b.isInUse,
      'usage_count': b.usageCount,
    }).toList();
  }

  /// Whether backends have been edited
  bool get backendsEdited => _backendsEdited;
  set backendsEdited(bool value) => _backendsEdited = value;
}

/// Request for a T2I backend
class T2IBackendRequest {
  static int _nextId = 0;

  final int id;
  final String? modelName;
  final bool Function(BackendData)? filter;
  final void Function()? notifyWillLoad;

  final AsyncManualResetEvent completedEvent = AsyncManualResetEvent();
  T2IBackendAccess? result;
  Exception? failure;

  T2IBackendRequest({
    this.modelName,
    this.filter,
    this.notifyWillLoad,
  }) : id = _nextId++;
}

/// Access wrapper for a claimed backend
class T2IBackendAccess {
  final BackendData _backend;
  bool _released = false;

  T2IBackendAccess(this._backend);

  /// Get the backend
  AbstractBackend get backend => _backend.backend;

  /// Get the backend data
  BackendData get data => _backend;

  /// Load a model on this backend
  Future<void> loadModel(String modelName) async {
    if (_released) {
      throw StateError('Backend access already released');
    }
    await _backend.backend.loadModel(modelName);
    _backend.currentModelName = modelName;
  }

  /// Release the backend
  void release() {
    if (_released) return;
    _released = true;
    _backend.release();
  }

  /// Use the backend with auto-release
  Future<T> use<T>(Future<T> Function(AbstractBackend) action) async {
    try {
      return await action(_backend.backend);
    } finally {
      release();
    }
  }
}
