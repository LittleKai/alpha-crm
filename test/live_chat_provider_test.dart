import 'dart:convert';
import 'package:alpha_crm/features/messaging/bulk/data/bulk_campaign_repository.dart';
import 'package:alpha_crm/features/messaging/bulk/providers/bulk_messaging_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_repository.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_cache.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_local_bridge_api.dart';
import 'package:alpha_crm/features/messaging/live_chat/providers/live_chat_provider.dart';
import 'package:alpha_crm/features/messaging/live_chat/utils/live_chat_attachment_view.dart';
import 'package:alpha_crm/features/zalo_integration/data/zalo_integration_api.dart';
import 'package:alpha_crm/mock/mock_accounts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  test('Conversation.fromJson prefers cloudConversationId as the id', () {
    final synced = Conversation.fromJson({
      'id': 'local-uuid-1',
      'cloudConversationId': 'cloud-conv-1',
      'accountId': 'acc-1',
      'threadId': 'thread-1',
      'displayName': 'Le Vuong',
    });
    final unsynced = Conversation.fromJson({
      'id': 'local-uuid-2',
      'cloudConversationId': '',
      'accountId': 'acc-1',
      'threadId': 'thread-2',
      'displayName': 'Le Vuong',
    });

    expect(synced.id, 'cloud-conv-1');
    expect(unsynced.id, 'local-uuid-2');
  });

  test('Conversation.fromJson keeps multiple labels from tags', () {
    final conversation = Conversation.fromJson({
      'id': 'local-uuid-labels',
      'accountId': 'acc-1',
      'threadId': 'thread-labels',
      'displayName': 'Le Vuong',
      'tags': ['khach nong', 'da chot'],
    });

    expect(conversation.tag, 'khach nong');
    expect(conversation.displayLabels, ['khach nong', 'da chot']);
  });

  test(
    'Conversation.fromJson maps custom attributes from supported aliases',
    () {
      final fromCustomFields = Conversation.fromJson({
        'id': 'conv-fields',
        'accountId': 'acc-1',
        'threadId': 'thread-fields',
        'displayName': 'Le Vuong',
        'customFields': {'budget': 100, 'source': null},
      });
      final fromAttributes = Conversation.fromJson({
        'id': 'conv-attrs',
        'accountId': 'acc-1',
        'threadId': 'thread-attrs',
        'displayName': 'Le Vuong',
        'attributes': {'stage': 'qualified'},
      });

      expect(fromCustomFields.customAttributes, {
        'budget': '100',
        'source': '',
      });
      expect(fromAttributes.customAttributes, {'stage': 'qualified'});
    },
  );

  test('LiveChatState filters conversations by label and unread state', () {
    final hot = _conversation(
      id: 'hot',
      unreadCount: 2,
      labels: const ['khach nong'],
    );
    final closed = _conversation(id: 'closed', labels: const ['da chot']);
    final unlabelled = _conversation(id: 'plain');
    final state = LiveChatState.initial().copyWith(
      conversations: [hot, closed, unlabelled],
      selectedLabelFilter: 'khach nong',
      unreadOnlyFilter: true,
    );

    expect(state.availableLabels, ['da chot', 'khach nong']);
    expect(state.filteredConversations, [hot]);
  });

  test('LiveChatState filters conversations by inbox workflow status', () {
    final active = _conversation(id: 'active');
    final unread = _conversation(id: 'unread', unreadCount: 2);
    final followUp = _conversation(
      id: 'follow-up',
      followUpAt: DateTime(2026, 7, 2, 9),
    );
    final archived = _conversation(id: 'archived', archived: true);
    final assigned = _conversation(id: 'assigned', assignedTo: 'me');
    final state = LiveChatState.initial().copyWith(
      conversations: [active, unread, followUp, archived, assigned],
    );

    expect(state.filteredConversations, [active, unread, followUp, assigned]);
    expect(
      state
          .copyWith(inboxStatusFilter: InboxStatusFilter.followUp)
          .filteredConversations,
      [followUp],
    );
    expect(
      state
          .copyWith(inboxStatusFilter: InboxStatusFilter.archived)
          .filteredConversations,
      [archived],
    );
    expect(
      state
          .copyWith(inboxStatusFilter: InboxStatusFilter.assigned)
          .filteredConversations,
      [assigned],
    );
  });

  test('LiveChatNotifier saves and reapplies conversation filters', () async {
    final notifier = LiveChatNotifier(_FakeLiveChatRepository());
    await Future<void>.delayed(Duration.zero);

    notifier.saveCurrentFilter('No filters');
    expect(notifier.state.savedFilters, isEmpty);

    notifier.setLabelFilter('khach nong');
    notifier.setUnreadOnlyFilter(true);
    notifier.saveCurrentFilter(' Hot unread ');

    final filter = notifier.state.savedFilters.single;
    expect(filter.name, 'Hot unread');
    expect(filter.label, 'khach nong');
    expect(filter.unreadOnly, isTrue);
    expect(notifier.state.selectedSavedFilterId, filter.id);

    notifier.clearConversationFilters();
    expect(notifier.state.hasActiveConversationFilters, isFalse);

    notifier.applySavedFilter(filter);
    expect(notifier.state.selectedLabelFilter, 'khach nong');
    expect(notifier.state.unreadOnlyFilter, isTrue);
    expect(notifier.state.selectedSavedFilterId, filter.id);
  });

  test('ChatMessage.fromJson treats an empty quote object as no quote', () {
    final noQuote = ChatMessage.fromJson({
      '_id': 'msg-q1',
      'senderId': 'user-1',
      'senderName': 'Le Vuong',
      'content': 'Bao nhieu',
      'direction': 'inbound',
      'quoteJson': '{}',
      'createdAt': '2026-06-16T12:14:00.000Z',
    });
    final withQuote = ChatMessage.fromJson({
      '_id': 'msg-q2',
      'senderId': 'user-1',
      'senderName': 'Le Vuong',
      'content': 'Tra loi',
      'direction': 'inbound',
      'quoteJson': '{"content":"Tin nhan goc"}',
      'createdAt': '2026-06-16T12:15:00.000Z',
    });

    expect(noQuote.quote, isNull);
    expect(withQuote.quote, isNotNull);
    expect(withQuote.quote!['content'], 'Tin nhan goc');
  });

  test('ChatMessage.fromJson uses receivedAt when sentAt is an empty string', () {
    // Inbound bridge rows carry sentAt = '' (empty, not null). A `??` chain
    // would stop there and fall back to now; the parsed time must instead come
    // from receivedAt so old inbound messages keep their real chronological slot.
    final inbound = ChatMessage.fromJson({
      '_id': 'msg-t1',
      'senderId': 'cust-1',
      'content': 'Bao nhieu',
      'direction': 'inbound',
      'sentAt': '',
      'receivedAt': '2026-06-15T08:03:01.474Z',
      'createdAt': '2026-06-15T08:03:01.359Z',
    });

    expect(
      inbound.timestamp.toUtc().toIso8601String(),
      '2026-06-15T08:03:01.474Z',
    );
  });

  test('ChatMessage.isFromBot reflects the chatbot metadata source', () {
    final fromBot = ChatMessage.fromJson({
      '_id': 'msg-b1',
      'senderId': 'acc-1',
      'content': 'Da chao ban',
      'direction': 'outbound',
      'metadataJson': '{"source":"chatbot"}',
      'createdAt': '2026-06-16T12:14:00.000Z',
    });
    final fromOperator = ChatMessage.fromJson({
      '_id': 'msg-b2',
      'senderId': 'acc-1',
      'content': 'Da chao ban',
      'direction': 'outbound',
      'metadataJson': '{}',
      'createdAt': '2026-06-16T12:15:00.000Z',
    });

    expect(fromBot.isFromBot, isTrue);
    expect(fromOperator.isFromBot, isFalse);
  });

  test('Conversation.fromJson unwraps the bridge lastMessagePreview envelope', () {
    final textPreview = Conversation.fromJson({
      'id': 'local-uuid-3',
      'accountId': 'acc-1',
      'threadId': 'thread-3',
      'displayName': 'Tan Thanh',
      'lastMessagePreview':
          '{"direction":"outbound","messageType":"text","content":"Da chao ban"}',
    });
    final stickerPreview = Conversation.fromJson({
      'id': 'local-uuid-4',
      'accountId': 'acc-1',
      'threadId': 'thread-4',
      'displayName': 'Tan Thanh',
      'lastMessagePreview':
          '{"direction":"inbound","messageType":"sticker","content":"{\\"id\\":34840}"}',
    });

    expect(textPreview.lastMessage, 'Da chao ban');
    expect(stickerPreview.lastMessage, 'Sticker');
  });

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

  test('Conversation.fromJson formats nested attachment preview JSON', () {
    final conversation = Conversation.fromJson({
      '_id': 'conv-file',
      'accountId': 'acc-1',
      'threadId': 'thread-1',
      'displayName': 'Le Vuong',
      'lastMessagePreview':
          '{"direction":"outbound","content":"{\\"title\\":\\"SPEC.md\\",\\"description\\":\\"Markdown spec\\",\\"params\\":\\"{\\\\\\"fileExt\\\\\\":\\\\\\"md\\\\\\",\\\\\\"fileSize\\\\\\":\\\\\\"2048\\\\\\"}\\"}"}',
      'updatedAt': '2026-06-03T08:00:00.000Z',
    });

    expect(conversation.lastMessage.contains('{'), isFalse);
    expect(conversation.lastMessage.contains('SPEC.md'), isFalse);
  });

  test('attachment view resolves local image attachments', () {
    final message = ChatMessage.fromJson({
      '_id': 'msg-image',
      'content': '',
      'messageType': 'image',
      'attachments': [
        {
          'kind': 'image',
          'name': 'photo.png',
          'localPath': r'D:\tmp\photo.png',
          'url': r'D:\tmp\photo.png',
        },
      ],
      'createdAt': '2026-06-03T08:00:00.000Z',
    });

    final view = resolveLiveChatAttachmentView(message);

    expect(view?.kind, LiveChatAttachmentKind.image);
    expect(view?.displayName, 'photo.png');
    expect(view?.localPath, r'D:\tmp\photo.png');
  });

  test('attachment view resolves legacy string image paths', () {
    final message = ChatMessage.fromJson({
      '_id': 'msg-image-string',
      'content': '[image]',
      'messageType': 'image',
      'attachments': [r'D:\tmp\photo.png'],
      'createdAt': '2026-06-03T08:00:00.000Z',
    });

    final view = resolveLiveChatAttachmentView(message);

    expect(view?.kind, LiveChatAttachmentKind.image);
    expect(view?.displayName, 'photo.png');
    expect(view?.localPath, r'D:\tmp\photo.png');
  });

  test('attachment view falls back for media placeholders', () {
    final image = ChatMessage.fromJson({
      '_id': 'msg-image-placeholder',
      'content': '[image]',
      'messageType': 'image',
      'createdAt': '2026-06-03T08:00:00.000Z',
    });
    final file = ChatMessage.fromJson({
      '_id': 'msg-file-placeholder',
      'content': '[file]',
      'messageType': 'file',
      'createdAt': '2026-06-03T08:00:00.000Z',
    });

    expect(
      resolveLiveChatAttachmentView(image)?.kind,
      LiveChatAttachmentKind.image,
    );
    expect(
      resolveLiveChatAttachmentView(file)?.kind,
      LiveChatAttachmentKind.file,
    );
  });

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

  test(
    'LiveChatNotifier keeps group conversations when managed list is empty',
    () async {
      final repository = _FakeLiveChatRepository()
        ..includeGroupConversation = true;
      final notifier = LiveChatNotifier(repository);
      await Future<void>.delayed(Duration.zero);

      await notifier.loadConversations(loadSelectedMessages: false);

      expect(
        notifier.state.conversations.where(
          (item) => item.threadType == 'group',
        ),
        isNotEmpty,
      );
    },
  );

  test(
    'LiveChatNotifier reports reaction API failures instead of throwing',
    () async {
      final repository = _FakeLiveChatRepository()..failReaction = true;
      final notifier = LiveChatNotifier(repository);
      await Future<void>.delayed(Duration.zero);
      await notifier.loadConversations(loadSelectedMessages: true);

      await notifier.reactToMessage(
        notifier.state.selectedConversation!.messages.first,
        'heart',
      );

      expect(notifier.state.errorMessage, contains('Thả cảm xúc thất bại'));
    },
  );

  test(
    'keeps the open conversation selected when it drops out of a silent reload',
    () async {
      final repository = _FakeLiveChatRepository();
      final notifier = LiveChatNotifier(repository);
      await Future<void>.delayed(Duration.zero);

      await notifier.loadConversations(loadSelectedMessages: true);
      expect(notifier.state.selectedConversation?.id, 'conv-1');

      // Next reload returns a different batch that excludes conv-1.
      repository.returnAlternateOnly = true;
      await notifier.loadConversations(silent: true);

      // The open conversation must NOT jump to conv-2.
      expect(notifier.state.selectedConversation?.id, 'conv-1');
    },
  );

  test('silent refresh loads messages after initial offline startup', () async {
    final repository = _FakeLiveChatRepository()..failNextConversations = true;
    final notifier = LiveChatNotifier(repository);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.selectedConversation, isNull);
    repository.resetCounters();

    await notifier.loadConversations(silent: true);

    expect(repository.getConversationsCalls, 1);
    expect(repository.getMessagesCalls, 1);
    expect(notifier.state.selectedConversation?.id, 'conv-1');
    expect(notifier.state.selectedConversation?.messages, isNotEmpty);
  });

  test('group @mention autocomplete matches diacritic-insensitively and computes explicit UTF-16 offsets', () {
    const members = <GroupMentionCandidate>[
      GroupMentionCandidate(id: 'u-1', displayName: 'Nguyễn Văn A'),
      GroupMentionCandidate(id: 'u-2', displayName: 'Trần Thị B'),
    ];

    final allSuggestions = matchGroupMentionCandidates(
      'Xin chào @',
      10,
      members,
      canMentionAll: true,
    );
    expect(allSuggestions.length, 3);
    expect(allSuggestions.first.isAll, isTrue);

    final filtered = matchGroupMentionCandidates(
      'Xin chào @nguyen van',
      20,
      members,
      canMentionAll: true,
    );
    expect(filtered.length, 1);
    expect(filtered.first.id, 'u-1');

    final applied = applyGroupMentionCandidate(
      'Xin chào @nguyen van',
      20,
      filtered.first,
    );
    expect(applied.text, 'Xin chào @Nguyễn Văn A ');
    expect(applied.selectionOffset, applied.text.length);

    final explicit = resolveExplicitGroupMentions(
      'Chào @Nguyễn Văn A và @All nhé',
      members,
      canMentionAll: true,
    );
    expect(explicit, [
      {'pos': 5, 'len': 13, 'uid': 'u-1'},
      {'pos': 22, 'len': 4, 'uid': '-1'},
    ]);

    // Ambiguous duplicate displayNames are skipped rather than tagging an arbitrary member
    final dupMembers = <GroupMentionCandidate>[
      const GroupMentionCandidate(id: 'u-1', displayName: 'Minh'),
      const GroupMentionCandidate(id: 'u-2', displayName: 'Minh'),
      const GroupMentionCandidate(id: 'u-3', displayName: 'Trang'),
    ];
    expect(
      resolveExplicitGroupMentions('Chào @Minh nhé', dupMembers),
      isEmpty,
    );

    // Single-word name followed by capitalized surname continuation is skipped
    expect(
      resolveExplicitGroupMentions('Chào @Trang Nguyễn nhé', dupMembers),
      isEmpty,
    );
    expect(
      resolveExplicitGroupMentions('Chào @Trang nhé', dupMembers),
      [
        {'pos': 5, 'len': 6, 'uid': 'u-3'},
      ],
    );
  });

  test('BulkMessagingNotifier.applyCampaignPollSnapshot tracks unknownCount, inFlightRecipient, and aborted_fail_streak', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(bulkMessagingProvider.notifier);

    final doneRunning = notifier.applyCampaignPollSnapshot(
      {
        'statusCounts': {'success': 2, 'failed': 1, 'cancelled': 0},
        'campaign': {'status': 'running'},
        'commandStatus': 'running',
      },
      localInFlight: {
        'unknownCount': 1,
        'inFlightRecipient': {
          'index': 3,
          'recipientId': '0901234567',
          'startedAt': '2026-11-10T00:00:00.000Z',
        },
      },
    );
    expect(doneRunning, isFalse);
    expect(container.read(bulkMessagingProvider).unknownCount, 1);
    expect(
      container.read(bulkMessagingProvider).inFlightRecipient,
      '0901234567',
    );

    // Intermediate progress poll right after circuit breaker triggers (commandStatus still 'running'):
    // displays abortedReason immediately, but keeps polling until terminal cloud state arrives.
    final doneAbortedProgress = notifier.applyCampaignPollSnapshot(
      {
        'statusCounts': {
          'success': 2,
          'failed': 5,
          'queued': 3,
          'cancelled': 0,
        },
        'campaign': {'status': 'running'},
        'commandStatus': 'running',
        'commandResult': {
          'status': 'running',
          'unknownCount': 1,
          'abortedReason': 'aborted_fail_streak',
          'cancelledCount': 3,
        },
      },
    );
    expect(doneAbortedProgress, isFalse);
    expect(
      container.read(bulkMessagingProvider).abortedReason,
      'aborted_fail_streak',
    );
    expect(
      container.read(bulkMessagingProvider).complianceError,
      ZaloIntegrationApi.translateToVietnamese('aborted_fail_streak'),
    );

    // Terminal cloud poll where CrmExecutionLog mapped 'unknown' -> 'queued' -> 'cancelled'
    // and finishCampaign already deleted local in-flight.json, but commandResult carries unknownCount
    final doneAborted = notifier.applyCampaignPollSnapshot(
      {
        'statusCounts': {
          'success': 2,
          'failed': 5,
          'cancelled': 4, // 3 truly cancelled + 1 timed-out mapped to cancelled by cloud
        },
        'campaign': {'status': 'cancelled'},
        'commandStatus': 'failed',
        'commandResult': {
          'unknownCount': 1,
          'abortedReason': 'aborted_fail_streak',
        },
        'commandError': 'Chiến dịch bị hủy do lỗi lệnh gửi.',
      },
    );
    expect(doneAborted, isTrue);
    final finalState = container.read(bulkMessagingProvider);
    expect(finalState.isSending, isFalse);
    expect(finalState.unknownCount, 1);
    expect(finalState.cancelledCount, 3);
    expect(finalState.inFlightRecipient, isNull);
    expect(finalState.abortedReason, 'aborted_fail_streak');
    expect(
      finalState.complianceError,
      ZaloIntegrationApi.translateToVietnamese('aborted_fail_streak'),
    );
    expect(
      ZaloIntegrationApi.translateToVietnamese('SEND_TIMEOUT'),
      contains('Quá thời gian phản hồi'),
    );
    expect(
      ZaloIntegrationApi.translateToVietnamese('rate_limited'),
      contains('giới hạn tốc độ gửi'),
    );
  });

  test('BulkCampaignRepository.getLocalInFlightCampaign parses response without leaking injected client', () async {
    var closedCount = 0;
    final mockClient = _TrackingClient(
      MockClient((request) async {
        expect(request.url.path, '/local/campaigns/in-flight');
        expect(request.url.queryParameters['campaignId'], 'camp-99');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'campaignId': 'camp-99',
                'unknownCount': 2,
                'inFlightRecipient': {
                  'index': 4,
                  'recipientId': '0988776655',
                  'startedAt': '2026-11-10T00:00:00.000Z',
                },
              },
            ],
          }),
          200,
        );
      }),
      onClose: () => closedCount++,
    );
    final repo = BulkCampaignRepository(httpClient: mockClient);
    final record = await repo.getLocalInFlightCampaign('camp-99');
    expect(record?['campaignId'], 'camp-99');
    expect(record?['unknownCount'], 2);
    expect(closedCount, 0); // Injected client is not closed by repository

    // Default owned client branch (no injected client) returns null cleanly on unreachable port and closes its client
    final defaultRepo = BulkCampaignRepository();
    final unreachable = await defaultRepo.getLocalInFlightCampaign(
      'camp-99',
      bridgeBaseUrl: 'http://127.0.0.1:1',
    );
    expect(unreachable, isNull);
  });
}

