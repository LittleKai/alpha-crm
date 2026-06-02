# Project Summary

**Last Updated:** 2026-06-03 +07:00
**Session:** #44 - Fixed Live Chat account selector dropdown to list and update selections correctly by binding it directly to `zaloIntegrationProvider.accounts` instead of the empty-prone `/crm/groups/accounts` API. Standardized Vietnamese accents on the default 'Tất cả tài khoản' dropdown label and fixed multiple unaccented strings/error messages across Chatbot, Live Chat, Tasks, Groups, and Customers screens and providers.

**Session:** #43 - Updated the monthly CRM subscription price and credits references in `subscription_screen.dart` to 500,000 VND / 525 credits to align with the new billing plans.

**Session:** #42 - Added Zalo connected accounts dropdown to Chatbot and Send History screens headers to align all four messaging tabs. Translated all remaining unaccented Vietnamese labels in the Live Chat screen to accented Vietnamese. Implemented parsed JSON link/video rich card preview decoding and rendering with image, title, description, and launchable URLs inside Live Chat message bubbles.

**Session:** #41 - Updated and fully connected features across the messaging tabs: Bulk Messaging (Gửi tin hàng loạt), Live Chat (Nhắn tin live chat), Auto Chatbot (Chatbot tự động), and Sending History (Lịch sử gửi tin). Connected the active Zalo accounts list from `zaloIntegrationProvider` to the campaign configuration panel. Dynamicized the target panels for Groups, Friends, and Tags to select from actual `managedGroupsProvider` and `customersProvider` lists. Enhanced the Live Chat panel to display tag badges in the list and customer notes in a banner. Corrected chatbot log status diacritic matching and replaced the hardcoded knowledge upload action with a dynamic dialog input.

**Session:** #40 - Integrated detailed compliance and settings rejection logging from Zalo Bot Service. Refactored the `ZaloIntegrationApi` class client-side to intercept non-200 HTTP responses (like 403 Forbidden) and parse their JSON payloads to extract detailed reasons and risk levels (e.g. quiet hours, daily limits, disablement flags). Formatted these into the `'error'` string, allowing all execution log panels in all tabs (Friend by Phone, Friend by Group, Create Groups, Invite to Group, Join Groups, Settings) to automatically display detailed causes instead of generic `HTTP 403` status codes.

**Session:** #39 - Integrated intelligent device conflict and warning handling. When a subscription is renewed but is currently active on another device, the local Zalo bot captures the device registration rejection error and exposes it via its `/health` status endpoint. The Flutter app's `ZaloIntegrationNotifier` extracts this error dynamically and displays a premium Amber warning banner on the Dashboard. Bounded the warning with a destructive "Thoát ứng dụng" action (using safe desktop `exit(0)`) and a "Kiểm tra lại" trigger for immediate verification.

**Session:** #38 - Implemented full manual customer/contact addition modal dialog form to replace mock placeholder toasts, connecting it directly to cloud database APIs with proper validation and loading state representation. Fixed unaccented Vietnamese labels in the metrics panel on the Campaign Overview (Tổng quan chiến dịch) tab. Converted the "Hướng dẫn & Mẹo sử dụng nhanh" static guide boxes to interactive, premium clickable cards that navigate correctly to their corresponding settings, customers, and messaging screens.

**Session:** #36 - Fixed critical Flutter DropdownButton assertion crash in chatbot AI tab and RenderFlex bottom layout overflow (28px) in Quick Templates. Fully implemented Quick Templates ("Tin mẫu nhanh") CRUD dialog and delete functions, linking them directly to database APIs. Corrected Vietnamese diacritics, status labels, dialog inputs, and priority badges in follow-up tasks ("Công việc follow-up") and sidebar layout. Documented Zalo bot messaging tab inactivity due to missing local agent device registration (`device-secret.json`).

**Session:** #35 - Phase 8-10 CRM production operations completed. Live chat and chatbot screens now use backend conversations/messages/rules/logs. Added managed Zalo group management, AI summaries/insights, saved customer segments, follow-up tasks, dashboard analytics, import/export flows, and agent inbound message reporting with managed-group filtering.

**Session:** #34 - Windows production release packaging now includes the local Zalo backend bundle. The desktop backend manager searches beside the app executable for `zalo-bot-service.cmd`, `zalo-bot-service.exe`, or `zalo-bot-service.bat`; the automated release script stages compiled backend files, dependencies, bundled `node.exe`, `.env.example`, and the launcher beside `alpha_crm.exe`.

