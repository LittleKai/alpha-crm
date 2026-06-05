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
| `npm start` | Chạy service |
| `npm run dev` | Watch mode |
| `npm run zalo:login-personal` | CLI bootstrap đăng nhập personal Zalo |
