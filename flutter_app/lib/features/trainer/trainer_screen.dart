import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'widgets/mask_editor.dart';
import 'widgets/video_editor.dart';
import 'widgets/vid_prep.dart';

/// OneTrainer Inference Screen - Matches React App.tsx layout exactly
/// Top tabs: txt2img | img2img | Inpaint | Vid Prep | Video Editor | Models | Settings
/// Left sidebar: Collapsible parameter sections
/// Center: Image preview
/// Bottom: Prompt input + Gallery
class TrainerScreen extends ConsumerStatefulWidget {
  const TrainerScreen({super.key});

  @override
  ConsumerState<TrainerScreen> createState() => _TrainerScreenState();
}

enum GenerationMode { txt2img, img2img, inpaint }
enum MainTab { generate, vidprep, editor }

// Model options
class ModelOption {
  final String value;
  final String label;
  final String path;
  final String category;

  const ModelOption({
    required this.value,
    required this.label,
    required this.path,
    required this.category,
  });
}

final modelOptions = [
  ModelOption(value: 'flux_dev', label: 'FLUX Dev', path: '/home/alex/SwarmUI/Models/diffusion_models/flux1-dev.safetensors', category: 'Image'),
  ModelOption(value: 'flux_schnell', label: 'FLUX Schnell', path: '/home/alex/SwarmUI/Models/diffusion_models/flux_schnell.safetensors', category: 'Image'),
  ModelOption(value: 'sdxl', label: 'SDXL', path: '/home/alex/SwarmUI/Models/Stable-Diffusion/sdxl.safetensors', category: 'Image'),
  ModelOption(value: 'sd_35', label: 'SD 3.5', path: '/home/alex/SwarmUI/Models/diffusion_models/sd3.5_large.safetensors', category: 'Image'),
  ModelOption(value: 'z_image', label: 'Z-Image', path: '/home/alex/SwarmUI/Models/diffusion_models/z_image_de_turbo_v1_bf16.safetensors', category: 'Image'),
  ModelOption(value: 'wan_t2v_high', label: 'Wan 2.2 T2V (High)', path: '/home/alex/SwarmUI/Models/diffusion_models/wan2.2_t2v_high_noise_14B_fp16.safetensors', category: 'Video'),
  ModelOption(value: 'wan_i2v_high', label: 'Wan 2.2 I2V (High)', path: '/home/alex/SwarmUI/Models/diffusion_models/wan2.2_i2v_high_noise_14B_fp16.safetensors', category: 'Video'),
  ModelOption(value: 'kandinsky_5_video', label: 'Kandinsky 5 T2V', path: 'kandinskylab/Kandinsky-5.0-T2V-Lite-sft-5s', category: 'Video'),
];

final samplerOptions = ['euler', 'euler_a', 'dpm_2m', 'dpm_2m_karras', 'ddim', 'unipc', 'heun'];
final resolutionOptions = ['512x512', '768x768', '1024x1024', '1280x720', '720x1280', '1536x1536'];

class _TrainerScreenState extends ConsumerState<TrainerScreen> {
  // Tab state
  MainTab _mainTab = MainTab.generate;
  GenerationMode _mode = GenerationMode.txt2img;

  // Model state
  String _modelType = 'flux_dev';
  bool _modelLoaded = false;

  // Generation params
  String _prompt = '';
  String _negPrompt = '';
  int _seed = -1;
  int _steps = 20;
  double _cfg = 7;
  String _sampler = 'euler';
  String _resolution = '1024x1024';
  int _images = 1;

  // Optional features
  bool _variationSeed = false;
  String? _initImage;
  String? _maskImage;
  double _initStrength = 0.75;
  bool _refineEnabled = false;
  double _refineScale = 2;
  bool _cnEnabled = false;
  bool _freeU = false;
  bool _showAdvanced = false;

  // Video settings
  int _numFrames = 16;
  int _videoDuration = 5;
  int _videoFps = 24;
  String _videoResolution = '768x512';

  // LoRAs
  List<Map<String, dynamic>> _loras = [];

  // UI state
  bool _isGenerating = false;
  bool _isLoadingModel = false;
  String _loadingMessage = '';
  int _currentStep = 0;
  int _totalSteps = 0;
  String? _error;
  List<Map<String, dynamic>> _gallery = [];
  Map<String, dynamic>? _selectedImage;
  bool _showMaskEditor = false;

  bool get _isVideoModel => ['wan_t2v_high', 'wan_i2v_high', 'kandinsky_5_video'].contains(_modelType);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = colorScheme.surface;
    final borderColor = colorScheme.outlineVariant.withOpacity(0.3);
    final primaryColor = colorScheme.primary;

