/**
 * PersonalZcaChannel — primary channel adapter using zca-js for personal Zalo.
 * Supports multiple concurrent active accounts and automatic round-robin rotation.
 */

import { existsSync, readFileSync, readdirSync, writeFileSync, unlinkSync, mkdirSync } from 'fs';
import { resolve, dirname, basename } from 'path';
import { config, projectRoot } from '../config.js';
import type {
  ZaloChannel,
  ZaloChannelStatus,
  ZaloSendMessageRequest,
  ZaloSendMessageResult,
  ZaloRecallMessageRequest,
  ZaloFriend,
  ZaloGroupMember,
  ZaloAuxiliaryEvent,
  ZaloInboundMessageEvent,
} from './types.js';
import { emitInboundMessage, emitInboundMessages } from './types.js';
import { createProxyAgent, redactProxyUrl } from '../integrations/proxy-helper.js';

// zca-js imports
import { Zalo, ThreadType, FriendEventType } from 'zca-js';
import type { API, Credentials } from 'zca-js';

interface ZaloAccountInstance {
  api: API;
  uId: string;
  label: string;
  listenerRunning: boolean;
  lastEventAt: string | null;
  avatar?: string;
}

interface AccountSettings {
  proxy?: string;
  blockSeen?: boolean;
  blockTyping?: boolean;
}

// Global active accounts pool
export const accountPool = new Map<string, ZaloAccountInstance>();
let loginError: string | null = null;
let poolInitialized = false;

// Undo (message recall) handler — set by the local-chat integration
type UndoMessageHandler = (accountId: string, zaloMsgId: string) => void | Promise<void>;
let _undoMessageHandler: UndoMessageHandler | null = null;

export function setUndoMessageHandler(handler: UndoMessageHandler | null): void {
  _undoMessageHandler = handler;
}

// Status (seen/delivered) handler — set by the local-chat integration
type StatusMessageHandler = (accountId: string, zaloMsgId: string, status: 'seen' | 'delivered') => void | Promise<void>;
let _statusMessageHandler: StatusMessageHandler | null = null;

export function setStatusMessageHandler(handler: StatusMessageHandler | null): void {
  _statusMessageHandler = handler;
}

type AuxiliaryEventHandler = (event: ZaloAuxiliaryEvent) => void | Promise<void>;
let _auxiliaryEventHandler: AuxiliaryEventHandler | null = null;

export function setAuxiliaryEventHandler(
  handler: AuxiliaryEventHandler | null,
): void {
  _auxiliaryEventHandler = handler;
}

async function emitAuxiliaryEvent(
  event: ZaloAuxiliaryEvent | null,
): Promise<void> {
  if (event && _auxiliaryEventHandler) {
    await _auxiliaryEventHandler(event);
  }
}

export function setLoginPoolInitializedForTest(value: boolean): void {
  poolInitialized = value;
  if (value) loginError = null;
}

// Round-robin index selector
let roundRobinIndex = 0;

// Memory Cache for friends and groups to prevent rate limits (429 status code)
interface CacheEntry<T> {
  timestamp: number;
  data: T;
}

const friendsCache = new Map<string, CacheEntry<ZaloFriend[]>>();
const groupsCache = new Map<string, CacheEntry<any[]>>();
const CACHE_TTL_MS = 60 * 1000; // 60 seconds

// Group name cache — short TTL to keep group display names fresh
const groupNameCache = new Map<string, { name: string; timestamp: number }>();
const GROUP_NAME_CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

async function resolveGroupName(api: API, groupId: string): Promise<string> {
  const cached = groupNameCache.get(groupId);
  if (cached && Date.now() - cached.timestamp < GROUP_NAME_CACHE_TTL_MS) {
    return cached.name;
  }
  try {
    const result = await (api as any).getGroupInfo(groupId);
    const info = result?.gridInfoMap?.[groupId];
    const name = info?.name || '';
    if (name) {
      groupNameCache.set(groupId, { name, timestamp: Date.now() });
    }
    return name;
  } catch (err) {
    console.warn(`[PersonalZcaChannel] getGroupInfo failed for ${groupId}:`, err);
    return '';
  }
}

// User Profile Cache to prevent rate limits
interface UserProfile {
  displayName: string;
  avatarUrl: string;
  timestamp: number;
}
const userProfileCache = new Map<string, UserProfile>();
const PROFILE_CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours

async function getOrFetchUserProfile(instance: ZaloAccountInstance, userId: string): Promise<{ displayName: string; avatarUrl: string } | null> {
  const cached = userProfileCache.get(userId);
  const now = Date.now();
  if (cached && (now - cached.timestamp < PROFILE_CACHE_TTL_MS)) {
    return { displayName: cached.displayName, avatarUrl: cached.avatarUrl };
  }

  try {
    console.log(`[PersonalZcaChannel - ${instance.label}] Fetching profile for user ${userId} from API...`);

    // Bypass phonebook version by setting it to 0 temporarily
    const apiCtx = (instance.api as any).getContext ? (instance.api as any).getContext() : null;
    const originalPhonebook = apiCtx?.extraVer?.phonebook;
    if (apiCtx?.extraVer) {
      apiCtx.extraVer.phonebook = 0;
    }

    const res = await instance.api.getUserInfo(userId);

    // Restore original phonebook version
    if (apiCtx?.extraVer && originalPhonebook !== undefined) {
      apiCtx.extraVer.phonebook = originalPhonebook;
    }

    const profiles = res?.changed_profiles || {};
    const profile = profiles[userId] || profiles[`${userId}_0`];
    if (profile) {
      const displayName = profile.displayName || profile.zaloName || '';
      const avatarUrl = normalizeImageUrl(profile.avatar || '');
      userProfileCache.set(userId, { displayName, avatarUrl, timestamp: now });
      return { displayName, avatarUrl };
    }
  } catch (err) {
    console.warn(`[PersonalZcaChannel - ${instance.label}] Failed to fetch user profile for ${userId}:`, err);
  }
  return null;
}

function accountSettingsPath(): string {
  const credPath = resolve(projectRoot, config.personalCredentialsPath);
  return resolve(dirname(credPath), 'account-settings.json');
}

function readAccountSettings(): Record<string, AccountSettings> {
  const filePath = accountSettingsPath();
  if (!existsSync(filePath)) return {};
  try {
    return JSON.parse(readFileSync(filePath, 'utf-8'));
  } catch {
    return {};
  }
}

function writeAccountSettings(settings: Record<string, AccountSettings>): void {
  const filePath = accountSettingsPath();
  mkdirSync(dirname(filePath), { recursive: true });
  writeFileSync(filePath, JSON.stringify(settings, null, 2), 'utf-8');
}

function accountIdFromCredentialsPath(filePath: string): string | undefined {
  const match = basename(filePath).match(/^credentials_(.+)\.json$/);
  return match?.[1];
}

function readPngMetadata(data: Buffer): { width: number; height: number } | null {
  if (
    data.length >= 24 &&
    data[0] === 0x89 &&
    data[1] === 0x50 &&
    data[2] === 0x4e &&
    data[3] === 0x47 &&
    data.toString('ascii', 12, 16) === 'IHDR'
  ) {
    return {
      width: data.readUInt32BE(16),
      height: data.readUInt32BE(20),
    };
  }
  return null;
}

function readGifMetadata(data: Buffer): { width: number; height: number } | null {
  if (
    data.length >= 10 &&
    (data.toString('ascii', 0, 6) === 'GIF87a' ||
      data.toString('ascii', 0, 6) === 'GIF89a')
  ) {
    return {
      width: data.readUInt16LE(6),
      height: data.readUInt16LE(8),
    };
  }
  return null;
}

function readJpegMetadata(data: Buffer): { width: number; height: number } | null {
  if (data.length < 4 || data[0] !== 0xff || data[1] !== 0xd8) return null;
  let offset = 2;
  while (offset + 9 < data.length) {
    if (data[offset] !== 0xff) {
      offset += 1;
      continue;
    }
    const marker = data[offset + 1];
    const segmentLength = data.readUInt16BE(offset + 2);
    if (segmentLength < 2) return null;
    const isSof =
      marker >= 0xc0 &&
      marker <= 0xcf &&
      ![0xc4, 0xc8, 0xcc].includes(marker);
    if (isSof && offset + 8 < data.length) {
      return {
        height: data.readUInt16BE(offset + 5),
        width: data.readUInt16BE(offset + 7),
      };
    }
    offset += 2 + segmentLength;
  }
  return null;
}

