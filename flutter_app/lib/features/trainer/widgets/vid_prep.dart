import 'package:flutter/material.dart';

/// VidPrep - Video Preparation Tool
/// Ported from React VidPrep.tsx
///
/// Features:
/// - Model presets (Wan, HunyuanVideo, FramePack) with FPS/resolution settings
/// - Video trimming with frame-accurate ranges
/// - Crop region selection
/// - Caption editing per clip
/// - Export to training-ready format
class VidPrep extends StatefulWidget {
  final VoidCallback? onClose;

  const VidPrep({super.key, this.onClose});

  @override
  State<VidPrep> createState() => _VidPrepState();
}

// Model presets with native FPS and recommended settings
class ModelPreset {
  final String id;
  final String name;
  final int fps;
  final List<ResolutionPreset> resolutions;
  final String frameRule;
  final List<int> validFrames;

  const ModelPreset({
    required this.id,
    required this.name,
    required this.fps,
    required this.resolutions,
    required this.frameRule,
    required this.validFrames,
  });
}

class ResolutionPreset {
  final String label;
  final int width;
  final int height;
  final int frames;

  const ResolutionPreset({
    required this.label,
    required this.width,
    required this.height,
    required this.frames,
  });
}

final modelPresets = {
  'wan': ModelPreset(
    id: 'wan',
    name: 'Wan 2.1/2.2',
    fps: 16,
    resolutions: [
      ResolutionPreset(label: 'Low (480x272)', width: 480, height: 272, frames: 65),
      ResolutionPreset(label: 'Medium (640x360)', width: 640, height: 360, frames: 37),
      ResolutionPreset(label: 'High (848x480)', width: 848, height: 480, frames: 21),
      ResolutionPreset(label: '720p (1280x720)', width: 1280, height: 720, frames: 17),
    ],
    frameRule: 'N*4+1',
    validFrames: [1, 5, 9, 13, 17, 21, 25, 29, 33, 37, 41, 45, 49, 53, 57, 61, 65, 69, 73, 77, 81],
  ),
  'hunyuan': ModelPreset(
    id: 'hunyuan',
    name: 'HunyuanVideo',
    fps: 24,
    resolutions: [
      ResolutionPreset(label: 'Low (480x270)', width: 480, height: 270, frames: 49),
      ResolutionPreset(label: 'Medium (640x360)', width: 640, height: 360, frames: 97),
      ResolutionPreset(label: 'Paper (960x544)', width: 960, height: 544, frames: 129),
    ],
    frameRule: 'N*4+1',
    validFrames: [1, 5, 9, 13, 17, 21, 25, 29, 33, 37, 41, 45, 49, 53, 57, 61, 65, 69, 73, 77, 81, 85, 89, 93, 97, 101, 105, 109, 113, 117, 121, 125, 129],
  ),
  'framepack': ModelPreset(
    id: 'framepack',
    name: 'FramePack',
    fps: 30,
    resolutions: [
      ResolutionPreset(label: 'Standard (512x512)', width: 512, height: 512, frames: 25),
      ResolutionPreset(label: 'Wide (768x432)', width: 768, height: 432, frames: 25),
    ],
    frameRule: 'flexible',
    validFrames: [9, 13, 17, 21, 25, 33, 41, 49],
  ),
};

class VideoFile {
  final String name;
  final String path;
  final double duration;
  final double fps;
  final int width;
  final int height;
  final int frames;
  final int size;
  String? thumbnail;

  VideoFile({
    required this.name,
    required this.path,
    required this.duration,
    required this.fps,
    required this.width,
    required this.height,
    required this.frames,
    required this.size,
    this.thumbnail,
  });
}

class CropRegion {
  int x;
  int y;
  int width;
  int height;

  CropRegion({
    this.x = 0,
    this.y = 0,
    this.width = 0,
    this.height = 0,
  });
}

class VideoRange {
  final String id;
  double start;
  double end;
  String caption;
  CropRegion? crop;
  bool useCrop;

  VideoRange({
    required this.id,
    required this.start,
    required this.end,
    this.caption = '',
    this.crop,
    this.useCrop = false,
  });
}

class ExportSettings {
  bool exportCropped;
  bool exportUncropped;
  bool exportFirstFrame;
  int maxLongestEdge;
  int targetFps;
  int targetFrames;
  String outputFormat;
  bool includeAudio;

  ExportSettings({
    this.exportCropped = true,
    this.exportUncropped = false,
    this.exportFirstFrame = true,
    this.maxLongestEdge = 848,
    this.targetFps = 16,
    this.targetFrames = 21,
    this.outputFormat = 'mp4',
    this.includeAudio = false,
  });
}

