/**
 * Cảnh báo khi hai backend cùng dùng chung một dataRoot.
 *
 * dataRoot là theo MÁY (%LOCALAPPDATA%\AlphaCRM\zalo-bot-service), nên một bản
 * dev chạy từ repo và một bản đóng gói chạy cùng lúc sẽ cùng ghi vào một file
 * SQLite và cùng chạy listener zca trên cùng bộ credentials — nguồn của những
 * lỗi rất khó lần ra.
 *
 * CHỈ cảnh báo, không từ chối khởi động: một file khoá cũ sót lại sau khi bị
 * taskkill sẽ biến app thành không mở được, tệ hơn nhiều so với vấn đề nó ngăn.
 */
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'fs';
import { resolve } from 'path';
import { dataRoot } from './config.js';

const FILE = resolve(dataRoot, 'owner.json');

export interface DataRootOwner {
  pid: number;
  projectRoot: string;
  startedAt: string;
}

/** Tiến trình còn sống không. `kill(pid, 0)` không gửi tín hiệu, chỉ kiểm tra. */
export function isProcessAlive(pid: number): boolean {
  if (!Number.isInteger(pid) || pid <= 0 || pid === process.pid) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (err: any) {
    // EPERM = tiến trình tồn tại nhưng thuộc user khác.
    return err?.code === 'EPERM';
  }
}

/** Đọc chủ sở hữu cũ và trả về nếu tiến trình đó VẪN đang chạy. */
export function readLiveOwner(file: string = FILE): DataRootOwner | null {
  if (!existsSync(file)) return null;
  try {
    const owner = JSON.parse(readFileSync(file, 'utf-8')) as DataRootOwner;
    return isProcessAlive(Number(owner?.pid)) ? owner : null;
  } catch {
    return null;
  }
}

/** Ghi nhận tiến trình này là chủ dataRoot; cảnh báo nếu đã có tiến trình khác. */
export function claimDataRoot(projectRoot: string, file: string = FILE): DataRootOwner | null {
  const conflicting = readLiveOwner(file);
  if (conflicting) {
    console.warn(
      `[data-root] ⚠ Một backend Alpha CRM khác (pid ${conflicting.pid}, ` +
        `${conflicting.projectRoot}) đang dùng chung ${dataRoot}. ` +
        `Hai tiến trình cùng ghi live-chat.sqlite và cùng chạy listener zca trên ` +
        `cùng bộ credentials — hãy tắt bớt một bản (thường là bản dev hoặc bản đóng gói).`,
    );
  }
  try {
    mkdirSync(dataRoot, { recursive: true });
    writeFileSync(
      file,
      JSON.stringify({ pid: process.pid, projectRoot, startedAt: new Date().toISOString() }, null, 2),
      'utf-8',
    );
  } catch (err) {
    console.error('[data-root] Không ghi được owner.json:', err);
  }
  return conflicting;
}
