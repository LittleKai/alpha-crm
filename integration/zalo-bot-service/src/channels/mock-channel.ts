/**
 * MockZaloChannel — test/dev fallback that returns mock results
 * without making any real Zalo API calls.
 */

import type {
  ZaloChannel,
  ZaloChannelStatus,
  ZaloSendMessageRequest,
  ZaloSendMessageResult,
  ZaloFriend,
  ZaloGroupMember,
} from './types.js';
import { emitInboundMessage } from './types.js';

let lastEventAt: string | null = null;
let mockListenerTimer: NodeJS.Timeout | null = null;

export class MockZaloChannel implements ZaloChannel {
  getStatus(): ZaloChannelStatus {
    return {
      connected: true,
      mode: 'mock',
      accountType: 'mock',
      accountLabel: 'Mock Channel',
      listenerRunning: mockListenerTimer !== null,
      lastEventAt,
    };
  }

  async sendMessage(
    req: ZaloSendMessageRequest,
    _isTestMode = false,
  ): Promise<ZaloSendMessageResult> {
    console.log(
      `[MockZaloChannel] Mock send to ${req.recipientId}: ${req.message.slice(0, 80)}`,
    );
    return {
      success: true,
      messageId: `mock_${Date.now()}`,
    };
  }

  handleWebhookEvent(event: Record<string, unknown>): void {
    lastEventAt = new Date().toISOString();
    console.log(
      '[MockZaloChannel] Mock webhook event:',
      JSON.stringify(event).slice(0, 200),
    );
  }

  async startListener(): Promise<void> {
    if (mockListenerTimer) return;
    mockListenerTimer = setInterval(() => {
      lastEventAt = new Date().toISOString();
      void emitInboundMessage({
        accountId: 'mock_acc_1',
        accountLabel: 'Mock Personal Zalo A',
        threadId: 'mock_live_customer',
        threadType: 'user',
        senderId: 'mock_live_customer',
        senderName: 'Mock Customer',
        content: 'Minh can tu van them ve bao gia.',
        messageType: 'text',
        providerMessageId: `mock_inbound_${Date.now()}`,
        timestamp: lastEventAt,
      });
    }, 45000);
    console.log('[MockZaloChannel] Mock realtime listener started.');
  }

  async stopListener(): Promise<void> {
    if (!mockListenerTimer) return;
    clearInterval(mockListenerTimer);
    mockListenerTimer = null;
    console.log('[MockZaloChannel] Mock realtime listener stopped.');
  }

  async getAllGroups(): Promise<any[]> {
    console.log('[MockZaloChannel] Fetching mock groups');
    return [
      { id: 'g1', name: 'Nhóm Dự Án Alpha', memberCount: 15, role: 'Trưởng nhóm', accountId: 'mock_acc_1' },
      { id: 'g2', name: 'Zalo Marketing Hub', memberCount: 142, role: 'Thành viên', accountId: 'mock_acc_1' },
      { id: 'g3', name: 'Gia Đình & Bạn Bè', memberCount: 8, role: 'Phó nhóm', accountId: 'mock_acc_2' },
      { id: 'g4', name: 'Khách Hàng Tiềm Năng', memberCount: 250, role: 'Trưởng nhóm', accountId: 'mock_acc_2' },
      { id: 'g5', name: 'Cộng Đồng Chia Sẻ Kinh Nghiệm', memberCount: 520, role: 'Thành viên', accountId: 'mock_acc_1' },
    ];
  }

  async leaveGroup(groupId: string, silent = false): Promise<boolean> {
    console.log(`[MockZaloChannel] Mock leaving group ${groupId} (silent: ${silent})`);
    return true;
  }

  getAccounts(): any[] {
    return [
      { id: 'mock_acc_1', label: 'Mock Personal Zalo A', connected: true, listenerRunning: true },
      { id: 'mock_acc_2', label: 'Mock Personal Zalo B', connected: true, listenerRunning: false },
    ];
  }

  async deleteAccount(accountId: string): Promise<boolean> {
    console.log(`[MockZaloChannel] Mock unlinked account: ${accountId}`);
    return true;
  }

