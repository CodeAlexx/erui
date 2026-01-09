import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/storage_service.dart';
import 'settings_section.dart';

/// Storage keys for output path settings
class OutputPathStorageKeys {
  static const String baseOutputDirectory = 'output_base_directory';
  static const String outputPathFormat = 'output_path_format';
  static const String autoCreateSubfolders = 'output_auto_create_subfolders';
}

/// Available tokens for path formatting
class PathToken {
  final String token;
  final String description;
  final String example;

  const PathToken({
    required this.token,
    required this.description,
    required this.example,
  });
}

/// Default output path settings provider
final outputPathSettingsProvider =
    StateNotifierProvider<OutputPathSettingsNotifier, OutputPathSettings>(
        (ref) {
  return OutputPathSettingsNotifier();
});

/// Output path settings state
class OutputPathSettings {
  final String baseDirectory;
  final String pathFormat;
  final bool autoCreateSubfolders;

  const OutputPathSettings({
    this.baseDirectory = '~/eriui/output',
    this.pathFormat = '[year]/[month]/[day]/',
    this.autoCreateSubfolders = true,
  });

  OutputPathSettings copyWith({
    String? baseDirectory,
    String? pathFormat,
    bool? autoCreateSubfolders,
  }) {
    return OutputPathSettings(
      baseDirectory: baseDirectory ?? this.baseDirectory,
      pathFormat: pathFormat ?? this.pathFormat,
      autoCreateSubfolders: autoCreateSubfolders ?? this.autoCreateSubfolders,
    );
  }
}

/// Output path settings state notifier
class OutputPathSettingsNotifier extends StateNotifier<OutputPathSettings> {
  OutputPathSettingsNotifier() : super(const OutputPathSettings()) {
    _loadSettings();
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    final baseDir = StorageService.getStringStatic(
            OutputPathStorageKeys.baseOutputDirectory) ??
        '~/eriui/output';
    final format = StorageService.getStringStatic(
            OutputPathStorageKeys.outputPathFormat) ??
        '[year]/[month]/[day]/';
    final autoCreate = StorageService.getBool(
            OutputPathStorageKeys.autoCreateSubfolders) ??
        true;

    state = OutputPathSettings(
      baseDirectory: baseDir,
      pathFormat: format,
      autoCreateSubfolders: autoCreate,
    );
  }

  /// Update base directory
  Future<void> setBaseDirectory(String directory) async {
    state = state.copyWith(baseDirectory: directory);
    await StorageService.setStringStatic(
        OutputPathStorageKeys.baseOutputDirectory, directory);
  }

  /// Update path format
  Future<void> setPathFormat(String format) async {
    state = state.copyWith(pathFormat: format);
    await StorageService.setStringStatic(
        OutputPathStorageKeys.outputPathFormat, format);
  }

  /// Update auto-create subfolders setting
  Future<void> setAutoCreateSubfolders(bool value) async {
    state = state.copyWith(autoCreateSubfolders: value);
    await StorageService.setBool(
        OutputPathStorageKeys.autoCreateSubfolders, value);
  }

  /// Generate preview path with sample values
  String generatePreviewPath({
    String? model,
    String? prompt,
    int? seed,
    int? width,
    int? height,
  }) {
    final now = DateTime.now();
    String result = state.pathFormat;

    // Date tokens
    result = result.replaceAll('[year]', now.year.toString());
    result = result.replaceAll(
        '[month]', now.month.toString().padLeft(2, '0'));
    result =
        result.replaceAll('[day]', now.day.toString().padLeft(2, '0'));

    // Generation tokens
    result = result.replaceAll('[model]', model ?? 'flux-dev');
    result = result.replaceAll(
        '[prompt]', _sanitizeForPath(prompt ?? 'sample-prompt'));
    result = result.replaceAll('[seed]', (seed ?? 12345).toString());
    result = result.replaceAll('[width]', (width ?? 1024).toString());
    result = result.replaceAll('[height]', (height ?? 1024).toString());

    return '${state.baseDirectory}/$result';
  }

  /// Sanitize a string for use in a file path
  String _sanitizeForPath(String input) {
    // Take first 30 chars, replace invalid chars with dashes
    String sanitized = input.length > 30 ? input.substring(0, 30) : input;
    sanitized = sanitized.replaceAll(RegExp(r'[<>:"/\\|?*]'), '-');
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), '-');
    sanitized = sanitized.replaceAll(RegExp(r'-+'), '-');
    sanitized = sanitized.trim();
    if (sanitized.endsWith('-')) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }
    return sanitized.toLowerCase();
  }
}

/// Output path settings widget for configuring output folder organization
class OutputPathSettingsWidget extends ConsumerStatefulWidget {
  const OutputPathSettingsWidget({super.key});

  @override
  ConsumerState<OutputPathSettingsWidget> createState() =>
      _OutputPathSettingsWidgetState();
}

