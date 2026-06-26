import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_cache.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_local_bridge_api.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'recallMessage surfaces local bridge failure in local-first mode',
    () async {
      final repository = LiveChatRepository(
        localFirstEnabled: true,
        cache: LiveChatCache(),
        localApi: _FailingRecallLocalApi(),
      );

      await expectLater(
        repository.recallMessage('conv-1', 'msg-1'),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Thu hồi tin nhắn Zalo thất bại'),
          ),
        ),
      );
    },
  );

  test(
    'reactToMessage forwards provider ID to local bridge in local-first mode',
    () async {
      final localApi = _RecordingReactionLocalApi();
      final repository = LiveChatRepository(
        localFirstEnabled: true,
        cache: LiveChatCache(),
        localApi: localApi,
      );

      final response = await repository.reactToMessage('msg-1', 'heart');

      expect(response['success'], true);
      expect(localApi.reactedMessageId, 'msg-1');
      expect(localApi.reaction, 'heart');
    },
  );

  test(
    'recallMessage forwards the provider message ID in local-first mode',
    () async {
      final localApi = _RecordingRecallLocalApi();
      final repository = LiveChatRepository(
        localFirstEnabled: true,
        cache: LiveChatCache(),
        localApi: localApi,
      );

      final response = await repository.recallMessage(
        'conv-1',
        'provider-msg-1',
      );

      expect(response['success'], true);
      expect(localApi.recalledMessageId, 'provider-msg-1');
    },
  );

  test(
    'getMessages returns local bridge offline instead of falling back to cloud',
    () async {
      final repository = LiveChatRepository(
        localFirstEnabled: false,
        cache: _MemoryLiveChatCache(),
        localApi: _FailingInboxLocalApi(),
      );

      final response = await repository.getMessages('conv-local-offline');

      expect(response['success'], true);
      expect(response['code'], 'LOCAL_BRIDGE_OFFLINE');
      expect(response['data'], isEmpty);
    },
  );

  test(
    'getConversations returns local bridge offline instead of falling back to cloud',
    () async {
      final repository = LiveChatRepository(
        localFirstEnabled: false,
        cache: _MemoryLiveChatCache(),
        localApi: _FailingInboxLocalApi(),
      );

      final response = await repository.getConversations(
        accountId: 'acc-local-offline',
      );

      expect(response['success'], false);
      expect(response['code'], 'LOCAL_BRIDGE_OFFLINE');
    },
  );
}

class _FailingRecallLocalApi extends LiveChatLocalBridgeApi {
  _FailingRecallLocalApi() : super(baseUrl: '');

  @override
  Future<Map<String, dynamic>> recallLocalMessage(String messageId) {
    throw Exception('Cannot recall message: missing provider message ID.');
  }
}

class _FailingInboxLocalApi extends LiveChatLocalBridgeApi {
  _FailingInboxLocalApi() : super(baseUrl: '');

  @override
  Future<Map<String, dynamic>> getLocalMessages(
    String conversationId, {
    int limit = 50,
    String? before,
    String? after,
  }) {
    throw Exception('local bridge offline');
  }

  @override
  Future<Map<String, dynamic>> getLocalConversations({
    String? accountId,
    String? search,
    int limit = 50,
    int offset = 0,
  }) {
    throw Exception('local bridge offline');
  }
}

class _MemoryLiveChatCache extends LiveChatCache {
  @override
  Future<List<Map<String, dynamic>>?> getFreshConversations(String cacheKey) {
    return Future.value(null);
  }

  @override
  Future<List<Map<String, dynamic>>?> getAnyCachedConversations(String cacheKey) {
    return Future.value(null);
  }

  @override
  Future<void> saveConversations(
    String cacheKey,
    List<Map<String, dynamic>> conversations,
    Duration expiry,
  ) async {}

  @override
  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
    String? after,
  }) {
    return Future.value(<Map<String, dynamic>>[]);
  }

  @override
  Future<void> saveMessages(
    String conversationId,
    List<Map<String, dynamic>> messages, {
    bool merge = true,
  }) async {}
}

class _RecordingReactionLocalApi extends LiveChatLocalBridgeApi {
  _RecordingReactionLocalApi() : super(baseUrl: '');

  String? reactedMessageId;
  String? reaction;

  @override
  Future<Map<String, dynamic>> reactToMessage(
    String messageId,
    String reaction,
  ) async {
    reactedMessageId = messageId;
    this.reaction = reaction;
    return {'success': true};
  }
}

class _RecordingRecallLocalApi extends LiveChatLocalBridgeApi {
  _RecordingRecallLocalApi() : super(baseUrl: '');

  String? recalledMessageId;

  @override
  Future<Map<String, dynamic>> recallLocalMessage(String messageId) async {
    recalledMessageId = messageId;
    return {'success': true};
  }
}
