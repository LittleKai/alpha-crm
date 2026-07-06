import {
  readIntegrationSettings,
  writeIntegrationSettings,
  type TelegramIntegrationStatus,
} from '../integrations/integration-store.js';
import { emitInboundMessage } from './types.js';
import type {
  ZaloChannel,
  ZaloChannelStatus,
  ZaloInboundMessageEvent,
  ZaloSendMessageRequest,
  ZaloSendMessageResult,
} from './types.js';

let lastEventAt: string | null = null;

function telegramSendMethod(messageType?: string): 'sendPhoto' | 'sendVideo' | 'sendAudio' | 'sendDocument' {
  if (messageType === 'image' || messageType === 'gif' || messageType === 'sticker') return 'sendPhoto';
  if (messageType === 'video') return 'sendVideo';
  if (messageType === 'voice') return 'sendAudio';
  return 'sendDocument';
}

function telegramMediaField(method: string): string {
  if (method === 'sendPhoto') return 'photo';
  if (method === 'sendVideo') return 'video';
  if (method === 'sendAudio') return 'audio';
  return 'document';
}

function connectedBots(): TelegramIntegrationStatus[] {
  return readIntegrationSettings().telegramBots.filter(
    (bot) => bot.status === 'configured' && bot.enabled === true && !!bot.botToken && !!bot.accountId,
  );
}

function findBot(accountId?: string): TelegramIntegrationStatus | undefined {
  const bots = connectedBots();
  if (accountId) return bots.find((bot) => bot.accountId === accountId);
  return bots[0];
}

/**
 * Telegram Bot API adapter. Unlike the Meta-based channels, Telegram has no
 * webhook signature scheme — the cloud webhook route (channelWebhooks.js,
 * `/telegram/webhook/:botId`) verifies updates via the X-Telegram-Bot-Api-
 * Secret-Token header instead. Outbound sends call
 * `https://api.telegram.org/bot{token}/sendMessage` (or send{Photo,Video,...}
 * for attachments) directly using the bot token stored locally via
 * integration-store.ts. Telegram has no group-listing concept comparable to
 * Zalo/Facebook (bots only see chats they've been added to via updates).
 * Supports multiple linked bots, selected by req.accountId.
 */
export class TelegramChannel implements ZaloChannel {
  getStatus(): ZaloChannelStatus {
    const bots = connectedBots();
    const accountLabel = bots.length === 0
      ? 'N/A'
      : bots.length === 1
        ? (bots[0].accountName || bots[0].accountId || 'N/A')
        : `${bots.length} Telegram bots`;

    return {
      connected: bots.length > 0,
      mode: 'telegram',
      accountType: 'telegram',
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
      return { success: true, messageId: `test_telegram_${Date.now()}` };
    }

    const bot = findBot(req.accountId);
    if (!bot?.botToken) {
      return { success: false, error: 'Telegram bot token is not configured.' };
    }

    const attachmentUrl = req.attachments?.[0];
    const method = attachmentUrl ? telegramSendMethod(req.messageType) : 'sendMessage';
    const body: Record<string, unknown> = attachmentUrl
      ? { chat_id: req.recipientId, [telegramMediaField(method)]: attachmentUrl, caption: req.message }
      : { chat_id: req.recipientId, text: req.message };

    try {
      const response = await fetch(
        `https://api.telegram.org/bot${bot.botToken}/${method}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        },
      );
      const responseBody: any = await response.json().catch(() => null);
      if (!response.ok || responseBody?.ok === false) {
        return {
          success: false,
          error: responseBody?.description || `Telegram Bot API error (${response.status})`,
        };
      }
      return {
        success: true,
        messageId: String(responseBody?.result?.message_id || `telegram_${Date.now()}`),
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
        '[TelegramChannel] Failed to emit inbound relayed message:',
        err instanceof Error ? err.message : String(err),
      );
    });
  }

  async getAllGroups(): Promise<any[]> {
    console.log('[TelegramChannel] Telegram group listing is not supported.');
    return [];
  }

  async leaveGroup(_groupId: string, _silent = false): Promise<boolean> {
    console.log('[TelegramChannel] Telegram does not support leaving groups via this adapter.');
    return false;
  }

  getAccounts(): any[] {
    return connectedBots().map((bot) => ({
      id: bot.accountId,
      label: bot.accountName ? `Telegram: ${bot.accountName}` : `Telegram: ${bot.accountId}`,
      connected: true,
      listenerRunning: false,
    }));
  }

  async deleteAccount(accountId: string): Promise<boolean> {
    const current = readIntegrationSettings();
    const remaining = current.telegramBots.filter((bot) => bot.accountId !== accountId);
    if (remaining.length === current.telegramBots.length) return false;
    writeIntegrationSettings({ ...current, telegramBots: remaining });
    return true;
  }
}
