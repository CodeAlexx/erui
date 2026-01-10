import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/providers.dart';
import '../models/eri_workflow_models.dart';

/// Factory class for building parameter widgets based on type
class ParamWidgetFactory {
  /// Build appropriate widget for the given parameter
  /// Returns a widget that displays and allows editing of the parameter value
  static Widget buildParamWidget({
    required EriWorkflowParam param,
    required dynamic value,
    required Function(dynamic) onChange,
    required BuildContext context,
    WidgetRef? ref,
  }) {
    switch (param.type.toLowerCase()) {
      case 'text':
      case 'string':
        return _TextParamWidget(
          param: param,
          value: value,
          onChange: onChange,
        );

      case 'dropdown':
      case 'select':
      case 'enum':
        return _DropdownParamWidget(
          param: param,
          value: value,
          onChange: onChange,
        );

      case 'integer':
      case 'int':
        return _IntegerParamWidget(
          param: param,
          value: value,
          onChange: onChange,
        );

      case 'decimal':
      case 'float':
      case 'double':
      case 'number':
        return _DecimalParamWidget(
          param: param,
          value: value,
          onChange: onChange,
        );

      case 'boolean':
      case 'bool':
      case 'toggle':
        return _BooleanParamWidget(
          param: param,
          value: value,
          onChange: onChange,
        );

      case 'image':
        return _ImageParamWidget(
          param: param,
          value: value,
          onChange: onChange,
        );

      case 'model':
        if (ref != null) {
          return _ModelParamWidget(
            param: param,
            value: value,
            onChange: onChange,
            ref: ref,
          );
        }
        return _TextParamWidget(
          param: param,
          value: value,
          onChange: onChange,
        );

      case 'multiline':
      case 'textarea':
        return _MultilineTextParamWidget(
          param: param,
          value: value,
          onChange: onChange,
        );

      case 'color':
        return _ColorParamWidget(
          param: param,
          value: value,
          onChange: onChange,
        );

      default:
        // Default to text input for unknown types
        return _TextParamWidget(
          param: param,
          value: value,
          onChange: onChange,
        );
    }
  }
}

/// Text input parameter widget
class _TextParamWidget extends StatefulWidget {
  final EriWorkflowParam param;
  final dynamic value;
  final Function(dynamic) onChange;

  const _TextParamWidget({
    required this.param,
    required this.value,
    required this.onChange,
  });

  @override
  State<_TextParamWidget> createState() => _TextParamWidgetState();
}

class _TextParamWidgetState extends State<_TextParamWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(_TextParamWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value?.toString() != _controller.text) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.param.name,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            hintText: widget.param.description ?? 'Enter ${widget.param.name}',
          ),
          style: const TextStyle(fontSize: 13),
          onChanged: widget.onChange,
        ),
        if (widget.param.description != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.param.description!,
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
          ),
        ],
      ],
    );
  }
}

/// Multiline text input parameter widget
class _MultilineTextParamWidget extends StatefulWidget {
  final EriWorkflowParam param;
  final dynamic value;
  final Function(dynamic) onChange;

  const _MultilineTextParamWidget({
    required this.param,
    required this.value,
    required this.onChange,
  });

  @override
  State<_MultilineTextParamWidget> createState() => _MultilineTextParamWidgetState();
}

class _MultilineTextParamWidgetState extends State<_MultilineTextParamWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(_MultilineTextParamWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value?.toString() != _controller.text) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.param.name,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            hintText: widget.param.description ?? 'Enter ${widget.param.name}',
          ),
          style: const TextStyle(fontSize: 13),
          maxLines: 4,
          onChanged: widget.onChange,
        ),
      ],
    );
  }
}

/// Dropdown select parameter widget
class _DropdownParamWidget extends StatelessWidget {
  final EriWorkflowParam param;
  final dynamic value;
  final Function(dynamic) onChange;

  const _DropdownParamWidget({
    required this.param,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = param.values ?? [];
    final currentValue = value?.toString();
    final validValue = items.contains(currentValue) ? currentValue : (items.isNotEmpty ? items.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          param.name,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: validValue,
              isExpanded: true,
              isDense: true,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
              items: items.map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              )).toList(),
              onChanged: (v) => onChange(v),
            ),
          ),
        ),
        if (param.description != null) ...[
          const SizedBox(height: 2),
          Text(
            param.description!,
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
          ),
        ],
      ],
    );
  }
}

/// Integer slider parameter widget
class _IntegerParamWidget extends StatelessWidget {
  final EriWorkflowParam param;
  final dynamic value;
  final Function(dynamic) onChange;

  const _IntegerParamWidget({
    required this.param,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final min = (param.min ?? 0).toDouble();
    final max = (param.max ?? 100).toDouble();
    final currentValue = ((value ?? param.defaultValue ?? min) as num).toDouble().clamp(min, max);
    final divisions = (max - min).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                param.name,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ),
            Text(
              currentValue.round().toString(),
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: currentValue,
            min: min,
            max: max,
            divisions: divisions > 0 ? divisions : null,
            onChanged: (v) => onChange(v.round()),
          ),
        ),
        if (param.description != null)
          Text(
            param.description!,
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
          ),
      ],
    );
  }
}

/// Decimal slider parameter widget
class _DecimalParamWidget extends StatelessWidget {
  final EriWorkflowParam param;
  final dynamic value;
  final Function(dynamic) onChange;

