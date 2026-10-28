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
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/crm_auth_token_store.dart';
import 'crm_cloud_api.dart';

enum SseConnectionState { connecting, connected, disconnected }

enum CrmConnectionLogLevel { info, warn, error }

@immutable
class CrmConnectionLogEntry {
  final DateTime timestamp;
  final CrmConnectionLogLevel level;
  final String code;
  final String? detail;

  const CrmConnectionLogEntry({
    required this.timestamp,
    required this.level,
    required this.code,
    this.detail,
  });
}

final RegExp _bearerTokenPattern = RegExp(
  r'Bearer\s+[A-Za-z0-9._~+/=-]+',
  caseSensitive: false,
);
final RegExp _jwtShapePattern = RegExp(
  r'\beyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}\b',
);
final RegExp _jsonSecretFieldPattern = RegExp(
  r'"(qrToken|pairingToken|pairingCode|code|accessToken|refreshToken|token|cookie|zpw_sek)"\s*:\s*"[^"]*"',
  caseSensitive: false,
);
final RegExp _querySecretParamPattern = RegExp(
  r'\b(qrToken|pairingToken|pairingCode|code|access_token|refresh_token|token|cookie|zpw_sek)=([^\s&"#;]+)',
  caseSensitive: false,
);
final RegExp _longHexPattern = RegExp(r'\b[0-9a-fA-F]{32,}\b');
final RegExp _emailPattern = RegExp(
  r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
);
final RegExp _vnPhonePattern = RegExp(
  r'(?<![0-9A-Za-z])(?:\+?84|0)\d{8,10}\b',
);

