import 'dart:convert';
import 'dart:math';

/// EriWorkflow - Main workflow class that mirrors SwarmUI's ComfyCustomWorkflow structure
///
/// Represents a complete ComfyUI workflow with custom parameters, templating support,
/// and metadata for organization and display.
class EriWorkflow {
  /// Unique identifier for the workflow
  final String id;

  /// Display name for the workflow
  final String name;

  /// Optional folder path for hierarchical organization
  final String? folder;

  /// ComfyUI visual workflow JSON (the full workflow graph)
  final String workflow;

  /// ComfyUI execution prompt JSON (the simplified execution format)
  final String prompt;

  /// Parameter definitions JSON (custom params schema)
  final String customParams;

  /// Default parameter values JSON
  final String paramValues;

  /// Preview thumbnail (base64 encoded image or path)
  final String? image;

  /// Optional description of the workflow
  final String? description;

  /// Whether to show this workflow in the simple/quick generate tab
  final bool enableInSimple;

  /// When the workflow was created
  final DateTime createdAt;

  /// When the workflow was last modified
  final DateTime updatedAt;

  /// Optional tags for search and filtering
  final List<String>? tags;

  /// Optional author name
  final String? author;

  /// Optional version string
  final String? version;

  const EriWorkflow({
    required this.id,
    required this.name,
    this.folder,
    required this.workflow,
    required this.prompt,
    this.customParams = '{}',
    this.paramValues = '{}',
    this.image,
    this.description,
    this.enableInSimple = false,
    required this.createdAt,
    required this.updatedAt,
    this.tags,
    this.author,
    this.version,
  });

