import 'dart:convert';
import 'dart:math';

/// Workflow generator for ComfyUI - builds node graphs from parameters
/// Equivalent to SwarmUI's WorkflowGenerator
class WorkflowGenerator {
  /// All registered workflow steps
  static final List<WorkflowStep> _steps = [];

  /// User input parameters for this generation
  final Map<String, dynamic> userInput;

  /// Generated node IDs
  final Map<String, String> _nodeIds = {};

  /// Auto-incrementing node ID counter
  int _nextNodeId = 1;

  /// The workflow being built
  final Map<String, Map<String, dynamic>> nodes = {};

  /// Current model output reference
  List<dynamic>? modelOutput;

  /// Current positive conditioning output
  List<dynamic>? positiveConditioningOutput;

  /// Current negative conditioning output
  List<dynamic>? negativeConditioningOutput;

  /// Current latent output
  List<dynamic>? latentOutput;

  /// Final image output reference
  List<dynamic>? finalImageOutput;

  /// VAE output reference
  List<dynamic>? vaeOutput;

  /// CLIP output reference
  List<dynamic>? clipOutput;

  /// Extra data to store in workflow
  final Map<String, dynamic> extraData = {};

  /// Features used in this workflow
  final Set<String> usedFeatures = {};

  /// Main model name being used
  String? mainModelName;

  /// Resolution
  int width = 1024;
  int height = 1024;

  /// Steps and CFG
  int steps = 20;
  double cfgScale = 7.0;

  /// Seed
  int seed = -1;

  WorkflowGenerator({required this.userInput}) {
    // Initialize from user input
    width = userInput['width'] as int? ?? 1024;
    height = userInput['height'] as int? ?? 1024;
    steps = userInput['steps'] as int? ?? 20;
    cfgScale = (userInput['cfgscale'] as num?)?.toDouble() ?? 7.0;
    seed = userInput['seed'] as int? ?? -1;

    if (seed < 0) {
      seed = Random().nextInt(1 << 32);
    }
  }

