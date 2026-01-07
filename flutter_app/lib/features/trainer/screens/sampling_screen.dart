import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/onetrainer_service.dart' as ot;

/// Sampling Screen - Sample definitions for training preview
/// Connected to OneTrainer API via currentConfigProvider
class SamplingScreen extends ConsumerStatefulWidget {
  const SamplingScreen({super.key});

  @override
  ConsumerState<SamplingScreen> createState() => _SamplingScreenState();
}

class _SamplingScreenState extends ConsumerState<SamplingScreen> {
  // Sample list
  List<Map<String, dynamic>> _samples = [];
  int? _selectedIndex;
  bool _loaded = false;

  static const _units = ['NEVER', 'EPOCH', 'STEP', 'SECOND', 'MINUTE', 'HOUR'];
  static const _formats = ['JPG', 'PNG'];
  static const _schedulers = [
    'DDIM', 'EULER', 'EULER_A', 'DPMPP', 'DPMPP_SDE', 'UNIPC',
    'EULER_KARRAS', 'DPMPP_KARRAS', 'DPMPP_SDE_KARRAS', 'UNIPC_KARRAS'
  ];

  @override
  void initState() {
    super.initState();
  }

  /// Load samples from config - checks both 'samples' array and sample_definition_file_name
  Future<void> _loadSamplesFromConfig(Map<String, dynamic> config) async {
    if (_loaded) return;

    // First try loading from samples array in config
    final samplesList = config['samples'] as List<dynamic>?;
    if (samplesList != null && samplesList.isNotEmpty) {
      final loaded = _parseSamplesList(samplesList);
      setState(() {
        _samples = loaded;
        if (_samples.isNotEmpty) _selectedIndex = 0;
        _loaded = true;
      });
      return;
    }

    // Try loading from sample_definition_file_name if samples array is empty
    final sampleDefFile = config['sample_definition_file_name'] as String?;
    if (sampleDefFile != null && sampleDefFile.isNotEmpty) {
      try {
        // Resolve relative paths against OneTrainer root
        String filePath = sampleDefFile;
        if (!sampleDefFile.startsWith('/')) {
          // Try common OneTrainer locations
          final possiblePaths = [
            '/home/alex/OneTrainer/$sampleDefFile',
            '/home/alex/OneTrainer_working/$sampleDefFile',
          ];
          for (final p in possiblePaths) {
            if (await File(p).exists()) {
              filePath = p;
              break;
            }
          }
        }
        final file = File(filePath);
        if (await file.exists()) {
          final content = await file.readAsString();
          final data = jsonDecode(content);
          if (data is List) {
            final loaded = _parseSamplesList(data);
            setState(() {
              _samples = loaded;
              if (_samples.isNotEmpty) _selectedIndex = 0;
              _loaded = true;
            });
            return;
          } else if (data is Map && data['samples'] is List) {
            final loaded = _parseSamplesList(data['samples'] as List);
            setState(() {
              _samples = loaded;
              if (_samples.isNotEmpty) _selectedIndex = 0;
              _loaded = true;
            });
            return;
          }
        }
      } catch (e) {
        print('Error loading sample definitions: $e');
      }
    }

    setState(() => _loaded = true);
  }

  List<Map<String, dynamic>> _parseSamplesList(List<dynamic> samplesList) {
    final loaded = <Map<String, dynamic>>[];
    for (final s in samplesList) {
      final sample = s as Map<String, dynamic>;
      loaded.add({
        'enabled': sample['enabled'] ?? true,
        'prompt': sample['prompt'] ?? '',
        'negative_prompt': sample['negative_prompt'] ?? '',
        'width': (sample['width'] as num?)?.toInt() ?? 512,
        'height': (sample['height'] as num?)?.toInt() ?? 512,
        'seed': (sample['seed'] as num?)?.toInt() ?? 42,
        'random_seed': sample['random_seed'] ?? false,
        'diffusion_steps': (sample['diffusion_steps'] as num?)?.toInt() ?? 20,
        'cfg_scale': (sample['cfg_scale'] as num?)?.toDouble() ?? 7.0,
        'noise_scheduler': sample['noise_scheduler'] ?? 'DDIM',
      });
    }
    return loaded;
  }

