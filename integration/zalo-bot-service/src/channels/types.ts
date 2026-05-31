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

export interface ZaloChannel {
  getStatus(): ZaloChannelStatus;
  sendMessage(req: ZaloSendMessageRequest, isTestMode?: boolean): Promise<ZaloSendMessageResult>;
  handleWebhookEvent?(event: Record<string, unknown>): void;
  startListener?(): Promise<void>;
  stopListener?(): Promise<void>;
}
