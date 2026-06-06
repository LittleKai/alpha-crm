import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_contracts.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_event.dart';
import 'package:alpha_crm/features/messaging/live_chat/providers/live_chat_provider.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Path builder tests
  // ---------------------------------------------------------------------------
  group('localMessagesPath', () {
    test('builds base path without query params', () {
      final path = localMessagesPath('conv123');
      expect(path, '/local/conversations/conv123/messages');
    });

    test('preserves before query parameter', () {
      final path = localMessagesPath('conv1', before: '2024-01-01T00:00:00Z');
      expect(path, contains('before='));
      expect(path, contains('2024-01-01T00%3A00%3A00Z'));
    });

    test('preserves after query parameter', () {
      final path = localMessagesPath('conv1', after: '2024-06-01T12:00:00Z');
      expect(path, contains('after='));
      expect(path, contains('2024-06-01T12%3A00%3A00Z'));
    });

    test('preserves limit query parameter', () {
      final path = localMessagesPath('conv1', limit: 50);
      expect(path, contains('limit=50'));
    });

    test('combines before, after, and limit', () {
      final path = localMessagesPath(
        'conv1',
        before: 'b',
        after: 'a',
        limit: 25,
      );
      expect(path, contains('before=b'));
      expect(path, contains('after=a'));
      expect(path, contains('limit=25'));
    });

    test('ignores empty before/after strings', () {
      final path = localMessagesPath('conv1', before: '', after: '');
      expect(path, '/local/conversations/conv1/messages');
    });
  });

  group('static path constants', () {
    test('localSendMessagePath', () {
      expect(localSendMessagePath, '/local/messages/send');
    });

    test('localSendAttachmentPath', () {
      expect(localSendAttachmentPath, '/local/messages/attachments/send');
    });

    test('localHealthPath', () {
      expect(localHealthPath, '/local/health');
    });
  });

  group('localRecallMessagePath', () {
    test('builds recall path with message id', () {
      expect(localRecallMessagePath('msg42'), '/local/messages/msg42/recall');
    });
  });

  group('LiveChatSseDecoder', () {
    test('parses named events and JSON data', () {
      final decoder = LiveChatSseDecoder();
      final events = <LiveChatEvent>[];
      events.addAll(decoder.addLine('id: event-1'));
      events.addAll(decoder.addLine('event: message.updated'));
      events.addAll(
        decoder.addLine(
          'data: {"accountId":"acc-1","threadId":"thread-1","data":{"messageId":"msg-1"}}',
        ),
      );
      events.addAll(decoder.addLine(''));

      expect(events, hasLength(1));
      expect(events.single.id, 'event-1');
      expect(events.single.type, 'message.updated');
      expect(events.single.data['messageId'], 'msg-1');
    });

    test('turns the connected SSE comment into bridge.connected', () {
      final decoder = LiveChatSseDecoder();
      final events = decoder.addLine(': connected');
      expect(events.single.type, 'bridge.connected');
    });
  });

  // ---------------------------------------------------------------------------
  // Response helper tests
  // ---------------------------------------------------------------------------
  group('isLocalResponseSuccess', () {
    test('returns true when success is true', () {
      expect(isLocalResponseSuccess({'success': true}), isTrue);
    });

    test('returns false when success is false', () {
      expect(isLocalResponseSuccess({'success': false}), isFalse);
    });

    test('returns false when success key is missing', () {
      expect(isLocalResponseSuccess(<String, dynamic>{}), isFalse);
    });
  });

  group('extractLocalDataList', () {
    test('extracts list of maps', () {
      final result = extractLocalDataList({
        'success': true,
        'data': [
          {'id': '1', 'text': 'hello'},
          {'id': '2', 'text': 'world'},
        ],
      });
      expect(result, hasLength(2));
      expect(result[0]['id'], '1');
    });

    test('returns empty list when data is not a list', () {
      expect(extractLocalDataList({'data': 'string'}), isEmpty);
    });

    test('returns empty list when data key is missing', () {
      expect(extractLocalDataList({'success': true}), isEmpty);
    });
  });

  group('isLocalBridgeFailure', () {
    test('detects bridgeOffline', () {
      expect(isLocalBridgeFailure({'reason': 'bridgeOffline'}), isTrue);
    });

    test('detects localOnlyUnavailable', () {
      expect(isLocalBridgeFailure({'reason': 'localOnlyUnavailable'}), isTrue);
    });

    test('returns false for unknown reason', () {
      expect(isLocalBridgeFailure({'reason': 'somethingElse'}), isFalse);
    });

    test('returns false when reason is absent', () {
      expect(isLocalBridgeFailure(<String, dynamic>{}), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // ChatMessage.fromJson compatibility tests (cloud + local shapes)
  // ---------------------------------------------------------------------------
  group('ChatMessage.fromJson local-first compatibility', () {
    test('parses messageType field', () {
      final msg = ChatMessage.fromJson({
        '_id': 'msg1',
        'senderId': 'u1',
        'senderName': 'User',
        'content': 'hello',
        'direction': 'inbound',
        'status': 'delivered',
        'sentAt': '2024-06-01T12:00:00Z',
        'messageType': 'image',
      });
      expect(msg.contentType, 'image');
    });

    test('parses attachments array', () {
      final attachments = [
        {'url': 'https://example.com/a.jpg', 'type': 'image'},
      ];
      final msg = ChatMessage.fromJson({
        'id': 'msg2',
        'senderId': 'u1',
        'senderName': 'User',
        'content': '',
        'direction': 'outbound',
        'status': 'sent',
        'sentAt': '2024-06-01T12:00:00Z',
        'attachments': attachments,
      });
      expect(msg.attachments, isNotNull);
      expect((msg.attachments as List).first['type'], 'image');
    });

    test('parses zaloMsgId', () {
      final msg = ChatMessage.fromJson({
        'id': 'msg3',
        'senderId': 'u1',
        'senderName': 'User',
        'text': 'hi',
        'direction': 'inbound',
        'status': 'delivered',
        'receivedAt': '2024-06-01T12:00:00Z',
        'zaloMsgId': 'zmsg_abc123',
      });
      expect(msg.zaloMsgId, 'zmsg_abc123');
    });

    test('parses isDeleted flag', () {
      final msg = ChatMessage.fromJson({
        'id': 'msg4',
        'senderId': 'u1',
        'senderName': 'User',
        'content': '[Tin nhắn đã thu hồi]',
        'direction': 'inbound',
        'status': 'delivered',
        'sentAt': '2024-06-01T12:00:00Z',
        'isDeleted': true,
      });
      expect(msg.isDeleted, isTrue);
    });

    test('falls back to "text" when messageType is absent', () {
      final msg = ChatMessage.fromJson({
        'id': 'msg5',
        'senderId': 'u1',
        'senderName': 'User',
        'content': 'plain text',
        'direction': 'inbound',
        'status': 'delivered',
        'sentAt': '2024-06-01T12:00:00Z',
      });
      expect(msg.contentType, 'text');
    });

    test('accepts local bridge shape with "text" key for message body', () {
      final msg = ChatMessage.fromJson({
        'id': 'local_1',
        'senderId': 'u1',
        'senderName': 'User',
        'text': 'from local bridge',
        'direction': 'inbound',
        'status': 'delivered',
        'receivedAt': '2024-06-01T13:00:00Z',
        'messageType': 'text',
        'zaloMsgId': 'zl_100',
      });
      expect(msg.message, 'from local bridge');
      expect(msg.zaloMsgId, 'zl_100');
    });

    test('parses client id, send error, quote and reactions', () {
      final msg = ChatMessage.fromJson({
        'id': 'local-rich',
        'content': 'hello',
        'direction': 'outbound',
        'status': 'failed',
        'clientMessageId': 'cli-1',
        'errorText': 'network error',
        'quoteJson': '{"messageId":"quoted-1","content":"old"}',
        'reactions': [
          {'userId': 'u1', 'reaction': 'heart'},
        ],
        'createdAt': '2026-06-06T10:00:00Z',
      });
      expect(msg.clientMessageId, 'cli-1');
      expect(msg.errorText, 'network error');
      expect(msg.quote?['messageId'], 'quoted-1');
      expect(msg.reactions.single['reaction'], 'heart');
    });
  });
}
