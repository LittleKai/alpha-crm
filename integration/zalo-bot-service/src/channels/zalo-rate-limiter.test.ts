// Adapted from https://github.com/luonghaianh1208/2anh-zalo-bot@9ab55105c83487588e66b55f0ef66894224250a7 (MIT License)

import assert from 'node:assert/strict';
import test from 'node:test';

import {
  RateLimitedError,
  createZaloRateLimiter,
} from './zalo-rate-limiter.js';

test('createZaloRateLimiter allows immediate burst up to capacity and drains high priority before normal priority', async () => {
  const limiter = createZaloRateLimiter({
    capacity: 2,
    refillMs: 30,
    maxWaitMs: 500,
  });

  try {
    const first = await limiter.acquire('normal');
    const second = await limiter.acquire('normal');
    assert.equal(first.waitedMs, 0);
    assert.equal(second.waitedMs, 0);

    const order: string[] = [];
    const pNormal = limiter.acquire('normal').then((res) => {
      order.push(`normal:${res.priority}`);
      return res;
    });
    const pHigh = limiter.acquire('high').then((res) => {
      order.push(`high:${res.priority}`);
      return res;
    });

    await Promise.all([pNormal, pHigh]);
    assert.deepEqual(order, ['high:high', 'normal:normal']);
  } finally {
    limiter.dispose();
  }
});

test('createZaloRateLimiter rejects up-front when projectedWait exceeds maxWaitMs and rejects starved normal waiter via deadline timer', async () => {
  const limiter = createZaloRateLimiter({
    capacity: 1,
    refillMs: 60,
    maxWaitMs: 80,
  });

  try {
    await limiter.acquire('high'); // consumes the 1 token

    // Queuing 1st waiter requires ~60ms (<= 80ms), queuing 2nd requires ~120ms (> 80ms -> up-front reject)
    const firstQueued = limiter.acquire('normal');
    await assert.rejects(
      () => limiter.acquire('normal'),
      (err: any) =>
        err instanceof RateLimitedError &&
        err.code === 'RATE_LIMITED' &&
        err.waitMs >= 80,
    );

    // Now starve firstQueued ('normal') by inserting a 'high' waiter after 20ms when tokens ~ 0.33
    await new Promise((r) => setTimeout(r, 25));
    const preemptHigh = limiter.acquire('high');
    await preemptHigh;
    await assert.rejects(
      () => firstQueued,
      (err: any) =>
        err instanceof RateLimitedError && err.code === 'RATE_LIMITED',
    );
  } finally {
    limiter.dispose();
  }
});

test('createZaloRateLimiter default performance.now clock is unaffected when global Date.now is pinned', async () => {
  const limiter = createZaloRateLimiter({
    capacity: 1,
    refillMs: 25,
    maxWaitMs: 500,
  });
  const realDateNow = Date.now;
  try {
    await limiter.acquire('high'); // bucket empty
    Date.now = () => 1_700_000_000_000; // simulate runWithFixedDateNow pinning Date.now
    const refilled = await limiter.acquire('high');
    assert.ok(refilled.waitedMs >= 15);
  } finally {
    Date.now = realDateNow;
    limiter.dispose();
  }
});
