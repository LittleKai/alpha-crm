# 📊 Báo Cáo Phân Tích Độ Lệch & Tiềm Năng Tích Hợp (Gap Analysis)

Báo cáo này phân tích chi tiết các tính năng hiện tại của **Alpha CRM** so với khả năng thực tế của 3 dự án tham khảo (**`zca-js`**, **`zalo-bot-js`**, và **`Deplao-App`**). Từ đó, chúng ta xác định những gì đã tích hợp, những gì vẫn đang ở dạng giả lập (Mock), và các phần có thể tiếp tục tham chiếu để nâng cấp ứng dụng.

---

## 📌 Bảng Tổng Hợp Trạng Thái Tích Hợp

| Dự Án Tham Khảo | Trạng Thái Hiện Tại | Tỷ Lệ Tích Hợp Lọc | Các Tính Năng Đang Ở Dạng MOCK (Giả Lập) trên Giao Diện |
| :--- | :--- | :--- | :--- |
| **zca-js** (Web Personal API) | `Đã tích hợp cơ bản` | ~10% | Tự động duyệt kết bạn, Rời nhóm hàng loạt, Gửi file/stickers, Quét thành viên nhóm. |
| **zalo-bot-js** (Official SDK) | `Mới chỉ dựng khung rỗng` | ~5% | Tự động refresh Access Token, Router Webhook sự kiện, Gửi tin nhắn mẫu ZNS. |
| **Deplao-App** (Desktop Wrapper) | `Mới tham khảo ý tưởng` | ~0% (Về code) | Quản lý Cookie đa phiên, Nhúng Webview Dark Glass, Chế độ tàng hình chat (Ẩn danh đã xem). |

---

## 1. Phân Tích Độ Lệch Chi Tiết Từng Dự Án

### 📂 Dự án tham khảo 1: `zca-js` (Zalo Web Personal API)

#### 🟢 Những phần ĐÃ tích hợp vào Alpha CRM:
1.  **Đăng nhập QR (CLI)**: Tệp `personal-login.ts` sử dụng `api.loginQR` để quét và lưu credentials cục bộ ở phía backend.
2.  **Đăng nhập bằng Session**: `personal-zca-channel.ts` đọc credentials đã lưu và duy trì phiên kết nối thông qua `zalo.login(credentials)`.
3.  **Lắng nghe sự kiện (Listener)**: Hỗ trợ khởi động (`api.listener.start()`) và dừng lắng nghe các sự kiện thời gian thực.
4.  **Gửi tin nhắn cơ bản**: Hỗ trợ gửi tin nhắn văn bản thông thường (`api.sendMessage`) đến người dùng cá nhân hoặc nhóm.

#### 🔴 Những phần CHƯA tích hợp nhưng `zca-js` ĐÃ HỖ TRỢ (Tiềm năng nâng cấp rất lớn):
Thư viện `zca-js` có sẵn **149 APIs** cực kỳ mạnh mẽ, nhưng Alpha CRM hiện đang để nhiều tính năng này ở dạng **MOCK** (Giao diện giả lập):

1.  **Tự động duyệt kết bạn (`acceptFriendRequest.ts`)**:
    *   *Hiện tại*: Màn hình `AutoApproveScreenPlaceholder` hoàn toàn là giao diện tĩnh (Mock).
    *   *Khả năng*: Có thể kết nối nút "Bật tự động duyệt" với API `acceptFriendRequest` của `zca-js` để duyệt kết bạn realtime khi có sự kiện `friendRequest` gửi đến.
2.  **Quản lý Nhóm hàng loạt (`leaveGroup.ts`, `createGroup.ts`, `removeUserFromGroup.ts`)**:
    *   *Hiện tại*: Màn hình "Rời nhóm hàng loạt" (`LeaveGroupsScreen`) đang dùng dữ liệu nhóm mock và tác vụ rời nhóm chạy giả lập (chỉ thêm dòng log).
    *   *Khả năng*: Sử dụng `api.getAllGroups()` để lấy danh sách nhóm thật của tài khoản và sử dụng `api.leaveGroup(groupId)` để thực hiện rời nhóm thật hàng loạt.
3.  **Quét thành viên nhóm (`getGroupMembersInfo.ts`)**:
    *   *Hiện tại*: Tính năng quét thành viên nhóm (`ScanMembersScreen`) là mock.
    *   *Khả năng*: Sử dụng `api.getGroupMembersInfo(groupId)` để lấy danh sách toàn bộ số điện thoại/tài khoản thành viên trong nhóm Zalo thật.
4.  **Gửi tin nhắn Rich Media & Nhãn dán (`sendSticker.ts`, `uploadAttachment.ts`, `sendVideo.ts`)**:
    *   *Hiện tại*: Phần chat và gửi tin nhắn mới chỉ hỗ trợ text thô.
    *   *Khả năng*: Sử dụng `uploadAttachment` và `sendSticker` để cho phép người dùng gửi hình ảnh, file báo giá dạng PDF và nhãn dán động của Zalo.
5.  **Tương tác Chat nâng cao (`addReaction.ts`, `deleteMessage.ts`, `undo.ts`)**:
    *   *Khả năng*: Thêm tính năng thả cảm xúc (tim, like), thu hồi tin nhắn (`undo`), hoặc xóa tin nhắn ở phía người gửi (`deleteMessage`).

---

### 📂 Dự án tham khảo 2: `zalo-bot-js` (Zalo Official Account SDK)

