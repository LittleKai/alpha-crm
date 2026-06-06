import assert from 'node:assert/strict';
import test from 'node:test';

import { LocalChatEventBus } from './local-chat-events.js';

test('event bus filters subscribers and replays events after a cursor', () => {
  const bus = new LocalChatEventBus(10);
  const received: string[] = [];

  const unsubscribe = bus.subscribe(
    (event) => received.push(event.type),
    { accountId: 'acc1', threadId: 'thread1' },
  );

  const first = bus.publish({
    type: 'message.created',
    accountId: 'acc1',
    threadId: 'thread1',
    data: { messageId: 'm1' },
  });
  bus.publish({
    type: 'typing.started',
    accountId: 'acc2',
    threadId: 'thread1',
    data: { userId: 'u2' },
  });
  bus.publish({
    type: 'message.seen',
    accountId: 'acc1',
    threadId: 'thread1',
    data: { messageId: 'm1' },
  });
  unsubscribe();

  assert.deepEqual(received, ['message.created', 'message.seen']);
  assert.deepEqual(
    bus.replayAfter(first.id, { accountId: 'acc1', threadId: 'thread1' }).map((event) => event.type),
    ['message.seen'],
  );
});
