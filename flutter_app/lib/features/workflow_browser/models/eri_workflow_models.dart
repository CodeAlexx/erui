import 'dart:convert';

/// EriWorkflow - mirrors SwarmUI's ComfyCustomWorkflow structure
/// Used for custom workflow management with parameter templating
class EriWorkflow {
  final String id;
  final String name;
  final String? folder;
  final String workflow;      // ComfyUI visual workflow JSON
  final String prompt;        // ComfyUI execution prompt JSON
  final String customParams;  // Parameter definitions JSON
  final String paramValues;   // Default parameter values JSON
  final String? image;        // Preview thumbnail (base64 or path)
  final String? description;
  final bool enableInSimple;  // Show in quick generate tab
  final DateTime createdAt;
  final DateTime updatedAt;

  const EriWorkflow({
    required this.id,
    required this.name,
    this.folder,
    required this.workflow,
    required this.prompt,
    this.customParams = '[]',
    this.paramValues = '{}',
    this.image,
    this.description,
    this.enableInSimple = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Parse custom params into EriWorkflowParam list
  List<EriWorkflowParam> get parameters {
    try {
      final List<dynamic> paramsJson = jsonDecode(customParams);
      return paramsJson.map((p) => EriWorkflowParam.fromJson(p as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get default parameter values as map
  Map<String, dynamic> get defaultValues {
    try {
      return jsonDecode(paramValues) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  /// Fill template with parameter values
  /// Supports: ${prompt}, ${negative_prompt}, ${seed}, ${steps}, ${width}, ${height}, ${cfg_scale}, ${model}
  /// Also supports custom params: ${param_name:default_value} and seed offsets: ${seed+42}
  String fillTemplate(Map<String, dynamic> params) {
    var result = prompt;

    // Standard tags
    result = result.replaceAll(r'${prompt}', params['prompt']?.toString() ?? '');
    result = result.replaceAll(r'${negative_prompt}', params['negativePrompt']?.toString() ?? params['negative_prompt']?.toString() ?? '');
    result = result.replaceAll(r'${seed}', (params['seed'] ?? -1).toString());
    result = result.replaceAll(r'${steps}', (params['steps'] ?? 20).toString());
    result = result.replaceAll(r'${width}', (params['width'] ?? 1024).toString());
    result = result.replaceAll(r'${height}', (params['height'] ?? 1024).toString());
    result = result.replaceAll(r'${cfg_scale}', (params['cfgScale'] ?? params['cfg_scale'] ?? 7.0).toString());
    result = result.replaceAll(r'${model}', params['model']?.toString() ?? '');

    // Custom param tags: ${param_name:default_value}
    final customTagRegex = RegExp(r'\$\{(\w+)(?::([^}]*))?\}');
    result = result.replaceAllMapped(customTagRegex, (match) {
      final paramName = match.group(1)!;
      final defaultValue = match.group(2) ?? '';
      return (params[paramName] ?? defaultValue).toString();
    });

    // Seed offset support: ${seed+42}
    final seedOffsetRegex = RegExp(r'\$\{seed\+(\d+)\}');
    result = result.replaceAllMapped(seedOffsetRegex, (match) {
      final offset = int.parse(match.group(1)!);
      final baseSeed = params['seed'] as int? ?? DateTime.now().millisecondsSinceEpoch;
      return (baseSeed + offset).toString();
    });

    return result;
  }

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
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'folder': folder,
    'workflow': workflow,
    'prompt': prompt,
    'custom_params': customParams,
    'param_values': paramValues,
    'image': image,
    'description': description,
    'enable_in_simple': enableInSimple,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory EriWorkflow.fromJson(Map<String, dynamic> json) {
    return EriWorkflow(
      id: json['id'] as String,
      name: json['name'] as String,
      folder: json['folder'] as String?,
      workflow: json['workflow'] as String? ?? '{}',
      prompt: json['prompt'] as String? ?? '{}',
      customParams: json['custom_params'] as String? ?? '[]',
      paramValues: json['param_values'] as String? ?? '{}',
      image: json['image'] as String?,
      description: json['description'] as String?,
      enableInSimple: json['enable_in_simple'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }
}

/// Parameter definition for workflow customization
class EriWorkflowParam {
  final String id;
  final String name;
  final String type;         // text, dropdown, integer, decimal, boolean, image, model
  final String? description;
  final dynamic defaultValue;
  final List<String>? values; // For dropdowns
  final num? min;
  final num? max;
  final num? step;
  final bool toggleable;
  final bool visible;
  final bool advanced;
  final String? featureFlag;
  final String? group;

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
  });

  EriWorkflowParam copyWith({
    String? id,
    String? name,
    String? type,
    String? description,
    dynamic defaultValue,
    List<String>? values,
    num? min,
    num? max,
    num? step,
    bool? toggleable,
    bool? visible,
    bool? advanced,
    String? featureFlag,
    String? group,
  }) {
    return EriWorkflowParam(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      defaultValue: defaultValue ?? this.defaultValue,
      values: values ?? this.values,
      min: min ?? this.min,
      max: max ?? this.max,
      step: step ?? this.step,
      toggleable: toggleable ?? this.toggleable,
      visible: visible ?? this.visible,
      advanced: advanced ?? this.advanced,
      featureFlag: featureFlag ?? this.featureFlag,
      group: group ?? this.group,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'description': description,
    'default_value': defaultValue,
    'values': values,
    'min': min,
    'max': max,
    'step': step,
    'toggleable': toggleable,
    'visible': visible,
    'advanced': advanced,
    'feature_flag': featureFlag,
    'group': group,
  };

  factory EriWorkflowParam.fromJson(Map<String, dynamic> json) {
    return EriWorkflowParam(
      id: json['id'] as String? ?? json['name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      description: json['description'] as String?,
      defaultValue: json['default_value'] ?? json['defaultValue'],
      values: (json['values'] as List<dynamic>?)?.cast<String>(),
      min: json['min'] as num?,
      max: json['max'] as num?,
      step: json['step'] as num?,
      toggleable: json['toggleable'] as bool? ?? false,
      visible: json['visible'] as bool? ?? true,
      advanced: json['advanced'] as bool? ?? false,
      featureFlag: json['feature_flag'] as String? ?? json['featureFlag'] as String?,
      group: json['group'] as String?,
    );
  }
}

/// Workflow execution result
class WorkflowExecutionResult {
  final String promptId;
  final List<String> outputImages;
  final Map<String, dynamic> metadata;
  final Duration executionTime;

  const WorkflowExecutionResult({
    required this.promptId,
    required this.outputImages,
    required this.metadata,
    required this.executionTime,
  });
}
