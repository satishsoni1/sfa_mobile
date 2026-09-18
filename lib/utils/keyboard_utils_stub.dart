import 'package:flutter/material.dart';

// Stub implementation for non-web platforms (iOS, Android, Desktop).
// On these platforms there is no browser window so the listener is a no-op.
class KeyboardUtils {
  static void initKeyboardListener(BuildContext context) {
    // No-op on native platforms — keyboard resize events are handled
    // natively by the Flutter engine on iOS and Android.
  }
}
