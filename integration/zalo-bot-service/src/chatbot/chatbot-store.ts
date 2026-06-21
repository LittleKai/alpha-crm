import type Database from 'better-sqlite3';
import type { JsonObject, JsonValue } from '../local-chat/local-chat-types.js';
import type {
  ChatbotAuditPayload,
  ChatbotAuditQueueItem,
  ChatbotConfigSnapshot,
  ChatbotConversationMode,
  ChatbotConversationState,
} from './chatbot-types.js';

const conversationModes = new Set<ChatbotConversationMode>([
  'enabled',
  'handoff',
  'disabled_by_operator',
]);
const personalAudiences = new Set(['all', 'crmOnly', 'none']);
const groupAudiences = new Set(['none', 'tagOnly', 'selected']);
const matchModes = new Set(['contains', 'exact', 'startsWith']);
const channelScopes = new Set(['all', 'user', 'group']);

export class ChatbotStore {
  constructor(
    private readonly db: Database.Database,
    private readonly now: () => number = Date.now,
  ) {}

  setConversationState(
    conversationKey: string,
    state: ChatbotConversationState,
  ): void {
    validateConversationState(state);
    this.db
      .prepare(
        `INSERT INTO chatbot_conversation_state
         (conversation_key, mode, reason, inherited, paused_until, updated_at)
         VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT(conversation_key) DO UPDATE SET
           mode = excluded.mode,
           reason = excluded.reason,
           inherited = excluded.inherited,
           paused_until = excluded.paused_until,
           updated_at = excluded.updated_at`,
      )
      .run(
        conversationKey,
        state.mode,
        state.reason,
        state.inherited ? 1 : 0,
        state.pausedUntil ?? null,
        this.now(),
      );
  }

  getConversationState(
    conversationKey: string,
  ): ChatbotConversationState | undefined {
    const row = this.db
      .prepare(
        `SELECT mode, reason, inherited, paused_until
         FROM chatbot_conversation_state
         WHERE conversation_key = ?`,
      )
      .get(conversationKey) as
      | { mode: string; reason: string | null; inherited: number; paused_until: number | null }
      | undefined;
    if (!row) return undefined;

    const state = {
      mode: row.mode,
      reason: row.reason,
      inherited: row.inherited === 1,
      pausedUntil: row.paused_until ?? null,
    };
    validateConversationState(state);
    return state;
  }

  getEffectiveConversationState(
    conversationKey: string,
    threadType: 'user' | 'group',
    snapshot?: ChatbotConfigSnapshot,
  ): ChatbotConversationState | undefined {
    const explicit = this.getConversationState(conversationKey);
    if (explicit) return explicit;
    // No global config synced yet (local-first install) → default personal
    // (user) threads ON so the operator's Bot toggle starts enabled. Group
    // threads stay off until explicitly enabled.
    if (!snapshot) {
      return threadType === 'user'
        ? { mode: 'enabled', reason: 'default_personal_on', inherited: true }
        : undefined;
    }
    if (!snapshot.settings.enabled || threadType !== 'user') return undefined;

    if (snapshot.settings.personalAudience === 'all') {
      return {
        mode: 'enabled',
        reason: 'global_personal_audience',
        inherited: true,
      };
    }
    if (
      snapshot.settings.personalAudience === 'crmOnly'
      && snapshot.scope.crmThreadKeys.includes(conversationKey)
    ) {
      return {
        mode: 'enabled',
        reason: 'crm_personal_audience',
        inherited: true,
      };
    }
    return undefined;
  }

  /**
   * Resolve whether the chatbot is effectively enabled for a conversation.
   * Combines the explicit per-conversation state with the inherited audience
   * default. Used by the local conversation-list endpoint so the operator UI
   * reflects the bridge's source of truth.
   */
  resolveConversationEnabled(
    conversationKey: string,
    threadType: 'user' | 'group',
  ): {
    chatbotEnabled: boolean;
    chatbotMode: ChatbotConversationMode | null;
    chatbotReason: string | null;
    chatbotPausedUntil: number | null;
  } {
    const snapshot = this.getConfigSnapshot();
    const effective = this.getEffectiveConversationState(
      conversationKey,
      threadType,
      snapshot,
    );
    return {
      chatbotEnabled: effective?.mode === 'enabled',
      chatbotMode: (effective?.mode ?? null) as ChatbotConversationMode | null,
      chatbotReason: effective?.reason ?? null,
      chatbotPausedUntil: effective?.pausedUntil ?? null,
    };
  }

