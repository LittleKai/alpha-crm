# Alpha CRM Single-PC Session Refactor Design

**Date:** 2026-06-06
**Status:** Approved design
**Scope:** Alpha CRM Flutter app, local `zalo-bot-service`, and the minimum Alpha Studio cloud API changes required for an end-to-end strict one-PC policy.

## 1. Goal

Replace manual CRM device registration with an automatic SaaS login flow:

- A Windows user signs in with Alpha CRM email and password.
- Flutter synchronizes the cloud JWT and user ID to the local Node bridge.
- The local bridge automatically registers and starts the Windows agent.
- One Alpha CRM account can have only one active Windows PC.
- A user may explicitly replace the old PC when signing in on a new PC.
- The replaced PC stops all agent activity and returns Flutter to the login screen.
- Replacing a PC must not delete Zalo credentials, SQLite chat data, account settings, or message history.

Mobile QR pairing remains supported as a remote-control relationship. Disconnecting a mobile remote must never disable the Windows agent.

## 2. Non-Goals

- Replacing the existing REST cloud API with WebSocket infrastructure.
- Removing mobile QR pairing.
- Deleting local Zalo accounts, SQLite databases, settings, logs, or message history after a PC is replaced.
- Allowing simultaneous active Windows PCs for one CRM user.
- Reworking unrelated CRM, billing, Live Chat, or campaign behavior.

## 3. Architectural Decisions

### Project structure

Keep the existing feature-first Flutter structure and the current Node agent modules. Add a focused local session/auth module instead of placing lifecycle logic directly in `server.ts`.

### API clients

Flutter uses a small typed local HTTP/SSE client for the loopback bridge. Node continues to use REST for the cloud API.

### Authentication

Flutter sends the cloud JWT and expected user ID only to `127.0.0.1`. The local bridge verifies the JWT against the cloud `/auth/me` endpoint and rejects a user ID mismatch before device registration.

### Real-time behavior

Cloud-to-agent revocation uses the existing heartbeat and command polling channels. Node-to-Flutter notification uses local Server-Sent Events because communication is one-way and SSE reconnects automatically.

### Error handling

Cloud responses include stable machine-readable error codes. Network failures use retry/backoff and never trigger logout. Only an explicit `DEVICE_REVOKED` response triggers local session revocation.

## 4. Components

### Flutter

Add a Windows-only local session client responsible for:

- `POST /local/auth/sync`
- Optional `forceReplace: true` retry after user confirmation
- Connecting to `GET /local/events`
- Mapping local errors to typed outcomes

`CrmAuthNotifier` remains the owner of CRM authentication state. After successful cloud authentication it synchronizes the local agent session on Windows. A `409 DEVICE_ALREADY_ACTIVE` result opens the project's custom dialog. A `session.revoked` event deletes the Flutter CRM token, resets auth state, and lets GoRouter redirect to `/login`.

Mobile does not expose email/password login as part of this refactor. Its QR pairing flow remains a remote-control flow.

### Local Node bridge

Add a session coordinator with these responsibilities:

- Validate `/local/auth/sync` payloads.
- Verify cloud token ownership.
- Register or replace the active device.
- Persist the active JWT and agent credentials.
- Start, stop, and restart the agent runner idempotently.
- Publish local SSE events.
- Revoke only CRM session credentials when the cloud rejects the device.

The coordinator must not delete:

- Zalo credential files
- Local chat SQLite files
- Zalo account settings
- Integration settings
- Message or conversation history

On revocation it deletes only:

- Flutter `crm_token.json`
- Node `.data/agent/device-secret.json`

It also stops Zalo listeners, command/campaign execution, heartbeat, polling, local background sync, and health-monitor timers.

### Cloud API

The cloud remains the authority for the active Windows device.

Required behavior:

- Device registration returns `409` with code `DEVICE_ALREADY_ACTIVE` when another PC is active.
- The conflict response includes only safe display metadata for the old PC.
- A force-replace endpoint atomically marks the old device `replaced` and creates or activates the new device.
- Agent authentication for a replaced device returns `403` with code `DEVICE_REVOKED`.
- The database invariant continues to allow only one active device per subscription/user.

The force-replace operation must run in a MongoDB transaction or an equivalent atomic sequence compatible with the existing transaction helper.

## 5. API Contracts

### `POST /local/auth/sync`

Request:

```json
{
  "token": "<cloud-jwt>",
  "userId": "<cloud-user-id>",
  "forceReplace": false
}
```

Success:

```json
{
  "success": true,
  "data": {
    "deviceId": "<device-id>",
    "status": "active"
  }
}
```

Conflict:

```json
{
  "success": false,
  "code": "DEVICE_ALREADY_ACTIVE",
  "message": "Tài khoản đang được sử dụng trên một máy tính khác.",
  "data": {
    "device": {
      "displayName": "Windows x64 (PC-A)",
      "lastSeenAt": "2026-06-06T00:00:00.000Z"
    }
  }
}
```

The endpoint is bound to loopback and accepts JSON only. It must validate body size and required string fields.

### `GET /local/events`

SSE event:

```text
event: session.revoked
data: {"code":"DEVICE_REVOKED","reason":"replaced_by_new_pc"}
```

The bridge sends periodic SSE keepalive comments and removes disconnected clients.

### Cloud force replacement

