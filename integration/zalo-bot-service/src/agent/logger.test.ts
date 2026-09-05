import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { formatLogArgs, redactSecrets } from './logger.js';

describe('logger formatting', () => {
  it('joins console-style args into one line', () => {
    assert.equal(formatLogArgs(['[server]', 'started on', 28080]), '[server] started on 28080');
  });

  it('keeps an Error stack instead of printing {}', () => {
    const err = new Error('boom');
    const line = formatLogArgs(['failed:', err]);
    assert.ok(line.startsWith('failed: Error: boom'), line.slice(0, 60));
    // Stack nhiều dòng phải bị gấp lại thành một dòng, nếu không mỗi dòng stack
    // trở thành một bản ghi rời trong agent.log.
    assert.ok(!line.includes('\n'));
  });

  it('never throws on a circular object', () => {
    const circular: any = { a: 1 };
    circular.self = circular;
    assert.doesNotThrow(() => formatLogArgs([circular]));
  });

  it('redacts a JWT that reaches a console line', () => {
    const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc123';
    const out = redactSecrets(formatLogArgs(['token =', jwt]));
    assert.ok(!out.includes(jwt));
    assert.ok(out.includes('[REDACTED_JWT]'));
  });
});
