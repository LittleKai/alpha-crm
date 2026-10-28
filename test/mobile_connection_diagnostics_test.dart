import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_transport.dart';
import 'package:alpha_crm/features/messaging/live_chat/utils/mobile_connection_diagnostics.dart';
import 'package:alpha_crm/shared/api/crm_sse_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalmStatusReveal / stepCalmStatusReveal', () {
    test('transient disconnect under 5000ms never becomes visible (including startup)', () {
      final step0 = stepCalmStatusReveal(
        CalmStatusReveal.idle,
        down: true,
        immediate: false,
        nowMs: 0,
      );
      expect(step0.visible, isFalse);
      expect(step0.recheckIn, const Duration(milliseconds: 5000));
      expect(step0.next.downSince, 0);

      // Recovers at t = 2000ms -> never visible, returns to idle.
      final step1 = stepCalmStatusReveal(
        step0.next,
        down: false,
        immediate: false,
        nowMs: 2000,
      );
      expect(step1.visible, isFalse);
      expect(step1.recheckIn, isNull);
      expect(step1.next, CalmStatusReveal.idle);
    });

    test('sustained disconnect >= 5000ms becomes visible and holds for 2000ms minVisible + 1000ms healthyHold', () {
      final step0 = stepCalmStatusReveal(
        CalmStatusReveal.idle,
        down: true,
        immediate: false,
        nowMs: 1000,
      );
      expect(step0.visible, isFalse);
      expect(step0.recheckIn, const Duration(milliseconds: 5000));

      // At t = 6000ms (5000ms elapsed) -> visible!
      final step1 = stepCalmStatusReveal(
        step0.next,
        down: true,
        immediate: false,
        nowMs: 6000,
      );
      expect(step1.visible, isTrue);
      expect(step1.next.shownAt, 6000);
      expect(step1.recheckIn, isNull);

      // Reconnects at t = 6500ms -> still visible because minVisible (until 8000ms) > healthyHold (until 7500ms).
      final step2 = stepCalmStatusReveal(
        step1.next,
        down: false,
        immediate: false,
        nowMs: 6500,
      );
      expect(step2.visible, isTrue);
      expect(step2.recheckIn, const Duration(milliseconds: 1500));

      // At t = 8000ms -> clears to idle.
      final step3 = stepCalmStatusReveal(
        step2.next,
        down: false,
        immediate: false,
        nowMs: 8000,
      );
      expect(step3.visible, isFalse);
      expect(step3.recheckIn, isNull);
      expect(step3.next, CalmStatusReveal.idle);
    });

    test('flapping healthy -> down within 1000ms healthyHold keeps the same outage without resetting downSince', () {
      // Reveal at t = 5000ms.
      final down0 = stepCalmStatusReveal(
        CalmStatusReveal.idle,
        down: true,
        immediate: false,
        nowMs: 0,
      );
      final revealed = stepCalmStatusReveal(
        down0.next,
        down: true,
        immediate: false,
        nowMs: 5000,
      );
      expect(revealed.visible, isTrue);

      // Healthy at t = 8000ms (minVisible 2s already satisfied, so 1000ms healthyHold applies until 9000ms).
      final healthyAt8k = stepCalmStatusReveal(
        revealed.next,
        down: false,
        immediate: false,
        nowMs: 8000,
      );
      expect(healthyAt8k.visible, isTrue);
      expect(healthyAt8k.recheckIn, const Duration(milliseconds: 1000));

      // Drops again at t = 8500ms -> stays visible immediately with original downSince = 0.
      final flapDown = stepCalmStatusReveal(
        healthyAt8k.next,
        down: true,
        immediate: false,
        nowMs: 8500,
      );
      expect(flapDown.visible, isTrue);
      expect(flapDown.next.downSince, 0);
      expect(flapDown.next.healthySince, isNull);
      expect(flapDown.recheckIn, isNull);
    });

    test('immediate: true reveals banner at once', () {
      final step = stepCalmStatusReveal(
        CalmStatusReveal.idle,
        down: true,
        immediate: true,
        nowMs: 500,
      );
      expect(step.visible, isTrue);
      expect(step.next.shownAt, 500);
      expect(step.recheckIn, isNull);
    });
  });

  group('diagnoseMobileConnection priority & 4 checklist rows', () {
    MobileConnectionSnapshot baseSnapshot({
      LiveChatTransportMode transportMode = LiveChatTransportMode.cloudRemote,
      bool isPaired = true,
      SseConnectionState sseState = SseConnectionState.connected,
      bool showReconnectBanner = false,
      int reconnectAttempts = 0,
      int? lastHttpStatus,
      String? lastError,
      bool hasAgentSnapshot = true,
      bool anyDeviceOnline = true,
      bool anyOnlineDeviceHasZaloIssue = false,
      DateTime? lastHeartbeatAt,
      String? mobileAppVersion,
      String? desktopAppVersion,
      String? desktopAgentVersion,
    }) {
      return MobileConnectionSnapshot(
        transportMode: transportMode,
        isPaired: isPaired,
        sseState: sseState,
        showReconnectBanner: showReconnectBanner,
        reconnectAttempts: reconnectAttempts,
        lastHttpStatus: lastHttpStatus,
        lastError: lastError,
        hasAgentSnapshot: hasAgentSnapshot,
        anyDeviceOnline: anyDeviceOnline,
        anyOnlineDeviceHasZaloIssue: anyOnlineDeviceHasZaloIssue,
        lastHeartbeatAt: lastHeartbeatAt,
        mobileAppVersion: mobileAppVersion,
        desktopAppVersion: desktopAppVersion,
        desktopAgentVersion: desktopAgentVersion,
      );
    }

    test('1. non-cloudRemote returns info "Chỉ áp dụng cho điện thoại"', () {
      final result = diagnoseMobileConnection(
        baseSnapshot(transportMode: LiveChatTransportMode.localBridge),
      );
      expect(result.severity, MobileConnectionIssueSeverity.info);
      expect(result.title, contains('Chỉ áp dụng cho điện thoại'));
      expect(result.checks, hasLength(4));
    });

    test('2. unpaired returns warning advising QR scan or 6-digit code', () {
      final result = diagnoseMobileConnection(baseSnapshot(isPaired: false));
      expect(result.severity, MobileConnectionIssueSeverity.warning);
      expect(result.nextStep, contains('6 chữ số'));
      expect(result.checks, hasLength(4));
    });

    test('3. HTTP 401 and 402/403 return error for auth / subscription', () {
      final authErr = diagnoseMobileConnection(
        baseSnapshot(
          sseState: SseConnectionState.disconnected,
          lastHttpStatus: 401,
        ),
      );
      expect(authErr.severity, MobileConnectionIssueSeverity.error);
      expect(authErr.nextStep.toLowerCase(), contains('đăng nhập'));

      final subErr = diagnoseMobileConnection(
        baseSnapshot(
          sseState: SseConnectionState.disconnected,
          lastHttpStatus: 402,
        ),
      );
      expect(subErr.severity, MobileConnectionIssueSeverity.error);
      expect(subErr.nextStep.toLowerCase(), contains('gói'));
    });

    test('4. SSE down with showReconnectBanner advises checking network or manual reconnect', () {
      final result = diagnoseMobileConnection(
        baseSnapshot(
          sseState: SseConnectionState.disconnected,
          showReconnectBanner: true,
          reconnectAttempts: 3,
        ),
      );
      expect(result.severity, MobileConnectionIssueSeverity.warning);
      expect(result.likelyCause, contains('3'));
      expect(result.nextStep, contains('Kết nối lại ngay'));
    });

    test('5. no snapshot yet returns info "Đang kiểm tra"', () {
      final result = diagnoseMobileConnection(
        baseSnapshot(hasAgentSnapshot: false),
      );
      expect(result.severity, MobileConnectionIssueSeverity.info);
      expect(result.title, contains('Đang kiểm tra'));
    });

    test('6. Desktop Agent offline converts UTC lastHeartbeatAt to local time and advises opening PC app', () {
      final localTime = DateTime(2026, 10, 28, 9, 30);
      final utcTime = localTime.toUtc();
      final result = diagnoseMobileConnection(
        baseSnapshot(
          anyDeviceOnline: false,
          lastHeartbeatAt: utcTime,
        ),
      );
      expect(result.severity, MobileConnectionIssueSeverity.warning);
      expect(result.likelyCause, contains('09:30'));
      expect(result.checks[2].statusText, contains('09:30'));
      expect(result.nextStep, contains('máy tính'));
    });

    test('7. Zalo session issue advises re-scanning Zalo QR on PC', () {
      final result = diagnoseMobileConnection(
        baseSnapshot(anyOnlineDeviceHasZaloIssue: true),
      );
      expect(result.severity, MobileConnectionIssueSeverity.warning);
      expect(result.nextStep, contains('QR Zalo'));
    });

    test('8. version compatibility check warns when desktop or mobile is outdated', () {
      final desktopOld = diagnoseMobileConnection(
        baseSnapshot(
          mobileAppVersion: '0.2.4+32',
          desktopAppVersion: '0.2.3',
        ),
      );
      expect(desktopOld.severity, MobileConnectionIssueSeverity.warning);
      expect(desktopOld.title, contains('máy tính đã cũ'));
      expect(desktopOld.likelyCause, contains('v0.2.3'));
      expect(desktopOld.likelyCause, contains('v0.2.4'));
      expect(
        desktopOld.checks[2].severity,
        MobileConnectionIssueSeverity.warning,
      );

      final mobileOld = diagnoseMobileConnection(
        baseSnapshot(
          mobileAppVersion: '0.2.3+31',
          desktopAppVersion: '0.3.0',
        ),
      );
      expect(mobileOld.severity, MobileConnectionIssueSeverity.warning);
      expect(mobileOld.title, contains('điện thoại đã cũ'));
      expect(
        mobileOld.checks[2].severity,
        MobileConnectionIssueSeverity.warning,
      );
    });

    test('9. all checks passing returns healthy', () {
      final result = diagnoseMobileConnection(
        baseSnapshot(
          mobileAppVersion: '0.2.3+31',
          desktopAppVersion: '0.2.3',
        ),
      );
      expect(result.severity, MobileConnectionIssueSeverity.healthy);
      expect(result.checks, hasLength(4));
      expect(
        result.checks.every(
          (c) => c.severity == MobileConnectionIssueSeverity.healthy,
        ),
        isTrue,
      );
    });
  });

  group('evaluateAgentVersionCompat', () {
    test('compares semver triplets and handles build metadata or missing versions', () {
      expect(
        evaluateAgentVersionCompat(
          mobileAppVersion: '0.2.3+31',
          desktopAppVersion: 'v0.2.3',
        ).status,
        AgentVersionCompatStatus.compatible,
      );
      expect(
        evaluateAgentVersionCompat(
          mobileAppVersion: '0.2.3+31',
          desktopAppVersion: '0.2.2',
        ).status,
        AgentVersionCompatStatus.desktopOutdated,
      );
      expect(
        evaluateAgentVersionCompat(
          mobileAppVersion: '0.2.3',
          desktopAppVersion: '0.3.0',
        ).status,
        AgentVersionCompatStatus.mobileOutdated,
      );
      expect(
        evaluateAgentVersionCompat(
          mobileAppVersion: null,
          desktopAppVersion: '0.2.3',
        ).status,
        AgentVersionCompatStatus.unknown,
      );
      expect(
        evaluateAgentVersionCompat(
          mobileAppVersion: '0.2.3',
          desktopAppVersion: '0.0.0',
        ).status,
        AgentVersionCompatStatus.unknown,
      );
    });
  });

  group('buildRedactedDiagnosticsReport', () {
    test('limits logs to 30 newest lines, shows desktopAgentVersion only if present, and scrubs planted tokens', () {
      final logs = List.generate(
        45,
        (i) => CrmConnectionLogEntry(
          timestamp: DateTime.utc(2026, 10, 28, 0, 0, i),
          level: CrmConnectionLogLevel.info,
          code: 'sse.step_$i',
          detail: 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIn0.sig_secret_$i',
        ),
      );

      final snapshot = MobileConnectionSnapshot(
        transportMode: LiveChatTransportMode.cloudRemote,
        isPaired: true,
        sseState: SseConnectionState.disconnected,
        showReconnectBanner: true,
        reconnectAttempts: 2,
        lastError: 'token=my_planted_secret_token_999',
        hasAgentSnapshot: true,
        anyDeviceOnline: true,
        anyOnlineDeviceHasZaloIssue: false,
        desktopAgentVersion: '0.2.0',
      );

      final report = buildRedactedDiagnosticsReport(
        snapshot,
        logs,
        mobileAppVersion: '0.2.3+31',
      );

      expect(report, contains('0.2.3+31'));
      expect(report, contains('0.2.0'));
      expect(report, contains('sse.step_44'));
      expect(report, contains('sse.step_15'));
      expect(report, isNot(contains('sse.step_14')));
      expect(report, isNot(contains('sig_secret_')));
      expect(report, isNot(contains('my_planted_secret_token_999')));
    });
  });
}
