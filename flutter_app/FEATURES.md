# EriUI Features Guide

Complete guide covering all 30 features in EriUI.

---

## Core Features (1-10)

### 1. Prompt Syntax Engine

Expand special syntax in your prompts before generation.

#### Supported Syntax

| Syntax | Description | Example |
|--------|-------------|---------|
| `<random:a,b,c>` | Randomly select one option | `a <random:cat,dog,bird> in a field` |
| `<wildcard:name>` | Random line from wildcard file | `a <wildcard:animals> playing` |
| `<alternate:a,b>` | Alternate between options each step | `<alternate:red,blue> sky` |
| `<fromto[0.5]:a,b>` | Switch from a to b at 50% | `<fromto[0.5]:sketch,photo>` |
| `<repeat[3]:word>` | Repeat word N times | `<repeat[3]:very> good` |
| `<trigger>` | Insert model's trigger phrase | `<trigger>, a portrait` |
| `<lora:name:weight>` | Apply LoRA with weight | `<lora:detail:0.8>` |
| `(word:1.5)` | Weight adjustment | `a (beautiful:1.3) sunset` |
| `<setvar[name]:value>` | Set variable | `<setvar[color]:red>` |
| `<var:name>` | Use variable | `a <var:color> car` |
| `<comment:text>` | Comment (stripped) | `<comment:test prompt>` |

---

### 2. Presets System

Save and load generation parameter presets.

#### How to Use

1. **Save a Preset:** Set parameters → Presets tab → "+ New Preset" → Enter name → Save
2. **Load a Preset:** Click any preset card to apply parameters instantly
3. **Manage:** Use three-dots menu to Edit, Delete, Export, or Import presets

#### Preset Contents
- Prompt & Negative Prompt
- Model, Steps, CFG Scale
- Width, Height, Sampler, Scheduler

---

### 3. Autocompletions

Get tag suggestions as you type.

- Start typing to see suggestions
- Press **Tab** or click to complete
- Type `<` for prompt syntax options
- Color-coded: Green (characters), Red (artists), Blue (general), Purple (meta)

---

### 4. Wildcards Manager

Create wildcard files for dynamic prompts.

**Access:** Tools > Wildcards

1. Click "+ New Wildcard"
2. Add options (one per line)
3. Use in prompts: `<wildcard:name>`
4. Organize with folders: `<wildcard:animals/pets>`

---

### 5. Grid Generator

Compare parameters in a grid layout.

**Access:** Tools > Grid Generator

1. Select X-Axis parameter and values (e.g., CFG `1,3,5,7`)
2. Optionally select Y-Axis
3. Click "Generate Grid"
4. View results as grid or individual images

---

### 6. Prompt Weighting UI

Adjust word emphasis with keyboard shortcuts.

| Shortcut | Action |
|----------|--------|
| `Ctrl + Up Arrow` | Increase weight |
| `Ctrl + Down Arrow` | Decrease weight |

Example: Select "cat" → Ctrl+Up → `(cat:1.1)` → Ctrl+Up → `(cat:1.2)`

---

### 7. Model Metadata Browser

View and edit model information.

**Access:** Three-dots menu on model card → "Edit Metadata"

- View: Title, Author, Architecture, Trigger phrase, Resolution
- Edit any field and save
- **Load from CivitAI:** Paste URL to auto-fetch metadata
- **Auto-Apply:** Selecting a model applies recommended settings

---

### 8. Image History + Metadata

Enhanced history with full parameter display.

- **Hover:** See all generation parameters
- **Three-dots menu:** Copy Seed, Copy Prompt, Copy All, Use Settings, Use as Init Image, Delete
- **Single click:** View full-size
- **Double-click:** Load all parameters
- History persists across sessions (configurable limit)

---

### 9. Batch Queue System

Queue multiple generations with different parameters.

**Access:** Queue panel (appears with batch > 1) or Tools > Queue

- **Pause/Resume** processing
- **Reorder** by dragging
- **Cancel** individual items
- Status: Pending (gray), Running (blue), Completed (green), Failed (red)

---

### 10. Regional Prompting UI

Apply different prompts to image regions.

**Access:** Tools > Regional Prompting

1. Click "+ Add Region"
2. Draw rectangle on canvas
3. Enter region-specific prompt
4. Adjust strength (0.0 - 1.0)
5. Add multiple regions with different colors

