// Adapted from https://github.com/luonghaianh1208/2anh-zalo-bot@9ab55105c83487588e66b55f0ef66894224250a7 (MIT License)

import assert from 'node:assert/strict';
import { mkdirSync, unlinkSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';

import { readImageMetadataForTest } from './personal-zca-channel.js';
import { sniffMediaMimeType } from '../local-chat/local-chat-media-worker.js';

test('readImageMetadataForTest parses BMP headers including top-down negative height and rejects invalid dimensions', async () => {
  const dir = resolve('.data');
  mkdirSync(dir, { recursive: true });
  const bmpPath = resolve(dir, 'test-image-metadata.bmp');
  const invalidBmpPath = resolve(dir, 'test-image-metadata-invalid.bmp');

  const bmp = Buffer.alloc(26);
  Buffer.from('BM', 'ascii').copy(bmp, 0);
  bmp.writeInt32LE(320, 18);
  bmp.writeInt32LE(-240, 22);
  writeFileSync(bmpPath, bmp);

  const invalidBmp = Buffer.alloc(26);
  Buffer.from('BM', 'ascii').copy(invalidBmp, 0);
  invalidBmp.writeInt32LE(0, 18);
  invalidBmp.writeInt32LE(240, 22);
  writeFileSync(invalidBmpPath, invalidBmp);

  try {
    const metadata = await readImageMetadataForTest(bmpPath);
    assert.equal(metadata.width, 320);
    assert.equal(metadata.height, 240);
    assert.equal(metadata.size, 26);

    await assert.rejects(
      () => readImageMetadataForTest(invalidBmpPath),
      /Unsupported image metadata format/,
    );
  } finally {
    unlinkSync(bmpPath);
    unlinkSync(invalidBmpPath);
  }
});

test('sniffMediaMimeType detects magic bytes on application/octet-stream and normalizes image/jpg', () => {
  const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
  const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const gif = Buffer.from('GIF89a\x01\x00\x01\x00', 'ascii');
  const webp = Buffer.from('RIFF\x00\x00\x00\x00WEBP', 'ascii');
  const bmp = Buffer.alloc(26);
  Buffer.from('BM', 'ascii').copy(bmp, 0);

  assert.equal(sniffMediaMimeType(jpeg, 'application/octet-stream'), 'image/jpeg');
  assert.equal(sniffMediaMimeType(png, ''), 'image/png');
  assert.equal(sniffMediaMimeType(gif, 'application/octet-stream'), 'image/gif');
  assert.equal(sniffMediaMimeType(webp, 'binary/octet-stream'), 'image/webp');
  assert.equal(sniffMediaMimeType(bmp, 'application/octet-stream'), 'image/bmp');
  assert.equal(sniffMediaMimeType(jpeg, 'image/jpg; charset=binary'), 'image/jpeg');
  assert.equal(sniffMediaMimeType(Buffer.from('hello'), 'application/pdf'), 'application/pdf');
});
