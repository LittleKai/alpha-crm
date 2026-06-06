/**
 * Local-first Live Chat HTTP API handlers.
 * Mounted under /local/* in the main server.
 */

import type { IncomingMessage, ServerResponse } from 'http';
import { randomUUID } from 'crypto';
import { getLocalChatStore } from './index.js';
import { config } from '../config.js';
import {
  getZaloStatus,
  reactMessage,
  sendMessage,
  sendTyping,
} from '../zalo.js';
import type { ZaloSendMessageRequest } from '../channels/types.js';
import { localChatEvents, type LocalChatEvent } from './local-chat-events.js';

type JsonFn = (res: ServerResponse, status: number, data: unknown, req?: IncomingMessage) => void;
type ReadBodyFn = (req: IncomingMessage) => Promise<string>;

/**
 * Try to handle a /local/* request. Returns true if handled.
 */
export function handleLocalRoute(
  method: string,
  url: string,
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
  readBody: ReadBodyFn,
): boolean {
  if (!url.startsWith('/local/')) return false;

  // GET /local/events?accountId=&threadId=
  if (method === 'GET' && /^\/local\/events(\?.*)?$/.test(url)) {
    handleLocalEvents(url, req, res);
    return true;
  }

  // GET /local/health
  if (method === 'GET' && url === '/local/health') {
    handleLocalHealth(req, res, json);
    return true;
  }

  // GET /local/conversations?accountId=&search=&limit=&offset=
  const convListMatch = url.match(/^\/local\/conversations(\?.*)?$/);
  if (method === 'GET' && convListMatch && !url.includes('/conversations/')) {
    const queryStr = convListMatch[1] ? convListMatch[1].slice(1) : '';
    handleLocalConversationList(queryStr, req, res, json);
    return true;
  }

  // POST /local/conversations/:id/mark-read
  const markReadMatch = url.match(/^\/local\/conversations\/([^/?]+)\/mark-read$/);
  if (method === 'POST' && markReadMatch) {
    const conversationId = decodeURIComponent(markReadMatch[1]);
    handleLocalMarkRead(conversationId, req, res, json);
    return true;
  }

  // GET /local/conversations/:id/messages?before=&after=&limit=
  const msgMatch = url.match(/^\/local\/conversations\/([^/?]+)\/messages(\?.*)?$/);
  if (method === 'GET' && msgMatch) {
    const conversationId = decodeURIComponent(msgMatch[1]);
    const queryStr = msgMatch[2] ? msgMatch[2].slice(1) : '';
    handleLocalMessages(conversationId, queryStr, req, res, json);
    return true;
  }

  // GET /local/messages/search?q=&accountId=&threadId=
  if (method === 'GET' && /^\/local\/messages\/search(\?.*)?$/.test(url)) {
    handleLocalMessageSearch(url, req, res, json);
    return true;
  }

  // GET /local/messages/:id/around?radius=
  const aroundMatch = url.match(/^\/local\/messages\/([^/?]+)\/around(\?.*)?$/);
  if (method === 'GET' && aroundMatch) {
    handleLocalMessagesAround(
      decodeURIComponent(aroundMatch[1]),
      aroundMatch[2]?.slice(1) || '',
      req,
      res,
      json,
    );
    return true;
  }

  // POST /local/messages/send
  if (method === 'POST' && url === '/local/messages/send') {
    handleLocalSend(req, res, json, readBody);
    return true;
  }

  // POST /local/messages/attachments/send
  if (method === 'POST' && url === '/local/messages/attachments/send') {
    handleLocalSendAttachment(req, res, json, readBody);
    return true;
  }

  // POST /local/messages/:id/recall
  const recallMatch = url.match(/^\/local\/messages\/([^/?]+)\/recall$/);
  if (method === 'POST' && recallMatch) {
    const messageId = decodeURIComponent(recallMatch[1]);
    handleLocalRecall(messageId, req, res, json);
    return true;
  }

  const retryMatch = url.match(/^\/local\/messages\/([^/?]+)\/retry$/);
  if (method === 'POST' && retryMatch) {
    handleLocalRetry(
      decodeURIComponent(retryMatch[1]),
      req,
      res,
      json,
    );
    return true;
  }

  const reactionMatch = url.match(/^\/local\/messages\/([^/?]+)\/reactions$/);
  if (method === 'POST' && reactionMatch) {
    handleLocalReaction(
      decodeURIComponent(reactionMatch[1]),
      req,
      res,
      json,
      readBody,
    );
    return true;
  }

  if (method === 'POST' && url === '/local/typing') {
    handleLocalTyping(req, res, json, readBody);
    return true;
  }

  const draftMatch = url.match(/^\/local\/drafts\/([^/?]+)\/([^/?]+)$/);
  if ((method === 'GET' || method === 'PUT') && draftMatch) {
    handleLocalDraft(
      method,
      decodeURIComponent(draftMatch[1]),
      decodeURIComponent(draftMatch[2]),
      req,
      res,
      json,
      readBody,
    );
    return true;
  }

  return false;
}

