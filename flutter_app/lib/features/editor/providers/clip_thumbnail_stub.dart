import 'dart:typed_data';

import '../models/editor_models.dart';

/// Stub implementation - should never be called
Future<List<Uint8List>> extractThumbnails({
  required EditorClip clip,
  required int thumbnailCount,
  required int thumbnailHeight,
}) async {
  print('[STUB] ERROR: Stub thumbnail implementation called! Platform detection failed.');
  throw UnsupportedError('Platform not supported for thumbnail extraction');
}
