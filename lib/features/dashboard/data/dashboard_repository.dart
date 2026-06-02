import '../../../shared/api/crm_cloud_api.dart';

class DashboardRepository {
  Future<Map<String, dynamic>> getOverview() async {
    final response = await CrmCloudApi.get('/crm/dashboard/overview');
    return response;
  }

  Future<Map<String, dynamic>> getCampaignPerformance({
    required String range,
  }) async {
    final response = await CrmCloudApi.get(
      '/crm/dashboard/campaign-performance?range=$range',
    );
    return response;
  }

  Future<Map<String, dynamic>> getFunnelAnalytics() {
    return CrmCloudApi.get('/crm/analytics/funnel');
  }

  Future<Map<String, dynamic>> getCampaignAnalytics() {
    return CrmCloudApi.get('/crm/analytics/campaigns');
  }

  Future<Map<String, dynamic>> getChatbotAnalytics() {
    return CrmCloudApi.get('/crm/analytics/chatbot');
  }

  Future<Map<String, dynamic>> getGroupAnalytics() {
    return CrmCloudApi.get('/crm/analytics/groups');
  }
}
