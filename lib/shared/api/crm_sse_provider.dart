import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'crm_sse_client.dart';

/// App-lifetime singleton. The underlying HTTP connection only opens once a
/// consumer subscribes to [CrmSseClient.events] (Live Chat, agent status,
/// pairing), so building this provider eagerly is cheap.
final crmSseClientProvider = Provider<CrmSseClient>((ref) {
  final client = CrmSseClient();
  final observer = _CrmSseLifecycleObserver(client);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(observer);
    client.dispose();
  });
  return client;
});

/// Pauses the SSE connection when the app is backgrounded (mobile) and
/// resumes it on foreground, per FE-2's lifecycle requirement.
class _CrmSseLifecycleObserver extends WidgetsBindingObserver {
  final CrmSseClient _client;

  _CrmSseLifecycleObserver(this._client);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _client.pause();
    } else if (state == AppLifecycleState.resumed) {
      _client.resume();
    }
  }
}
