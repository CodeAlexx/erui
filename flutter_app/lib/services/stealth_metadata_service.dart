import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import 'storage_service.dart';

/// Storage key for stealth metadata enabled setting
const String _stealthMetadataEnabledKey = 'stealth_metadata_enabled';

/// Magic bytes to identify stealth metadata presence
/// Using 'ERIUI' as identifier (0x45, 0x52, 0x49, 0x55, 0x49)
const List<int> _magicBytes = [0x45, 0x52, 0x49, 0x55, 0x49];

/// Stealth metadata service provider
final stealthMetadataServiceProvider = Provider<StealthMetadataService>((ref) {
  return StealthMetadataService();
});

/// Provider for stealth metadata enabled state
final stealthMetadataEnabledProvider =
    StateNotifierProvider<StealthMetadataEnabledNotifier, bool>((ref) {
  return StealthMetadataEnabledNotifier();
});

/// Notifier for stealth metadata enabled state
class StealthMetadataEnabledNotifier extends StateNotifier<bool> {
  StealthMetadataEnabledNotifier() : super(_loadInitialState());

  static bool _loadInitialState() {
    return StorageService.getBool(_stealthMetadataEnabledKey) ?? false;
  }

  /// Toggle stealth metadata encoding
  Future<void> toggle() async {
    state = !state;
    await StorageService.setBool(_stealthMetadataEnabledKey, state);
  }

  /// Set stealth metadata enabled state
  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await StorageService.setBool(_stealthMetadataEnabledKey, enabled);
  }
}

/// Stealth metadata service for encoding/decoding generation parameters
/// into image pixel data using LSB (Least Significant Bit) steganography.
///
/// This allows generation parameters to survive most image compression
/// and social media uploads while remaining invisible to the human eye.
///
/// Algorithm:
/// 1. Convert params JSON to bytes
/// 2. Prepend magic bytes + length (4 bytes, big-endian)
/// 3. Encode each bit into the LSB of pixel color channels
/// 4. Uses alpha channel if available, otherwise RGB channels
class StealthMetadataService {
  /// Check if stealth metadata encoding is enabled
  bool get isEnabled {
    return StorageService.getBool(_stealthMetadataEnabledKey) ?? false;
  }

