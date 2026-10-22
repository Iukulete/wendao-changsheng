[CmdletBinding()]
param([switch]$NoPrepare, [switch]$SkipVerify)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$Root = Split-Path -Parent $PSScriptRoot
$ProjectDir = Join-Path $Root "godot"
$OutputDir = Join-Path $Root "release\godot\windows"
$OutputExe = Join-Path $OutputDir "wendao-changsheng.exe"
$OutputPck = Join-Path $OutputDir "wendao-changsheng.pck"
$OutputLicenseDir = Join-Path $OutputDir "licenses"
$ChecksumPath = Join-Path $OutputDir "checksums.sha256"
$ConsolePath = Join-Path $Root "tools\godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe"
$TempDir = Join-Path $Root ".tmp\godot-build"

$releaseRoot = [System.IO.Path]::GetFullPath((Join-Path $Root "release"))
$resolvedOutputDir = [System.IO.Path]::GetFullPath($OutputDir)
if (-not $resolvedOutputDir.StartsWith($releaseRoot + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean unexpected output directory: $resolvedOutputDir"
}
if ([System.IO.Path]::GetPathRoot($Root) -ine "D:\") {
    throw "Windows project, release and validation data must remain on D:."
}
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
$env:TEMP = $TempDir
$env:TMP = $TempDir

function Invoke-CheckedGodot {
    param([string]$Executable, [string[]]$Arguments, [string]$Name,
          [int]$TimeoutSeconds = 600, [string]$Marker = "")
    $stdout = Join-Path $TempDir "$Name.stdout.log"
    $stderr = Join-Path $TempDir "$Name.stderr.log"
    $process = Start-Process -FilePath $Executable -ArgumentList $Arguments `
        -WorkingDirectory $Root -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill()
        throw "$Name timed out after $TimeoutSeconds seconds; process terminated."
    }
    $process.WaitForExit()
    $text = ([System.IO.File]::ReadAllText($stdout) + "`n" + [System.IO.File]::ReadAllText($stderr))
    Write-Host $text
    $plain = [regex]::Replace($text, '\x1b\[[0-?]*[ -/]*[@-~]', '')
    if ($process.ExitCode -ne 0 -or $plain -match '(?m)^\s*(SCRIPT ERROR|ERROR|FATAL ERROR|USER ERROR):' -or
        ($Marker -and $plain -notmatch ('(?m)^\s*' + [regex]::Escape($Marker)))) {
        throw "$Name failed: exit=$($process.ExitCode), marker=$Marker. Logs: $TempDir"
    }
}

if (-not $NoPrepare) {
    & (Join-Path $PSScriptRoot "prepare_godot.ps1")
    if ($LASTEXITCODE -ne 0) { throw "Pinned Godot preparation failed: $LASTEXITCODE" }
}
$version = (& $ConsolePath --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.7\.1\.stable\.official\.[0-9a-f]+$') {
    throw "Godot version drift detected: $version"
}
# Even when CI already ran regressions, never bypass the source/archive boundary.
foreach ($guard in @("verify_migration_surface.py", "verify_source_archive.py")) {
    & python -X utf8 (Join-Path $PSScriptRoot $guard)
    if ($LASTEXITCODE -ne 0) { throw "Release boundary guard failed ($guard): $LASTEXITCODE" }
}
if (-not $SkipVerify) {
    & (Join-Path $PSScriptRoot "verify_godot.ps1") -NoPrepare
    if ($LASTEXITCODE -ne 0) { throw "Ark validation failed: $LASTEXITCODE" }
}
if (Test-Path -LiteralPath $resolvedOutputDir) {
    Remove-Item -LiteralPath $resolvedOutputDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDir | Out-Null
Write-Host "Exporting the active 3D Ark Windows x86_64 build..."
Invoke-CheckedGodot -Executable $ConsolePath -Name "windows-export" -Arguments @(
    "--headless", "--audio-driver", "Dummy", "--path", "`"$ProjectDir`"",
    "--export-release", '"Windows Desktop"', "`"$OutputExe`"")
if (-not (Test-Path -LiteralPath $OutputExe) -or -not (Test-Path -LiteralPath $OutputPck)) {
    throw "Godot reported success without both Windows EXE and resource pack."
}
$exeSize = (Get-Item -LiteralPath $OutputExe).Length
$pckSize = (Get-Item -LiteralPath $OutputPck).Length
if ($exeSize -lt 1MB -or $pckSize -lt 1KB) {
    throw "Export artifacts look incomplete (EXE=$exeSize bytes, PCK=$pckSize bytes)."
}
& python -X utf8 (Join-Path $PSScriptRoot "game_version.py") --write (Join-Path $OutputDir "game-version.json")
if ($LASTEXITCODE -ne 0) { throw "Game version metadata generation failed: $LASTEXITCODE" }
New-Item -ItemType Directory -Force -Path $OutputLicenseDir | Out-Null
Copy-Item -LiteralPath (Join-Path $Root "LICENSE") -Destination (Join-Path $OutputLicenseDir "AGPL-3.0.txt") -Force
foreach ($licenseName in @("NotoSansSC-OFL.txt", "NotoSerifSC-OFL.txt", "font_manifest.json")) {
    Copy-Item -LiteralPath (Join-Path $ProjectDir "art\fonts\$licenseName") `
        -Destination (Join-Path $OutputLicenseDir $licenseName) -Force
}
Copy-Item -LiteralPath (Join-Path $Root "docs\WINDOWS_RELEASE_README.md") `
    -Destination (Join-Path $OutputDir "README.md") -Force

# Test the actual Windows EXE, not the editor. No audio hardware or third-party
# driver is needed by the Ark. Its menu must initialize without writing a save.
$SmokeDataDir = Join-Path $TempDir "export-smoke-userdata"
New-Item -ItemType Directory -Force -Path $SmokeDataDir | Out-Null
$previousAppData, $previousLocalAppData = $env:APPDATA, $env:LOCALAPPDATA
try {
    $env:APPDATA = $SmokeDataDir
    $env:LOCALAPPDATA = $SmokeDataDir
    Invoke-CheckedGodot -Executable $OutputExe -Name "windows-export-smoke" -TimeoutSeconds 120 `
        -Marker "ARK_MENU_READY_OK:" -Arguments @("--headless", "--audio-driver", "Dummy", "--quit-after", "5")
} finally {
    $env:APPDATA, $env:LOCALAPPDATA = $previousAppData, $previousLocalAppData
}
# The launcher will not open a stale retired 2D EXE lacking this product marker.
[System.IO.File]::WriteAllText((Join-Path $OutputDir "wendao-ark.txt"), "WENDAO_ARK_3D_PRODUCT_V1`r`n", [System.Text.Encoding]::ASCII)
$checksumLines = @(Get-ChildItem -LiteralPath $OutputDir -Recurse -File |
    Where-Object { $_.FullName -ne $ChecksumPath } | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($OutputDir.Length + 1).Replace('\', '/')
        "$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)  $relative"
    })
[System.IO.File]::WriteAllLines($ChecksumPath, $checksumLines, (New-Object System.Text.UTF8Encoding($false)))
try {
    & (Join-Path $PSScriptRoot "verify_release_bundle.ps1") -OutputDir $OutputDir
    if ($LASTEXITCODE -ne 0) { throw "Release bundle validation failed: $LASTEXITCODE" }
} catch {
    # Never leave a failed/incomplete build eligible for the launcher fast path.
    Remove-Item -LiteralPath (Join-Path $OutputDir "wendao-ark.txt") -Force -ErrorAction SilentlyContinue
    throw
}
Write-Host "ARK_WINDOWS_BUILD_OK: $OutputExe ($exeSize bytes), $OutputPck ($pckSize bytes)"
Get-FileHash -LiteralPath $OutputExe, $OutputPck -Algorithm SHA256 | Select-Object Path, Hash
