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
    "wendao-ark.txt",
    "game-version.json",
    "checksums.sha256",
    "licenses\AGPL-3.0.txt",
    "licenses\NotoSansSC-OFL.txt",
    "licenses\NotoSerifSC-OFL.txt",
    "licenses\font_manifest.json"
)
foreach ($relativePath in $required) {
    $path = Join-Path $OutputDir $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Release bundle is missing: $relativePath"
    }
}

$productMarker = (Get-Content -Raw -LiteralPath (Join-Path $OutputDir "wendao-ark.txt")).Trim()
if ($productMarker -cne "WENDAO_ARK_3D_PRODUCT_V1") {
    throw "This is not an identified 3D Ark release; refusing a stale legacy executable."
}

& python -X utf8 (Join-Path $PSScriptRoot "game_version.py") --verify (Join-Path $OutputDir "game-version.json")
if ($LASTEXITCODE -ne 0) { throw "Game version metadata validation failed: $LASTEXITCODE" }

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

# Retained font provenance and legal notices must match the source exactly.
foreach ($name in @("NotoSansSC-OFL.txt", "NotoSerifSC-OFL.txt", "font_manifest.json")) {
    $source = Join-Path $RepoRoot "godot\art\fonts\$name"
    $bundled = Join-Path $OutputDir "licenses\$name"
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $bundled -Algorithm SHA256).Hash) {
        throw "Release font license/provenance differs from source: $name"
    }
}

$forbidden = @(Get-ChildItem -LiteralPath $OutputDir -Recurse -File | Where-Object {
    $_.Extension -match '^(?i)\.(c|cc|cpp|cxx|h|hh|hpp|hxx|obj|gguf|safetensors|zip)$' -or
    $_.Name -match '^(?i)(llama-completion\.exe|adapter_config\.json)$'
})
if ($forbidden.Count -gt 0) {
    throw "Release bundle contains source, model, training, or runtime payloads that must stay on-demand: $($forbidden.FullName -join ', ')"
}

# Parse the actual PCK directory and verify every payload checksum. An allowlist
# permits only the six Ark scripts, two scenes, ocean shader and retained fonts;
# tests, archives, legacy audio/data/art and arbitrary resources fail closed.
& python -X utf8 (Join-Path $PSScriptRoot "verify_migration_surface.py") --pack (Join-Path $OutputDir "wendao-changsheng.pck")
if ($LASTEXITCODE -ne 0) { throw "Exported Ark PCK boundary failed: $LASTEXITCODE" }

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

Write-Host "ARK_RELEASE_BUNDLE_OK: $($bundleFiles.Count) files, font/AGPL licenses and complete checksums, Ark-only PCK."