function writeSseEvent(res: ServerResponse, event: LocalChatEvent): void {
  res.write(`id: ${event.id}\n`);
  res.write(`event: ${event.type}\n`);
  res.write(`data: ${JSON.stringify(event)}\n\n`);
}

function handleLocalEvents(
  url: string,
  req: IncomingMessage,
  res: ServerResponse,
): void {
  const query = new URL(url, 'http://127.0.0.1').searchParams;
  const filter = {
    accountId: query.get('accountId') || undefined,
    threadId: query.get('threadId') || undefined,
  };
  res.writeHead(200, {
    'Content-Type': 'text/event-stream; charset=utf-8',
    'Cache-Control': 'no-cache, no-transform',
    Connection: 'keep-alive',
    'X-Accel-Buffering': 'no',
  });
  res.write(': connected\n\n');

  const lastEventId = req.headers['last-event-id'];
  if (typeof lastEventId === 'string' && lastEventId) {
    for (const event of localChatEvents.replayAfter(lastEventId, filter)) {
      writeSseEvent(res, event);
    }
  }
  const unsubscribe = localChatEvents.subscribe(
    (event) => writeSseEvent(res, event),
    filter,
  );
  const heartbeat = setInterval(() => res.write(': heartbeat\n\n'), 20000);
  req.on('close', () => {
    clearInterval(heartbeat);
    unsubscribe();
  });
}

function serializeMessagePage(page: ReturnType<NonNullable<ReturnType<typeof getLocalChatStore>>['getMessages']>): {
  data: unknown[];
  attachments: Record<string, unknown[]>;
} {
  const attachments: Record<string, unknown[]> = {};
  for (const [messageId, items] of page.attachments) {
    attachments[messageId] = items;
  }
  return { data: page.messages, attachments };
}

function handleLocalMessageSearch(
  url: string,
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
): void {
  const store = getLocalChatStore();
  if (!store) {
    json(res, 503, { success: false, reason: 'localOnlyUnavailable' }, req);
    return;
  }
  const query = new URL(url, 'http://127.0.0.1').searchParams;
  const term = query.get('q') || '';
  const data = store.searchMessages(term, {
    accountId: query.get('accountId') || undefined,
    threadId: query.get('threadId') || undefined,
    limit: Number(query.get('limit') || 50),
  });
  json(res, 200, { success: true, data }, req);
}

function handleLocalMessagesAround(
  messageId: string,
  queryString: string,
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
): void {
  const store = getLocalChatStore();
  if (!store) {
    json(res, 503, { success: false, reason: 'localOnlyUnavailable' }, req);
    return;
  }
  const message = store.getMessage(messageId);
  if (!message) {
    json(res, 404, { success: false, error: 'Message not found.' }, req);
    return;
  }
  const params = new URLSearchParams(queryString);
  const radius = Math.min(Number(params.get('radius') || 15), 50);
  const page = store.getMessagesAround(
    message.conversationId,
    messageId,
    radius,
  );
  json(res, 200, { success: true, ...serializeMessagePage(page) }, req);
}

