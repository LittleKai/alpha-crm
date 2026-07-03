# Tasklist Chi Tiết — Hoàn Thiện Đa Nền Tảng Mobile & Web (Realtime SSE, Pairing QR, Offline Fallback)

> Tài liệu triển khai chi tiết cho kế hoạch `mobile-web-completion-plan.md`.
> Trạng thái: Sprint 1–4 đã triển khai (BE-1..BE-7, AG-1..AG-4, FE-1..FE-6, QA-2, DOC-1). QA-1 (E2E thật trên thiết bị) cần chạy thủ công — xem `mobile-web-completion-qa-checklist.md`, môi trường coding không có desktop+phone rig thật để tự chạy. `mobile-web-completion-plan.md` không tồn tại trong repo nên không có gì để cập nhật drift.
> Ngày phân tích: 2026-07-02.

---

## 1. KẾT QUẢ PHÂN TÍCH HIỆN TRẠNG (GAP ANALYSIS)

### 1.1. Những phần ĐÃ CÓ SẴN — không cần làm lại

| Hạng mục trong plan | Trạng thái thực tế | Bằng chứng (file:line) |
|---|---|---|
| **Task 1.2 — Pairing & Session Sync** | ✅ **Đã hoàn chỉnh phía backend.** `POST /crm/pairing/start` (mã 6 số + `qrToken` động, hash SHA-256, rate limiter `crmPairingLimiter`), `POST /crm/pairing/confirm` (nhận `pairingCode` HOẶC `qrToken`, kiểm tra cross-account owner), `POST /crm/pairing/revoke`, `GET /crm/pairing/:id` (cho desktop poll trạng thái). Model `CrmPairingSession` + `CrmDevice`. | `alpha-studio-backend/server/routes/crm.js:1264, 1318, 1403, 1453` |
| **Task 3.2 — Màn hình quét QR ghép đôi** | ✅ **Đã có.** Màn hình `device_pairing_screen.dart` (~800 dòng) đã tích hợp `mobile_scanner` (quét trên mobile), `qr_flutter` (hiển thị QR trên desktop), nhập mã 6 số thủ công, và danh sách thiết bị đã liên kết (Device Management) kèm hủy ghép đôi. | `lib/features/devices/presentation/screens/device_pairing_screen.dart:4,100`; `lib/features/devices/providers/crm_device_provider.dart` |
| **Task 1.3 — Command Queue** | ✅ **Đã có schema chuẩn.** `CrmAgentCommand` với `type` (`zalo.message.send`, `START_CAMPAIGN`…), `payload`, `status` (queued/sent/running/succeeded/failed/cancelled/expired), `idempotencyKey`, `expiresAt` (TTL, tự expire khi agent claim). Endpoint `/crm/agent/commands/next` (claim atomic bằng `findOneAndUpdate`) + `/crm/agent/commands/:id/result` (hỗ trợ progress `running`). | `crm.js:1496–1529, 1532+` |
| **Luồng gửi tin từ xa qua Cloud** | ✅ **Đã có pipeline.** `POST /crm/conversations/:id/send` → chọn `CrmDevice` active → tạo `CrmMessage` (status `queued`) → tạo `CrmAgentCommand` `zalo.message.send` (idempotency `live-send:<messageId>`, TTL 1h). Có cả `/send-attachment`, `/recall`, `/read`, `/messages/failed/clear`. | `crm.js:2775–2830, 2852, 2921, 2983, 2751` |
| **Task 2.2 — Đẩy inbound realtime từ Agent** | ✅ **Đã đạt về bản chất.** `handleInboundMessageEvent` trong `agent-runner.ts` được gọi trực tiếp từ listener zca-js (KHÔNG quét SQLite định kỳ), gọi ngay `reportInboundMessage` (1:1, full content) hoặc `reportInboundMessageMetadata` (group managed, metadata-only để bảo mật nội dung nhóm). | `integration/zalo-bot-service/src/agent/agent-runner.ts:233–397` |
| **Realtime SSE cục bộ trên Desktop (Flutter ↔ local bridge)** | ✅ **Đã có.** `LiveChatRepository.watchEvents` → `localApi.watchEvents` (SSE từ bridge localhost); provider đã có reconnect backoff, debounce refresh (120ms/400ms), resubscribe theo account. | `lib/features/messaging/live_chat/data/live_chat_repository.dart:344–347`; `providers/live_chat_provider.dart:2088–2195` |
| **Mẫu SSE helper phía backend** | ✅ Có sẵn helper SSE (headers `text/event-stream`, write event) dùng cho AI agent-runner — tái sử dụng được pattern. | `alpha-studio-backend/server/agent-runner/sse.js` |

