import test from 'node:test';
import assert from 'node:assert/strict';
import {
  LocalChatbotEngine,
  type ChatbotEvaluationInput,
  type ChatbotRule,
} from './chatbot-engine.js';

const baseRule: ChatbotRule = {
  id: 'rule-1',
  name: 'Pricing',
  keywords: ['báo giá'],
  matchMode: 'contains',
  response: 'Bảng giá đây.',
  isActive: true,
  priority: 10,
  channelScope: 'all',
  handoffKeywords: [],
  businessHours: { enabled: false },
};

function input(
  overrides: Partial<ChatbotEvaluationInput> = {},
): ChatbotEvaluationInput {
  return {
    conversationKey: 'account-1:user-1',
    threadType: 'user',
    messages: [
      {
        providerMessageId: 'message-1',
        content: 'Cho tôi xin báo giá',
        messageType: 'text',
        timestamp: '2026-06-11T03:00:00.000Z',
      },
    ],
    settings: {
      enabled: true,
      aiEnabled: false,
      personalAudience: 'all',
      groupAudience: 'none',
      handoffKeywords: ['gặp nhân viên'],
    },
    rules: [baseRule],
    scope: {
      crmThreadKeys: new Set(),
      selectedGroupKeys: new Set(),
    },
    conversationMode: 'enabled',
    managedGroup: false,
    mentionsBot: false,
    quotesBot: false,
    isProcessed: () => false,
    ...overrides,
  };
}

test('matches Vietnamese keywords without accents and combines source ids', async () => {
  const engine = new LocalChatbotEngine();
  const result = await engine.evaluate(input({
    messages: [
      {
        providerMessageId: 'message-1',
        content: 'Cho tôi xin',
        messageType: 'text',
        timestamp: '2026-06-11T03:00:00.000Z',
      },
      {
        providerMessageId: 'message-2',
        content: 'bao gia',
        messageType: 'text',
        timestamp: '2026-06-11T03:00:01.000Z',
      },
    ],
  }));

  assert.deepEqual(result, {
    kind: 'reply',
    mode: 'keyword',
    text: 'Bảng giá đây.',
    ruleId: 'rule-1',
    sourceMessageIds: ['message-1', 'message-2'],
  });
});

test('handoff keyword wins and produces no reply', async () => {
  const engine = new LocalChatbotEngine();
  const result = await engine.evaluate(input({
    messages: [{
      providerMessageId: 'message-1',
      content: 'Tôi muốn GAP NHAN VIEN',
      messageType: 'text',
      timestamp: '2026-06-11T03:00:00.000Z',
    }],
  }));

  assert.equal(result.kind, 'handoff');
});

test('personal crmOnly audience rejects threads outside cached CRM scope', async () => {
  const engine = new LocalChatbotEngine();
  const result = await engine.evaluate(input({
    settings: {
      ...input().settings,
      personalAudience: 'crmOnly',
    },
  }));

  assert.deepEqual(result, {
    kind: 'skipped',
    reason: 'personal_audience',
    sourceMessageIds: ['message-1'],
  });
});

test('group requires managed scope and mention or quote', async () => {
  const engine = new LocalChatbotEngine();
  const groupInput = input({
    conversationKey: 'account-1:group-1',
    threadType: 'group',
    managedGroup: true,
    settings: {
      ...input().settings,
      groupAudience: 'tagOnly',
    },
  });

  assert.equal((await engine.evaluate(groupInput)).kind, 'skipped');
  assert.equal((await engine.evaluate({
    ...groupInput,
    mentionsBot: true,
  })).kind, 'reply');
});

test('selected group audience requires cached selected key', async () => {
  const engine = new LocalChatbotEngine();
  const result = await engine.evaluate(input({
    conversationKey: 'account-1:group-1',
    threadType: 'group',
    managedGroup: true,
    mentionsBot: true,
    settings: {
      ...input().settings,
      groupAudience: 'selected',
    },
    scope: {
      crmThreadKeys: new Set(),
      selectedGroupKeys: new Set(),
    },
  }));

  assert.equal(result.kind, 'skipped');
});

test('explicit disabled and handoff states reject evaluation', async () => {
  const engine = new LocalChatbotEngine();

  assert.equal(
    (await engine.evaluate(input({
      conversationMode: 'disabled_by_operator',
    }))).kind,
    'skipped',
  );
  assert.equal(
    (await engine.evaluate(input({ conversationMode: 'handoff' }))).kind,
    'skipped',
  );
});

test('ignores duplicate, non-text, and self messages', async () => {
  const engine = new LocalChatbotEngine();

  assert.equal(
    (await engine.evaluate(input({ isProcessed: () => true }))).kind,
    'skipped',
  );
  assert.equal(
    (await engine.evaluate(input({
      messages: [{ ...input().messages[0]!, messageType: 'image' }],
    }))).kind,
    'skipped',
  );
  assert.equal(
    (await engine.evaluate(input({
      messages: [{ ...input().messages[0]!, isSelf: true }],
    }))).kind,
    'skipped',
  );
});

test('uses the lowest priority number among active in-hours rules', async () => {
  const engine = new LocalChatbotEngine();
  const result = await engine.evaluate(input({
    now: new Date('2026-06-11T03:00:00.000Z'),
    rules: [
      { ...baseRule, id: 'later', priority: 100, response: 'later' },
      {
        ...baseRule,
        id: 'closed',
        priority: 1,
        response: 'closed',
        businessHours: {
          enabled: true,
          timezone: 'Asia/Ho_Chi_Minh',
          days: [4],
          start: '18:00',
          end: '19:00',
        },
      },
      { ...baseRule, id: 'first', priority: 10, response: 'first' },
    ],
  }));

  assert.equal(result.kind, 'reply');
  if (result.kind === 'reply') {
    assert.equal(result.ruleId, 'first');
  }
});

test('calls AI only when no rule matches and returns text reply', async () => {
  const engine = new LocalChatbotEngine();
  let calls = 0;
  const result = await engine.evaluate(input({
    settings: { ...input().settings, aiEnabled: true },
    rules: [],
    generateAi: async () => {
      calls += 1;
      return { reply: 'AI response' };
    },
  }));

  assert.equal(calls, 1);
  assert.deepEqual(result, {
    kind: 'reply',
    mode: 'ai',
    text: 'AI response',
    sourceMessageIds: ['message-1'],
  });
});

test('AI failure enters failed handoff without fallback', async () => {
  const engine = new LocalChatbotEngine();
  const result = await engine.evaluate(input({
    settings: { ...input().settings, aiEnabled: true },
    rules: [],
    generateAi: async () => {
      throw new Error('quota exceeded');
    },
  }));

  assert.deepEqual(result, {
    kind: 'failed',
    reason: 'ai_failed',
    error: 'quota exceeded',
    enterHandoff: true,
    sourceMessageIds: ['message-1'],
  });
});

