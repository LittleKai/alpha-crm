import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/api/crm_cloud_api.dart';
import '../../../../shared/api/crm_sse_provider.dart';
import '../../../../shared/models/crm_customer.dart';
import '../../../../shared/utils/image_helper.dart';
import '../../../../shared/utils/desktop_notifier.dart';
import '../../../../shared/utils/string_helper.dart';
import '../../../../shared/local_db/local_db_maintenance.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../shared/utils/app_logger.dart';
import '../data/live_chat_repository.dart';
import '../data/live_chat_cache.dart';
import '../data/live_chat_local_bridge_api.dart';
import '../data/live_chat_event.dart';
import '../data/live_chat_transport.dart';

const Object _unset = Object();

final liveChatTransportModeProvider = Provider<LiveChatTransportMode>((ref) {
  return resolveLiveChatTransportMode();
});

final liveChatRepositoryProvider = Provider<LiveChatRepository>((ref) {
  final settings = ref.watch(settingsProvider).settings;
  final mode = ref.watch(liveChatTransportModeProvider);
  // Opportunistic cache eviction
  LocalDbMaintenance.runCleanup();

  return LiveChatRepository(
    localFirstEnabled: settings.localFirstLiveChat,
    cache: LiveChatCache(),
    localApi: LiveChatLocalBridgeApi(baseUrl: settings.localBridgeBaseUrl),
    mode: mode,
    sseClient: mode == LiveChatTransportMode.cloudRemote
        ? ref.watch(crmSseClientProvider)
        : null,
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

  /// Outbound messages auto-sent by the chatbot are tagged
  /// `metadata.source == 'chatbot'` by the bridge. Everything else outbound is
  /// a human operator reply. Used to badge AI vs nhân viên in the bubble.
  bool get isFromBot => metadata['source'] == 'chatbot';

  String get providerActionId =>
      zaloMsgId?.trim().isNotEmpty == true ? zaloMsgId!.trim() : id;

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
      senderName: (json['senderName'] ?? '').toString().toWellFormed(),
      senderAvatarUrl: json['senderAvatarUrl']?.toString(),
      message: _stringFrom(json, const [
        'content',
        'text',
        'message',
        'body',
      ]).toWellFormed(),
      direction: (json['direction'] ?? 'inbound').toString(),
      status: (json['status'] ?? '').toString(),
      // Pick the first NON-EMPTY timestamp. Inbound rows store sentAt as '' (an
      // empty string, not null), so a `??` chain would stop there and fall back
      // to now — re-stamping old inbound messages to "today" on every reload and
      // breaking chronological order. _stringFrom skips empties.
      timestamp: _dateFrom(
        _stringFrom(json, const ['sentAt', 'receivedAt', 'createdAt']),
      ),
      contentType: (json['messageType'] ?? json['contentType'] ?? 'text')
          .toString(),
      isDeleted: json['isDeleted'] == true,
      zaloMsgId: (json['zaloMsgId'] ?? json['providerMessageId'])?.toString(),
      clientMessageId: json['clientMessageId']?.toString(),
      errorText: (json['errorText'] ?? json['error'] ?? '')
          .toString()
          .toWellFormed(),
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
  final List<String> labels;
  final String notes;
  final Map<String, String> customAttributes;
  final bool chatbotEnabled;
  // When set and in the future, the bot is temporarily paused (a human replied).
  // chatbotEnabled stays true (master on) — this only drives the AI status icon.
  final DateTime? chatbotPausedUntil;
  final DateTime? followUpAt;
  final bool archived;
  final String assignedTo;
  final List<ConversationTimelineItem> timeline;
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
    this.labels = const [],
    required this.notes,
    this.customAttributes = const {},
    required this.chatbotEnabled,
    this.chatbotPausedUntil,
    this.followUpAt,
    this.archived = false,
    this.assignedTo = '',
    this.timeline = const [],
    required this.messages,
    this.crmCustomer,
  });

  /// True when the bot is on for this thread AND not in an operator-pause window.
  bool get chatbotActive =>
      chatbotEnabled &&
      (chatbotPausedUntil == null ||
          DateTime.now().isAfter(chatbotPausedUntil!));

  /// True when the bot is on but temporarily paused by a human reply.
  bool get chatbotPaused =>
      chatbotEnabled &&
      chatbotPausedUntil != null &&
      chatbotPausedUntil!.isAfter(DateTime.now());

  List<String> get displayLabels =>
      labels.isNotEmpty ? labels : (tag.isEmpty ? const [] : [tag]);

  Conversation copyWith({
    String? tag,
    List<String>? labels,
    String? notes,
    Map<String, String>? customAttributes,
    bool? chatbotEnabled,
    Object? chatbotPausedUntilSet = _unset,
    Object? followUpAtSet = _unset,
    bool? archived,
    String? assignedTo,
    List<ConversationTimelineItem>? timeline,
    int? unreadCount,
    List<ChatMessage>? messages,
    String? lastMessage,
    DateTime? lastMessageTime,
    CrmCustomer? crmCustomer,
    Object? crmCustomerSet = _unset,
  }) {
    final nextTag = tag ?? this.tag;
    final nextLabels =
        labels ??
        (tag == null ? this.labels : (nextTag.isEmpty ? [] : [nextTag]));
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
      tag: nextTag,
      labels: nextLabels,
      notes: notes ?? this.notes,
      customAttributes: customAttributes ?? this.customAttributes,
      chatbotEnabled: chatbotEnabled ?? this.chatbotEnabled,
      chatbotPausedUntil: chatbotPausedUntilSet == _unset
          ? chatbotPausedUntil
          : (chatbotPausedUntilSet as DateTime?),
      followUpAt: followUpAtSet == _unset
          ? followUpAt
          : (followUpAtSet as DateTime?),
      archived: archived ?? this.archived,
      assignedTo: assignedTo ?? this.assignedTo,
      timeline: timeline ?? this.timeline,
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
    final labels = tags
        .map((tag) => tag.toString().trim().toWellFormed())
        .where((tag) => tag.isNotEmpty)
        .toList();
    final name = (json['displayName'] ?? json['threadId'] ?? 'Unknown')
        .toString();
    // Prefer the cloud conversation id as the stable identity so cloud-keyed
    // operations (updateConversation tags/notes, cloud markRead) keep working
    // when the inbox is sourced from the local bridge. Fall back to the local
    // bridge id (or cloud _id) when the conversation has not synced to cloud.
    final cloudConversationId = (json['cloudConversationId'] ?? '').toString();
    final resolvedId = cloudConversationId.isNotEmpty
        ? cloudConversationId
        : (json['_id'] ?? json['id'] ?? '').toString();
    return Conversation(
      id: resolvedId,
      accountId: (json['accountId'] ?? '').toString(),
      threadId: (json['threadId'] ?? '').toString(),
      threadType: (json['threadType'] ?? 'user').toString(),
      customerName: name.toWellFormed(),
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
      ).toWellFormed(),
      lastMessageTime: _dateFrom(json['lastMessageAt'] ?? json['updatedAt']),
      unreadCount: int.tryParse((json['unreadCount'] ?? 0).toString()) ?? 0,
      tag: labels.isEmpty ? '' : labels.first,
      labels: labels,
      notes: (json['notes'] ?? '').toString().toWellFormed(),
      customAttributes: _mapCustomAttributes(json),
      chatbotEnabled: json['chatbotEnabled'] != false,
      chatbotPausedUntil: _pausedUntilFrom(json['chatbotPausedUntil']),
      followUpAt: _dateFromNullable(
        json['followUpAt'] ??
            json['snoozedUntil'] ??
            json['followUpUntil'] ??
            json['remindAt'],
      ),
      archived:
          json['archived'] == true ||
          json['isArchived'] == true ||
          json['status']?.toString() == 'archived',
      assignedTo: (json['assignedTo'] ?? json['assigneeId'] ?? '')
          .toString()
          .toWellFormed(),
      timeline: json['timeline'] is List
          ? (json['timeline'] as List)
                .whereType<Map>()
                .map(ConversationTimelineItem.fromJson)
                .toList()
          : const [],
      messages: const [],
      crmCustomer: null,
    );
  }
}

