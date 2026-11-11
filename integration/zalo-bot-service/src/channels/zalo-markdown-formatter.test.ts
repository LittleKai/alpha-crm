// Adapted from https://github.com/luonghaianh1208/2anh-zalo-bot@9ab55105c83487588e66b55f0ef66894224250a7 (MIT License)

import assert from 'node:assert/strict';
import { resolve } from 'node:path';
import test from 'node:test';

import {
  MENTION_ALL_UID,
  chunkStyledMessage,
  findMentions,
  formatAndChunkZaloMarkdown,
  formatZaloMarkdown,
  isZaloNumericErrorCode,
  latexToUnicode,
} from './zalo-markdown-formatter.js';
import {
  PersonalZcaChannel,
  accountPool,
  clearGroupMentionCacheForTest,
  clearReloginHistoryForTest,
  failedAccounts,
  isRecentProgrammaticSend,
  setAccountRateLimiterConfigForTest,
  setLoginPoolInitializedForTest,
} from './personal-zca-channel.js';

test('latexToUnicode converts chemical formulas, arrows, and fractions while preserving code and URLs', () => {
  assert.equal(
    latexToUnicode('$Ca^{2+} + CO_3^{2-} \\rightarrow CaCO_3$'),
    'Ca²⁺ + CO₃²⁻ → CaCO₃',
  );
  assert.equal(latexToUnicode('\\frac{1}{2} và $\\frac{a+b}{c}$'), '½ và (a+b)/c');
  assert.equal(
    latexToUnicode('Giữ nguyên `x^2_1` và https://example.com/?a=1^2'),
    'Giữ nguyên `x^2_1` và https://example.com/?a=1^2',
  );
});