  /// Register a workflow step
  static void addStep(
    void Function(WorkflowGenerator g) builder, {
    required double priority,
    String? name,
  }) {
    _steps.add(WorkflowStep(
      name: name ?? 'step_${_steps.length}',
      priority: priority,
      builder: builder,
    ));
    _steps.sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Clear all registered steps
  static void clearSteps() {
    _steps.clear();
  }

  /// Get a user input value
  T? get<T>(String key) {
    final value = userInput[key];
    if (value == null) return null;
    if (value is T) return value;
    return null;
  }

  /// Get a user input value with default
  T getOr<T>(String key, T defaultValue) {
    return get<T>(key) ?? defaultValue;
  }

  /// Check if user input has a value
  bool has(String key) {
    final value = userInput[key];
    if (value == null) return false;
    if (value is String && value.isEmpty) return false;
    if (value is List && value.isEmpty) return false;
    return true;
  }

  /// Create a new node and return its ID
  String createNode(String nodeClass, Map<String, dynamic> inputs, {String? id}) {
    final nodeId = id ?? '${_nextNodeId++}';
    _nodeIds[nodeClass] = nodeId;

    nodes[nodeId] = {
      'class_type': nodeClass,
      'inputs': inputs,
    };

    return nodeId;
  }

  /// Get an existing node ID or create placeholder
  String getNodeId(String nodeClass) {
    return _nodeIds[nodeClass] ?? nodeClass;
  }

  /// Update inputs on an existing node
  void updateNode(String nodeId, Map<String, dynamic> updates) {
    final node = nodes[nodeId];
    if (node != null) {
      final inputs = node['inputs'] as Map<String, dynamic>;
      inputs.addAll(updates);
    }
  }

  /// Build the complete workflow
  Map<String, dynamic> build() {
    // Run all registered steps in priority order
    for (final step in _steps) {
      try {
        step.builder(this);
      } catch (e) {
        throw WorkflowException('Failed in step ${step.name}: $e');
      }
    }

    // Create the final workflow structure
    return {
      'prompt': nodes,
      if (extraData.isNotEmpty) 'extra_data': extraData,
    };
  }

  /// Build a basic txt2img workflow
  Map<String, dynamic> buildBasicTxt2Img() {
    final prompt = getOr<String>('prompt', '');
    final negPrompt = getOr<String>('negativeprompt', '');
    final model = getOr<String>('model', '');
    final sampler = getOr<String>('sampler', 'euler');
    final scheduler = getOr<String>('scheduler', 'normal');

    // Load checkpoint
    final loadCheckpoint = createNode('CheckpointLoaderSimple', {
      'ckpt_name': model,
    });
    modelOutput = [loadCheckpoint, 0];
    clipOutput = [loadCheckpoint, 1];
    vaeOutput = [loadCheckpoint, 2];

    // Encode positive prompt
    final posEncode = createNode('CLIPTextEncode', {
      'text': prompt,
      'clip': clipOutput,
    });
    positiveConditioningOutput = [posEncode, 0];

    // Encode negative prompt
    final negEncode = createNode('CLIPTextEncode', {
      'text': negPrompt,
      'clip': clipOutput,
    });
    negativeConditioningOutput = [negEncode, 0];

    // Create empty latent
    final emptyLatent = createNode('EmptyLatentImage', {
      'width': width,
      'height': height,
      'batch_size': getOr<int>('images', 1),
    });
    latentOutput = [emptyLatent, 0];

    // KSampler
    final kSampler = createNode('KSampler', {
      'model': modelOutput,
      'positive': positiveConditioningOutput,
      'negative': negativeConditioningOutput,
      'latent_image': latentOutput,
      'seed': seed,
      'steps': steps,
      'cfg': cfgScale,
      'sampler_name': sampler,
      'scheduler': scheduler,
      'denoise': 1.0,
    });
    latentOutput = [kSampler, 0];

    // VAE Decode
    final vaeDecode = createNode('VAEDecode', {
      'samples': latentOutput,
      'vae': vaeOutput,
    });
    finalImageOutput = [vaeDecode, 0];

    // Save image
    createNode('SaveImage', {
      'images': finalImageOutput,
      'filename_prefix': 'EriUI',
    });

    return {'prompt': nodes};
  }

  /// Build img2img workflow
  Map<String, dynamic> buildImg2Img({
    required String initImagePath,
    double denoise = 0.6,
  }) {
    final workflow = buildBasicTxt2Img();

    // Load the init image
    final loadImage = createNode('LoadImage', {
      'image': initImagePath,
    });

    // Encode to latent
    final encodeVae = createNode('VAEEncode', {
      'pixels': [loadImage, 0],
      'vae': vaeOutput,
    });

    // Update KSampler to use encoded latent and denoise
    for (final node in nodes.entries) {
      if (node.value['class_type'] == 'KSampler') {
        updateNode(node.key, {
          'latent_image': [encodeVae, 0],
          'denoise': denoise,
        });
        break;
      }
    }

    // Remove empty latent node
    nodes.removeWhere((k, v) => v['class_type'] == 'EmptyLatentImage');

    return {'prompt': nodes};
  }

  /// Build inpainting workflow
  Map<String, dynamic> buildInpaint({
    required String initImagePath,
    required String maskImagePath,
    double denoise = 1.0,
  }) {
    final workflow = buildImg2Img(
      initImagePath: initImagePath,
      denoise: denoise,
    );

    // Load mask
    final loadMask = createNode('LoadImage', {
      'image': maskImagePath,
    });

    // Apply mask to latent
    final setMask = createNode('SetLatentNoiseMask', {
      'samples': latentOutput,
      'mask': [loadMask, 1], // Channel 1 is the mask
    });

    // Update KSampler to use masked latent
    for (final node in nodes.entries) {
      if (node.value['class_type'] == 'KSampler') {
        updateNode(node.key, {
          'latent_image': [setMask, 0],
        });
        break;
      }
    }

    return {'prompt': nodes};
  }

  /// Add LoRA to the workflow
  void addLoRA({
    required String loraName,
    double modelStrength = 1.0,
    double clipStrength = 1.0,
  }) {
    usedFeatures.add('lora');

    final loraLoader = createNode('LoraLoader', {
      'model': modelOutput,
      'clip': clipOutput,
      'lora_name': loraName,
      'strength_model': modelStrength,
      'strength_clip': clipStrength,
    });

    modelOutput = [loraLoader, 0];
    clipOutput = [loraLoader, 1];
  }

  /// Add ControlNet to the workflow
  void addControlNet({
    required String controlNetName,
    required String imagePath,
    double strength = 1.0,
  }) {
    usedFeatures.add('controlnet');

    // Load control image
    final loadImage = createNode('LoadImage', {
      'image': imagePath,
    });

    // Load ControlNet
    final loadControlNet = createNode('ControlNetLoader', {
      'control_net_name': controlNetName,
    });

    // Apply ControlNet
    final applyControlNet = createNode('ControlNetApplyAdvanced', {
      'positive': positiveConditioningOutput,
      'negative': negativeConditioningOutput,
      'control_net': [loadControlNet, 0],
      'image': [loadImage, 0],
      'strength': strength,
      'start_percent': 0.0,
      'end_percent': 1.0,
    });

    positiveConditioningOutput = [applyControlNet, 0];
    negativeConditioningOutput = [applyControlNet, 1];
  }

  /// Add upscaler to the workflow
  void addUpscale({
    required String upscalerName,
    double scale = 2.0,
  }) {
    usedFeatures.add('upscale');

    // Load upscale model
    final loadUpscaler = createNode('UpscaleModelLoader', {
      'model_name': upscalerName,
    });

    // Upscale image
    final upscale = createNode('ImageUpscaleWithModel', {
      'upscale_model': [loadUpscaler, 0],
      'image': finalImageOutput,
    });

    finalImageOutput = [upscale, 0];
  }

  /// Add face restore to the workflow
  void addFaceRestore({
    String model = 'GFPGANv1.4.pth',
    double strength = 1.0,
  }) {
    usedFeatures.add('facerestore');

    final faceRestore = createNode('FaceRestoreWithModel', {
      'image': finalImageOutput,
      'face_restore_model': model,
      'facedetection': 'retinaface_resnet50',
      'codeformer_fidelity': strength,
    });

    finalImageOutput = [faceRestore, 0];
  }

  /// Set custom VAE
  void setVAE(String vaeName) {
    usedFeatures.add('custom_vae');

    final loadVae = createNode('VAELoader', {
      'vae_name': vaeName,
    });

    vaeOutput = [loadVae, 0];
  }

  /// Get the workflow as JSON string
  String toJson() {
    return jsonEncode(build());
  }
}

/// A workflow generation step
class WorkflowStep {
  final String name;
  final double priority;
  final void Function(WorkflowGenerator g) builder;

  WorkflowStep({
    required this.name,
    required this.priority,
    required this.builder,
  });
}

/// Workflow generation exception
class WorkflowException implements Exception {
  final String message;
  WorkflowException(this.message);

  @override
  String toString() => 'WorkflowException: $message';
}

/// Standard workflow step priorities
class WorkflowPriorities {
  /// Before anything else
  static const double preInit = -100;

  /// Load checkpoint
  static const double loadModel = -50;

  /// Apply LoRAs
  static const double applyLoras = -40;

  /// Setup VAE
  static const double setupVae = -30;

  /// Text encoding
  static const double textEncode = -20;

  /// ControlNet setup
  static const double controlNet = -10;

  /// Create latent
  static const double createLatent = 0;

  /// Sampling
  static const double sample = 5;

  /// VAE decode
  static const double vaeDecode = 8;

  /// Post-processing
  static const double postProcess = 9;

  /// Save image (should be last)
  static const double saveImage = 10;
}
