/**
 * Local-first Live Chat type definitions.
 * These types represent the SQLite schema for local message storage.
 */

export type JsonPrimitive = string | number | boolean | null;
export type JsonValue = JsonPrimitive | JsonObject | JsonValue[];
export interface JsonObject {
  [key: string]: JsonValue;
}

export interface LocalConversation {
  id: string;
  accountId: string;
  threadId: string;
  threadType: 'user' | 'group';
  displayName: string;
  avatarUrl: string;
  lastMessagePreview: string;
  lastMessageAt: string;
  unreadCount: number;
  tags: string[];
  notes: string;
  customAttributes: Record<string, string>;
  archived: boolean;
  assignedTo: string;
  followUpAt: string;
  timeline: LocalConversationTimelineItem[];
  managedGroup: boolean;
  cloudConversationId: string;
  createdAt: string;
  updatedAt: string;
}

export interface LocalConversationTimelineItem {
  id: string;
  eventType: string;
  summary: string;
  metadata: Record<string, unknown>;
  createdAt: string;
}

export interface LocalMessage {
  id: string;
  conversationId: string;
  accountId: string;
  threadId: string;
  threadType: 'user' | 'group';
  direction: 'inbound' | 'outbound';
  senderId: string;
  senderName: string;
  senderAvatarUrl: string;
  content: string;
  messageType: string;
  providerMessageId: string;
  clientMessageId: string;
  zaloMsgId: string;
  status: string;
  errorText: string;
  quoteJson: string;
  mentionsJson: string;
  stylesJson: string;
  metadataJson: string;
  recalledContent: string;
  isDeleted: boolean;
  receivedAt: string;
  sentAt: string;
  createdAt: string;
  updatedAt: string;
}

export interface LocalAttachment {
  id: string;
  messageId: string;
  kind: string;
  name: string;
  url: string;
  localPath: string;
  mimeType: string;
  sizeBytes: number;
  metadataJson: string;
  status: string;
  checksum: string;
  errorText: string;
  downloadedAt: string;
  createdAt: string;
}

export interface InboundMessageInput {
  accountId: string;
  threadId: string;
  threadType: 'user' | 'group';
  /**
   * Message direction. Self-sent messages that arrive through the live
   * `message` / `old_messages` listener (e.g. the operator typing on their
   * phone) must be stored as 'outbound' so they render on the correct side.
   * Defaults to 'inbound' when omitted.
   */
  direction?: 'inbound' | 'outbound';
  senderId: string;
  senderName: string;
  avatarUrl?: string;
  /** Per-sender avatar URL (especially for group chats) */
  senderAvatarUrl?: string;
  /** Group display name (only set for group threads) */
  groupName?: string;
  content: string;
  messageType: string;
  providerMessageId: string;
  clientMessageId?: string;
  timestamp: string;
  quote?: Record<string, unknown>;
  mentions?: unknown[];
  styles?: unknown[];
  metadata?: Record<string, unknown>;
  attachments?: AttachmentInput[];
}

export interface OutboundMessageInput {
  accountId: string;
  threadId: string;
  threadType: 'user' | 'group';
  content: string;
  messageType?: string;
  clientMessageId?: string;
  quote?: Record<string, unknown>;
  mentions?: unknown[];
  styles?: unknown[];
  metadata?: Record<string, unknown>;
  attachments?: AttachmentInput[];
}

export interface AttachmentInput {
  kind: string;
  name?: string;
  url?: string;
  localPath?: string;
  mimeType?: string;
  sizeBytes?: number;
  metadata?: Record<string, unknown>;
}

export interface MessagePage {
  messages: LocalMessage[];
  attachments: Map<string, LocalAttachment[]>;
}

export interface MessageReceipt {
  messageId: string;
  userId: string;
  status: 'delivered' | 'seen';
  timestamp: string;
}

export interface MessageReaction {
  messageId: string;
  userId: string;
  reaction: string;
  timestamp: string;
}

export interface HistoryState {
  oldestTimestamp: string;
  hasMore: boolean;
  loading: boolean;
  lastError: string;
}
