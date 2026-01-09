import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'comfyui_service.dart';

/// Autocomplete service provider
final autocompleteServiceProvider = Provider<AutocompleteService>((ref) {
  final comfyService = ref.watch(comfyUIServiceProvider);
  return AutocompleteService(comfyService);
});

/// Tag category enum matching danbooru/e621 conventions
enum TagCategory {
  general(0, 'General', 0xFF2196F3), // Blue
  artist(1, 'Artist', 0xFFE91E63), // Red/Pink
  copyright(3, 'Copyright', 0xFF9C27B0), // Purple
  character(4, 'Character', 0xFF4CAF50), // Green
  meta(5, 'Meta', 0xFFFF9800), // Orange
  species(6, 'Species', 0xFF795548), // Brown (e621)
  lora(100, 'LoRA', 0xFFFFD700), // Gold
  embedding(101, 'Embedding', 0xFF00CED1), // Cyan
  model(102, 'Model', 0xFFFF4500), // OrangeRed
  syntax(200, 'Syntax', 0xFF9E9E9E); // Grey

  final int id;
  final String label;
  final int colorValue;

  const TagCategory(this.id, this.label, this.colorValue);

  static TagCategory fromId(int id) {
    return TagCategory.values.firstWhere(
      (c) => c.id == id,
      orElse: () => TagCategory.general,
    );
  }
}

/// Tag suggestion model
class TagSuggestion {
  final String tag;
  final String displayTag;
  final TagCategory category;
  final int count;
  final String? alias;

  const TagSuggestion({
    required this.tag,
    required this.displayTag,
    required this.category,
    this.count = 0,
    this.alias,
  });

  /// Create from CSV line (danbooru/e621 format: tag_name,category_id,count)
  factory TagSuggestion.fromCsvLine(String line) {
    final parts = line.split(',');
    if (parts.isEmpty) {
      return const TagSuggestion(
        tag: '',
        displayTag: '',
        category: TagCategory.general,
      );
    }

    final tag = parts[0].trim();
    final displayTag = tag.replaceAll('_', ' ');
    final categoryId = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final count = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    final alias = parts.length > 3 ? parts[3].trim() : null;

    return TagSuggestion(
      tag: tag,
      displayTag: displayTag,
      category: TagCategory.fromId(categoryId),
      count: count,
      alias: alias?.isNotEmpty == true ? alias : null,
    );
  }

  /// Create for model/LoRA
  factory TagSuggestion.forModel(String name, TagCategory category) {
    final displayName = name.split('/').last.replaceAll('.safetensors', '');
    return TagSuggestion(
      tag: name,
      displayTag: displayName,
      category: category,
    );
  }

  /// Create for syntax completion
  factory TagSuggestion.forSyntax(String syntax, String description) {
    return TagSuggestion(
      tag: syntax,
      displayTag: description,
      category: TagCategory.syntax,
    );
  }
}

/// Trie node for fast prefix search
class _TrieNode {
  final Map<String, _TrieNode> children = {};
  final List<int> tagIndices = [];
}

/// Autocomplete service for prompt field
/// Handles tag files, model names, LoRA names, and syntax completions
class AutocompleteService {
  final ComfyUIService _comfyService;

  /// All loaded tags
  final List<TagSuggestion> _tags = [];

  /// Trie for fast prefix search
  final _TrieNode _trie = _TrieNode();

  /// Model/LoRA completions (refreshed from API)
  final List<TagSuggestion> _modelCompletions = [];
  final List<TagSuggestion> _loraCompletions = [];
  final List<TagSuggestion> _embeddingCompletions = [];

