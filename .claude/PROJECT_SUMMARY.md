# Project Summary

**Last Updated:** 2026-06-06T20:47:12+07:00

**Session:** #80 - Hoàn tất toàn bộ Phase 1-4 của `ALPHA_CRM_REFACTOR_PLAN.md` và hợp nhất an toàn với pipeline Live Chat P0-P2 hiện có. Cloud áp dụng một PC Windows hoạt động cho mỗi subscription, hỗ trợ thay thế PC cũ bằng transaction/secret rotation, nhận diện `DEVICE_REVOKED`, và tách Mobile Remote khỏi trạng thái PC. Local Node chỉ khởi động runtime sau `/local/auth/sync`, phát revoke qua SSE, dừng campaign/sync/listener nhưng chỉ xóa hai file phiên CRM; batch history, self-echo reconciliation và local-first Live Chat được giữ nguyên. Flutter xử lý conflict bằng `AppDialog`, đồng bộ local session trước khi authenticated, tự quay về login khi revoke, giữ QR Remote và thêm Zalo onboarding. Xác minh trên working tree tích hợp: 43/43 Node tests, 79/79 Flutter tests, 16/16 cloud tests và Web build/Wasm dry run thành công; analyzer không có warning/error, còn 69 info lint nền.

**Session:** #79 - Hoàn tất triển khai toàn bộ P0-P2 từ `docs/specs/zalo-message-processing-gap-vs-deplao.md`. Backend Zalo Local Bridge có normalizer undo/delete/receipt/typing/reaction/group/friend/system, `clientMessageId` chống self-echo, schema receipt/reaction/draft/history/media/event log, batch lịch sử, worker tải media, SSE replay/filter, API mark-read/retry/reaction/typing/search/around/draft và outbound nâng cao. Flutter Live Chat chuyển sang SSE với polling dự phòng, optimistic send, hiển thị lỗi/gửi lại, receipt/reaction/typing, quote, draft, tìm kiếm, link và nhiều attachment; sqflite nâng lên schema v2. Xác minh: TypeScript build thành công, 31 Node tests và toàn bộ 72 Flutter tests đều vượt qua; `flutter analyze` không có lỗi biên dịch, còn 21 info lint nền của dự án.

**Session:** #78 - Đã nghiên cứu cách xử lý tin nhắn Zalo của Alpha CRM và đối chiếu với `D:\Dev\2.reference_pj\Zalo-ref\deplao-builder`. Thêm `docs/specs/zalo-message-processing-gap-vs-deplao.md` bằng tiếng Việt, phân loại rõ các phần đã có, mới có một phần và chưa có. Tài liệu xác nhận nền tảng local-first cho văn bản, tệp, lịch sử và thu hồi đã tồn tại; đồng thời ghi lại các phần còn thiếu về realtime, chuẩn hóa ID thu hồi, typing, receipt chi tiết, reaction, sự kiện nhóm/bạn bè, định dạng gửi nâng cao, đối soát self-echo, vòng đời media và trải nghiệm operator. Facebook được loại khỏi phạm vi nghiên cứu.

**Session:** #77 - Resolved dark mode and light mode theme rendering and transition issues in AOT/production environments. Changed `AppColors` properties to dynamic getters and removed the obsolete `ThemeColor` class. Fixed the light mode transition regression by hardcoding explicit light mode color constants inside `AppTheme.lightTheme` (decoupling it from dynamic `AppColors` getters) and synchronizing `AppColors.isDarkMode` early in the build phase of `main.dart`. Updated `app_sidebar.dart` to make inactive text/icon colors white-ish, active text colors pure white, and group/header labels highly legible in dark mode. Styled the `_ZaloPreview` widget dynamically in `bulk_messaging_screen.dart` with a dark viewport background, slate bubble background, and white text to ensure contrast in dark mode. Verified with 100% passing tests (68/68).

