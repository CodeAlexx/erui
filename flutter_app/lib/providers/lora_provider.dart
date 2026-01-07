import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

/// LoRA list provider
final loraListProvider = FutureProvider<List<LoraModel>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final response = await apiService.get<Map<String, dynamic>>('/API/ListLoras');
  if (response.isSuccess && response.data != null) {
    final files = response.data!['files'] as List? ?? [];
    return files.map((f) => LoraModel.fromJson(f as Map<String, dynamic>)).toList();
  }
  return [];
});

/// Selected LoRAs provider
final selectedLorasProvider = StateNotifierProvider<SelectedLorasNotifier, List<SelectedLora>>((ref) {
  return SelectedLorasNotifier();
});

/// LoRA model
class LoraModel {
  final String name;
  final String path;
  final String title;
  final String? previewImage;
  final String? type;
  final String? description;

  LoraModel({
    required this.name,
    required this.path,
    required this.title,
    this.previewImage,
    this.type,
    this.description,
  });

  factory LoraModel.fromJson(Map<String, dynamic> json) {
    return LoraModel(
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      previewImage: json['preview_image'] as String?,
      type: json['type'] as String?,
      description: json['description'] as String?,
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
