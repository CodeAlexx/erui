import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'gallery_provider.dart';

/// Selected image provider - tracks currently selected image for metadata display
final selectedImageProvider = StateNotifierProvider<SelectedImageNotifier, SelectedImageState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return SelectedImageNotifier(apiService);
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

/// Image metadata - parsed from SwarmUI format
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
      resolution = '${aspectW}:$aspectH (${width}x$height)';
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
  final ApiService _apiService;

  SelectedImageNotifier(this._apiService) : super(const SelectedImageState());

  /// Select an image by URL (for current session images)
  Future<void> selectImageUrl(String url) async {
    state = SelectedImageState(imageUrl: url, isLoading: true);
    await _fetchMetadata(url);
  }

  /// Select a gallery image (already has metadata)
  void selectGalleryImage(GalleryImage image) {
    ImageMetadata? metadata;
    if (image.metadata != null) {
      metadata = ImageMetadata.fromSwarmJson(image.metadata!);
    }
    state = SelectedImageState(
      galleryImage: image,
      metadata: metadata,
      isLoading: false,
    );
  }

  /// Fetch metadata for an image URL
  Future<void> _fetchMetadata(String url) async {
    try {
      // Extract path from URL to fetch metadata
      final uri = Uri.parse(url);
      final path = uri.path;

      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/GetImageMetadata',
        data: {'path': path},
      );

      if (response.isSuccess && response.data != null) {
        final metadata = ImageMetadata.fromSwarmJson(response.data!);
        state = state.copyWith(metadata: metadata, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: 'No metadata available');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clear selection
  void clearSelection() {
    state = const SelectedImageState();
  }
}
