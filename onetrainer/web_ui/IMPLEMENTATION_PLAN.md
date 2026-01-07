# Web UI Implementation Plan

## Current Status: Backend Foundation Complete

### What's Already Implemented

#### Backend (FastAPI)
```
web_ui/backend/
├── main.py                    # FastAPI app with CORS, routes
├── models.py                  # Pydantic request/response models
├── api/
│   ├── training.py            # /api/training/* endpoints
│   ├── config.py              # /api/config/* endpoints
│   ├── system.py              # /api/system/* endpoints
│   ├── filesystem.py          # /api/filesystem/* endpoints
│   └── samples.py             # /api/samples/* endpoints
├── services/
│   └── trainer_service.py     # TrainerService singleton wrapping GenericTrainer
└── ws/
    ├── connection_manager.py  # WebSocket connection management
    ├── handlers.py            # WebSocket message handlers
    ├── events.py              # Event types and broadcasting
    └── training_bridge.py     # Bridge to TrainCallbacks
```

#### Frontend (React + Vite)
```
web_ui/frontend/src/
├── lib/api.ts                 # Axios API client + WebSocket client
├── components/
│   ├── layout/Sidebar.tsx     # Navigation sidebar
│   └── views/
│       ├── DashboardView.tsx  # GPU monitor + Training console
│       ├── NewJobView.tsx     # Job creation with presets
│       ├── TrainingView.tsx   # Training params, LoRA, samples tabs
│       ├── ConceptsView.tsx   # Concept management
│       ├── SamplingView.tsx   # Sample definitions
│       └── ...                # Other views
```

---

## Phase 1: Core Training Flow (Priority: HIGH)

### 1.1 Wire "Create Job" to Start Training
**Files:** `NewJobView.tsx`, `api/training.py`

```typescript
// Frontend: NewJobView.tsx
const handleCreateJob = async () => {
  // 1. Save current config to temp file
  const configPath = await configApi.saveTemp(config);

  // 2. Start training with config path
  await trainingApi.start(configPath);

  // 3. Navigate to Dashboard to watch progress
  onViewChange('dashboard');
};
```

**Backend changes needed:**
- Add `POST /api/config/save-temp` endpoint to save config JSON
- Ensure training starts in background thread (already done)

### 1.2 Add Loss/Metrics to Progress Updates
**Files:** `trainer_service.py`, `training_bridge.py`

OneTrainer's `TrainProgress` doesn't include loss. Need to capture from training loop:

```python
# trainer_service.py - Add loss tracking
def _on_update_train_progress(self, progress: TrainProgress, max_step: int, max_epoch: int):
    # Get loss from trainer if available
    loss = None
    smooth_loss = None
    if self._trainer and hasattr(self._trainer, 'loss'):
        loss = self._trainer.loss
    if self._trainer and hasattr(self._trainer, 'smooth_loss'):
        smooth_loss = self._trainer.smooth_loss

    progress_dict = {
        "epoch": progress.epoch,
        "epoch_step": progress.epoch_step,
        "global_step": progress.global_step,
        "loss": loss,
        "smooth_loss": smooth_loss,
    }
```

### 1.3 Dashboard Real-time Updates
**Files:** `DashboardView.tsx`

Already partially implemented. Needs:
- Connect WebSocket progress events to log display
- Show epoch progress bar alongside step progress
- Display learning rate if available

---

## Phase 2: Configuration Management (Priority: HIGH)

### 2.1 Save/Load Config from UI
**Files:** `NewJobView.tsx`, `TrainingView.tsx`, `api/config.py`

```typescript
// Save config button handler
const handleSaveConfig = async () => {
  const name = await promptForName();
  await configApi.savePreset(name, config);
  refreshPresets();
};
```

**Backend:** Already has `POST /api/config/presets/{name}` - just wire it up.

### 2.2 Config Validation Before Training
**Files:** `NewJobView.tsx`

```typescript
const handleCreateJob = async () => {
  // Validate first
  const validation = await configApi.validate(config);
  if (!validation.valid) {
    setErrors(validation.errors);
    return;
  }
  // Proceed with training...
};
```

**Backend:** Already has `POST /api/config/validate` - just wire it up.

---

## Phase 3: Concepts Management (Priority: MEDIUM)

### 3.1 Add Concept CRUD Endpoints
**Files:** New `api/concepts.py`

```python
router = APIRouter()

@router.get("/")
async def list_concepts(config_path: str):
    """List concepts from a config file."""

@router.post("/")
async def add_concept(concept: ConceptRequest):
    """Add a new concept to config."""

@router.put("/{index}")
async def update_concept(index: int, concept: ConceptRequest):
    """Update existing concept."""

@router.delete("/{index}")
async def delete_concept(index: int):
    """Remove concept from config."""
```

### 3.2 Wire ConceptsView to API
**Files:** `ConceptsView.tsx`

