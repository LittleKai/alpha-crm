# SPEC — Production stability fixes: Live Chat realtime + Zalo backend supervisor

Date: 2026-07-04
Author: Architect (Claude)
Mode: Monolithic (single phase)

---

## Goal

Fix five verified production defects in the Alpha CRM Windows desktop app:

1. **Live Chat has no realtime updates on desktop.** `LiveChatRepository.watchEvents` returns `Stream.empty()` unless `localFirstEnabled` is true, but the `localFirstLiveChat` setting defaults to `false` and has no UI toggle. Result: new inbound Zalo messages are only detected by a 12-second polling timer that lives inside `LiveChatScreen`'s State and dies when the user navigates to another tab. → Fix the gate so desktop always opens the local SSE stream.
2. **SSE zombie risk.** The Flutter SSE client has no inactivity timeout. If the socket silently dies while `realtimeConnected` is true, the polling fallback (gated on `!realtimeConnected`) never runs. → Add a 60-second inactivity timeout (backend sends `: heartbeat` comments every 20s, so a healthy stream always has data within 20s).
3. **Supervisor kills a busy-but-healthy backend.** Watchdog probes `/health` every 5s with a 2s timeout and restarts after only 2 consecutive misses. The Node backend uses `better-sqlite3` (synchronous — heavy queries block the event loop for seconds), so a busy backend gets hard-killed. → Raise probe timeout to 5s, failure threshold to 3, and add a tick re-entrancy guard.
4. **Circuit breaker latches forever.** After 5 restarts within 2 minutes, status becomes `failed` and the watchdog tick returns immediately forever — the backend never auto-recovers until the user clicks "Thử lại". → Auto-retry once per 5-minute cooldown while keeping the manual retry button working. Also fix a stale exit-listener race in `waitUntilReady` that can wrongly abort a fresh start and feed the restart storm.
5. **Backend crashes on synchronous uncaught exceptions.** `server.ts` handles `unhandledRejection` but not `uncaughtException`. → Add the handler (log + keep alive), then rebuild the esbuild bundle.

---

## Context / Constraints

- Project: `D:\Dev\NodeJS\alpha-studio\tools\alpha-crm` — Flutter 3 desktop CRM (Dart SDK 3.10.7, Riverpod, GoRouter) + a local Node/TypeScript backend in `integration/zalo-bot-service/`.
- Shell for all commands: **Windows PowerShell**. Run Flutter commands from `D:\Dev\NodeJS\alpha-studio\tools\alpha-crm`. Run npm commands from `D:\Dev\NodeJS\alpha-studio\tools\alpha-crm\integration\zalo-bot-service`.
- **Project conventions that apply to this change (restated inline — follow them):**
  - Surgical changes only. Touch ONLY the files and lines named in the Steps. Do not reformat, do not refactor surrounding code, do not rename existing identifiers, do not add dependencies.
  - No new user-facing text is added anywhere in this SPEC, so the i18n rule (vi + en locale files) does NOT apply. Do not add UI strings.
  - Existing code comments in these files are written in Vietnamese or English; match the language of nearby comments when adding new ones.
  - After the task, documentation must be updated (Step 8) — this is mandatory in this repo.
- Files touched (complete list):
  - `lib/features/messaging/live_chat/data/live_chat_repository.dart`
  - `lib/features/messaging/live_chat/data/live_chat_local_bridge_api.dart`
  - `lib/shared/utils/zalo_backend_manager.dart`
  - `integration/zalo-bot-service/src/server.ts`
  - `test/live_chat_repository_watch_events_test.dart` (new file)
  - `.claude/IMPORTANT_FIXED_BUGS.md`, `.claude/PROJECT_SUMMARY.md` (docs)
- Do NOT touch: `live_chat_provider.dart`, `live_chat_screen.dart`, `live_chat_transport.dart`, `app_router.dart`, settings screens, i18n files, or any other file.

---

## Context Pack (verbatim excerpts from the real codebase — trust these)

### A. `lib/features/messaging/live_chat/data/live_chat_repository.dart`

The class `LiveChatRepository` has these relevant members (all already exist — reuse verbatim):

