import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, readFileSync, writeFileSync, existsSync, statSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';
import { saveClientLog, getClientLogs, deleteClientLogs } from './client-log.js';

let dir: string;

describe('client-log (NDJSON append-only)', () => {
  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), 'client-log-test-'));
  });
  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it('appends one line per log and returns newest first', () => {
    saveClientLog({ message: 'first' }, dir);
    saveClientLog({ message: 'second' }, dir);

    const raw = readFileSync(join(dir, 'client_errors.ndjson'), 'utf-8');
    assert.equal(raw.trim().split('\n').length, 2);

    const logs = getClientLogs(dir);
    assert.deepEqual(logs.map((l) => l.message), ['second', 'first']);
  });

  it('survives a torn last line (process killed mid-write)', () => {
    saveClientLog({ message: 'good' }, dir);
    const path = join(dir, 'client_errors.ndjson');
    writeFileSync(path, readFileSync(path, 'utf-8') + '{"message":"tor', 'utf-8');

    const logs = getClientLogs(dir);
    assert.equal(logs.length, 1);
    assert.equal(logs[0]!.message, 'good');
  });

  it('trims below the trigger size so it does not re-trim on every write', () => {
    // stackTrace ~5KB mỗi bản ghi → vượt ngưỡng 2MB trong khoảng 400 lần ghi.
    const bigStack = 'x'.repeat(5000);
    for (let i = 0; i < 600; i++) {
      saveClientLog({ message: `log-${i}`, stackTrace: bigStack }, dir);
    }
    const logs = getClientLogs(dir);
    assert.ok(logs.length <= 500, `expected <= 500, got ${logs.length}`);
    // Bản ghi mới nhất phải còn nguyên.
    assert.equal(logs[0]!.message, 'log-599');
    // Sau khi cắt, file phải nằm DƯỚI ngưỡng kích hoạt — nếu không thì mọi lần
    // ghi tiếp theo lại trim, tái tạo đúng vòng khuếch đại vừa bỏ đi.
    assert.ok(
      statSync(join(dir, 'client_errors.ndjson')).size < 2 * 1024 * 1024,
      'file must be under the trim trigger after trimming',
    );
  });

  it('migrates the legacy JSON-array file exactly once, newest preserved', () => {
    writeFileSync(
      join(dir, 'client_errors.json'),
      JSON.stringify([
        { id: 'b', message: 'newer', timestamp: '2026-01-02T00:00:00.000Z' },
        { id: 'a', message: 'older', timestamp: '2026-01-01T00:00:00.000Z' },
      ]),
      'utf-8',
    );

    const logs = getClientLogs(dir);
    assert.deepEqual(logs.map((l) => l.message), ['newer', 'older']);
    assert.equal(existsSync(join(dir, 'client_errors.json')), false);

    // Lần đọc thứ hai không được nhân đôi dữ liệu.
    assert.equal(getClientLogs(dir).length, 2);
  });

  it('deletes by id and leaves the rest intact', () => {
    saveClientLog({ message: 'keep-me' }, dir);
    saveClientLog({ message: 'drop-me' }, dir);
    const target = getClientLogs(dir).find((l) => l.message === 'drop-me')!;

    deleteClientLogs([target.id], dir);

    const logs = getClientLogs(dir);
    assert.deepEqual(logs.map((l) => l.message), ['keep-me']);
  });
});
