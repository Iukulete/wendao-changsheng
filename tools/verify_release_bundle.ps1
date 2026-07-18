[CmdletBinding()]
param(
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

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
    "setup-local-ai.bat",
    "checksums.sha256",
    "ai_engine\setup_portable_ai.ps1",
    "ai_engine\generate_event.ps1",
    "ai_engine\test_local_ai.ps1",
    "ai_engine\THIRD_PARTY_AI.md",
    "licenses\AGPL-3.0.txt",
    "licenses\NotoSansSC-OFL.txt",
    "licenses\NotoSerifSC-OFL.txt",
    "licenses\LICENSE-AUDIO.txt",
    "licenses\audio_manifest_v1.json",
    "licenses\THIRD_PARTY_AI.md"
)
foreach ($relativePath in $required) {
    $path = Join-Path $OutputDir $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Release bundle is missing: $relativePath"
    }
}

$forbidden = @(Get-ChildItem -LiteralPath $OutputDir -Recurse -File | Where-Object {
    $_.Extension -match '^(?i)\.(c|cc|cpp|cxx|h|hh|hpp|hxx|obj|gguf|safetensors|zip)$' -or
    $_.Name -match '^(?i)(llama-completion\.exe|adapter_config\.json)$'
})
if ($forbidden.Count -gt 0) {
    throw "Release bundle contains source, model, training, or runtime payloads that must stay on-demand: $($forbidden.FullName -join ', ')"
}

$licenseText = [System.IO.File]::ReadAllText(
    (Join-Path $OutputDir "licenses\AGPL-3.0.txt"), [System.Text.Encoding]::UTF8)
if (-not $licenseText.Contains("GNU AFFERO GENERAL PUBLIC LICENSE")) {
    throw "Release bundle AGPL license text is invalid."
}
$aiNotice = [System.IO.File]::ReadAllText(
    (Join-Path $OutputDir "licenses\THIRD_PARTY_AI.md"), [System.Text.Encoding]::UTF8)
foreach ($pinnedHash in @(
    "E8B6A059BA86947A44ACE84D6E5679795BC41862C25C30513142588F0E9DBA1D",
    "36D286CFEC617F33325B60F378C7478414CDBE884D30188708D8A2F0B0A9F3FF",
    "57CB5DD3143B2814B8D1D14587867628BFB126536ABFA7085CA9560C4919D998"
)) {
    if (-not $aiNotice.Contains($pinnedHash)) {
        throw "Release bundle AI notice is missing pinned hash $pinnedHash."
    }
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

$bundleFiles = @(Get-ChildItem -LiteralPath $OutputDir -Recurse -File |
    Where-Object { $_.FullName -ne $checksumPath })
if ($listed.Count -ne $bundleFiles.Count) {
    $unlisted = @($bundleFiles | Where-Object {
        $relative = $_.FullName.Substring($OutputDir.Length + 1)
        -not $listed.Contains($relative)
    })
    throw "Release checksum coverage is incomplete: $($unlisted.FullName -join ', ')"
}

Write-Host "Release bundle verified: $($bundleFiles.Count) files, licenses and on-demand AI installer present, no model/runtime payload bundled."