// ---------------------------------------------------------------------------
// GET /local/health
// ---------------------------------------------------------------------------
function handleLocalHealth(
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
): void {
  const store = getLocalChatStore();
  const zaloStatus = getZaloStatus();

  if (!store) {
    json(res, 200, {
      success: true,
      localFirstEnabled: false,
      db: { ok: false, messageCount: 0, conversationCount: 0 },
      zalo: {
        status: zaloStatus.connected ? 'online' : 'offline',
      },
    }, req);
    return;
  }

  const health = store.getHealth();
  json(res, 200, {
    success: true,
    localFirstEnabled: true,
    db: health,
    zalo: {
      status: zaloStatus.connected ? 'online' : 'offline',
    },
  }, req);
}

// ---------------------------------------------------------------------------
// GET /local/conversations?accountId=&search=&limit=&offset=
// ---------------------------------------------------------------------------
function handleLocalConversationList(
  queryStr: string,
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
): void {
  const store = getLocalChatStore();
  if (!store) {
    json(res, 503, {
      success: false,
      reason: 'localOnlyUnavailable',
      error: 'Local-first mode is not enabled.',
    }, req);
    return;
  }

  const params = new URLSearchParams(queryStr);
  const accountId = params.get('accountId') || undefined;
  const search = params.get('search') || undefined;
  const limit = params.has('limit') ? parseInt(params.get('limit')!, 10) : undefined;
  const offset = params.has('offset') ? parseInt(params.get('offset')!, 10) : undefined;

  const result = store.listConversations({ accountId, search, limit, offset });

  json(res, 200, {
    success: true,
    data: result.conversations,
    total: result.total,
  }, req);
}

// ---------------------------------------------------------------------------
// POST /local/conversations/:id/mark-read
// ---------------------------------------------------------------------------
async function handleLocalMarkRead(
  conversationId: string,
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
): Promise<void> {
  const store = getLocalChatStore();
  if (!store) {
    json(res, 503, {
      success: false,
      reason: 'localOnlyUnavailable',
      error: 'Local-first mode is not enabled.',
    }, req);
    return;
  }

  // Try by cloud conversation id first, then by direct local id
  let success = false;
  let convData: any;

  const convByCloud = store.db
    .prepare('SELECT * FROM conversations WHERE cloudConversationId = ?')
    .get(conversationId);

  if (convByCloud) {
    success = store.markConversationRead((convByCloud as any).id);
    convData = convByCloud;
  } else {
    success = store.markConversationRead(conversationId);
    convData = store.db.prepare('SELECT * FROM conversations WHERE id = ?').get(conversationId);
  }

  // Comply with blockSeen account settings before sending Zalo seen event
  if (success && convData) {
    try {
      const { getAccounts } = await import('../zalo.js');
      const accounts = getAccounts();
      const account = accounts.find((a) => a.id === convData.accountId);
      
      const blockSeen = account?.settings?.blockSeen === true;
      if (!blockSeen) {
        // Find the last received message to get providerMessageId
        const lastInboundMsg = store.db
          .prepare('SELECT providerMessageId FROM messages WHERE conversationId = ? AND direction = \'inbound\' ORDER BY createdAt DESC LIMIT 1')
          .get(convData.id) as any;

        if (lastInboundMsg && lastInboundMsg.providerMessageId) {
          const { accountPool } = await import('../channels/personal-zca-channel.js');
          const instance = accountPool.get(convData.accountId);
          if (instance && instance.api) {
            const threadType = convData.threadType === 'group' ? 1 : 0;
            // Best effort fire-and-forget
            (instance.api as any).sendSeenEvent(convData.threadId, threadType, lastInboundMsg.providerMessageId).catch(() => {});
          }
        }
      }
    } catch (e) {
      console.warn('[local-chat] Could not send seen event:', e);
    }
    localChatEvents.publish({
      type: 'conversation.read',
      accountId: convData.accountId,
      threadId: convData.threadId,
      data: { conversationId: convData.id },
    });
  }

  json(res, success ? 200 : 404, { success }, req);
}

