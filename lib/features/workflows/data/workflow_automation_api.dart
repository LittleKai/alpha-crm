import 'dart:convert';

import 'package:http/http.dart' as http;

import 'workflow_models.dart';

class WorkflowAutomationApi {
  final String baseUrl;
  final http.Client _client;

  WorkflowAutomationApi({required String baseUrl, http.Client? client})
    : baseUrl = normalizeUrl(baseUrl),
      _client = client ?? http.Client();

  static String normalizeUrl(String url) {
    var cleaned = url.trim();
    if (cleaned.isEmpty) return 'http://127.0.0.1:28080';
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'http://$cleaned';
    }
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }

  Future<Map<String, dynamic>> fetchN8nSettings() async {
    return _get('/api/integrations/n8n/settings');
  }

  Future<Map<String, dynamic>> saveN8nSettings({
    required bool enabled,
    required String baseUrl,
    required String apiKey,
    required String eventWebhookUrl,
    required String callbackUrl,
  }) async {
    return _post('/api/integrations/n8n/settings', {
      'n8n': {
        'enabled': enabled,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'eventWebhookUrl': eventWebhookUrl,
        'callbackUrl': callbackUrl,
      },
    });
  }

  Future<Map<String, dynamic>> saveEmailSettings({
    required Map<String, dynamic> email,
  }) async {
    return _post('/api/integrations/n8n/settings', {'email': email});
  }

  Future<Map<String, dynamic>> saveFacebookSettings({
    required Map<String, dynamic> facebook,
  }) async {
    return _post('/api/integrations/n8n/settings', {'facebook': facebook});
  }

  Future<Map<String, dynamic>> testN8nConnection({
    required String baseUrl,
    required String apiKey,
  }) async {
    return _post('/api/integrations/n8n/test', {
      'n8n': {'baseUrl': baseUrl, 'apiKey': apiKey},
    });
  }

  Future<Map<String, dynamic>> installTemplate(
    WorkflowTemplateInstallRequest request,
  ) async {
    return _post('/api/integrations/n8n/templates/install', request.toJson());
  }

  Future<Map<String, dynamic>> testProxy(String proxy) async {
    return _post('/api/proxy/test', {'proxy': proxy});
  }

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl$path'))
          .timeout(const Duration(seconds: 10));
      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Map<String, dynamic> _processResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return {
          ...decoded,
          'success': decoded['success'] == true && response.statusCode < 400,
        };
      }
    } catch (_) {}
    return {'success': false, 'error': 'HTTP ${response.statusCode}'};
  }

  void dispose() {
    _client.close();
  }
}
