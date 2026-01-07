import 'package:flutter/material.dart';

/// VideoEditor - Pro Timeline Video Editor
/// Ported from React VideoEditor.tsx
///
/// Features:
/// - Multi-track timeline (video, audio, image, text)
/// - Clip trimming and positioning
/// - Effects (brightness, contrast, blur, etc.)
/// - Transitions
/// - Export to video
class VideoEditor extends StatefulWidget {
  final VoidCallback? onClose;

  const VideoEditor({super.key, this.onClose});

  @override
  State<VideoEditor> createState() => _VideoEditorState();
}

// Types
class Track {
  final String id;
  final String name;
  final TrackType type;
  int order;
  bool muted;
  bool locked;
  bool visible;
  double height;

  Track({
    required this.id,
    required this.name,
    required this.type,
    required this.order,
    this.muted = false,
    this.locked = false,
    this.visible = true,
    this.height = 60,
  });
}

enum TrackType { video, audio }

class Clip {
  final String id;
  final ClipType type;
  final String name;
  final String sourcePath;
  final String mediaId;
  String trackId;
  // Trim points
  double sourceIn;
  double sourceOut;
  // Timeline
  double startTime;
  double duration;
  double get endTime => startTime + duration;
  // Transform
  double positionX;
  double positionY;
  double scale;
  double rotation;
  double opacity;
  // Effects
  List<Effect> effects;
  Transition? transitionIn;
  Transition? transitionOut;
  // Audio
  double volume;
  bool muted;
  // Text
  String? textContent;
  String? fontFamily;
  double? fontSize;
  Color? fontColor;
  // Color
  Color? color;

  Clip({
    required this.id,
    required this.type,
    required this.name,
    required this.sourcePath,
    required this.mediaId,
    required this.trackId,
    this.sourceIn = 0,
    this.sourceOut = 0,
    required this.startTime,
    required this.duration,
    this.positionX = 0,
    this.positionY = 0,
    this.scale = 1,
    this.rotation = 0,
    this.opacity = 1,
    this.effects = const [],
    this.transitionIn,
    this.transitionOut,
    this.volume = 1,
    this.muted = false,
    this.textContent,
    this.fontFamily,
    this.fontSize,
    this.fontColor,
    this.color,
  });
}

enum ClipType { video, audio, image, text, color }

class Effect {
  final String id;
  final String type;
  bool enabled;
  Map<String, dynamic> params;

  Effect({
    required this.id,
    required this.type,
    this.enabled = true,
    this.params = const {},
  });
}

class Transition {
  final String type;
  final double duration;

  Transition({required this.type, required this.duration});
}

class Project {
  final String id;
  String name;
  int width;
  int height;
  double fps;
  double duration;
  List<Track> tracks;
  List<Clip> clips;

  Project({
    required this.id,
    this.name = 'Untitled Project',
    this.width = 1920,
    this.height = 1080,
    this.fps = 24,
    this.duration = 60,
    this.tracks = const [],
    this.clips = const [],
  });
}

// Available effects
final List<Map<String, dynamic>> availableEffects = [
  {'type': 'brightness', 'name': 'Brightness', 'category': 'color', 'defaultParams': {'value': 0}},
  {'type': 'contrast', 'name': 'Contrast', 'category': 'color', 'defaultParams': {'value': 1}},
  {'type': 'saturation', 'name': 'Saturation', 'category': 'color', 'defaultParams': {'value': 1}},
  {'type': 'hue', 'name': 'Hue Shift', 'category': 'color', 'defaultParams': {'value': 0}},
  {'type': 'blur', 'name': 'Blur', 'category': 'stylize', 'defaultParams': {'radius': 5}},
  {'type': 'sharpen', 'name': 'Sharpen', 'category': 'stylize', 'defaultParams': {'amount': 1}},
  {'type': 'denoise', 'name': 'Denoise', 'category': 'stylize', 'defaultParams': {'strength': 4}},
  {'type': 'vignette', 'name': 'Vignette', 'category': 'stylize', 'defaultParams': {'amount': 0.3}},
  {'type': 'speed', 'name': 'Speed', 'category': 'utility', 'defaultParams': {'rate': 1}},
  {'type': 'chromakey', 'name': 'Green Screen', 'category': 'utility', 'defaultParams': {'color': '#00FF00', 'similarity': 0.3}},
];

class _VideoEditorState extends State<VideoEditor> {
  // Project state
  Project? _project;
  List<Track> _tracks = [];
  List<Clip> _clips = [];

  // Playback state
  bool _isPlaying = false;
  double _currentTime = 0;
  double _duration = 60;
  bool _isMuted = false;
  double _volume = 1;

  // Timeline state
  double _zoom = 1;
  double _scrollOffset = 0;
  bool _snapEnabled = true;

  // Selection
  String? _selectedClipId;
  String? _selectedTrackId;

  // Panels
  bool _showMediaBrowser = true;
  bool _showInspector = true;

