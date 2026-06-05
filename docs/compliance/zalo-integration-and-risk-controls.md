# 🛡️ Quy Trình Tích Hợp Zalo & Cơ Chế Kiểm Soát Rủi Ro CRM

> [!NOTE]  
> **Cập nhật mới nhất:** 2026-05-31 20:00 +07:00  
> **Phạm vi tài liệu:** Định hướng chiến lược tích hợp Zalo của **Alpha CRM** — Ưu tiên tài khoản cá nhân (Personal-First) qua thư viện `zca-js`, duy trì kênh Official OA làm dự phòng phụ, và thiết lập hệ thống kiểm soát rủi ro đa tầng nhằm bảo vệ tài khoản người dùng tối đa trước chính sách siết chặt của Zalo.

---

## 🗺️ 1. Định Hướng Tích Hợp Hệ Thống — Personal-First

Nhận thấy nhu cầu thực tế của các doanh nghiệp vừa và nhỏ trong việc tương tác trực tiếp, thân thiện và linh hoạt thông qua tài khoản Zalo cá nhân, Alpha CRM lựa chọn định hướng **Personal-First** làm trọng tâm phát triển. 

Hệ thống ưu tiên kết nối tài khoản cá nhân thông qua Node.js service sử dụng thư viện `zca-js`. Song song đó, hệ thống vẫn duy trì khả năng tích hợp **Zalo Official Account (OA)** như một kênh truyền thông chính thống bổ trợ khi doanh nghiệp có nhu cầu gửi tin nhắn thương hiệu, tin nhắn ZNS hoặc áp dụng các kịch bản tương tác tự động quy mô lớn đã đăng ký chính thức với Zalo.

### 📐 Kiến Trúc Bảo Mật & Ranh Giới Trách Nhiệm

Để bảo vệ tài khoản Zalo của người dùng khỏi bị rò rỉ dữ liệu hoặc bị quét nhận diện công cụ tự động hóa, Alpha CRM triển khai mô hình phân tách trách nhiệm nghiêm ngặt:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        Alpha CRM Flutter Client                        │
│  - Giao diện giám sát kết nối & cấu hình tham số an toàn               │
│  - Bộ lọc kiểm soát rủi ro mức Client (Advisory Compliance Guard)      │
│  - Tuyệt đối không lưu trữ: Cookie, Token, IMEI, QR raw, Session.     │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │  Yêu cầu gửi tin & trạng thái
                                   ▼  (HTTP REST API)
┌────────────────────────────────────────────────────────────────────────┐
│                   Node.js Backend Zalo Bot Service                     │
│  - Cổng thực thi chính sách an toàn (Server-Side Enforcement Guard)    │
│  - Quản lý & Đóng gói Adapter: PersonalZca, OfficialOa, Mock          │
│  - Lưu trữ credentials đăng nhập an toàn trong thư mục gitignored .data│
│  - Quản lý phiên làm việc & Listener thời gian thực                    │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │  Kết nối an toàn /
                                   │  Giao thức HTTPS / Web Zalo
                                   ▼
                      ┌────────────────────────┐
                      │    Zalo Cloud API /    │
                      │    Zalo Web Gateway    │
                      └────────────────────────┘
