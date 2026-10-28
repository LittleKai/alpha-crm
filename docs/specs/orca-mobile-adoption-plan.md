# Orca Mobile Feature Evaluation & Adoption Plan for Alpha CRM

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

---

## Part I — Direct Source Evaluation of `_tmp/orca/mobile` for Alpha CRM (Scale `/10`)

### 1. Architectural Comparison (`_tmp/orca` vs. `alpha-crm`)

| Dimension | Orca Mobile (`_tmp/orca/mobile`) | Alpha CRM Mobile (`lib/`) | Compatibility Assessment |
|---|---|---|---|
| **Core Role** | Mobile companion app steering a Desktop Host that holds local CLI/PTY sessions (`Claude`, `Codex`) | Android companion app (`LiveChatTransportMode.cloudRemote`) steering a paired Windows Desktop Agent that holds local `zca-js` Zalo sessions & SQLite | **9.5 / 10** — Identical "Mobile Companion ↔ Paired Desktop Host" topology |
| **UI Stack** | React Native 0.83 + Expo 55 + Zustand (`_tmp/orca/mobile/package.json`) | Flutter 3 / Dart 3.10.7 + Riverpod (`pubspec.yaml`) | **Patterns portable, UI code must be written in Flutter/Dart** |
| **Transport** | Direct LAN WebSocket + Cloud Relay WebSocket (`cloud/apps/relay`) with NaCl X25519/XSalsa20-Poly1305 E2EE (`_tmp/orca/mobile/src/transport/e2ee.ts`) | HTTPS REST (`CrmCloudApi`) + Server-Sent Events (`CrmSseClient` -> `/api/v1/crm/events`) + Windows Desktop Agent heartbeat (`agent-runner.ts`) | Keep Alpha CRM's SSE + REST architecture; port Orca's **transport resilience, watchdog, calm status reveal, and diagnostics** |
| **Pairing** | QR Scan + 6-digit code / deep link `orca://pair?code=...` (`_tmp/orca/mobile/src/transport/pairing.ts`) | QR Scan (`MobileScanner`) + 6-digit code (`DevicePairingScreen` + `buildPairingConfirmPayload`) | **8.8 / 10** — Direct functional match; Orca's URL/code normalizer & post-pair host status UX directly upgrade Alpha CRM |

---

### 2. Feature-by-Feature Scoring Table (10-Point Scale)

