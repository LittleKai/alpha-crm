/**
 * Local-first Live Chat HTTP API handlers.
 * Mounted under /local/* in the main server.
 */

import type { IncomingMessage, ServerResponse } from 'http';
import { getLocalChatStore } from './index.js';
import { config } from '../config.js';
import { getZaloStatus, sendMessage } from '../zalo.js';
import type { ZaloSendMessageRequest } from '../channels/types.js';

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

  return false;
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
    data: page ? page.messages : [],
    attachments: attachmentsObj,
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

  const recipientId = payload.recipientId || payload.threadId;
  const content = payload.content || payload.message || '';
  const accountId = payload.accountId || '';
  const threadType = payload.threadType || 'user';

  if (!recipientId || typeof recipientId !== 'string' || recipientId.trim().length === 0) {
    json(res, 400, { success: false, error: 'recipientId or threadId is required.' }, req);
    return;
  }
  if (!content || typeof content !== 'string' || content.trim().length === 0) {
    json(res, 400, { success: false, error: 'content or message text is required.' }, req);
    return;
  }

  // 1. Persist outbound message locally with "queued" status
  const localMsgId = store.insertOutboundMessage({
    accountId,
    threadId: recipientId,
    threadType,
    content: content.trim(),
    messageType: payload.messageType || 'text',
  });

  // 2. Send through ZCA/active channel
  try {
    const sendReq: ZaloSendMessageRequest = {
      recipientId,
      message: content.trim(),
      accountId: accountId || undefined,
      threadType,
      messageType: payload.messageType || 'text',
    };
    const result = await sendMessage(sendReq, false);

    if (result.success) {
      store.updateMessageStatus(localMsgId, 'sent', result.messageId);
      json(res, 200, {
        success: true,
        localMessageId: localMsgId,
        providerMessageId: result.messageId,
      }, req);
    } else {
      store.updateMessageStatus(localMsgId, 'failed');
      json(res, 500, {
        success: false,
        localMessageId: localMsgId,
        error: result.error || 'Send failed.',
      }, req);
    }
  } catch (err: any) {
    store.updateMessageStatus(localMsgId, 'failed');
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

  const recipientId = payload.recipientId || payload.threadId;
  const accountId = payload.accountId || '';
  const threadType = payload.threadType || 'user';
  const content = payload.content || payload.message || '';
  const attachments: string[] = payload.attachments || [];
  const messageType = payload.messageType || 'file';

  if (!recipientId || typeof recipientId !== 'string' || recipientId.trim().length === 0) {
    json(res, 400, { success: false, error: 'recipientId or threadId is required.' }, req);
    return;
  }
  if ((!content || content.trim().length === 0) && attachments.length === 0) {
    json(res, 400, { success: false, error: 'content or attachments are required.' }, req);
    return;
  }

  // 1. Persist locally
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
    attachments: attachmentInputs,
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
    };
    const result = await sendMessage(sendReq, false);

    if (result.success) {
      store.updateMessageStatus(localMsgId, 'sent', result.messageId);
      json(res, 200, {
        success: true,
        localMessageId: localMsgId,
        providerMessageId: result.messageId,
      }, req);
    } else {
      store.updateMessageStatus(localMsgId, 'failed');
      json(res, 500, {
        success: false,
        localMessageId: localMsgId,
        error: result.error || 'Attachment send failed.',
      }, req);
    }
  } catch (err: any) {
    store.updateMessageStatus(localMsgId, 'failed');
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
      .prepare('SELECT accountId, threadId, threadType, providerMessageId FROM messages WHERE id = ?')
      .get(messageId) as { accountId: string; threadId: string; threadType: string; providerMessageId: string } | undefined;

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
    });

    if (recallResult.success) {
      // Mark as deleted locally
      const deleted = store.markMessageDeleted(messageId);
      json(res, 200, { success: true, deletedLocal: deleted }, req);
    } else {
      json(res, 500, { success: false, error: recallResult.error || 'Failed to recall message via Zalo API.' }, req);
    }
  } catch (err: any) {
    json(res, 500, { success: false, error: err.message || 'Internal server error during recall.' }, req);
  }
}
