import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/onetrainer_service.dart' as ot;

/// Training Concepts Screen - Manage training concepts/datasets
/// Connected to OneTrainer API via currentConfigProvider
class ConceptsScreen extends ConsumerStatefulWidget {
  const ConceptsScreen({super.key});

  @override
  ConsumerState<ConceptsScreen> createState() => _ConceptsScreenState();
}

class Concept {
  final String id;
  String name;
  String path;
  String type;
  bool enabled;
  int balancing;
  int lossWeight;
  String balancingStrategy;
  int imageVariations;
  int textVariations;
  bool includeSubdirectories;
  int seed;
  // Image augmentation
  bool cropJitter;
  bool randomFlip;
  bool fixedFlip;
  int maxAngle;
  bool randomRotate;
  bool brightness;
  int brightnessStrength;
  bool contrast;
  int contrastStrength;
  bool saturation;
  int saturationStrength;
  bool hue;
  int hueStrength;
  bool overrideResolution;
  String resolutionOverride;
  bool randomCircularMaskShrink;
  bool randomMaskRotateCrop;
  // Text settings
  String promptSource;
  String promptPath;
  bool enableTagShuffling;
  String tagDelimiter;
  int keepTagsCount;
  bool tagDropoutEnable;
  String tagDropoutMode;
  double tagDropoutProbability;

  Concept({
    required this.id,
    required this.name,
    required this.path,
    this.type = 'Standard',
    this.enabled = true,
    this.balancing = 1,
    this.lossWeight = 1,
    this.balancingStrategy = 'Repeats',
    this.imageVariations = 1,
    this.textVariations = 1,
    this.includeSubdirectories = false,
    this.seed = 0,
    this.cropJitter = true,
    this.randomFlip = false,
    this.fixedFlip = false,
    this.maxAngle = 0,
    this.randomRotate = false,
    this.brightness = false,
    this.brightnessStrength = 0,
    this.contrast = false,
    this.contrastStrength = 0,
    this.saturation = false,
    this.saturationStrength = 0,
    this.hue = false,
    this.hueStrength = 0,
    this.overrideResolution = false,
    this.resolutionOverride = '512',
    this.randomCircularMaskShrink = false,
    this.randomMaskRotateCrop = false,
    this.promptSource = 'sample',
    this.promptPath = '',
    this.enableTagShuffling = false,
    this.tagDelimiter = ',',
    this.keepTagsCount = 1,
    this.tagDropoutEnable = false,
    this.tagDropoutMode = 'FULL',
    this.tagDropoutProbability = 0.0,
  });
}

class _ConceptsScreenState extends ConsumerState<ConceptsScreen> with SingleTickerProviderStateMixin {
  late TabController _detailsTabController;
  String _filterQuery = '';
  String _typeFilter = 'ALL';
  bool _showDisabled = true;
  String? _selectedConceptId;

  List<Concept> _concepts = [];

  Concept? get _selectedConcept => _selectedConceptId != null && _concepts.isNotEmpty
      ? _concepts.firstWhere((c) => c.id == _selectedConceptId, orElse: () => _concepts.first)
      : null;

