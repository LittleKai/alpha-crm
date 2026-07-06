import {
  readIntegrationSettings,
  writeIntegrationSettings,
  type WebchatWidgetSettings,
} from '../integrations/integration-store.js';
import { emitInboundMessage } from './types.js';
import type {
  ZaloChannel,
  ZaloChannelStatus,
  ZaloInboundMessageEvent,
  ZaloSendMessageRequest,
  ZaloSendMessageResult,
} from './types.js';

let lastEventAt: string | null = null;

function connectedWidgets(): WebchatWidgetSettings[] {
  return readIntegrationSettings().webchatWidgets.filter(
    (widget) => widget.status === 'configured' && widget.enabled === true && !!widget.widgetId,
  );
}

/**
 * Webchat widget adapter. Unlike every other channel, there is no 3rd-party
 * API to call: the guest browser talks directly to the cloud backend's
 * public webchatPublic.js routes, which already report inbound messages to
 * this device via CrmAgentCommand (same relay path as Facebook/Telegram/etc)
 * and outbound replies via the existing reportOutboundMessageEvent() generic
 * sync — so sendMessage() here only needs to succeed locally, it never talks
 * to an external API.
 */
export class WebchatChannel implements ZaloChannel {
  getStatus(): ZaloChannelStatus {
    const widgets = connectedWidgets();
    const accountLabel = widgets.length === 0
      ? 'N/A'
      : widgets.length === 1
        ? (widgets[0].widgetName || widgets[0].widgetId || 'N/A')
        : `${widgets.length} Webchat widgets`;

    return {
      connected: widgets.length > 0,
      mode: 'webchat',
      accountType: 'webchat',
      accountLabel,
      listenerRunning: false,
      lastEventAt,
    };
  }

  async sendMessage(
    req: ZaloSendMessageRequest,
    isTestMode = false,
  ): Promise<ZaloSendMessageResult> {
    if (isTestMode) {
      return { success: true, messageId: `test_webchat_${Date.now()}` };
    }

    const widget = connectedWidgets().find((w) => w.widgetId === req.accountId);
    if (!widget) {
      return { success: false, error: 'Webchat widget is not configured.' };
    }

    return { success: true, messageId: `webchat_${Date.now()}` };
  }

  handleWebhookEvent(event: Record<string, unknown>): void {
    lastEventAt = new Date().toISOString();
    // The cloud (webchatPublic.js) already normalized this payload into
    // ZaloInboundMessageEvent shape before relaying it down via
    // CrmAgentCommand, so it can be passed straight through to the shared
    // inbound funnel (local SQLite write + chatbot engagement).
    void emitInboundMessage(event as unknown as ZaloInboundMessageEvent).catch((err) => {
      console.warn(
        '[WebchatChannel] Failed to emit inbound relayed message:',
        err instanceof Error ? err.message : String(err),
      );
    });
  }

  async getAllGroups(): Promise<any[]> {
    console.log('[WebchatChannel] Webchat has no group concept.');
    return [];
  }

  async leaveGroup(_groupId: string, _silent = false): Promise<boolean> {
    console.log('[WebchatChannel] Webchat does not support leaving groups.');
    return false;
  }

  getAccounts(): any[] {
    return connectedWidgets().map((widget) => ({
      id: widget.widgetId,
      label: widget.widgetName ? `Webchat: ${widget.widgetName}` : `Webchat: ${widget.widgetId}`,
      connected: true,
      listenerRunning: false,
    }));
  }

  async deleteAccount(widgetId: string): Promise<boolean> {
    const current = readIntegrationSettings();
    const remaining = current.webchatWidgets.filter((widget) => widget.widgetId !== widgetId);
    if (remaining.length === current.webchatWidgets.length) return false;
    writeIntegrationSettings({ ...current, webchatWidgets: remaining });
    return true;
  }
}
