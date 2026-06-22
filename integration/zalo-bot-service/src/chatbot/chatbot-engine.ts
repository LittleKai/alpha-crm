import { normalizeVietnamese } from './chatbot-text.js';

export type ChatbotConversationMode =
  | 'enabled'
  | 'handoff'
  | 'disabled_by_operator';

export interface ChatbotSettings {
  enabled: boolean;
  aiEnabled: boolean;
  keywordRulesEnabled: boolean;
  personalAudience: 'all' | 'crmOnly' | 'none';
  groupAudience: 'none' | 'tagOnly' | 'selected';
  handoffKeywords: string[];
}

export interface ChatbotBusinessHours {
  enabled: boolean;
  timezone?: string;
  days?: number[];
  start?: string;
  end?: string;
}

export interface ChatbotRule {
  id: string;
  name: string;
  keywords: string[];
  matchMode: 'contains' | 'exact' | 'startsWith';
  response: string;
  isActive: boolean;
  priority: number;
  channelScope: 'all' | 'user' | 'group';
  handoffKeywords: string[];
  // Zalo account ids this rule applies to. Empty = all accounts.
  accountIds: string[];
  businessHours: ChatbotBusinessHours;
}

export interface ChatbotAttachment {
  type: 'image' | 'video' | 'audio' | 'file';
  // Content-hash id resolved to a local file path by the bridge at send time.
  id: string;
  name: string;
}

export interface ChatbotInboundMessage {
  providerMessageId: string;
  content: string;
  messageType: string;
  timestamp: string;
  isSelf?: boolean;
  isHistory?: boolean;
}

export interface ChatbotEvaluationInput {
  conversationKey: string;
  threadType: 'user' | 'group';
  messages: ChatbotInboundMessage[];
  settings: ChatbotSettings;
  rules: ChatbotRule[];
  scope: {
    crmThreadKeys: ReadonlySet<string>;
    selectedGroupKeys: ReadonlySet<string>;
  };
  conversationMode: ChatbotConversationMode;
  managedGroup: boolean;
  mentionsBot: boolean;
  quotesBot: boolean;
  isProcessed: (providerMessageId: string) => boolean;
  generateAi?: (request: {
    conversationKey: string;
    messages: ChatbotInboundMessage[];
  }) => Promise<{
    reply: string;
    attachments?: ChatbotAttachment[];
    usage?: Record<string, unknown>;
  }>;
  now?: Date;
}

export type ChatbotDecision =
  | {
      kind: 'reply';
      mode: 'keyword' | 'ai';
      text: string;
      ruleId?: string;
      attachments?: ChatbotAttachment[];
      // AI token usage (mode 'ai' only) — persisted to the local daily stats.
      tokenIn?: number;
      tokenOut?: number;
      // CrmAiUsage id from the cloud generate call, for the response-log token link.
      usageId?: string;
      sourceMessageIds: string[];
    }
  | {
      kind: 'handoff';
      reason: 'handoff_keyword';
      sourceMessageIds: string[];
    }
  | {
      kind: 'failed';
      reason: 'ai_failed';
      error: string;
      enterHandoff: true;
      sourceMessageIds: string[];
    }
  | {
      kind: 'skipped';
      reason: string;
      sourceMessageIds: string[];
    };

/** Coerce an opaque usage value to a non-negative integer token count. */
function toTokenCount(value: unknown): number {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? Math.trunc(n) : 0;
}

