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

  /// Upload an operator-attached knowledge file to the LOCAL bridge store.
  /// Returns `{id, name, size}`; the content-hash `id` is what the config keeps.
  Future<Map<String, dynamic>> uploadKnowledgeFile({
    required String filename,
    required List<int> bytes,
  }) async {
    final response = await _client
        .post(
          _baseUri.resolve('/local/chatbot/knowledge-file'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'filename': filename,
            'base64': base64Encode(bytes),
          }),
        )
        .timeout(const Duration(seconds: 30));
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true ||
        body['data'] is! Map) {
      throw Exception(
        body['error'] ?? body['message'] ?? 'Local bridge upload failed.',
      );
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  /// Ids of knowledge files currently present on this machine (for "missing
  /// file" warnings in the knowledge tab). Returns an empty set if unreachable.
  Future<Set<String>> listKnowledgeFileIds() async {
    try {
      final response = await _client
          .get(_baseUri.resolve('/local/chatbot/knowledge-files'))
          .timeout(const Duration(seconds: 3));
      final body = response.body.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      if (response.statusCode == 200 && body['data'] is Map) {
        final ids = (body['data'] as Map)['ids'];
        if (ids is List) {
          return ids.map((e) => e.toString()).toSet();
        }
      }
      return <String>{};
    } catch (_) {
      return <String>{};
    }
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
