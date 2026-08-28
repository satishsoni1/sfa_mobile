// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget getCorsImage(String url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
  final viewId = 'cors-img-$url-${DateTime.now().millisecondsSinceEpoch}';
  
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
    final img = html.ImageElement()
      ..src = url
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = fit == BoxFit.contain ? 'contain' : 'cover';
    return img;
  });

  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(viewType: viewId),
  );
}