  markProviderMessageProcessed(
    conversationKey: string,
    providerMessageId: string,
  ): void {
    this.db
      .prepare(
        `INSERT OR IGNORE INTO chatbot_processed_message
         (conversation_key, provider_message_id, processed_at)
         VALUES (?, ?, ?)`,
      )
      .run(conversationKey, providerMessageId, this.now());
  }

  hasProcessedProviderMessage(
    conversationKey: string,
    providerMessageId: string,
  ): boolean {
    const row = this.db
      .prepare(
        `SELECT 1 AS found
         FROM chatbot_processed_message
         WHERE conversation_key = ? AND provider_message_id = ?`,
      )
      .get(conversationKey, providerMessageId) as
      | { found: number }
      | undefined;
    return row?.found === 1;
  }

  saveConfigSnapshot(snapshot: ChatbotConfigSnapshot): void {
    validateConfigSnapshot(snapshot);
    const payloadJson = JSON.stringify(snapshot);
    this.db.transaction(() => {
      this.db
        .prepare(
          `INSERT INTO chatbot_config_snapshot
           (singleton_id, version, payload_json, synced_at)
           VALUES (1, ?, ?, ?)
           ON CONFLICT(singleton_id) DO UPDATE SET
             version = excluded.version,
             payload_json = excluded.payload_json,
             synced_at = excluded.synced_at`,
        )
        .run(snapshot.version, payloadJson, this.now());
    })();
  }

  getConfigSnapshot(): ChatbotConfigSnapshot | undefined {
    const row = this.db
      .prepare(
        `SELECT version, payload_json AS payloadJson
         FROM chatbot_config_snapshot
         WHERE singleton_id = 1`,
      )
      .get() as { version: string; payloadJson: string } | undefined;
    if (!row) return undefined;

    // A persisted snapshot can only be invalid via schema drift (an older build
    // wrote it; the write path validates strictly). Degrade to "no config synced"
    // instead of throwing — otherwise one stale row bricks every read path
    // (conversation list, runtime, sync status). Self-heals on the next cloud
    // sync, which overwrites the row via saveConfigSnapshot.
    try {
      const parsed: unknown = JSON.parse(row.payloadJson);
      validateConfigSnapshot(parsed);
      if (parsed.version !== row.version) {
        throw new Error('Invalid chatbot config snapshot version');
      }
      return parsed;
    } catch (error) {
      console.error('[chatbot] Ignoring invalid config snapshot:', error);
      return undefined;
    }
  }

  enqueueAudit(
    idempotencyKey: string,
    payload: ChatbotAuditPayload,
  ): boolean {
    validateJsonObject(payload, 'Invalid chatbot audit payload');
    const result = this.db
      .prepare(
        `INSERT OR IGNORE INTO chatbot_audit_queue
         (idempotency_key, payload_json, attempts, created_at, last_error)
         VALUES (?, ?, 0, ?, NULL)`,
      )
      .run(idempotencyKey, JSON.stringify(payload), this.now());
    return result.changes === 1;
  }

  listPendingAudits(limit = 100): ChatbotAuditQueueItem[] {
    const rows = this.db
      .prepare(
        `SELECT idempotency_key AS idempotencyKey,
                payload_json AS payloadJson,
                attempts,
                created_at AS createdAt,
                last_error AS lastError
         FROM chatbot_audit_queue
         ORDER BY created_at ASC, idempotency_key ASC
         LIMIT ?`,
      )
      .all(limit) as Array<{
      idempotencyKey: string;
      payloadJson: string;
      attempts: number;
      createdAt: number;
      lastError: string | null;
    }>;

    return rows.map((row) => ({
      idempotencyKey: row.idempotencyKey,
      payload: parseJsonObject(row.payloadJson, 'Invalid chatbot audit JSON'),
      attempts: row.attempts,
      createdAt: row.createdAt,
      lastError: row.lastError,
    }));
  }

  countPendingAudits(): number {
    const row = this.db
      .prepare('SELECT COUNT(*) AS count FROM chatbot_audit_queue')
      .get() as { count: number };
    return row.count;
  }

  markAuditFailed(idempotencyKey: string, error: string): void {
    this.db
      .prepare(
        `UPDATE chatbot_audit_queue
         SET attempts = attempts + 1, last_error = ?
         WHERE idempotency_key = ?`,
      )
      .run(error, idempotencyKey);
  }

  deleteAudit(idempotencyKey: string): void {
    this.db
      .prepare(
        'DELETE FROM chatbot_audit_queue WHERE idempotency_key = ?',
      )
      .run(idempotencyKey);
  }
}

