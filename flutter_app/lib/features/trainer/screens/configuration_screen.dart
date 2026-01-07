import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trainer_state_provider.dart';
import '../../../services/onetrainer_service.dart' as ot;

/// Configuration Screen - General, Model, Data, Backup tabs
/// Matches OneTrainer desktop app exactly
class ConfigurationScreen extends ConsumerStatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  ConsumerState<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends ConsumerState<ConfigurationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // General settings
  String _workspaceDir = '/home/alex/1_giger';
  bool _continueFromBackup = true;
  bool _debugMode = false;
  bool _tensorboard = true;
  bool _exposeTensorboard = false;
  bool _validation = true;
  int _dataloaderThreads = 1;
  String _trainDevice = 'cuda';
  bool _multiGpu = false;
  String _gradientPrecision = 'FLOAT_32_STOCHASTIC';
  bool _asyncGradientReduce = true;
  String _tempDevice = 'cpu';
  bool _enableWandB = false;
  String _wandbProject = '';
  String _wandbEntity = '';
  String _wandbRunName = '';
  String _wandbTags = '';
  String _wandbBaseUrl = '';
  String _deviceIndexes = '';
  bool _fusedGradientReduce = false;
  int _asyncGradientReduceBuffer = 100;
  String _cacheDir = '/home/alex/1_giger/cache';
  String _samplesDir = '/home/alex/1_giger/samples';
  bool _onlyCache = false;
  String _debugDir = '/home/alex/1_giger/debug';
  bool _alwaysOnTensorboard = false;
  int _tensorboardPort = 6006;
  int _validateAfter = 500;
  String _validateUnit = 'EPOCH';

  // Model settings - synced from preset
  String _modelType = 'Z_IMAGE';
  String _trainingMethod = 'LORA';
  bool _modelTypeSynced = false;
  String _lastSyncedPreset = '';
  String _hfToken = '';
  String _baseModel = 'Tongyi-MAI/Z-Image-Turbo';
  bool _compileTransformer = false;
  String _overrideTransformer = '';
  String _vaeOverride = '';
  String _quantLayerFilter = '';
  String _svdQuant = 'disabled';
  int _svdQuantRank = 64;
  String _transformerDataType = 'bfloat16';
  String _textEncoderDataType = 'bfloat16';
  String _textEncoder2DataType = 'bfloat16';
  String _textEncoder3DataType = 'bfloat16';
  String _vaeDataType = 'bfloat16';
  String _outputDestination = '/home/alex/1_giger/model';
  String _outputDataType = 'bfloat16';
  String _outputFormat = 'SAFETENSORS';
  String _includeConfig = 'SETTINGS';

  // Data settings
  int _resolution = 512;
  int _batchSize = 2;
  int _gradientAccumulation = 1;
  int _dataThreads = 1;
  bool _latentCaching = true;

  // Backup settings
  String _backupDir = '/home/alex/1_giger/backup';
  int _backupEveryNSteps = 500;
  int _keepNBackups = 3;
  bool _saveCheckpoints = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Setup workspace - creates subdirectories and populates path fields
  Future<void> _setupWorkspace() async {
    if (_workspaceDir.trim().isEmpty) return;

    final subdirs = ['cache', 'debug', 'model', 'backup', 'samples'];

    for (final subdir in subdirs) {
      try {
        final dir = Directory('$_workspaceDir/$subdir');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } catch (e) {
        debugPrint('Failed to create $subdir dir: $e');
      }
    }

    // Auto-populate all directory fields
    setState(() {
      _cacheDir = '$_workspaceDir/cache';
      _debugDir = '$_workspaceDir/debug';
      _outputDestination = '$_workspaceDir/model';
      _backupDir = '$_workspaceDir/backup';
      _samplesDir = '$_workspaceDir/samples';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created workspace directories in $_workspaceDir'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Check if model type has transformer (vs UNet)
  bool get _hasTransformer => [
    'STABLE_DIFFUSION_3', 'STABLE_DIFFUSION_35', 'PIXART_ALPHA', 'PIXART_SIGMA',
    'FLUX_DEV_1', 'FLUX_FILL_DEV_1', 'SANA', 'HUNYUAN_VIDEO', 'HI_DREAM_FULL',
    'CHROMA_1', 'QWEN', 'QWEN_IMAGE_EDIT', 'Z_IMAGE', 'WAN_2_1',
  ].contains(_modelType);

  /// Check if model type has multiple text encoders
  bool get _hasMultipleTextEncoders => [
    'STABLE_DIFFUSION_3', 'STABLE_DIFFUSION_35', 'STABLE_DIFFUSION_XL_10_BASE',
    'STABLE_DIFFUSION_XL_10_BASE_INPAINTING', 'FLUX_DEV_1', 'FLUX_FILL_DEV_1',
    'HUNYUAN_VIDEO', 'HI_DREAM_FULL',
  ].contains(_modelType);

  /// Check if model type has three text encoders
  bool get _hasThreeTextEncoders => [
    'STABLE_DIFFUSION_3', 'STABLE_DIFFUSION_35', 'HI_DREAM_FULL',
  ].contains(_modelType);

  /// Map human-readable model type to enum value
  String _mapModelTypeToEnum(String humanType) {
    const mapping = {
      'Chroma': 'CHROMA_1',
      'Z-Image': 'Z_IMAGE',
      'Flux': 'FLUX_DEV_1',
      'SDXL': 'STABLE_DIFFUSION_XL_10_BASE',
      'SD3': 'STABLE_DIFFUSION_3',
      'SD': 'STABLE_DIFFUSION_15',
      'PixArt': 'PIXART_SIGMA',
      'Hunyuan': 'HUNYUAN_VIDEO',
      'HiDream': 'HI_DREAM_FULL',
      'Wan': 'WAN_2_1',
      'Qwen': 'QWEN',
      'Qwen-Edit': 'QWEN_IMAGE_EDIT',
      'Kandinsky': 'KANDINSKY_5',
    };
    return mapping[humanType] ?? 'Z_IMAGE';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    // Watch the loaded config and sync fields
    final currentConfig = ref.watch(ot.currentConfigProvider);
    final config = currentConfig.config;

    // Sync all fields from loaded config when it changes
    if (config != null && config.isNotEmpty && !_modelTypeSynced) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // General settings
            if (config['workspace_dir'] != null) _workspaceDir = config['workspace_dir'] as String;
            if (config['cache_dir'] != null) _cacheDir = config['cache_dir'] as String;
            if (config['debug_dir'] != null) _debugDir = config['debug_dir'] as String;
            if (config['samples_dir'] != null) _samplesDir = config['samples_dir'] as String;
            if (config['output_model_destination'] != null) _outputDestination = config['output_model_destination'] as String;
            if (config['backup_dir'] != null) _backupDir = config['backup_dir'] as String;
            if (config['dataloader_threads'] != null) _dataloaderThreads = config['dataloader_threads'] as int;
            if (config['train_device'] != null) _trainDevice = config['train_device'] as String;
            if (config['temp_device'] != null) _tempDevice = config['temp_device'] as String;
            if (config['tensorboard'] != null) _tensorboard = config['tensorboard'] as bool;
            if (config['only_cache'] != null) _onlyCache = config['only_cache'] as bool;

            // Model settings
            if (config['model_type'] != null) _modelType = config['model_type'] as String;
            if (config['training_method'] != null) _trainingMethod = config['training_method'] as String;
            if (config['base_model_name'] != null) _baseModel = config['base_model_name'] as String;
            if (config['output_dtype'] != null) _outputDataType = config['output_dtype'] as String;
            if (config['compile'] != null) _compileTransformer = config['compile'] as bool;

            // Data settings
            if (config['resolution'] != null) _resolution = int.tryParse(config['resolution'].toString()) ?? 512;
            if (config['batch_size'] != null) _batchSize = config['batch_size'] as int;
            if (config['gradient_accumulation_steps'] != null) _gradientAccumulation = config['gradient_accumulation_steps'] as int;
            if (config['latent_caching'] != null) _latentCaching = config['latent_caching'] as bool;

            // Backup settings
            if (config['backup_after'] != null) _backupEveryNSteps = config['backup_after'] as int;
            if (config['rolling_backup_count'] != null) _keepNBackups = config['rolling_backup_count'] as int;

            _modelTypeSynced = true;
          });
        }
      });
    }

    // Reset sync flag when preset name changes
    if (currentConfig.presetName.isNotEmpty) {
      final configPreset = currentConfig.presetName;
      if (configPreset != _lastSyncedPreset) {
        _modelTypeSynced = false;
        _lastSyncedPreset = configPreset;
      }
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and tabs
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuration',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
                  indicatorColor: colorScheme.primary,
                  tabs: const [
                    Tab(child: Row(children: [Icon(Icons.settings, size: 18), SizedBox(width: 8), Text('General')])),
                    Tab(child: Row(children: [Icon(Icons.model_training, size: 18), SizedBox(width: 8), Text('Model')])),
                    Tab(child: Row(children: [Icon(Icons.data_usage, size: 18), SizedBox(width: 8), Text('Data')])),
                    Tab(child: Row(children: [Icon(Icons.backup, size: 18), SizedBox(width: 8), Text('Backup')])),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralTab(colorScheme),
                _buildModelTab(colorScheme),
                _buildDataTab(colorScheme),
                _buildBackupTab(colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                _buildSection('GENERAL SETTINGS', [
                  _buildWorkspaceField('Workspace Directory', _workspaceDir, (v) => setState(() => _workspaceDir = v), colorScheme),
                  _buildToggleWithDesc('Continue from last backup', null, _continueFromBackup, (v) => setState(() => _continueFromBackup = v), colorScheme),
                  _buildToggleWithDesc('Debug mode', null, _debugMode, (v) => setState(() => _debugMode = v), colorScheme),
                  _buildToggleWithDesc('Tensorboard', null, _tensorboard, (v) => setState(() => _tensorboard = v), colorScheme),
                  _buildToggleWithDesc('Expose Tensorboard', null, _exposeTensorboard, (v) => setState(() => _exposeTensorboard = v), colorScheme),
                  _buildToggleWithDesc('Validation', 'Enable by setting steps', _validation, (v) => setState(() => _validation = v), colorScheme),
                  _buildNumberFieldWithDesc('Dataloader Threads', null, _dataloaderThreads, (v) => setState(() => _dataloaderThreads = v), colorScheme),
                  _buildDropdown('Train Device', _trainDevice, ['cuda', 'cpu', 'mps'], (v) => setState(() => _trainDevice = v), colorScheme),
                  _buildToggleWithDesc('Multi-GPU', null, _multiGpu, (v) => setState(() => _multiGpu = v), colorScheme),
                  _buildDropdown('Gradient Reduce Precision', _gradientPrecision, ['FLOAT_32_STOCHASTIC', 'FLOAT_16', 'BFLOAT_16'], (v) => setState(() => _gradientPrecision = v), colorScheme),
                  _buildToggleWithDesc('Async Gradient Reduce', null, _asyncGradientReduce, (v) => setState(() => _asyncGradientReduce = v), colorScheme),
                  _buildDropdown('Temp Device', _tempDevice, ['cpu', 'cuda'], (v) => setState(() => _tempDevice = v), colorScheme),
                ], colorScheme),
                const SizedBox(height: 24),
                _buildSection('WEIGHTS & BIASES', [
                  _buildToggleWithDesc('Enable WandB', null, _enableWandB, (v) => setState(() => _enableWandB = v), colorScheme),
                  if (_enableWandB) ...[
                    _buildTextFieldWithDesc('Project Name', 'onetrainer', _wandbProject, (v) => setState(() => _wandbProject = v), colorScheme),
                    _buildTextFieldWithDesc('Entity (optional)', 'Your username or team', _wandbEntity, (v) => setState(() => _wandbEntity = v), colorScheme),
                    _buildTextFieldWithDesc('Run Name (optional)', 'Auto-generated if empty', _wandbRunName, (v) => setState(() => _wandbRunName = v), colorScheme),
                    _buildTextFieldWithDesc('Tags (comma-separated)', 'flux,lora,experiment', _wandbTags, (v) => setState(() => _wandbTags = v), colorScheme),
                    _buildTextFieldWithDesc('Server URL (self-hosted)', 'http://localhost:8080 (leave empty for wandb.ai)', _wandbBaseUrl, (v) => setState(() => _wandbBaseUrl = v), colorScheme),
                  ],
                ], colorScheme),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                _buildSection('', [
                  _buildPathField('Cache Directory', _cacheDir, (v) => setState(() => _cacheDir = v), colorScheme),
                  _buildPathField('Samples Directory', _samplesDir, (v) => setState(() => _samplesDir = v), colorScheme),
                  _buildToggleWithDesc('Only Cache', null, _onlyCache, (v) => setState(() => _onlyCache = v), colorScheme),
                  _buildPathField('Debug Directory', _debugDir, (v) => setState(() => _debugDir = v), colorScheme),
                  _buildToggleWithDesc('Always-On Tensorboard', null, _alwaysOnTensorboard, (v) => setState(() => _alwaysOnTensorboard = v), colorScheme),
                  _buildNumberFieldWithDesc('Tensorboard Port', null, _tensorboardPort, (v) => setState(() => _tensorboardPort = v), colorScheme),
                ], colorScheme),
                const SizedBox(height: 24),
                _buildSection('VALIDATION & GPU', [
                  _buildNumberWithDropdown('Validate after', _validateAfter, _validateUnit, (v) => setState(() => _validateAfter = v), (v) => setState(() => _validateUnit = v), colorScheme),
                  _buildTextFieldWithDesc('Device Indexes', '0,1...', _deviceIndexes, (v) => setState(() => _deviceIndexes = v), colorScheme),
                  _buildToggleWithDesc('Fused Gradient Reduce', null, _fusedGradientReduce, (v) => setState(() => _fusedGradientReduce = v), colorScheme),
                  _buildNumberFieldWithDesc('Buffer size (MB)', null, _asyncGradientReduceBuffer, (v) => setState(() => _asyncGradientReduceBuffer = v), colorScheme),
                ], colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                _buildSection('BASE MODEL', [
                  _buildDropdown('Model Type', _modelType, [
                    'STABLE_DIFFUSION_15', 'STABLE_DIFFUSION_XL_10_BASE', 'STABLE_DIFFUSION_3', 'STABLE_DIFFUSION_35',
                    'FLUX_DEV_1', 'FLUX_FILL_DEV_1', 'PIXART_ALPHA', 'PIXART_SIGMA', 'SANA',
                    'HUNYUAN_VIDEO', 'HI_DREAM_FULL', 'CHROMA_1', 'QWEN', 'QWEN_IMAGE_EDIT',
                    'KANDINSKY_5', 'KANDINSKY_5_VIDEO', 'Z_IMAGE', 'WAN_2_1',
                  ], (v) => setState(() => _modelType = v), colorScheme),
                  _buildDropdown('Training Method', _trainingMethod, ['LORA', 'FINE_TUNE', 'EMBEDDING'], (v) => setState(() => _trainingMethod = v), colorScheme),
                  _buildTextFieldWithDesc('Hugging Face Token', 'Optional: for protected repos', _hfToken, (v) => setState(() => _hfToken = v), colorScheme),
                  _buildTextFieldWithDesc('Base Model', null, _baseModel, (v) => setState(() => _baseModel = v), colorScheme),
                  _buildToggleWithDesc('Compile Transformer Blocks', null, _compileTransformer, (v) => setState(() => _compileTransformer = v), colorScheme),
                ], colorScheme),
                const SizedBox(height: 24),
                _buildSection('MODEL OVERRIDES', [
                  _buildTextFieldWithDesc('Override Transformer / GGUF', 'Optional', _overrideTransformer, (v) => setState(() => _overrideTransformer = v), colorScheme),
                  _buildTextFieldWithDesc('VAE Override', 'Optional', _vaeOverride, (v) => setState(() => _vaeOverride = v), colorScheme),
                ], colorScheme),
                const SizedBox(height: 24),
                _buildSection('QUANTIZATION', [
                  _buildTextFieldWithDesc('Quantization Layer Filter', 'Comma-separated layers', _quantLayerFilter, (v) => setState(() => _quantLayerFilter = v), colorScheme),
                  Row(
                    children: [
                      Expanded(child: _buildDropdown('SVDQuant', _svdQuant, ['disabled', 'enabled'], (v) => setState(() => _svdQuant = v), colorScheme)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildNumberFieldWithDesc('SVDQuant Rank', null, _svdQuantRank, (v) => setState(() => _svdQuantRank = v), colorScheme)),
                    ],
                  ),
                ], colorScheme),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                _buildSection('COMPONENT DATA TYPES', [
                  _buildDropdown(_hasTransformer ? 'Transformer Data Type' : 'UNet Data Type', _transformerDataType, ['float16', 'bfloat16', 'float32', 'float8', 'nfloat4'], (v) => setState(() => _transformerDataType = v), colorScheme),
                  _buildDropdown(_hasMultipleTextEncoders ? 'Text Encoder 1 Data Type' : 'Text Encoder Data Type', _textEncoderDataType, ['float16', 'bfloat16', 'float32'], (v) => setState(() => _textEncoderDataType = v), colorScheme),
                  if (_hasMultipleTextEncoders)
                    _buildDropdown('Text Encoder 2 Data Type', _textEncoder2DataType, ['float16', 'bfloat16', 'float32'], (v) => setState(() => _textEncoder2DataType = v), colorScheme),
                  if (_hasThreeTextEncoders)
                    _buildDropdown('Text Encoder 3 Data Type', _textEncoder3DataType, ['float16', 'bfloat16', 'float32'], (v) => setState(() => _textEncoder3DataType = v), colorScheme),
                  _buildDropdown('VAE Data Type', _vaeDataType, ['float16', 'bfloat16', 'float32'], (v) => setState(() => _vaeDataType = v), colorScheme),
                ], colorScheme),
                const SizedBox(height: 24),
                _buildSection('OUTPUT', [
                  _buildTextFieldWithDesc('Model Output Destination', null, _outputDestination, (v) => setState(() => _outputDestination = v), colorScheme),
                  Row(
                    children: [
                      Expanded(child: _buildDropdown('Output Data Type', _outputDataType, ['float16', 'bfloat16', 'float32'], (v) => setState(() => _outputDataType = v), colorScheme)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDropdown('Output Format', _outputFormat, ['SAFETENSORS', 'CKPT', 'DIFFUSERS'], (v) => setState(() => _outputFormat = v), colorScheme)),
                    ],
                  ),
                  _buildDropdown('Include Config', _includeConfig, ['SETTINGS', 'NONE', 'FULL'], (v) => setState(() => _includeConfig = v), colorScheme),
                ], colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection('DATASET SETTINGS', [
            _buildNumberFieldWithDesc('Resolution', 'Image resolution for training (typically 512, 768, or 1024)', _resolution, (v) => setState(() => _resolution = v), colorScheme),
            _buildNumberFieldWithDesc('Batch Size', 'Number of samples per training batch', _batchSize, (v) => setState(() => _batchSize = v), colorScheme),
            _buildNumberFieldWithDesc('Gradient Accumulation Steps', 'Number of steps to accumulate gradients before updating weights', _gradientAccumulation, (v) => setState(() => _gradientAccumulation = v), colorScheme),
            _buildNumberFieldWithDesc('Dataloader Threads', 'Number of worker threads for data loading', _dataThreads, (v) => setState(() => _dataThreads = v), colorScheme),
          ], colorScheme),
          const SizedBox(height: 24),
          _buildSection('PERFORMANCE OPTIONS', [
            _buildToggleWithDesc('Latent Caching', 'Cache VAE-encoded latents to speed up training', _latentCaching, (v) => setState(() => _latentCaching = v), colorScheme),
          ], colorScheme),
        ],
      ),
    );
  }

  Widget _buildBackupTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection('BACKUP SETTINGS', [
            _buildPathFieldWithDesc('Backup Directory', 'Directory where backups will be stored', _backupDir, (v) => setState(() => _backupDir = v), colorScheme),
            _buildNumberFieldWithDesc('Backup Every N Steps', 'Create a backup every N training steps', _backupEveryNSteps, (v) => setState(() => _backupEveryNSteps = v), colorScheme),
            _buildNumberFieldWithDesc('Keep N Backups', 'Maximum number of backups to retain (older backups will be deleted)', _keepNBackups, (v) => setState(() => _keepNBackups = v), colorScheme),
            _buildToggleWithDesc('Save Checkpoints', 'Include model checkpoints in backups', _saveCheckpoints, (v) => setState(() => _saveCheckpoints = v), colorScheme),
          ], colorScheme),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(title, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
            const SizedBox(height: 20),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _buildToggleWithDesc(String label, String? desc, bool value, Function(bool) onChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: colorScheme.onSurface, fontSize: 14)),
                if (desc != null) Text(desc, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: Colors.green),
        ],
      ),
    );
  }

  Widget _buildTextFieldWithDesc(String label, String? desc, String value, Function(String) onChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: value),
            style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
            decoration: InputDecoration(
              hintText: desc,
              hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 13),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPathField(String label, String value, Function(String) onChanged, ColorScheme colorScheme) {
    return _buildPathFieldWithDesc(label, null, value, onChanged, colorScheme);
  }

  /// Special workspace directory field with '+' button to create subdirs
  Widget _buildWorkspaceField(String label, String value, Function(String) onChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: value),
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 8),
              // '+' button to create workspace subdirs
              Tooltip(
                message: 'Create cache, debug, model, backup, samples subdirectories',
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.create_new_folder, color: Colors.white),
                    onPressed: _setupWorkspace,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPathFieldWithDesc(String label, String? desc, String value, Function(String) onChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: value),
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}, color: colorScheme.onSurface.withOpacity(0.6)),
              ),
            ],
          ),
          if (desc != null) ...[
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildNumberFieldWithDesc(String label, String? desc, int value, Function(int) onChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: value.toString()),
            keyboardType: TextInputType.number,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (v) => onChanged(int.tryParse(v) ?? value),
          ),
          if (desc != null) ...[
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, Function(String) onChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: options.contains(value) ? value : options.first,
                isExpanded: true,
                dropdownColor: colorScheme.surface,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                onChanged: (v) => onChanged(v!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberWithDropdown(String label, int value, String unit, Function(int) onValueChanged, Function(String) onUnitChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: TextEditingController(text: value.toString()),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (v) => onValueChanged(int.tryParse(v) ?? value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: unit,
                      dropdownColor: colorScheme.surface,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                      items: ['EPOCH', 'STEP', 'SECOND'].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                      onChanged: (v) => onUnitChanged(v!),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
