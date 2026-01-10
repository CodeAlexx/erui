# CLAUDE.md - EriUI Project Guide

## Project Overview

**EriUI** is a unified AI media creation suite built with Flutter, combining:
- **Image Generation** (SwarmUI-style interface clone)
- **Video Generation** (with built-in video editor)
- **Model Training** (OneTrainer integration)
- **Workflow Management** (ComfyUI workflow browser and visual editor)

It's a desktop-first application with web mode support, featuring its own ComfyUI backend instance.

## Architecture

```
eriui/
├── flutter_app/          # Main Flutter application
├── comfyui/              # Dedicated ComfyUI backend instance
│   └── ComfyUI/          # ComfyUI installation (port 8199)
├── server_manager.py     # Service orchestration tool
├── cors_server.py        # CORS proxy (web mode only)
└── CLAUDE.md             # This file
```

## Services & Ports

| Service | Port | Description |
|---------|------|-------------|
| ComfyUI | 8199 | Image/video generation backend (eriui's own instance) |
| OneTrainer | 8100 | Model training backend (external, at /home/alex/OneTrainer) |
| CORS Server | 8899 | HTTP proxy with CORS headers (web mode only) |
| Flutter App | - | Desktop app (Linux) or web app (Chrome) |

## Server Manager

Located at `/home/alex/eriui/server_manager.py`

```bash
# Interactive menu
python server_manager.py

# Desktop mode (default) - starts ComfyUI, OneTrainer, Flutter
python server_manager.py start

# Web mode - adds CORS server, uses Chrome
python server_manager.py start --web

# Other commands
python server_manager.py stop      # Stop all services
python server_manager.py status    # Show service status
python server_manager.py restart   # Restart all
python server_manager.py logs <service>  # View logs
```

## Flutter App Structure

```
flutter_app/lib/
├── main.dart                 # App entry point
├── app.dart                  # Router configuration (GoRouter)
├── features/                 # Feature modules
│   ├── generate/             # Image generation (SwarmUI clone)
│   ├── editor/               # Video editor
│   ├── trainer/              # OneTrainer integration UI
│   ├── models/               # Model browser/manager
│   ├── gallery/              # Generated images gallery
│   ├── workflow_browser/     # Workflow management UI
│   ├── workflow_editor/      # Visual node editor
│   ├── comfyui_editor/       # External ComfyUI launcher
│   ├── settings/             # User preferences
│   ├── tools/                # Utilities (batch, grid, etc.)
│   ├── regional/             # Regional prompting
│   └── wildcards/            # Wildcard management
├── providers/                # Riverpod state management
├── services/                 # API & business logic
├── models/                   # Data models
├── widgets/                  # Shared UI components
└── theme/                    # Design system
```

## Key Services

### ComfyUI Service (`lib/services/comfyui_service.dart`)
- Connects to ComfyUI backend on port 8199
- WebSocket for real-time progress updates
- Queues prompts, manages history, fetches models

### OneTrainer Service (`lib/services/onetrainer_service.dart`)
- Connects to OneTrainer Web UI on port 8100
- Training management, dataset handling
- Real-time training progress via WebSocket

### Workflow Services
- `workflow_storage_service.dart` - Hive-based workflow persistence
- `comfyui_workflow_api.dart` - Template filling, workflow execution
- `workflow_validation_service.dart` - Workflow structure validation

### Other Services
- `comfyui_workflow_builder.dart` - Builds ComfyUI workflows from params
- `generation_queue_service.dart` - Local generation queue
- `storage_service.dart` - Hive local storage (settings, state)
- `autocomplete_service.dart` - Prompt tag autocomplete
- `presets_service.dart` - Parameter preset management

## State Management

Uses **Riverpod** for state management:

### Key Providers
- `generationProvider` - Generation parameters and state
- `sessionProvider` - ComfyUI connection state
- `modelsProvider` - Available models list
- `loraProvider` - LoRA models
- `workflowProvider` - Workflow list and selection
- `workflowExecutionProvider` - Workflow execution state
- `panelStateProvider` - UI panel expansion states

## Features Detail

### Generate Screen (SwarmUI Clone)
- Three-panel layout: Parameters | Preview | Metadata
- Collapsible parameter sections
- Workflow browser integration
- LoRA/ControlNet/VAE support
- Batch generation, grid generation

### Video Editor
- Timeline with clip thumbnails
- Media playback with seeking
- Multiple tracks support
- FFmpeg-based thumbnail extraction

### Trainer (OneTrainer)
- Dashboard with GPU stats
- Training configuration
- Dataset management
- Real-time loss charts
- Preset management

### Workflow System (SwarmUI Parity)
- Workflow browser with folder hierarchy
- Custom parameter definitions
- Template tags: `${prompt}`, `${seed}`, `${model}`, etc.
- Visual node editor
- Import/export ComfyUI JSON

## Data Storage

- **Hive** - Local key-value storage (`/home/alex/Documents/eriui_storage`)
- **Workflows** - Stored in Hive with JSON serialization
- **Settings** - User preferences in Hive
- **Generated Images** - ComfyUI output directory

## Dependencies

Key Flutter packages:
- `flutter_riverpod` - State management
- `go_router` - Navigation
- `dio` - HTTP client
- `web_socket_channel` - WebSocket connections
- `hive_flutter` - Local storage
- `media_kit` - Video playback
- `file_picker` - File selection

## Build & Run

```bash
cd /home/alex/eriui/flutter_app

# Run desktop (recommended)
flutter run -d linux

# Run web
flutter run -d chrome

# Build release
flutter build linux --release
```

## External Dependencies

### ComfyUI Backend
- Location: `/home/alex/eriui/comfyui/ComfyUI`
- Virtual env: `venv/`
- Custom nodes: ComfyUI-Manager, ComfyUI-VideoHelperSuite, ComfyUI-LTXVideo
- Model paths linked to `/home/alex/SwarmUI/Models/`

### OneTrainer
- Location: `/home/alex/OneTrainer`
- Web UI: `/home/alex/OneTrainer/web_ui/`
- Virtual env: `venv/`

## Common Tasks

### Adding a new feature
1. Create feature folder in `lib/features/<name>/`
2. Add screen widget, providers, widgets
3. Register route in `lib/app.dart`
4. Add navigation in `lib/widgets/app_shell.dart`

### Adding a new service
1. Create service in `lib/services/<name>_service.dart`
2. Add Riverpod provider
3. Initialize in `main.dart` if needed

### Modifying workflow system
- Models: `lib/models/workflow_models.dart`
- Storage: `lib/services/workflow_storage_service.dart`
- API: `lib/services/comfyui_workflow_api.dart`
- UI: `lib/features/workflow_browser/`

## Important Notes

- **SwarmUI is read-only** - Don't modify SwarmUI code, only reference it
- **eriui has its own ComfyUI** - Uses port 8199, not SwarmUI's backend
- **Desktop-first** - CORS server only needed for web mode
- **Riverpod patterns** - Follow existing StateNotifier patterns

## Git Workflow

```bash
cd /home/alex/eriui
git status
git add -A
git commit -m "Description"
```

Repository is local (not pushed to remote).
