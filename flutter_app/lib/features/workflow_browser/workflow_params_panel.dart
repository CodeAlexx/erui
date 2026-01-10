import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/eri_workflow_models.dart';
import 'param_widgets/param_group_section.dart';
import 'providers/workflow_execution_provider.dart';

/// Dynamic parameter panel for workflow custom parameters
/// Renders parameters grouped by their group name with core params always visible
class WorkflowParamsPanel extends ConsumerWidget {
  final EriWorkflow workflow;
  final VoidCallback? onExecute;
  final VoidCallback? onCancel;

  const WorkflowParamsPanel({
    super.key,
    required this.workflow,
    this.onExecute,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final executionState = ref.watch(workflowExecutionProvider);
    final currentValues = executionState.currentParams;
    final isExecuting = executionState.isExecuting;

    // Group parameters by group name
    final params = workflow.parameters;
    final groupedParams = _groupParameters(params);

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Header
          _WorkflowHeader(
            workflow: workflow,
            isExecuting: isExecuting,
            onReset: () => ref.read(workflowExecutionProvider.notifier).resetToDefaults(),
          ),

          // Error display
          if (executionState.error != null)
            _ErrorBanner(
              error: executionState.error!,
              onDismiss: () => ref.read(workflowExecutionProvider.notifier).clearError(),
            ),

          // Progress indicator
          if (isExecuting)
            LinearProgressIndicator(
              value: executionState.progress > 0 ? executionState.progress : null,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),

          // Scrollable parameter sections
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Core Parameters - always visible at top
                _CoreParamsSection(
                  prompt: currentValues['prompt']?.toString() ?? '',
                  negativePrompt: currentValues['negativePrompt']?.toString() ??
                      currentValues['negative_prompt']?.toString() ?? '',
                  seed: (currentValues['seed'] as num?)?.toInt() ?? -1,
                  onPromptChanged: isExecuting
                      ? null
                      : (v) => ref.read(workflowExecutionProvider.notifier).updateParam('prompt', v),
                  onNegativePromptChanged: isExecuting
                      ? null
                      : (v) => ref.read(workflowExecutionProvider.notifier).updateParam('negativePrompt', v),
                  onSeedChanged: isExecuting
                      ? null
                      : (v) => ref.read(workflowExecutionProvider.notifier).updateParam('seed', v),
                ),

                // Ungrouped parameters (params without a group)
                UngroupedParamsSection(
                  params: params.where((p) => p.group == null || p.group!.isEmpty).toList(),
                  currentValues: currentValues,
                  onParamChanged: (key, value) =>
                      ref.read(workflowExecutionProvider.notifier).updateParam(key, value),
                ),

                // Grouped parameters
                for (final entry in groupedParams.entries)
                  if (entry.key.isNotEmpty)
                    ParamGroupSection(
                      groupName: entry.key,
                      params: entry.value,
                      currentValues: currentValues,
                      onParamChanged: (key, value) =>
                          ref.read(workflowExecutionProvider.notifier).updateParam(key, value),
                    ),
              ],
            ),
          ),

          // Execute button
          _ExecuteButton(
            isExecuting: isExecuting,
            progress: executionState.progress,
            onExecute: onExecute ??
                () => ref.read(workflowExecutionProvider.notifier).executeWorkflow(),
            onCancel: onCancel ??
                () => ref.read(workflowExecutionProvider.notifier).cancelExecution(),
          ),
        ],
      ),
    );
  }

  /// Group parameters by their group name
  Map<String, List<EriWorkflowParam>> _groupParameters(List<EriWorkflowParam> params) {
    final grouped = <String, List<EriWorkflowParam>>{};

    for (final param in params) {
      final groupName = param.group ?? '';
      grouped.putIfAbsent(groupName, () => []);
      grouped[groupName]!.add(param);
    }

    return grouped;
  }
}

/// Header showing workflow name and description
class _WorkflowHeader extends StatelessWidget {
  final EriWorkflow workflow;
  final bool isExecuting;
  final VoidCallback onReset;

