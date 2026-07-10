param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'src\wendao_enhanced.cpp'

if (!(Test-Path -LiteralPath $src)) {
    throw "Source file not found: $src"
}

$content = Get-Content -LiteralPath $src -Raw -Encoding UTF8
$changed = $false

# v0.2 菜单辅助函数需要被 ReturnFromInfoPage 提前引用，因此先补前置声明。
if ($content -notmatch 'V0_2_MENU_HELPER_DECL') {
    $proto = 'bool StartNewGameWithDaoName(HWND hWnd, const wstring& daoName, const wstring& traceReason);'
    if (!$content.Contains($proto)) {
        throw 'Unable to find StartNewGameWithDaoName prototype.'
    }
    $content = $content.Replace($proto, $proto + "`r`nvoid ShowMenuControls(bool visible); // V0_2_MENU_HELPER_DECL")
    $changed = $true
}

# 将原创开局事件接入 EventManager 构造流程。脚本保持幂等，多次执行不会重复插入。
if ($content -notmatch 'V0_2_OPENING_EVENTS_BEGIN') {
    $ctorPattern = '    EventManager\(\) \{\r?\n        InitEvents\(\);\r?\n    \}'
    $ctorReplacement = "    EventManager() {`r`n        InitEvents();`r`n        AddOpeningLocalEvents();`r`n    }"
    $next = [regex]::Replace($content, $ctorPattern, $ctorReplacement, 1)
    if ($next -eq $content) {
        throw 'Unable to patch EventManager constructor.'
    }
    $content = $next

    $marker = '    Event* GetRootBalanceEvent() {'
    $method = @'
    // V0_2_OPENING_EVENTS_BEGIN
    void AddOpeningLocalEvents() {
        AddEvent({
            L"【开局】测灵台余温",
            L"外院测灵台在人群面前亮了一瞬，又很快暗下去。记录执事只写下“根骨不稳”，可你袖中的黑白旧玉却在同一刻微微发烫。",
            {
                {L"压下异样", {L"你没有当众露出破绽，只把旧玉贴近心口。嘲笑声仍在，识海深处却多了一道空阙轮廓\n修为+45，因果+3", L"你强行压住旧玉，反被余温扰得心神发乱\n气血-18"}, 2},
                {L"追问执事", {L"执事没有回答，只让你秋试前再来复测；他把你的名字在册上圈了一笔\n修为+30，因果+6", L"你问得太急，引来更多旁观者注意\n因果-4"}, 0},
                {L"冷眼离场", {L"你转身离开，把今日所有目光都记进心里。旧玉的余温没有消失\n修为+35", L"你走得太快，错过执事与旁人低声提到的旧台裂纹"}, -1}
            }
        }, THEME_GENERAL);

        AddEvent({
            L"【开局】演武场失手",
            L"同院少年故意在演武场点你的名，说根骨不稳的人也该让大家看看斤两。木剑递到你手里，四周已经围满看热闹的人。",
            {
                {L"正面接战", {L"你不拼蛮力，只借步法拆开对方三招，虽未取胜，却让几名旁观者收起笑意\n修为+55，因果+4", L"对方突然加重力道，木剑震裂，你被逼退到场边\n气血-25"}, 3},
                {L"只守不攻", {L"你守得很稳，把他的急躁逼了出来。有人看出你并非全无章法\n修为+40", L"守得太久，旁人只记住你没有还手\n因果-3"}, 0},
                {L"当众认输", {L"你没有把无谓胜负看得太重，保住气血，也记住了对方出招习惯\n寿命+2", L"认输传得很快，轻慢你的人更多了\n因果-6"}, -3}
            }
        }, THEME_CULTIVATION);

        AddEvent({
            L"【旧物】黑白旧玉入梦",
            L"夜半时，旧玉贴着心口发凉。你梦见一扇没有门环的石门，门后有人翻动旧册，却始终不肯念出你的名字。",
            {
                {L"叩问石门", {L"石门没有开启，却落下一粒微光。醒来后，你对自身灵气流向多了一分把握\n修为+70，灵宝共鸣+3", L"门后传来笑声，像是在提醒你此刻还不够资格\n气血-20"}, 5},
                {L"记下梦纹", {L"你把梦里的纹路画在纸上，发现它与测灵台裂纹有几分相似\n修为+45，因果+5", L"梦纹天亮后散去大半，只剩模糊残线"}, 3},
                {L"封起旧玉", {L"你没有被梦兆牵着走，先稳住日常修行\n修为+35", L"旧玉沉寂，短时间不再回应"}, 0}
            }
        }, THEME_GENERAL);

        AddEvent({
            L"【家世】旧账房翻册",
            L"家中旧账房忽然请你去后院，说最近有人在打听你家欠下的旧契。账册边角发霉，却有几页被新近翻动过。",
            {
                {L"细查账册", {L"你查到一笔被人刻意挪过的灵石去向，旧账房看你的眼神多了几分认可\n灵石+12，因果+6", L"账册暗格里藏着追债符，刚碰到就烧了起来\n气血-18"}, 4},
                {L"询问旧账房", {L"旧账房低声提醒：秋试前别轻易接受外人资助\n修为+25，因果+8", L"他只肯说半句，像是仍怕牵连太深"}, 3},
                {L"暂不理会", {L"你把心思压回修炼，没有让旧账扰乱节奏\n修为+30", L"几日后，旧契的风声传到外院，味道已经变了"}, -1}
            }
        }, THEME_GENERAL);

        AddEvent({
            L"【人情】清冷师姐旁观",
            L"演武场边，一位很少开口的内院师姐看完你的失手，没有嘲笑，只问你是否知道自己真正输在哪里。",
            {
                {L"请她指点", {L"她只点出三处破绽，却句句落在要害。你按她所言调息，根基稳了半寸\n修为+65，因果+6", L"她的指点太快，你急着照做反而岔了一口气\n气血-16"}, 5},
                {L"坦言不知道", {L"她看了你很久，说不知道不可耻，不敢问才可耻\n修为+40，因果+4", L"旁人听见后，又添了几句难听闲话\n因果-2"}, 2},
                {L"婉拒好意", {L"你不想欠人情，只把她的话记在心里\n修为+25", L"她没有再说，转身时似乎有些失望"}, 0}
            }
        }, THEME_CULTIVATION);

        AddEvent({
            L"【外院】名额风波",
            L"秋试名册贴出时，你的名字被排在最末。几名同院少年围着榜单低笑，说有人已经准备把你的试炼牌换走。",
            {
                {L"当场核验", {L"你当众核验名册，逼得执事重新盖印。名额保住了，暗处的人也记住了你\n因果+8，修为+25", L"执事敷衍拖延，你只拿到一句等候复查\n因果-4"}, 4},
                {L"暗查换牌者", {L"你顺着试炼牌编号查到一名中间人，暂时没有惊动真正的幕后者\n灵石+8，因果+6", L"中间人早有准备，反手把线索断在坊市\n气血-12"}, 2},
                {L"暂且忍下", {L"你没有在榜前争吵，而是把时间留给修炼\n修为+45", L"忍让让对方以为你软弱，下一次会更直接"}, -2}
            }
        }, THEME_GENERAL);

        AddEvent({
            L"【坊市】残卷摊主",
            L"坊市角落有个摊主卖一堆残卷。他看见你袖中旧玉露出的黑白边角，忽然把最破的一卷推到你面前。",
            {
                {L"买下残卷", {L"残卷文字残缺，却有一段行气法正好能绕开你灵根滞涩处\n修为+80，灵石-8", L"残卷多处误刻，照着修行险些逆行经脉\n气血-22，灵石-8"}, 3},
                {L"追问来历", {L"摊主说这卷不是功法，是某个旧族用来遮掩根骨异象的办法\n因果+8，修为+30", L"摊主忽然收摊，人群一挤便没了踪影"}, 4},
                {L"转身离开", {L"你没有被古怪摊主牵住脚步，省下灵石\n灵石+2", L"旧玉微冷，像是错过了一次敲门声"}, 0}
            }
        }, THEME_GENERAL);

        AddEvent({
            L"【空阙】识海裂光",
            L"修炼到半夜时，灵气本该归入五行，却有一缕偏偏沉向识海深处。那里没有灵根，只有一座安静的空阙。",
            {
                {L"引气入阙", {L"你小心送入一缕灵气，空阙没有吞噬，反而替你洗去杂念\n修为+90，灵宝共鸣+4", L"空阙忽然一震，像拒绝过早触碰\n气血-28"}, 6},
                {L"只作旁观", {L"你没有强行探索，只把空阙变化记入心神。谨慎本身也是修行\n修为+50，因果+3", L"机会很快沉寂，短时间难以再现"}, 2},
                {L"用旧玉镇压", {L"黑白旧玉贴住眉心，空阙轮廓稳了下来\n修为+60", L"旧玉过冷，醒来后指尖微微发麻\n气血-12"}, 3}
            }
        }, THEME_CULTIVATION);
    }
    // V0_2_OPENING_EVENTS_END

'@
    if (!$content.Contains($marker)) {
        throw 'Unable to find GetRootBalanceEvent marker.'
    }
    $content = $content.Replace($marker, $method + $marker)
    $changed = $true
}