---

## Extended Features (11-30)

### 11. Drag-Drop Image to Prompt

Drop images directly into the app.

- **Drop on prompt area:** Set as init image
- **Drop on gallery:** Import to gallery
- Supports: PNG, JPG, WebP, GIF
- Also supports paste from clipboard (Ctrl+V)

---

### 12. Collapsible Parameter Groups

Organize parameters into expandable sections.

- Click group headers to collapse/expand
- State persists across sessions
- Groups: Basic, Sampling, Size, Advanced, LoRAs

---

### 13. Seed Lock/Variation

Control seed behavior for reproducible or varied results.

- **Lock icon:** Toggle to keep same seed between generations
- **Dice icon:** Randomize seed (-1)
- **Variation Mode:** Generate slight variations from a seed
- Copy/paste seed values

---

### 14. Aspect Ratio Selector

Quick aspect ratio presets with visual preview.

| Ratio | Resolution | Use Case |
|-------|------------|----------|
| 1:1 | 1024×1024 | Square, profile pics |
| 16:9 | 1344×768 | Landscape, wallpapers |
| 9:16 | 768×1344 | Portrait, mobile |
| 4:3 | 1152×896 | Classic photo |
| 3:2 | 1216×832 | DSLR standard |
| 21:9 | 1536×640 | Ultrawide, cinematic |

Click ratio button or enter custom dimensions.

---

### 15. Theme Toggle

Switch between light and dark themes.

- **Sun/Moon icon** in top navigation bar
- Click to toggle instantly
- Preference saved across sessions

---

### 16. Keyboard Shortcuts

Configurable keyboard shortcuts for common actions.

**Access:** Settings > Keyboard Shortcuts

| Default Shortcut | Action |
|------------------|--------|
| `Enter` | Generate |
| `Ctrl+Enter` | Generate (locked seed) |
| `Escape` | Cancel generation |
| `Ctrl+S` | Save preset |
| `Ctrl+Z` | Undo prompt |
| `Ctrl+Shift+C` | Copy seed |
| `Ctrl+V` | Toggle video mode |
| `Ctrl+R` | Randomize seed |
| `Ctrl+P` | Focus prompt |
| `Ctrl+N` | Focus negative prompt |
| `Ctrl+,` | Open settings |
| `Ctrl+M` | Open models |
| `Ctrl+G` | Open gallery |

All shortcuts are customizable.

---

### 17. Batch Generation Panel

Advanced batch generation controls.

- Set batch count (1-16)
- Queue multiple batches
- View progress per batch item
- Pause/resume batch processing
- Cancel individual items

---

### 18. Variation Generator

Create variations of existing images.

**Access:** Three-dots menu on image → "Generate Variations"

1. Select source image
2. Choose variation strength (0.1 - 1.0)
   - Low: Similar to original
   - High: More creative/different
3. Select count (1, 2, 4, 8, 9, or 16)
4. Click "Generate Variations"

Uses img2img with random seeds while keeping style/composition.

---

### 19. Infinite Generation

Continuous generation mode.

- Toggle "Infinite" mode
- App generates continuously until stopped
- Images queue automatically
- Great for exploration/overnight runs
- Stop anytime with cancel button

---

### 20. Init Image Panel

Full-featured img2img interface.

**Features:**
- Drag & drop support
- Paste from clipboard (Ctrl+V)
- Preview thumbnail
- Creativity/Denoise slider (0.0 - 1.0)
  - Low: Follow original closely
  - High: More creative interpretation
- Resize modes: Stretch, Crop, Pad, Just Resize
- Clear button

---

### 21. Image Comparison Slider

Compare two images side-by-side.

**Access:** Select image → Three-dots → "Compare With..."

- Drag slider left/right to reveal images
- Labels show which is "Before" and "After"
- "Swap Images" button reverses positions
- Full-screen dialog for detailed comparison

---

### 22. Output Folder Organization

Configure output folder structure.

**Access:** Settings > Paths

Options:
- **By Date:** `Output/2024-01-15/image.png`
- **By Model:** `Output/flux-dev/image.png`
- **By Project:** `Output/MyProject/image.png`
- **Custom Pattern:** `{date}/{model}/{prompt:20}`

Pattern variables: `{date}`, `{time}`, `{model}`, `{prompt}`, `{seed}`, `{width}`, `{height}`

---

