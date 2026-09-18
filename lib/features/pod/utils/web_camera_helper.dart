// Conditional import shim for WebCameraHelper.
// - On web: uses web_camera_helper_web.dart (dart:html available)
// - On iOS / Android / Desktop: uses web_camera_helper_stub.dart (no-op)
// This prevents dart:html from being compiled into native builds.
export 'web_camera_helper_stub.dart'
    if (dart.library.html) 'web_camera_helper_web.dart';
