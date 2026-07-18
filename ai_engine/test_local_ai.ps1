param(
    [string]$TestDir = "",
    [int]$TimeoutSec = 120,
    [switch]$KeepFiles
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Root = Split-Path -Parent $PSScriptRoot
$Generator = Join-Path $PSScriptRoot "generate_event.ps1"
$encoding = New-Object System.Text.UTF8Encoding($false)

if ([string]::IsNullOrWhiteSpace($TestDir)) {
    $TestDir = Join-Path $Root "release\_ai_test"
}
$TestDir = [System.IO.Path]::GetFullPath($TestDir)
$releaseRoot = [System.IO.Path]::GetFullPath((Join-Path $Root "release"))

if (-not $TestDir.StartsWith($releaseRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "TestDir must be under release/: $TestDir"
}
if (Test-Path -LiteralPath $TestDir) {
    Remove-Item -LiteralPath $TestDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $TestDir | Out-Null

$promptLines = @(
    "你是修仙 Roguelike 的事件叙事模型。",
    "请基于玩家上下文生成一个原创事件，严格输出5行：标题、描述、选项1、选项2、选项3。",
    "标题必须以【机缘】、【危机】、【奇遇】、【因果】、【传承】之一开头。",
    "描述45到90个中文字符，要贴合境界、家世、人情风波、最近记忆和当前世界。",
    "三个选项各2到8个中文字符，只写行动短语，不要编号。",
    "",
    "玩家: 玄",
    "境界名称: 炼气一层",
    "因果: 第一世，尚无前世记忆。",
    "年龄: 16",
    "灵根: 五行灵根，古典修仙纪灵气丰沛时并非废才。",
    "此世家世: 坊市小族；父亲顾临渊嘴硬护短；母亲叶微澜温柔但警惕；黑白旧玉只是随身旧玉。",
    "人情风波:",
    "- 清蘅真人刚试过你的心性，认可又担心。",
    "- 洛凝霜只在同门传闻中出现，尚未正式相识。",
    "当前世界:",
    "- 时代纪元: 古典修仙纪。",
    "- 时代概况: 灵气丰沛，宗门仍按根骨、心性和家世收徒。",
    "最近记忆:",
    "- 你守住青灯灵息，没有急着炫耀资质。"
)
$prompt = $promptLines -join "`n"
[System.IO.File]::WriteAllText((Join-Path $TestDir "ai_prompt.txt"), $prompt, $encoding)

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$ok = $true
$errorText = ""
try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $Generator `
        -ReleaseDir $TestDir `
        -Backend "portable" `
        -PortableTimeoutSec $TimeoutSec | Out-Null
} catch {
    $ok = $false
    $errorText = $_.Exception.Message
}
$sw.Stop()

function Read-TextFile {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8).Trim()
    }
    return ""
}

$backend = Read-TextFile (Join-Path $TestDir "ai_backend.txt")
$status = Read-TextFile (Join-Path $TestDir "ai_status.txt")
$event = Read-TextFile (Join-Path $TestDir "ai_event.txt")
$log = Read-TextFile (Join-Path $TestDir "ai_llama.log")

$eventIssues = New-Object System.Collections.Generic.List[string]
if ([string]::IsNullOrWhiteSpace($event)) {
    $eventIssues.Add("empty event")
} else {
    $eventLines = @($event -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($eventLines.Count -ne 5) { $eventIssues.Add("event should have exactly 5 lines") }
    if ($event -notmatch "^【(机缘|危机|奇遇|因果|传承)】") {
        $eventIssues.Add("title tag missing")
    }
    if ($event -match "前世|轮回|转世|上一世|旧日因果|不该留下|GenericAgent|provider|系统提示|调试|主界面|按钮") {
        $eventIssues.Add("first-life or debug leakage")
    }
    if ($event -match "，。|；。|、。|，，|。。") {
        $eventIssues.Add("broken punctuation")
    }
}
if ($backend -notmatch "\+lora:") {
    $eventIssues.Add("LoRA adapter was not used")
}

Write-Host "Wendao local AI self-test"
Write-Host "Elapsed: $([Math]::Round($sw.Elapsed.TotalSeconds, 1)) sec"
Write-Host "Result: $(if ($ok) { 'ok' } else { 'failed' })"
if ($backend) { Write-Host "Backend: $backend" }
if ($status) { Write-Host "Status: $status" }
if ($errorText) { Write-Host "Error: $errorText" }
Write-Host ""
Write-Host "Event:"
if ($event) {
    Write-Host $event
} else {
    Write-Host "(none)"
}

if ($eventIssues.Count -gt 0) {
    Write-Host ""
    Write-Host "Issues:"
    foreach ($issue in $eventIssues) { Write-Host "- $issue" }
    $ok = $false
}

if ($log) {
    Write-Host ""
    Write-Host "llama.cpp log tail:"
    (($log -split "`r?`n") | Select-Object -Last 12) -join "`n" | Write-Host
}

if (-not $KeepFiles) {
    Remove-Item -LiteralPath $TestDir -Recurse -Force -ErrorAction SilentlyContinue
}

if (-not $ok) {
    exit 1
}