class _TrackingClient extends http.BaseClient {
  final http.Client _inner;
  final void Function() onClose;

  _TrackingClient(this._inner, {required this.onClose});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {
    onClose();
    _inner.close();
  }
}

Conversation _conversation({
  required String id,
  int unreadCount = 0,
  List<String> labels = const [],
  DateTime? followUpAt,
  bool archived = false,
  String assignedTo = '',
}) {
  return Conversation(
    id: id,
    accountId: 'acc-1',
    threadId: 'thread-$id',
    threadType: 'user',
    customerName: 'Customer $id',
    customerAvatar: '',
    lastMessage: 'Xin chao',
    lastMessageTime: DateTime(2026),
    unreadCount: unreadCount,
    tag: labels.isEmpty ? '' : labels.first,
    labels: labels,
    notes: '',
    chatbotEnabled: true,
    followUpAt: followUpAt,
    archived: archived,
    assignedTo: assignedTo,
    messages: const [],
  );
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
  bool failReaction = false;
  bool failNextConversations = false;
  bool includeGroupConversation = false;
  bool returnAlternateOnly = false;
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
    if (failNextConversations) {
      failNextConversations = false;
      return {'success': false, 'message': 'Bridge offline'};
    }
    if (returnAlternateOnly) {
      return {
        'success': true,
        'data': <Map<String, dynamic>>[
          {
            '_id': 'conv-2',
            'accountId': 'acc-1',
            'threadId': 'thread-2',
            'threadType': 'user',
            'displayName': 'Khach hang 2',
            'lastMessagePreview': 'Moi',
            'updatedAt': '2026-06-03T09:00:00.000Z',
          },
        ],
      };
    }
    final data = <Map<String, dynamic>>[
      {
        '_id': conversation.id,
        'accountId': conversation.accountId,
        'threadId': conversation.threadId,
        'threadType': conversation.threadType,
        'displayName': conversation.customerName,
        'lastMessagePreview': conversation.lastMessage,
        'updatedAt': conversation.lastMessageTime.toIso8601String(),
      },
    ];
    if (includeGroupConversation) {
      data.add({
        '_id': 'conv-group-1',
        'accountId': 'acc-1',
        'threadId': 'group-1',
        'threadType': 'group',
        'displayName': 'testza',
        'lastMessagePreview': 'Xin chao nhom',
        'updatedAt': '2026-06-03T08:02:00.000Z',
      });
    }
    return {'success': true, 'data': data};
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

  @override
  Future<Map<String, dynamic>> reactToMessage(
    String messageId,
    String reaction,
  ) async {
    if (failReaction) {
      throw Exception('providerMessageId and reaction are required.');
    }
    return {'success': true};
  }
}
