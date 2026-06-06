# Alpha CRM Single-PC Session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace manual Windows device registration with automatic Flutter-to-local-agent activation, strict one-active-PC enforcement, explicit PC replacement, and non-destructive revocation.

**Architecture:** The cloud backend remains the authority for the active Windows device and exposes typed conflict/revocation responses. The local Node bridge coordinates token verification, device activation, agent lifecycle, SSE events, and credential cleanup. Flutter owns confirmation UX and authentication navigation through Riverpod and GoRouter.

**Tech Stack:** Node.js 18+, Express 5, Mongoose transactions, TypeScript, native `node:test`, Flutter 3, Dart, Riverpod, GoRouter, `package:http`.

---

## File Map

### Alpha Studio cloud backend

- Create `alpha-studio-backend/server/utils/crmDeviceSessions.js`: atomic device activation/replacement domain service.
- Create `alpha-studio-backend/server/utils/crmDeviceSessions.test.js`: transaction and metadata tests.
- Modify `alpha-studio-backend/server/routes/crm.js`: typed registration conflict, force-replace route, typed revoked-agent response.
- Create `alpha-studio-backend/server/routes/__tests__/crmDeviceSessionContract.test.mjs`: route contract regression checks.
- Modify `alpha-studio-backend/.claude/PROJECT_SUMMARY.md`: current single-PC API behavior.
- Modify `alpha-studio-backend/.claude/DATABASE.md`: active-device invariant and replacement status.

### Local `zalo-bot-service`

- Create `tools/alpha-crm/integration/zalo-bot-service/src/local-session/session-events.ts`: local SSE event hub.
- Create `tools/alpha-crm/integration/zalo-bot-service/src/local-session/session-coordinator.ts`: sync/logout/revocation orchestration.
- Create `tools/alpha-crm/integration/zalo-bot-service/src/local-session/session-coordinator.test.ts`: local session behavior tests.
- Create `tools/alpha-crm/integration/zalo-bot-service/src/agent/listener-health-monitor.ts`: sleep/wake and listener recovery.
- Create `tools/alpha-crm/integration/zalo-bot-service/src/agent/listener-health-monitor.test.ts`: timer drift/recovery tests.
- Modify `tools/alpha-crm/integration/zalo-bot-service/src/agent/cloud-api.ts`: typed cloud errors, token verification, replacement API, device disable.
- Modify `tools/alpha-crm/integration/zalo-bot-service/src/agent/agent-identity.ts`: credential `userId`, atomic writes, credential/token deletion.
- Modify `tools/alpha-crm/integration/zalo-bot-service/src/agent/agent-runner.ts`: explicit credentials, idempotent lifecycle, revocation callback, timer/watcher cleanup.
- Modify `tools/alpha-crm/integration/zalo-bot-service/src/agent/command-executor.ts`: global campaign cancellation signal.
- Modify `tools/alpha-crm/integration/zalo-bot-service/src/zalo.ts`: explicit listener stop/recovery helpers.
- Modify `tools/alpha-crm/integration/zalo-bot-service/src/server.ts`: local auth and SSE endpoints, lifecycle wiring, graceful shutdown.
- Modify `tools/alpha-crm/integration/zalo-bot-service/src/local-chat/sync-worker.ts`: lifecycle status and full stop semantics.
- Modify `tools/alpha-crm/integration/zalo-bot-service/package.json`: remove manual registration script and add Node test script.
- Delete `tools/alpha-crm/integration/zalo-bot-service/src/agent/register-device.ts`.
- Modify `tools/alpha-crm/integration/zalo-bot-service/README.md`: automatic activation and local endpoints.

### Flutter Alpha CRM

- Create `tools/alpha-crm/lib/features/auth/data/local_agent_session_client.dart`: loopback sync/logout/SSE client.
- Create `tools/alpha-crm/lib/features/auth/models/crm_login_result.dart`: typed login outcomes.
- Modify `tools/alpha-crm/lib/features/auth/providers/crm_auth_provider.dart`: Windows sync, conflict retry, SSE subscription, revocation logout.
- Modify `tools/alpha-crm/lib/features/auth/presentation/screens/crm_login_screen.dart`: custom replacement confirmation dialog.
- Modify `tools/alpha-crm/lib/shared/auth/crm_auth_token_store.dart`: expose platform-safe token cleanup only through existing abstraction.
- Create `tools/alpha-crm/test/local_agent_session_client_test.dart`: HTTP/SSE parsing tests.
- Create `tools/alpha-crm/test/crm_auth_provider_single_pc_test.dart`: provider state and revocation tests.
- Create `tools/alpha-crm/test/crm_login_screen_single_pc_test.dart`: dialog and retry widget tests.

### Shared docs

- Modify `ALPHA_CRM_REFACTOR_PLAN.md`: remove destructive SQLite/Zalo cleanup language.
- Modify `tools/alpha-crm/.claude/PROJECT_SUMMARY.md`: current architecture and status.
- Modify `tools/alpha-crm/.claude/IMPORTANT_FIXED_BUGS.md` only if implementation reveals a high-impact recurring failure.

---

### Task 1: Add Atomic Cloud Device Session Service

**Files:**
- Create: `alpha-studio-backend/server/utils/crmDeviceSessions.js`
- Create: `alpha-studio-backend/server/utils/crmDeviceSessions.test.js`

- [ ] **Step 1: Write failing tests for conflict metadata and atomic replacement**

Create tests with injected Mongoose/model fakes:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildActiveDeviceConflict,
  replaceActiveDevice,
} from './crmDeviceSessions.js';

test('buildActiveDeviceConflict exposes only safe device metadata', () => {
  const result = buildActiveDeviceConflict({
    displayName: 'Windows x64 (PC-A)',
    lastSeenAt: new Date('2026-06-06T00:00:00.000Z'),
    agentSecretHash: 'secret',
    machineFingerprintHash: 'fingerprint',
    lastIp: '127.0.0.1',
  });

  assert.deepEqual(result, {
    displayName: 'Windows x64 (PC-A)',
    lastSeenAt: new Date('2026-06-06T00:00:00.000Z'),
  });
});

