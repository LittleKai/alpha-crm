import fs from 'fs';
import { resolve } from 'path';
import { projectRoot } from '../config.js';

const logDirectory = resolve(projectRoot, '.data/logs');
const logFilePath = resolve(logDirectory, 'agent.log');
const MAX_LOG_BYTES = 5 * 1024 * 1024;

/**
 * Tham chiếu console GỐC, chụp trước khi [installConsoleFileTee] vá console.
 * Mọi lệnh in bên trong module này phải đi qua đây, nếu không sẽ đệ quy vô hạn.
 */
const originalConsole = {
  log: console.log.bind(console),
  warn: console.warn.bind(console),
  error: console.error.bind(console),
};

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

  // 3. Redact Zalo cookies, API keys, or channel tokens in JSON or key=value form
  redacted = redacted.replace(
    /(cookie|cookieValue|zpw_sek|secret|agentSecret|token|accessToken|refreshToken|botToken|apiKey|appSecret|verifyToken|zaloOaSecret|zaloOaAccessToken|zaloOaRefreshToken)(["']?\s*[:=]\s*["']?)[a-zA-Z0-9-_=+/.]+(["']?)/gi,
    '$1$2[REDACTED]$3',
  );

  return redacted;
}

/** Ghép các tham số kiểu console thành một chuỗi một dòng. */
export function formatLogArgs(args: unknown[]): string {
  return args
    .map((arg) => {
      if (typeof arg === 'string') return arg;
      if (arg instanceof Error) return arg.stack || `${arg.name}: ${arg.message}`;
      try {
        return JSON.stringify(arg);
      } catch {
        return String(arg);
      }
    })
    .join(' ')
    .replace(/\r?\n/g, ' | ');
}

let logFd: number | null = null;
let linesSinceRotateCheck = 0;
const ROTATE_CHECK_EVERY = 200;

function openLogFd(): number {
  if (logFd === null) {
    ensureLogDirectory();
    logFd = fs.openSync(logFilePath, 'a');
  }
  return logFd;
}

function closeLogFd(): void {
  if (logFd === null) return;
  try {
    fs.closeSync(logFd);
  } catch {
    /* ignore */
  }
  logFd = null;
}

/** Xoay file khi vượt MAX_LOG_BYTES: agent.log -> agent.log.old (giữ 1 đời). */
function rotateIfNeeded(): void {
  if (++linesSinceRotateCheck < ROTATE_CHECK_EVERY) return;
  linesSinceRotateCheck = 0;
  if (!fs.existsSync(logFilePath)) return;
  if (fs.statSync(logFilePath).size <= MAX_LOG_BYTES) return;
  // Windows không đổi tên được file đang có handle mở → đóng fd TRƯỚC.
  closeLogFd();
  const oldLogPath = resolve(logDirectory, 'agent.log.old');
  if (fs.existsSync(oldLogPath)) {
    fs.unlinkSync(oldLogPath);
  }
  fs.renameSync(logFilePath, oldLogPath);
}

const MAX_CONSECUTIVE_WRITE_FAILURES = 5;
let consecutiveWriteFailures = 0;

/** Ghi một dòng đã che secret vào agent.log. Không bao giờ in ra console. */
function appendToLogFile(level: string, message: string): void {
  if (consecutiveWriteFailures >= MAX_CONSECUTIVE_WRITE_FAILURES) return;
  try {
    rotateIfNeeded();
    const line = `[${new Date().toISOString()}] [${level}] ${redactSecrets(message)}\n`;
    fs.writeSync(openLogFd(), line);
    consecutiveWriteFailures = 0;
  } catch (err: any) {
    closeLogFd();
    consecutiveWriteFailures++;
    originalConsole.warn(
      `[logger] Failed to write to log file:`,
      err.message,
      consecutiveWriteFailures >= MAX_CONSECUTIVE_WRITE_FAILURES
        ? '(giving up on file logging for this run)'
        : '',
    );
  }
}

/**
 * Writes a formatted message to the console and logs it to a local file
 */
function writeLog(level: 'INFO' | 'WARN' | 'ERROR', message: string, ...optionalParams: any[]): void {
  const formattedMessage = formatLogArgs([message, ...optionalParams]);
  const safeMessage = redactSecrets(formattedMessage);

  if (level === 'ERROR') {
    originalConsole.error(`[${level}] ${safeMessage}`);
  } else if (level === 'WARN') {
    originalConsole.warn(`[${level}] ${safeMessage}`);
  } else {
    originalConsole.log(`[${level}] ${safeMessage}`);
  }

  appendToLogFile(level, formattedMessage);
}

let teeInstalled = false;

export function installConsoleFileTee(): void {
  if (teeInstalled) return;
  teeInstalled = true;

  console.log = (...args: unknown[]) => {
    const formatted = formatLogArgs(args);
    originalConsole.log(redactSecrets(formatted));
    appendToLogFile('INFO', formatted);
  };
  console.warn = (...args: unknown[]) => {
    const formatted = formatLogArgs(args);
    originalConsole.warn(redactSecrets(formatted));
    appendToLogFile('WARN', formatted);
  };
  console.error = (...args: unknown[]) => {
    const formatted = formatLogArgs(args);
    originalConsole.error(redactSecrets(formatted));
    appendToLogFile('ERROR', formatted);
  };

  appendToLogFile('INFO', `=== console tee installed (pid ${process.pid}) ===`);
}

export function logInfo(message: string, ...optionalParams: any[]): void {
  writeLog('INFO', message, ...optionalParams);
}

export function logError(message: string, ...optionalParams: any[]): void {
  writeLog('ERROR', message, ...optionalParams);
}
