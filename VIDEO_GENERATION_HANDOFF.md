# EriUI Video Generation Implementation - Handoff Document

**Date**: January 7, 2026
**Status**: Implementation complete, testing required

---

## Overview

EriUI is a Flutter desktop application that provides a unified interface for AI image/video generation (via ComfyUI) and model training (via OneTrainer). This document covers the video generation feature implementation using Wan2.2 models.

---

## Architecture

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│   Flutter App       │────▶│   EriUI Server      │────▶│   ComfyUI Backend   │
│   (Desktop Linux)   │     │   (Dart, port 7802) │     │   (port 8189)       │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
        │                            │
        │                            ▼
        │                   ┌─────────────────────┐
        └──────────────────▶│   SwarmUI Models    │
                            │   (symlinked)       │
                            └─────────────────────┘
```

### Key Paths
- **EriUI Project**: `/home/alex/eriui/`
- **Flutter App**: `/home/alex/eriui/flutter_app/`
- **Dart Server**: `/home/alex/eriui/bin/server.dart`
- **ComfyUI**: `/home/alex/eriui/comfyui/ComfyUI/` (port 8189)
- **SwarmUI Models**: `/home/alex/SwarmUI/Models/`

### Model Symlinks (Created)
ComfyUI models folder (`/home/alex/eriui/comfyui/ComfyUI/models/`) has symlinks to SwarmUI:
- `diffusion_models` → `/home/alex/SwarmUI/Models/diffusion_models`
- `unet` → `/home/alex/SwarmUI/Models/diffusion_models`
- `clip` → `/home/alex/SwarmUI/Models/clip`
- `text_encoders` → `/home/alex/SwarmUI/Models/clip`
- `clip_vision` → `/home/alex/SwarmUI/Models/clip_vision`
- `embeddings` → `/home/alex/SwarmUI/Models/Embeddings`

---

## Files Modified

### 1. Server Backend (`bin/server.dart`)

**Video Workflow Builder** (lines ~650-850):
```dart
Map<String, dynamic> _buildVideoWorkflow({
  required String prompt,
  String negativePrompt = '',
  required String model,
  int width = 848,
  int height = 480,
  int frames = 81,
  int steps = 20,
  double cfg = 6.0,
  int seed = -1,
  String sampler = 'uni_pc',
  String scheduler = 'normal',
  int fps = 24,
  List<Map<String, dynamic>>? loras,
  String? clipModel,
  String? vaeModel,
  String videoFormat = 'webp',
  bool isI2V = false,
  String? initImage,
  String? explicitHighNoise,  // For Wan2.2 dual-model
  String? explicitLowNoise,   // For Wan2.2 dual-model
})
```

**Key Features**:
- Detects Wan2.2 dual-model architecture (high_noise + low_noise)
- Auto-derives low_noise model from high_noise if not explicitly set
- Supports t2v (text-to-video) and i2v (image-to-video) modes
- Builds ComfyUI workflow with nodes: UNETLoader, CLIPLoader, VAELoader, KSampler, VAEDecode, SaveAnimatedWEBP

**API Endpoints Added**:
- `POST /api/ListVideoModels` - Lists video models with t2v/i2v type detection
- `POST /api/ListDiffusionModels` - Lists all diffusion models

**Video Mode Detection** (in `_generate()` method):
```dart
if (videoMode == true) {
  workflow = _buildVideoWorkflow(
    prompt: prompt,
    model: model ?? '',
    width: width,
    height: height,
    frames: frames,
    steps: steps,
    cfg: cfg,
    seed: seed,
    fps: fps,
    videoFormat: videoFormat,
    explicitHighNoise: highNoiseModel,
    explicitLowNoise: lowNoiseModel,
    // ... other params
  );
}
```

### 2. Generation Provider (`flutter_app/lib/providers/generation_provider.dart`)

**GenerationParams Class** - Added video parameters:
```dart
class GenerationParams {
  // ... existing params ...

  // Video parameters
  final bool videoMode;
  final String? videoModel;
  final String? highNoiseModel;  // For Wan2.2 dual-model
  final String? lowNoiseModel;   // For Wan2.2 dual-model
  final int frames;
  final int fps;
  final String videoFormat;

