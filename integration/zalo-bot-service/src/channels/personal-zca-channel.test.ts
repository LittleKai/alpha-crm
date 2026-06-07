import assert from 'node:assert/strict';
import { mkdirSync, unlinkSync, writeFileSync } from 'node:fs';
import test from 'node:test';
import { resolve } from 'node:path';
import { ThreadType } from 'zca-js';

import {
  PersonalZcaChannel,
  accountPool,
  normalizeZcaReactionForTest,
  normalizeInboundMessageForTest,
  normalizeReceiptEventForTest,
  normalizeUndoEventForTest,
  readImageMetadataForTest,
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

test('reads PNG dimensions for zca-js imageMetadataGetter', async () => {
  const dir = resolve('.data');
  mkdirSync(dir, { recursive: true });
  const filePath = resolve(dir, 'test-image-metadata.png');
  const png = Buffer.alloc(24);
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(png, 0);
  png.writeUInt32BE(13, 8);
  png.write('IHDR', 12, 'ascii');
  png.writeUInt32BE(320, 16);
  png.writeUInt32BE(180, 20);
  writeFileSync(filePath, png);
  try {
    const metadata = await readImageMetadataForTest(filePath);
    assert.equal(metadata.width, 320);
    assert.equal(metadata.height, 180);
    assert.equal(metadata.size, png.length);
  } finally {
    unlinkSync(filePath);
  }
});

test('recallMessage uses zca-js undo API with numeric cliMsgId fallback', async () => {
  accountPool.clear();
  setLoginPoolInitializedForTest(true);
  let captured: any;
  accountPool.set('operator-1', {
    api: {
      undo: async (payload: any, threadId: string, type: ThreadType) => {
        captured = { payload, threadId, type };
        return { status: 0 };
      },
    } as any,
    uId: 'operator-1',
    label: 'Operator',
    listenerRunning: false,
    lastEventAt: null,
  });

  const result = await new PersonalZcaChannel().recallMessage({
    accountId: 'operator-1',
    threadId: 'target-1',
    threadType: 'user',
    msgId: '7908682591079',
    cliMsgId: 'flutter_1780761273591',
  });

  assert.equal(result.success, true);
  assert.deepEqual(captured, {
    payload: {
      msgId: '7908682591079',
      cliMsgId: '7908682591079',
    },
    threadId: 'target-1',
    type: ThreadType.User,
  });
  accountPool.clear();
  setLoginPoolInitializedForTest(false);
});

test('reactMessage maps UI heart reaction to zca-js HEART reaction destination', async () => {
  accountPool.clear();
  setLoginPoolInitializedForTest(true);
  let captured: any;
  accountPool.set('operator-1', {
    api: {
      addReaction: async (icon: string, dest: any) => {
        captured = { icon, dest };
        return { msgIds: [123] };
      },
    } as any,
    uId: 'operator-1',
    label: 'Operator',
    listenerRunning: false,
    lastEventAt: null,
  });

  const result = await new PersonalZcaChannel().reactMessage({
    accountId: 'operator-1',
    threadId: 'target-1',
    threadType: 'user',
    msgId: '123456789',
    reaction: 'heart',
  });

  assert.equal(result.success, true);
  assert.equal(captured.icon, '/-heart');
  assert.deepEqual(captured.dest, {
    data: {
      msgId: '123456789',
      cliMsgId: '123456789',
    },
    threadId: 'target-1',
    type: ThreadType.User,
  });
  assert.equal(normalizeZcaReactionForTest('❤️'), '/-heart');
  accountPool.clear();
  setLoginPoolInitializedForTest(false);
});
