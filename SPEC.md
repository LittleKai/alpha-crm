# SPEC: Local-First Live Chat Refactor

## Goal

Refactor Alpha CRM Live Chat toward the plan in `.claude/prompt.txt`: local-first
message storage, minimal cloud metadata, and Flutter reads full chat history from
the local Zalo bridge. This SPEC also includes the requested SQLite/sqflite cache
plan so Flutter can reduce repeat API calls and media reloads.

## Phase Index

- `SPEC-phase-1.md` - Local-first architecture foundation and feature flags.
- `SPEC-phase-2.md` - Local Zalo bridge SQLite store and local message APIs.
- `SPEC-phase-3.md` - Cloud backend metadata-only compatibility layer.
- `SPEC-phase-4.md` - Flutter local-first repository and sqflite cache.
- `SPEC-phase-5.md` - Media cache, migration safety, docs, and verification.

## Shared Context / Constraints

- Follow `claude.md`, `.claude/PROJECT_SUMMARY.md`, `.claude/CONVENTIONS.md`,
  and `.claude/prompt.txt`.
- The Flutter app is in this repo. The cloud backend is outside this writable
  root at `D:\Dev\NodeJS\alpha-studio\alpha-studio-backend`; builder must request
  escalation before editing it.
- Do not remove existing cloud message routes in the first pass. Put local-first
  behavior behind `LOCAL_FIRST_LIVE_CHAT=true` and keep fallback paths until the
  full migration is verified.
- Do not store Zalo credentials/cookies/tokens in Flutter. Local bridge remains
  the owner of Zalo sessions and ZCA send/receive operations.
- Cloud should keep only conversation metadata needed by SaaS CRM: identity,
  display, unread, managed-group flag, bridge device/online status, and last
  safe preview.
- Full message body, raw payload, attachment metadata, and media cache metadata
  belong in local bridge storage and Flutter local cache, not cloud.
- Flutter SQLite should use `sqflite_common_ffi` for Windows desktop support.
  If builder needs Android/iOS support too, use the same repository abstraction
  with platform initialization. Web can fall back to in-memory/no-cache unless a
  web SQLite dependency is explicitly added in a later phase.
- Local bridge storage may use SQLite or a light equivalent. Prefer SQLite for
  queryable messages and paging. If choosing a Node SQLite package with native
  binaries, update packaging/release verification so Windows ZIP includes it.
- Keep personal Zalo risk controls and compliance warnings intact.

## Reality Check Performed Before Writing

Verified in this repo:

- `lib/features/messaging/live_chat/data/live_chat_repository.dart` contains
  `LiveChatRepository`, `getConversations`, `getMessages`,
  `clearFailedMessages`, `sendMessage`, `sendAttachment`, and `recallMessage`.
- `lib/features/messaging/live_chat/providers/live_chat_provider.dart` contains
  `LiveChatNotifier`, `loadConversations`, `selectConversation`, `loadMessages`,
  `refreshSelectedMessages`, `loadOlderMessages`, `sendMessage`,
  `sendAttachment`, and `recallMessage`.
- `lib/features/zalo_integration/data/zalo_integration_api.dart` contains
  `ZaloIntegrationApi` and `healthCheck`, and currently targets local bridge
  paths like `/health` and `/api/zalo/status`.
- `lib/shared/api/crm_cloud_api.dart` contains `CrmCloudApi` with fallback
  `https://alpha-studio-backend.fly.dev/api`.
- `lib/features/settings/providers/settings_provider.dart` contains
  `SettingsNotifier`, `_loadSettings`, `_saveSettingsToFile`, and
  `saveSettings`; settings currently persist to `zalo_settings.json`.
- `pubspec.yaml` currently has `path_provider` but no `sqflite`,
  `sqflite_common_ffi`, `cached_network_image`, or `flutter_cache_manager`.

Verified in local bridge:

- `integration/zalo-bot-service/src/server.ts` is a Node HTTP server with
  `/health`, `/api/zalo/status`, `/api/zalo/send-message`, and account/group
  routes.
- `integration/zalo-bot-service/src/agent/agent-runner.ts` installs
  `setInboundMessageHandler` and reports inbound messages through
  `handleInboundMessageEvent`.
- `integration/zalo-bot-service/src/agent/cloud-api.ts` contains
  `reportInboundMessage`, `fetchNextCommand`, `reportCommandResult`, and
  `fetchManagedGroups`.
- `integration/zalo-bot-service/package.json` currently depends on `proxy-agent`
  and `zca-js`; it has no database dependency.

Verified in cloud backend:

- `alpha-studio-backend/server/routes/crm.js` has
  `/crm/conversations`, `/crm/conversations/:id/messages`,
  `/crm/conversations/:id/send`, `/crm/conversations/:id/send-attachment`, and
  `/crm/agent/events/message`.
- `alpha-studio-backend/server/models/CrmMessage.js` currently stores full
  message content and attachments. This must be reduced only under the
  local-first migration path.
- `alpha-studio-backend/server/models/CrmConversation.js` already stores many
  metadata fields needed for a lightweight conversation list.

## Open Architecture Decisions For Builder

- Mobile local bridge access: default `127.0.0.1` works for Windows desktop
  only. For Android/mobile, builder should keep fallback behavior and expose
  configurable `localBridgeBaseUrl`; LAN pairing can be a later phase if not
  already available.
- Node SQLite package choice: if `better-sqlite3` or `sqlite3` is used, verify
  Windows packaging. If packaging risk is unacceptable, choose a light embedded
  store with SQLite-like repository API and document the tradeoff.
- Cloud message retention: do not delete existing historical `CrmMessage`
  documents automatically. This SPEC only prevents new full message storage when
  local-first mode is enabled and leaves archival cleanup as a separate explicit
  migration.

## Handoff

Builder should execute the phases sequentially. Each phase has its own files,
steps, and verification. Stop after any phase if verification fails or if a
cloud/backend permission boundary blocks progress.
