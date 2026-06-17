# Zalo Bot Service

Node.js/TypeScript integration service cho Alpha CRM ↔ Zalo.

## Kiến trúc

```text
Flutter (UI) → HTTP → zalo-bot-service → ZaloChannel adapter → Zalo API
                                        ├─ PersonalZcaChannel  (zca-js, primary)
                                        ├─ OfficialOaChannel   (OA API, optional)
                                        └─ MockZaloChannel     (test/dev)
```

Flutter side chỉ gọi HTTP đến service này, không trực tiếp gọi Zalo API.

## Phiên CRM một PC

Flutter Windows đồng bộ JWT sau khi cloud login thành công. Service chỉ khởi
động agent, Zalo listener, heartbeat, command polling và local sync sau khi
phiên được xác minh.

| Method | Path | Mô tả |
|--------|------|-------|
| POST | `/local/auth/sync` | Xác minh JWT/user, đăng ký hoặc thay thế PC và khởi động runtime |
| POST | `/local/auth/logout` | Dừng runtime, disable phiên PC best-effort và xóa hai file phiên CRM |
| GET | `/local/events` | SSE phát `session.revoked` cho Flutter |

`409 DEVICE_ALREADY_ACTIVE` yêu cầu Flutter xác nhận trước khi force replace.
Chỉ `403 DEVICE_REVOKED` mới làm local service thu hồi phiên. Lỗi mạng không
đăng xuất người dùng.

Thu hồi phiên chỉ xóa `crm_token.json` và `.data/agent/device-secret.json`.
SQLite, Zalo credentials, settings, conversations và history được giữ nguyên.

## Mục đích

- **Enforcement boundary**: Credentials Zalo (cookie, IMEI, token) lưu phía backend, không lộ ra client
- **Channel adapter**: Hỗ trợ personal Zalo (`zca-js`), OA, và mock qua interface chung
- **Compliance guard**: Backend kiểm tra compliance trước khi gọi Zalo API
- **Webhook receiver**: Nhận event từ Zalo (tin nhắn, theo dõi OA, v.v.)
- **Rate limiting**: Kiểm soát tần suất gọi API phía server

## Cài đặt

```bash
cp .env.example .env
# Cấu hình ZALO_CHANNEL_MODE và credentials tương ứng
npm install
npm run build
npm start
```

### Đăng nhập Personal Zalo (lần đầu)

```bash
npm run zalo:login-personal
```

Quét QR bằng app Zalo. Credentials được lưu tại `.data/zalo-personal/credentials.json` (gitignored).

### Giữ phiên đăng nhập lâu dài (re-login refresh)

File credential (`credentials_<uId>.json`) được ghi **đúng một lần** lúc QR login
và **giữ bất biến**. Service KHÔNG bao giờ re-serialize cookie jar sống rồi ghi
đè file — việc đó từng làm rớt cookie `zpw_sek` và hỏng phiên (lỗi
"zpw_sek bị thiếu hoặc không đúng").

Để giữ phiên sống lâu, service **đăng nhập lại** (`zalo.login(saved)`) định kỳ
(mặc định mỗi 12 giờ, có stagger 10s/tài khoản): Zalo cấp cookie mới vào jar
trong RAM, còn file lưu vẫn là bản QR gốc tốt. Đây là cách dự án tham khảo
ZaloCRM dùng (immutable credential + re-login refresh + circuit breaker).

Phiên vẫn có thể mất nếu Zalo chủ động vô hiệu hoá: đăng nhập trùng tài khoản ở
nơi khác (Zalo Web/máy khác → listener `closed` code 3000/3003), đổi mật khẩu,
hoặc hành vi bị gắn cờ. Khuyến nghị dùng tài khoản riêng và không đăng nhập song
song tài khoản đó ở thiết bị khác.

Khi bị thu hồi, lý do (mã 3000/3003) được lưu trong bộ nhớ của instance và trả
qua `GET /api/zalo/accounts` ở các field `status` (`connected` |
`disconnected_expired`), `disconnectReason`, `disconnectedAt`. Flutter hiển thị
icon cảnh báo + nút "Đăng nhập lại" trong panel "Tài khoản Zalo" (tab Cài đặt).

## Endpoints

| Method | Path | Mô tả |
|--------|------|-------|
| GET | `/health` | Health check |
| GET | `/api/zalo/status` | Trạng thái kết nối (mode, account, listener) |
| POST | `/api/zalo/webhook` | Nhận webhook từ Zalo |
| POST | `/api/zalo/test-send` | Gửi tin nhắn thử nghiệm |
| POST | `/api/zalo/send-message` | Gửi tin nhắn qua channel hiện tại |
| GET/POST | `/api/integrations/n8n/settings` | Lưu đọc cấu hình n8n, API key trả về UI dạng masked |
| POST | `/api/integrations/n8n/test` | Kiểm tra kết nối n8n Public API |
| GET | `/api/integrations/n8n/templates` | Danh sách workflow templates Alpha CRM |
| POST | `/api/integrations/n8n/templates/install` | Tạo workflow nháp trong n8n từ template |
| GET | `/api/integrations/n8n/workflows` | Đọc workflow list từ n8n |
| POST | `/api/proxy/test` | Kiểm tra proxy URL trước khi gán vào account |

Integration settings are stored locally at `.data/integrations/settings.json` (gitignored). Facebook Page tokens are intentionally not stored here; official Page/Messenger integration needs the cloud backend contract in `docs/specs/n8n-facebook-integration-contract.md`.

## Channel Modes

| Mode | Env | Mô tả |
|------|-----|-------|
| `personal_zca` | Mặc định | Dùng `zca-js` với tài khoản cá nhân |
| `official_oa` | Tùy chọn | Dùng Zalo OA/OpenAPI SDK |
| `mock` | Test | Trả kết quả giả lập |

### Official Bot/OA mode

`official_oa` is the safer production direction for inbound support and chatbot flows. Configure:

```env
ZALO_CHANNEL_MODE=official_oa
ZALO_BOT_TOKEN=your_bot_token
ZALO_BOT_API_BASE_URL=https://bot-api.zapps.me
ZALO_WEBHOOK_SECRET=shared_secret_for_incoming_webhooks
```

Current scope:

- `send-message` supports compliant text sends through the Official Bot API token.
- `/api/zalo/webhook` accepts Bot/OA-shaped message events and emits CRM inbound message events.
- Personal-only operations such as friend requests, group scans, joins, invites, and group creation remain unsupported in official mode.

## Scripts

| Script | Mô tả |
|--------|-------|
| `npm run build` | Compile TypeScript |
| `npm test` | Build và chạy toàn bộ Node tests |
| `npm start` | Chạy service |
| `npm run dev` | Watch mode |
| `npm run zalo:login-personal` | CLI bootstrap đăng nhập personal Zalo |

## Local-First Live Chat

This service acts as the source of truth for full Live Chat message bodies when Local-First mode is enabled.

Configure in `.env`:

```env
LOCAL_FIRST_LIVE_CHAT=true
LOCAL_CHAT_DB_PATH=.data/live-chat/live-chat.sqlite
```

When enabled:
- Inbound messages are captured fully into the local `better-sqlite3` database before cloud sync.
- Only a metadata summary (lastMessagePreview, timestamps, unreadCount) is sent to the cloud.
- The Flutter client queries `/local/conversations/:id/messages` and sends via `/local/messages/send` directly, avoiding cloud payload overhead.

