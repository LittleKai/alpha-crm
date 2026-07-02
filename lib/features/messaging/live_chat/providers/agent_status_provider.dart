/// Tracks Desktop Agent + Zalo session health for the Offline Fallback UI
/// (FE-4). Only meaningful in [LiveChatTransportMode.cloudRemote] — on
/// Windows desktop (local bridge) the agent IS this process, so there is
/// nothing to watch and the notifier stays in its default "healthy" state.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/api/crm_sse_client.dart';
import '../../../../shared/api/crm_sse_provider.dart';
import '../data/live_chat_transport.dart';
import 'live_chat_provider.dart';

enum ZaloAccountHealth { unknown, online, expired, loggedOut }

class AgentDeviceStatus {
  final String deviceId;
  final String displayName;
  final bool online;
  final DateTime? lastHeartbeatAt;
  final ZaloAccountHealth worstZaloHealth;

  const AgentDeviceStatus({
    required this.deviceId,
    required this.displayName,
    required this.online,
    this.lastHeartbeatAt,
    this.worstZaloHealth = ZaloAccountHealth.unknown,
  });
}

class AgentStatusState {
  /// True once the SSE connection has delivered at least one snapshot
  /// (`hello`) or update. Before that we don't know enough to show a banner.
  final bool hasSnapshot;
  final bool sseConnected;
  final Map<String, AgentDeviceStatus> devicesById;

  const AgentStatusState({
    this.hasSnapshot = false,
    this.sseConnected = false,
    this.devicesById = const {},
  });

  bool get anyDeviceOnline => devicesById.values.any((d) => d.online);

  bool get anyOnlineDeviceHasZaloIssue => devicesById.values.any(
    (d) =>
        d.online &&
        (d.worstZaloHealth == ZaloAccountHealth.expired ||
            d.worstZaloHealth == ZaloAccountHealth.loggedOut),
  );

  AgentStatusState copyWith({
    bool? hasSnapshot,
    bool? sseConnected,
    Map<String, AgentDeviceStatus>? devicesById,
  }) {
    return AgentStatusState(
      hasSnapshot: hasSnapshot ?? this.hasSnapshot,
      sseConnected: sseConnected ?? this.sseConnected,
      devicesById: devicesById ?? this.devicesById,
    );
  }
}

final agentStatusProvider =
    StateNotifierProvider<AgentStatusNotifier, AgentStatusState>((ref) {
      final mode = ref.watch(liveChatTransportModeProvider);
      if (mode != LiveChatTransportMode.cloudRemote) {
        return AgentStatusNotifier(null);
      }
      return AgentStatusNotifier(ref.watch(crmSseClientProvider));
    });

class AgentStatusNotifier extends StateNotifier<AgentStatusState> {
  final CrmSseClient? _client;
  StreamSubscription<CrmSseEvent>? _subscription;

  AgentStatusNotifier(this._client) : super(const AgentStatusState()) {
    final client = _client;
    if (client == null) return;
    client.connectionState.addListener(_onConnectionStateChanged);
    _onConnectionStateChanged();
    _subscription = client.events.listen(_onEvent);
  }

  void _onConnectionStateChanged() {
    final client = _client;
    if (client == null) return;
    state = state.copyWith(
      sseConnected: client.connectionState.value == SseConnectionState.connected,
    );
  }

  void _onEvent(CrmSseEvent event) {
    switch (event.name) {
      case 'hello':
        final raw = event.data['devices'];
        if (raw is! List) return;
        final devices = <String, AgentDeviceStatus>{
          for (final item in raw)
            if (item is Map) ..._deviceEntry(Map<String, dynamic>.from(item)),
        };
        state = state.copyWith(hasSnapshot: true, devicesById: devices);
        break;
      case 'device.status':
        final entry = _deviceEntry(event.data, idKey: 'deviceId');
        if (entry.isEmpty) return;
        state = state.copyWith(
          hasSnapshot: true,
          devicesById: {...state.devicesById, ...entry},
        );
        break;
    }
  }

  Map<String, AgentDeviceStatus> _deviceEntry(
    Map<String, dynamic> json, {
    String idKey = '_id',
  }) {
    final id = (json[idKey] ?? json['_id'] ?? json['deviceId'] ?? '')
        .toString();
    if (id.isEmpty) return const {};
    final zaloAccounts = json['zaloAccounts'];
    var worstHealth = ZaloAccountHealth.unknown;
    if (zaloAccounts is List) {
      for (final account in zaloAccounts) {
        if (account is! Map) continue;
        final status = (account['status'] ?? '').toString();
        final health = switch (status) {
          'online' => ZaloAccountHealth.online,
          'expired' => ZaloAccountHealth.expired,
          'logged_out' => ZaloAccountHealth.loggedOut,
          _ => ZaloAccountHealth.unknown,
        };
        if (health == ZaloAccountHealth.expired ||
            health == ZaloAccountHealth.loggedOut) {
          worstHealth = health;
          break;
        }
        if (health == ZaloAccountHealth.online &&
            worstHealth == ZaloAccountHealth.unknown) {
          worstHealth = health;
        }
      }
    }
    final lastHeartbeat = DateTime.tryParse(
      (json['lastHeartbeatAt'] ?? json['lastSeenAt'] ?? '').toString(),
    );
    return {
      id: AgentDeviceStatus(
        deviceId: id,
        displayName: (json['displayName'] ?? '').toString(),
        online: (json['agentStatus'] ?? '').toString() == 'online',
        lastHeartbeatAt: lastHeartbeat,
        worstZaloHealth: worstHealth,
      ),
    };
  }

  @override
  void dispose() {
    _client?.connectionState.removeListener(_onConnectionStateChanged);
    _subscription?.cancel();
    super.dispose();
  }
}
