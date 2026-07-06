import {
  readIntegrationSettings,
  writeIntegrationSettings,
  type WhatsappIntegrationStatus,
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

function whatsappAttachmentType(messageType?: string): 'image' | 'video' | 'audio' | 'document' {
  if (messageType === 'image' || messageType === 'gif' || messageType === 'sticker') return 'image';
  if (messageType === 'video') return 'video';
  if (messageType === 'voice') return 'audio';
  return 'document';
}

function connectedAccounts(): WhatsappIntegrationStatus[] {
  return readIntegrationSettings().whatsappAccounts.filter(
    (account) => account.status === 'configured' && account.enabled === true && !!account.accessToken && !!account.accountId,
  );
}

function findAccount(accountId?: string): WhatsappIntegrationStatus | undefined {
  const accounts = connectedAccounts();
  if (accountId) return accounts.find((account) => account.accountId === accountId);
  return accounts[0];
}

/**
 * WhatsApp Cloud API adapter. Rides the same Meta Graph API as
 * FacebookChannel/InstagramChannel (same App/App Secret, same signature
 * scheme) — see channelWebhooks.js for the `/whatsapp/webhook` handling.
 * Unlike Messenger/IG, outbound sends target `/{phone_number_id}/messages`
 * directly (no `/me/`) since the phone number itself is the account.
 * The 24h customer-service window is enforced by Meta's API itself (send
 * calls outside the window return an error), not by this adapter — the
 * `enforce24hWindow` setting is a UI-only warning toggle, matching the
 * existing Facebook/Instagram pattern (see integration-store.ts).
 * Supports multiple linked WhatsApp numbers, selected by req.accountId.
 */
export class WhatsappChannel implements ZaloChannel {
  getStatus(): ZaloChannelStatus {
    const accounts = connectedAccounts();
    const accountLabel = accounts.length === 0
      ? 'N/A'
      : accounts.length === 1
        ? (accounts[0].accountName || accounts[0].accountId || 'N/A')
        : `${accounts.length} WhatsApp accounts`;

    return {
      connected: accounts.length > 0,
      mode: 'whatsapp',
      accountType: 'whatsapp',
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
      return { success: true, messageId: `test_whatsapp_${Date.now()}` };
    }

    const account = findAccount(req.accountId);
    if (!account?.accessToken) {
      return { success: false, error: 'WhatsApp access token is not configured.' };
    }

    // Same attachment caveat as Facebook/Instagram: the Graph API fetches the
    // link itself, so attachments must already be hosted (e.g. on B2) before
    // being sent through this channel.
    const attachmentUrl = req.attachments?.[0];
    const message = attachmentUrl
      ? { [whatsappAttachmentType(req.messageType)]: { link: attachmentUrl } }
      : { text: { body: req.message } };

    try {
      const response = await fetch(
        `${GRAPH_API_BASE_URL}/${encodeURIComponent(account.accountId!)}/messages`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${account.accessToken}`,
          },
          body: JSON.stringify({
            messaging_product: 'whatsapp',
            to: req.recipientId,
            type: attachmentUrl ? whatsappAttachmentType(req.messageType) : 'text',
            ...message,
          }),
        },
      );
      const body: any = await response.json().catch(() => null);
      if (!response.ok || body?.error) {
        return {
          success: false,
          error: body?.error?.message || `WhatsApp Cloud API error (${response.status})`,
        };
      }
      return {
        success: true,
        messageId: body?.messages?.[0]?.id || `whatsapp_${Date.now()}`,
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
        '[WhatsappChannel] Failed to emit inbound relayed message:',
        err instanceof Error ? err.message : String(err),
      );
    });
  }

  async getAllGroups(): Promise<any[]> {
    console.log('[WhatsappChannel] WhatsApp does not support group listing.');
    return [];
  }

  async leaveGroup(_groupId: string, _silent = false): Promise<boolean> {
    console.log('[WhatsappChannel] WhatsApp does not support leaving groups.');
    return false;
  }

  getAccounts(): any[] {
    return connectedAccounts().map((account) => ({
      id: account.accountId,
      label: account.accountName ? `WhatsApp: ${account.accountName}` : `WhatsApp: ${account.accountId}`,
      connected: true,
      listenerRunning: false,
    }));
  }

  async deleteAccount(accountId: string): Promise<boolean> {
    const current = readIntegrationSettings();
    const remaining = current.whatsappAccounts.filter((account) => account.accountId !== accountId);
    if (remaining.length === current.whatsappAccounts.length) return false;
    writeIntegrationSettings({ ...current, whatsappAccounts: remaining });
    return true;
  }
}
