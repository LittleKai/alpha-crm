import test from 'node:test';
import assert from 'node:assert/strict';
import { CloudApiError } from '../agent/cloud-api.js';
import {
  SessionCoordinator,
  type SessionCoordinatorDependencies,
} from './session-coordinator.js';

function createDependencies(
  overrides: Partial<SessionCoordinatorDependencies> = {},
): SessionCoordinatorDependencies {
  return {
    verifyIdentity: async () => ({ userId: 'user-1' }),
    getCredentials: () => null,
    register: async () => ({ deviceId: 'device-1', agentSecret: 'secret-1' }),
    forceReplace: async () => ({ deviceId: 'device-2', agentSecret: 'secret-2' }),
    heartbeat: async () => undefined,
    disable: async () => undefined,
    saveCredentials: () => undefined,
    saveToken: () => undefined,
    deleteCredentials: () => undefined,
    deleteToken: () => undefined,
    startRuntime: async () => undefined,
    stopRuntime: async () => undefined,
    cancelCampaigns: () => undefined,
    resetCampaignCancellation: () => undefined,
    publish: () => undefined,
    ...overrides,
  };
}

test('sync rejects a JWT whose cloud identity differs from the requested user', async () => {
  const coordinator = new SessionCoordinator(createDependencies({
    verifyIdentity: async () => ({ userId: 'another-user' }),
  }));

  await assert.rejects(
    coordinator.sync({
      token: 'jwt',
      userId: 'user-1',
      displayName: 'Office PC',
      machineFingerprint: 'fingerprint',
    }),
    (error: any) => error.code === 'IDENTITY_MISMATCH',
  );
});

test('sync returns conflict without persisting or starting runtime', async () => {
  const calls: string[] = [];
  const coordinator = new SessionCoordinator(createDependencies({
    register: async () => {
      throw new CloudApiError(
        'active',
        409,
        'DEVICE_ALREADY_ACTIVE',
        {
          device: {
            displayName: 'Old PC',
            lastSeenAt: '2026-06-06T00:00:00.000Z',
          },
        },
      );
    },
    saveToken: () => calls.push('save-token'),
    startRuntime: async () => {
      calls.push('start');
    },
  }));

  const result = await coordinator.sync({
    token: 'jwt',
    userId: 'user-1',
    displayName: 'Office PC',
    machineFingerprint: 'fingerprint',
  });

  assert.deepEqual(result, {
    status: 'conflict',
    activeDevice: {
      displayName: 'Old PC',
      lastSeenAt: '2026-06-06T00:00:00.000Z',
    },
  });
  assert.deepEqual(calls, []);
});

test('forced sync persists the replacement credentials and starts runtime', async () => {
  const calls: string[] = [];
  const coordinator = new SessionCoordinator(createDependencies({
    saveToken: () => calls.push('save-token'),
    saveCredentials: (credentials) => calls.push(`save:${credentials.deviceId}`),
    resetCampaignCancellation: () => calls.push('reset-cancel'),
    startRuntime: async () => {
      calls.push('start');
    },
  }));

  const result = await coordinator.sync({
    token: 'jwt',
    userId: 'user-1',
    displayName: 'Office PC',
    machineFingerprint: 'fingerprint',
    force: true,
  });

  assert.deepEqual(result, { status: 'active', deviceId: 'device-2' });
  assert.deepEqual(calls, [
    'save-token',
    'save:device-2',
    'reset-cancel',
    'start',
  ]);
});

test('explicit revocation stops work before deleting session files and is idempotent', async () => {
  const calls: string[] = [];
  const coordinator = new SessionCoordinator(createDependencies({
    cancelCampaigns: () => calls.push('cancel'),
    stopRuntime: async () => {
      calls.push('stop');
    },
    deleteToken: () => calls.push('delete-token'),
    deleteCredentials: () => calls.push('delete-credentials'),
    publish: (event) => calls.push(`publish:${event.code}`),
  }));

  await Promise.all([
    coordinator.revoke('Replaced by another PC'),
    coordinator.revoke('Replaced by another PC'),
  ]);

  assert.deepEqual(calls, [
    'cancel',
    'stop',
    'delete-token',
    'delete-credentials',
    'publish:DEVICE_REVOKED',
  ]);
});
