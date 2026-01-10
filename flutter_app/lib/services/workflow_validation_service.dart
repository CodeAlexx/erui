import 'dart:convert';

import '../models/workflow_models.dart';
import 'comfyui_service.dart';
import 'comfyui_workflow_api.dart';

/// Validates workflows before execution
///
/// Provides comprehensive validation including:
/// - Structural validation (valid JSON, proper node/connection format)
/// - Connection validation (inputs/outputs match, no cycles)
/// - Node availability checking (required ComfyUI nodes exist)
/// - Parameter validation (values within constraints)
class WorkflowValidationService {
  final ComfyUIService _comfyService;

  /// Cache of available node types for faster validation
  Set<String>? _availableNodeTypes;

  /// Cache of node info for detailed validation
  Map<String, ComfyNodeInfo>? _nodeInfoCache;

  /// When the cache was last updated
  DateTime? _cacheTime;

  /// How long to keep the cache valid
  static const _cacheDuration = Duration(minutes: 5);

  WorkflowValidationService(this._comfyService);

  /// Validate a workflow completely
  ///
  /// Performs all validation checks and returns a comprehensive result.
  /// This is the main entry point for workflow validation.
  Future<ValidationResult> validateWorkflow(EriWorkflow workflow) async {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    // Step 1: Validate JSON structure
    final structureResult = _validateStructure(workflow);
    errors.addAll(structureResult.errors);
    warnings.addAll(structureResult.warnings);

    // If structure is invalid, don't proceed with other checks
    if (structureResult.errors.isNotEmpty) {
      return ValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    // Step 2: Validate node connections
    final connectionResult = _validateConnections(workflow);
    errors.addAll(connectionResult.errors);
    warnings.addAll(connectionResult.warnings);

    // Step 3: Check feature support (async - requires ComfyUI connection)
    try {
      final featureResult = await checkFeatureSupport(workflow);
      errors.addAll(featureResult.errors);
      warnings.addAll(featureResult.warnings);
    } catch (e) {
      warnings.add(ValidationWarning(
        code: 'feature_check_failed',
        message: 'Could not verify node availability: $e',
        severity: WarningSeverity.low,
      ));
    }

    // Step 4: Validate required nodes exist
    final requiredResult = _validateRequiredNodes(workflow);
    errors.addAll(requiredResult.errors);
    warnings.addAll(requiredResult.warnings);

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate workflow JSON structure
  ValidationResult _validateStructure(EriWorkflow workflow) {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    // Validate prompt JSON
    try {
      final prompt = jsonDecode(workflow.prompt);
      if (prompt is! Map<String, dynamic>) {
        errors.add(ValidationError(
          code: 'invalid_prompt_type',
          message: 'Prompt must be a JSON object, got ${prompt.runtimeType}',
          field: 'prompt',
        ));
      } else if (prompt.isEmpty) {
        errors.add(ValidationError(
          code: 'empty_prompt',
          message: 'Workflow prompt cannot be empty',
          field: 'prompt',
        ));
      } else {
        // Validate each node in the prompt
        for (final entry in prompt.entries) {
          final nodeId = entry.key;
          final nodeData = entry.value;

          if (nodeData is! Map<String, dynamic>) {
            errors.add(ValidationError(
              code: 'invalid_node_type',
              message: 'Node $nodeId must be a JSON object',
              nodeId: nodeId,
            ));
            continue;
          }

          // Check for required fields
          if (!nodeData.containsKey('class_type')) {
            errors.add(ValidationError(
              code: 'missing_class_type',
              message: 'Node $nodeId is missing class_type',
              nodeId: nodeId,
            ));
          }

          if (!nodeData.containsKey('inputs')) {
            warnings.add(ValidationWarning(
              code: 'missing_inputs',
              message: 'Node $nodeId has no inputs defined',
              nodeId: nodeId,
              severity: WarningSeverity.low,
            ));
          } else if (nodeData['inputs'] is! Map<String, dynamic>) {
            errors.add(ValidationError(
              code: 'invalid_inputs_type',
              message: 'Node $nodeId inputs must be a JSON object',
              nodeId: nodeId,
            ));
          }
        }
      }
    } catch (e) {
      errors.add(ValidationError(
        code: 'invalid_prompt_json',
        message: 'Invalid prompt JSON: $e',
        field: 'prompt',
      ));
    }

    // Validate workflow JSON (visual editor format) if present
    if (workflow.workflow.isNotEmpty && workflow.workflow != '{}') {
      try {
        final workflowData = jsonDecode(workflow.workflow);
        if (workflowData is! Map<String, dynamic>) {
          warnings.add(ValidationWarning(
            code: 'invalid_workflow_type',
            message: 'Workflow should be a JSON object',
            field: 'workflow',
            severity: WarningSeverity.medium,
          ));
        }
      } catch (e) {
        warnings.add(ValidationWarning(
          code: 'invalid_workflow_json',
          message: 'Invalid workflow JSON (visual data): $e',
          field: 'workflow',
          severity: WarningSeverity.medium,
        ));
      }
    }

    // Validate custom params JSON
    if (workflow.customParams.isNotEmpty && workflow.customParams != '[]') {
      try {
        final params = jsonDecode(workflow.customParams);
        if (params is! List) {
          warnings.add(ValidationWarning(
            code: 'invalid_custom_params_type',
            message: 'Custom params should be a JSON array',
            field: 'customParams',
            severity: WarningSeverity.low,
          ));
        } else {
          // Validate each parameter definition
          for (int i = 0; i < params.length; i++) {
            final param = params[i];
            if (param is! Map<String, dynamic>) {
              warnings.add(ValidationWarning(
                code: 'invalid_param_type',
                message: 'Parameter at index $i should be a JSON object',
                field: 'customParams[$i]',
                severity: WarningSeverity.low,
              ));
              continue;
            }

            if (!param.containsKey('id') || !param.containsKey('name') || !param.containsKey('type')) {
              warnings.add(ValidationWarning(
                code: 'incomplete_param',
                message: 'Parameter at index $i missing required fields (id, name, type)',
                field: 'customParams[$i]',
                severity: WarningSeverity.medium,
              ));
            }
          }
        }
      } catch (e) {
        warnings.add(ValidationWarning(
          code: 'invalid_custom_params_json',
          message: 'Invalid custom params JSON: $e',
          field: 'customParams',
          severity: WarningSeverity.low,
        ));
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate node connections
  ValidationResult _validateConnections(EriWorkflow workflow) {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    try {
      final prompt = jsonDecode(workflow.prompt) as Map<String, dynamic>;
      final nodeIds = prompt.keys.toSet();
      final connectedInputs = <String, Set<String>>{};

      for (final entry in prompt.entries) {
        final nodeId = entry.key;
        final nodeData = entry.value as Map<String, dynamic>;
        final inputs = nodeData['inputs'] as Map<String, dynamic>? ?? {};

        connectedInputs[nodeId] = {};

        for (final inputEntry in inputs.entries) {
          final inputName = inputEntry.key;
          final inputValue = inputEntry.value;

          // Check if this is a connection (array of [nodeId, outputIndex])
          if (inputValue is List && inputValue.length == 2) {
            final sourceNodeId = inputValue[0].toString();
            final outputIndex = inputValue[1];

            // Validate source node exists
            if (!nodeIds.contains(sourceNodeId)) {
              errors.add(ValidationError(
                code: 'missing_source_node',
                message: 'Node $nodeId input "$inputName" references non-existent node $sourceNodeId',
                nodeId: nodeId,
                field: inputName,
              ));
            }

            // Validate output index is valid
            if (outputIndex is! int || outputIndex < 0) {
              errors.add(ValidationError(
                code: 'invalid_output_index',
                message: 'Node $nodeId input "$inputName" has invalid output index: $outputIndex',
                nodeId: nodeId,
                field: inputName,
              ));
            }

            connectedInputs[nodeId]!.add(inputName);
          }
        }
      }

      // Check for cycles (basic check - more advanced cycle detection could be added)
      final visited = <String>{};
      final recursionStack = <String>{};

      bool hasCycle(String nodeId) {
        if (recursionStack.contains(nodeId)) return true;
        if (visited.contains(nodeId)) return false;

        visited.add(nodeId);
        recursionStack.add(nodeId);

        final nodeData = prompt[nodeId] as Map<String, dynamic>?;
        if (nodeData != null) {
          final inputs = nodeData['inputs'] as Map<String, dynamic>? ?? {};
          for (final inputValue in inputs.values) {
            if (inputValue is List && inputValue.length == 2) {
              final sourceNodeId = inputValue[0].toString();
              if (nodeIds.contains(sourceNodeId) && hasCycle(sourceNodeId)) {
                return true;
              }
            }
          }
        }

        recursionStack.remove(nodeId);
        return false;
      }

      for (final nodeId in nodeIds) {
        if (hasCycle(nodeId)) {
          errors.add(ValidationError(
            code: 'cycle_detected',
            message: 'Workflow contains a cycle involving node $nodeId',
            nodeId: nodeId,
          ));
          break; // Only report first cycle found
        }
      }

      // Check for disconnected nodes (nodes with no inputs and no outputs used)
      final usedAsSource = <String>{};
      for (final entry in prompt.entries) {
        final nodeData = entry.value as Map<String, dynamic>;
        final inputs = nodeData['inputs'] as Map<String, dynamic>? ?? {};
        for (final inputValue in inputs.values) {
          if (inputValue is List && inputValue.length == 2) {
            usedAsSource.add(inputValue[0].toString());
          }
        }
      }

      for (final nodeId in nodeIds) {
        final nodeData = prompt[nodeId] as Map<String, dynamic>;
        final classType = nodeData['class_type'] as String?;
        final inputs = nodeData['inputs'] as Map<String, dynamic>? ?? {};

        // Check if this node is an output node (SaveImage, PreviewImage, etc.)
        final isOutputNode = classType != null &&
            (classType.contains('Save') ||
             classType.contains('Preview') ||
             classType.contains('Output') ||
             classType == 'VHS_VideoCombine');

        // Node is disconnected if it's not used as source and not an output node
        if (!usedAsSource.contains(nodeId) && !isOutputNode && inputs.isEmpty) {
          warnings.add(ValidationWarning(
            code: 'disconnected_node',
            message: 'Node $nodeId ($classType) appears to be disconnected',
            nodeId: nodeId,
            severity: WarningSeverity.medium,
          ));
        }
      }

    } catch (e) {
      // Structure validation should have caught this, but just in case
      errors.add(ValidationError(
        code: 'connection_validation_error',
        message: 'Failed to validate connections: $e',
      ));
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Check if required ComfyUI features (nodes) are available
  Future<ValidationResult> checkFeatureSupport(EriWorkflow workflow) async {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    // Refresh cache if needed
    await _refreshCache();

    if (_availableNodeTypes == null) {
      warnings.add(ValidationWarning(
        code: 'cannot_check_features',
        message: 'Could not retrieve available nodes from ComfyUI',
        severity: WarningSeverity.medium,
      ));
      return ValidationResult(isValid: true, errors: errors, warnings: warnings);
    }

    try {
      final prompt = jsonDecode(workflow.prompt) as Map<String, dynamic>;

      for (final entry in prompt.entries) {
        final nodeId = entry.key;
        final nodeData = entry.value as Map<String, dynamic>;
        final classType = nodeData['class_type'] as String?;

        if (classType == null) continue;

        if (!_availableNodeTypes!.contains(classType)) {
          errors.add(ValidationError(
            code: 'missing_node_type',
            message: 'Node type "$classType" is not available in ComfyUI',
            nodeId: nodeId,
            field: 'class_type',
            suggestion: _suggestSimilarNode(classType),
          ));
        }
      }
    } catch (e) {
      warnings.add(ValidationWarning(
        code: 'feature_check_error',
        message: 'Error checking feature support: $e',
        severity: WarningSeverity.low,
      ));
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate node inputs against their definitions
  ///
  /// Uses cached node info to verify that node inputs match expected types
  /// and that required inputs are provided.
  Future<ValidationResult> validateNodeInputs(EriWorkflow workflow) async {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    // Ensure cache is populated
    await _refreshCache();

    if (_nodeInfoCache == null || _nodeInfoCache!.isEmpty) {
      warnings.add(const ValidationWarning(
        code: 'no_node_info',
        message: 'Could not retrieve node definitions for detailed validation',
        severity: WarningSeverity.low,
      ));
      return ValidationResult(isValid: true, errors: errors, warnings: warnings);
    }

    try {
      final prompt = jsonDecode(workflow.prompt) as Map<String, dynamic>;

      for (final entry in prompt.entries) {
        final nodeId = entry.key;
        final nodeData = entry.value as Map<String, dynamic>;
        final classType = nodeData['class_type'] as String?;
        final inputs = nodeData['inputs'] as Map<String, dynamic>? ?? {};

        if (classType == null) continue;

        final nodeInfo = _nodeInfoCache![classType];
        if (nodeInfo == null) continue;

        // Check required inputs
        for (final reqEntry in nodeInfo.inputs.required.entries) {
          final inputName = reqEntry.key;
          final inputDef = reqEntry.value;

          if (!inputs.containsKey(inputName)) {
            // Check if it's a connection type (MODEL, CLIP, etc.) vs value type
            if (!_isConnectionType(inputDef.type)) {
              errors.add(ValidationError(
                code: 'missing_required_input',
                message: 'Node $nodeId ($classType) missing required input "$inputName"',
                nodeId: nodeId,
                field: inputName,
              ));
            } else {
              // Connection inputs are ok to be missing if not connected
              // but warn about it
              warnings.add(ValidationWarning(
                code: 'unconnected_input',
                message: 'Node $nodeId ($classType) input "$inputName" is not connected',
                nodeId: nodeId,
                severity: WarningSeverity.medium,
              ));
            }
          }
        }
      }
    } catch (e) {
      warnings.add(ValidationWarning(
        code: 'input_validation_error',
        message: 'Error validating node inputs: $e',
        severity: WarningSeverity.low,
      ));
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Check if a type is a connection type (vs a value type)
  bool _isConnectionType(String type) {
    const connectionTypes = {
      'MODEL', 'CLIP', 'VAE', 'CONDITIONING', 'LATENT', 'IMAGE', 'MASK',
      'CONTROL_NET', 'UPSCALE_MODEL', 'SAMPLER', 'SIGMAS', 'NOISE',
      'GUIDER', 'CLIP_VISION', 'STYLE_MODEL', 'GLIGEN', 'MOTION_MODEL',
    };
    return connectionTypes.contains(type.toUpperCase());
  }

  /// Validate required nodes exist in workflow
  ValidationResult _validateRequiredNodes(EriWorkflow workflow) {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    try {
      final prompt = jsonDecode(workflow.prompt) as Map<String, dynamic>;
      final nodeTypes = <String>{};

      for (final nodeData in prompt.values) {
        if (nodeData is Map<String, dynamic>) {
          final classType = nodeData['class_type'] as String?;
          if (classType != null) {
            nodeTypes.add(classType);
          }
        }
      }

      // Check for output nodes
      final hasOutputNode = nodeTypes.any((type) =>
          type.contains('Save') ||
          type.contains('Preview') ||
          type == 'VHS_VideoCombine' ||
          type.contains('Output'));

      if (!hasOutputNode) {
        warnings.add(ValidationWarning(
          code: 'no_output_node',
          message: 'Workflow has no output node (SaveImage, PreviewImage, etc.)',
          severity: WarningSeverity.high,
        ));
      }

      // Check for sampling nodes
      final hasSampler = nodeTypes.any((type) =>
          type.contains('Sampler') ||
          type.contains('Sample'));

      if (!hasSampler) {
        warnings.add(ValidationWarning(
          code: 'no_sampler',
          message: 'Workflow has no sampler node - generation may not work correctly',
          severity: WarningSeverity.medium,
        ));
      }

    } catch (e) {
      // Ignore - structure validation handles this
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate parameter values against workflow parameter definitions
  ValidationResult validateParams(
    EriWorkflow workflow,
    Map<String, dynamic> params,
  ) {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    final paramDefs = workflow.parameters;

    for (final paramDef in paramDefs) {
      final value = params[paramDef.id];

      // Check if required parameter is missing
      if (value == null && !paramDef.toggleable) {
        // Not an error if there's a default value
        if (paramDef.defaultValue == null) {
          warnings.add(ValidationWarning(
            code: 'missing_param',
            message: 'Parameter "${paramDef.name}" has no value and no default',
            field: paramDef.id,
            severity: WarningSeverity.low,
          ));
        }
        continue;
      }

      if (value == null) continue;

      // Validate based on type
      switch (paramDef.type) {
        case 'integer':
          if (value is! int) {
            final parsed = int.tryParse(value.toString());
            if (parsed == null) {
              errors.add(ValidationError(
                code: 'invalid_integer',
                message: 'Parameter "${paramDef.name}" must be an integer',
                field: paramDef.id,
              ));
              continue;
            }
          }
          final intValue = value is int ? value : int.parse(value.toString());
          if (paramDef.min != null && intValue < paramDef.min!) {
            errors.add(ValidationError(
              code: 'value_too_low',
              message: 'Parameter "${paramDef.name}" must be at least ${paramDef.min}',
              field: paramDef.id,
            ));
          }
          if (paramDef.max != null && intValue > paramDef.max!) {
            errors.add(ValidationError(
              code: 'value_too_high',
              message: 'Parameter "${paramDef.name}" must be at most ${paramDef.max}',
              field: paramDef.id,
            ));
          }
          break;

        case 'decimal':
          if (value is! num) {
            final parsed = double.tryParse(value.toString());
            if (parsed == null) {
              errors.add(ValidationError(
                code: 'invalid_decimal',
                message: 'Parameter "${paramDef.name}" must be a number',
                field: paramDef.id,
              ));
              continue;
            }
          }
          final numValue = value is num ? value : double.parse(value.toString());
          if (paramDef.min != null && numValue < paramDef.min!) {
            errors.add(ValidationError(
              code: 'value_too_low',
              message: 'Parameter "${paramDef.name}" must be at least ${paramDef.min}',
              field: paramDef.id,
            ));
          }
          if (paramDef.max != null && numValue > paramDef.max!) {
            errors.add(ValidationError(
              code: 'value_too_high',
              message: 'Parameter "${paramDef.name}" must be at most ${paramDef.max}',
              field: paramDef.id,
            ));
          }
          break;

        case 'dropdown':
          if (paramDef.values != null && !paramDef.values!.contains(value.toString())) {
            errors.add(ValidationError(
              code: 'invalid_option',
              message: 'Parameter "${paramDef.name}" must be one of: ${paramDef.values!.join(", ")}',
              field: paramDef.id,
            ));
          }
          break;

        case 'boolean':
          if (value is! bool) {
            final strValue = value.toString().toLowerCase();
            if (strValue != 'true' && strValue != 'false') {
              errors.add(ValidationError(
                code: 'invalid_boolean',
                message: 'Parameter "${paramDef.name}" must be true or false',
                field: paramDef.id,
              ));
            }
          }
          break;

        case 'text':
          // Text parameters are always valid
          break;

        case 'image':
          // Could validate image format/existence
          if (value is String && value.isEmpty) {
            warnings.add(ValidationWarning(
              code: 'empty_image',
              message: 'Parameter "${paramDef.name}" image is empty',
              field: paramDef.id,
              severity: WarningSeverity.low,
            ));
          }
          break;

        case 'model':
          // Could validate model exists
          if (value is String && value.isEmpty) {
            warnings.add(ValidationWarning(
              code: 'empty_model',
              message: 'Parameter "${paramDef.name}" model is not specified',
              field: paramDef.id,
              severity: WarningSeverity.medium,
            ));
          }
          break;
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate standard generation parameters
  ValidationResult validateStandardParams(Map<String, dynamic> params) {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    // Seed validation
    final seed = params['seed'];
    if (seed != null && seed is! int) {
      final parsed = int.tryParse(seed.toString());
      if (parsed == null) {
        errors.add(ValidationError(
          code: 'invalid_seed',
          message: 'Seed must be an integer',
          field: 'seed',
        ));
      }
    }

    // Steps validation
    final steps = params['steps'];
    if (steps != null) {
      final stepsInt = steps is int ? steps : int.tryParse(steps.toString());
      if (stepsInt == null) {
        errors.add(ValidationError(
          code: 'invalid_steps',
          message: 'Steps must be an integer',
          field: 'steps',
        ));
      } else if (stepsInt < 1 || stepsInt > 150) {
        errors.add(ValidationError(
          code: 'steps_out_of_range',
          message: 'Steps must be between 1 and 150',
          field: 'steps',
        ));
      }
    }

    // Width/Height validation
    for (final dim in ['width', 'height']) {
      final value = params[dim];
      if (value != null) {
        final valueInt = value is int ? value : int.tryParse(value.toString());
        if (valueInt == null) {
          errors.add(ValidationError(
            code: 'invalid_$dim',
            message: '${dim.substring(0, 1).toUpperCase()}${dim.substring(1)} must be an integer',
            field: dim,
          ));
        } else if (valueInt < 64 || valueInt > 8192) {
          errors.add(ValidationError(
            code: '${dim}_out_of_range',
            message: '${dim.substring(0, 1).toUpperCase()}${dim.substring(1)} must be between 64 and 8192',
            field: dim,
          ));
        } else if (valueInt % 8 != 0) {
          warnings.add(ValidationWarning(
            code: '${dim}_not_divisible_by_8',
            message: '${dim.substring(0, 1).toUpperCase()}${dim.substring(1)} should be divisible by 8 for best results',
            field: dim,
            severity: WarningSeverity.low,
          ));
        }
      }
    }

    // CFG validation
    final cfg = params['cfg'] ?? params['cfgScale'] ?? params['cfg_scale'];
    if (cfg != null) {
      final cfgNum = cfg is num ? cfg : double.tryParse(cfg.toString());
      if (cfgNum == null) {
        errors.add(ValidationError(
          code: 'invalid_cfg',
          message: 'CFG scale must be a number',
          field: 'cfg',
        ));
      } else if (cfgNum < 0 || cfgNum > 30) {
        warnings.add(ValidationWarning(
          code: 'cfg_extreme',
          message: 'CFG scale is very ${cfgNum < 1 ? "low" : "high"}, results may be unexpected',
          field: 'cfg',
          severity: WarningSeverity.medium,
        ));
      }
    }

    // Denoise validation
    final denoise = params['denoise'];
    if (denoise != null) {
      final denoiseNum = denoise is num ? denoise : double.tryParse(denoise.toString());
      if (denoiseNum == null) {
        errors.add(ValidationError(
          code: 'invalid_denoise',
          message: 'Denoise must be a number',
          field: 'denoise',
        ));
      } else if (denoiseNum < 0 || denoiseNum > 1) {
        errors.add(ValidationError(
          code: 'denoise_out_of_range',
          message: 'Denoise must be between 0 and 1',
          field: 'denoise',
        ));
      }
    }

    // Prompt validation
    final prompt = params['prompt'];
    if (prompt != null && prompt is String && prompt.isEmpty) {
      warnings.add(ValidationWarning(
        code: 'empty_prompt',
        message: 'Prompt is empty',
        field: 'prompt',
        severity: WarningSeverity.medium,
      ));
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Refresh the node types cache
  Future<void> _refreshCache() async {
    final now = DateTime.now();

    if (_cacheTime != null && now.difference(_cacheTime!) < _cacheDuration) {
      return; // Cache is still valid
    }

    try {
      final nodeTypes = await _comfyService.getNodeTypes();
      _availableNodeTypes = nodeTypes.toSet();

      final nodeInfo = await _comfyService.getNodeTypesWithInfo();
      _nodeInfoCache = nodeInfo;

      _cacheTime = now;
    } catch (e) {
      // Keep old cache if refresh fails
      print('Failed to refresh validation cache: $e');
    }
  }

  /// Invalidate the cache (e.g., after connecting to a different server)
  void invalidateCache() {
    _availableNodeTypes = null;
    _nodeInfoCache = null;
    _cacheTime = null;
  }

  /// Suggest a similar node type if the requested one is not available
  String? _suggestSimilarNode(String nodeType) {
    if (_availableNodeTypes == null) return null;

    final lowerType = nodeType.toLowerCase();
    String? bestMatch;
    int bestScore = 0;

    for (final available in _availableNodeTypes!) {
      final lowerAvailable = available.toLowerCase();

      // Check for partial matches
      if (lowerAvailable.contains(lowerType) || lowerType.contains(lowerAvailable)) {
        final score = _levenshteinDistance(lowerType, lowerAvailable);
        if (bestMatch == null || score < bestScore) {
          bestMatch = available;
          bestScore = score;
        }
      }
    }

    // Also check for common alternatives
    final alternatives = _commonAlternatives[nodeType];
    if (alternatives != null) {
      for (final alt in alternatives) {
        if (_availableNodeTypes!.contains(alt)) {
          return alt;
        }
      }
    }

    return bestMatch;
  }

  /// Common node type alternatives (old name -> new names)
  static const _commonAlternatives = <String, List<String>>{
    'LoadImage': ['LoadImageBase64'],
    'LoadImageBase64': ['LoadImage'],
    'KSampler': ['KSamplerAdvanced', 'SamplerCustom'],
    'CLIPTextEncode': ['CLIPTextEncodeSDXL'],
  };

  /// Calculate Levenshtein distance for similarity matching
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List.generate(s2.length + 1, (i) => i);
    List<int> v1 = List.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < s2.length; j++) {
        final cost = s1[i] == s2[j] ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((a, b) => a < b ? a : b);
      }

      final temp = v0;
      v0 = v1;
      v1 = temp;
    }

    return v0[s2.length];
  }
}

/// Result of workflow validation
class ValidationResult {
  /// Whether the workflow passed validation (no errors)
  final bool isValid;

  /// List of validation errors (blocking issues)
  final List<ValidationError> errors;

  /// List of validation warnings (non-blocking issues)
  final List<ValidationWarning> warnings;

  const ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  /// Whether there are any warnings
  bool get hasWarnings => warnings.isNotEmpty;

  /// Whether there are any high-severity warnings
  bool get hasHighSeverityWarnings =>
      warnings.any((w) => w.severity == WarningSeverity.high);

  /// Get all issues (errors and warnings) combined
  List<ValidationIssue> get allIssues => [...errors, ...warnings];

  /// Create a successful validation result with no issues
  factory ValidationResult.success() {
    return const ValidationResult(
      isValid: true,
      errors: [],
      warnings: [],
    );
  }

  /// Merge multiple validation results
  factory ValidationResult.merge(List<ValidationResult> results) {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    for (final result in results) {
      errors.addAll(result.errors);
      warnings.addAll(result.warnings);
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  @override
  String toString() {
    if (isValid && warnings.isEmpty) {
      return 'ValidationResult: Valid';
    }
    return 'ValidationResult: ${errors.length} errors, ${warnings.length} warnings';
  }
}

/// Base class for validation issues
abstract class ValidationIssue {
  /// Error/warning code for programmatic handling
  final String code;

  /// Human-readable message
  final String message;

  /// Field or parameter that caused the issue
  final String? field;

  /// Node ID if the issue is related to a specific node
  final String? nodeId;

  const ValidationIssue({
    required this.code,
    required this.message,
    this.field,
    this.nodeId,
  });
}

/// A validation error (blocking issue)
class ValidationError extends ValidationIssue {
  /// Suggested fix for the error
  final String? suggestion;

  const ValidationError({
    required super.code,
    required super.message,
    super.field,
    super.nodeId,
    this.suggestion,
  });

  @override
  String toString() => 'Error [$code]: $message${nodeId != null ? " (node: $nodeId)" : ""}';
}

/// A validation warning (non-blocking issue)
class ValidationWarning extends ValidationIssue {
  /// Severity of the warning
  final WarningSeverity severity;

  const ValidationWarning({
    required super.code,
    required super.message,
    super.field,
    super.nodeId,
    required this.severity,
  });

  @override
  String toString() => 'Warning [$code]: $message${nodeId != null ? " (node: $nodeId)" : ""}';
}

/// Warning severity levels
enum WarningSeverity {
  /// Minor issue, unlikely to cause problems
  low,

  /// Moderate issue, might cause unexpected behavior
  medium,

  /// Significant issue, likely to cause problems
  high,
}
