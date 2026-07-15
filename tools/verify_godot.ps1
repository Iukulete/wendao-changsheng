[CmdletBinding()]
param(
    [switch]$NoPrepare
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
$ProjectDir = Join-Path $Root "godot"
$ConsolePath = Join-Path $Root "tools\godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe"
$TempDir = Join-Path $Root ".tmp\godot"

New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
$env:TEMP = $TempDir
$env:TMP = $TempDir

if (-not $NoPrepare) {
    & (Join-Path $PSScriptRoot "prepare_godot.ps1") -SkipTemplates
    if ($LASTEXITCODE -ne 0) {
        throw "Godot environment preparation failed with exit code $LASTEXITCODE."
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $ProjectDir "project.godot"))) {
    throw "Godot project was not found: $ProjectDir"
}
if (-not (Test-Path -LiteralPath $ConsolePath)) {
    throw "Godot 4.7.1 console executable was not found: $ConsolePath"
}

$version = (& $ConsolePath --version | Select-Object -First 1).Trim()
if ($version -notmatch '^4\.7\.1\.stable\.official\.') {
    throw "Godot version drift detected: $version"
}

Write-Host "Importing resources and checking scripts..."
& $ConsolePath --headless --path $ProjectDir --import
if ($LASTEXITCODE -ne 0) {
    throw "Godot resource import/script validation failed with exit code $LASTEXITCODE."
}

Write-Host "Loading the configured main scene for a headless smoke test..."
& $ConsolePath --headless --path $ProjectDir --quit-after 5
if ($LASTEXITCODE -ne 0) {
    throw "Godot main-scene smoke test failed with exit code $LASTEXITCODE."
}

$testScripts = @(
    "res://tests/save_service_test.gd",
    "res://tests/main_save_integration_test.gd"
)
foreach ($testScript in $testScripts) {
    Write-Host "Running Godot regression: $testScript"
    & $ConsolePath --headless --path $ProjectDir --script $testScript
    if ($LASTEXITCODE -ne 0) {
        throw "Godot regression failed ($testScript) with exit code $LASTEXITCODE."
    }
}

Write-Host "Godot validation passed: $version"
