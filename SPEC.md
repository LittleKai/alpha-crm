# SPEC: Remaining Reference Integration Phases

## Goal

Implement the remaining high-value Alpha CRM improvements that were selected from
`deplao-builder` and `ZaloCRM`, after the completed Customers workspace phase.
The goal is to make the app feel more like an operational CRM without changing
backend contracts unnecessarily, adding new dependencies, or copying reference
code across frameworks.

This SPEC is the handoff for the Builder model. It covers Phase 2, Phase 3, and
the gated Phase 4 work only. Phase 0 documentation and Phase 1 Customers UI have
already been completed.

## Current Status

- Done: `docs/reference-analysis.md`.
- Done: `docs/implementation-plan.md`.
- Done: Phase 1 Customers workspace UI in
  `lib/features/customers/presentation/screens/customers_screen.dart`.
- Done: Customers regression test in `test/customers_screen_test.dart`.
- Missing before this SPEC: no root `SPEC.md` existed, even though
  `.claude/PROJECT_SUMMARY.md` previously listed it.

## Context / Constraints

- Follow `claude.md`, `.claude/PROJECT_SUMMARY.md`, and
  `.claude/CONVENTIONS.md`.
- Keep feature changes inside the relevant feature folder unless there is clear
  reuse or app-shell ownership.
- Use existing tokens and widgets: `AppColors`, `AppSpacing`, `AppTextStyles`,
  `AppCard`, `AppButton`, `AppBadge`, `AppDialog`, `AppEmptyState`.
- Do not add Flutter packages for these phases.
- Do not change backend/API contracts in Phase 2 or Phase 3.
- Do not create mock-only appointments/orders/reports/team ACL UI in Phase 4.
  Phase 4 must first confirm backend/data contracts.
- Do not remove Zalo compliance warning behavior. High-risk Zalo screens must
  keep using `showComplianceWarningsDialog`.
- Keep Vietnamese UI copy consistent with nearby files. Avoid broad text
  rewrites because several existing files contain encoding artifacts.
- Update `.claude/PROJECT_SUMMARY.md` after implementation changes.
- Run `dart format` on touched Dart files, then `flutter test`, then
  `flutter analyze`. The current baseline may include existing info-level lints
  outside the files touched by this work; do not introduce new errors or new
  lints in changed files.

## Reality Check Already Performed

The following paths/symbols were verified with `rg` before writing this SPEC:

- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
  contains `DashboardScreen`.
- `lib/features/dashboard/providers/dashboard_provider.dart` contains
  `DashboardState`, `DashboardNotifier`, and `dashboardProvider`.
- `lib/features/dashboard/data/dashboard_repository.dart` contains existing
  dashboard endpoints for overview, campaign performance, funnel, campaigns,
  chatbot, and groups analytics.
- `lib/app/shell/app_topbar.dart` contains `AppTopbar`.
- `lib/features/customers/providers/customers_provider.dart` contains
  `CustomersNotifier` and `customersProvider`.
- `lib/features/messaging/live_chat/providers/live_chat_provider.dart` contains
  `Conversation`, `LiveChatNotifier`, and `liveChatProvider`.
- `lib/features/tasks/providers/crm_tasks_provider.dart` contains
  `CrmTask`, `CrmTasksNotifier`, and `crmTasksProvider`.
- `lib/features/zalo_integration/providers/zalo_integration_provider.dart`
  contains `ZaloIntegrationNotifier` and `zaloIntegrationProvider`.
- Route constants verified in `lib/app/routing/app_routes.dart` include:
  `AppRoutes.dashboard`, `AppRoutes.customers`,
  `AppRoutes.messagingBulk`, `AppRoutes.messagingLiveChat`,
  `AppRoutes.tasks`, `AppRoutes.subscription`, and `AppRoutes.settings`.

Discrepancies to account for:

- Use `crmTasksProvider`, not `followUpTasksProvider`.
- Use `AppRoutes.messagingBulk`, not `AppRoutes.bulkMessaging`.
- There is no root `.codegraph/` directory in this repo at the time this SPEC
  was written, so CodeGraph MCP was not available for this handoff.

