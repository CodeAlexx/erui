import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_static/shelf_static.dart';

import '../lib/core/program.dart';
import '../lib/api/api.dart';
import '../lib/utils/logging.dart';

/// EriUI Server Entry Point
void main(List<String> args) async {
  // Parse command line args
  final host = _getArg(args, 'host', '0.0.0.0');
  final port = int.parse(_getArg(args, 'port', '7802'));
  final comfyHost = _getArg(args, 'comfy-host', 'localhost');
  final comfyPort = _getArg(args, 'comfy-port', '8199'); // EriUI ComfyUI port (not SwarmUI's 8188)

  final shutdownCompleter = Completer<void>();

  try {
    // Initialize the program
    await Program.instance.init([
      '--comfy_host=$comfyHost',
      '--comfy_port=$comfyPort',
      ...args,
    ]);

    // Build the HTTP pipeline
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(corsHeaders())
        .addMiddleware(_errorHandler())
        .addHandler(_createHandler());

    // Start the server
    final server = await shelf_io.serve(handler, host, port);
    server.autoCompress = true;

    Logs.init('EriUI Server running at http://${server.address.host}:${server.port}');
    Logs.init('ComfyUI backend: http://$comfyHost:$comfyPort');
    Logs.init('Press Ctrl+C to stop');

    // Handle shutdown signals
    ProcessSignal.sigint.watch().first.then((_) {
      Logs.info('Received SIGINT, shutting down...');
      if (!shutdownCompleter.isCompleted) shutdownCompleter.complete();
    });

    ProcessSignal.sigterm.watch().first.then((_) {
      Logs.info('Received SIGTERM, shutting down...');
      if (!shutdownCompleter.isCompleted) shutdownCompleter.complete();
    });

    // Wait for shutdown signal
    await shutdownCompleter.future;

    // Graceful shutdown
    await server.close(force: true);
    await Program.instance.shutdown();

  } catch (e, stack) {
    Logs.error('Failed to start server: $e', e, stack);
    exit(1);
  }
}

/// Create the main request handler
Handler _createHandler() {
  return (Request request) async {
    final path = request.url.path;

    // API routes - handle both /API/ and /api/
    if (path.startsWith('API/') || path.startsWith('api/')) {
      return Api.router(request);
    }

    // Health check
    if (path == '' || path == '/') {
      return Response.ok(
        '{"name": "EriUI Server", "version": "0.1.0", "status": "running"}',
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Serve static files for web UI (if built)
    final staticDir = Directory('web');
    if (await staticDir.exists()) {
      final staticHandler = createStaticHandler(
        'web',
        defaultDocument: 'index.html',
      );
      return staticHandler(request);
    }

    // Default response
    return Response.ok(
      '{"name": "EriUI Server", "version": "0.1.0", "status": "running"}',
      headers: {'Content-Type': 'application/json'},
    );
  };
}

/// Error handling middleware
Middleware _errorHandler() {
  return (Handler innerHandler) {
    return (Request request) async {
      try {
        return await innerHandler(request);
      } catch (e, stack) {
        Logs.error('Request error: $e', e, stack);
        return Response.internalServerError(
          body: '{"error": "Internal server error"}',
          headers: {'Content-Type': 'application/json'},
        );
      }
    };
  };
}

/// Get command line argument
String _getArg(List<String> args, String name, String defaultValue) {
  for (final arg in args) {
    if (arg.startsWith('--$name=')) {
      return arg.substring('--$name='.length);
    }
  }
  return defaultValue;
}
