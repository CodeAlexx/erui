# WebSocket Quick Start Guide

Get up and running with OneTrainer WebSocket real-time updates in 5 minutes.

## 1. Test the System (Standalone)

Run the example server to test WebSocket functionality:

```bash
# From OneTrainer root directory
cd web_ui/backend/ws
python example_integration.py
```

This starts a test server on `http://localhost:8000` with:
- WebSocket endpoint: `ws://localhost:8000/ws`
- Status endpoint: `http://localhost:8000/api/ws/status`

## 2. Test with Browser Console

Open your browser console and run:

```javascript
// Connect to WebSocket
const ws = new WebSocket('ws://localhost:8000/ws');

// Handle connection
ws.onopen = () => {
    console.log('Connected!');

    // Subscribe to events
    ws.send(JSON.stringify({
        type: 'subscribe',
        events: ['training_progress', 'training_status', 'system_stats']
    }));
};

// Handle messages
ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    console.log('Received:', data.type, data);
};
```

You should see:
1. Connection established message
2. Subscription confirmation
3. System stats updates every 2 seconds (if GPU available)

## 3. Integrate with OneTrainer

### Option A: New Training Session

```python
from web_ui.backend.ws import (
    ConnectionManager,
    EventBroadcaster,
    TrainingWebSocketBridge,
    set_event_broadcaster,
)
from modules.trainer.GenericTrainer import GenericTrainer

# Initialize WebSocket components
connection_manager = ConnectionManager()
event_broadcaster = EventBroadcaster(connection_manager)
training_bridge = TrainingWebSocketBridge(event_broadcaster)

# Set global broadcaster
set_event_broadcaster(event_broadcaster)

# Start monitoring
await event_broadcaster.start_monitoring()

# Create callbacks
callbacks = training_bridge.create_train_callbacks()

# Create trainer with WebSocket callbacks
trainer = GenericTrainer(
    config=config,
    callbacks=callbacks,  # Use WebSocket-enabled callbacks
    commands=commands,
)

# Start training - updates will be broadcast automatically
trainer.start()
```

### Option B: Add to Existing Callbacks

```python
from modules.util.callbacks.TrainCallbacks import TrainCallbacks
from web_ui.backend.ws import TrainingWebSocketBridge, EventBroadcaster

# Your existing callbacks
callbacks = TrainCallbacks(
    on_update_train_progress=your_progress_handler,
    on_update_status=your_status_handler,
)

# Add WebSocket broadcasting
event_broadcaster = EventBroadcaster(connection_manager)
training_bridge = TrainingWebSocketBridge(event_broadcaster)
training_bridge.update_existing_callbacks(callbacks)

# Now callbacks will both call your handlers AND broadcast to WebSocket
```

## 4. Add WebSocket Endpoint to FastAPI

If you already have a FastAPI app:

```python
from fastapi import FastAPI, WebSocket
from web_ui.backend.ws import ConnectionManager, WebSocketHandler

app = FastAPI()

# Create WebSocket components (share these globally)
connection_manager = ConnectionManager()
ws_handler = WebSocketHandler(connection_manager)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time updates."""
    await ws_handler.handle_connection(websocket)

@app.get("/api/ws/status")
async def ws_status():
    """Get WebSocket system status."""
    return {
        "active_connections": connection_manager.get_connection_count(),
        "is_training": event_broadcaster.get_training_state()["status"] != "idle"
    }
```

## 5. Frontend Integration

### HTML

```html
<!DOCTYPE html>
<html>
<head>
    <title>OneTrainer Monitor</title>
    <style>
        .status-running { color: green; }
        .status-error { color: red; }
        #progress-bar { width: 0%; height: 20px; background: blue; }
    </style>
</head>
<body>
    <h1>OneTrainer Real-Time Monitor</h1>

    <div id="status-indicator">Status: <span id="status">Disconnected</span></div>
    <div id="progress-bar"></div>
    <div id="progress-text">0 / 0</div>
    <div id="loss">Loss: -</div>
    <div id="eta">ETA: -</div>

    <div id="logs"></div>

    <script src="monitor.js"></script>
</body>
</html>
```

### JavaScript (monitor.js)

```javascript
const ws = new WebSocket('ws://localhost:8000/ws');

ws.onopen = () => {
    document.getElementById('status').textContent = 'Connected';

    ws.send(JSON.stringify({
        type: 'subscribe',
        events: ['training_progress', 'training_status', 'log']
    }));
};

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);

    switch(data.type) {
        case 'training_progress':
            const progress = (data.global_step / (data.max_step * data.max_epoch)) * 100;
            document.getElementById('progress-bar').style.width = progress + '%';
            document.getElementById('progress-text').textContent =
                `${data.global_step} / ${data.max_step * data.max_epoch}`;

            if (data.loss) {
                document.getElementById('loss').textContent =
                    `Loss: ${data.loss.toFixed(4)}`;
            }

            if (data.eta_seconds) {
                const hours = Math.floor(data.eta_seconds / 3600);
                const mins = Math.floor((data.eta_seconds % 3600) / 60);
                document.getElementById('eta').textContent =
                    `ETA: ${hours}h ${mins}m`;
            }
            break;

        case 'training_status':
            const statusElem = document.getElementById('status');
            statusElem.textContent = data.status;
            statusElem.className = 'status-' + data.status;
            break;

        case 'log':
            const logDiv = document.getElementById('logs');
            const logEntry = document.createElement('div');
            logEntry.textContent = `[${data.level}] ${data.message}`;
            logDiv.appendChild(logEntry);
            logDiv.scrollTop = logDiv.scrollHeight;
            break;
    }
};

ws.onclose = () => {
    document.getElementById('status').textContent = 'Disconnected';
};
```

