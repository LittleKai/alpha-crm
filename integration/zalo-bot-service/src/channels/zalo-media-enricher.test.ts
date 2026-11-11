// Adapted from https://github.com/luonghaianh1208/2anh-zalo-bot@9ab55105c83487588e66b55f0ef66894224250a7 (MIT License)

import assert from 'node:assert/strict';
import test from 'node:test';

import {
  MIME_BY_EXT,
  createStickerDescriber,
  extensionOf,
  hasRealMedia,
  isAlreadyFriendErrorCode,
  isFileMessage,
  preferReadableImageFormats,
  resolveAttachmentMimeType,
} from './zalo-media-enricher.js';

test('createStickerDescriber resolves sticker label and PNG attachment, filters internal codes, caches FIFO without negative caching, and enforces timeout', async () => {
  let currentTime = 1_700_000_000_000;
  let apiCalls = 0;

  const describer = createStickerDescriber({
    ttlMs: 7 * 86400_000,
    maxEntries: 2,
    timeoutMs: 50,
    now: () => currentTime,
  });

  const api = {
    getStickersDetail: async (id: number) => {
      apiCalls++;
      if (id === 27703) {
        return [
          {
            id: 27703,
            text: '[^10751.27703^]',
            stickerUrl: 'https://zalo-api.zadn.vn/api/emoticon/sticker/webpc?eid=27703',
          },
        ];
      }
      if (id === 27704) {
        return [
          {
            id: 27704,
            text: 'xin chào',
            stickerUrl: '//zalo-api.zadn.vn/api/emoticon/sticker/webpc?eid=27704',
          },
        ];
      }
      if (id === 27705) {
        return [];
      }
      if (id === 27706) {
        await new Promise((resolve) => setTimeout(resolve, 200));
        return [{ id: 27706, text: 'slow', stickerUrl: 'https://example.com/slow.png' }];
      }
      return [{ id, text: `sticker-${id}`, stickerUrl: `https://example.com/${id}.png` }];
    },
  };

  // 1) Internal code [^10751.27703^] is filtered out -> label '[Sticker]'
  const first = await describer.describe(api, {
    data: {
      msgType: 'chat.sticker',
      content: { id: 27703, catId: 10751, type: 7 },
    },
  });
  assert.ok(first);
  assert.equal(first.text, '');
  assert.equal(first.label, '[Sticker]');
  assert.equal(
    first.attachment?.url,
    'https://zalo-api.zadn.vn/api/emoticon/sticker/webpc?eid=27703',
  );
  assert.equal(first.attachment?.mimeType, 'image/png');
  assert.equal(apiCalls, 1);

  // Cached hit does not call API again
  const cachedFirst = await describer.describe(api, {
    data: { content: { id: 27703, catId: 10751, type: 7 } },
  });
  assert.equal(cachedFirst?.label, '[Sticker]');
  assert.equal(apiCalls, 1);

  // 2) Human label -> '[Nhãn dán: xin chào]' and protocol-relative URL normalized
  const second = await describer.describe(api, {
    data: { content: { id: 27704, catId: 10751, type: 7 } },
  });
  assert.equal(second?.text, 'xin chào');
  assert.equal(second?.label, '[Nhãn dán: xin chào]');
  assert.equal(
    second?.attachment?.url,
    'https://zalo-api.zadn.vn/api/emoticon/sticker/webpc?eid=27704',
  );
  assert.equal(describer.size(), 2);

  // 3) Empty response is NOT negative-cached
  const emptyRes = await describer.describe(api, {
    data: { content: { id: 27705 } },
  });
  assert.equal(emptyRes?.label, '[Sticker]');
  assert.equal(emptyRes?.attachment, null);
  assert.equal(describer.size(), 2);

  // 4) Timeout fallback returns fallback label without hanging
  const timedOut = await describer.describe(api, {
    data: { content: { id: 27706 } },
  });
  assert.equal(timedOut?.label, '[Sticker]');
  assert.equal(timedOut?.attachment, null);

  // 5) FIFO eviction at maxEntries = 2 (inserting 27707 evicts 27703)
  await describer.describe(api, {
    data: { content: { id: 27707 } },
  });
  assert.equal(describer.size(), 2);
});

