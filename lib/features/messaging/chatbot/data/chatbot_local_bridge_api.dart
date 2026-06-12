import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatbotBridgeStatus {
  final bool running;
  final String? configVersion;
  final DateTime? lastSyncedAt;
  final String? lastError;
  final int pendingAudits;

  const ChatbotBridgeStatus({
    required this.running,
    this.configVersion,
    this.lastSyncedAt,
    this.lastError,
    required this.pendingAudits,
  });

  factory ChatbotBridgeStatus.fromJson(Map<String, dynamic> json) {
    final syncedAt = int.tryParse((json['lastSyncedAt'] ?? '').toString());
    return ChatbotBridgeStatus(
      running: json['running'] == true,
      configVersion: json['configVersion']?.toString(),
      lastSyncedAt: syncedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(syncedAt),
      lastError: json['lastError']?.toString(),
      pendingAudits: int.tryParse((json['pendingAudits'] ?? 0).toString()) ?? 0,
    );
  }
}

class ChatbotLocalBridgeApi {
  final Uri _baseUri;
  final http.Client _client;

  ChatbotLocalBridgeApi({
    String baseUrl = 'http://127.0.0.1:8787',
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl),
       _client = client ?? http.Client();

  Future<ChatbotBridgeStatus> getStatus() async {
    return _statusFrom(
      await _client
          .get(_baseUri.resolve('/local/chatbot/status'))
          .timeout(const Duration(seconds: 3)),
    );
  }

  Future<ChatbotBridgeStatus> syncNow() async {
    return _statusFrom(
      await _client
          .post(_baseUri.resolve('/local/chatbot/sync'))
          .timeout(const Duration(seconds: 12)),
    );
  }

  ChatbotBridgeStatus _statusFrom(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true ||
        body['data'] is! Map) {
      throw Exception(
        body['error'] ?? body['message'] ?? 'Local chatbot bridge unavailable.',
      );
    }
    return ChatbotBridgeStatus.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }
}
