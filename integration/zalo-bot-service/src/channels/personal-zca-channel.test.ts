import assert from 'node:assert/strict';
import test from 'node:test';
import { ThreadType } from 'zca-js';

import {
  PersonalZcaChannel,
  accountPool,
  normalizeInboundMessageForTest,
  normalizeReceiptEventForTest,
  normalizeUndoEventForTest,
  setLoginPoolInitializedForTest,
} from './personal-zca-channel.js';

test('normalizes root ThreadType.Group message events as group threads', () => {
  const inbound = normalizeInboundMessageForTest(
    { uId: 'operator-1', label: 'Operator' },
    {
      type: ThreadType.Group,
      threadId: 'group-1',
      data: {
        uidFrom: 'member-1',
        content: 'Xin chao nhom',
        msgId: 'msg-1',
        ts: 1780000000,
      },
    },
  );

  assert.equal(inbound?.threadType, 'group');
  assert.equal(inbound?.threadId, 'group-1');
  assert.equal(inbound?.senderId, 'member-1');
});

test('sendMessage preserves zca error code in returned error text', async () => {
  accountPool.clear();
  setLoginPoolInitializedForTest(true);
  accountPool.set('operator-1', {
    api: {
      sendMessage: async () => {
        const error = new Error('Tham số không hợp lệ') as Error & {
          code?: number;
        };
        error.code = 114;
        throw error;
      },
    } as any,
    uId: 'operator-1',
    label: 'Operator',
    listenerRunning: false,
    lastEventAt: null,
  });

  const originalLog = console.log;
  const originalError = console.error;
  console.log = () => {};
  console.error = () => {};
  let result: { success: boolean; error?: string } = { success: false };
  try {
    result = await new PersonalZcaChannel().sendMessage({
      accountId: 'operator-1',
      recipientId: 'target-1',
      message: 'hi',
      threadType: 'user',
    });
  } finally {
    console.log = originalLog;
    console.error = originalError;
  }

  assert.equal(result.success, false);
  assert.match(result.error ?? '', /114/);
  assert.match(result.error ?? '', /Tham số không hợp lệ/);
  accountPool.clear();
  setLoginPoolInitializedForTest(false);
});

test('normalizes undo events from nested Zalo payloads', () => {
  const event = normalizeUndoEventForTest(
    { uId: 'operator-1', label: 'Operator' },
    {
      type: ThreadType.Group,
      threadId: 'group-1',
      data: {
        content: {
          globalMsgId: 'global-undo-1',
          cliMsgId: 'client-undo-1',
        },
      },
    },
  );

  assert.equal(event?.type, 'message.recalled');
  assert.equal(event?.threadId, 'group-1');
  assert.equal(event?.providerMessageId, 'global-undo-1');
  assert.equal(event?.clientMessageId, 'client-undo-1');
});

test('normalizes seen receipt payloads with reader identities', () => {
  const events = normalizeReceiptEventForTest(
    { uId: 'operator-1', label: 'Operator' },
    'seen',
    {
      type: ThreadType.User,
      threadId: 'customer-1',
      data: {
        msgIds: ['msg-1', 'msg-2'],
        uid: 'customer-1',
        ts: 1780000000,
      },
    },
  );

  assert.equal(events.length, 2);
  assert.equal(events[0].type, 'message.seen');
  assert.equal(events[0].providerMessageId, 'msg-1');
  assert.equal(events[0].userId, 'customer-1');
});