**Session:** #76 - Completed Phase 2 to 5 of the local-first Live Chat refactor. Implemented local better-sqlite3 DB in the Zalo bridge to store full messages and synced only metadata to the cloud. Split Flutter LiveChatRepository to conditionally route messages and attachments to the local bridge based on localFirstLiveChat, falling back to sqflite caching or cloud fallback. Added CachedNetworkImage for media previews, opportunistic TTL cache eviction, and "Bridge offline" UI banners in live_chat_screen.dart. Verified no old cloud messages are deleted and migration handles empty DBs gracefully. Updated pubspec.yaml, local_db.dart, and crm.js for full local-first capability. All tests passing.

**Session:** #75 - Resolved the dark mode text color and container background issues by fixing the `isDarkMode` detection logic inside the `MaterialApp` builder in `main.dart` to correctly query the active `themeMode` and platform brightness instead of relying on context-based `Theme.of(context)` (which is placed above the theme context). Implemented dynamic `ThemeColor` overrides for `AppColors` texts (`textPrimary`, `textSecondary`, `textMuted` and `iconMuted`), so all texts render in white in dark mode. Fixed compilation errors in `live_chat_cache.dart` (changed JS `.push` to Dart `.add`) and mock constructor errors in `live_chat_provider_test.dart`. Verified clean static analysis and 100% test pass on all 64 tests.

**Session:** #74 - Resolved the dark mode theme issue by implementing a dynamic `ThemeColor` subclass of `Color` that overrides the `value` getter based on runtime theme state, automatically updating backgrounds, surfaces, text, and borders without changing hardcoded references. Updated `main.dart` to toggle `AppColors.isDarkMode` inside the `MaterialApp` builder. Migrated the Zalo account configuration dialog in `settings_screen.dart` to the project's standard custom `AppDialog` widget with a custom subtitle, icon, and action buttons. Verified clean `flutter analyze` and 100% `flutter test` pass.

**Session:** #73 - Phase 1 of local-first Live Chat refactor: added `localFirstLiveChat` feature flag, `localBridgeBaseUrl`, and cache TTL settings to `SystemSettings` with full `toJson/fromJson/copyWith` support and safe defaults. Created `live_chat_contracts.dart` defining local bridge path builders, response helpers, and failure indicators. Added contract and `ChatMessage.fromJson` compatibility tests. No production behavior changed unless `LOCAL_FIRST_LIVE_CHAT=true`.

**Session:** #72 - Colorized the automation tab icons, template category/difficulty/channel chips, n8n cards, Facebook Page API cards, and added a premium gradient "PRO AUTOMATION" badge to the screen header. In addition, enhanced the sidebar navigation to support dynamic, route-specific active colors for icons and soft backgrounds, and color-coded dashboard Quick Actions and Quick Guide steps. Verified using `flutter analyze` and `flutter test` showing 100% success.

**Session:** #71 - Replaced the monolithic `SPEC.md` with a phase-based Local-First Live Chat refactor SPEC derived from `.claude/prompt.txt` and the requested SQLite/sqflite cache direction. Archived the previous SPEC under `.spec-archive/`. New phase files cover feature flags, local Zalo bridge SQLite/local APIs, cloud metadata-only compatibility, Flutter local-first repository with sqflite cache, and media/cache/migration verification.

**Session:** #70 - Organized and grouped all documentation files under `docs/` into 5 categorized subdirectories: `guides`, `compliance`, `specs`, `api-catalog`, and `releases`. Updated relative file links inside `claude.md`, `SPEC.md`, `integration/zalo-bot-service/README.md`, `zca-js-api-catalog.md`, `zalo-integration-installation-and-usage.md`, and `.claude/PROJECT_SUMMARY.md`.

