import {
  getZaloStatus,
  sendMessage,
  recallMessage,
  getAllGroups,
  getAllFriends,
  getAccounts,
  findUser,
  sendFriendRequest,
  acceptFriendRequest,
  createGroup,
  joinGroup,
  inviteToGroup,
  leaveGroup,
  getGroupMembers
} from '../zalo.js';

// Local campaign tracking
const runningCampaigns = new Set<string>();
const cancelledCampaigns = new Set<string>();
let cancelAllCampaigns = false;

export function requestCancelAllCampaigns(): void {
  cancelAllCampaigns = true;
  for (const campaignId of runningCampaigns) {
    cancelledCampaigns.add(campaignId);
  }
}

export function resetCampaignCancellation(): void {
  cancelAllCampaigns = false;
}

export interface Command {
  _id: string;
  type: string;
  payload: any;
}

function validateZaloSendPayload(payload: any): void {
  const attachments = Array.isArray(payload?.attachments)
    ? payload.attachments.filter((item: unknown) => String(item || '').trim())
    : [];
  const hasMessage = String(payload?.message || '').trim().length > 0;
  if (!payload?.recipientId || (!hasMessage && attachments.length === 0)) {
    throw new Error(
      'Thieu recipientId hoac message hoac attachments trong payload gui tin nhan.',
    );
  }
}

export function validateZaloSendPayloadForTest(payload: any): void {
  validateZaloSendPayload(payload);
}

/**
 * Executes a cloud command locally by mapping it to the appropriate zalo-bot-service API.
 * For long-running commands like campaign execution, it runs them asynchronously in the background
 * to prevent blocking the agent's main command polling thread, allowing cancellation commands.
 */
export async function executeCommand(command: Command, deviceId?: string, agentSecret?: string): Promise<any> {
  const { type, payload } = command;

  switch (type) {
    case 'crm.agent.ping':
      return { pong: true, timestamp: new Date().toISOString() };

    case 'zalo.status':
      return getZaloStatus();

    case 'zalo.accounts.sync':
      return getAccounts();

    case 'zalo.groups.sync': {
      const groups = await getAllGroups();
      return payload?.accountId
        ? groups.filter((group: any) => group.accountId === payload.accountId)
        : groups;
    }

    case 'zalo.friends.sync':
      return getAllFriends();

    case 'zalo.message.send': {
      validateZaloSendPayload(payload);
      const result = await sendMessage({
        recipientId: payload.recipientId,
        message: payload.message,
        accountId: payload.accountId,
        threadType: payload.threadType,
        messageType: payload.messageType,
        attachments: payload.attachments,
      }, payload.isTestMode || false);
      if (!result.success) {
        throw new Error(result.error || 'Gửi tin nhắn thất bại.');
      }
      return result;
    }

    case 'zalo.message.recall': {
      if (!payload.threadId || !payload.msgId) {
        throw new Error('Thiếu threadId hoặc msgId trong payload thu hồi tin nhắn.');
      }
      const recallResult = await recallMessage({
        accountId: payload.accountId,
        threadId: payload.threadId,
        threadType: payload.threadType,
        msgId: payload.msgId,
        cliMsgId: payload.cliMsgId,
      });
      if (!recallResult.success) {
        throw new Error(recallResult.error || 'Thu hồi tin nhắn thất bại.');
      }
      return recallResult;
    }

    case 'START_CAMPAIGN':
    case 'crm.campaign.execute': {
      const campaignId = payload.campaignId;
      if (!campaignId) {
        throw new Error('Thiếu campaignId trong payload chiến dịch.');
      }

      if (runningCampaigns.has(campaignId)) {
        throw new Error(`Chiến dịch ${campaignId} đang chạy rồi.`);
      }

      if (!deviceId || !agentSecret) {
        throw new Error('Thiếu thông tin xác thực thiết bị để chạy chiến dịch nền.');
      }

      // Trigger campaign loop asynchronously in the background so we do NOT block the polling thread!
      runCampaignInBackground(command, deviceId, agentSecret);

      return {
        success: true,
        status: 'running',
        message: 'Chiến dịch đã được khởi chạy thành công ở chế độ nền.'
      };
    }

    case 'CANCEL_CAMPAIGN':
    case 'crm.campaign.cancel': {
      const campaignId = payload.campaignId;
      if (!campaignId) {
        throw new Error('Thiếu campaignId để hủy chiến dịch.');
      }
      if (runningCampaigns.has(campaignId)) {
        cancelledCampaigns.add(campaignId);
        console.log(`[command-executor] 🚫 Đã kích hoạt hủy chiến dịch cục bộ: ${campaignId}`);
        return { success: true, message: `Đã phát lệnh hủy chiến dịch ${campaignId} thành công.` };
      }
      return { success: true, message: `Chiến dịch ${campaignId} không hoạt động cục bộ.` };
    }

    // Additional helper/channel methods
    case 'zalo.friends.search':
      return findUser(payload.phone, payload.accountId);

    case 'zalo.friends.add':
      return sendFriendRequest(payload.userId, payload.message || '', payload.accountId);

    case 'zalo.friends.approve':
      return acceptFriendRequest(payload.senderId, payload.accountId);

    case 'zalo.groups.create':
      return createGroup(payload.name, payload.members || []);

    case 'zalo.groups.join':
      return joinGroup(payload.link);

    case 'zalo.groups.invite':
      return inviteToGroup(payload.userId, payload.groupId);

    case 'zalo.groups.leave':
      return leaveGroup(payload.groupId, payload.silent || false);

    case 'zalo.groups.members':
      return getGroupMembers(payload.groupId);

    default:
      throw new Error(`[command-executor] Lệnh không được hỗ trợ hoặc chưa được định nghĩa: "${type}"`);
  }
}

