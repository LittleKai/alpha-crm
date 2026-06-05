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
// GET /local/conversations/:id/messages
// ---------------------------------------------------------------------------
function handleLocalMessages(
  conversationId: string,
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
  const before = params.get('before') || undefined;
  const after = params.get('after') || undefined;
  const limit = params.has('limit') ? parseInt(params.get('limit')!, 10) : undefined;

  // Try by cloud conversation id first, then by direct local id
  let page = store.getMessagesByCloudId(conversationId, { before, after, limit });
  if (!page) {
    page = store.getMessages(conversationId, { before, after, limit });
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
function handleLocalRecall(
  messageId: string,
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

  const deleted = store.markMessageDeleted(messageId);
  if (deleted) {
    json(res, 200, { success: true }, req);
  } else {
    json(res, 404, { success: false, error: 'Message not found.' }, req);
  }
}
