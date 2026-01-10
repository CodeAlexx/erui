import 'dart:typed_data';

import '../models/editor_models.dart';

/// Stub implementation - should never be called
Future<List<Uint8List>> extractThumbnails({
  required EditorClip clip,
  required int thumbnailCount,
  required int thumbnailHeight,
}) async {
  throw UnsupportedError('Platform not supported for thumbnail extraction');
}
