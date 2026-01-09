import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/autocomplete_service.dart';

/// Autocomplete prompt field with dropdown overlay
/// Supports danbooru/e621 tags, LoRA names, embedding names, and syntax completions
class AutocompletePromptField extends ConsumerStatefulWidget {
  /// Initial text value
  final String initialValue;

  /// Callback when text changes
  final ValueChanged<String>? onChanged;

  /// Callback when text is submitted
  final ValueChanged<String>? onSubmitted;

  /// Input decoration
  final InputDecoration? decoration;

  /// Text style
  final TextStyle? style;

  /// Hint text style
  final TextStyle? hintStyle;

  /// Max lines for the text field
  final int maxLines;

  /// Min lines for the text field
  final int minLines;

  /// Whether the field is enabled
  final bool enabled;

  /// Focus node
  final FocusNode? focusNode;

  /// Controller (optional, will create internal one if not provided)
  final TextEditingController? controller;

  /// Maximum suggestions to show
  final int maxSuggestions;

  /// Debounce duration for search
  final Duration debounceDuration;

  const AutocompletePromptField({
    super.key,
    this.initialValue = '',
    this.onChanged,
    this.onSubmitted,
    this.decoration,
    this.style,
    this.hintStyle,
    this.maxLines = 4,
    this.minLines = 2,
    this.enabled = true,
    this.focusNode,
    this.controller,
    this.maxSuggestions = 10,
    this.debounceDuration = const Duration(milliseconds: 150),
  });

  @override
  ConsumerState<AutocompletePromptField> createState() =>
      _AutocompletePromptFieldState();
}

class _AutocompletePromptFieldState
    extends ConsumerState<AutocompletePromptField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocusNode = false;

  /// Overlay for suggestions dropdown
  OverlayEntry? _overlayEntry;

  /// Link to position overlay relative to text field
  final LayerLink _layerLink = LayerLink();

  /// Current suggestions
  List<TagSuggestion> _suggestions = [];

  /// Selected suggestion index
  int _selectedIndex = -1;

  /// Debounce timer
  int _debounceGeneration = 0;

  /// Whether overlay is showing
  bool get _isOverlayShowing => _overlayEntry != null;

  @override
  void initState() {
    super.initState();

    // Initialize controller
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController(text: widget.initialValue);
      _ownsController = true;
    }

    // Initialize focus node
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }

    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);

    // Initialize autocomplete service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(autocompleteServiceProvider).initialize();
    });
  }

  @override
  void didUpdateWidget(AutocompletePromptField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      if (_ownsController) {
        _controller.dispose();
      }
      if (widget.controller != null) {
        _controller = widget.controller!;
        _ownsController = false;
      } else {
        _controller = TextEditingController(text: widget.initialValue);
        _ownsController = true;
      }
      _controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _hideOverlay();
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideOverlay();
    }
  }

  void _onTextChanged() {
    widget.onChanged?.call(_controller.text);
    _debouncedSearch();
  }

  void _debouncedSearch() {
    final generation = ++_debounceGeneration;

    Future.delayed(widget.debounceDuration, () {
      if (generation == _debounceGeneration && mounted) {
        _updateSuggestions();
      }
    });
  }

  void _updateSuggestions() {
    if (!_focusNode.hasFocus) {
      _hideOverlay();
      return;
    }

    final service = ref.read(autocompleteServiceProvider);
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;

    if (cursorPos < 0) {
      _hideOverlay();
      return;
    }

    final suggestions = service.getCompletions(text, cursorPos);

    if (suggestions.isEmpty) {
      _hideOverlay();
      return;
    }

    setState(() {
      _suggestions = suggestions.take(widget.maxSuggestions).toList();
      _selectedIndex = -1;
    });

    _showOverlay();
  }

  void _showOverlay() {
    if (_isOverlayShowing) {
      _overlayEntry!.markNeedsBuild();
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildOverlay(),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _suggestions = [];
        _selectedIndex = -1;
      });
    }
  }

  void _selectSuggestion(TagSuggestion suggestion) {
    final service = ref.read(autocompleteServiceProvider);
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;

    if (cursorPos < 0) return;

    final boundaries = service.getWordBoundaries(text, cursorPos);
    if (boundaries == null) return;

    final (start, end) = boundaries;
    final beforeCursor = text.substring(0, cursorPos);
    final replacement = service.formatTagForInsertion(suggestion, beforeCursor);

    // Build new text
    final newText = text.substring(0, start) +
        replacement +
        (end < text.length ? text.substring(end) : '');

    // Calculate new cursor position
    final newCursorPos = start + replacement.length;

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    _hideOverlay();
    widget.onChanged?.call(newText);
  }

  void _navigateSuggestions(int delta) {
    if (_suggestions.isEmpty) return;

    setState(() {
      _selectedIndex += delta;
      if (_selectedIndex < 0) {
        _selectedIndex = _suggestions.length - 1;
      } else if (_selectedIndex >= _suggestions.length) {
        _selectedIndex = 0;
      }
    });
    _overlayEntry?.markNeedsBuild();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (!_isOverlayShowing) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _navigateSuggestions(1);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp:
        _navigateSuggestions(-1);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.tab:
      case LogicalKeyboardKey.enter:
        if (_selectedIndex >= 0 && _selectedIndex < _suggestions.length) {
          _selectSuggestion(_suggestions[_selectedIndex]);
          return KeyEventResult.handled;
        } else if (_suggestions.isNotEmpty) {
          _selectSuggestion(_suggestions[0]);
          return KeyEventResult.handled;
        }
        break;

      case LogicalKeyboardKey.escape:
        _hideOverlay();
        return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Widget _buildOverlay() {
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      width: 400,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 4),
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          color: colorScheme.surfaceContainerHigh,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                final isSelected = index == _selectedIndex;

                return _SuggestionTile(
                  suggestion: suggestion,
                  isSelected: isSelected,
                  onTap: () => _selectSuggestion(suggestion),
                  onHover: (hovering) {
                    if (hovering) {
                      setState(() => _selectedIndex = index);
                      _overlayEntry?.markNeedsBuild();
                    }
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(
        onKeyEvent: _handleKeyEvent,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          style: widget.style,
          decoration: widget.decoration ??
              InputDecoration(
                hintText: 'Type your prompt here...',
                hintStyle: widget.hintStyle,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
          onSubmitted: widget.onSubmitted,
        ),
      ),
    );
  }
}

