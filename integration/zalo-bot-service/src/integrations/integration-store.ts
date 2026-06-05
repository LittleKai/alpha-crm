import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { dirname, resolve } from 'path';
import { projectRoot } from '../config.js';

export interface N8nIntegrationSettings {
  enabled: boolean;
  baseUrl: string;
  apiKey: string;
  eventWebhookUrl: string;
  callbackUrl: string;
}

export interface FacebookIntegrationStatus {
  status: 'not_configured' | 'cloud_required' | 'configured';
  pageName?: string;
  pageId?: string;
}

export interface IntegrationSettings {
  n8n: N8nIntegrationSettings;
  facebook: FacebookIntegrationStatus;
}

const defaultSettings: IntegrationSettings = {
  n8n: {
    enabled: false,
    baseUrl: '',
    apiKey: '',
    eventWebhookUrl: '',
    callbackUrl: '',
  },
  facebook: {
    status: 'cloud_required',
  },
};

export function integrationSettingsPath(): string {
  return resolve(projectRoot, '.data/integrations/settings.json');
}

export function readIntegrationSettings(
  filePath = integrationSettingsPath(),
): IntegrationSettings {
  if (!existsSync(filePath)) return defaultSettings;
  try {
    const raw = JSON.parse(readFileSync(filePath, 'utf-8')) as Partial<IntegrationSettings>;
    return normalizeSettings(raw);
  } catch {
    return defaultSettings;
  }
}

export function writeIntegrationSettings(
  settings: Partial<IntegrationSettings>,
  filePath = integrationSettingsPath(),
): IntegrationSettings {
  const normalized = normalizeSettings(settings);
  mkdirSync(dirname(filePath), { recursive: true });
  writeFileSync(filePath, JSON.stringify(normalized, null, 2), 'utf-8');
  return normalized;
}

export function maskIntegrationSettings(settings: IntegrationSettings): IntegrationSettings {
  return {
    ...settings,
    n8n: {
      ...settings.n8n,
      apiKey: maskSecret(settings.n8n.apiKey),
    },
  };
}

function normalizeSettings(settings: Partial<IntegrationSettings>): IntegrationSettings {
  return {
    n8n: {
      enabled: settings.n8n?.enabled === true,
      baseUrl: normalizeBaseUrl(settings.n8n?.baseUrl || ''),
      apiKey: String(settings.n8n?.apiKey || '').trim(),
      eventWebhookUrl: normalizeBaseUrl(settings.n8n?.eventWebhookUrl || ''),
      callbackUrl: normalizeBaseUrl(settings.n8n?.callbackUrl || ''),
    },
    facebook: {
      status: settings.facebook?.status || 'cloud_required',
      pageName: settings.facebook?.pageName || undefined,
      pageId: settings.facebook?.pageId || undefined,
    },
  };
}

function normalizeBaseUrl(value: string): string {
  const trimmed = String(value || '').trim();
  if (!trimmed) return '';
  return trimmed.endsWith('/') ? trimmed.slice(0, -1) : trimmed;
}

function maskSecret(value: string): string {
  if (!value) return '';
  if (value.length <= 4) return '****';
  const visible = value.slice(-4);
  return `************${visible}`;
}
