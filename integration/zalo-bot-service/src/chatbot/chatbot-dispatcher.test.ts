import test from 'node:test';
import assert from 'node:assert/strict';
import {
  ChatbotDispatcher,
  type ChatbotDispatcherDependencies,
} from './chatbot-dispatcher.js';
import type { OutboundMessageInput } from '../local-chat/local-chat-types.js';

function createDependencies(
  overrides: Partial<ChatbotDispatcherDependencies> = {},
): {
  dependencies: ChatbotDispatcherDependencies;
  calls: string[];
  outbound: OutboundMessageInput[];
  audits: Array<Record<string, unknown>>;
} {
  const calls: string[] = [];
  const outbound: OutboundMessageInput[] = [];
  const audits: Array<Record<string, unknown>> = [];
  const dependencies: ChatbotDispatcherDependencies = {
    sendTyping: async () => {
      calls.push('typing');
      return true;
    },
    sendMessage: async () => {
      calls.push('send');
      return {
        success: true,
        messageId: 'provider-out-1',
        clientMessageId: 'client-out-1',
      };
    },
    insertOutboundMessage: (input) => {
      calls.push('persist');
      outbound.push(input);
      return 'local-out-1';
    },
    updateMessageStatus: (
      messageId,
      status,
      providerMessageId,
      _errorText,
      clientMessageId,
    ) => {
      calls.push(
        `status:${messageId}:${status}:${providerMessageId}:${clientMessageId}`,
      );
    },
    publish: (event) => {
      calls.push(`publish:${event.type}`);
    },
    setConversationState: (_conversationKey, state) => {
      calls.push(`state:${state.mode}`);
    },
    markProviderMessageProcessed: (_conversationKey, providerMessageId) => {
      calls.push(`processed:${providerMessageId}`);
    },
    enqueueAudit: (idempotencyKey, payload) => {
      calls.push(`enqueue:${idempotencyKey}`);
      audits.push({ idempotencyKey, ...payload });
      return true;
    },
    postAudit: async (audit) => {
      calls.push(`audit:${audit.outcome}`);
    },
    deleteAudit: () => {
      calls.push('audit:delete');
    },
    markAuditFailed: () => {
      calls.push('audit:failed');
    },
    now: () => 1_717_243_200_000,
    createClientMessageId: () => 'chatbot-client-1',
    ...overrides,
  };
  return { dependencies, calls, outbound, audits };
}

test('successful reply sends once, persists chatbot metadata, publishes, processes sources, and posts deterministic audit', async () => {
  const first = createDependencies();
  const dispatcher = new ChatbotDispatcher(first.dependencies);
  const input = {
    accountId: 'account-1',
    threadId: 'user-1',
    threadType: 'user' as const,
    conversationKey: 'account-1:user-1',
    decision: {
      kind: 'reply' as const,
      mode: 'keyword' as const,
      text: 'Bảng giá đây.',
      ruleId: 'rule-1',
      sourceMessageIds: ['source-1', 'source-2'],
    },
  };

  const result = await dispatcher.dispatch(input);

  assert.deepEqual(result, {
    status: 'sent',
    localMessageId: 'local-out-1',
    providerMessageId: 'provider-out-1',
  });
  assert.equal(first.calls.filter((call) => call === 'send').length, 1);
  assert.deepEqual(first.outbound, [{
    accountId: 'account-1',
    threadId: 'user-1',
    threadType: 'user',
    content: 'Bảng giá đây.',
    messageType: 'text',
    clientMessageId: 'chatbot-client-1',
    metadata: {
      source: 'chatbot',
      chatbotMode: 'keyword',
      ruleId: 'rule-1',
      sourceMessageIds: ['source-1', 'source-2'],
    },
  }]);
  assert.ok(
    first.calls.indexOf('send') < first.calls.indexOf('persist'),
    'outbound persistence must happen only after a successful send',
  );
  assert.ok(first.calls.includes('publish:message.created'));
  assert.ok(first.calls.includes('processed:source-1'));
  assert.ok(first.calls.includes('processed:source-2'));
  assert.equal(first.audits[0]?.outcome, 'matched');

  const second = createDependencies();
  await new ChatbotDispatcher(second.dependencies).dispatch(input);
  assert.equal(
    first.audits[0]?.idempotencyKey,
    second.audits[0]?.idempotencyKey,
  );
});

test('send failure does not persist a successful outbound, enters handoff, audits failure, and does not retry', async () => {
  let sends = 0;
  const fixture = createDependencies({
    sendMessage: async () => {
      sends += 1;
      return { success: false, error: 'Zalo unavailable' };
    },
  });
  const dispatcher = new ChatbotDispatcher(fixture.dependencies);

  const result = await dispatcher.dispatch({
    accountId: 'account-1',
    threadId: 'user-1',
    threadType: 'user',
    conversationKey: 'account-1:user-1',
    decision: {
      kind: 'reply',
      mode: 'ai',
      text: 'AI reply',
      sourceMessageIds: ['source-1'],
    },
  });

  assert.deepEqual(result, {
    status: 'failed',
    error: 'Zalo unavailable',
  });
  assert.equal(sends, 1);
  assert.equal(fixture.calls.includes('persist'), false);
  assert.equal(
    fixture.calls.some((call) => call.startsWith('publish:')),
    false,
  );
  assert.ok(fixture.calls.includes('state:handoff'));
  assert.ok(fixture.calls.includes('audit:failed'));
  assert.equal(
    fixture.calls.some((call) => call.startsWith('processed:')),
    false,
  );
});
