import '../../../../../shared/api/crm_cloud_api.dart';
import 'live_chat_cache.dart';
import 'live_chat_local_bridge_api.dart';
import 'live_chat_event.dart';

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
          final attachments = bridgeData['attachments'] is Map
              ? Map<String, dynamic>.from(bridgeData['attachments'] as Map)
              : <String, dynamic>{};
          final List<Map<String, dynamic>> messages =
              List<Map<String, dynamic>>.from(bridgeData['data'] ?? []).map((
                message,
              ) {
                final id = (message['id'] ?? message['_id'] ?? '').toString();
                return {
                  ...message,
                  if (attachments[id] != null) 'attachments': attachments[id],
                };
              }).toList();
          await cache.saveMessages(conversationId, messages);
          return {...bridgeData, 'data': messages};
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
    // Failed messages remain visible in local-first mode so users can retry.
    if (localFirstEnabled) return {'success': true};
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
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('logged out') ||
            errorString.contains('unauthorized')) {
          throw Exception(
            'Phiên đăng nhập Zalo đã hết hạn hoặc bị đăng xuất từ điện thoại. Vui lòng quét mã QR để kết nối lại Alpha CRM.',
          );
        }
      }
    }

    try {
      return await CrmCloudApi.post('/crm/conversations/$conversationId/send', {
        'content': message,
      });
    } catch (e) {
      final errorString = e.toString();
      if (errorString.contains('Không có thiết bị window') ||
          errorString.contains('ghép đôi')) {
        throw Exception(
          'Tài khoản Zalo đã bị đăng xuất hoặc mất kết nối từ điện thoại. Không thể gửi tin. Vui lòng quét QR để kết nối lại.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendRichMessage(
    String conversationId,
    String message, {
    required String clientMessageId,
    String messageType = 'text',
    Map<String, dynamic>? quote,
    List<Map<String, dynamic>>? mentions,
    List<Map<String, dynamic>>? styles,
    Map<String, dynamic>? link,
    Map<String, dynamic>? sticker,
    Map<String, dynamic>? video,
    Map<String, dynamic>? voice,
    Map<String, dynamic>? metadata,
    List<String>? attachments,
  }) async {
    if (!localFirstEnabled) return sendMessage(conversationId, message);
    return localApi.sendLocalMessage(
      conversationId,
      message,
      clientMessageId: clientMessageId,
      messageType: messageType,
      quote: quote,
      mentions: mentions,
      styles: styles,
      link: link,
      sticker: sticker,
      video: video,
      voice: voice,
      metadata: metadata,
      attachments: attachments,
    );
  }

  Future<Map<String, dynamic>> updateConversation(
    String conversationId,
    Map<String, dynamic> data,
  ) {
    return CrmCloudApi.put('/crm/conversations/$conversationId', data);
  }

  Future<Map<String, dynamic>> markRead(String conversationId) {
    if (localFirstEnabled) return localApi.markRead(conversationId);
    return CrmCloudApi.post('/crm/conversations/$conversationId/read', {});
  }

  Stream<LiveChatEvent> watchEvents({String? accountId, String? threadId}) {
    if (!localFirstEnabled) return const Stream.empty();
    return localApi.watchEvents(accountId: accountId, threadId: threadId);
  }

  Future<Map<String, dynamic>> retryMessage(String messageId) {
    return localApi.retryMessage(messageId);
  }

  Future<Map<String, dynamic>> reactToMessage(
    String messageId,
    String reaction,
  ) {
    return localApi.reactToMessage(messageId, reaction);
  }

  Future<Map<String, dynamic>> sendTyping(ConversationTarget target) {
    return localApi.sendTyping(
      accountId: target.accountId,
      threadId: target.threadId,
      threadType: target.threadType,
    );
  }

  Future<String> getDraft(ConversationTarget target) async {
    if (!localFirstEnabled) return '';
    final response = await localApi.getDraft(target.accountId, target.threadId);
    return (response['content'] ?? '').toString();
  }

  Future<void> saveDraft(ConversationTarget target, String content) async {
    if (!localFirstEnabled) return;
    await localApi.saveDraft(target.accountId, target.threadId, content);
  }

  Future<Map<String, dynamic>> searchMessages(
    String query, {
    String? accountId,
    String? threadId,
  }) {
    return localApi.searchMessages(
      query,
      accountId: accountId,
      threadId: threadId,
    );
  }

  Future<Map<String, dynamic>> messagesAround(String messageId) {
    return localApi.messagesAround(messageId);
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
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('logged out') ||
            errorString.contains('unauthorized')) {
          throw Exception(
            'Phiên đăng nhập Zalo đã hết hạn hoặc bị đăng xuất từ điện thoại. Vui lòng quét mã QR để kết nối lại Alpha CRM.',
          );
        }
      }
    }

    try {
      return await CrmCloudApi.post(
        '/crm/conversations/$conversationId/send-attachment',
        {
          'content': content,
          'attachments': attachmentPaths,
          'messageType': messageType,
        },
      );
    } catch (e) {
      final errorString = e.toString();
      if (errorString.contains('Không có thiết bị window') ||
          errorString.contains('ghép đôi')) {
        throw Exception(
          'Tài khoản Zalo đã bị đăng xuất hoặc mất kết nối từ điện thoại. Không thể gửi file. Vui lòng quét QR để kết nối lại.',
        );
      }
      rethrow;
    }
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

    try {
      return await CrmCloudApi.post(
        '/crm/conversations/$conversationId/messages/$messageId/recall',
        {},
      );
    } catch (e) {
      final errorString = e.toString();
      if (errorString.contains('Không có thiết bị window') ||
          errorString.contains('ghép đôi')) {
        throw Exception(
          'Tài khoản Zalo đã bị đăng xuất hoặc mất kết nối từ điện thoại. Không thể thu hồi tin. Vui lòng quét QR để kết nối lại.',
        );
      }
      rethrow;
    }
  }
}

class ConversationTarget {
  final String accountId;
  final String threadId;
  final String threadType;

  const ConversationTarget({
    required this.accountId,
    required this.threadId,
    required this.threadType,
  });
}