**Session:** #33 - Phase 7 CRM Bulk Messaging review fixes. Bulk campaign submission now creates a real backend template from the entered message before campaign creation, sends optional selected account/device metadata, and uses campaign name state instead of a generated-only name. Send history CSV export now copies generated CSV data to the clipboard with user feedback. Backend/agent fixes make manual recipients, group thread type, cancellation, status polling, and rate limits executable in production paths.

**Session:** #32 - Phase 7 CRM Bulk Messaging completed. Replaced mock bulk messaging simulation with backend-driven execution flow. Added `BulkCampaignRepository`, integrated with `BulkMessagingNotifier` to create campaigns, execute them via agent, and poll for status. Added CSV Export functionality to `SendHistoryScreen` and connected it to the actual execution logs.

**Session:** #31 - Fixed ZaloGroup compilation error in "Kết bạn từ nhóm" screen by importing mock_groups.dart, achieving 100% clean flutter analysis.

---

## 1. Project Overview

- **Type:** Cross-platform CRM UI application for web, Android, and Windows desktop.
- **Tech Stack:** Flutter, Dart SDK 3.10.7, Material 3, Riverpod, GoRouter.
- **Package Manager:** Flutter pub via `pubspec.yaml` and `pubspec.lock`.
- **i18n:** No formal localization solution. Vietnamese UI strings are currently inline; `intl` is used for formatting.
- **State Management:** `flutter_riverpod` with `StateNotifierProvider`, `StateProvider`, and local widget state.
- **Styling:** Central design tokens in `lib/app/theme/` plus reusable widgets in `lib/shared/widgets/`.
- **Deployment:** Automated release is handled by `alpha-studio-backend/scripts/release-to-b2.js` for Android APK, Windows ZIP, and Flutter Web under `/crm/`. The Windows ZIP includes the Flutter runner plus the local Zalo backend bundle required for production desktop use.
- **Knowledge Graph:** `.understand-anything/` is not present. Recommend running `/understand` before large impact analysis work.

---

## 2. File Structure

### Key Directories

```text
android/                     Native Android runner and Gradle config
docs/                        Design, architecture, agent task, and progress docs
img/                         Reference UI screenshots for the CRM app
lib/
  main.dart                   Flutter entry point
  app/                        App shell, routing, theme, responsive scaffold
  features/                   Feature-first CRM screens and providers
  mock/                       Mock domain models and sample/default data (includes ZaloChannelMode enum)
  shared/                     Reusable widgets and responsive utilities
test/                         Flutter widget tests
web/                          Flutter web manifest, icons, and index page
windows/                      Native Windows runner and CMake config
integration/
  zalo-bot-service/            Node.js/TypeScript backend bridge — personal-first via zca-js
    src/channels/              Channel adapter pattern (PersonalZca, OfficialOa, Mock)
    src/agent/                 Production outbound agent layer (runner, command executor, machine fingerprinting, cloud-api)
    src/compliance.ts          Channel-aware backend compliance guard
    src/config.ts              Environment config with ZaloChannelMode and Agent configs
    src/server.ts              HTTP API server (hardened to bind to 127.0.0.1 and restrict CORS)
    src/personal-login.ts      CLI bootstrap for personal Zalo QR login
    src/zalo.ts                Channel selector/router
docs/
  zalo-integration-and-risk-controls.md  Zalo compliance documentation (personal-first)
  zalo-integration-installation-and-usage.md  Setup and usage guide for Zalo integration
  zalo-reference-sources.md              List of 3 external reference projects and local paths
  zca-js-unintegrated-apis.md           Catalog of remaining unintegrated APIs from zca-js
  huong-dan-cai-dat-va-su-dung.md        Vietnamese installation and usage guide
```

### Critical Files

