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
  // Account-aware recovery hint for the health monitor. `listenerRunning` is a
  // coarse pool-level OR (any account listening), which misses a second account
  // whose listener dropped while the first is still up. When set, it means at
  // least one live (non-expired) account has a stopped listener and should be
  // recovered. Optional so single-account/mock channels can omit it.
  needsListenerRecovery?: boolean;
}

export interface ZaloSendMessageRequest {
  recipientId: string;
  message: string;
  accountId?: string;
  threadType?: 'user' | 'group';
  messageType?: 'text' | 'template' | 'image' | 'file' | 'sticker' | 'video' | 'voice' | 'gif' | 'link' | 'rich';
  /** File paths or URLs for attachments (images, videos, files) */
  attachments?: string[];
  /** Original filenames of attachments to display to the recipient */
  attachmentNames?: string[];
  clientMessageId?: string;
  quote?: Record<string, unknown>;
  mentions?: Array<Record<string, unknown>>;
  styles?: Array<Record<string, unknown>>;
  link?: Record<string, unknown>;
  sticker?: Record<string, unknown>;
  video?: Record<string, unknown>;
  voice?: Record<string, unknown>;
  metadata?: Record<string, unknown>;
}

export interface ZaloSendMessageResult {
  success: boolean;
  messageId?: string;
  /** Zalo client message id (cliMsgId/clientId) required by undo/reaction APIs */
  clientMessageId?: string;
  attachmentMessageIds?: string[];
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
  /** Per-sender avatar URL (especially useful for group chats) */
  senderAvatarUrl?: string;
  /** Group display name (only set for group threads) */
  groupName?: string;
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
    | 'reminder'
    | 'poll'
    | 'system'
    | 'rich'
    | 'unknown';
  providerMessageId: string;
  clientMessageId?: string;
  quote?: Record<string, unknown>;
  mentions?: unknown[];
  styles?: unknown[];
  metadata?: Record<string, unknown>;
  attachments?: Array<{
    kind: string;
    name?: string;
    url?: string;
    localPath?: string;
    mimeType?: string;
    sizeBytes?: number;
    metadata?: Record<string, unknown>;
  }>;
  timestamp: string;
}

export interface ZaloAuxiliaryEvent {
  type:
    | 'message.recalled'
    | 'message.deleted'
    | 'message.delivered'
    | 'message.seen'
    | 'message.reaction'
    | 'typing.started'
    | 'typing.stopped'
    | 'group.updated'
    | 'friend.updated'
    | 'system.message';
  accountId: string;
  threadId: string;
  threadType: 'user' | 'group';
  providerMessageId?: string;
  clientMessageId?: string;
  userId?: string;
  reaction?: string;
  timestamp: string;
  data?: Record<string, unknown>;
}

type InboundMessageHandler = (event: ZaloInboundMessageEvent) => void | Promise<void>;
type InboundMessageBatchHandler = (
  events: ZaloInboundMessageEvent[],
) => void | Promise<void>;

let inboundMessageHandler: InboundMessageHandler | null = null;
let inboundMessageBatchHandler: InboundMessageBatchHandler | null = null;

export function setInboundMessageHandler(handler: InboundMessageHandler | null): void {
  inboundMessageHandler = handler;
}

export function setInboundMessageBatchHandler(
  handler: InboundMessageBatchHandler | null,
): void {
  inboundMessageBatchHandler = handler;
}

export async function emitInboundMessage(event: ZaloInboundMessageEvent): Promise<void> {
  if (!inboundMessageHandler) return;
  await inboundMessageHandler(event);
}

export async function emitInboundMessages(
  events: ZaloInboundMessageEvent[],
): Promise<void> {
  if (events.length === 0) return;
  if (inboundMessageBatchHandler) {
    await inboundMessageBatchHandler(events);
    return;
  }
  for (const event of events) {
    await emitInboundMessage(event);
  }
}

export interface ZaloChannel {
  getStatus(): ZaloChannelStatus;
  sendMessage(req: ZaloSendMessageRequest, isTestMode?: boolean): Promise<ZaloSendMessageResult>;
  recallMessage?(req: ZaloRecallMessageRequest): Promise<{ success: boolean; error?: string }>;
  sendTyping?(accountId: string, threadId: string, threadType: 'user' | 'group'): Promise<boolean>;
  reactMessage?(request: {
    accountId: string;
    threadId: string;
    threadType: 'user' | 'group';
    msgId: string;
    cliMsgId?: string;
    reaction: string;
  }): Promise<{ success: boolean; error?: string }>;
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
