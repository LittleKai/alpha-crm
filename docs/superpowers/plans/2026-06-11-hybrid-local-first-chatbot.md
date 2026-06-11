# Hybrid Local-First Chatbot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild CRM chatbot execution so inbound Zalo messages are evaluated and answered by the local bridge, while cloud CRM remains the configuration, AI, quota, and audit authority.

**Architecture:** The local Node bridge persists inbound messages first, debounces each conversation for three seconds, evaluates cached audience/handoff/rule state, and calls the cloud only when AI generation is required. Successful replies are sent directly through `zca-js`, persisted locally, emitted over SSE, and audited idempotently to the cloud. Flutter manages configuration and per-conversation state through explicit local bridge APIs; the cloud never independently sends chatbot replies.

**Tech Stack:** Flutter/Dart, Provider, Node.js/TypeScript, Express, SQLite, Mongoose/MongoDB, `node:test`, Flutter test.

---

## Execution Notes

- The Flutter/local bridge repository is `D:\Dev\NodeJS\alpha-studio\tools\alpha-crm`.
- The cloud backend repository is `D:\Dev\NodeJS\alpha-studio\alpha-studio-backend`.
- Backend edits require write approval because that repository is outside the current writable workspace.
- Preserve all unrelated dirty-worktree changes.
- Run every task test before its implementation, confirm the expected failure, implement the minimum behavior, then rerun it.
- Use `git -c safe.directory='D:/Dev/NodeJS/alpha-studio/tools/alpha-crm' ...` for alpha-crm Git commands.

## Task 1: Extract Shared Cloud Chatbot Contracts

**Files:**
- Create: `D:\Dev\NodeJS\alpha-studio\alpha-studio-backend\server\utils\crmChatbot.js`
- Create: `D:\Dev\NodeJS\alpha-studio\alpha-studio-backend\server\utils\__tests__\crmChatbot.test.mjs`
- Modify: `D:\Dev\NodeJS\alpha-studio\alpha-studio-backend\server\routes\crm.js`

- [ ] **Step 1: Write failing tests for normalized config and deterministic decisions**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildChatbotConfigSnapshot,
  hasHandoffKeyword,
  matchChatbotRule,
} from '../crmChatbot.js';

test('handoff matching ignores Vietnamese accents and case', () => {
  assert.equal(
    hasHandoffKeyword('Tôi muốn GẶP NHÂN VIÊN', ['gap nhan vien']),
    true,
  );
});

test('rule matching returns highest-priority active rule in business hours', () => {
  const result = matchChatbotRule({
    content: 'Báo giá sản phẩm',
    now: new Date('2026-06-11T03:00:00.000Z'),
    rules: [
      { id: 'low', keywords: ['bao gia'], priority: 1, response: 'low' },
      { id: 'high', keywords: ['báo giá'], priority: 10, response: 'high' },
    ],
  });
  assert.equal(result.id, 'high');
});

