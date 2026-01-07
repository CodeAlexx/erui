import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/onetrainer_service.dart' hide PresetInfo;
import 'screens/training_queue_screen.dart';
import 'screens/datasets_screen.dart';
import 'screens/configuration_screen.dart';
import 'screens/concepts_screen.dart';
import 'screens/training_screen.dart';
import 'screens/sampling_screen.dart';
import 'screens/backup_screen.dart';
import 'screens/tensorboard_screen.dart';
import 'screens/tools_screen.dart';
import 'screens/dashboard_screen.dart';
import 'trainer_screen.dart';
import 'widgets/video_editor.dart';
import 'widgets/vid_prep.dart';
import 'widgets/preset_card_selector.dart';
import 'providers/trainer_state_provider.dart';
import '../../services/onetrainer_service.dart' as ot show OneTrainerService, OneTrainerConnectionState, TrainingState, TrainingProgress, oneTrainerServiceProvider, trainingStateProvider, currentConfigProvider, CurrentConfig;

/// OneTrainer Shell - Main navigation shell with sidebar
/// Connected to OneTrainer FastAPI backend
class OneTrainerShell extends ConsumerStatefulWidget {
  const OneTrainerShell({super.key});

  @override
  ConsumerState<OneTrainerShell> createState() => _OneTrainerShellState();
}

class _NavItem {
  final IconData icon;
  final String label;
  final Widget? screen;

  _NavItem(this.icon, this.label, [this.screen]);
}

class _OneTrainerShellState extends ConsumerState<OneTrainerShell> {
  int _selectedIndex = 0;
  String _currentPreset = '';
  String _modelType = 'Z_IMAGE';
  String _trainingMethod = 'LORA';
  List<PresetInfo> _presets = [];
  bool _isLoading = true;

  late final List<_NavItem> _navItems;

  // Model types from OneTrainer
  static const _modelTypes = [
    {'label': 'SD1.5', 'value': 'STABLE_DIFFUSION_15'},
    {'label': 'SD1.5 Inpaint', 'value': 'STABLE_DIFFUSION_15_INPAINTING'},
    {'label': 'SD2.0', 'value': 'STABLE_DIFFUSION_20'},
    {'label': 'SD2.1', 'value': 'STABLE_DIFFUSION_21'},
    {'label': 'SD3', 'value': 'STABLE_DIFFUSION_3'},
    {'label': 'SD3.5', 'value': 'STABLE_DIFFUSION_35'},
    {'label': 'SDXL', 'value': 'STABLE_DIFFUSION_XL_10_BASE'},
    {'label': 'SDXL Inpaint', 'value': 'STABLE_DIFFUSION_XL_10_BASE_INPAINTING'},
    {'label': 'PixArt Alpha', 'value': 'PIXART_ALPHA'},
    {'label': 'PixArt Sigma', 'value': 'PIXART_SIGMA'},
    {'label': 'Flux Dev', 'value': 'FLUX_DEV_1'},
    {'label': 'Flux Fill', 'value': 'FLUX_FILL_DEV_1'},
    {'label': 'Sana', 'value': 'SANA'},
    {'label': 'Hunyuan Video', 'value': 'HUNYUAN_VIDEO'},
    {'label': 'HiDream', 'value': 'HI_DREAM_FULL'},
    {'label': 'Chroma', 'value': 'CHROMA_1'},
    {'label': 'QwenImage', 'value': 'QWEN'},
    {'label': 'Qwen-Edit', 'value': 'QWEN_IMAGE_EDIT'},
    {'label': 'Kandinsky 5', 'value': 'KANDINSKY_5'},
    {'label': 'Kandinsky 5 Video', 'value': 'KANDINSKY_5_VIDEO'},
    {'label': 'Z-Image', 'value': 'Z_IMAGE'},
    {'label': 'Wan 2.1', 'value': 'WAN_2_1'},
  ];

