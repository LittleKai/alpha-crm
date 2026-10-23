<#
.SYNOPSIS
    Build, tag, create GitHub Release, and upload Alpha CRM artifacts to GitHub + Backblaze B2.

.DESCRIPTION
    - Run build.ps1 (unless -SkipBuild) to bump pubspec.yaml, build APK & Windows ZIP + Zalo backend bundle, and smoke-test
    - Commit pubspec.yaml version bump if modified
    - Push current branch and tag v<version> to origin
    - Create/update GitHub Release on LittleKai/alpha-crm and upload artifacts from build/release/
    - Run upload-b2.ps1 to publish artifacts and crm-app/version.json to Backblaze B2

.PARAMETER Version
    Version action ("patch", "minor", "major", "none") or explicit version/tag ("0.2.2" or "v0.2.2").

.PARAMETER Title
    Release title on GitHub and in version.json (default: "Alpha CRM v<version>").

.PARAMETER Notes
    Release notes (string or path to a UTF-8 file).

.PARAMETER Targets
    Comma-separated build targets: "windows", "android" (default: "windows,android").

.PARAMETER Prerelease
    Mark GitHub Release as prerelease.

.PARAMETER Draft
    Create GitHub Release as draft.

.PARAMETER SkipBuild
    Skip build step and use existing artifacts in build/release/.

.PARAMETER SkipB2
    Skip Backblaze B2 upload step (GitHub Release only).

.PARAMETER SkipGitHub
    Skip GitHub Release step (Backblaze B2 only).

.PARAMETER SkipApkBuild
    Reuse existing Android APK during build.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$Version = "patch",

    [string]$Title = "",

    [string]$Notes = "",

    [string]$Targets = "windows,android",

    [switch]$Prerelease,

    [switch]$Draft,

    [switch]$SkipBuild,

    [switch]$SkipB2,

    [switch]$SkipGitHub,

    [switch]$SkipApkBuild
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

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
Set-Location $ProjectRoot

# --- Build (if needed) ---

$ReleaseDir = Join-Path $ProjectRoot "build\release"

if (-not $SkipBuild) {
    Write-Step "Running build script"
    $BuildScript = Join-Path $PSScriptRoot "build.ps1"
    $BuildParams = @{
        Version = $Version
        Targets = $Targets
    }
    if ($SkipApkBuild) {
        $BuildParams["SkipApkBuild"] = $true
    }
    & $BuildScript @BuildParams
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Build failed!"
        exit 1
    }
}

# --- Read active version from pubspec.yaml ---

$PubspecPath = Join-Path $ProjectRoot "pubspec.yaml"
$PubspecRaw = Get-Content $PubspecPath -Raw -Encoding UTF8
if ($PubspecRaw -match '(?m)^version:\s*([^\s+]+)\+(\d+)') {
    $SemVer = $Matches[1]
    $BuildNum = $Matches[2]
} else {
    Write-Err "Could not parse version from pubspec.yaml"
    exit 1
}

$TagVersion = "v$SemVer"

if (-not $Title) {
    $Title = "Alpha CRM $TagVersion"
}

if ($Notes -and (Test-Path -LiteralPath $Notes -PathType Leaf)) {
    $NotesContent = Get-Content -LiteralPath $Notes -Raw -Encoding UTF8
} elseif ($Notes) {
    $NotesContent = $Notes
} else {
    $NotesContent = "Bản phát hành tự động Alpha CRM $TagVersion"
}

# --- Verify artifacts ---

Write-Step "Checking artifacts in build/release/"

if (-not (Test-Path $ReleaseDir)) {
    Write-Err "Directory build/release/ does not exist. Run build.ps1 first!"
    exit 1
}

$Artifacts = Get-ChildItem $ReleaseDir -File
if ($Artifacts.Count -eq 0) {
    Write-Err "No artifacts found in build/release/"
    exit 1
}

Write-Host "Artifacts to publish ($TagVersion+$BuildNum):" -ForegroundColor Yellow
foreach ($f in $Artifacts) {
    $Size = [math]::Round($f.Length / 1MB, 2)
    Write-Host "  - $($f.Name)  ($Size MB)"
}

# --- Commit pubspec.yaml if modified by version bump ---

$PubspecStatus = (git status --porcelain -- pubspec.yaml 2>$null)
if ($PubspecStatus) {
    Write-Step "Committing version bump in pubspec.yaml"
    git add pubspec.yaml
    git commit -m "chore(release): bump version to $SemVer+$BuildNum"
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to commit pubspec.yaml version bump!"
        exit 1
    }
    Write-Success "Committed pubspec.yaml ($SemVer+$BuildNum)"
}

