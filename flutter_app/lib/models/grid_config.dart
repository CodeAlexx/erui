// Grid generator configuration models
//
// Defines the data structures for configuring parameter grids
// for batch image generation with varying parameters.

/// Represents a single axis in the grid
///
/// An axis defines which parameter varies and what values it takes.
/// For example: CFG Scale with values [1, 3, 5, 7] or Steps with [10, 20, 30]
class GridAxis {
  /// The parameter name (matches GenerationParams field names)
  /// e.g., 'cfgScale', 'steps', 'sampler', 'model', 'prompt', 'seed'
  final String parameterName;

  /// The display name for the UI
  final String displayName;

  /// The values this axis will iterate through
  /// Stored as strings for flexibility (can be numbers, sampler names, etc.)
  final List<String> values;

  const GridAxis({
    required this.parameterName,
    required this.displayName,
    required this.values,
  });

  /// Create a copy with modified values
  GridAxis copyWith({
    String? parameterName,
    String? displayName,
    List<String>? values,
  }) {
    return GridAxis(
      parameterName: parameterName ?? this.parameterName,
      displayName: displayName ?? this.displayName,
      values: values ?? this.values,
    );
  }

  /// Number of values in this axis
  int get length => values.length;

  /// Check if axis is valid (has parameter and at least one value)
  bool get isValid => parameterName.isNotEmpty && values.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'parameterName': parameterName,
    'displayName': displayName,
    'values': values,
  };

  factory GridAxis.fromJson(Map<String, dynamic> json) {
    return GridAxis(
      parameterName: json['parameterName'] as String,
      displayName: json['displayName'] as String? ?? json['parameterName'] as String,
      values: (json['values'] as List).cast<String>(),
    );
  }
}

/// Represents available grid parameters with their metadata
class GridParameter {
  final String name;
  final String displayName;
  final GridParameterType type;
  final dynamic defaultValue;
  final double? min;
  final double? max;
  final List<String>? options;

  const GridParameter({
    required this.name,
    required this.displayName,
    required this.type,
    this.defaultValue,
    this.min,
    this.max,
    this.options,
  });

  /// All available grid parameters
  static const List<GridParameter> available = [
    GridParameter(
      name: 'cfgScale',
      displayName: 'CFG Scale',
      type: GridParameterType.number,
      defaultValue: 7.0,
      min: 1.0,
      max: 30.0,
    ),
    GridParameter(
      name: 'steps',
      displayName: 'Steps',
      type: GridParameterType.integer,
      defaultValue: 20,
      min: 1,
      max: 150,
    ),
    GridParameter(
      name: 'sampler',
      displayName: 'Sampler',
      type: GridParameterType.selection,
      defaultValue: 'euler',
      options: [
        'euler',
        'euler_ancestral',
        'heun',
        'heunpp2',
        'dpm_2',
        'dpm_2_ancestral',
        'lms',
        'dpm_fast',
        'dpm_adaptive',
        'dpmpp_2s_ancestral',
        'dpmpp_sde',
        'dpmpp_sde_gpu',
        'dpmpp_2m',
        'dpmpp_2m_sde',
        'dpmpp_2m_sde_gpu',
        'dpmpp_3m_sde',
        'dpmpp_3m_sde_gpu',
        'ddpm',
        'lcm',
        'uni_pc',
        'uni_pc_bh2',
      ],
    ),
    GridParameter(
      name: 'scheduler',
      displayName: 'Scheduler',
      type: GridParameterType.selection,
      defaultValue: 'normal',
      options: [
        'normal',
        'karras',
        'exponential',
        'sgm_uniform',
        'simple',
        'ddim_uniform',
        'beta',
      ],
    ),
    GridParameter(
      name: 'model',
      displayName: 'Model',
      type: GridParameterType.model,
      defaultValue: null,
    ),
    GridParameter(
      name: 'seed',
      displayName: 'Seed',
      type: GridParameterType.integer,
      defaultValue: -1,
      min: -1,
      max: 2147483647,
    ),
    GridParameter(
      name: 'prompt',
      displayName: 'Prompt Variations',
      type: GridParameterType.text,
      defaultValue: '',
    ),
    GridParameter(
      name: 'width',
      displayName: 'Width',
      type: GridParameterType.integer,
      defaultValue: 1024,
      min: 64,
      max: 2048,
    ),
    GridParameter(
      name: 'height',
      displayName: 'Height',
      type: GridParameterType.integer,
      defaultValue: 1024,
      min: 64,
      max: 2048,
    ),
  ];

