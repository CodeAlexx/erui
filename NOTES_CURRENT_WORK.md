# Current Work Notes - LoRA Filtering by Base Model

## What We Did
1. **Created `lora_metadata_server.py`** (port 7805) - Python server that reads safetensors metadata to detect base model type (flux, sdxl, sd15, sd3, wan, ltx, hunyuan, etc.)

2. **Updated `lora_provider.dart`** - Now fetches from metadata server instead of just LoRA names from ComfyUI. Added `loraBaseModelFilterProvider` and `getBaseModelType()` function.

3. **Updated LoRAs tab UI** (`eri_bottom_panel.dart`) - Added dropdown filter and "auto-match" button (magic wand icon) to filter LoRAs by selected model type.

4. **Added LoRA support to ALL workflow builders** - Flux, SD3.5, video models (Wan, Hunyuan, Mochi, LTX, SVD)

5. **Fixed Flux workflow** - Changed from EmptyFlux2LatentImage (128ch) to EmptySD3LatentImage (16ch), CFG=1.0, standard KSampler

## Current Bug
- Metadata server correctly detects 10+ Flux LoRAs (verified via curl)
- But UI shows NO LoRAs when filtering by "flux"
- Debug prints added to trace the issue - need to test after restart

## Files Modified
- `lora_metadata_server.py` (NEW)
- `server_manager.py` - added lora-metadata service
- `flutter_app/lib/providers/lora_provider.dart`
- `flutter_app/lib/features/generate/widgets/eri_bottom_panel.dart`
- `flutter_app/lib/providers/generation_provider.dart` - pass loras to buildFlux/buildSD35
- `flutter_app/lib/services/comfyui_workflow_builder.dart` - LoRA support for all builders

## To Debug
1. Restart Flutter
2. Go to LoRAs tab
3. Select "FLUX" from dropdown or click auto-match with Flux model selected
4. Check console for debug output:
   - `LoRA metadata loaded: X total, by type: {flux: N, ...}`
   - `LoRA filter: baseModel=flux, before=X, after=Y`

## Committed
- `ad047af` - "Add LoRA support to all workflows + base model filtering (untested)"

---

# ComfyUI-Griptape Analysis

**Repo**: https://github.com/griptape-ai/ComfyUI-Griptape

## What It Is
ComfyUI custom nodes that integrate LLMs (Claude, GPT, Gemini, Ollama, etc.) into ComfyUI workflows via the Griptape Python framework.

## Key Features
- **LLM Integration**: OpenAI, Claude, Gemini, Ollama, LM Studio, Azure, AWS Bedrock
- **AI Agents**: Create agents with tools (calculator, web scraper, file manager, vector stores)
- **Image Analysis**: Use LLMs to describe/analyze images in workflows
- **Audio**: Transcription (speech-to-text), TTS (text-to-speech)
- **Text Tasks**: Summarization, prompt enhancement, etc.

## Usefulness for EriUI: **MODERATE - Not Priority**

### Potential Benefits
1. **Auto-Captioning Enhancement**: Could use Claude/GPT to improve captions (already have Qwen)
2. **Prompt Enhancement**: LLM-powered prompt improvement before generation
3. **Smart Workflow Selection**: Agent could pick best workflow based on user description
4. **Image Analysis**: Describe generated images for metadata

### Why NOT Priority
1. **Already have Qwen** for captioning - works offline, no API costs
2. **Adds complexity** - another dependency, API keys, costs
3. **EriUI focus is generation/training** - not conversational AI
4. **Griptape is another abstraction layer** - could just call LLM APIs directly if needed

### Verdict
**SKIP FOR NOW** - Nice to have but not essential. If you want LLM features later, could integrate Claude API directly without the Griptape overhead. Focus on core generation/training features first.

---

# Reference Workflows Analysis

## 1. SD3 Family with LoRA Loader (`sd3 family with lora loader.json`)

