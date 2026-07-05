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
  /** Meta App Secret. Sent to the cloud backend (encrypted) so it can verify webhook signatures. */
  appSecret?: string;
  pageAccessToken?: string;
  enforce24hWindow?: boolean;
  /** Mongo _id returned by the cloud CrmChannelIntegration register call, used to target cloud deletes. */
  cloudId?: string;
}

export interface TiktokIntegrationStatus {
  status: 'not_configured' | 'cloud_required' | 'configured';
  enabled?: boolean;
  accountName?: string;
  accountId?: string;
  appId?: string;
  webhookCallbackUrl?: string;
  verifyToken?: string;
  /**
   * TikTok App Secret. Sent to the cloud backend (encrypted) so it can verify
   * webhook signatures, mirroring the Facebook flow. Placeholder shape —
   * not yet verified against real TikTok Business Messaging API docs.
   */
  appSecret?: string;
  accessToken?: string;
  enforce24hWindow?: boolean;
  /** Mongo _id returned by the cloud CrmChannelIntegration register call, used to target cloud deletes. */
  cloudId?: string;
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
  facebookPages: FacebookIntegrationStatus[];
  tiktokAccounts: TiktokIntegrationStatus[];
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
  facebookPages: [],
  tiktokAccounts: [],
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
    facebookPages: settings.facebookPages.map((page) => ({
      ...page,
      verifyToken: maskSecret(page.verifyToken || ''),
      appSecret: maskSecret(page.appSecret || ''),
      pageAccessToken: maskSecret(page.pageAccessToken || ''),
    })),
    tiktokAccounts: settings.tiktokAccounts.map((account) => ({
      ...account,
      verifyToken: maskSecret(account.verifyToken || ''),
      appSecret: maskSecret(account.appSecret || ''),
      accessToken: maskSecret(account.accessToken || ''),
    })),
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
    facebookPages: normalizeFacebookList(settings),
    tiktokAccounts: normalizeTiktokList(settings),
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

function normalizeFacebookEntry(entry: Partial<FacebookIntegrationStatus>): FacebookIntegrationStatus {
  return {
    status: entry.status || 'cloud_required',
    enabled: entry.enabled === true,
    pageName: entry.pageName || undefined,
    pageId: entry.pageId || undefined,
    appId: entry.appId || undefined,
    webhookCallbackUrl: normalizeBaseUrl(entry.webhookCallbackUrl || ''),
    verifyToken: String(entry.verifyToken || '').trim(),
    appSecret: String(entry.appSecret || '').trim(),
    pageAccessToken: String(entry.pageAccessToken || '').trim(),
    enforce24hWindow: entry.enforce24hWindow !== false,
    cloudId: entry.cloudId || undefined,
  };
}

function normalizeTiktokEntry(entry: Partial<TiktokIntegrationStatus>): TiktokIntegrationStatus {
  return {
    status: entry.status || 'cloud_required',
    enabled: entry.enabled === true,
    accountName: entry.accountName || undefined,
    accountId: entry.accountId || undefined,
    appId: entry.appId || undefined,
    webhookCallbackUrl: normalizeBaseUrl(entry.webhookCallbackUrl || ''),
    verifyToken: String(entry.verifyToken || '').trim(),
    appSecret: String(entry.appSecret || '').trim(),
    accessToken: String(entry.accessToken || '').trim(),
    enforce24hWindow: entry.enforce24hWindow !== false,
    cloudId: entry.cloudId || undefined,
  };
}

// One-time migration: settings.json written before multi-account support
// stored a single `facebook`/`tiktok` object instead of an array. Wrap it
// into a one-element array the first time it's read; the next write persists
// the new array shape.
function normalizeFacebookList(settings: Partial<IntegrationSettings>): FacebookIntegrationStatus[] {
  if (Array.isArray(settings.facebookPages)) {
    return settings.facebookPages.map(normalizeFacebookEntry);
  }
  const legacy = (settings as { facebook?: Partial<FacebookIntegrationStatus> }).facebook;
  return legacy?.pageId ? [normalizeFacebookEntry(legacy)] : [];
}

function normalizeTiktokList(settings: Partial<IntegrationSettings>): TiktokIntegrationStatus[] {
  if (Array.isArray(settings.tiktokAccounts)) {
    return settings.tiktokAccounts.map(normalizeTiktokEntry);
  }
  const legacy = (settings as { tiktok?: Partial<TiktokIntegrationStatus> }).tiktok;
  return legacy?.accountId ? [normalizeTiktokEntry(legacy)] : [];
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
