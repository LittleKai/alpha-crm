import {
  getZaloStatus,
  sendMessage,
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

export interface Command {
  _id: string;
  type: string;
  payload: any;
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

    case 'zalo.groups.sync':
      return getAllGroups();

    case 'zalo.friends.sync':
      return getAllFriends();

    case 'zalo.message.send': {
      if (!payload.recipientId || !payload.message) {
        throw new Error('Thiếu recipientId hoặc message trong payload gửi tin nhắn.');
      }
      return sendMessage({
        recipientId: payload.recipientId,
        message: payload.message,
        threadType: payload.threadType,
        messageType: payload.messageType
      }, payload.isTestMode || false);
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
      return findUser(payload.phone);

    case 'zalo.friends.add':
      return sendFriendRequest(payload.userId, payload.message || '');

    case 'zalo.friends.approve':
      return acceptFriendRequest(payload.senderId);

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

  // Map to stable target list of { phone, name, customerId }
  const targetList = recipients.length > 0 
    ? recipients 
    : customerIds.map((id: string) => ({ phone: id, name: 'Khách hàng', customerId: id }));

  runningCampaigns.add(campaignId);
  cancelledCampaigns.delete(campaignId);

  console.log(`[command-executor] [Background] Bắt đầu chạy chiến dịch ${campaignId} với ${targetList.length} khách hàng...`);

  const results = [];
  let anyFailed = false;

  for (let i = 0; i < targetList.length; i++) {
    const recipient = targetList[i];
    const recipientId = recipient.phone || recipient.customerId;

    // Check for cancellation before each send
    if (cancelledCampaigns.has(campaignId)) {
      console.log(`[command-executor] [Background] Chiến dịch ${campaignId} đã bị hủy bởi người dùng.`);
      results.push({
        customerId: recipient.customerId,
        phone: recipient.phone,
        status: 'cancelled',
        message: 'Chiến dịch bị hủy bởi người dùng.'
      });
      continue;
    }

    try {
      console.log(`[command-executor] [Background] [Campaign ${campaignId}] Gửi tin tới ${recipient.name} (${recipientId}) [${i + 1}/${targetList.length}]...`);
      
      // Personalize the template variables: replace {{name}} with recipient's actual name
      const personalizedText = templateText.replace(/\{\{name\}\}/g, recipient.name || 'Anh/Chị');

      const sendResult = await sendMessage({
        recipientId,
        message: personalizedText,
        threadType: 'user',
        messageType: 'text'
      }, payload.isTestMode || false);

      results.push({
        customerId: recipient.customerId,
        phone: recipient.phone,
        status: sendResult.success ? 'succeeded' : 'failed',
        messageId: sendResult.messageId,
        error: sendResult.error
      });

      if (!sendResult.success) {
        anyFailed = true;
      }
    } catch (err: any) {
      console.error(`[command-executor] [Background] Gửi tin tới ${recipientId} thất bại:`, err.message);
      results.push({
        customerId: recipient.customerId,
        phone: recipient.phone,
        status: 'failed',
        error: err.message
      });
      anyFailed = true;
    }

    // Delay between sends to comply with Zalo anti-spam limits (3 seconds)
    if (i < targetList.length - 1) {
      await new Promise((resolve) => setTimeout(resolve, 3000));
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
