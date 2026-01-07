/// Frenetic Data Syntax (FDS) parser for SwarmUI compatibility
/// This format is used by SwarmUI for Settings.fds, Backends.fds, etc.
///
/// FDS Format Example:
/// ```
/// key: value
/// nested_section
/// {
///     inner_key: inner_value
///     deep_section
///     {
///         deep_key: deep_value
///     }
/// }
/// ```
class FdsParser {
  /// Parse FDS content string to a Map
  static Map<String, dynamic> parse(String content) {
    final result = <String, dynamic>{};
    final lines = content.split('\n');
    _parseSection(lines, 0, result, 0);
    return result;
  }

  /// Parse a section recursively
  /// Returns the line index after parsing completes
  static int _parseSection(
    List<String> lines,
    int startIndex,
    Map<String, dynamic> target,
    int depth,
  ) {
    var i = startIndex;

    while (i < lines.length) {
      var line = lines[i];
      final trimmed = line.trim();

      // Skip empty lines and comments
      if (trimmed.isEmpty ||
          trimmed.startsWith('#') ||
          trimmed.startsWith('//')) {
        i++;
        continue;
      }

      // End of section
      if (trimmed == '}') {
        return i;
      }

      // Check for key: value pair
      final colonIndex = trimmed.indexOf(':');
      if (colonIndex > 0) {
        final key = trimmed.substring(0, colonIndex).trim();
        var value = trimmed.substring(colonIndex + 1).trim();

        // Handle multiline strings (value continues on next lines)
        if (value.isEmpty && i + 1 < lines.length) {
          final nextTrimmed = lines[i + 1].trim();
          if (nextTrimmed == '{') {
            // This is actually a nested section, not a key:value
            // Fall through to section handling below
          } else {
            target[key] = _parseValue(value);
            i++;
            continue;
          }
        } else {
          target[key] = _parseValue(value);
          i++;
          continue;
        }
      }

      // Check for nested section (name followed by { on next line)
      if (!trimmed.contains(':') && !trimmed.contains('{')) {
        final sectionName = trimmed;

        // Look for opening brace
        var braceIndex = i + 1;
        while (braceIndex < lines.length) {
          final braceLine = lines[braceIndex].trim();
          if (braceLine.isEmpty || braceLine.startsWith('#')) {
            braceIndex++;
            continue;
          }
          break;
        }

        if (braceIndex < lines.length && lines[braceIndex].trim() == '{') {
          final nested = <String, dynamic>{};
          final endIndex = _parseSection(lines, braceIndex + 1, nested, depth + 1);
          target[sectionName] = nested;
          i = endIndex + 1;
          continue;
        }
      }

      // Handle inline section: name { ... } on same line
      if (trimmed.contains('{') && !trimmed.startsWith('{')) {
        final braceIdx = trimmed.indexOf('{');
        final sectionName = trimmed.substring(0, braceIdx).trim();
        var remainder = trimmed.substring(braceIdx + 1).trim();

        if (remainder.endsWith('}')) {
          // Single-line section
          remainder = remainder.substring(0, remainder.length - 1).trim();
          final nested = <String, dynamic>{};
          if (remainder.isNotEmpty) {
            _parseSingleLine(remainder, nested);
          }
          target[sectionName] = nested;
        } else {
          // Multi-line inline section
          final nested = <String, dynamic>{};
          if (remainder.isNotEmpty) {
            _parseSingleLine(remainder, nested);
          }
          final endIndex = _parseSection(lines, i + 1, nested, depth + 1);
          target[sectionName] = nested;
          i = endIndex;
        }
        i++;
        continue;
      }

      i++;
    }

    return i;
  }

  /// Parse a single line of key: value pairs (for inline sections)
  static void _parseSingleLine(String line, Map<String, dynamic> target) {
    final parts = line.split(',');
    for (final part in parts) {
      final trimmed = part.trim();
      final colonIdx = trimmed.indexOf(':');
      if (colonIdx > 0) {
        final key = trimmed.substring(0, colonIdx).trim();
        final value = trimmed.substring(colonIdx + 1).trim();
        target[key] = _parseValue(value);
      }
    }
  }

  /// Parse a value string to the appropriate type
  static dynamic _parseValue(String value) {
    // Empty string
    if (value.isEmpty) return '';

    // Boolean
    if (value == 'true') return true;
    if (value == 'false') return false;

    // Integer
    final intVal = int.tryParse(value);
    if (intVal != null) return intVal;

    // Double
    final doubleVal = double.tryParse(value);
    if (doubleVal != null) return doubleVal;

    // Quoted string - remove quotes
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      return _unescapeString(value.substring(1, value.length - 1));
    }

    // List (comma-separated, enclosed in brackets)
    if (value.startsWith('[') && value.endsWith(']')) {
      final inner = value.substring(1, value.length - 1);
      if (inner.isEmpty) return <String>[];
      return inner.split(',').map((s) => _parseValue(s.trim())).toList();
    }

    // Plain string
    return value;
  }

  /// Unescape a string value
  static String _unescapeString(String value) {
    return value
        .replaceAll(r'\\', '\\')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'");
  }

  /// Serialize a Map to FDS format
  static String serialize(Map<String, dynamic> data, [int indent = 0]) {
    final buffer = StringBuffer();
    final prefix = '    ' * indent;

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is Map<String, dynamic>) {
        // Nested section
        buffer.writeln('$prefix$key');
        buffer.writeln('$prefix{');
        buffer.write(serialize(value, indent + 1));
        buffer.writeln('$prefix}');
      } else if (value is List) {
        // List value
        final items = value.map((v) => _serializeValue(v)).join(', ');
        buffer.writeln('$prefix$key: [$items]');
      } else {
        // Simple value
        buffer.writeln('$prefix$key: ${_serializeValue(value)}');
      }
    }

    return buffer.toString();
  }

  /// Serialize a single value
  static String _serializeValue(dynamic value) {
    if (value == null) return '';
    if (value is bool) return value.toString();
    if (value is num) return value.toString();
    if (value is String) {
      // Quote strings that contain special characters
      if (value.contains(' ') ||
          value.contains(':') ||
          value.contains('\n') ||
          value.contains('"') ||
          value.contains(',') ||
          value.contains('{') ||
          value.contains('}')) {
        return '"${_escapeString(value)}"';
      }
      return value;
    }
    return value.toString();
  }

  /// Escape a string for serialization
  static String _escapeString(String value) {
    return value
        .replaceAll('\\', r'\\')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t')
        .replaceAll('"', r'\"');
  }

  /// Load and parse an FDS file
  static Future<Map<String, dynamic>> loadFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return {};
    }
    final content = await file.readAsString();
    return parse(content);
  }

  /// Save a Map to an FDS file
  static Future<void> saveFile(String path, Map<String, dynamic> data) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(serialize(data));
  }
}

// Need File import for file operations
import 'dart:io';
