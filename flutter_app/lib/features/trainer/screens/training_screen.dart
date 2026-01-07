import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/onetrainer_service.dart' as ot;

/// Training Screen - Main training configuration and monitoring
/// Connected to OneTrainer API via currentConfigProvider
class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Samples browser state
  List<_TreeNode> _samplesTree = [];
  Set<String> _expandedNodes = {};
  String? _selectedPath;
  String _selectedName = '';
  List<String> _sampleImages = [];
  bool _loadingImages = false;

  static const _optimizers = [
    'ADAMW', 'ADAMW_8BIT', 'ADAM', 'ADAM_8BIT', 'LION', 'LION_8BIT',
    'PRODIGY', 'ADAFACTOR', 'SGD', 'LAMB', 'LARS', 'CAME',
    'SCHEDULE_FREE_ADAMW', 'SCHEDULE_FREE_SGD',
    'DADAPT_ADAM', 'DADAPT_LION', 'DADAPT_SGD',
  ];
  static const _schedulers = ['CONSTANT', 'LINEAR', 'COSINE', 'COSINE_WITH_RESTARTS', 'COSINE_WITH_HARD_RESTARTS', 'REX', 'ADAFACTOR', 'CUSTOM'];
  static const _emaModes = ['OFF', 'CPU', 'GPU'];
  static const _gradModes = ['OFF', 'ON', 'CPU_OFFLOADED'];
  static const _dtypes = ['FLOAT_32', 'FLOAT_16', 'BFLOAT_16', 'TFLOAT_32'];
  static const _lrScalers = ['NONE', 'SQRT_ACCUM', 'LINEAR_ACCUM', 'SQRT_BATCH_LINEAR_ACCUM'];
  static const _timestepDists = ['UNIFORM', 'SIGMOID', 'LOGIT_NORMAL', 'BETA', 'FLUX_SHIFT'];
  static const _lossWeights = ['CONSTANT', 'MIN_SNR_GAMMA', 'P2', 'DEBIASED', 'RESCALE_ZERO_TERMINAL_SNR', 'SIGMOID'];
  static const _lossScalers = ['NONE', 'BATCH_SIZE', 'ACCUM_STEPS', 'BATCH_AND_ACCUM'];
  static const _timeUnits = ['NEVER', 'EPOCH', 'STEP', 'SECOND', 'MINUTE'];
  static const _bucketPresets = ['default', 'photo', 'video', 'widescreen', 'square'];
  static const _bucketBalancing = ['OFF', 'SHUFFLE', 'ROUND_ROBIN'];

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

  void _updateConfig(String key, dynamic value) {
    ref.read(ot.currentConfigProvider.notifier).updateConfig({key: value});
  }

  // Safe type converters for config values (API may return String or num)
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<void> _loadSamplesTree() async {
    final currentConfig = ref.read(ot.currentConfigProvider);
    // Use samples_dir from config, fall back to workspace/samples
    String samplesDirPath = currentConfig.samplesDir;
    if (samplesDirPath.isEmpty && currentConfig.workspaceDir.isNotEmpty) {
      samplesDirPath = '${currentConfig.workspaceDir}/samples';
    }
    if (samplesDirPath.isEmpty) return;

    final samplesDir = Directory(samplesDirPath);
    if (!await samplesDir.exists()) {
      setState(() => _samplesTree = []);
      return;
    }

    final nodes = <_TreeNode>[];
    await for (final entity in samplesDir.list()) {
      if (entity is Directory) {
        final name = entity.path.split('/').last;

        // Count images directly in this folder
        int imageCount = 0;
        await for (final file in entity.list()) {
          if (file is File && _isImage(file.path)) imageCount++;
        }

        nodes.add(_TreeNode(
          path: entity.path,
          name: name,
          type: 'prompt',
          imageCount: imageCount,
        ));
      }
    }

    setState(() => _samplesTree = nodes);
  }

  bool _isImage(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') ||
           ext.endsWith('.webp') || ext.endsWith('.gif') || ext.endsWith('.bmp');
  }

  Future<void> _loadSampleImages(String path) async {
    setState(() => _loadingImages = true);

    final dir = Directory(path);
    if (!await dir.exists()) {
      setState(() {
        _sampleImages = [];
        _loadingImages = false;
      });
      return;
    }

    final images = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File && _isImage(entity.path)) {
        images.add(entity.path);
      }
    }
    images.sort();

    setState(() {
      _sampleImages = images;
      _loadingImages = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final currentConfig = ref.watch(ot.currentConfigProvider);
    final trainingState = ref.watch(ot.trainingStateProvider);
    final config = currentConfig.config ?? {};

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Column(
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: colorScheme.onSurface,
              unselectedLabelColor: colorScheme.onSurface.withOpacity(0.5),
              indicatorColor: colorScheme.primary,
              indicatorWeight: 2,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Samples'),
                Tab(text: 'Config File'),
                Tab(text: 'Parameters'),
                Tab(text: 'LoRA / Adapters'),
                Tab(text: 'Diffusion 4K'),
                Tab(text: 'Buckets'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: currentConfig.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(colorScheme, currentConfig, trainingState),
                      _buildSamplesTab(colorScheme, currentConfig),
                      _buildConfigTab(colorScheme, config),
                      _buildParametersTab(colorScheme, config),
                      _buildLoraTab(colorScheme, config),
                      _buildDiffusion4kTab(colorScheme, config),
                      _buildBucketsTab(colorScheme, config),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ===================== OVERVIEW TAB =====================
  Widget _buildOverviewTab(ColorScheme colorScheme, ot.CurrentConfig currentConfig, ot.TrainingState trainingState) {
    final progress = trainingState.progress;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
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
            Text('Training Overview', style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            // Loaded preset
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Text('Loaded Preset:', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
                  const SizedBox(width: 8),
                  Text(currentConfig.presetName.isNotEmpty ? currentConfig.presetName : 'None',
                       style: TextStyle(color: colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('Model: ${currentConfig.modelType}',
                       style: TextStyle(color: colorScheme.primary, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Status grid
            Row(
              children: [
                _buildStatusItem('Status', trainingState.status.toUpperCase(), colorScheme,
                    color: trainingState.isTraining ? Colors.green : null),
                _buildStatusItem('Epoch', progress != null ? '${progress.currentEpoch}/${progress.totalEpochs}' : '-', colorScheme),
                _buildStatusItem('Step', progress != null ? '${progress.currentStep}/${progress.totalSteps}' : '-', colorScheme),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusItem('Loss', progress?.loss?.toStringAsFixed(4) ?? '-', colorScheme,
                    color: progress?.loss != null ? colorScheme.tertiary : null),
                _buildStatusItem('LR', currentConfig.learningRate.toString(), colorScheme),
                _buildStatusItem('ETA', progress?.remainingTime ?? '-', colorScheme),
              ],
            ),

            if (trainingState.isTraining && progress != null) ...[
              const SizedBox(height: 24),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.totalSteps > 0 ? progress.currentStep / progress.totalSteps : 0,
                  backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Elapsed: ${progress.elapsedTime ?? "-"}',
                       style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
                  Text('${(progress.totalSteps > 0 ? progress.currentStep / progress.totalSteps * 100 : 0).toStringAsFixed(1)}%',
                       style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // Quick config summary
            Text('Configuration Summary', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildInfoChip('Epochs: ${currentConfig.epochs}', colorScheme),
                _buildInfoChip('Batch: ${currentConfig.batchSize}', colorScheme),
                _buildInfoChip('Resolution: ${currentConfig.resolution}', colorScheme),
                _buildInfoChip('Optimizer: ${currentConfig.optimizer}', colorScheme),
                _buildInfoChip('Method: ${currentConfig.trainingMethod}', colorScheme),
                if (currentConfig.trainingMethod == 'LORA')
                  _buildInfoChip('LoRA Rank: ${currentConfig.loraRank}', colorScheme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, ColorScheme colorScheme, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 13)),
            Text(value, style: TextStyle(color: color ?? colorScheme.onSurface, fontSize: 13, fontWeight: color != null ? FontWeight.w600 : null)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontSize: 12)),
    );
  }

  // ===================== SAMPLES TAB =====================
  Widget _buildSamplesTab(ColorScheme colorScheme, ot.CurrentConfig currentConfig) {
    // Load samples tree if not loaded and workspace exists
    if (_samplesTree.isEmpty && currentConfig.workspaceDir.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSamplesTree());
    }

    return Row(
      children: [
        // Left Panel - Tree View
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(right: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
                ),
                child: Row(
                  children: [
                    Text('SAMPLES', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.refresh, size: 16, color: colorScheme.onSurface.withOpacity(0.5)),
                      onPressed: _loadSamplesTree,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Refresh samples',
                    ),
                  ],
                ),
              ),
              // Tree
              Expanded(
                child: _samplesTree.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_outlined, size: 48, color: colorScheme.onSurface.withOpacity(0.2)),
                            const SizedBox(height: 8),
                            Text('No samples found', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('Workspace: ${currentConfig.workspaceDir}',
                                 style: TextStyle(color: colorScheme.onSurface.withOpacity(0.3), fontSize: 10)),
                          ],
                        ),
                      )
                    : ListView(
                        children: _samplesTree.map((node) => _buildTreeNode(node, 0, colorScheme)).toList(),
                      ),
              ),
            ],
          ),
        ),

        // Right Panel - Image Gallery
        Expanded(
          child: Column(
            children: [
              // Header
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedName.isNotEmpty ? _selectedName : 'Select a prompt to view samples',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    if (_sampleImages.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('(${_sampleImages.length} images)', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                    ],
                  ],
                ),
              ),
              // Gallery
              Expanded(
                child: _selectedPath == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_outlined, size: 64, color: colorScheme.onSurface.withOpacity(0.15)),
                            const SizedBox(height: 16),
                            Text('Select a prompt from the tree to view samples', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 13)),
                          ],
                        ),
                      )
                    : _loadingImages
                        ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary))
                        : _sampleImages.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image_outlined, size: 64, color: colorScheme.onSurface.withOpacity(0.15)),
                                    const SizedBox(height: 16),
                                    Text('No images in this folder', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 13)),
                                  ],
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(16),
                                child: GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 5,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: _sampleImages.length,
                                  itemBuilder: (context, index) => _buildImageThumbnail(_sampleImages[index], colorScheme),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTreeNode(_TreeNode node, int depth, ColorScheme colorScheme) {
    final isExpanded = _expandedNodes.contains(node.path);
    final isSelected = _selectedPath == node.path;
    final hasChildren = node.children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (hasChildren) {
                if (isExpanded) {
                  _expandedNodes.remove(node.path);
                } else {
                  _expandedNodes.add(node.path);
                }
              }
              _selectedPath = node.path;
              _selectedName = node.name;
            });
            if (node.type == 'prompt') {
              _loadSampleImages(node.path);
            }
          },
          child: Container(
            padding: EdgeInsets.only(left: depth * 16.0 + 8, top: 6, bottom: 6, right: 8),
            decoration: BoxDecoration(
              color: isSelected ? colorScheme.primary.withOpacity(0.15) : null,
            ),
            child: Row(
              children: [
                if (hasChildren)
                  Icon(isExpanded ? Icons.expand_more : Icons.chevron_right, size: 14, color: colorScheme.onSurface.withOpacity(0.4))
                else
                  const SizedBox(width: 14),
                const SizedBox(width: 4),
                Icon(
                  node.type == 'directory' ? (isExpanded ? Icons.folder_open : Icons.folder) : Icons.image_outlined,
                  size: 16,
                  color: node.type == 'directory' ? Colors.amber : Colors.blue.shade400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(node.name, style: TextStyle(color: isSelected ? colorScheme.primary : colorScheme.onSurface, fontSize: 12), overflow: TextOverflow.ellipsis),
                ),
                if (node.imageCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest.withOpacity(0.5), borderRadius: BorderRadius.circular(4)),
                    child: Text('${node.imageCount}', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 10)),
                  ),
              ],
            ),
          ),
        ),
        if (hasChildren && isExpanded)
          ...node.children.map((child) => _buildTreeNode(child, depth + 1, colorScheme)),
      ],
    );
  }

  Widget _buildImageThumbnail(String imagePath, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: colorScheme.surfaceContainerHighest,
            child: Icon(Icons.broken_image, color: colorScheme.onSurface.withOpacity(0.3)),
          ),
        ),
      ),
    );
  }

  // ===================== CONFIG FILE TAB =====================
  Widget _buildConfigTab(ColorScheme colorScheme, Map<String, dynamic> config) {
    final currentConfig = ref.watch(ot.currentConfigProvider);
    final configJson = _prettyPrintJson(config);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('FULL CONFIGURATION (JSON)', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
                child: Text('Loaded: ${currentConfig.presetName}', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: SelectableText(
              configJson,
              style: TextStyle(color: Colors.cyan.shade300, fontSize: 12, fontFamily: 'monospace', height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  String _prettyPrintJson(Map<String, dynamic> json) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    } catch (e) {
      return json.toString();
    }
  }

  // ===================== PARAMETERS TAB =====================
  Widget _buildParametersTab(ColorScheme colorScheme, Map<String, dynamic> config) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildParamsColumn1(colorScheme, config)),
          const SizedBox(width: 16),
          Expanded(child: _buildParamsColumn2(colorScheme, config)),
          const SizedBox(width: 16),
          Expanded(child: _buildParamsColumn3(colorScheme, config)),
        ],
      ),
    );
  }

  Widget _buildParamsColumn1(ColorScheme colorScheme, Map<String, dynamic> config) {
    final optimizerConfig = config['optimizer'];
    final optimizer = optimizerConfig is Map ? optimizerConfig['optimizer'] as String? : optimizerConfig as String?;

    return Column(
      children: [
        _buildSection('OPTIMIZER & LR', [
          _buildDropdownField('Optimizer', optimizer ?? 'ADAMW', _optimizers,
            (v) => _updateConfig('optimizer', {'optimizer': v}), colorScheme),
          _buildDropdownField('LR Scheduler', config['learning_rate_scheduler'] as String? ?? 'CONSTANT', _schedulers,
            (v) => _updateConfig('learning_rate_scheduler', v), colorScheme),
          _buildTextField('Learning Rate', (config['learning_rate'] ?? 0.0003).toString(),
            (v) => _updateConfig('learning_rate', double.tryParse(v) ?? 0.0003), colorScheme),
          _buildNumberField('Warmup Steps', _parseInt(config['learning_rate_warmup_steps']) ?? 200,
            (v) => _updateConfig('learning_rate_warmup_steps', v), colorScheme),
          _buildTextField('LR Min Factor', (config['learning_rate_min_factor'] ?? 0).toString(),
            (v) => _updateConfig('learning_rate_min_factor', double.tryParse(v) ?? 0), colorScheme),
          _buildNumberField('LR Cycles', _parseInt(config['learning_rate_cycles']) ?? 1,
            (v) => _updateConfig('learning_rate_cycles', v), colorScheme),
          _buildNumberField('Epochs', _parseInt(config['epochs']) ?? 125,
            (v) => _updateConfig('epochs', v), colorScheme),
          _buildNumberField('Batch Size', _parseInt(config['batch_size']) ?? 2,
            (v) => _updateConfig('batch_size', v), colorScheme),
          _buildNumberField('Accumulation Steps', _parseInt(config['gradient_accumulation_steps']) ?? 1,
            (v) => _updateConfig('gradient_accumulation_steps', v), colorScheme),
          _buildDropdownField('LR Scaler', config['learning_rate_scaler'] as String? ?? 'NONE', _lrScalers,
            (v) => _updateConfig('learning_rate_scaler', v), colorScheme),
          _buildTextField('Clip Grad Norm', (config['max_grad_norm'] ?? 1).toString(),
            (v) => _updateConfig('max_grad_norm', double.tryParse(v) ?? 1), colorScheme),
          _buildTextField('Dropout Probability', (config['dropout_probability'] ?? 0).toString(),
            (v) => _updateConfig('dropout_probability', double.tryParse(v) ?? 0), colorScheme),
          _buildNumberField('Dataloader Threads', _parseInt(config['dataloader_threads']) ?? 1,
            (v) => _updateConfig('dataloader_threads', v), colorScheme),
        ], colorScheme),
        const SizedBox(height: 16),
        _buildSection('TEXT ENCODER', [
          _buildToggle('Train Text Encoder', config['train_text_encoder'] as bool? ?? false,
            (v) => _updateConfig('train_text_encoder', v), colorScheme),
          _buildTextField('Caption Dropout', (config['text_encoder_dropout_probability'] ?? 0.0).toString(),
            (v) => _updateConfig('text_encoder_dropout_probability', double.tryParse(v) ?? 0.0), colorScheme),
          _buildTextField('Stop Training After', config['text_encoder_stop_training_after'] as String? ?? '',
            (v) => _updateConfig('text_encoder_stop_training_after', v), colorScheme, hint: 'epochs or steps'),
          _buildTextField('TE Learning Rate', config['text_encoder_learning_rate'] as String? ?? '',
            (v) => _updateConfig('text_encoder_learning_rate', v), colorScheme, hint: 'Override base LR'),
          _buildNumberField('Clip Skip', config['clip_skip'] as int? ?? 0,
            (v) => _updateConfig('clip_skip', v), colorScheme),
        ], colorScheme),
        const SizedBox(height: 16),
        _buildSection('EMBEDDINGS', [
          _buildTextField('Embeddings LR', config['embedding_learning_rate'] as String? ?? '',
            (v) => _updateConfig('embedding_learning_rate', v), colorScheme),
          _buildToggle('Preserve Embedding Norm', config['preserve_embedding_norm'] as bool? ?? false,
            (v) => _updateConfig('preserve_embedding_norm', v), colorScheme),
        ], colorScheme),
      ],
    );
  }

  Widget _buildParamsColumn2(ColorScheme colorScheme, Map<String, dynamic> config) {
    return Column(
      children: [
        _buildSection('EMA & CHECKPOINTING', [
          _buildDropdownField('EMA', config['ema'] as String? ?? 'OFF', _emaModes,
            (v) => _updateConfig('ema', v), colorScheme),
          _buildTextField('EMA Decay', (config['ema_decay'] ?? 0.999).toString(),
            (v) => _updateConfig('ema_decay', double.tryParse(v) ?? 0.999), colorScheme),
          _buildNumberField('EMA Update Interval', _parseInt(config['ema_update_step_interval']) ?? 5,
            (v) => _updateConfig('ema_update_step_interval', v), colorScheme),
          _buildDropdownField('Gradient Checkpointing', config['gradient_checkpointing'] as String? ?? 'ON', _gradModes,
            (v) => _updateConfig('gradient_checkpointing', v), colorScheme),
          _buildTextField('Layer Offload Fraction', (config['layer_offload_fraction'] ?? 0).toString(),
            (v) => _updateConfig('layer_offload_fraction', double.tryParse(v) ?? 0), colorScheme),
          _buildDropdownField('Train Data Type', config['train_dtype'] as String? ?? 'BFLOAT_16', _dtypes,
            (v) => _updateConfig('train_dtype', v), colorScheme),
          _buildDropdownField('Fallback Data Type', config['fallback_train_dtype'] as String? ?? 'BFLOAT_16', _dtypes,
            (v) => _updateConfig('fallback_train_dtype', v), colorScheme),
          _buildToggle('Autocast Cache', config['autocast_cache'] as bool? ?? true,
            (v) => _updateConfig('autocast_cache', v), colorScheme),
          _buildTextField('Resolution', config['resolution']?.toString() ?? '512',
            (v) => _updateConfig('resolution', v), colorScheme),
          _buildNumberField('Frames (Video)', _parseInt(config['frames']) ?? 25,
            (v) => _updateConfig('frames', v), colorScheme),
          _buildToggle('Force Circular Padding', config['force_circular_padding'] as bool? ?? false,
            (v) => _updateConfig('force_circular_padding', v), colorScheme),
          _buildToggle('Async Offloading', config['async_offloading'] as bool? ?? true,
            (v) => _updateConfig('async_offloading', v), colorScheme),
          _buildToggle('Activation Offloading', config['activation_offloading'] as bool? ?? true,
            (v) => _updateConfig('activation_offloading', v), colorScheme),
          _buildToggle('Compile Model', config['compile'] as bool? ?? false,
            (v) => _updateConfig('compile', v), colorScheme),
          _buildToggle('Only Cache (skip training)', config['only_cache'] as bool? ?? false,
            (v) => _updateConfig('only_cache', v), colorScheme),
        ], colorScheme),
        const SizedBox(height: 16),
        _buildSection('TRANSFORMER / UNET', [
          _buildToggle('Train Transformer', config['train_unet'] as bool? ?? true,
            (v) => _updateConfig('train_unet', v), colorScheme),
          _buildTextField('Stop Training After', config['unet_stop_training_after'] as String? ?? '',
            (v) => _updateConfig('unet_stop_training_after', v), colorScheme, hint: 'epochs or steps'),
          _buildTextField('Transformer LR', config['unet_learning_rate'] as String? ?? '',
            (v) => _updateConfig('unet_learning_rate', v), colorScheme),
          _buildToggle('Force Attention Mask', config['force_attention_mask'] as bool? ?? false,
            (v) => _updateConfig('force_attention_mask', v), colorScheme),
          _buildTextField('Guidance Scale', (config['guidance_scale'] ?? 1.0).toString(),
            (v) => _updateConfig('guidance_scale', double.tryParse(v) ?? 1.0), colorScheme),
          _buildToggle('Rescale Noise + V-pred', config['rescale_noise_scheduler_to_zero_terminal_snr'] as bool? ?? false,
            (v) => _updateConfig('rescale_noise_scheduler_to_zero_terminal_snr', v), colorScheme),
        ], colorScheme),
      ],
    );
  }

  Widget _buildParamsColumn3(ColorScheme colorScheme, Map<String, dynamic> config) {
    return Column(
      children: [
        _buildSection('MASKED TRAINING', [
          _buildTextField('Unmasked Prob', (config['unmasked_probability'] ?? 0.1).toString(),
            (v) => _updateConfig('unmasked_probability', double.tryParse(v) ?? 0.1), colorScheme),
          _buildTextField('Unmasked Weight', (config['unmasked_weight'] ?? 0.1).toString(),
            (v) => _updateConfig('unmasked_weight', double.tryParse(v) ?? 0.1), colorScheme),
          _buildTextField('Prior Preservation Weight', (config['prior_preservation_weight'] ?? 0).toString(),
            (v) => _updateConfig('prior_preservation_weight', double.tryParse(v) ?? 0), colorScheme),
          _buildToggle('Normalize Masked Loss', config['normalize_masked_loss'] as bool? ?? false,
            (v) => _updateConfig('normalize_masked_loss', v), colorScheme),
          _buildToggle('Custom Conditioning Image', config['custom_conditioning_image'] as bool? ?? false,
            (v) => _updateConfig('custom_conditioning_image', v), colorScheme),
        ], colorScheme),
        const SizedBox(height: 16),
        _buildSection('LOSS', [
          _buildTextField('MSE', (config['mse_strength'] ?? 1.0).toString(),
            (v) => _updateConfig('mse_strength', double.tryParse(v) ?? 1.0), colorScheme),
          _buildTextField('MAE', (config['mae_strength'] ?? 0).toString(),
            (v) => _updateConfig('mae_strength', double.tryParse(v) ?? 0), colorScheme),
          _buildTextField('Log-Cosh', (config['log_cosh_strength'] ?? 0).toString(),
            (v) => _updateConfig('log_cosh_strength', double.tryParse(v) ?? 0), colorScheme),
          _buildTextField('Huber', (config['huber_strength'] ?? 0).toString(),
            (v) => _updateConfig('huber_strength', double.tryParse(v) ?? 0), colorScheme),
          _buildTextField('Huber Delta', (config['huber_delta'] ?? 1).toString(),
            (v) => _updateConfig('huber_delta', double.tryParse(v) ?? 1), colorScheme),
          _buildTextField('VB Loss', (config['vb_loss_strength'] ?? 1).toString(),
            (v) => _updateConfig('vb_loss_strength', double.tryParse(v) ?? 1), colorScheme),
          _buildDropdownField('Loss Weight Function', config['loss_weight_fn'] as String? ?? 'CONSTANT', _lossWeights,
            (v) => _updateConfig('loss_weight_fn', v), colorScheme),
          _buildTextField('Gamma (SNR/P2)', (config['loss_weight_strength'] ?? 5.0).toString(),
            (v) => _updateConfig('loss_weight_strength', double.tryParse(v) ?? 5.0), colorScheme),
          _buildDropdownField('Loss Scaler', config['loss_scaler'] as String? ?? 'NONE', _lossScalers,
            (v) => _updateConfig('loss_scaler', v), colorScheme),
        ], colorScheme),
        const SizedBox(height: 16),
        _buildSection('NOISE', [
          _buildTextField('Offset Noise', (config['offset_noise_weight'] ?? 0.0).toString(),
            (v) => _updateConfig('offset_noise_weight', double.tryParse(v) ?? 0.0), colorScheme),
          _buildTextField('Perturbation Noise', (config['perturbation_noise_weight'] ?? 0.0).toString(),
            (v) => _updateConfig('perturbation_noise_weight', double.tryParse(v) ?? 0.0), colorScheme),
          _buildDropdownField('Timestep Distribution', config['timestep_distribution'] as String? ?? 'LOGIT_NORMAL', _timestepDists,
            (v) => _updateConfig('timestep_distribution', v), colorScheme),
          _buildTextField('Min Noise', (config['min_noising_strength'] ?? 0).toString(),
            (v) => _updateConfig('min_noising_strength', double.tryParse(v) ?? 0), colorScheme),
          _buildTextField('Max Noise', (config['max_noising_strength'] ?? 1).toString(),
            (v) => _updateConfig('max_noising_strength', double.tryParse(v) ?? 1), colorScheme),
          _buildTextField('Noise Weight', (config['noising_weight'] ?? 0).toString(),
            (v) => _updateConfig('noising_weight', double.tryParse(v) ?? 0), colorScheme),
          _buildTextField('Noise Bias', (config['noising_bias'] ?? 0).toString(),
            (v) => _updateConfig('noising_bias', double.tryParse(v) ?? 0), colorScheme),
          _buildTextField('Timestep Shift', (config['timestep_shift'] ?? 0).toString(),
            (v) => _updateConfig('timestep_shift', double.tryParse(v) ?? 0), colorScheme),
          _buildToggle('Generalized Offset Noise', config['offset_noise_generalized'] as bool? ?? false,
            (v) => _updateConfig('offset_noise_generalized', v), colorScheme),
          _buildToggle('Force V-Prediction', config['force_v_prediction'] as bool? ?? false,
            (v) => _updateConfig('force_v_prediction', v), colorScheme),
          _buildToggle('Force Epsilon Prediction', config['force_epsilon_prediction'] as bool? ?? false,
            (v) => _updateConfig('force_epsilon_prediction', v), colorScheme),
          _buildToggle('Dynamic Timestep Shifting', config['dynamic_timestep_shifting'] as bool? ?? false,
            (v) => _updateConfig('dynamic_timestep_shifting', v), colorScheme),
        ], colorScheme),
        const SizedBox(height: 16),
        _buildSection('LAYER FILTER', [
          _buildDropdownField('Preset', config['layer_filter_preset'] as String? ?? 'full', ['full', 'attn', 'mlp', 'custom'],
            (v) => _updateConfig('layer_filter_preset', v), colorScheme),
          _buildTextField('Custom Filter', config['layer_filter_custom'] as String? ?? '',
            (v) => _updateConfig('layer_filter_custom', v), colorScheme),
          _buildToggle('Use Regex', config['layer_filter_use_regex'] as bool? ?? true,
            (v) => _updateConfig('layer_filter_use_regex', v), colorScheme),
        ], colorScheme),
        const SizedBox(height: 16),
        _buildSection('DEVICE & MULTI-GPU', [
          _buildTextField('Train Device', config['train_device'] as String? ?? 'cuda',
            (v) => _updateConfig('train_device', v), colorScheme),
          _buildTextField('Temp Device', config['temp_device'] as String? ?? 'cpu',
            (v) => _updateConfig('temp_device', v), colorScheme),
          _buildToggle('Multi-GPU Training', config['multi_gpu'] as bool? ?? false,
            (v) => _updateConfig('multi_gpu', v), colorScheme),
        ], colorScheme),
        const SizedBox(height: 16),
        _buildSection('BACKUP & SAVE', [
          _buildNumberField('Backup After', _parseInt(config['backup_after']) ?? 30,
            (v) => _updateConfig('backup_after', v), colorScheme),
          _buildDropdownField('Unit', config['backup_after_unit'] as String? ?? 'MINUTE', _timeUnits,
            (v) => _updateConfig('backup_after_unit', v), colorScheme),
          _buildToggle('Rolling Backup', config['rolling_backup'] as bool? ?? false,
            (v) => _updateConfig('rolling_backup', v), colorScheme),
          _buildToggle('Backup Before Save', config['backup_before_save'] as bool? ?? false,
            (v) => _updateConfig('backup_before_save', v), colorScheme),
          _buildNumberField('Save Every', _parseInt(config['save_every']) ?? 0,
            (v) => _updateConfig('save_every', v), colorScheme),
          _buildDropdownField('Unit', config['save_every_unit'] as String? ?? 'NEVER', _timeUnits,
            (v) => _updateConfig('save_every_unit', v), colorScheme),
          _buildTextField('Filename Prefix', config['output_model_filename_prefix'] as String? ?? 'model_',
            (v) => _updateConfig('output_model_filename_prefix', v), colorScheme),
        ], colorScheme),
      ],
    );
  }

  // ===================== LORA TAB =====================
  static const _peftTypes = ['LoRA - Low-Rank Adaptation', 'DoRA - Weight Decomposition', 'LoHa - Hadamard Product', 'LoKr - Kronecker Product', 'LyCORIS'];
  static const _loraTargets = ['Custom Pattern...', 'TRANSFORMER', 'TEXT_ENCODER', 'TEXT_ENCODER_2', 'TEXT_ENCODER_AND_TRANSFORMER', 'FULL', 'EMBEDDING'];

  Widget _buildLoraTab(ColorScheme colorScheme, Map<String, dynamic> config) {
    final loraRank = _parseInt(config['lora_rank']) ?? 16;
    final loraAlpha = config['lora_alpha'] ?? 16;
    final loraDropout = config['lora_dropout'] ?? 0;
    final adapterName = config['adapter_name'] as String? ?? 'Primary Adapter';
    final peftType = config['peft_type'] as String? ?? 'LoRA - Low-Rank Adaptation';
    final loraTarget = config['lora_target'] as String? ?? 'Custom Pattern...';
    final customPattern = config['lora_custom_pattern'] as String? ?? '';
    final enableDora = config['enable_dora'] as bool? ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers_outlined, size: 20, color: colorScheme.onSurface.withOpacity(0.6)),
              const SizedBox(width: 8),
              Text('LoRA / PEFT Adapters', style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {},
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                // Header row with checkbox, number, name, type info
                Row(
                  children: [
                    Checkbox(
                      value: true,
                      onChanged: (_) {},
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Text('#1', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('Primary Adapter', style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('LoRA', style: TextStyle(color: colorScheme.primary, fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    Text('r=$loraRank α=$loraAlpha', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                    const Spacer(),
                    Icon(Icons.expand_less, color: colorScheme.onSurface.withOpacity(0.5)),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: colorScheme.outlineVariant.withOpacity(0.3)),
                const SizedBox(height: 16),
                _buildTextField('Adapter Name', adapterName,
                  (v) => _updateConfig('adapter_name', v), colorScheme),
                const SizedBox(height: 12),
                _buildDropdownField('PEFT Type', peftType, _peftTypes,
                  (v) => _updateConfig('peft_type', v), colorScheme),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildNumberField('Rank', loraRank, (v) => _updateConfig('lora_rank', v), colorScheme)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Alpha', loraAlpha.toString(), (v) => _updateConfig('lora_alpha', double.tryParse(v) ?? 16), colorScheme)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Dropout', loraDropout.toString(), (v) => _updateConfig('lora_dropout', double.tryParse(v) ?? 0.0), colorScheme)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDropdownField('Target Layers', loraTarget, _loraTargets,
                  (v) => _updateConfig('lora_target', v), colorScheme),
                const SizedBox(height: 12),
                _buildTextField('Custom Pattern (regex)', customPattern,
                  (v) => _updateConfig('lora_custom_pattern', v), colorScheme,
                  hint: '^(?=.*attention)(?!.*refiner).*,^(?=.*feed_forward)(?!.*refiner).*'),
                const SizedBox(height: 12),
                _buildToggle('Enable DoRA (Weight Decomposition)', enableDora,
                  (v) => _updateConfig('enable_dora', v), colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== DIFFUSION 4K TAB =====================
  Widget _buildDiffusion4kTab(ColorScheme colorScheme, Map<String, dynamic> config) {
    final enabled = config['diffusion_4k_enabled'] as bool? ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Diffusion-4K Wavelet Loss', style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Enhance high-frequency detail preservation using wavelet-based loss (from arXiv:2503.18352)',
                            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 13)),
                        ],
                      ),
                    ),
                    Switch(value: enabled, onChanged: (v) => _updateConfig('diffusion_4k_enabled', v), activeColor: Colors.green),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('4K Resolution Presets', style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Quick resolution presets for high-resolution training and sampling',
                  style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 13)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _build4KPresetButton('1024', config, colorScheme),
                    const SizedBox(width: 12),
                    _build4KPresetButton('2048', config, colorScheme),
                    const SizedBox(width: 12),
                    _build4KPresetButton('4096 (4K)', config, colorScheme, value: '4096'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _build4KPresetButton(String label, Map<String, dynamic> config, ColorScheme colorScheme, {String? value}) {
    final resolution = config['resolution']?.toString() ?? '512';
    final targetValue = value ?? label;
    final isSelected = resolution == targetValue;

    return InkWell(
      onTap: () => _updateConfig('resolution', targetValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.2) : colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(
          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        )),
      ),
    );
  }

  static const _balancingModes = ['OVERSAMPLE', 'UNDERSAMPLE', 'OFF'];

  // ===================== BUCKETS TAB =====================
  Widget _buildBucketsTab(ColorScheme colorScheme, Map<String, dynamic> config) {
    final enabled = config['aspect_ratio_bucketing'] as bool? ?? true;
    final preset = config['bucket_preset'] as String? ?? 'default';
    final quantization = config['bucket_quantization'] as int? ?? 64;
    final aspectTolerance = config['aspect_tolerance'] ?? 0.152;
    final balancingMode = config['bucket_balancing_mode'] as String? ?? 'OVERSAMPLE';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Aspect Ratio Bucketing', style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Group images by aspect ratio to minimize cropping', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 13)),
                        ],
                      ),
                    ),
                    Switch(value: enabled, onChanged: (v) => _updateConfig('aspect_ratio_bucketing', v), activeColor: Colors.green),
                  ],
                ),
              ],
            ),
          ),
          if (enabled) ...[
            const SizedBox(height: 16),
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
                  Text('Bucket Parameters', style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildDropdownField('Preset', preset, _bucketPresets, (v) => _updateConfig('bucket_preset', v), colorScheme)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDropdownField('Balancing Mode', balancingMode, _balancingModes, (v) => _updateConfig('bucket_balancing_mode', v), colorScheme)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildNumberField('Quantization', quantization, (v) => _updateConfig('bucket_quantization', v), colorScheme)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Aspect Tolerance', aspectTolerance.toString(), (v) => _updateConfig('aspect_tolerance', double.tryParse(v) ?? 0.152), colorScheme)),
                    ],
                  ),
                  _buildToggle('Repeat Small Buckets', config['bucket_repeat_small'] as bool? ?? true,
                    (v) => _updateConfig('bucket_repeat_small', v), colorScheme),
                  _buildToggle('Log Dropped Samples', config['bucket_log_dropped'] as bool? ?? true,
                    (v) => _updateConfig('bucket_log_dropped', v), colorScheme),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===================== HELPER WIDGETS =====================
  Widget _buildSection(String title, List<Widget> children, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String value, Function(String) onChanged, ColorScheme colorScheme, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: value),
            style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.3)),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField(String label, int value, Function(int) onChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: value.toString()),
            keyboardType: TextInputType.number,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: (v) => onChanged(int.tryParse(v) ?? value),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> options, Function(String) onChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: options.contains(value) ? value : options.first,
                isExpanded: true,
                dropdownColor: colorScheme.surface,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                onChanged: (v) => onChanged(v!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, Function(bool) onChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(color: colorScheme.onSurface, fontSize: 13))),
          SizedBox(
            height: 24,
            child: Switch(value: value, onChanged: onChanged, activeColor: Colors.green, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
        ],
      ),
    );
  }
}

// Tree node model for samples browser
class _TreeNode {
  final String path;
  final String name;
  final String type;
  final List<_TreeNode> children;
  final int imageCount;

  _TreeNode({
    required this.path,
    required this.name,
    this.type = 'directory',
    this.children = const [],
    this.imageCount = 0,
  });
}
