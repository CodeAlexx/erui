import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../models/preset.dart';
import '../../../services/presets_service.dart';
import '../../../providers/generation_provider.dart';

/// Panel for managing and applying presets
class PresetsPanel extends ConsumerStatefulWidget {
  final VoidCallback? onCollapse;
  const PresetsPanel({super.key, this.onCollapse});

  @override
  ConsumerState<PresetsPanel> createState() => _PresetsPanelState();
}

class _PresetsPanelState extends ConsumerState<PresetsPanel> {
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    final presetsState = ref.watch(presetsProvider);
    final currentFolder = ref.watch(currentPresetFolderProvider);
    final folders = ref.watch(presetFoldersProvider);
    final filteredPresets = ref.watch(filteredPresetsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(context, currentFolder),
        const SizedBox(height: 8),

        // Toolbar
        _buildToolbar(context),
        const SizedBox(height: 12),

        // Error display
        if (presetsState.error != null)
          _buildErrorBanner(context, presetsState.error!),

        // Breadcrumb navigation
        if (currentFolder != null)
          _buildBreadcrumbs(context, currentFolder),

        // Loading indicator
        if (presetsState.isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          // Folders
          if (folders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: folders.map((folder) => _buildFolderChip(
                  context,
                  folder,
                )).toList(),
              ),
            ),

          // Presets grid/list
          Expanded(
            child: filteredPresets.isEmpty
                ? _buildEmptyState(context, currentFolder)
                : _isGridView
                    ? _buildGridView(context, filteredPresets)
                    : _buildListView(context, filteredPresets),
          ),
        ],
      ],
    );
  }

  Widget _buildHeader(BuildContext context, String? currentFolder) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        if (currentFolder != null)
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Navigate up one level
              final parts = currentFolder.split('/');
              if (parts.length > 1) {
                ref.read(currentPresetFolderProvider.notifier).state =
                    parts.sublist(0, parts.length - 1).join('/');
              } else {
                ref.read(currentPresetFolderProvider.notifier).state = null;
              }
            },
            tooltip: 'Go back',
          ),
        Text(
          currentFolder?.split('/').last ?? 'Presets',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
              ),
        ),
        const Spacer(),
        // View toggle
        IconButton(
          icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
          },
          tooltip: _isGridView ? 'List view' : 'Grid view',
        ),
        // Collapse button
        if (widget.onCollapse != null)
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: widget.onCollapse,
            tooltip: 'Collapse panel',
          ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () => _showCreatePresetDialog(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New Preset'),
        ),
        OutlinedButton.icon(
          onPressed: () => _showCreateFolderDialog(context),
          icon: const Icon(Icons.create_new_folder, size: 18),
          label: const Text('New Folder'),
        ),
        OutlinedButton.icon(
          onPressed: () => _importPresets(context),
          icon: const Icon(Icons.file_download, size: 18),
          label: const Text('Import'),
        ),
        OutlinedButton.icon(
          onPressed: () => _exportPresets(context),
          icon: const Icon(Icons.file_upload, size: 18),
          label: const Text('Export'),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context, String error) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              ref.read(presetsProvider.notifier).clearError();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs(BuildContext context, String currentFolder) {
    final colorScheme = Theme.of(context).colorScheme;
    final parts = currentFolder.split('/');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            onTap: () {
              ref.read(currentPresetFolderProvider.notifier).state = null;
            },
            child: Text(
              'Root',
              style: TextStyle(color: colorScheme.primary),
            ),
          ),
          for (int i = 0; i < parts.length; i++) ...[
            Icon(Icons.chevron_right, size: 18, color: colorScheme.outline),
            InkWell(
              onTap: i < parts.length - 1
                  ? () {
                      ref.read(currentPresetFolderProvider.notifier).state =
                          parts.sublist(0, i + 1).join('/');
                    }
                  : null,
              child: Text(
                parts[i],
                style: TextStyle(
                  color: i == parts.length - 1
                      ? colorScheme.onSurface
                      : colorScheme.primary,
                  fontWeight: i == parts.length - 1
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFolderChip(BuildContext context, PresetFolder folder) {
    final colorScheme = Theme.of(context).colorScheme;

    return ActionChip(
      avatar: Icon(Icons.folder, size: 18, color: colorScheme.primary),
      label: Text('${folder.name} (${folder.presetCount})'),
      onPressed: () {
        ref.read(currentPresetFolderProvider.notifier).state = folder.path;
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String? currentFolder) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 64,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            currentFolder != null
                ? 'No presets in this folder'
                : 'No presets yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a preset to save your generation settings',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _showCreatePresetDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Preset'),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(BuildContext context, List<Preset> presets) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        return _PresetCard(
          preset: presets[index],
          onTap: () => _applyPreset(context, presets[index]),
          onLongPress: () => _showPresetMenu(context, presets[index]),
        );
      },
    );
  }

  Widget _buildListView(BuildContext context, List<Preset> presets) {
    return ListView.builder(
      itemCount: presets.length,
      itemBuilder: (context, index) {
        return _PresetListTile(
          preset: presets[index],
          onTap: () => _applyPreset(context, presets[index]),
          onLongPress: () => _showPresetMenu(context, presets[index]),
        );
      },
    );
  }

  void _applyPreset(BuildContext context, Preset preset) {
    final paramsNotifier = ref.read(generationParamsProvider.notifier);

    // Apply all non-null preset values
    if (preset.prompt != null) paramsNotifier.setPrompt(preset.prompt!);
    if (preset.negativePrompt != null) {
      paramsNotifier.setNegativePrompt(preset.negativePrompt!);
    }
    if (preset.model != null) paramsNotifier.setModel(preset.model);
    if (preset.steps != null) paramsNotifier.setSteps(preset.steps!);
    if (preset.cfgScale != null) paramsNotifier.setCfgScale(preset.cfgScale!);
    if (preset.width != null) paramsNotifier.setWidth(preset.width!);
    if (preset.height != null) paramsNotifier.setHeight(preset.height!);
    if (preset.sampler != null) paramsNotifier.setSampler(preset.sampler!);
    if (preset.scheduler != null) {
      paramsNotifier.setScheduler(preset.scheduler!);
    }
    if (preset.batchSize != null) {
      paramsNotifier.setBatchSize(preset.batchSize!);
    }
    if (preset.seed != null) paramsNotifier.setSeed(preset.seed!);

    // Video parameters
    if (preset.videoMode != null) {
      paramsNotifier.setVideoMode(preset.videoMode!);
    }
    if (preset.videoModel != null) {
      paramsNotifier.setVideoModel(preset.videoModel);
    }
    if (preset.frames != null) paramsNotifier.setFrames(preset.frames!);
    if (preset.fps != null) paramsNotifier.setFps(preset.fps!);
    if (preset.videoFormat != null) {
      paramsNotifier.setVideoFormat(preset.videoFormat!);
    }

    // Extra params
    if (preset.extraParams != null) {
      for (final entry in preset.extraParams!.entries) {
        paramsNotifier.setExtraParam(entry.key, entry.value);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied preset: ${preset.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPresetMenu(BuildContext context, Preset preset) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Apply'),
              onTap: () {
                Navigator.pop(context);
                _applyPreset(context, preset);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showEditPresetDialog(context, preset);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move),
              title: const Text('Move to Folder'),
              onTap: () {
                Navigator.pop(context);
                _showMoveDialog(context, preset);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(context);
                _duplicatePreset(context, preset);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, preset);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePresetDialog(BuildContext context) {
    final params = ref.read(generationParamsProvider);
    final currentFolder = ref.read(currentPresetFolderProvider);

    showDialog(
      context: context,
      builder: (context) => _PresetDialog(
        title: 'Create Preset',
        initialFolder: currentFolder,
        initialParams: params,
        onSave: (preset) async {
          await ref.read(presetsProvider.notifier).savePreset(preset);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditPresetDialog(BuildContext context, Preset preset) {
    showDialog(
      context: context,
      builder: (context) => _PresetDialog(
        title: 'Edit Preset',
        preset: preset,
        onSave: (updatedPreset) async {
          await ref.read(presetsProvider.notifier).updatePreset(updatedPreset);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context) {
    final controller = TextEditingController();
    final currentFolder = ref.read(currentPresetFolderProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'Enter folder name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;

              final folderPath = currentFolder != null
                  ? '$currentFolder/${controller.text.trim()}'
                  : controller.text.trim();

              // Create an empty preset in the folder to establish it
              final service = ref.read(presetsServiceProvider);
              final placeholder = service.createPresetFromParams(
                name: '.folder',
                folder: folderPath,
              );

              // Navigate to the new folder
              ref.read(currentPresetFolderProvider.notifier).state = folderPath;

              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showMoveDialog(BuildContext context, Preset preset) {
    final presetsState = ref.read(presetsProvider);

    // Collect all unique folders
    final folders = <String?>{null}; // null represents root
    for (final p in presetsState.presets) {
      if (p.folder != null && p.folder!.isNotEmpty) {
        folders.add(p.folder);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Folder'),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: folders.map((folder) {
              final isSelected = preset.folder == folder;
              return ListTile(
                leading: Icon(
                  folder == null ? Icons.home : Icons.folder,
                ),
                title: Text(folder ?? 'Root'),
                selected: isSelected,
                onTap: isSelected
                    ? null
                    : () {
                        ref.read(presetsProvider.notifier).movePreset(
                              preset.id,
                              folder,
                            );
                        Navigator.pop(context);
                      },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _duplicatePreset(BuildContext context, Preset preset) {
    final service = ref.read(presetsServiceProvider);
    final duplicate = preset.copyWith(
      id: service.generateId(),
      name: '${preset.name} (Copy)',
      createdAt: DateTime.now(),
    );

    ref.read(presetsProvider.notifier).savePreset(duplicate);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Duplicated: ${duplicate.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Preset preset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preset'),
        content: Text('Are you sure you want to delete "${preset.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(presetsProvider.notifier).deletePreset(preset.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _importPresets(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();

        final count = await ref.read(presetsProvider.notifier).importPresets(
              jsonString,
              merge: true,
            );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported $count presets'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _exportPresets(BuildContext context) async {
    try {
      final currentFolder = ref.read(currentPresetFolderProvider);
      final jsonString = ref.read(presetsProvider.notifier).exportPresets(
            folder: currentFolder,
          );

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Presets',
        fileName: 'eriui_presets.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(jsonString);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exported to: $result'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

/// Card widget for displaying a preset in grid view
class _PresetCard extends StatelessWidget {
  final Preset preset;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PresetCard({
    required this.preset,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    preset.videoMode == true
                        ? Icons.videocam
                        : Icons.image,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      preset.name,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (preset.model != null)
                _buildInfoRow(
                  context,
                  Icons.smart_toy,
                  preset.model!.split('/').last,
                ),
              if (preset.width != null && preset.height != null)
                _buildInfoRow(
                  context,
                  Icons.aspect_ratio,
                  '${preset.width} x ${preset.height}',
                ),
              if (preset.steps != null)
                _buildInfoRow(
                  context,
                  Icons.tune,
                  '${preset.steps} steps, CFG ${preset.cfgScale?.toStringAsFixed(1) ?? '-'}',
                ),
              const Spacer(),
              if (preset.description != null && preset.description!.isNotEmpty)
                Text(
                  preset.description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: colorScheme.outline),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// List tile widget for displaying a preset in list view
class _PresetListTile extends StatelessWidget {
  final Preset preset;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PresetListTile({
    required this.preset,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String subtitle = '';
    if (preset.model != null) {
      subtitle = preset.model!.split('/').last;
    }
    if (preset.width != null && preset.height != null) {
      subtitle += subtitle.isNotEmpty ? ' - ' : '';
      subtitle += '${preset.width}x${preset.height}';
    }
    if (preset.steps != null) {
      subtitle += subtitle.isNotEmpty ? ' - ' : '';
      subtitle += '${preset.steps} steps';
    }

    return ListTile(
      leading: Icon(
        preset.videoMode == true ? Icons.videocam : Icons.image,
        color: colorScheme.primary,
      ),
      title: Text(preset.name),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: onLongPress,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// Dialog for creating or editing a preset
class _PresetDialog extends ConsumerStatefulWidget {
  final String title;
  final Preset? preset;
  final String? initialFolder;
  final GenerationParams? initialParams;
  final Future<void> Function(Preset preset) onSave;

  const _PresetDialog({
    required this.title,
    this.preset,
    this.initialFolder,
    this.initialParams,
    required this.onSave,
  });

  @override
  ConsumerState<_PresetDialog> createState() => _PresetDialogState();
}

class _PresetDialogState extends ConsumerState<_PresetDialog> {
  late TextEditingController _nameController;
  late TextEditingController _folderController;
  late TextEditingController _descriptionController;

  bool _includePrompt = true;
  bool _includeNegativePrompt = true;
  bool _includeModel = true;
  bool _includeSettings = true;
  bool _includeVideoSettings = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.preset?.name ?? '',
    );
    _folderController = TextEditingController(
      text: widget.preset?.folder ?? widget.initialFolder ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.preset?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _folderController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'Enter preset name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _folderController,
                decoration: const InputDecoration(
                  labelText: 'Folder (optional)',
                  hintText: 'e.g., Characters/Fantasy',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Brief description of this preset',
                ),
              ),
              if (widget.preset == null) ...[
                const SizedBox(height: 24),
                Text(
                  'Include in Preset:',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Prompt'),
                  value: _includePrompt,
                  onChanged: (v) => setState(() => _includePrompt = v ?? true),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Negative Prompt'),
                  value: _includeNegativePrompt,
                  onChanged: (v) =>
                      setState(() => _includeNegativePrompt = v ?? true),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Model'),
                  value: _includeModel,
                  onChanged: (v) => setState(() => _includeModel = v ?? true),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Generation Settings (steps, CFG, size, sampler)'),
                  value: _includeSettings,
                  onChanged: (v) =>
                      setState(() => _includeSettings = v ?? true),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Video Settings'),
                  value: _includeVideoSettings,
                  onChanged: (v) =>
                      setState(() => _includeVideoSettings = v ?? true),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for the preset')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      Preset preset;

      if (widget.preset != null) {
        // Editing existing preset
        preset = widget.preset!.copyWith(
          name: _nameController.text.trim(),
          folder: _folderController.text.trim().isEmpty
              ? null
              : _folderController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          updatedAt: DateTime.now(),
        );
      } else {
        // Creating new preset from current params
        final params = widget.initialParams ?? ref.read(generationParamsProvider);
        final service = ref.read(presetsServiceProvider);

        if (params == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No parameters available')),
          );
          return;
        }

        preset = service.createPresetFromParams(
          name: _nameController.text.trim(),
          folder: _folderController.text.trim().isEmpty
              ? null
              : _folderController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          prompt: _includePrompt ? params.prompt : null,
          negativePrompt: _includeNegativePrompt ? params.negativePrompt : null,
          model: _includeModel ? params.model : null,
          steps: _includeSettings ? params.steps : null,
          cfgScale: _includeSettings ? params.cfgScale : null,
          width: _includeSettings ? params.width : null,
          height: _includeSettings ? params.height : null,
          sampler: _includeSettings ? params.sampler : null,
          scheduler: _includeSettings ? params.scheduler : null,
          batchSize: _includeSettings ? params.batchSize : null,
          seed: null, // Don't save seed by default
          videoMode: _includeVideoSettings ? params.videoMode : null,
          videoModel: _includeVideoSettings ? params.videoModel : null,
          frames: _includeVideoSettings ? params.frames : null,
          fps: _includeVideoSettings ? params.fps : null,
          videoFormat: _includeVideoSettings ? params.videoFormat : null,
          extraParams: params.extraParams.isNotEmpty ? params.extraParams : null,
        );
      }

      await widget.onSave(preset);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
