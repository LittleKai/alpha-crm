# 00 - Image Analysis

Nguồn ảnh: `img/`. Tất cả ảnh có kích thước `1920x1040`, desktop/web layout.

## Danh sách ảnh

| Ảnh | Màn hình tương ứng | Sidebar/menu | Độ phức tạp |
| --- | --- | --- | --- |
| `img/1.tong-quan.png` | Tổng quan chiến dịch | Tổng quan | Cao |
| `img/2.crm-khach-hang.png` | CRM Khách hàng | CRM Khách hàng | Trung bình |
| `img/3.quan-ly-noi-dung.png` | Tin mẫu nhanh | Quản lý nội dung | Thấp |
| `img/4-1.png` | Gửi tin nhắn hàng loạt | Chức năng nhắn tin / Gửi tin hàng loạt | Cao |
| `img/4-2.png` | Live Chat CRM Inbox | Chức năng nhắn tin / Nhắn tin Live Chat | Trung bình |
| `img/4-3.png` | Chatbot Tự Động | Chức năng nhắn tin / Chatbot tự động | Trung bình |
| `img/4-4.png` | Lịch sử gửi tin | Chức năng nhắn tin / Lịch sử gửi tin | Trung bình |
| `img/5-1.png` | Kết bạn theo SĐT | Chức năng kết bạn / Kết bạn theo SĐT | Cao |
| `img/5-2.png` | Kết bạn từ Nhóm Zalo | Chức năng kết bạn / Kết bạn từ Nhóm | Cao |
| `img/5-3.png` | Tự động Duyệt lời mời kết bạn | Chức năng kết bạn / Tự động Duyệt | Trung bình |
| `img/5-4.png` | Lịch sử chiến dịch kết bạn | Chức năng kết bạn / Lịch sử kết bạn | Thấp |
| `img/6-1.png` | Quét thành viên nhóm Zalo | Quản lý nhóm / Quét thành viên | Trung bình |
| `img/6-2.png` | Tham gia nhóm tự động | Quản lý nhóm / Tham gia nhóm | Cao |
| `img/6-3.png` | Mời bạn bè vào nhóm | Quản lý nhóm / Mời vào nhóm | Cao |
| `img/6-4.png` | Tạo nhóm tự động | Quản lý nhóm / Tạo nhóm | Cao |
| `img/6-5.png` | Rời nhóm hàng loạt | Quản lý nhóm / Rời nhóm | Cao |
| `img/7.cai-dat-he-thon.png` | Cài đặt hệ thống | Cài đặt hệ thống | Trung bình |

## Khung layout chung

- Thanh cửa sổ rất mỏng phía trên, nền trắng.
- Sidebar cố định bên trái rộng khoảng `250px`, nền trắng, border phải `#dbe3ef`.
- Branding trên sidebar gồm logo Zalo nhỏ, avatar vuông gradient xanh chữ `M`, tên `CRM ZALO`, subtitle `PHẦN MỀM MARKETING`.
- Nút thu gọn sidebar dạng vòng tròn nằm trên biên phải sidebar, ở gần y khoảng `64px`.
- Menu chia nhóm: mục cấp cao, tiêu đề nhóm uppercase màu xám xanh, menu con có icon line, label, active background xanh nhạt, thanh active màu xanh ở mép trái.
- Content nền `#f6f9fd`, top breadcrumb cao khoảng `64px`, border dưới.
- Header màn hình có icon xanh, tiêu đề `24-28px`, subtitle `14px`, khoảng cách dưới lớn.
- Card chính nền trắng, border xanh xám rất nhạt, radius khoảng `8px`, shadow nhẹ hoặc không shadow.

## Phân tích từng màn hình

### 1. Tổng quan chiến dịch - `1.tong-quan.png`

- UI chính: card báo cáo hiệu suất chiến dịch, chart đường trống với grid ngang, tab pill `Tin nhắn`, `Kết bạn`, `Phản hồi`, filter `7 ngày qua`, `30 ngày qua`, chỉ số thành công/thất bại.
- Bên dưới: card `Bắt đầu nhanh` có 3 quick actions dạng card ngang gradient rất nhẹ; card `Hướng dẫn & Mẹo sử dụng nhanh` có 3 item step.
- Component tái sử dụng: analytics card, segmented tabs, time-range button, line chart, quick action card, guide step card.
- Mock data: daily campaign metrics, success/failure counts, quick actions, guide tips.
- Trạng thái: default chart empty zero data như ảnh; loading skeleton chart; empty campaign metrics; error chart; active tab/date range.
- Chú ý: chart chiếm gần hết chiều rộng, legend nằm giữa dưới, card không quá nổi.

### 2. CRM Khách hàng - `2.crm-khach-hang.png`

