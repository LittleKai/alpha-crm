import test from 'node:test';
import assert from 'node:assert/strict';
import {
  CloudApiError,
  isDeviceRevokedError,
  reportInboundMessageMetadata,
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
