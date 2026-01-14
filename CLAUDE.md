# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## CRITICAL: How to Launch EriUI

**ALWAYS use the server manager to start EriUI. NEVER launch SwarmUI, OneTrainer, or ComfyUI directly.**

```bash
cd /home/alex/eriui

# Start EriUI (desktop mode) - THIS IS THE CORRECT WAY
python server_manager.py start

# Start in web mode (adds CORS server, uses Chrome)
python server_manager.py start --web

# Interactive menu
python server_manager.py

# Check status
python server_manager.py status

# Stop all services
python server_manager.py stop

# View logs for a service
python server_manager.py logs comfyui
```

This starts:
1. EriUI's own ComfyUI backend (port 8199)
2. OneTrainer web UI (port 8100)
3. Flutter desktop app (or web mode with `--web`)

**When working on EriUI**, use server_manager.py - don't launch SwarmUI or OneTrainer separately unless specifically asked.

## Project Overview

**EriUI** is a production-grade, power-user AI media suite built with Flutter. All-in-one application for the complete AI image/video workflow.

**Capabilities:**
- **Generate** - Image/video generation with ComfyUI backend
- **Trainer** - OneTrainer integration for LoRA/model training
- **Video Editor** - Timeline-based NLE with FFmpeg export
- **ComfyUI** - Visual node editor for workflows
- **Utilities** - Batch processing, interrogator, model merger, vid train prep

Desktop-first with web mode support.

## Services & Ports

| Service | Port | Location |
|---------|------|----------|
| ComfyUI | 8199 | `comfyui/ComfyUI` |
| OneTrainer | 8100 | `/home/alex/OneTrainer` |
| EriUI Server | 7802 | `bin/server.dart` (web only) |
| CORS Server | 8899 | `cors_server.py` (web only) |

## Build Commands

```bash
cd /home/alex/eriui/flutter_app

flutter run -d linux          # Run desktop app
flutter build linux --release # Build release
flutter test                  # Run tests
flutter analyze               # Analyze code
flutter pub get               # Get dependencies

# Code generation (after modifying models/providers)
dart run build_runner build --delete-conflicting-outputs
```

## Architecture

### State Management

Uses **Riverpod** with StateNotifier pattern. Providers in `lib/providers/`, feature-specific state in `lib/features/<name>/providers/`.

```dart
// Example: lib/providers/
final myProvider = StateNotifierProvider<MyNotifier, MyState>((ref) {
  return MyNotifier(ref);
});
```

### Service Layer

Services in `lib/services/` handle external APIs:
- `comfyui_service.dart` - WebSocket + REST API to ComfyUI (port 8199)
- `onetrainer_service.dart` - Training API via WebSocket + REST (port 8100)
- `workflow_storage_service.dart` - Hive-based persistence

### Routing

GoRouter with ShellRoute in `lib/app.dart`. All routes wrapped in `AppShell` (`lib/widgets/app_shell.dart`) for top navigation bar.

### Feature Structure

Each feature in `lib/features/<name>/`:
- `<name>_screen.dart` - Main screen widget
- `widgets/` - Feature-specific widgets
- `providers/` - Feature-specific state (optional)
- `models/` - Feature-specific data models
- `services/` - Feature-specific services

### Video Editor Architecture

The video editor (`lib/features/editor/`) has its own sub-architecture:
- `models/editor_models.dart` - EditorProject, Track, Clip, EditorTime
- `providers/editor_provider.dart` - Project state management
- `providers/playback_controller.dart` - media_kit integration
- `services/` - frame extraction, export, effects processing

### Key Providers

- `comfyUIServiceProvider` - ComfyUI API client
- `oneTrainerServiceProvider` - OneTrainer API client
- `trainingStateProvider` - Real-time training progress
- `editorProjectProvider` - Video editor project state

## Key Patterns

### Adding a New Feature

1. Create `lib/features/<name>/<name>_screen.dart`
2. Register route in `lib/app.dart` under `ShellRoute.routes`
3. Add navigation item in `lib/widgets/app_shell.dart` (top tabs or Utilities dropdown)
4. Add provider in `lib/providers/` if needed

### Adding a New Service

1. Create `lib/services/<name>_service.dart`
2. Add async initialization in `main.dart` if needed
3. Create provider to expose via Riverpod

### ComfyUI Workflow Templates

Workflows use template tags for parameter injection:
- `${prompt}`, `${negative_prompt}` - Text prompts
- `${seed}`, `${steps}`, `${cfg}` - Generation params
- `${width}`, `${height}` - Dimensions
- `${model}`, `${vae}`, `${sampler}` - Model selection

## Important Notes

- **Own ComfyUI backend** - EriUI runs its own ComfyUI on port 8199 (not shared)
- **OneTrainer integration** - Connects to OneTrainer at `/home/alex/OneTrainer`
- **SwarmUI is read-only** - `/home/alex/SwarmUI/` is reference only
- **Storage** - Hive storage at `/home/alex/Documents/eriui_storage`
- **Models directory** - `comfyui/ComfyUI/models/` (symlinked to shared models)
- **Platform detection** - Uses `kIsWeb` for web vs desktop code paths (e.g., video player)

## Git

Local repository only (no remote):
```bash
git add -A && git commit -m "Description"
```