**Session:** #69 - Stabilized Live Chat refresh behavior and Zalo account display naming. Live Chat now loads recent conversations/messages in smaller batches, preserves selected conversation messages during silent polling, filters failed outbound messages from the view, avoids duplicate conversation reload after send/attachment, supports load-older pagination, sanitizes rich JSON previews, reads backend `messageType`, and filters unmanaged group conversations client-side when managed group data is available. Added Settings appearance controls for light/dark/system theme mode and per-Zalo-account nicknames persisted in `zalo_settings.json`; `zaloIntegrationProvider` applies nicknames globally across tabs while retaining the original Zalo label for settings. Updated the local Zalo bridge to detect group events from root `ThreadType.Group`, support richer inbound message types, allow attachment-only sends, validate send payloads, and preserve ZCA error codes such as `114`. Verified with focused Live Chat tests, full `flutter test`, TypeScript build, and node bridge regression tests. `flutter analyze` still exits with existing info-level baseline lints only.

**Session:** #68 - Implemented Alpha CRM workflow automation integration. Added a Flutter `/workflows` workspace with a n8n-ready workflow template catalog, channel capability matrix, Riverpod provider, n8n settings form, and sidebar/topbar routing. Extended the local `zalo-bot-service` with n8n settings storage, masked API key responses, n8n Public API workflow creation, inbound Zalo event dispatch to n8n webhooks, proxy testing, and per-account `proxy-agent` enforcement for `zca-js` login sessions. Added official Facebook Page/Messenger cloud contract documentation and focused Flutter/Node regression tests.

**Session:** #67 - Refactored Zalo integration and Flutter Live Chat UI. Commented out the 'Tin mẫu nhanh' tab in `nav_item_models.dart`. Implemented a robust and crash-safe `_buildAvatar` helper in `live_chat_screen.dart` using `ClipOval` and `Image.network` with `errorBuilder` to render Zalo user and operator avatars safely, replacing all pre-existing `CircleAvatar` widgets. Fixed Zalo bot backend TypeScript compilation errors by adding `getUserInfo` and `getContext` declarations to `zca-js.d.ts` and optimizing `getOrFetchUserProfile` and `normalizeInboundMessage` to handle operator avatars and bypass caching. Verified compilation and 100% test pass.

**Session:** #66 - Added `docs/zca-js-api-catalog.md`, a categorized snapshot of the usable public `zca-js` API surface from the local reference repository `D:\Dev\2.reference_pj\Zalo-ref\zca-js`. The catalog covers the `Zalo` login facade, generated `API` facade, realtime listener methods/events, public type families, and Alpha CRM backend usage guidance with safeguards for high-risk personal-Zalo operations. Updated `claude.md` so future sessions know to consult this catalog before designing new personal-Zalo backend features.

**Session:** #65 - Fixed Zalo integration bugs and UI refinements. Threw error in `command-executor.ts` on `zalo.message.send` failure to correctly report delivery failure to the cloud. Implemented a 24-hour TTL `userProfileCache` in `personal-zca-channel.ts`, fetched missing profiles via `getUserInfo` to prevent Zalo rate limits, and fixed a TypeScript compilation mismatch with `getUserInfo` by casting to `any`. Corrected outbound conversation header handling in `crm.js` to prevent operator messages from overwriting customer profile details. In the Flutter Live Chat UI, removed tags/notes input fields from the conversation panel bottom, resolved the default avatar placeholder `/default` broken image load by falling back to letter initials, and fixed the hardcoded active account avatar indicator 'A' to dynamically display the first letter of the active account. Resolved a syntax error in the quick reply strip layout of `live_chat_screen.dart`. Verified backend compilation and 100% pass on all 25 widget and unit tests (`flutter test`).

**Session:** #64 - Ported ZaloCRM chat and contact capabilities to Alpha CRM Live Chat. Added new `contentType`, `isDeleted`, `zaloMsgId`, and `attachments` fields to `ChatMessage`. Extended `Conversation` model with `crmCustomer` data. Added detailed CRM contact details side panel on desktop and modal bottom sheet on mobile, allowing operators to create/update CRM customers directly from their Live Chat screen. Refactored message bubble rendering to support inline images with fullscreen previews, file/document attachments with sizes, reminder/calendar cards, indicators for voice/stickers/videos, and deleted messages. Added group chat tags, sender names in group threads, relative time formatting (e.g. 5 phút, Hôm qua), and a 12-second background auto-polling mechanism. Verified all changes via static analysis (`flutter analyze`) and unit tests (`flutter test`) - all passed.