  // History
  final List<String> _history = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    _initProject();
  }

  void _initProject() {
    _project = Project(
      id: 'project_${DateTime.now().millisecondsSinceEpoch}',
      name: 'New Project',
    );
    _tracks = [
      Track(id: 'track_1', name: 'Video 1', type: TrackType.video, order: 0),
      Track(id: 'track_2', name: 'Audio 1', type: TrackType.audio, order: 1),
    ];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Column(
        children: [
          // Top toolbar
          _buildToolbar(),

          // Main area (preview + panels)
          Expanded(
            child: Row(
              children: [
                // Media browser (left)
                if (_showMediaBrowser) _buildMediaBrowser(),

                // Preview area (center)
                Expanded(child: _buildPreview()),

                // Inspector (right)
                if (_showInspector) _buildInspector(),
              ],
            ),
          ),

          // Timeline
          _buildTimeline(),

          // Transport controls
          _buildTransport(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          // Project actions
          IconButton(
            icon: const Icon(Icons.folder_open, color: Colors.grey, size: 20),
            onPressed: () {},
            tooltip: 'Open Project',
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.grey, size: 20),
            onPressed: () {},
            tooltip: 'Save Project',
          ),

          const SizedBox(width: 16),
          Container(width: 1, height: 24, color: Colors.grey[700]),
          const SizedBox(width: 16),

          // History
          IconButton(
            icon: Icon(Icons.undo, color: _historyIndex > 0 ? Colors.grey : Colors.grey[800], size: 20),
            onPressed: _historyIndex > 0 ? _undo : null,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: Icon(Icons.redo, color: _historyIndex < _history.length - 1 ? Colors.grey : Colors.grey[800], size: 20),
            onPressed: _historyIndex < _history.length - 1 ? _redo : null,
            tooltip: 'Redo',
          ),

          const SizedBox(width: 16),
          Container(width: 1, height: 24, color: Colors.grey[700]),
          const SizedBox(width: 16),

          // Clip actions
          IconButton(
            icon: const Icon(Icons.content_cut, color: Colors.grey, size: 20),
            onPressed: _splitClip,
            tooltip: 'Split Clip',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
            onPressed: _deleteSelectedClip,
            tooltip: 'Delete Clip',
          ),

          const Spacer(),

          // Panel toggles
          _buildPanelToggle('Media', _showMediaBrowser, (v) => setState(() => _showMediaBrowser = v)),
          _buildPanelToggle('Inspector', _showInspector, (v) => setState(() => _showInspector = v)),

          const SizedBox(width: 16),

          // Export
          ElevatedButton.icon(
            onPressed: _exportVideo,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelToggle(String label, bool value, Function(bool) onChanged) {
    return TextButton(
      onPressed: () => onChanged(!value),
      child: Row(
        children: [
          Icon(
            value ? Icons.visibility : Icons.visibility_off,
            size: 16,
            color: value ? Colors.purple : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: value ? Colors.purple : Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMediaBrowser() {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: scaffoldBg,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('Media', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.grey, size: 18),
                  onPressed: _importMedia,
                  tooltip: 'Import Media',
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2a2a3e), height: 1),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library, size: 48, color: Colors.grey[700]),
                  const SizedBox(height: 12),
                  Text('Drop media here', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _importMedia,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Import'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: const Color(0xFF2a2a3e),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Preview', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInspector() {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: scaffoldBg,
        border: Border(left: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: const Row(
              children: [
                Text('Inspector', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2a2a3e), height: 1),
          Expanded(
            child: _selectedClipId != null
                ? _buildClipInspector()
                : const Center(
                    child: Text('Select a clip to edit', style: TextStyle(color: Colors.grey)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildClipInspector() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInspectorSection('Transform', [
            _buildSlider('Position X', 0, -500, 500),
            _buildSlider('Position Y', 0, -500, 500),
            _buildSlider('Scale', 1, 0.1, 4),
            _buildSlider('Rotation', 0, -180, 180),
            _buildSlider('Opacity', 1, 0, 1),
          ]),
          const SizedBox(height: 16),
          _buildInspectorSection('Audio', [
            _buildSlider('Volume', 1, 0, 2),
          ]),
          const SizedBox(height: 16),
          _buildInspectorSection('Effects', [
            const Text('Add effects from the Effects panel', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ],
      ),
    );
  }

  Widget _buildInspectorSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildSlider(String label, double value, double min, double max) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: (v) {},
              activeColor: Colors.purple,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          // Timeline toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Zoom controls
                IconButton(
                  icon: const Icon(Icons.zoom_out, size: 18),
                  color: Colors.grey,
                  onPressed: () => setState(() => _zoom = (_zoom - 0.2).clamp(0.2, 4)),
                ),
                SizedBox(
                  width: 100,
                  child: Slider(
                    value: _zoom,
                    min: 0.2,
                    max: 4,
                    onChanged: (v) => setState(() => _zoom = v),
                    activeColor: Colors.purple,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_in, size: 18),
                  color: Colors.grey,
                  onPressed: () => setState(() => _zoom = (_zoom + 0.2).clamp(0.2, 4)),
                ),

                const SizedBox(width: 16),

                // Snap toggle
                TextButton.icon(
                  onPressed: () => setState(() => _snapEnabled = !_snapEnabled),
                  icon: Icon(Icons.grid_3x3, size: 16, color: _snapEnabled ? Colors.purple : Colors.grey),
                  label: Text('Snap', style: TextStyle(color: _snapEnabled ? Colors.purple : Colors.grey, fontSize: 12)),
                ),

                const Spacer(),

                // Add track button
                TextButton.icon(
                  onPressed: _addTrack,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Track'),
                ),
              ],
            ),
          ),

          // Tracks
          Expanded(
            child: Row(
              children: [
                // Track headers
                Container(
                  width: 120,
                  color: const Color(0xFF16162a),
                  child: ListView.builder(
                    itemCount: _tracks.length,
                    itemBuilder: (context, index) {
                      final track = _tracks[index];
                      return Container(
                        height: track.height,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              track.type == TrackType.video ? Icons.videocam : Icons.audiotrack,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                track.name,
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(track.muted ? Icons.volume_off : Icons.volume_up, size: 14),
                              color: track.muted ? Colors.red : Colors.grey,
                              onPressed: () => setState(() => track.muted = !track.muted),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Timeline content
                Expanded(
                  child: Stack(
                    children: [
                      // Grid lines
                      CustomPaint(
                        painter: _TimelineGridPainter(
                          zoom: _zoom,
                          scrollOffset: _scrollOffset,
                          trackHeights: _tracks.map((t) => t.height).toList(),
                        ),
                        size: const Size.fromHeight(double.infinity),
                      ),

                      // Clips would be drawn here

                      // Playhead
                      Positioned(
                        left: _currentTime * 10 * _zoom - _scrollOffset,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 2,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransport() {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scaffoldBg,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Time display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0d0d1a),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _formatTime(_currentTime),
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14),
            ),
          ),

          const SizedBox(width: 24),

          // Transport buttons
          IconButton(
            icon: const Icon(Icons.skip_previous),
            color: Colors.grey,
            onPressed: () => setState(() => _currentTime = 0),
          ),
          IconButton(
            icon: const Icon(Icons.fast_rewind),
            color: Colors.grey,
            onPressed: () => setState(() => _currentTime = (_currentTime - 1).clamp(0, _duration)),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              color: Colors.white,
              onPressed: () => setState(() => _isPlaying = !_isPlaying),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fast_forward),
            color: Colors.grey,
            onPressed: () => setState(() => _currentTime = (_currentTime + 1).clamp(0, _duration)),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            color: Colors.grey,
            onPressed: () => setState(() => _currentTime = _duration),
          ),

          const SizedBox(width: 24),

          // Volume
          IconButton(
            icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
            color: _isMuted ? Colors.red : Colors.grey,
            onPressed: () => setState(() => _isMuted = !_isMuted),
          ),
          SizedBox(
            width: 80,
            child: Slider(
              value: _isMuted ? 0 : _volume,
              onChanged: (v) => setState(() {
                _volume = v;
                _isMuted = v == 0;
              }),
              activeColor: Colors.purple,
            ),
          ),

          const SizedBox(width: 24),

          // Duration display
          Text(
            '/ ${_formatTime(_duration)}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    final frames = ((seconds % 1) * 24).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}:${frames.toString().padLeft(2, '0')}';
  }

  void _undo() {
    // TODO: Implement undo
  }

  void _redo() {
    // TODO: Implement redo
  }

  void _splitClip() {
    // TODO: Implement split at playhead
  }

  void _deleteSelectedClip() {
    if (_selectedClipId != null) {
      setState(() {
        _clips.removeWhere((c) => c.id == _selectedClipId);
        _selectedClipId = null;
      });
    }
  }

  void _importMedia() {
    // TODO: Implement file picker
  }

  void _addTrack() {
    setState(() {
      final newId = 'track_${_tracks.length + 1}';
      _tracks.add(Track(
        id: newId,
        name: 'Track ${_tracks.length + 1}',
        type: _tracks.length % 2 == 0 ? TrackType.video : TrackType.audio,
        order: _tracks.length,
      ));
    });
  }

  void _exportVideo() {
    // TODO: Implement export
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a3e),
        title: const Text('Export Video', style: TextStyle(color: Colors.white)),
        content: const Text('Export functionality coming soon...', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _TimelineGridPainter extends CustomPainter {
  final double zoom;
  final double scrollOffset;
  final List<double> trackHeights;

  _TimelineGridPainter({
    required this.zoom,
    required this.scrollOffset,
    required this.trackHeights,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2a2a3e)
      ..strokeWidth = 1;

    // Vertical grid lines (time markers)
    final interval = 10 * zoom; // 1 second = 10px at zoom 1
    for (double x = -scrollOffset % interval; x < size.width; x += interval) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal track separators
    double y = 0;
    for (final height in trackHeights) {
      y += height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineGridPainter oldDelegate) {
    return zoom != oldDelegate.zoom || scrollOffset != oldDelegate.scrollOffset;
  }
}
