import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/comfyui_service.dart';

/// LoRA/LyCORIS list provider - fetches from ComfyUI backend
final loraListProvider = FutureProvider<List<LoraModel>>((ref) async {
  final comfyService = ref.watch(comfyUIServiceProvider);
  final allModels = <LoraModel>[];

  // Fetch LoRAs from ComfyUI backend
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
      previewImage: null, // ComfyUI doesn't provide preview images for LoRAs
      type: type,
      description: null,
      baseModel: null,
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

/// Filtered LoRA list based on search
final filteredLoraListProvider = Provider<AsyncValue<List<LoraModel>>>((ref) {
  final filter = ref.watch(loraFilterProvider).toLowerCase();
  final lorasAsync = ref.watch(loraListProvider);
  return lorasAsync.whenData((loras) {
    if (filter.isEmpty) return loras;
    return loras.where((lora) {
      return lora.name.toLowerCase().contains(filter) ||
             lora.title.toLowerCase().contains(filter) ||
             (lora.baseModel?.toLowerCase().contains(filter) ?? false);
    }).toList();
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
