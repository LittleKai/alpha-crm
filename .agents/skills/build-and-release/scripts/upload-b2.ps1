<#
.SYNOPSIS
    Upload Alpha CRM Windows ZIP + Android APK + version.json to Backblaze B2 (alpha-studio bucket).

.DESCRIPTION
    Uploads built artifacts to Backblaze B2 under crm-app/releases/ and updates crm-app/version.json:
      - crm-app/releases/alpha-crm-windows.zip
      - crm-app/releases/alpha-crm-v<version>.apk
      - crm-app/version.json
    Keeps per-platform release metadata; a partial upload preserves the legacy full-release manifest,
    and cleans up old releases on B2 (retaining the 3 newest versions).

.PARAMETER Version
    Version/tag string (e.g. "v0.2.2" or "0.2.2").

.PARAMETER ZipPath
    Explicit Windows ZIP to upload, selected only when windows is in Targets.

.PARAMETER ApkPath
    Explicit Android APK to upload, selected only when android is in Targets.

.PARAMETER Targets
    Platforms to publish. Defaults to explicit paths when supplied, otherwise windows,android.
    Selected platforms without an explicit path use only their exact build/release/ filename.

.PARAMETER Title
    Release title stored in version.json (default: "Alpha CRM v<version>").

.PARAMETER Notes
    Release notes (string or path to a UTF-8 file) stored in version.json.

.PARAMETER ReleaseUrl
    GitHub release html_url stored in version.json.

.PARAMETER PublishedAt
    ISO-8601 publish timestamp. Default: now (UTC).
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$ZipPath = "",

    [string]$ApkPath = "",

    [string]$Targets = "",

    [string]$Title = "",

    [string]$Notes = "",

    [string]$ReleaseUrl = "",

    [string]$PublishedAt = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'release-artifacts.ps1')

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# --- Resolve paths ---

$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
if (-not (Test-Path (Join-Path $ProjectRoot "pubspec.yaml"))) {
    $ProjectRoot = (Get-Location).Path
}
if (-not (Test-Path (Join-Path $ProjectRoot "pubspec.yaml"))) {
    Write-Err "Could not find pubspec.yaml. Please run script from tools/alpha-crm root."
    exit 1
}

$BackendDir = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot "..\..\alpha-studio-backend"))
if (-not (Test-Path $BackendDir)) {
    Write-Err "Could not find alpha-studio-backend at: $BackendDir"
    exit 1
}

Set-Location $ProjectRoot

$SemVer = $Version -replace '^v', ''
$TagVersion = "v$SemVer"

if (-not $Title) {
    $Title = "Alpha CRM $TagVersion"
}

$NotesFile = ""
if ($Notes -and (Test-Path -LiteralPath $Notes -PathType Leaf)) {
    $NotesFile = (Resolve-Path -LiteralPath $Notes).Path
    $Notes = Get-Content -LiteralPath $Notes -Raw -Encoding UTF8
} elseif (-not $Notes) {
    $Notes = "Bản phát hành tự động Alpha CRM $TagVersion"
}

