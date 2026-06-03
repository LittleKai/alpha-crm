/**
 * Zalo channel selector — routes to personal/OA/mock adapter based on config.
 * Keeps existing exported functions so server.ts changes are minimal.
 */

import { config } from './config.js';
import type { ZaloChannel, ZaloSendMessageRequest, ZaloSendMessageResult, ZaloChannelStatus, ZaloFriend, ZaloGroupMember } from './channels/types.js';
import { PersonalZcaChannel } from './channels/personal-zca-channel.js';
import { OfficialOaChannel } from './channels/official-oa-channel.js';
import { MockZaloChannel } from './channels/mock-channel.js';

function createChannel(): ZaloChannel {
  switch (config.channelMode) {
    case 'personal_zca':
      return new PersonalZcaChannel();
    case 'official_oa':
      return new OfficialOaChannel();
    case 'mock':
      return new MockZaloChannel();
    default:
      console.warn(
        `[zalo] Unknown channel mode "${config.channelMode}", falling back to mock.`,
      );
      return new MockZaloChannel();
  }
}

const channel: ZaloChannel = createChannel();

export type { ZaloChannelStatus };

export function getZaloStatus(): ZaloChannelStatus {
  return channel.getStatus();
}

export async function sendMessage(
  req: ZaloSendMessageRequest,
  isTestMode = false,
): Promise<ZaloSendMessageResult> {
  return channel.sendMessage(req, isTestMode);
}

export function handleWebhookEvent(event: Record<string, unknown>): void {
  channel.handleWebhookEvent?.(event);
}

export async function getAllGroups(): Promise<any[]> {
  if (!channel.getAllGroups) return [];
  return channel.getAllGroups();
}

export async function leaveGroup(groupId: string, silent = false, accountId?: string): Promise<boolean> {
  if (!channel.leaveGroup) return false;
  return channel.leaveGroup(groupId, silent, accountId);
}

export function getAccounts(): any[] {
  if (!channel.getAccounts) return [];
  return channel.getAccounts();
}

export async function deleteAccount(accountId: string): Promise<boolean> {
  if (!channel.deleteAccount) return false;
  return channel.deleteAccount(accountId);
}

export async function initializeZalo(): Promise<void> {
  if (channel.startListener) {
    console.log('[zalo] Initializing and starting Zalo listener on boot...');
    await channel.startListener();
  }
}

export async function getAllFriends(): Promise<ZaloFriend[]> {
  if (!channel.getAllFriends) return [];
  return channel.getAllFriends();
}

export async function getGroupMembers(groupId: string): Promise<ZaloGroupMember[]> {
  if (!channel.getGroupMembers) return [];
  return channel.getGroupMembers(groupId);
}

export async function getGroupLinkMembers(link: string): Promise<{ groupId: string; groupName: string; totalMember: number; members: ZaloGroupMember[]; avatar?: string }> {
  if (!channel.getGroupLinkMembers) return { groupId: '', groupName: '', totalMember: 0, members: [], avatar: '' };
  return channel.getGroupLinkMembers(link);
}

export async function createGroup(name: string, members: string[], accountId?: string): Promise<{ success: boolean; groupId?: string; error?: string }> {
  if (!channel.createGroup) return { success: false, error: 'Method not supported on current channel.' };
  return channel.createGroup(name, members, accountId);
}

export async function joinGroup(link: string, accountId?: string): Promise<{ success: boolean; error?: string }> {
  if (!channel.joinGroup) return { success: false, error: 'Method not supported on current channel.' };
  return channel.joinGroup(link, accountId);
}

export async function inviteToGroup(userId: string, groupId: string, accountId?: string): Promise<{ success: boolean; error?: string }> {
  if (!channel.inviteToGroup) return { success: false, error: 'Method not supported on current channel.' };
  return channel.inviteToGroup(userId, groupId, accountId);
}

export async function findUser(phoneNumber: string, accountId?: string): Promise<any> {
  if (!channel.findUser) return null;
  return channel.findUser(phoneNumber, accountId);
}

export async function sendFriendRequest(userId: string, message: string, accountId?: string): Promise<{ success: boolean; error?: string }> {
  if (!channel.sendFriendRequest) return { success: false, error: 'Method not supported on current channel.' };
  return channel.sendFriendRequest(userId, message, accountId);
}

export async function acceptFriendRequest(userId: string, accountId?: string): Promise<{ success: boolean; error?: string }> {
  if (!channel.acceptFriendRequest) return { success: false, error: 'Method not supported on current channel.' };
  return channel.acceptFriendRequest(userId, accountId);
}