| File | Purpose | Notes |
|------|---------|-------|
| `pubspec.yaml` | Flutter package metadata and dependencies | Uses Dart SDK `^3.10.7`; dependencies include GoRouter, Riverpod, fl_chart, data_table_2, google_fonts, intl, http, package_info_plus, path_provider, url_launcher, open_filex. |
| `analysis_options.yaml` | Analyzer and lint configuration | Includes `package:flutter_lints/flutter.yaml`. |
| `lib/main.dart` | Entry point | Wraps `MyApp` in `ProviderScope`; uses `MaterialApp.router`. |
| `lib/shared/api/crm_cloud_api.dart` | Alpha Studio cloud API client | Uses `ALPHA_STUDIO_API_URL` with production fallback and Bearer JWT headers. |
| `lib/shared/auth/crm_auth_token_store.dart` | CRM JWT storage abstraction | Web uses localStorage; native Android/Windows currently use an app-support JSON file via `path_provider` (fallback, not secure storage). |
| `lib/shared/auth/web_auth_bridge.dart` | Flutter web iframe SSO bridge | Accepts Alpha Studio `{ type: 'AUTH_TOKEN', token }` postMessage and sends `AUTH_READY`. |
| `lib/features/auth/providers/crm_auth_provider.dart` | Alpha Studio auth state | Restores/login/logout JWT, fetches `/api/auth/me`, CRM subscription, and quota. |
| `lib/app/routing/app_routes.dart` | Route constants | Defines 17 CRM routes. |
| `lib/app/routing/app_router.dart` | GoRouter tree | Root redirects to `/dashboard`; `ShellRoute` wraps CRM screens. |
| `lib/app/shell/responsive_scaffold.dart` | Layout switching | Mobile drawer, tablet collapsed sidebar, desktop sidebar. Auto-checks for updates on startup (Windows/Android) and shows update dialog. |
| `lib/app/shell/app_sidebar.dart` | Main navigation | Uses grouped nav items, active state, collapsed mode. |
| `lib/app/theme/app_colors.dart` | Color tokens | Implements design-system colors from `docs/01-design-system.md`. |
| `lib/app/theme/app_spacing.dart` | Spacing and radius tokens | 4/8/12/16/20/24/32/40/48 scale and radius tokens. |
| `lib/app/theme/app_text_styles.dart` | Typography tokens | Inter font via `google_fonts`. |
| `lib/shared/widgets/` | Shared UI primitives | Buttons, cards, inputs, tabs, alerts, badges, tables, logs, compliance warnings popup, update dialog. |
| `lib/shared/utils/zalo_backend_manager.dart` | Desktop local backend launcher | Windows production builds search beside `alpha_crm.exe` for `zalo-bot-service.cmd`/`.exe`/`.bat` and start the packaged local Zalo backend. |
| `lib/features/**/providers/` | Feature state | Riverpod `StateNotifier` classes for mock interactions. |
| `lib/mock/` | Mock data | Contacts, campaigns, messages, groups, accounts, system settings (with Zalo compliance fields). |
| `lib/shared/utils/zalo_compliance_guard.dart` | Shared compliance guard | Channel-mode-aware rule engine evaluating risk for all Zalo actions. |
| `lib/shared/utils/app_update_service.dart` | Auto-update service | Fetches GitHub Releases API, compares semver, downloads assets, installs updates (Windows .exe, Android .apk). |
| `lib/features/settings/providers/update_provider.dart` | Update state provider | Riverpod `StateNotifierProvider` managing check/download/install lifecycle for app updates. |
| `lib/features/zalo_integration/` | Zalo integration feature | API client, provider (with accountType, accountLabel, listenerRunning), and data models. |
| `integration/zalo-bot-service/` | Node.js backend | HTTP server with ZaloChannel adapter pattern: PersonalZca (zca-js), OfficialOa, Mock. The automated Windows release stages its compiled `dist/`, `node_modules`, `.env.example`, and bundled Node runtime into the ZIP while excluding `.env` and `.data` secrets. |
| `test/widget_test.dart` | Smoke test | Verifies app shell and initial dashboard route. |
| `SPEC.md` | Current integration specification | Defines personal-Zalo-first `zca-js` backend adapter plan, while keeping OA as optional secondary channel. |

---

## 7. Important Notes for Claude

### When making changes to:

- **Routing:** Keep route constants in `AppRoutes` and update `app_router.dart` only when route behavior changes.
- **Theme:** Use existing `AppColors`, `AppSpacing`, and `AppTextStyles`. Avoid hard-coded theme values unless they are screen-specific and justified.
- **Shared widgets:** Preserve public constructor APIs unless all usage sites are updated and verified.
- **Feature screens:** Keep changes inside the relevant `lib/features/<feature>/` module unless the task explicitly authorizes shared/app-layer edits.
- **Mock data:** Put reusable sample/default data in `lib/mock/`; do not embed large lists directly inside `build`.
- **Responsive UI:** Preserve mobile stack, tablet collapsed sidebar, and desktop multi-column behavior.

### Testing checklist:

- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] For UI changes, inspect desktop, tablet, and mobile widths.
- [ ] For routing changes, navigate all affected sidebar routes.

### Don't forget to:

- Update this file's timestamp and session number.
- Follow `.claude/CONVENTIONS.md`.
- Keep documentation current-state only.
- Record only high-impact or likely-to-recur fixed bugs in `.claude/IMPORTANT_FIXED_BUGS.md`.

---

## 8. Quick Commands

```bash
# Development
flutter pub get
flutter run -d chrome
flutter run -d windows

# Analysis
flutter analyze

# Test
flutter test

# Build examples
flutter build web
flutter build apk
flutter build windows
```

---

**Critical:** Read this entire file before making any changes to the project.
