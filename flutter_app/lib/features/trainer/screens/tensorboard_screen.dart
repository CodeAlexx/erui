import 'package:flutter/material.dart';

/// TensorBoard Screen - TensorBoard integration for training visualization
class TensorBoardScreen extends StatefulWidget {
  const TensorBoardScreen({super.key});

  @override
  State<TensorBoardScreen> createState() => _TensorBoardScreenState();
}

class _TensorBoardScreenState extends State<TensorBoardScreen> {
  bool _isRunning = false;
  int _port = 6006;
  String _logDirectory = 'All Logs (workspace)';

  // Mock training logs
  final List<Map<String, dynamic>> _logs = [
    {
      'name': '2025-04-22_19-35-00',
      'path': '/home/alex/workspace/tensorboard/2025-04-22_19-35-00',
      'age': '259d ago',
      'events': 1,
    },
  ];

  static const _logDirectories = [
    'All Logs (workspace)',
    'Current Training',
    'Custom Directory...',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.insights, size: 24, color: colorScheme.onSurface.withOpacity(0.6)),
                    const SizedBox(width: 12),
                    Text('TensorBoard', style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: () {},
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Server Status
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _isRunning ? Colors.green : colorScheme.onSurface.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isRunning ? 'TensorBoard Server Running' : 'TensorBoard Server Stopped',
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _isRunning = !_isRunning),
                        icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow, size: 18),
                        label: Text(_isRunning ? 'Stop TensorBoard' : 'Start TensorBoard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRunning ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                        ),
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
                      Text('Settings', style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          // Port
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Port', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: TextEditingController(text: _port.toString()),
                                  style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  onChanged: (v) => setState(() => _port = int.tryParse(v) ?? 6006),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Log Directory
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Log Directory', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
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
                                      value: _logDirectory,
                                      isExpanded: true,
                                      dropdownColor: colorScheme.surface,
                                      style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                                      items: _logDirectories.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                                      onChanged: (v) => setState(() => _logDirectory = v!),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Training Logs
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
                      Text('Training Logs', style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('/home/alex/workspace/tensorboard', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 11)),
                      const SizedBox(height: 16),

                      // Logs list
                      ..._logs.map((log) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.insert_chart_outlined, size: 20, color: colorScheme.onSurface.withOpacity(0.4)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(log['name'], style: TextStyle(color: colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 2),
                                  Text(log['path'], style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 11)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 12, color: colorScheme.onSurface.withOpacity(0.3)),
                                    const SizedBox(width: 4),
                                    Text(log['age'], style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text('${log['events']} event file', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.3), fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      )),

                      if (_logs.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text('No training logs found', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4))),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // About TensorBoard
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
                      Text('About TensorBoard', style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text(
                        'TensorBoard provides visualization of training metrics including loss curves, learning rate schedules, and sample images generated during training.',
                        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'To enable TensorBoard logging for your training runs, make sure the "TensorBoard" option is enabled in your training configuration.',
                        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text('Logs are stored in: ', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                          Text('/home/alex/workspace/tensorboard', style: TextStyle(color: colorScheme.primary, fontSize: 12, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
