# 03 - Implementation Plan

> Dừng ở tài liệu. Chỉ bắt đầu code khi người dùng xác nhận bằng câu: `Bắt đầu implementation`.

## Roadmap

### Phase 0: Project setup

- Tạo Flutter project stable cho desktop/web/android.
- Thêm dependencies: `go_router`, `flutter_riverpod`, `fl_chart`, `data_table_2`, `google_fonts`, `intl`, icon package.
- Tạo folder structure theo `docs/02-architecture.md`.
- Bật lint rules cơ bản, đảm bảo `flutter analyze` sạch.

### Phase 1: Design system + layout shell

- Tạo theme tokens: colors, text styles, spacing, radius, shadows.
- Tạo `AppShell`, `AppSidebar`, `AppTopbar`, responsive scaffold.
- Dựng sidebar desktop giống ảnh, bao gồm active state, group header, collapse button.
- Responsive: desktop fixed sidebar, tablet collapsed, mobile drawer/bottom navigation.

### Phase 2: Shared components

- Tạo card, buttons, inputs, select, tabs, empty state, metric card, alert, badge.
- Tạo table wrapper với loading/empty/error states.
- Tạo campaign config card, activity log panel, Zalo preview.
- Tạo mock state helpers.

### Phase 3: Các màn hình chính

- Dashboard/Tổng quan.
- CRM Khách hàng.
- Quản lý nội dung/Tin mẫu nhanh.
- Messaging: gửi hàng loạt, live chat, chatbot, lịch sử gửi tin.
- Friends: kết bạn theo SĐT, kết bạn từ nhóm, tự động duyệt, lịch sử.
- Groups: quét thành viên, tham gia nhóm, mời vào nhóm, tạo nhóm, rời nhóm.
- Settings.

### Phase 4: Mock interaction

- Search/filter client-side trên mock data.
- Toggle/switch/checkbox local state.
- Button loading giả lập ngắn.
- Empty/data/error demo states qua providers.
- Preview tin nhắn cập nhật theo textarea.

### Phase 5: Responsive/mobile

- Chuyển layout 2-3 cột thành stack.
- Toolbar wrap và table horizontal scroll/card rows.
- Drawer hoặc bottom navigation.
- Kiểm tra Android viewport phổ biến.

### Phase 6: Review, polish, cleanup

- So sánh từng màn hình với ảnh.
- Rà màu, spacing, typography, border radius.
- Chạy `flutter format`, `flutter analyze`, `flutter test`.
- Dọn mock data, duplicate widgets, hard-code layout.

## Thứ tự làm tối ưu

1. AGENT-00 setup.
2. AGENT-01 design system.
3. AGENT-02 shell/sidebar/topbar.
4. AGENT-03 routing.
5. AGENT-04 shared widgets.
6. Chạy song song các feature agents AGENT-05 đến AGENT-17.
7. AGENT-18 mobile responsive pass.
8. AGENT-19 polish.
9. AGENT-20 QA/review.

## Dependencies

| Task | Phụ thuộc |
| --- | --- |
| AGENT-00 | Không |
| AGENT-01 | AGENT-00 |
| AGENT-02 | AGENT-00, AGENT-01 |
| AGENT-03 | AGENT-00, AGENT-02 |
| AGENT-04 | AGENT-01 |
| AGENT-05..17 | AGENT-01, AGENT-02, AGENT-03, AGENT-04 |
| AGENT-18 | AGENT-05..17 |
| AGENT-19 | AGENT-18 |
| AGENT-20 | AGENT-19 |

## Task có thể chạy song song

- Sau AGENT-04: AGENT-05 Dashboard, AGENT-06 Customers, AGENT-07 Content, AGENT-08 Messaging bulk, AGENT-09 Live Chat, AGENT-10 Chatbot, AGENT-11 Send History, AGENT-12 Friends phone, AGENT-13 Friends group, AGENT-14 Auto Approve, AGENT-15 Friend History, AGENT-16 Group Management, AGENT-17 Settings.
- AGENT-08 và AGENT-12/13 dùng form campaign giống nhau, cần thống nhất shared component trước.
- AGENT-16 có nhiều màn hình nhóm, nên một agent phụ trách toàn bộ `lib/features/groups/**` để tránh conflict nội bộ.
