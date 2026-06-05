# SPEC Phase 2: Local Zalo Bridge SQLite Store And Local APIs

## Goal

Make the local Zalo bridge the owner of full Live Chat message history. Inbound
messages are written locally first, then only metadata is synced to cloud.

## Dependencies

- Requires Phase 1 contracts and feature flags.
- Does not require Flutter to consume local APIs yet.

## Context / Constraints

- Local bridge is under `integration/zalo-bot-service/`.
- Current server is HTTP-only in `src/server.ts`.
- Current inbound path is `setInboundMessageHandler(...)` in
  `src/agent/agent-runner.ts`, then `reportInboundMessage(...)` in
  `src/agent/cloud-api.ts`.
- Current send execution path is in `src/agent/command-executor.ts` and
  `src/zalo.ts`.

## Steps

### Step 2.1 - Choose And Add Local Store Dependency

**Files**

- Modify: `integration/zalo-bot-service/package.json`
- Modify: `integration/zalo-bot-service/package-lock.json`
- Modify if packaging affected: release packaging docs/scripts outside this repo
  only with user approval.

**Action**

- Add a local DB dependency.
- Preferred: SQLite with a small repository API. If using native packages
  (`better-sqlite3`, `sqlite3`), verify Windows packaging. If choosing a
  non-native equivalent, keep the module name/contract generic so it can later
  swap to SQLite.
- Add `.env.example` values:
  - `LOCAL_FIRST_LIVE_CHAT=true`
  - `LOCAL_CHAT_DB_PATH=.data/live-chat/live-chat.sqlite`

**Verify**

- `npm.cmd install` updates lockfile.
- `npm.cmd run build` still compiles.

### Step 2.2 - Create Local Chat Store

**Files**

- Create: `integration/zalo-bot-service/src/local-chat/local-chat-store.ts`
- Create: `integration/zalo-bot-service/src/local-chat/local-chat-types.ts`
- Create tests: `integration/zalo-bot-service/src/local-chat/local-chat-store.test.ts`

**Action**

- Create tables/collections:
  - `conversations`: `id`, `accountId`, `threadId`, `threadType`,
    `displayName`, `avatarUrl`, `lastMessagePreview`, `lastMessageAt`,
    `unreadCount`, `managedGroup`, `cloudConversationId`, `createdAt`,
    `updatedAt`.
  - `messages`: `id`, `conversationId`, `accountId`, `threadId`,
    `threadType`, `direction`, `senderId`, `senderName`, `content`,
    `messageType`, `providerMessageId`, `zaloMsgId`, `status`, `isDeleted`,
    `receivedAt`, `sentAt`, `createdAt`, `updatedAt`.
  - `attachments`: `id`, `messageId`, `kind`, `name`, `url`, `localPath`,
    `mimeType`, `sizeBytes`, `metadataJson`, `createdAt`.
  - `sync_state`: `key`, `value`, `updatedAt`.
- Add idempotent upsert by `(accountId, providerMessageId)` when available.
- Add message paging methods using `before`, `after`, and `limit`.
- Store raw payload only if needed for rendering, and keep it local only.

**Verify**

- Tests cover:
  - inbound upsert creates conversation and message.
  - duplicate provider message does not duplicate rows.
  - paging with `before` and `after` returns stable chronological order.
  - attachments persist and load with the message.

### Step 2.3 - Persist Inbound Messages Before Cloud Sync

**Files**

- Modify: `integration/zalo-bot-service/src/agent/agent-runner.ts`
- Modify: `integration/zalo-bot-service/src/agent/cloud-api.ts`
- Modify tests around inbound handling if existing or create focused tests.

**Action**

- In `handleInboundMessageEvent`, write full message to local store before
  calling cloud.
- Change the cloud report payload in local-first mode to metadata-only:
  - `accountId`, `threadId`, `threadType`, `displayName`, `avatarUrl`,
    `lastMessagePreview`, `lastMessageAt`, `unreadCountDelta`,
    `messageType`, `bridgeDeviceId`, and provider ids.
  - Do not include full `content`, full `attachments`, raw payload, or media
    base64.
- If local DB write fails, do not report full message to cloud as fallback.
  Return/log a local persistence failure so data ownership remains correct.

**Verify**

- Tests assert local store is called before cloud report.
- Tests assert cloud payload omits full message body under local-first mode.
- `npm.cmd run build` passes.

### Step 2.4 - Add Local Message APIs

**Files**

- Modify: `integration/zalo-bot-service/src/server.ts`
- Create: `integration/zalo-bot-service/src/local-chat/local-chat-api.ts` if
  route handlers would make `server.ts` too large.
- Add tests for API handlers where feasible.

**Action**

- Add:
  - `GET /local/health`
  - `GET /local/conversations/:id/messages?before=&after=&limit=`
  - `POST /local/messages/send`
  - `POST /local/messages/attachments/send` if attachment payload differs from
    text.
  - `POST /local/messages/:id/recall` if recall needs direct local route.
- `GET /local/health` returns DB status, local-first enabled state, and current
  Zalo status.
- `GET /local/conversations/:id/messages` reads from local store by cloud
  conversation id or local id. If id mapping is missing, support account/thread
  query fallback.
- `POST /local/messages/send` persists an outbound queued message locally, sends
  through ZCA/local channel, then updates message status and provider id.
- Keep existing `/api/zalo/send-message` for older screens/tests.

**Verify**

- API tests or node smoke tests cover:
  - health success.
  - message paging.
  - send rejects empty text and no attachments.
  - send delegates to existing ZCA send path.
- `node --test` focused bridge tests pass.

## Phase 2 Verification

- `npm.cmd run build` in `integration/zalo-bot-service`.
- `node --test` for new local-chat tests and existing bridge tests.
- Manual smoke:
  - start local bridge.
  - call `GET http://127.0.0.1:8787/local/health`.
  - call local messages endpoint with an empty DB and confirm safe empty list.
