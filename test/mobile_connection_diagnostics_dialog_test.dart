import 'package:alpha_crm/features/devices/providers/crm_device_provider.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_transport.dart';
import 'package:alpha_crm/features/messaging/live_chat/presentation/widgets/mobile_connection_diagnostics_dialog.dart';
import 'package:alpha_crm/features/messaging/live_chat/providers/agent_status_provider.dart';
import 'package:alpha_crm/features/messaging/live_chat/providers/live_chat_provider.dart';
import 'package:alpha_crm/shared/api/crm_sse_client.dart';
import 'package:alpha_crm/shared/api/crm_sse_provider.dart';
import 'package:alpha_crm/shared/widgets/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSseClient extends CrmSseClient {
  int reconnectNowCount = 0;
  String? lastReconnectReason;

  _FakeSseClient() {
    connectionState.value = SseConnectionState.disconnected;
    connectionLog.value = [
      CrmConnectionLogEntry(
        timestamp: DateTime.utc(2026, 10, 28, 10, 15, 0),
        level: CrmConnectionLogLevel.warn,
        code: 'sse.idle_timeout',
        detail: redactConnectionLogText(
          'Idle after 65s with Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIn0.secret_sig_999',
        ),
      ),
    ];
  }

  @override
  void reconnectNow({String reason = 'manual'}) {
    reconnectNowCount++;
    lastReconnectReason = reason;
  }
}

class _FakeDeviceNotifier extends CrmDeviceNotifier {
  int checkPairingCalls = 0;

  _FakeDeviceNotifier({CrmDeviceState? initial}) {
    state =
        initial ??
        const CrmDeviceState(
          hasLoaded: true,
          isPaired: true,
          deviceId: 'pc-1',
        );
  }

  @override
  Future<void> checkPairingStatus() async {
    checkPairingCalls++;
  }
}

