/**
 * Shared singleton for the local chat SQLite store.
 * Initializes lazily based on config.localFirstLiveChat.
 */

import { resolve } from 'path';
import { config, projectRoot } from '../config.js';
import { LocalChatStore } from './local-chat-store.js';

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
    console.log('[local-chat] SQLite store closed.');
  }
}