function validateConversationState(
  value: unknown,
): asserts value is ChatbotConversationState {
  if (!isRecord(value)
      || !conversationModes.has(value.mode as ChatbotConversationMode)
      || (value.reason !== null && typeof value.reason !== 'string')
      || typeof value.inherited !== 'boolean'
      || (value.pausedUntil != null && typeof value.pausedUntil !== 'number')) {
    throw new Error('Invalid chatbot conversation state');
  }
}

/**
 * True when the conversation is temporarily paused by a human operator reply
 * (cooldown not yet elapsed). `mode` is unaffected — this is orthogonal to the
 * permanent enabled/disabled/handoff switch.
 */
export function isChatbotPaused(
  state: ChatbotConversationState | undefined,
  now: number = Date.now(),
): boolean {
  return !!(state?.pausedUntil && now < state.pausedUntil);
}

function validateConfigSnapshot(
  value: unknown,
): asserts value is ChatbotConfigSnapshot {
  if (!isRecord(value)
      || typeof value.version !== 'string'
      || !isChatbotSettings(value.settings)
      || !Array.isArray(value.rules)
      || !value.rules.every(isChatbotRule)
      || !isRecord(value.scope)
      || !isStringArray(value.scope.crmThreadKeys)
      || !isStringArray(value.scope.selectedGroupKeys)
      || !isJsonValue(value)) {
    throw new Error('Invalid chatbot config snapshot');
  }
}

function isChatbotRule(value: unknown): boolean {
  return isRecord(value)
    && typeof value.id === 'string'
    && isStringArray(value.keywords)
    && typeof value.response === 'string'
    && (value.priority === undefined || typeof value.priority === 'number')
    && (value.isActive === undefined || typeof value.isActive === 'boolean')
    && (value.matchMode === undefined
      || matchModes.has(value.matchMode as string))
    && (value.channelScope === undefined
      || channelScopes.has(value.channelScope as string))
    && (value.accountIds === undefined || isStringArray(value.accountIds))
    && (value.businessHours === undefined
      || isBusinessHours(value.businessHours));
}

function isChatbotSettings(value: unknown): boolean {
  return isRecord(value)
    && typeof value.enabled === 'boolean'
    && (value.aiEnabled === undefined || typeof value.aiEnabled === 'boolean')
    && (value.keywordRulesEnabled === undefined
      || typeof value.keywordRulesEnabled === 'boolean')
    && (value.personalAudience === undefined
      || personalAudiences.has(value.personalAudience as string))
    && (value.groupAudience === undefined
      || groupAudiences.has(value.groupAudience as string))
    && (value.debounceSeconds === undefined
      || (
        typeof value.debounceSeconds === 'number'
        && Number.isFinite(value.debounceSeconds)
        && value.debounceSeconds >= 10
        && value.debounceSeconds <= 120
      ))
    && (value.aiHistoryLimit === undefined
      || (
        typeof value.aiHistoryLimit === 'number'
        && Number.isFinite(value.aiHistoryLimit)
        && value.aiHistoryLimit >= 0
        && value.aiHistoryLimit <= 20
      ))
    && (value.handoffKeywords === undefined
      || isStringArray(value.handoffKeywords));
}

function isBusinessHours(value: unknown): boolean {
  return isRecord(value)
    && typeof value.enabled === 'boolean'
    && (value.timezone === undefined || typeof value.timezone === 'string')
    && (value.days === undefined || (
      Array.isArray(value.days)
      && value.days.every((day) => (
        typeof day === 'number' && Number.isFinite(day)
      ))
    ))
    && (value.start === undefined || typeof value.start === 'string')
    && (value.end === undefined || typeof value.end === 'string');
}

function parseJsonObject(value: string, errorMessage: string): JsonObject {
  let parsed: unknown;
  try {
    parsed = JSON.parse(value);
  } catch {
    throw new Error(errorMessage);
  }
  validateJsonObject(parsed, errorMessage);
  return parsed;
}

function validateJsonObject(
  value: unknown,
  errorMessage: string,
): asserts value is JsonObject {
  if (!isRecord(value) || !isJsonValue(value)) {
    throw new Error(errorMessage);
  }
}

function isJsonValue(value: unknown): value is JsonValue {
  if (value === null
      || typeof value === 'string'
      || typeof value === 'boolean') {
    return true;
  }
  if (typeof value === 'number') return Number.isFinite(value);
  if (Array.isArray(value)) return value.every(isJsonValue);
  return isRecord(value) && Object.values(value).every(isJsonValue);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((item) => typeof item === 'string');
}
