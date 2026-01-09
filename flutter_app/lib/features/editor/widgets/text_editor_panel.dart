import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/text_clip_models.dart';
import '../providers/text_clips_provider.dart';

/// Panel for editing text clip properties
class TextEditorPanel extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const TextEditorPanel({super.key, this.onClose});

  @override
  ConsumerState<TextEditorPanel> createState() => _TextEditorPanelState();
}

class _TextEditorPanelState extends ConsumerState<TextEditorPanel> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedClip = ref.watch(selectedTextClipProvider);

    // Update text controller when selection changes
    if (selectedClip != null && _textController.text != selectedClip.text) {
      _textController.text = selectedClip.text;
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(context),

          if (selectedClip == null)
            _buildEmptyState(context)
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Text input
                    _buildTextInput(context, selectedClip),

                    const SizedBox(height: 16),

                    // Font settings
                    _buildFontSection(context, selectedClip),

                    const SizedBox(height: 16),

                    // Color settings
                    _buildColorSection(context, selectedClip),

                    const SizedBox(height: 16),

                    // Position
                    _buildPositionSection(context, selectedClip),

                    const SizedBox(height: 16),

                    // Animation
                    _buildAnimationSection(context, selectedClip),

                    const SizedBox(height: 16),

                    // Background
                    _buildBackgroundSection(context, selectedClip),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.text_fields, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Text Editor',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.text_fields,
              size: 48,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a text clip',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInput(BuildContext context, TextClip clip) {
    final colorScheme = Theme.of(context).colorScheme;

    return _Section(
      title: 'Content',
      child: TextField(
        controller: _textController,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Enter text...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.all(12),
        ),
        onChanged: (text) {
          ref.read(textClipsProvider.notifier).updateText(clip.id, text);
        },
      ),
    );
  }

  Widget _buildFontSection(BuildContext context, TextClip clip) {
    final style = clip.style;

    return _Section(
      title: 'Font',
      child: Column(
        children: [
          // Font family
          DropdownButtonFormField<String>(
            value: style.fontFamily,
            decoration: const InputDecoration(
              labelText: 'Font Family',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 'Arial', child: Text('Arial')),
              DropdownMenuItem(value: 'Helvetica', child: Text('Helvetica')),
              DropdownMenuItem(value: 'Times New Roman', child: Text('Times New Roman')),
              DropdownMenuItem(value: 'Georgia', child: Text('Georgia')),
              DropdownMenuItem(value: 'Verdana', child: Text('Verdana')),
              DropdownMenuItem(value: 'Courier New', child: Text('Courier New')),
            ],
            onChanged: (value) {
              if (value != null) {
                ref.read(textClipsProvider.notifier).updateStyle(
                      clip.id,
                      style.copyWith(fontFamily: value),
                    );
              }
            },
          ),

          const SizedBox(height: 8),

          // Font size
          Row(
            children: [
              const Text('Size: '),
              Expanded(
                child: Slider(
                  value: style.fontSize,
                  min: 12,
                  max: 200,
                  divisions: 94,
                  label: style.fontSize.round().toString(),
                  onChanged: (value) {
                    ref.read(textClipsProvider.notifier).updateStyle(
                          clip.id,
                          style.copyWith(fontSize: value),
                        );
                  },
                ),
              ),
              SizedBox(
                width: 40,
                child: Text('${style.fontSize.round()}'),
              ),
            ],
          ),

          // Font weight and style
          Row(
            children: [
              Expanded(
                child: SegmentedButton<FontWeight>(
                  segments: const [
                    ButtonSegment(
                      value: FontWeight.normal,
                      label: Text('Regular'),
                    ),
                    ButtonSegment(
                      value: FontWeight.bold,
                      label: Text('Bold'),
                    ),
                  ],
                  selected: {style.fontWeight},
                  onSelectionChanged: (selected) {
                    ref.read(textClipsProvider.notifier).updateStyle(
                          clip.id,
                          style.copyWith(fontWeight: selected.first),
                        );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Italic and underline
          Row(
            children: [
              FilterChip(
                label: const Text('Italic'),
                selected: style.italic,
                onSelected: (selected) {
                  ref.read(textClipsProvider.notifier).updateStyle(
                        clip.id,
                        style.copyWith(italic: selected),
                      );
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Underline'),
                selected: style.underline,
                onSelected: (selected) {
                  ref.read(textClipsProvider.notifier).updateStyle(
                        clip.id,
                        style.copyWith(underline: selected),
                      );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorSection(BuildContext context, TextClip clip) {
    final style = clip.style;

    return _Section(
      title: 'Colors',
      child: Column(
        children: [
          _ColorPicker(
            label: 'Text Color',
            color: style.color,
            onColorChanged: (color) {
              ref.read(textClipsProvider.notifier).updateStyle(
                    clip.id,
                    style.copyWith(color: color),
                  );
            },
          ),
          const SizedBox(height: 8),
          _ColorPicker(
            label: 'Stroke Color',
            color: style.strokeColor,
            nullable: true,
            onColorChanged: (color) {
              ref.read(textClipsProvider.notifier).updateStyle(
                    clip.id,
                    style.copyWith(strokeColor: color),
                  );
            },
          ),
          if (style.strokeColor != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Stroke Width: '),
                Expanded(
                  child: Slider(
                    value: style.strokeWidth,
                    min: 0,
                    max: 10,
                    onChanged: (value) {
                      ref.read(textClipsProvider.notifier).updateStyle(
                            clip.id,
                            style.copyWith(strokeWidth: value),
                          );
                    },
                  ),
                ),
                SizedBox(
                  width: 30,
                  child: Text(style.strokeWidth.toStringAsFixed(1)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPositionSection(BuildContext context, TextClip clip) {
    return _Section(
      title: 'Position',
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 40, child: Text('X:')),
              Expanded(
                child: Slider(
                  value: clip.position.dx,
                  min: 0,
                  max: 1,
                  onChanged: (value) {
                    ref.read(textClipsProvider.notifier).updatePosition(
                          clip.id,
                          Offset(value, clip.position.dy),
                        );
                  },
                ),
              ),
              SizedBox(
                width: 40,
                child: Text('${(clip.position.dx * 100).round()}%'),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 40, child: Text('Y:')),
              Expanded(
                child: Slider(
                  value: clip.position.dy,
                  min: 0,
                  max: 1,
                  onChanged: (value) {
                    ref.read(textClipsProvider.notifier).updatePosition(
                          clip.id,
                          Offset(clip.position.dx, value),
                        );
                  },
                ),
              ),
              SizedBox(
                width: 40,
                child: Text('${(clip.position.dy * 100).round()}%'),
              ),
            ],
          ),
          // Quick position buttons
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _QuickPositionButton(
                label: 'TL',
                position: const Offset(0.1, 0.1),
                onTap: () => _setPosition(clip, const Offset(0.1, 0.1)),
              ),
              _QuickPositionButton(
                label: 'TC',
                position: const Offset(0.5, 0.1),
                onTap: () => _setPosition(clip, const Offset(0.5, 0.1)),
              ),
              _QuickPositionButton(
                label: 'TR',
                position: const Offset(0.9, 0.1),
                onTap: () => _setPosition(clip, const Offset(0.9, 0.1)),
              ),
              _QuickPositionButton(
                label: 'ML',
                position: const Offset(0.1, 0.5),
                onTap: () => _setPosition(clip, const Offset(0.1, 0.5)),
              ),
              _QuickPositionButton(
                label: 'MC',
                position: const Offset(0.5, 0.5),
                onTap: () => _setPosition(clip, const Offset(0.5, 0.5)),
              ),
              _QuickPositionButton(
                label: 'MR',
                position: const Offset(0.9, 0.5),
                onTap: () => _setPosition(clip, const Offset(0.9, 0.5)),
              ),
              _QuickPositionButton(
                label: 'BL',
                position: const Offset(0.1, 0.9),
                onTap: () => _setPosition(clip, const Offset(0.1, 0.9)),
              ),
              _QuickPositionButton(
                label: 'BC',
                position: const Offset(0.5, 0.9),
                onTap: () => _setPosition(clip, const Offset(0.5, 0.9)),
              ),
              _QuickPositionButton(
                label: 'BR',
                position: const Offset(0.9, 0.9),
                onTap: () => _setPosition(clip, const Offset(0.9, 0.9)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setPosition(TextClip clip, Offset position) {
    ref.read(textClipsProvider.notifier).updatePosition(clip.id, position);
  }

  Widget _buildAnimationSection(BuildContext context, TextClip clip) {
    final animation = clip.animation;

    return _Section(
      title: 'Animation',
      child: Column(
        children: [
          DropdownButtonFormField<TextAnimationType>(
            value: animation?.type ?? TextAnimationType.none,
            decoration: const InputDecoration(
              labelText: 'Animation Type',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: TextAnimationType.values
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.displayName),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                ref.read(textClipsProvider.notifier).updateAnimation(
                      clip.id,
                      value == TextAnimationType.none
                          ? null
                          : TextAnimation(type: value),
                    );
              }
            },
          ),
          if (animation != null && animation.type != TextAnimationType.none) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('In Duration: '),
                Expanded(
                  child: Slider(
                    value: animation.entranceDuration,
                    min: 0,
                    max: 2,
                    onChanged: (value) {
                      ref.read(textClipsProvider.notifier).updateAnimation(
                            clip.id,
                            animation.copyWith(entranceDuration: value),
                          );
                    },
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('${animation.entranceDuration.toStringAsFixed(1)}s'),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Out Duration: '),
                Expanded(
                  child: Slider(
                    value: animation.exitDuration,
                    min: 0,
                    max: 2,
                    onChanged: (value) {
                      ref.read(textClipsProvider.notifier).updateAnimation(
                            clip.id,
                            animation.copyWith(exitDuration: value),
                          );
                    },
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('${animation.exitDuration.toStringAsFixed(1)}s'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBackgroundSection(BuildContext context, TextClip clip) {
    final background = clip.background;

    return _Section(
      title: 'Background',
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Enable Background'),
            value: background != null,
            onChanged: (value) {
              ref.read(textClipsProvider.notifier).updateBackground(
                    clip.id,
                    value ? const TextBackground() : null,
                  );
            },
          ),
          if (background != null) ...[
            _ColorPicker(
              label: 'Background Color',
              color: background.color,
              onColorChanged: (color) {
                ref.read(textClipsProvider.notifier).updateBackground(
                      clip.id,
                      background.copyWith(color: color),
                    );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Padding: '),
                Expanded(
                  child: Slider(
                    value: background.padding,
                    min: 0,
                    max: 50,
                    onChanged: (value) {
                      ref.read(textClipsProvider.notifier).updateBackground(
                            clip.id,
                            background.copyWith(padding: value),
                          );
                    },
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('${background.padding.round()}'),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Corner Radius: '),
                Expanded(
                  child: Slider(
                    value: background.borderRadius,
                    min: 0,
                    max: 30,
                    onChanged: (value) {
                      ref.read(textClipsProvider.notifier).updateBackground(
                            clip.id,
                            background.copyWith(borderRadius: value),
                          );
                    },
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('${background.borderRadius.round()}'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Section wrapper widget
class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// Simple color picker row
class _ColorPicker extends StatelessWidget {
  final String label;
  final Color? color;
  final bool nullable;
  final ValueChanged<Color?> onColorChanged;

  const _ColorPicker({
    required this.label,
    required this.color,
    this.nullable = false,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(child: Text(label)),
        if (nullable)
          IconButton(
            icon: Icon(
              color == null ? Icons.add : Icons.remove,
              size: 16,
            ),
            onPressed: () {
              onColorChanged(color == null ? Colors.black : null);
            },
          ),
        if (color != null)
          GestureDetector(
            onTap: () => _showColorPicker(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colorScheme.outline),
              ),
            ),
          ),
      ],
    );
  }

  void _showColorPicker(BuildContext context) {
    // Show color picker dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Colors.white,
            Colors.black,
            Colors.red,
            Colors.pink,
            Colors.purple,
            Colors.deepPurple,
            Colors.blue,
            Colors.cyan,
            Colors.teal,
            Colors.green,
            Colors.lightGreen,
            Colors.yellow,
            Colors.amber,
            Colors.orange,
            Colors.deepOrange,
          ].map((c) {
            return GestureDetector(
              onTap: () {
                onColorChanged(c);
                Navigator.of(context).pop();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: c == color ? Colors.blue : Colors.grey,
                    width: c == color ? 2 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Quick position button
class _QuickPositionButton extends StatelessWidget {
  final String label;
  final Offset position;
  final VoidCallback onTap;

  const _QuickPositionButton({
    required this.label,
    required this.position,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 28,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          textStyle: const TextStyle(fontSize: 10),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}
