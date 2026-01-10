import 'dart:convert';
import 'dart:math';

import '../models/workflow_models.dart';
import 'comfyui_service.dart';

/// Extended ComfyUI service for workflow operations
///
/// Provides workflow-specific functionality including:
/// - Template tag filling (${prompt}, ${seed}, ${model}, etc.)
/// - Workflow execution with parameter substitution
/// - Node type and object info fetching
extension ComfyUIWorkflowAPI on ComfyUIService {
  /// Queue a workflow for execution with parameter substitution
  ///
  /// Takes an [EriWorkflow] and a map of [params] to fill in template tags.
  /// Returns the prompt_id on success, null on failure.
  ///
  /// Standard template tags:
  /// - ${prompt} - Main positive prompt
  /// - ${negative_prompt} - Negative prompt
  /// - ${seed} - Generation seed (-1 for random)
  /// - ${steps} - Number of steps
  /// - ${width} - Image width
  /// - ${height} - Image height
  /// - ${cfg_scale} - CFG scale
  /// - ${model} - Model name
  ///
  /// Custom tags:
  /// - ${param_name} - Any custom parameter
  /// - ${param_name:default} - Custom parameter with default value
  /// - ${seed+N} - Seed with offset (e.g., ${seed+42})
  Future<String?> queueWorkflow(
    EriWorkflow workflow,
    Map<String, dynamic> params,
  ) async {
    // Start with workflow default values and merge with provided params
    final mergedParams = <String, dynamic>{
      ...workflow.defaultValues,
      ...params,
    };

    // Fill template tags in the prompt JSON
    final filledPrompt = _fillWorkflowTemplate(workflow.prompt, mergedParams);

    try {
      // Parse and queue the filled prompt
      final promptMap = jsonDecode(filledPrompt) as Map<String, dynamic>;
      return await queuePrompt(promptMap);
    } catch (e) {
      print('Error queueing workflow: $e');
      return null;
    }
  }

  /// Fill template tags in workflow JSON with parameter values
  ///
  /// Mirrors SwarmUI's QuickSimpleTagFiller behavior.
  /// Handles JSON escaping properly for string values.
  String _fillWorkflowTemplate(String template, Map<String, dynamic> params) {
    var result = template;

    // Resolve seed first (needed for seed offset calculations)
    final baseSeed = _resolveSeed(params['seed']);
    params['seed'] = baseSeed;

    // Standard tags - process in order to handle nested replacements
    result = _replaceTag(result, 'prompt', params['prompt'] ?? '');
    result = _replaceTag(result, 'negative_prompt', params['negativePrompt'] ?? params['negative_prompt'] ?? '');
    result = _replaceTag(result, 'seed', baseSeed);
    result = _replaceTag(result, 'steps', params['steps'] ?? 20);
    result = _replaceTag(result, 'width', params['width'] ?? 1024);
    result = _replaceTag(result, 'height', params['height'] ?? 1024);
    result = _replaceTag(result, 'cfg_scale', params['cfgScale'] ?? params['cfg_scale'] ?? params['cfg'] ?? 7.0);
    result = _replaceTag(result, 'cfg', params['cfg'] ?? params['cfgScale'] ?? params['cfg_scale'] ?? 7.0);
    result = _replaceTag(result, 'model', params['model'] ?? '');
    result = _replaceTag(result, 'sampler', params['sampler'] ?? 'euler');
    result = _replaceTag(result, 'scheduler', params['scheduler'] ?? 'normal');
    result = _replaceTag(result, 'denoise', params['denoise'] ?? 1.0);
    result = _replaceTag(result, 'batch_size', params['batchSize'] ?? params['batch_size'] ?? 1);
    result = _replaceTag(result, 'vae', params['vae'] ?? '');
    result = _replaceTag(result, 'clip_skip', params['clipSkip'] ?? params['clip_skip'] ?? 1);

    // Video-specific tags
    result = _replaceTag(result, 'frames', params['frames'] ?? 25);
    result = _replaceTag(result, 'fps', params['fps'] ?? 24);

    // Seed offset support: ${seed+42}, ${seed+100}, etc.
    final seedOffsetRegex = RegExp(r'\$\{seed\+(\d+)\}');
    result = result.replaceAllMapped(seedOffsetRegex, (match) {
      final offset = int.parse(match.group(1)!);
      return (baseSeed + offset).toString();
    });

    // Seed subtraction support: ${seed-42}
    final seedSubtractRegex = RegExp(r'\$\{seed-(\d+)\}');
    result = result.replaceAllMapped(seedSubtractRegex, (match) {
      final offset = int.parse(match.group(1)!);
      return (baseSeed - offset).abs().toString();
    });

    // Custom param tags: ${param_name:default_value}
    // Must be processed after standard tags to avoid conflicts
    final customTagRegex = RegExp(r'\$\{(\w+)(?::([^}]*))?\}');
    result = result.replaceAllMapped(customTagRegex, (match) {
      final paramName = match.group(1)!;
      final defaultValue = match.group(2) ?? '';

      // Check various key formats (camelCase, snake_case, kebab-case)
      dynamic value = params[paramName];
      value ??= params[_toSnakeCase(paramName)];
      value ??= params[_toCamelCase(paramName)];

      if (value != null) {
        return _formatValueForJson(value);
      }
      return _formatValueForJson(defaultValue);
    });

    return result;
  }