/// Scrubs credentials, pairing tokens/codes, JWTs, cookies, long hex secrets,
/// emails, and phone numbers from diagnostic text before it enters memory logs
/// or the user's clipboard.
String redactConnectionLogText(String input) {
  if (input.isEmpty) return input;
  var out = input;
  out = out.replaceAll(_bearerTokenPattern, 'Bearer [REDACTED]');
  out = out.replaceAll(_jwtShapePattern, '[REDACTED_JWT]');
  out = out.replaceAllMapped(
    _jsonSecretFieldPattern,
    (m) => '"${m.group(1)}":"[REDACTED]"',
  );
  out = out.replaceAllMapped(
    _querySecretParamPattern,
    (m) => '${m.group(1)}=[REDACTED]',
  );
  out = out.replaceAll(_longHexPattern, '[REDACTED_HEX]');
  out = out.replaceAll(_emailPattern, '[REDACTED_EMAIL]');
  out = out.replaceAll(_vnPhonePattern, '[REDACTED_PHONE]');
  return out;
}

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

  final http.Client Function() _httpClientFactory;
  final Future<String?> Function() _tokenProvider;
  final String Function() _baseUrlProvider;
  final Duration idleTimeout;
  final Duration connectTimeout;
  final int maxLogEntries;
  final DateTime Function() _clock;

  http.Client? _httpClient;
  StreamController<CrmSseEvent>? _controller;
  Timer? _reconnectTimer;
  Timer? _watchdogTimer;
  int _generation = 0;
  int _reconnectAttempts = 0;
  bool _disposed = false;
  bool _connecting = false;
  String _lastEventId = '';
  DateTime? _lastConnectedAt;
  String? _lastError;
  int? _lastHttpStatus;
  final ListQueue<CrmConnectionLogEntry> _logs =
      ListQueue<CrmConnectionLogEntry>();

  final ValueNotifier<SseConnectionState> connectionState =
      ValueNotifier<SseConnectionState>(SseConnectionState.disconnected);

  final ValueNotifier<bool> pausedState = ValueNotifier<bool>(false);

  final ValueNotifier<List<CrmConnectionLogEntry>> connectionLog =
      ValueNotifier<List<CrmConnectionLogEntry>>(
        const <CrmConnectionLogEntry>[],
      );

  CrmSseClient({
    http.Client Function()? httpClientFactory,
    Future<String?> Function()? tokenProvider,
    String Function()? baseUrlProvider,
    this.idleTimeout = const Duration(seconds: 65),
    this.connectTimeout = const Duration(seconds: 20),
    this.maxLogEntries = 100,
    DateTime Function()? clock,
  }) : _httpClientFactory = httpClientFactory ?? http.Client.new,
       _tokenProvider = tokenProvider ?? CrmAuthTokenStore.getToken,
       _baseUrlProvider = baseUrlProvider ?? (() => CrmCloudApi.baseUrl),
       _clock = clock ?? DateTime.now;

  int get reconnectAttempts => _reconnectAttempts;
  DateTime? get lastConnectedAt => _lastConnectedAt;
  String? get lastError => _lastError;
  int? get lastHttpStatus => _lastHttpStatus;
  bool get isPaused => pausedState.value;
  DateTime Function() get clock => _clock;

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

  void _appendLog(
    CrmConnectionLogLevel level,
    String code, [
    String? detail,
  ]) {
    if (maxLogEntries <= 0) return;
    final cleanDetail = detail == null || detail.isEmpty
        ? null
        : _truncate(redactConnectionLogText(detail), 240);
    while (_logs.length >= maxLogEntries) {
      _logs.removeFirst();
    }
    _logs.addLast(
      CrmConnectionLogEntry(
        timestamp: _clock(),
        level: level,
        code: code,
        detail: cleanDetail,
      ),
    );
    connectionLog.value = List<CrmConnectionLogEntry>.unmodifiable(_logs);
  }

  static String _truncate(String value, int maxChars) {
    if (value.length <= maxChars) return value;
    return '${value.substring(0, maxChars)}...';
  }

  void _armWatchdog({
    required int gen,
    required Duration timeout,
    required String timeoutCode,
  }) {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(timeout, () {
      if (_disposed || gen != _generation) return;
      _lastHttpStatus = null;
      _lastError = timeoutCode;
      _appendLog(
        CrmConnectionLogLevel.warn,
        timeoutCode,
        '${timeout.inSeconds}s',
      );
      _teardownConnection();
      _scheduleReconnect();
    });
  }

  void _handleCancel() {
    final controller = _controller;
    if (controller != null && !controller.hasListener) {
      _teardownConnection();
    }
  }

  Future<void> _connect() async {
    if (_disposed || pausedState.value || _connecting) return;
    final gen = ++_generation;
    _connecting = true;
    _reconnectTimer?.cancel();
    final client = _httpClientFactory();
    _httpClient = client;
    _armWatchdog(
      gen: gen,
      timeout: connectTimeout,
      timeoutCode: 'sse.connect_timeout',
    );
    _appendLog(CrmConnectionLogLevel.info, 'sse.connect_start');
    connectionState.value = SseConnectionState.connecting;
    if (_disposed || gen != _generation) {
      client.close();
      return;
    }

    try {
      final token = await _tokenProvider();
      if (_disposed || gen != _generation) {
        client.close();
        return;
      }

      final uri = Uri.parse('${_baseUrlProvider()}/crm/events/subscribe');
      final request = http.Request('GET', uri)
        ..headers['Accept'] = 'text/event-stream';
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (_lastEventId.isNotEmpty) {
        request.headers['Last-Event-ID'] = _lastEventId;
      }

      final response = await client.send(request);
      if (_disposed || gen != _generation) {
        client.close();
        return;
      }

      _lastHttpStatus = response.statusCode;
      if (response.statusCode != 200) {
        final isAuthOrSubError =
            response.statusCode == 401 ||
            response.statusCode == 402 ||
            response.statusCode == 403;
        final msg = 'SSE HTTP ${response.statusCode}';
        _lastError = msg;
        _appendLog(
          isAuthOrSubError
              ? CrmConnectionLogLevel.error
              : CrmConnectionLogLevel.warn,
          'sse.http_error',
          msg,
        );
        _watchdogTimer?.cancel();
        _connecting = false;
        client.close();
        if (_httpClient == client) _httpClient = null;
        _scheduleReconnect();
        return;
      }

      _lastConnectedAt = _clock();
      _lastError = null;
      connectionState.value = SseConnectionState.connected;
      _reconnectAttempts = 0;
      _connecting = false;
      _appendLog(CrmConnectionLogLevel.info, 'sse.connected');
      _armWatchdog(
        gen: gen,
        timeout: idleTimeout,
        timeoutCode: 'sse.idle_timeout',
      );

      final decoder = CrmSseDecoder();
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (_disposed || gen != _generation) {
          client.close();
          return;
        }
        // Reset idle watchdog on every raw line (including `: ping` comments).
        _armWatchdog(
          gen: gen,
          timeout: idleTimeout,
          timeoutCode: 'sse.idle_timeout',
        );
        final event = decoder.addLine(line);
        if (event != null) _emit(event);
      }
      // Server closed the stream normally — reconnect like any other drop.
      if (!_disposed && gen == _generation) {
        _watchdogTimer?.cancel();
        client.close();
        if (_httpClient == client) _httpClient = null;
        _appendLog(CrmConnectionLogLevel.info, 'sse.stream_closed');
        _scheduleReconnect();
      }
    } catch (err) {
      client.close();
      if (_disposed || gen != _generation) return;
      _watchdogTimer?.cancel();
      _connecting = false;
      if (_httpClient == client) _httpClient = null;
      _lastHttpStatus = null;
      final summary = redactConnectionLogText(
        '${err.runtimeType}: $err',
      );
      _lastError = _truncate(summary, 200);
      _appendLog(CrmConnectionLogLevel.warn, 'sse.error', summary);
      _scheduleReconnect();
    }
  }

  void _emit(CrmSseEvent event) {
    if (event.id.isNotEmpty) _lastEventId = event.id;
    _controller?.add(event);
  }

  void _scheduleReconnect() {
    connectionState.value = SseConnectionState.disconnected;
    final controller = _controller;
    if (_disposed ||
        pausedState.value ||
        controller == null ||
        !controller.hasListener) {
      return;
    }
    final delaySeconds = _reconnectDelaysSeconds[_reconnectAttempts.clamp(
      0,
      _reconnectDelaysSeconds.length - 1,
    )];
    _reconnectAttempts++;
    _appendLog(
      CrmConnectionLogLevel.info,
      'sse.reconnect_scheduled',
      '${delaySeconds}s (attempt $_reconnectAttempts)',
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), _connect);
  }

  void _teardownConnection() {
    _generation++;
    _reconnectTimer?.cancel();
    _watchdogTimer?.cancel();
    _connecting = false;
    _httpClient?.close();
    _httpClient = null;
    connectionState.value = SseConnectionState.disconnected;
  }

  /// Suspends the connection without disposing the client (app backgrounded).
  void pause() {
    if (_disposed) return;
    pausedState.value = true;
    _appendLog(CrmConnectionLogLevel.info, 'sse.pause');
    _teardownConnection();
  }

  /// Reopens the connection after [pause] if there are still listeners (app
  /// foregrounded). Idempotent: no-op if already connected or connecting.
  void resume() {
    if (_disposed) return;
    final controller = _controller;
    if (controller == null || !controller.hasListener) {
      pausedState.value = false;
      return;
    }
    if (!pausedState.value && (_httpClient != null || _connecting)) {
      return;
    }
    pausedState.value = false;
    _appendLog(CrmConnectionLogLevel.info, 'sse.resume');
    _reconnectAttempts = 0;
    _connect();
  }

  /// Forces an immediate fresh SSE connection attempt, cancelling any active
  /// stream or backoff delay. Safe no-op when there are no active listeners
  /// or after [dispose].
  void reconnectNow({String reason = 'manual'}) {
    if (_disposed) return;
    _appendLog(CrmConnectionLogLevel.info, 'sse.reconnect_now', reason);
    final controller = _controller;
    if (controller == null || !controller.hasListener) return;
    pausedState.value = false;
    _teardownConnection();
    _reconnectAttempts = 0;
    _connect();
  }

  void dispose() {
    _disposed = true;
    _teardownConnection();
    _controller?.close();
    _controller = null;
  }
}
