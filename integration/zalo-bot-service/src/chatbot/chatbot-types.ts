import type { JsonObject } from '../local-chat/local-chat-types.js';

export type ChatbotConversationMode =
  | 'enabled'
  | 'handoff'
  | 'disabled_by_operator';

export interface ChatbotConversationState {
  mode: ChatbotConversationMode;
  reason: string | null;
  inherited: boolean;
  // When set and in the future, the bot is temporarily paused because a human
  // operator replied (CRM or phone). `mode` stays 'enabled' — this is an orthogonal
  // cooldown that auto-expires, distinct from a permanent `disabled_by_operator`.
  pausedUntil?: number | null;
}

export interface ChatbotSettings {
  enabled: boolean;
  aiEnabled?: boolean;
  // Master switch for keyword scenarios. When false, no keyword rule is applied
  // (AI still works if enabled). Default true.
  keywordRulesEnabled?: boolean;
  personalAudience?: 'all' | 'crmOnly' | 'none';
  groupAudience?: 'none' | 'tagOnly' | 'selected';
  debounceSeconds?: number;
  // Number of recent conversation turns (consecutive same-sender messages
  // collapsed into one) the bridge sends to the AI as context. 0 = none.
  aiHistoryLimit?: number;
  // Knowledge documents (each may carry an `[Accounts]` targeting tag). The
  // bridge filters these per account before sending them to the cloud.
  knowledgeSnippets?: string[];
  handoffKeywords?: string[];
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
  name?: string;
  keywords: string[];
  response: string;
  priority?: number;
  isActive?: boolean;
  matchMode?: 'contains' | 'exact' | 'startsWith';
  channelScope?: 'all' | 'user' | 'group';
  handoffKeywords?: string[];
  // Zalo account ids this rule applies to. Empty/undefined = all accounts.
  accountIds?: string[];
  businessHours?: ChatbotBusinessHours;
}

export interface ChatbotConfigSnapshot {
  version: string;
  settings: ChatbotSettings;
  rules: ChatbotRule[];
  scope: {
    crmThreadKeys: string[];
    selectedGroupKeys: string[];
  };
}

export type ChatbotAuditPayload = JsonObject;

export interface ChatbotAuditQueueItem {
  idempotencyKey: string;
  payload: ChatbotAuditPayload;
  attempts: number;
  createdAt: number;
  lastError: string | null;
}
