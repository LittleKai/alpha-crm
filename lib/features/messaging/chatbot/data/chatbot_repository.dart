import 'package:http/http.dart' as http;

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

  Future<Map<String, dynamic>> uploadKnowledgeFile({
    required String filename,
    required List<int> bytes,
    required String contentType,
  }) async {
    final presignResponse = await CrmCloudApi.post('/upload/presign', {
      'filename': filename,
      'contentType': contentType,
      'folder': 'crm/chatbot-knowledge',
    });
    if (presignResponse['success'] != true || presignResponse['data'] is! Map) {
      return presignResponse;
    }

    final data = Map<String, dynamic>.from(presignResponse['data'] as Map);
    final presignedUrl = data['presignedUrl']?.toString();
    if (presignedUrl == null || presignedUrl.isEmpty) {
      return {'success': false, 'message': 'Backend chưa trả về URL upload.'};
    }

    final uploadResponse = await http.put(
      Uri.parse(presignedUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      return {
        'success': false,
        'message': 'Upload thất bại (${uploadResponse.statusCode}).',
      };
    }

    return {
      'success': true,
      'data': {
        ...data,
        'filename': filename,
        'size': bytes.length,
        'contentType': contentType,
      },
    };
  }
}