  const _WorkflowHeader({
    required this.workflow,
    required this.isExecuting,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.account_tree, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workflow.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (workflow.description != null && workflow.description!.isNotEmpty)
                  Text(
                    workflow.description!,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, size: 18, color: colorScheme.primary),
            onPressed: isExecuting ? null : onReset,
            tooltip: 'Reset to defaults',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// Error banner widget
class _ErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback onDismiss;

  const _ErrorBanner({
    required this.error,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 12),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: colorScheme.error),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// Core parameters section (prompt, negative prompt, seed)
class _CoreParamsSection extends StatefulWidget {
  final String prompt;
  final String negativePrompt;
  final int seed;
  final ValueChanged<String>? onPromptChanged;
  final ValueChanged<String>? onNegativePromptChanged;
  final ValueChanged<int>? onSeedChanged;

  const _CoreParamsSection({
    required this.prompt,
    required this.negativePrompt,
    required this.seed,
    this.onPromptChanged,
    this.onNegativePromptChanged,
    this.onSeedChanged,
  });

  @override
  State<_CoreParamsSection> createState() => _CoreParamsSectionState();
}

class _CoreParamsSectionState extends State<_CoreParamsSection> {
  late TextEditingController _promptController;
  late TextEditingController _negativePromptController;
  late TextEditingController _seedController;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.prompt);
    _negativePromptController = TextEditingController(text: widget.negativePrompt);
    _seedController = TextEditingController(text: widget.seed.toString());
  }

  @override
  void didUpdateWidget(_CoreParamsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prompt != _promptController.text) {
      _promptController.text = widget.prompt;
    }
    if (widget.negativePrompt != _negativePromptController.text) {
      _negativePromptController.text = widget.negativePrompt;
    }
    final seedText = widget.seed.toString();
    if (seedText != _seedController.text) {
      _seedController.text = seedText;
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativePromptController.dispose();
    _seedController.dispose();
    super.dispose();
  }

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
          // Section header
          Row(
            children: [
              Icon(Icons.edit, size: 14, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Prompts',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Prompt
          Text(
            'Prompt',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _promptController,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              hintText: 'Enter your prompt...',
              hintStyle: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
            ),
            style: const TextStyle(fontSize: 12),
            maxLines: 3,
            enabled: widget.onPromptChanged != null,
            onChanged: widget.onPromptChanged,
          ),
          const SizedBox(height: 10),

          // Negative prompt
          Text(
            'Negative Prompt',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _negativePromptController,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              hintText: 'Things to avoid...',
              hintStyle: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
            ),
            style: const TextStyle(fontSize: 12),
            maxLines: 2,
            enabled: widget.onNegativePromptChanged != null,
            onChanged: widget.onNegativePromptChanged,
          ),
          const SizedBox(height: 10),

          // Seed
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  'Seed',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _seedController,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    hintText: '-1 for random',
                    hintStyle: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                  ),
                  style: const TextStyle(fontSize: 12),
                  keyboardType: TextInputType.number,
                  enabled: widget.onSeedChanged != null,
                  onSubmitted: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null) {
                      widget.onSeedChanged?.call(parsed);
                    }
                  },
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.casino, size: 16, color: colorScheme.primary),
                onPressed: widget.onSeedChanged != null
                    ? () {
                        widget.onSeedChanged!(-1);
                        _seedController.text = '-1';
                      }
                    : null,
                tooltip: 'Random seed',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Execute button with progress indication
class _ExecuteButton extends StatelessWidget {
  final bool isExecuting;
  final double progress;
  final VoidCallback onExecute;
  final VoidCallback onCancel;

  const _ExecuteButton({
    required this.isExecuting,
    required this.progress,
    required this.onExecute,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: isExecuting
            ? ElevatedButton.icon(
                onPressed: onCancel,
                icon: const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                label: Text(progress > 0
                    ? 'Cancel (${(progress * 100).toInt()}%)'
                    : 'Cancel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor: colorScheme.onErrorContainer,
                ),
              )
            : ElevatedButton.icon(
                onPressed: onExecute,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Execute Workflow'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
              ),
      ),
    );
  }
}
