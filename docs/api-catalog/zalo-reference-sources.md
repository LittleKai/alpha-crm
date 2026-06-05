# 📚 Danh Sách Dự Án Tham Khảo Tích Hợp Zalo

Tài liệu này ghi nhận chi tiết 3 dự án mã nguồn tham khảo được sử dụng để xây dựng, tích hợp và phát triển các chức năng liên quan đến Zalo trong **Alpha CRM**. Doanh nghiệp và kỹ sư lập trình có thể dựa vào tài liệu này để kiểm tra chéo (double-check), cập nhật hoặc sửa lỗi logic kết nối Zalo.

---

## 📌 Bảng Tổng Quan Các Dự Án Tham Khảo

| Tên Dự Án | Đường Dẫn Cục Bộ (Local Path) | Vai Trò trong Alpha CRM | Loại Kết Nối |
| :--- | :--- | :--- | :--- |
| **zca-js** | `D:\Dev\2.reference_pj\Zalo-ref\zca-js` | Thư viện lõi điều khiển API Zalo Web cá nhân | Unofficial Web API (Cá nhân) |
| **zalo-bot-js** | `D:\Dev\2.reference_pj\Zalo-ref\zalo-bot-js` | Tham khảo logic API chatbot chính thức | Official OpenAPI (Chính thức) |
| **Deplao-App** | `D:\Dev\2.reference_pj\Zalo-ref\Deplao-App` | Tham khảo cấu trúc ứng dụng và giao diện Zalo | UI/UX & Flow Reference |

---

## 🔍 Chi Tiết Từng Dự Án Tham Khảo

### 1. Thư viện Lõi Tự Động Hóa Cá Nhân: `zca-js`
> [!IMPORTANT]
> Đây là thư viện cốt lõi điều khiển các tác vụ tự động hóa trên tài khoản Zalo cá nhân (Personal Zalo) hiện tại của Alpha CRM.

*   **Đường dẫn cục bộ**: [D:\Dev\2.reference_pj\Zalo-ref\zca-js](file:///D:/Dev/2.reference_pj/Zalo-ref/zca-js)
*   **Các thành phần tham khảo chính**:
    *   `src/zalo.ts` & `src/context.ts`: Cách thức khởi tạo phiên kết nối, quản lý thông tin đăng nhập (Credentials) thông qua Session/Cookie, mã nhận diện thiết bị IMEI và chuỗi User-Agent.
    *   `src/apis/login.ts` & `loginQR.ts`: Cơ chế đăng nhập bằng tài khoản hoặc quét mã QR động.
    *   `src/apis/sendMessage.ts`: Logic gửi tin nhắn văn bản, tin nhắn hình ảnh, tệp đính kèm đến tài khoản cá nhân (`ThreadType.User`) hoặc nhóm chat (`ThreadType.Group`).
    *   `src/apis/listen.ts`: Lắng nghe sự kiện thời gian thực (realtime listener) từ Web Zalo như nhận tin nhắn, có yêu cầu kết bạn mới, v.v.
*   **Cách tích hợp trong Alpha CRM**:
    Được cài đặt trực tiếp dưới dạng dependency từ NPM registry trong file `package.json` của Node.js service để tối ưu hóa tính di động và triển khai dễ dàng:
    ```json
    "zca-js": "^2.1.2"
    ```
    *Lưu ý: Mặc dù cài đặt từ NPM, lập trình viên có thể mở thư mục dự án cục bộ tại `D:\Dev\2.reference_pj\Zalo-ref\zca-js` để đọc mã nguồn chi tiết, nghiên cứu và hiểu sâu hơn về cơ chế hoạt động của các API.*

### 2. Logic API Chính Thức: `zalo-bot-js`
> [!NOTE]
> Được sử dụng để tham khảo và xây dựng luồng kết nối Zalo Official Account (OA) chính thức thông qua OpenAPI của Zalo.

*   **Đường dẫn cục bộ**: [D:\Dev\2.reference_pj\Zalo-ref\zalo-bot-js](file:///D:/Dev/2.reference_pj/Zalo-ref/zalo-bot-js)
*   **Các thành phần tham khảo chính**:
    *   Cách thức đăng ký Webhook và xử lý các gói tin JSON sự kiện gửi từ máy chủ chính thức của Zalo.
    *   Logic xác thực và làm mới Token (Access Token & Refresh Token) theo tiêu chuẩn bảo mật OAuth 2.0 của Zalo OA.
    *   Định dạng dữ liệu gửi tin nhắn mẫu chính thức (Template Messages, Tin nhắn ZNS).
*   **Cách tích hợp trong Alpha CRM**:
    Nằm trong lớp Adapter dành cho kênh chính thức (`OfficialOaChannel`), đóng vai trò như một giải pháp dự phòng hoặc tùy chọn nâng cấp chính thống khi doanh nghiệp cần độ ổn định tuyệt đối và tuân thủ hoàn toàn chính sách của Zalo.

### 3. Giao Diện & Luồng Nghiệp Vụ: `Deplao-App`
> [!TIP]
> Sử dụng để tham khảo cách thiết kế sơ đồ giao diện người dùng (UI/UX) và luồng nghiệp vụ tương tác Zalo thực tế trong môi trường doanh nghiệp.

*   **Đường dẫn cục bộ**: [D:\Dev\2.reference_pj\Zalo-ref\Deplao-App](file:///D:/Dev/2.reference_pj/Zalo-ref/Deplao-App)
*   **Các thành phần tham khảo chính**:
    *   Cấu trúc luồng điều hướng của một ứng dụng quản lý Zalo tập trung.
    *   Thiết kế giao diện hộp thoại quét mã QR đăng nhập Zalo trực quan trên ứng dụng client.
    *   Kịch bản tương tác người dùng (User Flows) đối với các tính năng: gửi tin hàng loạt (bulk messaging), tự động chấp nhận kết bạn và quản lý bộ lọc danh sách nhóm chat.

---

## 🛠️ Hướng Dẫn Kiểm Tra Chéo (Double-Check) Logic

Khi có bất kỳ lỗi kết nối hoặc thay đổi giao thức nào từ phía Zalo, bạn hãy tiến hành kiểm tra theo quy trình sau:

1.  **Kiểm tra giao thức Web Zalo**:
    *   Mở dự án `zca-js` cục bộ.
    *   Chạy thử các kịch bản test đăng nhập/gửi tin độc lập trong `zca-js` để xác định lỗi xuất phát từ thư viện kết nối hay từ giao diện Alpha CRM.
2.  **Kiểm tra API Webhook & Token OA**:
    *   Mở dự án `zalo-bot-js`.
    *   Kiểm tra xem cấu trúc dữ liệu JSON nhận được từ Webhook hoặc API gửi tin có khớp với chuẩn được cấu hình trong `OfficialOaChannel` của Alpha CRM hay không.
3.  **Kiểm tra tính đồng nhất của UI**:
    *   Mở dự án `Deplao-App` để đối chiếu các bước thiết lập tài khoản, cách xử lý sự cố đăng nhập trên giao diện để tối ưu hóa trải nghiệm người dùng trên client.
