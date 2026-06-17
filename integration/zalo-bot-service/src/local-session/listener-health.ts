import type { ZaloChannelStatus } from '../channels/types.js';

export function shouldRecoverZaloListener(status: ZaloChannelStatus): boolean {
  // Prefer the account-aware hint when the channel provides it (handles the
  // multi-account case where one listener is up and another is down). Fall back
  // to the coarse pool-level signal for channels that don't compute it.
  if (status.needsListenerRecovery !== undefined) {
    return status.connected && status.needsListenerRecovery;
  }
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
