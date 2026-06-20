import {
  deleteAgentCredentials,
  deleteCrmToken,
  getAgentCredentials,
  saveAgentCredentials,
  saveCrmToken,
} from '../agent/agent-identity.js';
import type { AgentCredentials } from '../agent/agent-identity.js';
import {
  disableDevice,
  forceReplaceDevice,
  registerDevice,
  sendHeartbeat,
  verifyCloudIdentity,
} from '../agent/cloud-api.js';
import {
  setAgentRevocationHandler,
  startAgentRunner,
  stopAgentRunner,
} from '../agent/agent-runner.js';
import {
  requestCancelAllCampaigns,
  resetCampaignCancellation,
} from '../agent/command-executor.js';
import {
  setSyncRevocationHandler,
  startBackgroundSync,
  stopBackgroundSync,
} from '../local-chat/sync-worker.js';
import {
  getZaloStatus,
  initializeZalo,
  recoverZaloListener,
  stopZaloListener,
} from '../zalo.js';
import { ListenerHealthMonitor } from './listener-health.js';
import { SessionCoordinator } from './session-coordinator.js';
import { SessionEventHub } from './session-events.js';
import {
  startLocalChatbotRuntime,
  stopLocalChatbotRuntime,
} from '../chatbot/index.js';

export const sessionEventHub = new SessionEventHub();

// Giữ SSE /local/events sống: gửi comment keepalive định kỳ để proxy/OS không
// đóng socket idle (gây "Connection closed while receiving data" phía client).
const sessionEventKeepAlive = setInterval(() => sessionEventHub.keepAlive(), 20000);
sessionEventKeepAlive.unref?.();

const listenerHealthMonitor = new ListenerHealthMonitor(
  getZaloStatus,
  recoverZaloListener,
);

/// Thân khởi động runtime dùng chung cho cả luồng sync từ Flutter lẫn luồng tự
/// khôi phục khi backend boot. Nạp pool tài khoản zca (initializeZalo →
/// ensureLoginPool) rồi bật chatbot/agent/sync + giám sát listener.
async function bootRuntime(credentials: AgentCredentials): Promise<void> {
  stopAgentRunner();
  stopBackgroundSync();
  stopLocalChatbotRuntime();
  await initializeZalo();
  startLocalChatbotRuntime(credentials);
  startAgentRunner(credentials);
  startBackgroundSync();
  listenerHealthMonitor.start();
}

export const sessionCoordinator = new SessionCoordinator({
  verifyIdentity: verifyCloudIdentity,
  getCredentials: getAgentCredentials,
  register: registerDevice,
  forceReplace: forceReplaceDevice,
  heartbeat: async (deviceId, agentSecret) => {
    await sendHeartbeat(deviceId, agentSecret, {
      status: getZaloStatus().connected ? 'online' : 'offline',
      appVersion: '0.2.0',
      agentVersion: '0.2.0',
    });
  },
  disable: disableDevice,
  saveCredentials: (credentials) => {
    if (!saveAgentCredentials(
      credentials.userId,
      credentials.deviceId,
      credentials.agentSecret,
    )) {
      throw new Error('Unable to persist local agent credentials.');
    }
  },
  saveToken: saveCrmToken,
  deleteCredentials: deleteAgentCredentials,
  deleteToken: deleteCrmToken,
  startRuntime: bootRuntime,
  stopRuntime: async () => {
    stopAgentRunner();
    stopBackgroundSync();
    stopLocalChatbotRuntime();
    listenerHealthMonitor.stop();
    await stopZaloListener();
  },
  cancelCampaigns: requestCancelAllCampaigns,
  resetCampaignCancellation,
  publish: (event) => sessionEventHub.publish(event),
});

setAgentRevocationHandler((reason) => sessionCoordinator.revoke(reason));
setSyncRevocationHandler((reason) => sessionCoordinator.revoke(reason));

/// Tự khôi phục runtime khi backend khởi động nếu máy đã từng đăng ký
/// (credentials đã lưu trên đĩa). Nhờ vậy pool tài khoản được nạp ngay mà KHÔNG
/// phải chờ Flutter gửi /local/auth/sync — fix lỗi "lần khởi động đầu thấy 0
/// tài khoản, phải hot reload mới nhận". Heartbeat trong runtime vẫn tự phát
/// hiện thu hồi/đụng thiết bị nên không phá vỡ device-gating của cloud.
export async function resumeRuntimeFromStoredCredentials(): Promise<boolean> {
  const credentials = getAgentCredentials();
  if (!credentials) {
    console.log('[session-runtime] No stored credentials — chờ Flutter session sync.');
    return false;
  }
  try {
    console.log('[session-runtime] Found stored credentials — tự khôi phục runtime khi boot.');
    await bootRuntime(credentials);
    return true;
  } catch (err) {
    console.error('[session-runtime] Auto-resume runtime thất bại:', err);
    return false;
  }
}

export async function shutdownSessionRuntime(): Promise<void> {
  clearInterval(sessionEventKeepAlive);
  stopAgentRunner();
  stopBackgroundSync();
  stopLocalChatbotRuntime();
  listenerHealthMonitor.stop();
  await stopZaloListener();
  sessionEventHub.close();
}
