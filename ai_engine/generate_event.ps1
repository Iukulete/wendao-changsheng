param(
    [string]$ReleaseDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "release"),
    [string]$Model = "wendao-xiuxian",
    [string]$ModelPath = "",
    [string]$LoraPath = "",
    [string]$LlamaCli = (Join-Path $PSScriptRoot "runtime\llama.cpp\llama-completion.exe"),
    [int]$PortableTimeoutSec = 75,
    [int]$OllamaTimeoutSec = 20,
    [ValidateSet("auto", "portable", "ollama")]
    [string]$Backend = "auto"
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
}
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

$basePrompt = [System.IO.File]::ReadAllText($promptPath, [System.Text.Encoding]::UTF8)
$basePrompt = $basePrompt + "`n严格只输出5行：标题、描述、选项一、选项二、选项三。不要解释。标题和描述合计至少写入两个上下文专有词。"

function Format-RuntimePrompt {
    param([string]$PromptText)

    $modelFile = [System.IO.Path]::GetFileName($ModelPath).ToLowerInvariant()
    if ($modelFile -match "gemma-4") {
        return "<bos><|turn>user`n" + $PromptText.Trim() + "`n<turn|>`n<|turn>model`n"
    }
    return $PromptText
}

$runtimePrompt = Format-RuntimePrompt $basePrompt
$ollamaPrompt = $basePrompt

