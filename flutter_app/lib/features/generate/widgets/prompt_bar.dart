import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/providers.dart';
import '../../../providers/lora_provider.dart';

/// Prompt input bar - positioned above bottom tabs like ERI
class PromptBar extends ConsumerStatefulWidget {
  const PromptBar({super.key});

  @override
  ConsumerState<PromptBar> createState() => _PromptBarState();
}

class _PromptBarState extends ConsumerState<PromptBar> {
  final _promptController = TextEditingController();
  final _negativeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _promptController.addListener(_onPromptChanged);
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativeController.dispose();
    super.dispose();
  }

  void _onPromptChanged() {
    ref.read(generationParamsProvider.notifier).setPrompt(_promptController.text);
    // Trigger rebuild for word count
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final params = ref.watch(generationParamsProvider);
    final generationState = ref.watch(generationProvider);
    final isGenerating = generationState.isGenerating;

    // Sync controller with state
    if (_promptController.text != params.prompt && !_promptController.text.contains(params.prompt)) {
      _promptController.text = params.prompt;
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Positive prompt box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.primary.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: InputDecoration(
                      hintText: 'Type your prompt here... (or, drag/paste an image in to use Image Prompting)',
                      hintStyle: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                    maxLines: 2,
                    enabled: !isGenerating,
                  ),
                ),
                Text(
                  '${_promptController.text.split(' ').where((w) => w.isNotEmpty).length}/75',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Negative prompt box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
            ),
            child: TextField(
              controller: _negativeController,
              decoration: InputDecoration(
                hintText: 'Negative prompt (optional)...',
                hintStyle: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant.withOpacity(0.4)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              maxLines: 1,
              enabled: !isGenerating,
              onChanged: (v) => ref.read(generationParamsProvider.notifier).setNegativePrompt(v),
            ),
          ),
          const SizedBox(height: 12),
          // Bottom row: Model selector + Generate button
          Row(
            children: [
              // Model selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Model: ', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                    _ModelDropdown(),
                  ],
                ),
              ),
              const Spacer(),
              // Generate button
              SizedBox(
                height: 40,
                child: isGenerating
                    ? OutlinedButton.icon(
                        onPressed: () => ref.read(generationProvider.notifier).cancel(),
                        icon: const Icon(Icons.stop, size: 18),
                        label: Text('Cancel (${generationState.currentStep}/${generationState.totalSteps})'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: () {
                          print('DEBUG: prompt="${params.prompt}", model=${params.model}');
                          print('DEBUG: promptEmpty=${params.prompt.trim().isEmpty}, modelNull=${params.model == null}');
                          if (params.prompt.trim().isEmpty || params.model == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Need prompt: "${params.prompt}", model: ${params.model}')),
                            );
                            return;
                          }
                                // Ensure prompt is synced before generating
                                ref.read(generationParamsProvider.notifier).setPrompt(_promptController.text);
                                final loras = ref.read(selectedLorasProvider);
                                ref.read(generationProvider.notifier).generate(
                                  ref.read(generationParamsProvider),
                                  loras: loras,
                                );
                              },
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Generate'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
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

/// Model dropdown
class _ModelDropdown extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final params = ref.watch(generationParamsProvider);
    final modelsState = ref.watch(modelsProvider);

    final models = modelsState.checkpoints;
    final selectedName = params.model ?? 'Select model';
    final displayName = selectedName.contains('/')
        ? selectedName.split('/').last.replaceAll('.safetensors', '')
        : selectedName.replaceAll('.safetensors', '');

    return PopupMenuButton<String>(
      tooltip: 'Select model',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayName.length > 25 ? '${displayName.substring(0, 25)}...' : displayName,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
          ),
          Icon(Icons.arrow_drop_down, size: 18, color: colorScheme.onSurfaceVariant),
        ],
      ),
      itemBuilder: (context) => models.map((m) {
        final name = m.name.contains('/')
            ? m.name.split('/').last.replaceAll('.safetensors', '')
            : m.name.replaceAll('.safetensors', '');
        return PopupMenuItem<String>(
          value: m.name,
          height: 36,
          child: Text(name, style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
      onSelected: (value) {
        ref.read(generationParamsProvider.notifier).setModel(value);
      },
    );
  }
}
