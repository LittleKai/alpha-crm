import test from 'node:test';
import assert from 'node:assert/strict';
import {
  CloudApiError,
  isDeviceRevokedError,
} from './cloud-api.js';

test('isDeviceRevokedError accepts only explicit cloud revocation', () => {
  assert.equal(
    isDeviceRevokedError(
      new CloudApiError('revoked', 403, 'DEVICE_REVOKED'),
    ),
    true,
  );
  assert.equal(
    isDeviceRevokedError(
      new CloudApiError('bad secret', 403, 'INVALID_AGENT_CREDENTIALS'),
    ),
    false,
  );
  assert.equal(isDeviceRevokedError(new TypeError('network failed')), false);
});
