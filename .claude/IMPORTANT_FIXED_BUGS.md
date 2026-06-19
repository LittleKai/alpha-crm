# Important Fixed Bugs

**Last Updated:** 2026-06-19 +07:00

---

## Chatbot inbound không có đường thực thi production

**Nguyên nhân:** Flutter chỉ CRUD cấu hình cloud; route inbound cloud chỉ upsert
conversation, không chạy rule/AI và không gửi qua phiên Zalo đang hoạt động.
Payload metadata local-first không có `content` nhưng backend lại bắt buộc trường
này.

**Khắc phục:** Thêm local chatbot runtime với SQLite state/config/audit, debounce
3 giây, audience/group mention/quote, handoff, rule theo business hours, AI
fallback qua cloud và gửi trực tiếp `zca-js`. Thêm agent API config/generate/audit,
nhánh metadata-only, operator takeover và SSE state. AI/quota/send lỗi chuyển
handoff, không fallback hoặc tự gửi lại; audit được retry idempotent.

---

## Purpose

This file records important fixed bugs that should not be repeated. Keep entries concise and actionable.

Record only high-impact, hard-to-detect, or likely-to-recur bugs. Do not record ordinary bug fixes, do not append entries after every task, and do not use this file as a changelog.

---

## Fixed Bugs

### 2026-06-19 - Microsecond clientMessageId pinned Date.now() and evicted the live `zpw_sek` cookie

- Symptom: every personal-Zalo send failed with `ZaloApiError ... zpw_sek bị thiếu hoặc không đúng` (code 600), immediately — even right after a fresh QR rescan — then the account was marked `disconnected_expired`. Looked like a dead/expired session but the on-disk credentials were fine.
- Root cause: Flutter sent `clientMessageId = 'flutter_<microsecondsSinceEpoch>'`. The backend's `createZaloClientMessageId` extracts the 16-digit run and `runWithFixedDateNow` overrides the **global `Date.now()`** with it for the whole zca-js send. Microseconds are ~1000× a ms timestamp, so `Date.now()` jumped ~50,000 years into the future. zca-js builds the request `Cookie` header via tough-cookie's `getCookieString()`, which checks expiry against `Date.now()` → `zpw_sek` was treated as expired, dropped from the request and **evicted from the in-RAM jar** → Zalo returns code 600. Re-scanning re-seeded the jar, but the next send evicted it again → endless loop.
- Fix summary: (1) Flutter `live_chat_provider.dart` now uses `millisecondsSinceEpoch` for `clientMessageId` (3 send sites). (2) Backend `runWithFixedDateNow` only pins `Date.now()` when the id is within ±10 min of the real clock (`DATE_NOW_PIN_TOLERANCE_MS`); any implausible value is ignored and the real clock is kept. Regression test `runWithFixedDateNow pins Date.now only for a plausible current ms timestamp`.
- Rule: NEVER override the global `Date.now()` with a value that is not a real current-ms timestamp while a zca-js call is in flight — tough-cookie expiry runs on `Date.now()` and will silently drop `zpw_sek`. Keep client message ids in milliseconds. This false-positive `zpw_sek` is distinct from genuine session revocation (websocket 3000/3003) and from on-disk cookie corruption (see memory `zca-cookie-persistence`).
- Related files: `tools/alpha-crm/lib/features/messaging/live_chat/providers/live_chat_provider.dart`, `tools/alpha-crm/integration/zalo-bot-service/src/channels/personal-zca-channel.ts`, `.../personal-zca-channel.test.ts`.

### 2026-06-19 - Local Zalo backend must not silently run on multiple ports

- Symptom: an orphan or stale Alpha CRM Zalo backend could keep one port while a newer backend silently started on a different port. Flutter could also accept any `GET /health` response with `status: ok`, so it could reuse the wrong service or keep talking to a stale backend session after QR re-login.
- Fix summary: `server.ts` now identifies itself via `/health` and `.data/active-port.json` with `service: alpha-crm-zalo-bot-service`, `pid`, `projectRoot`, and `dataRoot`, and refuses Node-side auto fallback on `EADDRINUSE`. `ZaloBackendManager` owns the port policy: prefer 8787, kill only a verified Alpha CRM Zalo backend holding a candidate port, and try the next port only when the owner is another app. Debug/manual active-port discovery now also requires the backend identity.
- Rule: never treat plain `status: ok` as proof that a local service is the Alpha CRM Zalo backend. Port cleanup must be identity-based; do not blind kill a port, and do not let the Node backend recursively choose random ports behind Flutter's back.
- Related files: `tools/alpha-crm/lib/shared/utils/zalo_backend_manager.dart`, `tools/alpha-crm/integration/zalo-bot-service/src/server.ts`, `tools/alpha-crm/test/zalo_backend_manager_port_policy_test.dart`.

