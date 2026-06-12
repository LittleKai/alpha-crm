import type { ChatbotStore } from './chatbot-store.js';
import type { ChatbotConfigSnapshot } from './chatbot-types.js';

interface ChatbotConfigApi {
  fetchConfig(): Promise<ChatbotConfigSnapshot>;
}

export interface ChatbotSyncStatus {
  running: boolean;
  configVersion: string | null;
  lastSyncedAt: number | null;
  lastError: string | null;
}

interface ChatbotConfigSyncOptions {
  store: ChatbotStore;
  api: ChatbotConfigApi;
  intervalMs?: number;
  now?: () => number;
  setIntervalFn?: (callback: () => void, intervalMs: number) => unknown;
  clearIntervalFn?: (handle: unknown) => void;
}

const DEFAULT_SYNC_INTERVAL_MS = 60_000;

export class ChatbotConfigSync {
  private readonly store: ChatbotStore;
  private readonly api: ChatbotConfigApi;
  private readonly intervalMs: number;
  private readonly now: () => number;
  private readonly setIntervalFn: (
    callback: () => void,
    intervalMs: number,
  ) => unknown;
  private readonly clearIntervalFn: (handle: unknown) => void;
  private intervalHandle: unknown;
  private status: ChatbotSyncStatus;

  constructor(options: ChatbotConfigSyncOptions) {
    this.store = options.store;
    this.api = options.api;
    this.intervalMs = options.intervalMs ?? DEFAULT_SYNC_INTERVAL_MS;
    this.now = options.now ?? Date.now;
    this.setIntervalFn = options.setIntervalFn
      ?? ((callback, intervalMs) => setInterval(callback, intervalMs));
    this.clearIntervalFn = options.clearIntervalFn
      ?? ((handle) => clearInterval(handle as NodeJS.Timeout));
    this.status = {
      running: false,
      configVersion: this.store.getConfigSnapshot()?.version ?? null,
      lastSyncedAt: null,
      lastError: null,
    };
  }

  start(): void {
    if (this.status.running) return;
    this.status = {
      ...this.status,
      running: true,
      configVersion:
        this.store.getConfigSnapshot()?.version
        ?? this.status.configVersion,
    };
    void this.syncNow().catch(() => {
      // Status records the failure; the cached snapshot remains active.
    });
    this.intervalHandle = this.setIntervalFn(() => {
      void this.syncNow().catch(() => {
        // Keep the loop alive and retain the last valid snapshot.
      });
    }, this.intervalMs);
  }

  stop(): void {
    if (this.intervalHandle !== undefined) {
      this.clearIntervalFn(this.intervalHandle);
      this.intervalHandle = undefined;
    }
    this.status = { ...this.status, running: false };
  }

  async syncNow(): Promise<ChatbotConfigSnapshot> {
    try {
      const snapshot = await this.api.fetchConfig();
      this.store.saveConfigSnapshot(snapshot);
      this.status = {
        ...this.status,
        configVersion: snapshot.version,
        lastSyncedAt: this.now(),
        lastError: null,
      };
      return snapshot;
    } catch (error) {
      this.status = {
        ...this.status,
        lastError: error instanceof Error ? error.message : String(error),
      };
      throw error;
    }
  }

  getStatus(): ChatbotSyncStatus {
    return { ...this.status };
  }
}

