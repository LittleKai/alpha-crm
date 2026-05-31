/**
 * Zalo channel selector — routes to personal/OA/mock adapter based on config.
 * Keeps existing exported functions so server.ts changes are minimal.
 */

import { config } from './config.js';
import type { ZaloChannel, ZaloSendMessageRequest, ZaloSendMessageResult, ZaloChannelStatus } from './channels/types.js';
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
