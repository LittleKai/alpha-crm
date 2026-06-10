import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/api/crm_cloud_api.dart';
import '../../../../shared/models/crm_customer.dart';
import '../../../../shared/utils/image_helper.dart';
import '../../../../shared/local_db/local_db_maintenance.dart';
import '../../../settings/providers/settings_provider.dart';
import '../data/live_chat_repository.dart';
import '../data/live_chat_cache.dart';
import '../data/live_chat_local_bridge_api.dart';
import '../data/live_chat_event.dart';

const Object _unset = Object();

final liveChatRepositoryProvider = Provider<LiveChatRepository>((ref) {
  final settings = ref.watch(settingsProvider).settings;
  // Opportunistic cache eviction
  LocalDbMaintenance.runCleanup();

  return LiveChatRepository(
    localFirstEnabled: settings.localFirstLiveChat,
    cache: LiveChatCache(),
    localApi: LiveChatLocalBridgeApi(baseUrl: settings.localBridgeBaseUrl),
  );
});

class LiveChatAccount {
  final String id;
  final String label;
  final int totalGroups;
  final int managedGroups;

  const LiveChatAccount({
    required this.id,
    required this.label,
    this.totalGroups = 0,
    this.managedGroups = 0,
  });

  @override
  bool operator ==(Object other) {
    return other is LiveChatAccount && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String message;
  final String direction;
  final String status;
  final DateTime timestamp;
  final String contentType;
  final bool isDeleted;
  final String? zaloMsgId;
  final String? clientMessageId;
  final String errorText;
  final Map<String, dynamic>? quote;
  final List<Map<String, dynamic>> reactions;
  final List<Map<String, dynamic>> receipts;
  final Map<String, dynamic> metadata;
  final dynamic attachments;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.message,
    required this.direction,
    required this.status,
    required this.timestamp,
    this.contentType = 'text',
    this.isDeleted = false,
    this.zaloMsgId,
    this.clientMessageId,
    this.errorText = '',
    this.quote,
    this.reactions = const [],
    this.receipts = const [],
    this.metadata = const {},
    this.attachments,
  });

  bool get isMine => direction == 'outbound';

  ChatMessage copyWith({
    String? id,
    String? status,
    String? errorText,
    String? zaloMsgId,
    bool? isDeleted,
    List<Map<String, dynamic>>? reactions,
    List<Map<String, dynamic>>? receipts,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      message: message,
      direction: direction,
      status: status ?? this.status,
      timestamp: timestamp,
      contentType: contentType,
      isDeleted: isDeleted ?? this.isDeleted,
      zaloMsgId: zaloMsgId ?? this.zaloMsgId,
      clientMessageId: clientMessageId,
      errorText: errorText ?? this.errorText,
      quote: quote,
      reactions: reactions ?? this.reactions,
      receipts: receipts ?? this.receipts,
      metadata: metadata,
      attachments: attachments,
    );
  }

  static ChatMessage fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      senderName: (json['senderName'] ?? '').toString(),
      senderAvatarUrl: json['senderAvatarUrl']?.toString(),
      message: _stringFrom(json, const ['content', 'text', 'message', 'body']),
      direction: (json['direction'] ?? 'inbound').toString(),
      status: (json['status'] ?? '').toString(),
      timestamp: _dateFrom(
        json['sentAt'] ?? json['receivedAt'] ?? json['createdAt'],
      ),
      contentType: (json['messageType'] ?? json['contentType'] ?? 'text')
          .toString(),
      isDeleted: json['isDeleted'] == true,
      zaloMsgId: (json['zaloMsgId'] ?? json['providerMessageId'])?.toString(),
      clientMessageId: json['clientMessageId']?.toString(),
      errorText: (json['errorText'] ?? json['error'] ?? '').toString(),
      quote: _mapFromJsonField(json['quote'] ?? json['quoteJson']),
      reactions: _mapListFromJsonField(json['reactions']),
      receipts: _mapListFromJsonField(json['receipts']),
      metadata:
          _mapFromJsonField(json['metadata'] ?? json['metadataJson']) ??
          const {},
      attachments: json['attachments'],
    );
  }
}

class Conversation {
  final String id;
  final String accountId;
  final String threadId;
  final String threadType;
  final String customerName;
  final String customerAvatar;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String tag;
  final String notes;
  final bool chatbotEnabled;
  final List<ChatMessage> messages;
  final CrmCustomer? crmCustomer;

  const Conversation({
    required this.id,
    required this.accountId,
    required this.threadId,
    required this.threadType,
    required this.customerName,
    required this.customerAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.tag,
    required this.notes,
    required this.chatbotEnabled,
    required this.messages,
    this.crmCustomer,
  });

  Conversation copyWith({
    String? tag,
    String? notes,
    bool? chatbotEnabled,
    int? unreadCount,
    List<ChatMessage>? messages,
    String? lastMessage,
    DateTime? lastMessageTime,
    CrmCustomer? crmCustomer,
    Object? crmCustomerSet = _unset,
  }) {
    return Conversation(
      id: id,
      accountId: accountId,
      threadId: threadId,
      threadType: threadType,
      customerName: customerName,
      customerAvatar: customerAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      tag: tag ?? this.tag,
      notes: notes ?? this.notes,
      chatbotEnabled: chatbotEnabled ?? this.chatbotEnabled,
      messages: messages ?? this.messages,
      crmCustomer: crmCustomerSet == _unset
          ? (crmCustomer ?? this.crmCustomer)
          : (crmCustomerSet as CrmCustomer?),
    );
  }

