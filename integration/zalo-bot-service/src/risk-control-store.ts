/**
 * Risk-control settings store.
 *
 * The Flutter "Kiểm soát rủi ro" UI owns these values, but compliance is
 * enforced server-side. This store lets the client push its settings to the
 * backend where they are persisted under dataRoot and applied to the live
 * `config` object, so enforcement (quiet hours, daily limits, automation
 * gates) actually reflects what the operator configured — instead of the
 * startup env defaults.
 */
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'fs';
import { resolve, dirname } from 'path';
import { config, dataRoot } from './config.js';

const FILE = resolve(dataRoot, 'integrations', 'risk-control.json');

// Fields the client is allowed to override at runtime.
export interface RiskControlSettings {
  maxBatchSize?: number;
  dailySendLimit?: number;
  quietHoursStart?: string;
  quietHoursEnd?: string;
  maxFailureRatePercent?: number;
  stopOnReportCount?: number;
  allowFriendAutomation?: boolean;
  allowGroupAutomation?: boolean;
  requireHumanApproval?: boolean;
  humanApprovalThreshold?: number;
  autoReplyNewFriend?: boolean;
}

const HHMM = /^\d{1,2}:\d{2}$/;

function sanitize(input: unknown): RiskControlSettings {
  const data = (input ?? {}) as Record<string, unknown>;
  const out: RiskControlSettings = {};

  const num = (key: keyof RiskControlSettings, min: number, max: number) => {
    const v = data[key];
    if (typeof v === 'number' && Number.isFinite(v)) {
      (out[key] as number) = Math.min(max, Math.max(min, Math.round(v)));
    }
  };
  const bool = (key: keyof RiskControlSettings) => {
    const v = data[key];
    if (typeof v === 'boolean') (out[key] as boolean) = v;
  };
  const time = (key: keyof RiskControlSettings) => {
    const v = data[key];
    if (typeof v === 'string' && HHMM.test(v.trim())) {
      (out[key] as string) = v.trim();
    }
  };

  num('maxBatchSize', 1, 10000);
  num('dailySendLimit', 1, 100000);
  num('maxFailureRatePercent', 1, 100);
  num('stopOnReportCount', 1, 100000);
  num('humanApprovalThreshold', 1, 100000);
  time('quietHoursStart');
  time('quietHoursEnd');
  bool('allowFriendAutomation');
  bool('allowGroupAutomation');
  bool('requireHumanApproval');
  bool('autoReplyNewFriend');

  return out;
}

export function readRiskControlSettings(): RiskControlSettings {
  try {
    if (!existsSync(FILE)) return {};
    return sanitize(JSON.parse(readFileSync(FILE, 'utf-8')));
  } catch {
    return {};
  }
}

/** Overlay persisted/given settings onto the live config object. */
export function applyRiskControlToConfig(settings: RiskControlSettings): void {
  const s = sanitize(settings);
  for (const [key, value] of Object.entries(s)) {
    if (value === undefined) continue;
    (config as unknown as Record<string, unknown>)[key] = value;
  }
}

export function writeRiskControlSettings(
  partial: unknown,
): RiskControlSettings {
  const merged = { ...readRiskControlSettings(), ...sanitize(partial) };
  mkdirSync(dirname(FILE), { recursive: true });
  writeFileSync(FILE, JSON.stringify(merged, null, 2), 'utf-8');
  applyRiskControlToConfig(merged);
  return merged;
}

// Apply persisted overrides over env defaults at startup (module import).
applyRiskControlToConfig(readRiskControlSettings());
