param(
    [string]$ReleaseDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "release"),
    [string]$Model = "gemma3:4b",
    [string]$ModelPath = "",
    [string]$LoraPath = "",
    [string]$LlamaCli = (Join-Path $PSScriptRoot "runtime\llama.cpp\llama-completion.exe"),
    [int]$PortableTimeoutSec = 75,
    [int]$OllamaTimeoutSec = 90,
    [ValidateSet("auto", "portable", "ollama")]
    [string]$Backend = "portable"
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Resolve-ConfiguredPath {
    param(
        [string]$ExplicitPath,
        [string]$EnvName,
        [string]$ConfigFile,
        [string]$DefaultPath
    )

    $candidate = $ExplicitPath
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = [Environment]::GetEnvironmentVariable($EnvName)
    }
    if ([string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $ConfigFile)) {
        $candidate = ([System.IO.File]::ReadAllText($ConfigFile, [System.Text.Encoding]::UTF8)).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = $DefaultPath
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        return ""
    }
    if ([System.IO.Path]::IsPathRooted($candidate)) {
        return [System.IO.Path]::GetFullPath($candidate)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $candidate))
}

function Resolve-AutoLoraPath {
    $loraDir = Join-Path $PSScriptRoot "lora"
    if (-not (Test-Path -LiteralPath $loraDir)) {
        return ""
    }

    $adapters = @(Get-ChildItem -LiteralPath $loraDir -Filter "*.gguf" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 4096 })
    if ($adapters.Count -eq 0) {
        return ""
    }

    $preferred = @($adapters | Where-Object { $_.Name -match "^(wendao|问道)" })
    if ($preferred.Count -gt 0) {
        $adapters = $preferred
    }

    $selected = $adapters | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    return [System.IO.Path]::GetFullPath($selected.FullName)
}

$ReleaseDir = [System.IO.Path]::GetFullPath($ReleaseDir)
$ModelPath = Resolve-ConfiguredPath `
    -ExplicitPath $ModelPath `
    -EnvName "WENDAO_GGUF_MODEL" `
    -ConfigFile (Join-Path $PSScriptRoot "model_path.txt") `
    -DefaultPath (Join-Path $PSScriptRoot "models\gemma-4-E4B_q4_0-it.gguf")
$LoraPath = Resolve-ConfiguredPath `
    -ExplicitPath $LoraPath `
    -EnvName "WENDAO_LORA_PATH" `
    -ConfigFile (Join-Path $PSScriptRoot "lora_path.txt") `
    -DefaultPath ""
if ([string]::IsNullOrWhiteSpace($LoraPath)) {
    $LoraPath = Resolve-AutoLoraPath
} elseif (-not (Test-Path -LiteralPath $LoraPath)) {
    $LoraPath = Resolve-AutoLoraPath
}
$LlamaCli = [System.IO.Path]::GetFullPath($LlamaCli)

$promptPath = Join-Path $ReleaseDir "ai_prompt.txt"
$eventPath = Join-Path $ReleaseDir "ai_event.txt"
$rawPath = Join-Path $ReleaseDir "ai_event_raw.txt"
$scenePath = Join-Path $ReleaseDir "ai_scene.json"
$backendPath = Join-Path $ReleaseDir "ai_backend.txt"
$statusPath = Join-Path $ReleaseDir "ai_status.txt"
$llamaLogPath = Join-Path $ReleaseDir "ai_llama.log"
$ollamaLogPath = Join-Path $ReleaseDir "ai_ollama.log"
$loraDisablePath = Join-Path $ReleaseDir "ai_lora_disabled.txt"
$encoding = New-Object System.Text.UTF8Encoding($false)

Get-ChildItem -LiteralPath $ReleaseDir -Filter "ai_llama_*.tmp" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddMinutes(-5) } |
    Remove-Item -Force -ErrorAction SilentlyContinue

function Get-AdapterFingerprint {
    param([string]$AdapterPath)

    if ([string]::IsNullOrWhiteSpace($AdapterPath) -or -not (Test-Path -LiteralPath $AdapterPath)) {
        return ""
    }

    $file = Get-Item -LiteralPath $AdapterPath -ErrorAction Stop
    return ([System.IO.Path]::GetFullPath($file.FullName) + "|" + $file.Length + "|" + $file.LastWriteTimeUtc.Ticks)
}

function Test-AdapterDisabled {
    param([string]$AdapterPath)

    if (-not (Test-Path -LiteralPath $loraDisablePath)) {
        return $false
    }

    $fingerprint = Get-AdapterFingerprint $AdapterPath
    if ([string]::IsNullOrWhiteSpace($fingerprint)) {
        return $false
    }

    try {
        $record = [System.IO.File]::ReadAllText($loraDisablePath, [System.Text.Encoding]::UTF8)
        return $record.Contains($fingerprint)
    } catch {
        return $false
    }
}

function Disable-AdapterForCurrentRun {
    param(
        [string]$AdapterPath,
        [string]$Reason
    )

    $fingerprint = Get-AdapterFingerprint $AdapterPath
    if ([string]::IsNullOrWhiteSpace($fingerprint)) {
        return
    }

    try {
        $record = $fingerprint + "`n" + $Reason
        [System.IO.File]::WriteAllText($loraDisablePath, $record, $encoding)
    } catch {
    }
}

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

$basePrompt = [System.IO.File]::ReadAllText($promptPath, [System.Text.Encoding]::UTF8)
$basePrompt = $basePrompt + "`n严格只输出5行：标题、描述、选项一、选项二、选项三。不要解释。标题和描述合计至少写入两个上下文专有词。"

function Add-ClippedPromptLine {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Line,
        [int]$MaxChars = 160
    )

    if ([string]::IsNullOrWhiteSpace($Line)) { return }
    if ($Line -match "隐藏设定|GenericAgent|provider|C\+\+|AI 可以") { return }
    $clean = [regex]::Replace($Line.Trim(), "\s+", " ")
    if ($clean.Length -gt $MaxChars) {
        $clean = $clean.Substring(0, $MaxChars) + "……"
    }
    if (-not $Lines.Contains($clean)) {
        [void]$Lines.Add($clean)
    }
}

function Test-FirstLifePrompt {
    param([string]$PromptText)
    if ([string]::IsNullOrWhiteSpace($PromptText)) { return $false }
    return $PromptText -match "第一世|第1世|Life:\s*first life|first life|尚无前世记忆|no past-life memory"
}

function Test-FirstLifeMemoryLeak {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return $Value -match "前世|轮回|转世|上一世|旧世|旧日因果|不该留下|今生抬头|旧梦归来|宿命回潮"
}

function Get-PromptSectionLines {
    param(
        [string[]]$Lines,
        [string]$StartPattern,
        [string[]]$StopPatterns,
        [int]$MaxLines = 12,
        [int]$MaxChars = 160
    )

    $out = New-Object System.Collections.Generic.List[string]
    $inside = $false
    foreach ($line in $Lines) {
        if (-not $inside) {
            if ($line -match $StartPattern) {
                $inside = $true
            } else {
                continue
            }
        } else {
            foreach ($stop in $StopPatterns) {
                if ($line -match $stop) {
                    return @($out)
                }
            }
        }
        Add-ClippedPromptLine $out $line $MaxChars
        if ($out.Count -ge $MaxLines) { break }
    }
    return @($out)
}

