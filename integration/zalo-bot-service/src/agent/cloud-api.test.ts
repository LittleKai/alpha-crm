import test from 'node:test';
import assert from 'node:assert/strict';
import {
  CloudApiError,
  isDeviceRevokedError,
  reportInboundMessageMetadata,
  sendHeartbeat,
  fetchNextCommand,
} from './cloud-api.js';

test('isDeviceRevokedError accepts only explicit cloud revocation', () => {
  assert.equal(
    isDeviceRevokedError(
      new CloudApiError('revoked', 403, 'DEVICE_REVOKED'),
    ),
    true,
  );
  assert.equal(
    isDeviceRevokedError(
      new CloudApiError('bad secret', 403, 'INVALID_AGENT_CREDENTIALS'),
    ),
    false,
  );
  assert.equal(isDeviceRevokedError(new TypeError('network failed')), false);
});

test('reportInboundMessageMetadata sends the local-first metadata contract', async () => {
  const originalFetch = globalThis.fetch;
  let requestBody: Record<string, unknown> | null = null;
  globalThis.fetch = async (_input, init) => {
    requestBody = JSON.parse(String(init?.body));
    return new Response(JSON.stringify({ success: true, data: {} }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  };

  try {
    await reportInboundMessageMetadata('device-1', 'secret-1', {
      accountId: 'account-1',
      threadId: 'thread-1',
      threadType: 'user',
      content: 'A'.repeat(120),
      timestamp: '2026-06-11T10:00:00.000Z',
      providerMessageId: 'message-1',
      messageType: 'text',
    });
  } finally {
    globalThis.fetch = originalFetch;
  }

  assert.deepEqual(requestBody, {
    accountId: 'account-1',
    threadId: 'thread-1',
    threadType: 'user',
    senderId: '',
    displayName: '',
    avatarUrl: '',
    lastMessagePreview: 'A'.repeat(100),
    lastMessageAt: '2026-06-11T10:00:00.000Z',
    unreadCountDelta: 1,
    messageType: 'text',
    bridgeDeviceId: 'device-1',
    providerMessageId: 'message-1',
    localFirst: true,
  });
  assert.equal(Object.hasOwn(requestBody ?? {}, 'content'), false);
});

test('sendHeartbeat sends the enriched AG-1 payload shape', async () => {
  const originalFetch = globalThis.fetch;
  let requestBody: Record<string, unknown> | null = null;
  let headers: Record<string, unknown> | null = null;
  globalThis.fetch = async (_input, init) => {
    requestBody = JSON.parse(String(init?.body));
    headers = init?.headers as Record<string, unknown>;
    return new Response(JSON.stringify({ success: true, data: {} }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  };

  try {
    await sendHeartbeat('device-1', 'secret-1', {
      status: 'online',
      appVersion: '1.2.3',
      agentVersion: '1.2.3',
      zaloAccounts: [{ accountId: 'acct-1', displayName: 'Sales', status: 'online' }],
      queueDepth: 2,
      clientConnections: 1,
    });
  } finally {
    globalThis.fetch = originalFetch;
  }

  assert.deepEqual(requestBody, {
    status: 'online',
    appVersion: '1.2.3',
    agentVersion: '1.2.3',
    zaloAccounts: [{ accountId: 'acct-1', displayName: 'Sales', status: 'online' }],
    queueDepth: 2,
    clientConnections: 1,
  });
  assert.equal((headers as any)?.['x-agent-device-id'], 'device-1');
  assert.equal((headers as any)?.['x-agent-secret'], 'secret-1');
});

test('fetchNextCommand sends waitMs when long-polling and omits it otherwise', async () => {
  const originalFetch = globalThis.fetch;
  const requestBodies: Array<Record<string, unknown>> = [];
  globalThis.fetch = async (_input, init) => {
    requestBodies.push(JSON.parse(String(init?.body)));
    return new Response(JSON.stringify({ success: true, data: null }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  };

  try {
    await fetchNextCommand('device-1', 'secret-1', 25000);
    await fetchNextCommand('device-1', 'secret-1');
  } finally {
    globalThis.fetch = originalFetch;
  }

  assert.deepEqual(requestBodies[0], { waitMs: 25000 });
  assert.deepEqual(requestBodies[1], {});
});
