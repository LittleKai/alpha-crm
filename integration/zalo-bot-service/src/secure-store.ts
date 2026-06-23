/**
 * secure-store — encryption-at-rest for sensitive local files (Zalo credential
 * JSON, account-settings.json with proxy credentials).
 *
 * Design (per product decision "OS-native"):
 *  - A single random AES-256 key is generated once and persisted to
 *    `<dataRoot>/.secure-key`.
 *  - On Windows the key blob is sealed with DPAPI (CurrentUser scope) via a
 *    one-shot PowerShell call, so the key on disk is useless without the
 *    logged-in Windows user. No app-managed plaintext key is left on disk.
 *  - On non-Windows (dev only) the key is stored raw with 0600 permissions.
 *  - Files are AES-256-GCM encrypted with a small magic header so reads can
 *    transparently fall back to plaintext for installs that predate encryption
 *    (no forced re-login / no migration step).
 *  - If the key cannot be obtained (DPAPI broken, PowerShell missing), writes
 *    fall back to plaintext — encryption is best-effort and must never lock the
 *    operator out of their Zalo login.
 *
 * NOTE: this only wraps file bytes. It does NOT re-serialize the Zalo cookie
 * jar — the credential file is still produced exactly once at QR login and the
 * decrypted plaintext is byte-identical, preserving the immutability policy
 * that protects `zpw_sek`.
 */
import { existsSync, readFileSync, writeFileSync, mkdirSync, chmodSync } from 'fs';
import { resolve, dirname } from 'path';
import { platform } from 'os';
import { execFileSync } from 'child_process';
import { randomBytes, createCipheriv, createDecipheriv } from 'crypto';
import { dataRoot } from './config.js';

const MAGIC = Buffer.from('ACENC1'); // 6-byte tag marking an encrypted payload
const IV_LEN = 12;
const TAG_LEN = 16;
const keyFilePath = resolve(dataRoot, '.secure-key');

// undefined = not resolved yet, null = unavailable (use plaintext), Buffer = key
let cachedKey: Buffer | null | undefined;

function runPowerShell(script: string, inputB64: string): string {
  return execFileSync(
    'powershell',
    ['-NoProfile', '-NonInteractive', '-Command', script],
    { env: { ...process.env, ACX: inputB64 }, encoding: 'utf-8' },
  ).trim();
}

function dpapiProtect(raw: Buffer): string {
  const script =
    "Add-Type -AssemblyName System.Security; " +
    "$b=[Convert]::FromBase64String($env:ACX); " +
    "$p=[System.Security.Cryptography.ProtectedData]::Protect($b,$null,[System.Security.Cryptography.DataProtectionScope]::CurrentUser); " +
    "[Convert]::ToBase64String($p)";
  return runPowerShell(script, raw.toString('base64'));
}

function dpapiUnprotect(protectedB64: string): Buffer {
  const script =
    "Add-Type -AssemblyName System.Security; " +
    "$b=[Convert]::FromBase64String($env:ACX); " +
    "$p=[System.Security.Cryptography.ProtectedData]::Unprotect($b,$null,[System.Security.Cryptography.DataProtectionScope]::CurrentUser); " +
    "[Convert]::ToBase64String($p)";
  return Buffer.from(runPowerShell(script, protectedB64), 'base64');
}

function loadOrCreateKey(): Buffer | null {
  if (cachedKey !== undefined) return cachedKey;
  try {
    const isWin = platform() === 'win32';
    if (existsSync(keyFilePath)) {
      const stored = readFileSync(keyFilePath, 'utf-8').trim();
      cachedKey = isWin ? dpapiUnprotect(stored) : Buffer.from(stored, 'base64');
    } else {
      const key = randomBytes(32);
      mkdirSync(dirname(keyFilePath), { recursive: true });
      writeFileSync(keyFilePath, isWin ? dpapiProtect(key) : key.toString('base64'), 'utf-8');
      if (!isWin) {
        try { chmodSync(keyFilePath, 0o600); } catch { /* best-effort */ }
      }
      cachedKey = key;
    }
    if (cachedKey.length !== 32) throw new Error('secure key has wrong length');
  } catch (err) {
    console.error('[secure-store] Encryption key unavailable, falling back to plaintext:', err);
    cachedKey = null;
  }
  return cachedKey;
}

function isEncrypted(buf: Buffer): boolean {
  return buf.length >= MAGIC.length && buf.subarray(0, MAGIC.length).equals(MAGIC);
}

/** Read a possibly-encrypted file. Returns null if missing or undecryptable. */
export function readSecure(filePath: string): string | null {
  if (!existsSync(filePath)) return null;
  const buf = readFileSync(filePath);
  if (!isEncrypted(buf)) return buf.toString('utf-8'); // plaintext (legacy)
  const key = loadOrCreateKey();
  if (!key) {
    console.error(`[secure-store] Cannot decrypt ${filePath}: no key.`);
    return null;
  }
  try {
    const iv = buf.subarray(MAGIC.length, MAGIC.length + IV_LEN);
    const tag = buf.subarray(MAGIC.length + IV_LEN, MAGIC.length + IV_LEN + TAG_LEN);
    const ct = buf.subarray(MAGIC.length + IV_LEN + TAG_LEN);
    const decipher = createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(ct), decipher.final()]).toString('utf-8');
  } catch (err) {
    console.error(`[secure-store] Failed to decrypt ${filePath}:`, err);
    return null;
  }
}

/** Write a file encrypted-at-rest, or plaintext if the key is unavailable. */
export function writeSecure(filePath: string, data: string): void {
  mkdirSync(dirname(filePath), { recursive: true });
  const key = loadOrCreateKey();
  if (!key) {
    writeFileSync(filePath, data, 'utf-8');
    return;
  }
  const iv = randomBytes(IV_LEN);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const ct = Buffer.concat([cipher.update(Buffer.from(data, 'utf-8')), cipher.final()]);
  writeFileSync(filePath, Buffer.concat([MAGIC, iv, cipher.getAuthTag(), ct]));
}