function Build-PortablePrompt {
    param([string]$PromptText)

    $sourceLines = @($PromptText -split "`r?`n")
    $out = New-Object System.Collections.Generic.List[string]
    Add-ClippedPromptLine $out "你是修仙Roguelike事件模型。严格只输出5行：标题、描述、选项一、选项二、选项三。" 200
    Add-ClippedPromptLine $out "标题以【机缘】【危机】【奇遇】【因果】【传承】之一开头；描述45到90个中文字符；三个选项各2到8个字。" 200
    Add-ClippedPromptLine $out "输出第5行后立刻停止；不要另起第二个事件，不要写model、assistant、解释、编号、项目符号或任何英文字母。" 220
    Add-ClippedPromptLine $out "优先延续本世人脉、家世、最近记忆、当前世界和未收束线头；NPC要像活人一样有情绪、目标、试探和后续动作。" 220
    Add-ClippedPromptLine $out "第一世只能写黑白旧玉、梦兆、早熟直觉和今生身世，不写明确前世记忆；低境界不能获得、装备或主动调用鸿蒙至宝。" 220
    Add-ClippedPromptLine $out "不要写UI、系统说明、按钮、编号、请选择；不要暴露隐藏设定或模型规则。" 180
    if (Test-FirstLifePrompt $PromptText) {
        Add-ClippedPromptLine $out "当前是第一世：只能写今生身世、父母师门、资质与黑白旧玉异样；不得写前世、轮回、转世或旧日因果。" 220
    }
    Add-ClippedPromptLine $out "" 1

    foreach ($line in $sourceLines) {
        if ($line -match "^(玩家|境界名称|因果|年龄|灵根|此世家世):") {
            Add-ClippedPromptLine $out $line 220
        }
    }

    foreach ($line in (Get-PromptSectionLines $sourceLines "^人情风波:" @("^轮回传承:","^通天灵宝:","^当前世界:") 18 190)) {
        Add-ClippedPromptLine $out $line 190
    }

    $worldPatterns = @(
        "当前世界:",
        "^- 时代纪元:",
        "^- 时代概况:",
        "^- 时代法则:",
        "^- 本世主线:",
        "^- 本世势力牵连:",
        "^\s*\* (伴生玉佩|玉意梦兆|师尊线推进|人情线推进|玉佩暗线推进|前世未竟推进|势力牵连|本世线索余波)",
        "^- 天机底线:",
        "^\s*\* (第一世|主角以今生选择|九大鸿蒙至宝)",
        "^- 近期因果摘要:",
        "^- 下一处因果钩子:",
        "^- 未收束线头:",
        "^- 人情压力:",
        "^- NPC 近况:",
        "^- 势力压力:",
        "^- 寿元压力:"
    )
    $inWorld = $false
    $worldCount = 0
    foreach ($line in $sourceLines) {
        if ($line -match "^当前世界:") { $inWorld = $true }
        if ($inWorld -and $line -match "^最近记忆:") { break }
        if (-not $inWorld) { continue }
        foreach ($pattern in $worldPatterns) {
            if ($line -match $pattern) {
                Add-ClippedPromptLine $out $line 190
                $worldCount++
                break
            }
        }
        if ($worldCount -ge 24) { break }
    }

    foreach ($line in (Get-PromptSectionLines $sourceLines "^最近记忆:" @("^严格只输出") 9 190)) {
        Add-ClippedPromptLine $out $line 190
    }

    Add-ClippedPromptLine $out "输出格式示例：" 80
    Add-ClippedPromptLine $out "【因果】桃枝问律" 80
    Add-ClippedPromptLine $out "清蘅真人隔着雨帘递来一枚旧符，问你愿不愿为行脚医修挡下古修问道宗的审查。" 120
    Add-ClippedPromptLine $out "接符应问" 40
    Add-ClippedPromptLine $out "暂避风声" 40
    Add-ClippedPromptLine $out "反查玉简" 40

    $joined = ($out | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n"
    if ($joined.Length -gt 3600) {
        $joined = $joined.Substring(0, 3600) + "`n严格只输出5行。"
    }
    return $joined
}

function Format-RuntimePrompt {
    param([string]$PromptText)

    $modelFile = [System.IO.Path]::GetFileName($ModelPath).ToLowerInvariant()
    if ($modelFile -match "gemma-4") {
        $portablePrompt = Build-PortablePrompt $PromptText
        return "<bos><|turn>user`n" + $portablePrompt.Trim() + "`n<turn|>`n<|turn>model`n"
    }
    return $PromptText
}

$runtimePrompt = Format-RuntimePrompt $basePrompt
$ollamaPrompt = $basePrompt

function ConvertTo-NativeArgument {
    param([AllowNull()][object]$Argument)

    if ($null -eq $Argument) { return '""' }
    $text = [string]$Argument
    if ($text.Length -eq 0) { return '""' }
    if ($text -notmatch '[\s"]') { return $text }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $backslashes = 0
    foreach ($ch in $text.ToCharArray()) {
        if ($ch -eq '\') {
            $backslashes++
            continue
        }
        if ($ch -eq '"') {
            if ($backslashes -gt 0) {
                [void]$builder.Append('\' * ($backslashes * 2))
                $backslashes = 0
            }
            [void]$builder.Append('\"')
            continue
        }
        if ($backslashes -gt 0) {
            [void]$builder.Append('\' * $backslashes)
            $backslashes = 0
        }
        [void]$builder.Append($ch)
    }
    if ($backslashes -gt 0) {
        [void]$builder.Append('\' * ($backslashes * 2))
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Join-NativeArguments {
    param([object[]]$Arguments)

    return (@($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join " ")
}

function Invoke-PortableLlama {
    param(
        [AllowNull()][string]$AdapterPath = $LoraPath,
        [int]$TimeoutSec = $PortableTimeoutSec
    )

    if (-not (Test-Path -LiteralPath $LlamaCli)) {
        throw "Missing llama.cpp executable: $LlamaCli"
    }
    if (-not (Test-Path -LiteralPath $ModelPath)) {
        throw "Missing GGUF model: $ModelPath"
    }

    $runtimePromptPath = [System.IO.Path]::GetFullPath((Join-Path $ReleaseDir "ai_prompt_runtime.txt"))
    [System.IO.File]::WriteAllText($runtimePromptPath, $runtimePrompt, [System.Text.Encoding]::UTF8)

    $args = @(
        "-m", $ModelPath,
        "-f", $runtimePromptPath,
        "-n", "80",
        "-c", "4096",
        "--temp", "0.65",
        "--top-p", "0.85",
        "--repeat-penalty", "1.08",
        "--reasoning", "off",
        "-no-cnv",
        "--single-turn",
        "--no-display-prompt",
        "--color", "off",
        "--no-warmup",
        "--no-perf",
        "--simple-io"
    )

    if (-not [string]::IsNullOrWhiteSpace($AdapterPath)) {
        if (-not (Test-Path -LiteralPath $AdapterPath)) {
            throw "Configured LoRA adapter was not found: $AdapterPath"
        }
        $args += @("--lora", $AdapterPath)
    }

    $stdoutTemp = [System.IO.Path]::GetFullPath((Join-Path $ReleaseDir ("ai_llama_stdout_" + [guid]::NewGuid().ToString("N") + ".tmp")))
    $stderrTemp = [System.IO.Path]::GetFullPath((Join-Path $ReleaseDir ("ai_llama_stderr_" + [guid]::NewGuid().ToString("N") + ".tmp")))
    $workingDir = Split-Path -Parent $LlamaCli

    try {
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $LlamaCli
        if ($null -ne $startInfo.ArgumentList) {
            foreach ($arg in $args) {
                [void]$startInfo.ArgumentList.Add($arg)
            }
        } else {
            $startInfo.Arguments = Join-NativeArguments $args
        }
        $startInfo.WorkingDirectory = $workingDir
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $startInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8

        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        if (-not $process.WaitForExit($TimeoutSec * 1000)) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $stderr = ""
            try { $stderr = $stderrTask.GetAwaiter().GetResult() } catch {}
            if ($stderr) {
                [System.IO.File]::WriteAllText($llamaLogPath, $stderr, $encoding)
            }
            throw "llama.cpp timed out after ${TimeoutSec}s"
        }

        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($stderr) {
            [System.IO.File]::WriteAllText($llamaLogPath, $stderr, $encoding)
        }
        if ($process.ExitCode -ne 0) {
            throw "llama.cpp exited with code $($process.ExitCode)"
        }

        return $stdout
    } finally {
        if (Test-Path -LiteralPath $stdoutTemp) {
            Remove-Item -LiteralPath $stdoutTemp -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $stderrTemp) {
            Remove-Item -LiteralPath $stderrTemp -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-Ollama {
    function Repair-MojibakeText {
        param([string]$Value)

        if ([string]::IsNullOrWhiteSpace($Value)) {
            return $Value
        }
        if ($Value -notmatch "[\u0080-\u00ff]") {
            return $Value
        }

        try {
            $latin1 = [System.Text.Encoding]::GetEncoding(28591)
            $bytes = $latin1.GetBytes($Value)
            $decoded = [System.Text.Encoding]::UTF8.GetString($bytes)
            if (($decoded -match "[\u4e00-\u9fff]") -or ($decoded -match "【|】")) {
                return $decoded
            }
        } catch {
        }

        return $Value
    }

    $numPredict = 220
    $thinkSetting = $false

    $body = @{
        model = $Model
        prompt = $ollamaPrompt
        stream = $false
        think = $thinkSetting
        options = @{
            temperature = 0.65
            top_p = 0.85
            repeat_penalty = 1.08
            num_predict = $numPredict
        }
    } | ConvertTo-Json -Depth 6
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

    try {
        $response = Invoke-RestMethod `
            -Uri "http://127.0.0.1:11434/api/generate" `
            -Method Post `
            -ContentType "application/json; charset=utf-8" `
            -Body $bodyBytes `
            -TimeoutSec $OllamaTimeoutSec
    } catch {
        [System.IO.File]::WriteAllText($ollamaLogPath, $_.Exception.ToString(), $encoding)
        throw
    }

    $responseText = [string]$response.response
    if ([string]::IsNullOrWhiteSpace($responseText) -and $null -ne $response.message) {
        $responseText = [string]$response.message.content
    }
    return Repair-MojibakeText $responseText
}

$text = ""
$usedBackend = ""
$errors = @()

if ([string]::IsNullOrWhiteSpace($text) -and ($Backend -eq "auto" -or $Backend -eq "portable")) {
    try {
        $usedBackend = "portable-llama.cpp:" + [System.IO.Path]::GetFileName($ModelPath)
        $activeLoraPath = $LoraPath
        if (Test-AdapterDisabled $activeLoraPath) {
            $errors += "portable-lora: disabled after previous failure"
            $activeLoraPath = ""
        }

        if ([string]::IsNullOrWhiteSpace($activeLoraPath)) {
            $text = Invoke-PortableLlama -AdapterPath "" -TimeoutSec $PortableTimeoutSec
            if ([string]::IsNullOrWhiteSpace($text)) {
                throw "llama.cpp returned empty text"
            }
            Write-StatusFile -BackendLabel $usedBackend -StatusText "已生成动态事件。"
        } else {
            try {
                $loraTimeoutSec = $PortableTimeoutSec
                $text = Invoke-PortableLlama -AdapterPath $activeLoraPath -TimeoutSec $loraTimeoutSec
                if ([string]::IsNullOrWhiteSpace($text)) {
                    throw "llama.cpp returned empty text"
                }
                $usedBackend += "+lora:" + [System.IO.Path]::GetFileName($activeLoraPath)
                Write-StatusFile -BackendLabel $usedBackend -StatusText "已生成动态事件。"
            } catch {
                $errors += "portable-lora: $($_.Exception.Message)"
                Disable-AdapterForCurrentRun -AdapterPath $activeLoraPath -Reason $_.Exception.Message
                Write-StatusFile -BackendLabel $usedBackend -StatusText "天机正在推演此世因果，完成后会自动显出事件。"

                $text = Invoke-PortableLlama -AdapterPath "" -TimeoutSec $PortableTimeoutSec
                if ([string]::IsNullOrWhiteSpace($text)) {
                    throw "llama.cpp returned empty text after adapter fallback"
                }
                $usedBackend += "+base-fallback"
                Write-StatusFile -BackendLabel $usedBackend -StatusText "已生成动态事件。"
            }
        }
    } catch {
        $errors += "portable: $($_.Exception.Message)"
        Write-StatusFile -BackendLabel "portable-llama.cpp" -StatusText "天机一度不稳，已由既有因果继续牵动。"
        if ($Backend -eq "portable") { throw }
    }
}

if ([string]::IsNullOrWhiteSpace($text) -and ($Backend -eq "auto" -or $Backend -eq "ollama")) {
    try {
        $text = Invoke-Ollama
        if ([string]::IsNullOrWhiteSpace($text)) {
            throw "Ollama returned empty text"
        }
        $usedBackend = "ollama:$Model"
        Write-StatusFile -BackendLabel $usedBackend -StatusText "已生成动态事件。"
    } catch {
        $errors += "ollama: $($_.Exception.Message)"
        Write-StatusFile -BackendLabel "ollama:$Model" -StatusText "天机一度不稳，已由既有因果继续牵动。"
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
    $clean = [regex]::Replace($clean, '\s*\[end of text\]\s*', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $clean = [regex]::Replace($clean, '\*\*', '')
    $clean = [regex]::Replace($clean, '[\u3040-\u30ff\uac00-\ud7af\u0400-\u04ff\u0370-\u03ff\u0590-\u06ff\u0900-\u097f\u0980-\u09ff\u0e00-\u0e7f\u1000-\u109f]+', '')
    $clean = [regex]::Replace($clean, '[A-Za-z]\s*级', '低阶')
    $clean = [regex]::Replace($clean, '[A-Za-z]+', '')
    $clean = [regex]::Replace($clean, '[\[\]]+', '')
    $clean = $clean.Replace("您", "你")
    $clean = $clean.Replace("话说速", "话说时")
    $clean = $clean.Replace("龙物", "灵物")
    $clean = $clean.Trim(@([char]96, [char]34, [char]39))
    $clean = [regex]::Replace($clean, '^\s*[-*]\s*', '')
    $clean = [regex]::Replace($clean, '^[A-Za-z][\.、:：\)]\s*', '')
    $clean = [regex]::Replace($clean, '^第[一二三四五六七八九十0-9]+行[:：]\s*', '')
    $clean = [regex]::Replace($clean, '^(标题|事件标题|描述|事件描述|选项[一二三四五六七八九十0-9]*|选项一|选项二|选项三|选择[一二三四五六七八九十0-9]*)[:：]\s*', '')
    $clean = [regex]::Replace($clean, '^\s*[-*0-9一二三四五]+[\.、:：\)]\s*', '')
    $clean = [regex]::Replace($clean, '\s+', '')
    $clean = $clean.Replace(";", "；").Replace(",", "，")
    return $clean.Trim()
}

function Test-BrokenEventText {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    if ($Value -match "[\u4e00-\u9fff][ \t]+[\u4e00-\u9fff]") { return $true }
    if ($Value -match "\|") { return $true }
    if ($Value -match "\*") { return $true }
    if ($Value -match "-{2,}|_{2,}|~{2,}") { return $true }
    if ($Value -match "话说速|被人到|的的|藏着的|带着的|露出一丝的|漏出一丝的|神量|仙尊神识") { return $true }
    return $false
}

function Test-MojibakeText {
    param([string]$Value)
    $scan = [regex]::Replace($Value, "\s*\[end of text\]\s*", "", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    return $scan -match "�|锛|涓|鍙|鐨|绗|椤|掳|谟|甯|€|[\u00c0-\u024f\u1e00-\u1eff\u3040-\u30ff\uac00-\ud7af\u0400-\u04ff\u0370-\u03ff\u0590-\u06ff\u0900-\u097f\u0980-\u09ff\u0e00-\u0e7f\u1000-\u109f]|://|[A-Za-z]|[\[\]]"
}

function Test-TitleLike {
    param([string]$Line)
    $clean = Normalize-EventLine $Line
    return $clean -match "^【[^】]+】"
}

function Test-ContextLabelLine {
    param([string]$Line)
    $clean = Normalize-EventLine $Line
    if ([string]::IsNullOrWhiteSpace($clean)) { return $false }
    if ($clean -match "^(玩家|境界名称|境界|因果|年龄|此世家世|家世|人情风波|轮回传承|当前世界|最近记忆|本世人脉|本世器物|当前继承的传承|失传古法当世解读|大道特性|寿元压力|隐藏设定|时代纪元|重大事件|事件影响|近年大事|世界时间|伴生玉佩|父亲|母亲|养育者|轮回余烬|本命法宝器纹|器痕归灵|天机底线|近期因果摘要|下一处因果钩子|未收束线头|人情压力|NPC近况|势力压力|人物动机参考|关系数值|稳定设定|游戏规则)\s*[:：]") { return $true }
    if ($clean -match "(境界名称|因果|本世器物|最近记忆|轮回传承|当前世界|本世人脉|隐藏设定|轮回余烬|本命法宝器纹|器痕归灵|当前继承的传承|天机底线|近期因果摘要|下一处因果钩子|未收束线头|人情压力|NPC近况|势力压力|人物动机参考|关系数值|稳定设定|游戏规则)\s*[:：]") { return $true }
    if ($clean -match "(台词参考|想要.+忌惮|忌惮.+下一步|下一步.+此人|AI 可以|C\+\+|provider|GenericAgent)") { return $true }
    if ($clean -match "^(炼气期|筑基期|金丹期|元婴期|化神期|仙帝|道祖)\s+因果\s*[+-]?\d+") { return $true }
    return $false
}

function Get-ContextKeywords {
    param([string]$PromptText)
    $isFirstLife = Test-FirstLifePrompt $PromptText
    if ($PromptText -match "顾临渊|叶微澜|江照雪|测灵碑|资质出众") {
        return @("父亲", "母亲", "顾临渊", "叶微澜", "江照雪", "测灵")
    }
    if ($PromptText -match "祁无咎|外显金丹|藏拙|隐藏实力|气机未必可信") {
        return @("外显", "修为", "气机", "藏拙", "隐藏", "试探", "活跃")
    }
    if ($PromptText -match "星穹远讯院|青灯登仙经|道网档案师") {
        return @("失传", "古法", "道网", "档案", "节点", "功法", "远方")
    }
    if ($PromptText -match "本命至宝初生器灵|本命器物已有朦胧器灵|器灵只能") {
        return @("本命", "器灵", "亲近", "畏惧", "神识", "温养", "器物")
    }
    if ($PromptText -match "闻迟|残炉|灵机工坊") {
        return @("灵机", "蒸汽", "工坊", "闻迟", "器痕", "残炉", "本命", "回路")
    }
    if ($PromptText -match "道祖-天道境|万道母鼎|万道本命至宝|多纪元因果归流") {
        return @("万道", "母鼎", "本命至宝", "旧友", "器灵", "因果", "天道境", "鼎")
    }
    if ($PromptText -match "境界名称:\s*道祖|造化青莲|陆青鸢|有限调用古老权柄") {
        return @("道祖", "青莲", "灵脉", "权柄", "代价", "陆青鸢", "反噬", "救")
    }
    if ($PromptText -match "后天通天灵宝|无人温养|威能流失|残钟") {
        return @("后天", "通天灵宝", "残钟", "温养", "威能", "流失", "道火")
    }
    if ($PromptText -match "先天通天灵宝|先天一气") {
        return @("先天", "通天灵宝", "先天一气", "观宝", "贪念", "器道")
    }
    if ($PromptText -match "低境界.*鸿蒙|鸿蒙.*低境界|只能见影|不能认主|不能调用权柄") {
        return @("鸿蒙", "投影", "见影", "拒绝", "权柄", "低境界", "道心")
    }
    if ($PromptText -match "返道拾荒盟|霜裂短剑|废土返道纪|残宗向导|器阁执事|器痕归灵") {
        return @("废土", "器痕", "残宗", "法宝", "器物", "古机", "废墟", "残炉")
    }
    if ($PromptText -match "枯井守盟|灵井枯潮|末法裂变纪|配给执事|仙帝仍会寿尽") {
        return @("寿元", "仙帝", "道祖", "末法", "灵井", "配给", "破境", "闭关")
    }
    if ($PromptText -match "天册仙朝册封吏|仙朝主簿|闻人策|仙朝.*(户籍|名册|册封)|父母身份被隐去|黑白相间") {
        return @("玉佩", "黑白", "玉痕", "名册", "册封", "家世", "养育", "旧名", "父母")
    }
    if ($PromptText -match "工坊契约反噬|灵机合约|旧债仍未清") {
        return @("玉意", "旧玉", "玉佩", "玉痕", "未竟", "旧债", "工坊", "契约", "合约", "养育")
    }
    if ($PromptText -match "当前当世鸿蒙天象|本世鸿蒙天象|鸿蒙参悟:|鸿蒙道印|造化青莲|归墟玄图|太初源炉|无量因果镜") {
        return @("鸿蒙", "至宝", "投影", "天象", "大道", "道祖")
    }
    if ($isFirstLife -and $PromptText -match "伴生玉佩|黑白旧玉|阴阳玉痕|梦中玉意|black-white old jade") {
        return @("玉佩", "黑白", "旧玉", "父母", "家世", "今生", "道途")
    }
    if ($PromptText -match "伴生玉佩|黑白旧玉|阴阳玉痕|梦中玉意") {
        return @("玉佩", "黑白", "梦中", "轮回", "记忆", "父母", "旧名")
    }
    if ($isFirstLife) {
        return @("人情", "宗门", "道途", "今生", "父母", "师门")
    }
    return @("因果", "旧日", "人情", "宗门", "道途")
}

function Get-RequiredKeywordGroups {
    param([string]$PromptText)

    if ($PromptText -match "星穹远讯院|青灯登仙经|道网档案师") {
        return @(
            @{ Label = "当世道网"; Words = @("道网", "档案", "节点", "远方") },
            @{ Label = "失传古法"; Words = @("失传", "古法", "功法", "旧法") }
        )
    }
    if ($PromptText -match "天册仙朝册封吏|仙朝主簿|闻人策|仙朝.*(户籍|名册|册封)|父母身份被隐去|黑白相间") {
        return @(
            @{ Label = "伴生旧玉"; Words = @("玉佩", "黑白", "玉痕", "旧玉") },
            @{ Label = "身世名册"; Words = @("名册", "册封", "家世", "养育", "旧名", "父母") }
        )
    }
    if ($PromptText -match "工坊契约反噬|灵机合约|旧债仍未清") {
        return @(
            @{ Label = "玉意线索"; Words = @("玉意", "旧玉", "玉佩", "玉痕", "黑白") },
            @{ Label = "未竟旧契"; Words = @("未竟", "旧债", "工坊", "契约", "合约") }
        )
    }
    if ($PromptText -match "本命至宝初生器灵|本命器物已有朦胧器灵|器灵只能") {
        return @(
            @{ Label = "本命器物"; Words = @("本命", "器物", "至宝") },
            @{ Label = "器灵情绪"; Words = @("器灵", "亲近", "畏惧", "神识") }
        )
    }
    if ($PromptText -match "闻迟|残炉|灵机工坊") {
        return @(
            @{ Label = "灵机工坊"; Words = @("灵机", "蒸汽", "工坊", "闻迟", "回路") },
            @{ Label = "本命器痕"; Words = @("器痕", "残炉", "本命", "器灵") }
        )
    }
    if ($PromptText -match "道祖-天道境|万道母鼎|万道本命至宝|多纪元因果归流") {
        return @(
            @{ Label = "万道终局"; Words = @("万道", "母鼎", "天道境", "本命至宝", "鼎") },
            @{ Label = "众生回声"; Words = @("旧友", "器灵", "愿望", "众声", "因果") }
        )
    }
    if ($PromptText -match "境界名称:\s*道祖|造化青莲|陆青鸢|有限调用古老权柄") {
        return @(
            @{ Label = "道祖权柄"; Words = @("道祖", "权柄", "代价") },
            @{ Label = "青莲灵脉"; Words = @("青莲", "灵脉", "陆青鸢", "救") }
        )
    }
    if ($PromptText -match "后天通天灵宝|无人温养|威能流失|残钟") {
        return @(
            @{ Label = "后天通天"; Words = @("后天", "通天灵宝", "残钟") },
            @{ Label = "温养衰退"; Words = @("温养", "威能", "流失", "道火") }
        )
    }
    if ($PromptText -match "先天通天灵宝|先天一气") {
        return @(
            @{ Label = "先天通天"; Words = @("先天", "通天灵宝") },
            @{ Label = "先天一气"; Words = @("先天一气", "贪念", "观宝") }
        )
    }
    if ($PromptText -match "低境界.*鸿蒙|鸿蒙.*低境界|只能见影|不能认主|不能调用权柄") {
        return @(
            @{ Label = "鸿蒙边界"; Words = @("鸿蒙", "投影", "见影") },
            @{ Label = "低境界拒绝"; Words = @("拒绝", "权柄", "低境界", "道心") }
        )
    }
    return @()
}

function Get-MissingKeywordGroups {
    param(
        [string]$Value,
        [object[]]$Groups
    )

    $missing = @()
    foreach ($group in $Groups) {
        $hasHit = $false
        foreach ($word in $group.Words) {
            if ($Value.Contains($word)) {
                $hasHit = $true
                break
            }
        }
        if (-not $hasHit) {
            $missing += $group.Label
        }
    }
    return $missing
}

function Test-ContainsAny {
    param(
        [string]$Value,
        [string[]]$Words
    )
    foreach ($word in $Words) {
        if ($Value.Contains($word)) { return $true }
    }
    return $false
}

function Test-UnintroducedCanonName {
    param(
        [string]$Value,
        [string]$PromptText
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    $names = @(
        "洛凝霜", "清蘅真人", "玄衡子", "沈听澜", "陆青鸢", "闻人策",
        "赵临", "闻迟", "周玄岐", "祁无咎", "江照雪",
        "顾临渊", "叶微澜", "沈怀舟", "林青棠", "陆守拙", "宋晚照"
    )
    foreach ($name in $names) {
        if ($Value.Contains($name) -and -not $PromptText.Contains($name)) {
            return $true
        }
    }
    return $false
}

function Get-KeywordHitCount {
    param(
        [string]$Value,
        [string[]]$Words
    )

    $hits = 0
    foreach ($word in $Words) {
        if ($Value.Contains($word)) { $hits++ }
    }
    return $hits
}

function New-ContextFallbackEvent {
    param([string]$PromptText)

    $isFirstLife = Test-FirstLifePrompt $PromptText

    if ($PromptText -match "顾临渊|叶微澜|江照雪|测灵碑|资质出众") {
        $peerName = "同代弟子"
        if ($PromptText -match "江照雪") {
            $peerName = "江照雪"
        }
        return @{
            Title = "【因果】测灵余声"
            Description = "测灵碑亮起后，父亲压住夸赞，母亲暗中护短，${peerName}却因你资质出众生出嫉妒。"
            Choices = @("谢过长辈", "稳住锋芒", "正面应试")
        }
    }
    if ($PromptText -match "祁无咎|外显金丹|藏拙|隐藏实力|气机未必可信") {
        return @{
            Title = "【奇遇】外显藏锋"
            Description = "活跃修士祁无咎外显金丹修为，却在试炼前漏出一丝藏拙气机，像要借你反应继续试探。"
            Choices = @("顺势试探", "暗记气机", "暂留余地")
        }
    }
    if ($PromptText -match "道祖-天道境|万道母鼎|万道本命至宝|多纪元因果归流") {
        return @{
            Title = "【因果】鼎前众声"
            Description = "万道母鼎将开，旧友与器灵的愿望一并涌来；万道本命至宝映照诸道，却仍等你给众生一个答案。"
            Choices = @("先听众声", "安放旧友", "观入万道")
        }
    }
    if ($PromptText -match "境界名称:\s*道祖|造化青莲|陆青鸢|有限调用古老权柄") {
        return @{
            Title = "【因果】青莲问价"
            Description = "陆青鸢按住造化青莲的余光，不让你轻易救下灵脉；她敬你为道祖，却更想先听清代价。"
            Choices = @("说清代价", "暂缓出手", "护住灵脉")
        }
    }
    if ($PromptText -match "本命至宝初生器灵|本命器物已有朦胧器灵|器灵只能") {
        return @{
            Title = "【传承】器灵初醒"
            Description = "本命至宝在掌心轻轻一颤，器灵像幼童怕生又认得你；亲近与畏惧一并贴上神识。"
            Choices = @("安抚器灵", "温养本命", "暂缓驱使")
        }
    }
    if ($PromptText -match "闻迟|残炉|灵机工坊") {
        return @{
            Title = "【传承】炉心器痕"
            Description = "闻迟在灵机工坊残炉前收起轻慢，惊疑地听见本命器痕回应你；他劝你别让旧法被拆成回路。"
            Choices = @("请教闻迟", "封住器痕", "重查残炉")
        }
    }
    if ($PromptText -match "后天通天灵宝|无人温养|威能流失|残钟") {
        return @{
            Title = "【传承】残钟余威"
            Description = "残钟曾是后天通天灵宝，如今钟纹黯淡仍令群修失声；它不认新主，只问你能否续一口道火。"
            Choices = @("温养残钟", "询问旧主", "暂不触碰")
        }
    }
    if ($PromptText -match "先天通天灵宝|先天一气") {
        return @{
            Title = "【传承】先天一气"
            Description = "先天通天灵宝残影一现，满阁炉火都向内收声；那缕先天一气压住众人贪念，也照出你的敬畏。"
            Choices = @("守礼观宝", "请教器道", "制止争夺")
        }
    }
    if ($PromptText -match "低境界.*鸿蒙|鸿蒙.*低境界|只能见影|不能认主|不能调用权柄") {
        return @{
            Title = "【因果】鸿蒙见影"
            Description = "鸿蒙投影压过识海，又在你伸手前自行退去；低境界承不住权柄，只能把拒绝化作一线悟痕。"
            Choices = @("守住道心", "静观投影", "记下悟痕")
        }
    }
    if ($PromptText -match "星穹远讯院|青灯登仙经|道网档案师|星穹道网纪") {
        return @{
            Title = "【传承】道网旧法"
            Description = "藏经长老认出你的起手式，低声把失传古法与道网档案相连，远方节点正悄悄复核你的影子。"
            Choices = @("压下旧法", "借网查档", "请教长老")
        }
    }
    if ($PromptText -match "枯井小宗|守门人|干粮旧记|一袋干粮") {
        return @{
            Title = "【因果】干粮旧记"
            Description = "枯井小宗守门人不识你今身，却认出祖上传下的干粮旧记；敬畏压住贪念，只轻声问你来意。"
            Choices = @("接过旧记", "问其祖上", "低调入宗")
        }
    }
    if ($PromptText -match "返道拾荒盟|霜裂短剑|废土返道纪|残宗向导|器阁执事|器痕归灵") {
        return @{
            Title = "【传承】废土器痕"
            Description = "残宗向导带你入废墟残炉，器阁执事听出前世法宝的器痕余响，提醒你霜裂短剑只是今生器物。"
            Choices = @("询问器痕", "封存短剑", "离开残炉")
        }
    }
    if ($PromptText -match "枯井守盟|灵井枯潮|末法裂变纪|配给执事|仙帝仍会寿尽") {
        return @{
            Title = "【危机】灵井卡名"
            Description = "赵临借灵井配给卡住试炼名额，笑你五行灵根太慢；旁人等着看笑话，只有账册露出涂改痕迹。"
            Choices = @("据理争名", "暂忍记账", "请人作证")
        }
    }
    if ($PromptText -match "天册仙朝册封吏|仙朝主簿|闻人策|仙朝.*(户籍|名册|册封)|父母身份被隐去|黑白相间") {
        return @{
            Title = "【因果】玉痕名册"
            Description = "仙朝册封吏核验名册时，你胸前黑白玉佩忽然发温，养育者避开目光，似乎仍替父母守着旧名。"
            Choices = @("追问旧名", "握玉静听", "暂避册封")
        }
    }
    if ($PromptText -match "玉意梦兆|工坊契约反噬|温凉玉意|灵机合约") {
        if ($isFirstLife) {
            return @{
                Title = "【因果】旧玉微温"
                Description = "黑白旧玉在工坊齿轮声里发温，你只觉契纸有些刺眼；养育者护短沉默，示意你先别急着落印。"
                Choices = @("握玉辨契", "问询养者", "暂避工坊")
            }
        }
        return @{
            Title = "【因果】玉意旧契"
            Description = "黑白旧玉在工坊齿轮声里发温，梦兆照见前世契约旧债；养育者护短沉默，只怕你又被合约套住。"
            Choices = @("握玉辨契", "问询养者", "暂避工坊")
        }
    }
    if ($PromptText -match "当前当世鸿蒙天象|本世鸿蒙天象|鸿蒙参悟:|鸿蒙道印|造化青莲|归墟玄图|太初源炉|无量因果镜") {
        return @{
            Title = "【因果】鸿蒙余光"
            Description = "本世天象压过识海，某件鸿蒙至宝只落下一线投影；低境界难承权柄，却逼你重新校准所修大道。"
            Choices = @("静观投影", "守住道心", "借势悟道")
        }
    }
    if ($PromptText -match "伴生玉佩|黑白旧玉|阴阳玉痕|梦中玉意") {
        if ($isFirstLife) {
            return @{
                Title = "【因果】旧玉微温"
                Description = "夜色压下时，黑白旧玉在衣襟里微微发温；你只觉心神安定，便想起今生父母临别时的叮嘱。"
                Choices = @("握玉静听", "稳住心神", "写信归家")
            }
        }
        return @{
            Title = "【因果】旧玉微温"
            Description = "夜色压下时，黑白旧玉在衣襟里微微发温，几段不该留下的轮回记忆又贴着神魂浮上来。"
            Choices = @("握玉静听", "压下梦痕", "循忆追因")
        }
    }
    if ($isFirstLife) {
        return @{
            Title = "【奇遇】雾径闻钟"
            Description = "你走入雾气遮蔽的山径，只听见远处山门钟声回荡；胸前旧玉微温，让你把心神重新稳住。"
            Choices = @("循钟前行", "原地观望", "稳住心神")
        }
    }
    return @{
        Title = "【奇遇】无名山径"
        Description = "你走入一条被雾气遮蔽的山径，隐约听见有人唤出你的道号，像旧日因果又在今生抬头。"
        Choices = @("循声前行", "原地观望", "立刻离开")
    }
}

function Normalize-Title {
    param([string]$Line)
    $title = Normalize-EventLine $Line
    $title = [regex]::Replace($title, "^【机遇】", "【机缘】")
    if ($title -notmatch "^【(机缘|危机|奇遇|因果|传承)】") {
        $tag = "【奇遇】"
        if ($title -match "机缘|机遇") { $tag = "【机缘】" }
        elseif ($title -match "危机") { $tag = "【危机】" }
        elseif ($title -match "因果") { $tag = "【因果】" }
        elseif ($title -match "传承") { $tag = "【传承】" }
        $title = [regex]::Replace($title, "^【[^】]+】\s*", "")
        $title = [regex]::Replace($title, "^(机缘|机遇|危机|奇遇|因果|传承)\s*", "")
        if ($title.Length -lt 2) { $title = "命中一线" }
        $title = $tag + $title
    }
    $title = [regex]::Replace($title, "^(【(?:机缘|危机|奇遇|因果|传承)】)\s+", '$1')
    return $title.Trim()
}

function Test-GoodDescription {
    param(
        [string]$Line,
        [string[]]$Keywords,
        [bool]$AllowWithoutKeyword = $false
    )
    $clean = Normalize-EventLine $Line
    if ([string]::IsNullOrWhiteSpace($clean)) { return $false }
    if (Test-TitleLike $clean) { return $false }
    if (Test-ContextLabelLine $clean) { return $false }
    if (Test-MojibakeText $clean) { return $false }
    if (Test-BrokenEventText $clean) { return $false }
    if ($clean -match "^(请选择|选择|选项|标题|描述)") { return $false }
    if ($clean.Length -lt 24 -or $clean.Length -gt 130) { return $false }
    if ($clean -notmatch "[。！？]$") { return $false }
    if (-not $AllowWithoutKeyword -and -not (Test-ContainsAny $clean $Keywords)) { return $false }
    return $true
}

function Convert-ToChoice {
    param([string]$Line)
    $choice = Normalize-EventLine $Line
    $choice = [regex]::Replace($choice, "^(请选择|选择|你选择|决定)\s*", "")
    $choice = [regex]::Replace($choice, "[。！？!?，,；;：:]+$", "")
    $choiceParts = $choice -split "[，,；;。！？!?]"
    if ($choiceParts.Count -gt 1) {
        $firstPart = $choiceParts[0].Trim()
        if ($firstPart.Length -ge 2 -and $firstPart.Length -le 8) {
            $choice = $firstPart
        }
    }
    $choice = $choice.Trim()
    if ($choice -eq "走后门") { $choice = "暗通执事" }
    if ($choice -eq "压下") { $choice = "压下旧法" }
    if ($choice -eq "闭关压") { $choice = "闭关压寿" }
    if ($choice -eq "暂避") { $choice = "暂避锋芒" }
    if ($choice -eq "问道") { $choice = "问道祖路" }
    if ($choice -eq "暂避锋") { $choice = "暂避锋芒" }
    if ($choice -match "^暂避锋芒") { $choice = "暂避锋芒" }
    if ($choice -eq "请长辈证词") { $choice = "请长辈证" }
    if ($choice.Length -lt 2 -or $choice.Length -gt 8) { return $null }
    if (Test-TitleLike $choice) { return $null }
    if (Test-ContextLabelLine $choice) { return $null }
    if (Test-MojibakeText $choice) { return $null }
    if ($choice -match "^(机缘|机遇|危机|奇遇|因果|传承)") { return $null }
    if ($choice -match "^(请选择|选项|解释|标题|描述)") { return $null }
    if (Test-BrokenEventText $choice) { return $null }
    if ($choice -match "[：:。！？!?，,；;]") { return $null }
    if ($choice -match "\s") { return $null }
    return $choice
}

function Get-LooseJsonCandidates {
    param([string]$RawText)

    $candidates = New-Object System.Collections.Generic.List[string]
    $trimmed = $RawText.Trim()
    if ($trimmed.StartsWith("{") -and $trimmed.EndsWith("}")) {
        $candidates.Add($trimmed)
    }

    foreach ($match in ([regex]::Matches($RawText, '(?s)```(?:json)?\s*(\{.*?\})\s*```', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))) {
        $candidates.Add($match.Groups[1].Value.Trim())
    }

    $start = $RawText.IndexOf("{")
    $end = $RawText.LastIndexOf("}")
    if ($start -ge 0 -and $end -gt $start) {
        $candidates.Add($RawText.Substring($start, $end - $start + 1).Trim())
    }

    return @($candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
}

function ConvertFrom-LooseJson {
    param([string]$RawText)

    foreach ($candidate in (Get-LooseJsonCandidates $RawText)) {
        $variants = @(
            $candidate,
            ([regex]::Replace($candidate, ",\s*([}\]])", '$1'))
        ) | Select-Object -Unique

        foreach ($variant in $variants) {
            try {
                return $variant | ConvertFrom-Json -ErrorAction Stop
            } catch {
                continue
            }
        }
    }
    return $null
}

function Get-ObjectText {
    param(
        [object]$Object,
        [string[]]$Names
    )
    foreach ($name in $Names) {
        if ($null -eq $Object) { continue }
        $property = $Object.PSObject.Properties[$name]
        if ($null -ne $property -and $null -ne $property.Value) {
            $value = [string]$property.Value
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                return $value
            }
        }
    }
    return ""
}

function Convert-StructuredEvent {
    param([string]$RawText)

    $obj = ConvertFrom-LooseJson $RawText
    if ($null -eq $obj) { return $null }

    $titleRaw = Get-ObjectText $obj @("title", "eventTitle", "标题")
    $descriptionRaw = Get-ObjectText $obj @("description", "desc", "narration", "描述")

    $beatTexts = New-Object System.Collections.Generic.List[string]
    $beatsProperty = $obj.PSObject.Properties["beats"]
    if ($null -ne $beatsProperty -and $null -ne $beatsProperty.Value) {
        foreach ($beat in @($beatsProperty.Value)) {
            if ($beat -is [string]) {
                if (-not [string]::IsNullOrWhiteSpace($beat)) { $beatTexts.Add($beat) }
            } else {
                $beatText = Get-ObjectText $beat @("narration", "text", "line", "描述")
                if (-not [string]::IsNullOrWhiteSpace($beatText)) { $beatTexts.Add($beatText) }
            }
        }
    }
    if ([string]::IsNullOrWhiteSpace($descriptionRaw) -and $beatTexts.Count -gt 0) {
        $descriptionRaw = ($beatTexts | Select-Object -First 2) -join "。"
    }

    if ([string]::IsNullOrWhiteSpace($titleRaw) -or [string]::IsNullOrWhiteSpace($descriptionRaw)) {
        return $null
    }

    $title = Normalize-Title $titleRaw
    $description = Normalize-EventLine $descriptionRaw
    if ($description.Length -gt 120) {
        $description = $description.Substring(0, 120)
    }
    if ($description -notmatch "[。！？]$") {
        $description += "。"
    }

    $choices = New-Object System.Collections.Generic.List[string]
    $choicesProperty = $obj.PSObject.Properties["choices"]
    if ($null -ne $choicesProperty -and $null -ne $choicesProperty.Value) {
        foreach ($rawChoice in @($choicesProperty.Value)) {
            $label = ""
            if ($rawChoice -is [string]) {
                $label = $rawChoice
            } else {
                $label = Get-ObjectText $rawChoice @("label", "text", "description", "选项")
            }
            $choice = Convert-ToChoice $label
            if ($null -ne $choice -and -not $choices.Contains($choice)) {
                $choices.Add($choice)
            }
            if ($choices.Count -ge 3) { break }
        }
    }

    if ($choices.Count -lt 2) { return $null }

    [pscustomobject]@{
        Title = $title
        Description = $description
        Choices = @($choices.ToArray())
        Raw = $obj
    }
}

$fallback = New-ContextFallbackEvent $basePrompt
$keywords = Get-ContextKeywords $basePrompt
$requiredGroups = Get-RequiredKeywordGroups $basePrompt
$isFirstLifePrompt = Test-FirstLifePrompt $basePrompt
$repairNotes = New-Object System.Collections.Generic.List[string]
$rawHadNoise = Test-MojibakeText $text
if ($rawHadNoise) {
    $repairNotes.Add("清理噪声")
}
$rawHadBrokenText = Test-BrokenEventText $text
if ($rawHadBrokenText) {
    $repairNotes.Add("清理病句")
}
$strictContextRepair = $true
if ($rawHadNoise -or $rawHadBrokenText) {
    $strictContextRepair = $true
}

$structuredEvent = Convert-StructuredEvent $text
if ($null -ne $structuredEvent) {
    $repairNotes.Add("结构化事件")
    try {
        $sceneJson = $structuredEvent.Raw | ConvertTo-Json -Depth 8
        [System.IO.File]::WriteAllText($scenePath, $sceneJson, $encoding)
    } catch {
        [System.IO.File]::WriteAllText($scenePath, "{}", $encoding)
    }
    $structuredLines = New-Object System.Collections.Generic.List[string]
    $structuredLines.Add($structuredEvent.Title)
    $structuredLines.Add($structuredEvent.Description)
    foreach ($choice in $structuredEvent.Choices) {
        $structuredLines.Add([string]$choice)
        if ($structuredLines.Count -ge 5) { break }
    }
    $text = (($structuredLines | Select-Object -First 5) -join [Environment]::NewLine) +
        [Environment]::NewLine + $text
}

$candidateLines = @()
foreach ($line in ($text -split "`r?`n")) {
    $clean = Normalize-EventLine $line
    if ($clean -match "^(下面|以下|好的|输出|格式|事件如下|生成)") { continue }
    if ($clean -match "^(请选择|请从|请在|选择如下|选项如下)\s*[:：]?\s*$") { continue }
    if ($clean.Length -gt 0) {
        $candidateLines += $clean
    }
}

$usedFallbackTitle = $false
$usedFallbackDescription = $false
$title = $null
foreach ($line in $candidateLines) {
    if ((Test-TitleLike $line) -or $line -match "^(机缘|机遇|危机|奇遇|因果|传承).{1,18}$") {
        $candidateTitle = Normalize-Title $line
        if ($candidateTitle.Length -le 34 -and -not (Test-ContextLabelLine $candidateTitle) -and -not (Test-MojibakeText $candidateTitle)) {
            $title = $candidateTitle
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($title)) {
    $title = $fallback.Title
    $usedFallbackTitle = $true
    $repairNotes.Add("标题")
}

$description = $null
foreach ($line in $candidateLines) {
    $clean = Normalize-EventLine $line
    $clean = [regex]::Replace($clean, "\s*(请选择|选择)[:：]?.*$", "")
    if ($isFirstLifePrompt -and (Test-FirstLifeMemoryLeak $clean)) { continue }
    if (Test-UnintroducedCanonName $clean $basePrompt) { continue }
    if (Test-GoodDescription $clean $keywords (-not $strictContextRepair)) {
        $description = $clean
        break
    }
}
if ([string]::IsNullOrWhiteSpace($description)) {
    $description = $fallback.Description
    $usedFallbackDescription = $true
    $repairNotes.Add("描述")
} elseif ($description.Length -gt 120) {
    $description = $description.Substring(0, 120)
}
if ($strictContextRepair -and (Get-KeywordHitCount ($title + "`n" + $description) $keywords) -lt 2) {
    $description = $fallback.Description
    $usedFallbackDescription = $true
    $repairNotes.Add("描述贴合上下文")
}
if ($isFirstLifePrompt -and (Test-FirstLifeMemoryLeak $description)) {
    $description = $fallback.Description
    $usedFallbackDescription = $true
    $repairNotes.Add("第一世记忆边界")
}
if (Test-UnintroducedCanonName $description $basePrompt) {
    $description = $fallback.Description
    $usedFallbackDescription = $true
    $repairNotes.Add("未引入角色")
}
if ($strictContextRepair) {
    $missingRequiredGroups = Get-MissingKeywordGroups ($title + "`n" + $description) $requiredGroups
    if ($missingRequiredGroups.Count -gt 0) {
        $description = $fallback.Description
        $usedFallbackDescription = $true
        $repairNotes.Add("描述缺少" + ($missingRequiredGroups -join "/"))
    }
}
if ($usedFallbackDescription -and -not $usedFallbackTitle) {
    $title = $fallback.Title
    $repairNotes.Add("标题贴合上下文")
}

$choices = @()
if (-not $usedFallbackDescription) {
    foreach ($line in $candidateLines) {
        $choiceLine = Normalize-EventLine $line
        if ($choiceLine.Length -gt 16) { continue }
        if (Test-TitleLike $choiceLine) { continue }
        if (Test-GoodDescription $choiceLine $keywords (-not $strictContextRepair)) { continue }
        $choice = Convert-ToChoice $line
        if ($null -ne $choice -and -not $choices.Contains($choice) -and $choice -ne $title -and $choice -ne $description) {
            $choices += $choice
        }
        if ($choices.Count -ge 3) { break }
    }
} else {
    $repairNotes.Add("选项贴合上下文")
}
if ($choices.Count -lt 3) {
    $repairNotes.Add("选项")
}
foreach ($choice in $fallback.Choices) {
    if ($choices.Count -ge 3) { break }
    if (-not $choices.Contains($choice)) {
        $choices += $choice
    }
}
if ($choices.Count -lt 3) {
    foreach ($choice in @("上前探查", "谨慎观望", "转身离开")) {
        if ($choices.Count -ge 3) { break }
        if (-not $choices.Contains($choice)) { $choices += $choice }
    }
}
if ($choices.Count -gt 3) {
    $choices = $choices[0..2]
}

$lines = @($title, $description, $choices[0], $choices[1], $choices[2])
[System.IO.File]::WriteAllText($eventPath, ($lines -join [Environment]::NewLine), $encoding)
$statusText = "已生成 1 条动态事件并写入 ai_event.txt。"
if ($repairNotes.Count -gt 0) {
    $statusText = "模型输出已后处理修复：" + (($repairNotes | Select-Object -Unique) -join "、") + "。"
}
Write-StatusFile -BackendLabel $usedBackend -StatusText $statusText
Write-Output "Generated $eventPath"
