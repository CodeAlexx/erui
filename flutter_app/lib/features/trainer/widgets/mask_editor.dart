import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// MaskEditor - Full-featured inpainting mask editor
/// Ported from React MaskEditor.tsx
///
/// Features:
/// - Brush tool with adjustable size
/// - Eraser tool
/// - Lasso/polygon selection
/// - SAM2 click-to-segment (TODO: API integration)
/// - Clear/invert mask
class MaskEditor extends StatefulWidget {
  final Uint8List? imageData;
  final String? imageUrl;
  final Uint8List? initialMask;
  final Function(Uint8List?) onMaskChange;
  final VoidCallback onClose;
  final double width;
  final double height;

  const MaskEditor({
    super.key,
    this.imageData,
    this.imageUrl,
    this.initialMask,
    required this.onMaskChange,
    required this.onClose,
    this.width = 800,
    this.height = 600,
  });

  @override
  State<MaskEditor> createState() => _MaskEditorState();
}

enum MaskTool { brush, eraser, lasso, sam2, sam2Exclude }

class _MaskEditorState extends State<MaskEditor> {
  MaskTool _tool = MaskTool.brush;
  double _brushSize = 30;
  List<Offset> _currentStroke = [];
  List<List<Offset>> _strokes = [];
  List<MaskTool> _strokeTools = [];
  List<double> _strokeSizes = [];
  List<Offset> _lassoPoints = [];
  List<_Sam2Point> _sam2Points = [];
  bool _isDrawing = false;
  bool _isLoadingSam2 = false;
  ui.Image? _backgroundImage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    // Load image from URL or data
    if (widget.imageUrl != null) {
      // TODO: Load from network
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Dialog(
      backgroundColor: scaffoldBg,
      child: Container(
        width: widget.width,
        height: widget.height + 100,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 12),

            // Toolbar
            _buildToolbar(),
            const SizedBox(height: 12),

            // Canvas area
            Expanded(
              child: _buildCanvas(),
            ),

            const SizedBox(height: 12),

            // Bottom actions
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.brush, color: Colors.purple),
        const SizedBox(width: 8),
        const Text(
          'Mask Editor',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          onPressed: widget.onClose,
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Tool buttons
          _buildToolButton(MaskTool.brush, Icons.brush, 'Brush'),
          _buildToolButton(MaskTool.eraser, Icons.auto_fix_off, 'Eraser'),
          _buildToolButton(MaskTool.lasso, Icons.gesture, 'Lasso'),
          _buildToolButton(MaskTool.sam2, Icons.auto_awesome, 'SAM2 Include'),
          _buildToolButton(MaskTool.sam2Exclude, Icons.block, 'SAM2 Exclude'),

          const SizedBox(width: 16),
          Container(width: 1, height: 24, color: Colors.grey[700]),
          const SizedBox(width: 16),

          // Brush size slider
          const Text('Size:', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Slider(
              value: _brushSize,
              min: 5,
              max: 100,
              onChanged: (v) => setState(() => _brushSize = v),
              activeColor: Colors.purple,
            ),
          ),
          Text(
            '${_brushSize.toInt()}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),

          const Spacer(),

          // Action buttons
          TextButton.icon(
            onPressed: _clearMask,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Clear'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
          TextButton.icon(
            onPressed: _invertMask,
            icon: const Icon(Icons.invert_colors, size: 16),
            label: const Text('Invert'),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(MaskTool tool, IconData icon, String tooltip) {
    final isSelected = _tool == tool;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _tool = tool),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.purple.withOpacity(0.3) : null,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? Colors.purple : Colors.transparent,
            ),
          ),
          child: Icon(icon, color: isSelected ? Colors.purple : Colors.grey, size: 20),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onTapDown: _onTapDown,
          child: CustomPaint(
            painter: _MaskPainter(
              strokes: _strokes,
              strokeTools: _strokeTools,
              strokeSizes: _strokeSizes,
              currentStroke: _currentStroke,
              currentTool: _tool,
              brushSize: _brushSize,
              lassoPoints: _lassoPoints,
              sam2Points: _sam2Points,
            ),
            size: Size(widget.width - 32, widget.height - 160),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: widget.onClose,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _applyMask,
          icon: const Icon(Icons.check),
          label: const Text('Apply Mask'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (_tool == MaskTool.brush || _tool == MaskTool.eraser) {
      setState(() {
        _isDrawing = true;
        _currentStroke = [details.localPosition];
      });
    } else if (_tool == MaskTool.lasso) {
      setState(() {
        _lassoPoints = [details.localPosition];
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_tool == MaskTool.brush || _tool == MaskTool.eraser) {
      if (_isDrawing) {
        setState(() {
          _currentStroke = [..._currentStroke, details.localPosition];
        });
      }
    } else if (_tool == MaskTool.lasso) {
      setState(() {
        _lassoPoints = [..._lassoPoints, details.localPosition];
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_tool == MaskTool.brush || _tool == MaskTool.eraser) {
      if (_currentStroke.isNotEmpty) {
        setState(() {
          _strokes = [..._strokes, _currentStroke];
          _strokeTools = [..._strokeTools, _tool];
          _strokeSizes = [..._strokeSizes, _brushSize];
          _currentStroke = [];
          _isDrawing = false;
        });
      }
    } else if (_tool == MaskTool.lasso) {
      // Close the lasso and fill
      if (_lassoPoints.length > 2) {
        setState(() {
          _strokes = [..._strokes, _lassoPoints];
          _strokeTools = [..._strokeTools, MaskTool.lasso];
          _strokeSizes = [..._strokeSizes, 0];
          _lassoPoints = [];
        });
      }
    }
  }

  void _onTapDown(TapDownDetails details) {
    if (_tool == MaskTool.sam2 || _tool == MaskTool.sam2Exclude) {
      final label = _tool == MaskTool.sam2 ? 1 : 0;
      setState(() {
        _sam2Points = [..._sam2Points, _Sam2Point(details.localPosition, label)];
      });
      // TODO: Call SAM2 API
    }
  }

  void _clearMask() {
    setState(() {
      _strokes = [];
      _strokeTools = [];
      _strokeSizes = [];
      _currentStroke = [];
      _lassoPoints = [];
      _sam2Points = [];
    });
  }

  void _invertMask() {
    // TODO: Implement mask inversion
  }

  void _applyMask() {
    // TODO: Generate mask image and call onMaskChange
    widget.onMaskChange(null);
    widget.onClose();
  }
}

class _Sam2Point {
  final Offset point;
  final int label;
  _Sam2Point(this.point, this.label);
}

class _MaskPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<MaskTool> strokeTools;
  final List<double> strokeSizes;
  final List<Offset> currentStroke;
  final MaskTool currentTool;
  final double brushSize;
  final List<Offset> lassoPoints;
  final List<_Sam2Point> sam2Points;

  _MaskPainter({
    required this.strokes,
    required this.strokeTools,
    required this.strokeSizes,
    required this.currentStroke,
    required this.currentTool,
    required this.brushSize,
    required this.lassoPoints,
    required this.sam2Points,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background (placeholder)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF2a2a3e),
    );

    // Draw existing strokes
    for (int i = 0; i < strokes.length; i++) {
      final stroke = strokes[i];
      final tool = strokeTools[i];
      final strokeSize = strokeSizes[i];

      if (tool == MaskTool.lasso) {
        // Fill lasso area
        final path = Path()..addPolygon(stroke, true);
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.red.withOpacity(0.5)
            ..style = PaintingStyle.fill,
        );
      } else {
        // Draw brush/eraser stroke
        final paint = Paint()
          ..color = tool == MaskTool.eraser
              ? const Color(0xFF2a2a3e)
              : Colors.red.withOpacity(0.5)
          ..strokeWidth = strokeSize
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        if (stroke.length > 1) {
          final path = Path()..moveTo(stroke[0].dx, stroke[0].dy);
          for (int j = 1; j < stroke.length; j++) {
            path.lineTo(stroke[j].dx, stroke[j].dy);
          }
          canvas.drawPath(path, paint);
        }
      }
    }

    // Draw current stroke
    if (currentStroke.isNotEmpty) {
      final paint = Paint()
        ..color = currentTool == MaskTool.eraser
            ? const Color(0xFF2a2a3e)
            : Colors.red.withOpacity(0.5)
        ..strokeWidth = brushSize
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (currentStroke.length > 1) {
        final path = Path()..moveTo(currentStroke[0].dx, currentStroke[0].dy);
        for (int j = 1; j < currentStroke.length; j++) {
          path.lineTo(currentStroke[j].dx, currentStroke[j].dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    // Draw lasso points
    if (lassoPoints.isNotEmpty) {
      final paint = Paint()
        ..color = Colors.green
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(lassoPoints[0].dx, lassoPoints[0].dy);
      for (int i = 1; i < lassoPoints.length; i++) {
        path.lineTo(lassoPoints[i].dx, lassoPoints[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // Draw SAM2 points
    for (final sam2Point in sam2Points) {
      canvas.drawCircle(
        sam2Point.point,
        8,
        Paint()..color = sam2Point.label == 1 ? Colors.green : Colors.red,
      );
      canvas.drawCircle(
        sam2Point.point,
        8,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Draw helper text
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Draw on image to create mask',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, size.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _MaskPainter oldDelegate) => true;
}
