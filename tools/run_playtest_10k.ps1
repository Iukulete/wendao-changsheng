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
	}
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
