/// SSE client for the cloud realtime channel (`GET /crm/events/subscribe`).
///
/// Used on platforms with no local Zalo bridge (web, Android, iOS). A single
/// instance is shared across Live Chat, agent-status, and pairing consumers
/// via [CrmSseClient.events] (a broadcast stream) so only one HTTP
/// connection is ever open per signed-in user, respecting the backend's
/// per-user connection cap.
///
/// Streaming works uniformly on IO and web: `package:http` 1.3+'s
/// `BrowserClient` is backed by `fetch()` + `ReadableStream` and delivers
/// response bytes incrementally (verified against the resolved http 1.6.0
/// source — "Responses are streamed"), so no io/web conditional split is
/// needed here.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/crm_auth_token_store.dart';
import 'crm_cloud_api.dart';

enum SseConnectionState { connecting, connected, disconnected }

class CrmSseEvent {
  final String id;
  final String name;
  final Map<String, dynamic> data;

  const CrmSseEvent({required this.id, required this.name, required this.data});
}

/// Pure line-by-line SSE frame decoder (`id:`/`event:`/`data:`, blank line
/// terminates a frame, `:`-prefixed lines are keep-alive comments). Split out
/// from [CrmSseClient] so the parsing logic is unit-testable without a real
/// HTTP connection — mirrors `LiveChatSseDecoder` in live_chat_event.dart.
class CrmSseDecoder {
  String _id = '';
  String _name = '';
  final List<String> _dataLines = [];

  /// Feeds one line; returns a decoded event if the line completed a frame
  /// with valid JSON `data:` payload (invalid JSON frames are dropped).
  CrmSseEvent? addLine(String line) {
    if (line.startsWith(':')) return null; // keep-alive ping/comment
    if (line.isEmpty) {
      if (_dataLines.isEmpty) {
        _reset();
        return null;
      }
      final event = _decode();
      _reset();
      return event;
    }
    if (line.startsWith('id:')) {
      _id = line.substring(3).trim();
    } else if (line.startsWith('event:')) {
      _name = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      _dataLines.add(line.substring(5).trimLeft());
    }
    return null;
  }

  CrmSseEvent? _decode() {
    try {
      final decoded = jsonDecode(_dataLines.join('\n'));
      if (decoded is! Map) return null;
      return CrmSseEvent(
        id: _id,
        name: _name.isEmpty ? 'message' : _name,
        data: Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  void _reset() {
    _id = '';
    _name = '';
    _dataLines.clear();
  }
}

class CrmSseClient {
  static const List<int> _reconnectDelaysSeconds = [1, 2, 5, 10];

  http.Client? _httpClient;
  StreamController<CrmSseEvent>? _controller;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;
  bool _connecting = false;
  String _lastEventId = '';

  final ValueNotifier<SseConnectionState> connectionState =
      ValueNotifier<SseConnectionState>(SseConnectionState.disconnected);

  /// Broadcast stream of decoded server events. The underlying HTTP
  /// connection opens lazily on first listener and closes when the last
  /// listener cancels.
  Stream<CrmSseEvent> get events {
    _controller ??= StreamController<CrmSseEvent>.broadcast(
      onListen: _connect,
      onCancel: _handleCancel,
    );
    return _controller!.stream;
  }

  void _handleCancel() {
    final controller = _controller;
    if (controller != null && !controller.hasListener) {
      _teardownConnection();
    }
  }

  Future<void> _connect() async {
    if (_disposed || _connecting) return;
    _connecting = true;
    connectionState.value = SseConnectionState.connecting;
    _reconnectTimer?.cancel();

    final client = http.Client();
    _httpClient = client;
    try {
      final token = await CrmAuthTokenStore.getToken();
      final uri = Uri.parse('${CrmCloudApi.baseUrl}/crm/events/subscribe');
      final request = http.Request('GET', uri)
        ..headers['Accept'] = 'text/event-stream';
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (_lastEventId.isNotEmpty) {
        request.headers['Last-Event-ID'] = _lastEventId;
      }

      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw http.ClientException('SSE HTTP ${response.statusCode}', uri);
      }

      connectionState.value = SseConnectionState.connected;
      _reconnectAttempts = 0;
      _connecting = false;

      final decoder = CrmSseDecoder();
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (_disposed || _httpClient != client) return;
        final event = decoder.addLine(line);
        if (event != null) _emit(event);
      }
      // Server closed the stream normally — reconnect like any other drop.
      if (!_disposed && _httpClient == client) _scheduleReconnect();
    } catch (_) {
      _connecting = false;
      if (!_disposed && _httpClient == client) _scheduleReconnect();
    }
  }

  void _emit(CrmSseEvent event) {
    if (event.id.isNotEmpty) _lastEventId = event.id;
    _controller?.add(event);
  }

  void _scheduleReconnect() {
    connectionState.value = SseConnectionState.disconnected;
    final controller = _controller;
    if (controller == null || !controller.hasListener) return;
    final delaySeconds = _reconnectDelaysSeconds[_reconnectAttempts.clamp(
      0,
      _reconnectDelaysSeconds.length - 1,
    )];
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), _connect);
  }

  void _teardownConnection() {
    _reconnectTimer?.cancel();
    _connecting = false;
    _httpClient?.close();
    _httpClient = null;
    connectionState.value = SseConnectionState.disconnected;
  }

  /// Suspends the connection without disposing the client (app backgrounded).
  void pause() {
    _teardownConnection();
  }

  /// Reopens the connection after [pause] if there are still listeners (app
  /// foregrounded). Resets backoff so reconnection is immediate.
  void resume() {
    if (_disposed) return;
    final controller = _controller;
    if (controller != null && controller.hasListener) {
      _reconnectAttempts = 0;
      _connect();
    }
  }

  void dispose() {
    _disposed = true;
    _teardownConnection();
    _controller?.close();
    _controller = null;
  }
}
