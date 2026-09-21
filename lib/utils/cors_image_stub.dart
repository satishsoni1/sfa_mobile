import 'package:flutter/material.dart';

Widget getCorsImage(
  String url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Map<String, String>? headers,
}) {
  return Image.network(
    url,
    width: width,
    height: height,
    fit: fit,
    headers: headers,
    errorBuilder: (_, __, ___) => Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Center(child: Icon(Icons.broken_image, size: 20, color: Colors.grey)),
    ),
  );
}
