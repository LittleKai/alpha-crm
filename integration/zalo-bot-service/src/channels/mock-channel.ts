/**
 * MockZaloChannel — test/dev fallback that returns mock results
 * without making any real Zalo API calls.
 */

import type {
  ZaloChannel,
  ZaloChannelStatus,
  ZaloSendMessageRequest,
  ZaloSendMessageResult,
} from './types.js';

let lastEventAt: string | null = null;

export class MockZaloChannel implements ZaloChannel {
  getStatus(): ZaloChannelStatus {
    return {
      connected: true,
      mode: 'mock',
      accountType: 'mock',
      accountLabel: 'Mock Channel',
      listenerRunning: false,
      lastEventAt,
    };
  }

  async sendMessage(
    req: ZaloSendMessageRequest,
    _isTestMode = false,
  ): Promise<ZaloSendMessageResult> {
    console.log(
      `[MockZaloChannel] Mock send to ${req.recipientId}: ${req.message.slice(0, 80)}`,
    );
    return {
      success: true,
      messageId: `mock_${Date.now()}`,
    };
  }

  handleWebhookEvent(event: Record<string, unknown>): void {
    lastEventAt = new Date().toISOString();
    console.log(
      '[MockZaloChannel] Mock webhook event:',
      JSON.stringify(event).slice(0, 200),
    );
  }
}
