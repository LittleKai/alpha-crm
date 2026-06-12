import type { JsonObject } from '../local-chat/local-chat-types.js';

export type ChatbotConversationMode =
  | 'enabled'
  | 'handoff'
  | 'disabled_by_operator';

export interface ChatbotConversationState {
  mode: ChatbotConversationMode;
  reason: string | null;
  inherited: boolean;
}

export interface ChatbotSettings {
  enabled: boolean;
  aiEnabled?: boolean;
  personalAudience?: 'all' | 'crmOnly' | 'none';
  groupAudience?: 'none' | 'tagOnly' | 'selected';
  debounceSeconds?: number;
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
