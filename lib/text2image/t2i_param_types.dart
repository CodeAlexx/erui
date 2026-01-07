/// Central parameter registry for T2I generation
/// Equivalent to SwarmUI's T2IParamTypes
class T2IParamTypes {
  /// All registered parameters
  static final Map<String, T2IParamType> _types = {};

  /// All parameter groups
  static final Map<String, T2IParamGroup> _groups = {};

  /// Get all registered types
  static Map<String, T2IParamType> get types => Map.unmodifiable(_types);

  /// Get all registered groups
  static Map<String, T2IParamGroup> get groups => Map.unmodifiable(_groups);

  // ========== CORE PARAMETERS ==========

  static late T2IParamType prompt;
  static late T2IParamType negativePrompt;
  static late T2IParamType images;
  static late T2IParamType seed;
  static late T2IParamType steps;
  static late T2IParamType cfgScale;
  static late T2IParamType width;
  static late T2IParamType height;
  static late T2IParamType aspectRatio;

  // ========== MODEL PARAMETERS ==========

  static late T2IParamType model;
  static late T2IParamType vae;
  static late T2IParamType loras;
  static late T2IParamType loraWeights;

  // ========== SAMPLING PARAMETERS ==========

  static late T2IParamType sampler;
  static late T2IParamType scheduler;

  // ========== INIT IMAGE PARAMETERS ==========

  static late T2IParamType initImage;
  static late T2IParamType initImageCreativity;
  static late T2IParamType maskImage;

