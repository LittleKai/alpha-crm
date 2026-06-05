# SPEC Phase 3: Cloud Backend Metadata-Only Compatibility

## Goal

Keep cloud conversation APIs useful for SaaS CRM while stopping new full message
body storage when local-first mode is enabled.

## Dependencies

- Phase 2 should define local metadata payload shape.
- Cloud backend edits are outside this repo and require user-approved escalation.

## Context / Constraints

- Cloud backend path:
  `D:\Dev\NodeJS\alpha-studio\alpha-studio-backend`.
- Current route file:
  `server/routes/crm.js`.
- Current models:
  `server/models/CrmConversation.js`, `server/models/CrmMessage.js`.
- Current helper from previous backend compatibility work:
  `server/utils/crmLiveChat.js`.

## Steps

### Step 3.1 - Add Backend Feature Flag

**Files**

- Modify: `alpha-studio-backend/.env.example`
- Modify: `alpha-studio-backend/server/routes/crm.js`
- Create or modify helper if needed: `alpha-studio-backend/server/utils/crmLiveChat.js`

**Action**

- Add `LOCAL_FIRST_LIVE_CHAT=true` or `CRM_LOCAL_FIRST_LIVE_CHAT=true`.
- Read it centrally near the CRM route/helper code. Do not scatter
  `process.env` lookups through handlers.
- Default must preserve current cloud behavior unless explicitly enabled.

**Verify**

- Existing backend tests pass with flag unset.
- New tests can force flag enabled through helper injection or environment.

### Step 3.2 - Store Metadata-Only Inbound Events

**Files**

- Modify: `alpha-studio-backend/server/routes/crm.js`
- Modify tests or create: `alpha-studio-backend/server/routes/__tests__/crmLocalFirstContract.test.mjs`

**Action**

- In `/crm/agent/events/message`, when local-first flag is enabled:
  - upsert `CrmConversation` with metadata only.
  - do not create a `CrmMessage` containing full `content`.
  - keep enough fields for list/search: `accountId`, `threadId`, `threadType`,
    `displayName`, `avatarUrl`, `lastMessagePreview`, `lastMessageAt`,
    `unreadCount`, `deviceId`, managed-group status.
- Allow `lastMessagePreview` to be short sanitized text or type label. It must
  not contain raw JSON payloads, base64, or full attachments.
- Continue managed-group enforcement for group messages.

**Verify**

- Test asserts `CrmConversation.findOneAndUpdate` path receives metadata.
- Test asserts no `CrmMessage.create` happens in local-first inbound mode.
- Test asserts old behavior remains when flag disabled.

### Step 3.3 - Make Cloud Messages Endpoint Explicitly Non-Authoritative

**Files**

- Modify: `alpha-studio-backend/server/routes/crm.js`
- Update Flutter fallback expectations in Phase 4.

**Action**

- For `/crm/conversations/:id/messages` under local-first flag, choose one:
  - return `{ success: false, code: 'LOCAL_BRIDGE_REQUIRED', message, data: [] }`
    with HTTP 409 or 200-compatible status; or
  - return `{ success: true, code: 'LOCAL_BRIDGE_REQUIRED', data: [] }`.
- Prefer a response that does not break existing Flutter parsing. The Flutter
  phase should treat this as "bridge required/offline", not as fatal corruption.
- Do not return full historical cloud messages in local-first mode unless the
  user explicitly asks for migration backfill.

**Verify**

- Test cloud messages endpoint local-first response shape.
- Existing cloud behavior remains with flag disabled.

### Step 3.4 - Preserve Command Queue For Sends

**Files**

- Modify only if needed: `alpha-studio-backend/server/routes/crm.js`

**Action**

- Keep `/crm/conversations/:id/send` and `send-attachment` command queue
  behavior for fallback/non-local-first mode.
- If Flutter local-first sends directly to bridge, cloud command queue should
  still be available for mobile/offline fallback and campaign flows.
- Do not remove `CrmAgentCommand` usage.

**Verify**

- Existing command executor tests and cloud command result handling remain
  compatible.

## Phase 3 Verification

- `node --test` backend focused tests.
- `node --check server/routes/crm.js`.
- `git diff --check` in backend.
- If no backend build script exists, state that syntax/tests were used instead.
