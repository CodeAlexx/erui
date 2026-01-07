import 'dart:io';
import 'package:logging/logging.dart';

/// EriUI logging system - mirrors SwarmUI's Logs class
class Logs {
  static final Logger _logger = Logger('EriUI');
  static LogLevel _minLevel = LogLevel.info;
  static IOSink? _logFile;

  /// Initialize logging system
  static void init(String message, {LogLevel? level, String? logFilePath}) {
    _minLevel = level ?? LogLevel.info;

    // Configure logging
    Logger.root.level = _toLevelFromLogLevel(_minLevel);
    Logger.root.onRecord.listen(_handleLogRecord);

    // Open log file if specified
    if (logFilePath != null) {
      final file = File(logFilePath);
      file.parent.createSync(recursive: true);
      _logFile = file.openWrite(mode: FileMode.append);
    }

    info(message);
  }

  /// Log at debug level
  static void debug(String message) {
    if (_minLevel.index <= LogLevel.debug.index) {
      _logger.fine(message);
    }
  }

  /// Log at verbose level
  static void verbose(String message) {
    if (_minLevel.index <= LogLevel.verbose.index) {
      _logger.finer(message);
    }
  }

  /// Log at info level
  static void info(String message) {
    if (_minLevel.index <= LogLevel.info.index) {
      _logger.info(message);
    }
  }

  /// Log at init level (startup messages)
  static void initLog(String message) {
    if (_minLevel.index <= LogLevel.init.index) {
      _logger.config(message);
    }
  }

  /// Log at warning level
  static void warning(String message) {
    if (_minLevel.index <= LogLevel.warning.index) {
      _logger.warning(message);
    }
  }

  /// Log at error level
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }

  /// Handle log record
  static void _handleLogRecord(LogRecord record) {
    final timestamp = _formatTimestamp(record.time);
    final level = _formatLevel(record.level);
    final message = '[$timestamp] [$level] ${record.message}';

    // Write to console with colors
    _writeToConsole(record.level, message);

    // Write to file if available
    if (_logFile != null) {
      _logFile!.writeln(message);
      if (record.error != null) {
        _logFile!.writeln('  Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        _logFile!.writeln('  Stack: ${record.stackTrace}');
      }
    }
  }

  static void _writeToConsole(Level level, String message) {
    if (level >= Level.SEVERE) {
      stderr.writeln('\x1B[31m$message\x1B[0m'); // Red
    } else if (level >= Level.WARNING) {
      stdout.writeln('\x1B[33m$message\x1B[0m'); // Yellow
    } else if (level >= Level.CONFIG) {
      stdout.writeln('\x1B[36m$message\x1B[0m'); // Cyan
    } else if (level >= Level.INFO) {
      stdout.writeln(message);
    } else {
      stdout.writeln('\x1B[90m$message\x1B[0m'); // Gray
    }
  }

  static String _formatTimestamp(DateTime time) {
    return '${time.year}-${_pad(time.month)}-${_pad(time.day)} '
        '${_pad(time.hour)}:${_pad(time.minute)}:${_pad(time.second)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String _formatLevel(Level level) {
    if (level >= Level.SEVERE) return 'ERROR';
    if (level >= Level.WARNING) return 'WARN';
    if (level >= Level.CONFIG) return 'INIT';
    if (level >= Level.INFO) return 'INFO';
    if (level >= Level.FINE) return 'DEBUG';
    return 'VERBOSE';
  }

  static Level _toLevelFromLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return Level.FINER;
      case LogLevel.debug:
        return Level.FINE;
      case LogLevel.info:
        return Level.INFO;
      case LogLevel.init:
        return Level.CONFIG;
      case LogLevel.warning:
        return Level.WARNING;
      case LogLevel.error:
        return Level.SEVERE;
      case LogLevel.none:
        return Level.OFF;
    }
  }

  /// Set minimum log level
  static void setLevel(LogLevel level) {
    _minLevel = level;
    Logger.root.level = _toLevelFromLogLevel(level);
  }

  /// Parse log level from string
  static LogLevel parseLevel(String level) {
    switch (level.toLowerCase()) {
      case 'verbose':
        return LogLevel.verbose;
      case 'debug':
        return LogLevel.debug;
      case 'info':
        return LogLevel.info;
      case 'init':
        return LogLevel.init;
      case 'warning':
        return LogLevel.warning;
      case 'error':
        return LogLevel.error;
      case 'none':
        return LogLevel.none;
      default:
        return LogLevel.info;
    }
  }

  /// Shutdown logging
  static Future<void> shutdown() async {
    await _logFile?.flush();
    await _logFile?.close();
  }
}

/// Log levels matching SwarmUI's LogLevel enum
enum LogLevel {
  verbose,
  debug,
  info,
  init,
  warning,
  error,
  none,
}
