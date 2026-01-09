import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/providers.dart';
import '../../regional/regional_prompt_editor.dart';
import 'init_image_panel.dart';
import 'variation_panel.dart';
import 'controlnet_panel.dart';

/// ERI-style parameters panel with collapsible sections
/// Matches SwarmUI parameter layout with "Display Advanced Options" toggle
class EriParametersPanel extends ConsumerStatefulWidget {
  const EriParametersPanel({super.key});

  @override
  ConsumerState<EriParametersPanel> createState() => _EriParametersPanelState();
}

class _EriParametersPanelState extends ConsumerState<EriParametersPanel> {
  // Track which sections are expanded
  bool _variationSeedExpanded = false;
  bool _resolutionExpanded = false;
  bool _samplingExpanded = true;
  bool _initImageExpanded = false;
  bool _refineUpscaleExpanded = false;
  bool _controlNetExpanded = false;
  bool _imageToVideoExpanded = false;

  // Advanced sections
  bool _eriInternalExpanded = false;
  bool _advancedVideoExpanded = false;
  bool _videoExtendExpanded = false;
  bool _advancedModelAddonsExpanded = false;
  bool _regionalPromptingExpanded = false;
  bool _segmentRefiningExpanded = false;
  bool _comfyUIExpanded = false;
  bool _dynamicThresholdingExpanded = false;
  bool _freeUExpanded = false;
  bool _scoringExpanded = false;
  bool _advancedSamplingExpanded = false;
  bool _otherFixesExpanded = false;

  // Master toggle for advanced options
  bool _showAdvancedOptions = false;

