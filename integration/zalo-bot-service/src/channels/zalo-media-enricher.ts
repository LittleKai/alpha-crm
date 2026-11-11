// Adapted from https://github.com/luonghaianh1208/2anh-zalo-bot@9ab55105c83487588e66b55f0ef66894224250a7 (MIT License)

const DEFAULT_LOOKUP_TIMEOUT_MS = 4000;
const DEFAULT_CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const DEFAULT_CACHE_LIMIT = 500;
const INTERNAL_STICKER_CODE_RE = /^\[\^[\d.]+\^\]$/;

export interface StickerEnrichment {
  id: number;
  catId?: number | null;
  type?: number | null;
  text: string;
  label: string;
  url: string | null;
  attachment: {
    kind: 'image';
    url: string;
    mimeType: 'image/png';
    name: string;
    metadata: Record<string, unknown>;
  } | null;
}

function parseStickerContentRecord(value: unknown): Record<string, unknown> | null {
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

export function extractStickerRef(eventOrData: any): {
  id: number;
  catId: number | null;
  type: number | null;
} | null {
  const data = eventOrData?.data ?? eventOrData ?? {};
  const content =
    parseStickerContentRecord(data.content) ??
    parseStickerContentRecord(data.msg) ??
    parseStickerContentRecord(data);
  if (!content) return null;

  const rawId = Number(content.id ?? content.stickerId);
  if (!Number.isFinite(rawId) || rawId <= 0) return null;

  const rawCat = Number(content.catId ?? content.cateId);
  const rawType = Number(content.type ?? content.stickerType);
  return {
    id: rawId,
    catId: Number.isFinite(rawCat) && rawCat > 0 ? rawCat : null,
    type: Number.isFinite(rawType) && rawType > 0 ? rawType : null,
  };
}

export function createStickerDescriber(opts?: {
  ttlMs?: number;
  maxEntries?: number;
  timeoutMs?: number;
  now?: () => number;
}): {
  describe(api: any, eventOrData: any): Promise<StickerEnrichment | null>;
  size(): number;
} {
  const ttlMs = opts?.ttlMs ?? DEFAULT_CACHE_TTL_MS;
  const maxEntries = opts?.maxEntries ?? DEFAULT_CACHE_LIMIT;
  const timeoutMs = opts?.timeoutMs ?? DEFAULT_LOOKUP_TIMEOUT_MS;
  const now = opts?.now ?? Date.now;
  const cache = new Map<number, { detail: Record<string, unknown>; at: number }>();

  async function lookupDetail(
    api: any,
    stickerId: number,
  ): Promise<Record<string, unknown> | null> {
    const cached = cache.get(stickerId);
    if (cached && now() - cached.at < ttlMs) {
      return cached.detail;
    }
    if (typeof api?.getStickersDetail !== 'function') {
      return cached?.detail ?? null;
    }

    let timer: ReturnType<typeof setTimeout> | null = null;
    try {
      const response = await Promise.race([
        Promise.resolve(api.getStickersDetail(stickerId)),
        new Promise<never>((_resolve, reject) => {
          timer = setTimeout(
            () => reject(new Error('getStickersDetail timeout')),
            timeoutMs,
          );
        }),
      ]);
      const first = Array.isArray(response) ? response[0] : response;
      if (!first || typeof first !== 'object') {
        // Do not negative-cache empty responses so a later retry can succeed.
        return cached?.detail ?? null;
      }
      const detail = first as Record<string, unknown>;
      if (cache.size >= maxEntries && !cache.has(stickerId)) {
        const oldestKey = cache.keys().next().value;
        if (oldestKey !== undefined) {
          cache.delete(oldestKey);
        }
      }
      cache.set(stickerId, { detail, at: now() });
      return detail;
    } catch {
      return cached?.detail ?? null;
    } finally {
      if (timer) clearTimeout(timer);
    }
  }

  return {
    async describe(api: any, eventOrData: any): Promise<StickerEnrichment | null> {
      const ref = extractStickerRef(eventOrData);
      if (!ref) return null;
      const detail = await lookupDetail(api, ref.id);
      const rawText = String(detail?.text ?? '').trim();
      const text =
        rawText && !INTERNAL_STICKER_CODE_RE.test(rawText) ? rawText : '';
      const label = text ? `[Nhãn dán: ${text}]` : '[Sticker]';
      const rawUrl = String(
        detail?.stickerUrl ?? detail?.stickerWebpUrl ?? detail?.uri ?? '',
      ).trim();
      const url = rawUrl
        ? rawUrl.startsWith('//')
          ? `https:${rawUrl}`
          : rawUrl
        : null;

      return {
        id: ref.id,
        catId: ref.catId,
        type: ref.type,
        text,
        label,
        url,
        attachment: url
          ? {
              kind: 'image',
              url,
              mimeType: 'image/png',
              name: `sticker_${ref.id}.png`,
              metadata: {
                stickerId: ref.id,
                ...(ref.catId ? { catId: ref.catId } : {}),
                ...(ref.type ? { stickerType: ref.type } : {}),
                ...(text ? { stickerText: text } : {}),
              },
            }
          : null,
      };
    },
    size(): number {
      return cache.size;
    },
  };
}

/**
 * When Zalo sends both a readable image URL (e.g. `/gr/jpg/<group>/<id>.jpg`) and
 * an unreadable JPEG XL URL (`/gr/jxl/<group>/<id>`) for the same `<group>`,
 * drop the `/gr/jxl/` duplicate while keeping `/gr/jxl/` if it is the only URL.
 */
export function preferReadableImageFormats<
  T extends { kind: string; url?: string },
>(attachments: T[]): T[] {
  if (attachments.length <= 1) return attachments;

  const parsed = attachments.map((item) => {
    if (item.kind !== 'image' || !item.url) {
      return { item, format: '', photoKey: '' };
    }
    const match = /\/gr\/([a-z0-9]+)\/([^/]+)(?:\/([^/?#]+))?/i.exec(item.url);
    if (!match) {
      return { item, format: '', photoKey: '' };
    }
    const format = (match[1] || '').toLowerCase();
    const group = match[2] || '';
    const rawLeaf = (match[3] || '').replace(/\.[a-z0-9]{1,5}$/i, '');
    const photoKey = rawLeaf ? `${group}/${rawLeaf}` : group;
    return {
      item,
      format,
      photoKey,
    };
  });

  const keysWithReadable = new Set(
    parsed
      .filter((entry) => entry.photoKey && entry.format && entry.format !== 'jxl')
      .map((entry) => entry.photoKey),
  );

  if (keysWithReadable.size === 0) return attachments;

  return parsed
    .filter(
      (entry) =>
        !(entry.format === 'jxl' && keysWithReadable.has(entry.photoKey)),
    )
    .map((entry) => entry.item);
}

const NON_MEDIA_MSG_TYPE_RE =
  /(recommended|webchat|chat\.text|poll|ecard|undo|sticker|link)/i;

const NON_MEDIA_MESSAGE_TYPES = new Set([
  'text',
  'link',
  'poll',
  'reminder',
  'contact_card',
  'system',
  'location',
  'sticker',
]);

/**
 * Denylist guard so non-media messages (`link` / `chat.recommended`, `poll`,
 * `ecard`, `undo`, `sticker`, etc.) never extract bogus `href` attachments,
 * while quoted messages with numeric `cliMsgType` still allow real image extraction.
 */
export function hasRealMedia(
  rawMsgType: unknown,
  messageType?: string,
): boolean {
  if (messageType && NON_MEDIA_MESSAGE_TYPES.has(messageType)) {
    return false;
  }
  const raw = String(rawMsgType ?? '').trim();
  if (raw && NON_MEDIA_MSG_TYPE_RE.test(raw)) {
    return false;
  }
  return true;
}

export function isFileMessage(
  rawMsgType: unknown,
  messageType?: string,
): boolean {
  if (messageType === 'file' || messageType === 'doc') return true;
  if (
    messageType === 'image' ||
    messageType === 'gif' ||
    messageType === 'video' ||
    messageType === 'voice'
  ) {
    return false;
  }
  return /(?:^|\.)(?:file|doc)/i.test(String(rawMsgType ?? '').trim());
}

/**
 * Extracts a 1..5 char alphanumeric file extension (without leading dot).
 * When given an `http(s)://` URL, inspects `new URL(input).pathname` so host
 * TLDs like `https://zalo.me` are never mistaken for file extensions.
 */
export function extensionOf(input: unknown): string {
  const raw = String(input ?? '').trim();
  if (!raw) return '';
  let candidate = raw;
  if (/^https?:\/\//i.test(raw)) {
    try {
      candidate = new URL(raw).pathname;
    } catch {
      candidate = raw.split(/[?#]/)[0] || '';
    }
  } else {
    candidate = raw.split(/[?#]/)[0] || '';
  }
  const match = /\.([A-Za-z0-9]{1,5})$/.exec(candidate);
  return match ? match[1].toLowerCase() : '';
}

export const MIME_BY_EXT: Readonly<Record<string, string>> = Object.freeze({
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  gif: 'image/gif',
  webp: 'image/webp',
  bmp: 'image/bmp',
  heic: 'image/heic',
  jxl: 'image/jxl',
  mp4: 'video/mp4',
  mov: 'video/quicktime',
  mkv: 'video/x-matroska',
  webm: 'video/webm',
  mp3: 'audio/mpeg',
  m4a: 'audio/mp4',
  aac: 'audio/aac',
  ogg: 'audio/ogg',
  wav: 'audio/wav',
  pdf: 'application/pdf',
  doc: 'application/msword',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  xls: 'application/vnd.ms-excel',
  xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ppt: 'application/vnd.ms-powerpoint',
  pptx: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  csv: 'text/csv',
  txt: 'text/plain',
  md: 'text/markdown',
  json: 'application/json',
  zip: 'application/zip',
  rar: 'application/vnd.rar',
  '7z': 'application/x-7z-compressed',
});

export function resolveAttachmentMimeType(
  fileExtOrNameOrUrl: string,
  kind: string,
): string {
  const trimmed = String(fileExtOrNameOrUrl ?? '').trim();
  const ext =
    /^[A-Za-z0-9]{1,5}$/.test(trimmed.replace(/^\./, ''))
      ? trimmed.replace(/^\./, '').toLowerCase()
      : extensionOf(trimmed);
  if (ext && MIME_BY_EXT[ext]) {
    return MIME_BY_EXT[ext];
  }
  if (kind === 'image') return 'image/jpeg';
  if (kind === 'file') return 'application/octet-stream';
  return '';
}

const ALREADY_FRIEND_CODES = new Set([222, 225]);

/**
 * Zalo friend-request error codes 222 (recipient already sent us a request;
 * sending back accepts it) and 225 (already friends) are idempotent successes.
 */
export function isAlreadyFriendErrorCode(err: unknown): boolean {
  if (!err || typeof err !== 'object') return false;
  const anyErr = err as Record<string, any>;
  const rawCode =
    anyErr.code ?? anyErr.data?.code ?? anyErr.details?.code ?? anyErr.error_code;
  const numCode = Number(rawCode);
  return Number.isInteger(numCode) && ALREADY_FRIEND_CODES.has(numCode);
}
