import { afterEach, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { ChatbotStore } from './chatbot-store.js';
import type { ChatbotConfigSnapshot } from './chatbot-types.js';
import { LocalChatStore } from '../local-chat/local-chat-store.js';

let chatbotStore: ChatbotStore;
let localStore: LocalChatStore;
let dbPath: string;
let tmpDir: string;

function openStores(): void {
  localStore = new LocalChatStore(dbPath);
  chatbotStore = new ChatbotStore(localStore.db, () => 1_717_243_200_000);
}

function restartStores(): void {
  localStore.close();
  openStores();
}

describe('ChatbotStore', () => {
  beforeEach(() => {
    tmpDir = mkdtempSync(join(tmpdir(), 'chatbot-store-test-'));
    dbPath = join(tmpDir, 'test.sqlite');
    openStores();
  });

  afterEach(() => {
    localStore.close();
    rmSync(tmpDir, { recursive: true, force: true });
  });

  it('persists explicit conversation modes across restart', () => {
    chatbotStore.setConversationState('acc:enabled', {
      mode: 'enabled',
      reason: null,
      inherited: false,
    });
    chatbotStore.setConversationState('acc:handoff', {
      mode: 'handoff',
      reason: 'requested_human',
      inherited: false,
    });
    chatbotStore.setConversationState('acc:operator', {
      mode: 'disabled_by_operator',
      reason: 'manual_operator_reply',
      inherited: false,
    });

    restartStores();

    assert.deepEqual(chatbotStore.getConversationState('acc:enabled'), {
      mode: 'enabled',
      reason: null,
      inherited: false,
    });
    assert.deepEqual(chatbotStore.getConversationState('acc:handoff'), {
      mode: 'handoff',
      reason: 'requested_human',
      inherited: false,
    });
    assert.deepEqual(chatbotStore.getConversationState('acc:operator'), {
      mode: 'disabled_by_operator',
      reason: 'manual_operator_reply',
      inherited: false,
    });
  });

  it('represents inherited conversation state', () => {
    chatbotStore.setConversationState('acc:new-user', {
      mode: 'enabled',
      reason: 'global_personal_audience',
      inherited: true,
    });

    assert.deepEqual(chatbotStore.getConversationState('acc:new-user'), {
      mode: 'enabled',
      reason: 'global_personal_audience',
      inherited: true,
    });
  });

  it('resolves a new personal conversation from the global all audience', () => {
    const snapshot = createSnapshot('v1', 'rule-1');

    assert.deepEqual(
      chatbotStore.getEffectiveConversationState(
        'acc:new-user',
        'user',
        snapshot,
      ),
      {
        mode: 'enabled',
        reason: 'global_personal_audience',
        inherited: true,
      },
    );
    assert.equal(
      chatbotStore.getConversationState('acc:new-user'),
      undefined,
    );
  });

  it('resolves crmOnly personal audience only for scoped conversations', () => {
    const snapshot = createSnapshot('v1', 'rule-1');
    snapshot.settings.personalAudience = 'crmOnly';

    assert.deepEqual(
      chatbotStore.getEffectiveConversationState(
        'acc:user',
        'user',
        snapshot,
      ),
      {
        mode: 'enabled',
        reason: 'crm_personal_audience',
        inherited: true,
      },
    );
    assert.equal(
      chatbotStore.getEffectiveConversationState(
        'acc:outside',
        'user',
        snapshot,
      ),
      undefined,
    );
  });

  it('prefers explicit conversation state over inherited audience state', () => {
    const snapshot = createSnapshot('v1', 'rule-1');
    chatbotStore.setConversationState('acc:user', {
      mode: 'handoff',
      reason: 'requested_human',
      inherited: false,
    });

    assert.deepEqual(
      chatbotStore.getEffectiveConversationState('acc:user', 'user', snapshot),
      {
        mode: 'handoff',
        reason: 'requested_human',
        inherited: false,
      },
    );
  });

  it('atomically replaces a versioned config snapshot', () => {
    const first = createSnapshot('v1', 'rule-1');
    const second = createSnapshot('v2', 'rule-2');

    chatbotStore.saveConfigSnapshot(first);
    chatbotStore.saveConfigSnapshot(second);

    assert.deepEqual(chatbotStore.getConfigSnapshot(), second);
    const rows = localStore.db
      .prepare('SELECT COUNT(*) AS count FROM chatbot_config_snapshot')
      .get() as { count: number };
    assert.equal(rows.count, 1);
  });

  it('keeps the previous config when replacement validation fails', () => {
    const valid = createSnapshot('v1', 'rule-1');
    chatbotStore.saveConfigSnapshot(valid);

    assert.throws(
      () => chatbotStore.saveConfigSnapshot({
        ...createSnapshot('v2', 'rule-2'),
        rules: [{ id: 'broken', keywords: 'not-an-array' }],
      } as unknown as ChatbotConfigSnapshot),
      /Invalid chatbot config snapshot/,
    );
    assert.deepEqual(chatbotStore.getConfigSnapshot(), valid);
  });

  it('rejects invalid optional chatbot settings fields', () => {
    const invalidSettings: Array<[string, unknown]> = [
      ['personalAudience', 'everyone'],
      ['handoffKeywords', 'gap nhan vien'],
      ['aiEnabled', 'yes'],
      ['groupAudience', 'all'],
      ['debounceSeconds', 1],
      ['debounceSeconds', 16],
      ['debounceSeconds', '5'],
    ];

    for (const [field, value] of invalidSettings) {
      const snapshot = createSnapshot('invalid-settings', 'rule-1');
      (snapshot.settings as unknown as Record<string, unknown>)[field] = value;

      assert.throws(
        () => chatbotStore.saveConfigSnapshot(snapshot),
        /Invalid chatbot config snapshot/,
        field,
      );
    }
  });

  it('rejects invalid optional chatbot rule fields', () => {
    const invalidRules: Array<[string, unknown]> = [
      ['matchMode', 'regex'],
      ['channelScope', 'personal'],
      ['businessHours', 'always'],
      ['businessHours', { enabled: 'yes' }],
      ['businessHours', { enabled: true, timezone: 7 }],
      ['businessHours', { enabled: true, days: ['monday'] }],
      ['businessHours', { enabled: true, start: 8 }],
      ['businessHours', { enabled: true, end: 18 }],
    ];

    for (const [field, value] of invalidRules) {
      const snapshot = createSnapshot('invalid-rule', 'rule-1');
      (snapshot.rules[0] as unknown as Record<string, unknown>)[field] = value;

      assert.throws(
        () => chatbotStore.saveConfigSnapshot(snapshot),
        /Invalid chatbot config snapshot/,
        `${field}: ${JSON.stringify(value)}`,
      );
    }
  });

  it('deduplicates audit queue entries by idempotency key', () => {
    const payload = {
      outcome: 'keyword',
      conversationKey: 'acc:user',
      timestamp: 1_717_243_200_000,
    } as const;

    assert.equal(chatbotStore.enqueueAudit('audit-1', payload), true);
    assert.equal(chatbotStore.enqueueAudit('audit-1', payload), false);
    assert.deepEqual(chatbotStore.listPendingAudits(), [
      {
        idempotencyKey: 'audit-1',
        payload,
        attempts: 0,
        createdAt: 1_717_243_200_000,
        lastError: null,
      },
    ]);
  });

  it('remembers the last processed provider message id across restart', () => {
    chatbotStore.setConversationState('acc:user', {
      mode: 'enabled',
      reason: null,
      inherited: true,
    });
    chatbotStore.markProviderMessageProcessed('acc:user', 'provider-123');

    restartStores();

    assert.equal(
      chatbotStore.hasProcessedProviderMessage('acc:user', 'provider-123'),
      true,
    );
    assert.equal(
      chatbotStore.hasProcessedProviderMessage('acc:user', 'provider-456'),
      false,
    );
  });

  it('records a provider message id without inventing enabled state', () => {
    chatbotStore.markProviderMessageProcessed('acc:unknown', 'provider-1');

    assert.equal(chatbotStore.getConversationState('acc:unknown'), undefined);
    assert.equal(
      chatbotStore.hasProcessedProviderMessage('acc:unknown', 'provider-1'),
      true,
    );
  });

  it('remembers every processed provider id for a conversation', () => {
    chatbotStore.markProviderMessageProcessed('acc:user', 'provider-1');
    chatbotStore.markProviderMessageProcessed('acc:user', 'provider-2');

    assert.equal(
      chatbotStore.hasProcessedProviderMessage('acc:user', 'provider-1'),
      true,
    );
    assert.equal(
      chatbotStore.hasProcessedProviderMessage('acc:user', 'provider-2'),
      true,
    );
  });

  it('rejects invalid persisted config JSON', () => {
    localStore.db
      .prepare(
        `INSERT INTO chatbot_config_snapshot
         (singleton_id, version, payload_json, synced_at)
         VALUES (1, 'broken', '{', 1717243200000)`,
      )
      .run();

    assert.throws(
      () => chatbotStore.getConfigSnapshot(),
      /Invalid chatbot config snapshot JSON/,
    );
  });
});

function createSnapshot(
  version: string,
  ruleId: string,
): ChatbotConfigSnapshot {
  return {
    version,
    settings: {
      enabled: true,
      personalAudience: 'all',
      handoffKeywords: ['gap nhan vien'],
    },
    rules: [
      {
        id: ruleId,
        keywords: ['bao gia'],
        response: 'Gia san pham',
        priority: 10,
      },
    ],
    scope: {
      crmThreadKeys: ['acc:user'],
      selectedGroupKeys: [],
    },
  };
}