  // Count of advanced options (matches SwarmUI showing 118)
  int get _advancedOptionsCount => 118;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);
    final generationState = ref.watch(generationProvider);
    final isGenerating = generationState.isGenerating;

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Scrollable parameter sections
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Core Parameters - always visible at top
                _CoreParametersSection(
                  images: params.batchSize,
                  seed: params.seed,
                  steps: params.steps,
                  cfgScale: params.cfgScale,
                  onImagesChanged: isGenerating ? null : paramsNotifier.setBatchSize,
                  onSeedChanged: isGenerating ? null : paramsNotifier.setSeed,
                  onStepsChanged: isGenerating ? null : paramsNotifier.setSteps,
                  onCfgScaleChanged: isGenerating ? null : paramsNotifier.setCfgScale,
                ),

                // Variation Seed
                _CollapsibleSection(
                  title: 'Variation Seed',
                  icon: Icons.shuffle,
                  isExpanded: _variationSeedExpanded,
                  hasToggle: true,
                  onToggle: () => setState(() => _variationSeedExpanded = !_variationSeedExpanded),
                  child: _VariationSeedContent(
                    enabled: _variationSeedExpanded,
                    onEnabledChanged: (v) => setState(() => _variationSeedExpanded = v),
                  ),
                ),

                // Resolution section
                _CollapsibleSection(
                  title: 'Resolution: ${params.width}x${params.height}',
                  icon: Icons.aspect_ratio,
                  isExpanded: _resolutionExpanded,
                  onToggle: () => setState(() => _resolutionExpanded = !_resolutionExpanded),
                  child: _ResolutionContent(
                    width: params.width,
                    height: params.height,
                    onWidthChanged: isGenerating ? null : paramsNotifier.setWidth,
                    onHeightChanged: isGenerating ? null : paramsNotifier.setHeight,
                  ),
                ),

                // Sampling section
                _CollapsibleSection(
                  title: 'Sampling',
                  icon: Icons.tune,
                  isExpanded: _samplingExpanded,
                  onToggle: () => setState(() => _samplingExpanded = !_samplingExpanded),
                  child: _SamplingContent(
                    sampler: params.sampler,
                    scheduler: params.scheduler,
                    onSamplerChanged: isGenerating ? null : paramsNotifier.setSampler,
                    onSchedulerChanged: isGenerating ? null : paramsNotifier.setScheduler,
                  ),
                ),

                // Init Image
                _CollapsibleSection(
                  title: 'Init Image',
                  icon: Icons.image,
                  isExpanded: _initImageExpanded,
                  hasToggle: true,
                  onToggle: () => setState(() => _initImageExpanded = !_initImageExpanded),
                  child: _InitImageContent(enabled: _initImageExpanded),
                ),

                // Refine / Upscale
                _CollapsibleSection(
                  title: 'Refine / Upscale',
                  icon: Icons.auto_fix_high,
                  isExpanded: _refineUpscaleExpanded,
                  hasToggle: true,
                  onToggle: () => setState(() => _refineUpscaleExpanded = !_refineUpscaleExpanded),
                  child: _RefineUpscaleContent(enabled: _refineUpscaleExpanded),
                ),

                // ControlNet
                _CollapsibleSection(
                  title: 'ControlNet',
                  icon: Icons.control_camera,
                  isExpanded: _controlNetExpanded,
                  hasToggle: true,
                  onToggle: () => setState(() => _controlNetExpanded = !_controlNetExpanded),
                  child: _ControlNetContent(enabled: _controlNetExpanded),
                ),

                // Video Generation (T2V / I2V)
                _CollapsibleSection(
                  title: 'Video',
                  icon: Icons.video_library,
                  isExpanded: _imageToVideoExpanded,
                  hasToggle: true,
                  onToggle: () => setState(() => _imageToVideoExpanded = !_imageToVideoExpanded),
                  child: _ImageToVideoContent(enabled: _imageToVideoExpanded),
                ),

                // LoRAs now shown in bottom panel above tabs (SwarmUI style)

                // === ADVANCED SECTIONS (only visible when checkbox is checked) ===
                if (_showAdvancedOptions) ...[
                  // Eri Internal (was Swarm Internal)
                  _CollapsibleSection(
                    title: 'Eri Internal',
                    icon: Icons.settings_applications,
                    isExpanded: _eriInternalExpanded,
                    onToggle: () => setState(() => _eriInternalExpanded = !_eriInternalExpanded),
                    child: _EriInternalContent(
                      batchSize: params.batchSize,
                      onBatchSizeChanged: isGenerating ? null : paramsNotifier.setBatchSize,
                    ),
                  ),

                  // Advanced Video
                  _CollapsibleSection(
                    title: 'Advanced Video',
                    icon: Icons.movie_filter,
                    isExpanded: _advancedVideoExpanded,
                    hasToggle: true,
                    onToggle: () => setState(() => _advancedVideoExpanded = !_advancedVideoExpanded),
                    child: _AdvancedVideoContent(enabled: _advancedVideoExpanded),
                  ),

                  // Video Extend
                  _CollapsibleSection(
                    title: 'Video Extend',
                    icon: Icons.video_settings,
                    isExpanded: _videoExtendExpanded,
                    hasToggle: true,
                    onToggle: () => setState(() => _videoExtendExpanded = !_videoExtendExpanded),
                    child: _VideoExtendContent(enabled: _videoExtendExpanded),
                  ),

                  // Advanced Model Addons
                  _CollapsibleSection(
                    title: 'Advanced Model Addons',
                    icon: Icons.extension,
                    isExpanded: _advancedModelAddonsExpanded,
                    onToggle: () => setState(() => _advancedModelAddonsExpanded = !_advancedModelAddonsExpanded),
                    child: _AdvancedModelAddonsContent(),
                  ),

                  // Regional Prompting
                  _CollapsibleSection(
                    title: 'Regional Prompting',
                    icon: Icons.grid_view,
                    isExpanded: _regionalPromptingExpanded,
                    onToggle: () => setState(() => _regionalPromptingExpanded = !_regionalPromptingExpanded),
                    child: const SizedBox(height: 300, child: RegionalPromptEditor()),
                  ),

                  // Segment Refining
                  _CollapsibleSection(
                    title: 'Segment Refining',
                    icon: Icons.auto_awesome_mosaic,
                    isExpanded: _segmentRefiningExpanded,
                    onToggle: () => setState(() => _segmentRefiningExpanded = !_segmentRefiningExpanded),
                    child: _SegmentRefiningContent(),
                  ),

                  // ComfyUI
                  _CollapsibleSection(
                    title: 'ComfyUI',
                    icon: Icons.account_tree,
                    isExpanded: _comfyUIExpanded,
                    onToggle: () => setState(() => _comfyUIExpanded = !_comfyUIExpanded),
                    child: _ComfyUIContent(),
                  ),

                  // Dynamic Thresholding
                  _CollapsibleSection(
                    title: 'Dynamic Thresholding',
                    icon: Icons.show_chart,
                    isExpanded: _dynamicThresholdingExpanded,
                    hasToggle: true,
                    onToggle: () => setState(() => _dynamicThresholdingExpanded = !_dynamicThresholdingExpanded),
                    child: _DynamicThresholdingContent(),
                  ),

                  // FreeU
                  _CollapsibleSection(
                    title: 'FreeU',
                    icon: Icons.tune,
                    isExpanded: _freeUExpanded,
                    hasToggle: true,
                    onToggle: () => setState(() => _freeUExpanded = !_freeUExpanded),
                    child: _FreeUContent(),
                  ),

                  // Scoring
                  _CollapsibleSection(
                    title: 'Scoring',
                    icon: Icons.score,
                    isExpanded: _scoringExpanded,
                    hasToggle: true,
                    onToggle: () => setState(() => _scoringExpanded = !_scoringExpanded),
                    child: _ScoringContent(),
                  ),

                  // Advanced Sampling
                  _CollapsibleSection(
                    title: 'Advanced Sampling',
                    icon: Icons.science,
                    isExpanded: _advancedSamplingExpanded,
                    onToggle: () => setState(() => _advancedSamplingExpanded = !_advancedSamplingExpanded),
                    child: _AdvancedSamplingContent(),
                  ),

                  // Other Fixes
                  _CollapsibleSection(
                    title: 'Other Fixes',
                    icon: Icons.build,
                    isExpanded: _otherFixesExpanded,
                    onToggle: () => setState(() => _otherFixesExpanded = !_otherFixesExpanded),
                    child: _OtherFixesContent(),
                  ),
                ],
              ],
            ),
          ),

          // Display Advanced Options checkbox (like SwarmUI)
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
              ),
            ),
            child: CheckboxListTile(
              value: _showAdvancedOptions,
              onChanged: (v) => setState(() => _showAdvancedOptions = v ?? false),
              title: Text(
                'Display Advanced Options? ($_advancedOptionsCount)',
                style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
              ),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),

          // Error display
          if (generationState.error != null)
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      generationState.error!,
                      style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => ref.read(generationProvider.notifier).clearError(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Core Parameters section (always visible, like SwarmUI's top box)
class _CoreParametersSection extends StatelessWidget {
  final int images;
  final int seed;
  final int steps;
  final double cfgScale;
  final ValueChanged<int>? onImagesChanged;
  final ValueChanged<int>? onSeedChanged;
  final ValueChanged<int>? onStepsChanged;
  final ValueChanged<double>? onCfgScaleChanged;

  const _CoreParametersSection({
    required this.images,
    required this.seed,
    required this.steps,
    required this.cfgScale,
    this.onImagesChanged,
    this.onSeedChanged,
    this.onStepsChanged,
    this.onCfgScaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Core Parameters',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Images count
          Row(
            children: [
              Text('Images', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              const Spacer(),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: TextEditingController(text: images.toString()),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  style: const TextStyle(fontSize: 12),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onSubmitted: (v) => onImagesChanged?.call(int.tryParse(v) ?? 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Seed
          Row(
            children: [
              Text('Seed', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              const Spacer(),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: TextEditingController(text: seed == -1 ? '-1' : seed.toString()),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  style: const TextStyle(fontSize: 12),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onSubmitted: (v) => onSeedChanged?.call(int.tryParse(v) ?? -1),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.casino, size: 16, color: colorScheme.primary),
                onPressed: () => onSeedChanged?.call(-1),
                tooltip: 'Random',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: Icon(Icons.refresh, size: 16, color: colorScheme.primary),
                onPressed: () {},
                tooltip: 'Reuse last',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Steps slider
          _ParameterSlider(
            label: 'Steps',
            value: steps.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: onStepsChanged != null ? (v) => onStepsChanged!(v.round()) : null,
          ),
          const SizedBox(height: 4),
          // CFG Scale slider
          _ParameterSlider(
            label: 'CFG Scale',
            value: cfgScale,
            min: 1,
            max: 20,
            divisions: 38,
            decimals: 1,
            onChanged: onCfgScaleChanged,
          ),
        ],
      ),
    );
  }
}

/// Segment Refining content - mask-based regional refinement
class _SegmentRefiningContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enable toggle
          SwitchListTile(
            title: const Text('Enable Segment Refining', style: TextStyle(fontSize: 12)),
            value: params.extraParams['segment_refine_enabled'] == true,
            onChanged: (v) => paramsNotifier.setExtraParam('segment_refine_enabled', v),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          // Refine strength
          _ParameterSlider(
            label: 'Refine Strength',
            value: (params.extraParams['segment_refine_strength'] as double?) ?? 0.5,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            decimals: 2,
            onChanged: (v) => paramsNotifier.setExtraParam('segment_refine_strength', v),
          ),
          const SizedBox(height: 8),
          // Refine steps
          _ParameterSlider(
            label: 'Refine Steps',
            value: ((params.extraParams['segment_refine_steps'] as int?) ?? 10).toDouble(),
            min: 1,
            max: 50,
            divisions: 49,
            decimals: 0,
            onChanged: (v) => paramsNotifier.setExtraParam('segment_refine_steps', v.toInt()),
          ),
          const SizedBox(height: 8),
          // Segment mode
          _ParameterDropdown(
            label: 'Segment Mode',
            value: (params.extraParams['segment_mode'] as String?) ?? 'face',
            items: const ['face', 'person', 'background', 'custom_mask'],
            onChanged: (v) => paramsNotifier.setExtraParam('segment_mode', v),
          ),
        ],
      ),
    );
  }
}

/// ComfyUI Workflows content
class _ComfyUIContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Workflow selector button
          OutlinedButton.icon(
            onPressed: () {
              // Navigate to ComfyUI workflow screen
              context.go('/comfyui');
            },
            icon: const Icon(Icons.account_tree, size: 16),
            label: const Text('Open Workflow Editor'),
          ),
          const SizedBox(height: 8),
          // Quick workflow dropdown
          _ParameterDropdown(
            label: 'Quick Workflow',
            value: 'default',
            items: const ['default', 'hires_fix', 'upscale_2x', 'face_restore', 'custom'],
            onChanged: (v) {},
          ),
          const SizedBox(height: 8),
          Text(
            'Use ComfyUI workflows for advanced generation pipelines',
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Dynamic Thresholding content - CFG rescaling
class _DynamicThresholdingContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mimic Scale
          _ParameterSlider(
            label: 'Mimic Scale',
            value: (params.extraParams['dtmimicscale'] as double?) ?? 7.0,
            min: 1.0,
            max: 30.0,
            divisions: 58,
            decimals: 1,
            onChanged: (v) => paramsNotifier.setExtraParam('dtmimicscale', v),
          ),
          const SizedBox(height: 8),
          // Threshold Percentile
          _ParameterSlider(
            label: 'Threshold Percentile',
            value: (params.extraParams['dtthresholdpercentile'] as double?) ?? 1.0,
            min: 0.9,
            max: 1.0,
            divisions: 10,
            decimals: 2,
            onChanged: (v) => paramsNotifier.setExtraParam('dtthresholdpercentile', v),
          ),
          const SizedBox(height: 8),
          // Mimic Mode
          _ParameterDropdown(
            label: 'Mimic Mode',
            value: (params.extraParams['dtmimicscalemode'] as String?) ?? 'Constant',
            items: const ['Constant', 'Linear Down', 'Cosine Down', 'Half Cosine Down'],
            onChanged: (v) => paramsNotifier.setExtraParam('dtmimicscalemode', v),
          ),
          const SizedBox(height: 8),
          // CFG Mode
          _ParameterDropdown(
            label: 'CFG Mode',
            value: (params.extraParams['dtcfgscalemode'] as String?) ?? 'Constant',
            items: const ['Constant', 'Linear Down', 'Cosine Down', 'Half Cosine Down'],
            onChanged: (v) => paramsNotifier.setExtraParam('dtcfgscalemode', v),
          ),
        ],
      ),
    );
  }
}

