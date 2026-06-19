import {
  deleteAgentCredentials,
  deleteCrmToken,
  getAgentCredentials,
  saveAgentCredentials,
  saveCrmToken,
} from '../agent/agent-identity.js';
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
  startRuntime: async (credentials) => {
    stopAgentRunner();
    stopBackgroundSync();
    stopLocalChatbotRuntime();
    await initializeZalo();
    startLocalChatbotRuntime(credentials);
    startAgentRunner(credentials);
    startBackgroundSync();
    listenerHealthMonitor.start();
  },
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

export async function shutdownSessionRuntime(): Promise<void> {
  clearInterval(sessionEventKeepAlive);
  stopAgentRunner();
  stopBackgroundSync();
  stopLocalChatbotRuntime();
  listenerHealthMonitor.stop();
  await stopZaloListener();
  sessionEventHub.close();
}