test('formatZaloMarkdown strips Markdown markers and computes accurate UTF-16 style spans', () => {
  const input = [
    '# Tiêu đề',
    '**đậm** và *nghiêng* và ~~gạch~~',
    '1. bước 1',
    '[Zalo](https://zalo.me) {red}cảnh báo{/red}',
  ].join('\n');

  const formatted = formatZaloMarkdown(input);
  assert.equal(
    formatted.text,
    [
      'Tiêu đề',
      'đậm và nghiêng và gạch',
      '1. bước 1',
      'Zalo (https://zalo.me) cảnh báo',
    ].join('\n'),
  );
  assert.doesNotMatch(formatted.text, /\*\*|~~|#|\{red\}/);

  // Heading has 'b' and 'f_18'
  assert.ok(
    formatted.styles.some((s) => s.start === 0 && s.len === 'Tiêu đề'.length && s.st === 'b'),
  );
  assert.ok(
    formatted.styles.some((s) => s.start === 0 && s.len === 'Tiêu đề'.length && s.st === 'f_18'),
  );
  // {red}cảnh báo{/red} has 'c_db342e'
  const redIndex = formatted.text.indexOf('cảnh báo');
  assert.ok(
    formatted.styles.some(
      (s) => s.start === redIndex && s.len === 'cảnh báo'.length && s.st === 'c_db342e',
    ),
  );
});

test('chunkStyledMessage and formatAndChunkZaloMarkdown never split UTF-16 surrogate pairs at MAX_CHARS, style boundaries, or byte-budget loops', () => {
  // 1) Surrogate pair '😀' (\uD83D\uDE00, length 2) straddling the exact 2000-char boundary:
  // 1999 ASCII 'a' chars + '😀' (indices 1999..2000) + 'b'
  const straddlingMaxChars = 'a'.repeat(1999) + '😀' + 'b'.repeat(20);
  const maxCharChunks = chunkStyledMessage(straddlingMaxChars, [], 2000, 40, 10000);
  assert.equal(maxCharChunks.length, 2);
  assert.equal(maxCharChunks[0].text.length, 1999);
  assert.equal(maxCharChunks[1].text.startsWith('😀'), true);
  for (const chunk of maxCharChunks) {
    assert.equal(chunk.text.includes('\uFFFD'), false);
    for (let i = 0; i < chunk.text.length; i++) {
      const code = chunk.text.charCodeAt(i);
      if (code >= 0xd800 && code <= 0xdbff) {
        const next = chunk.text.charCodeAt(i + 1);
        assert.ok(next >= 0xdc00 && next <= 0xdfff, 'high surrogate must be followed by low surrogate');
        i++;
      } else {
        assert.ok(code < 0xdc00 || code > 0xdfff, 'orphan low surrogate found');
      }
    }
  }

  // 2) Surrogate pair at style-count midpoint fallback and byte-budget shrink loop
  const emojiHeavy = Array.from({ length: 60 }, (_, idx) => `**Mục ${idx} 😀🎉**`).join(' ');
  const chunks = formatAndChunkZaloMarkdown(emojiHeavy, 2000, 10, 600);
  assert.ok(chunks.length >= 2);
  for (const chunk of chunks) {
    assert.ok(chunk.text.length <= 2000);
    assert.ok(chunk.styles.length <= 10);
    const bytes =
      Buffer.byteLength(chunk.text, 'utf8') +
      Buffer.byteLength(JSON.stringify(chunk.styles), 'utf8');
    assert.ok(bytes <= 600, `expected <= 600 bytes, got ${bytes}`);
  }
});

test('isZaloNumericErrorCode matches only integer err.code values', () => {
  assert.equal(isZaloNumericErrorCode({ code: 112 }), true);
  assert.equal(isZaloNumericErrorCode({ code: '-108' }), true);
  assert.equal(isZaloNumericErrorCode({ name: 'ZaloApiError' }), false);
  assert.equal(isZaloNumericErrorCode({ code: 'ECONNRESET' }), false);
  assert.equal(isZaloNumericErrorCode(new Error('network error')), false);
});

test('PersonalZcaChannel.sendMessage leaves operator messages untouched, chunks chatbot Markdown with echo dedup, retries plain on non-600 numeric error keeping quote, and never plain-retries code 600', async (t) => {
  const accountId = 'md-operator';
  const threadId = 'md-customer';
  accountPool.clear();
  failedAccounts.clear();
  clearReloginHistoryForTest(accountId);
  clearGroupMentionCacheForTest();
  setAccountRateLimiterConfigForTest({ capacity: 20, refillMs: 10, maxWaitMs: 500 });
  setLoginPoolInitializedForTest(true);
  t.after(() => {
    accountPool.clear();
    failedAccounts.clear();
    clearReloginHistoryForTest(accountId);
    clearGroupMentionCacheForTest();
    setAccountRateLimiterConfigForTest(null);
    setLoginPoolInitializedForTest(false);
  });

  const sentPayloads: any[] = [];
  let mode: 'ok' | 'fail_styled_112' | 'fail_600' | 'fail_second_chunk' = 'ok';
  let callIndex = 0;

  accountPool.set(accountId, {
    uId: accountId,
    label: 'Markdown Operator',
    listenerRunning: false,
    lastEventAt: null,
    status: 'connected',
    credentialsPath: resolve(process.cwd(), '__no_such_creds_md__.json'),
    api: {
      sendMessage: async (payload: any) => {
        sentPayloads.push(payload);
        callIndex++;
        if (mode === 'fail_styled_112' && payload.styles) {
          const err = new Error('Invalid style param') as Error & { code?: number };
          err.code = 112;
          throw err;
        }
        if (mode === 'fail_600') {
          const err = new Error('zpw_sek expired') as Error & { code?: number };
          err.code = 600;
          throw err;
        }
        if (mode === 'fail_second_chunk' && sentPayloads.length >= 2) {
          throw new Error('Network timeout on chunk 2');
        }
        return {
          message: {
            msgId: `prov-${callIndex}`,
            cliMsgId: String(Date.now()),
          },
        };
      },
    } as any,
  });

  const channel = new PersonalZcaChannel();

  // 1) Operator message without chatbot/markdown metadata is NOT formatted
  sentPayloads.length = 0;
  await channel.sendMessage({
    accountId,
    recipientId: threadId,
    threadType: 'user',
    message: '#123 5*3 = 15',
  });
  assert.equal(sentPayloads.length, 1);
  assert.equal(sentPayloads[0].msg, '#123 5*3 = 15');
  assert.equal(sentPayloads[0].styles, undefined);

  // 2) Chatbot 3-chunk message registers echo dedup for every chunk and drops misaligned mentions
  sentPayloads.length = 0;
  const longPart = 'Đoạn văn bản dài '.repeat(130); // ~2210 chars (> MAX_CHARS=2000) per section
  const threeChunkMarkdown = `**Phần 1** ${longPart}\n\n**Phần 2** ${longPart}\n\n**Phần 3** kết thúc`;
  const multiRes = await channel.sendMessage({
    accountId,
    recipientId: threadId,
    threadType: 'user',
    message: threeChunkMarkdown,
    clientMessageId: String(Date.now()),
    mentions: [{ pos: 0, len: 5, uid: 'u1' }],
    metadata: { source: 'chatbot' },
  });
  assert.equal(multiRes.success, true);
  assert.equal(sentPayloads.length, 3);
  assert.equal(multiRes.chunkMessageIds?.length, 3);
  for (const chunkMsgId of multiRes.chunkMessageIds ?? []) {
    assert.equal(isRecentProgrammaticSend(accountId, threadId, chunkMsgId), true);
  }
  // Mentions were dropped because formatting altered text offsets
  assert.equal(sentPayloads[0].mentions, undefined);

  // 3) Numeric error (code 112) on styled chunk retries once as plain text while keeping quote
  sentPayloads.length = 0;
  mode = 'fail_styled_112';
  const fallbackRes = await channel.sendMessage({
    accountId,
    recipientId: threadId,
    threadType: 'user',
    message: '**Xin chào** khách hàng',
    quote: {
      msgId: 'q1',
      cliMsgId: 'c1',
      uidFrom: 'u1',
      msg: 'hello',
      ts: 1700000000000,
    },
    metadata: { source: 'chatbot' },
  });
  assert.equal(fallbackRes.success, true);
  assert.equal(sentPayloads.length, 2);
  assert.ok(Array.isArray(sentPayloads[0].styles));
  assert.equal(sentPayloads[1].styles, undefined);
  assert.equal(sentPayloads[1].msg, 'Xin chào khách hàng');
  assert.ok(sentPayloads[1].quote, 'quote must be preserved on plain-text retry');

  // 4) Code 600 (zpw_sek) is NOT retried as plain text
  sentPayloads.length = 0;
  mode = 'fail_600';
  const origConsoleError = console.error;
  const origConsoleWarn = console.warn;
  console.error = () => {};
  console.warn = () => {};
  try {
    const deadRes = await channel.sendMessage({
      accountId,
      recipientId: threadId,
      threadType: 'user',
      message: '**Thử lại**',
      metadata: { source: 'chatbot' },
    });
    assert.equal(deadRes.success, false);
    // Called only once before relogin attempt fails (never plain-text retried)
    assert.equal(sentPayloads.length, 1);
  } finally {
    console.error = origConsoleError;
    console.warn = origConsoleWarn;
  }

  // 5) Partial multi-chunk failure (chunk 1 delivered, chunk 2 throws) reports partial success instead of total failure
  sentPayloads.length = 0;
  mode = 'fail_second_chunk';
  const partialRes = await channel.sendMessage({
    accountId,
    recipientId: threadId,
    threadType: 'user',
    message: threeChunkMarkdown,
    clientMessageId: String(Date.now()),
    metadata: { source: 'chatbot' },
  });
  assert.equal(partialRes.success, true);
  assert.equal(partialRes.chunkMessageIds?.length, 1);
  assert.equal(partialRes.chunkClientMessageIds?.length, 1);
  assert.equal(partialRes.messageId, partialRes.chunkMessageIds?.[0]);
  assert.match(partialRes.error ?? '', /^partial: 1\/3 chunks sent/);
});

test('findMentions resolves @Tên and @All post-Markdown while skipping ambiguous names, NAME_CONTINUES, emails, selfUid, and trailing chunk splits', () => {
  const members = [
    { id: 'bot-uid', displayName: 'Trợ Lý Bot' },
    { id: 'u-short', displayName: 'Nguyễn Văn' },
    { id: 'u-long', displayName: 'Nguyễn Văn A' },
    { id: 'u-trang', displayName: 'Trang' },
    { id: 'u-dup-1', displayName: 'Minh' },
    { id: 'u-dup-2', displayName: 'Minh' },
  ];

  // 1) Post-Markdown formatted text resolves longest name first + @All
  const formatted = formatZaloMarkdown(
    '**Chào** @All, nhờ @Nguyễn Văn A và @Nguyễn Văn hỗ trợ @Minh nhé!',
  );
  const mentions = findMentions(formatted.text, members, {
    selfUid: 'bot-uid',
    canMentionAll: true,
  });
  assert.deepEqual(mentions, [
    { pos: formatted.text.indexOf('@All'), len: 4, uid: MENTION_ALL_UID },
    {
      pos: formatted.text.indexOf('@Nguyễn Văn A'),
      len: '@Nguyễn Văn A'.length,
      uid: 'u-long',
    },
    {
      pos: formatted.text.indexOf('@Nguyễn Văn hỗ'),
      len: '@Nguyễn Văn'.length,
      uid: 'u-short',
    },
  ]);

  // 2) NAME_CONTINUES: "@Trang Nguyễn" does not tag single-word "Trang"
  assert.deepEqual(
    findMentions('Chào @Trang Nguyễn nhé, còn @Trang ở đây', members, {
      selfUid: 'bot-uid',
    }),
    [
      {
        pos: 'Chào @Trang Nguyễn nhé, còn '.length,
        len: '@Trang'.length,
        uid: 'u-trang',
      },
    ],
  );

  // 3) Emails, selfUid, and continuesInNextChunk trailing edge are skipped
  assert.deepEqual(
    findMentions(
      'Email support@Trang.vn hoặc gọi @Trợ Lý Bot hoặc @Trang   ',
      members,
      {
        selfUid: 'bot-uid',
        continuesInNextChunk: true,
      },
    ),
    [],
  );
});

test('PersonalZcaChannel.sendMessage resolves group @Tên mentions via cached getGroupInfo and returns RATE_LIMITED when rate limiter rejects', async (t) => {
  const accountId = 'grp-operator';
  const groupId = 'grp-100';
  accountPool.clear();
  clearGroupMentionCacheForTest();
  setLoginPoolInitializedForTest(true);
  t.after(() => {
    accountPool.clear();
    clearGroupMentionCacheForTest();
    setAccountRateLimiterConfigForTest(null);
    setLoginPoolInitializedForTest(false);
  });

  let groupInfoCalls = 0;
  const sentPayloads: any[] = [];
  accountPool.set(accountId, {
    uId: accountId,
    label: 'Group Operator',
    listenerRunning: false,
    lastEventAt: null,
    status: 'connected',
    api: {
      getGroupInfo: async (gid: string) => {
        groupInfoCalls++;
        return {
          gridInfoMap: {
            [gid]: {
              creatorId: accountId,
              adminIds: [],
              totalMember: 2,
              currentMems: [
                { id: accountId, dName: 'Group Operator' },
                { id: 'mem-1', dName: 'Lê Hoàng' },
              ],
            },
          },
        };
      },
      sendMessage: async (payload: any) => {
        sentPayloads.push(payload);
        return { message: { msgId: 'grp-msg-1', cliMsgId: String(Date.now()) } };
      },
    } as any,
  });

  setAccountRateLimiterConfigForTest({ capacity: 1, refillMs: 500, maxWaitMs: 10 });
  const channel = new PersonalZcaChannel();

  // First group send resolves @Lê Hoàng and @All and caches group directory
  const firstRes = await channel.sendMessage({
    accountId,
    recipientId: groupId,
    threadType: 'group',
    message: '**Thông báo** @All và @Lê Hoàng nhé!',
    metadata: { source: 'chatbot' },
  });
  assert.equal(firstRes.success, true);
  assert.equal(groupInfoCalls, 1);
  assert.equal(sentPayloads.length, 1);
  assert.deepEqual(sentPayloads[0].mentions, [
    { pos: 'Thông báo '.length, len: 4, uid: '-1' },
    { pos: 'Thông báo @All và '.length, len: '@Lê Hoàng'.length, uid: 'mem-1' },
  ]);

  // Immediate second send hits RateLimitedError (capacity=1, refillMs=500, maxWaitMs=10)
  const secondRes = await channel.sendMessage({
    accountId,
    recipientId: groupId,
    threadType: 'group',
    message: 'Tin thứ 2',
    metadata: { source: 'campaign' },
  });
  assert.equal(secondRes.success, false);
  assert.equal(secondRes.errorCode, 'RATE_LIMITED');
  assert.ok((secondRes.retryAfterMs ?? 0) >= 10);

  // 3) Multi-chunk group send where chunk 1 succeeds and chunk 2 hits RateLimitedError returns partial: 1/2
  sentPayloads.length = 0;
  setAccountRateLimiterConfigForTest({ capacity: 1, refillMs: 5000, maxWaitMs: 10 });
  accountPool.get(accountId)!.rateLimiter = undefined;
  const twoChunkGroupMsg = `**Mục 1** @Lê Hoàng ${'a'.repeat(1850)}\n\n**Mục 2** @Lê Hoàng ${'b'.repeat(400)}`;
  const partialRateRes = await channel.sendMessage({
    accountId,
    recipientId: groupId,
    threadType: 'group',
    message: twoChunkGroupMsg,
    metadata: { source: 'chatbot' },
  });
  assert.equal(partialRateRes.success, true);
  assert.match(partialRateRes.error ?? '', /^partial: 1\/2 chunks sent/);

  // 4) Plain-text fallback on group send drops mentions as well as styles, and getGroupInfo throwing still sends without tags
  sentPayloads.length = 0;
  clearGroupMentionCacheForTest();
  setAccountRateLimiterConfigForTest({ capacity: 10, refillMs: 100, maxWaitMs: 1000 });
  accountPool.get(accountId)!.rateLimiter = undefined;
  let rejectStyledOnce = true;
  let throwGroupInfo = false;
  accountPool.get(accountId)!.api.getGroupInfo = async (gid: string) => {
    if (throwGroupInfo) throw new Error('group info network error');
    return {
      gridInfoMap: {
        [gid]: {
          creatorId: accountId,
          adminIds: [],
          totalMember: 2,
          currentMems: [
            { id: accountId, dName: 'Group Operator' },
            { id: 'mem-1', dName: 'Lê Hoàng' },
          ],
        },
      },
    };
  };
  accountPool.get(accountId)!.api.sendMessage = async (payload: any) => {
    sentPayloads.push(payload);
    if (rejectStyledOnce && payload.styles) {
      rejectStyledOnce = false;
      const err: any = new Error('style format invalid');
      err.code = 112;
      throw err;
    }
    return { message: { msgId: `grp-msg-${sentPayloads.length}`, cliMsgId: String(Date.now()) } };
  };

  const fallbackGroupRes = await channel.sendMessage({
    accountId,
    recipientId: groupId,
    threadType: 'group',
    message: '**Chào** @Lê Hoàng',
    metadata: { source: 'chatbot' },
  });
  assert.equal(fallbackGroupRes.success, true);
  assert.equal(sentPayloads.length, 2);
  assert.ok(Array.isArray(sentPayloads[0].mentions));
  assert.equal(sentPayloads[1].styles, undefined);
  assert.equal(sentPayloads[1].mentions, undefined);

  // When getGroupInfo throws on an uncached group, sendMessage still succeeds without mentions
  sentPayloads.length = 0;
  clearGroupMentionCacheForTest();
  throwGroupInfo = true;
  const noDirRes = await channel.sendMessage({
    accountId,
    recipientId: 'grp-uncached',
    threadType: 'group',
    message: 'Chào @Lê Hoàng',
    metadata: { source: 'chatbot' },
  });
  assert.equal(noDirRes.success, true);
  assert.equal(sentPayloads.length, 1);
  assert.equal(sentPayloads[0].mentions, undefined);
});
