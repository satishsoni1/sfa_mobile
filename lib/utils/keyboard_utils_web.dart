import 'package:flutter/material.dart';
import 'dart:html' as html;

// Web-only implementation of KeyboardUtils.
// Only compiled when dart.library.html is available (web platform only).
class KeyboardUtils {
  static void initKeyboardListener(BuildContext context) {
    html.window.onResize.listen((event) {
      FocusScope.of(context).unfocus();
    });
  }
}
