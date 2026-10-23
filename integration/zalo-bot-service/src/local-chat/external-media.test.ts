import assert from 'node:assert/strict';
import dns from 'node:dns/promises';
import https from 'node:https';
import { EventEmitter } from 'node:events';
import { Readable } from 'node:stream';
import { test } from 'node:test';
import { downloadExternalMedia } from './external-media.js';

test('external media validates DNS and every redirect before connecting', async (t) => {
  let addresses = ['93.184.216.34'];
  let requests = 0;
  let status = 200;
  let location = '';
  let headers: Record<string, string> = {};
  let body = [Buffer.from('media')];
  let responses: Array<{ status: number; location?: string }> = [];
  t.mock.method(dns, 'lookup', async () => addresses.map(address => ({ address, family: address.includes(':') ? 6 : 4 })));
  t.mock.method(https, 'get', (url: URL, options: any, callback: (response: any) => void) => {
    requests++;
    assert.equal(options.agent, false);
    assert.equal(options.autoSelectFamily, false);
    options.lookup(url.hostname, {}, (error: unknown, address: string, family: number) => {
      assert.equal(error, null);
      assert.equal(address, addresses.find(value => !value.includes(':')) ?? addresses[0]);
      assert.equal(family, address.includes(':') ? 6 : 4);
    });
    const request = new EventEmitter();
    queueMicrotask(() => {
      const response = Readable.from(body);
      const hop = responses.shift() ?? { status, location };
      Object.assign(response, { statusCode: hop.status, headers: { 'content-type': 'image/png', ...headers, ...(hop.location ? { location: hop.location } : {}) } });
      callback(response);
    });
    return request;
  });
  const download = (url: string) => downloadExternalMedia(url, new AbortController().signal);
  for (const url of ['file:///test', 'https://user:pass@example.com/a', 'https://127.1/a', 'https://[::ffff:127.0.0.1]/a', 'https://[2002:7f00:1::]/a']) {
    await assert.rejects(download(url));
  }
  assert.equal(requests, 0);
  for (const address of ['127.0.0.1', '10.0.0.1', '100.64.0.1', '169.254.169.254', '172.16.0.1', '192.168.0.1', '198.18.0.1', '224.0.0.1', '::1', 'fc00::1', 'fe80::1', '::ffff:10.0.0.1', '2001:db8::1', '2002:0808:0808::1']) {
    addresses = [address];
    await assert.rejects(download('https://cdn.example/a'), /Blocked/, address);
  }
  addresses = ['93.184.216.34', '127.0.0.1'];
  await assert.rejects(download('https://cdn.example/a'));
  assert.equal(requests, 0);
  addresses = ['93.184.216.34'];
  status = 302;
  location = 'https://127.0.0.1/private';
  await assert.rejects(download('https://cdn.example/a'));
  assert.equal(requests, 1);
  location = '/loop';
  requests = 0;
  await assert.rejects(download('https://cdn.example/a'), /redirect/i);
  assert.equal(requests, 6);
  status = 200;
  location = '';
  responses = [{ status: 302, location: '/final' }, { status: 200 }];
  const result = await download('https://cdn.example/a');
  assert.equal(result.buffer.toString(), 'media');
  assert.equal(result.contentType, 'image/png');
  addresses = ['2001:4860:4860::8888'];
  assert.equal((await download('https://cdn.example/a')).buffer.toString(), 'media');
  addresses = ['2001:4860:4860::8888', '93.184.216.34'];
  assert.equal((await download('https://cdn.example/a')).buffer.toString(), 'media');
  headers = { 'content-length': String(501 * 1024 * 1024) };
  await assert.rejects(download('https://cdn.example/a'), /limit/i);
  headers = {};
  // Reuse a chunk so the stream exceeds the limit without allocating a 500 MB fixture.
  body = Array(32).fill(Buffer.alloc(16 * 1024 * 1024));
  await assert.rejects(download('https://cdn.example/a'), /limit/i);
  const controller = new AbortController();
  controller.abort();
  const before = requests;
  await assert.rejects(downloadExternalMedia('https://cdn.example/a', controller.signal));
  assert.equal(requests, before);
});

test('external media deadline also cancels a pending DNS lookup', async (t) => {
  t.mock.method(dns, 'lookup', () => new Promise(() => {}));
  const controller = new AbortController();
  const pending = downloadExternalMedia('https://cdn.example/a', controller.signal);
  controller.abort(new Error('deadline'));
  await assert.rejects(pending, /deadline/);
});

test('external media propagates connection and interrupted-body failures', async (t) => {
  t.mock.method(dns, 'lookup', async () => [{ address: '93.184.216.34', family: 4 }]);
  let failConnection = true;
  t.mock.method(https, 'get', (_url: URL, _options: unknown, callback: (response: any) => void) => {
    const request = new EventEmitter();
    queueMicrotask(() => {
      if (failConnection) {
        request.emit('error', new Error('connection failed'));
      } else {
        const response = Readable.from((async function* () {
          yield Buffer.from('partial');
          throw new Error('body interrupted');
        })());
        Object.assign(response, { statusCode: 200, headers: {} });
        callback(response);
      }
    });
    return request;
  });
  await assert.rejects(downloadExternalMedia('https://cdn.example/a', new AbortController().signal), /connection failed/);
  failConnection = false;
  await assert.rejects(downloadExternalMedia('https://cdn.example/a', new AbortController().signal), /body interrupted/);
});
