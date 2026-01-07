#!/bin/bash
# ERI UI - Image Generation Interface
# Launches ComfyUI backend, ERI API server, and Flutter web app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFY_DIR="$HOME/SwarmUI/dlbackend/ComfyUI"
FLUTTER_DIR="$HOME/flutter/bin"
ERI_PORT=7802
FLUTTER_PORT=8080
COMFY_PORT=8188

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "  ███████╗██████╗ ██╗"
echo "  ██╔════╝██╔══██╗██║"
echo "  █████╗  ██████╔╝██║"
echo "  ██╔══╝  ██╔══██╗██║"
echo "  ███████╗██║  ██║██║"
echo "  ╚══════╝╚═╝  ╚═╝╚═╝"
echo -e "${NC}"
echo "  Enhanced Reality Interface"
echo ""

cleanup() {
    echo -e "\n${YELLOW}Shutting down ERI...${NC}"
    kill $COMFY_PID 2>/dev/null || true
    kill $ERI_PID 2>/dev/null || true
    kill $FLUTTER_PID 2>/dev/null || true
    echo -e "${GREEN}ERI stopped.${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM

# Check if ports are in use
check_port() {
    if ss -tuln | grep -q ":$1 "; then
        echo -e "${YELLOW}Port $1 already in use, killing existing process...${NC}"
        fuser -k $1/tcp 2>/dev/null || true
        sleep 1
    fi
}

echo -e "${GREEN}[1/3] Starting ComfyUI backend...${NC}"
check_port $COMFY_PORT
cd "$COMFY_DIR"
./venv/bin/python main.py --listen --port $COMFY_PORT > /tmp/eri-comfy.log 2>&1 &
COMFY_PID=$!

# Wait for ComfyUI to start
echo -n "  Waiting for ComfyUI"
for i in {1..30}; do
    if curl -s "http://localhost:$COMFY_PORT/system_stats" > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 1
done

echo -e "${GREEN}[2/3] Starting ERI API server...${NC}"
check_port $ERI_PORT
cd "$SCRIPT_DIR"
"$FLUTTER_DIR/dart" run bin/server.dart --port=$ERI_PORT --comfy-url=http://localhost:$COMFY_PORT > /tmp/eri-server.log 2>&1 &
ERI_PID=$!
sleep 2

echo -e "${GREEN}[3/3] Starting ERI Web UI...${NC}"
check_port $FLUTTER_PORT
cd "$SCRIPT_DIR/flutter_app"
"$FLUTTER_DIR/flutter" run -d web-server --web-port $FLUTTER_PORT --web-hostname 0.0.0.0 > /tmp/eri-flutter.log 2>&1 &
FLUTTER_PID=$!

# Wait for Flutter to compile
echo -n "  Compiling Flutter app"
for i in {1..60}; do
    if curl -s "http://localhost:$FLUTTER_PORT" > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  ERI is running!${NC}"
echo ""
echo -e "  ${GREEN}Web UI:${NC}     http://localhost:$FLUTTER_PORT"
echo -e "  ${GREEN}API:${NC}        http://localhost:$ERI_PORT"
echo -e "  ${GREEN}ComfyUI:${NC}    http://localhost:$COMFY_PORT"
echo ""
echo -e "  Press ${YELLOW}Ctrl+C${NC} to stop all services"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"

# Keep running
wait
