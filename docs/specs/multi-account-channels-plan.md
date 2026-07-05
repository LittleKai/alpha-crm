# Kế hoạch: Hỗ trợ đa tài khoản Facebook Page / TikTok trong Live Chat

> File này được viết để thực hiện ở một session khác. Đọc từ đầu đến cuối trước khi bắt đầu code — mọi file path/dòng số đều đã được xác nhận qua khảo sát code thực tế (không suy đoán) tại thời điểm viết (2026-07-05).

## Bối cảnh

Câu hỏi gốc của người dùng: "Theo như thiết lập hiện tại thì liệu có thể kết nối được với nhiều tài khoản TikTok hoặc Facebook không? Còn trong Tab Live chat thì có thể phân ra rạch ròi giữa các nền tảng không?" — có tham khảo cách dự án **ChatbotX** xử lý (`D:\Dev\2.reference_pj\.Zalo-ref\.CRM-ref\ChatbotX`).

Trả lời sau khi khảo sát: **Không.** Có 3 điểm chặn cứng buộc đúng 1 tài khoản/kênh cho mỗi user:

1. **Backend** (`alpha-studio-backend/server/models/CrmChannelIntegration.js:41`):
   ```js
   crmChannelIntegrationSchema.index({ userId: 1, channel: 1 }, { unique: true });
   ```
   Unique index trên `{userId, channel}` → đăng ký Facebook Page thứ 2 sẽ **ghi đè** Page thứ 1 (vì route register dùng đúng filter này để upsert).

2. **Local bridge** (`integration/zalo-bot-service/src/integrations/integration-store.ts`): `facebook`/`tiktok` là **object đơn** (`FacebookIntegrationStatus`/`TiktokIntegrationStatus`), không phải mảng. Cả `facebook-channel.ts`/`tiktok-channel.ts` đọc thẳng singleton này khi gửi tin — không có khái niệm chọn credential theo `accountId`.

3. **Flutter**: `WorkflowAutomationState.facebook`/`.tiktok` là instance đơn, settings screen chỉ có 1 form duy nhất. `Live Chat` chỉ filter theo `CrmChannel` (loại nền tảng: facebook_page/tiktok/zalo...) — không có UI phân biệt "Page A" vs "Page B" trong cùng 1 kênh.

### Đối chiếu ChatbotX

ChatbotX model hoá mỗi tài khoản kết nối là **1 Inbox riêng** (bảng `Inbox` + `IntegrationMessenger`/`IntegrationTiktok` con trỏ tới):
- Không giới hạn số Inbox/workspace — chỉ `pageId` unique **toàn cục** (1 Page không thể gắn 2 workspace khác nhau), workspace muốn nối bao nhiêu Page/TikTok account cũng được (`packages/database/src/schema/integration-messenger.ts:70-77`, `uniqueIndex("IntegrationMessenger_pageId_key")` — không có unique theo `workspaceId`).
- `ContactInbox` (bảng join Contact↔Inbox) khiến hội thoại **tự động phân theo từng Inbox cụ thể**, không chỉ theo loại kênh.
- UI: trang `/inbox` liệt kê tất cả Inbox đã kết nối dạng card (`InboxCardList`, mỗi card = icon kênh + tên riêng), thêm tài khoản mới qua flow `/channels/create?channel=X`.

Quyết định: **triển khai multi-account theo tinh thần "mỗi tài khoản = 1 entity riêng, có thể list/thêm/xoá độc lập"**, tái dùng tối đa hạ tầng account-aware đã có sẵn trong `alpha-crm` (xây cho Zalo cá nhân multi-account) thay vì copy y hệt kiến trúc Postgres/Drizzle của ChatbotX.

## Phát hiện quan trọng: phần lớn hạ tầng ĐÃ account-aware, không cần sửa

Khảo sát sâu (3 subagent song song đọc code thực tế) xác nhận các lớp sau **đã hỗ trợ multi-account từ trước** (được xây cho Zalo cá nhân, generic đủ để dùng lại) và **KHÔNG cần đổi**:

