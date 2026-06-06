class ActiveDeviceSummary {
  final String? displayName;
  final DateTime? lastSeenAt;

  const ActiveDeviceSummary({this.displayName, this.lastSeenAt});
}

sealed class LocalAgentSyncResult {
  const LocalAgentSyncResult();
}

final class LocalAgentActive extends LocalAgentSyncResult {
  final String deviceId;

  const LocalAgentActive(this.deviceId);
}

final class LocalAgentConflict extends LocalAgentSyncResult {
  final ActiveDeviceSummary device;

  const LocalAgentConflict(this.device);
}

final class LocalAgentUnavailable extends LocalAgentSyncResult {
  final String message;

  const LocalAgentUnavailable(this.message);
}

sealed class LocalAgentSessionEvent {
  const LocalAgentSessionEvent();
}

final class LocalSessionRevoked extends LocalAgentSessionEvent {
  final String reason;

  const LocalSessionRevoked({required this.reason});

  @override
  bool operator ==(Object other) =>
      other is LocalSessionRevoked && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

sealed class CrmLoginResult {
  const CrmLoginResult();
}

final class CrmLoginSuccess extends CrmLoginResult {
  const CrmLoginSuccess();
}

final class CrmLoginDeviceConflict extends CrmLoginResult {
  final ActiveDeviceSummary device;

  const CrmLoginDeviceConflict(this.device);
}

final class CrmLoginFailure extends CrmLoginResult {
  final String message;

  const CrmLoginFailure(this.message);
}
