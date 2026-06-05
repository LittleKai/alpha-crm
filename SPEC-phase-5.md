# SPEC Phase 5: Media Cache, Migration Safety, Docs, And Verification

## Goal

Reduce repeated media loads, finish safe migration behavior, and document how to
operate local-first Live Chat without losing compatibility with old cloud mode.

## Dependencies

- Phase 2 local message APIs.
- Phase 4 Flutter local cache and source state.

## Context / Constraints

- Live Chat currently renders images with `Image.network` in
  `lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`.
- There are additional `NetworkImage` usages in group/friend/settings screens,
  but this phase should focus on Live Chat unless the builder explicitly expands
  scope.
- Do not cache secrets or Zalo credentials in Flutter.

## Steps

### Step 5.1 - Add Image/Media Cache Package Or Local Strategy

**Files**

- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`

**Action**

- Prefer `cached_network_image` for simple image caching in Flutter UI.
- If custom media cache is needed, use `media_cache` table from Phase 4 and
  store only downloaded media files/metadata, never tokens/cookies.
- Replace Live Chat message image previews and dialog preview from
  `Image.network` to cached image widget or cache-aware loader.
- Keep existing `errorBuilder`/placeholder behavior.

**Verify**

- Widget tests do not perform real network calls.
- Images still show placeholders/errors safely.
- No UI overflow from image placeholder/loading state.

### Step 5.2 - Add Cache Eviction

**Files**

- Modify: `lib/features/messaging/live_chat/data/live_chat_cache.dart`
- Modify or create: `lib/shared/local_db/local_db_maintenance.dart`
- Add tests: `test/live_chat_cache_eviction_test.dart`

**Action**

- Add TTL cleanup for:
  - generic cache entries.
  - old media cache rows.
  - old message rows only if explicitly configured; default should keep message
    history because local-first makes local DB authoritative.
- Run cleanup opportunistically on app start or repository initialization, not on
  every message render.

**Verify**

- Tests cover expired cache deletion and preserved non-expired messages.

### Step 5.3 - Migration And Fallback Safety

**Files**

- Modify: `lib/features/messaging/live_chat/data/live_chat_repository.dart`
- Modify: `integration/zalo-bot-service/src/local-chat/local-chat-store.ts`
- Modify cloud backend docs if edited in Phase 3.

**Action**

- Do not delete old `zalo_settings.json` settings; migrate new SQLite-backed
  cache alongside it.
- Do not delete cloud `CrmMessage` history automatically.
- If local DB is empty after enabling local-first:
  - show conversation metadata.
  - show bridge-offline/local-history-empty state.
  - do not backfill full cloud messages unless user explicitly approves.
- Ensure send operations create local outbound messages first, so the UI can show
  queued/sent/failed status without waiting for cloud.

**Verify**

- Tests cover empty local DB state.
- Manual smoke can open a conversation with no local messages and no crash.

### Step 5.4 - Documentation Updates

**Files**

- Modify: `.claude/PROJECT_SUMMARY.md`
- Modify: `README.md`
- Modify: `integration/zalo-bot-service/README.md`
- Modify: `integration/zalo-bot-service/.env.example`
- Modify if release packaging changes: `docs/releases/production-release-checklist.md`

**Action**

- Document:
  - `LOCAL_FIRST_LIVE_CHAT`.
  - `localBridgeBaseUrl`.
  - local DB path and backup warning.
  - cloud metadata-only behavior.
  - bridge offline behavior.
  - Windows packaging requirements for SQLite/native DB dependency.

**Verify**

- Docs describe current implemented state, not future hopes.

### Step 5.5 - End-To-End Verification

**Files**

- No new files unless adding smoke scripts.

**Action**

- Run Flutter:
  - `flutter pub get`
  - `dart format` on touched Dart files.
  - `flutter test`
  - `flutter analyze`
- Run local bridge:
  - `npm.cmd run build`
  - focused `node --test` local-chat and existing bridge tests.
- Run cloud backend if Phase 3 was changed:
  - focused `node --test`.
  - `node --check server/routes/crm.js`.
  - `git diff --check`.
- Manual smoke:
  - Start local bridge.
  - Confirm `/local/health`.
  - Receive or seed local message.
  - Open Live Chat in Flutter with `LOCAL_FIRST_LIVE_CHAT=true`.
  - Confirm conversation list comes from cloud metadata and messages come from
    local bridge/cache.
  - Stop bridge and confirm offline/cache banner appears without cloud message
    spam.

**Verify**

- All automated checks pass or known unrelated baseline issues are explicitly
  listed.
- No new full message body is sent to cloud in local-first inbound path.
- Local DB contains full messages and supports paging.
