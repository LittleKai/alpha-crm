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

/**
 * Helper to call cloud APIs with error handling
 */
async function callCloudApi(path: string, options: RequestInit): Promise<any> {
  const url = `${config.crmCloudApiUrl}${path}`;
  try {
    const res = await fetch(url, options);
    if (!res.ok) {
      const errBody = await res.json().catch(() => ({ message: `HTTP status ${res.status}` }));
      throw new Error(errBody.message || `Lỗi API Cloud (${res.status})`);
    }
    const body: any = await res.json();
    if (!body.success) {
      throw new Error(body.message || 'Lỗi API Cloud không thành công.');
    }
    return body.data;
  } catch (err: any) {
    console.error(`[cloud-api] Call to ${path} failed:`, err.message);
    throw err;
  }
}

/**
 * Registers device against active CRM subscription using User's JWT token
 */
export async function registerDevice(
  userJwt: string,
  displayName: string,
  machineFingerprint: string
): Promise<{ deviceId: string; agentSecret: string }> {
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${userJwt}`
  };
  const body = {
    machineFingerprint,
    displayName,
    platform: 'windows'
  };
  return callCloudApi('/crm/devices/register', {
    method: 'POST',
    headers,
    body: JSON.stringify(body)
  });
}

/**
 * Sends online heartbeat to cloud backend
 */
export async function sendHeartbeat(
  deviceId: string,
  agentSecret: string,
  statusPayload: { status: string; appVersion?: string; agentVersion?: string; lastError?: string }
): Promise<any> {
  const headers = {
    'Content-Type': 'application/json',
    'x-agent-device-id': deviceId,
    'x-agent-secret': agentSecret
  };
  return callCloudApi('/crm/agent/heartbeat', {
    method: 'POST',
    headers,
    body: JSON.stringify(statusPayload)
  });
}

/**
 * Polls for the next queued command for this agent device
 */
export async function fetchNextCommand(
  deviceId: string,
  agentSecret: string
): Promise<CommandResponse | null> {
  const headers = {
    'Content-Type': 'application/json',
    'x-agent-device-id': deviceId,
    'x-agent-secret': agentSecret
  };
  return callCloudApi('/crm/agent/commands/next', {
    method: 'POST',
    headers
  });
}

/**
 * Reports results of executing a command
 */
export async function reportCommandResult(
  deviceId: string,
  agentSecret: string,
  commandId: string,
  success: boolean,
  result?: any,
  errorMessage?: string
): Promise<any> {
  const headers = {
    'Content-Type': 'application/json',
    'x-agent-device-id': deviceId,
    'x-agent-secret': agentSecret
  };
  const body = {
    success,
    result,
    errorMessage
  };
  return callCloudApi(`/crm/agent/commands/${commandId}/result`, {
    method: 'POST',
    headers,
    body: JSON.stringify(body)
  });
}

/**
 * Reports intermediate progress of a running command
 */
export async function reportCommandProgress(
  deviceId: string,
  agentSecret: string,
  commandId: string,
  progressData: any
): Promise<any> {
  const headers = {
    'Content-Type': 'application/json',
    'x-agent-device-id': deviceId,
    'x-agent-secret': agentSecret
  };
  const body = {
    success: true,
    result: {
      status: 'running',
      ...progressData
    }
  };
  return callCloudApi(`/crm/agent/commands/${commandId}/result`, {
    method: 'POST',
    headers,
    body: JSON.stringify(body)
  });
}

export async function reportInboundMessage(
  deviceId: string,
  agentSecret: string,
  event: any
): Promise<any> {
  const headers = {
    'Content-Type': 'application/json',
    'x-agent-device-id': deviceId,
    'x-agent-secret': agentSecret
  };
  return callCloudApi('/crm/agent/events/message', {
    method: 'POST',
    headers,
    body: JSON.stringify(event)
  });
}

export async function fetchManagedGroups(
  deviceId: string,
  agentSecret: string
): Promise<ManagedGroupResponse[]> {
  const headers = {
    'Content-Type': 'application/json',
    'x-agent-device-id': deviceId,
    'x-agent-secret': agentSecret
  };
  return callCloudApi('/crm/agent/groups/managed', {
    method: 'GET',
    headers
  });
}

/**
 * Requests a new pairing session from the cloud backend
 */
export async function startPairingSession(
  deviceId: string,
  agentSecret: string
): Promise<PairingResponse> {
  const headers = {
    'Content-Type': 'application/json',
    'x-agent-device-id': deviceId,
    'x-agent-secret': agentSecret
  };
  // Wait! The /pairing/start route requires standard user auth in Phase 1,
  // but let's see if we can support calling it with agent auth in the backend.
  // Let's call /crm/pairing/start with deviceId in the body and agent auth headers,
  // which is extremely convenient for the Windows app/agent!
  const body = { deviceId };
  return callCloudApi('/crm/pairing/start', {
    method: 'POST',
    headers,
    body: JSON.stringify(body)
  });
}