| Lớp | File | Vì sao đã sẵn sàng |
|---|---|---|
| Backend conversation/message | `server/models/CrmConversation.js`, `CrmMessage.js` | Đã có field `accountId` **bắt buộc** + unique index theo `{userId, accountId, threadId,...}` (`CrmConversation.js:93`) và `{userId, accountId, providerMessageId}` (`CrmMessage.js:121-127`). 2 Page khác nhau đã tự phân tách đúng ngay hôm nay. |
| Backend webhook resolve | `server/routes/channelWebhooks.js` | Facebook: dòng 99-103 resolve integration theo `payload.entry[0].id` (pageId) → `CrmChannelIntegration.findOne({channel:'facebook_page', externalAccountId: pageId, enabled:true})`. TikTok: dòng 211-217 tương tự theo `payload.account_id`. Không dựa vào URL — vốn đã per-account. |
| Backend command relay | `CrmAgentCommand`, `channelWebhooks.js:80,196` | `payload: {channel, event}` với `event.accountId = integration.externalAccountId` đã có sẵn — chảy xuyên suốt không cần đổi. |
| Local SQLite | `src/local-chat/local-chat-store.ts` | Bảng `conversations`/`messages` đã có cả cột `accountId` VÀ `channel` (dòng ~227-279 tạo bảng, dòng ~478-481 thêm cột `channel`), unique index theo `(accountId, threadId)` và `(accountId, providerMessageId)`. Không cần đổi schema. |
| Local channel registry | `src/channels/channel-registry.ts` | Map theo channel-type string (`'facebook_page'`, `'tiktok'`) → 1 instance adapter. Multiplicity phải nằm **trong** adapter (xem Giai đoạn B), không phải ở registry — registry giữ nguyên. |
| Local command executor | `src/agent/command-executor.ts` case `channel.message.relay` (dòng ~124-132) | Forward nguyên `payload.event` (đã có `accountId`) cho `handleWebhookEvent()` — không chọn credential ở bước này, nên không cần đổi. |
| Local cloud-api | `src/agent/cloud-api.ts` (`ChannelIntegrationPayload`, `registerChannelIntegration`, dòng ~235-258) | Đã nhận `externalAccountId` per-call — gọi N lần (N account) là đủ, không cần đổi type/hàm. |
| Flutter conversation model | `lib/features/messaging/live_chat/providers/live_chat_provider.dart` | `Conversation`/`ChatMessage` đã có field `accountId` (dòng ~197, ~223 và tương tự cho ChatMessage) đọc từ `json['accountId']`. `LiveChatState.selectedAccount` → `loadConversations()` truyền `accountId: state.selectedAccount?.id` (dòng ~824) → `_repository.getConversations(accountId:...)` — lọc thật (server/local), không phải giả. |
| Flutter Live Chat UI | `lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart` | Dropdown chọn tài khoản đã có sẵn (`_Header`, dòng ~391-464, `AppSelectField` + avatar) và filter-chip theo channel (`_ConversationFilterChip`, dòng ~821-891). Tái dùng được, chỉ cần đổi nguồn dữ liệu accounts. |

**Điểm nghẽn thật sự chỉ nằm ở 3 chỗ**: (1) credential storage + registration ở backend, (2) credential storage + adapter routing ở local bridge, (3) Flutter settings UI (form đơn → list) + accounts-list provider (hiện chỉ có Zalo, cần gộp thêm Facebook/TikTok).

## Việc cụ thể theo từng hệ thống

### 1) `alpha-studio-backend`

- **`server/models/CrmChannelIntegration.js`**: đổi dòng 41 từ
  ```js
  crmChannelIntegrationSchema.index({ userId: 1, channel: 1 }, { unique: true });
  ```
  thành non-unique (dùng cho tốc độ query, không ràng buộc):
  ```js
  crmChannelIntegrationSchema.index({ userId: 1, channel: 1 });
  ```
  Giữ nguyên dòng 42 (`{channel, externalAccountId}` unique) — index này đúng, chặn 2 user khác nhau trùng 1 Page/account.

- **`server/routes/crm.js`** `POST /agent/channels/register` (dòng ~3233-3273): đổi filter của `findOneAndUpdate` từ
  ```js
  { userId: req.crmDevice.userId, channel }
  ```
  thành
  ```js
  { userId: req.crmDevice.userId, channel, externalAccountId }
  ```
  → upsert đúng theo account, không ghi đè account khác của cùng user/channel. Giữ nguyên xử lý lỗi `11000` (dòng ~3267, trùng account của **user khác**).

