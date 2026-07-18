param(
    [switch]$CheckOnly,
    [switch]$Force,
    [string]$ModelPath = "",
    [string]$ModelUrl = "https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf/resolve/99ef3d9bbf819591699ffa9084c4be12db1fbe6c/gemma-4-E4B_q4_0-it.gguf?download=true",
    [string]$ModelMirrorUrl = "https://hf-mirror.com/google/gemma-4-E4B-it-qat-q4_0-gguf/resolve/99ef3d9bbf819591699ffa9084c4be12db1fbe6c/gemma-4-E4B_q4_0-it.gguf?download=true",
    [string]$ExpectedModelSha256 = "E8B6A059BA86947A44ACE84D6E5679795BC41862C25C30513142588F0E9DBA1D",
    [switch]$SkipModelHash,
    [string]$LoraPath = "",
    [string]$LoraUrl = "https://github.com/Iukulete/wendao-changsheng/releases/download/lora-v7/wendao_gemma4_lora_text_v7_codex_filtered.gguf",
    [string]$LoraMirrorUrl = "https://ghproxy.net/https://github.com/Iukulete/wendao-changsheng/releases/download/lora-v7/wendao_gemma4_lora_text_v7_codex_filtered.gguf",
    [string]$LoraMirrorUrl2 = "https://ghfast.top/https://github.com/Iukulete/wendao-changsheng/releases/download/lora-v7/wendao_gemma4_lora_text_v7_codex_filtered.gguf",
    [string]$ExpectedLoraSha256 = "36D286CFEC617F33325B60F378C7478414CDBE884D30188708D8A2F0B0A9F3FF",
    [switch]$SkipLoraHash,
    [string]$RuntimeUrl = "https://github.com/ggml-org/llama.cpp/releases/download/b10066/llama-b10066-bin-win-vulkan-x64.zip",
    [string]$RuntimeMirrorUrl = "https://ghproxy.net/https://github.com/ggml-org/llama.cpp/releases/download/b10066/llama-b10066-bin-win-vulkan-x64.zip",
    [string]$RuntimeMirrorUrl2 = "https://ghfast.top/https://github.com/ggml-org/llama.cpp/releases/download/b10066/llama-b10066-bin-win-vulkan-x64.zip",
    [string]$ExpectedRuntimeZipSha256 = "57CB5DD3143B2814B8D1D14587867628BFB126536ABFA7085CA9560C4919D998"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Root = Split-Path -Parent $PSScriptRoot
$ModelDir = Join-Path $PSScriptRoot "models"
$RuntimeDir = Join-Path $PSScriptRoot "runtime"
$LlamaDir = Join-Path $RuntimeDir "vulkan"
$LoraDir = Join-Path $PSScriptRoot "lora"
$DefaultLoraName = "wendao_gemma4_lora_text_v7_codex_filtered.gguf"
if ([string]::IsNullOrWhiteSpace($ModelPath)) {
    $ModelPath = Join-Path $ModelDir "gemma-4-E4B_q4_0-it.gguf"
} elseif (-not [System.IO.Path]::IsPathRooted($ModelPath)) {
    $ModelPath = Join-Path $PSScriptRoot $ModelPath
}
$ModelPath = [System.IO.Path]::GetFullPath($ModelPath)
if ([string]::IsNullOrWhiteSpace($LoraPath)) {
    $LoraPath = Join-Path $LoraDir $DefaultLoraName
} elseif (-not [System.IO.Path]::IsPathRooted($LoraPath)) {
    $LoraPath = Join-Path $PSScriptRoot $LoraPath
}
$LoraPath = [System.IO.Path]::GetFullPath($LoraPath)
if ([string]::IsNullOrWhiteSpace($LoraUrl)) {
    $LoraUrl = [Environment]::GetEnvironmentVariable("WENDAO_LORA_URL")
}
$RuntimeZip = Join-Path $RuntimeDir "llama-b10066-bin-win-vulkan-x64.zip"
$LlamaCli = Join-Path $LlamaDir "llama-completion.exe"
$RuntimeVersionMarker = Join-Path $LlamaDir ".runtime-archive-sha256"

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
        [string[]]$Urls,
        [string]$OutFile,
        [string]$Label
    )

    if ($CheckOnly) {
        throw "$Label is missing and CheckOnly was set: $OutFile"
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    $tempFile = "$OutFile.part"
    $sourceMarker = "$tempFile.source"
    $downloadUrls = @($Urls | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($downloadUrls.Count -eq 0) {
        throw "No download URL is configured for $Label"
    }
    $sourceFingerprint = $downloadUrls -join "`n"
    $storedFingerprint = ""
    if (Test-Path -LiteralPath $sourceMarker) {
        $storedFingerprint = [System.IO.File]::ReadAllText($sourceMarker, [System.Text.Encoding]::UTF8)
    }
    if ((Test-Path -LiteralPath $tempFile) -and $storedFingerprint -ne $sourceFingerprint) {
        Write-Host "Discarding a partial download from a different pinned source."
        Remove-Item -LiteralPath $tempFile -Force
    }
    [System.IO.File]::WriteAllText($sourceMarker, $sourceFingerprint, (New-Object System.Text.UTF8Encoding($false)))

    Write-Host "Downloading: $Label"
    if (Test-Path -LiteralPath $tempFile) {
        Write-Host "Resuming partial download: $tempFile ($(Format-Bytes (Get-Item -LiteralPath $tempFile).Length))"
    }

    $curl = Get-Command "curl.exe" -ErrorAction SilentlyContinue
    if ($null -ne $curl) {
        $curlErrors = New-Object System.Collections.Generic.List[string]
        foreach ($url in $downloadUrls) {
            Write-Host $url
            for ($attempt = 1; $attempt -le 4; $attempt++) {
                $beforeBytes = if (Test-Path -LiteralPath $tempFile) {
                    (Get-Item -LiteralPath $tempFile).Length
                } else {
                    [long]0
                }
                & $curl.Source `
                    --location `
                    --fail `
                    --connect-timeout 15 `
                    --speed-limit 1024 `
                    --speed-time 90 `
                    --continue-at - `
                    --output $tempFile `
                    $url
                if ($LASTEXITCODE -eq 0) {
                    Move-Item -LiteralPath $tempFile -Destination $OutFile -Force
                    Remove-Item -LiteralPath $sourceMarker -Force -ErrorAction SilentlyContinue
                    return
                }
                $afterBytes = if (Test-Path -LiteralPath $tempFile) {
                    (Get-Item -LiteralPath $tempFile).Length
                } else {
                    [long]0
                }
                $curlErrors.Add("$url attempt $attempt (curl exit $LASTEXITCODE, $beforeBytes -> $afterBytes bytes)")
                if ($attempt -lt 4) {
                    Write-Warning "Download connection ended; resuming the same partial file."
                    Start-Sleep -Seconds 2
                }
            }
            Write-Warning "Download endpoint failed; trying the next pinned source."
        }
        throw "$Label download failed from every configured endpoint: $($curlErrors -join '; ')"
    }

    $webErrors = New-Object System.Collections.Generic.List[string]
    foreach ($url in $downloadUrls) {
        Write-Host $url

        $request = [System.Net.HttpWebRequest]::Create($url)
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
        $downloadSucceeded = $false

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
            $downloadSucceeded = $true
        } catch {
            $webErrors.Add("$url ($($_.Exception.Message))")
            Write-Warning "Download endpoint failed; trying the next pinned source."
        } finally {
            if ($outputStream) { $outputStream.Dispose() }
            if ($inputStream) { $inputStream.Dispose() }
            if ($response) { $response.Dispose() }
            Write-Progress -Activity $activity -Completed
        }
        if ($downloadSucceeded) {
            Move-Item -LiteralPath $tempFile -Destination $OutFile -Force
            Remove-Item -LiteralPath $sourceMarker -Force -ErrorAction SilentlyContinue
            return
        }
    }
    throw "$Label download failed from every configured endpoint: $($webErrors -join '; ')"
}

