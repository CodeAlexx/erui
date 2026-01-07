# EriUI Implementation Status

## PROJECT OVERVIEW

**EriUI** = Unified **Training + Inference** Flutter app combining:
- **OneTrainer** training capabilities (LoRA, finetune, embeddings)
- **ComfyUI** inference backend (image/video generation)
- All in one powerful, beautiful Flutter desktop app

### Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                     EriUI Flutter App                        │
│  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌──────────────┐  │
│  │ Trainer │  │ Generate │  │ VidPrep │  │ Video Editor │  │
│  └────┬────┘  └────┬─────┘  └────┬────┘  └──────┬───────┘  │
│       │            │             │              │           │
│       ▼            ▼             ▼              ▼           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              EriUI Dart Server (port 7803)          │   │
│  │         Proxies to OneTrainer + ComfyUI             │   │
│  └──────────────┬─────────────────────┬────────────────┘   │
└─────────────────┼─────────────────────┼────────────────────┘
                  │                     │
         ┌────────▼────────┐   ┌────────▼────────┐
         │   OneTrainer    │   │     ComfyUI     │
         │   (port 8000)   │   │   (port 8199)   │
         │   Training API  │   │  Inference API  │
         └─────────────────┘   └─────────────────┘
```

### Key Directories
| Component | Location |
|-----------|----------|
| **EriUI Flutter App** | `/home/alex/eriui/flutter_app/` |
| **EriUI Dart Server** | `/home/alex/eriui/bin/server.dart` |
| **OneTrainer (refactored)** | `/home/alex/OneTrainer/` |
| **OneTrainer WebUI (React)** | `/home/alex/OneTrainer/inference_app/frontend/src/` |
| **ComfyUI (standalone)** | `/home/alex/eriui/comfyui/` |
| **Launch Script** | `/home/alex/eriui/launch_eriui.sh` |

---

## CURRENT STATE (Jan 7, 2026)

### What's Working
- ✅ ComfyUI running standalone on port 8199
- ✅ EriUI Dart server running on port 7803
- ✅ Flutter app running on Linux desktop
- ✅ Theme system with User/Appearance color selection
- ✅ Generate screen (existing SwarmUI features ported)

### What's Been Built This Session

#### 1. TrainerScreen (`/home/alex/eriui/flutter_app/lib/features/trainer/trainer_screen.dart`)
Ported from React `/home/alex/OneTrainer/inference_app/frontend/src/App.tsx`

**Layout:**
- **Top tabs**: txt2img | img2img | Inpaint | Vid Prep | Video Editor | Models | Settings
- **Left sidebar**: Collapsible parameter sections (Core Parameters, Variation Seed, Resolution, Sampling, Init Image, Refine/Upscale, ControlNet, VIDEO SETTINGS, FreeU, LoRAs)
- **Center**: Image preview with welcome message
- **Bottom**: Prompt input (positive + negative) + Gallery thumbnails + Model selector

**Features:**
- Generation modes (txt2img, img2img, inpaint)
- All parameter sliders and dropdowns
- Seed with random/recycle buttons
- Init image upload with mask editor trigger
- Video model detection and settings
- LoRA management (advanced mode)
- Progress bar during generation

#### 2. MaskEditor (`/home/alex/eriui/flutter_app/lib/features/trainer/widgets/mask_editor.dart`)
- Brush tool with adjustable size
- Eraser tool
- Lasso/polygon selection
- SAM2 click-to-segment (include/exclude points)
- Clear/invert mask actions

#### 3. VideoEditor (`/home/alex/eriui/flutter_app/lib/features/trainer/widgets/video_editor.dart`)
- Multi-track timeline (video, audio tracks)
- Transport controls (play, pause, scrub, skip)
- Zoom controls for timeline
- Snap toggle
- Media browser panel
- Inspector panel for clip properties (transform, audio, effects)
- Effects system (brightness, contrast, blur, etc.)
- Export button

#### 4. VidPrep (`/home/alex/eriui/flutter_app/lib/features/trainer/widgets/vid_prep.dart`)
- Model presets: Wan 2.1/2.2, HunyuanVideo, FramePack
- Resolution/FPS/frame count settings per model
- Video import and preview
- Clip range management with captions
- Crop region support
- Export settings panel

#### 5. App Navigation
- **"Simple" tab renamed to "Trainer"** in top nav (`app_shell.dart`)
- **`/trainer` route added** to `app.dart`
- Trainer screen accessible from main navigation

---

## THEME REQUIREMENTS (CRITICAL)

**ALL screens MUST use EriUI theme colors from `Theme.of(context)`**

```dart
// Get theme colors in any widget
final colorScheme = Theme.of(context).colorScheme;
final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

