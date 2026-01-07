# WebSocket System Architecture

## Component Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         OneTrainer                               │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    GenericTrainer                          │ │
│  │                         │                                   │ │
│  │                         ▼                                   │ │
│  │                  TrainCallbacks                            │ │
│  │         (on_update_train_progress, etc.)                   │ │
│  └─────────────────────────┬──────────────────────────────────┘ │
└────────────────────────────┼────────────────────────────────────┘
                             │
                             ▼
        ┌────────────────────────────────────────────┐
        │     TrainingWebSocketBridge               │
        │  - Converts sync callbacks to async       │
        │  - Throttles updates                      │
        │  - Calculates ETA                         │
        └──────────────┬─────────────────────────────┘
                       │
                       ▼
        ┌────────────────────────────────────────────┐
        │       EventBroadcaster                     │
        │  - Defines event types                     │
        │  - Broadcasts to ConnectionManager         │
        │  - Background system monitoring            │
        └──────────────┬─────────────────────────────┘
                       │
                       ▼
        ┌────────────────────────────────────────────┐
        │       ConnectionManager                    │
        │  - Manages WebSocket connections           │
        │  - Handles subscriptions                   │
        │  - Broadcasts to clients                   │
        └──────────────┬─────────────────────────────┘
                       │
                       ▼
        ┌────────────────────────────────────────────┐
        │       WebSocketHandler                     │
        │  - Routes incoming messages                │
        │  - Handles subscribe/unsubscribe           │
        │  - Processes commands                      │
        └──────────────┬─────────────────────────────┘
                       │
                       ▼
        ┌────────────────────────────────────────────┐
        │          WebSocket Clients                 │
        │  - JavaScript frontend                     │
        │  - Python clients                          │
        │  - Testing tools                           │
        └────────────────────────────────────────────┘
```

## Data Flow

### Training Progress Update Flow

```
1. GenericTrainer.train()
   │
   ├─> callbacks.on_update_train_progress(train_progress, max_step, max_epoch)
   │
   └─> TrainingWebSocketBridge.on_update_train_progress()
       │
       ├─> [Calculate ETA]
       ├─> [Throttle updates]
       └─> broadcaster.broadcast_training_progress()
           │
           └─> connection_manager.broadcast(event, EventType.TRAINING_PROGRESS)
               │
               ├─> [Filter by subscriptions]
               └─> websocket.send_json(event) [to each client]
```

### Sample Generation Flow

```
1. ModelSampler.sample()
   │
   ├─> callbacks.on_sample_default(sampler_output)
   │
   └─> TrainingWebSocketBridge.on_sample_default()
       │
       ├─> [Extract sample info]
       └─> broadcaster.broadcast_sample_generated()
           │
           └─> connection_manager.broadcast(event, EventType.SAMPLE_GENERATED)
               │
               └─> [Send to subscribed clients]
```

### Client Subscription Flow

```
1. Client connects to /ws
   │
   ├─> WebSocketHandler.handle_connection(websocket)
   │
   └─> connection_manager.connect(websocket)
       │
       ├─> [Generate client_id]
       ├─> [Store connection]
       └─> [Send welcome message]

2. Client sends subscribe message
   │
   ├─> handler._handle_subscribe(client_id, message)
   │
   └─> connection_manager.subscribe(client_id, event_types)
       │
       ├─> [Store subscriptions]
       └─> [Send confirmation]

3. Events are broadcast
   │
   └─> connection_manager.broadcast(message, event_type)
       │
       ├─> [Filter by subscriptions]
       └─> [Send to matching clients]
```

## Event Types and Their Sources

| Event Type          | Triggered By                        | Update Frequency  |
|---------------------|-------------------------------------|-------------------|
| training_progress   | Training step completion            | ~10 per second    |
| training_status     | Status changes in trainer           | On change         |
| sample_generated    | Sample creation                     | On completion     |
| log                 | Status updates, errors              | Variable          |
| system_stats        | Background monitoring task          | Every 2 seconds   |
| validation_result   | Validation run completion           | On completion     |

## Thread Safety

### Async Locks

The `ConnectionManager` uses async locks for thread-safe operations:

```python
async with self._lock:
    # Critical section
    self._connections[client_id] = websocket
```

### Sync-to-Async Bridge

The `TrainingWebSocketBridge` handles sync callbacks from OneTrainer:

```python
def on_update_train_progress(self, ...):  # Sync method
    self._run_async(                       # Convert to async
        self.broadcaster.broadcast_training_progress(...)
    )
```

## Subscription Model

Clients can subscribe to specific event types to reduce bandwidth:

```
Client A subscribes to: [training_progress, training_status]
Client B subscribes to: [sample_generated, system_stats]
Client C subscribes to: [log] (all logs)

