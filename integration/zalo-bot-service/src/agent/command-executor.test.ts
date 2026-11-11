import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { listInterruptedCampaigns } from './campaign-progress.js';
import {
  runCampaignInBackgroundForTest,
  validateZaloSendPayloadForTest,
  withSendTimeoutForTest,
} from './command-executor.js';

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

test('withSendTimeoutForTest rejects with SEND_TIMEOUT and marks wrapper dead', async () => {
  const hung = new Promise<string>(() => {});
  const { promise, isDead } = withSendTimeoutForTest(hung, 20, 'test-send');
  assert.equal(isDead(), false);
  await assert.rejects(
    promise,
    (err: any) => err?.code === 'SEND_TIMEOUT' && /test-send/.test(err.message),
  );
  assert.equal(isDead(), true);
});

test('campaign runner checkpoints inFlightRecipient before send, retries RATE_LIMITED once, and records unknown on timeout', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'cmd-exec-test-'));
  try {
    const inFlightSeenDuringSend: Array<string | undefined> = [];
    const sleepCalls: number[] = [];
    let u2Attempts = 0;
    let finalReport: any = null;

    await runCampaignInBackgroundForTest(
      {
        _id: 'cmd-1',
        type: 'crm.campaign.execute',
        payload: {
          campaignId: 'camp-1',
          message: 'Xin chào {{name}}',
          recipients: [
            { customerId: 'c1', phone: 'u1', name: 'A' },
            { customerId: 'c2', phone: 'u2', name: 'B' },
            { customerId: 'c3', phone: 'u3', name: 'C' },
          ],
        },
      },
      'dev-1',
      'sec-1',
      {
        progressDir: dir,
        sendTimeoutMs: 25,
        sleepMs: async (ms) => {
          sleepCalls.push(ms);
        },
        evaluateCompliance: () => ({ allowed: true }),
        reportCommandProgress: async () => {},
        reportCommandResult: async (_dev, _sec, _cmd, success, result) => {
          finalReport = { success, result };
        },
        sendMessage: async (req) => {
          const [rec] = listInterruptedCampaigns(dir);
          inFlightSeenDuringSend.push(rec?.inFlightRecipient?.recipientId);
          assert.equal((req.metadata as any)?.source, 'campaign');
          if (req.recipientId === 'u1') {
            return { success: true, messageId: 'm1' };
          }
          if (req.recipientId === 'u2') {
            u2Attempts++;
            if (u2Attempts === 1) {
              return {
                success: false,
                error: 'rate limited',
                errorCode: 'RATE_LIMITED',
                retryAfterMs: 120,
              };
            }
            return { success: true, messageId: 'm2' };
          }
          // u3 hangs -> SEND_TIMEOUT -> status: 'unknown'
          return new Promise(() => {});
        },
      },
    );

    assert.deepEqual(inFlightSeenDuringSend, ['u1', 'u2', 'u2', 'u3']);
    assert.ok(sleepCalls.includes(120));
    assert.ok(finalReport);
    assert.equal(finalReport.success, false);
    assert.equal(finalReport.result.unknownCount, 1);
    assert.deepEqual(
      finalReport.result.results.map((r: any) => ({ phone: r.phone, status: r.status })),
      [
        { phone: 'u1', status: 'succeeded' },
        { phone: 'u2', status: 'succeeded' },
        { phone: 'u3', status: 'unknown' },
      ],
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('campaign circuit breaker aborts after 5 consecutive failures and marks remaining recipients cancelled', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'cmd-exec-cb-'));
  try {
    let sendCalls = 0;
    let finalReport: any = null;
    const progressReports: any[] = [];

    const recipients = Array.from({ length: 8 }, (_, idx) => ({
      customerId: `c${idx + 1}`,
      phone: `u${idx + 1}`,
      name: `User ${idx + 1}`,
    }));

    await runCampaignInBackgroundForTest(
      {
        _id: 'cmd-cb',
        type: 'crm.campaign.execute',
        payload: {
          campaignId: 'camp-cb',
          message: 'Hello',
          recipients,
        },
      },
      'dev-1',
      'sec-1',
      {
        progressDir: dir,
        sleepMs: async () => {},
        evaluateCompliance: () => ({ allowed: true }),
        reportCommandProgress: async (_d, _s, _c, progress) => {
          progressReports.push(progress);
        },
        reportCommandResult: async (_d, _s, _c, success, result) => {
          finalReport = { success, result };
        },
        sendMessage: async () => {
          sendCalls++;
          return { success: false, error: 'Zalo error' };
        },
      },
    );

    assert.equal(sendCalls, 5);
    assert.equal(finalReport.success, false);
    assert.equal(finalReport.result.abortedReason, 'aborted_fail_streak');
    assert.equal(finalReport.result.results.length, 8);
    assert.equal(
      finalReport.result.results.filter((r: any) => r.status === 'failed').length,
      5,
    );
    assert.equal(
      finalReport.result.results.filter((r: any) => r.status === 'cancelled').length,
      3,
    );
    assert.equal(progressReports.at(-1)?.abortedReason, 'aborted_fail_streak');
    assert.equal(progressReports.at(-1)?.cancelledCount, 3);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
