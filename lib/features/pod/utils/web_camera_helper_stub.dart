import 'dart:typed_data';

// Stub implementation for non-web platforms (iOS, Android, Desktop).
// WebCameraHelper uses dart:html which is not available on native platforms.
// These stubs ensure the file compiles without errors on iOS/Android.

class WebCameraHelper {
  Future<Uint8List?> captureFromCamera() async {
    // Not supported on native platforms — use image_picker instead.
    return null;
  }

  Future<List<WebImage>> pickFromGallery() async {
    // Not supported on native platforms — use image_picker instead.
    return [];
  }
}

class WebImage {
  final Uint8List bytes;
  final String filename;

  WebImage({required this.bytes, required this.filename});
}
