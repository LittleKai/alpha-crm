import type { AgentCredentials } from './agent-identity.js';
import {
  fetchManagedGroups,
  fetchNextCommand,
  isDeviceRevokedError,
  reportCommandResult,
  reportInboundMessage,
  reportInboundMessageMetadata,
  sendHeartbeat,
} from './cloud-api.js';
import { executeCommand } from './command-executor.js';
import { getZaloStatus } from '../zalo.js';
import { config } from '../config.js';
import {
  setInboundMessageBatchHandler,
  setInboundMessageHandler,
  type ZaloInboundMessageEvent,
} from '../channels/types.js';
import { dispatchN8nEvent } from '../integrations/n8n-event-dispatcher.js';
import { getLocalChatStore } from '../local-chat/index.js';
import { localChatEvents } from '../local-chat/local-chat-events.js';
import { handleChatbotInbound } from '../chatbot/index.js';

type RevocationHandler = (reason: string) => void | Promise<void>;

let running = false;
let pollingTimer: NodeJS.Timeout | null = null;
let heartbeatTimer: NodeJS.Timeout | null = null;
let revocationHandler: RevocationHandler | null = null;
let pollErrorCount = 0;
const BASE_POLL_DELAY_MS = 5000;
const MAX_POLL_DELAY_MS = 60000;
const HEARTBEAT_INTERVAL_MS = 10000;
let currentPollDelayMs = BASE_POLL_DELAY_MS;
let managedGroupCache: { expiresAt: number; keys: Set<string> } = {
  expiresAt: 0,
  keys: new Set(),
};

export function setAgentRevocationHandler(handler: RevocationHandler | null): void {
  revocationHandler = handler;
}

export function isAgentRunnerRunning(): boolean {
  return running;
}

export function startAgentRunner(credentials: AgentCredentials): void {
  if (config.crmAgentMode !== 'enabled') {
    console.log('[agent-runner] Agent runner mode is disabled in config.');
    return;
  }
  if (running) {
    return;
  }

  running = true;
  pollErrorCount = 0;
  currentPollDelayMs = BASE_POLL_DELAY_MS;
  managedGroupCache = { expiresAt: 0, keys: new Set() };
  setInboundMessageHandler((event) =>
    handleInboundMessageEvent(credentials, event),
  );
  setInboundMessageBatchHandler((events) =>
    handleInboundMessageBatch(credentials, events),
  );

  void runHeartbeat(credentials);
  heartbeatTimer = setInterval(() => {
    void runHeartbeat(credentials);
  }, HEARTBEAT_INTERVAL_MS);
  scheduleNextPoll(credentials);
}

export function stopAgentRunner(): void {
  if (!running && !pollingTimer && !heartbeatTimer) {
    setInboundMessageHandler(null);
    setInboundMessageBatchHandler(null);
    return;
  }
  running = false;
  setInboundMessageHandler(null);
  setInboundMessageBatchHandler(null);
  if (pollingTimer) {
    clearTimeout(pollingTimer);
    pollingTimer = null;
  }
  if (heartbeatTimer) {
    clearInterval(heartbeatTimer);
    heartbeatTimer = null;
  }
  console.log('[agent-runner] Outbound agent stopped.');
}

async function getManagedGroupKeys(
  credentials: AgentCredentials,
): Promise<Set<string>> {
  const now = Date.now();
  if (managedGroupCache.expiresAt > now) {
    return managedGroupCache.keys;
  }

  const groups = await fetchManagedGroups(
    credentials.deviceId,
    credentials.agentSecret,
  );
  const keys = new Set(
    groups.map((group) => `${group.accountId}:${group.groupId}`),
  );
  managedGroupCache = { expiresAt: now + 60000, keys };
  return keys;
}

async function handleInboundMessageBatch(
  credentials: AgentCredentials,
  events: ZaloInboundMessageEvent[],
): Promise<void> {
  if (!running) {
    return;
  }
  try {
    const managedKeys = events.some((event) => event.threadType === 'group')
      ? await getManagedGroupKeys(credentials)
      : new Set<string>();
    const accepted = events.filter(
      (event) =>
        event.threadType !== 'group' ||
        managedKeys.has(`${event.accountId}:${event.threadId}`),
    );
    if (accepted.length === 0 || !running) {
      return;
    }

    const localStore = getLocalChatStore();
    if (localStore) {
      const ids = localStore.upsertInboundMessages(
        accepted.map((event) => ({
          accountId: event.accountId,
          threadId: event.threadId,
          threadType: event.threadType,
          senderId: event.senderId,
          senderName: event.senderName || '',
          avatarUrl: event.avatarUrl,
          senderAvatarUrl: event.senderAvatarUrl,
          groupName: event.groupName,
          content: event.content,
          messageType: event.messageType,
          providerMessageId: event.providerMessageId,
          clientMessageId: event.clientMessageId,
          quote: event.quote,
          mentions: event.mentions,
          styles: event.styles,
          metadata: event.metadata,
          attachments: event.attachments,
          timestamp: event.timestamp,
        })),
      );
      accepted.forEach((event, index) => {
        localChatEvents.publish({
          type: 'message.created',
          accountId: event.accountId,
          threadId: event.threadId,
          data: {
            messageId: ids[index],
            providerMessageId: event.providerMessageId,
            clientMessageId: event.clientMessageId,
            history: true,
          },
        });
      });
      await Promise.all(
        accepted.map((event) =>
          reportInboundMessageMetadata(
            credentials.deviceId,
            credentials.agentSecret,
            event,
          ),
        ),
      );
    } else {
      await Promise.all(
        accepted.map((event) =>
          reportInboundMessage(
            credentials.deviceId,
            credentials.agentSecret,
            event,
          ),
        ),
      );
    }
    await Promise.all(
      accepted.map((event) => dispatchN8nEvent('zalo.message.inbound', event)),
    );
  } catch (error) {
    if (await handleCloudFailure(error)) {
      return;
    }
    console.warn(
      '[agent-runner] Failed to persist inbound history batch:',
      error instanceof Error ? error.message : String(error),
    );
  }
}