# v0.2 主菜单：补继续游戏、读取存档、存档管理、设定、退出键位与返回菜单控制。
if ($content -notmatch 'V0_2_MENU_HELPERS_BEGIN') {
    $marker = 'LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {'
    $helpers = @'
// V0_2_MENU_HELPERS_BEGIN
void ShowMenuControls(bool visible) {
    if (g_nameInput) ShowWindow(g_nameInput, visible ? SW_SHOW : SW_HIDE);
    if (g_btnStart) ShowWindow(g_btnStart, visible ? SW_SHOW : SW_HIDE);
    if (visible) LayoutMenuControls();
}

bool LoadLatestSaveFromMenu(HWND hWnd) {
    EnsureSaveDirectory();
    int bestSlot = -1;
    FILETIME bestTime = {};
    bool hasBest = false;
    for (int slot = 1; slot <= SAVE_SLOT_COUNT; ++slot) {
        wstring path = GetSaveSlotPath(slot);
        WIN32_FILE_ATTRIBUTE_DATA data = {};
        if (!GetFileAttributesExW(path.c_str(), GetFileExInfoStandard, &data)) continue;
        if (!hasBest || CompareFileTime(&data.ftLastWriteTime, &bestTime) > 0) {
            bestSlot = slot;
            bestTime = data.ftLastWriteTime;
            hasBest = true;
        }
    }
    if (bestSlot < 0) return false;
    if (!LoadGameFromPath(GetSaveSlotPath(bestSlot))) return false;
    g_gameState = STATE_GAME;
    g_messageText = L"【继续游戏】\n已接续最近一份旧录：第" + to_wstring(bestSlot) + L"号存档。";
    ShowMenuControls(false);
    InvalidateRect(hWnd, NULL, FALSE);
    return true;
}

void OpenMenuNotice(const wstring& title, const wstring& text) {
    ShowMenuControls(false);
    OpenInfoPage(title, text, STATE_MENU);
}

void HandleMenuKey(HWND hWnd, WPARAM key) {
    if (key == '1') {
        SetFocus(g_nameInput);
        return;
    }
    if (key == '2') {
        if (!LoadLatestSaveFromMenu(hWnd)) {
            OpenMenuNotice(L"继续游戏", L"没有找到可接续的旧录。\n\n可以按 [1] 输入道号开始新生，或按 [3] 查看存档槽。\n\n[ESC] 返回主菜单");
            InvalidateRect(hWnd, NULL, FALSE);
        }
        return;
    }
    if (key == '3') {
        ShowMenuControls(false);
        OpenSaveSlotPage(true);
        InvalidateRect(hWnd, NULL, FALSE);
        return;
    }
    if (key == '4') {
        ShowMenuControls(false);
        OpenSaveSlotPage(true);
        g_infoTitle = L"存档管理";
        g_infoText = L"当前版本先提供读取旧录入口。\n\n后续会在这里补：复制存档、删除存档、查看详细旧录、导出存档。\n\n请选择已有槽位读取，或按 [ESC] 返回主菜单。";
        InvalidateRect(hWnd, NULL, FALSE);
        return;
    }
    if (key == '5') {
        OpenMenuNotice(L"设定", L"当前版本使用默认设定。\n\n后续会补充：文字速度、音量、美术资源包、窗口比例、本地 AI 开关。\n\n[ESC] 返回主菜单");
        InvalidateRect(hWnd, NULL, FALSE);
        return;
    }
    if (key == VK_ESCAPE) {
        PostQuitMessage(0);
    }
}
// V0_2_MENU_HELPERS_END

'@
    if (!$content.Contains($marker)) {
        throw 'Unable to find WndProc marker.'
    }
    $content = $content.Replace($marker, $helpers + $marker)
    $changed = $true
}

