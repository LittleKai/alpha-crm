# Smoke Test Checklist — Alpha CRM

**Mục đích:** Kiểm tra tay trước khi phát hành. Chạy trên **artifact đã build** — Windows ZIP giải nén ra chạy `alpha_crm.exe`, và APK cài trên máy Android thật. KHÔNG kiểm bằng `flutter run`.
Lý do bắt buộc chạy bản build: `flutter run` **không** dựng được đường đi thật của backend Zalo cục bộ (`node.exe dist/server.cjs` nằm cạnh exe), không kiểm được Job Object, không kiểm được bundle ZIP có đủ Node runtime hay lỡ kèm `.env`. Ngoài ra Windows chạy `localBridge` còn Android chạy `cloudRemote` — **hai đường dữ liệu khác nhau, phải test cả hai**.

---

## Trước khi test

- [ ] `flutter analyze` và `flutter test` pass
- [ ] Build qua `alpha-studio-backend/scripts/release-to-b2.js`; giải nén ZIP kiểm tra: có `node.exe` + `dist/`, **không** có `.env` và **không** có `.data`
- [ ] Test trên máy **chưa từng cài** app (chưa có `Documents/AlphaCRM`, chưa có `.secure-key`) để bắt lỗi khởi tạo lần đầu

## Luồng chính — Windows (localBridge)

- [ ] **Khởi động:** mở app → splash che tới khi backend `healthy` **và** nạp xong tài khoản Zalo; không rơi vào màn chính khi backend `failed`
- [ ] **Đăng nhập Zalo cá nhân:** quét QR → đăng nhập được; **đóng app rồi mở lại → vẫn còn phiên** (xác nhận `credentials_*.json` mã hoá/giải mã đúng, cookie `zpw_sek` không bị hỏng)
- [ ] **Live Chat:** nhận tin đến hiện realtime; gửi trả lời → tin xuất hiện **một lần duy nhất** (không nhân đôi do echo outbound-reporter)
- [ ] **Đa kênh:** dropdown chọn tài khoản liệt kê đủ **mọi** kênh đã cấu hình (Zalo, Facebook, Instagram, WhatsApp, Telegram, TikTok, Webchat) — không thiếu kênh nào
- [ ] **Chiến dịch hẹn giờ:** hẹn một chiến dịch vài phút sau → **thoát app, mở lại** → chiến dịch vẫn còn trong hàng đợi và bắn đúng giờ
- [ ] **Tóm tắt AI nhóm:** chạy wizard trên một nhóm có ≥5 tin → ra summary; xác nhận nhóm bị gộp đúng khi đồng bộ từ nhiều tài khoản
- [ ] **Thoát app:** đóng bằng nút X → hộp thoại xác nhận; chọn "Thoát luôn" → **`node.exe` không còn chạy** trong Task Manager

## Luồng chính — Android (cloudRemote)

- [ ] **Đăng nhập + ghép thiết bị:** đăng nhập tài khoản Alpha Studio, ghép với Desktop Agent đang chạy
- [ ] **Realtime qua SSE:** tin nhắn đến trên desktop hiện lên mobile; trạng thái agent offline → banner chặn + khoá ô soạn tin
- [ ] **Offline cache:** bật máy bay → danh sách khách hàng vẫn hiện từ cache kèm thông báo offline (không phải danh sách rỗng)

## Sau khi test

- [ ] Không có tiến trình `node.exe` mồ côi sau khi thoát
- [ ] Log không in ra JWT, cookie Zalo, hay token kênh nào (API phải trả secret dạng đã che)
- [ ] `version.json` trên B2 khớp với APK + Windows ZIP vừa upload
- [ ] Ghi vấn đề phát hiện vào PROJECT_SUMMARY.md; bug khó phát hiện/dễ tái phát → `.claude/IMPORTANT_FIXED_BUGS.md`

---

**📌 NOTE:** Cập nhật checklist này khi có kênh hoặc luồng nghiệp vụ chính mới. Giữ mỗi phần "Luồng chính" ở mức 5–7 mục — đây là smoke test, không phải regression suite (`flutter test` lo phần đó).