function readWebpMetadata(data: Buffer): { width: number; height: number } | null {
  if (
    data.length < 30 ||
    data.toString('ascii', 0, 4) !== 'RIFF' ||
    data.toString('ascii', 8, 12) !== 'WEBP'
  ) {
    return null;
  }
  const chunk = data.toString('ascii', 12, 16);
  if (chunk === 'VP8X' && data.length >= 30) {
    return {
      width: data.readUIntLE(24, 3) + 1,
      height: data.readUIntLE(27, 3) + 1,
    };
  }
  if (chunk === 'VP8 ' && data.length >= 30) {
    return {
      width: data.readUInt16LE(26) & 0x3fff,
      height: data.readUInt16LE(28) & 0x3fff,
    };
  }
  if (chunk === 'VP8L' && data.length >= 25) {
    const bits = data.readUInt32LE(21);
    return {
      width: (bits & 0x3fff) + 1,
      height: ((bits >> 14) & 0x3fff) + 1,
    };
  }
  return null;
}

async function readImageMetadata(filePath: string): Promise<{
  width: number;
  height: number;
  size: number;
}> {
  const data = readFileSync(filePath);
  const dimensions =
    readPngMetadata(data) ||
    readGifMetadata(data) ||
    readJpegMetadata(data) ||
    readWebpMetadata(data);
  if (!dimensions || !dimensions.width || !dimensions.height) {
    throw new Error(`Unsupported image metadata format: ${filePath}`);
  }
  return {
    ...dimensions,
    size: data.length,
  };
}

export const readImageMetadataForTest = readImageMetadata;

export function createZaloClient(accountId?: string): Zalo {
  const settings = accountId ? readAccountSettings()[accountId] : undefined;
  const agent = settings?.proxy ? createProxyAgent(settings.proxy) : undefined;
  if (agent && settings?.proxy) {
    console.log(
      `[PersonalZcaChannel] Using proxy for account ${accountId}: ${redactProxyUrl(settings.proxy)}`,
    );
  }
  return new Zalo({
    selfListen: config.personalSelfListen,
    logging: true,
    imageMetadataGetter: readImageMetadata,
    ...(agent ? { agent } : {}),
  });
}

function toStringValue(value: unknown): string {
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function normalizeTimestamp(value: unknown): string {
  const raw = Number(value ?? Date.now());
  const milliseconds = Number.isFinite(raw)
    ? raw > 100000000000 ? raw : raw * 1000
    : Date.now();
  return new Date(milliseconds).toISOString();
}

function normalizeThread(
  instance: Pick<ZaloAccountInstance, 'uId'>,
  event: any,
): { threadId: string; threadType: 'user' | 'group' } {
  const data = event?.data ?? event ?? {};
  const nested = data?.content && typeof data.content === 'object'
    ? data.content
    : {};
  const rawType = data.threadType ?? event?.threadType ?? event?.type;
  const threadType =
    rawType === ThreadType.Group ||
    data.isGroup === true ||
    Boolean(data.groupId) ||
    String(rawType || '').toLowerCase().includes('group')
      ? 'group'
      : 'user';
  const senderId = toStringValue(
    data.uidFrom ?? data.fromUid ?? data.userId ?? data.uid,
  );
  const candidate = toStringValue(
    data.threadId ??
    event?.threadId ??
    data.groupId ??
    nested.threadId ??
    data.idTo,
  );
  const threadId = threadType === 'user' && candidate === instance.uId
    ? senderId
    : candidate || senderId;
  return { threadId, threadType };
}

function normalizeUndoEvent(
  instance: Pick<ZaloAccountInstance, 'uId'>,
  event: any,
): ZaloAuxiliaryEvent | null {
  const data = event?.data ?? event ?? {};
  const content = data?.content && typeof data.content === 'object'
    ? data.content
    : {};
  const providerMessageId = toStringValue(
    content.globalMsgId ??
    content.msgId ??
    data.globalMsgId ??
    data.msgId ??
    event?.msgId,
  );
  const clientMessageId = toStringValue(
    content.cliMsgId ?? data.cliMsgId ?? event?.cliMsgId,
  );
  const thread = normalizeThread(instance, event);
  if ((!providerMessageId && !clientMessageId) || !thread.threadId) return null;
  return {
    type: 'message.recalled',
    accountId: instance.uId,
    ...thread,
    providerMessageId,
    clientMessageId,
    timestamp: normalizeTimestamp(data.ts ?? event?.ts),
  };
}

function normalizeReceiptEvents(
  instance: Pick<ZaloAccountInstance, 'uId'>,
  status: 'seen' | 'delivered',
  event: any,
): ZaloAuxiliaryEvent[] {
  const data = event?.data ?? event ?? {};
  const thread = normalizeThread(instance, event);
  const ids = [
    ...(Array.isArray(data.msgIds) ? data.msgIds : []),
    ...(Array.isArray(data.messageIds) ? data.messageIds : []),
    data.msgId,
    data.globalMsgId,
    event?.msgId,
  ].map(toStringValue).filter(Boolean);
  const uniqueIds = [...new Set(ids)];
  const userId = toStringValue(
    data.uid ?? data.uidFrom ?? data.userId ?? data.fromUid,
  );
  return uniqueIds.map((providerMessageId) => ({
    type: status === 'seen' ? 'message.seen' : 'message.delivered',
    accountId: instance.uId,
    ...thread,
    providerMessageId,
    userId,
    timestamp: normalizeTimestamp(data.ts ?? event?.ts),
  }));
}

export function normalizeUndoEventForTest(
  instance: Pick<ZaloAccountInstance, 'uId' | 'label'>,
  event: any,
): ZaloAuxiliaryEvent | null {
  return normalizeUndoEvent(instance, event);
}

export function normalizeReceiptEventForTest(
  instance: Pick<ZaloAccountInstance, 'uId' | 'label'>,
  status: 'seen' | 'delivered',
  event: any,
): ZaloAuxiliaryEvent[] {
  return normalizeReceiptEvents(instance, status, event);
}

function normalizeImageUrl(value: unknown): string {
  const url = toStringValue(value).trim();
  if (url.startsWith('//')) return `https:${url}`;
  return url;
}

function hasRichPreviewKeys(value: unknown): boolean {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const data = value as Record<string, unknown>;
  return Boolean(data.href || data.url || data.thumb || data.thumbnail || data.fileUrl || data.fileName);
}

function extractStringFromRecord(value: unknown, keys: string[]): string {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return '';
  const data = value as Record<string, unknown>;
  for (const key of keys) {
    const text = toStringValue(data[key]).trim();
    if (text) return text;
  }
  return '';
}

function stringifyRecord(value: unknown): string {
  if (!value || typeof value !== 'object') return '';
  try {
    return JSON.stringify(value);
  } catch {
    return '';
  }
}

function extractInboundContent(data: Record<string, any>, messageType: ZaloInboundMessageEvent['messageType']): string {
  for (const key of ['content', 'msg', 'message', 'text', 'body']) {
    const direct = toStringValue(data[key]).trim();
    if (direct) return direct;
  }

  for (const key of ['content', 'msg', 'message', 'body', 'attach', 'attachments']) {
    const value = data[key];
    if (!value) continue;
    if (hasRichPreviewKeys(value)) return stringifyRecord(value);

    const nested = extractStringFromRecord(value, [
      'msg',
      'text',
      'message',
      'body',
      'content',
      'title',
      'description',
      'fileName',
      'name',
    ]);
    if (nested) return nested;

    if (messageType !== 'text') {
      const serialized = stringifyRecord(value);
      if (serialized) return serialized;
    }
  }

  return '';
}

function normalizeInboundMessage(instance: ZaloAccountInstance, event: any): ZaloInboundMessageEvent | null {
  const data = event?.data ?? event ?? {};
  const threadTypeValue = data.threadType ?? event?.threadType ?? event?.type;
  const isGroup =
    data.isGroup === true ||
    Boolean(data.groupId) ||
    threadTypeValue === ThreadType.Group ||
    String(threadTypeValue || '').toLowerCase().includes('group');
  const senderId = toStringValue(
    data.uidFrom ?? data.fromUid ?? data.senderId ?? data.fromId ?? data.userId ?? data.authorId,
  );

  // For 1:1 chats, threadId must ALWAYS be the OTHER person's UID.
  // - Inbound (Customer→Operator): senderId = Customer → threadId = Customer
  // - Self-sent (Operator→Customer): senderId = Operator, idTo = Customer → threadId = Customer
  // Previous bug: data.idTo was prioritized, which for inbound msgs = Operator's own ID.
  let threadId: string;
  if (isGroup) {
    threadId = toStringValue(data.threadId ?? event?.threadId ?? data.groupId);
  } else {
    const rawThreadId = toStringValue(data.threadId);
    if (rawThreadId && rawThreadId !== instance.uId) {
      // data.threadId is present and NOT our own ID → trust it
      threadId = rawThreadId;
    } else if (senderId && senderId !== instance.uId) {
      // Inbound message from someone else → use their ID as thread
      threadId = senderId;
    } else {
      // Self-sent message → recipient (idTo) is the other person
      threadId = toStringValue(data.idTo ?? data.toId) || senderId;
    }
  }
  if (!senderId || !threadId) return null;

  const rawType = String(data.msgType ?? data.type ?? '').toLowerCase();
  const richContent = hasRichPreviewKeys(data.content) ||
    hasRichPreviewKeys(data.attach) ||
    hasRichPreviewKeys(data.attachments);
  const messageType: ZaloInboundMessageEvent['messageType'] =
    rawType.includes('photo') || rawType.includes('image')
      ? 'image'
      : rawType.includes('file') || rawType.includes('doc')
        ? 'file'
        : rawType.includes('sticker')
          ? 'sticker'
          : rawType.includes('video')
            ? 'video'
            : rawType.includes('voice') || rawType.includes('audio')
              ? 'voice'
              : rawType.includes('gif')
                ? 'gif'
                : rawType.includes('location')
                  ? 'location'
              : rawType.includes('contact')
                    ? 'contact_card'
                    : rawType.includes('reminder')
                      ? 'reminder'
                      : rawType.includes('poll')
                        ? 'poll'
                        : rawType.includes('system') ||
                            rawType.includes('pin')
                          ? 'system'
                    : richContent
                      ? 'link'
                      : 'text';
  let content = extractInboundContent(data, messageType);
  if (!content) content = `[${messageType}]`;

  const timestamp = normalizeTimestamp(
    data.ts ?? data.timestamp ?? data.time,
  );

  // Try to find the sender's avatar from event data
  let avatarUrl = normalizeImageUrl(data.avatar || data.avt || data.avatarUrl || data.senderAvatar || '');
  let senderName = toStringValue(data.dName ?? data.displayName ?? data.senderName ?? data.fromName);

  if (senderId === instance.uId) {
    if (!avatarUrl) {
      avatarUrl = instance.avatar || '';
    }
    if (!senderName) {
      senderName = instance.label.replace(/\s*\([^)]*\)$/, '');
    }
  } else if (!avatarUrl && senderId) {
    const cached = friendsCache.get(instance.uId);
    if (cached?.data) {
      const friend = cached.data.find((f) => f.userId === senderId);
      if (friend?.avatar) {
        avatarUrl = normalizeImageUrl(friend.avatar);
      }
    }
  }

  return {
    accountId: instance.uId,
    accountLabel: instance.label,
    threadId,
    threadType: isGroup ? 'group' as const : 'user' as const,
    senderId,
    senderName,
    avatarUrl,
    senderAvatarUrl: avatarUrl, // per-sender avatar for group chat display
    content,
    messageType,
    providerMessageId: toStringValue(
      data.msgId ?? data.globalMsgId ?? data.messageId ?? data.id,
    ) || `zca_${instance.uId}_${threadId}_${Date.parse(timestamp)}`,
    clientMessageId: toStringValue(data.cliMsgId),
    quote: data.quote,
    mentions: Array.isArray(data.mentions) ? data.mentions : [],
    styles: Array.isArray(data.styles) ? data.styles : [],
    metadata: {
      ...(typeof data.metadata === 'object' ? data.metadata : {}),
      rawType,
      ...(messageType === 'system' ||
      messageType === 'poll' ||
      messageType === 'reminder'
        ? { systemPayload: data }
        : {}),
    },
    timestamp,
  };
}

