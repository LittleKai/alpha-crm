import 'dart:convert';
import 'package:http/http.dart' as http;
import 'live_chat_event.dart';

class LiveChatLocalBridgeApi {
  final String baseUrl;

  LiveChatLocalBridgeApi({this.baseUrl = 'http://127.0.0.1:8787'});

  Future<bool> getLocalHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/local/health'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getLocalMessages(
    String conversationId, {
    int limit = 50,
    String? before,
    String? after,
  }) async {
    try {
      final uri =
          Uri.parse(
            '$baseUrl/local/conversations/$conversationId/messages',
          ).replace(
            queryParameters: {
              'limit': limit.toString(),
              if (before != null) 'before': before,
              if (after != null) 'after': after,
            },
          );

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Bridge error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to reach local bridge: $e');
    }
  }

  Future<Map<String, dynamic>> sendLocalMessage(
    String conversationId,
    String content, {
    String? clientMessageId,
    String messageType = 'text',
    Map<String, dynamic>? quote,
    List<Map<String, dynamic>>? mentions,
    List<Map<String, dynamic>>? styles,
    Map<String, dynamic>? link,
    Map<String, dynamic>? sticker,
    Map<String, dynamic>? video,
    Map<String, dynamic>? voice,
    Map<String, dynamic>? metadata,
    List<String>? attachments,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/local/messages/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'conversationId': conversationId,
              'content': content,
              'messageType': messageType,
              'origin': 'operator',
              if (clientMessageId != null) 'clientMessageId': clientMessageId,
              if (quote != null) 'quote': quote,
              if (mentions != null) 'mentions': mentions,
              if (styles != null) 'styles': styles,
              if (link != null) 'link': link,
              if (sticker != null) 'sticker': sticker,
              if (video != null) 'video': video,
              if (voice != null) 'voice': voice,
              if (metadata != null) 'metadata': metadata,
              if (attachments != null) 'attachments': attachments,
            }),
          )
          .timeout(const Duration(seconds: 5));

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      if (response.statusCode == 200 || decoded['localMessageId'] != null) {
        return decoded;
      }
      throw Exception(
        decoded['error'] ?? 'Bridge error: ${response.statusCode}',
      );
    } catch (e) {
      throw Exception('Failed to send via local bridge: $e');
    }
  }

  Future<Map<String, dynamic>> sendLocalAttachment(
    String conversationId,
    List<String> attachments, {
    String? content,
    String? messageType,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/local/messages/attachments/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'conversationId': conversationId,
              'attachments': attachments,
              if (content != null) 'content': content,
              if (messageType != null) 'messageType': messageType,
              'origin': 'operator',
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      if (response.statusCode == 200 || decoded['localMessageId'] != null) {
        return decoded;
      }
      throw Exception(
        decoded['error'] ?? 'Bridge error: ${response.statusCode}',
      );
    } catch (e) {
      throw Exception('Failed to send attachment via local bridge: $e');
    }
  }

  Future<Map<String, dynamic>> recallLocalMessage(String messageId) async {
    final encodedMessageId = Uri.encodeComponent(messageId);
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/local/messages/$encodedMessageId/recall'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));
      return _decodeResponse(response);
    } catch (e) {
      throw Exception('Failed to recall via local bridge: $e');
    }
  }

  Stream<LiveChatEvent> watchEvents({
    String? accountId,
    String? threadId,
  }) async* {
    final query = <String, String>{
      if (accountId != null && accountId.isNotEmpty) 'accountId': accountId,
      if (threadId != null && threadId.isNotEmpty) 'threadId': threadId,
    };
    final uri = Uri.parse(
      '$baseUrl/local/events',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final client = http.Client();
    try {
      final request = http.Request('GET', uri)
        ..headers['Accept'] = 'text/event-stream';
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Bridge SSE error: ${response.statusCode}');
      }
      final decoder = LiveChatSseDecoder();
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        for (final event in decoder.addLine(line)) {
          yield event;
        }
      }
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> markRead(String conversationId) {
    return _post('/local/conversations/$conversationId/mark-read', const {});
  }

  Future<Map<String, dynamic>> updateChatbotState({
    required String accountId,
    required String threadId,
    required String mode,
    String? reason,
  }) {
    final key = Uri.encodeComponent('$accountId:$threadId');
    return _put('/local/conversations/$key/chatbot', {
      'mode': mode,
      if (reason != null) 'reason': reason,
    });
  }

  Future<Map<String, dynamic>> retryMessage(String messageId) {
    return _post('/local/messages/$messageId/retry', const {});
  }

  Future<Map<String, dynamic>> reactToMessage(
    String messageId,
    String reaction,
  ) {
    return _post(
      '/local/messages/${Uri.encodeComponent(messageId)}/reactions',
      {'reaction': reaction},
    );
  }

  Future<Map<String, dynamic>> sendTyping({
    required String accountId,
    required String threadId,
    required String threadType,
  }) {
    return _post('/local/typing', {
      'accountId': accountId,
      'threadId': threadId,
      'threadType': threadType,
    });
  }

  Future<Map<String, dynamic>> getDraft(
    String accountId,
    String threadId,
  ) async {
    final response = await http
        .get(
          Uri.parse(
            '$baseUrl/local/drafts/${Uri.encodeComponent(accountId)}/${Uri.encodeComponent(threadId)}',
          ),
        )
        .timeout(const Duration(seconds: 5));
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> saveDraft(
    String accountId,
    String threadId,
    String content,
  ) {
    return _put(
      '/local/drafts/${Uri.encodeComponent(accountId)}/${Uri.encodeComponent(threadId)}',
      {'content': content},
    );
  }

  Future<Map<String, dynamic>> searchMessages(
    String query, {
    String? accountId,
    String? threadId,
  }) async {
    final uri = Uri.parse('$baseUrl/local/messages/search').replace(
      queryParameters: {
        'q': query,
        if (accountId != null) 'accountId': accountId,
        if (threadId != null) 'threadId': threadId,
      },
    );
    return _decodeResponse(
      await http.get(uri).timeout(const Duration(seconds: 5)),
    );
  }

  Future<Map<String, dynamic>> messagesAround(String messageId) async {
    final encodedMessageId = Uri.encodeComponent(messageId);
    return _decodeResponse(
      await http
          .get(Uri.parse('$baseUrl/local/messages/$encodedMessageId/around'))
          .timeout(const Duration(seconds: 5)),
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));
    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final data = response.body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _withAbsoluteMediaUrls(data) as Map<String, dynamic>;
    }
    throw Exception(
      data['error'] ??
          data['message'] ??
          'Bridge error: ${response.statusCode}',
    );
  }

  Object? _withAbsoluteMediaUrls(Object? value) {
    if (value is List) return value.map(_withAbsoluteMediaUrls).toList();
    if (value is! Map) return value;
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final item = entry.value;
      if ((key == 'cacheUrl' || key == 'downloadUrl') &&
          item is String &&
          item.startsWith('/')) {
        result[key] = '$baseUrl$item';
      } else {
        result[key] = _withAbsoluteMediaUrls(item);
      }
    }
    return result;
  }
}