## Phase 2 - Dashboard Analytics And Operational Overview

### Dependencies

- Phase 1 Customers workspace UI must remain intact.
- No backend/API contract change.

### Goal

Make the Dashboard show CRM health, customer pipeline/source distribution, and
campaign status in a compact operational layout inspired by ZaloCRM and Deplao.

### Step 2.1 - Add Dashboard Regression Coverage First

**Files**

- Create or modify: `test/dashboard_screen_test.dart`
- Keep existing: `test/widget_test.dart`

**Action**

- Add a desktop-width widget test that renders `DashboardScreen` under
  `ProviderScope`.
- The test should fail before implementation by expecting stable keys that do
  not exist yet:
  - `ValueKey('dashboard_pipeline_section')`
  - `ValueKey('dashboard_source_section')`
  - `ValueKey('dashboard_campaign_status_section')`
- If deterministic data injection is needed, prefer a small fake notifier or
  provider override. Keep the test focused on rendering and overflow safety.
- Do not remove or weaken the existing app shell smoke test.

**Verify**

- `flutter test test/dashboard_screen_test.dart` fails before UI work because
  the new sections are missing.
- After implementation, the focused test passes at desktop width.

### Step 2.2 - Normalize Dashboard Data Locally

**Files**

- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- Modify only if needed: `lib/features/dashboard/providers/dashboard_provider.dart`

**Action**

- Do not add repository endpoints.
- Consume existing `DashboardState` fields:
  - `overview`
  - `analytics`
  - `performanceData`
  - `timeRange`
- Read customer status counts from `overview['customerStats']['byStatus']`
  when available.
- Read campaign status counts from `overview['campaignStats']['byStatus']`
  when available.
- Use `state.analytics['funnel']`, `state.analytics['campaigns']`,
  `state.analytics['chatbot']`, and `state.analytics['groups']` only if their
  runtime shape matches the code's expectations.
- Add small private helper methods in `dashboard_screen.dart` for safe map/list
  parsing. Keep them null-safe and tolerant of missing/malformed fields.
- If a helper becomes broadly useful or test-critical, move only that helper to
  `dashboard_provider.dart` with focused tests.

**Verify**

- Missing dashboard keys render empty states instead of throwing.
- Existing loading, refresh, subscription warning, performance chart, quick
  actions, and guide sections still render.

### Step 2.3 - Add Customer Pipeline Section

**Files**

- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

**Action**

- Add a new section after `_buildOperationsMetrics(state)` and before
  `_buildPerformanceCard(state, notifier)`.
- Name it with a private helper such as `_buildCrmPipelineSection`.
- Assign `const ValueKey('dashboard_pipeline_section')` to the top-level widget.
- Show four compact pipeline cards aligned with the Customers screen lifecycle:
  lead/not sent, contacted/sent, customer/success, inactive/failed.
- Use counts from `overview['customerStats']['byStatus']` first. If the backend
  provides only lifecycle keys, map them carefully and document the mapping in a
  short code comment.
- Each card should include label, count, percentage of total, icon, and color.
- Use responsive grid behavior:
  - 4 columns on wide desktop.
  - 2 columns on tablet.
  - 1 column on narrow mobile.

**Verify**

- The section does not overflow at 390px, 768px, and 1440px logical widths.
- Empty or zero counts render as zero without divide-by-zero errors.
- Existing Dashboard test and `test/widget_test.dart` still pass.

### Step 2.4 - Add Source Distribution Section

**Files**

- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- Use existing data only: `customersProvider` or dashboard `overview` if source
  distribution already exists in the response.

**Action**

- Add a source distribution card with
  `const ValueKey('dashboard_source_section')`.
- Prefer a backend-provided source distribution if present in `overview`.
- If no dashboard source distribution exists, derive a lightweight fallback from
  `customersProvider.contacts` using `Contact.source`.
