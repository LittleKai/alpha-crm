/**
 * Local-first Live Chat HTTP API handlers.
 * Mounted under /local/* in the main server.
 */

import type { IncomingMessage, ServerResponse } from 'http';
import { randomUUID } from 'crypto';
import { createReadStream, existsSync, statSync } from 'fs';
import { configureLocalChatMediaCache, getLocalChatStore } from './index.js';
import { config } from '../config.js';
import {
  getZaloStatus,
  reactMessage,
  sendMessage,
  sendTyping,
} from '../zalo.js';
import type { ZaloSendMessageRequest } from '../channels/types.js';
import { localChatEvents, type LocalChatEvent } from './local-chat-events.js';
import type { LocalMessage } from './local-chat-types.js';
import {
  getChatbotConfigSync,
  getChatbotStore,
  pauseChatbotForOperatorReply,
} from '../chatbot/index.js';
import { ChatbotStore, isChatbotPaused } from '../chatbot/chatbot-store.js';
import {
  listKnowledgeFileIds,
  saveKnowledgeFile,
} from '../chatbot/chatbot-knowledge-store.js';
import type { ChatbotConversationMode } from '../chatbot/chatbot-types.js';

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

  if (method === 'GET' && url === '/local/media-cache') {
    handleLocalMediaCache(req, res, json);
    return true;
  }
  if (method === 'POST' && url === '/local/media-cache/settings') {
    void handleLocalMediaCacheSettings(req, res, json, readBody);
    return true;
  }

  const mediaMatch = url.match(/^\/local\/media\/([^/?]+)(\/download)?$/);
  if (method === 'GET' && mediaMatch) {
    handleLocalMedia(
      decodeURIComponent(mediaMatch[1]),
      mediaMatch[2] === '/download',
      req,
      res,
      json,
    );
    return true;
  }

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

  if (method === 'GET' && url === '/local/chatbot/status') {
    handleLocalChatbotStatus(req, res, json);
    return true;
  }
  if (method === 'POST' && url === '/local/chatbot/sync') {
    void handleLocalChatbotSync(req, res, json);
    return true;
  }
  // POST /local/chatbot/knowledge-file  → store an operator-attached file
  if (method === 'POST' && url === '/local/chatbot/knowledge-file') {
    void handleSaveKnowledgeFile(req, res, json, readBody);
    return true;
  }
  // GET /local/chatbot/knowledge-files  → ids present locally (for "missing" warnings)
  if (method === 'GET' && url === '/local/chatbot/knowledge-files') {
    handleListKnowledgeFiles(req, res, json);
    return true;
  }
  // GET /local/chatbot/stats?from=&to=  → durable per-day response/token stats
  if (method === 'GET' && /^\/local\/chatbot\/stats(\?.*)?$/.test(url)) {
    handleLocalChatbotStats(url, req, res, json);
    return true;
  }

  if (method === 'GET' && /^\/local\/reporting\/conversation-rollup(\?.*)?$/.test(url)) {
    handleLocalConversationRollup(url, req, res, json);
    return true;
  }

  if (method === 'GET' && url === '/local/automation/rules') {
    handleLocalAutomationRules(req, res, json);
    return true;
  }
  if (method === 'PUT' && url === '/local/automation/rules') {
    void handlePutLocalAutomationRules(req, res, json, readBody);
    return true;
  }

  // GET /local/accounts/chat-settings  → map of accountId → { aiAutoReply }
  if (method === 'GET' && url === '/local/accounts/chat-settings') {
    handleGetAccountChatSettings(req, res, json);
    return true;
  }
  // PUT /local/accounts/:accountId/chat-settings  → { aiAutoReply: boolean }
  const acctSettingsMatch = url.match(
    /^\/local\/accounts\/([^/?]+)\/chat-settings$/,
  );
  if (method === 'PUT' && acctSettingsMatch) {
    void handlePutAccountChatSettings(
      decodeURIComponent(acctSettingsMatch[1]),
      req,
      res,
      json,
      readBody,
    );
    return true;
  }

  // GET /local/settings  → global app settings (operator-pause cooldown)
  if (method === 'GET' && url === '/local/settings') {
    const ls = getLocalChatStore();
    json(res, 200, {
      success: true,
      data: {
        operatorPauseCooldownMinutes:
          ls?.getOperatorPauseCooldownMinutes() ?? 10,
      },
    }, req);
    return true;
  }
  // PUT /local/settings  → { operatorPauseCooldownMinutes: number }
  if (method === 'PUT' && url === '/local/settings') {
    void (async () => {
      const ls = getLocalChatStore();
      if (!ls) {
        json(res, 503, { success: false, error: 'Local store unavailable.' }, req);
        return;
      }
      let payload: Record<string, unknown>;
      try {
        payload = JSON.parse(await readBody(req)) as Record<string, unknown>;
      } catch {
        json(res, 400, { success: false, error: 'Invalid JSON body.' }, req);
        return;
      }
      const minutes = Number(payload.operatorPauseCooldownMinutes);
      if (!Number.isFinite(minutes)) {
        json(res, 400, {
          success: false,
          error: 'operatorPauseCooldownMinutes (number) is required.',
        }, req);
        return;
      }
      const saved = ls.setOperatorPauseCooldownMinutes(minutes);
      json(res, 200, {
        success: true,
        data: { operatorPauseCooldownMinutes: saved },
      }, req);
    })();
    return true;
  }

  const chatbotStateMatch = url.match(
    /^\/local\/conversations\/([^/?]+)\/chatbot$/,
  );
  if (
    chatbotStateMatch
    && (method === 'GET' || method === 'PUT')
  ) {
    void handleLocalConversationChatbot(
      method,
      decodeURIComponent(chatbotStateMatch[1]),
      req,
      res,
      json,
      readBody,
    );
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

  const updateConversationMatch = url.match(/^\/local\/conversations\/([^/?]+)$/);
  if (method === 'PUT' && updateConversationMatch) {
    void handleLocalUpdateConversation(
      decodeURIComponent(updateConversationMatch[1]),
      req,
      res,
      json,
      readBody,
    );
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

  // POST /local/messages/:id/delete
  const deleteMatch = url.match(/^\/local\/messages\/([^/?]+)\/delete$/);
  if (method === 'POST' && deleteMatch) {
    const messageId = decodeURIComponent(deleteMatch[1]);
    handleLocalDelete(messageId, req, res, json);
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

function handleLocalChatbotStatus(
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
): void {
  const store = getChatbotStore();
  const sync = getChatbotConfigSync();
  const status = sync?.getStatus();
  json(res, 200, {
    success: true,
    data: {
      running: status?.running === true,
      configVersion: status?.configVersion ?? null,
      lastSyncedAt: status?.lastSyncedAt ?? null,
      lastError: status?.lastError ?? null,
      pendingAudits: store?.countPendingAudits() ?? 0,
    },
  }, req);
}

function handleLocalChatbotStats(
  url: string,
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
): void {
  const store = getChatbotStore();
  if (!store) {
    json(res, 503, { success: false, error: 'Chatbot store unavailable.' }, req);
    return;
  }
  const query = new URLSearchParams(url.split('?')[1] ?? '');
  const now = Date.now();
  const toMs = parseDateParam(query.get('to')) ?? now;
  const fromMs =
    parseDateParam(query.get('from')) ?? toMs - 30 * 24 * 60 * 60 * 1000;
  const fromKey = statsDateKey(Math.min(fromMs, toMs));
  const toKey = statsDateKey(Math.max(fromMs, toMs));
  const byDate = new Map(
    store.getResponseStats(fromKey, toKey).map((row) => [row.date, row]),
  );
  // One row per day in range so the chart x-axis stays continuous.
  const data = eachStatsDate(fromKey, toKey).map((date) => {
    const row = byDate.get(date);
    return {
      date,
      tokenIn: row?.tokenIn ?? 0,
      tokenOut: row?.tokenOut ?? 0,
      aiUses: row?.aiUses ?? 0,
      keywordUses: row?.keywordUses ?? 0,
      skipped: row?.skipped ?? 0,
    };
  });
  json(res, 200, { success: true, data }, req);
}

function parseDateParam(value: string | null): number | null {
  if (!value) return null;
  const ms = Date.parse(value);
  if (Number.isFinite(ms)) return ms;
  const asNum = Number(value);
  return Number.isFinite(asNum) && value.trim() !== '' ? asNum : null;
}

/** Local-time `yyyy-MM-dd`, matching how the store buckets responses. */
function statsDateKey(timestampMs: number): string {
  const date = new Date(timestampMs);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function eachStatsDate(fromKey: string, toKey: string): string[] {
  const [fy, fm, fd] = fromKey.split('-').map(Number);
  const [ty, tm, td] = toKey.split('-').map(Number);
  const cursor = new Date(fy, fm - 1, fd);
  const end = new Date(ty, tm - 1, td);
  const result: string[] = [];
  let guard = 0;
  while (cursor <= end && guard < 1000) {
    result.push(statsDateKey(cursor.getTime()));
    cursor.setDate(cursor.getDate() + 1);
    guard += 1;
  }
  return result;
}

async function handleLocalChatbotSync(
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
): Promise<void> {
  const sync = getChatbotConfigSync();
  if (!sync) {
    json(res, 503, {
      success: false,
      error: 'Chatbot runtime is unavailable.',
    }, req);
    return;
  }
  try {
    await sync.syncNow();
    handleLocalChatbotStatus(req, res, json);
  } catch (error) {
    json(res, 502, {
      success: false,
      error: error instanceof Error ? error.message : String(error),
      data: sync.getStatus(),
    }, req);
  }
}

async function handleSaveKnowledgeFile(
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
  readBody: ReadBodyFn,
): Promise<void> {
  try {
    const payload = JSON.parse((await readBody(req)) || '{}');
    const filename = String(payload.filename || '').trim();
    const base64 = String(payload.base64 || '');
    if (!filename || !base64) {
      json(res, 400, {
        success: false,
        error: 'filename and base64 are required.',
      }, req);
      return;
    }
    const bytes = Buffer.from(base64, 'base64');
    if (bytes.byteLength === 0) {
      json(res, 400, { success: false, error: 'Empty file.' }, req);
      return;
    }
    const saved = saveKnowledgeFile(bytes, filename);
    json(res, 200, {
      success: true,
      data: { id: saved.id, name: saved.name, size: bytes.byteLength },
    }, req);
  } catch (error) {
    json(res, 500, {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    }, req);
  }
}

function handleListKnowledgeFiles(
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
): void {
  json(res, 200, {
    success: true,
    data: { ids: listKnowledgeFileIds() },
  }, req);
}

function handleGetAccountChatSettings(
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
): void {
  const localStore = getLocalChatStore();
  if (!localStore) {
    json(res, 503, { success: false, error: 'Local store unavailable.' }, req);
    return;
  }
  json(res, 200, { success: true, data: localStore.getAccountChatSettings() }, req);
}

async function handlePutAccountChatSettings(
  accountId: string,
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
  readBody: ReadBodyFn,
): Promise<void> {
  const localStore = getLocalChatStore();
  if (!localStore) {
    json(res, 503, { success: false, error: 'Local store unavailable.' }, req);
    return;
  }
  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(await readBody(req)) as Record<string, unknown>;
  } catch {
    json(res, 400, { success: false, error: 'Invalid JSON body.' }, req);
    return;
  }
  if (typeof payload.aiAutoReply !== 'boolean') {
    json(res, 400, { success: false, error: 'aiAutoReply (boolean) is required.' }, req);
    return;
  }
  localStore.setAccountAiAutoReply(accountId, payload.aiAutoReply);
  json(res, 200, {
    success: true,
    data: { accountId, aiAutoReply: payload.aiAutoReply },
  }, req);
}

// Conversation chatbot-state (mode/pause/toggle) lives in the local DB and must
// work even when the full chatbot runtime is stopped (e.g. the Zalo account is
// logged out). Fall back to a transient store over the same DB.
function resolveChatbotStore(): ChatbotStore | null {
  const running = getChatbotStore();
  if (running) return running;
  const localStore = getLocalChatStore();
  return localStore ? new ChatbotStore(localStore.db) : null;
}

async function handleLocalConversationChatbot(
  method: string,
  conversationKey: string,
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
  readBody: ReadBodyFn,
): Promise<void> {
  const store = resolveChatbotStore();
  const localStore = getLocalChatStore();
  if (!store || !localStore) {
    json(res, 503, {
      success: false,
      error: 'Chatbot runtime is unavailable.',
    }, req);
    return;
  }
  const parsed = parseConversationKey(conversationKey);
  if (!parsed) {
    json(res, 400, {
      success: false,
      error: 'Invalid conversation key.',
    }, req);
    return;
  }

  if (method === 'PUT') {
    let payload: Record<string, unknown>;
    try {
      payload = JSON.parse(await readBody(req)) as Record<string, unknown>;
    } catch {
      json(res, 400, { success: false, error: 'Invalid JSON body.' }, req);
      return;
    }
    const mode = String(payload.mode ?? '') as ChatbotConversationMode;
    if (!['enabled', 'handoff', 'disabled_by_operator'].includes(mode)) {
      json(res, 400, {
        success: false,
        error: 'Invalid chatbot conversation mode.',
      }, req);
      return;
    }
    store.setConversationState(conversationKey, {
      mode,
      reason: payload.reason == null ? null : String(payload.reason),
      inherited: false,
    });
    publishConversationChatbotState(conversationKey);
  }

  const snapshot = store.getConfigSnapshot();
  const conversation = localStore.db
    .prepare(
      `SELECT threadType FROM conversations
       WHERE accountId = ? AND threadId = ?`,
    )
    .get(parsed.accountId, parsed.threadId) as
    | { threadType: 'user' | 'group' }
    | undefined;
  const effective = store.getEffectiveConversationState(
    conversationKey,
    conversation?.threadType ?? 'user',
    snapshot,
  );
  json(res, 200, {
    success: true,
    data: {
      conversationKey,
      mode: effective?.mode ?? 'disabled_by_operator',
      reason: effective?.reason ?? 'audience_not_eligible',
      inherited: effective?.inherited ?? true,
      pausedUntil: effective?.pausedUntil ?? null,
      effectiveEnabled:
        effective?.mode === 'enabled'
        && !isChatbotPaused(effective)
        && localStore.isAccountAiAutoReplyEnabled(parsed.accountId),
    },
  }, req);
}

function applyOperatorTakeover(
  accountId: string,
  threadId: string,
  origin: unknown,
): void {
  // A successful CRM send by a human → temporarily pause the bot (cooldown).
  // The bot's own sends (origin 'chatbot') must never pause it.
  if (origin === 'chatbot') return;
  pauseChatbotForOperatorReply(accountId, threadId);
}

function publishConversationChatbotState(conversationKey: string): void {
  const parsed = parseConversationKey(conversationKey);
  const state = resolveChatbotStore()?.getConversationState(conversationKey);
  if (!parsed || !state) return;
  localChatEvents.publish({
    type: 'conversation.chatbot_state',
    accountId: parsed.accountId,
    threadId: parsed.threadId,
    data: {
      conversationKey,
      ...state,
      // Effectively active only when enabled AND not in an operator-pause window.
      effectiveEnabled: state.mode === 'enabled' && !isChatbotPaused(state),
    },
  });
}

function parseConversationKey(
  value: string,
): { accountId: string; threadId: string } | null {
  const separator = value.indexOf(':');
  if (separator <= 0 || separator === value.length - 1) return null;
  return {
    accountId: value.slice(0, separator),
    threadId: value.slice(separator + 1),
  };
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
    attachments[messageId] = items.map(serializeAttachment);
  }
  return { data: page.messages, attachments };
}

function serializeLocalMessageWithAttachments(
  store: NonNullable<ReturnType<typeof getLocalChatStore>>,
  messageId: string,
): Record<string, unknown> | undefined {
  const message = store.getMessage(messageId);
  if (!message) return undefined;
  const attachments = (store.db
    .prepare('SELECT * FROM attachments WHERE messageId = ?')
    .all(messageId) as Record<string, unknown>[]).map(serializeAttachment);
  return {
    ...message,
    attachments,
    receipts: store.getReceipts(messageId),
    reactions: store.getReactions(messageId),
  };
}

function serializeAttachment(item: object): Record<string, unknown> {
  const data = item as Record<string, unknown>;
  return {
    ...data,
    cacheUrl: data.status === 'ready' && data.localPath
      ? `/local/media/${encodeURIComponent(String(data.id))}`
      : '',
    downloadUrl: data.status === 'ready' && data.localPath
      ? `/local/media/${encodeURIComponent(String(data.id))}/download`
      : '',
  };
}

function handleLocalMedia(
  attachmentId: string,
  download: boolean,
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
): void {
  const store = getLocalChatStore();
  const attachment = store?.db
    .prepare('SELECT * FROM attachments WHERE id = ?')
    .get(attachmentId) as Record<string, unknown> | undefined;
  const localPath = String(attachment?.localPath || '');
  if (!attachment || attachment.status !== 'ready' || !localPath || !existsSync(localPath)) {
    json(res, 404, { success: false, error: 'Cached media not found.' }, req);
    return;
  }

  const size = statSync(localPath).size;
  const mimeType = String(attachment.mimeType || 'application/octet-stream');
  const safeName = String(attachment.name || `media-${attachmentId}`)
    .replace(/[\r\n"]/g, '_');
  const range = req.headers.range;
  res.setHeader('Accept-Ranges', 'bytes');
  res.setHeader('Content-Type', mimeType);
  res.setHeader(
    'Content-Disposition',
    `${download ? 'attachment' : 'inline'}; filename*=UTF-8''${encodeURIComponent(safeName)}`,
  );

  if (range) {
    const match = /^bytes=(\d*)-(\d*)$/.exec(range);
    const start = match?.[1] ? Number(match[1]) : 0;
    const end = match?.[2] ? Math.min(Number(match[2]), size - 1) : size - 1;
    if (!match || start < 0 || end < start || start >= size) {
      res.statusCode = 416;
      res.setHeader('Content-Range', `bytes */${size}`);
      res.end();
      return;
    }
    res.statusCode = 206;
    res.setHeader('Content-Range', `bytes ${start}-${end}/${size}`);
    res.setHeader('Content-Length', end - start + 1);
    createReadStream(localPath, { start, end }).pipe(res);
    return;
  }

  res.statusCode = 200;
  res.setHeader('Content-Length', size);
  createReadStream(localPath).pipe(res);
}

function handleLocalMediaCache(
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
): void {
  const store = getLocalChatStore();
  if (!store) {
    json(res, 503, { success: false, error: 'Local-first mode is not enabled.' }, req);
    return;
  }
  const stats = store.db
    .prepare(
      `SELECT COUNT(*) AS fileCount,
              COALESCE(SUM(sizeBytes), 0) AS totalBytes
       FROM attachments
       WHERE status = 'ready' AND localPath != ''`,
    )
    .get();
  json(res, 200, {
    success: true,
    data: {
      ...(stats as Record<string, unknown>),
      maxBytes: 20 * 1024 * 1024 * 1024,
      maxAgeDays: 90,
    },
  }, req);
}

async function handleLocalMediaCacheSettings(
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
  readBody: ReadBodyFn,
): Promise<void> {
  const payload = JSON.parse(await readBody(req).catch(() => '{}'));
  const maxGb = Number(payload.maxGb || 20);
  const maxAgeDays = Number(payload.maxAgeDays || 90);
  if (!Number.isFinite(maxGb) || !Number.isFinite(maxAgeDays)) {
    json(res, 400, { success: false, error: 'Invalid media cache settings.' }, req);
    return;
  }
  configureLocalChatMediaCache(maxGb, maxAgeDays);
  json(res, 200, { success: true, data: { maxGb, maxAgeDays } }, req);
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

  const chatbotStore = resolveChatbotStore();
  const enriched = result.conversations.map((conv) => {
    const threadType: 'user' | 'group' =
      conv.threadType === 'group' ? 'group' : 'user';
    const resolved = chatbotStore
      ? chatbotStore.resolveConversationEnabled(
          `${conv.accountId}:${conv.threadId}`,
          threadType,
        )
      : {
          chatbotEnabled: false,
          chatbotMode: null,
          chatbotReason: null,
          chatbotPausedUntil: null,
        };
    // The per-account AI auto-reply switch (settings dialog) hard-gates the Bot
    // toggle: when it's off, the conversation reports disabled regardless of the
    // resolved per-conversation state.
    const accountAiOn = store.isAccountAiAutoReplyEnabled(conv.accountId);
    return {
      ...conv,
      chatbotEnabled: resolved.chatbotEnabled && accountAiOn,
      chatbotMode: resolved.chatbotMode,
      chatbotReason: resolved.chatbotReason,
      chatbotPausedUntil: resolved.chatbotPausedUntil,
    };
  });

  json(res, 200, {
    success: true,
    data: enriched,
    total: result.total,
  }, req);
}

// ---------------------------------------------------------------------------
// PUT /local/conversations/:id
// ---------------------------------------------------------------------------
async function handleLocalUpdateConversation(
  conversationId: string,
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

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(await readBody(req)) as Record<string, unknown>;
  } catch {
    json(res, 400, { success: false, error: 'Invalid JSON body.' }, req);
    return;
  }

  const updated = store.updateConversationMetadata(conversationId, {
    tags: payload.tags,
    notes: payload.notes,
    customAttributes:
      payload.customAttributes ?? payload.customFields ?? payload.attributes,
    archived: payload.archived ?? payload.isArchived,
    assignedTo: payload.assignedTo ?? payload.assigneeId,
    followUpAt: payload.followUpAt ?? payload.snoozedUntil,
  });
  if (!updated) {
    json(res, 404, { success: false, error: 'Conversation not found.' }, req);
    return;
  }

  localChatEvents.publish({
    type: 'conversation.updated',
    accountId: updated.accountId,
    threadId: updated.threadId,
    data: { conversationId: updated.id },
  });
  json(res, 200, { success: true, data: updated }, req);
}

// ---------------------------------------------------------------------------
// GET /local/reporting/conversation-rollup?from=&to=&accountId=
// ---------------------------------------------------------------------------
function handleLocalConversationRollup(
  url: string,
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

  const queryString = url.split('?')[1] || '';
  const params = new URLSearchParams(queryString);
  const data = store.getConversationRollup({
    from: params.get('from') || undefined,
    to: params.get('to') || undefined,
    accountId: params.get('accountId') || undefined,
  });
  json(res, 200, { success: true, data }, req);
}

// ---------------------------------------------------------------------------
// GET/PUT /local/automation/rules
// ---------------------------------------------------------------------------
function handleLocalAutomationRules(
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
  json(res, 200, { success: true, data: store.listAutomationRules() }, req);
}

async function handlePutLocalAutomationRules(
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
  const rawRules = Array.isArray(payload.rules) ? payload.rules : [];
  const rules = rawRules.map((rule: any) => ({
    id: String(rule.id || randomUUID()),
    name: String(rule.name || '').trim(),
    event: String(rule.event || 'Tin nhắn mới').trim(),
    conditionField: String(rule.conditionField || 'Nội dung tin nhắn').trim(),
    conditionOperator: String(rule.conditionOperator || 'chứa').trim(),
    conditionValue: String(rule.conditionValue || '').trim(),
    actions: Array.isArray(rule.actions)
      ? rule.actions.map((item: unknown) => String(item).trim()).filter(Boolean)
      : [],
    enabled: rule.enabled !== false,
    createdAt: String(rule.createdAt || new Date().toISOString()),
  })).filter((rule: any) => rule.name.length > 0);
  json(res, 200, {
    success: true,
    data: store.replaceAutomationRules(rules),
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

  // Check account status against the live pool (in-memory, no `accounts` table).
  if (accountId) {
    const { getAccounts } = await import('../zalo.js');
    const acc = getAccounts().find((a) => a.id === accountId);
    if (acc && acc.status === 'disconnected_expired') {
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
      store.updateMessageStatus(
        localMsgId,
        'sent',
        result.messageId,
        '',
        result.clientMessageId,
      );
      localChatEvents.publish({
        type: 'message.updated',
        accountId,
        threadId: recipientId,
        data: {
          messageId: localMsgId,
          clientMessageId: result.clientMessageId || clientMessageId,
          providerMessageId: result.messageId,
          status: 'sent',
        },
      });
      applyOperatorTakeover(accountId, recipientId, payload.origin);
      json(res, 200, {
        success: true,
        localMessageId: localMsgId,
        providerMessageId: result.messageId,
        clientMessageId: result.clientMessageId,
        attachmentMessageIds: result.attachmentMessageIds,
        data: serializeLocalMessageWithAttachments(store, localMsgId),
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
      store.updateMessageStatus(
        localMsgId,
        'sent',
        result.messageId,
        '',
        result.clientMessageId,
      );
      localChatEvents.publish({
        type: 'message.updated',
        accountId,
        threadId: recipientId,
        data: {
          messageId: localMsgId,
          clientMessageId: result.clientMessageId || clientMessageId,
          providerMessageId: result.messageId,
          status: 'sent',
        },
      });
      applyOperatorTakeover(accountId, recipientId, payload.origin);
      json(res, 200, {
        success: true,
        localMessageId: localMsgId,
        providerMessageId: result.messageId,
        clientMessageId: result.clientMessageId,
        attachmentMessageIds: result.attachmentMessageIds,
        data: serializeLocalMessageWithAttachments(store, localMsgId),
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
        data: serializeLocalMessageWithAttachments(store, localMsgId),
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
      data: serializeLocalMessageWithAttachments(store, localMsgId),
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
      .prepare('SELECT id, accountId, threadId, threadType, providerMessageId, clientMessageId FROM messages WHERE id = ?')
      .get(messageId) as { id: string; accountId: string; threadId: string; threadType: string; providerMessageId: string; clientMessageId: string } | undefined
      ?? store.db
        .prepare('SELECT id, accountId, threadId, threadType, providerMessageId, clientMessageId FROM messages WHERE providerMessageId = ? OR zaloMsgId = ? ORDER BY createdAt DESC LIMIT 1')
        .get(messageId, messageId) as { id: string; accountId: string; threadId: string; threadType: string; providerMessageId: string; clientMessageId: string } | undefined;

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
      const deleted = store.markMessageDeleted(msgRow.id);
      localChatEvents.publish({
        type: 'message.recalled',
        accountId: msgRow.accountId,
        threadId: msgRow.threadId,
        data: {
          messageId: msgRow.id,
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

async function handleLocalDelete(
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
    const msgRow = store.db
      .prepare('SELECT id, accountId, threadId FROM messages WHERE id = ?')
      .get(messageId) as { id: string; accountId: string; threadId: string } | undefined
      ?? store.db
        .prepare('SELECT id, accountId, threadId FROM messages WHERE providerMessageId = ? OR zaloMsgId = ? ORDER BY createdAt DESC LIMIT 1')
        .get(messageId, messageId) as { id: string; accountId: string; threadId: string } | undefined;

    if (!msgRow) {
      json(res, 404, { success: false, error: 'Message not found.' }, req);
      return;
    }

    const deleted = store.deleteMessage(msgRow.id);
    if (deleted) {
      localChatEvents.publish({
        type: 'message.deleted',
        accountId: msgRow.accountId,
        threadId: msgRow.threadId,
        data: {
          messageId: msgRow.id,
        },
      });
      json(res, 200, { success: true }, req);
    } else {
      json(res, 500, { success: false, error: 'Failed to delete message from local store.' }, req);
    }
  } catch (err: any) {
    json(res, 500, { success: false, error: err.message || 'Internal server error during local delete.' }, req);
  }
}

async function handleLocalRetry(
  messageId: string,
  req: IncomingMessage,
  res: ServerResponse,
  json: JsonFn,
): Promise<void> {
  const store = getLocalChatStore();
  const message = store?.getMessage(messageId) ?? (store?.db
    .prepare('SELECT * FROM messages WHERE providerMessageId = ? OR zaloMsgId = ? ORDER BY createdAt DESC LIMIT 1')
    .get(messageId, messageId) as LocalMessage | undefined);
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
    store.updateMessageStatus(
      messageId,
      'sent',
      result.messageId,
      '',
      result.clientMessageId,
    );
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
      clientMessageId: result.clientMessageId,
      status: result.success ? 'sent' : 'failed',
      error: result.error,
    },
  });
  json(res, result.success ? 200 : 500, {
    success: result.success,
    localMessageId: messageId,
    providerMessageId: result.messageId,
    clientMessageId: result.clientMessageId,
    attachmentMessageIds: result.attachmentMessageIds,
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
    cliMsgId: message.clientMessageId || undefined,
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
