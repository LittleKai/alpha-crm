/**
 * Số liệu vòng đời do SUPERVISOR bên Flutter nắm giữ (backend không tự biết mình
 * đã bị khởi động lại bao nhiêu lần, vì mỗi lần restart là một tiến trình mới).
 * Flutter đẩy sang qua POST /internal/supervisor-stats; agent-runner gửi kèm
 * heartbeat để cloud thấy được độ ổn định thực địa trên từng máy khách.
 */
export interface SupervisorStats {
  restartCount: number;
  lastExitCode: number | null;
  lastError: string;
  reportedAt: string;
}

let stats: SupervisorStats | null = null;

export function setSupervisorStats(input: Partial<SupervisorStats>): SupervisorStats {
  const restartCount = Number(input.restartCount);
  // Number(null) === 0 — phải loại null/undefined TRƯỚC khi ép kiểu, nếu không
  // một máy chưa từng crash sẽ báo về cloud là "đã thoát với mã 0".
  const rawExitCode = input.lastExitCode;
  const lastExitCode =
    rawExitCode === null || rawExitCode === undefined
      ? Number.NaN
      : Number(rawExitCode);
  stats = {
    restartCount: Number.isFinite(restartCount) && restartCount >= 0 ? Math.floor(restartCount) : 0,
    lastExitCode: Number.isFinite(lastExitCode) ? Math.floor(lastExitCode) : null,
    // Cắt ngắn: thông điệp này đi vào Mongo mỗi nhịp heartbeat.
    lastError: String(input.lastError ?? '').slice(0, 500),
    reportedAt: new Date().toISOString(),
  };
  return stats;
}

export function getSupervisorStats(): SupervisorStats | null {
  return stats;
}
