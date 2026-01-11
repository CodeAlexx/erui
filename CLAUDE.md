# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## CRITICAL: How to Launch EriUI

**ALWAYS use the server manager to start EriUI. NEVER launch SwarmUI, OneTrainer, or ComfyUI directly.**

```bash
cd /home/alex/eriui

# Start EriUI (desktop mode) - THIS IS THE CORRECT WAY
python server_manager.py start

# Or use interactive menu
python server_manager.py

# Check status
python server_manager.py status

# Stop all services
python server_manager.py stop
```

This starts:
1. EriUI's own ComfyUI backend (port 8199)
2. OneTrainer web UI (port 8100)
3. Flutter desktop app

**When working on EriUI**, use server_manager.py - don't launch SwarmUI or OneTrainer separately unless specifically asked.

## Project Overview

**EriUI** is a production-grade, power-user AI media suite built with Flutter. All-in-one application for the complete AI image/video workflow.

**Capabilities:**
- **Inference** - SwarmUI-style generate screen with own ComfyUI backend
- **Training** - Embedded OneTrainer web UI (`/home/alex/OneTrainer`)
- **Video Editor** - Timeline-based editing with FFmpeg integration
- **Captioner** - Qwen Instruct for image/video captioning
- **Video Prep** - Dataset preparation tools for video training
- **Workflow System** - ComfyUI workflow browser and visual node editor

Desktop-first with web mode support.

## Services & Ports

| Service | Port | Location | Mode |
|---------|------|----------|------|
| ComfyUI | 8199 | `/home/alex/eriui/comfyui/ComfyUI` | Both |
| OneTrainer | 8100 | `/home/alex/OneTrainer` | Both |
| EriUI Server | 7802 | `/home/alex/eriui/bin/server.dart` | Web only |
| CORS Server | 8899 | `/home/alex/eriui/cors_server.py` | Web only |
| Workflow API | 7803 | ComfyUI workflow system | Both |

## Build Commands (Flutter App Only)

```bash
cd /home/alex/eriui/flutter_app

# Run desktop app (if not using server_manager)
flutter run -d linux

# Build release
flutter build linux --release

# Run tests
flutter test

# Analyze code
flutter analyze

# Get dependencies
flutter pub get

# Generate code (Riverpod generators, Hive adapters)
dart run build_runner build --delete-conflicting-outputs
```

## Architecture

### State Management Pattern

Uses **Riverpod** with StateNotifier pattern throughout:

```dart
// Provider definition in lib/providers/
final myProvider = StateNotifierProvider<MyNotifier, MyState>((ref) {
  return MyNotifier(ref);
});

class MyNotifier extends StateNotifier<MyState> {
  final Ref _ref;
  MyNotifier(this._ref) : super(MyState.initial());
}
```

### Feature Module Structure

Each feature in `lib/features/<name>/` follows:
- `<name>_screen.dart` - Main screen widget
- `widgets/` - Feature-specific widgets
- `providers/` - Feature-specific state (optional, most in `lib/providers/`)

### Service Layer

Services in `lib/services/` handle business logic and external APIs:
- `comfyui_service.dart` - WebSocket + REST API to ComfyUI backend
- `onetrainer_service.dart` - Training management API
- `workflow_storage_service.dart` - Hive-based workflow persistence
- `comfyui_workflow_api.dart` - Workflow template execution

### Routing

GoRouter with ShellRoute in `lib/app.dart`. All routes wrapped in `AppShell` for consistent navigation.

### Data Persistence

Hive for local storage:
- Storage directory: `/home/alex/Documents/eriui_storage`
- Initialize in `main.dart` before `runApp()`
- Workflows stored as JSON in Hive boxes

## Key Patterns

### Adding a New Feature

1. Create `lib/features/<name>/<name>_screen.dart`
2. Register route in `lib/app.dart` under `ShellRoute.routes`
3. Add navigation item in `lib/widgets/app_shell.dart`
4. Add provider in `lib/providers/` if needed

### Adding a New Service

1. Create `lib/services/<name>_service.dart`
2. Add initialization in `main.dart` if async setup required
3. Create provider to expose service via Riverpod

### Workflow System

ComfyUI workflows use template tags for parameter injection:
- `${prompt}`, `${negative_prompt}` - Text prompts
- `${seed}`, `${steps}`, `${cfg}` - Generation params
- `${width}`, `${height}` - Dimensions
- `${model}`, `${vae}`, `${sampler}` - Model selection

Key files:
- Models: `lib/models/workflow_models.dart`
- Validation: `lib/services/workflow_validation_service.dart`
- Execution: `lib/services/comfyui_workflow_api.dart`

## Important Notes

- **Own ComfyUI backend** - EriUI runs its own ComfyUI instance on port 8199 (not shared with other tools)
- **OneTrainer web UI** - Embedded as the working training interface at `/home/alex/OneTrainer` (kept as fallback and primary training)
- **SwarmUI is read-only** - `/home/alex/SwarmUI/` and its ComfyUI backend are reference only, do not modify
- **Desktop-first** - CORS server only needed for web mode
- **Models directory** - ComfyUI models at `/home/alex/eriui/comfyui/ComfyUI/models/` (symlinked to shared location)

## Git

Local repository only (no remote). Standard workflow:
```bash
git add -A
git commit -m "Description"
```
