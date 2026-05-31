# 📘 Hướng Dẫn Cài Đặt & Sử Dụng Tích Hợp Zalo

> [!NOTE]  
> **Cập nhật mới nhất:** 2026-05-31 20:00 +07:00  
> **Phiên bản hệ thống:** v0.2.0 (Personal-Zalo-First)  
> Tài liệu này hướng dẫn chi tiết cách cài đặt, cấu hình và sử dụng hệ thống tích hợp Zalo của **Alpha CRM**, tập trung vào giải pháp tài khoản cá nhân thông qua Node.js service sử dụng thư viện `zca-js`.

---

## 🗺️ 1. Tổng Quan Kiến Trúc Tích Hợp

Hệ thống tích hợp Zalo của Alpha CRM hoạt động theo mô hình **Client-Server-Adapter**. Flutter UI chỉ đóng vai trò là giao diện hiển thị và đưa ra cảnh báo sớm (Advisory), trong khi Node.js backend (`integration/zalo-bot-service`) đảm nhận việc quản lý kết nối, lưu trữ thông tin đăng nhập và thực thi các biện pháp kiểm soát rủi ro (Enforcement Boundary).

```text
┌────────────────────────┐         HTTP         ┌──────────────────────────────┐
│  Alpha CRM Flutter UI  │ ───────────────────> │  Node.js Zalo Bot Service    │
│  (Advisory Guard & UI) │ <─────────────────── │  (Enforcement Boundary)      │
└────────────────────────┘        Status        └──────────────┬───────────────┘
                                                               │
                                       ┌───────────────────────┼───────────────────────┐
                                       ▼                       ▼                       ▼
                            ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
                            │  Channel Adapter    │ │  Channel Adapter    │ │  Channel Adapter    │
                            │  (Personal Zca)     │ │  (Official OA)      │ │  (Mock / Test)      │
                            │  * Thư viện zca-js  │ │  * Zalo OpenAPI SDK │ │  * Giả lập gửi/nhận │
                            └──────────┬──────────┘ └──────────┬──────────┘ └──────────┬──────────┘
                                       │                       │                       │
                                       ▼                       ▼                       ▼
                            ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
                            │  Zalo Web Personal  │ │ Zalo OA / OpenAPI   │ │     Mock State      │
                            └─────────────────────┘ └─────────────────────┘ └─────────────────────┘
```

Hệ thống hỗ trợ 3 chế độ kênh (Zalo Channel Modes):

| Chế độ (Mode) | Giá trị cấu hình | Đối tượng Zalo | Cơ chế kỹ thuật | Tính năng chính |
| :--- | :--- | :--- | :--- | :--- |
| **Personal Zalo** *(Default)* | `personal_zca` | Tài khoản cá nhân | Giao thức Web Zalo thông qua `zca-js` | Kết bạn, nhóm, live chat, gửi tin nhắn theo SĐT, tự động hóa an toàn |
| **Official OA** | `official_oa` | Zalo Official Account | OpenAPI chính thức của Zalo | Gửi tin nhắn template, ZNS, chăm sóc khách hàng quan tâm OA |
| **Mock / Test** | `mock` | Không kết nối thật | Trả kết quả giả lập cục bộ | Kiểm thử hệ thống, đào tạo operator mà không lo bị khóa tài khoản |

---

## ⚙️ 2. Cài Đặt và Cấu Hình Backend

Backend Node.js service nằm tại thư mục `integration/zalo-bot-service/`. Hãy làm theo các bước dưới đây để thiết lập môi trường chạy.

### 2.1 Cài Đặt Dependencies

Di chuyển vào thư mục dự án backend, sao chép file cấu hình mẫu và tiến hành cài đặt:

```bash
# 1. Di chuyển vào thư mục backend
cd integration/zalo-bot-service

# 2. Tạo file môi trường từ file mẫu
cp .env.example .env

# 3. Cài đặt các thư viện phụ thuộc (bao gồm cả zca-js cục bộ)
npm install

# 4. Biên dịch TypeScript sang JavaScript
npm run build
```

