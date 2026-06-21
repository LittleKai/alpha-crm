import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildChatbotHistory,
  type ChatbotHistorySourceMessage,
} from './chatbot-history.js';

function msg(
  partial: Partial<ChatbotHistorySourceMessage> & {
    direction: 'inbound' | 'outbound';
    content: string;
  },
): ChatbotHistorySourceMessage {
  return { messageType: 'text', ...partial };
}

test('collapses consecutive same-sender messages into one turn', () => {
  const history = buildChatbotHistory(
    [
      msg({ direction: 'inbound', content: 'a1' }),
      msg({ direction: 'inbound', content: 'a2' }),
      msg({ direction: 'inbound', content: 'a3' }),
      msg({ direction: 'outbound', content: 'b1' }),
    ],
    new Set(),
    10,
  );
  assert.deepEqual(history, [
    { role: 'user', content: 'a1\na2\na3' },
    { role: 'assistant', content: 'b1' },
  ]);
});

test('keeps only the last N turns', () => {
  const history = buildChatbotHistory(
    [
      msg({ direction: 'inbound', content: 'u1' }),
      msg({ direction: 'outbound', content: 'a1' }),
      msg({ direction: 'inbound', content: 'u2' }),
      msg({ direction: 'outbound', content: 'a2' }),
    ],
    new Set(),
    2,
  );
  assert.deepEqual(history, [
    { role: 'user', content: 'u2' },
    { role: 'assistant', content: 'a2' },
  ]);
});

test('excludes the messages currently being answered and non-text/empty/deleted', () => {
  const history = buildChatbotHistory(
    [
      msg({ direction: 'inbound', content: 'old' }),
      msg({ direction: 'inbound', content: '', }),
      msg({ direction: 'inbound', content: 'img', messageType: 'image' }),
      msg({ direction: 'inbound', content: 'gone', isDeleted: true }),
      msg({ direction: 'inbound', content: 'current', providerMessageId: 'p1' }),
    ],
    new Set(['p1']),
    10,
  );
  assert.deepEqual(history, [{ role: 'user', content: 'old' }]);
});

test('returns nothing when limit is 0', () => {
  assert.deepEqual(
    buildChatbotHistory(
      [msg({ direction: 'inbound', content: 'x' })],
      new Set(),
      0,
    ),
    [],
  );
});
