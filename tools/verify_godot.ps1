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

Write-Host "Validating authored event path deltas..."
& python (Join-Path $PSScriptRoot "verify_event_paths.py")
if ($LASTEXITCODE -ne 0) {
    throw "Event path validation failed with exit code $LASTEXITCODE."
}

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
$importOutput = @(& $ConsolePath --headless --path $ProjectDir --import 2>&1)
$importExitCode = $LASTEXITCODE
$importOutput | ForEach-Object { Write-Host $_ }
if ($importExitCode -ne 0 -or (($importOutput | Out-String) -match '(?m)^(SCRIPT ERROR|ERROR):')) {
    throw "Godot resource import/script validation failed with exit code $importExitCode."
}

Write-Host "Loading the configured main scene for a headless smoke test..."
$smokeOutput = @(& $ConsolePath --headless --path $ProjectDir --quit-after 5 2>&1)
$smokeExitCode = $LASTEXITCODE
$smokeOutput | ForEach-Object { Write-Host $_ }
if ($smokeExitCode -ne 0 -or (($smokeOutput | Out-String) -match '(?m)^(SCRIPT ERROR|ERROR):')) {
    throw "Godot main-scene smoke test failed with exit code $smokeExitCode."
}

$testScripts = @(
    "res://tests/game_state_test.gd",
    "res://tests/world_simulation_test.gd",
    "res://tests/story_system_test.gd",
    "res://tests/achievement_system_test.gd",
    "res://tests/dungeon_system_test.gd",
    "res://tests/local_ai_bridge_test.gd",
    "res://tests/item_system_test.gd",
    "res://tests/combat_system_test.gd",
    "res://tests/save_service_test.gd",
    "res://tests/main_save_integration_test.gd"
)
foreach ($testScript in $testScripts) {
    Write-Host "Running Godot regression: $testScript"
    $testOutput = @(& $ConsolePath --headless --path $ProjectDir --quit-after 600 --script $testScript 2>&1)
    $testExitCode = $LASTEXITCODE
    $testOutput | ForEach-Object { Write-Host $_ }
    $testText = $testOutput | Out-String
    $testName = [IO.Path]::GetFileNameWithoutExtension($testScript).ToUpperInvariant()
    $successMarker = $testName + "_OK:"
    if ($testExitCode -ne 0 -or $testText -match '(?m)^(SCRIPT ERROR|ERROR):' -or
            -not $testText.Contains($successMarker)) {
        throw "Godot regression failed ($testScript): exit=$testExitCode, expected marker=$successMarker."
    }
}

Write-Host "Godot validation passed: $version"