  async getAllFriends(): Promise<ZaloFriend[]> {
    console.log('[MockZaloChannel] Fetching mock friends');
    return [
      { userId: 'u1', displayName: 'Lê Hoàng Minh', zaloName: 'hoangminh', avatar: '', phoneNumber: '0901112222', isFriend: true },
      { userId: 'u2', displayName: 'Nguyễn Thị Hồng', zaloName: 'thihong', avatar: '', phoneNumber: '0903334444', isFriend: true },
      { userId: 'u3', displayName: 'Trần Minh Hải', zaloName: 'minhhai', avatar: '', phoneNumber: '0905556666', isFriend: true },
      { userId: 'u4', displayName: 'Phạm Thanh Sơn', zaloName: 'thanhson', avatar: '', phoneNumber: '0907778888', isFriend: true },
      { userId: 'u5', displayName: 'Vũ Ngọc Anh', zaloName: 'ngocanh', avatar: '', phoneNumber: '0909990000', isFriend: true },
      { userId: 'u6', displayName: 'Đỗ Tiến Đạt', zaloName: 'tiendat', avatar: '', phoneNumber: '0912223333', isFriend: true },
      { userId: 'u7', displayName: 'Hoàng Kim Liên', zaloName: 'kimlien', avatar: '', phoneNumber: '0914445555', isFriend: true },
      { userId: 'u8', displayName: 'Bùi Thế Vinh', zaloName: 'thevinh', avatar: '', phoneNumber: '0916667777', isFriend: true },
    ];
  }

  async getGroupMembers(groupId: string): Promise<ZaloGroupMember[]> {
    console.log(`[MockZaloChannel] Fetching mock members for group ${groupId}`);
    return [
      { id: 'u1', displayName: 'Phạm Minh Đức', zaloName: 'minhduc', avatar: '', role: 'owner' },
      { id: 'u2', displayName: 'Trần Thanh Hằng', zaloName: 'thanhhang', avatar: '', role: 'admin' },
      { id: 'u3', displayName: 'Nguyễn Duy Mạnh', zaloName: 'duymanh', avatar: '', role: 'member' },
      { id: 'u4', displayName: 'Lê Việt Anh', zaloName: 'vietanh', avatar: '', role: 'member' },
      { id: 'u5', displayName: 'Hoàng Quốc Việt', zaloName: 'quocviet', avatar: '', role: 'member' },
      { id: 'u6', displayName: 'Vũ Thị Lan', zaloName: 'thilan', avatar: '', role: 'member' },
    ];
  }

  async getGroupLinkMembers(link: string): Promise<{ groupId: string; groupName: string; totalMember: number; members: ZaloGroupMember[]; avatar?: string }> {
    console.log(`[MockZaloChannel] Fetching mock group link info for: ${link}`);
    const members: ZaloGroupMember[] = [
      { id: 'u10', displayName: 'Nguyễn Văn An', zaloName: 'vanan', avatar: '', role: 'owner' },
      { id: 'u11', displayName: 'Trần Thị Bình', zaloName: 'thibinh', avatar: '', role: 'admin' },
      { id: 'u12', displayName: 'Lê Quốc Cường', zaloName: 'quoccuong', avatar: '', role: 'member' },
      { id: 'u13', displayName: 'Phạm Đức Dũng', zaloName: 'ducdung', avatar: '', role: 'member' },
      { id: 'u14', displayName: 'Hoàng Minh Hiếu', zaloName: 'minhhieu', avatar: '', role: 'member' },
    ];
    return {
      groupId: 'mock_link_group',
      groupName: 'Nhóm từ link Zalo (mock)',
      totalMember: members.length,
      members,
      avatar: 'https://images.unsplash.com/photo-1582213782179-e0d53f98f2ca?auto=format&fit=crop&w=150',
    };
  }

  async createGroup(name: string, members: string[]): Promise<{ success: boolean; groupId?: string; error?: string }> {
    console.log(`[MockZaloChannel] Creating group: ${name} with members: ${members.join(', ')}`);
    return {
      success: true,
      groupId: `mock_group_${Date.now()}`,
    };
  }

  async joinGroup(link: string): Promise<{ success: boolean; error?: string }> {
    console.log(`[MockZaloChannel] Joining group via link: ${link}`);
    return { success: true };
  }

  async inviteToGroup(userId: string, groupId: string): Promise<{ success: boolean; error?: string }> {
    console.log(`[MockZaloChannel] Inviting user ${userId} to group ${groupId}`);
    return { success: true };
  }

  async findUser(phoneNumber: string): Promise<any> {
    console.log(`[MockZaloChannel] Finding user by phone: ${phoneNumber}`);
    return {
      uid: `mock_user_${phoneNumber}`,
      zalo_name: `User ${phoneNumber}`,
      display_name: `Khách Hàng ${phoneNumber}`,
      avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150',
    };
  }

  async sendFriendRequest(userId: string, message: string): Promise<{ success: boolean; error?: string }> {
    console.log(`[MockZaloChannel] Sending friend request to ${userId} with message: ${message}`);
    return { success: true };
  }

  async acceptFriendRequest(userId: string): Promise<{ success: boolean; error?: string }> {
    console.log(`[MockZaloChannel] Accepting friend request from ${userId}`);
    return { success: true };
  }
}
