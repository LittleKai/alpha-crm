import fs from 'fs';
import { resolve, dirname } from 'path';
import { config, projectRoot } from '../config.js';

const logDirectory = resolve(projectRoot, '.data/logs');
const logFilePath = resolve(logDirectory, 'agent.log');

/**
 * Ensures the log directory exists
 */
function ensureLogDirectory(): void {
  if (!fs.existsSync(logDirectory)) {
    fs.mkdirSync(logDirectory, { recursive: true });
  }
}

/**
 * Redacts sensitive tokens, secrets, cookies, or credentials from a log string
 */
export function redactSecrets(content: string): string {
  if (!content) return '';

  let redacted = content;

  // 1. Redact JWT tokens (Bearer and raw)
  redacted = redacted.replace(/(ey[a-zA-Z0-9-_=]+\.[a-zA-Z0-9-_=]+\.?[a-zA-Z0-9-_.+/=]*)/g, '[REDACTED_JWT]');

  // 2. Redact Agent secret hashes or passwords (hex of length 64)
  redacted = redacted.replace(/\b([a-fA-F0-9]{64})\b/g, '[REDACTED_SECRET_HASH]');

  // 3. Redact Zalo cookies or credentials
  redacted = redacted.replace(/(cookie|cookieValue|secret|agentSecret|token|zaloOaSecret|zaloOaAccessToken|zaloOaRefreshToken)":"?[a-zA-Z0-9-_=+/.]+"?/gi, '$1":"[REDACTED]"');

  return redacted;
}

/**
 * Writes a formatted message to the console and logs it to a local file
 */
function writeLog(level: 'INFO' | 'WARN' | 'ERROR', message: string, ...optionalParams: any[]): void {
  const timestamp = new Date().toISOString();
  
  // Format the full message
  let formattedMessage = message;
  if (optionalParams.length > 0) {
    formattedMessage += ' ' + optionalParams.map(p => typeof p === 'object' ? JSON.stringify(p) : String(p)).join(' ');
  }

  // Redact secrets
  const safeMessage = redactSecrets(formattedMessage);
  const logLine = `[${timestamp}] [${level}] ${safeMessage}\n`;

  // Output to appropriate console stream
  if (level === 'ERROR') {
    console.error(`[${level}] ${safeMessage}`);
  } else if (level === 'WARN') {
    console.warn(`[${level}] ${safeMessage}`);
  } else {
    console.log(`[${level}] ${safeMessage}`);
  }

  // Write to log file
  try {
    ensureLogDirectory();
    
    // Simple file size check for rotation (e.g. limit to 5MB)
    if (fs.existsSync(logFilePath)) {
      const stats = fs.statSync(logFilePath);
      if (stats.size > 5 * 1024 * 1024) {
        // Rotate: rename current to agent.log.old
        const oldLogPath = resolve(logDirectory, 'agent.log.old');
        if (fs.existsSync(oldLogPath)) {
          fs.unlinkSync(oldLogPath);
        }
        fs.renameSync(logFilePath, oldLogPath);
      }
    }

    fs.appendFileSync(logFilePath, logLine, 'utf-8');
  } catch (err: any) {
    console.warn(`[logger] Failed to write to log file:`, err.message);
  }
}

export function logInfo(message: string, ...optionalParams: any[]): void {
  writeLog('INFO', message, ...optionalParams);
}

export function logWarn(message: string, ...optionalParams: any[]): void {
  writeLog('WARN', message, ...optionalParams);
}

export function logError(message: string, ...optionalParams: any[]): void {
  writeLog('ERROR', message, ...optionalParams);
}
