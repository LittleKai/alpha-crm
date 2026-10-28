import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../../shared/api/crm_sse_client.dart';
import '../data/live_chat_transport.dart';

const int calmStatusRevealDelayMs = 5000;
const int calmStatusMinVisibleMs = 2000;
const int calmStatusHealthyHoldMs = 1000;

/// Pure state container ported from Orca's `CalmStatusReveal`
/// (`src/shared/calm-status-reveal.ts`). Suppresses sub-5s transient SSE
/// reconnect blips while enforcing a 2s minimum visible window and 1s healthy
/// hold once a banner is revealed.
@immutable
class CalmStatusReveal {
  final int? downSince;
  final int? shownAt;
  final int? healthySince;

  const CalmStatusReveal({
    this.downSince,
    this.shownAt,
    this.healthySince,
  });

  static const CalmStatusReveal idle = CalmStatusReveal();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalmStatusReveal &&
        other.downSince == downSince &&
        other.shownAt == shownAt &&
        other.healthySince == healthySince;
  }

  @override
  int get hashCode => Object.hash(downSince, shownAt, healthySince);
}

@immutable
class CalmStatusStep {
  final CalmStatusReveal next;
  final bool visible;
  final Duration? recheckIn;

  const CalmStatusStep({
    required this.next,
    required this.visible,
    required this.recheckIn,
  });
}

CalmStatusStep stepCalmStatusReveal(
  CalmStatusReveal prev, {
  required bool down,
  required bool immediate,
  required int nowMs,
}) {
  if (down) {
    final downSince = prev.downSince ?? nowMs;
    if (prev.shownAt != null) {
      return CalmStatusStep(
        next: CalmStatusReveal(
          downSince: downSince,
          shownAt: prev.shownAt,
          healthySince: null,
        ),
        visible: true,
        recheckIn: null,
      );
    }
    if (immediate) {
      return CalmStatusStep(
        next: CalmStatusReveal(
          downSince: downSince,
          shownAt: nowMs,
          healthySince: null,
        ),
        visible: true,
        recheckIn: null,
      );
    }
    final elapsed = nowMs - downSince;
    if (elapsed >= calmStatusRevealDelayMs) {
      return CalmStatusStep(
        next: CalmStatusReveal(
          downSince: downSince,
          shownAt: nowMs,
          healthySince: null,
        ),
        visible: true,
        recheckIn: null,
      );
    }
    return CalmStatusStep(
      next: CalmStatusReveal(
        downSince: downSince,
        shownAt: null,
        healthySince: null,
      ),
      visible: false,
      recheckIn: Duration(milliseconds: calmStatusRevealDelayMs - elapsed),
    );
  }

  if (prev.shownAt == null) {
    return const CalmStatusStep(
      next: CalmStatusReveal.idle,
      visible: false,
      recheckIn: null,
    );
  }

  final healthySince = prev.healthySince ?? nowMs;
  final clearAt = math.max(
    prev.shownAt! + calmStatusMinVisibleMs,
    healthySince + calmStatusHealthyHoldMs,
  );
  if (nowMs >= clearAt) {
    return const CalmStatusStep(
      next: CalmStatusReveal.idle,
      visible: false,
      recheckIn: null,
    );
  }

  return CalmStatusStep(
    next: CalmStatusReveal(
      downSince: prev.downSince,
      shownAt: prev.shownAt,
      healthySince: healthySince,
    ),
    visible: true,
    recheckIn: Duration(milliseconds: clearAt - nowMs),
  );
}

enum MobileConnectionIssueSeverity { healthy, info, warning, error }

enum AgentVersionCompatStatus {
  compatible,
  desktopOutdated,
  mobileOutdated,
  unknown,
}

@immutable
class AgentVersionCompatResult {
  final AgentVersionCompatStatus status;
  final String? mobileVersion;
  final String? desktopVersion;

  const AgentVersionCompatResult({
    required this.status,
    this.mobileVersion,
    this.desktopVersion,
  });
}

