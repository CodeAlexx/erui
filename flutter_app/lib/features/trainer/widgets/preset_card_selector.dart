import 'package:flutter/material.dart';

/// Preset info model
class PresetInfo {
  final String name;
  final String path;
  final String? lastModified;
  final int? id;
  final bool isDbPreset;

  PresetInfo({
    required this.name,
    this.path = '',
    this.lastModified,
    this.id,
    this.isDbPreset = false,
  });
}

/// Preset Card Selector Dialog - matches OneTrainer React UI
class PresetCardSelector extends StatefulWidget {
  final List<PresetInfo> presets;
  final String? currentPreset;
  final Function(PresetInfo) onSelect;
  final Function(PresetInfo)? onDelete;

  const PresetCardSelector({
    super.key,
    required this.presets,
    this.currentPreset,
    required this.onSelect,
    this.onDelete,
  });

  /// Show the preset selector dialog
  static Future<PresetInfo?> show(
    BuildContext context, {
    required List<PresetInfo> presets,
    String? currentPreset,
    Function(PresetInfo)? onDelete,
  }) {
    return showDialog<PresetInfo>(
      context: context,
      builder: (context) => PresetCardSelector(
        presets: presets,
        currentPreset: currentPreset,
        onSelect: (preset) => Navigator.of(context).pop(preset),
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<PresetCardSelector> createState() => _PresetCardSelectorState();
}

class _PresetCardSelectorState extends State<PresetCardSelector> {
  String _searchQuery = '';
  String _activeFilter = 'All';
  final Set<String> _favorites = {};

  static const _allFilters = [
    'All', 'Kandinsky', 'Qwen', 'Qwen-Edit', 'Flux', 'SDXL', 'SD3', 'SD',
    'Chroma', 'Z-Image', 'PixArt', 'Hunyuan', 'HiDream', 'Wan', 'LoRA', 'Finetune'
  ];

  // Model type colors
  static const _modelColors = {
    'Qwen': Color(0xFF9333EA),      // purple-600
    'Qwen-Edit': Color(0xFF7C3AED), // violet-600
    'Kandinsky': Color(0xFFE11D48), // rose-600
    'Flux': Color(0xFF2563EB),      // blue-600
    'SDXL': Color(0xFF16A34A),      // green-600
    'SD3': Color(0xFF0D9488),       // teal-600
    'SD': Color(0xFF4B5563),        // gray-600
    'Chroma': Color(0xFFDB2777),    // pink-600
    'Z-Image': Color(0xFFEA580C),   // orange-600
    'PixArt': Color(0xFF0891B2),    // cyan-600
    'Hunyuan': Color(0xFFDC2626),   // red-600
    'HiDream': Color(0xFF4F46E5),   // indigo-600
    'Sana': Color(0xFFCA8A04),      // yellow-600
    'Cascade': Color(0xFFD97706),   // amber-600
    'Wan': Color(0xFF059669),       // emerald-600
    'Other': Color(0xFF6B7280),     // gray-500
  };

  String _getModelType(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('qwen') && (lower.contains('edit') || lower.contains('qedit'))) return 'Qwen-Edit';
    if (lower.contains('qwen')) return 'Qwen';
    if (lower.contains('kandinsky') || lower.contains('k5')) return 'Kandinsky';
    if (lower.contains('flux')) return 'Flux';
    if (lower.contains('sdxl') || lower.contains('xl')) return 'SDXL';
    if (lower.contains('sd 3') || lower.contains('sd3')) return 'SD3';
    if (lower.contains('sd 1') || lower.contains('sd 2') || lower.contains('sd1') || lower.contains('sd2')) return 'SD';
    if (lower.contains('chroma')) return 'Chroma';
    if (lower.contains('z-image') || lower.contains('zimage')) return 'Z-Image';
    if (lower.contains('pixart')) return 'PixArt';
    if (lower.contains('hunyuan')) return 'Hunyuan';
    if (lower.contains('hidream')) return 'HiDream';
    if (lower.contains('sana')) return 'Sana';
    if (lower.contains('cascade') || lower.contains('wuerstchen')) return 'Cascade';
    if (lower.contains('wan')) return 'Wan';
    return 'Other';
  }

  String _getMethodType(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('lora') || lower.contains('lokr') || lower.contains('loha')) return 'LoRA';
    if (lower.contains('finetune') || lower.contains('fine_tune')) return 'Finetune';
    if (lower.contains('embedding')) return 'Embedding';
    return 'Other';
  }

  String? _getVramTier(String name) {
    final match = RegExp(r'(\d+)\s*GB', caseSensitive: false).firstMatch(name);
    return match != null ? '${match.group(1)}GB' : null;
  }

  List<PresetInfo> get _filteredPresets {
    var result = List<PresetInfo>.from(widget.presets);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((p) => p.name.toLowerCase().contains(query)).toList();
    }

    // Category filter
    if (_activeFilter != 'All') {
      if (['LoRA', 'Finetune', 'Embedding'].contains(_activeFilter)) {
        result = result.where((p) => _getMethodType(p.name) == _activeFilter).toList();
      } else {
        result = result.where((p) => _getModelType(p.name) == _activeFilter).toList();
      }
    }

    // Sort: favorites first, then alphabetically
    result.sort((a, b) {
      final aFav = _favorites.contains(a.name);
      final bFav = _favorites.contains(b.name);
      if (aFav && !bFav) return -1;
      if (!aFav && bFav) return 1;
      return a.name.compareTo(b.name);
    });

    return result;
  }

