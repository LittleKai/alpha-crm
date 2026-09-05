# Important Fixed Bugs

**Last Updated:** 2026-07-04 +07:00

---

## Lỗi ParentDataWidget gây crash app khi mở tab Nhật ký / Lỗi hệ thống

**Triệu chứng:** Mở tab "Nhật ký hoạt động" hoặc "Lỗi hệ thống" trong cài đặt gây crash ứng dụng Flutter ngay lập tức với thông báo lỗi: `⛔ Flutter Framework Error: Incorrect use of ParentDataWidget. The offending Expanded is currently placed inside a Wrap widget.`

**Nguyên nhân:** Cả `live_logs_tab.dart` và `reported_errors_tab.dart` đều sử dụng widget `Spacer` (bản chất chứa `Expanded` bên trong) trực tiếp bên trong widget `Wrap`. `Expanded` chỉ có thể đặt bên trong một widget `Flex` (như `Row`, `Column`) để nhận `FlexParentData`, trong khi `Wrap` cung cấp `WrapParentData`.

**Cách sửa:** Loại bỏ `Spacer` ra khỏi `Wrap`. Thay vào đó, thiết lập `alignment: WrapAlignment.spaceBetween` trên `Wrap` và gom nhóm các nút thao tác bên phải vào một `Row(mainAxisSize: MainAxisSize.min)` (hoặc `Wrap`) để đạt được bố cục tương đương mà không bị crash.

**Quy tắc cần nhớ:** Tuyệt đối không dùng `Spacer` hoặc `Expanded` trực tiếp trong `Wrap`. Luôn dùng `WrapAlignment` hoặc bọc các widget con vào `Row`/`Column` nếu muốn căn chỉnh khoảng cách.

**Các file liên quan:** `tools/alpha-crm/lib/features/settings/presentation/widgets/live_logs_tab.dart`, `tools/alpha-crm/lib/features/settings/presentation/widgets/reported_errors_tab.dart`.

---

## Live Chat desktop không có realtime — chỉ dựa vào polling 12s (chết khi rời tab)

**Triệu chứng:** Trên bản desktop production, tin nhắn Zalo mới chỉ được phát hiện sau tối đa 12s
polling timer sống trong `State` của `LiveChatScreen`. Vì timer đó bị `dispose()` khi rời tab, việc
rời khỏi Live Chat để làm việc khác khiến ứng dụng KHÔNG BAO GIỜ báo tin nhắn mới cho đến khi người
dùng tự quay lại tab và polling chạy lại.

**Nguyên nhân:** `LiveChatRepository.watchEvents()` chỉ mở local SSE stream khi `localFirstEnabled ==
true`, nhưng setting `localFirstLiveChat` mặc định `false` và không có UI để bật. Mọi hành động local
khác trong repository đều dùng pattern `_preferLocalZaloActions || localFirstEnabled` (đúng trên
desktop), riêng `watchEvents()` bị bỏ sót và chỉ check `localFirstEnabled` một mình → luôn rơi vào
`return const Stream.empty()` trên desktop. Cùng nhóm lỗi với bug "Bot toggle" trước đây (gate thiếu
`_preferLocalZaloActions`).

**Cách sửa:** Đổi gate thành `if (!_preferLocalZaloActions && !localFirstEnabled) return const
Stream.empty();` (`live_chat_repository.dart`) + test hồi quy `test/live_chat_repository_watch_events_test.dart`.
Đồng thời thêm timeout không hoạt động 60s cho SSE client
(`live_chat_local_bridge_api.dart::watchEvents`) vì backend gửi `: heartbeat` mỗi 20s — quá 60s
không có dữ liệu nghĩa là socket đã chết im lặng, cần ném lỗi để notifier tự reconnect thay vì treo
`realtimeConnected = true` mãi mãi (khi đó fallback polling bị gate `!realtimeConnected` sẽ không bao
giờ chạy). **Quy tắc cần nhớ:** mọi capability local-bridge mới PHẢI dùng pattern
`_preferLocalZaloActions || localFirstEnabled`, không bao giờ dùng `localFirstEnabled` một mình.

**Bổ sung — hardening supervisor backend (`zalo_backend_manager.dart`):** probe `/health` timeout
2s→5s và ngưỡng lỗi liên tiếp 2→3 lần (chịu đựng query đồng bộ `better-sqlite3` chặn event loop vài
giây), thêm cờ chống chồng chéo (`_ticking`) cho mỗi nhịp watchdog, circuit breaker không còn latch
vĩnh viễn mà tự thử lại một lần sau mỗi 5 phút cooldown (nút "Thử lại" thủ công vẫn hoạt động song
song), và sửa race điều kiện exit-listener cũ trong `waitUntilReady` (listener của tiến trình bị kill
trong một chu kỳ restart trước đó có thể ghi đè trạng thái của lần khởi động mới). Backend
(`server.ts`) cũng bắt thêm `process.on('uncaughtException', ...)` bên cạnh `unhandledRejection` sẵn
có, để một lỗi throw đồng bộ từ trong callback listener zca-js không giết chết tiến trình.

