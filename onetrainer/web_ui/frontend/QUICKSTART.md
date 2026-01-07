# Quick Start Guide

## Installation

1. Make sure you have Node.js 18+ installed:
   ```bash
   node -v  # Should be v18 or higher
   ```

2. Run the setup script:
   ```bash
   ./setup.sh
   ```

   Or manually:
   ```bash
   npm install
   ```

## Development

Start the development server:
```bash
npm run dev
```

The app will open at `http://localhost:5173`

## Project Overview

### Main Components

- **App.tsx** - Main application component with tab routing
- **Header.tsx** - Top bar with preset selector and actions
- **TabNav.tsx** - Tab navigation bar
- **StatusBar.tsx** - Bottom status bar with training controls
- **TrainingTab.tsx** - Example tab content (training settings)

### Key Features

1. **Tab Navigation** - Switch between different configuration sections
2. **Preset Management** - Load/save training presets
3. **Training Controls** - Start/stop/pause training
4. **Status Display** - Real-time training progress and metrics

### Adding New Tabs

1. Create a new component in `src/components/tabs/`
2. Import it in `App.tsx`
3. Add it to the `renderTabContent()` switch statement

Example:
```typescript
// src/components/tabs/ModelTab.tsx
export function ModelTab() {
  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Model Configuration</CardTitle>
        </CardHeader>
        <CardContent>
          {/* Your form fields here */}
        </CardContent>
      </Card>
    </div>
  );
}
```

Then in App.tsx:
```typescript
case 'model':
  return <ModelTab />;
```

### Using shadcn/ui Components

All components are in `src/components/ui/`:

```typescript
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';

<Card>
  <CardHeader>
    <CardTitle>Example</CardTitle>
  </CardHeader>
  <CardContent>
    <Label>Name</Label>
    <Input placeholder="Enter name..." />
    <Button variant="primary">Submit</Button>
  </CardContent>
</Card>
```

### State Management

Using Zustand store (`src/stores/configStore.ts`):

```typescript
import { useConfigStore } from '@/stores/configStore';

function MyComponent() {
  const config = useConfigStore((state) => state.config);
  const updateConfig = useConfigStore((state) => state.updateConfig);
  
  return (
    <Input 
      value={config.learning_rate}
      onChange={(e) => updateConfig({ learning_rate: parseFloat(e.target.value) })}
    />
  );
}
```

### API Calls

Using the API client (`src/lib/api.ts`):

```typescript
import { trainingApi, configApi, filesystemApi } from '@/lib/api';

// Get training status
const { data } = await trainingApi.getStatus();

// Start training
await trainingApi.start(config);

// Load presets
const { data: presets } = await configApi.getPresets();
```

### Styling

Using Tailwind CSS with custom theme colors:

```typescript
<div className="bg-dark-surface border border-dark-border rounded-lg p-4">
  <h2 className="text-primary font-semibold">Title</h2>
  <p className="text-gray-400">Description</p>
</div>
```

Custom colors available:
- `bg-dark-bg` - Main background (#1a1a2e)
- `bg-dark-surface` - Card/panel background (#252541)
- `border-dark-border` - Border color (#3a3a52)
- `bg-dark-hover` - Hover state (#2d2d43)
- `text-primary` - Accent color (#22b8cf)

## Building for Production

```bash
npm run build
```

Output will be in the `dist/` directory.

## Troubleshooting

### Port already in use
If port 5173 is already in use, you can change it in `vite.config.ts`:
```typescript
server: {
  port: 3000, // Change to your preferred port
  ...
}
```

### Module not found errors
Make sure all dependencies are installed:
```bash
rm -rf node_modules package-lock.json
npm install
```

### TypeScript errors
Check your `tsconfig.json` and make sure all paths are correct.