class _VidPrepState extends State<VidPrep> {
  // Selected model preset
  String _selectedModel = 'wan';
  int _selectedResolutionIndex = 2; // High (848x480)

  // Video state
  VideoFile? _currentVideo;
  List<VideoRange> _ranges = [];
  String? _selectedRangeId;

  // Playback
  bool _isPlaying = false;
  double _currentTime = 0;
  double _duration = 0;

  // Export settings
  final ExportSettings _exportSettings = ExportSettings();

  // Processing state
  bool _isProcessing = false;
  double _processingProgress = 0;
  String _processingStatus = '';

  // UI state
  bool _showExportPanel = false;

  ModelPreset get _currentPreset => modelPresets[_selectedModel]!;
  ResolutionPreset get _currentResolution => _currentPreset.resolutions[_selectedResolutionIndex];

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

          // Main content
          Expanded(
            child: Row(
              children: [
                // Left panel - Settings & Ranges
                _buildLeftPanel(),

                // Center - Video preview
                Expanded(child: _buildPreview()),

                // Right panel - Export settings
                if (_showExportPanel) _buildExportPanel(),
              ],
            ),
          ),

          // Bottom - Timeline
          _buildTimeline(),
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
          const Icon(Icons.content_cut, color: Colors.purple, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Video Prep',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),

          const SizedBox(width: 24),

          // Model selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2a2a3e),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedModel,
                dropdownColor: const Color(0xFF2a2a3e),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                items: modelPresets.entries.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value.name),
                )).toList(),
                onChanged: (v) => setState(() => _selectedModel = v!),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Resolution selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2a2a3e),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedResolutionIndex.clamp(0, _currentPreset.resolutions.length - 1),
                dropdownColor: const Color(0xFF2a2a3e),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                items: _currentPreset.resolutions.asMap().entries.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value.label),
                )).toList(),
                onChanged: (v) => setState(() => _selectedResolutionIndex = v!),
              ),
            ),
          ),

          const Spacer(),

          // Import button
          ElevatedButton.icon(
            onPressed: _importVideo,
            icon: const Icon(Icons.video_file, size: 16),
            label: const Text('Import Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2a2a3e),
              foregroundColor: Colors.white,
            ),
          ),

          const SizedBox(width: 12),

          // Export panel toggle
          TextButton.icon(
            onPressed: () => setState(() => _showExportPanel = !_showExportPanel),
            icon: Icon(Icons.settings, size: 16, color: _showExportPanel ? Colors.purple : Colors.grey),
            label: Text('Export', style: TextStyle(color: _showExportPanel ? Colors.purple : Colors.grey)),
          ),

          const SizedBox(width: 12),

          // Export button
          ElevatedButton.icon(
            onPressed: _ranges.isNotEmpty ? _exportClips : null,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export Clips'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: scaffoldBg,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          // Model info
          _buildModelInfo(),

          const Divider(color: Color(0xFF2a2a3e), height: 1),

          // Ranges list
          Expanded(child: _buildRangesList()),

          // Add range button
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _currentVideo != null ? _addRange : null,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Clip Range'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2a2a3e),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text('Model Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Target FPS', '${_currentPreset.fps}'),
          _buildInfoRow('Resolution', '${_currentResolution.width}x${_currentResolution.height}'),
          _buildInfoRow('Max Frames', '${_currentResolution.frames}'),
          _buildInfoRow('Frame Rule', _currentPreset.frameRule),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRangesList() {
    if (_ranges.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_filter, size: 48, color: Color(0xFF3a3a4e)),
            SizedBox(height: 12),
            Text('No clip ranges', style: TextStyle(color: Colors.grey)),
            Text('Import a video and add ranges', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _ranges.length,
      itemBuilder: (context, index) {
        final range = _ranges[index];
        final isSelected = range.id == _selectedRangeId;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.purple.withOpacity(0.2) : const Color(0xFF2a2a3e),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.purple : Colors.transparent,
            ),
          ),
          child: InkWell(
            onTap: () => setState(() => _selectedRangeId = range.id),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Clip ${index + 1}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        '${_formatTime(range.start)} - ${_formatTime(range.end)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        color: Colors.red,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        onPressed: () => _deleteRange(range.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: range.caption,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Caption...',
                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xFF3a3a4e)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (v) => range.caption = v,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        range.useCrop ? Icons.crop : Icons.crop_free,
                        size: 14,
                        color: range.useCrop ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        range.useCrop ? 'Cropped' : 'Full frame',
                        style: TextStyle(color: range.useCrop ? Colors.green : Colors.grey, fontSize: 11),
                      ),
                      const Spacer(),
                      Text(
                        '${((range.end - range.start) * _currentPreset.fps).round()} frames',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreview() {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Video preview
          Expanded(
            child: Center(
              child: _currentVideo != null
                  ? AspectRatio(
                      aspectRatio: _currentVideo!.width / _currentVideo!.height,
                      child: Container(
                        color: const Color(0xFF2a2a3e),
                        child: const Center(
                          child: Icon(Icons.play_circle_outline, size: 64, color: Colors.grey),
                        ),
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_library, size: 64, color: Color(0xFF3a3a4e)),
                        SizedBox(height: 16),
                        Text('Import a video to begin', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
            ),
          ),

          // Playback controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                const SizedBox(width: 16),
                Text(
                  '${_formatTime(_currentTime)} / ${_formatTime(_duration)}',
                  style: const TextStyle(color: Colors.grey, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: scaffoldBg,
        border: Border(left: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Export Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            _buildToggleSetting('Export Cropped', _exportSettings.exportCropped, (v) => setState(() => _exportSettings.exportCropped = v)),
            _buildToggleSetting('Export Uncropped', _exportSettings.exportUncropped, (v) => setState(() => _exportSettings.exportUncropped = v)),
            _buildToggleSetting('Export First Frame', _exportSettings.exportFirstFrame, (v) => setState(() => _exportSettings.exportFirstFrame = v)),
            _buildToggleSetting('Include Audio', _exportSettings.includeAudio, (v) => setState(() => _exportSettings.includeAudio = v)),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2a2a3e)),
            const SizedBox(height: 16),

            const Text('Output Format', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'mp4', label: Text('MP4')),
                ButtonSegment(value: 'webm', label: Text('WebM')),
              ],
              selected: {_exportSettings.outputFormat},
              onSelectionChanged: (v) => setState(() => _exportSettings.outputFormat = v.first),
            ),

            const SizedBox(height: 16),

            const Text('Max Longest Edge', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Slider(
              value: _exportSettings.maxLongestEdge.toDouble(),
              min: 256,
              max: 1920,
              divisions: 13,
              label: '${_exportSettings.maxLongestEdge}px',
              onChanged: (v) => setState(() => _exportSettings.maxLongestEdge = v.toInt()),
              activeColor: Colors.purple,
            ),
            Text('${_exportSettings.maxLongestEdge}px', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleSetting(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Stack(
        children: [
          // Range visualization
          if (_currentVideo != null)
            ..._ranges.map((range) => Positioned(
              left: (range.start / _duration) * MediaQuery.of(context).size.width,
              width: ((range.end - range.start) / _duration) * MediaQuery.of(context).size.width,
              top: 20,
              bottom: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: range.id == _selectedRangeId
                      ? Colors.purple.withOpacity(0.5)
                      : Colors.blue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: range.id == _selectedRangeId ? Colors.purple : Colors.blue,
                  ),
                ),
              ),
            )),

          // Playhead
          Positioned(
            left: (_duration > 0 ? _currentTime / _duration : 0) * MediaQuery.of(context).size.width,
            top: 0,
            bottom: 0,
            child: Container(
              width: 2,
              color: Colors.red,
            ),
          ),

          // Time markers
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 16,
              color: const Color(0xFF16162a),
              child: const Center(
                child: Text('Timeline', style: TextStyle(color: Colors.grey, fontSize: 10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    final ms = ((seconds % 1) * 100).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }

  void _importVideo() {
    // TODO: Implement file picker
    // For now, simulate with dummy data
    setState(() {
      _currentVideo = VideoFile(
        name: 'sample_video.mp4',
        path: '/path/to/video.mp4',
        duration: 60,
        fps: 30,
        width: 1920,
        height: 1080,
        frames: 1800,
        size: 50000000,
      );
      _duration = 60;
    });
  }

  void _addRange() {
    if (_currentVideo == null) return;

    final id = 'range_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _ranges.add(VideoRange(
        id: id,
        start: _currentTime,
        end: (_currentTime + 2).clamp(0, _duration),
        caption: '',
      ));
      _selectedRangeId = id;
    });
  }

  void _deleteRange(String id) {
    setState(() {
      _ranges.removeWhere((r) => r.id == id);
      if (_selectedRangeId == id) {
        _selectedRangeId = _ranges.isNotEmpty ? _ranges.first.id : null;
      }
    });
  }

  void _exportClips() {
    // TODO: Implement export
    setState(() {
      _isProcessing = true;
      _processingProgress = 0;
      _processingStatus = 'Preparing export...';
    });

    // Simulate progress
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isProcessing = false;
        _processingProgress = 1;
        _processingStatus = 'Export complete!';
      });
    });
  }
}
