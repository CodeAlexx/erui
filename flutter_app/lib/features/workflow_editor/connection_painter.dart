import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../workflow/models/workflow_models.dart';
import 'workflow_node_widget.dart';

/// Custom painter for drawing connections between nodes
///
/// Features:
/// - Bezier curves between output and input slots
/// - Color-coded by data type
/// - Highlight on hover (future)
/// - In-progress connection preview during drag
class ConnectionPainter extends CustomPainter {
  /// List of existing connections
  final List<WorkflowConnection> connections;

  /// Map of all nodes
  final Map<String, WorkflowNode> nodes;

  /// Pending connection being drawn
  final WorkflowConnection? pendingConnection;

  /// End position of pending connection (mouse position)
  final Offset? pendingEnd;

  /// Color scheme for theming
  final ColorScheme colorScheme;

  /// Hovered connection ID (for highlighting)
  final String? hoveredConnectionId;

  ConnectionPainter({
    required this.connections,
    required this.nodes,
    this.pendingConnection,
    this.pendingEnd,
    required this.colorScheme,
    this.hoveredConnectionId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw existing connections
    for (final connection in connections) {
      _drawConnection(canvas, connection);
    }

    // Draw pending connection
    if (pendingConnection != null && pendingEnd != null) {
      _drawPendingConnection(canvas);
    }
  }

  void _drawConnection(Canvas canvas, WorkflowConnection connection) {
    final sourceNode = nodes[connection.sourceNodeId];
    final targetNode = nodes[connection.targetNodeId];

    if (sourceNode == null || targetNode == null) return;

    final sourceDefinition = NodeDefinitions.getDefinition(sourceNode.type);
    final targetDefinition = NodeDefinitions.getDefinition(targetNode.type);

    // Get output position
    final outputPosition = _getOutputPosition(sourceNode, connection.sourceOutput);

    // Get input position
    final inputPosition = _getInputPosition(
      targetNode,
      connection.targetInput,
      targetDefinition,
    );

    // Determine data type from output
    String dataType = 'UNKNOWN';
    if (sourceDefinition != null && connection.sourceOutput < sourceDefinition.outputs.length) {
      dataType = sourceDefinition.outputs[connection.sourceOutput].type;
    }

    final isHovered = connection.id == hoveredConnectionId;

    // Draw the bezier curve
    _drawBezierCurve(
      canvas,
      outputPosition,
      inputPosition,
      dataType,
      isHovered: isHovered,
    );
  }

  void _drawPendingConnection(Canvas canvas) {
    final sourceNode = nodes[pendingConnection!.sourceNodeId];
    if (sourceNode == null || pendingEnd == null) return;

    final sourceDefinition = NodeDefinitions.getDefinition(sourceNode.type);
    final outputPosition = _getOutputPosition(sourceNode, pendingConnection!.sourceOutput);

    // Determine data type
    String dataType = 'UNKNOWN';
    if (sourceDefinition != null && pendingConnection!.sourceOutput < sourceDefinition.outputs.length) {
      dataType = sourceDefinition.outputs[pendingConnection!.sourceOutput].type;
    }

    // Draw with semi-transparent styling
    _drawBezierCurve(
      canvas,
      outputPosition,
      pendingEnd!,
      dataType,
      isPending: true,
    );
  }

  void _drawBezierCurve(
    Canvas canvas,
    Offset start,
    Offset end,
    String dataType, {
    bool isHovered = false,
    bool isPending = false,
  }) {
    final color = getDataTypeColor(dataType);
    final alpha = isPending ? 0.6 : 1.0;
    final strokeWidth = isHovered ? 4.0 : 3.0;

    // Main line paint
    final linePaint = Paint()
      ..color = color.withOpacity(alpha)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Glow effect for active connections
    if (isHovered) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..strokeWidth = strokeWidth + 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      final glowPath = _createBezierPath(start, end);
      canvas.drawPath(glowPath, glowPaint);
    }

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..strokeWidth = strokeWidth + 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final shadowPath = _createBezierPath(
      Offset(start.dx, start.dy + 2),
      Offset(end.dx, end.dy + 2),
    );
    canvas.drawPath(shadowPath, shadowPaint);

    // Draw main line
    final path = _createBezierPath(start, end);
    canvas.drawPath(path, linePaint);

    // Draw flow indicators (animated dots along the line)
    if (!isPending) {
      _drawFlowIndicators(canvas, path, color, alpha);
    }

    // Draw connection endpoints
    _drawEndpoint(canvas, start, color, alpha, isOutput: true);
    _drawEndpoint(canvas, end, color, alpha, isOutput: false);
  }

