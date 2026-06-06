import { createHash } from 'crypto';
import { mkdir, rename, unlink, writeFile } from 'fs/promises';
import { extname, resolve } from 'path';

import { localChatEvents } from './local-chat-events.js';
import type { LocalChatStore } from './local-chat-store.js';
import type { LocalAttachment } from './local-chat-types.js';

const MAX_MEDIA_BYTES = 25 * 1024 * 1024;

export class LocalChatMediaWorker {
  private timer: NodeJS.Timeout | null = null;
  private running = false;

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
    } finally {
      this.running = false;
    }
  }

  private async download(attachment: LocalAttachment): Promise<void> {
    this.store.updateAttachmentDownload(attachment.id, {
      status: 'downloading',
    });
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 20000);
    const extension = this.safeExtension(attachment);
    const target = resolve(this.mediaDirectory, `${attachment.id}${extension}`);
    const temporary = `${target}.part`;
    try {
      const response = await fetch(attachment.url, {
        signal: controller.signal,
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const declaredSize = Number(response.headers.get('content-length') || 0);
      if (declaredSize > MAX_MEDIA_BYTES) {
        throw new Error('Media exceeds the 25 MB local cache limit.');
      }
      const buffer = Buffer.from(await response.arrayBuffer());
      if (buffer.byteLength > MAX_MEDIA_BYTES) {
        throw new Error('Media exceeds the 25 MB local cache limit.');
      }
      await writeFile(temporary, buffer);
      await rename(temporary, target);
      const checksum = createHash('sha256').update(buffer).digest('hex');
      this.store.updateAttachmentDownload(attachment.id, {
        status: 'ready',
        localPath: target,
        checksum,
        downloadedAt: new Date().toISOString(),
      });
      this.publish(attachment, 'media.ready', { localPath: target, checksum });
    } catch (error) {
      await unlink(temporary).catch(() => {});
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
      const extension = extname(new URL(attachment.url).pathname);
      return /^[.][a-zA-Z0-9]{1,8}$/.test(extension) ? extension : '';
    } catch {
      return '';
    }
  }
}
