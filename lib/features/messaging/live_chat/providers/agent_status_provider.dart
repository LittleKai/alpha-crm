/// Tracks Desktop Agent + Zalo session health for the Offline Fallback UI
/// (FE-4). Only meaningful in [LiveChatTransportMode.cloudRemote] — on
/// Windows desktop (local bridge) the agent IS this process, so there is
/// nothing to watch and the notifier stays in its default "healthy" state.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/api/crm_sse_client.dart';
import '../../../../shared/api/crm_sse_provider.dart';
import '../data/live_chat_transport.dart';
import '../utils/mobile_connection_diagnostics.dart';
import 'live_chat_provider.dart';

enum ZaloAccountHealth { unknown, online, expired, loggedOut }

class AgentDeviceStatus {
  final String deviceId;
  final String displayName;
  final bool online;
  final DateTime? lastHeartbeatAt;
  final ZaloAccountHealth worstZaloHealth;
  final String? appVersion;
  final String? agentVersion;

  const AgentDeviceStatus({
    required this.deviceId,
    required this.displayName,
    required this.online,
    this.lastHeartbeatAt,
    this.worstZaloHealth = ZaloAccountHealth.unknown,
    this.appVersion,
    this.agentVersion,
  });
}

class AgentStatusState {
  /// True once the SSE connection has delivered at least one snapshot
  /// (`hello`) or update. Before that we don't know enough to show a banner.
  final bool hasSnapshot;
  final bool sseConnected;
  final bool showReconnectBanner;
  final Map<String, AgentDeviceStatus> devicesById;

  const AgentStatusState({
    this.hasSnapshot = false,
    this.sseConnected = false,
    this.showReconnectBanner = false,
    this.devicesById = const {},
  });

  bool get anyDeviceOnline => devicesById.values.any((d) => d.online);

  bool get anyOnlineDeviceHasZaloIssue => devicesById.values.any(
    (d) =>
        d.online &&
        (d.worstZaloHealth == ZaloAccountHealth.expired ||
            d.worstZaloHealth == ZaloAccountHealth.loggedOut),
  );

  DateTime? get latestHeartbeatAt {
    DateTime? latest;
    for (final d in devicesById.values) {
      final hb = d.lastHeartbeatAt;
      if (hb != null && (latest == null || hb.isAfter(latest))) {
        latest = hb;
      }
    }
    return latest;
  }

  String? get primaryDesktopAppVersion {
    for (final d in devicesById.values) {
      if (d.online && d.appVersion != null && d.appVersion!.isNotEmpty) {
        return d.appVersion;
      }
    }
    for (final d in devicesById.values) {
      if (d.appVersion != null && d.appVersion!.isNotEmpty) {
        return d.appVersion;
      }
    }
    return null;
  }

  String? get primaryDesktopAgentVersion {
    for (final d in devicesById.values) {
      if (d.online && d.agentVersion != null && d.agentVersion!.isNotEmpty) {
        return d.agentVersion;
      }
    }
    for (final d in devicesById.values) {
      if (d.agentVersion != null && d.agentVersion!.isNotEmpty) {
        return d.agentVersion;
      }
    }
    return null;
  }

  AgentStatusState copyWith({
    bool? hasSnapshot,
    bool? sseConnected,
    bool? showReconnectBanner,
    Map<String, AgentDeviceStatus>? devicesById,
  }) {
    return AgentStatusState(
      hasSnapshot: hasSnapshot ?? this.hasSnapshot,
      sseConnected: sseConnected ?? this.sseConnected,
      showReconnectBanner: showReconnectBanner ?? this.showReconnectBanner,
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
  final DateTime Function() _clock;
  StreamSubscription<CrmSseEvent>? _subscription;
  CalmStatusReveal _calm = CalmStatusReveal.idle;
  Timer? _calmTimer;

  AgentStatusNotifier(
    this._client, {
    DateTime Function()? clock,
    @visibleForTesting AgentStatusState? initialState,
  }) : _clock = clock ?? _client?.clock ?? DateTime.now,
       super(initialState ?? const AgentStatusState()) {
    final client = _client;
    if (client == null) return;
    client.connectionState.addListener(_onConnectionStateChanged);
    client.pausedState.addListener(_onConnectionStateChanged);
    _subscription = client.events.listen(_onEvent);
    _onConnectionStateChanged();
  }

  void _onConnectionStateChanged() {
    if (!mounted) return;
    final client = _client;
    if (client == null) return;
    if (client.isPaused) {
      _calmTimer?.cancel();
      _calmTimer = null;
      _calm = CalmStatusReveal.idle;
      state = state.copyWith(
        sseConnected: false,
        showReconnectBanner: false,
      );
      return;
    }
    _applyCalmStep();
  }

  void _applyCalmStep() {
    if (!mounted) return;
    final client = _client;
    if (client == null) return;
    if (client.isPaused) {
      _calmTimer?.cancel();
      _calmTimer = null;
      _calm = CalmStatusReveal.idle;
      state = state.copyWith(
        sseConnected: false,
        showReconnectBanner: false,
      );
      return;
    }

    final isConnected =
        client.connectionState.value == SseConnectionState.connected;
    final status = client.lastHttpStatus;
    final immediate = status == 401 || status == 402 || status == 403;
    final nowMs = _clock().millisecondsSinceEpoch;

    final step = stepCalmStatusReveal(
      _calm,
      down: !isConnected,
      immediate: immediate,
      nowMs: nowMs,
    );
    _calm = step.next;
    state = state.copyWith(
      sseConnected: isConnected,
      showReconnectBanner: step.visible,
    );

    _calmTimer?.cancel();
    _calmTimer = null;
    final recheckIn = step.recheckIn;
    if (recheckIn != null) {
      _calmTimer = Timer(recheckIn, () {
        if (mounted) _applyCalmStep();
      });
    }
  }

  void _onEvent(CrmSseEvent event) {
    if (!mounted) return;
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

  static String? _nonEmptyString(Object? value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
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
    final existing = state.devicesById[id];
    final displayName = _nonEmptyString(json['displayName']) ??
        existing?.displayName ??
        '';
    return {
      id: AgentDeviceStatus(
        deviceId: id,
        displayName: displayName,
        online: (json['agentStatus'] ?? '').toString() == 'online',
        lastHeartbeatAt: lastHeartbeat ?? existing?.lastHeartbeatAt,
        worstZaloHealth: worstHealth,
        appVersion: _nonEmptyString(json['appVersion']) ?? existing?.appVersion,
        agentVersion:
            _nonEmptyString(json['agentVersion']) ?? existing?.agentVersion,
      ),
    };
  }

  @override
  void dispose() {
    _calmTimer?.cancel();
    _calmTimer = null;
    _client?.connectionState.removeListener(_onConnectionStateChanged);
    _client?.pausedState.removeListener(_onConnectionStateChanged);
    _subscription?.cancel();
    super.dispose();
  }
}
