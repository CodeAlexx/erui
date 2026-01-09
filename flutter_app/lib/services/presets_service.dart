import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/preset.dart';
import 'storage_service.dart';

/// Key for storing presets in Hive
const String _presetsKey = 'eriui_presets';

/// Presets service provider
final presetsServiceProvider = Provider<PresetsService>((ref) {
  return PresetsService();
});

/// Presets state provider
final presetsProvider =
    StateNotifierProvider<PresetsNotifier, PresetsState>((ref) {
  final service = ref.watch(presetsServiceProvider);
  return PresetsNotifier(service);
});

/// Current folder provider for navigation
final currentPresetFolderProvider = StateProvider<String?>((ref) => null);

/// Filtered presets provider (by current folder)
final filteredPresetsProvider = Provider<List<Preset>>((ref) {
  final state = ref.watch(presetsProvider);
  final currentFolder = ref.watch(currentPresetFolderProvider);

  return state.presets.where((preset) {
    if (currentFolder == null) {
      // Root level - show presets without folder
      return preset.folder == null || preset.folder!.isEmpty;
    }
    // Show presets in current folder
    return preset.folder == currentFolder;
  }).toList();
});

/// Folders provider
final presetFoldersProvider = Provider<List<PresetFolder>>((ref) {
  final state = ref.watch(presetsProvider);
  final currentFolder = ref.watch(currentPresetFolderProvider);

  // Get unique folders from presets
  final folderPaths = <String>{};
  for (final preset in state.presets) {
    if (preset.folder != null && preset.folder!.isNotEmpty) {
      folderPaths.add(preset.folder!);
    }
  }

  // Filter to show only immediate children of current folder
  final folders = <PresetFolder>[];
  for (final path in folderPaths) {
    String? immediateChild;

    if (currentFolder == null) {
      // At root, get top-level folder names
      final parts = path.split('/');
      if (parts.isNotEmpty) {
        immediateChild = parts.first;
      }
    } else {
      // In a folder, get immediate children
      if (path.startsWith('$currentFolder/')) {
        final remaining = path.substring(currentFolder.length + 1);
        final parts = remaining.split('/');
        if (parts.isNotEmpty) {
          immediateChild = '$currentFolder/${parts.first}';
        }
      }
    }

    if (immediateChild != null && !folders.any((f) => f.path == immediateChild)) {
      final count = state.presets.where((p) =>
        p.folder == immediateChild ||
        (p.folder?.startsWith('$immediateChild/') ?? false)
      ).length;

      folders.add(PresetFolder(
        name: immediateChild.split('/').last,
        parentFolder: currentFolder,
        presetCount: count,
      ));
    }
  }

  folders.sort((a, b) => a.name.compareTo(b.name));
  return folders;
});

/// Presets state
class PresetsState {
  final List<Preset> presets;
  final bool isLoading;
  final String? error;

  const PresetsState({
    this.presets = const [],
    this.isLoading = false,
    this.error,
  });