- `final bool localFirstEnabled;`
- `final LiveChatTransportMode mode;` (enum values: `LiveChatTransportMode.localBridge`, `LiveChatTransportMode.cloudRemote`)
- `final LiveChatLocalBridgeApi localApi;`
- `final CrmSseClient? sseClient;`
- A private getter `bool get _preferLocalZaloActions` which is `true` on Windows desktop builds. Every other local action in this class is gated with the pattern `_preferLocalZaloActions || localFirstEnabled` — for example line 160:

```dart
    final useLocalMessages = _preferLocalZaloActions || localFirstEnabled;
```

The buggy method (around lines 363–378; line numbers may shift slightly — anchor on the code text, not the number):

```dart
  Stream<LiveChatEvent> watchEvents({String? accountId, String? threadId}) {
    if (mode == LiveChatTransportMode.cloudRemote) {
      final client = sseClient;
      if (client == null) return const Stream.empty();
      return mapCloudSseEvents(client.events, accountId: accountId);
    }
    if (!localFirstEnabled) return const Stream.empty();
    return localApi.watchEvents(accountId: accountId, threadId: threadId);
  }
```

### B. `lib/features/messaging/live_chat/data/live_chat_local_bridge_api.dart`

Imports at top of file (already present): `dart:convert`, `package:http/http.dart as http`, `live_chat_event.dart`. The class is constructed as `LiveChatLocalBridgeApi({this.baseUrl = 'http://127.0.0.1:28080'});`.

Current SSE method, lines 197–228:

```dart
  Stream<LiveChatEvent> watchEvents({
    String? accountId,
    String? threadId,
  }) async* {
    final query = <String, String>{
      if (accountId != null && accountId.isNotEmpty) 'accountId': accountId,
      if (threadId != null && threadId.isNotEmpty) 'threadId': threadId,
    };
    final uri = Uri.parse(
      '$baseUrl/local/events',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final client = http.Client();
    try {
      final request = http.Request('GET', uri)
        ..headers['Accept'] = 'text/event-stream';
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Bridge SSE error: ${response.statusCode}');
      }
      final decoder = LiveChatSseDecoder();
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        for (final event in decoder.addLine(line)) {
          yield event;
        }
      }
    } finally {
      client.close();
    }
  }
```

Fact: the local backend SSE endpoint (`GET /local/events` in `integration/zalo-bot-service/src/local-chat/local-chat-api.ts`) writes a `: connected` comment on connect and a `: heartbeat` comment every 20 seconds. The Flutter `LiveChatSseDecoder` (in `lib/features/messaging/live_chat/data/live_chat_event.dart`) synthesizes a `bridge.connected` event from the `: connected` comment; `LiveChatNotifier._handleRealtimeEvent` already handles `bridge.connected` by reloading accounts + conversations and setting `realtimeConnected = true`. The notifier already has reconnect-with-backoff on stream error/done. **No provider changes are needed** — once the stream actually opens, everything downstream already works.

### C. `lib/shared/utils/zalo_backend_manager.dart`

Class `ZaloBackendManager` (all-static). Relevant constants, lines 52–63:

```dart
  static const String _serviceId = 'alpha-crm-zalo-bot-service';
  static const int _defaultPort = 28080;
  static const int _fallbackPortLimit = 10;
  static const Duration _watchdogInterval = Duration(seconds: 5);

  /// Số nhịp health-check lỗi liên tiếp trước khi coi backend là chết.
  static const int _failureThreshold = 2;

  /// Số lần khởi động lại tối đa trong [_circuitWindow] trước khi mở circuit.
  static const int _maxRestartsPerWindow = 5;
  static const Duration _circuitWindow = Duration(minutes: 2);
  static const Duration _maxBackoff = Duration(seconds: 30);
```

State fields, lines 70–76:

```dart
  static Timer? _watchdogTimer;
  static int _consecutiveFailures = 0;
  static int _restartCount = 0;
  static DateTime? _windowStart;

  /// Đang trong một chu trình (re)start — chặn watchdog kích hoạt chồng chéo.
  static bool _ensuring = false;
```

Status enum is `BackendStatus` with values used here: `stopped`, `starting`, `restarting`, `healthy`, `degraded`, `failed`. Status is set via the existing private helper `_setStatus(BackendStatus ...)`. Logging uses the existing `AppLogger()` with `.info(...)` / `.error(...)` methods (already imported in this file). `debugPrint` is also already imported and used.

