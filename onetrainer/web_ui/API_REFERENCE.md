# OneTrainer Web UI API Reference

## Base URL
```
http://localhost:8000
```

## WebSocket Connection
```
ws://localhost:8000/ws
```

---

## Training Endpoints

### GET /api/training/status
Get current training status and state.

**Response:**
```json
{
  "is_training": false,
  "status": "idle",
  "progress": null,
  "max_step": 0,
  "max_epoch": 0,
  "error": null
}
```

### POST /api/training/start
Start a new training session.

**Request:**
```json
{
  "config_path": "/path/to/config.json",
  "config_dict": null
}
```

**Response:**
```json
{
  "success": true,
  "message": "Training started"
}
```

### POST /api/training/stop
Stop the current training session.

**Response:**
```json
{
  "success": true,
  "message": "Stop command sent"
}
```

### POST /api/training/backup
Create a backup of the current training state.

**Response:**
```json
{
  "success": true,
  "message": "Backup command sent"
}
```

### POST /api/training/save
Save the current model.

**Response:**
```json
{
  "success": true,
  "message": "Save command sent"
}
```

### GET /api/training/progress
Get detailed training progress.

**Response:**
```json
{
  "is_training": true,
  "progress": {
    "epoch": 1,
    "epoch_step": 100,
    "epoch_sample": 800,
    "global_step": 1100
  },
  "max_step": 10000,
  "max_epoch": 10
}
```

---

## Configuration Endpoints

### GET /api/config/current
Get the current training configuration.

**Response:**
```json
{
  "config": {
    "model_type": "stable_diffusion",
    "learning_rate": 0.0001,
    ...
  }
}
```

### GET /api/config/list
List available configuration files.

**Response:**
```json
{
  "configs": [
    "sd_lora_config.json",
    "flux_full_finetune.json"
  ]
}
```

### GET /api/config/load/{config_name}
Load a configuration file by name.

**Parameters:**
- `config_name`: Name of config file (without .json)

**Response:**
```json
{
  "model_type": "stable_diffusion",
  "learning_rate": 0.0001,
  ...
}
```

### POST /api/config/validate
Validate a training configuration.

**Request:**
```json
{
  "model_type": "stable_diffusion",
  "learning_rate": 0.0001,
  ...
}
```

**Response:**
```json
{
  "valid": true,
  "errors": [],
  "warnings": [
    "Learning rate is higher than recommended"
  ]
}
```

### GET /api/config/schema
Get the JSON schema for configurations.

**Response:**
```json
{
  "type": "object",
  "properties": {
    "model_type": {"type": "string", ...},
    "learning_rate": {"type": "number", ...},
    ...
  }
}
```

### GET /api/config/defaults
Get default configuration values.

**Response:**
```json
{
  "model_type": "stable_diffusion",
  "learning_rate": 0.0001,
  ...
}
```

---

## Sample Generation Endpoints

### POST /api/samples/default
Generate samples using default configuration.

**Response:**
```json
{
  "success": true,
  "message": "Default sample generation requested"
}
```

### POST /api/samples/custom
Generate a custom sample with specific parameters.

**Request:**
```json
{
  "prompt": "a beautiful landscape",
  "negative_prompt": "blurry, low quality",
  "seed": 42,
  "steps": 30,
  "cfg_scale": 7.5,
  "width": 512,
  "height": 512
}
```

**Response:**
```json
{
  "success": true,
  "message": "Custom sample generation requested"
}
```

### GET /api/samples/list
List all generated samples.

**Response:**
```json
{
  "samples": [
    {
      "id": "sample_001",
      "timestamp": "2024-01-01T12:00:00",
      "path": "/path/to/sample.png",
      "metadata": {...}
    }
  ]
}
```

### GET /api/samples/latest?count=10
Get the most recent samples.

**Parameters:**
- `count`: Number of samples to return (default: 10)

**Response:**
```json
{
  "samples": [...]
}
```

### GET /api/samples/{sample_id}
Get a specific sample by ID.

**Response:**
```json
{
  "id": "sample_001",
  "timestamp": "2024-01-01T12:00:00",
  "path": "/path/to/sample.png",
  "metadata": {
    "prompt": "...",
    "seed": 42,
    ...
  }
}
```

---

## System Information Endpoints

### GET /api/system/info
Get system information.