  /// Syntax completions for SwarmUI/EriUI prompt syntax
  final List<TagSuggestion> _syntaxCompletions = [
    TagSuggestion.forSyntax('<lora:', 'Apply LoRA with weight'),
    TagSuggestion.forSyntax('<lyco:', 'Apply LyCORIS with weight'),
    TagSuggestion.forSyntax('<embedding:', 'Use textual inversion embedding'),
    TagSuggestion.forSyntax('<wildcard:', 'Random selection from wildcard file'),
    TagSuggestion.forSyntax('<random:', 'Random number or selection'),
    TagSuggestion.forSyntax('<segment:', 'Segmentation region'),
    TagSuggestion.forSyntax('<preset:', 'Apply preset'),
    TagSuggestion.forSyntax('<break>', 'BREAK token for SD attention'),
    TagSuggestion.forSyntax('<clear>', 'Clear regional prompt'),
    TagSuggestion.forSyntax('(text:1.2)', 'Increase attention weight'),
    TagSuggestion.forSyntax('[text]', 'Decrease attention weight'),
    TagSuggestion.forSyntax('[from:to:0.5]', 'Prompt scheduling'),
  ];

  /// Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Whether tags are loaded
  bool _tagsLoaded = false;
  bool get tagsLoaded => _tagsLoaded;

  AutocompleteService(this._comfyService);

  /// Initialize the service and load tag files
  Future<void> initialize() async {
    if (_isLoading || _tagsLoaded) return;
    _isLoading = true;

    try {
      // Load tags from various sources in parallel
      await Future.wait([
        _loadTagFilesFromAssets(),
        _loadTagFilesFromUserDirectory(),
        _refreshModelCompletions(),
      ]);

      _tagsLoaded = true;
    } finally {
      _isLoading = false;
    }
  }

  /// Load tag files from Flutter assets
  Future<void> _loadTagFilesFromAssets() async {
    try {
      // Try to load common tag files from assets
      final assetFiles = [
        'assets/tags/danbooru.csv',
        'assets/tags/e621.csv',
        'assets/tags/tags.csv',
      ];

      for (final assetPath in assetFiles) {
        try {
          final data = await rootBundle.loadString(assetPath);
          _parseTagFile(data);
        } catch (_) {
          // Asset doesn't exist, skip
        }
      }
    } catch (e) {
      // No tag assets available
    }
  }

  /// Load tag files from user directory
  Future<void> _loadTagFilesFromUserDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final tagsDir = Directory(path.join(appDir.path, 'EriUI', 'tags'));

      if (!await tagsDir.exists()) {
        await tagsDir.create(recursive: true);
        return;
      }

