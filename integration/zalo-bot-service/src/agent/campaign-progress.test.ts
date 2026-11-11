import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync, mkdirSync, existsSync, readdirSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';
import {
  beginCampaign,
  updateCampaign,
  finishCampaign,
  listInterruptedCampaigns,
} from './campaign-progress.js';

let dir: string;

describe('campaign progress', () => {
  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), 'campaign-progress-'));
  });
  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it('reports nothing when no campaign ever ran', () => {
    assert.deepEqual(listInterruptedCampaigns(dir), []);
  });

  it('survives a mid-campaign crash with the last committed progress', () => {
    beginCampaign({ campaignId: 'c1', commandId: 'cmd1', total: 500 }, dir);
    updateCampaign('c1', { processed: 213, successCount: 200, failedCount: 13 }, dir);

    // Không gọi finishCampaign — mô phỏng tiến trình bị giết ở người thứ 213.
    const [record] = listInterruptedCampaigns(dir);
    assert.equal(record!.campaignId, 'c1');
    assert.equal(record!.commandId, 'cmd1');
    assert.equal(record!.processed, 213);
    assert.equal(record!.total, 500);
    assert.equal(record!.successCount, 200);
    assert.equal(record!.failedCount, 13);
  });

  it('leaves nothing behind for a campaign that ran to completion', () => {
    beginCampaign({ campaignId: 'c2', commandId: 'cmd2', total: 2 }, dir);
    updateCampaign('c2', { processed: 2, successCount: 2 }, dir);
    finishCampaign('c2', dir);

    assert.deepEqual(listInterruptedCampaigns(dir), []);
  });

  it('tracks several campaigns independently', () => {
    beginCampaign({ campaignId: 'a', commandId: 'cmd-a', total: 10 }, dir);
    beginCampaign({ campaignId: 'b', commandId: 'cmd-b', total: 20 }, dir);
    updateCampaign('a', { processed: 4 }, dir);
    finishCampaign('b', dir);

    const records = listInterruptedCampaigns(dir);
    assert.equal(records.length, 1);
    assert.equal(records[0]!.campaignId, 'a');
    assert.equal(records[0]!.processed, 4);
  });

  it('ignores an update for a campaign that is already finished', () => {
    beginCampaign({ campaignId: 'c3', commandId: 'cmd3', total: 5 }, dir);
    finishCampaign('c3', dir);
    const updated = updateCampaign('c3', { processed: 99 }, dir);
    assert.equal(updated, false);

    assert.deepEqual(listInterruptedCampaigns(dir), []);
  });

  it('treats a corrupt file as "no campaigns" instead of throwing at boot and saves .corrupt-<ts> copy', () => {
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, 'in-flight.json'), '{"c1": {"campaig', 'utf-8');

    // Ném ở đây là backend chết ngay lúc boot rồi bị supervisor restart lặp.
    assert.doesNotThrow(() => listInterruptedCampaigns(dir));
    assert.deepEqual(listInterruptedCampaigns(dir), []);
    assert.equal(existsSync(join(dir, 'in-flight.json')), false);
    const files = readdirSync(dir);
    assert.ok(files.some((name) => name.startsWith('in-flight.json.corrupt-')));
  });

  it('persists inFlightRecipient, unknownCount, and abortedReason via atomic rename without leftover .tmp', () => {
    assert.equal(beginCampaign({ campaignId: 'c4', commandId: 'cmd4', total: 10 }, dir), true);
    assert.equal(
      updateCampaign(
        'c4',
        {
          processed: 3,
          failedCount: 2,
          unknownCount: 1,
          inFlightRecipient: { index: 3, recipientId: 'u-4', startedAt: '2026-11-10T00:00:00.000Z' },
          abortedReason: 'aborted_fail_streak',
        },
        dir,
      ),
      true,
    );

    const [record] = listInterruptedCampaigns(dir);
    assert.equal(record!.unknownCount, 1);
    assert.equal(record!.abortedReason, 'aborted_fail_streak');
    assert.deepEqual(record!.inFlightRecipient, {
      index: 3,
      recipientId: 'u-4',
      startedAt: '2026-11-10T00:00:00.000Z',
    });
    assert.equal(existsSync(join(dir, 'in-flight.json.tmp')), false);
  });

  it('normalizes legacy in-flight.json records that lack unknownCount or abortedReason', () => {
    mkdirSync(dir, { recursive: true });
    writeFileSync(
      join(dir, 'in-flight.json'),
      JSON.stringify({
        legacy1: {
          campaignId: 'legacy1',
          commandId: 'cmd-legacy',
          startedAt: '2026-11-01T00:00:00.000Z',
          updatedAt: '2026-11-01T00:01:00.000Z',
          total: 25,
          processed: 10,
          successCount: 9,
          failedCount: 1,
        },
      }),
      'utf-8',
    );
    const [record] = listInterruptedCampaigns(dir);
    assert.equal(record!.campaignId, 'legacy1');
    assert.equal(record!.unknownCount, 0);
    assert.equal(record!.abortedReason, undefined);
    assert.equal(record!.inFlightRecipient, undefined);
  });
});
