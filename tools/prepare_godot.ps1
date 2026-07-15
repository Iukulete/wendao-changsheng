[CmdletBinding()]
param(
    [switch]$SkipTemplates
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$GodotVersion = "4.7.1"
$GodotRelease = "4.7.1-stable"
$GodotTemplateVersion = "4.7.1.stable"
$EngineArchiveName = "Godot_v4.7.1-stable_win64.exe.zip"
$TemplateArchiveName = "Godot_v4.7.1-stable_export_templates.tpz"
$EngineSha256 = "c7a289051eaefb460b0106b60e9cd5bee0ef55fd102dcb2bed1eb356cf3d90a1"
$TemplateSha256 = "86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72"
$ReleaseBaseUrl = "https://github.com/godotengine/godot-builds/releases/download/$GodotRelease"
$TemplateDownloadUrl = "https://downloads.godotengine.org/?flavor=stable&platform=templates&slug=export_templates.tpz&version=$GodotVersion"

$Root = Split-Path -Parent $PSScriptRoot
$EngineDir = Join-Path $Root "tools\godot\$GodotVersion"
$TempDir = Join-Path $Root ".tmp\godot"
$EngineArchive = Join-Path $EngineDir $EngineArchiveName
$TemplateArchive = Join-Path $EngineDir $TemplateArchiveName
$EnginePath = Join-Path $EngineDir "Godot_v4.7.1-stable_win64.exe"
$ConsolePath = Join-Path $EngineDir "Godot_v4.7.1-stable_win64_console.exe"
$TemplateDir = Join-Path $EngineDir "editor_data\export_templates\$GodotTemplateVersion"
$TemplateMarker = Join-Path $TemplateDir ".archive-sha256"
$WindowsTemplate = Join-Path $TemplateDir "windows_release_x86_64.exe"

New-Item -ItemType Directory -Force -Path $EngineDir, $TempDir | Out-Null
$env:TEMP = $TempDir
$env:TMP = $TempDir

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-VerifiedDownload {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256
    )

    if (Test-Path -LiteralPath $Path) {
        $actual = Get-FileSha256 $Path
        if ($actual -eq $ExpectedSha256) {
            Write-Host "Verified cached archive: $Path"
            return
        }
        Write-Warning "Discarding archive with unexpected SHA-256: $Path"
        Remove-Item -LiteralPath $Path -Force
    }

    $partial = "$Path.partial"
    Write-Host "Downloading official Godot archive: $Uri"

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($null -ne $curl) {
        & $curl.Source --fail --location --retry 5 --retry-all-errors --retry-delay 3 --continue-at - --output $partial $Uri
        if ($LASTEXITCODE -ne 0) {
            throw "curl failed with exit code $LASTEXITCODE while downloading $Uri"
        }
    } else {
        Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $partial
    }

    $actual = Get-FileSha256 $partial
    if ($actual -ne $ExpectedSha256) {
        Remove-Item -LiteralPath $partial -Force
        throw "SHA-256 mismatch for $Uri. Expected $ExpectedSha256, got $actual."
    }

    Move-Item -LiteralPath $partial -Destination $Path -Force
    Write-Host "Verified SHA-256: $ExpectedSha256"
}

function Expand-TemplateArchive {
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $destinationRoot = [System.IO.Path]::GetFullPath($Destination).TrimEnd('\') + '\'
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        foreach ($entry in $archive.Entries) {
            $relative = $entry.FullName.Replace('/', '\')
            if ($relative.StartsWith("templates\", [System.StringComparison]::OrdinalIgnoreCase)) {
                $relative = $relative.Substring("templates\".Length)
            }
            if ([string]::IsNullOrWhiteSpace($relative)) {
                continue
            }

            $target = [System.IO.Path]::GetFullPath((Join-Path $Destination $relative))
            if (-not $target.StartsWith($destinationRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Unsafe path in export-template archive: $($entry.FullName)"
            }

            if ([string]::IsNullOrEmpty($entry.Name)) {
                New-Item -ItemType Directory -Force -Path $target | Out-Null
                continue
            }

            $targetDirectory = Split-Path -Parent $target
            New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
        }
    } finally {
        $archive.Dispose()
    }
}

Get-VerifiedDownload `
    -Uri "$ReleaseBaseUrl/$EngineArchiveName" `
    -Path $EngineArchive `
    -ExpectedSha256 $EngineSha256

if (-not (Test-Path -LiteralPath $EnginePath) -or -not (Test-Path -LiteralPath $ConsolePath)) {
    Write-Host "Extracting Godot $GodotVersion editor..."
    Expand-Archive -LiteralPath $EngineArchive -DestinationPath $EngineDir -Force
}

# Godot's self-contained marker keeps editor settings, import metadata and
# export templates beside the portable editor instead of under C:\Users.
$SelfContainedMarker = Join-Path $EngineDir "_sc_"
if (-not (Test-Path -LiteralPath $SelfContainedMarker)) {
    Set-Content -LiteralPath $SelfContainedMarker -Value "Wendao portable Godot environment" -Encoding ASCII
}

$reportedVersion = (& $ConsolePath --version | Select-Object -First 1).Trim()
if ($reportedVersion -notmatch '^4\.7\.1\.stable\.official\.') {
    throw "Unexpected Godot version: $reportedVersion"
}
Write-Host "Godot editor ready: $reportedVersion"

if (-not $SkipTemplates) {
    Get-VerifiedDownload `
        -Uri $TemplateDownloadUrl `
        -Path $TemplateArchive `
        -ExpectedSha256 $TemplateSha256

    $templateReady = (Test-Path -LiteralPath $WindowsTemplate) -and
        (Test-Path -LiteralPath $TemplateMarker) -and
        ((Get-Content -LiteralPath $TemplateMarker -Raw).Trim() -eq $TemplateSha256)

    if (-not $templateReady) {
        Write-Host "Installing verified export templates into the D-drive portable environment..."
        Expand-TemplateArchive -ArchivePath $TemplateArchive -Destination $TemplateDir
        if (-not (Test-Path -LiteralPath $WindowsTemplate)) {
            throw "Windows x86_64 release template was not found after extraction: $WindowsTemplate"
        }
        Set-Content -LiteralPath $TemplateMarker -Value $TemplateSha256 -Encoding ASCII
    }
    Write-Host "Windows export template ready: $WindowsTemplate"
}

[pscustomobject]@{
    Version = $reportedVersion
    Engine = $ConsolePath
    Templates = if ($SkipTemplates) { "skipped" } else { $TemplateDir }
    PortableData = (Join-Path $EngineDir "editor_data")
}