### 1.2. Những GAP THẬT SỰ còn lại (mục tiêu của tasklist này)

| # | Gap | Chi tiết | Ảnh hưởng |
|---|---|---|---|
| G1 | **Backend không có SSE cho Web/Mobile client** | Không tồn tại `/api/crm/events/subscribe`. `POST /crm/agent/events/message` (crm.js:2998) chỉ persist vào MongoDB, không broadcast. | Mobile/Web không thể nhận tin realtime — vi phạm tiêu chí nghiệm thu #2 (<1s). |
| G2 | **Heartbeat nghèo nàn & bị bỏ qua** | Agent chỉ gửi `{status, appVersion, agentVersion}` (agent-runner.ts:399–416); backend handler (crm.js:1472) **bỏ qua cả field `status`**, chỉ cập nhật `lastSeenAt`. Không có trạng thái Zalo account (online/expired), queue depth, và không broadcast device online/offline. | Client không biết Desktop Agent còn sống hay không — vi phạm tiêu chí #3 (offline fallback). |
| G3 | **Độ trễ lệnh cao (polling 5s)** | `BASE_POLL_DELAY_MS = 5000` (agent-runner.ts:31); chỉ hạ xuống 500ms ngay sau khi vừa nhận được 1 lệnh; backoff lỗi tới 60s. `/agent/commands/next` trả về ngay (không long-poll). | Tin gửi từ mobile trễ tới ~5s trước khi agent nhận lệnh. |
| G4 | **Flutter hard-code local bridge, không có chế độ remote** | `LiveChatRepository._preferLocalZaloActions => true` (live_chat_repository.dart:17) → mọi nền tảng (kể cả web/Android) đều gọi bridge `localhost` → fail → hiện "Bridge offline" + cache rỗng. `crm_cloud_api.dart` **không có** method conversations/SSE nào. `watchEvents` trả `Stream.empty()` khi không local-first. | Live Chat hoàn toàn không dùng được trên Web/Mobile. |
| G5 | **Cloud chặn lịch sử tin khi LOCAL_FIRST_LIVE_CHAT=true** | `GET /conversations/:id/messages` trả `LOCAL_BRIDGE_REQUIRED` + data rỗng khi flag bật (crm.js:2719; flag: `server/utils/crmLiveChat.js:89`). | Mobile/Web không đọc được lịch sử hội thoại từ cloud. |
| G6 | **Agent không report tin OUTBOUND** | `cloud-api.ts` chỉ có `reportInboundMessage`/`reportInboundMessageMetadata`. Tin do operator gửi từ Desktop UI hoặc chatbot auto-reply **không được đẩy lên cloud** → mobile không thấy chiều gửi đi. | Hội thoại trên mobile lệch/thiếu chiều outbound; trạng thái seen/delivered không đồng bộ. |
| G7 | **Chưa có Offline Fallback UI** | Flutter chưa có provider theo dõi trạng thái Desktop Agent từ cloud (devices chỉ có `lastSeenAt` tĩnh khi load màn pairing); chưa có banner cảnh báo, chưa disable composer. | Người dùng gửi tin vào hư không khi agent tắt. |
| G8 | **Chưa có Optimistic UI + quản lý tin lỗi ở chế độ remote** | Chế độ local đã có trạng thái tin; nhưng remote (cloud send) chưa có optimistic bubble "Đang gửi…", chưa có timeout 15s → failed, retry/xóa tin cloud (`retryMessage` hiện chỉ gọi local bridge — repository.dart:349). | Vi phạm Task 3.4. |

### 1.3. Kiến trúc mục tiêu (sau khi hoàn thành)

