import 'package:flutter/material.dart';

/// Slider parameter widget
class SliderParameter extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double)? valueLabel;
  final ValueChanged<double> onChanged;
  final bool enabled;

  const SliderParameter({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.valueLabel,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = valueLabel?.call(value) ?? value.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            Text(displayValue, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

/// Integer slider parameter
class IntSliderParameter extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const IntSliderParameter({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SliderParameter(
      label: label,
      value: value.toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      divisions: max - min,
      valueLabel: (v) => v.round().toString(),
      onChanged: (v) => onChanged(v.round()),
      enabled: enabled,
    );
  }
}

/// Dropdown parameter widget
class DropdownParameter<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool enabled;

  const DropdownParameter({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          isExpanded: true,
        ),
      ],
    );
  }
}

/// Text input parameter widget
class TextParameter extends StatelessWidget {
  final String label;
  final String? value;
  final String? hintText;
  final int maxLines;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const TextParameter({
    super.key,
    required this.label,
    this.value,
    this.hintText,
    this.maxLines = 1,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: value),
          decoration: InputDecoration(hintText: hintText),
          maxLines: maxLines,
          onChanged: onChanged,
          enabled: enabled,
        ),
      ],
    );
  }
}

/// Toggle parameter widget
class ToggleParameter extends StatelessWidget {
  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  const ToggleParameter({
    super.key,
    required this.label,
    this.description,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label),
      subtitle: description != null ? Text(description!) : null,
      value: value,
      onChanged: enabled ? onChanged : null,
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// Seed input parameter
class SeedParameter extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const SeedParameter({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<SeedParameter> createState() => _SeedParameterState();
}

class _SeedParameterState extends State<SeedParameter> {
  late TextEditingController _controller;
  bool _isRandom = true;

  @override
  void initState() {
    super.initState();
    _isRandom = widget.value < 0;
    _controller = TextEditingController(
      text: _isRandom ? '' : widget.value.toString(),
    );
  }

  @override
  void didUpdateWidget(SeedParameter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _isRandom = widget.value < 0;
      _controller.text = _isRandom ? '' : widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Seed', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: widget.enabled && !_isRandom,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: _isRandom ? 'Random' : 'Enter seed',
                ),
                onChanged: (value) {
                  final seed = int.tryParse(value);
                  if (seed != null) {
                    widget.onChanged(seed);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                _isRandom ? Icons.shuffle : Icons.pin,
                color: _isRandom
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              onPressed: widget.enabled
                  ? () {
                      setState(() {
                        _isRandom = !_isRandom;
                        if (_isRandom) {
                          widget.onChanged(-1);
                          _controller.clear();
                        } else {
                          _controller.text = '0';
                          widget.onChanged(0);
                        }
                      });
                    }
                  : null,
              tooltip: _isRandom ? 'Random seed' : 'Fixed seed',
            ),
            IconButton(
              icon: const Icon(Icons.casino),
              onPressed: widget.enabled && !_isRandom
                  ? () {
                      final seed = DateTime.now().millisecondsSinceEpoch %
                          (1 << 31 - 1);
                      _controller.text = seed.toString();
                      widget.onChanged(seed);
                    }
                  : null,
              tooltip: 'Generate random seed',
            ),
          ],
        ),
      ],
    );
  }
}

/// Resolution parameter widget
class ResolutionParameter extends StatelessWidget {
  final int width;
  final int height;
  final ValueChanged<int> onWidthChanged;
  final ValueChanged<int> onHeightChanged;
  final bool enabled;

  const ResolutionParameter({
    super.key,
    required this.width,
    required this.height,
    required this.onWidthChanged,
    required this.onHeightChanged,
    this.enabled = true,
  });

  static const List<_AspectRatio> presets = [
    _AspectRatio('1:1', 1024, 1024),
    _AspectRatio('16:9', 1344, 768),
    _AspectRatio('9:16', 768, 1344),
    _AspectRatio('4:3', 1152, 896),
    _AspectRatio('3:4', 896, 1152),
    _AspectRatio('3:2', 1216, 832),
    _AspectRatio('2:3', 832, 1216),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resolution', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        // Width slider
        IntSliderParameter(
          label: 'Width',
          value: width,
          min: 256,
          max: 2048,
          onChanged: onWidthChanged,
          enabled: enabled,
        ),
        // Height slider
        IntSliderParameter(
          label: 'Height',
          value: height,
          min: 256,
          max: 2048,
          onChanged: onHeightChanged,
          enabled: enabled,
        ),
        const SizedBox(height: 8),
        // Presets
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((preset) {
            final isSelected = preset.width == width && preset.height == height;
            return FilterChip(
              label: Text(preset.label),
              selected: isSelected,
              onSelected: enabled
                  ? (_) {
                      onWidthChanged(preset.width);
                      onHeightChanged(preset.height);
                    }
                  : null,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AspectRatio {
  final String label;
  final int width;
  final int height;

  const _AspectRatio(this.label, this.width, this.height);
}

/// Section header widget
class ParameterSection extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;
  final bool expanded;
  final ValueChanged<bool>? onExpansionChanged;

  const ParameterSection({
    super.key,
    required this.title,
    this.trailing,
    required this.children,
    bool? initiallyExpanded,
    bool expanded = true,
    this.onExpansionChanged,
  }) : expanded = initiallyExpanded ?? expanded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ExpansionTile(
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.primary,
            ),
      ),
      trailing: trailing,
      initiallyExpanded: expanded,
      onExpansionChanged: onExpansionChanged,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 16),
      children: children
          .map((child) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: child,
              ))
          .toList(),
    );
  }
}
