import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { mergeReleaseManifest, referencedAssetNames, readVerifiedArtifact } from './release-manifest.mjs';

const asset = (name) => ({ name, browser_download_url: `https://example.test/${name}`, size: 10 });
const oldWindows = asset('alpha-crm-windows-v1.0.0.zip');
const oldAndroid = asset('alpha-crm-v1.0.0.apk');
const baseline = { tag_name: 'v1.0.0', version: '1.0.0', build_number: '1', assets: [oldWindows, oldAndroid] };
const next = { tag_name: 'v1.1.0', version: '1.1.0', build_number: '2', name: 'New', body: 'Notes' };
const windows = asset('alpha-crm-windows-v1.1.0.zip');
const android = asset('alpha-crm-v1.1.0.apk');

const partial = mergeReleaseManifest(baseline, next, { windows });
assert.equal(partial.tag_name, 'v1.0.0');
assert.deepEqual(partial.assets, baseline.assets);
assert.equal(partial.platform_releases.windows.tag_name, 'v1.1.0');
assert.equal(partial.platform_releases.android.tag_name, 'v1.0.0');
assert.deepEqual(partial.platform_releases.android.assets, [oldAndroid]);
assert(referencedAssetNames(partial).has(oldWindows.name));
assert(referencedAssetNames(partial).has(oldAndroid.name));
assert(referencedAssetNames(partial).has(windows.name));

const complete = mergeReleaseManifest(partial, next, { android });
assert.equal(complete.tag_name, 'v1.1.0');
assert.deepEqual(complete.assets, [windows, android]);
assert.throws(() => mergeReleaseManifest(partial, { ...next, build_number: '3' }, { android }), /use a new semver/);
assert.throws(() => mergeReleaseManifest({ ...baseline, build_number: undefined }, { ...next, tag_name: 'v1.0.0' }, { windows }), /use a new semver/);

const firstPartial = mergeReleaseManifest(null, next, { windows });
assert.deepEqual(firstPartial.assets, [windows]);
assert.equal(firstPartial.platform_releases.android, undefined);
const fixture = mkdtempSync(join(tmpdir(), 'crm-release-'));
try {
  const artifactPath = join(fixture, 'artifact.zip');
  const bytes = Buffer.from('validated artifact');
  const hash = createHash('sha256').update(bytes).digest('hex');
  writeFileSync(artifactPath, bytes);
  assert.deepEqual(readVerifiedArtifact(artifactPath, hash), bytes);
  writeFileSync(artifactPath, 'changed after validation');
  assert.throws(() => readVerifiedArtifact(artifactPath, hash), /changed after validation/);
  assert.throws(() => readVerifiedArtifact(artifactPath, ''), /changed after validation/);
} finally {
  rmSync(fixture, { recursive: true, force: true });
}
console.log('Release manifest safety checks passed.');
