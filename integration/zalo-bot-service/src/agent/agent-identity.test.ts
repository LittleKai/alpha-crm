import test from 'node:test';
import assert from 'node:assert/strict';
import {
  existsSync,
  mkdtempSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  deleteFileIfPresent,
  readAgentCredentialsFile,
  writeAgentCredentialsFile,
} from './agent-identity.js';

test('agent credentials persist the owning CRM user', () => {
  const directory = mkdtempSync(join(tmpdir(), 'alpha-crm-agent-'));
  const path = join(directory, 'device-secret.json');

  writeAgentCredentialsFile(path, {
    userId: 'user-1',
    deviceId: 'device-1',
    agentSecret: 'secret-1',
  });

  assert.deepEqual(readAgentCredentialsFile(path), {
    userId: 'user-1',
    deviceId: 'device-1',
    agentSecret: 'secret-1',
  });
});

test('invalid legacy credentials without userId are rejected', () => {
  const directory = mkdtempSync(join(tmpdir(), 'alpha-crm-agent-'));
  const path = join(directory, 'device-secret.json');
  writeFileSync(path, JSON.stringify({
    deviceId: 'device-1',
    agentSecret: 'secret-1',
  }));

  assert.equal(readAgentCredentialsFile(path), null);
});

test('deleteFileIfPresent deletes only the requested session file', () => {
  const directory = mkdtempSync(join(tmpdir(), 'alpha-crm-agent-'));
  const target = join(directory, 'device-secret.json');
  const preserved = join(directory, 'live-chat.sqlite');
  writeFileSync(target, '{}');
  writeFileSync(preserved, 'keep');

  deleteFileIfPresent(target);

  assert.equal(existsSync(target), false);
  assert.equal(readFileSync(preserved, 'utf8'), 'keep');
});
