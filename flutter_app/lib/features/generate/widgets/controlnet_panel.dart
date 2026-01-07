import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../../providers/advanced_generation_provider.dart';
import '../../../widgets/widgets.dart';

/// ControlNet settings panel
class ControlNetPanel extends ConsumerWidget {
  const ControlNetPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(advancedGenerationProvider);
    final notifier = ref.read(advancedGenerationProvider.notifier);
    final controlNet = state.controlNet;

    final controlNetModels = ref.watch(controlNetModelsProvider);
    final preprocessors = ref.watch(preprocessorsProvider);

    return ParameterSection(
      title: 'ControlNet',
      initiallyExpanded: state.activeMode == 'controlnet',
      trailing: Switch(
        value: controlNet.isEnabled,
        onChanged: controlNet.model != null
            ? (enabled) {
                if (!enabled) notifier.clearControlNet();
              }
            : null,
      ),
      children: [
        // Model selector
        controlNetModels.when(
          data: (models) => DropdownButtonFormField<String>(
            value: controlNet.model,
            decoration: const InputDecoration(
              labelText: 'ControlNet Model',
              helperText: 'Select a ControlNet model',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('None')),
              ...models.map((m) => DropdownMenuItem(
                value: m.name,
                child: Text(m.name),
              )),
            ],
            onChanged: (value) => notifier.setControlNetModel(value),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error loading models: $e'),
        ),
        const SizedBox(height: 16),

        // Preprocessor selector
        preprocessors.when(
          data: (preps) => DropdownButtonFormField<String>(
            value: controlNet.preprocessor ?? 'none',
            decoration: const InputDecoration(
              labelText: 'Preprocessor',
              helperText: 'Image preprocessing before ControlNet',
            ),
            items: preps.map((p) => DropdownMenuItem(
              value: p.id,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.name),
                  Text(
                    p.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )).toList(),
            onChanged: (value) => notifier.setControlNetPreprocessor(value),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error loading preprocessors: $e'),
        ),
        const SizedBox(height: 16),

        // Image picker
        _ImagePicker(
          label: 'Control Image',
          image: controlNet.image,
          onImageSelected: (image) => notifier.setControlNetImage(image),
          onClear: () => notifier.setControlNetImage(null),
        ),
        const SizedBox(height: 16),

        // Strength slider
        SliderParameter(
          label: 'Strength',
          value: controlNet.strength,
          min: 0,
          max: 2,
          divisions: 40,
          valueLabel: (v) => v.toStringAsFixed(2),
          onChanged: (v) => notifier.setControlNetStrength(v),
        ),
        const SizedBox(height: 8),

        // Start/End percent
        Row(
          children: [
            Expanded(
              child: SliderParameter(
                label: 'Start %',
                value: controlNet.startPercent,
                min: 0,
                max: 1,
                divisions: 20,
                valueLabel: (v) => '${(v * 100).round()}%',
                onChanged: (v) => notifier.setControlNetStartPercent(v),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SliderParameter(
                label: 'End %',
                value: controlNet.endPercent,
                min: 0,
                max: 1,
                divisions: 20,
                valueLabel: (v) => '${(v * 100).round()}%',
                onChanged: (v) => notifier.setControlNetEndPercent(v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Img2Img settings panel
class Img2ImgPanel extends ConsumerWidget {
  const Img2ImgPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(advancedGenerationProvider);
    final notifier = ref.read(advancedGenerationProvider.notifier);
    final img2img = state.img2img;

    return ParameterSection(
      title: 'Image to Image',
      initiallyExpanded: state.activeMode == 'img2img',
      trailing: Switch(
        value: img2img.isEnabled,
        onChanged: img2img.initImage != null
            ? (enabled) {
                if (!enabled) notifier.clearImg2Img();
              }
            : null,
      ),
      children: [
        // Image picker
        _ImagePicker(
          label: 'Init Image',
          image: img2img.initImage,
          onImageSelected: (image) => notifier.setInitImage(image),
          onClear: () => notifier.clearImg2Img(),
        ),
        const SizedBox(height: 16),

        // Creativity slider (denoising strength)
        SliderParameter(
          label: 'Creativity',
          value: img2img.creativity,
          min: 0,
          max: 1,
          divisions: 20,
          valueLabel: (v) => v.toStringAsFixed(2),
          onChanged: (v) => notifier.setCreativity(v),
        ),
        const SizedBox(height: 4),
        Text(
          '0 = Follow original image, 1 = Ignore original completely',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 16),

        // Resize mode
        DropdownButtonFormField<String>(
          value: img2img.resizeMode,
          decoration: const InputDecoration(
            labelText: 'Resize Mode',
          ),
          items: const [
            DropdownMenuItem(value: 'resize', child: Text('Resize to fit')),
            DropdownMenuItem(value: 'crop', child: Text('Crop to fit')),
            DropdownMenuItem(value: 'fill', child: Text('Fill to fit')),
          ],
          onChanged: (value) {
            if (value != null) notifier.setResizeMode(value);
          },
        ),
      ],
    );
  }
}

/// Inpainting settings panel
class InpaintPanel extends ConsumerWidget {
  const InpaintPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(advancedGenerationProvider);
    final notifier = ref.read(advancedGenerationProvider.notifier);
    final inpaint = state.inpaint;

    return ParameterSection(
      title: 'Inpainting',
      initiallyExpanded: state.activeMode == 'inpaint',
      trailing: Switch(
        value: inpaint.isEnabled,
        onChanged: inpaint.initImage != null
            ? (enabled) {
                if (!enabled) notifier.clearInpaint();
              }
            : null,
      ),
      children: [
        // Init image
        _ImagePicker(
          label: 'Source Image',
          image: inpaint.initImage,
          onImageSelected: (image) => notifier.setInpaintInitImage(image),
          onClear: () => notifier.setInpaintInitImage(null),
        ),
        const SizedBox(height: 16),

        // Mask image
        _ImagePicker(
          label: 'Mask Image',
          image: inpaint.maskImage,
          onImageSelected: (image) => notifier.setMaskImage(image),
          onClear: () => notifier.setMaskImage(null),
          helperText: 'White = change, Black = preserve',
        ),
        const SizedBox(height: 16),

        // Creativity slider
        SliderParameter(
          label: 'Creativity',
          value: inpaint.creativity,
          min: 0,
          max: 1,
          divisions: 20,
          valueLabel: (v) => v.toStringAsFixed(2),
          onChanged: (v) => notifier.setInpaintCreativity(v),
        ),
        const SizedBox(height: 16),

        // Mask blur
        IntSliderParameter(
          label: 'Mask Blur',
          value: inpaint.maskBlur,
          min: 0,
          max: 64,
          onChanged: (v) => notifier.setMaskBlur(v),
        ),
        const SizedBox(height: 8),

        // Mask expand
        IntSliderParameter(
          label: 'Mask Expand',
          value: inpaint.maskExpand,
          min: -64,
          max: 64,
          onChanged: (v) => notifier.setMaskExpand(v),
        ),
        const SizedBox(height: 16),

        // Fill mode
        DropdownButtonFormField<String>(
          value: inpaint.fillMode,
          decoration: const InputDecoration(
            labelText: 'Masked Content',
          ),
          items: const [
            DropdownMenuItem(value: 'original', child: Text('Original')),
            DropdownMenuItem(value: 'noise', child: Text('Noise')),
            DropdownMenuItem(value: 'blur', child: Text('Blur')),
            DropdownMenuItem(value: 'nothing', child: Text('Nothing (latent)')),
          ],
          onChanged: (value) {
            if (value != null) notifier.setFillMode(value);
          },
        ),
      ],
    );
  }
}

/// Upscale settings panel
class UpscalePanel extends ConsumerWidget {
  const UpscalePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(advancedGenerationProvider);
    final notifier = ref.read(advancedGenerationProvider.notifier);
    final upscale = state.upscale;

    final upscalers = ref.watch(upscalersProvider);

    return ParameterSection(
      title: 'Upscaling',
      initiallyExpanded: false,
      trailing: Switch(
        value: upscale.isEnabled,
        onChanged: (enabled) {
          if (!enabled) notifier.clearUpscale();
        },
      ),
      children: [
        // Upscaler selector
        upscalers.when(
          data: (models) => DropdownButtonFormField<String>(
            value: upscale.upscaler,
            decoration: const InputDecoration(
              labelText: 'Upscaler',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('None')),
              ...models.map((m) => DropdownMenuItem(
                value: m.name,
                child: Text('${m.name} (${m.scale})'),
              )),
            ],
            onChanged: (value) => notifier.setUpscaler(value),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error loading upscalers: $e'),
        ),
        const SizedBox(height: 16),

        // Scale slider
        SliderParameter(
          label: 'Scale Factor',
          value: upscale.scale,
          min: 1,
          max: 8,
          divisions: 14,
          valueLabel: (v) => '${v.toStringAsFixed(1)}x',
          onChanged: (v) => notifier.setUpscaleScale(v),
        ),
        const SizedBox(height: 8),

        // Tile size
        IntSliderParameter(
          label: 'Tile Size',
          value: upscale.tileSize,
          min: 128,
          max: 1024,
          onChanged: (v) => notifier.setUpscaleTileSize(v),
        ),
      ],
    );
  }
}

/// Refiner settings panel
class RefinerPanel extends ConsumerWidget {
  const RefinerPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(advancedGenerationProvider);
    final notifier = ref.read(advancedGenerationProvider.notifier);
    final refiner = state.refiner;

    return ParameterSection(
      title: 'Refiner (SDXL)',
      initiallyExpanded: false,
      trailing: Switch(
        value: refiner.isEnabled,
        onChanged: (enabled) {
          if (!enabled) notifier.clearRefiner();
        },
      ),
      children: [
        // Model selector (would need SD models provider)
        TextField(
          decoration: const InputDecoration(
            labelText: 'Refiner Model',
            hintText: 'Enter refiner model name',
          ),
          onChanged: (value) => notifier.setRefinerModel(value.isEmpty ? null : value),
        ),
        const SizedBox(height: 16),

        // Switch point
        SliderParameter(
          label: 'Switch At',
          value: refiner.switchAt,
          min: 0,
          max: 1,
          divisions: 20,
          valueLabel: (v) => '${(v * 100).round()}%',
          onChanged: (v) => notifier.setRefinerSwitchAt(v),
        ),
        const SizedBox(height: 4),
        Text(
          'Percentage of steps before switching to refiner',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

/// Image picker widget
class _ImagePicker extends StatelessWidget {
  final String label;
  final Uint8List? image;
  final ValueChanged<Uint8List?> onImageSelected;
  final VoidCallback? onClear;
  final String? helperText;

  const _ImagePicker({
    required this.label,
    this.image,
    required this.onImageSelected,
    this.onClear,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.outline,
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (image != null)
          Stack(
            children: [
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    image!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filled(
                  icon: const Icon(Icons.close),
                  onPressed: onClear,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.errorContainer,
                    foregroundColor: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          )
        else
          InkWell(
            onTap: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.image,
              );
              if (result != null && result.files.single.path != null) {
                final bytes = await File(result.files.single.path!).readAsBytes();
                onImageSelected(bytes);
              }
            },
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, color: colorScheme.outline),
                  const SizedBox(height: 8),
                  Text(
                    'Click to select image',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
