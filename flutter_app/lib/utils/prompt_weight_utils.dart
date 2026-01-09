import 'package:flutter/material.dart';

/// Utilities for SD/ComfyUI prompt weighting syntax
/// Supports (text:weight) format with Ctrl+Up/Down to adjust weights

/// Increase weight of selected text or text around cursor
/// Returns the new text and updated selection
({String text, int selectionStart, int selectionEnd}) increaseWeight(
  String text,
  int selectionStart,
  int selectionEnd,
) {
  return _adjustWeight(text, selectionStart, selectionEnd, 0.1);
}

/// Decrease weight of selected text or text around cursor
/// Returns the new text and updated selection
({String text, int selectionStart, int selectionEnd}) decreaseWeight(
  String text,
  int selectionStart,
  int selectionEnd,
) {
  return _adjustWeight(text, selectionStart, selectionEnd, -0.1);
}

/// Core weight adjustment logic
({String text, int selectionStart, int selectionEnd}) _adjustWeight(
  String text,
  int selectionStart,
  int selectionEnd,
  double delta,
) {
  // If no selection, try to find weighted section around cursor
  if (selectionStart == selectionEnd) {
    final weighted = _findWeightedSectionAtCursor(text, selectionStart);
    if (weighted != null) {
      // Adjust existing weight
      return _adjustExistingWeight(text, weighted, delta);
    }
    // No weighted section found, try to find a word to wrap
    final word = _findWordAtCursor(text, selectionStart);
    if (word != null && delta > 0) {
      // Only wrap if increasing weight
      return _wrapWithWeight(text, word.start, word.end, 1.0 + delta);
    }
    return (text: text, selectionStart: selectionStart, selectionEnd: selectionEnd);
  }

  // Selection exists - check if it's inside a weighted section
  final weighted = _findWeightedSectionContaining(text, selectionStart, selectionEnd);
  if (weighted != null) {
    return _adjustExistingWeight(text, weighted, delta);
  }

  // Selection not in weighted section - wrap it (only if increasing)
  if (delta > 0) {
    return _wrapWithWeight(text, selectionStart, selectionEnd, 1.0 + delta);
  }
  return (text: text, selectionStart: selectionStart, selectionEnd: selectionEnd);
}

/// Find a weighted section (text:weight) that contains the cursor
_WeightedSection? _findWeightedSectionAtCursor(String text, int cursor) {
  // Look for pattern (text:weight) containing cursor
  final regex = RegExp(r'\(([^()]+):(\d+\.?\d*)\)');
  for (final match in regex.allMatches(text)) {
    if (cursor >= match.start && cursor <= match.end) {
      final weight = double.tryParse(match.group(2)!) ?? 1.0;
      return _WeightedSection(
        start: match.start,
        end: match.end,
        innerText: match.group(1)!,
        weight: weight,
      );
    }
  }
  return null;
}

/// Find a weighted section containing the given selection range
_WeightedSection? _findWeightedSectionContaining(String text, int start, int end) {
  final regex = RegExp(r'\(([^()]+):(\d+\.?\d*)\)');
  for (final match in regex.allMatches(text)) {
    if (start >= match.start && end <= match.end) {
      final weight = double.tryParse(match.group(2)!) ?? 1.0;
      return _WeightedSection(
        start: match.start,
        end: match.end,
        innerText: match.group(1)!,
        weight: weight,
      );
    }
  }
  return null;
}

/// Find word boundaries around cursor
({int start, int end})? _findWordAtCursor(String text, int cursor) {
  if (text.isEmpty) return null;

  // Don't select if cursor is at start/end or on whitespace
  if (cursor <= 0 || cursor > text.length) return null;

  int start = cursor;
  int end = cursor;

  // Expand backwards
  while (start > 0 && !_isWordBoundary(text[start - 1])) {
    start--;
  }

  // Expand forwards
  while (end < text.length && !_isWordBoundary(text[end])) {
    end++;
  }

  if (start == end) return null;
  return (start: start, end: end);
}

