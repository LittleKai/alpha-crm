/**
 * Shared singleton for the local chat SQLite store.
 * Initializes lazily based on config.localFirstLiveChat.
 * Also wires the undo (message recall) handler from the listener into the store.
 */

import { resolve } from 'path';
import { config, projectRoot } from '../config.js';
import { LocalChatStore } from './local-chat-store.js';
import { setUndoMessageHandler, setStatusMessageHandler } from '../channels/personal-zca-channel.js';

let _store: LocalChatStore | null = null;

/**
 * Returns the shared LocalChatStore instance, or null if local-first is disabled.
 */
export function getLocalChatStore(): LocalChatStore | null {
  if (!config.localFirstLiveChat) return null;

  if (!_store) {
    const dbPath = resolve(projectRoot, config.localChatDbPath);
    _store = new LocalChatStore(dbPath);
    console.log(`[local-chat] Initialized SQLite store at ${dbPath}`);

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
  }
  return _store;
}

/**
 * Close the store (for graceful shutdown).
 */
export function closeLocalChatStore(): void {
  if (_store) {
    _store.close();
    _store = null;
    setUndoMessageHandler(null);
    setStatusMessageHandler(null);
    console.log('[local-chat] SQLite store closed.');
  }
}
