import { createHash, randomUUID } from 'node:crypto';
import type {
  ZaloSendMessageRequest,
  ZaloSendMessageResult,
} from '../channels/types.js';
import type { LocalChatEventInput } from '../local-chat/local-chat-events.js';
import type { OutboundMessageInput } from '../local-chat/local-chat-types.js';
import type { ChatbotDecision } from './chatbot-engine.js';
import type { ChatbotAuditRequest } from './chatbot-cloud-api.js';
import type {
  ChatbotAuditPayload,
  ChatbotConversationState,
} from './chatbot-types.js';

export interface ChatbotDispatchInput {
  accountId: string;
  threadId: string;
  threadType: 'user' | 'group';
  conversationKey: string;
  decision: ChatbotDecision;
}

export interface ChatbotDispatcherDependencies {
  sendTyping(
    accountId: string,
    threadId: string,
    threadType: 'user' | 'group',
  ): Promise<boolean>;
  sendMessage(request: ZaloSendMessageRequest): Promise<ZaloSendMessageResult>;
  insertOutboundMessage(input: OutboundMessageInput): string;
  updateMessageStatus(
    messageId: string,
    status: string,
    providerMessageId?: string,
    errorText?: string,
    clientMessageId?: string,
  ): void;
  publish(event: LocalChatEventInput): void;
  setConversationState(
    conversationKey: string,
    state: ChatbotConversationState,
  ): void;
  markProviderMessageProcessed(
    conversationKey: string,
    providerMessageId: string,
  ): void;
  enqueueAudit(
    idempotencyKey: string,
    payload: ChatbotAuditPayload,
  ): boolean;
  postAudit(request: ChatbotAuditRequest): Promise<void>;
  deleteAudit(idempotencyKey: string): void;
  markAuditFailed(idempotencyKey: string, error: string): void;
  now?: () => number;
  createClientMessageId?: () => string;
}

export type ChatbotDispatchResult =
  | {
      status: 'sent';
      localMessageId: string;
      providerMessageId: string;
    }
  | { status: 'handoff' | 'skipped'; reason: string }
  | { status: 'failed'; error: string };

export class ChatbotDispatcher {
  private readonly now: () => number;
  private readonly createClientMessageId: () => string;

  constructor(private readonly dependencies: ChatbotDispatcherDependencies) {
    this.now = dependencies.now ?? Date.now;
    this.createClientMessageId =
      dependencies.createClientMessageId
      ?? (() => `chatbot-${randomUUID()}`);
  }

  async dispatch(input: ChatbotDispatchInput): Promise<ChatbotDispatchResult> {
    const { decision } = input;
    if (decision.kind === 'reply') {
      return this.dispatchReply(input, decision);
    }
    if (decision.kind === 'handoff') {
      this.enterHandoff(input.conversationKey, decision.reason);
      this.markProcessed(input.conversationKey, decision.sourceMessageIds);
      await this.recordAudit(input, 'handoff', { reason: decision.reason });
      return { status: 'handoff', reason: decision.reason };
    }
    if (decision.kind === 'failed') {
      this.enterHandoff(input.conversationKey, decision.reason);
      await this.recordAudit(input, 'failed', {
        reason: decision.reason,
        error: decision.error,
      });
      return { status: 'failed', error: decision.error };
    }

    await this.recordAudit(input, 'skipped', { reason: decision.reason });
    return { status: 'skipped', reason: decision.reason };
  }

