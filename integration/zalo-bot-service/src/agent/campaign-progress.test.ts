import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync, mkdirSync, existsSync } from 'fs';
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
    updateCampaign('c3', { processed: 99 }, dir);

    assert.deepEqual(listInterruptedCampaigns(dir), []);
  });

  it('treats a corrupt file as "no campaigns" instead of throwing at boot', () => {
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, 'in-flight.json'), '{"c1": {"campaig', 'utf-8');

    // Ném ở đây là backend chết ngay lúc boot rồi bị supervisor restart lặp.
    assert.doesNotThrow(() => listInterruptedCampaigns(dir));
    assert.deepEqual(listInterruptedCampaigns(dir), []);
    assert.ok(existsSync(join(dir, 'in-flight.json')));
  });
});