  /// Load concepts from config
  void _loadConceptsFromConfig(Map<String, dynamic> config) {
    final conceptsList = config['concepts'] as List<dynamic>?;
    if (conceptsList == null) return;

    final loaded = <Concept>[];
    for (int i = 0; i < conceptsList.length; i++) {
      final c = conceptsList[i] as Map<String, dynamic>;
      loaded.add(Concept(
        id: i.toString(),
        name: c['name'] as String? ?? 'Concept ${i + 1}',
        path: c['path'] as String? ?? '',
        type: c['type'] as String? ?? 'Standard',
        enabled: c['enabled'] as bool? ?? true,
        balancing: (c['balancing'] as num?)?.toInt() ?? 1,
        lossWeight: (c['loss_weight'] as num?)?.toInt() ?? 1,
        balancingStrategy: c['balancing_strategy'] as String? ?? 'Repeats',
        imageVariations: (c['image_variations'] as num?)?.toInt() ?? 1,
        textVariations: (c['text_variations'] as num?)?.toInt() ?? 1,
        includeSubdirectories: c['include_subdirectories'] as bool? ?? false,
        seed: (c['seed'] as num?)?.toInt() ?? 0,
        cropJitter: c['crop_jitter'] as bool? ?? true,
        randomFlip: c['random_flip'] as bool? ?? false,
        fixedFlip: c['fixed_flip'] as bool? ?? false,
        maxAngle: (c['random_rotate_max_angle'] as num?)?.toInt() ?? 0,
        randomRotate: c['random_rotate'] as bool? ?? false,
        brightness: c['random_brightness'] as bool? ?? false,
        brightnessStrength: (c['random_brightness_max_strength'] as num?)?.toInt() ?? 0,
        contrast: c['random_contrast'] as bool? ?? false,
        contrastStrength: (c['random_contrast_max_strength'] as num?)?.toInt() ?? 0,
        saturation: c['random_saturation'] as bool? ?? false,
        saturationStrength: (c['random_saturation_max_strength'] as num?)?.toInt() ?? 0,
        hue: c['random_hue'] as bool? ?? false,
        hueStrength: (c['random_hue_max_strength'] as num?)?.toInt() ?? 0,
        overrideResolution: c['override_resolution'] as bool? ?? false,
        resolutionOverride: c['resolution_override'] as String? ?? '512',
        randomCircularMaskShrink: c['random_circular_mask_shrink'] as bool? ?? false,
        randomMaskRotateCrop: c['random_mask_rotate_crop'] as bool? ?? false,
        promptSource: c['prompt_source'] as String? ?? 'sample',
        promptPath: c['prompt_path'] as String? ?? '',
        enableTagShuffling: c['enable_tag_shuffling'] as bool? ?? false,
        tagDelimiter: c['tag_delimiter'] as String? ?? ',',
        keepTagsCount: (c['keep_tags_count'] as num?)?.toInt() ?? 1,
        tagDropoutEnable: c['tag_dropout'] as bool? ?? false,
        tagDropoutMode: c['tag_dropout_mode'] as String? ?? 'FULL',
        tagDropoutProbability: (c['tag_dropout_probability'] as num?)?.toDouble() ?? 0.0,
      ));
    }

    if (mounted && (_concepts.length != loaded.length || _concepts.isEmpty)) {
      setState(() {
        _concepts = loaded;
        if (_selectedConceptId == null && _concepts.isNotEmpty) {
          _selectedConceptId = _concepts.first.id;
        }
      });
    }
  }

  /// Save concepts back to config
  void _saveConceptsToConfig() {
    final conceptsList = _concepts.map((c) => {
      'name': c.name,
      'path': c.path,
      'type': c.type,
      'enabled': c.enabled,
      'balancing': c.balancing,
      'loss_weight': c.lossWeight,
      'balancing_strategy': c.balancingStrategy,
      'image_variations': c.imageVariations,
      'text_variations': c.textVariations,
      'include_subdirectories': c.includeSubdirectories,
      'seed': c.seed,
      'crop_jitter': c.cropJitter,
      'random_flip': c.randomFlip,
      'fixed_flip': c.fixedFlip,
      'random_rotate': c.randomRotate,
      'random_rotate_max_angle': c.maxAngle,
      'random_brightness': c.brightness,
      'random_brightness_max_strength': c.brightnessStrength,
      'random_contrast': c.contrast,
      'random_contrast_max_strength': c.contrastStrength,
      'random_saturation': c.saturation,
      'random_saturation_max_strength': c.saturationStrength,
      'random_hue': c.hue,
      'random_hue_max_strength': c.hueStrength,
      'override_resolution': c.overrideResolution,
      'resolution_override': c.resolutionOverride,
      'random_circular_mask_shrink': c.randomCircularMaskShrink,
      'random_mask_rotate_crop': c.randomMaskRotateCrop,
      'prompt_source': c.promptSource,
      'prompt_path': c.promptPath,
      'enable_tag_shuffling': c.enableTagShuffling,
      'tag_delimiter': c.tagDelimiter,
      'keep_tags_count': c.keepTagsCount,
      'tag_dropout': c.tagDropoutEnable,
      'tag_dropout_mode': c.tagDropoutMode,
      'tag_dropout_probability': c.tagDropoutProbability,
    }).toList();

    ref.read(ot.currentConfigProvider.notifier).updateConfig({'concepts': conceptsList});
  }

