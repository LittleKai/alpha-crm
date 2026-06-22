import type { AgentCredentials } from '../agent/agent-identity.js';
import type { ZaloInboundMessageEvent } from '../channels/types.js';
import { getLocalChatStore } from '../local-chat/index.js';
import { localChatEvents } from '../local-chat/local-chat-events.js';
import { sendMessage, sendTyping } from '../zalo.js';
import { ChatbotCloudApi } from './chatbot-cloud-api.js';
import { ChatbotConfigSync } from './chatbot-config-sync.js';
import { ChatbotDispatcher } from './chatbot-dispatcher.js';
import { LocalChatbotEngine } from './chatbot-engine.js';
import { LocalChatbotRuntime } from './chatbot-runtime.js';
import { ChatbotStore } from './chatbot-store.js';
import { resolveKnowledgeFilePath } from './chatbot-knowledge-store.js';
import { buildChatbotHistory } from './chatbot-history.js';
import { filterKnowledgeSnippetsForAccount } from './chatbot-knowledge.js';

let runtime: LocalChatbotRuntime | null = null;
let chatbotStore: ChatbotStore | null = null;
let configSync: ChatbotConfigSync | null = null;
let auditSyncTimer: NodeJS.Timeout | null = null;

export function startLocalChatbotRuntime(
  credentials: AgentCredentials,
): void {
  stopLocalChatbotRuntime();
  const localStore = getLocalChatStore();
  if (!localStore) return;

  chatbotStore = new ChatbotStore(localStore.db);
  const cloudApi = new ChatbotCloudApi(credentials);
  configSync = new ChatbotConfigSync({
    store: chatbotStore,
    api: cloudApi,
  });
  const engine = new LocalChatbotEngine();
  const dispatcher = new ChatbotDispatcher({
    sendTyping,
    sendMessage: (request) => sendMessage(request, false),
    insertOutboundMessage: (input) =>
      localStore.insertOutboundMessage(input),
    updateMessageStatus: (...args) =>
      localStore.updateMessageStatus(...args),
    publish: (event) => {
      localChatEvents.publish(event);
    },
    setConversationState: (key, state) =>
      chatbotStore!.setConversationState(key, state),
    markProviderMessageProcessed: (key, providerMessageId) =>
      chatbotStore!.markProviderMessageProcessed(key, providerMessageId),
    enqueueAudit: (key, payload) =>
      chatbotStore!.enqueueAudit(key, payload),
    postAudit: (audit) => cloudApi.postAudit(audit),
    deleteAudit: (key) => chatbotStore!.deleteAudit(key),
    markAuditFailed: (key, error) =>
      chatbotStore!.markAuditFailed(key, error),
    recordResponseDaily: (outcome, accountId, timestamp, tokenIn, tokenOut) =>
      chatbotStore!.recordResponseDaily(
        outcome,
        accountId,
        timestamp,
        tokenIn,
        tokenOut,
      ),
    resolveAttachmentPath: (id) => resolveKnowledgeFilePath(id),
  });

  runtime = new LocalChatbotRuntime({
    getConfigSnapshot: () => chatbotStore!.getConfigSnapshot(),
    getEffectiveConversationState: (key, threadType, snapshot) =>
      chatbotStore!.getEffectiveConversationState(
        key,
        threadType,
        snapshot,
      ),
    getConversationState: (key) =>
      chatbotStore!.getConversationState(key),
    setConversationState: (key, state) =>
      chatbotStore!.setConversationState(key, state),
    hasProcessedProviderMessage: (key, providerMessageId) =>
      chatbotStore!.hasProcessedProviderMessage(key, providerMessageId),
    evaluate: (input) => engine.evaluate(input),
    dispatch: (input) => dispatcher.dispatch(input),
    generateAi: async ({ conversationKey, messages }) => {
      const separator = conversationKey.indexOf(':');
      const accountId = conversationKey.slice(0, separator);
      const threadId = conversationKey.slice(separator + 1);
      // Recent conversation context (collapsed turns) the operator configured the
      // AI to read. Built locally from the chat store — message text never leaves
      // this machine except inside this generate request.
      const snapshot = chatbotStore?.getConfigSnapshot();
      const limitTurns = snapshot?.settings.aiHistoryLimit ?? 5;
      let history: Array<{ role: 'user' | 'assistant'; content: string }> = [];
      if (limitTurns > 0) {
        const page = localStore.getMessagesByThread(accountId, threadId, {
          // Fetch enough raw rows to cover `limitTurns` collapsed turns.
          limit: Math.min(200, Math.max(20, limitTurns * 6)),
        });
        if (page) {
          const excludeIds = new Set(
            messages
              .map((message) => message.providerMessageId)
              .filter((id): id is string => !!id),
          );
          history = buildChatbotHistory(page.messages, excludeIds, limitTurns);
        }
      }
      // Knowledge documents filtered for this account (the cloud applies these
      // instead of its full stored set). Only sent when the operator has
      // configured knowledge so older configs fall back to the cloud's copy.
      const rawSnippets = snapshot?.settings.knowledgeSnippets;
      const knowledgeSnippets = Array.isArray(rawSnippets)
        ? filterKnowledgeSnippetsForAccount(rawSnippets, accountId)
        : undefined;
      const result = await cloudApi.generateReply({
        accountId,
        threadId,
        conversationKey,
        messages: messages.map((message) => ({
          id: message.providerMessageId,
          content: message.content,
          timestamp: Date.parse(message.timestamp) || Date.now(),
        })),
        history,
        ...(knowledgeSnippets ? { knowledgeSnippets } : {}),
      });
      return {
        reply: result.reply,
        attachments: result.attachments,
        ...(result.usage ? { usage: result.usage } : {}),
      };
    },
    startConfigSync: () => configSync!.start(),
    stopConfigSync: () => configSync!.stop(),
  });
  runtime.start();
  void flushPendingAudits(cloudApi);
  auditSyncTimer = setInterval(() => {
    void flushPendingAudits(cloudApi);
  }, 60_000);
}

