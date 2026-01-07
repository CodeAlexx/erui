import 'dart:async';
import 'api_context.dart';

/// Definition of an API endpoint
class ApiCall {
  /// API endpoint name (used in URL: /API/{name})
  final String name;

  /// Human-readable description
  final String description;

  /// Required permissions to call this endpoint
  final Set<String> requiredPermissions;

  /// Whether GET requests are allowed (in addition to POST)
  final bool allowGet;

  /// The handler function
  final Future<Map<String, dynamic>> Function(ApiContext) handler;

  /// Whether this is a WebSocket endpoint
  final bool isWebSocket;

  /// Rate limit (requests per minute, 0 for no limit)
  final int rateLimit;

  ApiCall({
    required this.name,
    required this.description,
    Set<String>? requiredPermissions,
    this.allowGet = false,
    required this.handler,
    this.isWebSocket = false,
    this.rateLimit = 0,
  }) : requiredPermissions = requiredPermissions ?? {};

  /// Create an API call requiring admin permission
  factory ApiCall.admin({
    required String name,
    required String description,
    required Future<Map<String, dynamic>> Function(ApiContext) handler,
    bool allowGet = false,
  }) {
    return ApiCall(
      name: name,
      description: description,
      requiredPermissions: {'admin'},
      allowGet: allowGet,
      handler: handler,
    );
  }

  /// Create an API call requiring user permission
  factory ApiCall.user({
    required String name,
    required String description,
    required Future<Map<String, dynamic>> Function(ApiContext) handler,
    bool allowGet = false,
  }) {
    return ApiCall(
      name: name,
      description: description,
      requiredPermissions: {'user'},
      allowGet: allowGet,
      handler: handler,
    );
  }

  /// Create a public API call (no auth required)
  factory ApiCall.public({
    required String name,
    required String description,
    required Future<Map<String, dynamic>> Function(ApiContext) handler,
    bool allowGet = true,
  }) {
    return ApiCall(
      name: name,
      description: description,
      allowGet: allowGet,
      handler: handler,
    );
  }
}