if (-not $PublishedAt) {
    $PublishedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

# Resolve only the requested platforms, and validate embedded metadata before credentials/network.
if (-not $Targets) {
    $ExplicitTargets = @()
    if ($ZipPath) { $ExplicitTargets += 'windows' }
    if ($ApkPath) { $ExplicitTargets += 'android' }
    $Targets = if ($ExplicitTargets.Count) { $ExplicitTargets -join ',' } else { 'windows,android' }
}
$PubspecRaw = Get-Content -LiteralPath (Join-Path $ProjectRoot 'pubspec.yaml') -Raw -Encoding UTF8
if ($PubspecRaw -notmatch '(?m)^version:\s*([^\s+]+)\+(\d+)') { throw 'Could not parse pubspec.yaml version.' }
if ($Matches[1] -ne $SemVer) { throw "Requested version $SemVer does not match pubspec.yaml $($Matches[1])." }
$BuildNum = $Matches[2]
$Artifacts = @(Get-ReleaseArtifacts -ProjectRoot $ProjectRoot -Version $SemVer -Build $BuildNum -Targets $Targets -ZipPath $ZipPath -ApkPath $ApkPath)
$WindowsArtifact = $Artifacts | Where-Object Extension -eq '.zip'
$AndroidArtifact = $Artifacts | Where-Object Extension -eq '.apk'

Write-Step "Uploading Alpha CRM $TagVersion artifacts to Backblaze B2"

$env:CRM_B2_PROJECT_ROOT = $ProjectRoot
$env:CRM_B2_BACKEND_DIR  = $BackendDir
$env:CRM_B2_SEMVER       = $SemVer
$env:CRM_B2_BUILD        = $BuildNum
$env:CRM_B2_TAG          = $TagVersion
$env:CRM_B2_TITLE        = $Title
$env:CRM_B2_NOTES        = $Notes
$env:CRM_B2_NOTES_FILE   = $NotesFile
$env:CRM_B2_RELEASE_URL  = $ReleaseUrl
$env:CRM_B2_PUBLISHED_AT = $PublishedAt
$env:CRM_B2_ZIP_PATH     = if ($WindowsArtifact) { $WindowsArtifact.FullName } else { '' }
$env:CRM_B2_APK_PATH     = if ($AndroidArtifact) { $AndroidArtifact.FullName } else { '' }
$env:CRM_B2_ZIP_SHA256   = if ($WindowsArtifact) { $WindowsArtifact.ReleaseSha256 } else { '' }
$env:CRM_B2_APK_SHA256   = if ($AndroidArtifact) { $AndroidArtifact.ReleaseSha256 } else { '' }
$env:CRM_B2_MANIFEST_HELPER = Join-Path $PSScriptRoot 'release-manifest.mjs'

$NodeUploadScript = @'
import fs from 'fs';
import path from 'path';
import { pathToFileURL } from 'node:url';
import dotenv from 'dotenv';
import { S3Client, PutObjectCommand, GetObjectCommand, CopyObjectCommand, ListObjectsV2Command, DeleteObjectsCommand } from '@aws-sdk/client-s3';
const { mergeReleaseManifest, referencedAssetNames, readVerifiedArtifact } = await import(pathToFileURL(process.env.CRM_B2_MANIFEST_HELPER));

const projectRoot = process.env.CRM_B2_PROJECT_ROOT;
const backendDir = process.env.CRM_B2_BACKEND_DIR;

const rootEnv = path.join(projectRoot, '.env');
const backendEnv = path.join(backendDir, '.env');
if (fs.existsSync(backendEnv)) dotenv.config({ path: backendEnv });
if (fs.existsSync(rootEnv)) dotenv.config({ path: rootEnv, override: true });

const {
  B2_ENDPOINT,
  B2_REGION = 'us-west-004',
  B2_ACCESS_KEY_ID,
  B2_SECRET_ACCESS_KEY,
  B2_BUCKET_NAME,
  CDN_BASE_URL,
} = process.env;

if (!B2_ENDPOINT || !B2_ACCESS_KEY_ID || !B2_SECRET_ACCESS_KEY || !B2_BUCKET_NAME || !CDN_BASE_URL) {
  console.error('[ERROR] Missing B2_* or CDN_BASE_URL credentials in .env!');
  process.exit(1);
}

const cdnBase = CDN_BASE_URL.replace(/\/+$/, '');
const semver = process.env.CRM_B2_SEMVER;
const tag = process.env.CRM_B2_TAG;
const title = process.env.CRM_B2_TITLE;
const notes = (process.env.CRM_B2_NOTES_FILE && fs.existsSync(process.env.CRM_B2_NOTES_FILE))
  ? fs.readFileSync(process.env.CRM_B2_NOTES_FILE, 'utf8')
  : (process.env.CRM_B2_NOTES || '');
const releaseUrl = process.env.CRM_B2_RELEASE_URL || '';
const publishedAt = process.env.CRM_B2_PUBLISHED_AT || new Date().toISOString();
const zipPath = process.env.CRM_B2_ZIP_PATH;
const apkPath = process.env.CRM_B2_APK_PATH;
// Read and bind all upload bytes before the first remote operation.
const zipBuffer = zipPath ? readVerifiedArtifact(zipPath, process.env.CRM_B2_ZIP_SHA256) : null;
const apkBuffer = apkPath ? readVerifiedArtifact(apkPath, process.env.CRM_B2_APK_SHA256) : null;

const s3 = new S3Client({
  endpoint: B2_ENDPOINT,
  region: B2_REGION,
  credentials: {
    accessKeyId: B2_ACCESS_KEY_ID,
    secretAccessKey: B2_SECRET_ACCESS_KEY,
  },
  forcePathStyle: true,
  requestChecksumCalculation: 'WHEN_REQUIRED',
  responseChecksumValidation: 'WHEN_REQUIRED',
});

const versionKey = 'crm-app/version.json';

const streamToString = (stream) =>
  new Promise((resolve, reject) => {
    const chunks = [];
    stream.on('data', (c) => chunks.push(c));
    stream.on('error', reject);
    stream.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
  });

async function cleanupOldReleases(manifest) {
  console.log('\nCleaning up old releases on B2 (keeping 3 newest versions)...');
  try {
    const listRes = await s3.send(new ListObjectsV2Command({
      Bucket: B2_BUCKET_NAME,
      Prefix: 'crm-app/releases/',
    }));
    if (!listRes.Contents || listRes.Contents.length === 0) return;

    const fileRegex = /^crm-app\/releases\/alpha-crm-(?:windows-)?v([\d.]+)\.(?:apk|zip)$/;
    const fileVersionMap = [];
    for (const item of listRes.Contents) {
      const m = item.Key.match(fileRegex);
      if (m) fileVersionMap.push({ key: item.Key, version: m[1] });
    }

    const uniqueVersions = Array.from(new Set(fileVersionMap.map((x) => x.version)));
    if (uniqueVersions.length <= 3) {
      console.log(`Found ${uniqueVersions.length} version(s) on B2; no cleanup needed.`);
      return;
    }

    uniqueVersions.sort((v1, v2) => {
      const p1 = v1.split('.').map(Number);
      const p2 = v2.split('.').map(Number);
      for (let i = 0; i < 3; i++) {
        const diff = (p1[i] || 0) - (p2[i] || 0);
        if (diff !== 0) return diff;
      }
      return 0;
    });

    const deleteVersions = uniqueVersions.slice(0, -3);
    const protectedNames = referencedAssetNames(manifest);
    const deleteKeys = fileVersionMap
      .filter((x) => deleteVersions.includes(x.version) && !protectedNames.has(path.posix.basename(x.key)))
      .map((x) => ({ Key: x.key }));

    if (deleteKeys.length > 0) {
      await s3.send(new DeleteObjectsCommand({
        Bucket: B2_BUCKET_NAME,
        Delete: { Objects: deleteKeys, Quiet: true },
      }));
      console.log(`[OK] Deleted ${deleteKeys.length} old build file(s) from B2.`);
    }
  } catch (err) {
    console.warn('[WARN] Failed to clean up old B2 releases:', err.message);
  }
}

async function main() {
  let existing = null;
  try {
    const getRes = await s3.send(new GetObjectCommand({ Bucket: B2_BUCKET_NAME, Key: versionKey }));
    existing = JSON.parse(await streamToString(getRes.Body));
    console.log(`Loaded existing version.json (${existing.tag_name}).`);
  } catch (error) {
    if (error.name !== 'NoSuchKey' && error.$metadata?.httpStatusCode !== 404) throw error;
    console.log('No existing version.json found — creating a fresh one.');
  }

  const uploaded = {};
  const releaseMetadata = {
    tag_name: tag,
    version: semver,
    build_number: process.env.CRM_B2_BUILD,
    name: title,
    body: notes,
    ...(releaseUrl ? { html_url: releaseUrl } : {}),
    published_at: publishedAt,
  };
  // Check immutable semver/build identity before uploading any bytes.
  mergeReleaseManifest(existing, releaseMetadata, {});

  if (apkBuffer) {
    const apkKey = `crm-app/releases/alpha-crm-v${semver}.apk`;
    const apkUrl = `${cdnBase}/${apkKey}`;
    console.log(`Uploading Android APK: ${apkKey} (${(apkBuffer.length / 1024 / 1024).toFixed(2)} MB)...`);
    await s3.send(new PutObjectCommand({
      Bucket: B2_BUCKET_NAME,
      Key: apkKey,
      Body: apkBuffer,
      ContentType: 'application/vnd.android.package-archive',
    }));
    console.log(`[OK] APK -> ${apkUrl}`);
    uploaded.android = {
      name: `alpha-crm-v${semver}.apk`,
      browser_download_url: apkUrl,
      size: apkBuffer.length,
    };
  }

  if (zipBuffer) {
    const winVersionedName = `alpha-crm-windows-v${semver}.zip`;
    const winVersionedKey = `crm-app/releases/${winVersionedName}`;
    const winUrl = `${cdnBase}/${winVersionedKey}`;
    console.log(`Uploading Windows ZIP: ${winVersionedKey} (${(zipBuffer.length / 1024 / 1024).toFixed(2)} MB)...`);
    await s3.send(new PutObjectCommand({
        Bucket: B2_BUCKET_NAME,
        Key: winVersionedKey,
        Body: zipBuffer,
        ContentType: 'application/zip',
      }));
    console.log(`[OK] Windows ZIP -> ${winUrl}`);
    uploaded.windows = {
      name: winVersionedName,
      browser_download_url: winUrl,
      size: zipBuffer.length,
    };
  }

  const versionJson = mergeReleaseManifest(existing, releaseMetadata, uploaded);

  // Preserve a legacy static URL's bytes during a partial release.
  if (versionJson.tag_name === tag &&
      versionJson.platform_releases.windows?.tag_name === tag &&
      versionJson.platform_releases.windows?.build_number === process.env.CRM_B2_BUILD &&
      versionJson.platform_releases.android?.tag_name === tag &&
      versionJson.platform_releases.android?.build_number === process.env.CRM_B2_BUILD) {
    await s3.send(zipBuffer ? new PutObjectCommand({
      Bucket: B2_BUCKET_NAME,
      Key: 'crm-app/releases/alpha-crm-windows.zip',
      Body: zipBuffer,
      ContentType: 'application/zip',
    }) : new CopyObjectCommand({
      Bucket: B2_BUCKET_NAME,
      Key: 'crm-app/releases/alpha-crm-windows.zip',
      CopySource: `${B2_BUCKET_NAME}/crm-app/releases/alpha-crm-windows-v${semver}.zip`,
    }));
  }

  await s3.send(new PutObjectCommand({
    Bucket: B2_BUCKET_NAME,
    Key: versionKey,
    Body: JSON.stringify(versionJson, null, 2),
    ContentType: 'application/json',
  }));
  console.log(`[OK] version.json -> ${cdnBase}/${versionKey}`);

  await cleanupOldReleases(versionJson);

  console.log('\n========================================');
  console.log(' B2 upload completed!');
  console.log('========================================');
  for (const a of versionJson.assets) {
    console.log(`  ${a.name}: ${a.browser_download_url}`);
  }
  console.log(`Manifest    : ${cdnBase}/${versionKey}`);
  console.log(`Studio page : https://giaiphapsangtao.com/studio/crm/subscription`);
}

main().catch((err) => {
  console.error('[ERROR] B2 upload failed:', err.message);
  process.exit(1);
});
'@

Push-Location $BackendDir
try {
    & node --input-type=module -e $NodeUploadScript
    if ($LASTEXITCODE -ne 0) {
        exit 1
    }
} finally {
    Pop-Location
}
