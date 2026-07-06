param(
    [switch]$CheckOnly,
    [switch]$Force,
    [string]$ModelPath = "",
    [string]$ModelUrl = "https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf/resolve/main/gemma-4-E4B_q4_0-it.gguf?download=true",
    [string]$ExpectedModelSha256 = "E8B6A059BA86947A44ACE84D6E5679795BC41862C25C30513142588F0E9DBA1D",
    [switch]$SkipModelHash,
    [string]$RuntimeUrl = "https://github.com/ggml-org/llama.cpp/releases/download/b9843/llama-b9843-bin-win-cpu-x64.zip",
    [string]$ExpectedRuntimeZipSha256 = "8EBF156B4543FC8B0A4C3D1FC5CBD952516646AF0CFABB74D1E53BD86321F1E0"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Root = Split-Path -Parent $PSScriptRoot
$ModelDir = Join-Path $PSScriptRoot "models"
$RuntimeDir = Join-Path $PSScriptRoot "runtime"
$LlamaDir = Join-Path $RuntimeDir "llama.cpp"
$LoraDir = Join-Path $PSScriptRoot "lora"
if ([string]::IsNullOrWhiteSpace($ModelPath)) {
    $ModelPath = Join-Path $ModelDir "gemma-4-E4B_q4_0-it.gguf"
} elseif (-not [System.IO.Path]::IsPathRooted($ModelPath)) {
    $ModelPath = Join-Path $PSScriptRoot $ModelPath
}
$ModelPath = [System.IO.Path]::GetFullPath($ModelPath)
$RuntimeZip = Join-Path $RuntimeDir "llama-b9843-bin-win-cpu-x64.zip"
$LlamaCli = Join-Path $LlamaDir "llama-completion.exe"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
}

function Format-Bytes {
    param([long]$Bytes)

    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N1} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Assert-Hash {
    param(
        [string]$Path,
        [string]$Expected,
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label missing: $Path"
    }

    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actual -ne $Expected.ToUpperInvariant()) {
        throw "$Label SHA256 mismatch. Expected $Expected, got $actual"
    }
    Write-Host "$Label hash OK: $actual"
}

