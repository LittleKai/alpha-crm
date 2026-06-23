import type { ZaloInboundMessageEvent } from '../channels/types.js';
import { config } from '../config.js';
import { wasRecentlyAutoApproved } from '../recent-friend-approvals.js';
import {
  ConversationDebouncer,
  type DebounceScheduler,
} from './chatbot-debounce.js';
import type {
  ChatbotDecision,
  ChatbotEvaluationInput,
  ChatbotRule as EngineChatbotRule,
  ChatbotSettings as EngineChatbotSettings,
} from './chatbot-engine.js';
import type { ChatbotDispatchResult } from './chatbot-dispatcher.js';
import { isChatbotPaused } from './chatbot-store.js';
import type {
  ChatbotConfigSnapshot,
  ChatbotConversationState,
} from './chatbot-types.js';

interface PersistedInboundOptions {
  isHistory?: boolean;
  managedGroup?: boolean;
}

interface BufferedInbound {
  event: ZaloInboundMessageEvent;
  managedGroup: boolean;
}

export interface ChatbotRuntimeDependencies {
  scheduler?: DebounceScheduler;
  getConfigSnapshot(): ChatbotConfigSnapshot | undefined;
  getEffectiveConversationState(
    conversationKey: string,
    threadType: 'user' | 'group',
    snapshot: ChatbotConfigSnapshot,
  ): ChatbotConversationState | undefined;
  getConversationState(
    conversationKey: string,
  ): ChatbotConversationState | undefined;
  setConversationState(
    conversationKey: string,
    state: ChatbotConversationState,
  ): void;
  hasProcessedProviderMessage(
    conversationKey: string,
    providerMessageId: string,
  ): boolean;
  evaluate(input: ChatbotEvaluationInput): Promise<ChatbotDecision>;
  dispatch(input: {
    accountId: string;
    threadId: string;
    threadType: 'user' | 'group';
    conversationKey: string;
    decision: ChatbotDecision;
  }): Promise<ChatbotDispatchResult>;
  generateAi?: ChatbotEvaluationInput['generateAi'];
  startConfigSync(): void;
  stopConfigSync(): void;
}

export class LocalChatbotRuntime {
  private readonly debouncer: ConversationDebouncer<BufferedInbound>;
  private running = false;

  constructor(private readonly dependencies: ChatbotRuntimeDependencies) {
    this.debouncer = new ConversationDebouncer({
      delayMs: () => resolveDebounceMs(
        dependencies.getConfigSnapshot()?.settings.debounceSeconds,
      ),
      // Hard ceiling on total wait from the first buffered message. Must be >=
      // the max configurable debounce (120s) so a long debounce is not cut short.
      maxWaitMs: 120000,
      maxItems: 20,
      scheduler: dependencies.scheduler,
      onFlush: (key, values) => this.evaluateBuffered(key, values),
    });
  }

  start(): void {
    if (this.running) return;
    this.running = true;
    this.dependencies.startConfigSync();
  }

  stop(): void {
    if (!this.running) return;
    this.running = false;
    this.debouncer.stop();
    this.dependencies.stopConfigSync();
  }

  handlePersistedInbound(
    event: ZaloInboundMessageEvent,
    options: PersistedInboundOptions = {},
  ): void {
    if (
      !this.running
      || options.isHistory
      || event.senderId === event.accountId
      || !event.providerMessageId
    ) {
      const why = !this.running
        ? 'runtime not running'
        : options.isHistory
          ? 'history message'
          : event.senderId === event.accountId
            ? 'self message'
            : 'no providerMessageId';
      console.log(
        `[chatbot-flow] runtime skip pmid=${event.providerMessageId ?? '-'}: ${why}`,
      );
      return;
    }
    if (
      !config.autoReplyNewFriend
      && event.threadType === 'user'
      && wasRecentlyAutoApproved(event.senderId)
    ) {
      console.log(
        `[chatbot-flow] runtime skip pmid=${event.providerMessageId}: new friend auto-reply disabled`,
      );
      return;
    }
    const conversationKey = `${event.accountId}:${event.threadId}`;
    if (
      this.dependencies.hasProcessedProviderMessage(
        conversationKey,
        event.providerMessageId,
      )
    ) {
      console.log(
        `[chatbot-flow] runtime skip pmid=${event.providerMessageId}: already processed`,
      );
      return;
    }
    console.log(
      `[chatbot-flow] debounce push key=${conversationKey} pmid=${event.providerMessageId} ` +
        `delayMs=${resolveDebounceMs(this.dependencies.getConfigSnapshot()?.settings.debounceSeconds)}`,
    );
    this.debouncer.push(conversationKey, {
      event,
      managedGroup: options.managedGroup === true,
    });
  }

  flushConversation(conversationKey: string): Promise<void> {
    return this.debouncer.flush(conversationKey);
  }

