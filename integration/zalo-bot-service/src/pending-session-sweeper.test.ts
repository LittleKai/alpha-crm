import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync, existsSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';
import {
  PENDING_SESSION_TTL_MS,
  sessionStartedAt,
  sweepExpiredSessions,
} from './pending-session-sweeper.js';

let qrDir: string;

function makeSession(dir: string, id: string) {
  const qrFileName = `qr_${id}.png`;
  writeFileSync(join(dir, qrFileName), 'fake-png', 'utf-8');
  return { qrFileName };
}

describe('pending QR session sweeper', () => {
  beforeEach(() => {
    qrDir = mkdtempSync(join(tmpdir(), 'qr-sweep-'));
  });
  afterEach(() => rmSync(qrDir, { recursive: true, force: true }));

  it('removes an expired session and deletes its QR image', () => {
    const now = 1_800_000_000_000;
    const oldId = `session_${now - PENDING_SESSION_TTL_MS - 1}`;
    const sessions = new Map([[oldId, makeSession(qrDir, oldId)]]);

    const removed = sweepExpiredSessions(sessions, qrDir, now);

    assert.deepEqual(removed, [oldId]);
    assert.equal(sessions.size, 0);
    assert.equal(existsSync(join(qrDir, `qr_${oldId}.png`)), false);
  });

  it('keeps a session that is still within its window', () => {
    const now = 1_800_000_000_000;
    const freshId = `session_${now - 1000}`;
    const sessions = new Map([[freshId, makeSession(qrDir, freshId)]]);

    assert.deepEqual(sweepExpiredSessions(sessions, qrDir, now), []);
    assert.equal(sessions.size, 1);
    assert.equal(existsSync(join(qrDir, `qr_${freshId}.png`)), true);
  });

  it('keeps a session whose id cannot be parsed rather than dropping it', () => {
    const sessions = new Map([['weird-id', makeSession(qrDir, 'weird-id')]]);
    assert.deepEqual(sweepExpiredSessions(sessions, qrDir, Date.now()), []);
    assert.equal(sessions.size, 1);
  });

  it('does not throw when the QR image is already gone', () => {
    const now = 1_800_000_000_000;
    const oldId = `session_${now - PENDING_SESSION_TTL_MS - 1}`;
    const sessions = new Map([[oldId, { qrFileName: 'qr_missing.png' }]]);

    assert.doesNotThrow(() => sweepExpiredSessions(sessions, qrDir, now));
    assert.equal(sessions.size, 0);
  });

  it('parses the timestamp out of a session id', () => {
    assert.equal(sessionStartedAt('session_1700000000000'), 1700000000000);
    assert.ok(Number.isNaN(sessionStartedAt('nope')));
    assert.ok(Number.isNaN(sessionStartedAt('session_abc')));
  });
});