```text
┌─────────────────────┐  GET /crm/events/subscribe (SSE, JWT)   ┌──────────────────────┐
│  Web / Mobile        │ <────────────────────────────────────── │   Cloud Backend      │
│  (remote transport)  │  POST /crm/conversations/:id/send ────> │   (Express + Mongo)  │
└─────────────────────┘                                          │  ┌────────────────┐  │
                                                                 │  │ CrmEventHub    │  │
        Desktop Flutter (không đổi: local bridge SSE)            │  │ (per-userId)   │  │
                                                                 │  └───┬────────────┘  │
                                                                 └──────┼───────────────┘
                              broadcast khi: agent event message,       │
                              command result, heartbeat online/offline  │
                                                                        ▼
                                          ┌──────────────────────────────────────┐
                                          │ Desktop Agent (zalo-bot-service)     │
                                          │ • heartbeat giàu payload, 15s        │
                                          │ • long-poll /commands/next (~25s)    │
                                          │ • report inbound + OUTBOUND event    │
                                          └──────────────────────────────────────┘
```

**Quyết định kiến trúc đề xuất:**
1. **SSE (không phải Socket.io)** cho client: một chiều server→client là đủ (chiều lên đã có REST); tái dùng pattern `agent-runner/sse.js`; hoạt động tốt qua Fly.io. Flutter dùng `http.Client().send()` stream (io) + `EventSource` hoặc fetch-stream (web).
2. **Long-poll cho agent** thay vì WebSocket: thay đổi nhỏ nhất trên hạ tầng hiện có (`/agent/commands/next` giữ nguyên contract, thêm `waitMs`), đạt độ trễ <1s mà không cần thêm dependency.
3. **Không đổi hành vi Desktop:** Desktop Windows tiếp tục local-first qua bridge. Chế độ remote chỉ kích hoạt khi nền tảng không có bridge (web, Android, iOS).

---

## 2. DANH SÁCH TASK CHI TIẾT

Quy ước ID: `BE-*` = alpha-studio-backend, `AG-*` = zalo-bot-service (Desktop Agent), `FE-*` = Flutter alpha-crm. Mỗi task ghi rõ file dự kiến sửa/tạo, việc cần làm, và tiêu chí xong (DoD).

### PHASE 1 — Cloud Backend (`alpha-studio-backend`)

#### BE-1. Xây dựng CrmEventHub (SSE hub theo userId) — *nền tảng của mọi thứ realtime*
- **Tạo mới:** `server/utils/crmEventHub.js`
- **Việc cần làm:**
  - Class/module singleton giữ `Map<userId, Set<res>>` các kết nối SSE đang mở.
  - API: `subscribe(userId, res)` (đăng ký + cleanup khi `close`), `publish(userId, eventName, payload)` (ghi `event:`/`data:` JSON + `id:` tăng dần), `heartbeatTick()` (gửi comment `: ping` mỗi 25s giữ kết nối qua proxy/Fly.io).
  - Giới hạn tối đa N kết nối/user (đề xuất 5) — đóng kết nối cũ nhất khi vượt.
  - Không cần Redis pub/sub ở bước này (backend Fly.io 1 instance); ghi chú TODO khi scale ngang.
- **DoD:** unit test publish/subscribe/cleanup; kết nối giữ ổn định >5 phút qua proxy.

#### BE-2. Endpoint `GET /api/crm/events/subscribe` (SSE cho Web/Mobile)
- **Sửa:** `server/routes/crm.js`
- **Việc cần làm:**
  - Route mới `router.get('/events/subscribe', authMiddleware, requireActiveSubscription, ...)` → set headers SSE (tham khảo `server/agent-runner/sse.js`), gọi `crmEventHub.subscribe(req.user._id, res)`.
  - Hỗ trợ JWT qua query param `?token=` **hoặc** header (EventSource trên web không set custom header được) — nếu authMiddleware chỉ đọc header thì bổ sung nhánh đọc `req.query.token` riêng cho route này.
  - Gửi event khởi tạo `event: hello` kèm `{serverTime, devices: [...trạng thái online hiện tại]}` để client sync ngay khi kết nối.
  - Sự kiện chuẩn hóa (đặt tên cố định, tài liệu hóa trong file này):
    - `message.new` — tin inbound mới (payload: CrmMessage + conversation summary)
    - `message.status` — chuyển trạng thái tin outbound (queued→sent/failed, kèm `providerMessageId`)
    - `conversation.updated` — preview/unread thay đổi
    - `device.status` — Desktop Agent online/offline/zalo-expired
    - `pairing.completed` — ghép đôi thành công (desktop đang chờ biết ngay)
- **DoD:** `curl -N` nhận được `hello` + ping; đóng kết nối không leak listener.

