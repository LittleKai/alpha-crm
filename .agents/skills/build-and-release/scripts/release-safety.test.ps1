$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release-artifacts.ps1')

function Assert-Throws([scriptblock]$Action, [string]$Expected) {
    try { & $Action } catch {
        if ($_.Exception.Message -notlike "*$Expected*") { throw }
        return
    }
    throw "Expected rejection containing '$Expected'."
}

$Badging = "package: name='com.alphastudio.crm.alpha_crm' versionCode='30' versionName='0.2.2' platformBuildVersionName='16' platformBuildVersionCode='36' compileSdkVersion='36' compileSdkVersionCodename='16'"
$ApkIdentity = ConvertFrom-ApkBadging $Badging
if ($ApkIdentity.Version -ne '0.2.2' -or $ApkIdentity.Build -ne '30') {
    throw 'APK package version must not be confused with platform build metadata.'
}
Assert-Throws { ConvertFrom-ApkBadging "package: name='example' platformBuildVersionCode='36' platformBuildVersionName='16'" } 'Could not read embedded APK version'

$FixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
try {
    $ReleaseDir = Join-Path $FixtureRoot 'build/release'
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.IO.Compression
    $ZipFixture = Join-Path $FixtureRoot 'structure.zip'
    $Archive = [IO.Compression.ZipFile]::Open($ZipFixture, [IO.Compression.ZipArchiveMode]::Create)
    $Archive.CreateEntry('README.txt') | Out-Null
    $Archive.Dispose()
    Assert-Throws { Get-ArtifactIdentity -Path $ZipFixture -Platform 'windows' -ProjectRoot $FixtureRoot } 'exactly one alpha_crm.exe'
    $Archive = [IO.Compression.ZipFile]::Open($ZipFixture, [IO.Compression.ZipArchiveMode]::Update)
    $Archive.CreateEntry('alpha_crm.exe') | Out-Null
    $Archive.CreateEntry('nested/alpha_crm.exe') | Out-Null
    $Archive.Dispose()
    Assert-Throws { Get-ArtifactIdentity -Path $ZipFixture -Platform 'windows' -ProjectRoot $FixtureRoot } 'exactly one alpha_crm.exe'
    foreach ($ForbiddenEntry in @('zalo-bot-service/.data/logs/agent.log', 'zalo-bot-service/.env', '.data/', '.env', 'zalo-bot-service\.data\logs\agent.log')) {
        $DirtyZip = Join-Path $FixtureRoot 'dirty.zip'
        $Archive = [IO.Compression.ZipFile]::Open($DirtyZip, [IO.Compression.ZipArchiveMode]::Create)
        $Archive.CreateEntry('alpha_crm.exe') | Out-Null
        $Archive.CreateEntry($ForbiddenEntry) | Out-Null
        $Archive.Dispose()
        Assert-Throws { Get-ArtifactIdentity -Path $DirtyZip -Platform 'windows' -ProjectRoot $FixtureRoot } 'Windows ZIP contains forbidden .data or .env entry'
        Remove-Item -LiteralPath $DirtyZip -Force
    }
    # Read PE metadata from a Windows system utility as inert bytes; never launch the fixture.
    $PeFixture = Join-Path $env:WINDIR 'System32/whoami.exe'
    $PeInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo($PeFixture)
    $PeZip = Join-Path $FixtureRoot 'metadata.zip'
    $Archive = [IO.Compression.ZipFile]::Open($PeZip, [IO.Compression.ZipArchiveMode]::Create)
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive, $PeFixture, 'app/alpha_crm.exe') | Out-Null
    $Archive.Dispose()
    $Identity = Get-ArtifactIdentity -Path $PeZip -Platform 'windows' -ProjectRoot $FixtureRoot
    if ($Identity.Version -ne "$($PeInfo.FileMajorPart).$($PeInfo.FileMinorPart).$($PeInfo.FileBuildPart)" -or $Identity.Build -ne "$($PeInfo.FilePrivatePart)") {
        throw 'ZIP embedded PE identity was read incorrectly.'
    }
    Set-Content (Join-Path $ReleaseDir 'alpha-crm-windows.zip') 'windows fixture'
    Set-Content (Join-Path $ReleaseDir 'alpha-crm-v1.0.0.apk') 'stale apk fixture'
    # Native metadata tools are the boundary; selection and comparison below run unchanged.
    function Get-ArtifactIdentity { param($Path, $Platform, $ProjectRoot) @{ Version = '1.1.0'; Build = '2' } }
    $Selected = @(Get-ReleaseArtifacts -ProjectRoot $FixtureRoot -Version '1.1.0' -Build '2' -Targets 'windows')
    if ($Selected.Count -ne 1 -or $Selected[0].Extension -ne '.zip') { throw 'Unselected stale APK was included.' }
    Assert-Throws { Get-ReleaseArtifacts -ProjectRoot $FixtureRoot -Version '1.1.0' -Build '2' -Targets 'android' } 'Missing android artifact'
    Assert-Throws { Get-ReleaseArtifacts -ProjectRoot $FixtureRoot -Version '1.1.0' -Build '2' -Targets 'windows,typo' } 'Invalid target'
    Assert-Throws { Get-ReleaseArtifacts -ProjectRoot $FixtureRoot -Version '1.1.0' -Build '2' -Targets 'windows' -ApkPath (Join-Path $ReleaseDir 'alpha-crm-v1.0.0.apk') } 'ApkPath requires android'
    Set-Content (Join-Path $ReleaseDir 'alpha-crm-v1.1.0.apk') 'renamed stale apk fixture'
    function Get-ArtifactIdentity { param($Path, $Platform, $ProjectRoot) @{ Version = '1.0.0'; Build = '1' } }
    Assert-Throws { Get-ReleaseArtifacts -ProjectRoot $FixtureRoot -Version '1.1.0' -Build '2' -Targets 'android' } 'Artifact version mismatch'
    function Get-ArtifactIdentity { param($Path, $Platform, $ProjectRoot) @{ Version = '1.1.0'; Build = '1' } }
    Assert-Throws { Get-ReleaseArtifacts -ProjectRoot $FixtureRoot -Version '1.1.0' -Build '2' -Targets 'windows' } 'Artifact version mismatch'
    Write-Host 'Release artifact safety checks passed.'
} finally {
    if (Test-Path -LiteralPath $FixtureRoot) { [IO.Directory]::Delete($FixtureRoot, $true) }
}
