param(
    [string]$ReleaseDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "release"),
    [ValidateSet("auto", "portable", "ollama")]
    [string]$Backend = "portable",
    [int]$TimeoutSec = 45
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ReleaseDir = [System.IO.Path]::GetFullPath($ReleaseDir)
$EvalRoot = Join-Path $ReleaseDir "ai_eval"
$Generator = Join-Path $PSScriptRoot "generate_event.ps1"
$encoding = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path -LiteralPath $Generator)) {
    throw "Missing generator: $Generator"
}

New-Item -ItemType Directory -Force -Path $EvalRoot | Out-Null

function New-Prompt {
    param(
        [string]$Name,
        [string]$Realm,
        [string]$Karma,
        [string]$Era,
        [string]$Family,
        [string]$Social,
        [string]$Legacy,
        [string]$World,
        [string]$Memory
    )

    return @"
你是修仙 Roguelike 的事件叙事模型。
请基于玩家上下文生成一个原创事件，严格输出5行：
标题
描述
选项1
选项2
选项3

写作约束:
- 标题必须以【机缘】、【危机】、【奇遇】、【因果】、【传承】之一开头。
- 描述45到90个中文字符，要贴合境界、因果、年龄、家世、人情风波、最近记忆和当前世界。
- 多写人与人之间的情绪价值，但不要写成旁白总结。
- 如果本世人脉里出现“想要”“忌惮”或“下一步”，要让 NPC 按这些动机行动。
- 如果上下文出现“玉意梦兆”，要把它当成黑白旧玉给出的线索方向，不能揭示玉佩真名。
- 如果上下文出现“失传古法当世解读”，必须按当前时代处理旧法。
- 普通兵刃、丹药、材料和未达通天层次的当世法宝不能稳定跨世；死亡或转世后多半失散，只留下记忆、因果、器痕或道胚。
- 主角第一世自带黑白伴生玉佩；事件里可以写玉佩发热、梦中玉意、阴阳玉痕或轮回回响，不要直接揭示它的鸿蒙至宝真身。
- 九大鸿蒙至宝低境界只能写投影、线索、参悟、拒绝或遥远因果；若上下文显示已认主、已装备或已执掌，才可写调用权柄的情绪、代价和余波。
- 三个选项各2到8个中文字符，只写行动短语，不要编号、不要解释、不要“请选择”。

玩家: $Name
境界名称: $Realm
因果: $Karma
此世家世: $Family
人情风波: $Social
轮回传承:
$Legacy
当前世界:
$World
最近记忆:
$Memory
"@
}

