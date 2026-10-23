import { getLocalChatStore } from './index.js';
import { getAgentCredentials, type AgentCredentials } from '../agent/agent-identity.js';
import {
  fetchManagedGroups,
  reportInboundMessageMetadata,
  reportInboundMessage,
  reportOutboundMessage,
  reportOutboundMessageMetadata,
  isDeviceRevokedError,
} from '../agent/cloud-api.js';

const SYNC_INTERVAL_MS = 5000; // Poll every 5 seconds
const MAX_RETRY_COUNT = 10;

let _timer: NodeJS.Timeout | null = null;
let _isRunning = false;
let _enabled = false;
let _revocationHandler: ((reason: string) => void | Promise<void>) | null = null;

let managedGroupCache: { expiresAt: number; keys: Set<string> } = {
  expiresAt: 0,
  keys: new Set(),
};

async function isGroupManaged(
  credentials: AgentCredentials,
  accountId: string,
  threadId: string,
): Promise<boolean> {
  const now = Date.now();
  if (managedGroupCache.expiresAt <= now) {
    const groups = await fetchManagedGroups(credentials.deviceId, credentials.agentSecret);
    managedGroupCache = {
      expiresAt: now + 60000,
      keys: new Set(groups.map((group) => `${group.accountId}:${group.groupId}`)),
    };
  }
  return managedGroupCache.keys.has(`${accountId}:${threadId}`);
}

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
          // Group message content MUST NEVER leave the device (privacy rule).
          // Only managed groups report metadata; 1:1 threads report inbound/outbound according to direction.
          if (msg.threadType === 'group') {
            const managed = await isGroupManaged(credentials, msg.accountId, msg.threadId);
            if (managed) {
              const metaEvent = {
                accountId: msg.accountId,
                threadId: msg.threadId,
                threadType: 'group' as const,
                senderId: msg.senderId,
                senderName: msg.senderName,
                avatarUrl: msg.senderAvatarUrl,
                content: '',
                messageType: msg.messageType,
                providerMessageId: msg.providerMessageId,
                clientMessageId: msg.clientMessageId,
                timestamp: msg.sentAt || msg.receivedAt || msg.createdAt,
              };
              if (msg.direction === 'outbound') {
                await reportOutboundMessageMetadata(credentials.deviceId, credentials.agentSecret, metaEvent);
              } else {
                await reportInboundMessageMetadata(credentials.deviceId, credentials.agentSecret, metaEvent);
              }
            }
          } else if (msg.direction === 'outbound') {
            // Only sync outbound messages after they have actually been sent
            if (msg.status === 'sent') {
              await reportOutboundMessage(credentials.deviceId, credentials.agentSecret, {
                channel: msg.channel,
                accountId: msg.accountId,
                threadId: msg.threadId,
                threadType: 'user',
                senderId: msg.senderId || msg.accountId,
                senderName: msg.senderName,
                avatarUrl: msg.senderAvatarUrl,
                content: msg.content,
                messageType: msg.messageType,
                providerMessageId: msg.providerMessageId,
                clientMessageId: msg.clientMessageId,
                timestamp: msg.sentAt || msg.createdAt,
              });
            }
          } else {
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
              localFirst: true,
            };
            await reportInboundMessage(credentials.deviceId, credentials.agentSecret, event);
          }
        }
      } else if (actionRow.action === 'sync_conversation') {
        const convId = payload.conversationId;
        const conv = store.db
          .prepare('SELECT * FROM conversations WHERE id = ?')
          .get(convId) as any;

        if (conv) {
          const isGroup = conv.threadType === 'group';
          const canSync = !isGroup || await isGroupManaged(credentials, conv.accountId, conv.threadId);
          if (canSync) {
            const metadata = {
              accountId: conv.accountId,
              threadId: conv.threadId,
              threadType: conv.threadType,
              displayName: conv.displayName,
              avatarUrl: conv.avatarUrl,
              // Never upload group message preview text to cloud
              lastMessagePreview: isGroup ? '' : conv.lastMessagePreview,
              lastMessageAt: conv.lastMessageAt,
              unreadCountDelta: 0,
              unreadCount: conv.unreadCount,
              messageType: 'text',
              bridgeDeviceId: credentials.deviceId,
              localFirst: true,
            };
            await reportInboundMessageMetadata(credentials.deviceId, credentials.agentSecret, metadata);
          }
        }
      }

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
        store.markSyncActionFailed(actionRow.id, new Date(Date.now() + 1000 * 60 * 60 * 24 * 365).toISOString());
      } else {
        const backoffMs = Math.pow(2, actionRow.retryCount) * 2000;
        const nextRetryAt = new Date(Date.now() + backoffMs).toISOString();
        store.markSyncActionFailed(actionRow.id, nextRetryAt);
      }
    }
  }

  _isRunning = false;
}
