import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vid_train_prep_provider.dart';
import '../models/vid_train_prep_models.dart';

class RangeListPanel extends ConsumerWidget {
  const RangeListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranges = ref.watch(rangesForSelectedVideoProvider);
    final selectedRangeId = ref.watch(vidTrainPrepProvider.select((s) => s.selectedRangeId));
    final selectedVideo = ref.watch(selectedVideoProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with Add Range button
        _buildHeader(context, ref, colorScheme, ranges.length, selectedVideo != null),
        // Range list
        Expanded(
          child: selectedVideo == null
              ? _buildNoVideoSelected(colorScheme)
              : ranges.isEmpty
                  ? _buildEmptyState(colorScheme, ref)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: ranges.length,
                      itemBuilder: (context, index) {
                        final range = ranges[index];
                        return RangeCard(
                          range: range,
                          index: index + 1,
                          fps: selectedVideo.fps,
                          isSelected: range.id == selectedRangeId,
                          onTap: () => ref.read(vidTrainPrepProvider.notifier).selectRange(range.id),
                          onDelete: () => ref.read(vidTrainPrepProvider.notifier).deleteRange(range.id),
                          onCaptionChanged: (caption) => ref.read(vidTrainPrepProvider.notifier)
                              .updateRange(range.id, caption: caption),
                          onCropToggle: (useCrop) => ref.read(vidTrainPrepProvider.notifier)
                              .updateRange(range.id, useCrop: useCrop),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, ColorScheme colorScheme, int count, bool canAdd) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Icon(Icons.layers, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text('Ranges', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.add, size: 18),
            onPressed: canAdd ? () {
              final video = ref.read(selectedVideoProvider);
              if (video != null) {
                ref.read(vidTrainPrepProvider.notifier).addRange(video.id);
              }
            } : null,
            tooltip: 'Add Range',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_clear, size: 48, color: colorScheme.onSurfaceVariant.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text('No ranges defined', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final video = ref.read(selectedVideoProvider);
              if (video != null) {
                ref.read(vidTrainPrepProvider.notifier).addRange(video.id);
              }
            },
            icon: Icon(Icons.add, size: 18),
            label: Text('Add Range'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoVideoSelected(ColorScheme colorScheme) {
    return Center(
      child: Text('Select a video first', style: TextStyle(color: colorScheme.onSurfaceVariant)),
    );
  }
}

class RangeCard extends StatefulWidget {
  final ClipRange range;
  final int index;
  final double fps;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<String> onCaptionChanged;
  final ValueChanged<bool> onCropToggle;

  const RangeCard({
    super.key,
    required this.range,
    required this.index,
    required this.fps,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onCaptionChanged,
    required this.onCropToggle,
  });

  @override
  State<RangeCard> createState() => _RangeCardState();
}

class _RangeCardState extends State<RangeCard> {
  late TextEditingController _captionController;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.range.caption);
  }

  @override
  void didUpdateWidget(covariant RangeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.range.caption != oldWidget.range.caption) {
      _captionController.text = widget.range.caption;
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final startTime = _formatTime(Duration(milliseconds: ((widget.range.startFrame / widget.fps) * 1000).round()));
    final endTime = _formatTime(Duration(milliseconds: ((widget.range.endFrame / widget.fps) * 1000).round()));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: widget.isSelected ? colorScheme.primaryContainer.withOpacity(0.3) : colorScheme.surfaceVariant.withOpacity(0.3),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Range number, time, frame count, delete
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Range ${widget.index}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                  const Spacer(),
                  if (widget.range.useCrop && widget.range.crop != null)
                    Icon(Icons.crop, size: 14, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 16),
                    onPressed: widget.onDelete,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: 'Delete Range',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Time and frame info
              Text('$startTime - $endTime', style: TextStyle(fontSize: 12)),
              Text('${widget.range.endFrame - widget.range.startFrame} frames',
                   style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              // Caption field
              TextField(
                controller: _captionController,
                decoration: InputDecoration(
                  hintText: 'Enter caption...',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                ),
                style: TextStyle(fontSize: 12),
                maxLines: 2,
                onChanged: widget.onCaptionChanged,
              ),
              const SizedBox(height: 8),
              // Crop toggle
              Row(
                children: [
                  Text('Use Crop', style: TextStyle(fontSize: 12)),
                  const Spacer(),
                  Switch(
                    value: widget.range.useCrop,
                    onChanged: widget.onCropToggle,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    final millis = (d.inMilliseconds % 1000) ~/ 10;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}';
  }
}