- **Thêm 2 route quản lý mới** (agent-auth, cùng file `crm.js`, đặt cạnh route register), theo đúng convention `_id`-làm-discriminator đã dùng cho `CloudSession` (xem `server/routes/cloud.js`, ví dụ `CloudSession.findById(req.params.id)`):
  - `GET /api/crm/agent/channels` → trả về danh sách `CrmChannelIntegration` của `req.crmDevice.userId` (ẩn `appSecret`/`verifyToken` hoặc chỉ trả trạng thái mask, tuỳ nhu cầu Flutter).
  - `DELETE /api/crm/agent/channels/:id` → `CrmChannelIntegration.findOneAndDelete({_id: req.params.id, userId: req.crmDevice.userId})`, trả 404 nếu không thuộc user.

- **Không đổi**: `CrmConversation`/`CrmMessage`/`channelWebhooks.js`/`CrmAgentCommand` — đã account-safe (xem bảng ở trên). Lưu ý: `CrmDevice.findOne({userId, status:'active'})` (dòng ~112, ~226 trong `channelWebhooks.js`) vẫn là single-active-device — không liên quan tới multi-account-per-channel, không cần đổi ở giai đoạn này.

### 2) `integration/zalo-bot-service`

- **`src/integrations/integration-store.ts`**:
  - Đổi interface `IntegrationSettings`:
    ```ts
    export interface IntegrationSettings {
      n8n: N8nIntegrationSettings;
      facebookPages: FacebookIntegrationStatus[];   // was: facebook: FacebookIntegrationStatus
      tiktokAccounts: TiktokIntegrationStatus[];     // was: tiktok: TiktokIntegrationStatus
      email: EmailIntegrationSettings;
    }
    ```
  - Mỗi phần tử mảng cần 1 `id` ổn định — dùng luôn `pageId`/`accountId` làm id (đã là field bắt buộc khi `enabled`).
  - `normalizeSettings()`/`maskIntegrationSettings()` (hiện ở dòng ~133-211): đổi từ xử lý object đơn sang `.map(...)` qua mảng.
  - **Migration 1 lần**: khi đọc `settings.json` cũ (có key `facebook`/`tiktok` dạng object), bọc thành mảng 1 phần tử `[oldObject]` rồi lưu lại theo schema mới. Làm trong `readIntegrationSettings()`, tương tự các migration một-lần khác đã có trong codebase này (xem cách `config.ts` migrate `.data` cũ sang `dataRoot`, theo mô tả trong `CLAUDE.md` phần Zalo Integration Direction).

- **`src/channels/facebook-channel.ts`** / **`tiktok-channel.ts`**:
  - Bỏ các chỗ đọc thẳng singleton (`readIntegrationSettings().facebook` ở dòng ~33/57/133, `.tiktok` ở dòng ~30/54/120).
  - Xây map credential theo `pageId`/`accountId`, **mirror đúng pattern `accountPool: Map<string, ZaloAccountInstance>`** đã có trong `src/channels/personal-zca-channel.ts` (dòng ~1660-1664 dùng `req.accountId ? accountPool.get(req.accountId) : undefined`).
  - `sendMessage(req, isTestMode)`: hiện bỏ qua `req.accountId` (field đã tồn tại sẵn trên `ZaloSendMessageRequest`, xem `types.ts:25`) — sửa để dùng nó chọn đúng `pageAccessToken`/`accessToken` trong map.
  - `getAccounts()` (đã trả mảng, hiện dòng ~132-145/119-132 chỉ trả 0-hoặc-1 phần tử): sửa để map qua N phần tử thật từ `facebookPages`/`tiktokAccounts`.
  - `deleteAccount(accountId)` (hiện là stub trả `false`): implement thật — xoá phần tử khỏi mảng trong `integration-store.ts`, ghi lại settings.

