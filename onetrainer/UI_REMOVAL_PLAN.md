# OneTrainer UI Removal Plan

**Status:** DEFERRED - Keep all UI code until EriUI is fully operational

## Code Audit Summary

### UI Code (To Be Removed Later)

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

When EriUI fully replaces UI functionality:

### Phase 1: Remove Tkinter
- [ ] Delete `modules/ui/` directory (7,994 lines)
- [ ] Delete `scripts/train_ui.py`
- [ ] Delete `scripts/caption_ui.py`
- [ ] Delete `scripts/convert_model_ui.py`
- [ ] Delete `scripts/video_tool_ui.py`
- [ ] Remove tkinter from requirements.txt

### Phase 2: Remove Web UI
- [ ] Delete `web_ui/` directory (35,325 lines)
- [ ] Remove FastAPI, uvicorn from requirements
- [ ] Remove React/Node dependencies

### Phase 3: Cleanup
- [ ] Remove any orphaned UI-only utilities
- [ ] Update imports that reference removed modules
- [ ] Test all training functionality via EriUI

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
