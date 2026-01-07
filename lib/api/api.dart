import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../utils/logging.dart';
import '../accounts/session.dart';
import 'api_context.dart';
import 'api_call.dart';

/// Central API router for EriUI
/// Equivalent to SwarmUI's API class
class Api {
  /// All registered API endpoints
  static final Map<String, ApiCall> _endpoints = {};

  /// Get all registered endpoints
  static Map<String, ApiCall> get endpoints => Map.unmodifiable(_endpoints);

  /// Register an API call
  static void registerCall(ApiCall call) {
    _endpoints[call.name] = call;
    Logs.debug('Registered API: ${call.name}');
  }

  /// Unregister an API call
  static void unregisterCall(String name) {
    _endpoints.remove(name);
  }

  /// Get the router for all API endpoints
  static Router get router {
    final router = Router();

    // Register all POST endpoints
    for (final entry in _endpoints.entries) {
      router.post('/API/${entry.key}', _createHandler(entry.value));
    }

    // Also allow GET for some endpoints
    for (final entry in _endpoints.entries) {
      if (entry.value.allowGet) {
        router.get('/API/${entry.key}', _createHandler(entry.value));
      }
    }

    // Catch-all for unknown endpoints
    router.all('/API/<name|.*>', _notFoundHandler);

    return router;
  }

  /// Create a handler for an API call
  static Handler _createHandler(ApiCall call) {
    return (Request request) async {
      final stopwatch = Stopwatch()..start();

      try {
        // Parse request body
        Map<String, dynamic> body = {};
        if (request.method == 'POST') {
          final bodyStr = await request.readAsString();
          if (bodyStr.isNotEmpty) {
            try {
              body = jsonDecode(bodyStr) as Map<String, dynamic>;
            } catch (e) {
              return _errorResponse('Invalid JSON body: $e', 400);
            }
          }
        } else if (request.method == 'GET') {
          // Parse query parameters
          for (final entry in request.url.queryParameters.entries) {
            body[entry.key] = entry.value;
          }
        }

        // Create API context
        final context = ApiContext(
          request: request,
          body: body,
        );

        // Load session if session_id provided
        await context.loadSession();

        // Check permissions
        if (call.requiredPermissions.isNotEmpty) {
          if (context.session == null) {
            return _errorResponse('Session required', 401);
          }

          for (final perm in call.requiredPermissions) {
            if (!context.session!.hasPermission(perm)) {
              return _errorResponse('Permission denied: $perm', 403);
            }
          }
        }

        // Execute the handler
        final result = await call.handler(context);

        stopwatch.stop();
        Logs.debug('API ${call.name} completed in ${stopwatch.elapsedMilliseconds}ms');

        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e, stack) {
        stopwatch.stop();

        if (e is ApiException) {
          return _errorResponse(e.message, e.statusCode);
        }

        Logs.error('API ${call.name} error: $e', e, stack);
        return _errorResponse('Internal server error: $e', 500);
      }
    };
  }

  /// Handler for unknown endpoints
  static Future<Response> _notFoundHandler(Request request) async {
    final path = request.url.path;
    return _errorResponse('Unknown API endpoint: $path', 404);
  }

  /// Create an error response
  static Response _errorResponse(String message, int statusCode) {
    return Response(
      statusCode,
      body: jsonEncode({'error': message}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Get list of all registered API names
  static List<String> getEndpointNames() {
    return _endpoints.keys.toList()..sort();
  }

  /// Get endpoint info for documentation
  static List<Map<String, dynamic>> getEndpointInfo() {
    return _endpoints.values.map((call) => {
      'name': call.name,
      'description': call.description,
      'permissions': call.requiredPermissions.toList(),
      'allowGet': call.allowGet,
    }).toList();
  }
}

/// API exception with status code
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, [this.statusCode = 400]);

  @override
  String toString() => 'ApiException: $message';
}