**Session:** #63 - Reviewed the Builder implementation against `SPEC.md` and `BUILDER_LOG.md`. Added `REVIEW_LOG.md` and applied reviewer fixes: stopped `AppTopbar` from eagerly initializing dashboard/live-chat/task providers during ordinary shell render, changed subscription notifications to use known authenticated `crmAuthProvider` state, improved phone digit matching in global search, removed private dialog `key` lint warnings, added a topbar regression test for lazy provider behavior, and fixed the Dashboard async-context guard. Verified focused topbar/dashboard tests, full `flutter test`, and `dart format`; `flutter analyze` still exits with existing baseline info-level issues outside the reviewed topbar/dashboard fixes.

**Session:** #62 - Implemented Phase 2, 3, and 4 of SPEC.md. Added Customer Pipeline, Source Distribution, and Campaign Status sections to DashboardScreen. Converted AppTopbar to ConsumerStatefulWidget and implemented Global Search & Notification Bell popups with local Vietnamese-aware diacritic normalization and navigation. Created widget test coverage in `test/dashboard_screen_test.dart` and `test/app_topbar_test.dart`. Performed contract audit in lib and local Node.js backend for appointments, orders, reports, and team ACL. Confirmed all contracts are missing, created contract gap documentation at `docs/crm-domain-contract-gap.md`, and stopped Phase 4. All tests passed, and static analysis verified successfully.

**Session:** #59 - Fixed compliance error reporting for campaign execution. Modified backend `crm.js` agent command result route to set the campaign status to 'cancelled' (instead of 'completed') and mark all remaining queued execution logs as 'cancelled' with the corresponding error message when a command fails (e.g. blocked by compliance before sending). Fixed MongoDB Mixed field query matching issues in `crm.js` by querying `payload.campaignId` as both ObjectId and String formats. Exposed `translateToVietnamese` as a public static helper in `ZaloIntegrationApi`. Updated Flutter `BulkMessagingNotifier` progress status polling to parse the command status and errors, display compliance failure messages in the UI, and log them cleanly. Verified via static analysis.

**Session:** #57 - Refactored the Alpha CRM Flutter "Đăng ký & gói AI" screen with backend-aligned catalog data and real checkout flows. Added `subscription_catalog.dart` for the monthly plan (`crm_monthly`: 500,000 VND / 525 Credits / 1000 AI quota) and AI top-up packs (+200/+1000/+2000), plus tests for catalog parity, renewal detail calculation, and VietQR checkout parsing. Redesigned `subscription_screen.dart` into a dense operational dashboard with a monthly plan card, AI quota card, AI top-up cards, custom renewal confirmation dialog, payment-method dialog, and a real VietQR dialog using backend-returned `qrCodeUrl`, OCB `CASS55252503`, and exact `transferContent` instead of static placeholder bank instructions. Added desktop/mobile widget tests that caught and fixed the Flutter unbounded-height layout assertion (`parentDataDirty` follow-on) and mobile button overflow. `CrmAuthState` now tracks `creditBalance` and refreshes it from `/auth/me` so the renewal dialog can warn when Credits are insufficient.

