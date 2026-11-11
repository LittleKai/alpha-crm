// Adapted from https://github.com/luonghaianh1208/2anh-zalo-bot@9ab55105c83487588e66b55f0ef66894224250a7 (MIT License)

import fs from 'fs';
import { resolve } from 'path';
import { dataRoot } from '../config.js';

/**
 * Tiến độ chiến dịch đang chạy, ghi xuống đĩa.
 *
 * Trước đây trạng thái chiến dịch chỉ nằm trong RAM: backend restart giữa một
 * chiến dịch 500 người ở người thứ 213 thì tiến độ mất sạch VÀ cloud không bao
 * giờ nhận được báo cáo kết quả — lệnh treo ở trạng thái "đang chạy" vĩnh viễn.
 *
 * Bản ghi ở đây KHÔNG dùng để chạy tiếp. Cố gửi tiếp sau khi restart là rủi ro
 * gửi trùng cho những người đã nhận; mục đích của nó là báo cáo trung thực
 * "đã gián đoạn ở người thứ N" để cloud đóng lệnh lại.
 */
export interface InFlightRecipient {
  index: number;
  recipientId: string;
  startedAt: string;
}

export interface CampaignProgressRecord {
  campaignId: string;
  commandId: string;
  total: number;
  processed: number;
  successCount: number;
  failedCount: number;
  cancelledCount: number;
  unknownCount?: number;
  inFlightRecipient?: InFlightRecipient | null;
  abortedReason?: string;
  startedAt: string;
  updatedAt: string;
}

const defaultDirectory = resolve(dataRoot, 'campaigns');
const FILE_NAME = 'in-flight.json';
const SLEEP_BUF = new Int32Array(new SharedArrayBuffer(4));

function filePath(dir: string): string {
  return resolve(dir, FILE_NAME);
}

function readAll(dir: string): Record<string, CampaignProgressRecord> {
  const path = filePath(dir);
  if (!fs.existsSync(path)) return {};
  let rawText: string;
  try {
    rawText = fs.readFileSync(path, 'utf-8');
  } catch {
    // Lỗi I/O tạm thời (EBUSY/EPERM do AV/indexer trên Windows) — không quarantine file hợp lệ.
    return {};
  }
  try {
    const parsed = JSON.parse(rawText);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return {};
    const normalized: Record<string, CampaignProgressRecord> = {};
    for (const [key, raw] of Object.entries(parsed)) {
      if (!raw || typeof raw !== 'object' || Array.isArray(raw)) continue;
      const r = raw as Record<string, unknown>;
      normalized[key] = {
        ...(r as unknown as CampaignProgressRecord),
        cancelledCount:
          typeof r.cancelledCount === 'number' && Number.isFinite(r.cancelledCount)
            ? r.cancelledCount
            : 0,
        unknownCount:
          typeof r.unknownCount === 'number' && Number.isFinite(r.unknownCount)
            ? r.unknownCount
            : 0,
      };
    }
    return normalized;
  } catch {
    try {
      for (const entry of fs.readdirSync(dir)) {
        if (entry.startsWith(`${FILE_NAME}.corrupt-`)) {
          fs.unlinkSync(resolve(dir, entry));
        }
      }
      const corruptTs = Math.trunc(performance.timeOrigin + performance.now());
      const corruptPath = `${path}.corrupt-${corruptTs}`;
      try {
        fs.renameSync(path, corruptPath);
      } catch {
        fs.copyFileSync(path, corruptPath);
        try {
          fs.unlinkSync(path);
        } catch {
          // ignore unlink fallback failure
        }
      }
    } catch {
      // ignore diagnostic copy failure
    }
    // File hỏng (bị kill giữa lúc ghi) — coi như không có chiến dịch dở dang.
    // Thà mất một báo cáo gián đoạn còn hơn làm backend chết lúc boot.
    return {};
  }
}

function renameWithWindowsRetry(tmpPath: string, targetPath: string): void {
  let lastErr: any;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      fs.renameSync(tmpPath, targetPath);
      return;
    } catch (err: any) {
      lastErr = err;
      const code = String(err?.code || '');
      if ((code === 'EPERM' || code === 'EBUSY' || code === 'EACCES') && attempt < 2) {
        Atomics.wait(SLEEP_BUF, 0, 0, 50);
        continue;
      }
      throw err;
    }
  }
  throw lastErr;
}

function writeAll(dir: string, records: Record<string, CampaignProgressRecord>): boolean {
  const target = filePath(dir);
  const tmp = `${target}.tmp`;
  try {
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(tmp, JSON.stringify(records, null, 2), 'utf-8');
    renameWithWindowsRetry(tmp, target);
    return true;
  } catch (err) {
    try {
      if (fs.existsSync(tmp)) fs.unlinkSync(tmp);
    } catch {
      // ignore cleanup error
    }
    console.error('[campaign-progress] Không ghi được tiến độ chiến dịch:', err);
    return false;
  }
}

export function beginCampaign(
  record: Omit<
    CampaignProgressRecord,
    'startedAt' | 'updatedAt' | 'processed' | 'successCount' | 'failedCount' | 'cancelledCount'
  >,
  dir: string = defaultDirectory,
): boolean {
  const now = new Date().toISOString();
  const records = readAll(dir);
  records[record.campaignId] = {
    ...record,
    processed: 0,
    successCount: 0,
    failedCount: 0,
    cancelledCount: 0,
    unknownCount: 0,
    inFlightRecipient: null,
    startedAt: now,
    updatedAt: now,
  };
  return writeAll(dir, records);
}

export function updateCampaign(
  campaignId: string,
  patch: Partial<
    Pick<
      CampaignProgressRecord,
      | 'processed'
      | 'successCount'
      | 'failedCount'
      | 'cancelledCount'
      | 'unknownCount'
      | 'inFlightRecipient'
      | 'abortedReason'
    >
  >,
  dir: string = defaultDirectory,
): boolean {
  const records = readAll(dir);
  const existing = records[campaignId];
  if (!existing) return false;
  records[campaignId] = { ...existing, ...patch, updatedAt: new Date().toISOString() };
  return writeAll(dir, records);
}

export function finishCampaign(campaignId: string, dir: string = defaultDirectory): void {
  const records = readAll(dir);
  if (!(campaignId in records)) return;
  delete records[campaignId];
  writeAll(dir, records);
}

/**
 * Chiến dịch còn sót lại trên đĩa — tức là tiến trình đã chết trước khi chúng
 * kịp kết thúc. Bên gọi phải tự loại những chiến dịch đang chạy thật trong
 * tiến trình hiện tại (runtime khởi động lại mà tiến trình thì không).
 */
export function listInterruptedCampaigns(dir: string = defaultDirectory): CampaignProgressRecord[] {
  return Object.values(readAll(dir));
}