### 23. Bulk Operations

Perform actions on multiple images at once.

**Access:** Gallery → Select Mode (checkbox icon)

1. Click images to select (blue checkmark)
2. Use bulk action bar:
   - **Delete All:** Remove selected images
   - **Move To:** Move to folder
   - **Export:** Download as ZIP
   - **Add to Dataset:** Training dataset prep
3. Click "Cancel" to exit selection mode

---

### 24. Image Search/Filter

Find images in gallery quickly.

**Access:** Gallery → Search/Filter bar

- **Search:** Text search in prompts and metadata
- **Filter by:**
  - Model used
  - Date range
  - Resolution
  - Has LoRA
  - Favorited
- **Sort:** Date, Name, Size
- Combine filters for precise results

---

### 25. Model Comparison View

Compare outputs from different models.

**Access:** Tools > Model Comparison

1. Select 2-4 models to compare
2. Enter shared prompt
3. Lock seed for fair comparison
4. Click "Compare"
5. View side-by-side results
6. Use comparison slider between any two

---

### 26. Model Categories/Tags

Organize models with categories and tags.

**Features:**
- **Architecture filters:** SD 1.5, SDXL, Flux, SD3, etc.
- **Custom tags:** Add your own tags to models
- **Categories:** Character, Style, Realistic, Anime, etc.
- **Quick filters:** Filter model list by any tag/category
- Tags persist in model metadata

---

### 27. Model Download Manager

Download models directly in the app.

**Access:** Models → Download (cloud icon)

**Features:**
- Paste CivitAI or Hugging Face URL
- Auto-detect model type and destination
- Progress bar with speed/ETA
- Queue multiple downloads
- Resume interrupted downloads
- Cancel anytime

---

### 28. LoRA Browser Improvements

Enhanced LoRA management.

**Features:**
- Thumbnail previews
- Strength slider per LoRA (0.0 - 2.0)
- Trigger word display
- Quick search/filter
- Favorites for quick access
- Model compatibility indicators
- Drag to reorder applied LoRAs

---

### 29. Generation Queue Preview

Visual preview of queued generations.

**Access:** Queue panel (bottom of generate screen)

**Features:**
- Thumbnail preview of settings
- Prompt preview
- Estimated time
- Drag to reorder
- Click to edit before generation
- Progress indicators
- Cancel individual items

---

### 30. Stealth Metadata

Embed generation parameters invisibly in images.

**Access:** Settings > Generation > Stealth Metadata

**How it works:**
- Uses LSB (Least Significant Bit) steganography
- Encodes parameters into pixel data
- Invisible to human eye
- Survives most image compression
- Works with social media uploads

**Usage:**
1. Enable "Stealth Metadata" in settings
2. Generate images normally
3. Parameters are automatically embedded
4. Drop any image to extract hidden parameters

**Embedded data:**
- Prompt, Negative prompt
- Model, Seed, Steps, CFG
- Resolution, Sampler, Scheduler
- Timestamp, Version info

---

## Quick Reference

| Feature | Access | Shortcut |
|---------|--------|----------|
| Presets | Bottom panel > Presets | - |
| Wildcards | Tools > Wildcards | - |
| Grid Generator | Tools > Grid Generator | - |
| Regional Prompting | Tools > Regional Prompting | - |
| Queue | Tools > Queue | - |
| Model Metadata | Model card > Three dots | - |
| Model Comparison | Tools > Model Comparison | - |
| History Params | History > Hover/Click | - |
| Prompt Weight | Select text | Ctrl+Up/Down |
| Autocomplete | Type in prompt | Tab |
| Theme Toggle | Top bar sun/moon | - |
| Generate | Generate button | Enter |
| Cancel | Cancel button | Escape |
| Settings | Navigation | Ctrl+, |

---

## Tips & Tricks

1. **Combine wildcards with presets** for endless variety
2. **Use Grid Generator** to find optimal CFG/steps
3. **Lock seed** when comparing models or LoRAs
4. **Double-click history** to quickly reuse settings
5. **Stealth metadata** lets you share images while keeping params
6. **Variation generator** is great for exploring around a good image
7. **Keyboard shortcuts** speed up your workflow significantly
8. **Bulk operations** for managing large galleries
9. **Model comparison** helps pick the best model for your style
10. **Custom output folders** keep your work organized

---

*Generated for EriUI v2.0*