- UI chính: header `CRM Khách Hàng`, 4 stat cards, search input, 3 dropdown filters, import/export buttons, primary `+ Thêm liên hệ`.
- Vùng nội dung hiện empty state ở giữa: icon người, text `Chưa có liên hệ nào`, 2 button `Import file`, `+ Thêm thủ công`.
- Component: stat card icon tròn màu pastel, search field, dropdown select, action button, empty state, table container cho trạng thái có dữ liệu.
- Mock data: contacts, tags/group, import source, message sent status.
- Trạng thái: default empty; loading table; data table; error; selected rows; disabled import/start when no data.
- Chú ý: toolbar cùng một hàng, stat cards chia 4 cột đều.

### 3. Tin mẫu nhanh - `3.quan-ly-noi-dung.png`

- UI chính: header `Tin mẫu nhanh`, search toàn chiều rộng, button `+ Thêm tin mẫu`, card empty lớn.
- Component: template search, template list/card/table, empty state, create button.
- Mock data: message templates with title, content, variables, created date.
- Trạng thái: empty; loading; list data; error; selected template.
- Chú ý: card empty cao khoảng `278px`, đặt sát toolbar.

### 4. Gửi tin nhắn hàng loạt - `4-1.png`

- UI chính: tab ngang 4 loại gửi: theo SĐT, vào nhóm Zalo, cho bạn bè Zalo, nhãn phân loại Zalo; bên phải `Quản lý chiến dịch (0)`.
- Layout 3 cột: trái danh sách target và import; giữa form cấu hình campaign; phải preview Zalo.
- Form có accordion `1. CẤU HÌNH CHUNG`, alert đỏ chưa có tài khoản, delay min/max, accordion `2. CẤU HÌNH NỘI DUNG`, editor toolbar, token chips, textarea, button chọn tin mẫu.
- Preview Zalo: header xanh, avatar `KH`, tên `Khách hàng Zalo`, vùng chat xám nhạt.
- Component: campaign tabs, target list panel, campaign config accordion, rich text toolbar, token chip, Zalo phone preview.
- Mock data: targets, campaigns, accounts, message body, variables, send status.
- Trạng thái: disabled start without account/target; empty target list; loading import; validation error; active tab; preview update.

### 5. Live Chat - `4-2.png`

- UI chính: header `Live Chat (CRM Inbox)`, account dropdown bên phải, refresh button; empty state `Không có tài khoản Zalo kết nối`.
- Component: account selector, refresh icon button, empty state. Khi có dữ liệu cần 3-pane inbox: conversation list, chat thread, customer info.
- Mock data: accounts, conversations, messages, unread counts.
- Trạng thái: disconnected empty trong ảnh; loading account; empty conversations; selected conversation; error.
- Chú ý: ảnh chỉ thể hiện trạng thái chưa kết nối, chưa có UI chat thật.

### 6. Chatbot tự động - `4-3.png`

- UI chính: tab ngang `Kịch bản từ khóa`, `Trí tuệ nhân tạo (AI)`, `Tài liệu kiến thức`, `Nhật ký phản hồi`; button `+ Tạo kịch bản mới`; empty state.
- Component: top tabs, chatbot script list, create button, empty state.
- Mock data: keyword rules, AI config, knowledge docs, response logs.
- Trạng thái: active tab; empty; loading; data list/table; disabled actions if no account; error.

### 7. Lịch sử gửi tin - `4-4.png`

- UI chính: 4 stat cards `Tổng gửi`, `Thành công`, `Thất bại`, `Đang chờ`; search; status dropdown; refresh, export, delete buttons; empty table card.
- Component: colored metric cards, filter toolbar, destructive button, history table, empty state.
- Mock data: send history rows with campaign, phone, content, status, timestamp.
- Trạng thái: empty; loading; data table; selected rows; error; delete confirmation modal.

### 8. Kết bạn theo SĐT - `5-1.png`

- UI chính: 2 cột lớn. Trái là target list/import panel; phải là cấu hình kết bạn tự động.
- Form giống gửi tin: account alert, delay min/max, content textarea, spintax chip, checkbox `Gửi inbox sau khi kết bạn`.
- Component: recipient import panel, auto-friend config card, text area, checkbox, alert.
- Mock data: phone list, groups, accounts, invite message, delay config.
- Trạng thái: empty target; disabled start; validation error; loading import; selected group.

### 9. Kết bạn từ Nhóm Zalo - `5-2.png`

- UI chính: 2 cột. Trái có search member, filter/start, tab segmented `Quét từ link nhóm` và `Chọn từ nhóm Zalo`, input link, button `Quét nhóm`, empty state thành viên nhóm. Phải là form cấu hình giống `5-1`.
- Component: group source tabs, group link input, scan button, member list, config card.
- Mock data: group links, scanned members, existing groups.
- Trạng thái: empty; scanning/loading; scan result; error invalid link; selected members.

### 10. Tự động Duyệt lời mời kết bạn - `5-3.png`

- UI chính: card trái lớn chứa mô tả, 2 setting rows với switch off, info alert xanh; card phải `Tài khoản đang chạy duyệt`.
- Component: setting row with switch, account running list, info alert.
- Mock data: connected accounts, auto approve enabled, welcome message enabled.
- Trạng thái: switches off/on; no connected account; running account list; disabled when account missing.

### 11. Lịch sử kết bạn - `5-4.png`

