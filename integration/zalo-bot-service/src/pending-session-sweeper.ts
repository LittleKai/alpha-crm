/**
 * Dọn phiên đăng nhập QR quá hạn.
 *
 * Phiên QR chỉ sống vài phút nhưng trước đây không bao giờ bị xoá khỏi Map, và
 * ảnh `qr_*.png` ở lại trên đĩa vĩnh viễn — Map phình theo mỗi lần người dùng
 * bấm "Thêm tài khoản".
 *
 * Tách khỏi server.ts để test được: import server.ts sẽ mở luôn cổng HTTP.
 */
import { existsSync, unlinkSync } from 'fs';
import { resolve } from 'path';

export const PENDING_SESSION_TTL_MS = 10 * 60 * 1000;

export interface SweepableSession {
  qrFileName: string;
}

/** Id có dạng `session_<epoch ms>`; trả NaN nếu không đọc được. */
export function sessionStartedAt(sessionId: string): number {
  const raw = sessionId.startsWith('session_') ? sessionId.slice('session_'.length) : '';
  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : Number.NaN;
}

/**
 * Xoá các phiên quá hạn khỏi [sessions] và xoá ảnh QR tương ứng trong [qrDir].
 * Trả về id các phiên đã dọn.
 *
 * Id không đọc được thì GIỮ LẠI: thà rò rỉ một bản ghi còn hơn xoá nhầm phiên
 * đang chờ người dùng quét mã.
 */
export function sweepExpiredSessions(
  sessions: Map<string, SweepableSession>,
  qrDir: string,
  now = Date.now(),
  ttlMs = PENDING_SESSION_TTL_MS,
): string[] {
  const removed: string[] = [];
  for (const [sessionId, session] of sessions) {
    const startedAt = sessionStartedAt(sessionId);
    if (Number.isNaN(startedAt) || now - startedAt < ttlMs) continue;

    sessions.delete(sessionId);
    removed.push(sessionId);
    try {
      const qrPath = resolve(qrDir, session.qrFileName);
      if (existsSync(qrPath)) unlinkSync(qrPath);
    } catch (err) {
      console.warn(`[server] Không xoá được ảnh QR của ${sessionId}:`, err);
    }
  }
  return removed;
}
