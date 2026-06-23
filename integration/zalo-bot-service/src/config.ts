import { readFileSync, existsSync, mkdirSync, cpSync, readdirSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { homedir, platform } from 'os';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * projectRoot resolves to integration/zalo-bot-service/ regardless of
 * whether the caller lives in dist/ or dist/channels/.
 * The `.env` file and RUNTIME/ephemeral files (active-port.json, logs,
 * temp-sends) resolve from here.
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
  // Whether the chatbot may auto-reply to a contact that was just auto-approved
  // as a friend. Independent of friend auto-approval itself.
  autoReplyNewFriend: boolean;
  // Agent configuration
  localBindHost: string;
  localBindPort: number;
  crmCloudApiUrl: string;
  crmAgentDeviceId: string;
  crmAgentSecretPath: string;
  crmAgentMode: 'enabled' | 'disabled';
  // Local-first Live Chat
  localFirstLiveChat: boolean;
  localChatDbPath: string;
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

/**
 * dataRoot: nơi lưu DỮ LIỆU BỀN VỮNG (credentials Zalo, định danh thiết bị, DB
 * chat, media hội thoại, knowledge) ở vị trí ổn định theo từng MÁY — độc lập với
 * vị trí cài đặt — để không mất khi cập nhật / di chuyển thư mục / chuyển giữa
 * bản dev và bản đóng gói.
 *
 * Windows: %LOCALAPPDATA%\\AlphaCRM\\zalo-bot-service (Local, KHÔNG roam — định
 * danh thiết bị phải gắn với từng máy). Có thể override bằng ALPHA_CRM_DATA_DIR.
 *
 * Lưu ý: active-port.json, logs, temp-sends là file runtime/ephemeral nên vẫn
 * nằm ở projectRoot/.data và KHÔNG dùng dataRoot.
 */
function resolveDataRoot(): string {
  const override = process.env['ALPHA_CRM_DATA_DIR'];
  if (override && override.trim()) return resolve(override.trim());
  if (platform() === 'win32') {
    const base = process.env['LOCALAPPDATA'] || process.env['APPDATA'];
    if (base) return resolve(base, 'AlphaCRM', 'zalo-bot-service');
  }
  // macOS/Linux (chủ yếu dùng cho dev)
  return resolve(homedir(), '.alpha-crm', 'zalo-bot-service');
}

export const dataRoot = resolveDataRoot();

/**
 * Migration một lần: nếu dataRoot chưa tồn tại nhưng có `.data` cũ cạnh service
 * (các bản trước lưu theo vị trí cài đặt), copy dữ liệu bền vững sang dataRoot để
 * KHÔNG mất login/DB/device khi nâng cấp. Bỏ qua các mục runtime
 * (active-port.json, logs, temp-sends).
 */
function migrateLegacyDataIfNeeded(): void {
  try {
    const legacy = resolve(projectRoot, '.data');
    if (dataRoot === legacy) return; // dev trỏ thẳng .data → không cần migrate
    if (existsSync(dataRoot)) return; // đã migrate hoặc đã có dữ liệu mới
    if (!existsSync(legacy)) return; // không có gì để chuyển
    mkdirSync(dataRoot, { recursive: true });
    const skip = new Set(['active-port.json', 'logs', 'temp-sends']);
    for (const entry of readdirSync(legacy)) {
      if (skip.has(entry)) continue;
      cpSync(resolve(legacy, entry), resolve(dataRoot, entry), { recursive: true });
    }
    console.log(`[config] Migrated legacy data: ${legacy} -> ${dataRoot}`);
  } catch (err) {
    console.error('[config] Legacy data migration failed (continuing):', err);
  }
}

migrateLegacyDataIfNeeded();

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
    process.env['ZALO_PERSONAL_CREDENTIALS_PATH'] ||
    resolve(dataRoot, 'zalo-personal/credentials.json'),
  personalQrPath:
    process.env['ZALO_PERSONAL_QR_PATH'] || resolve(dataRoot, 'zalo-personal/qr.png'),
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
  autoReplyNewFriend: parseBool(process.env['ZALO_AUTO_REPLY_NEW_FRIEND'], true),
  // Agent configuration
  localBindHost: process.env['LOCAL_BIND_HOST'] || '127.0.0.1',
  localBindPort: parseInt(process.env['LOCAL_BIND_PORT'] || process.env['PORT'] || '8787', 10),
  crmCloudApiUrl: process.env['CRM_CLOUD_API_URL'] || 'https://alpha-studio-backend.fly.dev/api',
  crmAgentDeviceId: process.env['CRM_AGENT_DEVICE_ID'] || '',
  crmAgentSecretPath:
    process.env['CRM_AGENT_SECRET_PATH'] || resolve(dataRoot, 'agent/device-secret.json'),
  crmAgentMode: (process.env['CRM_AGENT_MODE'] as 'enabled' | 'disabled') || 'enabled',
  // Local-first Live Chat
  localFirstLiveChat: parseBool(process.env['LOCAL_FIRST_LIVE_CHAT'], true),
  localChatDbPath:
    process.env['LOCAL_CHAT_DB_PATH'] || resolve(dataRoot, 'live-chat/live-chat.sqlite'),
};
