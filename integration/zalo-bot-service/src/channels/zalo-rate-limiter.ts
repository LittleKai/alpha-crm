// Adapted from https://github.com/luonghaianh1208/2anh-zalo-bot@9ab55105c83487588e66b55f0ef66894224250a7 (MIT License)

import { performance } from 'node:perf_hooks';

export type RateLimitPriority = 'high' | 'normal';

export class RateLimitedError extends Error {
  readonly code = 'RATE_LIMITED' as const;
  readonly waitMs: number;

  constructor(waitMs: number) {
    const sec = Math.ceil(waitMs / 1000);
    super(
      `Zalo đang bận (${sec}s) — tạm hoãn thao tác nền để giữ an toàn tài khoản / Zalo rate limit busy (${sec}s) — please retry shortly`,
    );
    this.name = 'RateLimitedError';
    this.waitMs = waitMs;
  }
}

export interface ZaloRateLimiter {
  acquire(
    priority?: RateLimitPriority,
  ): Promise<{ waitedMs: number; priority: RateLimitPriority }>;
  state(): {
    tokens: number;
    highQueued: number;
    normalQueued: number;
  };
  dispose(): void;
}

interface QueuedWaiter {
  enqueuedAt: number;
  priority: RateLimitPriority;
  deadlineTimer: ReturnType<typeof setTimeout> | null;
  settled: boolean;
  resolve: (value: { waitedMs: number; priority: RateLimitPriority }) => void;
  reject: (reason: unknown) => void;
}

/**
 * Per-account two-lane priority token-bucket outbound rate limiter.
 *
 * - Default clock uses `performance.now()` so `runWithFixedDateNow` (`Date.now`
 *   pinning during `zca-js` message dispatch) never freezes token refills.
 * - Uses fractional token refill (`tokens = Math.min(capacity, tokens + elapsed / refillMs)`).
 * - Drains `'high'` priority waiters (interactive Live Chat & Chatbot replies)
 *   ahead of `'normal'` priority waiters (bulk campaigns, friend requests, group invites).
 * - Enforces both an up-front `projectedWait > maxWaitMs` fail-fast reject and a
 *   per-waiter deadline timer (`maxWaitMs`) so a `'normal'` waiter starved by later
 *   `'high'` arrivals also rejects cleanly with `RateLimitedError`.
 */
export function createZaloRateLimiter(opts?: {
  capacity?: number;
  refillMs?: number;
  maxWaitMs?: number;
  now?: () => number;
}): ZaloRateLimiter {
  const capacity = Math.max(1, Number(opts?.capacity) || 5);
  const refillMs = Math.max(1, Number(opts?.refillMs) || 3000);
  const maxWaitMs =
    opts?.maxWaitMs === undefined ? 20_000 : Number(opts.maxWaitMs);
  const now = opts?.now ?? (() => performance.now());

  let tokens = capacity;
  let lastRefill = now();
  let drainTimer: ReturnType<typeof setTimeout> | null = null;
  let disposed = false;
  const highQueue: QueuedWaiter[] = [];
  const normalQueue: QueuedWaiter[] = [];

  function refill(): void {
    const t = now();
    const elapsed = Math.max(0, t - lastRefill);
    if (elapsed <= 0) return;
    tokens = Math.min(capacity, tokens + elapsed / refillMs);
    lastRefill = t;
  }

  function nextWaiter(): QueuedWaiter | undefined {
    while (highQueue.length > 0) {
      const w = highQueue.shift()!;
      if (!w.settled) return w;
    }
    while (normalQueue.length > 0) {
      const w = normalQueue.shift()!;
      if (!w.settled) return w;
    }
    return undefined;
  }

  function hasPendingWaiters(): boolean {
    return (
      highQueue.some((w) => !w.settled) || normalQueue.some((w) => !w.settled)
    );
  }

  function scheduleDrain(): void {
    if (disposed || drainTimer !== null) return;
    if (!hasPendingWaiters()) return;
    const waitMs = Math.max(1, Math.ceil((1 - tokens) * refillMs));
    drainTimer = setTimeout(() => {
      drainTimer = null;
      drain();
    }, waitMs);
  }

  function drain(): void {
    if (disposed) return;
    refill();
    while (tokens >= 1) {
      const w = nextWaiter();
      if (!w) break;
      w.settled = true;
      if (w.deadlineTimer) {
        clearTimeout(w.deadlineTimer);
        w.deadlineTimer = null;
      }
      tokens -= 1;
      const waitedMs = Math.max(0, Math.round(now() - w.enqueuedAt));
      w.resolve({ waitedMs, priority: w.priority });
    }
    if (hasPendingWaiters()) {
      scheduleDrain();
    }
  }

  return {
    acquire(
      priority: RateLimitPriority = 'normal',
    ): Promise<{ waitedMs: number; priority: RateLimitPriority }> {
      if (disposed) {
        return Promise.reject(new RateLimitedError(refillMs));
      }
      const lane: RateLimitPriority = priority === 'high' ? 'high' : 'normal';
      refill();
      if (tokens >= 1 && !hasPendingWaiters()) {
        tokens -= 1;
        return Promise.resolve({ waitedMs: 0, priority: lane });
      }

      const activeHigh = highQueue.filter((w) => !w.settled).length;
      const activeNormal = normalQueue.filter((w) => !w.settled).length;
      const ahead = lane === 'high' ? activeHigh : activeHigh + activeNormal;
      const projectedWait = Math.ceil((ahead + 1 - tokens) * refillMs);
      if (maxWaitMs >= 0 && projectedWait > maxWaitMs) {
        return Promise.reject(new RateLimitedError(projectedWait));
      }

      return new Promise((resolve, reject) => {
        const waiter: QueuedWaiter = {
          enqueuedAt: now(),
          priority: lane,
          deadlineTimer: null,
          settled: false,
          resolve,
          reject,
        };
        if (maxWaitMs >= 0 && Number.isFinite(maxWaitMs)) {
          waiter.deadlineTimer = setTimeout(() => {
            if (waiter.settled) return;
            waiter.settled = true;
            waiter.deadlineTimer = null;
            const waited = Math.max(
              maxWaitMs,
              Math.round(now() - waiter.enqueuedAt),
            );
            waiter.reject(new RateLimitedError(waited));
          }, Math.max(1, maxWaitMs));
        }
        if (lane === 'high') {
          highQueue.push(waiter);
        } else {
          normalQueue.push(waiter);
        }
        scheduleDrain();
      });
    },

    state() {
      refill();
      return {
        tokens,
        highQueued: highQueue.filter((w) => !w.settled).length,
        normalQueued: normalQueue.filter((w) => !w.settled).length,
      };
    },

    dispose() {
      disposed = true;
      if (drainTimer) {
        clearTimeout(drainTimer);
        drainTimer = null;
      }
      for (const q of [highQueue, normalQueue]) {
        while (q.length > 0) {
          const w = q.shift()!;
          if (w.settled) continue;
          w.settled = true;
          if (w.deadlineTimer) {
            clearTimeout(w.deadlineTimer);
            w.deadlineTimer = null;
          }
          w.reject(new RateLimitedError(refillMs));
        }
      }
    },
  };
}