function normalizeNumericMessageId(value: unknown, fallback: string): string {
  const raw = toStringValue(value).trim();
  if (/^\d+$/.test(raw)) return raw;
  return fallback;
}

function normalizeQuoteForZca(
  quote: Record<string, unknown> | undefined,
): Record<string, unknown> | undefined {
  if (!quote || Object.keys(quote).length === 0) return undefined;
  const msgId = toStringValue(
    quote.msgId ??
      quote.messageId ??
      quote.providerMessageId ??
      quote.zaloMsgId,
  ).trim();
  if (!msgId) return undefined;
  const content = quote.content ?? quote.message ?? quote.text ?? '';
  const tsRaw = Number(quote.ts ?? quote.timestamp ?? Date.now());
  return {
    content: typeof content === 'string' ? content : stringifyRecord(content),
    msgType: toStringValue(
      quote.msgType ?? quote.messageType ?? quote.contentType,
    ) || 'webchat',
    propertyExt: quote.propertyExt ?? '',
    uidFrom: toStringValue(quote.uidFrom ?? quote.senderId),
    msgId,
    cliMsgId: normalizeNumericMessageId(
      quote.cliMsgId ?? quote.clientMessageId,
      msgId,
    ),
    ts: Number.isFinite(tsRaw) ? tsRaw : Date.now(),
    ttl: Number(quote.ttl ?? 0),
  };
}

function normalizeZcaReaction(reaction: string): string {
  const trimmed = reaction.trim();
  const lower = trimmed.toLowerCase();
  const normalized = lower.replace(/[_\s-]+/g, '');
  const map: Record<string, string> = {
    heart: '/-heart',
    love: '/-heart',
    yeuthich: '/-heart',
    favourite: '/-heart',
    favorite: '/-heart',
    '❤️': '/-heart',
    '❤': '/-heart',
    '/-heart': '/-heart',
    like: '/-strong',
    thumbsup: '/-strong',
    strong: '/-strong',
    '👍': '/-strong',
    '/-strong': '/-strong',
    haha: ':>',
    laugh: ':>',
    wow: ':o',
    cry: ':-((',
    sad: '--b',
    angry: ':-h',
    none: '',
    cancel: '',
    remove: '',
    '': '',
  };
  return map[normalized] ?? map[lower] ?? trimmed;
}

export const normalizeZcaReactionForTest = normalizeZcaReaction;

export function normalizeInboundMessageForTest(
  instance: Pick<ZaloAccountInstance, 'uId' | 'label'>,
  event: any,
): ZaloInboundMessageEvent | null {
  return normalizeInboundMessage(
    {
      api: {} as API,
      listenerRunning: false,
      lastEventAt: null,
      ...instance,
    },
    event,
  );
}

// Export the active account pool loader so server.ts can call it
export async function ensureLoginPool(): Promise<void> {
  if (poolInitialized) return;

  const credPath = resolve(projectRoot, config.personalCredentialsPath);
  const credDir = dirname(credPath);

  if (!existsSync(credDir)) {
    mkdirSync(credDir, { recursive: true });
    console.log(`[PersonalZcaChannel] Created credentials directory: ${credDir}`);
  }

  console.log(`[PersonalZcaChannel] Scanning for credentials in ${credDir}...`);
  try {
    const files = readdirSync(credDir);
    const credFiles = files.filter(f => f.startsWith('credentials') && f.endsWith('.json'));

    if (credFiles.length === 0) {
      console.log('[PersonalZcaChannel] No accounts found. Use the CLI login or UI to bootstrap.');
      loginError = 'No credentials found.';
    }

    for (const file of credFiles) {
      const filePath = resolve(credDir, file);
      await loadCredentialsFile(filePath);
    }

    poolInitialized = true;
    loginError = null;
  } catch (err) {
    loginError = `Failed to scan credentials directory: ${err instanceof Error ? err.message : String(err)}`;
    console.error('[PersonalZcaChannel] Scan error:', err);
  }
}

