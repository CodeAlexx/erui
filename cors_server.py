#!/usr/bin/env python3
"""Simple HTTP server with CORS headers for video thumbnail extraction testing."""

from http.server import HTTPServer, SimpleHTTPRequestHandler
import os

class CORSRequestHandler(SimpleHTTPRequestHandler):
    def send_cors_headers(self):
        """Send CORS headers to allow cross-origin access."""
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Access-Control-Max-Age', '86400')  # Cache preflight for 24 hours

    def end_headers(self):
        self.send_cors_headers()
        super().end_headers()

    def do_OPTIONS(self):
        """Handle preflight CORS requests."""
        self.send_response(200)
        self.send_cors_headers()
        self.send_header('Content-Length', '0')
        self.send_header('Content-Type', 'text/plain')
        # Must call parent's end_headers to avoid double CORS headers
        SimpleHTTPRequestHandler.end_headers(self)

if __name__ == '__main__':
    os.chdir('/home/alex/eriui')
    port = 8899
    print(f'Starting CORS-enabled server on port {port}...')
    print(f'Serving files from: {os.getcwd()}')
    httpd = HTTPServer(('', port), CORSRequestHandler)
    httpd.serve_forever()
