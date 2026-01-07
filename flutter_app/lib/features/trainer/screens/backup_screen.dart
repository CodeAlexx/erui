import 'package:flutter/material.dart';

/// Backup Screen - Backup & Save Settings
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  // Backup settings
  int _backupAfter = 30;
  String _backupUnit = 'MINUTE';
  bool _rollingBackup = false;
  int _rollingBackupCount = 3;
  bool _backupBeforeSave = true;

  // Save settings
  int _saveEvery = 0;
  String _saveUnit = 'NEVER';
  int _skipFirst = 0;
  String _filenamePrefix = '';

  static const _timeUnits = ['NEVER', 'EPOCH', 'STEP', 'SECOND', 'MINUTE'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Backup & Save Settings', style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),

            // Backup Settings Section
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
                      Text('BACKUP SETTINGS', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text('backup now', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Backup After
                  _buildFieldRow(
                    'Backup After',
                    Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: TextEditingController(text: _backupAfter.toString()),
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                            decoration: _inputDecoration(colorScheme),
                            onChanged: (v) => setState(() => _backupAfter = int.tryParse(v) ?? 30),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildDropdown(_backupUnit, _timeUnits.where((u) => u != 'NEVER').toList(), (v) => setState(() => _backupUnit = v), colorScheme),
                      ],
                    ),
                    colorScheme,
                  ),
                  const SizedBox(height: 16),

                  // Rolling Backup
                  _buildFieldRow(
                    'Rolling Backup',
                    Switch(
                      value: _rollingBackup,
                      onChanged: (v) => setState(() => _rollingBackup = v),
                      activeColor: Colors.teal,
                    ),
                    colorScheme,
                  ),
                  const SizedBox(height: 16),

                  // Rolling Backup Count
                  _buildFieldRow(
                    'Rolling Backup Count',
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: TextEditingController(text: _rollingBackupCount.toString()),
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                        decoration: _inputDecoration(colorScheme),
                        enabled: _rollingBackup,
                        onChanged: (v) => setState(() => _rollingBackupCount = int.tryParse(v) ?? 3),
                      ),
                    ),
                    colorScheme,
                  ),
                  const SizedBox(height: 16),

                  // Backup Before Save
                  _buildFieldRow(
                    'Backup Before Save',
                    Switch(
                      value: _backupBeforeSave,
                      onChanged: (v) => setState(() => _backupBeforeSave = v),
                      activeColor: Colors.teal,
                    ),
                    colorScheme,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save Settings Section
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
                      Text('SAVE SETTINGS', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text('save now', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Save Every
                  _buildFieldRow(
                    'Save Every',
                    Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: TextEditingController(text: _saveEvery.toString()),
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                            decoration: _inputDecoration(colorScheme),
                            onChanged: (v) => setState(() => _saveEvery = int.tryParse(v) ?? 0),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildDropdown(_saveUnit, _timeUnits, (v) => setState(() => _saveUnit = v), colorScheme),
                      ],
                    ),
                    colorScheme,
                  ),
                  const SizedBox(height: 16),

                  // Skip First
                  _buildFieldRow(
                    'Skip First',
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: TextEditingController(text: _skipFirst.toString()),
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                        decoration: _inputDecoration(colorScheme),
                        onChanged: (v) => setState(() => _skipFirst = int.tryParse(v) ?? 0),
                      ),
                    ),
                    colorScheme,
                  ),
                  const SizedBox(height: 16),

                  // Save Filename Prefix
                  _buildFieldRow(
                    'Save Filename Prefix',
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: _filenamePrefix),
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                        decoration: _inputDecoration(colorScheme).copyWith(hintText: 'Enter prefix for saved files...'),
                        onChanged: (v) => setState(() => _filenamePrefix = v),
                      ),
                    ),
                    colorScheme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow(String label, Widget field, ColorScheme colorScheme) {
    return Row(
      children: [
        SizedBox(
          width: 180,
          child: Text(label, style: TextStyle(color: colorScheme.onSurface, fontSize: 13)),
        ),
        field,
      ],
    );
  }

  Widget _buildDropdown(String value, List<String> options, Function(String) onChanged, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(value) ? value : options.first,
          dropdownColor: colorScheme.surface,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(ColorScheme colorScheme) {
    return InputDecoration(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }
}
