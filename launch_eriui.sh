#!/bin/bash
# EriUI Full Launch Script
# Starts ComfyUI backend + EriUI server + Flutter app

ERIUI_DIR="/home/alex/eriui"
FLUTTER_DIR="/home/alex/flutter"
COMFY_PORT=8199
SERVER_PORT=7803

# Add Flutter/Dart to PATH
export PATH="$FLUTTER_DIR/bin:$PATH"

echo "=========================================="
echo "         EriUI Launch Script"
echo "=========================================="

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "Shutting down EriUI..."
    pkill -f "main.py --port $COMFY_PORT" 2>/dev/null
    pkill -f "dart.*server.dart" 2>/dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM

# Start ComfyUI in background
echo "[1/3] Starting ComfyUI on port $COMFY_PORT..."
cd "$ERIUI_DIR/comfyui/ComfyUI"
source venv/bin/activate
python main.py --port $COMFY_PORT --listen 0.0.0.0 &
COMFY_PID=$!

# Wait for ComfyUI to be ready
echo "Waiting for ComfyUI to start..."
for i in {1..30}; do
    if curl -s "http://localhost:$COMFY_PORT/system_stats" > /dev/null 2>&1; then
        echo "ComfyUI ready!"
        break
    fi
    sleep 1
done

# Start EriUI server
echo "[2/3] Starting EriUI server on port $SERVER_PORT..."
cd "$ERIUI_DIR"
dart run bin/server.dart --port=$SERVER_PORT --comfy-url=http://localhost:$COMFY_PORT &
SERVER_PID=$!
sleep 3

# Start Flutter app (optional - comment out if you want to run separately)
echo "[3/3] Starting EriUI Flutter app..."
cd "$ERIUI_DIR/flutter_app"
rm -f /home/alex/Documents/eriui_storage.lock
flutter run -d linux &

echo ""
echo "=========================================="
echo "EriUI is running!"
echo "  ComfyUI:     http://localhost:$COMFY_PORT"
echo "  EriUI API:   http://localhost:$SERVER_PORT"
echo "=========================================="
echo "Press Ctrl+C to stop all services"

# Wait for any process to exit
wait
