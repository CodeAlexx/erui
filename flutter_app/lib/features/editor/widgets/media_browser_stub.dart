// Stub implementation for non-web platforms (desktop/mobile)
// This file is used when dart:html is not available

/// Stub - throws error if accidentally called on non-web
Future<List<({String name, String blobUrl})>> pickFilesForWeb() async {
  throw UnsupportedError('pickFilesForWeb is only available on web platform');
}