/// Individual suggestion tile
class _SuggestionTile extends StatelessWidget {
  final TagSuggestion suggestion;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  const _SuggestionTile({
    required this.suggestion,
    required this.isSelected,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryColor = Color(suggestion.category.colorValue);

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: isSelected
              ? colorScheme.primaryContainer.withOpacity(0.5)
              : Colors.transparent,
          child: Row(
            children: [
              // Category indicator
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              // Tag name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      suggestion.displayTag,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (suggestion.alias != null)
                      Text(
                        suggestion.alias!,
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
              // Count badge
              if (suggestion.count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatCount(suggestion.count),
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // Category label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  suggestion.category.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: categoryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

/// Simple prompt bar with autocomplete
/// Drop-in replacement for the standard prompt bar
class AutocompletePromptBar extends ConsumerStatefulWidget {
  const AutocompletePromptBar({super.key});

  @override
  ConsumerState<AutocompletePromptBar> createState() =>
      _AutocompletePromptBarState();
}

class _AutocompletePromptBarState extends ConsumerState<AutocompletePromptBar> {
  final _promptController = TextEditingController();
  final _negativeController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    _negativeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
          // Positive prompt with autocomplete
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
                  child: AutocompletePromptField(
                    controller: _promptController,
                    decoration: InputDecoration(
                      hintText:
                          'Type your prompt here... (Tab to complete tags)',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    style:
                        TextStyle(fontSize: 13, color: colorScheme.onSurface),
                    maxLines: 2,
                    minLines: 1,
                  ),
                ),
                Text(
                  '${_promptController.text.split(' ').where((w) => w.isNotEmpty).length}/75',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Negative prompt with autocomplete
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
            ),
            child: AutocompletePromptField(
              controller: _negativeController,
              decoration: InputDecoration(
                hintText: 'Negative prompt (optional)...',
                hintStyle: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              style:
                  TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              maxLines: 1,
              minLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
