import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_theme.dart';
import 'features/generate/generate_screen.dart';
import 'features/models/models_screen.dart';
import 'features/gallery/gallery_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/comfy_workflow/comfy_workflow_screen.dart';
import 'features/comfyui_editor/comfyui_editor_screen.dart';
import 'features/editor/editor_screen.dart';
import 'features/trainer/onetrainer_shell.dart';
// Tools screens
import 'features/tools/analytics_screen.dart';
import 'features/tools/batch_processing_screen.dart';
import 'features/tools/grid_generator_screen.dart';
import 'features/tools/image_interrogator_screen.dart';
import 'features/tools/model_comparison_screen.dart';
import 'features/tools/model_merger_screen.dart';
// Other orphaned screens
import 'features/wildcards/wildcards_screen.dart';
import 'features/workflow/workflow_screen.dart';
import 'features/regional/regional_prompt_editor.dart';
// Workflow browser and editor
import 'features/workflow_browser/workflow_browser_screen.dart';
import 'features/workflow_editor/visual_workflow_editor.dart';
import 'widgets/app_shell.dart';
import 'providers/theme_provider.dart';

/// Main ERI application widget
class EriUIApp extends ConsumerWidget {
  const EriUIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = ref.watch(colorSchemeProvider);
    final uiDensity = ref.watch(uiDensityProvider);
    final densityNotifier = ref.read(uiDensityProvider.notifier);

    return MaterialApp.router(
      title: 'ERI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(colorScheme).copyWith(
        visualDensity: densityNotifier.visualDensity,
      ),
      darkTheme: AppTheme.dark(colorScheme).copyWith(
        visualDensity: densityNotifier.visualDensity,
      ),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}

/// App router configuration
final _router = GoRouter(
  initialLocation: '/generate',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return AppShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/generate',
          name: 'generate',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GenerateScreen(),
          ),
        ),
        GoRoute(
          path: '/models',
          name: 'models',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ModelsScreen(),
          ),
        ),
        GoRoute(
          path: '/gallery',
          name: 'gallery',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GalleryScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
        GoRoute(
          path: '/workflow',
          name: 'workflow',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ComfyWorkflowScreen(),
          ),
        ),
        GoRoute(
          path: '/comfyui',
          name: 'comfyui',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ComfyUIEditorScreen(),
          ),
        ),
        GoRoute(
          path: '/editor',
          name: 'editor',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: EditorScreen(),
          ),
        ),
        GoRoute(
          path: '/trainer',
          name: 'trainer',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: OneTrainerShell(),
          ),
        ),
        // Tools routes
        GoRoute(
          path: '/tools/analytics',
          name: 'analytics',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AnalyticsScreen(),
          ),
        ),
        GoRoute(
          path: '/tools/batch',
          name: 'batch',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: BatchProcessingScreen(),
          ),
        ),
        GoRoute(
          path: '/tools/grid',
          name: 'grid',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GridGeneratorScreen(),
          ),
        ),
        GoRoute(
          path: '/tools/interrogator',
          name: 'interrogator',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ImageInterrogatorScreen(),
          ),
        ),
        GoRoute(
          path: '/tools/compare',
          name: 'compare',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ModelComparisonScreen(),
          ),
        ),
        GoRoute(
          path: '/tools/merger',
          name: 'merger',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ModelMergerScreen(),
          ),
        ),
        // Other screens
        GoRoute(
          path: '/wildcards',
          name: 'wildcards',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: WildcardsScreen(),
          ),
        ),
        GoRoute(
          path: '/workflow-builder',
          name: 'workflow-builder',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: WorkflowScreen(),
          ),
        ),
        GoRoute(
          path: '/regional',
          name: 'regional',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: RegionalPromptEditor(),
          ),
        ),
        // Workflow browser and editor routes
        GoRoute(
          path: '/workflow-browser',
          name: 'workflow-browser',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: WorkflowBrowserScreen(),
          ),
        ),
        GoRoute(
          path: '/workflow/edit/:id',
          name: 'workflow-edit',
          pageBuilder: (context, state) {
            final workflowId = state.pathParameters['id'];
            return NoTransitionPage(
              child: _WorkflowEditorWrapper(workflowId: workflowId),
            );
          },
        ),
        GoRoute(
          path: '/workflow/new',
          name: 'workflow-new',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: _WorkflowEditorWrapper(workflowId: null),
          ),
        ),
      ],
    ),
  ],
);

/// Wrapper widget that loads workflow and passes to editor
class _WorkflowEditorWrapper extends ConsumerWidget {
  final String? workflowId;

  const _WorkflowEditorWrapper({required this.workflowId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VisualWorkflowEditor(
      initialWorkflow: null, // TODO: Load from provider based on workflowId
      onSave: (workflow) {
        // Save and navigate back
        context.go('/workflow-browser');
      },
    );
  }
}
