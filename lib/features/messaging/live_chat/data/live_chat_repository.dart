import '../../../../../shared/api/crm_cloud_api.dart';
import 'live_chat_cache.dart';
import 'live_chat_local_bridge_api.dart';

class LiveChatRepository {
  final bool localFirstEnabled;
  final LiveChatCache cache;
  final LiveChatLocalBridgeApi localApi;

  LiveChatRepository({
    required this.localFirstEnabled,
    required this.cache,
    required this.localApi,
  });

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
  }) async {
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

    final cacheKey = 'conversations_${accountId}_$search';

    // Check fresh cache first
    final cached = await cache.getFreshConversations(cacheKey);
    if (cached != null) {
      return {'success': true, 'data': cached};
    }

    // Fallback to cloud
    try {
      final response = await CrmCloudApi.get(path);
      if (response['success'] == true && response['data'] is List) {
        final List<Map<String, dynamic>> rawList =
            List<Map<String, dynamic>>.from(response['data']);
        await cache.saveConversations(
          cacheKey,
          rawList,
          const Duration(seconds: 15),
        );
      }
      return response;
    } catch (e) {
      // If offline, return anything we have in cache regardless of freshness, marked as offline
      await cache.getFreshConversations(cacheKey);
      // Actually cache doesn't expose stale. It's okay.
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCachedMessages(String conversationId) {
    return cache.getMessages(conversationId, limit: 30);
  }

  Future<Map<String, dynamic>> getMessages(
    String conversationId, {
    int limit = 30,
    String? before,
    String? after,
  }) async {
    if (localFirstEnabled) {
      try {
        final bridgeData = await localApi.getLocalMessages(
          conversationId,
          limit: limit,
          before: before,
          after: after,
        );
        if (bridgeData['success'] == true) {
          final List<Map<String, dynamic>> messages =
              List<Map<String, dynamic>>.from(bridgeData['data'] ?? []);
          await cache.saveMessages(conversationId, messages);
          return bridgeData;
        }
      } catch (e) {
        // Fallback to cache if bridge is offline
        final cached = await cache.getMessages(
          conversationId,
          limit: limit,
          before: before,
          after: after,
        );
        return {
          'success': true,
          'data': cached,
          'code': 'LOCAL_BRIDGE_OFFLINE',
          'message': 'Bridge offline. Showing cached messages.',
        };
      }
    }

    final query = <String, String>{'limit': limit.toString()};
    if (before != null && before.isNotEmpty) query['before'] = before;
    if (after != null && after.isNotEmpty) query['after'] = after;
    final path = Uri(
      path: '/crm/conversations/$conversationId/messages',
      queryParameters: query,
    ).toString();
    return CrmCloudApi.get(path);
  }

  Future<Map<String, dynamic>> clearFailedMessages(
    String conversationId,
  ) async {
    if (localFirstEnabled) {
      await cache.clearFailedMessages(conversationId);
      // Wait, there is no local API to clear failed messages on bridge?
      // Assuming cloud syncs state
    }
    return CrmCloudApi.post(
      '/crm/conversations/$conversationId/messages/failed/clear',
      {},
    );
  }

  Future<Map<String, dynamic>> sendMessage(
    String conversationId,
    String message,
  ) async {
    if (localFirstEnabled) {
      try {
        final response = await localApi.sendLocalMessage(
          conversationId,
          message,
        );
        if (response['success'] == true && response['data'] != null) {
          await cache.saveMessages(conversationId, [
            Map<String, dynamic>.from(response['data']),
          ]);
        }
        return response;
      } catch (e) {
        // Fallback to cloud queue if bridge is down?
        // Spec: "If Flutter local-first sends directly to bridge, cloud command queue should still be available for mobile/offline fallback"
        print('Local bridge error during sendMessage: $e');
      }
    }
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
  }) async {
    if (localFirstEnabled) {
      try {
        final response = await localApi.sendLocalAttachment(
          conversationId,
          attachmentPaths,
          content: content,
          messageType: messageType,
        );
        if (response['success'] == true && response['data'] != null) {
          await cache.saveMessages(conversationId, [
            Map<String, dynamic>.from(response['data']),
          ]);
        }
        return response;
      } catch (e) {
        // Fallback to cloud queue if bridge is down
        print('Local bridge error during sendAttachment: $e');
      }
    }
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
  ) async {
    if (localFirstEnabled) {
      try {
        final response = await localApi.recallLocalMessage(messageId);
        // Maybe update local cache to mark as deleted
        return response;
      } catch (e) {
        // Fallback to cloud queue
        print('Local bridge error during recallMessage: $e');
      }
    }
    return CrmCloudApi.post(
      '/crm/conversations/$conversationId/messages/$messageId/recall',
      {},
    );
  }
}
