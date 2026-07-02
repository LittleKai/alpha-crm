import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_cloud_event_mapper.dart';
import 'package:alpha_crm/shared/api/crm_sse_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps message.new to message.created keyed by the message accountId', () async {
    final source = Stream<CrmSseEvent>.fromIterable([
      const CrmSseEvent(
        id: '1',
        name: 'message.new',
        data: {
          'message': {
            'accountId': 'acc-1',
            'threadId': 'thread-1',
            'content': 'hi',
          },
        },
      ),
    ]);

    final events = await mapCloudSseEvents(source, accountId: 'acc-1').toList();

    expect(events, hasLength(1));
    expect(events.single.type, 'message.created');
    expect(events.single.threadId, 'thread-1');
  });

  test('filters out events for a different account', () async {
    final source = Stream<CrmSseEvent>.fromIterable([
      const CrmSseEvent(
        id: '1',
        name: 'message.new',
        data: {
          'message': {'accountId': 'acc-2', 'threadId': 'thread-1'},
        },
      ),
    ]);

    final events = await mapCloudSseEvents(source, accountId: 'acc-1').toList();

    expect(events, isEmpty);
  });

  test('lets account-less events (hello, message.status) through regardless of filter', () async {
    final source = Stream<CrmSseEvent>.fromIterable([
      const CrmSseEvent(id: '1', name: 'hello', data: {'devices': []}),
      const CrmSseEvent(
        id: '2',
        name: 'message.status',
        data: {'messageId': 'm-1', 'status': 'sent'},
      ),
    ]);

    final events = await mapCloudSseEvents(source, accountId: 'acc-1').toList();

    expect(events.map((e) => e.type), ['bridge.connected', 'message.status']);
    expect(events.last.data['status'], 'sent');
  });

  test('maps conversation.updated to friend.updated', () async {
    final source = Stream<CrmSseEvent>.fromIterable([
      const CrmSseEvent(
        id: '1',
        name: 'conversation.updated',
        data: {'accountId': 'acc-1', 'threadId': 'thread-1'},
      ),
    ]);

    final events = await mapCloudSseEvents(source).toList();

    expect(events.single.type, 'friend.updated');
  });

  test('drops device.status and pairing.completed (not chat events)', () async {
    final source = Stream<CrmSseEvent>.fromIterable([
      const CrmSseEvent(id: '1', name: 'device.status', data: {}),
      const CrmSseEvent(id: '2', name: 'pairing.completed', data: {}),
    ]);

    final events = await mapCloudSseEvents(source).toList();

    expect(events, isEmpty);
  });
}
