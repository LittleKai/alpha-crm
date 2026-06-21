import {
  callCloudApi,
  CloudApiError,
} from '../agent/cloud-api.js';
import type { ChatbotConfigSnapshot } from './chatbot-types.js';

export interface ChatbotAgentCredentials {
  deviceId: string;
  agentSecret: string;
}

export interface ChatbotGenerateRequest {
  accountId: string;
  threadId: string;
  conversationKey: string;
  messages: Array<{
    id: string;
    content: string;
    timestamp: number;
  }>;
  history: Array<{
    role: 'user' | 'assistant';
    content: string;
  }>;
  // Knowledge documents already filtered for this account by the bridge. When
  // present the cloud uses these instead of the operator's full stored set.
  knowledgeSnippets?: string[];
}

export type ChatbotAttachmentType = 'image' | 'video' | 'audio' | 'file';

export interface ChatbotGenerateAttachment {
  type: ChatbotAttachmentType;
  // Content-hash id of a file stored locally by the bridge knowledge store.
  id: string;
  name: string;
}

export interface ChatbotGenerateResponse {
  reply: string;
  attachments: ChatbotGenerateAttachment[];
  usage?: Record<string, unknown>;
}

export interface ChatbotAuditRequest {
  idempotencyKey: string;
  outcome: 'matched' | 'ai' | 'handoff' | 'skipped' | 'failed';
  conversationKey: string;
  timestamp: number;
  [key: string]: unknown;
}

const REQUEST_TIMEOUT_MS = 12_000;

export class ChatbotCloudApi {
  constructor(private readonly credentials: ChatbotAgentCredentials) {}

  async fetchConfig(): Promise<ChatbotConfigSnapshot> {
    const data = await callCloudApi('/crm/agent/chatbot/config', {
      method: 'GET',
      headers: this.headers(),
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
    if (!isConfigSnapshot(data)) {
      throw new CloudApiError(
        'Invalid chatbot config response.',
        502,
        'INVALID_CHATBOT_CONFIG_RESPONSE',
        data,
      );
    }
    return data;
  }

  async generateReply(
    request: ChatbotGenerateRequest,
  ): Promise<ChatbotGenerateResponse> {
    const data = await callCloudApi('/crm/agent/chatbot/generate', {
      method: 'POST',
      headers: this.headers(),
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      body: JSON.stringify(request),
    });
    const attachments = isRecord(data)
      ? parseGenerateAttachments(data.attachments)
      : [];
    if (
      !isRecord(data)
      || typeof data.reply !== 'string'
      || (data.reply.trim().length === 0 && attachments.length === 0)
    ) {
      throw new CloudApiError(
        'Invalid chatbot AI response.',
        502,
        'INVALID_CHATBOT_AI_RESPONSE',
        data,
      );
    }
    return {
      reply: data.reply,
      attachments,
      ...(isRecord(data.usage) ? { usage: data.usage } : {}),
    };
  }

  async postAudit(request: ChatbotAuditRequest): Promise<void> {
    await callCloudApi('/crm/agent/chatbot/audit', {
      method: 'POST',
      headers: this.headers(),
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      body: JSON.stringify(request),
    });
  }

  private headers(): Record<string, string> {
    return {
      'Content-Type': 'application/json',
      'x-agent-device-id': this.credentials.deviceId,
      'x-agent-secret': this.credentials.agentSecret,
    };
  }
}

function isConfigSnapshot(value: unknown): value is ChatbotConfigSnapshot {
  return isRecord(value)
    && typeof value.version === 'string'
    && isRecord(value.settings)
    && typeof value.settings.enabled === 'boolean'
    && Array.isArray(value.rules)
    && value.rules.every((rule) =>
      isRecord(rule)
      && typeof rule.id === 'string'
      && Array.isArray(rule.keywords)
      && rule.keywords.every((keyword) => typeof keyword === 'string')
      && typeof rule.response === 'string')
    && isRecord(value.scope)
    && isStringArray(value.scope.crmThreadKeys)
    && isStringArray(value.scope.selectedGroupKeys);
}

function parseGenerateAttachments(value: unknown): ChatbotGenerateAttachment[] {
  if (!Array.isArray(value)) return [];
  const allowed: ChatbotAttachmentType[] = ['image', 'video', 'audio', 'file'];
  const result: ChatbotGenerateAttachment[] = [];
  for (const item of value) {
    if (!isRecord(item)) continue;
    const id = typeof item.id === 'string' ? item.id.trim() : '';
    if (!id) continue;
    const type = allowed.includes(item.type as ChatbotAttachmentType)
      ? (item.type as ChatbotAttachmentType)
      : 'file';
    const name = typeof item.name === 'string' ? item.name : '';
    result.push({ type, id, name });
  }
  return result;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value)
    && value.every((item) => typeof item === 'string');
}

