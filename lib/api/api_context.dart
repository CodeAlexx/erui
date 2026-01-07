import 'dart:io';
import 'package:shelf/shelf.dart';

import '../accounts/session.dart';
import '../accounts/user.dart';
import '../core/program.dart';
import 'api.dart';

/// Context for an API request
class ApiContext {
  /// Original HTTP request
  final Request request;

  /// Parsed request body
  final Map<String, dynamic> body;

  /// Loaded session (if any)
  Session? session;

  /// Extra data attached during request processing
  final Map<String, dynamic> extraData = {};

  ApiContext({
    required this.request,
    required this.body,
    this.session,
  });

  /// Get the user from session
  User? get user => session?.user;

  /// Get the client's IP address
  String get clientIp {
    // Check X-Forwarded-For header
    final forwarded = request.headers['x-forwarded-for'];
    if (forwarded != null) {
      return forwarded.split(',').first.trim();
    }

    // Check X-Real-IP header
    final realIp = request.headers['x-real-ip'];
    if (realIp != null) {
      return realIp;
    }

    // Fallback to connection info (not always available in shelf)
    return request.headers['host'] ?? 'unknown';
  }

  /// Load session from body or headers
  Future<void> loadSession() async {
    // Try session_id from body
    final sessionId = body['session_id'] as String?;
    if (sessionId != null && sessionId.isNotEmpty) {
      session = Program.instance.sessions.tryGetSession(sessionId);
      if (session != null) {
        session!.updateLastUsedTime();
      }
      return;
    }

    // Try Authorization header
    final authHeader = request.headers['authorization'];
    if (authHeader != null) {
      if (authHeader.startsWith('Bearer ')) {
        final token = authHeader.substring(7);
        // TODO: Validate API token and create session
      } else if (authHeader.startsWith('Session ')) {
        final sessId = authHeader.substring(8);
        session = Program.instance.sessions.tryGetSession(sessId);
        if (session != null) {
          session!.updateLastUsedTime();
        }
      }
    }
  }

  /// Get a required parameter from body
  T require<T>(String key) {
    if (!body.containsKey(key)) {
      throw ApiException('Missing required parameter: $key');
    }
    final value = body[key];
    if (value is! T) {
      throw ApiException('Invalid type for parameter $key: expected $T, got ${value.runtimeType}');
    }
    return value;
  }

  /// Get an optional parameter from body
  T? get<T>(String key) {
    final value = body[key];
    if (value == null) return null;
    if (value is T) return value;

    // Try type conversion for common types
    if (T == int && value is String) {
      return int.tryParse(value) as T?;
    }
    if (T == double && value is String) {
      return double.tryParse(value) as T?;
    }
    if (T == double && value is int) {
      return value.toDouble() as T?;
    }
    if (T == bool && value is String) {
      return (value.toLowerCase() == 'true') as T?;
    }
    if (T == String) {
      return value.toString() as T;
    }

    return null;
  }

  /// Get a parameter with default value
  T getOr<T>(String key, T defaultValue) {
    return get<T>(key) ?? defaultValue;
  }

  /// Get a list parameter
  List<T> getList<T>(String key) {
    final value = body[key];
    if (value == null) return [];
    if (value is List) {
      return value.whereType<T>().toList();
    }
    return [];
  }

  /// Get a map parameter
  Map<String, dynamic> getMap(String key) {
    final value = body[key];
    if (value == null) return {};
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  /// Check if parameter exists and is not empty
  bool has(String key) {
    final value = body[key];
    if (value == null) return false;
    if (value is String && value.isEmpty) return false;
    if (value is List && value.isEmpty) return false;
    if (value is Map && value.isEmpty) return false;
    return true;
  }

  /// Require a session
  Session requireSession() {
    if (session == null) {
      throw ApiException('Session required', 401);
    }
    return session!;
  }

  /// Require a user
  User requireUser() {
    final sess = requireSession();
    return sess.user;
  }

  /// Check if user has permission
  bool hasPermission(String permission) {
    return session?.hasPermission(permission) ?? false;
  }

  /// Require a permission
  void requirePermission(String permission) {
    if (!hasPermission(permission)) {
      throw ApiException('Permission denied: $permission', 403);
    }
  }
}
