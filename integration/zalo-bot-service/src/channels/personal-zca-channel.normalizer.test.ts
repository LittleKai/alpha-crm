import assert from 'node:assert/strict';
import { test } from 'node:test';

import { normalizeInboundMessageForTest } from './personal-zca-channel.js';

const instance = {
  uId: 'acc-1',
  label: 'Nguyen Anh Duc',
};

test('normalizeInboundMessage reads nested plain text content and avatar aliases', () => {
  const event = {
    data: {
      uidFrom: 'user-1',
      idTo: 'user-1',
      content: {
        msg: 'Tin nhan thuong khong co link',
      },
      avatar: '//avatar.zalo.me/user.jpg',
      msgId: 'msg-1',
      ts: 1780483200000,
    },
  };

  const normalized = normalizeInboundMessageForTest(instance, event);

  assert.equal(normalized?.content, 'Tin nhan thuong khong co link');
  assert.equal(normalized?.avatarUrl, 'https://avatar.zalo.me/user.jpg');
  assert.equal(normalized?.messageType, 'text');
});