  /// Replace a single template tag with its value
  String _replaceTag(String template, String tagName, dynamic value) {
    // Handle the case where tag appears in JSON string context
    // e.g., "text": "${prompt}" or "seed": ${seed}
    final formattedValue = _formatValueForJson(value);

    // Replace ${tagName} pattern
    return template.replaceAll('\${$tagName}', formattedValue);
  }

  /// Format a value appropriately for JSON context
  ///
  /// - Strings are escaped for JSON (quotes, backslashes, newlines, etc.)
  /// - Numbers are converted to string representation
  /// - Booleans are converted to "true" or "false"
  /// - null becomes empty string
  String _formatValueForJson(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is String) {
      // Escape JSON special characters
      return _escapeJsonString(value);
    }

    if (value is num || value is bool) {
      return value.toString();
    }

    if (value is List || value is Map) {
      // For complex types, encode and strip outer quotes if needed
      return jsonEncode(value);
    }

    return value.toString();
  }

  /// Escape special characters for JSON string context
  ///
  /// This is critical for proper JSON generation. Handles:
  /// - Backslash (\) -> (\\)
  /// - Quote (") -> (\")
  /// - Newline -> (\n)
  /// - Carriage return -> (\r)
  /// - Tab -> (\t)
  /// - Backspace -> (\b)
  /// - Form feed -> (\f)
  String _escapeJsonString(String value) {
    final buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      final char = value[i];
      switch (char) {
        case '\\':
          buffer.write('\\\\');
          break;
        case '"':
          buffer.write('\\"');
          break;
        case '\n':
          buffer.write('\\n');
          break;
        case '\r':
          buffer.write('\\r');
          break;
        case '\t':
          buffer.write('\\t');
          break;
        case '\b':
          buffer.write('\\b');
          break;
        case '\f':
          buffer.write('\\f');
          break;
        default:
          // Handle control characters
          final codeUnit = char.codeUnitAt(0);
          if (codeUnit < 32) {
            buffer.write('\\u${codeUnit.toRadixString(16).padLeft(4, '0')}');
          } else {
            buffer.write(char);
          }
      }
    }

    return buffer.toString();
  }

  /// Resolve seed value, generating random if -1 or null
  int _resolveSeed(dynamic seed) {
    if (seed == null || seed == -1) {
      // Generate random seed in valid range
      return Random().nextInt(0x7FFFFFFF);
    }
    if (seed is int) {
      return seed;
    }
    if (seed is String) {
      return int.tryParse(seed) ?? Random().nextInt(0x7FFFFFFF);
    }
    return Random().nextInt(0x7FFFFFFF);
  }

  /// Convert camelCase to snake_case
  String _toSnakeCase(String input) {
    return input.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }

  /// Convert snake_case to camelCase
  String _toCamelCase(String input) {
    return input.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (match) => match.group(1)!.toUpperCase(),
    );
  }

  /// Get list of available node types from ComfyUI
  ///
  /// Returns a sorted list of all registered ComfyUI node class types.
  Future<List<String>> getNodeTypes() async {
    try {
      final objectInfo = await getObjectInfo();
      if (objectInfo == null) return [];

      final nodeTypes = objectInfo.keys.toList();
      nodeTypes.sort();
      return nodeTypes;
    } catch (e) {
      print('Error getting node types: $e');
      return [];
    }
  }

  /// Get detailed object info for all nodes
  ///
  /// Returns the full object_info response from ComfyUI which includes:
  /// - Node class types
  /// - Input definitions (required and optional)
  /// - Output definitions
  /// - Category information
  /// - Display names
  ///
  /// The base getObjectInfo() method is already in ComfyUIService,
  /// this is a typed wrapper that returns the same data.
  Future<Map<String, ComfyNodeInfo>?> getNodeTypesWithInfo() async {
    try {
      final objectInfo = await getObjectInfo();
      if (objectInfo == null) return null;

      final result = <String, ComfyNodeInfo>{};
      for (final entry in objectInfo.entries) {
        final nodeType = entry.key;
        final nodeData = entry.value as Map<String, dynamic>;
        result[nodeType] = ComfyNodeInfo.fromJson(nodeType, nodeData);
      }
      return result;
    } catch (e) {
      print('Error getting node types with info: $e');
      return null;
    }
  }

  /// Get info for a specific node type
  ///
  /// Returns detailed information about a single node type including
  /// its inputs, outputs, and configuration options.
  Future<ComfyNodeInfo?> getNodeTypeInfo(String nodeType) async {
    try {
      final nodeInfo = await getNodeInfo(nodeType);
      if (nodeInfo == null) return null;

      final nodeData = nodeInfo[nodeType] as Map<String, dynamic>?;
      if (nodeData == null) return null;

      return ComfyNodeInfo.fromJson(nodeType, nodeData);
    } catch (e) {
      print('Error getting node type info for $nodeType: $e');
      return null;
    }
  }

  /// Get available input options for a specific node input
  ///
  /// For inputs with predefined options (like sampler_name, scheduler, etc.),
  /// returns the list of valid values.
  Future<List<String>> getNodeInputOptions(
    String nodeType,
    String inputName,
  ) async {
    try {
      final nodeInfo = await getNodeTypeInfo(nodeType);
      if (nodeInfo == null) return [];

      // Check required inputs
      final requiredInput = nodeInfo.inputs.required[inputName];
      if (requiredInput != null && requiredInput.options != null) {
        return requiredInput.options!;
      }

      // Check optional inputs
      final optionalInput = nodeInfo.inputs.optional?[inputName];
      if (optionalInput != null && optionalInput.options != null) {
        return optionalInput.options!;
      }

      return [];
    } catch (e) {
      print('Error getting node input options: $e');
      return [];
    }
  }

  /// Check if a specific node type is available
  Future<bool> hasNodeType(String nodeType) async {
    final nodeTypes = await getNodeTypes();
    return nodeTypes.contains(nodeType);
  }

  /// Check if multiple node types are available
  ///
  /// Returns a map of node type to availability status.
  Future<Map<String, bool>> checkNodeTypes(List<String> nodeTypes) async {
    final available = await getNodeTypes();
    final availableSet = available.toSet();

    return {
      for (final type in nodeTypes) type: availableSet.contains(type),
    };
  }
}

