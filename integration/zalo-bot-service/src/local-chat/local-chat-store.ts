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
        messageId TEXT NOT NULL,
        userId TEXT NOT NULL,
        reaction TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        PRIMARY KEY (messageId, userId),
        FOREIGN KEY (messageId) REFERENCES messages(id)
      );

      CREATE TABLE IF NOT EXISTS chat_drafts (
        accountId TEXT NOT NULL,
        threadId TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        updatedAt TEXT NOT NULL,
        PRIMARY KEY (accountId, threadId)
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
      ['attachments', "status TEXT NOT NULL DEFAULT 'ready'"],
      ['attachments', "checksum TEXT NOT NULL DEFAULT ''"],
      ['attachments', "errorText TEXT NOT NULL DEFAULT ''"],
      ['attachments', "downloadedAt TEXT NOT NULL DEFAULT ''"],
    ] as const;
    for (const [table, definition] of additionalColumns) {
      try {
        this.db.exec(`ALTER TABLE ${table} ADD COLUMN ${definition}`);
      } catch {
        // Column already exists.
      }
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
  ): string {
    const existing = this.db
      .prepare('SELECT id FROM conversations WHERE accountId = ? AND threadId = ?')
      .get(accountId, threadId) as { id: string } | undefined;

    if (existing) {
      // Update display info if changed
      this.db
        .prepare(
          `UPDATE conversations SET displayName = ?, avatarUrl = ?, updatedAt = ?
           WHERE id = ?`,
        )
        .run(displayName || '', avatarUrl || '', new Date().toISOString(), existing.id);
      return existing.id;
    }

    const id = randomUUID();
    const now = new Date().toISOString();
    this.db
      .prepare(
        `INSERT INTO conversations
         (id, accountId, threadId, threadType, displayName, avatarUrl,
          lastMessagePreview, lastMessageAt, unreadCount, managedGroup,
          cloudConversationId, createdAt, updatedAt)
         VALUES (?, ?, ?, ?, ?, ?, '', ?, 0, 0, '', ?, ?)`,
      )
      .run(id, accountId, threadId, threadType, displayName || '', avatarUrl || '', now, now, now);
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

    // For group chats, use groupName as display name; for 1:1, use senderName
    const displayName = input.threadType === 'group'
      ? (input.groupName || input.senderName || '')
      : (input.senderName || '');

    const conversationId = this.findOrCreateConversation(
      input.accountId,
      input.threadId,
      input.threadType,
      displayName,
      input.avatarUrl || '',
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
         VALUES (?, ?, ?, ?, ?, 'inbound', ?, ?, ?, ?, ?, ?, ?, '', 'delivered', '',
                 ?, ?, ?, ?, '', 0, ?, '', ?, ?)`,
      )
      .run(
        id,
        conversationId,
        input.accountId,
        input.threadId,
        input.threadType,
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
             unreadCount = unreadCount + 1, updatedAt = ?
         WHERE id = ?`,
      )
      .run(JSON.stringify({
        direction: 'inbound',
        messageType: input.messageType || 'text',
        content: preview,
      }), input.timestamp || now, now, conversationId);

    this.enqueueSyncAction('sync_message', { messageId: id });
    this.enqueueSyncAction('sync_conversation', { conversationId });
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
    if (!input.reaction) {
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
         VALUES (?, ?, ?, ?)
         ON CONFLICT(messageId, userId)
         DO UPDATE SET reaction = excluded.reaction, timestamp = excluded.timestamp`,
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
    const limit = Math.min(options.limit || 50, 200);
    const offset = options.offset || 0;

    let whereClause = '1=1';
    const params: any[] = [];

    if (options.accountId) {
      whereClause += ' AND accountId = ?';
      params.push(options.accountId);
    }

    if (options.search) {
      whereClause += ' AND (displayName LIKE ? OR threadId LIKE ?)';
      const searchPattern = `%${options.search}%`;
      params.push(searchPattern, searchPattern);
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
      conversations: rows.map((r) => this._mapConversation(r)),
      total,
    };
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
