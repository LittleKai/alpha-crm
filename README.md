# Alpha CRM - Hệ thống Quản lý Khách hàng & Tiếp thị Zalo

Alpha CRM là một ứng dụng giao diện (CRM UI) đa nền tảng được phát triển bằng Flutter, hỗ trợ các nền tảng Web, Android và Windows Desktop. Dự án được thiết kế chuyên biệt để phục vụ các chiến dịch tiếp thị (Marketing) và quản lý tương tác trên nền tảng Zalo với thiết kế hiện đại, responsive cao và tối ưu trải nghiệm người dùng.

---

## 📸 Giao diện mẫu & Thiết kế
Hệ thống tuân thủ nghiêm ngặt **Design System** tiêu chuẩn (định nghĩa trong [docs/01-design-system.md](file:///d:/Dev/NodeJS/alpha-studio/tools/alpha-crm/docs/01-design-system.md)) với các bộ mã màu hiện đại, khoảng cách (spacing) đồng bộ, kiểu chữ Inter thanh lịch và hiệu ứng responsive mượt mà trên cả Mobile, Tablet lẫn Desktop.

Các ảnh giao diện thiết kế mẫu được lưu giữ trong thư mục [img/](file:///d:/Dev/NodeJS/alpha-studio/tools/alpha-crm/img/) để tham chiếu tính tương đồng và độ chính xác của giao diện UI thực tế.

---

## ✨ Các Tính Năng Chính (Core Features)

Dự án bao gồm 17 luồng màn hình nghiệp vụ chính được chia thành các phân hệ cụ thể:

### 1. Phân hệ Tổng quan & Khách hàng
*   **Tổng quan (Dashboard):** Biểu đồ hiệu suất chiến dịch trực quan (sử dụng `fl_chart`), các thẻ chỉ số (metric cards) tương tác và danh sách hành động nhanh.
*   **Khách hàng (CRM Customers):** Bộ lọc tìm kiếm nâng cao, phân loại nhóm, danh sách khách hàng dạng bảng tối ưu kèm trạng thái chi tiết.
*   **Quản lý mẫu nội dung:** Nơi quản lý các mẫu tin nhắn soạn sẵn (Text, Image, Link) hỗ trợ tìm kiếm nhanh và thêm mới.

### 2. Phân hệ Tin nhắn (Messaging)
*   **Gửi tin hàng loạt (Bulk Messaging):** Hỗ trợ thiết lập chiến dịch gửi tin nhắn tới danh sách số điện thoại hoặc nhóm. Tích hợp cảnh báo khi chưa kết nối tài khoản Zalo.
*   **Live Chat:** Giao diện nhắn tin đa luồng với bộ lọc hội thoại, danh sách khách hàng và khung chat thời gian thực.
*   **Chatbot tự động:** Thiết lập và quản lý các kịch bản phản hồi tự động dựa trên từ khóa hoặc sự kiện.
*   **Lịch sử gửi tin:** Thống kê kết quả chiến dịch gửi tin kèm biểu đồ trực quan, bộ lọc trạng thái (Thành công, Thất bại) và tùy chọn gửi lại (Retry).

### 3. Phân hệ Bạn bè (Friend Operations)
*   **Kết bạn theo SĐT:** Chiến dịch gửi lời mời kết bạn tự động theo danh sách số điện thoại có sẵn.
*   **Kết bạn từ Nhóm:** Quét thành viên từ các nhóm Zalo tham gia và gửi lời mời kết bạn hàng loạt.
*   **Tự động duyệt kết bạn:** Cấu hình tự động chấp nhận lời mời kết bạn dựa trên các tiêu chí định sẵn.
*   **Lịch sử kết bạn:** Nhật ký chi tiết của các chiến dịch kết bạn theo thời gian.

### 4. Phân hệ Nhóm (Group Operations)
*   **Quét thành viên:** Hỗ trợ quét danh sách thành viên từ các nhóm Zalo.
*   **Tham gia nhóm:** Tự động tham gia danh sách nhóm qua link/QR code.
*   **Mời vào nhóm:** Gửi lời mời tham gia nhóm hàng loạt cho danh sách bạn bè.
*   **Tạo nhóm mới:** Thiết lập tạo nhóm Zalo tự động và mời thành viên ban đầu.
*   **Rời nhóm:** Quản lý và lọc các nhóm không hoạt động để tự động rời đi hàng loạt.

### 5. Cài đặt hệ thống (System Settings)
*   Quản lý danh sách tài khoản Zalo liên kết và trạng thái kết nối.
*   Cấu hình Proxy (IP/Port/Username/Password) riêng cho từng tài khoản hoặc dùng chung.
*   Cấu hình giãn cách thời gian (delay) chạy các tác vụ tránh spam, chống block tài khoản.

---

## 🛠️ Công Nghệ Sử Dụng (Tech Stack)

*   **Framework:** [Flutter 3](https://flutter.dev/)
*   **Ngôn ngữ:** [Dart SDK ^3.10.7](https://dart.dev/)
*   **Quản lý trạng thái (State Management):** `flutter_riverpod` (kết hợp `StateNotifierProvider` và `StateProvider`).
*   **Điều hướng (Routing):** `go_router` cấu hình tập trung thông qua `AppRouter`.
*   **Biểu đồ (Charts):** `fl_chart`.
*   **Bảng dữ liệu nâng cao:** `data_table_2` (hỗ trợ scroll mượt mà trên Desktop).
*   **Font chữ:** `google_fonts` (Inter).
*   **Định dạng dữ liệu:** `intl`.

---

## 📁 Cấu Trúc Thư Mục Dự Án (Directory Structure)

```text
lib/
├── main.dart                   # Điểm khởi chạy ứng dụng (Entry point)
├── app/                        # Cấu hình cốt lõi của ứng dụng
│   ├── routing/                # Định nghĩa các tuyến đường (AppRoutes, AppRouter)
│   ├── theme/                  # Định nghĩa Design System (Colors, Spacing, TextStyles, Theme)
│   └── shell/                  # App Shell, Responsive Scaffold (Sidebar, Topbar)
├── features/                   # Các module tính năng (Feature-first Architecture)
│   ├── dashboard/              # Trang tổng quan
│   ├── customers/              # Quản lý khách hàng
│   ├── content/                # Quản lý mẫu nội dung
│   ├── messaging/              # Phân hệ tin nhắn (Bulk, Live Chat, Chatbot, History)
│   ├── friends/                # Phân hệ bạn bè (By Phone, By Group, Auto Approve, History)
│   ├── groups/                 # Phân hệ nhóm (Scan, Join, Invite, Create, Leave)
│   └── settings/               # Cài đặt hệ thống
├── shared/                     # Các thành phần dùng chung (Reusable Primitives)
│   ├── widgets/                # Các widget giao diện tùy biến (Buttons, Cards, Tables, Tabs, Inputs,...)
│   └── utils/                  # Tiện ích bổ trợ (Responsive breakpoints, formatters)
└── mock/                       # Dữ liệu mô phỏng cho luồng UI (Contacts, Campaigns, Groups,...)
```

---

## 🚀 Hướng Dẫn Phát Triển (Development Setup)

### Yêu cầu hệ thống
*   Đã cài đặt **Flutter SDK** phiên bản tương thích (hỗ trợ Dart SDK `^3.10.7`).
*   Đã cài đặt các công cụ biên dịch tương ứng cho nền tảng đích (Chrome cho Web, Android Studio cho Android, Visual Studio C++ cho Windows).

### Cài đặt và Chạy thử

1.  **Tải các gói thư viện phụ thuộc:**
    ```bash
    flutter pub get
    ```

2.  **Kiểm tra và phân tích cú pháp tĩnh:**
    ```bash
    flutter analyze
    ```

3.  **Chạy thử nghiệm (Unit/Widget Tests):**
    ```bash
    flutter test
    ```

4.  **Chạy ứng dụng trên môi trường cục bộ:**
    *   *Chạy trên Trình duyệt Web (Chrome):*
        ```bash
        flutter run -d chrome
        ```
    *   *Chạy ứng dụng Windows Desktop:*
        ```bash
        flutter run -d windows
        ```

### Biên dịch đóng gói (Build Production)

*   **Web:**
    ```bash
    flutter build web
    ```
*   **Android (APK):**
    ```bash
    flutter build apk
    ```
*   **Windows Desktop:**
    ```bash
    flutter build windows
    ```

---

## 📄 Tài Liệu Tham Khảo (Documentation)

Các tài liệu được lưu trữ có cấu trúc trong thư mục `docs/`:
*   **[docs/guides/](file:///d:/Dev/NodeJS/alpha-studio/tools/alpha-crm/docs/guides/)**: Sổ tay cài đặt & vận hành hệ thống CRM và tích hợp Zalo.
*   **[docs/compliance/](file:///d:/Dev/NodeJS/alpha-studio/tools/alpha-crm/docs/compliance/)**: Các quy chế an toàn & kiểm soát rủi ro chống block tài khoản Zalo.
*   **[docs/specs/](file:///d:/Dev/NodeJS/alpha-studio/tools/alpha-crm/docs/specs/)**: Đặc tả tích hợp nghiệp vụ, kế hoạch triển khai và phân tích gaps luồng dữ liệu.
*   **[docs/api-catalog/](file:///d:/Dev/NodeJS/alpha-studio/tools/alpha-crm/docs/api-catalog/)**: Danh mục phân loại API và tài liệu tra cứu thư viện lõi Zalo (`zca-js`).
*   **[docs/releases/](file:///d:/Dev/NodeJS/alpha-studio/tools/alpha-crm/docs/releases/)**: Checklist kiểm duyệt phát hành phiên bản production.
## ?? Local-First Live Chat

T? Phase 2+, h? th?ng h? tr? c� ch? Local-First Live Chat:
- To�n b? n?i dung tin nh?n v� file ��nh k�m ��?c l�u tr?c ti?p xu?ng \etter-sqlite3\ t?i Local Bridge.
- Client Flutter giao ti?p qua API \/local/*\ �? load/g?i tin nh?n si�u t?c m� kh�ng b? delay ho?c gi?i h?n t?i tr?ng (payload) t? Cloud.
- T�nh n�ng Cache c?c b? (\sqflite\) tr�n Flutter gi�p hi?n th? d? li?u ngay l?p t?c, fallback c?c k? m�?t m� khi Local Bridge offline.
- T? �?ng d?n d?p c�c ?nh thumbnail v� d? li?u cache h?t h?n �? ti?t ki?m dung l�?ng �?a.