- Do not introduce a new cloud API call just for source distribution.
- Render a compact list/bar distribution instead of a large decorative chart.
  `fl_chart` is already available, but a token-based list is acceptable and
  lower risk.
- Handle loading and empty customer data with a clear empty state.

**Verify**

- Dashboard does not crash if `customersProvider.contacts` is empty.
- Source names and counts fit inside cards on mobile.
- The widget test can find `dashboard_source_section`.

### Step 2.5 - Add Campaign Status / Performance Table

**Files**

- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

**Action**

- Add a compact campaign status section with
  `const ValueKey('dashboard_campaign_status_section')`.
- Use existing `state.performanceData` and/or
  `overview['campaignStats']['byStatus']`.
- Show status totals and a small recent performance table/list:
  - period label
  - success count
  - failure count
  - total count
- Keep the existing line chart in `_buildPerformanceCard`; this section should
  complement it, not replace it.

**Verify**

- The section renders with empty performance data.
- It does not duplicate or remove existing `_buildPerformanceCard` controls.

### Step 2.6 - Phase 2 Verification

**Files**

- Touched Dart files.
- `.claude/PROJECT_SUMMARY.md`

**Action**

- Run `dart format` on touched Dart/test files.
- Run:
  - `flutter test test/dashboard_screen_test.dart`
  - `flutter test`
  - `flutter analyze`
- Update `.claude/PROJECT_SUMMARY.md` with the new current state.

**Verify**

- Focused dashboard test passes.
- Full test suite passes.
- `flutter analyze` has no new issues in touched files. If unrelated existing
  info-level lints remain, report them explicitly.

## Phase 3 - Topbar Global Search And Notifications

### Dependencies

- Phase 2 should be stable first.
- No backend/API contract change.

### Goal

Add lazy, app-shell-level search and notification utilities inspired by ZaloCRM
and Deplao without making the topbar start aggressive polling or heavy work on
every route.

### Step 3.1 - Add Topbar Regression Coverage First

**Files**

- Create: `test/app_topbar_test.dart`

**Action**

- Add a widget test for `AppTopbar`.
- The first test should render the topbar and expect:
  - `ValueKey('global_search_button')`
  - `ValueKey('notification_bell_button')`
- Add an interaction test that opens the search UI and expects:
  - `ValueKey('global_search_panel')`
- Add an interaction test that opens the notification UI and expects:
  - `ValueKey('notification_menu')`
- Use provider overrides or minimal fake state as needed. Keep the tests focused
  on UI opening and result rendering, not backend calls.

**Verify**

- The focused topbar test fails before implementation because the keys are
  missing.
- After implementation, `flutter test test/app_topbar_test.dart` passes.

### Step 3.2 - Convert AppTopbar To Stateful Shell Utility

**Files**

- Modify: `lib/app/shell/app_topbar.dart`

**Action**

- Convert `AppTopbar` from `ConsumerWidget` to `ConsumerStatefulWidget`.
- Preserve the public constructor API:
  - `currentRoute`
  - `onMenuPressed`
- Keep existing breadcrumbs and `WarningIconButton` behavior.
- Add local controller/focus state only if needed for search input.
- Do not move route breadcrumb logic out of the file unless it becomes necessary
  for tests.

**Verify**

- Existing routes still show the same breadcrumb text and route icons.
- Mobile menu button behavior is unchanged.
- Zalo warning icon still appears for the same high-risk routes.

### Step 3.3 - Add Lazy Global Search

**Files**

- Modify: `lib/app/shell/app_topbar.dart`
- Import existing providers only as needed:
  - `customersProvider`
  - `liveChatProvider`
  - `crmTasksProvider`
- Import routes from `lib/app/routing/app_routes.dart`.

**Action**

- Add a topbar search trigger with
  `const ValueKey('global_search_button')`.
- On wide widths, it can look like a compact search field. On narrow widths, use
  an icon button.
- Open a search panel/dialog with `const ValueKey('global_search_panel')`.
- Use `AppDialog` or a custom token-styled dialog/panel. Do not use default
  `AlertDialog` for the complex search panel.