async function handleInboundMessageEvent(
  credentials: AgentCredentials,
  event: ZaloInboundMessageEvent,
): Promise<void> {
  if (!running) {
    return;
  }
  try {
    if (event.threadType === 'group') {
      const managedKeys = await getManagedGroupKeys(credentials);
      if (!managedKeys.has(`${event.accountId}:${event.threadId}`)) {
        return;
      }
    }

    const localStore = getLocalChatStore();
    if (localStore) {
      try {
        const existingProviderMessage = event.providerMessageId
          ? localStore.db
              .prepare(
                `SELECT id FROM messages
                 WHERE accountId = ? AND providerMessageId = ?`,
              )
              .get(event.accountId, event.providerMessageId)
          : undefined;
        const reconciledId =
          event.senderId === event.accountId && event.clientMessageId
            ? localStore.reconcileOutboundMessage({
                accountId: event.accountId,
                clientMessageId: event.clientMessageId,
                providerMessageId: event.providerMessageId,
                status: 'sent',
              })
            : undefined;
        const localMessageId =
          reconciledId ||
          localStore.upsertInboundMessage({
            accountId: event.accountId,
            threadId: event.threadId,
            threadType: event.threadType,
            senderId: event.senderId,
            senderName: event.senderName || '',
            avatarUrl: event.avatarUrl,
            senderAvatarUrl: event.senderAvatarUrl,
            groupName: event.groupName,
            content: event.content,
            messageType: event.messageType,
            providerMessageId: event.providerMessageId,
            clientMessageId: event.clientMessageId,
            quote: event.quote,
            mentions: event.mentions,
            styles: event.styles,
            metadata: event.metadata,
            attachments: event.attachments,
            timestamp: event.timestamp,
          });
        localChatEvents.publish({
          type: reconciledId ? 'message.updated' : 'message.created',
          accountId: event.accountId,
          threadId: event.threadId,
          data: {
            messageId: localMessageId,
            providerMessageId: event.providerMessageId,
            clientMessageId: event.clientMessageId,
          },
        });
        if (!reconciledId && !existingProviderMessage) {
          handleChatbotInbound(event, event.threadType === 'group');
        }
      } catch (error: any) {
        console.error(
          '[agent-runner] Local store write failed; cloud report skipped:',
          error.message,
        );
        return;
      }

      await reportInboundMessageMetadata(
        credentials.deviceId,
        credentials.agentSecret,
        event,
      );
    } else {
      await reportInboundMessage(
        credentials.deviceId,
        credentials.agentSecret,
        event,
      );
    }

    await dispatchN8nEvent('zalo.message.inbound', event);
  } catch (error: any) {
    if (await handleCloudFailure(error)) {
      return;
    }
    console.warn('[agent-runner] Failed to report inbound message:', error.message);
  }
}

async function runHeartbeat(credentials: AgentCredentials): Promise<void> {
  if (!running) {
    return;
  }
  try {
    const zaloStatus = getZaloStatus();
    await sendHeartbeat(credentials.deviceId, credentials.agentSecret, {
      status: zaloStatus.connected ? 'online' : 'offline',
      appVersion: '0.2.0',
      agentVersion: '0.2.0',
    });
  } catch (error: any) {
    if (await handleCloudFailure(error)) {
      return;
    }
    console.warn('[agent-runner] Heartbeat failed; session retained:', error.message);
  }
}

function scheduleNextPoll(credentials: AgentCredentials): void {
  if (!running) {
    return;
  }
  pollingTimer = setTimeout(async () => {
    await runPollStep(credentials);
    if (running) {
      scheduleNextPoll(credentials);
    }
  }, currentPollDelayMs);
}

async function runPollStep(credentials: AgentCredentials): Promise<void> {
  if (!running) {
    return;
  }
  try {
    const command = await fetchNextCommand(
      credentials.deviceId,
      credentials.agentSecret,
    );
    pollErrorCount = 0;
    currentPollDelayMs = BASE_POLL_DELAY_MS;
    if (!command || !running) {
      return;
    }

    try {
      const result = await executeCommand(
        command,
        credentials.deviceId,
        credentials.agentSecret,
      );
      if (running) {
        await reportCommandResult(
          credentials.deviceId,
          credentials.agentSecret,
          command._id,
          true,
          result,
        );
      }
    } catch (executionError: any) {
      if (running) {
        await reportCommandResult(
          credentials.deviceId,
          credentials.agentSecret,
          command._id,
          false,
          undefined,
          executionError.message,
        );
      }
    }
    currentPollDelayMs = 500;
  } catch (error: any) {
    if (await handleCloudFailure(error)) {
      return;
    }
    pollErrorCount += 1;
    currentPollDelayMs = Math.min(
      BASE_POLL_DELAY_MS * Math.pow(2, pollErrorCount - 1),
      MAX_POLL_DELAY_MS,
    );
    console.warn(
      `[agent-runner] Poll failed; retrying in ${currentPollDelayMs / 1000}s:`,
      error.message,
    );
  }
}

async function handleCloudFailure(error: unknown): Promise<boolean> {
  if (!isDeviceRevokedError(error)) {
    return false;
  }
  stopAgentRunner();
  await revocationHandler?.('This PC session was replaced by another Windows PC.');
  return true;
}
