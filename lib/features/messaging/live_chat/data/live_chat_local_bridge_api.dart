import 'dart:convert';
import 'package:http/http.dart' as http;

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
    String content,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/local/messages/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'conversationId': conversationId,
              'content': content,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Bridge error: ${response.statusCode}');
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
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Bridge error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to send attachment via local bridge: $e');
    }
  }

  Future<Map<String, dynamic>> recallLocalMessage(String messageId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/local/messages/$messageId/recall'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Bridge error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to recall via local bridge: $e');
    }
  }
}
