# BUILDER_LOG.md

## Entry: .hybrid-ai/SPEC.md - 2026-07-04

**SPEC:** .hybrid-ai/SPEC.md
**Built by:** Claude Sonnet 5 - 2026-07-04
**Status:** Complete

## Files touched

- `lib/features/messaging/live_chat/data/live_chat_repository.dart` - `watchEvents()` gate now checks `_preferLocalZaloActions || localFirstEnabled` instead of `localFirstEnabled` alone.
- `lib/features/messaging/live_chat/data/live_chat_local_bridge_api.dart` - Added 60s inactivity `.timeout()` on the SSE line stream in `watchEvents()`.
- `test/live_chat_repository_watch_events_test.dart` (new) - Regression test asserting desktop opens local SSE even when `localFirstEnabled` is false.
- `lib/shared/utils/zalo_backend_manager.dart` - `_failureThreshold` 2→3, health-probe timeout 2s→5s (in `_readHealth`, called by `_probeHealth`), added `_ticking` re-entrancy guard around `_tick()`, added `_circuitOpenedAt` + 5-minute cooldown auto-retry when circuit is open, fixed stale exit-listener race in `waitUntilReady` via a captured `watchedProcess` identity check.
- `integration/zalo-bot-service/src/server.ts` - Added `process.on('uncaughtException', ...)` handler; rebuilt `dist/server.cjs` (gitignored).
- `.claude/IMPORTANT_FIXED_BUGS.md` - New top entry (2026-07-04) documenting the watchEvents gate bug + supervisor hardening.
- `.claude/PROJECT_SUMMARY.md` - Updated `zalo_backend_manager.dart` and Live Chat transport description rows; updated "Latest Session" summary.

## Summary

Implemented all 8 SPEC steps. The core fix (Step 1) closes the gap where desktop Live Chat silently degraded to a 12s polling timer that dies on tab navigation, by aligning `watchEvents()` with the same local-action gate pattern used everywhere else in the repository. Step 3 adds a 60s SSE inactivity timeout so a zombie socket surfaces as a stream error (triggering the notifier's existing reconnect-with-backoff) instead of leaving `realtimeConnected` stuck `true` and blocking the polling fallback. Steps 4-6 harden the backend supervisor against a synchronous `better-sqlite3` backend (looser probe tolerance, re-entrancy guard, non-latching circuit breaker, fixed exit-listener race). Step 7 adds a matching `uncaughtException` safety net on the backend side. One deviation: the 2s→5s probe timeout SPEC described as "inside `_probeHealth`" is actually one call-level down in the private helper `_readHealth` that `_probeHealth` invokes — it is the only `Duration(seconds: 2)` in the file, so intent was unambiguous.

## Baseline verification

- `flutter analyze` - Passed (72 pre-existing info/warning issues, 0 errors; none in SPEC target files)
- `flutter test` - 149 passed / 1 failed (pre-existing `workflow_screen_test.dart` failure, unrelated to this SPEC — caused by pre-existing uncommitted sidebar/workflow UI work already in the working tree)

## Final verification

- `flutter analyze` (full repo) - Passed - same 72 pre-existing issues, no new issues
- `flutter test` (full repo) - 150 passed / 1 failed - same pre-existing unrelated failure; new regression test passes
- `npm test` (integration/zalo-bot-service) - Passed - all 131 tests
- `npm run bundle` - Passed - `dist/server.cjs` rebuilt (2.0mb), contains `uncaughtException` handler

## Placeholder scan

- `Select-String -Pattern "TODO|stub|placeholder|NotImplemented"` over all 5 touched implementation files - Clean (2 matches found, both pre-existing and outside the lines this SPEC touched: a doc comment for the existing `NOT_SUPPORTED_REMOTE` stub design in `live_chat_repository.dart:9`, and a pre-existing `TODO` at `server.ts:952` unrelated to this change)

## Deviations from SPEC

- Step 4: the `.timeout(const Duration(seconds: 2))` SPEC located "inside `_probeHealth` (near line 584)" is actually inside `_readHealth`, the private helper that `_probeHealth` calls one level down — not textually inside `_probeHealth`'s own body. It is the only `Duration(seconds: 2)` in the file and the intended change (raise the HTTP health-probe timeout) is unambiguous, so treated as a minor mismatch and applied there.
- Step 2: omitted the `skip: false` argument shown in the SPEC's test skeleton — it is a no-op (tests are not skipped by default), so dropping it is not a behavior change.

## Open questions

None.