#### BE-3. Broadcast từ các điểm phát sinh sự kiện
- **Sửa:** `server/routes/crm.js` tại các handler sau:
  - `POST /agent/events/message` (crm.js:2998): sau khi persist → `publish(userId, 'message.new', ...)` + `publish(userId, 'conversation.updated', ...)`.
  - `POST /agent/commands/:id/result` (crm.js:1532): khi command `zalo.message.send` kết thúc → cập nhật `CrmMessage.status` (`sent`/`failed` + `sentAt`/`errorMessage`) **và** `publish('message.status')`. Kiểm tra hiện trạng: xác nhận handler đã cập nhật CrmMessage tương ứng chưa; nếu chưa có thì bổ sung mapping `command.payload.crmMessageId → CrmMessage`.
  - `POST /conversations/:id/send` + `/send-attachment`: sau khi tạo CrmMessage queued → `publish('message.status', {status:'queued'})` (cho các client khác của cùng user thấy tin đang đi).
  - `POST /pairing/confirm` (crm.js:1318): sau khi confirm → `publish('pairing.completed')`.
- **DoD:** test tích hợp: giả lập agent POST events/message → client SSE nhận `message.new` <100ms.

#### BE-4. Nâng cấp Heartbeat: lưu trạng thái + phát hiện online/offline
- **Sửa:** `server/routes/crm.js:1472` (heartbeat handler), `server/models/CrmDevice.js`
- **Việc cần làm:**
  - Mở rộng schema `CrmDevice`: `agentStatus` (`online`/`offline`), `zaloAccounts: [{accountId, displayName, status: 'online'|'expired'|'logged_out'}]`, `queueDepth`, `lastHeartbeatAt` (giữ `lastSeenAt` như cũ để không vỡ chỗ khác).
  - Handler heartbeat: lưu payload mới (BE nhận từ AG-1), so sánh trạng thái trước/sau → nếu chuyển offline→online hoặc zalo status đổi → `publish('device.status')`.
  - **Cron/interval offline detector:** job mỗi 30s quét `CrmDevice` có `lastHeartbeatAt > 60s` mà `agentStatus === 'online'` → set `offline` + `publish('device.status')`. Đặt trong `server/index.js` (theo pattern cron cloud desktop hiện có của backend).
- **DoD:** tắt agent → tối đa 90s sau client SSE nhận `device.status: offline`; bật lại → nhận `online` ngay heartbeat kế tiếp.

#### BE-5. Long-poll cho `/agent/commands/next`
- **Sửa:** `server/routes/crm.js:1496`
- **Việc cần làm:**
  - Thêm body param `waitMs` (agent gửi, cap 25000ms — dưới timeout 30s của proxy). Nếu không có lệnh queued: thay vì trả `null` ngay, đăng ký waiter theo `deviceId` (Map in-memory `deviceId → resolver`) và giữ request.
  - Khi route tạo command mới (`/conversations/:id/send`, campaign, v.v.) → gọi `notifyCommandWaiter(deviceId)` để request đang treo trả lệnh ngay. Điểm tạo command tập trung: cân nhắc helper `createAgentCommand(...)` gói `CrmAgentCommand.create` + notify để không sót chỗ nào (grep toàn bộ `CrmAgentCommand.create` trong crm.js để thay).
  - Timeout `waitMs` → trả `{data: null}` như cũ (backward compatible: agent cũ không gửi `waitMs` vẫn hoạt động).
- **DoD:** gửi tin từ client → agent (đang treo long-poll) nhận command trong <500ms.

#### BE-6. Nhận sự kiện OUTBOUND từ agent + gỡ chặn lịch sử tin cho remote client
- **Sửa:** `server/routes/crm.js`
- **Việc cần làm:**
  - Endpoint mới `POST /agent/events/outbound-message` (agentAuthMiddleware): nhận tin outbound đã gửi từ Desktop (operator/chatbot), upsert `CrmMessage` (direction `outbound`, dedupe theo `providerMessageId`/`clientMessageId`) + cập nhật conversation preview → `publish('message.new')`. Với nhóm managed metadata-only: áp dụng cùng chính sách privacy như inbound (không lưu content nhóm nếu chính sách hiện tại là metadata-only — xem `reportInboundMessageMetadata` để nhất quán).
  - `GET /conversations/:id/messages` (crm.js:2717): bỏ return sớm `LOCAL_BRIDGE_REQUIRED`; thay bằng: vẫn trả dữ liệu cloud hiện có (tin 1:1 inbound + outbound đã sync). Ghi chú rõ trong response `meta.syncScope` để client hiển thị "lịch sử đầy đủ nằm trên máy chủ Desktop".