Map<String, String> _mapCustomAttributes(Map<String, dynamic> json) {
  final raw =
      json['customFields'] ?? json['customAttributes'] ?? json['attributes'];
  if (raw is! Map) return const {};
  return raw.map((key, value) {
    return MapEntry(key.toString(), value?.toString() ?? '');
  });
}

DateTime? _pausedUntilFrom(dynamic value) {
  if (value == null) return null;
  final ms = int.tryParse(value.toString());
  if (ms == null || ms <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(ms);
}

DateTime? _dateFromNullable(dynamic value) {
  if (value == null) return null;
  final raw = value.toString();
  if (raw.isEmpty) return null;
  final ms = int.tryParse(raw);
  if (ms != null && ms > 0) return DateTime.fromMillisecondsSinceEpoch(ms);
  return DateTime.tryParse(raw);
}

enum InboxStatusFilter { all, unread, followUp, archived, assigned }

class ConversationTimelineItem {
  final String id;
  final String eventType;
  final String summary;
  final DateTime createdAt;

  const ConversationTimelineItem({
    required this.id,
    required this.eventType,
    required this.summary,
    required this.createdAt,
  });

  factory ConversationTimelineItem.fromJson(Map<dynamic, dynamic> json) {
    return ConversationTimelineItem(
      id: json['id']?.toString() ?? '',
      eventType: json['eventType']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      createdAt: _dateFrom(json['createdAt']),
    );
  }
}

class ConversationSavedFilter {
  final String id;
  final String name;
  final String label;
  final bool unreadOnly;
  final bool labeledOnly;
  final InboxStatusFilter inboxStatus;

  const ConversationSavedFilter({
    required this.id,
    required this.name,
    this.label = '',
    this.unreadOnly = false,
    this.labeledOnly = false,
    this.inboxStatus = InboxStatusFilter.all,
  });

  factory ConversationSavedFilter.fromJson(Map<dynamic, dynamic> json) {
    final statusName = json['inboxStatus']?.toString() ?? 'all';
    return ConversationSavedFilter(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      unreadOnly: json['unreadOnly'] == true,
      labeledOnly: json['labeledOnly'] == true,
      inboxStatus: InboxStatusFilter.values.firstWhere(
        (item) => item.name == statusName,
        orElse: () => InboxStatusFilter.all,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'label': label,
      'unreadOnly': unreadOnly,
      'labeledOnly': labeledOnly,
      'inboxStatus': inboxStatus.name,
    };
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
  final String highlightedMessageId;
  final bool isChatFocused;
  final int unfocusedNewMessageCount;
  final String selectedLabelFilter;
  final bool unreadOnlyFilter;
  final bool labeledOnlyFilter;
  final InboxStatusFilter inboxStatusFilter;
  final String selectedSavedFilterId;
  final List<ConversationSavedFilter> savedFilters;
  // Per-account AI auto-reply switch (Live Chat settings dialog). Accounts
  // absent default to ON. When OFF, the per-conversation Bot toggle is forced
  // off and non-interactive.
  final Map<String, bool> accountAiAutoReply;

  bool isAccountAiAutoReplyEnabled(String accountId) =>
      accountAiAutoReply[accountId] ?? true;

  List<String> get availableLabels {
    final labels = <String>{};
    for (final conversation in conversations) {
      labels.addAll(conversation.displayLabels);
    }
    return labels.toList()..sort();
  }

  bool get hasActiveConversationFilters =>
      selectedLabelFilter.isNotEmpty ||
      unreadOnlyFilter ||
      labeledOnlyFilter ||
      inboxStatusFilter != InboxStatusFilter.all;

  List<Conversation> get filteredConversations {
    return conversations.where((conversation) {
      final labels = conversation.displayLabels;
      if (selectedLabelFilter.isNotEmpty &&
          !labels.contains(selectedLabelFilter)) {
        return false;
      }
      if (unreadOnlyFilter && conversation.unreadCount <= 0) return false;
      if (labeledOnlyFilter && labels.isEmpty) return false;
      switch (inboxStatusFilter) {
        case InboxStatusFilter.all:
          if (conversation.archived) return false;
          break;
        case InboxStatusFilter.unread:
          if (conversation.unreadCount <= 0 || conversation.archived) {
            return false;
          }
          break;
        case InboxStatusFilter.followUp:
          if (conversation.followUpAt == null || conversation.archived) {
            return false;
          }
          break;
        case InboxStatusFilter.archived:
          if (!conversation.archived) return false;
          break;
        case InboxStatusFilter.assigned:
          if (conversation.assignedTo.isEmpty || conversation.archived) {
            return false;
          }
          break;
      }
      return true;
    }).toList();
  }

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
    this.highlightedMessageId = '',
    this.isChatFocused = false,
    this.unfocusedNewMessageCount = 0,
    this.selectedLabelFilter = '',
    this.unreadOnlyFilter = false,
    this.labeledOnlyFilter = false,
    this.inboxStatusFilter = InboxStatusFilter.all,
    this.selectedSavedFilterId = '',
    this.savedFilters = const [],
    this.accountAiAutoReply = const {},
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
      selectedLabelFilter: '',
      unreadOnlyFilter: false,
      labeledOnlyFilter: false,
      inboxStatusFilter: InboxStatusFilter.all,
      selectedSavedFilterId: '',
      savedFilters: [],
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
    String? highlightedMessageId,
    bool? isChatFocused,
    int? unfocusedNewMessageCount,
    String? selectedLabelFilter,
    bool? unreadOnlyFilter,
    bool? labeledOnlyFilter,
    InboxStatusFilter? inboxStatusFilter,
    String? selectedSavedFilterId,
    List<ConversationSavedFilter>? savedFilters,
    Map<String, bool>? accountAiAutoReply,
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
      highlightedMessageId: highlightedMessageId ?? this.highlightedMessageId,
      isChatFocused: isChatFocused ?? this.isChatFocused,
      unfocusedNewMessageCount:
          unfocusedNewMessageCount ?? this.unfocusedNewMessageCount,
      selectedLabelFilter: selectedLabelFilter ?? this.selectedLabelFilter,
      unreadOnlyFilter: unreadOnlyFilter ?? this.unreadOnlyFilter,
      labeledOnlyFilter: labeledOnlyFilter ?? this.labeledOnlyFilter,
      inboxStatusFilter: inboxStatusFilter ?? this.inboxStatusFilter,
      selectedSavedFilterId:
          selectedSavedFilterId ?? this.selectedSavedFilterId,
      savedFilters: savedFilters ?? this.savedFilters,
      accountAiAutoReply: accountAiAutoReply ?? this.accountAiAutoReply,
    );
  }
}

class LiveChatNotifier extends StateNotifier<LiveChatState> {
  final LiveChatRepository _repository;
  // Returns the current desktop-notification preference (read fresh each time
  // so runtime toggles in the Live Chat settings dialog take effect).
  final bool Function() _notificationsEnabled;
  StreamSubscription<LiveChatEvent>? _eventSubscription;
  Timer? _eventRefreshDebounce;
  Timer? _draftDebounce;
  // Realtime is subscribed at ACCOUNT level (all threads) so the conversation
  // list updates live, not just the open thread. The SSE self-heals via an
  // exponential-backoff reconnect when the stream drops.
  String? _subscribedAccountId;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  Timer? _listRefreshDebounce;
  // Per-conversation high-water mark of the unread count we last toasted, so a
  // single message never re-notifies on repeated silent refreshes.
  final Map<String, int> _lastNotifiedUnread = <String, int>{};
  DateTime _lastTypingSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  // Cloud-remote mode only: cloudMessageId -> 15s watchdog started right
  // after an optimistic send resolves, cleared by a matching `message.status`
  // SSE event (see `_trackCloudSendStatus`/`_applyCloudMessageStatusEvent`).
  final Map<String, Timer> _pendingCloudSendTimers = <String, Timer>{};

  LiveChatNotifier(this._repository, {bool Function()? notificationsEnabled})
    : _notificationsEnabled = notificationsEnabled ?? (() => false),
      super(LiveChatState.initial()) {
    unawaited(_loadSavedFilters());
    loadAccounts();
    loadConversations(loadSelectedMessages: true);
  }

  Future<void> _loadSavedFilters() async {
    try {
      final filters = (await _repository.cache.getSavedFilters())
          .map(ConversationSavedFilter.fromJson)
          .where((filter) => filter.id.isNotEmpty && filter.name.isNotEmpty)
          .toList();
      if (filters.isNotEmpty) {
        state = state.copyWith(savedFilters: filters);
      }
    } catch (_) {}
  }

  Future<void> _persistSavedFilters() async {
    try {
      await _repository.cache.saveSavedFilters(
        state.savedFilters.map((filter) => filter.toJson()).toList(),
      );
    } catch (_) {}
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
    // Refresh the per-account AI auto-reply gate so the Bot toggle reflects it.
    final aiSettings = await getAccountAiAutoReply();
    state = state.copyWith(accountAiAutoReply: aiSettings);
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
      try {
        var conversations = (response['data'] as List)
            .whereType<Map>()
            .map(
              (item) => Conversation.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
        conversations = await _filterManagedGroupConversations(conversations);
        conversations = _mergeWorkflowState(conversations);
        // Only on silent refreshes (poll/SSE) do we surface a desktop toast for
        // newly arrived inbound messages — never on the first/manual full load.
        if (silent) {
          _notifyNewInboundMessages(conversations);
        } else {
          // Manual/account-switch load → reset the toast baseline so a later
          // silent refresh only notifies for genuinely NEW unread.
          _lastNotifiedUnread
            ..clear()
            ..addEntries(
              conversations.map((c) => MapEntry(c.id, c.unreadCount)),
            );
        }
        final selected = _selectedAfterRefresh(conversations);
        final hasSelected = selected.id.isNotEmpty;
        final isNewOrEmpty =
            state.selectedConversation == null ||
            state.selectedConversation!.id != selected.id ||
            selected.messages.isEmpty;
        final shouldLoadMessages =
            hasSelected && (loadSelectedMessages || isNewOrEmpty);

        state = state.copyWith(
          conversations: conversations,
          selectedConversation: selected.id.isEmpty ? null : selected,
          isLoading: false,
          isRefreshingConversations: false,
        );
        if (shouldLoadMessages) {
          await loadMessages(selected.id);
          _subscribeToEvents(selected);
          await _loadDraft(selected);
        }
      } catch (e, stack) {
        AppLogger().error(
          '[LiveChatProvider] Error parsing conversations: $e',
          e,
          stack,
        );
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Lỗi parse dữ liệu hội thoại: $e',
        );
      }
    } else {
      AppLogger().error(
        '[LiveChatProvider] loadConversations failed. Response: $response',
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: (response['message'] ?? 'Không thể tải hội thoại.')
            .toString(),
      );
    }
  }

  Conversation _selectedAfterRefresh(List<Conversation> conversations) {
    final current = state.selectedConversation;
    if (current != null && current.id.isNotEmpty) {
      for (final conversation in conversations) {
        if (conversation.id == current.id) {
          return conversation.copyWith(
            messages: current.messages,
            crmCustomer: current.crmCustomer,
            unreadCount: current.unreadCount,
          );
        }
      }
      // The open conversation is not in this (paginated/filtered) batch. Keep it
      // selected instead of silently jumping to a different conversation.
      return current;
    }
    return conversations.isEmpty ? _emptyConversation : conversations.first;
  }

  List<Conversation> _mergeWorkflowState(List<Conversation> conversations) {
    final existingById = <String, Conversation>{
      for (final conversation in state.conversations)
        conversation.id: conversation,
    };
    final selected = state.selectedConversation;
    if (selected != null) existingById[selected.id] = selected;
    return conversations.map((conversation) {
      final existing = existingById[conversation.id];
      if (existing == null) return conversation;
      return conversation.copyWith(
        followUpAtSet: existing.followUpAt,
        archived: existing.archived,
        assignedTo: existing.assignedTo,
      );
    }).toList();
  }

  Future<List<Conversation>> _filterManagedGroupConversations(
    List<Conversation> conversations,
  ) async {
    // Luôn hiển thị tất cả các group (mặc định bật)
    return conversations;
  }

  // Fire a desktop toast for conversations whose unread count rose since the
  // previous snapshot (inbound only — outbound never bumps unread). Skips the
  // conversation the operator is actively viewing, and the very first load
  // (empty baseline) to avoid a burst of toasts on startup.
  void _notifyNewInboundMessages(List<Conversation> updated) {
    // The very first load establishes the baseline silently (no toast burst).
    final firstLoad = state.conversations.isEmpty;
    final selectedId = state.selectedConversation?.id;
    final notify = _notificationsEnabled();
    for (final conv in updated) {
      final lastNotified = _lastNotifiedUnread[conv.id] ?? 0;
      final hasNew = conv.unreadCount > lastNotified;
      // Always advance the high-water mark so the SAME message can never be
      // toasted twice across repeated silent refreshes (fixes the toast loop).
      if (conv.unreadCount != lastNotified) {
        _lastNotifiedUnread[conv.id] = conv.unreadCount;
      }
      if (!notify || firstLoad || !hasNew) continue;
      if (conv.id == selectedId && state.isChatFocused) continue;
      final title = conv.customerName.isNotEmpty
          ? conv.customerName
          : 'Tin nhắn mới';
      DesktopNotifier.instance.show(title, conv.lastMessage);
    }
  }

  Future<void> selectAccount(LiveChatAccount? account) async {
    state = state.copyWith(
      selectedAccount: account,
      selectedConversation: null,
    );
    await loadConversations(loadSelectedMessages: true);
  }

  /// Deep-link entry: open the conversation for [accountId] + [threadId]
  /// (e.g. from a care task linked to a Zalo group). Selects the matching
  /// account (or all accounts), reloads, then selects the thread.
  Future<void> openByThread(String accountId, String threadId) async {
    if (threadId.isEmpty) return;
    final matched = state.accounts.where((a) => a.id == accountId).toList();
    final account = matched.isNotEmpty ? matched.first : state.accounts.first;
    await selectAccount(account);
    final convs = state.conversations
        .where(
          (c) =>
              c.threadId == threadId &&
              (accountId.isEmpty || c.accountId == accountId),
        )
        .toList();
    if (convs.isNotEmpty) {
      await selectConversation(convs.first);
    } else {
      state = state.copyWith(
        errorMessage:
            'Chưa thấy hội thoại nhóm này trong Live Chat (có thể chưa có tin nhắn).',
      );
    }
  }

  Future<void> setSearchQuery(String query) async {
    state = state.copyWith(searchQuery: query);
    await loadConversations(loadSelectedMessages: true);
  }

  void setLabelFilter(String label) {
    state = state.copyWith(
      selectedLabelFilter: label,
      selectedSavedFilterId: '',
    );
  }

  void setUnreadOnlyFilter(bool enabled) {
    state = state.copyWith(
      unreadOnlyFilter: enabled,
      selectedSavedFilterId: '',
    );
  }

  void setLabeledOnlyFilter(bool enabled) {
    state = state.copyWith(
      labeledOnlyFilter: enabled,
      selectedSavedFilterId: '',
    );
  }

  void setInboxStatusFilter(InboxStatusFilter filter) {
    state = state.copyWith(
      inboxStatusFilter: filter,
      unreadOnlyFilter: filter == InboxStatusFilter.unread,
      selectedSavedFilterId: '',
    );
  }

  void clearConversationFilters() {
    state = state.copyWith(
      selectedLabelFilter: '',
      unreadOnlyFilter: false,
      labeledOnlyFilter: false,
      inboxStatusFilter: InboxStatusFilter.all,
      selectedSavedFilterId: '',
    );
  }

  void saveCurrentFilter(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || !state.hasActiveConversationFilters) return;
    final filter = ConversationSavedFilter(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: trimmed,
      label: state.selectedLabelFilter,
      unreadOnly: state.unreadOnlyFilter,
      labeledOnly: state.labeledOnlyFilter,
      inboxStatus: state.inboxStatusFilter,
    );
    state = state.copyWith(
      savedFilters: [filter, ...state.savedFilters],
      selectedSavedFilterId: filter.id,
    );
    unawaited(_persistSavedFilters());
  }

  void applySavedFilter(ConversationSavedFilter filter) {
    state = state.copyWith(
      selectedLabelFilter: filter.label,
      unreadOnlyFilter: filter.unreadOnly,
      labeledOnlyFilter: filter.labeledOnly,
      inboxStatusFilter: filter.inboxStatus,
      selectedSavedFilterId: filter.id,
    );
  }

  void deleteSavedFilter(String id) {
    state = state.copyWith(
      savedFilters: state.savedFilters
          .where((filter) => filter.id != id)
          .toList(),
      selectedSavedFilterId: state.selectedSavedFilterId == id
          ? ''
          : state.selectedSavedFilterId,
    );
    unawaited(_persistSavedFilters());
  }

  Future<void> selectConversation(Conversation conversation) async {
    // Switch the open thread synchronously so the tap feels instant — the
    // header, contact panel and input swap immediately instead of waiting on
    // the SQLite cache read + network round-trip below.
    state = state.copyWith(
      selectedConversation: conversation.copyWith(
        unreadCount: 0,
        messages: const [],
      ),
      hasMoreMessages: true,
      isUsingCachedMessages: false,
      isLoadingMessages: true,
      replyingTo: null,
      typingUserIds: <String>{},
    );
    _subscribeToEvents(conversation);

    // Hydrate from the local cache first (fast) so older messages paint before
    // the network reply lands. Guard against a newer switch racing ahead.
    final cachedData = await _repository.getCachedMessages(conversation.id);
    final cachedMessages =
        cachedData
            .map(
              (item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final current = state.selectedConversation;
    if (current != null &&
        current.id == conversation.id &&
        cachedMessages.isNotEmpty) {
      state = state.copyWith(
        selectedConversation: current.copyWith(messages: cachedMessages),
        isUsingCachedMessages: true,
      );
    }

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
    Map<String, String>? customFields,
  }) async {
    final conversation = state.selectedConversation;
    if (conversation == null) return false;
    final normalizedTags = _normalizeTags(tags);
    final existingCustomer = conversation.crmCustomer;
    final resolvedCustomFields =
        customFields ??
        existingCustomer?.customFields ??
        conversation.customAttributes;

    state = state.copyWith(isSending: true);
    try {
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
        tags: normalizedTags,
        source: source.isEmpty ? 'Zalo Live Chat' : source,
        lifecycleStage: existingCustomer?.lifecycleStage ?? 'lead',
        consentStatus: existingCustomer?.consentStatus ?? 'granted',
        consentEvidence:
            existingCustomer?.consentEvidence ?? 'Updated from Live Chat CRM',
        customFields: resolvedCustomFields,
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

        final updatedTag = normalizedTags.isNotEmpty
            ? normalizedTags.first
            : '';
        await _repository.updateConversation(conversation.id, {
          'tags': normalizedTags,
          'notes': notes,
          'customAttributes': savedCustomer.customFields,
        });

        final updated = conversation.copyWith(
          crmCustomer: savedCustomer,
          tag: updatedTag,
          labels: normalizedTags,
          notes: notes,
          customAttributes: savedCustomer.customFields,
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
    try {
      await _repository.updateConversation(conversation.id, {
        'tags': normalizedTags,
        'notes': notes,
        'customAttributes': resolvedCustomFields,
      });
      final updated = conversation.copyWith(
        tag: normalizedTags.isEmpty ? '' : normalizedTags.first,
        labels: normalizedTags,
        notes: notes,
        customAttributes: resolvedCustomFields,
      );
      state = state.copyWith(
        selectedConversation: updated,
        conversations: state.conversations
            .map((c) => c.id == conversation.id ? updated : c)
            .toList(),
        isSending: false,
      );
      return true;
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

    if (response['success'] != true || response['data'] is! List) {
      return;
    }
    final messages = (response['data'] as List)
        .whereType<Map>()
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final selected = state.selectedConversation;
    if (selected == null || selected.id != conversationId) {
      return;
    }
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
    // millisecondsSinceEpoch (NOT micro): the backend pins zca-js's clientId to this
    // value; a microsecond id (~1000x larger) lands far in the future and makes
    // tough-cookie drop the `zpw_sek` cookie → every send fails with code 600.
    final clientMessageId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
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
        if (_repository.isCloudRemote) {
          // No bridge round-trip to reload from — keep the optimistic bubble
          // and track its cloud id so `message.status` SSE events (or the
          // 15s timeout) can resolve it in place instead of reloading (a
          // reload would duplicate the bubble: the cloud message has no
          // clientMessageId, so it wouldn't merge-key against the optimistic
          // one — see `_messageKey`).
          final cloudMessageId = _extractCloudMessageId(response);
          if (cloudMessageId.isNotEmpty) {
            _trackCloudSendStatus(clientMessageId, cloudMessageId);
          }
        } else {
          await loadMessages(conversation.id);
        }
        _markOperatorTakeover(conversation);
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
        (response['error'] ?? response['message'] ?? 'Gửi tin nhắn thất bại.')
            .toString(),
        localMessageId: response['localMessageId']?.toString(),
      );
    } catch (error) {
      _setOptimisticFailed(clientMessageId, error.toString());
    }
  }

  String _extractCloudMessageId(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map) {
      final message = data['message'];
      if (message is Map) {
        return (message['_id'] ?? message['id'] ?? '').toString();
      }
    }
    return '';
  }

  /// Renumbers the optimistic bubble to the cloud message id and starts a
  /// 15s watchdog; `_applyCloudMessageStatusEvent`/`_timeoutCloudMessage`
  /// resolve it to sent/failed. See FE-5 in the mobile-web tasklist.
  void _trackCloudSendStatus(String clientMessageId, String cloudMessageId) {
    final conversation = state.selectedConversation;
    if (conversation == null) return;
    final updatedMessages = conversation.messages
        .map(
          (message) => message.clientMessageId == clientMessageId
              ? message.copyWith(id: cloudMessageId)
              : message,
        )
        .toList();
    _replaceSelected(conversation.copyWith(messages: updatedMessages));

    _pendingCloudSendTimers.remove(cloudMessageId)?.cancel();
    _pendingCloudSendTimers[cloudMessageId] = Timer(
      const Duration(seconds: 15),
      () {
        _pendingCloudSendTimers.remove(cloudMessageId);
        _timeoutCloudMessage(cloudMessageId);
      },
    );
  }

  void _timeoutCloudMessage(String cloudMessageId) {
    final conversation = state.selectedConversation;
    if (conversation == null) return;
    var matched = false;
    final updatedMessages = conversation.messages.map((message) {
      if (message.id == cloudMessageId &&
          (message.status == 'sending' || message.status == 'queued')) {
        matched = true;
        return message.copyWith(
          status: 'failed',
          errorText: 'Không có phản hồi từ máy chủ Desktop.',
        );
      }
      return message;
    }).toList();
    if (matched) {
      _replaceSelected(conversation.copyWith(messages: updatedMessages));
    }
  }

  /// Applies a `message.status` SSE event (queued/sent/failed) to the
  /// matching bubble, cancelling its 15s timeout watchdog.
  void _applyCloudMessageStatusEvent(LiveChatEvent event) {
    final messageId = (event.data['messageId'] ?? '').toString();
    final status = (event.data['status'] ?? '').toString();
    if (messageId.isEmpty || status.isEmpty) return;
    _pendingCloudSendTimers.remove(messageId)?.cancel();
    final conversation = state.selectedConversation;
    if (conversation == null) return;
    var matched = false;
    final errorMessage = (event.data['errorMessage'] ?? '').toString();
    final updatedMessages = conversation.messages.map((message) {
      if (message.id == messageId) {
        matched = true;
        return message.copyWith(
          status: status,
          errorText: status == 'failed' ? errorMessage : '',
        );
      }
      return message;
    }).toList();
    if (matched) {
      _replaceSelected(conversation.copyWith(messages: updatedMessages));
    }
  }

  Future<void> sendLink(String url, {String title = ''}) async {
    final conversation = state.selectedConversation;
    final normalized = url.trim();
    if (conversation == null || normalized.isEmpty) return;
    state = state.copyWith(isSending: true, errorMessage: null);
    try {
      final response = await _repository.sendRichMessage(
        conversation.id,
        title.trim().isEmpty ? normalized : title.trim(),
        clientMessageId: 'flutter_${DateTime.now().millisecondsSinceEpoch}',
        messageType: 'link',
        link: {'url': normalized, 'href': normalized, 'title': title.trim()},
      );
      if (response['success'] == true) {
        await loadMessages(conversation.id);
        _markOperatorTakeover(conversation);
        state = state.copyWith(isSending: false);
      } else {
        if (response['localMessageId'] != null) {
          await loadMessages(conversation.id);
        }
        final errorMsg = (response['error'] ?? 'Gửi liên kết thất bại.')
            .toString();
        AppLogger().error('Gửi liên kết Live Chat thất bại: $errorMsg');
        state = state.copyWith(isSending: false, errorMessage: errorMsg);
      }
    } catch (error, stack) {
      AppLogger().error(
        'Ngoại lệ khi gửi liên kết Live Chat: $error',
        error,
        stack,
      );
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Gửi liên kết thất bại: $error',
      );
    }
  }

  Future<void> sendSticker(Map<String, dynamic> sticker) async {
    final conversation = state.selectedConversation;
    if (conversation == null || sticker.isEmpty) return;
    state = state.copyWith(isSending: true, errorMessage: null);
    try {
      final response = await _repository.sendRichMessage(
        conversation.id,
        '',
        clientMessageId: 'flutter_${DateTime.now().millisecondsSinceEpoch}',
        messageType: 'sticker',
        sticker: sticker,
      );
      if (response['success'] == true) {
        await loadMessages(conversation.id);
        _markOperatorTakeover(conversation);
        state = state.copyWith(isSending: false);
      } else {
        final errorMsg = (response['error'] ?? 'Gửi sticker thất bại.')
            .toString();
        AppLogger().error('Gửi sticker Live Chat thất bại: $errorMsg');
        state = state.copyWith(isSending: false, errorMessage: errorMsg);
      }
    } catch (error, stack) {
      AppLogger().error(
        'Ngoại lệ khi gửi sticker Live Chat: $error',
        error,
        stack,
      );
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Gửi sticker thất bại: $error',
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
    AppLogger().error(
      'Gửi tin nhắn Live Chat thất bại (ID: $clientMessageId): $error',
    );
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
    if (_repository.isCloudRemote) {
      // Cloud has no retry-by-id endpoint (see FE-5 in the mobile-web
      // tasklist) — drop the failed bubble and resend the same content as a
      // brand new message.
      _replaceSelected(
        conversation.copyWith(
          messages: conversation.messages
              .where((item) => item.id != message.id)
              .toList(),
        ),
      );
      await sendMessage(message.message);
      return;
    }
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
          (response['error'] ?? 'Gửi lại thất bại.').toString(),
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
    if (message.isMine || message.providerActionId.isEmpty) return;
    try {
      final response = await _repository.reactToMessage(
        message.providerActionId,
        reaction,
      );
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
    if (selected == null) return;
    try {
      final response = await _repository.searchMessages(
        query.trim(),
        accountId: selected.accountId,
        threadId: selected.threadId,
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
        return;
      }
    } catch (_) {
      // Fall back to the loaded conversation when the bridge is unavailable.
    }
    final needle = query.trim().toLowerCase();
    state = state.copyWith(
      messageSearchResults: selected.messages
          .where((message) => message.message.toLowerCase().contains(needle))
          .toList(),
    );
  }

  Future<void> openSearchResult(ChatMessage message) async {
    final selected = state.selectedConversation;
    if (selected == null) return;
    if (selected.messages.any((item) => item.id == message.id)) {
      _highlightSearchResult(message.id);
      return;
    }
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
    _highlightSearchResult(message.id);
  }

  void _highlightSearchResult(String messageId) {
    state = state.copyWith(highlightedMessageId: messageId);
    Timer(const Duration(seconds: 2), () {
      if (state.highlightedMessageId == messageId) {
        state = state.copyWith(highlightedMessageId: '');
      }
    });
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
    final tags = _parseTagInput(tag);
    final response = await _repository.updateConversation(conversation.id, {
      'tags': tags,
    });
    if (response['success'] == true) {
      _replaceSelected(
        conversation.copyWith(
          tag: tags.isEmpty ? '' : tags.first,
          labels: tags,
        ),
      );
    }
  }

  Future<void> toggleChatbot(bool enabled) async {
    final conversation = state.selectedConversation;
    if (conversation == null) return;
    // Optimistic flip for instant feedback; turning ON also clears any pause.
    _replaceSelected(
      conversation.copyWith(
        chatbotEnabled: enabled,
        chatbotPausedUntilSet: enabled ? null : conversation.chatbotPausedUntil,
      ),
    );
    try {
      final response = await _repository.updateChatbotState(
        ConversationTarget(
          id: conversation.id,
          accountId: conversation.accountId,
          threadId: conversation.threadId,
          threadType: conversation.threadType,
        ),
        enabled: enabled,
      );
      if (response['success'] != true) {
        _replaceSelected(conversation); // revert on failure
      }
    } catch (_) {
      _replaceSelected(conversation); // revert on error
    }
  }

  Future<void> pauseChatbotForSelected() async {
    final conversation = state.selectedConversation;
    if (conversation == null) return;
    await setChatbotForConversation(conversation, false);
  }

  Future<void> setChatbotForConversation(
    Conversation conversation,
    bool enabled,
  ) async {
    _replaceConversation(
      conversation.copyWith(
        chatbotEnabled: enabled,
        chatbotPausedUntilSet: enabled ? null : conversation.chatbotPausedUntil,
      ),
    );
    try {
      final response = await _repository.updateChatbotState(
        ConversationTarget(
          id: conversation.id,
          accountId: conversation.accountId,
          threadId: conversation.threadId,
          threadType: conversation.threadType,
        ),
        enabled: enabled,
      );
      if (response['success'] != true) {
        _replaceConversation(conversation);
      }
    } catch (_) {
      _replaceConversation(conversation);
    }
  }

  void setFollowUp(Conversation conversation, DateTime? followUpAt) {
    _replaceConversation(
      conversation.copyWith(followUpAtSet: followUpAt, archived: false),
    );
  }

  void setSelectedFollowUp(DateTime? followUpAt) {
    final conversation = state.selectedConversation;
    if (conversation == null) return;
    setFollowUp(conversation, followUpAt);
  }

  void toggleArchived(Conversation conversation) {
    _replaceConversation(
      conversation.copyWith(
        archived: !conversation.archived,
        followUpAtSet: conversation.archived ? conversation.followUpAt : null,
      ),
    );
  }

  void toggleAssignedToMe(Conversation conversation) {
    _replaceConversation(
      conversation.copyWith(
        assignedTo: conversation.assignedTo.isEmpty ? 'me' : '',
        archived: false,
      ),
    );
  }

  /// Resume the bot immediately for the open conversation, clearing any pending
  /// operator-pause cooldown (the dimmed AI icon's double-click action).
  Future<void> resumeChatbotNow() async {
    final conversation = state.selectedConversation;
    if (conversation == null || !conversation.chatbotPaused) return;
    // Optimistically brighten the icon; the backend clears `pausedUntil`.
    _replaceSelected(
      conversation.copyWith(chatbotEnabled: true, chatbotPausedUntilSet: null),
    );
    await _repository.updateChatbotState(
      ConversationTarget(
        id: conversation.id,
        accountId: conversation.accountId,
        threadId: conversation.threadId,
        threadType: conversation.threadType,
      ),
      enabled: true,
    );
  }

  void _markOperatorTakeover(Conversation conversation) {
    final current = state.selectedConversation;
    if (current == null || current.id != conversation.id) return;
    // Operator replied → temporary PAUSE (icon dims), NOT a permanent toggle-off.
    // Keep the master switch ON; the backend's conversation.chatbot_state event
    // refines the exact pausedUntil moments later. Skip if the bot is already off.
    if (!current.chatbotEnabled) return;
    _replaceSelected(
      current.copyWith(
        chatbotPausedUntilSet: DateTime.now().add(const Duration(minutes: 10)),
      ),
    );
  }

  /// Per-account AI auto-reply settings (Live Chat settings dialog). Returns a
  /// map of accountId → aiAutoReply (bool); accounts absent default to true.
  Future<Map<String, bool>> getAccountAiAutoReply() async {
    try {
      final response = await _repository.getAccountChatSettings();
      final data = response['data'];
      final result = <String, bool>{};
      if (data is Map) {
        data.forEach((key, value) {
          if (value is Map && value['aiAutoReply'] is bool) {
            result[key.toString()] = value['aiAutoReply'] as bool;
          }
        });
      }
      return result;
    } catch (_) {
      return <String, bool>{};
    }
  }

  Future<bool> setAccountAiAutoReply(String accountId, bool enabled) async {
    try {
      final response = await _repository.setAccountAiAutoReply(
        accountId,
        enabled,
      );
      final ok = response['success'] == true;
      if (ok) {
        // Keep the header Bot toggle's gate in sync with the dialog change.
        state = state.copyWith(
          accountAiAutoReply: {...state.accountAiAutoReply, accountId: enabled},
        );
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Minutes the bot stays paused after a human reply (5–120, default 10).
  Future<int> getOperatorPauseCooldownMinutes() async {
    try {
      final response = await _repository.getAppSettings();
      final value = response['data']?['operatorPauseCooldownMinutes'];
      final minutes = int.tryParse('${value ?? ''}');
      if (minutes != null && minutes >= 5 && minutes <= 120) return minutes;
    } catch (_) {}
    return 10;
  }

  Future<int> setOperatorPauseCooldownMinutes(int minutes) async {
    final clamped = minutes.clamp(5, 120);
    try {
      final response = await _repository.setOperatorPauseCooldownMinutes(
        clamped,
      );
      final saved = response['data']?['operatorPauseCooldownMinutes'];
      return int.tryParse('${saved ?? ''}') ?? clamped;
    } catch (_) {
      return clamped;
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
    try {
      final response = await _repository.sendAttachment(
        conversation.id,
        filePaths,
        content: content,
        messageType: messageType,
      );
      if (response['success'] == true) {
        await loadMessages(conversation.id);
        _markOperatorTakeover(conversation);
        state = state.copyWith(isSending: false);
      } else {
        if (response['localMessageId'] != null) {
          await loadMessages(conversation.id);
        }
        final errorMsg =
            (response['error'] ?? response['message'] ?? 'Gửi file thất bại.')
                .toString();
        AppLogger().error('Gửi tệp tin Live Chat thất bại: $errorMsg');
        state = state.copyWith(isSending: false, errorMessage: errorMsg);
      }
    } catch (error, stack) {
      AppLogger().error(
        'Ngoại lệ khi gửi tệp tin Live Chat: $error',
        error,
        stack,
      );
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Gửi tệp tin thất bại: $error',
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
        final errorMsg =
            (response['message'] ??
                    response['error'] ??
                    'Thu hồi tin nhắn thất bại.')
                .toString();
        AppLogger().error('Thu hồi tin nhắn thất bại: $errorMsg');
        state = state.copyWith(isSending: false, errorMessage: errorMsg);
        return false;
      }
    } catch (error, stack) {
      AppLogger().error(
        'Lỗi ngoại lệ khi thu hồi tin nhắn: $error',
        error,
        stack,
      );
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Thu hồi tin nhắn thất bại: $error',
      );
      return false;
    }
  }

  Future<bool> deleteMessage(String messageId) async {
    final conversation = state.selectedConversation;
    if (conversation == null) return false;
    state = state.copyWith(isSending: true, errorMessage: null);
    try {
      final response = await _repository.deleteMessage(
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
                      'Xóa tin nhắn thất bại.')
                  .toString(),
        );
        return false;
      }
    } catch (error) {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Xóa tin nhắn thất bại: $error',
      );
      return false;
    }
  }

  @override
  void dispose() {
    _subscribedAccountId = null;
    _reconnectTimer?.cancel();
    _listRefreshDebounce?.cancel();
    _eventSubscription?.cancel();
    _eventRefreshDebounce?.cancel();
    _draftDebounce?.cancel();
    for (final timer in _pendingCloudSendTimers.values) {
      timer.cancel();
    }
    _pendingCloudSendTimers.clear();
    super.dispose();
  }

  void _subscribeToEvents(Conversation conversation) {
    // Subscribe per ACCOUNT (not per thread) so the stream survives switching
    // conversations and the list gets realtime updates for every thread.
    if (_subscribedAccountId == conversation.accountId &&
        _eventSubscription != null) {
      // Same account already streaming — just reset per-thread transient state.
      state = state.copyWith(typingUserIds: <String>{});
      return;
    }
    _openAccountStream(conversation.accountId);
  }

  void _openAccountStream(String accountId) {
    _reconnectTimer?.cancel();
    _eventSubscription?.cancel();
    _subscribedAccountId = accountId;
    state = state.copyWith(realtimeConnected: false, typingUserIds: <String>{});
    _eventSubscription = _repository
        .watchEvents(accountId: accountId)
        .listen(
          (event) {
            _reconnectAttempts = 0; // healthy traffic resets the backoff
            _handleRealtimeEvent(event);
          },
          onError: (_) => _scheduleReconnect(),
          onDone: () => _scheduleReconnect(),
        );
  }

  // Self-healing SSE: reconnect with exponential backoff (1,2,4,…,30s) instead
  // of leaving realtime dead until the next manual conversation switch.
  void _scheduleReconnect() {
    state = state.copyWith(realtimeConnected: false);
    final accountId = _subscribedAccountId;
    if (accountId == null) return;
    _reconnectTimer?.cancel();
    final delaySeconds = (1 << _reconnectAttempts).clamp(1, 30);
    if (_reconnectAttempts < 5) _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_subscribedAccountId == accountId) _openAccountStream(accountId);
    });
  }

  void _scheduleListRefresh() {
    _listRefreshDebounce?.cancel();
    _listRefreshDebounce = Timer(const Duration(milliseconds: 400), () {
      loadConversations(silent: true);
    });
  }

  void _handleRealtimeEvent(LiveChatEvent event) {
    if (event.type == 'bridge.connected') {
      state = state.copyWith(realtimeConnected: true);
      loadAccounts();
      loadConversations(loadSelectedMessages: true);
      return;
    }
    if (event.type == 'conversation.chatbot_state') {
      _applyChatbotStateEvent(event);
      state = state.copyWith(realtimeConnected: true);
      return;
    }
    if (event.type == 'message.status') {
      _applyCloudMessageStatusEvent(event);
      state = state.copyWith(realtimeConnected: true);
      return;
    }
    state = state.copyWith(realtimeConnected: true);

    final selected = state.selectedConversation;
    final isForSelected =
        selected != null &&
        (event.threadId.isEmpty || event.threadId == selected.threadId) &&
        (event.accountId.isEmpty ||
            selected.accountId.isEmpty ||
            event.accountId == selected.accountId);

    if (!isForSelected) {
      // Event for another thread on this account → refresh the conversation list
      // so its unread/last-message updates live (and a toast may surface).
      if (event.type == 'message.created') {
        if (!state.isChatFocused) {
          state = state.copyWith(
            unfocusedNewMessageCount: state.unfocusedNewMessageCount + 1,
          );
        }
        _scheduleListRefresh();
      }
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
      state = state.copyWith(typingUserIds: typing);
      return;
    }
    if (event.type == 'group.updated' || event.type == 'friend.updated') {
      loadConversations(silent: true);
      return;
    }
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
    // Keep the list (preview/unread) fresh for the open thread too.
    _scheduleListRefresh();
  }

  void _applyChatbotStateEvent(LiveChatEvent event) {
    final mode = (event.data['mode'] ?? '').toString();
    // Master switch (toggle) follows `mode`; the operator-pause window is
    // orthogonal and carried by `pausedUntil`.
    final enabled = mode.isEmpty
        ? event.data['effectiveEnabled'] == true
        : mode == 'enabled';
    final pausedUntil = _pausedUntilFrom(event.data['pausedUntil']);
    Conversation apply(Conversation c) =>
        c.copyWith(chatbotEnabled: enabled, chatbotPausedUntilSet: pausedUntil);
    bool matches(Conversation c) =>
        c.threadId == event.threadId &&
        (event.accountId.isEmpty || c.accountId == event.accountId);
    final selected = state.selectedConversation;
    final updatedSelected = selected != null && matches(selected)
        ? apply(selected)
        : selected;
    state = state.copyWith(
      selectedConversation: updatedSelected,
      conversations: state.conversations
          .map((c) => matches(c) ? apply(c) : c)
          .toList(),
    );
  }

  void _replaceSelected(Conversation updated) {
    _replaceConversation(updated, updateSelected: true);
  }

  void _replaceConversation(
    Conversation updated, {
    bool updateSelected = false,
  }) {
    final shouldUpdateSelected =
        updateSelected || state.selectedConversation?.id == updated.id;
    state = state.copyWith(
      selectedConversation: shouldUpdateSelected
          ? updated
          : state.selectedConversation,
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
    return LiveChatNotifier(
      ref.read(liveChatRepositoryProvider),
      notificationsEnabled: () =>
          ref.read(settingsProvider).settings.liveChatNotifications,
    );
  },
);

