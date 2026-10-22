[CmdletBinding()]
param([switch]$NoPrepare)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$Root = Split-Path -Parent $PSScriptRoot
$ConsolePath = Join-Path $Root "tools\godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe"

# Canonical headless suite. verify_migration_surface.py compares this exact list
# to all Ark tests on disk, excluding only the helper and display-only capture.
$testScripts = @(
    "res://tests/ark_audit_construction_test.gd",
    "res://tests/ark_audit_hazards_test.gd",
    "res://tests/ark_audit_input_test.gd",
    "res://tests/ark_audit_navigation_test.gd",
    "res://tests/ark_chart_layout_audit_test.gd",
    "res://tests/ark_exposure_test.gd",
    "res://tests/ark_fixture_edit_test.gd",
    "res://tests/ark_greybox_smoke.gd",
    "res://tests/ark_jade_sail_ark_test.gd",
    "res://tests/ark_jade_sail_guest_stay_test.gd",
    "res://tests/ark_jade_sail_industry_test.gd",
    "res://tests/ark_landmass_physics_test.gd",
    "res://tests/ark_menu_integration_test.gd",
    "res://tests/ark_mooring_test.gd",
    "res://tests/ark_navigation_test.gd",
    "res://tests/ark_persistence_sanitize_audit_test.gd",
    "res://tests/ark_pressure_galley_test.gd",
    "res://tests/ark_reef_beast_test.gd",
    "res://tests/ark_reef_surge_test.gd",
    "res://tests/ark_refuge_test.gd",
    "res://tests/ark_resident_gather_test.gd",
    "res://tests/ark_save_integrity_audit_test.gd",
    "res://tests/ark_test_paths_test.gd",
    "res://tests/ark_world_travel_test.gd",
    "res://tests/ark_multifloor_risk_test.gd",
    "res://tests/ark_water_risk_test.gd",
    "res://tests/ark_resource_consistency_test.gd",
    "res://tests/ark_pixel_protagonist_test.gd",
    "res://tests/ark_emma_protagonist_test.gd",
    "res://tests/ark_game_version_test.gd",
    "res://tests/ark_module_chain_test.gd",
    "res://tests/ark_native_water_test.gd",
    "res://tests/ark_gerstner_water_test.gd",
    "res://tests/ark_hud_clarity_test.gd",
    "res://tests/ark_home_meal_test.gd"
)

if (-not $NoPrepare) {
    & (Join-Path $PSScriptRoot "prepare_godot.ps1") -SkipTemplates
    if ($LASTEXITCODE -ne 0) { throw "Pinned Godot preparation failed: $LASTEXITCODE" }
}
# One implementation gives Windows and cloud runs the same timeout, log,
# strict version, error and positive-marker protections, including PCK proof.
& python -X utf8 (Join-Path $PSScriptRoot "verify_godot.py") --godot $ConsolePath
if ($LASTEXITCODE -ne 0) { throw "Ark validation failed: $LASTEXITCODE" }