**Session:** #56 - Refactored compliance warning UX across all high-risk screens. Redesigned the Zalo compliance warnings dialog (`_ComplianceWarningsDialog` in `compliance_warnings_popup.dart`) with premium styling, dynamic header gradients based on warning state (deep Amber for warning, Dark Slate for safe), and user-friendly Vietnamese text translating technical jargon like "Consent". Modified `bulk_messaging_screen.dart` to make the warning button always visible in the header and open the redesigned dialog on click, fixing the typo "danh bạ bè" to "danh bạ bạn bè". Integrated the same always-visible warning button UX into the headers of 6 other high-risk screens: Invite-to-Group, Join-Groups, Create-Groups, Scan-Members, Friend-by-Phone, and Friend-by-Group. Updated `.claude/CONVENTIONS.md` and `claude.md` to document the convention requiring developers to use the custom `showComplianceWarningsDialog` instead of Flutter's default dialogs for Zalo compliance and safety alerts. Verified with clean static analysis.

**Session:** #55 - Refactored Zalo compliance controls from blocking (Hard-block) to advisory warnings (Soft-warning) for marketing operations. Modified the client-side compliance guard `zalo_compliance_guard.dart` and backend bridge compliance rules `compliance.ts` to return `allowed: true` when consent proof is missing or when a chatbot reply lacks recent interaction. Updated `bulk_messaging_provider.dart` to check compliance reactively and store warnings. Refactored warning UX in `bulk_messaging_screen.dart` by removing the yellow alert banner from the screen body, adding an amber warning icon button to the Page Header next to the accounts dropdown, and showing a detailed guidelines dialog on click. Simplified warning messages in `zalo_compliance_guard.dart` to use plain Vietnamese without technical jargon like "consent proof". Cleaned up unused imports.

**Session:** #54 - Fixed Windows ZIP self-update behavior. The app no longer opens the downloaded Windows ZIP in Explorer and stops there; `AppUpdateService` now writes and launches a detached `apply_update.cmd` helper that waits for the app to exit, expands the ZIP with PowerShell, finds the extracted folder containing `alpha_crm.exe`, copies the bundle into the current app directory with `robocopy`, restarts `alpha_crm.exe`, and logs failures. Added a regression test for the generated updater script and switched update-service logging from `print` to `debugPrint`.

**Session:** #53 - Fixed PC-mobile device pairing state and QR flow. The cloud backend records paired mobile users in the active Windows `CrmDevice.pairedMobileUserIds` array rather than creating separate mobile device records, so the Flutter device provider now parses paired state from that field, accepts both 6-digit pairing codes and QR `qrToken` payloads, and polls the PC screen while waiting for confirmation. Replaced the previous mock QR scanner UX with real PC QR generation (`qr_flutter`) and mobile camera scanning (`mobile_scanner`), added Android camera permission, and added provider regression tests.

**Session:** #52 - Fixed Windows portable ZIP backend startup failure caused by `integration/zalo-bot-service/node_modules/zca-js` being a local junction to the reference repository. Reinstalled `zca-js@2.1.2` from the npm registry so `package-lock.json` resolves to the published tarball, restaged the Windows backend bundle with a real `zca-js` directory, rebuilt `build/alpha-crm-windows.zip`, and verified the packaged backend starts successfully with `/health` returning HTTP 200.

**Session:** #51 - Released CRM version 0.0.2 to Backblaze B2 and Web. Automatically bumped version in `pubspec.yaml` to `0.0.2+5`, built Android APK, Windows executable, local `zalo-bot-service` backend, packaged Windows release to ZIP (bundled with local backend), compiled Flutter Web with base href `/crm/` (copied to React public folder), uploaded packages to Backblaze B2, and updated metadata `version.json`. Refactored in-app updater to open Windows ZIP files in default explorer instead of trying to run them. Removed version suffix from Windows ZIP to keep folder name static after update. Configured release-to-b2.js script to optionally use Shorebird for APK builds if CLI is installed.

**Session:** #50 - Fixed Windows local Zalo integration loopback refusal by switching `localhost` to explicit IPv4 `127.0.0.1:8787`. Refactored device pairing screen to support up to 3 paired mobile devices simultaneously, displaying them in a list with individual revoke buttons on PC. Streamlined Settings screen on mobile clients by automatically hiding redundant PC-only settings (Zalo backend integration card, add accounts, delays, risk controls, and auto-approve).

