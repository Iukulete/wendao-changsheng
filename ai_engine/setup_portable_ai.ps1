param(
    [switch]$CheckOnly,
    [switch]$Force,
    [string]$ModelUrl = "https://huggingface.co/bartowski/Qwen_Qwen3-0.6B-GGUF/resolve/main/Qwen_Qwen3-0.6B-Q4_K_M.gguf?download=true",
    [string]$RuntimeUrl = "https://github.com/ggml-org/llama.cpp/releases/download/b9803/llama-b9803-bin-win-cpu-x64.zip"
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
$ModelPath = Join-Path $ModelDir "Qwen_Qwen3-0.6B-Q4_K_M.gguf"
$RuntimeZip = Join-Path $RuntimeDir "llama-b9803-bin-win-cpu-x64.zip"
$LlamaCli = Join-Path $LlamaDir "llama-cli.exe"

$ExpectedModelSha256 = "9ACFC1E001311F34B4252001B626F2E466D592A42065F66571BFF3790D4E1B14"
$ExpectedRuntimeZipSha256 = "4D942D5FCB7F3AB026844208306C5EEBECF4530F4E52EED5C4717DBDF9FE3C5D"

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
    Write-Host "$Label OK: $actual"
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

    Write-Host "Downloading $Label..."
    Write-Host $Url
    Invoke-WebRequest -Uri $Url -OutFile $tempFile -UseBasicParsing
    Move-Item -LiteralPath $tempFile -Destination $OutFile -Force
}

Write-Host "Wendao portable AI setup"
Write-Host "Project: $Root"

if ($Force -or -not (Test-Path -LiteralPath $ModelPath)) {
    Download-File -Url $ModelUrl -OutFile $ModelPath -Label "Qwen3 0.6B GGUF model"
} else {
    Write-Host "Model exists: $ModelPath"
}
Assert-Hash -Path $ModelPath -Expected $ExpectedModelSha256 -Label "Model"

if ($Force -or -not (Test-Path -LiteralPath $RuntimeZip)) {
    Download-File -Url $RuntimeUrl -OutFile $RuntimeZip -Label "llama.cpp Windows CPU runtime"
} else {
    Write-Host "Runtime zip exists: $RuntimeZip"
}
Assert-Hash -Path $RuntimeZip -Expected $ExpectedRuntimeZipSha256 -Label "Runtime zip"

if ($Force -or -not (Test-Path -LiteralPath $LlamaCli)) {
    if ($CheckOnly) {
        throw "llama-cli.exe missing and CheckOnly was set: $LlamaCli"
    }

    Write-Host "Extracting llama.cpp runtime..."
    if (Test-Path -LiteralPath $LlamaDir) {
        Remove-Item -LiteralPath $LlamaDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $LlamaDir | Out-Null
    Expand-Archive -LiteralPath $RuntimeZip -DestinationPath $LlamaDir -Force
} else {
    Write-Host "llama.cpp runtime exists: $LlamaCli"
}

if (-not (Test-Path -LiteralPath $LlamaCli)) {
    throw "llama-cli.exe was not found after setup: $LlamaCli"
}

Write-Host ""
Write-Host "Portable AI is ready."
Write-Host "Model: $ModelPath"
Write-Host "Runtime: $LlamaCli"