  static Conversation fromJson(Map<String, dynamic> json) {
    final tags = json['tags'] is List
        ? List<Object?>.from(json['tags'] as List)
        : const [];
    final name = (json['displayName'] ?? json['threadId'] ?? 'Unknown')
        .toString();
    return Conversation(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      accountId: (json['accountId'] ?? '').toString(),
      threadId: (json['threadId'] ?? '').toString(),
      threadType: (json['threadType'] ?? 'user').toString(),
      customerName: name,
      customerAvatar: sanitizeImageUrl(
        _stringFrom(json, const [
          'avatarUrl',
          'avatar',
          'customerAvatar',
          'senderAvatar',
        ]),
      ),
      lastMessage: _formatConversationPreview(
        _stringFrom(json, const [
          'lastMessagePreview',
          'lastMessage',
          'lastContent',
        ]),
        messageType:
            (json['lastMessage'] is Map
                    ? (json['lastMessage'] as Map)['messageType'] ??
                          (json['lastMessage'] as Map)['contentType']
                    : json['messageType'] ?? json['contentType'])
                ?.toString(),
        direction: json['lastMessage'] is Map
            ? (json['lastMessage'] as Map)['direction']?.toString()
            : null,
      ),
      lastMessageTime: _dateFrom(json['lastMessageAt'] ?? json['updatedAt']),
      unreadCount: int.tryParse((json['unreadCount'] ?? 0).toString()) ?? 0,
      tag: tags.isEmpty ? '' : tags.first.toString(),
      notes: (json['notes'] ?? '').toString(),
      chatbotEnabled: json['chatbotEnabled'] != false,
      messages: const [],
      crmCustomer: null,
    );
  }
}

class LiveChatState {
  final LiveChatAccount? selectedAccount;
  final List<LiveChatAccount> accounts;
  final List<Conversation> conversations;
  final Conversation? selectedConversation;
  final bool isLoading;
  final bool isRefreshingConversations;
  final bool isLoadingMessages;
  final bool isLoadingOlderMessages;
  final bool hasMoreMessages;
  final bool isSending;
  final String searchQuery;
  final String? errorMessage;
  final bool isBridgeOffline;
  final bool isUsingCachedMessages;
  final String messageSource;
  final bool realtimeConnected;
  final Set<String> typingUserIds;
  final String draftText;
  final ChatMessage? replyingTo;
  final List<ChatMessage> messageSearchResults;
  final bool isChatFocused;
  final int unfocusedNewMessageCount;

  const LiveChatState({
    this.selectedAccount,
    required this.accounts,
    required this.conversations,
    this.selectedConversation,
    required this.isLoading,
    this.isRefreshingConversations = false,
    this.isLoadingMessages = false,
    this.isLoadingOlderMessages = false,
    this.hasMoreMessages = true,
    required this.isSending,
    required this.searchQuery,
    this.errorMessage,
    this.isBridgeOffline = false,
    this.isUsingCachedMessages = false,
    this.messageSource = 'cloudLegacy',
    this.realtimeConnected = false,
    this.typingUserIds = const {},
    this.draftText = '',
    this.replyingTo,
    this.messageSearchResults = const [],
    this.isChatFocused = true,
    this.unfocusedNewMessageCount = 0,
  });

  factory LiveChatState.initial() {
    return const LiveChatState(
      selectedAccount: LiveChatAccount(id: '', label: 'Tất cả tài khoản'),
      accounts: [LiveChatAccount(id: '', label: 'Tất cả tài khoản')],
      conversations: [],
      selectedConversation: null,
      isLoading: false,
      isRefreshingConversations: false,
      isLoadingMessages: false,
      isLoadingOlderMessages: false,
      hasMoreMessages: true,
      isSending: false,
      searchQuery: '',
      errorMessage: null,
      isBridgeOffline: false,
      isUsingCachedMessages: false,
      messageSource: 'cloudLegacy',
      realtimeConnected: false,
      typingUserIds: {},
      draftText: '',
      replyingTo: null,
      messageSearchResults: [],
      isChatFocused: true,
      unfocusedNewMessageCount: 0,
    );
  }

