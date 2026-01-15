import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'widgets/eri_parameters_panel.dart';
import 'widgets/eri_bottom_panel.dart';
import 'widgets/prompt_bar.dart';
import 'widgets/image_metadata_panel.dart';
// Workflow integration
import '../workflow_browser/workflow_browser.dart';
import '../workflow_browser/workflow_params_panel.dart';
import '../workflow_browser/providers/workflow_execution_provider.dart';

/// Panel width providers for resizable panels
final leftPanelWidthProvider = StateProvider<double>((ref) => 320);
final rightPanelWidthProvider = StateProvider<double>((ref) => 300);
final bottomPanelHeightProvider = StateProvider<double>((ref) => 200);

/// Provider to track if workflow browser panel is visible
final workflowBrowserVisibleProvider = StateProvider<bool>((ref) => false);

/// Provider to track currently active workflow for generation
final activeWorkflowIdProvider = StateProvider<String?>((ref) => null);

/// Main image generation screen - ERI style layout
class GenerateScreen extends ConsumerStatefulWidget {
  const GenerateScreen({super.key});

  @override
  ConsumerState<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends ConsumerState<GenerateScreen> {
  bool _wasGenerating = false;
  bool _isDraggingLeft = false;
  bool _isDraggingRight = false;
  bool _isDraggingBottom = false;
  bool _isDraggingWorkflow = false;
  double _workflowPanelWidth = 260;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(modelsProvider.notifier).loadModels();
      // Check for workflow query parameter
      _checkWorkflowQueryParam();
    });
  }

  void _checkWorkflowQueryParam() {
    // Check if we navigated here with a workflow parameter
    final uri = GoRouterState.of(context).uri;
    final workflowId = uri.queryParameters['workflow'];
    if (workflowId != null && workflowId.isNotEmpty) {
      // Set active workflow and load it
      ref.read(activeWorkflowIdProvider.notifier).state = workflowId;
      ref.read(workflowBrowserProvider.notifier).selectWorkflow(workflowId);
      // Load workflow into execution provider
      final browserState = ref.read(workflowBrowserProvider);
      if (browserState.selectedWorkflow != null) {
        ref.read(workflowExecutionProvider.notifier).loadWorkflow(browserState.selectedWorkflow!);
      }
    }
  }

  void _checkGenerationComplete() {
    final generationState = ref.read(generationProvider);
    final params = ref.read(generationParamsProvider);

    if (_wasGenerating && !generationState.isGenerating && generationState.generatedImages.isNotEmpty) {
      final historyNotifier = ref.read(generationHistoryProvider.notifier);
      for (final url in generationState.generatedImages) {
        historyNotifier.addImage(GeneratedImage(
          url: url,
          prompt: params.prompt,
          negativePrompt: params.negativePrompt,
          params: params,
          createdAt: DateTime.now(),
          id: '${DateTime.now().millisecondsSinceEpoch}_${url.hashCode}',
        ));
      }
    }
    _wasGenerating = generationState.isGenerating;
  }

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(generationProvider);
    final generationParams = ref.watch(generationParamsProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkGenerationComplete());

    final leftWidth = ref.watch(leftPanelWidthProvider);
    final rightWidth = ref.watch(rightPanelWidthProvider);
    final bottomHeight = ref.watch(bottomPanelHeightProvider);
    final showWorkflowBrowser = ref.watch(workflowBrowserVisibleProvider);
    final workflowExecState = ref.watch(workflowExecutionProvider);
    final hasActiveWorkflow = workflowExecState.activeWorkflow != null;

    return Column(
      children: [
        // Main content area
        Expanded(
          child: Row(
            children: [
              // Collapsible workflow browser panel (left-most)
              if (showWorkflowBrowser) ...[
                SizedBox(
                  width: _workflowPanelWidth,
                  child: _WorkflowBrowserSidePanel(
                    onWorkflowSelected: (workflow) {
                      ref.read(activeWorkflowIdProvider.notifier).state = workflow.id;
                      ref.read(workflowExecutionProvider.notifier).loadWorkflow(workflow);
                    },
                    onClose: () {
                      ref.read(workflowBrowserVisibleProvider.notifier).state = false;
                    },
                  ),
                ),
                // Workflow panel resize handle
                _ResizeHandle(
                  isVertical: true,
                  isDragging: _isDraggingWorkflow,
                  onDragStart: () => setState(() => _isDraggingWorkflow = true),
                  onDragEnd: () => setState(() => _isDraggingWorkflow = false),
                  onDragUpdate: (dx) {
                    setState(() {
                      _workflowPanelWidth = (_workflowPanelWidth + dx).clamp(200.0, 400.0);
                    });
                  },
                ),
              ],
              // Left panel - Parameters or Workflow Params (resizable)
              SizedBox(
                width: leftWidth,
                child: hasActiveWorkflow
                    ? _WorkflowParamsLeftPanel(
                        onClearWorkflow: () {
                          ref.read(activeWorkflowIdProvider.notifier).state = null;
                          ref.read(workflowExecutionProvider.notifier).loadWorkflow(
                            // Clear by loading empty workflow
                            workflowExecState.activeWorkflow!.copyWith(
                              customParams: '[]',
                            ),
                          );
                        },
                      )
                    : const EriParametersPanel(),
              ),
              // Left resize handle
              _ResizeHandle(
                isVertical: true,
                isDragging: _isDraggingLeft,
                onDragStart: () => setState(() => _isDraggingLeft = true),
                onDragEnd: () => setState(() => _isDraggingLeft = false),
                onDragUpdate: (dx) {
                  final newWidth = (leftWidth + dx).clamp(200.0, 500.0);
                  ref.read(leftPanelWidthProvider.notifier).state = newWidth;
                },
              ),
              // Center column - Image preview + Prompt bar
              Expanded(
                child: Column(
                  children: [
                    // Image preview (takes remaining space)
                    Expanded(
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Builder(builder: (context) {
                          final history = ref.watch(generationHistoryProvider);
                          final allImages = [
                            ...generationState.generatedImages,
                            ...history.map((h) => h.url),
                          ];
                          return GenerationPreview(
                            imageUrl: generationState.currentImage ??
                                (generationState.generatedImages.isNotEmpty
                                    ? generationState.generatedImages.first
                                    : null),
                            isGenerating: generationState.isGenerating,
                            isVideoMode: generationParams.videoMode,
                            progress: generationState.progress,
                            currentStep: generationState.currentStep,
                            totalSteps: generationState.totalSteps,
                            allImages: allImages.isNotEmpty ? allImages : null,
                          );
                        }),
                      ),
                    ),
                    // Workflow toggle + Prompt bar with autocomplete - above bottom tabs
                    _WorkflowPromptRow(
                      showWorkflowBrowser: showWorkflowBrowser,
                      hasActiveWorkflow: hasActiveWorkflow,
                      activeWorkflowName: workflowExecState.activeWorkflow?.name,
                    ),
                  ],
                ),
              ),
              // Right resize handle
              _ResizeHandle(
                isVertical: true,
                isDragging: _isDraggingRight,
                onDragStart: () => setState(() => _isDraggingRight = true),
                onDragEnd: () => setState(() => _isDraggingRight = false),
                onDragUpdate: (dx) {
                  final newWidth = (rightWidth - dx).clamp(200.0, 500.0);
                  ref.read(rightPanelWidthProvider.notifier).state = newWidth;
                },
              ),
              // Right panel - History OR Metadata (like SwarmUI)
              SizedBox(
                width: rightWidth,
                child: _RightPanel(),
              ),
            ],
          ),
        ),
        // Bottom resize handle
        _ResizeHandle(
          isVertical: false,
          isDragging: _isDraggingBottom,
          onDragStart: () => setState(() => _isDraggingBottom = true),
          onDragEnd: () => setState(() => _isDraggingBottom = false),
          onDragUpdate: (dy) {
            final newHeight = (bottomHeight - dy).clamp(100.0, 400.0);
            ref.read(bottomPanelHeightProvider.notifier).state = newHeight;
          },
        ),
        // Bottom panel - ONLY tabs (no prompt area)
        SizedBox(
          height: bottomHeight,
          child: EriBottomPanel(),
        ),
      ],
    );
  }
}

