import assert from 'node:assert/strict';
import test from 'node:test';

import { validateZaloSendPayloadForTest } from './command-executor.js';

test('zalo.message.send validation allows attachment-only payloads', () => {
  assert.doesNotThrow(() =>
    validateZaloSendPayloadForTest({
      recipientId: 'thread-1',
      message: '',
      attachments: ['C:/tmp/image.png'],
    }),
  );
});

test('zalo.message.send validation rejects empty text and no attachments', () => {
  assert.throws(
    () =>
      validateZaloSendPayloadForTest({
        recipientId: 'thread-1',
        message: ' ',
        attachments: [],
      }),
    /message hoac attachments/,
  );
});
