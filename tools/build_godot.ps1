[CmdletBinding()]
param(
    [switch]$NoPrepare,
    [switch]$SkipVerify,
    [switch]$SkipAudioDeviceSmoke,
    [switch]$ProductRelease
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
$ProjectDir = Join-Path $Root "godot"
$OutputDir = Join-Path $Root "release\godot\windows"
$OutputExe = Join-Path $OutputDir "wendao-changsheng.exe"
$OutputPck = Join-Path $OutputDir "wendao-changsheng.pck"
$OutputLicenseDir = Join-Path $OutputDir "licenses"
$OutputAiDir = Join-Path $OutputDir "ai_engine"
$ChecksumPath = Join-Path $OutputDir "checksums.sha256"
$ConsolePath = Join-Path $Root "tools\godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe"
$TempDir = Join-Path $Root ".tmp\godot"

if ($ProductRelease -and $SkipAudioDeviceSmoke) {
    throw "ProductRelease cannot skip the real Windows audio-device smoke test."
}

$releaseRoot = [System.IO.Path]::GetFullPath((Join-Path $Root "release"))
$resolvedOutputDir = [System.IO.Path]::GetFullPath($OutputDir)
if (-not $resolvedOutputDir.StartsWith($releaseRoot + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean unexpected output directory: $resolvedOutputDir"
}
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
$env:TEMP = $TempDir
$env:TMP = $TempDir

if (-not $NoPrepare) {
    & (Join-Path $PSScriptRoot "prepare_godot.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw "Godot environment preparation failed with exit code $LASTEXITCODE."
    }
}

if (-not $SkipVerify) {
    & (Join-Path $PSScriptRoot "verify_godot.ps1") -NoPrepare `
        -RequireFinalAudio:$ProductRelease -RequireProductArt:$ProductRelease
    if ($LASTEXITCODE -ne 0) {
        throw "Godot validation failed with exit code $LASTEXITCODE."
    }
} elseif ($ProductRelease) {
    & python -X utf8 (Join-Path $PSScriptRoot "verify_audio_assets.py") --require-final
    if ($LASTEXITCODE -ne 0) {
        throw "Product release audio gate failed with exit code $LASTEXITCODE."
    }
    & python -X utf8 (Join-Path $PSScriptRoot "verify_godot_art.py") --release
    if ($LASTEXITCODE -ne 0) {
        throw "Product release art gate failed with exit code $LASTEXITCODE."
    }
}

if (Test-Path -LiteralPath $resolvedOutputDir) {
    Remove-Item -LiteralPath $resolvedOutputDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDir | Out-Null
Write-Host "Exporting the Windows x86_64 release..."
& $ConsolePath --headless --path $ProjectDir --export-release "Windows Desktop" $OutputExe
if ($LASTEXITCODE -ne 0) {
    throw "Godot Windows export failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path -LiteralPath $OutputExe)) {
    throw "Godot reported success, but the Windows executable is missing: $OutputExe"
}
if (-not (Test-Path -LiteralPath $OutputPck)) {
    throw "Godot reported success, but the resource pack is missing: $OutputPck"
}

$exeSize = (Get-Item -LiteralPath $OutputExe).Length
$pckSize = (Get-Item -LiteralPath $OutputPck).Length
if ($exeSize -lt 1MB -or $pckSize -lt 1KB) {
    throw "Export artifacts look incomplete (EXE=$exeSize bytes, PCK=$pckSize bytes)."
}

New-Item -ItemType Directory -Force -Path $OutputLicenseDir | Out-Null
Copy-Item -LiteralPath (Join-Path $Root "LICENSE") `
    -Destination (Join-Path $OutputLicenseDir "AGPL-3.0.txt") -Force
foreach ($licenseName in @("NotoSansSC-OFL.txt", "NotoSerifSC-OFL.txt")) {
    $licenseSource = Join-Path $ProjectDir "art\fonts\$licenseName"
    $licenseTarget = Join-Path $OutputLicenseDir $licenseName
    if (-not (Test-Path -LiteralPath $licenseSource)) {
        throw "Bundled font license is missing: $licenseSource"
    }
    Copy-Item -LiteralPath $licenseSource -Destination $licenseTarget -Force
}
$audioLicenseSource = Join-Path $ProjectDir "audio\LICENSE-AUDIO.txt"
$audioManifestSource = Join-Path $ProjectDir "audio\audio_manifest_v1.json"
foreach ($auditSource in @($audioLicenseSource, $audioManifestSource)) {
    if (-not (Test-Path -LiteralPath $auditSource)) {
        throw "Bundled audio audit file is missing: $auditSource"
    }
    Copy-Item -LiteralPath $auditSource -Destination (Join-Path $OutputLicenseDir (Split-Path -Leaf $auditSource)) -Force
}
$aiNoticeSource = Join-Path $Root "ai_engine\THIRD_PARTY_AI.md"
Copy-Item -LiteralPath $aiNoticeSource -Destination (Join-Path $OutputLicenseDir "THIRD_PARTY_AI.md") -Force

New-Item -ItemType Directory -Force -Path $OutputAiDir | Out-Null
foreach ($aiSupportName in @(
    "setup_portable_ai.ps1", "generate_event.ps1", "test_local_ai.ps1", "THIRD_PARTY_AI.md"
)) {
    Copy-Item -LiteralPath (Join-Path $Root "ai_engine\$aiSupportName") `
        -Destination (Join-Path $OutputAiDir $aiSupportName) -Force
}
Copy-Item -LiteralPath (Join-Path $Root "setup-local-ai.bat") `
    -Destination (Join-Path $OutputDir "setup-local-ai.bat") -Force
Copy-Item -LiteralPath (Join-Path $Root "docs\WINDOWS_RELEASE_README.md") `
    -Destination (Join-Path $OutputDir "README.md") -Force

# Run the actual exported build, while keeping its user-data probe on D:.
$SmokeDataDir = Join-Path $TempDir "export-smoke-userdata"
New-Item -ItemType Directory -Force -Path $SmokeDataDir | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = $SmokeDataDir
    $env:LOCALAPPDATA = $SmokeDataDir
    Write-Host "Running exported Windows build smoke test..."
    $smoke = Start-Process -FilePath $OutputExe -WorkingDirectory $OutputDir `
        -ArgumentList "--headless", "--quit-after", "5" -WindowStyle Hidden -PassThru -Wait
    if ($smoke.ExitCode -ne 0) {
        throw "Exported Windows build smoke test failed with exit code $($smoke.ExitCode)."
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

if (-not $SkipAudioDeviceSmoke) {
    & (Join-Path $PSScriptRoot "verify_export_audio.ps1") -ExePath $OutputExe
    if ($LASTEXITCODE -ne 0) {
        throw "Exported Windows audio-device smoke failed with exit code $LASTEXITCODE."
    }
} else {
    Write-Host "Skipping the hardware-backed Windows audio-device smoke; this mode is reserved for headless CI."
}

$checksumLines = @(Get-ChildItem -LiteralPath $OutputDir -Recurse -File |
    Where-Object { $_.FullName -ne $ChecksumPath } |
    Sort-Object FullName |
    ForEach-Object {
        $relative = $_.FullName.Substring($OutputDir.Length + 1).Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        "$hash  $relative"
    })
[System.IO.File]::WriteAllLines($ChecksumPath, $checksumLines, (New-Object System.Text.UTF8Encoding($false)))

& (Join-Path $PSScriptRoot "verify_release_bundle.ps1") -OutputDir $OutputDir
if ($LASTEXITCODE -ne 0) {
    throw "Release bundle validation failed with exit code $LASTEXITCODE."
}

Write-Host "Godot Windows build complete:"
Write-Host "  $OutputExe ($exeSize bytes)"
Write-Host "  $OutputPck ($pckSize bytes)"
Get-FileHash -LiteralPath $OutputExe, $OutputPck -Algorithm SHA256 |
    Select-Object Path, Hash
