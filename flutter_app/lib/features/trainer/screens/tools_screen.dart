import 'package:flutter/material.dart';
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

  // Captioner state
  String _captionerModel = 'Qwen2-VL-7B-Instruct';
  bool _captionerLoaded = false;
  String _captionerFolderPath = '/path/to/images';
  String _customPrompt = 'Give one detailed paragraph (max 250 words) describing everyt';
  bool _skipCaptioned = false;
  bool _summaryMode = false;
  bool _oneSentenceMode = false;
  double _maxTokens = 256;
  String _imageResolution = 'auto';
  String _captionerStatus = '';

  // Mask Generation state
  String _maskImageDir = '/path/to/images';
  String _maskModel = 'Segment Anything (SAM)';
  double _maskThreshold = 0.5;
  bool _invertMask = false;

  static const _captionerModels = ['Qwen2-VL-7B-Instruct', 'BLIP-2', 'LLaVA-1.5', 'CogVLM'];
  static const _maskModels = ['Segment Anything (SAM)', 'U2-Net', 'BiRefNet', 'RMBG-1.4'];
  static const _resolutions = ['auto', '224', '336', '512', '768', '1024'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Model ID', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
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
                                onChanged: (v) => setState(() => _captionerModel = v!),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => setState(() => _captionerLoaded = !_captionerLoaded),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            foregroundColor: colorScheme.onSurface,
                          ),
                          child: const Text('Load'),
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
                              TextField(
                                controller: TextEditingController(text: _captionerFolderPath),
                                style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                                decoration: _inputDecoration(colorScheme),
                                onChanged: (v) => setState(() => _captionerFolderPath = v),
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
                                controller: TextEditingController(text: _customPrompt),
                                style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                                decoration: _inputDecoration(colorScheme),
                                onChanged: (v) => setState(() => _customPrompt = v),
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
                        Text('Skip already captioned media (.txt exists)', style: TextStyle(color: colorScheme.onSurface, fontSize: 12)),
                        const SizedBox(width: 24),
                        Checkbox(
                          value: _summaryMode,
                          onChanged: (v) => setState(() => _summaryMode = v ?? false),
                        ),
                        Text('Summary Mode', style: TextStyle(color: colorScheme.onSurface, fontSize: 12)),
                        const SizedBox(width: 24),
                        Checkbox(
                          value: _oneSentenceMode,
                          onChanged: (v) => setState(() => _oneSentenceMode = v ?? false),
                        ),
                        Text('One-Sentence Mode', style: TextStyle(color: colorScheme.onSurface, fontSize: 12)),
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
                        'Give one detailed paragraph (max 250 words) describing everything clearly visible in the image—subjects, objects, environment, style, lighting, and mood. Do not use openings like \'This is\' or \'The image shows\'; start directly with the main subject. Avoid guessing anything not clearly visible.',
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
                          onPressed: () {},
                          child: const Text('Reset to Default Prompt'),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _captionerLoaded ? () {} : null,
                          icon: const Icon(Icons.auto_fix_high, size: 18),
                          label: const Text('Start Processing'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.stop, size: 18, color: Colors.red.shade400),
                          label: Text('Abort', style: TextStyle(color: Colors.red.shade400)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade400),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Status
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
                    Text('Status', style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (_captionerStatus.isEmpty)
                      Text('Ready', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 12))
                    else
                      Text(_captionerStatus, style: TextStyle(color: colorScheme.onSurface, fontSize: 12)),
                  ],
                ),
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