**Session:** #49 - Fixed Live Chat inbound message normalization and avatar rendering: the local Zalo agent now extracts plain text from nested zca-js payload shapes while preserving rich preview JSON for link/file messages, normalizes protocol-relative avatar URLs, and the Flutter Live Chat model accepts text/message/avatar aliases with regression tests for normal text and avatar fallback.

**Session:** #48 - Researched the Deplao App reference and integrated suitable CRM features: quick reply shortcuts for Live Chat and quick templates, local app lock overlay with salted password hash, per-account local Zalo bot settings metadata for proxy/blockSeen/blockTyping, and a post-implementation spec for review/fix-bug follow-up. The Deplao Electron BrowserView shell and network interception model were intentionally not ported as-is.

**Session:** #47 - Researched the `zalo-bot-js` reference SDK and integrated the safe Official Bot/OA subset into the local Zalo bridge: added a small `zalo-bot-js`-style Official Bot API transport for text sends, normalized official webhook message payloads into the existing CRM inbound event pipeline, and documented `ZALO_BOT_TOKEN` official mode while keeping personal-only friend/group automation unsupported in official mode.

**Session:** #46 - Added `gemini-2.5-pro` as a 1-quota Auto Chatbot AI model, introduced reusable shared `AppDialog` / `AppDialogSection` widgets for polished project-wide dialog styling, and migrated the Chatbot create-rule, add-knowledge, keyword-help, and knowledge-help dialogs to the new pattern with clearer guidance that backend GCLI generates AI content while the local Zalo agent performs actual message/file/image sending.

**Session:** #45 - Updated the Auto Chatbot tab model selector to only allow `gemini-3-flash-preview` and `gemini-3.1-pro-preview`, sends the current model/prompt/temperature to the backend AI playground, added help dialogs for keyword scripts and knowledge documents, and guarded keyword rule creation against duplicate double-submit requests.

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
    security/                  Local app lock provider, overlay, and password hashing helpers
    workflows/                 n8n workflow template catalog, automation screen, channel capability matrix, and local backend API client
  mock/                       Mock domain models and sample/default data (includes ZaloChannelMode enum)
  shared/                     Reusable widgets and responsive utilities
test/                         Flutter widget tests
web/                          Flutter web manifest, icons, and index page
windows/                      Native Windows runner and CMake config
integration/
  zalo-bot-service/            Node.js/TypeScript backend bridge — personal-first via zca-js
    src/channels/              Channel adapter pattern (PersonalZca, OfficialOa, Mock)
    src/agent/                 Production outbound agent layer (runner, command executor, machine fingerprinting, cloud-api)
    src/integrations/           n8n settings/client/template builder, n8n event dispatcher, and proxy helper tests/utilities
    src/compliance.ts          Channel-aware backend compliance guard
    src/config.ts              Environment config with ZaloChannelMode and Agent configs
    src/server.ts              HTTP API server (hardened to bind to 127.0.0.1 and restrict CORS)
    src/personal-login.ts      CLI bootstrap for personal Zalo QR login
    src/zalo.ts                Channel selector/router
docs/
  guides/
    customer-installation-guide.md               Setup quick-start for customers
    production-crm-operator-guide.md             Daily handbook for operators
    zalo-integration-installation-and-usage.md   Detailed setup guide for Zalo integration backend
  compliance/
    zalo-integration-and-risk-controls.md        Comprehensive Vietnamese Zalo risk control strategy
    production-zalo-risk-controls.md             English Zalo risk controls summary checklist
  specs/
    reference-analysis.md                        Comparison of Alpha CRM vs Deplao and ZaloCRM
    implementation-plan.md                       Phased integration plan
    deplao-feature-integration-spec.md           Features integrated from Deplao
    crm-domain-contract-gap.md                   Gap analysis for future domain models
    zalo-message-processing-gap-vs-deplao.md     Zalo Live Chat handling parity audit against Deplao
    n8n-facebook-integration-contract.md         Meta Page and n8n webhook routing strategy
  api-catalog/
    zalo-reference-sources.md                    Local repo references (zca-js, zalo-bot-js, Deplao)
    zca-js-api-catalog.md                        API catalog for the zca-js library
    zca-js-unintegrated-apis.md                 List of remaining unintegrated zca-js APIs
  releases/
    production-release-checklist.md              Release checklists and verification steps
