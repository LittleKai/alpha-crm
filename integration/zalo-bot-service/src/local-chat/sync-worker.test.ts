import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

test('sync worker reports sent/delivered/seen, gates unsent groups and retries cloud failures', async (t) => {
  const directory = mkdtempSync(join(tmpdir(), 'alpha-sync-worker-'));
  const previousDataRoot = process.env.ALPHA_CRM_DATA_DIR;
  process.env.ALPHA_CRM_DATA_DIR = directory;
  const { config } = await import('../config.js');
  const { LocalChatMediaWorker } = await import('./local-chat-media-worker.js');
  const { getLocalChatStore, closeLocalChatStore } = await import('./index.js');
  const { startBackgroundSync, stopBackgroundSync } = await import('./sync-worker.js');
  const originalConfig = {
    localChatDbPath: config.localChatDbPath, localFirstLiveChat: config.localFirstLiveChat,
    crmAgentSecretPath: config.crmAgentSecretPath, crmCloudApiUrl: config.crmCloudApiUrl,
  };
  config.localFirstLiveChat = true;
  config.localChatDbPath = join(directory, 'chat.sqlite');
  config.crmAgentSecretPath = join(directory, 'device-secret.json');
  config.crmCloudApiUrl = 'https://cloud.invalid/api';
  writeFileSync(config.crmAgentSecretPath, JSON.stringify({ userId: 'test-user', deviceId: 'test-device', agentSecret: 'test-secret' }));
  t.after(() => {
    stopBackgroundSync(); closeLocalChatStore(); Object.assign(config, originalConfig);
    if (previousDataRoot === undefined) delete process.env.ALPHA_CRM_DATA_DIR;
    else process.env.ALPHA_CRM_DATA_DIR = previousDataRoot;
    rmSync(directory, { recursive: true, force: true });
  });
  // Media downloads have a separate lifecycle; only the sync worker runs here.
  t.mock.method(LocalChatMediaWorker.prototype, 'start', () => {});
  const store = getLocalChatStore()!;
  const reports: any[] = [];
  let rejectReports = false;
  t.mock.method(globalThis, 'fetch', async (url: string, options: RequestInit) => {
    assert.ok(String(url).startsWith('https://cloud.invalid/api/'));
    if (String(url).endsWith('/groups/managed')) {
      return new Response(JSON.stringify({ success: true, data: [
        { accountId: 'operator', groupId: 'managed-group' },
      ] }));
    }
    assert.ok(String(url).endsWith('/events/message'));
    if (rejectReports) return new Response(JSON.stringify({ success: false, message: 'offline' }), { status: 503 });
    reports.push(JSON.parse(String(options.body)));
    return new Response(JSON.stringify({ success: true, data: {} }));
  });
  let tick!: () => Promise<void>;
  t.mock.method(globalThis, 'setInterval', (callback: () => Promise<void>, milliseconds: number) => {
    assert.equal(milliseconds, 5000);
    tick = callback;
    return {} as NodeJS.Timeout;
  });
  startBackgroundSync();
  const insert = (threadType: 'user' | 'group', status: string) => {
    const messageId = store.insertOutboundMessage({
      accountId: 'operator', threadId: threadType === 'group' ? 'managed-group' : 'customer',
      threadType, content: `private-${status}`, clientMessageId: `${threadType}-${status}`,
    });
    store.updateMessageStatus(messageId, 'sent', `provider-${threadType}-${status}`);
    if (status !== 'sent') store.updateMessageStatus(messageId, status);
    // Only exercise durable message jobs, not conversation metadata jobs.
    store.db.prepare("DELETE FROM sync_queue WHERE action = 'sync_conversation'").run();
    return messageId;
  };
  for (const threadType of ['user', 'group'] as const) {
    for (const status of ['sent', 'delivered', 'seen', 'queued', 'failed']) insert(threadType, status);
  }
  await tick();
  assert.deepEqual(reports.map((event) => event.providerMessageId).sort(), [
    'provider-group-delivered', 'provider-group-seen', 'provider-group-sent',
    'provider-user-delivered', 'provider-user-seen', 'provider-user-sent',
  ]);
  assert.ok(reports.filter((event) => event.threadType === 'group').every((event) =>
    event.content === undefined && event.lastMessagePreview === '' && event.unreadCountDelta === 0));
  assert.equal(store.getPendingSyncActions(50).length, 0);

  // A queued send acknowledged above gets a new durable job once the send succeeds.
  const queued = store.db.prepare("SELECT id FROM messages WHERE clientMessageId = 'user-queued'").get() as { id: string };
  store.updateMessageStatus(queued.id, 'sent', 'provider-retried-send');
  rejectReports = true;
  await tick();
  const retry = store.db.prepare('SELECT * FROM sync_queue').get() as { id: string; retryCount: number; nextRetryAt: string };
  assert.equal(retry.retryCount, 1);
  assert.ok(Date.parse(retry.nextRetryAt) > Date.now());
  store.updateMessageStatus(queued.id, 'seen');
  store.db.prepare('UPDATE sync_queue SET nextRetryAt = ? WHERE id = ?').run('2000-01-01T00:00:00.000Z', retry.id);
  rejectReports = false;
  await tick();
  assert.equal(reports.at(-1)?.providerMessageId, 'provider-retried-send');
  assert.equal(reports.at(-1)?.content, 'private-queued');
  assert.equal(store.getPendingSyncActions(50).length, 0);
});
