param(
    [string]$ReleaseDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "release"),
    [string]$Model = "wendao-xiuxian",
    [string]$ModelPath = (Join-Path $PSScriptRoot "models\Qwen_Qwen3-0.6B-Q4_K_M.gguf"),
    [string]$LlamaCli = (Join-Path $PSScriptRoot "runtime\llama.cpp\llama-cli.exe"),
    [int]$PortableTimeoutSec = 25,
    [int]$OllamaTimeoutSec = 20,
    [ValidateSet("auto", "portable", "ollama")]
    [string]$Backend = "auto"
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ReleaseDir = [System.IO.Path]::GetFullPath($ReleaseDir)
$ModelPath = [System.IO.Path]::GetFullPath($ModelPath)
$LlamaCli = [System.IO.Path]::GetFullPath($LlamaCli)

$promptPath = Join-Path $ReleaseDir "ai_prompt.txt"
$eventPath = Join-Path $ReleaseDir "ai_event.txt"
$rawPath = Join-Path $ReleaseDir "ai_event_raw.txt"
$backendPath = Join-Path $ReleaseDir "ai_backend.txt"
$statusPath = Join-Path $ReleaseDir "ai_status.txt"
$llamaLogPath = Join-Path $ReleaseDir "ai_llama.log"
$ollamaLogPath = Join-Path $ReleaseDir "ai_ollama.log"
$encoding = New-Object System.Text.UTF8Encoding($false)

function Write-StatusFile {
    param(
        [string]$BackendLabel,
        [string]$StatusText
    )

    if ($BackendLabel) {
        [System.IO.File]::WriteAllText($backendPath, $BackendLabel, $encoding)
    }
    if ($StatusText) {
        [System.IO.File]::WriteAllText($statusPath, $StatusText, $encoding)
    }
}

if (-not (Test-Path -LiteralPath $promptPath)) {
    throw "Missing prompt file: $promptPath"
}

$prompt = [System.IO.File]::ReadAllText($promptPath, [System.Text.Encoding]::UTF8)
$prompt = "/no_think`n" + $prompt + "`n严格只输出5行：标题、描述、选项一、选项二、选项三。不要解释。"

