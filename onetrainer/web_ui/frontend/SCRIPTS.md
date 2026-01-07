# Available Scripts

## Package Scripts (npm/yarn)

### Development

```bash
npm run dev
```
Starts the Vite development server with:
- Hot Module Replacement (HMR)
- Fast refresh for React components
- TypeScript type checking in background
- Available at `http://localhost:5173`
- API proxy to `http://localhost:8000/api`
- WebSocket proxy to `ws://localhost:8000/ws`

### Production Build

```bash
npm run build
```
Builds the app for production:
1. Runs TypeScript compiler (`tsc`) for type checking
2. Builds optimized bundle with Vite
3. Outputs to `dist/` directory
4. Minified and tree-shaken code
5. Source maps included

### Preview Production Build

```bash
npm run preview
```
Serves the production build locally for testing:
- Runs local server with production bundle
- Available at `http://localhost:4173` (default)
- Use to verify production build before deployment

### Linting

```bash
npm run lint
```
Runs ESLint on TypeScript/TSX files:
- Checks `src/**/*.{ts,tsx}` files
- Uses TypeScript ESLint parser
- Reports code quality issues

## Custom Scripts

### Setup Script

```bash
./setup.sh
```
Automated setup script that:
1. Checks Node.js version (requires 18+)
2. Installs all dependencies
3. Removes old JavaScript files (if migrating)
4. Provides next steps

### Verification Script

```bash
./verify-setup.sh
```
Verifies frontend setup by checking:
- Node.js and npm installation
- All TypeScript files exist
- All component files exist
- All library files exist
- Dependencies installation status
- Provides green/red checkmarks for each item

## Quick Commands Reference

### First Time Setup
```bash
# Clone/navigate to project
cd /home/alex/OneTrainer/web_ui/frontend

# Run setup script
./setup.sh

# Or manually install
npm install

# Verify setup
./verify-setup.sh

# Start development
npm run dev
```

### Daily Development
```bash
# Start dev server
npm run dev

# In another terminal, start backend
cd /home/alex/OneTrainer
python start.py --web-ui
```

### Before Committing
```bash
# Check for linting issues
npm run lint

# Build to verify production works
npm run build

# Test production build
npm run preview
```

### Cleaning

```bash
# Remove dependencies
rm -rf node_modules

# Remove build output
rm -rf dist

# Remove lock file (if needed)
rm package-lock.json

# Reinstall everything
npm install
```

## Environment Variables

Create a `.env.local` file for local overrides:

```env
# API URL (default: /api via proxy)
VITE_API_URL=http://localhost:8000/api

# WebSocket URL (default: /ws via proxy)
VITE_WS_URL=ws://localhost:8000/ws

# Enable debug mode
VITE_DEBUG=true
```

Access in code:
```typescript
const apiUrl = import.meta.env.VITE_API_URL;
```

## Port Configuration

### Change Dev Server Port

Edit `vite.config.ts`:
```typescript
export default defineConfig({
  server: {
    port: 3000, // Change to your preferred port
    ...
  },
});
```

### Change Preview Port

```bash
npm run preview -- --port 4000
```

## Build Options

### Build for Different Environments

```bash
# Development build (with source maps)
npm run build

# Production build (optimized)
NODE_ENV=production npm run build

# Build with custom base path
npm run build -- --base=/onetrainer/
```

## TypeScript

### Type Checking Only

```bash
npx tsc --noEmit
```
Runs TypeScript compiler in check-only mode (no output).

### Watch Mode

```bash
npx tsc --noEmit --watch
```
Continuously checks types as you edit.

## Dependency Management

### Install New Dependency

```bash
npm install <package-name>
```

### Install Dev Dependency

```bash
npm install -D <package-name>
```

### Update Dependencies

```bash
# Update all to latest within semver
npm update

# Update to latest major versions (careful!)
npx npm-check-updates -u
npm install
```

### Check for Outdated

```bash
npm outdated
```

## Useful Development Commands

### Clear Vite Cache

```bash
rm -rf node_modules/.vite
npm run dev
```

### Analyze Bundle Size

```bash
npm run build
npx vite-bundle-visualizer
```

### Format Code (if Prettier installed)

```bash
npx prettier --write "src/**/*.{ts,tsx}"
```

## Troubleshooting Scripts

### Fix Permission Issues

```bash
chmod +x setup.sh
chmod +x verify-setup.sh
```

### Rebuild from Scratch

```bash
rm -rf node_modules dist package-lock.json
npm install
npm run dev
```

### Check Node/npm Versions

```bash
node -v   # Should be 18+
npm -v    # Should be 9+
```

## CI/CD Scripts (Future)

For GitHub Actions or similar:

```yaml
# Install dependencies
npm ci

# Run tests (when added)
npm test

# Build
npm run build

# Deploy
# Copy dist/ to web server
```

## Performance Profiling

```bash
# Build with profiling
npm run build -- --profile

# Analyze build time
VITE_PROFILE=true npm run build
```

## Debug Mode

```bash
# Start with debugging
DEBUG=vite:* npm run dev

# Node debugging
node --inspect node_modules/.bin/vite
```

## Summary

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `npm run dev` | Development server | Daily development |
| `npm run build` | Production build | Before deployment |
| `npm run preview` | Test production | Verify builds |
| `npm run lint` | Check code quality | Before commits |
| `./setup.sh` | Initial setup | First time only |
| `./verify-setup.sh` | Verify setup | After setup/changes |

## Next Steps

1. Run `./setup.sh` for first-time setup
2. Run `npm run dev` to start development
3. Open `http://localhost:5173` in browser
4. Make changes and see them hot-reload instantly!
