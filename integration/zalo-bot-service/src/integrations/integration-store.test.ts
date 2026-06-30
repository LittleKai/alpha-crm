import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import {
  maskIntegrationSettings,
  readIntegrationSettings,
  writeIntegrationSettings,
} from './integration-store.js';

test('integration settings persist n8n secrets and return masked status', () => {
  const dir = mkdtempSync(join(tmpdir(), 'alpha-crm-integrations-'));
  const filePath = join(dir, 'settings.json');
  try {
    writeIntegrationSettings(
      {
        n8n: {
          enabled: true,
          baseUrl: 'https://n8n.example.com/',
          apiKey: 'n8n-secret-123456',
          eventWebhookUrl: 'https://n8n.example.com/webhook/alpha',
          callbackUrl: 'https://alpha.example/api/crm/n8n/actions',
        },
        facebook: {
          status: 'configured',
          enabled: true,
          pageName: 'Alpha Page',
          pageId: '123456',
          pageAccessToken: 'page-token-abcdef',
          verifyToken: 'verify-token-123456',
          enforce24hWindow: true,
        },
        email: {
          enabled: true,
          mode: 'inbox',
          fromName: 'Alpha CRM',
          fromAddress: 'care@example.com',
          smtpHost: 'smtp.example.com/',
          smtpPort: 587,
          smtpSecure: false,
          smtpUsername: 'care@example.com',
          smtpPassword: 'smtp-secret-123456',
          inboundEnabled: true,
          imapHost: 'imap.example.com/',
          imapPort: 993,
          imapSecure: true,
          imapUsername: 'care@example.com',
          imapPassword: 'imap-secret-123456',
        },
      },
      filePath,
    );

    const settings = readIntegrationSettings(filePath);
    assert.equal(settings.n8n.baseUrl, 'https://n8n.example.com');
    assert.equal(settings.n8n.apiKey, 'n8n-secret-123456');
    assert.equal(settings.email.smtpHost, 'smtp.example.com');
    assert.equal(settings.email.imapHost, 'imap.example.com');

    const masked = maskIntegrationSettings(settings);
    assert.equal(masked.n8n.apiKey, '************3456');
    assert.equal(masked.facebook.status, 'configured');
    assert.equal(masked.facebook.pageAccessToken, '************cdef');
    assert.equal(masked.facebook.verifyToken, '************3456');
    assert.equal(masked.email.smtpPassword, '************3456');
    assert.equal(masked.email.imapPassword, '************3456');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
