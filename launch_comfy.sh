#!/bin/bash
# EriUI ComfyUI Launch Script
# Runs on port 8199 (separate from SwarmUI's ComfyUI on 8188)

cd /home/alex/eriui/comfyui/ComfyUI
source venv/bin/activate

echo "Starting EriUI ComfyUI on port 8199..."
python main.py --port 8199 --listen 0.0.0.0 "$@"