| # | Orca Mobile Feature & Source Files Inspected | Score (/10) | Verdict | Detailed Rationale & Impact on Alpha CRM |
|---|---|---|---|---|
| **1** | **Calm Connection Status Reveal (Anti-Flicker Banner State Machine)**<br>• `_tmp/orca/src/shared/calm-status-reveal.ts` (`stepCalmStatusReveal`, `CALM_STATUS_REVEAL_DELAY_MS = 5000`, `CALM_STATUS_MIN_VISIBLE_MS = 2000`, `CALM_STATUS_HEALTHY_HOLD_MS = 1000`)<br>• `_tmp/orca/mobile/src/transport/calm-connection-state.ts` (`stepCalmConnectionState`) | **9.5 / 10** | **ADOPT** | **Problem in Alpha CRM:** `lib/features/messaging/live_chat/providers/agent_status_provider.dart` sets `sseConnected = false` on the exact millisecond an SSE stream drops or resumes from background, causing `live_chat_screen.dart` (line 1567 / 1854) to flash the `"Đang kết nối lại..."` banner and shift the message list layout during 300ms–2s network handoffs.<br>**Impact:** Porting `CalmStatusReveal` into `agent_status_provider.dart` suppresses transient `<5s` SSE reconnect blips after a healthy connection while still surfacing initial connects, auth failures, and real Desktop Agent outages immediately. |
| **2** | **SSE Idle Watchdog, Connection Revival & Manual Reconnect Nudge**<br>• `_tmp/orca/mobile/src/transport/connection-revival-triggers.ts` (`subscribeConnectionRevivalTriggers`)<br>• `_tmp/orca/mobile/src/transport/socket-deadline-clock.ts` (`createSocketDeadlineClock`)<br>• `_tmp/orca/mobile/src/transport/connection-health.ts` (`classifyConnection`) | **9.2 / 10** | **ADOPT** | **Problem in Alpha CRM:** `lib/shared/api/crm_sse_client.dart` reads `response.stream` with **no idle timeout** (unlike `live_chat_local_bridge_api.dart`, which fixed silent half-open TCP hangs in Bug #2 of `.claude/IMPORTANT_FIXED_BUGS.md` with a 60s timeout). Cloud sends `: ping` every 25s; if Android switches Wi-Fi ↔ 4G/5G, the socket can hang in `SseConnectionState.connected` indefinitely without firing `onDone`.<br>**Impact:** Adding a configurable idle watchdog (default `65s`, >2.5x server 25s ping) plus `reconnectNow({String reason})` and tracking `reconnectAttempts` / `lastConnectedAt` eliminates silent zombie SSE streams on mobile. |
| **3** | **Bounded Redacted Connection Log & Automated Troubleshoot Diagnostics**<br>• `_tmp/orca/mobile/src/transport/connection-log-buffer.ts` (`createConnectionLogStore`, `MAX_ENTRIES_PER_HOST = 200`)<br>• `_tmp/orca/mobile/src/diagnostics/connection-log-redaction.ts` (`redactConnectionLogText`)<br>• `_tmp/orca/mobile/src/diagnostics/connection-diagnostics-analysis.ts` (`diagnoseConnection`)<br>• `_tmp/orca/mobile/src/diagnostics/use-troubleshoot-diagnostics.ts` & `app/connection-log.tsx` | **9.0 / 10** | **ADOPT** | **Problem in Alpha CRM:** Windows has `BackendSplashOverlay` log copy, but Android (`cloudRemote`) has zero visibility when SSE, Pairing, or Desktop Agent fails.<br>**Impact:** Adding a bounded (100-entry) redacted ring buffer in `CrmSseClient`, a pure `diagnoseMobileConnection()` analyzer (`likelyCause` + `nextStep` in Vietnamese), and a `showMobileConnectionDiagnosticsDialog()` (`AppDialog`) with 1-tap redacted report copy and manual reconnect brings Orca-grade self-service troubleshooting to Alpha CRM Mobile. |
| **4** | **Host / Agent Version & Protocol Compatibility Evaluation**<br>• `_tmp/orca/src/shared/protocol-version.ts` (`ORCA_PROTOCOL_VERSION`)<br>• `_tmp/orca/mobile/src/transport/protocol-compat.ts` (`evaluateCompat`)<br>• `_tmp/orca/mobile/src/components/ProtocolBlockScreen.tsx` | **8.8 / 10** | **ADOPT (Warn Mode)** | **Problem in Alpha CRM:** `zalo-bot-service/src/cloud/agent-runner.ts` already reports `appVersion` and `agentVersion` in every heartbeat, and cloud SSE `hello` / `device.status` events forward device metadata, but `AgentDeviceStatus` in `agent_status_provider.dart` drops `appVersion` and `agentVersion`.<br>**Impact:** Parsing `appVersion`/`agentVersion` in `AgentDeviceStatus` and evaluating version compatibility (`evaluateAgentVersionCompat`) lets Mobile warn the user when the Windows Desktop Agent is outdated relative to the mobile app. |
| **5** | **Pairing Input Normalization (`alphacrm://pair`, hyphenated codes) & Live Host Health on Pairing Screen**<br>• `_tmp/orca/mobile/src/transport/pairing.ts` (`extractPairingCodeFromUrl`, `parsePairingCode`)<br>• `_tmp/orca/mobile/app/pair-scan.tsx` & `app/pair-confirm.tsx` | **8.5 / 10** | **ADOPT** | **Problem in Alpha CRM:** `buildPairingConfirmPayload()` in `crm_device_provider.dart` only strips spaces (`123 456`), failing on hyphenated codes (`123-456`), deep-link URLs (`alphacrm://pair?code=...` or `?token=...`), or JSON with `qrToken`. Furthermore, `DevicePairingScreen` on Android shows a static `"Sẵn sàng hoạt động"` badge when paired, even if the Desktop PC is offline or its Zalo session is expired.<br>**Impact:** Normalizing all QR/code/deep-link formats, adding a 1-tap `"Dán mã"` (Paste clipboard) button, and showing live Desktop Agent status (`online`, `lastHeartbeatAt`, `worstZaloHealth`, `appVersion`) + `"Chẩn đoán kết nối"` on `DevicePairingScreen`. |
| **6** | **Structured Outbox / Send Guard Feedback**<br>• `_tmp/orca/mobile/src/session/use-mobile-structured-sends.ts` | **7.5 / 10** | **PARTIAL (Already 80% in Alpha CRM)** | Alpha CRM already disables composer buttons when `!isAccountConnected` and shows `remoteBlockedReason` (`live_chat_screen.dart:1556-1570`). Enhancing that banner with calm SSE status, version mismatch notice, and direct action buttons (`"Chẩn đoán"` / `"Kết nối lại"`) completes the pattern without duplicating `LiveChatNotifier.sendMessage`. |
| **7** | **LAN Direct WebSocket + Cloud Relay NaCl E2EE Stack**<br>• `_tmp/orca/mobile/src/transport/e2ee.ts`, `lan-client.ts`, `relay-client.ts`, `pre-profile-pairing-coordinator.ts` | **2.0 / 10** | **REJECT** | Alpha CRM already has a production NestJS cloud backend (`alpha-studio-backend`) with JWT auth, MongoDB message metadata sync, and SSE (`/crm/events`). Replacing SSE with a custom stateful WebSocket relay (`cloud/apps/relay`) and client-side NaCl key exchange would break multi-device history sync and violate YAGNI. |
| **8** | **Mobile Terminal WebView (`xterm.js`), Git Diff Viewer & File Tree Browser**<br>• `_tmp/orca/mobile/src/terminal/TerminalWebView.tsx`, `app/git.tsx`, `app/files.tsx` | **1.0 / 10** | **REJECT** | Domain-specific to an AI coding IDE. Alpha CRM is a multi-channel customer messaging & sales CRM; terminal emulation and git diffs have zero business relevance. |

### Overall Suitability Score: **7.8 / 10**
- **Mobile Companion Resilience, Diagnostics & Pairing UX Layer:** **9.0 / 10** (Directly solves real mobile edge cases in Alpha CRM).
- **IDE-specific & Custom Relay Layer:** **1.5 / 10** (Skipped per Ponytail/YAGNI).

> **Review note (Part III):** Scores for #1–#6 were re-checked against the code and the cloud backend. Item #4 is downgraded to **DEFER** because the version fields never reach the mobile app and the two version numbers are not comparable. See Part III §3 for the revised scores. Part II below is the revised, authoritative plan.

---

## Part II — Implementation Plan (revised by Claude Code review, 2026-10-28)

**Goal:** Make the Android (`cloudRemote`) companion more reliable, make pairing easier, and give users self-service troubleshooting. Port the highest-scoring Orca Mobile transport and UX patterns into Flutter/Riverpod.

**Architecture:**
1. **`CrmSseClient` (`lib/shared/api/crm_sse_client.dart`)**:
   - Add one watchdog timer. It covers the connect phase (`connectTimeout`, default 20s) and the open stream (`idleTimeout`, default 65s, more than 2.5x the 25s server ping in `alpha-studio-backend/server/utils/crmEventHub.js`).
   - Add a connection generation counter so a stale attempt can never change shared state.
   - Make `resume()` idempotent. Add `reconnectNow({String reason})`.
   - Add connection metadata: `reconnectAttempts`, `lastConnectedAt`, `lastError`, `lastHttpStatus`, `isPaused`.
   - Add a bounded log of lifecycle entries only (100 entries). Every entry is scrubbed by `redactConnectionLogText()`.
2. **`lib/features/messaging/live_chat/utils/mobile_connection_diagnostics.dart`**: pure Dart, no widgets.
   - `CalmStatusReveal` + `stepCalmStatusReveal(...)`: a literal port of `_tmp/orca/src/shared/calm-status-reveal.ts`. Constants: reveal delay 5s, minimum visible 2s, healthy hold 1s.
   - `MobileConnectionSnapshot`, `diagnoseMobileConnection(...)`, `buildRedactedDiagnosticsReport(...)`.
   - Version compatibility is **display-only** in this plan. `evaluateAgentVersionCompat` is deferred (see Part III §2.5).
3. **`AgentStatusNotifier` (`agent_status_provider.dart`)**:
   - Parse `appVersion` / `agentVersion` as nullable fields for forward compatibility.
   - Drive `AgentStatusState.showReconnectBanner` from the calm state machine. Keep raw `sseConnected` unchanged for diagnostics.
   - Reset the calm clock while the client is paused (app in background).
4. **Pairing & diagnostics UI**:
   - `normalizePairingInput()` in `crm_device_provider.dart` is the single source of truth. The validator, the submit path and `buildPairingConfirmPayload()` all use it.
   - The Android branch of `DevicePairingScreen` (`_buildPairedState` + unpaired client form) gets a paste button and a live Desktop Agent status row.
   - `showMobileConnectionDiagnosticsDialog()` (`showDialog` + `AppDialog`) is opened from the Live Chat `cloudRemote` banners and from the pairing screen.

**Tech Stack:** Flutter 3 / Dart 3.10.7, `flutter_riverpod` (`StateNotifierProvider`), `http` 1.6 (`package:http/testing.dart` `MockClient.streaming` for tests), `flutter_test`, `fake_async` (add to `dev_dependencies`; today it is only transitive, so importing it directly fails `depend_on_referenced_packages`).

**Global Constraints (from `AGENTS.md`, `.claude/CONVENTIONS.md` and the actual code):**
- All files UTF-8 without BOM.
- Dialogs: follow the pattern the code really uses: `showDialog(context: context, builder: (dialogContext) => AppDialog(...))` from `lib/shared/widgets/app_dialog.dart`. Close with `Navigator.of(dialogContext).pop()`, or `Navigator.of(context).pop()` inside a widget that lives in the dialog route. `showStandardDialog` / `standard_dialog.dart` named in `AGENTS.md` and `CONVENTIONS.md` do not exist in `lib/` (doc drift, see Part III §2.6).
- UI text: the app has no i18n layer (no `.arb`, no `AppLocalizations`). All strings stay hard-coded Vietnamese, consistent with the existing screens. The `vi` + `en` rule in `AGENTS.md` cannot be met without new infrastructure; this is out of scope (Part III §5).
- Never put `Spacer` or `Expanded` directly inside `Wrap`. Use a `Row` with `Expanded`, or a `Column`.
- Never log, copy or display raw JWTs, `Bearer` tokens, `qrToken` (48 hex chars), `pairingToken`, the 6-digit `pairingCode`, cookies, emails or phone numbers.
- No periodic timers in widgets. Compute relative times at build time.
- Every `await` in a `State`/`ConsumerState` is followed by `if (!mounted) return;` before using `context`, `ref` or `setState`.
- Zero warnings on `flutter analyze`. All existing and new `flutter test` suites pass.
- The transport contract changes, so the Android release APK must be built and smoke-tested (`AGENTS.md` VERIFY). Windows must be checked for "no behaviour change in `localBridge` mode".

**Execution order:** Task 1, Task 2, Task 3, Task 4. Each task leaves the tree green. Task 3 does not reference the dialog; Task 4 adds all "Chẩn đoán" entry points.

---

### Task 1: SSE Watchdog, Generation Guard, Idempotent Resume, `reconnectNow` & Redacted Log (`CrmSseClient`)

**Files:**
- Modify: `lib/shared/api/crm_sse_client.dart`
- Modify: `test/crm_sse_client_test.dart` (keep the 7 existing `CrmSseDecoder` tests unchanged)
- Modify: `pubspec.yaml` (`dev_dependencies: fake_async`)
- Do not change: `lib/shared/api/crm_sse_provider.dart`. `CrmSseClient()` with no arguments must keep working.

**Real names to use (the first draft named symbols that do not exist):** the stream is read by an `await for` loop inside `_connect()`; there is no `_lineSub`, `_backoffAttempt`, `_active`, `_paused` or `_openConnection()`. Backoff state is `_reconnectAttempts` with `_reconnectDelaysSeconds = [1, 2, 5, 10]`. Token source is `CrmAuthTokenStore.getToken()`. Base URL is `CrmCloudApi.baseUrl`. Endpoint is `GET {baseUrl}/crm/events/subscribe`. An `await for` loop cannot be cancelled from a timer, so the watchdog must close the per-attempt `http.Client`.

- [x] **Step 1: Write failing tests in `test/crm_sse_client_test.dart`**
  Build the client with injected `httpClientFactory` (returning `MockClient.streaming` wrappers that count `send()` and `close()`), `tokenProvider: () async => 'test-token'`, and `baseUrlProvider: () => 'https://test.invalid/api'`. Use `fakeAsync` for all timer tests and assert `async.pendingTimers` is empty at the end.
  1. `redactConnectionLogText` scrubs `Bearer <jwt>`, `token=<v>`, `"qrToken":"<v>"`, `"pairingToken":"<v>"`, `"pairingCode":"123456"`, 48-char hex, long base64/JWT-shaped strings and emails. It keeps event names (`device.status`), `SSE HTTP 401` and durations readable.
  2. The log is bounded: 150 appended entries leave exactly `maxLogEntries` (100); the oldest are dropped. No entry contains `test-token`.
  3. Idle watchdog: the server sends headers then goes silent. After `idleTimeout` there is one `sse.idle_timeout` warn entry, the old client is closed, the state becomes `disconnected`, and the factory is called a second time after the backoff delay.
  4. Keep-alive: `: ping` comment lines arriving more often than `idleTimeout` keep the stream alive (no reconnect). The decoder ignores comments, so the watchdog must be reset on every raw line **before** `decoder.addLine`.
  5. Connect timeout: `send()` never completes. After `connectTimeout` there is one `sse.connect_timeout` entry and a reconnect is scheduled. `_connecting` does not stay `true` forever.
  6. `reconnectNow(reason: 'manual_test')` while connected closes the old client, opens exactly one new stream, and resets `reconnectAttempts` to 0. Two calls in a row still leave exactly one open client.
  7. Regression for a silent bug: `resume()` while already connected or connecting does nothing (factory call count unchanged). Today it opens a second stream and never closes the first.
  8. `pause()` cancels the watchdog and the reconnect timer. Time passing while paused creates no reconnect. `dispose()` leaves no pending timers and closes the controller.
  9. Generation guard: an old attempt that fails after `reconnectNow()` does not flip `_connecting`, does not change `connectionState`, and does not schedule a reconnect.
  10. HTTP 401/402/403: `lastHttpStatus` is set and the log entry level is `error`.
  11. `reconnectNow()` with no listeners or after `dispose()` is a no-op (no throw, no factory call).

- [x] **Step 2: Run the tests and confirm they fail**
  Run: `rtk flutter test test/crm_sse_client_test.dart`
  Expected: compile errors for the missing constructor parameters, `redactConnectionLogText`, `CrmConnectionLogEntry` and `reconnectNow`.

- [x] **Step 3: Implement in `lib/shared/api/crm_sse_client.dart`**
  - Add `enum CrmConnectionLogLevel { info, warn, error }` and an immutable `CrmConnectionLogEntry` (`timestamp`, `level`, `code`, `detail`).
  - Add top-level `String redactConnectionLogText(String input)`, inspired by `_tmp/orca/mobile/src/diagnostics/connection-log-redaction.ts`. It must be pure so Task 2 can reuse it.
  - Add optional named constructor parameters, all with production defaults:
    - `http.Client Function()? httpClientFactory` (default `http.Client.new`)
    - `Future<String?> Function()? tokenProvider` (default `CrmAuthTokenStore.getToken`)
    - `String Function()? baseUrlProvider` (default `() => CrmCloudApi.baseUrl`)
    - `Duration idleTimeout = const Duration(seconds: 65)`
    - `Duration connectTimeout = const Duration(seconds: 20)`
    - `int maxLogEntries = 100`
    - `DateTime Function()? clock` (default `DateTime.now`)
  - **Generation guard:** add `int _generation`. `_connect()` takes `final gen = ++_generation`. After every `await` (token, `send`, each stream line) it checks `if (_disposed || gen != _generation)`; if so it closes its own client and returns. Only the current generation may set `_connecting`, `connectionState`, `_reconnectAttempts`, `lastError`, or call `_scheduleReconnect()`. `_teardownConnection()` increments `_generation`.
  - **Watchdog:** one `Timer? _watchdogTimer`. Arm it with `connectTimeout` at the start of `_connect()`. Re-arm it with `idleTimeout` when headers arrive (HTTP 200) and on every raw line. When it fires (current generation only): log `sse.connect_timeout` or `sse.idle_timeout` (warn), call `_teardownConnection()` (this closes the client, so the old `await for` throws and is ignored by the guard), then `_scheduleReconnect()`. Cancel it in `_teardownConnection()`.
  - **Failure path:** on error in the current generation, close the failed client and set `_httpClient = null` before scheduling a reconnect. Today the failed client is never closed.
  - **`resume()`:** return early when `_disposed`, when there are no listeners, or when `_httpClient != null || _connecting`. Clear `_paused`, log `sse.resume`, reset `_reconnectAttempts`, call `_connect()`. Reason: `_CrmSseLifecycleObserver` calls `resume()` on every `AppLifecycleState.resumed`. Android also sends `inactive -> resumed` without `paused` (camera permission dialog for `MobileScanner`, notification shade). The backend keeps at most 5 streams per user and evicts the **oldest** (`crmEventHub.js`), so a leaked stream can disconnect the user's other device.
  - **`pause()`:** set `_paused = true`, log `sse.pause`, then `_teardownConnection()`.
  - **`reconnectNow({String reason = 'manual'})`:** if `_disposed` return. Log `sse.reconnect_now` (info, detail = reason). If no listeners, return. Otherwise clear `_paused`, `_teardownConnection()`, `_reconnectAttempts = 0`, `_connect()`.
  - **Exposed read-only API:** `int get reconnectAttempts`, `DateTime? get lastConnectedAt`, `String? get lastError` (redacted, max 200 chars), `int? get lastHttpStatus`, `bool get isPaused`, and `ValueListenable<List<CrmConnectionLogEntry>> get connectionLog`. The list is unmodifiable; a new list replaces it on every append so `ValueListenableBuilder` rebuilds.
  - **What to log (lifecycle only):** `sse.connect_start`, `sse.connected`, `sse.http_error` (status), `sse.error` (exception `runtimeType` + redacted message), `sse.stream_closed`, `sse.connect_timeout`, `sse.idle_timeout`, `sse.reconnect_scheduled` (delay), `sse.pause`, `sse.resume`, `sse.reconnect_now`. Never log headers, tokens, event payloads, `: ping` lines, or one entry per event. Otherwise `message.new` traffic would flush the buffer.
  - **`dispose()`:** keep the current order (`_disposed = true`, teardown, close controller). Do **not** dispose the `connectionState` / `connectionLog` notifiers. `AgentStatusNotifier.dispose()` calls `removeListener` on them, and Riverpod does not guarantee which provider is disposed first. A disposed `ValueNotifier` asserts in debug.

- [x] **Step 4: Run the tests and confirm they pass**
  Run: `rtk flutter test test/crm_sse_client_test.dart`
  Expected: PASS, with no pending timers reported.

---

### Task 2: Calm Status Reveal, Diagnostics Analyzer & `AgentStatusNotifier` Wiring

**Files:**
- Create: `lib/features/messaging/live_chat/utils/mobile_connection_diagnostics.dart`
- Modify: `lib/features/messaging/live_chat/providers/agent_status_provider.dart`
- Create: `test/mobile_connection_diagnostics_test.dart`
- Create: `test/agent_status_provider_test.dart`

- [x] **Step 1: Write failing tests**
  `test/mobile_connection_diagnostics_test.dart` (pure, no `fakeAsync` needed; pass `now` explicitly):
  1. `stepCalmStatusReveal`, one name used everywhere (the first draft mixed `CalmStatusRevealController`, `CalmSseStatusState` and `stepCalmSseStatus`):
     - Down at t=0 and healthy at t=2000ms: never visible; `recheckIn` at t=0 is 5000ms.
     - Down for 5000ms: visible. Healthy at t=5500ms: still visible until t=7000ms (2s minimum visible). Then idle.
     - Healthy, then down again within the 1s healthy hold: still the same outage (`downSince` unchanged, banner stays).
     - `immediate: true`: visible at once.
     - **Startup is not special.** The first connection gets the same 5s grace. The first draft revealed the banner at once before the first connection, which flashes "Đang kết nối lại..." on every Live Chat open.
  2. `diagnoseMobileConnection(MobileConnectionSnapshot)` returns `MobileConnectionDiagnosis { severity, title, likelyCause, nextStep, checks }` with this priority:
     1. transport is not `cloudRemote`: `info`, "Chỉ áp dụng cho điện thoại".
     2. not paired: advise scanning the QR or entering the 6-digit code.
     3. `lastHttpStatus` is 401: advise signing in again. 402/403: advise checking the subscription.
     4. SSE down and the banner is revealed: advise checking the network or tapping "Kết nối lại ngay"; mention `reconnectAttempts`.
     5. no snapshot yet: `info`, "Đang kiểm tra".
     6. Desktop Agent offline (`hasSnapshot && !anyDeviceOnline`): advise opening Alpha CRM on the Windows PC; include the last heartbeat time.
     7. Zalo session expired/logged out (`anyOnlineDeviceHasZaloIssue`): advise scanning the Zalo QR again on the PC.
     8. healthy.
     `checks` always has 4 rows: Pairing, Cloud connection (SSE), Desktop Agent heartbeat, Zalo session.
  3. `buildRedactedDiagnosticsReport(snapshot, logs, {mobileAppVersion})`: plain text, at most the 30 newest log lines, Desktop `agentVersion` shown only if present. A token planted in a log detail and in `lastError` never appears in the output.
  `test/agent_status_provider_test.dart` (`fakeAsync` + `ProviderContainer` with `crmSseClientProvider` overridden by a client built from Task 1 test doubles, and `liveChatTransportModeProvider` forced to `cloudRemote`):
  4. connected, then disconnected, then connected at +2s: `showReconnectBanner` never becomes `true`; `sseConnected` (raw) did flip.
  5. disconnected for 6s: `showReconnectBanner == true`.
  6. `client.pause()` while disconnected: banner `false`, no calm timer pending. After `resume()` the 5s grace starts from the resume time, not from the pause time. Without this, coming back from 2 minutes in background would show the banner at once.
  7. `container.dispose()` while the calm timer is pending: no exception, no `state =` after dispose, `async.pendingTimers` empty.
  8. A `hello` snapshot with `appVersion` / `agentVersion` fills the new nullable fields. Missing or empty values become `null`.

- [x] **Step 2: Run the tests and confirm they fail**
  Run: `rtk flutter test test/mobile_connection_diagnostics_test.dart test/agent_status_provider_test.dart`

- [x] **Step 3: Implement**
  - `mobile_connection_diagnostics.dart`: no Flutter widget imports. Import `redactConnectionLogText` and `CrmConnectionLogEntry` from `crm_sse_client.dart`. `CalmStatusReveal` stores milliseconds (`downSince`, `shownAt`, `healthySince`, all nullable) plus `static const idle`. `stepCalmStatusReveal(prev, {required bool down, required bool immediate, required int nowMs})` returns `CalmStatusStep { next, visible, Duration? recheckIn }`.
  - `AgentDeviceStatus`: add `final String? appVersion; final String? agentVersion;` (parse with `_nonEmptyString(json['appVersion'])`). Today the backend does not send these fields (Part III §2.5), so they stay `null`. That is expected; do not build UI logic that depends on them.
  - `AgentStatusState`: add `final bool showReconnectBanner` (const default `false`) and add it to `copyWith`. Do not try to "default to `sseConnected`"; a const constructor cannot do that.
  - `AgentStatusNotifier`:
    - Constructor `AgentStatusNotifier(this._client, {DateTime Function()? clock})`. The provider passes no clock.
    - Fields `CalmStatusReveal _calm = CalmStatusReveal.idle;` and `Timer? _calmTimer;`.
    - `_onConnectionStateChanged()`: `if (!mounted) return;` If `_client.isPaused`: cancel `_calmTimer`, set `_calm = idle`, set `showReconnectBanner: false` and `sseConnected: false`, return. Otherwise call `_applyCalmStep()`.
    - `_applyCalmStep()`: `down = connectionState != connected`, `immediate = lastHttpStatus in {401, 402, 403}`. Step the machine, write `sseConnected` and `showReconnectBanner` in one `state =`, cancel `_calmTimer`, and if `recheckIn != null` start `Timer(recheckIn, () { if (mounted) _applyCalmStep(); })`.
    - `dispose()`: cancel `_calmTimer` **first**, then remove the listener, cancel the subscription, then `super.dispose()`. The first draft said `ref.onDispose`; that is the wrong hook, because `StateNotifier` has no `ref`. The provider also rebuilds and disposes the old notifier when `liveChatTransportModeProvider` changes, and the timer must die with it.
    - When `_client == null` (desktop / `localBridge`): no listener, no timer, `showReconnectBanner` stays `false`.
  - Keep `anyDeviceOnline` / `anyOnlineDeviceHasZaloIssue` unchanged. While SSE is down they are stale; the diagnostics text says so.

- [x] **Step 4: Run the tests and confirm they pass**
  Run: `rtk flutter test test/mobile_connection_diagnostics_test.dart test/agent_status_provider_test.dart`

---

### Task 3: Pairing Input Normalization & Live Desktop Status on `DevicePairingScreen`

**Files:**
- Modify: `lib/features/devices/providers/crm_device_provider.dart`
- Modify: `lib/features/devices/presentation/screens/device_pairing_screen.dart`
- Modify: `test/crm_device_provider_test.dart` (keep the 5 existing tests unchanged)

**Facts from the code:** there is no `_MobilePairingView`. The Android UI is the `isClient` (`defaultTargetPlatform == TargetPlatform.android`) branch of `_DevicePairingScreenState`: `_buildPairedState()` plus the unpaired code form. The form validator (around line 605) rejects `123-456` (7 chars, not 6 digits, not 16+ chars), and `_submitPairingCode()` strips spaces before calling `confirmPairing()`. Because of this, normalization inside the provider alone is unreachable from the UI. The backend `qrToken` is 48 hex chars and the `pairingCode` is 6 digits; both are compared by SHA-256 hash in `POST /crm/pairing/confirm`.

- [x] **Step 1: Write failing tests in `test/crm_device_provider_test.dart`**
  1. Codes: `123-456`, ` 12 3-456 `, `123.456` give `{'pairingCode': '123456'}`.
  2. Rejected as codes (`normalizePairingInput` returns `null`): `-12345` and `+12345` (today `int.tryParse` accepts them as 6-char codes), `12345`, `1234567`.
  3. JSON: `{"type":"alpha_crm_pairing","pairingToken":"<48hex>"}` gives `{'qrToken': '<48hex>'}` (unchanged). `{"qrToken":"..."}` gives the same. `{"pairingCode":"654-321"}` or `{"code":"654321"}` gives `{'pairingCode': '654321'}`.
  4. Bug fix: `{"type":"alpha_crm_pairing","pairingToken":"123456"}` gives `{'pairingCode': '123456'}`. The desktop builds this QR when the backend returns no `qrToken` (`pairingToken: data['qrToken'] ?? data['pairingCode']`). Today the code is sent as `qrToken`, the hash never matches, and pairing always fails.
  5. URLs (only schemes `alphacrm`, `http`, `https`): `alphacrm://pair?code=654-321` and `https://host/pair?pairingCode=654321` give a code. `alphacrm://pair?qrToken=<48hex>` and `?token=<48hex>` give a `qrToken`. A URL with none of these parameters returns `null`. `orca://` is **not** supported (no producer in Alpha CRM).
  6. Fallback, kept for backward compatibility: any other single-line input of 16+ chars without spaces gives `{'qrToken': input}`. Input longer than 4096 chars returns `null`.
  7. `buildPairingConfirmPayload(input)` keeps its signature and returns `normalizePairingInput(input) ?? {'qrToken': input.trim()}`, so existing callers and tests do not change.

- [x] **Step 2: Run the tests and confirm they fail**
  Run: `rtk flutter test test/crm_device_provider_test.dart`

- [x] **Step 3: Implement**
  - `crm_device_provider.dart`: add top-level `Map<String, String>? normalizePairingInput(String raw)`. Order: trim and length cap; 6-digit code after removing `[\s\-.]` and matching `^\d{6}$`; JSON map; URI with an allowed scheme; 16+ char fallback. A token value that is itself 6 digits maps to `pairingCode`. Never log the input.
  - `device_pairing_screen.dart`:
    - Validator: `normalizePairingInput(value) == null` gives the error 'Mã ghép đôi gồm 6 chữ số, hoặc dán mã QR / đường dẫn ghép đôi.'
    - `_submitPairingCode()` passes the raw text (remove `.replaceAll(' ', '')`). The provider normalizes.
    - Unpaired Android form: add `OutlinedButton.icon(icon: Icons.content_paste_rounded, label: 'Dán mã')`. Handler: `final data = await Clipboard.getData(Clipboard.kTextPlain); if (!mounted) return;` If the text is empty, show the SnackBar 'Bộ nhớ tạm không có mã ghép đôi.' Otherwise set `_codeController.text` and move the cursor to the end. **Do not auto-submit**: `/crm/pairing/confirm` is rate-limited (`crmPairingLimiter`) and the clipboard may hold an old code. Layout: a `Row` with two `Expanded` buttons, or the paste button above "Ghép đôi" in the existing `Column`. No `Wrap` + `Expanded`.
    - Paired Android card (`_buildPairedState`, isClient branch): replace the static 'Sẵn sàng hoạt động' row with a `Consumer` that watches `liveChatTransportModeProvider` and `agentStatusProvider`. If the mode is not `cloudRemote`, keep the old static text. Select the device by `state.deviceId` (the PC `_id`; the SSE map keys are the same Mongo `_id` strings). Fall back to "any device online" when the id is missing. States, in priority order:
      - `showReconnectBanner`: 'Đang kết nối lại máy chủ...' (device data may be stale).
      - `!hasSnapshot`: 'Đang kiểm tra...'.
      - Zalo issue: 'Phiên Zalo trên máy tính đã hết hạn'.
      - offline: 'Máy tính đang ngoại tuyến' + 'Lần cuối: HH:mm dd/MM' (`intl` `DateFormat`, computed at build, no ticker).
      - online: 'Máy tính đang trực tuyến'.
      Show the Desktop agent version only when it is non-null.
    - `agentStatusProvider` is not `autoDispose` and Live Chat already keeps it alive, so watching it here opens no extra SSE stream (one shared client).
    - Do not add the "Chẩn đoán kết nối" button in this task (Task 4).
    - Out of scope, noted only: `simulateQrScanner()` creates a `TextEditingController` that is never disposed.

- [x] **Step 4: Run the tests and confirm they pass**
  Run: `rtk flutter test test/crm_device_provider_test.dart`

---

### Task 4: Diagnostics Dialog & Entry Points (Live Chat banners, pairing screen)

**Files:**
- Create: `lib/features/messaging/live_chat/presentation/widgets/mobile_connection_diagnostics_dialog.dart`
- Modify: `lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`
- Modify: `lib/features/devices/presentation/screens/device_pairing_screen.dart`
- Create: `test/mobile_connection_diagnostics_dialog_test.dart`
- Modify (docs): `.claude/PROJECT_SUMMARY.md`; `.claude/IMPORTANT_FIXED_BUGS.md` only for the silent bugs fixed here (duplicate SSE stream on `resume()`, 6-digit `pairingToken` QR always failing).

- [x] **Step 1: Write widget tests in `test/mobile_connection_diagnostics_dialog_test.dart`**
  Test setup, needed because the real providers touch the network and platform channels:
  - Override `crmSseClientProvider` with `overrideWithValue(fakeClient)`. This also avoids the real provider registering a `WidgetsBindingObserver`. `fakeClient` subclasses `CrmSseClient` and counts `reconnectNow` calls; seed its `connectionLog` with an entry containing `Bearer abc.def.ghi`.
  - Override `agentStatusProvider` with a notifier built on `null` client plus a `@visibleForTesting` seeded state.
  - Override `crmDeviceProvider` with a `CrmDeviceNotifier` subclass whose `checkPairingStatus()` only counts calls. The base constructor calls it, and Dart dispatches to the override, so no `CrmCloudApi.get` runs.
  - Mock the clipboard via `SystemChannels.platform`.
  Cases:
  1. The dialog renders `AppDialog` with the diagnosis title, likely cause, next step, the 4 checklist rows and recent logs. `abc.def.ghi` is not found anywhere in the widget tree.
  2. 'Kết nối lại ngay' calls `reconnectNow(reason: 'diagnostics_dialog')` once and `checkPairingStatus()` once. While `connectionState == connecting` the button is disabled.
  3. 'Sao chép báo cáo' writes text without the token to the clipboard and shows the inline 'Đã sao chép'.
  4. 'Đóng' closes the dialog. After `pumpAndSettle` no timers are pending.

- [x] **Step 2: Run the tests and confirm they fail**
  Run: `rtk flutter test test/mobile_connection_diagnostics_dialog_test.dart`

- [x] **Step 3: Implement**
  - `showMobileConnectionDiagnosticsDialog(BuildContext context)`: `showDialog(context: context, builder: (dialogContext) => const MobileConnectionDiagnosticsDialog())`.
  - `MobileConnectionDiagnosticsDialog` is a `ConsumerStatefulWidget` with local `_reconnecting` and `_copied`. It watches `agentStatusProvider`, `crmDeviceProvider` and `liveChatTransportModeProvider`. It reads `crmSseClientProvider` and wraps the dynamic part in `ValueListenableBuilder`s on `connectionState` and `connectionLog`. It builds a `MobileConnectionSnapshot` and calls `diagnoseMobileConnection()`.
  - Body: a diagnosis card, 4 checklist rows, then logs (newest first, max 30, monospace, inside `ConstrainedBox(maxHeight: 200)` + `ListView`). Relative times are computed at build. No timers.
  - `AppDialogAction`s:
    - 'Sao chép báo cáo' (outline): `await Clipboard.setData(...)`, then `if (!mounted) return;` and `setState(() => _copied = true)`. Use inline feedback, not a `SnackBar`: a SnackBar on the root `Scaffold` renders under the modal barrier.
    - 'Kết nối lại ngay': disabled while `_reconnecting` or `connectionState == connecting`. Calls `reconnectNow(reason: 'diagnostics_dialog')`, then `await ref.read(crmDeviceProvider.notifier).checkPairingStatus()`. (`refreshDevices()` from the first draft does not exist.) Then `if (!mounted) return;` and reset `_reconnecting`.
    - 'Đóng': `Navigator.of(context).pop()`. The widget's own `context` is inside the dialog route.
  - `live_chat_screen.dart` (anchor by symbol, not by line number: the `transportMode == LiveChatTransportMode.cloudRemote` branch that sets `remoteBlockedReason`, around line 1556 in v0.2.3):
    - Replace `else if (!agentStatus.sseConnected)` with `else if (agentStatus.showReconnectBanner)`. Text: `agentStatus.hasSnapshot ? 'Đang kết nối lại...' : 'Đang kết nối tới máy chủ...'`.
    - In both `cloudRemote` banners (the blocking warning banner and the soft info banner, both `Row`s with `Expanded(Text)`), add a compact `TextButton('Chẩn đoán')` after the `Expanded`, with `visualDensity: VisualDensity.compact`. Show it only when `transportMode == cloudRemote`, so the Windows `localBridge` banner is unchanged.
  - `device_pairing_screen.dart`: add `TextButton.icon(icon: Icons.troubleshoot_rounded, label: 'Chẩn đoán kết nối')` to the Android paired card and the Android unpaired form, only when the mode is `cloudRemote`.

- [x] **Step 4: Full verification**
  1. `rtk flutter analyze` (0 issues).
  2. `rtk flutter test` (all suites).
  3. `D:\Dev\conda-envs\py312\python.exe .claude\guard_check.py`.
  4. Build the Android release APK with the `build-and-release` skill (Android only, no publish), install it, and smoke-test it on a real phone:
     - Open Live Chat: no banner flash during the first connect (< 5s).
     - Airplane mode for 10s: the banner appears after about 5s and stays at least 2s after the reconnect.
     - Switch Wi-Fi to 4G without airplane mode: a reconnect happens within 65s (`sse.idle_timeout` or a normal reconnect in the diagnostics log).
     - Background for 2 minutes, then foreground: no banner flash; the log has exactly one `sse.resume` and one `sse.connected`.
     - Open the QR scanner (camera permission dialog, `inactive -> resumed`): no second `sse.connect_start`.
     - Paste `123-456`, the JSON QR and an `alphacrm://pair?code=` link: all pair. A random string shows the validator error.
     - Copy the diagnostics report into a notes app: no JWT, `qrToken`, pairing code or email.
     - Close and reopen the app, then repeat the first check.
  5. Windows: build or run the release and confirm that `localBridge` Live Chat banners and the pairing screen look and behave as before (no diagnostics buttons).
  6. Update `.claude/PROJECT_SUMMARY.md` (rows for `crm_sse_client.dart` and `agent_status_provider.dart`, plus the new diagnostics module). Add the two silent bugs to `.claude/IMPORTANT_FIXED_BUGS.md`.

---

## Part III — Claude Code Review and Plan Revisions

Reviewed on 2026-10-28 against `lib/shared/api/crm_sse_client.dart`, `lib/shared/api/crm_sse_provider.dart`, `agent_status_provider.dart`, `crm_device_provider.dart`, `device_pairing_screen.dart`, `live_chat_screen.dart`, `lib/shared/widgets/app_dialog.dart`, `integration/zalo-bot-service/src/agent/agent-runner.ts`, `alpha-studio-backend/server/routes/crm.js`, `alpha-studio-backend/server/index.js`, `alpha-studio-backend/server/utils/crmEventHub.js` and `_tmp/orca/src/shared/calm-status-reveal.ts`. The direction of the first draft is sound. Several details did not match the code, and the version-compatibility item has no data to work with.

### 1. Verdict

- Items #1, #2, #3 and #5 are worth doing. Item #2 is more valuable than scored, because the review found a silent duplicate-stream bug on `resume()`.
- Item #4 (version compatibility) cannot work today. It is reduced to display-only and deferred.
- Tasks 1–4 were rewritten above. The main changes: real symbol names, a generation guard plus a connect-phase watchdog, resetting the calm clock in the background, the correct dispose hook, a validator that can reach the normalizer, and test setups that avoid real network and platform channels.

### 2. Findings

#### 2.1 Plan vs code mismatches (fixed in Part II)

| # | First draft said | Code says | Fix |
|---|---|---|---|
| 1 | `_lineSub`, `_backoffAttempt`, `_active`, `_paused`, `_openConnection()` | `await for` loop in `_connect()`, `_reconnectAttempts`, `_connecting`, `_disposed` | Task 1 uses real names. The watchdog closes the per-attempt `http.Client`, because an `await for` loop cannot be cancelled. |
| 2 | `CrmSessionStore.getAccessToken`, `CrmCloudConfig.baseUrl` | `CrmAuthTokenStore.getToken`, `CrmCloudApi.baseUrl` | Fixed. Injected as `tokenProvider` / `baseUrlProvider`. |
| 3 | SSE at `/api/v1/crm/events` (Part I) | `GET {baseUrl}/crm/events/subscribe` | Fixed in Task 1. |
| 4 | Tests use "a fake `http.Client`" | The client calls `http.Client()` directly | Added `httpClientFactory`; tests use `MockClient.streaming`. |
| 5 | `fakeAsync` is implied | `fake_async` is only a transitive dependency | Added to `dev_dependencies`. |
| 6 | Cancel the calm timer in `ref.onDispose` | `AgentStatusNotifier` is a `StateNotifier` without `ref` | Cancel in `dispose()` before `super.dispose()`; `mounted` check in the timer callback. |
| 7 | `calmSseConnected` "defaulting to `sseConnected`" | Not possible in a const constructor | Replaced by `showReconnectBanner` (default `false`). |
| 8 | Three different names for the calm state machine | — | One name: `CalmStatusReveal` / `stepCalmStatusReveal`, ported literally, including the 1s healthy hold. |
| 9 | `_MobilePairingView` | No such class; Android UI is the `isClient` branch of `_DevicePairingScreenState` | Task 3 targets `_buildPairedState` and the unpaired form. |
| 10 | `crmDeviceProvider.notifier.refreshDevices()` | Method is `checkPairingStatus()` | Fixed. |
| 11 | Normalize `123-456` in the provider | The form validator rejects it first, and `_submitPairingCode` strips spaces | The validator and submit use `normalizePairingInput`. |
| 12 | Live Chat line numbers 1567 / 1820–1890 | They drift on every edit | Anchor by symbol; line numbers are hints only. |
| 13 | Dialogs "MUST use `AppDialog`" | Correct for the code, but `AGENTS.md` / `CONVENTIONS.md` require `showStandardDialog`, which does not exist in `lib/` | Follow the code: `showDialog` + `AppDialog`. Doc drift reported in §5. |

#### 2.2 Lifecycle and timer edge cases (new requirements)

1. **Duplicate SSE stream on `resume()` (existing silent bug).** `_CrmSseLifecycleObserver` calls `resume()` on every `resumed`. On Android, `inactive -> resumed` happens without `paused` (camera permission dialog when the QR scanner opens, notification shade). `resume()` then calls `_connect()` while connected. That replaces `_httpClient` and never closes the old client. The backend keeps 5 streams per user and evicts the oldest, so this can silently disconnect the user's other device. Fixed by making `resume()` idempotent (Task 1, test 7).
2. **Connect phase can hang forever.** `client.send()` has no timeout. On a half-open network `_connecting` stays `true` and the state stays `connecting`. The watchdog now covers the connect phase.
3. **Stale attempts change shared state.** The `catch` in `_connect()` sets `_connecting = false` for any attempt, even an old one. Once `reconnectNow()` exists, that allows two concurrent streams. Fixed with the generation counter.
4. **Failed clients are never closed.** Socket leak on each failed attempt. Fixed in the failure path.
5. **Keep-alive pings must reset the watchdog.** `CrmSseDecoder` drops `: ping` lines, so a watchdog reset on decoded events would fire every 65s on a quiet but healthy stream. The reset happens on each raw line.
6. **Background makes the calm clock lie.** After `pause()`, `downSince` would be minutes old at `resume()`. The banner would show at once, which is exactly what the feature should prevent. The notifier resets the calm state while `isPaused`.
7. **Startup mislabel.** Today the soft banner says 'Đang kết nối lại...' on every Live Chat open until the first connect. The first draft kept that ("reveal immediately before first connection"). The revised plan gives startup the same 5s grace and uses the label 'Đang kết nối tới máy chủ...' when there is no snapshot yet.
8. **Auth/subscription errors must not be hidden.** HTTP 401/402/403 currently retry forever with backoff. They are now surfaced at once (`immediate: true`) and diagnosed separately.
9. **Provider disposal order.** Riverpod may dispose `crmSseClientProvider` before `agentStatusProvider`. Disposing the client's `ValueNotifier`s would make the notifier's `removeListener` assert. The plan keeps those notifiers alive.
10. **Notifier rebuild.** `agentStatusProvider` watches `liveChatTransportModeProvider`. A rebuild disposes the old notifier, so its calm timer must be cancelled in `dispose()`.
11. **Widget-level async.** The paste button, copy button and reconnect button all `await`. Each one checks `mounted` before using `context` / `setState`. Widgets use no periodic timers.
12. **Test isolation.** The real `crmDeviceProvider` calls `CrmCloudApi.get` in its constructor, and the real `crmSseClientProvider` registers a `WidgetsBindingObserver` and reads secure storage. Task 4 tests override all three providers.

#### 2.3 Pairing edge cases

- `int.tryParse('-12345')` and `int.tryParse('+12345')` succeed, so these 6-char strings pass as codes today. The normalizer uses `^\d{6}$`.
- The desktop QR falls back to `pairingToken: pairingCode` when the backend returns no `qrToken`. Mobile sends it as `qrToken`, and the backend hashes it as a QR token, so pairing always fails. A 6-digit token now maps to `pairingCode`. This changes only a case that never worked.
- `orca://` and deep-link parsing in general: nothing in Alpha CRM produces `alphacrm://pair` links, and there is no Android intent filter. `orca://` is dropped. `alphacrm://` and `https` query parsing are kept only as cheap paste support.
- Auto-submit after paste is rejected because of the rate limiter and the risk of an old clipboard value.

#### 2.4 Logging and privacy

- The log records lifecycle events only. Logging every event would let `message.new` traffic push out the entries that matter, and would put message metadata on the clipboard.
- Redaction also covers the 6-digit pairing code, the 48-hex `qrToken`, emails and phone numbers, not only JWTs.

#### 2.5 Version compatibility (item #4) — why it is deferred

1. The data never reaches the phone. `hello` selects only `displayName agentStatus zaloAccounts queueDepth lastHeartbeatAt lastSeenAt` (`crm.js`, `GET /events/subscribe`). Both `device.status` publishes (`crm.js` heartbeat route, `index.js` stale-device interval) also omit `appVersion` / `agentVersion`.
2. The numbers are not comparable. `agent-runner.ts` sends `PACKAGE_VERSION` from `integration/zalo-bot-service/package.json` (now `0.2.0`) as **both** `appVersion` and `agentVersion`. The mobile app version comes from `pubspec.yaml` (now `0.2.3+31`). These two lines are released independently. A `major.minor` comparison would give false "desktop outdated" warnings as soon as the Flutter app reaches `0.3.0`.
3. To do it properly later: (a) the backend adds the fields to the `hello` select and to both `device.status` payloads; (b) the agent reports the Flutter app version separately (for example through the existing `/internal/supervisor-stats` path), or both sides share an integer `protocolVersion` like Orca's `ORCA_PROTOCOL_VERSION`; (c) only then add `evaluateAgentVersionCompat` and a warning.

#### 2.6 Convention notes

- `showStandardDialog` (`lib/shared/widgets/standard_dialog.dart`) is required by `AGENTS.md` and `CONVENTIONS.md` but does not exist. All current dialogs use `showDialog` + `AppDialog`. The plan follows the code.
- `AGENTS.md` requires `vi` and `en` UI text, but the app has no i18n layer. The plan stays Vietnamese-only.

### 3. Revised scores

| # | Feature | First draft | Revised | Verdict | Reason |
|---|---|---|---|---|---|
| 1 | Calm status reveal | 9.5 | **9.0** | ADOPT | Real problem (banner + composer layout shift on blips). Needs the background reset and startup grace to be correct. |
| 2 | Watchdog, revival, manual reconnect | 9.2 | **9.4** | ADOPT | Also fixes the duplicate-stream bug, the hung connect and the client leak. |
| 3 | Redacted log + diagnostics | 9.0 | **8.0** | ADOPT (smaller) | Useful on Android, which has no visibility today. Keep it to lifecycle entries; the analyzer is simple rules. |
| 4 | Version compatibility | 8.8 | **3.5** | DEFER (display-only) | No data reaches the phone, and the two version numbers are unrelated (§2.5). |
| 5 | Pairing normalization + live status | 8.5 | **7.0** | ADOPT (trimmed) | Hyphen codes, paste, the 6-digit `pairingToken` fix and live status are worth it. Deep links have no producer. |
| 6 | Send-guard feedback | 7.5 | **7.0** | PARTIAL | Folded into Task 4 as the "Chẩn đoán" button on the existing banners. |
| 7 | LAN WebSocket + relay E2EE | 2.0 | 2.0 | REJECT | Unchanged. |
| 8 | Terminal / git / file tree | 1.0 | 1.0 | REJECT | Unchanged. |

**Revised overall suitability: 7.2 / 10.** The adoptable resilience, diagnostics and pairing layer (#1, #2, #3, #5, #6) scores **8.4 / 10**.

### 4. Revision log

- **Architecture / Global Constraints:** corrected dialog pattern, i18n reality, privacy list, no widget timers, `mounted` rule, Android release smoke, execution order.
- **Task 1:** real symbols; injectable factory, token, base URL and clock; generation guard; one watchdog for the connect and idle phases, reset on raw lines; idempotent `resume()`; `reconnectNow()` semantics including the no-listener and disposed cases; failed-client close; lifecycle-only log through a `ValueListenable`; do not dispose `ValueNotifier`s; 11 tests instead of 4.
- **Task 2:** one state-machine name; literal Orca port with healthy hold; no immediate reveal at startup; `immediate` only for 401/402/403; reset while paused; `showReconnectBanner` instead of `calmSseConnected`; timer cancelled in `dispose()` with a `mounted` guard; version fields nullable and display-only; new notifier test file with `fakeAsync` disposal checks.
- **Task 3:** real UI targets; `normalizePairingInput` shared by validator, submit and payload builder; `^\d{6}$`; 6-digit `pairingToken` fix; `orca://` dropped; paste without auto-submit; live status by `deviceId` with priority order and no ticker; diagnostics button moved to Task 4.
- **Task 4:** `ConsumerStatefulWidget` dialog with `ValueListenableBuilder`s; inline copy feedback; reconnect disabled while connecting; `checkPairingStatus()` instead of `refreshDevices()`; Live Chat anchored by symbol; buttons only in `cloudRemote`; provider overrides that avoid network and platform channels; Android APK smoke checklist covering background, camera permission and network switch; Windows no-regression check; `IMPORTANT_FIXED_BUGS.md` entries for the two silent bugs.

### 5. Open items for the owner (Resolved in Follow-up Implementation)

1. **[x] Backend + Agent + Mobile Version Compatibility (#4):**
   - `alpha-studio-backend/server/routes/crm.js` (`CRM_SSE_HELLO_DEVICE_SELECT` in `GET /events/subscribe` and `buildDeviceStatusEventPayload` in `POST /agent/heartbeat`) and `server/index.js` (stale-device offline interval) now include `appVersion` and `agentVersion` in `hello` and `device.status` SSE events.
   - `integration/zalo-bot-service/src/agent/cloud-api.ts`, `agent-runner.ts`, `scripts/bundle.mjs`, and `lib/shared/utils/zalo_backend_manager.dart` now report the real Flutter Desktop app version (`ALPHA_CRM_APP_VERSION` / `CRM_DESKTOP_APP_VERSION` from `pubspec.yaml`) as `appVersion` and the bot service package version as `agentVersion`.
   - `lib/features/messaging/live_chat/utils/mobile_connection_diagnostics.dart` now implements `evaluateAgentVersionCompat()` and warns in `diagnoseMobileConnection()` and `MobileConnectionDiagnosticsDialog` when either Desktop or Mobile is outdated.
2. **[x] `showStandardDialog` Helper Alignment:**
   - Added `showStandardDialog<T>()` in `lib/shared/widgets/app_dialog.dart` and wired it into `showMobileConnectionDiagnosticsDialog()` and `DevicePairingScreen` (also disposing `tokenController` in `simulateQrScanner()`).
3. **Note on `vi` + `en` UI text:** The app currently has no `.arb` / `AppLocalizations` layer; UI text remains consistent with existing Vietnamese screens until a project-wide localization layer is introduced.
