import { getLocalChatStore } from './index.js';
import { getAgentCredentials } from '../agent/agent-identity.js';
import { reportInboundMessageMetadata, reportInboundMessage } from '../agent/cloud-api.js';
import { isDeviceRevokedError } from '../agent/cloud-api.js';

const SYNC_INTERVAL_MS = 5000; // Poll every 5 seconds
const MAX_RETRY_COUNT = 10;

let _timer: NodeJS.Timeout | null = null;
let _isRunning = false;
let _enabled = false;
let _revocationHandler: ((reason: string) => void | Promise<void>) | null = null;

export function setSyncRevocationHandler(
  handler: ((reason: string) => void | Promise<void>) | null,
): void {
  _revocationHandler = handler;
}

export function isBackgroundSyncRunning(): boolean {
  return _timer !== null;
}

export function startBackgroundSync(): void {
  if (_timer) return;
  _enabled = true;
  console.log('[sync-worker] Starting background sync worker...');
  _timer = setInterval(processSyncQueue, SYNC_INTERVAL_MS);
}

export function stopBackgroundSync(): void {
  _enabled = false;
  if (_timer) {
    clearInterval(_timer);
    _timer = null;
    console.log('[sync-worker] Stopped background sync worker.');
  }
  _isRunning = false;
}

async function processSyncQueue(): Promise<void> {
  if (_isRunning || !_enabled) return;
  
  const store = getLocalChatStore();
  if (!store) return;

  const credentials = getAgentCredentials();
  if (!credentials) return; // Cannot sync without agent credentials

  const actions = store.getPendingSyncActions(20);
  if (actions.length === 0) return;

  _isRunning = true;

  for (const actionRow of actions) {
    if (!_enabled) break;
    try {
      const payload = JSON.parse(actionRow.payloadJson);
      
      if (actionRow.action === 'sync_message') {
        const msgId = payload.messageId;
        const msg = store.db
          .prepare('SELECT * FROM messages WHERE id = ?')
          .get(msgId) as any;
        
        if (msg) {
          // Construct payload matching ZaloInboundMessageEvent for Cloud API
          const event = {
            accountId: msg.accountId,
            threadId: msg.threadId,
            threadType: msg.threadType,
            senderId: msg.senderId,
            senderName: msg.senderName,
            avatarUrl: msg.senderAvatarUrl,
            content: msg.content,
            messageType: msg.messageType,
            providerMessageId: msg.providerMessageId,
            timestamp: msg.sentAt || msg.receivedAt || msg.createdAt,
            direction: msg.direction,
            status: msg.status,
            isDeleted: msg.isDeleted === 1,
            localFirst: true
          };

          // Send to cloud
          await reportInboundMessage(credentials.deviceId, credentials.agentSecret, event);
        }
      } else if (actionRow.action === 'sync_conversation') {
        const convId = payload.conversationId;
        const conv = store.db
          .prepare('SELECT * FROM conversations WHERE id = ?')
          .get(convId) as any;
        
        if (conv) {
          // Send metadata update
          const metadata = {
            accountId: conv.accountId,
            threadId: conv.threadId,
            threadType: conv.threadType,
            displayName: conv.displayName,
            avatarUrl: conv.avatarUrl,
            lastMessagePreview: conv.lastMessagePreview,
            lastMessageAt: conv.lastMessageAt,
            unreadCountDelta: 0, // Since we just sync absolute state or 0
            unreadCount: conv.unreadCount, // If cloud supports absolute
            messageType: 'text',
            bridgeDeviceId: credentials.deviceId,
            localFirst: true
          };
          await reportInboundMessageMetadata(credentials.deviceId, credentials.agentSecret, metadata);
        }
      }

      // Mark complete
      if (!_enabled) break;
      store.markSyncActionComplete(actionRow.id);
      console.log(`[sync-worker] Synced action ${actionRow.action} (ID: ${actionRow.id}) successfully.`);
    } catch (err: any) {
      if (isDeviceRevokedError(err)) {
        stopBackgroundSync();
        await _revocationHandler?.('This PC session was replaced by another Windows PC.');
        break;
      }
      console.error(`[sync-worker] Failed to sync action ${actionRow.id}:`, err.message);
      if (actionRow.retryCount >= MAX_RETRY_COUNT) {
        console.error(`[sync-worker] Action ${actionRow.id} exceeded max retries. Marking failed forever.`);
        store.markSyncActionFailed(actionRow.id, new Date(Date.now() + 1000 * 60 * 60 * 24 * 365).toISOString()); // Retry in 1 year (effectively dead)
      } else {
        // Exponential backoff
        const backoffMs = Math.pow(2, actionRow.retryCount) * 2000; 
        const nextRetryAt = new Date(Date.now() + backoffMs).toISOString();
        store.markSyncActionFailed(actionRow.id, nextRetryAt);
      }
    }
  }

  _isRunning = false;
}
