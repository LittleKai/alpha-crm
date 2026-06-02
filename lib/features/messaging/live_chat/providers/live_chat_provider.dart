import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/live_chat_repository.dart';

const Object _unset = Object();

final liveChatRepositoryProvider = Provider<LiveChatRepository>((ref) {
  return LiveChatRepository();
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
  final String message;
  final String direction;
  final String status;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.direction,
    required this.status,
    required this.timestamp,
  });

  bool get isMine => direction == 'outbound';

  static ChatMessage fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      senderName: (json['senderName'] ?? '').toString(),
      message: (json['content'] ?? '').toString(),
      direction: (json['direction'] ?? 'inbound').toString(),
      status: (json['status'] ?? '').toString(),
      timestamp: _dateFrom(
        json['sentAt'] ?? json['receivedAt'] ?? json['createdAt'],
      ),
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
  });

  Conversation copyWith({
    String? tag,
    String? notes,
    bool? chatbotEnabled,
    int? unreadCount,
    List<ChatMessage>? messages,
    String? lastMessage,
    DateTime? lastMessageTime,
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
      customerAvatar: name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
      lastMessage: (json['lastMessagePreview'] ?? '').toString(),
      lastMessageTime: _dateFrom(json['lastMessageAt'] ?? json['updatedAt']),
      unreadCount: int.tryParse((json['unreadCount'] ?? 0).toString()) ?? 0,
      tag: tags.isEmpty ? '' : tags.first.toString(),
      notes: (json['notes'] ?? '').toString(),
      chatbotEnabled: json['chatbotEnabled'] != false,
      messages: const [],
    );
  }
}

class LiveChatState {
  final LiveChatAccount? selectedAccount;
  final List<LiveChatAccount> accounts;
  final List<Conversation> conversations;
  final Conversation? selectedConversation;
  final bool isLoading;
  final bool isSending;
  final String searchQuery;
  final String? errorMessage;

  const LiveChatState({
    this.selectedAccount,
    required this.accounts,
    required this.conversations,
    this.selectedConversation,
    required this.isLoading,
    required this.isSending,
    required this.searchQuery,
    this.errorMessage,
  });

  factory LiveChatState.initial() {
    return const LiveChatState(
      selectedAccount: LiveChatAccount(id: '', label: 'Tat ca tai khoan'),
      accounts: [LiveChatAccount(id: '', label: 'Tat ca tai khoan')],
      conversations: [],
      selectedConversation: null,
      isLoading: false,
      isSending: false,
      searchQuery: '',
      errorMessage: null,
    );
  }

  LiveChatState copyWith({
    Object? selectedAccount = _unset,
    List<LiveChatAccount>? accounts,
    List<Conversation>? conversations,
    Object? selectedConversation = _unset,
    bool? isLoading,
    bool? isSending,
    String? searchQuery,
    String? errorMessage,
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
      isSending: isSending ?? this.isSending,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
    );
  }
}

class LiveChatNotifier extends StateNotifier<LiveChatState> {
  final LiveChatRepository _repository;

  LiveChatNotifier(this._repository) : super(LiveChatState.initial()) {
    loadAccounts();
    loadConversations();
  }

  Future<void> loadAccounts() async {
    final response = await _repository.getAccounts();
    if (response['success'] != true) return;
    final data = response['data'];
    final rawAccounts = data is Map ? data['accounts'] : null;
    final accounts = <LiveChatAccount>[
      const LiveChatAccount(id: '', label: 'Tat ca tai khoan'),
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

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final response = await _repository.getConversations(
      accountId: state.selectedAccount?.id,
      search: state.searchQuery,
    );

    if (response['success'] == true && response['data'] is List) {
      final conversations = (response['data'] as List)
          .whereType<Map>()
          .map((item) => Conversation.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final selected = conversations.firstWhere(
        (conversation) => conversation.id == state.selectedConversation?.id,
        orElse: () =>
            conversations.isEmpty ? _emptyConversation : conversations.first,
      );
      state = state.copyWith(
        conversations: conversations,
        selectedConversation: conversations.isEmpty ? null : selected,
        isLoading: false,
      );
      if (conversations.isNotEmpty) {
        await loadMessages(selected.id);
      }
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: (response['message'] ?? 'Khong the tai hoi thoai.')
            .toString(),
      );
    }
  }

  Future<void> selectAccount(LiveChatAccount? account) async {
    state = state.copyWith(
      selectedAccount: account,
      selectedConversation: null,
    );
    await loadConversations();
  }

  Future<void> setSearchQuery(String query) async {
    state = state.copyWith(searchQuery: query);
    await loadConversations();
  }

  Future<void> selectConversation(Conversation conversation) async {
    state = state.copyWith(
      selectedConversation: conversation.copyWith(unreadCount: 0),
    );
    await Future.wait([
      loadMessages(conversation.id),
      _repository.markRead(conversation.id),
    ]);
  }

  Future<void> loadMessages(String conversationId) async {
    final response = await _repository.getMessages(conversationId);
    if (response['success'] != true || response['data'] is! List) return;
    final messages = (response['data'] as List)
        .whereType<Map>()
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final selected = state.selectedConversation;
    if (selected == null || selected.id != conversationId) return;
    final updated = selected.copyWith(messages: messages, unreadCount: 0);
    state = state.copyWith(
      selectedConversation: updated,
      conversations: state.conversations
          .map(
            (conversation) =>
                conversation.id == conversationId ? updated : conversation,
          )
          .toList(),
    );
  }

  Future<void> sendMessage(String text) async {
    final conversation = state.selectedConversation;
    if (conversation == null || text.trim().isEmpty) return;
    state = state.copyWith(isSending: true, errorMessage: null);
    final response = await _repository.sendMessage(
      conversation.id,
      text.trim(),
    );
    if (response['success'] == true) {
      await loadMessages(conversation.id);
      await loadConversations();
      state = state.copyWith(isSending: false);
    } else {
      state = state.copyWith(
        isSending: false,
        errorMessage: (response['message'] ?? 'Gui tin nhan that bai.')
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
);

DateTime _dateFrom(Object? value) {
  if (value == null) return DateTime.now();
  return DateTime.tryParse(value.toString()) ?? DateTime.now();
}
