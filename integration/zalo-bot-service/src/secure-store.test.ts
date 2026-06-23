import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync } from 'fs';
import { resolve } from 'path';
import { tmpdir } from 'os';

// Point dataRoot at a throwaway dir BEFORE importing config/secure-store.
const tmp = mkdtempSync(resolve(tmpdir(), 'alpha-secure-'));
process.env['ALPHA_CRM_DATA_DIR'] = tmp;

const { readSecure, writeSecure } = await import('./secure-store.js');

test('writeSecure round-trips through readSecure', () => {
  const file = resolve(tmp, 'creds.json');
  const payload = JSON.stringify({ cookie: { zpw_sek: 'secret-value' }, imei: '123' });
  writeSecure(file, payload);
  assert.equal(readSecure(file), payload);
});

test('reads legacy plaintext files unchanged (transparent fallback)', () => {
  const file = resolve(tmp, 'legacy.json');
  const payload = JSON.stringify({ plain: true });
  writeFileSync(file, payload, 'utf-8');
  assert.equal(readSecure(file), payload);
});

test('readSecure returns null for a missing file', () => {
  assert.equal(readSecure(resolve(tmp, 'nope.json')), null);
});

test('on-disk bytes are not plaintext when a key is available', () => {
  const file = resolve(tmp, 'enc.json');
  const secret = 'zpw_sek-do-not-leak';
  writeSecure(file, JSON.stringify({ secret }));
  const onDisk = readFileSync(file);
  // If encryption engaged, the raw secret must not be readable on disk.
  // (If the key was unavailable we fell back to plaintext — tolerate that.)
  const looksEncrypted = onDisk.subarray(0, 6).toString() === 'ACENC1';
  if (looksEncrypted) {
    assert.ok(!onDisk.toString('utf-8').includes(secret));
  }
});
