import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_service.dart';

/// Provider for wildcards service
final wildcardsServiceProvider = Provider<WildcardsService>((ref) {
  return WildcardsService();
});

/// Provider for wildcards state
final wildcardsProvider =
    StateNotifierProvider<WildcardsNotifier, WildcardsState>((ref) {
  final service = ref.watch(wildcardsServiceProvider);
  return WildcardsNotifier(service);
});

/// Represents a single wildcard with a name and list of options
class Wildcard {
  final String name;
  final String folder;
  final List<String> options;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Wildcard({
    required this.name,
    required this.folder,
    required this.options,
    DateTime? createdAt,
    DateTime? modifiedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        modifiedAt = modifiedAt ?? DateTime.now();

  /// Get full path including folder (e.g., "animals/cats")
  String get fullPath => folder.isEmpty ? name : '$folder/$name';

  /// Get a random option from this wildcard
  String getRandomOption() {
    if (options.isEmpty) return '';
    final random = Random();
    return options[random.nextInt(options.length)];
  }

  /// Create from JSON map
  factory Wildcard.fromJson(Map<String, dynamic> json) {
    return Wildcard(
      name: json['name'] as String,
      folder: json['folder'] as String? ?? '',
      options: (json['options'] as List<dynamic>).cast<String>(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'folder': folder,
      'options': options,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
    };
  }

  /// Create a copy with modified fields
  Wildcard copyWith({
    String? name,
    String? folder,
    List<String>? options,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return Wildcard(
      name: name ?? this.name,
      folder: folder ?? this.folder,
      options: options ?? this.options,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? DateTime.now(),
    );
  }
}

/// Represents a folder in the wildcards hierarchy
class WildcardFolder {
  final String path;
  final String name;
  final List<WildcardFolder> subfolders;
  final List<Wildcard> wildcards;

  WildcardFolder({
    required this.path,
    required this.name,
    this.subfolders = const [],
    this.wildcards = const [],
  });

  /// Get the depth of this folder (0 for root level)
  int get depth => path.isEmpty ? 0 : path.split('/').length;
}

/// State for wildcards management
class WildcardsState {
  final List<Wildcard> wildcards;
  final List<String> folders;
  final String selectedFolder;
  final Wildcard? selectedWildcard;
  final bool isLoading;
  final String? error;

  const WildcardsState({
    this.wildcards = const [],
    this.folders = const [],
    this.selectedFolder = '',
    this.selectedWildcard,
    this.isLoading = false,
    this.error,
  });

  /// Get wildcards in the selected folder
  List<Wildcard> get filteredWildcards {
    if (selectedFolder.isEmpty) {
      return wildcards.where((w) => w.folder.isEmpty).toList();
    }
    return wildcards.where((w) => w.folder == selectedFolder).toList();
  }

  /// Get wildcards in a specific folder (including subfolders)
  List<Wildcard> getWildcardsInFolder(String folder, {bool recursive = false}) {
    if (!recursive) {
      return wildcards.where((w) => w.folder == folder).toList();
    }
    return wildcards
        .where((w) => w.folder == folder || w.folder.startsWith('$folder/'))
        .toList();
  }

  /// Build folder tree structure
  WildcardFolder buildFolderTree() {
    final rootWildcards = wildcards.where((w) => w.folder.isEmpty).toList();
    final subfolderMap = <String, List<Wildcard>>{};

    for (final wildcard in wildcards) {
      if (wildcard.folder.isNotEmpty) {
        subfolderMap.putIfAbsent(wildcard.folder, () => []).add(wildcard);
      }
    }

    return _buildFolderRecursive('', '', subfolderMap, rootWildcards);
  }

  WildcardFolder _buildFolderRecursive(
    String path,
    String name,
    Map<String, List<Wildcard>> wildcardMap,
    List<Wildcard> rootWildcards,
  ) {
    final directWildcards = path.isEmpty
        ? rootWildcards
        : wildcardMap[path] ?? [];

    // Find direct subfolders
    final subfoldersSet = <String>{};
    for (final folderPath in wildcardMap.keys) {
      if (path.isEmpty) {
        if (!folderPath.contains('/')) {
          subfoldersSet.add(folderPath);
        }
      } else if (folderPath.startsWith('$path/')) {
        final remainder = folderPath.substring(path.length + 1);
        if (!remainder.contains('/')) {
          subfoldersSet.add(folderPath);
        }
      }
    }

    final subfolders = subfoldersSet.map((subPath) {
      final subName = subPath.split('/').last;
      return _buildFolderRecursive(subPath, subName, wildcardMap, []);
    }).toList();

    return WildcardFolder(
      path: path,
      name: name.isEmpty ? 'Wildcards' : name,
      subfolders: subfolders,
      wildcards: directWildcards,
    );
  }

  WildcardsState copyWith({
    List<Wildcard>? wildcards,
    List<String>? folders,
    String? selectedFolder,
    Wildcard? selectedWildcard,
    bool clearSelectedWildcard = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return WildcardsState(
      wildcards: wildcards ?? this.wildcards,
      folders: folders ?? this.folders,
      selectedFolder: selectedFolder ?? this.selectedFolder,
      selectedWildcard: clearSelectedWildcard ? null : (selectedWildcard ?? this.selectedWildcard),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Wildcards service for storage and management
class WildcardsService {
  static const String _storageKey = 'wildcards_data';
  final Random _random = Random();

  /// Load all wildcards from storage
  Future<List<Wildcard>> loadWildcards() async {
    final data = StorageService.getStringStatic(_storageKey);
    if (data == null || data.isEmpty) {
      return _getDefaultWildcards();
    }

    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => Wildcard.fromJson(json)).toList();
    } catch (e) {
      return _getDefaultWildcards();
    }
  }

  /// Save all wildcards to storage
  Future<void> saveWildcards(List<Wildcard> wildcards) async {
    final jsonList = wildcards.map((w) => w.toJson()).toList();
    await StorageService.setStringStatic(_storageKey, jsonEncode(jsonList));
  }

  /// Get a random item from a wildcard by path
  String? getRandomItem(List<Wildcard> wildcards, String path) {
    // Path can be "name" or "folder/name"
    final wildcard = wildcards.firstWhere(
      (w) => w.fullPath == path,
      orElse: () => wildcards.firstWhere(
        (w) => w.name == path,
        orElse: () => Wildcard(name: '', folder: '', options: []),
      ),
    );

    if (wildcard.options.isEmpty) return null;
    return wildcard.options[_random.nextInt(wildcard.options.length)];
  }

  /// Parse text content into list of options (one per line)
  List<String> parseOptions(String content) {
    return content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// Format options list to text content
  String formatOptions(List<String> options) {
    return options.join('\n');
  }

  /// Get unique folder list from wildcards
  List<String> extractFolders(List<Wildcard> wildcards) {
    final folders = <String>{};
    for (final wildcard in wildcards) {
      if (wildcard.folder.isNotEmpty) {
        // Add the folder and all parent folders
        final parts = wildcard.folder.split('/');
        for (int i = 1; i <= parts.length; i++) {
          folders.add(parts.sublist(0, i).join('/'));
        }
      }
    }
    final sortedFolders = folders.toList()..sort();
    return sortedFolders;
  }

  /// Import wildcards from text (format: name\noption1\noption2...)
  Wildcard? importFromText(String name, String content, {String folder = ''}) {
    final options = parseOptions(content);
    if (options.isEmpty) return null;

    return Wildcard(
      name: name,
      folder: folder,
      options: options,
    );
  }

  /// Get default wildcards for new installations
  List<Wildcard> _getDefaultWildcards() {
    return [
      Wildcard(
        name: 'colors',
        folder: '',
        options: ['red', 'blue', 'green', 'yellow', 'purple', 'orange', 'pink', 'cyan'],
      ),
      Wildcard(
        name: 'animals',
        folder: '',
        options: ['cat', 'dog', 'bird', 'horse', 'elephant', 'tiger', 'lion', 'wolf'],
      ),
      Wildcard(
        name: 'anime',
        folder: 'styles',
        options: ['anime style', 'manga style', 'cel shaded', 'studio ghibli style'],
      ),
      Wildcard(
        name: 'photo',
        folder: 'styles',
        options: ['photorealistic', 'hyperrealistic', 'photograph', 'DSLR photo'],
      ),
    ];
  }
}

/// State notifier for wildcards management
class WildcardsNotifier extends StateNotifier<WildcardsState> {
  final WildcardsService _service;

  WildcardsNotifier(this._service) : super(const WildcardsState()) {
    loadWildcards();
  }

  /// Load wildcards from storage
  Future<void> loadWildcards() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final wildcards = await _service.loadWildcards();
      final folders = _service.extractFolders(wildcards);
      state = state.copyWith(
        wildcards: wildcards,
        folders: folders,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load wildcards: $e',
      );
    }
  }

  /// Select a folder
  void selectFolder(String folder) {
    state = state.copyWith(
      selectedFolder: folder,
      clearSelectedWildcard: true,
    );
  }

  /// Select a wildcard
  void selectWildcard(Wildcard? wildcard) {
    state = state.copyWith(selectedWildcard: wildcard);
  }

  /// Create a new wildcard
  Future<bool> createWildcard(Wildcard wildcard) async {
    try {
      // Check for duplicate names in the same folder
      final exists = state.wildcards.any(
        (w) => w.name == wildcard.name && w.folder == wildcard.folder,
      );
      if (exists) {
        state = state.copyWith(error: 'A wildcard with this name already exists in this folder');
        return false;
      }

      final updatedList = [...state.wildcards, wildcard];
      await _service.saveWildcards(updatedList);
      final folders = _service.extractFolders(updatedList);
      state = state.copyWith(
        wildcards: updatedList,
        folders: folders,
        selectedWildcard: wildcard,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create wildcard: $e');
      return false;
    }
  }

  /// Update an existing wildcard
  Future<bool> updateWildcard(Wildcard oldWildcard, Wildcard newWildcard) async {
    try {
      final index = state.wildcards.indexWhere(
        (w) => w.name == oldWildcard.name && w.folder == oldWildcard.folder,
      );
      if (index == -1) {
        state = state.copyWith(error: 'Wildcard not found');
        return false;
      }

      // Check for duplicate names if name/folder changed
      if (oldWildcard.name != newWildcard.name ||
          oldWildcard.folder != newWildcard.folder) {
        final exists = state.wildcards.any(
          (w) =>
              w.name == newWildcard.name &&
              w.folder == newWildcard.folder &&
              w != oldWildcard,
        );
        if (exists) {
          state = state.copyWith(error: 'A wildcard with this name already exists in this folder');
          return false;
        }
      }

      final updatedList = [...state.wildcards];
      updatedList[index] = newWildcard;
      await _service.saveWildcards(updatedList);
      final folders = _service.extractFolders(updatedList);
      state = state.copyWith(
        wildcards: updatedList,
        folders: folders,
        selectedWildcard: newWildcard,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update wildcard: $e');
      return false;
    }
  }

  /// Delete a wildcard
  Future<bool> deleteWildcard(Wildcard wildcard) async {
    try {
      final updatedList = state.wildcards
          .where((w) => !(w.name == wildcard.name && w.folder == wildcard.folder))
          .toList();
      await _service.saveWildcards(updatedList);
      final folders = _service.extractFolders(updatedList);
      state = state.copyWith(
        wildcards: updatedList,
        folders: folders,
        clearSelectedWildcard: state.selectedWildcard?.name == wildcard.name,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete wildcard: $e');
      return false;
    }
  }

  /// Get a random item from a wildcard
  String? getRandomItem(String path) {
    return _service.getRandomItem(state.wildcards, path);
  }

  /// Import wildcard from text content
  Future<bool> importFromText(String name, String content, {String? folder}) async {
    final wildcard = _service.importFromText(
      name,
      content,
      folder: folder ?? state.selectedFolder,
    );
    if (wildcard == null) {
      state = state.copyWith(error: 'Failed to parse wildcard content');
      return false;
    }
    return createWildcard(wildcard);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
