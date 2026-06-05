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
  accountId?: string;
  threadType?: 'user' | 'group';
  messageType?: 'text' | 'template' | 'image' | 'file' | 'sticker' | 'video' | 'voice' | 'gif' | 'link' | 'rich';
  /** File paths or URLs for attachments (images, videos, files) */
  attachments?: string[];
}

export interface ZaloSendMessageResult {
  success: boolean;
  messageId?: string;
  error?: string;
}

export interface ZaloRecallMessageRequest {
  accountId?: string;
  threadId: string;
  threadType?: 'user' | 'group';
  /** The provider message ID (msgId from Zalo) */
  msgId: string;
  /** The client message ID */
  cliMsgId?: string;
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

export interface ZaloInboundMessageEvent {
  accountId: string;
  accountLabel?: string;
  threadId: string;
  threadType: 'user' | 'group';
  senderId: string;
  senderName?: string;
  avatarUrl?: string;
  content: string;
  messageType:
    | 'text'
    | 'image'
    | 'file'
    | 'sticker'
    | 'video'
    | 'voice'
    | 'gif'
    | 'link'
    | 'location'
    | 'contact_card'
    | 'rich'
    | 'unknown';
  providerMessageId: string;
  timestamp: string;
}

type InboundMessageHandler = (event: ZaloInboundMessageEvent) => void | Promise<void>;

let inboundMessageHandler: InboundMessageHandler | null = null;

export function setInboundMessageHandler(handler: InboundMessageHandler | null): void {
  inboundMessageHandler = handler;
}

export async function emitInboundMessage(event: ZaloInboundMessageEvent): Promise<void> {
  if (!inboundMessageHandler) return;
  await inboundMessageHandler(event);
}

export interface ZaloChannel {
  getStatus(): ZaloChannelStatus;
  sendMessage(req: ZaloSendMessageRequest, isTestMode?: boolean): Promise<ZaloSendMessageResult>;
  recallMessage?(req: ZaloRecallMessageRequest): Promise<{ success: boolean; error?: string }>;
  handleWebhookEvent?(event: Record<string, unknown>): void;
  startListener?(): Promise<void>;
  stopListener?(): Promise<void>;
  getAllGroups?(): Promise<any[]>;
  leaveGroup?(groupId: string, silent?: boolean, accountId?: string): Promise<boolean>;
  getAccounts?(): any[];
  updateAccountSettings?(accountId: string, settings: Record<string, unknown>): Promise<boolean>;
  deleteAccount?(accountId: string): Promise<boolean>;
  getAllFriends?(accountId?: string): Promise<ZaloFriend[]>;
  getGroupMembers?(groupId: string): Promise<ZaloGroupMember[]>;
  getGroupLinkMembers?(link: string): Promise<{ groupId: string; groupName: string; totalMember: number; members: ZaloGroupMember[]; avatar?: string }>;
  createGroup?(name: string, members: string[], accountId?: string): Promise<{ success: boolean; groupId?: string; error?: string }>;
  joinGroup?(link: string, accountId?: string): Promise<{ success: boolean; error?: string }>;
  inviteToGroup?(userId: string, groupId: string, accountId?: string): Promise<{ success: boolean; error?: string }>;
  findUser?(phoneNumber: string, accountId?: string): Promise<any>;
  sendFriendRequest?(userId: string, message: string, accountId?: string): Promise<{ success: boolean; error?: string }>;
  acceptFriendRequest?(userId: string, accountId?: string): Promise<{ success: boolean; error?: string }>;
}