bool _isWordBoundary(String char) {
  return char == ' ' || char == ',' || char == '(' || char == ')' || char == ':';
}

/// Adjust weight of existing weighted section
({String text, int selectionStart, int selectionEnd}) _adjustExistingWeight(
  String text,
  _WeightedSection section,
  double delta,
) {
  final newWeight = section.weight + delta;

  // Round to 1 decimal place
  final roundedWeight = (newWeight * 10).round() / 10;

  if (roundedWeight <= 1.0) {
    // Remove weighting, just keep inner text
    final before = text.substring(0, section.start);
    final after = text.substring(section.end);
    final newText = before + section.innerText + after;
    return (
      text: newText,
      selectionStart: section.start,
      selectionEnd: section.start + section.innerText.length,
    );
  }

  // Update weight
  final newWeightStr = roundedWeight.toStringAsFixed(1);
  final replacement = '(${section.innerText}:$newWeightStr)';
  final before = text.substring(0, section.start);
  final after = text.substring(section.end);
  final newText = before + replacement + after;

  return (
    text: newText,
    selectionStart: section.start,
    selectionEnd: section.start + replacement.length,
  );
}

/// Wrap text with weight syntax
({String text, int selectionStart, int selectionEnd}) _wrapWithWeight(
  String text,
  int start,
  int end,
  double weight,
) {
  final selectedText = text.substring(start, end).trim();
  if (selectedText.isEmpty) {
    return (text: text, selectionStart: start, selectionEnd: end);
  }

  final weightStr = weight.toStringAsFixed(1);
  final replacement = '($selectedText:$weightStr)';
  final before = text.substring(0, start);
  final after = text.substring(end);
  final newText = before + replacement + after;

  return (
    text: newText,
    selectionStart: start,
    selectionEnd: start + replacement.length,
  );
}

class _WeightedSection {
  final int start;
  final int end;
  final String innerText;
  final double weight;

  _WeightedSection({
    required this.start,
    required this.end,
    required this.innerText,
    required this.weight,
  });
}

/// Count approximate CLIP tokens in a prompt
/// CLIP uses BPE tokenization; this is a rough approximation
int countTokens(String prompt) {
  if (prompt.isEmpty) return 0;

  // Remove weight syntax for counting
  final cleaned = prompt.replaceAll(RegExp(r'[():]+'), ' ');

  // Split by whitespace and punctuation
  final tokens = cleaned.split(RegExp(r'[\s,;]+'))
      .where((t) => t.isNotEmpty)
      .toList();

  // Rough estimate: most words are 1-2 tokens
  // Long words (>6 chars) tend to be 2+ tokens
  int count = 0;
  for (final token in tokens) {
    if (token.length <= 3) {
      count += 1;
    } else if (token.length <= 6) {
      count += 1;
    } else {
      // Longer words often split into multiple tokens
      count += (token.length / 4).ceil();
    }
  }

  return count;
}

/// Build TextSpans with highlighting for weighted sections and bracket matching
List<TextSpan> highlightWeights(
  String prompt, {
  required TextStyle baseStyle,
  required Color weightedColor,
  required Color weightedBackground,
  required Color bracketColor,
  int? cursorPosition,
}) {
  if (prompt.isEmpty) {
    return [TextSpan(text: '', style: baseStyle)];
  }

  final spans = <TextSpan>[];
  final regex = RegExp(r'\(([^()]+):(\d+\.?\d*)\)');
  int lastEnd = 0;

  // Find matching bracket for cursor
  int? matchingBracket;
  if (cursorPosition != null) {
    matchingBracket = _findMatchingBracket(prompt, cursorPosition);
  }

  for (final match in regex.allMatches(prompt)) {
    // Add text before this match
    if (match.start > lastEnd) {
      spans.add(_buildSpanWithBrackets(
        prompt.substring(lastEnd, match.start),
        lastEnd,
        baseStyle,
        bracketColor,
        cursorPosition,
        matchingBracket,
      ));
    }

    // Add the weighted section with highlighting
    final weight = double.tryParse(match.group(2)!) ?? 1.0;
    final intensity = ((weight - 1.0) * 2).clamp(0.0, 1.0);

    spans.add(TextSpan(
      text: match.group(0),
      style: baseStyle.copyWith(
        color: Color.lerp(baseStyle.color, weightedColor, intensity),
        backgroundColor: weightedBackground.withOpacity(0.1 + intensity * 0.2),
        fontWeight: weight > 1.2 ? FontWeight.w600 : null,
      ),
    ));

    lastEnd = match.end;
  }

  // Add remaining text
  if (lastEnd < prompt.length) {
    spans.add(_buildSpanWithBrackets(
      prompt.substring(lastEnd),
      lastEnd,
      baseStyle,
      bracketColor,
      cursorPosition,
      matchingBracket,
    ));
  }

  return spans.isEmpty ? [TextSpan(text: prompt, style: baseStyle)] : spans;
}