  List<Map<String, String>> _getTrainingMethods(String modelType) {
    const sd15Types = ['STABLE_DIFFUSION_15', 'STABLE_DIFFUSION_15_INPAINTING', 'STABLE_DIFFUSION_20', 'STABLE_DIFFUSION_20_INPAINTING', 'STABLE_DIFFUSION_21'];
    const noVaeTypes = ['STABLE_DIFFUSION_3', 'STABLE_DIFFUSION_35', 'STABLE_DIFFUSION_XL_10_BASE', 'STABLE_DIFFUSION_XL_10_BASE_INPAINTING', 'WUERSTCHEN_2', 'STABLE_CASCADE_1', 'PIXART_ALPHA', 'PIXART_SIGMA', 'FLUX_DEV_1', 'FLUX_FILL_DEV_1', 'SANA', 'HUNYUAN_VIDEO', 'HI_DREAM_FULL', 'CHROMA_1'];
    const noEmbeddingTypes = ['QWEN', 'QWEN_IMAGE_EDIT', 'KANDINSKY_5', 'KANDINSKY_5_VIDEO', 'Z_IMAGE', 'WAN_2_1'];

    if (sd15Types.contains(modelType)) {
      return [
        {'label': 'Fine Tune', 'value': 'FINE_TUNE'},
        {'label': 'LoRA', 'value': 'LORA'},
        {'label': 'Embedding', 'value': 'EMBEDDING'},
        {'label': 'Fine Tune VAE', 'value': 'FINE_TUNE_VAE'},
      ];
    } else if (noVaeTypes.contains(modelType)) {
      return [
        {'label': 'Fine Tune', 'value': 'FINE_TUNE'},
        {'label': 'LoRA', 'value': 'LORA'},
        {'label': 'Embedding', 'value': 'EMBEDDING'},
      ];
    } else if (noEmbeddingTypes.contains(modelType)) {
      return [
        {'label': 'Fine Tune', 'value': 'FINE_TUNE'},
        {'label': 'LoRA', 'value': 'LORA'},
      ];
    }
    return [
      {'label': 'Fine Tune', 'value': 'FINE_TUNE'},
      {'label': 'LoRA', 'value': 'LORA'},
    ];
  }

  @override
  void initState() {
    super.initState();
    _navItems = [
      _NavItem(Icons.dashboard, 'Dashboard', const DashboardScreen()),
      _NavItem(Icons.queue, 'Training Queue', const TrainingQueueScreen()),
      _NavItem(Icons.folder_open, 'Datasets', const DatasetsScreen()),
      _NavItem(Icons.tune, 'Configuration', const ConfigurationScreen()),
      _NavItem(Icons.lightbulb_outline, 'Concepts', const ConceptsScreen()),
      _NavItem(Icons.model_training, 'Training', const TrainingScreen()),
      _NavItem(Icons.image, 'Sampling', const SamplingScreen()),
      _NavItem(Icons.backup, 'Backup', const BackupScreen()),
      _NavItem(Icons.insights, 'TensorBoard', const TensorBoardScreen()),
      _NavItem(Icons.build, 'Tools', const ToolsScreen()),
      _NavItem(Icons.text_fields, 'Embeddings', _buildPlaceholder('Embeddings')),
      _NavItem(Icons.cloud_outlined, 'Cloud', _buildPlaceholder('Cloud')),
      _NavItem(Icons.storage, 'Database', _buildPlaceholder('Database')),
      _NavItem(Icons.view_in_ar, 'Models', _buildPlaceholder('Models')),
      _NavItem(Icons.settings, 'Settings', _buildPlaceholder('Settings')),
    ];
    _connectAndLoadPresets();
  }