    // Show VidPrep or VideoEditor if those tabs selected
    if (_mainTab == MainTab.vidprep) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: Column(
          children: [
            _buildTopTabs(),
            const Expanded(child: VidPrep()),
          ],
        ),
      );
    }
    if (_mainTab == MainTab.editor) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: Column(
          children: [
            _buildTopTabs(),
            const Expanded(child: VideoEditor()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          Column(
            children: [
              // Top tabs
              _buildTopTabs(),

              // Main area
              Expanded(
                child: Row(
                  children: [
                    // Left sidebar - Parameters
                    _buildLeftSidebar(),

                    // Center - Preview
                    Expanded(child: _buildPreviewArea()),
                  ],
                ),
              ),

              // Bottom bar
              _buildBottomBar(),
            ],
          ),

          // Mask Editor Modal
          if (_showMaskEditor && _initImage != null)
            MaskEditor(
              imageUrl: _initImage,
              initialMask: null,
              onMaskChange: (mask) {
                setState(() {
                  // _maskImage = mask;
                  if (_mode != GenerationMode.inpaint) {
                    _mode = GenerationMode.inpaint;
                  }
                });
              },
              onClose: () => setState(() => _showMaskEditor = false),
            ),
        ],
      ),
    );
  }

  Widget _buildTopTabs() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          // Mode selector tabs
          Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                _buildModeTab('txt2img', Icons.auto_awesome, GenerationMode.txt2img),
                _buildModeTab('img2img', Icons.image, GenerationMode.img2img),
                _buildModeTab('Inpaint', Icons.brush, GenerationMode.inpaint),
              ],
            ),
          ),
          // Vid Prep tab
          _buildMainTab('Vid Prep', Icons.content_cut, MainTab.vidprep),
          // Video Editor tab
          _buildMainTab('Video Editor', Icons.movie, MainTab.editor),
          // Models tab
          _buildSimpleTab('Models', () {}),
          // Settings tab
          _buildSimpleTab('Settings', () {}),
          const Spacer(),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'OneTrainer Inference',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, IconData icon, GenerationMode mode) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _mainTab == MainTab.generate && _mode == mode;
    return InkWell(
      onTap: () => setState(() {
        _mainTab = MainTab.generate;
        _mode = mode;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.15) : null,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainTab(String label, IconData icon, MainTab tab) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _mainTab == tab;
    return InkWell(
      onTap: () => setState(() => _mainTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.15) : null,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleTab(String label, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 288,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: ListView(
        children: [
          // Filter
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Filter parameters...',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),

          // Core Parameters
          _CollapsibleSection(
            title: 'Core Parameters',
            defaultOpen: true,
            children: [
              _buildSlider('Images', _images.toDouble(), 1, 16, (v) => setState(() => _images = v.toInt())),
              _buildSeedRow(),
              _buildSlider('Steps', _steps.toDouble(), 1, 150, (v) => setState(() => _steps = v.toInt())),
              _buildSlider('CFG Scale', _cfg, 1, 30, (v) => setState(() => _cfg = v), step: 0.5),
            ],
          ),

          // Variation Seed
          _CollapsibleSection(
            title: 'Variation Seed',
            toggle: true,
            enabled: _variationSeed,
            onToggle: (v) => setState(() => _variationSeed = v),
            children: _variationSeed ? [
              _buildSlider('Strength', 0.5, 0, 1, (v) {}, step: 0.05),
            ] : [],
          ),

          // Resolution
          _CollapsibleSection(
            title: 'Resolution',
            defaultOpen: true,
            children: [
              _buildDropdown('Preset', _resolution, resolutionOptions, (v) => setState(() => _resolution = v)),
            ],
          ),

          // Sampling
          _CollapsibleSection(
            title: 'Sampling',
            defaultOpen: true,
            children: [
              _buildDropdown('Sampler', _sampler, samplerOptions, (v) => setState(() => _sampler = v)),
            ],
          ),

          // Init Image
          _CollapsibleSection(
            title: 'Init Image',
            defaultOpen: _mode != GenerationMode.txt2img,
            children: [
              _buildInitImageSection(),
            ],
          ),

          // Refine / Upscale
          _CollapsibleSection(
            title: 'Refine / Upscale',
            toggle: true,
            enabled: _refineEnabled,
            onToggle: (v) => setState(() => _refineEnabled = v),
            children: _refineEnabled ? [
              _buildSlider('Scale', _refineScale, 1, 4, (v) => setState(() => _refineScale = v), step: 0.5),
            ] : [],
          ),

          // ControlNet
          _CollapsibleSection(
            title: 'ControlNet',
            toggle: true,
            enabled: _cnEnabled,
            onToggle: (v) => setState(() => _cnEnabled = v),
            children: _cnEnabled ? [
              _buildDropdown('Model', 'canny', ['canny', 'depth', 'pose'], (v) {}),
            ] : [],
          ),

          // Video Settings
          _CollapsibleSection(
            title: 'VIDEO SETTINGS',
            defaultOpen: _isVideoModel,
            children: [
              _buildSlider('Duration (s)', _videoDuration.toDouble(), 1, 10, (v) => setState(() => _videoDuration = v.toInt())),
              _buildSlider('Frames', _numFrames.toDouble(), 4, 64, (v) => setState(() => _numFrames = v.toInt())),
              _buildDropdown('Resolution', _videoResolution, ['512x512', '768x512', '512x768', '1024x1024', '1280x768'], (v) => setState(() => _videoResolution = v)),
              _buildSlider('FPS', _videoFps.toDouble(), 8, 30, (v) => setState(() => _videoFps = v.toInt())),
            ],
          ),

          // FreeU
          _CollapsibleSection(
            title: 'FreeU',
            toggle: true,
            enabled: _freeU,
            onToggle: (v) => setState(() => _freeU = v),
            children: [],
          ),

          // Advanced toggle
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Checkbox(
                  value: _showAdvanced,
                  onChanged: (v) => setState(() => _showAdvanced = v!),
                  activeColor: colorScheme.primary,
                ),
                Text('Display Advanced Options', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),

          // LoRAs (advanced)
          if (_showAdvanced)
            _CollapsibleSection(
              title: 'LoRAs',
              children: [
                ..._loras.asMap().entries.map((e) => _buildLoraRow(e.key)),
                Builder(builder: (context) {
                  final cs = Theme.of(context).colorScheme;
                  return TextButton.icon(
                    onPressed: () => setState(() => _loras.add({'path': '', 'weight': 1.0, 'enabled': true})),
                    icon: Icon(Icons.add, size: 14, color: cs.primary),
                    label: Text('Add LoRA', style: TextStyle(color: cs.primary, fontSize: 12)),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSeedRow() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text('Seed', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
          ),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: _seed.toString()),
              style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (v) => _seed = int.tryParse(v) ?? -1,
            ),
          ),
          const SizedBox(width: 4),
          _buildIconButton('🎲', colorScheme.primary, () => setState(() => _seed = DateTime.now().millisecondsSinceEpoch % 2147483647)),
          _buildIconButton('♻️', colorScheme.secondary, () {
            if (_selectedImage != null) setState(() => _seed = _selectedImage!['seed'] ?? -1);
          }),
        ],
      ),
    );
  }

  Widget _buildIconButton(String emoji, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChange, {double step = 1}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) / step).round(),
              onChanged: onChange,
              activeColor: colorScheme.primary,
            ),
          ),
          SizedBox(
            width: 56,
            child: TextField(
              controller: TextEditingController(text: step < 1 ? value.toStringAsFixed(1) : value.toInt().toString()),
              style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              ),
              onChanged: (v) => onChange(double.tryParse(v) ?? value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, Function(String) onChange) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: options.contains(value) ? value : options.first,
                  isExpanded: true,
                  dropdownColor: colorScheme.surfaceContainerHighest,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
                  items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                  onChanged: (v) => onChange(v!),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitImageSection() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_initImage != null) {
      return Column(
        children: [
          Stack(
            children: [
              Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(_initImage!, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: InkWell(
                  onTap: () => setState(() {
                    _initImage = null;
                    _maskImage = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.close, size: 14, color: colorScheme.onError),
                  ),
                ),
              ),
            ],
          ),
          if (_mode == GenerationMode.inpaint)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mask', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _showMaskEditor = true),
                    icon: const Icon(Icons.brush, size: 14),
                    label: Text(_maskImage != null ? 'Edit Mask' : 'Create Mask'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.tertiary,
                      foregroundColor: colorScheme.onTertiary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),
          _buildSlider('Strength', _initStrength, 0, 1, (v) => setState(() => _initStrength = v), step: 0.05),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_upload, color: colorScheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text('Drop image here or click to upload', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Use selected image
                },
                icon: const Icon(Icons.image, size: 14),
                label: const Text('Use selected image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoraRow(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final lora = _loras[index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: TextEditingController(text: lora['path']),
              style: TextStyle(color: colorScheme.onSurface, fontSize: 11),
              decoration: InputDecoration(
                hintText: 'LoRA path...',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 48,
            child: TextField(
              controller: TextEditingController(text: lora['weight'].toString()),
              style: TextStyle(color: colorScheme.onSurface, fontSize: 11),
              decoration: InputDecoration(
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete, size: 14, color: colorScheme.error),
            onPressed: () => setState(() => _loras.removeAt(index)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Image preview
        Expanded(
          child: Container(
            color: colorScheme.surface,
            child: Center(
              child: _selectedImage != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Image.network(
                              '/api/gallery/${_selectedImage!['id']}',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 64, color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Welcome to OneTrainer Inference', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 18)),
                        const SizedBox(height: 8),
                        Text('Select a model and generate images', style: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 14)),
                      ],
                    ),
            ),
          ),
        ),

        // Progress bar
        if (_isLoadingModel || _isGenerating)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: colorScheme.surface.withOpacity(0.9),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  _isLoadingModel && !_isGenerating
                      ? _loadingMessage
                      : _isGenerating && _currentStep > 0
                          ? 'Step $_currentStep/$_totalSteps'
                          : 'Starting generation...',
                  style: TextStyle(color: colorScheme.primary, fontSize: 14),
                ),
                if (_isGenerating && _totalSteps > 0) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _currentStep / _totalSteps,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        color: colorScheme.primary,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${((_currentStep / _totalSteps) * 100).round()}%', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ],
            ),
          ),

        // Prompt area
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
          ),
          child: Column(
            children: [
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: colorScheme.error.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(_error!, style: TextStyle(color: colorScheme.error, fontSize: 13))),
                      IconButton(
                        icon: Icon(Icons.close, size: 16, color: colorScheme.error),
                        onPressed: () => setState(() => _error = null),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        // Positive prompt
                        Row(
                          children: [
                            Text('+', style: TextStyle(color: colorScheme.primary, fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: TextEditingController(text: _prompt),
                                style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                                maxLines: 1,
                                decoration: InputDecoration(
                                  hintText: 'Type your prompt here...',
                                  hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                ),
                                onChanged: (v) => _prompt = v,
                                onSubmitted: (_) => _generate(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Negative prompt
                        Row(
                          children: [
                            Text('Neg:', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: TextEditingController(text: _negPrompt),
                                style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Optionally, type a negative prompt here...',
                                  hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                onChanged: (v) => _negPrompt = v,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: _isGenerating ? _cancel : _generate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isGenerating ? colorScheme.error : colorScheme.primary,
                          foregroundColor: _isGenerating ? colorScheme.onError : colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        child: Row(
                          children: [
                            Text(_isGenerating ? 'Cancel' : 'Generate'),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 16),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      IconButton(
                        icon: const Icon(Icons.settings, size: 16),
                        color: colorScheme.onSurfaceVariant,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          // Gallery
          SizedBox(
            height: 80,
            child: _gallery.isEmpty
                ? Center(child: Text('No images yet', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(4),
                    itemCount: _gallery.length,
                    itemBuilder: (context, index) {
                      final img = _gallery[index];
                      final isSelected = _selectedImage?['id'] == img['id'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedImage = img),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected ? colorScheme.primary : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(img['thumbnail'] ?? '', width: 72, height: 72, fit: BoxFit.cover),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom tabs & model selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              border: Border(top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                // Model selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
                  ),
                  child: Row(
                    children: [
                      Text('Model:', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(width: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _modelType,
                          dropdownColor: colorScheme.surfaceContainerHighest,
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                          items: modelOptions.map((m) => DropdownMenuItem(value: m.value, child: Text(m.label))).toList(),
                          onChanged: (v) => setState(() => _modelType = v!),
                        ),
                      ),
                      if (_modelLoaded)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),

                // Tab buttons
                _buildBottomTab('History', true),
                _buildBottomTab('Models', false),
                _buildBottomTab('VAEs', false),
                _buildBottomTab('LoRAs', false),
                _buildBottomTab('ControlNets', false),

                const Spacer(),
                Text('OneTrainer Inference v1.0', style: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.5), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTab(String label, bool isSelected) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _generate() {
    // TODO: Call API
    setState(() => _isGenerating = true);
  }

  void _cancel() {
    // TODO: Call cancel API
    setState(() => _isGenerating = false);
  }
}

/// Collapsible section widget
class _CollapsibleSection extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final bool defaultOpen;
  final bool toggle;
  final bool enabled;
  final Function(bool)? onToggle;

  const _CollapsibleSection({
    required this.title,
    required this.children,
    this.defaultOpen = false,
    this.toggle = false,
    this.enabled = false,
    this.onToggle,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _isOpen;

  @override
  void initState() {
    super.initState();
    _isOpen = widget.defaultOpen;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isOpen = !_isOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    _isOpen ? Icons.expand_more : Icons.chevron_right,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                    ),
                  ),
                  if (widget.toggle)
                    GestureDetector(
                      onTap: () => widget.onToggle?.call(!widget.enabled),
                      child: Container(
                        width: 32,
                        height: 16,
                        decoration: BoxDecoration(
                          color: widget.enabled ? colorScheme.primary : colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 150),
                          alignment: widget.enabled ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.onPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_isOpen)
            Container(
              color: colorScheme.surface.withOpacity(0.5),
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(children: widget.children),
            ),
        ],
      ),
    );
  }
}
