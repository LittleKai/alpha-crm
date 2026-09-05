import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';
import { isProcessAlive, readLiveOwner } from './data-root-owner.js';

let dir: string;
let file: string;

describe('dataRoot owner', () => {
  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), 'data-root-owner-'));
    file = join(dir, 'owner.json');
  });
  afterEach(() => rmSync(dir, { recursive: true, force: true }));

  it('ignores a stale owner file left by a killed process', () => {
    // PID gần như chắc chắn không tồn tại — mô phỏng file sót sau taskkill /F.
    writeFileSync(file, JSON.stringify({ pid: 999999, projectRoot: 'C:/old' }), 'utf-8');
    // Coi bản ghi chết là "không có chủ" mới là điều quan trọng: nếu không,
    // một file khoá cũ sẽ biến app thành không mở được.
    assert.equal(readLiveOwner(file), null);
  });

  it('never treats the current process as a conflict', () => {
    writeFileSync(file, JSON.stringify({ pid: process.pid, projectRoot: 'C:/self' }), 'utf-8');
    assert.equal(readLiveOwner(file), null);
    assert.equal(isProcessAlive(process.pid), false);
  });

  it('reports no owner when the file is missing or corrupt', () => {
    assert.equal(readLiveOwner(file), null);
    writeFileSync(file, 'không phải json', 'utf-8');
    assert.equal(readLiveOwner(file), null);
  });

  it('rejects nonsense pids', () => {
    assert.equal(isProcessAlive(0), false);
    assert.equal(isProcessAlive(-1), false);
    assert.equal(isProcessAlive(Number.NaN), false);
  });
});