/// Right-side panel - shows History OR Metadata (like SwarmUI)
class _RightPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedImage = ref.watch(selectedImageProvider);

    // Show metadata panel if an image is selected
    if (selectedImage.hasImage) {
      return Column(
        children: [
          // Back to history button
          _BackToHistoryButton(),
          // Metadata panel
          const Expanded(child: ImageMetadataPanel()),
        ],
      );
    }

    // Otherwise show history
    return _HistoryPanel();
  }
}

/// Back to history button
class _BackToHistoryButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            onPressed: () => ref.read(selectedImageProvider.notifier).clearSelection(),
            tooltip: 'Back to history',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Text('Image Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => ref.read(selectedImageProvider.notifier).clearSelection(),
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// Show right-click context menu for image
void _showImageContextMenu(BuildContext context, WidgetRef ref, String imageUrl, Offset position) {
  final colorScheme = Theme.of(context).colorScheme;

  showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
    items: [
      PopupMenuItem<String>(
        value: 'use_image',
        child: Row(
          children: [
            Icon(Icons.image, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Use Image', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'view_full',
        child: Row(
          children: [
            Icon(Icons.fullscreen, size: 18, color: colorScheme.onSurface),
            const SizedBox(width: 8),
            const Text('View Full Size', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'reuse_params',
        child: Row(
          children: [
            Icon(Icons.refresh, size: 18, color: colorScheme.onSurface),
            const SizedBox(width: 8),
            const Text('Reuse Parameters', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 18, color: colorScheme.error),
            const SizedBox(width: 8),
            Text('Delete Image', style: TextStyle(fontSize: 13, color: colorScheme.error)),
          ],
        ),
      ),
    ],
  ).then((value) {
    if (value == null) return;

    switch (value) {
      case 'use_image':
        // Set as init image
        ref.read(generationParamsProvider.notifier).setExtraParam('init_image', imageUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image set as init image')),
        );
        break;
      case 'view_full':
        ImageViewerDialog.show(context, imageUrl: imageUrl);
        break;
      case 'reuse_params':
        // Select image to load params
        ref.read(selectedImageProvider.notifier).selectImageUrl(imageUrl);
        break;
      case 'delete':
        _confirmDeleteImage(context, ref, imageUrl);
        break;
    }
  });
}

/// Confirm delete dialog
void _confirmDeleteImage(BuildContext context, WidgetRef ref, String imageUrl) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Image?'),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // Remove from history
            final history = ref.read(generationHistoryProvider);
            final imageToRemove = history.firstWhere(
              (img) => img.url == imageUrl,
              orElse: () => GeneratedImage(
                url: imageUrl,
                prompt: '',
                params: const GenerationParams(),
                createdAt: DateTime.now(),
              ),
            );
            if (imageToRemove.id != null) {
              ref.read(generationHistoryProvider.notifier).removeImage(imageToRemove.id!);
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image removed from history')),
            );
          },
          child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      ],
    ),
  );
}

/// History panel showing generated images
class _HistoryPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final history = ref.watch(generationHistoryProvider);
    final generationState = ref.watch(generationProvider);
    final selectedImage = ref.watch(selectedImageProvider);

    // Combine current batch with history
    final allImages = [
      ...generationState.generatedImages,
      ...history.map((h) => h.url),
    ];

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.history, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('History', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                const Spacer(),
                Text('${allImages.length}', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          // Image grid
          Expanded(
            child: allImages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined, size: 40, color: colorScheme.outlineVariant),
                        const SizedBox(height: 8),
                        Text('No images yet', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text('Generate some!', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemCount: allImages.length,
                    itemBuilder: (context, index) {
                      final imageUrl = allImages[index];
                      final isSelected = selectedImage.imageUrl == imageUrl;

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            // Select image to show metadata
                            ref.read(selectedImageProvider.notifier).selectImageUrl(imageUrl);
                          },
                          onDoubleTap: () {
                            // Double-click opens full viewer
                            ImageViewerDialog.show(
                              context,
                              imageUrl: imageUrl,
                              allImages: allImages,
                              initialIndex: index,
                            );
                          },
                          onSecondaryTapUp: (details) {
                            // Right-click context menu
                            _showImageContextMenu(context, ref, imageUrl, details.globalPosition);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: isSelected
                                  ? Border.all(color: colorScheme.primary, width: 2)
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(isSelected ? 2 : 4),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Icon(Icons.broken_image, color: colorScheme.error, size: 20),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Resize handle for draggable panel borders
class _ResizeHandle extends StatelessWidget {
  final bool isVertical;
  final bool isDragging;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final Function(double) onDragUpdate;

  const _ResizeHandle({
    required this.isVertical,
    required this.isDragging,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: isVertical ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        onHorizontalDragStart: isVertical ? (_) => onDragStart() : null,
        onHorizontalDragUpdate: isVertical ? (d) => onDragUpdate(d.delta.dx) : null,
        onHorizontalDragEnd: isVertical ? (_) => onDragEnd() : null,
        onVerticalDragStart: !isVertical ? (_) => onDragStart() : null,
        onVerticalDragUpdate: !isVertical ? (d) => onDragUpdate(d.delta.dy) : null,
        onVerticalDragEnd: !isVertical ? (_) => onDragEnd() : null,
        child: Container(
          width: isVertical ? 6 : double.infinity,
          height: isVertical ? double.infinity : 6,
          color: isDragging ? colorScheme.primary.withOpacity(0.3) : Colors.transparent,
          child: Center(
            child: Container(
              width: isVertical ? 2 : 40,
              height: isVertical ? 40 : 2,
              decoration: BoxDecoration(
                color: isDragging ? colorScheme.primary : colorScheme.outlineVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Workflow browser side panel for the generate screen
class _WorkflowBrowserSidePanel extends ConsumerWidget {
  final Function(dynamic) onWorkflowSelected;
  final VoidCallback onClose;

  const _WorkflowBrowserSidePanel({
    required this.onWorkflowSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Header with close button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.account_tree, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Workflows',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Close workflow browser',
                ),
              ],
            ),
          ),
          // Workflow browser content
          Expanded(
            child: WorkflowBrowserPanel(
              onWorkflowSelected: onWorkflowSelected,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Left panel showing workflow parameters when a workflow is active
class _WorkflowParamsLeftPanel extends ConsumerWidget {
  final VoidCallback onClearWorkflow;

  const _WorkflowParamsLeftPanel({required this.onClearWorkflow});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final workflowState = ref.watch(workflowExecutionProvider);
    final workflow = workflowState.activeWorkflow;

    if (workflow == null) {
      return const EriParametersPanel();
    }

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Workflow header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.account_tree, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workflow.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (workflow.description != null && workflow.description!.isNotEmpty)
                        Text(
                          workflow.description!,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onClearWorkflow,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Clear workflow',
                ),
              ],
            ),
          ),
          // Workflow parameters - includes its own execute button
          Expanded(
            child: WorkflowParamsPanel(
              workflow: workflow,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row containing workflow toggle and prompt bar
class _WorkflowPromptRow extends ConsumerWidget {
  final bool showWorkflowBrowser;
  final bool hasActiveWorkflow;
  final String? activeWorkflowName;

  const _WorkflowPromptRow({
    required this.showWorkflowBrowser,
    required this.hasActiveWorkflow,
    this.activeWorkflowName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          // Workflow toggle button
          Tooltip(
            message: showWorkflowBrowser ? 'Hide workflows' : 'Show workflows',
            child: InkWell(
              onTap: () {
                ref.read(workflowBrowserVisibleProvider.notifier).state = !showWorkflowBrowser;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: showWorkflowBrowser
                      ? colorScheme.primaryContainer.withOpacity(0.5)
                      : Colors.transparent,
                  border: Border(
                    right: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_tree,
                      size: 18,
                      color: showWorkflowBrowser ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                    if (hasActiveWorkflow && activeWorkflowName != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          activeWorkflowName!,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Prompt bar takes remaining space
          const Expanded(child: PromptBar()),
        ],
      ),
    );
  }
}