`startSupervised()` body (lines ~417–427) and `retryManually()` body (lines ~430–441) both contain this reset block — you will extend it:

```dart
    _manualStop = false;
    _consecutiveFailures = 0;
    _restartCount = 0;
    _windowStart = null;
    _setStatus(BackendStatus.starting);
    await _ensureRunning();
    _startWatchdog();
```

Watchdog and tick, lines ~444–478:

```dart
  /// Bật vòng giám sát health định kỳ (idempotent).
  static void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(_watchdogInterval, (_) => _tick());
  }

  /// Một nhịp watchdog: kiểm tra /health, chịu đựng một lần lỡ, lỗi liên tiếp
  /// quá ngưỡng thì kích hoạt khởi động lại.
  static Future<void> _tick() async {
    if (_manualStop || _ensuring) return;
    // Circuit đang mở → ngưng auto-restart, chờ retryManually().
    if (status.value == BackendStatus.failed) return;

    final port = _activePort ?? _defaultPort;
    final healthy = await _probeHealth(port);
    if (healthy) {
      _consecutiveFailures = 0;
      _isRunning = true;
      // Ổn định đủ lâu → reset circuit breaker.
      if (_windowStart != null &&
          DateTime.now().difference(_windowStart!) > _circuitWindow) {
        _windowStart = null;
        _restartCount = 0;
      }
      _setStatus(BackendStatus.healthy);
      return;
    }

    _consecutiveFailures++;
    if (_consecutiveFailures < _failureThreshold) {
      _setStatus(BackendStatus.degraded);
      return; // chịu đựng một lần lỡ tạm thời
    }
```

(the tick then falls through to call `await _ensureRunning();`).

Inside `_ensureRunning()` (lines ~482–541) the circuit-open branch looks like this — you will add one line to it:

```dart
      if (_restartCount >= _maxRestartsPerWindow) {
        _lastStartupError =
            'Backend khởi động lại thất bại $_restartCount lần liên tiếp '
            '(circuit breaker mở). Vui lòng thử lại thủ công.';
        AppLogger().error('ZaloBackendManager: $_lastStartupError');
        _setStatus(BackendStatus.failed);
        return;
      }
```

`_probeHealth(int port)` is a private static method near line 584 that performs an HTTP GET on `/health` with a `.timeout(const Duration(seconds: 2))` — this `Duration(seconds: 2)` inside `_probeHealth` is the probe timeout you will raise to 5 seconds. (Do NOT confuse it with the 3-second timeout inside `waitUntilReady`, which stays unchanged.)

Inside `waitUntilReady({Duration timeout = const Duration(seconds: 20)})` (lines ~321–379) there is this exit-listener registration — it has a stale-listener race (a listener registered on an OLD process object fires later and corrupts the state of a NEW start attempt):

```dart
    _backendExited = false;
    _backendProcess?.exitCode.then((code) {
      _backendExited = true;
      _isRunning = false;
      _lastStartupError = 'Tiến trình backend đã thoát sớm với mã $code.';
      AppLogger().error('ZaloBackendManager: $_lastStartupError');
    });
```

### D. `integration/zalo-bot-service/src/server.ts`

End of file, lines 1189–1201 (current):

```ts
process.on('SIGINT', () => {
  void shutdown();
});
process.on('SIGTERM', () => {
  void shutdown();
});

// Safety net: a single unhandled async error (e.g. a dead Zalo session thrown
// from deep inside zca-js) must never crash the whole service and take down the
// listeners of every other account. Log and keep running.
process.on('unhandledRejection', (reason) => {
  console.error('[server] Unhandled promise rejection (kept alive):', reason);
});
```

There is currently **no** `uncaughtException` handler anywhere in `integration/zalo-bot-service/src/`.

Backend npm scripts (from `integration/zalo-bot-service/package.json`): `npm test` (build + run tests), `npm run bundle` (esbuild → `dist/server.cjs`, which is the file shipped in packaged releases).

### E. Test wiring facts (for Step 2)

