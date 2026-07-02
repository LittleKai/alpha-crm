import { getAgentCredentials } from './agent-identity.js';
import {
  fetchManagedGroups,
  reportOutboundMessage,
  reportOutboundMessageMetadata,
} from './cloud-api.js';

export interface OutboundReportEvent {
  accountId: string;
  threadId: string;
  threadType: 'user' | 'group';
  senderId: string;
  senderName?: string;
  displayName?: string;
  avatarUrl?: string;
  content: string;
  messageType?: string;
  providerMessageId?: string;
  clientMessageId?: string;
  timestamp?: string;
  attachments?: unknown;
}

let managedGroupCache: { expiresAt: number; keys: Set<string> } = {
  expiresAt: 0,
  keys: new Set(),
};

async function isGroupManaged(accountId: string, threadId: string): Promise<boolean> {
  const credentials = getAgentCredentials();
  if (!credentials) return false;

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

// Fire-and-forget report of an outbound message (operator send from the
// Desktop UI, or chatbot auto-reply) to the cloud so mobile/web clients see
// it via SSE (BE-6). Managed groups get the same metadata-only privacy
// treatment as inbound group messages — no content leaves the device.
export function reportOutboundMessageEvent(event: OutboundReportEvent): void {
  const credentials = getAgentCredentials();
  if (!credentials) return;

  void (async () => {
    try {
      if (event.threadType === 'group') {
        const isManaged = await isGroupManaged(event.accountId, event.threadId);
        if (!isManaged) return;
        await reportOutboundMessageMetadata(credentials.deviceId, credentials.agentSecret, event);
        return;
      }
      await reportOutboundMessage(credentials.deviceId, credentials.agentSecret, event);
    } catch (error) {
      console.warn(
        '[outbound-reporter] Failed to report outbound message:',
        error instanceof Error ? error.message : String(error),
      );
    }
  })();
}
