# Project Summary

*Last Updated: 2026-06-19 (Session #125) - Added CRM trial awareness to the Flutter client subscription flow. `CrmAuthState` now preserves the cloud subscription plan and exposes `isTrialSubscription`; login/refresh keeps `crm_trial` from `/crm/subscription/me`, and `/subscription` shows the one-time trial terms (7 days, 50 AI requests, free, one account only) with an upgrade CTA to the paid monthly plan. Added regression coverage for keeping the trial plan from the cloud profile.*

*Last Updated: 2026-06-19 (Session #124) - Fixed Live Chat realtime + made the paused AI icon interactive. Realtime (Flutter `live_chat_provider.dart`): the SSE is now subscribed at ACCOUNT level (`watchEvents(accountId:)`, threadId omitted) and persists across thread switches, so the conversation LIST updates live (a `message.created` for a non-open thread debounce-refreshes the list); it self-heals via exponential-backoff reconnect (`_openAccountStream`/`_scheduleReconnect`, 1→30s) instead of staying dead after a drop (old `onError/onDone` just set `realtimeConnected=false`). The "tin nhắn mới" toast loop is fixed with a per-conversation high-water map `_lastNotifiedUnread` (a given unread level is toasted at most once; baseline reset on manual/account-switch loads). AI icon (`_AiStatusIcon` in `live_chat_screen.dart`): hovering the dimmed (paused) icon shows a status tooltip, and **double-clicking it calls `resumeChatbotNow()`** → reuses `updateChatbotState(enabled:true)` to clear `pausedUntil` immediately (no backend change needed). Fixed: an operator reply was wrongly turning the per-conversation toggle OFF — `_markOperatorTakeover` now sets a temporary `chatbotPausedUntil` and keeps `chatbotEnabled` true (only an explicit toggle/handoff disables). The AI icon is now a circular badge (border + tinted fill: primary when active, muted when paused) with extra spacing before the Bot switch. `flutter analyze` clean (no errors/warnings). Backend unchanged from #123 (109 tests pass).*

*Last Updated: 2026-06-19 (Session #123) - Reworked chatbot operator-takeover into an auto-expiring pause + added an AI status icon. Previously a human reply set a PERMANENT `disabled_by_operator` (and `toggleChatbot` reused the same mode), so any conversation the operator touched had its AI stuck off until manually re-enabled — this is why "AI không hoạt động" after the operator sent test messages. Now: a human reply (CRM send `applyOperatorTakeover`, OR a self-sent phone reply detected in `agent-runner` when `senderId===accountId && !reconciledId`) calls `pauseChatbotForOperatorReply`, which keeps `mode='enabled'` and sets a temporary `paused_until` (new column on `chatbot_conversation_state`). `chatbot-runtime.evaluateBuffered` short-circuits while `isChatbotPaused`, so the bot stays silent during the cooldown and auto-resumes after. Cooldown is a global local setting (`app_settings` kv, default 10 min, clamp 5–120) via `GET/PUT /local/settings`, editable in the Live Chat settings dialog (slider). Only the per-conversation toggle OFF (`disabled_by_operator`, reason `operator_disabled`) is permanent. A one-time DB migration DELETEs legacy `manual_operator_reply` takeover rows so stuck conversations recover on first run. Flutter: `Conversation` gains `chatbotPausedUntil` (+ `chatbotActive`/`chatbotPaused` getters); the chat header shows a `smart_toy` icon — bright = AI active, dim + tooltip ("AI tạm nghỉ … tự bật lại lúc HH:mm") = paused, hidden when toggle off; a 30s `_statusTicker` flips the icon to active at expiry. SSE `conversation.chatbot_state` + conversation list now carry `pausedUntil`. Backend 109 tests pass (added pause/cooldown/migration tests); `flutter analyze` clean. NOTE: separate Live Chat realtime fragility (SSE has no auto-reconnect; list-level updates only via the 12s disconnected-poll) was diagnosed but NOT changed this session.*

*Last Updated: 2026-06-19 (Session #122) - Added ZaloCRM-style auto re-login + circuit breaker to personal-Zalo send recovery. A send that fails with `zpw_sek`/code 600 no longer expires the account on the first error: `PersonalZcaChannel.sendMessage` now re-logs in from the immutable credentials file (`reloginAccountFromDiskOnce` → `zalo.login(file)`, which makes Zalo re-issue fresh cookies into a new RAM jar) and retries the send once. A sliding-window circuit breaker (`RELOGIN_MAX_IN_WINDOW = 3` per `RELOGIN_WINDOW_MS = 5 min`, tracked in `reloginHistory`) prevents hammering a genuinely revoked account; concurrent sends share one re-login via `reloginInFlight`. Only when re-login fails (file revoked/missing `zpw_sek`) or the breaker is open does the outer catch mark the account `disconnected_expired` (→ QR re-login). A successful send resets the breaker. Added Node tests for the breaker counter and the expire-after-failed-relogin path in `personal-zca-channel.test.ts` (106 tests pass). Complements Session #121's microsecond-`Date.now` fix.*

*Last Updated: 2026-06-19 (Session #121) - Fixed the RECURRING personal-Zalo `zpw_sek bị thiếu hoặc không đúng` (code 600) failure that hit every send immediately, even right after a fresh QR rescan. Root cause was NOT session expiry: Flutter `live_chat_provider.dart` generated `clientMessageId = 'flutter_<microsecondsSinceEpoch>'`; the backend's `runWithFixedDateNow` pins the **global `Date.now()`** to that id so zca-js's `cliMsgId` matches the optimistic UI, but a microsecond value (~1000× a ms timestamp) moved `Date.now()` ~50,000 years into the future. zca-js builds the request `Cookie` header via tough-cookie's `getCookieString()`, whose expiry check reads `Date.now()`, so `zpw_sek` was treated as expired, dropped from the request and evicted from the RAM jar → code 600; rescanning re-seeded the jar but the next send evicted it again (endless loop). Fix: Flutter now uses `millisecondsSinceEpoch` for `clientMessageId` (3 send sites); backend `runWithFixedDateNow` only pins `Date.now()` when the id is within ±10 min of the real clock (`DATE_NOW_PIN_TOLERANCE_MS`), otherwise keeps the real clock. Distinct from the Session #111 on-disk cookie-corruption fix and from real revocation (websocket 3000/3003). Reference `deplao-builder` avoids the trap entirely by sending with the real clock and reconciling the actual `cliMsgId` from the send response. Added regression test in `personal-zca-channel.test.ts`. See IMPORTANT_FIXED_BUGS.md.*

*Last Updated: 2026-06-19 (Session #120) - Hardened local Zalo backend port ownership. `server.ts` now exposes an explicit `/health` identity (`service: alpha-crm-zalo-bot-service`, `pid`, `projectRoot`, `dataRoot`, active bind info) and writes the same identity into `.data/active-port.json`; it no longer auto-falls through to the next port on `EADDRINUSE`. `ZaloBackendManager` now treats plain `status: ok` as insufficient, chooses the backend port itself, kills only verified Alpha CRM Zalo backend processes that are holding a candidate port, and falls back to the next port only when the owner is another app. Debug/manual backend discovery also requires the health identity before updating `zalo_settings.json`. Added `test/zalo_backend_manager_port_policy_test.dart` for identity and command-line recognition rules.*

*Last Updated: 2026-06-19 (Session #119) - Hardened personal-Zalo credential failure handling. When every saved `credentials_*.json` fails to load because `zpw_sek` is missing or `zalo.login(savedCredentials)` is rejected, the backend now preserves the failed-credential reason instead of clearing `loginError` after scanning. `PersonalZcaChannel.sendMessage()` now surfaces the specific failed account reason from `failedAccounts` when the pool is empty or the requested account could not load, so users see the actionable QR re-login cause instead of a generic "No active connected Zalo accounts" error. A successful QR re-login now clears stale `failedAccounts`/`loginError` for that account and passes the just-written `credentials_<uId>.json` path into `addAccountInstance()`, preventing old code-600 state from leaking into the new session. Added Node regression tests for these paths in `personal-zca-channel.test.ts`. Existing corrupted credential files still cannot be repaired in code and require a fresh QR login.*

*Last Updated: 2026-06-18 (Session #118) - Hardened the Windows auto-update flow. The in-place updater (`app_update_service.dart` → `buildWindowsZipUpdaterScript`) now opens a titled console that shows progress (giải nén → copy → khởi động lại) and auto-closes; on failure it **restarts the existing app** (instead of opening Explorer) so the result can be reported. Added post-update verification: before exiting, `_installWindowsZipUpdate` writes a `.update_pending` marker (target version) next to the exe; on next startup `main.dart` calls `AppUpdateService.checkPostUpdateResult()` and a new global `UpdateResultGate` shows a green "Đã cập nhật thành công" banner (auto-dismiss) when the running version matches, or a **"Cập nhật chưa hoàn tất → Tải lại bản mới"** dialog (opens the download page) when the update did not apply (e.g. the `alpha_crm.exe`→`Alpha CRM.exe` rename breaks in-place copy). Release packaging (`alpha-studio-backend/scripts/release-to-b2.js`): added `--android`/`--windows` platform flags (no flag = both); re-enabled the Android `flutter build apk --release` build + APK upload; `version.json` assets are now **merged by platform** so a single-platform release preserves the other platform's download link. The local Zalo backend now ships as a single **minified** esbuild bundle (`dist/server.cjs`, `minify:true`) and the release stages **only** `server.cjs` + the `better-sqlite3` closure (no loose `dist/*.js` sources / no full `node_modules`) — smaller ZIP, no readable backend source leak. **Backend durable-data relocation:** the local Zalo backend now stores persistent state (Zalo credentials, `agent/device-secret.json`, `live-chat.sqlite`, `local-chat-media`, `chatbot-knowledge`, `integrations/settings.json`, QR) under a stable per-machine `dataRoot` = `%LOCALAPPDATA%\AlphaCRM\zalo-bot-service` (override `ALPHA_CRM_DATA_DIR`) instead of `.data` next to the (re)moved install — so updating/moving the app or switching dev↔packaged no longer wipes the Zalo login, chat DB, or device identity (which previously triggered a re-login + cloud "đổi máy" confirmation). `config.ts` exposes `dataRoot` and runs a one-time copy migration from the legacy `.data`; runtime/ephemeral files (`active-port.json`, `logs`, `temp-sends`) intentionally stay at `projectRoot/.data`. The Flutter side is unchanged: user **downloads** stay in `Downloads/AlphaCRM` (user-facing) and the Flutter local DB stays in `getApplicationSupportDirectory()`. (Session #117) - Fixed pre-existing unit and widget test failures in the Flutter repository: made AppLogger initialization lazy to prevent LateInitializationError during test execution; wrapped the login screen test with DeviceConflictGate to correctly display the device conflict warning; updated the revocation test to align with the new session-preservation flow. Verified chatbot default configurations (aiEnabled: false, groupAudience: 'tagOnly'), mock documents, and rule seeding. (Session #116) - Fixed the chatbot AI file sending behavior: when the chatbot sends a knowledge file, copy it temporarily to preserve its original filename (e.g., invoices.pdf) instead of the content hash id, ensuring Zalo recipients receive the file with its original name. (Session #115) - Fixed the real "kicked to a blank login screen on app start" bug: on **token restoration**, if the cloud returns `409 DEVICE_ALREADY_ACTIVE` (account device limit = 1, an old device occupies the slot), `_authenticateToken` returned `CrmLoginDeviceConflict` but `_checkLocalToken` **ignored the return value** → user landed on a blank login with no dialog. Now BOTH fresh login and restoration surface the conflict via `CrmAuthState.pendingDeviceConflict` + a global `DeviceConflictGate` that shows the "Đăng xuất máy cũ?" dialog inline (→ `confirmDeviceReplacement()` force-replaces the old device via `/crm/devices/force-logout-old`, or `cancelPendingLogin()`); the old login-screen `showDialog` path was removed because it didn't render reliably. Backend stderr/stdout is now decoded with `utf8.decode` (was `String.fromCharCodes` → mojibake) and `AppLogger` writes clean single-line entries (`ISO-time [LEVEL] message`) via a serialized write queue instead of the multi-line PrettyPrinter. Settings → "Tích hợp Zalo Backend" panel was simplified to **"Trạng thái Zalo"**: removed the redundant/false backend-connection badge, the manual Backend URL field, and the "Kiểm tra kết nối" button (the supervisor + global banner now own backend lifecycle/health); it auto-refreshes Zalo account/listener status on open. Also fixed diagnostics being invisible in release: `AppLogger` used the default logger filter (suppresses `info` in release) and only created `_logFile` lazily — now it uses an always-log filter, writes an init line immediately, and falls back to `<exe>/logs` if `getApplicationDocumentsDirectory()` fails. (Session #114) - Compacted common dialog headers (AppDialog and ComplianceWarningsDialog) by reducing horizontal padding from 32px (AppSpacing.xl) to 24px (AppSpacing.l) and vertical padding from 24px (AppSpacing.l) to 16px (AppSpacing.m) to align better with the dialog body content and look more balanced. (Session #113) - Hardened the local Zalo backend lifecycle for production: `ZaloBackendManager` is now a supervisor (state machine `BackendStatus`, continuous /health watchdog every 5s, auto-restart with exponential backoff + a 5-restarts/2-min circuit breaker, and a permanent process-exit listener that restarts on unexpected crash). Process lifecycle is bound to a Windows **Job Object** (`KILL_ON_JOB_CLOSE`, via `lib/shared/utils/windows_job_object.dart` raw FFI) so node.exe can never orphan/hold port 8787 even on a hard kill. Boot is now **non-blocking** (`main.dart` fires `startSupervised()` and runs the UI immediately) with a global `BackendStatusBanner` showing starting/restarting/degraded/failed states and a manual "Thử lại" (retryManually) on circuit-open. Added a full-screen **`BackendSplashOverlay`** (glassmorphic) covering the app during the first backend startup (disappears once healthy; shows a retry on failed). **Windows desktop shell** (`lib/shared/utils/desktop_window_manager.dart` via `window_manager` + `tray_manager`): app launches **maximized**, the **X button shows a confirm dialog** ("Thoát luôn" / "Ẩn xuống tray" / "Hủy") via `DesktopShell.closeRequest` + `AppCloseGate` (renders the dialog inline, no GoRouter navigator dependency), and the tray right-click menu offers "Hiện ứng dụng" / "Thoát" (real exit stops the backend first). Renamed the Windows executable output from `alpha_crm.exe` to **`Alpha CRM.exe`** (CMake `OUTPUT_NAME` + Runner.rc `OriginalFilename`). Maximize is now owned solely by the native runner (`windows/runner/main.cpp` `SW_SHOWMAXIMIZED`); the Dart `window_manager.maximize()/show()` call was removed because it re-applied the default window size and caused a "maximize-then-shrink" flicker. **Device-revoked UX:** an in-session `session.revoked` no longer silently logs the user out — `CrmAuthState.deviceRevokedReason` + a confirm dialog lets the user keep this PC (force re-register, revoking the other device, via `reclaimRevokedDevice()`) or log out (`dismissRevokedDevice()`). The dialog is rendered by a global `RevocationGate` (inline render in the `main.dart` builder, like `AppCloseGate`) so it appears regardless of router/`AppShell` state. **Exit hang fixed:** "Thoát luôn" / tray "Thoát" now calls `ZaloBackendManager.prepareForShutdown()` (non-blocking `proc.kill()`) then `exit(0)` — it does NOT await `windowManager.destroy()`/tray teardown (the actual freeze source); the Job Object kills the backend when the process ends. The `_handleRevocation` diagnostic uses `AppLogger` (file + `/api/logs/client`) not `debugPrint` (stripped in release). **Maximize-shrink fixed:** `DesktopShell._reassertMaximized()` re-applies `maximize()` at 300/800/1500 ms to override window_manager un-maximizing the natively-maximized window during init. (Session #112) - Implemented database-backed caching, idle loading, and visual load indicators for the Campaign Overview (Dashboard) screen. Also moved default downloads and media cache path to a subfolder (`Downloads/AlphaCRM`) rather than the root downloads directory. (Session #111) - Fixed personal-Zalo `zpw_sek bị thiếu hoặc không đúng` (code 600) outage: removed the cookie-jar re-serialization (`persistAccountCredentials`/`persistAllCredentials`/startCredentialRefreshTimer) that overwrote the credentials file with a degraded RAM jar and dropped `zpw_sek`. The credentials file is now immutable (written once at QR login); a `zpw_sek`/code-600 send failure marks the account `disconnected_expired`. A file already corrupted requires a fresh QR re-login. See IMPORTANT_FIXED_BUGS.md. (Session #110) Fixed GoRouter assertion crash when saving settings in Risk Controls dialog (due to popping settings screen instead of dialog context). Also Chatbot AI can now actually SEND knowledge files/images/audio/video to customers, LOCAL-FIRST: files are stored only on the operator machine (`<bridge>/.data/chatbot-knowledge/<id>`, uploaded via the local bridge — never on B2/cloud); the cloud keeps only name/type/description + content-hash id. Backend resolves [[SEND:Fx]] markers into `{id,name,type}` (stripping stray filename text); the bridge resolves id→local path and sends via zca-js (missing file → skipped + red "thiếu file" badge in the knowledge tab). Also (Session #108) fixed personal-Zalo disconnect-on-login + multi-account listener recovery. See IMPORTANT_FIXED_BUGS.md.*

## 1. Project Overview

- **Type:** Cross-platform CRM UI application for web, Android, and Windows desktop.
- **Tech Stack:** Flutter, Dart SDK 3.10.7, Material 3, Riverpod, GoRouter.
- **Package Manager:** Flutter pub via `pubspec.yaml` and `pubspec.lock`.
- **i18n:** No formal localization solution. Vietnamese UI strings are currently inline; `intl` is used for formatting.
- **State Management:** `flutter_riverpod` with `StateNotifierProvider`, `StateProvider`, and local widget state.
- **Styling:** Central design tokens in `lib/app/theme/` plus reusable widgets in `lib/shared/widgets/`.
- **Deployment:** Automated release is handled by `alpha-studio-backend/scripts/release-to-b2.js` for Android APK, Windows ZIP, and Flutter Web under `/crm/`. The Windows ZIP includes the Flutter runner plus the local Zalo backend bundle required for production desktop use.
- **Knowledge Graph:** `.understand-anything/` is not present. Recommend running `/understand` before large impact analysis work.

---

## 2. File Structure

### Key Directories

```text
android/                     Native Android runner and Gradle config
docs/                        Design, architecture, agent task, and progress docs
img/                         Reference UI screenshots for the CRM app
lib/
  main.dart                   Flutter entry point
  app/                        App shell, routing, theme, responsive scaffold
  features/                   Feature-first CRM screens and providers
    security/                  Local app lock provider, overlay, and password hashing helpers
    workflows/                 n8n workflow template catalog, automation screen, channel capability matrix, and local backend API client
  mock/                       Mock domain models and sample/default data (includes ZaloChannelMode enum)
  shared/                     Reusable widgets and responsive utilities
test/                         Flutter widget tests
web/                          Flutter web manifest, icons, and index page
windows/                      Native Windows runner and CMake config
integration/
  zalo-bot-service/            Node.js/TypeScript backend bridge — personal-first via zca-js
    src/channels/              Channel adapter pattern (PersonalZca, OfficialOa, Mock)
    src/agent/                 Production outbound agent layer (runner, command executor, machine fingerprinting, cloud-api)
    src/integrations/           n8n settings/client/template builder, n8n event dispatcher, and proxy helper tests/utilities
    src/compliance.ts          Channel-aware backend compliance guard
    src/config.ts              Environment config with ZaloChannelMode and Agent configs
    src/server.ts              HTTP API server (hardened to bind to 127.0.0.1 and restrict CORS)
    src/personal-login.ts      CLI bootstrap for personal Zalo QR login
    src/zalo.ts                Channel selector/router
docs/
  guides/
    customer-installation-guide.md               Setup quick-start for customers
    production-crm-operator-guide.md             Daily handbook for operators
    zalo-integration-installation-and-usage.md   Detailed setup guide for Zalo integration backend
  compliance/
    zalo-integration-and-risk-controls.md        Comprehensive Vietnamese Zalo risk control strategy
    production-zalo-risk-controls.md             English Zalo risk controls summary checklist
  specs/
    reference-analysis.md                        Comparison of Alpha CRM vs Deplao and ZaloCRM
    implementation-plan.md                       Phased integration plan
    deplao-feature-integration-spec.md           Features integrated from Deplao
    crm-domain-contract-gap.md                   Gap analysis for future domain models
    zalo-message-processing-gap-vs-deplao.md     Zalo Live Chat handling parity audit against Deplao
    n8n-facebook-integration-contract.md         Meta Page and n8n webhook routing strategy
  api-catalog/
    zalo-reference-sources.md                    Local repo references (zca-js, zalo-bot-js, Deplao)
    zca-js-api-catalog.md                        API catalog for the zca-js library
    zca-js-unintegrated-apis.md                 List of remaining unintegrated zca-js APIs
  releases/
    production-release-checklist.md              Release checklists and verification steps
```

### Critical Files

| File | Purpose | Notes |
|------|---------|-------|
| `pubspec.yaml` | Flutter package metadata and dependencies | Uses Dart SDK `^3.10.7`; dependencies include GoRouter, Riverpod, fl_chart, data_table_2, google_fonts, intl, http, package_info_plus, path_provider, url_launcher, open_filex, mobile_scanner, qr_flutter, ffi + win32 (Windows Job Object), window_manager + tray_manager (Windows maximize/tray). Declares `assets/app_icon.ico` (tray icon). |
| `integration/zalo-bot-service/package.json` | Local backend package metadata | Uses `zca-js@^2.1.2` and `proxy-agent@^6.5.0` for per-account HTTP/HTTPS/SOCKS proxy enforcement. |
| `analysis_options.yaml` | Analyzer and lint configuration | Includes `package:flutter_lints/flutter.yaml`. |
| `lib/main.dart` | Entry point | Wraps `MyApp` in `ProviderScope`; uses `MaterialApp.router`. Boot is non-blocking: fires `ZaloBackendManager.startSupervised()` (fire-and-forget) and mounts `BackendStatusBanner` above the router child. |
| `lib/shared/api/crm_cloud_api.dart` | Alpha Studio cloud API client | Uses `ALPHA_STUDIO_API_URL` with production fallback and Bearer JWT headers. |
| `lib/shared/auth/crm_auth_token_store.dart` | CRM JWT storage abstraction | Web uses localStorage; native Android/Windows currently use an app-support JSON file via `path_provider` (fallback, not secure storage). |
| `lib/shared/auth/web_auth_bridge.dart` | Flutter web iframe SSO bridge | Accepts Alpha Studio `{ type: 'AUTH_TOKEN', token }` postMessage and sends `AUTH_READY`. |
| `lib/features/auth/providers/crm_auth_provider.dart` | Alpha Studio auth state | Restores/login/logout JWT, fetches `/api/auth/me`, CRM subscription, and quota. |
| `lib/app/routing/app_routes.dart` | Route constants | Defines 17 CRM routes. |
| `lib/app/routing/app_router.dart` | GoRouter tree | Root redirects to `/dashboard`; `ShellRoute` wraps CRM screens. |
| `lib/features/customers/presentation/screens/customers_screen.dart` | Customers workspace | Shows customer stats, saved segments, status pipeline summary, responsive table, selected-contact actions, and a desktop/tablet detail panel. |
| `lib/app/shell/responsive_scaffold.dart` | Layout switching | Mobile drawer, tablet collapsed sidebar, desktop sidebar. Auto-checks for updates on startup (Windows/Android) and shows update dialog. |
| `lib/app/shell/app_sidebar.dart` | Main navigation | Uses grouped nav items, active state, collapsed mode. |
| `lib/features/security/` | Local app lock feature | Provides app-level lock overlay, local password hash persistence, and sidebar lock trigger. |
| `lib/features/workflows/` | Workflow automation feature | Provides `/workflows`, n8n settings UI, template catalog/filtering, channel capability matrix, and install calls to local backend. |
| `lib/features/messaging/live_chat/utils/quick_reply_shortcuts.dart` | Quick reply resolver | Resolves `/1`, `/2`, and named quick template shortcuts for Live Chat sends. |
| `lib/app/theme/app_colors.dart` | Color tokens | Implements design-system colors from `docs/01-design-system.md`. |
| `lib/app/theme/app_spacing.dart` | Spacing and radius tokens | 4/8/12/16/20/24/32/40/48 scale and radius tokens. |
| `lib/app/theme/app_text_styles.dart` | Typography tokens | Inter font via `google_fonts`. |
| `lib/shared/widgets/` | Shared UI primitives | Buttons, cards, inputs, tabs, alerts, badges, tables, logs, compliance warnings popup, update dialog. |
| `lib/shared/utils/zalo_backend_manager.dart` | Desktop local backend **supervisor** | Spawns the packaged local Zalo backend (prefers direct `node.exe dist/server.cjs` beside `alpha_crm.exe`, falls back to `zalo-bot-service.cmd`/`.exe`/`.bat`). Exposes `BackendStatus` via a `ValueNotifier`; `startSupervised()` runs a 5s /health watchdog with auto-restart (exponential backoff + circuit breaker) and `retryManually()` for circuit-open recovery. Binds each spawned process to a Windows Job Object so it dies with the app. |
| `lib/shared/utils/windows_job_object.dart` | Windows Job Object helper (raw FFI) | Creates a `KILL_ON_JOB_CLOSE` Job Object and assigns the backend pid so node.exe is killed by the OS when the app exits (incl. hard kill). Isolated from Flutter imports to avoid win32 symbol clashes; fails silently → falls back to taskkill. |
| `lib/shared/widgets/backend_status_banner.dart` | Global backend status banner | `ValueListenableBuilder` on `ZaloBackendManager.status`; hidden when healthy/stopped, shows starting/restarting/degraded and a red failed state with a "Thử lại" button (`retryManually`). Mounted in `main.dart` above the router child. |
| `lib/shared/widgets/backend_splash_overlay.dart` | First-startup splash | Full-screen glassmorphic splash shown while the backend starts for the FIRST time (covers login/app); disappears permanently once `BackendStatus.healthy`; shows error + "Thử lại" on `failed`. Wraps the app in `main.dart`. |
| `lib/shared/utils/desktop_window_manager.dart` | Windows window + tray shell | `DesktopShell` (uses `window_manager` + `tray_manager`): maximize owned by native runner; intercepts the X button (`setPreventClose`) and raises `closeRequest` so the UI can confirm. Exposes `exitApp()` / `hideToTray()` / `cancelClose()`; tray menu ("Hiện ứng dụng" / "Thoát"). Real exit calls `ZaloBackendManager.stopBackend()` then `destroy()`. Tray icon = `assets/app_icon.ico`. |
| `lib/shared/widgets/app_close_gate.dart` | X-button confirm dialog | Wraps the whole app; listens to `DesktopShell.closeRequest` and renders an inline `AppDialog` (no `showDialog`/Navigator needed) with "Thoát luôn" / "Ẩn xuống tray" / "Hủy". |
| `lib/shared/widgets/revocation_gate.dart` | Device-revoked confirm dialog | `ConsumerWidget` wrapping the whole app; watches `CrmAuthState.deviceRevokedReason` and renders an inline `AppDialog` ("Dùng máy này" → `reclaimRevokedDevice`, "Đăng xuất" → `dismissRevokedDevice`). Global mount so it shows in any router state. |
| `lib/features/**/providers/` | Feature state | Riverpod `StateNotifier` classes for mock interactions. |
| `lib/features/subscription/models/subscription_catalog.dart` | CRM subscription catalog helper | Keeps Flutter plan/top-up prices aligned with backend catalog and parses VietQR checkout payloads. |
| `lib/mock/` | Mock data | Contacts, campaigns, messages, groups, accounts, system settings (with Zalo compliance fields). |
| `lib/shared/utils/zalo_compliance_guard.dart` | Shared compliance guard | Channel-mode-aware rule engine evaluating risk for all Zalo actions. |
| `lib/shared/utils/app_update_service.dart` | Auto-update service | Fetches B2 `version.json`, compares semver, downloads the per-platform asset (Windows `.zip`, Android `.apk`), applies Windows zip in-place via a console updater script (titled, shows progress, auto-closes, restarts app on success/failure), writes a `.update_pending` marker, and verifies the result on next launch via `checkPostUpdateResult()`. |
| `lib/shared/widgets/update_result_gate.dart` | Post-update result UI | Global inline gate: green success banner (auto-dismiss) or a "Cập nhật chưa hoàn tất → Tải lại bản mới" dialog when an in-place update did not apply. Driven by `postUpdateResultProvider`. |
| `lib/features/settings/providers/update_provider.dart` | Update state provider | Riverpod `StateNotifierProvider` managing check/download/install lifecycle for app updates. |
| `lib/features/zalo_integration/` | Zalo integration feature | API client, provider (with accountType, accountLabel, listenerRunning), and data models. |
| `integration/zalo-bot-service/` | Node.js backend | HTTP server with ZaloChannel adapter pattern: PersonalZca (zca-js), OfficialOa, Mock. The automated Windows release stages its compiled `dist/`, `node_modules`, `.env.example`, and bundled Node runtime into the ZIP while excluding `.env` and `.data` secrets. |
| `integration/zalo-bot-service/src/integrations/` | n8n/proxy helpers | Stores masked n8n settings, builds n8n workflow payloads, dispatches inbound events to n8n webhooks, and creates/test proxy agents. |
| `integration/zalo-bot-service/src/channels/official-bot-client.ts` | Official Bot API transport | Small `zalo-bot-js`-style native fetch transport used by `OfficialOaChannel` for compliant official text sends through `ZALO_BOT_TOKEN`. |
| `integration/zalo-bot-service/src/channels/official-oa-channel.ts` | Official Bot/OA channel adapter | Handles official status, text sends, and webhook inbound normalization into `ZaloInboundMessageEvent` for CRM live chat/chatbot ingestion. |
| `docs/specs/deplao-feature-integration-spec.md` | Deplao integration review spec | Records implemented features, review checklist, known limits, and verification commands. |
| `docs/specs/zalo-message-processing-gap-vs-deplao.md` | Phân tích phần xử lý tin nhắn Zalo còn thiếu | Đối chiếu Live Chat của Alpha CRM với pipeline Zalo của Deplao; ghi rõ các phần realtime, lưu trữ, gửi tin, media và UI còn thiếu hoặc mới triển khai một phần. Không bao gồm Facebook. |
| `docs/specs/reference-analysis.md` | Reference analysis | Compares current Alpha CRM against Deplao Builder and ZaloCRM and identifies reusable UX/domain patterns. |
| `docs/specs/implementation-plan.md` | Reference integration plan | Documents the phased implementation plan, impacted files, risks, and verification checklist. |
| `test/customers_screen_test.dart` | Customers screen regression test | Verifies the new pipeline summary and customer detail panel interaction. |
| `test/widget_test.dart` | Smoke test | Verifies app shell and initial dashboard route. |
| `SPEC.md` | Current integration specification | Defines personal-Zalo-first `zca-js` backend adapter plan, while keeping OA as optional secondary channel. |
| `lib/features/messaging/live_chat/data/live_chat_contracts.dart` | Local-first bridge contracts | Path builders, response helpers, and failure indicators for local bridge API. Behind `localFirstLiveChat` feature flag. |

---

## 7. Important Notes for Claude

### When making changes to:

- **Routing:** Keep route constants in `AppRoutes` and update `app_router.dart` only when route behavior changes.
- **Theme:** Use existing `AppColors`, `AppSpacing`, and `AppTextStyles`. Avoid hard-coded theme values unless they are screen-specific and justified.
- **Shared widgets:** Preserve public constructor APIs unless all usage sites are updated and verified.
- **Feature screens:** Keep changes inside the relevant `lib/features/<feature>/` module unless the task explicitly authorizes shared/app-layer edits.
- **Mock data:** Put reusable sample/default data in `lib/mock/`; do not embed large lists directly inside `build`.
- **Responsive UI:** Preserve mobile stack, tablet collapsed sidebar, and desktop multi-column behavior.

### Testing checklist:

- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] For UI changes, inspect desktop, tablet, and mobile widths.
- [ ] For routing changes, navigate all affected sidebar routes.

### Don't forget to:

- Update this file's timestamp and session number.
- Follow `.claude/CONVENTIONS.md`.
- Keep documentation current-state only.
- Record only high-impact or likely-to-recur fixed bugs in `.claude/IMPORTANT_FIXED_BUGS.md`.

---

## 8. Quick Commands

```bash
# Development
flutter pub get
flutter run -d chrome
flutter run -d windows

# Analysis
flutter analyze

# Test
flutter test

# Build examples
flutter build web
flutter build apk
flutter build windows
```

---

**Critical:** Read this entire file before making any changes to the project.
