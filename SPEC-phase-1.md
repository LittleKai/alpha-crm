# SPEC Phase 1: Local-First Foundation And Feature Flags

## Goal

Add explicit local-first configuration and contracts before moving storage. This
phase must not change production behavior unless `LOCAL_FIRST_LIVE_CHAT=true`.

## Dependencies

- Depends on `SPEC.md`.
- No backend data migration yet.

## Context / Constraints

- Flutter settings currently persist to `zalo_settings.json` through
  `SettingsNotifier`.
- Flutter Live Chat currently reads conversations and messages from cloud through
  `LiveChatRepository`.
- Local bridge base URL is already represented by `zaloBackendBaseUrl` in
  `SystemSettings`, but the prompt asks for an explicit local bridge setting.

## Steps

### Step 1.1 - Add Shared Config Shape

**Files**

- Modify: `lib/mock/mock_accounts.dart`
- Modify: `lib/features/settings/providers/settings_provider.dart`
- Modify if UI is needed: `lib/features/settings/presentation/screens/settings_screen.dart`

**Action**

- Add settings fields:
  - `localFirstLiveChat` defaulting from build-time
    `bool.fromEnvironment('LOCAL_FIRST_LIVE_CHAT')` or false-compatible default.
  - `localBridgeBaseUrl`, defaulting to current local backend default
    `http://127.0.0.1:8787`.
  - Optional cache TTL values:
    - `liveChatConversationCacheTtlSeconds` default `30`.
    - `liveChatMessageCacheTtlSeconds` default `300`.
- Persist these in `SystemSettings.toJson/fromJson/copyWith`.
- Keep `zaloBackendBaseUrl` for existing Zalo integration. If both base URL
  fields exist, local bridge Live Chat should use `localBridgeBaseUrl`; legacy
  Zalo screens can continue using `zaloBackendBaseUrl`.

**Verify**

- Existing settings load/save tests or `flutter test` do not regress.
- Existing `zalo_settings.json` without these keys loads with defaults.

### Step 1.2 - Define Local-First DTO Contracts

**Files**

- Create: `lib/features/messaging/live_chat/data/live_chat_contracts.dart`
- Create or modify tests: `test/live_chat_local_first_contract_test.dart`

**Action**

- Define small helpers or constants for local bridge paths:
  - `GET /local/conversations/:id/messages?before=&after=&limit=`
  - `POST /local/messages/send`
  - `POST /local/messages/attachments/send` if needed for attachment sends.
  - `POST /local/messages/:id/recall` or a compatible local send command.
  - `GET /local/health`
- Define response expectations as Dart parsing helpers if useful:
  - `success: true`
  - `data: List<Map<String, dynamic>>` for messages.
  - `bridgeOffline` or `localOnlyUnavailable` indicators for failure UI.
- Keep existing `ChatMessage.fromJson` compatible with cloud and local shapes.

**Verify**

- Add tests that local path builders preserve `before`, `after`, and `limit`.
- Add tests that message JSON containing `messageType`, `attachments`,
  `zaloMsgId`, and `isDeleted` still parses through `ChatMessage.fromJson`.

### Step 1.3 - Document Builder Boundaries

**Files**

- Modify: `.claude/PROJECT_SUMMARY.md`
- Modify if needed: `README.md`

**Action**

- Record that the current active plan is local-first Live Chat behind feature
  flag. Do not claim it is implemented yet.

**Verify**

- Documentation is current-state only and does not duplicate this SPEC.

## Phase 1 Verification

- `dart format` on touched Dart/test files.
- `flutter test test/live_chat_local_first_contract_test.dart`
- `flutter test`
- `flutter analyze` and report any existing info-level baseline separately.
