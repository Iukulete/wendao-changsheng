[CmdletBinding()]
param(
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    $OutputDir = Join-Path (Split-Path -Parent $scriptRoot) "release\godot\windows"
}
$OutputDir = [System.IO.Path]::GetFullPath($OutputDir)
if (-not (Test-Path -LiteralPath $OutputDir -PathType Container)) {
    throw "Release bundle directory is missing: $OutputDir"
}

$required = @(
    "wendao-changsheng.exe",
    "wendao-changsheng.pck",
    "README.md",
    "checksums.sha256",
    "licenses\AGPL-3.0.txt",
    "licenses\NotoSansSC-OFL.txt",
    "licenses\NotoSerifSC-OFL.txt",
    "licenses\LICENSE-AUDIO.txt",
    "licenses\audio_manifest_v2.json",
    "licenses\0ad-audio-LICENSE.txt",
    "licenses\kenney-cc0.txt",
    "licenses\opengameart-dungeon-ambient-cc0.txt",
    "licenses\opengameart-jade-throne-ccby3.txt"
)
foreach ($relativePath in $required) {
    $path = Join-Path $OutputDir $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Release bundle is missing: $relativePath"
    }
}

# The build directory is cleaned before export, but keep the release gate
# closed to stale binaries, archives, debug logs, or files from a retired
# engine if a caller supplies a pre-existing bundle directory.
$allowedRelativePaths = New-Object 'System.Collections.Generic.HashSet[string]' `
    ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($relativePath in @($required)) {
    [void]$allowedRelativePaths.Add($relativePath.Replace('\', '/'))
}
$bundleFiles = @(Get-ChildItem -LiteralPath $OutputDir -Recurse -File)
$unexpectedFiles = @($bundleFiles | Where-Object {
    $relative = $_.FullName.Substring($OutputDir.Length + 1).Replace('\', '/')
    -not $allowedRelativePaths.Contains($relative)
})
if ($unexpectedFiles.Count -gt 0) {
    throw "Release bundle contains unapproved files: $($unexpectedFiles.FullName -join ', ')"
}

$legacyManifestPath = Join-Path $OutputDir "licenses\audio_manifest_v1.json"
if (Test-Path -LiteralPath $legacyManifestPath) {
    throw "Release bundle must not ship the legacy audio_manifest_v1.json."
}
$audioManifestPath = Join-Path $OutputDir "licenses\audio_manifest_v2.json"
$audioManifest = Get-Content -Raw -LiteralPath $audioManifestPath | ConvertFrom-Json
if ([int]$audioManifest.version -ne 2 -or [string]$audioManifest.schema -ne "curated-audio-v2") {
    throw "Release bundle audio manifest is not curated-audio-v2."
}
$sourceAudioManifestPath = Join-Path $RepoRoot "godot\audio\audio_manifest_v2.json"
if (-not (Test-Path -LiteralPath $sourceAudioManifestPath -PathType Leaf)) {
    throw "Source audio manifest is missing: $sourceAudioManifestPath"
}
$sourceAudioManifestHash = (Get-FileHash -LiteralPath $sourceAudioManifestPath -Algorithm SHA256).Hash
$bundleAudioManifestHash = (Get-FileHash -LiteralPath $audioManifestPath -Algorithm SHA256).Hash
if ($sourceAudioManifestHash -ne $bundleAudioManifestHash) {
    throw "Release bundle audio manifest does not match the source manifest (source=$sourceAudioManifestHash bundle=$bundleAudioManifestHash)."
}
if (@($audioManifest.assets).Count -lt 32) {
    throw "Release bundle audio manifest contains too few curated assets."
}
$releaseSfx = @($audioManifest.assets | Where-Object { $_.kind -eq "sfx" })
$semanticSfx = @($releaseSfx | Where-Object {
    $_.PSObject.Properties.Name -contains "semantic_category" -and
        -not [string]::IsNullOrWhiteSpace($_.semantic_category)
})
$retiredPunch = @($releaseSfx | Where-Object { $_.source_file -match "(?i)impactPunch" })
$sourcePackages = @($audioManifest.source_packages.PSObject.Properties)
if ($releaseSfx.Count -lt 27 -or $semanticSfx.Count -lt 18 -or
        $sourcePackages.Count -lt 6 -or $retiredPunch.Count -ne 0) {
    throw "Release audio contract regressed (SFX=$($releaseSfx.Count), semantic=$($semanticSfx.Count), packages=$($sourcePackages.Count), punch=$($retiredPunch.Count))."
}
$requiredAudioCategories = @(
    "weapon_impact", "shield_guard", "spell_cast", "recovery", "status",
    "phase_change", "victory", "defeat"
)
foreach ($category in $requiredAudioCategories) {
    if (@($semanticSfx | Where-Object { $_.semantic_category -eq $category }).Count -eq 0) {
        throw "Release audio manifest is missing semantic category: $category"
    }
}

$forbidden = @(Get-ChildItem -LiteralPath $OutputDir -Recurse -File | Where-Object {
    $_.Extension -match '^(?i)\.(c|cc|cpp|cxx|h|hh|hpp|hxx|obj|gguf|safetensors|zip)$' -or
    $_.Name -match '^(?i)(llama-completion\.exe|adapter_config\.json)$'
})
if ($forbidden.Count -gt 0) {
    throw "Release bundle contains source, model, training, or runtime payloads that must stay on-demand: $($forbidden.FullName -join ', ')"
}

# Godot resource paths remain visible in the PCK directory table even when
# payloads are compressed. Catch retired content that slipped through an
# all-resources export without unpacking or executing the bundle.
$pckPath = Join-Path $OutputDir "wendao-changsheng.pck"
$pckText = [System.Text.Encoding]::UTF8.GetString(
    [System.IO.File]::ReadAllBytes($pckPath))
$declaredAudioPaths = @($audioManifest.assets | ForEach-Object {
    $runtimePath = [string]$_.runtime_path
    if (-not $runtimePath.StartsWith("res://audio/")) {
        throw "Release audio manifest contains an invalid runtime path: $runtimePath"
    }
    $runtimePath.Substring(6).Replace('\', '/')
})
foreach ($declaredAudioPath in $declaredAudioPaths) {
    if (-not $pckText.Contains($declaredAudioPath)) {
        throw "Release PCK is missing a manifest-declared audio resource: $declaredAudioPath"
    }
}
$forbiddenPckMarkers = @(
    "audio/generated/",
    "audio_manifest_v1.json",
    "local_ai_bridge",
    "LocalAIBridge",
    "ai_engine/",
    "setup-local-ai"
)
foreach ($marker in $forbiddenPckMarkers) {
    if ($pckText.Contains($marker)) {
        throw "Release PCK contains retired or development-only content marker: $marker"
    }
}
$pckText = $null

$licenseText = [System.IO.File]::ReadAllText(
    (Join-Path $OutputDir "licenses\AGPL-3.0.txt"), [System.Text.Encoding]::UTF8)
if (-not $licenseText.Contains("GNU AFFERO GENERAL PUBLIC LICENSE")) {
    throw "Release bundle AGPL license text is invalid."
}
$checksumPath = Join-Path $OutputDir "checksums.sha256"
$checksumLines = @([System.IO.File]::ReadAllLines($checksumPath, [System.Text.Encoding]::UTF8) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$listed = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($line in $checksumLines) {
    if ($line -notmatch '^([A-Fa-f0-9]{64})  (.+)$') {
        throw "Invalid checksum line: $line"
    }
    $expected = $Matches[1].ToUpperInvariant()
    $relative = $Matches[2].Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $parentSegments = @($relative -split '[\\/]' | Where-Object { $_ -eq '..' })
    if ([System.IO.Path]::IsPathRooted($relative) -or
        $parentSegments.Count -gt 0) {
        throw "Checksum entry uses an absolute or parent-traversing path: $relative"
    }
    if (-not $listed.Add($relative)) {
        throw "Duplicate checksum entry: $relative"
    }
    $path = [System.IO.Path]::GetFullPath((Join-Path $OutputDir $relative))
    if (-not $path.StartsWith($OutputDir + [System.IO.Path]::DirectorySeparatorChar,
            [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Checksum entry escapes the release bundle: $relative"
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Checksum entry is missing from the release bundle: $relative"
    }
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ($actual -ne $expected) {
        throw "Release checksum mismatch: $relative"
    }
}

$bundleFiles = @($bundleFiles |
    Where-Object { $_.FullName -ne $checksumPath })
if ($listed.Count -ne $bundleFiles.Count) {
    $unlisted = @($bundleFiles | Where-Object {
        $relative = $_.FullName.Substring($OutputDir.Length + 1)
        -not $listed.Contains($relative)
    })
    throw "Release checksum coverage is incomplete: $($unlisted.FullName -join ', ')"
}

Write-Host "Release bundle verified: $($bundleFiles.Count) files, licenses present, no AI/model/runtime payload bundled."