- `LiveChatRepository` is constructed in `lib/features/messaging/live_chat/providers/live_chat_provider.dart` (provider `liveChatRepositoryProvider`, line 27) with named parameters including `localFirstEnabled:`, `cache:`, `localApi:`, `mode:`, and `sseClient:`. Open that provider once to copy the exact constructor parameter list — construct your test instance the same way, passing `sseClient: null` if the parameter exists and is nullable.
- `LiveChatCache` (in `lib/features/messaging/live_chat/data/live_chat_cache.dart`) has a default constructor and is lazy — constructing it does NOT touch the database, so it is safe in a unit test as long as no cache method is called. `watchEvents` never calls the cache.
- `Stream.empty()` completes with `done` immediately and never emits an error. A real `localApi.watchEvents` pointed at an unreachable port emits a connection **error**. The regression test distinguishes the two.
- Existing tests live in `test/` and run with `flutter test`.

---

## Clarified Decisions / Assumptions

1. Circuit-breaker auto-retry cooldown: **5 minutes** (`Duration(minutes: 5)`). Manual "Thử lại" button behavior is unchanged.
2. Probe timeout **5s**, failure threshold **3**. Watchdog interval stays 5s; a re-entrancy guard prevents overlapping ticks now that a probe can take as long as the interval.
3. SSE inactivity timeout: **60 seconds** with no incoming data ⇒ treat stream as dead (throw), letting the existing notifier reconnect logic take over.
4. `uncaughtException` policy: **log and keep the process alive** — consistent with the existing `unhandledRejection` stance and its comment rationale.
5. Desktop (`_preferLocalZaloActions == true`) always opens the local SSE stream regardless of the `localFirstLiveChat` setting — mirroring how every other local action in the repository is already gated.

## No-Placeholder Contract

This phase must implement working behavior, not just scaffolding. Do not leave TODO-only code, empty functions/classes, `NotImplemented`, mock returns, fake sample data, or handlers without real integration.

## Deferred Work

None.

---

## Steps

### Step 1 — Fix the realtime gate in `LiveChatRepository.watchEvents`

- **File:** `lib/features/messaging/live_chat/data/live_chat_repository.dart`
- **Location anchor:** Inside the method `Stream<LiveChatEvent> watchEvents({String? accountId, String? threadId})`, the line reading exactly `if (!localFirstEnabled) return const Stream.empty();`
- **Action:** Replace that single line with:

```dart
    if (!_preferLocalZaloActions && !localFirstEnabled) {
      return const Stream.empty();
    }
```

- **Do NOT:** change the `cloudRemote` branch above it, the `localApi.watchEvents(...)` call below it, or any other method in this file. Do not rename `localFirstEnabled` or `_preferLocalZaloActions`.
- **Verify:** `flutter analyze` reports no new issues. `Select-String -Path "lib\features\messaging\live_chat\data\live_chat_repository.dart" -Pattern "_preferLocalZaloActions && !localFirstEnabled"` prints exactly one match.

### Step 2 — Regression test for the gate

- **File:** `test/live_chat_repository_watch_events_test.dart` (new file)
- **Location anchor:** new file.
- **Action:** First open `lib/features/messaging/live_chat/providers/live_chat_provider.dart` and copy the exact named-argument list used to construct `LiveChatRepository` in `liveChatRepositoryProvider` (line ~27). Then create the test. Skeleton (adapt ONLY the constructor arguments to the real signature; keep the assertions as written):

```dart
import 'package:flutter_test/flutter_test.dart';

// Adjust these imports to the package name in pubspec.yaml (check `name:` in
// tools/alpha-crm/pubspec.yaml, e.g. `package:alpha_crm/...`).
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_cache.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_local_bridge_api.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_repository.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_transport.dart';

void main() {
  test(
    'watchEvents opens local SSE on desktop even when localFirstEnabled is false',
    () async {
      final repository = LiveChatRepository(
        // Copy the real constructor arguments from liveChatRepositoryProvider.
        // The three that matter for this test:
        localFirstEnabled: false,
        mode: LiveChatTransportMode.localBridge,
        localApi: LiveChatLocalBridgeApi(baseUrl: 'http://127.0.0.1:1'),
        cache: LiveChatCache(),
      );

      // Before the fix this returned Stream.empty() => immediate clean `done`.
      // After the fix it must ATTEMPT the local SSE connection, which fails
      // against the unreachable port 1 with a connection error.
      await expectLater(
        repository.watchEvents(),
        emitsError(anything),
      );
    },
    // On desktop test runners _preferLocalZaloActions is true; this test is
    // meaningless on web.
    skip: false,
  );
}
```

  Notes for the Builder: if `_preferLocalZaloActions` in the repository is derived from `kIsWeb`/`defaultTargetPlatform`, the default `flutter test` runner (desktop VM) already satisfies "desktop". If the repository constructor requires additional required parameters (e.g. `sseClient`), pass `null` for nullable ones — copy exactly what the provider does.