  /// Register all default parameters
  static void registerDefaults() {
    _types.clear();
    _groups.clear();

    // ========== GROUPS ==========

    final promptGroup = _registerGroup(T2IParamGroup(
      id: 'prompt',
      name: 'Prompt',
      description: 'Text prompt settings',
      open: true,
      orderPriority: -100,
    ));

    final coreGroup = _registerGroup(T2IParamGroup(
      id: 'core',
      name: 'Core Parameters',
      description: 'Essential generation parameters',
      open: true,
      orderPriority: -50,
    ));

    final resolutionGroup = _registerGroup(T2IParamGroup(
      id: 'resolution',
      name: 'Resolution',
      description: 'Image dimensions',
      open: false,
      orderPriority: -40,
    ));

    final samplingGroup = _registerGroup(T2IParamGroup(
      id: 'sampling',
      name: 'Sampling',
      description: 'Sampler and scheduler settings',
      open: false,
      orderPriority: -30,
    ));

    final initImageGroup = _registerGroup(T2IParamGroup(
      id: 'init_image',
      name: 'Init Image',
      description: 'Image-to-image settings',
      open: false,
      toggles: true,
      orderPriority: -20,
    ));

    final advancedGroup = _registerGroup(T2IParamGroup(
      id: 'advanced',
      name: 'Advanced',
      description: 'Advanced generation options',
      open: false,
      orderPriority: 10,
    ));

    final controlNetGroup = _registerGroup(T2IParamGroup(
      id: 'controlnet',
      name: 'ControlNet',
      description: 'ControlNet settings',
      open: false,
      toggles: true,
      orderPriority: 20,
    ));

    final refinementGroup = _registerGroup(T2IParamGroup(
      id: 'refinement',
      name: 'Refinement',
      description: 'Post-processing and refinement',
      open: false,
      orderPriority: 30,
    ));

    // ========== PROMPT PARAMETERS ==========

    prompt = _register(T2IParamType(
      id: 'prompt',
      name: 'Prompt',
      description: 'The text prompt describing what to generate.',
      type: ParamDataType.text,
      defaultValue: '',
      group: promptGroup,
      viewType: ParamViewType.prompt,
    ));

    negativePrompt = _register(T2IParamType(
      id: 'negativeprompt',
      name: 'Negative Prompt',
      description: 'What to avoid in the generated image.',
      type: ParamDataType.text,
      defaultValue: '',
      group: promptGroup,
      viewType: ParamViewType.prompt,
    ));

    // ========== CORE PARAMETERS ==========

    images = _register(T2IParamType(
      id: 'images',
      name: 'Images',
      description: 'Number of images to generate.',
      type: ParamDataType.integer,
      defaultValue: 1,
      min: 1,
      max: 10000,
      viewMax: 100,
      group: coreGroup,
    ));

    seed = _register(T2IParamType(
      id: 'seed',
      name: 'Seed',
      description: 'Random seed. Use -1 for random.',
      type: ParamDataType.integer,
      defaultValue: -1,
      min: -1,
      max: (1 << 32) - 1,
      group: coreGroup,
      viewType: ParamViewType.seed,
    ));

    steps = _register(T2IParamType(
      id: 'steps',
      name: 'Steps',
      description: 'Number of diffusion steps.',
      type: ParamDataType.integer,
      defaultValue: 20,
      min: 1,
      max: 500,
      viewMax: 100,
      group: coreGroup,
    ));

    cfgScale = _register(T2IParamType(
      id: 'cfgscale',
      name: 'CFG Scale',
      description: 'How strongly to follow the prompt.',
      type: ParamDataType.decimal,
      defaultValue: 7.0,
      min: 0.0,
      max: 100.0,
      viewMax: 20.0,
      step: 0.5,
      group: coreGroup,
    ));

    // ========== MODEL PARAMETERS ==========

    model = _register(T2IParamType(
      id: 'model',
      name: 'Model',
      description: 'Main generation model.',
      type: ParamDataType.model,
      subtype: 'Stable-Diffusion',
      defaultValue: '',
      group: coreGroup,
    ));

    vae = _register(T2IParamType(
      id: 'vae',
      name: 'VAE',
      description: 'VAE for encoding/decoding.',
      type: ParamDataType.model,
      subtype: 'VAE',
      defaultValue: 'None',
      group: advancedGroup,
      toggleable: true,
    ));

    loras = _register(T2IParamType(
      id: 'loras',
      name: 'LoRAs',
      description: 'LoRA models to apply.',
      type: ParamDataType.list,
      subtype: 'LoRA',
      defaultValue: <String>[],
      group: advancedGroup,
    ));

    loraWeights = _register(T2IParamType(
      id: 'loraweights',
      name: 'LoRA Weights',
      description: 'Weight for each LoRA.',
      type: ParamDataType.list,
      subtype: 'decimal',
      defaultValue: <double>[],
      group: advancedGroup,
    ));

    // ========== RESOLUTION PARAMETERS ==========

    aspectRatio = _register(T2IParamType(
      id: 'aspectratio',
      name: 'Aspect Ratio',
      description: 'Image aspect ratio.',
      type: ParamDataType.dropdown,
      defaultValue: '1:1',
      values: [
        '1:1', '4:3', '3:2', '8:5', '16:9', '21:9',
        '3:4', '2:3', '5:8', '9:16', '9:21', 'Custom'
      ],
      group: resolutionGroup,
    ));

    width = _register(T2IParamType(
      id: 'width',
      name: 'Width',
      description: 'Image width in pixels.',
      type: ParamDataType.integer,
      defaultValue: 1024,
      min: 64,
      max: 16384,
      viewMax: 2048,
      step: 64,
      group: resolutionGroup,
    ));

    height = _register(T2IParamType(
      id: 'height',
      name: 'Height',
      description: 'Image height in pixels.',
      type: ParamDataType.integer,
      defaultValue: 1024,
      min: 64,
      max: 16384,
      viewMax: 2048,
      step: 64,
      group: resolutionGroup,
    ));

    // ========== SAMPLING PARAMETERS ==========

    sampler = _register(T2IParamType(
      id: 'sampler',
      name: 'Sampler',
      description: 'Sampling algorithm.',
      type: ParamDataType.dropdown,
      defaultValue: 'euler',
      values: [
        'euler', 'euler_ancestral', 'heun', 'heunpp2',
        'dpm_2', 'dpm_2_ancestral', 'lms', 'dpm_fast',
        'dpm_adaptive', 'dpmpp_2s_ancestral', 'dpmpp_sde',
        'dpmpp_sde_gpu', 'dpmpp_2m', 'dpmpp_2m_sde',
        'dpmpp_2m_sde_gpu', 'dpmpp_3m_sde', 'dpmpp_3m_sde_gpu',
        'ddpm', 'lcm', 'ddim', 'uni_pc', 'uni_pc_bh2',
      ],
      group: samplingGroup,
    ));

    scheduler = _register(T2IParamType(
      id: 'scheduler',
      name: 'Scheduler',
      description: 'Noise scheduler.',
      type: ParamDataType.dropdown,
      defaultValue: 'normal',
      values: [
        'normal', 'karras', 'exponential', 'sgm_uniform',
        'simple', 'ddim_uniform', 'beta', 'ays', 'gits',
      ],
      group: samplingGroup,
    ));

    // ========== INIT IMAGE PARAMETERS ==========

    initImage = _register(T2IParamType(
      id: 'initimage',
      name: 'Init Image',
      description: 'Starting image for img2img.',
      type: ParamDataType.image,
      group: initImageGroup,
      toggleable: true,
    ));

    initImageCreativity = _register(T2IParamType(
      id: 'initimagecreativity',
      name: 'Creativity',
      description: '0 = follow original, 1 = ignore original.',
      type: ParamDataType.decimal,
      defaultValue: 0.6,
      min: 0.0,
      max: 1.0,
      step: 0.05,
      group: initImageGroup,
    ));

    maskImage = _register(T2IParamType(
      id: 'maskimage',
      name: 'Mask Image',
      description: 'Inpainting mask. White = change, black = preserve.',
      type: ParamDataType.image,
      group: initImageGroup,
      toggleable: true,
    ));

    // ========== ADVANCED PARAMETERS ==========

    _register(T2IParamType(
      id: 'clipskip',
      name: 'CLIP Skip',
      description: 'Number of CLIP layers to skip.',
      type: ParamDataType.integer,
      defaultValue: 1,
      min: 1,
      max: 12,
      group: advancedGroup,
      toggleable: true,
    ));

    _register(T2IParamType(
      id: 'seamlesstileable',
      name: 'Seamless Tileable',
      description: 'Generate seamlessly tileable images.',
      type: ParamDataType.dropdown,
      defaultValue: 'false',
      values: ['false', 'true', 'X-Only', 'Y-Only'],
      group: advancedGroup,
    ));

    _register(T2IParamType(
      id: 'freeu',
      name: 'FreeU',
      description: 'Enable FreeU enhancement.',
      type: ParamDataType.boolean,
      defaultValue: false,
      group: advancedGroup,
      toggleable: true,
    ));

    _register(T2IParamType(
      id: 'freeub1',
      name: 'FreeU B1',
      description: 'FreeU B1 parameter.',
      type: ParamDataType.decimal,
      defaultValue: 1.3,
      min: 0.0,
      max: 3.0,
      step: 0.1,
      group: advancedGroup,
    ));

    _register(T2IParamType(
      id: 'freeub2',
      name: 'FreeU B2',
      description: 'FreeU B2 parameter.',
      type: ParamDataType.decimal,
      defaultValue: 1.4,
      min: 0.0,
      max: 3.0,
      step: 0.1,
      group: advancedGroup,
    ));

    _register(T2IParamType(
      id: 'freeus1',
      name: 'FreeU S1',
      description: 'FreeU S1 parameter.',
      type: ParamDataType.decimal,
      defaultValue: 0.9,
      min: 0.0,
      max: 3.0,
      step: 0.1,
      group: advancedGroup,
    ));

    _register(T2IParamType(
      id: 'freeus2',
      name: 'FreeU S2',
      description: 'FreeU S2 parameter.',
      type: ParamDataType.decimal,
      defaultValue: 0.2,
      min: 0.0,
      max: 3.0,
      step: 0.1,
      group: advancedGroup,
    ));

    // ========== CONTROLNET PARAMETERS ==========

    _register(T2IParamType(
      id: 'controlnetmodel',
      name: 'ControlNet Model',
      description: 'ControlNet model to use.',
      type: ParamDataType.model,
      subtype: 'ControlNet',
      defaultValue: '',
      group: controlNetGroup,
      toggleable: true,
    ));

    _register(T2IParamType(
      id: 'controlnetimage',
      name: 'ControlNet Image',
      description: 'Input image for ControlNet.',
      type: ParamDataType.image,
      group: controlNetGroup,
    ));

    _register(T2IParamType(
      id: 'controlnetstrength',
      name: 'ControlNet Strength',
      description: 'How strongly to apply ControlNet.',
      type: ParamDataType.decimal,
      defaultValue: 1.0,
      min: 0.0,
      max: 2.0,
      step: 0.05,
      group: controlNetGroup,
    ));

    _register(T2IParamType(
      id: 'controlnetstartpercent',
      name: 'Start Percent',
      description: 'When to start applying ControlNet.',
      type: ParamDataType.decimal,
      defaultValue: 0.0,
      min: 0.0,
      max: 1.0,
      step: 0.05,
      group: controlNetGroup,
    ));

    _register(T2IParamType(
      id: 'controlnetendpercent',
      name: 'End Percent',
      description: 'When to stop applying ControlNet.',
      type: ParamDataType.decimal,
      defaultValue: 1.0,
      min: 0.0,
      max: 1.0,
      step: 0.05,
      group: controlNetGroup,
    ));

    // ========== REFINEMENT PARAMETERS ==========

    _register(T2IParamType(
      id: 'refinermodel',
      name: 'Refiner Model',
      description: 'Refiner model (SDXL).',
      type: ParamDataType.model,
      subtype: 'Stable-Diffusion',
      defaultValue: '',
      group: refinementGroup,
      toggleable: true,
    ));

    _register(T2IParamType(
      id: 'refinercontrolpercent',
      name: 'Refiner Switch',
      description: 'When to switch to refiner.',
      type: ParamDataType.decimal,
      defaultValue: 0.8,
      min: 0.0,
      max: 1.0,
      step: 0.05,
      group: refinementGroup,
    ));

    _register(T2IParamType(
      id: 'upscaler',
      name: 'Upscaler',
      description: 'Upscale model to use.',
      type: ParamDataType.model,
      subtype: 'Upscaler',
      defaultValue: '',
      group: refinementGroup,
      toggleable: true,
    ));

    _register(T2IParamType(
      id: 'upscalefactor',
      name: 'Upscale Factor',
      description: 'Upscale multiplier.',
      type: ParamDataType.decimal,
      defaultValue: 2.0,
      min: 1.0,
      max: 8.0,
      step: 0.5,
      group: refinementGroup,
    ));

    // ========== VIDEO PARAMETERS ==========

    final videoGroup = _registerGroup(T2IParamGroup(
      id: 'video',
      name: 'Video',
      description: 'Video generation settings',
      open: false,
      toggles: true,
      orderPriority: 40,
    ));

    _register(T2IParamType(
      id: 'videomodel',
      name: 'Video Model',
      description: 'Video generation model.',
      type: ParamDataType.model,
      subtype: 'SVD',
      defaultValue: '',
      group: videoGroup,
      toggleable: true,
      featureFlag: 'video',
    ));

    _register(T2IParamType(
      id: 'videoframes',
      name: 'Frames',
      description: 'Number of video frames.',
      type: ParamDataType.integer,
      defaultValue: 25,
      min: 1,
      max: 1000,
      viewMax: 100,
      group: videoGroup,
      featureFlag: 'video',
    ));

    _register(T2IParamType(
      id: 'videofps',
      name: 'FPS',
      description: 'Frames per second.',
      type: ParamDataType.integer,
      defaultValue: 8,
      min: 1,
      max: 120,
      group: videoGroup,
      featureFlag: 'video',
    ));

    _register(T2IParamType(
      id: 'videomotionbucket',
      name: 'Motion Bucket',
      description: 'Motion amount for SVD.',
      type: ParamDataType.integer,
      defaultValue: 127,
      min: 1,
      max: 255,
      group: videoGroup,
      featureFlag: 'video',
    ));

    // Sort groups
    final sortedGroups = _groups.values.toList()
      ..sort((a, b) => a.orderPriority.compareTo(b.orderPriority));
    _groups.clear();
    for (final g in sortedGroups) {
      _groups[g.id] = g;
    }
  }

