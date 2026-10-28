import 'dart:async';
import 'dart:convert';

import 'package:alpha_crm/shared/api/crm_sse_client.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _FakeHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(
    http.BaseRequest request,
    _FakeHttpClient client,
  ) _handler;

  bool isClosed = false;
  int sendCount = 0;
  final List<StreamController<List<int>>> _controllers = [];

  _FakeHttpClient(this._handler);

  void attachController(StreamController<List<int>> controller) {
    _controllers.add(controller);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sendCount++;
    return _handler(request, this);
  }

  @override
  void close() {
    if (isClosed) return;
    isClosed = true;
    for (final c in _controllers) {
      if (!c.isClosed) {
        c.addError(http.ClientException('Client closed'));
        c.close();
      }
    }
  }
}

void main() {
  test('decodes a single-line data frame terminated by a blank line', () {
    final decoder = CrmSseDecoder();
    expect(decoder.addLine('event: hello'), isNull);
    expect(decoder.addLine('id: 1'), isNull);
    expect(
      decoder.addLine('data: {"serverTime":"2026-07-02T00:00:00.000Z"}'),
      isNull,
    );
    final event = decoder.addLine('');

    expect(event, isNotNull);
    expect(event!.name, 'hello');
    expect(event.id, '1');
    expect(event.data['serverTime'], '2026-07-02T00:00:00.000Z');
  });

  test('joins multi-line data payloads with a newline before decoding', () {
    // The joining newline must land where JSON allows whitespace (never
    // inside a string literal, which would make raw JSON invalid) — this
    // matches how a real multi-line `data:` payload is legally split.
    final decoder = CrmSseDecoder();
    decoder.addLine('event: message.new');
    decoder.addLine('data: {"message":');
    decoder.addLine('data: {"content":"hello"}}');
    final event = decoder.addLine('');

    expect(event, isNotNull);
    expect(event!.data['message']['content'], 'hello');
  });

  test('ignores keep-alive comment lines without terminating the frame', () {
    final decoder = CrmSseDecoder();
    decoder.addLine('event: device.status');
    decoder.addLine('data: {"deviceId":"dev-1"}');
    expect(decoder.addLine(': ping'), isNull);
    final event = decoder.addLine('');

    expect(event, isNotNull);
    expect(event!.data['deviceId'], 'dev-1');
  });

  test('a bare comment line with no pending frame produces no event', () {
    final decoder = CrmSseDecoder();
    expect(decoder.addLine(': ping'), isNull);
    expect(decoder.addLine(''), isNull);
  });

  test('defaults the event name to "message" when omitted', () {
    final decoder = CrmSseDecoder();
    decoder.addLine('data: {"a":1}');
    final event = decoder.addLine('');

    expect(event!.name, 'message');
  });

  test('drops a frame with malformed JSON instead of throwing', () {
    final decoder = CrmSseDecoder();
    decoder.addLine('event: message.status');
    decoder.addLine('data: {not valid json');
    final event = decoder.addLine('');

    expect(event, isNull);
  });

  test('resets state between frames so a later valid frame still decodes', () {
    final decoder = CrmSseDecoder();
    decoder.addLine('data: {not valid json');
    decoder.addLine('');
    decoder.addLine('event: conversation.updated');
    decoder.addLine('data: {"accountId":"acc-1"}');
    final event = decoder.addLine('');

    expect(event, isNotNull);
    expect(event!.name, 'conversation.updated');
    expect(event.data['accountId'], 'acc-1');
  });

  group('CrmSseClient resilience, watchdog & redaction', () {
    test(
      '1. redactConnectionLogText scrubs tokens, qrToken, pairingCode, code, cookies, phones, hex, JWT, and emails while preserving event/status/epoch info',
      () {
        const raw =
            'SSE HTTP 401 on event device.status after 65s (epoch=1708499887766): Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c '
            'url=https://api.example.com/crm?token=secret_query_token_123&code=654-321 '
            'payload={"qrToken":"0123456789abcdef0123456789abcdef0123456789abcdef","pairingToken":"pt-secret-999","pairingCode":"123456","code":"987654"} '
            'Cookie: zpw_sek=super_secret_cookie_val; '
            'phone=+84912345678 '
            'hex=abcdef0123456789abcdef0123456789abcdef0123456789 '
            'user=admin@alphastudio.vn';

        final scrubbed = redactConnectionLogText(raw);

        expect(scrubbed, contains('SSE HTTP 401'));
        expect(scrubbed, contains('device.status'));
        expect(scrubbed, contains('65s'));
        expect(scrubbed, contains('epoch=1708499887766'));
        expect(scrubbed, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));
        expect(scrubbed, isNot(contains('secret_query_token_123')));
        expect(scrubbed, isNot(contains('654-321')));
        expect(
          scrubbed,
          isNot(contains('0123456789abcdef0123456789abcdef0123456789abcdef')),
        );
        expect(scrubbed, isNot(contains('pt-secret-999')));
        expect(scrubbed, isNot(contains('123456')));
        expect(scrubbed, isNot(contains('987654')));
        expect(scrubbed, isNot(contains('super_secret_cookie_val')));
        expect(scrubbed, isNot(contains('84912345678')));
        expect(
          scrubbed,
          isNot(contains('abcdef0123456789abcdef0123456789abcdef0123456789')),
        );
        expect(scrubbed, isNot(contains('admin@alphastudio.vn')));
      },
    );

    test(
      '2. connectionLog is bounded to maxLogEntries and never leaks the access token',
      () {
        fakeAsync((async) {
          final createdClients = <_FakeHttpClient>[];
          final sse = CrmSseClient(
            maxLogEntries: 100,
            tokenProvider: () async => 'test-token-super-secret-value-1234567890',
            baseUrlProvider: () => 'https://test.invalid/api',
            httpClientFactory: () {
              late _FakeHttpClient client;
              client = _FakeHttpClient((request, self) async {
                final controller = StreamController<List<int>>();
                self.attachController(controller);
                return http.StreamedResponse(controller.stream, 200);
              });
              createdClients.add(client);
              return client;
            },
          );

          final sub = sse.events.listen((_) {});
          async.flushMicrotasks();

          for (var i = 0; i < 80; i++) {
            sse.reconnectNow(reason: 'step_$i via Bearer test-token-super-secret-value-1234567890');
            async.flushMicrotasks();
          }

          final logs = sse.connectionLog.value;
          expect(logs.length, 100);
          expect(logs.first.detail, isNot(equals('step_0')));
          expect(logs.last.code, 'sse.connected');
          for (final entry in logs) {
            expect(
              entry.detail ?? '',
              isNot(contains('test-token-super-secret-value-1234567890')),
            );
          }

          sub.cancel();
          sse.dispose();
          async.flushMicrotasks();
          expect(async.pendingTimers, isEmpty);
        });
      },
    );

    test(
      '3. idle watchdog closes silent stream after idleTimeout and schedules reconnect',
      () {
        fakeAsync((async) {
          final createdClients = <_FakeHttpClient>[];
          final sse = CrmSseClient(
            idleTimeout: const Duration(seconds: 65),
            connectTimeout: const Duration(seconds: 20),
            tokenProvider: () async => 'test-token',
            baseUrlProvider: () => 'https://test.invalid/api',
            httpClientFactory: () {
              final client = _FakeHttpClient((request, self) async {
                final controller = StreamController<List<int>>();
                self.attachController(controller);
                return http.StreamedResponse(controller.stream, 200);
              });
              createdClients.add(client);
              return client;
            },
          );

          final sub = sse.events.listen((_) {});
          async.flushMicrotasks();
          expect(createdClients, hasLength(1));
          expect(sse.connectionState.value, SseConnectionState.connected);

          // Advance to 64s -> still connected.
          async.elapse(const Duration(seconds: 64));
          expect(sse.connectionState.value, SseConnectionState.connected);
          expect(createdClients.first.isClosed, isFalse);

          // Advance 1 more second (65s total) -> idle timeout fires.
          async.elapse(const Duration(seconds: 1));
          expect(createdClients.first.isClosed, isTrue);
          expect(sse.connectionState.value, SseConnectionState.disconnected);
          expect(
            sse.connectionLog.value.where((e) => e.code == 'sse.idle_timeout'),
            hasLength(1),
          );
          expect(
            sse.connectionLog.value
                .firstWhere((e) => e.code == 'sse.idle_timeout')
                .level,
            CrmConnectionLogLevel.warn,
          );

          // Backoff delay (1s) triggers second connection attempt.
          async.elapse(const Duration(seconds: 1));
          expect(createdClients, hasLength(2));
          expect(sse.connectionState.value, SseConnectionState.connected);

          sub.cancel();
          sse.dispose();
          async.flushMicrotasks();
          expect(async.pendingTimers, isEmpty);
        });
      },
    );

    test(
      '4. keep-alive ": ping" comments reset the idle watchdog before decoder.addLine',
      () {
        fakeAsync((async) {
          final createdClients = <_FakeHttpClient>[];
          StreamController<List<int>>? activeStream;
          final sse = CrmSseClient(
            idleTimeout: const Duration(seconds: 65),
            tokenProvider: () async => 'test-token',
            baseUrlProvider: () => 'https://test.invalid/api',
            httpClientFactory: () {
              final client = _FakeHttpClient((request, self) async {
                final controller = StreamController<List<int>>();
                activeStream = controller;
                self.attachController(controller);
                return http.StreamedResponse(controller.stream, 200);
              });
              createdClients.add(client);
              return client;
            },
          );

          final sub = sse.events.listen((_) {});
          async.flushMicrotasks();
          expect(createdClients, hasLength(1));

          // Send ": ping\n\n" every 25s for 125s (> 65s idleTimeout).
          for (var i = 0; i < 5; i++) {
            async.elapse(const Duration(seconds: 25));
            activeStream!.add(utf8.encode(': ping\n\n'));
            async.flushMicrotasks();
          }

          expect(createdClients, hasLength(1));
          expect(createdClients.first.isClosed, isFalse);
          expect(sse.connectionState.value, SseConnectionState.connected);
          expect(
            sse.connectionLog.value.where((e) => e.code == 'sse.idle_timeout'),
            isEmpty,
          );

          sub.cancel();
          sse.dispose();
          async.flushMicrotasks();
          expect(async.pendingTimers, isEmpty);
        });
      },
    );

    test(
      '5. connect timeout aborts hung send() after connectTimeout and schedules reconnect',
      () {
        fakeAsync((async) {
          final createdClients = <_FakeHttpClient>[];
          var attempt = 0;
          final sse = CrmSseClient(
            connectTimeout: const Duration(seconds: 20),
            idleTimeout: const Duration(seconds: 65),
            tokenProvider: () async => 'test-token',
            baseUrlProvider: () => 'https://test.invalid/api',
            httpClientFactory: () {
              final currentAttempt = ++attempt;
              final client = _FakeHttpClient((request, self) {
                if (currentAttempt == 1) {
                  // Never completes unless closed.
                  return Completer<http.StreamedResponse>().future;
                }
                final controller = StreamController<List<int>>();
                self.attachController(controller);
                return Future.value(
                  http.StreamedResponse(controller.stream, 200),
                );
              });
              createdClients.add(client);
              return client;
            },
          );

          final sub = sse.events.listen((_) {});
          async.flushMicrotasks();
          expect(sse.connectionState.value, SseConnectionState.connecting);

          async.elapse(const Duration(seconds: 20));
          expect(createdClients.first.isClosed, isTrue);
          expect(sse.connectionState.value, SseConnectionState.disconnected);
          expect(
            sse.connectionLog.value.where(
              (e) => e.code == 'sse.connect_timeout',
            ),
            hasLength(1),
          );

          // After 1s backoff, attempt 2 succeeds.
          async.elapse(const Duration(seconds: 1));
          expect(createdClients, hasLength(2));
          expect(sse.connectionState.value, SseConnectionState.connected);

          sub.cancel();
          sse.dispose();
          async.flushMicrotasks();
          expect(async.pendingTimers, isEmpty);
        });
      },
    );

    test(
      '6. reconnectNow closes old client, opens one fresh stream, and resets reconnectAttempts',
      () {
        fakeAsync((async) {
          final createdClients = <_FakeHttpClient>[];
          final sse = CrmSseClient(
            tokenProvider: () async => 'test-token',
            baseUrlProvider: () => 'https://test.invalid/api',
            httpClientFactory: () {
              final client = _FakeHttpClient((request, self) async {
                final controller = StreamController<List<int>>();
                self.attachController(controller);
                return http.StreamedResponse(controller.stream, 200);
              });
              createdClients.add(client);
              return client;
            },
          );

          final sub = sse.events.listen((_) {});
          async.flushMicrotasks();
          expect(createdClients, hasLength(1));

          sse.reconnectNow(reason: 'manual_test');
          sse.reconnectNow(reason: 'manual_test_2');
          async.flushMicrotasks();

          expect(createdClients, hasLength(3));
          expect(createdClients[0].isClosed, isTrue);
          expect(createdClients[1].isClosed, isTrue);
          expect(createdClients[2].isClosed, isFalse);
          expect(sse.reconnectAttempts, 0);
          expect(sse.connectionState.value, SseConnectionState.connected);

          sub.cancel();
          sse.dispose();
          async.flushMicrotasks();
          expect(async.pendingTimers, isEmpty);
        });
      },
    );

    test(
      '7. resume() while already connected or connecting is idempotent and does not open duplicate streams',
      () {
        fakeAsync((async) {
          final createdClients = <_FakeHttpClient>[];
          final sse = CrmSseClient(
            tokenProvider: () async => 'test-token',
            baseUrlProvider: () => 'https://test.invalid/api',
            httpClientFactory: () {
              final client = _FakeHttpClient((request, self) async {
                final controller = StreamController<List<int>>();
                self.attachController(controller);
                return http.StreamedResponse(controller.stream, 200);
              });
              createdClients.add(client);
              return client;
            },
          );

          final sub = sse.events.listen((_) {});
          // While connecting (before microtasks finish):
          sse.resume();
          async.flushMicrotasks();
          expect(createdClients, hasLength(1));
          expect(sse.connectionState.value, SseConnectionState.connected);

          // While already connected:
          sse.resume();
          async.flushMicrotasks();
          expect(createdClients, hasLength(1));
          expect(createdClients.first.isClosed, isFalse);

          sub.cancel();
          sse.dispose();
          async.flushMicrotasks();
          expect(async.pendingTimers, isEmpty);
        });
      },
    );

    test(
      '8. pause() cancels watchdog and reconnect timer; dispose() leaves no pending timers',
      () {
        fakeAsync((async) {
          final createdClients = <_FakeHttpClient>[];
          final sse = CrmSseClient(
            idleTimeout: const Duration(seconds: 65),
            tokenProvider: () async => 'test-token',
            baseUrlProvider: () => 'https://test.invalid/api',
            httpClientFactory: () {
              final client = _FakeHttpClient((request, self) async {
                final controller = StreamController<List<int>>();
                self.attachController(controller);
                return http.StreamedResponse(controller.stream, 200);
              });
              createdClients.add(client);
              return client;
            },
          );

          final sub = sse.events.listen((_) {});
          async.flushMicrotasks();
          expect(createdClients, hasLength(1));

          sse.pause();
          expect(sse.isPaused, isTrue);
          expect(createdClients.first.isClosed, isTrue);
          expect(sse.connectionState.value, SseConnectionState.disconnected);

          // Elapse 5 minutes while paused -> no reconnect attempts.
          async.elapse(const Duration(minutes: 5));
          expect(createdClients, hasLength(1));
          expect(async.pendingTimers, isEmpty);

          // Resume reconnects once.
          sse.resume();
          async.flushMicrotasks();
          expect(sse.isPaused, isFalse);
          expect(createdClients, hasLength(2));
          expect(sse.connectionState.value, SseConnectionState.connected);

          sub.cancel();
          sse.dispose();
          async.flushMicrotasks();
          expect(async.pendingTimers, isEmpty);
        });
      },
    );

    test(
      '9. generation guard ignores late failure from a stale connection attempt after reconnectNow()',
      () {
        fakeAsync((async) {
          final firstSendCompleter = Completer<http.StreamedResponse>();
          final createdClients = <_FakeHttpClient>[];
          var attempt = 0;

          final sse = CrmSseClient(
            tokenProvider: () async => 'test-token',
            baseUrlProvider: () => 'https://test.invalid/api',
            httpClientFactory: () {
              final currentAttempt = ++attempt;
              final client = _FakeHttpClient((request, self) {
                if (currentAttempt == 1) {
                  return firstSendCompleter.future;
                }
                final controller = StreamController<List<int>>();
                self.attachController(controller);
                return Future.value(
                  http.StreamedResponse(controller.stream, 200),
                );
              });
              createdClients.add(client);
              return client;
            },
          );

          final sub = sse.events.listen((_) {});
          async.flushMicrotasks();
          expect(createdClients, hasLength(1));
          expect(sse.connectionState.value, SseConnectionState.connecting);

          // Trigger reconnectNow while attempt 1's send() is still pending.
          sse.reconnectNow(reason: 'supersede');
          async.flushMicrotasks();
          expect(createdClients, hasLength(2));
          expect(sse.connectionState.value, SseConnectionState.connected);

          // Now fail attempt 1 late -> must not disturb attempt 2!
          firstSendCompleter.completeError(
            http.ClientException('late error from attempt 1'),
          );
          async.flushMicrotasks();

          expect(sse.connectionState.value, SseConnectionState.connected);
          expect(sse.reconnectAttempts, 0);
          expect(createdClients, hasLength(2));

          sub.cancel();
          sse.dispose();
          async.flushMicrotasks();
          expect(async.pendingTimers, isEmpty);
        });
      },
    );

    test(
      '10. HTTP 401/402/403 sets lastHttpStatus, logs at error level, and clears lastHttpStatus on subsequent transport failure',
      () {
        fakeAsync((async) {
          var attempt = 0;
          final sse = CrmSseClient(
            tokenProvider: () async => 'test-token',
            baseUrlProvider: () => 'https://test.invalid/api',
            httpClientFactory: () {
              final currentAttempt = ++attempt;
              return _FakeHttpClient((request, self) async {
                if (currentAttempt == 1) {
                  return http.StreamedResponse(
                    const Stream<List<int>>.empty(),
                    401,
                  );
                }
                throw http.ClientException('Offline socket error');
              });
            },
          );

          final sub = sse.events.listen((_) {});
          async.flushMicrotasks();

          expect(sse.lastHttpStatus, 401);
          final httpLog = sse.connectionLog.value.firstWhere(
            (e) => e.code == 'sse.http_error',
          );
          expect(httpLog.level, CrmConnectionLogLevel.error);
          expect(httpLog.detail, contains('401'));

          // When the next reconnect fails with a transport exception, stale 401 is cleared.
          async.elapse(const Duration(seconds: 1));
          expect(sse.lastHttpStatus, isNull);

          sub.cancel();
          sse.dispose();
          async.flushMicrotasks();
          expect(async.pendingTimers, isEmpty);
        });
      },
    );

    test(
      '11. reconnectNow() with no listeners or after dispose() is a safe no-op',
      () {
        fakeAsync((async) {
          var factoryCalls = 0;
          final sse = CrmSseClient(
            tokenProvider: () async => 'test-token',
            baseUrlProvider: () => 'https://test.invalid/api',
            httpClientFactory: () {
              factoryCalls++;
              return _FakeHttpClient((request, self) async {
                return http.StreamedResponse(
                  const Stream<List<int>>.empty(),
                  200,
                );
              });
            },
          );

          // No listener yet:
          sse.reconnectNow(reason: 'no_listener');
          async.flushMicrotasks();
          expect(factoryCalls, 0);
          expect(
            sse.connectionLog.value.where((e) => e.code == 'sse.reconnect_now'),
            hasLength(1),
          );

          // After dispose:
          sse.dispose();
          sse.reconnectNow(reason: 'after_dispose');
          async.flushMicrotasks();
          expect(factoryCalls, 0);
          expect(async.pendingTimers, isEmpty);
        });
      },
    );
  });
}
