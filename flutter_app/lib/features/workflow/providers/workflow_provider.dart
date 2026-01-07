import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/workflow_models.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';

/// Workflow editor state
class WorkflowEditorState {
  final Workflow? workflow;
  final String? selectedNodeId;
  final Set<String> selectedNodeIds;
  final WorkflowConnection? pendingConnection;
  final Offset viewOffset;
  final double zoom;
  final bool isDirty;
  final bool isExecuting;
  final String? executionError;
  final Map<String, double> nodeProgress;

  const WorkflowEditorState({
    this.workflow,
    this.selectedNodeId,
    this.selectedNodeIds = const {},
    this.pendingConnection,
    this.viewOffset = Offset.zero,
    this.zoom = 1.0,
    this.isDirty = false,
    this.isExecuting = false,
    this.executionError,
    this.nodeProgress = const {},
  });

  WorkflowEditorState copyWith({
    Workflow? workflow,
    String? selectedNodeId,
    Set<String>? selectedNodeIds,
    WorkflowConnection? pendingConnection,
    Offset? viewOffset,
    double? zoom,
    bool? isDirty,
    bool? isExecuting,
    String? executionError,
    Map<String, double>? nodeProgress,
    bool clearSelectedNode = false,
    bool clearPendingConnection = false,
  }) {
    return WorkflowEditorState(
      workflow: workflow ?? this.workflow,
      selectedNodeId: clearSelectedNode ? null : (selectedNodeId ?? this.selectedNodeId),
      selectedNodeIds: selectedNodeIds ?? this.selectedNodeIds,
      pendingConnection: clearPendingConnection ? null : (pendingConnection ?? this.pendingConnection),
      viewOffset: viewOffset ?? this.viewOffset,
      zoom: zoom ?? this.zoom,
      isDirty: isDirty ?? this.isDirty,
      isExecuting: isExecuting ?? this.isExecuting,
      executionError: executionError,
      nodeProgress: nodeProgress ?? this.nodeProgress,
    );
  }
}

/// Workflow editor notifier
class WorkflowEditorNotifier extends StateNotifier<WorkflowEditorState> {
  final ApiService _apiService;
  final StorageService _storageService;

  WorkflowEditorNotifier(this._apiService, this._storageService)
      : super(const WorkflowEditorState()) {
    // Initialize node definitions
    NodeDefinitions.registerDefaults();
  }

  // ========== WORKFLOW MANAGEMENT ==========

  /// Create a new workflow
  void newWorkflow({String name = 'New Workflow'}) {
    state = state.copyWith(
      workflow: Workflow(
        id: const Uuid().v4(),
        name: name,
      ),
      isDirty: false,
      clearSelectedNode: true,
    );
  }

  /// Load a workflow
  void loadWorkflow(Workflow workflow) {
    state = state.copyWith(
      workflow: workflow,
      isDirty: false,
      clearSelectedNode: true,
    );
  }

