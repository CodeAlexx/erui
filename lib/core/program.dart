import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/logging.dart';
import '../utils/fds_parser.dart';
import '../utils/async_utils.dart';
import 'settings.dart';
import 'events.dart';
import '../accounts/session_handler.dart';
import '../accounts/permissions.dart';
import '../backends/backend_handler.dart';
import '../text2image/t2i_model_handler.dart';
import '../api/api.dart';
import '../api/endpoints/basic_api.dart';
import '../api/endpoints/models_api.dart';
import '../api/endpoints/t2i_api.dart';
import '../api/endpoints/advanced_t2i_api.dart';
import '../api/endpoints/system_api.dart';
import '../api/endpoints/history_api.dart';
import '../text2image/t2i_param_types.dart';

/// Central orchestrator for EriUI server
/// Equivalent to SwarmUI's Program.cs
class Program {
  // Singleton instance
  static final Program instance = Program._internal();
  factory Program() => instance;
  Program._internal();

  // ========== CORE COMPONENTS ==========

  late BackendHandler backends;
  late SessionHandler sessions;
  late Settings serverSettings;

  // ========== MODEL REGISTRIES ==========

  final Map<String, T2IModelHandler> t2iModelSets = {};

  // ========== CANCELLATION & SHUTDOWN ==========

  final CancellationTokenSource _globalCancelSource = CancellationTokenSource();
  CancellationToken get globalProgramCancel => _globalCancelSource.token;
  bool _hasShutdown = false;
  bool _initialized = false;

  // ========== CONFIGURATION ==========

  String dataDir = 'Data';
  String? settingsFilePath;
  String launchMode = 'web';
  bool lockSettings = false;
  bool noPersist = false;

  // ========== COMMAND LINE FLAGS ==========

  final Map<String, String> commandLineFlags = {};

  // ========== EVENT SYSTEM ==========

  final Event modelRefreshEvent = Event('modelRefresh');
  final Event tickIsGeneratingEvent = Event('tickIsGenerating');
  final Event tickNoGenerationsEvent = Event('tickNoGenerations');
  final Event tickEvent = Event('tick');
  final Event slowTickEvent = Event('slowTick');
  final Event modelPathsChangedEvent = Event('modelPathsChanged');
  final Event preShutdownEvent = Event('preShutdown');

  // ========== RUNTIME STATE ==========

  final ManyReadOneWriteLock refreshLock = ManyReadOneWriteLock(maxReaders: 64);
  String? versionUpdateMessage;
  String? currentGitDate;
  int exitCode = 0;

  // ========== TICK TIMERS ==========

  Timer? _tickTimer;
  Timer? _slowTickTimer;

  // ========== INITIALIZATION ==========

  /// Initialize the program
  Future<void> init(List<String> args) async {
    if (_initialized) {
      throw StateError('Program already initialized');
    }

    await _phase0_processSetup();
    await _phase1_configurationLoad(args);
    await _phase2_parallelStartup();
    await _phase3_modelParameterRegistration();
    await _phase4_coreHandlerInit();
    await _phase5_modelLoading();
    await _phase6_backendLoading();
    await _phase7_apiRegistration();

    _initialized = true;
    Logs.init('EriUI Server fully initialized');
  }

  /// Phase 0: Process setup
  Future<void> _phase0_processSetup() async {
    Logs.init('EriUI Server Starting...');

    // Register shutdown handlers
    ProcessSignal.sigint.watch().listen((_) => shutdown());
    ProcessSignal.sigterm.watch().listen((_) => shutdown());
  }

  /// Phase 1: Configuration load
  Future<void> _phase1_configurationLoad(List<String> args) async {
    _parseCommandLineArgs(args);

    dataDir = commandLineFlags['data_dir'] ?? 'Data';
    settingsFilePath = commandLineFlags['settings_file'] ?? '$dataDir/Settings.fds';
    launchMode = commandLineFlags['launch_mode'] ?? 'web';
    noPersist = commandLineFlags['no_persist'] == 'true';

    await _loadSettingsFile();

    Logs.info('Configuration loaded from $settingsFilePath');
  }

  /// Phase 2: Parallel startup tasks
  Future<void> _phase2_parallelStartup() async {
    // Ensure data directory exists
    await Directory(dataDir).create(recursive: true);

    // Initialize Permissions
    Permissions.registerDefaults();

    Logs.debug('Parallel startup complete');
  }

  /// Phase 3: Model & parameter registration
  Future<void> _phase3_modelParameterRegistration() async {
    _buildModelLists();
    Logs.debug('Model paths registered');
  }

  /// Phase 4: Core handler initialization
  Future<void> _phase4_coreHandlerInit() async {
    backends = BackendHandler(
      saveFilePath: commandLineFlags['backends_file'] ?? '$dataDir/Backends.fds',
    );

    sessions = SessionHandler(dataDir: dataDir);
    sessions.noPersist = noPersist;
    await sessions.init();

    // Start tick timers
    _startTickLoops();

    Logs.debug('Core handlers initialized');
  }