- **`src/server.ts`** settings-save handler (khối Facebook dòng ~264-309, TikTok ~311-337):
  - Đổi từ nhận 1 object Facebook/TikTok sang nhận mảng (hoặc 1 object + `action: 'add'|'update'|'delete'` — chọn cách nào đơn giản hơn khi code thực tế, không over-engineer).
  - Lặp qua từng account trong mảng đã lưu, gọi `registerChannelIntegration(...)` (không đổi signature) cho **từng** account thay vì 1 lần cố định.
  - Thêm route `DELETE /api/integrations/facebook/accounts/:pageId` và `DELETE /api/integrations/tiktok/accounts/:accountId` — xoá local + gọi cloud `DELETE /api/crm/agent/channels/:id` tương ứng (cần lưu `id` cloud trả về từ lần register, hoặc gọi cloud theo `channel+externalAccountId` nếu không muốn lưu thêm cloud `_id` cục bộ).
  - Thêm route `GET /api/integrations/facebook/accounts` / `GET /api/integrations/tiktok/accounts` để Flutter list.

- **Không đổi**: `channel-registry.ts`, `command-executor.ts`, `cloud-api.ts` (`ChannelIntegrationPayload`/`registerChannelIntegration` dùng nguyên), `local-chat-store.ts`/`local-chat-types.ts` (schema đã account-safe).

### 3) `alpha-crm` (Flutter)

- **`lib/features/workflows/providers/workflow_automation_provider.dart`**:
  - Thêm field `id` vào `FacebookSettingsState`/`TiktokSettingsState` (dùng `pageId`/`accountId` làm giá trị).
  - Đổi `WorkflowAutomationState.facebook`/`.tiktok` (hiện dòng ~349-350, instance đơn) thành `List<FacebookSettingsState>`/`List<TiktokSettingsState>`.
  - Thêm notifier method: `addFacebookAccount`, `updateFacebookAccount(id, ...)`, `removeFacebookAccount(id)` (và tương tự cho TikTok).

- **`lib/features/workflows/data/workflow_automation_api.dart`**:
  - Đổi `saveFacebookSettings`/`saveTiktokSettings` (hiện dòng ~55-65, POST nguyên object vào `{'facebook': {...}}`) cho khớp contract mảng/CRUD mới của bridge (list/add/update/delete theo id, xem route mới ở Giai đoạn B).

- **`lib/features/workflows/presentation/screens/facebook_settings_screen.dart`** / **`tiktok_settings_screen.dart`**:
  - Chuyển từ 1 form đơn sang **list + detail**, tái dùng nguyên pattern từ **`lib/features/devices/presentation/screens/device_pairing_screen.dart`** (route `/devices`, hàm `_buildPairedState` dòng ~438-533):
    - Badge đếm số lượng: `'CÁC FANPAGE ĐÃ LIÊN KẾT (${accounts.length})'`.
    - `ListView.separated` + `shrinkWrap`/`NeverScrollableScrollPhysics` qua danh sách account.
    - Mỗi item: `Container` card, icon tròn + tên + trạng thái, `IconButton` gỡ mở `AppDialog`/`useConfirm` (theo đúng rule bắt buộc trong `CLAUDE.md` gốc — KHÔNG dùng `confirm()` native).
    - **Không đặt giới hạn số lượng tài khoản** (khác cap "3 thiết bị" của `device_pairing_screen.dart`) trừ khi có yêu cầu rõ ràng sau này.
    - Phần "thêm tài khoản" tái dùng gần như nguyên form hiện tại (đã viết ở giai đoạn port Facebook/TikTok gốc) nhưng scope theo 1 account đang thêm/sửa, thay vì 1 form cố định toàn màn hình.

- **`lib/features/messaging/live_chat/providers/live_chat_provider.dart`** + **`live_chat_screen.dart`**:
  - Mở rộng `loadAccounts()`/`getAccounts()` (hiện chỉ gọi `GET /crm/groups/accounts`, Zalo-only) để gộp thêm tài khoản Facebook/TikTok (nguồn: local bridge, endpoint `GET /api/integrations/facebook/accounts` + `/tiktok/accounts` mới ở Giai đoạn B) vào cùng danh sách `accounts`.
  - Mỗi dòng dropdown hiện icon kênh tương ứng (tái dùng `CrmChannel.icon`/`.color` từ `lib/shared/models/crm_channel.dart`).
  - Giữ filter-chip theo channel (`_ConversationFilterChip`) làm bộ lọc phụ (lọc thô theo loại nền tảng), dropdown account làm bộ lọc chính (lọc theo tài khoản cụ thể) — không cần redesign, tái dùng plumbing `selectedAccount`/`accountId` đã hoạt động cho Zalo.
  - Xác nhận `accountId` được điền đúng xuyên suốt cho hội thoại Facebook/TikTok — đã có sẵn ở tầng data/backend (`channelWebhooks.js` đã set `event.accountId = integration.externalAccountId`), chỉ cần kiểm tra khi test end-to-end ở Giai đoạn E.