**Response:**
```json
{
  "os": {
    "system": "Linux",
    "release": "5.15.0",
    "version": "...",
    "machine": "x86_64",
    "processor": "AMD Ryzen 9"
  },
  "cpu": {
    "count": 16,
    "usage_percent": 25.5
  },
  "memory": {
    "total_gb": 64.0,
    "used_gb": 32.5,
    "available_gb": 31.5,
    "usage_percent": 50.8
  },
  "disk": {
    "total_gb": 1000.0,
    "used_gb": 500.0,
    "free_gb": 500.0,
    "usage_percent": 50.0
  },
  "gpu": {
    "available": true,
    "count": 1,
    "devices": [
      {
        "id": 0,
        "name": "NVIDIA GeForce RTX 4090",
        "memory_total_gb": 24.0,
        "memory_allocated_gb": 8.5,
        "memory_reserved_gb": 10.0
      }
    ]
  }
}
```

### GET /api/system/resources
Get current resource usage.

**Response:**
```json
{
  "cpu_percent": 45.2,
  "memory_percent": 60.5,
  "disk_percent": 50.0,
  "gpu_memory": [
    {
      "device": 0,
      "allocated_percent": 35.4,
      "reserved_percent": 41.7
    }
  ]
}
```

### GET /api/system/processes
Get information about the OneTrainer process.

**Response:**
```json
{
  "pid": 12345,
  "cpu_percent": 125.5,
  "memory_percent": 15.2,
  "memory_mb": 9728.5,
  "num_threads": 24,
  "status": "running"
}
```

---

## WebSocket Events

### Client → Server

#### Ping
```
"ping"
```

### Server → Client

#### Connection Established
```json
{
  "type": "connected",
  "data": {
    "is_training": false,
    "status": "idle",
    ...
  }
}
```

#### Pong
```json
{
  "type": "pong"
}
```

#### Training State Update
```json
{
  "type": "training_state",
  "data": {
    "is_training": true,
    "status": "running",
    "progress": {
      "epoch": 1,
      "epoch_step": 100,
      "epoch_sample": 800,
      "global_step": 1100
    },
    "max_step": 10000,
    "max_epoch": 10,
    "error": null
  }
}
```

#### Default Sample Generated
```json
{
  "type": "sample_default",
  "data": {
    "sample_count": 4
  }
}
```

#### Default Sample Progress
```json
{
  "type": "sample_default_progress",
  "data": {
    "current": 2,
    "total": 4
  }
}
```

#### Custom Sample Generated
```json
{
  "type": "sample_custom",
  "data": {
    "sample_count": 1
  }
}
```

#### Custom Sample Progress
```json
{
  "type": "sample_custom_progress",
  "data": {
    "current": 1,
    "total": 1
  }
}
```

---

## Error Responses

All endpoints may return error responses in this format:

```json
{
  "detail": "Error message describing what went wrong"
}
```

### Common HTTP Status Codes
- `200 OK` - Successful request
- `400 Bad Request` - Invalid request parameters
- `404 Not Found` - Resource not found
- `500 Internal Server Error` - Server error
- `501 Not Implemented` - Feature not yet implemented

---

## Example Usage

### JavaScript/TypeScript

```javascript
// Fetch training status
const response = await fetch('http://localhost:8000/api/training/status');
const status = await response.json();
console.log(status);

// Start training
await fetch('http://localhost:8000/api/training/start', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    config_path: '/path/to/config.json'
  })
});

// WebSocket connection
const ws = new WebSocket('ws://localhost:8000/ws');
ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Received:', data);
};
```

### Python

```python
import requests
import json

# Fetch training status
response = requests.get('http://localhost:8000/api/training/status')
status = response.json()
print(status)

# Start training
response = requests.post(
    'http://localhost:8000/api/training/start',
    json={'config_path': '/path/to/config.json'}
)
result = response.json()
print(result)

# WebSocket (using websockets library)
import asyncio
import websockets

async def monitor_training():
    async with websockets.connect('ws://localhost:8000/ws') as ws:
        async for message in ws:
            data = json.loads(message)
            print('Received:', data)

asyncio.run(monitor_training())
```

### cURL

```bash
# Get training status
curl http://localhost:8000/api/training/status

# Start training
curl -X POST http://localhost:8000/api/training/start \
  -H "Content-Type: application/json" \
  -d '{"config_path": "/path/to/config.json"}'

# Stop training
curl -X POST http://localhost:8000/api/training/stop

# Get system info
curl http://localhost:8000/api/system/info
```
