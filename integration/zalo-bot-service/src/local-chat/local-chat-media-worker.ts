import { createHash } from 'crypto';
import { mkdir, rename, unlink, writeFile } from 'fs/promises';
import { extname, resolve } from 'path';

import { localChatEvents } from './local-chat-events.js';
import { downloadExternalMedia } from './external-media.js';
import type { LocalChatStore } from './local-chat-store.js';
import type { LocalAttachment } from './local-chat-types.js';

const DEFAULT_CACHE_BYTES = 20 * 1024 * 1024 * 1024;
const DEFAULT_MAX_AGE_DAYS = 90;

const MIME_TO_EXT: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'image/gif': '.gif',
  'image/webp': '.webp',
  'image/bmp': '.bmp',
  'video/mp4': '.mp4',
  'video/quicktime': '.mov',
  'audio/mpeg': '.mp3',
  'audio/mp3': '.mp3',
  'audio/wav': '.wav',
  'audio/ogg': '.ogg',
  'audio/m4a': '.m4a',
  'application/pdf': '.pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': '.docx',
  'application/msword': '.doc',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '.xlsx',
  'application/vnd.ms-excel': '.xls',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation': '.pptx',
  'application/vnd.ms-powerpoint': '.ppt',
  'application/zip': '.zip',
  'application/x-zip-compressed': '.zip',
  'text/plain': '.txt',
  'text/html': '.html',
  'application/json': '.json',
};

// Adapted from https://github.com/luonghaianh1208/2anh-zalo-bot@9ab55105c83487588e66b55f0ef66894224250a7 (MIT License)
export function sniffMediaMimeType(
  buffer: Buffer,
  declaredContentType?: string,
): string {
  const rawType = String(declaredContentType ?? '')
    .split(';')[0]
    .trim()
    .toLowerCase();
  const normalized = rawType === 'image/jpg' ? 'image/jpeg' : rawType;

  if (
    normalized &&
    normalized !== 'application/octet-stream' &&
    normalized !== 'binary/octet-stream'
  ) {
    return normalized;
  }

  if (
    buffer.length >= 3 &&
    buffer[0] === 0xff &&
    buffer[1] === 0xd8 &&
    buffer[2] === 0xff
  ) {
    return 'image/jpeg';
  }
  if (
    buffer.length >= 8 &&
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47 &&
    buffer[4] === 0x0d &&
    buffer[5] === 0x0a &&
    buffer[6] === 0x1a &&
    buffer[7] === 0x0a
  ) {
    return 'image/png';
  }
  if (
    buffer.length >= 6 &&
    (buffer.toString('ascii', 0, 6) === 'GIF87a' ||
      buffer.toString('ascii', 0, 6) === 'GIF89a')
  ) {
    return 'image/gif';
  }
  if (
    buffer.length >= 12 &&
    buffer.toString('ascii', 0, 4) === 'RIFF' &&
    buffer.toString('ascii', 8, 12) === 'WEBP'
  ) {
    return 'image/webp';
  }
  if (buffer.length >= 26 && buffer.readUInt16BE(0) === 0x424d) {
    return 'image/bmp';
  }

  return normalized;
}

export class LocalChatMediaWorker {
  private timer: NodeJS.Timeout | null = null;
  private running = false;
  private maxCacheBytes = DEFAULT_CACHE_BYTES;
  private maxAgeDays = DEFAULT_MAX_AGE_DAYS;

  constructor(
    private readonly store: LocalChatStore,
    private readonly mediaDirectory: string,
  ) {}

  start(intervalMs = 15000): void {
    if (this.timer) return;
    void this.runOnce();
    this.timer = setInterval(() => void this.runOnce(), intervalMs);
  }

  stop(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  async runOnce(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      await mkdir(this.mediaDirectory, { recursive: true });
      for (const attachment of this.store.listPendingAttachments(5)) {
        await this.download(attachment);
      }
      await this.cleanup(this.maxCacheBytes, this.maxAgeDays);
    } finally {
      this.running = false;
    }
  }

  configure(maxGb: number, maxAgeDays: number): void {
    this.maxCacheBytes = Math.max(1, maxGb) * 1024 * 1024 * 1024;
    this.maxAgeDays = Math.max(1, maxAgeDays);
  }

  private async download(attachment: LocalAttachment): Promise<void> {
    this.store.updateAttachmentDownload(attachment.id, {
      status: 'downloading',
    });
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 20000);

