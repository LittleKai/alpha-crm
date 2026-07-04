# REVIEW_LOG.md

## Entry: .hybrid-ai/SPEC.md - 2026-07-04

**Reviewed by:** Claude Sonnet 5
**Builder entry reviewed:** "Entry: .hybrid-ai/SPEC.md - 2026-07-04" in BUILDER_LOG.md (Status: Complete)

### Scope

Reviewed all 8 SPEC steps against the actual working tree: `live_chat_repository.dart`, `live_chat_local_bridge_api.dart`, `zalo_backend_manager.dart`, `server.ts`, the new regression test, and the two doc files.

### Verification performed

- Read every changed region of the 4 implementation files directly (not just diff hunks) and compared line-for-line against the SPEC's Context Pack / Steps.
- Step 1 (`watchEvents` gate): confirmed `if (!_preferLocalZaloActions && !localFirstEnabled) { return const Stream.empty(); }` — exact match, only line changed in the method.
- Step 3 (SSE inactivity timeout): confirmed 60s `.timeout()` inserted exactly where specified, `finally { client.close(); }` untouched.
- Step 4 (probe tolerance + tick guard): confirmed `_failureThreshold = 3`, `.timeout(const Duration(seconds: 5))` in `_readHealth` (Builder correctly noted in BUILDER_LOG this is one call-level below `_probeHealth`, not textually inside it — harmless, unambiguous, correctly justified deviation), `_ticking` guard wraps the full `_tick()` body via try/finally with all original `return`s intact.
- Step 5 (circuit auto-retry): confirmed `_circuitCooldown = Duration(minutes: 5)`, `_circuitOpenedAt` declared/set/reset in all 4 required places (`_tick` cooldown branch, `_ensureRunning` circuit-open branch, `startSupervised`, `retryManually`). Traced the cooldown-expiry code path manually — after cooldown, one restart attempt is made through the normal `_ensureRunning` flow with counters reset, and the circuit correctly re-opens after another `_maxRestartsPerWindow` failures if the backend is still broken. No infinite-retry or lockout logic error.
- Step 6 (`waitUntilReady` exit-listener race): confirmed `final watchedProcess = _backendProcess;` capture + `if (!identical(watchedProcess, _backendProcess)) return;` guard inside the `.then()` callback, exactly as specified; the 3s HTTP timeout and 20s overall timeout in this method are untouched.
- Step 7 (`uncaughtException`): confirmed handler appended verbatim after the existing `unhandledRejection` handler in `server.ts`; re-ran `npm run bundle` myself and confirmed `dist/server.cjs` contains the handler.
- Step 8 (docs): confirmed `.claude/IMPORTANT_FIXED_BUGS.md` has a new top entry dated 2026-07-04 describing the bug class and the fix, and `.claude/PROJECT_SUMMARY.md` rows for `zalo_backend_manager.dart` and `live_chat_transport.dart` plus the "Latest Session" line accurately reflect the new behavior (probe 5s/3-miss, 5-min cooldown, `_preferLocalZaloActions || localFirstEnabled` gate). No changelog-style prose added, consistent with project rules.
- Scope check: `git status` shows a number of modified/untracked files (`app_router.dart`, `app_sidebar.dart`, `bulk_messaging_screen.dart`, `chatbot_screen.dart`, `settings_screen.dart`, `system_logs_screen.dart`, `workflow_automation_screen.dart`, `CONVENTIONS.md`, new settings/log-tab widgets, etc.) that are **not** listed in BUILDER_LOG's "Files touched" and are unrelated to this SPEC's scope (sidebar/workflow UI, tooltip conventions). These are pre-existing uncommitted work already in the working tree before this Builder run (as BUILDER_LOG itself notes re: the one pre-existing failing test). Builder did not touch or claim them — correctly out of scope, not a Builder violation.
- Placeholder scan: `TODO|stub|placeholder|NotImplemented` over all 5 touched implementation files → 2 matches, both pre-existing and outside the edited lines (`live_chat_repository.dart:9` doc comment for the existing `NOT_SUPPORTED_REMOTE` design, `server.ts:952` pre-existing unrelated TODO). No new placeholders introduced.

### Commands run (fresh, independent of Builder's log)

- `flutter analyze` → 0 errors, same 72 pre-existing info/warning issues as Builder's baseline, none in SPEC target files.
- `flutter test test/live_chat_repository_watch_events_test.dart` → `All tests passed!`
- `flutter test test/zalo_backend_manager_port_policy_test.dart` → `All tests passed!` (existing test, no regression)
- `flutter test` (full suite) → 150 passed / 1 failed — the failure is `workflow_screen_test.dart: Workflow automation route opens from sidebar on desktop`, matching Builder's documented pre-existing/unrelated failure (caused by the unrelated sidebar/workflow work already in the tree, not this SPEC).
- `npm test` (integration/zalo-bot-service) → all 131 tests pass.
- `npm run bundle` → succeeds, `dist/server.cjs` (2.0mb) rebuilt and contains `uncaughtException`.

### Findings

None. No correctness bugs, no scope creep within the SPEC's own files, no placeholder/shell behavior, no convention violations (Vietnamese doc-comment style matched, no i18n surface since no user-facing UI text was added, surgical single-purpose edits only). The one documented deviation (probe timeout location: `_readHealth` vs `_probeHealth`) was correctly identified and justified by Builder, and is the only `Duration(seconds: 2)` in the file so there was no ambiguity risk.

### Attribution

Not applicable — no defects found to attribute.

### Report

- Reviewed: all 8 SPEC steps, cross-checked against BUILDER_LOG.md claims and the live working tree.
- Passed: every step implemented correctly and verified independently (analyzer, focused tests, full suite, backend tests, bundle rebuild, placeholder scan, doc updates).
- Fixed inline: nothing needed fixing.
- Still needs attention: the pre-existing `workflow_screen_test.dart` failure and the unrelated uncommitted sidebar/workflow/CONVENTIONS.md changes in the working tree are outside this SPEC's scope and were not introduced by this Builder run — flagging only for the user's awareness, not blocking this review.
- Ready to ship/commit: yes, for the SPEC's own file set.

VERDICT: SHIP
