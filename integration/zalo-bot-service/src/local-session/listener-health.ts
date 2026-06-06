import type { ZaloChannelStatus } from '../channels/types.js';

export function shouldRecoverZaloListener(status: ZaloChannelStatus): boolean {
  return status.connected && !status.listenerRunning;
}

export class ListenerHealthMonitor {
  private timer: NodeJS.Timeout | null = null;
  private recovery: Promise<void> | null = null;

  constructor(
    private readonly getStatus: () => ZaloChannelStatus,
    private readonly recover: () => Promise<void>,
    private readonly intervalMs = 15000,
  ) {}

  start(): void {
    if (this.timer) {
      return;
    }
    this.timer = setInterval(() => {
      void this.check();
    }, this.intervalMs);
  }

  stop(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  async check(): Promise<void> {
    if (!shouldRecoverZaloListener(this.getStatus()) || this.recovery) {
      return this.recovery ?? Promise.resolve();
    }
    this.recovery = this.recover().finally(() => {
      this.recovery = null;
    });
    return this.recovery;
  }
}