  PresetsState copyWith({
    List<Preset>? presets,
    bool? isLoading,
    String? error,
  }) {
    return PresetsState(
      presets: presets ?? this.presets,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Presets notifier for state management
class PresetsNotifier extends StateNotifier<PresetsState> {
  final PresetsService _service;

  PresetsNotifier(this._service) : super(const PresetsState()) {
    loadPresets();
  }

  /// Load all presets from storage
  Future<void> loadPresets() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final presets = await _service.loadPresets();
      state = state.copyWith(presets: presets, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Save a new preset
  Future<void> savePreset(Preset preset) async {
    try {
      await _service.savePreset(preset);
      final updatedList = [...state.presets];
      final existingIndex = updatedList.indexWhere((p) => p.id == preset.id);
      if (existingIndex >= 0) {
        updatedList[existingIndex] = preset;
      } else {
        updatedList.add(preset);
      }
      state = state.copyWith(presets: updatedList, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Update an existing preset
  Future<void> updatePreset(Preset preset) async {
    try {
      final updated = preset.copyWith(updatedAt: DateTime.now());
      await _service.savePreset(updated);
      final updatedList = state.presets.map((p) {
        return p.id == updated.id ? updated : p;
      }).toList();
      state = state.copyWith(presets: updatedList, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Delete a preset
  Future<void> deletePreset(String id) async {
    try {
      await _service.deletePreset(id);
      final updatedList = state.presets.where((p) => p.id != id).toList();
      state = state.copyWith(presets: updatedList, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Delete all presets in a folder
  Future<void> deleteFolder(String folderPath) async {
    try {
      final toDelete = state.presets.where((p) =>
          p.folder == folderPath ||
          (p.folder?.startsWith('$folderPath/') ?? false));

      for (final preset in toDelete) {
        await _service.deletePreset(preset.id);
      }

      final updatedList = state.presets.where((p) =>
          p.folder != folderPath &&
          !(p.folder?.startsWith('$folderPath/') ?? false)).toList();

      state = state.copyWith(presets: updatedList, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Move a preset to a different folder
  Future<void> movePreset(String id, String? newFolder) async {
    final preset = state.presets.firstWhere((p) => p.id == id);
    final updated = preset.copyWith(
      folder: newFolder,
      updatedAt: DateTime.now(),
    );
    await updatePreset(updated);
  }

  /// Rename a folder
  Future<void> renameFolder(String oldPath, String newPath) async {
    try {
      final updatedPresets = <Preset>[];

      for (final preset in state.presets) {
        if (preset.folder == oldPath) {
          updatedPresets.add(preset.copyWith(
            folder: newPath,
            updatedAt: DateTime.now(),
          ));
        } else if (preset.folder?.startsWith('$oldPath/') ?? false) {
          updatedPresets.add(preset.copyWith(
            folder: preset.folder!.replaceFirst(oldPath, newPath),
            updatedAt: DateTime.now(),
          ));
        } else {
          updatedPresets.add(preset);
        }
      }

      await _service.saveAllPresets(updatedPresets);
      state = state.copyWith(presets: updatedPresets, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Import presets from JSON
  Future<int> importPresets(String jsonString, {bool merge = true}) async {
    try {
      final imported = _service.parsePresetsJson(jsonString);

      if (!merge) {
        // Replace all presets
        await _service.saveAllPresets(imported);
        state = state.copyWith(presets: imported, error: null);
        return imported.length;
      }

      // Merge with existing presets
      final merged = [...state.presets];
      int addedCount = 0;

      for (final preset in imported) {
        final existingIndex = merged.indexWhere((p) => p.id == preset.id);
        if (existingIndex >= 0) {
          merged[existingIndex] = preset;
        } else {
          merged.add(preset);
          addedCount++;
        }
      }

      await _service.saveAllPresets(merged);
      state = state.copyWith(presets: merged, error: null);
      return addedCount;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Export presets to JSON
  String exportPresets({List<String>? ids, String? folder}) {
    List<Preset> toExport;

    if (ids != null) {
      toExport = state.presets.where((p) => ids.contains(p.id)).toList();
    } else if (folder != null) {
      toExport = state.presets.where((p) =>
          p.folder == folder ||
          (p.folder?.startsWith('$folder/') ?? false)).toList();
    } else {
      toExport = state.presets;
    }

    return _service.exportPresetsToJson(toExport);
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Service for managing presets in local storage
class PresetsService {
  final _uuid = const Uuid();

  /// Generate a new unique ID for a preset
  String generateId() => _uuid.v4();

  /// Load all presets from storage
  Future<List<Preset>> loadPresets() async {
    final jsonString = StorageService.getStringStatic(_presetsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => Preset.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading presets: $e');
      return [];
    }
  }

  /// Save a single preset (updates or adds)
  Future<void> savePreset(Preset preset) async {
    final presets = await loadPresets();
    final existingIndex = presets.indexWhere((p) => p.id == preset.id);

    if (existingIndex >= 0) {
      presets[existingIndex] = preset;
    } else {
      presets.add(preset);
    }

    await saveAllPresets(presets);
  }

  /// Save all presets to storage
  Future<void> saveAllPresets(List<Preset> presets) async {
    final jsonList = presets.map((p) => p.toJson()).toList();
    await StorageService.setStringStatic(_presetsKey, jsonEncode(jsonList));
  }

  /// Delete a preset by ID
  Future<void> deletePreset(String id) async {
    final presets = await loadPresets();
    presets.removeWhere((p) => p.id == id);
    await saveAllPresets(presets);
  }

  /// Parse presets from JSON string
  List<Preset> parsePresetsJson(String jsonString) {
    final dynamic decoded = jsonDecode(jsonString);

    List<dynamic> jsonList;
    if (decoded is List) {
      jsonList = decoded;
    } else if (decoded is Map && decoded.containsKey('presets')) {
      jsonList = decoded['presets'] as List<dynamic>;
    } else {
      throw const FormatException('Invalid presets JSON format');
    }

    return jsonList
        .map((json) => Preset.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Export presets to JSON string
  String exportPresetsToJson(List<Preset> presets) {
    final jsonList = presets.map((p) => p.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'presets': jsonList,
    });
  }

  /// Create a preset from current generation parameters
  Preset createPresetFromParams({
    required String name,
    String? folder,
    String? description,
    String? prompt,
    String? negativePrompt,
    String? model,
    int? steps,
    double? cfgScale,
    int? width,
    int? height,
    String? sampler,
    String? scheduler,
    int? batchSize,
    int? seed,
    bool? videoMode,
    String? videoModel,
    int? frames,
    int? fps,
    String? videoFormat,
    Map<String, dynamic>? extraParams,
    String? thumbnail,
  }) {
    return Preset(
      id: generateId(),
      name: name,
      folder: folder,
      description: description,
      prompt: prompt,
      negativePrompt: negativePrompt,
      model: model,
      steps: steps,
      cfgScale: cfgScale,
      width: width,
      height: height,
      sampler: sampler,
      scheduler: scheduler,
      batchSize: batchSize,
      seed: seed,
      videoMode: videoMode,
      videoModel: videoModel,
      frames: frames,
      fps: fps,
      videoFormat: videoFormat,
      extraParams: extraParams,
      createdAt: DateTime.now(),
      thumbnail: thumbnail,
    );
  }
}
