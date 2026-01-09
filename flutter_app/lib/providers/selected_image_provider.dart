import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/comfyui_service.dart';
import 'gallery_provider.dart';

/// Selected image provider - tracks currently selected image for metadata display
final selectedImageProvider = StateNotifierProvider<SelectedImageNotifier, SelectedImageState>((ref) {
  final comfyService = ref.watch(comfyUIServiceProvider);
  return SelectedImageNotifier(comfyService);
});

/// Selected image state
class SelectedImageState {
  final String? imageUrl;
  final GalleryImage? galleryImage;
  final ImageMetadata? metadata;
  final bool isLoading;
  final String? error;

  const SelectedImageState({
    this.imageUrl,
    this.galleryImage,
    this.metadata,
    this.isLoading = false,
    this.error,
  });

  bool get hasImage => imageUrl != null || galleryImage != null;
  String? get displayUrl => imageUrl ?? galleryImage?.url;

  SelectedImageState copyWith({
    String? imageUrl,
    GalleryImage? galleryImage,
    ImageMetadata? metadata,
    bool? isLoading,
    String? error,
  }) {
    return SelectedImageState(
      imageUrl: imageUrl ?? this.imageUrl,
      galleryImage: galleryImage ?? this.galleryImage,
      metadata: metadata ?? this.metadata,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  SelectedImageState cleared() {
    return const SelectedImageState();
  }
}

/// Image metadata - parsed from ComfyUI workflow format
class ImageMetadata {
  final String? prompt;
  final String? negativePrompt;
  final String? model;
  final int? images;
  final String? resolution;
  final int? width;
  final int? height;
  final int? seed;
  final int? steps;
  final double? cfgScale;
  final String? sampler;
  final String? scheduler;
  final String? vae;
  final List<LoraInfo>? loras;
  final String? swarmVersion;
  final String? date;
  final String? prepTime;
  final String? genTime;
  final Map<String, dynamic>? raw;

  const ImageMetadata({
    this.prompt,
    this.negativePrompt,
    this.model,
    this.images,
    this.resolution,
    this.width,
    this.height,
    this.seed,
    this.steps,
    this.cfgScale,
    this.sampler,
    this.scheduler,
    this.vae,
    this.loras,
    this.swarmVersion,
    this.date,
    this.prepTime,
    this.genTime,
    this.raw,
  });

  /// Parse metadata from ComfyUI history entry
  factory ImageMetadata.fromComfyHistory(Map<String, dynamic> historyEntry) {
    final promptList = historyEntry['prompt'] as List?;
    if (promptList == null || promptList.isEmpty) {
      return ImageMetadata(raw: historyEntry);
    }

    // prompt[0] is the workflow nodes
    final nodes = promptList[0] as Map<String, dynamic>?;
    if (nodes == null) {
      return ImageMetadata(raw: historyEntry);
    }

    String? prompt;
    String? negativePrompt;
    String? model;
    int? width;
    int? height;
    int? seed;
    int? steps;
    double? cfgScale;
    String? sampler;
    String? scheduler;
    String? vae;
    List<LoraInfo>? loras;

    // Extract information from workflow nodes
    for (final node in nodes.values) {
      if (node is! Map<String, dynamic>) continue;

      final classType = node['class_type'] as String?;
      final inputs = node['inputs'] as Map<String, dynamic>?;
      if (classType == null || inputs == null) continue;

      switch (classType) {
        case 'CLIPTextEncode':
          // Try to identify positive vs negative prompt
          final text = inputs['text'] as String?;
          if (text != null) {
            // First CLIPTextEncode is usually positive prompt
            if (prompt == null) {
              prompt = text;
            } else if (negativePrompt == null) {
              negativePrompt = text;
            }
          }
          break;

        case 'CheckpointLoaderSimple':
        case 'CheckpointLoader':
          model = inputs['ckpt_name'] as String?;
          break;

        case 'KSampler':
        case 'KSamplerAdvanced':
          seed = inputs['seed'] as int?;
          steps = inputs['steps'] as int?;
          cfgScale = (inputs['cfg'] as num?)?.toDouble();
          sampler = inputs['sampler_name'] as String?;
          scheduler = inputs['scheduler'] as String?;
          break;

        case 'EmptyLatentImage':
          width = inputs['width'] as int?;
          height = inputs['height'] as int?;
          break;

        case 'VAELoader':
          vae = inputs['vae_name'] as String?;
          break;

        case 'LoraLoader':
        case 'LoraLoaderModelOnly':
          final loraName = inputs['lora_name'] as String?;
          final strength = (inputs['strength_model'] as num?)?.toDouble() ?? 1.0;
          if (loraName != null) {
            loras ??= [];
            loras.add(LoraInfo(name: loraName, weight: strength));
          }
          break;
      }
    }

    String? resolution;
    if (width != null && height != null) {
      // Calculate aspect ratio
      final gcd = _gcd(width, height);
      final aspectW = width ~/ gcd;
      final aspectH = height ~/ gcd;
      resolution = '$aspectW:$aspectH (${width}x$height)';
    }

    return ImageMetadata(
      prompt: prompt,
      negativePrompt: negativePrompt,
      model: model,
      resolution: resolution,
      width: width,
      height: height,
      seed: seed,
      steps: steps,
      cfgScale: cfgScale,
      sampler: sampler,
      scheduler: scheduler,
      vae: vae,
      loras: loras,
      raw: historyEntry,
    );
  }

  /// Parse metadata from SwarmUI format (for compatibility)
  factory ImageMetadata.fromSwarmJson(Map<String, dynamic> json) {
    final suiParams = json['sui_image_params'] as Map<String, dynamic>? ?? json;
    final suiExtra = json['sui_extra_data'] as Map<String, dynamic>?;

    // Parse LoRAs
    List<LoraInfo>? loras;
    final loraNames = suiParams['loras'] as String?;
    final loraWeights = suiParams['loraweights'] as String?;
    if (loraNames != null && loraNames.isNotEmpty) {
      final names = loraNames.split(',');
      final weights = loraWeights?.split(',') ?? [];
      loras = [];
      for (int i = 0; i < names.length; i++) {
        final name = names[i].trim();
        if (name.isNotEmpty) {
          final weight = i < weights.length ? double.tryParse(weights[i].trim()) ?? 1.0 : 1.0;
          loras.add(LoraInfo(name: name, weight: weight));
        }
      }
    }

    final width = suiParams['width'] as int?;
    final height = suiParams['height'] as int?;
    String? resolution;
    if (width != null && height != null) {
      // Calculate aspect ratio
      final gcd = _gcd(width, height);
      final aspectW = width ~/ gcd;
      final aspectH = height ~/ gcd;
      resolution = '$aspectW:$aspectH (${width}x$height)';
    }

    return ImageMetadata(
      prompt: suiParams['prompt'] as String?,
      negativePrompt: suiParams['negativeprompt'] as String?,
      model: suiParams['model'] as String?,
      images: suiParams['images'] as int?,
      resolution: resolution,
      width: width,
      height: height,
      seed: suiParams['seed'] as int?,
      steps: suiParams['steps'] as int?,
      cfgScale: (suiParams['cfgscale'] as num?)?.toDouble(),
      sampler: suiParams['sampler'] as String?,
      scheduler: suiParams['scheduler'] as String?,
      vae: suiParams['vae'] as String?,
      loras: loras,
      swarmVersion: suiParams['swarm_version'] as String?,
      date: suiExtra?['date'] as String?,
      prepTime: suiExtra?['prep_time'] as String?,
      genTime: suiExtra?['generation_time'] as String?,
      raw: json,
    );
  }

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a;
  }
}

/// LoRA info
class LoraInfo {
  final String name;
  final double weight;

