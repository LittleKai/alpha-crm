import 'package:flutter_test/flutter_test.dart';

import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_cache.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_local_bridge_api.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_repository.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_transport.dart';

void main() {
  test(
    'watchEvents opens local SSE on desktop even when localFirstEnabled is false',
    () async {
      final repository = LiveChatRepository(
        localFirstEnabled: false,
        mode: LiveChatTransportMode.localBridge,
        localApi: LiveChatLocalBridgeApi(baseUrl: 'http://127.0.0.1:1'),
        cache: LiveChatCache(),
      );

      // Before the fix this returned Stream.empty() => immediate clean `done`.
      // After the fix it must ATTEMPT the local SSE connection, which fails
      // against the unreachable port 1 with a connection error.
      await expectLater(repository.watchEvents(), emitsError(anything));
    },
  );
}
