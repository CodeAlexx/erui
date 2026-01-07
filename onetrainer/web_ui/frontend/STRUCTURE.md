# Frontend Structure

## Complete File Tree

```
frontend/
├── package.json                    # Dependencies and scripts
├── tsconfig.json                   # TypeScript configuration
├── tsconfig.node.json              # TypeScript config for Vite
├── vite.config.ts                  # Vite configuration
├── tailwind.config.js              # Tailwind CSS configuration
├── postcss.config.js               # PostCSS configuration
├── index.html                      # HTML entry point
├── setup.sh                        # Setup script
├── README.md                       # Main documentation
├── QUICKSTART.md                   # Quick start guide
├── STRUCTURE.md                    # This file
│
└── src/
    ├── main.tsx                    # Application entry point
    ├── App.tsx                     # Main app component
    ├── index.css                   # Global styles
    │
    ├── components/
    │   ├── ui/                     # shadcn/ui components
    │   │   ├── button.tsx          # Button component
    │   │   ├── card.tsx            # Card component
    │   │   ├── input.tsx           # Input component
    │   │   ├── label.tsx           # Label component
    │   │   ├── select.tsx          # Select dropdown component
    │   │   ├── switch.tsx          # Toggle switch component
    │   │   └── tabs.tsx            # Tabs component
    │   │
    │   ├── layout/                 # Layout components
    │   │   ├── Header.tsx          # Top navigation bar
    │   │   ├── TabNav.tsx          # Tab navigation
    │   │   └── StatusBar.tsx       # Bottom status bar
    │   │
    │   └── tabs/                   # Tab content components
    │       └── TrainingTab.tsx     # Training configuration tab
    │
    ├── lib/
    │   ├── api.ts                  # API client and endpoints
    │   └── utils.ts                # Utility functions
    │
    ├── stores/
    │   └── configStore.ts          # Zustand state management
    │
    └── types/
        └── config.ts               # TypeScript type definitions
```

## Component Overview

### UI Components (shadcn/ui)

All components follow shadcn/ui patterns with Radix UI primitives:

- **button.tsx** - Multi-variant button (default, primary, success, danger, ghost)
- **card.tsx** - Card container with header, title, and content sections
- **input.tsx** - Styled text input with focus states
- **label.tsx** - Form label with proper accessibility
- **select.tsx** - Dropdown select with search and icons
- **switch.tsx** - Toggle switch for boolean values
- **tabs.tsx** - Tab navigation and content areas

### Layout Components

- **Header.tsx** - Application header with:
  - OneTrainer branding
  - Preset selector dropdown
  - Load/Save/Settings buttons

- **TabNav.tsx** - Main navigation tabs:
  - General, Model, Data, Concepts, Training
  - Sampling, Backup, Tools, Cloud, LoRA

- **StatusBar.tsx** - Bottom status bar with:
  - Start/Pause/Stop training buttons
  - Training metrics display
  - Progress bar
  - Status indicator

### Tab Components

- **TrainingTab.tsx** - Example implementation showing:
  - Training configuration form
  - Optimizer settings
  - Advanced options
  - Proper use of UI components

## Key Files

### Configuration

- **package.json** - All dependencies including:
  - React 18.3.1
  - TypeScript 5.3.3
  - Vite 5.0.10
  - Tailwind CSS 3.4.0
  - Radix UI primitives
  - Zustand 4.4.7
  - Axios 1.6.2

- **vite.config.ts** - Vite setup with:
  - Port 5173
  - API proxy to localhost:8000
  - WebSocket proxy for /ws
  - Path aliases (@/ → ./src)

- **tailwind.config.js** - Custom theme:
  - Dark mode by default
  - OneTrainer color palette
  - Custom font families

- **tsconfig.json** - TypeScript configuration:
  - Strict mode enabled
  - Path aliases configured
  - Modern ES2020 target

### Application

- **main.tsx** - React entry point with StrictMode

- **App.tsx** - Main application component:
  - Tab state management
  - Tab content routing
  - Layout composition

- **index.css** - Global styles:
  - Tailwind directives
  - Custom scrollbar styling
  - Utility classes

### API & State

- **lib/api.ts** - Axios client with endpoints:
  - trainingApi (status, start, stop, pause, resume)
  - configApi (presets, get, save, delete)
  - filesystemApi (browse, scan)

- **stores/configStore.ts** - Zustand store:
  - Training configuration state
  - Training status state
  - Current preset tracking
  - State update methods

- **types/config.ts** - TypeScript types:
  - TrainingConfig interface
  - TrainingStatus interface
  - Concept interface
  - Sample interface
  - Preset interface

## Color Palette

```typescript
colors: {
  dark: {
    bg: '#1a1a2e',        // Main background
    surface: '#252541',   // Cards, panels
    border: '#3a3a52',    // Borders
    hover: '#2d2d43',     // Hover states
  },
  primary: {
    DEFAULT: '#22b8cf',   // Cyan accent
    hover: '#1a9db1',     // Darker cyan
    light: '#3cd4eb',     // Lighter cyan
  },
  success: '#10b981',     // Green
  warning: '#f59e0b',     // Orange
  danger: '#ef4444',      // Red
}
```

## Next Steps

To complete the frontend, you'll need to:

1. Create remaining tab components:
   - GeneralTab.tsx
   - ModelTab.tsx
   - DataTab.tsx
   - ConceptsTab.tsx
   - SamplingTab.tsx
   - BackupTab.tsx
   - ToolsTab.tsx
   - CloudTab.tsx
   - LoRATab.tsx

2. Implement API integration:
   - Connect forms to configStore
   - Wire up training controls
   - Implement preset loading/saving
   - Add WebSocket for real-time updates

3. Add features:
   - Form validation
   - Error handling
   - Loading states
   - Notifications/toasts
   - File browser component
   - Sample preview

4. Testing:
   - Unit tests for components
   - Integration tests for API
   - E2E tests for workflows
