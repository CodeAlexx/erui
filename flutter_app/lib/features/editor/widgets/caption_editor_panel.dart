import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/caption_models.dart';
import '../providers/caption_provider.dart';
import '../providers/editor_provider.dart';

/// Panel for editing captions/subtitles.
///
/// Features:
/// - Caption list with timing
/// - Add/edit/delete captions
/// - Import/export SRT, VTT
/// - Auto-transcription via SwarmUI
/// - Style and position controls
class CaptionEditorPanel extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const CaptionEditorPanel({super.key, this.onClose});

  @override
  ConsumerState<CaptionEditorPanel> createState() => _CaptionEditorPanelState();
}

class _CaptionEditorPanelState extends ConsumerState<CaptionEditorPanel> {
  final TextEditingController _textController = TextEditingController();
  bool _isEditing = false;
  EditorId? _editingCaptionId;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final captionState = ref.watch(captionProvider);
    final tracks = captionState.tracks;
    final activeTrack = captionState.activeTrack;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(context),

          // Track selector
          if (tracks.isNotEmpty) _buildTrackSelector(context, tracks, activeTrack),

          // Toolbar
          _buildToolbar(context),

          // Caption list
          Expanded(
            child: activeTrack == null
                ? _buildEmptyState(context)
                : _buildCaptionList(context, activeTrack),
          ),