- Implement local Vietnamese-aware normalization without adding dependencies:
  lowercase, remove common Vietnamese diacritics, trim whitespace, and allow
  phone-number matching by digits.
- Search across existing in-memory provider state:
  - Contacts: name, phone, group, tag, source, status.
  - Live chat conversations: customerName, threadId, lastMessage, tag.
  - Tasks: title, description, priority, status.
- Do not add new repository calls in the topbar.
- Do not start new periodic timers in the topbar.
- When a result is tapped:
  - close the panel
  - navigate with `context.go(...)`
  - use existing route constants:
    `AppRoutes.customers`, `AppRoutes.messagingLiveChat`, `AppRoutes.tasks`
- If no providers have loaded data, show an empty/loading-neutral state rather
  than forcing broad refreshes.

**Verify**

- Searching by contact name, phone digits, conversation text, and task title
  works when those states contain data.
- Empty query shows useful recent/category placeholders or an empty prompt.
- Search panel does not overflow on mobile.

### Step 3.4 - Add Notification Bell Menu

**Files**

- Modify: `lib/app/shell/app_topbar.dart`
- Import existing providers only as needed:
  - `zaloIntegrationProvider`
  - `liveChatProvider`
  - `crmTasksProvider`
  - `crmAuthProvider` if subscription state is shown

**Action**

- Add a notification trigger with
  `const ValueKey('notification_bell_button')`.
- Open a menu/panel with `const ValueKey('notification_menu')`.
- Build notifications from existing state only:
  - Zalo backend inactive or disconnected.
  - Connected account with `connected == false`.
  - Connected account with `listenerRunning == false`.
  - `ZaloIntegrationState.agentError`.
  - Conversations with `unreadCount > 0`.
  - Open tasks where `dueAt` is before now.
  - Expired subscription if `crmAuthProvider` already exposes the needed state.
- Keep notification count conservative. If loading state is unknown, do not show
  alarming counts.
- Each notification should have:
  - severity icon/color
  - short title
  - short detail
  - route target
- When tapped, close the menu and navigate with existing route constants:
  `AppRoutes.settings`, `AppRoutes.messagingLiveChat`, `AppRoutes.tasks`,
  `AppRoutes.subscription`, or `AppRoutes.dashboard`.
- Do not add polling. If a manual refresh is added, it should call existing
  notifier methods and be explicitly user-triggered.

**Verify**

- Notification menu opens with zero notifications and with fake notification
  state.
- Existing warning button remains independent from the notification bell.
- No provider repeatedly reloads merely because the topbar rebuilt.

### Step 3.5 - Phase 3 Verification

**Files**

- Touched Dart files.
- `.claude/PROJECT_SUMMARY.md`

**Action**

- Run `dart format` on touched Dart/test files.
- Run:
  - `flutter test test/app_topbar_test.dart`
  - `flutter test`
  - `flutter analyze`
- Update `.claude/PROJECT_SUMMARY.md`.

**Verify**

- Focused topbar test passes.
- Full test suite passes.
- `flutter analyze` has no new issues in touched files. If unrelated existing
  info-level lints remain, report them explicitly.

## Phase 4 - CRM Domain Expansion Gate

### Dependencies

- Phase 2 and Phase 3 should be complete.
- Backend/data contracts must be confirmed before any UI implementation.

### Goal

Decide whether Alpha CRM can safely add appointment/order/report/team CRM
surfaces now. If contracts are missing, document the gap and stop. Do not add
mock-only domain UI.

### Step 4.1 - Contract Audit First

**Files**

- Inspect:
  - `lib/shared/api/crm_cloud_api.dart`
  - `lib/features/**/data/*.dart`
  - `lib/features/**/providers/*.dart`
  - `integration/zalo-bot-service/src/**`
  - `docs/**`
- Create only if contracts are missing:
  - `docs/crm-domain-contract-gap.md`

**Action**

- Search for existing support for:
  - appointments
  - orders
  - reports
  - exports beyond existing Customers export and Send History CSV
  - teams/users/ACL assignments