  Map<String, int> get _filterCounts {
    final counts = <String, int>{'All': widget.presets.length};
    for (final p in widget.presets) {
      final model = _getModelType(p.name);
      final method = _getMethodType(p.name);
      counts[model] = (counts[model] ?? 0) + 1;
      counts[method] = (counts[method] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filteredPresets;
    final counts = _filterCounts;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 700),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
              ),
              child: Row(
                children: [
                  Text('Select Preset', style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ],
              ),
            ),

            // Search & Filters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
              ),
              child: Column(
                children: [
                  // Search
                  TextField(
                    autofocus: true,
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search presets...',
                      hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
                      prefixIcon: Icon(Icons.search, color: colorScheme.onSurface.withOpacity(0.4)),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                  const SizedBox(height: 12),

                  // Filter chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allFilters
                        .where((f) => (counts[f] ?? 0) > 0)
                        .map((filter) => _buildFilterChip(filter, counts[filter] ?? 0, colorScheme))
                        .toList(),
                  ),
                ],
              ),
            ),

            // Preset Grid
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 48, color: colorScheme.onSurface.withOpacity(0.2)),
                          const SizedBox(height: 8),
                          Text('No presets found', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4))),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 280,
                        childAspectRatio: 2.2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _buildPresetCard(filtered[index], colorScheme),
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${filtered.length} presets', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                  Text('Click to load • Star to favorite', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filter, int count, ColorScheme colorScheme) {
    final isActive = _activeFilter == filter;
    return InkWell(
      onTap: () => setState(() => _activeFilter = filter),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.primary : colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '$filter ($count)',
          style: TextStyle(
            color: isActive ? colorScheme.onPrimary : colorScheme.onSurface.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPresetCard(PresetInfo preset, ColorScheme colorScheme) {
    final modelType = _getModelType(preset.name);
    final methodType = _getMethodType(preset.name);
    final vram = _getVramTier(preset.name);
    final isFavorite = _favorites.contains(preset.name);
    final isSelected = widget.currentPreset == preset.name;
    final modelColor = _modelColors[modelType] ?? _modelColors['Other']!;

    return InkWell(
      onTap: () => widget.onSelect(preset),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.1) : colorScheme.surfaceContainerHighest.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + favorite
            Row(
              children: [
                Expanded(
                  child: Text(
                    preset.name.replaceFirst('#', ''),
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isFavorite) {
                        _favorites.remove(preset.name);
                      } else {
                        _favorites.add(preset.name);
                      }
                    });
                  },
                  child: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    size: 18,
                    color: isFavorite ? Colors.amber : colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Badges
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _buildBadge(modelType, modelColor),
                if (methodType != 'Other') _buildBadge(methodType, Colors.grey.shade600),
                if (vram != null) _buildBadge(vram, colorScheme.outlineVariant),
              ],
            ),
            const Spacer(),

            // Bottom row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      preset.isDbPreset ? Icons.storage : Icons.schedule,
                      size: 12,
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      preset.isDbPreset ? 'Database' : 'JSON',
                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 10),
                    ),
                  ],
                ),
                if (widget.onDelete != null)
                  InkWell(
                    onTap: () => widget.onDelete!(preset),
                    child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400.withOpacity(0.6)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }
}
