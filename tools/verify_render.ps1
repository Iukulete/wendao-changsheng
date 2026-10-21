[CmdletBinding()]
param()
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$Root = Split-Path -Parent $PSScriptRoot
$ConsolePath = Join-Path $Root "tools\godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe"
# Separate display-backed gate: res://tests/ark_render_capture_test.gd must emit
# ARK_RENDER_CAPTURE_TEST_OK:. The shared runner checks errors, timeout, exact
# PNG dimensions and distinct menu/3D-state pixels; no audio device is needed.
& python -X utf8 (Join-Path $PSScriptRoot "verify_godot.py") --godot $ConsolePath --render-only --display-driver windows
if ($LASTEXITCODE -ne 0) { throw "Ark display-backed render validation failed: $LASTEXITCODE" }
