import test from 'node:test';
import assert from 'node:assert/strict';
import {
  ChatbotCloudApi,
  type ChatbotAgentCredentials,
} from './chatbot-cloud-api.js';
import { CloudApiError } from '../agent/cloud-api.js';

const credentials: ChatbotAgentCredentials = {
  deviceId: 'device-1',
  agentSecret: 'secret-1',
};

test('fetchConfig uses agent authentication and validates the snapshot', async () => {
  const originalFetch = globalThis.fetch;
  let request: { url: string; init?: RequestInit } | undefined;
  globalThis.fetch = async (input, init) => {
    request = { url: String(input), init };
    return jsonResponse({
      success: true,
      data: {
        version: 'v1',
        settings: { enabled: true },
        rules: [],
        scope: { crmThreadKeys: [], selectedGroupKeys: [] },
      },
    });
  };

  try {
    const snapshot = await new ChatbotCloudApi(credentials).fetchConfig();
    assert.equal(snapshot.version, 'v1');
  } finally {
    globalThis.fetch = originalFetch;
  }

  assert.match(request?.url ?? '', /\/crm\/agent\/chatbot\/config$/);
  assert.equal(request?.init?.method, 'GET');
  assert.equal(
    new Headers(request?.init?.headers).get('x-agent-device-id'),
    'device-1',
  );
  assert.equal(
    new Headers(request?.init?.headers).get('x-agent-secret'),
    'secret-1',
  );
});

test('generateReply makes one request and validates text output', async () => {
  const originalFetch = globalThis.fetch;
  let calls = 0;
  globalThis.fetch = async () => {
    calls += 1;
    return jsonResponse({
      success: true,
      data: { reply: 'Generated reply', usage: { units: 1 } },
    });
  };

  try {
    const result = await new ChatbotCloudApi(credentials).generateReply({
      accountId: 'account-1',
      threadId: 'thread-1',
      conversationKey: 'account-1:thread-1',
      messages: [{
        id: 'message-1',
        content: 'Question',
        timestamp: 1,
      }],
      history: [],
    });
    assert.equal(result.reply, 'Generated reply');
    assert.equal(calls, 1);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('postAudit sends the idempotency key without retrying errors', async () => {
  const originalFetch = globalThis.fetch;
  let calls = 0;
  globalThis.fetch = async () => {
    calls += 1;
    return jsonResponse(
      { success: false, code: 'AUDIT_REJECTED', message: 'bad audit' },
      400,
    );
  };

  try {
    await assert.rejects(
      () => new ChatbotCloudApi(credentials).postAudit({
        idempotencyKey: 'audit-1',
        outcome: 'failed',
        conversationKey: 'account-1:thread-1',
        timestamp: 1,
      }),
      (error) =>
        error instanceof CloudApiError
        && error.code === 'AUDIT_REJECTED',
    );
    assert.equal(calls, 1);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('rejects malformed cloud config instead of caching it', async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => jsonResponse({
    success: true,
    data: { version: 'v1', settings: {}, rules: 'invalid' },
  });

  try {
    await assert.rejects(
      () => new ChatbotCloudApi(credentials).fetchConfig(),
      /Invalid chatbot config response/,
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

