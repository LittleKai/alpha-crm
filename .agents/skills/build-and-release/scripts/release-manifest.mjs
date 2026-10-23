import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

export function readVerifiedArtifact(filePath, expectedSha256) {
  const bytes = readFileSync(filePath);
  const actual = createHash('sha256').update(bytes).digest('hex');
  if (!expectedSha256 || actual !== expectedSha256.toLowerCase()) {
    throw new Error(`Artifact changed after validation: ${filePath}`);
  }
  return bytes;
}

export function mergeReleaseManifest(existing, release, uploaded) {
  // Artifact keys contain semver only; a different build must never overwrite those bytes.
  for (const entry of [existing, ...Object.values(existing?.platform_releases ?? {})]) {
    if (entry?.tag_name === release.tag_name &&
        String(entry.build_number ?? '') !== String(release.build_number)) {
      throw new Error('Release tag already exists with another or unknown build; use a new semver.');
    }
  }
  const platforms = { ...existing?.platform_releases };
  // Seed the legacy full release once; each platform keeps its own version and notes thereafter.
  for (const platform of ['windows', 'android']) {
    if (!platforms[platform] && existing) {
      const extensions = platform === 'windows' ? /\.zip$/i : /\.apk$/i;
      const assets = (existing.assets ?? []).filter((asset) => extensions.test(asset.name));
      if (assets.length) {
        const { platform_releases, ...metadata } = existing;
        platforms[platform] = { ...metadata, assets };
      }
    }
    if (uploaded[platform]) platforms[platform] = { ...release, assets: [uploaded[platform]] };
  }
  const complete = ['windows', 'android'].every((platform) =>
    platforms[platform]?.tag_name === release.tag_name &&
    String(platforms[platform]?.build_number) === String(release.build_number));
  // ponytail: legacy clients see partial upgrades after both platforms catch up; new clients read platform_releases.
  const baseline = complete || !existing
    ? { ...release, assets: Object.values(platforms).flatMap((entry) => entry.assets) }
    : existing;
  return { ...baseline, platform_releases: platforms };
}

export function referencedAssetNames(manifest) {
  return new Set([
    ...(manifest.assets ?? []),
    ...Object.values(manifest.platform_releases ?? {}).flatMap((entry) => entry.assets ?? []),
  ].map((asset) => asset.name));
}