test('snapshot exposes only the local runtime contract', () => {
  const snapshot = buildChatbotConfigSnapshot({
    settings: { enabled: true, personalAudience: 'crmOnly' },
    rules: [],
    crmThreadKeys: ['acc-1:user-1'],
    selectedGroupKeys: [],
    version: 'v1',
  });
  assert.deepEqual(snapshot.scope.crmThreadKeys, ['acc-1:user-1']);
  assert.equal(snapshot.settings.enabled, true);
});
```

- [ ] **Step 2: Run the test and confirm it fails because the utility does not exist**

Run:

```powershell
node --test server/utils/__tests__/crmChatbot.test.mjs
```

Expected: module-not-found failure for `server/utils/crmChatbot.js`.

- [ ] **Step 3: Implement pure utility functions**

Implement and export:

```js
export function normalizeVietnamese(value) {
  return String(value ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase()
    .trim();
}

export function hasHandoffKeyword(content, keywords) {
  const normalized = normalizeVietnamese(content);
  return keywords.some((keyword) =>
    normalized.includes(normalizeVietnamese(keyword)),
  );
}
```

Move/refactor the existing rule matching and business-hours logic from `crm.js` into the utility. Keep route behavior unchanged at this stage.

- [ ] **Step 4: Run utility and existing route contract tests**

Run:

```powershell
node --test server/utils/__tests__/crmChatbot.test.mjs server/routes/__tests__/crmLocalFirstContract.test.mjs server/routes/__tests__/crmLiveChatContract.test.mjs
```

Expected: all tests pass.

- [ ] **Step 5: Commit the backend extraction**

```powershell
git add server/utils/crmChatbot.js server/utils/__tests__/crmChatbot.test.mjs server/routes/crm.js
git commit -m "refactor: extract CRM chatbot contracts"
```

## Task 2: Add Cloud Agent Config, AI, and Audit Endpoints

**Files:**
- Modify: `D:\Dev\NodeJS\alpha-studio\alpha-studio-backend\server\routes\crm.js`
- Modify: `D:\Dev\NodeJS\alpha-studio\alpha-studio-backend\server\models\CrmChatbotLog.js`
- Create: `D:\Dev\NodeJS\alpha-studio\alpha-studio-backend\server\routes\__tests__\crmChatbotAgentContract.test.mjs`
- Modify: `D:\Dev\NodeJS\alpha-studio\alpha-studio-backend\server\routes\__tests__\crmLocalFirstContract.test.mjs`

- [ ] **Step 1: Write failing contract tests**

Cover these requirements:

```js
test('agent exposes config, generate, and audit routes', () => {
  assert.match(source, /router\.get\(['"]\/agent\/chatbot\/config/);
  assert.match(source, /router\.post\(['"]\/agent\/chatbot\/generate/);
  assert.match(source, /router\.post\(['"]\/agent\/chatbot\/audit/);
});

test('local-first metadata reports do not require message content', () => {
  assert.match(source, /event\.localFirst/);
  assert.match(source, /lastMessagePreview/);
});

test('audit uses an idempotency key', () => {
  assert.match(logModelSource, /idempotencyKey/);
});
```

Also assert that `/agent/events/message` does not call AI generation or send a Zalo reply.

- [ ] **Step 2: Run the contract tests and confirm route/model failures**

Run:

```powershell
node --test server/routes/__tests__/crmChatbotAgentContract.test.mjs server/routes/__tests__/crmLocalFirstContract.test.mjs
```

Expected: missing agent chatbot routes and `idempotencyKey`.

- [ ] **Step 3: Extend the chatbot log model**

Add:

```js
idempotencyKey: {
  type: String,
  trim: true,
},
accountId: {
  type: String,
  trim: true,
},
threadId: {
  type: String,
  trim: true,
},
```

Create a partial unique index scoped by tenant:

```js
schema.index(
  { tenantId: 1, idempotencyKey: 1 },
  {
    unique: true,
    partialFilterExpression: { idempotencyKey: { $type: 'string' } },
  },
);
```

- [ ] **Step 4: Implement `GET /agent/chatbot/config`**

Return a versioned snapshot:

```json
{
  "version": "settings-and-rules-updatedAt-hash",
  "settings": {
    "enabled": true,
    "personalAudience": "crmOnly",
    "groupAudience": "tagOnly",
    "handoffKeywords": [],
    "aiEnabled": true,
    "selectedGroupKeys": []
  },
  "rules": [],
  "scope": {
    "crmThreadKeys": [],
    "selectedGroupKeys": []
  }
}
```

Use agent authentication and tenant/account scoping already established by the CRM agent routes. Include only enabled rules and the fields needed by local evaluation.

- [ ] **Step 5: Implement `POST /agent/chatbot/generate`**

Request contract:

```json
{
  "accountId": "account",
  "threadId": "thread",
  "conversationKey": "account:thread",
  "messages": [
    { "id": "provider-id", "content": "customer message", "timestamp": 0 }
  ],
  "history": []
}
```

Behavior:

- Resolve tenant subscription from the authenticated agent.
- Reuse the current CRM AI quota and provider path.
- Return `{ "reply": "...", "usage": {...} }` on success.
- Return typed errors such as `AI_DISABLED`, `QUOTA_EXCEEDED`, or `AI_UNAVAILABLE`.
- Never send the reply to Zalo from the cloud.

- [ ] **Step 6: Implement `POST /agent/chatbot/audit`**

Use an upsert keyed by `{ tenantId, idempotencyKey }`. Accept `matched`, `ai`, `handoff`, `skipped`, and `failed` outcomes, with bounded message previews and error metadata. A duplicate request must return the existing log without creating a second document.

- [ ] **Step 7: Fix local-first metadata ingestion**

In `upsertConversationFromInbound`, branch explicitly:

```js
if (event.localFirst === true) {
  requireFields(event, ['accountId', 'threadId']);
  return updateConversationMetadata({
    preview: event.lastMessagePreview ?? '',
    timestamp: event.lastMessageAt ?? event.timestamp,
  });
}
```

Do not create a cloud message record for metadata-only events. Preserve the existing full-message path for non-local-first agents.

- [ ] **Step 8: Run backend chatbot tests**

Run:

```powershell
node --test server/utils/__tests__/crmChatbot.test.mjs server/routes/__tests__/crmChatbotAgentContract.test.mjs server/routes/__tests__/crmLocalFirstContract.test.mjs server/routes/__tests__/crmLiveChatContract.test.mjs
```

Expected: all pass.

- [ ] **Step 9: Commit cloud agent APIs**

```powershell
git add server/routes/crm.js server/models/CrmChatbotLog.js server/routes/__tests__/crmChatbotAgentContract.test.mjs server/routes/__tests__/crmLocalFirstContract.test.mjs
git commit -m "feat: add CRM chatbot agent APIs"
```

## Task 3: Add Local Chatbot State and Config Persistence

**Files:**
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-types.ts`
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-store.ts`
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-store.test.ts`
- Modify: `integration/zalo-bot-service/src/local-chat/local-chat-store.ts`
- Modify: `integration/zalo-bot-service/src/local-chat/local-chat-types.ts`

- [ ] **Step 1: Write failing store tests**

Test:

- A new personal conversation inherits global audience state.
- Explicit `enabled`, `handoff`, and `disabled_by_operator` state survives restart.
- Config snapshot replacement is atomic and versioned.
- Audit queue rejects duplicate idempotency keys.
- Processed provider message IDs are remembered.

Representative assertion:

```ts
assert.deepEqual(store.getConversationState('acc:user'), {
  mode: 'disabled_by_operator',
  reason: 'manual_operator_reply',
  inherited: false,
});
```

- [ ] **Step 2: Run the focused test and confirm missing module failure**

Run:

```powershell
npm.cmd run build
node --test dist/chatbot/chatbot-store.test.js
```

Expected: TypeScript/module failure because the chatbot store does not exist.

- [ ] **Step 3: Add SQLite migrations**

Add tables through the existing `_migrate()` path:

```sql
CREATE TABLE IF NOT EXISTS chatbot_conversation_state (
  conversation_key TEXT PRIMARY KEY,
  mode TEXT NOT NULL,
  reason TEXT,
  inherited INTEGER NOT NULL DEFAULT 1,
  updated_at INTEGER NOT NULL,
  last_processed_message_id TEXT
);

CREATE TABLE IF NOT EXISTS chatbot_config_snapshot (
  singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
  version TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  synced_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS chatbot_audit_queue (
  idempotency_key TEXT PRIMARY KEY,
  payload_json TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  last_error TEXT
);
```

Keep schema ownership in `local-chat-store.ts`; expose typed operations through `ChatbotStore`.

- [ ] **Step 4: Implement typed state rules**

Define:

```ts
export type ChatbotConversationMode =
  | 'enabled'
  | 'handoff'
  | 'disabled_by_operator';

export interface ChatbotConfigSnapshot {
  version: string;
  settings: ChatbotSettings;
  rules: ChatbotRule[];
  scope: {
    crmThreadKeys: string[];
    selectedGroupKeys: string[];
  };
}
```

Store timestamps in milliseconds and JSON-parse through validation helpers, not unchecked casts.

- [ ] **Step 5: Run store tests**

Run:

```powershell
npm.cmd run build
node --test dist/chatbot/chatbot-store.test.js dist/local-chat/local-chat-store.test.js
```

Expected: all pass.

- [ ] **Step 6: Commit local persistence**

```powershell
git add integration/zalo-bot-service/src/chatbot integration/zalo-bot-service/src/local-chat/local-chat-store.ts integration/zalo-bot-service/src/local-chat/local-chat-types.ts
git commit -m "feat: persist local chatbot state"
```

## Task 4: Build the Local Cloud Client and Config Synchronizer

**Files:**
- Modify: `integration/zalo-bot-service/src/agent/cloud-api.ts`
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-cloud-api.ts`
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-cloud-api.test.ts`
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-config-sync.ts`
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-config-sync.test.ts`

- [ ] **Step 1: Write failing client tests**

Test exact methods:

```ts
await api.fetchConfig();
await api.generateReply(request);
await api.postAudit(record);
```

Assert agent headers, timeouts, JSON validation, typed cloud errors, and no retry for AI generation.

- [ ] **Step 2: Run focused tests and confirm failure**

Run:

```powershell
npm.cmd run build
node --test dist/chatbot/chatbot-cloud-api.test.js dist/chatbot/chatbot-config-sync.test.js
```

Expected: missing modules.

- [ ] **Step 3: Implement cloud client**

Wrap `callCloudApi` instead of duplicating authentication. Validate response shapes before returning them. Generation must make one request only; config and audit sync may use bounded retry/backoff.

- [ ] **Step 4: Implement config synchronizer**

Required operations:

```ts
start(): void;
stop(): void;
syncNow(): Promise<ChatbotConfigSnapshot>;
getStatus(): ChatbotSyncStatus;
```

On startup, use the cached snapshot immediately, then refresh in the background. An unavailable cloud must not delete the last valid snapshot.

- [ ] **Step 5: Correct the metadata report payload**

Ensure `reportInboundMessageMetadata` sends:

```ts
{
  localFirst: true,
  accountId,
  threadId,
  lastMessagePreview,
  lastMessageAt,
}
```

Do not add full message content to metadata-only cloud reports.

- [ ] **Step 6: Run client and existing cloud API tests**

Run:

```powershell
npm.cmd run build
node --test dist/chatbot/chatbot-cloud-api.test.js dist/chatbot/chatbot-config-sync.test.js dist/agent/cloud-api.test.js
```

Expected: all pass.

- [ ] **Step 7: Commit cloud synchronization**

```powershell
git add integration/zalo-bot-service/src/agent/cloud-api.ts integration/zalo-bot-service/src/chatbot
git commit -m "feat: sync chatbot config with local bridge"
```

## Task 5: Implement the Local Chatbot Decision Engine

**Files:**
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-engine.ts`
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-engine.test.ts`
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-text.ts`
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-debounce.ts`
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-debounce.test.ts`

- [ ] **Step 1: Write failing eligibility and decision tests**

Cover:

- Global disabled.
- Explicit conversation disabled.
- `personalAudience`: `all`, `crmOnly`, `none`.
- `groupAudience`: `none`, `tagOnly`, `selected`.
- Group must be managed and mention the bot or quote a bot message.
- Self messages, history sync, and duplicate provider IDs are skipped.
- Handoff keywords ignore case and Vietnamese accents.
- Active rule priority and business hours.
- No rule plus AI disabled produces `skipped`, not a reply.
- AI error produces `failed` and transitions to `handoff`.
- Chatbot output is text-only.

Example:

```ts
const result = await engine.evaluate({
  conversationKey: 'acc:user',
  messages: [
    message('m1', 'bao'),
    message('m2', 'gia san pham'),
  ],
});

assert.deepEqual(result, {
  kind: 'reply',
  mode: 'keyword',
  text: '...',
  sourceMessageIds: ['m1', 'm2'],
});
```

- [ ] **Step 2: Write failing debounce tests with a fake clock**

Verify:

- Messages within three seconds are combined in order.
- A later message resets the timer.
- Different conversations flush independently.
- `stop()` cancels pending work.
- The buffer has a bounded message count and character size.

- [ ] **Step 3: Run focused tests and confirm failures**

Run:

```powershell
npm.cmd run build
node --test dist/chatbot/chatbot-engine.test.js dist/chatbot/chatbot-debounce.test.js
```

Expected: missing engine/debounce modules.

- [ ] **Step 4: Implement normalization and eligibility**

Use a shared local normalizer:

```ts
export function normalizeVietnamese(input: string): string {
  return input
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase()
    .trim();
}
```

Keep pure eligibility functions separate from I/O so all audience and group rules can be unit tested.

- [ ] **Step 5: Implement deterministic decision order**

Use exactly:

1. Reject self/history/duplicate/non-text events.
2. Check global, audience, group, and conversation state.
3. Check handoff keywords.
4. Match active keyword rules by priority.
5. Call cloud AI only when AI is enabled and no rule matched.
6. On AI/cloud/quota failure, create a failed result and enter handoff.

- [ ] **Step 6: Implement three-second per-conversation debounce**

Use one timer and bounded buffer per conversation key. Expose `push(event)`, `flush(key)`, and `stop()`. Do not use global sleeps.

- [ ] **Step 7: Run engine tests**

Run:

```powershell
npm.cmd run build
node --test dist/chatbot/chatbot-engine.test.js dist/chatbot/chatbot-debounce.test.js
```

Expected: all pass.

- [ ] **Step 8: Commit the decision engine**

```powershell
git add integration/zalo-bot-service/src/chatbot
git commit -m "feat: add local chatbot decision engine"
```

## Task 6: Dispatch Replies and Wire Inbound Processing

**Files:**
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-dispatcher.ts`
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-dispatcher.test.ts`
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-runtime.ts`
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-runtime.test.ts`
- Modify: `integration/zalo-bot-service/src/agent/agent-runner.ts`
- Modify: `integration/zalo-bot-service/src/local-session/session-runtime.ts`
- Modify: `integration/zalo-bot-service/src/local-chat/local-chat-events.ts`
- Modify: `integration/zalo-bot-service/src/local-chat/local-chat-api.ts`

- [ ] **Step 1: Write failing dispatcher tests**

Verify a successful reply:

- Calls `sendTyping` optionally, then `sendMessage` once.
- Persists an outbound local message with `metadata.source = 'chatbot'`.
- Publishes the normal local message SSE event.
- Marks source message IDs processed.
- Queues/posts one audit record with a deterministic idempotency key.

Verify send failure:

- Does not persist a successful outbound message.
- Produces a failed audit.
- Transitions conversation to handoff.
- Does not retry automatically.

- [ ] **Step 2: Write failing runtime wiring tests**

Assert:

- `handleInboundMessageEvent` persists and publishes before enqueueing chatbot evaluation.
- History batch ingestion never invokes the chatbot.
- Runtime startup starts config sync and chatbot runtime.
- Runtime shutdown stops debounce timers and sync loops.

- [ ] **Step 3: Run focused tests and confirm failures**

Run:

```powershell
npm.cmd run build
node --test dist/chatbot/chatbot-dispatcher.test.js dist/chatbot/chatbot-runtime.test.js
```

Expected: missing runtime/dispatcher and wiring assertions.

- [ ] **Step 4: Implement dispatcher**

Use dependency injection for Zalo send functions, store, event publisher, and audit API. Generate:

```ts
const idempotencyKey =
  `${conversationKey}:${sourceMessageIds.join(',')}:${decisionMode}`;
```

Persist the provider message ID returned by `sendMessage`.

- [ ] **Step 5: Wire live inbound events**

After the existing local upsert and SSE publication, enqueue only newly inserted live inbound messages:

```ts
if (result.inserted && event.source !== 'history') {
  chatbotRuntime.accept(event);
}
```

Keep n8n dispatch behavior intact.

- [ ] **Step 6: Implement operator takeover**

In `/local/messages/send`, accept:

```json
{ "origin": "operator" }
```

After and only after a successful manual send:

```ts
chatbotStore.setConversationState(key, {
  mode: 'disabled_by_operator',
  reason: 'manual_operator_reply',
  inherited: false,
});
```

Chatbot-origin sends must use the dispatcher directly and must never invoke this manual takeover path.

- [ ] **Step 7: Start and stop chatbot runtime with the Zalo session**

Initialize only after Zalo and the local store are ready. Stop all timers before stopping the session runner.

- [ ] **Step 8: Run local service tests**

Run:

```powershell
npm.cmd test
```

Expected: all local Node tests pass.

- [ ] **Step 9: Commit runtime integration**

```powershell
git add integration/zalo-bot-service/src
git commit -m "feat: execute chatbot replies through local Zalo session"
```

## Task 7: Expose Local Chatbot Management APIs

**Files:**
- Modify: `integration/zalo-bot-service/src/local-chat/local-chat-api.ts`
- Modify: `integration/zalo-bot-service/src/local-chat/local-chat-types.ts`
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-local-api.test.ts`

- [ ] **Step 1: Write failing local API tests**

Cover:

```text
GET  /local/chatbot/status
POST /local/chatbot/sync
GET  /local/conversations/:conversationKey/chatbot
PUT  /local/conversations/:conversationKey/chatbot
```

Expected state update body:

```json
{
  "mode": "enabled",
  "reason": "operator_reenabled"
}
```

Reject unknown modes and malformed conversation keys with `400`.

- [ ] **Step 2: Run the API test and confirm 404 failures**

Run:

```powershell
npm.cmd run build
node --test dist/chatbot/chatbot-local-api.test.js
```

Expected: routes return not found.

- [ ] **Step 3: Implement status and sync routes**

Status response includes:

```json
{
  "running": true,
  "configVersion": "v1",
  "lastSyncedAt": 0,
  "lastError": null,
  "pendingAudits": 0
}
```

`POST /local/chatbot/sync` performs an immediate cloud refresh and returns the updated status.

- [ ] **Step 4: Implement per-conversation state routes**

Return both effective and explicit state:

```json
{
  "conversationKey": "account:thread",
  "mode": "enabled",
  "reason": "operator_reenabled",
  "inherited": false,
  "effectiveEnabled": true
}
```

Publish `conversation.chatbot_state` after a successful update.

- [ ] **Step 5: Run local API and full local tests**

Run:

```powershell
npm.cmd test
```

Expected: all pass.

- [ ] **Step 6: Commit local management APIs**

```powershell
git add integration/zalo-bot-service/src
git commit -m "feat: expose local chatbot management APIs"
```

## Task 8: Add Flutter Local Bridge Clients

**Files:**
- Create: `lib/features/messaging/chatbot/data/chatbot_local_bridge_api.dart`
- Create: `test/chatbot_local_bridge_api_test.dart`
- Modify: `lib/features/messaging/live_chat/data/live_chat_local_bridge_api.dart`
- Modify: `lib/features/messaging/live_chat/data/live_chat_repository.dart`
- Modify: `test/live_chat_repository_test.dart`

- [ ] **Step 1: Write failing API client tests**

Test:

- Decode chatbot status.
- Trigger immediate config sync.
- Read and update conversation chatbot state.
- Manual local send includes `"origin": "operator"`.
- Non-2xx and malformed JSON become typed repository failures.

- [ ] **Step 2: Run Flutter tests and confirm missing API behavior**

Run:

```powershell
flutter test test/chatbot_local_bridge_api_test.dart test/live_chat_repository_test.dart
```

Expected: missing class/method or assertion failures.

- [ ] **Step 3: Implement chatbot bridge models and API**

Define immutable models:

```dart
class ChatbotBridgeStatus {
  final bool running;
  final String? configVersion;
  final DateTime? lastSyncedAt;
  final String? lastError;
  final int pendingAudits;
}

enum ConversationChatbotMode {
  enabled,
  handoff,
  disabledByOperator,
}
```

Use the same local bridge base URL and timeout/error conventions as live chat.

- [ ] **Step 4: Route live-chat chatbot updates locally in local-first mode**

Add a dedicated repository method:

```dart
Future<ConversationChatbotState> updateChatbotState(
  LiveChatConversation conversation,
  ConversationChatbotMode mode,
);
```

Do not send local chatbot toggles through the generic cloud conversation update path.

- [ ] **Step 5: Mark manual sends explicitly**

Update the local bridge request body:

```dart
{
  'conversationId': conversationId,
  'content': content,
  'origin': 'operator',
}
```

- [ ] **Step 6: Run focused Flutter tests**

Run:

```powershell
flutter test test/chatbot_local_bridge_api_test.dart test/live_chat_repository_test.dart
```

Expected: all pass.

- [ ] **Step 7: Commit Flutter data integration**

```powershell
git add lib/features/messaging/chatbot/data lib/features/messaging/live_chat/data test/chatbot_local_bridge_api_test.dart test/live_chat_repository_test.dart
git commit -m "feat: connect Flutter to local chatbot APIs"
```

## Task 9: Synchronize Flutter Chatbot Configuration

**Files:**
- Modify: `lib/features/messaging/chatbot/providers/chatbot_provider.dart`
- Modify: `lib/features/messaging/chatbot/presentation/screens/chatbot_screen.dart`
- Modify: `lib/features/messaging/chatbot/data/chatbot_repository.dart`
- Modify: `test/chatbot_provider_test.dart`

- [ ] **Step 1: Write failing provider tests**

Verify:

- Initial load also reads bridge status.
- Successful settings/rule mutations trigger immediate bridge sync.
- Cloud save remains successful if bridge sync fails, while exposing a warning state.
- Retry sync updates status without resaving cloud configuration.
- Selected group keys round-trip through settings.

- [ ] **Step 2: Run provider tests and confirm failures**

Run:

```powershell
flutter test test/chatbot_provider_test.dart
```

Expected: missing bridge status/sync behavior.

- [ ] **Step 3: Extend settings contract for selected groups**

Add `selectedGroupKeys` with an empty-list default to Dart settings, cloud serialization, and backend settings normalization. The cloud config snapshot must return this same field.

- [ ] **Step 4: Add provider sync state**

Expose:

```dart
ChatbotBridgeStatus? bridgeStatus;
bool isSyncingBridge;
String? bridgeSyncWarning;

Future<void> syncBridgeNow();
```

After a successful cloud mutation, call `syncBridgeNow()`. Do not roll back the cloud mutation when the local bridge is temporarily offline.

- [ ] **Step 5: Add runtime status UI**

Near the chatbot configuration header, show:

- `Đang hoạt động` when runtime and config sync are healthy.
- `Chưa đồng bộ` when cloud data saved but bridge refresh failed.
- `Bridge ngoại tuyến` when local runtime is unavailable.
- A retry action that calls `syncBridgeNow()`.

When `groupAudience == selected`, show a managed-group selector and persist `selectedGroupKeys`.

- [ ] **Step 6: Run provider tests and static analysis**

Run:

```powershell
flutter test test/chatbot_provider_test.dart
flutter analyze
```

Expected: tests pass; no new analyzer errors.

- [ ] **Step 7: Commit configuration synchronization**

```powershell
git add lib/features/messaging/chatbot test/chatbot_provider_test.dart
git commit -m "feat: synchronize chatbot settings with local runtime"
```

## Task 10: Show and Control Conversation Chatbot State

**Files:**
- Modify: `lib/features/messaging/live_chat/domain/live_chat_models.dart`
- Modify: `lib/features/messaging/live_chat/providers/live_chat_provider.dart`
- Modify: `lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`
- Modify: `test/live_chat_provider_test.dart`

- [ ] **Step 1: Write failing provider tests**

Verify:

- Toggle on writes explicit `enabled`.
- Toggle off writes `disabled_by_operator` with an operator reason.
- Manual-send completion refreshes local conversation chatbot state.
- SSE `conversation.chatbot_state` updates the visible conversation.
- `handoff` and manual takeover are distinguishable in the model.

- [ ] **Step 2: Run provider tests and confirm failures**

Run:

```powershell
flutter test test/live_chat_provider_test.dart
```

Expected: current boolean-only model cannot represent the required states.

- [ ] **Step 3: Extend conversation state**

Add:

```dart
final ConversationChatbotMode chatbotMode;
final String? chatbotStateReason;
final bool chatbotStateInherited;
```

Keep `chatbotEnabled` as a derived compatibility getter if existing UI/tests depend on it.

- [ ] **Step 4: Update provider behavior**

Replace generic `updateConversation(chatbotEnabled: ...)` calls with `updateChatbotState`. Refresh after manual local send, and handle the new SSE event without reloading the full inbox.

- [ ] **Step 5: Update live-chat UI**

The toggle reflects effective state. Add concise state text:

- `Chatbot đang bật`
- `Đã bàn giao cho nhân viên`
- `Tắt sau phản hồi thủ công`

Re-enabling clears handoff/manual takeover by writing explicit `enabled`.

- [ ] **Step 6: Run live-chat tests**

Run:

```powershell
flutter test test/live_chat_provider_test.dart test/live_chat_repository_test.dart
```

Expected: all pass.

- [ ] **Step 7: Commit conversation state UI**

```powershell
git add lib/features/messaging/live_chat test/live_chat_provider_test.dart test/live_chat_repository_test.dart
git commit -m "feat: manage chatbot state per conversation"
```

## Task 11: Add End-to-End Contract Coverage

**Files:**
- Create: `integration/zalo-bot-service/src/chatbot/chatbot-integration.test.ts`
- Modify: `test/chatbot_provider_test.dart`
- Modify: `test/live_chat_provider_test.dart`
- Modify: `D:\Dev\NodeJS\alpha-studio\alpha-studio-backend\server\routes\__tests__\crmChatbotAgentContract.test.mjs`

- [ ] **Step 1: Write failing local integration tests**

Use fakes for cloud and Zalo, with real temporary SQLite storage:

1. Receive two live messages in one conversation.
2. Advance fake time by three seconds.
3. Match a keyword rule.
4. Send one combined reply.
5. Persist and emit the reply.
6. Create one audit record.
7. Replay the same provider messages and confirm no second reply.

Add separate scenarios for AI success, AI failure/handoff, managed-group mention, and operator takeover.

- [ ] **Step 2: Run integration tests and fix only contract gaps**

Run:

```powershell
npm.cmd run build
node --test dist/chatbot/chatbot-integration.test.js
```

Expected before final fixes: failures reveal mismatched wiring or state contracts, not missing core components.

- [ ] **Step 3: Add cloud/Flutter contract assertions**

Assert field names and enum values are identical across:

- Cloud config/audit payloads.
- Local TypeScript types.
- Flutter JSON models.

Prefer fixture payloads in tests over string-source checks where modules can be imported safely.

- [ ] **Step 4: Run all focused cross-layer tests**

Run:

```powershell
npm.cmd test
flutter test test/chatbot_local_bridge_api_test.dart test/chatbot_provider_test.dart test/live_chat_repository_test.dart test/live_chat_provider_test.dart
```

Backend:

```powershell
node --test server/utils/__tests__/crmChatbot.test.mjs server/routes/__tests__/crmChatbotAgentContract.test.mjs server/routes/__tests__/crmLocalFirstContract.test.mjs server/routes/__tests__/crmLiveChatContract.test.mjs
```

Expected: all pass.

- [ ] **Step 5: Commit integration coverage**

```powershell
git add integration/zalo-bot-service/src/chatbot test
git commit -m "test: cover hybrid chatbot workflow"
```

## Task 12: Update Project Documentation

**Files:**
- Modify: `.claude/PROJECT_SUMMARY.md`
- Modify: `.claude/IMPORTANT_FIXED_BUGS.md`
- Modify: `README.md`
- Modify: `D:\Dev\NodeJS\alpha-studio\alpha-studio-backend\.claude\PROJECT_SUMMARY.md`
- Modify: `D:\Dev\NodeJS\alpha-studio\alpha-studio-backend\.claude\DATABASE.md`

- [ ] **Step 1: Document the runtime ownership boundary**

State clearly:

- Local bridge owns debounce, eligibility, rule execution, Zalo send, local persistence, and SSE.
- Cloud owns settings, rules, CRM scope, AI/quota, and audit.
- Cloud inbound metadata ingestion never executes chatbot replies.
- Manual operator send disables the bot for that conversation until explicitly re-enabled.

- [ ] **Step 2: Document local tables and cloud log fields**

Include migration fields, state enum values, config snapshot lifecycle, audit idempotency key, and retention/bounds.

- [ ] **Step 3: Document operational troubleshooting**

Add checks for:

- Bridge runtime status.
- Last config sync error.
- Pending audit count.
- AI quota/provider error.
- Conversation handoff/manual takeover reason.

- [ ] **Step 4: Review docs against implementation**

Search for stale claims that the cloud `/agent/events/message` endpoint runs the bot or that the chatbot toggle is cloud-only.

- [ ] **Step 5: Commit documentation**

Alpha CRM:

```powershell
git add .claude/PROJECT_SUMMARY.md .claude/IMPORTANT_FIXED_BUGS.md README.md
git commit -m "docs: document hybrid chatbot runtime"
```

Backend:

```powershell
git add .claude/PROJECT_SUMMARY.md .claude/DATABASE.md
git commit -m "docs: document chatbot agent contracts"
```

## Task 13: Final Verification

- [ ] **Step 1: Run the full local Node suite**

From `integration/zalo-bot-service`:

```powershell
npm.cmd test
```

Expected: exit code `0`.

- [ ] **Step 2: Run the full Flutter suite**

From alpha-crm:

```powershell
flutter test
```

Expected: exit code `0`.

- [ ] **Step 3: Run Flutter static analysis**

```powershell
flutter analyze
```

Expected: no new errors. Record any pre-existing warnings separately.

- [ ] **Step 4: Run backend CRM tests**

From `alpha-studio-backend`:

```powershell
node --test server/utils/__tests__/crmChatbot.test.mjs server/routes/__tests__/crmChatbotAgentContract.test.mjs server/routes/__tests__/crmLocalFirstContract.test.mjs server/routes/__tests__/crmLiveChatContract.test.mjs
```

Expected: exit code `0`.

- [ ] **Step 5: Perform a manual local-first smoke test**

Use a test Zalo account:

1. Enable global chatbot and sync the bridge.
2. Send two rapid personal messages matching a keyword rule.
3. Confirm one reply after approximately three seconds.
4. Send a non-rule message with AI enabled and confirm one AI reply.
5. Trigger a handoff keyword and confirm no chatbot reply.
6. Re-enable the conversation from Live Chat.
7. Send an operator reply and confirm the bot becomes `disabled_by_operator`.
8. In a managed group, confirm replies occur only on mention/quote and according to group audience.
9. Stop cloud connectivity and confirm cached keyword rules still work while AI enters handoff without fallback.

- [ ] **Step 6: Inspect final diffs and repository status**

```powershell
git -c safe.directory='D:/Dev/NodeJS/alpha-studio/tools/alpha-crm' diff --check
git -c safe.directory='D:/Dev/NodeJS/alpha-studio/tools/alpha-crm' status --short
```

Review the backend repository separately. Confirm no unrelated user changes were reverted or committed.

