<#
.SYNOPSIS
    Build Alpha CRM Windows (ZIP + bundled Zalo backend) and/or Android (APK) release.

.DESCRIPTION
    Delegates to alpha-studio-backend/scripts/release-to-b2.js with --no-upload so that:
    - Version in pubspec.yaml is updated (unless -SkipVersionUpdate or Version="none")
    - Android APK is built (flutter build apk --release)
    - Windows EXE is built (flutter build windows --release)
    - Local Zalo backend (integration/zalo-bot-service) is bundled via esbuild (dist/server.cjs)
    - Pinned Node LTS runtime (v22.23.2, ABI 127) + matching better-sqlite3 native addon are staged
    - Staged backend is smoke-tested on port 8799 (/health + /local/health SQLite probe)
    - Output artifacts are staged into build/release/

.PARAMETER Version
    Version action ("patch", "minor", "major", "none") or explicit semver ("0.2.2" or "v0.2.2").

.PARAMETER Targets
    Comma-separated build targets: "windows", "android" (default: "windows,android").

.PARAMETER SkipVersionUpdate
    Keep current version in pubspec.yaml without bumping.

.PARAMETER SkipApkBuild
    Reuse existing build/app/outputs/flutter-apk/app-release.apk if present.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$Version = "none",

    [string]$Targets = "windows,android",

    [switch]$SkipVersionUpdate,

    [switch]$SkipApkBuild
)

$ErrorActionPreference = "Stop"

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
$ReleaseToB2Script = Join-Path $BackendDir "scripts\release-to-b2.js"
if (-not (Test-Path $ReleaseToB2Script)) {
    Write-Err "Could not find release-to-b2.js at: $ReleaseToB2Script"
    exit 1
}

Set-Location $ProjectRoot

# --- Parse targets ---

$TargetList = $Targets.Split(',') | ForEach-Object { $_.Trim().ToLower() }
$WantWindows = $TargetList -contains "windows"
$WantAndroid = ($TargetList -contains "android") -or ($TargetList -contains "apk")

if (-not $WantWindows -and -not $WantAndroid) {
    Write-Err "Invalid -Targets '$Targets'. Specify 'windows', 'android', or 'windows,android'."
    exit 1
}

# --- Guard against CMake generator platform mismatch (Fixed Bug #20) ---

if ($WantWindows) {
    $CmakeCache = Join-Path $ProjectRoot "build\windows\x64\CMakeCache.txt"
    if (Test-Path $CmakeCache) {
        $CacheContent = Get-Content $CmakeCache -Raw -ErrorAction SilentlyContinue
        if ($CacheContent -match 'CMAKE_GENERATOR_PLATFORM:INTERNAL=(.*)') {
            $GenPlatform = $Matches[1].Trim()
            if ($GenPlatform -ne "x64") {
                Write-Step "Cleaning stale build/windows (CMAKE_GENERATOR_PLATFORM='$GenPlatform')"
                Remove-Item (Join-Path $ProjectRoot "build\windows") -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# --- Resolve version action for release-to-b2.js ---

$PubspecPath = Join-Path $ProjectRoot "pubspec.yaml"
$PubspecRaw = Get-Content $PubspecPath -Raw -Encoding UTF8
$CurrentSemVer = "0.0.0"
$CurrentBuild = "1"
if ($PubspecRaw -match '(?m)^version:\s*([^\s+]+)\+(\d+)') {
    $CurrentSemVer = $Matches[1]
    $CurrentBuild = $Matches[2]
}

if ($SkipVersionUpdate -or (-not $Version) -or ($Version -in @("none", "skip", "current", "nobump"))) {
    $ActionArg = "none"
} elseif ($Version -in @("patch", "minor", "major")) {
    $ActionArg = $Version
} else {
    $CleanedVer = $Version -replace '^v', ''
    if ($CleanedVer -eq $CurrentSemVer -and $SkipVersionUpdate) {
        $ActionArg = "none"
    } else {
        $ActionArg = $CleanedVer
    }
}

Write-Host "Project root    : $ProjectRoot"
Write-Host "Backend dir     : $BackendDir"
Write-Host "Current version : $CurrentSemVer+$CurrentBuild"
Write-Host "Version action  : $ActionArg"
Write-Host "Targets         : $Targets"

# --- Run release-to-b2.js in local build mode (--no-upload) ---

Write-Step "Running Alpha CRM build pipeline (release-to-b2.js --no-upload)"

$NodeArgs = @($ReleaseToB2Script, $ActionArg, "--no-upload")
if ($WantWindows -and -not $WantAndroid) {
    $NodeArgs += "--windows"
} elseif ($WantAndroid -and -not $WantWindows) {
    $NodeArgs += "--android"
}
if ($SkipApkBuild) {
    $NodeArgs += "--skip-apk-build"
}

Push-Location $BackendDir
try {
    & node @NodeArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Err "release-to-b2.js local build failed (exit code $LASTEXITCODE)!"
        exit 1
    }
} finally {
    Pop-Location
}

# --- Read resulting version from pubspec.yaml ---

$UpdatedPubspec = Get-Content $PubspecPath -Raw -Encoding UTF8
if ($UpdatedPubspec -match '(?m)^version:\s*([^\s+]+)\+(\d+)') {
    $FinalSemVer = $Matches[1]
    $FinalBuild = $Matches[2]
} else {
    Write-Err "Could not parse updated version from pubspec.yaml"
    exit 1
}

Write-Success "Active version: $FinalSemVer+$FinalBuild"

# --- Stage artifacts into build/release/ ---

$ReleaseDir = Join-Path $ProjectRoot "build\release"
if (-not (Test-Path $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
}

if ($WantWindows) {
    $ZipSrc = Join-Path $ProjectRoot "build\alpha-crm-windows.zip"
    if (-not (Test-Path $ZipSrc)) {
        Write-Err "Expected Windows ZIP not found at $ZipSrc"
        exit 1
    }
    $ZipDest = Join-Path $ReleaseDir "alpha-crm-windows.zip"
    Copy-Item $ZipSrc $ZipDest -Force
    $ZipSize = [math]::Round((Get-Item $ZipDest).Length / 1MB, 2)
    Write-Success "Staged Windows ZIP: $ZipDest ($ZipSize MB)"
}

if ($WantAndroid) {
    $ApkSrc = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-release.apk"
    if (-not (Test-Path $ApkSrc)) {
        Write-Err "Expected Android APK not found at $ApkSrc"
        exit 1
    }
    # Remove older APK versions in build/release/ so only the active version is uploaded
    Get-ChildItem $ReleaseDir -Filter "alpha-crm-v*.apk" -ErrorAction SilentlyContinue | Remove-Item -Force
    $ApkDest = Join-Path $ReleaseDir "alpha-crm-v$FinalSemVer.apk"
    Copy-Item $ApkSrc $ApkDest -Force
    $ApkSize = [math]::Round((Get-Item $ApkDest).Length / 1MB, 2)
    Write-Success "Staged Android APK: $ApkDest ($ApkSize MB)"
}

# --- Summary ---

Write-Step "Build completed!"

$Artifacts = Get-ChildItem $ReleaseDir -File
Write-Host "Artifacts in build/release/:" -ForegroundColor Yellow
foreach ($f in $Artifacts) {
    $Size = [math]::Round($f.Length / 1MB, 2)
    Write-Host "  - $($f.Name)  ($Size MB)"
}

Write-Host ""
Write-Host "Next step: run release.ps1 -Version $FinalSemVer -SkipBuild to publish to GitHub & Backblaze B2." -ForegroundColor Cyan
