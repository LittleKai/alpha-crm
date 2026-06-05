/**
 * Local-first Live Chat type definitions.
 * These types represent the SQLite schema for local message storage.
 */

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
  managedGroup: boolean;
  cloudConversationId: string;
  createdAt: string;
  updatedAt: string;
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
  content: string;
  messageType: string;
  providerMessageId: string;
  zaloMsgId: string;
  status: string;
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
  createdAt: string;
}

export interface InboundMessageInput {
  accountId: string;
  threadId: string;
  threadType: 'user' | 'group';
  senderId: string;
  senderName: string;
  avatarUrl?: string;
  content: string;
  messageType: string;
  providerMessageId: string;
  timestamp: string;
  attachments?: AttachmentInput[];
}

export interface OutboundMessageInput {
  accountId: string;
  threadId: string;
  threadType: 'user' | 'group';
  content: string;
  messageType?: string;
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
