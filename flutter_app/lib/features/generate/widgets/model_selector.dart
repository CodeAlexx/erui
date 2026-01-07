import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/providers.dart';

/// Model selector for generation
class GenerateModelSelector extends ConsumerWidget {
  final String? selectedModel;
  final ValueChanged<String?> onModelChanged;
  final bool enabled;

  const GenerateModelSelector({
    super.key,
    this.selectedModel,
    required this.onModelChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final modelsState = ref.watch(modelsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Model',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
            ),
            const Spacer(),
            if (modelsState.isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: enabled
                    ? () => ref.read(modelsProvider.notifier).refresh()
                    : null,
                tooltip: 'Refresh models',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Model dropdown
        DropdownButtonFormField<String>(
          value: selectedModel,
          isExpanded: true,
          decoration: const InputDecoration(
            hintText: 'Select a model',
          ),
          items: modelsState.checkpoints.map((model) {
            return DropdownMenuItem(
              value: model.name,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      model.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (model.modelClass != null)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        model.modelClass!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                            ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: enabled ? onModelChanged : null,
        ),
        // Model info
        if (selectedModel != null) ...[
          const SizedBox(height: 8),
          _ModelInfoCard(modelName: selectedModel!),
        ],
      ],
    );
  }
}

class _ModelInfoCard extends ConsumerWidget {
  final String modelName;

  const _ModelInfoCard({required this.modelName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final modelsState = ref.watch(modelsProvider);

    final model = modelsState.checkpoints
        .where((m) => m.name == modelName)
        .firstOrNull;

    if (model == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Text(
                'Model Info',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (model.modelClass != null)
            _InfoRow(label: 'Type', value: model.modelClass!),
          _InfoRow(label: 'Size', value: model.formattedSize),
          if (model.hash != null)
            _InfoRow(
              label: 'Hash',
              value: model.hash!.substring(0, 8),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
