/**
 * Shared singleton for the local chat SQLite store.
 * Initializes lazily based on config.localFirstLiveChat.
 * Also wires the undo (message recall) handler from the listener into the store.
 */

import { resolve } from 'path';
import { config, projectRoot, dataRoot } from '../config.js';
import { LocalChatStore } from './local-chat-store.js';
import {
  setAuxiliaryEventHandler,
  setUndoMessageHandler,
  setStatusMessageHandler,
} from '../channels/personal-zca-channel.js';
import { localChatEvents } from './local-chat-events.js';
import { LocalChatMediaWorker } from './local-chat-media-worker.js';
import { readMediaCacheSettings } from './media-cache-store.js';

let _store: LocalChatStore | null = null;
let _mediaWorker: LocalChatMediaWorker | null = null;

/**
 * Returns the shared LocalChatStore instance, or null if local-first is disabled.
 */
export function getLocalChatStore(): LocalChatStore | null {
  if (!config.localFirstLiveChat) return null;

  if (!_store) {
    const dbPath = resolve(projectRoot, config.localChatDbPath);
    _store = new LocalChatStore(dbPath);
    _mediaWorker = new LocalChatMediaWorker(
      _store,
      resolve(dataRoot, 'local-chat-media'),
    );
    // Nạp lại hạn mức đã lưu TRƯỚC khi worker chạy vòng dọn đầu tiên, nếu không
    // nó dọn theo mặc định 20GB/90 ngày dù người dùng đã đặt khác.
    const mediaSettings = readMediaCacheSettings();
    _mediaWorker.configure(mediaSettings.maxGb, mediaSettings.maxAgeDays);
    _mediaWorker.start();
    console.log(
      `[local-chat] Initialized SQLite store at ${dbPath} ` +
        `(media cache ${mediaSettings.maxGb}GB / ${mediaSettings.maxAgeDays} ngày)`,
    );

    // Wire undo handler so listener recall events update local DB
    setUndoMessageHandler((_accountId: string, zaloMsgId: string) => {
      if (_store) {
        const deleted = _store.markMessageDeletedByProviderMsgId(zaloMsgId);
        if (deleted) {
          console.log(`[local-chat] Undo: marked message ${zaloMsgId} as deleted in local DB.`);
        } else {
          console.log(`[local-chat] Undo: message ${zaloMsgId} not found in local DB.`);
        }
      }
    });

    // Wire status handler for seen/delivered receipts
    setStatusMessageHandler((_accountId: string, zaloMsgId: string, status: 'seen' | 'delivered') => {
      if (_store) {
        _store.updateMessageStatusByProviderId(zaloMsgId, status);
      }
    });

    setAuxiliaryEventHandler((event) => {
      if (!_store) return;
      _store.appendZaloEvent({
        type: event.type,
        accountId: event.accountId,
        threadId: event.threadId,
        data: {
          ...event.data,
          providerMessageId: event.providerMessageId,
          clientMessageId: event.clientMessageId,
          userId: event.userId,
          reaction: event.reaction,
        },
        timestamp: event.timestamp,
      });
      if (
        (event.type === 'message.seen' ||
          event.type === 'message.delivered') &&
        event.providerMessageId
      ) {
        _store.upsertReceipt({
          accountId: event.accountId,
          providerMessageId: event.providerMessageId,
          userId: event.userId || event.threadId,
          status: event.type === 'message.seen' ? 'seen' : 'delivered',
          timestamp: event.timestamp,
        });
      } else if (
        event.type === 'message.reaction' &&
        event.providerMessageId
      ) {
        _store.upsertReaction({
          accountId: event.accountId,
          providerMessageId: event.providerMessageId,
          userId: event.userId || event.threadId,
          reaction: event.reaction || '',
          timestamp: event.timestamp,
        });
      } else if (
        event.type === 'message.recalled' ||
        event.type === 'message.deleted'
      ) {
        if (event.providerMessageId) {
          _store.markMessageDeletedByProviderMsgId(event.providerMessageId);
        } else if (event.clientMessageId) {
          const row = _store.db
            .prepare(
              `SELECT id FROM messages
               WHERE accountId = ? AND clientMessageId = ?`,
            )
            .get(event.accountId, event.clientMessageId) as
            | { id: string }
            | undefined;
          if (row) _store.markMessageDeleted(row.id);
        }
      }
      localChatEvents.publish({
        type: event.type,
        accountId: event.accountId,
        threadId: event.threadId,
        data: {
          ...event.data,
          providerMessageId: event.providerMessageId,
          clientMessageId: event.clientMessageId,
          userId: event.userId,
          reaction: event.reaction,
        },
      });
    });
  }
  return _store;
}

export function configureLocalChatMediaCache(
  maxGb: number,
  maxAgeDays: number,
): void {
  getLocalChatStore();
  _mediaWorker?.configure(maxGb, maxAgeDays);
}

/**
 * Close the store (for graceful shutdown).
 */
export function closeLocalChatStore(): void {
  if (_store) {
    _mediaWorker?.stop();
    _mediaWorker = null;
    _store.close();
    _store = null;
    setUndoMessageHandler(null);
    setStatusMessageHandler(null);
    setAuxiliaryEventHandler(null);
    console.log('[local-chat] SQLite store closed.');
  }
}