## Thứ tự triển khai — báo lại người dùng sau mỗi giai đoạn trước khi sang giai đoạn kế

1. **Giai đoạn A — Backend multi-account**
   - Sửa: index, upsert filter, thêm route `GET/DELETE /api/crm/agent/channels`.
   - Verify: đăng ký 2 Page khác nhau cho cùng 1 user → cả 2 tồn tại độc lập (không ghi đè). Đăng ký lại đúng `externalAccountId` → update tại chỗ. Luồng Facebook/TikTok đơn hiện tại (đã build trước đó) không bị regression.

2. **Giai đoạn B — Local bridge multi-account**
   - Sửa: `integration-store.ts` → mảng + migration, `facebook-channel.ts`/`tiktok-channel.ts` → chọn credential theo `accountId`, `server.ts` → loop-register + route list/delete.
   - Verify: `npx tsc --noEmit`. Thêm thủ công 2 Page giả vào `settings.json`, gọi endpoint list thấy đủ 2. Gọi gửi tin với từng `accountId` khác nhau → dùng đúng token tương ứng (kiểm tra qua log/mock, không cần Page thật).

3. **Giai đoạn C — Flutter data layer**
   - Sửa: `id` trên settings state, list hoá `WorkflowAutomationState`, cập nhật `workflow_automation_api.dart`.
   - Verify: `flutter analyze` sạch. Cập nhật `test/workflow_automation_provider_test.dart` nếu test hiện tại tham chiếu state dạng đơn (`state.facebook.pageId` kiểu cũ sẽ vỡ khi đổi sang `List`).

4. **Giai đoạn D — Flutter UI**
   - Sửa: list+detail cho `facebook_settings_screen.dart`/`tiktok_settings_screen.dart` (tái dùng `device_pairing_screen.dart`).
   - Verify: `flutter run -d chrome` hoặc `-d windows`, thêm/sửa/xoá thử 1 Facebook Page và 1 TikTok account trên UI thật, xác nhận `useConfirm` hiện đúng khi gỡ.

5. **Giai đoạn E — Live Chat đa tài khoản**
   - Sửa: gộp accounts list đa kênh trong `live_chat_provider.dart`/`live_chat_screen.dart`.
   - Verify: giả lập 2 Page test (2 dòng trong `settings.json`/DB), kiểm tra dropdown Live Chat liệt kê đúng 2 dòng riêng biệt kèm icon kênh, chọn từng dòng lọc đúng hội thoại của Page đó (không lẫn giữa 2 Page).

6. **Giai đoạn F — Đồng bộ tài liệu**
   - Cập nhật `alpha-crm/.claude/PROJECT_SUMMARY.md`, `alpha-studio-backend/.claude/PROJECT_SUMMARY.md`.
   - Cập nhật `docs/specs/n8n-facebook-integration-contract.md` — thêm mô tả endpoint list/delete multi-account (`GET/DELETE /api/crm/agent/channels`, local bridge `GET/DELETE /api/integrations/{facebook,tiktok}/accounts`).
   - Cập nhật `alpha-crm/.claude/IMPORTANT_FIXED_BUGS.md` nếu phát sinh vấn đề đáng nhớ trong quá trình làm.

## Giả định đã nêu (cần xác nhận lại nếu sai trước khi bắt đầu Giai đoạn A)

- Trang thiết kế lại `facebook_settings_screen.dart`/`tiktok_settings_screen.dart` tái dùng đúng pattern `device_pairing_screen.dart` (list card + confirm dialog `useConfirm`/`AppDialog`) thay vì tự nghĩ ra UI mới — giữ nhất quán với phần còn lại của app.
- Không đổi kiến trúc cloud-relay đã chốt ở giai đoạn port gốc (webhook vẫn cloud-owned, tin nhắn vẫn lưu SQLite local qua `emitInboundMessage`) — multi-account chỉ mở rộng theo chiều "bao nhiêu tài khoản", không đổi luồng dữ liệu.