## 6. Testing

### Run Unit Tests

```bash
# Install pytest if needed
pip install pytest pytest-asyncio

# Run tests
pytest web_ui/backend/ws/test_websocket.py -v
```

### Manual Testing

1. Start the example server
2. Open multiple browser tabs
3. Each tab connects and subscribes
4. Verify all tabs receive updates
5. Close some tabs, verify others continue working

## 7. Common Use Cases

### Monitor Training Progress

```javascript
ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    if (data.type === 'training_progress') {
        updateChart(data.global_step, data.loss);
        updateProgressBar(data.global_step, data.max_step * data.max_epoch);
    }
};
```

### Display Generated Samples

```javascript
ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    if (data.type === 'sample_generated') {
        const img = document.createElement('img');
        img.src = data.path;
        img.alt = data.prompt;
        document.getElementById('gallery').appendChild(img);
    }
};
```

### Real-Time Logs

```javascript
ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    if (data.type === 'log') {
        addLogEntry(data.level, data.message, data.timestamp);
    }
};
```

### System Resource Monitoring

```javascript
ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    if (data.type === 'system_stats') {
        updateGPUChart(data.gpu_memory_used_gb, data.gpu_memory_total_gb);
        updateCPUChart(data.cpu_percent);
    }
};
```

## 8. Troubleshooting

### Connection Refused

```bash
# Check if server is running
curl http://localhost:8000/api/ws/status

# Check WebSocket endpoint
wscat -c ws://localhost:8000/ws
```

### No Events Received

1. Verify subscription:
```javascript
ws.send(JSON.stringify({
    type: 'subscribe',
    events: ['training_progress']
}));
```

2. Check server logs for errors
3. Verify event broadcaster is started:
```python
await event_broadcaster.start_monitoring()
```

### High Memory Usage

1. Reduce monitoring interval:
```python
event_broadcaster._monitor_interval = 5.0  # seconds
```

2. Limit event history:
```python
# Don't store events, just broadcast
```

3. Disconnect unused clients

## 9. Production Checklist

Before deploying to production:

- [ ] Add authentication (JWT/sessions)
- [ ] Use WSS (secure WebSocket)
- [ ] Configure CORS properly
- [ ] Add rate limiting
- [ ] Set up logging/monitoring
- [ ] Test with multiple clients
- [ ] Test reconnection logic
- [ ] Add error recovery
- [ ] Configure reverse proxy (nginx)
- [ ] Test under load

## 10. Next Steps

- Read [README.md](README.md) for detailed documentation
- Read [ARCHITECTURE.md](ARCHITECTURE.md) for system design
- Check [example_integration.py](example_integration.py) for complete example
- Run [test_websocket.py](test_websocket.py) to verify installation

## Support

For issues or questions:
1. Check the logs
2. Review the README and ARCHITECTURE docs
3. Run the tests to verify setup
4. Check OneTrainer's main documentation

## Example: Complete Minimal Setup

```python
# server.py
from fastapi import FastAPI, WebSocket
from web_ui.backend.ws import (
    ConnectionManager, WebSocketHandler,
    EventBroadcaster, set_event_broadcaster
)

app = FastAPI()
connection_manager = ConnectionManager()
event_broadcaster = EventBroadcaster(connection_manager)
ws_handler = WebSocketHandler(connection_manager)
set_event_broadcaster(event_broadcaster)

@app.on_event("startup")
async def startup():
    await event_broadcaster.start_monitoring()

@app.on_event("shutdown")
async def shutdown():
    await event_broadcaster.stop_monitoring()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await ws_handler.handle_connection(websocket)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

```html
<!-- client.html -->
<!DOCTYPE html>
<html>
<body>
    <div id="output"></div>
    <script>
        const ws = new WebSocket('ws://localhost:8000/ws');
        ws.onopen = () => ws.send(JSON.stringify({
            type: 'subscribe',
            events: ['system_stats']
        }));
        ws.onmessage = (e) => {
            const data = JSON.parse(e.data);
            document.getElementById('output').innerHTML +=
                JSON.stringify(data, null, 2) + '<br><br>';
        };
    </script>
</body>
</html>
```

That's it! You now have real-time WebSocket updates for OneTrainer.
