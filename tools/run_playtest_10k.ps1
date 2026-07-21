[CmdletBinding()]
param(
	[int]$Count = 10000,
	[int]$TimeoutSec = 1800,
	[int]$Shards = 4,
	[int]$Offset = 0
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
if ($Count -lt 1 -or $Count -gt 100000) {
	throw "Count must be between 1 and 100000."
}
if ($Shards -lt 1 -or $Shards -gt 16 -or $Shards -gt $Count) {
	throw "Shards must be between 1 and min(16, Count)."
}
if ($Offset -lt 0) {
	throw "Offset cannot be negative."
}

$Root = Split-Path -Parent $PSScriptRoot
$ProjectDir = Join-Path $Root "godot"
$ConsolePath = Join-Path $Root "tools\godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe"
if (-not (Test-Path -LiteralPath $ConsolePath)) {
	throw "Godot 4.7.1 console executable was not found: $ConsolePath"
}

$BatchDir = Join-Path $Root ".tmp\playtest-batch"
New-Item -ItemType Directory -Force -Path $BatchDir | Out-Null
$processes = @()
$playtestSummaries = @()
$assigned = 0
try {
	for ($shard = 0; $shard -lt $Shards; $shard++) {
		$shardCount = [Math]::Floor($Count / $Shards)
		if ($shard -lt ($Count % $Shards)) {
			$shardCount++
		}
		$shardOffset = $Offset + $assigned
		$assigned += $shardCount
		$runtimeDir = Join-Path $Root ".tmp\playtest-runtime-$shardOffset"
		New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null
		$env:TEMP = $runtimeDir
		$env:TMP = $runtimeDir
		$env:WENDAO_PLAYTEST_COUNT = $shardCount.ToString()
		$env:WENDAO_PLAYTEST_OFFSET = $shardOffset.ToString()
		$stdout = Join-Path $BatchDir "shard-$shardOffset.stdout.log"
		$stderr = Join-Path $BatchDir "shard-$shardOffset.stderr.log"
		$process = Start-Process -FilePath $ConsolePath -ArgumentList @(
			"--headless", "--audio-driver", "Dummy", "--path", $ProjectDir,
			"--quit-after", $TimeoutSec, "--script", "res://tests/ten_thousand_playtest_test.gd"
		) -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
		$processes += [pscustomobject]@{
			Process = $process
			Count = $shardCount
			Offset = $shardOffset
			Stdout = $stdout
			Stderr = $stderr
			RuntimeDir = $runtimeDir
		}
	}
	if ($assigned -ne $Count) {
		throw "Shard assignment mismatch: assigned=$assigned expected=$Count"
	}
	$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
	foreach ($entry in $processes) {
		$remaining = [Math]::Max(1, [int]($deadline - [DateTime]::UtcNow).TotalMilliseconds)
		if (-not $entry.Process.WaitForExit($remaining)) {
			$entry.Process.Kill()
			throw "Playtest shard timed out: offset=$($entry.Offset)"
		}
		$entry.Process.WaitForExit()
		$entry.Process.Refresh()
		$exitCode = [int]$entry.Process.ExitCode
		$stdoutText = [System.IO.File]::ReadAllText($entry.Stdout, [System.Text.Encoding]::UTF8)
		$stderrText = [System.IO.File]::ReadAllText($entry.Stderr, [System.Text.Encoding]::UTF8)
		Write-Host $stdoutText
		if (-not [string]::IsNullOrWhiteSpace($stderrText)) {
			Write-Host $stderrText
		}
		if ($exitCode -ne 0 -or
				-not $stdoutText.Contains("TEN_THOUSAND_PLAYTEST_OK: $($entry.Count) ")) {
			throw "Playtest shard failed: offset=$($entry.Offset) exit=$exitCode"
		}
		$summaryLine = @($stdoutText -split "`r?`n" | Where-Object {
			$_.StartsWith("PLAYTEST_SUMMARY: ")
		}) | Select-Object -Last 1
		if ([string]::IsNullOrWhiteSpace($summaryLine)) {
			throw "Playtest shard did not emit a structured summary: offset=$($entry.Offset)"
		}
		$playtestSummaries += ($summaryLine.Substring("PLAYTEST_SUMMARY: ".Length) | ConvertFrom-Json)
	}
	$batchTelemetry = @{
		sessions = 0L
		natural_deaths = 0L
		reincarnations = 0L
		ai_fallbacks = 0L
		save_roundtrips = 0L
		choice_availability_fallbacks = 0L
		combat_turn_total = 0L
		combat_hp_loss_basis_points_total = 0L
		combat_near_deaths = 0L
		story_triggers = 0L
		story_trigger_event_total = 0L
		story_stage_total = 0L
		final_year_total = 0L
		event_resolutions = @{}
		choice_positions = @{}
		event_choice_counts = @{}
		offered_choice_profiles = @{}
		selected_choice_profiles = @{}
		combat_outcomes = @{}
		combat_outcomes_by_root = @{}
		combat_turn_total_by_root = @{}
		combat_hp_loss_basis_points_by_root = @{}
		dungeon_outcomes = @{}
		dungeon_outcomes_by_root = @{}
		root_cohort_sessions = @{}
		final_resource_totals = @{}
		final_path_totals = @{}
	}
	function Add-NumericProperties([hashtable]$Target, $Source) {
		if ($null -eq $Source) { return }
		foreach ($property in $Source.PSObject.Properties) {
			$key = [string]$property.Name
			$Target[$key] = [long]($Target[$key]) + [long]($property.Value)
		}
	}
	foreach ($summary in $playtestSummaries) {
		$telemetry = $summary.telemetry
		foreach ($field in @(
			"sessions", "natural_deaths", "reincarnations", "ai_fallbacks",
			"save_roundtrips", "choice_availability_fallbacks", "combat_turn_total",
			"combat_hp_loss_basis_points_total", "combat_near_deaths", "story_triggers",
			"story_trigger_event_total", "story_stage_total", "final_year_total"
		)) {
			$batchTelemetry[$field] = [long]$batchTelemetry[$field] + [long]$telemetry.$field
		}
		foreach ($field in @(
			"event_resolutions", "choice_positions", "event_choice_counts",
			"offered_choice_profiles", "selected_choice_profiles", "combat_outcomes",
			"combat_outcomes_by_root", "combat_turn_total_by_root",
			"combat_hp_loss_basis_points_by_root", "dungeon_outcomes", "dungeon_outcomes_by_root",
			"root_cohort_sessions", "final_resource_totals", "final_path_totals"
		)) {
			Add-NumericProperties $batchTelemetry[$field] $telemetry.$field
		}
	}
	$sessionCount = [Math]::Max(1L, [long]$batchTelemetry.sessions)
	$combatAttempts = [long](($batchTelemetry.combat_outcomes.Values | Measure-Object -Sum).Sum)
	$dungeonAttempts = [long](($batchTelemetry.dungeon_outcomes.Values | Measure-Object -Sum).Sum)
	$averages = @{
		final_year = [Math]::Round([double]$batchTelemetry.final_year_total / $sessionCount, 3)
		story_stages = [Math]::Round([double]$batchTelemetry.story_stage_total / $sessionCount, 3)
		combat_turns = if ($combatAttempts -gt 0) {
			[Math]::Round([double]$batchTelemetry.combat_turn_total / $combatAttempts, 3)
		} else { 0.0 }
		combat_hp_loss = if ($combatAttempts -gt 0) {
			[Math]::Round([double]$batchTelemetry.combat_hp_loss_basis_points_total /
				$combatAttempts / 10000.0, 6)
		} else { 0.0 }
		resources = @{}
		paths = @{}
	}
	foreach ($key in $batchTelemetry.final_resource_totals.Keys) {
		$averages.resources[$key] = [Math]::Round(
			[double]$batchTelemetry.final_resource_totals[$key] / $sessionCount, 3)
	}
	foreach ($key in $batchTelemetry.final_path_totals.Keys) {
		$averages.paths[$key] = [Math]::Round(
			[double]$batchTelemetry.final_path_totals[$key] / $sessionCount, 3)
	}
	$rates = @{
		natural_death = [Math]::Round([double]$batchTelemetry.natural_deaths / $sessionCount, 6)
		combat_victory = if ($combatAttempts -gt 0) {
			[Math]::Round([double]$batchTelemetry.combat_outcomes.victory / $combatAttempts, 6)
		} else { 0.0 }
		combat_near_death = if ($combatAttempts -gt 0) {
			[Math]::Round([double]$batchTelemetry.combat_near_deaths / $combatAttempts, 6)
		} else { 0.0 }
		dungeon_completion = if ($dungeonAttempts -gt 0) {
			[Math]::Round([double]$batchTelemetry.dungeon_outcomes.completed / $dungeonAttempts, 6)
		} else { 0.0 }
		costless_offered_choice = [Math]::Round(
			[double]$batchTelemetry.offered_choice_profiles.costless /
			[Math]::Max(1L, [long]$batchTelemetry.offered_choice_profiles.total), 6)
	}
	$batchSummary = @{
		runs = $Count
		shards = $Shards
		offset = $Offset
		telemetry = $batchTelemetry
		rates = $rates
		averages = $averages
	}
	Write-Host "PLAYTEST_BATCH_SUMMARY: $($batchSummary | ConvertTo-Json -Compress -Depth 8)"
	Write-Host "PLAYTEST_BATCH_OK: $Count sessions across $Shards shards at offset $Offset."
} finally {
	foreach ($entry in $processes) {
		if (-not $entry.Process.HasExited) {
			$entry.Process.Kill()
		}
	}
	foreach ($path in @($BatchDir) + @($processes | ForEach-Object { $_.RuntimeDir })) {
		if (Test-Path -LiteralPath $path) {
			[System.IO.Directory]::Delete($path, $true)
		}
	}
}