## Ghi chú kỹ thuật khác thu thập được trong quá trình khảo sát

- Prior art tốt nhất trong `alpha-studio-backend` cho "nhiều doc cùng loại/user" là **`CloudSession`** (`server/models/CloudSession.js` + `server/routes/cloud.js`): dùng `_id` làm discriminator trả về cho client, không dùng flag `default`/`primary`. Đã áp dụng đúng convention này cho route `GET/DELETE /api/crm/agent/channels/:id` ở Giai đoạn A.
- `CrmDevice.zaloAccounts` (`server/models/CrmDevice.js:85-93`) là 1 pattern multi-account KHÁC (mảng nhúng trong 1 doc, cập nhật wholesale qua heartbeat) — không áp dụng cho Facebook/TikTok vì các kênh này cần webhook-driven per-account secret/signature lookup (mỗi account cần 1 doc đầy đủ, không phải 1 entry nhẹ trong mảng).
- `appSecret`/`verifyToken` được mã hoá ở tầng route (`server/utils/encryption.js`, AES-256-CBC, không phải Mongoose hook) — giữ nguyên cách này cho các route mới ở Giai đoạn A.

---

## Mở rộng thêm kênh: Instagram / WhatsApp / Telegram / Webchat

Sau khi Giai đoạn A-F (multi-account cho Facebook/TikTok) hoàn tất, kiến trúc "1 kênh = N tài khoản, mỗi tài khoản = 1 doc `CrmChannelIntegration` + list/detail UI" đã là generic — thêm kênh mới về nguyên tắc chỉ là lặp lại đúng khuôn mẫu Facebook, KHÔNG phải thiết kế lại. Tuy nhiên 3 trong 4 kênh mới có đặc điểm khác biệt cần quyết định rõ trước khi code (nêu ở dưới), không nên tự đoán.

### Mức độ giống Facebook của từng kênh

| Kênh | Giống Facebook đến đâu | Khác biệt cần biết |
|---|---|---|
| **Instagram** | Rất giống — cùng hạ tầng Meta Graph API, cùng App/App Secret, cùng kiểu xác thực `X-Hub-Signature-256`. IG DM là 1 sản phẩm con của cùng Meta App dùng cho Facebook Messenger (Page phải link với 1 tài khoản Instagram professional). | Payload Meta gửi có `object: "instagram"` thay vì `"page"`, và cấu trúc `entry[].messaging[]` hơi khác field. **Có thể tái dùng gần như nguyên `facebook-channel.ts`/webhook Facebook**, chỉ thêm nhánh phân loại theo `object` field. Cần verify cấu trúc payload thật khi có App test. |
| **WhatsApp** | Cũng chạy trên Meta hạ tầng (WhatsApp Business Platform / Cloud API), cùng kiểu webhook `X-Hub-Signature-256` + verify token. | `externalAccountId` là `phone_number_id` (không phải pageId). Gửi tin qua endpoint Graph API khác (`/PHONE_NUMBER_ID/messages`), có khái niệm **24h customer service window** (chỉ được nhắn tự do trong 24h kể từ tin nhắn cuối của khách, ngoài ra phải dùng template đã duyệt) — đây là ràng buộc chính sách quan trọng cần thể hiện rõ trong UI cảnh báo (tương tự `showComplianceWarningsDialog` đã dùng cho Zalo). |
| **Telegram** | **Khác hẳn** — không dùng hạ tầng Meta. Tạo bot qua BotFather → nhận 1 `botToken` duy nhất (không có khái niệm `appId`/`appSecret`/`verifyToken` kiểu Meta). Đăng ký webhook bằng cách tự gọi Telegram API `setWebhook` (không phải verify GET challenge như Meta). Telegram hỗ trợ optional `secret_token` header để xác thực thay cho HMAC signature. | **Cần quyết định schema**: `CrmChannelIntegration` hiện có field cứng `appId/verifyToken/appSecret` theo khuôn Meta — Telegram không khớp. Xem mục "Quyết định kiến trúc cần chốt trước" bên dưới. |
| **Webchat** | **Không phải kênh webhook từ nền tảng thứ 3** — đây là 1 widget chat nhúng trên chính website của khách hàng (không có Meta/Telegram/TikTok nào cả). Khách vãng lai mở widget → gửi tin trực tiếp tới cloud backend của mình, không phải verify chữ ký từ ai. | **Đây thực chất là 1 mini-feature riêng** (xây widget + endpoint public cho khách ẩn danh + kênh real-time đẩy tin ngược lại trình duyệt khách, ví dụ SSE/WebSocket) chứ không phải "thêm 1 adapter nữa". Xem mục quyết định bên dưới — cần xác nhận phạm vi trước khi code, đừng tự bổ sung tính năng ngoài yêu cầu. |

