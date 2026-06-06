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
