import { config } from '../config.js';

export interface CommandResponse {
  _id: string;
  type: string;
  payload: any;
  idempotencyKey?: string;
}

export interface ManagedGroupResponse {
  _id: string;
  accountId: string;
  groupId: string;
  name?: string;
}

export interface PairingResponse {
  sessionId: string;
  pairingCode: string;
  qrToken: string;
  expiresAt: string;
}

export class CloudApiError extends Error {
  constructor(
    message: string,
    public readonly status: number,
    public readonly code?: string,
    public readonly data: unknown = null,
  ) {
    super(message);
    this.name = 'CloudApiError';
  }
}

export function isDeviceRevokedError(error: unknown): boolean {
  return error instanceof CloudApiError
    && error.status === 403
    && error.code === 'DEVICE_REVOKED';
}

export async function callCloudApi(
  path: string,
  options: RequestInit,
  timeoutMs?: number,
): Promise<any> {
  const url = `${config.crmCloudApiUrl}${path}`;
  try {
    const response = await fetch(url, {
      ...options,
      signal: timeoutMs ? AbortSignal.timeout(timeoutMs) : options.signal,
    });
    const body: any = await response.json().catch(() => null);
    if (!response.ok || !body?.success) {
      throw new CloudApiError(
        body?.message || `Cloud API error (${response.status})`,
        response.status,
        body?.code,
        body?.data,
      );
    }
    return body.data;
  } catch (error: any) {
    console.error(`[cloud-api] Call to ${path} failed:`, error.message);
    if (error.cause) {
      console.error(`[cloud-api] Error cause detail:`, error.cause);
    }
    throw error;
  }
}

export async function verifyCloudIdentity(userJwt: string): Promise<{ userId: string }> {
  const data = await callCloudApi('/auth/me', {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${userJwt}`,
    },
  });
  const user = data?.user ?? data;
  const userId = user?._id ?? user?.id;
  if (typeof userId !== 'string' || userId.length === 0) {
    throw new CloudApiError(
      'Cloud identity response is missing a user ID.',
      502,
      'INVALID_IDENTITY_RESPONSE',
    );
  }
  return { userId };
}

export async function registerDevice(
  userJwt: string,
  displayName: string,
  machineFingerprint: string,
): Promise<{ deviceId: string; agentSecret: string }> {
  return callCloudApi('/crm/devices/register', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${userJwt}`,
    },
    body: JSON.stringify({
      machineFingerprint,
      displayName,
      platform: 'windows',
      agentVersion: '0.2.0',
    }),
  });
}

export async function forceReplaceDevice(
  userJwt: string,
  displayName: string,
  machineFingerprint: string,
): Promise<{ deviceId: string; agentSecret: string }> {
  return callCloudApi('/crm/devices/force-logout-old', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${userJwt}`,
    },
    body: JSON.stringify({
      machineFingerprint,
      displayName,
      platform: 'windows',
      agentVersion: '0.2.0',
    }),
  });
}

export async function disableDevice(userJwt: string, deviceId: string): Promise<void> {
  await callCloudApi(`/crm/devices/${deviceId}/disable`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${userJwt}`,
    },
  });
}

export interface HeartbeatZaloAccount {
  accountId: string;
  displayName: string;
  status: 'online' | 'expired' | 'logged_out';
}

export async function sendHeartbeat(
  deviceId: string,
  agentSecret: string,
  statusPayload: {
    status: string;
    appVersion?: string;
    agentVersion?: string;
    lastError?: string;
    zaloAccounts?: HeartbeatZaloAccount[];
    queueDepth?: number;
    clientConnections?: number;
  },
): Promise<any> {
  return callCloudApi('/crm/agent/heartbeat', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-agent-device-id': deviceId,
      'x-agent-secret': agentSecret,
    },
    body: JSON.stringify(statusPayload),
  });
}

// waitMs > 0 makes this a long-poll: the backend holds the request open (up
// to ~25s) until a command is queued for this device. The fetch timeout is
// set a bit above waitMs so a slow-but-honoring backend isn't aborted early.
export async function fetchNextCommand(
  deviceId: string,
  agentSecret: string,
  waitMs = 0,
): Promise<CommandResponse | null> {
  return callCloudApi(
    '/crm/agent/commands/next',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-agent-device-id': deviceId,
        'x-agent-secret': agentSecret,
      },
      body: JSON.stringify(waitMs > 0 ? { waitMs } : {}),
    },
    waitMs > 0 ? 30000 : undefined,
  );
}