test('replaceActiveDevice replaces old device and creates one active device in one transaction', async () => {
  const calls = [];
  const session = {
    async withTransaction(fn) {
      calls.push('withTransaction');
      return fn();
    },
    async endSession() {
      calls.push('endSession');
    },
  };
  const oldDevice = {
    _id: 'old-device',
    status: 'active',
    async save(options) {
      calls.push(['old.save', options.session]);
    },
  };
  const createdDevice = { _id: 'new-device' };
  const models = {
    CrmDevice: {
      async findOne() {
        return oldDevice;
      },
      async create(docs, options) {
        calls.push(['create', docs[0].status, options.session]);
        return [createdDevice];
      },
    },
    CrmAuditLog: {
      async create(docs, options) {
        calls.push(['audit', docs[0].action, options.session]);
      },
    },
  };

  const result = await replaceActiveDevice({
    mongooseClient: { async startSession() { return session; } },
    models,
    userId: 'user-1',
    subscriptionId: 'sub-1',
    deviceInput: {
      machineFingerprintHash: 'hash',
      displayName: 'PC-B',
      platform: 'windows',
      agentSecretHash: 'secret-hash',
    },
  });

  assert.equal(result.device._id, 'new-device');
  assert.equal(oldDevice.status, 'replaced');
  assert.ok(calls.includes('withTransaction'));
  assert.deepEqual(calls.at(-1), 'endSession');
});
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```powershell
node --test server/utils/crmDeviceSessions.test.js
```

Expected: FAIL because `crmDeviceSessions.js` does not exist.

- [ ] **Step 3: Implement the domain service**

Implement:

```js
import crypto from 'crypto';
import mongoose from 'mongoose';
import CrmDevice from '../models/CrmDevice.js';
import CrmAuditLog from '../models/CrmAuditLog.js';

export function buildActiveDeviceConflict(device) {
  return {
    displayName: device.displayName,
    lastSeenAt: device.lastSeenAt,
  };
}

export function createAgentSecret() {
  const value = crypto.randomBytes(32).toString('hex');
  return {
    value,
    hash: crypto.createHash('sha256').update(value).digest('hex'),
  };
}

export async function replaceActiveDevice({
  mongooseClient = mongoose,
  models = { CrmDevice, CrmAuditLog },
  userId,
  subscriptionId,
  deviceInput,
}) {
  const session = await mongooseClient.startSession();
  try {
    return await session.withTransaction(async () => {
      const activeDeviceQuery = models.CrmDevice.findOne({
        subscriptionId,
        status: 'active',
      });
      const oldDevice = typeof activeDeviceQuery.session === 'function'
        ? await activeDeviceQuery.session(session)
        : await activeDeviceQuery;

      if (oldDevice) {
        oldDevice.status = 'replaced';
        oldDevice.replacedAt = new Date();
        await oldDevice.save({ session });
      }

      const [device] = await models.CrmDevice.create([{
        userId,
        subscriptionId,
        ...deviceInput,
        status: 'active',
      }], { session });

      await models.CrmAuditLog.create([{
        userId,
        subscriptionId,
        deviceId: device._id,
        action: 'device_replaced',
        details: { replacedDeviceId: oldDevice?._id ?? null },
      }], { session });

      return { device, replacedDevice: oldDevice };
    });
  } finally {
    await session.endSession();
  }
}
```

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```powershell
node --test server/utils/crmDeviceSessions.test.js
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add server/utils/crmDeviceSessions.js server/utils/crmDeviceSessions.test.js
git commit -m "feat(crm): add atomic device replacement service"
```

---

### Task 2: Expose Typed Cloud Registration and Revocation Contracts

**Files:**
- Modify: `alpha-studio-backend/server/routes/crm.js`
- Create: `alpha-studio-backend/server/routes/__tests__/crmDeviceSessionContract.test.mjs`

- [ ] **Step 1: Write failing route contract tests**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const source = fs.readFileSync(
  new URL('../crm.js', import.meta.url),
  'utf8',
);

test('device registration returns typed active-device conflict', () => {
  assert.match(source, /DEVICE_ALREADY_ACTIVE/);
  assert.match(source, /buildActiveDeviceConflict/);
  assert.match(source, /status\(409\)/);
});

test('agent authentication returns typed revoked-device response', () => {
  assert.match(source, /DEVICE_REVOKED/);
  assert.match(source, /status\(403\)/);
});

test('force logout old route uses atomic replacement service', () => {
  assert.match(source, /devices\/force-logout-old/);
  assert.match(source, /replaceActiveDevice/);
});
```

- [ ] **Step 2: Run the contract tests and verify RED**

Run:

```powershell
node --test server/routes/__tests__/crmDeviceSessionContract.test.mjs
```

Expected: FAIL because typed codes and force-replace route are absent.

- [ ] **Step 3: Modify `agentAuthMiddleware`**

Return stable error payloads:

```js
if (!device) {
  return res.status(403).json({
    success: false,
    code: 'DEVICE_REVOKED',
    message: 'Thiết bị không còn là phiên Alpha CRM đang hoạt động.',
  });
}

