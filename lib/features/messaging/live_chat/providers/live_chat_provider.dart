import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../mock/mock_campaigns.dart';

class ChatMessage {
  final String id;
  final String senderId; // 'me' or 'customer'
  final String senderName;
  final String message;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
  });
}

class Conversation {
  final String id;
  final String customerName;
  final String customerPhone;
  final String customerAvatar;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String tag;
  final String notes;
  final List<ChatMessage> messages;

  const Conversation({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.customerAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.tag,
    required this.notes,
    required this.messages,
  });

  Conversation copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    String? customerAvatar,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    String? tag,
    String? notes,
    List<ChatMessage>? messages,
  }) {
    return Conversation(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAvatar: customerAvatar ?? this.customerAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      tag: tag ?? this.tag,
      notes: notes ?? this.notes,
      messages: messages ?? this.messages,
    );
  }
}

class LiveChatState {
  final ZaloAccount? selectedAccount;
  final List<ZaloAccount> accounts;
  final List<Conversation> conversations;
  final Conversation? selectedConversation;
  final bool isLoading;

  const LiveChatState({
    this.selectedAccount,
    required this.accounts,
    required this.conversations,
    this.selectedConversation,
    required this.isLoading,
  });

  factory LiveChatState.initial() {
    return const LiveChatState(
      selectedAccount: null,
      accounts: MockCampaignsData.sampleAccounts,
      conversations: [],
      selectedConversation: null,
      isLoading: false,
    );
  }