function Download-File {
    param(
        [string]$Url,
        [string]$OutFile,
        [string]$Label
    )

    if ($CheckOnly) {
        throw "$Label is missing and CheckOnly was set: $OutFile"
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    $tempFile = "$OutFile.part"
    if (Test-Path -LiteralPath $tempFile) {
        Remove-Item -LiteralPath $tempFile -Force
    }

    Write-Host "Downloading: $Label"
    Write-Host $Url

    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.AllowAutoRedirect = $true
    $request.UserAgent = "WendaoChangshengSetup/1.0"
    $request.Timeout = 30000
    $request.ReadWriteTimeout = 30000

    $response = $null
    $inputStream = $null
    $outputStream = $null
    $activity = "Downloading $Label"
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $lastProgressMs = 0
    $downloaded = [long]0

    try {
        $response = $request.GetResponse()
        $total = [long]$response.ContentLength
        $inputStream = $response.GetResponseStream()
        $outputStream = [System.IO.File]::Open($tempFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $buffer = New-Object byte[] (1024 * 1024)

        while (($read = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $outputStream.Write($buffer, 0, $read)
            $downloaded += $read

            if (($stopwatch.ElapsedMilliseconds - $lastProgressMs) -ge 250) {
                $elapsedSeconds = [Math]::Max(0.1, $stopwatch.Elapsed.TotalSeconds)
                $speed = [long]($downloaded / $elapsedSeconds)
                if ($total -gt 0) {
                    $percent = [Math]::Min(100, [Math]::Round(($downloaded * 100.0) / $total, 1))
                    Write-Progress -Activity $activity -Status "$(Format-Bytes $downloaded) / $(Format-Bytes $total)  $(Format-Bytes $speed)/s" -PercentComplete $percent
                } else {
                    Write-Progress -Activity $activity -Status "$(Format-Bytes $downloaded)  $(Format-Bytes $speed)/s"
                }
                $lastProgressMs = $stopwatch.ElapsedMilliseconds
            }
        }
    } finally {
        if ($outputStream) { $outputStream.Dispose() }
        if ($inputStream) { $inputStream.Dispose() }
        if ($response) { $response.Dispose() }
        Write-Progress -Activity $activity -Completed
    }

    Move-Item -LiteralPath $tempFile -Destination $OutFile -Force
}

Write-Host "Wendao portable AI setup"
Write-Host "Project: $Root"
Write-Host "Existing files are reused. Use -Force to download again."
Write-Host ""

$modelExists = Test-Path -LiteralPath $ModelPath
if ($Force -or -not $modelExists) {
    Download-File -Url $ModelUrl -OutFile $ModelPath -Label "Gemma 4 E4B QAT Q4_0 GGUF model"
} else {
    Write-Host "Model exists, skip download: $ModelPath"
}

$skipModelHashCheck = [bool]$SkipModelHash
if (-not $skipModelHashCheck) {
    $skipModelHashCheck = [string]::IsNullOrWhiteSpace($ExpectedModelSha256)
}
if ($skipModelHashCheck) {
    Write-Host "Model hash check skipped. Use this only for trusted local model files."
}
if (-not $skipModelHashCheck) {
    Assert-Hash -Path $ModelPath -Expected $ExpectedModelSha256 -Label "Model"
}

$runtimeReady = (Test-Path -LiteralPath $LlamaCli)
$runtimeDownloaded = $false
if (-not $Force -and $runtimeReady) {
    Write-Host "llama.cpp runtime exists, skip download: $LlamaCli"
} else {
    if ($Force -or -not (Test-Path -LiteralPath $RuntimeZip)) {
        Download-File -Url $RuntimeUrl -OutFile $RuntimeZip -Label "llama.cpp Windows CPU runtime"
        $runtimeDownloaded = $true
    } else {
        Write-Host "Runtime zip exists, skip download: $RuntimeZip"
    }
    $skipRuntimeHashCheck = [string]::IsNullOrWhiteSpace($ExpectedRuntimeZipSha256)
    if ($skipRuntimeHashCheck) {
        Write-Host "Runtime zip hash check skipped."
    }
    if (-not $skipRuntimeHashCheck) {
        Assert-Hash -Path $RuntimeZip -Expected $ExpectedRuntimeZipSha256 -Label "Runtime zip"
    }
}

if ($Force -or $runtimeDownloaded -or -not $runtimeReady) {
    if ($CheckOnly) {
        throw "llama-completion.exe missing and CheckOnly was set: $LlamaCli"
    }

    Write-Host "Extracting llama.cpp runtime..."
    if (Test-Path -LiteralPath $LlamaDir) {
        Remove-Item -LiteralPath $LlamaDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $LlamaDir | Out-Null
    Expand-Archive -LiteralPath $RuntimeZip -DestinationPath $LlamaDir -Force
}

if (-not (Test-Path -LiteralPath $LlamaCli)) {
    throw "llama-completion.exe was not found after setup: $LlamaCli"
}

Write-Host ""
Write-Host "Portable AI base is ready."
Write-Host "Model: $ModelPath"
Write-Host "Runtime: $LlamaCli"

$loraFiles = @()
if (Test-Path -LiteralPath $LoraDir) {
    $loraFiles = @(Get-ChildItem -LiteralPath $LoraDir -Filter "*.gguf" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending)
}
if ($loraFiles.Count -gt 0) {
    Write-Host "Current LoRA: $($loraFiles[0].FullName)"
}
if ($loraFiles.Count -eq 0) {
    Write-Host "No LoRA adapter found. The base model will be used first."
    Write-Host "Put ai_engine\lora\*.gguf here later; the newest adapter is selected automatically."
}