if (device.agentSecretHash !== incomingSecretHash) {
  return res.status(403).json({
    success: false,
    code: 'INVALID_AGENT_CREDENTIALS',
    message: 'Thông tin xác thực thiết bị không hợp lệ.',
  });
}
```

- [ ] **Step 4: Modify normal registration conflict**

Find the active device before creating a new one and return:

```js
return res.status(409).json({
  success: false,
  code: 'DEVICE_ALREADY_ACTIVE',
  message: 'Tài khoản đang được sử dụng trên một máy tính khác.',
  data: {
    device: buildActiveDeviceConflict(activeDevice),
  },
});
```

If the active device has the same fingerprint, still return conflict unless the local bridge already has matching valid agent credentials. Do not issue a new agent secret from the registration route.

- [ ] **Step 5: Add `POST /devices/force-logout-old`**

Validate the same input as registration, create a new secret, call `replaceActiveDevice`, and return the new secret once:

```js
router.post(
  '/devices/force-logout-old',
  crmDeviceLimiter,
  authMiddleware,
  requireActiveSubscription,
  async (req, res) => {
    const { machineFingerprint, displayName, platform, appVersion, agentVersion } = req.body;
    if (!machineFingerprint || !displayName) {
      return res.status(400).json({
        success: false,
        code: 'INVALID_DEVICE_INPUT',
        message: 'Thiếu thông tin nhận diện máy tính.',
      });
    }

    const secret = createAgentSecret();
    const result = await replaceActiveDevice({
      userId: req.user._id,
      subscriptionId: req.crmSubscription._id,
      deviceInput: {
        machineFingerprintHash: crypto
          .createHash('sha256')
          .update(machineFingerprint)
          .digest('hex'),
        displayName,
        platform: platform || 'windows',
        appVersion: appVersion || '',
        agentVersion: agentVersion || '',
        agentSecretHash: secret.hash,
        lastIp: req.ip,
      },
    });

    return res.json({
      success: true,
      data: {
        deviceId: result.device._id,
        agentSecret: secret.value,
      },
    });
  },
);
```

- [ ] **Step 6: Run focused cloud tests**

Run:

```powershell
node --test server/utils/crmDeviceSessions.test.js server/routes/__tests__/crmDeviceSessionContract.test.mjs
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add server/routes/crm.js server/routes/__tests__/crmDeviceSessionContract.test.mjs
git commit -m "feat(crm): enforce typed single-PC device sessions"
```

---

### Task 3: Add Typed Local Cloud API and Credential Cleanup

**Files:**
- Modify: `tools/alpha-crm/integration/zalo-bot-service/src/agent/cloud-api.ts`
- Modify: `tools/alpha-crm/integration/zalo-bot-service/src/agent/agent-identity.ts`
- Create: `tools/alpha-crm/integration/zalo-bot-service/src/agent/agent-identity.test.ts`

- [ ] **Step 1: Write failing credential persistence/cleanup tests**

Use a temporary credential path by extracting path-based helpers:

```ts
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, existsSync, writeFileSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import {
  readAgentCredentialsFile,
  writeAgentCredentialsFile,
  deleteFileIfPresent,
} from './agent-identity.js';

test('agent credentials persist userId with device secret', () => {
  const dir = mkdtempSync(join(tmpdir(), 'alpha-crm-agent-'));
  const path = join(dir, 'device-secret.json');

  writeAgentCredentialsFile(path, {
    userId: 'user-1',
    deviceId: 'device-1',
    agentSecret: 'secret-1',
  });

  assert.deepEqual(readAgentCredentialsFile(path), {
    userId: 'user-1',
    deviceId: 'device-1',
    agentSecret: 'secret-1',
  });
});

test('deleteFileIfPresent deletes only the requested file', () => {
  const dir = mkdtempSync(join(tmpdir(), 'alpha-crm-agent-'));
  const target = join(dir, 'device-secret.json');
  const preserved = join(dir, 'live-chat.sqlite');
  writeFileSync(target, '{}');
  writeFileSync(preserved, 'keep');

  deleteFileIfPresent(target);

  assert.equal(existsSync(target), false);
  assert.equal(readFileSync(preserved, 'utf8'), 'keep');
});
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
npm run build
node --test dist/agent/agent-identity.test.js
```

Expected: build/test FAIL because the helper APIs do not exist.

- [ ] **Step 3: Implement credential helpers**

Change `AgentCredentials` to:

```ts
export interface AgentCredentials {
  userId: string;
  deviceId: string;
  agentSecret: string;
}
```

Add:

```ts
export function writeAgentCredentialsFile(
  path: string,
  credentials: AgentCredentials,
): void {
  fs.mkdirSync(dirname(path), { recursive: true });
  const tempPath = `${path}.tmp`;
  fs.writeFileSync(tempPath, JSON.stringify(credentials, null, 2), 'utf8');
  fs.renameSync(tempPath, path);
}

export function readAgentCredentialsFile(path: string): AgentCredentials | null {
  if (!fs.existsSync(path)) return null;
  const parsed = JSON.parse(fs.readFileSync(path, 'utf8'));
  if (!parsed.userId || !parsed.deviceId || !parsed.agentSecret) return null;
  return parsed;
}

export function deleteFileIfPresent(path: string): void {
  if (fs.existsSync(path)) fs.unlinkSync(path);
}

export function deleteAgentCredentials(): void {
  deleteFileIfPresent(resolve(projectRoot, config.crmAgentSecretPath));
}

export function deleteCrmToken(): void {
  const path = getCrmTokenPath();
  if (path) deleteFileIfPresent(path);
}
```

Update `saveAgentCredentials(userId, deviceId, agentSecret)` and all callers.

- [ ] **Step 4: Add typed cloud errors and methods**

Implement:

```ts
export class CloudApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly code: string | null,
    readonly data: unknown = null,
  ) {
    super(message);
  }
}

export function isDeviceRevokedError(error: unknown): boolean {
  return error instanceof CloudApiError &&
    error.status === 403 &&
    error.code === 'DEVICE_REVOKED';
}

export async function verifyCloudIdentity(userJwt: string): Promise<{ userId: string }> {
  const data = await callCloudApi('/auth/me', {
    method: 'GET',
    headers: { Authorization: `Bearer ${userJwt}` },
  });
  const user = data.user ?? data;
  return { userId: String(user._id ?? user.id ?? '') };
}

export async function forceReplaceDevice(
  userJwt: string,
  displayName: string,
  machineFingerprint: string,
): Promise<{ deviceId: string; agentSecret: string }> {
  return callCloudApi('/crm/devices/force-logout-old', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${userJwt}`,
    },
    body: JSON.stringify({
      machineFingerprint,
      displayName,
      platform: 'windows',
      agentVersion: '0.2.0',
    }),
  });
}

export async function disableDevice(
  userJwt: string,
  deviceId: string,
): Promise<void> {
  await callCloudApi(`/crm/devices/${deviceId}/disable`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${userJwt}`,
    },
    body: '{}',
  });
}
```

Make `callCloudApi` throw `CloudApiError` using HTTP status, `body.code`, `body.message`, and `body.data`.

- [ ] **Step 5: Run build and tests**

Run:

```powershell
npm run build
node --test dist/agent/agent-identity.test.js
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add src/agent/cloud-api.ts src/agent/agent-identity.ts src/agent/agent-identity.test.ts
git commit -m "feat(crm-agent): add typed cloud session credentials"
```

---

### Task 4: Build the Local Session Coordinator and SSE Hub

**Files:**
- Create: `tools/alpha-crm/integration/zalo-bot-service/src/local-session/session-events.ts`
- Create: `tools/alpha-crm/integration/zalo-bot-service/src/local-session/session-coordinator.ts`
- Create: `tools/alpha-crm/integration/zalo-bot-service/src/local-session/session-coordinator.test.ts`

- [ ] **Step 1: Write failing coordinator tests**

Define dependencies so tests use real coordinator behavior without network/filesystem globals:

```ts
import test from 'node:test';
import assert from 'node:assert/strict';
import { SessionCoordinator } from './session-coordinator.js';
import { CloudApiError } from '../agent/cloud-api.js';