  static T2IParamType _register(T2IParamType type) {
    _types[type.id] = type;
    return type;
  }

  static T2IParamGroup _registerGroup(T2IParamGroup group) {
    _groups[group.id] = group;
    return group;
  }

  /// Get a parameter type by ID
  static T2IParamType? getType(String id) => _types[id.toLowerCase()];

  /// Get a parameter group by ID
  static T2IParamGroup? getGroup(String id) => _groups[id];

  /// Get all parameters in a group
  static List<T2IParamType> getParamsInGroup(String groupId) {
    return _types.values.where((t) => t.group?.id == groupId).toList();
  }

  /// Get parameters as API response
  static List<Map<String, dynamic>> toApiList() {
    return _types.values.map((t) => t.toJson()).toList();
  }

  /// Get groups as API response
  static List<Map<String, dynamic>> groupsToApiList() {
    return _groups.values.map((g) => g.toJson()).toList();
  }
}

/// Parameter data type
enum ParamDataType {
  text,
  integer,
  decimal,
  boolean,
  dropdown,
  image,
  model,
  list,
  imageList,
  audio,
  video,
}

/// Parameter view type (how it's displayed)
enum ParamViewType {
  normal,
  prompt,
  small,
  big,
  slider,
  potSlider,
  seed,
}