- **Do NOT:** modify `LiveChatRepository` to make the test pass, add mocking packages, or touch other test files.
- **Verify:** `flutter test test/live_chat_repository_watch_events_test.dart` → `All tests passed!`.

### Step 3 — SSE inactivity timeout in the local bridge client

- **File:** `lib/features/messaging/live_chat/data/live_chat_local_bridge_api.dart`
- **Location anchor:** Inside `Stream<LiveChatEvent> watchEvents(...) async*`, the `await for` loop shown in Context Pack B.
- **Action:** Add a 60-second inactivity timeout on the decoded line stream. Replace the `await for` block with:

```dart
      final decoder = LiveChatSseDecoder();
      // Backend gửi ": heartbeat" mỗi 20s — quá 60s không có dữ liệu nghĩa là
      // socket đã chết im lặng; ném lỗi để notifier reconnect.
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 60));
      await for (final line in lines) {
        for (final event in decoder.addLine(line)) {
          yield event;
        }
      }
```

  (`Stream.timeout` without an `onTimeout` callback injects a `TimeoutException` as a stream error; the `await for` rethrows it; the generator's `finally` still runs `client.close()`; the notifier's `onError` handler schedules a reconnect. `TimeoutException` is exported by `dart:async`, which async generators already have implicitly — but if the analyzer complains about anything, add `import 'dart:async';` at the top of the file.)
- **Do NOT:** change request headers, the status-code check, the `finally` block, or any other method in this file. Do not add a timeout to `getLocalHealth` or other REST calls.
- **Verify:** `flutter analyze` clean. `Select-String -Path "lib\features\messaging\live_chat\data\live_chat_local_bridge_api.dart" -Pattern "timeout\(const Duration\(seconds: 60\)\)"` prints one match.

### Step 4 — Supervisor tolerance: probe timeout 5s, threshold 3, tick re-entrancy guard

- **File:** `lib/shared/utils/zalo_backend_manager.dart`
- **Action (three sub-edits, all in this file):**
  1. In the constants block (Context Pack C), change `static const int _failureThreshold = 2;` to `static const int _failureThreshold = 3;` and update its doc comment to `/// Số nhịp health-check lỗi liên tiếp trước khi coi backend là chết.` (unchanged text is fine — only the value changes).
  2. Inside the private method `_probeHealth` (near line 584): change its `.timeout(const Duration(seconds: 2))` to `.timeout(const Duration(seconds: 5))`. This is the ONLY `Duration(seconds: 2)` inside `_probeHealth`. Do NOT touch the 3-second timeout inside `waitUntilReady`.
  3. Add a re-entrancy guard so ticks cannot overlap now that one probe can take up to 5s (equal to `_watchdogInterval`). Below the existing field `static bool _ensuring = false;` add:

```dart
  /// Một nhịp watchdog đang chạy — probe có thể kéo dài bằng cả chu kỳ.
  static bool _ticking = false;
```

  Then wrap the entire body of `_tick()`:

```dart
  static Future<void> _tick() async {
    if (_ticking) return;
    _ticking = true;
    try {
      // ...toàn bộ thân hàm _tick hiện tại, giữ nguyên...
    } finally {
      _ticking = false;
    }
  }
```

  Keep every existing statement of the current body intact inside the `try`, including all `return`s (they now exit through the `finally`, which is correct).
- **Do NOT:** change `_watchdogInterval`, `_maxRestartsPerWindow`, `_circuitWindow`, `_maxBackoff`, or any spawn/kill logic.
- **Verify:** `flutter analyze` clean. `flutter test test/zalo_backend_manager_port_policy_test.dart` passes (existing test, must not regress).

### Step 5 — Circuit breaker auto-retry after 5-minute cooldown

- **File:** `lib/shared/utils/zalo_backend_manager.dart`
- **Action (four sub-edits):**
  1. In the constants block, after `static const Duration _maxBackoff = Duration(seconds: 30);` add:

