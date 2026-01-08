import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:convert';

/// OneTrainer API service provider
final oneTrainerServiceProvider = Provider<OneTrainerService>((ref) {
  return OneTrainerService();
});

/// Training state provider - auto-updates via WebSocket
final trainingStateProvider = StateNotifierProvider<TrainingStateNotifier, TrainingState>((ref) {
  final service = ref.watch(oneTrainerServiceProvider);
  return TrainingStateNotifier(service);
});

/// Presets list provider
final presetsProvider = FutureProvider<List<PresetInfo>>((ref) async {
  final service = ref.watch(oneTrainerServiceProvider);
  return service.getPresets();
});

/// Current loaded config provider - loads config when preset name changes
final currentConfigProvider = StateNotifierProvider<CurrentConfigNotifier, CurrentConfig>((ref) {
  final service = ref.watch(oneTrainerServiceProvider);
  return CurrentConfigNotifier(service);
});

/// Current config state
class CurrentConfig {
  final String presetName;
  final Map<String, dynamic>? config;
  final bool isLoading;
  final String? error;

  CurrentConfig({
    this.presetName = '',
    this.config,
    this.isLoading = false,
    this.error,
  });

  CurrentConfig copyWith({
    String? presetName,
    Map<String, dynamic>? config,
    bool? isLoading,
    String? error,
  }) {
    return CurrentConfig(
      presetName: presetName ?? this.presetName,
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  // Helper getters for common config fields
  String get modelType => config?['model_type'] as String? ?? 'Z_IMAGE';
  String get trainingMethod => config?['training_method'] as String? ?? 'LORA';
  String get baseModelName => config?['base_model_name'] as String? ?? '';
  String get workspaceDir => config?['workspace_dir'] as String? ?? '';
  String get cacheDir => config?['cache_dir'] as String? ?? '';
  String get outputDir => config?['output_model_destination'] as String? ?? '';
  int get epochs => config?['epochs'] as int? ?? 100;
  int get batchSize => config?['batch_size'] as int? ?? 1;
  double get learningRate => (config?['learning_rate'] as num?)?.toDouble() ?? 0.0001;
  String get optimizer => config?['optimizer']?['optimizer'] as String? ?? 'ADAMW';
  String get lrScheduler => config?['learning_rate_scheduler'] as String? ?? 'CONSTANT';
  int get warmupSteps => config?['learning_rate_warmup_steps'] as int? ?? 0;
  String get resolution => config?['resolution'] as String? ?? '512';
  bool get trainTransformer => config?['train_unet'] as bool? ?? true;
  bool get trainTextEncoder => config?['train_text_encoder'] as bool? ?? false;
  String get trainDtype => config?['train_dtype'] as String? ?? 'BFLOAT_16';
  String get outputDtype => config?['output_dtype'] as String? ?? 'BFLOAT_16';

  // LoRA settings
  int get loraRank => config?['lora_rank'] as int? ?? 16;
  double get loraAlpha => (config?['lora_alpha'] as num?)?.toDouble() ?? 1.0;
  double get loraDropout => (config?['lora_dropout'] as num?)?.toDouble() ?? 0.0;

  // EMA settings
  String get ema => config?['ema'] as String? ?? 'OFF';
  double get emaDecay => (config?['ema_decay'] as num?)?.toDouble() ?? 0.999;

  // Gradient checkpointing
  String get gradientCheckpointing => config?['gradient_checkpointing'] as String? ?? 'ON';

  // Concepts/datasets
  List<dynamic> get concepts => config?['concepts'] as List<dynamic>? ?? [];

  // Sample settings
  String get samplesDir => config?['samples_dir'] as String? ?? '';
  List<dynamic> get sampleDefinitions => config?['sample_definition_file_name'] != null
    ? [config!['sample_definition_file_name']]
    : (config?['samples'] as List<dynamic>? ?? []);
  int get sampleAfterEpochs => config?['sample_after_epochs'] as int? ?? 1;
  int get sampleEveryNEpochs => config?['sample_every_n_epochs'] as int? ?? 1;

  // Backup settings
  String get backupDir => config?['backup_dir'] as String? ?? '';
  int get backupAfter => config?['backup_after'] as int? ?? 0;
  String get backupAfterUnit => config?['backup_after_unit'] as String? ?? 'NEVER';
}

class CurrentConfigNotifier extends StateNotifier<CurrentConfig> {
  final OneTrainerService _service;

  CurrentConfigNotifier(this._service) : super(CurrentConfig());

  Future<void> loadPreset(String presetName) async {
    if (presetName.isEmpty) return;
    if (state.presetName == presetName && state.config != null) return;

    state = state.copyWith(presetName: presetName, isLoading: true, error: null);

    final config = await _service.loadPreset(presetName);
    if (config != null) {
      state = state.copyWith(config: config, isLoading: false);
    } else {
      state = state.copyWith(isLoading: false, error: 'Failed to load preset');
    }
  }

  void updateConfig(Map<String, dynamic> updates) {
    if (state.config == null) return;
    final newConfig = Map<String, dynamic>.from(state.config!);
    newConfig.addAll(updates);
    state = state.copyWith(config: newConfig);
  }

  void setConfig(Map<String, dynamic> config) {
    state = state.copyWith(config: config);
  }

  void clear() {
    state = CurrentConfig();
  }
}

/// OneTrainer API Service
class OneTrainerService {
  late Dio _dio;
  WebSocketChannel? _wsChannel;
  String _baseUrl = 'http://localhost:8100';
  String _wsUrl = 'ws://localhost:8100/ws';

  final _connectionStateController = StreamController<OneTrainerConnectionState>.broadcast();
  Stream<OneTrainerConnectionState> get connectionState => _connectionStateController.stream;

  final _trainingUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get trainingUpdates => _trainingUpdateController.stream;

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logs => _logController.stream;

  Timer? _pingTimer;
  bool _isConnected = false;

  OneTrainerService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(seconds: 30),
    ));
  }

  /// Configure the service with host and port
  void configure({required String host, required int port}) {
    _baseUrl = 'http://$host:$port';
    _wsUrl = 'ws://$host:$port/ws';
  }

  String get baseUrl => _baseUrl;
  bool get isConnected => _isConnected;

  /// Connect to OneTrainer backend
  Future<bool> connect() async {
    try {
      _connectionStateController.add(OneTrainerConnectionState.connecting);

      // Test HTTP connection
      final response = await _dio.get('$_baseUrl/health');
      if (response.statusCode != 200) {
        _connectionStateController.add(OneTrainerConnectionState.disconnected);
        return false;
      }

      // Connect WebSocket for real-time updates
      await _connectWebSocket();

      _isConnected = true;
      _connectionStateController.add(OneTrainerConnectionState.connected);
      return true;
    } catch (e) {
      print('OneTrainer connection failed: $e');
      _connectionStateController.add(OneTrainerConnectionState.error);
      return false;
    }
  }

  /// Disconnect from OneTrainer
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    await _wsChannel?.sink.close();
    _wsChannel = null;
    _isConnected = false;
    _connectionStateController.add(OneTrainerConnectionState.disconnected);
  }

  Future<void> _connectWebSocket() async {
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      _wsChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            _handleWsMessage(data);
          } catch (e) {
            print('WS parse error: $e');
          }
        },
        onError: (error) {
          print('OneTrainer WS error: $error');
          _isConnected = false;
          _connectionStateController.add(OneTrainerConnectionState.error);
        },
        onDone: () {
          print('OneTrainer WS closed');
          _isConnected = false;
          _connectionStateController.add(OneTrainerConnectionState.disconnected);
        },
      );

      // Start ping timer to keep connection alive
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _wsChannel?.sink.add('ping');
      });
    } catch (e) {
      print('WebSocket connection failed: $e');
      rethrow;
    }
  }

  void _handleWsMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'connected':
      case 'training_state':
      case 'progress':
      case 'sampling':
        _trainingUpdateController.add(data);
        break;
      case 'log':
        // Backend sends message directly in root, not nested under 'data'
        final message = data['message'] as String? ?? data['data']?['message'] as String? ?? '';
        if (message.isNotEmpty) {
          _logController.add(message);
        }
        break;
      case 'sample_default':
      case 'sample_custom':
        _trainingUpdateController.add(data);
        break;
      case 'pong':
        // Heartbeat response
        break;
      default:
        _trainingUpdateController.add(data);
    }
  }

  // ==================== Health & Status ====================

  /// Check health
  Future<Map<String, dynamic>?> getHealth() async {
    try {
      final response = await _dio.get('$_baseUrl/health');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Health check failed: $e');
      return null;
    }
  }

  /// Get training status
  Future<TrainingStatus?> getStatus() async {
    try {
      final response = await _dio.get('$_baseUrl/api/training/status');
      return TrainingStatus.fromJson(response.data);
    } catch (e) {
      print('Get status failed: $e');
      return null;
    }
  }

  /// Get training progress
  Future<Map<String, dynamic>?> getProgress() async {
    try {
      final response = await _dio.get('$_baseUrl/api/training/progress');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Get progress failed: $e');
      return null;
    }
  }

  /// Check training status and emit updates (for manual polling)
  Future<void> checkTrainingStatus() async {
    try {
      final status = await getStatus();
      if (status != null) {
        _trainingUpdateController.add({
          'type': 'training_state',
          'data': {
            'is_training': status.isTraining,
            'status': status.status,
          }
        });
      }

      final progress = await getProgress();
      if (progress != null) {
        _trainingUpdateController.add({
          'type': 'progress',
          'data': progress,
        });
      }
    } catch (e) {
      print('Check training status failed: $e');
    }
  }

  // ==================== Training Control ====================

  /// Start training with config path
  Future<CommandResult> startTraining(String configPath, {String? secretsPath}) async {
    try {
      final response = await _dio.post('$_baseUrl/api/training/start', data: {
        'config_path': configPath,
        if (secretsPath != null) 'secrets_path': secretsPath,
      });
      return CommandResult.fromJson(response.data);
    } catch (e) {
      return CommandResult(success: false, message: 'Start training failed: $e');
    }
  }

  /// Stop training
  Future<CommandResult> stopTraining() async {
    try {
      final response = await _dio.post('$_baseUrl/api/training/stop');
      return CommandResult.fromJson(response.data);
    } catch (e) {
      return CommandResult(success: false, message: 'Stop training failed: $e');
    }
  }

  /// Trigger sample generation
  Future<CommandResult> triggerSample() async {
    try {
      final response = await _dio.post('$_baseUrl/api/training/sample');
      return CommandResult.fromJson(response.data);
    } catch (e) {
      return CommandResult(success: false, message: 'Trigger sample failed: $e');
    }
  }

  /// Trigger backup
  Future<CommandResult> triggerBackup() async {
    try {
      final response = await _dio.post('$_baseUrl/api/training/backup');
      return CommandResult.fromJson(response.data);
    } catch (e) {
      return CommandResult(success: false, message: 'Trigger backup failed: $e');
    }
  }

  /// Trigger save
  Future<CommandResult> triggerSave() async {
    try {
      final response = await _dio.post('$_baseUrl/api/training/save');
      return CommandResult.fromJson(response.data);
    } catch (e) {
      return CommandResult(success: false, message: 'Trigger save failed: $e');
    }
  }

  // ==================== Config Management ====================

  /// Get list of presets
  Future<List<PresetInfo>> getPresets({String? configDir}) async {
    try {
      final response = await _dio.get('$_baseUrl/api/config/presets',
        queryParameters: configDir != null ? {'config_dir': configDir} : null,
      );
      final data = response.data as Map<String, dynamic>;
      final presets = data['presets'] as List<dynamic>;
      return presets.map((p) => PresetInfo.fromJson(p)).toList();
    } catch (e) {
      print('Get presets failed: $e');
      return [];
    }
  }

  /// Load a preset by name
  Future<Map<String, dynamic>?> loadPreset(String name, {String? configDir}) async {
    try {
      // URL encode the preset name (handles #, spaces, etc.)
      final encodedName = Uri.encodeComponent(name);
      final response = await _dio.get('$_baseUrl/api/config/presets/$encodedName',
        queryParameters: configDir != null ? {'config_dir': configDir} : null,
      );
      final data = response.data as Map<String, dynamic>;
      final config = data['config'];
      if (config is Map<String, dynamic>) {
        return config;
      } else if (config is String) {
        // Some responses might return JSON string
        return jsonDecode(config) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Load preset failed: $e');
      return null;
    }
  }

  /// Save a preset
  Future<CommandResult> savePreset(String name, Map<String, dynamic> config, {String? configDir}) async {
    try {
      final response = await _dio.post('$_baseUrl/api/config/presets/$name',
        data: {'config': config},
        queryParameters: configDir != null ? {'config_dir': configDir} : null,
      );
      return CommandResult.fromJson(response.data);
    } catch (e) {
      return CommandResult(success: false, message: 'Save preset failed: $e');
    }
  }

  /// Delete a preset
  Future<CommandResult> deletePreset(String name, {String? configDir}) async {
    try {
      final response = await _dio.delete('$_baseUrl/api/config/presets/$name',
        queryParameters: configDir != null ? {'config_dir': configDir} : null,
      );
      return CommandResult.fromJson(response.data);
    } catch (e) {
      return CommandResult(success: false, message: 'Delete preset failed: $e');
    }
  }

  /// Save config to temp file and return path
  Future<String?> saveTempConfig(Map<String, dynamic> config) async {
    try {
      final response = await _dio.post('$_baseUrl/api/config/save-temp', data: {
        'config': config,
      });
      final data = response.data as Map<String, dynamic>;
      return data['path'] as String?;
    } catch (e) {
      print('Save temp config failed: $e');
      return null;
    }
  }

  /// Validate config
  Future<ConfigValidation> validateConfig(Map<String, dynamic> config) async {
    try {
      final response = await _dio.post('$_baseUrl/api/config/validate', data: {
        'config': config,
      });
      return ConfigValidation.fromJson(response.data);
    } catch (e) {
      return ConfigValidation(valid: false, errors: ['Validation failed: $e'], warnings: []);
    }
  }

  /// Load concepts from file
  Future<List<dynamic>?> loadConceptsFile(String filePath) async {
    try {
      final response = await _dio.get('$_baseUrl/api/config/concepts-file',
        queryParameters: {'file_path': filePath},
      );
      final data = response.data as Map<String, dynamic>;
      return data['concepts'] as List<dynamic>?;
    } catch (e) {
      print('Load concepts file failed: $e');
      return null;
    }
  }

  // ==================== System ====================

  /// Get system info
  Future<Map<String, dynamic>?> getSystemInfo() async {
    try {
      final response = await _dio.get('$_baseUrl/api/system/info');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Get system info failed: $e');
      return null;
    }
  }

  /// Get system resources (GPU, CPU, memory)
  Future<Map<String, dynamic>?> getSystemResources() async {
    try {
      final response = await _dio.get('$_baseUrl/api/system/info');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Get system resources failed: $e');
      return null;
    }
  }

  // ==================== Filesystem ====================

  /// Browse directory
  Future<Map<String, dynamic>?> browseDirectory(String path) async {
    try {
      final response = await _dio.get('$_baseUrl/api/filesystem/browse',
        queryParameters: {'path': path},
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Browse directory failed: $e');
      return null;
    }
  }

  // ==================== Tensorboard ====================

  /// Start tensorboard
  Future<CommandResult> startTensorboard(String logDir, {int port = 6006}) async {
    try {
      final response = await _dio.post('$_baseUrl/api/tensorboard/start', data: {
        'log_dir': logDir,
        'port': port,
      });
      return CommandResult.fromJson(response.data);
    } catch (e) {
      return CommandResult(success: false, message: 'Start tensorboard failed: $e');
    }
  }

  /// Stop tensorboard
  Future<CommandResult> stopTensorboard() async {
    try {
      final response = await _dio.post('$_baseUrl/api/tensorboard/stop');
      return CommandResult.fromJson(response.data);
    } catch (e) {
      return CommandResult(success: false, message: 'Stop tensorboard failed: $e');
    }
  }

  /// Get tensorboard status
  Future<Map<String, dynamic>?> getTensorboardStatus() async {
    try {
      final response = await _dio.get('$_baseUrl/api/tensorboard/status');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Get tensorboard status failed: $e');
      return null;
    }
  }

  void dispose() {
    _pingTimer?.cancel();
    _wsChannel?.sink.close();
    _connectionStateController.close();
    _trainingUpdateController.close();
    _logController.close();
  }
}

// ==================== Data Models ====================

enum OneTrainerConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class TrainingStatus {
  final bool isTraining;
  final String status;
  final String? error;

  TrainingStatus({
    required this.isTraining,
    required this.status,
    this.error,
  });

  factory TrainingStatus.fromJson(Map<String, dynamic> json) {
    return TrainingStatus(
      isTraining: json['is_training'] as bool? ?? false,
      status: json['status'] as String? ?? 'unknown',
      error: json['error'] as String?,
    );
  }
}

class TrainingProgress {
  final int currentEpoch;
  final int totalEpochs;
  final int currentStep;
  final int totalSteps;
  final int epochStep;
  final int epochLength;
  final double? loss;
  final double? smoothLoss;
  final String? elapsedTime;
  final String? remainingTime;
  final double? samplesPerSecond;

  TrainingProgress({
    required this.currentEpoch,
    required this.totalEpochs,
    required this.currentStep,
    required this.totalSteps,
    required this.epochStep,
    required this.epochLength,
    this.loss,
    this.smoothLoss,
    this.elapsedTime,
    this.remainingTime,
    this.samplesPerSecond,
  });

  factory TrainingProgress.fromJson(Map<String, dynamic> json) {
    // Handle both backend formats (WebSocket uses different field names)
    return TrainingProgress(
      currentEpoch: json['epoch'] as int? ?? json['current_epoch'] as int? ?? 0,
      totalEpochs: json['max_epoch'] as int? ?? json['total_epochs'] as int? ?? 0,
      currentStep: json['global_step'] as int? ?? json['step'] as int? ?? json['current_step'] as int? ?? 0,
      totalSteps: json['max_step'] as int? ?? json['total_steps'] as int? ?? 0,
      epochStep: json['epoch_step'] as int? ?? 0,
      epochLength: json['epoch_length'] as int? ?? 0,
      loss: (json['loss'] as num?)?.toDouble(),
      smoothLoss: (json['smooth_loss'] as num?)?.toDouble(),
      elapsedTime: json['elapsed_time'] as String?,
      remainingTime: _formatEta(json['eta_seconds']),
      samplesPerSecond: (json['samples_per_second'] as num?)?.toDouble(),
    );
  }

  static String? _formatEta(dynamic etaSeconds) {
    if (etaSeconds == null) return null;
    final seconds = (etaSeconds as num).toInt();
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

class CommandResult {
  final bool success;
  final String message;

  CommandResult({required this.success, required this.message});

  factory CommandResult.fromJson(Map<String, dynamic> json) {
    return CommandResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}

class PresetInfo {
  final String name;
  final String path;
  final String? description;
  final DateTime? lastModified;

  PresetInfo({
    required this.name,
    required this.path,
    this.description,
    this.lastModified,
  });

  factory PresetInfo.fromJson(Map<String, dynamic> json) {
    return PresetInfo(
      name: json['name'] as String,
      path: json['path'] as String,
      description: json['description'] as String?,
      lastModified: json['last_modified'] != null
        ? DateTime.tryParse(json['last_modified'] as String)
        : null,
    );
  }
}

class ConfigValidation {
  final bool valid;
  final List<String> errors;
  final List<String> warnings;

  ConfigValidation({
    required this.valid,
    required this.errors,
    required this.warnings,
  });

  factory ConfigValidation.fromJson(Map<String, dynamic> json) {
    return ConfigValidation(
      valid: json['valid'] as bool? ?? false,
      errors: (json['errors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      warnings: (json['warnings'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

// ==================== State Notifier ====================

class TrainingState {
  final bool isTraining;
  final String status;
  final String? error;
  final TrainingProgress? progress;
  final List<String> logs;
  final bool isSampling;

  TrainingState({
    this.isTraining = false,
    this.status = 'idle',
    this.error,
    this.progress,
    this.logs = const [],
    this.isSampling = false,
  });

  TrainingState copyWith({
    bool? isTraining,
    String? status,
    String? error,
    TrainingProgress? progress,
    List<String>? logs,
    bool? isSampling,
  }) {
    return TrainingState(
      isTraining: isTraining ?? this.isTraining,
      status: status ?? this.status,
      error: error,
      progress: progress ?? this.progress,
      logs: logs ?? this.logs,
      isSampling: isSampling ?? this.isSampling,
    );
  }
}

class TrainingStateNotifier extends StateNotifier<TrainingState> {
  final OneTrainerService _service;
  StreamSubscription? _updateSub;
  StreamSubscription? _logSub;

  TrainingStateNotifier(this._service) : super(TrainingState()) {
    _updateSub = _service.trainingUpdates.listen(_handleUpdate);
    _logSub = _service.logs.listen(_handleLog);
  }

  void _handleUpdate(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    // Backend sends fields directly in root OR nested under 'data'
    final updateData = data['data'] as Map<String, dynamic>? ?? data;

    switch (type) {
      case 'connected':
      case 'training_state':
      case 'training_status':
        state = state.copyWith(
          isTraining: updateData['is_training'] as bool? ?? updateData['status'] == 'training',
          status: updateData['status'] as String?,
          error: updateData['error'] as String?,
        );
        break;
      case 'progress':
      case 'training_progress':
        state = state.copyWith(
          progress: TrainingProgress.fromJson(updateData),
          // Don't set isTraining here - let training_status handle that
        );
        break;
      case 'sampling':
        final current = updateData['current'] as int? ?? 0;
        final total = updateData['total'] as int? ?? 0;
        state = state.copyWith(isSampling: current < total);
        break;
      case 'sample_default':
      case 'sample_custom':
      case 'sample_generated':
        state = state.copyWith(isSampling: false);
        break;
    }
  }

  void _handleLog(String log) {
    if (log.isEmpty) return;
    final newLogs = [...state.logs, log];
    // Keep only last 1000 logs
    if (newLogs.length > 1000) {
      newLogs.removeRange(0, newLogs.length - 1000);
    }
    state = state.copyWith(logs: newLogs);
  }

  void clearLogs() {
    state = state.copyWith(logs: []);
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    _logSub?.cancel();
    super.dispose();
  }
}