/// Information about a ComfyUI node type
class ComfyNodeInfo {
  /// The class type name (e.g., "KSampler", "CLIPTextEncode")
  final String classType;

  /// Display name for the node
  final String displayName;

  /// Category path (e.g., "sampling", "conditioning")
  final String category;

  /// Input definitions
  final ComfyNodeInputs inputs;

  /// Output type names
  final List<String> outputTypes;

  /// Output display names
  final List<String> outputNames;

  /// Whether this is an output node (has no outputs)
  final bool isOutputNode;

  const ComfyNodeInfo({
    required this.classType,
    required this.displayName,
    required this.category,
    required this.inputs,
    required this.outputTypes,
    required this.outputNames,
    required this.isOutputNode,
  });

  factory ComfyNodeInfo.fromJson(String classType, Map<String, dynamic> json) {
    final input = json['input'] as Map<String, dynamic>? ?? {};
    final required = input['required'] as Map<String, dynamic>? ?? {};
    final optional = input['optional'] as Map<String, dynamic>?;

    final requiredInputs = <String, ComfyInputDef>{};
    for (final entry in required.entries) {
      requiredInputs[entry.key] = ComfyInputDef.fromJson(entry.key, entry.value);
    }

    Map<String, ComfyInputDef>? optionalInputs;
    if (optional != null) {
      optionalInputs = {};
      for (final entry in optional.entries) {
        optionalInputs[entry.key] = ComfyInputDef.fromJson(entry.key, entry.value);
      }
    }

    final outputList = json['output'] as List? ?? [];
    final outputNameList = json['output_name'] as List? ?? [];
    // output_is_list indicates which outputs return lists vs single values
    // Currently stored but not used - could be useful for connection validation
    // final outputIsListList = json['output_is_list'] as List? ?? [];

    return ComfyNodeInfo(
      classType: classType,
      displayName: json['display_name'] as String? ?? classType,
      category: json['category'] as String? ?? 'uncategorized',
      inputs: ComfyNodeInputs(
        required: requiredInputs,
        optional: optionalInputs,
      ),
      outputTypes: outputList.cast<String>(),
      outputNames: outputNameList.cast<String>(),
      isOutputNode: json['output_node'] as bool? ?? false,
    );
  }
}