#### 🟢 Những phần ĐÃ tích hợp vào Alpha CRM:
1.  **Cơ chế chuyển đổi kênh (Channel Switcher)**: Dựng cấu trúc `OfficialOaChannel` kế thừa interface `ZaloChannel` để sẵn sàng định tuyến tin nhắn.

#### 🔴 Những phần CHƯA tích hợp nhưng `zalo-bot-js` ĐÃ HỖ TRỢ:
Dự án tham khảo này là một bộ SDK hoàn chỉnh để xây dựng chatbot chuyên nghiệp cho Zalo OA chính thức, nhưng Alpha CRM hiện đang bỏ trống phần này:

1.  **Quản lý Token tự động (OAuth 2.0 Rotation)**:
    *   *Khả năng*: Tham chiếu cách `zalo-bot-js` quản lý thời hạn sống của `Access Token` (2-6 giờ) và tự động gọi API làm mới bằng `Refresh Token` để tránh việc mất kết nối giữa chừng.
2.  **Định tuyến Webhook thông minh (`core/Bot.ts`)**:
    *   *Khả năng*: Sử dụng bộ lọc (filters) và xử lý sự kiện (handlers) của `zalo-bot-js` để phân tích các gói webhook gửi đến từ Zalo OA, tự động phân loại sự kiện (người dùng gửi tin nhắn, người dùng quan tâm OA, v.v.).
3.  **Gửi tin nhắn ZNS & Mẫu biểu biểu diễn (Templates)**:
    *   *Khả năng*: Tích hợp sâu thư viện để gửi các mẫu tin nhắn chăm sóc khách hàng chính thức, tin nhắn khảo sát, tin nhắn có nút bấm tương tác (Action Buttons) đúng tiêu chuẩn của Zalo OA API.

---

### 📂 Dự án tham khảo 3: `Deplao-App` (Zalo Desktop Wrapper)

#### 🟢 Những phần ĐÃ tham khảo về mặt thiết kế:
1.  **Thiết kế UI giao diện tối (Dark/Glass UI)**: Phản chiếu ý tưởng giao diện hiện đại, tối giản và cao cấp cho CRM.
2.  **Quản lý đa tài khoản (Multi-Account)**: Ý tưởng cho phép kết nối song song nhiều tài khoản Zalo cá nhân cùng lúc và chuyển đổi mượt mà.

#### 🔴 Những phần CHƯA tích hợp nhưng `Deplao-App` ĐÃ HỖ TRỢ:
`Deplao-App` là ứng dụng Electron đóng gói giao diện Web Zalo, cung cấp khả năng can thiệp trực tiếp vào mã DOM của trình duyệt:

1.  **Đăng nhập đa phiên bằng Chromium Partition (`persist:session_name`)**:
    *   *Khả năng*: Nếu Alpha CRM muốn tích hợp một màn hình "Xem trực tiếp Web Zalo" dạng nhúng (WebView) cho từng tài khoản, ta có thể học cách `Deplao-App` phân chia luồng cookie và session để đăng nhập nhiều tài khoản Zalo Web cùng lúc trên một màn hình mà không bị đá phiên nhau ra.
2.  **Tùy biến giao diện Web Zalo bằng CSS (`custom_style.css`)**:
    *   *Khả năng*: Nhúng tệp CSS Dark Glass của `Deplao-App` vào các frame Web Zalo được nhúng để biến giao diện chat mặc định của Zalo thành một giao diện đồng bộ với tông màu tối cao cấp của Alpha CRM.
3.  **Chặn sự kiện đã xem/đang soạn thảo (Seen/Typing Interception)**:
    *   *Khả năng*: Tham khảo file `preload.js` để viết script chặn các request gửi sự kiện "đã xem" (`/api/message/seen`) hoặc "đang nhập tin" (`/api/message/typing`). Điều này giúp nhân viên bán hàng đọc tin nhắn của khách hàng mà khách hàng không hề biết (chế độ ẩn danh), nâng cao tính riêng tư trong chăm sóc khách hàng.

---

## 📈 Lộ Trình Khuyến Nghị (Roadmap) Để Nâng Cấp Alpha CRM

Để nâng cấp tối đa CRM này từ dạng giao diện tĩnh/giả lập sang chạy thực tế dựa trên các nguồn tham khảo hiện có, bạn nên thực hiện theo thứ tự ưu tiên sau:

1.  **Ưu tiên 1: Thực hiện hóa chức năng Duyệt kết bạn & Rời nhóm**
    *   *API Tham chiếu*: `acceptFriendRequest.ts` & `leaveGroup.ts` trong `zca-js`.
    *   *Tác động*: Biến các nút nhấn trên màn hình `AutoApproveScreenPlaceholder` và `LeaveGroupsScreen` thành thật chỉ bằng cách kết nối API backend tương ứng.
2.  **Ưu tiên 2: Triển khai gửi tin nhắn đa phương tiện (Rich Messages)**
    *   *API Tham chiếu*: `uploadAttachment.ts` & `sendSticker.ts` trong `zca-js`.
    *   *Tác động*: Cho phép nhân viên gửi ảnh chụp màn hình, file PDF báo giá trực tiếp trên thanh hội thoại CRM.
3.  **Ưu tiên 3: Xây dựng Chế độ Ẩn danh chăm sóc khách hàng**
    *   *Script Tham chiếu*: `preload.js` trong `Deplao-App`.
    *   *Tác động*: Cho phép đọc tin nhắn của khách hàng mà không hiện trạng thái "đã xem", giúp nhân viên có thời gian chuẩn bị kịch bản phản hồi tốt nhất.