- **DoD:** gửi tin từ Desktop UI → trong <1s tin xuất hiện trên client SSE; GET messages từ mobile trả được lịch sử cloud.

#### BE-7. (Bảo mật) Rà soát chuỗi ủy quyền lệnh từ Mobile
- **Sửa:** `server/routes/crm.js` (nhỏ), tài liệu
- **Việc cần làm:**
  - Xác nhận mọi route tạo command đều qua `authMiddleware + requireActiveSubscription` (đã có) và device thuộc đúng `userId` (đã có tại send). KHÔNG cần `jwtSignature` per-command như plan gợi ý — agent auth bằng `x-agent-secret` + `deviceId` đã đủ (secret chỉ agent giữ); ghi quyết định này vào doc để đóng Task 1.3-security.
  - Bổ sung rate limit cho `/conversations/:id/send` từ mobile nếu chưa có (tái dùng limiter pattern hiện có).
- **DoD:** review checklist ký xác nhận trong PR; test 403 khi gửi vào device của user khác.

### PHASE 2 — Desktop Agent (`tools/alpha-crm/integration/zalo-bot-service`)

#### AG-1. Heartbeat giàu payload + chu kỳ 15s
- **Sửa:** `src/agent/agent-runner.ts:399–416`, `src/agent/cloud-api.ts:136`
- **Việc cần làm:**
  - Payload mới: `{status, appVersion, agentVersion, zaloAccounts: [{accountId, displayName, status}], queueDepth, clientConnections}`. Nguồn: `getZaloStatus()` mở rộng đa tài khoản (kiểm tra API hiện có trong `src/zalo.ts` / account store), số SSE client cục bộ đang mở, độ sâu hàng đợi gửi nội bộ.
  - Giảm interval heartbeat xuống 15s (kiểm tra hằng số hiện tại nơi `setInterval` tại agent-runner.ts:69).
  - Version bump: `appVersion`/`agentVersion` đọc từ package.json thay vì hard-code `'0.2.0'`.
- **DoD:** backend nhận và lưu đủ field; unit test build payload.

#### AG-2. Chuyển vòng lặp lệnh sang long-poll
- **Sửa:** `src/agent/agent-runner.ts:31–34, 418–485`, `src/agent/cloud-api.ts:157` (`fetchNextCommand`)
- **Việc cần làm:**
  - `fetchNextCommand` gửi `{waitMs: 25000}`; timeout phía fetch đặt 30s.
  - Vòng lặp: có lệnh → xử lý xong poll lại ngay (giữ hành vi 500ms hiện tại); không lệnh (long-poll timeout) → poll lại ngay lập tức (không sleep 5s nữa). Giữ nguyên exponential backoff khi **lỗi mạng** (5s→60s) và reset khi thành công.
  - Fallback: nếu backend cũ (không hỗ trợ waitMs, trả ngay `null`) → phát hiện response quá nhanh (<1s) và tự hạ về nhịp poll 3s để không spam server.
- **DoD:** đo E2E: tạo command trên cloud → agent nhận <500ms; khi mất mạng không spam log/CPU.

#### AG-3. Report tin OUTBOUND lên cloud
- **Tạo/Sửa:** `src/agent/cloud-api.ts` (thêm `reportOutboundMessage`), `src/agent/agent-runner.ts`
- **Việc cần làm:**
  - Xác định điểm hook: nơi bridge ghi tin outbound vào SQLite sau khi gửi thành công (tìm trong flow send của `src/server.ts` / message store — nơi phát SSE event cục bộ `message.new` cho Flutter desktop). Tái dùng đúng event đó để đồng thời gọi `reportOutboundMessage` (fire-and-forget, có retry-queue nhẹ khi cloud lỗi — tái dùng `handleCloudFailure`).
  - Áp chính sách privacy nhóm managed (metadata-only) giống inbound.
  - Dedupe: gửi kèm `clientMessageId` + `providerMessageId` để BE-6 upsert không nhân đôi (đặc biệt tin gửi qua chính command cloud — command result đã cập nhật status, event outbound chỉ bổ sung nếu chưa có).
- **DoD:** gửi tin từ Desktop UI + chatbot auto-reply → cloud có CrmMessage outbound đúng conversation, không trùng bản ghi với tin gửi từ mobile.

