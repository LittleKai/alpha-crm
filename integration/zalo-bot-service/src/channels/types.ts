/**
 * Channel adapter interface — hides personal vs OA details from server.ts.
 */

import type { ZaloChannelMode } from '../config.js';

export interface ZaloChannelStatus {
  connected: boolean;
  mode: ZaloChannelMode | 'disconnected';
  accountType: 'personal' | 'official' | 'mock' | 'none';
  accountLabel: string;
  listenerRunning: boolean;
  lastEventAt: string | null;
}

export interface ZaloSendMessageRequest {
  recipientId: string;
  message: string;
  threadType?: 'user' | 'group';
  messageType?: 'text' | 'template';
}

export interface ZaloSendMessageResult {
  success: boolean;
  messageId?: string;
  error?: string;
}

export interface ZaloFriend {
  userId: string;
  displayName: string;
  zaloName: string;
  avatar: string;
  phoneNumber: string;
  isFriend: boolean;
}

export interface ZaloGroupMember {
  id: string;
  displayName: string;
  zaloName: string;
  avatar: string;
  role: 'owner' | 'admin' | 'member';
}

export interface ZaloChannel {
  getStatus(): ZaloChannelStatus;
  sendMessage(req: ZaloSendMessageRequest, isTestMode?: boolean): Promise<ZaloSendMessageResult>;
  handleWebhookEvent?(event: Record<string, unknown>): void;
  startListener?(): Promise<void>;
  stopListener?(): Promise<void>;
  getAllGroups?(): Promise<any[]>;
  leaveGroup?(groupId: string, silent?: boolean): Promise<boolean>;
  getAccounts?(): any[];
  deleteAccount?(accountId: string): Promise<boolean>;
  getAllFriends?(): Promise<ZaloFriend[]>;
  getGroupMembers?(groupId: string): Promise<ZaloGroupMember[]>;
  getGroupLinkMembers?(link: string): Promise<{ groupId: string; groupName: string; totalMember: number; members: ZaloGroupMember[] }>;
  createGroup?(name: string, members: string[]): Promise<{ success: boolean; groupId?: string; error?: string }>;
  joinGroup?(link: string): Promise<{ success: boolean; error?: string }>;
  inviteToGroup?(userId: string, groupId: string): Promise<{ success: boolean; error?: string }>;
  findUser?(phoneNumber: string): Promise<any>;
  sendFriendRequest?(userId: string, message: string): Promise<{ success: boolean; error?: string }>;
  acceptFriendRequest?(userId: string): Promise<{ success: boolean; error?: string }>;
}