  /// Get parameter by name
  static GridParameter? getByName(String name) {
    try {
      return available.firstWhere((p) => p.name == name);
    } catch (_) {
      return null;
    }
  }
}

/// Types of grid parameters
enum GridParameterType {
  number,    // Floating point numbers (CFG scale)
  integer,   // Whole numbers (steps, seed)
  selection, // Dropdown selection (sampler, scheduler)
  model,     // Model selection
  text,      // Text input (prompt variations)
}

/// Complete grid configuration
///
/// Supports up to 3 axes (X, Y, Z) for comprehensive parameter exploration.
/// Total images generated = X.length * Y.length * Z.length
class GridConfig {
  /// Optional name for this grid configuration
  final String? name;

  /// X axis (required for any grid)
  final GridAxis? xAxis;

  /// Y axis (optional, creates 2D grid)
  final GridAxis? yAxis;

  /// Z axis (optional, creates 3D grid - multiple 2D grids)
  final GridAxis? zAxis;

  /// Base parameters that apply to all generations
  /// These are the starting values that get overridden by axis values
  final Map<String, dynamic> baseParams;

  /// Output as individual images or combined grid image
  final bool combineAsGrid;

  /// Add labels to grid output
  final bool showLabels;

  const GridConfig({
    this.name,
    this.xAxis,
    this.yAxis,
    this.zAxis,
    this.baseParams = const {},
    this.combineAsGrid = true,
    this.showLabels = true,
  });

  /// Create a copy with modified values
  GridConfig copyWith({
    String? name,
    GridAxis? xAxis,
    GridAxis? yAxis,
    GridAxis? zAxis,
    Map<String, dynamic>? baseParams,
    bool? combineAsGrid,
    bool? showLabels,
  }) {
    return GridConfig(
      name: name ?? this.name,
      xAxis: xAxis ?? this.xAxis,
      yAxis: yAxis ?? this.yAxis,
      zAxis: zAxis ?? this.zAxis,
      baseParams: baseParams ?? this.baseParams,
      combineAsGrid: combineAsGrid ?? this.combineAsGrid,
      showLabels: showLabels ?? this.showLabels,
    );
  }

  /// Clear a specific axis
  GridConfig clearAxis(int axisIndex) {
    switch (axisIndex) {
      case 0:
        return copyWith(xAxis: null);
      case 1:
        return copyWith(yAxis: null);
      case 2:
        return copyWith(zAxis: null);
      default:
        return this;
    }
  }

  /// Get all active axes
  List<GridAxis> get activeAxes {
    return [
      if (xAxis != null && xAxis!.isValid) xAxis!,
      if (yAxis != null && yAxis!.isValid) yAxis!,
      if (zAxis != null && zAxis!.isValid) zAxis!,
    ];
  }

  /// Total number of images to generate
  int get totalImages {
    if (activeAxes.isEmpty) return 0;
    return activeAxes.fold(1, (product, axis) => product * axis.length);
  }

  /// Grid dimensions as a string (e.g., "4x3" or "4x3x2")
  String get dimensionString {
    if (activeAxes.isEmpty) return '0';
    return activeAxes.map((a) => a.length.toString()).join('x');
  }

  /// Check if configuration is valid for generation
  bool get isValid => activeAxes.isNotEmpty && totalImages > 0;

  /// Estimate generation time (rough estimate based on steps and batch)
  Duration estimateTime({int secondsPerImage = 10}) {
    return Duration(seconds: totalImages * secondsPerImage);
  }

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (xAxis != null) 'xAxis': xAxis!.toJson(),
    if (yAxis != null) 'yAxis': yAxis!.toJson(),
    if (zAxis != null) 'zAxis': zAxis!.toJson(),
    'baseParams': baseParams,
    'combineAsGrid': combineAsGrid,
    'showLabels': showLabels,
  };

  factory GridConfig.fromJson(Map<String, dynamic> json) {
    return GridConfig(
      name: json['name'] as String?,
      xAxis: json['xAxis'] != null
          ? GridAxis.fromJson(json['xAxis'] as Map<String, dynamic>)
          : null,
      yAxis: json['yAxis'] != null
          ? GridAxis.fromJson(json['yAxis'] as Map<String, dynamic>)
          : null,
      zAxis: json['zAxis'] != null
          ? GridAxis.fromJson(json['zAxis'] as Map<String, dynamic>)
          : null,
      baseParams: json['baseParams'] as Map<String, dynamic>? ?? {},
      combineAsGrid: json['combineAsGrid'] as bool? ?? true,
      showLabels: json['showLabels'] as bool? ?? true,
    );
  }
}

