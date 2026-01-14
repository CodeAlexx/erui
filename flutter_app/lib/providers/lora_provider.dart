import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../services/comfyui_service.dart';

/// LoRA metadata server URL
const _loraMetadataUrl = 'http://localhost:7805';

/// LoRA/LyCORIS list provider - fetches from metadata server with base model info
final loraListProvider = FutureProvider<List<LoraModel>>((ref) async {
  final allModels = <LoraModel>[];

  try {
    // Try to fetch from metadata server first (has base model info)
    final response = await http.get(Uri.parse('$_loraMetadataUrl/loras'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final List<dynamic> loraData = json.decode(response.body);

      for (final data in loraData) {
        final name = data['name'] as String? ?? '';
        final filename = data['filename'] as String? ?? name;
        final baseModel = data['base_model'] as String? ?? 'unknown';
        final type = data['type'] as String? ?? 'LoRA';

        allModels.add(LoraModel(
          name: name,
          path: name,
          title: _formatLoraTitle(filename),
          previewImage: null,
          type: type,
          description: null,
          baseModel: baseModel,
        ));
      }

      return allModels;
    }
  } catch (e) {
    // Metadata server not available, fall back to ComfyUI
    print('LoRA metadata server not available: $e');
  }

  // Fallback: Fetch from ComfyUI backend (no base model info)
  final comfyService = ref.watch(comfyUIServiceProvider);
  final loraNames = await comfyService.getLoras();

  for (final name in loraNames) {
    // Detect type from filename
    final lowerName = name.toLowerCase();
    final type = (lowerName.contains('locon') ||
        lowerName.contains('loha') ||
        lowerName.contains('lokr') ||
        lowerName.contains('lycoris')) ? 'LyCORIS' : 'LoRA';

    allModels.add(LoraModel(
      name: name,
      path: name,
      title: _formatLoraTitle(name),
      previewImage: null,
      type: type,
      description: null,
      baseModel: null, // Unknown when using fallback
    ));
  }

  return allModels;
});

/// Format LoRA name for display
String _formatLoraTitle(String name) {
  // Remove file extension
  String title = name;
  if (title.endsWith('.safetensors')) {
    title = title.substring(0, title.length - 12);
  } else if (title.endsWith('.ckpt')) {
    title = title.substring(0, title.length - 5);
  } else if (title.endsWith('.pt')) {
    title = title.substring(0, title.length - 3);
  }

  // Remove path separators and get just the filename
  final parts = title.split(RegExp(r'[/\\]'));
  title = parts.last;

  return title;
}

/// LoRA filter text provider
final loraFilterProvider = StateProvider<String>((ref) => '');

/// Base model filter provider - filters LoRAs by compatible base model
/// Values: 'all', 'flux', 'sdxl', 'sd15', 'sd3', 'wan', 'ltx', 'hunyuan', etc.
final loraBaseModelFilterProvider = StateProvider<String>((ref) => 'all');

/// Available base model filter options
final loraBaseModelOptionsProvider = Provider<List<String>>((ref) {
  return ['all', 'flux', 'sdxl', 'sd15', 'sd3', 'wan', 'ltx', 'hunyuan', 'hidream', 'zimage', 'unknown'];
});

/// Get base model type from currently selected model name
String getBaseModelType(String modelName) {
  final lower = modelName.toLowerCase();

  if (lower.contains('flux')) return 'flux';
  if (lower.contains('sdxl') || lower.contains('xl')) return 'sdxl';
  if (lower.contains('sd3') || lower.contains('sd_3') || lower.contains('stable-diffusion-3')) return 'sd3';
  if (lower.contains('sd1') || lower.contains('sd_1') || lower.contains('v1-5') || lower.contains('1.5')) return 'sd15';
  if (lower.contains('wan')) return 'wan';
  if (lower.contains('ltx')) return 'ltx';
  if (lower.contains('hunyuan')) return 'hunyuan';
  if (lower.contains('hidream')) return 'hidream';
  if (lower.contains('zimage') || lower.contains('z-image') || lower.contains('z_image')) return 'zimage';
  if (lower.contains('kandinsky')) return 'kandinsky';

  return 'unknown';
}

/// Filtered LoRA list based on search AND base model filter
final filteredLoraListProvider = Provider<AsyncValue<List<LoraModel>>>((ref) {
  final filter = ref.watch(loraFilterProvider).toLowerCase();
  final baseModelFilter = ref.watch(loraBaseModelFilterProvider);
  final lorasAsync = ref.watch(loraListProvider);

  return lorasAsync.whenData((loras) {
    var filtered = loras;

    // Filter by base model if not 'all'
    if (baseModelFilter != 'all') {
      filtered = filtered.where((lora) {
        // If LoRA base model is unknown, show it (might be compatible)
        if (lora.baseModel == null || lora.baseModel == 'unknown') {
          return true;
        }
        return lora.baseModel!.toLowerCase() == baseModelFilter.toLowerCase();
      }).toList();
    }

    // Filter by search text
    if (filter.isNotEmpty) {
      filtered = filtered.where((lora) {
        return lora.name.toLowerCase().contains(filter) ||
               lora.title.toLowerCase().contains(filter) ||
               (lora.baseModel?.toLowerCase().contains(filter) ?? false);
      }).toList();
    }

    return filtered;
  });
});

/// Selected LoRAs provider
final selectedLorasProvider = StateNotifierProvider<SelectedLorasNotifier, List<SelectedLora>>((ref) {
  return SelectedLorasNotifier();
});

/// LoRA/LyCORIS model
class LoraModel {
  final String name;
  final String path;
  final String title;
  final String? previewImage;
  final String type; // 'LoRA' or 'LyCORIS'
  final String? description;
  final String? baseModel; // SD1.5, SDXL, Flux, etc.

  LoraModel({
    required this.name,
    required this.path,
    required this.title,
    this.previewImage,
    required this.type,
    this.description,
    this.baseModel,
  });

  /// Check if this is a LyCORIS model
  bool get isLycoris => type == 'LyCORIS' ||
      name.toLowerCase().contains('locon') ||
      name.toLowerCase().contains('loha') ||
      name.toLowerCase().contains('lokr') ||
      name.toLowerCase().contains('lycoris');

  factory LoraModel.fromJson(Map<String, dynamic> json, {String type = 'LoRA'}) {
    final name = json['name'] as String? ?? '';
    // Auto-detect LyCORIS from filename
    final detectedType = (name.toLowerCase().contains('locon') ||
        name.toLowerCase().contains('loha') ||
        name.toLowerCase().contains('lokr') ||
        name.toLowerCase().contains('lycoris')) ? 'LyCORIS' : type;

    return LoraModel(
      name: name,
      path: json['path'] as String? ?? '',
      title: json['title'] as String? ?? name,
      previewImage: json['preview_image'] as String? ?? json['previewImage'] as String?,
      type: detectedType,
      description: json['description'] as String?,
      baseModel: json['standard_width'] != null
          ? (json['standard_width'] as int) >= 1024 ? 'SDXL/Flux' : 'SD1.5'
          : null,
    );
  }
}

/// Selected LoRA with strength
class SelectedLora {
  final LoraModel lora;
  final double strength;

  SelectedLora({required this.lora, this.strength = 1.0});

  SelectedLora copyWith({double? strength}) {
    return SelectedLora(lora: lora, strength: strength ?? this.strength);
  }

  Map<String, dynamic> toJson() => {
    'name': lora.name,
    'strength': strength,
  };
}

/// Selected LoRAs notifier
class SelectedLorasNotifier extends StateNotifier<List<SelectedLora>> {
  SelectedLorasNotifier() : super([]);

  void addLora(LoraModel lora) {
    if (!state.any((s) => s.lora.name == lora.name)) {
      state = [...state, SelectedLora(lora: lora)];
    }
  }

  void removeLora(String loraName) {
    state = state.where((s) => s.lora.name != loraName).toList();
  }

  void updateStrength(String loraName, double strength) {
    state = state.map((s) {
      if (s.lora.name == loraName) {
        return s.copyWith(strength: strength);
      }
      return s;
    }).toList();
  }

  void clear() {
    state = [];
  }
}
