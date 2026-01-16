import 'dart:convert';
import 'dart:math';

/// Configuration for a LoRA model
class LoraConfig {
  /// The LoRA model filename
  final String name;

  /// Strength applied to the model weights
  final double modelStrength;

  /// Strength applied to the CLIP weights
  final double clipStrength;

  const LoraConfig({
    required this.name,
    this.modelStrength = 1.0,
    this.clipStrength = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'model_strength': modelStrength,
        'clip_strength': clipStrength,
      };

  factory LoraConfig.fromJson(Map<String, dynamic> json) => LoraConfig(
        name: json['name'] as String,
        modelStrength: (json['model_strength'] as num?)?.toDouble() ?? 1.0,
        clipStrength: (json['clip_strength'] as num?)?.toDouble() ?? 1.0,
      );
}

/// Configuration for ControlNet
class ControlNetConfig {
  /// The ControlNet model filename
  final String model;

  /// The control image as base64 encoded string
  final String imageBase64;

  /// Strength of the ControlNet influence
  final double strength;

  /// Start percentage for ControlNet application (0.0-1.0)
  final double startPercent;

  /// End percentage for ControlNet application (0.0-1.0)
  final double endPercent;

  const ControlNetConfig({
    required this.model,
    required this.imageBase64,
    this.strength = 1.0,
    this.startPercent = 0.0,
    this.endPercent = 1.0,
  });
}

/// Configuration for FreeU enhancement
class FreeUConfig {
  final double b1;
  final double b2;
  final double s1;
  final double s2;

  const FreeUConfig({
    this.b1 = 1.3,
    this.b2 = 1.4,
    this.s1 = 0.9,
    this.s2 = 0.2,
  });

  /// Default FreeU v2 values for SDXL
  static const sdxl = FreeUConfig(b1: 1.3, b2: 1.4, s1: 0.9, s2: 0.2);

  /// Default FreeU v2 values for SD 1.5
  static const sd15 = FreeUConfig(b1: 1.5, b2: 1.6, s1: 0.9, s2: 0.2);
}

/// Configuration for Dynamic Thresholding (sd-dynamic-thresholding)
///
/// Dynamic Thresholding helps prevent over-saturation and improve image quality
/// at high CFG scales by dynamically adjusting the guidance threshold.
class DynamicThresholdingConfig {
  /// The CFG scale to mimic (typically set to match your target CFG)
  final double mimicScale;

  /// Percentile for threshold calculation (0.0-1.0)
  final double thresholdPercentile;

  /// Mode for mimic scale interpolation
  /// Options: Constant, Linear Down, Half Cosine Down, Cosine Down, etc.
  final String mimicMode;

  /// Minimum mimic scale (used with non-constant modes)
  final double mimicScaleMin;

  /// Mode for CFG scale interpolation
  /// Options: Constant, Linear Down, Half Cosine Down, Cosine Down, etc.
  final String cfgMode;

  /// Minimum CFG scale (used with non-constant modes)
  final double cfgScaleMin;

  /// Schedule value for interpolation
  final double schedVal;

  /// Whether to process feature channels separately
  final bool separateFeatureChannels;

  /// Starting point for scaling: MEAN or ZERO
  final String scalingStartpoint;

  /// Measure for variability: AD (Average Deviation) or STD (Standard Deviation)
  final String variabilityMeasure;

  /// Interpolation factor for phi (0.0-1.0)
  final double interpolatePhi;

  const DynamicThresholdingConfig({
    this.mimicScale = 7.0,
    this.thresholdPercentile = 1.0,
    this.mimicMode = 'Constant',
    this.mimicScaleMin = 0.0,
    this.cfgMode = 'Constant',
    this.cfgScaleMin = 0.0,
    this.schedVal = 4.0,
    this.separateFeatureChannels = true,
    this.scalingStartpoint = 'MEAN',
    this.variabilityMeasure = 'AD',
    this.interpolatePhi = 1.0,
  });

  /// Default configuration for general use
  static const standard = DynamicThresholdingConfig();

  /// Configuration optimized for high CFG scales (10+)
  static const highCfg = DynamicThresholdingConfig(
    mimicScale: 10.0,
    thresholdPercentile: 0.995,
  );
}

/// Builder for ComfyUI workflow JSON
///
/// Converts ERI generation parameters into ComfyUI-compatible workflow JSON
/// that can be sent to a ComfyUI backend for execution.
class ComfyUIWorkflowBuilder {
  int _nodeId = 0;
  final Map<String, dynamic> _workflow = {};

  // Track node outputs for connections
  String _modelNode = '';
  int _modelOutput = 0;
  String _clipNode = '';
  int _clipOutput = 1;
  String _vaeNode = '';
  int _vaeOutput = 2;
  String _positiveNode = '';
  String _negativeNode = '';
  String _latentNode = '';
  String _samplerNode = '';
  String _imageNode = '';

  /// Reset the builder for a new workflow
  void reset() {
    _nodeId = 0;
    _workflow.clear();
    _modelNode = '';
    _modelOutput = 0;
    _clipNode = '';
    _clipOutput = 1;
    _vaeNode = '';
    _vaeOutput = 2;
    _positiveNode = '';
    _negativeNode = '';
    _latentNode = '';
    _samplerNode = '';
    _imageNode = '';
  }

  /// Add a node to the workflow and return its ID
  String _addNode(String classType, Map<String, dynamic> inputs) {
    _nodeId++;
    final id = _nodeId.toString();
    _workflow[id] = {
      'class_type': classType,
      'inputs': inputs,
    };
    return id;
  }

  /// Create a node reference for input connections
  List<dynamic> _nodeRef(String nodeId, int outputIndex) {
    return [nodeId, outputIndex];
  }

  /// Generate a random seed if -1 is provided
  int _resolveSeed(int seed) {
    if (seed < 0) {
      return Random().nextInt(0x7FFFFFFF);
    }
    return seed;
  }

  /// Build a text-to-image workflow
  ///
  /// Creates a complete ComfyUI workflow for text-to-image generation with
  /// optional support for img2img, LoRAs, ControlNet, custom VAE, FreeU,
  /// and Dynamic Thresholding.
  Map<String, dynamic> buildText2Image({
    required String model,
    required String prompt,
    String negativePrompt = '',
    int width = 1024,
    int height = 1024,
    int steps = 20,
    double cfg = 7.0,
    int seed = -1,
    String sampler = 'euler',
    String scheduler = 'normal',
    int batchSize = 1,
    String? vae,
    List<LoraConfig>? loras,
    // Init image (img2img)
    String? initImageBase64,
    double denoise = 1.0,
    // ControlNet
    ControlNetConfig? controlNet,
    // Advanced model patches
    FreeUConfig? freeU,
    DynamicThresholdingConfig? dynamicThresholding,
    // Clip skip
    int clipSkip = 1,
    // Output
    String filenamePrefix = 'ERI',
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);

    // Step 1: Load checkpoint
    _modelNode = _addNode('CheckpointLoaderSimple', {
      'ckpt_name': model,
    });
    _clipNode = _modelNode;
    _clipOutput = 1;
    _vaeNode = _modelNode;
    _vaeOutput = 2;

    // Step 2: Load custom VAE if specified
    if (vae != null && vae.isNotEmpty) {
      _vaeNode = _addNode('VAELoader', {
        'vae_name': vae,
      });
      _vaeOutput = 0;
    }

    // Step 3: Apply LoRAs (chain them)
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraNode = _addNode('LoraLoader', {
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
          'strength_clip': lora.clipStrength,
          'model': _nodeRef(_modelNode, _modelOutput),
          'clip': _nodeRef(_clipNode, _clipOutput),
        });
        _modelNode = loraNode;
        _modelOutput = 0;
        _clipNode = loraNode;
        _clipOutput = 1;
      }
    }

    // Step 4: Apply FreeU if enabled
    if (freeU != null) {
      final freeUNode = _addNode('FreeU_V2', {
        'b1': freeU.b1,
        'b2': freeU.b2,
        's1': freeU.s1,
        's2': freeU.s2,
        'model': _nodeRef(_modelNode, _modelOutput),
      });
      _modelNode = freeUNode;
      _modelOutput = 0;
    }

    // Step 4b: Apply Dynamic Thresholding if enabled
    if (dynamicThresholding != null) {
      final dtNode = _addNode('DynamicThresholdingFull', {
        'model': _nodeRef(_modelNode, _modelOutput),
        'mimic_scale': dynamicThresholding.mimicScale,
        'threshold_percentile': dynamicThresholding.thresholdPercentile,
        'mimic_mode': dynamicThresholding.mimicMode,
        'mimic_scale_min': dynamicThresholding.mimicScaleMin,
        'cfg_mode': dynamicThresholding.cfgMode,
        'cfg_scale_min': dynamicThresholding.cfgScaleMin,
        'sched_val': dynamicThresholding.schedVal,
        'separate_feature_channels':
            dynamicThresholding.separateFeatureChannels ? 'enable' : 'disable',
        'scaling_startpoint': dynamicThresholding.scalingStartpoint,
        'variability_measure': dynamicThresholding.variabilityMeasure,
        'interpolate_phi': dynamicThresholding.interpolatePhi,
      });
      _modelNode = dtNode;
      _modelOutput = 0;
    }

    // Step 5: Apply clip skip if > 1
    if (clipSkip > 1) {
      final clipSetNode = _addNode('CLIPSetLastLayer', {
        'stop_at_clip_layer': -clipSkip,
        'clip': _nodeRef(_clipNode, _clipOutput),
      });
      _clipNode = clipSetNode;
      _clipOutput = 0;
    }

    // Step 6: Encode prompts
    _positiveNode = _addNode('CLIPTextEncode', {
      'text': prompt,
      'clip': _nodeRef(_clipNode, _clipOutput),
    });

    _negativeNode = _addNode('CLIPTextEncode', {
      'text': negativePrompt,
      'clip': _nodeRef(_clipNode, _clipOutput),
    });

    // Step 7: Create latent image (empty or from init image)
    if (initImageBase64 != null && initImageBase64.isNotEmpty) {
      // img2img mode: load image and encode to latent
      final loadImageNode = _addNode('LoadImageBase64', {
        'image': initImageBase64,
      });
      _latentNode = _addNode('VAEEncode', {
        'pixels': _nodeRef(loadImageNode, 0),
        'vae': _nodeRef(_vaeNode, _vaeOutput),
      });
    } else {
      // txt2img mode: empty latent
      _latentNode = _addNode('EmptyLatentImage', {
        'width': width,
        'height': height,
        'batch_size': batchSize,
      });
    }

    // Step 8: Apply ControlNet if specified
    if (controlNet != null) {
      final controlNetLoader = _addNode('ControlNetLoader', {
        'control_net_name': controlNet.model,
      });

      final loadControlImage = _addNode('LoadImageBase64', {
        'image': controlNet.imageBase64,
      });

      final applyControlNet = _addNode('ControlNetApplyAdvanced', {
        'strength': controlNet.strength,
        'start_percent': controlNet.startPercent,
        'end_percent': controlNet.endPercent,
        'positive': _nodeRef(_positiveNode, 0),
        'negative': _nodeRef(_negativeNode, 0),
        'control_net': _nodeRef(controlNetLoader, 0),
        'image': _nodeRef(loadControlImage, 0),
      });

      _positiveNode = applyControlNet;
      // Negative is output 1 of ControlNetApplyAdvanced
    }

    // Step 9: KSampler
    _samplerNode = _addNode('KSampler', {
      'seed': resolvedSeed,
      'steps': steps,
      'cfg': cfg,
      'sampler_name': sampler,
      'scheduler': scheduler,
      'denoise': denoise,
      'model': _nodeRef(_modelNode, _modelOutput),
      'positive': _nodeRef(
          _positiveNode, controlNet != null ? 0 : 0), // ControlNet changes output
      'negative': _nodeRef(
          controlNet != null ? _positiveNode : _negativeNode,
          controlNet != null ? 1 : 0),
      'latent_image': _nodeRef(_latentNode, 0),
    });

