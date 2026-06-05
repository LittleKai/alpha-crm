import test from 'node:test';
import assert from 'node:assert/strict';
import { parseProxyUrl, redactProxyUrl } from './proxy-helper.js';

test('parseProxyUrl accepts authenticated socks and http proxy URLs', () => {
  assert.deepEqual(parseProxyUrl('socks5://user:pass@127.0.0.1:1080'), {
    protocol: 'socks5:',
    host: '127.0.0.1',
    port: '1080',
    username: 'user',
    password: 'pass',
  });
  assert.equal(parseProxyUrl('http://proxy.local:8080')?.protocol, 'http:');
});

test('redactProxyUrl hides proxy password', () => {
  assert.equal(
    redactProxyUrl('socks5://user:pass@127.0.0.1:1080'),
    'socks5://user:***@127.0.0.1:1080',
  );
});