// Add account dynamically (e.g. after QR login)
export async function addAccountInstance(uId: string, apiInstance: API): Promise<void> {
  let label = `${config.personalAccountLabel} (${uId})`;
  let avatar = '';
  try {
    const info = await apiInstance.fetchAccountInfo();
    const displayName = info?.profile?.displayName;
    avatar = normalizeImageUrl(info?.profile?.avatar || '');
    if (displayName) {
      label = `${displayName} (${uId})`;
    }
  } catch (err) {
    console.error(`[PersonalZcaChannel] Failed to fetch account display name:`, err);
  }

  const instance: ZaloAccountInstance = {
    api: apiInstance,
    uId,
    label,
    listenerRunning: false,
    lastEventAt: null,
    avatar,
  };

  accountPool.set(uId, instance);
  console.log(`[PersonalZcaChannel] Dynamically added new account to pool: ${label}`);
  
  // Auto start listener
  await startListenerForInstance(instance);
}

async function loadCredentialsFile(filePath: string): Promise<void> {
  try {
    const raw = readFileSync(filePath, 'utf-8');
    const credentials: Credentials = JSON.parse(raw);

    const accountId = accountIdFromCredentialsPath(filePath);
    const zalo = createZaloClient(accountId);

    const activeApi = await zalo.login(credentials);
    const uId = activeApi.getOwnId ? activeApi.getOwnId() : `personal_${Date.now()}`;
    
    // Add to pool
    await addAccountInstance(uId, activeApi);
  } catch (err) {
    console.error(`[PersonalZcaChannel] Failed to load credentials from ${filePath}:`, err);
  }
}

async function startListenerForInstance(instance: ZaloAccountInstance): Promise<void> {
  if (instance.listenerRunning) return;
  try {
    const listener = instance.api.listener;
    if (listener) {
      listener.removeAllListeners("friend_event");
      listener.removeAllListeners("message");
      listener.removeAllListeners("undo");
      listener.removeAllListeners("group_event");
      listener.removeAllListeners("seen");
      listener.removeAllListeners("seen_messages");
      listener.removeAllListeners("delivered_messages");
      listener.removeAllListeners("typing");
      listener.removeAllListeners("reaction");
      listener.removeAllListeners("message_deleted");
      listener.removeAllListeners("delete");

      listener.on("friend_event", async (event: any) => {
        instance.lastEventAt = new Date().toISOString();
        console.log(`[PersonalZcaChannel - ${instance.label}] Event friend_event received:`, JSON.stringify(event));
        await emitAuxiliaryEvent({
          type: 'friend.updated',
          accountId: instance.uId,
          threadId: toStringValue(event?.data?.fromUid ?? event?.data?.userId),
          threadType: 'user',
          userId: toStringValue(event?.data?.fromUid ?? event?.data?.userId),
          timestamp: normalizeTimestamp(event?.data?.ts ?? event?.ts),
          data: event?.data ?? {},
        });

        if (event.type === FriendEventType.REQUEST && !event.isSelf) {
          const senderId = event.data?.fromUid;
          const message = event.data?.message || '';
          console.log(`[PersonalZcaChannel - ${instance.label}] Friend request from ${senderId}: "${message}"`);

          if (config.allowFriendAutomation) {
            console.log(`[PersonalZcaChannel - ${instance.label}] Auto-approving friend request for ${senderId}...`);
            try {
              await instance.api.acceptFriendRequest(senderId);
              console.log(`[PersonalZcaChannel - ${instance.label}] Successfully approved friend request for ${senderId}`);
            } catch (acceptErr) {
              console.error(`[PersonalZcaChannel - ${instance.label}] Failed to auto-approve friend for ${senderId}:`, acceptErr);
            }
          } else {
            console.log(`[PersonalZcaChannel - ${instance.label}] Auto-approval is disabled (allowFriendAutomation=false).`);
          }
        }
      });

      // ── Undo (message recall) event ──
      listener.on("undo", async (data: any) => {
        instance.lastEventAt = new Date().toISOString();
        const event = normalizeUndoEvent(instance, data);
        if (event) {
          console.log(`[PersonalZcaChannel - ${instance.label}] Undo event for msgId: ${event.providerMessageId || event.clientMessageId}`);
          await emitAuxiliaryEvent(event);
          if (_undoMessageHandler && event.providerMessageId) {
            await _undoMessageHandler(instance.uId, event.providerMessageId);
          }
        }
      });

      const handleDelete = async (data: any): Promise<void> => {
        instance.lastEventAt = new Date().toISOString();
        const recalled = normalizeUndoEvent(instance, data);
        if (recalled) {
          await emitAuxiliaryEvent({
            ...recalled,
            type: 'message.deleted',
          });
        }
      };
      listener.on("message_deleted", handleDelete);
      listener.on("delete", handleDelete);

      // ── Group events (member add/remove, rename) ──
      listener.on("group_event", async (event: any) => {
        instance.lastEventAt = new Date().toISOString();
        const groupId = event?.data?.groupId ?? event?.threadId ?? '';
        const subType = event?.data?.updateType ?? event?.subType ?? '';
        console.log(
          `[PersonalZcaChannel - ${instance.label}] Group event: groupId=${groupId}, subType=${subType}`,
          JSON.stringify(event).substring(0, 300),
        );
        // Invalidate group name cache on rename/update events
        if (groupId) {
          groupNameCache.delete(groupId);
          groupsCache.delete(instance.uId);
        }
        await emitAuxiliaryEvent({
          type: 'group.updated',
          accountId: instance.uId,
          threadId: toStringValue(groupId),
          threadType: 'group',
          timestamp: normalizeTimestamp(event?.data?.ts ?? event?.ts),
          data: event?.data ?? {},
        });
      });

      // ── Seen, Delivered, Typing events ──
      const handleReceipt = async (
        status: 'seen' | 'delivered',
        data: any,
      ): Promise<void> => {
        instance.lastEventAt = new Date().toISOString();
        for (const event of normalizeReceiptEvents(instance, status, data)) {
          await emitAuxiliaryEvent(event);
          if (_statusMessageHandler && event.providerMessageId) {
            await _statusMessageHandler(
              instance.uId,
              event.providerMessageId,
              status,
            );
          }
        }
      };
      listener.on("seen", (data: any) => handleReceipt('seen', data));
      listener.on("seen_messages", (data: any) => handleReceipt('seen', data));
      listener.on("delivered_messages", (data: any) => handleReceipt('delivered', data));

      listener.on("typing", async (data: any) => {
        instance.lastEventAt = new Date().toISOString();
        const payload = data?.data ?? data ?? {};
        const thread = normalizeThread(instance, data);
        const threadId = thread.threadId;
        const isTyping = data?.data?.isTyping ?? data?.isTyping;
        console.log(`[PersonalZcaChannel - ${instance.label}] Typing event in threadId: ${threadId}, isTyping: ${isTyping}`);
        await emitAuxiliaryEvent({
          type: isTyping === false ? 'typing.stopped' : 'typing.started',
          accountId: instance.uId,
          ...thread,
          userId: toStringValue(payload.uidFrom ?? payload.userId),
          timestamp: normalizeTimestamp(payload.ts),
        });
      });

      listener.on("reaction", async (data: any) => {
        const payload = data?.data ?? data ?? {};
        const thread = normalizeThread(instance, data);
        await emitAuxiliaryEvent({
          type: 'message.reaction',
          accountId: instance.uId,
          ...thread,
          providerMessageId: toStringValue(
            payload.msgId ?? payload.globalMsgId,
          ),
          userId: toStringValue(payload.uidFrom ?? payload.userId),
          reaction: toStringValue(
            payload.reaction ?? payload.reactionType ?? payload.icon,
          ),
          timestamp: normalizeTimestamp(payload.ts),
          data: payload,
        });
      });

      listener.on("old_messages", async (event: any) => {
        instance.lastEventAt = new Date().toISOString();
        const msgs = event?.data?.msgs ?? event?.messages ?? [];
        console.log(`[PersonalZcaChannel - ${instance.label}] Received ${msgs.length} old messages.`);
        const batch: ZaloInboundMessageEvent[] = [];
        for (const msg of msgs) {
          try {
            const inbound = normalizeInboundMessage(instance, msg);
            if (!inbound) continue;
            
            if (inbound.senderId && (!inbound.avatarUrl || !inbound.senderName)) {
               const profile = await getOrFetchUserProfile(instance, inbound.senderId);
               if (profile) {
                 inbound.avatarUrl = profile.avatarUrl;
                 inbound.senderAvatarUrl = profile.avatarUrl;
                 inbound.senderName = inbound.senderName || profile.displayName;
               }
            }
            if (inbound.threadType === 'group' && inbound.threadId) {
               const groupName = await resolveGroupName(instance.api, inbound.threadId);
               if (groupName) inbound.groupName = groupName;
            }
            batch.push(inbound);
          } catch (err) {
            console.error(`[PersonalZcaChannel - ${instance.label}] Error processing old message:`, err);
          }
        }
        await emitInboundMessages(batch);
      });

      listener.on("message", async (event: any) => {
        instance.lastEventAt = new Date().toISOString();
        const inbound = normalizeInboundMessage(instance, event);
        if (!inbound) return;

        // Fetch missing sender avatar or display name from API
        if (inbound.senderId && (!inbound.avatarUrl || !inbound.senderName)) {
          const profile = await getOrFetchUserProfile(instance, inbound.senderId);
          if (profile) {
            inbound.avatarUrl = profile.avatarUrl;
            inbound.senderAvatarUrl = profile.avatarUrl;
            if (!inbound.senderName) {
              inbound.senderName = profile.displayName;
            }
          }
        }

        // Resolve group display name for group threads
        if (inbound.threadType === 'group' && inbound.threadId) {
          const groupName = await resolveGroupName(instance.api, inbound.threadId);
          if (groupName) {
            inbound.groupName = groupName;
          }
        }

        console.log(
          `[PersonalZcaChannel - ${instance.label}] Message event from ${inbound.senderId} (${inbound.messageType}, ${inbound.content.length} chars)${inbound.groupName ? ` in group "${inbound.groupName}"` : ''}.`,
        );
        await emitInboundMessage(inbound);
      });

      // ── Connection closed (e.g. Kicked from phone or Duplicate Login) ──
      listener.on("closed", async (code: number, reason: string) => {
        console.warn(`[PersonalZcaChannel - ${instance.label}] Listener closed. Code: ${code}, Reason: ${reason}`);
        if (code === 3000 || code === 3003) { // 3000: Duplicate, 3003: Kicked
          console.error(`[PersonalZcaChannel - ${instance.label}] Kicked by server or duplicate login. Marking as disconnected.`);

          instance.listenerRunning = false;

          // Import local chat store to update DB
          try {
            const { getLocalChatStore } = await import('../local-chat/index.js');
            const store = getLocalChatStore();
            if (store) {
              store.db.prepare('UPDATE accounts SET status = ? WHERE id = ?').run('DISCONNECTED_EXPIRED', instance.uId);
            }
          } catch (e) {
            console.error('Failed to update account status in DB:', e);
          }

          await stopListenerForInstance(instance);
        }
      });

      listener.start();
      instance.listenerRunning = true;
      console.log(`[PersonalZcaChannel - ${instance.label}] Realtime listener started.`);
    }
  } catch (err) {
    console.error(`[PersonalZcaChannel - ${instance.label}] Failed to start realtime listener:`, err);
  }
}