      final files = await tagsDir.list().toList();
      for (final file in files) {
        if (file is File) {
          final ext = path.extension(file.path).toLowerCase();
          if (ext == '.csv' || ext == '.txt') {
            try {
              final data = await file.readAsString();
              _parseTagFile(data);
            } catch (_) {
              // Skip files that can't be read
            }
          }
        }
      }
    } catch (e) {
      // User directory not accessible
    }
  }

  /// Parse tag file content (CSV or TXT format)
  void _parseTagFile(String content) {
    final lines = const LineSplitter().convert(content);
    final startIndex = _tags.length;

    for (final line in lines) {
      if (line.trim().isEmpty || line.startsWith('#')) continue;

      final suggestion = TagSuggestion.fromCsvLine(line);
      if (suggestion.tag.isNotEmpty) {
        _tags.add(suggestion);
      }
    }

    // Build trie for new tags
    for (int i = startIndex; i < _tags.length; i++) {
      _addToTrie(_tags[i].tag.toLowerCase(), i);
      // Also index by display name for space-separated search
      if (_tags[i].displayTag != _tags[i].tag) {
        _addToTrie(_tags[i].displayTag.toLowerCase(), i);
      }
    }
  }

  /// Add tag to trie for prefix search
  void _addToTrie(String text, int index) {
    var node = _trie;
    for (final char in text.split('')) {
      node = node.children.putIfAbsent(char, () => _TrieNode());
    }
    if (!node.tagIndices.contains(index)) {
      node.tagIndices.add(index);
    }
  }

  /// Refresh model/LoRA completions from ComfyUI API
  Future<void> _refreshModelCompletions() async {
    try {
      // Fetch checkpoints from ComfyUI
      final checkpoints = await _comfyService.getCheckpoints();
      _modelCompletions.clear();
      _modelCompletions.addAll(
        checkpoints.map((name) => TagSuggestion.forModel(
              name,
              TagCategory.model,
            )),
      );

      // Fetch LoRAs from ComfyUI
      final loras = await _comfyService.getLoras();
      _loraCompletions.clear();
      _loraCompletions.addAll(
        loras.map((name) => TagSuggestion.forModel(
              name,
              TagCategory.lora,
            )),
      );

      // Fetch Embeddings from ComfyUI
      final embeddings = await _comfyService.getEmbeddings();
      _embeddingCompletions.clear();
      _embeddingCompletions.addAll(
        embeddings.map((name) => TagSuggestion.forModel(
              name,
              TagCategory.embedding,
            )),
      );
    } catch (_) {
      // ComfyUI API not available
    }
  }

  /// Load custom tag file from path
  Future<bool> loadTagFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final content = await file.readAsString();
      _parseTagFile(content);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Search tags by prefix (fast trie-based search)
  List<TagSuggestion> searchTags(String query, {int limit = 50}) {
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    final results = <TagSuggestion>[];
    final seenTags = <String>{};

    // Walk trie to find prefix matches
    var node = _trie;
    for (final char in lowerQuery.split('')) {
      final child = node.children[char];
      if (child == null) break;
      node = child;
    }

    // Collect all tag indices from this node and descendants
    _collectFromTrie(node, results, seenTags, limit * 2);

    // Sort by count (popularity) descending
    results.sort((a, b) => b.count.compareTo(a.count));

    return results.take(limit).toList();
  }

  /// Recursively collect tag indices from trie
  void _collectFromTrie(
    _TrieNode node,
    List<TagSuggestion> results,
    Set<String> seen,
    int limit,
  ) {
    if (results.length >= limit) return;

    // Add tags at this node
    for (final idx in node.tagIndices) {
      if (idx < _tags.length) {
        final tag = _tags[idx];
        if (!seen.contains(tag.tag)) {
          seen.add(tag.tag);
          results.add(tag);
          if (results.length >= limit) return;
        }
      }
    }

    // Recurse into children
    for (final child in node.children.values) {
      _collectFromTrie(child, results, seen, limit);
      if (results.length >= limit) return;
    }
  }

  /// Get syntax completions (when user types `<`)
  List<TagSuggestion> getSyntaxCompletions(String query) {
    if (query.isEmpty) return _syntaxCompletions;

    final lowerQuery = query.toLowerCase();
    return _syntaxCompletions
        .where((s) =>
            s.tag.toLowerCase().startsWith(lowerQuery) ||
            s.displayTag.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Get LoRA completions (for <lora: syntax)
  List<TagSuggestion> getLoraCompletions(String query) {
    if (query.isEmpty) return _loraCompletions.take(50).toList();

    final lowerQuery = query.toLowerCase();
    return _loraCompletions
        .where((s) => s.displayTag.toLowerCase().contains(lowerQuery))
        .take(50)
        .toList();
  }

  /// Get embedding completions (for <embedding: syntax)
  List<TagSuggestion> getEmbeddingCompletions(String query) {
    if (query.isEmpty) return _embeddingCompletions.take(50).toList();

    final lowerQuery = query.toLowerCase();
    return _embeddingCompletions
        .where((s) => s.displayTag.toLowerCase().contains(lowerQuery))
        .take(50)
        .toList();
  }

  /// Get model completions
  List<TagSuggestion> getModelCompletions(String query) {
    if (query.isEmpty) return _modelCompletions.take(50).toList();

    final lowerQuery = query.toLowerCase();
    return _modelCompletions
        .where((s) => s.displayTag.toLowerCase().contains(lowerQuery))
        .take(50)
        .toList();
  }

  /// Get completions based on current context
  /// Analyzes cursor position and surrounding text to determine what to complete
  List<TagSuggestion> getCompletions(String text, int cursorPosition) {
    if (text.isEmpty || cursorPosition == 0) return [];

    // Find the current "word" being typed
    final beforeCursor = text.substring(0, cursorPosition);

    // Check for special syntax patterns
    final syntaxMatch = RegExp(r'<([a-z]*):?([^>]*)$', caseSensitive: false)
        .firstMatch(beforeCursor);

    if (syntaxMatch != null) {
      final syntaxType = syntaxMatch.group(1)?.toLowerCase() ?? '';
      final innerQuery = syntaxMatch.group(2) ?? '';

      // Check what type of completion to show
      if (syntaxType == 'lora' || syntaxType == 'lyco') {
        return getLoraCompletions(innerQuery);
      } else if (syntaxType == 'embedding') {
        return getEmbeddingCompletions(innerQuery);
      } else if (syntaxType.isEmpty) {
        // Just typed `<`, show syntax options
        return getSyntaxCompletions('');
      } else {
        // Partial syntax type, filter syntax completions
        return getSyntaxCompletions('<$syntaxType');
      }
    }

    // Regular tag completion - find current word
    final wordMatch = RegExp(r'[\w_-]+$').firstMatch(beforeCursor);
    if (wordMatch == null) return [];

    final currentWord = wordMatch.group(0) ?? '';
    if (currentWord.length < 2) return []; // Require at least 2 chars

    return searchTags(currentWord);
  }

  /// Get the word boundaries for replacement at cursor position
  (int start, int end)? getWordBoundaries(String text, int cursorPosition) {
    if (text.isEmpty || cursorPosition == 0) return null;

    final beforeCursor = text.substring(0, cursorPosition);
    final afterCursor = text.substring(cursorPosition);

    // Check for syntax completion
    final syntaxMatch = RegExp(r'<[^>]*$').firstMatch(beforeCursor);
    if (syntaxMatch != null) {
      final start = syntaxMatch.start;
      // Find closing > if exists
      final closeMatch = RegExp(r'^[^>]*>?').firstMatch(afterCursor);
      final endOffset = closeMatch?.group(0)?.endsWith('>') == true
          ? closeMatch!.end
          : closeMatch?.end ?? 0;
      return (start, cursorPosition + endOffset);
    }

    // Regular word boundaries
    final wordMatch = RegExp(r'[\w_-]+$').firstMatch(beforeCursor);
    if (wordMatch == null) return null;

    final start = wordMatch.start;

    // Extend to include rest of word after cursor
    final afterMatch = RegExp(r'^[\w_-]*').firstMatch(afterCursor);
    final end = cursorPosition + (afterMatch?.end ?? 0);

    return (start, end);
  }

  /// Format tag for insertion (handle underscores, escaping)
  String formatTagForInsertion(TagSuggestion suggestion, String context) {
    // For syntax completions, use the tag as-is
    if (suggestion.category == TagCategory.syntax) {
      return suggestion.tag;
    }

    // For LoRA/embedding in special syntax, just return the name
    if (suggestion.category == TagCategory.lora ||
        suggestion.category == TagCategory.embedding) {
      // Check if we're inside a syntax block
      if (context.contains('<lora:') || context.contains('<lyco:')) {
        return '${suggestion.tag}:1>';
      }
      if (context.contains('<embedding:')) {
        return '${suggestion.tag}>';
      }
      // Standalone, wrap in proper syntax
      if (suggestion.category == TagCategory.lora) {
        return '<lora:${suggestion.tag}:1>';
      }
      return '<embedding:${suggestion.tag}>';
    }

    // Regular tags - use underscores (standard for danbooru-style prompts)
    // But many models prefer spaces, so use the original tag format
    return suggestion.tag;
  }

  /// Get total number of loaded tags
  int get tagCount => _tags.length;

  /// Get stats about loaded data
  Map<String, int> get stats => {
        'tags': _tags.length,
        'models': _modelCompletions.length,
        'loras': _loraCompletions.length,
        'embeddings': _embeddingCompletions.length,
      };
}
