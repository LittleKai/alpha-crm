/// Maps the shared cloud SSE stream (`CrmSseEvent`, cloud vocabulary:
/// `hello`/`message.new`/`message.status`/`conversation.updated`) onto the
/// Live Chat event vocabulary (`LiveChatEvent`, bridge vocabulary:
/// `bridge.connected`/`message.created`/`friend.updated`/`message.status`)
/// so [LiveChatNotifier]'s existing realtime handler works unmodified for
/// both transports. `device.status` and `pairing.completed` are NOT chat
/// events — they are consumed directly off the shared SSE stream by
/// `agent_status_provider.dart` and the pairing screen instead.
library;

import '../../../../shared/api/crm_sse_client.dart';
import 'live_chat_event.dart';

Stream<LiveChatEvent> mapCloudSseEvents(
  Stream<CrmSseEvent> source, {
  String? accountId,
}) {
  return source
      .map(_mapEvent)
      .where((event) => event != null)
      .map((event) => event!)
      .where((event) {
        if (accountId == null || accountId.isEmpty) return true;
        if (event.accountId.isEmpty) return true; // hello / message.status
        return event.accountId == accountId;
      });
}

LiveChatEvent? _mapEvent(CrmSseEvent event) {
  switch (event.name) {
    case 'hello':
      return LiveChatEvent(
        id: event.id,
        type: 'bridge.connected',
        accountId: '',
        threadId: '',
        timestamp: DateTime.now(),
        data: event.data,
      );
    case 'message.new':
      final rawMessage = event.data['message'];
      final message = rawMessage is Map
          ? Map<String, dynamic>.from(rawMessage)
          : <String, dynamic>{};
      return LiveChatEvent(
        id: event.id,
        type: 'message.created',
        accountId: (message['accountId'] ?? '').toString(),
        threadId: (message['threadId'] ?? '').toString(),
        timestamp: DateTime.now(),
        data: message,
      );
    case 'conversation.updated':
      return LiveChatEvent(
        id: event.id,
        type: 'friend.updated',
        accountId: (event.data['accountId'] ?? '').toString(),
        threadId: (event.data['threadId'] ?? '').toString(),
        timestamp: DateTime.now(),
        data: event.data,
      );
    case 'message.status':
      // Outbound status transition for OUR OWN message — not thread-scoped
      // the way inbound events are, so accountId/threadId stay empty and
      // LiveChatNotifier routes it to a dedicated handler by type.
      return LiveChatEvent(
        id: event.id,
        type: 'message.status',
        accountId: '',
        threadId: '',
        timestamp: DateTime.now(),
        data: event.data,
      );
    default:
      return null;
  }
}