async function stopListenerForInstance(instance: ZaloAccountInstance): Promise<void> {
  if (!instance.listenerRunning) return;
  try {
    const listener = instance.api.listener;
    if (listener) {
      listener.stop();
      listener.removeAllListeners("friend_event");
      listener.removeAllListeners("message");
      listener.removeAllListeners("undo");
      listener.removeAllListeners("group_event");
      listener.removeAllListeners("seen");
      listener.removeAllListeners("seen_messages");
      listener.removeAllListeners("delivered_messages");
      listener.removeAllListeners("typing");
      listener.removeAllListeners("reaction");
      listener.removeAllListeners("message_deleted");
      listener.removeAllListeners("delete");
      instance.listenerRunning = false;
      console.log(`[PersonalZcaChannel - ${instance.label}] Realtime listener stopped.`);
    }
  } catch (err) {
    console.error(`[PersonalZcaChannel - ${instance.label}] Failed to stop realtime listener:`, err);
  }
}

export class PersonalZcaChannel implements ZaloChannel {
  getStatus(): ZaloChannelStatus {
    const connected = accountPool.size > 0;
    const connectedAccounts = Array.from(accountPool.values());
    const label = connected
      ? `${accountPool.size} tài khoản Zalo cá nhân`
      : 'Chưa liên kết tài khoản nào';

    const listenerRunning = connectedAccounts.some(acc => acc.listenerRunning);
    const lastEventAt = connectedAccounts.reduce<string | null>((latest, acc) => {
      if (!acc.lastEventAt) return latest;
      if (!latest) return acc.lastEventAt;
      return new Date(acc.lastEventAt) > new Date(latest) ? acc.lastEventAt : latest;
    }, null);

    return {
      connected,
      mode: 'personal_zca',
      accountType: 'personal',
      accountLabel: label,
      listenerRunning,
      lastEventAt,
    };
  }

  async sendMessage(
    req: ZaloSendMessageRequest,
    isTestMode = false,
  ): Promise<ZaloSendMessageResult> {
    if (isTestMode) {
      return { success: true, messageId: `test_personal_${Date.now()}` };
    }

    try {
      await ensureLoginPool();

      if (accountPool.size === 0) {
        throw new Error('No active connected Zalo accounts in the pool.');
      }

      // Dynamic Round-Robin rotation selector, unless CRM requested a sender account.
      const instances = Array.from(accountPool.values());
      let selectedInstance = req.accountId ? accountPool.get(req.accountId) : undefined;
      if (!selectedInstance && req.accountId) {
        throw new Error(`Requested Zalo account ${req.accountId} is not connected.`);
      }
      if (!selectedInstance) {
        selectedInstance = instances[roundRobinIndex % instances.length];
        roundRobinIndex++;
      }

      console.log(`[PersonalZcaChannel] Selected sender account: ${selectedInstance.label}`);

      const recipientId = String(req.recipientId || '').trim();
      const messageText = String(req.message || '').trim();
      const attachments = (req.attachments || []).filter((item) =>
        String(item || '').trim(),
      );
      if (!recipientId || (!messageText && attachments.length === 0)) {
        throw new Error('Missing recipientId or message/attachments.');
      }

      const threadType =
        req.threadType === 'group' ? ThreadType.Group : ThreadType.User;

      const hasAttachments = attachments.length > 0;
      console.log(`[PersonalZcaChannel] sendMessage params: recipientId=${recipientId}, threadType=${req.threadType}(${threadType}), message="${messageText.substring(0, 50)}", attachments=${hasAttachments ? attachments.length : 0}`);

      // Build the richest payload supported by the installed zca-js version.
      const quote = normalizeQuoteForZca(req.quote);
      const messageContent: any = {
        msg: messageText,
        ...(req.clientMessageId ? { cliMsgId: req.clientMessageId } : {}),
        ...(quote ? { quote } : {}),
        ...(req.mentions ? { mentions: req.mentions } : {}),
        ...(req.styles ? { styles: req.styles } : {}),
      };
      if (hasAttachments) {
        messageContent.attachments = attachments;
      }

      const api = selectedInstance.api as any;
      let result: any;
      if (req.messageType === 'sticker' && req.sticker && api.sendSticker) {
        result = await api.sendSticker(req.sticker, recipientId, threadType);
      } else if (req.messageType === 'link' && req.link && api.sendLink) {
        result = await api.sendLink(req.link, recipientId, threadType);
      } else if (req.messageType === 'video' && req.video && api.sendVideo) {
        result = await api.sendVideo(req.video, recipientId, threadType);
      } else if (req.messageType === 'voice' && req.voice && api.sendVoice) {
        result = await api.sendVoice(req.voice, recipientId, threadType);
      } else {
        result = await selectedInstance.api.sendMessage(
          messageContent,
          recipientId,
          threadType,
        );
      }

      // zca-js sendMessage returns { message: SendMessageResult | null, attachment: SendMessageResult[] }
      const msgResult = (result as any)?.message ?? result;
      const msgId = msgResult?.msgId ?? (result as any)?.msgId ?? `personal_${Date.now()}`;

      console.log(`[PersonalZcaChannel] sendMessage result:`, JSON.stringify(result)?.substring(0, 200));

      return {
        success: true,
        messageId: msgId,
      };
    } catch (err) {
      console.error(`[PersonalZcaChannel] sendMessage error:`, err);
      const errAny = err as any;
      const code = errAny?.code ?? errAny?.data?.code ?? errAny?.details?.code;
      const message = loginError || (err instanceof Error ? err.message : 'Unknown personal send error');
      return {
        success: false,
        error: code ? `${message} (code: ${code})` : message,
      };
    }
  }

