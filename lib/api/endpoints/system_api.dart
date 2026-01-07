import 'dart:async';
import 'dart:io';

import '../../core/program.dart';
import '../api.dart';
import '../api_call.dart';
import '../api_context.dart';

/// System status and monitoring API endpoints
class SystemAPI {
  /// Register all system API endpoints
  static void register() {
    Api.registerCall(ApiCall(
      name: 'GetSystemStatus',
      description: 'Get overall system status',
      requiredPermissions: {'user'},
      allowGet: true,
      handler: _getSystemStatus,
    ));

    Api.registerCall(ApiCall(
      name: 'GetBackendStatus',
      description: 'Get status of all backends',
      requiredPermissions: {'user'},
      allowGet: true,
      handler: _getBackendStatus,
    ));

    Api.registerCall(ApiCall(
      name: 'GetResourceUsage',
      description: 'Get system resource usage',
      requiredPermissions: {'user'},
      allowGet: true,
      handler: _getResourceUsage,
    ));

    Api.registerCall(ApiCall(
      name: 'GetServerInfo',
      description: 'Get server information',
      requiredPermissions: {},
      allowGet: true,
      handler: _getServerInfo,
    ));

    Api.registerCall(ApiCall(
      name: 'GetActiveSessions',
      description: 'Get active session count',
      requiredPermissions: {'admin'},
      allowGet: true,
      handler: _getActiveSessions,
    ));

    Api.registerCall(ApiCall(
      name: 'GetModelCounts',
      description: 'Get model counts by type',
      requiredPermissions: {'user'},
      allowGet: true,
      handler: _getModelCounts,
    ));

    Api.registerCall(ApiCall(
      name: 'GetGenerationStats',
      description: 'Get generation statistics',
      requiredPermissions: {'user'},
      handler: _getGenerationStats,
    ));

    Api.registerCall(ApiCall(
      name: 'RestartBackend',
      description: 'Restart a specific backend',
      requiredPermissions: {'admin'},
      handler: _restartBackend,
    ));

    Api.registerCall(ApiCall(
      name: 'CheckHealth',
      description: 'Health check endpoint',
      requiredPermissions: {},
      allowGet: true,
      handler: _checkHealth,
    ));
  }

  /// Get overall system status
  static Future<Map<String, dynamic>> _getSystemStatus(ApiContext ctx) async {
    final program = Program.instance;

    // Get backend statuses
    final backends = <Map<String, dynamic>>[];
    for (final backend in program.backends.backends.values) {
      backends.add({
        'id': backend.id,
        'type': backend.type.name,
        'status': backend.status.name,
        'current_model': backend.currentModelName,
        'features': backend.supportedFeatures.toList(),
      });
    }

    return {
      'status': 'running',
      'uptime_seconds': _getUptime(),
      'backends': backends,
      'active_generations': _getActiveGenerations(),
      'queued_generations': _getQueuedGenerations(),
      'session_count': program.sessions.activeSessions.length,
    };
  }

  /// Get backend status
  static Future<Map<String, dynamic>> _getBackendStatus(ApiContext ctx) async {
    final program = Program.instance;

    final backends = <Map<String, dynamic>>[];
    for (final backend in program.backends.backends.values) {
      backends.add({
        'id': backend.id,
        'type': backend.type.name,
        'status': backend.status.name,
        'address': backend.address,
        'current_model': backend.currentModelName,
        'max_resolution': backend.maxResolution,
        'supported_features': backend.supportedFeatures.toList(),
        'is_available': backend.isAvailable,
        'last_error': backend.lastError,
      });
    }

    return {'backends': backends};
  }

