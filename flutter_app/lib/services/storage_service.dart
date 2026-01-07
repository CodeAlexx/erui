import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Storage service provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Local storage service using Hive
class StorageService {
  static late Box<dynamic> _box;
  static const String _boxName = 'eriui_storage';

  /// Initialize the storage service
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// Get a string value (instance method)
  String? getString(String key) {
    return _box.get(key) as String?;
  }

  /// Set a string value (instance method)
  Future<void> setString(String key, String value) async {
    await _box.put(key, value);
  }

  /// Get a string value (static)
  static String? getStringStatic(String key) {
    return _box.get(key) as String?;
  }

  /// Set a string value (static)
  static Future<void> setStringStatic(String key, String value) async {
    await _box.put(key, value);
  }

  /// Get an integer value
  static int? getInt(String key) {
    return _box.get(key) as int?;
  }

  /// Set an integer value
  static Future<void> setInt(String key, int value) async {
    await _box.put(key, value);
  }

  /// Get a double value
  static double? getDouble(String key) {
    return _box.get(key) as double?;
  }

  /// Set a double value
  static Future<void> setDouble(String key, double value) async {
    await _box.put(key, value);
  }

  /// Get a boolean value
  static bool? getBool(String key) {
    return _box.get(key) as bool?;
  }

  /// Set a boolean value
  static Future<void> setBool(String key, bool value) async {
    await _box.put(key, value);
  }

  /// Get a list of strings
  static List<String>? getStringList(String key) {
    final value = _box.get(key);
    if (value == null) return null;
    return (value as List).cast<String>();
  }

  /// Set a list of strings
  static Future<void> setStringList(String key, List<String> value) async {
    await _box.put(key, value);
  }

  /// Get a map value
  static Map<String, dynamic>? getMap(String key) {
    final value = _box.get(key);
    if (value == null) return null;
    return Map<String, dynamic>.from(value as Map);
  }

  /// Set a map value
  static Future<void> setMap(String key, Map<String, dynamic> value) async {
    await _box.put(key, value);
  }

  /// Check if a key exists
  static bool containsKey(String key) {
    return _box.containsKey(key);
  }

  /// Remove a value
  static Future<void> remove(String key) async {
    await _box.delete(key);
  }

  /// Clear all values
  static Future<void> clear() async {
    await _box.clear();
  }

  /// Get all keys
  static Iterable<dynamic> get keys => _box.keys;
}