  /// Parse custom params JSON into a list of EriWorkflowParam objects
  List<EriWorkflowParam> get parameters {
    try {
      final paramsMap = jsonDecode(customParams) as Map<String, dynamic>;
      return paramsMap.entries.map((entry) {
        final paramData = entry.value as Map<String, dynamic>;
        return EriWorkflowParam.fromJson(entry.key, paramData);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get the default parameter values as a map
  Map<String, dynamic> get defaultValues {
    try {
      return jsonDecode(paramValues) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  /// Fill the workflow template with the provided parameter values
  ///
  /// Supports the following template tags:
  /// - ${prompt} - Main prompt text
  /// - ${negative_prompt} - Negative prompt text
  /// - ${seed} - Seed value (-1 for random)
  /// - ${seed+N} - Seed with offset N
  /// - ${steps} - Number of steps
  /// - ${width} - Image width
  /// - ${height} - Image height
  /// - ${cfg_scale} - CFG scale value
  /// - ${model} - Model name
  /// - ${sampler} - Sampler name
  /// - ${scheduler} - Scheduler name
  /// - ${batch_size} - Batch size
  /// - ${param_name} - Custom parameter value
  /// - ${param_name:default} - Custom parameter with default value
  String fillTemplate(Map<String, dynamic> params) {
    String result = prompt;

    // Generate random seed if not provided or -1
    int seedValue = params['seed'] as int? ?? -1;
    if (seedValue == -1) {
      seedValue = Random().nextInt(1 << 31);
    }

    // Standard template tags
    result = result.replaceAll(r'${prompt}', _escapeJsonString(params['prompt']?.toString() ?? ''));
    result = result.replaceAll(r'${negative_prompt}', _escapeJsonString(params['negativePrompt']?.toString() ?? params['negative_prompt']?.toString() ?? ''));
    result = result.replaceAll(r'${seed}', seedValue.toString());
    result = result.replaceAll(r'${steps}', (params['steps'] ?? 20).toString());
    result = result.replaceAll(r'${width}', (params['width'] ?? 1024).toString());
    result = result.replaceAll(r'${height}', (params['height'] ?? 1024).toString());
    result = result.replaceAll(r'${cfg_scale}', (params['cfgScale'] ?? params['cfg_scale'] ?? 7.0).toString());
    result = result.replaceAll(r'${cfg}', (params['cfgScale'] ?? params['cfg_scale'] ?? params['cfg'] ?? 7.0).toString());
    result = result.replaceAll(r'${model}', _escapeJsonString(params['model']?.toString() ?? ''));
    result = result.replaceAll(r'${sampler}', _escapeJsonString(params['sampler']?.toString() ?? 'euler'));
    result = result.replaceAll(r'${scheduler}', _escapeJsonString(params['scheduler']?.toString() ?? 'normal'));
    result = result.replaceAll(r'${batch_size}', (params['batchSize'] ?? params['batch_size'] ?? 1).toString());
    result = result.replaceAll(r'${vae}', _escapeJsonString(params['vae']?.toString() ?? ''));
    result = result.replaceAll(r'${clip}', _escapeJsonString(params['clip']?.toString() ?? ''));

    // Video-specific tags
    result = result.replaceAll(r'${frames}', (params['frames'] ?? 81).toString());
    result = result.replaceAll(r'${fps}', (params['fps'] ?? 24).toString());
    result = result.replaceAll(r'${video_format}', _escapeJsonString(params['videoFormat']?.toString() ?? params['video_format']?.toString() ?? 'mp4'));

    // Seed offset support: ${seed+42}
    final seedOffsetRegex = RegExp(r'\$\{seed\+(\d+)\}');
    result = result.replaceAllMapped(seedOffsetRegex, (match) {
      final offset = int.parse(match.group(1)!);
      return (seedValue + offset).toString();
    });

    // Custom param tags with optional default: ${param_name} or ${param_name:default_value}
    final customTagRegex = RegExp(r'\$\{(\w+)(?::([^}]*))?\}');
    result = result.replaceAllMapped(customTagRegex, (match) {
      final paramName = match.group(1)!;
      final defaultValue = match.group(2) ?? '';

      // Skip if it's a standard tag that wasn't replaced (shouldn't happen)
      if (_isStandardTag(paramName)) {
        return match.group(0)!;
      }

      final value = params[paramName] ?? defaultValue;
      // Check if value needs JSON string escaping
      if (value is String) {
        return _escapeJsonString(value);
      }
      return value.toString();
    });

    return result;
  }

  /// Check if a tag name is a standard template tag
  bool _isStandardTag(String tag) {
    const standardTags = {
      'prompt', 'negative_prompt', 'seed', 'steps', 'width', 'height',
      'cfg_scale', 'cfg', 'model', 'sampler', 'scheduler', 'batch_size',
      'vae', 'clip', 'frames', 'fps', 'video_format',
    };
    return standardTags.contains(tag);
  }

  /// Escape a string for use in JSON
  String _escapeJsonString(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
  }

  /// Create a copy with updated fields
  EriWorkflow copyWith({
    String? id,
    String? name,
    String? folder,
    String? workflow,
    String? prompt,
    String? customParams,
    String? paramValues,
    String? image,
    String? description,
    bool? enableInSimple,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    String? author,
    String? version,
  }) {
    return EriWorkflow(
      id: id ?? this.id,
      name: name ?? this.name,
      folder: folder ?? this.folder,
      workflow: workflow ?? this.workflow,
      prompt: prompt ?? this.prompt,
      customParams: customParams ?? this.customParams,
      paramValues: paramValues ?? this.paramValues,
      image: image ?? this.image,
      description: description ?? this.description,
      enableInSimple: enableInSimple ?? this.enableInSimple,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      author: author ?? this.author,
      version: version ?? this.version,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'folder': folder,
      'workflow': workflow,
      'prompt': prompt,
      'customParams': customParams,
      'paramValues': paramValues,
      'image': image,
      'description': description,
      'enableInSimple': enableInSimple,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tags': tags,
      'author': author,
      'version': version,
    };
  }

  /// Create from JSON map
  factory EriWorkflow.fromJson(Map<String, dynamic> json) {
    return EriWorkflow(
      id: json['id'] as String,
      name: json['name'] as String,
      folder: json['folder'] as String?,
      workflow: json['workflow'] as String? ?? '{}',
      prompt: json['prompt'] as String? ?? '{}',
      customParams: json['customParams'] as String? ?? '{}',
      paramValues: json['paramValues'] as String? ?? '{}',
      image: json['image'] as String?,
      description: json['description'] as String?,
      enableInSimple: json['enableInSimple'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : null,
      author: json['author'] as String?,
      version: json['version'] as String?,
    );
  }

  /// Encode to JSON string
  String encode() => jsonEncode(toJson());

  /// Decode from JSON string
  static EriWorkflow decode(String source) =>
      EriWorkflow.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// Get the full path including folder
  String get fullPath => folder != null ? '$folder/$name' : name;

  @override
  String toString() => 'EriWorkflow(id: $id, name: $name, folder: $folder)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EriWorkflow && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// EriWorkflowParam - Parameter definition for workflow customization
///
/// Defines a single customizable parameter with its type, constraints,
/// and UI hints.
class EriWorkflowParam {
  /// Parameter identifier (used in template tags)
  final String id;

  /// Display name for the parameter
  final String name;

  /// Parameter type: text, dropdown, integer, decimal, boolean, image, model
  final String type;

  /// Optional description/tooltip
  final String? description;

  /// Default value for the parameter
  final dynamic defaultValue;

  /// Allowed values (for dropdown type)
  final List<String>? values;

  /// Minimum value (for numeric types)
  final num? min;

  /// Maximum value (for numeric types)
  final num? max;

  /// Step increment (for numeric types)
  final num? step;

  /// Whether the parameter can be toggled on/off
  final bool toggleable;

  /// Whether the parameter is visible in the UI
  final bool visible;

  /// Whether this is an advanced parameter (hidden by default)
  final bool advanced;

  /// Feature flag requirement (e.g., "comfyui" requires ComfyUI backend)
  final String? featureFlag;

  /// Group name for organizing parameters in the UI
  final String? group;

  /// Priority for ordering within a group (lower = higher priority)
  final int priority;

  const EriWorkflowParam({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.defaultValue,
    this.values,
    this.min,
    this.max,
    this.step,
    this.toggleable = false,
    this.visible = true,
    this.advanced = false,
    this.featureFlag,
    this.group,
    this.priority = 0,
  });

  /// Create from JSON with ID provided separately
  factory EriWorkflowParam.fromJson(String id, Map<String, dynamic> json) {
    return EriWorkflowParam(
      id: id,
      name: json['name'] as String? ?? id,
      type: json['type'] as String? ?? 'text',
      description: json['description'] as String?,
      defaultValue: json['default'] ?? json['defaultValue'],
      values: json['values'] != null
          ? List<String>.from(json['values'] as List)
          : null,
      min: json['min'] as num?,
      max: json['max'] as num?,
      step: json['step'] as num?,
      toggleable: json['toggleable'] as bool? ?? false,
      visible: json['visible'] as bool? ?? true,
      advanced: json['advanced'] as bool? ?? false,
      featureFlag: json['featureFlag'] as String?,
      group: json['group'] as String?,
      priority: json['priority'] as int? ?? 0,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'description': description,
      'default': defaultValue,
      'values': values,
      'min': min,
      'max': max,
      'step': step,
      'toggleable': toggleable,
      'visible': visible,
      'advanced': advanced,
      'featureFlag': featureFlag,
      'group': group,
      'priority': priority,
    };
  }

  /// Validate a value against this parameter's constraints
  bool validate(dynamic value) {
    if (value == null) {
      return !toggleable; // Null is OK if toggleable
    }

    switch (type) {
      case 'integer':
        if (value is! int) return false;
        if (min != null && value < min!) return false;
        if (max != null && value > max!) return false;
        return true;

      case 'decimal':
        if (value is! num) return false;
        if (min != null && value < min!) return false;
        if (max != null && value > max!) return false;
        return true;

      case 'dropdown':
        if (values == null) return true;
        return values!.contains(value.toString());

      case 'boolean':
        return value is bool;

      case 'text':
      case 'image':
      case 'model':
      default:
        return true;
    }
  }

  /// Coerce a value to the correct type
  dynamic coerceValue(dynamic value) {
    if (value == null) return defaultValue;

    switch (type) {
      case 'integer':
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) return int.tryParse(value) ?? defaultValue;
        return defaultValue;

      case 'decimal':
        if (value is double) return value;
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value) ?? defaultValue;
        return defaultValue;

      case 'boolean':
        if (value is bool) return value;
        if (value is String) return value.toLowerCase() == 'true';
        return defaultValue;

      default:
        return value;
    }
  }

  @override
  String toString() => 'EriWorkflowParam(id: $id, name: $name, type: $type)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EriWorkflowParam && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// WorkflowExecutionResult - Result of workflow execution
///
/// Contains the output images, metadata, and execution timing information.
class WorkflowExecutionResult {
  /// The ComfyUI prompt ID for this execution
  final String promptId;

  /// List of output image URLs or paths
  final List<String> outputImages;

  /// Additional metadata from the execution
  final Map<String, dynamic> metadata;

  /// How long the execution took
  final Duration executionTime;

  /// Whether the execution was successful
  final bool success;

  /// Error message if execution failed
  final String? error;

  /// The seed value used (useful if random was requested)
  final int? usedSeed;

  /// Node execution details (for debugging)
  final Map<String, dynamic>? nodeOutputs;

  const WorkflowExecutionResult({
    required this.promptId,
    this.outputImages = const [],
    this.metadata = const {},
    this.executionTime = Duration.zero,
    this.success = true,
    this.error,
    this.usedSeed,
    this.nodeOutputs,
  });

  /// Create a successful result
  factory WorkflowExecutionResult.success({
    required String promptId,
    required List<String> outputImages,
    Map<String, dynamic>? metadata,
    Duration? executionTime,
    int? usedSeed,
    Map<String, dynamic>? nodeOutputs,
  }) {
    return WorkflowExecutionResult(
      promptId: promptId,
      outputImages: outputImages,
      metadata: metadata ?? {},
      executionTime: executionTime ?? Duration.zero,
      success: true,
      usedSeed: usedSeed,
      nodeOutputs: nodeOutputs,
    );
  }

  /// Create a failed result
  factory WorkflowExecutionResult.failure({
    required String promptId,
    required String error,
    Duration? executionTime,
    Map<String, dynamic>? nodeOutputs,
  }) {
    return WorkflowExecutionResult(
      promptId: promptId,
      success: false,
      error: error,
      executionTime: executionTime ?? Duration.zero,
      nodeOutputs: nodeOutputs,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'promptId': promptId,
      'outputImages': outputImages,
      'metadata': metadata,
      'executionTime': executionTime.inMilliseconds,
      'success': success,
      'error': error,
      'usedSeed': usedSeed,
      'nodeOutputs': nodeOutputs,
    };
  }

  /// Create from JSON map
  factory WorkflowExecutionResult.fromJson(Map<String, dynamic> json) {
    return WorkflowExecutionResult(
      promptId: json['promptId'] as String,
      outputImages: json['outputImages'] != null
          ? List<String>.from(json['outputImages'] as List)
          : [],
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : {},
      executionTime: Duration(milliseconds: json['executionTime'] as int? ?? 0),
      success: json['success'] as bool? ?? true,
      error: json['error'] as String?,
      usedSeed: json['usedSeed'] as int?,
      nodeOutputs: json['nodeOutputs'] != null
          ? Map<String, dynamic>.from(json['nodeOutputs'] as Map)
          : null,
    );
  }

  @override
  String toString() => 'WorkflowExecutionResult(promptId: $promptId, success: $success, images: ${outputImages.length})';
}

/// WorkflowFolder - Represents a folder for organizing workflows
class WorkflowFolder {
  /// Folder name
  final String name;

  /// Parent folder path (null for root-level folders)
  final String? parentFolder;

  /// Number of workflows in this folder (not including subfolders)
  final int workflowCount;

  const WorkflowFolder({
    required this.name,
    this.parentFolder,
    this.workflowCount = 0,
  });

  /// Get the full path of the folder
  String get path => parentFolder != null ? '$parentFolder/$name' : name;

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'parentFolder': parentFolder,
      'workflowCount': workflowCount,
    };
  }

  /// Create from JSON map
  factory WorkflowFolder.fromJson(Map<String, dynamic> json) {
    return WorkflowFolder(
      name: json['name'] as String,
      parentFolder: json['parentFolder'] as String?,
      workflowCount: json['workflowCount'] as int? ?? 0,
    );
  }

  @override
  String toString() => 'WorkflowFolder(name: $name, path: $path)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkflowFolder && other.path == path;
  }

  @override
  int get hashCode => path.hashCode;
}

/// WorkflowValidationResult - Result of workflow validation
class WorkflowValidationResult {
  /// Whether the workflow is valid
  final bool isValid;

  /// List of validation errors
  final List<String> errors;

  /// List of validation warnings
  final List<String> warnings;

  /// Missing node types that the workflow requires
  final List<String> missingNodes;

  /// Missing models that the workflow requires
  final List<String> missingModels;

  const WorkflowValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.missingNodes = const [],
    this.missingModels = const [],
  });

  /// Create a successful validation result
  factory WorkflowValidationResult.valid({
    List<String>? warnings,
  }) {
    return WorkflowValidationResult(
      isValid: true,
      warnings: warnings ?? [],
    );
  }

  /// Create a failed validation result
  factory WorkflowValidationResult.invalid({
    required List<String> errors,
    List<String>? warnings,
    List<String>? missingNodes,
    List<String>? missingModels,
  }) {
    return WorkflowValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings ?? [],
      missingNodes: missingNodes ?? [],
      missingModels: missingModels ?? [],
    );
  }

  @override
  String toString() => 'WorkflowValidationResult(isValid: $isValid, errors: ${errors.length}, warnings: ${warnings.length})';
}