// ---------------------------------------------------------------------------
// GET /local/conversations/:id/messages
// ---------------------------------------------------------------------------
async function handleLocalMessages(
  conversationId: string,
  queryStr: string,
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
): Promise<void> {
  const store = getLocalChatStore();
  if (!store) {
    json(res, 503, {
      success: false,
      reason: 'localOnlyUnavailable',
      error: 'Local-first mode is not enabled.',
    }, req);
    return;
  }

  const params = new URLSearchParams(queryStr);
  const before = params.get('before') || undefined;
  const after = params.get('after') || undefined;
  const limit = params.has('limit') ? parseInt(params.get('limit')!, 10) : undefined;

  let page = store.getMessagesByCloudId(conversationId, { before, after, limit });
  if (!page) {
    page = store.getMessages(conversationId, { before, after, limit });
  }

  // If asking for older messages and we have none (or few), try triggering requestOldMessages
  if (before && page.messages.length === 0) {
    try {
      const conv = store.getConversation(conversationId) || store.db.prepare('SELECT * FROM conversations WHERE cloudConversationId = ?').get(conversationId) as any;
      if (conv) {
        // Find the oldest message providerMessageId we currently have
        const oldestMsg = store.db
          .prepare(`SELECT providerMessageId FROM messages WHERE conversationId = ? AND providerMessageId != '' ORDER BY createdAt ASC LIMIT 1`)
          .get(conv.id) as any;

        if (oldestMsg?.providerMessageId) {
          store.setHistoryState(conv.accountId, conv.threadId, {
            oldestTimestamp: before,
            hasMore: true,
            loading: true,
            lastError: '',
          });
          const { accountPool } = await import('../channels/personal-zca-channel.js');
          const instance = accountPool.get(conv.accountId);
          if (instance && instance.api?.listener) {
            const threadTypeNum = conv.threadType === 'group' ? 1 : 0;
            console.log(`[local-chat-api] Local history exhausted. Requesting old messages from Zalo (msgId: ${oldestMsg.providerMessageId})`);
            // Fire-and-forget: request old messages from Zalo. They will come in via the "old_messages" event.
            (instance.api.listener as any).requestOldMessages(threadTypeNum, oldestMsg.providerMessageId);
          }
        }
      }
    } catch (err) {
      console.warn('[local-chat-api] Failed to trigger requestOldMessages:', err);
      const conv = store.getConversation(conversationId);
      if (conv) {
        store.setHistoryState(conv.accountId, conv.threadId, {
          oldestTimestamp: before,
          hasMore: true,
          loading: false,
          lastError: err instanceof Error ? err.message : String(err),
        });
      }
    }
  }

  // Convert attachments map to a plain object for JSON serialization
  const attachmentsObj: Record<string, any[]> = {};
  if (page) {
    for (const [msgId, atts] of page.attachments) {
      attachmentsObj[msgId] = atts;
    }
  }

  json(res, 200, {
    success: true,
    data: page
      ? page.messages.map((message) => ({
          ...message,
          receipts: store.getReceipts(message.id),
          reactions: store.getReactions(message.id),
        }))
      : [],
    attachments: attachmentsObj,
    history: (() => {
      const conv = store.getConversation(conversationId);
      return conv
        ? store.getHistoryState(conv.accountId, conv.threadId)
        : undefined;
    })(),
  }, req);
}

