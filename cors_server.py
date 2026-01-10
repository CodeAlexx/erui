#!/usr/bin/env python3
"""HTTP server with CORS headers and Range request support for video streaming."""

from http.server import HTTPServer, SimpleHTTPRequestHandler
import os
import re

class RangeRequestHandler(SimpleHTTPRequestHandler):
    """HTTP handler with CORS and Range request support for video seeking."""

    def send_cors_headers(self):
        """Send CORS headers to allow cross-origin access."""
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Accept-Ranges')
        self.send_header('Access-Control-Max-Age', '86400')

    def end_headers(self):
        self.send_cors_headers()
        super().end_headers()

    def do_OPTIONS(self):
        """Handle preflight CORS requests."""
        self.send_response(200)
        self.send_cors_headers()
        self.send_header('Content-Length', '0')
        self.send_header('Content-Type', 'text/plain')
        SimpleHTTPRequestHandler.end_headers(self)

    def do_GET(self):
        """Handle GET requests with Range support."""
        path = self.translate_path(self.path)

        if not os.path.isfile(path):
            return super().do_GET()

        file_size = os.path.getsize(path)
        range_header = self.headers.get('Range')

        if range_header:
            # Parse Range header
            match = re.match(r'bytes=(\d*)-(\d*)', range_header)
            if match:
                start_str, end_str = match.groups()
                start = int(start_str) if start_str else 0
                end = int(end_str) if end_str else file_size - 1

                # Clamp to valid range
                start = max(0, start)
                end = min(end, file_size - 1)
                length = end - start + 1

                # Send partial content response
                self.send_response(206)
                self.send_header('Content-Type', self.guess_type(path))
                self.send_header('Content-Length', str(length))
                self.send_header('Content-Range', f'bytes {start}-{end}/{file_size}')
                self.send_header('Accept-Ranges', 'bytes')
                self.end_headers()

                # Send the requested byte range
                with open(path, 'rb') as f:
                    f.seek(start)
                    self.wfile.write(f.read(length))
                return

        # No Range header - send full file with Accept-Ranges header
        self.send_response(200)
        self.send_header('Content-Type', self.guess_type(path))
        self.send_header('Content-Length', str(file_size))
        self.send_header('Accept-Ranges', 'bytes')
        self.end_headers()

        with open(path, 'rb') as f:
            self.wfile.write(f.read())

    def do_HEAD(self):
        """Handle HEAD requests with Accept-Ranges header."""
        path = self.translate_path(self.path)

        if os.path.isfile(path):
            file_size = os.path.getsize(path)
            self.send_response(200)
            self.send_header('Content-Type', self.guess_type(path))
            self.send_header('Content-Length', str(file_size))
            self.send_header('Accept-Ranges', 'bytes')
            self.end_headers()
        else:
            super().do_HEAD()

if __name__ == '__main__':
    os.chdir('/home/alex/eriui')
    port = 8899
    print(f'Starting CORS + Range-enabled server on port {port}...')
    print(f'Serving files from: {os.getcwd()}')
    print('Supports: CORS, Range requests (video seeking)')
    httpd = HTTPServer(('', port), RangeRequestHandler)
    httpd.serve_forever()