### Quyết định kiến trúc cần chốt trước khi code (đừng tự quyết định ngầm)

1. **Schema `CrmChannelIntegration` có nên đổi từ field cứng sang blob linh hoạt?**
   Hiện tại: `appId`, `verifyToken`, `appSecret` là field cố định kiểu Meta. Instagram/WhatsApp dùng đúng bộ field này (tái dùng nguyên). Telegram chỉ cần 1 `botToken` (+ optional `webhookSecret`) — không khớp field cứng.
   - Phương án A (đơn giản, khuyến nghị): thêm field optional `botToken` (mã hoá) riêng cho Telegram, giữ nguyên field Meta cho Facebook/Instagram/WhatsApp. Không đổi kiến trúc, chỉ thêm field mới — đúng tinh thần "surgical changes".
   - Phương án B (tổng quát hơn nhưng tốn công refactor): gộp mọi credential thành 1 field `credentials: Mixed` (encrypted JSON blob), mỗi channel tự định nghĩa shape riêng. Chỉ nên chọn nếu dự kiến còn thêm nhiều kênh nữa có credential shape khác nhau trong tương lai gần.
   → **Mặc định chọn Phương án A** trừ khi người dùng có ý định thêm nhiều kênh custom khác nữa.

2. **Webchat có nằm trong phạm vi đợt này không, hay tách task riêng?**
   Webchat đòi hỏi: (a) 1 endpoint public (không agent-auth) để khách vãng lai mở phiên chat, (b) 1 cơ chế đẩy tin real-time về trình duyệt khách khi nhân viên trả lời (SSE hoặc WebSocket — hệ thống hiện có `crmEventHub` dùng SSE cho phía CRM, có thể tái dùng cơ chế tương tự nhưng cho phía khách ẩn danh, cần audience/auth khác hẳn), (c) 1 script nhúng (`<script>` embed) + giao diện widget. Đây là khối lượng công việc tương đương 1 tính năng độc lập, không nên lẫn vào 4 giai đoạn adapter Instagram/WhatsApp/Telegram bên dưới.
   → **Khuyến nghị**: tách Webchat thành **Giai đoạn riêng sau cùng** (Giai đoạn L), làm sau khi Instagram/WhatsApp/Telegram (vốn cùng khuôn webhook-relay) đã xong, để tránh trộn 2 loại kiến trúc khác nhau trong cùng 1 lượt review.

### Việc cụ thể (Instagram / WhatsApp / Telegram — cùng khuôn webhook-relay với Facebook/TikTok)

