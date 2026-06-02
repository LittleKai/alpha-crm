import '../../../../shared/api/crm_cloud_api.dart';

class ManagedGroupsRepository {
  Future<Map<String, dynamic>> getAccounts() {
    return CrmCloudApi.get('/crm/groups/accounts');
  }

  Future<Map<String, dynamic>> syncGroups({
    String? accountId,
    String? deviceId,
  }) {
    return CrmCloudApi.post('/crm/groups/sync', {
      if (accountId != null && accountId.isNotEmpty) 'accountId': accountId,
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
    });
  }

  Future<Map<String, dynamic>> getGroups({String? accountId, bool? managed}) {
    final query = <String, String>{};
    if (accountId != null && accountId.isNotEmpty) {
      query['accountId'] = accountId;
    }
    if (managed != null) query['managed'] = managed.toString();
    final path = Uri(
      path: '/crm/groups',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
    return CrmCloudApi.get(path);
  }

  Future<Map<String, dynamic>> updateManaged(
    String id, {
    required bool isManaged,
    String summaryCadence = 'daily',
    String notes = '',
  }) {
    return CrmCloudApi.put('/crm/groups/$id/manage', {
      'isManaged': isManaged,
      'summaryCadence': summaryCadence,
      'notes': notes,
    });
  }

  Future<Map<String, dynamic>> getInsights() {
    return CrmCloudApi.get('/crm/groups/insights?status=open');
  }

  Future<Map<String, dynamic>> summarizeGroup(String id) {
    return CrmCloudApi.post('/crm/groups/$id/summarize', {});
  }

  Future<Map<String, dynamic>> getSummaries(String id) {
    return CrmCloudApi.get('/crm/groups/$id/summaries');
  }

  Future<Map<String, dynamic>> exportSummaries({String? groupId}) {
    final query = groupId == null || groupId.isEmpty
        ? null
        : {'groupId': groupId};
    final path = Uri(
      path: '/crm/exports/group-summaries',
      queryParameters: query,
    ).toString();
    return CrmCloudApi.get(path);
  }
}
