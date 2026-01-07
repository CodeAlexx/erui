import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current trainer preset state - shared between shell and screens
class TrainerPresetState {
  final String presetName;
  final String presetPath;
  final String modelType;
  final String trainingMethod;

  TrainerPresetState({
    this.presetName = '',
    this.presetPath = '',
    this.modelType = '',
    this.trainingMethod = 'LORA',
  });

  TrainerPresetState copyWith({
    String? presetName,
    String? presetPath,
    String? modelType,
    String? trainingMethod,
  }) {
    return TrainerPresetState(
      presetName: presetName ?? this.presetName,
      presetPath: presetPath ?? this.presetPath,
      modelType: modelType ?? this.modelType,
      trainingMethod: trainingMethod ?? this.trainingMethod,
    );
  }
}

class TrainerPresetNotifier extends StateNotifier<TrainerPresetState> {
  TrainerPresetNotifier() : super(TrainerPresetState());

  void setPreset(String name, String path) {
    // Auto-detect model type from preset name
    final lower = name.toLowerCase();
    String modelType = 'Other';
    if (lower.contains('qwen') && lower.contains('edit')) modelType = 'Qwen-Edit';
    else if (lower.contains('qwen')) modelType = 'Qwen';
    else if (lower.contains('kandinsky')) modelType = 'Kandinsky';
    else if (lower.contains('flux')) modelType = 'Flux';
    else if (lower.contains('sdxl')) modelType = 'SDXL';
    else if (lower.contains('sd3')) modelType = 'SD3';
    else if (lower.contains('sd 1') || lower.contains('sd 2')) modelType = 'SD';
    else if (lower.contains('chroma')) modelType = 'Chroma';
    else if (lower.contains('z-image') || lower.contains('zimage')) modelType = 'Z-Image';
    else if (lower.contains('pixart')) modelType = 'PixArt';
    else if (lower.contains('hunyuan')) modelType = 'Hunyuan';
    else if (lower.contains('hidream')) modelType = 'HiDream';
    else if (lower.contains('wan')) modelType = 'Wan';

    // Auto-detect training method
    String trainingMethod = 'LORA';
    if (lower.contains('finetune')) trainingMethod = 'FINE_TUNE';
    else if (lower.contains('embedding')) trainingMethod = 'EMBEDDING';

    state = state.copyWith(
      presetName: name,
      presetPath: path,
      modelType: modelType,
      trainingMethod: trainingMethod,
    );
  }

  void setModelType(String modelType) {
    state = state.copyWith(modelType: modelType);
  }

  void setTrainingMethod(String method) {
    state = state.copyWith(trainingMethod: method);
  }

  void clear() {
    state = TrainerPresetState();
  }
}

final trainerPresetProvider = StateNotifierProvider<TrainerPresetNotifier, TrainerPresetState>((ref) {
  return TrainerPresetNotifier();
});
