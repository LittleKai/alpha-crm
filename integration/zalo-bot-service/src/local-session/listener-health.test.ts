import test from 'node:test';
import assert from 'node:assert/strict';
import {
  ListenerHealthMonitor,
  shouldRecoverZaloListener,
} from './listener-health.js';
import type { ZaloChannelStatus } from '../channels/types.js';

function status(
  connected: boolean,
  listenerRunning: boolean,
): ZaloChannelStatus {
  return {
    connected,
    listenerRunning,
    mode: connected ? 'personal_zca' : 'disconnected',
    accountType: connected ? 'personal' : 'none',
    accountLabel: '',
    lastEventAt: null,
  };
}

test('listener recovery is needed only for a connected account with a stopped listener', () => {
  assert.equal(shouldRecoverZaloListener(status(true, false)), true);
  assert.equal(shouldRecoverZaloListener(status(true, true)), false);
  assert.equal(shouldRecoverZaloListener(status(false, false)), false);
});

test('multi-account: account-aware hint recovers a down listener even if another account is up', () => {
  // Pool-level listenerRunning is true (account A up) but account B is down:
  // the coarse signal alone would miss it, the hint catches it.
  assert.equal(
    shouldRecoverZaloListener({ ...status(true, true), needsListenerRecovery: true }),
    true,
  );
  // All live accounts listening → no recovery.
  assert.equal(
    shouldRecoverZaloListener({ ...status(true, true), needsListenerRecovery: false }),
    false,
  );
  // Not connected (all expired) → never recover, regardless of the hint.
  assert.equal(
    shouldRecoverZaloListener({ ...status(false, false), needsListenerRecovery: true }),
    false,
  );
});

test('health monitor coalesces concurrent listener recovery attempts', async () => {
  let recoveries = 0;
  let release!: () => void;
  const blocked = new Promise<void>((resolve) => {
    release = resolve;
  });
  const monitor = new ListenerHealthMonitor(
    () => status(true, false),
    async () => {
      recoveries += 1;
      await blocked;
    },
  );

  const first = monitor.check();
  const second = monitor.check();
  assert.equal(recoveries, 1);
  release();
  await Promise.all([first, second]);
});