// ---------------------------------------------------------------------------
// POST /local/messages/send
// ---------------------------------------------------------------------------
async function handleLocalSend(
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
  readBody: ReadBodyFn,
): Promise<void> {
  const store = getLocalChatStore();
  if (!store) {
    json(res, 503, {
      success: false,
      reason: 'localOnlyUnavailable',
      error: 'Local-first mode is not enabled.',
    }, req);
    return;
  }

  let payload: any;
  try {
    payload = JSON.parse(await readBody(req));
  } catch {
    json(res, 400, { success: false, error: 'Invalid JSON body.' }, req);
    return;
  }

  let recipientId = payload.recipientId || payload.threadId;
  const content = String(payload.content || payload.message || '');
  let accountId = payload.accountId || '';
  let threadType = payload.threadType || 'user';

  // If we only got conversationId, look it up in the database
  if (payload.conversationId && !recipientId) {
    const conv = store.db.prepare('SELECT * FROM conversations WHERE id = ?').get(payload.conversationId) as any;
    if (conv) {
      recipientId = conv.threadId;
      accountId = conv.accountId;
      threadType = conv.threadType;
    }
  }

  if (!recipientId || typeof recipientId !== 'string' || recipientId.trim().length === 0) {
    json(res, 400, { success: false, error: 'recipientId or threadId is required.' }, req);
    return;
  }

  // Check account status
  if (accountId) {
    const acc = store.db.prepare('SELECT status FROM accounts WHERE id = ?').get(accountId) as any;
    if (acc && acc.status === 'DISCONNECTED_EXPIRED') {
      json(res, 401, { success: false, error: 'Logged out. Device is no longer connected to Zalo.' }, req);
      return;
    }
  }
  const hasRichPayload = Boolean(
    payload.sticker ||
    payload.link ||
    payload.video ||
    payload.voice ||
    (Array.isArray(payload.attachments) && payload.attachments.length > 0),
  );
  if (
    (!content || typeof content !== 'string' || content.trim().length === 0) &&
    !hasRichPayload
  ) {
    json(res, 400, { success: false, error: 'content or message text is required.' }, req);
    return;
  }

  // 1. Persist outbound message locally with "queued" status
  const clientMessageId = payload.clientMessageId || randomUUID();
  const localMsgId = store.insertOutboundMessage({
    accountId,
    threadId: recipientId,
    threadType,
    content: content.trim(),
    messageType: payload.messageType || 'text',
    clientMessageId,
    quote: payload.quote,
    mentions: payload.mentions,
    styles: payload.styles,
    metadata: {
      ...(payload.metadata || {}),
      ...(payload.link ? { link: payload.link } : {}),
      ...(payload.sticker ? { sticker: payload.sticker } : {}),
      ...(payload.video ? { video: payload.video } : {}),
      ...(payload.voice ? { voice: payload.voice } : {}),
    },
    attachments: (payload.attachments || []).map((path: string) => ({
      kind: payload.messageType || 'file',
      url: path,
      localPath: path,
    })),
  });
  localChatEvents.publish({
    type: 'message.created',
    accountId,
    threadId: recipientId,
    data: { messageId: localMsgId, clientMessageId, status: 'queued' },
  });

  // 2. Send through ZCA/active channel
  try {
    const sendReq: ZaloSendMessageRequest = {
      recipientId,
      message: content.trim(),
      accountId: accountId || undefined,
      threadType,
      messageType: payload.messageType || 'text',
      attachments: payload.attachments,
      clientMessageId,
      quote: payload.quote,
      mentions: payload.mentions,
      styles: payload.styles,
      link: payload.link,
      sticker: payload.sticker,
      video: payload.video,
      voice: payload.voice,
      metadata: payload.metadata,
    };
    const result = await sendMessage(sendReq, false);

    if (result.success) {
      store.updateMessageStatus(localMsgId, 'sent', result.messageId);
      localChatEvents.publish({
        type: 'message.updated',
        accountId,
        threadId: recipientId,
        data: {
          messageId: localMsgId,
          clientMessageId,
          providerMessageId: result.messageId,
          status: 'sent',
        },
      });
      json(res, 200, {
        success: true,
        localMessageId: localMsgId,
        providerMessageId: result.messageId,
      }, req);
    } else {
      store.updateMessageStatus(
        localMsgId,
        'failed',
        undefined,
        result.error || 'Send failed.',
      );
      localChatEvents.publish({
        type: 'message.failed',
        accountId,
        threadId: recipientId,
        data: {
          messageId: localMsgId,
          clientMessageId,
          error: result.error || 'Send failed.',
        },
      });
      json(res, 500, {
        success: false,
        localMessageId: localMsgId,
        error: result.error || 'Send failed.',
      }, req);
    }
  } catch (err: any) {
    store.updateMessageStatus(
      localMsgId,
      'failed',
      undefined,
      err.message || 'Send failed.',
    );
    localChatEvents.publish({
      type: 'message.failed',
      accountId,
      threadId: recipientId,
      data: {
        messageId: localMsgId,
        clientMessageId,
        error: err.message || 'Send failed.',
      },
    });
    json(res, 500, {
      success: false,
      localMessageId: localMsgId,
      error: err.message || 'Send failed.',
    }, req);
  }
}