/// A single generation in the grid queue
class GridGenerationItem {
  /// Unique identifier
  final String id;

  /// Index in the grid (x, y, z coordinates)
  final int xIndex;
  final int yIndex;
  final int zIndex;

  /// The parameters for this specific generation
  final Map<String, dynamic> params;

  /// Status of this generation
  final GridItemStatus status;

  /// Result image URL (if completed)
  final String? imageUrl;

  /// Error message (if failed)
  final String? error;

  const GridGenerationItem({
    required this.id,
    required this.xIndex,
    this.yIndex = 0,
    this.zIndex = 0,
    required this.params,
    this.status = GridItemStatus.pending,
    this.imageUrl,
    this.error,
  });

  GridGenerationItem copyWith({
    String? id,
    int? xIndex,
    int? yIndex,
    int? zIndex,
    Map<String, dynamic>? params,
    GridItemStatus? status,
    String? imageUrl,
    String? error,
  }) {
    return GridGenerationItem(
      id: id ?? this.id,
      xIndex: xIndex ?? this.xIndex,
      yIndex: yIndex ?? this.yIndex,
      zIndex: zIndex ?? this.zIndex,
      params: params ?? this.params,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      error: error ?? this.error,
    );
  }

  /// Get axis labels for this item
  String getLabel(GridConfig config) {
    final labels = <String>[];
    if (config.xAxis != null && xIndex < config.xAxis!.values.length) {
      labels.add('${config.xAxis!.displayName}: ${config.xAxis!.values[xIndex]}');
    }
    if (config.yAxis != null && yIndex < config.yAxis!.values.length) {
      labels.add('${config.yAxis!.displayName}: ${config.yAxis!.values[yIndex]}');
    }
    if (config.zAxis != null && zIndex < config.zAxis!.values.length) {
      labels.add('${config.zAxis!.displayName}: ${config.zAxis!.values[zIndex]}');
    }
    return labels.join(', ');
  }
}

/// Status of a grid generation item
enum GridItemStatus {
  pending,
  generating,
  completed,
  failed,
  cancelled,
}

/// Grid generation progress state
class GridGenerationState {
  final GridConfig? config;
  final List<GridGenerationItem> items;
  final int currentIndex;
  final bool isGenerating;
  final bool isPaused;
  final bool isCancelled;
  final String? error;
  final DateTime? startTime;
  final DateTime? endTime;

  const GridGenerationState({
    this.config,
    this.items = const [],
    this.currentIndex = 0,
    this.isGenerating = false,
    this.isPaused = false,
    this.isCancelled = false,
    this.error,
    this.startTime,
    this.endTime,
  });

  GridGenerationState copyWith({
    GridConfig? config,
    List<GridGenerationItem>? items,
    int? currentIndex,
    bool? isGenerating,
    bool? isPaused,
    bool? isCancelled,
    String? error,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return GridGenerationState(
      config: config ?? this.config,
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      isGenerating: isGenerating ?? this.isGenerating,
      isPaused: isPaused ?? this.isPaused,
      isCancelled: isCancelled ?? this.isCancelled,
      error: error,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  /// Total items in the grid
  int get totalItems => items.length;

  /// Number of completed items
  int get completedCount => items.where((i) => i.status == GridItemStatus.completed).length;

  /// Number of failed items
  int get failedCount => items.where((i) => i.status == GridItemStatus.failed).length;

  /// Progress as a value between 0.0 and 1.0
  double get progress => totalItems > 0 ? completedCount / totalItems : 0.0;

  /// Get all completed image URLs
  List<String> get completedImages => items
      .where((i) => i.status == GridItemStatus.completed && i.imageUrl != null)
      .map((i) => i.imageUrl!)
      .toList();

  /// Elapsed time since start
  Duration? get elapsed {
    if (startTime == null) return null;
    final end = endTime ?? DateTime.now();
    return end.difference(startTime!);
  }

  /// Estimated time remaining based on current progress
  Duration? get estimatedRemaining {
    if (elapsed == null || completedCount == 0) return null;
    final remaining = totalItems - completedCount;
    final avgPerItem = elapsed!.inMilliseconds / completedCount;
    return Duration(milliseconds: (remaining * avgPerItem).round());
  }
}