// Use these instead of hardcoded colors:
colorScheme.primary          // Primary accent color (user-selected)
colorScheme.surface          // Surface/card backgrounds
colorScheme.onSurface        // Text on surfaces
colorScheme.outlineVariant   // Border colors
scaffoldBg                   // Main background
```

**Theme is configured in:** User → Appearance tab
**Theme file:** `/home/alex/eriui/flutter_app/lib/theme/app_theme.dart`
**Available schemes:** Amber, Gold, Mango, Deep Orange, Brand Blue, Indigo, etc.

### Screens That Need Theme Updates
- [x] `VideoEditor` - UPDATED to use theme colors
- [x] `VidPrep` - UPDATED to use theme colors
- [x] `MaskEditor` - UPDATED to use theme colors
- [x] `TrainerScreen` - UPDATED to use theme colors

---

## WHAT NEEDS TO BE DONE NEXT

### Priority 1: Theme Compliance ✅ DONE
All widgets updated to use `Theme.of(context).colorScheme`

### Priority 2: API Integration (CURRENT FOCUS)
Connect Flutter screens to actual backends:

**TrainerScreen → OneTrainer API:**
```
POST /api/training/start
POST /api/training/stop
GET  /api/training/status
GET  /api/training/progress
POST /api/training/sample
GET  /api/config/presets
```

**TrainerScreen → ComfyUI API (via EriUI server):**
```
POST /api/generate
POST /api/generate/cancel
GET  /api/status
GET  /api/gallery
```

### Priority 3: Missing Features
- [ ] Image file picker for init image
- [ ] Drag-and-drop image upload
- [ ] Gallery image selection → use as init
- [ ] Real-time WebSocket progress updates
- [ ] Model loading status
- [ ] Actual generation API calls

### Priority 4: Training UI
The current TrainerScreen is actually an **Inference** UI (ported from OneTrainer's inference_app).
May need a separate **Training Configuration** screen for:
- Dataset management
- Training presets
- LoRA/finetune configuration
- TensorBoard integration
- Training progress monitoring

---

## FILE REFERENCE

### Flutter App Structure
```
/home/alex/eriui/flutter_app/lib/
├── app.dart                 # Routes: /generate, /trainer, /models, /gallery, /settings, /workflow
├── main.dart                # Entry point
├── features/
│   ├── trainer/
│   │   ├── trainer_screen.dart      # Main inference UI (UPDATED)
│   │   └── widgets/
│   │       ├── mask_editor.dart     # Inpainting mask editor (NEW)
│   │       ├── video_editor.dart    # Timeline video editor (NEW)
│   │       └── vid_prep.dart        # Video preparation tool (NEW)
│   ├── generate/
│   │   └── generate_screen.dart     # Original SwarmUI generate screen
│   ├── models/
│   ├── gallery/
│   ├── settings/
│   └── workflow/
├── widgets/
│   └── app_shell.dart       # Top navigation with Trainer tab (UPDATED)
├── providers/               # Riverpod state management
├── services/                # API services
└── theme/
    └── app_theme.dart       # FlexColorScheme theme definitions
```

### React Source Reference
Original React components that were ported:
- `/home/alex/OneTrainer/inference_app/frontend/src/App.tsx` (34KB) → trainer_screen.dart
- `/home/alex/OneTrainer/inference_app/frontend/src/components/MaskEditor.tsx` (18KB) → mask_editor.dart
- `/home/alex/OneTrainer/inference_app/frontend/src/components/VideoEditor.tsx` (62KB) → video_editor.dart
- `/home/alex/OneTrainer/inference_app/frontend/src/components/VidPrep.tsx` (48KB) → vid_prep.dart

---

## LAUNCH COMMANDS

```bash
# Launch everything (ComfyUI + Server + Flutter)
cd /home/alex/eriui && ./launch_eriui.sh

