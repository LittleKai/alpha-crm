import test from 'node:test';
import assert from 'node:assert/strict';
import { buildN8nEventPayload } from './n8n-event-dispatcher.js';

test('buildN8nEventPayload wraps Alpha CRM event metadata', () => {
  const payload = buildN8nEventPayload('zalo.message.inbound', {
    threadId: 'thread_1',
    content: 'hello',
  });

  assert.equal(payload.source, 'alpha_crm');
  assert.equal(payload.eventType, 'zalo.message.inbound');
  assert.equal(payload.event.threadId, 'thread_1');
  assert.match(payload.timestamp, /^\d{4}-\d{2}-\d{2}T/);
});