```

#### Nguyên Tắc An Toàn Dữ Liệu Bắt Buộc:
*   **Flutter chỉ đóng vai trò Advisory (Khuyến nghị):** Client UI có nhiệm vụ hiển thị cảnh báo rủi ro trực quan và ngăn chặn operator thực hiện các thao tác sai lầm ngay trên giao diện. Tuy nhiên, Flutter không lưu trữ bất kỳ thông tin đăng nhập nhạy cảm nào và không chịu trách nhiệm thực thi cuối cùng.
*   **Backend là Enforcement Boundary (Ranh giới thực thi):** Mọi chính sách kiểm soát rủi ro (Hạn mức ngày, khung giờ yên lặng, duyệt thủ công, stop-condition) đều được thực thi độc lập và bắt buộc ở mức Server. Dù Flutter Client có bị chỉnh sửa hoặc gửi yêu cầu trực tiếp, Backend vẫn sẽ từ chối xử lý nếu vi phạm cấu hình an toàn trên Server.
*   **Cô lập thông tin nhạy cảm:** Toàn bộ cookie, IMEI thiết bị giả lập, tệp tin cấu hình session của tài khoản cá nhân được lưu trữ độc lập trong thư mục `.data/` của Backend. Thư mục này nằm ngoài tầm tiếp cận của Client HTTP và bắt buộc phải nằm trong danh sách `.gitignore` của dự án để ngăn chặn rò rỉ lên repository công khai.

---

## ⚖️ 2. Cơ Sở Chính Sách Zalo & Phân Tích Rủi Ro

Hệ thống kiểm soát rủi ro của Alpha CRM được xây dựng dựa trên sự đối chiếu nghiêm ngặt với các điều khoản vận hành chính thức của Zalo nhằm giảm thiểu tối đa khả năng tài khoản bị gắn cờ vi phạm:

1.  **Chính sách chống Spam và Làm phiền:** Zalo định nghĩa spam là các hành vi gửi tin nhắn hàng loạt với tần suất cao, tìm kiếm và gửi lời mời kết bạn liên tục tới những người dùng chưa có mối quan hệ bạn bè từ trước. Mọi hành vi mang tính chất lặp đi lặp lại không tự nhiên đều bị hệ thống AI của Zalo quét và phân tích tự động.
2.  **Rủi ro sử dụng Công cụ bên thứ ba:** Việc đăng nhập tài khoản cá nhân thông qua phiên bản Web giả lập (`zca-js`) là giải pháp không chính thức (Unofficial). Zalo có quyền tạm khóa hoặc vô hiệu hóa vĩnh viễn các tài khoản phát sinh kết nối từ các thiết bị không xác định, trình giả lập hoặc có hoạt động bất thường kéo dài.
3.  **Hạn chế tự động kết bạn:** Việc gửi lời mời kết bạn quá nhiều trong khoảng thời gian ngắn (vượt quá 30-50 lời mời/ngày đối với tài khoản thường) sẽ khiến tính năng kết bạn bị khóa tạm thời từ 1-7 ngày.
4.  **Cơ chế báo xấu (Report):** Người nhận tin nhắn có quyền báo xấu tin nhắn từ người lạ, bài đăng hoặc hành vi của tài khoản. Đây là nguồn dữ liệu quan trọng nhất để Zalo rà soát và áp dụng các hình phạt khóa tài khoản.

> [!WARNING]  
> Sử dụng tích hợp Zalo cá nhân qua `zca-js` luôn đi kèm với rủi ro tài khoản bị hạn chế hoặc khóa vĩnh viễn nếu vận hành sai cách. Alpha CRM cung cấp các công cụ kiểm soát để **giảm thiểu** rủi ro này về mức thấp nhất, nhưng không thể loại bỏ hoàn toàn. Doanh nghiệp cần cân nhắc sử dụng các tài khoản phụ hoặc tài khoản chuyên dụng cho việc tiếp thị tự động.

Nguồn tham chiếu chính sách chính thức:
*   [Chính sách cộng đồng Zalo](https://help.zalo.me/huong-dan/chuyen-muc/chinh-sach-cong-dong-zalo/)
*   [Lỗi tài khoản Zalo bị tạm thời vô hiệu hóa](https://help.zalo.me/huong-dan/chuyen-muc/quan-ly-tai-khoan-zalo/loi-thuong-gap/tai-khoan-zalo-bi-tam-thoi-vo-hieu-hoa/)
*   [Quy định về hạn chế tính năng kết bạn](https://help.zalo.me/huong-dan/chuyen-muc/ban-be-va-danh-ba/khong-ket-ban-duoc-tren-zalo-ly-do-va-cach-khac-phuc/)
*   [Quy định và phí gửi tin Zalo Official Account](https://oa.zalo.me/home/resources/news/thong-bao-chinh-sach-gui-tin-va-quy-dinh-phi-gui-tin_1433049880779375099)

---

## 📊 3. Ma Trận Đánh Giá Hành Vi Rủi Ro & Cơ Chế Kiểm Soát

Hệ thống chia nhỏ các hoạt động tương tác Zalo thành các cấp độ rủi ro khác nhau để áp dụng cơ chế kiểm duyệt tương xứng:

### 🔴 Cấp độ: CRITICAL (Rất Cao) — Yêu cầu kiểm soát nghiêm ngặt & Bật thủ công

Các hành vi tự động hóa chủ động tác động đến tài nguyên hệ thống của Zalo, rất dễ bị AI phát hiện và khóa tài khoản ngay lập tức.

| Hành vi cụ thể | Nguyên nhân rủi ro | Cơ chế kiểm soát bắt buộc |
| :--- | :--- | :--- |
| **Tự động kết bạn theo SĐT** | Gửi hàng loạt lời mời kết bạn tới tệp SĐT lạ ngoài danh bạ. | * Chế độ Personal: Mặc định tắt. Yêu cầu bật cờ `allowFriendAutomation=true` trong Cài đặt.<br>* Bắt buộc qua bước phê duyệt thủ công từng trường hợp (Human Approval Gate).<br>* Chế độ OA: Không hỗ trợ tính năng này. |
| **Tự động kết bạn từ thành viên nhóm** | Quét danh sách thành viên trong nhóm lạ và tự động gửi kết bạn hàng loạt. | * Bắt buộc bật cấu hình cho phép tự động hóa.<br>* Áp dụng thời gian chờ (cooldown) ngẫu nhiên từ 60-180 giây giữa mỗi lời mời kết bạn để giả lập hành vi người dùng thật. |
| **Tự động mời khách hàng vào nhóm** | Thêm hàng loạt người dùng lạ vào nhóm chat chung khi chưa được sự đồng ý. | * Giới hạn số lượng mời tối đa mỗi đợt.<br>* Bắt buộc có bằng chứng đồng ý của khách hàng (`consentStatus=true`). |
| **Tự động tạo nhóm hàng loạt** | Tạo liên tiếp nhiều nhóm chat trong thời gian ngắn để spam thông tin. | * Bắt buộc duyệt thủ công (Human Approval).<br>* Áp dụng cooldown tối thiểu 10 phút giữa các lần tạo nhóm. |
| **Proxy Rotation / Xoay tài khoản** | Tự động chuyển đổi địa chỉ IP/Proxy liên tục để tránh hệ thống quét. | * Mặc định tắt (`allowProxyUsage=false`). Việc đổi IP đột ngột và liên tục khiến Zalo đánh giá tài khoản có nguy cơ bị hack và tự động khóa bảo vệ phiên làm việc. |

### 🟠 Cấp độ: HIGH (Cao) — Yêu cầu điều kiện tương tác và Hạn ngạch

Các hành vi gửi tin nhắn outbound hàng loạt tới danh sách khách hàng.

| Hành vi cụ thể | Nguyên nhân rủi ro | Cơ chế kiểm soát bắt buộc |
| :--- | :--- | :--- |
| **Gửi tin nhắn hàng loạt theo SĐT lạ** | Gửi tin nhắn outbound tới khách hàng chưa kết bạn và chưa từng tương tác. | * Yêu cầu bắt buộc phải có bằng chứng đồng ý nhận tin (`requireConsentProof=true`).<br>* Nội dung tin nhắn phải được kiểm duyệt thủ công bởi operator. |
| **Gửi tin nhắn hàng loạt tới Follower OA** | Gửi tin nhắn truyền thông quảng cáo sai mục đích hoặc vượt quá hạn mức quy định của OA. | * Phân loại chính xác loại tin nhắn (Tin tương tác, Tin giao dịch, Tin truyền thông).<br>* Kiểm tra hạn ngạch gửi tin của OA trước khi thực thi nhằm tránh lãng phí chi phí và bị báo xấu. |
| **Chatbot Outbound chủ động** | Chatbot tự động gửi tin nhắn mở lời chào mừng hoặc quảng cáo ngoài khung giờ tương tác cho phép. | * Chỉ cho phép gửi tin nhắn chào mừng khi khách hàng chủ động quan tâm/inbound đầu tiên.<br>* Giới hạn tần suất trả lời tự động của bot. |
| **Sử dụng Spintax tránh né hệ thống** | Tự động xáo trộn từ ngữ (Ví dụ: `{Chào bạn│Hi anh/chị}`) để đánh lừa bộ lọc spam của Zalo. | * Mặc định tắt (`disableSpintax=true`). Khuyến khích doanh nghiệp tập trung tối ưu hóa chất lượng nội dung cá nhân hóa thay vì áp dụng các kỹ thuật lách bộ lọc kém bền vững. |

### 🟡 Cấp độ: MEDIUM (Trung Bình) — Cần giám sát và ghi log chi tiết

Hành vi gửi tin nhắn chăm sóc khách hàng định kỳ hoặc tương tác hỗ trợ.

| Hành vi cụ thể | Nguyên nhân rủi ro | Cơ chế kiểm soát bắt buộc |
| :--- | :--- | :--- |
| **Gửi tin nhắn theo Khung giờ đêm** | Gửi tin nhắn tự động chăm sóc khách hàng vào khung giờ ngủ nghỉ (Ví dụ: 22h đêm - 7h sáng). | * Hệ thống kích hoạt Khung giờ yên lặng (`quietHoursStart=21:00`, `quietHoursEnd=08:00`). Mọi tin nhắn tự động phát sinh trong khung giờ này sẽ được đưa vào hàng đợi (Queue) chờ xử lý vào sáng hôm sau. |
| **Import danh sách SĐT không rõ nguồn gốc** | Import số lượng lớn SĐT từ nguồn mua bán, chưa qua sàng lọc. | * Hệ thống yêu cầu khai báo rõ nguồn gốc dữ liệu (`source`), thời điểm đồng ý (`grantedAt`), và bằng chứng (`proofNote`) khi import khách hàng vào CRM. |
| **Vượt ngưỡng giới hạn ngày** | Gửi số lượng tin nhắn quá nhiều cho cùng một nhóm đối tượng khách hàng. | * Giới hạn trần gửi tin ngày (`dailySendLimit=100`) bảo vệ tài khoản.<br>* Áp dụng per-recipient cooldown 24 giờ (Không gửi tin tự động lần thứ 2 cho cùng 1 người trong vòng 24 giờ). |

### 🟢 Cấp độ: LOW (Thấp) — Luôn cho phép

Các hành vi thụ động hoặc có sự tương tác chủ động hai chiều từ khách hàng.

| Hành vi cụ thể | Lý do an toàn | Cơ chế kiểm soát áp dụng |
| :--- | :--- | :--- |
| **Live chat phản hồi tin nhắn đến** | Khách hàng chủ động gửi tin nhắn hỏi thông tin trước, operator phản hồi trực tiếp. | * Cho phép tương tác tự do.<br>* Ghi log nội dung hội thoại phục vụ đánh giá chất lượng chăm sóc khách hàng. |
| **Chatbot Inbound phản hồi theo kịch bản** | Khách hàng gõ từ khóa hỗ trợ, chatbot tự động phản hồi lại thông tin hữu ích ngay lập tức. | * Tự do hoạt động khi có sự tương tác inbound của người nhận trong vòng 72 giờ gần nhất. |
| **Giám sát sức khỏe kết nối Backend** | Chỉ truy vấn trạng thái kết nối của dịch vụ Zalo Bot. | * Cho phép chạy ngầm định kỳ 30 giây/lần. Trạng thái kết nối hiển thị rõ ràng trên dashboard. |

---

## 🛠️ 4. Quy Tắc Sản Phẩm Hệ Thống (CRM Rules)

Để xây dựng một giải pháp CRM bền vững, Alpha CRM áp dụng các quy tắc sản phẩm bất di bất dịch sau:

1.  **Mặc định an toàn (Secure by Default):** Khi khởi tạo, mọi cài đặt liên quan đến tự động hóa tài khoản cá nhân đều ở chế độ tắt. Doanh nghiệp phải chủ động đánh giá mức độ rủi ro và tự tay kích hoạt các tính năng này trong phần cài đặt quản trị.
2.  **Cơ chế dừng tự động khẩn cấp (Fail-Closed Stop Conditions):** 
    *   Hệ thống giám sát liên tục tỷ lệ gửi lỗi (Failure Rate) trên tổng số yêu cầu gửi tin của Backend. Nếu tỷ lệ lỗi vượt quá ngưỡng cho phép (Mặc định `10%` trong 50 tin nhắn gần nhất), hệ thống sẽ tự động tạm ngưng toàn bộ hàng đợi gửi tin và yêu cầu operator kiểm tra lại tình trạng tài khoản Zalo.
    *   Nếu phát hiện có tín hiệu báo xấu (Report Signal) từ phía khách hàng (Mặc định `>= 1` lần báo xấu gửi về từ webhook), hệ thống gửi tin tự động sẽ lập tức đóng băng để tránh rủi ro tài khoản bị Zalo quét khóa diện rộng.
3.  **Yêu cầu xác thực sự đồng ý (Consent-First):** Tin nhắn outbound gửi tới khách hàng lạ bắt buộc phải liên kết với một bản ghi Consent hợp lệ lưu trên cơ sở dữ liệu CRM. Các chiến dịch gửi hàng loạt không có consent proof sẽ bị bộ lọc của Flutter và Backend chặn ngay lập tức.
4.  **Bảo vệ thời gian thực:** Trạng thái kết nối và các chỉ số đo lường rủi ro của Zalo Bot được đồng bộ thời gian thực lên màn hình làm việc của Operator. Khi có sự cố kết nối hoặc tài khoản bị giới hạn tính năng, hệ thống sẽ đưa ra hướng dẫn xử lý trực quan thay vì báo lỗi hệ thống chung chung.

---

## ⚙️ 5. Cài Đặt Mặc Định An Toàn (Safe Defaults Configuration)

Dưới đây là các tham số mặc định an toàn được cấu hình cứng trong mã nguồn Flutter (`lib/mock/mock_accounts.dart`) và Backend (`src/config.ts`), đảm bảo hệ thống luôn vận hành trong vùng an toàn khi vừa cài đặt:

```typescript
// Các tham số cấu hình mặc định mức Backend (Node.js) & Flutter Client
const SAFE_DEFAULTS = {
  zaloChannelMode: 'personal_zca',             // Ưu tiên sử dụng kênh cá nhân thông qua zca-js
  allowPersonalAccountAutomation: true,        // Cho phép tự động hóa cơ bản đối với tài khoản cá nhân
  allowProxyUsage: false,                      // Cấm sử dụng xoay vòng IP/Proxy ngẫu nhiên
  allowFriendAutomation: false,                // Cấm tự động gửi lời mời kết bạn hàng loạt
  allowGroupAutomation: false,                 // Cấm tự động tham gia, tạo, mời vào nhóm chat
  requireConsentProof: true,                   // Bắt buộc kiểm tra bằng chứng đồng ý nhận tin
  requireRecentInteraction: false,             // Không bắt buộc tương tác gần đây đối với tài khoản cá nhân
  disableSpintax: true,                        // Chặn kỹ thuật trộn từ ngữ spintax né tránh bộ lọc
  requireHumanApproval: true,                  // Bắt buộc duyệt thủ công đối với các thao tác hàng loạt
  humanApprovalThreshold: 20,                  // Ngưỡng kích hoạt duyệt thủ công (Batch > 20 đối tượng)
  maxBatchSize: 20,                            // Giới hạn số lượng đối tượng tối đa trong một đợt gửi
  dailySendLimit: 100,                         // Giới hạn cứng số tin gửi đi tối đa của tài khoản/ngày
  perRecipientCooldownHours: 24,               // Khoảng cách an toàn tối thiểu giữa 2 tin nhắn gửi cùng khách hàng
  maxFailureRatePercent: 10,                   // Ngưỡng tỷ lệ lỗi kích hoạt dừng khẩn cấp (10%)
  stopOnReportCount: 1,                        // Ngưỡng số lần báo xấu kích hoạt khóa hệ thống (1 báo xấu)
  quietHoursStart: '21:00',                    // Bắt đầu khung giờ yên lặng (Không làm phiền khách hàng)
  quietHoursEnd: '08:00'                       // Kết thúc khung giờ yên lặng
};
```

---

## 🏗️ 6. Các Phân Lớp Thực Thi Chính Sách Trong Mã Nguồn

Để đảm bảo chính sách bảo mật hoạt động nhất quán, cấu trúc mã nguồn của Alpha CRM được phân tách rõ ràng thành các tầng kiểm soát:

```text
┌────────────────────────────────────────────────────────────────────────┐
│ 1. TẦNG CẢNH BÁO SỚM (Client UI)                                        │
│    - File: settings_screen.dart & zalo_compliance_help_panel.dart      │
│    - Nhiệm vụ: Hiển thị các thông số rủi ro, cảnh báo trực quan cho     │
│      operator bằng các thẻ chỉ báo màu sắc (Đỏ, Vàng, Xanh).            │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │  Chuyển giao đối tượng hành động
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ 2. TẦNG LỌC ĐIỀU KIỆN CLIENT (Client Compliance Guard)                  │
│    - File: zalo_compliance_guard.dart                                  │
│    - Nhiệm vụ: Đánh giá nhanh loại hành động (ZaloActionType) dựa trên  │
│      cấu hình bộ nhớ của Flutter để đưa ra quyết định cho phép gọi API │
│      hoặc chặn ngay lập tức kèm theo danh sách giải pháp gợi ý.         │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │  Yêu cầu được chấp thuận mức Client
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ 3. TẦNG THỰC THI CUỐI CÙNG (Backend Compliance Guard)                  │
│    - File: integration/zalo-bot-service/src/compliance.ts              │
│    - Nhiệm vụ: Tái đánh giá độc lập toàn bộ các tham số bằng dữ liệu    │
│      môi trường thực tế trên Server. Kiểm tra các chỉ số động như       │
│      Failure Rate, Report Count từ Webhook để đưa ra quyết định chặn.   │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │  Yêu cầu vượt qua bộ lọc Server
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ 4. TẦNG GIAO TIẾP VẬT LÝ (Channel Adapter)                              │
│    - File: integration/zalo-bot-service/src/channels/                  │
│    - Nhiệm vụ: Chuyển hóa yêu cầu thành cuộc gọi API thực tế tới Zalo   │
│      thông qua Adapter tương ứng (PersonalZca, OfficialOa).            │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 🎯 7. Tiêu Chí Nghiệm Thu Tính Năng Zalo Mới (Acceptance Criteria)

