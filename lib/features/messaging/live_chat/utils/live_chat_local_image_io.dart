import 'dart:io';

import 'package:flutter/material.dart';

Widget buildLiveChatLocalImage(
  String path, {
  BoxFit fit = BoxFit.contain,
  Widget? errorWidget,
}) {
  return Image.file(
    File(path),
    fit: fit,
    errorBuilder: (context, error, stackTrace) {
      return errorWidget ??
          const SizedBox(
            width: 120,
            height: 120,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          );
    },
  );
}