if ($content -notmatch 'V0_2_MENU_KEYDOWN_BEGIN') {
    $needle = '        case WM_KEYDOWN: {'
    $insert = @'
        case WM_KEYDOWN: {
            // V0_2_MENU_KEYDOWN_BEGIN
            if (g_gameState == STATE_MENU) {
                HandleMenuKey(hWnd, wParam);
                break;
            }
            // V0_2_MENU_KEYDOWN_END
'@
    if (!$content.Contains($needle)) {
        throw 'Unable to find WM_KEYDOWN marker.'
    }
    $content = $content.Replace($needle, $insert)
    $changed = $true
}

if ($content -notmatch 'V0_2_MENU_RETURN_CONTROLS') {
    $needle = '    g_gameState = g_infoReturnState;'
    $replace = "    g_gameState = g_infoReturnState;`r`n    // V0_2_MENU_RETURN_CONTROLS`r`n    if (g_gameState == STATE_MENU) {`r`n        ShowMenuControls(true);`r`n    }"
    if (!$content.Contains($needle)) {
        throw 'Unable to patch ReturnFromInfoPage.'
    }
    $content = $content.Replace($needle, $replace)
    $changed = $true
}

if ($content -notmatch 'V0_2_SAVE_LOAD_HIDE_MENU') {
    $needle = '        if (LoadGameFromPath(path)) {'
    $replace = "        if (LoadGameFromPath(path)) {`r`n            // V0_2_SAVE_LOAD_HIDE_MENU`r`n            g_gameState = STATE_GAME;`r`n            ShowMenuControls(false);"
    if (!$content.Contains($needle)) {
        throw 'Unable to patch save slot load state.'
    }
    $content = $content.Replace($needle, $replace)
    $changed = $true
}

if ($content -notmatch 'V0_2_SAVE_RETURN_STATE') {
    $pattern = '    OpenInfoPage\(loadMode \? L"[^"]+" : L"[^"]+", BuildSaveSlotIntroText\(loadMode\), STATE_GAME\);'
    $replace = '    OpenInfoPage(loadMode ? L"读取存档" : L"保存存档", BuildSaveSlotIntroText(loadMode), (g_gameState == STATE_MENU ? STATE_MENU : STATE_GAME)); // V0_2_SAVE_RETURN_STATE'
    $replace = $replace.Replace('\"', '"')
    $next = [regex]::Replace($content, $pattern, $replace, 1)
    if ($next -eq $content) {
        throw 'Unable to patch save slot return state.'
    }
    $content = $next
    $changed = $true
}

if ($content -notmatch 'V0_2_MENU_PAINT_OPTIONS') {
    $content = $content.Replace('int panelHeight = 210;', 'int panelHeight = 335; // V0_2_MENU_PAINT_OPTIONS')
    $needle = '            graphics.DrawRectangle(&inputPen, inputRect);'
    $replace = @'
            graphics.DrawRectangle(&inputPen, inputRect);
            Font menuHintFont(&fontFamily, 18, FontStyleRegular, UnitPixel);
            RectF menuHintRect((REAL)panelLeft + 38, (REAL)panelTop + 140, (REAL)panelWidth - 76, 142);
            graphics.DrawString(L"[1] 开始新生 / 输入道号\n[2] 继续游戏（最近旧录）\n[3] 读取存档\n[4] 存档管理\n[5] 设定\n[ESC] 退出游戏", -1, &menuHintFont, menuHintRect, &leftFormat, &softWhiteBrush);
'@
    if (!$content.Contains($needle)) {
        throw 'Unable to patch menu paint options.'
    }
    $content = $content.Replace($needle, $replace)
    $changed = $true
}

if ($changed) {
    Set-Content -LiteralPath $src -Value $content -Encoding UTF8
    Write-Host 'v0.2 opening/menu/content patch applied.'
} else {
    Write-Host 'v0.2 opening/menu/content patch already applied.'
}
