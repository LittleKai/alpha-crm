/**
 * OfficialOaChannel — optional secondary channel using Zalo OA/OpenAPI.
 * Wraps existing OA placeholder behavior from the original zalo.ts.
 */

import { config } from '../config.js';
import type {
  ZaloChannel,
  ZaloChannelStatus,
  ZaloInboundMessageEvent,
  ZaloSendMessageRequest,
  ZaloSendMessageResult,
} from './types.js';
import { emitInboundMessage } from './types.js';
import { OfficialBotApiError, OfficialBotClient } from './official-bot-client.js';

let lastEventAt: string | null = null;

function toStringValue(value: unknown): string {
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function pickRecord(...values: unknown[]): Record<string, unknown> {
  for (const value of values) {
    const record = asRecord(value);
    if (Object.keys(record).length > 0) return record;
  }
  return {};
}

function normalizeTimestamp(value: unknown): string {
  const raw = Number(value ?? Date.now());
  const timestampMs = Number.isFinite(raw)
    ? raw > 100000000000 ? raw : raw * 1000
    : Date.now();
  return new Date(timestampMs).toISOString();
}

function detectMessageType(message: Record<string, unknown>): ZaloInboundMessageEvent['messageType'] {
  const rawType = toStringValue(message['message_type'] ?? message['msgType'] ?? message['type']).toLowerCase();
  if (rawType.includes('photo') || rawType.includes('image') || message['photo']) return 'image';
  if (rawType.includes('file') || message['file']) return 'file';
  if (rawType.includes('sticker') || message['sticker']) return 'sticker';
  if (message['text'] || message['content'] || message['message']) return 'text';
  return 'unknown';
}

function normalizeOfficialInboundEvent(event: Record<string, unknown>): ZaloInboundMessageEvent | null {
  const data = asRecord(event['data']);
  const message = pickRecord(event['message'], data['message'], data);
  const chat = pickRecord(message['chat'], data['chat']);
  const from = pickRecord(message['from'], data['from'], data['sender'], event['sender']);

  const senderId =
    toStringValue(from['id']) ||
    toStringValue(from['user_id']) ||
    toStringValue(data['user_id']) ||
    toStringValue(event['user_id']);
  const threadId =
    toStringValue(chat['id']) ||
    toStringValue(data['thread_id']) ||
    toStringValue(data['recipient_id']) ||
    senderId;

  if (!senderId || !threadId) return null;

  const messageType = detectMessageType(message);
  const content =
    toStringValue(message['text']) ||
    toStringValue(message['content']) ||
    toStringValue(message['message']) ||
    toStringValue(data['text']) ||
    toStringValue(event['text']) ||
    `[${messageType}]`;
  const chatType = toStringValue(chat['type']).toLowerCase();
  const timestamp = normalizeTimestamp(
    message['date'] ?? message['timestamp'] ?? data['timestamp'] ?? event['timestamp'],
  );

  return {
    accountId: config.zaloOaId || 'official_oa',
    accountLabel: config.zaloOaId ? `OA: ${config.zaloOaId}` : 'Official Zalo Bot/OA',
    threadId,
    threadType: chatType.includes('group') ? 'group' : 'user',
    senderId,
    senderName:
      toStringValue(from['display_name']) ||
      toStringValue(from['name']) ||
      toStringValue(from['username']),
    avatarUrl: toStringValue(from['avatar']) || toStringValue(from['avatarUrl']),
    content,
    messageType,
    providerMessageId:
      toStringValue(message['message_id']) ||
      toStringValue(message['messageId']) ||
      toStringValue(message['msg_id']) ||
      `official_${threadId}_${Date.parse(timestamp) || Date.now()}`,
    timestamp,
  };
}

export class OfficialOaChannel implements ZaloChannel {
  private readonly botClient =
    config.zaloBotToken
      ? new OfficialBotClient({
        token: config.zaloBotToken,
        baseUrl: config.zaloBotApiBaseUrl,
        timeoutMs: config.zaloBotApiTimeoutMs,
      })
      : null;

  getStatus(): ZaloChannelStatus {
    const hasToken = !!config.zaloOaAccessToken;
    const hasOaId = !!config.zaloOaId;
    const hasBotToken = !!config.zaloBotToken;

    return {
      connected: (hasToken && hasOaId) || hasBotToken,
      mode: 'official_oa',
      accountType: 'official',
      accountLabel: config.zaloOaId || (hasBotToken ? 'Official Bot API' : 'N/A'),
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

    if (req.messageType === 'template') {
      return {
        success: false,
        error: 'Template/OA transaction messages are not implemented in the local official channel yet.',
      };
    }

    if (!this.botClient) {
      return {
        success: false,
        error: 'ZALO_BOT_TOKEN is not configured. Official text send requires the Bot API token.',
      };
    }

    try {
      const result = await this.botClient.sendTextMessage(req.recipientId, req.message);
      return {
        success: true,
        messageId: result.messageId || `official_${Date.now()}`,
      };
    } catch (err) {
      const suffix = err instanceof OfficialBotApiError && err.statusCode
        ? ` (${err.statusCode}${err.code ? `/${err.code}` : ''})`
        : '';
      return {
        success: false,
        error: `${err instanceof Error ? err.message : String(err)}${suffix}`,
      };
    }
  }

  handleWebhookEvent(event: Record<string, unknown>): void {
    lastEventAt = new Date().toISOString();
    const eventName = event['event_name'] as string | undefined;
    console.log(
      `[OfficialOaChannel] Webhook event: ${eventName || 'unknown'}`,
      JSON.stringify(event).slice(0, 200),
    );

    const inbound = normalizeOfficialInboundEvent(event);
    if (!inbound) return;

    void emitInboundMessage(inbound).catch((err) => {
      console.warn(
        '[OfficialOaChannel] Failed to emit inbound webhook message:',
        err instanceof Error ? err.message : String(err),
      );
    });
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
    const hasBotToken = !!config.zaloBotToken;
    if ((hasToken && hasOaId) || hasBotToken) {
      return [
        {
          id: config.zaloOaId || 'official_bot_api',
          label: config.zaloOaId ? `OA: ${config.zaloOaId}` : 'Official Bot API',
          connected: true,
          listenerRunning: false,
        },
      ];
    }
    return [];
  }

  async deleteAccount(accountId: string): Promise<boolean> {
    console.log('[OfficialOaChannel] Official OA does not support dynamic unlinking.');
    return false;
  }
}