---

## Tóm tắt nhóm "Tiếp tục từ lần trước" (incremental) luôn lấy TOÀN BỘ tin nhắn dù đã có lịch sử tóm tắt

**Triệu chứng:** Trong Tab Quản lý nhóm CRM, chế độ tóm tắt incremental đáng lẽ chỉ lấy tin
nhắn MỚI sau lần tóm tắt trước (vd 0 tin), nhưng `previewMessageCount`/`summarizeWithConfig`
lại lấy hết 92 tin (toàn bộ nhóm).

**Nguyên nhân:** Local store (`local-chat-store.ts`) lưu `messages.createdAt` là cột **TEXT**
ISO-8601 UTC (`2026-06-23T11:30:47.000Z`) và lọc con trỏ `after` bằng **so sánh chuỗi**
(`WHERE createdAt > ?`). Nhưng `_gatherLocalGroupMessages` (managed_groups_provider.dart) lại
truyền `after` dưới dạng **epoch-milliseconds** (`coveredTo.millisecondsSinceEpoch`, vd
`"1718000000001"`). So sánh chuỗi `"2026-…Z" > "1718…"` → `'2' > '1'` → ĐÚNG với MỌI hàng →
watermark không lọc gì → lấy hết tin. Mode `range` dính cùng lỗi.

**Cách sửa:** Truyền `after` dạng UTC ISO string khớp cột TEXT (bỏ `+1ms` vì `>` đã exclusive),
range `after = DateTime.now().subtract(...).toUtc().toIso8601String()`. Đồng thời watermark
incremental lấy từ **local cache** `GroupSummaryLocalStore.loadSummaries` (max `coveredTo`) thay vì
`state.selectedSummaries` in-memory — để nhóm CÓ lịch sử không rơi về "đọc hết" khi danh sách
summary cloud chưa load / offline. **Chỉ sửa Flutter**, không đụng backend. Bài học: con trỏ
phân trang của local-chat là ISO TEXT, KHÔNG phải epoch.

---

## Biểu đồ "Hiệu suất chiến dịch" luôn count = 0 cho chuỗi Bạn bè (dù lịch sử kết bạn có dữ liệu)

**Triệu chứng:** Tab "Lịch sử kết bạn" hiển thị đúng số liệu (vd 3 thất bại), nhưng
biểu đồ Báo cáo hiệu suất chiến dịch trên Dashboard luôn vẽ `friendSuccess`/`friendFailure` = 0.

**Nguyên nhân:** Hai bề mặt dùng hai nguồn dữ liệu KHÁC nhau:
- Tab lịch sử đọc SQLite **local** `friend_history` (ghi bởi `friendHistoryProvider.addRecord` trong các campaign by_phone/by_group).
- Biểu đồ đọc **cloud** `CrmExecutionLog` qua `/crm/dashboard/campaign-performance`, vốn CHỈ log campaign *gửi tin nhắn*. Kết bạn chạy qua local zalo-bot-service, không bao giờ tạo `CrmExecutionLog` → endpoint không trả `friendSuccess/friendFailure` → chuỗi friend luôn 0.

**Cách sửa:** Nạp chuỗi friend của biểu đồ từ chính `friend_history` local (giống cách
đã merge chatbot stats local). Xem `dashboard_chart_data.dart::mergeFriendStatsIntoPerformanceData`
và `dashboard_provider.dart::_buildFriendDailyStats`. KHÔNG cần sửa cloud backend.

---

## Giờ im lặng (và mọi thiết lập kiểm soát rủi ro) trong UI không có tác dụng — backend vẫn chặn theo env mặc định

**Triệu chứng:** Đặt "giờ im lặng từ 23:00" trong UI Kiểm soát rủi ro nhưng gửi kết bạn/tin nhắn vẫn bị chặn.

**Nguyên nhân:** Compliance enforce ở backend (`zalo-bot-service/src/compliance.ts`)
đọc cấu hình CHỈ từ **env vars** lúc khởi động (`config.ts`, mặc định quiet hours `21:00–08:00`,
`allowFriendAutomation=false`...). UI Flutter lưu `SystemSettings` local nhưng `saveSettings()`
**không** gửi các field này xuống backend → backend luôn dùng mặc định env.

**Cách sửa:** Thêm endpoint backend `POST /api/zalo/compliance/settings` (xem
`risk-control-store.ts`) persist vào `dataRoot/integrations/risk-control.json` và overlay
lên `config` lúc runtime + khởi động. Flutter `saveSettings()` POST các field risk-control
xuống endpoint này. **Lưu ý:** thay đổi backend cần `npm run bundle` lại cho bản release đóng gói.

---

## App Windows treo hoàn toàn (render được màn chính nhưng không click/scroll/focus, CPU ~1.3 lõi)

