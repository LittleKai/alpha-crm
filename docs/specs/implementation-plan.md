# Alpha CRM Reference Integration Implementation Plan

**Date:** 2026-06-04
**Goal:** Integrate a small, high-value subset of UI/UX ideas from `deplao-builder` and `ZaloCRM` into Alpha CRM without changing backend contracts or adding dependencies.

## Constraints

- Do not copy reference code directly across frameworks.
- Do not change backend/API contracts.
- Do not add Flutter packages unless a later phase proves it is required.
- Use existing design tokens: `AppColors`, `AppSpacing`, `AppTextStyles`.
- Use existing shared widgets first.
- Keep high-risk Zalo actions covered by the existing compliance warning pattern.
- Create `docs/reference-analysis.md` and this file before code changes.

## Phase 0 - Analysis And Documentation

### Tasks

- Analyze current Alpha CRM architecture, screens, components, state management, routing, CRM features, UI/UX weaknesses, and safe refactor areas.
- Analyze `deplao-builder` and `ZaloCRM` reference projects.
- Create `docs/reference-analysis.md`.
- Create `docs/implementation-plan.md`.

### Verification

- Confirm both docs exist and include the required feature comparison and implementation plan sections.

## Phase 1 - Customers Workspace UI

### UI First

Improve `lib/features/customers/presentation/screens/customers_screen.dart`:

- Add a pipeline/health summary section derived from current contacts:
  - Chưa gửi
  - Đã gửi
  - Thành công
  - Thất bại
- Make customer rows selectable with checkboxes using existing `CustomersNotifier.toggleContactSelection`.
- Add row activation to show a detail panel.
- Add a desktop two-column layout:
  - Main contact table/list on the left.
  - Contact detail panel on the right when a customer is active.
- Keep mobile layout stacked and avoid table overflow.
- Add a floating or inline contextual bulk action bar when `selectedIds` is not empty:
  - Count selected contacts.
  - Clear selection.
  - Export current selection placeholder via existing export flow where practical.
  - Start bulk messaging by navigating to `/messaging/bulk`.
- Convert complex customer dialogs from `AlertDialog` to `AppDialog`.

### Function First

No backend/API contract change in this phase. Function changes are local UI state and existing provider calls:

- Existing add contact flow stays through `CustomersNotifier.addContact`.
- Existing save segment flow stays through `CustomersNotifier.saveCurrentFiltersAsSegment`.
- Existing selection state stays in `CustomersState.selectedIds`.
- Existing export flow stays through `CustomersNotifier.exportContacts`.

### Refactor

- Keep the implementation inside `customers_screen.dart` unless a component becomes reused elsewhere.
- Use private widgets in the same file:
  - `_CustomerPipelineCard`
  - `_ContactDetailPanel`
  - `_SelectedContactsBar`
  - `_ContactAvatar`
- Avoid changing shared widget APIs.

### Expected Files

- Modify: `lib/features/customers/presentation/screens/customers_screen.dart`
- Modify: `.claude/PROJECT_SUMMARY.md`
- Create: `docs/reference-analysis.md`
- Create: `docs/implementation-plan.md`
- Test/possibly modify: `test/widget_test.dart` or add `test/customers_screen_test.dart` only if existing smoke tests do not cover the new UI reliably.

### Risks

- `DataTable2` can overflow if embedded in a narrow row with a detail panel. Use constrained heights and responsive layout.
- Selection state can retain IDs after filters change. The current provider already keeps selection globally; UI should display the selected count honestly and provide clear selection reset.
- Dialog conversion can introduce layout overflow on mobile. Use `AppDialog` width constraints and scrollable content.
- Existing analyzer may report old lint info unrelated to this work. Fix compile errors caused by this change, but avoid broad unrelated lint cleanup.

### Tests

- Run `flutter analyze`.
- Run `flutter test`.
- If test runtime is too high or environment-limited, run at least:
  - `flutter test test/widget_test.dart`
  - any newly added Customers test.

## Phase 2 - Later Dashboard Improvements

Add ZaloCRM-inspired dashboard sections after Phase 1 is stable:

- Pipeline chart/card from customer lifecycle.
- Source distribution card.
- Appointment/order KPI placeholders only if backend data exists.
- Campaign performance table from current campaign/send history APIs.

Expected files:

- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- `lib/features/dashboard/providers/dashboard_provider.dart`
- `test/widget_test.dart` or focused dashboard widget tests.

## Phase 3 - Later Topbar Utilities

Add global search and notifications once data sources are confirmed:

- Global search from contacts/messages/tasks/appointments where APIs exist.
- Notification menu for disconnected Zalo accounts, unreplied conversations, overdue tasks, and subscription/device warnings.

Expected files:

- `lib/app/shell/app_topbar.dart`
- `lib/features/**/providers/*` as needed for data source reuse.
- New shared search/notification widgets only if reusable.

## Phase 4 - Later CRM Domain Expansion

Only after backend contract is confirmed:

- Contact appointment context.
- Orders context.
- Broader reports/export.
- Team/account ACL views.

These should not be implemented as mock-only UI unless explicitly requested.

## Immediate Execution Choice

Proceed with Phase 1 only in this session. It is high value, low risk, and does not require backend or dependency changes.

