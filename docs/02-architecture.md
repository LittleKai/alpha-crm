# 02 - Architecture

## Kiến trúc đề xuất

Flutter app theo feature-first architecture. Shared layer giữ design system, app shell, reusable widgets, routing và mock infrastructure. Mỗi màn hình nghiệp vụ nằm trong `lib/features/<feature>/` để nhiều agent có thể làm song song mà ít conflict.

## Package cần dùng

- `go_router`: routing, deep link, route state.
- `flutter_riverpod`: dependency injection, view state, mock repository providers.
- `fl_chart`: line chart ở Tổng quan.
- `data_table_2`: table desktop có scroll tốt.
- `flutter_svg`: nếu cần dùng asset SVG icon/logo sau này.
- `google_fonts`: font Inter.
- `intl`: định dạng ngày giờ, số lượng, phần trăm.
- `lucide_icons` hoặc `iconsax_flutter`: icon line gần ảnh. Nếu không dùng package icon riêng thì dùng Material Icons trước.

## Cấu trúc thư mục

```text
lib/
  main.dart
  app/
    app.dart
    routing/
      app_router.dart
      app_routes.dart
    theme/
      app_colors.dart
      app_spacing.dart
      app_text_styles.dart
      app_theme.dart
    shell/
      app_shell.dart
      app_sidebar.dart
      app_topbar.dart
      responsive_scaffold.dart
  shared/
    widgets/
      app_button.dart
      app_card.dart
      app_empty_state.dart
      app_metric_card.dart
      app_search_field.dart
      app_select_field.dart
      app_table.dart
      app_tabs.dart
      app_alert.dart
      app_badge.dart
      app_section_header.dart
      campaign_config_card.dart
      activity_log_panel.dart
    models/
      ui_state.dart
    utils/
      responsive_breakpoints.dart
      formatters.dart
  mock/
    mock_accounts.dart
    mock_campaigns.dart
    mock_contacts.dart
    mock_groups.dart
    mock_messages.dart
  features/
    dashboard/
    customers/
    content/
    messaging/
    friends/
    groups/
    settings/
```

## Routing

- Centralize trong `lib/app/routing/app_router.dart`.
- Dùng route names từ `app_routes.dart`.
- App shell là parent route cho toàn bộ trang CRM.
- Mỗi feature expose một `Widget` màn hình, không tự sửa router sau khi AGENT-03 hoàn tất.
- Đường dẫn đề xuất:
  - `/dashboard`
  - `/customers`
  - `/content/templates`
  - `/messaging/bulk`
  - `/messaging/live-chat`
  - `/messaging/chatbot`
  - `/messaging/history`
  - `/friends/by-phone`
  - `/friends/by-group`
  - `/friends/auto-approve`
  - `/friends/history`
  - `/groups/scan-members`
  - `/groups/join`
  - `/groups/invite`
  - `/groups/create`
  - `/groups/leave`
  - `/settings`

## State management

- Riverpod là mặc định.
- Mỗi feature có `providers/` riêng nếu cần state.
- Shared app state: selected route, sidebar collapsed, connected account list.
- View state dùng sealed-like model đơn giản: loading, data, empty, error.
- Không gọi backend thật trong phase đầu, provider trả mock repository.

## Mock data

- Mock data để trong `lib/mock/`.
- Mỗi feature đọc mock qua repository/provider riêng, ví dụ `customersRepositoryProvider`.
- Dữ liệu cần có cả empty và sample data để agent có thể dựng default/loading/empty/error/data.
- Không hard-code list lớn trực tiếp trong widget build.

## Shared widgets

- Shared widgets nằm trong `lib/shared/widgets/`.
- Chỉ AGENT-04 hoặc agent nền tảng được sửa shared widgets.
- Feature agent dùng shared widgets qua API có sẵn. Nếu thiếu API, ghi yêu cầu vào `docs/06-progress-tracker.md` thay vì tự sửa shared.

## Feature modules

Mỗi feature có cấu trúc:

```text
lib/features/<feature>/
  presentation/
    screens/
    widgets/
  data/
    models/
    repositories/
  providers/
```

Với feature nhỏ có thể bỏ `data/` nếu dùng trực tiếp mock provider, nhưng vẫn giữ `presentation/screens`.

## Quy tắc đặt tên

- File Dart: `snake_case.dart`.
- Class/widget: `PascalCase`.
- Provider: `<name>Provider`.
- Model immutable: `PascalCase`, fields `camelCase`.
- Screen widget: `<Feature><Screen>Screen`, ví dụ `BulkMessagingScreen`.
- Widget nội bộ feature: prefix theo feature nếu có thể conflict.

## Quy tắc tránh conflict nhiều agent

- `pubspec.yaml`, router, theme, shell chỉ do AGENT-00 đến AGENT-03 sửa.
- Shared widgets chỉ do AGENT-04 sửa sau khi tạo API ban đầu.
- Feature agents chỉ sửa trong thư mục feature được giao và mock file được giao.
- Không đổi tên route, theme token hoặc shared widget public API khi chưa có review.
- Mỗi agent cập nhật `docs/06-progress-tracker.md` ở dòng task của mình.
- Nếu cần thay đổi ngoài scope, agent ghi note và dừng phần đó, không tự sửa.