function Invoke-PortableLlama {
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
        "-n", "96",
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

    if (-not [string]::IsNullOrWhiteSpace($LoraPath)) {
        if (-not (Test-Path -LiteralPath $LoraPath)) {
            throw "Configured LoRA adapter was not found: $LoraPath"
        }
        $args += @("--lora", $LoraPath)
    }

    $stderrTemp = [System.IO.Path]::GetFullPath((Join-Path $ReleaseDir ("ai_llama_stderr_" + [guid]::NewGuid().ToString("N") + ".tmp")))
    $workingDir = Split-Path -Parent $LlamaCli
    $job = Start-Job -ScriptBlock {
        param(
            [string]$ExePath,
            [string[]]$ExeArgs,
            [string]$ExeWorkingDir,
            [string]$NativeStdErrPath
        )

        $ErrorActionPreference = "Continue"
        $OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::InputEncoding = [System.Text.Encoding]::UTF8
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        Set-Location -LiteralPath $ExeWorkingDir

        $nativeOut = & $ExePath @ExeArgs 2> $NativeStdErrPath
        $nativeExitCode = $LASTEXITCODE
        $stdoutText = [string]::Join([Environment]::NewLine, @($nativeOut | ForEach-Object { [string]$_ }))
        [pscustomobject]@{
            ExitCode = $nativeExitCode
            StdOut = $stdoutText
        }
    } -ArgumentList $LlamaCli, $args, $workingDir, $stderrTemp

    try {
        $completedJob = Wait-Job -Job $job -Timeout $PortableTimeoutSec
        if ($null -eq $completedJob) {
            Stop-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
            $stderr = ""
            if (Test-Path -LiteralPath $stderrTemp) {
                $stderr = [System.IO.File]::ReadAllText($stderrTemp, [System.Text.Encoding]::UTF8)
            }
            if ($stderr) {
                [System.IO.File]::WriteAllText($llamaLogPath, $stderr, $encoding)
            }
            throw "llama.cpp timed out after ${PortableTimeoutSec}s"
        }

        $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
        $stderr = ""
        if (Test-Path -LiteralPath $stderrTemp) {
            $stderr = [System.IO.File]::ReadAllText($stderrTemp, [System.Text.Encoding]::UTF8)
        }
        if ($stderr) {
            [System.IO.File]::WriteAllText($llamaLogPath, $stderr, $encoding)
        }
        if ($null -eq $result) {
            throw "llama.cpp produced no process result"
        }
        if ($result.ExitCode -ne 0) {
            throw "llama.cpp exited with code $($result.ExitCode)"
        }

        return [string]$result.StdOut
    } finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue | Out-Null
        if (Test-Path -LiteralPath $stderrTemp) {
            Remove-Item -LiteralPath $stderrTemp -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-Ollama {
    $body = @{
        model = $Model
        prompt = $ollamaPrompt
        stream = $false
        think = $false
        options = @{
            temperature = 0.65
            top_p = 0.85
            repeat_penalty = 1.08
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
        $usedBackend = "portable-llama.cpp:" + [System.IO.Path]::GetFileName($ModelPath)
        if (-not [string]::IsNullOrWhiteSpace($LoraPath)) {
            $usedBackend += "+lora:" + [System.IO.Path]::GetFileName($LoraPath)
        }
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
    $clean = [regex]::Replace($clean, '\s*\[end of text\]\s*$', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $clean = [regex]::Replace($clean, '\*\*', '')
    $clean = $clean.Trim(@([char]96, [char]34, [char]39))
    $clean = [regex]::Replace($clean, '^\s*[-*]\s*', '')
    $clean = [regex]::Replace($clean, '^[A-Za-z][\.、:：\)]\s*', '')
    $clean = [regex]::Replace($clean, '^第[一二三四五六七八九十0-9]+行[:：]\s*', '')
    $clean = [regex]::Replace($clean, '^(标题|事件标题|描述|事件描述|选项[一二三四五六七八九十0-9]*|选项一|选项二|选项三|选择[一二三四五六七八九十0-9]*)[:：]\s*', '')
    $clean = [regex]::Replace($clean, '^\s*[-*0-9一二三四五]+[\.、:：\)]\s*', '')
    $clean = [regex]::Replace($clean, '\s+', ' ')
    $clean = $clean.Replace(";", "；").Replace(",", "，")
    return $clean.Trim()
}

function Test-MojibakeText {
    param([string]$Value)
    $scan = [regex]::Replace($Value, "\s*\[end of text\]\s*", "", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    return $scan -match "�|锛|涓|鍙|鐨|绗|椤|掳|谟|甯|€|[\u3040-\u30ff\uac00-\ud7af\u0400-\u04ff\u0370-\u03ff\u0590-\u06ff\u0900-\u097f\u0e00-\u0e7f\u1000-\u109f]|://|[A-Za-z]{3,}"
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
    if ($clean -match "^(玩家|境界名称|境界|因果|年龄|此世家世|家世|人情风波|轮回传承|当前世界|最近记忆|本世人脉|本世器物|当前继承的传承|失传古法当世解读|大道特性|寿元压力|隐藏设定|时代纪元|重大事件|事件影响|近年大事|世界时间|伴生玉佩|父亲|母亲|养育者|轮回余烬|本命法宝器纹|器痕归灵)\s*[:：]") { return $true }
    if ($clean -match "(境界名称|因果|本世器物|最近记忆|轮回传承|当前世界|本世人脉|隐藏设定|轮回余烬|本命法宝器纹|器痕归灵|当前继承的传承)\s*[:：]") { return $true }
    if ($clean -match "^(炼气期|筑基期|金丹期|元婴期|化神期|仙帝|道祖)\s+因果\s*[+-]?\d+") { return $true }
    return $false
}

function Get-ContextKeywords {
    param([string]$PromptText)
    if ($PromptText -match "星穹远讯院|青灯登仙经|道网档案师|星穹道网纪") {
        return @("失传", "古法", "道网", "档案", "节点", "功法", "长老", "旧法")
    }
    if ($PromptText -match "返道拾荒盟|霜裂短剑|废土返道纪|残宗向导|器阁执事|器痕归灵") {
        return @("废土", "器痕", "残宗", "法宝", "器物", "古机", "废墟", "残炉")
    }
    if ($PromptText -match "枯井守盟|灵井枯潮|末法裂变纪|配给执事|仙帝仍会寿尽") {
        return @("寿元", "仙帝", "道祖", "末法", "灵井", "配给", "破境", "闭关")
    }
    if ($PromptText -match "天册仙朝册封吏|父母身份被隐去|黑白相间|仙朝鼎盛纪") {
        return @("玉佩", "黑白", "名册", "册封", "家世", "养育", "旧名", "父母")
    }
    if ($PromptText -match "当前当世鸿蒙天象|本世鸿蒙天象|鸿蒙参悟:|鸿蒙道印|造化青莲|归墟玄图|太初源炉|无量因果镜") {
        return @("鸿蒙", "至宝", "投影", "天象", "大道", "道祖")
    }
    if ($PromptText -match "伴生玉佩|黑白旧玉|阴阳玉痕|梦中玉意") {
        return @("玉佩", "黑白", "梦中", "轮回", "记忆", "父母", "旧名")
    }
    return @("因果", "旧日", "人情", "宗门", "道途")
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

    if ($PromptText -match "星穹远讯院|青灯登仙经|道网档案师|星穹道网纪") {
        return @{
            Title = "【传承】道网旧法"
            Description = "藏经长老认出你的起手式，低声把失传古法与道网档案相连，远方节点正悄悄复核你的影子。"
            Choices = @("压下旧法", "借网查档", "请教长老")
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
            Title = "【危机】灵井寿限"
            Description = "灵井枯潮逼近，配给执事扣住破境名额；你虽号仙帝，仍能听见寿元在闭关石门外一点点迫近。"
            Choices = @("争取配给", "闭关压寿", "问道祖路")
        }
    }
    if ($PromptText -match "天册仙朝册封吏|父母身份被隐去|黑白相间|仙朝鼎盛纪") {
        return @{
            Title = "【因果】玉痕名册"
            Description = "册封吏核验名册时，你胸前黑白玉佩忽然发温，养育者避开你的目光，似乎仍在替父母守着旧名。"
            Choices = @("追问旧名", "握玉静听", "暂避册封")
        }
    }
    if ($PromptText -match "当前当世鸿蒙天象|本世鸿蒙天象|鸿蒙参悟:|鸿蒙道印|造化青莲|归墟玄图|太初源炉|无量因果镜") {
        return @{
            Title = "【因果】鸿蒙余光"
            Description = "本世天象压过识海，某件鸿蒙至宝只落下一线投影，不肯成为装备，却逼你重新校准所修大道。"
            Choices = @("参悟投影", "守住道心", "拒绝诱因")
        }
    }
    if ($PromptText -match "伴生玉佩|黑白旧玉|阴阳玉痕|梦中玉意") {
        return @{
            Title = "【因果】旧玉微温"
            Description = "夜色压下时，黑白旧玉在衣襟里微微发温，几段不该留下的轮回记忆又贴着神魂浮上来。"
            Choices = @("握玉静听", "压下梦痕", "循忆追因")
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
        [string[]]$Keywords
    )
    $clean = Normalize-EventLine $Line
    if ([string]::IsNullOrWhiteSpace($clean)) { return $false }
    if (Test-TitleLike $clean) { return $false }
    if (Test-ContextLabelLine $clean) { return $false }
    if (Test-MojibakeText $clean) { return $false }
    if ($clean -match "^(请选择|选择|选项|标题|描述)") { return $false }
    if ($clean.Length -lt 35 -or $clean.Length -gt 130) { return $false }
    if (-not (Test-ContainsAny $clean $Keywords)) { return $false }
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
    if ($choice.Length -lt 2 -or $choice.Length -gt 8) { return $null }
    if (Test-TitleLike $choice) { return $null }
    if (Test-ContextLabelLine $choice) { return $null }
    if (Test-MojibakeText $choice) { return $null }
    if ($choice -match "^(请选择|选项|解释|标题|描述)") { return $null }
    if ($choice -match "[：:。！？!?，,；;]") { return $null }
    if ($choice -match "\s") { return $null }
    return $choice
}

$fallback = New-ContextFallbackEvent $basePrompt
$keywords = Get-ContextKeywords $basePrompt
$repairNotes = New-Object System.Collections.Generic.List[string]

$candidateLines = @()
if (-not (Test-MojibakeText $text)) {
    foreach ($line in ($text -split "`r?`n")) {
        $clean = Normalize-EventLine $line
        if ($clean -match "^(下面|以下|好的|输出|格式|事件如下|生成)") { continue }
        if ($clean -match "^(请选择|请从|请在|选择如下|选项如下)\s*[:：]?\s*$") { continue }
        if ($clean.Length -gt 0) {
            $candidateLines += $clean
        }
    }
} else {
    $repairNotes.Add("疑似乱码")
}

$title = $null
foreach ($line in $candidateLines) {
    if (Test-TitleLike $line) {
        $candidateTitle = Normalize-Title $line
        if ($candidateTitle.Length -le 34 -and -not (Test-ContextLabelLine $candidateTitle) -and -not (Test-MojibakeText $candidateTitle)) {
            $title = $candidateTitle
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($title)) {
    $title = $fallback.Title
    $repairNotes.Add("标题")
}

$description = $null
foreach ($line in $candidateLines) {
    $clean = Normalize-EventLine $line
    $clean = [regex]::Replace($clean, "\s*(请选择|选择)[:：]?.*$", "")
    if (Test-GoodDescription $clean $keywords) {
        $description = $clean
        break
    }
}
if ([string]::IsNullOrWhiteSpace($description)) {
    $description = $fallback.Description
    $repairNotes.Add("描述")
} elseif ($description.Length -gt 120) {
    $description = $description.Substring(0, 120)
}
if ((Get-KeywordHitCount ($title + "`n" + $description) $keywords) -lt 2) {
    $description = $fallback.Description
    $repairNotes.Add("描述贴合上下文")
}

$choices = @()
if ($repairNotes.Count -eq 0) {
    foreach ($line in $candidateLines) {
        $choiceLine = Normalize-EventLine $line
        if ($choiceLine.Length -gt 16) { continue }
        if (Test-TitleLike $choiceLine) { continue }
        if (Test-GoodDescription $choiceLine $keywords) { continue }
        $choice = Convert-ToChoice $line
        if ($null -ne $choice -and -not $choices.Contains($choice) -and $choice -ne $title -and $choice -ne $description) {
            $choices += $choice
        }
        if ($choices.Count -ge 3) { break }
    }
} else {
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
