import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

/// Provider for managing parameter panel section states
final panelStateProvider =
    StateNotifierProvider<PanelStateNotifier, PanelState>((ref) {
  return PanelStateNotifier();
});

/// Keys for section identifiers
enum PanelSection {
  // Core sections (always visible)
  variationSeed,
  resolution,
  sampling,
  initImage,
  refineUpscale,
  controlNet,
  video,

  // Advanced sections
  eriInternal,
  advancedVideo,
  videoExtend,
  advancedModelAddons,
  regionalPrompting,
  segmentRefining,
  comfyUI,
  dynamicThresholding,
  freeU,
  scoring,
  advancedSampling,
  otherFixes,
}

/// State for panel section expansion
class PanelState {
  /// Map of section to expanded state
  final Map<PanelSection, bool> expandedSections;

  /// Map of section to enabled state (for toggleable sections)
  final Map<PanelSection, bool> enabledSections;

  /// Whether to show advanced options
  final bool showAdvancedOptions;

  const PanelState({
    this.expandedSections = const {},
    this.enabledSections = const {},
    this.showAdvancedOptions = false,
  });

  /// Check if a section is expanded
  bool isExpanded(PanelSection section) {
    return expandedSections[section] ?? _defaultExpanded(section);
  }

  /// Check if a section is enabled
  bool isEnabled(PanelSection section) {
    return enabledSections[section] ?? false;
  }

  /// Default expanded state for sections
  static bool _defaultExpanded(PanelSection section) {
    switch (section) {
      case PanelSection.sampling:
        return true; // Sampling expanded by default
      default:
        return false;
    }
  }

  PanelState copyWith({
    Map<PanelSection, bool>? expandedSections,
    Map<PanelSection, bool>? enabledSections,
    bool? showAdvancedOptions,
  }) {
    return PanelState(
      expandedSections: expandedSections ?? this.expandedSections,
      enabledSections: enabledSections ?? this.enabledSections,
      showAdvancedOptions: showAdvancedOptions ?? this.showAdvancedOptions,
    );
  }
}

/// Notifier for panel state
class PanelStateNotifier extends StateNotifier<PanelState> {
  static const String _storageKeyPrefix = 'panel_section_';
  static const String _advancedKey = 'panel_show_advanced';

  PanelStateNotifier() : super(const PanelState()) {
    _loadState();
  }

  /// Load persisted state from storage
  Future<void> _loadState() async {
    final expandedSections = <PanelSection, bool>{};
    final enabledSections = <PanelSection, bool>{};

    for (final section in PanelSection.values) {
      final expandedKey = '${_storageKeyPrefix}expanded_${section.name}';
      final enabledKey = '${_storageKeyPrefix}enabled_${section.name}';

      final expanded = StorageService.getBool(expandedKey);
      final enabled = StorageService.getBool(enabledKey);

      if (expanded != null) {
        expandedSections[section] = expanded;
      }
      if (enabled != null) {
        enabledSections[section] = enabled;
      }
    }

    final showAdvanced = StorageService.getBool(_advancedKey) ?? false;

    state = PanelState(
      expandedSections: expandedSections,
      enabledSections: enabledSections,
      showAdvancedOptions: showAdvanced,
    );
  }

  /// Toggle section expanded state
  void toggleExpanded(PanelSection section) {
    final currentExpanded = state.isExpanded(section);
    final newExpanded = !currentExpanded;

    final newExpandedSections = Map<PanelSection, bool>.from(state.expandedSections);
    newExpandedSections[section] = newExpanded;

    state = state.copyWith(expandedSections: newExpandedSections);

    // Persist
    final key = '${_storageKeyPrefix}expanded_${section.name}';
    StorageService.setBool(key, newExpanded);
  }

  /// Set section expanded state
  void setExpanded(PanelSection section, bool expanded) {
    final newExpandedSections = Map<PanelSection, bool>.from(state.expandedSections);
    newExpandedSections[section] = expanded;

    state = state.copyWith(expandedSections: newExpandedSections);

    // Persist
    final key = '${_storageKeyPrefix}expanded_${section.name}';
    StorageService.setBool(key, expanded);
  }

  /// Toggle section enabled state (for toggleable sections)
  void toggleEnabled(PanelSection section) {
    final currentEnabled = state.isEnabled(section);
    final newEnabled = !currentEnabled;

    final newEnabledSections = Map<PanelSection, bool>.from(state.enabledSections);
    newEnabledSections[section] = newEnabled;

    // Also expand when enabled
    final newExpandedSections = Map<PanelSection, bool>.from(state.expandedSections);
    if (newEnabled) {
      newExpandedSections[section] = true;
    }

    state = state.copyWith(
      enabledSections: newEnabledSections,
      expandedSections: newExpandedSections,
    );

    // Persist
    final enabledKey = '${_storageKeyPrefix}enabled_${section.name}';
    StorageService.setBool(enabledKey, newEnabled);

    if (newEnabled) {
      final expandedKey = '${_storageKeyPrefix}expanded_${section.name}';
      StorageService.setBool(expandedKey, true);
    }
  }

  /// Set section enabled state
  void setEnabled(PanelSection section, bool enabled) {
    final newEnabledSections = Map<PanelSection, bool>.from(state.enabledSections);
    newEnabledSections[section] = enabled;

    state = state.copyWith(enabledSections: newEnabledSections);

    // Persist
    final key = '${_storageKeyPrefix}enabled_${section.name}';
    StorageService.setBool(key, enabled);
  }

  /// Toggle show advanced options
  void toggleAdvancedOptions() {
    final newValue = !state.showAdvancedOptions;
    state = state.copyWith(showAdvancedOptions: newValue);
    StorageService.setBool(_advancedKey, newValue);
  }

  /// Set show advanced options
  void setAdvancedOptions(bool show) {
    state = state.copyWith(showAdvancedOptions: show);
    StorageService.setBool(_advancedKey, show);
  }

  /// Collapse all sections
  void collapseAll() {
    final newExpandedSections = <PanelSection, bool>{};
    for (final section in PanelSection.values) {
      newExpandedSections[section] = false;
      final key = '${_storageKeyPrefix}expanded_${section.name}';
      StorageService.setBool(key, false);
    }
    state = state.copyWith(expandedSections: newExpandedSections);
  }

  /// Expand all sections
  void expandAll() {
    final newExpandedSections = <PanelSection, bool>{};
    for (final section in PanelSection.values) {
      newExpandedSections[section] = true;
      final key = '${_storageKeyPrefix}expanded_${section.name}';
      StorageService.setBool(key, true);
    }
    state = state.copyWith(expandedSections: newExpandedSections);
  }
}
