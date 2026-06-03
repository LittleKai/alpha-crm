import { readFileSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * projectRoot resolves to integration/zalo-bot-service/ regardless of
 * whether the caller lives in dist/ or dist/channels/.
 * All relative paths (credentials, QR, .env) resolve from here.
 */
export const projectRoot = resolve(__dirname, '..');

export type ZaloChannelMode = 'personal_zca' | 'official_oa' | 'mock';

interface Config {
  port: number;
  nodeEnv: string;
  // Channel selection
  channelMode: ZaloChannelMode;
  // Personal Zalo (zca-js) config
  personalCredentialsPath: string;
  personalQrPath: string;
  personalAccountLabel: string;
  personalSelfListen: boolean;
  // Official OA config (optional)
  zaloOaId: string;
  zaloOaSecret: string;
  zaloOaAccessToken: string;
  zaloOaRefreshToken: string;
  zaloBotToken: string;
  zaloBotApiBaseUrl: string;
  zaloBotApiTimeoutMs: number;
  // Webhook
  zaloWebhookVerifyToken: string;
  zaloWebhookSecret: string;
  // Safety — server-side enforcement (NOT from client)
  allowedTestUids: string[];
  maxBatchSize: number;
  dailySendLimit: number;
  quietHoursStart: string;
  quietHoursEnd: string;
  maxFailureRatePercent: number;
  stopOnReportCount: number;
  allowPersonalAccountAutomation: boolean;
  allowFriendAutomation: boolean;
  allowGroupAutomation: boolean;
  requireHumanApproval: boolean;
  humanApprovalThreshold: number;
  // Agent configuration
  localBindHost: string;
  localBindPort: number;
  crmCloudApiUrl: string;
  crmAgentDeviceId: string;
  crmAgentSecretPath: string;
  crmAgentMode: 'enabled' | 'disabled';
}

function loadEnv(): void {
  const envPath = resolve(projectRoot, '.env');
  if (!existsSync(envPath)) return;

  const content = readFileSync(envPath, 'utf-8');
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const value = trimmed.slice(eqIdx + 1).trim();
    if (!process.env[key]) {
      process.env[key] = value;
    }
  }
}

loadEnv();

function parseCsv(value: string | undefined): string[] {
  if (!value) return [];
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function parseBool(value: string | undefined, fallback: boolean): boolean {
  if (value === undefined || value === '') return fallback;
  return value === 'true' || value === '1';
}

export const config: Config = {
  port: parseInt(process.env['PORT'] || '8787', 10),
  nodeEnv: process.env['NODE_ENV'] || 'development',
  channelMode: (process.env['ZALO_CHANNEL_MODE'] as ZaloChannelMode) || 'personal_zca',
  personalCredentialsPath:
    process.env['ZALO_PERSONAL_CREDENTIALS_PATH'] || '.data/zalo-personal/credentials.json',
  personalQrPath:
    process.env['ZALO_PERSONAL_QR_PATH'] || '.data/zalo-personal/qr.png',
  personalAccountLabel:
    process.env['ZALO_PERSONAL_ACCOUNT_LABEL'] || 'Personal Zalo 1',
  personalSelfListen:
    process.env['ZALO_PERSONAL_SELF_LISTEN'] === 'true',
  zaloOaId: process.env['ZALO_OA_ID'] || '',
  zaloOaSecret: process.env['ZALO_OA_SECRET'] || '',
  zaloOaAccessToken: process.env['ZALO_OA_ACCESS_TOKEN'] || '',
  zaloOaRefreshToken: process.env['ZALO_OA_REFRESH_TOKEN'] || '',
  zaloBotToken: process.env['ZALO_BOT_TOKEN'] || '',
  zaloBotApiBaseUrl: process.env['ZALO_BOT_API_BASE_URL'] || 'https://bot-api.zapps.me',
  zaloBotApiTimeoutMs: parseInt(process.env['ZALO_BOT_API_TIMEOUT_MS'] || '12000', 10),
  zaloWebhookVerifyToken:
    process.env['ZALO_WEBHOOK_VERIFY_TOKEN'] || 'alpha-crm-verify',
  zaloWebhookSecret: process.env['ZALO_WEBHOOK_SECRET'] || '',
  allowedTestUids: parseCsv(process.env['ZALO_ALLOWED_TEST_UIDS']),
  maxBatchSize: parseInt(process.env['ZALO_MAX_BATCH_SIZE'] || '20', 10),
  dailySendLimit: parseInt(process.env['ZALO_DAILY_SEND_LIMIT'] || '100', 10),
  quietHoursStart: process.env['ZALO_QUIET_HOURS_START'] || '21:00',
  quietHoursEnd: process.env['ZALO_QUIET_HOURS_END'] || '08:00',
  maxFailureRatePercent: parseInt(process.env['ZALO_MAX_FAILURE_RATE_PERCENT'] || '10', 10),
  stopOnReportCount: parseInt(process.env['ZALO_STOP_ON_REPORT_COUNT'] || '1', 10),
  allowPersonalAccountAutomation: parseBool(process.env['ZALO_ALLOW_PERSONAL_AUTOMATION'], true),
  allowFriendAutomation: parseBool(process.env['ZALO_ALLOW_FRIEND_AUTOMATION'], false),
  allowGroupAutomation: parseBool(process.env['ZALO_ALLOW_GROUP_AUTOMATION'], false),
  requireHumanApproval: parseBool(process.env['ZALO_REQUIRE_HUMAN_APPROVAL'], true),
  humanApprovalThreshold: parseInt(process.env['ZALO_HUMAN_APPROVAL_THRESHOLD'] || '20', 10),
  // Agent configuration
  localBindHost: process.env['LOCAL_BIND_HOST'] || '127.0.0.1',
  localBindPort: parseInt(process.env['LOCAL_BIND_PORT'] || process.env['PORT'] || '8787', 10),
  crmCloudApiUrl: process.env['CRM_CLOUD_API_URL'] || 'https://alpha-studio-backend.fly.dev/api',
  crmAgentDeviceId: process.env['CRM_AGENT_DEVICE_ID'] || '',
  crmAgentSecretPath: process.env['CRM_AGENT_SECRET_PATH'] || '.data/agent/device-secret.json',
  crmAgentMode: (process.env['CRM_AGENT_MODE'] as 'enabled' | 'disabled') || 'enabled',
};
