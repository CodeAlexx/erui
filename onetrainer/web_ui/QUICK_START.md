# OneTrainer Web UI - Quick Start Guide

## Installation

```bash
# Install dependencies
pip install fastapi uvicorn[standard] websockets psutil pydantic

# Or use requirements file
pip install -r web_ui/requirements.txt
```

## Running the Server

```bash
# From OneTrainer root directory

# Recommended: Using startup script (checks dependencies)
chmod +x web_ui/start_server.sh
./web_ui/start_server.sh

# Alternative: Direct Python
python web_ui/run.py
```

Server will start at: **http://localhost:8000**

## Quick Test

```bash
# Test imports
python web_ui/test_imports.py

# Access API documentation
# Open browser: http://localhost:8000/docs
```

## API Endpoints

### Training Control
```bash
# Get status
curl http://localhost:8000/api/training/status

# Stop training
curl -X POST http://localhost:8000/api/training/stop

# Create backup
curl -X POST http://localhost:8000/api/training/backup
```

### Configuration
```bash
# List presets
curl http://localhost:8000/api/config/presets

# Get current config
curl http://localhost:8000/api/config/current
```

### Samples
```bash
# List samples
curl http://localhost:8000/api/samples

# Generate default sample
curl -X POST http://localhost:8000/api/samples/generate/default
```

### System Info
```bash
# System information
curl http://localhost:8000/api/system/info

# Resource usage
curl http://localhost:8000/api/system/resources
```

## WebSocket Connection

```javascript
const ws = new WebSocket('ws://localhost:8000/ws');

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Update:', data);
};
```

## File Structure

```
web_ui/
├── backend/
│   ├── main.py              # FastAPI app
│   ├── api/                 # REST endpoints
│   │   ├── training.py      # Training control
│   │   ├── config.py        # Configuration
│   │   ├── samples.py       # Sample generation
│   │   └── system.py        # System info
│   ├── services/
│   │   └── trainer_service.py  # Singleton trainer manager
│   └── ws/                  # WebSocket handlers
├── run.py                   # Entry point
├── test_imports.py          # Test script
├── start_server.sh          # Startup script
└── requirements.txt         # Dependencies
```

## Key Features

✅ Real-time training updates via WebSocket
✅ RESTful API for all operations
✅ Thread-safe singleton trainer service
✅ Automatic state broadcasting
✅ System monitoring
✅ Sample generation
✅ Configuration management

## Documentation

- **README.md** - Full documentation
- **API_REFERENCE.md** - Complete API reference
- **IMPLEMENTATION_SUMMARY.md** - Technical details
- **QUICK_START.md** - This file

## Troubleshooting

### Import Errors
```bash
# Verify imports work
python web_ui/test_imports.py
```

### Port Already in Use
```bash
# Change port in web_ui/run.py
# Default is 8000, try 8001, 8080, etc.
```

### Can't Connect
- Check firewall settings
- Verify server is running: `ps aux | grep uvicorn`
- Check logs for errors

## Next Steps

1. Start the server
2. Open API docs: http://localhost:8000/docs
3. Test endpoints via Swagger UI
4. Connect WebSocket client
5. Build frontend application

## Support

For issues:
1. Check console output for errors
2. Review logs
3. Run test_imports.py
4. Check OneTrainer root directory location
