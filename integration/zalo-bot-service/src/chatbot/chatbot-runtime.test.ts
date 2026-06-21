import test from 'node:test';
import assert from 'node:assert/strict';
import {
  LocalChatbotRuntime,
  type ChatbotRuntimeDependencies,
} from './chatbot-runtime.js';
import type { DebounceScheduler } from './chatbot-debounce.js';
import type {
  ChatbotEvaluationInput,
  ChatbotDecision,
} from './chatbot-engine.js';
import type { ChatbotConfigSnapshot } from './chatbot-types.js';
import type { ZaloInboundMessageEvent } from '../channels/types.js';

class FakeScheduler implements DebounceScheduler {
  readonly delays: number[] = [];
  private nextId = 1;

  set(_callback: () => void, delayMs: number): unknown {
    this.delays.push(delayMs);
    return this.nextId++;
  }

  clear(_handle: unknown): void {}
}

function snapshot(version: string): ChatbotConfigSnapshot {
  return {
    version,
    settings: {
      enabled: true,
      aiEnabled: false,
      personalAudience: 'all',
      groupAudience: 'tagOnly',
      handoffKeywords: [],
    },
    rules: [{
      id: 'rule-1',
      name: 'Pricing',
      keywords: ['bao gia'],
      matchMode: 'contains',
      response: 'Gia san pham',
      isActive: true,
      priority: 10,
      channelScope: 'all',
      handoffKeywords: [],
      businessHours: { enabled: false },
    }],
    scope: {
      crmThreadKeys: [],
      selectedGroupKeys: [],
    },
  };
}

function event(
  overrides: Partial<ZaloInboundMessageEvent> = {},
): ZaloInboundMessageEvent {
  return {
    accountId: 'account-1',
    threadId: 'group-1',
    threadType: 'group',
    senderId: 'customer-1',
    content: 'bao gia',
    messageType: 'text',
    providerMessageId: 'provider-1',
    timestamp: '2026-06-11T03:00:00.000Z',
    ...overrides,
  };
}

function createDependencies(
  scheduler: FakeScheduler,
  getSnapshot: () => ChatbotConfigSnapshot | undefined,
): {
  dependencies: ChatbotRuntimeDependencies;
  evaluations: ChatbotEvaluationInput[];
  dispatched: ChatbotDecision[];
  lifecycle: string[];
} {
  const evaluations: ChatbotEvaluationInput[] = [];
  const dispatched: ChatbotDecision[] = [];
  const lifecycle: string[] = [];
  const dependencies: ChatbotRuntimeDependencies = {
    scheduler,
    getConfigSnapshot: getSnapshot,
    getEffectiveConversationState: () => ({
      mode: 'enabled',
      reason: null,
      inherited: false,
    }),
    getConversationState: () => ({
      mode: 'enabled',
      reason: null,
      inherited: false,
    }),
    setConversationState: () => undefined,
    hasProcessedProviderMessage: () => false,
    evaluate: async (input) => {
      evaluations.push(input);
      return {
        kind: 'reply',
        mode: 'keyword',
        text: 'Gia san pham',
        ruleId: 'rule-1',
        sourceMessageIds: input.messages.map(
          (message) => message.providerMessageId,
        ),
      };
    },
    dispatch: async (input) => {
      dispatched.push(input.decision);
      return {
        status: 'sent',
        localMessageId: 'local-out-1',
        providerMessageId: 'provider-out-1',
      };
    },
    startConfigSync: () => lifecycle.push('sync:start'),
    stopConfigSync: () => lifecycle.push('sync:stop'),
  };
  return { dependencies, evaluations, dispatched, lifecycle };
}

test('debounces persisted live events for the default 20 seconds and loads the latest cached snapshot at flush', async () => {
  const scheduler = new FakeScheduler();
  let cachedSnapshot = snapshot('v1');
  const fixture = createDependencies(scheduler, () => cachedSnapshot);
  const runtime = new LocalChatbotRuntime(fixture.dependencies);
  runtime.start();

  runtime.handlePersistedInbound(event({
    providerMessageId: 'provider-1',
    content: 'bao',
    mentions: [{ uid: 'account-1' }],
  }), { managedGroup: true });
  runtime.handlePersistedInbound(event({
    providerMessageId: 'provider-2',
    content: 'gia',
    quote: { ownerId: 'account-1' },
  }), { managedGroup: true });
  cachedSnapshot = snapshot('v2');

  assert.deepEqual(scheduler.delays, [20000, 20000]);
  await runtime.flushConversation('account-1:group-1');

  assert.equal(fixture.evaluations.length, 1);
  assert.equal(fixture.evaluations[0]?.settings.enabled, true);
  assert.deepEqual(
    fixture.evaluations[0]?.messages.map(
      (message) => message.providerMessageId,
    ),
    ['provider-1', 'provider-2'],
  );
  assert.equal(fixture.evaluations[0]?.managedGroup, true);
  assert.equal(fixture.evaluations[0]?.mentionsBot, true);
  assert.equal(fixture.evaluations[0]?.quotesBot, true);
  assert.equal(fixture.dispatched.length, 1);
  runtime.stop();
  assert.deepEqual(fixture.lifecycle, ['sync:start', 'sync:stop']);
});

test('uses the configured debounce duration from the latest snapshot', () => {
  const scheduler = new FakeScheduler();
  const configuredSnapshot = snapshot('v1');
  configuredSnapshot.settings.debounceSeconds = 30;
  const fixture = createDependencies(scheduler, () => configuredSnapshot);
  const runtime = new LocalChatbotRuntime(fixture.dependencies);
  runtime.start();

  runtime.handlePersistedInbound(event(), { managedGroup: true });

  assert.deepEqual(scheduler.delays, [30000]);
  runtime.stop();
});

test('ignores history and self events and does not infer group triggers from ambiguous payloads', async () => {
  const scheduler = new FakeScheduler();
  const fixture = createDependencies(scheduler, () => snapshot('v1'));
  const runtime = new LocalChatbotRuntime(fixture.dependencies);
  runtime.start();

  runtime.handlePersistedInbound(event({
    providerMessageId: 'history-1',
  }), { isHistory: true, managedGroup: true });
  runtime.handlePersistedInbound(event({
    providerMessageId: 'self-1',
    senderId: 'account-1',
  }), { managedGroup: true });
  runtime.handlePersistedInbound(event({
    providerMessageId: 'live-1',
    mentions: [{ displayName: 'Bot' }],
    quote: { content: 'old bot text' },
  }));

  assert.deepEqual(scheduler.delays, [20000]);
  await runtime.flushConversation('account-1:group-1');

  assert.equal(fixture.evaluations.length, 1);
  assert.equal(fixture.evaluations[0]?.managedGroup, false);
  assert.equal(fixture.evaluations[0]?.mentionsBot, false);
  assert.equal(fixture.evaluations[0]?.quotesBot, false);
});
