import {
  readIntegrationSettings,
  writeIntegrationSettings,
  type InstagramIntegrationStatus,
} from '../integrations/integration-store.js';
import { emitInboundMessage } from './types.js';
import type {
  ZaloChannel,
  ZaloChannelStatus,
  ZaloInboundMessageEvent,
  ZaloSendMessageRequest,
  ZaloSendMessageResult,
} from './types.js';

const GRAPH_API_BASE_URL = 'https://graph.facebook.com/v19.0';

let lastEventAt: string | null = null;

function graphAttachmentType(messageType?: string): 'image' | 'video' | 'audio' | 'file' {
  if (messageType === 'image' || messageType === 'gif') return 'image';
  if (messageType === 'video') return 'video';
  if (messageType === 'voice') return 'audio';
  return 'file';
}

function connectedAccounts(): InstagramIntegrationStatus[] {
  return readIntegrationSettings().instagramAccounts.filter(
    (account) => account.status === 'configured' && account.enabled === true && !!account.accessToken && !!account.accountId,
  );
}

function findAccount(accountId?: string): InstagramIntegrationStatus | undefined {
  const accounts = connectedAccounts();
  if (accountId) return accounts.find((account) => account.accountId === accountId);
  return accounts[0];
}

/**
 * Instagram Direct Messaging adapter. Rides the same Meta Graph API as
 * FacebookChannel (same App/App Secret, same signature scheme, same
 * entry[].messaging[] webhook shape) — see channelWebhooks.js for the
 * `object: "instagram"` handling. Like Facebook, this channel has no
 * persistent connection: inbound events arrive pre-normalized via
 * handleWebhookEvent() (relayed down from the cloud webhook through
 * CrmAgentCommand), and outbound sends call the Graph API directly using
 * the IG account's access token stored locally via integration-store.ts.
 * Supports multiple linked IG accounts, selected by req.accountId.
 */
export class InstagramChannel implements ZaloChannel {
  getStatus(): ZaloChannelStatus {
    const accounts = connectedAccounts();
    const accountLabel = accounts.length === 0
      ? 'N/A'
      : accounts.length === 1
        ? (accounts[0].accountName || accounts[0].accountId || 'N/A')
        : `${accounts.length} Instagram accounts`;

    return {
      connected: accounts.length > 0,
      mode: 'instagram',
      accountType: 'instagram',
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
      return { success: true, messageId: `test_instagram_${Date.now()}` };
    }

    const account = findAccount(req.accountId);
    if (!account?.accessToken) {
      return { success: false, error: 'Instagram access token is not configured.' };
    }

    // Same attachment caveat as Facebook: the Graph API fetches the URL
    // itself, so attachments must already be hosted (e.g. on B2) before
    // being sent through this channel.
    const attachmentUrl = req.attachments?.[0];
    const message = attachmentUrl
      ? {
        attachment: {
          type: graphAttachmentType(req.messageType),
          payload: { url: attachmentUrl, is_reusable: true },
        },
      }
      : { text: req.message };

    try {
      const response = await fetch(
        `${GRAPH_API_BASE_URL}/me/messages?access_token=${encodeURIComponent(account.accessToken)}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            recipient: { id: req.recipientId },
            message,
            messaging_type: 'RESPONSE',
          }),
        },
      );
      const body: any = await response.json().catch(() => null);
      if (!response.ok || body?.error) {
        return {
          success: false,
          error: body?.error?.message || `Instagram Graph API error (${response.status})`,
        };
      }
      return {
        success: true,
        messageId: body?.message_id || `instagram_${Date.now()}`,
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
        '[InstagramChannel] Failed to emit inbound relayed message:',
        err instanceof Error ? err.message : String(err),
      );
    });
  }

  async getAllGroups(): Promise<any[]> {
    console.log('[InstagramChannel] Instagram does not support group listing.');
    return [];
  }

  async leaveGroup(_groupId: string, _silent = false): Promise<boolean> {
    console.log('[InstagramChannel] Instagram does not support leaving groups.');
    return false;
  }

  getAccounts(): any[] {
    return connectedAccounts().map((account) => ({
      id: account.accountId,
      label: account.accountName ? `Instagram: ${account.accountName}` : `Instagram: ${account.accountId}`,
      connected: true,
      listenerRunning: false,
    }));
  }

  async deleteAccount(accountId: string): Promise<boolean> {
    const current = readIntegrationSettings();
    const remaining = current.instagramAccounts.filter((account) => account.accountId !== accountId);
    if (remaining.length === current.instagramAccounts.length) return false;
    writeIntegrationSettings({ ...current, instagramAccounts: remaining });
    return true;
  }
}