  LiveChatState copyWith({
    ZaloAccount? selectedAccount,
    List<ZaloAccount>? accounts,
    List<Conversation>? conversations,
    Conversation? selectedConversation,
    bool? isLoading,
  }) {
    return LiveChatState(
      selectedAccount: selectedAccount,
      accounts: accounts ?? this.accounts,
      conversations: conversations ?? this.conversations,
      selectedConversation: selectedConversation,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class LiveChatNotifier extends StateNotifier<LiveChatState> {
  LiveChatNotifier() : super(LiveChatState.initial());

  void selectAccount(ZaloAccount? account) {
    if (account == null || !account.isConnected) {
      state = state.copyWith(
        selectedAccount: null,
        conversations: [],
        selectedConversation: null,
      );
      return;
    }

    state = state.copyWith(isLoading: true, selectedAccount: account);

    // Simulate loading conversations
    Future.delayed(const Duration(milliseconds: 400), () {
      final mockConvs = _getMockConversations();
      state = state.copyWith(
        conversations: mockConvs,
        selectedConversation: mockConvs.isNotEmpty ? mockConvs[0] : null,
        isLoading: false,
      );
    });
  }

  void selectConversation(Conversation conversation) {
    // Mark as read
    final updatedConvs = state.conversations.map((c) {
      if (c.id == conversation.id) {
        return c.copyWith(unreadCount: 0);
      }
      return c;
    }).toList();

    state = state.copyWith(
      conversations: updatedConvs,
      selectedConversation: conversation.copyWith(unreadCount: 0),
    );
  }

  void sendMessage(String text) {
    if (state.selectedConversation == null || text.trim().isEmpty) return;

    final activeConv = state.selectedConversation!;
    final newMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'me',
      senderName: state.selectedAccount?.name ?? 'Me',
      message: text,
      timestamp: DateTime.now(),
    );

    final updatedMessages = [...activeConv.messages, newMessage];
    final updatedConv = activeConv.copyWith(
      messages: updatedMessages,
      lastMessage: text,
      lastMessageTime: DateTime.now(),
    );

    final updatedConvs = state.conversations.map((c) {
      return c.id == activeConv.id ? updatedConv : c;
    }).toList();

    state = state.copyWith(
      conversations: updatedConvs,
      selectedConversation: updatedConv,
    );

    // Simulate automatic bot reply after 1.5 seconds for nice interactivity
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (state.selectedConversation?.id != activeConv.id) return;

      final replyMsg = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: 'customer',
        senderName: activeConv.customerName,
        message:
            'Cảm ơn anh/chị đã nhắn tin. Em đã nhận được thông tin và sẽ phản hồi sớm nhất ạ!',
        timestamp: DateTime.now(),
      );

      final replyConv = state.selectedConversation!.copyWith(
        messages: [...state.selectedConversation!.messages, replyMsg],
        lastMessage: replyMsg.message,
        lastMessageTime: DateTime.now(),
      );

      final finalConvs = state.conversations.map((c) {
        return c.id == activeConv.id ? replyConv : c;
      }).toList();

      state = state.copyWith(
        conversations: finalConvs,
        selectedConversation: replyConv,
      );
    });
  }

  void updateNotes(String notes) {
    if (state.selectedConversation == null) return;
    final updatedConv = state.selectedConversation!.copyWith(notes: notes);
    final updatedConvs = state.conversations.map((c) {
      return c.id == updatedConv.id ? updatedConv : c;
    }).toList();

    state = state.copyWith(
      conversations: updatedConvs,
      selectedConversation: updatedConv,
    );
  }

  void updateTag(String tag) {
    if (state.selectedConversation == null) return;
    final updatedConv = state.selectedConversation!.copyWith(tag: tag);
    final updatedConvs = state.conversations.map((c) {
      return c.id == updatedConv.id ? updatedConv : c;
    }).toList();

    state = state.copyWith(
      conversations: updatedConvs,
      selectedConversation: updatedConv,
    );
  }

  List<Conversation> _getMockConversations() {
    return [
      Conversation(
        id: '1',
        customerName: 'Nguyễn Hoàng Nam',
        customerPhone: '0909123456',
        customerAvatar: 'NH',
        lastMessage: 'Dịch vụ bên mình giá thế nào ạ?',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 12)),
        unreadCount: 2,
        tag: 'Khách hàng VIP',
        notes: 'Khách quan tâm gói phần mềm marketing chuyên sâu.',
        messages: [
          ChatMessage(
            id: '101',
            senderId: 'customer',
            senderName: 'Nguyễn Hoàng Nam',
            message: 'Xin chào, em muốn tìm hiểu dịch vụ CRM Zalo.',
            timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          ),
          ChatMessage(
            id: '102',
            senderId: 'me',
            senderName: 'Nguyễn Văn A',
            message:
                'Dạ chào anh Nam, phần mềm bên em hỗ trợ gửi tin hàng loạt, kết bạn và chatbot tự động ạ.',
            timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
          ),
          ChatMessage(
            id: '103',
            senderId: 'customer',
            senderName: 'Nguyễn Hoàng Nam',
            message: 'Dịch vụ bên mình giá thế nào ạ?',
            timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
          ),
        ],
      ),
      Conversation(
        id: '2',
        customerName: 'Trần Thị Thu Trang',
        customerPhone: '0988223344',
        customerAvatar: 'TT',
        lastMessage: 'Đã nhận được tài liệu tư vấn.',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
        unreadCount: 0,
        tag: 'Khách hàng tiềm năng',
        notes: 'Cần gửi báo giá chi tiết qua email.',
        messages: [
          ChatMessage(
            id: '201',
            senderId: 'customer',
            senderName: 'Trần Thị Thu Trang',
            message: 'Gửi cho mình tài liệu giới thiệu nhé.',
            timestamp: DateTime.now().subtract(const Duration(hours: 3)),
          ),
          ChatMessage(
            id: '202',
            senderId: 'me',
            senderName: 'Nguyễn Văn A',
            message: 'Dạ, em gửi chị Trang file PDF giới thiệu tính năng ạ.',
            timestamp: DateTime.now().subtract(
              const Duration(hours: 2, minutes: 30),
            ),
          ),
          ChatMessage(
            id: '203',
            senderId: 'customer',
            senderName: 'Trần Thị Thu Trang',
            message: 'Đã nhận được tài liệu tư vấn.',
            timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        ],
      ),
      Conversation(
        id: '3',
        customerName: 'Phạm Minh Đức',
        customerPhone: '0977556677',
        customerAvatar: 'PM',
        lastMessage: 'Cảm ơn em nhiều nhé.',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
        unreadCount: 0,
        tag: 'Đối tác',
        notes: 'Đối tác phát triển plugin API.',
        messages: [
          ChatMessage(
            id: '301',
            senderId: 'customer',
            senderName: 'Phạm Minh Đức',
            message: 'API đã tích hợp ổn định chưa em?',
            timestamp: DateTime.now().subtract(
              const Duration(days: 1, hours: 2),
            ),
          ),
          ChatMessage(
            id: '302',
            senderId: 'me',
            senderName: 'Nguyễn Văn A',
            message: 'Dạ chạy mượt rồi anh ơi, không bị checkpoint nữa ạ.',
            timestamp: DateTime.now().subtract(
              const Duration(days: 1, hours: 1),
            ),
          ),
          ChatMessage(
            id: '303',
            senderId: 'customer',
            senderName: 'Phạm Minh Đức',
            message: 'Cảm ơn em nhiều nhé.',
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ],
      ),
    ];
  }
}

final liveChatProvider = StateNotifierProvider<LiveChatNotifier, LiveChatState>(
  (ref) {
    return LiveChatNotifier();
  },
);