Write-Host "Wendao portable AI setup"
Write-Host "Project: $Root"
Write-Host "Existing files are reused. Use -Force to download again."
Write-Host ""

$modelExists = Test-Path -LiteralPath $ModelPath
if ($Force -or -not $modelExists) {
    Download-File -Urls @($ModelUrl, $ModelMirrorUrl) -OutFile $ModelPath -Label "Gemma 4 E4B QAT Q4_0 GGUF model"
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

$existingLoraFiles = @()
if (Test-Path -LiteralPath $LoraDir) {
    $existingLoraFiles = @(Get-ChildItem -LiteralPath $LoraDir -Filter "*.gguf" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 4096 } |
        Sort-Object LastWriteTimeUtc -Descending)
}
$targetLoraExists = Test-Path -LiteralPath $LoraPath
$fallbackLora = $null
if (-not $targetLoraExists -and $existingLoraFiles.Count -gt 0) {
    $fallbackLora = $existingLoraFiles[0]
}
$loraExists = $targetLoraExists -or ([string]::IsNullOrWhiteSpace($LoraUrl) -and $null -ne $fallbackLora)
if ($Force -or -not $loraExists) {
    if ([string]::IsNullOrWhiteSpace($LoraUrl)) {
        if ($CheckOnly) {
            throw "LoRA adapter missing and CheckOnly was set: $LoraPath"
        }
        Write-Host "No LoRA download URL configured. The base model will be used first."
        Write-Host "Set WENDAO_LORA_URL or pass -LoraUrl to download an adapter automatically."
    } else {
        Download-File -Urls @($LoraUrl, $LoraMirrorUrl, $LoraMirrorUrl2) -OutFile $LoraPath -Label "Wendao LoRA adapter"
    }
} elseif ($targetLoraExists) {
    Write-Host "LoRA adapter exists, skip download: $LoraPath"
} else {
    Write-Host "LoRA adapter exists, skip download: $($fallbackLora.FullName)"
}