function Invoke-PortableLlama {
    if (-not (Test-Path -LiteralPath $LlamaCli)) {
        throw "Missing llama.cpp executable: $LlamaCli"
    }
    if (-not (Test-Path -LiteralPath $ModelPath)) {
        throw "Missing GGUF model: $ModelPath"
    }

    $runtimePromptPath = [System.IO.Path]::GetFullPath((Join-Path $ReleaseDir "ai_prompt_runtime.txt"))
    [System.IO.File]::WriteAllText($runtimePromptPath, $prompt, [System.Text.Encoding]::UTF8)

    $args = @(
        "-m", $ModelPath,
        "-f", $runtimePromptPath,
        "-n", "120",
        "-c", "4096",
        "--temp", "0.85",
        "--top-p", "0.9",
        "--repeat-penalty", "1.12",
        "--reasoning", "off",
        "--single-turn",
        "--no-display-prompt",
        "--no-warmup",
        "--no-perf",
        "--no-show-timings",
        "--simple-io"
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $LlamaCli
    $psi.WorkingDirectory = Split-Path -Parent $LlamaCli
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.Arguments = (($args | ForEach-Object {
        if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
    }) -join ' ')

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()

    if (-not $process.WaitForExit($PortableTimeoutSec * 1000)) {
        try { $process.Kill() } catch {}
        $stderr = $process.StandardError.ReadToEnd()
        if ($stderr) {
            [System.IO.File]::WriteAllText($llamaLogPath, $stderr, $encoding)
        }
        throw "llama.cpp timed out after ${PortableTimeoutSec}s"
    }

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    if ($stderr) {
        [System.IO.File]::WriteAllText($llamaLogPath, $stderr, $encoding)
    }
    if ($process.ExitCode -ne 0) {
        throw "llama.cpp exited with code $($process.ExitCode)"
    }

    return $stdout
}

function Invoke-Ollama {
    $body = @{
        model = $Model
        prompt = $prompt
        stream = $false
        think = $false
        options = @{
            temperature = 0.85
            top_p = 0.9
            repeat_penalty = 1.12
            num_predict = 180
        }
    } | ConvertTo-Json -Depth 6

    try {
        $response = Invoke-RestMethod `
            -Uri "http://127.0.0.1:11434/api/generate" `
            -Method Post `
            -ContentType "application/json" `
            -Body $body `
            -TimeoutSec $OllamaTimeoutSec
    } catch {
        [System.IO.File]::WriteAllText($ollamaLogPath, $_.Exception.ToString(), $encoding)
        throw
    }

    return [string]$response.response
}

$text = ""
$usedBackend = ""
$errors = @()

if ($Backend -eq "auto" -or $Backend -eq "portable") {
    try {
        $text = Invoke-PortableLlama
        $usedBackend = "portable-llama.cpp"
        Write-StatusFile -BackendLabel $usedBackend -StatusText "便携模型生成成功。"
    } catch {
        $errors += "portable: $($_.Exception.Message)"
        Write-StatusFile -BackendLabel "portable-llama.cpp" -StatusText "便携模型失败：$($_.Exception.Message)"
        if ($Backend -eq "portable") { throw }
    }
}

if ([string]::IsNullOrWhiteSpace($text) -and ($Backend -eq "auto" -or $Backend -eq "ollama")) {
    try {
        $text = Invoke-Ollama
        $usedBackend = "ollama:$Model"
        Write-StatusFile -BackendLabel $usedBackend -StatusText "Ollama 生成成功。"
    } catch {
        $errors += "ollama: $($_.Exception.Message)"
        Write-StatusFile -BackendLabel "ollama:$Model" -StatusText "Ollama 失败：$($_.Exception.Message)"
        if ($Backend -eq "ollama") { throw }
    }
}

if ([string]::IsNullOrWhiteSpace($text)) {
    Write-StatusFile -BackendLabel "模板回退" -StatusText "未获取有效模型输出，已回退到内置模板。$($errors -join '; ')"
    throw "No AI backend generated text. $($errors -join '; ')"
}

[System.IO.File]::WriteAllText($backendPath, $usedBackend, $encoding)
[System.IO.File]::WriteAllText($statusPath, "已生成动态事件。", $encoding)
[System.IO.File]::WriteAllText($rawPath, $text, $encoding)
$text = [regex]::Replace($text, "(?s)<think>.*?</think>", "")
$text = [regex]::Replace($text, "(?s)Thinking.*?done thinking\.", "")
$text = [regex]::Replace($text, "(?s)^.*?\.\.\. \(truncated\)\s*", "")
$text = [regex]::Replace($text, "(?m)^Loading model\.\.\.\s*$", "")
$text = [regex]::Replace($text, "(?m)^available commands:.*$", "")
$text = [regex]::Replace($text, "(?m)^\s*/(?:exit|regen|clear|read|glob).*$", "")
$text = [regex]::Replace($text, "(?m)^build\s+:.*$", "")
$text = [regex]::Replace($text, "(?m)^model\s+:.*$", "")
$text = [regex]::Replace($text, "(?m)^modalities\s+:.*$", "")
$text = [regex]::Replace($text, "(?m)^Exiting\.\.\.\s*$", "")
$text = [regex]::Replace($text, "(?m)^[▄▀█\s]+$", "")
$text = [regex]::Replace($text, "(?m)^\s*>\s*$", "")

function Normalize-EventLine {
    param([string]$Line)

    $clean = $Line.Trim()
    $clean = [regex]::Replace($clean, '^```(?:text|markdown)?\s*', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $clean = [regex]::Replace($clean, '\s*```$', '')
    $clean = [regex]::Replace($clean, '\*\*', '')
    $clean = $clean.Trim(@([char]96, [char]34, [char]39))
    $clean = [regex]::Replace($clean, '^\s*[-*]\s*', '')
    $clean = [regex]::Replace($clean, '^[A-Za-z][\.、:：\)]\s*', '')
    $clean = [regex]::Replace($clean, '^第[一二三四五六七八九十0-9]+行[:：]\s*', '')
    $clean = [regex]::Replace($clean, '^(标题|事件标题|描述|事件描述|选项[一二三四五六七八九十0-9]*|选项一|选项二|选项三|选择[一二三四五六七八九十0-9]*)[:：]\s*', '')
    $clean = [regex]::Replace($clean, '^\s*[-*0-9一二三四五]+[\.、:：\)]\s*', '')
    $clean = [regex]::Replace($clean, '\s+', ' ')
    return $clean.Trim()
}

$lines = @()
foreach ($line in ($text -split "`r?`n")) {
    $clean = Normalize-EventLine $line
    if ($clean -match "^(下面|以下|好的|输出|格式|事件如下|生成)") {
        continue
    }
    if ($clean -match "^(请选择|请从|请在|选择如下|选项如下)\s*[:：]?\s*$") {
        continue
    }
    if ($clean.Length -gt 0) {
        $lines += $clean
    }
}

if ($lines.Count -gt 0 -and $lines.Count -lt 5) {
    $fallbackChoices = @("上前探查", "谨慎观望", "转身离开")
    if ($lines.Count -lt 2) {
        $lines += "你行至灵雾深处，忽见旧日因果化作一缕微光，似在引你踏入未知之局。"
    }
    while ($lines.Count -lt 5) {
        $lines += $fallbackChoices[$lines.Count - 2]
    }
}

if ($lines.Count -lt 5) {
    $flat = [regex]::Replace($text, "\s+", " ").Trim()
    if ($flat.Length -gt 0) {
        $lines = @("【奇遇】命中一线", $flat.Substring(0, [Math]::Min(80, $flat.Length)), "主动探查", "谨慎观察", "转身离开")
    } else {
        $lines = @("【奇遇】无名山径", "你走入一条被雾气遮蔽的山径，隐约听见有人呼唤你的道号。", "循声前行", "原地观望", "立刻离开")
    }
}

$lines = $lines[0..4]
$title = $lines[0]
$title = Normalize-EventLine $title
$title = [regex]::Replace($title, "^【机遇】", "【机缘】")
if ($title -notmatch "^【(机缘|危机|奇遇|因果|传承)】") {
    $tag = "【奇遇】"
    if ($title -match "机缘") { $tag = "【机缘】" }
    elseif ($title -match "机遇") { $tag = "【机缘】" }
    elseif ($title -match "危机") { $tag = "【危机】" }
    elseif ($title -match "因果") { $tag = "【因果】" }
    elseif ($title -match "传承") { $tag = "【传承】" }
    $title = [regex]::Replace($title, "^【[^】]+】\s*", "")
    $title = [regex]::Replace($title, "^(机缘|机遇|危机|奇遇|因果|传承)\s*", "")
    if ($title.Length -lt 2) { $title = "命中一线" }
    $title = $tag + $title
}
$title = [regex]::Replace($title, "^(【(?:机缘|危机|奇遇|因果|传承)】)\s+", '$1')
$lines[0] = $title

$description = Normalize-EventLine $lines[1]
$description = [regex]::Replace($description, "\s*(请选择|选择)[:：]?.*$", "")
if ($description.Length -gt 110) {
    $description = $description.Substring(0, 110)
}
if ($description.Length -lt 12 -or $description -match "^(请选择|选择|选项)") {
    $description = "你行至灵雾深处，忽见旧日因果化作一缕微光，似在引你踏入未知之局。"
}
$lines[1] = $description

for ($i = 2; $i -lt 5; $i++) {
    $choice = Normalize-EventLine $lines[$i]
    $choice = [regex]::Replace($choice, "^(请选择|选择|你选择|决定)\s*", "")
    $choice = [regex]::Replace($choice, "[。！？!?，,；;：:]+$", "")
    $choiceParts = $choice -split "[，,；;。！？!?]"
    if ($choiceParts.Count -gt 1) {
        $firstPart = $choiceParts[0].Trim()
        if ($firstPart.Length -ge 2 -and $firstPart.Length -le 8) {
            $choice = $firstPart
        }
    }
    if ($choice.Length -lt 2 -or $choice -match "^(请选择|选项|解释)") {
        $fallbackChoices = @("上前探查", "谨慎观望", "转身离开")
        $choice = $fallbackChoices[$i - 2]
    }
    if ($choice.Length -gt 8) {
        $choice = $choice.Substring(0, 8)
    }
    $lines[$i] = $choice
}

[System.IO.File]::WriteAllText($eventPath, ($lines -join [Environment]::NewLine), $encoding)
Write-StatusFile -BackendLabel $usedBackend -StatusText "已生成 1 条动态事件并写入 ai_event.txt。"
Write-Output "Generated $eventPath"