- **Backend**: `CrmChannelIntegration.js` — thêm `'instagram'`, `'whatsapp'`, `'telegram'` vào `enum` dòng 12 (giữ `'webchat'` cho giai đoạn riêng). Thêm field optional `botToken` (mã hoá) cho Telegram (xem Quyết định #1).
  `server/routes/channelWebhooks.js` — thêm khối route mới cho từng kênh, copy đúng cấu trúc khối Facebook (dòng ~97-128) đã có: Instagram/WhatsApp verify `X-Hub-Signature-256` bằng `appSecret` (giống hệt Facebook, khác object/field payload); Telegram không có GET verify-challenge (bỏ qua bước `GET webhook`), `POST` xác thực qua header `secret_token` thay vì HMAC, resolve integration theo `botToken`-derived id hoặc `chat.id`/bot username tuỳ thiết kế thật.
  Route register (`crm.js`) và list/delete (`GET/DELETE /agent/channels`) đã generic theo `channel` — không cần sửa thêm ngoài enum.
- **Local bridge**: tạo `instagram-channel.ts`, `whatsapp-channel.ts`, `telegram-channel.ts` mirror cấu trúc `facebook-channel.ts` (Instagram/WhatsApp gần như copy nguyên, đổi endpoint Graph API gửi tin và field payload). Telegram đơn giản hơn: `sendMessage` gọi thẳng `https://api.telegram.org/bot<token>/sendMessage`, không cần app secret verify ở phía adapter (verify đã làm ở backend qua `secret_token`). Đăng ký thêm vào `channel-registry.ts` (thêm key `'instagram'`, `'whatsapp'`, `'telegram'`) — đúng pattern hiện có, không đổi cấu trúc registry.
  `integration-store.ts` mở rộng thêm `instagramAccounts[]`/`whatsappAccounts[]`/`telegramBots[]` theo đúng khuôn mảng đã dựng ở Giai đoạn B của multi-account Facebook/TikTok.
- **Flutter**: `crm_channel.dart` — thêm `instagram`, `whatsapp`, `telegram` vào enum `CrmChannel` (giữ `webchat` cho giai đoạn riêng) + icon/màu tương ứng (Instagram: gradient hồng-tím theo brand; WhatsApp: xanh lá `#25D366`; Telegram: xanh dương `#26A5E4`) + cập nhật i18n vi/en cho tên hiển thị kênh (bắt buộc theo `CLAUDE.md` gốc — mọi text UI mới phải có cả 2 ngôn ngữ).
  `workflow_automation_provider.dart`/`_api.dart` — thêm state list + API calls theo đúng khuôn Facebook/TikTok đã list-hoá ở Giai đoạn C.
  3 settings screen mới (`instagram_settings_screen.dart`, `whatsapp_settings_screen.dart`, `telegram_settings_screen.dart`) tái dùng đúng layout `facebook_settings_screen.dart` sau khi đã chuyển sang list+detail — Telegram form đơn giản hơn (chỉ 1 ô nhập bot token, không cần appId/verifyToken).
  Live Chat: `loadAccounts()` gộp thêm 3 nguồn account mới vào cùng danh sách hiện có — không cần thay đổi UI thêm, dropdown/filter-chip đã generic theo `CrmChannel`.
  WhatsApp cần thêm 1 banner cảnh báo UI về "24h customer service window" — dùng `showComplianceWarningsDialog` (bắt buộc theo `CLAUDE.md`, không dùng Dialog mặc định).

### Thứ tự triển khai bổ sung

7. **Giai đoạn G — Instagram** (làm sau khi Giai đoạn A-F multi-account Facebook/TikTok xong): backend enum + webhook route + `instagram-channel.ts` + Flutter enum/settings screen/Live Chat. Verify: giả lập webhook Meta test event có `object:"instagram"`, xác nhận tin vào đúng `LocalChatStore` với `channel:'instagram'` và `accountId` đúng IG-linked Page.
8. **Giai đoạn H — WhatsApp**: tương tự Giai đoạn G + banner cảnh báo 24h window. Verify: test webhook WhatsApp Cloud API sandbox, xác nhận gửi trong/ngoài 24h window được cảnh báo đúng trên UI trước khi gửi (nếu quyết định chặn cứng ngoài 24h, cần hỏi lại người dùng — đây là quyết định sản phẩm, không tự quyết).
9. **Giai đoạn I — Telegram**: chốt Quyết định #1 (field `botToken`) trước, sau đó backend/local bridge/Flutter theo khuôn đơn giản hơn (không app secret). Verify: tạo bot test qua BotFather, gọi `setWebhook` trỏ về route mới, gửi tin thử 2 chiều.
10. **Giai đoạn K — Đồng bộ tài liệu đợt 2**: cập nhật `n8n-facebook-integration-contract.md` (đổi tên hoặc thêm file mới `docs/specs/omnichannel-integration-contract.md` nếu phạm vi rộng hơn "n8n + facebook" thuần tuý), `PROJECT_SUMMARY.md` liên quan.
11. **Giai đoạn L — Webchat** (tách riêng, chỉ làm sau khi có xác nhận phạm vi rõ ràng từ người dùng — xem Quyết định #2): thiết kế endpoint public + cơ chế real-time + widget embed, review riêng trước khi code vì đây là bề mặt tấn công mới (public-facing, không qua agent-auth) cần cân nhắc kỹ về bảo mật/rate-limit.
