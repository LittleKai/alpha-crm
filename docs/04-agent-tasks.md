# 04 - Agent Tasks

Quy tắc chung: mỗi agent chỉ sửa file trong phạm vi cho phép. Nếu cần thay đổi shared file ngoài scope, ghi note vào `docs/06-progress-tracker.md`.

## TASK ID: AGENT-00-ProjectSetup

### Vai trò agent
Project Setup Agent.

### Mục tiêu
Tạo Flutter project chạy được cho desktop/web/android và cấu trúc thư mục nền tảng.

### Input cần đọc
`docs/01-design-system.md`, `docs/02-architecture.md`.

### File được phép sửa
`pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `lib/app/**`, `lib/shared/**`, `lib/mock/**`, platform folders do Flutter tạo.

### File không được sửa
`lib/features/**` sau khi các feature agent bắt đầu; `docs/00-image-analysis.md`.

### Công việc chi tiết
- Tạo project Flutter nếu chưa có.
- Thêm dependencies nền tảng.
- Tạo thư mục theo architecture.
- Tạo app chạy với màn hình placeholder.

### Component cần tạo
`main.dart`, `App`, placeholder shell, basic route placeholder.

### Acceptance criteria
`flutter pub get`, `flutter analyze` chạy được; app mở được trên web/desktop/android.

### Cách test
Chạy `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run -d chrome`.

### Ghi chú tránh conflict
Không dựng UI feature thật.

## TASK ID: AGENT-01-DesignSystem

### Vai trò agent
Design System Agent.

### Mục tiêu
Triển khai theme/tokens giống ảnh.

### Input cần đọc
`docs/00-image-analysis.md`, `docs/01-design-system.md`, ảnh `img/*.png`.

### File được phép sửa
`lib/app/theme/**`, `lib/shared/widgets/app_button.dart`, `lib/shared/widgets/app_card.dart` nếu chưa có.

### File không được sửa
`lib/features/**`, `lib/app/routing/**`.

### Công việc chi tiết
- Tạo color, spacing, text style tokens.
- Tạo `ThemeData`.
- Tạo primitive button/card nếu cần cho style.

### Component cần tạo
`AppColors`, `AppSpacing`, `AppTextStyles`, `AppTheme`.

### Acceptance criteria
Theme dùng Inter, màu/border/radius theo docs, không hard-code theme trong feature.

### Cách test
Chạy `flutter analyze`; kiểm tra visual qua screen placeholder.

### Ghi chú tránh conflict
Không đổi public token name sau khi feature agents bắt đầu.

## TASK ID: AGENT-02-AppShell

### Vai trò agent
Layout Agent.

### Mục tiêu
Dựng app shell, sidebar, topbar/breadcrumb, responsive scaffold.

### Input cần đọc
`docs/00-image-analysis.md`, `docs/01-design-system.md`, `img/1.tong-quan.png`.

### File được phép sửa
`lib/app/shell/**`, `lib/shared/utils/responsive_breakpoints.dart`.

### File không được sửa
`lib/features/**`, `lib/app/routing/**` trừ placeholder integration đã thống nhất.

### Công việc chi tiết
- Sidebar fixed desktop, collapsed tablet, drawer/mobile.
- Menu groups đúng ảnh.
- Active nav state nhận từ router.
- Topbar breadcrumb.

### Component cần tạo
`AppShell`, `AppSidebar`, `AppTopbar`, `ResponsiveScaffold`, nav item models.

### Acceptance criteria
Sidebar giống ảnh desktop, không overflow mobile/tablet, active state rõ.

### Cách test
`flutter run -d chrome`; resize desktop/tablet/mobile.

### Ghi chú tránh conflict
Không tự thêm route feature chi tiết, chỉ nhận menu config.

## TASK ID: AGENT-03-Routing

### Vai trò agent
Routing Agent.

### Mục tiêu
Thiết lập route tree đầy đủ và placeholder screens.

### Input cần đọc
`docs/02-architecture.md`, `docs/04-agent-tasks.md`.

### File được phép sửa
`lib/app/routing/**`, placeholder screen files nếu nằm trong `lib/features/**/presentation/screens/*_placeholder.dart`.

### File không được sửa
Theme, shared widgets, implementation screens của feature agents.

### Công việc chi tiết
- Tạo route constants.
- Tạo GoRouter parent shell.
- Tạo route cho 17 màn hình.
- Breadcrumb metadata.

### Component cần tạo
`AppRouter`, `AppRoutes`, placeholder screens.

### Acceptance criteria
Tất cả menu đi được tới route tương ứng.

### Cách test
Chạy app, click toàn bộ sidebar; `flutter analyze`.

### Ghi chú tránh conflict
Feature agent thay placeholder bằng screen thật trong thư mục của mình nhưng không sửa route path.

## TASK ID: AGENT-04-SharedWidgets

### Vai trò agent
Shared Components Agent.

### Mục tiêu
Tạo widget tái sử dụng cho toàn app.

### Input cần đọc
`docs/00-image-analysis.md`, `docs/01-design-system.md`.

### File được phép sửa
`lib/shared/widgets/**`, `lib/shared/models/**`, `lib/shared/utils/**`.

### File không được sửa
`lib/features/**`, `lib/app/routing/**`.

### Công việc chi tiết
- Card, buttons, form fields, tabs, metric card, empty state, alert, badge.
- Table wrapper với loading/empty/error.
- Campaign config helpers, activity log panel, Zalo preview shell.

### Component cần tạo
`AppCard`, `AppButton`, `AppSearchField`, `AppSelectField`, `AppMetricCard`, `AppEmptyState`, `AppTable`, `AppTabs`, `AppAlert`, `AppBadge`, `CampaignConfigCard`, `ActivityLogPanel`.

### Acceptance criteria
Feature screens có thể dựng UI giống ảnh mà không copy style lặp lại.

### Cách test
Widget smoke tests nếu có; `flutter analyze`.

### Ghi chú tránh conflict
Không đưa business logic feature vào shared.

## TASK ID: AGENT-05-Dashboard

### Vai trò agent
Dashboard Agent.

### Mục tiêu
Dựng màn hình Tổng quan giống `1.tong-quan.png`.

### Input cần đọc
`docs/00-image-analysis.md`, `docs/01-design-system.md`, `img/1.tong-quan.png`.

### File được phép sửa
`lib/features/dashboard/**`, `lib/mock/mock_campaigns.dart`.

### File không được sửa
`lib/app/**`, `lib/shared/**`.

### Công việc chi tiết
- Page header, campaign performance card, chart, quick actions, guide cards.
- Mock data zero/default và sample.
- Loading/empty/error state cho chart/card.

### Component cần tạo
`DashboardScreen`, dashboard widgets, `CampaignMetric`.

### Acceptance criteria
Desktop layout giống ảnh; chart và cards responsive.

### Cách test
Navigate `/dashboard`; `flutter analyze`; kiểm tra resize.

### Ghi chú tránh conflict
Không sửa shared chart wrapper nếu thiếu, tạo widget nội bộ feature.

## TASK ID: AGENT-06-Customers

### Vai trò agent
Customer Agent.

### Mục tiêu
Dựng CRM Khách hàng giống `2.crm-khach-hang.png`.

### Input cần đọc
`docs/00-image-analysis.md`, `img/2.crm-khach-hang.png`.

### File được phép sửa
`lib/features/customers/**`, `lib/mock/mock_contacts.dart`.

### File không được sửa
`lib/app/**`, `lib/shared/**`.

### Công việc chi tiết
- Stat cards, filter toolbar, empty state, mock table data.
- Button import/export/add contact.
- States: empty, loading, data, error, selected rows.

### Component cần tạo
`CustomersScreen`, `Customer`, `CustomersRepository`, customer table widgets.

### Acceptance criteria
Empty state và toolbar giống ảnh, data mode không phá layout.

### Cách test
Navigate `/customers`; `flutter analyze`.

### Ghi chú tránh conflict
Không tự tạo modal thêm liên hệ nếu chưa có ảnh; dùng placeholder action.

## TASK ID: AGENT-07-Content

### Vai trò agent
Content Agent.

### Mục tiêu
Dựng Tin mẫu nhanh giống `3.quan-ly-noi-dung.png`.

### Input cần đọc
`docs/00-image-analysis.md`, `img/3.quan-ly-noi-dung.png`.

### File được phép sửa
`lib/features/content/**`, `lib/mock/mock_messages.dart`.

### File không được sửa
`lib/app/**`, `lib/shared/**`.

### Công việc chi tiết
- Search, add template, empty card.
- Mock template list/data state.
- Placeholder modal note nếu cần.

### Component cần tạo
`ContentTemplatesScreen`, `MessageTemplate`.

### Acceptance criteria
Empty state đúng ảnh và responsive.

### Cách test
Navigate `/content/templates`; `flutter analyze`.

### Ghi chú tránh conflict
Không sửa messaging feature dù cùng mock messages.

## TASK ID: AGENT-08-BulkMessaging

### Vai trò agent
Messaging Agent.

### Mục tiêu
Dựng Gửi tin nhắn hàng loạt giống `4-1.png`.

### Input cần đọc
`docs/00-image-analysis.md`, `img/4-1.png`.

### File được phép sửa
`lib/features/messaging/bulk/**`, `lib/mock/mock_campaigns.dart`, `lib/mock/mock_messages.dart`.

### File không được sửa
`lib/app/**`, `lib/shared/**`, các màn messaging khác ngoài `bulk`.

### Công việc chi tiết
- Campaign tabs, target/import panel, config form, Zalo preview.
- Disabled start khi thiếu account/target.
- Local state cho textarea/preview.

### Component cần tạo
`BulkMessagingScreen`, `BulkTargetPanel`, `MessageConfigPanel`, `ZaloPreviewPanel`.

### Acceptance criteria
3 cột desktop giống ảnh; mobile stack hợp lý.

### Cách test
Navigate `/messaging/bulk`; `flutter analyze`; resize.

### Ghi chú tránh conflict
Không đổi shared `CampaignConfigCard`.

## TASK ID: AGENT-09-LiveChat

### Vai trò agent
Live Chat Agent.

### Mục tiêu
Dựng trạng thái Live Chat giống `4-2.png`.

### Input cần đọc
`docs/00-image-analysis.md`, `img/4-2.png`.

### File được phép sửa
`lib/features/messaging/live_chat/**`, `lib/mock/mock_messages.dart`.

### File không được sửa
Các màn messaging khác, app shell.

### Công việc chi tiết
- Header, account selector, refresh button, disconnected empty state.
- Chuẩn bị mock conversation model cho data state.

### Component cần tạo
`LiveChatScreen`, `Conversation`, `ChatMessage`.

### Acceptance criteria
Disconnected state giống ảnh; data mode không cần hoàn chỉnh nếu chưa có ảnh.

### Cách test
Navigate `/messaging/live-chat`; `flutter analyze`.

### Ghi chú tránh conflict
Không suy đoán quá nhiều UI chat thật, ghi cần thêm ảnh.

## TASK ID: AGENT-10-Chatbot

### Vai trò agent
Chatbot Agent.

### Mục tiêu
Dựng Chatbot tự động giống `4-3.png`.

### Input cần đọc
`docs/00-image-analysis.md`, `img/4-3.png`.

### File được phép sửa
`lib/features/messaging/chatbot/**`, `lib/mock/mock_messages.dart`.

### File không được sửa
Các màn messaging khác.

### Công việc chi tiết
- Tabs, create button, empty state.
- Mock keyword rules, AI config, knowledge docs, logs.

### Component cần tạo
`ChatbotScreen`, `ChatbotRule`, `ChatbotTabBar`.

### Acceptance criteria
Tab active và empty state đúng ảnh.

### Cách test
Navigate `/messaging/chatbot`; `flutter analyze`.

### Ghi chú tránh conflict
Không tự tạo editor rule modal nếu thiếu ảnh.

## TASK ID: AGENT-11-SendHistory

### Vai trò agent
Send History Agent.

### Mục tiêu
Dựng Lịch sử gửi tin giống `4-4.png`.

### Input cần đọc
`docs/00-image-analysis.md`, `img/4-4.png`.

### File được phép sửa
`lib/features/messaging/history/**`, `lib/mock/mock_campaigns.dart`.

### File không được sửa
Các màn messaging khác.

### Công việc chi tiết
- Metric cards, filter toolbar, table/empty state.
- Mock send history rows.

### Component cần tạo
`SendHistoryScreen`, `SendHistoryRecord`.

### Acceptance criteria
Stats/filter/action bar và empty state giống ảnh.

### Cách test
Navigate `/messaging/history`; `flutter analyze`.

### Ghi chú tránh conflict
Delete action chỉ local/mock, không backend.

## TASK ID: AGENT-12-FriendByPhone

### Vai trò agent
Friend Campaign Agent.

### Mục tiêu
Dựng Kết bạn theo SĐT giống `5-1.png`.

### Input cần đọc
`docs/00-image-analysis.md`, `img/5-1.png`.

### File được phép sửa
`lib/features/friends/by_phone/**`, `lib/mock/mock_contacts.dart`, `lib/mock/mock_campaigns.dart`.

### File không được sửa
Các màn friends khác, shared.

### Công việc chi tiết
- Target panel, config panel, message textarea, checkbox, delay fields.
- Disabled/validation states.

### Component cần tạo
`FriendByPhoneScreen`, `FriendInviteConfig`.

### Acceptance criteria
2 cột desktop giống ảnh, stack mobile.

### Cách test
Navigate `/friends/by-phone`; `flutter analyze`.

### Ghi chú tránh conflict
Không sửa bulk messaging dù component tương tự.

## TASK ID: AGENT-13-FriendByGroup

### Vai trò agent
Group Friend Agent.

### Mục tiêu
Dựng Kết bạn từ Nhóm Zalo giống `5-2.png`.

### Input cần đọc
`docs/00-image-analysis.md`, `img/5-2.png`.

### File được phép sửa
`lib/features/friends/by_group/**`, `lib/mock/mock_groups.dart`, `lib/mock/mock_campaigns.dart`.

### File không được sửa
Các màn friends khác, shared.

### Công việc chi tiết
- Member search/filter, source tabs, link scan input, member empty/data state.
- Config panel giống ảnh.

### Component cần tạo
`FriendByGroupScreen`, `GroupMember`, `GroupScanSourceTabs`.

### Acceptance criteria
Left panel và config card đúng spacing/width.

### Cách test
Navigate `/friends/by-group`; `flutter analyze`.

### Ghi chú tránh conflict
Không thay model group chung nếu AGENT-16 đã tạo, dùng adapter nội bộ.

## TASK ID: AGENT-14-AutoApprove

### Vai trò agent
Auto Approval Agent.

### Mục tiêu
Dựng Tự động Duyệt lời mời kết bạn giống `5-3.png`.

### Input cần đọc
`docs/00-image-analysis.md`, `img/5-3.png`.

### File được phép sửa
`lib/features/friends/auto_approve/**`, `lib/mock/mock_accounts.dart`.

### File không được sửa
Các màn friends khác, settings.

### Công việc chi tiết
- Setting rows with switches, info alert, running account panel.
- Mock on/off state.

### Component cần tạo
`AutoApproveScreen`, `AutoApproveSettings`.

### Acceptance criteria
Switch off state và right panel đúng ảnh.

### Cách test
Navigate `/friends/auto-approve`; `flutter analyze`.

### Ghi chú tránh conflict
Không sửa settings advanced toggle, chỉ dùng mock riêng.

## TASK ID: AGENT-15-FriendHistory

### Vai trò agent
Friend History Agent.

### Mục tiêu
Dựng Lịch sử kết bạn giống `5-4.png`.

### Input cần đọc
`docs/00-image-analysis.md`, `img/5-4.png`.

### File được phép sửa
`lib/features/friends/history/**`, `lib/mock/mock_campaigns.dart`.

### File không được sửa
Các màn friends khác.

### Công việc chi tiết
- History card, empty state, optional table data state.

### Component cần tạo
`FriendHistoryScreen`, `FriendHistoryRecord`.

### Acceptance criteria
Card và empty state giống ảnh.

### Cách test
Navigate `/friends/history`; `flutter analyze`.

### Ghi chú tránh conflict
Không tự thêm filters nếu chưa có ảnh.

## TASK ID: AGENT-16-Groups

### Vai trò agent
Group Management Agent.

### Mục tiêu
Dựng các màn Quản lý nhóm từ `6-1.png` đến `6-5.png`.

### Input cần đọc
`docs/00-image-analysis.md`, `img/6-1.png`, `img/6-2.png`, `img/6-3.png`, `img/6-4.png`, `img/6-5.png`.

### File được phép sửa
`lib/features/groups/**`, `lib/mock/mock_groups.dart`.

### File không được sửa
`lib/features/friends/**`, `lib/app/**`, `lib/shared/**`.

### Công việc chi tiết
- Quét thành viên: form link, saved group dropdown, empty/result table.
- Tham gia nhóm: config card, log panel.
- Mời vào nhóm: config, friend list, progress log.
- Tạo nhóm: group names, friend list, progress log.
- Rời nhóm: account/group list, silent checkbox, destructive action, progress log.

### Component cần tạo
`ScanMembersScreen`, `JoinGroupsScreen`, `InviteToGroupScreen`, `CreateGroupsScreen`, `LeaveGroupsScreen`, group models/widgets.

### Acceptance criteria
5 màn đúng route, layout desktop giống ảnh, mobile stack.

### Cách test
Navigate toàn bộ `/groups/*`; `flutter analyze`.

### Ghi chú tránh conflict
Một agent phụ trách cả group feature để tránh sửa chung model/widget.

## TASK ID: AGENT-17-Settings

### Vai trò agent
Settings Agent.

### Mục tiêu
Dựng Cài đặt hệ thống giống `7.cai-dat-he-thon.png`.

### Input cần đọc
`docs/00-image-analysis.md`, `img/7.cai-dat-he-thon.png`.

### File được phép sửa
`lib/features/settings/**`, `lib/mock/mock_accounts.dart`.

### File không được sửa
`lib/features/friends/**`, app shell.

### Công việc chi tiết
- Account card, proxy input, add account button, connection badge.
- Time settings card, delay inputs, warning alert, save button.
- Advanced automation card with checkbox/save.

### Component cần tạo
`SettingsScreen`, `AccountSettings`, `DelaySettings`.

### Acceptance criteria
Cards, inputs, alert và scroll giống ảnh.

### Cách test
Navigate `/settings`; `flutter analyze`; kiểm tra vertical scroll.

### Ghi chú tránh conflict
Không implement QR login thật.

## TASK ID: AGENT-18-MobileResponsive

### Vai trò agent
Responsive Agent.

### Mục tiêu
Rà toàn bộ app trên tablet/mobile.

### Input cần đọc
`docs/01-design-system.md`, tất cả ảnh, code feature đã tạo.

### File được phép sửa
`lib/app/shell/**`, `lib/shared/widgets/**`, `lib/features/**/presentation/**` với thay đổi layout responsive nhỏ.

### File không được sửa
Business model/mock data trừ khi cần sửa lỗi compile.

### Công việc chi tiết
- Kiểm tra breakpoints.
- Stack panel 2-3 cột.
- Toolbar wrap.
- Table scroll/card row.
- Không để overflow text/button.

### Component cần tạo
Responsive helpers nếu thiếu.

### Acceptance criteria
Không overflow trên mobile; desktop không regress so với ảnh.

### Cách test
`flutter run -d chrome`, resize 390, 768, 1440 width; `flutter analyze`.

### Ghi chú tránh conflict
Chỉ sau khi feature agents hoàn tất.

## TASK ID: AGENT-19-PolishCleanup

### Vai trò agent
Polish Agent.

### Mục tiêu
Rà consistency UI, duplicate, naming, hard-code.

### Input cần đọc
`docs/00-image-analysis.md`, `docs/01-design-system.md`, toàn bộ code.

### File được phép sửa
Toàn bộ `lib/**` nhưng chỉ thay đổi polish/refactor nhỏ, cập nhật docs tracker.

### File không được sửa
Không đổi architecture/routing path nếu không có lỗi nghiêm trọng.

### Công việc chi tiết
- So sánh với ảnh.
- Chuẩn hóa spacing/màu.
- Xóa duplicate local widget nếu đã có shared.
- Format/analyze/test.

### Component cần tạo
Không bắt buộc.

### Acceptance criteria
UI nhất quán, analyzer sạch, không đổi phạm vi nghiệp vụ.

### Cách test
`flutter format .`, `flutter analyze`, `flutter test`.

### Ghi chú tránh conflict
Chạy sau các feature agent.

## TASK ID: AGENT-20-QAReview

### Vai trò agent
Review Agent.

### Mục tiêu
Review toàn bộ implementation theo docs và ảnh.

### Input cần đọc
`docs/00-image-analysis.md`, `docs/01-design-system.md`, `docs/02-architecture.md`, `docs/05-agent-review-prompts.md`, tất cả ảnh, code.

### File được phép sửa
Không sửa code trong lần review đầu. Chỉ ghi findings. Nếu được yêu cầu fix thì sửa theo scope được duyệt.

### File không được sửa
Toàn bộ code khi chưa có yêu cầu fix.

### Công việc chi tiết
- Review scope từng task.
- So visual với ảnh.
- Chạy analyze/test nếu có thể.
- Ghi PASS/NEEDS_CHANGES.

### Component cần tạo
Không.

### Acceptance criteria
Có report rõ lỗi nghiêm trọng, lỗi UI, lỗi kiến trúc, file cần sửa.

### Cách test
`flutter analyze`, `flutter test`, manual route sweep.

### Ghi chú tránh conflict
Review không tự ý refactor.