// ---------------------------------------------------------------------------
// POST /local/messages/attachments/send
// ---------------------------------------------------------------------------
async function handleLocalSendAttachment(
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
  readBody: ReadBodyFn,
): Promise<void> {
  const store = getLocalChatStore();
  if (!store) {
    json(res, 503, {
      success: false,
      reason: 'localOnlyUnavailable',
      error: 'Local-first mode is not enabled.',
    }, req);
    return;
  }

  let payload: any;
  try {
    payload = JSON.parse(await readBody(req));
  } catch {
    json(res, 400, { success: false, error: 'Invalid JSON body.' }, req);
    return;
  }

  let recipientId = payload.recipientId || payload.threadId;
  let accountId = payload.accountId || '';
  let threadType = payload.threadType || 'user';
  const content = String(payload.content || payload.message || '');
  const attachments: string[] = payload.attachments || [];
  const messageType = payload.messageType || 'file';

  // If we only got conversationId, look it up in the database
  if (payload.conversationId && !recipientId) {
    const conv = store.db.prepare('SELECT * FROM conversations WHERE id = ?').get(payload.conversationId) as any;
    if (conv) {
      recipientId = conv.threadId;
      accountId = conv.accountId;
      threadType = conv.threadType;
    }
  }

  if (!recipientId || typeof recipientId !== 'string' || recipientId.trim().length === 0) {
    json(res, 400, { success: false, error: 'recipientId or threadId is required.' }, req);
    return;
  }
  if ((!content || content.trim().length === 0) && attachments.length === 0) {
    json(res, 400, { success: false, error: 'content or attachments are required.' }, req);
    return;
  }

  // 1. Persist locally
  const clientMessageId = payload.clientMessageId || randomUUID();
  const attachmentInputs = attachments.map((path: string) => ({
    kind: messageType,
    url: path,
    localPath: path,
  }));
  const localMsgId = store.insertOutboundMessage({
    accountId,
    threadId: recipientId,
    threadType,
    content: content.trim(),
    messageType,
    clientMessageId,
    quote: payload.quote,
    mentions: payload.mentions,
    styles: payload.styles,
    metadata: payload.metadata,
    attachments: attachmentInputs,
  });
  localChatEvents.publish({
    type: 'message.created',
    accountId,
    threadId: recipientId,
    data: { messageId: localMsgId, clientMessageId, status: 'queued' },
  });

  // 2. Send through ZCA/active channel
  try {
    const sendReq: ZaloSendMessageRequest = {
      recipientId,
      message: content.trim(),
      accountId: accountId || undefined,
      threadType,
      messageType,
      attachments,
      clientMessageId,
      quote: payload.quote,
      mentions: payload.mentions,
      styles: payload.styles,
      metadata: payload.metadata,
    };
    const result = await sendMessage(sendReq, false);

    if (result.success) {
      store.updateMessageStatus(localMsgId, 'sent', result.messageId);
      localChatEvents.publish({
        type: 'message.updated',
        accountId,
        threadId: recipientId,
        data: {
          messageId: localMsgId,
          clientMessageId,
          providerMessageId: result.messageId,
          status: 'sent',
        },
      });
      json(res, 200, {
        success: true,
        localMessageId: localMsgId,
        providerMessageId: result.messageId,
      }, req);
    } else {
      store.updateMessageStatus(
        localMsgId,
        'failed',
        undefined,
        result.error || 'Attachment send failed.',
      );
      localChatEvents.publish({
        type: 'message.failed',
        accountId,
        threadId: recipientId,
        data: {
          messageId: localMsgId,
          clientMessageId,
          error: result.error || 'Attachment send failed.',
        },
      });
      json(res, 500, {
        success: false,
        localMessageId: localMsgId,
        error: result.error || 'Attachment send failed.',
      }, req);
    }
  } catch (err: any) {
    store.updateMessageStatus(
      localMsgId,
      'failed',
      undefined,
      err.message || 'Attachment send failed.',
    );
    localChatEvents.publish({
      type: 'message.failed',
      accountId,
      threadId: recipientId,
      data: {
        messageId: localMsgId,
        clientMessageId,
        error: err.message || 'Attachment send failed.',
      },
    });
    json(res, 500, {
      success: false,
      localMessageId: localMsgId,
      error: err.message || 'Attachment send failed.',
    }, req);
  }
}

