import 'package:flutter/material.dart';

Widget buildLiveChatLocalImage(
  String path, {
  BoxFit fit = BoxFit.contain,
  Widget? errorWidget,
}) {
  return errorWidget ??
      const SizedBox(
        width: 120,
        height: 120,
        child: Center(child: Icon(Icons.image_not_supported_outlined)),
      );
}

bool liveChatLocalFileExists(String path) {
  return false;
}
