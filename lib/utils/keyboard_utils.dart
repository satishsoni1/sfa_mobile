import 'package:flutter/material.dart';
import 'dart:html' as html;

class KeyboardUtils {
  static void initKeyboardListener(BuildContext context) {
    html.window.onResize.listen((event) {
      FocusScope.of(context).unfocus();
    });
  }
}