  async recallMessage(req: ZaloRecallMessageRequest): Promise<{ success: boolean; error?: string }> {
    try {
      await ensureLoginPool();
      if (accountPool.size === 0) {
        throw new Error('No active connected Zalo accounts in the pool.');
      }

      const instances = Array.from(accountPool.values());
      let selectedInstance = req.accountId ? accountPool.get(req.accountId) : undefined;
      if (!selectedInstance && req.accountId) {
        throw new Error(`Requested Zalo account ${req.accountId} is not connected.`);
      }
      if (!selectedInstance) {
        selectedInstance = instances[0];
      }

      console.log(`[PersonalZcaChannel] recallMessage: msgId=${req.msgId}, threadId=${req.threadId}`);

      const threadType = req.threadType === 'group' ? ThreadType.Group : ThreadType.User;
      const msgId = String(req.msgId || '').trim();
      const cliMsgId = normalizeNumericMessageId(req.cliMsgId, msgId);
      const api = selectedInstance.api as any;
      if (api.undo) {
        await api.undo({ msgId, cliMsgId }, req.threadId, threadType);
      } else if (api.undoMessage) {
        await api.undoMessage(
          {
            msgId,
            cliMsgId,
            msgType: 1,
            uidFrom: selectedInstance.uId,
            idTo: req.threadId,
          },
          req.threadId,
          threadType,
        );
      } else {
        throw new Error('Recall is not supported by the installed zca-js version.');
      }

      console.log(`[PersonalZcaChannel] recallMessage success`);
      return { success: true };
    } catch (err) {
      console.error(`[PersonalZcaChannel] recallMessage error:`, err);
      return {
        success: false,
        error: err instanceof Error ? err.message : 'Unknown recall error',
      };
    }
  }

  async sendTyping(
    accountId: string,
    threadId: string,
    threadType: 'user' | 'group',
  ): Promise<boolean> {
    await ensureLoginPool();
    const instance = accountPool.get(accountId);
    const api = instance?.api as any;
    if (!api?.sendTypingEvent) return false;
    await api.sendTypingEvent(
      threadId,
      threadType === 'group' ? ThreadType.Group : ThreadType.User,
    );
    return true;
  }