  Path _createBezierPath(Offset start, Offset end) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Calculate control points for smooth bezier curve
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    // Adaptive control distance based on horizontal distance
    final controlDistance = (dx.abs() / 2).clamp(50.0, 200.0);

    // If going backwards (right to left), use different curve
    if (dx < 0) {
      // S-curve for backward connections
      final midY = (start.dy + end.dy) / 2;
      path.cubicTo(
        start.dx + controlDistance,
        start.dy,
        start.dx + controlDistance,
        midY,
        (start.dx + end.dx) / 2,
        midY,
      );
      path.cubicTo(
        end.dx - controlDistance,
        midY,
        end.dx - controlDistance,
        end.dy,
        end.dx,
        end.dy,
      );
    } else {
      // Standard horizontal bezier for forward connections
      path.cubicTo(
        start.dx + controlDistance,
        start.dy,
        end.dx - controlDistance,
        end.dy,
        end.dx,
        end.dy,
      );
    }

    return path;
  }

  void _drawFlowIndicators(Canvas canvas, Path path, Color color, double alpha) {
    // Get points along the path for flow indicators
    final metrics = path.computeMetrics().first;
    final pathLength = metrics.length;

    // Draw 2-3 dots along the path
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(alpha * 0.8)
      ..style = PaintingStyle.fill;

    final dotCount = 3;
    for (var i = 0; i < dotCount; i++) {
      final t = (i + 1) / (dotCount + 1);
      final tangent = metrics.getTangentForOffset(pathLength * t);
      if (tangent != null) {
        canvas.drawCircle(tangent.position, 2.5, dotPaint);
      }
    }
  }

  void _drawEndpoint(
    Canvas canvas,
    Offset position,
    Color color,
    double alpha, {
    required bool isOutput,
  }) {
    // Outer ring
    final ringPaint = Paint()
      ..color = color.withOpacity(alpha)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(position, 6, ringPaint);

    // Inner dot
    final dotPaint = Paint()
      ..color = color.withOpacity(alpha)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(position, 3, dotPaint);
  }

  Offset _getOutputPosition(WorkflowNode node, int outputIndex) {
    // Output slots are on the right side of the node
    // Each slot is positioned below the header and any inputs
    final definition = NodeDefinitions.getDefinition(node.type);
    final inputCount = definition?.inputs.length ?? 0;

    // Header height (approx 36px) + inputs (approx 24px each) + some padding
    const headerHeight = 36.0;
    const slotHeight = 24.0;
    const dividerHeight = 8.0;

    final baseY = headerHeight + (inputCount * slotHeight) + dividerHeight;

    return Offset(
      node.position.dx + node.size.width,
      node.position.dy + baseY + (outputIndex * slotHeight) + (slotHeight / 2),
    );
  }

  Offset _getInputPosition(
    WorkflowNode node,
    String inputName,
    NodeDefinition? definition,
  ) {
    if (definition == null) {
      return Offset(node.position.dx, node.position.dy + 50);
    }

    final inputIndex = definition.inputs.indexWhere((i) => i.name == inputName);
    if (inputIndex < 0) {
      return Offset(node.position.dx, node.position.dy + 50);
    }

    // Input slots are on the left side
    const headerHeight = 36.0;
    const slotHeight = 24.0;

    return Offset(
      node.position.dx,
      node.position.dy + headerHeight + (inputIndex * slotHeight) + (slotHeight / 2),
    );
  }

  @override
  bool shouldRepaint(covariant ConnectionPainter oldDelegate) {
    return connections != oldDelegate.connections ||
        nodes != oldDelegate.nodes ||
        pendingConnection != oldDelegate.pendingConnection ||
        pendingEnd != oldDelegate.pendingEnd ||
        hoveredConnectionId != oldDelegate.hoveredConnectionId;
  }
}

