import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/editor_models.dart';

/// Track header widget that appears on the left side of each track.
/// Displays track controls including name, mute, solo, lock, visibility,
/// and volume controls.
class TrackHeader extends StatefulWidget {
  /// The track to display
  final Track track;

  /// Whether this track is currently selected
  final bool isSelected;

  /// Called when the track header is tapped
  final VoidCallback? onTap;

  /// Called when the track name is changed
  final Function(String)? onNameChanged;

  /// Called when mute state changes
  final Function(bool)? onMuteChanged;

  /// Called when solo state changes
  final Function(bool)? onSoloChanged;

  /// Called when lock state changes
  final Function(bool)? onLockChanged;

  /// Called when visibility state changes
  final Function(bool)? onVisibilityChanged;

  /// Called when volume changes (audio tracks only)
  final Function(double)? onVolumeChanged;

  /// Called when track should be deleted
  final VoidCallback? onDelete;

  /// Called when track should be duplicated
  final VoidCallback? onDuplicate;

  /// Called when track drag starts for reordering
  final VoidCallback? onDragStart;

  /// Called when track drag ends
  final VoidCallback? onDragEnd;

  const TrackHeader({
    super.key,
    required this.track,
    this.isSelected = false,
    this.onTap,
    this.onNameChanged,
    this.onMuteChanged,
    this.onSoloChanged,
    this.onLockChanged,
    this.onVisibilityChanged,
    this.onVolumeChanged,
    this.onDelete,
    this.onDuplicate,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  State<TrackHeader> createState() => _TrackHeaderState();
}

class _TrackHeaderState extends State<TrackHeader> {
  bool _isEditingName = false;
  late TextEditingController _nameController;
  late FocusNode _nameFocusNode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.track.name);
    _nameFocusNode = FocusNode();
    _nameFocusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(TrackHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.name != widget.track.name && !_isEditingName) {
      _nameController.text = widget.track.name;
    }
  }