  Future<void> _connectAndLoadPresets() async {
    final service = ref.read(ot.oneTrainerServiceProvider);

    // Connect to OneTrainer backend
    final connected = await service.connect();
    if (!connected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to OneTrainer backend. Make sure it\'s running on port 8100.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Load presets
    final presets = await service.getPresets();
    if (mounted) {
      setState(() {
        _presets = presets.map((p) => PresetInfo(name: p.name, path: p.path)).toList();
        if (_presets.isNotEmpty && _currentPreset.isEmpty) {
          _currentPreset = _presets.first.name;
          // Update shared state provider with first preset
          ref.read(trainerPresetProvider.notifier).setPreset(
            _presets.first.name,
            _presets.first.path ?? '',
          );
          // Load the full config for this preset
          ref.read(ot.currentConfigProvider.notifier).loadPreset(_presets.first.name);
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshPresets() async {
    final service = ref.read(ot.oneTrainerServiceProvider);
    final presets = await service.getPresets();
    setState(() {
      _presets = presets.map((p) => PresetInfo(name: p.name, path: p.path)).toList();
    });
  }

  /// Load a preset file from the selected preset
  Future<void> _loadPresetFile() async {
    if (_currentPreset.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a preset first')),
      );
      return;
    }

    final service = ref.read(ot.oneTrainerServiceProvider);
    final config = await service.loadPreset(_currentPreset);

    if (config != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loaded preset: $_currentPreset'),
          backgroundColor: Colors.green,
        ),
      );
      // TODO: Populate configuration fields with loaded config
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load preset: $_currentPreset'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Export current configuration
  Future<void> _exportConfig() async {
    final service = ref.read(ot.oneTrainerServiceProvider);

    // For now, just show a message - full implementation would gather all config
    final path = await service.saveTempConfig({
      'preset_name': _currentPreset,
      'model_type': _modelType,
      'training_method': _trainingMethod,
    });

    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported config to: $path'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Save current preset
  Future<void> _saveCurrentPreset() async {
    if (_currentPreset.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a preset first')),
      );
      return;
    }

    final service = ref.read(ot.oneTrainerServiceProvider);
    final currentConfig = ref.read(ot.currentConfigProvider);

    // Use the full config from currentConfigProvider
    final config = currentConfig.config;
    if (config == null || config.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No config loaded to save'), backgroundColor: Colors.orange),
      );
      return;
    }

    final result = await service.savePreset(_currentPreset, config);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success ? 'Saved preset: $_currentPreset' : 'Save failed: ${result.message}'),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final service = ref.watch(ot.oneTrainerServiceProvider);
    final trainingState = ref.watch(ot.trainingStateProvider);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(colorScheme, scaffoldBg, service),

          // Main content
          Expanded(
            child: Column(
              children: [
                // Top bar
                _buildTopBar(colorScheme),

                // Content
                Expanded(
                  child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _navItems[_selectedIndex].screen ?? _buildPlaceholder(_navItems[_selectedIndex].label),
                ),

                // Bottom status bar
                _buildStatusBar(colorScheme, service, trainingState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(ColorScheme colorScheme, Color scaffoldBg, ot.OneTrainerService service) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: scaffoldBg,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorScheme.primary, colorScheme.secondary],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text('OT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'OneTrainer',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Nav items
          Expanded(
            child: ListView.builder(
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = index == _selectedIndex;

                return InkWell(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primary.withOpacity(0.15) : null,
                      border: Border(
                        left: BorderSide(
                          color: isSelected ? colorScheme.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 18,
                          color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Connection status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    StreamBuilder<ot.OneTrainerConnectionState>(
                      stream: service.connectionState,
                      builder: (context, snapshot) {
                        final state = snapshot.data ?? ot.OneTrainerConnectionState.disconnected;
                        final isConnected = state == ot.OneTrainerConnectionState.connected;
                        return Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isConnected ? Colors.green :
                                       state == ot.OneTrainerConnectionState.connecting ? Colors.orange : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isConnected ? 'Connected' :
                              state == ot.OneTrainerConnectionState.connecting ? 'Connecting...' : 'Disconnected',
                              style: TextStyle(
                                color: isConnected ? Colors.green :
                                       state == ot.OneTrainerConnectionState.connecting ? Colors.orange : Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 16),
                      onPressed: _connectAndLoadPresets,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Stop Server button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Implement stop server functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Stop Server not implemented yet')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Stop Server', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPresetSelector() async {
    final result = await PresetCardSelector.show(
      context,
      presets: _presets,
      currentPreset: _currentPreset,
      onDelete: (preset) async {
        final service = ref.read(ot.oneTrainerServiceProvider);
        final result = await service.deletePreset(preset.name);
        if (result.success) {
          setState(() {
            _presets.removeWhere((p) => p.name == preset.name);
          });
        }
      },
    );
    if (result != null) {
      setState(() {
        _currentPreset = result.name;
      });
      // Update shared state provider
      ref.read(trainerPresetProvider.notifier).setPreset(result.name, result.path ?? '');
      // Load the full config for this preset
      ref.read(ot.currentConfigProvider.notifier).loadPreset(result.name);
    }
  }

  String _getModelTypeFromPreset(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('qwen') && lower.contains('edit')) return 'Qwen-Edit';
    if (lower.contains('qwen')) return 'Qwen';
    if (lower.contains('kandinsky')) return 'Kandinsky';
    if (lower.contains('flux')) return 'Flux';
    if (lower.contains('sdxl')) return 'SDXL';
    if (lower.contains('sd3')) return 'SD3';
    if (lower.contains('sd 1') || lower.contains('sd 2')) return 'SD';
    if (lower.contains('chroma')) return 'Chroma';
    if (lower.contains('z-image') || lower.contains('zimage')) return 'Z-Image';
    if (lower.contains('pixart')) return 'PixArt';
    if (lower.contains('hunyuan')) return 'Hunyuan';
    if (lower.contains('hidream')) return 'HiDream';
    if (lower.contains('wan')) return 'Wan';
    return 'Other';
  }

  String _getMethodTypeFromPreset(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('lora')) return 'LoRA';
    if (lower.contains('finetune')) return 'Finetune';
    if (lower.contains('embedding')) return 'Embedding';
    return 'Other';
  }

  Color _getModelColor(String modelType) {
    const colors = {
      'Qwen': Color(0xFF9333EA),
      'Qwen-Edit': Color(0xFF7C3AED),
      'Kandinsky': Color(0xFFE11D48),
      'Flux': Color(0xFF2563EB),
      'SDXL': Color(0xFF16A34A),
      'SD3': Color(0xFF0D9488),
      'SD': Color(0xFF4B5563),
      'Chroma': Color(0xFFDB2777),
      'Z-Image': Color(0xFFEA580C),
      'PixArt': Color(0xFF0891B2),
      'Hunyuan': Color(0xFFDC2626),
      'HiDream': Color(0xFF4F46E5),
      'Wan': Color(0xFF059669),
    };
    return colors[modelType] ?? const Color(0xFF6B7280);
  }

  Widget _buildTopBar(ColorScheme colorScheme) {
    final modelType = _getModelTypeFromPreset(_currentPreset);
    final methodType = _getMethodTypeFromPreset(_currentPreset);
    final modelColor = _getModelColor(modelType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          // Preset selector dropdown
          InkWell(
            onTap: _showPresetSelector,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.save_outlined, size: 16, color: colorScheme.onSurface.withOpacity(0.6)),
                  const SizedBox(width: 8),
                  Text(_currentPreset.isEmpty ? 'Select Preset' : _currentPreset,
                       style: TextStyle(color: colorScheme.onSurface, fontSize: 13)),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_drop_down, size: 18, color: colorScheme.onSurface.withOpacity(0.6)),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Grid view button
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: IconButton(
              icon: const Icon(Icons.grid_view, size: 18),
              onPressed: _showPresetSelector,
              color: colorScheme.onSurface.withOpacity(0.6),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),

          const Spacer(),

          // Model Type Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _modelType,
                dropdownColor: colorScheme.surface,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                items: _modelTypes.map((m) => DropdownMenuItem(
                  value: m['value'],
                  child: Text(m['label']!, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _modelType = v;
                      // Reset training method if invalid
                      final methods = _getTrainingMethods(v);
                      if (!methods.any((m) => m['value'] == _trainingMethod)) {
                        _trainingMethod = methods.first['value']!;
                      }
                    });
                  }
                },
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Training Method Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _trainingMethod,
                dropdownColor: colorScheme.surface,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                items: _getTrainingMethods(_modelType).map((m) => DropdownMenuItem(
                  value: m['value'],
                  child: Text(m['label']!, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _trainingMethod = v);
                  }
                },
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Action buttons
          TextButton.icon(
            onPressed: _loadPresetFile,
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('Load File'),
          ),
          TextButton.icon(
            onPressed: _exportConfig,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _saveCurrentPreset,
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save Preset'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ColorScheme colorScheme, ot.OneTrainerService service, ot.TrainingState trainingState) {
    // Bottom bar is intentionally empty - training controls are on Dashboard
    return const SizedBox.shrink();
  }

  Future<void> _startTraining(ot.OneTrainerService service) async {
    if (_currentPreset.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a preset first'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Get current edited config from provider - this includes all UI edits
    final currentConfig = ref.read(ot.currentConfigProvider);
    final config = currentConfig.config;

    if (config == null || config.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No config loaded - please load a preset first'), backgroundColor: Colors.red),
      );
      return;
    }

    // Save the current (possibly edited) config to a temp file
    // This ensures any UI edits are used in training
    final tempPath = await service.saveTempConfig(config);
    if (tempPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save config for training'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final result = await service.startTraining(tempPath);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _stopTraining(ot.OneTrainerService service) async {
    final result = await service.stopTraining();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _triggerSample(ot.OneTrainerService service) async {
    final result = await service.triggerSample();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Widget _buildPlaceholder(String title) {
    return Builder(
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction, size: 64, color: colorScheme.onSurface.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text(
                '$title - Coming Soon',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 18),
              ),
            ],
          ),
        );
      },
    );
  }
}