```dart
  /// Circuit mở → tự thử lại sau cooldown này (retryManually() vẫn dùng được).
  static const Duration _circuitCooldown = Duration(minutes: 5);
```

  2. After the field `static DateTime? _windowStart;` add:

```dart
  static DateTime? _circuitOpenedAt;
```

  3. Inside `_tick()` (now inside the `try` from Step 4), replace the two lines

```dart
    // Circuit đang mở → ngưng auto-restart, chờ retryManually().
    if (status.value == BackendStatus.failed) return;
```

  with:

```dart
      // Circuit đang mở → chờ hết cooldown rồi tự thử lại một chu kỳ mới;
      // retryManually() vẫn cho phép thử lại ngay lập tức.
      if (status.value == BackendStatus.failed) {
        final openedAt = _circuitOpenedAt;
        if (openedAt == null ||
            DateTime.now().difference(openedAt) < _circuitCooldown) {
          return;
        }
        AppLogger().info(
          'ZaloBackendManager: circuit cooldown '
          '${_circuitCooldown.inMinutes} phút đã hết — tự thử khởi động lại.',
        );
        _circuitOpenedAt = null;
        _consecutiveFailures = 0;
        _restartCount = 0;
        _windowStart = null;
        _setStatus(BackendStatus.restarting);
        await _ensureRunning();
        return;
      }
```

  4. In `_ensureRunning()`, in the circuit-open branch (Context Pack C), add `_circuitOpenedAt = DateTime.now();` immediately BEFORE the line `_setStatus(BackendStatus.failed);`. And in BOTH `startSupervised()` and `retryManually()`, extend the reset block by adding `_circuitOpenedAt = null;` right after `_windowStart = null;`.
- **Do NOT:** change the `failed`-status UI banner (`backend_status_banner.dart`), the meaning of `retryManually()`, or the `_maxRestartsPerWindow` logic.
- **Verify:** `flutter analyze` clean. `Select-String -Path "lib\shared\utils\zalo_backend_manager.dart" -Pattern "_circuitOpenedAt"` prints at least 5 matches (declaration, cooldown check, null-reset in tick, set-on-open, resets in startSupervised/retryManually).

### Step 6 — Fix stale exit-listener race in `waitUntilReady`

- **File:** `lib/shared/utils/zalo_backend_manager.dart`
- **Location anchor:** Inside `waitUntilReady`, the block shown at the end of Context Pack C (`_backendExited = false;` followed by `_backendProcess?.exitCode.then(...)`).
- **Action:** Capture the process reference and ignore the callback if a different process has since been spawned. Replace the block with:

```dart
    _backendExited = false;
    final watchedProcess = _backendProcess;
    watchedProcess?.exitCode.then((code) {
      // Listener của tiến trình cũ (đã bị kill trong một chu kỳ restart) không
      // được phép phá trạng thái của lần khởi động mới.
      if (!identical(watchedProcess, _backendProcess)) return;
      _backendExited = true;
      _isRunning = false;
      _lastStartupError = 'Tiến trình backend đã thoát sớm với mã $code.';
      AppLogger().error('ZaloBackendManager: $_lastStartupError');
    });
```

- **Do NOT:** change the polling loop below it, the 3-second HTTP timeout, or the 20-second overall timeout default.
- **Verify:** `flutter analyze` clean; `flutter test` (full suite) passes.

### Step 7 — Backend `uncaughtException` handler + rebuild bundle

- **File:** `integration/zalo-bot-service/src/server.ts`
- **Location anchor:** End of file, immediately AFTER the existing `process.on('unhandledRejection', ...)` block quoted in Context Pack D.
- **Action:** Append:

```ts

// Safety net: a synchronous uncaught exception (e.g. thrown inside a zca-js
// listener callback or a timer) must not kill the listeners of every other
// account. Log and keep running; the Flutter supervisor restarts the process
// if it truly dies.
process.on('uncaughtException', (err) => {
  console.error('[server] Uncaught exception (kept alive):', err);
});
```

  Then rebuild so the packaged release picks it up. In PowerShell:

```powershell
cd D:\Dev\NodeJS\alpha-studio\tools\alpha-crm\integration\zalo-bot-service
npm test
npm run bundle
```