  const _DecimalParamWidget({
    required this.param,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final min = (param.min ?? 0).toDouble();
    final max = (param.max ?? 1).toDouble();
    final step = (param.step ?? 0.01).toDouble();
    final currentValue = ((value ?? param.defaultValue ?? min) as num).toDouble().clamp(min, max);
    final divisions = step > 0 ? ((max - min) / step).round() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                param.name,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ),
            Text(
              currentValue.toStringAsFixed(2),
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: currentValue,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChange,
          ),
        ),
        if (param.description != null)
          Text(
            param.description!,
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
          ),
      ],
    );
  }
}

/// Boolean switch parameter widget
class _BooleanParamWidget extends StatelessWidget {
  final EriWorkflowParam param;
  final dynamic value;
  final Function(dynamic) onChange;

  const _BooleanParamWidget({
    required this.param,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentValue = value == true || value == 'true' || value == 1;

    return SwitchListTile(
      title: Text(
        param.name,
        style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
      ),
      subtitle: param.description != null
          ? Text(
              param.description!,
              style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
            )
          : null,
      value: currentValue,
      onChanged: onChange,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// Image picker parameter widget
class _ImageParamWidget extends StatelessWidget {
  final EriWorkflowParam param;
  final dynamic value;
  final Function(dynamic) onChange;

  const _ImageParamWidget({
    required this.param,
    required this.value,
    required this.onChange,
  });

  Future<void> _pickImage(BuildContext context) async {
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
          onChange(base64String);
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = value != null && value.toString().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          param.name,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _pickImage(context),
          child: Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasImage ? colorScheme.primary : colorScheme.outlineVariant,
              ),
            ),
            child: hasImage
                ? Stack(
                    children: [
                      Center(
                        child: _buildImagePreview(value.toString(), colorScheme),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: Icon(Icons.close, size: 16, color: colorScheme.error),
                          onPressed: () => onChange(null),
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
                        Text(
                          'Click to select image',
                          style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        if (param.description != null) ...[
          const SizedBox(height: 2),
          Text(
            param.description!,
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
          ),
        ],
      ],
    );
  }

  Widget _buildImagePreview(String imageData, ColorScheme colorScheme) {
    try {
      // Try to decode as base64
      if (imageData.startsWith('data:')) {
        imageData = imageData.split(',').last;
      }
      final bytes = base64Decode(imageData);
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(
          bytes,
          height: 70,
          fit: BoxFit.contain,
        ),
      );
    } catch (e) {
      // If not base64, show placeholder
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image, size: 16, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text('Image set', style: TextStyle(fontSize: 11, color: colorScheme.primary)),
        ],
      );
    }
  }
}

/// Model selector parameter widget
class _ModelParamWidget extends ConsumerWidget {
  final EriWorkflowParam param;
  final dynamic value;
  final Function(dynamic) onChange;
  final WidgetRef ref;

  const _ModelParamWidget({
    required this.param,
    required this.value,
    required this.onChange,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final modelsState = ref.watch(modelsProvider);
    final checkpoints = modelsState.checkpoints;
    final currentValue = value?.toString();
    final modelNames = checkpoints.map((m) => m.name).toList();
    final validValue = modelNames.contains(currentValue) ? currentValue : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                param.name,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ),
            if (modelsState.isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: Icon(Icons.refresh, size: 14, color: colorScheme.primary),
                onPressed: () => ref.read(modelsProvider.notifier).refresh(),
                tooltip: 'Refresh models',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: validValue,
              isExpanded: true,
              isDense: true,
              hint: const Text('Select model'),
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
              items: checkpoints.map((model) => DropdownMenuItem(
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
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          model.modelClass!,
                          style: TextStyle(
                            fontSize: 9,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              )).toList(),
              onChanged: (v) => onChange(v),
            ),
          ),
        ),
        if (param.description != null) ...[
          const SizedBox(height: 2),
          Text(
            param.description!,
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
          ),
        ],
      ],
    );
  }
}

/// Color picker parameter widget
class _ColorParamWidget extends StatelessWidget {
  final EriWorkflowParam param;
  final dynamic value;
  final Function(dynamic) onChange;

  const _ColorParamWidget({
    required this.param,
    required this.value,
    required this.onChange,
  });

  Color _parseColor(dynamic value) {
    if (value == null) return Colors.white;
    if (value is Color) return value;
    if (value is int) return Color(value);
    if (value is String) {
      final hex = value.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentColor = _parseColor(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          param.name,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            final color = await showDialog<Color>(
              context: context,
              builder: (context) => _SimpleColorPicker(initialColor: currentColor),
            );
            if (color != null) {
              onChange(color.value);
            }
          },
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: currentColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Center(
              child: Text(
                '#${currentColor.value.toRadixString(16).substring(2).toUpperCase()}',
                style: TextStyle(
                  fontSize: 11,
                  color: currentColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
        ),
        if (param.description != null) ...[
          const SizedBox(height: 2),
          Text(
            param.description!,
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
          ),
        ],
      ],
    );
  }
}

/// Simple color picker dialog
class _SimpleColorPicker extends StatefulWidget {
  final Color initialColor;

  const _SimpleColorPicker({required this.initialColor});

  @override
  State<_SimpleColorPicker> createState() => _SimpleColorPickerState();
}

class _SimpleColorPickerState extends State<_SimpleColorPicker> {
  late Color _selectedColor;

  static const List<Color> _presetColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Color'),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _presetColors.map((color) {
          final isSelected = _selectedColor.value == color.value;
          return GestureDetector(
            onTap: () => setState(() => _selectedColor = color),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    )
                  : null,
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedColor),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
