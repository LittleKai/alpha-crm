/**
 * OfficialOaChannel — optional secondary channel using Zalo OA/OpenAPI.
 * Wraps existing OA placeholder behavior from the original zalo.ts.
 */

import { config } from '../config.js';
import type {
  ZaloChannel,
  ZaloChannelStatus,
  ZaloSendMessageRequest,
  ZaloSendMessageResult,
} from './types.js';

let lastEventAt: string | null = null;

export class OfficialOaChannel implements ZaloChannel {
  getStatus(): ZaloChannelStatus {
    const hasToken = !!config.zaloOaAccessToken;
    const hasOaId = !!config.zaloOaId;

    return {
      connected: hasToken && hasOaId,
      mode: 'official_oa',
      accountType: 'official',
      accountLabel: config.zaloOaId || 'N/A',
      listenerRunning: false,
      lastEventAt,
    };
  }

  async sendMessage(
    req: ZaloSendMessageRequest,
    isTestMode = false,
  ): Promise<ZaloSendMessageResult> {
    if (isTestMode) {
      return { success: true, messageId: `test_oa_${Date.now()}` };
    }

    if (!config.zaloOaAccessToken) {
      return {
        success: false,
        error: 'Zalo OA access token not configured.',
      };
    }

    // TODO: Integrate actual Zalo OA API call here
    return {
      success: false,
      error:
        'Zalo OA API integration pending. Configure ZALO_OA_ACCESS_TOKEN and implement SDK call.',
    };
  }

  handleWebhookEvent(event: Record<string, unknown>): void {
    lastEventAt = new Date().toISOString();
    const eventName = event['event_name'] as string | undefined;
    console.log(
      `[OfficialOaChannel] Webhook event: ${eventName || 'unknown'}`,
      JSON.stringify(event).slice(0, 200),
    );
  }

  async getAllGroups(): Promise<any[]> {
    console.log('[OfficialOaChannel] Official OA does not support personal group listing.');
    return [];
  }

  async leaveGroup(groupId: string, silent = false): Promise<boolean> {
    console.log('[OfficialOaChannel] Official OA does not support leaving personal groups.');
    return false;
  }

  getAccounts(): any[] {
    const hasToken = !!config.zaloOaAccessToken;
    const hasOaId = !!config.zaloOaId;
    if (hasToken && hasOaId) {
      return [
        { id: config.zaloOaId, label: `OA: ${config.zaloOaId}`, connected: true, listenerRunning: false },
      ];
    }
    return [];
  }

  async deleteAccount(accountId: string): Promise<boolean> {
    console.log('[OfficialOaChannel] Official OA does not support dynamic unlinking.');
    return false;
  }
}