/// Input definitions for a node
class ComfyNodeInputs {
  /// Required inputs (must be connected or have value)
  final Map<String, ComfyInputDef> required;

  /// Optional inputs
  final Map<String, ComfyInputDef>? optional;

  const ComfyNodeInputs({
    required this.required,
    this.optional,
  });
}

/// Definition of a single input
class ComfyInputDef {
  /// Input name
  final String name;

  /// Input type (e.g., "MODEL", "STRING", "INT", "FLOAT")
  final String type;

  /// Default value if any
  final dynamic defaultValue;

  /// Minimum value for numeric types
  final num? min;

  /// Maximum value for numeric types
  final num? max;

  /// Step for numeric types
  final num? step;

  /// List of options for combo/dropdown types
  final List<String>? options;

  /// Whether this is a multiline text input
  final bool multiline;

  const ComfyInputDef({
    required this.name,
    required this.type,
    this.defaultValue,
    this.min,
    this.max,
    this.step,
    this.options,
    this.multiline = false,
  });

  factory ComfyInputDef.fromJson(String name, dynamic json) {
    if (json is List && json.isNotEmpty) {
      final typeOrOptions = json[0];
      final config = json.length > 1 ? json[1] as Map<String, dynamic>? : null;

      // If first element is a list, it's options (combo type)
      if (typeOrOptions is List) {
        return ComfyInputDef(
          name: name,
          type: 'COMBO',
          options: typeOrOptions.cast<String>(),
          defaultValue: config?['default'],
        );
      }

      // Otherwise it's a type string
      final type = typeOrOptions as String;

      return ComfyInputDef(
        name: name,
        type: type,
        defaultValue: config?['default'],
        min: config?['min'] as num?,
        max: config?['max'] as num?,
        step: config?['step'] as num?,
        multiline: config?['multiline'] as bool? ?? false,
      );
    }

    return ComfyInputDef(
      name: name,
      type: json?.toString() ?? 'UNKNOWN',
    );
  }
}
