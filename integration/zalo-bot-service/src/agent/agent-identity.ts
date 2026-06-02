import os from 'os';
import crypto from 'crypto';
import fs from 'fs';
import { dirname, resolve } from 'path';
import { config, projectRoot } from '../config.js';

interface AgentCredentials {
  deviceId: string;
  agentSecret: string;
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
  if (!fs.existsSync(secretPath)) {
    return null;
  }
  try {
    const raw = fs.readFileSync(secretPath, 'utf-8');
    const parsed = JSON.parse(raw);
    if (parsed.deviceId && parsed.agentSecret) {
      return parsed as AgentCredentials;
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
export function saveAgentCredentials(deviceId: string, agentSecret: string): boolean {
  const secretPath = resolve(projectRoot, config.crmAgentSecretPath);
  try {
    const parentDir = dirname(secretPath);
    if (!fs.existsSync(parentDir)) {
      fs.mkdirSync(parentDir, { recursive: true });
    }
    const data = { deviceId, agentSecret };
    fs.writeFileSync(secretPath, JSON.stringify(data, null, 2), 'utf-8');
    console.log(`[agent-identity] Agent credentials saved successfully to ${secretPath}`);
    return true;
  } catch (err) {
    console.error('[agent-identity] Failed to save agent credentials:', err);
    return false;
  }
}

/**
 * Resolves the path to the CRM token JSON file created by the Flutter desktop app.
 * Supports Windows, macOS, and Linux.
 */
export function getCrmTokenPath(): string | null {
  const home = os.homedir();
  let tokenPath = '';
  
  if (process.platform === 'win32') {
    const appData = process.env.APPDATA || resolve(home, 'AppData', 'Roaming');
    tokenPath = resolve(appData, 'com.alphastudio.crm', 'alpha_crm', 'crm_token.json');
  } else if (process.platform === 'darwin') {
    tokenPath = resolve(home, 'Library/Application Support', 'com.alphastudio.crm', 'alpha_crm', 'crm_token.json');
  } else {
    tokenPath = resolve(home, '.config', 'com.alphastudio.crm', 'alpha_crm', 'crm_token.json');
  }

  if (fs.existsSync(tokenPath)) {
    return tokenPath;
  }
  return null;
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