test('sync rejects cloud user mismatch', async () => {
  const coordinator = new SessionCoordinator({
    verifyIdentity: async () => ({ userId: 'cloud-user' }),
  } as any);

  await assert.rejects(
    coordinator.sync({
      token: 'jwt',
      userId: 'different-user',
      forceReplace: false,
    }),
    /không khớp/,
  );
});

test('sync returns typed conflict without starting agent', async () => {
  let starts = 0;
  const coordinator = new SessionCoordinator({
    verifyIdentity: async () => ({ userId: 'user-1' }),
    getCredentials: () => null,
    register: async () => {
      throw new CloudApiError(
        'active',
        409,
        'DEVICE_ALREADY_ACTIVE',
        { device: { displayName: 'PC-A' } },
      );
    },
    startAgent: () => { starts += 1; },
  } as any);

  const result = await coordinator.sync({
    token: 'jwt',
    userId: 'user-1',
    forceReplace: false,
  });

  assert.equal(result.kind, 'conflict');
  assert.equal(starts, 0);
});

test('revoke stops services and deletes only CRM session credentials', async () => {
  const calls = [];
  const coordinator = new SessionCoordinator({
    stopAgent: () => calls.push('agent'),
    stopZalo: async () => calls.push('zalo'),
    stopSync: () => calls.push('sync'),
    stopHealthMonitor: () => calls.push('health'),
    cancelCampaigns: () => calls.push('campaigns'),
    deleteCrmToken: () => calls.push('token'),
    deleteAgentCredentials: () => calls.push('credentials'),
    publishEvent: (event) => calls.push(event.type),
  } as any);

  await coordinator.revoke('replaced_by_new_pc');

  assert.deepEqual(calls, [
    'campaigns',
    'agent',
    'sync',
    'health',
    'zalo',
    'token',
    'credentials',
    'session.revoked',
  ]);
});
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
npm run build
node --test dist/local-session/session-coordinator.test.js
```

Expected: FAIL because the coordinator and event hub do not exist.

- [ ] **Step 3: Implement SSE event hub**

```ts
import type { ServerResponse } from 'http';

export interface LocalSessionEvent {
  type: 'session.revoked';
  code: 'DEVICE_REVOKED';
  reason: string;
}

const clients = new Set<ServerResponse>();

export function addSessionEventClient(res: ServerResponse): () => void {
  clients.add(res);
  return () => clients.delete(res);
}

export function publishSessionEvent(event: LocalSessionEvent): void {
  const payload = `event: ${event.type}\ndata: ${JSON.stringify(event)}\n\n`;
  for (const client of clients) client.write(payload);
}

export function writeSessionKeepalive(): void {
  for (const client of clients) client.write(': keepalive\n\n');
}
```

- [ ] **Step 4: Implement coordinator**

Required public API:

```ts
export interface SyncSessionInput {
  token: string;
  userId: string;
  forceReplace: boolean;
}

export type SyncSessionResult =
  | { kind: 'active'; deviceId: string }
  | { kind: 'conflict'; device: { displayName: string; lastSeenAt?: string } };

export class SessionCoordinator {
  constructor(private readonly deps: SessionCoordinatorDependencies) {}

  async sync(input: SyncSessionInput): Promise<SyncSessionResult> {
    // validate strings
    // verify cloud identity and exact userId match
    // reuse credentials only when credentials.userId matches and heartbeat succeeds
    // delete revoked stale credentials and continue to registration
    // call register or forceReplace
    // persist userId/deviceId/agentSecret
    // start agent, sync worker, and health monitor idempotently
    // map only DEVICE_ALREADY_ACTIVE to conflict
  }

  async logout(token: string): Promise<void> {
    // best-effort disable current device with the cloud
    // stop runtime and delete CRM token/agent credential
    // do not publish session.revoked for user-initiated logout
  }

  async revoke(reason: string): Promise<void> {
    // idempotent destructive boundary limited to CRM session credentials
  }
}
```

Use a private `revoking` promise so concurrent heartbeat and poll failures execute cleanup once.

- [ ] **Step 5: Run coordinator tests**

Run:

```powershell
npm run build
node --test dist/local-session/session-coordinator.test.js
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add src/local-session/session-events.ts src/local-session/session-coordinator.ts src/local-session/session-coordinator.test.ts
git commit -m "feat(crm-agent): coordinate local SaaS sessions"
```

---

### Task 5: Make Agent, Campaign, Sync, and Zalo Lifecycles Revocation-Safe

**Files:**
- Modify: `tools/alpha-crm/integration/zalo-bot-service/src/agent/agent-runner.ts`
- Modify: `tools/alpha-crm/integration/zalo-bot-service/src/agent/command-executor.ts`
- Modify: `tools/alpha-crm/integration/zalo-bot-service/src/local-chat/sync-worker.ts`
- Modify: `tools/alpha-crm/integration/zalo-bot-service/src/zalo.ts`
- Create: `tools/alpha-crm/integration/zalo-bot-service/src/agent/listener-health-monitor.ts`
- Create: `tools/alpha-crm/integration/zalo-bot-service/src/agent/listener-health-monitor.test.ts`

- [ ] **Step 1: Write failing health-monitor tests**

```ts
import test from 'node:test';
import assert from 'node:assert/strict';
import { ListenerHealthMonitor } from './listener-health-monitor.js';

test('health monitor restarts listener once after sleep drift', async () => {
  let restarts = 0;
  const monitor = new ListenerHealthMonitor({
    now: () => 80_000,
    intervalMs: 10_000,
    driftThresholdMs: 30_000,
    getStatus: () => ({ connected: true, listenerRunning: false }),
    restartListener: async () => { restarts += 1; },
  });
  monitor.setLastTickForTest(0);

  await monitor.tick();
  await monitor.tick();

  assert.equal(restarts, 1);
});
```

Do not add public production test-only setters. Instead inject initial clock/timer state through constructor options or test the exported pure `shouldRecoverListener` helper.

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
npm run build
node --test dist/agent/listener-health-monitor.test.js
```