    let extension = this.safeExtension(attachment);
    let temporary: string | null = null;
    try {
      const { buffer, contentType } = await downloadExternalMedia(attachment.url, controller.signal);
      const effectiveMimeType = sniffMediaMimeType(
        buffer,
        contentType || attachment.mimeType,
      );

      if (!extension) {
        extension = MIME_TO_EXT[effectiveMimeType] || '';
      }

      const kind = (attachment.kind || '').toLowerCase();
      const ext = extension.toLowerCase();

      const isMedia = kind === 'image' ||
        kind === 'video' ||
        kind === 'audio' ||
        effectiveMimeType.startsWith('image/') ||
        effectiveMimeType.startsWith('video/') ||
        effectiveMimeType.startsWith('audio/') ||
        ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.mp4', '.mov', '.avi', '.mp3', '.wav', '.ogg', '.m4a'].includes(ext);

      const subfolder = isMedia ? 'Media' : 'Files';
      const targetDir = resolve(this.mediaDirectory, subfolder);
      await mkdir(targetDir, { recursive: true });

      const target = resolve(targetDir, `${attachment.id}${extension}`);
      temporary = `${target}.part`;

      await writeFile(temporary, buffer);
      await rename(temporary, target);
      const checksum = createHash('sha256').update(buffer).digest('hex');
      this.store.updateAttachmentDownload(attachment.id, {
        status: 'ready',
        localPath: target,
        checksum,
        downloadedAt: new Date().toISOString(),
        sizeBytes: buffer.byteLength,
        ...(effectiveMimeType ? { mimeType: effectiveMimeType } : {}),
      });
      this.publish(attachment, 'media.ready', { localPath: target, checksum });
    } catch (error) {
      if (temporary) {
        await unlink(temporary).catch(() => {});
      }
      const message = error instanceof Error ? error.message : String(error);
      this.store.updateAttachmentDownload(attachment.id, {
        status: 'failed',
        errorText: message,
      });
      this.publish(attachment, 'media.failed', { error: message });
    } finally {
      clearTimeout(timeout);
    }
  }

  async cleanup(
    maxBytes = DEFAULT_CACHE_BYTES,
    maxAgeDays = DEFAULT_MAX_AGE_DAYS,
  ): Promise<{ removed: number; freedBytes: number }> {
    const rows = this.store.db
      .prepare(
        `SELECT id, localPath, sizeBytes, downloadedAt, createdAt
         FROM attachments
         WHERE status = 'ready' AND localPath != ''
         ORDER BY COALESCE(downloadedAt, createdAt) ASC`,
      )
      .all() as Array<{
        id: string;
        localPath: string;
        sizeBytes: number;
        downloadedAt: string;
        createdAt: string;
      }>;
    let totalBytes = rows.reduce((sum, row) => sum + Number(row.sizeBytes || 0), 0);
    let removed = 0;
    let freedBytes = 0;
    const cutoff = Date.now() - maxAgeDays * 86400000;
    for (const row of rows) {
      const timestamp = Date.parse(row.downloadedAt || row.createdAt);
      if (timestamp >= cutoff && totalBytes <= maxBytes) continue;
      await unlink(row.localPath).catch(() => {});
      this.store.db
        .prepare(
          `UPDATE attachments
           SET localPath = '', status = 'pending', checksum = '',
               downloadedAt = '', errorText = ''
           WHERE id = ?`,
        )
        .run(row.id);
      const bytes = Number(row.sizeBytes || 0);
      totalBytes -= bytes;
      freedBytes += bytes;
      removed += 1;
    }
    return { removed, freedBytes };
  }

  private publish(
    attachment: LocalAttachment,
    type: string,
    data: Record<string, unknown>,
  ): void {
    const message = this.store.db
      .prepare(
        `SELECT accountId, threadId FROM messages WHERE id = ?`,
      )
      .get(attachment.messageId) as
      | { accountId: string; threadId: string }
      | undefined;
    localChatEvents.publish({
      type,
      accountId: message?.accountId,
      threadId: message?.threadId,
      data: {
        attachmentId: attachment.id,
        messageId: attachment.messageId,
        ...data,
      },
    });
  }

  private safeExtension(attachment: LocalAttachment): string {
    try {
      if (attachment.name) {
        const ext = extname(attachment.name);
        if (/^[.][a-zA-Z0-9]{1,8}$/.test(ext)) {
          return ext;
        }
      }

      if (attachment.mimeType) {
        const typeOnly = attachment.mimeType.split(';')[0].trim().toLowerCase();
        const ext = MIME_TO_EXT[typeOnly];
        if (ext) {
          return ext;
        }
      }

      if (attachment.url) {
        const urlObj = new URL(attachment.url);
        for (const paramName of ['name', 'filename', 'file', 'title']) {
          const paramVal = urlObj.searchParams.get(paramName);
          if (paramVal) {
            const ext = extname(paramVal);
            if (/^[.][a-zA-Z0-9]{1,8}$/.test(ext)) {
              return ext;
            }
          }
        }

        const extension = extname(urlObj.pathname);
        if (/^[.][a-zA-Z0-9]{1,8}$/.test(extension)) {
          return extension;
        }
      }
      return '';
    } catch {
      return '';
    }
  }
}
