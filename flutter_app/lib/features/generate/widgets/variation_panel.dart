import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/providers.dart';
import '../../../providers/lora_provider.dart';

/// Provider for variation generation state
final variationStateProvider = StateNotifierProvider<VariationStateNotifier, VariationState>((ref) {
  return VariationStateNotifier();
});

/// Variation generation state
class VariationState {
  final String? sourceImageUrl;
  final double strength;
  final int count;
  final bool isGenerating;

  const VariationState({
    this.sourceImageUrl,
    this.strength = 0.5,
    this.count = 4,
    this.isGenerating = false,
  });

  VariationState copyWith({
    String? sourceImageUrl,
    double? strength,
    int? count,
    bool? isGenerating,
  }) {
    return VariationState(
      sourceImageUrl: sourceImageUrl ?? this.sourceImageUrl,
      strength: strength ?? this.strength,
      count: count ?? this.count,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }
}

/// Variation state notifier
class VariationStateNotifier extends StateNotifier<VariationState> {
  VariationStateNotifier() : super(const VariationState());

  void setSourceImage(String? url) {
    state = state.copyWith(sourceImageUrl: url);
  }

  void setStrength(double strength) {
    state = state.copyWith(strength: strength.clamp(0.0, 1.0));
  }

  void setCount(int count) {
    state = state.copyWith(count: count.clamp(1, 16));
  }

  void setGenerating(bool isGenerating) {
    state = state.copyWith(isGenerating: isGenerating);
  }

  void clear() {
    state = const VariationState();
  }
}

/// Shows variation generation dialog
/// Takes an existing image and generates variations using img2img
class VariationDialog extends ConsumerStatefulWidget {
  final String sourceImageUrl;
  final GeneratedImage? sourceImage;

  const VariationDialog({
    super.key,
    required this.sourceImageUrl,
    this.sourceImage,
  });

  /// Show the variation dialog
  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
    GeneratedImage? sourceImage,
  }) {
    return showDialog(
      context: context,
      builder: (context) => VariationDialog(
        sourceImageUrl: imageUrl,
        sourceImage: sourceImage,
      ),
    );
  }

  @override
  ConsumerState<VariationDialog> createState() => _VariationDialogState();
}

class _VariationDialogState extends ConsumerState<VariationDialog> {
  double _strength = 0.5;
  int _count = 4;

  @override
  void initState() {
    super.initState();
    // Initialize from provider state if available
    final variationState = ref.read(variationStateProvider);
    _strength = variationState.strength;
    _count = variationState.count;
  }

  Future<void> _generateVariations() async {
    final variationNotifier = ref.read(variationStateProvider.notifier);
    final generationNotifier = ref.read(generationProvider.notifier);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);
    final loras = ref.read(selectedLorasProvider);

    // Set generating state
    variationNotifier.setGenerating(true);
    variationNotifier.setSourceImage(widget.sourceImageUrl);
    variationNotifier.setStrength(_strength);
    variationNotifier.setCount(_count);

    // Set up img2img parameters
    paramsNotifier.setInitImage(widget.sourceImageUrl);
    paramsNotifier.setInitImageCreativity(_strength);
    paramsNotifier.setBatchSize(_count);

    // If we have source image metadata, use its parameters
    if (widget.sourceImage != null) {
      final source = widget.sourceImage!;
      paramsNotifier.setPrompt(source.prompt);
      if (source.negativePrompt != null) {
        paramsNotifier.setNegativePrompt(source.negativePrompt!);
      }
      paramsNotifier.setWidth(source.params.width);
      paramsNotifier.setHeight(source.params.height);
      paramsNotifier.setSteps(source.params.steps);
      paramsNotifier.setCfgScale(source.params.cfgScale);
      // Use -1 for seed to get variations
      paramsNotifier.setSeed(-1);
      paramsNotifier.setSampler(source.params.sampler);
      paramsNotifier.setScheduler(source.params.scheduler);
      if (source.params.model != null) {
        paramsNotifier.setModel(source.params.model);
      }
    } else {
      // Use random seed for variations
      paramsNotifier.setSeed(-1);
    }

    // Close dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Start generation
    await generationNotifier.generate(
      ref.read(generationParamsProvider),
      loras: loras.isNotEmpty ? loras : null,
    );

    // Clear generating state
    variationNotifier.setGenerating(false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final variationState = ref.watch(variationStateProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Generate Variations'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source image preview
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.network(
                  widget.sourceImageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) => Center(
                    child: Icon(Icons.broken_image, color: colorScheme.error),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Variation strength slider
            Text(
              'Variation Strength',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Higher values create more different variations',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Similar',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: _strength,
                      min: 0.1,
                      max: 1.0,
                      divisions: 18,
                      label: _strength.toStringAsFixed(2),
                      onChanged: (value) => setState(() => _strength = value),
                    ),
                  ),
                ),
                Text(
                  'Different',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(_strength * 100).round()}% creativity',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Number of variations
            Text(
              'Number of Variations',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [1, 2, 4, 8, 9, 16].map((count) {
                final isSelected = _count == count;
                return Material(
                  color: isSelected
                      ? colorScheme.primary.withOpacity(0.2)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => setState(() => _count = count),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Info box about how it works
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Uses img2img with random seeds to create variations of your image while keeping the same style and composition.',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: variationState.isGenerating ? null : _generateVariations,
          icon: variationState.isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome, size: 18),
          label: Text(variationState.isGenerating
              ? 'Generating...'
              : 'Generate $_count Variation${_count > 1 ? 's' : ''}'),
        ),
      ],
    );
  }
}

