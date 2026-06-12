export interface DebounceScheduler {
  set(callback: () => void, delayMs: number): unknown;
  clear(handle: unknown): void;
}

interface ConversationDebouncerOptions<T> {
  delayMs: number | (() => number);
  maxWaitMs?: number;
  maxItems?: number;
  scheduler?: DebounceScheduler;
  now?: () => number;
  onFlush: (key: string, values: T[]) => void | Promise<void>;
}

interface PendingBuffer<T> {
  values: T[];
  handle: unknown;
  firstPushedAt: number;
}

const defaultScheduler: DebounceScheduler = {
  set: (callback, delayMs) => setTimeout(callback, delayMs),
  clear: (handle) => clearTimeout(handle as NodeJS.Timeout),
};

export class ConversationDebouncer<T> {
  private readonly delayMs: number | (() => number);
  private readonly maxWaitMs?: number;
  private readonly maxItems: number;
  private readonly scheduler: DebounceScheduler;
  private readonly now: () => number;
  private readonly onFlush: (key: string, values: T[]) => void | Promise<void>;
  private readonly pending = new Map<string, PendingBuffer<T>>();

  constructor(options: ConversationDebouncerOptions<T>) {
    this.delayMs = options.delayMs;
    this.maxWaitMs = options.maxWaitMs;
    this.maxItems = Math.max(1, options.maxItems ?? 20);
    this.scheduler = options.scheduler ?? defaultScheduler;
    this.now = options.now ?? Date.now;
    this.onFlush = options.onFlush;
  }

  push(key: string, value: T): void {
    const existing = this.pending.get(key);
    if (existing) {
      this.scheduler.clear(existing.handle);
    }
    const values = [...(existing?.values ?? []), value].slice(-this.maxItems);
    const now = this.now();
    const firstPushedAt = existing?.firstPushedAt ?? now;
    const configuredDelay = typeof this.delayMs === 'function'
      ? this.delayMs()
      : this.delayMs;
    const debounceDelay = Math.max(0, configuredDelay);
    const remainingMaxWait = this.maxWaitMs === undefined
      ? debounceDelay
      : Math.max(0, this.maxWaitMs - (now - firstPushedAt));
    const handle = this.scheduler.set(() => {
      void this.flush(key);
    }, Math.min(debounceDelay, remainingMaxWait));
    this.pending.set(key, { values, handle, firstPushedAt });
  }

  async flush(key: string): Promise<void> {
    const buffer = this.pending.get(key);
    if (!buffer) return;
    this.pending.delete(key);
    this.scheduler.clear(buffer.handle);
    await this.onFlush(key, buffer.values);
  }

  peek(key: string): T[] {
    return [...(this.pending.get(key)?.values ?? [])];
  }

  stop(): void {
    for (const buffer of this.pending.values()) {
      this.scheduler.clear(buffer.handle);
    }
    this.pending.clear();
  }
}
