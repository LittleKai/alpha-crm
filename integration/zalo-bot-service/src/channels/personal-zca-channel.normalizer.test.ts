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

test('normalizeInboundMessage extracts image attachments from Zalo payloads', () => {
  const event = {
    data: {
      uidFrom: 'user-1',
      idTo: 'user-1',
      msgType: 'chat.photo',
      content: {
        title: '',
        description: '',
        href: 'https://zalo.example/view/photo',
        thumb: 'https://zalo.example/thumb/photo.jpg',
        params: {
          fileName: 'photo.jpg',
          fileSize: 2048,
          fileExt: 'jpg',
        },
      },
      msgId: 'img-1',
      cliMsgId: 'cli-img-1',
      ts: 1780483200000,
    },
  };

  const normalized = normalizeInboundMessageForTest(instance, event) as any;

  assert.equal(normalized?.messageType, 'image');
  assert.equal(normalized?.content, '[image]');
  assert.equal(normalized?.attachments?.length, 1);
  assert.deepEqual(normalized?.attachments?.[0], {
    kind: 'image',
    name: 'photo.jpg',
    url: 'https://zalo.example/view/photo',
    mimeType: 'image/jpeg',
    sizeBytes: 2048,
    metadata: {
      thumbnailUrl: 'https://zalo.example/thumb/photo.jpg',
      fileExt: 'jpg',
    },
  });
});
