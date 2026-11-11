import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../shared/api/crm_cloud_api.dart';

class BulkCampaignRepository {
  final http.Client? _httpClient;

  BulkCampaignRepository({http.Client? httpClient}) : _httpClient = httpClient;

  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> data) async {
    return await CrmCloudApi.post('/crm/templates', data);
  }

  Future<Map<String, dynamic>> createCampaign(Map<String, dynamic> data) async {
    return await CrmCloudApi.post('/crm/campaigns', data);
  }

  Future<Map<String, dynamic>> startCampaign(
    String campaignId, {
    String? humanApprovedAt,
  }) async {
    final Map<String, dynamic> body = humanApprovedAt != null
        ? {'humanApprovedAt': humanApprovedAt}
        : {};
    return await CrmCloudApi.post('/crm/campaigns/$campaignId/start', body);
  }

  Future<Map<String, dynamic>> cancelCampaign(String campaignId) async {
    return await CrmCloudApi.post('/crm/campaigns/$campaignId/cancel', {});
  }

  Future<Map<String, dynamic>> getCampaignStatus(String campaignId) async {
    return await CrmCloudApi.get('/crm/campaigns/$campaignId/status');
  }

  Future<Map<String, dynamic>?> getLocalInFlightCampaign(
    String campaignId, {
    String bridgeBaseUrl = 'http://127.0.0.1:28080',
  }) async {
    final ownsClient = _httpClient == null;
    final client = _httpClient ?? http.Client();
    try {
      final uri = Uri.parse(bridgeBaseUrl).replace(
        path: '/local/campaigns/in-flight',
        queryParameters: {'campaignId': campaignId},
      );
      final resp = await client
          .get(uri)
          .timeout(const Duration(milliseconds: 1200));
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body);
      if (body is Map<String, dynamic> &&
          body['success'] == true &&
          body['data'] is List &&
          (body['data'] as List).isNotEmpty) {
        final first = (body['data'] as List).first;
        if (first is Map) {
          return Map<String, dynamic>.from(first);
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }
}
