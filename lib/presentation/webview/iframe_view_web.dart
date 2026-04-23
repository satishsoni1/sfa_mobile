import 'dart:async';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:universal_html/html.dart' as html;

Widget buildInternalIFrameView({
  required String url,
  required String viewType,
  required VoidCallback onFrameLoaded,
  required ValueChanged<String> onFrameError,
}) {
  final iframe = html.IFrameElement()
    ..src = url
    ..style.border = 'none'
    ..style.width = '100%'
    ..style.height = '100%'
    ..allow = 'fullscreen';

  StreamSubscription<html.Event>? loadSub;
  StreamSubscription<html.Event>? errorSub;
  Timer? timeoutTimer;
  var completed = false;

  void completeLoaded() {
    if (completed) return;
    completed = true;
    timeoutTimer?.cancel();
    loadSub?.cancel();
    errorSub?.cancel();
    onFrameLoaded();
  }

  void completeError(String message) {
    if (completed) return;
    completed = true;
    timeoutTimer?.cancel();
    loadSub?.cancel();
    errorSub?.cancel();
    onFrameError(message);
  }

  loadSub = iframe.onLoad.listen((_) => completeLoaded());
  errorSub = iframe.onError.listen((_) {
    completeError('Unable to load the page inside the app.');
  });
  timeoutTimer = Timer(const Duration(seconds: 15), () {
    completeError(
      'This page could not be displayed inside the app. It may be blocked by iframe or network restrictions.',
    );
  });

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) => iframe);

  return HtmlElementView(viewType: viewType);
}