class _OutputPathSettingsWidgetState
    extends ConsumerState<OutputPathSettingsWidget> {
  late TextEditingController _formatController;
  late TextEditingController _baseDirectoryController;

  /// Available tokens for path formatting
  static const List<PathToken> availableTokens = [
    PathToken(
      token: '[year]',
      description: 'Current year',
      example: '2025',
    ),
    PathToken(
      token: '[month]',
      description: 'Current month (01-12)',
      example: '01',
    ),
    PathToken(
      token: '[day]',
      description: 'Current day (01-31)',
      example: '08',
    ),
    PathToken(
      token: '[model]',
      description: 'Model name',
      example: 'flux-dev',
    ),
    PathToken(
      token: '[prompt]',
      description: 'Sanitized prompt (first 30 chars)',
      example: 'beautiful-sunset',
    ),
    PathToken(
      token: '[seed]',
      description: 'Generation seed',
      example: '12345',
    ),
    PathToken(
      token: '[width]',
      description: 'Image width',
      example: '1024',
    ),
    PathToken(
      token: '[height]',
      description: 'Image height',
      example: '1024',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(outputPathSettingsProvider);
    _formatController = TextEditingController(text: settings.pathFormat);
    _baseDirectoryController =
        TextEditingController(text: settings.baseDirectory);
  }

  @override
  void dispose() {
    _formatController.dispose();
    _baseDirectoryController.dispose();
    super.dispose();
  }

  /// Insert a token at cursor position
  void _insertToken(String token) {
    final text = _formatController.text;
    final selection = _formatController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, token);
    _formatController.text = newText;
    _formatController.selection = TextSelection.collapsed(
      offset: start + token.length,
    );

    ref.read(outputPathSettingsProvider.notifier).setPathFormat(newText);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(outputPathSettingsProvider);
    final notifier = ref.read(outputPathSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Base directory section
        SettingsSection(
          title: 'Base Output Directory',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _baseDirectoryController,
                      decoration: InputDecoration(
                        labelText: 'Base Directory',
                        hintText: '~/eriui/output',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.folder),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.folder_open),
                          tooltip: 'Browse',
                          onPressed: () {
                            // TODO: Implement directory picker
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Directory picker not yet implemented'),
                              ),
                            );
                          },
                        ),
                      ),
                      onChanged: (value) {
                        notifier.setBaseDirectory(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Path format section
        SettingsSection(
          title: 'Output Path Format',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Format input field
                  TextField(
                    controller: _formatController,
                    decoration: InputDecoration(
                      labelText: 'Path Format',
                      hintText: '[year]/[month]/[day]/',
                      border: const OutlineInputBorder(),
                      helperText: 'Use tokens below to build your path format',
                      helperMaxLines: 2,
                    ),
                    onChanged: (value) {
                      notifier.setPathFormat(value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Token chips
                  Text(
                    'Available Tokens',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTokens.map((token) {
                      return Tooltip(
                        message: '${token.description}\nExample: ${token.example}',
                        child: ActionChip(
                          label: Text(token.token),
                          avatar: Icon(
                            _getTokenIcon(token.token),
                            size: 18,
                          ),
                          onPressed: () => _insertToken(token.token),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Preset format buttons
                  Text(
                    'Preset Formats',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PresetFormatChip(
                        label: 'By Date',
                        format: '[year]/[month]/[day]/',
                        onTap: () {
                          _formatController.text = '[year]/[month]/[day]/';
                          notifier.setPathFormat('[year]/[month]/[day]/');
                        },
                      ),
                      _PresetFormatChip(
                        label: 'By Model',
                        format: '[year]/[month]/[model]/',
                        onTap: () {
                          _formatController.text = '[year]/[month]/[model]/';
                          notifier.setPathFormat('[year]/[month]/[model]/');
                        },
                      ),
                      _PresetFormatChip(
                        label: 'Date + Model',
                        format: '[year]-[month]-[day]/[model]/',
                        onTap: () {
                          _formatController.text =
                              '[year]-[month]-[day]/[model]/';
                          notifier
                              .setPathFormat('[year]-[month]-[day]/[model]/');
                        },
                      ),
                      _PresetFormatChip(
                        label: 'By Prompt',
                        format: '[year]/[month]/[prompt]/',
                        onTap: () {
                          _formatController.text = '[year]/[month]/[prompt]/';
                          notifier.setPathFormat('[year]/[month]/[prompt]/');
                        },
                      ),
                      _PresetFormatChip(
                        label: 'By Resolution',
                        format: '[year]/[month]/[width]x[height]/',
                        onTap: () {
                          _formatController.text =
                              '[year]/[month]/[width]x[height]/';
                          notifier
                              .setPathFormat('[year]/[month]/[width]x[height]/');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Preview section
        SettingsSection(
          title: 'Path Preview',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview with sample values:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            notifier.generatePreviewPath(),
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontFamily: 'monospace',
                                    ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          tooltip: 'Copy path',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                              text: notifier.generatePreviewPath(),
                            ));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Path copied to clipboard'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Options section
        SettingsSection(
          title: 'Options',
          children: [
            SwitchListTile(
              title: const Text('Auto-create subfolders'),
              subtitle: const Text(
                'Automatically create directories if they don\'t exist',
              ),
              value: settings.autoCreateSubfolders,
              onChanged: (value) {
                notifier.setAutoCreateSubfolders(value);
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Get icon for a token
  IconData _getTokenIcon(String token) {
    switch (token) {
      case '[year]':
      case '[month]':
      case '[day]':
        return Icons.calendar_today;
      case '[model]':
        return Icons.smart_toy;
      case '[prompt]':
        return Icons.text_fields;
      case '[seed]':
        return Icons.casino;
      case '[width]':
      case '[height]':
        return Icons.aspect_ratio;
      default:
        return Icons.code;
    }
  }
}

/// Preset format chip widget
class _PresetFormatChip extends StatelessWidget {
  final String label;
  final String format;
  final VoidCallback onTap;

  const _PresetFormatChip({
    required this.label,
    required this.format,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: format,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(label),
      ),
    );
  }
}
