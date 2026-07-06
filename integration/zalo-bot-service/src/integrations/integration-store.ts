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

export interface InstagramIntegrationStatus {
  status: 'not_configured' | 'cloud_required' | 'configured';
  enabled?: boolean;
  accountName?: string;
  accountId?: string;
  appId?: string;
  webhookCallbackUrl?: string;
  verifyToken?: string;
  /** Meta App Secret (same app as Facebook Messenger). Sent to the cloud backend (encrypted) so it can verify webhook signatures. */
  appSecret?: string;
  accessToken?: string;
  enforce24hWindow?: boolean;
  /** Mongo _id returned by the cloud CrmChannelIntegration register call, used to target cloud deletes. */
  cloudId?: string;
}

export interface WhatsappIntegrationStatus {
  status: 'not_configured' | 'cloud_required' | 'configured';
  enabled?: boolean;
  accountName?: string;
  /** WhatsApp phone_number_id, one CrmChannelIntegration row per registered phone number. */
  accountId?: string;
  appId?: string;
  webhookCallbackUrl?: string;
  verifyToken?: string;
  /** Meta App Secret (WhatsApp Cloud API rides the same Graph API app). Sent to the cloud backend (encrypted) so it can verify webhook signatures. */
  appSecret?: string;
  accessToken?: string;
  enforce24hWindow?: boolean;
  /** Mongo _id returned by the cloud CrmChannelIntegration register call, used to target cloud deletes. */
  cloudId?: string;
}

export interface TelegramIntegrationStatus {
  status: 'not_configured' | 'cloud_required' | 'configured';
  enabled?: boolean;
  /** Bot username (e.g. "MyCrmBot"), for display only. */
  accountName?: string;
  /** Bot's numeric id (the part of botToken before ':'), used by the cloud webhook route to identify the bot. */
  accountId?: string;
  webhookCallbackUrl?: string;
  /** Telegram Bot API token, e.g. "123456789:ABC-DEF...". Sent to the cloud backend (encrypted); only used locally for outbound sendMessage calls. */
  botToken?: string;
  /** Telegram webhook secret_token, echoed back on every update via X-Telegram-Bot-Api-Secret-Token. */
  verifyToken?: string;
  /** Mongo _id returned by the cloud CrmChannelIntegration register call, used to target cloud deletes. */
  cloudId?: string;
}

export interface WebchatWidgetSettings {
  status: 'not_configured' | 'cloud_required' | 'configured';
  enabled?: boolean;
  /** Randomly generated locally; doubles as the public widgetId (externalAccountId on the cloud) and the embed script's data-widget-id value. */
  widgetId?: string;
  widgetName?: string;
  welcomeMessage?: string;
  primaryColorHex?: string;
  /** Free-text label for the site/domain this widget is embedded on, display only. */
  siteLabel?: string;
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
  instagramAccounts: InstagramIntegrationStatus[];
  whatsappAccounts: WhatsappIntegrationStatus[];
  telegramBots: TelegramIntegrationStatus[];
  webchatWidgets: WebchatWidgetSettings[];
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
  instagramAccounts: [],
  whatsappAccounts: [],
  telegramBots: [],
  webchatWidgets: [],
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
    instagramAccounts: settings.instagramAccounts.map((account) => ({
      ...account,
      verifyToken: maskSecret(account.verifyToken || ''),
      appSecret: maskSecret(account.appSecret || ''),
      accessToken: maskSecret(account.accessToken || ''),
    })),
    whatsappAccounts: settings.whatsappAccounts.map((account) => ({
      ...account,
      verifyToken: maskSecret(account.verifyToken || ''),
      appSecret: maskSecret(account.appSecret || ''),
      accessToken: maskSecret(account.accessToken || ''),
    })),
    telegramBots: settings.telegramBots.map((bot) => ({
      ...bot,
      botToken: maskSecret(bot.botToken || ''),
      verifyToken: maskSecret(bot.verifyToken || ''),
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
    instagramAccounts: normalizeInstagramList(settings),
    whatsappAccounts: normalizeWhatsappList(settings),
    telegramBots: normalizeTelegramList(settings),
    webchatWidgets: normalizeWebchatList(settings),
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

function normalizeInstagramEntry(entry: Partial<InstagramIntegrationStatus>): InstagramIntegrationStatus {
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

function normalizeInstagramList(settings: Partial<IntegrationSettings>): InstagramIntegrationStatus[] {
  if (Array.isArray(settings.instagramAccounts)) {
    return settings.instagramAccounts.map(normalizeInstagramEntry);
  }
  return [];
}

function normalizeWhatsappEntry(entry: Partial<WhatsappIntegrationStatus>): WhatsappIntegrationStatus {
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

function normalizeWhatsappList(settings: Partial<IntegrationSettings>): WhatsappIntegrationStatus[] {
  if (Array.isArray(settings.whatsappAccounts)) {
    return settings.whatsappAccounts.map(normalizeWhatsappEntry);
  }
  return [];
}

function normalizeTelegramEntry(entry: Partial<TelegramIntegrationStatus>): TelegramIntegrationStatus {
  return {
    status: entry.status || 'cloud_required',
    enabled: entry.enabled === true,
    accountName: entry.accountName || undefined,
    accountId: entry.accountId || undefined,
    webhookCallbackUrl: normalizeBaseUrl(entry.webhookCallbackUrl || ''),
    botToken: String(entry.botToken || '').trim(),
    verifyToken: String(entry.verifyToken || '').trim(),
    cloudId: entry.cloudId || undefined,
  };
}

function normalizeTelegramList(settings: Partial<IntegrationSettings>): TelegramIntegrationStatus[] {
  if (Array.isArray(settings.telegramBots)) {
    return settings.telegramBots.map(normalizeTelegramEntry);
  }
  return [];
}

function normalizeWebchatEntry(entry: Partial<WebchatWidgetSettings>): WebchatWidgetSettings {
  return {
    status: entry.status || 'cloud_required',
    enabled: entry.enabled === true,
    widgetId: entry.widgetId || undefined,
    widgetName: String(entry.widgetName || '').trim(),
    welcomeMessage: String(entry.welcomeMessage || '').trim(),
    primaryColorHex: String(entry.primaryColorHex || '#4F46E5').trim(),
    siteLabel: String(entry.siteLabel || '').trim(),
    cloudId: entry.cloudId || undefined,
  };
}

function normalizeWebchatList(settings: Partial<IntegrationSettings>): WebchatWidgetSettings[] {
  if (Array.isArray(settings.webchatWidgets)) {
    return settings.webchatWidgets.map(normalizeWebchatEntry);
  }
  return [];
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
