import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { LocalChatStore } from './local-chat-store.js';
import { mkdtempSync, rmSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';

let store: LocalChatStore;
let tmpDir: string;

function setup(): void {
  tmpDir = mkdtempSync(join(tmpdir(), 'local-chat-test-'));
  store = new LocalChatStore(join(tmpDir, 'test.sqlite'));
}

function teardown(): void {
  store.close();
  rmSync(tmpDir, { recursive: true, force: true });
}

describe('LocalChatStore', () => {
  beforeEach(() => setup());
  afterEach(() => teardown());

  // -------------------------------------------------------------------------
  // Inbound upsert creates conversation and message
  // -------------------------------------------------------------------------
  it('inbound upsert creates conversation and message', () => {
    const msgId = store.upsertInboundMessage({
      accountId: 'acc1',
      threadId: 'thread1',
      threadType: 'user',
      senderId: 'sender1',
      senderName: 'Nguyen Van A',
      avatarUrl: 'https://example.com/avatar.jpg',
      content: 'Xin chào!',
      messageType: 'text',
      providerMessageId: 'pmsg_001',
      timestamp: '2024-06-01T12:00:00Z',
    });

    assert.ok(msgId, 'should return a message id');

    const conv = store.getConversationByThread('acc1', 'thread1');
    assert.ok(conv, 'conversation should exist');
    assert.equal(conv!.accountId, 'acc1');
    assert.equal(conv!.threadId, 'thread1');
    assert.equal(conv!.threadType, 'user');
    assert.equal(conv!.displayName, 'Nguyen Van A');
    assert.equal(conv!.unreadCount, 1);

    const page = store.getMessages(conv!.id);
    assert.equal(page.messages.length, 1);
    assert.equal(page.messages[0].content, 'Xin chào!');
    assert.equal(page.messages[0].direction, 'inbound');
    assert.equal(page.messages[0].providerMessageId, 'pmsg_001');
  });

  // -------------------------------------------------------------------------
  // Duplicate provider message does not duplicate rows
  // -------------------------------------------------------------------------
  it('duplicate provider message does not duplicate rows', () => {
    const input = {
      accountId: 'acc1',
      threadId: 'thread1',
      threadType: 'user' as const,
      senderId: 'sender1',
      senderName: 'Nguyen Van A',
      content: 'Hello',
      messageType: 'text',
      providerMessageId: 'pmsg_dup',
      timestamp: '2024-06-01T12:00:00Z',
    };

    const id1 = store.upsertInboundMessage(input);
    const id2 = store.upsertInboundMessage(input);

    assert.equal(id1, id2, 'should return same id for duplicate');

    const conv = store.getConversationByThread('acc1', 'thread1');
    const page = store.getMessages(conv!.id);
    assert.equal(page.messages.length, 1, 'should have exactly 1 message');
  });

  // -------------------------------------------------------------------------
  // Paging with before and after returns stable chronological order
  // -------------------------------------------------------------------------
  it('paging with before and after returns stable chronological order', async () => {
    // Insert 5 messages with distinct timestamps
    for (let i = 0; i < 5; i++) {
      store.upsertInboundMessage({
        accountId: 'acc1',
        threadId: 'thread1',
        threadType: 'user',
        senderId: 'sender1',
        senderName: 'User',
        content: `Message ${i}`,
        messageType: 'text',
        providerMessageId: `pmsg_${i}`,
        timestamp: `2024-06-01T12:0${i}:00Z`,
      });
      // Sleep 5ms to ensure distinct createdAt
      await new Promise(r => setTimeout(r, 5));
    }

    const conv = store.getConversationByThread('acc1', 'thread1');
    assert.ok(conv);

    // Get all messages
    const allPage = store.getMessages(conv!.id, { limit: 10 });
    assert.equal(allPage.messages.length, 5);

    // Verify chronological order
    for (let i = 1; i < allPage.messages.length; i++) {
      assert.ok(
        allPage.messages[i].createdAt >= allPage.messages[i - 1].createdAt,
        'messages should be in chronological order',
      );
    }

    // Paging with "before" - get messages before the 3rd message
    const thirdMsgTime = allPage.messages[2].createdAt;
    const beforePage = store.getMessages(conv!.id, {
      before: thirdMsgTime,
      limit: 10,
    });
    assert.equal(beforePage.messages.length, 2, 'should have 2 messages before msg 3');

    // Paging with "after" - get messages after the 3rd message
    const afterPage = store.getMessages(conv!.id, {
      after: thirdMsgTime,
      limit: 10,
    });
    assert.equal(afterPage.messages.length, 2, 'should have 2 messages after msg 3');

    // Verify "after" returns chronologically ordered results
    for (let i = 0; i < afterPage.messages.length; i++) {
      assert.ok(
        afterPage.messages[i].createdAt > thirdMsgTime,
        'all messages should be after the cursor',
      );
    }
  });

  // -------------------------------------------------------------------------
  // Attachments persist and load with the message
  // -------------------------------------------------------------------------
  it('attachments persist and load with the message', () => {
    const msgId = store.upsertInboundMessage({
      accountId: 'acc1',
      threadId: 'thread1',
      threadType: 'user',
      senderId: 'sender1',
      senderName: 'User',
      content: '',
      messageType: 'image',
      providerMessageId: 'pmsg_img',
      timestamp: '2024-06-01T12:00:00Z',
      attachments: [
        {
          kind: 'image',
          name: 'photo.jpg',
          url: 'https://example.com/photo.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 102400,
          metadata: { width: 800, height: 600 },
        },
        {
          kind: 'file',
          name: 'doc.pdf',
          url: 'https://example.com/doc.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 204800,
        },
      ],
    });

    const conv = store.getConversationByThread('acc1', 'thread1');
    const page = store.getMessages(conv!.id);

    assert.equal(page.messages.length, 1);
    const attachments = page.attachments.get(msgId);
    assert.ok(attachments, 'should have attachments');
    assert.equal(attachments!.length, 2);

    const img = attachments!.find((a) => a.kind === 'image');
    assert.ok(img);
    assert.equal(img!.name, 'photo.jpg');
    assert.equal(img!.mimeType, 'image/jpeg');
    assert.equal(img!.sizeBytes, 102400);
    assert.equal(JSON.parse(img!.metadataJson).width, 800);
    assert.equal(img!.status, 'pending');

    const file = attachments!.find((a) => a.kind === 'file');
    assert.ok(file);
    assert.equal(file!.name, 'doc.pdf');

    store.updateAttachmentDownload(img!.id, {
      status: 'ready',
      localPath: 'D:/cache/photo.jpg',
      checksum: 'sha256',
      downloadedAt: '2026-06-06T12:00:00.000Z',
    });
    const refreshed = store.getMessages(conv!.id).attachments.get(msgId);
    assert.equal(refreshed?.find((item) => item.id === img!.id)?.status, 'ready');
  });

  // -------------------------------------------------------------------------
  // Outbound message insert and status update
  // -------------------------------------------------------------------------
  it('outbound message inserts with queued status and updates after send', () => {
    const msgId = store.insertOutboundMessage({
      accountId: 'acc1',
      threadId: 'thread1',
      threadType: 'user',
      content: 'Hello from operator',
    });

    const conv = store.getConversationByThread('acc1', 'thread1');
    const page = store.getMessages(conv!.id);
    assert.equal(page.messages.length, 1);
    assert.equal(page.messages[0].status, 'queued');
    assert.equal(page.messages[0].direction, 'outbound');

    // Update status after successful send
    store.updateMessageStatus(msgId, 'sent', 'zalo_msg_123');

    const page2 = store.getMessages(conv!.id);
    assert.equal(page2.messages[0].status, 'sent');
    assert.equal(page2.messages[0].providerMessageId, 'zalo_msg_123');
  });

  // -------------------------------------------------------------------------
  // Health check
  // -------------------------------------------------------------------------
  it('health returns counts', () => {
    const health1 = store.getHealth();
    assert.equal(health1.ok, true);
    assert.equal(health1.messageCount, 0);
    assert.equal(health1.conversationCount, 0);

    store.upsertInboundMessage({
      accountId: 'acc1',
      threadId: 'thread1',
      threadType: 'user',
      senderId: 's1',
      senderName: 'U',
      content: 'hi',
      messageType: 'text',
      providerMessageId: 'p1',
      timestamp: '2024-01-01T00:00:00Z',
    });

    const health2 = store.getHealth();
    assert.equal(health2.messageCount, 1);
    assert.equal(health2.conversationCount, 1);
  });

  // -------------------------------------------------------------------------
  // Mark message deleted
  // -------------------------------------------------------------------------
  it('markMessageDeleted sets isDeleted and clears content', () => {
    const msgId = store.upsertInboundMessage({
      accountId: 'acc1',
      threadId: 'thread1',
      threadType: 'user',
      senderId: 's1',
      senderName: 'U',
      content: 'secret message',
      messageType: 'text',
      providerMessageId: 'p_del',
      timestamp: '2024-01-01T00:00:00Z',
    });

    const result = store.markMessageDeleted(msgId);
    assert.equal(result, true);

    const conv = store.getConversationByThread('acc1', 'thread1');
    const page = store.getMessages(conv!.id);
    assert.equal(page.messages[0].isDeleted, true);
    assert.equal(page.messages[0].content, '[Tin nhắn đã thu hồi]');
  });

  // -------------------------------------------------------------------------
  // Sync state
  // -------------------------------------------------------------------------
  it('sync state get/set works', () => {
    assert.equal(store.getSyncState('lastSync'), undefined);

    store.setSyncState('lastSync', '2024-06-01T00:00:00Z');
    assert.equal(store.getSyncState('lastSync'), '2024-06-01T00:00:00Z');

    store.setSyncState('lastSync', '2024-06-02T00:00:00Z');
    assert.equal(store.getSyncState('lastSync'), '2024-06-02T00:00:00Z');
  });

  // -------------------------------------------------------------------------
  // Cloud conversation ID lookup
  // -------------------------------------------------------------------------
  it('getMessagesByCloudId returns null for unknown id', () => {
    const result = store.getMessagesByCloudId('unknown_cloud_id');
    assert.equal(result, null);
  });

  // -------------------------------------------------------------------------
  // Thread-based lookup
  // -------------------------------------------------------------------------
  it('getMessagesByThread returns null for unknown thread', () => {
    const result = store.getMessagesByThread('acc_none', 'thread_none');
    assert.equal(result, null);
  });

  it('getMessagesByThread returns messages for known thread', () => {
    store.upsertInboundMessage({
      accountId: 'acc1',
      threadId: 'thread1',
      threadType: 'user',
      senderId: 's1',
      senderName: 'U',
      content: 'hi',
      messageType: 'text',
      providerMessageId: 'p_thread',
      timestamp: '2024-01-01T00:00:00Z',
    });

    const result = store.getMessagesByThread('acc1', 'thread1');
    assert.ok(result);
    assert.equal(result!.messages.length, 1);
  });

  it('reconciles an outbound self echo by client message id', () => {
    const messageId = store.insertOutboundMessage({
      accountId: 'acc1',
      threadId: 'thread1',
      threadType: 'user',
      content: 'Optimistic message',
      clientMessageId: 'cli-1',
    });

    const reconciled = store.reconcileOutboundMessage({
      accountId: 'acc1',
      clientMessageId: 'cli-1',
      providerMessageId: 'provider-1',
      status: 'sent',
    });

    assert.equal(reconciled, messageId);
    const result = store.getMessagesByThread('acc1', 'thread1');
    assert.equal(result?.messages.length, 1);
    assert.equal(result?.messages[0].clientMessageId, 'cli-1');
    assert.equal(result?.messages[0].providerMessageId, 'provider-1');
  });

  it('persists receipts and reactions against provider message ids', () => {
    const messageId = store.insertOutboundMessage({
      accountId: 'acc1',
      threadId: 'thread1',
      threadType: 'user',
      content: 'Track engagement',
      clientMessageId: 'cli-2',
    });
    store.updateMessageStatus(messageId, 'sent', 'provider-2');

    assert.equal(
      store.upsertReceipt({
        accountId: 'acc1',
        providerMessageId: 'provider-2',
        userId: 'customer-1',
        status: 'seen',
        timestamp: '2026-06-06T10:00:00.000Z',
      }),
      true,
    );
    assert.equal(
      store.upsertReaction({
        accountId: 'acc1',
        providerMessageId: 'provider-2',
        userId: 'customer-1',
        reaction: 'heart',
        timestamp: '2026-06-06T10:01:00.000Z',
      }),
      true,
    );

    assert.deepEqual(store.getReceipts(messageId), [
      {
        messageId,
        userId: 'customer-1',
        status: 'seen',
        timestamp: '2026-06-06T10:00:00.000Z',
      },
    ]);
    assert.deepEqual(store.getReactions(messageId), [
      {
        messageId,
        userId: 'customer-1',
        reaction: 'heart',
        timestamp: '2026-06-06T10:01:00.000Z',
      },
    ]);
  });

  it('saves drafts and history state per account thread', () => {
    store.saveDraft('acc1', 'thread1', 'Noi dung dang viet');
    assert.equal(store.getDraft('acc1', 'thread1'), 'Noi dung dang viet');

    store.setHistoryState('acc1', 'thread1', {
      oldestTimestamp: '2026-01-01T00:00:00.000Z',
      hasMore: true,
      loading: false,
      lastError: '',
    });
    assert.deepEqual(store.getHistoryState('acc1', 'thread1'), {
      oldestTimestamp: '2026-01-01T00:00:00.000Z',
      hasMore: true,
      loading: false,
      lastError: '',
    });
  });

  it('searches messages and returns a window around a result', () => {
    for (let i = 0; i < 5; i++) {
      store.upsertInboundMessage({
        accountId: 'acc1',
        threadId: 'thread1',
        threadType: 'user',
        senderId: 'customer-1',
        senderName: 'Customer',
        content: i === 2 ? 'Hoa don thang sau' : `Message ${i}`,
        messageType: 'text',
        providerMessageId: `search-${i}`,
        timestamp: `2026-06-06T10:0${i}:00.000Z`,
      });
    }

    const results = store.searchMessages('Hoa don', {
      accountId: 'acc1',
      threadId: 'thread1',
    });
    assert.equal(results.length, 1);

    const around = store.getMessagesAround(results[0].conversationId, results[0].id, 1);
    assert.equal(around.messages.length, 3);
    assert.equal(around.messages[1].id, results[0].id);
  });

  it('stores history batches in one transaction', () => {
    const ids = store.upsertInboundMessages([
      {
        accountId: 'acc1',
        threadId: 'thread1',
        threadType: 'user',
        senderId: 'customer-1',
        senderName: 'Customer',
        content: 'Old 1',
        messageType: 'text',
        providerMessageId: 'batch-1',
        timestamp: '2025-01-01T00:00:00.000Z',
      },
      {
        accountId: 'acc1',
        threadId: 'thread1',
        threadType: 'user',
        senderId: 'customer-1',
        senderName: 'Customer',
        content: 'Old 2',
        messageType: 'text',
        providerMessageId: 'batch-2',
        timestamp: '2025-01-01T00:01:00.000Z',
      },
    ]);
    assert.equal(ids.length, 2);
    assert.equal(store.getMessagesByThread('acc1', 'thread1')?.messages.length, 2);
  });
});
