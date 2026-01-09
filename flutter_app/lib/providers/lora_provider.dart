import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

/// LoRA/LyCORIS list provider - fetches from EriUI backend
final loraListProvider = FutureProvider<List<LoraModel>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final allModels = <LoraModel>[];

  // Fetch LoRAs from EriUI backend
  final loraResponse = await apiService.post<Map<String, dynamic>>(
    '/API/ListModels',
    data: {'type': 'LoRA', 'depth': 3},
  );
  if (loraResponse.isSuccess && loraResponse.data != null) {
    final models = loraResponse.data!['models'] as List? ?? [];
    allModels.addAll(models.map((m) => LoraModel.fromJson(m as Map<String, dynamic>, type: 'LoRA')));
  }

  // Fetch LyCORIS from EriUI backend
  final lycorisResponse = await apiService.post<Map<String, dynamic>>(
    '/API/ListModels',
    data: {'type': 'LyCORIS', 'depth': 3},
  );
  if (lycorisResponse.isSuccess && lycorisResponse.data != null) {
    final models = lycorisResponse.data!['models'] as List? ?? [];
    allModels.addAll(models.map((m) => LoraModel.fromJson(m as Map<String, dynamic>, type: 'LyCORIS')));
  }

  return allModels;
});

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