Expected: FAIL because the monitor does not exist.

- [ ] **Step 3: Refactor `agent-runner` lifecycle**

Replace file-token auto-registration and watcher ownership with explicit credentials:

```ts
export function startAgentRunner(credentials: AgentCredentials): void;
export function stopAgentRunner(): void;
export function setAgentRevokedHandler(
  handler: ((reason: string) => Promise<void>) | null,
): void;
export function isAgentRunnerActive(): boolean;
```

Requirements:

- Remove `attemptAutoRegistration`, `watchCrmToken`, and retry timers.
- Heartbeat interval becomes 10 seconds.
- Heartbeat and poll catch `isDeviceRevokedError(error)` and invoke the revocation handler once.
- Transient failures retain exponential backoff.
- `stopAgentRunner` clears heartbeat/poll timers and resets backoff/cache state.

- [ ] **Step 4: Add global campaign cancellation**

Add:

```ts
let cancelAllRequested = false;

export function requestCancelAllCampaigns(): void {
  cancelAllRequested = true;
}

export function resetCancelAllCampaigns(): void {
  cancelAllRequested = false;
}
```

Before each recipient send:

```ts
if (cancelAllRequested || cancelledCampaigns.has(campaignId)) {
  // mark remaining local result entries cancelled and do not call Zalo
}
```

Reset cancellation only after a new authenticated session starts, not automatically at the end of the revoked campaign.

- [ ] **Step 5: Harden sync worker and Zalo lifecycle**

Expose:

```ts
export function isBackgroundSyncRunning(): boolean;
export async function stopZaloListeners(): Promise<void>;
export async function recoverZaloListeners(): Promise<void>;
```

`recoverZaloListeners` must use a module-level in-flight promise so concurrent recovery calls share one restart.

- [ ] **Step 6: Implement health monitor**

The monitor:

- Ticks every 15 seconds.
- Treats drift over 45 seconds as sleep/wake.
- Recovers when accounts are connected but no listener is running.
- Uses exponential retry capped at 5 minutes.
- Has idempotent `start()`/`stop()`.
- Never starts if the local CRM session is inactive.

- [ ] **Step 7: Run focused Node tests and build**

Run:

```powershell
npm run build
node --test dist/agent/*.test.js dist/local-session/*.test.js
```

Expected: PASS.

- [ ] **Step 8: Commit**

```powershell
git add src/agent/agent-runner.ts src/agent/command-executor.ts src/agent/listener-health-monitor.ts src/agent/listener-health-monitor.test.ts src/local-chat/sync-worker.ts src/zalo.ts
git commit -m "feat(crm-agent): stop revoked work and recover listeners"
```

---

### Task 6: Add Local Auth/SSE HTTP Endpoints and Remove Manual Registration

**Files:**
- Modify: `tools/alpha-crm/integration/zalo-bot-service/src/server.ts`
- Modify: `tools/alpha-crm/integration/zalo-bot-service/package.json`
- Delete: `tools/alpha-crm/integration/zalo-bot-service/src/agent/register-device.ts`
- Create: `tools/alpha-crm/integration/zalo-bot-service/src/local-session/local-session-api.test.ts`

- [ ] **Step 1: Write failing local route contract tests**

Extract a `handleLocalSessionRoute` function and test it with request/response fakes:

```ts
test('POST /local/auth/sync rejects missing token', async () => {
  const response = await invokeLocalRoute({
    method: 'POST',
    url: '/local/auth/sync',
    body: JSON.stringify({ userId: 'user-1' }),
  });

  assert.equal(response.status, 400);
  assert.equal(response.json.code, 'INVALID_AUTH_SYNC');
});

test('GET /local/events opens an SSE response', async () => {
  const response = await invokeLocalRoute({
    method: 'GET',
    url: '/local/events',
  });

  assert.equal(response.headers['Content-Type'], 'text/event-stream');
});
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
npm run build
node --test dist/local-session/local-session-api.test.js
```

Expected: FAIL because the route handler does not exist.

- [ ] **Step 3: Implement local routes**

Add:

```text
POST /local/auth/sync
POST /local/auth/logout
GET  /local/events
```

Rules:

- Accept requests only when the server is bound to loopback.
- Reject bodies over 64 KiB.
- Return `409` for coordinator conflicts.
- Return stable `{ success, code, message, data }` shapes.
- SSE headers include `Cache-Control: no-cache` and `Connection: keep-alive`.
- Remove SSE clients when `req` closes.

- [ ] **Step 4: Wire startup and shutdown**

At startup:

- Initialize Zalo credentials/listeners.
- Configure the agent revocation callback to call `SessionCoordinator.revoke`.
- Do not start the agent until local auth sync restores/validates a matching session.
- Start SSE keepalive timer.

On `SIGTERM`, `SIGINT`, and server close:

- Stop agent runner.
- Stop health monitor.
- Stop background sync.
- Stop Zalo listeners.
- Close local chat store.
- Clear SSE keepalive timer.

- [ ] **Step 5: Remove manual CLI**

Delete:

```text
src/agent/register-device.ts
```

Remove:

```json
"crm:register-device": "tsc && node dist/agent/register-device.js"
```

Add:

```json
"test": "npm run build && node --test dist"
```

- [ ] **Step 6: Run local bridge verification**

Run:

```powershell
npm run build
npm test
```

Expected: PASS with no TypeScript errors.

- [ ] **Step 7: Commit**

```powershell
git add src/server.ts src/local-session/local-session-api.test.ts package.json
git rm src/agent/register-device.ts
git commit -m "feat(crm-agent): expose local auth session API"
```

---

### Task 7: Add Flutter Local Agent Client and Typed Login Results

**Files:**
- Create: `tools/alpha-crm/lib/features/auth/data/local_agent_session_client.dart`
- Create: `tools/alpha-crm/lib/features/auth/models/crm_login_result.dart`
- Create: `tools/alpha-crm/test/local_agent_session_client_test.dart`

- [ ] **Step 1: Write failing client tests**

Use an injected `http.Client`:

