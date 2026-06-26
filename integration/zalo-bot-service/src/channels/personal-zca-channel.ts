/**
 * PersonalZcaChannel — primary channel adapter using zca-js for personal Zalo.
 * Supports multiple concurrent active accounts and automatic round-robin rotation.
 */

import { existsSync, readFileSync, readdirSync, writeFileSync, unlinkSync, mkdirSync, copyFileSync, rmdirSync } from 'fs';
import { resolve, dirname, basename } from 'path';
import { config, projectRoot } from '../config.js';
import { readSecure, writeSecure } from '../secure-store.js';
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
import { markAutoApproved } from '../recent-friend-approvals.js';

// zca-js imports
import { Zalo, ThreadType, FriendEventType } from 'zca-js';
import type { API, Credentials } from 'zca-js';

type AccountStatus = 'connected' | 'disconnected_expired';

interface ZaloAccountInstance {
  api: API;
  uId: string;
  label: string;
  listenerRunning: boolean;
  lastEventAt: string | null;
  avatar?: string;
  // Source credentials file this account was loaded from / should persist to.
  credentialsPath?: string;
  // Connection health surfaced to the UI. When the realtime socket is force-closed
  // by Zalo (duplicate login / kicked), the session is dead and must be re-scanned.
  // Optional so lightweight test fixtures can omit it; defaults to 'connected'.
  status?: AccountStatus;
  disconnectCode?: number;
  disconnectReason?: string;
  disconnectedAt?: string;
}