Event: training_progress
  ✓ Sent to Client A
  ✗ Not sent to Client B
  ✗ Not sent to Client C

Event: sample_generated
  ✗ Not sent to Client A
  ✓ Sent to Client B
  ✗ Not sent to Client C
```

## Error Handling Strategy

### Graceful Degradation

```
WebSocket disconnects → ConnectionManager removes client
                      → Training continues unaffected

Broadcast fails      → Log error
                     → Remove failed client
                     → Continue broadcasting to others

Message parsing fails → Send error to client
                      → Continue processing next message
```

### Exception Boundaries

```python
# All critical operations wrapped in try-except
try:
    await websocket.send_json(message)
except WebSocketDisconnect:
    await self.disconnect(client_id)
except Exception as e:
    logger.error(f"Error: {e}")
    await self.disconnect(client_id)
```

## Performance Optimizations

### 1. Update Throttling

```python
# Limit progress updates to 10 per second
if current_time - self._last_progress_time < 0.1:
    return
```

### 2. Subscription Filtering

Only send events to subscribed clients:

```python
if event_type in self._subscriptions.get(client_id, set()):
    await websocket.send_json(message)
```

### 3. Async I/O

All network operations are async, preventing blocking:

```python
async def broadcast(self, message):
    for client_id, websocket in self._connections.items():
        await websocket.send_json(message)  # Non-blocking
```

### 4. Background Monitoring

System stats collection runs in background task:

```python
async def _monitor_system_stats(self):
    while self._is_monitoring:
        stats = self._collect_system_stats()
        await self.broadcast_system_stats(**stats)
        await asyncio.sleep(2.0)  # Non-blocking delay
```

## Message Format

All WebSocket messages follow this structure:

```json
{
  "type": "event_type",
  "timestamp": "ISO-8601 timestamp",
  ... event-specific fields ...
}
```

This allows clients to:
1. Route messages by type
2. Order events chronologically
3. Handle unknown event types gracefully

## Scaling Considerations

### Current Design

- Single server instance
- In-memory connection storage
- Direct WebSocket connections

### Future Scaling

For production deployments with multiple servers:

1. **Redis Pub/Sub** for cross-server broadcasting
2. **Sticky sessions** for WebSocket connections
3. **Connection pooling** for database connections
4. **Message queues** for reliable delivery
5. **Load balancer** with WebSocket support

## Security Considerations

### Current Implementation

- No authentication (development)
- No encryption (use wss:// in production)
- No rate limiting
- No input validation (basic validation only)

### Production Requirements

1. **Authentication**: JWT tokens or session-based auth
2. **Authorization**: Role-based access control
3. **Encryption**: WSS (WebSocket Secure)
4. **Rate Limiting**: Per-client message rate limits
5. **Input Validation**: Strict message validation
6. **CORS**: Proper CORS configuration

## Testing Strategy

### Unit Tests

- Individual component functionality
- Mock WebSocket connections
- Event serialization

### Integration Tests

- Full component interaction
- Real WebSocket connections (test server)
- End-to-end message flow

### Load Tests

- Multiple concurrent connections
- High-frequency updates
- Memory usage monitoring

## Monitoring and Debugging

### Logging Levels

- **DEBUG**: Message routing, subscriptions
- **INFO**: Connections, disconnections, events
- **WARNING**: Failed sends, invalid messages
- **ERROR**: Exceptions, crashes

### Metrics to Track

- Active connections count
- Messages sent per second
- Average message latency
- Error rate per client
- Memory usage
- WebSocket frame size

### Debug Tools

1. Browser DevTools (Network → WS)
2. WebSocket testing tools (Postman, wscat)
3. Custom logging in handlers
4. `/api/ws/status` endpoint

## File Structure

```
web_ui/backend/ws/
├── __init__.py              # Package exports
├── connection_manager.py    # Connection management
├── handlers.py              # Message routing
├── events.py                # Event definitions
├── training_bridge.py       # OneTrainer integration
├── example_integration.py   # FastAPI example
├── test_websocket.py        # Unit tests
├── README.md                # Usage documentation
└── ARCHITECTURE.md          # This file
```

## Dependencies

```
fastapi          # Web framework
websockets       # WebSocket protocol
torch            # GPU stats
psutil           # System stats
asyncio          # Async operations
dataclasses      # Event structures
```

## Future Enhancements

1. **Reconnection Support**: Client-side automatic reconnection
2. **Event Replay**: Send recent events to new connections
3. **Compression**: Gzip compression for large messages
4. **Binary Protocol**: Protocol buffers for efficiency
5. **Multi-room**: Separate channels for multiple trainings
6. **Command System**: Pause/resume/stop via WebSocket
7. **Authentication**: Secure access control
8. **Persistence**: Store events in database