List<int>? _parseSemverTriplet(String? raw) {
  if (raw == null) return null;
  var cleaned = raw.trim();
  if (cleaned.isEmpty) return null;
  if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
    cleaned = cleaned.substring(1).trim();
  }
  cleaned = cleaned.split('+').first.split('-').first.trim();
  final parts = cleaned.split('.');
  if (parts.length < 2) return null;
  final major = int.tryParse(parts[0]);
  final minor = int.tryParse(parts[1]);
  final patch = parts.length >= 3 ? int.tryParse(parts[2]) : 0;
  if (major == null || minor == null || patch == null) return null;
  if (major == 0 && minor == 0 && patch == 0) return null;
  return [major, minor, patch];
}

AgentVersionCompatResult evaluateAgentVersionCompat({
  required String? mobileAppVersion,
  required String? desktopAppVersion,
}) {
  final mobileParts = _parseSemverTriplet(mobileAppVersion);
  final desktopParts = _parseSemverTriplet(desktopAppVersion);
  if (mobileParts == null || desktopParts == null) {
    return AgentVersionCompatResult(
      status: AgentVersionCompatStatus.unknown,
      mobileVersion: mobileAppVersion?.trim(),
      desktopVersion: desktopAppVersion?.trim(),
    );
  }
  final normalizedMobile =
      '${mobileParts[0]}.${mobileParts[1]}.${mobileParts[2]}';
  final normalizedDesktop =
      '${desktopParts[0]}.${desktopParts[1]}.${desktopParts[2]}';

  for (var i = 0; i < 3; i++) {
    if (desktopParts[i] < mobileParts[i]) {
      return AgentVersionCompatResult(
        status: AgentVersionCompatStatus.desktopOutdated,
        mobileVersion: normalizedMobile,
        desktopVersion: normalizedDesktop,
      );
    }
    if (desktopParts[i] > mobileParts[i]) {
      return AgentVersionCompatResult(
        status: AgentVersionCompatStatus.mobileOutdated,
        mobileVersion: normalizedMobile,
        desktopVersion: normalizedDesktop,
      );
    }
  }
  return AgentVersionCompatResult(
    status: AgentVersionCompatStatus.compatible,
    mobileVersion: normalizedMobile,
    desktopVersion: normalizedDesktop,
  );
}

@immutable
class MobileConnectionCheckItem {
  final String label;
  final String statusText;
  final MobileConnectionIssueSeverity severity;

  const MobileConnectionCheckItem({
    required this.label,
    required this.statusText,
    required this.severity,
  });
}

@immutable
class MobileConnectionSnapshot {
  final LiveChatTransportMode transportMode;
  final bool isPaired;
  final SseConnectionState sseState;
  final bool showReconnectBanner;
  final int reconnectAttempts;
  final int? lastHttpStatus;
  final String? lastError;
  final bool hasAgentSnapshot;
  final bool anyDeviceOnline;
  final bool anyOnlineDeviceHasZaloIssue;
  final DateTime? lastHeartbeatAt;
  final String? mobileAppVersion;
  final String? desktopAppVersion;
  final String? desktopAgentVersion;

  const MobileConnectionSnapshot({
    required this.transportMode,
    required this.isPaired,
    required this.sseState,
    required this.showReconnectBanner,
    this.reconnectAttempts = 0,
    this.lastHttpStatus,
    this.lastError,
    required this.hasAgentSnapshot,
    required this.anyDeviceOnline,
    required this.anyOnlineDeviceHasZaloIssue,
    this.lastHeartbeatAt,
    this.mobileAppVersion,
    this.desktopAppVersion,
    this.desktopAgentVersion,
  });
}

@immutable
class MobileConnectionDiagnosis {
  final MobileConnectionIssueSeverity severity;
  final String title;
  final String likelyCause;
  final String nextStep;
  final List<MobileConnectionCheckItem> checks;

  const MobileConnectionDiagnosis({
    required this.severity,
    required this.title,
    required this.likelyCause,
    required this.nextStep,
    required this.checks,
  });
}

