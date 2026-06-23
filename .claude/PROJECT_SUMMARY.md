# Project Summary

## 1. Project Overview

- **Type:** Cross-platform CRM UI application for web, Android, and Windows desktop.
- **Tech Stack:** Flutter, Dart SDK 3.10.7, Material 3, Riverpod, GoRouter.
- **Package Manager:** Flutter pub via `pubspec.yaml` and `pubspec.lock`.
- **i18n:** No formal app-string localization solution; Vietnamese UI strings are inline. `intl` is used for formatting. `flutter_localizations` is wired into `MaterialApp.router` with `locale: Locale('vi')` so built-in Material widgets (date/time pickers, default tooltips) render in Vietnamese with 24h time.
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
    src/risk-control-store.ts  Persists client risk-control settings (dataRoot/integrations/risk-control.json) and overlays them onto live config (quiet hours, limits, automation gates)
    src/recent-friend-approvals.ts  TTL tracker of just auto-approved friends; lets chatbot suppress auto-reply when autoReplyNewFriend=false
    src/config.ts              Environment config with ZaloChannelMode and Agent configs (compliance defaults overridable at runtime via risk-control-store)
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
    sqlite-encryption-at-rest-proposal.md        Proposal for encrypting the message SQLite DBs (SQLCipher vs field-level)
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
| `pubspec.yaml` | Flutter package metadata and dependencies | Uses Dart SDK `^3.10.7`; dependencies include GoRouter, Riverpod, fl_chart, data_table_2, google_fonts, intl (`^0.20.2`), flutter_localizations (SDK, for Vietnamese Material pickers), http, package_info_plus, path_provider, url_launcher, open_filex, mobile_scanner, qr_flutter, flutter_secure_storage (native CRM token storage), ffi + win32 (Windows Job Object), window_manager + tray_manager (Windows maximize/tray). Declares `assets/app_icon.ico` (tray icon). |
| `integration/zalo-bot-service/package.json` | Local backend package metadata | Uses `zca-js@^2.1.2` and `proxy-agent@^6.5.0` for per-account HTTP/HTTPS/SOCKS proxy enforcement. |
| `integration/zalo-bot-service/src/secure-store.ts` | Encryption-at-rest helper | `readSecure`/`writeSecure` wrap sensitive local files (Zalo `credentials_*.json`, `account-settings.json`) with AES-256-GCM. Key is a random 32-byte key sealed by Windows DPAPI (CurrentUser, one-shot PowerShell) in `dataRoot/.secure-key`; raw 0600 key file on non-Windows (dev). Magic-header detection gives transparent plaintext fallback (no forced re-login) and best-effort degradation to plaintext if the key is unavailable. Does NOT re-serialize the cookie jar — decrypted bytes are identical, preserving `zpw_sek` immutability. |
| `analysis_options.yaml` | Analyzer and lint configuration | Includes `package:flutter_lints/flutter.yaml`. |
| `lib/main.dart` | Entry point | Wraps `MyApp` in `ProviderScope`; uses `MaterialApp.router`. Boot is non-blocking: fires `ZaloBackendManager.startSupervised()` (fire-and-forget) and mounts `BackendStatusBanner` above the router child. |
| `lib/shared/api/crm_cloud_api.dart` | Alpha Studio cloud API client | Uses `ALPHA_STUDIO_API_URL` with production fallback and Bearer JWT headers. |
| `lib/shared/auth/crm_auth_token_store.dart` | CRM JWT storage abstraction | Conditional import: web → localStorage; native Android/Windows → `token_store_native.dart`. |
| `lib/shared/auth/token_store_native.dart` | Native CRM token store | Stores the JWT in the OS keystore via `flutter_secure_storage` (Windows DPAPI / Android Keystore). One-time migration imports any legacy plaintext `crm_token.json` then deletes it. All ops are best-effort (swallow errors → null). |
| `lib/shared/auth/web_auth_bridge.dart` | Flutter web iframe SSO bridge | Accepts Alpha Studio `{ type: 'AUTH_TOKEN', token }` postMessage and sends `AUTH_READY`. |
| `lib/features/auth/providers/crm_auth_provider.dart` | Alpha Studio auth state | Restores/login/logout JWT, fetches `/api/auth/me`, CRM subscription, and quota. |
| `lib/app/routing/app_routes.dart` | Route constants | Defines 17 CRM routes. |
| `lib/app/routing/app_router.dart` | GoRouter tree | Root redirects to `/dashboard`; `ShellRoute` wraps CRM screens. |
| `lib/features/customers/presentation/screens/customers_screen.dart` | Customers workspace | Shows customer stats, saved segments, status pipeline summary, responsive table, selected-contact actions, and a desktop/tablet detail panel. |
| `lib/features/customers/providers/customers_provider.dart` | Customers state + offline cache | `loadContacts()` caches each successful cloud load into the `cache_entries` table (keyed by user id, 30-day TTL) via `LocalDb.putCache`; when the cloud call fails it falls back to the cached snapshot and surfaces an offline notice instead of an empty list. Caching is best-effort. |
| `lib/shared/local_db/local_db.dart` | Local SQLite (sqflite/ffi) | Adds generic `putCache(key,value,{ttl})` / `getCache(key)` over the `cache_entries` table (expired rows purged on read) used by the Customers offline cache. |
| `lib/features/dashboard/utils/dashboard_chart_data.dart` | Dashboard chart data helpers | Normalizes daily dashboard chart metrics, merges local chatbot daily stats into campaign performance data, and protects cumulative message series from rendering as per-day values. |
| `lib/app/shell/responsive_scaffold.dart` | Layout switching | Mobile drawer, tablet collapsed sidebar, desktop sidebar. Auto-checks for updates on startup (Windows/Android) and shows update dialog. |
| `lib/app/shell/app_sidebar.dart` | Main navigation | Uses grouped nav items, active state, collapsed mode. |
| `lib/features/security/` | Local app lock feature | Provides app-level lock overlay, local password hash persistence, and sidebar lock trigger. |
| `lib/features/workflows/` | Workflow automation feature | Provides `/workflows`, n8n settings UI, template catalog/filtering, channel capability matrix, and install calls to local backend. |
| `lib/features/messaging/live_chat/utils/quick_reply_shortcuts.dart` | Quick reply resolver | Resolves `/1`, `/2`, and named quick template shortcuts for Live Chat sends. |
| `lib/features/messaging/bulk/` | Bulk messaging + scheduled campaigns | Compose/send bulk campaigns (phone/group/friends/tags). Shared `launchCampaign()` in `providers/bulk_messaging_provider.dart` (template→campaign→start) used by both immediate send and scheduling. Client-side scheduling (Path B): `providers/scheduled_campaigns_provider.dart` holds a queue of `data/scheduled_campaign.dart` snapshots, each with its own Timer; persisted via `data/scheduled_campaigns_dao.dart` to the `scheduled_campaigns` SQLite table (re-armed at app launch in `main.dart`; past-due → `missed`). Managed via the "Quản lý chiến dịch (n)" button + dialog; a red (n) badge also shows on the sidebar "Gửi tin nhắn hàng loạt" item (`/messaging/bulk`) via `_NavCountBadge`. Requires app open at fire time (same limit as the local agent). |
| `lib/app/theme/app_colors.dart` | Color tokens | Implements design-system colors from `docs/01-design-system.md`. |
| `lib/app/theme/app_spacing.dart` | Spacing and radius tokens | 4/8/12/16/20/24/32/40/48 scale and radius tokens. |
| `lib/app/theme/app_text_styles.dart` | Typography tokens | Inter font via `google_fonts`. |
| `lib/shared/widgets/` | Shared UI primitives | Buttons, cards, inputs, tabs, alerts, badges, tables, logs, compliance warnings popup, update dialog. |
| `lib/shared/utils/zalo_backend_manager.dart` | Desktop local backend **supervisor** | Spawns the packaged local Zalo backend (prefers direct `node.exe dist/server.cjs` beside `alpha_crm.exe`, falls back to `zalo-bot-service.cmd`/`.exe`/`.bat`). Exposes `BackendStatus` via a `ValueNotifier`; `startSupervised()` runs a 5s /health watchdog with auto-restart (exponential backoff + circuit breaker) and `retryManually()` for circuit-open recovery. Binds each spawned process to a Windows Job Object so it dies with the app. |
| `lib/shared/utils/windows_job_object.dart` | Windows Job Object helper (raw FFI) | Creates a `KILL_ON_JOB_CLOSE` Job Object and assigns the backend pid so node.exe is killed by the OS when the app exits (incl. hard kill). Isolated from Flutter imports to avoid win32 symbol clashes; fails silently → falls back to taskkill. |
| `lib/shared/widgets/backend_status_banner.dart` | Global backend status banner | `ValueListenableBuilder` on `ZaloBackendManager.status`; hidden when healthy/stopped, shows starting/restarting/degraded and a red failed state with a "Thử lại" button (`retryManually`). Mounted in `main.dart` above the router child. |
| `lib/shared/widgets/backend_splash_overlay.dart` | First-startup splash | Full-screen glassmorphic splash shown while the backend starts for the FIRST time (covers login/app); disappears permanently once `BackendStatus.healthy`; shows error + "Thử lại" on `failed`. Wraps the app in `main.dart`. |
| `lib/shared/utils/desktop_window_manager.dart` | Windows window + tray shell | `DesktopShell` (uses `window_manager` + `tray_manager`): maximize owned by native runner; intercepts the X button (`setPreventClose`) and raises `closeRequest` so the UI can confirm. Exposes `exitApp()` / `hideToTray()` / `cancelClose()`; tray menu ("Hiện ứng dụng" / "Thoát"). Real exit calls `ZaloBackendManager.stopBackend()` then `destroy()`. Tray icon = `assets/app_icon.ico`. |
| `lib/shared/widgets/app_close_gate.dart` | X-button confirm dialog | Wraps the whole app; listens to `DesktopShell.closeRequest` and renders an inline `AppDialog` (no `showDialog`/Navigator needed) with "Thoát luôn" / "Ẩn xuống tray" / "Hủy". |
| `lib/shared/widgets/revocation_gate.dart` | Device-revoked confirm dialog | `ConsumerWidget` wrapping the whole app; watches `CrmAuthState.deviceRevokedReason` and renders an inline `AppDialog` ("Dùng máy này" → `reclaimRevokedDevice`, "Đăng xuất" → `dismissRevokedDevice`). Global mount so it shows in any router state. |
| `lib/features/**/providers/` | Feature state | Riverpod `StateNotifier` classes for mock interactions. |
| `lib/features/subscription/models/subscription_catalog.dart` | CRM subscription catalog helper | Keeps Flutter plan/top-up prices aligned with backend catalog and parses VietQR checkout payloads. |
| `lib/mock/` | Mock data | Contacts, campaigns, messages, groups, accounts, system settings (with Zalo compliance fields). |
| `lib/shared/utils/zalo_compliance_guard.dart` | Shared compliance guard | Channel-mode-aware rule engine evaluating risk for all Zalo actions. |
| `lib/shared/utils/app_update_service.dart` | Auto-update service | Fetches B2 `version.json`, compares semver, downloads the per-platform asset (Windows `.zip`, Android `.apk`), applies Windows zip in-place via a console updater script (titled, shows progress, auto-closes, restarts app on success/failure), writes a `.update_pending` marker, and verifies the result on next launch via `checkPostUpdateResult()`. |
| `lib/shared/widgets/update_result_gate.dart` | Post-update result UI | Global inline gate: green success banner (auto-dismiss) or a "Cập nhật chưa hoàn tất → Tải lại bản mới" dialog when an in-place update did not apply. Driven by `postUpdateResultProvider`. |
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
| `lib/features/groups/manage/` | Managed groups + AI summary | `/groups/manage` tab. Per-group AI summary wizard (scope incremental/recent/range, extraction goals, industry prompt templates in `data/group_summary_templates.dart`, auto-task toggle). **Local-first:** wizard choice is remembered per Zalo `groupId` in `data/group_summary_local_store.dart` (`Documents/AlphaCRM/group_summaries.json`), which also caches the summary history shown instantly on select. "Tóm tắt AI" **always** opens the wizard (no separate config button); the wizard previews how many local messages the scope covers and **blocks summarize when < `kMinSummaryMessages` (5)**. "Lịch sử tóm tắt" button opens `group_summary_history_dialog.dart` (full local history; closes via the builder's own dialog context — see IMPORTANT_FIXED_BUGS). The list has a client-side name search box (`_groupSearchProvider`). Groups are merged by **logical identity** (`groupIdentityKey` = clean lowercased name + member count, in the provider) rather than raw Zalo `groupId`, so the same real-world group synced by several accounts under **different Zalo IDs** collapses into one row with overlapping `AccountAvatarStack` avatars. Local config/history/watermark are all keyed by this identity. When summarizing a merged group, `_gatherLocalGroupMessages` reads **every sibling account's** local conversation and **unions + dedupes messages by message id** (sorted oldest→newest) so differing per-account coverage (few vs many messages, different senders) collapses into one timeline. `setManaged` and the "Điểm cần chú ý" insight filter also operate over all sibling records (by identity / sibling Zalo IDs). Group names are stripped of any `[id]` prefix. **Privacy: group message content is NOT stored on the backend.** The provider reads messages from the **local** store via `LiveChatLocalBridgeApi` (matches group→conversation by `threadId`, scope→cursor) and sends them **transiently** in the body of `POST /crm/groups/:id/summarize`; cloud runs the LLM and persists only the derived structured summary + insights. Incremental watermark = prior summary `coveredTo`; insights deduped by `dedupKey`. Requires the local desktop backend (won't work on web/mobile, which have no local messages). |

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