void main() {
  testWidgets(
    '1. renders AppDialog with diagnosis, 4 checklist rows, and redacted logs without leaking tokens',
    (tester) async {
      final fakeSse = _FakeSseClient();
      final fakeDevice = _FakeDeviceNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            liveChatTransportModeProvider.overrideWithValue(
              LiveChatTransportMode.cloudRemote,
            ),
            crmSseClientProvider.overrideWithValue(fakeSse),
            crmDeviceProvider.overrideWith((_) => fakeDevice),
            agentStatusProvider.overrideWith(
              (_) => AgentStatusNotifier(
                null,
                initialState: const AgentStatusState(
                  hasSnapshot: true,
                  sseConnected: false,
                  showReconnectBanner: true,
                  devicesById: {
                    'pc-1': AgentDeviceStatus(
                      deviceId: 'pc-1',
                      displayName: 'Office PC',
                      online: true,
                      worstZaloHealth: ZaloAccountHealth.online,
                    ),
                  },
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MobileConnectionDiagnosticsDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Mất kết nối tới máy chủ đám mây'), findsOneWidget);
      expect(find.text('Ghép đôi máy tính'), findsOneWidget);
      expect(find.text('Kết nối máy chủ (SSE)'), findsOneWidget);
      expect(find.text('Desktop Agent trên PC'), findsOneWidget);
      expect(find.text('Phiên Zalo trên PC'), findsOneWidget);
      expect(find.textContaining('sse.idle_timeout'), findsOneWidget);
      expect(find.textContaining('secret_sig_999'), findsNothing);
    },
  );

  testWidgets(
    '2. tapping "Kết nối lại ngay" calls reconnectNow and checkPairingStatus; disabled while connecting',
    (tester) async {
      final fakeSse = _FakeSseClient();
      final fakeDevice = _FakeDeviceNotifier();
      fakeDevice.checkPairingCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            liveChatTransportModeProvider.overrideWithValue(
              LiveChatTransportMode.cloudRemote,
            ),
            crmSseClientProvider.overrideWithValue(fakeSse),
            crmDeviceProvider.overrideWith((_) => fakeDevice),
            agentStatusProvider.overrideWith(
              (_) => AgentStatusNotifier(
                null,
                initialState: const AgentStatusState(
                  hasSnapshot: true,
                  sseConnected: false,
                  showReconnectBanner: true,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MobileConnectionDiagnosticsDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kết nối lại ngay'));
      await tester.pumpAndSettle();

      expect(fakeSse.reconnectNowCount, 1);
      expect(fakeSse.lastReconnectReason, 'diagnostics_dialog');
      expect(fakeDevice.checkPairingCalls, 1);

      // When connectionState == connecting, button should be disabled.
      fakeSse.connectionState.value = SseConnectionState.connecting;
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kết nối lại ngay'));
      await tester.pumpAndSettle();
      expect(fakeSse.reconnectNowCount, 1);
    },
  );

  testWidgets(
    '3. tapping "Sao chép báo cáo" copies redacted report to clipboard and shows inline "Đã sao chép"',
    (tester) async {
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              final args = call.arguments as Map;
              copiedText = args['text'] as String?;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final fakeSse = _FakeSseClient();
      final fakeDevice = _FakeDeviceNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            liveChatTransportModeProvider.overrideWithValue(
              LiveChatTransportMode.cloudRemote,
            ),
            crmSseClientProvider.overrideWithValue(fakeSse),
            crmDeviceProvider.overrideWith((_) => fakeDevice),
            agentStatusProvider.overrideWith(
              (_) => AgentStatusNotifier(
                null,
                initialState: const AgentStatusState(
                  hasSnapshot: true,
                  sseConnected: true,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MobileConnectionDiagnosticsDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sao chép báo cáo'));
      await tester.pumpAndSettle();

      expect(copiedText, isNotNull);
      expect(copiedText, contains('ALPHA CRM MOBILE CONNECTION DIAGNOSTICS'));
      expect(copiedText, isNot(contains('secret_sig_999')));
      expect(find.text('Đã sao chép'), findsOneWidget);
    },
  );

  testWidgets(
    '4. showMobileConnectionDiagnosticsDialog opens dialog and "Đóng" closes it cleanly',
    (tester) async {
      final fakeSse = _FakeSseClient();
      final fakeDevice = _FakeDeviceNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            liveChatTransportModeProvider.overrideWithValue(
              LiveChatTransportMode.cloudRemote,
            ),
            crmSseClientProvider.overrideWithValue(fakeSse),
            crmDeviceProvider.overrideWith((_) => fakeDevice),
            agentStatusProvider.overrideWith(
              (_) => AgentStatusNotifier(
                null,
                initialState: const AgentStatusState(
                  hasSnapshot: true,
                  sseConnected: true,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      showMobileConnectionDiagnosticsDialog(context),
                  child: const Text('Mở chẩn đoán'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở chẩn đoán'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsOneWidget);

      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
    },
  );

  testWidgets(
    '5. when CrmDeviceState has not loaded yet (opened from LiveChat while offline), diagnoses SSE outage instead of unpaired',
    (tester) async {
      final fakeSse = _FakeSseClient();
      final uninitialisedDevice = _FakeDeviceNotifier(
        initial: const CrmDeviceState(
          hasLoaded: false,
          isPaired: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            liveChatTransportModeProvider.overrideWithValue(
              LiveChatTransportMode.cloudRemote,
            ),
            crmSseClientProvider.overrideWithValue(fakeSse),
            crmDeviceProvider.overrideWith((_) => uninitialisedDevice),
            agentStatusProvider.overrideWith(
              (_) => AgentStatusNotifier(
                null,
                initialState: const AgentStatusState(
                  hasSnapshot: true,
                  sseConnected: false,
                  showReconnectBanner: true,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MobileConnectionDiagnosticsDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mất kết nối tới máy chủ đám mây'), findsOneWidget);
      expect(find.text('Chưa ghép đôi với máy tính chủ'), findsNothing);
    },
  );

  testWidgets(
    '6. warns when desktop appVersion is older than mobileAppVersionOverride',
    (tester) async {
      final fakeSse = _FakeSseClient();
      fakeSse.connectionState.value = SseConnectionState.connected;
      final fakeDevice = _FakeDeviceNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            liveChatTransportModeProvider.overrideWithValue(
              LiveChatTransportMode.cloudRemote,
            ),
            crmSseClientProvider.overrideWithValue(fakeSse),
            crmDeviceProvider.overrideWith((_) => fakeDevice),
            agentStatusProvider.overrideWith(
              (_) => AgentStatusNotifier(
                null,
                initialState: const AgentStatusState(
                  hasSnapshot: true,
                  sseConnected: true,
                  showReconnectBanner: false,
                  devicesById: {
                    'pc-1': AgentDeviceStatus(
                      deviceId: 'pc-1',
                      displayName: 'Office PC',
                      online: true,
                      worstZaloHealth: ZaloAccountHealth.online,
                      appVersion: '0.2.2',
                      agentVersion: '0.2.0',
                    ),
                  },
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MobileConnectionDiagnosticsDialog(
                mobileAppVersionOverride: '0.2.3+31',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Phiên bản Alpha CRM trên máy tính đã cũ'),
        findsOneWidget,
      );
      expect(find.textContaining('PC v0.2.2 < Mobile v0.2.3'), findsOneWidget);
    },
  );
}