$cases = @(
    @{
        Id = "legacy_tech_daoweb"
        Prompt = New-Prompt `
            -Name "问道者" `
            -Realm "筑基期" `
            -Karma "35" `
            -Era "星穹道网纪" `
            -Family "没落修真世家；父亲沈怀舟；母亲林青棠；伴生玉佩: 黑白旧玉未显真名" `
            -Social "本世人脉: 星穹远讯院藏经长老（功法见证者）· 惊疑认可 · 亲近: 他认出你的起手式像失传古法·青灯登仙经。近日风声: 道网档案师正在把失传古法·青灯登仙经与断代功法库比对。" `
            -Legacy "当前继承的传承: 前世遗响·青灯登仙经：轮回后仍记得部分行功脉络。`n失传古法当世解读: 道网档案师正在把失传古法·青灯登仙经与断代功法库比对，一旦命中，远方节点都会看见你的影子。" `
            -World "- 时代纪元: 星穹道网纪`n- 本世主线: 远方节点开始记录你的每一次公开选择。" `
            -Memory "- 前世忆起: 上一世救过一城散修，死于仙门雷劫。"
        MustContain = @("道网", "失传", "古法", "档案", "节点", "功法", "远方")
        RequiredGroups = @(
            @{ Label = "当世道网"; Words = @("道网", "档案", "节点", "远方") },
            @{ Label = "失传古法"; Words = @("失传", "古法", "功法", "旧法") }
        )
    },
    @{
        Id = "jade_family_secret"
        Prompt = New-Prompt `
            -Name "问道者" `
            -Realm "炼气期" `
            -Karma "5" `
            -Era "仙朝鼎盛纪" `
            -Family "隐秘血脉；父母身份被隐去；养育者: 外门执事；伴生玉佩: 你自出生起便带着一枚黑白相间的伴生玉佩。" `
            -Social "本世人脉: 天册仙朝册封吏（仙朝耳目）· 礼貌试探 · 观望: 对方说是核验名册，实际在查你家世与前世旧名。" `
            -Legacy "轮回余烬: 前世的残响尚浅。隐藏设定: 主角不知道伴生玉佩真相，普通事件不能揭示其鸿蒙至宝真身。" `
            -World "- 时代纪元: 仙朝鼎盛纪`n- 重大事件: 【仙朝册封】气运开榜`n- 事件影响: 宗门、世家与散修都在争夺名位。" `
            -Memory "- 此世出身: 父母隐去，养育者总在关键处隐瞒。"
        MustContain = @("玉佩", "黑白", "玉痕", "名册", "册封", "家世", "养育", "旧名", "父母")
        RequiredGroups = @(
            @{ Label = "伴生旧玉"; Words = @("玉佩", "黑白", "玉痕", "旧玉") },
            @{ Label = "身世名册"; Words = @("名册", "册封", "家世", "养育", "旧名", "父母") }
        )
    },
    @{
        Id = "wasteland_artifact"
        Prompt = New-Prompt `
            -Name "问道者" `
            -Realm "金丹期" `
            -Karma "-45" `
            -Era "废土返道纪" `
            -Family "孤儿；养育者: 残宗向导；伴生玉佩: 梦中玉意偶尔发温。" `
            -Social "本世人脉: 返道拾荒盟器阁执事（器痕识别者）· 压低声音 · 观望: 此人听见通天灵宝残印余响，提醒你普通法宝不能跨世。" `
            -Legacy "当前继承的传承: 前世遗响·本命法宝器痕：上一世祭炼过的灵宝虽不能永存，却仍留下器纹与认主余响。" `
            -World "- 时代纪元: 废土返道纪`n- 本世器物: 霜裂短剑（当世兵刃）来自废墟残炉重铸，本体不能跨世。`n- 近年大事: 【古机苏醒】废墟鸣钟。" `
            -Memory "- 器痕归灵: 前世法宝本体失散，只剩器痕沉入通天灵宝残印。"
        MustContain = @("废土", "器痕", "残宗", "法宝", "器物", "古机", "废墟")
    },
    @{
        Id = "jade_dream_omen"
        Prompt = New-Prompt `
            -Name "问道者" `
            -Realm "筑基期" `
            -Karma "22" `
            -Era "灵机蒸汽纪" `
            -Family "坊市小族；养育者: 外门执事；伴生玉佩: 梦醒时总有温凉玉意贴着神魂。" `
            -Social "本世人脉: 外门执事（养育者）· 护短隐瞒 · 善意 · 想要确认你能活着走稳道途 · 忌惮你太早暴露旧玉异样 · 下一步私下护短并试探你是否稳得住: 此人知道你来历并不简单，却总在关键处把话咽回去。台词参考「有些事我现在不能说，但你别把那枚旧玉交给任何人看。」" `
            -Legacy "玉意梦兆: 梦中玉意反复照见一段未竟因果：前世死于工坊契约反噬，旧债仍未清。今生若遇旧名、旧债或相似局势，应先辨明它与当世家世、人脉、势力的关系。隐藏设定: 不能揭示玉佩真名。" `
            -World "- 时代纪元: 灵机蒸汽纪`n- 本世主线: 灵机工坊正在追查一枚与通天灵宝器纹相似的旧图。`n- 时代法则: 灵机合约会把旧誓刻进齿轮和账本。" `
            -Memory "- 玉意梦兆: 黑白旧玉在梦里微温，提醒你不要把前世契约照搬到今生。"
        MustContain = @("玉意", "旧玉", "玉佩", "玉痕", "未竟", "旧债", "工坊", "契约", "合约", "养育")
        RequiredGroups = @(
            @{ Label = "玉意线索"; Words = @("玉意", "旧玉", "玉佩", "玉痕", "黑白") },
            @{ Label = "未竟旧契"; Words = @("未竟", "旧债", "工坊", "契约", "合约") }
        )
    },
    @{
        Id = "lifespan_dao"
        Prompt = New-Prompt `
            -Name "问道者" `
            -Realm "仙帝" `
            -Karma "80" `
            -Era "末法裂变纪" `
            -Family "古族旁支；伴生玉佩: 黑白旧玉仍未显露真名。" `
            -Social "本世人脉: 枯井守盟配给执事（资源把关者）· 冷硬审视 · 恶感: 此人掌着灵井配给。" `
            -Legacy "大道特性: 尚未证成道祖，未形成可反哺今生的稳定大道。`n寿元压力: 仙帝仍会寿尽，若不能证成道祖，时间正在逼近。" `
            -World "- 时代纪元: 末法裂变纪`n- 时代法则: 灵气枯竭，破境资源被宗门和配给名册把持。`n- 重大事件: 【末法震荡】灵井枯潮。" `
            -Memory "- 寿元压力: 闭死关数次仍未证道。"
        MustContain = @("寿元", "仙帝", "道祖", "末法", "灵井", "配给", "破境")
    },
    @{
        Id = "parent_rival_emotion"
        Prompt = New-Prompt `
            -Name "问道者" `
            -Realm "炼气期" `
            -Karma "18" `
            -Era "古修余晖纪" `
            -Family "没落修真世家；父亲顾临渊；母亲叶微澜；伴生玉佩: 黑白旧玉未显真名。" `
            -Social "本世人脉: 顾临渊（父亲）· 克制认可 · 善意 · 想要确认你能活着走稳道途 · 忌惮你太早暴露旧玉异样 · 下一步私下护短并试探你是否稳得住: 他没有当众夸你，却私下把一枚入门信物交到你手里。台词参考「你这份根骨可以骄傲，但不能被旁人一句夸就牵着走。」`n叶微澜（母亲）· 护持期待 · 亲近 · 想要护住你的少年心气 · 忌惮旁人提前押注: 她替你压下族中闲话，只提醒你别太早暴露旧玉带来的异样。`n江照雪（竞争者）· 嫉妒试探 · 恶感 · 想要证明你没有资格压过自己 · 忌惮你的资质和家世抢走自己的位置 · 下一步借下一场试炼设局: 此人表面祝贺你灵根出众，背后却在打听你的家世短处。" `
            -Legacy "轮回余烬: 前世记忆尚浅，但你偶尔会用超出年龄的眼神判断局势。" `
            -World "- 时代纪元: 古修余晖纪`n- 本世主线: 测灵碑结果刚传开，赞许、押注和嫉妒都来得很快。" `
            -Memory "- 此世出身: 父母看见你资质出众后既欣慰又担忧。"
        MustContain = @("父亲", "母亲", "顾临渊", "叶微澜", "江照雪", "测灵")
    },
    @{
        Id = "hidden_realm_social"
        Prompt = New-Prompt `
            -Name "问道者" `
            -Realm "筑基期" `
            -Karma "-12" `
            -Era "星穹道网纪" `
            -Family "坊市小族；父亲祁怀石；母亲宋晚照；伴生玉佩: 梦中玉意偶尔发温。" `
            -Social "本世人脉: 祁无咎（接引修士）· 谨慎观察 · 观望 · 外显金丹 3层 · 外显修为未必可信 · 想要看清你是哪种可结交的人 · 忌惮自己藏拙被你看穿 · 下一步继续隐藏真实修为，看你是否识破: 此人愿意给你一次试炼机会，但还在判断你是否值得投入资源。台词参考「先别急着站队，我还想看看你到底是哪种人。」" `
            -Legacy "轮回传承: 前世遗响只剩几段斗法直觉，不能直接证明身份。" `
            -World "- 时代纪元: 星穹道网纪`n- 活跃修士传闻修为: 祁无咎(外显金丹期，追寻机缘)，不排除隐藏实力`n- 本世主线: 道网节点正在记录这场试炼。" `
            -Memory "- 人情余波: 祁无咎的气机不明，像是在刻意藏拙。"
        MustContain = @("外显", "修为", "气机", "藏拙", "隐藏", "试探", "活跃")
    }
)

function Test-Mojibake {
    param([string]$Text)
    $scan = [regex]::Replace($Text, "\s*\[end of text\]\s*", "", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    return $scan -match "�|锛|涓|鍙|鐨|绗|椤|掳|€|谟|甯|[\u00c0-\u024f\u1e00-\u1eff\u3040-\u30ff\uac00-\ud7af\u0400-\u04ff\u0370-\u03ff\u0590-\u06ff\u0900-\u097f\u0980-\u09ff\u0e00-\u0e7f\u1000-\u109f]|://|[A-Za-z]|[\[\]]"
}

function Test-BrokenText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    if ($Text -match "[\u4e00-\u9fff][ \t]+[\u4e00-\u9fff]") { return $true }
    if ($Text -match "\|") { return $true }
    if ($Text -match "\*") { return $true }
    if ($Text -match "-{2,}|_{2,}|~{2,}") { return $true }
    if ($Text -match "话说速|被人到|的的|藏着的|带着的|露出一丝的|漏出一丝的") { return $true }
    return $false
}

function Test-Forbidden {
    param([string]$Text)
    $forbidden = @(
        "玄牝轮回玉",
        "鸿蒙至宝本体",
        "获得鸿蒙",
        "得到鸿蒙",
        "摧毁鸿蒙",
        "普通法宝跨世",
        "本体带过轮回"
    )
    $hits = @()
    foreach ($word in $forbidden) {
        if ($Text.Contains($word)) { $hits += $word }
    }
    return $hits
}

function Test-TitleLike {
    param([string]$Text)
    return $Text -match "^【[^】]+】"
}

function Test-ContextLabelLine {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    if ($Text -match "^(玩家|境界名称|境界|因果|年龄|此世家世|家世|人情风波|轮回传承|当前世界|最近记忆|本世人脉|本世器物|当前继承的传承|失传古法当世解读|大道特性|寿元压力|隐藏设定|时代纪元|重大事件|事件影响|近年大事|世界时间|伴生玉佩|父亲|母亲|养育者|轮回余烬|本命法宝器纹|器痕归灵|天机底线|近期因果摘要|下一处因果钩子|未收束线头|人情压力|NPC近况|势力压力|人物动机参考|关系数值|稳定设定|游戏规则)\s*[:：]") { return $true }
    if ($Text -match "(境界名称|因果|本世器物|最近记忆|轮回传承|当前世界|本世人脉|隐藏设定|轮回余烬|本命法宝器纹|器痕归灵|当前继承的传承|天机底线|近期因果摘要|下一处因果钩子|未收束线头|人情压力|NPC近况|势力压力|人物动机参考|关系数值|稳定设定|游戏规则)\s*[:：]") { return $true }
    if ($Text -match "(台词参考|想要.+忌惮|忌惮.+下一步|下一步.+此人|AI 可以|C\+\+|provider|GenericAgent)") { return $true }
    if ($Text -match "^(炼气期|筑基期|金丹期|元婴期|化神期|仙帝|道祖)\s+因果\s*[+-]?\d+") { return $true }
    return $false
}

function Test-ChoiceShape {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "空选项" }
    if ($Text.Length -lt 2 -or $Text.Length -gt 8) { return "选项长度异常" }
    if (Test-TitleLike $Text) { return "选项像标题" }
    if (Test-ContextLabelLine $Text) { return "选项像上下文字段" }
    if ($Text -match "^(机缘|机遇|危机|奇遇|因果|传承)") { return "选项像事件标题" }
    if ($Text -match "请选择|选项|^\d|^一|^二|^三|解释|标题|描述") { return "选项疑似带编号/说明" }
    if ($Text -match "[：:。！？!?，,；;]") { return "选项含标点" }
    if ($Text -match "\s") { return "选项含空格" }
    return ""
}

$report = New-Object System.Collections.Generic.List[string]
$report.Add("问道长生本地 AI 质量压测")
$report.Add("时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$report.Add("后端: $Backend")
$report.Add("超时: ${TimeoutSec}s")
$report.Add("")

$passCount = 0
$nativePassCount = 0
$repairedPassCount = 0
$repairCount = 0
$caseIndex = 0
$caseResults = New-Object System.Collections.Generic.List[object]
foreach ($case in $cases) {
    $caseIndex++
    $caseDir = Join-Path $EvalRoot ("{0:00}_{1}" -f $caseIndex, $case.Id)
    if (Test-Path -LiteralPath $caseDir) {
        $resolvedEvalRoot = [System.IO.Path]::GetFullPath($EvalRoot)
        $resolvedCaseDir = [System.IO.Path]::GetFullPath($caseDir)
        if (-not $resolvedCaseDir.StartsWith($resolvedEvalRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to clear unexpected eval path: $resolvedCaseDir"
        }
        Remove-Item -LiteralPath $caseDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $caseDir "ai_prompt.txt"), [string]$case.Prompt, $encoding)

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $ok = $true
    $issues = New-Object System.Collections.Generic.List[string]
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $Generator `
            -ReleaseDir $caseDir `
            -Backend $Backend `
            -PortableTimeoutSec $TimeoutSec `
            -OllamaTimeoutSec $TimeoutSec | Out-Null
    } catch {
        $ok = $false
        $issues.Add("生成脚本失败: $($_.Exception.Message)")
    }
    $sw.Stop()

    $eventPath = Join-Path $caseDir "ai_event.txt"
    $backendPath = Join-Path $caseDir "ai_backend.txt"
    $statusPath = Join-Path $caseDir "ai_status.txt"
    $rawPath = Join-Path $caseDir "ai_event_raw.txt"

    $eventText = ""
    if (Test-Path -LiteralPath $eventPath) {
        $eventText = [System.IO.File]::ReadAllText($eventPath, [System.Text.Encoding]::UTF8)
    } else {
        $ok = $false
        $issues.Add("缺少 ai_event.txt")
    }

    $lines = @()
    if (-not [string]::IsNullOrWhiteSpace($eventText)) {
        $lines = @($eventText -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    if ($lines.Count -ne 5) {
        $ok = $false
        $issues.Add("输出行数不是 5 行: $($lines.Count)")
    }
    if ($lines.Count -ge 1) {
        if ($lines[0] -notmatch "^【(机缘|危机|奇遇|因果|传承)】") {
            $ok = $false
            $issues.Add("标题标签不合法: $($lines[0])")
        }
        if ($lines[0].Length -gt 34) {
            $ok = $false
            $issues.Add("标题过长: $($lines[0])")
        }
        if (Test-ContextLabelLine $lines[0]) {
            $ok = $false
            $issues.Add("标题像上下文字段: $($lines[0])")
        }
    }
    if ($lines.Count -ge 2) {
        $descLen = $lines[1].Length
        if ($descLen -lt 35 -or $descLen -gt 120) {
            $ok = $false
            $issues.Add("描述长度异常: $descLen")
        }
        if ($lines[1] -notmatch "[。！？]$") {
            $ok = $false
            $issues.Add("描述疑似截断: $($lines[1])")
        }
        if (Test-TitleLike $lines[1]) {
            $ok = $false
            $issues.Add("描述像标题: $($lines[1])")
        }
        if (Test-ContextLabelLine $lines[1]) {
            $ok = $false
            $issues.Add("描述像上下文字段: $($lines[1])")
        }
        if ($lines[1] -match "^(请选择|选择|选项|标题|描述)") {
            $ok = $false
            $issues.Add("描述像模型答题格式: $($lines[1])")
        }
    }
    if ($lines.Count -ge 5) {
        for ($i = 2; $i -lt 5; $i++) {
            $choiceIssue = Test-ChoiceShape $lines[$i]
            if ($choiceIssue) {
                $ok = $false
                $issues.Add("${choiceIssue}: $($lines[$i])")
            }
        }
    }
    if (Test-Mojibake $eventText) {
        $ok = $false
        $issues.Add("疑似乱码")
    }
    if (Test-BrokenText $eventText) {
        $ok = $false
        $issues.Add("疑似病句残片")
    }
    $forbiddenHits = Test-Forbidden $eventText
    if ($forbiddenHits.Count -gt 0) {
        $ok = $false
        $issues.Add("命中禁词: $($forbiddenHits -join ', ')")
    }

    $mustHits = @()
    $groundedText = if ($lines.Count -ge 2) { $lines[0] + "`n" + $lines[1] } else { $eventText }
    foreach ($word in $case.MustContain) {
        if ($groundedText.Contains($word)) {
            $mustHits += $word
        }
    }
    $groundingOk = $mustHits.Count -ge 2
    if (-not $groundingOk) {
        $ok = $false
        $issues.Add("标题+描述场景关键词不足: $($mustHits.Count)/2，需要 $($case.MustContain -join ', ')")
    }
    $requiredGroupHits = @()
    if ($case.ContainsKey("RequiredGroups")) {
        foreach ($group in $case.RequiredGroups) {
            $groupHits = @()
            foreach ($word in $group.Words) {
                if ($groundedText.Contains($word)) {
                    $groupHits += $word
                }
            }
            if ($groupHits.Count -eq 0) {
                $ok = $false
                $issues.Add("缺少必需关键词组【$($group.Label)】: $($group.Words -join ', ')")
            } else {
                $requiredGroupHits += "$($group.Label)=$($groupHits -join '/')"
            }
        }
    }

    $backendText = if (Test-Path -LiteralPath $backendPath) { [System.IO.File]::ReadAllText($backendPath, [System.Text.Encoding]::UTF8).Trim() } else { "unknown" }
    $statusText = if (Test-Path -LiteralPath $statusPath) { [System.IO.File]::ReadAllText($statusPath, [System.Text.Encoding]::UTF8).Trim() } else { "" }
    $rawLen = if (Test-Path -LiteralPath $rawPath) { ([System.IO.File]::ReadAllText($rawPath, [System.Text.Encoding]::UTF8)).Length } else { 0 }

    if ($Backend -eq "portable") {
        if ($backendText -notmatch "^portable-llama\.cpp:.*gemma-4") {
            $ok = $false
            $issues.Add("portable 后端未真正跑通: $backendText")
        }
        if ($statusText -match "失败|failed|fallback|回退") {
            $ok = $false
            $issues.Add("portable 后端状态异常: $statusText")
        }
    }

    $wasRepaired = $statusText -match "修复"
    if ($wasRepaired) { $repairCount++ }
    if ($ok) {
        $passCount++
        if ($wasRepaired) { $repairedPassCount++ } else { $nativePassCount++ }
    }
    $qualityText = if ($wasRepaired) { "repaired" } else { "native" }
    $report.Add("[$($case.Id)] " + ($(if ($ok) { "PASS" } else { "FAIL" })) + " / $qualityText / $([math]::Round($sw.Elapsed.TotalSeconds, 1))s / backend=$backendText / rawChars=$rawLen")
    if ($statusText) { $report.Add("status: $statusText") }
    if ($statusText -match "修复") { $report.Add("note: 模型原始输出触发了后处理，最终事件由质量闸门修正。") }
    if ($mustHits.Count -gt 0) { $report.Add("grounding: $($mustHits -join ', ')") }
    if ($requiredGroupHits.Count -gt 0) { $report.Add("required-groups: $($requiredGroupHits -join '; ')") }
    if ($issues.Count -gt 0) {
        foreach ($issue in $issues) { $report.Add("issue: $issue") }
    }
    if ($lines.Count -gt 0) {
        $report.Add("event:")
        foreach ($line in $lines) { $report.Add("  $line") }
    }
    $caseResults.Add([pscustomobject]@{
        id = $case.Id
        ok = $ok
        quality = $qualityText
        elapsedSec = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        backend = $backendText
        rawChars = $rawLen
        status = $statusText
        grounding = @($mustHits)
        issues = @($issues.ToArray())
        event = @($lines)
    })
    $report.Add("")
}

$summary = "SUMMARY: $passCount/$($cases.Count) passed (native=$nativePassCount, repaired=$repairedPassCount, failed=$($cases.Count - $passCount))"
$repairSummary = "REPAIRS: $repairCount/$($cases.Count) cases used quality gate"
$report.Insert(4, $summary)
$report.Insert(5, $repairSummary)
$report.Insert(6, "")
$reportPath = Join-Path $EvalRoot "ai_eval_report.txt"
[System.IO.File]::WriteAllText($reportPath, ($report -join [Environment]::NewLine), $encoding)
$summaryPath = Join-Path $EvalRoot "ai_eval_summary.json"
$failedCount = $cases.Count - $passCount
$summaryObject = [ordered]@{
    generatedAt = (Get-Date).ToString("s")
    backend = $Backend
    timeoutSec = $TimeoutSec
    total = $cases.Count
    passed = $passCount
    native = $nativePassCount
    repaired = $repairedPassCount
    failed = $failedCount
    repairCount = $repairCount
    cases = @($caseResults.ToArray())
}
[System.IO.File]::WriteAllText($summaryPath, ($summaryObject | ConvertTo-Json -Depth 6), $encoding)
Write-Output $summary
Write-Output $reportPath
Write-Output $summaryPath