/// Pending deep-link target consumed by [LiveChatScreen] on mount to open a
/// specific conversation (e.g. from a care task's "Mở Live Chat" button).
class LiveChatDeepLink {
  final String accountId;
  final String threadId;

  const LiveChatDeepLink({required this.accountId, required this.threadId});
}

final liveChatDeepLinkProvider = StateProvider<LiveChatDeepLink?>(
  (ref) => null,
);

List<String> _parseTagInput(String input) {
  return _normalizeTags(
    input
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(),
  );
}

List<String> _normalizeTags(List<String> tags) {
  final normalized = <String>{};
  for (final tag in tags) {
    final clean = tag.trim().toWellFormed();
    if (clean.isNotEmpty) normalized.add(clean);
  }
  return normalized.toList();
}

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
  labels: const [],
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
  // Treat an empty object as "absent" so callers (e.g. the reply-quote box,
  // which renders whenever quote != null) don't fire on a `{}` placeholder.
  if (value is Map) {
    return value.isEmpty ? null : Map<String, dynamic>.from(value);
  }
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return decoded.isEmpty ? null : Map<String, dynamic>.from(decoded);
      }
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
  // The local bridge stores lastMessagePreview as an envelope
  // {"direction","messageType","content"}. Unwrap it once so we format the real
  // text/type/direction instead of rendering the raw JSON string. Structured
  // payloads (sticker/file/link JSON inside `content`) fall through to the typed
  // handling below via the carried messageType.
  final envelope = rawMessage.trim();
  if (envelope.startsWith('{') && envelope.endsWith('}')) {
    try {
      final decoded = jsonDecode(envelope);
      if (decoded is Map &&
          decoded['isDeleted'] != true &&
          decoded.containsKey('content') &&
          (decoded.containsKey('direction') ||
              decoded.containsKey('messageType'))) {
        return _formatConversationPreview(
          decoded['content']?.toString() ?? '',
          messageType:
              (messageType ?? decoded['messageType'] ?? decoded['contentType'])
                  ?.toString(),
          direction: (direction ?? decoded['direction'])?.toString(),
        );
      }
    } catch (_) {}
  }

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