```dart
test('sync maps 409 device conflict to typed result', () async {
  final client = MockClient((request) async {
    expect(request.url.path, '/local/auth/sync');
    return http.Response(
      jsonEncode({
        'success': false,
        'code': 'DEVICE_ALREADY_ACTIVE',
        'data': {
          'device': {'displayName': 'PC-A'}
        }
      }),
      409,
      headers: {'content-type': 'application/json'},
    );
  });

  final api = LocalAgentSessionClient(client: client);
  final result = await api.sync(
    token: 'jwt',
    userId: 'user-1',
  );

  expect(result, isA<LocalAgentConflict>());
  expect((result as LocalAgentConflict).device.displayName, 'PC-A');
});

test('event parser emits session revoked events', () async {
  final events = LocalAgentSessionClient.parseSseLines(
    Stream.fromIterable([
      'event: session.revoked',
      'data: {"code":"DEVICE_REVOKED","reason":"replaced_by_new_pc"}',
      '',
    ]),
  );

  expect(
    await events.first,
    const LocalSessionRevoked(reason: 'replaced_by_new_pc'),
  );
});
```

- [ ] **Step 2: Run test and verify RED**

Run:

```powershell
flutter test test/local_agent_session_client_test.dart
```

Expected: FAIL because client/models do not exist.

- [ ] **Step 3: Implement typed models**

Define:

```dart
sealed class LocalAgentSyncResult {
  const LocalAgentSyncResult();
}

final class LocalAgentActive extends LocalAgentSyncResult {
  final String deviceId;
  const LocalAgentActive(this.deviceId);
}

final class LocalAgentConflict extends LocalAgentSyncResult {
  final ActiveDeviceSummary device;
  const LocalAgentConflict(this.device);
}

final class LocalAgentUnavailable extends LocalAgentSyncResult {
  final String message;
  const LocalAgentUnavailable(this.message);
}

sealed class LocalAgentSessionEvent {
  const LocalAgentSessionEvent();
}

final class LocalSessionRevoked extends LocalAgentSessionEvent {
  final String reason;
  const LocalSessionRevoked({required this.reason});
}
```

- [ ] **Step 4: Implement local client**

Requirements:

- Default base URL `http://127.0.0.1:8787`.
- `sync({token, userId, forceReplace = false})`.
- `logout({required token})`.
- `events()` using `http.Request` + `client.send`.
- Parse SSE line-by-line.
- Treat connection failures as `LocalAgentUnavailable`, not revocation.
- Do not run loopback calls on web, Android, or iOS.

- [ ] **Step 5: Run client tests**

Run:

```powershell
flutter test test/local_agent_session_client_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/features/auth/data/local_agent_session_client.dart lib/features/auth/models/crm_login_result.dart test/local_agent_session_client_test.dart
git commit -m "feat(crm): add typed local agent session client"
```

---

### Task 8: Integrate Windows Login, Conflict Confirmation, and Revocation

**Files:**
- Modify: `tools/alpha-crm/lib/features/auth/providers/crm_auth_provider.dart`
- Modify: `tools/alpha-crm/lib/features/auth/presentation/screens/crm_login_screen.dart`
- Create: `tools/alpha-crm/test/crm_auth_provider_single_pc_test.dart`
- Create: `tools/alpha-crm/test/crm_login_screen_single_pc_test.dart`

- [ ] **Step 1: Write failing provider tests**

Refactor provider construction for dependency injection:

```dart
test('Windows login returns conflict and stays unauthenticated', () async {
  final cloud = FakeCrmAuthGateway(
    loginResponse: {
      'success': true,
      'data': {'token': 'jwt'},
    },
    getResponses: {
      '/auth/me': {
        'success': true,
        'data': {
          'user': {'_id': 'user-1', 'email': 'user@example.com'}
        },
      },
      '/crm/subscription/me': {
        'success': true,
        'data': {'active': true},
      },
      '/crm/quota': {
        'success': true,
        'data': {
          'includedAiLimit': 1000,
          'includedAiUsed': 0,
          'extraAiRemaining': 0,
        },
      },
    },
  );
  final local = FakeLocalAgentSessionClient(
    syncResult: const LocalAgentConflict(
      ActiveDeviceSummary(displayName: 'PC-A'),
    ),
  );
  final notifier = CrmAuthNotifier(
    cloudApi: cloud,
    localAgent: local,
    isWindows: true,
    autoInitialize: false,
  );

  final result = await notifier.login('user@example.com', 'password');

  expect(result, isA<CrmLoginDeviceConflict>());
  expect(notifier.state.isAuthenticated, false);
});

test('revocation event clears auth state', () async {
  final local = FakeLocalAgentSessionClient(
    syncResult: const LocalAgentActive('device-1'),
  );
  final notifier = buildAuthenticatedNotifier(local);

  local.emit(const LocalSessionRevoked(reason: 'replaced_by_new_pc'));
  await pumpEventQueue();

  expect(notifier.state.isAuthenticated, false);
  expect(await CrmAuthTokenStore.getToken(), isNull);
});
```

- [ ] **Step 2: Run provider tests and verify RED**

Run:

```powershell
flutter test test/crm_auth_provider_single_pc_test.dart
```

Expected: FAIL because login still returns `bool` and has no local session dependency.

- [ ] **Step 3: Refactor auth state transitions**

Add an injectable gateway in the same provider file:

```dart
abstract interface class CrmAuthGateway {
  Future<Map<String, dynamic>> get(String path);
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  );
}

final class DefaultCrmAuthGateway implements CrmAuthGateway {
  const DefaultCrmAuthGateway();

  @override
  Future<Map<String, dynamic>> get(String path) => CrmCloudApi.get(path);

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) => CrmCloudApi.post(path, body);
}
```

Use this constructor:

```dart
CrmAuthNotifier({
  CrmAuthGateway cloudApi = const DefaultCrmAuthGateway(),
  LocalAgentSessionClient? localAgent,
  bool? isWindows,
  bool autoInitialize = true,
}) : _cloudApi = cloudApi,
     _localAgent = localAgent ?? LocalAgentSessionClient(),
     _isWindows = isWindows ??
         (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows),
     super(const CrmAuthState()) {
  if (autoInitialize) _initialize();
}
```

Add user ID:

```dart
class CrmUserState {
  final String id;
  // existing fields
}
```

Define login results:

