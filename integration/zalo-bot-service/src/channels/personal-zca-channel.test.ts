import assert from 'node:assert/strict';
import { mkdirSync, unlinkSync, writeFileSync } from 'node:fs';
import test from 'node:test';
import { resolve } from 'node:path';
import { ThreadType } from 'zca-js';

import {
  PersonalZcaChannel,
  accountPool,
  addAccountInstance,
  failedAccounts,
  normalizeZcaReactionForTest,
  normalizeInboundMessageForTest,
  normalizeReceiptEventForTest,
  normalizeUndoEventForTest,
  readImageMetadataForTest,
  runWithFixedDateNowForTest,
  recordReloginAttemptForTest,
  clearReloginHistoryForTest,
  RELOGIN_MAX_IN_WINDOW_FOR_TEST,
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

test('runWithFixedDateNow pins Date.now only for a plausible current ms timestamp', async () => {
  const realNow = Date.now();

  // Valid current ms id → Date.now is pinned to it (so zca-js stamps the same cliMsgId).
  const validId = String(realNow);
  let seenInside = 0;
  await runWithFixedDateNowForTest(validId, async () => {
    seenInside = Date.now();
  });
  assert.equal(seenInside, realNow);
  assert.notEqual(Date.now, undefined); // restored

  // Microsecond id (~1000x larger, far future) → NOT pinned; the real clock is kept,
  // so tough-cookie never treats zpw_sek as expired.
  const microId = String(realNow * 1000);
  let seenMicro = 0;
  await runWithFixedDateNowForTest(microId, async () => {
    seenMicro = Date.now();
  });
  assert.ok(
    Math.abs(seenMicro - realNow) < 60_000,
    `expected real-now clock, got ${seenMicro}`,
  );

  // Non-numeric id → NOT pinned.
  let seenText = 0;
  await runWithFixedDateNowForTest('flutter_not_a_number', async () => {
    seenText = Date.now();
  });
  assert.ok(Math.abs(seenText - realNow) < 60_000);
});

test('recordReloginAttempt counts attempts within the sliding window', () => {
  clearReloginHistoryForTest('cb-acct');
  assert.equal(recordReloginAttemptForTest('cb-acct'), 1);
  assert.equal(recordReloginAttemptForTest('cb-acct'), 2);
  assert.equal(recordReloginAttemptForTest('cb-acct'), 3);
  // The 4th attempt exceeds the breaker budget (RELOGIN_MAX_IN_WINDOW = 3).
  assert.equal(recordReloginAttemptForTest('cb-acct'), RELOGIN_MAX_IN_WINDOW_FOR_TEST + 1);
  clearReloginHistoryForTest('cb-acct');
  assert.equal(recordReloginAttemptForTest('cb-acct'), 1);
  clearReloginHistoryForTest('cb-acct');
});

test('sendMessage marks account expired when re-login cannot recover a zpw_sek session', async () => {
  accountPool.clear();
  failedAccounts.clear();
  clearReloginHistoryForTest('operator-1');
  setLoginPoolInitializedForTest(true);
  accountPool.set('operator-1', {
    api: {
      sendMessage: async () => {
        const error = new Error('zpw_sek bị thiếu hoặc không đúng') as Error & {
          code?: number;
        };
        error.code = 600;
        throw error;
      },
    } as any,
    uId: 'operator-1',
    label: 'Operator',
    listenerRunning: false,
    lastEventAt: null,
    status: 'connected',
    // Points at a file that does not exist → re-login from disk returns null.
    credentialsPath: resolve(process.cwd(), '__alpha_crm_no_such_credentials__.json'),
  });

  const originalLog = console.log;
  const originalWarn = console.warn;
  const originalError = console.error;
  console.log = () => {};
  console.warn = () => {};
  console.error = () => {};
  let result: { success: boolean; error?: string } = { success: true };
  try {
    result = await new PersonalZcaChannel().sendMessage({
      accountId: 'operator-1',
      recipientId: 'target-1',
      message: 'hi',
      threadType: 'user',
    });
  } finally {
    console.log = originalLog;
    console.warn = originalWarn;
    console.error = originalError;
  }

  assert.equal(result.success, false);
  assert.match(result.error ?? '', /zpw_sek|600/);
  // Re-login failed → account is marked expired so the UI shows the QR re-login prompt.
  assert.equal(accountPool.get('operator-1')?.status, 'disconnected_expired');

  clearReloginHistoryForTest('operator-1');
  accountPool.clear();
  setLoginPoolInitializedForTest(false);
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

test('sendMessage surfaces failed credential reason when no account can be loaded', async () => {
  accountPool.clear();
  failedAccounts.clear();
  setLoginPoolInitializedForTest(true);
  failedAccounts.set('operator-1', {
    id: 'operator-1',
    reason: 'File credentials_operator-1.json này bị thiếu trường quan trọng zpw_sek.',
    filePath: 'credentials_operator-1.json',
  });

  const originalError = console.error;
  console.error = () => {};
  let result: { success: boolean; error?: string } = { success: true };
  try {
    result = await new PersonalZcaChannel().sendMessage({
      accountId: 'operator-1',
      recipientId: 'target-1',
      message: 'hi',
      threadType: 'user',
    });
  } finally {
    console.error = originalError;
    accountPool.clear();
    failedAccounts.clear();
    setLoginPoolInitializedForTest(false);
  }

  assert.equal(result.success, false);
  assert.match(result.error ?? '', /zpw_sek/);
  assert.doesNotMatch(result.error ?? '', /No active connected Zalo accounts/);
});

test('addAccountInstance clears stale failed credential state after QR relogin succeeds', async () => {
  accountPool.clear();
  failedAccounts.clear();
  setLoginPoolInitializedForTest(true);
  failedAccounts.set('operator-1', {
    id: 'operator-1',
    reason: 'Đăng nhập thất bại (code: 600)',
    filePath: 'credentials_operator-1.json',
  });

  await addAccountInstance('operator-1', {
    fetchAccountInfo: async () => ({
      profile: { displayName: 'Operator', avatar: '' },
    }),
  } as any, 'credentials_operator-1.json');

  try {
    assert.equal(failedAccounts.has('operator-1'), false);
    assert.deepEqual(
      new PersonalZcaChannel().getAccounts().map((account) => account.id),
      ['operator-1'],
    );
  } finally {
    accountPool.clear();
    failedAccounts.clear();
    setLoginPoolInitializedForTest(false);
  }
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

test('recallMessage uses zca-js undo API with the stored Zalo cliMsgId', async () => {
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
    cliMsgId: '1780761273591',
  });

  assert.equal(result.success, true);
  assert.deepEqual(captured, {
    payload: {
      msgId: '7908682591079',
      cliMsgId: '1780761273591',
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
    cliMsgId: '1780761273591',
    reaction: 'heart',
  });

  assert.equal(result.success, true);
  assert.equal(captured.icon, '/-heart');
  assert.deepEqual(captured.dest, {
    data: {
      msgId: '123456789',
      cliMsgId: '1780761273591',
    },
    threadId: 'target-1',
    type: ThreadType.User,
  });
  assert.equal(normalizeZcaReactionForTest('❤️'), '/-heart');
  accountPool.clear();
  setLoginPoolInitializedForTest(false);
});