test('preferReadableImageFormats drops /gr/jxl/ duplicate when readable format exists in same group', () => {
  const attachments = [
    {
      kind: 'image',
      url: 'https://photo-zadn.zdn.vn/gr/jxl/abc123/photo1',
    },
    {
      kind: 'image',
      url: 'https://photo-zadn.zdn.vn/gr/jpg/abc123/photo1.jpg',
    },
  ];
  const filtered = preferReadableImageFormats(attachments);
  assert.equal(filtered.length, 1);
  assert.equal(
    filtered[0].url,
    'https://photo-zadn.zdn.vn/gr/jpg/abc123/photo1.jpg',
  );

  // Preserves /gr/jxl/ when it is the only URL for that group
  const singleJxl = [
    {
      kind: 'image',
      url: 'https://photo-zadn.zdn.vn/gr/jxl/onlyjxl/photo2',
    },
  ];
  assert.deepEqual(preferReadableImageFormats(singleJxl), singleJxl);

  // Preserves distinct photos in the same group when one is JXL and another is JPG
  const distinctInSameGroup = [
    {
      kind: 'image',
      url: 'https://photo-zadn.zdn.vn/gr/jxl/abc123/photo-A',
    },
    {
      kind: 'image',
      url: 'https://photo-zadn.zdn.vn/gr/jpg/abc123/photo-B.jpg',
    },
  ];
  assert.deepEqual(
    preferReadableImageFormats(distinctInSameGroup),
    distinctInSameGroup,
  );

  // Preserves case-sensitive distinct photo leaf identifiers in the same group
  const caseDistinctLeaves = [
    {
      kind: 'image',
      url: 'https://photo-zadn.zdn.vn/gr/jxl/abc123/photo-A',
    },
    {
      kind: 'image',
      url: 'https://photo-zadn.zdn.vn/gr/jpg/abc123/photo-a.jpg',
    },
  ];
  assert.deepEqual(
    preferReadableImageFormats(caseDistinctLeaves),
    caseDistinctLeaves,
  );
});

test('hasRealMedia denylist blocks link, poll, ecard, undo, and sticker while allowing media and numeric quote cliMsgType', () => {
  assert.equal(hasRealMedia('chat.recommended', 'link'), false);
  assert.equal(hasRealMedia('share.ecard', 'contact_card'), false);
  assert.equal(hasRealMedia('chat.poll', 'poll'), false);
  assert.equal(hasRealMedia('chat.sticker', 'sticker'), false);
  assert.equal(hasRealMedia('chat.undo', 'system'), false);
  assert.equal(hasRealMedia('webchat', 'text'), false);
  assert.equal(hasRealMedia('', 'location'), false);
  assert.equal(hasRealMedia('', 'reminder'), false);

  assert.equal(hasRealMedia('chat.photo', 'image'), true);
  assert.equal(hasRealMedia('chat.video.msg', 'video'), true);
  assert.equal(hasRealMedia('chat.voice', 'voice'), true);
  assert.equal(hasRealMedia('share.file', 'file'), true);
  assert.equal(hasRealMedia('chat.gif', 'gif'), true);
  assert.equal(hasRealMedia(3, undefined), true);
});

test('isFileMessage, extensionOf, and resolveAttachmentMimeType cover all 31 extensions and URL pathname extraction', () => {
  assert.equal(isFileMessage('share.file', 'file'), true);
  assert.equal(isFileMessage('share.doc', 'doc'), true);
  assert.equal(isFileMessage('chat.photo', 'image'), false);

  assert.equal(extensionOf('bao-gia_2026.PDF'), 'pdf');
  assert.equal(
    extensionOf('https://cdn.zalo.me/files/hop-dong.docx?token=abc#page=1'),
    'docx',
  );
  assert.equal(extensionOf('https://zalo.me'), '');
  assert.equal(extensionOf('file.toolongext'), '');

  assert.equal(Object.keys(MIME_BY_EXT).length, 31);
  for (const [ext, expectedMime] of Object.entries(MIME_BY_EXT)) {
    assert.equal(resolveAttachmentMimeType(ext, 'file'), expectedMime);
    assert.equal(resolveAttachmentMimeType(`.${ext.toUpperCase()}`, 'file'), expectedMime);
  }
  assert.equal(resolveAttachmentMimeType('unknown', 'file'), 'application/octet-stream');
  assert.equal(resolveAttachmentMimeType('unknown', 'image'), 'image/jpeg');
});

test('isAlreadyFriendErrorCode recognizes Zalo codes 222 and 225', () => {
  assert.equal(isAlreadyFriendErrorCode({ code: 222 }), true);
  assert.equal(isAlreadyFriendErrorCode({ code: '225' }), true);
  assert.equal(isAlreadyFriendErrorCode({ data: { code: 222 } }), true);
  assert.equal(isAlreadyFriendErrorCode({ code: 112 }), false);
  assert.equal(isAlreadyFriendErrorCode({ code: 600 }), false);
  assert.equal(isAlreadyFriendErrorCode(null), false);
});