/// FreeU content - backbone/skip enhancement
class _FreeUContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Backbone Scale 1
          _ParameterSlider(
            label: 'Backbone Scale 1',
            value: (params.extraParams['freeub1'] as double?) ?? 1.1,
            min: 0.0,
            max: 2.0,
            divisions: 40,
            decimals: 2,
            onChanged: (v) => paramsNotifier.setExtraParam('freeub1', v),
          ),
          const SizedBox(height: 8),
          // Backbone Scale 2
          _ParameterSlider(
            label: 'Backbone Scale 2',
            value: (params.extraParams['freeub2'] as double?) ?? 1.2,
            min: 0.0,
            max: 2.0,
            divisions: 40,
            decimals: 2,
            onChanged: (v) => paramsNotifier.setExtraParam('freeub2', v),
          ),
          const SizedBox(height: 8),
          // Skip Scale 1
          _ParameterSlider(
            label: 'Skip Scale 1',
            value: (params.extraParams['freeus1'] as double?) ?? 0.9,
            min: 0.0,
            max: 2.0,
            divisions: 40,
            decimals: 2,
            onChanged: (v) => paramsNotifier.setExtraParam('freeus1', v),
          ),
          const SizedBox(height: 8),
          // Skip Scale 2
          _ParameterSlider(
            label: 'Skip Scale 2',
            value: (params.extraParams['freeus2'] as double?) ?? 0.2,
            min: 0.0,
            max: 2.0,
            divisions: 40,
            decimals: 2,
            onChanged: (v) => paramsNotifier.setExtraParam('freeus2', v),
          ),
        ],
      ),
    );
  }
}