/// Animated connection painter for showing data flow
class AnimatedConnectionPainter extends CustomPainter {
  final List<WorkflowConnection> connections;
  final Map<String, WorkflowNode> nodes;
  final ColorScheme colorScheme;
  final double animationValue; // 0.0 to 1.0 for animation

  AnimatedConnectionPainter({
    required this.connections,
    required this.nodes,
    required this.colorScheme,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final connection in connections) {
      _drawAnimatedConnection(canvas, connection);
    }
  }

  void _drawAnimatedConnection(Canvas canvas, WorkflowConnection connection) {
    final sourceNode = nodes[connection.sourceNodeId];
    final targetNode = nodes[connection.targetNodeId];

    if (sourceNode == null || targetNode == null) return;

    final sourceDefinition = NodeDefinitions.getDefinition(sourceNode.type);
    final targetDefinition = NodeDefinitions.getDefinition(targetNode.type);

    // Get positions
    final start = _getOutputPosition(sourceNode, connection.sourceOutput);
    final end = _getInputPosition(targetNode, connection.targetInput, targetDefinition);

    // Get data type color
    String dataType = 'UNKNOWN';
    if (sourceDefinition != null && connection.sourceOutput < sourceDefinition.outputs.length) {
      dataType = sourceDefinition.outputs[connection.sourceOutput].type;
    }
    final color = getDataTypeColor(dataType);

    // Create path
    final path = _createBezierPath(start, end);

    // Draw base line
    final basePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, basePaint);

    // Draw animated segment
    final metrics = path.computeMetrics().first;
    final pathLength = metrics.length;

    final segmentLength = pathLength * 0.2; // 20% of path
    final startOffset = (animationValue * pathLength) % pathLength;
    final endOffset = math.min(startOffset + segmentLength, pathLength);

    final extractedPath = metrics.extractPath(startOffset, endOffset);

    final animPaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(extractedPath, animPaint);
  }

  Path _createBezierPath(Offset start, Offset end) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    final dx = end.dx - start.dx;
    final controlDistance = (dx.abs() / 2).clamp(50.0, 200.0);

    if (dx < 0) {
      final midY = (start.dy + end.dy) / 2;
      path.cubicTo(
        start.dx + controlDistance,
        start.dy,
        start.dx + controlDistance,
        midY,
        (start.dx + end.dx) / 2,
        midY,
      );
      path.cubicTo(
        end.dx - controlDistance,
        midY,
        end.dx - controlDistance,
        end.dy,
        end.dx,
        end.dy,
      );
    } else {
      path.cubicTo(
        start.dx + controlDistance,
        start.dy,
        end.dx - controlDistance,
        end.dy,
        end.dx,
        end.dy,
      );
    }

    return path;
  }

  Offset _getOutputPosition(WorkflowNode node, int outputIndex) {
    final definition = NodeDefinitions.getDefinition(node.type);
    final inputCount = definition?.inputs.length ?? 0;

    const headerHeight = 36.0;
    const slotHeight = 24.0;
    const dividerHeight = 8.0;

    final baseY = headerHeight + (inputCount * slotHeight) + dividerHeight;

    return Offset(
      node.position.dx + node.size.width,
      node.position.dy + baseY + (outputIndex * slotHeight) + (slotHeight / 2),
    );
  }

  Offset _getInputPosition(
    WorkflowNode node,
    String inputName,
    NodeDefinition? definition,
  ) {
    if (definition == null) {
      return Offset(node.position.dx, node.position.dy + 50);
    }

    final inputIndex = definition.inputs.indexWhere((i) => i.name == inputName);
    if (inputIndex < 0) {
      return Offset(node.position.dx, node.position.dy + 50);
    }

    const headerHeight = 36.0;
    const slotHeight = 24.0;

    return Offset(
      node.position.dx,
      node.position.dy + headerHeight + (inputIndex * slotHeight) + (slotHeight / 2),
    );
  }

  @override
  bool shouldRepaint(covariant AnimatedConnectionPainter oldDelegate) {
    return connections != oldDelegate.connections ||
        nodes != oldDelegate.nodes ||
        animationValue != oldDelegate.animationValue;
  }
}