**Triệu chứng:** App mở lên, vẽ được màn hình chính nhưng đơ tuyệt đối — không
focus/scroll/click. Clean/pub get/cài lại Flutter/xóa build/revert git **đều vô tác
dụng**; dự án Flutter khác chạy bình thường; cả bản Release cũng treo. App vẫn
`Responding=True` nhưng đốt ~1.3 lõi CPU liên tục.

**Nguyên nhân THẬT (xác nhận bằng VM Service + `debugPrintRebuildDirtyWidgets`):**
`WarningIconButton` (nút "Trung tâm Tuân thủ & An toàn" — có ở header MỌI màn rủi ro
cao) chạy `AnimationController.repeat(reverse: true)` **vô hạn** cho hiệu ứng hào quang
nhấp nháy. Animation này ép engine dựng frame ở 60fps **mãi mãi**. Màn chính có các
glass-card **`BackdropFilter` (blur)** — loại layer **không thể cache** → mỗi frame
phải rasterize lại trên **luồng raster của engine** (không phải Dart isolate). Trên
máy này chi phí blur/frame vượt ngân sách → frame dồn ứ → luồng platform (xử lý input
Win32 + present) nghẽn → cửa sổ render nhưng chết input.

**Bằng chứng quyết định:**
- VM `getCpuSamples` trên main isolate ≈ **0 mẫu** dù CPU 1.3 lõi → chi phí nằm ở luồng
  raster (C++/Skia), không phải Dart.
- Tắt `repeat()` → CPU **0.02s/6s (idle)**, hết treo. Bật lại → 1.3 lõi.
- `RepaintBoundary` quanh nút **KHÔNG cứu được** vì `BackdropFilter` re-raster mỗi frame
  bất kể ai vẽ; vấn đề là "có frame được dựng liên tục", không phải vùng vẽ của nút.

**Khắc phục:** Bỏ animation lặp vô hạn — `WarningIconButton` thành `StatelessWidget`
với hào quang **TĨNH** (BoxShadow blur cố định). Không còn frame 60fps liên tục →
BackdropFilter chỉ vẽ khi có tương tác thật → idle khi rảnh.

**Bài học:**
1. "Render được nhưng chết input" trên Flutter desktop = luồng UI/raster bị bão hoà,
   KHÔNG phải lỗi layout.
2. CPU cao + `getCpuSamples` main isolate ~0 ⇒ thủ phạm ở **luồng raster** (paint/composite).
3. TUYỆT ĐỐI tránh `AnimationController.repeat()` vô hạn (glow/shimmer/pulse trang trí)
   khi sau/ quanh nó có `BackdropFilter`/glass-card — nó biến hiệu ứng trang trí thành
   re-blur toàn màn 60fps. Nếu cần animation, phải bỏ BackdropFilter ở vùng đó hoặc dùng
   hiệu ứng không cần re-raster nền.

**Phụ (hardening, KHÔNG phải nguyên nhân treo này):** `ZaloBackendManager._killProcess`
trước đây gọi `Process.runSync('taskkill'...)` ĐỒNG BỘ trên isolate UI (chính tác giả
đã ghi chú gây treo ở `prepareForShutdown`). Đã đổi sang `Process.run` bất đồng bộ
(timeout 5s) để vòng restart của watchdog không bao giờ block UI. Mọi spawn/kill backend
phải BẤT ĐỒNG BỘ — không `*Sync`/blocking trên main isolate. Cũng đừng để backend dev
`node --watch` sót giữa các phiên (gây tranh cổng 8787 + storm reconnect riêng).


---

## Toggle Bot trong Live Chat tự tắt (sai đường route lên cloud)

**Triệu chứng:** Bấm bật toggle Bot thì lập tức tắt lại; không có log. Mọi bản vá
ở local bridge (default-ON, account gate, `resolveChatbotStore`) đều vô tác dụng.