/// Parameter type definition
class T2IParamType {
  final String id;
  final String name;
  final String description;
  final ParamDataType type;
  final String? subtype;
  final dynamic defaultValue;
  final num? min;
  final num? max;
  final num? viewMax;
  final num? step;
  final List<String>? values;
  final T2IParamGroup? group;
  final ParamViewType viewType;
  final bool toggleable;
  final String? featureFlag;
  final bool visible;
  final int orderPriority;

  const T2IParamType({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.subtype,
    this.defaultValue,
    this.min,
    this.max,
    this.viewMax,
    this.step,
    this.values,
    this.group,
    this.viewType = ParamViewType.normal,
    this.toggleable = false,
    this.featureFlag,
    this.visible = true,
    this.orderPriority = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type.name,
        'subtype': subtype,
        'default': defaultValue,
        'min': min,
        'max': max,
        'view_max': viewMax,
        'step': step,
        'values': values,
        'group': group?.id,
        'view_type': viewType.name,
        'toggleable': toggleable,
        'feature_flag': featureFlag,
        'visible': visible,
        'order': orderPriority,
      };
}

/// Parameter group
class T2IParamGroup {
  final String id;
  final String name;
  final String description;
  final bool open;
  final bool toggles;
  final int orderPriority;

  const T2IParamGroup({
    required this.id,
    required this.name,
    this.description = '',
    this.open = false,
    this.toggles = false,
    this.orderPriority = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'open': open,
        'toggles': toggles,
        'order': orderPriority,
      };
}
