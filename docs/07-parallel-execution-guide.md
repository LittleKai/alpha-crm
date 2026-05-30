# 07 - Parallel Execution Guide

## Cách chạy nhiều agent/session song song

- Mỗi agent/session đọc `docs/00-image-analysis.md`, `docs/01-design-system.md`, `docs/02-architecture.md`, `docs/04-agent-tasks.md` trước khi làm.
- Chỉ giao một `AGENT-XX` cho mỗi session.
- Agent phải ghi rõ file đã sửa và cập nhật dòng của mình trong `docs/06-progress-tracker.md`.
- Không agent nào tự làm task khác khi chưa được yêu cầu.

## Agent nên chạy trước

1. AGENT-00 Project setup.
2. AGENT-01 Design system.
3. AGENT-02 App shell.
4. AGENT-03 Routing.
5. AGENT-04 Shared widgets.

Không nên chạy feature agents trước AGENT-04 vì sẽ tạo nhiều style/widget trùng lặp.

## Agent có thể chạy đồng thời

Sau AGENT-04, có thể chạy song song:

- AGENT-05 Dashboard.
- AGENT-06 Customers.
- AGENT-07 Content.
- AGENT-08 Bulk Messaging.
- AGENT-09 Live Chat.
- AGENT-10 Chatbot.
- AGENT-11 Send History.
- AGENT-12 Friend By Phone.
- AGENT-13 Friend By Group.
- AGENT-14 Auto Approve.
- AGENT-15 Friend History.
- AGENT-16 Groups.
- AGENT-17 Settings.

AGENT-18, AGENT-19, AGENT-20 chỉ chạy sau khi feature agents hoàn tất.

## Quy tắc tránh sửa chung file

- `pubspec.yaml`: AGENT-00 là chủ sở hữu. Agent khác chỉ request dependency qua progress tracker.
- `lib/app/theme/**`: AGENT-01 là chủ sở hữu.
- `lib/app/shell/**`: AGENT-02 là chủ sở hữu, AGENT-18 có thể sửa responsive sau.
- `lib/app/routing/**`: AGENT-03 là chủ sở hữu.
- `lib/shared/**`: AGENT-04 là chủ sở hữu, AGENT-18/19 có thể polish sau khi feature xong.
- `lib/features/<feature>/**`: chỉ agent feature tương ứng sửa.
- `lib/mock/*.dart`: agent dùng đúng mock file được cấp, tránh đổi schema chung khi không cần.

## Quy trình merge code

1. Agent hoàn tất task, chạy test/analyze theo task.
2. Agent cập nhật `docs/06-progress-tracker.md`: status `NEEDS_REVIEW`, files touched, notes.
3. Reviewer chạy prompt trong `docs/05-agent-review-prompts.md`.
4. Nếu PASS, review status `APPROVED`.
5. Nếu NEEDS_CHANGES, agent chỉ sửa các file trong scope và cập nhật lại tracker.

## Quy trình review sau mỗi task

- Đọc task gốc trong `docs/04-agent-tasks.md`.
- Đọc ảnh liên quan trong `docs/00-image-analysis.md`.
- Kiểm tra `git diff` hoặc file touched.
- Kiểm tra compile/lint nếu môi trường cho phép.
- So sánh visual với ảnh desktop.
- Kiểm tra responsive tối thiểu bằng resize web.

## Cách xử lý conflict

- Conflict ở shared/theme/router: dừng, giao cho agent chủ sở hữu file quyết định.
- Conflict trong feature riêng: agent feature tự resolve.
- Conflict mock data: ưu tiên giữ schema backward compatible; nếu cần đổi schema, ghi note và review lại feature phụ thuộc.
- Không xóa code của agent khác nếu chưa hiểu thay đổi.

## Cách cập nhật progress tracker

- Khi bắt đầu: `Status = IN_PROGRESS`.
- Khi code xong, chờ review: `Status = NEEDS_REVIEW`.
- Nếu reviewer yêu cầu sửa: `Status = NEEDS_CHANGES`.
- Sau khi sửa xong: `Status = NEEDS_REVIEW`.
- Khi approved: `Status = APPROVED`.
- `Files touched` phải liệt kê thư mục/file chính xác.
- `Notes` ghi thiếu ảnh, thiếu thông tin, hoặc request shared component nếu có.

## Điểm cần xác nhận trước implementation

- Mobile dùng drawer hay bottom navigation.
- Có cần dựng trạng thái data thật cho tất cả table/list trong phase đầu hay chỉ empty/default như ảnh.
- Có cần modal thêm/sửa/xóa ngay không khi chưa có ảnh.
- Icon package ưu tiên nếu Material Icons không đủ giống.
- Có cần logo Zalo/asset thật hay dùng placeholder text/icon.