// ---------------------------------------------------------------------------
// POST /local/messages/:id/recall
// ---------------------------------------------------------------------------
async function handleLocalRecall(
  messageId: string,
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
): Promise<void> {
  const store = getLocalChatStore();
  if (!store) {
    json(res, 503, {
      success: false,
      reason: 'localOnlyUnavailable',
      error: 'Local-first mode is not enabled.',
    }, req);
    return;
  }

  try {
    // Look up the message to get its providerMessageId, accountId, and threadId
    const msgRow = store.db
      .prepare('SELECT accountId, threadId, threadType, providerMessageId, clientMessageId FROM messages WHERE id = ?')
      .get(messageId) as { accountId: string; threadId: string; threadType: string; providerMessageId: string; clientMessageId: string } | undefined;

    if (!msgRow) {
      json(res, 404, { success: false, error: 'Message not found.' }, req);
      return;
    }

    if (!msgRow.providerMessageId) {
      json(res, 400, { success: false, error: 'Cannot recall message: missing provider message ID.' }, req);
      return;
    }

    // Call Zalo API to recall the message
    const { recallMessage } = await import('../zalo.js');
    const recallResult = await recallMessage({
      accountId: msgRow.accountId,
      threadId: msgRow.threadId,
      threadType: msgRow.threadType as 'user' | 'group',
      msgId: msgRow.providerMessageId,
      cliMsgId: msgRow.clientMessageId || undefined,
    });

    if (recallResult.success) {
      // Mark as deleted locally
      const deleted = store.markMessageDeleted(messageId);
      localChatEvents.publish({
        type: 'message.recalled',
        accountId: msgRow.accountId,
        threadId: msgRow.threadId,
        data: {
          messageId,
          providerMessageId: msgRow.providerMessageId,
          clientMessageId: msgRow.clientMessageId,
        },
      });
      json(res, 200, { success: true, deletedLocal: deleted }, req);
    } else {
      json(res, 500, { success: false, error: recallResult.error || 'Failed to recall message via Zalo API.' }, req);
    }
  } catch (err: any) {
    json(res, 500, { success: false, error: err.message || 'Internal server error during recall.' }, req);
  }
}

