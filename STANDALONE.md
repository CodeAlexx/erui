# EriUI Standalone Architecture

EriUI is a fully standalone application that does not depend on SwarmUI or any external inference server.

## Architecture

```
Flutter App (Desktop/Web)
    ↓
EriUI Dart Server (port 7803)
    ├─→ EriUI ComfyUI Backend (port 8199)
    └─→ OneTrainer Backend (port 8000, optional)
```

## Port Configuration

| Component | Port | Notes |
|-----------|------|-------|
| EriUI Dart Server | 7803 | Main API server |
| EriUI ComfyUI | 8199 | Standalone (NOT SwarmUI's 8188) |
| OneTrainer | 8000 | Optional training backend |

## SwarmUI Independence

EriUI is completely independent from SwarmUI:
- Uses its own ComfyUI instance on port 8199
- Has its own output directory: `/home/alex/eriui/output`
- Model previews are generated locally (placeholder SVG if not available)
- No API calls to SwarmUI

**SwarmUI and its ComfyUI backend (port 8188) are READ-ONLY references only.**

## Output Directory

Generated images are saved to: `/home/alex/eriui/output`

Can be configured via command line:
```bash
dart run bin/server.dart --output-dir=/custom/path
```

## TODO: Model Location Configuration

**Status**: Pending implementation

Currently, model paths in the trainer screen are hardcoded to `/home/alex/SwarmUI/Models/`.
This needs to be made configurable for full standalone operation.

### Planned Solution

1. Add `--models-dir` command line argument to server
2. Query model list from ComfyUI API instead of hardcoding paths
3. Add model directory configuration to Flutter app settings
4. Support multiple model directories (ComfyUI models + external)

### Workaround (Current)

For training, models are referenced from ComfyUI's model directories:
- `/home/alex/eriui/comfyui/ComfyUI/models/checkpoints/`
- `/home/alex/eriui/comfyui/ComfyUI/models/loras/`
- etc.

ComfyUI can be configured to use symlinks to external model directories.

## Launch Commands

### Start EriUI Server
```bash
cd /home/alex/eriui
dart run bin/server.dart --port=7803 --comfy-url=http://localhost:8199
```

### Start EriUI ComfyUI
```bash
cd /home/alex/eriui/comfyui/ComfyUI
source venv/bin/activate
python main.py --port 8199
```

### Full Launch Script
```bash
./launch_eriui.sh
```

## Configuration Files

- Server settings: Command line arguments
- Flutter app: `lib/services/api_service.dart` (baseUrl: localhost:7803)
- ComfyUI: Standard ComfyUI configuration

## Directory Structure

```
/home/alex/eriui/
├── bin/
│   └── server.dart          # Main Dart server
├── lib/
│   └── backends/
│       └── comfyui/          # ComfyUI backend library
├── flutter_app/              # Flutter desktop/web app
├── comfyui/
│   └── ComfyUI/              # Standalone ComfyUI instance
├── output/                   # Generated images (auto-created)
└── STANDALONE.md             # This file
```
