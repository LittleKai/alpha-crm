import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_repository.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_cache.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_local_bridge_api.dart';
import 'package:alpha_crm/features/messaging/live_chat/providers/live_chat_provider.dart';
import 'package:alpha_crm/mock/mock_accounts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ChatMessage.fromJson accepts text aliases from Zalo payloads', () {
    final fromText = ChatMessage.fromJson({
      '_id': 'msg-1',
      'senderId': 'user-1',
      'senderName': 'Le Vuong',
      'text': 'Tin nhan thuong khong co link',
      'direction': 'inbound',
      'createdAt': '2026-06-03T08:00:00.000Z',
    });
    final fromMessage = ChatMessage.fromJson({
      '_id': 'msg-2',
      'senderId': 'user-1',
      'senderName': 'Le Vuong',
      'message': 'Noi dung tu field message',
      'direction': 'inbound',
      'createdAt': '2026-06-03T08:01:00.000Z',
    });

    expect(fromText.message, 'Tin nhan thuong khong co link');
    expect(fromMessage.message, 'Noi dung tu field message');
  });

  test(
    'Conversation.fromJson accepts avatar aliases and normalizes image url',
    () {
      final conversation = Conversation.fromJson({
        '_id': 'conv-1',
        'accountId': 'acc-1',
        'threadId': 'thread-1',
        'displayName': 'Le Vuong',
        'avatar': '//avatar.zalo.me/user.jpg',
        'lastMessagePreview': 'Xin chao',
        'updatedAt': '2026-06-03T08:00:00.000Z',
      });

      expect(conversation.customerAvatar, 'https://avatar.zalo.me/user.jpg');
    },
  );

  test('ChatMessage.fromJson reads backend messageType alias', () {
    final message = ChatMessage.fromJson({
      '_id': 'msg-media',
      'senderId': 'user-1',
      'senderName': 'Le Vuong',
      'content': '{"href":"https://example.com","title":"Example"}',
      'messageType': 'link',
      'attachments': [
        {'url': 'https://example.com/image.jpg'},
      ],
      'createdAt': '2026-06-03T08:00:00.000Z',
    });

    expect(message.contentType, 'link');
    expect(message.attachments, isA<List>());
  });

  test(
    'Conversation.fromJson formats raw rich previews instead of leaking JSON',
    () {
      final conversation = Conversation.fromJson({
        '_id': 'conv-link',
        'accountId': 'acc-1',
        'threadId': 'thread-1',
        'displayName': 'Le Vuong',
        'lastMessagePreview':
            '{"title":"Example","description":"Preview text","href":"https://example.com"}',
        'updatedAt': '2026-06-03T08:00:00.000Z',
      });

      expect(conversation.lastMessage, 'Liên kết');
    },
  );

  test('SystemSettings persists theme mode and per-account nicknames', () {
    final settings = MockAccounts.defaultSettings.copyWith(
      appThemeMode: 'dark',
      accountNicknames: const {'acc-1': 'Sale Hà Nội'},
    );

    final restored = SystemSettings.fromJson(settings.toJson());

    expect(restored.appThemeMode, 'dark');
    expect(restored.nicknameForAccount('acc-1'), 'Sale Hà Nội');
    expect(restored.nicknameForAccount('missing'), isNull);
  });

  test(
    'LiveChatNotifier sends without reloading conversations twice',
    () async {
      final repository = _FakeLiveChatRepository();
      final notifier = LiveChatNotifier(repository);
      await Future<void>.delayed(Duration.zero);

      await notifier.loadConversations(loadSelectedMessages: true);
      repository.resetCounters();

      await notifier.sendMessage('Xin chao');

      expect(repository.sendMessageCalls, 1);
      expect(repository.getMessagesCalls, 1);
      expect(repository.getConversationsCalls, 0);
      expect(
        notifier.state.selectedConversation?.messages.last.message,
        'Xin chao',
      );
    },
  );

  test('failed optimistic message keeps the local id for retry', () async {
    final repository = _FakeLiveChatRepository()..failNextSend = true;
    final notifier = LiveChatNotifier(repository);
    await Future<void>.delayed(Duration.zero);
    await notifier.loadConversations(loadSelectedMessages: true);

    await notifier.sendMessage('That bai');
    final failed = notifier.state.selectedConversation!.messages.last;
    expect(failed.id, 'local-failed-1');
    expect(failed.status, 'failed');

    await notifier.retryMessage(failed);
    expect(repository.retriedMessageId, 'local-failed-1');
  });
}

class _FakeLiveChatRepository extends LiveChatRepository {
  _FakeLiveChatRepository()
    : super(
        localFirstEnabled: false,
        cache: LiveChatCache(),
        localApi: LiveChatLocalBridgeApi(baseUrl: ''),
      );

  int getConversationsCalls = 0;
  int getMessagesCalls = 0;
  int sendMessageCalls = 0;
  bool failNextSend = false;
  String? retriedMessageId;

  final conversation = Conversation(
    id: 'conv-1',
    accountId: 'acc-1',
    threadId: 'thread-1',
    threadType: 'user',
    customerName: 'Khach hang',
    customerAvatar: '',
    lastMessage: 'Cu',
    lastMessageTime: DateTime.parse('2026-06-03T08:00:00.000Z'),
    unreadCount: 0,
    tag: '',
    notes: '',
    chatbotEnabled: true,
    messages: const [],
  );

  final _messages = <Map<String, dynamic>>[
    {
      '_id': 'msg-1',
      'senderId': 'thread-1',
      'senderName': 'Khach hang',
      'content': 'Cu',
      'direction': 'inbound',
      'status': 'received',
      'createdAt': '2026-06-03T08:00:00.000Z',
    },
  ];

  void resetCounters() {
    getConversationsCalls = 0;
    getMessagesCalls = 0;
    sendMessageCalls = 0;
  }

  @override
  Future<Map<String, dynamic>> getAccounts() async {
    return {
      'success': true,
      'data': {'accounts': []},
    };
  }

  @override
  Future<Map<String, dynamic>> getManagedGroups({String? accountId}) async {
    return {'success': true, 'data': []};
  }

  @override
  Future<Map<String, dynamic>> getConversations({
    String? accountId,
    String? search,
    int limit = 30,
  }) async {
    getConversationsCalls += 1;
    return {
      'success': true,
      'data': [
        {
          '_id': conversation.id,
          'accountId': conversation.accountId,
          'threadId': conversation.threadId,
          'threadType': conversation.threadType,
          'displayName': conversation.customerName,
          'lastMessagePreview': conversation.lastMessage,
          'updatedAt': conversation.lastMessageTime.toIso8601String(),
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> getMessages(
    String conversationId, {
    int limit = 30,
    String? before,
    String? after,
  }) async {
    getMessagesCalls += 1;
    return {'success': true, 'data': _messages};
  }

  @override
  Future<Map<String, dynamic>> clearFailedMessages(
    String conversationId,
  ) async {
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> sendMessage(
    String conversationId,
    String message,
  ) async {
    sendMessageCalls += 1;
    if (failNextSend) {
      failNextSend = false;
      return {
        'success': false,
        'localMessageId': 'local-failed-$sendMessageCalls',
        'error': 'network error',
      };
    }
    _messages.add({
      '_id': 'msg-send-$sendMessageCalls',
      'senderId': 'operator',
      'senderName': 'Operator',
      'content': message,
      'direction': 'outbound',
      'status': 'queued',
      'createdAt': '2026-06-03T08:01:00.000Z',
    });
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> retryMessage(String messageId) async {
    retriedMessageId = messageId;
    return {'success': false, 'error': 'still offline'};
  }
}