export function stopLocalChatbotRuntime(): void {
  runtime?.stop();
  if (auditSyncTimer) {
    clearInterval(auditSyncTimer);
    auditSyncTimer = null;
  }
  runtime = null;
  configSync = null;
  chatbotStore = null;
}

export function handleChatbotInbound(
  event: ZaloInboundMessageEvent,
  managedGroup: boolean,
): void {
  runtime?.handlePersistedInbound(event, { managedGroup });
}

/**
 * A human operator replied (from the CRM or their phone) — pause the bot for this
 * conversation for the configured cooldown. `mode` stays 'enabled'; only a temporary
 * `pausedUntil` is set, so the bot auto-resumes once the operator goes quiet. A
 * permanent OFF (`disabled_by_operator`) or an active `handoff` is left untouched.
 */
export function pauseChatbotForOperatorReply(
  accountId: string,
  threadId: string,
): void {
  const store = chatbotStore;
  const localStore = getLocalChatStore();
  if (!store || !localStore || !accountId || !threadId) return;
  const key = `${accountId}:${threadId}`;
  const current = store.getConversationState(key);
  if (
    current
    && (current.mode === 'disabled_by_operator' || current.mode === 'handoff')
  ) {
    return;
  }
  const pausedUntil =
    Date.now() + localStore.getOperatorPauseCooldownMinutes() * 60 * 1000;
  store.setConversationState(key, {
    mode: 'enabled',
    reason: 'manual_operator_reply',
    inherited: false,
    pausedUntil,
  });
  localChatEvents.publish({
    type: 'conversation.chatbot_state',
    accountId,
    threadId,
    data: {
      conversationKey: key,
      mode: 'enabled',
      reason: 'manual_operator_reply',
      inherited: false,
      pausedUntil,
      effectiveEnabled: false,
    },
  });
}

export function getLocalChatbotRuntime(): LocalChatbotRuntime | null {
  return runtime;
}

export function getChatbotStore(): ChatbotStore | null {
  return chatbotStore;
}

export function getChatbotConfigSync(): ChatbotConfigSync | null {
  return configSync;
}

async function flushPendingAudits(cloudApi: ChatbotCloudApi): Promise<void> {
  const store = chatbotStore;
  if (!store) return;
  for (const item of store.listPendingAudits(50)) {
    try {
      const outcome = String(item.payload.outcome || 'skipped');
      if (!['matched', 'ai', 'handoff', 'skipped', 'failed'].includes(outcome)) {
        store.markAuditFailed(item.idempotencyKey, 'Invalid audit outcome');
        continue;
      }
      await cloudApi.postAudit({
        ...item.payload,
        idempotencyKey: item.idempotencyKey,
        outcome: outcome as 'matched' | 'ai' | 'handoff' | 'skipped' | 'failed',
        conversationKey: String(item.payload.conversationKey || ''),
        timestamp: Number(item.payload.timestamp || item.createdAt),
      });
      store.deleteAudit(item.idempotencyKey);
    } catch (error) {
      store.markAuditFailed(
        item.idempotencyKey,
        error instanceof Error ? error.message : String(error),
      );
    }
  }
}
