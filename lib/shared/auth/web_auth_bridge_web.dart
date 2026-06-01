// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/foundation.dart';

void setupWebAuthListener({required Function(String token) onTokenReceived}) {
  debugPrint('[WebAuthBridge] Initializing Web SSO Listener...');

  html.window.addEventListener('message', (html.Event event) {
    if (event is html.MessageEvent) {
      final data = event.data;
      final parsedData = _parseMessage(data);
      if (parsedData == null) return;

      if (parsedData['type'] == 'AUTH_TOKEN' && parsedData['token'] != null) {
        final String token = parsedData['token'].toString();
        debugPrint('[WebAuthBridge] Token received from parent window.');
        onTokenReceived(token);
      }
    }
  });

  // Gửi AUTH_READY lên parent window để parent gửi token xuống
  if (html.window.parent != html.window) {
    html.window.parent?.postMessage(jsonEncode({'type': 'AUTH_READY'}), '*');
    // Also post it as raw Map just in case
    html.window.parent?.postMessage({'type': 'AUTH_READY'}, '*');
    debugPrint('[WebAuthBridge] Sent AUTH_READY to parent window.');
  }
}

Map<String, dynamic>? _parseMessage(dynamic data) {
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  if (data is String) {
    final trimmed = data.trimLeft();
    if (!trimmed.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
  }
  return null;
}
