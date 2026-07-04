import type { ZaloChannel } from './types.js';
import { config } from '../config.js';
import { getChannelInstance } from '../zalo.js';

/**
 * Multi-channel registry: maps a channel key (e.g. 'zalo_personal', 'zalo_oa',
 * 'facebook_page', 'tiktok') to its ZaloChannel-shaped adapter instance.
 *
 * Facebook/TikTok adapters are registered here once implemented; for now only
 * the existing Zalo singleton is registered so current Zalo behavior is unchanged.
 */
const registry = new Map<string, ZaloChannel>();

function activeZaloChannelKey(): string {
  return config.channelMode === 'official_oa' ? 'zalo_oa' : 'zalo_personal';
}

registry.set(activeZaloChannelKey(), getChannelInstance());

export function getChannel(channelKey: string): ZaloChannel | undefined {
  return registry.get(channelKey);
}

export function registerChannel(channelKey: string, instance: ZaloChannel): void {
  registry.set(channelKey, instance);
}

export function listRegisteredChannels(): string[] {
  return Array.from(registry.keys());
}
