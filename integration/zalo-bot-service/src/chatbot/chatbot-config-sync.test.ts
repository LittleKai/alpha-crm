import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { LocalChatStore } from '../local-chat/local-chat-store.js';
import { ChatbotStore } from './chatbot-store.js';
import { ChatbotConfigSync } from './chatbot-config-sync.js';
import type { ChatbotConfigSnapshot } from './chatbot-types.js';

test('syncNow stores a valid cloud snapshot and updates status', async () => {
  const fixture = createFixture();
  try {
    const snapshot = config('v1');
    const sync = new ChatbotConfigSync({
      store: fixture.chatbotStore,
      api: { fetchConfig: async () => snapshot },
      now: () => 100,
    });

    assert.deepEqual(await sync.syncNow(), snapshot);
    assert.deepEqual(fixture.chatbotStore.getConfigSnapshot(), snapshot);
    assert.deepEqual(sync.getStatus(), {
      running: false,
      configVersion: 'v1',
      lastSyncedAt: 100,
      lastError: null,
    });
  } finally {
    fixture.close();
  }
});

test('failed refresh preserves the last valid cached snapshot', async () => {
  const fixture = createFixture();
  try {
    fixture.chatbotStore.saveConfigSnapshot(config('cached'));
    const sync = new ChatbotConfigSync({
      store: fixture.chatbotStore,
      api: {
        fetchConfig: async () => {
          throw new Error('offline');
        },
      },
    });

    await assert.rejects(() => sync.syncNow(), /offline/);
    assert.equal(
      fixture.chatbotStore.getConfigSnapshot()?.version,
      'cached',
    );
    assert.equal(sync.getStatus().lastError, 'offline');
  } finally {
    fixture.close();
  }
});

test('start exposes cached config immediately and refreshes in background', async () => {
  const fixture = createFixture();
  try {
    fixture.chatbotStore.saveConfigSnapshot(config('cached'));
    let resolveFetch: ((value: ChatbotConfigSnapshot) => void) | undefined;
    const sync = new ChatbotConfigSync({
      store: fixture.chatbotStore,
      api: {
        fetchConfig: () => new Promise((resolve) => {
          resolveFetch = resolve;
        }),
      },
      setIntervalFn: () => 1,
      clearIntervalFn: () => {},
    });

    sync.start();
    assert.deepEqual(sync.getStatus(), {
      running: true,
      configVersion: 'cached',
      lastSyncedAt: null,
      lastError: null,
    });

    resolveFetch?.(config('fresh'));
    await new Promise((resolve) => setImmediate(resolve));
    assert.equal(sync.getStatus().configVersion, 'fresh');

    sync.stop();
    assert.equal(sync.getStatus().running, false);
  } finally {
    fixture.close();
  }
});

function config(version: string): ChatbotConfigSnapshot {
  return {
    version,
    settings: { enabled: true },
    rules: [],
    scope: { crmThreadKeys: [], selectedGroupKeys: [] },
  };
}

function createFixture(): {
  chatbotStore: ChatbotStore;
  close: () => void;
} {
  const directory = mkdtempSync(join(tmpdir(), 'chatbot-sync-'));
  const localStore = new LocalChatStore(join(directory, 'test.sqlite'));
  return {
    chatbotStore: new ChatbotStore(localStore.db),
    close: () => {
      localStore.close();
      rmSync(directory, { recursive: true, force: true });
    },
  };
}