- UI chính: một card lớn `Lịch sử kết bạn`, empty state giữa.
- Component: history card/table, empty state.
- Mock data: friend campaign logs, statuses, timestamps.
- Trạng thái: empty; loading; data; error.

### 12. Quét thành viên nhóm - `6-1.png`

- UI chính: card form quét link nhóm với input dài, button `Quét thành viên`, dropdown nhóm đã lưu, empty instruction ở giữa.
- Component: scan form, saved group dropdown, scan result table, empty state.
- Mock data: group links, saved scanned groups, member list.
- Trạng thái: empty; scanning; data table; invalid link error.

### 13. Tham gia nhóm tự động - `6-2.png`

- UI chính: 2 cột, card trái cấu hình campaign, card phải nhật ký hoạt động. Card trái có account selector empty, multiline links, delay min/max, primary `Bắt đầu chạy`.
- Component: campaign config card, log panel, multiline input, delay fields.
- Mock data: accounts, group links, join logs.
- Trạng thái: empty account; loading; running; log data; error.

### 14. Mời bạn bè vào nhóm - `6-3.png`

- UI chính: 3 cột: cấu hình lời mời, list bạn bè, nhật ký tiến trình. Có checkbox `Chọn tất cả`, search bạn bè, empty list.
- Component: config form, friend selector panel, progress log panel.
- Mock data: source account, target groups, friends, invite logs.
- Trạng thái: empty friends; selected friends; disabled group select; running; error.

### 15. Tạo nhóm tự động - `6-4.png`

- UI chính: 3 cột giống `6-3`, nhưng form có textarea tên nhóm nhiều dòng, button `Tạo nhóm tự động`; panel giữa `Thêm bạn bè vào nhóm`.
- Component: group creation form, friend selector, progress log.
- Mock data: group names, friends, creation logs.
- Trạng thái: empty friends; selected all; validation for group names; running; error.

### 16. Rời nhóm hàng loạt - `6-5.png`

- UI chính: 3 cột: cấu hình rời nhóm, list nhóm, nhật ký. Có button tải lại, checkbox `Rời nhóm âm thầm`, button destructive đỏ nhạt.
- Component: leave group config, group list panel, progress log, destructive action button.
- Mock data: account groups, selected groups, leave logs.
- Trạng thái: empty groups; selected groups; loading reload; confirm modal; error.

### 17. Cài đặt hệ thống - `7.cai-dat-he-thon.png`

- UI chính: nhiều card dọc. Card tài khoản Zalo có proxy input, badge xanh `0 đang kết nối`, button `+ Thêm tài khoản Zalo`. Card cài đặt thời gian có inputs delay, alert hồng nhạt, button `Lưu cài đặt`. Card tính năng tự động nâng cao có checkbox và save.
- Component: settings section card, badge, proxy input, numeric input, info/warning alert, checkbox row.
- Mock data: accounts, proxy value, global delay settings, advanced toggles.
- Trạng thái: default; saving/loading; validation; account connected list; error.

## Component lặp lại

- App shell: sidebar, breadcrumb topbar, page header.
- Navigation group and nav item with active/hover/collapsed states.
- Primary, secondary, outline, destructive, icon buttons.
- Search input, select dropdown, numeric input, textarea, checkbox, switch.
- Card, metric/stat card, alert, badge, empty state.
- Tab bar, segmented control, accordion.
- Data table wrapper with loading/empty/error states.
- Campaign config panels for delay/account/message content.
- Progress/activity log panel.

## Điểm cần chú ý để giống ảnh

- Tông màu chủ đạo xanh `#2563eb`, nền app rất nhạt `#f6f9fd`, border `#dbe3ef`.
- Không dùng card bo quá tròn; radius khoảng `6-8px`.
- Font giống Inter/Roboto, weight tiêu đề `600-700`, body màu xám xanh.
- Mật độ desktop cao, nhiều khoảng trống nhưng không theo kiểu landing page.
- Active sidebar cần background `#eaf1ff`, text/icon xanh, vạch xanh trái.
- Form controls cao khoảng `38-40px`, button cao `38-40px`.

## Điểm chưa rõ cần xác nhận

- Không có ảnh mobile/tablet, cần xác nhận ưu tiên drawer hay bottom navigation cho mobile.
- Không có ảnh modal tạo/sửa liên hệ, thêm tin mẫu, chọn tin mẫu, xác nhận xóa.
- Không có ảnh trạng thái có dữ liệu thật cho table/list/chat.
- Không có ảnh sidebar collapsed.
- Không có ảnh popup thêm tài khoản Zalo/QR.
- Một số màn hình trong sidebar là trạng thái rỗng nên mock data chi tiết sẽ phải suy luận từ domain.

## Màn hình có thể làm song song

- Sau khi hoàn tất project setup, design system, shell và routing, các feature có thể làm song song theo thư mục riêng: dashboard, customers, content, messaging, friend automation, group management, settings.
- Các màn hình cùng nhóm nhưng dùng chung nhiều component form/campaign nên nên có shared widgets trước khi chia agent màn hình.
