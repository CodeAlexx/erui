import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/trainer_state_provider.dart';
import '../../../services/onetrainer_service.dart' as ot;

/// Dashboard Screen - Training overview with GPU stats and controls
/// Updates via WebSocket streaming from OneTrainer
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Console logs
  final List<_LogEntry> _logs = [];
  DateTime _lastUpdated = DateTime.now();

  // Loss chart data
  final List<FlSpot> _lossHistory = [];
  final List<FlSpot> _smoothLossHistory = [];
  int _lastTrackedStep = 0;

  // GPU data (will be fetched from API)
  String _gpuName = 'NVIDIA GeForce RTX 4090';
  int _gpuTemp = 45;
  int _gpuFan = 30;
  double _gpuPower = 65.0;
  double _gpuPowerLimit = 450.0;
  int _gpuUtil = 0;
  double _vramUsed = 1.2;
  double _vramTotal = 24.0;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _fetchGpuInfo(),
      _fetchTrainingStatus(),
    ]);
  }

  Future<void> _fetchTrainingStatus() async {
    final service = ref.read(ot.oneTrainerServiceProvider);
    await service.checkTrainingStatus();
  }

  Future<void> _fetchGpuInfo() async {
    final service = ref.read(ot.oneTrainerServiceProvider);
    final resources = await service.getSystemResources();
    if (resources != null && mounted) {
      // API returns gpus array, get first GPU
      final gpus = resources['gpus'] as List<dynamic>?;
      if (gpus != null && gpus.isNotEmpty) {
        final gpu = gpus[0] as Map<String, dynamic>;
        setState(() {
          _lastUpdated = DateTime.now();
          _gpuName = gpu['name'] as String? ?? _gpuName;
          _gpuTemp = (gpu['temperature'] as num?)?.toInt() ?? _gpuTemp;
          _gpuFan = (gpu['fan_speed'] as num?)?.toInt() ?? _gpuFan;
          _gpuUtil = (gpu['utilization'] as num?)?.toInt() ?? _gpuUtil;
          _gpuPower = (gpu['power_draw'] as num?)?.toDouble() ?? _gpuPower;
          _gpuPowerLimit = (gpu['power_limit'] as num?)?.toDouble() ?? _gpuPowerLimit;
          // Memory is in bytes, convert to GB
          final memAllocated = (gpu['memory_allocated'] as num?)?.toDouble() ?? 0;
          final memTotal = (gpu['memory_total'] as num?)?.toDouble() ?? 1;
          _vramUsed = memAllocated / (1024 * 1024 * 1024);  // bytes to GB
          _vramTotal = memTotal / (1024 * 1024 * 1024);      // bytes to GB
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final presetState = ref.watch(trainerPresetProvider);
    final trainingState = ref.watch(ot.trainingStateProvider);
    final service = ref.watch(ot.oneTrainerServiceProvider);

    final isTraining = trainingState.isTraining;
    final progress = trainingState.progress;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with controls
            Row(
              children: [
                Text('Dashboard', style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),

                // Preset display (read-only, shows current preset from top bar)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.save_outlined, size: 14, color: colorScheme.onSurface.withOpacity(0.5)),
                      const SizedBox(width: 8),
                      Text(
                        presetState.presetName.isEmpty ? 'No preset selected' : presetState.presetName,
                        style: TextStyle(
                          color: presetState.presetName.isEmpty
                            ? colorScheme.onSurface.withOpacity(0.4)
                            : colorScheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Model Type badge
                if (presetState.modelType.isNotEmpty)
                  _buildBadge(presetState.modelType, _getModelColor(presetState.modelType)),

                const SizedBox(width: 8),

                // Training Method badge
                if (presetState.trainingMethod.isNotEmpty)
                  _buildBadge(presetState.trainingMethod, colorScheme.primary),

                const SizedBox(width: 16),

                // Start/Stop Training button
                if (!isTraining)
                  ElevatedButton.icon(
                    onPressed: presetState.presetName.isEmpty ? null : () => _startTraining(service, presetState),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Start Training'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      disabledBackgroundColor: colorScheme.primary.withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => _stopTraining(service),
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('Stop Training'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),

                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _refreshAll,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
                Text('Last updated: ${_formatTime(_lastUpdated)}', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 24),

            // GPU Monitor
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // GPU Name + Stats Row
                  Row(
                    children: [
                      Icon(Icons.memory, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(_gpuName, style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      _buildGpuStat(Icons.thermostat, '$_gpuTemp°C', _gpuTemp > 80 ? colorScheme.error : _gpuTemp > 65 ? colorScheme.tertiary : colorScheme.primary),
                      const SizedBox(width: 16),
                      _buildGpuStat(Icons.air, '$_gpuFan%', colorScheme.primary),
                      const SizedBox(width: 16),
                      _buildGpuStat(Icons.bolt, '${_gpuPower.toInt()}/${_gpuPowerLimit.toInt()}W', colorScheme.tertiary),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress bars
                  Row(
                    children: [
                      Expanded(child: _buildProgressBar('GPU', _gpuUtil.toDouble(), 100, colorScheme.primary, colorScheme)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildProgressBar('VRAM', _vramUsed, _vramTotal, colorScheme.secondary, colorScheme, suffix: 'GB')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildProgressBar('Power', _gpuPower, _gpuPowerLimit, colorScheme.tertiary, colorScheme, suffix: '%')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Training Overview (like OneTrainer)
            _buildTrainingOverview(colorScheme, presetState, trainingState, progress),
            const SizedBox(height: 16),

            // Loss Chart
            _buildLossChart(colorScheme, progress),
            const SizedBox(height: 16),

            // Training Console
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.terminal, size: 16, color: colorScheme.onSurface.withOpacity(0.5)),
                        const SizedBox(width: 8),
                        Text('TRAINING CONSOLE', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          onPressed: () => setState(() => _logs.clear()),
                          color: colorScheme.onSurface.withOpacity(0.4),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      ],
                    ),
                  ),

                  // Progress summary (when training)
                  if (isTraining && progress != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.1),
                        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _buildStatChip('Epoch', '${progress.currentEpoch}/${progress.totalEpochs}', colorScheme),
                              _buildStatChip('Step', '${progress.currentStep}/${progress.totalSteps}', colorScheme),
                              _buildStatChip('Loss', progress.loss?.toStringAsFixed(4) ?? '--', colorScheme, color: colorScheme.tertiary),
                              _buildStatChip('Smooth Loss', progress.smoothLoss?.toStringAsFixed(4) ?? '--', colorScheme, color: colorScheme.primary),
                              _buildStatChip('Speed', progress.samplesPerSecond != null ? '${progress.samplesPerSecond!.toStringAsFixed(2)} it/s' : '--', colorScheme, color: colorScheme.secondary),
                              _buildStatChip('Elapsed', progress.elapsedTime ?? '--', colorScheme),
                              _buildStatChip('ETA', progress.remainingTime ?? '--', colorScheme, color: colorScheme.tertiary),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress.totalSteps > 0 ? progress.currentStep / progress.totalSteps : 0,
                              backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Console output (logs from training)
                  Container(
                    height: 300,
                    padding: const EdgeInsets.all(16),
                    child: _buildLogsView(colorScheme, trainingState),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Training Status - OneTrainer style
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TRAINING STATUS', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  if (isTraining && progress != null) ...[
                    // Status line with preset name
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text('Training ...', style: TextStyle(color: colorScheme.primary, fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 12),
                        Text('(${presetState.presetName})', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Stats row - Progress, Epoch Step, Epoch, Step, Elapsed
                    Row(
                      children: [
                        _buildStatusItem('Progress', '${(progress.totalSteps > 0 ? (progress.currentStep / progress.totalSteps * 100).toInt() : 0)}%', colorScheme),
                        _buildStatusItem('Epoch Step', '${progress.epochStep} of ${progress.epochLength > 0 ? progress.epochLength : "--"}', colorScheme),
                        _buildStatusItem('Epoch', '${progress.currentEpoch}/${progress.totalEpochs}', colorScheme),
                        _buildStatusItem('Step', '${progress.currentStep}/${progress.totalSteps}', colorScheme),
                        _buildStatusItem('Elapsed', progress.elapsedTime ?? '--', colorScheme),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ETA row
                    Row(
                      children: [
                        Text('ETA: ', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                        Text(progress.remainingTime ?? '--', style: TextStyle(color: colorScheme.tertiary, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.hourglass_empty, size: 32, color: colorScheme.onSurface.withOpacity(0.2)),
                            const SizedBox(height: 8),
                            Text('No training in progress', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 14)),
                            if (presetState.presetName.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text('Select a preset from the top bar to start', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.3), fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsView(ColorScheme colorScheme, ot.TrainingState trainingState) {
    final allLogs = [..._logs.map((e) => e.message), ...trainingState.logs];

    if (allLogs.isEmpty) {
      return Center(
        child: Text(
          'No training output yet. Start a training job to see progress here.',
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
        ),
      );
    }

    return ListView.builder(
      itemCount: allLogs.length,
      itemBuilder: (context, index) {
        final log = allLogs[index];
        final cs = Theme.of(context).colorScheme;
        Color textColor = cs.onSurface.withOpacity(0.7);
        if (log.contains('step:')) textColor = cs.secondary;
        else if (log.contains('epoch')) textColor = cs.tertiary;
        else if (log.contains('sampling')) textColor = cs.primary;
        else if (log.contains('error') || log.contains('Error')) textColor = cs.error;

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            log,
            style: TextStyle(color: textColor, fontSize: 12, fontFamily: 'monospace'),
          ),
        );
      },
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }

  Color _getModelColor(String modelType) {
    const colors = {
      'Qwen': Color(0xFF9333EA),
      'Qwen-Edit': Color(0xFF7C3AED),
      'Kandinsky': Color(0xFFE11D48),
      'Flux': Color(0xFF2563EB),
      'SDXL': Color(0xFF16A34A),
      'SD3': Color(0xFF0D9488),
      'SD': Color(0xFF4B5563),
      'Chroma': Color(0xFFDB2777),
      'Z-Image': Color(0xFFEA580C),
      'PixArt': Color(0xFF0891B2),
      'Hunyuan': Color(0xFFDC2626),
      'HiDream': Color(0xFF4F46E5),
      'Wan': Color(0xFF059669),
    };
    return colors[modelType] ?? const Color(0xFF6B7280);
  }

  Widget _buildGpuStat(IconData icon, String value, Color color) {
    return Builder(builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: cs.onSurface, fontSize: 12)),
        ],
      );
    });
  }

  Widget _buildProgressBar(String label, double value, double max, Color color, ColorScheme colorScheme, {String? suffix}) {
    final percentage = max > 0 ? (value / max * 100) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
            Text(
              suffix == 'GB' ? '${value.toStringAsFixed(1)}/${max.toStringAsFixed(0)}GB' : '${percentage.toInt()}%',
              style: TextStyle(color: colorScheme.onSurface, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, ColorScheme colorScheme, {Color? color}) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color ?? colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, ColorScheme colorScheme) {
    return Expanded(
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
          Text(value, style: TextStyle(color: colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTrainingOverview(ColorScheme colorScheme, TrainerPresetState presetState, ot.TrainingState trainingState, ot.TrainingProgress? progress) {
    final currentConfig = ref.watch(ot.currentConfigProvider);
    final config = currentConfig.config ?? {};

    // Config values for summary
    final epochs = config['epochs'] ?? 100;
    final batchSize = config['batch_size'] ?? 1;
    final resolution = config['resolution'] ?? '512';
    final optimizer = config['optimizer']?['optimizer'] ?? 'ADAMW';
    final method = config['training_method'] ?? 'LORA';
    final loraRank = config['lora_rank'] ?? 16;
    final lr = config['learning_rate'] ?? 0.0001;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text('Training Overview', style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (presetState.presetName.isNotEmpty)
                Text('Loaded Preset: ${presetState.presetName}', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
              const SizedBox(width: 24),
              Text('Model: ${presetState.modelType}', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),

          // Status line with progress
          Row(
            children: [
              Text('Status', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: trainingState.isTraining ? colorScheme.primary.withOpacity(0.2) : colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    trainingState.status.isNotEmpty ? trainingState.status : (trainingState.isTraining ? 'Training...' : 'Idle'),
                    style: TextStyle(color: trainingState.isTraining ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text('${progress?.currentEpoch ?? 0}/${progress?.totalEpochs ?? epochs}', style: TextStyle(color: colorScheme.onSurface, fontSize: 12)),
              Text('Epoch', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
              const SizedBox(width: 16),
              Text('${progress?.currentStep ?? 0}/${progress?.totalSteps ?? 0}', style: TextStyle(color: colorScheme.onSurface, fontSize: 12)),
              Text('Step', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),

          // Loss, LR, ETA row
          Row(
            children: [
              _buildOverviewStat('Loss', progress?.loss?.toStringAsFixed(4) ?? '--', colorScheme),
              _buildOverviewStat('LR', lr.toString(), colorScheme),
              _buildOverviewStat('ETA', progress?.remainingTime ?? '--', colorScheme),
            ],
          ),
          const SizedBox(height: 8),

          // Elapsed + Progress %
          Row(
            children: [
              _buildOverviewStat('Elapsed', progress?.elapsedTime ?? '--', colorScheme),
              const Spacer(),
              Text('${progress != null && progress.totalSteps > 0 ? (progress.currentStep / progress.totalSteps * 100).toStringAsFixed(1) : '0.0'}%',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),

          // Configuration Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Configuration Summary', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildConfigChip('Epochs: $epochs', colorScheme),
                    _buildConfigChip('Batch: $batchSize', colorScheme),
                    _buildConfigChip('Resolution: $resolution', colorScheme),
                    _buildConfigChip('Optimizer: $optimizer', colorScheme),
                    _buildConfigChip('Method: $method', colorScheme),
                    _buildConfigChip('LoRA Rank: $loraRank', colorScheme),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat(String label, String value, ColorScheme colorScheme) {
    return Expanded(
      child: Row(
        children: [
          Text('$label ', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
          Text(value, style: TextStyle(color: colorScheme.onSurface, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildConfigChip(String text, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8), fontSize: 11)),
    );
  }

  Widget _buildLossChart(ColorScheme colorScheme, ot.TrainingProgress? progress) {
    // Update loss history when progress changes
    if (progress != null && progress.currentStep > _lastTrackedStep) {
      _lastTrackedStep = progress.currentStep;
      if (progress.loss != null) {
        _lossHistory.add(FlSpot(progress.currentStep.toDouble(), progress.loss!));
        // Keep last 100 points for performance
        if (_lossHistory.length > 100) _lossHistory.removeAt(0);
      }
      if (progress.smoothLoss != null) {
        _smoothLossHistory.add(FlSpot(progress.currentStep.toDouble(), progress.smoothLoss!));
        if (_smoothLossHistory.length > 100) _smoothLossHistory.removeAt(0);
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.show_chart, size: 16, color: colorScheme.onSurface.withOpacity(0.5)),
              const SizedBox(width: 8),
              Text('LOSS CHART', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
              const Spacer(),
              // Legend
              Container(width: 12, height: 3, color: colorScheme.tertiary),
              const SizedBox(width: 4),
              Text('Loss', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 10)),
              const SizedBox(width: 12),
              Container(width: 12, height: 3, color: colorScheme.primary),
              const SizedBox(width: 4),
              Text('Smooth Loss', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: _lossHistory.isEmpty && _smoothLossHistory.isEmpty
              ? Center(
                  child: Text('No loss data yet', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.3), fontSize: 12)),
                )
              : LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 0.1,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: colorScheme.outlineVariant.withOpacity(0.2),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) => Text(
                            value.toStringAsFixed(2),
                            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 9),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      if (_lossHistory.isNotEmpty)
                        LineChartBarData(
                          spots: _lossHistory,
                          isCurved: true,
                          color: colorScheme.tertiary,
                          barWidth: 2,
                          dotData: FlDotData(show: false),
                        ),
                      if (_smoothLossHistory.isNotEmpty)
                        LineChartBarData(
                          spots: _smoothLossHistory,
                          isCurved: true,
                          color: colorScheme.primary,
                          barWidth: 2,
                          dotData: FlDotData(show: false),
                        ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  Future<void> _startTraining(ot.OneTrainerService service, TrainerPresetState presetState) async {
    // Get current edited config from provider - this includes all UI edits
    final currentConfig = ref.read(ot.currentConfigProvider);
    final config = currentConfig.config;

    if (config == null || config.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('No config loaded - please select a preset first'), backgroundColor: Theme.of(context).colorScheme.error),
      );
      return;
    }

    setState(() {
      _logs.add(_LogEntry('info', 'Saving config and starting training...'));
    });

    // Save the current (possibly edited) config to a temp file
    // This ensures any UI edits are used in training
    final tempPath = await service.saveTempConfig(config);
    if (tempPath == null) {
      if (mounted) {
        setState(() {
          _logs.add(_LogEntry('error', 'Failed to save config for training'));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Failed to save config for training'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
      return;
    }

    setState(() {
      _logs.add(_LogEntry('info', 'Starting training with ${presetState.presetName}...'));
    });

    final result = await service.startTraining(tempPath);
    if (mounted) {
      setState(() {
        _logs.add(_LogEntry(result.success ? 'info' : 'error', result.message));
      });
      // No snackbar - status shows in Training Overview
    }
  }

  Future<void> _stopTraining(ot.OneTrainerService service) async {
    setState(() {
      _logs.add(_LogEntry('info', 'Stopping training...'));
    });

    final result = await service.stopTraining();
    if (mounted) {
      setState(() {
        _logs.add(_LogEntry(result.success ? 'info' : 'error', result.message));
      });
      // No snackbar - status shows in Training Overview
    }
  }
}

class _LogEntry {
  final String type;
  final String message;
  _LogEntry(this.type, this.message);
}
