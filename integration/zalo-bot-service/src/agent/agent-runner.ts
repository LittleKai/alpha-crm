import os from 'os';
import { getAgentCredentials, getMachineFingerprint, saveAgentCredentials, getCrmToken } from './agent-identity.js';
import { fetchManagedGroups, fetchNextCommand, reportCommandResult, reportInboundMessage, sendHeartbeat, registerDevice } from './cloud-api.js';
import { executeCommand } from './command-executor.js';
import { getZaloStatus } from '../zalo.js';
import { config } from '../config.js';
import { setInboundMessageHandler, type ZaloInboundMessageEvent } from '../channels/types.js';

let running = false;
let pollingIntervalTimer: NodeJS.Timeout | null = null;
let heartbeatIntervalTimer: NodeJS.Timeout | null = null;
let autoRegisterTimeoutTimer: NodeJS.Timeout | null = null;

// Track polling details
let pollErrorCount = 0;
const BASE_POLL_DELAY_MS = 5000;
const MAX_POLL_DELAY_MS = 60000;
let currentPollDelayMs = BASE_POLL_DELAY_MS;
let managedGroupCache: { expiresAt: number; keys: Set<string> } = {
  expiresAt: 0,
  keys: new Set()
};

/**
 * Starts the outbound CRM agent background loops
 */
export function startAgentRunner(): void {
  if (config.crmAgentMode !== 'enabled') {
    console.log('[agent-runner] Agent runner mode is disabled in config.');
    return;
  }

  if (running) {
    console.warn('[agent-runner] Agent runner is already running.');
    return;
  }

  const credentials = getAgentCredentials();
  if (!credentials) {
    console.log('[agent-runner] ⚠️ Không tìm thấy thông tin xác thực thiết bị (.data/agent/device-secret.json). Đang quét crm_token.json...');
    attemptAutoRegistration();
    return;
  }

  console.log('\n=========================================');
  console.log(` Starting Alpha CRM Outbound Agent Channel `);
  console.log(` Device ID: ${credentials.deviceId}`);
  console.log(` Target Cloud API: ${config.crmCloudApiUrl}`);
  console.log('=========================================\n');

  running = true;
  setInboundMessageHandler((event) => handleInboundMessageEvent(credentials.deviceId, credentials.agentSecret, event));

  // 1. Start heartbeat loop (every 30s)
  runHeartbeatLoop(credentials.deviceId, credentials.agentSecret);
  heartbeatIntervalTimer = setInterval(
    () => runHeartbeatLoop(credentials.deviceId, credentials.agentSecret),
    30000
  );

  // 2. Start polling loop
  scheduleNextPoll(credentials.deviceId, credentials.agentSecret);
}

/**
 * Attempts to automatically register the device using active CRM token.
 * Retries every 10 seconds under the hood if token is missing.
 */
async function attemptAutoRegistration(): Promise<void> {
  try {
    const token = getCrmToken();
    if (token) {
      console.log('[agent-runner] Phát hiện token hoạt động từ crm_token.json. Đang tự động đăng ký thiết bị...');
      const fingerprint = getMachineFingerprint();
      const hostname = os.hostname() || 'Agent PC';
      const displayName = `Windows ${process.arch} (${hostname})`;
      
      console.log(`[agent-runner] Đang đăng ký với tên hiển thị "${displayName}"...`);
      const result = await registerDevice(token, displayName, fingerprint);
      console.log(`[agent-runner] ✅ Tự động đăng ký thành công! Device ID: ${result.deviceId}`);
      
      saveAgentCredentials(result.deviceId, result.agentSecret);
      
      // Clear auto-register check timer if scheduled
      if (autoRegisterTimeoutTimer) {
        clearTimeout(autoRegisterTimeoutTimer);
        autoRegisterTimeoutTimer = null;
      }
      
      // Start the main loops
      startAgentRunner();
      return;
    }
  } catch (err: any) {
    console.error('[agent-runner] ❌ Tự động đăng ký thiết bị thất bại:', err.message);
  }

  // If we couldn't find a token or registration failed, schedule next check in 10 seconds
  if (!autoRegisterTimeoutTimer && running === false) {
    autoRegisterTimeoutTimer = setTimeout(() => {
      autoRegisterTimeoutTimer = null;
      attemptAutoRegistration();
    }, 10000);
  }
}

/**
 * Stop background agent runner loops cleanly
 */
