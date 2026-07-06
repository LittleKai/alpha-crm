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

  Future<Map<String, dynamic>> fetchFacebookAccounts() async {
    return _get('/api/integrations/facebook/accounts');
  }

  Future<Map<String, dynamic>> saveFacebookAccount(
    Map<String, dynamic> account,
  ) async {
    return _post('/api/integrations/facebook/accounts', account);
  }

  Future<Map<String, dynamic>> deleteFacebookAccount(String pageId) async {
    return _delete('/api/integrations/facebook/accounts/$pageId');
  }

  Future<Map<String, dynamic>> fetchTiktokAccounts() async {
    return _get('/api/integrations/tiktok/accounts');
  }

  Future<Map<String, dynamic>> saveTiktokAccount(
    Map<String, dynamic> account,
  ) async {
    return _post('/api/integrations/tiktok/accounts', account);
  }

  Future<Map<String, dynamic>> deleteTiktokAccount(String accountId) async {
    return _delete('/api/integrations/tiktok/accounts/$accountId');
  }

  Future<Map<String, dynamic>> fetchInstagramAccounts() async {
    return _get('/api/integrations/instagram/accounts');
  }

  Future<Map<String, dynamic>> saveInstagramAccount(
    Map<String, dynamic> account,
  ) async {
    return _post('/api/integrations/instagram/accounts', account);
  }

  Future<Map<String, dynamic>> deleteInstagramAccount(String accountId) async {
    return _delete('/api/integrations/instagram/accounts/$accountId');
  }

  Future<Map<String, dynamic>> fetchWhatsappAccounts() async {
    return _get('/api/integrations/whatsapp/accounts');
  }

  Future<Map<String, dynamic>> saveWhatsappAccount(
    Map<String, dynamic> account,
  ) async {
    return _post('/api/integrations/whatsapp/accounts', account);
  }

  Future<Map<String, dynamic>> deleteWhatsappAccount(String accountId) async {
    return _delete('/api/integrations/whatsapp/accounts/$accountId');
  }

  Future<Map<String, dynamic>> fetchTelegramBots() async {
    return _get('/api/integrations/telegram/accounts');
  }

  Future<Map<String, dynamic>> saveTelegramBot(
    Map<String, dynamic> bot,
  ) async {
    return _post('/api/integrations/telegram/accounts', bot);
  }

  Future<Map<String, dynamic>> deleteTelegramBot(String accountId) async {
    return _delete('/api/integrations/telegram/accounts/$accountId');
  }

  Future<Map<String, dynamic>> fetchWebchatWidgets() async {
    return _get('/api/integrations/webchat/accounts');
  }

  Future<Map<String, dynamic>> saveWebchatWidget(
    Map<String, dynamic> widget,
  ) async {
    return _post('/api/integrations/webchat/accounts', widget);
  }

  Future<Map<String, dynamic>> deleteWebchatWidget(String widgetId) async {
    return _delete('/api/integrations/webchat/accounts/$widgetId');
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

  Future<Map<String, dynamic>> fetchAutomationRules() async {
    return _get('/local/automation/rules');
  }

  Future<Map<String, dynamic>> saveAutomationRules(
    List<Map<String, dynamic>> rules,
  ) async {
    return _put('/local/automation/rules', {'rules': rules});
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

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .put(
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

  Future<Map<String, dynamic>> _delete(String path) async {
    try {
      final response = await _client
          .delete(Uri.parse('$baseUrl$path'))
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