/// Compact variation button for hover overlay on images
class VariationButton extends ConsumerWidget {
  final String imageUrl;
  final GeneratedImage? sourceImage;
  final double size;

  const VariationButton({
    super.key,
    required this.imageUrl,
    this.sourceImage,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.black.withOpacity(0.6),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () => VariationDialog.show(
          context,
          imageUrl: imageUrl,
          sourceImage: sourceImage,
        ),
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: 'Generate Variations',
          child: Padding(
            padding: EdgeInsets.all(size * 0.2),
            child: Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Variation panel widget for inline use (e.g., in parameters panel)
class VariationPanel extends ConsumerStatefulWidget {
  final String? sourceImageUrl;
  final GeneratedImage? sourceImage;

  const VariationPanel({
    super.key,
    this.sourceImageUrl,
    this.sourceImage,
  });

  @override
  ConsumerState<VariationPanel> createState() => _VariationPanelState();
}

class _VariationPanelState extends ConsumerState<VariationPanel> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final variationState = ref.watch(variationStateProvider);
    final variationNotifier = ref.read(variationStateProvider.notifier);

    final imageUrl = widget.sourceImageUrl ?? variationState.sourceImageUrl;

    if (imageUrl == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 40,
                color: colorScheme.outlineVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'Select an image to generate variations',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Right-click an image in history',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source image preview
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.broken_image, color: colorScheme.error, size: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Source Image',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () => variationNotifier.setSourceImage(null),
                      icon: Icon(Icons.close, size: 14, color: colorScheme.error),
                      label: Text(
                        'Clear',
                        style: TextStyle(fontSize: 11, color: colorScheme.error),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Strength slider
          _VariationSlider(
            label: 'Strength',
            value: variationState.strength,
            min: 0.1,
            max: 1.0,
            divisions: 18,
            onChanged: (v) => variationNotifier.setStrength(v),
          ),
          const SizedBox(height: 8),

          // Count selector
          Row(
            children: [
              Text(
                'Count',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              _CountButton(
                count: variationState.count,
                onCountChanged: (c) => variationNotifier.setCount(c),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Generate button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: variationState.isGenerating
                  ? null
                  : () => _generateVariations(context, ref, imageUrl),
              icon: variationState.isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(
                variationState.isGenerating
                    ? 'Generating...'
                    : 'Generate ${variationState.count} Variations',
                style: const TextStyle(fontSize: 12),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateVariations(BuildContext context, WidgetRef ref, String imageUrl) async {
    final variationState = ref.read(variationStateProvider);
    final variationNotifier = ref.read(variationStateProvider.notifier);
    final generationNotifier = ref.read(generationProvider.notifier);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);
    final loras = ref.read(selectedLorasProvider);

    // Set generating state
    variationNotifier.setGenerating(true);

    // Set up img2img parameters
    paramsNotifier.setInitImage(imageUrl);
    paramsNotifier.setInitImageCreativity(variationState.strength);
    paramsNotifier.setBatchSize(variationState.count);
    paramsNotifier.setSeed(-1); // Random seed for variations

    // If we have source image metadata, use its parameters
    if (widget.sourceImage != null) {
      final source = widget.sourceImage!;
      paramsNotifier.setPrompt(source.prompt);
      if (source.negativePrompt != null) {
        paramsNotifier.setNegativePrompt(source.negativePrompt!);
      }
      paramsNotifier.setWidth(source.params.width);
      paramsNotifier.setHeight(source.params.height);
      paramsNotifier.setSteps(source.params.steps);
      paramsNotifier.setCfgScale(source.params.cfgScale);
      paramsNotifier.setSampler(source.params.sampler);
      paramsNotifier.setScheduler(source.params.scheduler);
      if (source.params.model != null) {
        paramsNotifier.setModel(source.params.model);
      }
    }

    // Start generation
    await generationNotifier.generate(
      ref.read(generationParamsProvider),
      loras: loras.isNotEmpty ? loras : null,
    );

    // Clear generating state
    variationNotifier.setGenerating(false);
  }
}

/// Compact slider for variation settings
class _VariationSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double>? onChanged;

  const _VariationSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 55,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
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
          width: 35,
          child: Text(
            '${(value * 100).round()}%',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurface),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// Count selector with +/- buttons
class _CountButton extends StatelessWidget {
  final int count;
  final ValueChanged<int> onCountChanged;

  const _CountButton({
    required this.count,
    required this.onCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: count > 1 ? () => onCountChanged(count - 1) : null,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(
                Icons.remove,
                size: 14,
                color: count > 1 ? colorScheme.onSurface : colorScheme.outlineVariant,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          InkWell(
            onTap: count < 16 ? () => onCountChanged(count + 1) : null,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(
                Icons.add,
                size: 14,
                color: count < 16 ? colorScheme.onSurface : colorScheme.outlineVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