  /// Save samples back to config
  void _saveSamplesToConfig() {
    final samplesList = _samples.map((s) => {
      'enabled': s['enabled'] ?? true,
      'prompt': s['prompt'] ?? '',
      'negative_prompt': s['negative_prompt'] ?? '',
      'width': s['width'] ?? 512,
      'height': s['height'] ?? 512,
      'seed': s['seed'] ?? 42,
      'random_seed': s['random_seed'] ?? false,
      'diffusion_steps': s['diffusion_steps'] ?? 20,
      'cfg_scale': s['cfg_scale'] ?? 7.0,
      'noise_scheduler': s['noise_scheduler'] ?? 'DDIM',
    }).toList();

    ref.read(ot.currentConfigProvider.notifier).updateConfig({'samples': samplesList});
  }

  void _updateConfig(String key, dynamic value) {
    ref.read(ot.currentConfigProvider.notifier).updateConfig({key: value});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final currentConfig = ref.watch(ot.currentConfigProvider);
    final config = currentConfig.config ?? {};

    // Load samples from config
    if (config.isNotEmpty && !_loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSamplesFromConfig(config));
    }

    // Get sampling settings from config
    final sampleAfter = (config['sample_after'] as num?)?.toInt() ?? 10;
    final sampleUnit = config['sample_after_unit'] as String? ?? 'EPOCH';
    final skipFirst = (config['sample_skip_first'] as num?)?.toInt() ?? 0;
    final format = config['sample_image_format'] as String? ?? 'JPG';
    final nonEmaSampling = config['non_ema_sampling'] as bool? ?? true;
    final samplesToTensorboard = config['samples_to_tensorboard'] as bool? ?? true;

