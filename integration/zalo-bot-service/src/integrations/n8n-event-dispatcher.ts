import { readIntegrationSettings } from './integration-store.js';

export interface N8nEventPayload {
  source: 'alpha_crm';
  eventType: string;
  timestamp: string;
  event: any;
}

export function buildN8nEventPayload(eventType: string, event: any): N8nEventPayload {
  return {
    source: 'alpha_crm',
    eventType,
    timestamp: new Date().toISOString(),
    event,
  };
}

export async function dispatchN8nEvent(eventType: string, event: any): Promise<void> {
  const settings = readIntegrationSettings();
  if (!settings.n8n.enabled || !settings.n8n.eventWebhookUrl) return;

  try {
    const response = await fetch(settings.n8n.eventWebhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Alpha-CRM-Event': eventType,
      },
      body: JSON.stringify(buildN8nEventPayload(eventType, event)),
    });
    if (!response.ok) {
      console.warn(`[n8n-dispatcher] Webhook returned HTTP ${response.status}.`);
    }
  } catch (err) {
    console.warn(
      '[n8n-dispatcher] Failed to dispatch event:',
      err instanceof Error ? err.message : String(err),
    );
  }
}
