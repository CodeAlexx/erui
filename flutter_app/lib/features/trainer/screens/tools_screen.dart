import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/vid_prep.dart';
import '../widgets/video_editor.dart';

/// Tools Screen - Utility Tools with multiple tabs
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8100',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
  ));

  // Captioner state
  String _captionerModel = 'Qwen/Qwen2.5-VL-7B-Instruct';
  bool _captionerLoaded = false;
  bool _isLoadingModel = false;
  String _captionerFolderPath = '';
  String _customPrompt = 'Give one detailed paragraph (max 250 words) describing everything clearly visible in the image—subjects, objects, environment, style, lighting, and mood. Do not use openings like \'This is\' or \'The image shows\'; start directly with the main subject. Avoid guessing anything not clearly visible.';
  bool _skipCaptioned = true;
  bool _summaryMode = false;
  bool _oneSentenceMode = false;
  bool _isVideoMode = false;
  double _videoFps = 1.0;

  static const _defaultImagePrompt = 'Give one detailed paragraph (max 250 words) describing everything clearly visible in the image—subjects, objects, environment, style, lighting, and mood. Do not use openings like \'This is\' or \'The image shows\'; start directly with the main subject. Avoid guessing anything not clearly visible.';
  static const _defaultVideoPrompt = 'Describe what happens in this video in one detailed paragraph (max 250 words). Include the actions, movements, and any changes that occur. Start directly with what is happening, avoid openings like \'This video shows\'. Focus on the sequence of events and motion.';
  double _maxTokens = 256;
  String _imageResolution = 'auto';
  String _quantization = 'None';
  String _attnImpl = 'eager';
  String _captionerStatus = 'Ready';
  String _vramUsed = '';

  // Processing state
  bool _isProcessing = false;
  double _progress = 0;
  int _processed = 0;
  int _skipped = 0;
  int _failed = 0;
  int _total = 0;
  String? _currentFile;
  String? _lastCaption;
  String? _currentImagePath;
  Timer? _pollTimer;
  final Stopwatch _stopwatch = Stopwatch();
  late TextEditingController _promptController;

  // Mask Generation state
  String _maskImageDir = '/path/to/images';
  String _maskModel = 'Segment Anything (SAM)';
  double _maskThreshold = 0.5;
  bool _invertMask = false;

  static const _captionerModels = [
    'Qwen/Qwen2.5-VL-7B-Instruct',
    'Qwen/Qwen2-VL-7B-Instruct',
  ];
  static const _maskModels = ['Segment Anything (SAM)', 'U2-Net', 'BiRefNet', 'RMBG-1.4'];
  static const _resolutions = ['auto', 'fast', 'high'];
  static const _quantizations = ['None', '8-bit', '4-bit'];
  static const _attnImpls = ['eager', 'flash_attention_2'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _promptController = TextEditingController(text: _customPrompt);
    _checkModelState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    _pollTimer?.cancel();
    _dio.close();
    super.dispose();
  }

  // Check if model is already loaded
  Future<void> _checkModelState() async {
    try {
      final res = await _dio.get('/api/caption/state');
      if (res.statusCode == 200 && mounted) {
        final data = res.data as Map<String, dynamic>;
        setState(() {
          _captionerLoaded = data['loaded'] == true;
          _vramUsed = data['vram_used'] ?? '';
          if (_captionerLoaded && data['model_id'] != null) {
            _captionerModel = data['model_id'];
          }
        });
      }
    } catch (e) {
      // OneTrainer not running
    }
  }

  // Load the captioning model
  Future<void> _loadModel() async {
    setState(() => _isLoadingModel = true);
    try {
      final res = await _dio.post('/api/caption/load', data: {
        'model_id': _captionerModel,
        'quantization': _quantization,
        'attn_impl': _attnImpl,
      });
      if (res.statusCode == 200 && mounted) {
        final data = res.data as Map<String, dynamic>;
        setState(() {
          _captionerLoaded = data['loaded'] == true;
          _vramUsed = data['vram_used'] ?? '';
          _captionerStatus = 'Model loaded';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _captionerStatus = 'Error loading model: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoadingModel = false);
    }
  }

  // Unload the model
  Future<void> _unloadModel() async {
    try {
      await _dio.post('/api/caption/unload');
      if (mounted) {
        setState(() {
          _captionerLoaded = false;
          _vramUsed = '';
          _captionerStatus = 'Model unloaded';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _captionerStatus = 'Error unloading: $e');
      }
    }
  }

  // Pick folder and auto-detect content type
  Future<void> _pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null && mounted) {
      // Scan folder to detect if mostly images or videos
      final dir = Directory(result);
      int imageCount = 0;
      int videoCount = 0;

      try {
        final files = dir.listSync().whereType<File>();
        for (final file in files) {
          if (_isVideoFile(file.path)) {
            videoCount++;
          } else if (_isImageFile(file.path)) {
            imageCount++;
          }
        }
      } catch (e) {
        // Ignore scan errors
      }

      setState(() {
        _captionerFolderPath = result;
        // Auto-detect mode based on folder contents
        if (videoCount > imageCount && videoCount > 0) {
          _isVideoMode = true;
          _customPrompt = _defaultVideoPrompt;
          _promptController.text = _customPrompt;
        } else if (imageCount > 0) {
          _isVideoMode = false;
          _customPrompt = _defaultImagePrompt;
          _promptController.text = _customPrompt;
        }
      });
    }
  }

  // Check if file is an image
  bool _isImageFile(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') ||
           ext.endsWith('.bmp') || ext.endsWith('.gif') || ext.endsWith('.webp');
  }

  // Build the final prompt based on modes
  String _buildFinalPrompt() {
    if (_oneSentenceMode) {
      return 'Describe this image in one concise sentence.';
    } else if (_summaryMode) {
      return 'Provide a brief summary of what is shown in this image.';
    }
    return _customPrompt;
  }

  // Start batch processing
  Future<void> _startProcessing() async {
    if (_captionerFolderPath.isEmpty) {
      setState(() => _captionerStatus = 'Please select a folder first');
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _processed = 0;
      _skipped = 0;
      _failed = 0;
      _currentFile = null;
      _lastCaption = null;
      _captionerStatus = 'Starting...';
    });

    _stopwatch.reset();
    _stopwatch.start();

    try {
      final res = await _dio.post('/api/caption/batch/start', data: {
        'folder_path': _captionerFolderPath,
        'prompt': _buildFinalPrompt(),
        'skip_existing': _skipCaptioned,
        'max_tokens': _maxTokens.toInt(),
        'resolution_mode': _imageResolution,
      });

      if (res.statusCode == 200) {
        // Start polling for status
        _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _pollStatus());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _captionerStatus = 'Error: $e';
        });
      }
      _stopwatch.stop();
    }
  }

  // Poll batch status
  Future<void> _pollStatus() async {
    try {
      final res = await _dio.get('/api/caption/batch/status');
      if (res.statusCode == 200 && mounted) {
        final data = res.data as Map<String, dynamic>;
        final stats = data['stats'] as Map<String, dynamic>? ?? {};

        setState(() {
          _progress = (data['progress'] as num?)?.toDouble() ?? 0;
          _processed = stats['processed'] as int? ?? 0;
          _skipped = stats['skipped'] as int? ?? 0;
          _failed = stats['failed'] as int? ?? 0;
          _total = data['total'] as int? ?? 0;
          _currentFile = data['current_file'];
          _lastCaption = data['last_caption'];

          if (_currentFile != null) {
            _currentImagePath = '$_captionerFolderPath/$_currentFile';
            _captionerStatus = 'Processing: $_currentFile';
          }
        });

        if (data['active'] != true) {
          _pollTimer?.cancel();
          _stopwatch.stop();
          setState(() {
            _isProcessing = false;
            _captionerStatus = 'Complete: $_processed processed, $_skipped skipped, $_failed failed';
          });
        }
      }
    } catch (e) {
      // Ignore poll errors
    }
  }

  // Stop processing
  Future<void> _stopProcessing() async {
    try {
      await _dio.post('/api/caption/batch/stop');
      _pollTimer?.cancel();
      _stopwatch.stop();
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _captionerStatus = 'Stopped by user';
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  // Reset to default prompt
  void _resetPrompt() {
    setState(() {
      _customPrompt = _isVideoMode ? _defaultVideoPrompt : _defaultImagePrompt;
      _promptController.text = _customPrompt;
      _summaryMode = false;
      _oneSentenceMode = false;
    });
  }

  // Format elapsed time
  String _formatTime(Duration d) {
    final mins = d.inMinutes.toString().padLeft(2, '0');
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  // Check if file is a video
  bool _isVideoFile(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi') ||
           ext.endsWith('.webm') || ext.endsWith('.mkv') || ext.endsWith('.flv');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Column(
        children: [
          // Header with tabs
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Utility Tools', style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: colorScheme.primary,
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurface.withOpacity(0.5),
                  tabs: const [
                    Tab(text: 'Captioner'),
                    Tab(text: 'Model Conversion'),
                    Tab(text: 'Mask Generation'),
                    Tab(text: 'Dataset Tools'),
                    Tab(text: 'Image Tools'),
                    Tab(text: 'Video Prep'),
                    Tab(text: 'Video Editor'),
                  ],
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCaptionerTab(colorScheme),
                _buildPlaceholderTab('Model Conversion', colorScheme),
                _buildMaskGenerationTab(colorScheme),
                _buildPlaceholderTab('Dataset Tools', colorScheme),
                _buildPlaceholderTab('Image Tools', colorScheme),
                const VidPrep(),
                const VideoEditor(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionerTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Model Information
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Model Information', style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _captionerLoaded ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _captionerLoaded ? 'LOADED' : 'UNLOADED',
                            style: TextStyle(color: _captionerLoaded ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_vramUsed.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Text('VRAM: $_vramUsed', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Model ID', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _captionerModel,
                                    isExpanded: true,
                                    dropdownColor: colorScheme.surface,
                                    style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                                    items: _captionerModels.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                    onChanged: _captionerLoaded ? null : (v) => setState(() => _captionerModel = v!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Quantization', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _quantization,
                                    isExpanded: true,
                                    dropdownColor: colorScheme.surface,
                                    style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                                    items: _quantizations.map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                                    onChanged: _captionerLoaded ? null : (v) => setState(() => _quantization = v!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 160,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Attention', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _attnImpl,
                                    isExpanded: true,
                                    dropdownColor: colorScheme.surface,
                                    style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                                    items: _attnImpls.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                                    onChanged: _captionerLoaded ? null : (v) => setState(() => _attnImpl = v!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Spacer(),
                        if (_captionerLoaded)
                          ElevatedButton(
                            onPressed: _unloadModel,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.2),
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Unload'),
                          )
                        else
                          ElevatedButton(
                            onPressed: _isLoadingModel ? null : _loadModel,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.surfaceContainerHighest,
                              foregroundColor: colorScheme.onSurface,
                            ),
                            child: _isLoadingModel
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Load'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Settings
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Folder Path / Custom Prompt
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('FOLDER PATH', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11, letterSpacing: 0.5)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: TextEditingController(text: _captionerFolderPath),
                                      style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                                      decoration: _inputDecoration(colorScheme).copyWith(
                                        hintText: '/path/to/images',
                                        hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.3)),
                                      ),
                                      onChanged: (v) => setState(() => _captionerFolderPath = v),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: _pickFolder,
                                    icon: const Icon(Icons.folder_open),
                                    tooltip: 'Browse',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CUSTOM PROMPT', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11, letterSpacing: 0.5)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _promptController,
                                style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                                decoration: _inputDecoration(colorScheme),
                                maxLines: 2,
                                textDirection: TextDirection.ltr,
                                onChanged: (v) => _customPrompt = v,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Checkboxes
                    Row(
                      children: [
                        Checkbox(
                          value: _skipCaptioned,
                          onChanged: (v) => setState(() => _skipCaptioned = v ?? false),
                        ),
                        Text('Skip captioned', style: TextStyle(color: colorScheme.onSurface, fontSize: 12)),
                        const SizedBox(width: 16),
                        Checkbox(
                          value: _isVideoMode,
                          onChanged: (v) => setState(() {
                            _isVideoMode = v ?? false;
                            _customPrompt = _isVideoMode ? _defaultVideoPrompt : _defaultImagePrompt;
                            _promptController.text = _customPrompt;
                          }),
                        ),
                        Text('Video Mode', style: TextStyle(color: colorScheme.onSurface, fontSize: 12, fontWeight: _isVideoMode ? FontWeight.bold : FontWeight.normal)),
                        const SizedBox(width: 16),
                        Checkbox(
                          value: _summaryMode,
                          onChanged: (v) => setState(() => _summaryMode = v ?? false),
                        ),
                        Text('Summary', style: TextStyle(color: colorScheme.onSurface, fontSize: 12)),
                        const SizedBox(width: 16),
                        Checkbox(
                          value: _oneSentenceMode,
                          onChanged: (v) => setState(() => _oneSentenceMode = v ?? false),
                        ),
                        Text('One-Sentence', style: TextStyle(color: colorScheme.onSurface, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Final Prompt Preview
                    Text('Final Prompt Preview', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _customPrompt,
                        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontSize: 12, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Max Tokens / Image Resolution
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('MAX TOKENS', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11, letterSpacing: 0.5)),
                                  const Spacer(),
                                  Text(_maxTokens.toInt().toString(), style: TextStyle(color: colorScheme.onSurface, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Slider(
                                value: _maxTokens,
                                min: 32,
                                max: 512,
                                divisions: 480,
                                activeColor: colorScheme.primary,
                                onChanged: (v) => setState(() => _maxTokens = v),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('32', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.3), fontSize: 10)),
                                  Text('512', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.3), fontSize: 10)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('IMAGE RESOLUTION', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11, letterSpacing: 0.5)),
                                  const SizedBox(width: 8),
                                  Text('choose the resolution mode', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.3), fontSize: 10)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _imageResolution,
                                    isExpanded: true,
                                    dropdownColor: colorScheme.surface,
                                    style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                                    items: _resolutions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                                    onChanged: (v) => setState(() => _imageResolution = v!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _resetPrompt,
                          child: const Text('Reset to Default Prompt'),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: (_captionerLoaded && !_isProcessing) ? _startProcessing : null,
                          icon: const Icon(Icons.auto_fix_high, size: 18),
                          label: const Text('Start Processing'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _isProcessing ? _stopProcessing : null,
                          icon: Icon(Icons.stop, size: 18, color: _isProcessing ? Colors.red.shade400 : Colors.grey),
                          label: Text('Abort', style: TextStyle(color: _isProcessing ? Colors.red.shade400 : Colors.grey)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _isProcessing ? Colors.red.shade400 : Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Status + Progress
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Status', style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (_isProcessing || _stopwatch.elapsed.inSeconds > 0)
                          Text('Time: ${_formatTime(_stopwatch.elapsed)}', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_captionerStatus, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontSize: 12)),
                    if (_isProcessing || _progress > 0) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${(_progress * 100).toStringAsFixed(1)}%', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                          Text('Processed: $_processed of $_total  Skipped: $_skipped  Failed: $_failed', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Current Image + Generated Caption
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Image
                  Expanded(
                    child: Container(
                      height: 300,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Media', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _currentImagePath != null && File(_currentImagePath!).existsSync()
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: _isVideoFile(_currentImagePath!)
                                        ? Container(
                                            color: colorScheme.surfaceContainerHighest,
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.videocam, size: 48, color: colorScheme.onSurface.withOpacity(0.5)),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    _currentFile ?? 'Video',
                                                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontSize: 11),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        : Image.file(
                                            File(_currentImagePath!),
                                            fit: BoxFit.contain,
                                          ),
                                  )
                                : Center(
                                    child: Text(
                                      'Waiting for media...',
                                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.3)),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Generated Caption
                  Expanded(
                    child: Container(
                      height: 300,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Generated Caption', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                _lastCaption ?? 'Caption will appear here...',
                                style: TextStyle(
                                  color: _lastCaption != null ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.3),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaskGenerationTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MASK GENERATION', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                const SizedBox(height: 24),

                // Image Directory
                Text('Image Directory', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                const SizedBox(height: 4),
                TextField(
                  controller: TextEditingController(text: _maskImageDir),
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                  decoration: _inputDecoration(colorScheme),
                  onChanged: (v) => setState(() => _maskImageDir = v),
                ),
                const SizedBox(height: 16),

                // Mask Model / Threshold
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mask Model', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _maskModel,
                                isExpanded: true,
                                dropdownColor: colorScheme.surface,
                                style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                                items: _maskModels.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                onChanged: (v) => setState(() => _maskModel = v!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Threshold', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: TextEditingController(text: _maskThreshold.toString()),
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                            decoration: _inputDecoration(colorScheme),
                            onChanged: (v) => setState(() => _maskThreshold = double.tryParse(v) ?? 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Invert Mask
                Row(
                  children: [
                    Checkbox(
                      value: _invertMask,
                      onChanged: (v) => setState(() => _invertMask = v ?? false),
                    ),
                    Text('Invert Mask', style: TextStyle(color: colorScheme.onSurface, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      child: const Text('Generate Masks'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Edit Masks'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(String title, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 64, color: colorScheme.onSurface.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('$title - Coming Soon', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 18)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(ColorScheme colorScheme) {
    return InputDecoration(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}