TextSpan _buildSpanWithBrackets(
  String text,
  int offset,
  TextStyle baseStyle,
  Color bracketColor,
  int? cursorPosition,
  int? matchingBracket,
) {
  // Simple case - no bracket highlighting needed
  if (cursorPosition == null || matchingBracket == null) {
    return TextSpan(text: text, style: baseStyle);
  }

  // Check if matching bracket is in this segment
  final bracketInSegment = matchingBracket >= offset &&
                           matchingBracket < offset + text.length;
  final cursorInSegment = cursorPosition >= offset &&
                          cursorPosition < offset + text.length;

  if (!bracketInSegment && !cursorInSegment) {
    return TextSpan(text: text, style: baseStyle);
  }

  // Build spans with bracket highlighting
  final spans = <TextSpan>[];
  for (int i = 0; i < text.length; i++) {
    final globalPos = offset + i;
    final char = text[i];
    final isHighlighted = globalPos == matchingBracket ||
                          (globalPos == cursorPosition - 1 &&
                           (char == '(' || char == ')'));

    if (isHighlighted && (char == '(' || char == ')')) {
      spans.add(TextSpan(
        text: char,
        style: baseStyle.copyWith(
          color: bracketColor,
          fontWeight: FontWeight.bold,
          backgroundColor: bracketColor.withOpacity(0.2),
        ),
      ));
    } else {
      // Try to batch consecutive non-highlighted chars
      int end = i + 1;
      while (end < text.length) {
        final nextPos = offset + end;
        final nextChar = text[end];
        final nextHighlighted = nextPos == matchingBracket ||
                                (nextPos == cursorPosition - 1 &&
                                 (nextChar == '(' || nextChar == ')'));
        if (nextHighlighted && (nextChar == '(' || nextChar == ')')) break;
        end++;
      }
      spans.add(TextSpan(text: text.substring(i, end), style: baseStyle));
      i = end - 1;
    }
  }

  return TextSpan(children: spans);
}

/// Find matching bracket for the one at or before cursor
int? _findMatchingBracket(String text, int cursor) {
  // Check character before cursor
  if (cursor > 0 && cursor <= text.length) {
    final char = text[cursor - 1];
    if (char == '(') {
      return _findClosingBracket(text, cursor - 1);
    } else if (char == ')') {
      return _findOpeningBracket(text, cursor - 1);
    }
  }

  // Check character at cursor
  if (cursor < text.length) {
    final char = text[cursor];
    if (char == '(') {
      return _findClosingBracket(text, cursor);
    } else if (char == ')') {
      return _findOpeningBracket(text, cursor);
    }
  }

  return null;
}

int? _findClosingBracket(String text, int openPos) {
  int depth = 1;
  for (int i = openPos + 1; i < text.length; i++) {
    if (text[i] == '(') depth++;
    if (text[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

int? _findOpeningBracket(String text, int closePos) {
  int depth = 1;
  for (int i = closePos - 1; i >= 0; i--) {
    if (text[i] == ')') depth++;
    if (text[i] == '(') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}