export async function reportCommandResult(
  deviceId: string,
  agentSecret: string,
  commandId: string,
  success: boolean,
  result?: any,
  errorMessage?: string,
): Promise<any> {
  return callCloudApi(`/crm/agent/commands/${commandId}/result`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-agent-device-id': deviceId,
      'x-agent-secret': agentSecret,
    },
    body: JSON.stringify({ success, result, errorMessage }),
  });
}

export async function reportCommandProgress(
  deviceId: string,
  agentSecret: string,
  commandId: string,
  progressData: any,
): Promise<any> {
  return callCloudApi(`/crm/agent/commands/${commandId}/result`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-agent-device-id': deviceId,
      'x-agent-secret': agentSecret,
    },
    body: JSON.stringify({
      success: true,
      result: {
        status: 'running',
        ...progressData,
      },
    }),
  });
}

export async function reportInboundMessage(
  deviceId: string,
  agentSecret: string,
  event: any,
): Promise<any> {
  return callCloudApi('/crm/agent/events/message', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-agent-device-id': deviceId,
      'x-agent-secret': agentSecret,
    },
    body: JSON.stringify(event),
  });
}

export async function reportInboundMessageMetadata(
  deviceId: string,
  agentSecret: string,
  event: any,
): Promise<any> {
  const preview = typeof event.content === 'string'
    ? event.content.slice(0, 100)
    : '';
  return callCloudApi('/crm/agent/events/message', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-agent-device-id': deviceId,
      'x-agent-secret': agentSecret,
    },
    body: JSON.stringify({
      accountId: event.accountId,
      threadId: event.threadId,
      threadType: event.threadType,
      senderId: event.senderId || '',
      displayName: event.senderName || '',
      avatarUrl: event.avatarUrl || '',
      lastMessagePreview: preview,
      lastMessageAt: event.timestamp || new Date().toISOString(),
      // A self-sent message (operator's own phone/desktop) must never bump the
      // conversation's unread counter on remote clients.
      unreadCountDelta: event.senderId && event.senderId === event.accountId ? 0 : 1,
      messageType: event.messageType || 'text',
      bridgeDeviceId: deviceId,
      providerMessageId: event.providerMessageId || '',
      localFirst: true,
    }),
  });
}

// AG-3 / BE-6: outbound messages (operator send or chatbot auto-reply) hit
// the SAME cloud endpoint as inbound — the backend tells inbound and
// outbound apart by comparing event.senderId to the Zalo account's own ID
// (see upsertConversationFromInbound in crm.js), so this is a plain alias
// for 1:1 threads where full content is reported.
export const reportOutboundMessage = reportInboundMessage;

// Managed-group outbound: same privacy stance as inbound group messages (no
// content leaves the device), but unreadCountDelta is 0 — the operator's own
// message should never bump the conversation's unread counter.
export async function reportOutboundMessageMetadata(
  deviceId: string,
  agentSecret: string,
  event: any,
): Promise<any> {
  const preview = typeof event.content === 'string'
    ? event.content.slice(0, 100)
    : '';
  return callCloudApi('/crm/agent/events/message', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-agent-device-id': deviceId,
      'x-agent-secret': agentSecret,
    },
    body: JSON.stringify({
      accountId: event.accountId,
      threadId: event.threadId,
      threadType: event.threadType,
      senderId: event.senderId || '',
      displayName: event.displayName || '',
      avatarUrl: event.avatarUrl || '',
      lastMessagePreview: preview,
      lastMessageAt: event.timestamp || new Date().toISOString(),
      unreadCountDelta: 0,
      messageType: event.messageType || 'text',
      bridgeDeviceId: deviceId,
      providerMessageId: event.providerMessageId || '',
      localFirst: true,
    }),
  });
}

export async function fetchManagedGroups(
  deviceId: string,
  agentSecret: string,
): Promise<ManagedGroupResponse[]> {
  return callCloudApi('/crm/agent/groups/managed', {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
      'x-agent-device-id': deviceId,
      'x-agent-secret': agentSecret,
    },
  });
}

export async function startPairingSession(
  deviceId: string,
  agentSecret: string,
): Promise<PairingResponse> {
  return callCloudApi('/crm/pairing/start', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-agent-device-id': deviceId,
      'x-agent-secret': agentSecret,
    },
    body: JSON.stringify({ deviceId }),
  });
}