> [!IMPORTANT]  
> Thư viện `zca-js` được cài đặt dưới dạng local dependency liên kết với thư mục chứa mã nguồn thư viện gốc để đảm bảo hiệu năng và khả năng tùy biến cao nhất.

### 2.2 Cấu Hình Chi Tiết File `.env`

Mở file `.env` vừa tạo và cấu hình các tham số phù hợp với nhu cầu vận hành:

```env
# ────────────────────────────────────────────────────────────────────────
# ⚙️ Cấu Hình Chung
# ────────────────────────────────────────────────────────────────────────
PORT=8787
NODE_ENV=development

# Lựa chọn chế độ Zalo Channel: personal_zca | official_oa | mock
ZALO_CHANNEL_MODE=personal_zca

# ────────────────────────────────────────────────────────────────────────
# 👤 Cấu Hình Personal Zalo (zca-js)
# ────────────────────────────────────────────────────────────────────────
# Đường dẫn lưu file session & cookies đăng nhập (Tuyệt đối không đưa vào git)
ZALO_PERSONAL_CREDENTIALS_PATH=.data/zalo-personal/credentials.json
# Đường dẫn lưu file ảnh mã QR để đăng nhập lần đầu
ZALO_PERSONAL_QR_PATH=.data/zalo-personal/qr.png
# Nhãn hiển thị cho tài khoản này trên giao diện CRM
ZALO_PERSONAL_ACCOUNT_LABEL=Personal Zalo 1
# Nhận và xử lý cả tin nhắn do chính mình gửi đi (true/false)
ZALO_PERSONAL_SELF_LISTEN=false

# ────────────────────────────────────────────────────────────────────────
# 🏢 Cấu Hình Official OA (Chỉ cần thiết khi ZALO_CHANNEL_MODE=official_oa)
# ────────────────────────────────────────────────────────────────────────
ZALO_OA_ID=
ZALO_OA_SECRET=
ZALO_OA_ACCESS_TOKEN=
ZALO_OA_REFRESH_TOKEN=

# ────────────────────────────────────────────────────────────────────────
# ⚓ Cấu Hình Webhook (Dùng cho cả Personal và OA để nhận sự kiện realtime)
# ────────────────────────────────────────────────────────────────────────
ZALO_WEBHOOK_VERIFY_TOKEN=alpha-crm-verify
ZALO_WEBHOOK_SECRET=

# ────────────────────────────────────────────────────────────────────────
# 🛡️ Cài Đặt Kiểm Soát Rủi Ro & An Toàn (Enforced Server-Side)
# ────────────────────────────────────────────────────────────────────────
# Danh sách SĐT kiểm thử (cách nhau bởi dấu phẩy), nếu khai báo thì chỉ gửi tới các SĐT này
ZALO_ALLOWED_TEST_UIDS=
# Giới hạn số lượng tin nhắn gửi đi tối đa trong mỗi đợt (batch)
ZALO_MAX_BATCH_SIZE=20
# Trần giới hạn số tin gửi đi tối đa của tài khoản trong 1 ngày
ZALO_DAILY_SEND_LIMIT=100
# Khung giờ yên lặng (ngăn chặn tự động gửi tin làm phiền khách hàng)
ZALO_QUIET_HOURS_START=21:00
ZALO_QUIET_HOURS_END=08:00
# Ngưỡng tỷ lệ gửi lỗi tối đa (%) trước khi hệ thống kích hoạt tự động khóa dừng (fail-closed)
ZALO_MAX_FAILURE_RATE_PERCENT=10
# Số lượng báo xấu tối đa nhận được trước khi dừng hệ thống gửi tin
ZALO_STOP_ON_REPORT_COUNT=1

# Tự động hóa tài khoản cá nhân & phân hệ tương tác
ZALO_ALLOW_PERSONAL_AUTOMATION=true
ZALO_ALLOW_FRIEND_AUTOMATION=false
ZALO_ALLOW_GROUP_AUTOMATION=false
ZALO_REQUIRE_HUMAN_APPROVAL=true
ZALO_HUMAN_APPROVAL_THRESHOLD=20
```

### 2.3 Thực Hiện Đăng Nhập Personal Zalo Lần Đầu (Bootstrap)