  private async dispatchReply(
    input: ChatbotDispatchInput,
    decision: Extract<ChatbotDecision, { kind: 'reply' }>,
  ): Promise<ChatbotDispatchResult> {
    await this.dependencies
      .sendTyping(input.accountId, input.threadId, input.threadType)
      .catch(() => false);

    const clientMessageId = this.createClientMessageId();
    let sendResult: ZaloSendMessageResult;
    try {
      sendResult = await this.dependencies.sendMessage({
        recipientId: input.threadId,
        accountId: input.accountId,
        threadType: input.threadType,
        message: decision.text,
        messageType: 'text',
        clientMessageId,
        metadata: { source: 'chatbot' },
      });
    } catch (error) {
      return this.handleSendFailure(input, error);
    }
    if (!sendResult.success) {
      return this.handleSendFailure(
        input,
        new Error(sendResult.error || 'Zalo send failed'),
      );
    }

    try {
      const metadata = {
        source: 'chatbot',
        chatbotMode: decision.mode,
        ...(decision.ruleId ? { ruleId: decision.ruleId } : {}),
        sourceMessageIds: decision.sourceMessageIds,
      };
      const localMessageId = this.dependencies.insertOutboundMessage({
        accountId: input.accountId,
        threadId: input.threadId,
        threadType: input.threadType,
        content: decision.text,
        messageType: 'text',
        clientMessageId,
        metadata,
      });
      const providerMessageId = sendResult.messageId || '';
      this.dependencies.updateMessageStatus(
        localMessageId,
        'sent',
        providerMessageId || undefined,
        '',
        sendResult.clientMessageId || clientMessageId,
      );
      this.dependencies.publish({
        type: 'message.created',
        accountId: input.accountId,
        threadId: input.threadId,
        data: {
          messageId: localMessageId,
          providerMessageId,
          clientMessageId: sendResult.clientMessageId || clientMessageId,
        },
      });
      this.markProcessed(input.conversationKey, decision.sourceMessageIds);
      await this.recordAudit(
        input,
        decision.mode === 'keyword' ? 'matched' : 'ai',
        {
          ...(decision.ruleId ? { ruleId: decision.ruleId } : {}),
          providerMessageId,
          localMessageId,
        },
      );
      return {
        status: 'sent',
        localMessageId,
        providerMessageId,
      };
    } catch (error) {
      return this.handleSendFailure(input, error);
    }
  }

  private async handleSendFailure(
    input: ChatbotDispatchInput,
    error: unknown,
  ): Promise<ChatbotDispatchResult> {
    const message = error instanceof Error ? error.message : String(error);
    this.enterHandoff(input.conversationKey, 'send_failed');
    await this.recordAudit(input, 'failed', {
      reason: 'send_failed',
      error: message,
    });
    return { status: 'failed', error: message };
  }

  private enterHandoff(conversationKey: string, reason: string): void {
    this.dependencies.setConversationState(conversationKey, {
      mode: 'handoff',
      reason,
      inherited: false,
    });
  }

  private markProcessed(
    conversationKey: string,
    providerMessageIds: string[],
  ): void {
    for (const providerMessageId of providerMessageIds) {
      this.dependencies.markProviderMessageProcessed(
        conversationKey,
        providerMessageId,
      );
    }
  }

  private async recordAudit(
    input: ChatbotDispatchInput,
    outcome: ChatbotAuditRequest['outcome'],
    details: ChatbotAuditPayload,
  ): Promise<void> {
    const idempotencyKey = createChatbotAuditIdempotencyKey(
      input.conversationKey,
      outcome,
      input.decision.sourceMessageIds,
    );
    const payload: ChatbotAuditPayload = {
      outcome,
      conversationKey: input.conversationKey,
      accountId: input.accountId,
      threadId: input.threadId,
      threadType: input.threadType,
      sourceMessageIds: input.decision.sourceMessageIds,
      timestamp: this.now(),
      ...details,
    };
    try {
      this.dependencies.enqueueAudit(idempotencyKey, payload);
      await this.dependencies.postAudit({
        idempotencyKey,
        outcome,
        conversationKey: input.conversationKey,
        timestamp: Number(payload.timestamp),
        ...payload,
      });
      this.dependencies.deleteAudit(idempotencyKey);
    } catch (error) {
      this.dependencies.markAuditFailed(
        idempotencyKey,
        error instanceof Error ? error.message : String(error),
      );
    }
  }
}

export function createChatbotAuditIdempotencyKey(
  conversationKey: string,
  outcome: ChatbotAuditRequest['outcome'],
  sourceMessageIds: string[],
): string {
  const digest = createHash('sha256')
    .update(JSON.stringify([conversationKey, outcome, sourceMessageIds]))
    .digest('hex');
  return `chatbot:${digest}`;
}
