import 'dart:async';

import 'package:flutter/material.dart';

/// Search widget for filtering workflows with debounced input
class WorkflowSearchBar extends StatefulWidget {
  /// Initial search value
  final String initialValue;

  /// Callback when search query changes (after debounce)
  final void Function(String query) onSearch;

  /// Debounce duration (default 300ms)
  final Duration debounceDuration;

  /// Hint text for the search field
  final String hintText;

  /// Whether the search field is enabled
  final bool enabled;

  /// Whether to auto-focus the search field
  final bool autofocus;

  const WorkflowSearchBar({
    super.key,
    this.initialValue = '',
    required this.onSearch,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.hintText = 'Search workflows...',
    this.enabled = true,
    this.autofocus = false,
  });

  @override
  State<WorkflowSearchBar> createState() => _WorkflowSearchBarState();
}

class _WorkflowSearchBarState extends State<WorkflowSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounceTimer;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(WorkflowSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller if initial value changes externally
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      widget.onSearch(value);
    });
  }

  void _clearSearch() {
    _controller.clear();
    _debounceTimer?.cancel();
    widget.onSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: colorScheme.surface,
      child: Focus(
        onFocusChange: (hasFocus) => setState(() => _hasFocus = hasFocus),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hasFocus
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hasFocus
                  ? colorScheme.primary.withOpacity(0.5)
                  : colorScheme.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Search icon
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.search,
                  size: 18,
                  color: _hasFocus
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),

              // Text field
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  onChanged: _onSearchChanged,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),

              // Clear button
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: _clearSearch,
                  tooltip: 'Clear search',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact inline search field for toolbar integration
class WorkflowSearchField extends StatefulWidget {
  final String initialValue;
  final void Function(String query) onSearch;
  final Duration debounceDuration;
  final String hintText;
  final bool enabled;
  final double? width;

  const WorkflowSearchField({
    super.key,
    this.initialValue = '',
    required this.onSearch,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.hintText = 'Search...',
    this.enabled = true,
    this.width,
  });

  @override
  State<WorkflowSearchField> createState() => _WorkflowSearchFieldState();
}

class _WorkflowSearchFieldState extends State<WorkflowSearchField> {
  late final TextEditingController _controller;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      widget.onSearch(value);
    });
  }

  void _clearSearch() {
    _controller.clear();
    _debounceTimer?.cancel();
    widget.onSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: widget.width ?? 200,
      child: TextField(
        controller: _controller,
        enabled: widget.enabled,
        onChanged: _onSearchChanged,
        style: Theme.of(context).textTheme.bodySmall,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
          prefixIcon: Icon(
            Icons.search,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 36),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: _clearSearch,
                  visualDensity: VisualDensity.compact,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 32),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
      ),
    );
  }
}

/// Search bar with filter dropdown
class WorkflowSearchBarWithFilter extends StatefulWidget {
  final String initialValue;
  final String? selectedFilter;
  final List<String> filterOptions;
  final void Function(String query) onSearch;
  final void Function(String? filter) onFilterChanged;
  final Duration debounceDuration;
  final String hintText;

  const WorkflowSearchBarWithFilter({
    super.key,
    this.initialValue = '',
    this.selectedFilter,
    this.filterOptions = const [],
    required this.onSearch,
    required this.onFilterChanged,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.hintText = 'Search workflows...',
  });

  @override
  State<WorkflowSearchBarWithFilter> createState() => _WorkflowSearchBarWithFilterState();
}

class _WorkflowSearchBarWithFilterState extends State<WorkflowSearchBarWithFilter> {
  late final TextEditingController _controller;
  Timer? _debounceTimer;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      widget.onSearch(value);
    });
  }

  void _clearSearch() {
    _controller.clear();
    _debounceTimer?.cancel();
    widget.onSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: colorScheme.surface,
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Focus(
              onFocusChange: (hasFocus) => setState(() => _hasFocus = hasFocus),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _hasFocus
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _hasFocus
                        ? colorScheme.primary.withOpacity(0.5)
                        : colorScheme.outlineVariant.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        Icons.search,
                        size: 18,
                        color: _hasFocus
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: _onSearchChanged,
                        style: Theme.of(context).textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                              ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: _clearSearch,
                        tooltip: 'Clear search',
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(8),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Filter dropdown
          if (widget.filterOptions.isNotEmpty) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String?>(
              initialValue: widget.selectedFilter,
              onSelected: widget.onFilterChanged,
              tooltip: 'Filter',
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 18,
                    color: widget.selectedFilter != null
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  if (widget.selectedFilter != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              itemBuilder: (context) => [
                PopupMenuItem<String?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(
                        Icons.clear_all,
                        size: 18,
                        color: widget.selectedFilter == null
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'All',
                        style: TextStyle(
                          fontWeight: widget.selectedFilter == null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                ...widget.filterOptions.map((filter) => PopupMenuItem<String>(
                      value: filter,
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 18,
                            color: widget.selectedFilter == filter
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            filter,
                            style: TextStyle(
                              fontWeight: widget.selectedFilter == filter
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Search suggestions widget for autocomplete
class WorkflowSearchSuggestions extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String suggestion) onSuggestionSelected;
  final bool isVisible;

  const WorkflowSearchSuggestions({
    super.key,
    required this.suggestions,
    required this.onSuggestionSelected,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible || suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];

          return InkWell(
            onTap: () => onSuggestionSelected(suggestion),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