    // Get selected sample data
    final selectedSample = _selectedIndex != null && _selectedIndex! < _samples.length
        ? _samples[_selectedIndex!]
        : null;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                Text('Sample Definitions', style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  child: const Text('sample now'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
                  child: const Text('manual sample'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _addSample,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Sample'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: const Text('Import Prompts'),
                ),
              ],
            ),
          ),

          // Settings bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                Text('Sample After', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: TextEditingController(text: sampleAfter.toString()),
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                    decoration: _inputDecoration(colorScheme),
                    onChanged: (v) => _updateConfig('sample_after', int.tryParse(v) ?? 10),
                  ),
                ),
                const SizedBox(width: 8),
                _buildCompactDropdown(sampleUnit, _units, (v) => _updateConfig('sample_after_unit', v), colorScheme),
                const SizedBox(width: 24),
                Text('Skip First', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: TextEditingController(text: skipFirst.toString()),
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                    decoration: _inputDecoration(colorScheme),
                    onChanged: (v) => _updateConfig('sample_skip_first', int.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 24),
                Text('Format', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
                const SizedBox(width: 8),
                _buildCompactDropdown(format, _formats, (v) => _updateConfig('sample_image_format', v), colorScheme),
                const SizedBox(width: 24),
                Text('Non-EMA Sampling', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
                const SizedBox(width: 8),
                Switch(
                  value: nonEmaSampling,
                  onChanged: (v) => _updateConfig('non_ema_sampling', v),
                  activeColor: Colors.teal,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 24),
                Text('Samples to Tensorboard', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
                const SizedBox(width: 8),
                Switch(
                  value: samplesToTensorboard,
                  onChanged: (v) => _updateConfig('samples_to_tensorboard', v),
                  activeColor: Colors.teal,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Row(
              children: [
                // Sample list
                Expanded(
                  flex: 3,
                  child: ListView.builder(
                    itemCount: _samples.length,
                    itemBuilder: (context, index) => _buildSampleRow(index, colorScheme),
                  ),
                ),

                // Details panel
                if (selectedSample != null)
                  Container(
                    width: 320,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border(left: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
                    ),
                    child: _buildDetailsPanel(colorScheme, selectedSample),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleRow(int index, ColorScheme colorScheme) {
    final sample = _samples[index];
    final isSelected = _selectedIndex == index;
    final width = sample['width'] ?? 512;
    final height = sample['height'] ?? 512;
    final resolution = '$width × $height';

    return InkWell(
      onTap: () => setState(() {
        _selectedIndex = index;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.1) : null,
          border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.2))),
        ),
        child: Row(
          children: [
            // Delete button
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              color: Colors.red.shade400,
              onPressed: () => _removeSample(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            // Copy button
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              color: colorScheme.onSurface.withOpacity(0.4),
              onPressed: () => _duplicateSample(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            const SizedBox(width: 8),
            // Enable toggle
            Switch(
              value: sample['enabled'] ?? true,
              onChanged: (v) {
                setState(() => _samples[index]['enabled'] = v);
                _saveSamplesToConfig();
              },
              activeColor: Colors.green,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 12),
            // Resolution
            SizedBox(
              width: 80,
              child: Text(resolution, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
            ),
            // Seed
            SizedBox(
              width: 60,
              child: Text('seed: ${sample['seed']}', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 11)),
            ),
            const SizedBox(width: 12),
            // Prompt (truncated)
            Expanded(
              child: Text(
                sample['prompt'] ?? '',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Menu
            IconButton(
              icon: const Icon(Icons.more_horiz, size: 18),
              color: colorScheme.onSurface.withOpacity(0.4),
              onPressed: () {},
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsPanel(ColorScheme colorScheme, Map<String, dynamic>? sample) {
    if (sample == null) return const SizedBox.shrink();

    final prompt = sample['prompt'] as String? ?? '';
    final negativePrompt = sample['negative_prompt'] as String? ?? '';
    final width = sample['width'] as int? ?? 512;
    final height = sample['height'] as int? ?? 512;
    final seed = sample['seed'] as int? ?? 42;
    final randomSeed = sample['random_seed'] as bool? ?? false;
    final diffusionSteps = sample['diffusion_steps'] as int? ?? 20;
    final cfgScale = sample['cfg_scale'] as double? ?? 7.0;
    final scheduler = sample['noise_scheduler'] as String? ?? 'DDIM';

    void updateSample(String key, dynamic value) {
      setState(() => _samples[_selectedIndex!][key] = value);
      _saveSamplesToConfig();
    }

    void setResolution(int w, int h) {
      setState(() {
        _samples[_selectedIndex!]['width'] = w;
        _samples[_selectedIndex!]['height'] = h;
      });
      _saveSamplesToConfig();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Sample Details', style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _selectedIndex = null),
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Prompt
          Text('Prompt', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: prompt),
            maxLines: 4,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
            decoration: _inputDecoration(colorScheme),
            onChanged: (v) => updateSample('prompt', v),
          ),
          const SizedBox(height: 12),

          // Negative Prompt
          Text('Negative Prompt', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: negativePrompt),
            maxLines: 2,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
            decoration: _inputDecoration(colorScheme).copyWith(hintText: 'Enter negative prompt...'),
            onChanged: (v) => updateSample('negative_prompt', v),
          ),
          const SizedBox(height: 16),

          // Width/Height
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Width', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: TextEditingController(text: width.toString()),
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                      decoration: _inputDecoration(colorScheme),
                      onChanged: (v) => updateSample('width', int.tryParse(v) ?? 512),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Height', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: TextEditingController(text: height.toString()),
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                      decoration: _inputDecoration(colorScheme),
                      onChanged: (v) => updateSample('height', int.tryParse(v) ?? 512),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Resolution Presets
          Text('Resolution Presets', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildPresetButtonWithCallback('512', 512, 512, width, height, setResolution, colorScheme),
              _buildPresetButtonWithCallback('768', 768, 768, width, height, setResolution, colorScheme),
              _buildPresetButtonWithCallback('1024', 1024, 1024, width, height, setResolution, colorScheme),
              _buildPresetButtonWithCallback('1536', 1536, 1536, width, height, setResolution, colorScheme),
              _buildPresetButtonWithCallback('2048', 2048, 2048, width, height, setResolution, colorScheme),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildPresetButtonWithCallback('1024×768', 1024, 768, width, height, setResolution, colorScheme),
              _buildPresetButtonWithCallback('768×1024', 768, 1024, width, height, setResolution, colorScheme),
              _buildPresetButtonWithCallback('1536×1024', 1536, 1024, width, height, setResolution, colorScheme),
              _buildPresetButtonWithCallback('1024×1536', 1024, 1536, width, height, setResolution, colorScheme),
            ],
          ),
          const SizedBox(height: 16),

          // Seed
          Text('Seed', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: seed.toString()),
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                  decoration: _inputDecoration(colorScheme),
                  onChanged: (v) => updateSample('seed', int.tryParse(v) ?? 42),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.shuffle, size: 18),
                onPressed: () => updateSample('seed', DateTime.now().millisecondsSinceEpoch % 1000000),
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Checkbox(
                value: randomSeed,
                onChanged: (v) => updateSample('random_seed', v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Text('Random Seed', style: TextStyle(color: colorScheme.onSurface, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),

          // Diffusion Steps / CFG Scale
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Diffusion Steps', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: TextEditingController(text: diffusionSteps.toString()),
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                      decoration: _inputDecoration(colorScheme),
                      onChanged: (v) => updateSample('diffusion_steps', int.tryParse(v) ?? 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CFG Scale', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: TextEditingController(text: cfgScale.toString()),
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                      decoration: _inputDecoration(colorScheme),
                      onChanged: (v) => updateSample('cfg_scale', double.tryParse(v) ?? 7.0),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Noise Scheduler
          Text('Noise Scheduler', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _schedulers.contains(scheduler) ? scheduler : _schedulers.first,
                isExpanded: true,
                dropdownColor: colorScheme.surface,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                items: _schedulers.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => updateSample('noise_scheduler', v!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButtonWithCallback(String label, int w, int h, int currentW, int currentH, void Function(int, int) onTap, ColorScheme colorScheme) {
    final isSelected = currentW == w && currentH == h;
    return InkWell(
      onTap: () => onTap(w, h),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.2) : colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7), fontSize: 11)),
      ),
    );
  }

  Widget _buildCompactDropdown(String value, List<String> options, Function(String) onChanged, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: colorScheme.surface,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(ColorScheme colorScheme) {
    return InputDecoration(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  void _addSample() {
    setState(() {
      _samples.add({
        'enabled': true,
        'prompt': 'Enter your prompt here...',
        'negative_prompt': '',
        'width': 1024,
        'height': 1024,
        'seed': 42,
        'random_seed': false,
        'diffusion_steps': 20,
        'cfg_scale': 7.0,
        'noise_scheduler': 'DDIM',
      });
      _selectedIndex = _samples.length - 1;
    });
    _saveSamplesToConfig();
  }

  void _removeSample(int index) {
    setState(() {
      _samples.removeAt(index);
      if (_selectedIndex == index) {
        _selectedIndex = _samples.isNotEmpty ? 0 : null;
      } else if (_selectedIndex != null && _selectedIndex! > index) {
        _selectedIndex = _selectedIndex! - 1;
      }
    });
    _saveSamplesToConfig();
  }

  void _duplicateSample(int index) {
    setState(() {
      _samples.insert(index + 1, Map<String, dynamic>.from(_samples[index]));
      _selectedIndex = index + 1;
    });
    _saveSamplesToConfig();
  }
}