$skipLoraHashCheck = [bool]$SkipLoraHash
if (-not $skipLoraHashCheck) {
    $skipLoraHashCheck = [string]::IsNullOrWhiteSpace($ExpectedLoraSha256)
}
if ($skipLoraHashCheck) {
    Write-Host "LoRA hash check skipped."
} elseif (Test-Path -LiteralPath $LoraPath) {
    Assert-Hash -Path $LoraPath -Expected $ExpectedLoraSha256 -Label "LoRA"
}

$runtimeMarker = ""
if (Test-Path -LiteralPath $RuntimeVersionMarker) {
    $runtimeMarker = ([System.IO.File]::ReadAllText(
        $RuntimeVersionMarker, [System.Text.Encoding]::UTF8)).Trim()
}
$runtimeReady = (Test-Path -LiteralPath $LlamaCli) -and
    $runtimeMarker -eq $ExpectedRuntimeZipSha256.ToUpperInvariant()
$runtimeDownloaded = $false
if (-not $Force -and $runtimeReady) {
    Write-Host "llama.cpp runtime exists, skip download: $LlamaCli"
} else {
    if ($Force -or -not (Test-Path -LiteralPath $RuntimeZip)) {
        Download-File -Urls @($RuntimeUrl, $RuntimeMirrorUrl, $RuntimeMirrorUrl2) -OutFile $RuntimeZip -Label "llama.cpp Windows Vulkan runtime"
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
    [System.IO.File]::WriteAllText(
        $RuntimeVersionMarker,
        $ExpectedRuntimeZipSha256.ToUpperInvariant(),
        (New-Object System.Text.UTF8Encoding($false)))
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
if (Test-Path -LiteralPath $LoraPath) {
    Write-Host "Current LoRA: $LoraPath"
} elseif ($loraFiles.Count -gt 0) {
    Write-Host "Current LoRA: $($loraFiles[0].FullName)"
}
if ($loraFiles.Count -eq 0) {
    Write-Host "No LoRA adapter found. The base model will be used first."
    Write-Host "Put ai_engine\lora\*.gguf here later; the newest adapter is selected automatically."
}