```dart
sealed class CrmLoginResult {
  const CrmLoginResult();
}

final class CrmLoginSuccess extends CrmLoginResult {
  const CrmLoginSuccess();
}

final class CrmLoginDeviceConflict extends CrmLoginResult {
  final ActiveDeviceSummary device;
  const CrmLoginDeviceConflict(this.device);
}

final class CrmLoginFailure extends CrmLoginResult {
  final String message;
  const CrmLoginFailure(this.message);
}
```

Flow:

- Authenticate and fetch cloud user/subscription/quota.
- On Windows, sync local agent before setting `isAuthenticated: true`.
- On conflict, retain pending token/user privately in the notifier, not in authenticated state.
- `confirmDeviceReplacement()` retries with `forceReplace: true`.
- On success, persist token, set authenticated state, and subscribe to SSE.
- On cancel, delete pending token and reset state.
- Override `dispose()` and cancel the SSE subscription.
- `logout()` calls local logout best-effort on Windows, then deletes Flutter token.

- [ ] **Step 4: Write failing widget test for the custom dialog**

```dart
testWidgets('device conflict shows replacement confirmation dialog', (tester) async {
  await tester.pumpWidget(buildLoginApp(
    loginResult: const CrmLoginDeviceConflict(
      ActiveDeviceSummary(displayName: 'PC-A'),
    ),
  ));

  await tester.enterText(find.byKey(const Key('crm-email')), 'user@example.com');
  await tester.enterText(find.byKey(const Key('crm-password')), 'password');
  await tester.tap(find.byKey(const Key('crm-login-submit')));
  await tester.pumpAndSettle();

  expect(find.text('Đăng xuất máy tính cũ?'), findsOneWidget);
  expect(find.textContaining('PC-A'), findsOneWidget);
});
```

- [ ] **Step 5: Implement conflict UI**

Use `AppDialog`, not the native browser/Flutter confirmation dialog:

```dart
final result = await ref
    .read(crmAuthProvider.notifier)
    .login(email, password);

if (result is CrmLoginDeviceConflict && mounted) {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: 'Đăng xuất máy tính cũ?',
      icon: Icons.desktop_windows_rounded,
      subtitle:
          'Tài khoản đang hoạt động trên ${result.device.displayName}. '
          'Bạn có muốn đăng xuất máy cũ để dùng trên máy này không?',
      actions: [
        AppDialogAction(
          text: 'Hủy',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        AppDialogAction(
          text: 'Đăng xuất máy cũ',
          variant: AppButtonVariant.destructive,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
      child: const SizedBox.shrink(),
    ),
  );

  if (confirmed == true) {
    await ref.read(crmAuthProvider.notifier).confirmDeviceReplacement();
  } else {
    await ref.read(crmAuthProvider.notifier).cancelPendingLogin();
  }
}
```

Import `AppDialog`, `AppButtonVariant`, and add stable widget keys to login fields/buttons for tests.

- [ ] **Step 6: Run provider and widget tests**

Run:

```powershell
flutter test test/crm_auth_provider_single_pc_test.dart test/crm_login_screen_single_pc_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add lib/features/auth/providers/crm_auth_provider.dart lib/features/auth/presentation/screens/crm_login_screen.dart test/crm_auth_provider_single_pc_test.dart test/crm_login_screen_single_pc_test.dart
git commit -m "feat(crm): enforce single-PC login in Flutter"
```

---

### Task 9: Preserve Mobile QR Remote Semantics

**Files:**
- Modify: `alpha-studio-backend/server/routes/crm.js`
- Modify: `alpha-studio-backend/server/routes/__tests__/crmDeviceSessionContract.test.mjs`
- Modify: `tools/alpha-crm/lib/features/devices/providers/crm_device_provider.dart`
- Modify: `tools/alpha-crm/lib/features/devices/presentation/screens/device_pairing_screen.dart`
- Modify: `tools/alpha-crm/test/crm_device_provider_test.dart`

- [ ] **Step 1: Add failing cloud contract test for remote-only revocation**

Extend the route contract test:

```js
test('pairing revoke route removes mobile pairing without disabling the PC', () => {
  assert.match(source, /pairing\/revoke/);
  assert.match(source, /\$pull:\s*\{[\s\S]*pairedMobileUserIds/);
});
```

- [ ] **Step 2: Add failing Flutter tests that remote disconnect never disables PC**

```dart
test('mobile remote disconnect builds revoke-pairing request only', () {
  final request = buildRemoteDisconnectRequest(
    deviceId: 'pc-device',
    mobileUserId: 'mobile-user',
  );

  expect(request.path, '/crm/pairing/revoke');
  expect(request.path, isNot(contains('/devices/')));
  expect(request.path, isNot(contains('/disable')));
});
```

Add a widget assertion that mobile retains QR scanning while Windows displays the QR/session management view.

- [ ] **Step 3: Run contract/device tests and verify RED**

Run:

```powershell
node --test server/routes/__tests__/crmDeviceSessionContract.test.mjs
flutter test test/crm_device_provider_test.dart
```

Expected: FAIL because `/crm/pairing/revoke` does not exist and Flutter currently calls `/crm/devices/:id/disable`.

- [ ] **Step 4: Add remote-only cloud revocation route**

Add an authenticated route that updates only pairing arrays:

```js
router.post('/pairing/revoke', authMiddleware, async (req, res) => {
  const requestedMobileUserId = req.body.mobileUserId || req.user._id;
  const device = await CrmDevice.findOneAndUpdate(
    {
      userId: req.user._id,
      status: 'active',
      pairedMobileUserIds: requestedMobileUserId,
    },
    {
      $pull: {
        pairedMobileUserIds: requestedMobileUserId,
        pairedMobileDevices: { userId: requestedMobileUserId },
      },
    },
    { new: true },
  );

  if (!device) {
    return res.status(404).json({
      success: false,
      code: 'REMOTE_PAIRING_NOT_FOUND',
      message: 'Không tìm thấy kết nối Remote đang hoạt động.',
    });
  }

  return res.json({
    success: true,
    data: { device },
  });
});
```

This route must never set `CrmDevice.status`.

- [ ] **Step 5: Separate Flutter remote disconnect from PC device lifecycle**

Ensure provider methods are explicit:

```dart
Future<bool> disconnectCurrentMobileRemote();
Future<bool> revokePairedMobile(String mobileUserId);
```

