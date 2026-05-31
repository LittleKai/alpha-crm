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

## Channel Modes

| Mode | Env | Mô tả |
|------|-----|-------|
| `personal_zca` | Mặc định | Dùng `zca-js` với tài khoản cá nhân |
| `official_oa` | Tùy chọn | Dùng Zalo OA/OpenAPI SDK |
| `mock` | Test | Trả kết quả giả lập |

## Scripts

| Script | Mô tả |
|--------|-------|
| `npm run build` | Compile TypeScript |
| `npm start` | Chạy service |
| `npm run dev` | Watch mode |
| `npm run zalo:login-personal` | CLI bootstrap đăng nhập personal Zalo |
