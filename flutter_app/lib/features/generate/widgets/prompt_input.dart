import 'package:flutter/material.dart';

/// Prompt input widget
class PromptInput extends StatefulWidget {
  final String prompt;
  final String negativePrompt;
  final ValueChanged<String> onPromptChanged;
  final ValueChanged<String> onNegativePromptChanged;
  final bool enabled;

  const PromptInput({
    super.key,
    required this.prompt,
    required this.negativePrompt,
    required this.onPromptChanged,
    required this.onNegativePromptChanged,
    this.enabled = true,
  });

  @override
  State<PromptInput> createState() => _PromptInputState();
}

class _PromptInputState extends State<PromptInput> {
  late TextEditingController _promptController;
  late TextEditingController _negativeController;
  bool _showNegative = false;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.prompt);
    _negativeController = TextEditingController(text: widget.negativePrompt);
    _showNegative = widget.negativePrompt.isNotEmpty;
  }

  @override
  void didUpdateWidget(PromptInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prompt != oldWidget.prompt &&
        widget.prompt != _promptController.text) {
      _promptController.text = widget.prompt;
    }
    if (widget.negativePrompt != oldWidget.negativePrompt &&
        widget.negativePrompt != _negativeController.text) {
      _negativeController.text = widget.negativePrompt;
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prompt header
        Row(
          children: [
            Text(
              'Prompt',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: widget.enabled
                  ? () => setState(() => _showNegative = !_showNegative)
                  : null,
              icon: Icon(
                _showNegative ? Icons.remove : Icons.add,
                size: 16,
              ),
              label: Text(_showNegative ? 'Hide negative' : 'Add negative'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Prompt input
        TextField(
          controller: _promptController,
          enabled: widget.enabled,
          maxLines: 4,
          minLines: 3,
          decoration: InputDecoration(
            hintText: 'Describe what you want to generate...',
            alignLabelWithHint: true,
            suffixIcon: _promptController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: widget.enabled
                        ? () {
                            _promptController.clear();
                            widget.onPromptChanged('');
                          }
                        : null,
                  )
                : null,
          ),
          onChanged: widget.onPromptChanged,
        ),
        // Token count hint
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${_promptController.text.split(' ').where((s) => s.isNotEmpty).length} words',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
          ),
        ),
        // Negative prompt
        if (_showNegative) ...[
          const SizedBox(height: 16),
          Text(
            'Negative Prompt',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _negativeController,
            enabled: widget.enabled,
            maxLines: 2,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: 'What to avoid...',
            ),
            onChanged: widget.onNegativePromptChanged,
          ),
        ],
      ],
    );
  }
}

/// Quick prompt suggestions
class PromptSuggestions extends StatelessWidget {
  final ValueChanged<String> onSuggestionTapped;

  const PromptSuggestions({
    super.key,
    required this.onSuggestionTapped,
  });

  static const List<String> _suggestions = [
    'masterpiece, best quality',
    'highly detailed',
    '8k resolution',
    'cinematic lighting',
    'photorealistic',
    'digital art',
    'concept art',
    'anime style',
    'oil painting',
    'watercolor',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _suggestions.map((suggestion) {
        return ActionChip(
          label: Text(suggestion),
          onPressed: () => onSuggestionTapped(suggestion),
        );
      }).toList(),
    );
  }
}