          // Add caption bar
          if (activeTrack != null) _buildAddCaptionBar(context),
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
          Icon(Icons.closed_caption, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Captions & Subtitles',
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

  Widget _buildTrackSelector(
      BuildContext context, List<CaptionTrack> tracks, CaptionTrack? activeTrack) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<EditorId>(
              value: activeTrack?.id,
              isExpanded: true,
              underline: const SizedBox(),
              hint: const Text('Select track'),
              items: tracks.map((track) {
                return DropdownMenuItem(
                  value: track.id,
                  child: Row(
                    children: [
                      Text(track.name, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          track.language.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (id) {
                if (id != null) {
                  ref.read(captionProvider.notifier).setActiveTrack(id);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => _showAddTrackDialog(context),
            tooltip: 'Add Track',
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showInPreview = ref.watch(captionVisibilityProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          // Import
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            onPressed: () => _importCaptions(context),
            tooltip: 'Import SRT/VTT',
          ),

          // Export
          IconButton(
            icon: const Icon(Icons.file_download_outlined, size: 18),
            onPressed: () => _exportCaptions(context),
            tooltip: 'Export',
          ),

          // Auto-transcribe
          IconButton(
            icon: const Icon(Icons.mic, size: 18),
            onPressed: () => _autoTranscribe(context),
            tooltip: 'Auto-transcribe (Whisper)',
          ),

          const Spacer(),

          // Toggle preview visibility
          IconButton(
            icon: Icon(
              showInPreview ? Icons.visibility : Icons.visibility_off,
              size: 18,
            ),
            onPressed: () {
              ref.read(captionProvider.notifier).setShowInPreview(!showInPreview);
            },
            tooltip: showInPreview ? 'Hide in Preview' : 'Show in Preview',
          ),

          // Style settings
          IconButton(
            icon: const Icon(Icons.text_format, size: 18),
            onPressed: () => _showStyleDialog(context),
            tooltip: 'Caption Style',
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionList(BuildContext context, CaptionTrack track) {
    final colorScheme = Theme.of(context).colorScheme;
    final captions = track.sortedCaptions;
    final selectedIds = ref.watch(captionProvider).selectedCaptionIds;
    final currentTime = ref.watch(playheadPositionProvider);

    if (captions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.subtitles_off,
              size: 48,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No captions yet',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Caption'),
              onPressed: () => _addCaption(context),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: captions.length,
      itemBuilder: (context, index) {
        final caption = captions[index];
        final isSelected = selectedIds.contains(caption.id);
        final isActive = caption.isActiveAt(currentTime);

        return _CaptionListItem(
          caption: caption,
          isSelected: isSelected,
          isActive: isActive,
          onTap: () {
            ref.read(captionProvider.notifier).selectCaptions({caption.id});
            // Seek to caption start
            ref.read(editorProjectProvider.notifier).setPlayhead(caption.startTime);
          },
          onEdit: () => _editCaption(context, caption),
          onDelete: () {
            ref.read(captionProvider.notifier).removeCaption(caption.id);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.closed_caption_off,
            size: 48,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No caption tracks',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Track'),
            onPressed: () => _showAddTrackDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCaptionBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Enter caption text...',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: const TextStyle(fontSize: 13),
              onSubmitted: (text) {
                if (text.isNotEmpty) {
                  _addCaptionAtPlayhead(text);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              if (_textController.text.isNotEmpty) {
                _addCaptionAtPlayhead(_textController.text);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addCaptionAtPlayhead(String text) {
    final currentTime = ref.read(playheadPositionProvider);
    ref.read(captionProvider.notifier).addCaption(
      startTime: currentTime,
      endTime: EditorTime(currentTime.microseconds + 3000000), // 3 second default
      text: text,
    );
    _textController.clear();
  }

  void _addCaption(BuildContext context) {
    // Show dialog to add caption with custom timing
    showDialog(
      context: context,
      builder: (context) => _AddCaptionDialog(
        onAdd: (startTime, endTime, text) {
          ref.read(captionProvider.notifier).addCaption(
            startTime: startTime,
            endTime: endTime,
            text: text,
          );
        },
      ),
    );
  }

  void _editCaption(BuildContext context, Caption caption) {
    showDialog(
      context: context,
      builder: (context) => _EditCaptionDialog(
        caption: caption,
        onSave: (updated) {
          ref.read(captionProvider.notifier).updateCaption(updated);
        },
      ),
    );
  }

  void _showAddTrackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddTrackDialog(
        onAdd: (name, language) {
          ref.read(captionProvider.notifier).addTrack(
            name: name,
            language: language,
          );
        },
      ),
    );
  }

  void _importCaptions(BuildContext context) {
    // TODO: File picker and import logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import functionality coming soon')),
    );
  }

  void _exportCaptions(BuildContext context) {
    final srt = ref.read(captionProvider.notifier).exportSrt();
    if (srt != null) {
      // TODO: Save to file
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export functionality coming soon')),
      );
    }
  }

  void _autoTranscribe(BuildContext context) {
    // TODO: Extract audio and call SwarmUI Whisper API
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connecting to SwarmUI for transcription...')),
    );
  }

  void _showStyleDialog(BuildContext context) {
    final activeTrack = ref.read(captionProvider).activeTrack;
    if (activeTrack == null) return;

    showDialog(
      context: context,
      builder: (context) => _CaptionStyleDialog(
        style: activeTrack.style,
        position: activeTrack.position,
        onSave: (style, position) {
          ref.read(captionProvider.notifier).updateTrackStyle(activeTrack.id, style);
          ref.read(captionProvider.notifier).updateTrackPosition(activeTrack.id, position);
        },
      ),
    );
  }
}

/// Caption list item
class _CaptionListItem extends StatelessWidget {
  final Caption caption;
  final bool isSelected;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CaptionListItem({
    required this.caption,
    required this.isSelected,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primaryContainer.withOpacity(0.5)
            : isSelected
                ? colorScheme.surfaceContainerHighest
                : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isSelected
            ? Border.all(color: colorScheme.primary.withOpacity(0.5))
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timing
              SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatTime(caption.startTime),
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: colorScheme.primary,
                      ),
                    ),
                    Text(
                      _formatTime(caption.endTime),
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Text
              Expanded(
                child: Text(
                  caption.text,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, size: 16, color: colorScheme.error),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(EditorTime time) {
    final total = time.inSeconds;
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).floor().toString().padLeft(2, '0');
    final ms = ((total % 1) * 1000).round().toString().padLeft(3, '0');
    return '$minutes:$seconds.$ms';
  }
}

/// Dialog for adding a caption
class _AddCaptionDialog extends StatefulWidget {
  final void Function(EditorTime startTime, EditorTime endTime, String text) onAdd;

  const _AddCaptionDialog({required this.onAdd});

  @override
  State<_AddCaptionDialog> createState() => _AddCaptionDialogState();
}

class _AddCaptionDialogState extends State<_AddCaptionDialog> {
  final _textController = TextEditingController();
  double _startSeconds = 0;
  double _endSeconds = 3;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Caption'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'Caption Text',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Start (sec)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _startSeconds = double.tryParse(v) ?? 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'End (sec)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _endSeconds = double.tryParse(v) ?? 3,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onAdd(
              EditorTime.fromSeconds(_startSeconds),
              EditorTime.fromSeconds(_endSeconds),
              _textController.text,
            );
            Navigator.of(context).pop();
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Dialog for editing a caption
class _EditCaptionDialog extends StatefulWidget {
  final Caption caption;
  final void Function(Caption updated) onSave;

  const _EditCaptionDialog({required this.caption, required this.onSave});

  @override
  State<_EditCaptionDialog> createState() => _EditCaptionDialogState();
}

class _EditCaptionDialogState extends State<_EditCaptionDialog> {
  late TextEditingController _textController;
  late double _startSeconds;
  late double _endSeconds;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.caption.text);
    _startSeconds = widget.caption.startTime.inSeconds;
    _endSeconds = widget.caption.endTime.inSeconds;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Caption'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'Caption Text',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Start (sec)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: _startSeconds.toStringAsFixed(2)),
                  onChanged: (v) => _startSeconds = double.tryParse(v) ?? _startSeconds,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'End (sec)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: _endSeconds.toStringAsFixed(2)),
                  onChanged: (v) => _endSeconds = double.tryParse(v) ?? _endSeconds,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(widget.caption.copyWith(
              text: _textController.text,
              startTime: EditorTime.fromSeconds(_startSeconds),
              endTime: EditorTime.fromSeconds(_endSeconds),
            ));
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Dialog for adding a caption track
class _AddTrackDialog extends StatefulWidget {
  final void Function(String name, String language) onAdd;

  const _AddTrackDialog({required this.onAdd});

  @override
  State<_AddTrackDialog> createState() => _AddTrackDialogState();
}

class _AddTrackDialogState extends State<_AddTrackDialog> {
  final _nameController = TextEditingController(text: 'Subtitles');
  String _language = 'en';

  static const _languages = [
    ('en', 'English'),
    ('es', 'Spanish'),
    ('fr', 'French'),
    ('de', 'German'),
    ('it', 'Italian'),
    ('pt', 'Portuguese'),
    ('ja', 'Japanese'),
    ('ko', 'Korean'),
    ('zh', 'Chinese'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Caption Track'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Track Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _language,
            decoration: const InputDecoration(
              labelText: 'Language',
              border: OutlineInputBorder(),
            ),
            items: _languages.map((l) {
              return DropdownMenuItem(
                value: l.$1,
                child: Text('${l.$2} (${l.$1})'),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _language = v);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onAdd(_nameController.text, _language);
            Navigator.of(context).pop();
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Dialog for caption style settings
class _CaptionStyleDialog extends StatefulWidget {
  final CaptionStyle style;
  final CaptionPosition position;
  final void Function(CaptionStyle style, CaptionPosition position) onSave;

  const _CaptionStyleDialog({
    required this.style,
    required this.position,
    required this.onSave,
  });

  @override
  State<_CaptionStyleDialog> createState() => _CaptionStyleDialogState();
}

class _CaptionStyleDialogState extends State<_CaptionStyleDialog> {
  late CaptionStyle _style;
  late CaptionPosition _position;

  @override
  void initState() {
    super.initState();
    _style = widget.style;
    _position = widget.position;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Caption Style'),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Font size
            Row(
              children: [
                const Text('Font Size: '),
                Expanded(
                  child: Slider(
                    value: _style.fontSize,
                    min: 12,
                    max: 48,
                    onChanged: (v) => setState(() => _style = _style.copyWith(fontSize: v)),
                  ),
                ),
                Text('${_style.fontSize.round()}'),
              ],
            ),

            // Position
            Row(
              children: [
                const Text('Position: '),
                Expanded(
                  child: Slider(
                    value: _position.vertical,
                    min: 0,
                    max: 1,
                    onChanged: (v) => setState(() => _position = _position.copyWith(vertical: v)),
                  ),
                ),
                Text(_position.vertical < 0.3 ? 'Top' : _position.vertical > 0.7 ? 'Bottom' : 'Middle'),
              ],
            ),

            // Alignment
            const SizedBox(height: 8),
            const Text('Alignment:'),
            SegmentedButton<CaptionAlignment>(
              segments: const [
                ButtonSegment(value: CaptionAlignment.left, icon: Icon(Icons.format_align_left)),
                ButtonSegment(value: CaptionAlignment.center, icon: Icon(Icons.format_align_center)),
                ButtonSegment(value: CaptionAlignment.right, icon: Icon(Icons.format_align_right)),
              ],
              selected: {_position.horizontal},
              onSelectionChanged: (v) => setState(() => _position = _position.copyWith(horizontal: v.first)),
            ),

            // Outline width
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Outline: '),
                Expanded(
                  child: Slider(
                    value: _style.outlineWidth,
                    min: 0,
                    max: 5,
                    onChanged: (v) => setState(() => _style = _style.copyWith(outlineWidth: v)),
                  ),
                ),
                Text('${_style.outlineWidth.round()}'),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_style, _position);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
