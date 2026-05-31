import 'dart:convert';
import 'package:http/http.dart' as http;

class ZaloIntegrationApi {
  final String baseUrl;
  final http.Client _client;

  ZaloIntegrationApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'status': 'error', 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getZaloStatus() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/zalo/status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {
        'connected': false,
        'mode': 'disconnected',
        'error': 'HTTP ${response.statusCode}',
      };
    } catch (e) {
      return {
        'connected': false,
        'mode': 'disconnected',
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> testSend({
    required String recipientId,
    required String message,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/test-send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'recipientId': recipientId,
              'message': message,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  void dispose() {
    _client.close();
  }
}
