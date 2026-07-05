import {
  readIntegrationSettings,
  writeIntegrationSettings,
  type TiktokIntegrationStatus,
} from '../integrations/integration-store.js';
import { emitInboundMessage } from './types.js';
import type {
  ZaloChannel,
  ZaloChannelStatus,
  ZaloInboundMessageEvent,
  ZaloSendMessageRequest,
  ZaloSendMessageResult,
} from './types.js';

// NOTE: TikTok Business Messaging API base URL, request/response shape, and
// attachment handling below are a placeholder mirroring FacebookChannel's
// Graph API structure. They are NOT yet verified against real TikTok API
// docs/credentials — re-verify the endpoint path, auth scheme, and payload
// shape once real TikTok Business Messaging API access is available.
const TIKTOK_API_BASE_URL = 'https://business-api.tiktok.com/open_api/v1.3';

let lastEventAt: string | null = null;

function connectedAccounts(): TiktokIntegrationStatus[] {
  return readIntegrationSettings().tiktokAccounts.filter(
    (account) => account.status === 'configured' && account.enabled === true && !!account.accessToken && !!account.accountId,
  );
}

function findAccount(accountId?: string): TiktokIntegrationStatus | undefined {
  const accounts = connectedAccounts();
  if (accountId) return accounts.find((account) => account.accountId === accountId);
  return accounts[0];
}

/**
 * TikTok channel adapter, structurally mirroring FacebookChannel: no
 * persistent connection, inbound events arrive pre-normalized via
 * handleWebhookEvent() (relayed down from the cloud webhook through
 * CrmAgentCommand — see channelWebhooks.js), and outbound sends call the
 * TikTok Business Messaging API directly using the access token stored
 * locally via integration-store.ts. Supports multiple linked accounts,
 * selected by req.accountId.
 */
export class TiktokChannel implements ZaloChannel {
  getStatus(): ZaloChannelStatus {
    const accounts = connectedAccounts();
    const accountLabel = accounts.length === 0
      ? 'N/A'
      : accounts.length === 1
        ? (accounts[0].accountName || accounts[0].accountId || 'N/A')
        : `${accounts.length} TikTok accounts`;

    return {
      connected: accounts.length > 0,
      mode: 'tiktok',
      accountType: 'tiktok',
      accountLabel,
      listenerRunning: false,
      lastEventAt,
    };
  }

  async sendMessage(
    req: ZaloSendMessageRequest,
    isTestMode = false,
  ): Promise<ZaloSendMessageResult> {
    if (isTestMode) {
      return { success: true, messageId: `test_tiktok_${Date.now()}` };
    }

    const account = findAccount(req.accountId);
    if (!account?.accessToken) {
      return { success: false, error: 'TikTok access token is not configured.' };
    }

    const attachmentUrl = req.attachments?.[0];
    const message = attachmentUrl
      ? { attachment_url: attachmentUrl }
      : { text: req.message };

    try {
      const response = await fetch(`${TIKTOK_API_BASE_URL}/business/messages/send/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Access-Token': account.accessToken,
        },
        body: JSON.stringify({
          recipient_id: req.recipientId,
          ...message,
        }),
      });
      const body: any = await response.json().catch(() => null);
      if (!response.ok || body?.code) {
        return {
          success: false,
          error: body?.message || `TikTok API error (${response.status})`,
        };
      }
      return {
        success: true,
        messageId: body?.data?.message_id || `tiktok_${Date.now()}`,
      };
    } catch (err) {
      return {
        success: false,
        error: err instanceof Error ? err.message : String(err),
      };
    }
  }

  handleWebhookEvent(event: Record<string, unknown>): void {
    lastEventAt = new Date().toISOString();
    // The cloud webhook route (channelWebhooks.js) already normalized this
    // payload into ZaloInboundMessageEvent shape before relaying it down via
    // CrmAgentCommand, so it can be passed straight through to the shared
    // inbound funnel (local SQLite write + chatbot engagement).
    void emitInboundMessage(event as unknown as ZaloInboundMessageEvent).catch((err) => {
      console.warn(
        '[TiktokChannel] Failed to emit inbound relayed message:',
        err instanceof Error ? err.message : String(err),
      );
    });
  }

  async getAllGroups(): Promise<any[]> {
    console.log('[TiktokChannel] TikTok does not support group listing.');
    return [];
  }

  async leaveGroup(_groupId: string, _silent = false): Promise<boolean> {
    console.log('[TiktokChannel] TikTok does not support leaving groups.');
    return false;
  }

  getAccounts(): any[] {
    return connectedAccounts().map((account) => ({
      id: account.accountId,
      label: account.accountName ? `TikTok: ${account.accountName}` : `TikTok: ${account.accountId}`,
      connected: true,
      listenerRunning: false,
    }));
  }

  async deleteAccount(accountId: string): Promise<boolean> {
    const current = readIntegrationSettings();
    const remaining = current.tiktokAccounts.filter((account) => account.accountId !== accountId);
    if (remaining.length === current.tiktokAccounts.length) return false;
    writeIntegrationSettings({ ...current, tiktokAccounts: remaining });
    return true;
  }
}
