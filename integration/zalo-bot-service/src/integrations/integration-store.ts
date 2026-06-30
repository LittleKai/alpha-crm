import { existsSync } from 'fs';
import { resolve } from 'path';
import { dataRoot } from '../config.js';
import { readSecure, writeSecure } from '../secure-store.js';

export interface N8nIntegrationSettings {
  enabled: boolean;
  baseUrl: string;
  apiKey: string;
  eventWebhookUrl: string;
  callbackUrl: string;
}

export interface FacebookIntegrationStatus {
  status: 'not_configured' | 'cloud_required' | 'configured';
  enabled?: boolean;
  pageName?: string;
  pageId?: string;
  appId?: string;
  webhookCallbackUrl?: string;
  verifyToken?: string;
  pageAccessToken?: string;
  enforce24hWindow?: boolean;
}

export interface EmailIntegrationSettings {
  enabled: boolean;
  mode: 'transactional' | 'inbox';
  fromName: string;
  fromAddress: string;
  smtpHost: string;
  smtpPort: number;
  smtpSecure: boolean;
  smtpUsername: string;
  smtpPassword: string;
  inboundEnabled: boolean;
  imapHost: string;
  imapPort: number;
  imapSecure: boolean;
  imapUsername: string;
  imapPassword: string;
}

export interface IntegrationSettings {
  n8n: N8nIntegrationSettings;
  facebook: FacebookIntegrationStatus;
  email: EmailIntegrationSettings;
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
    enforce24hWindow: true,
  },
  email: {
    enabled: false,
    mode: 'transactional',
    fromName: '',
    fromAddress: '',
    smtpHost: '',
    smtpPort: 587,
    smtpSecure: false,
    smtpUsername: '',
    smtpPassword: '',
    inboundEnabled: false,
    imapHost: '',
    imapPort: 993,
    imapSecure: true,
    imapUsername: '',
    imapPassword: '',
  },
};

export function integrationSettingsPath(): string {
  return resolve(dataRoot, 'integrations/settings.json');
}

export function readIntegrationSettings(
  filePath = integrationSettingsPath(),
): IntegrationSettings {
  if (!existsSync(filePath)) return defaultSettings;
  try {
    const contents = readSecure(filePath);
    if (!contents) return defaultSettings;
    const raw = JSON.parse(contents) as Partial<IntegrationSettings>;
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
  writeSecure(filePath, JSON.stringify(normalized, null, 2));
  return normalized;
}

export function maskIntegrationSettings(settings: IntegrationSettings): IntegrationSettings {
  return {
    ...settings,
    n8n: {
      ...settings.n8n,
      apiKey: maskSecret(settings.n8n.apiKey),
    },
    email: {
      ...settings.email,
      smtpPassword: maskSecret(settings.email.smtpPassword),
      imapPassword: maskSecret(settings.email.imapPassword),
    },
    facebook: {
      ...settings.facebook,
      verifyToken: maskSecret(settings.facebook.verifyToken || ''),
      pageAccessToken: maskSecret(settings.facebook.pageAccessToken || ''),
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
      enabled: settings.facebook?.enabled === true,
      pageName: settings.facebook?.pageName || undefined,
      pageId: settings.facebook?.pageId || undefined,
      appId: settings.facebook?.appId || undefined,
      webhookCallbackUrl: normalizeBaseUrl(settings.facebook?.webhookCallbackUrl || ''),
      verifyToken: String(settings.facebook?.verifyToken || '').trim(),
      pageAccessToken: String(settings.facebook?.pageAccessToken || '').trim(),
      enforce24hWindow: settings.facebook?.enforce24hWindow !== false,
    },
    email: {
      enabled: settings.email?.enabled === true,
      mode: settings.email?.mode === 'inbox' ? 'inbox' : 'transactional',
      fromName: String(settings.email?.fromName || '').trim(),
      fromAddress: String(settings.email?.fromAddress || '').trim(),
      smtpHost: normalizeHost(settings.email?.smtpHost || ''),
      smtpPort: normalizePort(settings.email?.smtpPort, 587),
      smtpSecure: settings.email?.smtpSecure === true,
      smtpUsername: String(settings.email?.smtpUsername || '').trim(),
      smtpPassword: String(settings.email?.smtpPassword || '').trim(),
      inboundEnabled: settings.email?.inboundEnabled === true,
      imapHost: normalizeHost(settings.email?.imapHost || ''),
      imapPort: normalizePort(settings.email?.imapPort, 993),
      imapSecure: settings.email?.imapSecure !== false,
      imapUsername: String(settings.email?.imapUsername || '').trim(),
      imapPassword: String(settings.email?.imapPassword || '').trim(),
    },
  };
}

function normalizeBaseUrl(value: string): string {
  const trimmed = String(value || '').trim();
  if (!trimmed) return '';
  return trimmed.endsWith('/') ? trimmed.slice(0, -1) : trimmed;
}

function normalizeHost(value: string): string {
  return String(value || '').trim().replace(/\/+$/, '');
}

function normalizePort(value: unknown, fallback: number): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0 || parsed > 65535) return fallback;
  return parsed;
}

function maskSecret(value: string): string {
  if (!value) return '';
  if (value.length <= 4) return '****';
  const visible = value.slice(-4);
  return `************${visible}`;
}