- **Do NOT:** add `process.exit` calls, change the `unhandledRejection` handler, or touch `shutdown()`/signal handlers. Do not commit `dist/` changes unless the repo already tracks them (check `git status` — if `dist/server.cjs` is gitignored, leave it out of the commit).
- **Verify:** `npm test` passes. `Select-String -Path "src\server.ts" -Pattern "uncaughtException"` prints one match. After `npm run bundle`, `Select-String -Path "dist\server.cjs" -Pattern "uncaughtException"` prints at least one match.

### Step 8 — Documentation updates (mandatory in this repo)

- **Files:** `.claude/IMPORTANT_FIXED_BUGS.md` and `.claude/PROJECT_SUMMARY.md`
- **Action:**
  1. Add a new entry at the TOP of the entries in `.claude/IMPORTANT_FIXED_BUGS.md`, dated 2026-07-04, following the existing entry format in that file. Content to convey (write it in the same style/language as neighboring entries):
     - **Bug:** Desktop production never opened the Live Chat local SSE stream because `LiveChatRepository.watchEvents` gated on `localFirstEnabled` alone (`localFirstLiveChat` defaults to false and has no UI toggle), while every other local action used `_preferLocalZaloActions || localFirstEnabled`. All realtime updates silently degraded to the 12s polling timer inside `LiveChatScreen`, which is disposed when the tab is not active → no new-message detection with the tab closed. Same bug class as the earlier "Bot toggle" fix. **Fix:** gate is now `if (!_preferLocalZaloActions && !localFirstEnabled) return const Stream.empty();` + regression test `test/live_chat_repository_watch_events_test.dart`. **Rule to remember:** any new local-bridge capability must use the `_preferLocalZaloActions || localFirstEnabled` pattern, never `localFirstEnabled` alone.
     - Also briefly note the supervisor hardening in the same entry or a second entry: probe timeout 2s→5s, threshold 2→3, tick guard, circuit auto-retry after 5-minute cooldown, stale exit-listener fix, backend `uncaughtException` safety net.
  2. In `.claude/PROJECT_SUMMARY.md`: update the description line for `lib/shared/utils/zalo_backend_manager.dart` to reflect the new supervisor behavior (probe 5s timeout / 3-miss threshold / circuit auto-retry 5 min cooldown), and the Live Chat transport note to say desktop always opens local SSE regardless of `localFirstLiveChat`. Update the session number at the top per the file's own convention. Do NOT add changelog-style prose — the file reflects current state only.
- **Do NOT:** rewrite unrelated sections of either doc.
- **Verify:** Both files contain the new content (`Select-String -Path ".claude\IMPORTANT_FIXED_BUGS.md" -Pattern "watchEvents"` prints a match).

---

## Validation Plan

Preflight (before any edit):

```powershell
cd D:\Dev\NodeJS\alpha-studio\tools\alpha-crm
flutter analyze          # expect: current baseline (note any pre-existing issues)
flutter test             # expect: current suite green — record baseline
```

After all steps:

```powershell
cd D:\Dev\NodeJS\alpha-studio\tools\alpha-crm
flutter analyze          # expect: no NEW issues vs baseline
flutter test             # expect: all pass, including the new watch_events test
cd integration\zalo-bot-service
npm test                 # expect: pass
npm run bundle           # expect: dist/server.cjs rebuilt, contains uncaughtException
```

Manual smoke (optional but recommended): `flutter run -d windows`, log in, open Live Chat once, then navigate to another tab and send a Zalo message to the connected account from a phone — a desktop notification/unread badge must appear within ~2 seconds without reopening the Live Chat tab.

Placeholder scan (mandatory): search all touched files for `TODO`, `stub`, `placeholder`, `NotImplemented`, empty handlers, hardcoded fake data:

```powershell
Get-ChildItem "lib\features\messaging\live_chat\data\live_chat_repository.dart","lib\features\messaging\live_chat\data\live_chat_local_bridge_api.dart","lib\shared\utils\zalo_backend_manager.dart","integration\zalo-bot-service\src\server.ts","test\live_chat_repository_watch_events_test.dart" | Select-String -Pattern "TODO|stub|placeholder|NotImplemented"
```

Expect: no matches introduced by this change.

## Dependencies

None — single phase. Steps 4–6 touch the same file and must be applied in order. Step 2 depends on Step 1. Step 7 is independent. Step 8 is last.