**Nguyên nhân (tìm ra bằng log `[bot-toggle]`):** `LiveChatRepository.updateChatbotState`
là **hành động Zalo DUY NHẤT** chỉ kiểm tra `localFirstEnabled` (mặc định false),
trong khi mọi hành động khác (getConversations, sendMessage, markRead...) dùng
`_preferLocalZaloActions || localFirstEnabled` (`_preferLocalZaloActions` hardcode
`true`). Hậu quả: hội thoại Zalo local nhưng toggle lại gọi cloud
`PUT /crm/conversations/:id` → cloud trả **500** ("Lỗi server khi cập nhật hội
thoại") → Flutter revert optimistic flip → toggle nảy về OFF. Local bridge không
bao giờ được gọi nên các fix ở đó không có hiệu lực.

**Khắc phục:** Đổi điều kiện thành `_preferLocalZaloActions || localFirstEnabled`
để khớp với mọi hành động Zalo khác → toggle đi qua local bridge.

**Bài học:** Khi sửa mãi không ăn, dừng đoán — thêm log ở **biên** (request/response
2 phía). Log lộ ngay URL `fly.dev/.../crm/conversations` + status 500, tức là sai
backend đích, không phải lỗi logic trong local bridge.

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

### 2026-09-05 - Backend cục bộ chưa bao giờ tắt sạch trên Windows → SQLite không được đóng, WAL phình vô hạn

- Symptom: `live-chat.sqlite-wal` lớn hơn cả file DB chính (4.17MB vs 4.05MB) và mtime của DB chính đứng yên 2 tháng — toàn bộ tin nhắn trong khoảng đó chỉ tồn tại trong WAL. Không có triệu chứng nhìn thấy trên UI cho tới khi mất dữ liệu hoặc DB hỏng.
- Root cause: `process.on(SIGINT/SIGTERM)` trong `server.ts` là **dead code trên Windows** — Dart `Process.kill()` và `taskkill /T /F` đều là TerminateProcess, Node không nhận signal. Nên `shutdown()` chưa từng chạy; và `closeLocalChatStore()` là export **không có caller nào** trong toàn repo. SQLite không được đóng lần nào ⇒ không có checkpoint lúc thoát.
- Fix summary: thêm `POST /internal/shutdown` (loopback + bắt buộc header `x-alpha-crm-shutdown` để preflight của trình duyệt không tới được); `shutdown()` gọi `closeLocalChatStore()` và có timer thoát cưỡng bức 3s; Flutter `ZaloBackendManager.shutdownGracefully()` gọi endpoint này rồi chờ `exitCode` trước khi kill, dùng ở `exitApp()` và luồng cập nhật ZIP. Store thêm `checkpoint(reason)` chạy cả lúc **boot** (dọn WAL tồn của phiên trước) lẫn lúc `close()`, cộng pragma `busy_timeout=5000` và `synchronous=NORMAL`.
- Rule: **không bao giờ dựa vào SIGINT/SIGTERM để tắt sạch trên Windows.** Mọi tài nguyên cần đóng có trật tự (SQLite, file handle) phải đi qua `/internal/shutdown`. Ai thay `shutdownGracefully()` bằng kill thẳng là tái tạo lại đúng lỗi này. Checkpoint lúc boot là lớp bảo vệ độc lập: đã kiểm chứng rằng sau nó, một lần kill cứng vẫn để lại WAL 0 byte.
- Related files: `tools/alpha-crm/integration/zalo-bot-service/src/server.ts`, `.../src/local-chat/local-chat-store.ts`, `tools/alpha-crm/lib/shared/utils/zalo_backend_manager.dart`, `.../desktop_window_manager.dart`, `.../app_update_service.dart`.

### 2026-07-05 - Live Chat composer bị khóa nhầm cho hội thoại Facebook/TikTok (gate "connected" chỉ tính theo Zalo account pool)

- Symptom: Mở hội thoại Facebook Page/TikTok trong Live Chat (chế độ local-bridge), ô soạn tin bị vô hiệu hóa như thể tài khoản "đã ngắt kết nối", dù integration Facebook/TikTok tương ứng đang bật và hoạt động bình thường.
- Root cause: Trong `live_chat_screen.dart`, ở nhánh transport không phải `cloudRemote`, `isAccountConnected` được suy ra bằng cách tìm `conversation.accountId` trong `zaloState.accounts` (`zaloIntegrationProvider`, Zalo-only) qua `firstWhere(..., orElse: () => ZaloConnectedAccount(..., connected: false, status: 'disconnected_expired'))`. Vì accountId của Facebook Page/TikTok không bao giờ khớp bất kỳ Zalo account nào, mọi hội thoại ngoài Zalo đều rơi vào `orElse` → `connected=false` → composer bị khóa vĩnh viễn cho kênh đó.
- Fix summary: Chỉ áp dụng gate theo Zalo account pool khi `conversation.channel` là `zaloPersonal`/`zaloOa`; các channel khác (`facebookPage`, `tiktok`, và channel tương lai) mặc định `isAccountConnected = true` — kết nối của chúng do integration settings riêng (`enabled` flag) quản lý, không qua Zalo pool.
- Rule: Không bao giờ tái sử dụng trạng thái "connected" của Zalo account pool để gate UI cho hội thoại của channel khác — luôn kiểm tra `conversation.channel` trước. Lỗi này sẽ tái diễn mỗi khi thêm channel mới vào Live Chat nếu không thêm nhánh theo channel tương tự.
- Related files: `tools/alpha-crm/lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`.

### 2026-07-03 - Self-echo Zalo messages double-reported to cloud and bumped unread; explicit `unreadCountDelta: 0` swallowed by `|| 1`

- Symptom: on mobile/web (cloud SSE mode), every message the operator sent from Desktop/chatbot flipped the conversation to "unread" and risked duplicate CrmMessage rows; inbound customer bubbles never appeared in local-first mode.
- Root cause: (1) zca-js runs with `selfListen: true`, so every outbound send comes back as a listener echo into `handleInboundMessageEvent`, which re-reported it to the cloud (`reportInboundMessageMetadata`) with a **hard-coded `unreadCountDelta: 1`** — even though `outbound-reporter` had already reported the same message at send time (dedupe only by `providerMessageId`, racy). (2) The backend's metadata branch used `$inc: { unreadCount: Number(event.unreadCountDelta) || 1 }`, so an explicit `0` was silently turned back into `+1`. (3) In local-first mode ALL inbound (even 1:1) was metadata-only, so the cloud never stored/published inbound content.
- Fix summary: agent skips the cloud report for echoes/duplicates (`reconciledId || existingProviderMessage`); 1:1 threads now report FULL content in local-first mode (option (b)) while managed groups stay metadata-only; `reportInboundMessageMetadata` computes `unreadCountDelta` (0 when `senderId === accountId`); backend uses `Number.isFinite(...)` so an explicit 0 delta survives.
- Rule: there is exactly ONE cloud report per message — at send time via `outbound-reporter` for CRM/chatbot sends, or via the listener path for everything else. When adding a new send path, either hook `reportOutboundMessageEvent` at send time (and ensure the echo reconciles via `clientMessageId`) or let the echo report it — never both. Never write `Number(x) || fallback` when `0` is a meaningful value.
- Related files: `tools/alpha-crm/integration/zalo-bot-service/src/agent/agent-runner.ts`, `tools/alpha-crm/integration/zalo-bot-service/src/agent/cloud-api.ts`, `alpha-studio-backend/server/routes/crm.js` (`upsertConversationFromInbound`).

### 2026-06-22 - Dialog "Đóng" button popped the GoRouter page (whole-app crash) via captured outer context

- Symptom: Opening the group AI-summary history dialog ("Lịch sử tóm tắt") then tapping "Đóng" crashed the app: `currentConfiguration.isNotEmpty: You have popped the last page off of the stack` followed by `!_debugLocked` during Navigator dispose.
- Root cause: `showGroupSummaryHistory(BuildContext context, ...)` built `AppDialog` directly in `showDialog(builder: (_) => AppDialog(... onPressed: () => Navigator.of(context).pop()))`. The action closure captured the **outer caller `context`** (the screen, under the root GoRouter Navigator), so `pop()` popped the last GoRouter page instead of the dialog route.
- Fix: name the builder's context (`builder: (dialogContext) => ...`) and pop `dialogContext`.
- Rule: When `showDialog(builder: (ctx) => Widget(...))` builds the dialog inline and its buttons need to close it, always close over the builder's `ctx` — never the function's outer `context`. (If the dialog body is its own widget, e.g. the summary wizard/settings/preview dialogs, its build context is already under the dialog route, so popping there is safe.) Same family as the 2026-06-18 GoRouter pop crash.
- Related files: `tools/alpha-crm/lib/features/groups/manage/presentation/widgets/group_summary_history_dialog.dart`.

### 2026-06-21 - Windows debug run must not reuse a stale single-instance window

- Symptom: `flutter run -d windows` built successfully, then failed with `Error waiting for a debug connection: The log reader stopped unexpectedly, or never started.` The visible `alpha_crm.exe` window could be an old hung instance that could not be focused, clicked, or scrolled.
- Root cause: the native Windows runner enforced `Global\AlphaCRM_SingleInstance` even in Debug builds. A stale/hung previous `alpha_crm.exe` kept the mutex, so every new `flutter run` process exited after trying to focus the old window. Flutter never got a debug connection to the newly launched process because no new debug process survived.
- Fix summary: disable the single-instance mutex in `_DEBUG` builds so `flutter run` always launches its own debuggable process. Release builds still enforce single-instance, but now probe the existing window with `SendMessageTimeoutW(WM_NULL, SMTO_ABORTIFHUNG)` before treating it as reusable.
- Rule: do not apply production single-instance focus-forward logic to Flutter Debug runs. If single-instance is used in Release, never assume an existing HWND is usable without a hang-safe responsiveness probe.
- Related files: `tools/alpha-crm/windows/runner/main.cpp`.


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

### 2026-06-23 - Release `flutter build windows` chết vì CMakeCache cũ lệch generator platform

- Symptom: `node scripts/release-to-b2.js --windows --local` chạy `flutter build windows --release` báo `CMake Error: Error: generator platform: x64 Does not match the platform used previously:` (vế "used previously" RỖNG) → `Unable to generate build files` → abort release. Lỗi xảy ra DÙ đã `flutter clean` trước đó.
- Root cause: `build/windows/x64/CMakeCache.txt` còn sót (hoặc bị một lần build hỏng tái tạo dở) với `CMAKE_GENERATOR_PLATFORM` rỗng/lệch. `flutter clean` không phải lúc nào cũng xóa được `build/windows` (file bị khóa bởi một tiến trình app/smoke-test đang chạy, hoặc bị một lần build lỗi tạo lại cache dở).
- Fix summary: Xóa cứng thư mục `tools/alpha-crm/build/windows` (`Remove-Item -Recurse -Force`) rồi chạy lại script release. Build sạch tái sinh CMakeCache đúng x64 và đi qua tới bước stage backend + zip.
- Rule: Khi release Windows báo lỗi CMake "generator platform … does not match", ĐỪNG chỉ `flutter clean` — xóa hẳn `build/windows` (đảm bảo không còn `alpha_crm.exe`/node smoke-test nào đang giữ file) rồi build lại. Đây là tiền điều kiện trước mọi lần `release-to-b2.js --windows`.
- Related files: `alpha-studio-backend/scripts/release-to-b2.js`, `tools/alpha-crm/build/windows/` (build artifact, gitignored).

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

### 2026-06-23 - Per-Account `blockTyping` Setting Was Never Enforced

- Symptom: Bật "block typing" cho một tài khoản Zalo nhưng hệ thống vẫn gửi sự kiện "đang soạn tin" (typing) tới Zalo từ Live Chat và chatbot.
- Root cause: `account-settings.json` lưu cả `blockSeen` và `blockTyping`. `blockSeen` được kiểm tra trước khi gửi seen (`local-chat-api.ts`), nhưng `blockTyping` không được kiểm tra ở bất kỳ đâu — `handleLocalTyping` gọi thẳng `sendTyping`.
- Fix summary: Chặn ngay tại chokepoint `PersonalZcaChannel.sendTyping` (`if (readAccountSettings()[accountId]?.blockTyping === true) return false;`) để áp dụng cho mọi đường gọi (Live Chat + chatbot), thay vì chỉ vá riêng endpoint typing.
- Rule: Khi thêm một cờ cấu hình hành vi gửi tới Zalo (kiểu `blockSeen`/`blockTyping`), phải nối dây cờ đó ở chokepoint của hành động tương ứng, không để cờ "định nghĩa nhưng không thực thi".
- Related files: `tools/alpha-crm/integration/zalo-bot-service/src/channels/personal-zca-channel.ts`.

### 2026-06-25 - Live Chat history does not load when backend comes online after startup

- Symptom: Opening the Live Chat tab displays the active/selected conversation metadata in the sidebar, but the messages panel remains completely empty and SSE real-time stream is not connected.
- Root cause: `liveChatProvider`'s notifier initializes on startup. The initial `loadConversations` call fails because the local backend is offline. When the backend comes online, `_pollingTimer` in `LiveChatScreen` triggers a silent refresh (`loadConversations(silent: true)`). Since `silent` is true, the message loading block `loadMessages` and SSE event subscription `_subscribeToEvents` were skipped. As a result, the selected conversation would remain without any loaded messages.
- Fix summary: Updated `loadConversations` to load messages and subscribe to the SSE stream if a conversation is selected but has empty messages, or if the selected conversation changes (even if it's a silent load). Added automatic reloading of accounts and conversations upon receiving the `bridge.connected` real-time event.
- Rule: Always load messages and subscribe to SSE when a conversation is first resolved/selected (e.g., when the backend comes online), even if the refresh is silent. Ensure that when real-time connection succeeds (`bridge.connected`), both accounts and conversations are fully reloaded to refresh the UI state.
- Related files: `tools/alpha-crm/lib/features/messaging/live_chat/providers/live_chat_provider.dart`.

### 2026-06-25 - Live Chat Screen crashes on dispose/hot-restart with defunct element assertion

- Symptom: When navigating away from the Live Chat screen or performing a hot restart, the application crashes with: `Failed assertion: line 5340 pos 12: '_lifecycleState != _ElementLifecycle.defunct': is not true.` inside `Element.markNeedsBuild`.
- Root cause: In `live_chat_screen.dart`'s `dispose()`, we called `ref.read(liveChatProvider.notifier).setChatFocused(false)` to update the focus state synchronously. Since this happens during widget tree teardown, updating the provider's state notified other child elements that were also in the process of being disposed/unmounted, which in turn called `markNeedsBuild()` on defunct/defuncting elements. Additionally, `_scrollMessagesToBottom` did not guard its scroll controller actions with a `mounted` check, leading to potential post-disposal assertions.
- Fix summary: Wrapped `setChatFocused(false)` inside `WidgetsBinding.instance.addPostFrameCallback` with a try-catch block to defer focus state updates until after the widget tree teardown completes. Added `if (!mounted) return;` at the beginning of `_scrollMessagesToBottom`'s post-frame callback.
- Rule: Never modify Riverpod provider states synchronously inside a State's `dispose()` method if those providers have active UI listeners. Always defer updates to a post-frame callback (or microtask) and wrap them defensively. Always guard async/post-frame callbacks that access scroll controllers with `mounted` checks.
- Related files: `tools/alpha-crm/lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`.

### 2026-06-26 - Zalo Calls Rendered as 'sendBubbleMessage' and Links Rendered as File Cards

- Symptom: (1) Zalo call messages in Live Chat were displayed inside a file card with the text "sendBubbleMessage" instead of a proper description like "Cuộc gọi thoại" or "Cuộc gọi nhỡ". (2) Web links (like chatgpt share links) were rendered as file card widgets with download/open buttons rather than proper link previews.
- Root cause: (1) Zalo call messages have `msgType = 'sendBubbleMessage'` and `content = 'sendBubbleMessage'` with details in `params`. The backend did not normalize them, falling back to sending `'sendBubbleMessage'` as raw text content. In Flutter, because the content type wasn't recognized, it fell through to a file card preview. (2) `_getFileInfo` in `_MessageBubble` intercepted any message where `params.fType == 1`. Link previews often contain `fType: 1` but no `fileExt`, causing links to be incorrectly detected as files.
- Fix summary: (1) Added a call-detection block in backend `normalizeInboundMessage` to parse call actions (`recommened.misscall` / `recommened.calltime` / `call_id`) and format call durations into user-friendly strings like "📵 Cuộc gọi nhỡ" and "📞 Cuộc gọi (15s)". (2) Updated `_getFileInfo` in `_MessageBubble` to return null if `msg.contentType == 'link'` or if `params.fileExt == null` (indicating it is a link preview instead of a file), allowing it to fall through to the correct link preview renderer.
- Rule: Avoid treating messages as files based solely on `fType == 1`; verify that `fileExt` is present. Ensure call events are parsed on the backend to yield a human-readable text preview.
- Related files: `tools/alpha-crm/integration/zalo-bot-service/src/channels/personal-zca-channel.ts`, `tools/alpha-crm/lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`.

### 2026-06-26 - Open Containing Folder Action Opens Directory Instead of Highlighting File

- Symptom: Clicking the "Mở thư mục chứa tệp" button in Live Chat opened the folder directory on Windows, but did not automatically select/highlight the downloaded file. Additionally, non-media files saved from live chat were saved without a file extension and went into the main download folder together with media files.
- Root cause: (1) Flutter's `launchUrl` was called on the parent directory URI, which only opens the explorer. (2) `downloadLiveChatMedia` did not append file extensions if they were not explicitly passed in `fileName`. (3) Files were saved directly to the root of the downloads folder without segregation.
- Fix summary: (1) Replaced `launchUrl` in `live_chat_screen.dart` with `Process.run('explorer.exe', ['/select,$winPath'])` on Windows to open explorer and highlight the file. (2) Enhanced `downloadLiveChatMedia` to look up `Content-Disposition`, `Content-Type` mappings, or the URL path for missing extensions. (3) Separated downloaded files into `Media/` (for images, audio, video) and `Files/` (for documents, sheets, etc.) subdirectories under the CRM download folder.
- Rule: On Windows, use `Process.run('explorer.exe', ['/select,$winPath'])` to highlight files. Detect and attach missing file extensions from HTTP response headers, and separate media and non-media files into `Media` and `Files` folders.
- Related files: `tools/alpha-crm/lib/features/messaging/live_chat/data/live_chat_download_service_io.dart`, `tools/alpha-crm/lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`.

### 2026-06-26 - Zalo Group Polls Rendered as Raw JSON/HTML and Auto-saved Cache Files Lacking Extensions

- Symptom: (1) Group poll messages in the Live Chat screen were displayed as raw stringified JSON text in gray bubbles containing unparsed template text (like `%1$s` and `%2$s`) and raw HTML tags. (2) Auto-saved backend cache files inside `C:\Users\XEON\AppData\Local\AlphaCRM\zalo-bot-service\local-chat-media\Files` were saved with no file extension.
- Root cause: (1) Zalo poll messages sometimes arrive as regular `text` or `link` events from personal Zalo, containing a stringified JSON body representing the poll event. Since the content type was not `'poll'`, the frontend did not trigger the poll formatter and fell back to displaying the raw JSON. (2) The backend `safeExtension` helper did not extract file extensions from `attachment.mimeType` or the URL query parameters (which is where Zalo stores the file name). Since many file downloads return `application/octet-stream` as the content type, they were saved without an extension.
- Fix summary: (1) Added poll detection in the backend `personal-zca-channel.ts` normalizer to check if message bodies contain poll JSON structures and set `messageType` to `'poll'`. Updated the frontend `live_chat_screen.dart` to parse poll JSON data even if the message arrived under other content types (reconciling legacy DB rows). (2) Enhanced the backend `local-chat-media-worker.ts`'s `safeExtension` helper to extract file extensions from `attachment.mimeType` (using a comprehensive MIME mapping table), URL query parameters, and fallback to the URL pathname.
- Rule: Always check `attachment.mimeType` and URL query parameters for file extensions before falling back to the URL pathname, as Zalo attachments store file details inside query parameters and are often served as `application/octet-stream`.
- Related files: `tools/alpha-crm/integration/zalo-bot-service/src/channels/personal-zca-channel.ts`, `tools/alpha-crm/integration/zalo-bot-service/src/local-chat/local-chat-media-worker.ts`, `tools/alpha-crm/lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`.

---

## Instagram/WhatsApp/Telegram inbound webhook messages bị Mongoose reject do enum thiếu giá trị

**Triệu chứng:** Khi Instagram/WhatsApp/Telegram (Giai đoạn G/H/I) được thêm vào `CrmChannelIntegration.channel` enum và `channelWebhooks.js`, tin nhắn inbound từ 3 kênh này sẽ throw `ValidationError` khi gọi `CrmMessage.create({..., channel: 'instagram'|'whatsapp'|'telegram', ...})` — không hề lộ ra ở `tsc`/`flutter analyze` vì đây là lỗi runtime chỉ xảy ra khi có webhook thật gửi tới.

**Nguyên nhân:** `CrmConversation.js` và `CrmMessage.js` vẫn giữ enum cũ `['zalo_personal', 'zalo_oa', 'facebook_page', 'tiktok']` — chỉ `CrmChannelIntegration.js` được cập nhật khi thêm kênh mới, 2 model còn lại bị bỏ sót. `upsertConversationFromInbound()` (`server/routes/crm.js`) dùng `findOneAndUpdate(..., { upsert: true })` KHÔNG có `runValidators: true` nên phần update `CrmConversation` không lộ lỗi ngay, nhưng bước tạo `CrmMessage.create(...)` ngay sau đó dùng `.create()` (luôn chạy full schema validation) nên sẽ throw ngay khi channel không nằm trong enum.

**Cách sửa:** Thêm đầy đủ giá trị kênh vào enum `channel` của cả `CrmConversation.js` VÀ `CrmMessage.js`, không chỉ `CrmChannelIntegration.js`.

**Quy tắc cần nhớ:** Khi thêm 1 kênh mới (`channel` enum value), phải rà soát và cập nhật ĐỒNG THỜI cả 3 model: `CrmChannelIntegration.js`, `CrmConversation.js`, `CrmMessage.js` — không chỉ model dùng cho cấu hình tích hợp. Vì `findOneAndUpdate` mặc định không chạy validator, lỗi enum có thể im lặng ở bước upsert conversation nhưng vẫn nổ ở bước tạo message ngay sau đó.

**Các file liên quan:** `alpha-studio-backend/server/models/CrmConversation.js`, `alpha-studio-backend/server/models/CrmMessage.js`, `alpha-studio-backend/server/models/CrmChannelIntegration.js`, `alpha-studio-backend/server/routes/crm.js` (`upsertConversationFromInbound`), `alpha-studio-backend/server/routes/channelWebhooks.js`.

---

## WhatsApp/Telegram không thực sự chọn được trong bộ chuyển tài khoản Live Chat dù Phase H/I đã "hoàn thành"

**Triệu chứng:** Sau khi cắm xong WhatsApp (Phase H) và Telegram (Phase I) — settings screen, provider, backend route đều hoạt động — tài khoản của 2 kênh này vẫn không xuất hiện trong dropdown chuyển tài khoản ở đầu trang Live Chat. Người dùng không thể chọn hộp thoại WhatsApp/Telegram từ Live Chat dù đã kết nối thành công ở trang cài đặt.

**Nguyên nhân:** Dropdown chuyển tài khoản trong `_Header` (`live_chat_screen.dart`) được xây dựng bằng cách nối tay từng danh sách tài khoản (`zaloState.accounts`, `facebookPages`, `tiktokAccounts`, `instagramAccounts`) — không có cơ chế tự động duyệt qua mọi kênh đã đăng ký. Khi thêm Facebook/TikTok/Instagram, mỗi phase đều tự tay thêm khối `...accounts.map(...)` + nhánh `onChanged` tương ứng, nhưng khối tương tự cho WhatsApp và Telegram chưa từng được thêm — task tracker đánh dấu Phase H/I "hoàn thành" chỉ dựa trên cài đặt kênh, không kiểm tra điểm merge này.

**Cách sửa:** Thêm 3 khối còn thiếu (WhatsApp, Telegram, và Webchat mới) vào cùng chỗ: field `whatsappAccounts`/`telegramBots`/`webchatWidgets` ở đầu `build()`, mở rộng điều kiện `value:` ternary, thêm 3 khối `...accounts.map((account) => DropdownMenuItem(...))` dùng `channelAvatar(CrmChannel.X)`, và 3 nhánh `where()` tương ứng trong `onChanged`.

**Quy tắc cần nhớ:** Khi thêm 1 kênh mới vào hệ thống, phải rà soát VÀ xác nhận nó thực sự xuất hiện trong dropdown chuyển tài khoản Live Chat (`live_chat_screen.dart` → `_Header`) — không chỉ kiểm tra trang cài đặt kênh riêng lẻ. Đánh dấu 1 phase "hoàn thành" trong task tracker không đồng nghĩa với việc mọi điểm tích hợp chéo (cross-cutting integration point) đã được nối dây đầy đủ.

**Các file liên quan:** `lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`.
