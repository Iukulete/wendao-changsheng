[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
$ProjectDir = Join-Path $Root "godot"
$ConsolePath = Join-Path $Root "tools\godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe"
$CaptureDir = Join-Path $Root ".tmp\render-captures"
$TestScript = "res://tests/render_capture_test.gd"

New-Item -ItemType Directory -Force -Path $CaptureDir | Out-Null
try {
    # A real Windows display driver is required for viewport pixel capture. The
    # window starts far outside the desktop work area and cannot take focus.
    $ErrorActionPreference = "Continue"
    $output = @(& $ConsolePath --display-driver windows --rendering-method gl_compatibility `
        --audio-driver Dummy --position "-32000,-32000" --resolution 1440x900 `
        --path $ProjectDir --quit-after 600 --script $TestScript 2>&1)
    $exitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = "Stop"
}
$output | ForEach-Object { Write-Host $_ }
$text = $output | Out-String
if ($exitCode -ne 0 -or $text -match '(?m)^(SCRIPT ERROR|ERROR):' -or
        -not $text.Contains("RENDER_CAPTURE_TEST_OK:")) {
    throw "Godot render capture failed: exit=$exitCode."
}

$expected = @(
    "menu_1280x720.png",
    "main_1280x720.png",
    "main_1440x900.png",
    "main_1920x1080.png",
    "dungeon_route_1440x900.png",
    "dungeon_combat_1440x900.png"
)
foreach ($name in $expected) {
    $path = Join-Path $CaptureDir $name
    if (-not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).Length -lt 10000) {
        throw "Render capture is missing or unexpectedly small: $path"
    }
}
Write-Host "Godot render validation passed: $($expected.Count) captures in $CaptureDir"