  /// Encode generation parameters into PNG image bytes.
  ///
  /// [imageBytes] - Original PNG image bytes
  /// [metadata] - Generation parameters to encode
  ///
  /// Returns modified PNG bytes with embedded metadata, or null if encoding fails.
  Uint8List? encodeMetadata(
    Uint8List imageBytes,
    Map<String, dynamic> metadata,
  ) {
    try {
      // Decode the image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        print('StealthMetadata: Failed to decode image');
        return null;
      }

      // Convert metadata to bytes
      final jsonString = jsonEncode(metadata);
      final jsonBytes = utf8.encode(jsonString);

      // Build data payload: magic bytes + length (4 bytes) + data
      final dataLength = jsonBytes.length;
      final payload = Uint8List(_magicBytes.length + 4 + dataLength);

      // Write magic bytes
      for (int i = 0; i < _magicBytes.length; i++) {
        payload[i] = _magicBytes[i];
      }

      // Write length as 4-byte big-endian
      payload[_magicBytes.length] = (dataLength >> 24) & 0xFF;
      payload[_magicBytes.length + 1] = (dataLength >> 16) & 0xFF;
      payload[_magicBytes.length + 2] = (dataLength >> 8) & 0xFF;
      payload[_magicBytes.length + 3] = dataLength & 0xFF;

      // Write JSON data
      for (int i = 0; i < dataLength; i++) {
        payload[_magicBytes.length + 4 + i] = jsonBytes[i];
      }

      // Calculate required pixels (8 bits per byte, using multiple channels)
      // Using RGB channels = 3 bits per pixel, or RGBA = 4 bits per pixel
      final hasAlpha = image.numChannels == 4;
      final bitsPerPixel = hasAlpha ? 4 : 3;
      final requiredBits = payload.length * 8;
      final requiredPixels = (requiredBits / bitsPerPixel).ceil();
      final availablePixels = image.width * image.height;

      if (requiredPixels > availablePixels) {
        print(
            'StealthMetadata: Image too small. Need $requiredPixels pixels, have $availablePixels');
        return null;
      }

      // Encode data into pixel LSBs
      int bitIndex = 0;
      final totalBits = payload.length * 8;

      for (int y = 0; y < image.height && bitIndex < totalBits; y++) {
        for (int x = 0; x < image.width && bitIndex < totalBits; x++) {
          final pixel = image.getPixel(x, y);

          // Get current channel values
          int r = pixel.r.toInt();
          int g = pixel.g.toInt();
          int b = pixel.b.toInt();
          int a = hasAlpha ? pixel.a.toInt() : 255;

          // Encode bits into LSBs
          if (bitIndex < totalBits) {
            r = _encodeBit(r, _getBit(payload, bitIndex++));
          }
          if (bitIndex < totalBits) {
            g = _encodeBit(g, _getBit(payload, bitIndex++));
          }
          if (bitIndex < totalBits) {
            b = _encodeBit(b, _getBit(payload, bitIndex++));
          }
          if (hasAlpha && bitIndex < totalBits) {
            a = _encodeBit(a, _getBit(payload, bitIndex++));
          }

          // Set modified pixel
          image.setPixelRgba(x, y, r, g, b, a);
        }
      }

      // Encode back to PNG
      final encodedBytes = img.encodePng(image);
      return Uint8List.fromList(encodedBytes);
    } catch (e) {
      print('StealthMetadata: Encoding error: $e');
      return null;
    }
  }

  /// Decode generation parameters from PNG image bytes.
  ///
  /// [imageBytes] - PNG image bytes that may contain stealth metadata
  ///
  /// Returns decoded metadata map, or null if no valid metadata found.
  Map<String, dynamic>? decodeMetadata(Uint8List imageBytes) {
    try {
      // Decode the image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        print('StealthMetadata: Failed to decode image');
        return null;
      }

      final hasAlpha = image.numChannels == 4;
      final bitsPerPixel = hasAlpha ? 4 : 3;

      // First, read enough bits to get magic bytes + length
      final headerSize = _magicBytes.length + 4;
      final headerBits = headerSize * 8;
      final headerBytes = _extractBytes(image, headerBits, hasAlpha);

      if (headerBytes == null) {
        return null;
      }

      // Verify magic bytes
      for (int i = 0; i < _magicBytes.length; i++) {
        if (headerBytes[i] != _magicBytes[i]) {
          // No stealth metadata present
          return null;
        }
      }

      // Read length
      final length = (headerBytes[_magicBytes.length] << 24) |
          (headerBytes[_magicBytes.length + 1] << 16) |
          (headerBytes[_magicBytes.length + 2] << 8) |
          headerBytes[_magicBytes.length + 3];

      // Sanity check length
      if (length <= 0 || length > 1024 * 1024) {
        // Max 1MB
        print('StealthMetadata: Invalid length: $length');
        return null;
      }

      // Calculate if we have enough pixels
      final totalBits = (headerSize + length) * 8;
      final requiredPixels = (totalBits / bitsPerPixel).ceil();
      final availablePixels = image.width * image.height;

      if (requiredPixels > availablePixels) {
        print('StealthMetadata: Not enough pixels for declared data length');
        return null;
      }

      // Extract full data
      final fullBytes = _extractBytes(image, totalBits, hasAlpha);
      if (fullBytes == null) {
        return null;
      }

      // Extract JSON data
      final jsonBytes = fullBytes.sublist(headerSize, headerSize + length);

      // Parse JSON
      try {
        final jsonString = utf8.decode(jsonBytes);
        final metadata = jsonDecode(jsonString) as Map<String, dynamic>;
        return metadata;
      } catch (e) {
        print('StealthMetadata: JSON parse error: $e');
        return null;
      }
    } catch (e) {
      print('StealthMetadata: Decoding error: $e');
      return null;
    }
  }

  /// Check if an image contains stealth metadata without fully decoding it
  bool hasStealthMetadata(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return false;

      final hasAlpha = image.numChannels == 4;
      final headerBits = _magicBytes.length * 8;
      final headerBytes = _extractBytes(image, headerBits, hasAlpha);

      if (headerBytes == null) return false;

      // Check magic bytes
      for (int i = 0; i < _magicBytes.length; i++) {
        if (headerBytes[i] != _magicBytes[i]) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Convert generation params to a clean metadata map for encoding
  Map<String, dynamic> paramsToMetadata({
    required String prompt,
    String? negativePrompt,
    String? model,
    int? width,
    int? height,
    int? steps,
    double? cfgScale,
    int? seed,
    String? sampler,
    String? scheduler,
    Map<String, dynamic>? extra,
  }) {
    final metadata = <String, dynamic>{
      'prompt': prompt,
      if (negativePrompt != null && negativePrompt.isNotEmpty)
        'negative_prompt': negativePrompt,
      if (model != null) 'model': model,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (steps != null) 'steps': steps,
      if (cfgScale != null) 'cfg_scale': cfgScale,
      if (seed != null) 'seed': seed,
      if (sampler != null) 'sampler': sampler,
      if (scheduler != null) 'scheduler': scheduler,
      if (extra != null) ...extra,
      // Add timestamp and version
      'generated_at': DateTime.now().toIso8601String(),
      'stealth_version': 1,
    };
    return metadata;
  }

  /// Extract bytes from image LSBs
  Uint8List? _extractBytes(img.Image image, int totalBits, bool hasAlpha) {
    final byteCount = (totalBits / 8).ceil();
    final bytes = Uint8List(byteCount);
    int bitIndex = 0;

    for (int y = 0; y < image.height && bitIndex < totalBits; y++) {
      for (int x = 0; x < image.width && bitIndex < totalBits; x++) {
        final pixel = image.getPixel(x, y);

        // Extract bits from LSBs
        if (bitIndex < totalBits) {
          _setBit(bytes, bitIndex++, pixel.r.toInt() & 1);
        }
        if (bitIndex < totalBits) {
          _setBit(bytes, bitIndex++, pixel.g.toInt() & 1);
        }
        if (bitIndex < totalBits) {
          _setBit(bytes, bitIndex++, pixel.b.toInt() & 1);
        }
        if (hasAlpha && bitIndex < totalBits) {
          _setBit(bytes, bitIndex++, pixel.a.toInt() & 1);
        }
      }
    }

    return bytes;
  }

  /// Get a specific bit from a byte array
  int _getBit(Uint8List bytes, int bitIndex) {
    final byteIndex = bitIndex ~/ 8;
    final bitOffset = 7 - (bitIndex % 8); // MSB first
    return (bytes[byteIndex] >> bitOffset) & 1;
  }

  /// Set a specific bit in a byte array
  void _setBit(Uint8List bytes, int bitIndex, int value) {
    final byteIndex = bitIndex ~/ 8;
    final bitOffset = 7 - (bitIndex % 8); // MSB first
    if (value == 1) {
      bytes[byteIndex] |= (1 << bitOffset);
    } else {
      bytes[byteIndex] &= ~(1 << bitOffset);
    }
  }

  /// Encode a single bit into a channel value's LSB
  int _encodeBit(int channelValue, int bit) {
    return (channelValue & 0xFE) | bit;
  }
}

/// Extension methods for easy metadata encoding/decoding on Uint8List
extension StealthMetadataExtension on Uint8List {
  /// Encode metadata into this image
  Uint8List? encodeStealthMetadata(Map<String, dynamic> metadata) {
    return StealthMetadataService().encodeMetadata(this, metadata);
  }

  /// Decode metadata from this image
  Map<String, dynamic>? decodeStealthMetadata() {
    return StealthMetadataService().decodeMetadata(this);
  }

  /// Check if this image has stealth metadata
  bool hasStealthMetadata() {
    return StealthMetadataService().hasStealthMetadata(this);
  }
}
