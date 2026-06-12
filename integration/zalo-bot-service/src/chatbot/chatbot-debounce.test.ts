import test from 'node:test';
import assert from 'node:assert/strict';
import {
  ConversationDebouncer,
  type DebounceScheduler,
} from './chatbot-debounce.js';

class FakeScheduler implements DebounceScheduler {
  private nextId = 1;
  private currentTime = 0;
  private callbacks = new Map<number, {
    callback: () => void;
    dueAt: number;
  }>();

  set(callback: () => void, delayMs: number): unknown {
    const id = this.nextId++;
    this.callbacks.set(id, {
      callback,
      dueAt: this.currentTime + delayMs,
    });
    return id;
  }

  clear(handle: unknown): void {
    this.callbacks.delete(Number(handle));
  }

  now(): number {
    return this.currentTime;
  }

  advance(milliseconds: number): void {
    this.currentTime += milliseconds;
    const due = [...this.callbacks.entries()]
      .filter(([, item]) => item.dueAt <= this.currentTime)
      .sort((left, right) => left[1].dueAt - right[1].dueAt);
    for (const [id, item] of due) {
      if (!this.callbacks.delete(id)) continue;
      item.callback();
    }
  }

  get pending(): number {
    return this.callbacks.size;
  }
}

test('combines messages per conversation and resets the timer', async () => {
  const scheduler = new FakeScheduler();
  const flushed: Array<{ key: string; values: string[] }> = [];
  const debouncer = new ConversationDebouncer<string>({
    delayMs: 3000,
    scheduler,
    now: () => scheduler.now(),
    onFlush: async (key, values) => {
      flushed.push({ key, values });
    },
  });

  debouncer.push('a', 'one');
  debouncer.push('a', 'two');
  debouncer.push('b', 'other');
  assert.equal(scheduler.pending, 2);

  scheduler.advance(3000);
  await Promise.resolve();

  assert.deepEqual(flushed, [
    { key: 'a', values: ['one', 'two'] },
    { key: 'b', values: ['other'] },
  ]);
});

test('flushes after max wait even when new messages keep resetting debounce', async () => {
  const scheduler = new FakeScheduler();
  const flushed: string[][] = [];
  const debouncer = new ConversationDebouncer<string>({
    delayMs: 5000,
    maxWaitMs: 12000,
    scheduler,
    now: () => scheduler.now(),
    onFlush: async (_key, values) => {
      flushed.push(values);
    },
  });

  debouncer.push('a', 'one');
  scheduler.advance(4000);
  debouncer.push('a', 'two');
  scheduler.advance(4000);
  debouncer.push('a', 'three');
  scheduler.advance(3999);
  assert.deepEqual(flushed, []);

  scheduler.advance(1);
  await Promise.resolve();

  assert.deepEqual(flushed, [['one', 'two', 'three']]);
});

test('bounds buffered items and stop cancels pending work', () => {
  const scheduler = new FakeScheduler();
  const debouncer = new ConversationDebouncer<string>({
    delayMs: 3000,
    maxItems: 2,
    scheduler,
    onFlush: async () => {},
  });

  debouncer.push('a', 'one');
  debouncer.push('a', 'two');
  debouncer.push('a', 'three');
  assert.deepEqual(debouncer.peek('a'), ['two', 'three']);

  debouncer.stop();
  assert.equal(scheduler.pending, 0);
  assert.deepEqual(debouncer.peek('a'), []);
});