/// Helper class for hit testing connections
class ConnectionHitTester {
  static const double _hitTolerance = 10.0;

  /// Test if a point is near a connection line
  static String? hitTest(
    Offset point,
    List<WorkflowConnection> connections,
    Map<String, WorkflowNode> nodes,
  ) {
    for (final connection in connections) {
      final sourceNode = nodes[connection.sourceNodeId];
      final targetNode = nodes[connection.targetNodeId];

      if (sourceNode == null || targetNode == null) continue;

      final targetDefinition = NodeDefinitions.getDefinition(targetNode.type);
      final sourceDefinition = NodeDefinitions.getDefinition(sourceNode.type);

      // Get positions
      final start = _getOutputPosition(sourceNode, connection.sourceOutput, sourceDefinition);
      final end = _getInputPosition(targetNode, connection.targetInput, targetDefinition);

      // Sample points along the bezier curve and check distance
      final path = _createBezierPath(start, end);
      final metrics = path.computeMetrics().first;
      final pathLength = metrics.length;

      // Sample every 10 pixels
      for (double d = 0; d < pathLength; d += 10) {
        final tangent = metrics.getTangentForOffset(d);
        if (tangent != null) {
          final distance = (point - tangent.position).distance;
          if (distance < _hitTolerance) {
            return connection.id;
          }
        }
      }
    }

    return null;
  }

  static Path _createBezierPath(Offset start, Offset end) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    final dx = end.dx - start.dx;
    final controlDistance = (dx.abs() / 2).clamp(50.0, 200.0);

    if (dx < 0) {
      final midY = (start.dy + end.dy) / 2;
      path.cubicTo(
        start.dx + controlDistance,
        start.dy,
        start.dx + controlDistance,
        midY,
        (start.dx + end.dx) / 2,
        midY,
      );
      path.cubicTo(
        end.dx - controlDistance,
        midY,
        end.dx - controlDistance,
        end.dy,
        end.dx,
        end.dy,
      );
    } else {
      path.cubicTo(
        start.dx + controlDistance,
        start.dy,
        end.dx - controlDistance,
        end.dy,
        end.dx,
        end.dy,
      );
    }

    return path;
  }

  static Offset _getOutputPosition(
    WorkflowNode node,
    int outputIndex,
    NodeDefinition? definition,
  ) {
    final inputCount = definition?.inputs.length ?? 0;

    const headerHeight = 36.0;
    const slotHeight = 24.0;
    const dividerHeight = 8.0;

    final baseY = headerHeight + (inputCount * slotHeight) + dividerHeight;

    return Offset(
      node.position.dx + node.size.width,
      node.position.dy + baseY + (outputIndex * slotHeight) + (slotHeight / 2),
    );
  }

  static Offset _getInputPosition(
    WorkflowNode node,
    String inputName,
    NodeDefinition? definition,
  ) {
    if (definition == null) {
      return Offset(node.position.dx, node.position.dy + 50);
    }

    final inputIndex = definition.inputs.indexWhere((i) => i.name == inputName);
    if (inputIndex < 0) {
      return Offset(node.position.dx, node.position.dy + 50);
    }

    const headerHeight = 36.0;
    const slotHeight = 24.0;

    return Offset(
      node.position.dx,
      node.position.dy + headerHeight + (inputIndex * slotHeight) + (slotHeight / 2),
    );
  }
}
