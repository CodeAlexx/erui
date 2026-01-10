import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/storage_service.dart';
import '../models/eri_workflow_models.dart';
import 'param_widget_factory.dart';

/// Collapsible section for grouping workflow parameters
/// Remembers expansion state across sessions
class ParamGroupSection extends ConsumerStatefulWidget {
  final String groupName;
  final List<EriWorkflowParam> params;
  final Map<String, dynamic> currentValues;
  final Function(String key, dynamic value) onParamChanged;
  final bool initiallyExpanded;

  const ParamGroupSection({
    super.key,
    required this.groupName,
    required this.params,
    required this.currentValues,
    required this.onParamChanged,
    this.initiallyExpanded = true,
  });

  @override
  ConsumerState<ParamGroupSection> createState() => _ParamGroupSectionState();
}

class _ParamGroupSectionState extends ConsumerState<ParamGroupSection> {
  late bool _isExpanded;
  static const String _storageKeyPrefix = 'workflow_param_group_';

  @override
  void initState() {
    super.initState();
    _loadExpansionState();
  }

  void _loadExpansionState() {
    final key = '$_storageKeyPrefix${widget.groupName}';
    final stored = StorageService.getBool(key);
    _isExpanded = stored ?? widget.initiallyExpanded;
  }

  void _saveExpansionState(bool expanded) {
    final key = '$_storageKeyPrefix${widget.groupName}';
    StorageService.setBool(key, expanded);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Filter to only visible parameters
    final visibleParams = widget.params.where((p) => p.visible).toList();

    if (visibleParams.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
            _saveExpansionState(_isExpanded);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.groupName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                // Parameter count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${visibleParams.length}',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Content
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildParamWidgets(context),
            ),
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  List<Widget> _buildParamWidgets(BuildContext context) {
    final visibleParams = widget.params.where((p) => p.visible).toList();
    final widgets = <Widget>[];

    for (int i = 0; i < visibleParams.length; i++) {
      final param = visibleParams[i];
      final value = widget.currentValues[param.id] ?? param.defaultValue;

      widgets.add(
        ParamWidgetFactory.buildParamWidget(
          param: param,
          value: value,
          onChange: (newValue) => widget.onParamChanged(param.id, newValue),
          context: context,
          ref: ref,
        ),
      );

      // Add spacing between params (except last)
      if (i < visibleParams.length - 1) {
        widgets.add(const SizedBox(height: 12));
      }
    }

    return widgets;
  }
}

/// A simpler collapsible section using ExpansionTile
/// Alternative implementation that uses Material ExpansionTile
class ParamGroupExpansionTile extends ConsumerStatefulWidget {
  final String groupName;
  final List<EriWorkflowParam> params;
  final Map<String, dynamic> currentValues;
  final Function(String key, dynamic value) onParamChanged;
  final bool initiallyExpanded;

  const ParamGroupExpansionTile({
    super.key,
    required this.groupName,
    required this.params,
    required this.currentValues,
    required this.onParamChanged,
    this.initiallyExpanded = true,
  });

  @override
  ConsumerState<ParamGroupExpansionTile> createState() => _ParamGroupExpansionTileState();
}

class _ParamGroupExpansionTileState extends ConsumerState<ParamGroupExpansionTile> {
  late bool _isExpanded;
  static const String _storageKeyPrefix = 'workflow_param_group_tile_';

  @override
  void initState() {
    super.initState();
    _loadExpansionState();
  }

  void _loadExpansionState() {
    final key = '$_storageKeyPrefix${widget.groupName}';
    final stored = StorageService.getBool(key);
    _isExpanded = stored ?? widget.initiallyExpanded;
  }

  void _saveExpansionState(bool expanded) {
    final key = '$_storageKeyPrefix${widget.groupName}';
    StorageService.setBool(key, expanded);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleParams = widget.params.where((p) => p.visible).toList();

    if (visibleParams.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      initiallyExpanded: _isExpanded,
      onExpansionChanged: (expanded) {
        setState(() {
          _isExpanded = expanded;
        });
        _saveExpansionState(expanded);
      },
      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.1),
      collapsedBackgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.05),
      iconColor: colorScheme.primary,
      collapsedIconColor: colorScheme.onSurfaceVariant,
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.groupName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${visibleParams.length}',
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
      children: _buildParamWidgets(context),
    );
  }

  List<Widget> _buildParamWidgets(BuildContext context) {
    final visibleParams = widget.params.where((p) => p.visible).toList();
    final widgets = <Widget>[];

    for (int i = 0; i < visibleParams.length; i++) {
      final param = visibleParams[i];
      final value = widget.currentValues[param.id] ?? param.defaultValue;

      widgets.add(
        ParamWidgetFactory.buildParamWidget(
          param: param,
          value: value,
          onChange: (newValue) => widget.onParamChanged(param.id, newValue),
          context: context,
          ref: ref,
        ),
      );

      if (i < visibleParams.length - 1) {
        widgets.add(const SizedBox(height: 12));
      }
    }

    return widgets;
  }
}

/// Ungrouped parameters section for params without a group
class UngroupedParamsSection extends ConsumerWidget {
  final List<EriWorkflowParam> params;
  final Map<String, dynamic> currentValues;
  final Function(String key, dynamic value) onParamChanged;

  const UngroupedParamsSection({
    super.key,
    required this.params,
    required this.currentValues,
    required this.onParamChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleParams = params.where((p) => p.visible && (p.group == null || p.group!.isEmpty)).toList();

    if (visibleParams.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildParamWidgets(context, ref, visibleParams),
      ),
    );
  }

  List<Widget> _buildParamWidgets(BuildContext context, WidgetRef ref, List<EriWorkflowParam> visibleParams) {
    final widgets = <Widget>[];

    for (int i = 0; i < visibleParams.length; i++) {
      final param = visibleParams[i];
      final value = currentValues[param.id] ?? param.defaultValue;

      widgets.add(
        ParamWidgetFactory.buildParamWidget(
          param: param,
          value: value,
          onChange: (newValue) => onParamChanged(param.id, newValue),
          context: context,
          ref: ref,
        ),
      );

      if (i < visibleParams.length - 1) {
        widgets.add(const SizedBox(height: 12));
      }
    }

    return widgets;
  }
}