**Key Nodes:**
- `CheckpointLoaderSimple` → sd3.5_large.safetensors
- `TripleCLIPLoader` → clip_g, clip_l, t5xxl_fp16
- `VAELoader` → Sd3_5ae.safetensors
- `ModelSamplingSD3` (shift=3) - IMPORTANT: Apply BEFORE LoRA
- `SkipLayerGuidanceSD3` - Optional quality improvement
- `Lora Loader Stack (rgthree)` - Apply AFTER ModelSamplingSD3
- `EmptySD3LatentImage`
- `KSampler` - CFG=5.5, 44 steps, dpmpp_2m, sgm_uniform

**Key Insight:** For SD3.5, the model sampling node should come BEFORE LoRA loading in the chain.

---

## 2. Qwen Image Edit Plus (`image_qwen_image_editplus.json`)

**New model for image editing!**

**Key Nodes:**
- `UNETLoader` → qwen_image_edit_fp8_e4m3fn.safetensors (diffusion_models/)
- `CLIPLoader` → qwen_2.5_vl_7b_fp8_scaled.safetensors (text_encoders/, type: **qwen_image**)
- `VAELoader` → qwen_image_vae.safetensors
- `LoraLoaderModelOnly` → Qwen-Image-Edit-Lightning-8steps-V1.0.safetensors (speed LoRA)
- `ModelSamplingAuraFlow` (shift=3)
- `CFGNorm` (strength=1)
- `TextEncodeQwenImageEditPlus` - Special encoder takes clip + vae + up to 3 images
- `KSampler` - CFG=1, 8 steps, euler, simple

**Use Case:** Multi-image editing - can composite/edit multiple images based on prompt.

---

## 3. Chroma1-HD (`ComfyUI_Chroma1-HD_T2I-workflow.json`)

**NEW MODEL - Flux alternative with negative prompts!**

**Key Nodes:**
- `UNETLoader` → Chroma1-HD-fp8_scaled_rev2.safetensors (diffusion_models/)
- `CLIPLoader` → t5xxl_flan... (type: **chroma**)
- `VAELoader` → ae.safetensors (same as Flux)
- `ModelSamplingAuraFlow` (shift=1) - Flow Shift
- `T5TokenizerOptions` - Optional padding settings
- `CFGGuider` - CFG=3.8
- `SamplerCustomAdvanced` with `BetaSamplingScheduler` (26 steps, alpha=0.45, beta=0.45)
- `EmptySD3LatentImage`

**Key Differences from Flux:**
- Uses negative prompts (unlike Flux)
- Uses CFGGuider instead of embedded guidance
- Uses BetaSamplingScheduler for sigmas
- Different CLIP type: "chroma" not "flux"

**Implemented:** Added buildChroma() workflow builder - Flux-like but with negatives!

---

## Workflow Builder Improvements Identified

1. **SD3.5 (`buildSD35`)**: Add `ModelSamplingSD3` node with shift parameter
2. **Qwen Image Edit**: New workflow builder opportunity (complex - needs multi-image UI)
3. ~~**Chroma**: New workflow builder - Flux-like but with CFG/negatives~~ ✅ DONE
4. **LoRA Order**: For SD3, LoRAs should go AFTER ModelSamplingSD3

---

## Recent Changes (Session)

### Fixed: LoRA Metadata Server Not Starting
- **Issue**: `lora-metadata` service was defined but not in start order
- **Fix**: Added `lora-metadata` to both start and stop order in `server_manager.py`
- Now starts automatically with `python server_manager.py start`

### Added: Chroma Model Support
- Added `buildChroma()` workflow builder in `comfyui_workflow_builder.dart`
- Added Chroma detection in `generation_provider.dart`
- Added Chroma to LoRA base model options in `lora_provider.dart`
- Added Chroma to metadata server patterns in `lora_metadata_server.py`

### Added: HiDream Model Support
- Added `buildHiDream()` workflow builder with QuadrupleCLIPLoader (4 CLIP models!)
  - Uses clip_l, clip_g, t5xxl, and llama_3.1_8b_instruct
  - ModelSamplingSD3 with configurable shift
- Added HiDream detection in `generation_provider.dart` with auto-variant detection:
  - **Full**: shift=3, 50 steps, uni_pc sampler
  - **Dev**: shift=6, 28 steps, lcm sampler, CFG=1
  - **Fast**: shift=3, 16 steps, lcm sampler, CFG=1
- Added hidream to LoRA base model options

