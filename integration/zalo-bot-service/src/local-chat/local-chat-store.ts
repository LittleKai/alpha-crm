/**
 * Local-first Live Chat SQLite store.
 * Owns full message history; cloud receives metadata only.
 */

import Database from 'better-sqlite3';
import { randomUUID } from 'crypto';
import { mkdirSync, existsSync } from 'fs';
import { dirname } from 'path';
import type {
  LocalConversation,
  LocalConversationTimelineItem,
  LocalMessage,
  LocalAttachment,
  InboundMessageInput,
  OutboundMessageInput,
  AttachmentInput,
  HistoryState,
  MessagePage,
  MessageReaction,
  MessageReceipt,
} from './local-chat-types.js';

type ConversationMetadataInput = {
  tags?: unknown;
  notes?: unknown;
  customAttributes?: unknown;
  archived?: unknown;
  assignedTo?: unknown;
  followUpAt?: unknown;
};

type LocalAutomationRule = {
  id: string;
  name: string;
  event: string;
  conditionField: string;
  conditionOperator: string;
  conditionValue: string;
  actions: string[];
  enabled: boolean;
  createdAt: string;
};

function parsePreviewRecord(value: unknown): Record<string, unknown> | null {
  if (!value) return null;
  if (typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  if (typeof value === 'string' && value.trim().startsWith('{')) {
    try {
      const parsed = JSON.parse(value);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed as Record<string, unknown>;
      }
    } catch {
      return null;
    }
  }
  return null;
}

function cleanPreviewText(value: string): string {
  const trimmed = value.trim();
  return trimmed.length > 100 ? `${trimmed.slice(0, 100)}...` : trimmed;
}

function previewForType(messageType?: string): string | null {
  const type = (messageType || '').toLowerCase();
  if (type === 'image' || type === 'gif') return '[Hình ảnh]';
  if (type === 'file') return '[Tệp đính kèm]';
  if (type === 'sticker') return '[Sticker]';
  if (type === 'video') return '[Video]';
  if (type === 'voice' || type === 'audio') return '[Tin nhắn thoại]';
  if (type === 'link' || type === 'rich') return 'Liên kết';
  return null;
}

function previewForStructuredContent(content: unknown): string | null {
  const record = parsePreviewRecord(content);
  if (!record) return null;
  const typed = previewForType(
    String(record.messageType || record.contentType || ''),
  );
  if (typed) return typed;
  const params = parsePreviewRecord(record.params);
  if (
    params &&
    (params.fileExt != null || params.fileName != null || params.fType === 1)
  ) {
    return '[Tệp đính kèm]';
  }
  const title = String(record.title || '').trim();
  const description = String(record.description || '').trim();
  const href = String(record.href || record.url || '').trim();
  if (title || description || href) {
    return title || description || 'Liên kết';
  }
  return null;
}

