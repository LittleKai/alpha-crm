import type { ZaloChannel } from './types.js';
import { config } from '../config.js';
import { getChannelInstance } from '../zalo.js';
import { FacebookChannel } from './facebook-channel.js';
import { TiktokChannel } from './tiktok-channel.js';

/**
 * Multi-channel registry: maps a channel key (e.g. 'zalo_personal', 'zalo_oa',
 * 'facebook_page', 'tiktok') to its ZaloChannel-shaped adapter instance.
 *
 * Registers the active Zalo singleton plus FacebookChannel and TiktokChannel.
 * TiktokChannel mirrors FacebookChannel's structure but is not yet verified
 * against real TikTok Business Messaging API docs/credentials.
 */
const registry = new Map<string, ZaloChannel>();

function activeZaloChannelKey(): string {
  return config.channelMode === 'official_oa' ? 'zalo_oa' : 'zalo_personal';
}

registry.set(activeZaloChannelKey(), getChannelInstance());
registry.set('facebook_page', new FacebookChannel());
registry.set('tiktok', new TiktokChannel());

export function getChannel(channelKey: string): ZaloChannel | undefined {
  return registry.get(channelKey);
}

export function registerChannel(channelKey: string, instance: ZaloChannel): void {
  registry.set(channelKey, instance);
}

export function listRegisteredChannels(): string[] {
  return Array.from(registry.keys());
}
