// This file is the entry point for KeyboardUtils.
// It conditionally imports the web or stub implementation at compile time.
// - On web: uses keyboard_utils_web.dart (dart:html available)
// - On iOS / Android / Desktop: uses keyboard_utils_stub.dart (no-op)
// This prevents the dart:html import from breaking native builds.
export 'keyboard_utils_stub.dart'
    if (dart.library.html) 'keyboard_utils_web.dart';