  /// Get resource usage
  static Future<Map<String, dynamic>> _getResourceUsage(ApiContext ctx) async {
    // Get process info
    final processInfo = ProcessInfo.currentRss;

    return {
      'memory': {
        'rss_mb': processInfo / (1024 * 1024),
        'heap_mb': ProcessInfo.currentRss / (1024 * 1024),
      },
      'cpu': {
        'process_time_ms': _getProcessCpuTime(),
      },
      'disk': {
        'output_folder_mb': await _getFolderSize(Program.instance.serverSettings.paths.outputPath),
        'models_folder_mb': await _getFolderSize(Program.instance.serverSettings.paths.modelRoot),
      },
    };
  }

  /// Get server info
  static Future<Map<String, dynamic>> _getServerInfo(ApiContext ctx) async {
    return {
      'version': '0.1.0',
      'server_name': 'EriUI',
      'dart_version': Platform.version,
      'os': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'hostname': Platform.localHostname,
      'supported_features': [
        'text2img',
        'img2img',
        'inpaint',
        'controlnet',
        'upscale',
        'refiner',
        'batch',
        'regional',
        'workflow',
      ],
    };
  }

  /// Get active sessions
  static Future<Map<String, dynamic>> _getActiveSessions(ApiContext ctx) async {
    final program = Program.instance;
    final sessions = program.sessions.activeSessions;

    return {
      'count': sessions.length,
      'sessions': sessions.values.map((s) => {
        'id': s.id.substring(0, 8),
        'username': s.user?.username ?? 'anonymous',
        'created_at': s.createdAt.toIso8601String(),
        'last_activity': s.lastActivity.toIso8601String(),
        'active_generations': s.liveGens,
      }).toList(),
    };
  }

  /// Get model counts
  static Future<Map<String, dynamic>> _getModelCounts(ApiContext ctx) async {
    final program = Program.instance;
    final counts = <String, int>{};

    for (final entry in program.t2iModelSets.entries) {
      counts[entry.key] = entry.value.models.length;
    }

    return {'counts': counts, 'total': counts.values.fold(0, (a, b) => a + b)};
  }

  /// Get generation statistics
  static Future<Map<String, dynamic>> _getGenerationStats(ApiContext ctx) async {
    final period = ctx.getOr<String>('period', 'hour'); // hour, day, week, month

    // In a real implementation, this would query a database
    // For now, return placeholder stats
    return {
      'period': period,
      'total_generations': 0,
      'successful': 0,
      'failed': 0,
      'average_time_ms': 0,
      'models_used': <String, int>{},
    };
  }

  /// Restart a backend
  static Future<Map<String, dynamic>> _restartBackend(ApiContext ctx) async {
    final backendId = ctx.require<String>('backend_id');

    final program = Program.instance;
    final backend = program.backends.backends[backendId];

    if (backend == null) {
      return {'success': false, 'error': 'Backend not found'};
    }

    await backend.restart();

    return {'success': true, 'message': 'Backend restart initiated'};
  }

  /// Health check
  static Future<Map<String, dynamic>> _checkHealth(ApiContext ctx) async {
    final program = Program.instance;

    // Check if any backend is available
    final hasBackend = program.backends.backends.values.any((b) => b.isAvailable);

    return {
      'status': hasBackend ? 'healthy' : 'degraded',
      'timestamp': DateTime.now().toIso8601String(),
      'checks': {
        'backends': hasBackend,
        'database': true, // Would check actual database connection
        'storage': true, // Would check storage access
      },
    };
  }

  // ========== HELPERS ==========

  static int _getUptime() {
    // In real implementation, track start time
    return 0;
  }

  static int _getActiveGenerations() {
    int count = 0;
    for (final session in Program.instance.sessions.activeSessions.values) {
      count += session.liveGens;
    }
    return count;
  }

  static int _getQueuedGenerations() {
    int count = 0;
    for (final session in Program.instance.sessions.activeSessions.values) {
      count += session.waitingGenerations;
    }
    return count;
  }

  static int _getProcessCpuTime() {
    // Platform-specific CPU time
    return 0;
  }

  static Future<double> _getFolderSize(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return 0;

    double size = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        size += await entity.length();
      }
    }
    return size / (1024 * 1024);
  }
}