  const LoraInfo({required this.name, this.weight = 1.0});

  String get displayName {
    final shortName = name.replaceAll('.safetensors', '');
    return shortName.length > 20 ? '${shortName.substring(0, 20)}...' : shortName;
  }
}

/// Selected image notifier
class SelectedImageNotifier extends StateNotifier<SelectedImageState> {
  final ComfyUIService _comfyService;

  SelectedImageNotifier(this._comfyService) : super(const SelectedImageState());

  /// Select an image by URL (for current session images)
  Future<void> selectImageUrl(String url) async {
    state = SelectedImageState(imageUrl: url, isLoading: true);
    await _fetchMetadata(url);
  }

  /// Select a gallery image (already has metadata from ComfyUI history)
  void selectGalleryImage(GalleryImage image) {
    ImageMetadata? metadata;
    if (image.metadata != null) {
      // Parse metadata from ComfyUI history format
      metadata = ImageMetadata.fromComfyHistory(image.metadata!);
    }
    state = SelectedImageState(
      galleryImage: image,
      metadata: metadata,
      isLoading: false,
    );
  }

  /// Fetch metadata for an image URL from ComfyUI history
  Future<void> _fetchMetadata(String url) async {
    try {
      // Try to extract prompt ID from URL to fetch history
      // ComfyUI image URLs look like: http://host:port/view?filename=...&subfolder=...&type=output
      final uri = Uri.parse(url);
      final filename = uri.queryParameters['filename'];

      if (filename == null) {
        state = state.copyWith(isLoading: false, error: 'No metadata available');
        return;
      }

      // ComfyUI doesn't have a direct way to get metadata by filename
      // We would need to search through history, which is expensive
      // For now, just indicate no metadata available
      state = state.copyWith(isLoading: false, error: 'Metadata lookup not available');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clear selection
  void clearSelection() {
    state = const SelectedImageState();
  }
}