    // Step 10: VAE Decode
    _imageNode = _addNode('VAEDecode', {
      'samples': _nodeRef(_samplerNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // Step 11: Save Image
    _addNode('SaveImage', {
      'filename_prefix': filenamePrefix,
      'images': _nodeRef(_imageNode, 0),
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build a Flux image generation workflow
  ///
  /// Based on reference workflow: flux-lora-simple
  /// Uses: UNETLoader, DualCLIPLoader, CLIPTextEncode, FluxGuidance,
  /// ModelSamplingFlux, BasicGuider, BasicScheduler, SamplerCustomAdvanced
  Map<String, dynamic> buildFlux({
    required String model,
    required String prompt,
    String negativePrompt = '',
    int width = 1024,
    int height = 1024,
    int steps = 35,
    double guidance = 3.5,
    int seed = -1,
    String sampler = 'dpmpp_2m',
    String scheduler = 'sgm_uniform',
    int batchSize = 1,
    String? vae,
    String clipL = 'clip_l.safetensors',
    String clipT5 = 't5xxl_fp8_e4m3fn_scaled.safetensors',
    String? initImageBase64,
    double denoise = 1.0,
    String filenamePrefix = 'ERI_flux',
    List<LoraConfig>? loras,
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);

    // Load Flux model using UNETLoader
    final weightDtype = model.toLowerCase().contains('fp8') ? 'fp8_e4m3fn' : 'default';
    _modelNode = _addNode('UNETLoader', {
      'unet_name': model,
      'weight_dtype': weightDtype,
    });
    _modelOutput = 0;

    // Load dual CLIP (t5xxl + clip_l) for Flux
    _clipNode = _addNode('DualCLIPLoader', {
      'clip_name1': clipT5,
      'clip_name2': clipL,
      'type': 'flux',
    });
    _clipOutput = 0;

    // Apply LoRAs (model only for Flux)
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraNode = _addNode('LoraLoaderModelOnly', {
          'model': _nodeRef(_modelNode, _modelOutput),
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
        });
        _modelNode = loraNode;
        _modelOutput = 0;
      }
    }

    // ModelSamplingFlux - applies flux-specific sampling with shift parameters
    final modelSamplingNode = _addNode('ModelSamplingFlux', {
      'model': _nodeRef(_modelNode, _modelOutput),
      'max_shift': 1.15,
      'base_shift': 0.5,
      'width': width,
      'height': height,
    });
    _modelNode = modelSamplingNode;
    _modelOutput = 0;

    // Load VAE (ae.safetensors for Flux)
    _vaeNode = _addNode('VAELoader', {
      'vae_name': vae ?? 'ae.safetensors',
    });
    _vaeOutput = 0;

    // CLIPTextEncode - standard text encoding
    final clipEncodeNode = _addNode('CLIPTextEncode', {
      'clip': _nodeRef(_clipNode, _clipOutput),
      'text': prompt,
    });

    // FluxGuidance - applies guidance to conditioning
    final guidanceNode = _addNode('FluxGuidance', {
      'conditioning': _nodeRef(clipEncodeNode, 0),
      'guidance': guidance,
    });

    // Create latent
    if (initImageBase64 != null && initImageBase64.isNotEmpty) {
      final loadImageNode = _addNode('LoadImageBase64', {
        'image': initImageBase64,
      });
      final resizeNode = _addNode('ImageResize', {
        'image': _nodeRef(loadImageNode, 0),
        'width': width,
        'height': height,
        'interpolation': 'bicubic',
        'method': 'fill / crop',
        'condition': 'always',
      });
      _latentNode = _addNode('VAEEncode', {
        'pixels': _nodeRef(resizeNode, 0),
        'vae': _nodeRef(_vaeNode, _vaeOutput),
      });
    } else {
      _latentNode = _addNode('EmptyLatentImage', {
        'width': width,
        'height': height,
        'batch_size': batchSize,
      });
    }

    // RandomNoise
    final noiseNode = _addNode('RandomNoise', {
      'noise_seed': resolvedSeed,
    });

    // BasicGuider - combines model and conditioning
    final guiderNode = _addNode('BasicGuider', {
      'model': _nodeRef(_modelNode, _modelOutput),
      'conditioning': _nodeRef(guidanceNode, 0),
    });

    // KSamplerSelect
    final samplerSelectNode = _addNode('KSamplerSelect', {
      'sampler_name': sampler,
    });

    // BasicScheduler
    final schedulerNode = _addNode('BasicScheduler', {
      'model': _nodeRef(_modelNode, _modelOutput),
      'scheduler': scheduler,
      'steps': steps,
      'denoise': denoise,
    });

    // SamplerCustomAdvanced
    _samplerNode = _addNode('SamplerCustomAdvanced', {
      'noise': _nodeRef(noiseNode, 0),
      'guider': _nodeRef(guiderNode, 0),
      'sampler': _nodeRef(samplerSelectNode, 0),
      'sigmas': _nodeRef(schedulerNode, 0),
      'latent_image': _nodeRef(_latentNode, 0),
    });

    // VAE Decode
    _imageNode = _addNode('VAEDecode', {
      'samples': _nodeRef(_samplerNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // Save image
    _addNode('SaveImage', {
      'filename_prefix': filenamePrefix,
      'images': _nodeRef(_imageNode, 0),
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build a Flux.2 Klein text-to-image workflow
  ///
  /// Flux.2 Klein 4B uses:
  /// - UNETLoader for diffusion model
  /// - CLIPLoader with type='flux2' for qwen_3_4b text encoder
  /// - VAELoader for flux2-vae
  /// - CFGGuider (cfg=5 for base, cfg=1 for distilled)
  /// - Flux2Scheduler for sigmas
  /// - EmptyFlux2LatentImage for Flux2-specific latent
  Map<String, dynamic> buildFlux2Klein({
    required String model,
    required String prompt,
    String negativePrompt = '',
    int width = 1024,
    int height = 1024,
    int steps = 20,
    double cfgScale = 5.0,
    int seed = -1,
    String sampler = 'euler',
    int batchSize = 1,
    String clip = 'qwen_3_4b.safetensors',
    String vae = 'flux2-vae.safetensors',
    String filenamePrefix = 'ERI_flux2klein',
    List<LoraConfig>? loras,
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);

    // Determine if distilled model (4-step) or base (20-step)
    final isDistilled = model.toLowerCase().contains('klein-4b') &&
                        !model.toLowerCase().contains('base');

    // Load Flux2 Klein model using UNETLoader
    _modelNode = _addNode('UNETLoader', {
      'unet_name': model,
      'weight_dtype': 'default',
    });
    _modelOutput = 0;

    // Load CLIP using CLIPLoader with flux2 type
    _clipNode = _addNode('CLIPLoader', {
      'clip_name': clip,
      'type': 'flux2',
      'device': 'default',
    });
    _clipOutput = 0;

    // Apply LoRAs if provided
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraNode = _addNode('LoraLoaderModelOnly', {
          'model': _nodeRef(_modelNode, _modelOutput),
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
        });
        _modelNode = loraNode;
        _modelOutput = 0;
      }
    }

    // Load VAE
    _vaeNode = _addNode('VAELoader', {
      'vae_name': vae,
    });
    _vaeOutput = 0;

    // CLIPTextEncode for positive prompt
    final positiveNode = _addNode('CLIPTextEncode', {
      'clip': _nodeRef(_clipNode, _clipOutput),
      'text': prompt,
    });

    // For distilled model, use ConditioningZeroOut for negative
    // For base model, use empty CLIPTextEncode
    String negativeNode;
    if (isDistilled) {
      negativeNode = _addNode('ConditioningZeroOut', {
        'conditioning': _nodeRef(positiveNode, 0),
      });
    } else {
      negativeNode = _addNode('CLIPTextEncode', {
        'clip': _nodeRef(_clipNode, _clipOutput),
        'text': negativePrompt,
      });
    }

    // CFGGuider - cfg=5 for base, cfg=1 for distilled
    final effectiveCfg = isDistilled ? 1.0 : cfgScale;
    final guiderNode = _addNode('CFGGuider', {
      'model': _nodeRef(_modelNode, _modelOutput),
      'positive': _nodeRef(positiveNode, 0),
      'negative': _nodeRef(negativeNode, 0),
      'cfg': effectiveCfg,
    });

    // Flux2Scheduler - 4 steps for distilled, 20 for base
    final effectiveSteps = isDistilled ? 4 : steps;
    final schedulerNode = _addNode('Flux2Scheduler', {
      'steps': effectiveSteps,
      'width': width,
      'height': height,
    });

    // EmptyFlux2LatentImage
    _latentNode = _addNode('EmptyFlux2LatentImage', {
      'width': width,
      'height': height,
      'batch_size': batchSize,
    });

    // RandomNoise
    final noiseNode = _addNode('RandomNoise', {
      'noise_seed': resolvedSeed,
    });

    // KSamplerSelect
    final samplerSelectNode = _addNode('KSamplerSelect', {
      'sampler_name': sampler,
    });

    // SamplerCustomAdvanced
    _samplerNode = _addNode('SamplerCustomAdvanced', {
      'noise': _nodeRef(noiseNode, 0),
      'guider': _nodeRef(guiderNode, 0),
      'sampler': _nodeRef(samplerSelectNode, 0),
      'sigmas': _nodeRef(schedulerNode, 0),
      'latent_image': _nodeRef(_latentNode, 0),
    });

    // VAE Decode
    _imageNode = _addNode('VAEDecode', {
      'samples': _nodeRef(_samplerNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // Save image
    _addNode('SaveImage', {
      'filename_prefix': filenamePrefix,
      'images': _nodeRef(_imageNode, 0),
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build a Flux.2 Klein image edit workflow
  ///
  /// Takes an input image and edits it based on the prompt.
  /// Uses the same architecture as t2i but encodes the input image.
  Map<String, dynamic> buildFlux2KleinEdit({
    required String model,
    required String prompt,
    required String initImageBase64,
    String negativePrompt = '',
    int width = 1024,
    int height = 1024,
    int steps = 20,
    double cfgScale = 5.0,
    double denoise = 0.75,
    int seed = -1,
    String sampler = 'euler',
    String clip = 'qwen_3_4b.safetensors',
    String vae = 'flux2-vae.safetensors',
    String filenamePrefix = 'ERI_flux2klein_edit',
    List<LoraConfig>? loras,
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);

    // Determine if distilled model
    final isDistilled = model.toLowerCase().contains('klein-4b') &&
                        !model.toLowerCase().contains('base');

    // Load Flux2 Klein model using UNETLoader
    _modelNode = _addNode('UNETLoader', {
      'unet_name': model,
      'weight_dtype': 'default',
    });
    _modelOutput = 0;

    // Load CLIP using CLIPLoader with flux2 type
    _clipNode = _addNode('CLIPLoader', {
      'clip_name': clip,
      'type': 'flux2',
      'device': 'default',
    });
    _clipOutput = 0;

    // Apply LoRAs if provided
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraNode = _addNode('LoraLoaderModelOnly', {
          'model': _nodeRef(_modelNode, _modelOutput),
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
        });
        _modelNode = loraNode;
        _modelOutput = 0;
      }
    }

    // Load VAE
    _vaeNode = _addNode('VAELoader', {
      'vae_name': vae,
    });
    _vaeOutput = 0;

    // Load and encode the input image
    final loadImageNode = _addNode('LoadImageBase64', {
      'image': initImageBase64,
    });

    // Resize to target dimensions
    final resizeNode = _addNode('ImageResize', {
      'image': _nodeRef(loadImageNode, 0),
      'width': width,
      'height': height,
      'interpolation': 'bicubic',
      'method': 'fill / crop',
      'condition': 'always',
    });

    // Encode to latent
    _latentNode = _addNode('VAEEncode', {
      'pixels': _nodeRef(resizeNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // CLIPTextEncode for positive prompt
    final positiveNode = _addNode('CLIPTextEncode', {
      'clip': _nodeRef(_clipNode, _clipOutput),
      'text': prompt,
    });

    // For distilled model, use ConditioningZeroOut for negative
    String negativeNode;
    if (isDistilled) {
      negativeNode = _addNode('ConditioningZeroOut', {
        'conditioning': _nodeRef(positiveNode, 0),
      });
    } else {
      negativeNode = _addNode('CLIPTextEncode', {
        'clip': _nodeRef(_clipNode, _clipOutput),
        'text': negativePrompt,
      });
    }

    // CFGGuider
    final effectiveCfg = isDistilled ? 1.0 : cfgScale;
    final guiderNode = _addNode('CFGGuider', {
      'model': _nodeRef(_modelNode, _modelOutput),
      'positive': _nodeRef(positiveNode, 0),
      'negative': _nodeRef(negativeNode, 0),
      'cfg': effectiveCfg,
    });

    // Flux2Scheduler with denoise
    final effectiveSteps = isDistilled ? 4 : steps;
    final schedulerNode = _addNode('Flux2Scheduler', {
      'steps': effectiveSteps,
      'width': width,
      'height': height,
      'denoise': denoise,
    });

    // RandomNoise
    final noiseNode = _addNode('RandomNoise', {
      'noise_seed': resolvedSeed,
    });

    // KSamplerSelect
    final samplerSelectNode = _addNode('KSamplerSelect', {
      'sampler_name': sampler,
    });

    // SamplerCustomAdvanced
    _samplerNode = _addNode('SamplerCustomAdvanced', {
      'noise': _nodeRef(noiseNode, 0),
      'guider': _nodeRef(guiderNode, 0),
      'sampler': _nodeRef(samplerSelectNode, 0),
      'sigmas': _nodeRef(schedulerNode, 0),
      'latent_image': _nodeRef(_latentNode, 0),
    });

    // VAE Decode
    _imageNode = _addNode('VAEDecode', {
      'samples': _nodeRef(_samplerNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // Save image
    _addNode('SaveImage', {
      'filename_prefix': filenamePrefix,
      'images': _nodeRef(_imageNode, 0),
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build an SD3.5 image generation workflow
  ///
  /// SD3.5 models require:
  /// - UNETLoader for diffusion_models path
  /// - TripleCLIPLoader for clip_l + clip_g + t5xxl
  /// - CLIPTextEncodeSD3 for prompt encoding
  /// - EmptySD3LatentImage for 16-channel latent
  /// Build an SD3.5 image generation workflow matching reference.
  ///
  /// SD3.5 requires:
  /// - UNETLoader for diffusion model
  /// - TripleCLIPLoader (clip_l, clip_g, t5xxl)
  /// - ModelSamplingSD3 with shift=3 (applied BEFORE LoRAs)
  /// - CLIPTextEncodeSD3 for prompts
  /// - SD3.5 specific VAE
  Map<String, dynamic> buildSD35({
    required String model,
    required String prompt,
    String negativePrompt = '',
    int width = 1024,
    int height = 1024,
    int steps = 44,  // Reference uses 44 steps
    double cfg = 5.5,  // Reference uses CFG 5.5
    int seed = -1,
    String sampler = 'dpmpp_2m',  // Reference uses dpmpp_2m
    String scheduler = 'sgm_uniform',  // Reference uses sgm_uniform
    int batchSize = 1,
    String? vae,
    String clipL = 'clip_l.safetensors',
    String clipG = 'clip_g.safetensors',
    String clipT5 = 't5xxl_fp16.safetensors',
    String? initImageBase64,
    double denoise = 1.0,
    String filenamePrefix = 'ERI_sd35',
    List<LoraConfig>? loras,
    double shift = 3.0,  // ModelSamplingSD3 shift parameter
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);

    // Load SD3.5 model using UNETLoader (diffusion_models path)
    final weightDtype = model.toLowerCase().contains('fp8') ? 'fp8_e4m3fn' : 'default';
    final unetNode = _addNode('UNETLoader', {
      'unet_name': model,
      'weight_dtype': weightDtype,
    });

    // Apply ModelSamplingSD3 with shift (BEFORE LoRAs per reference)
    _modelNode = _addNode('ModelSamplingSD3', {
      'model': _nodeRef(unetNode, 0),
      'shift': shift,
    });
    _modelOutput = 0;

    // Load triple CLIP (clip_l + clip_g + t5xxl) for SD3
    _clipNode = _addNode('TripleCLIPLoader', {
      'clip_name1': clipL,
      'clip_name2': clipG,
      'clip_name3': clipT5,
    });
    _clipOutput = 0;

    // Apply LoRAs AFTER ModelSamplingSD3 (per reference workflow)
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraNode = _addNode('LoraLoader', {
          'model': _nodeRef(_modelNode, _modelOutput),
          'clip': _nodeRef(_clipNode, _clipOutput),
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
          'strength_clip': lora.clipStrength,
        });
        _modelNode = loraNode;
        _modelOutput = 0;
        _clipNode = loraNode;
        _clipOutput = 1;
      }
    }

    // Load VAE - use SD3.5 specific VAE
    _vaeNode = _addNode('VAELoader', {
      'vae_name': vae ?? 'OfficialStableDiffusion/sd35_vae.safetensors',
    });
    _vaeOutput = 0;

    // Encode prompts using CLIPTextEncodeSD3
    _positiveNode = _addNode('CLIPTextEncodeSD3', {
      'clip': _nodeRef(_clipNode, _clipOutput),
      'clip_l': prompt,
      'clip_g': prompt,
      't5xxl': prompt,
      'empty_padding': 'none',
    });

    _negativeNode = _addNode('CLIPTextEncodeSD3', {
      'clip': _nodeRef(_clipNode, _clipOutput),
      'clip_l': negativePrompt,
      'clip_g': negativePrompt,
      't5xxl': negativePrompt,
      'empty_padding': 'none',
    });

    // Create latent - img2img or empty
    if (initImageBase64 != null && initImageBase64.isNotEmpty) {
      // Image-to-image mode
      final loadImageNode = _addNode('LoadImageBase64', {
        'image': initImageBase64,
      });

      final resizeNode = _addNode('ImageResize', {
        'image': _nodeRef(loadImageNode, 0),
        'width': width,
        'height': height,
        'interpolation': 'bicubic',
        'method': 'fill / crop',
        'condition': 'always',
      });

      _latentNode = _addNode('VAEEncode', {
        'pixels': _nodeRef(resizeNode, 0),
        'vae': _nodeRef(_vaeNode, _vaeOutput),
      });
    } else {
      // Text-to-image mode - use SD3-specific latent (16 channels)
      _latentNode = _addNode('EmptySD3LatentImage', {
        'width': width,
        'height': height,
        'batch_size': batchSize,
      });
    }

    // Standard KSampler for SD3.5
    _samplerNode = _addNode('KSampler', {
      'seed': resolvedSeed,
      'steps': steps,
      'cfg': cfg,
      'sampler_name': sampler,
      'scheduler': scheduler,
      'denoise': denoise,
      'model': _nodeRef(_modelNode, _modelOutput),
      'positive': _nodeRef(_positiveNode, 0),
      'negative': _nodeRef(_negativeNode, 0),
      'latent_image': _nodeRef(_latentNode, 0),
    });

    // VAE Decode
    _imageNode = _addNode('VAEDecode', {
      'samples': _nodeRef(_samplerNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // Save image
    _addNode('SaveImage', {
      'filename_prefix': filenamePrefix,
      'images': _nodeRef(_imageNode, 0),
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build a Chroma (Chroma1-HD) image generation workflow
  ///
  /// Chroma is a Flux-like model that supports negative prompts via CFG.
  /// Key differences from Flux:
  /// - Uses single T5 CLIP with type "chroma"
  /// - Supports proper negative prompts with CFG
  /// - Uses ModelSamplingAuraFlow with shift=1
  Map<String, dynamic> buildChroma({
    required String model,
    required String prompt,
    String negativePrompt = '',
    int width = 1024,
    int height = 1024,
    int steps = 26,
    double cfg = 3.8,
    int seed = -1,
    String sampler = 'euler',
    String scheduler = 'beta',
    int batchSize = 1,
    String? vae,
    String clipT5 = 't5xxl_fp16.safetensors',
    String? initImageBase64,
    double denoise = 1.0,
    String filenamePrefix = 'ERI_chroma',
    List<LoraConfig>? loras,
    double shift = 1.0,
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);

    // Load Chroma model using UNETLoader (diffusion_models path)
    final weightDtype = model.toLowerCase().contains('fp8') ? 'fp8_e4m3fn' : 'default';
    _modelNode = _addNode('UNETLoader', {
      'unet_name': model,
      'weight_dtype': weightDtype,
    });
    _modelOutput = 0;

    // Apply ModelSamplingAuraFlow for Chroma (flow shift)
    final modelSamplingNode = _addNode('ModelSamplingAuraFlow', {
      'model': _nodeRef(_modelNode, _modelOutput),
      'shift': shift,
    });
    _modelNode = modelSamplingNode;
    _modelOutput = 0;

    // Load single T5 CLIP for Chroma
    _clipNode = _addNode('CLIPLoader', {
      'clip_name': clipT5,
    });
    _clipOutput = 0;

    // Apply LoRAs (after model sampling, before encoding)
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraNode = _addNode('LoraLoader', {
          'model': _nodeRef(_modelNode, _modelOutput),
          'clip': _nodeRef(_clipNode, _clipOutput),
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
          'strength_clip': lora.clipStrength,
        });
        _modelNode = loraNode;
        _modelOutput = 0;
        _clipNode = loraNode;
        _clipOutput = 1;
      }
    }

    // Load VAE (ae.safetensors for Chroma, same as Flux)
    _vaeNode = _addNode('VAELoader', {
      'vae_name': vae ?? 'ae.safetensors',
    });
    _vaeOutput = 0;

    // Encode prompts using standard CLIPTextEncode (Chroma supports negatives!)
    _positiveNode = _addNode('CLIPTextEncode', {
      'clip': _nodeRef(_clipNode, _clipOutput),
      'text': prompt,
    });

    _negativeNode = _addNode('CLIPTextEncode', {
      'clip': _nodeRef(_clipNode, _clipOutput),
      'text': negativePrompt,
    });

    // Create latent - img2img or empty
    if (initImageBase64 != null && initImageBase64.isNotEmpty) {
      // Image-to-image mode
      final loadImageNode = _addNode('LoadImageBase64', {
        'image': initImageBase64,
      });

      final resizeNode = _addNode('ImageResize', {
        'image': _nodeRef(loadImageNode, 0),
        'width': width,
        'height': height,
        'interpolation': 'bicubic',
        'method': 'fill / crop',
        'condition': 'always',
      });

      _latentNode = _addNode('VAEEncode', {
        'pixels': _nodeRef(resizeNode, 0),
        'vae': _nodeRef(_vaeNode, _vaeOutput),
      });
    } else {
      // Text-to-image mode - use SD3 latent for Chroma
      _latentNode = _addNode('EmptySD3LatentImage', {
        'width': width,
        'height': height,
        'batch_size': batchSize,
      });
    }

    // Standard KSampler with CFG (Chroma uses real CFG unlike Flux)
    _samplerNode = _addNode('KSampler', {
      'seed': resolvedSeed,
      'steps': steps,
      'cfg': cfg,
      'sampler_name': sampler,
      'scheduler': scheduler,
      'denoise': denoise,
      'model': _nodeRef(_modelNode, _modelOutput),
      'positive': _nodeRef(_positiveNode, 0),
      'negative': _nodeRef(_negativeNode, 0),
      'latent_image': _nodeRef(_latentNode, 0),
    });

    // VAE Decode
    _imageNode = _addNode('VAEDecode', {
      'samples': _nodeRef(_samplerNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // Save image
    _addNode('SaveImage', {
      'filename_prefix': filenamePrefix,
      'images': _nodeRef(_imageNode, 0),
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build a HiDream image generation workflow
  ///
  /// HiDream uses QuadrupleCLIPLoader (clip_l, clip_g, t5xxl, llama) and ModelSamplingSD3.
  /// Variants: Full (shift=3, 50 steps), Dev (shift=6, 28 steps, cfg=1), Fast (shift=3, 16 steps)
  Map<String, dynamic> buildHiDream({
    required String model,
    required String prompt,
    String negativePrompt = '',
    int width = 1024,
    int height = 1024,
    int steps = 50,
    double cfg = 5.0,
    int seed = -1,
    String sampler = 'uni_pc',
    String scheduler = 'simple',
    int batchSize = 1,
    String? vae,
    String clipL = 'clip_l_hidream.safetensors',
    String clipG = 'clip_g_hidream.safetensors',
    String clipT5 = 't5xxl_fp8_e4m3fn.safetensors',
    String clipLlama = 'llama_3.1_8b_instruct_fp8_scaled.safetensors',
    String? initImageBase64,
    double denoise = 1.0,
    String filenamePrefix = 'ERI_hidream',
    List<LoraConfig>? loras,
    double shift = 3.0,
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);

    // Load HiDream model using UNETLoader
    final weightDtype = model.toLowerCase().contains('fp8') ? 'fp8_e4m3fn' : 'default';
    final unetNode = _addNode('UNETLoader', {
      'unet_name': model,
      'weight_dtype': weightDtype,
    });

    // Apply ModelSamplingSD3 with shift (BEFORE LoRAs per SD3-family convention)
    _modelNode = _addNode('ModelSamplingSD3', {
      'model': _nodeRef(unetNode, 0),
      'shift': shift,
    });
    _modelOutput = 0;

    // Load QuadrupleCLIP (clip_l + clip_g + t5xxl + llama) for HiDream
    _clipNode = _addNode('QuadrupleCLIPLoader', {
      'clip_name1': clipL,
      'clip_name2': clipG,
      'clip_name3': clipT5,
      'clip_name4': clipLlama,
    });
    _clipOutput = 0;

    // Apply LoRAs AFTER ModelSamplingSD3 (per SD3-family convention)
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraNode = _addNode('LoraLoader', {
          'model': _nodeRef(_modelNode, _modelOutput),
          'clip': _nodeRef(_clipNode, _clipOutput),
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
          'strength_clip': lora.clipStrength,
        });
        _modelNode = loraNode;
        _modelOutput = 0;
        _clipNode = loraNode;
        _clipOutput = 1;
      }
    }

    // Load VAE (ae.safetensors for HiDream)
    _vaeNode = _addNode('VAELoader', {
      'vae_name': vae ?? 'ae.safetensors',
    });
    _vaeOutput = 0;

    // Encode prompts using standard CLIPTextEncode
    _positiveNode = _addNode('CLIPTextEncode', {
      'clip': _nodeRef(_clipNode, _clipOutput),
      'text': prompt,
    });

    _negativeNode = _addNode('CLIPTextEncode', {
      'clip': _nodeRef(_clipNode, _clipOutput),
      'text': negativePrompt,
    });

    // Create latent - img2img or empty
    if (initImageBase64 != null && initImageBase64.isNotEmpty) {
      final loadImageNode = _addNode('LoadImageBase64', {
        'image': initImageBase64,
      });

      final resizeNode = _addNode('ImageResize', {
        'image': _nodeRef(loadImageNode, 0),
        'width': width,
        'height': height,
        'interpolation': 'bicubic',
        'method': 'fill / crop',
        'condition': 'always',
      });

      _latentNode = _addNode('VAEEncode', {
        'pixels': _nodeRef(resizeNode, 0),
        'vae': _nodeRef(_vaeNode, _vaeOutput),
      });
    } else {
      _latentNode = _addNode('EmptySD3LatentImage', {
        'width': width,
        'height': height,
        'batch_size': batchSize,
      });
    }

    // Standard KSampler
    _samplerNode = _addNode('KSampler', {
      'seed': resolvedSeed,
      'steps': steps,
      'cfg': cfg,
      'sampler_name': sampler,
      'scheduler': scheduler,
      'denoise': denoise,
      'model': _nodeRef(_modelNode, _modelOutput),
      'positive': _nodeRef(_positiveNode, 0),
      'negative': _nodeRef(_negativeNode, 0),
      'latent_image': _nodeRef(_latentNode, 0),
    });

    // VAE Decode
    _imageNode = _addNode('VAEDecode', {
      'samples': _nodeRef(_samplerNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // Save image
    _addNode('SaveImage', {
      'filename_prefix': filenamePrefix,
      'images': _nodeRef(_imageNode, 0),
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build an OmniGen2 image generation workflow
  ///
  /// OmniGen2 uses Qwen VL encoder with type "omnigen2".
  /// Can do text-to-image or image-conditioned generation.
  Map<String, dynamic> buildOmniGen2({
    required String model,
    required String prompt,
    String negativePrompt = '',
    int width = 1024,
    int height = 1024,
    int steps = 20,
    double cfg = 5.0,
    int seed = -1,
    String sampler = 'euler',
    String scheduler = 'simple',
    int batchSize = 1,
    String? vae,
    String clipQwen = 'qwen_2.5_vl_fp16.safetensors',
    String? initImageBase64,
    double denoise = 1.0,
    String filenamePrefix = 'ERI_omnigen2',
    List<LoraConfig>? loras,
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);

    // Load OmniGen2 model using UNETLoader
    final weightDtype = model.toLowerCase().contains('fp8') ? 'fp8_e4m3fn' : 'default';
    _modelNode = _addNode('UNETLoader', {
      'unet_name': model,
      'weight_dtype': weightDtype,
    });
    _modelOutput = 0;

    // Load Qwen VL CLIP
    _clipNode = _addNode('CLIPLoader', {
      'clip_name': clipQwen,
    });
    _clipOutput = 0;

    // Apply LoRAs
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraNode = _addNode('LoraLoader', {
          'model': _nodeRef(_modelNode, _modelOutput),
          'clip': _nodeRef(_clipNode, _clipOutput),
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
          'strength_clip': lora.clipStrength,
        });
        _modelNode = loraNode;
        _modelOutput = 0;
        _clipNode = loraNode;
        _clipOutput = 1;
      }
    }

    // Load VAE (ae.safetensors for OmniGen2)
    _vaeNode = _addNode('VAELoader', {
      'vae_name': vae ?? 'ae.safetensors',
    });
    _vaeOutput = 0;

    // Encode prompts using standard CLIPTextEncode
    _positiveNode = _addNode('CLIPTextEncode', {
      'clip': _nodeRef(_clipNode, _clipOutput),
      'text': prompt,
    });

    _negativeNode = _addNode('CLIPTextEncode', {
      'clip': _nodeRef(_clipNode, _clipOutput),
      'text': negativePrompt,
    });

    // Create latent - img2img or empty
    if (initImageBase64 != null && initImageBase64.isNotEmpty) {
      final loadImageNode = _addNode('LoadImageBase64', {
        'image': initImageBase64,
      });

      final resizeNode = _addNode('ImageResize', {
        'image': _nodeRef(loadImageNode, 0),
        'width': width,
        'height': height,
        'interpolation': 'bicubic',
        'method': 'fill / crop',
        'condition': 'always',
      });

      _latentNode = _addNode('VAEEncode', {
        'pixels': _nodeRef(resizeNode, 0),
        'vae': _nodeRef(_vaeNode, _vaeOutput),
      });
    } else {
      _latentNode = _addNode('EmptySD3LatentImage', {
        'width': width,
        'height': height,
        'batch_size': batchSize,
      });
    }

    // Standard KSampler with CFG
    _samplerNode = _addNode('KSampler', {
      'seed': resolvedSeed,
      'steps': steps,
      'cfg': cfg,
      'sampler_name': sampler,
      'scheduler': scheduler,
      'denoise': denoise,
      'model': _nodeRef(_modelNode, _modelOutput),
      'positive': _nodeRef(_positiveNode, 0),
      'negative': _nodeRef(_negativeNode, 0),
      'latent_image': _nodeRef(_latentNode, 0),
    });

    // VAE Decode
    _imageNode = _addNode('VAEDecode', {
      'samples': _nodeRef(_samplerNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // Save image
    _addNode('SaveImage', {
      'filename_prefix': filenamePrefix,
      'images': _nodeRef(_imageNode, 0),
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build a high-resolution fix (hires) workflow
  ///
  /// First pass at lower resolution, then upscale and refine
  Map<String, dynamic> buildHiresFix({
    required String model,
    required String prompt,
    String negativePrompt = '',
    int width = 1024,
    int height = 1024,
    int steps = 20,
    double cfg = 7.0,
    int seed = -1,
    String sampler = 'euler',
    String scheduler = 'normal',
    String? vae,
    List<LoraConfig>? loras,
    // Hires settings
    double upscaleBy = 1.5,
    int hiresSteps = 10,
    double hiresDenoise = 0.5,
    String upscaleMethod = 'nearest-exact',
    // Advanced model patches
    FreeUConfig? freeU,
    DynamicThresholdingConfig? dynamicThresholding,
    String filenamePrefix = 'ERI_hires',
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);

    // First pass at target resolution
    _modelNode = _addNode('CheckpointLoaderSimple', {
      'ckpt_name': model,
    });
    _clipNode = _modelNode;
    _clipOutput = 1;
    _vaeNode = _modelNode;
    _vaeOutput = 2;

    // Custom VAE
    if (vae != null && vae.isNotEmpty) {
      _vaeNode = _addNode('VAELoader', {
        'vae_name': vae,
      });
      _vaeOutput = 0;
    }

    // Apply LoRAs
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraNode = _addNode('LoraLoader', {
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
          'strength_clip': lora.clipStrength,
          'model': _nodeRef(_modelNode, _modelOutput),
          'clip': _nodeRef(_clipNode, _clipOutput),
        });
        _modelNode = loraNode;
        _modelOutput = 0;
        _clipNode = loraNode;
        _clipOutput = 1;
      }
    }

    // FreeU
    if (freeU != null) {
      final freeUNode = _addNode('FreeU_V2', {
        'b1': freeU.b1,
        'b2': freeU.b2,
        's1': freeU.s1,
        's2': freeU.s2,
        'model': _nodeRef(_modelNode, _modelOutput),
      });
      _modelNode = freeUNode;
      _modelOutput = 0;
    }

    // Dynamic Thresholding
    if (dynamicThresholding != null) {
      final dtNode = _addNode('DynamicThresholdingFull', {
        'model': _nodeRef(_modelNode, _modelOutput),
        'mimic_scale': dynamicThresholding.mimicScale,
        'threshold_percentile': dynamicThresholding.thresholdPercentile,
        'mimic_mode': dynamicThresholding.mimicMode,
        'mimic_scale_min': dynamicThresholding.mimicScaleMin,
        'cfg_mode': dynamicThresholding.cfgMode,
        'cfg_scale_min': dynamicThresholding.cfgScaleMin,
        'sched_val': dynamicThresholding.schedVal,
        'separate_feature_channels':
            dynamicThresholding.separateFeatureChannels ? 'enable' : 'disable',
        'scaling_startpoint': dynamicThresholding.scalingStartpoint,
        'variability_measure': dynamicThresholding.variabilityMeasure,
        'interpolate_phi': dynamicThresholding.interpolatePhi,
      });
      _modelNode = dtNode;
      _modelOutput = 0;
    }

    // Encode prompts
    _positiveNode = _addNode('CLIPTextEncode', {
      'text': prompt,
      'clip': _nodeRef(_clipNode, _clipOutput),
    });

    _negativeNode = _addNode('CLIPTextEncode', {
      'text': negativePrompt,
      'clip': _nodeRef(_clipNode, _clipOutput),
    });

    // First pass latent
    _latentNode = _addNode('EmptyLatentImage', {
      'width': width,
      'height': height,
      'batch_size': 1,
    });

    // First pass sampler
    _samplerNode = _addNode('KSampler', {
      'seed': resolvedSeed,
      'steps': steps,
      'cfg': cfg,
      'sampler_name': sampler,
      'scheduler': scheduler,
      'denoise': 1.0,
      'model': _nodeRef(_modelNode, _modelOutput),
      'positive': _nodeRef(_positiveNode, 0),
      'negative': _nodeRef(_negativeNode, 0),
      'latent_image': _nodeRef(_latentNode, 0),
    });

    // Upscale latent
    final upscaledLatent = _addNode('LatentUpscaleBy', {
      'samples': _nodeRef(_samplerNode, 0),
      'upscale_method': upscaleMethod,
      'scale_by': upscaleBy,
    });

    // Second pass sampler (hires fix)
    final hiresSampler = _addNode('KSampler', {
      'seed': resolvedSeed,
      'steps': hiresSteps,
      'cfg': cfg,
      'sampler_name': sampler,
      'scheduler': scheduler,
      'denoise': hiresDenoise,
      'model': _nodeRef(_modelNode, _modelOutput),
      'positive': _nodeRef(_positiveNode, 0),
      'negative': _nodeRef(_negativeNode, 0),
      'latent_image': _nodeRef(upscaledLatent, 0),
    });

    // VAE Decode
    _imageNode = _addNode('VAEDecode', {
      'samples': _nodeRef(hiresSampler, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // Save Image
    _addNode('SaveImage', {
      'filename_prefix': filenamePrefix,
      'images': _nodeRef(_imageNode, 0),
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build a video generation workflow (for models like AnimateDiff, SVD, etc.)
  ///
  /// This is a basic structure - actual video models may require additional nodes
  Map<String, dynamic> buildVideo({
    required String model,
    required String prompt,
    String negativePrompt = '',
    int width = 512,
    int height = 512,
    int frames = 16,
    int fps = 8,
    int steps = 20,
    double cfg = 7.0,
    int seed = -1,
    String sampler = 'euler',
    String scheduler = 'normal',
    String? vae,
    // Motion module for AnimateDiff
    String? motionModule,
    double motionScale = 1.0,
    // Init image for SVD/video2video
    String? initImageBase64,
    double denoise = 1.0,
    // Output
    String filenamePrefix = 'ERI_video',
    String outputFormat = 'video/h264-mp4', // or 'image/gif'
    List<LoraConfig>? loras,
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);

    // Load checkpoint
    _modelNode = _addNode('CheckpointLoaderSimple', {
      'ckpt_name': model,
    });
    _modelOutput = 0;
    _clipNode = _modelNode;
    _clipOutput = 1;
    _vaeNode = _modelNode;
    _vaeOutput = 2;

    // Apply LoRAs (including LyCORIS - handled by standard LoraLoader)
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraNode = _addNode('LoraLoader', {
          'model': _nodeRef(_modelNode, _modelOutput),
          'clip': _nodeRef(_clipNode, _clipOutput),
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
          'strength_clip': lora.clipStrength,
        });
        _modelNode = loraNode;
        _modelOutput = 0;
        _clipNode = loraNode;
        _clipOutput = 1;
      }
    }

    // Custom VAE
    if (vae != null && vae.isNotEmpty) {
      _vaeNode = _addNode('VAELoader', {
        'vae_name': vae,
      });
      _vaeOutput = 0;
    }

    // Load motion module for AnimateDiff
    if (motionModule != null && motionModule.isNotEmpty) {
      final motionModuleNode = _addNode('ADE_LoadAnimateDiffModel', {
        'model_name': motionModule,
      });

      final applyMotion = _addNode('ADE_ApplyAnimateDiffModel', {
        'model': _nodeRef(_modelNode, _modelOutput),
        'motion_model': _nodeRef(motionModuleNode, 0),
        'motion_scale': motionScale,
      });
      _modelNode = applyMotion;
      _modelOutput = 0;
    }

    // Encode prompts
    _positiveNode = _addNode('CLIPTextEncode', {
      'text': prompt,
      'clip': _nodeRef(_clipNode, _clipOutput),
    });

    _negativeNode = _addNode('CLIPTextEncode', {
      'text': negativePrompt,
      'clip': _nodeRef(_clipNode, _clipOutput),
    });

    // Create latent (batch = frames for video)
    if (initImageBase64 != null && initImageBase64.isNotEmpty) {
      // Video2video: load and encode init image
      final loadImageNode = _addNode('LoadImageBase64', {
        'image': initImageBase64,
      });

      // For SVD, use SVD_img2vid_Conditioning
      _latentNode = _addNode('VAEEncode', {
        'pixels': _nodeRef(loadImageNode, 0),
        'vae': _nodeRef(_vaeNode, _vaeOutput),
      });

      // Repeat latent for frames
      _latentNode = _addNode('RepeatLatentBatch', {
        'samples': _nodeRef(_latentNode, 0),
        'amount': frames,
      });
    } else {
      // Empty latent batch for all frames
      _latentNode = _addNode('EmptyLatentImage', {
        'width': width,
        'height': height,
        'batch_size': frames,
      });
    }

    // KSampler
    _samplerNode = _addNode('KSampler', {
      'seed': resolvedSeed,
      'steps': steps,
      'cfg': cfg,
      'sampler_name': sampler,
      'scheduler': scheduler,
      'denoise': denoise,
      'model': _nodeRef(_modelNode, _modelOutput),
      'positive': _nodeRef(_positiveNode, 0),
      'negative': _nodeRef(_negativeNode, 0),
      'latent_image': _nodeRef(_latentNode, 0),
    });

    // VAE Decode
    _imageNode = _addNode('VAEDecode', {
      'samples': _nodeRef(_samplerNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // Combine frames to video
    final combineNode = _addNode('VHS_VideoCombine', {
      'images': _nodeRef(_imageNode, 0),
      'frame_rate': fps,
      'loop_count': 0,
      'filename_prefix': filenamePrefix,
      'format': outputFormat,
      'pingpong': false,
      'save_output': true,
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build a Stable Video Diffusion (SVD) workflow
  Map<String, dynamic> buildSVD({
    required String model,
    required String initImageBase64,
    int width = 1024,
    int height = 576,
    int frames = 25,
    int fps = 6,
    int steps = 20,
    double cfg = 2.5,
    int seed = -1,
    double motionBucketId = 127,
    double augmentationLevel = 0.0,
    double minCfg = 1.0,
    String filenamePrefix = 'ERI_svd',
    List<LoraConfig>? loras,
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);

    // Load SVD checkpoint
    final checkpointNode = _addNode('ImageOnlyCheckpointLoader', {
      'ckpt_name': model,
    });
    _modelNode = checkpointNode;
    _modelOutput = 0;
    _clipNode = checkpointNode;
    _clipOutput = 1;
    _vaeNode = checkpointNode;
    _vaeOutput = 2;

    // Apply LoRAs (model only - SVD uses clip_vision not standard CLIP)
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraNode = _addNode('LoraLoaderModelOnly', {
          'model': _nodeRef(_modelNode, _modelOutput),
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
        });
        _modelNode = loraNode;
        _modelOutput = 0;
      }
    }

    // Load init image
    final loadImageNode = _addNode('LoadImageBase64', {
      'image': initImageBase64,
    });

    // Resize image if needed
    final resizeNode = _addNode('ImageResize', {
      'image': _nodeRef(loadImageNode, 0),
      'width': width,
      'height': height,
      'interpolation': 'bicubic',
      'method': 'fill / crop',
      'condition': 'always',
    });

    // SVD conditioning
    final conditioningNode = _addNode('SVD_img2vid_Conditioning', {
      'clip_vision': _nodeRef(_clipNode, _clipOutput),
      'init_image': _nodeRef(resizeNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
      'width': width,
      'height': height,
      'video_frames': frames,
      'motion_bucket_id': motionBucketId.toInt(),
      'fps': fps,
      'augmentation_level': augmentationLevel,
    });

    // VideoLinearCFGGuidance for SVD
    final guidanceNode = _addNode('VideoLinearCFGGuidance', {
      'model': _nodeRef(_modelNode, _modelOutput),
      'min_cfg': minCfg,
    });

    // KSampler
    _samplerNode = _addNode('KSampler', {
      'seed': resolvedSeed,
      'steps': steps,
      'cfg': cfg,
      'sampler_name': 'euler',
      'scheduler': 'karras',
      'denoise': 1.0,
      'model': _nodeRef(guidanceNode, 0),
      'positive': _nodeRef(conditioningNode, 0),
      'negative': _nodeRef(conditioningNode, 1),
      'latent_image': _nodeRef(conditioningNode, 2),
    });

    // VAE Decode
    _imageNode = _addNode('VAEDecode', {
      'samples': _nodeRef(_samplerNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // Combine to video
    _addNode('VHS_VideoCombine', {
      'images': _nodeRef(_imageNode, 0),
      'frame_rate': fps,
      'loop_count': 0,
      'filename_prefix': filenamePrefix,
      'format': 'video/h264-mp4',
      'pingpong': false,
      'save_output': true,
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build an inpainting workflow
  Map<String, dynamic> buildInpaint({
    required String model,
    required String prompt,
    required String imageBase64,
    required String maskBase64,
    String negativePrompt = '',
    int steps = 20,
    double cfg = 7.0,
    int seed = -1,
    String sampler = 'euler',
    String scheduler = 'normal',
    double denoise = 1.0,
    String? vae,
    List<LoraConfig>? loras,
    int growMaskBy = 6,
    // Advanced model patches
    FreeUConfig? freeU,
    DynamicThresholdingConfig? dynamicThresholding,
    String filenamePrefix = 'ERI_inpaint',
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);

    // Load checkpoint
    _modelNode = _addNode('CheckpointLoaderSimple', {
      'ckpt_name': model,
    });
    _clipNode = _modelNode;
    _clipOutput = 1;
    _vaeNode = _modelNode;
    _vaeOutput = 2;

    // Custom VAE
    if (vae != null && vae.isNotEmpty) {
      _vaeNode = _addNode('VAELoader', {
        'vae_name': vae,
      });
      _vaeOutput = 0;
    }

    // Apply LoRAs
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraNode = _addNode('LoraLoader', {
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
          'strength_clip': lora.clipStrength,
          'model': _nodeRef(_modelNode, _modelOutput),
          'clip': _nodeRef(_clipNode, _clipOutput),
        });
        _modelNode = loraNode;
        _modelOutput = 0;
        _clipNode = loraNode;
        _clipOutput = 1;
      }
    }

    // Apply FreeU if enabled
    if (freeU != null) {
      final freeUNode = _addNode('FreeU_V2', {
        'b1': freeU.b1,
        'b2': freeU.b2,
        's1': freeU.s1,
        's2': freeU.s2,
        'model': _nodeRef(_modelNode, _modelOutput),
      });
      _modelNode = freeUNode;
      _modelOutput = 0;
    }

    // Apply Dynamic Thresholding if enabled
    if (dynamicThresholding != null) {
      final dtNode = _addNode('DynamicThresholdingFull', {
        'model': _nodeRef(_modelNode, _modelOutput),
        'mimic_scale': dynamicThresholding.mimicScale,
        'threshold_percentile': dynamicThresholding.thresholdPercentile,
        'mimic_mode': dynamicThresholding.mimicMode,
        'mimic_scale_min': dynamicThresholding.mimicScaleMin,
        'cfg_mode': dynamicThresholding.cfgMode,
        'cfg_scale_min': dynamicThresholding.cfgScaleMin,
        'sched_val': dynamicThresholding.schedVal,
        'separate_feature_channels':
            dynamicThresholding.separateFeatureChannels ? 'enable' : 'disable',
        'scaling_startpoint': dynamicThresholding.scalingStartpoint,
        'variability_measure': dynamicThresholding.variabilityMeasure,
        'interpolate_phi': dynamicThresholding.interpolatePhi,
      });
      _modelNode = dtNode;
      _modelOutput = 0;
    }

    // Load image
    final loadImageNode = _addNode('LoadImageBase64', {
      'image': imageBase64,
    });

    // Load mask
    final loadMaskNode = _addNode('LoadImageBase64', {
      'image': maskBase64,
    });

    // Convert mask to proper format (assume mask comes as RGB, convert to mask)
    final maskToImageNode = _addNode('ImageToMask', {
      'image': _nodeRef(loadMaskNode, 0),
      'channel': 'red',
    });

    // Grow mask
    final growMaskNode = _addNode('GrowMask', {
      'mask': _nodeRef(maskToImageNode, 0),
      'expand': growMaskBy,
      'tapered_corners': true,
    });

    // Set latent noise mask (for inpainting)
    final vaeEncodeNode = _addNode('VAEEncodeForInpaint', {
      'pixels': _nodeRef(loadImageNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
      'mask': _nodeRef(growMaskNode, 0),
      'grow_mask_by': growMaskBy,
    });
    _latentNode = vaeEncodeNode;

    // Encode prompts
    _positiveNode = _addNode('CLIPTextEncode', {
      'text': prompt,
      'clip': _nodeRef(_clipNode, _clipOutput),
    });

    _negativeNode = _addNode('CLIPTextEncode', {
      'text': negativePrompt,
      'clip': _nodeRef(_clipNode, _clipOutput),
    });

    // KSampler
    _samplerNode = _addNode('KSampler', {
      'seed': resolvedSeed,
      'steps': steps,
      'cfg': cfg,
      'sampler_name': sampler,
      'scheduler': scheduler,
      'denoise': denoise,
      'model': _nodeRef(_modelNode, _modelOutput),
      'positive': _nodeRef(_positiveNode, 0),
      'negative': _nodeRef(_negativeNode, 0),
      'latent_image': _nodeRef(_latentNode, 0),
    });

    // VAE Decode
    _imageNode = _addNode('VAEDecode', {
      'samples': _nodeRef(_samplerNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // Save Image
    _addNode('SaveImage', {
      'filename_prefix': filenamePrefix,
      'images': _nodeRef(_imageNode, 0),
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build a SDXL workflow with refiner
  Map<String, dynamic> buildSDXLWithRefiner({
    required String baseModel,
    required String refinerModel,
    required String prompt,
    String negativePrompt = '',
    int width = 1024,
    int height = 1024,
    int baseSteps = 25,
    int refinerSteps = 10,
    double baseCfg = 7.0,
    double refinerCfg = 7.0,
    int seed = -1,
    String sampler = 'euler',
    String scheduler = 'normal',
    double switchAt = 0.8, // Switch from base to refiner at this step %
    String? vae,
    List<LoraConfig>? loras,
    // Advanced model patches
    FreeUConfig? freeU,
    DynamicThresholdingConfig? dynamicThresholding,
    String filenamePrefix = 'ERI_sdxl',
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);

    // Load base checkpoint
    final baseCheckpoint = _addNode('CheckpointLoaderSimple', {
      'ckpt_name': baseModel,
    });
    _modelNode = baseCheckpoint;
    _modelOutput = 0;
    _clipNode = baseCheckpoint;
    _clipOutput = 1;
    _vaeNode = baseCheckpoint;
    _vaeOutput = 2;

    // Load refiner checkpoint
    final refinerCheckpoint = _addNode('CheckpointLoaderSimple', {
      'ckpt_name': refinerModel,
    });

    // Custom VAE
    if (vae != null && vae.isNotEmpty) {
      _vaeNode = _addNode('VAELoader', {
        'vae_name': vae,
      });
      _vaeOutput = 0;
    }

    // Apply LoRAs to base model
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraNode = _addNode('LoraLoader', {
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
          'strength_clip': lora.clipStrength,
          'model': _nodeRef(_modelNode, _modelOutput),
          'clip': _nodeRef(_clipNode, _clipOutput),
        });
        _modelNode = loraNode;
        _modelOutput = 0;
        _clipNode = loraNode;
        _clipOutput = 1;
      }
    }

    // Apply FreeU if enabled (base model only)
    if (freeU != null) {
      final freeUNode = _addNode('FreeU_V2', {
        'b1': freeU.b1,
        'b2': freeU.b2,
        's1': freeU.s1,
        's2': freeU.s2,
        'model': _nodeRef(_modelNode, _modelOutput),
      });
      _modelNode = freeUNode;
      _modelOutput = 0;
    }

    // Apply Dynamic Thresholding if enabled (base model only)
    if (dynamicThresholding != null) {
      final dtNode = _addNode('DynamicThresholdingFull', {
        'model': _nodeRef(_modelNode, _modelOutput),
        'mimic_scale': dynamicThresholding.mimicScale,
        'threshold_percentile': dynamicThresholding.thresholdPercentile,
        'mimic_mode': dynamicThresholding.mimicMode,
        'mimic_scale_min': dynamicThresholding.mimicScaleMin,
        'cfg_mode': dynamicThresholding.cfgMode,
        'cfg_scale_min': dynamicThresholding.cfgScaleMin,
        'sched_val': dynamicThresholding.schedVal,
        'separate_feature_channels':
            dynamicThresholding.separateFeatureChannels ? 'enable' : 'disable',
        'scaling_startpoint': dynamicThresholding.scalingStartpoint,
        'variability_measure': dynamicThresholding.variabilityMeasure,
        'interpolate_phi': dynamicThresholding.interpolatePhi,
      });
      _modelNode = dtNode;
      _modelOutput = 0;
    }

    // Base CLIP encode (SDXL has dual CLIP)
    final basePositive = _addNode('CLIPTextEncodeSDXL', {
      'text_g': prompt,
      'text_l': prompt,
      'width': width,
      'height': height,
      'crop_w': 0,
      'crop_h': 0,
      'target_width': width,
      'target_height': height,
      'clip': _nodeRef(_clipNode, _clipOutput),
    });

    final baseNegative = _addNode('CLIPTextEncodeSDXL', {
      'text_g': negativePrompt,
      'text_l': negativePrompt,
      'width': width,
      'height': height,
      'crop_w': 0,
      'crop_h': 0,
      'target_width': width,
      'target_height': height,
      'clip': _nodeRef(_clipNode, _clipOutput),
    });

    // Refiner CLIP encode
    final refinerPositive = _addNode('CLIPTextEncodeSDXLRefiner', {
      'text': prompt,
      'ascore': 6.0,
      'width': width,
      'height': height,
      'clip': _nodeRef(refinerCheckpoint, 1),
    });

    final refinerNegative = _addNode('CLIPTextEncodeSDXLRefiner', {
      'text': negativePrompt,
      'ascore': 2.5,
      'width': width,
      'height': height,
      'clip': _nodeRef(refinerCheckpoint, 1),
    });

    // Empty latent
    _latentNode = _addNode('EmptyLatentImage', {
      'width': width,
      'height': height,
      'batch_size': 1,
    });

    // Base KSampler
    final baseEnd = (baseSteps * switchAt).round();
    _samplerNode = _addNode('KSamplerAdvanced', {
      'seed': resolvedSeed,
      'steps': baseSteps,
      'cfg': baseCfg,
      'sampler_name': sampler,
      'scheduler': scheduler,
      'start_at_step': 0,
      'end_at_step': baseEnd,
      'add_noise': 'enable',
      'return_with_leftover_noise': 'enable',
      'model': _nodeRef(_modelNode, _modelOutput),
      'positive': _nodeRef(basePositive, 0),
      'negative': _nodeRef(baseNegative, 0),
      'latent_image': _nodeRef(_latentNode, 0),
    });

    // Refiner KSampler
    final refinerSampler = _addNode('KSamplerAdvanced', {
      'seed': resolvedSeed,
      'steps': baseSteps,
      'cfg': refinerCfg,
      'sampler_name': sampler,
      'scheduler': scheduler,
      'start_at_step': baseEnd,
      'end_at_step': baseSteps,
      'add_noise': 'disable',
      'return_with_leftover_noise': 'disable',
      'model': _nodeRef(refinerCheckpoint, 0),
      'positive': _nodeRef(refinerPositive, 0),
      'negative': _nodeRef(refinerNegative, 0),
      'latent_image': _nodeRef(_samplerNode, 0),
    });

    // VAE Decode
    _imageNode = _addNode('VAEDecode', {
      'samples': _nodeRef(refinerSampler, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // Save Image
    _addNode('SaveImage', {
      'filename_prefix': filenamePrefix,
      'images': _nodeRef(_imageNode, 0),
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build an upscale workflow using an upscale model
  Map<String, dynamic> buildUpscale({
    required String upscaleModel,
    required String imageBase64,
    String filenamePrefix = 'ERI_upscale',
  }) {
    reset();

    // Load upscale model
    final upscaleModelNode = _addNode('UpscaleModelLoader', {
      'model_name': upscaleModel,
    });

    // Load image
    final loadImageNode = _addNode('LoadImageBase64', {
      'image': imageBase64,
    });

    // Upscale
    _imageNode = _addNode('ImageUpscaleWithModel', {
      'upscale_model': _nodeRef(upscaleModelNode, 0),
      'image': _nodeRef(loadImageNode, 0),
    });

    // Save
    _addNode('SaveImage', {
      'filename_prefix': filenamePrefix,
      'images': _nodeRef(_imageNode, 0),
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Convert workflow to JSON string
  String toJson() {
    return jsonEncode(_workflow);
  }

  /// Convert workflow to pretty-printed JSON string
  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(_workflow);
  }

  /// Get the current workflow as a map
  Map<String, dynamic> get workflow => Map<String, dynamic>.from(_workflow);

  /// Get the ID of the last added node
  String get lastNodeId => _nodeId.toString();

  /// Get model node reference
  List<dynamic> get modelRef => _nodeRef(_modelNode, _modelOutput);

  /// Get CLIP node reference
  List<dynamic> get clipRef => _nodeRef(_clipNode, _clipOutput);

  /// Get VAE node reference
  List<dynamic> get vaeRef => _nodeRef(_vaeNode, _vaeOutput);

  // ============================================================================
  // VIDEO GENERATION WORKFLOWS
  // ============================================================================

  /// Build an LTX-2 video workflow exactly matching the official Lightricks reference.
  ///
  /// LTX-2 Video Workflow - Simplified single-stage sampling
  ///
  /// Uses only verified ComfyUI nodes:
  /// - CheckpointLoaderSimple, LTXAVTextEncoderLoader, LTXVAudioVAELoader
  /// - CLIPTextEncode, LTXVConditioning
  /// - EmptyLTXVLatentVideo, LTXVEmptyLatentAudio, LTXVConcatAVLatent
  /// - LTXVScheduler, RandomNoise, KSamplerSelect, CFGGuider
  /// - SamplerCustomAdvanced, LTXVSeparateAVLatent
  /// - VAEDecodeTiled, LTXVAudioVAEDecode, VHS_VideoCombine
  Map<String, dynamic> buildLTXVideo({
    required String model,
    required String prompt,
    String negativePrompt = '',
    int width = 1280,
    int height = 720,
    int frames = 121,
    int steps = 20,
    double cfg = 4.0,
    int seed = -1,
    int fps = 24,
    String? initImageBase64,
    double videoAugmentationLevel = 0.15,
    String filenamePrefix = 'ERI_ltx_video',
    String outputFormat = 'video/h264-mp4',
    List<LoraConfig>? loras,
    // LTX-specific parameters
    String textEncoder = 'gemma_3_12B_it.safetensors',
    String distilledLora = 'ltx-2-19b-distilled-lora-384.safetensors',
    String upscaleModel = 'ltx-2-spatial-upscaler-x2-1.0.safetensors',
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);

    // CheckpointLoaderSimple - load LTX model
    final checkpointNode = _addNode('CheckpointLoaderSimple', {
      'ckpt_name': model,
    });

    // LTXAVTextEncoderLoader - load gemma text encoder
    final clipNode = _addNode('LTXAVTextEncoderLoader', {
      'text_encoder': textEncoder,
      'ckpt_name': model,
    });

    // LTXVAudioVAELoader - load audio VAE from same checkpoint
    final audioVaeNode = _addNode('LTXVAudioVAELoader', {
      'ckpt_name': model,
    });

    // CLIPTextEncode - positive prompt
    final positiveNode = _addNode('CLIPTextEncode', {
      'text': prompt,
      'clip': _nodeRef(clipNode, 0),
    });

    // CLIPTextEncode - negative prompt
    final negativeNode = _addNode('CLIPTextEncode', {
      'text': negativePrompt,
      'clip': _nodeRef(clipNode, 0),
    });

    // LTXVConditioning - add frame rate to conditioning
    final conditioningNode = _addNode('LTXVConditioning', {
      'frame_rate': fps,
      'positive': _nodeRef(positiveNode, 0),
      'negative': _nodeRef(negativeNode, 0),
    });

    // EmptyLTXVLatentVideo - video latent
    final videoLatentNode = _addNode('EmptyLTXVLatentVideo', {
      'width': width,
      'height': height,
      'length': frames,
      'batch_size': 1,
    });

    // LTXVEmptyLatentAudio - audio latent
    final audioLatentNode = _addNode('LTXVEmptyLatentAudio', {
      'frames_number': frames,
      'frame_rate': fps,
      'batch_size': 1,
      'audio_vae': _nodeRef(audioVaeNode, 0),
    });

    // LTXVConcatAVLatent - combine video + audio latents
    final concatLatentNode = _addNode('LTXVConcatAVLatent', {
      'video_latent': _nodeRef(videoLatentNode, 0),
      'audio_latent': _nodeRef(audioLatentNode, 0),
    });

    // Apply LoRAs if provided
    var currentModel = checkpointNode;
    var currentModelOutput = 0;
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraNode = _addNode('LoraLoaderModelOnly', {
          'model': _nodeRef(currentModel, currentModelOutput),
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
        });
        currentModel = loraNode;
        currentModelOutput = 0;
      }
    }

    // LTXVScheduler - scheduler for sigmas
    final schedulerNode = _addNode('LTXVScheduler', {
      'steps': steps,
      'max_shift': 2.05,
      'base_shift': 0.95,
      'stretch': true,
      'terminal': 0.1,
      'latent': _nodeRef(concatLatentNode, 0),
    });

    // RandomNoise
    final noiseNode = _addNode('RandomNoise', {
      'noise_seed': resolvedSeed,
    });

    // KSamplerSelect - euler_ancestral sampler (as per reference)
    final samplerNode = _addNode('KSamplerSelect', {
      'sampler_name': 'euler_ancestral',
    });

    // CFGGuider - standard classifier-free guidance
    final guiderNode = _addNode('CFGGuider', {
      'cfg': cfg,
      'model': _nodeRef(currentModel, currentModelOutput),
      'positive': _nodeRef(conditioningNode, 0),
      'negative': _nodeRef(conditioningNode, 1),
    });

    // SamplerCustomAdvanced - sampling
    final samplerAdvNode = _addNode('SamplerCustomAdvanced', {
      'noise': _nodeRef(noiseNode, 0),
      'guider': _nodeRef(guiderNode, 0),
      'sampler': _nodeRef(samplerNode, 0),
      'sigmas': _nodeRef(schedulerNode, 0),
      'latent_image': _nodeRef(concatLatentNode, 0),
    });

    // LTXVSeparateAVLatent - separate video and audio
    final separateNode = _addNode('LTXVSeparateAVLatent', {
      'av_latent': _nodeRef(samplerAdvNode, 0),
    });

    // VAEDecodeTiled - decode video with tiling for large videos
    final imageNode = _addNode('VAEDecodeTiled', {
      'tile_size': 512,
      'overlap': 64,
      'temporal_size': 4096,
      'temporal_overlap': 8,
      'samples': _nodeRef(separateNode, 0),
      'vae': _nodeRef(checkpointNode, 2),
    });

    // LTXVAudioVAEDecode - decode audio
    final audioNode = _addNode('LTXVAudioVAEDecode', {
      'samples': _nodeRef(separateNode, 1),
      'audio_vae': _nodeRef(audioVaeNode, 0),
    });

    // VHS_VideoCombine - output video with audio
    _addNode('VHS_VideoCombine', {
      'images': _nodeRef(imageNode, 0),
      'audio': _nodeRef(audioNode, 0),
      'frame_rate': fps,
      'loop_count': 0,
      'filename_prefix': filenamePrefix,
      'format': outputFormat,
      'pix_fmt': 'yuv420p',
      'crf': 19,
      'save_metadata': true,
      'trim_to_audio': false,
      'pingpong': false,
      'save_output': true,
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build a Wan Video workflow with dual model support
  ///
  /// Wan uses a dual-model approach: high_noise model for early denoising steps
  /// and low_noise model for later refinement steps.
  /// Models are in diffusion_models/ directory, not checkpoints.
  Map<String, dynamic> buildWanVideo({
    required String highNoiseModel,
    required String lowNoiseModel,
    required String prompt,
    String negativePrompt = '',
    int width = 832,
    int height = 480,
    int frames = 81,
    int steps = 20,
    double cfg = 5.0,
    int seed = -1,
    int fps = 16,
    String? initImageBase64,
    double switchRatio = 0.5,
    String filenamePrefix = 'ERI_wan_video',
    String outputFormat = 'video/webp',
    String clipModel = 't5xxl_fp16.safetensors',
    String? vaeModel, // Auto-detect based on model version
    List<LoraConfig>? loras,
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);
    final switchStep = (steps * switchRatio).round();

    // Detect Wan version (2.1 vs 2.2) from model name
    final isWan22 = highNoiseModel.toLowerCase().contains('wan2.2') ||
        highNoiseModel.toLowerCase().contains('wan22');
    final autoVae = isWan22 ? 'wan2.2_vae.safetensors' : 'wan_2.1_vae.safetensors';
    final resolvedVae = vaeModel ?? autoVae;

    // Load high noise model using UNETLoader (diffusion_models path)
    final highWeightDtype = highNoiseModel.toLowerCase().contains('fp8') ? 'fp8_e4m3fn' : 'default';
    final highNoiseUnet = _addNode('UNETLoader', {
      'unet_name': highNoiseModel,
      'weight_dtype': highWeightDtype,
    });

    // Load low noise model using UNETLoader
    final lowWeightDtype = lowNoiseModel.toLowerCase().contains('fp8') ? 'fp8_e4m3fn' : 'default';
    var lowNoiseUnet = _addNode('UNETLoader', {
      'unet_name': lowNoiseModel,
      'weight_dtype': lowWeightDtype,
    });

    // Apply LoRAs to both models (model only, not clip - using LoraLoaderModelOnly)
    var highNoiseUnetFinal = highNoiseUnet;
    var highNoiseOutput = 0;
    var lowNoiseUnetFinal = lowNoiseUnet;
    var lowNoiseOutput = 0;
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        // Apply to high noise model
        final loraHighNode = _addNode('LoraLoaderModelOnly', {
          'model': _nodeRef(highNoiseUnetFinal, highNoiseOutput),
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
        });
        highNoiseUnetFinal = loraHighNode;
        highNoiseOutput = 0;

        // Apply to low noise model
        final loraLowNode = _addNode('LoraLoaderModelOnly', {
          'model': _nodeRef(lowNoiseUnetFinal, lowNoiseOutput),
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
        });
        lowNoiseUnetFinal = loraLowNode;
        lowNoiseOutput = 0;
      }
    }

    // Load CLIP text encoder (T5)
    _clipNode = _addNode('CLIPLoader', {
      'clip_name': clipModel,
    });
    _clipOutput = 0;

    // Load VAE
    _vaeNode = _addNode('VAELoader', {
      'vae_name': resolvedVae,
    });
    _vaeOutput = 0;

    // Encode prompts using standard CLIPTextEncode
    _positiveNode = _addNode('CLIPTextEncode', {
      'text': prompt,
      'clip': _nodeRef(_clipNode, _clipOutput),
    });

    _negativeNode = _addNode('CLIPTextEncode', {
      'text': negativePrompt,
      'clip': _nodeRef(_clipNode, _clipOutput),
    });

    // Handle start image for I2V mode
    String? startImageNode;
    if (initImageBase64 != null && initImageBase64.isNotEmpty) {
      final loadImageNode = _addNode('LoadImageBase64', {
        'image': initImageBase64,
      });

      startImageNode = _addNode('ImageResize', {
        'image': _nodeRef(loadImageNode, 0),
        'width': width,
        'height': height,
        'interpolation': 'bicubic',
        'method': 'fill / crop',
        'condition': 'always',
      });
    }

    // Use WanImageToVideo node for proper video latent + conditioning
    // This creates the correct 5D video latent and handles I2V conditioning
    final wanI2V = _addNode('WanImageToVideo', {
      'positive': _nodeRef(_positiveNode, 0),
      'negative': _nodeRef(_negativeNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
      'width': width,
      'height': height,
      'length': frames,
      'batch_size': 1,
      if (startImageNode != null) 'start_image': _nodeRef(startImageNode, 0),
    });

    // Get conditioned outputs from WanImageToVideo
    // Output 0: positive (conditioned), Output 1: negative (conditioned), Output 2: latent
    final conditionedPositive = wanI2V;
    const conditionedPositiveOutput = 0;
    final conditionedNegative = wanI2V;
    const conditionedNegativeOutput = 1;
    _latentNode = wanI2V;
    const latentOutput = 2;

    // First pass with high noise model (early steps)
    final highNoiseSampler = _addNode('KSamplerAdvanced', {
      'seed': resolvedSeed,
      'steps': steps,
      'cfg': cfg,
      'sampler_name': 'euler',
      'scheduler': 'normal',
      'start_at_step': 0,
      'end_at_step': switchStep,
      'add_noise': 'enable',
      'return_with_leftover_noise': 'enable',
      'model': _nodeRef(highNoiseUnetFinal, highNoiseOutput),
      'positive': _nodeRef(conditionedPositive, conditionedPositiveOutput),
      'negative': _nodeRef(conditionedNegative, conditionedNegativeOutput),
      'latent_image': _nodeRef(_latentNode, latentOutput),
    });

    // Second pass with low noise model (later steps)
    _samplerNode = _addNode('KSamplerAdvanced', {
      'seed': resolvedSeed,
      'steps': steps,
      'cfg': cfg,
      'sampler_name': 'euler',
      'scheduler': 'normal',
      'start_at_step': switchStep,
      'end_at_step': steps,
      'add_noise': 'disable',
      'return_with_leftover_noise': 'disable',
      'model': _nodeRef(lowNoiseUnetFinal, lowNoiseOutput),
      'positive': _nodeRef(conditionedPositive, conditionedPositiveOutput),
      'negative': _nodeRef(conditionedNegative, conditionedNegativeOutput),
      'latent_image': _nodeRef(highNoiseSampler, 0),
    });

    // VAE Decode
    _imageNode = _addNode('VAEDecode', {
      'samples': _nodeRef(_samplerNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // Combine frames to video using VHS_VideoCombine
    _addNode('VHS_VideoCombine', {
      'images': _nodeRef(_imageNode, 0),
      'frame_rate': fps,
      'loop_count': 0,
      'filename_prefix': filenamePrefix,
      'format': outputFormat,
      'pingpong': false,
      'save_output': true,
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build a Hunyuan Video workflow
  ///
  /// Hunyuan Video is a high-quality video generation model from Tencent.
  /// Uses proper Hunyuan-specific nodes for video latent and I2V conditioning.
  Map<String, dynamic> buildHunyuanVideo({
    required String model,
    required String prompt,
    String negativePrompt = '',
    int width = 848,
    int height = 480,
    int frames = 49,
    int steps = 30,
    double cfg = 6.0,
    int seed = -1,
    int fps = 24,
    String? initImageBase64,
    String filenamePrefix = 'ERI_hunyuan_video',
    String outputFormat = 'video/webp',
    String vaeModel = 'hunyuan_video_vae_bf16.safetensors',
    List<LoraConfig>? loras,
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);

    // Load Hunyuan model using UNETLoader (diffusion_models path)
    final weightDtype = model.toLowerCase().contains('fp8') ? 'fp8_e4m3fn' : 'default';
    _modelNode = _addNode('UNETLoader', {
      'unet_name': model,
      'weight_dtype': weightDtype,
    });
    _modelOutput = 0;

    // Apply LoRAs (model only, not clip - using LoraLoaderModelOnly)
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraNode = _addNode('LoraLoaderModelOnly', {
          'model': _nodeRef(_modelNode, _modelOutput),
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
        });
        _modelNode = loraNode;
        _modelOutput = 0;
      }
    }

    // Load CLIP using DualCLIPLoader for Hunyuan Video
    // Hunyuan Video uses llava + clip_l text encoders
    _clipNode = _addNode('DualCLIPLoader', {
      'clip_name1': 'llava_llama3_fp8_scaled.safetensors',
      'clip_name2': 'clip_l.safetensors',
      'type': 'hunyuan_video',
    });
    _clipOutput = 0;

    // Load VAE
    _vaeNode = _addNode('VAELoader', {
      'vae_name': vaeModel,
    });
    _vaeOutput = 0;

    // Encode prompts
    _positiveNode = _addNode('CLIPTextEncode', {
      'text': prompt,
      'clip': _nodeRef(_clipNode, _clipOutput),
    });

    _negativeNode = _addNode('CLIPTextEncode', {
      'text': negativePrompt,
      'clip': _nodeRef(_clipNode, _clipOutput),
    });

    // Handle I2V mode using HunyuanImageToVideo node
    String conditionedPositive;
    int conditionedPositiveOutput;

    if (initImageBase64 != null && initImageBase64.isNotEmpty) {
      // Load and resize start image
      final loadImageNode = _addNode('LoadImageBase64', {
        'image': initImageBase64,
      });

      final resizeNode = _addNode('ImageResize', {
        'image': _nodeRef(loadImageNode, 0),
        'width': width,
        'height': height,
        'interpolation': 'bicubic',
        'method': 'fill / crop',
        'condition': 'always',
      });

      // Use HunyuanImageToVideo for I2V mode
      // This creates proper video latent and conditioning
      final hunyuanI2V = _addNode('HunyuanImageToVideo', {
        'positive': _nodeRef(_positiveNode, 0),
        'vae': _nodeRef(_vaeNode, _vaeOutput),
        'width': width,
        'height': height,
        'length': frames,
        'batch_size': 1,
        'guidance_type': 'v1 (concat)',
        'start_image': _nodeRef(resizeNode, 0),
      });
      conditionedPositive = hunyuanI2V;
      conditionedPositiveOutput = 0;
      _latentNode = hunyuanI2V;
    } else {
      // Text-to-video mode - use EmptyHunyuanLatentVideo for proper 5D video latent
      _latentNode = _addNode('EmptyHunyuanLatentVideo', {
        'width': width,
        'height': height,
        'length': frames,
        'batch_size': 1,
      });
      conditionedPositive = _positiveNode;
      conditionedPositiveOutput = 0;
    }

    // KSampler
    _samplerNode = _addNode('KSampler', {
      'seed': resolvedSeed,
      'steps': steps,
      'cfg': cfg,
      'sampler_name': 'euler',
      'scheduler': 'normal',
      'denoise': 1.0,
      'model': _nodeRef(_modelNode, _modelOutput),
      'positive': _nodeRef(conditionedPositive, conditionedPositiveOutput),
      'negative': _nodeRef(_negativeNode, 0),
      'latent_image': _nodeRef(_latentNode, initImageBase64 != null ? 1 : 0),
    });

    // VAE Decode
    _imageNode = _addNode('VAEDecode', {
      'samples': _nodeRef(_samplerNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // Combine frames to video
    _addNode('VHS_VideoCombine', {
      'images': _nodeRef(_imageNode, 0),
      'frame_rate': fps,
      'loop_count': 0,
      'filename_prefix': filenamePrefix,
      'format': outputFormat,
      'pingpong': false,
      'save_output': true,
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build a Mochi Video workflow
  ///
  /// Mochi is a video generation model optimized for motion quality.
  Map<String, dynamic> buildMochiVideo({
    required String model,
    required String prompt,
    String negativePrompt = '',
    int width = 848,
    int height = 480,
    int frames = 84,
    int steps = 30,
    double cfg = 4.5,
    int seed = -1,
    int fps = 24,
    String? initImageBase64,
    String filenamePrefix = 'ERI_mochi_video',
    String outputFormat = 'video/webp',
    List<LoraConfig>? loras,
  }) {
    reset();
    final resolvedSeed = _resolveSeed(seed);

    // Load Mochi model using UNETLoader (diffusion_models path)
    final weightDtype = model.toLowerCase().contains('fp8') ? 'fp8_e4m3fn' : 'default';
    _modelNode = _addNode('UNETLoader', {
      'unet_name': model,
      'weight_dtype': weightDtype,
    });
    _modelOutput = 0;

    // Load CLIP using CLIPLoader
    _clipNode = _addNode('CLIPLoader', {
      'clip_name': 't5xxl_fp16.safetensors',
    });
    _clipOutput = 0;

    // Load VAE (use Mochi VAE if available, or standard video VAE)
    _vaeNode = _addNode('VAELoader', {
      'vae_name': 'mochi_preview_vae_bf16.safetensors',
    });
    _vaeOutput = 0;

    // Apply LoRAs (model only, not clip)
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraNode = _addNode('LoraLoaderModelOnly', {
          'model': _nodeRef(_modelNode, _modelOutput),
          'lora_name': lora.name,
          'strength_model': lora.modelStrength,
        });
        _modelNode = loraNode;
        _modelOutput = 0;
      }
    }

    // Encode prompts
    _positiveNode = _addNode('CLIPTextEncode', {
      'text': prompt,
      'clip': _nodeRef(_clipNode, _clipOutput),
    });

    _negativeNode = _addNode('CLIPTextEncode', {
      'text': negativePrompt,
      'clip': _nodeRef(_clipNode, _clipOutput),
    });

    // Create video latent using EmptyMochiLatentVideo (proper 5D latent)
    _latentNode = _addNode('EmptyMochiLatentVideo', {
      'width': width,
      'height': height,
      'length': frames,
      'batch_size': 1,
    });

    // KSampler with Mochi-optimized settings
    _samplerNode = _addNode('KSampler', {
      'seed': resolvedSeed,
      'steps': steps,
      'cfg': cfg,
      'sampler_name': 'euler',
      'scheduler': 'normal',
      'denoise': 1.0,
      'model': _nodeRef(_modelNode, _modelOutput),
      'positive': _nodeRef(_positiveNode, 0),
      'negative': _nodeRef(_negativeNode, 0),
      'latent_image': _nodeRef(_latentNode, 0),
    });

    // VAE Decode
    _imageNode = _addNode('VAEDecode', {
      'samples': _nodeRef(_samplerNode, 0),
      'vae': _nodeRef(_vaeNode, _vaeOutput),
    });

    // Combine frames to video
    _addNode('VHS_VideoCombine', {
      'images': _nodeRef(_imageNode, 0),
      'frame_rate': fps,
      'loop_count': 0,
      'filename_prefix': filenamePrefix,
      'format': outputFormat,
      'pingpong': false,
      'save_output': true,
    });

    return Map<String, dynamic>.from(_workflow);
  }

  /// Build a video workflow with automatic model type detection
  ///
  /// Automatically detects the video model type based on the model name and
  /// routes to the appropriate specialized workflow builder.
  Map<String, dynamic> buildVideoAuto({
    required String model,
    required String prompt,
    String negativePrompt = '',
    int width = 1024,
    int height = 576,
    int frames = 25,
    int steps = 25,
    double cfg = 7.0,
    int seed = -1,
    int fps = 24,
    String? initImageBase64,
    String? highNoiseModel,
    String? lowNoiseModel,
    double videoAugmentationLevel = 0.15,
    String outputFormat = 'video/webp',
    String filenamePrefix = 'ERI_video',
    // SVD-specific parameters
    double motionBucketId = 127,
    double augmentationLevel = 0.0,
    double minCfg = 1.0,
    // AnimateDiff-specific parameters
    String? motionModule,
    double motionScale = 1.0,
    // Wan-specific parameters
    double switchRatio = 0.5,
    // LoRAs
    List<LoraConfig>? loras,
  }) {
    final modelLower = model.toLowerCase();

    // Detect LTX Video models
    if (modelLower.contains('ltx')) {
      return buildLTXVideo(
        model: model,
        prompt: prompt,
        negativePrompt: negativePrompt,
        width: width,
        height: height,
        frames: frames,
        steps: steps,
        cfg: cfg,
        seed: seed,
        fps: fps,
        initImageBase64: initImageBase64,
        videoAugmentationLevel: videoAugmentationLevel,
        filenamePrefix: filenamePrefix,
        outputFormat: outputFormat,
        loras: loras,
      );
    }

    // Detect Wan Video models (dual model system)
    if (modelLower.contains('wan')) {
      // For Wan, we need both high and low noise models
      // If not provided, try to infer from model name or use the same model
      final highModel = highNoiseModel ?? model;
      final lowModel = lowNoiseModel ?? model;

      return buildWanVideo(
        highNoiseModel: highModel,
        lowNoiseModel: lowModel,
        prompt: prompt,
        negativePrompt: negativePrompt,
        width: width,
        height: height,
        frames: frames,
        steps: steps,
        cfg: cfg,
        seed: seed,
        fps: fps,
        initImageBase64: initImageBase64,
        switchRatio: switchRatio,
        filenamePrefix: filenamePrefix,
        outputFormat: outputFormat,
        loras: loras,
      );
    }

    // Detect Hunyuan Video models
    if (modelLower.contains('hunyuan')) {
      return buildHunyuanVideo(
        model: model,
        prompt: prompt,
        negativePrompt: negativePrompt,
        width: width,
        height: height,
        frames: frames,
        steps: steps,
        cfg: cfg,
        seed: seed,
        fps: fps,
        initImageBase64: initImageBase64,
        filenamePrefix: filenamePrefix,
        outputFormat: outputFormat,
        loras: loras,
      );
    }

    // Detect Mochi Video models
    if (modelLower.contains('mochi')) {
      return buildMochiVideo(
        model: model,
        prompt: prompt,
        negativePrompt: negativePrompt,
        width: width,
        height: height,
        frames: frames,
        steps: steps,
        cfg: cfg,
        seed: seed,
        fps: fps,
        initImageBase64: initImageBase64,
        filenamePrefix: filenamePrefix,
        outputFormat: outputFormat,
        loras: loras,
      );
    }

    // Detect SVD (Stable Video Diffusion) models
    if (modelLower.contains('svd') ||
        modelLower.contains('stable-video') ||
        modelLower.contains('stablevideo')) {
      // SVD requires an init image
      if (initImageBase64 != null && initImageBase64.isNotEmpty) {
        return buildSVD(
          model: model,
          initImageBase64: initImageBase64,
          width: width,
          height: height,
          frames: frames,
          fps: fps,
          steps: steps,
          cfg: cfg,
          seed: seed,
          motionBucketId: motionBucketId,
          augmentationLevel: augmentationLevel,
          minCfg: minCfg,
          filenamePrefix: filenamePrefix,
          loras: loras,
        );
      }
    }

    // Default to generic video workflow (AnimateDiff-style)
    return buildVideo(
      model: model,
      prompt: prompt,
      negativePrompt: negativePrompt,
      width: width,
      height: height,
      frames: frames,
      fps: fps,
      steps: steps,
      cfg: cfg,
      seed: seed,
      motionModule: motionModule,
      motionScale: motionScale,
      initImageBase64: initImageBase64,
      filenamePrefix: filenamePrefix,
      outputFormat: _convertOutputFormat(outputFormat),
      loras: loras,
    );
  }

  /// Convert output format string to VHS_VideoCombine compatible format
  String _convertOutputFormat(String format) {
    switch (format.toLowerCase()) {
      case 'webp':
      case 'video/webp':
        return 'video/webp';
      case 'gif':
      case 'image/gif':
        return 'image/gif';
      case 'mp4':
      case 'video/mp4':
      case 'video/h264-mp4':
        return 'video/h264-mp4';
      default:
        return format;
    }
  }
}
