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
    first.calls.indexOf('persist') < first.calls.indexOf('send'),
    'outbound persistence must happen before send',
  );
  assert.ok(first.calls.includes('publish:message.created'));
  assert.ok(first.calls.includes('publish:message.updated'));
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

test('reply with attachments sends text then each local file and records them', async () => {
  const resolved: string[] = [];
  const fixture = createDependencies({
    resolveAttachmentPath: (id) => {
      resolved.push(id);
      return `/data/chatbot-knowledge/${id}`;
    },
  });

  const result = await new ChatbotDispatcher(fixture.dependencies).dispatch({
    accountId: 'account-1',
    threadId: 'user-1',
    threadType: 'user',
    conversationKey: 'account-1:user-1',
    decision: {
      kind: 'reply',
      mode: 'ai',
      text: 'Gửi bạn tài liệu nhé.',
      attachments: [
        { type: 'image', id: 'idimg', name: 'lo-trinh.png' },
        { type: 'video', id: 'idvid', name: 'demo.mp4' },
      ],
      sourceMessageIds: ['source-1'],
    },
  });

  assert.equal(result.status, 'sent');
  // 1 text + 2 attachment sends.
  assert.equal(fixture.calls.filter((call) => call === 'send').length, 3);
  assert.equal(fixture.outbound.length, 3);
  assert.equal(fixture.outbound[0]?.messageType, 'text');
  assert.equal(fixture.outbound[1]?.messageType, 'image');
  assert.equal(fixture.outbound[2]?.messageType, 'video');
  assert.deepEqual(resolved, ['idimg', 'idvid']);
  assert.equal(fixture.audits[0]?.attachmentCount, 2);
  assert.ok(fixture.calls.includes('processed:source-1'));
});

test('attachment send failure is non-fatal once text is delivered', async () => {
  const fixture = createDependencies({
    sendMessage: async (request) => {
      if (request.attachments && request.attachments.length > 0) {
        return { success: false, error: 'upload failed' };
      }
      return {
        success: true,
        messageId: 'provider-out-1',
        clientMessageId: 'client-out-1',
      };
    },
    resolveAttachmentPath: () => '/data/chatbot-knowledge/idf',
  });

  const result = await new ChatbotDispatcher(fixture.dependencies).dispatch({
    accountId: 'account-1',
    threadId: 'user-1',
    threadType: 'user',
    conversationKey: 'account-1:user-1',
    decision: {
      kind: 'reply',
      mode: 'ai',
      text: 'Xin chào',
      attachments: [{ type: 'image', id: 'idf', name: 'f.png' }],
      sourceMessageIds: ['source-1'],
    },
  });

  assert.equal(result.status, 'sent');
  assert.equal(fixture.outbound.length, 2); // both the text and the attachment persisted (one sent, one failed)
  assert.equal(fixture.outbound[0]?.messageType, 'text');
  assert.equal(fixture.outbound[1]?.messageType, 'image');
  assert.ok(fixture.calls.includes('publish:message.created'));
  assert.ok(fixture.calls.includes('publish:message.failed'));
  assert.ok(
    fixture.calls.includes('status:local-out-1:failed:undefined:undefined'),
    'should update attachment status to failed'
  );
  assert.ok(fixture.calls.includes('processed:source-1'));
  assert.notEqual(
    fixture.calls.find((call) => call.startsWith('state:')),
    'state:handoff',
  );
});

test('missing local knowledge file is skipped without blocking the text reply', async () => {
  const fixture = createDependencies({
    resolveAttachmentPath: () => null, // file not present on this machine
  });

  const result = await new ChatbotDispatcher(fixture.dependencies).dispatch({
    accountId: 'account-1',
    threadId: 'user-1',
    threadType: 'user',
    conversationKey: 'account-1:user-1',
    decision: {
      kind: 'reply',
      mode: 'ai',
      text: 'Xin chào',
      attachments: [{ type: 'image', id: 'gone', name: 'gone.png' }],
      sourceMessageIds: ['source-1'],
    },
  });

  assert.equal(result.status, 'sent'); // text still delivered
  assert.equal(fixture.calls.filter((call) => call === 'send').length, 1);
  assert.equal(fixture.outbound.length, 1);
  assert.equal(fixture.outbound[0]?.messageType, 'text');
});

test('file-only reply (empty text) still sends the local attachment', async () => {
  const fixture = createDependencies({
    resolveAttachmentPath: (id) => `/data/chatbot-knowledge/${id}`,
  });

  const result = await new ChatbotDispatcher(fixture.dependencies).dispatch({
    accountId: 'account-1',
    threadId: 'user-1',
    threadType: 'user',
    conversationKey: 'account-1:user-1',
    decision: {
      kind: 'reply',
      mode: 'ai',
      text: '',
      attachments: [{ type: 'image', id: 'idf', name: 'f.png' }],
      sourceMessageIds: ['source-1'],
    },
  });

  assert.equal(result.status, 'sent');
  assert.equal(fixture.calls.filter((call) => call === 'send').length, 1);
  assert.equal(fixture.outbound.length, 1);
  assert.equal(fixture.outbound[0]?.messageType, 'image');
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
  assert.ok(fixture.calls.includes('persist'), 'should persist as queued');
  assert.ok(fixture.calls.includes('publish:message.created'), 'should publish message.created');
  assert.ok(fixture.calls.includes('publish:message.failed'), 'should publish message.failed');
  assert.ok(
    fixture.calls.includes('status:local-out-1:failed:undefined:undefined'),
    'should update status to failed'
  );
  assert.ok(fixture.calls.includes('state:handoff'));
  assert.ok(fixture.calls.includes('audit:failed'));
  assert.equal(
    fixture.calls.some((call) => call.startsWith('processed:')),
    false,
  );
});
