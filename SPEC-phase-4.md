# SPEC Phase 4: Flutter Local-First Repository And Sqflite Cache

## Goal

Make Flutter Live Chat use cloud only for conversation metadata and use the local
bridge for full messages, with sqflite-backed local cache to reduce repeated
cloud/local API calls and improve offline/bridge-offline behavior.

## Dependencies

- Phase 1 settings/contracts.
- Phase 2 local bridge APIs.
- Phase 3 cloud local-first response shape, or fallback-compatible behavior.

## Context / Constraints

- Primary files:
  - `lib/features/messaging/live_chat/data/live_chat_repository.dart`
  - `lib/features/messaging/live_chat/providers/live_chat_provider.dart`
  - `lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`
  - `lib/shared/api/crm_cloud_api.dart`
  - `lib/features/zalo_integration/data/zalo_integration_api.dart`
  - `lib/features/settings/providers/settings_provider.dart`
- Dependency file: `pubspec.yaml`.
- Tests: `test/live_chat_provider_test.dart` plus new local cache tests.

## Steps

### Step 4.1 - Add Flutter SQLite Dependencies

**Files**

- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`

**Action**

- Add:
  - `sqflite_common_ffi`
  - `sqflite` only if mobile implementation needs it.
  - `path` if direct DB path joining is needed.
- Initialize sqflite FFI for desktop before opening the DB. Keep initialization
  inside a shared DB service, not in widget code.
- Do not use Python or external scripts for dependency edits.

**Verify**

- `flutter pub get` succeeds.
- `flutter test` can run on host without missing SQLite plugin errors.

### Step 4.2 - Create Shared Local Database Service

**Files**

- Create: `lib/shared/local_db/local_db.dart`
- Create: `lib/shared/local_db/local_db_schema.dart`
- Create tests: `test/local_db_test.dart`

**Action**

- Open DB under app support/documents directory via `path_provider`.
- Use a schema versioned migration:
  - `cache_entries`: generic cache key/value JSON with `expiresAt`.
  - `live_chat_conversations`: cloud conversation metadata cache.
  - `live_chat_messages`: local message cache keyed by conversation id and
    message/provider id.
  - `media_cache`: URL, localPath, mime/type, size, expiresAt, lastAccessedAt.
- Provide a constructor/factory allowing tests to use in-memory or temp DB.
- Keep API small and repository-friendly.

**Verify**

- Tests cover DB open, migration, insert/get/delete expired cache.

### Step 4.3 - Add Live Chat Cache Repository

**Files**

- Create: `lib/features/messaging/live_chat/data/live_chat_cache.dart`
- Create tests: `test/live_chat_cache_test.dart`

**Action**

- Implement:
  - `saveConversations(cacheKey, List<Map<String, dynamic>>, ttl)`
  - `getFreshConversations(cacheKey)`
  - `saveMessages(conversationId, List<Map<String, dynamic>>, {merge})`
  - `getMessages(conversationId, {limit, before, after})`
  - `clearFailedMessages(conversationId)`
  - `touchMediaUrl(url, metadata)`
- Cache key should include account id and search query so filtered lists do not
  collide.
- Message merge must be idempotent by `zaloMsgId`, `_id/id`, or a deterministic
  fallback key matching `_messageKey` behavior in `LiveChatNotifier`.

**Verify**

- Tests cover TTL hit/miss, message merge, paging, failed-message clearing.

### Step 4.4 - Split Cloud And Local Bridge Clients

**Files**

- Modify: `lib/features/messaging/live_chat/data/live_chat_repository.dart`
- Create: `lib/features/messaging/live_chat/data/live_chat_local_bridge_api.dart`
- Modify tests: `test/live_chat_provider_test.dart` or create repository tests.

**Action**

- Keep cloud methods for:
  - `getAccounts`
  - `getManagedGroups`
  - `getConversations`
  - metadata updates such as tags/notes/markRead if still cloud-owned.
- Add local bridge methods for:
  - `getLocalHealth`
  - `getLocalMessages`
  - `sendLocalMessage`
  - `sendLocalAttachment`
  - `recallLocalMessage`
- `LiveChatRepository.getMessages` should:
  - if `localFirstLiveChat` is true, try local bridge first.
  - on local success, cache messages and return them.
  - on local offline, return cached messages with a bridge-offline marker if
    available.
  - only call cloud messages as legacy fallback when local-first flag is false
    or when explicitly configured.
- `getConversations` should use cloud, cache result, and use cache when cloud
  fails or TTL says fresh enough.

**Verify**

- Tests simulate:
  - local bridge success.
  - local bridge offline with cached messages.
  - cloud conversation cache hit avoids second cloud call within TTL.
  - legacy mode still calls cloud messages.

### Step 4.5 - Update LiveChatNotifier UX State

**Files**

- Modify: `lib/features/messaging/live_chat/providers/live_chat_provider.dart`
- Modify: `lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`

**Action**

- Add state flags:
  - `isBridgeOffline`
  - `isUsingCachedMessages`
  - `messageSource`: `local`, `cache`, `cloudLegacy`, or similar.
- When selecting a conversation:
  - load cached messages immediately if available.
  - then refresh from local bridge if online.
  - show "Bridge offline, chi xem duoc metadata/recent summary" when local
    bridge is unavailable and no full cached messages exist.
- Existing send UI should disable or show clear error when local-first is on and
  bridge is offline.
- Keep polling gentle: do not call cloud messages on every 12-second poll in
  local-first mode.

**Verify**

- Provider tests assert bridge offline status and cached messages are reflected
  in state.
- UI test or widget smoke verifies offline banner text exists.

## Phase 4 Verification

- `dart format` on touched Dart files.
- `flutter test test/local_db_test.dart test/live_chat_cache_test.dart`
- `flutter test test/live_chat_provider_test.dart`
- `flutter test`
- `flutter analyze`; report existing baseline info-level lints separately.
