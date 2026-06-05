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
          status: 'cloud_required',
          pageName: 'Alpha Page',
        },
      },
      filePath,
    );

    const settings = readIntegrationSettings(filePath);
    assert.equal(settings.n8n.baseUrl, 'https://n8n.example.com');
    assert.equal(settings.n8n.apiKey, 'n8n-secret-123456');

    const masked = maskIntegrationSettings(settings);
    assert.equal(masked.n8n.apiKey, '************3456');
    assert.equal(masked.facebook.status, 'cloud_required');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
