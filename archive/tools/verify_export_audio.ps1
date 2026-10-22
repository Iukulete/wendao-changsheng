[CmdletBinding()]
param(
    [string]$ExePath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ExePath)) {
    $ExePath = Join-Path $Root "release\godot\windows\wendao-changsheng.exe"
}
$ExePath = [IO.Path]::GetFullPath($ExePath)
if (-not (Test-Path -LiteralPath $ExePath)) {
    throw "Exported executable was not found: $ExePath"
}

$DataDir = Join-Path $Root ".tmp\godot\export-audio-device-userdata"
$GameName = -join (@(0x95EE, 0x9053, 0x957F, 0x751F, 0x20, 0x00B7, 0x20, 0x795E, 0x6E38, 0x7248) |
    ForEach-Object { [char]$_ })
$UserDir = Join-Path $DataDir ("Godot\app_userdata\" + $GameName)
$StdoutPath = Join-Path $Root ".tmp\godot\export-audio-device.stdout.log"
$StderrPath = Join-Path $Root ".tmp\godot\export-audio-device.stderr.log"
New-Item -ItemType Directory -Force -Path $UserDir | Out-Null
$settings = @(
    "[audio]",
    "muted=true",
    "mute_unfocused=true",
    "master=100.0",
    "music=72.0",
    "ambience=62.0",
    "sfx=86.0",
    "ui=74.0",
    "vo=100.0",
    "night_mode=false",
    "reduce_sudden=false",
    "mono=false"
) -join [Environment]::NewLine
[IO.File]::WriteAllText((Join-Path $UserDir "audio_settings.cfg"), $settings,
    [Text.UTF8Encoding]::new($false))
Remove-Item -LiteralPath $StdoutPath, $StderrPath -Force -ErrorAction SilentlyContinue

$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = $DataDir
    $env:LOCALAPPDATA = $DataDir
    # The actual Windows window is placed far outside the desktop work area.
    # Audio is muted in the persisted game settings before launch, while the
    # real default audio driver and playback lifecycle are still exercised.
    $process = Start-Process -FilePath $ExePath -WorkingDirectory (Split-Path $ExePath) `
        -ArgumentList "--verbose", "--audio-driver", "WASAPI", `
            "--display-driver", "windows", `
            "--rendering-method", "gl_compatibility", "--position", "-32000,-32000", `
            "--resolution", "640x360", "--quit-after", "600", "--", "--audio-smoke" `
        -WindowStyle Hidden -RedirectStandardOutput $StdoutPath `
        -RedirectStandardError $StderrPath -PassThru -Wait
}
finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

$stdout = Get-Content -LiteralPath $StdoutPath -Raw -ErrorAction SilentlyContinue
$stderr = Get-Content -LiteralPath $StderrPath -Raw -ErrorAction SilentlyContinue
if ($process.ExitCode -ne 0 -or $stdout -match '(?m)^(SCRIPT ERROR|ERROR):' -or
        $stderr -match '(?m)^(SCRIPT ERROR|ERROR):') {
    Write-Host $stdout
    Write-Host $stderr
    throw "Off-screen exported audio-device smoke failed with exit code $($process.ExitCode)."
}
if ($stdout -notmatch 'AUDIO_DEVICE_SMOKE_READY: driver=WASAPI display=windows') {
    Write-Host $stdout
    throw "The exported build did not report a live WASAPI/Windows backend."
}
$driver = "WASAPI"
if ($stdout -notmatch 'AUDIO_DEVICE_MUSIC_SMOKE_OK: era=steam state=decisive pressure_voices=2 decisive_voices=2 ambience_transition_voices=2 ambience_transition_streams=2 ambience_settled_voices=1 ambience_settled_streams=1 rare_cue=true') {
    Write-Host $stdout
    throw "The exported build did not complete real-backend Ogg music transitions."
}
if ($stdout -notmatch 'AUDIO_DEVICE_SHUTDOWN_OK: players_stopped streams_released') {
    Write-Host $stdout
    throw "The exported build did not complete deterministic audio resource shutdown."
}
Write-Host "Exported Windows audio-device, dual-player music, and shared ambience-bed smoke passed off-screen and muted (driver=$driver)."
