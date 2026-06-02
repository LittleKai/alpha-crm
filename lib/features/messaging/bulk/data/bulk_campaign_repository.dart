import '../../../../shared/api/crm_cloud_api.dart';

class BulkCampaignRepository {
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
}
