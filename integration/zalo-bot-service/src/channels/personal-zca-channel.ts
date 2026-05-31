/**
 * PersonalZcaChannel — primary channel adapter using zca-js for personal Zalo.
 * Credentials are loaded from backend-local files, never exposed to Flutter.
 */

import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';
import { config, projectRoot } from '../config.js';
import type {
  ZaloChannel,
  ZaloChannelStatus,
  ZaloSendMessageRequest,
  ZaloSendMessageResult,
} from './types.js';

// zca-js imports — types are inferred at build time from the local package
import { Zalo, ThreadType } from 'zca-js';
import type { API, Credentials } from 'zca-js';

let api: API | null = null;
let listenerRunning = false;
let lastEventAt: string | null = null;
let loginError: string | null = null;

async function ensureLogin(): Promise<API> {
  if (api) return api;

  const credPath = resolve(projectRoot, config.personalCredentialsPath);
  if (!existsSync(credPath)) {
    loginError = `Personal credentials not found at ${config.personalCredentialsPath}. Run "npm run zalo:login-personal" to bootstrap.`;
    throw new Error(loginError);
  }

  try {
    const raw = readFileSync(credPath, 'utf-8');
    const credentials: Credentials = JSON.parse(raw);

    const zalo = new Zalo({
      selfListen: config.personalSelfListen,
      logging: true,
    });
    api = await zalo.login(credentials);
    loginError = null;
    console.log('[PersonalZcaChannel] Logged in successfully.');
    return api;
  } catch (err) {
    loginError = `Login failed: ${err instanceof Error ? err.message : String(err)}`;
    throw new Error(loginError);
  }
}

export class PersonalZcaChannel implements ZaloChannel {
  getStatus(): ZaloChannelStatus {
    return {
      connected: api !== null,
      mode: 'personal_zca',
      accountType: 'personal',
      accountLabel: config.personalAccountLabel,
      listenerRunning,
      lastEventAt,
    };
  }

  async sendMessage(
    req: ZaloSendMessageRequest,
    isTestMode = false,
  ): Promise<ZaloSendMessageResult> {
    if (isTestMode) {
      return { success: true, messageId: `test_personal_${Date.now()}` };
    }

    try {
      const currentApi = await ensureLogin();
      const threadType =
        req.threadType === 'group' ? ThreadType.Group : ThreadType.User;

      const result = await currentApi.sendMessage(
        { msg: req.message },
        req.recipientId,
        threadType,
      );

      return {
        success: true,
        messageId: result?.msgId ?? `personal_${Date.now()}`,
      };
    } catch (err) {
      return {
        success: false,
        error:
          loginError ||
          (err instanceof Error ? err.message : 'Unknown personal send error'),
      };
    }
  }

  handleWebhookEvent(event: Record<string, unknown>): void {
    lastEventAt = new Date().toISOString();
    const eventName = event['event_name'] as string | undefined;
    console.log(
      `[PersonalZcaChannel] Event: ${eventName || 'unknown'}`,
      JSON.stringify(event).slice(0, 200),
    );
  }

  async startListener(): Promise<void> {
    if (listenerRunning) return;
    try {
      const currentApi = await ensureLogin();
      const listener = currentApi.listener;
      if (listener) {
        listener.start();
        listenerRunning = true;
        console.log('[PersonalZcaChannel] Listener started.');
      }
    } catch (err) {
      console.error('[PersonalZcaChannel] Failed to start listener:', err);
    }
  }

  async stopListener(): Promise<void> {
    if (!listenerRunning || !api) return;
    try {
      const listener = api.listener;
      if (listener) {
        listener.stop();
        listenerRunning = false;
        console.log('[PersonalZcaChannel] Listener stopped.');
      }
    } catch (err) {
      console.error('[PersonalZcaChannel] Failed to stop listener:', err);
    }
  }
}
