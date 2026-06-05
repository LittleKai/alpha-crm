# REVIEW_LOG.md

**Reviewed SPEC:** `SPEC.md`
**Reviewed BUILDER_LOG:** `BUILDER_LOG.md`
**Reviewer:** Codex on 2026-06-05T00:00:04+07:00
**Status:** Approved with reviewer fixes

## Scope Reviewed

- Phase 2 Dashboard analytics and operational overview.
- Phase 3 AppTopbar global search and notification utilities.
- Phase 4 CRM domain contract audit.
- Builder-declared files and actual git diff/untracked files.

## Findings

1. `AppTopbar` eagerly watched `dashboardProvider`, `liveChatProvider`, and `crmTasksProvider` while rendering the topbar. Those providers trigger data loads from their constructors, which violated the SPEC requirement for lazy shell utilities and risked background work on every route.
2. `AppTopbar` treated an unknown dashboard subscription state as expired, creating a false notification when `overview` was not loaded.
3. Global search phone matching did not normalize the query to digits before comparing against contact phone digits.
4. Analyzer reported new `unused_element_parameter` warnings for private dialog constructors in `app_topbar.dart`.
5. Analyzer still reported the existing dashboard async-context lint in a touched file.

## Fixes Applied

- Limited topbar notification badge calculation to lightweight `zaloIntegrationProvider` and `crmAuthProvider` state.
- Kept live chat, task, and customer provider reads inside user-opened search/notification dialogs.
- Switched subscription warning logic to known authenticated subscription state from `crmAuthProvider`.
- Added digit-only phone query matching.
- Removed unused `key` parameters from private dialog constructors.
- Added a regression test that fails if the topbar render path initializes dashboard, live chat, or task providers.
- Replaced `context.mounted` with a `mounted` guard before showing the Dashboard snackbar.

## Verification

- `dart format --set-exit-if-changed lib\features\dashboard\presentation\screens\dashboard_screen.dart lib\app\shell\app_topbar.dart test\app_topbar_test.dart` passed.
- `flutter test test\app_topbar_test.dart` passed.
- `flutter test test\dashboard_screen_test.dart` passed.
- `flutter test` passed with `+25`.
- `flutter analyze` still exits 1 with 42 existing info-level issues outside the reviewed topbar changes. No remaining analyzer issues in `lib/app/shell/app_topbar.dart`.

## Residual Notes

- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` no longer has the async-context analyzer issue that was present during review.
- Remaining analyzer info items are the existing project baseline in auth, groups, messaging bulk, settings, Zalo backend waiting, and web auth storage files.