  /// Phase 5: Model loading
  Future<void> _phase5_modelLoading() async {
    await refreshAllModelSets();
    // Create composite handler
    modelHandler = CompositeModelHandler(t2iModelSets);
    Logs.debug('Models loaded');
  }

  /// Phase 6: Backend loading
  Future<void> _phase6_backendLoading() async {
    await backends.load();
    Logs.debug('Backends loaded');
  }

  /// Phase 7: API registration
  Future<void> _phase7_apiRegistration() async {
    // Register parameter types first
    T2IParamTypes.registerDefaults();

    // Register API endpoints
    BasicAPI.register();
    ModelsAPI.register();
    T2IAPI.register();
    AdvancedT2IAPI.register();
    SystemAPI.register();
    HistoryAPI.register();
    Logs.debug('API endpoints registered: ${Api.endpoints.length}');
  }

  /// Composite model handler for all model types
  late CompositeModelHandler modelHandler;

  /// Get model handler for a specific type
  T2IModelHandler? getModelHandler(String type) => t2iModelSets[type];

  // ========== SHUTDOWN ==========

  /// Shutdown the program
  Future<void> shutdown([int code = 0]) async {
    if (_hasShutdown) return;
    _hasShutdown = true;

    Logs.info('Shutting down...');

    exitCode = code;

    // Fire pre-shutdown event
    preShutdownEvent.invoke();

    // Cancel all operations
    _globalCancelSource.cancel();

    // Stop tick timers
    _tickTimer?.cancel();
    _slowTickTimer?.cancel();

    // Shutdown components
    await backends.shutdown();
    await sessions.shutdown();

    for (final handler in t2iModelSets.values) {
      handler.shutdown();
    }

    await Logs.shutdown();

    Logs.info('All core shutdowns complete.');
  }

  // ========== MODEL MANAGEMENT ==========

  void _buildModelLists() {
    final paths = serverSettings.paths;
    final modelRoot = paths.modelRoot;

    t2iModelSets['Stable-Diffusion'] = T2IModelHandler(
      modelType: 'Stable-Diffusion',
      folderPaths: _resolveModelPaths(modelRoot, paths.sdModelFolder),
    );

    t2iModelSets['VAE'] = T2IModelHandler(
      modelType: 'VAE',
      folderPaths: _resolveModelPaths(modelRoot, paths.sdVAEFolder),
    );

    t2iModelSets['LoRA'] = T2IModelHandler(
      modelType: 'LoRA',
      folderPaths: _resolveModelPaths(modelRoot, paths.sdLoraFolder),
    );

    t2iModelSets['Embedding'] = T2IModelHandler(
      modelType: 'Embedding',
      folderPaths: _resolveModelPaths(modelRoot, paths.sdEmbeddingFolder),
    );

    t2iModelSets['ControlNet'] = T2IModelHandler(
      modelType: 'ControlNet',
      folderPaths: _resolveModelPaths(modelRoot, paths.sdControlNetsFolder),
    );

    t2iModelSets['Clip'] = T2IModelHandler(
      modelType: 'Clip',
      folderPaths: _resolveModelPaths(modelRoot, paths.sdClipFolder),
    );

    t2iModelSets['ClipVision'] = T2IModelHandler(
      modelType: 'ClipVision',
      folderPaths: _resolveModelPaths(modelRoot, paths.sdClipVisionFolder),
    );
  }

  Future<void> refreshAllModelSets() async {
    await refreshLock.enterWrite();
    try {
      for (final handler in t2iModelSets.values) {
        await handler.refresh();
      }
      modelRefreshEvent.invoke();
    } finally {
      refreshLock.exitWrite();
    }
  }

  // ========== UTILITIES ==========

  void _parseCommandLineArgs(List<String> args) {
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];

      if (arg.startsWith('--')) {
        final key = arg.substring(2);
        String? value;

        if (key.contains('=')) {
          final parts = key.split('=');
          commandLineFlags[parts[0]] = parts.sublist(1).join('=');
        } else if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
          value = args[++i];
          commandLineFlags[key] = value;
        } else {
          commandLineFlags[key] = 'true';
        }
      }
    }
  }

  Future<void> _loadSettingsFile() async {
    serverSettings = await Settings.loadFromFile(settingsFilePath!);

    // Apply log level from settings
    final logLevel = Logs.parseLevel(serverSettings.logs.logLevel);
    Logs.setLevel(logLevel);
  }

  List<String> _resolveModelPaths(String root, String folder) {
    final paths = <String>[];

    for (final r in root.split(';')) {
      for (final f in folder.split(';')) {
        final path = p.join(r.trim(), f.trim());
        paths.add(path);
      }
    }

    return paths;
  }

  void _startTickLoops() {
    // Fast tick every 100ms
    _tickTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (globalProgramCancel.isCancelled) return;
      tickEvent.invoke();
    });

    // Slow tick every 5 seconds
    _slowTickTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (globalProgramCancel.isCancelled) return;
      slowTickEvent.invoke();
    });
  }
}