List<MobileConnectionCheckItem> _buildChecklist(MobileConnectionSnapshot s) {
  final pairingCheck = s.isPaired
      ? const MobileConnectionCheckItem(
          label: 'Ghép đôi máy tính',
          statusText: 'Đã ghép đôi với máy tính chủ',
          severity: MobileConnectionIssueSeverity.healthy,
        )
      : const MobileConnectionCheckItem(
          label: 'Ghép đôi máy tính',
          statusText: 'Chưa ghép đôi',
          severity: MobileConnectionIssueSeverity.warning,
        );

  final MobileConnectionCheckItem sseCheck;
  if (s.lastHttpStatus == 401 ||
      s.lastHttpStatus == 402 ||
      s.lastHttpStatus == 403) {
    sseCheck = MobileConnectionCheckItem(
      label: 'Kết nối máy chủ (SSE)',
      statusText: 'Lỗi xác thực / gói cước (HTTP ${s.lastHttpStatus})',
      severity: MobileConnectionIssueSeverity.error,
    );
  } else if (s.sseState == SseConnectionState.connected) {
    sseCheck = const MobileConnectionCheckItem(
      label: 'Kết nối máy chủ (SSE)',
      statusText: 'Đang kết nối thời gian thực',
      severity: MobileConnectionIssueSeverity.healthy,
    );
  } else if (s.showReconnectBanner) {
    sseCheck = MobileConnectionCheckItem(
      label: 'Kết nối máy chủ (SSE)',
      statusText: 'Mất kết nối (thử lại lần ${s.reconnectAttempts})',
      severity: MobileConnectionIssueSeverity.warning,
    );
  } else {
    sseCheck = const MobileConnectionCheckItem(
      label: 'Kết nối máy chủ (SSE)',
      statusText: 'Đang đồng bộ kênh thời gian thực...',
      severity: MobileConnectionIssueSeverity.info,
    );
  }

  final MobileConnectionCheckItem agentCheck;
  if (!s.isPaired) {
    agentCheck = const MobileConnectionCheckItem(
      label: 'Desktop Agent trên PC',
      statusText: 'Chờ ghép đôi máy tính',
      severity: MobileConnectionIssueSeverity.info,
    );
  } else if (!s.hasAgentSnapshot) {
    agentCheck = const MobileConnectionCheckItem(
      label: 'Desktop Agent trên PC',
      statusText: 'Đang kiểm tra nhịp tim từ máy tính...',
      severity: MobileConnectionIssueSeverity.info,
    );
  } else if (!s.anyDeviceOnline) {
    final lastStr = s.lastHeartbeatAt != null
        ? ' (lần cuối ${DateFormat('HH:mm dd/MM').format(s.lastHeartbeatAt!.toLocal())})'
        : '';
    agentCheck = MobileConnectionCheckItem(
      label: 'Desktop Agent trên PC',
      statusText: 'Máy tính đang ngoại tuyến$lastStr',
      severity: MobileConnectionIssueSeverity.warning,
    );
  } else {
    final compat = evaluateAgentVersionCompat(
      mobileAppVersion: s.mobileAppVersion,
      desktopAppVersion: s.desktopAppVersion,
    );
    final shownVersion =
        (s.desktopAppVersion != null && s.desktopAppVersion!.isNotEmpty)
        ? s.desktopAppVersion
        : s.desktopAgentVersion;
    final verSuffix = shownVersion != null && shownVersion.isNotEmpty
        ? ' (v$shownVersion)'
        : '';
    if (compat.status == AgentVersionCompatStatus.desktopOutdated) {
      agentCheck = MobileConnectionCheckItem(
        label: 'Desktop Agent trên PC',
        statusText:
            'Máy tính đang trực tuyến nhưng phiên bản cũ (PC v${compat.desktopVersion} < Mobile v${compat.mobileVersion})',
        severity: MobileConnectionIssueSeverity.warning,
      );
    } else if (compat.status == AgentVersionCompatStatus.mobileOutdated) {
      agentCheck = MobileConnectionCheckItem(
        label: 'Desktop Agent trên PC',
        statusText:
            'Máy tính đang trực tuyến nhưng ứng dụng điện thoại cũ (Mobile v${compat.mobileVersion} < PC v${compat.desktopVersion})',
        severity: MobileConnectionIssueSeverity.warning,
      );
    } else {
      agentCheck = MobileConnectionCheckItem(
        label: 'Desktop Agent trên PC',
        statusText: 'Máy tính đang trực tuyến$verSuffix',
        severity: MobileConnectionIssueSeverity.healthy,
      );
    }
  }

  final MobileConnectionCheckItem zaloCheck;
  if (!s.isPaired || !s.hasAgentSnapshot || !s.anyDeviceOnline) {
    zaloCheck = const MobileConnectionCheckItem(
      label: 'Phiên Zalo trên PC',
      statusText: 'Chưa xác định (chờ máy tính trực tuyến)',
      severity: MobileConnectionIssueSeverity.info,
    );
  } else if (s.anyOnlineDeviceHasZaloIssue) {
    zaloCheck = const MobileConnectionCheckItem(
      label: 'Phiên Zalo trên PC',
      statusText: 'Phiên Zalo đã hết hạn hoặc mất kết nối',
      severity: MobileConnectionIssueSeverity.warning,
    );
  } else {
    zaloCheck = const MobileConnectionCheckItem(
      label: 'Phiên Zalo trên PC',
      statusText: 'Tài khoản Zalo hoạt động bình thường',
      severity: MobileConnectionIssueSeverity.healthy,
    );
  }

  return [pairingCheck, sseCheck, agentCheck, zaloCheck];
}