# Or manually:
# 1. ComfyUI
cd /home/alex/eriui/comfyui/ComfyUI && source venv/bin/activate && python main.py --port 8199 --listen 0.0.0.0

# 2. Dart Server
cd /home/alex/eriui && /home/alex/flutter/bin/dart run bin/server.dart --port=7803

# 3. Flutter App
cd /home/alex/eriui/flutter_app && /home/alex/flutter/bin/flutter run -d linux
```

---

## KNOWN ISSUES

1. **Crash cause**: SwarmUI/ComfyUI crashed due to missing `extra_model_paths.yaml`
2. **Port conflicts**: Kill existing processes before relaunch
   ```bash
   pkill -f "ComfyUI" && pkill -f "dart"
   ```

---

## MODEL SUPPORT

### Image Models
- FLUX Dev, FLUX Schnell
- SDXL
- SD 3.5
- Z-Image, Z-Image Turbo
- Qwen-Image, Qwen-Edit
- Lumina 2
- OmniGen 2

### Video Models
- Wan 2.2 T2V (High/Low noise)
- Wan 2.2 I2V (High/Low noise)
- Wan 2.1 VACE
- Kandinsky 5 T2V (Lite/Pro)
- HunyuanVideo (planned)

---

## RESUME INSTRUCTIONS

If starting fresh after a crash:

1. **Read this file first** to understand the project
2. **Check what's running**: `ss -tlnp | grep -E "8199|7803"`
3. **Kill stale processes**: `pkill -f "ComfyUI" && pkill -f "dart"`
4. **Launch**: `cd /home/alex/eriui && ./launch_eriui.sh`
5. **Current task**: API Integration - connect TrainerScreen to ComfyUI/OneTrainer APIs
6. **Theme colors**: Already done - all widgets use `Theme.of(context).colorScheme`

### Last Session Summary (Jan 7, 2026)
- ✅ Ported React App.tsx → TrainerScreen (inference UI with tabs, sidebar, prompt, gallery)
- ✅ Ported MaskEditor, VideoEditor, VidPrep from React to Flutter
- ✅ Updated all widgets to use EriUI theme system
- ✅ Documentation fully updated with architecture, file refs, and resume instructions

---

## ONETRAINER TRAINING UI (Jan 7, 2026 - LATEST)

### OneTrainer Shell
**File:** `/home/alex/eriui/flutter_app/lib/features/trainer/onetrainer_shell.dart`

**Navigation Sidebar (16 items):**
- Dashboard
- Training Queue → `TrainingQueueScreen`
- Datasets → `DatasetsScreen`
- Configuration → `ConfigurationScreen`
- Concepts → `ConceptsScreen`
- Training (placeholder)
- Sampling (placeholder)
- Backup (placeholder)
- Inference → `TrainerScreen` (existing generate UI)
- TensorBoard (placeholder)
- Tools (placeholder)
- Embeddings (placeholder)
- Cloud (placeholder)
- Database (placeholder)
- Models (placeholder)
- Settings (placeholder)

**Top Bar:**
- Preset selector dropdown (#z-imageGiger16GB)
- Grid toggle button
- Model badges (Z-Image, LoRA)
- Load File, Export, Save Preset buttons

---

### Training Screens Built

#### 1. TrainingQueueScreen
**File:** `/home/alex/eriui/flutter_app/lib/features/trainer/screens/training_queue_screen.dart`
- Current training job with progress bar
- Pending queue list with reorder/remove
- History section with success/fail status

#### 2. DatasetsScreen
**File:** `/home/alex/eriui/flutter_app/lib/features/trainer/screens/datasets_screen.dart`
- Dataset list with search/sort
- Image grid preview when dataset selected
- Dataset actions (add, remove, refresh)

#### 3. ConfigurationScreen
**File:** `/home/alex/eriui/flutter_app/lib/features/trainer/screens/configuration_screen.dart`
- **4 Tabs:** General | Model | Data | Backup
- **General Tab:** Config name, output path, training method (LoRA/Finetune/Embedding/Dreambooth), seed, precision (fp16/bf16/fp32)
- **Model Tab:** Base model selector, VAE path, LoRA rank/alpha, LoRA type dropdown, use gradient checkpointing
- **Data Tab:** Train batch size, resolution, image augmentation (random flip/crop), cache latents, aspect ratio bucketing
- **Backup Tab:** Save frequency, max checkpoints, save optimizer state

#### 4. ConceptsScreen ✅ COMPLETE
**File:** `/home/alex/eriui/flutter_app/lib/features/trainer/screens/concepts_screen.dart`

**Concept Grid:**
- Concept cards with: delete button (red X), enable toggle (green/gray), thumbnail, folder icon, name, tag icon
- Filter bar: search, type dropdown (ALL/Standard/Prior), show disabled checkbox, clear button
- Dynamic column count (5 with panel, 6 without)

**Details Panel (3 Tabs):**

**General Tab:**
- Name, Path (with folder browse button), Type dropdown
- Balancing + Loss Weight (side by side)
- Balancing Strategy dropdown (Repeats/Shuffle/Round Robin)
- Image Variations + Text Variations (side by side)
- Include Subdirectories checkbox
- Seed field
- Delete Concept button

**Image Tab:**
- AUGMENTATION: Crop Jitter, Random Flip + Fixed Flip, Random Rotate + Max Angle
- COLOR: Brightness/Contrast/Saturation/Hue (each with Strength field)
- RESOLUTION: Override Resolution checkbox + resolution input when enabled
- MASK: Random Circular Mask Shrink, Random Mask Rotate Crop

**Text Tab:**
- Prompt Source dropdown (sample/txt/filename/concept)
- Prompt Path (optional)
- TAG SHUFFLING: Enable checkbox, Delimiter + Keep Tags fields
- TAG DROPOUT: Enable checkbox, Mode dropdown (FULL/PARTIAL) + Probability field

#### 5. TrainingScreen ✅ FULLY BUILT (MOST IMPORTANT)
**File:** `/home/alex/eriui/flutter_app/lib/features/trainer/screens/training_screen.dart`

**7 Tabs (ALL COMPLETE):**
1. **Overview** - Training status (Status, Epoch, Step, Loss, LR, ETA), Loaded preset
2. **Samples** - ✅ Tree view with folders/prompts (left), image grid gallery (right)
   - Tree nodes: expand/collapse, folder icons (yellow), image icons (blue), count badges
   - Gallery: thumbnails grid, lightbox support
3. **Config File** - ✅ JSON config viewer with syntax highlighting (green keys, cyan numbers, orange bools)
   - Full configuration JSON display matching screenshot
4. **Parameters** - 3-column layout with ALL training parameters:
   - **Column 1:** OPTIMIZER & LR (Optimizer, Scheduler, LR, Warmup, Epochs, Batch Size, etc.), TEXT ENCODER, EMBEDDINGS
   - **Column 2:** EMA & CHECKPOINTING (EMA, Decay, Gradient Checkpointing, Data Types, Resolution, Offloading), TRANSFORMER/UNET, NOISE
   - **Column 3:** MASKED TRAINING, LOSS (MSE, MAE, Huber, etc.), DEVICE & MULTI-GPU, BACKUP & SAVE
5. **LoRA / Adapters** - ✅ COMPLETE with expandable adapter cards
   - "+ Add Adapter" button
   - Expandable cards with: drag handle, checkbox, name, type badge, r/alpha
   - PEFT Types: LoRA, LoHa, LoKr, LoCon, IA3, DyLoRA, GLoRA, OFT, BOFT
   - Layer Presets: Full, Attention Only, QKV+Out, MLP/FFN, Diffusers, Transformer Blocks, Custom Pattern
   - Custom Pattern (regex) field
   - Enable DoRA checkbox
6. **Diffusion 4K** - ✅ COMPLETE matching screenshot
   - Wavelet Loss toggle with arXiv reference
   - 4K Resolution Presets: 1024, 2048, 4096 (4K) buttons
7. **Buckets** - ✅ COMPLETE with full 2-column layout
   - Left: Aspect Ratio Bucketing toggle, Presets (dropdown + ratio tags), Use Custom Aspects, Bucket Parameters (Quantization, Aspect Tolerance, Min Bucket Size, Merge Threshold)
   - Right: Bucket Balancing (Mode, Repeat Small Buckets, Max Per Batch), Logging & Debug (Log Dropped), Config Summary (cyan code block)

**Parameters from React code:**
- Optimizers: ADAMW, LION, PRODIGY, ADAFACTOR, etc.
- Schedulers: CONSTANT, LINEAR, COSINE, REX
- Data types: FLOAT_32, FLOAT_16, BFLOAT_16, TFLOAT_32
- Timestep distributions: UNIFORM, SIGMOID, LOGIT_NORMAL, BETA, FLUX_SHIFT
- Loss functions: MSE, MAE, Log-Cosh, Huber, VB Loss
- Time units: NEVER, EPOCH, STEP, SECOND, MINUTE

---

### React Source Reference (Training UI)
- `/home/alex/OneTrainer/web_ui/frontend/src/components/views/TrainingView.tsx` → training_screen.dart (27K tokens, HUGE)
- `/home/alex/OneTrainer/web_ui/frontend/src/components/views/ConceptsView.tsx` → concepts_screen.dart
- `/home/alex/OneTrainer/web_ui/frontend/src/components/views/DatasetsView.tsx` → datasets_screen.dart
- `/home/alex/OneTrainer/web_ui/frontend/src/components/layout/Sidebar.tsx` → onetrainer_shell.dart

---

#### 6. SamplingScreen ✅ COMPLETE
**File:** `/home/alex/eriui/flutter_app/lib/features/trainer/screens/sampling_screen.dart`

- Header: "sample now", "manual sample", "+ Add Sample", "Import Prompts" buttons
- Settings bar: Sample After, EPOCH/STEP dropdown, Skip First, Format (JPG/PNG/WEBP), Non-EMA Sampling toggle, Samples to TensorBoard toggle
- Sample list with: delete (red X), copy, enable toggle, resolution, seed, truncated prompt, menu
- Details panel: Prompt (textarea), Negative Prompt, Width/Height, Resolution Presets (512-2048, aspect ratios), Seed + Random, Diffusion Steps, CFG Scale, Noise Scheduler dropdown

#### 7. BackupScreen ✅ COMPLETE
**File:** `/home/alex/eriui/flutter_app/lib/features/trainer/screens/backup_screen.dart`

- **BACKUP SETTINGS:** "backup now" button, Backup After (value + MINUTE/EPOCH/STEP), Rolling Backup toggle, Rolling Backup Count, Backup Before Save toggle
- **SAVE SETTINGS:** "save now" button, Save Every (value + NEVER/EPOCH/STEP), Skip First, Save Filename Prefix

#### 8. TensorBoardScreen ✅ COMPLETE
**File:** `/home/alex/eriui/flutter_app/lib/features/trainer/screens/tensorboard_screen.dart`

- Server status with "Start/Stop TensorBoard" button (green/red)
- Settings: Port (6006), Log Directory dropdown
- Training Logs list with: chart icon, name, path, age (Xd ago), event count
- About TensorBoard description section

#### 9. ToolsScreen ✅ COMPLETE (2 of 5 tabs)
**File:** `/home/alex/eriui/flutter_app/lib/features/trainer/screens/tools_screen.dart`

**5 Tabs:** Captioner | Model Conversion | Mask Generation | Dataset Tools | Image Tools

**Captioner tab:**
- Model Information (LOADED/UNLOADED badge), Model ID dropdown + Load button
- Folder Path, Custom Prompt fields
- Skip already captioned, Summary Mode, One-Sentence Mode checkboxes
- Final Prompt Preview
- MAX TOKENS slider (32-512), IMAGE RESOLUTION dropdown
- Reset to Default Prompt, Start Processing, Abort buttons
- Status section

**Mask Generation tab:**
- Image Directory field
- Mask Model dropdown (SAM, U2-Net, BiRefNet, RMBG-1.4), Threshold field
- Invert Mask checkbox
- Generate Masks, Edit Masks buttons

---

## WHAT NEEDS DONE NEXT

### Immediate
- [ ] Hot reload Flutter app to test all new screens
- [ ] Build remaining placeholder screens:
  - Embeddings, Cloud, Database, Models, Settings screens
  - Model Conversion, Dataset Tools, Image Tools tabs in ToolsScreen

### API Integration
- [ ] Connect training screens to OneTrainer backend (port 8000)
- [ ] Real-time WebSocket for training progress
- [ ] Config save/load to presets
- [ ] Database mode for concepts

### Navigation
- [ ] "Inference" nav item should navigate to main Generate tab, not embedded TrainerScreen
- [ ] Consider merging Trainer tab into OneTrainer shell structure
