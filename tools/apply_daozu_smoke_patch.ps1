param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'src\wendao_enhanced.cpp'

if (!(Test-Path -LiteralPath $src)) {
    throw "Source file not found: $src"
}

$content = Get-Content -LiteralPath $src -Raw -Encoding UTF8
$changed = $false

if ($content -notmatch 'V0_2_DAOZU_SMOKE_BEGIN') {
    $marker = '// ==================== 主函数 ===================='
    $smoke = @'
// V0_2_DAOZU_SMOKE_BEGIN
int RunDaozuSmokeTest() {
    CreateDirectoryW(L"save", NULL);
    wofstream report(L"dao_smoke_result.txt");
    UseUtf8Locale(report);

    int failures = 0;
    auto log = [&](const wstring& line) {
        if (report) report << line << L"\n";
    };

    log(L"问道长生 v0.2 自动烟测：从凡人境推进到天道境");
    log(L"目标：验证高境界推进、突破、存档读写、道祖后寿元规则不会卡死。\n");

    for (int run = 1; run <= 3; ++run) {
        g_player = Player();
        g_player.name = L"烟测道号" + to_wstring(run);
        g_player.rootFire = 10;
        g_player.rootWater = 10;
        g_player.rootWood = 10;
        g_player.rootMetal = 10;
        g_player.rootEarth = 10;
        g_player.CheckRootBalance();
        g_player.karma = 999;
        g_player.spiritStones = 999999;
        g_player.pills = 9999;
        g_player.age = 16;
        g_player.lifespan = 10000000;
        g_player.hp = g_player.maxHp;
        g_player.mp = g_player.maxMp;

        g_generation = run;
        g_jadeDreamOmenEventsThisLife = 0;
        g_lifeStoryProgressThisLife = 0;
        g_lastLifeStoryProgressEventCount = -1000;
        g_plannedLegacies.clear();
        g_memoryLog.clear();
        g_discoveredItems.clear();
        g_lifeArtifacts.clear();
        g_eraChronicle.clear();
        GenerateWorldEra();
        GenerateHongmengOmen();
        InitWorldData();
        GenerateFactionTie();
        GenerateLifeStoryHooks();
        g_dynamicWorld.SetEraFlavor(g_worldEraName);
        g_dynamicWorld.Reset();
        GenerateSocialRumors();
        InitializeStoryStateForLife();

        log(L"[RUN " + to_wstring(run) + L"] 开局：" + GetRealmName(g_player.realm) + L" " + to_wstring(g_player.level) + L"层；" + g_player.GetRootQuality());

        int guard = 0;
        while (g_player.realm < HEAVENLY_DAO && guard++ < 80) {
            Realm before = g_player.realm;
            g_player.rootFire = 10;
            g_player.rootWater = 10;
            g_player.rootWood = 10;
            g_player.rootMetal = 10;
            g_player.rootEarth = 10;
            g_player.CheckRootBalance();
            g_player.karma = 999;
            g_player.hp = g_player.maxHp;
            g_player.mp = g_player.maxMp;
            g_player.lifespan = max(g_player.lifespan, g_player.age + 1000000);
            g_player.level = 9;
            g_player.exp = g_player.GetExpNeeded();

            if (!g_player.CanBreakthrough()) {
                log(L"  FAIL: " + GetRealmName(g_player.realm) + L" 满层满修为仍不可突破；状态=" + g_player.GetStatusText());
                failures++;
                break;
            }

            bool ok = false;
            for (int attempt = 1; attempt <= 3; ++attempt) {
                if (g_player.TryBreakthrough(9999)) {
                    ok = true;
                    break;
                }
                g_player.level = 9;
                g_player.exp = g_player.GetExpNeeded();
                g_player.hp = g_player.maxHp;
                g_player.karma = 999;
            }

            if (!ok || g_player.realm <= before) {
                log(L"  FAIL: " + GetRealmName(before) + L" 突破失败或境界未推进。");
                failures++;
                break;
            }

            log(L"  -> " + GetRealmName(g_player.realm) + L" " + to_wstring(g_player.level) + L"层，寿元=" + to_wstring(g_player.lifespan));

            if (g_player.IsDead()) {
                log(L"  FAIL: 刚突破后被判定死亡：" + GetRealmName(g_player.realm));
                failures++;
                break;
            }
        }

        if (g_player.realm != HEAVENLY_DAO) {
            log(L"[RUN " + to_wstring(run) + L"] FAIL: 未到天道境，最终=" + GetRealmName(g_player.realm));
            failures++;
        } else {
            log(L"[RUN " + to_wstring(run) + L"] PASS: 已到天道境。状态摘要=" + g_player.GetCultivationProgressLabel());
        }

        wstring savePath = L"save\\dao_smoke_" + to_wstring(run) + L".sav";
        if (!SaveGameToPath(savePath)) {
            log(L"[RUN " + to_wstring(run) + L"] FAIL: 天道境存档失败。路径=" + savePath);
            failures++;
        } else {
            Realm savedRealm = g_player.realm;
            if (!LoadGameFromPath(savePath)) {
                log(L"[RUN " + to_wstring(run) + L"] FAIL: 天道境读档失败。路径=" + savePath);
                failures++;
            } else if (g_player.realm != savedRealm || g_player.realm != HEAVENLY_DAO) {
                log(L"[RUN " + to_wstring(run) + L"] FAIL: 读档后境界不一致，当前=" + GetRealmName(g_player.realm));
                failures++;
            } else {
                log(L"[RUN " + to_wstring(run) + L"] PASS: 天道境存档/读档成功。\n");
            }
        }
    }

    if (failures == 0) {
        log(L"RESULT: PASS");
        return 0;
    }
    log(L"RESULT: FAIL，问题数=" + to_wstring(failures));
    return 1;
}
// V0_2_DAOZU_SMOKE_END

'@
    if (!$content.Contains($marker)) {
        throw 'Unable to find main function marker.'
    }
    $content = $content.Replace($marker, $smoke + $marker)
    $changed = $true
}

if ($content -notmatch 'V0_2_DAOZU_SMOKE_ENTRY') {
    $needle = '    GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);'
    $replace = @'
    GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);
    // V0_2_DAOZU_SMOKE_ENTRY
    if (GetEnvironmentVariableW(L"WENDAO_DAOZU_SMOKE", nullptr, 0) > 0) {
        int smokeCode = RunDaozuSmokeTest();
        GdiplusShutdown(gdiplusToken);
        return smokeCode;
    }
'@
    if (!$content.Contains($needle)) {
        throw 'Unable to find GdiplusStartup marker.'
    }
    $content = $content.Replace($needle, $replace)
    $changed = $true
}

if ($changed) {
    Set-Content -LiteralPath $src -Value $content -Encoding UTF8
    Write-Host 'v0.2 Daozu smoke-test patch applied.'
} else {
    Write-Host 'v0.2 Daozu smoke-test patch already applied.'
}
