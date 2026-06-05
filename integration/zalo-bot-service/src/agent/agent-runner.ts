import os from 'os';
import fs from 'fs';
import { getAgentCredentials, getMachineFingerprint, saveAgentCredentials, getCrmToken, getCrmTokenPath } from './agent-identity.js';
import { fetchManagedGroups, fetchNextCommand, reportCommandResult, reportInboundMessage, sendHeartbeat, registerDevice } from './cloud-api.js';
import { executeCommand } from './command-executor.js';
import { getZaloStatus } from '../zalo.js';
import { config } from '../config.js';
import { setInboundMessageHandler, type ZaloInboundMessageEvent } from '../channels/types.js';
import { dispatchN8nEvent } from '../integrations/n8n-event-dispatcher.js';

let running = false;
let pollingIntervalTimer: NodeJS.Timeout | null = null;
let heartbeatIntervalTimer: NodeJS.Timeout | null = null;
let autoRegisterTimeoutTimer: NodeJS.Timeout | null = null;
let autoRegisterFailCount = 0;
let tokenWatcherActive = false;
export let lastRegistrationError: string | null = null;

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
  lastRegistrationError = null; // Clear error if credentials load successfully
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
 * Watches the crm_token.json file for changes to wake up from sleep instantly.
 */
function watchCrmToken(tokenPath: string): void {
  if (tokenWatcherActive) return;
  tokenWatcherActive = true;
  
  fs.watchFile(tokenPath, { interval: 5000 }, (curr, prev) => {
    if (curr.mtimeMs !== prev.mtimeMs) {
      console.log('[agent-runner] 🔄 Phát hiện file crm_token.json thay đổi (Đăng nhập mới hoặc cập nhật gói cước). Đang kích hoạt kiểm tra đăng ký ngay lập tức...');
      
      // If there is an active auto-register timeout timer, cancel it
      if (autoRegisterTimeoutTimer) {
        clearTimeout(autoRegisterTimeoutTimer);
        autoRegisterTimeoutTimer = null;
      }
      
      // Reset fail count and try registering immediately
      autoRegisterFailCount = 0;
      attemptAutoRegistration();
    }
  });
}

/**
 * Attempts to automatically register the device using active CRM token.
 * Retries under the hood if token is missing or registration fails.
 */
async function attemptAutoRegistration(): Promise<void> {
  const tokenPath = getCrmTokenPath();
  if (tokenPath) {
    watchCrmToken(tokenPath);
  }

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
      
      lastRegistrationError = null; // Clear on success
      autoRegisterFailCount = 0;
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
    autoRegisterFailCount++;
    lastRegistrationError = err.message; // Save registration failure error
    console.error('[agent-runner] ❌ Tự động đăng ký thiết bị thất bại:', err.message);

    // If the error is due to inactive/expired subscription, suspend retries for 30 minutes to prevent spamming
    if (err.message.includes('Yêu cầu gói đăng ký') || err.message.includes('hết hạn')) {
      console.log('[agent-runner] ⏸️ Phát hiện tài khoản chưa kích hoạt hoặc đã hết hạn gói cước CRM.');
      console.log('[agent-runner] Tạm ngưng tự động đăng ký để tránh spam Cloud API. Hệ thống sẽ thử lại sau mỗi 30 phút.');

      if (!autoRegisterTimeoutTimer && running === false) {
        autoRegisterTimeoutTimer = setTimeout(() => {
          autoRegisterTimeoutTimer = null;
          attemptAutoRegistration();
        }, 30 * 60 * 1000); // 30 minutes
      }
      return;
    }
  }

  // Calculate exponential backoff retry delay (10s, 20s, 40s, 80s, up to 5 minutes maximum)
  const backoffDelayMs = Math.min(10000 * Math.pow(2, Math.min(autoRegisterFailCount - 1, 5)), 5 * 60 * 1000);

  if (!autoRegisterTimeoutTimer && running === false) {
    autoRegisterTimeoutTimer = setTimeout(() => {
      autoRegisterTimeoutTimer = null;
      attemptAutoRegistration();
    }, backoffDelayMs);
    console.log(`[agent-runner] Sẽ thử tự động đăng ký lại sau ${backoffDelayMs / 1000} giây (Số lần thất bại liên tiếp: ${autoRegisterFailCount})`);
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
    await dispatchN8nEvent('zalo.message.inbound', event);
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
