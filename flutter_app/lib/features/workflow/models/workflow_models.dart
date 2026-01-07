import 'dart:convert';
import 'package:flutter/material.dart';

/// A workflow is a collection of nodes connected together
class Workflow {
  final String id;
  final String name;
  final String? description;
  final Map<String, WorkflowNode> nodes;
  final List<WorkflowConnection> connections;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final Map<String, dynamic> metadata;

  Workflow({
    required this.id,
    required this.name,
    this.description,
    Map<String, WorkflowNode>? nodes,
    List<WorkflowConnection>? connections,
    DateTime? createdAt,
    DateTime? modifiedAt,
    Map<String, dynamic>? metadata,
  })  : nodes = nodes ?? {},
        connections = connections ?? [],
        createdAt = createdAt ?? DateTime.now(),
        modifiedAt = modifiedAt ?? DateTime.now(),
        metadata = metadata ?? {};

  Workflow copyWith({
    String? id,
    String? name,
    String? description,
    Map<String, WorkflowNode>? nodes,
    List<WorkflowConnection>? connections,
    DateTime? createdAt,
    DateTime? modifiedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Workflow(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      nodes: nodes ?? Map.from(this.nodes),
      connections: connections ?? List.from(this.connections),
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? DateTime.now(),
      metadata: metadata ?? Map.from(this.metadata),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'nodes': nodes.map((k, v) => MapEntry(k, v.toJson())),
    'connections': connections.map((c) => c.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
    'modified_at': modifiedAt.toIso8601String(),
    'metadata': metadata,
  };

  factory Workflow.fromJson(Map<String, dynamic> json) {
    return Workflow(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      nodes: (json['nodes'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, WorkflowNode.fromJson(v as Map<String, dynamic>)),
      ),
      connections: (json['connections'] as List?)
          ?.map((e) => WorkflowConnection.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      modifiedAt: json['modified_at'] != null
          ? DateTime.parse(json['modified_at'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to ComfyUI workflow format
  Map<String, dynamic> toComfyUI() {
    final prompt = <String, dynamic>{};

    for (final entry in nodes.entries) {
      final node = entry.value;
      final inputs = <String, dynamic>{};

      // Add static input values
      for (final inputEntry in node.inputValues.entries) {
        inputs[inputEntry.key] = inputEntry.value;
      }

      // Add connected inputs
      for (final conn in connections.where((c) => c.targetNodeId == entry.key)) {
        inputs[conn.targetInput] = [conn.sourceNodeId, conn.sourceOutput];
      }

      prompt[entry.key] = {
        'class_type': node.type,
        'inputs': inputs,
      };
    }

    return {'prompt': prompt};
  }

  /// Create from ComfyUI workflow format
  factory Workflow.fromComfyUI(Map<String, dynamic> json, {String? name}) {
    final prompt = json['prompt'] as Map<String, dynamic>;
    final nodes = <String, WorkflowNode>{};
    final connections = <WorkflowConnection>[];

    int y = 0;
    for (final entry in prompt.entries) {
      final nodeId = entry.key;
      final nodeData = entry.value as Map<String, dynamic>;
      final classType = nodeData['class_type'] as String;
      final inputs = nodeData['inputs'] as Map<String, dynamic>? ?? {};

      // Get node definition
      final definition = NodeDefinitions.getDefinition(classType);

      // Parse inputs
      final inputValues = <String, dynamic>{};

      for (final inputEntry in inputs.entries) {
        final value = inputEntry.value;
        if (value is List && value.length == 2) {
          // This is a connection
          connections.add(WorkflowConnection(
            id: '${value[0]}_${inputEntry.key}_$nodeId',
            sourceNodeId: value[0].toString(),
            sourceOutput: value[1] is int ? value[1] : 0,
            targetNodeId: nodeId,
            targetInput: inputEntry.key,
          ));
        } else {
          // This is a static value
          inputValues[inputEntry.key] = value;
        }
      }

      nodes[nodeId] = WorkflowNode(
        id: nodeId,
        type: classType,
        title: definition?.title ?? classType,
        position: Offset(100, y.toDouble()),
        inputValues: inputValues,
      );

      y += 150;
    }

    return Workflow(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name ?? 'Imported Workflow',
      nodes: nodes,
      connections: connections,
    );
  }
}

/// A node in the workflow
class WorkflowNode {
  final String id;
  final String type;
  final String title;
  final Offset position;
  final Size size;
  final Map<String, dynamic> inputValues;
  final bool isCollapsed;

  WorkflowNode({
    required this.id,
    required this.type,
    required this.title,
    this.position = Offset.zero,
    this.size = const Size(200, 100),
    Map<String, dynamic>? inputValues,
    this.isCollapsed = false,
  }) : inputValues = inputValues ?? {};

  WorkflowNode copyWith({
    String? id,
    String? type,
    String? title,
    Offset? position,
    Size? size,
    Map<String, dynamic>? inputValues,
    bool? isCollapsed,
  }) {
    return WorkflowNode(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      position: position ?? this.position,
      size: size ?? this.size,
      inputValues: inputValues ?? Map.from(this.inputValues),
      isCollapsed: isCollapsed ?? this.isCollapsed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'position': {'x': position.dx, 'y': position.dy},
    'size': {'width': size.width, 'height': size.height},
    'input_values': inputValues,
    'is_collapsed': isCollapsed,
  };

  factory WorkflowNode.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>?;
    final sz = json['size'] as Map<String, dynamic>?;

    return WorkflowNode(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      position: pos != null
          ? Offset(
              (pos['x'] as num).toDouble(),
              (pos['y'] as num).toDouble(),
            )
          : Offset.zero,
      size: sz != null
          ? Size(
              (sz['width'] as num).toDouble(),
              (sz['height'] as num).toDouble(),
            )
          : const Size(200, 100),
      inputValues: json['input_values'] as Map<String, dynamic>?,
      isCollapsed: json['is_collapsed'] as bool? ?? false,
    );
  }
}

/// A connection between nodes
class WorkflowConnection {
  final String id;
  final String sourceNodeId;
  final int sourceOutput;
  final String targetNodeId;
  final String targetInput;

  WorkflowConnection({
    required this.id,
    required this.sourceNodeId,
    required this.sourceOutput,
    required this.targetNodeId,
    required this.targetInput,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'source_node_id': sourceNodeId,
    'source_output': sourceOutput,
    'target_node_id': targetNodeId,
    'target_input': targetInput,
  };

  factory WorkflowConnection.fromJson(Map<String, dynamic> json) {
    return WorkflowConnection(
      id: json['id'] as String,
      sourceNodeId: json['source_node_id'] as String,
      sourceOutput: json['source_output'] as int,
      targetNodeId: json['target_node_id'] as String,
      targetInput: json['target_input'] as String,
    );
  }
}

/// Definition of a node type
class NodeDefinition {
  final String type;
  final String title;
  final String category;
  final String description;
  final List<NodeInput> inputs;
  final List<NodeOutput> outputs;
  final Color color;

  const NodeDefinition({
    required this.type,
    required this.title,
    required this.category,
    this.description = '',
    this.inputs = const [],
    this.outputs = const [],
    this.color = Colors.grey,
  });
}

/// Definition of a node input
class NodeInput {
  final String name;
  final String type;
  final dynamic defaultValue;
  final bool required;
  final dynamic min;
  final dynamic max;
  final List<String>? options;

  const NodeInput({
    required this.name,
    required this.type,
    this.defaultValue,
    this.required = true,
    this.min,
    this.max,
    this.options,
  });
}

/// Definition of a node output
class NodeOutput {
  final String name;
  final String type;

  const NodeOutput({
    required this.name,
    required this.type,
  });
}

/// Registry of all node definitions
class NodeDefinitions {
  static final Map<String, NodeDefinition> _definitions = {};

  /// Get a node definition by type
  static NodeDefinition? getDefinition(String type) => _definitions[type];

  /// Get all definitions
  static List<NodeDefinition> get all => _definitions.values.toList();

  /// Get definitions by category
  static List<NodeDefinition> getByCategory(String category) {
    return _definitions.values.where((d) => d.category == category).toList();
  }

  /// Get all categories
  static List<String> get categories {
    return _definitions.values.map((d) => d.category).toSet().toList()..sort();
  }

  /// Register default ComfyUI nodes
  static void registerDefaults() {
    _definitions.clear();

    // ========== LOADERS ==========
    _register(NodeDefinition(
      type: 'CheckpointLoaderSimple',
      title: 'Load Checkpoint',
      category: 'loaders',
      description: 'Load a checkpoint model',
      color: Colors.purple,
      inputs: [
        NodeInput(name: 'ckpt_name', type: 'STRING'),
      ],
      outputs: [
        NodeOutput(name: 'MODEL', type: 'MODEL'),
        NodeOutput(name: 'CLIP', type: 'CLIP'),
        NodeOutput(name: 'VAE', type: 'VAE'),
      ],
    ));

    _register(NodeDefinition(
      type: 'VAELoader',
      title: 'Load VAE',
      category: 'loaders',
      color: Colors.purple,
      inputs: [
        NodeInput(name: 'vae_name', type: 'STRING'),
      ],
      outputs: [
        NodeOutput(name: 'VAE', type: 'VAE'),
      ],
    ));

    _register(NodeDefinition(
      type: 'LoraLoader',
      title: 'Load LoRA',
      category: 'loaders',
      color: Colors.purple,
      inputs: [
        NodeInput(name: 'model', type: 'MODEL'),
        NodeInput(name: 'clip', type: 'CLIP'),
        NodeInput(name: 'lora_name', type: 'STRING'),
        NodeInput(name: 'strength_model', type: 'FLOAT', defaultValue: 1.0, min: -10, max: 10),
        NodeInput(name: 'strength_clip', type: 'FLOAT', defaultValue: 1.0, min: -10, max: 10),
      ],
      outputs: [
        NodeOutput(name: 'MODEL', type: 'MODEL'),
        NodeOutput(name: 'CLIP', type: 'CLIP'),
      ],
    ));

    _register(NodeDefinition(
      type: 'ControlNetLoader',
      title: 'Load ControlNet',
      category: 'loaders',
      color: Colors.purple,
      inputs: [
        NodeInput(name: 'control_net_name', type: 'STRING'),
      ],
      outputs: [
        NodeOutput(name: 'CONTROL_NET', type: 'CONTROL_NET'),
      ],
    ));

    _register(NodeDefinition(
      type: 'UpscaleModelLoader',
      title: 'Load Upscale Model',
      category: 'loaders',
      color: Colors.purple,
      inputs: [
        NodeInput(name: 'model_name', type: 'STRING'),
      ],
      outputs: [
        NodeOutput(name: 'UPSCALE_MODEL', type: 'UPSCALE_MODEL'),
      ],
    ));

    _register(NodeDefinition(
      type: 'LoadImage',
      title: 'Load Image',
      category: 'loaders',
      color: Colors.purple,
      inputs: [
        NodeInput(name: 'image', type: 'STRING'),
      ],
      outputs: [
        NodeOutput(name: 'IMAGE', type: 'IMAGE'),
        NodeOutput(name: 'MASK', type: 'MASK'),
      ],
    ));

    // ========== CONDITIONING ==========
    _register(NodeDefinition(
      type: 'CLIPTextEncode',
      title: 'CLIP Text Encode',
      category: 'conditioning',
      color: Colors.orange,
      inputs: [
        NodeInput(name: 'text', type: 'STRING'),
        NodeInput(name: 'clip', type: 'CLIP'),
      ],
      outputs: [
        NodeOutput(name: 'CONDITIONING', type: 'CONDITIONING'),
      ],
    ));

    _register(NodeDefinition(
      type: 'ConditioningCombine',
      title: 'Conditioning Combine',
      category: 'conditioning',
      color: Colors.orange,
      inputs: [
        NodeInput(name: 'cond_1', type: 'CONDITIONING'),
        NodeInput(name: 'cond_2', type: 'CONDITIONING'),
      ],
      outputs: [
        NodeOutput(name: 'CONDITIONING', type: 'CONDITIONING'),
      ],
    ));

    _register(NodeDefinition(
      type: 'ConditioningSetMask',
      title: 'Conditioning Set Mask',
      category: 'conditioning',
      color: Colors.orange,
      inputs: [
        NodeInput(name: 'conditioning', type: 'CONDITIONING'),
        NodeInput(name: 'mask', type: 'MASK'),
        NodeInput(name: 'strength', type: 'FLOAT', defaultValue: 1.0, min: 0, max: 10),
        NodeInput(name: 'set_cond_area', type: 'STRING', options: ['default', 'mask bounds']),
      ],
      outputs: [
        NodeOutput(name: 'CONDITIONING', type: 'CONDITIONING'),
      ],
    ));

    _register(NodeDefinition(
      type: 'ControlNetApplyAdvanced',
      title: 'Apply ControlNet',
      category: 'conditioning',
      color: Colors.orange,
      inputs: [
        NodeInput(name: 'positive', type: 'CONDITIONING'),
        NodeInput(name: 'negative', type: 'CONDITIONING'),
        NodeInput(name: 'control_net', type: 'CONTROL_NET'),
        NodeInput(name: 'image', type: 'IMAGE'),
        NodeInput(name: 'strength', type: 'FLOAT', defaultValue: 1.0, min: 0, max: 2),
        NodeInput(name: 'start_percent', type: 'FLOAT', defaultValue: 0.0, min: 0, max: 1),
        NodeInput(name: 'end_percent', type: 'FLOAT', defaultValue: 1.0, min: 0, max: 1),
      ],
      outputs: [
        NodeOutput(name: 'positive', type: 'CONDITIONING'),
        NodeOutput(name: 'negative', type: 'CONDITIONING'),
      ],
    ));

    // ========== LATENT ==========
    _register(NodeDefinition(
      type: 'EmptyLatentImage',
      title: 'Empty Latent',
      category: 'latent',
      color: Colors.pink,
      inputs: [
        NodeInput(name: 'width', type: 'INT', defaultValue: 1024, min: 64, max: 8192),
        NodeInput(name: 'height', type: 'INT', defaultValue: 1024, min: 64, max: 8192),
        NodeInput(name: 'batch_size', type: 'INT', defaultValue: 1, min: 1, max: 100),
      ],
      outputs: [
        NodeOutput(name: 'LATENT', type: 'LATENT'),
      ],
    ));

    _register(NodeDefinition(
      type: 'VAEEncode',
      title: 'VAE Encode',
      category: 'latent',
      color: Colors.pink,
      inputs: [
        NodeInput(name: 'pixels', type: 'IMAGE'),
        NodeInput(name: 'vae', type: 'VAE'),
      ],
      outputs: [
        NodeOutput(name: 'LATENT', type: 'LATENT'),
      ],
    ));

    _register(NodeDefinition(
      type: 'VAEDecode',
      title: 'VAE Decode',
      category: 'latent',
      color: Colors.pink,
      inputs: [
        NodeInput(name: 'samples', type: 'LATENT'),
        NodeInput(name: 'vae', type: 'VAE'),
      ],
      outputs: [
        NodeOutput(name: 'IMAGE', type: 'IMAGE'),
      ],
    ));

    _register(NodeDefinition(
      type: 'SetLatentNoiseMask',
      title: 'Set Latent Noise Mask',
      category: 'latent',
      color: Colors.pink,
      inputs: [
        NodeInput(name: 'samples', type: 'LATENT'),
        NodeInput(name: 'mask', type: 'MASK'),
      ],
      outputs: [
        NodeOutput(name: 'LATENT', type: 'LATENT'),
      ],
    ));

    // ========== SAMPLING ==========
    _register(NodeDefinition(
      type: 'KSampler',
      title: 'KSampler',
      category: 'sampling',
      color: Colors.blue,
      inputs: [
        NodeInput(name: 'model', type: 'MODEL'),
        NodeInput(name: 'positive', type: 'CONDITIONING'),
        NodeInput(name: 'negative', type: 'CONDITIONING'),
        NodeInput(name: 'latent_image', type: 'LATENT'),
        NodeInput(name: 'seed', type: 'INT', defaultValue: -1),
        NodeInput(name: 'steps', type: 'INT', defaultValue: 20, min: 1, max: 150),
        NodeInput(name: 'cfg', type: 'FLOAT', defaultValue: 7.0, min: 0, max: 30),
        NodeInput(name: 'sampler_name', type: 'STRING', options: ['euler', 'euler_ancestral', 'dpmpp_2m', 'dpmpp_sde']),
        NodeInput(name: 'scheduler', type: 'STRING', options: ['normal', 'karras', 'exponential', 'sgm_uniform']),
        NodeInput(name: 'denoise', type: 'FLOAT', defaultValue: 1.0, min: 0, max: 1),
      ],
      outputs: [
        NodeOutput(name: 'LATENT', type: 'LATENT'),
      ],
    ));

    _register(NodeDefinition(
      type: 'KSamplerAdvanced',
      title: 'KSampler Advanced',
      category: 'sampling',
      color: Colors.blue,
      inputs: [
        NodeInput(name: 'model', type: 'MODEL'),
        NodeInput(name: 'positive', type: 'CONDITIONING'),
        NodeInput(name: 'negative', type: 'CONDITIONING'),
        NodeInput(name: 'latent_image', type: 'LATENT'),
        NodeInput(name: 'noise_seed', type: 'INT', defaultValue: -1),
        NodeInput(name: 'steps', type: 'INT', defaultValue: 20, min: 1, max: 150),
        NodeInput(name: 'cfg', type: 'FLOAT', defaultValue: 7.0, min: 0, max: 30),
        NodeInput(name: 'sampler_name', type: 'STRING'),
        NodeInput(name: 'scheduler', type: 'STRING'),
        NodeInput(name: 'start_at_step', type: 'INT', defaultValue: 0, min: 0, max: 150),
        NodeInput(name: 'end_at_step', type: 'INT', defaultValue: 20, min: 0, max: 150),
        NodeInput(name: 'add_noise', type: 'STRING', options: ['enable', 'disable']),
        NodeInput(name: 'return_with_leftover_noise', type: 'STRING', options: ['disable', 'enable']),
      ],
      outputs: [
        NodeOutput(name: 'LATENT', type: 'LATENT'),
      ],
    ));

    // ========== IMAGE ==========
    _register(NodeDefinition(
      type: 'SaveImage',
      title: 'Save Image',
      category: 'image',
      color: Colors.green,
      inputs: [
        NodeInput(name: 'images', type: 'IMAGE'),
        NodeInput(name: 'filename_prefix', type: 'STRING', defaultValue: 'EriUI'),
      ],
      outputs: [],
    ));

    _register(NodeDefinition(
      type: 'PreviewImage',
      title: 'Preview Image',
      category: 'image',
      color: Colors.green,
      inputs: [
        NodeInput(name: 'images', type: 'IMAGE'),
      ],
      outputs: [],
    ));

    _register(NodeDefinition(
      type: 'ImageUpscaleWithModel',
      title: 'Upscale Image',
      category: 'image',
      color: Colors.green,
      inputs: [
        NodeInput(name: 'upscale_model', type: 'UPSCALE_MODEL'),
        NodeInput(name: 'image', type: 'IMAGE'),
      ],
      outputs: [
        NodeOutput(name: 'IMAGE', type: 'IMAGE'),
      ],
    ));

    _register(NodeDefinition(
      type: 'ImageScale',
      title: 'Scale Image',
      category: 'image',
      color: Colors.green,
      inputs: [
        NodeInput(name: 'image', type: 'IMAGE'),
        NodeInput(name: 'upscale_method', type: 'STRING', options: ['nearest-exact', 'bilinear', 'area', 'bicubic', 'lanczos']),
        NodeInput(name: 'width', type: 'INT', defaultValue: 1024, min: 0, max: 16384),
        NodeInput(name: 'height', type: 'INT', defaultValue: 1024, min: 0, max: 16384),
        NodeInput(name: 'crop', type: 'STRING', options: ['disabled', 'center']),
      ],
      outputs: [
        NodeOutput(name: 'IMAGE', type: 'IMAGE'),
      ],
    ));

    // ========== MASK ==========
    _register(NodeDefinition(
      type: 'SolidMask',
      title: 'Solid Mask',
      category: 'mask',
      color: Colors.teal,
      inputs: [
        NodeInput(name: 'value', type: 'FLOAT', defaultValue: 1.0, min: 0, max: 1),
        NodeInput(name: 'width', type: 'INT', defaultValue: 512, min: 1, max: 16384),
        NodeInput(name: 'height', type: 'INT', defaultValue: 512, min: 1, max: 16384),
      ],
      outputs: [
        NodeOutput(name: 'MASK', type: 'MASK'),
      ],
    ));

    _register(NodeDefinition(
      type: 'InvertMask',
      title: 'Invert Mask',
      category: 'mask',
      color: Colors.teal,
      inputs: [
        NodeInput(name: 'mask', type: 'MASK'),
      ],
      outputs: [
        NodeOutput(name: 'MASK', type: 'MASK'),
      ],
    ));
  }

  static void _register(NodeDefinition definition) {
    _definitions[definition.type] = definition;
  }
}
