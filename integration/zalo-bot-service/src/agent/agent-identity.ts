import os from 'os';
import crypto from 'crypto';
import fs from 'fs';
import { dirname, resolve } from 'path';
import { config, projectRoot } from '../config.js';

export interface AgentCredentials {
  userId: string;
  deviceId: string;
  agentSecret: string;
}

interface CrmTokenFile {
  token: string;
  userId?: string;
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

/**
 * Generates a stable machine fingerprint SHA-256 hash from Windows-safe platform properties.
 * Does not send raw hardware IDs to the cloud.
 */
export function getMachineFingerprint(): string {
  const parts = [
    os.hostname(),
    os.platform(),
    os.arch(),
    os.release(),
    os.homedir(),
    process.env.COMPUTERNAME || '',
    process.env.PROCESSOR_IDENTIFIER || ''
  ];
  const raw = parts.filter(Boolean).join('|');
  return crypto.createHash('sha256').update(raw).digest('hex');
}

/**
 * Loads agent credentials from local storage.
 * Resolves path from projectRoot.
 */
export function getAgentCredentials(): AgentCredentials | null {
  const secretPath = resolve(projectRoot, config.crmAgentSecretPath);
  return readAgentCredentialsFile(secretPath);
}

export function readAgentCredentialsFile(secretPath: string): AgentCredentials | null {
  try {
    if (!fs.existsSync(secretPath)) {
      return null;
    }
    const raw = fs.readFileSync(secretPath, 'utf-8');
    const parsed: unknown = JSON.parse(raw);
    if (
      parsed
      && typeof parsed === 'object'
      && isNonEmptyString((parsed as AgentCredentials).userId)
      && isNonEmptyString((parsed as AgentCredentials).deviceId)
      && isNonEmptyString((parsed as AgentCredentials).agentSecret)
    ) {
      const credentials = parsed as AgentCredentials;
      return {
        userId: credentials.userId,
        deviceId: credentials.deviceId,
        agentSecret: credentials.agentSecret,
      };
    }
  } catch (err) {
    console.error('[agent-identity] Failed to load agent credentials:', err);
  }
  return null;
}

/**
 * Saves agent credentials to local storage.
 * Creates parent directory if it does not exist.
 */
export function saveAgentCredentials(
  userId: string,
  deviceId: string,
  agentSecret: string,
): boolean {
  const secretPath = resolve(projectRoot, config.crmAgentSecretPath);
  try {
    writeAgentCredentialsFile(secretPath, { userId, deviceId, agentSecret });
    console.log(`[agent-identity] Agent credentials saved successfully to ${secretPath}`);
    return true;
  } catch (err) {
    console.error('[agent-identity] Failed to save agent credentials:', err);
    return false;
  }
}

export function writeAgentCredentialsFile(
  secretPath: string,
  credentials: AgentCredentials,
): void {
  fs.mkdirSync(dirname(secretPath), { recursive: true });
  const temporaryPath = `${secretPath}.tmp`;
  fs.writeFileSync(temporaryPath, JSON.stringify(credentials, null, 2), 'utf-8');
  fs.renameSync(temporaryPath, secretPath);
}

export function deleteFileIfPresent(filePath: string): void {
  fs.rmSync(filePath, { force: true });
}

/**
 * Resolves the path to the CRM token JSON file created by the Flutter desktop app.
 * Supports Windows, macOS, and Linux.
 */
export function resolveCrmTokenPath(): string {
  const home = os.homedir();

  if (process.platform === 'win32') {
    const appData = process.env.APPDATA || resolve(home, 'AppData', 'Roaming');
    return resolve(appData, 'com.alphastudio.crm', 'alpha_crm', 'crm_token.json');
  }

  if (process.platform === 'darwin') {
    return resolve(
      home,
      'Library/Application Support',
      'com.alphastudio.crm',
      'alpha_crm',
      'crm_token.json',
    );
  }

  return resolve(home, '.config', 'com.alphastudio.crm', 'alpha_crm', 'crm_token.json');
}

export function getCrmTokenPath(): string | null {
  const tokenPath = resolveCrmTokenPath();
  return fs.existsSync(tokenPath) ? tokenPath : null;
}

/**
 * Reads and returns the active JWT token from the local Flutter desktop app.
 */
export function getCrmToken(): string | null {
  const tokenPath = getCrmTokenPath();
  if (!tokenPath) return null;
  try {
    const raw = fs.readFileSync(tokenPath, 'utf8');
    const parsed = JSON.parse(raw);
    return parsed.token || null;
  } catch (err) {
    console.error('[agent-identity] Failed to load crm_token.json:', err);
    return null;
  }
}

export function saveCrmToken(token: string, userId: string): void {
  const tokenPath = resolveCrmTokenPath();
  const temporaryPath = `${tokenPath}.tmp`;
  const data: CrmTokenFile = { token, userId };
  fs.mkdirSync(dirname(tokenPath), { recursive: true });
  fs.writeFileSync(temporaryPath, JSON.stringify(data, null, 2), 'utf8');
  fs.renameSync(temporaryPath, tokenPath);
}

export function deleteCrmToken(): void {
  deleteFileIfPresent(resolveCrmTokenPath());
}

export function deleteAgentCredentials(): void {
  deleteFileIfPresent(resolve(projectRoot, config.crmAgentSecretPath));
}

