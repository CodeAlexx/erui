#!/usr/bin/env python3
"""
LoRA Metadata Server - Reads safetensors metadata to determine base model compatibility
"""

import os
import json
import re
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import threading

# Try to import safetensors
try:
    from safetensors import safe_open
    HAS_SAFETENSORS = True
except ImportError:
    HAS_SAFETENSORS = False
    print("Warning: safetensors not installed, metadata reading disabled")

LORA_DIR = '/home/alex/eriui/comfyui/ComfyUI/models/loras/'
CACHE_FILE = '/home/alex/eriui/comfyui/ComfyUI/user/lora_metadata_cache.json'

# Base model type mapping
BASE_MODEL_PATTERNS = {
    'flux': ['flux', 'Flux'],
    'chroma': ['chroma', 'Chroma'],
    'sdxl': ['sdxl', 'SDXL', 'stable-diffusion-xl'],
    'sd15': ['sd_1.5', 'sd1.5', 'sd15', 'stable-diffusion-v1'],
    'sd3': ['sd3', 'SD3', 'stable-diffusion-3'],
    'hidream': ['hidream', 'HiDream'],
    'omnigen2': ['omnigen', 'OmniGen'],
    'zimage': ['zimage', 'z-image', 'Z-Image'],
    'ltx': ['ltx', 'LTX'],
    'wan': ['wan', 'Wan'],
    'hunyuan': ['hunyuan', 'Hunyuan'],
    'kandinsky': ['kandinsky', 'Kandinsky'],
}

def detect_base_model(metadata: dict, filename: str) -> str:
    """Detect the base model type from metadata or filename."""
    if not metadata:
        metadata = {}

    # Check ss_base_model_version
    base_version = metadata.get('ss_base_model_version', '').lower()

    # Check modelspec.architecture
    architecture = metadata.get('modelspec.architecture', '').lower()

    # Combine for matching
    combined = f"{base_version} {architecture} {filename}".lower()

    # Match against patterns
    for model_type, patterns in BASE_MODEL_PATTERNS.items():
        for pattern in patterns:
            if pattern.lower() in combined:
                return model_type

    # Try to detect from resolution in metadata
    resolution = metadata.get('ss_resolution', '') or metadata.get('modelspec.resolution', '')
    if resolution:
        try:
            # Parse resolution like "1024,1024" or "512,512"
            if ',' in str(resolution):
                w = int(str(resolution).split(',')[0])
                if w >= 1024:
                    return 'sdxl'  # SDXL resolution
                elif w <= 768:
                    return 'sd15'  # SD1.5 resolution
        except:
            pass

    return 'unknown'

def read_lora_metadata(filepath: str) -> dict:
    """Read metadata from a safetensors file."""
    if not HAS_SAFETENSORS:
        return {}

    try:
        with safe_open(filepath, framework='pt') as f:
            return dict(f.metadata()) if f.metadata() else {}
    except Exception as e:
        return {'error': str(e)}

def scan_loras() -> list:
    """Scan all LoRAs and extract metadata."""
    results = []

    if not os.path.exists(LORA_DIR):
        return results

    for root, dirs, files in os.walk(LORA_DIR):
        for filename in files:
            if not filename.endswith('.safetensors'):
                continue

            filepath = os.path.join(root, filename)
            rel_path = os.path.relpath(filepath, LORA_DIR)

            metadata = read_lora_metadata(filepath)
            base_model = detect_base_model(metadata, filename)

            # Detect LoRA type (LoRA vs LyCORIS)
            lora_type = 'LoRA'
            network_module = metadata.get('ss_network_module', '').lower()
            if any(x in network_module for x in ['locon', 'loha', 'lokr', 'lycoris']):
                lora_type = 'LyCORIS'
            elif any(x in filename.lower() for x in ['locon', 'loha', 'lokr', 'lycoris']):
                lora_type = 'LyCORIS'

            results.append({
                'name': rel_path,
                'filename': filename,
                'base_model': base_model,
                'type': lora_type,
                'ss_base_model_version': metadata.get('ss_base_model_version', ''),
                'modelspec_architecture': metadata.get('modelspec.architecture', ''),
                'ss_network_module': metadata.get('ss_network_module', ''),
                'ss_resolution': metadata.get('ss_resolution', '') or metadata.get('modelspec.resolution', ''),
            })

    return results

def load_cache() -> list:
    """Load cached metadata if available."""
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, 'r') as f:
                return json.load(f)
        except:
            pass
    return []

def save_cache(data: list):
    """Save metadata to cache file."""
    try:
        os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
        with open(CACHE_FILE, 'w') as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        print(f"Failed to save cache: {e}")


class LoraMetadataHandler(BaseHTTPRequestHandler):
    """HTTP request handler for LoRA metadata."""

    # Class-level cache
    _cache = None
    _cache_lock = threading.Lock()

    def log_message(self, format, *args):
        """Suppress default logging."""
        pass

    def send_cors_headers(self):
        """Send CORS headers."""
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')

    def do_OPTIONS(self):
        """Handle CORS preflight."""
        self.send_response(200)
        self.send_cors_headers()
        self.end_headers()

    def do_GET(self):
        """Handle GET requests."""
        parsed = urlparse(self.path)

        if parsed.path == '/loras':
            self.handle_loras(parsed)
        elif parsed.path == '/refresh':
            self.handle_refresh()
        elif parsed.path == '/health':
            self.handle_health()
        else:
            self.send_error(404, 'Not Found')

    def handle_loras(self, parsed):
        """Return LoRA list with metadata."""
        params = parse_qs(parsed.query)
        base_model_filter = params.get('base_model', [None])[0]

        # Get cached data or scan
        with self._cache_lock:
            if self._cache is None:
                self._cache = load_cache()
                if not self._cache:
                    self._cache = scan_loras()
                    save_cache(self._cache)

            data = self._cache

        # Filter by base model if requested
        if base_model_filter and base_model_filter != 'all':
            data = [l for l in data if l['base_model'] == base_model_filter]

        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_cors_headers()
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def handle_refresh(self):
        """Force refresh of metadata cache."""
        with self._cache_lock:
            self._cache = scan_loras()
            save_cache(self._cache)
            data = self._cache

        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_cors_headers()
        self.end_headers()
        self.wfile.write(json.dumps({'status': 'ok', 'count': len(data)}).encode())

    def handle_health(self):
        """Health check endpoint."""
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_cors_headers()
        self.end_headers()
        self.wfile.write(json.dumps({'status': 'ok'}).encode())


def run_server(port=7804):
    """Run the metadata server."""
    server = HTTPServer(('0.0.0.0', port), LoraMetadataHandler)
    print(f"LoRA Metadata Server running on http://0.0.0.0:{port}")
    print(f"  GET /loras - List all LoRAs with metadata")
    print(f"  GET /loras?base_model=flux - Filter by base model")
    print(f"  GET /refresh - Refresh metadata cache")
    server.serve_forever()


if __name__ == '__main__':
    import sys
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 7804
    run_server(port)
