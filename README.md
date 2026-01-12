# EriUI

**All-in-one AI image/video generation and training platform.**

EriUI is a complete replacement for multiple AI tools in a single, unified application:

## What EriUI Replaces

| Tool | EriUI Equivalent |
|------|------------------|
| SwarmUI | Generate tab, ComfyUI Workflow tab |
| OneTrainer | Trainer tab |
| ComfyUI (standalone) | Built-in ComfyUI backend |
| DaVinci/Premiere | Video Editor tab |
| VidTrainPrep | Video Train Prep (Utilities) |
| Any other trainer | Unified training interface |

## Architecture

EriUI is a self-contained application that bundles everything users need:

```
eriui/
├── flutter_app/          # Flutter frontend (cross-platform UI)
├── comfyui/ComfyUI/      # Bundled ComfyUI backend for generation
└── (OneTrainer API)      # Training backend integration
```

### Key Design Decisions

- **Bundled ComfyUI**: EriUI includes its own ComfyUI installation. This ensures users don't need external dependencies like SwarmUI. Models can be configured via `extra_model_paths.yaml`.

- **Unified Training**: Instead of requiring users to install OneTrainer separately, EriUI provides a complete training interface that connects to the OneTrainer API.

- **Single Install**: Users install EriUI once and have access to all features - generation, workflows, training, and model management.

## Features

### Generate Tab
- Text-to-image generation
- Image-to-image
- Multiple model support (SD, SDXL, Flux, etc.)

### Comfy Workflow Tab
- Visual node-based workflow editor
- Load/save workflows
- Full ComfyUI compatibility

### Trainer Tab
- Dashboard with live training stats
- Loss chart visualization
- Configuration management
- Preset system
- Sample generation during training
- Support for LoRA, LoKr, and other training methods

### Video Editor Tab
- Multi-track timeline with drag-and-drop clips
- Frame-accurate playhead with click-to-seek and drag scrubbing
- Keyboard shortcuts (J/K/L shuttle, arrow keys for frame stepping)
- Clip thumbnails extracted from video frames
- Media browser with import and organization
- Real-time video preview with media_kit
- Trim, split, and arrange clips on timeline
- FFmpeg-based export

### Video Train Prep (Utilities)
- Import video folders with automatic metadata probing
- Define multiple clip ranges per video with start/end frames
- Interactive crop region drawing on video preview
- Per-range captions for training
- Export cropped/uncropped clips and first frames
- Generate OneTrainer-compatible YAML configs
- Model presets for Wan, Hunyuan, LTX-Video, CogVideoX

## Configuration

### Model Paths
Configure model locations in `comfyui/ComfyUI/extra_model_paths.yaml`:

```yaml
models:
  base_path: /path/to/your/models
  checkpoints: Stable-Diffusion
  loras: Lora
  # ... etc
```

## Development

### Requirements
- Flutter SDK 3.0+
- Python 3.10+ (for ComfyUI backend)
- CUDA-capable GPU

### Building
```bash
cd flutter_app
flutter build linux --release
```

### Running
```bash
./flutter_app/build/linux/x64/release/bundle/flutter_app
```

## License

[TBD]