MobileConnectionDiagnosis diagnoseMobileConnection(
  MobileConnectionSnapshot snapshot,
) {
  final checks = _buildChecklist(snapshot);

  // 1. Not cloudRemote
  if (snapshot.transportMode != LiveChatTransportMode.cloudRemote) {
    return MobileConnectionDiagnosis(
      severity: MobileConnectionIssueSeverity.info,
      title: 'Chỉ áp dụng cho điện thoại',
      likelyCause:
          'Thiết bị đang chạy ở chế độ Local Bridge trực tiếp trên máy tính Windows.',
      nextStep:
          'Không cần sử dụng chẩn đoán kết nối từ xa trên máy tính chủ.',
      checks: checks,
    );
  }

  // 2. Not paired
  if (!snapshot.isPaired) {
    return MobileConnectionDiagnosis(
      severity: MobileConnectionIssueSeverity.warning,
      title: 'Chưa ghép đôi với máy tính chủ',
      likelyCause:
          'Điện thoại chưa được liên kết với ứng dụng Alpha CRM trên máy tính Windows.',
      nextStep:
          'Mở mục Ghép đôi thiết bị trên máy tính và quét mã QR hoặc nhập mã ghép đôi gồm 6 chữ số.',
      checks: checks,
    );
  }

  // 3. HTTP 401 or 402/403
  if (snapshot.lastHttpStatus == 401) {
    return MobileConnectionDiagnosis(
      severity: MobileConnectionIssueSeverity.error,
      title: 'Phiên đăng nhập đã hết hạn (HTTP 401)',
      likelyCause:
          'Token xác thực trên điện thoại không còn hợp lệ hoặc đã bị thu hồi.',
      nextStep:
          'Vui lòng đăng xuất và đăng nhập lại tài khoản Alpha CRM trên điện thoại.',
      checks: checks,
    );
  }
  if (snapshot.lastHttpStatus == 402 || snapshot.lastHttpStatus == 403) {
    return MobileConnectionDiagnosis(
      severity: MobileConnectionIssueSeverity.error,
      title: 'Gói cước hoặc quyền truy cập bị từ chối (HTTP ${snapshot.lastHttpStatus})',
      likelyCause:
          'Gói dịch vụ Alpha CRM đã hết hạn hoặc tài khoản chưa được cấp quyền đồng bộ đám mây.',
      nextStep:
          'Vui lòng kiểm tra trạng thái gói cước trong mục Gói dịch vụ hoặc liên hệ quản trị viên.',
      checks: checks,
    );
  }

  // 4. SSE down and banner revealed
  if (snapshot.sseState != SseConnectionState.connected &&
      snapshot.showReconnectBanner) {
    return MobileConnectionDiagnosis(
      severity: MobileConnectionIssueSeverity.warning,
      title: 'Mất kết nối tới máy chủ đám mây',
      likelyCause:
          'Kênh sự kiện thời gian thực (SSE) đang bị gián đoạn (đã thử lại ${snapshot.reconnectAttempts} lần).',
      nextStep:
          'Kiểm tra kết nối Wi-Fi/4G trên điện thoại hoặc nhấn "Kết nối lại ngay" bên dưới.',
      checks: checks,
    );
  }

  // 5. No snapshot yet
  if (!snapshot.hasAgentSnapshot) {
    return MobileConnectionDiagnosis(
      severity: MobileConnectionIssueSeverity.info,
      title: 'Đang kiểm tra trạng thái máy tính chủ',
      likelyCause:
          'Điện thoại vừa mở kết nối và đang chờ bản tin trạng thái đầu tiên từ máy chủ.',
      nextStep:
          'Đợi vài giây hoặc nhấn "Kết nối lại ngay" nếu trạng thái không cập nhật.',
      checks: checks,
    );
  }

  // 6. Desktop Agent offline
  if (!snapshot.anyDeviceOnline) {
    final lastSeen = snapshot.lastHeartbeatAt != null
        ? ' Nhịp tim cuối cùng lúc ${DateFormat('HH:mm dd/MM/yyyy').format(snapshot.lastHeartbeatAt!.toLocal())}.'
        : '';
    return MobileConnectionDiagnosis(
      severity: MobileConnectionIssueSeverity.warning,
      title: 'Máy tính chủ đang ngoại tuyến',
      likelyCause:
          'Không nhận được tín hiệu từ Desktop Agent trên máy tính Windows.$lastSeen',
      nextStep:
          'Mở ứng dụng Alpha CRM trên máy tính chủ, đảm bảo máy tính có mạng Internet và không bị tắt nguồn/ngủ đông.',
      checks: checks,
    );
  }

  // 7. Zalo session expired / logged out
  if (snapshot.anyOnlineDeviceHasZaloIssue) {
    return MobileConnectionDiagnosis(
      severity: MobileConnectionIssueSeverity.warning,
      title: 'Phiên Zalo trên máy tính đã hết hạn',
      likelyCause:
          'Máy tính chủ đang trực tuyến nhưng tài khoản Zalo trên máy tính đã bị đăng xuất hoặc hết hạn phiên.',
      nextStep:
          'Mở Alpha CRM trên máy tính Windows và quét lại mã QR Zalo để khôi phục gửi/nhận tin nhắn.',
      checks: checks,
    );
  }

  // 8. App version compatibility between Mobile and Desktop Host
  final compat = evaluateAgentVersionCompat(
    mobileAppVersion: snapshot.mobileAppVersion,
    desktopAppVersion: snapshot.desktopAppVersion,
  );
  if (compat.status == AgentVersionCompatStatus.desktopOutdated) {
    return MobileConnectionDiagnosis(
      severity: MobileConnectionIssueSeverity.warning,
      title: 'Phiên bản Alpha CRM trên máy tính đã cũ',
      likelyCause:
          'Ứng dụng trên máy tính chủ (v${compat.desktopVersion}) cũ hơn phiên bản trên điện thoại (v${compat.mobileVersion}).',
      nextStep:
          'Mở Alpha CRM trên máy tính Windows và cập nhật lên phiên bản mới nhất để đồng bộ ổn định.',
      checks: checks,
    );
  }
  if (compat.status == AgentVersionCompatStatus.mobileOutdated) {
    return MobileConnectionDiagnosis(
      severity: MobileConnectionIssueSeverity.warning,
      title: 'Phiên bản Alpha CRM trên điện thoại đã cũ',
      likelyCause:
          'Ứng dụng trên điện thoại (v${compat.mobileVersion}) cũ hơn phiên bản trên máy tính chủ (v${compat.desktopVersion}).',
      nextStep:
          'Cập nhật ứng dụng Alpha CRM trên điện thoại lên phiên bản mới nhất.',
      checks: checks,
    );
  }

  // 9. Healthy
  return MobileConnectionDiagnosis(
    severity: MobileConnectionIssueSeverity.healthy,
    title: 'Kết nối hoạt động ổn định',
    likelyCause:
        'Điện thoại, máy chủ đám mây, máy tính chủ và phiên Zalo đều đang trực tuyến.',
    nextStep: 'Bạn có thể gửi và nhận tin nhắn bình thường.',
    checks: checks,
  );
}

