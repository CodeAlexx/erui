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
import 'features/trainer/onetrainer_shell.dart';
import 'widgets/app_shell.dart';
import 'providers/theme_provider.dart';

/// Main ERI application widget
class EriUIApp extends ConsumerWidget {
  const EriUIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = ref.watch(colorSchemeProvider);

    return MaterialApp.router(
      title: 'ERI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(colorScheme),
      darkTheme: AppTheme.dark(colorScheme),
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
          path: '/trainer',
          name: 'trainer',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: OneTrainerShell(),
          ),
        ),
      ],
    ),
  ],
);
