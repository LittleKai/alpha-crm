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
export interface CampaignProgressRecord {
  campaignId: string;
  commandId: string;
  total: number;
  processed: number;
  successCount: number;
  failedCount: number;
  cancelledCount: number;
  startedAt: string;
  updatedAt: string;
}

const defaultDirectory = resolve(dataRoot, 'campaigns');
const FILE_NAME = 'in-flight.json';

function filePath(dir: string): string {
  return resolve(dir, FILE_NAME);
}

function readAll(dir: string): Record<string, CampaignProgressRecord> {
  const path = filePath(dir);
  if (!fs.existsSync(path)) return {};
  try {
    const parsed = JSON.parse(fs.readFileSync(path, 'utf-8'));
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  } catch {
    // File hỏng (bị kill giữa lúc ghi) — coi như không có chiến dịch dở dang.
    // Thà mất một báo cáo gián đoạn còn hơn làm backend chết lúc boot.
    return {};
  }
}

function writeAll(dir: string, records: Record<string, CampaignProgressRecord>): void {
  try {
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(filePath(dir), JSON.stringify(records, null, 2), 'utf-8');
  } catch (err) {
    console.error('[campaign-progress] Không ghi được tiến độ chiến dịch:', err);
  }
}

export function beginCampaign(
  record: Omit<CampaignProgressRecord, 'startedAt' | 'updatedAt' | 'processed' | 'successCount' | 'failedCount' | 'cancelledCount'>,
  dir: string = defaultDirectory,
): void {
  const now = new Date().toISOString();
  const records = readAll(dir);
  records[record.campaignId] = {
    ...record,
    processed: 0,
    successCount: 0,
    failedCount: 0,
    cancelledCount: 0,
    startedAt: now,
    updatedAt: now,
  };
  writeAll(dir, records);
}

export function updateCampaign(
  campaignId: string,
  patch: Partial<Pick<CampaignProgressRecord, 'processed' | 'successCount' | 'failedCount' | 'cancelledCount'>>,
  dir: string = defaultDirectory,
): void {
  const records = readAll(dir);
  const existing = records[campaignId];
  if (!existing) return;
  records[campaignId] = { ...existing, ...patch, updatedAt: new Date().toISOString() };
  writeAll(dir, records);
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