/// Scoring content - automatic image quality scoring
class _ScoringContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aesthetic score threshold
          _ParameterSlider(
            label: 'Min Aesthetic Score',
            value: (params.extraParams['min_aesthetic_score'] as double?) ?? 0.0,
            min: 0.0,
            max: 10.0,
            divisions: 100,
            decimals: 1,
            onChanged: (v) => paramsNotifier.setExtraParam('min_aesthetic_score', v),
          ),
          const SizedBox(height: 8),
          // Artifact detection
          SwitchListTile(
            title: const Text('Detect Artifacts', style: TextStyle(fontSize: 12)),
            subtitle: Text('Flag images with hands/face issues', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
            value: params.extraParams['detect_artifacts'] == true,
            onChanged: (v) => paramsNotifier.setExtraParam('detect_artifacts', v),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          // Auto-discard bad images
          SwitchListTile(
            title: const Text('Auto-Discard Failed', style: TextStyle(fontSize: 12)),
            subtitle: Text('Automatically regenerate low-score images', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
            value: params.extraParams['auto_discard_low_score'] == true,
            onChanged: (v) => paramsNotifier.setExtraParam('auto_discard_low_score', v),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// Advanced Sampling content
class _AdvancedSamplingContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sigma Min
          _ParameterSlider(
            label: 'Sigma Min',
            value: (params.extraParams['sigmamin'] as double?) ?? 0.0,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            decimals: 3,
            onChanged: (v) => paramsNotifier.setExtraParam('sigmamin', v),
          ),
          const SizedBox(height: 8),
          // Sigma Max
          _ParameterSlider(
            label: 'Sigma Max',
            value: (params.extraParams['sigmamax'] as double?) ?? 14.6,
            min: 0.0,
            max: 20.0,
            divisions: 200,
            decimals: 1,
            onChanged: (v) => paramsNotifier.setExtraParam('sigmamax', v),
          ),
          const SizedBox(height: 8),
          // VAE Tiling
          SwitchListTile(
            title: const Text('VAE Tiling', style: TextStyle(fontSize: 12)),
            value: params.extraParams['vaetile'] == true,
            onChanged: (v) => paramsNotifier.setExtraParam('vaetile', v),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// Other Fixes content
class _OtherFixesContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video frame interpolation
          SwitchListTile(
            title: const Text('Frame Interpolation', style: TextStyle(fontSize: 12)),
            subtitle: Text('RIFE interpolation for smoother video', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
            value: params.extraParams['frame_interpolation'] == true,
            onChanged: (v) => paramsNotifier.setExtraParam('frame_interpolation', v),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          // Interpolation factor
          if (params.extraParams['frame_interpolation'] == true)
            _ParameterDropdown(
              label: 'Interpolation Factor',
              value: (params.extraParams['interpolation_factor'] as String?) ?? '2x',
              items: const ['2x', '4x', '8x'],
              onChanged: (v) => paramsNotifier.setExtraParam('interpolation_factor', v),
            ),
          const SizedBox(height: 8),
          // Video trim start
          _ParameterSlider(
            label: 'Trim Start (frames)',
            value: ((params.extraParams['trim_start'] as int?) ?? 0).toDouble(),
            min: 0,
            max: 50,
            divisions: 50,
            decimals: 0,
            onChanged: (v) => paramsNotifier.setExtraParam('trim_start', v.toInt()),
          ),
          const SizedBox(height: 8),
          // Video trim end
          _ParameterSlider(
            label: 'Trim End (frames)',
            value: ((params.extraParams['trim_end'] as int?) ?? 0).toDouble(),
            min: 0,
            max: 50,
            divisions: 50,
            decimals: 0,
            onChanged: (v) => paramsNotifier.setExtraParam('trim_end', v.toInt()),
          ),
          const SizedBox(height: 8),
          // Face restore
          SwitchListTile(
            title: const Text('Auto Face Restore', style: TextStyle(fontSize: 12)),
            subtitle: Text('Apply GFPGAN/CodeFormer after generation', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
            value: params.extraParams['auto_face_restore'] == true,
            onChanged: (v) => paramsNotifier.setExtraParam('auto_face_restore', v),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// Collapsible section widget like ERI/SwarmUI
class _CollapsibleSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isExpanded;
  final bool hasToggle;
  final VoidCallback onToggle;
  final Widget child;

  const _CollapsibleSection({
    required this.title,
    required this.icon,
    required this.isExpanded,
    this.hasToggle = false,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Header - compact single line like SwarmUI
        InkWell(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (hasToggle)
                  SizedBox(
                    height: 20,
                    width: 36,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Switch(
                        value: isExpanded,
                        onChanged: (_) => onToggle(),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Content
        if (isExpanded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: child,
          ),
      ],
    );
  }
}

/// Resolution content
class _ResolutionContent extends StatelessWidget {
  final int width;
  final int height;
  final ValueChanged<int>? onWidthChanged;
  final ValueChanged<int>? onHeightChanged;

  const _ResolutionContent({
    required this.width,
    required this.height,
    this.onWidthChanged,
    this.onHeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Aspect ratio buttons
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _AspectButton(label: '1:1', isSelected: width == height, onTap: () {
              onWidthChanged?.call(1024);
              onHeightChanged?.call(1024);
            }),
            _AspectButton(label: '16:9', isSelected: width == 1344 && height == 768, onTap: () {
              onWidthChanged?.call(1344);
              onHeightChanged?.call(768);
            }),
            _AspectButton(label: '9:16', isSelected: width == 768 && height == 1344, onTap: () {
              onWidthChanged?.call(768);
              onHeightChanged?.call(1344);
            }),
            _AspectButton(label: '4:3', isSelected: width == 1152 && height == 896, onTap: () {
              onWidthChanged?.call(1152);
              onHeightChanged?.call(896);
            }),
            _AspectButton(label: '3:4', isSelected: width == 896 && height == 1152, onTap: () {
              onWidthChanged?.call(896);
              onHeightChanged?.call(1152);
            }),
          ],
        ),
        const SizedBox(height: 16),
        // Width slider
        _ParameterSlider(
          label: 'Width',
          value: width.toDouble(),
          min: 512,
          max: 2048,
          divisions: 24,
          onChanged: onWidthChanged != null ? (v) => onWidthChanged!(v.round()) : null,
        ),
        const SizedBox(height: 8),
        // Height slider
        _ParameterSlider(
          label: 'Height',
          value: height.toDouble(),
          min: 512,
          max: 2048,
          divisions: 24,
          onChanged: onHeightChanged != null ? (v) => onHeightChanged!(v.round()) : null,
        ),
      ],
    );
  }
}

/// Aspect ratio button
class _AspectButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AspectButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected ? colorScheme.primary.withOpacity(0.2) : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                Icon(Icons.check, size: 14, color: colorScheme.primary),
              if (isSelected) const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sampling content (just sampler/scheduler, steps/cfg moved to Core)
class _SamplingContent extends ConsumerWidget {
  final String sampler;
  final String scheduler;
  final ValueChanged<String>? onSamplerChanged;
  final ValueChanged<String>? onSchedulerChanged;

  const _SamplingContent({
    required this.sampler,
    required this.scheduler,
    this.onSamplerChanged,
    this.onSchedulerChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final samplers = ['euler', 'euler_ancestral', 'dpm_2', 'dpmpp_2m', 'dpmpp_sde', 'ddim', 'uni_pc'];
    final schedulers = ['normal', 'karras', 'exponential', 'simple', 'sgm_uniform'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sampler dropdown
        _ParameterDropdown(
          label: 'Sampler',
          value: sampler,
          items: samplers,
          onChanged: onSamplerChanged,
        ),
        const SizedBox(height: 12),
        // Scheduler dropdown
        _ParameterDropdown(
          label: 'Scheduler',
          value: scheduler,
          items: schedulers,
          onChanged: onSchedulerChanged,
        ),
      ],
    );
  }
}

/// Eri Internal content (advanced settings)
class _EriInternalContent extends ConsumerWidget {
  final int batchSize;
  final ValueChanged<int>? onBatchSizeChanged;

  const _EriInternalContent({required this.batchSize, this.onBatchSizeChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Batch Size
        _ParameterSlider(
          label: 'Batch Size',
          value: batchSize.toDouble(),
          min: 1,
          max: 9,
          divisions: 8,
          onChanged: onBatchSizeChanged != null ? (v) => onBatchSizeChanged!(v.round()) : null,
        ),
        const SizedBox(height: 12),

        // Backend Preference dropdown
        _ParameterDropdown(
          label: 'Backend Preference',
          value: (params.extraParams['backendpreference'] as String?) ?? 'Any',
          items: const ['Any', 'ComfyUI', 'Auto1111', 'Local'],
          onChanged: (v) => paramsNotifier.setExtraParam('backendpreference', v),
        ),
        const SizedBox(height: 8),

        // Model Loading Behavior dropdown
        _ParameterDropdown(
          label: 'Model Loading',
          value: (params.extraParams['modelloadmode'] as String?) ?? 'Standard',
          items: const ['Standard', 'Fast Swap', 'Keep Loaded', 'Unload After'],
          onChanged: (v) => paramsNotifier.setExtraParam('modelloadmode', v),
        ),
        const SizedBox(height: 8),

        // Cache Settings dropdown
        _ParameterDropdown(
          label: 'Cache Behavior',
          value: (params.extraParams['cachebehavior'] as String?) ?? 'Normal',
          items: const ['Normal', 'Aggressive', 'Minimal', 'Disabled'],
          onChanged: (v) => paramsNotifier.setExtraParam('cachebehavior', v),
        ),
        const SizedBox(height: 8),

        // Clip Skip
        _ParameterSlider(
          label: 'CLIP Skip',
          value: ((params.extraParams['clipstop'] as int?) ?? 1).toDouble(),
          min: 1,
          max: 12,
          divisions: 11,
          onChanged: (v) => paramsNotifier.setExtraParam('clipstop', v.round()),
        ),
        const SizedBox(height: 8),

        // FreeU Auto-apply toggle
        SwitchListTile(
          title: Text('Auto FreeU', style: TextStyle(fontSize: 12, color: colorScheme.onSurface)),
          subtitle: Text('Automatically apply FreeU enhancement', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
          value: params.extraParams['autoapplyfreeu'] == true,
          onChanged: (v) => paramsNotifier.setExtraParam('autoapplyfreeu', v),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),

        // Seamless Tiling toggle
        SwitchListTile(
          title: Text('Seamless Tiling', style: TextStyle(fontSize: 12, color: colorScheme.onSurface)),
          subtitle: Text('Generate tileable images', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
          value: params.extraParams['seamlesstileable'] == true,
          onChanged: (v) => paramsNotifier.setExtraParam('seamlesstileable', v),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

/// Parameter slider widget
class _ParameterSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final int decimals;
  final ValueChanged<double>? onChanged;

  const _ParameterSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.decimals = 0,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 45,
          child: Text(
            decimals > 0 ? value.toStringAsFixed(decimals) : value.round().toString(),
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// Parameter dropdown widget
class _ParameterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String>? onChanged;

  const _ParameterDropdown({
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
              isExpanded: true,
              isDense: true,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
              items: items.map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              )).toList(),
              onChanged: onChanged != null ? (v) => onChanged!(v!) : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Variation Seed content
class _VariationSeedContent extends ConsumerWidget {
  final bool enabled;
  final ValueChanged<bool>? onEnabledChanged;

  const _VariationSeedContent({required this.enabled, this.onEnabledChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Variation Seed input
        Row(
          children: [
            Text('Seed', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
            const Spacer(),
            SizedBox(
              width: 100,
              child: TextField(
                controller: TextEditingController(
                  text: params.variationSeed?.toString() ?? '-1',
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  hintText: '-1',
                ),
                style: const TextStyle(fontSize: 11),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onSubmitted: (v) {
                  final parsed = int.tryParse(v);
                  paramsNotifier.setVariationSeed(parsed == -1 ? null : parsed);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Variation Strength slider
        _ParameterSlider(
          label: 'Strength',
          value: params.variationStrength,
          min: 0,
          max: 1,
          divisions: 20,
          decimals: 2,
          onChanged: (v) => paramsNotifier.setVariationStrength(v),
        ),
      ],
    );
  }
}

/// Init Image content
class _InitImageContent extends ConsumerWidget {
  final bool enabled;

  const _InitImageContent({required this.enabled});

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final base64String = base64Encode(file.bytes!);
          ref.read(generationParamsProvider.notifier).setInitImage(base64String);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);
    final hasImage = params.initImage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image drop zone / preview with file picker
        GestureDetector(
          onTap: () => _pickImage(context, ref),
          child: Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: hasImage ? colorScheme.primary : colorScheme.outlineVariant,
                style: BorderStyle.solid,
              ),
            ),
            child: hasImage
                ? Stack(
                    children: [
                      Center(
                        child: Text('Image set', style: TextStyle(fontSize: 11, color: colorScheme.primary)),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: Icon(Icons.close, size: 16, color: colorScheme.error),
                          onPressed: () => paramsNotifier.setInitImage(null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Clear image',
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate, size: 24, color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 4),
                        Text('Click to select image', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        // Creativity slider (denoising strength)
        _ParameterSlider(
          label: 'Creativity',
          value: params.initImageCreativity,
          min: 0,
          max: 1,
          divisions: 20,
          decimals: 2,
          onChanged: (v) => paramsNotifier.setInitImageCreativity(v),
        ),
      ],
    );
  }
}

/// Refine / Upscale content
class _RefineUpscaleContent extends ConsumerWidget {
  final bool enabled;

  const _RefineUpscaleContent({required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);
    final modelsState = ref.watch(modelsProvider);
    final refiners = modelsState.checkpoints.where((m) =>
      m.name.toLowerCase().contains('refiner') ||
      m.name.toLowerCase().contains('sdxl')
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Refiner model dropdown
        _ParameterDropdown(
          label: 'Refiner Model',
          value: params.refinerModel ?? 'None',
          items: ['None', ...refiners.map((m) => m.displayName)],
          onChanged: (v) => paramsNotifier.setRefinerModel(v == 'None' ? null : v),
        ),
        const SizedBox(height: 8),
        // Upscale factor
        _ParameterSlider(
          label: 'Upscale',
          value: params.upscaleFactor,
          min: 1,
          max: 4,
          divisions: 12,
          decimals: 1,
          onChanged: (v) => paramsNotifier.setUpscaleFactor(v),
        ),
        const SizedBox(height: 8),
        // Refiner steps
        _ParameterSlider(
          label: 'Steps',
          value: params.refinerSteps.toDouble(),
          min: 1,
          max: 100,
          divisions: 99,
          onChanged: (v) => paramsNotifier.setRefinerSteps(v.round()),
        ),
      ],
    );
  }
}

/// ControlNet content
class _ControlNetContent extends ConsumerWidget {
  final bool enabled;

  const _ControlNetContent({required this.enabled});

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final base64String = base64Encode(file.bytes!);
          ref.read(generationParamsProvider.notifier).setControlNetImage(base64String);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);
    final modelsState = ref.watch(modelsProvider);
    final controlnets = modelsState.controlnets;
    final hasImage = params.controlNetImage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image drop zone / preview with file picker
        GestureDetector(
          onTap: () => _pickImage(context, ref),
          child: Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: hasImage ? colorScheme.primary : colorScheme.outlineVariant),
            ),
            child: hasImage
                ? Stack(
                    children: [
                      Center(
                        child: Text('Control image set', style: TextStyle(fontSize: 10, color: colorScheme.primary)),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: Icon(Icons.close, size: 14, color: colorScheme.error),
                          onPressed: () => paramsNotifier.setControlNetImage(null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Clear image',
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate, size: 20, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text('Click to select control image', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        // ControlNet model dropdown
        _ParameterDropdown(
          label: 'Model',
          value: params.controlNetModel ?? 'None',
          items: ['None', ...controlnets.map((m) => m.displayName)],
          onChanged: (v) => paramsNotifier.setControlNetModel(v == 'None' ? null : v),
        ),
        const SizedBox(height: 8),
        // Strength slider
        _ParameterSlider(
          label: 'Strength',
          value: params.controlNetStrength,
          min: 0,
          max: 2,
          divisions: 40,
          decimals: 2,
          onChanged: (v) => paramsNotifier.setControlNetStrength(v),
        ),
      ],
    );
  }
}

/// Image To Video content
class _ImageToVideoContent extends ConsumerWidget {
  final bool enabled;

  const _ImageToVideoContent({required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final modelsState = ref.watch(modelsProvider);
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);

    // Get all diffusion models for video
    final allDiffusionModels = modelsState.diffusionModels;

    // Filter for Wan high_noise models (for main dropdown when Wan selected)
    final wanHighNoiseModels = allDiffusionModels.where((m) {
      final name = m.name.toLowerCase();
      return name.contains('wan') && name.contains('high_noise');
    }).toList();

    final wanLowNoiseModels = allDiffusionModels.where((m) {
      final name = m.name.toLowerCase();
      return name.contains('wan') && name.contains('low_noise');
    }).toList();

    // Other video models (LTX, Mochi, Hunyuan, etc.)
    final otherVideoModels = allDiffusionModels.where((m) {
      final name = m.name.toLowerCase();
      return (name.contains('ltx') || name.contains('mochi') ||
              (name.contains('hunyuan') && name.contains('video')) ||
              name.contains('svd') || name.contains('kandinsky')) &&
             !name.contains('wan');
    }).toList();

    // Main model list: Wan high_noise + other video models
    final mainVideoModels = [...wanHighNoiseModels, ...otherVideoModels];

    // Check if current model is Wan (needs dual models) or LTX
    final currentModel = params.videoModel?.toLowerCase() ?? '';
    final isWanModel = currentModel.contains('wan');
    final isLTXModel = currentModel.contains('ltx');

    // Check if init image is set (I2V mode for LTX)
    final hasInitImage = params.initImage != null && params.initImage!.isNotEmpty;
    final isLTXI2V = isLTXModel && hasInitImage;

    // Enable video mode when this section is expanded
    if (enabled && !params.videoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        paramsNotifier.setVideoMode(true);
        if (params.videoModel == null && mainVideoModels.isNotEmpty) {
          final firstModel = mainVideoModels.first.name;
          paramsNotifier.setVideoModel(firstModel);
          // Auto-set high/low noise if Wan
          if (firstModel.toLowerCase().contains('wan')) {
            paramsNotifier.setHighNoiseModel(firstModel);
            final lowNoise = firstModel.replaceAll('high_noise', 'low_noise');
            paramsNotifier.setLowNoiseModel(lowNoise);
          }
        }
      });
    } else if (!enabled && params.videoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        paramsNotifier.setVideoMode(false);
      });
    }

    // Determine current model type for display
    // For LTX models, T2V/I2V is determined by whether an init image is present
    final isWanI2V = isWanModel && currentModel.contains('i2v');
    final isT2V = isLTXModel
        ? !hasInitImage  // LTX: T2V if no init image, I2V if has init image
        : (currentModel.contains('t2v') || (!currentModel.contains('i2v') && !currentModel.contains('svd')));

    String modelType;
    if (isWanModel) {
      modelType = isWanI2V ? 'Wan I2V (dual model)' : 'Wan T2V (dual model)';
    } else if (isLTXModel) {
      modelType = isLTXI2V ? 'LTX Image→Video' : 'LTX Text→Video';
    } else {
      modelType = isT2V ? 'Text→Video' : 'Image→Video';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isWanModel
                ? Colors.orange.withOpacity(0.2)
                : isLTXI2V
                    ? Colors.purple.withOpacity(0.2)
                    : (isT2V ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                modelType,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isWanModel
                      ? Colors.orange
                      : isLTXI2V
                          ? Colors.purple
                          : (isT2V ? Colors.green : Colors.blue),
                ),
              ),
              if (isLTXModel && !hasInitImage) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Add an Init Image to switch to I2V mode',
                  child: Icon(
                    Icons.info_outline,
                    size: 12,
                    color: Colors.green.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Main Video model dropdown with refresh button
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _ParameterDropdown(
                label: 'Video Model',
                value: params.videoModel ?? (mainVideoModels.isNotEmpty ? mainVideoModels.first.name : 'None'),
                items: mainVideoModels.isEmpty ? ['None'] : mainVideoModels.map((m) => m.name).toList(),
                onChanged: (v) {
                  paramsNotifier.setVideoModel(v);
                  // Apply model-specific defaults (CFG, resolution, etc.)
                  paramsNotifier.applyModelDefaults(v);
                  // Auto-set high/low noise for Wan
                  if (v.toLowerCase().contains('wan') && v.contains('high_noise')) {
                    paramsNotifier.setHighNoiseModel(v);
                    paramsNotifier.setLowNoiseModel(v.replaceAll('high_noise', 'low_noise'));
                  } else {
                    paramsNotifier.setHighNoiseModel(null);
                    paramsNotifier.setLowNoiseModel(null);
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: modelsState.isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                    )
                  : Icon(Icons.refresh, size: 18, color: colorScheme.primary),
              onPressed: modelsState.isLoading
                  ? null
                  : () => ref.read(modelsProvider.notifier).refresh(),
              tooltip: 'Refresh models',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        // Wan dual-model selectors (only show for Wan)
        if (isWanModel) ...[
          const SizedBox(height: 8),
          _ParameterDropdown(
            label: 'High Noise Model',
            value: params.highNoiseModel ?? (wanHighNoiseModels.isNotEmpty ? wanHighNoiseModels.first.name : 'None'),
            items: wanHighNoiseModels.isEmpty ? ['None'] : wanHighNoiseModels.map((m) => m.name).toList(),
            onChanged: (v) => paramsNotifier.setHighNoiseModel(v),
          ),
          const SizedBox(height: 8),
          _ParameterDropdown(
            label: 'Low Noise Model',
            value: params.lowNoiseModel ?? (wanLowNoiseModels.isNotEmpty ? wanLowNoiseModels.first.name : 'None'),
            items: wanLowNoiseModels.isEmpty ? ['None'] : wanLowNoiseModels.map((m) => m.name).toList(),
            onChanged: (v) => paramsNotifier.setLowNoiseModel(v),
          ),
        ],
        const SizedBox(height: 8),
        // Frames
        _ParameterSlider(
          label: 'Frames',
          value: params.frames.toDouble(),
          min: 1,
          max: 121,
          divisions: 30,
          onChanged: (v) => paramsNotifier.setFrames(v.round()),
        ),
        const SizedBox(height: 8),
        // Video Steps
        _ParameterSlider(
          label: 'Steps',
          value: params.steps.toDouble(),
          min: 1,
          max: 50,
          divisions: 49,
          onChanged: (v) => paramsNotifier.setSteps(v.round()),
        ),
        const SizedBox(height: 8),
        // Video CFG
        _ParameterSlider(
          label: 'CFG',
          value: params.cfgScale,
          min: 1,
          max: 20,
          divisions: 38,
          decimals: 1,
          onChanged: (v) => paramsNotifier.setCfgScale(v),
        ),
        const SizedBox(height: 8),
        // FPS
        _ParameterSlider(
          label: 'FPS',
          value: params.fps.toDouble(),
          min: 1,
          max: 60,
          divisions: 59,
          onChanged: (v) => paramsNotifier.setFps(v.round()),
        ),
        const SizedBox(height: 8),
        // LTX I2V specific options (show when LTX model with init image)
        if (isLTXI2V) ...[
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.movie_filter, size: 14, color: Colors.purple),
                    const SizedBox(width: 4),
                    Text(
                      'Image-to-Video Settings',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ParameterSlider(
                  label: 'Augment',
                  value: params.videoAugmentationLevel,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  decimals: 2,
                  onChanged: (v) => paramsNotifier.setVideoAugmentationLevel(v),
                ),
                Text(
                  'Higher values add more motion/variation from init image',
                  style: TextStyle(
                    fontSize: 9,
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
        // Format dropdown
        _ParameterDropdown(
          label: 'Format',
          value: params.videoFormat,
          items: ['webp', 'gif', 'mp4', 'webm'],
          onChanged: (v) => paramsNotifier.setVideoFormat(v),
        ),
      ],
    );
  }
}

/// Advanced Video content
class _AdvancedVideoContent extends ConsumerWidget {
  final bool enabled;

  const _AdvancedVideoContent({required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FPS - wired to params.fps
        _ParameterSlider(
          label: 'FPS',
          value: params.fps.toDouble(),
          min: 1,
          max: 60,
          divisions: 59,
          onChanged: (v) => paramsNotifier.setFps(v.round()),
        ),
        const SizedBox(height: 8),
        // Motion Bucket (SVD) - wired to extraParams svdmotionbucketid
        _ParameterSlider(
          label: 'Motion',
          value: ((params.extraParams['svdmotionbucketid'] as int?) ?? 127).toDouble(),
          min: 1,
          max: 255,
          divisions: 254,
          onChanged: (v) => paramsNotifier.setExtraParam('svdmotionbucketid', v.round()),
        ),
        const SizedBox(height: 8),
        // Min CFG - wired to extraParams svdmincfg
        _ParameterSlider(
          label: 'Min CFG',
          value: (params.extraParams['svdmincfg'] as double?) ?? 1.0,
          min: 0,
          max: 10,
          divisions: 20,
          decimals: 1,
          onChanged: (v) => paramsNotifier.setExtraParam('svdmincfg', v),
        ),
      ],
    );
  }
}

/// Video Extend content
class _VideoExtendContent extends ConsumerWidget {
  final bool enabled;

  const _VideoExtendContent({required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Frame Overlap - wired to extraParams videoframeoverlap
        _ParameterSlider(
          label: 'Overlap',
          value: ((params.extraParams['videoframeoverlap'] as int?) ?? 9).toDouble(),
          min: 1,
          max: 32,
          divisions: 31,
          onChanged: (v) => paramsNotifier.setExtraParam('videoframeoverlap', v.round()),
        ),
        const SizedBox(height: 8),
        // Extend format - wired to extraParams videoextendformat
        _ParameterDropdown(
          label: 'Format',
          value: (params.extraParams['videoextendformat'] as String?) ?? 'webp',
          items: const ['webp', 'gif', 'mp4', 'webm'],
          onChanged: (v) => paramsNotifier.setExtraParam('videoextendformat', v),
        ),
      ],
    );
  }
}

/// Advanced Model Addons content
class _AdvancedModelAddonsContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);
    final modelsState = ref.watch(modelsProvider);
    final vaes = modelsState.vaes;
    final textEncoders = modelsState.textEncoders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // VAE dropdown
        _ParameterDropdown(
          label: 'VAE',
          value: params.vae ?? 'Automatic',
          items: ['Automatic', 'None', ...vaes.map((m) => m.displayName)],
          onChanged: (v) => paramsNotifier.setVae(v == 'Automatic' ? null : v),
        ),
        const SizedBox(height: 8),
        // Text Encoder dropdown (CLIP/T5)
        if (textEncoders.isNotEmpty) ...[
          _ParameterDropdown(
            label: 'Text Encoder',
            value: params.textEncoder ?? 'Default',
            items: ['Default', ...textEncoders.map((m) => m.displayName)],
            onChanged: (v) => paramsNotifier.setTextEncoder(v == 'Default' ? null : v),
          ),
          const SizedBox(height: 8),
        ],
        // Precision dropdown
        _ParameterDropdown(
          label: 'Precision',
          value: params.precision ?? 'Automatic',
          items: ['Automatic', 'fp32', 'fp16', 'bf16', 'fp8'],
          onChanged: (v) => paramsNotifier.setPrecision(v == 'Automatic' ? null : v),
        ),
      ],
    );
  }
}
