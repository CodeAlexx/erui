# OneTrainer UI Audit & Plan

**Status:**
- Tkinter UI: REMOVE (once EriUI stable)
- Web UI: KEEP as fallback

## Code Audit Summary

### UI Code

| Component | Lines | Path | Notes |
|-----------|-------|------|-------|
| Tkinter UI | 7,994 | `modules/ui/` | Desktop GUI widgets |
| Web UI Backend | 16,911 | `web_ui/backend/` | FastAPI server |
| Web UI Frontend | 18,414 | `web_ui/frontend/` | React/TypeScript |
| UI Scripts | 118 | `scripts/*_ui.py` | GUI launchers |
| **TOTAL UI** | **43,437** | | **39% of codebase** |

### Core Code (Keep)

| Component | Lines | Path | Notes |
|-----------|-------|------|-------|
| Model Loaders | ~8,000 | `modules/modelLoader/` | All architectures |
| Model Savers | ~6,000 | `modules/modelSaver/` | Checkpoint saving |
| Model Setup | ~7,000 | `modules/modelSetup/` | Training config |
| Model Samplers | ~4,000 | `modules/modelSampler/` | Inference during training |
| Data Loaders | ~5,000 | `modules/dataLoader/` | Dataset handling |
| Trainers | ~3,000 | `modules/trainer/` | GenericTrainer, etc. |
| Models | ~8,000 | `modules/model/` | Architecture definitions |
| Utilities | ~20,000 | `modules/util/` | Config, args, callbacks |
| Persistence | ~3,000 | `modules/persistence/` | Database, migrations |
| Core Scripts | 1,741 | `scripts/` (non-UI) | train.py, sample.py |
| **TOTAL CORE** | **~66,711** | | **61% of codebase** |

## Removal Checklist (Future)

### Phase 1: Remove Tkinter (once EriUI stable)
- [ ] Delete `modules/ui/` directory (7,994 lines)
- [ ] Delete `scripts/train_ui.py`
- [ ] Delete `scripts/caption_ui.py`
- [ ] Delete `scripts/convert_model_ui.py`
- [ ] Delete `scripts/video_tool_ui.py`
- [ ] Remove tkinter from requirements.txt

### Phase 2: Web UI - KEEP AS FALLBACK
Web UI (35,325 lines) retained for:
- Browser-based access when Flutter unavailable
- Remote training management
- API reference implementation
- Debugging/diagnostics

### Phase 3: Cleanup (after Tkinter removal)
- [ ] Remove any orphaned tkinter-only utilities
- [ ] Update imports that reference removed modules
- [ ] Test all training functionality via EriUI + Web UI fallback

## Integration Points

EriUI replaces these OneTrainer UI functions:

| OneTrainer UI | EriUI Replacement |
|---------------|-------------------|
| TrainUI.py (tkinter) | Flutter trainer screens |
| web_ui/backend/api/ | Dart server direct IPC |
| web_ui/frontend/ | Flutter desktop app |
| ConfigList.py | Flutter config management |
| SampleWindow.py | Flutter sample viewer |
| ConceptWindow.py | Flutter concepts screen |

## Dependencies to Keep

These are required by core training (not UI-only):

- `torch`, `torchvision` - Training
- `transformers`, `diffusers` - Model loading
- `safetensors` - Checkpoint handling
- `accelerate` - Training optimization
- `pillow` - Image processing
- `numpy` - Numerical operations
- `tqdm` - Progress (used by trainer, not just UI)

## Notes

- Keep all UI code until EriUI training workflow is 100% tested
- Web UI backend is useful reference for API design
- Tkinter UI shows all configurable parameters
- ~43K lines removable = significant maintenance reduction

---

*Last updated: January 2026*
*EriUI Pre-Alpha v0.1.0*
