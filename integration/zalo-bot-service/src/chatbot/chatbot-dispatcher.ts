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
  // Durable per-day response counter, independent of the sync queue. Optional so
  // existing tests/wiring without it keep working.
  recordResponseDaily?(
    outcome: string,
    accountId: string,
    timestamp: number,
    tokenIn: number,
    tokenOut: number,
  ): void;
  // Resolve a knowledge-file id to its local file path on this machine, or null
  // if the file is missing (e.g. configured on another machine). zca-js sends
  // the local path directly — no download.
  resolveAttachmentPath?(id: string): string | null;
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

    // `group_trigger` (group reply only when mentioned/replied-to) is the normal
    // resting state in groups — it would flood the response log, so don't audit
    // or count it. Other skip reasons are still logged for visibility.
    if (decision.reason !== 'group_trigger') {
      await this.recordAudit(input, 'skipped', { reason: decision.reason });
    }
    return { status: 'skipped', reason: decision.reason };
  }

  private async dispatchReply(
    input: ChatbotDispatchInput,
    decision: Extract<ChatbotDecision, { kind: 'reply' }>,
  ): Promise<ChatbotDispatchResult> {
    await this.dependencies
      .sendTyping(input.accountId, input.threadId, input.threadType)
      .catch(() => false);

    const text = decision.text.trim();
    const attachments = decision.attachments ?? [];

    let lastLocalMessageId = '';
    let lastProviderMessageId = '';

    // 1) Text part. A text send failure is fatal (enters handoff) exactly as
    //    before — only sent when there is text, so a file-only reply is allowed.
    if (text.length > 0) {
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
        lastLocalMessageId = localMessageId;
        lastProviderMessageId = providerMessageId;
      } catch (error) {
        return this.handleSendFailure(input, error);
      }
    }

    // 2) Attachment parts. Supplementary — a per-file failure is logged and
    //    skipped so it never undoes an already-delivered text message.
    for (const attachment of attachments) {
      const sent = await this.dispatchAttachment(input, decision, attachment);
      if (sent) {
        lastLocalMessageId = sent.localMessageId || lastLocalMessageId;
        lastProviderMessageId = sent.providerMessageId || lastProviderMessageId;
      }
    }

    // Nothing got out the door (e.g. empty text and every attachment failed).
    if (!lastProviderMessageId && !lastLocalMessageId) {
      return this.handleSendFailure(
        input,
        new Error('Chatbot reply had no deliverable content'),
      );
    }

    this.markProcessed(input.conversationKey, decision.sourceMessageIds);
    await this.recordAudit(
      input,
      decision.mode === 'keyword' ? 'matched' : 'ai',
      {
        ...(decision.ruleId ? { ruleId: decision.ruleId } : {}),
        // The actual reply text so the cloud log can show a preview. Without
        // this the "Nội dung phản hồi" column is blank (keyword replies never
        // reach the cloud generate endpoint, so the cloud has no other source).
        responsePreview:
          text || (attachments.length ? '[Đã gửi tệp đính kèm]' : ''),
        providerMessageId: lastProviderMessageId,
        localMessageId: lastLocalMessageId,
        ...(attachments.length ? { attachmentCount: attachments.length } : {}),
      },
    );
    return {
      status: 'sent',
      localMessageId: lastLocalMessageId,
      providerMessageId: lastProviderMessageId,
    };
  }

  private async dispatchAttachment(
    input: ChatbotDispatchInput,
    decision: Extract<ChatbotDecision, { kind: 'reply' }>,
    attachment: NonNullable<
      Extract<ChatbotDecision, { kind: 'reply' }>['attachments']
    >[number],
  ): Promise<{ localMessageId: string; providerMessageId: string } | null> {
    const resolve = this.dependencies.resolveAttachmentPath;
    if (!resolve) return null;

    const localPath = resolve(attachment.id);
    if (!localPath) {
      // Missing on this machine — most likely attached on another device. Skip
      // (never blocks the text reply); the operator is warned in the knowledge
      // tab via the present-ids list.
      console.error(
        `[ChatbotDispatcher] Knowledge file missing locally, skipping (${attachment.name}, id=${attachment.id}).`,
      );
      return null;
    }

    try {
      const clientMessageId = this.createClientMessageId();
      const messageType = mapAttachmentMessageType(attachment.type);
      const sendResult = await this.dependencies.sendMessage({
        recipientId: input.threadId,
        accountId: input.accountId,
        threadType: input.threadType,
        message: '',
        messageType,
        attachments: [localPath],
        attachmentNames: [attachment.name || ''],
        clientMessageId,
        metadata: { source: 'chatbot' },
      });
      if (!sendResult.success) {
        console.error(
          `[ChatbotDispatcher] Attachment send failed (${attachment.name}): ${sendResult.error}`,
        );
        return null;
      }
      const localMessageId = this.dependencies.insertOutboundMessage({
        accountId: input.accountId,
        threadId: input.threadId,
        threadType: input.threadType,
        content: attachment.name || '',
        messageType,
        clientMessageId,
        metadata: {
          source: 'chatbot',
          chatbotMode: decision.mode,
          sourceMessageIds: decision.sourceMessageIds,
        },
        attachments: [
          {
            kind: attachment.type,
            name: attachment.name,
            localPath,
          },
        ],
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
      return { localMessageId, providerMessageId };
    } catch (error) {
      console.error(
        `[ChatbotDispatcher] Attachment dispatch error (${attachment.name}):`,
        error,
      );
      return null;
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
    // Durable local stats first — independent of cloud upload success, so the
    // dashboard's response chart is correct even fully offline.
    const decision = input.decision;
    const tokenIn =
      decision.kind === 'reply' && decision.mode === 'ai'
        ? decision.tokenIn ?? 0
        : 0;
    const tokenOut =
      decision.kind === 'reply' && decision.mode === 'ai'
        ? decision.tokenOut ?? 0
        : 0;
    this.dependencies.recordResponseDaily?.(
      outcome,
      input.accountId,
      Number(payload.timestamp),
      tokenIn,
      tokenOut,
    );
    // Carry token usage to the cloud so the response log shows Token (In/Out)
    // for personal/live AI replies instead of 0/0.
    if (decision.kind === 'reply' && decision.mode === 'ai') {
      payload.tokenIn = tokenIn;
      payload.tokenOut = tokenOut;
      if (decision.usageId) {
        payload.aiUsageId = decision.usageId;
      }
    }
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

function mapAttachmentMessageType(
  type: 'image' | 'video' | 'audio' | 'file',
): 'image' | 'video' | 'voice' | 'file' {
  if (type === 'image') return 'image';
  if (type === 'video') return 'video';
  if (type === 'audio') return 'voice';
  return 'file';
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
