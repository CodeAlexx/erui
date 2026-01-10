#!/usr/bin/env python3
"""Simple HTTP server with CORS headers for video thumbnail extraction testing."""

from http.server import HTTPServer, SimpleHTTPRequestHandler
import os

class CORSRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        # Add CORS headers to allow cross-origin access
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

if __name__ == '__main__':
    os.chdir('/home/alex/eriui')
    port = 8899
    print(f'Starting CORS-enabled server on port {port}...')
    print(f'Serving files from: {os.getcwd()}')
    httpd = HTTPServer(('', port), CORSRequestHandler)
    httpd.serve_forever()
