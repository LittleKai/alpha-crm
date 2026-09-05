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

  // 3. Redact Zalo cookies or credentials
  redacted = redacted.replace(/(cookie|cookieValue|secret|agentSecret|token|zaloOaSecret|zaloOaAccessToken|zaloOaRefreshToken)":"?[a-zA-Z0-9-_=+/.]+"?/gi, '$1":"[REDACTED]"');

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

/**
 * Giữ fd mở thay vì `appendFileSync` (mở + ghi + đóng mỗi dòng). Tee bám vào
 * đường in nóng của backend nên số syscall mỗi dòng là chi phí có thật trên
 * event loop — nơi `/health` và mọi truy vấn SQLite đồng bộ cùng chen chân.
 * Vẫn ghi ĐỒNG BỘ: mục đích của file này là còn dấu vết khi tiến trình chết,
 * mà đệm bất đồng bộ thì mất đúng những dòng cuối cùng đáng giá nhất.
 */
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

/**
 * Bỏ ghi file sau ngần này lần lỗi liên tiếp. Nếu người dùng giải nén bản build
 * vào thư mục chỉ đọc (Program Files), không có cái này thì MỖI dòng console
 * sinh thêm một dòng cảnh báo — biến một sự cố quyền ghi thành ngập nhật ký.
 */
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
    closeLogFd(); // fd hỏng (file bị xoá/di chuyển) → lần sau mở lại
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

  // In qua console GỐC để tee không ghi lặp dòng này (writeLog tự ghi file).
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

/**
 * Vá console.log/warn/error để mọi dòng cũng rơi vào agent.log.
 *
 * Backend có ~270 lời gọi console.* và chỉ 4 lời gọi logInfo/logError, nên
 * trước đây gần như toàn bộ nhật ký chỉ tồn tại trong pipe stdout — phụ thuộc
 * việc app Flutter còn sống để hứng. Backend chết trước khi Flutter kịp đọc là
 * không còn dấu vết nào để chẩn đoán.
 */
export function installConsoleFileTee(): void {
  if (teeInstalled) return;
  teeInstalled = true;

  console.log = (...args: unknown[]) => {
    originalConsole.log(...args);
    appendToLogFile('INFO', formatLogArgs(args));
  };
  console.warn = (...args: unknown[]) => {
    originalConsole.warn(...args);
    appendToLogFile('WARN', formatLogArgs(args));
  };
  console.error = (...args: unknown[]) => {
    originalConsole.error(...args);
    appendToLogFile('ERROR', formatLogArgs(args));
  };

  appendToLogFile('INFO', `=== console tee installed (pid ${process.pid}) ===`);
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
