import { createRequire } from 'node:module';
import type { AgentCredentials } from './agent-identity.js';
import {
  fetchManagedGroups,
  fetchNextCommand,
  isDeviceRevokedError,
  reportCommandResult,
  reportInboundMessage,
  reportInboundMessageMetadata,
  sendHeartbeat,
  type HeartbeatZaloAccount,
} from './cloud-api.js';
import { executeCommand, getRunningCampaignCount } from './command-executor.js';
import { getZaloStatus, getAccounts } from '../zalo.js';
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

// The packaged release ships only dist/server.cjs (no package.json next to
// it), so this can't just `require('../../package.json')` at runtime in that
// context. scripts/bundle.mjs inlines CRM_AGENT_VERSION via esbuild `define`
// for the bundled build; unbundled dev/tsc runs fall back to reading the
// real package.json off disk, which is present in a full repo checkout.
function resolveAppVersion(): string {
  const injected = process.env.CRM_AGENT_VERSION;
  if (injected) return injected;
  try {
    const require = createRequire(import.meta.url);
    return (require('../../package.json') as { version: string }).version;
  } catch {
    return '0.0.0';
  }
}
const PACKAGE_VERSION = resolveAppVersion();

type RevocationHandler = (reason: string) => void | Promise<void>;

let running = false;
let pollingTimer: NodeJS.Timeout | null = null;
let heartbeatTimer: NodeJS.Timeout | null = null;
let revocationHandler: RevocationHandler | null = null;
let pollErrorCount = 0;
const BASE_POLL_DELAY_MS = 5000;
const MAX_POLL_DELAY_MS = 60000;
// How long the backend is asked to hold /agent/commands/next open when
// nothing is queued yet (long-poll), and how we detect an older backend
// that doesn't support waitMs and replies immediately instead of holding.
const LONG_POLL_WAIT_MS = 25000;
const LONG_POLL_FALLBACK_THRESHOLD_MS = 1000;
const LONG_POLL_FALLBACK_DELAY_MS = 3000;
// Already finer than the 15s target (BE-4 marks a device offline after 60s
// without a heartbeat), so no change needed here.
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
  // Diagnostic: trace each inbound message end-to-end. `providerAgeMs` is the lag
  // between the Zalo-reported timestamp and when this bridge received it — a large
  // value points at listener/zca-js delay rather than chatbot debounce.
  const providerTs = Date.parse(event.timestamp);
  console.log(
    `[chatbot-flow] recv acct=${event.accountId} thread=${event.threadId} ` +
      `type=${event.threadType}/${event.messageType} pmid=${event.providerMessageId ?? '-'} ` +
      `from=${event.senderId}` +
      (Number.isFinite(providerTs)
        ? ` providerAgeMs=${Date.now() - providerTs}`
        : ''),
  );
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
      // True when this event is an echo of a CRM/chatbot send (reconciled) or a
      // duplicate delivery — those were already reported to the cloud at send
      // time by outbound-reporter, so re-reporting would race the cloud's
      // providerMessageId dedupe and could double the message.
      let alreadyReportedAtSendTime = false;
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
        alreadyReportedAtSendTime = Boolean(reconciledId || existingProviderMessage);
        const localMessageId =
          reconciledId ||
          localStore.upsertInboundMessage({
            channel: event.channel,
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
        // manually. Defaults on. Each branch logs WHY a message did/didn't reach
        // the chatbot so dropped auto-replies can be diagnosed.
        if (reconciledId || existingProviderMessage) {
          // Echo of our own send or a duplicate — never a new inbound to answer.
        } else if (!isManaged) {
          console.log(
            `[chatbot-flow] skip chatbot pmid=${event.providerMessageId}: thread not managed`,
          );
        } else if (!localStore.isAccountAiAutoReplyEnabled(event.accountId)) {
          console.log(
            `[chatbot-flow] skip chatbot pmid=${event.providerMessageId}: AI auto-reply OFF for acct=${event.accountId}`,
          );
        } else {
          console.log(
            `[chatbot-flow] -> chatbot engage pmid=${event.providerMessageId}`,
          );
          handleChatbotInbound(event, event.threadType === 'group');
        }
      } catch (error: any) {
        console.error(
          '[agent-runner] Local store write failed; cloud report skipped:',
          error.message,
        );
        return;
      }

      // Relayed channels (Facebook/TikTok) already got a durable Mongo write
      // from the cloud webhook route before this event was relayed down via
      // CrmAgentCommand — reporting it again here would duplicate the message.
      const isRelayedChannel = Boolean(
        event.channel && event.channel !== 'zalo_personal' && event.channel !== 'zalo_oa',
      );

      if (isRelayedChannel) {
        // no-op: already durably recorded by the cloud webhook.
      } else if (alreadyReportedAtSendTime) {
        // Echo/duplicate of an already-reported send — skip the cloud report.
      } else if (event.threadType === 'group') {
        if (isManaged) {
          await reportInboundMessageMetadata(
            credentials.deviceId,
            credentials.agentSecret,
            event,
          );
        }
      } else {
        // 1:1 threads sync full content even in local-first mode so remote
        // (mobile/web) clients render real message bubbles. Group content
        // stays on this device — managed groups only ever send metadata.
        await reportInboundMessage(
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

function mapZaloAccountsForHeartbeat(): HeartbeatZaloAccount[] {
  try {
    return getAccounts()
      .map((account: any) => ({
        accountId: String(account?.id ?? ''),
        displayName: String(account?.label ?? ''),
        status: (account?.status === 'disconnected_expired' ? 'expired' : 'online') as HeartbeatZaloAccount['status'],
      }))
      .filter((account) => account.accountId);
  } catch (error) {
    console.warn(
      '[agent-runner] Failed to read Zalo accounts for heartbeat:',
      error instanceof Error ? error.message : String(error),
    );
    return [];
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
      appVersion: PACKAGE_VERSION,
      agentVersion: PACKAGE_VERSION,
      zaloAccounts: mapZaloAccountsForHeartbeat(),
      queueDepth: getRunningCampaignCount(),
      clientConnections: localChatEvents.listenerCount,
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
    const startedAt = Date.now();
    const command = await fetchNextCommand(
      credentials.deviceId,
      credentials.agentSecret,
      LONG_POLL_WAIT_MS,
    );
    const elapsedMs = Date.now() - startedAt;
    pollErrorCount = 0;
    if (!command || !running) {
      // No command was queued. A long-poll that actually held the request
      // open returns close to LONG_POLL_WAIT_MS later, so poll again right
      // away. A response that came back almost instantly means the backend
      // doesn't honor waitMs (older version) — fall back to a light poll
      // rhythm instead of hammering it.
      currentPollDelayMs = elapsedMs < LONG_POLL_FALLBACK_THRESHOLD_MS
        ? LONG_POLL_FALLBACK_DELAY_MS
        : 0;
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