Trước khi bất kỳ phân hệ hay chức năng Zalo mới nào được đưa vào hoạt động trên môi trường sản xuất (Production), đội ngũ phát triển bắt buộc phải hoàn thành danh sách kiểm tra nghiệm thu dưới đây:

*   [ ] **Định tuyến Kênh rõ ràng:** Tính năng phải hỗ trợ đầy đủ 3 chế độ Adapter (Personal, OA, Mock).
*   [ ] **Tương thích Compliance Server:** Hành động mới phải được định nghĩa rõ ràng trong bộ lọc `src/compliance.ts` ở Backend với các quy tắc kiểm soát rủi ro tương ứng.
*   [ ] **Cơ chế Cảnh báo sớm trên Client:** Flutter Client phải bắt và hiển thị chính xác các quyết định từ `ZaloComplianceGuard`, đưa ra lý do và hành động khắc phục cụ thể cho operator khi bị chặn.
*   [ ] **Ràng buộc Consent:** Nếu hành động thuộc nhóm gửi tin Outbound hàng loạt, bắt buộc phải có mô hình xác thực Consent Proof và Opt-out của người nhận.
*   [ ] **Kiểm soát Khung giờ yên lặng:** Tính năng tự động hóa phải tuân thủ nghiêm ngặt Khung giờ yên lặng hoặc hỗ trợ cơ chế đưa tin nhắn vào hàng đợi thông minh.
*   [ ] **Duyệt thủ công cho Batch lớn:** Tích hợp thành công bước phê duyệt trung gian (Approval Gate) khi số lượng đối tượng vượt ngưỡng cấu hình.
*   [ ] **Ghi nhật ký Audit Log:** Mọi hành động gửi tin hoặc tương tác tự động đều phải ghi nhận log chi tiết tại backend (Ai thực hiện, Nội dung gì, Lý do được thông qua bộ lọc, Thời gian thực thi) phục vụ công tác thanh tra dòng dữ liệu khi có sự cố xảy ra.
