import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import { SessionCoordinator } from './session-coordinator.js';
import { SessionEventHub } from './session-events.js';
import { handleLocalSessionRoute } from './local-session-api.js';

function createCoordinator(): SessionCoordinator {
  return new SessionCoordinator({
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
  });
}

test('local auth sync accepts a valid cloud session', async () => {
  const coordinator = createCoordinator();
  const hub = new SessionEventHub();
  const server = createServer(async (request, response) => {
    const handled = await handleLocalSessionRoute(
      request.method || 'GET',
      request.url || '/',
      request,
      response,
      (res, status, body) => {
        res.writeHead(status, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(body));
      },
      coordinator,
      hub,
    );
    if (!handled) {
      response.writeHead(404).end();
    }
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address() as AddressInfo;

  const response = await fetch(`http://127.0.0.1:${address.port}/local/auth/sync`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      token: 'jwt',
      userId: 'user-1',
      displayName: 'Office PC',
      machineFingerprint: 'fingerprint',
    }),
  });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    success: true,
    data: { status: 'active', deviceId: 'device-1' },
  });
  await new Promise<void>((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  });
});

test('local auth sync rejects mismatched user identity', async () => {
  const coordinator = createCoordinator();
  const hub = new SessionEventHub();
  const server = createServer(async (request, response) => {
    await handleLocalSessionRoute(
      request.method || 'GET',
      request.url || '/',
      request,
      response,
      (res, status, body) => {
        res.writeHead(status, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(body));
      },
      coordinator,
      hub,
    );
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address() as AddressInfo;

  const response = await fetch(`http://127.0.0.1:${address.port}/local/auth/sync`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      token: 'jwt',
      userId: 'another-user',
      displayName: 'Office PC',
      machineFingerprint: 'fingerprint',
    }),
  });

  assert.equal(response.status, 401);
  assert.equal((await response.json() as any).code, 'IDENTITY_MISMATCH');
  await new Promise<void>((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  });
});