  @override
  void initState() {
    super.initState();
    _detailsTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _detailsTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final currentConfig = ref.watch(ot.currentConfigProvider);
    final config = currentConfig.config ?? {};

    // Load concepts from config if needed
    if (config.isNotEmpty && _concepts.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadConceptsFromConfig(config));
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and Add Concept button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Text(
                  'Training Concepts',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addConcept,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Concept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          // Filter bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Search field
                SizedBox(
                  width: 180,
                  child: TextField(
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Filter...',
                      hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
                      prefixIcon: Icon(Icons.search, size: 18, color: colorScheme.onSurface.withOpacity(0.4)),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (v) => setState(() => _filterQuery = v),
                  ),
                ),
                const SizedBox(width: 20),

                // Type dropdown
                Text('Type:', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _typeFilter,
                      dropdownColor: colorScheme.surface,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                      items: ['ALL', 'Standard', 'Prior'].map((t) =>
                        DropdownMenuItem(value: t, child: Text(t))
                      ).toList(),
                      onChanged: (v) => setState(() => _typeFilter = v!),
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Show disabled checkbox
                Checkbox(
                  value: _showDisabled,
                  onChanged: (v) => setState(() => _showDisabled = v!),
                  activeColor: colorScheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Text(
                  'Show Disabled (${_concepts.where((c) => !c.enabled).length})',
                  style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontSize: 13),
                ),
                const SizedBox(width: 12),

                // Clear button
                TextButton(
                  onPressed: () => setState(() {
                    _filterQuery = '';
                    _typeFilter = 'ALL';
                    _showDisabled = true;
                  }),
                  child: Text('Clear', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6))),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Main content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Concepts grid
                  Expanded(
                    child: _buildConceptsGrid(colorScheme),
                  ),
                  // Details panel (only show when concept selected)
                  if (_selectedConcept != null) ...[
                    const SizedBox(width: 16),
                    _buildDetailsPanel(colorScheme),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConceptsGrid(ColorScheme colorScheme) {
    final filtered = _concepts.where((c) {
      if (!_showDisabled && !c.enabled) return false;
      if (_filterQuery.isNotEmpty && !c.name.toLowerCase().contains(_filterQuery.toLowerCase())) return false;
      if (_typeFilter != 'ALL' && c.type != _typeFilter) return false;
      return true;
    }).toList();

    // Dynamic column count based on whether panel is shown
    final crossAxisCount = _selectedConcept != null ? 5 : 6;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildConceptCard(filtered[index], colorScheme),
    );
  }

  Widget _buildConceptCard(Concept concept, ColorScheme colorScheme) {
    final isSelected = concept.id == _selectedConceptId;

    return GestureDetector(
      onTap: () => setState(() => _selectedConceptId = concept.id),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.15)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // Top row: delete + clone buttons (left) + toggle switch (right)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Delete button (red X)
                      InkWell(
                        onTap: () => _deleteConcept(concept),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Clone button (green)
                      InkWell(
                        onTap: () => _cloneConcept(concept),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.copy, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  // Enable/disable toggle
                  SizedBox(
                    height: 24,
                    child: Switch(
                      value: concept.enabled,
                      onChanged: (v) => _updateConcept(() => concept.enabled = v),
                      activeColor: Colors.green,
                      activeTrackColor: Colors.green.withOpacity(0.5),
                      inactiveThumbColor: colorScheme.onSurface.withOpacity(0.4),
                      inactiveTrackColor: colorScheme.onSurface.withOpacity(0.2),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),

            // Thumbnail area (placeholder)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 36,
                    color: colorScheme.onSurface.withOpacity(0.15),
                  ),
                ),
              ),
            ),

            // Bottom row: folder icon + name + tag icon
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  // Folder icon (blue)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.folder, size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  // Name
                  Expanded(
                    child: Text(
                      concept.name,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Tag icon
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.label_outline,
                      size: 12,
                      color: colorScheme.onSurface.withOpacity(0.4),
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

  Widget _buildDetailsPanel(ColorScheme colorScheme) {
    final concept = _selectedConcept!;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Text(
                  'Concept Details',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: colorScheme.onSurface.withOpacity(0.5)),
                  onPressed: () => setState(() => _selectedConceptId = null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),

          // Tabs: General | Image | Text
          TabBar(
            controller: _detailsTabController,
            labelColor: colorScheme.onSurface,
            unselectedLabelColor: colorScheme.onSurface.withOpacity(0.5),
            indicatorColor: colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'General'),
              Tab(text: 'Image'),
              Tab(text: 'Text'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _detailsTabController,
              children: [
                _buildGeneralTab(concept, colorScheme),
                _buildImageTab(concept, colorScheme),
                _buildTextTab(concept, colorScheme),
              ],
            ),
          ),

          // Delete button at bottom
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _deleteConcept(concept),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete Concept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralTab(Concept concept, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          _buildTextField('Name', concept.name, (v) => _updateConcept(() => concept.name = v), colorScheme),

          // Path with folder button
          _buildPathField('Path', concept.path, (v) => _updateConcept(() => concept.path = v), colorScheme),

          // Type dropdown
          _buildDropdown('Type', concept.type, ['Standard', 'Prior'], (v) => _updateConcept(() => concept.type = v), colorScheme),

          // Balancing + Loss Weight row
          Row(
            children: [
              Expanded(child: _buildNumberField('Balancing', concept.balancing, (v) => _updateConcept(() => concept.balancing = v), colorScheme)),
              const SizedBox(width: 12),
              Expanded(child: _buildNumberField('Loss Weight', concept.lossWeight, (v) => _updateConcept(() => concept.lossWeight = v), colorScheme)),
            ],
          ),

          // Balancing Strategy dropdown
          _buildDropdown('Balancing Strategy', concept.balancingStrategy, ['Repeats', 'Shuffle', 'Round Robin'], (v) => _updateConcept(() => concept.balancingStrategy = v), colorScheme),

          // Image Variations + Text Variations row
          Row(
            children: [
              Expanded(child: _buildNumberField('Image Variations', concept.imageVariations, (v) => _updateConcept(() => concept.imageVariations = v), colorScheme)),
              const SizedBox(width: 12),
              Expanded(child: _buildNumberField('Text Variations', concept.textVariations, (v) => _updateConcept(() => concept.textVariations = v), colorScheme)),
            ],
          ),

          // Include Subdirectories checkbox
          _buildCheckbox('Include Subdirectories', concept.includeSubdirectories, (v) => _updateConcept(() => concept.includeSubdirectories = v!), colorScheme),

          // Seed
          _buildNumberField('Seed', concept.seed, (v) => _updateConcept(() => concept.seed = v), colorScheme),
        ],
      ),
    );
  }

  Widget _buildImageTab(Concept concept, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AUGMENTATION section
          _buildSectionHeader('AUGMENTATION', colorScheme),
          const SizedBox(height: 12),

          _buildCheckbox('Crop Jitter', concept.cropJitter, (v) => _updateConcept(() => concept.cropJitter = v!), colorScheme),

          // Random Flip + Fixed Flip on same row
          Row(
            children: [
              Expanded(child: _buildCheckbox('Random Flip', concept.randomFlip, (v) => _updateConcept(() => concept.randomFlip = v!), colorScheme)),
              Expanded(child: _buildCheckbox('Fixed Flip', concept.fixedFlip, (v) => _updateConcept(() => concept.fixedFlip = v!), colorScheme)),
            ],
          ),

          // Random Rotate with Max Angle
          _buildCheckboxWithField('Random Rotate', 'Max Angle', concept.randomRotate, concept.maxAngle,
            (v) => _updateConcept(() => concept.randomRotate = v!),
            (v) => _updateConcept(() => concept.maxAngle = v),
            colorScheme),

          const SizedBox(height: 20),

          // COLOR section
          _buildSectionHeader('COLOR', colorScheme),
          const SizedBox(height: 12),

          _buildCheckboxWithField('Brightness', 'Strength', concept.brightness, concept.brightnessStrength,
            (v) => _updateConcept(() => concept.brightness = v!),
            (v) => _updateConcept(() => concept.brightnessStrength = v),
            colorScheme),

          _buildCheckboxWithField('Contrast', 'Strength', concept.contrast, concept.contrastStrength,
            (v) => _updateConcept(() => concept.contrast = v!),
            (v) => _updateConcept(() => concept.contrastStrength = v),
            colorScheme),

          _buildCheckboxWithField('Saturation', 'Strength', concept.saturation, concept.saturationStrength,
            (v) => _updateConcept(() => concept.saturation = v!),
            (v) => _updateConcept(() => concept.saturationStrength = v),
            colorScheme),

          _buildCheckboxWithField('Hue', 'Strength', concept.hue, concept.hueStrength,
            (v) => _updateConcept(() => concept.hue = v!),
            (v) => _updateConcept(() => concept.hueStrength = v),
            colorScheme),

          const SizedBox(height: 20),

          // RESOLUTION section
          _buildSectionHeader('RESOLUTION', colorScheme),
          const SizedBox(height: 12),

          _buildCheckbox('Override Resolution', concept.overrideResolution, (v) => _updateConcept(() => concept.overrideResolution = v!), colorScheme),

          if (concept.overrideResolution)
            _buildTextField('Resolution', concept.resolutionOverride, (v) => _updateConcept(() => concept.resolutionOverride = v), colorScheme),

          const SizedBox(height: 20),

          // MASK section
          _buildSectionHeader('MASK', colorScheme),
          const SizedBox(height: 12),

          _buildCheckbox('Random Circular Mask Shrink', concept.randomCircularMaskShrink, (v) => _updateConcept(() => concept.randomCircularMaskShrink = v!), colorScheme),
          _buildCheckbox('Random Mask Rotate Crop', concept.randomMaskRotateCrop, (v) => _updateConcept(() => concept.randomMaskRotateCrop = v!), colorScheme),
        ],
      ),
    );
  }

  Widget _buildTextTab(Concept concept, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prompt Source dropdown
          _buildDropdown('Prompt Source', concept.promptSource,
            ['sample', 'txt', 'filename', 'concept'],
            (v) => _updateConcept(() => concept.promptSource = v), colorScheme),

          // Prompt Path
          _buildTextField('Prompt Path (optional)', concept.promptPath,
            (v) => _updateConcept(() => concept.promptPath = v), colorScheme),

          const SizedBox(height: 16),

          // TAG SHUFFLING section
          _buildSectionHeader('TAG SHUFFLING', colorScheme),
          const SizedBox(height: 12),

          _buildCheckbox('Enable Tag Shuffling', concept.enableTagShuffling,
            (v) => _updateConcept(() => concept.enableTagShuffling = v!), colorScheme),

          if (concept.enableTagShuffling) ...[
            Row(
              children: [
                Expanded(child: _buildTextField('Delimiter', concept.tagDelimiter,
                  (v) => _updateConcept(() => concept.tagDelimiter = v), colorScheme)),
                const SizedBox(width: 12),
                Expanded(child: _buildNumberField('Keep Tags', concept.keepTagsCount,
                  (v) => _updateConcept(() => concept.keepTagsCount = v), colorScheme)),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // TAG DROPOUT section
          _buildSectionHeader('TAG DROPOUT', colorScheme),
          const SizedBox(height: 12),

          _buildCheckbox('Enable Tag Dropout', concept.tagDropoutEnable,
            (v) => _updateConcept(() => concept.tagDropoutEnable = v!), colorScheme),

          if (concept.tagDropoutEnable) ...[
            Row(
              children: [
                Expanded(child: _buildDropdown('Mode', concept.tagDropoutMode,
                  ['FULL', 'PARTIAL'],
                  (v) => _updateConcept(() => concept.tagDropoutMode = v), colorScheme)),
                const SizedBox(width: 12),
                Expanded(child: _buildDoubleField('Probability', concept.tagDropoutProbability,
                  (v) => _updateConcept(() => concept.tagDropoutProbability = v), colorScheme)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDoubleField(String label, double value, Function(double) onChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: value.toString()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            onChanged: (v) => onChanged(double.tryParse(v) ?? value),
          ),
        ],
      ),
    );
  }

  // ============ Helper Widgets ============

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Text(
      title,
      style: TextStyle(
        color: colorScheme.onSurface.withOpacity(0.5),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildTextField(String label, String value, Function(String) onChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: value),
            style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPathField(String label, String value, Function(String) onChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: value),
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.folder_open, size: 18, color: colorScheme.onSurface.withOpacity(0.6)),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField(String label, int value, Function(int) onChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            onChanged: (v) => onChanged(int.tryParse(v) ?? value),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, Function(String) onChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                icon: Icon(Icons.arrow_drop_down, color: colorScheme.onSurface.withOpacity(0.5)),
                items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                onChanged: (v) => onChanged(v!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, Function(bool?) onChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: colorScheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxWithField(String checkLabel, String fieldLabel, bool checkValue, int fieldValue,
      Function(bool?) onCheckChanged, Function(int) onFieldChanged, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: checkValue,
              onChanged: onCheckChanged,
              activeColor: colorScheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              checkLabel,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fieldLabel,
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 10),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 50,
                height: 28,
                child: TextField(
                  controller: TextEditingController(text: fieldValue.toString()),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  ),
                  onChanged: (v) => onFieldChanged(int.tryParse(v) ?? fieldValue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============ Actions ============

  void _addConcept() {
    setState(() {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      _concepts.add(Concept(id: id, name: 'New Concept', path: '/path/to/dataset'));
      _selectedConceptId = id;
    });
    _saveConceptsToConfig();
  }

  void _cloneConcept(Concept concept) {
    setState(() {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      _concepts.add(Concept(
        id: id,
        name: '${concept.name} (Copy)',
        path: concept.path,
        type: concept.type,
        enabled: concept.enabled,
        balancing: concept.balancing,
        lossWeight: concept.lossWeight,
        balancingStrategy: concept.balancingStrategy,
        imageVariations: concept.imageVariations,
        textVariations: concept.textVariations,
        includeSubdirectories: concept.includeSubdirectories,
        seed: concept.seed,
        cropJitter: concept.cropJitter,
        randomFlip: concept.randomFlip,
        fixedFlip: concept.fixedFlip,
        maxAngle: concept.maxAngle,
        randomRotate: concept.randomRotate,
        brightness: concept.brightness,
        brightnessStrength: concept.brightnessStrength,
        contrast: concept.contrast,
        contrastStrength: concept.contrastStrength,
        saturation: concept.saturation,
        saturationStrength: concept.saturationStrength,
        hue: concept.hue,
        hueStrength: concept.hueStrength,
        overrideResolution: concept.overrideResolution,
        resolutionOverride: concept.resolutionOverride,
        randomCircularMaskShrink: concept.randomCircularMaskShrink,
        randomMaskRotateCrop: concept.randomMaskRotateCrop,
        promptSource: concept.promptSource,
        promptPath: concept.promptPath,
        enableTagShuffling: concept.enableTagShuffling,
        tagDelimiter: concept.tagDelimiter,
        keepTagsCount: concept.keepTagsCount,
        tagDropoutEnable: concept.tagDropoutEnable,
        tagDropoutMode: concept.tagDropoutMode,
        tagDropoutProbability: concept.tagDropoutProbability,
      ));
      _selectedConceptId = id;
    });
    _saveConceptsToConfig();
  }

  void _deleteConcept(Concept concept) {
    setState(() {
      _concepts.removeWhere((c) => c.id == concept.id);
      if (_selectedConceptId == concept.id) {
        _selectedConceptId = _concepts.isNotEmpty ? _concepts.first.id : null;
      }
    });
    _saveConceptsToConfig();
  }

  void _updateConcept(void Function() update) {
    setState(update);
    _saveConceptsToConfig();
  }
}
