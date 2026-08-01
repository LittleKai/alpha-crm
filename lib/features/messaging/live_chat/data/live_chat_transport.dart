/// Determines whether Live Chat talks to the local Zalo bridge (Windows
/// desktop, supervised by `ZaloBackendManager`) or the cloud backend directly
/// (Android, iOS — platforms with no bridge process).
library;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

enum LiveChatTransportMode { localBridge, cloudRemote }

/// Resolves the transport mode for this run.
///
/// Windows desktop uses [LiveChatTransportMode.localBridge]; every other
/// platform (Android, iOS) uses [LiveChatTransportMode.cloudRemote].
/// Uses the same `defaultTargetPlatform` client-platform check already
/// established by `zalo_integration_provider.dart` and
/// `device_pairing_screen.dart` — no dart:io platform probing needed. Can be
/// forced via `--dart-define=LIVE_CHAT_TRANSPORT_MODE=local|remote` for
/// testing.
LiveChatTransportMode resolveLiveChatTransportMode() {
  const override = String.fromEnvironment('LIVE_CHAT_TRANSPORT_MODE');
  if (override == 'local') return LiveChatTransportMode.localBridge;
  if (override == 'remote') return LiveChatTransportMode.cloudRemote;
  final isClientPlatform =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  return isClientPlatform
      ? LiveChatTransportMode.cloudRemote
      : LiveChatTransportMode.localBridge;
}