The local bridge calls:

```text
POST /api/crm/devices/force-logout-old
Authorization: Bearer <cloud-jwt>
```

Body:

```json
{
  "machineFingerprint": "<fingerprint>",
  "displayName": "<display-name>",
  "platform": "windows",
  "appVersion": "<app-version>",
  "agentVersion": "<agent-version>"
}
```

The response returns the new device ID and agent secret once.

## 6. Runtime Flows

### Normal Windows login

1. Flutter authenticates against the cloud.
2. Flutter reads the authenticated cloud user ID.
3. Flutter calls local `/local/auth/sync`.
4. Node verifies token ownership through `/auth/me`.
5. Node registers the device.
6. Node stores credentials and starts agent services.
7. Flutter completes login navigation.

### Device conflict

1. Cloud registration returns `409 DEVICE_ALREADY_ACTIVE`.
2. Node forwards the typed conflict to Flutter.
3. Flutter displays a custom confirmation dialog.
4. Cancellation keeps the new PC logged out and does not alter the old PC.
5. Confirmation repeats local sync with `forceReplace: true`.
6. Cloud atomically replaces the active device.
7. New Node credentials are stored and the new agent starts.

### Old PC revocation

1. The old agent heartbeat or command poll receives `403 DEVICE_REVOKED`.
2. The agent cancellation signal prevents further campaign recipients from being processed.
3. All agent, listener, sync, polling, heartbeat, and health timers stop.
4. CRM JWT and agent credentials are deleted.
5. Zalo credentials, SQLite data, settings, and history remain intact.
6. Node emits `session.revoked` through local SSE.
7. Flutter clears auth state and GoRouter redirects to `/login`.

### Sleep and wake recovery

A health monitor tracks timer drift and Zalo listener state. Large timer drift indicates sleep/wake. If the session is still authorized but listeners are offline, it performs a single guarded listener restart with exponential backoff. It must not create duplicate listeners or overlapping recovery attempts.

## 7. Lifecycle and Cancellation

Agent lifecycle operations are idempotent:

- Calling start while active is a no-op.
- Calling stop more than once is safe.
- Starting after credential replacement uses only the new credentials.
- All timer handles are owned by their module and cleared during stop.
- File watchers are also stopped during revocation.

Long-running campaign execution receives a shared cancellation signal. The executor checks it before each external Zalo action and before reporting further progress. Revocation must stop new sends; an already-issued external request cannot be recalled.

## 8. Security

- Local auth endpoints bind only to `127.0.0.1`.
- CORS remains restricted to trusted local Flutter origins.
- JWT values, agent secrets, and Zalo credentials are never logged or returned from health endpoints.
- `/local/auth/sync` verifies cloud identity before accepting `userId`.
- Force replacement requires a valid user JWT and an active CRM subscription.
- Conflict metadata excludes secrets, fingerprints, IP addresses, and internal hashes.
- Agent auth distinguishes revoked credentials from transient cloud/network errors.

## 9. Testing

### Local Node tests

- Reject missing/invalid sync fields.
- Reject JWT/user ID mismatch.
- Return typed conflict without starting duplicate loops.
- Start and stop lifecycle idempotently.
- Clear every timer and watcher on revocation.
- Delete only CRM JWT and agent credential files.
- Preserve SQLite, Zalo credentials, and settings.
- Emit `session.revoked` to SSE clients.
- Recover a stopped listener once after simulated sleep/wake.

### Cloud backend tests

- First PC registers successfully.
- Second PC receives `409 DEVICE_ALREADY_ACTIVE`.
- Force replacement leaves exactly one active device.
- Old agent credentials receive `403 DEVICE_REVOKED`.
- Failed replacement transaction does not leave zero or two active devices.
- Conflict responses expose only approved metadata.

### Flutter tests

- Successful login synchronizes the local agent before entering the app.
- Conflict opens the custom confirmation dialog.
- Cancel keeps the new PC logged out.
- Confirm retries with `forceReplace: true`.
- SSE revocation clears auth state and redirects to login.
- Mobile retains QR pairing and does not use Windows local auth sync.

### Verification commands

```text
integration/zalo-bot-service: npm run build and Node tests
alpha-studio-backend: focused CRM route/model tests and build/start checks
alpha-crm: flutter analyze and flutter test
```

## 10. Documentation and Migration

- Remove `crm:register-device` and `src/agent/register-device.ts`.
- Update local bridge README and environment examples.
- Update Alpha CRM project summary, conventions if contracts change, and important bug notes only when a high-impact regression is fixed.
- Update cloud backend project summary and database/API documentation.
- Correct the refactor plan so replaced-PC behavior no longer claims that SQLite or Zalo data is deleted.
- Keep existing device and pairing records compatible; QR pairing continues to use the active Windows device.

## 11. Acceptance Criteria

- A Windows user can activate the local agent by signing in without terminal commands.
- A second PC cannot become active without explicit confirmation.
- Confirming replacement results in exactly one active PC.
- The old PC stops sending and returns to login after receiving explicit revocation.
- Revocation removes only CRM JWT and agent credentials.
- Zalo credentials, SQLite, settings, and history survive replacement.
- Mobile QR remote pairing still works and mobile disconnect cannot disable the Windows agent.
- Sleep/wake recovery does not create duplicate listeners or polling spam.