```

### Critical Files

| File | Purpose | Notes |
|------|---------|-------|
| `pubspec.yaml` | Flutter package metadata and dependencies | Uses Dart SDK `^3.10.7`; dependencies include GoRouter, Riverpod, fl_chart, data_table_2, google_fonts, intl, http, package_info_plus, path_provider, url_launcher, open_filex, mobile_scanner, qr_flutter. |
| `integration/zalo-bot-service/package.json` | Local backend package metadata | Uses `zca-js@^2.1.2` and `proxy-agent@^6.5.0` for per-account HTTP/HTTPS/SOCKS proxy enforcement. |
| `analysis_options.yaml` | Analyzer and lint configuration | Includes `package:flutter_lints/flutter.yaml`. |
| `lib/main.dart` | Entry point | Wraps `MyApp` in `ProviderScope`; uses `MaterialApp.router`. |
| `lib/shared/api/crm_cloud_api.dart` | Alpha Studio cloud API client | Uses `ALPHA_STUDIO_API_URL` with production fallback and Bearer JWT headers. |
| `lib/shared/auth/crm_auth_token_store.dart` | CRM JWT storage abstraction | Web uses localStorage; native Android/Windows currently use an app-support JSON file via `path_provider` (fallback, not secure storage). |
| `lib/shared/auth/web_auth_bridge.dart` | Flutter web iframe SSO bridge | Accepts Alpha Studio `{ type: 'AUTH_TOKEN', token }` postMessage and sends `AUTH_READY`. |
| `lib/features/auth/providers/crm_auth_provider.dart` | Alpha Studio auth state | Restores/login/logout JWT, fetches `/api/auth/me`, CRM subscription, and quota. |
| `lib/app/routing/app_routes.dart` | Route constants | Defines 17 CRM routes. |
| `lib/app/routing/app_router.dart` | GoRouter tree | Root redirects to `/dashboard`; `ShellRoute` wraps CRM screens. |
| `lib/features/customers/presentation/screens/customers_screen.dart` | Customers workspace | Shows customer stats, saved segments, status pipeline summary, responsive table, selected-contact actions, and a desktop/tablet detail panel. |
| `lib/app/shell/responsive_scaffold.dart` | Layout switching | Mobile drawer, tablet collapsed sidebar, desktop sidebar. Auto-checks for updates on startup (Windows/Android) and shows update dialog. |
| `lib/app/shell/app_sidebar.dart` | Main navigation | Uses grouped nav items, active state, collapsed mode. |
| `lib/features/security/` | Local app lock feature | Provides app-level lock overlay, local password hash persistence, and sidebar lock trigger. |
| `lib/features/workflows/` | Workflow automation feature | Provides `/workflows`, n8n settings UI, template catalog/filtering, channel capability matrix, and install calls to local backend. |
| `lib/features/messaging/live_chat/utils/quick_reply_shortcuts.dart` | Quick reply resolver | Resolves `/1`, `/2`, and named quick template shortcuts for Live Chat sends. |
| `lib/app/theme/app_colors.dart` | Color tokens | Implements design-system colors from `docs/01-design-system.md`. |
| `lib/app/theme/app_spacing.dart` | Spacing and radius tokens | 4/8/12/16/20/24/32/40/48 scale and radius tokens. |
| `lib/app/theme/app_text_styles.dart` | Typography tokens | Inter font via `google_fonts`. |
| `lib/shared/widgets/` | Shared UI primitives | Buttons, cards, inputs, tabs, alerts, badges, tables, logs, compliance warnings popup, update dialog. |
| `lib/shared/utils/zalo_backend_manager.dart` | Desktop local backend launcher | Windows production builds search beside `alpha_crm.exe` for `zalo-bot-service.cmd`/`.exe`/`.bat` and start the packaged local Zalo backend. |
| `lib/features/**/providers/` | Feature state | Riverpod `StateNotifier` classes for mock interactions. |
| `lib/features/subscription/models/subscription_catalog.dart` | CRM subscription catalog helper | Keeps Flutter plan/top-up prices aligned with backend catalog and parses VietQR checkout payloads. |
| `lib/mock/` | Mock data | Contacts, campaigns, messages, groups, accounts, system settings (with Zalo compliance fields). |
| `lib/shared/utils/zalo_compliance_guard.dart` | Shared compliance guard | Channel-mode-aware rule engine evaluating risk for all Zalo actions. |
| `lib/shared/utils/app_update_service.dart` | Auto-update service | Fetches GitHub Releases API, compares semver, downloads assets, installs updates (Windows .exe, Android .apk). |
| `lib/features/settings/providers/update_provider.dart` | Update state provider | Riverpod `StateNotifierProvider` managing check/download/install lifecycle for app updates. |
| `lib/features/zalo_integration/` | Zalo integration feature | API client, provider (with accountType, accountLabel, listenerRunning), and data models. |
| `integration/zalo-bot-service/` | Node.js backend | HTTP server with ZaloChannel adapter pattern: PersonalZca (zca-js), OfficialOa, Mock. The automated Windows release stages its compiled `dist/`, `node_modules`, `.env.example`, and bundled Node runtime into the ZIP while excluding `.env` and `.data` secrets. |
| `integration/zalo-bot-service/src/integrations/` | n8n/proxy helpers | Stores masked n8n settings, builds n8n workflow payloads, dispatches inbound events to n8n webhooks, and creates/test proxy agents. |
| `integration/zalo-bot-service/src/channels/official-bot-client.ts` | Official Bot API transport | Small `zalo-bot-js`-style native fetch transport used by `OfficialOaChannel` for compliant official text sends through `ZALO_BOT_TOKEN`. |
| `integration/zalo-bot-service/src/channels/official-oa-channel.ts` | Official Bot/OA channel adapter | Handles official status, text sends, and webhook inbound normalization into `ZaloInboundMessageEvent` for CRM live chat/chatbot ingestion. |
| `docs/specs/deplao-feature-integration-spec.md` | Deplao integration review spec | Records implemented features, review checklist, known limits, and verification commands. |
| `docs/specs/zalo-message-processing-gap-vs-deplao.md` | Phân tích phần xử lý tin nhắn Zalo còn thiếu | Đối chiếu Live Chat của Alpha CRM với pipeline Zalo của Deplao; ghi rõ các phần realtime, lưu trữ, gửi tin, media và UI còn thiếu hoặc mới triển khai một phần. Không bao gồm Facebook. |
| `docs/specs/reference-analysis.md` | Reference analysis | Compares current Alpha CRM against Deplao Builder and ZaloCRM and identifies reusable UX/domain patterns. |
| `docs/specs/implementation-plan.md` | Reference integration plan | Documents the phased implementation plan, impacted files, risks, and verification checklist. |
| `test/customers_screen_test.dart` | Customers screen regression test | Verifies the new pipeline summary and customer detail panel interaction. |
| `test/widget_test.dart` | Smoke test | Verifies app shell and initial dashboard route. |
| `SPEC.md` | Current integration specification | Defines personal-Zalo-first `zca-js` backend adapter plan, while keeping OA as optional secondary channel. |
| `lib/features/messaging/live_chat/data/live_chat_contracts.dart` | Local-first bridge contracts | Path builders, response helpers, and failure indicators for local bridge API. Behind `localFirstLiveChat` feature flag. |

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