  LiveChatState copyWith({
    Object? selectedAccount = _unset,
    List<LiveChatAccount>? accounts,
    List<Conversation>? conversations,
    Object? selectedConversation = _unset,
    bool? isLoading,
    bool? isRefreshingConversations,
    bool? isLoadingMessages,
    bool? isLoadingOlderMessages,
    bool? hasMoreMessages,
    bool? isSending,
    String? searchQuery,
    String? errorMessage,
    bool? isBridgeOffline,
    bool? isUsingCachedMessages,
    String? messageSource,
    bool? realtimeConnected,
    Set<String>? typingUserIds,
    String? draftText,
    Object? replyingTo = _unset,
    List<ChatMessage>? messageSearchResults,
    bool? isChatFocused,
    int? unfocusedNewMessageCount,
  }) {
    return LiveChatState(
      selectedAccount: selectedAccount == _unset
          ? this.selectedAccount
          : selectedAccount as LiveChatAccount?,
      accounts: accounts ?? this.accounts,
      conversations: conversations ?? this.conversations,
      selectedConversation: selectedConversation == _unset
          ? this.selectedConversation
          : selectedConversation as Conversation?,
      isLoading: isLoading ?? this.isLoading,
      isRefreshingConversations:
          isRefreshingConversations ?? this.isRefreshingConversations,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isLoadingOlderMessages:
          isLoadingOlderMessages ?? this.isLoadingOlderMessages,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      isSending: isSending ?? this.isSending,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      isBridgeOffline: isBridgeOffline ?? this.isBridgeOffline,
      isUsingCachedMessages:
          isUsingCachedMessages ?? this.isUsingCachedMessages,
      messageSource: messageSource ?? this.messageSource,
      realtimeConnected: realtimeConnected ?? this.realtimeConnected,
      typingUserIds: typingUserIds ?? this.typingUserIds,
      draftText: draftText ?? this.draftText,
      replyingTo: replyingTo == _unset
          ? this.replyingTo
          : replyingTo as ChatMessage?,
      messageSearchResults: messageSearchResults ?? this.messageSearchResults,
      isChatFocused: isChatFocused ?? this.isChatFocused,
      unfocusedNewMessageCount:
          unfocusedNewMessageCount ?? this.unfocusedNewMessageCount,
    );
  }
}

class LiveChatNotifier extends StateNotifier<LiveChatState> {
  final LiveChatRepository _repository;
  StreamSubscription<LiveChatEvent>? _eventSubscription;
  Timer? _eventRefreshDebounce;
  Timer? _draftDebounce;
  DateTime _lastTypingSentAt = DateTime.fromMillisecondsSinceEpoch(0);

  LiveChatNotifier(this._repository) : super(LiveChatState.initial()) {
    loadAccounts();
    loadConversations(loadSelectedMessages: true);
  }

  Future<void> loadAccounts() async {
    final response = await _repository.getAccounts();
    if (response['success'] != true) return;
    final data = response['data'];
    final rawAccounts = data is Map ? data['accounts'] : null;
    final accounts = <LiveChatAccount>[
      const LiveChatAccount(id: '', label: 'Tất cả tài khoản'),
      if (rawAccounts is List)
        ...rawAccounts.map((item) {
          final json = Map<String, dynamic>.from(item as Map);
          final id = (json['accountId'] ?? '').toString();
          return LiveChatAccount(
            id: id,
            label: (json['label'] ?? id).toString(),
            totalGroups:
                int.tryParse((json['totalGroups'] ?? 0).toString()) ?? 0,
            managedGroups:
                int.tryParse((json['managedCount'] ?? 0).toString()) ?? 0,
          );
        }),
    ];
    state = state.copyWith(accounts: accounts);
  }

  Future<void> loadConversations({
    bool silent = false,
    bool loadSelectedMessages = false,
  }) async {
    state = state.copyWith(
      isLoading: silent ? state.isLoading : true,
      isRefreshingConversations: silent,
      errorMessage: null,
    );
    final response = await _repository.getConversations(
      accountId: state.selectedAccount?.id,
      search: state.searchQuery,
    );

    if (response['success'] == true && response['data'] is List) {
      var conversations = (response['data'] as List)
          .whereType<Map>()
          .map((item) => Conversation.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      conversations = await _filterManagedGroupConversations(conversations);
      final selected = _selectedAfterRefresh(conversations);
      state = state.copyWith(
        conversations: conversations,
        selectedConversation: conversations.isEmpty ? null : selected,
        isLoading: false,
        isRefreshingConversations: false,
      );
      if (loadSelectedMessages && conversations.isNotEmpty) {
        await loadMessages(selected.id);
        _subscribeToEvents(selected);
        await _loadDraft(selected);
      }
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: (response['message'] ?? 'Không thể tải hội thoại.')
            .toString(),
      );
    }
  }

  Conversation _selectedAfterRefresh(List<Conversation> conversations) {
    final current = state.selectedConversation;
    if (current != null) {
      for (final conversation in conversations) {
        if (conversation.id == current.id) {
          return conversation.copyWith(
            messages: current.messages,
            crmCustomer: current.crmCustomer,
            unreadCount: current.unreadCount,
          );
        }
      }
    }
    return conversations.isEmpty ? _emptyConversation : conversations.first;
  }

  Future<List<Conversation>> _filterManagedGroupConversations(
    List<Conversation> conversations,
  ) async {
    // Luôn hiển thị tất cả các group (mặc định bật)
    return conversations;
  }

  Future<void> selectAccount(LiveChatAccount? account) async {
    state = state.copyWith(
      selectedAccount: account,
      selectedConversation: null,
    );
    await loadConversations(loadSelectedMessages: true);
  }

  Future<void> setSearchQuery(String query) async {
    state = state.copyWith(searchQuery: query);
    await loadConversations(loadSelectedMessages: true);
  }

