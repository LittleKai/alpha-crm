import '../../../../../shared/api/crm_cloud_api.dart';

class LiveChatRepository {
  Future<Map<String, dynamic>> getAccounts() {
    return CrmCloudApi.get('/crm/groups/accounts');
  }

  Future<Map<String, dynamic>> getManagedGroups({String? accountId}) {
    final query = <String, String>{'managed': 'true'};
    if (accountId != null && accountId.isNotEmpty) {
      query['accountId'] = accountId;
    }
    final path = Uri(path: '/crm/groups', queryParameters: query).toString();
    return CrmCloudApi.get(path);
  }

  Future<Map<String, dynamic>> getConversations({
    String? accountId,
    String? search,
    int limit = 30,
  }) {
    final query = <String, String>{'limit': limit.toString()};
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

  Future<Map<String, dynamic>> getMessages(
    String conversationId, {
    int limit = 30,
    String? before,
    String? after,
  }) {
    final query = <String, String>{'limit': limit.toString()};
    if (before != null && before.isNotEmpty) query['before'] = before;
    if (after != null && after.isNotEmpty) query['after'] = after;
    final path = Uri(
      path: '/crm/conversations/$conversationId/messages',
      queryParameters: query,
    ).toString();
    return CrmCloudApi.get(path);
  }

  Future<Map<String, dynamic>> clearFailedMessages(String conversationId) {
    return CrmCloudApi.post(
      '/crm/conversations/$conversationId/messages/failed/clear',
      {},
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

  Future<Map<String, dynamic>> sendAttachment(
    String conversationId,
    List<String> attachmentPaths, {
    String content = '',
    String messageType = 'file',
  }) {
    return CrmCloudApi.post(
      '/crm/conversations/$conversationId/send-attachment',
      {
        'content': content,
        'attachments': attachmentPaths,
        'messageType': messageType,
      },
    );
  }

  Future<Map<String, dynamic>> recallMessage(
    String conversationId,
    String messageId,
  ) {
    return CrmCloudApi.post(
      '/crm/conversations/$conversationId/messages/$messageId/recall',
      {},
    );
  }
}