  async reactMessage(request: {
    accountId: string;
    threadId: string;
    threadType: 'user' | 'group';
    msgId: string;
    reaction: string;
  }): Promise<{ success: boolean; error?: string }> {
    try {
      await ensureLoginPool();
      const instance = accountPool.get(request.accountId);
      const api = instance?.api as any;
      if (!api) throw new Error('Zalo account is not connected.');
      const threadType = request.threadType === 'group'
        ? ThreadType.Group
        : ThreadType.User;
      const reaction = normalizeZcaReaction(request.reaction);
      const msgId = String(request.msgId || '').trim();
      const cliMsgId = normalizeNumericMessageId(
        (request as { cliMsgId?: string }).cliMsgId,
        msgId,
      );
      if (api.addReaction) {
        await api.addReaction(
          reaction,
          {
            data: {
              msgId,
              cliMsgId,
            },
            threadId: request.threadId,
            type: threadType,
          },
        );
      } else if (api.sendReaction) {
        await api.sendReaction(
          reaction,
          msgId,
          request.threadId,
          threadType,
        );
      } else {
        throw new Error('Reaction is not supported by the installed zca-js version.');
      }
      return { success: true };
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Reaction failed.',
      };
    }
  }

  handleWebhookEvent(event: Record<string, unknown>): void {
    const eventName = event['event_name'] as string | undefined;
    console.log(
      `[PersonalZcaChannel Webhook] Event: ${eventName || 'unknown'}`,
      JSON.stringify(event).slice(0, 200),
    );
  }

  async startListener(): Promise<void> {
    await ensureLoginPool();
    for (const instance of accountPool.values()) {
      await startListenerForInstance(instance);
    }
  }

  async stopListener(): Promise<void> {
    for (const instance of accountPool.values()) {
      await stopListenerForInstance(instance);
    }
  }

  async getAllGroups(): Promise<any[]> {
    try {
      await ensureLoginPool();
      if (accountPool.size === 0) return [];

      const allGroups: any[] = [];
      const now = Date.now();

      for (const instance of accountPool.values()) {
        try {
          const cached = groupsCache.get(instance.uId);
          let instanceGroups: any[];

          if (cached && (now - cached.timestamp < CACHE_TTL_MS)) {
            console.log(`[PersonalZcaChannel - ${instance.label}] Using cached group list (${cached.data.length} groups, age: ${Math.round((now - cached.timestamp) / 1000)}s).`);
            instanceGroups = cached.data;
          } else {
            console.log(`[PersonalZcaChannel - ${instance.label}] Fetching group list from API...`);
            const groupsData = await instance.api.getAllGroups();
            const groupIds = Object.keys(groupsData.gridVerMap || {});
            
            if (groupIds.length === 0) {
              instanceGroups = [];
            } else {
              console.log(`[PersonalZcaChannel - ${instance.label}] Fetching details for ${groupIds.length} groups from API...`);
              const infoData = await instance.api.getGroupInfo(groupIds);
              const gridInfoMap = infoData.gridInfoMap || {};
              const myUid = instance.uId;

              instanceGroups = groupIds.map((id) => {
                const info = gridInfoMap[id] || {};
                const role = info.creatorId === myUid ? 'Trưởng nhóm' : 'Thành viên';
                return {
                  id,
                  name: `[${instance.uId.slice(-4)}] ${info.name || 'Nhóm không tên'}`,
                  memberCount: info.totalMember || (info.memberIds ? info.memberIds.length : 0) || 0,
                  role,
                  avatar: info.fullAvt || info.avt || '',
                  accountId: instance.uId,
                };
              });
            }

            // Update cache
            groupsCache.set(instance.uId, {
              timestamp: now,
              data: instanceGroups,
            });
            console.log(`[PersonalZcaChannel - ${instance.label}] Fetched and cached ${instanceGroups.length} groups.`);
          }

          allGroups.push(...instanceGroups);
        } catch (err) {
          console.error(`[PersonalZcaChannel - ${instance.label}] Failed to fetch groups:`, err);
          // Fall back to stale cache if available
          const cached = groupsCache.get(instance.uId);
          if (cached) {
            console.log(`[PersonalZcaChannel - ${instance.label}] Falling back to stale cached group list.`);
            allGroups.push(...cached.data);
          }
        }
      }

      return allGroups;
    } catch (err) {
      console.error('[PersonalZcaChannel] Failed to get Zalo groups:', err);
      return [];
    }
  }

  async leaveGroup(groupId: string, silent = false, accountId?: string): Promise<boolean> {
    try {
      await ensureLoginPool();
      if (accountPool.size === 0) return false;

      if (accountId) {
        const instance = accountPool.get(accountId);
        if (instance) {
          try {
            console.log(`[PersonalZcaChannel - ${instance.label}] Attempting to leave group ${groupId}...`);
            await instance.api.leaveGroup(groupId, silent);
            console.log(`[PersonalZcaChannel - ${instance.label}] Successfully left group ${groupId}`);
            groupsCache.delete(instance.uId);
            return true;
          } catch (err) {
            console.error(`[PersonalZcaChannel - ${instance.label}] Failed to leave group ${groupId}:`, err);
            return false;
          }
        }
      }

      let leftAny = false;
      for (const instance of accountPool.values()) {
        try {
          console.log(`[PersonalZcaChannel - ${instance.label}] Attempting to leave group ${groupId}...`);
          await instance.api.leaveGroup(groupId, silent);
          console.log(`[PersonalZcaChannel - ${instance.label}] Successfully left group ${groupId}`);
          leftAny = true;
          // Invalidate groups cache
          groupsCache.delete(instance.uId);
        } catch (err) {
          // Continue to next instance in case it was not owned by this account
        }
      }
      return leftAny;
    } catch (err) {
      console.error(`[PersonalZcaChannel] Failed to leave group ${groupId}:`, err);
      return false;
    }
  }

  getAccounts(): any[] {
    const settingsByAccount = readAccountSettings();
    return Array.from(accountPool.values()).map(acc => ({
      id: acc.uId,
      label: acc.label,
      connected: true,
      listenerRunning: acc.listenerRunning,
      avatar: acc.avatar || '',
      settings: settingsByAccount[acc.uId] || {},
    }));
  }

  async updateAccountSettings(accountId: string, settings: Record<string, unknown>): Promise<boolean> {
    if (!accountPool.has(accountId)) return false;
    const current = readAccountSettings();
    current[accountId] = {
      proxy: typeof settings.proxy === 'string' ? settings.proxy.trim() : '',
      blockSeen: settings.blockSeen === true,
      blockTyping: settings.blockTyping === true,
    };
    writeAccountSettings(current);
    console.log(`[PersonalZcaChannel] Updated local settings for account ${accountId}.`);
    return true;
  }

  async deleteAccount(accountId: string): Promise<boolean> {
    const instance = accountPool.get(accountId);
    if (!instance) return false;

    try {
      await stopListenerForInstance(instance);
      accountPool.delete(accountId);

      // Invalidate caches
      friendsCache.delete(accountId);
      groupsCache.delete(accountId);

      const credPath = resolve(projectRoot, config.personalCredentialsPath);
      const credDir = dirname(credPath);
      
      const filePaths = [
        resolve(credDir, `credentials_${accountId}.json`),
        resolve(credDir, `credentials.json`), // Delete backward compatibility files too
      ];

      for (const filePath of filePaths) {
        if (existsSync(filePath)) {
          unlinkSync(filePath);
        }
      }

      const settingsByAccount = readAccountSettings();
      delete settingsByAccount[accountId];
      writeAccountSettings(settingsByAccount);

      console.log(`[PersonalZcaChannel] Successfully unlinked Zalo account: ${accountId}`);
      return true;
    } catch (err) {
      console.error(`[PersonalZcaChannel] Failed to unlink account ${accountId}:`, err);
      return false;
    }
  }

  async getAllFriends(accountId?: string): Promise<ZaloFriend[]> {
    try {
      await ensureLoginPool();
      if (accountPool.size === 0) return [];

      const allFriends: ZaloFriend[] = [];
      const seenIds = new Set<string>();
      const now = Date.now();
      
      const targetInstances = accountId && accountPool.has(accountId) 
        ? [accountPool.get(accountId)!] 
        : Array.from(accountPool.values());

      for (const instance of targetInstances) {
        try {
          const cached = friendsCache.get(instance.uId);
          let friends: ZaloFriend[];

          if (cached && (now - cached.timestamp < CACHE_TTL_MS)) {
            console.log(`[PersonalZcaChannel - ${instance.label}] Using cached friend list (${cached.data.length} friends, age: ${Math.round((now - cached.timestamp) / 1000)}s).`);
            friends = cached.data;
          } else {
            console.log(`[PersonalZcaChannel - ${instance.label}] Fetching friend list from API...`);
            const rawFriends = await instance.api.getAllFriends();
            friends = rawFriends.map((f) => ({
              userId: f.userId,
              displayName: f.displayName || f.zaloName || '',
              zaloName: f.zaloName || '',
              avatar: f.avatar || '',
              phoneNumber: f.phoneNumber || '',
              isFriend: true,
            }));
            
            // Update cache
            friendsCache.set(instance.uId, {
              timestamp: now,
              data: friends,
            });
            console.log(`[PersonalZcaChannel - ${instance.label}] Fetched and cached ${friends.length} friends.`);
          }

          for (const f of friends) {
            if (seenIds.has(f.userId)) continue;
            seenIds.add(f.userId);
            allFriends.push(f);
          }
        } catch (err) {
          console.error(`[PersonalZcaChannel - ${instance.label}] Failed to fetch friends:`, err);
          // Fall back to stale cache if available
          const cached = friendsCache.get(instance.uId);
          if (cached) {
            console.log(`[PersonalZcaChannel - ${instance.label}] Falling back to stale cached friend list.`);
            for (const f of cached.data) {
              if (seenIds.has(f.userId)) continue;
              seenIds.add(f.userId);
              allFriends.push(f);
            }
          }
        }
      }

      return allFriends;
    } catch (err) {
      console.error('[PersonalZcaChannel] Failed to get all friends:', err);
      return [];
    }
  }

  async getGroupMembers(groupId: string): Promise<ZaloGroupMember[]> {
    try {
      await ensureLoginPool();
      if (accountPool.size === 0) return [];

      for (const instance of accountPool.values()) {
        try {
          console.log(`[PersonalZcaChannel - ${instance.label}] Fetching members for group ${groupId}...`);
          const infoData = await instance.api.getGroupInfo(groupId);
          const info = infoData.gridInfoMap?.[groupId];
          if (!info) continue;

          let memberIds: string[] = info.memberIds || [];
          if (memberIds.length === 0 && info.memVerList) {
            memberIds = info.memVerList.map((item: string) => item.split('_')[0]);
          }
          const adminIds: string[] = info.adminIds || [];
          const creatorId: string = info.creatorId || '';
          const members: ZaloGroupMember[] = [];

          // Use currentMems for display names when available
          const currentMemsMap = new Map<string, any>();
          if (info.currentMems) {
            for (const m of info.currentMems) {
              currentMemsMap.set(m.id, m);
            }
          }

          // Batch-fetch member profiles for IDs not in currentMems
          const unknownIds = memberIds.filter(id => !currentMemsMap.has(id));
          let profilesMap: Record<string, any> = {};
          if (unknownIds.length > 0) {
            try {
              const profileData = await instance.api.getGroupMembersInfo(unknownIds);
              profilesMap = profileData.profiles || {};
            } catch {
              // Proceed with partial data
            }
          }

          for (const uid of memberIds) {
            const cm = currentMemsMap.get(uid);
            const profile = profilesMap[uid];
            let role: 'owner' | 'admin' | 'member' = 'member';
            if (uid === creatorId) role = 'owner';
            else if (adminIds.includes(uid)) role = 'admin';

            members.push({
              id: uid,
              displayName: cm?.dName || profile?.displayName || profile?.zaloName || uid,
              zaloName: cm?.zaloName || profile?.zaloName || '',
              avatar: cm?.avatar || profile?.avatar || '',
              role,
            });
          }

          console.log(`[PersonalZcaChannel - ${instance.label}] Found ${members.length} members in group ${groupId}.`);
          return members;
        } catch (err) {
          console.error(`[PersonalZcaChannel - ${instance.label}] Failed to fetch group members:`, err);
        }
      }

      return [];
    } catch (err) {
      console.error(`[PersonalZcaChannel] Failed to get group members for ${groupId}:`, err);
      return [];
    }
  }

  async getGroupLinkMembers(link: string): Promise<{ groupId: string; groupName: string; totalMember: number; members: ZaloGroupMember[]; avatar?: string }> {
    const empty = { groupId: '', groupName: '', totalMember: 0, members: [] as ZaloGroupMember[], avatar: '' };
    try {
      await ensureLoginPool();
      if (accountPool.size === 0) return empty;

      for (const instance of accountPool.values()) {
        try {
          console.log(`[PersonalZcaChannel - ${instance.label}] Fetching group info from link: ${link}`);
          const data = await instance.api.getGroupLinkInfo({ link });

          const adminIds = data.adminIds || [];
          const creatorId = data.creatorId || '';
          const members: ZaloGroupMember[] = (data.currentMems || []).map((m: any) => {
            let role: 'owner' | 'admin' | 'member' = 'member';
            if (m.id === creatorId) role = 'owner';
            else if (adminIds.includes(m.id)) role = 'admin';
            return {
              id: m.id,
              displayName: m.dName || m.zaloName || m.id,
              zaloName: m.zaloName || '',
              avatar: m.avatar || '',
              role,
            };
          });

          const avatarUrl = data.avatar || data.avt || data.avatarUrl || '';
          console.log(`[PersonalZcaChannel - ${instance.label}] Link scan: ${data.name}, ${members.length}/${data.totalMember} members loaded.`);
          return {
            groupId: data.groupId,
            groupName: data.name || '',
            totalMember: data.totalMember || members.length,
            members,
            avatar: avatarUrl,
          };
        } catch (err) {
          console.error(`[PersonalZcaChannel - ${instance.label}] Failed to fetch group link info:`, err);
        }
      }

      return empty;
    } catch (err) {
      console.error(`[PersonalZcaChannel] Failed to get group link members:`, err);
      return empty;
    }
  }

  async createGroup(name: string, members: string[], accountId?: string): Promise<{ success: boolean; groupId?: string; error?: string }> {
    try {
      await ensureLoginPool();
      if (accountPool.size === 0) {
        throw new Error('No active connected Zalo accounts in the pool.');
      }
      
      let selectedInstance = accountId ? accountPool.get(accountId) : undefined;
      if (!selectedInstance && accountId) {
        throw new Error(`Requested Zalo account ${accountId} is not connected.`);
      }
      if (!selectedInstance) {
        selectedInstance = Array.from(accountPool.values())[0];
      }

      console.log(`[PersonalZcaChannel] Using account ${selectedInstance.label} to create group "${name}"`);
      const result = await selectedInstance.api.createGroup({
        name,
        members,
      });

      // Invalidate groups cache immediately
      groupsCache.delete(selectedInstance.uId);

      return {
        success: true,
        groupId: result?.groupId,
      };
    } catch (err) {
      console.error(`[PersonalZcaChannel] Failed to create group:`, err);
      return {
        success: false,
        error: err instanceof Error ? err.message : String(err),
      };
    }
  }

  async joinGroup(link: string, accountId?: string): Promise<{ success: boolean; error?: string }> {
    try {
      await ensureLoginPool();
      if (accountPool.size === 0) {
        throw new Error('No active connected Zalo accounts in the pool.');
      }

      let selectedInstance = accountId ? accountPool.get(accountId) : undefined;
      if (!selectedInstance && accountId) {
        throw new Error(`Requested Zalo account ${accountId} is not connected.`);
      }
      if (!selectedInstance) {
        selectedInstance = Array.from(accountPool.values())[0];
      }

      console.log(`[PersonalZcaChannel] Using account ${selectedInstance.label} to join group from link: ${link}`);
      await selectedInstance.api.joinGroupLink(link);

      // Invalidate groups cache immediately
      groupsCache.delete(selectedInstance.uId);

      return {
        success: true,
      };
    } catch (err) {
      console.error(`[PersonalZcaChannel] Failed to join group:`, err);
      return {
        success: false,
        error: err instanceof Error ? err.message : String(err),
      };
    }
  }

  async inviteToGroup(userId: string, groupId: string, accountId?: string): Promise<{ success: boolean; error?: string }> {
    try {
      await ensureLoginPool();
      if (accountPool.size === 0) {
        throw new Error('No active connected Zalo accounts in the pool.');
      }

      let selectedInstance = accountId ? accountPool.get(accountId) : undefined;
      if (!selectedInstance && accountId) {
        throw new Error(`Requested Zalo account ${accountId} is not connected.`);
      }
      if (!selectedInstance) {
        // Try to find which account has access to this group, otherwise use the first active account
        selectedInstance = Array.from(accountPool.values())[0];
        for (const instance of accountPool.values()) {
          try {
            const infoData = await instance.api.getGroupInfo(groupId);
            if (infoData?.gridInfoMap?.[groupId]) {
              selectedInstance = instance;
              break;
            }
          } catch {
            // Ignore and check next account
          }
        }
      }

      console.log(`[PersonalZcaChannel] Using account ${selectedInstance.label} to invite user ${userId} to group ${groupId}`);
      await selectedInstance.api.inviteUserToGroups(userId, groupId);

      return {
        success: true,
      };
    } catch (err) {
      console.error(`[PersonalZcaChannel] Failed to invite user to group:`, err);
      return {
        success: false,
        error: err instanceof Error ? err.message : String(err),
      };
    }
  }

  async findUser(phoneNumber: string, accountId?: string): Promise<any> {
    try {
      await ensureLoginPool();
      if (accountPool.size === 0) {
        throw new Error('No active connected Zalo accounts in the pool.');
      }
      let selectedInstance = accountId ? accountPool.get(accountId) : undefined;
      if (!selectedInstance && accountId) {
        throw new Error(`Requested Zalo account ${accountId} is not connected.`);
      }
      if (!selectedInstance) {
        selectedInstance = Array.from(accountPool.values())[0];
      }
      console.log(`[PersonalZcaChannel] Using account ${selectedInstance.label} to search phone: ${phoneNumber}`);
      const profile = await selectedInstance.api.findUser(phoneNumber);
      return profile;
    } catch (err) {
      console.error(`[PersonalZcaChannel] Failed to find user by phone ${phoneNumber}:`, err);
      throw err;
    }
  }

  async sendFriendRequest(userId: string, message: string, accountId?: string): Promise<{ success: boolean; error?: string }> {
    try {
      await ensureLoginPool();
      if (accountPool.size === 0) {
        throw new Error('No active connected Zalo accounts in the pool.');
      }
      let selectedInstance = accountId ? accountPool.get(accountId) : undefined;
      if (!selectedInstance && accountId) {
        throw new Error(`Requested Zalo account ${accountId} is not connected.`);
      }
      if (!selectedInstance) {
        selectedInstance = Array.from(accountPool.values())[0];
      }
      console.log(`[PersonalZcaChannel] Using account ${selectedInstance.label} to send friend request to ${userId}`);
      await selectedInstance.api.sendFriendRequest(message, userId);
      return { success: true };
    } catch (err) {
      console.error(`[PersonalZcaChannel] Failed to send friend request to ${userId}:`, err);
      return {
        success: false,
        error: err instanceof Error ? err.message : String(err),
      };
    }
  }

  async acceptFriendRequest(userId: string, accountId?: string): Promise<{ success: boolean; error?: string }> {
    try {
      await ensureLoginPool();
      if (accountPool.size === 0) {
        throw new Error('No active connected Zalo accounts in the pool.');
      }
      let selectedInstance = accountId ? accountPool.get(accountId) : undefined;
      if (!selectedInstance && accountId) {
        throw new Error(`Requested Zalo account ${accountId} is not connected.`);
      }
      if (!selectedInstance) {
        selectedInstance = Array.from(accountPool.values())[0];
      }
      console.log(`[PersonalZcaChannel] Using account ${selectedInstance.label} to accept friend request from ${userId}`);
      await selectedInstance.api.acceptFriendRequest(userId);
      
      // Invalidate friends cache immediately to reflect the new friend list
      friendsCache.delete(selectedInstance.uId);
      
      return { success: true };
    } catch (err) {
      console.error(`[PersonalZcaChannel] Failed to accept friend request from ${userId}:`, err);
      return {
        success: false,
        error: err instanceof Error ? err.message : String(err),
      };
    }
  }
}