#### AG-4. (Nhỏ) Đẩy `pairing.completed` nhanh cho desktop đang chờ
- **Hiện trạng:** desktop poll `GET /crm/pairing/:id` để biết đã confirm.
- **Việc cần làm:** giữ nguyên polling (đơn giản, tần suất thấp) — chỉ giảm interval poll khi màn pairing đang mở nếu thực tế >2s. **Task kiểm tra, có thể NO-OP.**
- **DoD:** đo thời gian từ lúc mobile confirm → desktop hiển thị thành công <2s (tiêu chí nghiệm thu #1).

### PHASE 3 — Flutter (`tools/alpha-crm`)

#### FE-1. Tầng transport: xác định chế độ Local vs Remote
- **Tạo mới:** `lib/features/messaging/live_chat/data/live_chat_transport.dart`
- **Sửa:** `lib/features/messaging/live_chat/data/live_chat_repository.dart:17`
- **Việc cần làm:**
  - Enum `LiveChatTransportMode { localBridge, cloudRemote }`. Quy tắc: Windows desktop (bridge được supervise bởi `ZaloBackendManager`) → `localBridge`; `kIsWeb` hoặc Android/iOS → `cloudRemote`. Cho phép override debug qua dart-define để test.
  - Thay hard-code `_preferLocalZaloActions => true` bằng đọc mode; **mọi nhánh method hiện có giữ nguyên hành vi khi mode = localBridge** (không regression desktop). Khi `cloudRemote`: các method Zalo-action đi thẳng nhánh cloud hiện có (`/crm/conversations…`); method local-only (draft, searchMessages, messagesAround, sendTyping, retryMessage, accountChatSettings…) trả về stub an toàn hoặc disable ở UI (FE-5 xử lý phần hiển thị).
- **DoD:** `flutter analyze` sạch; chạy desktop Windows không đổi hành vi (regression test thủ công theo checklist); web/Android không còn gọi localhost.

#### FE-2. `CrmSseClient` — kết nối SSE cloud đa nền tảng
- **Tạo mới:** `lib/shared/api/crm_sse_client.dart` (+ `crm_sse_client_io.dart`, `crm_sse_client_web.dart` qua conditional import — theo đúng pattern `crm_auth_token_store.dart` đã dùng)
- **Việc cần làm:**
  - IO: `http.Client().send(Request('GET', …/crm/events/subscribe))` đọc stream line-based, parse `event:`/`data:`/`id:`; Web: dùng fetch-stream (package `http` trên web đã stream được; nếu không thì `EventSource` qua `package:web`) — truyền JWT qua query param `?token=` (khớp BE-2).
  - Reconnect: exponential backoff 1s→2s→5s→10s (max), reset khi nhận event; gửi `Last-Event-ID` khi reconnect (BE có thể bỏ qua ở v1 — client tự refresh list khi reconnect).
  - Expose `Stream<CrmSseEvent>` (name + json payload) + `ValueNotifier<SseConnectionState>` (connecting/connected/disconnected) cho UI dùng ở FE-4.
  - Lifecycle: pause khi app vào background (mobile) — dùng `WidgetsBindingObserver`, resume + full refresh khi foreground.
- **DoD:** unit test parser SSE (multi-line data, ping comment, event id); kết nối thật giữ >5 phút không leak.

#### FE-3. Nối SSE cloud vào Live Chat provider (thay polling)
- **Sửa:** `lib/features/messaging/live_chat/providers/live_chat_provider.dart`, `live_chat_repository.dart:344` (`watchEvents`), `live_chat_event.dart`
- **Việc cần làm:**
  - `watchEvents`: khi mode `cloudRemote` → map `CrmSseClient` events (`message.new`, `message.status`, `conversation.updated`) về `LiveChatEvent` hiện có (bổ sung factory parse từ payload cloud — đối chiếu shape CrmMessage vs shape bridge, viết mapper riêng, KHÔNG sửa shape local).
  - Provider: logic subscribe/reconnect/debounce hiện có (dòng 2088–2195) dùng lại nguyên vẹn vì chỉ nguồn stream đổi. Xóa/không thêm bất kỳ timer polling định kỳ nào cho remote; chỉ giữ refresh-on-reconnect.
  - `getConversations`/`getMessages` mode remote: đã có sẵn nhánh cloud trong repository (dòng 89–126, 182–189) — kích hoạt qua FE-1, kiểm tra shape response cloud render đúng UI (field name khác bridge: đối chiếu `CrmMessage` mongo vs message bridge, bổ sung mapping trong data layer nếu lệch).
- **DoD:** trên Chrome (web) + Android: tin nhắn Zalo mới hiển thị <1s không cần thao tác; danh sách hội thoại tự cập nhật preview/unread.

#### FE-4. Offline Fallback UI (trạng thái Desktop Agent)
- **Tạo mới:** `lib/features/messaging/live_chat/providers/agent_status_provider.dart`
- **Sửa:** `live_chat_screen.dart` (header + composer)
- **Việc cần làm:**
  - Provider lắng nghe `device.status` từ `CrmSseClient` + trạng thái ban đầu từ event `hello` (BE-2); state: `{agentOnline, zaloAccountStatus, lastSeenAt, sseConnected}`.
  - Banner cảnh báo trên header Live Chat (chỉ mode remote): "Không kết nối được với máy tính chủ (Desktop Agent). Tin nhắn có thể bị trễ." — style theo `AppColors` warning, tái dùng pattern `BackendStatusBanner` (KHÔNG dùng lại widget đó — nó gắn với ZaloBackendManager desktop).
  - Disable composer + nút gửi khi: agent offline HOẶC tài khoản Zalo `expired/logged_out` HOẶC SSE mất kết nối >30s (kèm tooltip lý do). Trường hợp SSE rớt nhưng agent có thể vẫn online → banner mức nhẹ "Đang kết nối lại…" (composer vẫn mở), chỉ khóa khi `device.status=offline` xác định.
  - Phân biệt 3 trạng thái hiển thị: (1) mất mạng client, (2) agent offline, (3) Zalo hết phiên — copy text riêng từng loại.
- **DoD:** tắt agent trên Windows → trong ≤90s web/mobile hiện banner + composer khóa; bật lại → tự mở khóa không cần reload.

#### FE-5. Optimistic UI + quản lý tin lỗi (mode remote)
- **Sửa:** `live_chat_provider.dart` (send flow), `live_chat_screen.dart` (bubble status), `live_chat_repository.dart`
- **Việc cần làm:**
  - Khi gửi (remote): chèn ngay bubble local status `sending` với `clientMessageId`; map các chuyển trạng thái từ `message.status` SSE: `queued` → "Đang gửi…", `sent` → "Đã gửi" (✓), `failed` → icon đỏ.
  - Timeout 15s: nếu sau 15s không nhận `message.status` sent/failed → chuyển bubble sang `failed` cục bộ với lý do "Không có phản hồi từ máy chủ Desktop" (nhưng nếu sau đó SSE báo `sent` muộn → tự nâng cấp lại thành sent, dedupe theo `clientMessageId`).
  - Nút trên bubble failed: **Thử lại** (re-POST `/conversations/:id/send` với cùng nội dung — tạo message mới; cân nhắc gửi kèm `clientMessageId` cũ để backend dedupe nếu BE hỗ trợ) và **Xóa tin** (xóa bubble local; nếu message đã persist cloud dạng failed → gọi `/messages/failed/clear` hoặc endpoint xóa đơn lẻ — kiểm tra `/messages/:id/delete` cloud có tồn tại không, nếu không thì chỉ clear-failed toàn hội thoại như backend hiện có, ghi rõ giới hạn).
  - Trạng thái "Đã nhận/Đã xem": **ngoài phạm vi v1** (cần zca-js delivered/seen event pipeline qua agent — ghi vào Known Limitations).
- **DoD:** kịch bản test: gửi khi agent bật (→ sent <3s), gửi rồi tắt agent giữa chừng (→ failed sau 15s, retry được sau khi bật lại).

#### FE-6. Hoàn thiện luồng pairing trên mobile (kiểm tra + vá nhỏ)
- **Sửa (nếu cần):** `device_pairing_screen.dart`, `crm_device_provider.dart`
- **Việc cần làm:**
  - Regression test luồng hiện có: desktop hiển thị QR (`qrToken`) → mobile quét → confirm → hai bên cập nhật. Đo tiêu chí #1 (<2s sau quét).
  - Sau pairing thành công trên mobile: tự trigger refresh danh sách tài khoản Zalo (`/crm/groups/accounts`) + điều hướng gợi ý sang Live Chat.
  - Nghe `pairing.completed` (SSE, từ BE-3) ở màn pairing desktop để thay/giảm polling `GET /pairing/:id` (chỉ khi FE-2 đã xong; nếu chưa thì giữ polling).
- **DoD:** checklist quét QR pass trên Android thật; danh sách thiết bị hiển thị trạng thái online/offline lấy từ `agentStatus` mới (BE-4).

### PHASE 4 — Kiểm thử, tài liệu, phát hành

#### QA-1. Kiểm thử tích hợp E2E theo tiêu chí nghiệm thu
- Ma trận: (Windows desktop + agent) × (Chrome web, Android APK) × các kịch bản: nhận tin realtime (<1s), gửi tin remote (<3s), agent tắt (fallback ≤90s), agent bật lại (tự hồi phục), Zalo hết phiên (banner riêng), pairing (<2s).
- Test đa client: 2 tab web + 1 mobile cùng user — mọi client đồng bộ.
- Load nhẹ: 1 user giữ SSE 30 phút, kiểm tra memory backend không tăng bất thường.

#### QA-2. Regression Desktop
- Toàn bộ Live Chat desktop (local bridge) chạy như cũ: gửi/nhận, attachment, recall, draft, quick reply, chatbot toggle. `flutter analyze` + `flutter test` + test có sẵn (`test/customers_screen_test.dart`, v.v.) pass.

#### DOC-1. Cập nhật tài liệu (bắt buộc theo workspace rules)
- `tools/alpha-crm/.claude/PROJECT_SUMMARY.md`: thêm transport mode mới, SSE client, agent status provider, file structure mới.
- `alpha-studio-backend/.claude/PROJECT_SUMMARY.md` + `DATABASE.md`: CrmDevice schema mở rộng, endpoint SSE + outbound-message, long-poll.
- Cập nhật `docs/specs/mobile-web-completion-plan.md`: đánh dấu Task 1.2/3.2/2.2 phần lớn đã có sẵn (drift check).
- `docs/guides/customer-installation-guide.md`: mục dùng CRM trên điện thoại/web.

---

## 3. THỨ TỰ TRIỂN KHAI & PHỤ THUỘC

```text
Sprint 1 (Backend realtime core):   BE-1 → BE-2 → BE-3 → BE-4      (BE-5 song song)
Sprint 2 (Agent):                   AG-1, AG-2 (cần BE-4/BE-5)     → AG-3 (cần BE-6)
Sprint 3 (Flutter remote):          FE-1 → FE-2 → FE-3 → FE-4 → FE-5   (FE-6 song song, cần BE-3)
Sprint 4:                           BE-7, AG-4, QA-1, QA-2, DOC-1
```

| Task | Phụ thuộc | Độ rủi ro | Ghi chú rủi ro |
|---|---|---|---|
| BE-1/BE-2 | — | Trung bình | SSE qua Fly.io proxy: cần ping 25s, test idle timeout thực tế |
| BE-5 | — | Trung bình | Long-poll giữ connection: chú ý pool/limit của Express + Fly.io |
| AG-3/BE-6 | Chính sách privacy nhóm | Cao | Phải nhất quán metadata-only cho nhóm managed; review kỹ trước merge |
| FE-1 | — | Cao nhất về regression | Đụng vào gating của toàn bộ repository Live Chat desktop — cần checklist QA-2 |
| FE-2 web | — | Trung bình | Stream fetch trên Flutter web + CORS: backend cần cho phép SSE route trong CORS config |

## 4. KNOWN LIMITATIONS (chấp nhận ở v1)

1. **Lịch sử tin trên mobile/web giới hạn phạm vi cloud-sync** (tin từ lúc agent bắt đầu report; nhóm managed chỉ metadata) — lịch sử đầy đủ vẫn ở Desktop.
2. **Trạng thái "Đã xem/Đã nhận"** chưa làm (cần pipeline delivered/seen từ zca-js).
3. **"Đang nhập…" (typing) từ Zalo → mobile** chưa làm (chỉ có chiều gửi typing từ desktop local).
4. **Scale ngang backend**: CrmEventHub in-memory, cần Redis pub/sub khi backend >1 instance.
5. **Gửi attachment từ mobile**: `/send-attachment` cloud nhận đường dẫn file cục bộ desktop — gửi file thật từ mobile cần upload B2 + agent tải về, để giai đoạn sau.
