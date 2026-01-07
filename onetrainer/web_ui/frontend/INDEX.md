# OneTrainer Frontend - Documentation Index

Complete index of all documentation files for the OneTrainer web UI frontend.

## Quick Links

| Document | Purpose | Audience |
|----------|---------|----------|
| [QUICKSTART.md](#quickstartmd) | Get started in 5 minutes | New developers |
| [SUMMARY.md](#summarymd) | Complete implementation overview | Everyone |
| [README.md](#readmemd) | Main documentation | Developers |
| [STRUCTURE.md](#structuremd) | File structure reference | Developers |
| [UI_PREVIEW.md](#ui_previewmd) | Visual design guide | Designers/Developers |
| [SCRIPTS.md](#scriptsmd) | All available scripts | Developers |
| [INDEX.md](#indexmd) | This file | Everyone |

## Documentation Files

### QUICKSTART.md
**Quick Start Guide**
- Installation steps
- First run instructions
- Basic usage examples
- Common operations
- Troubleshooting basics

**Best for:** New developers who want to get up and running quickly.

---

### SUMMARY.md
**Implementation Summary**
- What was created
- Technology stack
- Core features
- File structure overview
- Getting started steps
- What's working vs what needs implementation
- Design system
- Next steps

**Best for:** Understanding the complete scope of the implementation.

---

### README.md
**Main Documentation**
- Project overview
- Tech stack details
- Getting started
- Project structure
- Features list
- API integration details
- Color scheme
- Development guide

**Best for:** Comprehensive understanding of the project.

---

### STRUCTURE.md
**File Structure Reference**
- Complete file tree
- Component overview
- UI components descriptions
- Layout components
- API and state files
- Configuration files
- Color palette
- Next steps

**Best for:** Understanding where everything is located.

---

### UI_PREVIEW.md
**Visual Design Guide**
- Visual layout mockup
- Color scheme details
- Component examples
- Responsive behavior
- Interactive states
- Spacing system
- Typography guide
- Icons reference
- Animation specs
- Accessibility notes
- Example screens

**Best for:** Understanding the visual design and user interface.

---

### SCRIPTS.md
**Scripts Reference**
- Package scripts (npm commands)
- Custom scripts (setup, verify)
- Environment variables
- Port configuration
- Build options
- TypeScript commands
- Dependency management
- Troubleshooting scripts
- CI/CD examples
- Performance profiling

**Best for:** Understanding all available commands and tools.

---

### INDEX.md
**Documentation Index (This File)**
- Complete documentation map
- Quick navigation
- File purposes
- Learning paths

**Best for:** Finding the right documentation for your needs.

---

## Configuration Files

### package.json
- Project metadata
- Dependencies (runtime)
- Dev dependencies
- Scripts (dev, build, preview, lint)

### tsconfig.json
- TypeScript compiler configuration
- Strict mode enabled
- Path aliases (@/ → ./src)
- ES2020 target

### tsconfig.node.json
- Node-specific TypeScript config
- For vite.config.ts compilation

### vite.config.ts
- Vite build configuration
- Dev server settings (port 5173)
- API proxy to localhost:8000
- WebSocket proxy
- Path aliases

### tailwind.config.js
- Tailwind CSS theme
- Dark mode configuration
- Custom colors (OneTrainer palette)
- Custom fonts

### postcss.config.js
- PostCSS configuration
- Tailwind CSS plugin
- Autoprefixer plugin

### index.html
- HTML entry point
- Root div
- Script tag for main.tsx
- Google Fonts link

---

## Source Code Structure

### Entry Points
- **src/main.tsx** - React application entry
- **src/App.tsx** - Main app component
- **src/index.css** - Global styles

### Components

#### UI Components (src/components/ui/)
- **button.tsx** - Button component
- **card.tsx** - Card container component
- **input.tsx** - Text input component
- **label.tsx** - Form label component
- **select.tsx** - Dropdown select component
- **switch.tsx** - Toggle switch component
- **tabs.tsx** - Tab navigation component

#### Layout Components (src/components/layout/)
- **Header.tsx** - Top navigation bar
- **TabNav.tsx** - Tab navigation
- **StatusBar.tsx** - Bottom status bar

#### Tab Components (src/components/tabs/)
- **TrainingTab.tsx** - Training configuration tab

### Library Files (src/lib/)
- **api.ts** - Axios API client
- **utils.ts** - Utility functions (cn helper)

### State Management (src/stores/)
- **configStore.ts** - Zustand global store

### Type Definitions (src/types/)
- **config.ts** - TypeScript interfaces

---

## Scripts

### Setup Scripts
- **setup.sh** - Initial project setup
- **verify-setup.sh** - Verify installation

### Package Scripts
- **npm run dev** - Start development server
- **npm run build** - Build for production
- **npm run preview** - Preview production build
- **npm run lint** - Lint TypeScript files

---

## Learning Paths

### For New Developers
1. Read **QUICKSTART.md** - Get started quickly
2. Run `./setup.sh` - Install dependencies
3. Run `npm run dev` - Start development
4. Read **UI_PREVIEW.md** - Understand the UI
5. Read **SCRIPTS.md** - Learn available commands

### For Frontend Developers
1. Read **SUMMARY.md** - Understand implementation
2. Read **README.md** - Full documentation
3. Read **STRUCTURE.md** - Understand file structure
4. Browse `src/` directory - See the code
5. Read **QUICKSTART.md** - Common patterns

### For Designers
1. Read **UI_PREVIEW.md** - Visual design guide
2. Browse `src/components/ui/` - UI components
3. Check `tailwind.config.js` - Theme colors
4. Check `src/index.css` - Global styles

### For DevOps/Deployment
1. Read **SCRIPTS.md** - Build and deployment
2. Check `vite.config.ts` - Build configuration
3. Check `package.json` - Dependencies
4. Read **README.md** - Environment setup

---

## Common Tasks

### I want to...

#### Start developing
→ Read [QUICKSTART.md](#quickstartmd)

#### Understand what was built
→ Read [SUMMARY.md](#summarymd)

#### Find a specific file
→ Read [STRUCTURE.md](#structuremd)

#### Learn the visual design
→ Read [UI_PREVIEW.md](#ui_previewmd)

#### Run npm commands
→ Read [SCRIPTS.md](#scriptsmd)

#### Add a new component
→ Read [QUICKSTART.md](#quickstartmd) section "Adding New Tabs"

#### Change colors/theme
→ Edit `tailwind.config.js` and check [UI_PREVIEW.md](#ui_previewmd)

#### Configure the build
→ Edit `vite.config.ts` and read [SCRIPTS.md](#scriptsmd)

#### Troubleshoot issues
→ Check [SCRIPTS.md](#scriptsmd) "Troubleshooting Scripts"

---

## File Locations

### Documentation
```
frontend/
├── QUICKSTART.md         - Quick start guide
├── SUMMARY.md            - Implementation summary
├── README.md             - Main documentation
├── STRUCTURE.md          - File structure
├── UI_PREVIEW.md         - Visual design guide
├── SCRIPTS.md            - Scripts reference
└── INDEX.md              - This file
```

### Configuration
```
frontend/
├── package.json          - Dependencies
├── tsconfig.json         - TypeScript config
├── tsconfig.node.json    - Node TypeScript config
├── vite.config.ts        - Vite config
├── tailwind.config.js    - Tailwind config
├── postcss.config.js     - PostCSS config
└── index.html            - HTML entry
```

### Source Code
```
frontend/src/
├── main.tsx              - Entry point
├── App.tsx               - Main component
├── index.css             - Global styles
├── components/           - React components
├── lib/                  - Library code
├── stores/               - State management
└── types/                - TypeScript types
```

---

## Help & Support

### Getting Help

1. **Setup Issues**: Check [SCRIPTS.md](#scriptsmd) troubleshooting
2. **Code Questions**: Check [QUICKSTART.md](#quickstartmd) examples
3. **Design Questions**: Check [UI_PREVIEW.md](#ui_previewmd)
4. **Build Issues**: Check [SCRIPTS.md](#scriptsmd) and `vite.config.ts`

### Resources

- **React Docs**: https://react.dev
- **TypeScript Docs**: https://www.typescriptlang.org
- **Vite Docs**: https://vitejs.dev
- **Tailwind Docs**: https://tailwindcss.com
- **shadcn/ui**: https://ui.shadcn.com
- **Radix UI**: https://www.radix-ui.com

---

## Version History

### Current Version: 1.0.0
- Complete React + TypeScript + Vite frontend
- 7 shadcn/ui components
- 3 layout components
- 1 example tab component
- Full API integration setup
- Dark theme with OneTrainer colors
- Complete documentation

---

## Contributing

When adding new features:

1. Create component in appropriate directory
2. Follow existing component patterns
3. Update relevant documentation
4. Add to [STRUCTURE.md](#structuremd) if new files
5. Update [SUMMARY.md](#summarymd) "What's Working" section

---

## Quick Reference Card

```
┌─────────────────────────────────────────┐
│ OneTrainer Frontend Quick Reference     │
├─────────────────────────────────────────┤
│                                         │
│ Setup:        ./setup.sh                │
│ Verify:       ./verify-setup.sh         │
│ Dev:          npm run dev               │
│ Build:        npm run build             │
│ Preview:      npm run preview           │
│ Lint:         npm run lint              │
│                                         │
│ Dev Server:   http://localhost:5173     │
│ Backend:      http://localhost:8000     │
│                                         │
│ Docs:         See INDEX.md              │
│ Quick Start:  See QUICKSTART.md         │
│ UI Guide:     See UI_PREVIEW.md         │
│                                         │
└─────────────────────────────────────────┘
```

---

**Last Updated**: December 2024
**Frontend Version**: 1.0.0
**React Version**: 18.3.1
**TypeScript Version**: 5.3.3
