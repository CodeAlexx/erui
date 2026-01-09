import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';

import '../../../providers/providers.dart';
import '../../../services/comfyui_service.dart';

/// Model metadata editor dialog - similar to SwarmUI's Edit Metadata
class ModelMetadataEditor extends ConsumerStatefulWidget {
  final ModelInfo model;
  final String? currentImageUrl; // Currently generated image to use as preview

  const ModelMetadataEditor({
    super.key,
    required this.model,
    this.currentImageUrl,
  });

  @override
  ConsumerState<ModelMetadataEditor> createState() => _ModelMetadataEditorState();
}

class _ModelMetadataEditorState extends ConsumerState<ModelMetadataEditor> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // Form controllers
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _resolutionController;
  late TextEditingController _licenseController;
  late TextEditingController _dateController;
  late TextEditingController _mergedFromController;
  late TextEditingController _tagsController;
  late TextEditingController _usageHintController;
  late TextEditingController _triggerPhraseController;
  late TextEditingController _descriptionController;
  late TextEditingController _civitaiUrlController;

  String _architecture = 'Stable Diffusion XL 1.0-Base';
  String _predictionType = 'Epsilon';
  String? _previewImageUrl;
  String? _hash;
  String? _createdDate;
  String? _modifiedDate;

  static const _architectures = [
    'Stable Diffusion 1.5',
    'Stable Diffusion 2.0',
    'Stable Diffusion 2.1',
    'Stable Diffusion XL 1.0-Base',
    'Stable Diffusion XL 1.0-Refiner',
    'Stable Diffusion 3',
    'Stable Diffusion 3.5',
    'Flux.1 Dev',
    'Flux.1 Schnell',
    'LTX-Video',
    'LTX-2',
    'Hunyuan Video',
    'Wan Video',
    'Other',
  ];

  static const _predictionTypes = [
    'Epsilon',
    'V-Prediction',
    'Flow Matching',
    'Rectified Flow',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _authorController = TextEditingController();
    _resolutionController = TextEditingController();
    _licenseController = TextEditingController();
    _dateController = TextEditingController();
    _mergedFromController = TextEditingController();
    _tagsController = TextEditingController();
    _usageHintController = TextEditingController();
    _triggerPhraseController = TextEditingController();
    _descriptionController = TextEditingController();
    _civitaiUrlController = TextEditingController();
    _loadMetadata();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _resolutionController.dispose();
    _licenseController.dispose();
    _dateController.dispose();
    _mergedFromController.dispose();
    _tagsController.dispose();
    _usageHintController.dispose();
    _triggerPhraseController.dispose();
    _descriptionController.dispose();
    _civitaiUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Note: ComfyUI doesn't have a built-in metadata API
      // For now, just populate with basic model info
      // Model metadata could be stored locally or via a separate service
      _titleController.text = widget.model.displayName;
      _previewImageUrl = widget.model.previewUrl;
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMetadata() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Note: ComfyUI doesn't have a built-in metadata save API
      // Model metadata would need to be stored locally or via a separate service
      // For now, just show success and close
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Metadata editing not yet supported with ComfyUI backend')),
        );
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _useCurrentImage() async {
    if (widget.currentImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No current image available')),
      );
      return;
    }

    // Note: ComfyUI doesn't have a preview image upload API
    // Preview images would need to be managed locally
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preview image upload not yet supported with ComfyUI backend')),
    );
  }

  Future<void> _loadFromCivitai() async {
    // Note: CivitAI integration requires a separate service
    // This feature is not available with direct ComfyUI backend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CivitAI integration not yet available with ComfyUI backend')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 900),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, color: colorScheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Model Metadata',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          widget.model.name,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Info row (read-only)
                            if (_createdDate != null || _modifiedDate != null || _hash != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_createdDate != null)
                                      Text('Created: $_createdDate', style: Theme.of(context).textTheme.bodySmall),
                                    if (_modifiedDate != null)
                                      Text('Modified: $_modifiedDate', style: Theme.of(context).textTheme.bodySmall),
                                    if (_hash != null)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Hash: $_hash',
                                              style: Theme.of(context).textTheme.bodySmall,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy, size: 16),
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: _hash!));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Hash copied')),
                                              );
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),

                            // Load from CivitAI
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _civitaiUrlController,
                                    decoration: const InputDecoration(
                                      labelText: 'Load from CivitAI',
                                      hintText: 'CivitAI URL (or blank to use hash)',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: _isLoading ? null : _loadFromCivitai,
                                  child: const Text('Load'),
                                ),
                              ],
                            ),
                            const Divider(height: 32),

                            // Title
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Title',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Author
                            TextFormField(
                              controller: _authorController,
                              decoration: const InputDecoration(
                                labelText: 'Author',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Architecture & Prediction Type row
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _architectures.contains(_architecture) ? _architecture : 'Other',
                                    decoration: const InputDecoration(
                                      labelText: 'Architecture',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _architectures.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                                    onChanged: (v) => setState(() => _architecture = v ?? _architecture),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _predictionTypes.contains(_predictionType) ? _predictionType : 'Epsilon',
                                    decoration: const InputDecoration(
                                      labelText: 'Prediction Type',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _predictionTypes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                                    onChanged: (v) => setState(() => _predictionType = v ?? _predictionType),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Resolution & License row
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _resolutionController,
                                    decoration: const InputDecoration(
                                      labelText: 'Standard Resolution',
                                      hintText: '1024x1024',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _licenseController,
                                    decoration: const InputDecoration(
                                      labelText: 'License',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Date & Merged From row
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _dateController,
                                    decoration: const InputDecoration(
                                      labelText: 'Date',
                                      hintText: '2024-01-01',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _mergedFromController,
                                    decoration: const InputDecoration(
                                      labelText: 'Merged From',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Tags
                            TextFormField(
                              controller: _tagsController,
                              decoration: const InputDecoration(
                                labelText: 'Tags',
                                hintText: 'tag1, tag2, tag3',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Usage Hint
                            TextFormField(
                              controller: _usageHintController,
                              decoration: const InputDecoration(
                                labelText: 'Usage Hint',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Trigger Phrase
                            TextFormField(
                              controller: _triggerPhraseController,
                              decoration: const InputDecoration(
                                labelText: 'Trigger Phrase',
                                hintText: 'e.g., "in the style of xyz"',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Description
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                              maxLines: 4,
                            ),
                            const SizedBox(height: 24),

                            // Preview Image section
                            Text(
                              'Preview Image',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Preview thumbnail
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _previewImageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: _previewImageUrl!,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => Icon(
                                              Icons.image_not_supported,
                                              color: colorScheme.outline,
                                            ),
                                          )
                                        : Icon(
                                            Icons.image,
                                            size: 48,
                                            color: colorScheme.outline,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Image actions
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (widget.currentImageUrl != null)
                                        FilledButton.icon(
                                          onPressed: _isSaving ? null : _useCurrentImage,
                                          icon: const Icon(Icons.image),
                                          label: const Text('Use Current Image'),
                                        ),
                                      const SizedBox(height: 8),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          // TODO: Implement file picker
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('File picker coming soon')),
                                          );
                                        },
                                        icon: const Icon(Icons.upload_file),
                                        label: const Text('Choose File'),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Ctrl+V to paste image',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: colorScheme.outline,
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
                    ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSaving ? null : _saveMetadata,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