  const GenerationParams({
    // ... existing ...
    this.videoMode = false,
    this.videoModel,
    this.highNoiseModel,
    this.lowNoiseModel,
    this.frames = 81,
    this.fps = 24,
    this.videoFormat = 'webp',
  });
}
```

**GenerationParamsNotifier** - Added setters:
- `setVideoMode(bool)`
- `setVideoModel(String?)`
- `setHighNoiseModel(String?)`
- `setLowNoiseModel(String?)`
- `setFrames(int)`
- `setFps(int)`
- `setVideoFormat(String)`

**Generate Method** - Sends video params to server:
```dart
if (params.videoMode) 'video_mode': true,
if (params.videoMode) 'frames': params.frames,
if (params.videoMode) 'fps': params.fps,
if (params.videoMode) 'video_format': params.videoFormat,
if (params.videoMode && params.highNoiseModel != null) 'high_noise_model': params.highNoiseModel,
if (params.videoMode && params.lowNoiseModel != null) 'low_noise_model': params.lowNoiseModel,
```

### 3. Models Provider (`flutter_app/lib/providers/models_provider.dart`)

**Added**:
- `diffusionModels` field to `ModelsState`
- `_loadDiffusionModels()` method calling `/api/ListDiffusionModels`

### 4. Parameters Panel UI (`flutter_app/lib/features/generate/widgets/eri_parameters_panel.dart`)

**Video Section** (`_ImageToVideoContent` widget):
- Renamed from "Image To Video" to "Video" (since t2v doesn't need input image)
- Shows mode indicator: "Wan T2V (dual model)" or "Text→Video"
- **Video Model dropdown** - Selects from diffusion models with "wan" or "video" in name
- **High Noise Model dropdown** - Only shown when Wan model selected
- **Low Noise Model dropdown** - Only shown when Wan model selected
- Frames slider (17-257, default 81)
- FPS slider (8-60, default 24)
- Video Format dropdown (webp, mp4, gif)

**Auto-selection Logic**:
- When High Noise Model changes, auto-derives Low Noise Model by replacing "high" with "low"
- Wan detection: model name contains "wan" and ("t2v" or "i2v")

### 5. API Service (`flutter_app/lib/services/api_service.dart`)

**Fixed port**: Changed from 7803 to 7802
```dart
String _baseUrl = 'http://localhost:7802';
String _wsUrl = 'ws://localhost:7802/ws';
```

---

## Wan2.2 Model Architecture

Wan2.2 uses a **dual-model** architecture for video generation:

1. **High Noise Model** - Handles initial denoising (high noise levels)
   - Example: `wan2.2_t2v_high_noise_14B_fp16.safetensors`

2. **Low Noise Model** - Handles final denoising (low noise levels)
   - Example: `wan2.2_t2v_low_noise_14B_fp16.safetensors`

**Available Wan Models** (in `/home/alex/SwarmUI/Models/diffusion_models/`):
- `wan2.2_t2v_high_noise_14B_fp16.safetensors` (T2V)
- `wan2.2_t2v_low_noise_14B_fp16.safetensors` (T2V)
- `wan2.2_i2v_high_noise_14B_fp16.safetensors` (I2V)
- `wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors` (I2V)
- `wan2.2_i2v_low_noise_14B_fp16.safetensors` (I2V)
- `wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors` (I2V)
- `wan2.1_vace_14B_fp16.safetensors` (VACE variant)

---

## How to Run

### 1. Start ComfyUI (if not running)
```bash
cd /home/alex/eriui/comfyui/ComfyUI
python main.py --listen 0.0.0.0 --port 8189
```

### 2. Start EriUI Server
```bash
cd /home/alex/eriui
/home/alex/flutter/bin/dart bin/server.dart
# Server runs on http://0.0.0.0:7802
```

### 3. Start Flutter App
```bash
cd /home/alex/eriui/flutter_app
flutter run -d linux
```

### 4. Test Video Generation
1. Go to Generate tab
2. Expand "Video" section (click toggle to enable)
3. Select Video Model (e.g., `wan2.2_t2v_high_noise_14B_fp16`)
4. Wan dual-model dropdowns should appear - verify High Noise and Low Noise models
5. Enter a prompt
6. Click Generate

---

## What's Complete

1. **Server-side video workflow builder** - Full Wan2.2 dual-model support
2. **Video mode detection** in generation endpoint
3. **Flutter video UI** with:
   - Video model selection
   - Wan dual-model (high/low noise) dropdowns
   - Frames, FPS, format controls
4. **Video model listing API** - Separates t2v/i2v models
5. **Diffusion models provider** - Loads all diffusion models for UI

---

## What Needs Testing

1. **End-to-end video generation** - Click Generate with Wan t2v models selected
2. **Workflow validation** - Verify ComfyUI accepts the generated workflow
3. **Dual model loading** - Confirm both high_noise and low_noise models load
4. **Progress polling** - Video generation takes longer, verify progress updates
5. **Output saving** - Check video saves to output directory

---

## Potential Issues

1. **Memory**: Wan2.2 14B fp16 models are ~14GB each. Need ~32GB+ VRAM for dual-model
2. **Workflow nodes**: May need custom ComfyUI nodes for Wan2.2 (check if installed)
3. **CLIP model**: Wan uses special CLIP loader type "wan" - verify it's available
4. **VAE**: Wan needs `wan2.2_vae.safetensors` or compatible VAE

---

## Debug Commands

```bash
# Test server API
curl -X POST http://localhost:7802/api/ListDiffusionModels -H "Content-Type: application/json" -d '{}'

# Test ComfyUI directly
curl -s http://localhost:8189/object_info/UNETLoader

# Check models
ls -la /home/alex/SwarmUI/Models/diffusion_models/ | grep wan

# Server log
cat /tmp/eriui_server.log

# Flutter app output (in flutter run terminal)
# Press 'r' for hot reload after code changes
```

---

## Next Steps

1. **Test video generation** with real Wan2.2 models
2. **Add video preview** - Show preview frames during generation
3. **Add I2V support** - Image input for image-to-video mode
4. **Optimize memory** - Add model offloading/quantization options
5. **Add LoRA support** for video - Wan video LoRAs exist in the loras folder
