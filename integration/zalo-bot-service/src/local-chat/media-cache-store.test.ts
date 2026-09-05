import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';
import {
  DEFAULT_MEDIA_CACHE,
  readMediaCacheSettings,
  writeMediaCacheSettings,
  sanitizeMediaCacheSettings,
} from './media-cache-store.js';

let dir: string;
let file: string;

describe('media cache settings', () => {
  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), 'media-cache-'));
    file = join(dir, 'media-cache.json');
  });
  afterEach(() => rmSync(dir, { recursive: true, force: true }));

  it('survives a backend restart instead of falling back to the default', () => {
    writeMediaCacheSettings({ maxGb: 5, maxAgeDays: 30 }, file);
    // Lần đọc kế tiếp mô phỏng tiến trình mới sau restart.
    assert.deepEqual(readMediaCacheSettings(file), { maxGb: 5, maxAgeDays: 30 });
  });

  it('falls back to the default when nothing was ever saved', () => {
    assert.deepEqual(readMediaCacheSettings(file), DEFAULT_MEDIA_CACHE);
  });

  it('falls back to the default when the file is corrupt', () => {
    writeFileSync(file, '{not json', 'utf-8');
    assert.deepEqual(readMediaCacheSettings(file), DEFAULT_MEDIA_CACHE);
  });

  it('clamps junk to a usable range', () => {
    assert.deepEqual(sanitizeMediaCacheSettings({ maxGb: 0, maxAgeDays: 0 }), {
      maxGb: 1,
      maxAgeDays: 1,
    });
    assert.deepEqual(sanitizeMediaCacheSettings({ maxGb: 99999, maxAgeDays: 99999 }), {
      maxGb: 1024,
      maxAgeDays: 3650,
    });
    assert.deepEqual(sanitizeMediaCacheSettings({ maxGb: 'nhiều' }), DEFAULT_MEDIA_CACHE);
  });
});
