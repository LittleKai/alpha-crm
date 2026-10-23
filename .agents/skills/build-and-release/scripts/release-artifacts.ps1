# Shared local-only checks. Never infer an artifact's version from its filename.
function Get-ReleaseTargets {
    param([string]$Targets)
    $Selected = @($Targets.Split(',') | ForEach-Object {
        $Target = $_.Trim().ToLowerInvariant()
        if ($Target -eq 'apk') { $Target = 'android' }
        if ($Target -notin @('windows', 'android')) { throw "Invalid target '$Target'." }
        $Target
    } | Select-Object -Unique)
    if ($Selected.Count -eq 0) { throw 'At least one target is required.' }
    $Selected
}

function ConvertFrom-ApkBadging {
    param([string]$Badging)
    if ($Badging -cnotmatch "(?m)^package:[^\r\n]*?[ \t]versionCode='(\d+)'[ \t]+versionName='([^']+)'(?:[ \t]|$)") {
        throw 'Could not read embedded APK version with aapt.'
    }
    @{ Version = $Matches[2]; Build = $Matches[1] }
}

function Get-ArtifactIdentity {
    param([string]$Path, [string]$Platform, [string]$ProjectRoot)
    if ($Platform -eq 'windows') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $Archive = [IO.Compression.ZipFile]::OpenRead($Path)
        $TempExe = Join-Path ([IO.Path]::GetTempPath()) ("crm-release-" + [guid]::NewGuid().ToString('N') + '.exe')
        try {
            foreach ($Entry in $Archive.Entries) {
                if (($Entry.FullName -replace '\\', '/') -match '(^|/)\.(data|env)(/|$)') {
                    throw 'Windows ZIP contains forbidden .data or .env entry.'
                }
            }
            $Executables = @($Archive.Entries | Where-Object { ($_.FullName -replace '\\', '/') -match '(^|/)alpha_crm\.exe$' })
            if ($Executables.Count -ne 1) { throw 'Windows ZIP must contain exactly one alpha_crm.exe.' }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($Executables[0], $TempExe)
            $Info = [Diagnostics.FileVersionInfo]::GetVersionInfo($TempExe)
            return @{ Version = "$($Info.FileMajorPart).$($Info.FileMinorPart).$($Info.FileBuildPart)"; Build = "$($Info.FilePrivatePart)" }
        } finally {
            $Archive.Dispose()
            if (Test-Path -LiteralPath $TempExe) { Remove-Item -LiteralPath $TempExe -Force }
        }
    }

    $SdkRoot = $env:ANDROID_SDK_ROOT
    if (-not $SdkRoot) { $SdkRoot = $env:ANDROID_HOME }
    $LocalProperties = Join-Path $ProjectRoot 'android/local.properties'
    if (-not $SdkRoot -and (Test-Path -LiteralPath $LocalProperties)) {
        $SdkLine = Get-Content -LiteralPath $LocalProperties | Where-Object { $_ -match '^sdk\.dir=' } | Select-Object -First 1
        if ($SdkLine) { $SdkRoot = $SdkLine.Substring(8).Replace('\\', '\').Replace('\:', ':') }
    }
    if (-not $SdkRoot) { throw 'Android SDK is required to validate APK version (ANDROID_SDK_ROOT or sdk.dir).' }
    $Aapt = Get-ChildItem -LiteralPath (Join-Path $SdkRoot 'build-tools') -Directory |
        Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'aapt.exe' } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $Aapt) { throw 'Android SDK aapt.exe not found; APK version cannot be verified.' }
    $Badging = (& $Aapt dump badging $Path 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not read embedded APK version with aapt.'
    }
    ConvertFrom-ApkBadging $Badging
}

function Get-ReleaseArtifacts {
    param([string]$ProjectRoot, [string]$Version, [string]$Build, [string]$Targets, [string]$ZipPath = '', [string]$ApkPath = '')
    if ($Version -notmatch '^\d+\.\d+\.\d+$' -or $Build -notmatch '^\d+$') { throw 'Invalid release version/build.' }
    $Selected = @(Get-ReleaseTargets $Targets)
    if ($ZipPath -and 'windows' -notin $Selected) { throw 'ZipPath requires windows in Targets.' }
    if ($ApkPath -and 'android' -notin $Selected) { throw 'ApkPath requires android in Targets.' }
    foreach ($Platform in $Selected) {
        $ArtifactPath = if ($Platform -eq 'windows') {
            if ($ZipPath) { $ZipPath } else { Join-Path $ProjectRoot 'build/release/alpha-crm-windows.zip' }
        } else {
            if ($ApkPath) { $ApkPath } else { Join-Path $ProjectRoot "build/release/alpha-crm-v$Version.apk" }
        }
        if (-not (Test-Path -LiteralPath $ArtifactPath -PathType Leaf)) { throw "Missing $Platform artifact: $ArtifactPath" }
        $Artifact = Get-Item -LiteralPath $ArtifactPath
        $ExpectedExtension = if ($Platform -eq 'windows') { '.zip' } else { '.apk' }
        if ($Artifact.Extension -ne $ExpectedExtension) { throw "Invalid $Platform artifact extension." }
        $Identity = Get-ArtifactIdentity -Path $Artifact.FullName -Platform $Platform -ProjectRoot $ProjectRoot
        if ($Identity.Version -ne $Version -or $Identity.Build -ne $Build) {
            throw "Artifact version mismatch for $($Artifact.Name): embedded $($Identity.Version)+$($Identity.Build), expected $Version+$Build. Rebuild the selected platform."
        }
        $Artifact | Add-Member -NotePropertyName ReleaseSha256 -NotePropertyValue (Get-FileHash -LiteralPath $Artifact.FullName -Algorithm SHA256).Hash -Force
        $Artifact
    }
}
