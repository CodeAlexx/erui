# UI Preview & Layout

## Visual Layout

```
┌─────────────────────────────────────────────────────────────────┐
│ OneTrainer         [Preset Selector ▾]    [Load] [Save] [⚙️]   │ ← Header (56px)
├─────────────────────────────────────────────────────────────────┤
│ General│Model│Data│Concepts│Training│Sampling│Backup│Tools│... │ ← Tab Nav (48px)
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Training Configuration                                  │    │
│  ├────────────────────────────────────────────────────────┤    │
│  │                                                         │    │
│  │ Learning Rate    [0.0001      ] Batch Size [1    ]    │    │
│  │ Epochs          [100          ] Gradient   [1    ]    │    │
│  │                                                         │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Optimizer Settings                                      │    │
│  ├────────────────────────────────────────────────────────┤    │
│  │                                                         │    │ ← Main Content
│  │ Optimizer        [AdamW ▾]                             │    │   (Scrollable)
│  │ LR Scheduler     [Constant ▾]                          │    │
│  │                                                         │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Advanced Options                                        │    │
│  ├────────────────────────────────────────────────────────┤    │
│  │                                                         │    │
│  │ Mixed Precision Training                    [●──]      │    │
│  │ Gradient Checkpointing                      [──○]      │    │
│  │ Use EMA                                     [──○]      │    │
│  │                                                         │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│ [▶ Start] [⏸ Pause] [■ Stop]  Epoch: 0/100  Step: 0/1000      │
│                         ████░░░░░░░░░░░░░░  Status: Idle   │ ← Status Bar (64px)
└─────────────────────────────────────────────────────────────────┘
```

## Color Scheme

### Background Colors
- **Header/TabNav/StatusBar**: `#252541` (dark surface)
- **Main Content Area**: `#1a1a2e` (dark background)
- **Cards**: `#252541` (dark surface)

### Accent Colors
- **Primary/Active**: `#22b8cf` (cyan/teal) - tabs, buttons, progress
- **Success**: `#10b981` (green) - start button
- **Danger**: `#ef4444` (red) - stop button
- **Warning**: `#f59e0b` (orange)

### Text Colors
- **Primary Text**: `#f3f4f6` (gray-100)
- **Secondary Text**: `#9ca3af` (gray-400)
- **Label Text**: `#e5e7eb` (gray-200)

### Borders
- **Default**: `#3a3a52` (subtle gray)
- **Hover**: `#2d2d43` (lighter on hover)

## Component Examples

### Card Component
```
┌────────────────────────────────────┐
│ Card Title                         │ ← CardHeader
├────────────────────────────────────┤
│                                    │
│ Content goes here...               │ ← CardContent
│                                    │
└────────────────────────────────────┘
```

### Input Field
```
Label
[                                   ] ← Focus: cyan ring
```

### Select Dropdown
```
Optimizer
[AdamW                           ▾]
  ↓ (when clicked)
┌────────────────────────────────┐
│ ✓ AdamW                        │ ← Selected (cyan check)
│   Adam                         │
│   SGD                          │
│   Adafactor                    │
└────────────────────────────────┘
```

### Switch Toggle
```
Option Name                    [●──] ← Off (gray)
Option Name                    [──●] ← On (cyan)
```

### Button Variants
```
[  Default  ]  ← Gray background
[  Primary  ]  ← Cyan background
[  Success  ]  ← Green background
[  Danger   ]  ← Red background
[   Ghost   ]  ← Transparent background
```

### Tab Navigation
```
General│Model│Data│Training│Sampling│Backup
   ↑       ↑                   ↑
 Inactive Active (cyan)     Inactive
 (gray)   (cyan underline)   (gray)
```

### Progress Bar
```
████████████░░░░░░░░░░░░ 40%
└─ Cyan fill   └─ Gray background
```

## Responsive Behavior

### Desktop (≥1024px)
- Full layout as shown
- 2-column grid for form fields
- Side-by-side controls

### Tablet (768px - 1023px)
- Stacked layout
- 2-column grid maintained
- Compressed spacing

### Mobile (<768px)
- Single column layout
- Full-width cards
- Stacked form fields
- Scrollable tab navigation

## Interactive States

### Buttons
```
Default:  bg-gray, text-white
Hover:    bg-lighter, text-white
Active:   bg-darker, text-white
Disabled: opacity-50, cursor-not-allowed
```

### Inputs
```
Default: border-gray, bg-dark
Focus:   border-transparent, ring-cyan
Error:   border-red, ring-red
```

### Cards
```
Default: border-gray, bg-dark
Hover:   border-lighter (subtle)
```

## Spacing System

- **Padding**: 16px (cards), 24px (page)
- **Gap**: 16px (form fields), 24px (sections)
- **Margin**: 0 (controlled by parent)

## Typography

### Headings
- **Card Title**: 18px, semibold, gray-100
- **Section Title**: 16px, medium, gray-200

### Body Text
- **Labels**: 14px, medium, gray-200
- **Input Text**: 14px, normal, gray-100
- **Help Text**: 13px, normal, gray-400

### Monospace (Code/Paths)
- **Font**: JetBrains Mono
- **Size**: 13px
- **Color**: gray-300

## Icons

Using Lucide React icons:
- **Play**: Training start
- **Pause**: Training pause
- **Square**: Training stop
- **Upload**: Load config
- **Download**: Save config
- **Settings**: Settings menu
- **ChevronDown**: Dropdown indicators
- **Check**: Selection indicators

## Animation

- **Transitions**: 150ms ease for colors
- **Progress Bar**: 300ms ease for width changes
- **Hover Effects**: Instant (0ms) for better responsiveness
- **Tab Switching**: Instant content swap

## Accessibility

- **Focus Rings**: 2px cyan ring on all interactive elements
- **Keyboard Navigation**: Tab order follows visual flow
- **ARIA Labels**: All inputs have proper labels
- **Color Contrast**: WCAG AA compliant
- **Screen Reader**: Semantic HTML structure

## Example Screens

### Training Tab (Active)
- Large form with multiple sections
- Card-based layout
- 2-column grid for inputs
- Toggle switches for boolean options

### Status Bar States

**Idle:**
```
[▶ Start] [⏸ Pause] [■ Stop]  Status: Idle
         (enabled)  (disabled) (disabled)
```

**Running:**
```
[▶ Start] [⏸ Pause] [■ Stop]  Epoch: 42/100  Loss: 0.0234
(disabled) (enabled)  (enabled) ████████░░░░░░  Status: Running
```

**Error:**
```
[▶ Start] [⏸ Pause] [■ Stop]  Status: Error: CUDA out of memory
(enabled)  (disabled) (enabled) (red text)
```

## Dark Mode Only

This UI is designed exclusively for dark mode matching OneTrainer's desktop application aesthetic. No light mode variant is planned.
