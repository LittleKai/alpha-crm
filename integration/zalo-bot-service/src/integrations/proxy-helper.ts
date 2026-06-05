import { ProxyAgent } from 'proxy-agent';
import type { Agent } from 'http';
import https from 'https';

export interface ParsedProxyUrl {
  protocol: string;
  host: string;
  port: string;
  username: string;
  password: string;
}

export interface ProxyTestResult {
  success: boolean;
  status?: number;
  error?: string;
  redactedProxy?: string;
}

export function parseProxyUrl(value: string): ParsedProxyUrl | null {
  const trimmed = String(value || '').trim();
  if (!trimmed) return null;
  try {
    const parsed = new URL(trimmed);
    if (!['http:', 'https:', 'socks4:', 'socks5:'].includes(parsed.protocol)) {
      return null;
    }
    if (!parsed.hostname || !parsed.port) return null;
    return {
      protocol: parsed.protocol,
      host: parsed.hostname,
      port: parsed.port,
      username: decodeURIComponent(parsed.username || ''),
      password: decodeURIComponent(parsed.password || ''),
    };
  } catch {
    return null;
  }
}

export function redactProxyUrl(value: string): string {
  const parsed = parseProxyUrl(value);
  if (!parsed) return '';
  const auth = parsed.username
    ? `${encodeURIComponent(parsed.username)}:${parsed.password ? '***' : ''}@`
    : '';
  return `${parsed.protocol}//${auth}${parsed.host}:${parsed.port}`;
}

export function createProxyAgent(proxyUrl: string): Agent | undefined {
  if (!parseProxyUrl(proxyUrl)) return undefined;
  return new ProxyAgent({ getProxyForUrl: () => proxyUrl }) as unknown as Agent;
}

export async function testProxyConnection(proxyUrl: string): Promise<ProxyTestResult> {
  const agent = createProxyAgent(proxyUrl);
  if (!agent) {
    return { success: false, error: 'Invalid proxy URL.' };
  }
  return new Promise((resolve) => {
    const req = https.request(
      'https://httpbin.org/ip',
      {
        method: 'GET',
        agent,
        timeout: 8000,
      },
      (response) => {
        response.resume();
        resolve({
          success: Boolean(response.statusCode && response.statusCode >= 200 && response.statusCode < 300),
          status: response.statusCode,
          error: response.statusCode && response.statusCode < 300
            ? undefined
            : `Proxy test HTTP ${response.statusCode || 'unknown'}`,
          redactedProxy: redactProxyUrl(proxyUrl),
        });
      },
    );
    req.on('timeout', () => {
      req.destroy(new Error('Proxy test timeout.'));
    });
    req.on('error', (err) => {
      resolve({
        success: false,
        error: err.message,
        redactedProxy: redactProxyUrl(proxyUrl),
      });
    });
    req.end();
  });
}