  Future<void> selectConversation(Conversation conversation) async {
    final cachedData = await _repository.getCachedMessages(conversation.id);
    final cachedMessages =
        cachedData
            .map(
              (item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    state = state.copyWith(
      selectedConversation: conversation.copyWith(
        unreadCount: 0,
        messages: cachedMessages,
      ),
      hasMoreMessages: true,
      isUsingCachedMessages: cachedMessages.isNotEmpty,
      replyingTo: null,
      typingUserIds: <String>{},
    );
    _subscribeToEvents(conversation);
    await _loadDraft(conversation);
    await Future.wait([
      loadMessages(conversation.id),
      _repository.markRead(conversation.id),
      fetchCrmCustomerForConversation(conversation),
    ]);
  }

  Future<void> _loadDraft(Conversation conversation) async {
    try {
      final content = await _repository.getDraft(
        ConversationTarget(
          accountId: conversation.accountId,
          threadId: conversation.threadId,
          threadType: conversation.threadType,
        ),
      );
      if (state.selectedConversation?.id == conversation.id) {
        state = state.copyWith(draftText: content);
      }
    } catch (_) {}
  }

  Future<void> fetchCrmCustomerForConversation(
    Conversation conversation,
  ) async {
    try {
      final response = await CrmCloudApi.get(
        '/crm/customers?search=${conversation.threadId}',
      );
      if (response['success'] == true && response['data'] is List) {
        final list = response['data'] as List;
        CrmCustomer? matchedCustomer;
        for (final item in list) {
          final customer = CrmCustomer.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (customer.zaloUserId == conversation.threadId ||
              customer.zaloThreadId == conversation.threadId ||
              customer.phone == conversation.threadId) {
            matchedCustomer = customer;
            break;
          }
        }
        if (matchedCustomer == null && list.isNotEmpty) {
          final first = CrmCustomer.fromJson(
            Map<String, dynamic>.from(list.first),
          );
          if (first.zaloUserId == conversation.threadId ||
              first.zaloThreadId == conversation.threadId ||
              first.name == conversation.customerName) {
            matchedCustomer = first;
          }
        }

        if (matchedCustomer != null) {
          final selected = state.selectedConversation;
          if (selected != null && selected.id == conversation.id) {
            final updated = selected.copyWith(crmCustomer: matchedCustomer);
            state = state.copyWith(
              selectedConversation: updated,
              conversations: state.conversations
                  .map((c) => c.id == conversation.id ? updated : c)
                  .toList(),
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<bool> saveCrmCustomer({
    required String name,
    required String phone,
    required String email,
    required String source,
    required String status,
    required String notes,
    required List<String> tags,
  }) async {
    final conversation = state.selectedConversation;
    if (conversation == null) return false;

    state = state.copyWith(isSending: true);
    try {
      final existingCustomer = conversation.crmCustomer;
      Map<String, dynamic> response;

      final customerData = CrmCustomer(
        id: existingCustomer?.id ?? '',
        userId: existingCustomer?.userId ?? '',
        name: name,
        email: email,
        phone: phone,
        company: existingCustomer?.company ?? 'Mặc định',
        notes: notes,
        status: status.isEmpty ? 'lead' : status,
        zaloUserId: conversation.threadId,
        zaloThreadId: conversation.threadId,
        tags: tags,
        source: source.isEmpty ? 'Zalo Live Chat' : source,
        lifecycleStage: existingCustomer?.lifecycleStage ?? 'lead',
        consentStatus: existingCustomer?.consentStatus ?? 'granted',
        consentEvidence:
            existingCustomer?.consentEvidence ?? 'Updated from Live Chat CRM',
        customFields: existingCustomer?.customFields ?? const {},
        createdAt: existingCustomer?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (existingCustomer != null) {
        response = await CrmCloudApi.put(
          '/crm/customers/${existingCustomer.id}',
          customerData.toJson(),
        );
      } else {
        response = await CrmCloudApi.post(
          '/crm/customers',
          customerData.toJson(),
        );
      }

      if (response['success'] == true && response['data'] != null) {
        final savedCustomer = CrmCustomer.fromJson(
          Map<String, dynamic>.from(response['data']),
        );

        final updatedTag = tags.isNotEmpty ? tags.first : '';
        await _repository.updateConversation(conversation.id, {
          'tags': tags,
          'notes': notes,
        });

        final updated = conversation.copyWith(
          crmCustomer: savedCustomer,
          tag: updatedTag,
          notes: notes,
        );

        state = state.copyWith(
          selectedConversation: updated,
          conversations: state.conversations
              .map((c) => c.id == conversation.id ? updated : c)
              .toList(),
          isSending: false,
        );
        return true;
      }
    } catch (_) {}
    state = state.copyWith(isSending: false);
    return false;
  }

  Future<void> loadMessages(
    String conversationId, {
    int limit = 30,
    String? before,
    String? after,
  }) async {
    final isOlderLoad = before != null && before.isNotEmpty;
    state = state.copyWith(
      isLoadingMessages: !isOlderLoad && after == null,
      isLoadingOlderMessages: isOlderLoad,
    );
    final response = await _repository.getMessages(
      conversationId,
      limit: limit,
      before: before,
      after: after,
    );

    final isBridgeOffline =
        response['code'] == 'LOCAL_BRIDGE_OFFLINE' ||
        response['code'] == 'LOCAL_BRIDGE_REQUIRED';
    final isUsingCachedMessages = response['code'] == 'LOCAL_BRIDGE_OFFLINE';
    final messageSource = response['code'] == 'LOCAL_BRIDGE_REQUIRED'
        ? 'cloudLegacy'
        : (isUsingCachedMessages ? 'cache' : 'local');

    state = state.copyWith(
      isLoadingMessages: false,
      isLoadingOlderMessages: false,
      isBridgeOffline: isBridgeOffline,
      isUsingCachedMessages: isUsingCachedMessages,
      messageSource: messageSource,
    );

    if (response['success'] != true || response['data'] is! List) return;
    final messages = (response['data'] as List)
        .whereType<Map>()
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final selected = state.selectedConversation;
    if (selected == null || selected.id != conversationId) return;
    final mergedMessages = _mergeMessages(
      selected.messages,
      messages,
      prepend: isOlderLoad,
      append: after != null && after.isNotEmpty,
    );
    final updated = selected.copyWith(messages: mergedMessages, unreadCount: 0);
    state = state.copyWith(
      selectedConversation: updated,
      hasMoreMessages: after != null && after.isNotEmpty
          ? state.hasMoreMessages
          : messages.length >= limit,
      conversations: state.conversations
          .map(
            (conversation) =>
                conversation.id == conversationId ? updated : conversation,
          )
          .toList(),
    );
  }

  Future<void> refreshSelectedMessages() async {
    final selected = state.selectedConversation;
    if (selected == null) return;
    final after = selected.messages.isEmpty
        ? null
        : selected.messages.last.timestamp.toIso8601String();
    await loadMessages(selected.id, after: after);
  }

  Future<void> loadOlderMessages() async {
    final selected = state.selectedConversation;
    if (selected == null ||
        selected.messages.isEmpty ||
        state.isLoadingOlderMessages ||
        !state.hasMoreMessages) {
      return;
    }
    await loadMessages(
      selected.id,
      before: selected.messages.first.timestamp.toIso8601String(),
    );
  }

  List<ChatMessage> _mergeMessages(
    List<ChatMessage> current,
    List<ChatMessage> incoming, {
    bool prepend = false,
    bool append = false,
  }) {
    if (!prepend && !append) return incoming;
    final byId = <String, ChatMessage>{
      for (final message in current) _messageKey(message): message,
    };
    final ordered = prepend
        ? [...incoming, ...current]
        : [...current, ...incoming];
    return [
      for (final message in ordered)
        if (byId[_messageKey(message)] == message ||
            !byId.containsKey(_messageKey(message)))
          byId.putIfAbsent(_messageKey(message), () => message),
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  String _messageKey(ChatMessage message) {
    if (message.clientMessageId != null &&
        message.clientMessageId!.isNotEmpty) {
      return 'client:${message.clientMessageId}';
    }
    if (message.zaloMsgId != null && message.zaloMsgId!.isNotEmpty) {
      return 'zalo:${message.zaloMsgId}';
    }
    if (message.id.isNotEmpty) return 'id:${message.id}';
    return '${message.direction}:${message.timestamp.toIso8601String()}:${message.message}';
  }

  Future<void> sendMessage(String text) async {
    final conversation = state.selectedConversation;
    if (conversation == null || text.trim().isEmpty) return;
    final clientMessageId = 'flutter_${DateTime.now().microsecondsSinceEpoch}';
    final reply = state.replyingTo;
    final optimistic = ChatMessage(
      id: clientMessageId,
      senderId: conversation.accountId,
      senderName: 'Ban',
      message: text.trim(),
      direction: 'outbound',
      status: 'sending',
      timestamp: DateTime.now(),
      clientMessageId: clientMessageId,
      quote: reply == null
          ? null
          : {
              'messageId': reply.zaloMsgId ?? reply.id,
              'msgId': reply.zaloMsgId ?? reply.id,
              'clientMessageId': reply.clientMessageId,
              'cliMsgId': reply.clientMessageId,
              'content': reply.message,
              'senderId': reply.senderId,
              'uidFrom': reply.senderId,
              'messageType': reply.contentType,
              'msgType': reply.contentType == 'text'
                  ? 'webchat'
                  : reply.contentType,
              'timestamp': reply.timestamp.millisecondsSinceEpoch,
              'ts': reply.timestamp.millisecondsSinceEpoch,
            },
    );
    _replaceSelected(
      conversation.copyWith(messages: [...conversation.messages, optimistic]),
    );
    state = state.copyWith(isSending: true, errorMessage: null);
    try {
      final response = await _repository.sendRichMessage(
        conversation.id,
        text.trim(),
        clientMessageId: clientMessageId,
        quote: optimistic.quote,
      );
      if (response['success'] == true) {
        await loadMessages(conversation.id);
        state = state.copyWith(
          isSending: false,
          replyingTo: null,
          draftText: '',
        );
        await updateDraft('');
        return;
      }
      _setOptimisticFailed(
        clientMessageId,
        (response['error'] ?? response['message'] ?? 'Gui tin nhan that bai.')
            .toString(),
        localMessageId: response['localMessageId']?.toString(),
      );
    } catch (error) {
      _setOptimisticFailed(clientMessageId, error.toString());
    }
  }

  Future<void> sendLink(String url, {String title = ''}) async {
    final conversation = state.selectedConversation;
    final normalized = url.trim();
    if (conversation == null || normalized.isEmpty) return;
    state = state.copyWith(isSending: true, errorMessage: null);
    final response = await _repository.sendRichMessage(
      conversation.id,
      title.trim().isEmpty ? normalized : title.trim(),
      clientMessageId: 'flutter_${DateTime.now().microsecondsSinceEpoch}',
      messageType: 'link',
      link: {'url': normalized, 'href': normalized, 'title': title.trim()},
    );
    if (response['success'] == true) {
      await loadMessages(conversation.id);
      state = state.copyWith(isSending: false);
    } else {
      if (response['localMessageId'] != null) {
        await loadMessages(conversation.id);
      }
      state = state.copyWith(
        isSending: false,
        errorMessage: (response['error'] ?? 'Gui lien ket that bai.')
            .toString(),
      );
    }
  }

  Future<void> sendSticker(Map<String, dynamic> sticker) async {
    final conversation = state.selectedConversation;
    if (conversation == null || sticker.isEmpty) return;
    state = state.copyWith(isSending: true, errorMessage: null);
    final response = await _repository.sendRichMessage(
      conversation.id,
      '',
      clientMessageId: 'flutter_${DateTime.now().microsecondsSinceEpoch}',
      messageType: 'sticker',
      sticker: sticker,
    );
    if (response['success'] == true) {
      await loadMessages(conversation.id);
      state = state.copyWith(isSending: false);
    } else {
      state = state.copyWith(
        isSending: false,
        errorMessage: (response['error'] ?? 'Gui sticker that bai.').toString(),
      );
    }
  }

  void _setOptimisticFailed(
    String clientMessageId,
    String error, {
    String? localMessageId,
  }) {
    final conversation = state.selectedConversation;
    if (conversation == null) return;
    _replaceSelected(
      conversation.copyWith(
        messages: conversation.messages
            .map(
              (message) => message.clientMessageId == clientMessageId
                  ? message.copyWith(
                      id: localMessageId,
                      status: 'failed',
                      errorText: error,
                    )
                  : message,
            )
            .toList(),
      ),
    );
    state = state.copyWith(isSending: false, errorMessage: error);
  }

  Future<void> retryMessage(ChatMessage message) async {
    final conversation = state.selectedConversation;
    if (conversation == null || message.id.isEmpty) return;
    _replaceSelected(
      conversation.copyWith(
        messages: conversation.messages
            .map(
              (item) => item.id == message.id
                  ? item.copyWith(status: 'sending', errorText: '')
                  : item,
            )
            .toList(),
      ),
    );
    try {
      final response = await _repository.retryMessage(message.id);
      if (response['success'] == true) {
        await loadMessages(conversation.id);
      } else {
        _setOptimisticFailed(
          message.clientMessageId ?? message.id,
          (response['error'] ?? 'Gui lai that bai.').toString(),
        );
      }
    } catch (error) {
      _setOptimisticFailed(
        message.clientMessageId ?? message.id,
        error.toString(),
      );
    }
  }

  Future<void> reactToMessage(ChatMessage message, String reaction) async {
    if (message.id.isEmpty) return;
    try {
      final response = await _repository.reactToMessage(message.id, reaction);
      if (response['success'] == true) {
        final selected = state.selectedConversation;
        if (selected != null) await loadMessages(selected.id);
      } else {
        state = state.copyWith(
          errorMessage:
              (response['message'] ??
                      response['error'] ??
                      'Thả cảm xúc thất bại.')
                  .toString(),
        );
      }
    } catch (error) {
      state = state.copyWith(errorMessage: 'Thả cảm xúc thất bại: $error');
    }
  }

  void replyTo(ChatMessage? message) {
    state = state.copyWith(replyingTo: message);
  }

  Future<void> updateDraft(String content) async {
    final conversation = state.selectedConversation;
    if (conversation == null) return;
    state = state.copyWith(draftText: content);
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        await _repository.saveDraft(
          ConversationTarget(
            accountId: conversation.accountId,
            threadId: conversation.threadId,
            threadType: conversation.threadType,
          ),
          content,
        );
      } catch (_) {}
    });
  }

  Future<void> notifyTyping() async {
    final conversation = state.selectedConversation;
    if (conversation == null ||
        DateTime.now().difference(_lastTypingSentAt) <
            const Duration(seconds: 3)) {
      return;
    }
    _lastTypingSentAt = DateTime.now();
    try {
      await _repository.sendTyping(
        ConversationTarget(
          accountId: conversation.accountId,
          threadId: conversation.threadId,
          threadType: conversation.threadType,
        ),
      );
    } catch (_) {}
  }

  Future<void> searchMessages(String query) async {
    final selected = state.selectedConversation;
    if (query.trim().isEmpty) {
      state = state.copyWith(messageSearchResults: []);
      return;
    }
    final response = await _repository.searchMessages(
      query.trim(),
      accountId: selected?.accountId,
      threadId: selected?.threadId,
    );
    if (response['success'] == true && response['data'] is List) {
      state = state.copyWith(
        messageSearchResults: (response['data'] as List)
            .whereType<Map>()
            .map(
              (item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(),
      );
    }
  }

  Future<void> openSearchResult(ChatMessage message) async {
    final selected = state.selectedConversation;
    if (selected == null) return;
    final response = await _repository.messagesAround(message.id);
    if (response['success'] != true || response['data'] is! List) return;
    final messages =
        (response['data'] as List)
            .whereType<Map>()
            .map(
              (item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _replaceSelected(selected.copyWith(messages: messages));
  }

  void setChatFocused(bool focused) {
    state = state.copyWith(
      isChatFocused: focused,
      unfocusedNewMessageCount: focused ? 0 : state.unfocusedNewMessageCount,
    );
  }

  // ignore: unused_element
  Future<void> _sendMessageLegacy(String text) async {
    final conversation = state.selectedConversation;
    if (conversation == null || text.trim().isEmpty) return;
    state = state.copyWith(isSending: true, errorMessage: null);
    final response = await _repository.sendMessage(
      conversation.id,
      text.trim(),
    );
    if (response['success'] == true) {
      await loadMessages(conversation.id);
      state = state.copyWith(isSending: false);
    } else {
      state = state.copyWith(
        isSending: false,
        errorMessage: (response['message'] ?? 'Gửi tin nhắn thất bại.')
            .toString(),
      );
    }
  }

  Future<void> updateNotes(String notes) async {
    final conversation = state.selectedConversation;
    if (conversation == null) return;
    final response = await _repository.updateConversation(conversation.id, {
      'notes': notes,
    });
    if (response['success'] == true) {
      _replaceSelected(conversation.copyWith(notes: notes));
    }
  }

  Future<void> updateTag(String tag) async {
    final conversation = state.selectedConversation;
    if (conversation == null) return;
    final tags = tag.trim().isEmpty ? <String>[] : [tag.trim()];
    final response = await _repository.updateConversation(conversation.id, {
      'tags': tags,
    });
    if (response['success'] == true) {
      _replaceSelected(conversation.copyWith(tag: tag.trim()));
    }
  }

  Future<void> toggleChatbot(bool enabled) async {
    final conversation = state.selectedConversation;
    if (conversation == null) return;
    final response = await _repository.updateConversation(conversation.id, {
      'chatbotEnabled': enabled,
    });
    if (response['success'] == true) {
      _replaceSelected(conversation.copyWith(chatbotEnabled: enabled));
    }
  }

  Future<void> sendAttachment(
    List<String> filePaths, {
    String content = '',
    String messageType = 'file',
  }) async {
    final conversation = state.selectedConversation;
    if (conversation == null || filePaths.isEmpty) return;
    state = state.copyWith(isSending: true, errorMessage: null);
    final response = await _repository.sendAttachment(
      conversation.id,
      filePaths,
      content: content,
      messageType: messageType,
    );
    if (response['success'] == true) {
      await loadMessages(conversation.id);
      state = state.copyWith(isSending: false);
    } else {
      if (response['localMessageId'] != null) {
        await loadMessages(conversation.id);
      }
      state = state.copyWith(
        isSending: false,
        errorMessage: (response['message'] ?? 'Gửi file thất bại.').toString(),
      );
    }
  }

  Future<bool> recallMessage(String messageId) async {
    final conversation = state.selectedConversation;
    if (conversation == null) return false;
    state = state.copyWith(isSending: true, errorMessage: null);
    try {
      final response = await _repository.recallMessage(
        conversation.id,
        messageId,
      );
      if (response['success'] == true) {
        await loadMessages(conversation.id);
        state = state.copyWith(isSending: false);
        return true;
      } else {
        state = state.copyWith(
          isSending: false,
          errorMessage:
              (response['message'] ??
                      response['error'] ??
                      'Thu hồi tin nhắn thất bại.')
                  .toString(),
        );
        return false;
      }
    } catch (error) {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Thu hồi tin nhắn thất bại: $error',
      );
      return false;
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _eventRefreshDebounce?.cancel();
    _draftDebounce?.cancel();
    super.dispose();
  }

  void _subscribeToEvents(Conversation conversation) {
    _eventSubscription?.cancel();
    state = state.copyWith(realtimeConnected: false, typingUserIds: <String>{});
    _eventSubscription = _repository
        .watchEvents(
          accountId: conversation.accountId,
          threadId: conversation.threadId,
        )
        .listen(
          _handleRealtimeEvent,
          onError: (_) => state = state.copyWith(realtimeConnected: false),
          onDone: () => state = state.copyWith(realtimeConnected: false),
        );
  }

  void _handleRealtimeEvent(LiveChatEvent event) {
    if (event.type == 'bridge.connected') {
      state = state.copyWith(realtimeConnected: true);
      return;
    }
    final selected = state.selectedConversation;
    if (selected == null ||
        (event.threadId.isNotEmpty && event.threadId != selected.threadId)) {
      return;
    }
    if (event.type == 'typing.started' || event.type == 'typing.stopped') {
      final userId = (event.data['userId'] ?? '').toString();
      final typing = <String>{...state.typingUserIds};
      if (event.type == 'typing.started' && userId.isNotEmpty) {
        typing.add(userId);
      } else {
        typing.remove(userId);
      }
      state = state.copyWith(realtimeConnected: true, typingUserIds: typing);
      return;
    }
    if (event.type == 'group.updated' || event.type == 'friend.updated') {
      state = state.copyWith(realtimeConnected: true);
      loadConversations(silent: true);
      return;
    }
    state = state.copyWith(realtimeConnected: true);
    if (event.type == 'message.created' && !state.isChatFocused) {
      state = state.copyWith(
        unfocusedNewMessageCount: state.unfocusedNewMessageCount + 1,
      );
    }
    _eventRefreshDebounce?.cancel();
    _eventRefreshDebounce = Timer(const Duration(milliseconds: 120), () {
      final current = state.selectedConversation;
      if (current != null) loadMessages(current.id);
    });
  }

  void _replaceSelected(Conversation updated) {
    state = state.copyWith(
      selectedConversation: updated,
      conversations: state.conversations
          .map(
            (conversation) =>
                conversation.id == updated.id ? updated : conversation,
          )
          .toList(),
    );
  }
}

final liveChatProvider = StateNotifierProvider<LiveChatNotifier, LiveChatState>(
  (ref) {
    return LiveChatNotifier(ref.read(liveChatRepositoryProvider));
  },
);

final _emptyConversation = Conversation(
  id: '',
  accountId: '',
  threadId: '',
  threadType: 'user',
  customerName: '',
  customerAvatar: '?',
  lastMessage: '',
  lastMessageTime: DateTime.fromMillisecondsSinceEpoch(0),
  unreadCount: 0,
  tag: '',
  notes: '',
  chatbotEnabled: true,
  messages: const [],
  crmCustomer: null,
);

DateTime _dateFrom(Object? value) {
  if (value == null) return DateTime.now();
  final valStr = value.toString();
  final ts = int.tryParse(valStr);
  if (ts != null && ts > 1000000000000) {
    return DateTime.fromMillisecondsSinceEpoch(ts).toLocal();
  }
  final parsed = DateTime.tryParse(valStr);
  return parsed != null ? parsed.toLocal() : DateTime.now();
}

String _stringFrom(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString();
    if (text.isNotEmpty) return text;
  }
  return '';
}

Map<String, dynamic>? _mapFromJsonField(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }

  return null;
}

List<Map<String, dynamic>> _mapListFromJsonField(Object? value) {
  Object? decoded = value;
  if (value is String && value.isNotEmpty) {
    try {
      decoded = jsonDecode(value);
    } catch (_) {
      return const [];
    }
  }
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _formatConversationPreview(
  String rawMessage, {
  String? messageType,
  String? direction,
}) {
  final prefix = direction == 'outbound' ? 'Bạn: ' : '';
  final normalizedType = messageType?.trim().toLowerCase();
  final typedPreview = _previewForType(normalizedType);
  if (typedPreview != null) return '$prefix$typedPreview';

  final trimmed = rawMessage.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final deleted = decoded['isDeleted'] == true;
        if (deleted) return '$prefix(tin nhắn đã thu hồi)';

        final decodedType = (decoded['messageType'] ?? decoded['contentType'])
            ?.toString();
        final decodedPreview = _previewForType(decodedType?.toLowerCase());
        if (decodedPreview != null) return '$prefix$decodedPreview';
        final structuredPreview = _previewForStructuredContent(decoded);
        if (structuredPreview != null) return '$prefix$structuredPreview';
        final nestedContent = _mapFromJsonField(decoded['content']);
        final nestedPreview = _previewForStructuredContent(nestedContent);
        if (nestedPreview != null) return '$prefix$nestedPreview';

        final params = decoded['params'];
        if (params is Map &&
            (params['fileExt'] != null || params['fType'] == 1)) {
          return '${prefix}Tệp đính kèm';
        }
        if (params is String && params.trim().startsWith('{')) {
          final parsedParams = jsonDecode(params);
          if (parsedParams is Map &&
              (parsedParams['fileExt'] != null || parsedParams['fType'] == 1)) {
            return '${prefix}Tệp đính kèm';
          }
        }

        final href =
            decoded['href']?.toString() ?? decoded['url']?.toString() ?? '';
        final title = decoded['title']?.toString() ?? '';
        final description = decoded['description']?.toString() ?? '';
        if (href.isNotEmpty || title.isNotEmpty || description.isNotEmpty) {
          return '${prefix}Liên kết';
        }
      }
    } catch (_) {
      return rawMessage;
    }
  }

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return '${prefix}Liên kết';
  }

  return rawMessage;
}

String? _previewForStructuredContent(Map<String, dynamic>? decoded) {
  if (decoded == null) return null;
  final decodedType = (decoded['messageType'] ?? decoded['contentType'])
      ?.toString()
      .toLowerCase();
  final typedPreview = _previewForType(decodedType);
  if (typedPreview != null) return typedPreview;

  final params = decoded['params'];
  if (params is Map &&
      (params['fileExt'] != null ||
          params['fType'] == 1 ||
          params['fileName'] != null)) {
    return _previewForType('file');
  }
  if (params is String && params.trim().startsWith('{')) {
    try {
      final parsedParams = jsonDecode(params);
      if (parsedParams is Map &&
          (parsedParams['fileExt'] != null ||
              parsedParams['fType'] == 1 ||
              parsedParams['fileName'] != null)) {
        return _previewForType('file');
      }
    } catch (_) {}
  }

  final fileName =
      decoded['fileName']?.toString() ??
      decoded['name']?.toString() ??
      decoded['title']?.toString() ??
      '';
  if (RegExp(r'\.[a-z0-9]{1,8}$', caseSensitive: false).hasMatch(fileName) &&
      (decoded['description'] != null || decoded['params'] != null)) {
    return _previewForType('file');
  }

  final href =
      decoded['href']?.toString() ??
      decoded['url']?.toString() ??
      decoded['thumb']?.toString() ??
      '';
  final title = decoded['title']?.toString() ?? '';
  final description = decoded['description']?.toString() ?? '';
  if (href.isNotEmpty || title.isNotEmpty || description.isNotEmpty) {
    return _previewForType('link');
  }
  return null;
}

String? _previewForType(String? type) {
  switch (type) {
    case 'image':
      return 'Hình ảnh';
    case 'file':
      return 'Tệp đính kèm';
    case 'sticker':
      return 'Sticker';
    case 'video':
      return 'Video';
    case 'voice':
      return 'Tin nhắn thoại';
    case 'gif':
      return 'GIF';
    case 'link':
    case 'rich':
      return 'Liên kết';
    case 'location':
      return 'Vị trí';
    case 'contact_card':
      return 'Danh thiếp';
  }
  return null;
}
