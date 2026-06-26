import { createHash } from 'crypto';
import { mkdir, rename, unlink, writeFile } from 'fs/promises';
import { extname, resolve } from 'path';

import { localChatEvents } from './local-chat-events.js';
import type { LocalChatStore } from './local-chat-store.js';
import type { LocalAttachment } from './local-chat-types.js';

const MAX_MEDIA_BYTES = 500 * 1024 * 1024;
const DEFAULT_CACHE_BYTES = 20 * 1024 * 1024 * 1024;
const DEFAULT_MAX_AGE_DAYS = 90;

const MIME_TO_EXT: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'image/gif': '.gif',
  'image/webp': '.webp',
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
      const response = await fetch(attachment.url, {
        signal: controller.signal,
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const declaredSize = Number(response.headers.get('content-length') || 0);
      if (declaredSize > MAX_MEDIA_BYTES) {
        throw new Error('Media exceeds the 500 MB local cache limit.');
      }
      const buffer = Buffer.from(await response.arrayBuffer());
      if (buffer.byteLength > MAX_MEDIA_BYTES) {
        throw new Error('Media exceeds the 500 MB local cache limit.');
      }

      const contentType = (response.headers.get('content-type') || '').toLowerCase();
      
      // Fallback: If extension was not found from name, mimeType, or URL, map from content-type header
      if (!extension) {
        const typeOnly = contentType.split(';')[0].trim();
        extension = MIME_TO_EXT[typeOnly] || '';
        console.log(`[LocalChatMediaWorker] Extension fallback from Content-Type: "${contentType}" -> "${extension}"`);
      }

      // Determine content subfolder for auto-saving the cache file
      const kind = (attachment.kind || '').toLowerCase();
      const ext = extension.toLowerCase();
      
      const isMedia = kind === 'image' ||
        kind === 'video' ||
        kind === 'audio' ||
        contentType.startsWith('image/') ||
        contentType.startsWith('video/') ||
        contentType.startsWith('audio/') ||
        ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.mp4', '.mov', '.avi', '.mp3', '.wav', '.ogg', '.m4a'].includes(ext);

      const subfolder = isMedia ? 'Media' : 'Files';
      const targetDir = resolve(this.mediaDirectory, subfolder);
      await mkdir(targetDir, { recursive: true });

      const target = resolve(targetDir, `${attachment.id}${extension}`);
      temporary = `${target}.part`;

      // Debug logs for verifying the downloaded cache file attributes
      console.log(`[LocalChatMediaWorker] Auto-caching attachment id: ${attachment.id}`);
      console.log(`  - Display Name: "${attachment.name}"`);
      console.log(`  - Content-Type: "${contentType}"`);
      console.log(`  - Inferred Extension: "${extension}"`);
      console.log(`  - Target Path: "${target}"`);

      await writeFile(temporary, buffer);
      await rename(temporary, target);
      const checksum = createHash('sha256').update(buffer).digest('hex');
      this.store.updateAttachmentDownload(attachment.id, {
        status: 'ready',
        localPath: target,
        checksum,
        downloadedAt: new Date().toISOString(),
        sizeBytes: buffer.byteLength,
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
    console.log(`[LocalChatMediaWorker] safeExtension check for attachment:`, {
      id: attachment.id,
      name: attachment.name,
      mimeType: attachment.mimeType,
      url: attachment.url,
    });
    try {
      // 1. Try to extract from the attachment display name (e.g. "document.pdf")
      if (attachment.name) {
        const ext = extname(attachment.name);
        if (/^[.][a-zA-Z0-9]{1,8}$/.test(ext)) {
          console.log(`  - Found extension from name: "${ext}"`);
          return ext;
        }
      }
      
      // 2. Try to extract from the attachment.mimeType
      if (attachment.mimeType) {
        const typeOnly = attachment.mimeType.split(';')[0].trim().toLowerCase();
        const ext = MIME_TO_EXT[typeOnly];
        if (ext) {
          console.log(`  - Found extension from mimeType "${attachment.mimeType}": "${ext}"`);
          return ext;
        }
      }

      // 3. Parse URL to check query params (e.g. ?name=doc.pdf or ?file=doc.pdf)
      if (attachment.url) {
        const urlObj = new URL(attachment.url);
        for (const paramName of ['name', 'filename', 'file', 'title']) {
          const paramVal = urlObj.searchParams.get(paramName);
          if (paramVal) {
            const ext = extname(paramVal);
            if (/^[.][a-zA-Z0-9]{1,8}$/.test(ext)) {
              console.log(`  - Found extension from URL query param "${paramName}": "${ext}"`);
              return ext;
            }
          }
        }

        // 4. Fall back to the URL pathname extension
        const extension = extname(urlObj.pathname);
        if (/^[.][a-zA-Z0-9]{1,8}$/.test(extension)) {
          console.log(`  - Found extension from URL pathname: "${extension}"`);
          return extension;
        }
      }
      console.log(`  - No extension found`);
      return '';
    } catch (err) {
      console.log(`  - Error in safeExtension:`, err);
      return '';
    }
  }
}
