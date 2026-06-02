import '../../../../shared/api/crm_cloud_api.dart';

class SendHistoryRepository {
  Future<Map<String, dynamic>> getExecutionLogs({
    String? campaignId,
    String? status,
    String? customerId,
    String? search,
    int? page,
    int? limit,
  }) async {
    final queryParams = <String, String>{};
    if (campaignId != null && campaignId.isNotEmpty) {
      queryParams['campaignId'] = campaignId;
    }
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (customerId != null && customerId.isNotEmpty) {
      queryParams['customerId'] = customerId;
    }
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (page != null) queryParams['page'] = page.toString();
    if (limit != null) queryParams['limit'] = limit.toString();

    final path = Uri(
      path: '/crm/execution-logs',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    ).toString();
    final response = await CrmCloudApi.get(path);
    return response;
  }
}