- Load concepts from current config
- Add/edit/delete concepts
- Update config when concepts change

---

## Phase 4: Sample Generation (Priority: MEDIUM)

### 4.1 Sample During Training
**Files:** `TrainingView.tsx`, `trainer_service.py`

```typescript
// Request sample generation during training
const handleGenerateSample = async () => {
  await trainingApi.sampleDefault();
};
```

**Backend:** Already has `trainer_service.sample_default()` - add endpoint.

### 4.2 Sample Image Display
**Files:** `TrainingView.tsx` (Samples tab), `api/samples.py`

- WebSocket broadcasts sample events with paths
- Frontend displays sample images in grid
- Add endpoint to serve sample images

```python
@router.get("/image/{sample_id}")
async def get_sample_image(sample_id: str):
    """Serve sample image file."""
    return FileResponse(sample_path)
```

---

## Phase 5: Queue Management (Priority: LOW)

### 5.1 Job Queue Backend
**Files:** New `services/queue_service.py`

```python
class QueueService:
    def __init__(self):
        self.queue: List[QueuedJob] = []
        self.current_job: Optional[QueuedJob] = None

    def add_job(self, config: TrainConfig) -> str:
        """Add job to queue, return job ID."""

    def remove_job(self, job_id: str):
        """Remove job from queue."""

    def start_next(self):
        """Start next job in queue when current finishes."""
```

### 5.2 Queue API Endpoints
**Files:** New `api/queue.py`

```python
@router.get("/")
async def list_queue():

@router.post("/")
async def add_to_queue(config: ConfigRequest):

@router.delete("/{job_id}")
async def remove_from_queue(job_id: str):

@router.post("/{job_id}/move")
async def reorder_queue(job_id: str, position: int):
```

---

## Phase 6: Inference (Priority: LOW)

### 6.1 Inference Service
**Files:** New `services/inference_service.py`

```python
class InferenceService:
    def __init__(self):
        self.pipeline = None
        self.loaded_model = None

    def load_model(self, model_path: str, model_type: str):
        """Load model for inference."""

    def generate(self, prompt: str, params: GenerateParams) -> Image:
        """Generate image from prompt."""
```

### 6.2 Inference API
**Files:** New `api/inference.py`

```python
@router.post("/load")
async def load_model(model_path: str, model_type: str):

@router.post("/generate")
async def generate_image(request: GenerateRequest):

@router.get("/gallery")
async def list_generated_images():
```

---

## API Endpoint Summary

### Existing (Working)
| Endpoint | Method | Status |
|----------|--------|--------|
| `/api/training/start` | POST | ✅ Implemented |
| `/api/training/stop` | POST | ✅ Implemented |
| `/api/training/status` | GET | ✅ Implemented |
| `/api/training/progress` | GET | ✅ Implemented |
| `/api/config/presets` | GET | ✅ Implemented |
| `/api/config/presets/{name}` | GET | ✅ Implemented |
| `/api/config/presets/{name}` | POST | ✅ Implemented |
| `/api/config/validate` | POST | ✅ Implemented |
| `/api/system/info` | GET | ✅ Implemented |
| `/api/filesystem/browse` | GET | ✅ Implemented |

### Needed
| Endpoint | Method | Priority |
|----------|--------|----------|
| `/api/config/save-temp` | POST | HIGH |
| `/api/training/sample` | POST | MEDIUM |
| `/api/samples/image/{id}` | GET | MEDIUM |
| `/api/concepts` | CRUD | MEDIUM |
| `/api/queue` | CRUD | LOW |
| `/api/inference/load` | POST | LOW |
| `/api/inference/generate` | POST | LOW |

---

## WebSocket Events

### Existing
| Event | Direction | Status |
|-------|-----------|--------|
| `training_state` | Server→Client | ✅ |
| `progress` | Server→Client | ✅ (needs loss) |
| `sample_default` | Server→Client | ✅ |
| `sample_custom` | Server→Client | ✅ |

### Needed
| Event | Direction | Priority |
|-------|-----------|----------|
| `loss_update` | Server→Client | HIGH |
| `backup_created` | Server→Client | MEDIUM |
| `sample_image` | Server→Client | MEDIUM |
| `queue_update` | Server→Client | LOW |

---

## Quick Start Commands

```bash
# Start backend
cd /home/alex/OneTrainer
python -m web_ui.run

# Start frontend dev server
cd /home/alex/OneTrainer/web_ui/frontend
npm run dev

# Access UI
open http://localhost:5173
```

---

## Next Steps (Recommended Order)

1. **Wire NewJobView "Create Job" button** - Most impactful, enables actual training
2. **Add loss to progress updates** - Makes dashboard useful
3. **Connect config save/load** - Enables workflow persistence
4. **Add sample image serving** - Shows training progress visually
5. **Implement concepts API** - Full dataset configuration
6. **Queue management** - Multi-job workflows
7. **Inference** - Use trained models