Neither method may call `/crm/devices/:id/disable`. Keep the QR scanner and pairing payload behavior unchanged.

- [ ] **Step 6: Update screen language**

Use:

- Mobile: `Ngắt kết nối Remote`
- Windows: QR pairing and paired remote management

Do not add an email/password login flow to mobile in this task.

- [ ] **Step 7: Run contract and device tests**

Run:

```powershell
node --test server/routes/__tests__/crmDeviceSessionContract.test.mjs
flutter test test/crm_device_provider_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```powershell
git add server/routes/crm.js server/routes/__tests__/crmDeviceSessionContract.test.mjs
git commit -m "feat(crm): revoke mobile remotes without disabling PC"

git add lib/features/devices/providers/crm_device_provider.dart lib/features/devices/presentation/screens/device_pairing_screen.dart test/crm_device_provider_test.dart
git commit -m "fix(crm): keep mobile disconnect scoped to remote pairing"
```

Run the cloud commit from `alpha-studio-backend` and the Flutter commit from `tools/alpha-crm`.

---

### Task 10: Update Documentation and Remove Destructive Plan Language

**Files:**
- Modify: `ALPHA_CRM_REFACTOR_PLAN.md`
- Modify: `tools/alpha-crm/integration/zalo-bot-service/README.md`
- Modify: `tools/alpha-crm/.claude/PROJECT_SUMMARY.md`
- Modify: `alpha-studio-backend/.claude/PROJECT_SUMMARY.md`
- Modify: `alpha-studio-backend/.claude/DATABASE.md`

- [ ] **Step 1: Correct the refactor plan**

Replace all claims that revocation deletes SQLite/Zalo/settings with:

```text
Khi bị thay thế bởi PC mới:
- Dừng agent, Zalo listener, campaign, heartbeat, polling và local sync.
- Xóa CRM JWT (`crm_token.json`) và agent credential (`device-secret.json`).
- Giữ nguyên SQLite, tài khoản Zalo, cấu hình, hội thoại và lịch sử.
- Báo Flutter qua SSE để quay về màn hình đăng nhập.
```

Remove Phase 4 scenarios that ask mobile remote disconnect to log out or wipe the Windows PC.

- [ ] **Step 2: Update bridge README**

Document:

```text
POST /local/auth/sync
POST /local/auth/logout
GET /local/events
```

Remove `npm run crm:register-device`.

- [ ] **Step 3: Update project summaries**

Record current architecture only:

- Strict one-PC cloud contract.
- Local auth sync and SSE.
- Non-destructive revocation.
- Mobile QR remains remote pairing.
- Exact verification status.

Update `Last Updated` to `2026-06-06`.

- [ ] **Step 4: Update backend database/API docs**

Document:

- `CrmDevice.status = replaced`.
- Partial unique active-device index.
- `409 DEVICE_ALREADY_ACTIVE`.
- `403 DEVICE_REVOKED`.
- Atomic force-replace route.

- [ ] **Step 5: Check docs and commit**

Run:

```powershell
rg -n "xóa.*SQLite|xóa trắng data|crm:register-device|cmr:register-device" ALPHA_CRM_REFACTOR_PLAN.md tools/alpha-crm alpha-studio-backend/.claude
```

Expected: no obsolete destructive/session-registration instructions outside explicitly historical records.

Commit:

```powershell
git add ALPHA_CRM_REFACTOR_PLAN.md tools/alpha-crm/integration/zalo-bot-service/README.md tools/alpha-crm/.claude/PROJECT_SUMMARY.md alpha-studio-backend/.claude/PROJECT_SUMMARY.md alpha-studio-backend/.claude/DATABASE.md
git commit -m "docs(crm): document automatic single-PC sessions"
```

If the workspace root and nested Alpha CRM repository require separate commits, commit each repository independently with the same scoped message.

---

### Task 11: End-to-End Verification

**Files:**
- No production files unless verification exposes a regression; any fix must begin with a failing regression test.

- [ ] **Step 1: Verify cloud backend tests**

Run:

```powershell
node --test server/utils/crmDeviceSessions.test.js server/routes/__tests__/crmDeviceSessionContract.test.mjs
node --test server/utils/crmBilling.test.js server/utils/crmCatalog.test.js server/utils/crmQuota.test.js
```

Expected: all PASS.

- [ ] **Step 2: Verify local bridge**

Run:

```powershell
npm run build
npm test
```

Expected: TypeScript build and all Node tests PASS.

- [ ] **Step 3: Verify Flutter**

Run:

```powershell
dart format lib/features/auth lib/features/devices test/local_agent_session_client_test.dart test/crm_auth_provider_single_pc_test.dart test/crm_login_screen_single_pc_test.dart test/crm_device_provider_test.dart
flutter analyze
flutter test
```

Expected:

- Formatting completes without changes on a second run.
- `flutter test` PASS.
- `flutter analyze` has no new errors; if existing info-level baseline remains, record it precisely.

- [ ] **Step 4: Smoke-test local bridge endpoints**

Start the bridge:

```powershell
npm start
```

From another terminal:

```powershell
curl.exe http://127.0.0.1:8787/health
curl.exe -N http://127.0.0.1:8787/local/events
```

Expected:

- `/health` returns HTTP 200 without secrets.
- `/local/events` remains open with `text/event-stream`.

- [ ] **Step 5: Manual two-PC acceptance test**

Using test account and two Windows machines or isolated app-data profiles:

1. Sign in on PC A and verify agent heartbeat.
2. Sign in on PC B and verify conflict dialog.
3. Cancel and confirm PC A remains active.
4. Retry on PC B and confirm replacement.
5. Verify PC A stops before another campaign recipient, removes CRM token/agent secret, keeps Zalo/SQLite/settings, and returns to login.
6. Restart PC A and verify it stays logged out without polling spam.
7. Verify mobile QR pairing still controls the active PC and mobile disconnect does not disable it.

- [ ] **Step 6: Inspect final diffs**

Run separately in each repository:

```powershell
git status --short
git diff --check
git log -5 --oneline
```

Expected:

- No unintended files.
- Existing unrelated Live Chat changes remain untouched.
- No whitespace errors.

- [ ] **Step 7: Final verification commit if needed**

Only if verification required test-backed fixes:

```powershell
git add <only-files-fixed-during-verification>
git commit -m "fix(crm): address single-PC verification regressions"
```