### 2026-06-19 - Failed personal-Zalo credentials must not be hidden by generic pool errors

- Symptom: corrupted/revoked `credentials_<uid>.json` files were recorded in `failedAccounts`, but after credential scanning `loginError` could be reset to `null`; send flows then returned the generic `No active connected Zalo accounts in the pool.` instead of the actionable `zpw_sek` / login rejection reason.
- Fix summary: preserve the failed credential reason when all saved credentials fail to load, and make `PersonalZcaChannel.sendMessage()` prefer the matching `failedAccounts` reason when the pool is empty or the requested account failed to load. A successful QR re-login clears stale failed state for that account and stores the exact credential path on the new live instance.
- Rule: if `loadCredentialsFile()` rejects a saved QR session, keep that reason visible to account status and send flows. Do not mask it with generic pool-empty errors. When QR re-login succeeds for the same `uId`, clear `failedAccounts`/`loginError` for that account immediately; otherwise stale code-600 state can leak into the new session. A corrupted credential file still requires fresh QR login; code cannot recreate a missing `zpw_sek`.
- Related files: `tools/alpha-crm/integration/zalo-bot-service/src/channels/personal-zca-channel.ts`, `tools/alpha-crm/integration/zalo-bot-service/src/channels/personal-zca-channel.test.ts`, `tools/alpha-crm/integration/zalo-bot-service/src/server.ts`.

### 2026-06-18 - Mọi lệnh gửi tin Zalo cá nhân fail `zpw_sek bị thiếu hoặc không đúng` (code 600) do ghi đè cookie jar sống ra đĩa

- Symptom: `[PersonalZcaChannel] sendMessage error: ZaloApiError ... zpw_sek bị thiếu hoặc không đúng` (code 600) cho mọi lần gửi, kéo dài qua restart. File `credentials_<uId>.json` chỉ còn vài cookie và **thiếu hẳn `zpw_sek`**.
- Root cause: `persistAccountCredentials()` (gọi lúc login và định kỳ 10 phút qua `startCredentialRefreshTimer`) **re-serialize jar cookie SỐNG** `api.getContext().cookie.serializeSync()` rồi ghi đè file credentials. zca-js giữ cookie trong tough-cookie jar RAM; trong lúc Zalo xoay vòng phiên, jar có thời điểm bị suy giảm/thiếu `zpw_sek`. Một lần flush trúng thời điểm đó là ghi đè file tốt bằng cookie-set không có `zpw_sek` → hỏng phiên trên đĩa vĩnh viễn → `zalo.login()` lần sau (restart) nạp cookie chết → mọi send code 600.
- Fix summary: **Bỏ hoàn toàn việc re-serialize jar ra đĩa** — xóa `persistAccountCredentials` / `persistAllCredentials` / `startCredentialRefreshTimer` và các call site. File credentials là bản QR-login gốc **bất biến** (ghi đúng MỘT lần từ `event.data` sự kiện `GotLoginInfo` trong `personal-login.ts` và handler `/create-qr` ở `server.ts`). Để giữ phiên dài hạn thì RE-LOGIN từ dữ liệu bất biến (Zalo cấp lại cookie mới vào jar RAM), đúng pattern tham chiếu `ZaloCRM/backend/src/modules/zalo/zalo-pool.ts`. Bổ sung: khi `sendMessage` lỗi code 600/`zpw_sek` → `stopListener` + set account `disconnected_expired` để UI Settings hiện ⚠️ "Đăng nhập lại" thay vì fail âm thầm mãi.
- Khôi phục dữ liệu: file credentials đã hỏng KHÔNG thể vá bằng code (cookie `zpw_sek` đã mất) — phải **đăng nhập QR lại** để sinh file mới hợp lệ.
- Rule: **TUYỆT ĐỐI không re-serialize `api.getContext().cookie` ra đĩa.** File credentials chỉ ghi một lần lúc QR login và phải bất biến. Giữ phiên sống bằng re-login (`zalo.login(saved)`), không bằng cách flush jar RAM. Nỗi lo "cookie cũ bị stale sau restart" là sai — cookie QR gốc mới là thứ `zalo.login()` cần; chính việc ghi đè jar đã xoay vòng mới làm hỏng `zpw_sek`.
- Related files: `tools/alpha-crm/integration/zalo-bot-service/src/channels/personal-zca-channel.ts`. Tham chiếu pattern đúng: `D:\Dev\2.reference_pj\.Zalo-ref\ZaloCRM\backend\src\modules\zalo\zalo-pool.ts`.