async function handleLocalRetry(
  messageId: string,
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
): Promise<void> {
  const store = getLocalChatStore();
  const message = store?.getMessage(messageId);
  if (!store || !message) {
    json(res, 404, { success: false, error: 'Message not found.' }, req);
    return;
  }
  if (message.direction !== 'outbound') {
    json(res, 400, { success: false, error: 'Only outbound messages can be retried.' }, req);
    return;
  }
  const attachments = store.db
    .prepare(
      `SELECT CASE WHEN localPath != '' THEN localPath ELSE url END AS path
       FROM attachments WHERE messageId = ?`,
    )
    .all(messageId) as Array<{ path: string }>;
  const metadata = JSON.parse(message.metadataJson || '{}');
  store.updateMessageStatus(messageId, 'sending');
  localChatEvents.publish({
    type: 'message.updated',
    accountId: message.accountId,
    threadId: message.threadId,
    data: { messageId, status: 'sending' },
  });
  const result = await sendMessage({
    accountId: message.accountId,
    recipientId: message.threadId,
    threadType: message.threadType,
    message: message.content,
    messageType: message.messageType as ZaloSendMessageRequest['messageType'],
    clientMessageId: message.clientMessageId || randomUUID(),
    quote: JSON.parse(message.quoteJson || '{}'),
    mentions: JSON.parse(message.mentionsJson || '[]'),
    styles: JSON.parse(message.stylesJson || '[]'),
    metadata,
    link: metadata.link,
    sticker: metadata.sticker,
    video: metadata.video,
    voice: metadata.voice,
    attachments: attachments.map((item) => item.path).filter(Boolean),
  });
  if (result.success) {
    store.updateMessageStatus(messageId, 'sent', result.messageId);
  } else {
    store.updateMessageStatus(
      messageId,
      'failed',
      undefined,
      result.error || 'Retry failed.',
    );
  }
  localChatEvents.publish({
    type: result.success ? 'message.updated' : 'message.failed',
    accountId: message.accountId,
    threadId: message.threadId,
    data: {
      messageId,
      providerMessageId: result.messageId,
      status: result.success ? 'sent' : 'failed',
      error: result.error,
    },
  });
  json(res, result.success ? 200 : 500, {
    success: result.success,
    localMessageId: messageId,
    providerMessageId: result.messageId,
    error: result.error,
  }, req);
}

async function handleLocalReaction(
  messageId: string,
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
  readBody: ReadBodyFn,
): Promise<void> {
  const store = getLocalChatStore();
  const message = store?.getMessage(messageId);
  if (!store || !message) {
    json(res, 404, { success: false, error: 'Message not found.' }, req);
    return;
  }
  const payload = JSON.parse(await readBody(req).catch(() => '{}'));
  const reaction = String(payload.reaction || '');
  if (!message.providerMessageId || !reaction) {
    json(res, 400, { success: false, error: 'providerMessageId and reaction are required.' }, req);
    return;
  }
  const result = await reactMessage({
    accountId: message.accountId,
    threadId: message.threadId,
    threadType: message.threadType,
    msgId: message.providerMessageId,
    reaction,
  });
  if (result.success) {
    store.upsertReaction({
      accountId: message.accountId,
      providerMessageId: message.providerMessageId,
      userId: message.accountId,
      reaction,
      timestamp: new Date().toISOString(),
    });
    localChatEvents.publish({
      type: 'message.reaction',
      accountId: message.accountId,
      threadId: message.threadId,
      data: { messageId, userId: message.accountId, reaction },
    });
  }
  json(res, result.success ? 200 : 500, result, req);
}

async function handleLocalTyping(
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
  readBody: ReadBodyFn,
): Promise<void> {
  const payload = JSON.parse(await readBody(req).catch(() => '{}'));
  const accountId = String(payload.accountId || '');
  const threadId = String(payload.threadId || '');
  const threadType = payload.threadType === 'group' ? 'group' : 'user';
  if (!accountId || !threadId) {
    json(res, 400, { success: false, error: 'accountId and threadId are required.' }, req);
    return;
  }
  const success = await sendTyping(accountId, threadId, threadType);
  json(res, success ? 200 : 501, { success }, req);
}

async function handleLocalDraft(
  method: string,
  accountId: string,
  threadId: string,
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
  readBody: ReadBodyFn,
): Promise<void> {
  const store = getLocalChatStore();
  if (!store) {
    json(res, 503, { success: false, reason: 'localOnlyUnavailable' }, req);
    return;
  }
  if (method === 'GET') {
    json(res, 200, {
      success: true,
      content: store.getDraft(accountId, threadId),
    }, req);
    return;
  }
  const payload = JSON.parse(await readBody(req).catch(() => '{}'));
  store.saveDraft(accountId, threadId, String(payload.content || ''));
  json(res, 200, { success: true }, req);
}
