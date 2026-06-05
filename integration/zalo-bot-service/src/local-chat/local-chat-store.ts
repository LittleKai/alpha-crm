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
  MessagePage,
} from './local-chat-types.js';

export class LocalChatStore {
  private db: Database.Database;

  constructor(dbPath: string) {
    const dir = dirname(dbPath);
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true });
    }
    this.db = new Database(dbPath);
    this.db.pragma('journal_mode = WAL');
    this.db.pragma('foreign_keys = ON');
    this._migrate();
  }

  /** Run idempotent schema migration */
  private _migrate(): void {
    this.db.exec(`
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

    const conversationId = this.findOrCreateConversation(
      input.accountId,
      input.threadId,
      input.threadType,
      input.senderName,
      input.avatarUrl || '',
    );

    const id = randomUUID();
    const now = new Date().toISOString();

    this.db
      .prepare(
        `INSERT INTO messages
         (id, conversationId, accountId, threadId, threadType, direction,
          senderId, senderName, content, messageType, providerMessageId,
          zaloMsgId, status, isDeleted, receivedAt, sentAt, createdAt, updatedAt)
         VALUES (?, ?, ?, ?, ?, 'inbound', ?, ?, ?, ?, ?, '', 'delivered', 0,
                 ?, '', ?, ?)`,
      )
      .run(
        id,
        conversationId,
        input.accountId,
        input.threadId,
        input.threadType,
        input.senderId,
        input.senderName,
        input.content,
        input.messageType || 'text',
        input.providerMessageId || '',
        input.timestamp || now,
        now,
        now,
      );

    // Insert attachments
    if (input.attachments && input.attachments.length > 0) {
      this._insertAttachments(id, input.attachments);
    }

    // Update conversation preview
    const preview =
      input.content.length > 100
        ? input.content.slice(0, 100) + '...'
        : input.content;
    this.db
      .prepare(
        `UPDATE conversations
         SET lastMessagePreview = ?, lastMessageAt = ?,
             unreadCount = unreadCount + 1, updatedAt = ?
         WHERE id = ?`,
      )
      .run(preview, input.timestamp || now, now, conversationId);

    return id;
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
          senderId, senderName, content, messageType, providerMessageId,
          zaloMsgId, status, isDeleted, receivedAt, sentAt, createdAt, updatedAt)
         VALUES (?, ?, ?, ?, ?, 'outbound', '', '', ?, ?, '', '', 'queued', 0,
                 '', ?, ?, ?)`,
      )
      .run(
        id,
        conversationId,
        input.accountId,
        input.threadId,
        input.threadType,
        input.content,
        input.messageType || 'text',
        now,
        now,
        now,
      );

    if (input.attachments && input.attachments.length > 0) {
      this._insertAttachments(id, input.attachments);
    }

    return id;
  }

  /**
   * Update outbound message status after send attempt.
   */
  updateMessageStatus(
    messageId: string,
    status: string,
    providerMessageId?: string,
  ): void {
    const now = new Date().toISOString();
    if (providerMessageId) {
      this.db
        .prepare(
          `UPDATE messages SET status = ?, providerMessageId = ?,
           sentAt = ?, updatedAt = ? WHERE id = ?`,
        )
        .run(status, providerMessageId, now, now, messageId);
    } else {
      this.db
        .prepare('UPDATE messages SET status = ?, updatedAt = ? WHERE id = ?')
        .run(status, now, messageId);
    }
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

  // ---------------------------------------------------------------------------
  // Recall / delete
  // ---------------------------------------------------------------------------

  markMessageDeleted(messageId: string): boolean {
    const now = new Date().toISOString();
    const result = this.db
      .prepare(
        'UPDATE messages SET isDeleted = 1, content = ?, updatedAt = ? WHERE id = ?',
      )
      .run('[Tin nhắn đã thu hồi]', now, messageId);
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
       (id, messageId, kind, name, url, localPath, mimeType, sizeBytes, metadataJson, createdAt)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    );
    for (const a of attachments) {
      stmt.run(
        randomUUID(),
        messageId,
        a.kind || '',
        a.name || '',
        a.url || '',
        a.localPath || '',
        a.mimeType || '',
        a.sizeBytes || 0,
        a.metadata ? JSON.stringify(a.metadata) : '{}',
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
      content: row.content,
      messageType: row.messageType,
      providerMessageId: row.providerMessageId,
      zaloMsgId: row.zaloMsgId,
      status: row.status,
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
      createdAt: row.createdAt,
    };
  }
}