// Human-readable explanation for a websocket close code from zca-js.
// 3000 = DuplicateConnection, 3003 = KickConnection (see zca-js CloseReason).
function describeCloseReason(code: number, reason: string): string {
  switch (code) {
    case 3000:
      return 'Đăng nhập trùng: tài khoản này vừa được đăng nhập ở nơi khác (Zalo Web hoặc thiết bị khác), khiến phiên trên CRM bị ngắt. Vui lòng quét QR đăng nhập lại.';
    case 3003:
      return 'Bị đăng xuất: phiên đã bị thu hồi/đăng xuất từ ứng dụng Zalo trên điện thoại. Vui lòng quét QR đăng nhập lại.';
    default:
      return reason
        ? `Mất kết nối (mã ${code}): ${reason}`
        : `Mất kết nối (mã ${code}).`;
  }
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

type InboundAttachment = NonNullable<ZaloInboundMessageEvent['attachments']>[number];

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
interface GroupMeta {
  name: string;
  avatar: string;
}
const groupNameCache = new Map<string, { meta: GroupMeta; timestamp: number }>();
const GROUP_NAME_CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

// Resolve a group's display name AND avatar from the zca-js API. The group
// avatar (fullAvt/avt) becomes the conversation avatar so the inbox shows the
// group's own picture rather than whichever member happened to send last.
async function resolveGroupInfo(api: API, groupId: string): Promise<GroupMeta> {
  const cached = groupNameCache.get(groupId);
  if (cached && Date.now() - cached.timestamp < GROUP_NAME_CACHE_TTL_MS) {
    return cached.meta;
  }
  try {
    const result = await (api as any).getGroupInfo(groupId);
    const info = result?.gridInfoMap?.[groupId];
    const meta: GroupMeta = {
      name: info?.name || '',
      avatar: normalizeImageUrl(info?.fullAvt || info?.avt || ''),
    };
    if (meta.name || meta.avatar) {
      groupNameCache.set(groupId, { meta, timestamp: Date.now() });
    }
    return meta;
  } catch (err) {
    console.warn(`[PersonalZcaChannel] getGroupInfo failed for ${groupId}:`, err);
    return { name: '', avatar: '' };
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
  try {
    const raw = readSecure(accountSettingsPath());
    if (!raw) return {};
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

function writeAccountSettings(settings: Record<string, AccountSettings>): void {
  writeSecure(accountSettingsPath(), JSON.stringify(settings, null, 2));
}

function accountIdFromCredentialsPath(filePath: string): string | undefined {
  const match = basename(filePath).match(/^credentials_(.+)\.json$/);
  return match?.[1];
}

function defaultCredentialsPathForAccount(uId: string): string {
  const credPath = resolve(projectRoot, config.personalCredentialsPath);
  return resolve(dirname(credPath), `credentials_${uId}.json`);
}

/**
 * Credentials persistence policy — DO NOT re-serialize the live cookie jar.
 *
 * The credentials file (`credentials_<uId>.json`) is written EXACTLY ONCE, at
 * QR login, from the fresh `GotLoginInfo` event data (see `personal-login.ts`
 * and the `/create-qr` handler in `server.ts`). It must stay immutable.
 *
 * Re-serializing the in-memory tough-cookie jar (`api.getContext().cookie`)
 * back to disk is the root cause of the `zpw_sek bị thiếu hoặc không đúng`
 * (code 600) outage: zca-js's RAM jar is momentarily degraded during session
 * rotation, so a periodic flush could overwrite the good file with a cookie set
 * missing `zpw_sek`, permanently corrupting the on-disk session. The canonical
 * reference (ZaloCRM `zalo-pool.ts`) never does this — it keeps long-lived
 * sessions alive by RE-LOGGING IN (`zalo.login(savedCredentials)`) from the
 * immutable saved data, which makes Zalo re-issue fresh cookies into the RAM
 * jar while the file stays the known-good QR original.
 */

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

function isPollPayload(value: unknown): boolean {
  if (!value) return false;
  let parsed: any = null;
  if (typeof value === 'object' && !Array.isArray(value)) {
    parsed = value;
  } else if (typeof value === 'string') {
    const trimmed = value.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        parsed = JSON.parse(trimmed);
      } catch {}
    }
  }
  if (parsed && typeof parsed === 'object') {
    const paramsVal = parsed.params;
    let paramsMap: any = null;
    if (typeof paramsVal === 'string' && paramsVal.trim().startsWith('{')) {
      try {
        paramsMap = JSON.parse(paramsVal);
      } catch {}
    } else if (paramsVal && typeof paramsVal === 'object') {
      paramsMap = paramsVal;
    }
    return Boolean(paramsMap && (paramsMap.pollId || paramsMap.question || paramsMap.dName));
  }
  return false;
}

function parseRecord(value: unknown): Record<string, unknown> | null {
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

function extensionMimeType(fileExt: string, kind: string): string {
  const ext = fileExt.toLowerCase().replace(/^\./, '');
  const map: Record<string, string> = {
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    png: 'image/png',
    gif: 'image/gif',
    webp: 'image/webp',
    pdf: 'application/pdf',
    doc: 'application/msword',
    docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    xls: 'application/vnd.ms-excel',
    xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    zip: 'application/zip',
    mp4: 'video/mp4',
    mp3: 'audio/mpeg',
  };
  return map[ext] || (kind === 'image' ? 'image/jpeg' : '');
}

function numericSize(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

function firstNonEmptyString(...values: unknown[]): string {
  for (const value of values) {
    const text = toStringValue(value).trim();
    if (text) return text;
  }
  return '';
}

function attachmentKindFromMessageType(
  messageType: ZaloInboundMessageEvent['messageType'],
  data: Record<string, unknown>,
): string {
  if (messageType === 'image' || messageType === 'gif') return 'image';
  if (messageType === 'video') return 'video';
  if (messageType === 'voice') return 'voice';
  if (messageType === 'file') return 'file';
  const raw = String(data.msgType ?? data.type ?? '').toLowerCase();
  if (raw.includes('photo') || raw.includes('image')) return 'image';
  if (raw.includes('video')) return 'video';
  if (raw.includes('voice') || raw.includes('audio')) return 'voice';
  return 'file';
}

function extractAttachmentFromRecord(
  value: unknown,
  messageType: ZaloInboundMessageEvent['messageType'],
): InboundAttachment | null {
  const record = parseRecord(value);
  if (!record) return null;
  const params = parseRecord(record.params) || {};
  const kind = attachmentKindFromMessageType(messageType, record);
  const fileName = firstNonEmptyString(
    record.fileName,
    record.name,
    record.title,
    params.fileName,
    params.name,
  );
  const fileExt = firstNonEmptyString(
    record.fileExt,
    record.ext,
    params.fileExt,
    params.ext,
  );
  const url = normalizeImageUrl(
    record.href ??
      record.url ??
      record.fileUrl ??
      record.oriUrl ??
      record.originUrl ??
      record.downloadUrl ??
      record.hdUrl ??
      record.thumb ??
      record.thumbnail,
  );
  const thumbnailUrl = normalizeImageUrl(
    record.thumb ?? record.thumbnail ?? record.previewUrl ?? params.thumb,
  );
  if (!url && !thumbnailUrl && !fileName) return null;
  return {
    kind,
    ...(fileName ? { name: fileName } : {}),
    ...(url || thumbnailUrl ? { url: url || thumbnailUrl } : {}),
    ...(extensionMimeType(fileExt, kind)
      ? { mimeType: extensionMimeType(fileExt, kind) }
      : {}),
    ...(numericSize(record.fileSize ?? record.size ?? params.fileSize ?? params.size)
      ? {
          sizeBytes: numericSize(
            record.fileSize ?? record.size ?? params.fileSize ?? params.size,
          ),
        }
      : {}),
    metadata: {
      ...(thumbnailUrl ? { thumbnailUrl } : {}),
      ...(fileExt ? { fileExt } : {}),
    },
  };
}

function extractInboundAttachments(
  data: Record<string, any>,
  messageType: ZaloInboundMessageEvent['messageType'],
): InboundAttachment[] {
  const candidates = [
    data.attachments,
    data.attach,
    data.content,
    data.params,
  ];
  const attachments: NonNullable<ZaloInboundMessageEvent['attachments']> = [];
  for (const candidate of candidates) {
    if (!candidate) continue;
    const values = Array.isArray(candidate) ? candidate : [candidate];
    for (const value of values) {
      const attachment = extractAttachmentFromRecord(value, messageType);
      if (!attachment) continue;
      const key = `${attachment.kind}:${attachment.url || ''}:${attachment.name || ''}`;
      if (
        !attachments.some(
          (item) => `${item.kind}:${item.url || ''}:${item.name || ''}` === key,
        )
      ) {
        attachments.push(attachment);
      }
    }
  }
  return attachments;
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
  const isPollMsg = isPollPayload(data.content) ||
    isPollPayload(data.attach) ||
    isPollPayload(data.attachments) ||
    isPollPayload(data.message);

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
                      : (rawType.includes('poll') || isPollMsg)
                        ? 'poll'
                        : rawType.includes('system') ||
                            rawType.includes('pin')
                          ? 'system'
                    : richContent
                      ? 'link'
                      : 'text';
  const attachments = extractInboundAttachments(data, messageType);
  let content = extractInboundContent(data, messageType);

  // Call detection and normalization
  const isCall =
    rawType.includes('call') ||
    (typeof data.content === 'object' &&
      data.content !== null &&
      (data.content.action === 'recommened.misscall' ||
        data.content.action === 'recommened.calltime' ||
        data.content.call_id ||
        data.content.callId ||
        data.content.callType !== undefined));

  if (isCall) {
    const contentRaw = typeof data.content === 'object' && data.content !== null ? data.content : {};
    const action = String(contentRaw.action || '');
    if (action === 'recommened.misscall') {
      content = '📵 Cuộc gọi nhỡ';
    } else if (action === 'recommened.calltime') {
      let params: any = {};
      try {
        const p = contentRaw.params;
        params = typeof p === 'string' ? JSON.parse(p) : (p || {});
      } catch {}
      const secs = Number(params.duration || 0);
      if (secs > 0) {
        const m = Math.floor(secs / 60);
        const s = secs % 60;
        content = `📞 Cuộc gọi (${m > 0 ? `${m}p ` : ''}${s}s)`;
      } else {
        content = '📞 Cuộc gọi';
      }
    } else {
      const missed = contentRaw.missed === true || contentRaw.status === 2;
      const secs = Number(contentRaw.duration || contentRaw.call_duration || 0);
      if (missed) {
        content = '📵 Cuộc gọi nhỡ';
      } else if (secs > 0) {
        const m = Math.floor(secs / 60);
        const s = secs % 60;
        content = `📞 Cuộc gọi (${m > 0 ? `${m}p ` : ''}${s}s)`;
      } else {
        content = '📞 Cuộc gọi';
      }
    }
  }

  if (attachments.length > 0 && messageType !== 'text' && messageType !== 'link') {
    content = `[${messageType}]`;
  }
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
    attachments,
    timestamp,
  };
}

function normalizeNumericMessageId(value: unknown, fallback: string): string {
  const raw = toStringValue(value).trim();
  if (/^\d+$/.test(raw)) return raw;
  return fallback;
}

function createZaloClientMessageId(seed?: unknown): string {
  const normalized = normalizeNumericMessageId(seed, '');
  if (normalized) return normalized;
  const embeddedNumericId = toStringValue(seed).match(/\d{10,}/)?.[0] || '';
  return embeddedNumericId || String(Date.now());
}

// Pin Date.now() to the client message id ONLY when it is a plausible CURRENT
// millisecond timestamp, so zca-js stamps the outgoing message's clientId/cliMsgId
// with the same id the optimistic UI used (enables exact self-echo dedup).
//
// CRITICAL: never pin Date.now() to an arbitrary number. zca-js builds the request
// `Cookie` header from a tough-cookie jar whose expiry check reads the global
// Date.now() (utils.js getCookieString). Pinning it far from reality — e.g. a
// microsecond id like `flutter_<microsecondsSinceEpoch>`, which is ~1000x too large
// and lands ~50,000 years in the future — makes tough-cookie treat the `zpw_sek`
// session cookie as expired, drop it from the request AND evict it from the RAM jar.
// Zalo then rejects every send with code 600 `zpw_sek bị thiếu hoặc không đúng`,
// immediately, even right after a fresh QR login. When the id is not a sane current
// ms timestamp, skip the pin and let zca-js use the real clock.
const DATE_NOW_PIN_TOLERANCE_MS = 10 * 60 * 1000; // ±10 min around the real clock

async function runWithFixedDateNow<T>(
  clientMessageId: string,
  fn: () => Promise<T>,
): Promise<T> {
  const fixed = Number(clientMessageId);
  const realNow = Date.now();
  const isPlausibleNowMs =
    Number.isFinite(fixed) &&
    Math.abs(fixed - realNow) <= DATE_NOW_PIN_TOLERANCE_MS;
  if (!isPlausibleNowMs) return fn();
  const originalDateNow = Date.now;
  Date.now = () => fixed;
  try {
    return await fn();
  } finally {
    Date.now = originalDateNow;
  }
}

export const runWithFixedDateNowForTest = runWithFixedDateNow;

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
    loginError = accountPool.size === 0
      ? describeFailedCredentials() || loginError
      : null;
  } catch (err) {
    loginError = `Failed to scan credentials directory: ${err instanceof Error ? err.message : String(err)}`;
    console.error('[PersonalZcaChannel] Scan error:', err);
  }
}

// Add account dynamically (e.g. after QR login)
export async function addAccountInstance(
  uId: string,
  apiInstance: API,
  credentialsPath?: string,
): Promise<void> {
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

  // Tear down any existing live session for this account before adding the new
  // one. Without this the previous realtime websocket stays open, Zalo sees two
  // connections for the same uId and force-closes one with code 3000
  // (DuplicateConnection) — the "đăng nhập xong là mất kết nối ngay" symptom.
  const existing = accountPool.get(uId);
  if (existing) {
    await stopListenerForInstance(existing);
    console.log(`[PersonalZcaChannel] Replaced existing session for ${uId} before re-login.`);
  }

  const instance: ZaloAccountInstance = {
    api: apiInstance,
    uId,
    label,
    listenerRunning: false,
    lastEventAt: null,
    avatar,
    credentialsPath: credentialsPath || defaultCredentialsPathForAccount(uId),
    status: 'connected',
  };

  accountPool.set(uId, instance);
  failedAccounts.delete(uId);
  loginError = null;
  console.log(`[PersonalZcaChannel] Dynamically added new account to pool: ${label}`);

  // Auto start listener
  await startListenerForInstance(instance);
  // NOTE: do NOT persist the live cookie jar here. The credentials file is the
  // immutable QR-login original; re-serializing the RAM jar corrupts `zpw_sek`.
}

export const failedAccounts = new Map<string, { id: string, reason: string, filePath: string }>();

function describeFailedCredentials(accountId?: string): string | null {
  if (accountId) {
    const failed = failedAccounts.get(accountId);
    if (failed) return failed.reason;
  }
  const failures = Array.from(failedAccounts.values());
  if (failures.length === 0) return null;
  if (failures.length === 1) return failures[0].reason;
  return `Không thể nạp ${failures.length} tài khoản Zalo: ${failures
    .map((failed) => `${failed.id}: ${failed.reason}`)
    .join(' | ')}`;
}

async function loadCredentialsFile(filePath: string): Promise<void> {
  const accountId = accountIdFromCredentialsPath(filePath);
  try {
    const raw = readSecure(filePath);
    if (raw === null) {
      throw new Error(`Không đọc được file ${basename(filePath)} (giải mã thất bại).`);
    }
    const credentials: Credentials = JSON.parse(raw);

    const zpw_sek = (credentials.cookie as any)?.zpw_sek || raw.includes('zpw_sek');
    if (!zpw_sek) {
      throw new Error(`File ${basename(filePath)} này bị thiếu trường quan trọng zpw_sek (do lỗi ghi đè cookie cũ trước đó hoặc phiên đã bị Zalo thu hồi từ điện thoại).`);
    }

    const zalo = createZaloClient(accountId);

    const activeApi = await zalo.login(credentials);
    const uId = activeApi.getOwnId ? activeApi.getOwnId() : `personal_${Date.now()}`;

    // Add to pool — remember the exact file we loaded from so refreshed cookies
    // are persisted back to the same path (handles legacy credentials.json too).
    await addAccountInstance(uId, activeApi, filePath);
    if (accountId) failedAccounts.delete(accountId);
  } catch (err) {
    console.error(`[PersonalZcaChannel] Failed to load credentials from ${filePath}:`, err);
    const idToUse = accountId || `unknown_${Date.now()}`;
    failedAccounts.set(idToUse, {
      id: idToUse,
      reason: err instanceof Error ? err.message : String(err),
      filePath,
    });
  }
}

// ── Session recovery: re-login from the immutable credentials file ──────────────
// When a send fails with zpw_sek/code 600 the live RAM cookie jar may just be stale.
// Re-reading the immutable QR-login file and calling zalo.login() makes Zalo re-issue
// fresh cookies (incl. a new zpw_sek) into a brand-new RAM jar — mirroring ZaloCRM's
// reconnect/autoReconnect. We NEVER re-serialize the jar back to disk (see the
// credentials persistence policy above). A circuit breaker bounds the attempts so a
// genuinely revoked account is not hammered.
const RELOGIN_WINDOW_MS = 5 * 60 * 1000; // 5-minute sliding window
const RELOGIN_MAX_IN_WINDOW = 3; // re-login attempts per window before giving up
const reloginHistory = new Map<string, number[]>();
const reloginInFlight = new Map<string, Promise<ZaloAccountInstance | null>>();

function isDeadSessionError(err: unknown): boolean {
  const e = err as any;
  const code = e?.code ?? e?.data?.code ?? e?.details?.code;
  const message = e instanceof Error ? e.message : String(e ?? '');
  return code === 600 || /zpw_sek/i.test(message);
}

// Records a re-login attempt and returns how many happened within the sliding window
// (including this one). The caller gives up once this exceeds RELOGIN_MAX_IN_WINDOW.
function recordReloginAttempt(uId: string): number {
  const now = Date.now();
  const history = (reloginHistory.get(uId) ?? []).filter(
    (t) => now - t < RELOGIN_WINDOW_MS,
  );
  history.push(now);
  reloginHistory.set(uId, history);
  return history.length;
}

function clearReloginHistory(uId: string): void {
  reloginHistory.delete(uId);
}

async function reloginAccountFromDisk(
  instance: ZaloAccountInstance,
): Promise<ZaloAccountInstance | null> {
  const filePath =
    instance.credentialsPath || defaultCredentialsPathForAccount(instance.uId);
  if (!existsSync(filePath)) {
    console.error(
      `[PersonalZcaChannel - ${instance.label}] Cannot re-login: credentials file missing at ${filePath}`,
    );
    return null;
  }
  try {
    const raw = readSecure(filePath);
    if (raw === null || !raw.includes('zpw_sek')) {
      console.error(
        `[PersonalZcaChannel - ${instance.label}] Cannot re-login: credentials file is missing zpw_sek (needs a fresh QR login).`,
      );
      return null;
    }
    const credentials: Credentials = JSON.parse(raw);
    const accountId = accountIdFromCredentialsPath(filePath);
    const zalo = createZaloClient(accountId);
    const activeApi = await zalo.login(credentials);
    const uId = activeApi.getOwnId ? activeApi.getOwnId() : instance.uId;
    // addAccountInstance tears down the previous (dead) session, restarts the listener
    // and resets status to 'connected'.
    await addAccountInstance(uId, activeApi, filePath);
    console.log(
      `[PersonalZcaChannel - ${instance.label}] Re-login from saved credentials succeeded.`,
    );
    return accountPool.get(uId) ?? null;
  } catch (err) {
    console.error(
      `[PersonalZcaChannel - ${instance.label}] Re-login from disk failed:`,
      err,
    );
    return null;
  }
}

// De-dupe concurrent re-logins for the same account (e.g. a burst of sends all hitting
// zpw_sek at once) so the session is not torn down / re-created multiple times.
function reloginAccountFromDiskOnce(
  instance: ZaloAccountInstance,
): Promise<ZaloAccountInstance | null> {
  const existing = reloginInFlight.get(instance.uId);
  if (existing) return existing;
  const p = reloginAccountFromDisk(instance).finally(() => {
    reloginInFlight.delete(instance.uId);
  });
  reloginInFlight.set(instance.uId, p);
  return p;
}

// Test exports for the circuit breaker (the re-login itself needs a live zca-js login).
export const recordReloginAttemptForTest = recordReloginAttempt;
export const clearReloginHistoryForTest = clearReloginHistory;
export const RELOGIN_MAX_IN_WINDOW_FOR_TEST = RELOGIN_MAX_IN_WINDOW;

// Tracks accounts whose inbox has been bootstrapped from Zalo recent history
// (once per process lifetime) so a reconnect does not re-trigger the sync.
const recentInboxBootstrapDone = new Set<string>();

async function startListenerForInstance(instance: ZaloAccountInstance): Promise<void> {
  if (instance.listenerRunning) return;
  // A revoked session can never reconnect on the same (dead) cookie — skip it so
  // the health monitor does not spin in a reconnect loop and the warning stays put.
  if (instance.status === 'disconnected_expired') return;
  try {
    const listener = instance.api.listener;
    if (listener) {
      listener.removeAllListeners("connected");
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
      listener.removeAllListeners("old_messages");
      listener.removeAllListeners("closed");

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
              markAutoApproved(senderId);
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

      listener.on("old_messages", async (payload: any) => {
        instance.lastEventAt = new Date().toISOString();
        // zca-js emits old_messages as (messages: Message[], threadType) — the
        // FIRST arg is the message array itself, not an event wrapper. The old
        // `event.data.msgs` read always yielded [] so history never loaded.
        // Stay defensive across versions.
        const msgs: any[] = Array.isArray(payload)
          ? payload
          : (payload?.data?.msgs ?? payload?.messages ?? []);
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
               const group = await resolveGroupInfo(instance.api, inbound.threadId);
               if (group.name) inbound.groupName = group.name;
               // Conversation avatar = the group's own picture, not the sender's.
               if (group.avatar) inbound.avatarUrl = group.avatar;
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

        // Resolve group display name + avatar for group threads. The group's
        // own picture becomes the conversation avatar (senderAvatarUrl keeps the
        // per-message sender avatar for in-bubble display).
        if (inbound.threadType === 'group' && inbound.threadId) {
          const group = await resolveGroupInfo(instance.api, inbound.threadId);
          if (group.name) {
            inbound.groupName = group.name;
          }
          if (group.avatar) {
            inbound.avatarUrl = group.avatar;
          }
        }

        console.log(
          `[PersonalZcaChannel - ${instance.label}] Message event from ${inbound.senderId} (${inbound.messageType}, ${inbound.content.length} chars)${inbound.groupName ? ` in group "${inbound.groupName}"` : ''}.`,
        );
        await emitInboundMessage(inbound);
      });

      // ── Handle Listener Errors to prevent crashes ──
      listener.on("error", (err: any) => {
        console.warn(`[PersonalZcaChannel - ${instance.label}] Realtime listener error:`, err?.message || err);
      });

      // ── Connection closed (e.g. Kicked from phone or Duplicate Login) ──
      listener.on("closed", async (code: number, reason: string) => {
        console.warn(`[PersonalZcaChannel - ${instance.label}] Listener closed. Code: ${code}, Reason: ${reason}`);

        if (code === 3000 || code === 3003) { // 3000: Duplicate, 3003: Kicked
          // Unrecoverable: only a fresh QR login fixes it. Stop (while
          // listenerRunning is still true so cleanup runs) and mark expired so the
          // health monitor does not spin reconnecting a dead cookie, and the UI
          // can surface the revoke reason.
          console.error(`[PersonalZcaChannel - ${instance.label}] Kicked by server or duplicate login. Marking as disconnected.`);
          await stopListenerForInstance(instance);
          instance.status = 'disconnected_expired';
          instance.disconnectCode = code;
          instance.disconnectReason = describeCloseReason(code, reason);
          instance.disconnectedAt = new Date().toISOString();
          return;
        }

        // Transient close (network blip, server reset…). The socket is dead, so
        // drop the "running" flag — this fixes the zombie "đang lắng nghe" state
        // in the UI and lets the existing ListenerHealthMonitor (connected &&
        // !listenerRunning → recover, every 15s) auto-reconnect without a manual
        // re-login. status stays 'connected' so recovery is allowed.
        instance.listenerRunning = false;
      });

      listener.on("connected", () => {
        console.log(`[PersonalZcaChannel - ${instance.label}] Listener connected.`);
        // Bootstrap the inbox once per process: ask Zalo for the most recent
        // messages across all user and group threads. The "old_messages" handler
        // above upserts them (with name/avatar enrichment), so conversations
        // populate like a messenger inbox instead of appearing only after a new
        // live message arrives. Idempotent (dedup by providerMessageId).
        if (recentInboxBootstrapDone.has(instance.uId)) return;
        recentInboxBootstrapDone.add(instance.uId);
        setTimeout(() => {
          try {
            (listener as any).requestOldMessages(ThreadType.User, null);
            (listener as any).requestOldMessages(ThreadType.Group, null);
            console.log(`[PersonalZcaChannel - ${instance.label}] Requested recent history for inbox bootstrap.`);
          } catch (err) {
            console.warn(`[PersonalZcaChannel - ${instance.label}] Inbox bootstrap request failed:`, err);
          }
        }, 2000);
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
      listener.removeAllListeners("connected");
      listener.removeAllListeners("old_messages");
      listener.removeAllListeners("closed");
      recentInboxBootstrapDone.delete(instance.uId);
      instance.listenerRunning = false;
      console.log(`[PersonalZcaChannel - ${instance.label}] Realtime listener stopped.`);
    }
  } catch (err) {
    console.error(`[PersonalZcaChannel - ${instance.label}] Failed to stop realtime listener:`, err);
  }
}

export class PersonalZcaChannel implements ZaloChannel {
  getStatus(): ZaloChannelStatus {
    const connectedAccounts = Array.from(accountPool.values());
    // A kicked/expired account stays in the pool so the UI can still surface its
    // disconnect reason. "connected" must therefore mean at least one account is
    // still live — not just pool.size > 0, otherwise an all-expired pool would
    // keep reporting "đã kết nối" and no warning would ever show.
    const connected = connectedAccounts.some(
      acc => acc.status !== 'disconnected_expired',
    );
    const label = accountPool.size > 0
      ? `${accountPool.size} tài khoản Zalo cá nhân`
      : 'Chưa liên kết tài khoản nào';

    const listenerRunning = connectedAccounts.some(acc => acc.listenerRunning);
    // Per-account recovery hint: any live (non-expired) account whose listener is
    // down needs recovering — even if another account is still listening (so the
    // coarse `listenerRunning` OR above is true). This is what makes auto-recovery
    // work with multiple accounts.
    const needsListenerRecovery = connectedAccounts.some(
      acc => acc.status !== 'disconnected_expired' && !acc.listenerRunning,
    );
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
      needsListenerRecovery,
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

    let selectedInstance: ZaloAccountInstance | undefined;
    const tempDirsToCleanup: string[] = [];
    try {
      await ensureLoginPool();

      if (accountPool.size === 0) {
        const credentialError = describeFailedCredentials(req.accountId);
        if (credentialError) {
          throw new Error(credentialError);
        }
        throw new Error('No active connected Zalo accounts in the pool.');
      }

      // Dynamic Round-Robin rotation selector, unless CRM requested a sender account.
      const instances = Array.from(accountPool.values());
      selectedInstance = req.accountId ? accountPool.get(req.accountId) : undefined;
      if (!selectedInstance && req.accountId) {
        throw new Error(
          describeFailedCredentials(req.accountId) ||
            `Requested Zalo account ${req.accountId} is not connected.`,
        );
      }
      if (!selectedInstance) {
        selectedInstance = instances[roundRobinIndex % instances.length];
        roundRobinIndex++;
      }

      console.log(`[PersonalZcaChannel] Selected sender account: ${selectedInstance.label}`);

      let recipientId = String(req.recipientId || '').trim();
      const messageText = String(req.message || '').trim();
      const attachments = (req.attachments || []).filter((item) =>
        String(item || '').trim(),
      );
      if (!recipientId || (!messageText && attachments.length === 0)) {
        throw new Error('Missing recipientId or message/attachments.');
      }

      const threadType =
        req.threadType === 'group' ? ThreadType.Group : ThreadType.User;

      // Automatically resolve phone number to Zalo UID if needed
      if (threadType === ThreadType.User && /^(0|84|\+84)\d{8,10}$/.test(recipientId)) {
        try {
          const profile = await selectedInstance.api.findUser(recipientId);
          if (profile && profile.uid && profile.uid !== '0') {
            console.log(`[PersonalZcaChannel] Resolved phone ${recipientId} to UID ${profile.uid}`);
            recipientId = profile.uid;
          } else {
            console.warn(`[PersonalZcaChannel] findUser returned empty/invalid UID for ${recipientId}`);
          }
        } catch (findErr: any) {
          console.warn(`[PersonalZcaChannel] Failed to resolve phone ${recipientId} to UID: ${findErr.message || findErr}`);
        }
      }

      // Prepare processed attachments to preserve original filenames
      let processedAttachments: string[] = [];
      if (attachments.length > 0) {
        if (req.attachmentNames && req.attachmentNames.length > 0) {
          const tempBaseDir = resolve(projectRoot, '.data/temp-sends');
          if (!existsSync(tempBaseDir)) {
            mkdirSync(tempBaseDir, { recursive: true });
          }
          for (let i = 0; i < attachments.length; i++) {
            const originalPath = attachments[i];
            const originalName = req.attachmentNames[i];
            if (originalName && existsSync(originalPath)) {
              const uniqueSubdir = resolve(
                tempBaseDir,
                `${Date.now()}_${Math.random().toString(36).substring(2, 9)}`
              );
              mkdirSync(uniqueSubdir, { recursive: true });
              tempDirsToCleanup.push(uniqueSubdir);

              const tempPath = resolve(uniqueSubdir, originalName);
              copyFileSync(originalPath, tempPath);
              processedAttachments.push(tempPath);
            } else {
              processedAttachments.push(originalPath);
            }
          }
        } else {
          processedAttachments = attachments;
        }
      }

      const hasAttachments = processedAttachments.length > 0;
      console.log(`[PersonalZcaChannel] sendMessage params: recipientId=${recipientId}, threadType=${req.threadType}(${threadType}), message="${messageText.substring(0, 50)}", attachments=${hasAttachments ? processedAttachments.length : 0}`);

      // Build the richest payload supported by the installed zca-js version.
      const quote = normalizeQuoteForZca(req.quote);
      const zcaClientMessageId = createZaloClientMessageId(
        req.clientMessageId,
      );
      const messageContent: any = {
        msg: messageText,
        ...(quote ? { quote } : {}),
        ...(req.mentions ? { mentions: req.mentions } : {}),
        ...(req.styles ? { styles: req.styles } : {}),
      };
      if (hasAttachments) {
        messageContent.attachments = processedAttachments;
      }

      const dispatchSend = (apiInst: any): Promise<any> => {
        if (req.messageType === 'sticker' && req.sticker && apiInst.sendSticker) {
          return apiInst.sendSticker(req.sticker, recipientId, threadType);
        }
        if (req.messageType === 'link' && req.link && apiInst.sendLink) {
          return apiInst.sendLink(req.link, recipientId, threadType);
        }
        if (req.messageType === 'video' && req.video && apiInst.sendVideo) {
          return apiInst.sendVideo(req.video, recipientId, threadType);
        }
        if (req.messageType === 'voice' && req.voice && apiInst.sendVoice) {
          return apiInst.sendVoice(req.voice, recipientId, threadType);
        }
        return runWithFixedDateNow(
          zcaClientMessageId,
          () => apiInst.sendMessage(messageContent, recipientId, threadType),
        );
      };

      let result: any;
      try {
        result = await dispatchSend(selectedInstance.api as any);
      } catch (sendErr) {
        // A dead-session (zpw_sek / code 600) error can mean the session was truly
        // revoked, OR just that the in-RAM cookie jar went stale. Recover the way the
        // reference ZaloCRM does: RE-LOGIN from the immutable credentials file (Zalo
        // re-issues fresh cookies into the RAM jar) and retry the send ONCE. A circuit
        // breaker (RELOGIN_MAX_IN_WINDOW per RELOGIN_WINDOW_MS) keeps a genuinely
        // revoked account from being hammered: once the budget is spent we rethrow and
        // the outer catch marks the account disconnected_expired (→ QR re-login).
        if (!isDeadSessionError(sendErr)) throw sendErr;
        const attempts = recordReloginAttempt(selectedInstance.uId);
        if (attempts > RELOGIN_MAX_IN_WINDOW) {
          console.error(
            `[PersonalZcaChannel - ${selectedInstance.label}] Circuit breaker open: ${attempts - 1} re-logins already failed within ${RELOGIN_WINDOW_MS / 60000} min. Not retrying.`,
          );
          throw sendErr;
        }
        console.warn(
          `[PersonalZcaChannel - ${selectedInstance.label}] Send hit zpw_sek; re-logging in from saved credentials (attempt ${attempts}/${RELOGIN_MAX_IN_WINDOW}) and retrying once...`,
        );
        const refreshed = await reloginAccountFromDiskOnce(selectedInstance);
        if (!refreshed) throw sendErr;
        selectedInstance = refreshed;
        // A still-failing retry propagates to the outer catch (→ mark expired).
        result = await dispatchSend(selectedInstance.api as any);
      }

      // A successful send (possibly after re-login) proves the session is healthy —
      // reset the circuit breaker so a future isolated failure starts from a clean slate.
      clearReloginHistory(selectedInstance.uId);

      // zca-js sendMessage returns { message: SendMessageResult | null, attachment: SendMessageResult[] }
      const msgResult = (result as any)?.message ?? result;
      const attachmentMessageIds = Array.isArray((result as any)?.attachment)
        ? (result as any).attachment
            .map((item: any) => item?.msgId)
            .filter((item: unknown) => item != null)
            .map(String)
        : [];
      const msgId =
        msgResult?.msgId ??
        (result as any)?.msgId ??
        attachmentMessageIds[0] ??
        `personal_${Date.now()}`;

      console.log(`[PersonalZcaChannel] sendMessage result:`, JSON.stringify(result)?.substring(0, 200));

      return {
        success: true,
        messageId: String(msgId),
        clientMessageId: zcaClientMessageId,
        attachmentMessageIds,
      };
    } catch (err) {
      console.error(`[PersonalZcaChannel] sendMessage error:`, err);
      const errAny = err as any;
      const code = errAny?.code ?? errAny?.data?.code ?? errAny?.details?.code;
      const message = loginError || (err instanceof Error ? err.message : 'Unknown personal send error');

      // Reaching here with a `zpw_sek` error means the in-flight re-login + retry above
      // did NOT recover the session (or the circuit breaker is open) — the session is
      // genuinely dead. Mark the account expired so the Settings UI surfaces the ⚠️ +
      // "Đăng nhập lại" instead of failing silently on every future send.
      const isDeadSession =
        code === 600 || /zpw_sek/i.test(message);
      if (isDeadSession && selectedInstance && selectedInstance.status !== 'disconnected_expired') {
        console.error(`[PersonalZcaChannel - ${selectedInstance.label}] Dead session (zpw_sek). Marking as disconnected_expired.`);
        await stopListenerForInstance(selectedInstance);
        selectedInstance.status = 'disconnected_expired';
        selectedInstance.disconnectReason = 'Phiên đăng nhập đã hết hạn (zpw_sek). Vui lòng đăng nhập lại.';
        selectedInstance.disconnectedAt = new Date().toISOString();
      }

      return {
        success: false,
        error: code ? `${message} (code: ${code})` : message,
      };
    } finally {
      for (const dir of tempDirsToCleanup) {
        try {
          if (existsSync(dir)) {
            for (const entry of readdirSync(dir)) {
              unlinkSync(resolve(dir, entry));
            }
            rmdirSync(dir);
          }
        } catch (cleanupErr) {
          console.warn(`[PersonalZcaChannel] Failed to clean up temp dir ${dir}:`, cleanupErr);
        }
      }
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
      const cliMsgId = normalizeNumericMessageId(req.cliMsgId, '');
      if (!cliMsgId) {
        throw new Error(
          'Missing Zalo client message ID (cliMsgId) required for recall.',
        );
      }
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
    // Respect the per-account "block typing" privacy setting: when enabled we
    // never emit typing events for this account (live chat or chatbot).
    if (readAccountSettings()[accountId]?.blockTyping === true) return false;
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
    cliMsgId?: string;
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
        request.cliMsgId,
        '',
      );
      if (!cliMsgId) {
        throw new Error(
          'Missing Zalo client message ID (cliMsgId) required for reaction.',
        );
      }
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
              // zca-js getGroupInfo can error/return empty when too many IDs are
              // requested at once, which silently breaks group sync for accounts
              // with many groups. Fetch in chunks and merge so a single bad chunk
              // doesn't lose the whole account.
              // ponytail: chunk size 50, raise if the API tolerates more.
              const gridInfoMap: Record<string, any> = {};
              const chunkSize = 50;
              for (let i = 0; i < groupIds.length; i += chunkSize) {
                const chunk = groupIds.slice(i, i + chunkSize);
                try {
                  const infoData = await instance.api.getGroupInfo(chunk);
                  Object.assign(gridInfoMap, infoData.gridInfoMap || {});
                } catch (chunkErr) {
                  console.error(`[PersonalZcaChannel - ${instance.label}] getGroupInfo failed for chunk ${i}-${i + chunk.length} (${chunk.length} ids):`, chunkErr);
                }
              }
              const resolvedCount = Object.keys(gridInfoMap).length;
              if (resolvedCount < groupIds.length) {
                console.warn(`[PersonalZcaChannel - ${instance.label}] Resolved info for only ${resolvedCount}/${groupIds.length} groups.`);
              }
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
    const accounts: any[] = Array.from(accountPool.values()).map(acc => ({
      id: acc.uId,
      label: acc.label,
      connected: acc.status !== 'disconnected_expired',
      listenerRunning: acc.listenerRunning,
      status: acc.status || 'connected',
      disconnectReason: acc.disconnectReason || '',
      disconnectedAt: acc.disconnectedAt || '',
      avatar: acc.avatar || '',
      settings: settingsByAccount[acc.uId] || {},
    }));

    for (const failed of failedAccounts.values()) {
      accounts.push({
        id: failed.id,
        label: `Tài khoản ${failed.id}`,
        connected: false,
        listenerRunning: false,
        status: 'disconnected_expired',
        disconnectReason: `Không thể kết nối và bị từ chối đăng nhập. Nguyên nhân: ${failed.reason}`,
        disconnectedAt: new Date().toISOString(),
        avatar: '',
        settings: settingsByAccount[failed.id] || {},
      });
    }

    return accounts;
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
    if (failedAccounts.has(accountId)) {
      failedAccounts.delete(accountId);
      const filePath = resolve(dirname(resolve(projectRoot, config.personalCredentialsPath)), `credentials_${accountId}.json`);
      if (existsSync(filePath)) unlinkSync(filePath);
      return true;
    }

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
