import 'dart:async';
import 'dart:convert';

import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_transport.dart';
import 'package:alpha_crm/features/messaging/live_chat/providers/agent_status_provider.dart';
import 'package:alpha_crm/features/messaging/live_chat/providers/live_chat_provider.dart';
import 'package:alpha_crm/shared/api/crm_sse_client.dart';
import 'package:alpha_crm/shared/api/crm_sse_provider.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _ControllableHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(
    http.BaseRequest request,
    _ControllableHttpClient self,
  ) _handler;
  final List<StreamController<List<int>>> _controllers = [];
  bool isClosed = false;

  _ControllableHttpClient(this._handler);

  void attach(StreamController<List<int>> controller) {
    _controllers.add(controller);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _handler(request, this);

  @override
  void close() {
    if (isClosed) return;
    isClosed = true;
    for (final c in _controllers) {
      if (!c.isClosed) {
        c.addError(http.ClientException('Closed'));
        c.close();
      }
    }
  }
}

void main() {
  group('AgentStatusNotifier calm status reveal & lifecycle', () {
    test(
      '4. brief disconnect (<5s) flips raw sseConnected but never sets showReconnectBanner',
      () {
        fakeAsync((async) {
          final streams = <StreamController<List<int>>>[];
          var currentNow = DateTime.utc(2026, 10, 28, 12, 0, 0);

          final sse = CrmSseClient(
            clock: () => currentNow,
            tokenProvider: () async => 'test-token',
            baseUrlProvider: () => 'https://test.invalid/api',
            httpClientFactory: () {
              return _ControllableHttpClient((request, self) async {
                final controller = StreamController<List<int>>();
                self.attach(controller);
                streams.add(controller);
                return http.StreamedResponse(controller.stream, 200);
              });
            },
          );

          final container = ProviderContainer(
            overrides: [
              liveChatTransportModeProvider.overrideWithValue(
                LiveChatTransportMode.cloudRemote,
              ),
              crmSseClientProvider.overrideWithValue(sse),
            ],
          );

          // Subscribe to keep provider active.
          final sub = container.listen(agentStatusProvider, (_, _) {});
          async.flushMicrotasks();

          expect(container.read(agentStatusProvider).sseConnected, isTrue);
          expect(
            container.read(agentStatusProvider).showReconnectBanner,
            isFalse,
          );

          // Drop connection at t=0.
          streams.first.close();
          async.flushMicrotasks();
          expect(container.read(agentStatusProvider).sseConnected, isFalse);
          expect(
            container.read(agentStatusProvider).showReconnectBanner,
            isFalse,
          );

          // Reconnect happens after 1s backoff (at t=1s < 5s reveal delay).
          currentNow = currentNow.add(const Duration(seconds: 1));
          async.elapse(const Duration(seconds: 1));
          expect(container.read(agentStatusProvider).sseConnected, isTrue);
          expect(
            container.read(agentStatusProvider).showReconnectBanner,
            isFalse,
          );

          sub.close();
          container.dispose();
          sse.dispose();
          async.flushMicrotasks();
          expect(async.pendingTimers, isEmpty);
        });
      },
    );

    test(
      '5. sustained disconnect >= 5s sets showReconnectBanner == true',
      () {
        fakeAsync((async) {
          var currentNow = DateTime.utc(2026, 10, 28, 12, 0, 0);
          final sse = CrmSseClient(
            clock: () => currentNow,
            tokenProvider: () async => 'test-token',
            baseUrlProvider: () => 'https://test.invalid/api',
            httpClientFactory: () {
              return _ControllableHttpClient((request, self) async {
                throw http.ClientException('Network unreachable');
              });
            },
          );

          final container = ProviderContainer(
            overrides: [
              liveChatTransportModeProvider.overrideWithValue(
                LiveChatTransportMode.cloudRemote,
              ),
              crmSseClientProvider.overrideWithValue(sse),
            ],
          );

          final sub = container.listen(agentStatusProvider, (_, _) {});
          async.flushMicrotasks();
          expect(
            container.read(agentStatusProvider).showReconnectBanner,
            isFalse,
          );

          // Advance 6 seconds while all reconnect attempts fail.
          for (var i = 0; i < 6; i++) {
            currentNow = currentNow.add(const Duration(seconds: 1));
            async.elapse(const Duration(seconds: 1));
          }

          expect(
            container.read(agentStatusProvider).showReconnectBanner,
            isTrue,
          );

          sub.close();
          container.dispose();
          sse.dispose();
          async.flushMicrotasks();
          expect(async.pendingTimers, isEmpty);
        });
      },
    );

    test(
      '6. client.pause() while disconnected cancels calm timer, hides banner, and resets calm clock so resuming after 2 minutes gets a fresh 5s grace window',
      () {
        fakeAsync((async) {
          var currentNow = DateTime.utc(2026, 10, 28, 12, 0, 0);
          var shouldFail = true;

          final sse = CrmSseClient(
            clock: () => currentNow,
            tokenProvider: () async => 'test-token',
            baseUrlProvider: () => 'https://test.invalid/api',
            httpClientFactory: () {
              return _ControllableHttpClient((request, self) async {
                if (shouldFail) {
                  throw http.ClientException('Offline');
                }
                final controller = StreamController<List<int>>();
                self.attach(controller);
                return http.StreamedResponse(controller.stream, 200);
              });
            },
          );

          final container = ProviderContainer(
            overrides: [
              liveChatTransportModeProvider.overrideWithValue(
                LiveChatTransportMode.cloudRemote,
              ),
              crmSseClientProvider.overrideWithValue(sse),
            ],
          );

          final sub = container.listen(agentStatusProvider, (_, _) {});
          async.flushMicrotasks();
          expect(
            sse.connectionState.value,
            SseConnectionState.disconnected,
          );

          // Pause while already disconnected (at +2s, while calm 5s timer is pending).
          for (var i = 0; i < 2; i++) {
            currentNow = currentNow.add(const Duration(seconds: 1));
            async.elapse(const Duration(seconds: 1));
          }
          expect(
            container.read(agentStatusProvider).showReconnectBanner,
            isFalse,
          );
          sse.pause();
          async.flushMicrotasks();
          // No calm timer or reconnect timer may remain pending while paused!
          expect(async.pendingTimers, isEmpty);

          // Resume, let it stay disconnected for 6s so banner is revealed, then pause while disconnected.
          sse.resume();
          async.flushMicrotasks();
          for (var i = 0; i < 6; i++) {
            currentNow = currentNow.add(const Duration(seconds: 1));
            async.elapse(const Duration(seconds: 1));
          }
          expect(
            container.read(agentStatusProvider).showReconnectBanner,
            isTrue,
          );

          // Pause while disconnected with banner visible -> banner must become false immediately.
          sse.pause();
          async.flushMicrotasks();
          expect(
            container.read(agentStatusProvider).showReconnectBanner,
            isFalse,
          );
          expect(async.pendingTimers, isEmpty);

          currentNow = currentNow.add(const Duration(minutes: 2));
          async.elapse(const Duration(minutes: 2));
          expect(
            container.read(agentStatusProvider).showReconnectBanner,
            isFalse,
          );

          // Resume when first attempt fails briefly, then succeeds 1s later.
          shouldFail = true;
          sse.resume();
          async.flushMicrotasks();
          // Must NOT immediately flash banner at resume!
          expect(
            container.read(agentStatusProvider).showReconnectBanner,
            isFalse,
          );

          shouldFail = false;
          currentNow = currentNow.add(const Duration(seconds: 1));
          async.elapse(const Duration(seconds: 1));
          expect(container.read(agentStatusProvider).sseConnected, isTrue);
          expect(
            container.read(agentStatusProvider).showReconnectBanner,
            isFalse,
          );

          sub.close();
          container.dispose();
          sse.dispose();
          async.flushMicrotasks();
          expect(async.pendingTimers, isEmpty);
        });
      },
    );

    test(
      '7. container.dispose() while calm timer is pending cancels timer cleanly without throwing',
      () {
        fakeAsync((async) {
          var currentNow = DateTime.utc(2026, 10, 28, 12, 0, 0);
          final sse = CrmSseClient(
            clock: () => currentNow,
            tokenProvider: () async => 'test-token',
            baseUrlProvider: () => 'https://test.invalid/api',
            httpClientFactory: () {
              return _ControllableHttpClient((request, self) async {
                throw http.ClientException('Offline');
              });
            },
          );

          final container = ProviderContainer(
            overrides: [
              liveChatTransportModeProvider.overrideWithValue(
                LiveChatTransportMode.cloudRemote,
              ),
              crmSseClientProvider.overrideWithValue(sse),
            ],
          );

          final sub = container.listen(agentStatusProvider, (_, _) {});
          async.flushMicrotasks();

          // Dispose container and sse while calm 5s timer is still pending.
          sub.close();
          container.dispose();
          sse.dispose();

          currentNow = currentNow.add(const Duration(seconds: 10));
          async.elapse(const Duration(seconds: 10));
          expect(async.pendingTimers, isEmpty);
        });
      },
    );

    test(
      '8. hello snapshot parses nullable appVersion and agentVersion and normalizes empty strings to null',
      () {
        fakeAsync((async) {
          StreamController<List<int>>? activeStream;
          final sse = CrmSseClient(
            tokenProvider: () async => 'test-token',
            baseUrlProvider: () => 'https://test.invalid/api',
            httpClientFactory: () {
              return _ControllableHttpClient((request, self) async {
                final controller = StreamController<List<int>>();
                activeStream = controller;
                self.attach(controller);
                return http.StreamedResponse(controller.stream, 200);
              });
            },
          );

          final container = ProviderContainer(
            overrides: [
              liveChatTransportModeProvider.overrideWithValue(
                LiveChatTransportMode.cloudRemote,
              ),
              crmSseClientProvider.overrideWithValue(sse),
            ],
          );

          final sub = container.listen(agentStatusProvider, (_, _) {});
          async.flushMicrotasks();

          final helloPayload = jsonEncode({
            'devices': [
              {
                'deviceId': 'pc-1',
                'displayName': 'Office PC',
                'agentStatus': 'online',
                'appVersion': '0.2.3',
                'agentVersion': '0.2.0',
              },
              {
                'deviceId': 'pc-2',
                'displayName': 'Backup PC',
                'agentStatus': 'offline',
                'appVersion': '   ',
              },
            ],
          });
          activeStream!.add(
            utf8.encode('event: hello\ndata: $helloPayload\n\n'),
          );
          async.flushMicrotasks();

          final state = container.read(agentStatusProvider);
          expect(state.hasSnapshot, isTrue);
          expect(state.devicesById['pc-1']?.online, isTrue);
          expect(state.devicesById['pc-1']?.appVersion, '0.2.3');
          expect(state.devicesById['pc-1']?.agentVersion, '0.2.0');
          expect(state.primaryDesktopAppVersion, '0.2.3');
          expect(state.primaryDesktopAgentVersion, '0.2.0');
          expect(state.devicesById['pc-2']?.online, isFalse);
          expect(state.devicesById['pc-2']?.appVersion, isNull);
          expect(state.devicesById['pc-2']?.agentVersion, isNull);

          // Incremental device.status without displayName/appVersion preserves existing values.
          final statusPayload = jsonEncode({
            'deviceId': 'pc-1',
            'agentStatus': 'online',
            'zaloAccounts': [
              {'accountId': 'z1', 'status': 'online'},
            ],
          });
          activeStream!.add(
            utf8.encode('event: device.status\ndata: $statusPayload\n\n'),
          );
          async.flushMicrotasks();

          final updated = container.read(agentStatusProvider);
          expect(updated.devicesById['pc-1']?.displayName, 'Office PC');
          expect(updated.devicesById['pc-1']?.appVersion, '0.2.3');
          expect(updated.devicesById['pc-1']?.agentVersion, '0.2.0');

          sub.close();
          container.dispose();
          sse.dispose();
          async.flushMicrotasks();
          expect(async.pendingTimers, isEmpty);
        });
      },
    );
  });
}