### 2026-06-18 - GoRouter Assertion Crash when Saving Risk Controls Dialog ('currentConfiguration.isNotEmpty' / '!_debugLocked')

- Symptom: Clicking the "Lưu cài đặt rủi ro" button inside the Risk Controls dialog, or dismissing the dialog while the save operation is in progress, would crash the app. The log shows: `Failed assertion: 'currentConfiguration.isNotEmpty': You have popped the last page off of the stack, there are no pages left to show` followed by `Failed assertion: '!_debugLocked': is not true` during Navigator disposal.
- Root cause: In `settings_screen.dart`, the `onSave` callback inside `_showRiskControlsDialog` performed `await notifier.saveSettings();` and then checked `if (mounted) { navigator.pop(); }`. However, `mounted` referred to the parent `_SettingsScreenState` (the main settings screen), which remains mounted even if the dialog has already been closed. Thus, if the dialog was closed during the save process, `navigator.pop()` was still called on the dialog's navigator context, popping the parent settings screen off the routing stack instead of the dialog.
- Fix summary: Replaced the `if (mounted)` check with `if (context.mounted)` in the `onSave` callback. Since `context` refers to the `Consumer`'s BuildContext within the dialog, `context.mounted` correctly turns `false` if the dialog has been dismissed, preventing the double-pop/crash.
- Rule: Always check `context.mounted` (or the dialog context's mount state) rather than the parent screen/state's `mounted` before popping dialogs after an asynchronous gap.
- Related files: `tools/alpha-crm/lib/features/settings/presentation/screens/settings_screen.dart`

### 2026-06-17 - Tài khoản Zalo cá nhân mất kết nối ngay sau đăng nhập (duplicate 3000) + UI không báo

- Symptom: Đăng nhập QR xong là phiên rớt ngay, lặp lại nhiều lần; UI không hiện cảnh báo nào (vẫn "đã kết nối"). Một số lần socket chết âm thầm nhưng badge vẫn "đang lắng nghe".
- Root cause (3 lỗi độc lập trong `personal-zca-channel.ts`):
  1. `addAccountInstance` **không stop instance cũ** của cùng `uId` trước khi `accountPool.set` ghi đè → websocket realtime cũ vẫn mở → Zalo thấy 2 kết nối cùng tài khoản → force-close code **3000 (DuplicateConnection)**. Mỗi lần đăng nhập lại bỏ rơi thêm 1 socket → cứ đăng nhập là bị đá.
  2. Bản ghi ngắt rơi vào instance **mồ côi** (đã bị set ghi đè khỏi pool) nên `getAccounts()` không thấy → không có cảnh báo. Thêm vào đó `getStatus().connected = accountPool.size > 0` **bỏ qua** `disconnected_expired` → app vẫn "đã kết nối".
  3. Handler `closed` **chỉ xử lý mã 3000/3003**; mọi mã khác (rớt mạng 1006…) không set `listenerRunning=false`, không reconnect → socket zombie: UI "đang lắng nghe" nhưng không nhận tin, không có cơ chế phục hồi.
- Fix summary:
  1. `addAccountInstance`: nếu `accountPool.has(uId)` → `await stopListenerForInstance(existing)` rồi mới thêm instance mới (diệt tự-trùng).
  2. `getStatus().connected` = `connectedAccounts.some(acc => acc.status !== 'disconnected_expired')` thay vì `size > 0`.
  3. Handler `closed`: với MỌI mã → set `listenerRunning=false`. Mã 3000/3003 = `stop` + `disconnected_expired` + lưu `disconnectReason` (không reconnect cookie chết). Mã tạm thời chỉ hạ `listenerRunning=false` và để **`ListenerHealthMonitor` có sẵn** (connected && !listenerRunning → recover mỗi 15s) tự reconnect — không thêm vòng reconnect riêng. Bổ sung `removeAllListeners("closed"/"old_messages")` trong start/stop để tránh double-bind khi reconnect.
- Rule: Mỗi instance Zalo cá nhân chỉ được có **một** listener websocket sống tại một thời điểm — luôn stop instance cũ trước khi tạo phiên mới cho cùng `uId`. Trạng thái kết nối hiển thị cho UI phải dựa trên account còn sống (`status !== 'disconnected_expired'`), không phải số lượng account trong pool. Không nuốt các mã `closed` khác 3000/3003: tối thiểu hạ `listenerRunning` để health monitor phục hồi và badge phản ánh đúng.
- Đa tài khoản: `ListenerHealthMonitor` cũ xét ở mức pool (`connected && !some(listenerRunning)`), nên account thứ 2 rớt khi account thứ nhất vẫn chạy sẽ KHÔNG tự reconnect. Đã sửa: thêm `needsListenerRecovery` (account-aware) vào `ZaloChannelStatus`, `getStatus()` tính `some(acc.status !== 'disconnected_expired' && !acc.listenerRunning)`, và `shouldRecoverZaloListener` ưu tiên cờ này (fallback logic cũ cho mock/official). `addAccountInstance` chỉ dọn instance trùng `uId` nên đăng nhập 2 tài khoản khác nhau không đụng nhau. Recovery (`startListener()`) restart mọi instance dừng, instance đang chạy được guard nên không nhân đôi.
- Related files: `tools/alpha-crm/integration/zalo-bot-service/src/channels/personal-zca-channel.ts`, `.../src/channels/types.ts`, `.../src/local-session/listener-health.ts`, `.../src/server.ts` (luồng QR login gọi `addAccountInstance`), `tools/alpha-crm/lib/app/shell/app_topbar.dart` (badge cảnh báo per-account), `tools/alpha-crm/lib/features/zalo_integration/providers/zalo_integration_provider.dart`.

### 2026-06-16 - esbuild CJS bundle làm `import.meta.url` rỗng → vỡ `projectRoot`/active-port

- Symptom: Khi bundle backend Node sidecar thành 1 file CJS (`dist/server.cjs`) bằng esbuild, server vẫn boot nhưng `projectRoot` sai → `.data/active-port.json` ghi nhầm chỗ, làm Flutter không dò được cổng (lặp lại đúng class lỗi "backend khởi động không đúng").
- Root cause: `src/config.ts` tính `projectRoot` từ `fileURLToPath(import.meta.url)`. Ở output `format: 'cjs'`, `import.meta` không tồn tại nên esbuild thay bằng giá trị **rỗng** (cảnh báo `empty-import-meta`), khiến `fileURLToPath('')` cho đường dẫn sai.
- Fix summary: Trong `scripts/bundle.mjs` thêm `banner.js = "const import_meta_url = require('url').pathToFileURL(__filename).href;"` và `define: { 'import.meta.url': 'import_meta_url' }`. CJS luôn có `__filename`, nên `import.meta.url` trỏ về chính file bundle → `projectRoot` = thư mục service như bản `dist/server.js` chưa bundle.
- Rule: Mọi lần bundle code ESM dùng `import.meta.url`/`import.meta.dirname` sang CJS bằng esbuild, PHẢI shim `import.meta` qua banner + define, hoặc xuất ESM (`format:'esm'`). Đừng bỏ qua cảnh báo `empty-import-meta` — nó là lỗi runtime ngầm. Luôn smoke-test boot bundle và kiểm tra `active-port.json` rơi đúng `<serviceDir>/.data/`.
- Related files: `tools/alpha-crm/integration/zalo-bot-service/scripts/bundle.mjs`, `.../src/config.ts`, `alpha-studio-backend/scripts/release-to-b2.js` (`stageDependencyClosure`, `verifyStagedBackend`), `tools/alpha-crm/lib/shared/utils/zalo_backend_manager.dart`.

### 2026-06-08 - Zalo Image URL Expiration & Local-First Image Rendering Fallback

- Symptom: Images in the Live Chat tab failed to display after a few hours/days, rendering the "Không thể tải ảnh" (Unable to load image) error widget.
- Root cause: Zalo remote image URLs expire quickly. Although the Node.js background media worker (`LocalChatMediaWorker`) successfully downloaded a local copy of each image to `.data/local-chat-media/`, the Flutter client only checked if the attachment had a remote URL (`image.hasRemoteUrl`), and unconditionally attempted to load it using `CachedNetworkImage`, ignoring the cached local path when the remote load failed.
- Fix summary: Introduced `liveChatLocalFileExists` helper in the platform-specific local image stubs/implementations to verify file presence on disk. Updated `_buildMessageContent` in `live_chat_screen.dart` to check if a valid local copy exists (`useLocal = image.hasLocalPath && liveChatLocalFileExists(image.localPath)`) and render the local image using `buildLiveChatLocalImage`, falling back to `CachedNetworkImage` only if the local file is not found. Fixed string encoding typos from `'KhĂ´ng thá»ƒ...'` to `'Không thể...'` in the error widgets.
- Rule: Always check and prioritize loading media from `image.localPath` if it exists on the local filesystem before falling back to remote URLs, as Zalo CDN URLs are short-lived.
- Related files: `tools/alpha-crm/lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`, `tools/alpha-crm/lib/features/messaging/live_chat/utils/live_chat_local_image_io.dart`, `tools/alpha-crm/lib/features/messaging/live_chat/utils/live_chat_local_image_stub.dart`.

### 2026-06-06 - Dart AOT Compilation Bypasses Overridden Getters on Custom Color Subclasses

- Symptom: In dark mode, containers, cards, tables, and borders rendered with white/light backgrounds instead of dark backgrounds in production builds (Windows release executable and Web production target), despite working perfectly in JIT mode (unit/widget tests).
- Root cause: In Dart AOT (Ahead-of-Time) compilation, the compiler optimizes property reads on core types like `Color`. Specifically, the graphics engine reads the color's `value` field directly via memory offset on the native/C++ side, completely bypassing the overridden Dart `value` getter in the custom `ThemeColor` subclass.
- Fix summary: Converted all dynamic colors in `AppColors` from `static const Color` constants to dynamic `static Color get` properties, removed the `ThemeColor` class entirely, and removed the `const` keyword from widgets and text styles referencing the updated colors across 15+ screens, shared widgets, and test files to resolve compilation errors.
- Rule: Never override properties on core Dart types like `Color` or `Duration` when writing cross-platform AOT/production code. Use dynamic getters returning plain standard instances instead.
- Related files: `tools/alpha-crm/lib/app/theme/app_colors.dart`, `tools/alpha-crm/lib/app/theme/app_theme.dart`, `tools/alpha-crm/lib/shared/widgets/app_card.dart`, `tools/alpha-crm/lib/shared/widgets/app_metric_card.dart`, and 15+ screen files.

### 2026-06-05 - Live Chat Polling Must Merge, Not Replace, Active Messages

- Symptom: Live Chat flickered during refresh, old-message scrolling was pulled back to the top, raw rich-preview JSON leaked into conversation previews, and failed outbound messages stayed visible after reopening a chat.
- Root cause: The Flutter provider reloaded the selected messages and the full conversation list on every poll/send, replaced the selected conversation message list wholesale, assumed only `contentType`, and displayed backend preview strings without defensive rich-content formatting.
- Fix summary: Silent polling now refreshes conversations without replacing selected messages, selected messages merge by stable id/provider id, send/attachment no longer trigger a second full conversation reload, failed messages are filtered client-side, messages use `messageType` fallback parsing, and rich-preview JSON is formatted into safe labels.
- Rule: Chat UIs must preserve scroll state and merge incremental updates; do not replace the active message list from background polling unless the user explicitly switches conversations.
- Related files: `tools/alpha-crm/lib/features/messaging/live_chat/providers/live_chat_provider.dart`, `tools/alpha-crm/lib/features/messaging/live_chat/data/live_chat_repository.dart`, `tools/alpha-crm/lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`, `tools/alpha-crm/test/live_chat_provider_test.dart`.

### 2026-06-05 - ZCA Group Events May Carry ThreadType at the Event Root

- Symptom: Some Zalo group conversations could appear as personal/direct chats or use the sender UID as the thread id, causing confusing Live Chat entries and send failures.
- Root cause: The local `PersonalZcaChannel` normalizer checked `data.threadType` and group fields but missed `event.type === ThreadType.Group`, which is a common zca-js listener shape.
- Fix summary: Group detection now checks the root event type, uses root `threadId` for group threads, extends inbound message type detection, allows attachment-only sends, and preserves ZCA error codes in send failures.
- Rule: Normalize zca-js listener events from both root-level and nested `data` fields before deciding thread identity or message type.
- Related files: `tools/alpha-crm/integration/zalo-bot-service/src/channels/personal-zca-channel.ts`, `tools/alpha-crm/integration/zalo-bot-service/src/channels/types.ts`, `tools/alpha-crm/integration/zalo-bot-service/src/agent/command-executor.ts`.

### 2026-06-04 - Windows ZIP Updates Must Self-Apply, Not Just Open Explorer

- Symptom: The in-app Windows updater downloaded the release ZIP, opened it, and then stopped. Users had to manually extract/copy files, so the update did not actually apply.
- Root cause: Portable ZIP releases are not installers. Calling `OpenFilex.open(zipPath)` only opens the archive in Explorer and cannot replace the running `alpha_crm.exe` bundle.
- Fix summary: `AppUpdateService` now generates a detached `apply_update.cmd` helper for ZIP releases. The helper waits for the app to exit, expands the ZIP with PowerShell, finds the folder containing `alpha_crm.exe`, copies files into the current app directory with `robocopy`, restarts the app, and writes an update log.
- Rule: For Windows portable ZIP releases, always launch a separate updater process/script that applies the bundle after the running app exits. Do not use `OpenFilex.open` as an installer for ZIP assets.
- Related files: `tools/alpha-crm/lib/shared/utils/app_update_service.dart`, `tools/alpha-crm/test/app_update_service_test.dart`.

### 2026-06-03 - Device Pairing Must Read `pairedMobileUserIds`, Not Mobile Device Records

- Symptom: On mobile, tapping QR scan did not open a real scanner. Entering the pairing code could show success, but the PC and mobile device pairing screens still appeared unchanged.
- Root cause: The cloud backend does not create separate active Android/iOS `CrmDevice` records for paired phones. It records mobile pairings on the active Windows device in `pairedMobileUserIds`. The Flutter provider incorrectly searched `/crm/devices` for non-Windows active device records, so confirmed pairings were ignored by the UI. The QR button was also a mock dialog rather than a camera scanner.
- Fix summary: Parse paired state from the active Windows device's `pairedMobileUserIds`, accept both 6-digit `pairingCode` and QR `qrToken` confirm payloads, poll the PC pairing screen while waiting, render a real QR with `qr_flutter`, scan it with `mobile_scanner`, and add Android camera permission.
- Rule: Treat the active Windows `CrmDevice` as the host record for mobile pairings unless the cloud backend schema changes; never infer mobile pairing status from separate mobile `CrmDevice` rows.
- Related files: `tools/alpha-crm/lib/features/devices/providers/crm_device_provider.dart`, `tools/alpha-crm/lib/features/devices/presentation/screens/device_pairing_screen.dart`, `tools/alpha-crm/android/app/src/main/AndroidManifest.xml`, `tools/alpha-crm/test/crm_device_provider_test.dart`.

### 2026-06-03 - Windows Localhost vs 127.0.0.1 Loopback Refusal Error

- Symptom: Linking Zalo account or performing health check in the Windows build fails with SocketException (OS Error: The remote computer refused the network connection, errno = 1225).
- Root cause: The local Node.js server binds to `127.0.0.1` (IPv4 loopback), but the Flutter app was configured with `http://localhost:8787` by default. On Windows, `localhost` resolves to `::1` (IPv6 loopback) first. Since the Node.js server was not listening on `::1`, the connection was refused.
- Fix summary: Changed default Zalo Backend Base URL from `http://localhost:8787` to `http://127.0.0.1:8787` in settings config schema, mock defaults, UI fallbacks, and the existing `zalo_settings.json` file.
- Rule: Always use explicit IPv4 `127.0.0.1` instead of `localhost` for local/loopback backend server connections on Windows to avoid IPv6 name resolution issues.
- Related files: `tools/alpha-crm/zalo_settings.json`, `tools/alpha-crm/lib/mock/mock_accounts.dart`, `tools/alpha-crm/lib/features/zalo_integration/data/zalo_integration_api.dart`, `tools/alpha-crm/lib/features/settings/presentation/screens/settings_screen.dart`, `tools/alpha-crm/docs/zalo-integration-installation-and-usage.md`.

### 2026-06-03 - Live Chat Must Preserve Plain Text Inbound Payloads

- Symptom: Live Chat appeared to load only messages that had links/files/rich attachments, while plain text inbound messages were missing or blank; sender avatars also fell back to initials even when Zalo provided an avatar.
- Root cause: The local `PersonalZcaChannel` normalizer only read a narrow set of top-level content/avatar fields. Some zca-js plain text events can carry text in nested objects such as `content.msg`, while avatar URLs may be protocol-relative (`//...`). Flutter Live Chat also only read `content` and `avatarUrl`.
- Fix summary: Added robust inbound content extraction for nested text fields while preserving rich preview JSON for link/file messages, normalized protocol-relative avatars, and extended Flutter Live Chat model parsing to accept `text`, `message`, `avatar`, `customerAvatar`, and related aliases.
- Rule: Zalo inbound payload handling must normalize both top-level and nested message fields, and UI model parsing should accept backend/agent aliases rather than assuming a single field name.
- Related files: `tools/alpha-crm/integration/zalo-bot-service/src/channels/personal-zca-channel.ts`, `tools/alpha-crm/lib/features/messaging/live_chat/providers/live_chat_provider.dart`, `tools/alpha-crm/lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`.

### 2026-06-01 - Background Campaign Start Must Not Complete Campaigns

- Symptom: A campaign command could start asynchronously on the Windows agent, but the backend treated the initial `{ status: 'running' }` report as a final successful result and could mark the campaign `completed` before messages finished sending.
- Root cause: The agent runner reports every command result through the same endpoint, while the backend result handler did not distinguish in-progress reports from final campaign results.
- Fix summary: Backend result handling now stores `{ status: 'running' }` as command status `running` and returns without setting `finishedAt` or changing `CrmCampaign.status`; final background results still complete/cancel the campaign.
- Rule: Long-running agent commands need an explicit in-progress state and must update campaign status only from final result payloads.
- Related files: `alpha-studio-backend/server/routes/crm.js`, `tools/alpha-crm/integration/zalo-bot-service/src/agent/agent-runner.ts`, `tools/alpha-crm/integration/zalo-bot-service/src/agent/command-executor.ts`.

### 2026-06-02 - Zalo Group Dropdown Assertion Crash (g['groupId'] vs g['id'])

- Symptom: Opening "Kết bạn từ nhóm" -> "Chọn từ nhóm Zalo" threw a Flutter DropdownButton assertion crash (`items == null || items.isEmpty || ...`).
- Root cause: `FriendByGroupNotifier.loadGroups` mapped backend group records using `id: g['groupId']` instead of the correct `g['id']` returned by ZCA API, causing all loaded groups to fallback to an empty string `""` as their ID, which created multiple dropdown items with duplicate empty string values.
- Fix summary: Changed group mapping in `FriendByGroupNotifier.loadGroups` to map `id: g['id']` and safely parse `memberCount: int.tryParse(g['memberCount']?.toString() ?? '0') ?? 0` to align with the backend payload.
- Rule: Always align Zalo group structure parsing across providers (such as `InviteToGroupNotifier`, `LeaveGroupsNotifier`, and `FriendByGroupNotifier`) to use `id: g['id']` and robustly parse `memberCount` via `int.tryParse`.
- Related files: `tools/alpha-crm/lib/features/friends/by_group/providers/friend_by_group_provider.dart`.

### 2026-06-02 - Zalo Group Member Scanning 0-Member Failure due to Account Mismatch

- Symptom: Selecting a group from the Zalo groups dropdown in "Kết bạn từ nhóm" yielded 0 members and failed scanning with: `[PersonalZcaChannel] Found 0 members in group <groupId>`.
- Root cause: The dropdown returned groups belonging to all logged in accounts, but the member scanner utilized the currently active Zalo account from the config. When an account attempted to read members of a group it did not belong to, the ZCA API returned empty details/errors.
- Fix summary: Modified backend Zalo adapters (`PersonalZcaChannel`, `MockZaloChannel`) to return `accountId` alongside group info. Updated Flutter provider group builders to map `accountId` to ZaloGroup models. Configured the dropdown list in UI screens (`friend_by_group_screen.dart`, `invite_to_group_screen.dart`) to dynamically filter the Zalo groups, showing only groups that belong to the currently selected sending Zalo account.
- Rule: Always filter target groups dropdown lists by the selected active account ID in the UI scaffolding to prevent empty member API results and permissions errors.
- Related files: `tools/alpha-crm/integration/zalo-bot-service/src/channels/personal-zca-channel.ts`, `tools/alpha-crm/integration/zalo-bot-service/src/channels/mock-channel.ts`, `tools/alpha-crm/lib/features/friends/by_group/presentation/screens/friend_by_group_screen.dart`, `tools/alpha-crm/lib/features/groups/presentation/screens/invite_to_group_screen.dart`.

### 2026-06-04 - State copyWith Method Clearing Optional Fields (complianceError) Implicitly

- Symptom: When bulk campaigns were started and then blocked/paused due to compliance (e.g. Quiet Hours), the compliance error banner did not show up on the Flutter screen and the execution status logs did not display metrics correctly.
- Root cause: In `BulkMessagingState`'s `copyWith` method, `complianceError` and `complianceWarning` fields did not have null-coalescing fallback operators (`?? this.complianceError`). Therefore, any state update that did not explicitly pass these fields (like connection updates or heartbeats from `zaloIntegrationProvider`) implicitly cleared them to `null`. Additionally, `BulkMessagingScreen` was completely missing the log console widget.
- Fix summary: Modified `copyWith` to default to the current state values, introducing `clearComplianceError: true` and `clearComplianceWarning: true` boolean flags when we explicitly want to clear them. Simplified `_checkCompliance` state updates and updated all log calls to use `LogItem` instead of `String`. Added `ActivityLogPanel` to the `BulkMessagingScreen` UI under the metrics cards.
- Rule: Do not write `field: field` in State `copyWith` methods to allow clearing fields. Instead, use `field: clearField ? null : (field ?? this.field)` to prevent state changes from accidentally wiping unrelated status properties.
- Related files: `tools/alpha-crm/lib/features/messaging/bulk/providers/bulk_messaging_provider.dart`, `tools/alpha-crm/lib/features/messaging/bulk/presentation/screens/bulk_messaging_screen.dart`.
### 2026-06-11 - Windows Video Playback Requires A Windows Plugin Implementation

- Symptom: Mở video trong Live Chat trên Windows làm ứng dụng ném `UnimplementedError: init() has not been implemented` từ `VideoPlayerPlatform.init`.
- Root cause: Gói `video_player` không cung cấp implementation cho Windows, nên `VideoPlayerController.initialize()` gọi vào implementation mặc định chưa được cài đặt.
- Fix summary: Thay `video_player` bằng `media_kit`, `media_kit_video` và `media_kit_libs_video`; gọi `MediaKit.ensureInitialized()` khi khởi động và dùng `Player`/`VideoController` trong màn hình video.
- Rule: Không dùng `video_player` cho tính năng phát video đa nền tảng có Windows. Mọi chuỗi giao diện tiếng Việt mới phải dùng UTF-8 và đầy đủ dấu; duy trì test hồi quy cho các thông báo Live Chat.
- Related files: `tools/alpha-crm/pubspec.yaml`, `tools/alpha-crm/lib/main.dart`, `tools/alpha-crm/lib/features/messaging/live_chat/presentation/screens/live_chat_video_screen.dart`, `tools/alpha-crm/test/live_chat_video_configuration_test.dart`.

# Live Chat Provider IDs And Media Cache

- Zalo reaction/recall must use `zaloMsgId`/`providerMessageId`; CRM row IDs are not valid provider action IDs.
- Local bridge action lookup accepts either its SQLite row ID or the provider ID, but successful recall must mark the resolved local row ID deleted only after the Zalo API succeeds.
- Cached media is exposed through `/local/media/:attachmentId`; video responses must preserve HTTP Range support.
- Never call `Uri.decodeComponent` on untrusted attachment names without catching malformed percent encoding.
