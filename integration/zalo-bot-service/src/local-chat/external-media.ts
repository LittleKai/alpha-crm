import dns from 'node:dns/promises';
import http from 'node:http';
import https from 'node:https';
import { BlockList, isIP } from 'node:net';

const MAX_MEDIA_BYTES = 500 * 1024 * 1024;
const blockedV4 = new BlockList();
for (const [address, prefix] of [
  ['0.0.0.0', 8], ['10.0.0.0', 8], ['100.64.0.0', 10], ['127.0.0.0', 8],
  ['169.254.0.0', 16], ['172.16.0.0', 12], ['192.0.0.0', 24], ['192.0.2.0', 24],
  ['192.88.99.0', 24], ['192.168.0.0', 16], ['198.18.0.0', 15],
  ['198.51.100.0', 24], ['203.0.113.0', 24], ['224.0.0.0', 4], ['240.0.0.0', 4],
] as const) blockedV4.addSubnet(address, prefix, 'ipv4');
const globalV6 = new BlockList();
globalV6.addSubnet('2000::', 3, 'ipv6');
const blockedV6 = new BlockList();
for (const [address, prefix] of [['2001::', 23], ['2001:db8::', 32], ['2002::', 16], ['3fff::', 20]] as const) {
  blockedV6.addSubnet(address, prefix, 'ipv6');
}

function isPublicAddress(address: string): boolean {
  const family = isIP(address);
  return family === 4 ? !blockedV4.check(address, 'ipv4') :
    family === 6 && globalV6.check(address, 'ipv6') && !blockedV6.check(address, 'ipv6');
}

async function resolvePublicAddress(url: URL, signal: AbortSignal) {
  signal.throwIfAborted();
  const host = url.hostname.replace(/^\[|\]$/g, '').toLowerCase();
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password ||
      host.replace(/\.$/, '') === 'localhost' || host.replace(/\.$/, '').endsWith('.local')) {
    throw new Error('Blocked unsafe or local media URL.');
  }
  if (isIP(host)) {
    if (!isPublicAddress(host)) throw new Error('Blocked non-public media address.');
    return { address: host, family: isIP(host) };
  }
  let abort!: () => void;
  const aborted = new Promise<never>((_resolve, reject) => {
    abort = () => reject(signal.reason);
    signal.addEventListener('abort', abort, { once: true });
  });
  try {
    const addresses = await Promise.race([dns.lookup(host, { all: true, verbatim: true }), aborted]);
    signal.throwIfAborted();
    if (!addresses.length || addresses.some(result => !isPublicAddress(result.address))) {
      throw new Error('Blocked non-public media address.');
    }
    // Keep dual-stack CDNs usable on Windows networks without IPv6 connectivity.
    return addresses.find(result => result.family === 4) ?? addresses[0];
  } finally {
    signal.removeEventListener('abort', abort);
  }
}

/** Validate and pin every hop; automatic redirects and a second DNS lookup bypass this boundary. */
export async function downloadExternalMedia(rawUrl: string, signal: AbortSignal): Promise<{ buffer: Buffer; contentType: string }> {
  let url = new URL(rawUrl);
  for (let redirects = 0; ; redirects++) {
    const address = await resolvePublicAddress(url, signal);
    signal.throwIfAborted();
    const response = await new Promise<http.IncomingMessage>((resolve, reject) => {
      const options: http.RequestOptions & { autoSelectFamily: boolean } = {
        signal,
        agent: false,
        autoSelectFamily: false,
        lookup: (_host, _options, callback) => callback(null, address.address, address.family),
      };
      const request = (url.protocol === 'https:' ? https : http).get(url, options, resolve);
      request.on('error', reject);
    });
    try {
      const status = response.statusCode || 0;
      if ([301, 302, 303, 307, 308].includes(status)) {
        if (!response.headers.location || redirects >= 5) throw new Error('Invalid or excessive media redirects.');
        url = new URL(response.headers.location, url);
        continue;
      }
      if (status < 200 || status >= 300) throw new Error(`HTTP ${status}`);
      if (Number(response.headers['content-length'] || 0) > MAX_MEDIA_BYTES) {
        throw new Error('Media exceeds the 500 MB local cache limit.');
      }
      const chunks: Buffer[] = [];
      let bytes = 0;
      for await (const chunk of response) {
        bytes += chunk.length;
        if (bytes > MAX_MEDIA_BYTES) throw new Error('Media exceeds the 500 MB local cache limit.');
        chunks.push(chunk);
      }
      return { buffer: Buffer.concat(chunks, bytes), contentType: (response.headers['content-type'] || '').toLowerCase() };
    } finally {
      response.destroy();
    }
  }
}