Vì lý do bảo mật cực kỳ nghiêm ngặt, Alpha CRM **không cho phép** truyền thông tin nhạy cảm (như cookie, mật khẩu, IMEI, hoặc QR code thô) qua giao thức HTTP tới Flutter. Mọi thao tác lấy quyền đăng nhập (Session) đều phải được thực hiện thông qua **CLI Bootstrap Script** chạy trực tiếp trên Server/Máy chủ chạy backend.

Thực hiện lệnh sau trên terminal của server để kích hoạt đăng nhập:

```bash
npm run zalo:login-personal
```

**Quá trình này sẽ thực hiện các bước tự động sau:**
1. Tạo thư mục bảo mật lưu trữ cục bộ `.data/zalo-personal/` (Đã được cấu hình gitignore để đảm bảo an toàn tuyệt đối).
2. Kết nối tới Zalo Web Gateway, sinh ra mã QR đăng nhập và lưu file ảnh tại đường dẫn cấu hình `ZALO_PERSONAL_QR_PATH`.
3. Hiển thị trực tiếp mã QR dạng ASCII trực quan trên Terminal.
4. **Hành động của Operator:** Mở ứng dụng Zalo trên điện thoại cá nhân, chọn tính năng quét QR và xác nhận đăng nhập cho trình duyệt Web Zalo.
5. Sau khi đăng nhập thành công, Node.js service sẽ nhận được thông tin session, tiến hành trích xuất credentials và lưu trữ dưới dạng JSON được mã hóa tại `ZALO_PERSONAL_CREDENTIALS_PATH`.
6. Chương trình in ra trạng thái đăng nhập thành công và tự động kết thúc an toàn. **Thông tin cookie và token nhạy cảm hoàn toàn không được hiển thị ra màn hình Terminal.**

> [!CAUTION]  
> - Tuyệt đối không xóa thư mục `.data/` trừ khi bạn muốn hủy phiên đăng nhập cũ và thực hiện đăng nhập lại từ đầu.
> - Không chia sẻ file `credentials.json` cho bất kỳ ai. File này chứa quyền kiểm soát tài khoản Zalo cá nhân của bạn dưới dạng phiên web.

### 2.4 Khởi Động Vận Hành Service

Khi đã hoàn tất đăng nhập và cấu hình, bạn có thể khởi động chạy dịch vụ:

```bash
# Khởi động dịch vụ ở chế độ production
npm start

# Hoặc khởi động ở chế độ hot-reload cho nhà phát triển (Development)
npm run dev
```

Dịch vụ mặc định sẽ lắng nghe tại cổng `http://localhost:8787`.

---

## 📡 3. Hệ Thống Danh Sách API Endpoints

Backend cung cấp các API endpoints chuẩn hóa sau để Flutter CRM UI và các hệ thống bên thứ ba tương tác:

| Phương thức | Đường dẫn API | Chức năng chi tiết | Yêu cầu Body mẫu |
| :--- | :--- | :--- | :--- |
| **GET** | `/health` | Kiểm tra tình trạng hoạt động (uptime, memory) của service. | *Không* |
| **GET** | `/api/zalo/status` | Lấy chi tiết trạng thái kết nối hiện tại của adapter đang hoạt động. | *Không* |
| **POST** | `/api/zalo/webhook` | Tiếp nhận và định tuyến các sự kiện realtime (tin nhắn mới, sự kiện OA) gửi từ Zalo. | Event JSON |
| **POST** | `/api/zalo/test-send` | Thực hiện gửi tin nhắn kiểm thử không ảnh hưởng tới hạn ngạch. | `{ "recipientId": "SĐT/UID", "message": "Nội dung" }` |
| **POST** | `/api/zalo/send-message` | Gửi tin nhắn thực tế qua kênh Zalo đang hoạt động (Đã qua kiểm tra rủi ro). | `{ "recipientId": "UID", "message": "Nội dung", "threadType": "user/group" }` |

### Phản hồi trạng thái mẫu (Response `/api/zalo/status`)

```json
{
  "connected": true,
  "mode": "personal_zca",
  "accountType": "personal",
  "accountLabel": "Personal Zalo 1",
  "listenerRunning": true,
  "lastEventAt": "2026-05-31T15:25:00.000Z",
  "version": "v0.2.0"
}
```

