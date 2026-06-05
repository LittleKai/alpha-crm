import type { N8nIntegrationSettings } from './integration-store.js';

export interface N8nConnectionResult {
  success: boolean;
  status?: number;
  error?: string;
}

export function toN8nCreateWorkflowRequest(payload: any): Record<string, unknown> {
  return {
    name: payload.name,
    active: payload.active === true,
    nodes: payload.nodes || [],
    connections: payload.connections || {},
    settings: payload.settings || {},
  };
}

export class N8nClient {
  private readonly baseUrl: string;
  private readonly apiKey: string;

  constructor(settings: Pick<N8nIntegrationSettings, 'baseUrl' | 'apiKey'>) {
    this.baseUrl = normalizeBaseUrl(settings.baseUrl);
    this.apiKey = settings.apiKey.trim();
  }

  async testConnection(): Promise<N8nConnectionResult> {
    if (!this.baseUrl || !this.apiKey) {
      return { success: false, error: 'Missing n8n base URL or API key.' };
    }
    try {
      const response = await fetch(`${this.baseUrl}/api/v1/workflows?limit=1`, {
        method: 'GET',
        headers: this.headers(),
      });
      return response.ok
        ? { success: true, status: response.status }
        : { success: false, status: response.status, error: await readError(response) };
    } catch (err) {
      return { success: false, error: err instanceof Error ? err.message : String(err) };
    }
  }

  async listWorkflows(): Promise<any> {
    const response = await fetch(`${this.baseUrl}/api/v1/workflows`, {
      method: 'GET',
      headers: this.headers(),
    });
    if (!response.ok) {
      throw new Error(await readError(response));
    }
    return response.json();
  }

  async createWorkflow(payload: any): Promise<any> {
    const response = await fetch(`${this.baseUrl}/api/v1/workflows`, {
      method: 'POST',
      headers: {
        ...this.headers(),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(toN8nCreateWorkflowRequest(payload)),
    });
    if (!response.ok) {
      throw new Error(await readError(response));
    }
    return response.json();
  }

  private headers(): Record<string, string> {
    return {
      Accept: 'application/json',
      'X-N8N-API-KEY': this.apiKey,
    };
  }
}

async function readError(response: Response): Promise<string> {
  try {
    const body = await response.json() as Record<string, any>;
    return body.message || body.error || `n8n API error ${response.status}`;
  } catch {
    return `n8n API error ${response.status}`;
  }
}

function normalizeBaseUrl(value: string): string {
  const trimmed = String(value || '').trim();
  return trimmed.endsWith('/') ? trimmed.slice(0, -1) : trimmed;
}
