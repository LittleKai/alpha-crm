# BUILDER_LOG.md

**SPEC:** SPEC-phase-5.md
**Built by:** antigravity-claude-opus-4-6-thinking, 2026-06-05
**Status:** Complete

## Files touched

- `pubspec.yaml` / `pubspec.lock` — Added `cached_network_image`.
- `lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart` — Replaced `Image.network` with `CachedNetworkImage` for media previews, fullscreen viewer, and inline image components, retaining the original `errorWidget` behavior.
- `lib/shared/local_db/local_db_maintenance.dart` — Created an opportunistic TTL cache eviction script to prune expired generic cache rows, expired media cache rows, and optionally prune old messages. 
- `test/live_chat_cache_eviction_test.dart` — Added test logic for cleanup preservation logic.
- `lib/features/messaging/live_chat/providers/live_chat_provider.dart` — Hooked up `LocalDbMaintenance.runCleanup()` upon `LiveChatRepository` initialization so that local caching prevents disk bloating over time. 
- `integration/zalo-bot-service/src/local-chat/local-chat-store.test.ts` — Fixed an async race condition in the previous chronological order test by ensuring explicit minimum sleep limits.
- `README.md` & `integration/zalo-bot-service/README.md` & `.claude/PROJECT_SUMMARY.md` — Added documentation references, warnings, and architectural overviews for the Local-First Live Chat environment flag (`LOCAL_FIRST_LIVE_CHAT`), usage of SQLite (`better-sqlite3`), and bridge APIs.

## Summary

Implemented phase 5. We integrated `cached_network_image` to avoid fetching Zalo image assets multiple times and rendering placeholders during HTTP latency. We introduced `LocalDbMaintenance` which seamlessly hooks into repository provider initialization to garbage collect old generic queries and media cache links. To ensure safety, local DB starts gracefully without wiping cloud data or crashing when empty, displaying appropriate offline statuses. Tests and documentation were updated across both Flutter and backend bridging layers to reflect the local-first architectural shift.

## Deviations from SPEC

None.

## Open questions

None.