  /// Import from ComfyUI JSON
  void importFromComfyUI(String json, {String? name}) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final workflow = Workflow.fromComfyUI(data, name: name);
      loadWorkflow(workflow);
    } catch (e) {
      state = state.copyWith(executionError: 'Failed to import workflow: $e');
    }
  }

  /// Export to ComfyUI JSON
  String? exportToComfyUI() {
    if (state.workflow == null) return null;
    return jsonEncode(state.workflow!.toComfyUI());
  }

  /// Save workflow
  Future<bool> saveWorkflow() async {
    if (state.workflow == null) return false;

    try {
      final workflows = await _loadSavedWorkflows();
      workflows[state.workflow!.id] = state.workflow!;
      await _saveWorkflows(workflows);

      state = state.copyWith(isDirty: false);
      return true;
    } catch (e) {
      state = state.copyWith(executionError: 'Failed to save workflow: $e');
      return false;
    }
  }

  /// Delete workflow
  Future<bool> deleteWorkflow(String id) async {
    try {
      final workflows = await _loadSavedWorkflows();
      workflows.remove(id);
      await _saveWorkflows(workflows);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get list of saved workflows
  Future<List<Workflow>> getSavedWorkflows() async {
    final workflows = await _loadSavedWorkflows();
    return workflows.values.toList()
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
  }

  Future<Map<String, Workflow>> _loadSavedWorkflows() async {
    final json = _storageService.getString('workflows');
    if (json == null) return {};

    final data = jsonDecode(json) as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, Workflow.fromJson(v as Map<String, dynamic>)));
  }

  Future<void> _saveWorkflows(Map<String, Workflow> workflows) async {
    final json = jsonEncode(workflows.map((k, v) => MapEntry(k, v.toJson())));
    await _storageService.setString('workflows', json);
  }

  // ========== NODE MANAGEMENT ==========

  /// Add a node
  void addNode(String type, {Offset? position}) {
    if (state.workflow == null) return;

    final definition = NodeDefinitions.getDefinition(type);
    if (definition == null) return;

    final id = const Uuid().v4().substring(0, 8);
    final node = WorkflowNode(
      id: id,
      type: type,
      title: definition.title,
      position: position ?? _getNextNodePosition(),
      inputValues: _getDefaultInputValues(definition),
    );

    final nodes = Map<String, WorkflowNode>.from(state.workflow!.nodes);
    nodes[id] = node;

    state = state.copyWith(
      workflow: state.workflow!.copyWith(nodes: nodes),
      isDirty: true,
      selectedNodeId: id,
    );
  }

  Offset _getNextNodePosition() {
    if (state.workflow == null || state.workflow!.nodes.isEmpty) {
      return const Offset(100, 100);
    }

    // Find the rightmost node and place new node to its right
    double maxX = 0;
    double avgY = 0;
    for (final node in state.workflow!.nodes.values) {
      if (node.position.dx > maxX) {
        maxX = node.position.dx;
      }
      avgY += node.position.dy;
    }
    avgY /= state.workflow!.nodes.length;

    return Offset(maxX + 250, avgY);
  }

  Map<String, dynamic> _getDefaultInputValues(NodeDefinition definition) {
    final values = <String, dynamic>{};
    for (final input in definition.inputs) {
      if (input.defaultValue != null) {
        values[input.name] = input.defaultValue;
      }
    }
    return values;
  }

  /// Remove a node
  void removeNode(String nodeId) {
    if (state.workflow == null) return;

    final nodes = Map<String, WorkflowNode>.from(state.workflow!.nodes);
    nodes.remove(nodeId);

    // Remove connections to/from this node
    final connections = state.workflow!.connections
        .where((c) => c.sourceNodeId != nodeId && c.targetNodeId != nodeId)
        .toList();

    state = state.copyWith(
      workflow: state.workflow!.copyWith(nodes: nodes, connections: connections),
      isDirty: true,
      clearSelectedNode: state.selectedNodeId == nodeId,
    );
  }

  /// Update node position
  void updateNodePosition(String nodeId, Offset position) {
    if (state.workflow == null) return;

    final nodes = Map<String, WorkflowNode>.from(state.workflow!.nodes);
    final node = nodes[nodeId];
    if (node == null) return;

    nodes[nodeId] = node.copyWith(position: position);

    state = state.copyWith(
      workflow: state.workflow!.copyWith(nodes: nodes),
      isDirty: true,
    );
  }

  /// Update node input value
  void updateNodeInput(String nodeId, String inputName, dynamic value) {
    if (state.workflow == null) return;

    final nodes = Map<String, WorkflowNode>.from(state.workflow!.nodes);
    final node = nodes[nodeId];
    if (node == null) return;

    final inputValues = Map<String, dynamic>.from(node.inputValues);
    inputValues[inputName] = value;

    nodes[nodeId] = node.copyWith(inputValues: inputValues);

    state = state.copyWith(
      workflow: state.workflow!.copyWith(nodes: nodes),
      isDirty: true,
    );
  }

  /// Select a node
  void selectNode(String? nodeId) {
    if (nodeId == null) {
      state = state.copyWith(clearSelectedNode: true);
    } else {
      state = state.copyWith(selectedNodeId: nodeId);
    }
  }

  /// Toggle node collapse state
  void toggleNodeCollapse(String nodeId) {
    if (state.workflow == null) return;

    final nodes = Map<String, WorkflowNode>.from(state.workflow!.nodes);
    final node = nodes[nodeId];
    if (node == null) return;

    nodes[nodeId] = node.copyWith(isCollapsed: !node.isCollapsed);

    state = state.copyWith(
      workflow: state.workflow!.copyWith(nodes: nodes),
    );
  }

  // ========== CONNECTION MANAGEMENT ==========

  /// Start creating a connection
  void startConnection(String sourceNodeId, int sourceOutput) {
    state = state.copyWith(
      pendingConnection: WorkflowConnection(
        id: 'pending',
        sourceNodeId: sourceNodeId,
        sourceOutput: sourceOutput,
        targetNodeId: '',
        targetInput: '',
      ),
    );
  }

  /// Complete a connection
  void completeConnection(String targetNodeId, String targetInput) {
    if (state.workflow == null || state.pendingConnection == null) return;

    // Validate connection
    final sourceNode = state.workflow!.nodes[state.pendingConnection!.sourceNodeId];
    final targetNode = state.workflow!.nodes[targetNodeId];
    if (sourceNode == null || targetNode == null) {
      state = state.copyWith(clearPendingConnection: true);
      return;
    }

    // Check if connection already exists
    final existingConnection = state.workflow!.connections.any(
      (c) => c.targetNodeId == targetNodeId && c.targetInput == targetInput,
    );
    if (existingConnection) {
      // Remove existing connection first
      removeConnectionToInput(targetNodeId, targetInput);
    }

    // Create connection
    final connection = WorkflowConnection(
      id: const Uuid().v4().substring(0, 8),
      sourceNodeId: state.pendingConnection!.sourceNodeId,
      sourceOutput: state.pendingConnection!.sourceOutput,
      targetNodeId: targetNodeId,
      targetInput: targetInput,
    );

    final connections = List<WorkflowConnection>.from(state.workflow!.connections);
    connections.add(connection);

    state = state.copyWith(
      workflow: state.workflow!.copyWith(connections: connections),
      isDirty: true,
      clearPendingConnection: true,
    );
  }

  /// Cancel pending connection
  void cancelConnection() {
    state = state.copyWith(clearPendingConnection: true);
  }

  /// Remove a connection
  void removeConnection(String connectionId) {
    if (state.workflow == null) return;

    final connections = state.workflow!.connections
        .where((c) => c.id != connectionId)
        .toList();

    state = state.copyWith(
      workflow: state.workflow!.copyWith(connections: connections),
      isDirty: true,
    );
  }

  /// Remove connection to an input
  void removeConnectionToInput(String nodeId, String inputName) {
    if (state.workflow == null) return;

    final connections = state.workflow!.connections
        .where((c) => !(c.targetNodeId == nodeId && c.targetInput == inputName))
        .toList();

    state = state.copyWith(
      workflow: state.workflow!.copyWith(connections: connections),
      isDirty: true,
    );
  }

  // ========== VIEW MANAGEMENT ==========

  /// Update view offset (pan)
  void updateViewOffset(Offset offset) {
    state = state.copyWith(viewOffset: offset);
  }

  /// Update zoom level
  void updateZoom(double zoom) {
    state = state.copyWith(zoom: zoom.clamp(0.25, 2.0));
  }

  /// Reset view
  void resetView() {
    state = state.copyWith(viewOffset: Offset.zero, zoom: 1.0);
  }

  /// Fit workflow in view
  void fitInView(Size viewSize) {
    if (state.workflow == null || state.workflow!.nodes.isEmpty) return;

    // Calculate bounding box
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final node in state.workflow!.nodes.values) {
      minX = node.position.dx < minX ? node.position.dx : minX;
      minY = node.position.dy < minY ? node.position.dy : minY;
      maxX = (node.position.dx + node.size.width) > maxX
          ? (node.position.dx + node.size.width)
          : maxX;
      maxY = (node.position.dy + node.size.height) > maxY
          ? (node.position.dy + node.size.height)
          : maxY;
    }

    final width = maxX - minX + 100;
    final height = maxY - minY + 100;

    final zoomX = viewSize.width / width;
    final zoomY = viewSize.height / height;
    final zoom = (zoomX < zoomY ? zoomX : zoomY).clamp(0.25, 1.0);

    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;

    state = state.copyWith(
      viewOffset: Offset(
        viewSize.width / 2 - centerX * zoom,
        viewSize.height / 2 - centerY * zoom,
      ),
      zoom: zoom,
    );
  }

  // ========== EXECUTION ==========

  /// Execute workflow
  Future<void> executeWorkflow() async {
    if (state.workflow == null) return;

    state = state.copyWith(
      isExecuting: true,
      executionError: null,
      nodeProgress: {},
    );

    try {
      final comfyWorkflow = state.workflow!.toComfyUI();

      // Queue on backend
      final response = await _apiService.post('/api/GenerateText2Image', data: {
        'workflow': comfyWorkflow,
      });

      if (!response.isSuccess) {
        throw Exception(response.error ?? 'Unknown error');
      }

      // Start polling for progress
      // In a real implementation, this would use WebSocket
      state = state.copyWith(isExecuting: false);
    } catch (e) {
      state = state.copyWith(
        isExecuting: false,
        executionError: e.toString(),
      );
    }
  }

  /// Cancel execution
  Future<void> cancelExecution() async {
    try {
      await _apiService.post('/api/InterruptGeneration', data: {});
      state = state.copyWith(isExecuting: false);
    } catch (e) {
      // Ignore
    }
  }

  /// Update node progress
  void updateNodeProgress(String nodeId, double progress) {
    final nodeProgress = Map<String, double>.from(state.nodeProgress);
    nodeProgress[nodeId] = progress;
    state = state.copyWith(nodeProgress: nodeProgress);
  }
}

/// Provider for workflow editor
final workflowEditorProvider = StateNotifierProvider<WorkflowEditorNotifier, WorkflowEditorState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return WorkflowEditorNotifier(apiService, storageService);
});