export function stopAgentRunner(): void {
  running = false;
  setInboundMessageHandler(null);
  if (pollingIntervalTimer) {
    clearTimeout(pollingIntervalTimer);
    pollingIntervalTimer = null;
  }
  if (heartbeatIntervalTimer) {
    clearInterval(heartbeatIntervalTimer);
    heartbeatIntervalTimer = null;
  }
  if (autoRegisterTimeoutTimer) {
    clearTimeout(autoRegisterTimeoutTimer);
    autoRegisterTimeoutTimer = null;
  }
  console.log('[agent-runner] Outbound Agent Channel stopped.');
}


async function getManagedGroupKeys(deviceId: string, agentSecret: string): Promise<Set<string>> {
  const now = Date.now();
  if (managedGroupCache.expiresAt > now) return managedGroupCache.keys;

  const groups = await fetchManagedGroups(deviceId, agentSecret);
  const keys = new Set(groups.map((group) => `${group.accountId}:${group.groupId}`));
  managedGroupCache = { expiresAt: now + 60000, keys };
  return keys;
}

async function handleInboundMessageEvent(
  deviceId: string,
  agentSecret: string,
  event: ZaloInboundMessageEvent
): Promise<void> {
  try {
    if (event.threadType === 'group') {
      const managedKeys = await getManagedGroupKeys(deviceId, agentSecret);
      if (!managedKeys.has(`${event.accountId}:${event.threadId}`)) return;
    }
    await reportInboundMessage(deviceId, agentSecret, event);
  } catch (err: any) {
    console.warn('[agent-runner] Failed to report inbound message:', err.message);
  }
}

/**
 * Executes a single heartbeat tick
 */
async function runHeartbeatLoop(deviceId: string, agentSecret: string): Promise<void> {
  if (!running) return;
  try {
    const zaloStatus = getZaloStatus();
    const statusStr = zaloStatus.connected ? 'online' : 'offline';
    await sendHeartbeat(deviceId, agentSecret, {
      status: statusStr,
      appVersion: '0.2.0',
      agentVersion: '0.2.0'
    });
    console.log(`[agent-runner] Heartbeat sent successfully. Zalo status: ${statusStr}`);
  } catch (err: any) {
    console.error(`[agent-runner] Heartbeat failed:`, err.message);
  }
}

/**
 * Schedules the next poll step
 */
function scheduleNextPoll(deviceId: string, agentSecret: string): void {
  if (!running) return;
  pollingIntervalTimer = setTimeout(async () => {
    await runPollStep(deviceId, agentSecret);
    scheduleNextPoll(deviceId, agentSecret);
  }, currentPollDelayMs);
}

/**
 * Performs a single command poll, executes if command found, and reports the outcome
 */
async function runPollStep(deviceId: string, agentSecret: string): Promise<void> {
  try {
    const command = await fetchNextCommand(deviceId, agentSecret);
    
    // Connection succeeded, reset backoff
    pollErrorCount = 0;
    currentPollDelayMs = BASE_POLL_DELAY_MS;

    if (!command) {
      // No commands queued, quiet poll
      return;
    }

    console.log(`\n[agent-runner] 📥 Nhận lệnh mới từ Cloud: "${command.type}" (ID: ${command._id})`);
    
    try {
      // Execute the command locally
      const result = await executeCommand(command, deviceId, agentSecret);
      
      console.log(`[agent-runner] Lệnh "${command.type}" xử lý thành công.`);
      
      // Report success back to cloud
      await reportCommandResult(deviceId, agentSecret, command._id, true, result);
    } catch (execErr: any) {
      console.error(`[agent-runner] Lệnh "${command.type}" xử lý thất bại:`, execErr.message);
      
      // Report failure back to cloud
      await reportCommandResult(deviceId, agentSecret, command._id, false, undefined, execErr.message);
    }

    // Since we just processed a command, trigger next poll step immediately to see if there are more
    currentPollDelayMs = 500; // instant follow-up
  } catch (err: any) {
    pollErrorCount++;
    // Exponential backoff logic: double the delay up to max cap
    currentPollDelayMs = Math.min(BASE_POLL_DELAY_MS * Math.pow(2, pollErrorCount - 1), MAX_POLL_DELAY_MS);
    console.warn(`[agent-runner] Polling failed (${err.message}). Retrying in ${currentPollDelayMs / 1000}s...`);
  }
}
