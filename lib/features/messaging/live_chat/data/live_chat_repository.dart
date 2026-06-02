import '../../../../../shared/api/crm_cloud_api.dart';

class LiveChatRepository {
  Future<Map<String, dynamic>> getAccounts() {
    return CrmCloudApi.get('/crm/groups/accounts');
  }

  Future<Map<String, dynamic>> getConversations({
    String? accountId,
    String? search,
  }) {
    final query = <String, String>{'limit': '100'};
    if (accountId != null && accountId.isNotEmpty) {
      query['accountId'] = accountId;
    }
    if (search != null && search.isNotEmpty) {
      query['search'] = search;
    }
    final path = Uri(
      path: '/crm/conversations',
      queryParameters: query,
    ).toString();
    return CrmCloudApi.get(path);
  }

  Future<Map<String, dynamic>> getMessages(String conversationId) {
    return CrmCloudApi.get(
      '/crm/conversations/$conversationId/messages?limit=100',
    );
  }

  Future<Map<String, dynamic>> sendMessage(
    String conversationId,
    String message,
  ) {
    return CrmCloudApi.post('/crm/conversations/$conversationId/send', {
      'content': message,
    });
  }

  Future<Map<String, dynamic>> updateConversation(
    String conversationId,
    Map<String, dynamic> data,
  ) {
    return CrmCloudApi.put('/crm/conversations/$conversationId', data);
  }

  Future<Map<String, dynamic>> markRead(String conversationId) {
    return CrmCloudApi.post('/crm/conversations/$conversationId/read', {});
  }
}