  @override
  void dispose() {
    _nameFocusNode.removeListener(_onFocusChange);
    _nameFocusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_nameFocusNode.hasFocus && _isEditingName) {
      _finishEditing();
    }
  }

  void _startEditing() {
    setState(() {
      _isEditingName = true;
    });
    _nameFocusNode.requestFocus();
    _nameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _nameController.text.length,
    );
  }

  void _finishEditing() {
    if (!_isEditingName) return;

    setState(() {
      _isEditingName = false;
    });

    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != widget.track.name) {
      widget.onNameChanged?.call(newName);
    } else {
      _nameController.text = widget.track.name;
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditingName = false;
      _nameController.text = widget.track.name;
    });
  }

  IconData _getTrackTypeIcon() {
    switch (widget.track.type) {
      case TrackType.video:
        return Icons.videocam;
      case TrackType.audio:
        return Icons.audiotrack;
      case TrackType.text:
        return Icons.text_fields;
      case TrackType.effect:
        return Icons.auto_fix_high;
    }
  }

  Color _getTrackTypeColor(ColorScheme colorScheme) {
    switch (widget.track.type) {
      case TrackType.video:
        return Colors.blue;
      case TrackType.audio:
        return Colors.green;
      case TrackType.text:
        return Colors.purple;
      case TrackType.effect:
        return Colors.orange;
    }
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final colorScheme = Theme.of(context).colorScheme;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 8),
              const Text('Rename'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 8),
              const Text('Duplicate'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: colorScheme.error),
              const SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: colorScheme.error)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;

      switch (value) {
        case 'rename':
          _startEditing();
          break;
        case 'duplicate':
          widget.onDuplicate?.call();
          break;
        case 'delete':
          widget.onDelete?.call();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trackColor = _getTrackTypeColor(colorScheme);
    final isAudioTrack = widget.track.type == TrackType.audio ||
        widget.track.type == TrackType.video;

    return GestureDetector(
      onTap: widget.onTap,
      onSecondaryTapUp: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      child: Container(
        height: widget.track.height,
        decoration: BoxDecoration(
          color: widget.isSelected
              ? colorScheme.primaryContainer.withOpacity(0.3)
              : colorScheme.surface,
          border: Border(
            left: BorderSide(
              color: trackColor,
              width: 3,
            ),
            bottom: BorderSide(
              color: colorScheme.outlineVariant,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Drag handle
            MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: GestureDetector(
                onPanStart: (_) => widget.onDragStart?.call(),
                onPanEnd: (_) => widget.onDragEnd?.call(),
                child: Container(
                  width: 20,
                  height: double.infinity,
                  color: Colors.transparent,
                  child: Icon(
                    Icons.drag_indicator,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            // Track type icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Tooltip(
                message: widget.track.type.name.toUpperCase(),
                child: Icon(
                  _getTrackTypeIcon(),
                  size: 18,
                  color: trackColor,
                ),
              ),
            ),

            // Track name (editable)
            Expanded(
              child: GestureDetector(
                onDoubleTap: _startEditing,
                child: _isEditingName
                    ? _buildNameEditor(colorScheme)
                    : _buildNameDisplay(colorScheme),
              ),
            ),

            // Control buttons row
            _buildControlButtons(colorScheme),

            // Volume slider for audio tracks
            if (isAudioTrack) _buildVolumeSlider(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildNameDisplay(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        widget.track.name,
        style: TextStyle(
          fontSize: 12,
          color: widget.track.isMuted
              ? colorScheme.onSurface.withOpacity(0.5)
              : colorScheme.onSurface,
          fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildNameEditor(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextField(
        controller: _nameController,
        focusNode: _nameFocusNode,
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: colorScheme.primary),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
        onSubmitted: (_) => _finishEditing(),
        inputFormatters: [
          LengthLimitingTextInputFormatter(50),
        ],
      ),
    );
  }

  Widget _buildControlButtons(ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mute button
        _buildToggleButton(
          icon: widget.track.isMuted ? Icons.volume_off : Icons.volume_up,
          label: 'M',
          tooltip: widget.track.isMuted ? 'Unmute' : 'Mute',
          isActive: widget.track.isMuted,
          activeColor: colorScheme.error,
          onPressed: () => widget.onMuteChanged?.call(!widget.track.isMuted),
          colorScheme: colorScheme,
        ),

        // Solo button
        _buildToggleButton(
          icon: Icons.headphones,
          label: 'S',
          tooltip: widget.track.isSolo ? 'Unsolo' : 'Solo',
          isActive: widget.track.isSolo,
          activeColor: Colors.amber,
          onPressed: () => widget.onSoloChanged?.call(!widget.track.isSolo),
          colorScheme: colorScheme,
        ),

        // Lock button
        _buildToggleButton(
          icon: widget.track.isLocked ? Icons.lock : Icons.lock_open,
          tooltip: widget.track.isLocked ? 'Unlock' : 'Lock',
          isActive: widget.track.isLocked,
          activeColor: colorScheme.tertiary,
          onPressed: () => widget.onLockChanged?.call(!widget.track.isLocked),
          colorScheme: colorScheme,
        ),

        // Visibility toggle
        _buildToggleButton(
          icon: widget.track.isVisible ? Icons.visibility : Icons.visibility_off,
          tooltip: widget.track.isVisible ? 'Hide' : 'Show',
          isActive: !widget.track.isVisible,
          activeColor: colorScheme.onSurfaceVariant,
          onPressed: () => widget.onVisibilityChanged?.call(!widget.track.isVisible),
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    String? label,
    required String tooltip,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: isActive
                ? Border.all(color: activeColor.withOpacity(0.5), width: 1)
                : null,
          ),
          child: Center(
            child: label != null
                ? Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isActive ? activeColor : colorScheme.onSurfaceVariant,
                    ),
                  )
                : Icon(
                    icon,
                    size: 14,
                    color: isActive ? activeColor : colorScheme.onSurfaceVariant,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeSlider(ColorScheme colorScheme) {
    return SizedBox(
      width: 60,
      child: Tooltip(
        message: 'Volume: ${(widget.track.volume * 100).toInt()}%',
        child: SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.onSurface.withOpacity(0.2),
            thumbColor: colorScheme.primary,
            overlayColor: colorScheme.primary.withOpacity(0.2),
          ),
          child: Slider(
            value: widget.track.volume.clamp(0.0, 2.0),
            min: 0.0,
            max: 2.0,
            onChanged: widget.track.isLocked
                ? null
                : (value) => widget.onVolumeChanged?.call(value),
          ),
        ),
      ),
    );
  }
}

/// Compact track header variant for smaller displays
class CompactTrackHeader extends StatelessWidget {
  final Track track;
  final bool isSelected;
  final VoidCallback? onTap;
  final Function(bool)? onMuteChanged;
  final Function(bool)? onVisibilityChanged;

  const CompactTrackHeader({
    super.key,
    required this.track,
    this.isSelected = false,
    this.onTap,
    this.onMuteChanged,
    this.onVisibilityChanged,
  });

  Color _getTrackTypeColor() {
    switch (track.type) {
      case TrackType.video:
        return Colors.blue;
      case TrackType.audio:
        return Colors.green;
      case TrackType.text:
        return Colors.purple;
      case TrackType.effect:
        return Colors.orange;
    }
  }

  IconData _getTrackTypeIcon() {
    switch (track.type) {
      case TrackType.video:
        return Icons.videocam;
      case TrackType.audio:
        return Icons.audiotrack;
      case TrackType.text:
        return Icons.text_fields;
      case TrackType.effect:
        return Icons.auto_fix_high;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trackColor = _getTrackTypeColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withOpacity(0.3)
              : colorScheme.surface,
          border: Border(
            left: BorderSide(color: trackColor, width: 3),
            bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 4),
            Icon(_getTrackTypeIcon(), size: 14, color: trackColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                track.name,
                style: TextStyle(
                  fontSize: 11,
                  color: track.isMuted
                      ? colorScheme.onSurface.withOpacity(0.5)
                      : colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(
                track.isMuted ? Icons.volume_off : Icons.volume_up,
                size: 14,
              ),
              iconSize: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: () => onMuteChanged?.call(!track.isMuted),
              color: track.isMuted
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
              tooltip: track.isMuted ? 'Unmute' : 'Mute',
            ),
            IconButton(
              icon: Icon(
                track.isVisible ? Icons.visibility : Icons.visibility_off,
                size: 14,
              ),
              iconSize: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: () => onVisibilityChanged?.call(!track.isVisible),
              color: !track.isVisible
                  ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                  : colorScheme.onSurfaceVariant,
              tooltip: track.isVisible ? 'Hide' : 'Show',
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