### Added: OmniGen2 Model Support
- Added `buildOmniGen2()` workflow builder in `comfyui_workflow_builder.dart`
  - Uses CLIPLoader with type "omnigen2" (Qwen 2.5 VL encoder)
  - Standard KSampler workflow with CFG
- Added OmniGen2 detection in `generation_provider.dart`
- Added omnigen2 to LoRA base model options in `lora_provider.dart`
- Added omnigen2 to metadata server patterns in `lora_metadata_server.py`

---

## Reference Workflow Analysis (New)

### 4. HiDream LoRA Workflow
**Key Nodes:**
- `UNETLoader` → HiDream model
- `QuadrupleCLIPLoader` → clip_l, clip_g, t5xxl, llama (4 encoders!)
- `ModelSamplingSD3` with shift=3 (Full) or shift=6 (Dev)
- `CLIPTextEncode` for prompts
- `EmptySD3LatentImage` (16 channels)
- `KSampler` with variant-specific settings

### 5. OmniGen2 Workflow
**Key Nodes:**
- `UNETLoader` → omnigen2 model
- `CLIPLoader` with type="omnigen2" → Qwen 2.5 VL encoder
- `DualCFGGuider` - For image reference (optional)
- `EmptySD3LatentImage`
- `KSampler` with CFG

---

## LTX-2 Video Workflow (Updated to Match Reference Exactly)

### Reference: `/home/alex/eriui/ltx2.json`

**Two-Stage Sampling with Audio:**

**Stage 1 (Base - Half Resolution):**
- `CheckpointLoaderSimple` → ltx-2-19b-dev-fp8.safetensors
- `LTXAVTextEncoderLoader` → gemma_3_12B_it.safetensors
- `LTXVAudioVAELoader` → from same checkpoint
- `CLIPTextEncode` for positive/negative prompts
- `LTXVConditioning` → frame_rate=24
- `EmptyLTXVLatentVideo` → half resolution (640x360 for 1280x720 output)
- `LTXVEmptyLatentAudio` → audio latent
- `LTXVConcatAVLatent` → combine video + audio latents
- `LTXVScheduler` → steps=20, max_shift=2.05, base_shift=0.95, stretch=true, terminal=0.1
- `CFGGuider` → cfg=4 (base model, no LoRA)
- `KSamplerSelect` → euler_ancestral
- `SamplerCustomAdvanced` → first pass sampling

**Upscale:**
- `LTXVSeparateAVLatent` → separate video/audio after stage 1
- `LTXVCropGuides` → prepare for upscale
- `LatentUpscaleModelLoader` → ltx-2-spatial-upscaler-x2-1.0.safetensors
- `LTXVLatentUpsampler` → 2x spatial upscale
- `LTXVConcatAVLatent` → recombine with audio

**Stage 2 (Refinement - Full Resolution with LoRA):**
- `LoraLoaderModelOnly` → ltx-2-19b-distilled-lora-384.safetensors (ALWAYS applied!)
- Optional: Additional camera control LoRAs
- `ManualSigmas` → "0.909375, 0.725, 0.421875, 0.0" (4 steps)
- `CFGGuider` → cfg=1
- `KSamplerSelect` → euler_ancestral
- `SamplerCustomAdvanced` → refinement pass (uses denoised_output slot 1)

**Decode & Output:**
- `LTXVSeparateAVLatent` → final separate
- `VAEDecodeTiled` → tile_size=512, overlap=64, temporal_size=4096, temporal_overlap=8
- `LTXVAudioVAEDecode` → decode audio
- `CreateVideo` → combine images + audio at fps
- `SaveVideo` → mp4 output

**Key Parameters (defaults):**
- Width: 1280, Height: 720
- Frames: 121
- Steps: 20 (stage 1)
- CFG: 4.0 (stage 1), 1.0 (stage 2)
- FPS: 24
- Distilled LoRA: ltx-2-19b-distilled-lora-384.safetensors (applied by default!)

**Implementation Updated:** `buildLTXVideo()` now matches reference exactly with:
- Default distilled LoRA applied to stage 2
- Configurable upscale model and text encoder
- User-provided LoRAs applied after distilled LoRA
