[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ArchiveName = "ffmpeg-n7.1-latest-win64-lgpl-7.1.zip"
$ArchiveSha256 = "985b3477e9a07399675f5923dcfdf57bae41b3ec0a7b2ad61d9be5e2da30c6b3"
$DownloadUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/$ArchiveName"

$Root = Split-Path -Parent $PSScriptRoot
$CacheDir = Join-Path $Root ".local\audio-encoder"
$ArchivePath = Join-Path $CacheDir $ArchiveName
$PartialPath = "$ArchivePath.partial"
$ExtractDir = Join-Path $CacheDir "ffmpeg-n7.1-lgpl-7.1"
$MarkerPath = Join-Path $ExtractDir ".archive-sha256"

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

if (Test-Path -LiteralPath $ArchivePath) {
    $actual = Get-FileSha256 $ArchivePath
    if ($actual -ne $ArchiveSha256) {
        Write-Warning "Discarding FFmpeg archive with unexpected SHA-256: $ArchivePath"
        Remove-Item -LiteralPath $ArchivePath -Force
    }
}

if (-not (Test-Path -LiteralPath $ArchivePath)) {
    Write-Host "Downloading the pinned FFmpeg 7.1 LGPL audio encoder..."
    $bits = Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue
    if ($null -ne $bits) {
        try {
            Start-BitsTransfer -Source $DownloadUrl -Destination $PartialPath `
                -DisplayName "Wendao FFmpeg 7.1 audio encoder" -Description "Pinned LGPL generation tool"
        } catch {
            Write-Warning "BITS download failed; falling back to curl: $($_.Exception.Message)"
            Remove-Item -LiteralPath $PartialPath -Force -ErrorAction SilentlyContinue
            $bits = $null
        }
    }
    if ($null -eq $bits) {
        $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
        if ($null -ne $curl) {
            & $curl.Source --fail --location --retry 5 --retry-all-errors --retry-delay 3 `
                --continue-at - --output $PartialPath $DownloadUrl
            if ($LASTEXITCODE -ne 0) {
                throw "curl failed with exit code $LASTEXITCODE while downloading $DownloadUrl"
            }
        } else {
            Invoke-WebRequest -UseBasicParsing -Uri $DownloadUrl -OutFile $PartialPath
        }
    }
    $actual = Get-FileSha256 $PartialPath
    if ($actual -ne $ArchiveSha256) {
        Remove-Item -LiteralPath $PartialPath -Force
        throw "FFmpeg SHA-256 mismatch. Expected $ArchiveSha256, got $actual. The upstream 'latest' asset may have changed; update this pin only after reviewing the new LGPL build."
    }
    Move-Item -LiteralPath $PartialPath -Destination $ArchivePath -Force
}

$extractedHash = ""
if (Test-Path -LiteralPath $MarkerPath) {
    $extractedHash = (Get-Content -LiteralPath $MarkerPath -Raw).Trim().ToLowerInvariant()
}
if ($extractedHash -ne $ArchiveSha256) {
    if (Test-Path -LiteralPath $ExtractDir) {
        $resolvedCache = [IO.Path]::GetFullPath($CacheDir).TrimEnd('\') + '\'
        $resolvedExtract = [IO.Path]::GetFullPath($ExtractDir)
        if (-not $resolvedExtract.StartsWith($resolvedCache, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to replace an extraction directory outside the audio cache: $resolvedExtract"
        }
        Remove-Item -LiteralPath $ExtractDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $ExtractDir | Out-Null
    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $ExtractDir -Force
    Set-Content -LiteralPath $MarkerPath -Value $ArchiveSha256 -Encoding ASCII
}

$ffmpegCandidates = @(Get-ChildItem -LiteralPath $ExtractDir -Recurse -File -Filter "ffmpeg.exe")
if ($ffmpegCandidates.Count -ne 1) {
    throw "Expected exactly one ffmpeg.exe in the verified archive, found $($ffmpegCandidates.Count)."
}
$FfmpegPath = $ffmpegCandidates[0].FullName
$versionOutput = @(& $FfmpegPath -hide_banner -version)
$versionExitCode = $LASTEXITCODE
$version = ($versionOutput | Select-Object -First 1).Trim()
if ($versionExitCode -ne 0 -or $version -notmatch '^ffmpeg version n7\.1') {
    throw "Unexpected FFmpeg build: $version"
}

Write-Host "Audio encoder ready: $version"
[pscustomobject]@{
    Executable = $FfmpegPath
    Version = $version
    ArchiveSha256 = $ArchiveSha256
    Cache = $CacheDir
}
