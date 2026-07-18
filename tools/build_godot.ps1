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
$ConsolePath = Join-Path $Root "tools\godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe"
$TempDir = Join-Path $Root ".tmp\godot"

if ($ProductRelease -and $SkipAudioDeviceSmoke) {
    throw "ProductRelease cannot skip the real Windows audio-device smoke test."
}

New-Item -ItemType Directory -Force -Path $TempDir, $OutputDir | Out-Null
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

Remove-Item -LiteralPath $OutputExe, $OutputPck -Force -ErrorAction SilentlyContinue
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

Write-Host "Godot Windows build complete:"
Write-Host "  $OutputExe ($exeSize bytes)"
Write-Host "  $OutputPck ($pckSize bytes)"
Get-FileHash -LiteralPath $OutputExe, $OutputPck -Algorithm SHA256 |
    Select-Object Path, Hash
