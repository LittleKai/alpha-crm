import 'package:alpha_crm/features/messaging/live_chat/providers/live_chat_provider.dart';
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
}
