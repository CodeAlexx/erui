import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';

import '../../../providers/providers.dart';
import '../../../services/api_service.dart';

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
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get<Map<String, dynamic>>(
        '/api/model/metadata',
        queryParameters: {
          'model': widget.model.name,
          'type': widget.model.type,
        },
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        _titleController.text = data['title'] ?? widget.model.displayName;
        _authorController.text = data['author'] ?? '';
        _resolutionController.text = data['standard_resolution'] ?? '';
        _licenseController.text = data['license'] ?? '';
        _dateController.text = data['date'] ?? '';
        _mergedFromController.text = data['merged_from'] ?? '';
        _tagsController.text = (data['tags'] as List?)?.join(', ') ?? '';
        _usageHintController.text = data['usage_hint'] ?? '';
        _triggerPhraseController.text = data['trigger_phrase'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _architecture = data['architecture'] ?? _architecture;
        _predictionType = data['prediction_type'] ?? _predictionType;
        _previewImageUrl = data['preview_image'] ?? widget.model.previewUrl;
        _hash = data['hash'];
        _createdDate = data['created'];
        _modifiedDate = data['modified'];
      }
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
      final apiService = ref.read(apiServiceProvider);
      final metadata = {
        'model': widget.model.name,
        'type': widget.model.type,
        'metadata': {
          'title': _titleController.text,
          'author': _authorController.text,
          'architecture': _architecture,
          'prediction_type': _predictionType,
          'standard_resolution': _resolutionController.text,
          'license': _licenseController.text,
          'date': _dateController.text,
          'merged_from': _mergedFromController.text,
          'tags': _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
          'usage_hint': _usageHintController.text,
          'trigger_phrase': _triggerPhraseController.text,
          'description': _descriptionController.text,
        },
      };

      final response = await apiService.post<Map<String, dynamic>>(
        '/api/model/metadata',
        data: metadata,
      );

      if (response.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Metadata saved successfully')),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception(response.error ?? 'Failed to save metadata');
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

    setState(() => _isSaving = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post<Map<String, dynamic>>(
        '/api/model/preview/upload',
        data: {
          'model': widget.model.name,
          'type': widget.model.type,
          'image_url': widget.currentImageUrl,
        },
      );

      if (response.isSuccess) {
        setState(() {
          _previewImageUrl = response.data?['preview_path'] ?? widget.currentImageUrl;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Preview image updated')),
          );
        }
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

  Future<void> _loadFromCivitai() async {
    final url = _civitaiUrlController.text.trim();

    setState(() => _isLoading = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post<Map<String, dynamic>>(
        '/api/model/civitai/load',
        data: {
          'model': widget.model.name,
          'type': widget.model.type,
          'url': url.isEmpty ? null : url, // null = use hash
        },
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        if (data['title'] != null) _titleController.text = data['title'];
        if (data['author'] != null) _authorController.text = data['author'];
        if (data['description'] != null) _descriptionController.text = data['description'];
        if (data['tags'] != null) _tagsController.text = (data['tags'] as List).join(', ');
        if (data['trigger_phrase'] != null) _triggerPhraseController.text = data['trigger_phrase'];

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loaded metadata from CivitAI')),
        );
      } else {
        throw Exception(response.error ?? 'Model not found on CivitAI');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CivitAI: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
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
