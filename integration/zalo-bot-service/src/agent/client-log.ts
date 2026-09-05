import fs from 'fs';
import { resolve } from 'path';
import { projectRoot } from '../config.js';

const defaultLogDirectory = resolve(projectRoot, '.data/logs');
const LOG_FILE = 'client_errors.ndjson';
const LEGACY_LOG_FILE = 'client_errors.json';

/** Số bản ghi giữ lại sau mỗi lần cắt bớt. */
const MAX_LOGS = 500;
/** Vượt ngưỡng này thì cắt bớt. Kiểm tra bằng statSync — không đọc/parse file. */
const TRIM_AT_BYTES = 2 * 1024 * 1024;

export interface ClientLog {
  id: string;
  message: string;
  error?: string;
  stackTrace?: string;
  platform?: string;
  timestamp: string;
}

function logFilePath(dir: string): string {
  return resolve(dir, LOG_FILE);
}

function ensureLogDirectory(dir: string): void {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function parseLines(content: string): ClientLog[] {
  const logs: ClientLog[] = [];
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    try {
      logs.push(JSON.parse(trimmed) as ClientLog);
    } catch {
      // Dòng ghi dở do bị kill giữa chừng — bỏ qua, phần còn lại vẫn đọc được.
      // Đây chính là lý do dùng NDJSON thay vì một mảng JSON duy nhất.
    }
  }
  return logs;
}

/**
 * Chuyển file mảng JSON của bản cũ sang NDJSON, một lần duy nhất.
 */
function migrateLegacyIfNeeded(dir: string): void {
  const legacy = resolve(dir, LEGACY_LOG_FILE);
  if (!fs.existsSync(legacy)) return;
  try {
    const parsed = JSON.parse(fs.readFileSync(legacy, 'utf-8'));
    if (Array.isArray(parsed) && parsed.length > 0) {
      // File cũ là mới-nhất-trước; NDJSON ghi theo thứ tự thời gian nên đảo lại.
      const lines = parsed
        .slice(0, MAX_LOGS)
        .reverse()
        .map((log) => JSON.stringify(log))
        .join('\n');
      fs.appendFileSync(logFilePath(dir), `${lines}\n`, 'utf-8');
    }
    fs.unlinkSync(legacy);
  } catch (err) {
    console.error('[client-log] Legacy client_errors.json migration failed:', err);
  }
}

/**
 * Giữ lại các bản ghi mới nhất, chặn theo CẢ số lượng lẫn dung lượng.
 *
 * Chặn theo dung lượng là bắt buộc: 500 bản ghi kèm stack trace vẫn có thể vượt
 * TRIM_AT_BYTES, và khi đó mọi lần ghi tiếp theo lại kích hoạt trim — đúng kiểu
 * đọc-parse-ghi-lại mỗi bản ghi mà NDJSON sinh ra để loại bỏ.
 */
function trim(dir: string): void {
  const path = logFilePath(dir);
  try {
    const logs = parseLines(fs.readFileSync(path, 'utf-8')).slice(-MAX_LOGS);
    const budget = TRIM_AT_BYTES / 2;
    const lines: string[] = [];
    let bytes = 0;
    for (let i = logs.length - 1; i >= 0; i--) {
      const line = JSON.stringify(logs[i]);
      bytes += line.length + 1;
      if (bytes > budget && lines.length > 0) break;
      lines.unshift(line);
    }
    fs.writeFileSync(path, lines.join('\n') + '\n', 'utf-8');
  } catch (err) {
    console.error('[client-log] Failed to trim client log:', err);
  }
}

/**
 * Nối thêm một bản ghi. Chỉ append + một statSync — KHÔNG đọc/parse/ghi lại cả
 * file như bản cũ, vì hàm này nằm trên event loop và bị gọi mỗi lần app báo lỗi
 * (một trận lỗi dồn dập từng đủ để làm nghẽn /health).
 */
export function saveClientLog(
  logData: Partial<ClientLog>,
  dir: string = defaultLogDirectory,
): void {
  ensureLogDirectory(dir);
  migrateLegacyIfNeeded(dir);

  const log: ClientLog = {
    id: `log_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
    message: logData.message || 'Unknown Error',
    error: logData.error,
    stackTrace: logData.stackTrace,
    platform: logData.platform || 'Unknown',
    timestamp: logData.timestamp || new Date().toISOString(),
  };

  const path = logFilePath(dir);
  fs.appendFileSync(path, `${JSON.stringify(log)}\n`, 'utf-8');

  try {
    if (fs.statSync(path).size > TRIM_AT_BYTES) {
      trim(dir);
    }
  } catch {
    /* stat lỗi thì bỏ qua — lần ghi sau sẽ thử lại */
  }
}

/** Trả về mới nhất trước, giống hợp đồng của bản cũ. */
export function getClientLogs(dir: string = defaultLogDirectory): ClientLog[] {
  migrateLegacyIfNeeded(dir);
  const path = logFilePath(dir);
  if (!fs.existsSync(path)) return [];
  try {
    return parseLines(fs.readFileSync(path, 'utf-8')).reverse();
  } catch {
    return [];
  }
}

export function deleteClientLogs(ids: string[], dir: string = defaultLogDirectory): void {
  migrateLegacyIfNeeded(dir);
  const path = logFilePath(dir);
  if (!fs.existsSync(path)) return;
  try {
    const kept = parseLines(fs.readFileSync(path, 'utf-8')).filter(
      (log) => !ids.includes(log.id),
    );
    fs.writeFileSync(
      path,
      kept.length > 0 ? kept.map((log) => JSON.stringify(log)).join('\n') + '\n' : '',
      'utf-8',
    );
  } catch (err) {
    console.error('Failed to delete client logs:', err);
  }
}
