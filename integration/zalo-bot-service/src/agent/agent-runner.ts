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
import { handleChatbotInbound, pauseChatbotForOperatorReply } from '../chatbot/index.js';

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
    // The managed-group set comes from a CLOUD fetch. It must NEVER block or drop
    // local storage — otherwise a cloud hiccup silently loses every group message
    // (1:1 messages skip this call, which is why they kept working). Default to an
    // empty set on failure so local storage proceeds; only cloud/n8n gating cares.
    let managedKeys = new Set<string>();
    if (events.some((event) => event.threadType === 'group')) {
      try {
        managedKeys = await getManagedGroupKeys(credentials);
      } catch (err) {
        console.warn(
          '[agent-runner] managed-group lookup failed; storing groups locally as unmanaged:',
          err instanceof Error ? err.message : String(err),
        );
      }
    }
    const isManaged = (event: ZaloInboundMessageEvent) =>
      event.threadType !== 'group' ||
      managedKeys.has(`${event.accountId}:${event.threadId}`);

    const localStore = getLocalChatStore();
    if (localStore) {
      // Local-first inbox stores EVERY thread (including unmanaged groups) so the
      // conversation list populates naturally like a messenger. Cloud reporting,
      // n8n dispatch, and chatbot remain gated to managed groups below.
      if (events.length === 0 || !running) {
        return;
      }
      const ids = localStore.upsertInboundMessages(
        events.map((event) => ({
          accountId: event.accountId,
          threadId: event.threadId,
          threadType: event.threadType,
          // Self-sent history (operator's own phone messages) renders outbound.
          direction:
            event.senderId === event.accountId
              ? ('outbound' as const)
              : ('inbound' as const),
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
      events.forEach((event, index) => {
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
      const reportable = events.filter(isManaged);
      await Promise.all(
        reportable.map((event) =>
          reportInboundMessageMetadata(
            credentials.deviceId,
            credentials.agentSecret,
            event,
          ),
        ),
      );
      await Promise.all(
        reportable.map((event) =>
          dispatchN8nEvent('zalo.message.inbound', event),
        ),
      );
    } else {
      const accepted = events.filter(isManaged);
      if (accepted.length === 0 || !running) {
        return;
      }
      await Promise.all(
        accepted.map((event) =>
          reportInboundMessage(
            credentials.deviceId,
            credentials.agentSecret,
            event,
          ),
        ),
      );
      await Promise.all(
        accepted.map((event) => dispatchN8nEvent('zalo.message.inbound', event)),
      );
    }
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
    // Resolve managed status WITHOUT letting the cloud fetch drop the message.
    // A group message must still be stored locally even if the managed-group
    // lookup fails (previously this threw and the whole handler bailed, which is
    // why live group messages never landed while 1:1 messages did).
    let isManaged = true;
    if (event.threadType === 'group') {
      try {
        isManaged = (await getManagedGroupKeys(credentials)).has(
          `${event.accountId}:${event.threadId}`,
        );
      } catch (err) {
        console.warn(
          '[agent-runner] managed-group lookup failed; storing group locally as unmanaged:',
          err instanceof Error ? err.message : String(err),
        );
        isManaged = false;
      }
    }

    const localStore = getLocalChatStore();
    if (localStore) {
      // Store every thread locally (including unmanaged groups) so the inbox
      // populates naturally. Chatbot, cloud report and n8n stay gated to
      // managed groups below.
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
            // Self-sent live messages (operator's own phone) render outbound.
            direction:
              event.senderId === event.accountId
                ? ('outbound' as const)
                : ('inbound' as const),
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
        // Operator replied from their phone (a genuine self-sent message, NOT an
        // echo of a CRM/chatbot send which would be reconciled) → pause the bot for
        // the cooldown so AI doesn't talk over the human.
        if (
          event.senderId === event.accountId &&
          !reconciledId &&
          !existingProviderMessage
        ) {
          pauseChatbotForOperatorReply(event.accountId, event.threadId);
        }
        // Per-account AI auto-reply switch (Live Chat settings). When off, this
        // account never auto-engages incoming messages — the operator replies
        // manually. Defaults on.
        if (
          !reconciledId &&
          !existingProviderMessage &&
          isManaged &&
          localStore.isAccountAiAutoReplyEnabled(event.accountId)
        ) {
          handleChatbotInbound(event, event.threadType === 'group');
        }
      } catch (error: any) {
        console.error(
          '[agent-runner] Local store write failed; cloud report skipped:',
          error.message,
        );
        return;
      }

      if (isManaged) {
        await reportInboundMessageMetadata(
          credentials.deviceId,
          credentials.agentSecret,
          event,
        );
      }
    } else {
      if (!isManaged) {
        return;
      }
      await reportInboundMessage(
        credentials.deviceId,
        credentials.agentSecret,
        event,
      );
    }

    if (isManaged) {
      await dispatchN8nEvent('zalo.message.inbound', event);
    }
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