export class LocalChatbotEngine {
  async evaluate(input: ChatbotEvaluationInput): Promise<ChatbotDecision> {
    const sourceMessageIds = input.messages.map(
      (message) => message.providerMessageId,
    );
    const skip = (reason: string): ChatbotDecision => ({
      kind: 'skipped',
      reason,
      sourceMessageIds,
    });

    if (!input.settings.enabled) return skip('global_disabled');
    if (input.conversationMode !== 'enabled') {
      return skip(`conversation_${input.conversationMode}`);
    }

    if (input.threadType === 'user') {
      if (input.settings.personalAudience === 'none') {
        return skip('personal_audience');
      }
      if (
        input.settings.personalAudience === 'crmOnly'
        && !input.scope.crmThreadKeys.has(input.conversationKey)
      ) {
        return skip('personal_audience');
      }
    } else {
      if (!input.managedGroup || input.settings.groupAudience === 'none') {
        return skip('group_audience');
      }
      if (!input.mentionsBot && !input.quotesBot) {
        return skip('group_trigger');
      }
      if (
        input.settings.groupAudience === 'selected'
        && !input.scope.selectedGroupKeys.has(input.conversationKey)
      ) {
        return skip('group_audience');
      }
    }

    const messages = input.messages.filter(
      (message) =>
        !message.isSelf
        && !message.isHistory
        && message.messageType === 'text'
        && message.content.trim().length > 0
        && !input.isProcessed(message.providerMessageId),
    );
    if (messages.length === 0) return skip('no_eligible_messages');

    const combinedContent = messages
      .map((message) => message.content.trim())
      .join('\n');
    const eligibleIds = messages.map((message) => message.providerMessageId);
    // conversationKey is `${accountId}:${threadId}`; accountId never contains ':'.
    const accountId = input.conversationKey.split(':')[0] ?? '';
    // Master switch off → no keyword scenarios at all (rule matching AND
    // rule-level handoff keywords). Global handoff keywords still apply; AI still
    // runs if enabled.
    const applicableRules = input.settings.keywordRulesEnabled === false
      ? []
      : input.rules
          .filter(
            (rule) =>
              rule.isActive
              && (rule.channelScope === 'all'
                || rule.channelScope === input.threadType)
              && (rule.accountIds.length === 0
                || rule.accountIds.includes(accountId)),
          )
          .sort((left, right) => left.priority - right.priority);

    const handoffKeywords = [
      ...input.settings.handoffKeywords,
      ...applicableRules.flatMap((rule) => rule.handoffKeywords),
    ];
    if (containsKeyword(combinedContent, handoffKeywords)) {
      return {
        kind: 'handoff',
        reason: 'handoff_keyword',
        sourceMessageIds: eligibleIds,
      };
    }

    const now = input.now ?? new Date();
    const matchedRule = applicableRules.find(
      (rule) =>
        isWithinBusinessHours(rule.businessHours, now)
        && matchesRule(rule, combinedContent),
    );
    if (matchedRule) {
      return {
        kind: 'reply',
        mode: 'keyword',
        text: matchedRule.response,
        ruleId: matchedRule.id,
        sourceMessageIds: eligibleIds,
      };
    }

    if (!input.settings.aiEnabled) return {
      kind: 'skipped',
      reason: 'no_matching_rule',
      sourceMessageIds: eligibleIds,
    };

    try {
      if (!input.generateAi) {
        throw new Error('AI generator is unavailable');
      }
      const generated = await input.generateAi({
        conversationKey: input.conversationKey,
        messages,
      });
      const reply = generated.reply.trim();
      const attachments = generated.attachments ?? [];
      if (!reply && attachments.length === 0) {
        throw new Error('AI returned an empty reply');
      }
      const usage = generated.usage;
      const usageId =
        typeof usage?.id === 'string'
          ? usage.id
          : usage?.id != null
            ? String(usage.id)
            : undefined;
      return {
        kind: 'reply',
        mode: 'ai',
        text: reply,
        ...(attachments.length ? { attachments } : {}),
        tokenIn: toTokenCount(usage?.promptTokens),
        tokenOut: toTokenCount(usage?.completionTokens),
        ...(usageId ? { usageId } : {}),
        sourceMessageIds: eligibleIds,
      };
    } catch (error) {
      return {
        kind: 'failed',
        reason: 'ai_failed',
        error: error instanceof Error ? error.message : String(error),
        enterHandoff: true,
        sourceMessageIds: eligibleIds,
      };
    }
  }
}

function containsKeyword(content: string, keywords: string[]): boolean {
  const normalized = normalizeVietnamese(content);
  return keywords.some((keyword) => {
    const candidate = normalizeVietnamese(keyword);
    return candidate.length > 0 && normalized.includes(candidate);
  });
}

function matchesRule(rule: ChatbotRule, content: string): boolean {
  const normalized = normalizeVietnamese(content);
  return rule.keywords.some((keyword) => {
    const candidate = normalizeVietnamese(keyword);
    if (!candidate) return false;
    if (rule.matchMode === 'exact') return normalized === candidate;
    if (rule.matchMode === 'startsWith') {
      return normalized.startsWith(candidate);
    }
    return normalized.includes(candidate);
  });
}

function isWithinBusinessHours(
  businessHours: ChatbotBusinessHours,
  now: Date,
): boolean {
  if (!businessHours.enabled) return true;
  const timezone = businessHours.timezone || 'Asia/Ho_Chi_Minh';
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);
  const value = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)?.value ?? '';
  const weekdays: Record<string, number> = {
    Sun: 0,
    Mon: 1,
    Tue: 2,
    Wed: 3,
    Thu: 4,
    Fri: 5,
    Sat: 6,
  };
  const day = weekdays[value('weekday')];
  if (day === undefined) return false;
  if (
    businessHours.days?.length
    && !businessHours.days.includes(day)
  ) {
    return false;
  }

  const current = `${value('hour')}:${value('minute')}`;
  const start = businessHours.start || '08:00';
  const end = businessHours.end || '18:00';
  if (start <= end) return current >= start && current <= end;
  return current >= start || current <= end;
}