function buildMessagePreview(input: {
  content: string;
  messageType?: string;
  attachments?: AttachmentInput[];
}): string {
  if (input.attachments?.some((item) => item.kind === 'image')) {
    return '[Hình ảnh]';
  }
  if (input.attachments?.length) {
    return '[Tệp đính kèm]';
  }
  const typed = previewForType(input.messageType);
  if (typed) return typed;
  const structured = previewForStructuredContent(input.content);
  if (structured) return cleanPreviewText(structured);
  if (/^https?:\/\//i.test(input.content.trim())) return 'Liên kết';
  return cleanPreviewText(input.content);
}

function parseJsonObject(value: unknown): Record<string, unknown> {
  if (!value) return {};
  if (typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  if (typeof value === 'string' && value.trim().startsWith('{')) {
    try {
      const parsed = JSON.parse(value);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed as Record<string, unknown>;
      }
    } catch {
      return {};
    }
  }
  return {};
}

function parseJsonStringList(value: unknown): string[] {
  let raw: unknown = [];
  if (Array.isArray(value)) {
    raw = value;
  } else if (typeof value === 'string' && value.trim().startsWith('[')) {
    try {
      raw = JSON.parse(value);
    } catch {
      raw = [];
    }
  }
  if (!Array.isArray(raw)) return [];
  return raw
    .map((item) => String(item || '').trim())
    .filter((item) => item.length > 0);
}

function parseStringMap(value: unknown): Record<string, string> {
  const parsed = parseJsonObject(value);
  const result: Record<string, string> = {};
  for (const [key, item] of Object.entries(parsed)) {
    const cleanKey = key.trim();
    if (!cleanKey) continue;
    result[cleanKey] = item == null ? '' : String(item);
  }
  return result;
}

function dateKey(value: string | undefined): string {
  const parsed = value ? new Date(value) : new Date();
  if (Number.isNaN(parsed.getTime())) return new Date().toISOString().slice(0, 10);
  return parsed.toISOString().slice(0, 10);
}

export class LocalChatStore {
  private _db: Database.Database;

  get db(): Database.Database {
    return this._db;
  }

  constructor(dbPath: string) {
    const dir = dirname(dbPath);
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true });
    }
    this._db = new Database(dbPath);
    this._db.pragma('journal_mode = WAL');
    this._db.pragma('foreign_keys = ON');
    this._migrate();
  }

  /** Run idempotent schema migration */
  private _migrate(): void {
    // Migrate message_reactions to support stacking (multiple reactions per user)
    try {
      const tableExists = this._db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='message_reactions'").get();
      if (tableExists) {
        const info = this._db.pragma('table_info(message_reactions)') as any[];
        const hasId = info.some((col: any) => col.name === 'id');
        if (!hasId) {
          this._db.exec(`
            ALTER TABLE message_reactions RENAME TO message_reactions_old;
            CREATE TABLE message_reactions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              messageId TEXT NOT NULL,
              userId TEXT NOT NULL,
              reaction TEXT NOT NULL,
              timestamp TEXT NOT NULL,
              FOREIGN KEY (messageId) REFERENCES messages(id)
            );
            INSERT INTO message_reactions (messageId, userId, reaction, timestamp)
            SELECT messageId, userId, reaction, timestamp FROM message_reactions_old;
            DROP TABLE message_reactions_old;
          `);
        }
      }
    } catch (e) {
      console.error('Failed to migrate message_reactions:', e);
    }

    this._db.exec(`
      CREATE TABLE IF NOT EXISTS conversations (
        id TEXT PRIMARY KEY,
        accountId TEXT NOT NULL,
        threadId TEXT NOT NULL,
        threadType TEXT NOT NULL DEFAULT 'user',
        displayName TEXT NOT NULL DEFAULT '',
        avatarUrl TEXT NOT NULL DEFAULT '',
        lastMessagePreview TEXT NOT NULL DEFAULT '',
        lastMessageAt TEXT NOT NULL DEFAULT '',
        unreadCount INTEGER NOT NULL DEFAULT 0,
        tagsJson TEXT NOT NULL DEFAULT '[]',
        notes TEXT NOT NULL DEFAULT '',
        customAttributesJson TEXT NOT NULL DEFAULT '{}',
        archived INTEGER NOT NULL DEFAULT 0,
        assignedTo TEXT NOT NULL DEFAULT '',
        followUpAt TEXT NOT NULL DEFAULT '',
        managedGroup INTEGER NOT NULL DEFAULT 0,
        cloudConversationId TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      );

      CREATE UNIQUE INDEX IF NOT EXISTS idx_conv_account_thread
        ON conversations(accountId, threadId);

      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        conversationId TEXT NOT NULL,
        accountId TEXT NOT NULL,
        threadId TEXT NOT NULL,
        threadType TEXT NOT NULL DEFAULT 'user',
        direction TEXT NOT NULL DEFAULT 'inbound',
        senderId TEXT NOT NULL DEFAULT '',
        senderName TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        messageType TEXT NOT NULL DEFAULT 'text',
        providerMessageId TEXT NOT NULL DEFAULT '',
        zaloMsgId TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT '',
        isDeleted INTEGER NOT NULL DEFAULT 0,
        receivedAt TEXT NOT NULL DEFAULT '',
        sentAt TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (conversationId) REFERENCES conversations(id)
      );

      CREATE INDEX IF NOT EXISTS idx_msg_conv_created
        ON messages(conversationId, createdAt);

      CREATE UNIQUE INDEX IF NOT EXISTS idx_msg_account_provider
        ON messages(accountId, providerMessageId)
        WHERE providerMessageId != '';

      CREATE TABLE IF NOT EXISTS attachments (
        id TEXT PRIMARY KEY,
        messageId TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL DEFAULT '',
        url TEXT NOT NULL DEFAULT '',
        localPath TEXT NOT NULL DEFAULT '',
        mimeType TEXT NOT NULL DEFAULT '',
        sizeBytes INTEGER NOT NULL DEFAULT 0,
        metadataJson TEXT NOT NULL DEFAULT '{}',
        createdAt TEXT NOT NULL,
        FOREIGN KEY (messageId) REFERENCES messages(id)
      );

      CREATE INDEX IF NOT EXISTS idx_attach_msg
        ON attachments(messageId);

      CREATE TABLE IF NOT EXISTS sync_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL DEFAULT '',
        updatedAt TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS sync_queue (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        payloadJson TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        retryCount INTEGER NOT NULL DEFAULT 0,
        nextRetryAt TEXT NOT NULL,
        createdAt TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS message_receipts (
        messageId TEXT NOT NULL,
        userId TEXT NOT NULL,
        status TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        PRIMARY KEY (messageId, userId, status),
        FOREIGN KEY (messageId) REFERENCES messages(id)
      );

      CREATE TABLE IF NOT EXISTS message_reactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        messageId TEXT NOT NULL,
        userId TEXT NOT NULL,
        reaction TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (messageId) REFERENCES messages(id)
      );

      CREATE TABLE IF NOT EXISTS chat_drafts (
        accountId TEXT NOT NULL,
        threadId TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        updatedAt TEXT NOT NULL,
        PRIMARY KEY (accountId, threadId)
      );

      CREATE TABLE IF NOT EXISTS conversation_timeline (
        id TEXT PRIMARY KEY,
        conversationId TEXT NOT NULL,
        eventType TEXT NOT NULL,
        summary TEXT NOT NULL DEFAULT '',
        metadataJson TEXT NOT NULL DEFAULT '{}',
        createdAt TEXT NOT NULL,
        FOREIGN KEY (conversationId) REFERENCES conversations(id)
      );

      CREATE INDEX IF NOT EXISTS idx_conv_timeline_conv_time
        ON conversation_timeline(conversationId, createdAt DESC);

      CREATE TABLE IF NOT EXISTS conversation_metrics_daily (
        date TEXT NOT NULL,
        accountId TEXT NOT NULL DEFAULT '',
        inboundMessages INTEGER NOT NULL DEFAULT 0,
        outboundMessages INTEGER NOT NULL DEFAULT 0,
        newConversations INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (date, accountId)
      );

      CREATE TABLE IF NOT EXISTS automation_rules (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        event TEXT NOT NULL DEFAULT '',
        conditionField TEXT NOT NULL DEFAULT '',
        conditionOperator TEXT NOT NULL DEFAULT '',
        conditionValue TEXT NOT NULL DEFAULT '',
        actionsJson TEXT NOT NULL DEFAULT '[]',
        enabled INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS history_state (
        accountId TEXT NOT NULL,
        threadId TEXT NOT NULL,
        oldestTimestamp TEXT NOT NULL DEFAULT '',
        hasMore INTEGER NOT NULL DEFAULT 1,
        loading INTEGER NOT NULL DEFAULT 0,
        lastError TEXT NOT NULL DEFAULT '',
        updatedAt TEXT NOT NULL,
        PRIMARY KEY (accountId, threadId)
      );

      CREATE TABLE IF NOT EXISTS zalo_event_log (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        accountId TEXT NOT NULL DEFAULT '',
        threadId TEXT NOT NULL DEFAULT '',
        dataJson TEXT NOT NULL DEFAULT '{}',
        timestamp TEXT NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_zalo_event_thread_time
        ON zalo_event_log(accountId, threadId, timestamp);

      CREATE TABLE IF NOT EXISTS chatbot_conversation_state (
        conversation_key TEXT PRIMARY KEY,
        mode TEXT NOT NULL,
        reason TEXT,
        inherited INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL,
        last_processed_message_id TEXT
      );

      CREATE TABLE IF NOT EXISTS chatbot_config_snapshot (
        singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
        version TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        synced_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS chatbot_audit_queue (
        idempotency_key TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        last_error TEXT
      );

      CREATE TABLE IF NOT EXISTS chatbot_processed_message (
        conversation_key TEXT NOT NULL,
        provider_message_id TEXT NOT NULL,
        processed_at INTEGER NOT NULL,
        PRIMARY KEY (conversation_key, provider_message_id)
      );

      CREATE TABLE IF NOT EXISTS chatbot_response_daily (
        date TEXT NOT NULL,
        account_id TEXT NOT NULL,
        ai INTEGER NOT NULL DEFAULT 0,
        keyword INTEGER NOT NULL DEFAULT 0,
        skipped INTEGER NOT NULL DEFAULT 0,
        token_in INTEGER NOT NULL DEFAULT 0,
        token_out INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (date, account_id)
      );

      CREATE TABLE IF NOT EXISTS account_chat_settings (
        accountId TEXT PRIMARY KEY,
        aiAutoReply INTEGER NOT NULL DEFAULT 1,
        updatedAt TEXT NOT NULL DEFAULT ''
      );

      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    `);

    // ── Incremental migrations (idempotent) ──
    // Add senderAvatarUrl column to messages if not present
    try {
      this.db.exec(`ALTER TABLE messages ADD COLUMN senderAvatarUrl TEXT NOT NULL DEFAULT ''`);
    } catch {
      // Column already exists — ignore
    }
    const additionalColumns = [
      ['messages', "clientMessageId TEXT NOT NULL DEFAULT ''"],
      ['messages', "errorText TEXT NOT NULL DEFAULT ''"],
      ['messages', "quoteJson TEXT NOT NULL DEFAULT '{}'"],
      ['messages', "mentionsJson TEXT NOT NULL DEFAULT '[]'"],
      ['messages', "stylesJson TEXT NOT NULL DEFAULT '[]'"],
      ['messages', "metadataJson TEXT NOT NULL DEFAULT '{}'"],
      ['messages', "recalledContent TEXT NOT NULL DEFAULT ''"],
      ['conversations', "tagsJson TEXT NOT NULL DEFAULT '[]'"],
      ['conversations', "notes TEXT NOT NULL DEFAULT ''"],
      ['conversations', "customAttributesJson TEXT NOT NULL DEFAULT '{}'"],
      ['conversations', "archived INTEGER NOT NULL DEFAULT 0"],
      ['conversations', "assignedTo TEXT NOT NULL DEFAULT ''"],
      ['conversations', "followUpAt TEXT NOT NULL DEFAULT ''"],
      ['attachments', "status TEXT NOT NULL DEFAULT 'ready'"],
      ['attachments', "checksum TEXT NOT NULL DEFAULT ''"],
      ['attachments', "errorText TEXT NOT NULL DEFAULT ''"],
      ['attachments', "downloadedAt TEXT NOT NULL DEFAULT ''"],
      // Operator-reply cooldown: while in the future the bot is temporarily paused.
      ['chatbot_conversation_state', 'paused_until INTEGER'],
    ] as const;
    for (const [table, definition] of additionalColumns) {
      try {
        this.db.exec(`ALTER TABLE ${table} ADD COLUMN ${definition}`);
      } catch {
        // Column already exists.
      }
    }

    // One-time cleanup: legacy operator-takeover rows stored a PERMANENT
    // `disabled_by_operator` with reason `manual_operator_reply`. Under the new
    // model an operator reply only sets a temporary `paused_until` (mode stays
    // 'enabled'). Delete those stale rows so the conversation falls back to the
    // audience default (bot active again) instead of being stuck off forever.
    try {
      this.db
        .prepare(
          `DELETE FROM chatbot_conversation_state
           WHERE mode = 'disabled_by_operator' AND reason = 'manual_operator_reply'`,
        )
        .run();
    } catch {
      // Table not present yet on a brand-new DB — ignore.
    }

    // Add index on providerMessageId for fast undo lookups
    this.db.exec(`
      CREATE INDEX IF NOT EXISTS idx_msg_provider_id
        ON messages(providerMessageId) WHERE providerMessageId != '';
      CREATE UNIQUE INDEX IF NOT EXISTS idx_msg_account_client
        ON messages(accountId, clientMessageId) WHERE clientMessageId != '';
    `);
  }

  // ---------------------------------------------------------------------------
  // Conversation helpers
  // ---------------------------------------------------------------------------

  /** Find or create conversation by (accountId, threadId). Returns conversation id. */
  findOrCreateConversation(
    accountId: string,
    threadId: string,
    threadType: 'user' | 'group',
    displayName: string,
    avatarUrl: string,
    createdAt?: string,
  ): string {
    const existing = this.db
      .prepare('SELECT id FROM conversations WHERE accountId = ? AND threadId = ?')
      .get(accountId, threadId) as { id: string } | undefined;

    if (existing) {
      // Only refresh display info when the incoming value is non-empty. Outbound
      // messages (chatbot/operator replies) carry empty senderName/avatar, so a
      // blind UPDATE would wipe the name/avatar that an inbound message set.
      this.db
        .prepare(
          `UPDATE conversations
           SET displayName = CASE WHEN ? != '' THEN ? ELSE displayName END,
               avatarUrl   = CASE WHEN ? != '' THEN ? ELSE avatarUrl END,
               updatedAt = ?
           WHERE id = ?`,
        )
        .run(
          displayName || '',
          displayName || '',
          avatarUrl || '',
          avatarUrl || '',
          new Date().toISOString(),
          existing.id,
        );
      return existing.id;
    }

    const id = randomUUID();
    const now = createdAt || new Date().toISOString();
    this.db
      .prepare(
        `INSERT INTO conversations
         (id, accountId, threadId, threadType, displayName, avatarUrl,
          lastMessagePreview, lastMessageAt, unreadCount, tagsJson, notes,
          customAttributesJson, archived, assignedTo, followUpAt, managedGroup,
          cloudConversationId, createdAt, updatedAt)
         VALUES (?, ?, ?, ?, ?, ?, '', ?, 0, '[]', '', '{}', 0, '', '', 0, '', ?, ?)`,
      )
      .run(id, accountId, threadId, threadType, displayName || '', avatarUrl || '', now, now, now);
    this._incrementConversationMetric(dateKey(now), accountId, 'newConversations');
    this._addTimelineEvent(id, 'created', 'Conversation created', {}, now);
    return id;
  }

  getConversation(conversationId: string): LocalConversation | undefined {
    const row = this.db
      .prepare('SELECT * FROM conversations WHERE id = ?')
      .get(conversationId) as any;
    return row ? this._mapConversation(row) : undefined;
  }

  getConversationByThread(accountId: string, threadId: string): LocalConversation | undefined {
    const row = this.db
      .prepare('SELECT * FROM conversations WHERE accountId = ? AND threadId = ?')
      .get(accountId, threadId) as any;
    return row ? this._mapConversation(row) : undefined;
  }

  private _mapConversation(row: any): LocalConversation {
    return {
      id: row.id,
      accountId: row.accountId,
      threadId: row.threadId,
      threadType: row.threadType,
      displayName: row.displayName,
      avatarUrl: row.avatarUrl,
      lastMessagePreview: row.lastMessagePreview,
      lastMessageAt: row.lastMessageAt,
      unreadCount: row.unreadCount,
      tags: parseJsonStringList(row.tagsJson),
      notes: row.notes || '',
      customAttributes: parseStringMap(row.customAttributesJson),
      archived: row.archived === 1,
      assignedTo: row.assignedTo || '',
      followUpAt: row.followUpAt || '',
      timeline: this._getConversationTimeline(row.id),
      managedGroup: row.managedGroup === 1,
      cloudConversationId: row.cloudConversationId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
  }

  // ---------------------------------------------------------------------------
  // Inbound upsert
  // ---------------------------------------------------------------------------

  /**
   * Upsert an inbound message. Idempotent by (accountId, providerMessageId).
   * Creates conversation if missing. Returns the message id.
   */
  upsertInboundMessage(input: InboundMessageInput): string {
    // Idempotent check
    if (input.providerMessageId) {
      const existing = this.db
        .prepare(
          'SELECT id FROM messages WHERE accountId = ? AND providerMessageId = ?',
        )
        .get(input.accountId, input.providerMessageId) as { id: string } | undefined;
      if (existing) return existing.id;
    }
    if (input.clientMessageId) {
      const existing = this.db
        .prepare(
          'SELECT id FROM messages WHERE accountId = ? AND clientMessageId = ?',
        )
        .get(input.accountId, input.clientMessageId) as
        | { id: string }
        | undefined;
      if (existing) {
        this.updateMessageStatus(
          existing.id,
          'sent',
          input.providerMessageId || undefined,
        );
        return existing.id;
      }
    }

    // Self-sent history (operator typed on their phone) arrives through the same
    // listener as inbound. Persist it as outbound so it renders on the right side.
    const direction = input.direction === 'outbound' ? 'outbound' : 'inbound';

    // Conversation identity must reflect the OTHER party, never the operator.
    // - Group: always the group name.
    // - 1:1 inbound: the sender (customer).
    // - 1:1 outbound (self): leave blank so we don't name the thread after the
    //   operator; the read-time fallback fills it from the latest inbound sender.
    const displayName = input.threadType === 'group'
      ? (input.groupName || '')
      : (direction === 'outbound' ? '' : (input.senderName || ''));
    const conversationAvatar =
      input.threadType === 'group' || direction === 'inbound'
        ? (input.avatarUrl || '')
        : '';

    const conversationId = this.findOrCreateConversation(
      input.accountId,
      input.threadId,
      input.threadType,
      displayName,
      conversationAvatar,
      input.timestamp || new Date().toISOString(),
    );

    const id = randomUUID();
    const now = new Date().toISOString();

    this.db
      .prepare(
        `INSERT INTO messages
         (id, conversationId, accountId, threadId, threadType, direction,
          senderId, senderName, senderAvatarUrl, content, messageType, providerMessageId,
          clientMessageId, zaloMsgId, status, errorText, quoteJson, mentionsJson,
          stylesJson, metadataJson, recalledContent, isDeleted, receivedAt, sentAt,
          createdAt, updatedAt)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '', 'delivered', '',
                 ?, ?, ?, ?, '', 0, ?, '', ?, ?)`,
      )
      .run(
        id,
        conversationId,
        input.accountId,
        input.threadId,
        input.threadType,
        direction,
        input.senderId,
        input.senderName,
        input.senderAvatarUrl || input.avatarUrl || '',
        input.content,
        input.messageType || 'text',
        input.providerMessageId || '',
        input.clientMessageId || '',
        JSON.stringify(input.quote || {}),
        JSON.stringify(input.mentions || []),
        JSON.stringify(input.styles || []),
        JSON.stringify(input.metadata || {}),
        input.timestamp || now,
        now,
        now,
      );

    // Insert attachments
    if (input.attachments && input.attachments.length > 0) {
      this._insertAttachments(id, input.attachments);
    }

    const preview = buildMessagePreview(input);
    this.db
      .prepare(
        `UPDATE conversations
         SET lastMessagePreview = ?, lastMessageAt = ?,
             unreadCount = unreadCount + ?, updatedAt = ?
         WHERE id = ?`,
      )
      .run(JSON.stringify({
        direction,
        messageType: input.messageType || 'text',
        content: preview,
      }), input.timestamp || now, direction === 'inbound' ? 1 : 0, now, conversationId);
    this._incrementConversationMetric(
      dateKey(input.timestamp || now),
      input.accountId,
      direction === 'inbound' ? 'inboundMessages' : 'outboundMessages',
    );

    this.enqueueSyncAction('sync_message', { messageId: id });
    this.enqueueSyncAction('sync_conversation', { conversationId });
    if (direction === 'inbound') {
      this._applyAutomationRules(conversationId, input);
    }
    this.db
      .prepare(
        `UPDATE history_state SET
           oldestTimestamp = CASE
             WHEN oldestTimestamp = '' OR oldestTimestamp > ? THEN ?
             ELSE oldestTimestamp
           END,
           loading = 0,
           lastError = '',
           updatedAt = ?
         WHERE accountId = ? AND threadId = ?`,
      )
      .run(
        input.timestamp || now,
        input.timestamp || now,
        now,
        input.accountId,
        input.threadId,
      );

    return id;
  }

  upsertInboundMessages(inputs: InboundMessageInput[]): string[] {
    const insertBatch = this.db.transaction(
      (items: InboundMessageInput[]) =>
        items.map((item) => this.upsertInboundMessage(item)),
    );
    return insertBatch(inputs);
  }

  // ---------------------------------------------------------------------------
  // Outbound message
  // ---------------------------------------------------------------------------

  /**
   * Insert a queued outbound message. Returns the message id.
   */
  insertOutboundMessage(input: OutboundMessageInput): string {
    const conversationId = this.findOrCreateConversation(
      input.accountId,
      input.threadId,
      input.threadType,
      '',
      '',
    );

    if (input.clientMessageId) {
      const existing = this.db
        .prepare('SELECT id FROM messages WHERE accountId = ? AND clientMessageId = ?')
        .get(input.accountId, input.clientMessageId) as { id: string } | undefined;
      if (existing) {
        return existing.id;
      }
    }

    const id = randomUUID();
    const now = new Date().toISOString();

    this.db
      .prepare(
        `INSERT INTO messages
         (id, conversationId, accountId, threadId, threadType, direction,
          senderId, senderName, senderAvatarUrl, content, messageType, providerMessageId,
          clientMessageId, zaloMsgId, status, errorText, quoteJson, mentionsJson,
          stylesJson, metadataJson, recalledContent, isDeleted, receivedAt, sentAt,
          createdAt, updatedAt)
         VALUES (?, ?, ?, ?, ?, 'outbound', '', '', '', ?, ?, '', ?, '', 'queued', '',
                 ?, ?, ?, ?, '', 0, '', ?, ?, ?)`,
      )
      .run(
        id,
        conversationId,
        input.accountId,
        input.threadId,
        input.threadType,
        input.content,
        input.messageType || 'text',
        input.clientMessageId || '',
        JSON.stringify(input.quote || {}),
        JSON.stringify(input.mentions || []),
        JSON.stringify(input.styles || []),
        JSON.stringify(input.metadata || {}),
        now,
        now,
        now,
      );

    if (input.attachments && input.attachments.length > 0) {
      this._insertAttachments(id, input.attachments);
    }

    const preview = buildMessagePreview(input);
    this.db
      .prepare(
        `UPDATE conversations
         SET lastMessagePreview = ?, lastMessageAt = ?, updatedAt = ?, unreadCount = 0
         WHERE id = ?`,
      )
      .run(JSON.stringify({
        direction: 'outbound',
        messageType: input.messageType || 'text',
        content: preview,
      }), now, now, conversationId);
    this._incrementConversationMetric(
      dateKey(now),
      input.accountId,
      'outboundMessages',
    );

    this.enqueueSyncAction('sync_message', { messageId: id });
    this.enqueueSyncAction('sync_conversation', { conversationId });

    return id;
  }

  /**
   * Update outbound message status after send attempt.
   */
  updateMessageStatus(
    messageId: string,
    status: string,
    providerMessageId?: string,
    errorText = '',
    clientMessageId?: string,
  ): void {
    const now = new Date().toISOString();
    if (providerMessageId && clientMessageId) {
      this.db
        .prepare(
          `UPDATE messages SET status = ?, providerMessageId = ?,
           clientMessageId = ?, errorText = ?, sentAt = ?, updatedAt = ?
           WHERE id = ?`,
        )
        .run(
          status,
          providerMessageId,
          clientMessageId,
          errorText,
          now,
          now,
          messageId,
        );
    } else if (providerMessageId) {
      this.db
        .prepare(
          `UPDATE messages SET status = ?, providerMessageId = ?, errorText = ?,
           sentAt = ?, updatedAt = ? WHERE id = ?`,
        )
        .run(status, providerMessageId, errorText, now, now, messageId);
    } else if (clientMessageId) {
      this.db
        .prepare(
          `UPDATE messages SET status = ?, clientMessageId = ?,
           errorText = ?, updatedAt = ? WHERE id = ?`,
        )
        .run(status, clientMessageId, errorText, now, messageId);
    } else {
      this.db
        .prepare('UPDATE messages SET status = ?, errorText = ?, updatedAt = ? WHERE id = ?')
        .run(status, errorText, now, messageId);
    }
    this.enqueueSyncAction('sync_message', { messageId });
  }

  /**
   * Update message status by providerMessageId.
   * Useful for seen/delivered receipts from Zalo.
   */
  updateMessageStatusByProviderId(providerMessageId: string, status: string): void {
    const now = new Date().toISOString();
    const result = this.db
      .prepare(
        `UPDATE messages SET status = ?, updatedAt = ?
         WHERE providerMessageId = ? AND providerMessageId != '' RETURNING id`,
      )
      .get(status, now, providerMessageId) as { id: string } | undefined;
    if (result) {
      this.enqueueSyncAction('sync_message', { messageId: result.id });
    }
  }

  reconcileOutboundMessage(input: {
    accountId: string;
    clientMessageId: string;
    providerMessageId?: string;
    status?: string;
  }): string | undefined {
    if (!input.clientMessageId) return undefined;
    const row = this.db
      .prepare(
        `SELECT id FROM messages
         WHERE accountId = ? AND clientMessageId = ? AND direction = 'outbound'`,
      )
      .get(input.accountId, input.clientMessageId) as { id: string } | undefined;
    if (!row) return undefined;
    this.updateMessageStatus(
      row.id,
      input.status || 'sent',
      input.providerMessageId,
      '',
      input.clientMessageId,
    );
    return row.id;
  }

  // ---------------------------------------------------------------------------
  // Paging
  // ---------------------------------------------------------------------------

  /**
   * Fetch messages for a conversation with cursor-based paging.
   * Returns messages in chronological order (oldest first).
   */
  getMessages(
    conversationId: string,
    options: { before?: string; after?: string; limit?: number } = {},
  ): MessagePage {
    const limit = Math.min(options.limit || 30, 200);
    let sql: string;
    const params: any[] = [conversationId];

    if (options.before) {
      sql = `SELECT * FROM messages WHERE conversationId = ? AND createdAt < ?
             ORDER BY createdAt DESC LIMIT ?`;
      params.push(options.before, limit);
    } else if (options.after) {
      sql = `SELECT * FROM messages WHERE conversationId = ? AND createdAt > ?
             ORDER BY createdAt ASC LIMIT ?`;
      params.push(options.after, limit);
    } else {
      // Latest messages (descending so we get the tail, then reverse)
      sql = `SELECT * FROM messages WHERE conversationId = ?
             ORDER BY createdAt DESC LIMIT ?`;
      params.push(limit);
    }

    const rows = this.db.prepare(sql).all(...params) as any[];

    // Ensure chronological order
    rows.sort(
      (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
    );

    const messages: LocalMessage[] = rows.map((r) => this._mapMessage(r));

    // Load attachments for all messages
    const attachments = new Map<string, LocalAttachment[]>();
    if (messages.length > 0) {
      const ids = messages.map((m) => m.id);
      const placeholders = ids.map(() => '?').join(',');
      const attachRows = this.db
        .prepare(
          `SELECT * FROM attachments WHERE messageId IN (${placeholders})`,
        )
        .all(...ids) as any[];
      for (const ar of attachRows) {
        const mapped = this._mapAttachment(ar);
        const list = attachments.get(mapped.messageId) || [];
        list.push(mapped);
        attachments.set(mapped.messageId, list);
      }
    }

    return { messages, attachments };
  }

  /**
   * Get messages by cloud conversation ID or by (accountId, threadId) fallback.
   */
  getMessagesByCloudId(
    cloudConversationId: string,
    options: { before?: string; after?: string; limit?: number } = {},
  ): MessagePage | null {
    const conv = this.db
      .prepare('SELECT id FROM conversations WHERE cloudConversationId = ?')
      .get(cloudConversationId) as { id: string } | undefined;
    if (!conv) return null;
    return this.getMessages(conv.id, options);
  }

  getMessagesByThread(
    accountId: string,
    threadId: string,
    options: { before?: string; after?: string; limit?: number } = {},
  ): MessagePage | null {
    const conv = this.db
      .prepare('SELECT id FROM conversations WHERE accountId = ? AND threadId = ?')
      .get(accountId, threadId) as { id: string } | undefined;
    if (!conv) return null;
    return this.getMessages(conv.id, options);
  }

  getMessage(messageId: string): LocalMessage | undefined {
    const row = this.db
      .prepare('SELECT * FROM messages WHERE id = ?')
      .get(messageId) as any;
    return row ? this._mapMessage(row) : undefined;
  }

  searchMessages(
    query: string,
    options: {
      accountId?: string;
      threadId?: string;
      limit?: number;
    } = {},
  ): LocalMessage[] {
    const trimmed = query.trim();
    if (!trimmed) return [];
    const where = ['content LIKE ?', 'isDeleted = 0'];
    const params: unknown[] = [`%${trimmed}%`];
    if (options.accountId) {
      where.push('accountId = ?');
      params.push(options.accountId);
    }
    if (options.threadId) {
      where.push('threadId = ?');
      params.push(options.threadId);
    }
    const limit = Math.min(options.limit || 50, 200);
    const rows = this.db
      .prepare(
        `SELECT * FROM messages WHERE ${where.join(' AND ')}
         ORDER BY createdAt DESC LIMIT ?`,
      )
      .all(...params, limit) as any[];
    return rows.map((row) => this._mapMessage(row));
  }

  getMessagesAround(
    conversationId: string,
    messageId: string,
    radius = 15,
  ): MessagePage {
    const center = this.db
      .prepare(
        'SELECT createdAt FROM messages WHERE id = ? AND conversationId = ?',
      )
      .get(messageId, conversationId) as { createdAt: string } | undefined;
    if (!center) return { messages: [], attachments: new Map() };

    const before = this.db
      .prepare(
        `SELECT * FROM messages
         WHERE conversationId = ? AND createdAt < ?
         ORDER BY createdAt DESC LIMIT ?`,
      )
      .all(conversationId, center.createdAt, radius) as any[];
    const current = this.db
      .prepare('SELECT * FROM messages WHERE id = ?')
      .get(messageId) as any;
    const after = this.db
      .prepare(
        `SELECT * FROM messages
         WHERE conversationId = ? AND createdAt > ?
         ORDER BY createdAt ASC LIMIT ?`,
      )
      .all(conversationId, center.createdAt, radius) as any[];
    const messages = [
      ...before.reverse(),
      current,
      ...after,
    ].filter(Boolean).map((row) => this._mapMessage(row));
    return this._loadAttachments(messages);
  }

  upsertReceipt(input: {
    accountId: string;
    providerMessageId: string;
    userId: string;
    status: 'delivered' | 'seen';
    timestamp: string;
  }): boolean {
    const message = this.db
      .prepare(
        `SELECT id FROM messages
         WHERE accountId = ? AND providerMessageId = ?`,
      )
      .get(input.accountId, input.providerMessageId) as { id: string } | undefined;
    if (!message) return false;
    this.db
      .prepare(
        `INSERT INTO message_receipts (messageId, userId, status, timestamp)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(messageId, userId, status)
         DO UPDATE SET timestamp = excluded.timestamp`,
      )
      .run(message.id, input.userId, input.status, input.timestamp);
    this.updateMessageStatusByProviderId(
      input.providerMessageId,
      input.status,
    );
    return true;
  }

  getReceipts(messageId: string): MessageReceipt[] {
    return this.db
      .prepare(
        `SELECT messageId, userId, status, timestamp
         FROM message_receipts WHERE messageId = ?
         ORDER BY timestamp ASC`,
      )
      .all(messageId) as MessageReceipt[];
  }

  upsertReaction(input: {
    accountId: string;
    providerMessageId: string;
    userId: string;
    reaction: string;
    timestamp: string;
  }): boolean {
    const message = this.db
      .prepare(
        `SELECT id FROM messages
         WHERE accountId = ? AND providerMessageId = ?`,
      )
      .get(input.accountId, input.providerMessageId) as { id: string } | undefined;
    if (!message) return false;
    if (!input.reaction || input.reaction === 'none') {
      this.db
        .prepare(
          'DELETE FROM message_reactions WHERE messageId = ? AND userId = ?',
        )
        .run(message.id, input.userId);
      return true;
    }
    this.db
      .prepare(
        `INSERT INTO message_reactions (messageId, userId, reaction, timestamp)
         VALUES (?, ?, ?, ?)`,
      )
      .run(message.id, input.userId, input.reaction, input.timestamp);
    return true;
  }

  getReactions(messageId: string): MessageReaction[] {
    return this.db
      .prepare(
        `SELECT messageId, userId, reaction, timestamp
         FROM message_reactions WHERE messageId = ?
         ORDER BY timestamp ASC`,
      )
      .all(messageId) as MessageReaction[];
  }

  saveDraft(accountId: string, threadId: string, content: string): void {
    this.db
      .prepare(
        `INSERT INTO chat_drafts (accountId, threadId, content, updatedAt)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(accountId, threadId)
         DO UPDATE SET content = excluded.content, updatedAt = excluded.updatedAt`,
      )
      .run(accountId, threadId, content, new Date().toISOString());
  }

  getDraft(accountId: string, threadId: string): string {
    const row = this.db
      .prepare(
        'SELECT content FROM chat_drafts WHERE accountId = ? AND threadId = ?',
      )
      .get(accountId, threadId) as { content: string } | undefined;
    return row?.content || '';
  }

  // ---------------------------------------------------------------------------
  // Per-account chat settings (e.g. AI auto-reply on/off)
  // ---------------------------------------------------------------------------

  /** Whether the chatbot may auto-reply for this account. Defaults true. */
  isAccountAiAutoReplyEnabled(accountId: string): boolean {
    const row = this.db
      .prepare('SELECT aiAutoReply FROM account_chat_settings WHERE accountId = ?')
      .get(accountId) as { aiAutoReply: number } | undefined;
    return row ? row.aiAutoReply === 1 : true;
  }

  /** Map of accountId → aiAutoReply for every account with an explicit setting. */
  getAccountChatSettings(): Record<string, { aiAutoReply: boolean }> {
    const rows = this.db
      .prepare('SELECT accountId, aiAutoReply FROM account_chat_settings')
      .all() as Array<{ accountId: string; aiAutoReply: number }>;
    const out: Record<string, { aiAutoReply: boolean }> = {};
    for (const r of rows) out[r.accountId] = { aiAutoReply: r.aiAutoReply === 1 };
    return out;
  }

  setAccountAiAutoReply(accountId: string, enabled: boolean): void {
    this.db
      .prepare(
        `INSERT INTO account_chat_settings (accountId, aiAutoReply, updatedAt)
         VALUES (?, ?, ?)
         ON CONFLICT(accountId)
         DO UPDATE SET aiAutoReply = excluded.aiAutoReply, updatedAt = excluded.updatedAt`,
      )
      .run(accountId, enabled ? 1 : 0, new Date().toISOString());
  }

  // ── Global app settings (kv) ──
  private getSetting(key: string): string | undefined {
    const row = this.db
      .prepare('SELECT value FROM app_settings WHERE key = ?')
      .get(key) as { value: string } | undefined;
    return row?.value;
  }

  private setSetting(key: string, value: string): void {
    this.db
      .prepare(
        `INSERT INTO app_settings (key, value) VALUES (?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value`,
      )
      .run(key, value);
  }

  static readonly OPERATOR_PAUSE_DEFAULT_MIN = 10;
  static readonly OPERATOR_PAUSE_MIN = 5;
  static readonly OPERATOR_PAUSE_MAX = 120;

  /** Minutes the bot stays paused after a human reply (clamped 5–120, default 10). */
  getOperatorPauseCooldownMinutes(): number {
    const raw = Number(this.getSetting('operatorPauseCooldownMinutes'));
    if (!Number.isFinite(raw)) return LocalChatStore.OPERATOR_PAUSE_DEFAULT_MIN;
    return Math.min(
      LocalChatStore.OPERATOR_PAUSE_MAX,
      Math.max(LocalChatStore.OPERATOR_PAUSE_MIN, Math.round(raw)),
    );
  }

  setOperatorPauseCooldownMinutes(minutes: number): number {
    const clamped = Math.min(
      LocalChatStore.OPERATOR_PAUSE_MAX,
      Math.max(LocalChatStore.OPERATOR_PAUSE_MIN, Math.round(Number(minutes) || 0)),
    );
    this.setSetting('operatorPauseCooldownMinutes', String(clamped));
    return clamped;
  }

  setHistoryState(
    accountId: string,
    threadId: string,
    state: HistoryState,
  ): void {
    this.db
      .prepare(
        `INSERT INTO history_state
         (accountId, threadId, oldestTimestamp, hasMore, loading, lastError, updatedAt)
         VALUES (?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(accountId, threadId) DO UPDATE SET
           oldestTimestamp = excluded.oldestTimestamp,
           hasMore = excluded.hasMore,
           loading = excluded.loading,
           lastError = excluded.lastError,
           updatedAt = excluded.updatedAt`,
      )
      .run(
        accountId,
        threadId,
        state.oldestTimestamp,
        state.hasMore ? 1 : 0,
        state.loading ? 1 : 0,
        state.lastError,
        new Date().toISOString(),
      );
  }

  appendZaloEvent(input: {
    type: string;
    accountId: string;
    threadId: string;
    data?: Record<string, unknown>;
    timestamp: string;
  }): string {
    const id = randomUUID();
    this.db
      .prepare(
        `INSERT INTO zalo_event_log
         (id, type, accountId, threadId, dataJson, timestamp)
         VALUES (?, ?, ?, ?, ?, ?)`,
      )
      .run(
        id,
        input.type,
        input.accountId,
        input.threadId,
        JSON.stringify(input.data || {}),
        input.timestamp,
      );
    return id;
  }

  getHistoryState(accountId: string, threadId: string): HistoryState {
    const row = this.db
      .prepare(
        `SELECT oldestTimestamp, hasMore, loading, lastError
         FROM history_state WHERE accountId = ? AND threadId = ?`,
      )
      .get(accountId, threadId) as any;
    return {
      oldestTimestamp: row?.oldestTimestamp || '',
      hasMore: row ? row.hasMore === 1 : true,
      loading: row ? row.loading === 1 : false,
      lastError: row?.lastError || '',
    };
  }

  // ---------------------------------------------------------------------------
  // Recall / delete
  // ---------------------------------------------------------------------------

  markMessageDeleted(messageId: string): boolean {
    const now = new Date().toISOString();
    const result = this.db
      .prepare(
        `UPDATE messages SET isDeleted = 1, recalledContent = content,
         content = ?, updatedAt = ? WHERE id = ?`,
      )
      .run('[Tin nhắn đã thu hồi]', now, messageId);
    if (result.changes > 0) {
      this.enqueueSyncAction('sync_message', { messageId });
    }
    return result.changes > 0;
  }

  deleteMessage(messageId: string): boolean {
    // Delete attachments first
    this.db.prepare('DELETE FROM attachments WHERE messageId = ?').run(messageId);
    // Delete message receipt if any
    this.db.prepare('DELETE FROM message_receipts WHERE messageId = ?').run(messageId);
    // Delete message
    const result = this.db.prepare('DELETE FROM messages WHERE id = ?').run(messageId);
    return result.changes > 0;
  }

  /**
   * Soft-delete a message by its Zalo provider message ID (for undo events).
   * Returns true if any row was updated.
   */
  markMessageDeletedByProviderMsgId(providerMessageId: string): boolean {
    const now = new Date().toISOString();
    const result = this.db
      .prepare(
        `UPDATE messages SET isDeleted = 1, recalledContent = content,
         content = ?, updatedAt = ?
         WHERE providerMessageId = ? AND providerMessageId != '' RETURNING id`,
      )
      .get('[Tin nhắn đã thu hồi]', now, providerMessageId) as { id: string } | undefined;
    if (result) {
      this.enqueueSyncAction('sync_message', { messageId: result.id });
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Conversation listing (paginated)
  // ---------------------------------------------------------------------------

  /**
   * List conversations with optional filtering and pagination.
   * Returns conversations ordered by lastMessageAt descending (most recent first).
   */
  listConversations(options: {
    accountId?: string;
    search?: string;
    limit?: number;
    offset?: number;
  } = {}): { conversations: LocalConversation[]; total: number } {
    // Ceiling raised to 2000 so the response-log name lookup can resolve more
    // than the 200 most-recent threads. Paginated callers default to 50.
    const limit = Math.min(options.limit || 50, 2000);
    const offset = options.offset || 0;

    let whereClause = '1=1';
    const params: any[] = [];

    if (options.accountId) {
      whereClause += ' AND accountId = ?';
      params.push(options.accountId);
    }

    if (options.search) {
      whereClause +=
        ' AND (displayName LIKE ? OR threadId LIKE ? OR tagsJson LIKE ? OR notes LIKE ? OR customAttributesJson LIKE ?)';
      const searchPattern = `%${options.search}%`;
      params.push(
        searchPattern,
        searchPattern,
        searchPattern,
        searchPattern,
        searchPattern,
      );
    }

    const totalRow = this.db
      .prepare(`SELECT COUNT(*) as c FROM conversations WHERE ${whereClause}`)
      .get(...params) as { c: number };
    const total = totalRow.c;

    const rows = this.db
      .prepare(
        `SELECT * FROM conversations WHERE ${whereClause}
         ORDER BY lastMessageAt DESC LIMIT ? OFFSET ?`,
      )
      .all(...params, limit, offset) as any[];

    return {
      conversations: rows.map((r) => {
        const conv = this._mapConversation(r);
        // Existing 1:1 conversations created/overwritten by an outbound message
        // may have an empty name/avatar. Fall back to the most recent inbound
        // sender so the inbox, header and message avatars render correctly.
        if (conv.threadType !== 'group' &&
            (!conv.displayName || !conv.avatarUrl)) {
          const sender = this.db
            .prepare(
              `SELECT senderName, senderAvatarUrl FROM messages
               WHERE conversationId = ? AND direction = 'inbound' AND senderName != ''
               ORDER BY createdAt DESC LIMIT 1`,
            )
            .get(conv.id) as
            | { senderName?: string; senderAvatarUrl?: string }
            | undefined;
          if (sender) {
            if (!conv.displayName) conv.displayName = sender.senderName || '';
            if (!conv.avatarUrl) conv.avatarUrl = sender.senderAvatarUrl || '';
          }
        }
        return conv;
      }),
      total,
    };
  }

  updateConversationMetadata(
    conversationId: string,
    input: ConversationMetadataInput,
  ): LocalConversation | undefined {
    const existing = this._resolveConversationRow(conversationId);
    if (!existing) return undefined;

    const currentTags = parseJsonStringList(existing.tagsJson);
    const currentAttributes = parseStringMap(existing.customAttributesJson);
    const nextTags = input.tags === undefined
      ? currentTags
      : parseJsonStringList(input.tags);
    const nextNotes = input.notes === undefined
      ? (existing.notes || '')
      : String(input.notes || '').trim();
    const nextAttributes = input.customAttributes === undefined
      ? currentAttributes
      : parseStringMap(input.customAttributes);
    const nextArchived = input.archived === undefined
      ? existing.archived === 1
      : input.archived === true;
    const nextAssignedTo = input.assignedTo === undefined
      ? (existing.assignedTo || '')
      : String(input.assignedTo || '').trim();
    const nextFollowUpAt = input.followUpAt === undefined
      ? (existing.followUpAt || '')
      : String(input.followUpAt || '').trim();
    const now = new Date().toISOString();

    this.db
      .prepare(
        `UPDATE conversations
         SET tagsJson = ?, notes = ?, customAttributesJson = ?,
             archived = ?, assignedTo = ?, followUpAt = ?, updatedAt = ?
         WHERE id = ?`,
      )
      .run(
        JSON.stringify(nextTags),
        nextNotes,
        JSON.stringify(nextAttributes),
        nextArchived ? 1 : 0,
        nextAssignedTo,
        nextFollowUpAt,
        now,
        existing.id,
      );

    if (JSON.stringify(nextTags) !== JSON.stringify(currentTags)) {
      this._addTimelineEvent(
        existing.id,
        'labels.updated',
        `Labels updated: ${nextTags.join(', ') || 'none'}`,
        { tags: nextTags },
        now,
      );
    }
    if (nextNotes !== (existing.notes || '')) {
      this._addTimelineEvent(existing.id, 'notes.updated', 'Notes updated', {}, now);
    }
    if (JSON.stringify(nextAttributes) !== JSON.stringify(currentAttributes)) {
      this._addTimelineEvent(
        existing.id,
        'custom_attributes.updated',
        'Custom attributes updated',
        { customAttributes: nextAttributes },
        now,
      );
    }
    if (
      nextArchived !== (existing.archived === 1) ||
      nextAssignedTo !== (existing.assignedTo || '') ||
      nextFollowUpAt !== (existing.followUpAt || '')
    ) {
      this._addTimelineEvent(
        existing.id,
        'workflow.updated',
        'Workflow state updated',
        {
          archived: nextArchived,
          assignedTo: nextAssignedTo,
          followUpAt: nextFollowUpAt,
        },
        now,
      );
    }

    this.enqueueSyncAction('sync_conversation', { conversationId: existing.id });
    return this.getConversation(existing.id);
  }

  /**
   * Mark a conversation as read (reset unreadCount to 0).
   */
  markConversationRead(conversationId: string): boolean {
    const now = new Date().toISOString();
    const result = this.db
      .prepare(
        'UPDATE conversations SET unreadCount = 0, updatedAt = ? WHERE id = ?',
      )
      .run(now, conversationId);
    if (result.changes > 0) {
      this.enqueueSyncAction('sync_conversation', { conversationId });
    }
    return result.changes > 0;
  }

  getConversationRollup(options: {
    from?: string;
    to?: string;
    accountId?: string;
  } = {}): Array<Record<string, unknown>> {
    let where = '1=1';
    const params: unknown[] = [];
    if (options.from) {
      where += ' AND date >= ?';
      params.push(options.from);
    }
    if (options.to) {
      where += ' AND date <= ?';
      params.push(options.to);
    }
    if (options.accountId) {
      where += ' AND accountId = ?';
      params.push(options.accountId);
    }
    return this.db
      .prepare(
        `SELECT date, accountId, inboundMessages, outboundMessages,
                newConversations
         FROM conversation_metrics_daily
         WHERE ${where}
         ORDER BY date ASC`,
      )
      .all(...params) as Array<Record<string, unknown>>;
  }

  listAutomationRules(): LocalAutomationRule[] {
    const rows = this.db
      .prepare('SELECT * FROM automation_rules ORDER BY createdAt DESC')
      .all() as any[];
    return rows.map((row) => ({
      id: row.id,
      name: row.name,
      event: row.event,
      conditionField: row.conditionField,
      conditionOperator: row.conditionOperator,
      conditionValue: row.conditionValue,
      actions: parseJsonStringList(row.actionsJson),
      enabled: row.enabled === 1,
      createdAt: row.createdAt,
    }));
  }

  replaceAutomationRules(rules: LocalAutomationRule[]): LocalAutomationRule[] {
    const now = new Date().toISOString();
    const tx = this.db.transaction((items: LocalAutomationRule[]) => {
      this.db.prepare('DELETE FROM automation_rules').run();
      const insert = this.db.prepare(
        `INSERT INTO automation_rules
         (id, name, event, conditionField, conditionOperator, conditionValue,
          actionsJson, enabled, createdAt, updatedAt)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      );
      for (const rule of items) {
        insert.run(
          rule.id,
          rule.name,
          rule.event,
          rule.conditionField,
          rule.conditionOperator,
          rule.conditionValue,
          JSON.stringify(rule.actions || []),
          rule.enabled ? 1 : 0,
          rule.createdAt || now,
          now,
        );
      }
    });
    tx(rules);
    return this.listAutomationRules();
  }

  // ---------------------------------------------------------------------------
  // Sync state helpers
  // ---------------------------------------------------------------------------

  getSyncState(key: string): string | undefined {
    const row = this.db
      .prepare('SELECT value FROM sync_state WHERE key = ?')
      .get(key) as { value: string } | undefined;
    return row?.value;
  }

  setSyncState(key: string, value: string): void {
    const now = new Date().toISOString();
    this.db
      .prepare(
        `INSERT INTO sync_state (key, value, updatedAt)
         VALUES (?, ?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value, updatedAt = excluded.updatedAt`,
      )
      .run(key, value, now);
  }

  // ---------------------------------------------------------------------------
  // Background Sync Queue
  // ---------------------------------------------------------------------------

  enqueueSyncAction(action: string, payload: any): void {
    const id = randomUUID();
    const now = new Date().toISOString();
    this.db
      .prepare(
        `INSERT INTO sync_queue (id, action, payloadJson, status, retryCount, nextRetryAt, createdAt)
         VALUES (?, ?, ?, 'pending', 0, ?, ?)`
      )
      .run(id, action, JSON.stringify(payload), now, now);
  }

  getPendingSyncActions(limit = 10): any[] {
    const now = new Date().toISOString();
    return this.db
      .prepare(
        `SELECT * FROM sync_queue
         WHERE status = 'pending' AND nextRetryAt <= ?
         ORDER BY createdAt ASC LIMIT ?`
      )
      .all(now, limit) as any[];
  }

  markSyncActionComplete(id: string): void {
    this.db
      .prepare(`UPDATE sync_queue SET status = 'completed' WHERE id = ?`)
      .run(id);
    // Optionally delete it:
    // this.db.prepare(`DELETE FROM sync_queue WHERE id = ?`).run(id);
  }

  markSyncActionFailed(id: string, nextRetryAt: string): void {
    this.db
      .prepare(
        `UPDATE sync_queue
         SET retryCount = retryCount + 1, nextRetryAt = ?
         WHERE id = ?`
      )
      .run(nextRetryAt, id);
  }

  listPendingAttachments(limit = 10): LocalAttachment[] {
    const rows = this.db
      .prepare(
        `SELECT * FROM attachments
         WHERE status IN ('pending', 'failed')
           AND url LIKE 'http%'
           AND localPath = ''
         ORDER BY createdAt ASC LIMIT ?`,
      )
      .all(limit) as any[];
    return rows.map((row) => this._mapAttachment(row));
  }

  updateAttachmentDownload(
    attachmentId: string,
    update: {
      status: 'pending' | 'downloading' | 'ready' | 'failed';
      localPath?: string;
      checksum?: string;
      errorText?: string;
      downloadedAt?: string;
      sizeBytes?: number;
    },
  ): void {
    this.db
      .prepare(
        `UPDATE attachments SET
           status = ?,
           localPath = COALESCE(?, localPath),
           checksum = COALESCE(?, checksum),
           errorText = ?,
           downloadedAt = COALESCE(?, downloadedAt),
           sizeBytes = COALESCE(?, sizeBytes)
         WHERE id = ?`,
      )
      .run(
        update.status,
        update.localPath ?? null,
        update.checksum ?? null,
        update.errorText || '',
        update.downloadedAt ?? null,
        update.sizeBytes ?? null,
        attachmentId,
      );
  }

  // ---------------------------------------------------------------------------
  // Health
  // ---------------------------------------------------------------------------

  getHealth(): {
    ok: boolean;
    messageCount: number;
    conversationCount: number;
  } {
    try {
      const msgCount = (
        this.db.prepare('SELECT COUNT(*) as c FROM messages').get() as any
      ).c;
      const convCount = (
        this.db.prepare('SELECT COUNT(*) as c FROM conversations').get() as any
      ).c;
      return { ok: true, messageCount: msgCount, conversationCount: convCount };
    } catch {
      return { ok: false, messageCount: 0, conversationCount: 0 };
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  close(): void {
    this.db.close();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  private _resolveConversationRow(conversationId: string): any | undefined {
    const direct = this.db
      .prepare('SELECT * FROM conversations WHERE id = ?')
      .get(conversationId) as any | undefined;
    if (direct) return direct;
    return this.db
      .prepare('SELECT * FROM conversations WHERE cloudConversationId = ?')
      .get(conversationId) as any | undefined;
  }

  private _addTimelineEvent(
    conversationId: string,
    eventType: string,
    summary: string,
    metadata: Record<string, unknown>,
    createdAt = new Date().toISOString(),
  ): void {
    this.db
      .prepare(
        `INSERT INTO conversation_timeline
         (id, conversationId, eventType, summary, metadataJson, createdAt)
         VALUES (?, ?, ?, ?, ?, ?)`,
      )
      .run(
        randomUUID(),
        conversationId,
        eventType,
        summary,
        JSON.stringify(metadata),
        createdAt,
      );
  }

  private _getConversationTimeline(
    conversationId: string,
  ): LocalConversationTimelineItem[] {
    const rows = this.db
      .prepare(
        `SELECT * FROM conversation_timeline
         WHERE conversationId = ?
         ORDER BY createdAt DESC
         LIMIT 12`,
      )
      .all(conversationId) as any[];
    return rows.map((row) => ({
      id: row.id,
      eventType: row.eventType,
      summary: row.summary,
      metadata: parseJsonObject(row.metadataJson),
      createdAt: row.createdAt,
    }));
  }

  private _incrementConversationMetric(
    date: string,
    accountId: string,
    column: 'inboundMessages' | 'outboundMessages' | 'newConversations',
  ): void {
    this.db
      .prepare(
        `INSERT INTO conversation_metrics_daily
         (date, accountId, inboundMessages, outboundMessages, newConversations)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(date, accountId) DO UPDATE SET
           inboundMessages = inboundMessages + excluded.inboundMessages,
           outboundMessages = outboundMessages + excluded.outboundMessages,
           newConversations = newConversations + excluded.newConversations`,
      )
      .run(
        date,
        accountId || '',
        column === 'inboundMessages' ? 1 : 0,
        column === 'outboundMessages' ? 1 : 0,
        column === 'newConversations' ? 1 : 0,
      );
  }

  private _applyAutomationRules(
    conversationId: string,
    input: InboundMessageInput,
  ): void {
    const rules = this.listAutomationRules().filter((rule) => rule.enabled);
    if (rules.length === 0) return;
    const text = `${input.content || ''}`.toLowerCase();
    const matchedLabels = new Set<string>();
    const notes: string[] = [];
    for (const rule of rules) {
      const event = rule.event.toLowerCase();
      if (event && !event.includes('tin') && !event.includes('message')) {
        continue;
      }
      const expected = rule.conditionValue.toLowerCase().trim();
      const operator = rule.conditionOperator.toLowerCase();
      const matches = operator.includes('bằng') || operator.includes('equal')
        ? text === expected
        : expected.length === 0 || text.includes(expected);
      if (!matches) continue;

      for (const action of rule.actions) {
        const normalized = action.trim();
        const lower = normalized.toLowerCase();
        if (lower.includes('gắn nhãn:') || lower.includes('add label:')) {
          const label = normalized.split(':').slice(1).join(':').trim();
          if (label) matchedLabels.add(label);
        } else if (lower.includes('ghi chú') || lower.includes('note')) {
          notes.push(`[Automation] ${rule.name}`);
        }
      }
    }
    if (matchedLabels.size === 0 && notes.length === 0) return;

    const conv = this.getConversation(conversationId);
    if (!conv) return;
    const tags = [...new Set([...conv.tags, ...matchedLabels])];
    const nextNotes = notes.length === 0
      ? conv.notes
      : [conv.notes, ...notes].filter(Boolean).join('\n');
    this.updateConversationMetadata(conversationId, {
      tags,
      notes: nextNotes,
      customAttributes: conv.customAttributes,
    });
  }

  private _insertAttachments(
    messageId: string,
    attachments: AttachmentInput[],
  ): void {
    const now = new Date().toISOString();
    const stmt = this.db.prepare(
      `INSERT INTO attachments
       (id, messageId, kind, name, url, localPath, mimeType, sizeBytes,
        metadataJson, status, checksum, errorText, downloadedAt, createdAt)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '', '', '', ?)`,
    );
    for (const a of attachments) {
      const id = randomUUID();
      const url = a.url || '';
      const localPath = a.localPath || '';
      const status = !localPath && /^https?:\/\//i.test(url)
        ? 'pending'
        : 'ready';
      stmt.run(
        id,
        messageId,
        a.kind || '',
        a.name || '',
        url,
        localPath,
        a.mimeType || '',
        a.sizeBytes || 0,
        a.metadata ? JSON.stringify(a.metadata) : '{}',
        status,
        now,
      );
    }
  }

  private _mapMessage(row: any): LocalMessage {
    return {
      id: row.id,
      conversationId: row.conversationId,
      accountId: row.accountId,
      threadId: row.threadId,
      threadType: row.threadType,
      direction: row.direction,
      senderId: row.senderId,
      senderName: row.senderName,
      senderAvatarUrl: row.senderAvatarUrl || '',
      content: row.content,
      messageType: row.messageType,
      providerMessageId: row.providerMessageId,
      clientMessageId: row.clientMessageId || '',
      zaloMsgId: row.zaloMsgId,
      status: row.status,
      errorText: row.errorText || '',
      quoteJson: row.quoteJson || '{}',
      mentionsJson: row.mentionsJson || '[]',
      stylesJson: row.stylesJson || '[]',
      metadataJson: row.metadataJson || '{}',
      recalledContent: row.recalledContent || '',
      isDeleted: row.isDeleted === 1,
      receivedAt: row.receivedAt,
      sentAt: row.sentAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
  }

  private _mapAttachment(row: any): LocalAttachment {
    return {
      id: row.id,
      messageId: row.messageId,
      kind: row.kind,
      name: row.name,
      url: row.url,
      localPath: row.localPath,
      mimeType: row.mimeType,
      sizeBytes: row.sizeBytes,
      metadataJson: row.metadataJson,
      status: row.status || 'ready',
      checksum: row.checksum || '',
      errorText: row.errorText || '',
      downloadedAt: row.downloadedAt || '',
      createdAt: row.createdAt,
    };
  }

  private _loadAttachments(messages: LocalMessage[]): MessagePage {
    const attachments = new Map<string, LocalAttachment[]>();
    if (messages.length === 0) return { messages, attachments };
    const ids = messages.map((message) => message.id);
    const placeholders = ids.map(() => '?').join(',');
    const rows = this.db
      .prepare(
        `SELECT * FROM attachments WHERE messageId IN (${placeholders})`,
      )
      .all(...ids) as any[];
    for (const row of rows) {
      const attachment = this._mapAttachment(row);
      const list = attachments.get(attachment.messageId) || [];
      list.push(attachment);
      attachments.set(attachment.messageId, list);
    }
    return { messages, attachments };
  }
}