  private async evaluateBuffered(
    conversationKey: string,
    buffered: BufferedInbound[],
  ): Promise<void> {
    if (!this.running || buffered.length === 0) return;
    const snapshot = this.dependencies.getConfigSnapshot();
    if (!snapshot) {
      console.log(
        `[chatbot-flow] flush abort key=${conversationKey}: no config snapshot`,
      );
      return;
    }

    const explicitState = this.dependencies.getConversationState(conversationKey);
    // A human operator just replied (CRM or phone) → stay silent until the
    // cooldown elapses. `mode` is still 'enabled'; this is a temporary pause.
    if (isChatbotPaused(explicitState)) {
      console.log(
        `[chatbot-flow] flush abort key=${conversationKey}: paused by operator reply`,
      );
      return;
    }

    console.log(
      `[chatbot-flow] flush key=${conversationKey} buffered=${buffered.length}`,
    );
    const first = buffered[0]!.event;
    const effective =
      explicitState
      ?? this.dependencies.getEffectiveConversationState(
        conversationKey,
        first.threadType,
        snapshot,
      );
    const decision = await this.dependencies.evaluate({
      conversationKey,
      threadType: first.threadType,
      messages: buffered.map(({ event }) => ({
        providerMessageId: event.providerMessageId,
        content: event.content,
        messageType: event.messageType,
        timestamp: event.timestamp,
        isSelf: event.senderId === event.accountId,
        isHistory: false,
      })),
      settings: toEngineSettings(snapshot),
      rules: snapshot.rules.map(toEngineRule),
      scope: {
        crmThreadKeys: new Set(snapshot.scope.crmThreadKeys),
        selectedGroupKeys: new Set(snapshot.scope.selectedGroupKeys),
      },
      conversationMode: effective?.mode ?? 'enabled',
      managedGroup: buffered.every((item) => item.managedGroup),
      mentionsBot: buffered.some(({ event }) =>
        mentionsAccount(event.mentions, event.accountId)),
      quotesBot: buffered.some(({ event }) =>
        quoteBelongsToAccount(event.quote, event.accountId)),
      isProcessed: (providerMessageId) =>
        this.dependencies.hasProcessedProviderMessage(
          conversationKey,
          providerMessageId,
        ),
      generateAi: this.dependencies.generateAi,
    });

    const detail = decision.kind === 'reply'
      ? `mode=${decision.mode}`
      : 'reason' in decision
        ? `reason=${decision.reason}`
        : '';
    console.log(
      `[chatbot-flow] decision key=${conversationKey} kind=${decision.kind} ${detail}`,
    );

    const result = await this.dependencies.dispatch({
      accountId: first.accountId,
      threadId: first.threadId,
      threadType: first.threadType,
      conversationKey,
      decision,
    });
    console.log(
      `[chatbot-flow] dispatch key=${conversationKey} status=${result.status}`,
    );
  }
}

function resolveDebounceMs(value: number | undefined): number {
  if (!Number.isFinite(value)) return 20000;
  return Math.min(120, Math.max(10, Number(value))) * 1000;
}

function toEngineSettings(
  snapshot: ChatbotConfigSnapshot,
): EngineChatbotSettings {
  return {
    enabled: snapshot.settings.enabled,
    aiEnabled: snapshot.settings.aiEnabled === true,
    keywordRulesEnabled: snapshot.settings.keywordRulesEnabled !== false,
    personalAudience: snapshot.settings.personalAudience ?? 'all',
    groupAudience: snapshot.settings.groupAudience ?? 'none',
    handoffKeywords: snapshot.settings.handoffKeywords ?? [],
  };
}

function toEngineRule(
  rule: ChatbotConfigSnapshot['rules'][number],
): EngineChatbotRule {
  return {
    id: rule.id,
    name: rule.name ?? rule.id,
    keywords: rule.keywords,
    matchMode: rule.matchMode ?? 'contains',
    response: rule.response,
    isActive: rule.isActive !== false,
    priority: rule.priority ?? 100,
    channelScope: rule.channelScope ?? 'user',
    handoffKeywords: rule.handoffKeywords ?? [],
    accountIds: rule.accountIds ?? [],
    businessHours: rule.businessHours ?? { enabled: false },
  };
}

function mentionsAccount(
  mentions: unknown[] | undefined,
  accountId: string,
): boolean {
  return (mentions ?? []).some((mention) => {
    if (!isRecord(mention)) return false;
    return [
      mention.uid,
      mention.userId,
      mention.id,
      mention.accountId,
    ].some((value) => String(value ?? '') === accountId);
  });
}

function quoteBelongsToAccount(
  quote: Record<string, unknown> | undefined,
  accountId: string,
): boolean {
  if (!quote) return false;
  return [
    quote.ownerId,
    quote.uidFrom,
    quote.senderId,
    quote.accountId,
  ].some((value) => String(value ?? '') === accountId);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