String buildRedactedDiagnosticsReport(
  MobileConnectionSnapshot snapshot,
  List<CrmConnectionLogEntry> logs, {
  String? mobileAppVersion,
}) {
  final diagnosis = diagnoseMobileConnection(snapshot);
  final buffer = StringBuffer();
  buffer.writeln('=== ALPHA CRM MOBILE CONNECTION DIAGNOSTICS ===');
  final effectiveMobileVersion =
      (mobileAppVersion != null && mobileAppVersion.isNotEmpty)
      ? mobileAppVersion
      : snapshot.mobileAppVersion;
  if (effectiveMobileVersion != null && effectiveMobileVersion.isNotEmpty) {
    buffer.writeln('Mobile App Version: $effectiveMobileVersion');
  }
  if (snapshot.desktopAppVersion != null &&
      snapshot.desktopAppVersion!.isNotEmpty) {
    buffer.writeln('Desktop App Version: ${snapshot.desktopAppVersion}');
  }
  if (snapshot.desktopAgentVersion != null &&
      snapshot.desktopAgentVersion!.isNotEmpty) {
    buffer.writeln('Desktop Agent Version: ${snapshot.desktopAgentVersion}');
  }
  buffer.writeln('Transport Mode: ${snapshot.transportMode.name}');
  buffer.writeln('Paired: ${snapshot.isPaired}');
  buffer.writeln('SSE State: ${snapshot.sseState.name}');
  buffer.writeln('Reconnect Attempts: ${snapshot.reconnectAttempts}');
  if (snapshot.lastHttpStatus != null) {
    buffer.writeln('Last HTTP Status: ${snapshot.lastHttpStatus}');
  }
  if (snapshot.lastError != null && snapshot.lastError!.isNotEmpty) {
    buffer.writeln(
      'Last Error: ${redactConnectionLogText(snapshot.lastError!)}',
    );
  }
  buffer.writeln('Diagnosis: ${diagnosis.title} (${diagnosis.severity.name})');
  buffer.writeln('Likely Cause: ${diagnosis.likelyCause}');
  buffer.writeln('Next Step: ${diagnosis.nextStep}');
  buffer.writeln('');
  buffer.writeln('--- Checklist ---');
  for (final item in diagnosis.checks) {
    buffer.writeln(
      '- [${item.severity.name.toUpperCase()}] ${item.label}: ${item.statusText}',
    );
  }
  buffer.writeln('');
  buffer.writeln('--- Recent Connection Logs (max 30) ---');
  final recentLogs = logs.length <= 30 ? logs : logs.sublist(logs.length - 30);
  if (recentLogs.isEmpty) {
    buffer.writeln('(no connection log entries)');
  } else {
    for (final entry in recentLogs) {
      final ts = entry.timestamp.toUtc().toIso8601String();
      final detail = entry.detail == null || entry.detail!.isEmpty
          ? ''
          : ' — ${redactConnectionLogText(entry.detail!)}';
      buffer.writeln(
        '$ts [${entry.level.name.toUpperCase()}] ${entry.code}$detail',
      );
    }
  }
  return redactConnectionLogText(buffer.toString().trimRight());
}
