import '../../../../../shared/api/crm_cloud_api.dart';

class ChatbotRepository {
  Future<Map<String, dynamic>> getSettings() {
    return CrmCloudApi.get('/crm/chatbot/settings');
  }

  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> settings) {
    return CrmCloudApi.put('/crm/chatbot/settings', settings);
  }

  Future<Map<String, dynamic>> getRules() {
    return CrmCloudApi.get('/crm/chatbot/rules');
  }

  Future<Map<String, dynamic>> createRule({
    required String name,
    String? description,
    required String keyword,
    required String response,
  }) {
    final keywords = keyword
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return CrmCloudApi.post('/crm/chatbot/rules', {
      'name': name,
      'description': description ?? '',
      'keywords': keywords.isEmpty ? [keyword] : keywords,
      'response': response,
      'matchMode': 'contains',
      'isActive': true,
    });
  }

  Future<Map<String, dynamic>> updateRule(
    String id,
    Map<String, dynamic> data,
  ) {
    return CrmCloudApi.put('/crm/chatbot/rules/$id', data);
  }

  Future<Map<String, dynamic>> deleteRule(String id) {
    return CrmCloudApi.delete('/crm/chatbot/rules/$id');
  }

  Future<Map<String, dynamic>> getLogs() {
    return CrmCloudApi.get('/crm/chatbot/logs?limit=100');
  }
}
