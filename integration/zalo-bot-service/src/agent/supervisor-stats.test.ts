import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { setSupervisorStats, getSupervisorStats } from './supervisor-stats.js';

describe('supervisor stats', () => {
  it('keeps lastExitCode null when the process never exited', () => {
    const out = setSupervisorStats({ restartCount: 0, lastExitCode: null });
    // Number(null) === 0 — không được biến "chưa từng thoát" thành "thoát mã 0".
    assert.equal(out.lastExitCode, null);
    assert.equal(out.restartCount, 0);
  });

  it('normalizes junk into safe values', () => {
    const out = setSupervisorStats({
      restartCount: -5 as unknown as number,
      lastError: 'y'.repeat(2000),
    });
    assert.equal(out.restartCount, 0);
    assert.equal(out.lastError.length, 500);
  });

  it('stores the latest push for the heartbeat to read', () => {
    setSupervisorStats({ restartCount: 4, lastExitCode: 3221225477 });
    assert.equal(getSupervisorStats()?.restartCount, 4);
    assert.equal(getSupervisorStats()?.lastExitCode, 3221225477);
  });
});
