import {
  readIntegrationSettings,
  writeIntegrationSettings,
  type FacebookIntegrationStatus,
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

function connectedPages(): FacebookIntegrationStatus[] {
  return readIntegrationSettings().facebookPages.filter(
    (page) => page.status === 'configured' && page.enabled === true && !!page.pageAccessToken && !!page.pageId,
  );
}

function findPage(accountId?: string): FacebookIntegrationStatus | undefined {
  const pages = connectedPages();
  if (accountId) return pages.find((page) => page.pageId === accountId);
  return pages[0];
}

/**
 * Facebook Messenger adapter. Unlike Zalo (which owns a live local session)
 * or OfficialOaChannel (which reads env-configured tokens), this channel has
 * no persistent connection: inbound events arrive pre-normalized via
 * handleWebhookEvent() (relayed down from the cloud webhook through
 * CrmAgentCommand — see channelWebhooks.js), and outbound sends call the Meta
 * Graph API directly using the page access token stored locally via
 * integration-store.ts. Supports multiple linked Pages, selected by
 * req.accountId (== pageId).
 */
export class FacebookChannel implements ZaloChannel {
  getStatus(): ZaloChannelStatus {
    const pages = connectedPages();
    const accountLabel = pages.length === 0
      ? 'N/A'
      : pages.length === 1
        ? (pages[0].pageName || pages[0].pageId || 'N/A')
        : `${pages.length} Fanpages`;

    return {
      connected: pages.length > 0,
      mode: 'facebook_page',
      accountType: 'facebook_page',
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
      return { success: true, messageId: `test_facebook_${Date.now()}` };
    }

    const page = findPage(req.accountId);
    if (!page?.pageAccessToken) {
      return { success: false, error: 'Facebook Page access token is not configured.' };
    }

    // The Graph API attachment upload fetches the URL itself, so only
    // remotely-reachable URLs work here (unlike Zalo's zca-js, which can
    // upload a local file path directly) — attachments must already be
    // hosted (e.g. on B2) before being sent through this channel.
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
        `${GRAPH_API_BASE_URL}/me/messages?access_token=${encodeURIComponent(page.pageAccessToken)}`,
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
          error: body?.error?.message || `Facebook Graph API error (${response.status})`,
        };
      }
      return {
        success: true,
        messageId: body?.message_id || `facebook_${Date.now()}`,
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
        '[FacebookChannel] Failed to emit inbound relayed message:',
        err instanceof Error ? err.message : String(err),
      );
    });
  }

  async getAllGroups(): Promise<any[]> {
    console.log('[FacebookChannel] Facebook Messenger does not support group listing.');
    return [];
  }

  async leaveGroup(_groupId: string, _silent = false): Promise<boolean> {
    console.log('[FacebookChannel] Facebook Messenger does not support leaving groups.');
    return false;
  }

  getAccounts(): any[] {
    return connectedPages().map((page) => ({
      id: page.pageId,
      label: page.pageName ? `Facebook: ${page.pageName}` : `Facebook Page: ${page.pageId}`,
      connected: true,
      listenerRunning: false,
    }));
  }

  async deleteAccount(accountId: string): Promise<boolean> {
    const current = readIntegrationSettings();
    const remaining = current.facebookPages.filter((page) => page.pageId !== accountId);
    if (remaining.length === current.facebookPages.length) return false;
    writeIntegrationSettings({ ...current, facebookPages: remaining });
    return true;
  }
}
