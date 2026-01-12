// Web implementation for file picking with Object URLs
// This file is only imported on web platform via conditional import
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';

/// Pick files using native HTML input and return Object URLs
/// This avoids loading entire file bytes into memory for large files
Future<List<({String name, String blobUrl})>> pickFilesForWeb() async {
  final completer = Completer<List<({String name, String blobUrl})>>();
  
  // Create hidden file input
  final input = html.FileUploadInputElement()
    ..accept = '.mp4,.webm,.mov,.mkv,.avi,.gif,.png,.jpg,.jpeg,.webp,.bmp,.tiff'
    ..multiple = true;
  
  // Listen for file selection
  input.onChange.listen((event) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete([]);
      return;
    }
    
    final result = <({String name, String blobUrl})>[];
    for (final file in files) {
      // Create Object URL - this doesn't load bytes into memory!
      final blobUrl = html.Url.createObjectUrlFromBlob(file);
      print('DEBUG: Created blob URL for ${file.name}: $blobUrl (${file.size} bytes)');
      result.add((name: file.name, blobUrl: blobUrl));
    }
    
    completer.complete(result);
  });
  
  // Trigger file picker dialog
  input.click();
  
  return completer.future;
}