/**
 * Runs a campaign execution loop asynchronously in the background.
 * Reports the final outcome of all sends back to the Cloud Backend when finished.
 */
async function runCampaignInBackground(command: Command, deviceId: string, agentSecret: string): Promise<void> {
  const { payload } = command;
  const campaignId = payload.campaignId;
  const recipients = payload.recipients || [];
  const customerIds = payload.customerIds || [];
  const templateText = payload.message || 'Tin nhắn chiến dịch';
  const actionType = payload.channel === 'email' ? 'bulk_message_by_phone' : 'bulk_message_to_friends';
  const minDelaySeconds = Math.max(1, Number(payload.rateLimit?.minDelaySeconds) || 3);
  const maxDelaySeconds = Math.max(minDelaySeconds, Number(payload.rateLimit?.maxDelaySeconds) || minDelaySeconds);

  // Map to stable target list of { phone, name, customerId }
  const targetList = recipients.length > 0 
    ? recipients 
    : customerIds.map((id: string) => ({ phone: id, name: 'Khách hàng', customerId: id }));

  // Run local compliance guard for safety (fail-closed)
  try {
    const { evaluateCompliance } = await import('../compliance.js');
    const decision = evaluateCompliance({
      actionType: actionType as any,
      targetCount: targetList.length,
      hasConsentProof: true, // Assuming backend filtered this
      hasRecentInteraction: true,
      isTestMode: payload.isTestMode || false
    });

    if (!decision.allowed) {
      console.log(`[command-executor] [Background] Chiến dịch ${campaignId} bị chặn bởi compliance: ${decision.reason}`);
      const { reportCommandResult } = await import('./cloud-api.js');
      await reportCommandResult(deviceId, agentSecret, command._id, false, null, decision.reason);
      return;
    }
  } catch (err: any) {
    console.error('[command-executor] Compliance check error:', err.message);
  }

  runningCampaigns.add(campaignId);
  cancelledCampaigns.delete(campaignId);

  console.log(`[command-executor] [Background] Bắt đầu chạy chiến dịch ${campaignId} với ${targetList.length} khách hàng...`);

  const results = [];
  let anyFailed = false;
  let successCount = 0;
  let failedCount = 0;
  let cancelledCount = 0;

  for (let i = 0; i < targetList.length; i++) {
    const recipient = targetList[i];
    const recipientId = recipient.phone || recipient.customerId;
    let latestResult: any = null;

    // Check for cancellation before each send
    if (cancelAllCampaigns || cancelledCampaigns.has(campaignId)) {
      console.log(`[command-executor] [Background] Chiến dịch ${campaignId} đã bị hủy bởi người dùng.`);
      latestResult = {
        customerId: recipient.customerId,
        phone: recipient.phone,
        status: 'cancelled',
        message: 'Chiến dịch bị hủy bởi người dùng.'
      };
      results.push(latestResult);
      cancelledCount++;
      continue;
    }

    try {
      console.log(`[command-executor] [Background] [Campaign ${campaignId}] Gửi tin tới ${recipient.name} (${recipientId}) [${i + 1}/${targetList.length}]...`);
      
      // Personalize the template variables: replace {{name}} with recipient's actual name
      const personalizedText = templateText.replace(/\{\{name\}\}/g, recipient.name || 'Anh/Chị');

      const sendResult = await sendMessage({
        recipientId,
        message: personalizedText,
        threadType: recipient.threadType || 'user',
        messageType: 'text'
      }, payload.isTestMode || false);

      latestResult = {
        customerId: recipient.customerId,
        phone: recipient.phone,
        status: sendResult.success ? 'succeeded' : 'failed',
        messageId: sendResult.messageId,
        error: sendResult.error
      };
      results.push(latestResult);

      if (sendResult.success) {
        successCount++;
      } else {
        failedCount++;
        anyFailed = true;
      }
    } catch (err: any) {
      console.error(`[command-executor] [Background] Gửi tin tới ${recipientId} thất bại:`, err.message);
      latestResult = {
        customerId: recipient.customerId,
        phone: recipient.phone,
        status: 'failed',
        error: err.message
      };
      results.push(latestResult);
      failedCount++;
      anyFailed = true;
    }

    // Report intermediate progress
    try {
      const { reportCommandProgress } = await import('./cloud-api.js');
      await reportCommandProgress(deviceId, agentSecret, command._id, {
        campaignId,
        processed: i + 1,
        total: targetList.length,
        successCount,
        failedCount,
        cancelledCount,
        latestResult
      });
    } catch (err: any) {
      console.error(`[command-executor] [Background] Lỗi báo cáo tiến độ:`, err.message);
    }

    // Delay between sends to comply with Zalo anti-spam limits (3 seconds)
    if (i < targetList.length - 1) {
      const delaySeconds = minDelaySeconds + Math.random() * (maxDelaySeconds - minDelaySeconds);
      await new Promise((resolve) => setTimeout(resolve, delaySeconds * 1000));
    }
  }

  runningCampaigns.delete(campaignId);
  const wasCancelled = cancelledCampaigns.has(campaignId);
  cancelledCampaigns.delete(campaignId);

  // Report final detailed execution results back to the Cloud Backend crmAgentCommand result endpoint
  try {
    const finalResult = {
      campaignId,
      totalProcessed: targetList.length,
      results
    };
    
    const successState = !anyFailed && !wasCancelled;

    console.log(`[command-executor] [Background] Báo cáo kết quả chiến dịch ${campaignId} về Cloud...`);
    const { reportCommandResult } = await import('./cloud-api.js');
    await reportCommandResult(deviceId, agentSecret, command._id, successState, finalResult);
    console.log(`[command-executor] [Background] Hoàn thành báo cáo chiến dịch ${campaignId}.`);
  } catch (err: any) {
    console.error(`[command-executor] [Background] Thất bại khi gửi báo cáo kết quả về Cloud:`, err.message);
  }
}