- Confirm whether the Flutter app already has repositories/providers/routes for
  these domains.
- Confirm whether backend endpoints are already documented or consumed by
  Flutter. Do not infer contracts from reference projects.
- If contracts are missing or ambiguous, create
  `docs/crm-domain-contract-gap.md` with:
  - required endpoints
  - expected response shapes
  - screens that would consume them
  - risk notes
  - proposed phase split for future work
- If contracts are missing, stop Phase 4 after writing the document and updating
  `.claude/PROJECT_SUMMARY.md`.

**Verify**

- The audit uses `rg` results or targeted file reads, not assumptions.
- No Flutter UI code is added if contracts are not confirmed.

### Step 4.2 - Implement Contact Timeline Only If Contract Exists

**Files**

- Modify only if contract exists:
  - `lib/features/customers/presentation/screens/customers_screen.dart`
  - Create only if needed:
    `lib/features/customers/data/customer_activity_repository.dart`
  - Create only if needed:
    `lib/features/customers/providers/customer_activity_provider.dart`
  - Test:
    `test/customers_screen_test.dart` or a focused new test

**Action**

- Add appointment/order/activity context to the existing contact detail panel
  only if real data can be loaded from an existing contract.
- Keep it scoped to the selected contact.
- Show loading, empty, and error states.
- Do not block the current customer table if timeline data fails.
- Do not add a new route unless the product already has a route for that domain.

**Verify**

- Selecting a customer still opens the existing detail panel.
- Timeline data renders when fake/real contract data exists.
- Empty timeline renders a neutral empty state.
- Existing Customers regression test still passes.

### Step 4.3 - Implement Dashboard Appointment/Order KPIs Only If Contract Exists

**Files**

- Modify only if contract exists:
  - `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
  - `lib/features/dashboard/providers/dashboard_provider.dart`
  - `lib/features/dashboard/data/dashboard_repository.dart`
  - `test/dashboard_screen_test.dart`

**Action**

- Add appointment/order KPI cards to Dashboard only when an existing endpoint or
  documented response field exists.
- Reuse the dashboard cards and grid patterns from Phase 2.
- If a field is absent, render the section as unavailable only if the contract
  says the field is optional. Otherwise do not add the section.

**Verify**

- Dashboard remains usable when appointment/order KPI data is empty.
- Tests cover the available-data and empty-data paths.

### Step 4.4 - Defer Reports And Team ACL Unless Already Fully Contracted

**Files**

- Create or update:
  - `docs/crm-domain-contract-gap.md`

**Action**

- Do not create new Reports or Team ACL routes in this SPEC unless all of these
  are already confirmed:
  - route target
  - repository/API contract
  - provider state
  - permission model
  - expected UI workflow
- If not confirmed, document a follow-up SPEC recommendation instead.

**Verify**

- No placeholder Reports/ACL screens are added.
- The gap document clearly tells the next Architect/Builder what is missing.

### Step 4.5 - Phase 4 Verification

**Files**

- Touched docs/Dart/test files.
- `.claude/PROJECT_SUMMARY.md`

**Action**

- If Phase 4 stopped at documentation, verify the document exists and run no
  Flutter commands unless Dart files changed.
- If Dart files changed, run:
  - `dart format` on touched Dart/test files
  - focused tests for changed screens/providers
  - `flutter test`
  - `flutter analyze`
- Update `.claude/PROJECT_SUMMARY.md`.

**Verify**

- The Builder report explicitly says whether Phase 4 was implemented or stopped
  at contract gap documentation.
- No backend/API contract was invented in Flutter.

## Final Builder Handoff Checklist

Before reporting completion, the Builder must provide:

- Phases completed.
- Files changed.
- Tests run and exact outcomes.
- Whether `flutter analyze` has unrelated pre-existing issues.
- Any Phase 4 contract gaps discovered.
- Confirmation that `docs/reference-analysis.md`,
  `docs/implementation-plan.md`, `SPEC.md`, and
  `.claude/PROJECT_SUMMARY.md` remain consistent with the current app state.