# --- Push current branch to origin ---

Write-Step "Pushing current branch to origin"

$CurrentBranch = (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
if ($CurrentBranch -and $CurrentBranch -ne "HEAD") {
    Write-Host "Pushing branch '$CurrentBranch' to origin..."
    git push origin $CurrentBranch
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Push branch $CurrentBranch failed!"
        exit 1
    }
    Write-Success "Branch '$CurrentBranch' pushed to origin"
} else {
    Write-Host "Detached HEAD or could not detect branch name, skipping branch push."
}

# --- Create & push git tag ---

Write-Step "Creating & pushing git tag: $TagVersion"

$ExistingTag = git tag -l $TagVersion 2>$null
if ($ExistingTag) {
    Write-Host "Tag $TagVersion already exists locally, skipping tag creation."
} else {
    git tag -a $TagVersion -m "Release $TagVersion"
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Creating git tag failed!"
        exit 1
    }
    Write-Success "Tag $TagVersion created"
}

git push origin $TagVersion
if ($LASTEXITCODE -ne 0) {
    Write-Err "Push tag $TagVersion failed!"
    exit 1
}
Write-Success "Tag $TagVersion pushed to origin"

# --- GitHub Release ---

$HtmlUrl = ""

if ($SkipGitHub) {
    Write-Host ""
    Write-Host "[SKIP] GitHub Release skipped (-SkipGitHub)." -ForegroundColor Yellow
} else {
    Write-Step "Reading GITHUB_TOKEN"

    $Token = $null
    $EnvCandidates = @(
        (Join-Path $ProjectRoot ".env"),
        (Join-Path $BackendDir ".env")
    )
    foreach ($EnvFile in $EnvCandidates) {
        if ((-not $Token) -and (Test-Path $EnvFile)) {
            Get-Content $EnvFile | ForEach-Object {
                if ($_ -match '^\s*GITHUB_TOKEN\s*=\s*(.+)\s*$') {
                    $Token = $Matches[1].Trim().Trim('"').Trim("'")
                }
            }
        }
    }

    if (-not $Token) {
        Write-Err "Could not find GITHUB_TOKEN in .env or ../../alpha-studio-backend/.env"
        exit 1
    }
    Write-Success "GITHUB_TOKEN loaded"

    $RemoteUrl = git remote get-url origin 2>$null
    if ($RemoteUrl -match 'github\.com[:/]([^/]+)/([^/.]+?)(?:\.git)?$') {
        $Owner = $Matches[1]
        $Repo = $Matches[2]
    } else {
        Write-Err "Could not parse owner/repo from git remote origin: $RemoteUrl"
        exit 1
    }

    Write-Step "Creating or updating GitHub Release ($Owner/$Repo @ $TagVersion)"

    $Headers = @{
        "Authorization"        = "Bearer $Token"
        "Accept"               = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }

    $ReleaseId = $null
    $ExistingAssets = @()
    $GetReleaseUrl = "https://api.github.com/repos/$Owner/$Repo/releases/tags/$TagVersion"

    try {
        $ExistingRelease = Invoke-RestMethod -Uri $GetReleaseUrl -Method GET -Headers $Headers
        $ReleaseId = $ExistingRelease.id
        $HtmlUrl = $ExistingRelease.html_url
        $ExistingAssets = $ExistingRelease.assets
        Write-Host "Found existing GitHub Release $TagVersion (ID: $ReleaseId)" -ForegroundColor Yellow

        if ($NotesContent) {
            $PatchJson = (@{ name = $Title; body = $NotesContent } | ConvertTo-Json -Depth 3)
            $PatchBytes = [System.Text.Encoding]::UTF8.GetBytes($PatchJson)
            Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/releases/$ReleaseId" `
                -Method PATCH -Headers $Headers -Body $PatchBytes -ContentType "application/json; charset=utf-8" | Out-Null
            Write-Success "Updated release title & notes"
        }
    } catch {
        $ReleaseJson = (@{
            tag_name               = $TagVersion
            target_commitish       = if ($CurrentBranch -and $CurrentBranch -ne "HEAD") { $CurrentBranch } else { "main" }
            name                   = $Title
            body                   = $NotesContent
            draft                  = $Draft.IsPresent
            prerelease             = $Prerelease.IsPresent
            generate_release_notes = $false
        } | ConvertTo-Json -Depth 3)
        $ReleaseBytes = [System.Text.Encoding]::UTF8.GetBytes($ReleaseJson)

        try {
            $Response = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/releases" `
                -Method POST -Headers $Headers -Body $ReleaseBytes -ContentType "application/json; charset=utf-8"
            $ReleaseId = $Response.id
            $HtmlUrl = $Response.html_url
            Write-Success "GitHub Release created: $HtmlUrl"
        } catch {
            Write-Err "GitHub API error creating release: $($_.Exception.Message)"
            exit 1
        }
    }

    Write-Step "Uploading artifacts to GitHub Release"

    $UploadUrlBase = "https://uploads.github.com/repos/$Owner/$Repo/releases/$ReleaseId/assets"

    foreach ($Artifact in $Artifacts) {
        $FileName = $Artifact.Name
        $FilePath = $Artifact.FullName
        $FileSize = [math]::Round($Artifact.Length / 1MB, 2)

        if ($ExistingAssets) {
            foreach ($Asset in $ExistingAssets) {
                if ($Asset.name -eq $FileName) {
                    Write-Host "Deleting existing GitHub asset: $FileName..." -NoNewline
                    try {
                        Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/releases/assets/$($Asset.id)" `
                            -Method DELETE -Headers $Headers | Out-Null
                        Write-Host " [OK]" -ForegroundColor Green
                    } catch {
                        Write-Host " [FAILED]" -ForegroundColor Red
                    }
                }
            }
        }

        Write-Host "Uploading to GitHub: $FileName ($FileSize MB)..." -NoNewline
        $ContentType = switch -Regex ($FileName) {
            '\.apk$' { "application/vnd.android.package-archive" }
            '\.zip$' { "application/zip" }
            '\.exe$' { "application/x-msdownload" }
            default  { "application/octet-stream" }
        }

        $UploadUrl = "$UploadUrlBase`?name=$([Uri]::EscapeDataString($FileName))"
        try {
            $UploadResponse = Invoke-RestMethod -Uri $UploadUrl -Method POST -Headers $Headers `
                -InFile $FilePath -ContentType $ContentType
            Write-Host " [OK]" -ForegroundColor Green
            Write-Host "  -> $($UploadResponse.browser_download_url)"
        } catch {
            Write-Host " [FAILED]" -ForegroundColor Red
            Write-Err "GitHub asset upload failed for ${FileName}: $($_.Exception.Message)"
            exit 1
        }
    }
}

# --- Upload to Backblaze B2 ---

$B2Ok = $false

if ($SkipB2) {
    Write-Host ""
    Write-Host "[SKIP] B2 upload skipped (-SkipB2). App auto-updater & web download link stay on the previous version." -ForegroundColor Yellow
} else {
    Write-Step "Uploading to Backblaze B2"

    $WinZip = $Artifacts | Where-Object { $_.Name -like "*windows*.zip" } | Select-Object -First 1
    $AndroidApk = $Artifacts | Where-Object { $_.Name -like "*.apk" } | Select-Object -First 1

    $UploadScript = Join-Path $PSScriptRoot "upload-b2.ps1"
    $UploadParams = @{
        Version = $SemVer
        Title   = $Title
        Notes   = $NotesContent
    }
    if ($HtmlUrl) {
        $UploadParams["ReleaseUrl"] = $HtmlUrl
    }
    if ($WinZip) {
        $UploadParams["ZipPath"] = $WinZip.FullName
    }
    if ($AndroidApk) {
        $UploadParams["ApkPath"] = $AndroidApk.FullName
    }

    & $UploadScript @UploadParams
    if ($LASTEXITCODE -eq 0) {
        $B2Ok = $true
    } else {
        Write-Err "B2 upload failed. GitHub Release is already published - rerun B2 upload alone with:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File `".agents\skills\build-and-release\scripts\upload-b2.ps1`" -Version `"$SemVer`"" -ForegroundColor Yellow
        exit 1
    }
}

# --- Done ---

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Release completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Version        : $TagVersion ($SemVer+$BuildNum)" -ForegroundColor Yellow
if ($HtmlUrl) {
    Write-Host "GitHub Release : $HtmlUrl" -ForegroundColor Yellow
}
if ($B2Ok) {
    Write-Host "Studio page    : https://giaiphapsangtao.com/studio/crm/subscription" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Artifacts:" -ForegroundColor Yellow
foreach ($f in $Artifacts) {
    $Size = [math]::Round($f.Length / 1MB, 2)
    Write-Host "  - $($f.Name)  ($Size MB)"
}