---

## 📱 4. Cấu Hình Trên Ứng Dụng Flutter CRM

### 4.1 Cấu Hình Trong Mục Settings

Operator đăng nhập ứng dụng Alpha CRM và điều hướng đến màn hình **Settings (Cài đặt hệ thống) → Kiểm soát rủi ro Zalo**:

*   **Zalo Backend Base URL:** Địa chỉ chạy của Node.js service (Ví dụ: `http://localhost:8787`). Hệ thống sẽ tự động gửi request `/health` để kiểm tra độ trễ kết nối.
*   **Preferred Channel:** Chọn lựa chế độ muốn áp dụng (Personal Zca, Official OA, Mock).
*   **Tham số rủi ro:** Bật/tắt và cấu hình các giá trị số lượng batch tối đa, trần gửi hàng ngày, giờ yên lặng tương ứng với cài đặt backend.

### 4.2 Thẻ Kết Nối & Giám Sát Trạng Thái

Trạng thái kết nối hiển thị sinh động trên giao diện cài đặt với các chỉ báo màu sắc trực quan:
*   🟢 **Connected - Personal Mode (zca-js):** Kết nối tài khoản cá nhân hoạt động bình thường. Sẵn sàng tương tác.
*   🔵 **Connected - Official OA Mode:** Kết nối tài khoản Zalo OA chính thức.
*   🟡 **Connected - Mock Mode:** Chế độ giả lập an toàn đang hoạt động.
*   🔴 **Disconnected / Configuration Error:** Không thể kết nối tới Backend service hoặc thông tin credentials đăng nhập bị thiếu.

---

## ⚡ 5. Quy Trình Chuyển Đổi Kênh Linh Hoạt (Switching Channel)

Hệ thống Alpha CRM được thiết kế để có thể chuyển đổi kênh linh hoạt mà không làm gián đoạn trải nghiệm của người dùng.

### Chuyển Từ Chế Độ Personal Sang Official OA

1. Truy cập trang quản trị Zalo Cloud và lấy thông tin: `ZALO_OA_ID`, `ZALO_OA_SECRET`, `ZALO_OA_ACCESS_TOKEN`, `ZALO_OA_REFRESH_TOKEN`.
2. Mở file `.env` của backend và cập nhật các trường tương ứng.
3. Thay đổi giá trị kênh: `ZALO_CHANNEL_MODE=official_oa`.
4. Khởi động lại dịch vụ backend (`npm run build && npm start`).
5. Trên ứng dụng Flutter, hệ thống sẽ tự động cập nhật trạng thái hiển thị của kênh sang **Official OA** mà không cần cấu hình lại mã nguồn Flutter.

### Chuyển Sang Chế Độ Mock / Test

1. Mở file `.env` của backend.
2. Thiết lập: `ZALO_CHANNEL_MODE=mock`.
3. Khởi động lại backend service.
4. Mọi yêu cầu gửi tin từ CRM lúc này sẽ luôn trả về kết quả thành công giả lập trong tích tắc, giúp bạn an tâm demo sản phẩm cho khách hàng.

---

## 📖 6. Tài Liệu Liên Quan Trực Tiếp

Để tối ưu hóa quá trình vận hành và hiểu sâu hơn về hệ thống bảo mật, vui lòng tham khảo các tài liệu liên quan sau:
*   📄 **Quy chế kiểm soát rủi ro & Chính sách Zalo:** [zalo-integration-and-risk-controls.md](file:///d:/Dev/NodeJS/alpha-studio/tools/alpha-crm/docs/zalo-integration-and-risk-controls.md)
*   📐 **Bản đặc tả kiến trúc tích hợp hệ thống (SPEC):** [SPEC.md](file:///d:/Dev/NodeJS/alpha-studio/tools/alpha-crm/SPEC.md)
*   💾 **Hướng dẫn chi tiết module backend:** [integration/zalo-bot-service/README.md](file:///d:/Dev/NodeJS/alpha-studio/tools/alpha-crm/integration/zalo-bot-service/README.md)
