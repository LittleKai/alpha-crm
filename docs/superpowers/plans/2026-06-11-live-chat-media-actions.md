# Live Chat Media And Message Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver bridge-managed media caching and reliable Live Chat actions, search, playback, and downloads on Windows, Android, and Web.

**Architecture:** Extend the existing local-chat store, media worker, and API rather than adding a second backend. Normalize message actions and attachments in Flutter, then build platform download adapters and focused UI surfaces on top.

**Tech Stack:** Flutter, Riverpod, Dart IO/Web adapters, Node.js, TypeScript, better-sqlite3, HTTP Range responses.

---

### Task 1: Provider message action identifiers

**Files:**
- Modify: `lib/features/messaging/live_chat/providers/live_chat_provider.dart`
- Modify: `lib/features/messaging/live_chat/data/live_chat_repository.dart`
- Modify: `lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`
- Test: `test/live_chat_provider_test.dart`
- Test: `test/live_chat_repository_test.dart`

- [ ] Add failing tests proving reaction and recall dispatch the provider message ID.
- [ ] Add a failing test proving outbound messages cannot react.
- [ ] Run focused Flutter tests and confirm expected failures.
- [ ] Add `providerActionId`, guard outbound reactions, and select local/cloud APIs from configuration.
- [ ] Run focused tests and confirm they pass.

### Task 2: Bridge media cache contract

**Files:**
- Modify: `integration/zalo-bot-service/src/local-chat/local-chat-types.ts`
- Modify: `integration/zalo-bot-service/src/local-chat/local-chat-store.ts`
- Modify: `integration/zalo-bot-service/src/local-chat/local-chat-media-worker.ts`
- Test: `integration/zalo-bot-service/src/local-chat/local-chat-store.test.ts`

- [ ] Add failing tests for cache state, access timestamps, usage, and oldest-first cleanup.
- [ ] Run backend tests and confirm expected failures.
- [ ] Add schema migration and store methods for media cache metadata.
- [ ] Update the worker to persist pending, ready, and failed states.
- [ ] Run backend tests and confirm they pass.

### Task 3: Bridge media HTTP API

**Files:**
- Modify: `integration/zalo-bot-service/src/local-chat/local-chat-api.ts`
- Add: `integration/zalo-bot-service/src/local-chat/local-chat-media-api.test.ts`

- [ ] Add failing tests for full media responses, byte ranges, download disposition, stats, cleanup, and retry.
- [ ] Implement validated cache lookup and streaming responses.
- [ ] Add media settings, stats, cleanup, and retry endpoints.
- [ ] Run backend tests and build.

### Task 4: Flutter attachment normalization and downloads

**Files:**
- Modify: `lib/features/messaging/live_chat/utils/live_chat_attachment_view.dart`
- Add: `lib/features/messaging/live_chat/data/live_chat_download_service.dart`
- Add platform implementations beside the service.
- Modify: `pubspec.yaml`
- Test: `test/live_chat_attachment_view_test.dart`
- Add: `test/live_chat_download_service_test.dart`

- [ ] Add failing tests for malformed percent encoding and video metadata.
- [ ] Add failing tests for destination naming and platform delegation.
- [ ] Implement safe decoding, video kind, cache URLs, and download adapters.
- [ ] Run focused Flutter tests.

### Task 5: Search and media UI

**Files:**
- Modify: `lib/features/messaging/live_chat/providers/live_chat_provider.dart`
- Modify: `lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`
- Add: `lib/features/messaging/live_chat/presentation/screens/live_chat_video_screen.dart`
- Test: `test/live_chat_provider_test.dart`
- Add: `test/live_chat_search_dialog_test.dart`

- [ ] Add failing provider tests for loading, errors, conversation scope, and selected-result ID.
- [ ] Implement search state and selected-result highlight state.
- [ ] Replace the search alert with a custom dialog and keyed scroll-to-result behavior.
- [ ] Add image/file download controls and a video player page.
- [ ] Run focused Flutter tests.

### Task 6: Settings and cache controls

**Files:**
- Modify: the existing `SystemSettings` model file located by symbol search.
- Modify: `lib/features/settings/providers/settings_provider.dart`
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`
- Add or modify focused settings tests.

- [ ] Add failing persistence tests for download folder, 90-day age, and 20-GB limit.
- [ ] Implement settings persistence and bridge cache API calls.
- [ ] Add folder selection, usage, clear-cache, and fallback explanations for Web.
- [ ] Run focused settings tests.

### Task 7: Documentation and full verification

**Files:**
- Modify: `.claude/PROJECT_SUMMARY.md`
- Modify: `.claude/IMPORTANT_FIXED_BUGS.md`

- [ ] Run `dart format` on changed Dart files.
- [ ] Run backend tests and build.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] Update current-state documentation and record the provider-ID/media-cache invariants.
