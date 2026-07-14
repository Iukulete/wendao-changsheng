# -*- coding: utf-8 -*-
"""Install v0.10 reincarnation-jade weapon mastery, awakenings and techniques.

Runs after v0.9. Achievement weapons stop being static stat sticks: the currently
attuned weapon gains resonance from real play, awakens through three stages,
charges a reusable signature technique, and contributes route-specific event
and breakthrough modifiers. All mastery data is persisted in ACHIEVEMENTS_V3.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
LEGACY = ROOT / "legacy_system" / "legacy_system.h"
MARKER = "V0_10_JADE_WEAPON_AWAKENING"


def once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"Unable to patch {label}: anchor not found")
    return text.replace(old, new, 1)


def main() -> int:
    if not SRC.exists() or not LEGACY.exists():
        raise FileNotFoundError("Required source/header missing")

    source = SRC.read_text(encoding="utf-8")
    header = LEGACY.read_text(encoding="utf-8")
    if MARKER in source and MARKER in header:
        print("v0.10 jade weapon awakening already applied.")
        return 0
    if "V0_9_ACHIEVEMENT_TOASTS" not in source or "V0_9_ACHIEVEMENT_TOASTS" not in header:
        raise RuntimeError("v0.9 achievement weapons must run before v0.10")

    # ---------------- Header: persistent mastery model ----------------
    header = once(header,
        "    int maxHp;\n    int daoHeart;\n    bool unlocked;",
        "    int maxHp;\n    int daoHeart;\n"
        "    int resonance;       // V0_10_JADE_WEAPON_AWAKENING\n"
        "    int awakeningStage;  // 0沉眠 1初鸣 2真名 3道化\n"
        "    int charge;          // 0~100，满后可显圣\n"
        "    int invocations;\n"
        "    bool unlocked;",
        "weapon mastery fields")

    header = once(header,
        "          attack(attack), defense(defense), maxHp(maxHp), daoHeart(daoHeart),\n          unlocked(false) {}",
        "          attack(attack), defense(defense), maxHp(maxHp), daoHeart(daoHeart),\n"
        "          resonance(0), awakeningStage(0), charge(0), invocations(0),\n"
        "          unlocked(false) {}",
        "weapon mastery constructor")

    private_helpers = r'''
    int WeaponStageFromResonance(int resonance) const { // V0_10_JADE_WEAPON_AWAKENING
        if (resonance >= 320) return 3;
        if (resonance >= 140) return 2;
        if (resonance >= 45) return 1;
        return 0;
    }

    wstring WeaponStageName(int stage) const {
        if (stage >= 3) return L"道化";
        if (stage >= 2) return L"真名";
        if (stage >= 1) return L"初鸣";
        return L"沉眠";
    }

    wstring WeaponStyleName(const EternalWeapon& weapon) const {
        if (weapon.id == L"zhanjie" || weapon.id == L"xuesha" ||
            weapon.id == L"jiuxiao" || weapon.id == L"canxing") return L"杀伐";
        if (weapon.id == L"qinglian" || weapon.id == L"suiyue" ||
            weapon.id == L"zuting" || weapon.id == L"lunhui") return L"护生";
        if (weapon.id == L"wandao" || weapon.id == L"heibai" ||
            weapon.id == L"wuliang" || weapon.id == L"sixiang") return L"万道";
        return L"问心";
    }

    int StageScalePercent(int stage) const {
        if (stage >= 3) return 80;
        if (stage >= 2) return 45;
        if (stage >= 1) return 20;
        return 0;
    }

'''
    header = once(header, "    int FindWeaponIndex(const wstring& id) const {", private_helpers + "    int FindWeaponIndex(const wstring& id) const {", "weapon mastery helpers")

    header = once(header,
        "        return weapon.tier * 1000 + weapon.attack * 20 + weapon.defense * 16 +\n               weapon.maxHp / 4 + weapon.daoHeart * 18;",
        "        return weapon.tier * 1000 + weapon.attack * 20 + weapon.defense * 16 +\n"
        "               weapon.maxHp / 4 + weapon.daoHeart * 18 +\n"
        "               weapon.awakeningStage * 260 + weapon.resonance / 3;",
        "weapon score mastery")

    public_methods = r'''
    int GetEquippedWeaponResonance() const {
        const EternalWeapon* weapon = GetEquippedWeapon();
        return weapon ? weapon->resonance : 0;
    }

    int GetEquippedWeaponStage() const {
        const EternalWeapon* weapon = GetEquippedWeapon();
        return weapon ? weapon->awakeningStage : 0;
    }

    int GetEquippedWeaponCharge() const {
        const EternalWeapon* weapon = GetEquippedWeapon();
        return weapon ? weapon->charge : 0;
    }

    wstring GetEquippedWeaponStageName() const {
        const EternalWeapon* weapon = GetEquippedWeapon();
        return weapon ? WeaponStageName(weapon->awakeningStage) : L"未唤醒";
    }

    wstring GetEquippedWeaponStyleName() const {
        const EternalWeapon* weapon = GetEquippedWeapon();
        return weapon ? WeaponStyleName(*weapon) : L"无";
    }

    void GetEquippedWeaponEffectiveBonuses(int& attack, int& defense, int& maxHp, int& daoHeart) const {
        attack = defense = maxHp = daoHeart = 0;
        const EternalWeapon* weapon = GetEquippedWeapon();
        if (!weapon) return;
        int scale = StageScalePercent(weapon->awakeningStage);
        attack = weapon->attack + weapon->attack * scale / 100;
        defense = weapon->defense + weapon->defense * scale / 100;
        maxHp = weapon->maxHp + weapon->maxHp * scale / 100;
        daoHeart = weapon->daoHeart + weapon->daoHeart * scale / 100;
        wstring style = WeaponStyleName(*weapon);
        int stage = weapon->awakeningStage;
        if (style == L"杀伐") attack += stage * 3;
        else if (style == L"护生") { defense += stage * 2; maxHp += stage * 45; }
        else if (style == L"问心") daoHeart += stage * 2;
        else { attack += stage * 2; defense += stage * 2; maxHp += stage * 30; daoHeart += stage; }
    }

    int GetEquippedWeaponBreakthroughBonus() const {
        const EternalWeapon* weapon = GetEquippedWeapon();
        if (!weapon) return 0;
        int stage = weapon->awakeningStage;
        wstring style = WeaponStyleName(*weapon);
        if (style == L"问心") return stage * 3;
        if (style == L"万道") return stage * 4;
        if (style == L"护生") return stage * 2;
        return stage;
    }

    int GetEquippedWeaponAdventureSuccessBonus() const {
        const EternalWeapon* weapon = GetEquippedWeapon();
        if (!weapon) return 0;
        int stage = weapon->awakeningStage;
        wstring style = WeaponStyleName(*weapon);
        if (style == L"杀伐") return stage * 4;
        if (style == L"万道") return stage * 3;
        if (style == L"问心") return stage * 2;
        return stage;
    }

    bool AddEquippedWeaponResonance(int amount, const wstring& reason) {
        if (amount <= 0 || equippedWeapon < 0 || equippedWeapon >= (int)jadeWeapons.size()) return false;
        EternalWeapon& weapon = jadeWeapons[equippedWeapon];
        if (!weapon.unlocked) return false;
        int oldStage = weapon.awakeningStage;
        weapon.resonance = min(9999, weapon.resonance + amount);
        weapon.charge = min(100, weapon.charge + max(1, amount * 2));
        weapon.awakeningStage = max(weapon.awakeningStage, WeaponStageFromResonance(weapon.resonance));
        if (weapon.awakeningStage > oldStage) {
            AchievementUnlockNotice notice;
            notice.id = L"weapon_awaken_" + weapon.id + L"_" + to_wstring(weapon.awakeningStage);
            notice.name = weapon.name + L"·" + WeaponStageName(weapon.awakeningStage);
            notice.description = L"轮回玉兵在真实道途中完成新一层苏醒。缘由：" + reason;
            notice.tier = min(ACHIEVEMENT_TIER_HEAVEN, max(weapon.tier, weapon.awakeningStage - 1));
            notice.rewardWeapon = weapon.name;
            notice.rewardText = L"共鸣" + to_wstring(weapon.resonance) + L"；道法流派：" + WeaponStyleName(weapon);
            pendingUnlocks.push_back(notice);
            return true;
        }
        return false;
    }

    bool CanInvokeEquippedWeapon() const {
        const EternalWeapon* weapon = GetEquippedWeapon();
        return weapon && weapon->charge >= 100;
    }

    bool ConsumeEquippedWeaponCharge() {
        if (!CanInvokeEquippedWeapon()) return false;
        EternalWeapon& weapon = jadeWeapons[equippedWeapon];
        weapon.charge = 0;
        weapon.invocations++;
        return true;
    }

'''
    header = once(header, "    bool EquipNextUnlockedWeapon() {", public_methods + "    bool EquipNextUnlockedWeapon() {", "weapon mastery public API")

    header = once(header,
        "                ss << L\"  加成：攻击+\" << weapon.attack << L\"，防御+\" << weapon.defense\n                   << L\"，气血+\" << weapon.maxHp << L\"，道心+\" << weapon.daoHeart << L\"\\n\";",
        "                int effectiveAttack = weapon.attack + weapon.attack * StageScalePercent(weapon.awakeningStage) / 100;\n"
        "                int effectiveDefense = weapon.defense + weapon.defense * StageScalePercent(weapon.awakeningStage) / 100;\n"
        "                int effectiveHp = weapon.maxHp + weapon.maxHp * StageScalePercent(weapon.awakeningStage) / 100;\n"
        "                int effectiveDao = weapon.daoHeart + weapon.daoHeart * StageScalePercent(weapon.awakeningStage) / 100;\n"
        "                ss << L\"  觉醒：\" << WeaponStageName(weapon.awakeningStage)\n"
        "                   << L\" · 共鸣\" << weapon.resonance << L\" · 显圣蓄能\" << weapon.charge << L\"/100\"\n"
        "                   << L\" · \" << WeaponStyleName(weapon) << L\"道法\\n\";\n"
        "                ss << L\"  基础加成：攻击+\" << effectiveAttack << L\"，防御+\" << effectiveDefense\n"
        "                   << L\"，气血+\" << effectiveHp << L\"，道心+\" << effectiveDao << L\"\\n\";",
        "armory mastery display")

    old_save = '''        file << L"ACHIEVEMENTS_V2\\n";
        file << achievements.size() << L"\\n";
        for (const auto& achievement : achievements) file << achievement.unlocked << L"\\n";
        file << jadeWeapons.size() << L"\\n";
        for (const auto& weapon : jadeWeapons) file << weapon.unlocked << L"\\n";
        file << equippedWeapon << L"\\n";'''
    new_save = '''        file << L"ACHIEVEMENTS_V3\\n";
        file << achievements.size() << L"\\n";
        for (const auto& achievement : achievements) file << achievement.unlocked << L"\\n";
        file << jadeWeapons.size() << L"\\n";
        for (const auto& weapon : jadeWeapons) {
            file << weapon.unlocked << L" " << weapon.resonance << L" "
                 << weapon.awakeningStage << L" " << weapon.charge << L" "
                 << weapon.invocations << L"\\n";
        }
        file << equippedWeapon << L"\\n";'''
    header = once(header, old_save, new_save, "achievement v3 save")

    header = once(header,
        "        bool isV1 = marker == L\"ACHIEVEMENTS_V1\";\n        bool isV2 = marker == L\"ACHIEVEMENTS_V2\";\n        if (!isV1 && !isV2) return false;",
        "        bool isV1 = marker == L\"ACHIEVEMENTS_V1\";\n"
        "        bool isV2 = marker == L\"ACHIEVEMENTS_V2\";\n"
        "        bool isV3 = marker == L\"ACHIEVEMENTS_V3\";\n"
        "        if (!isV1 && !isV2 && !isV3) return false;",
        "achievement v3 marker")

    header = once(header,
        "        for (auto& weapon : jadeWeapons) weapon.unlocked = false;",
        "        for (auto& weapon : jadeWeapons) {\n"
        "            weapon.unlocked = false; weapon.resonance = 0; weapon.awakeningStage = 0;\n"
        "            weapon.charge = 0; weapon.invocations = 0;\n"
        "        }",
        "reset mastery load")

    old_weapon_load = '''        if (isV2) {
            size_t weaponCount = 0;
            file >> weaponCount;
            file.ignore(numeric_limits<streamsize>::max(), L'\\n');
            for (size_t i = 0; i < weaponCount; ++i) {
                bool unlocked = false;
                file >> unlocked;
                file.ignore(numeric_limits<streamsize>::max(), L'\\n');
                if (i < jadeWeapons.size()) jadeWeapons[i].unlocked = unlocked;
            }
            file >> equippedWeapon;
            file.ignore(numeric_limits<streamsize>::max(), L'\\n');
            if (equippedWeapon < 0 || equippedWeapon >= (int)jadeWeapons.size() ||
                !jadeWeapons[equippedWeapon].unlocked) SelectStrongestUnlockedWeapon();
        } else {'''
    new_weapon_load = '''        if (isV2 || isV3) {
            size_t weaponCount = 0;
            file >> weaponCount;
            file.ignore(numeric_limits<streamsize>::max(), L'\\n');
            for (size_t i = 0; i < weaponCount; ++i) {
                bool unlocked = false;
                int resonance = 0, stage = 0, charge = 0, invocations = 0;
                if (isV3) file >> unlocked >> resonance >> stage >> charge >> invocations;
                else file >> unlocked;
                file.ignore(numeric_limits<streamsize>::max(), L'\\n');
                if (i < jadeWeapons.size()) {
                    jadeWeapons[i].unlocked = unlocked;
                    jadeWeapons[i].resonance = max(0, resonance);
                    jadeWeapons[i].awakeningStage = max(stage, WeaponStageFromResonance(resonance));
                    jadeWeapons[i].charge = max(0, min(100, charge));
                    jadeWeapons[i].invocations = max(0, invocations);
                }
            }
            file >> equippedWeapon;
            file.ignore(numeric_limits<streamsize>::max(), L'\\n');
            if (equippedWeapon < 0 || equippedWeapon >= (int)jadeWeapons.size() ||
                !jadeWeapons[equippedWeapon].unlocked) SelectStrongestUnlockedWeapon();
        } else {'''
    header = once(header, old_weapon_load, new_weapon_load, "achievement v3 load")

    # ---------------- Source: state tracking, effective bonuses and active technique ----------------
    source = once(source,
        "int g_appliedJadeWeaponDaoHeart = 0;",
        "int g_appliedJadeWeaponDaoHeart = 0;\n"
        "bool g_jadeWeaponTrackInitialized = false; // V0_10_JADE_WEAPON_AWAKENING\n"
        "int g_jadeWeaponTrackGeneration = 0;\n"
        "int g_jadeWeaponTrackRealm = 0;\n"
        "int g_jadeWeaponTrackLevel = 0;\n"
        "int g_jadeWeaponTrackEvents = 0;\n"
        "int g_jadeWeaponTrackBattles = 0;\n"
        "int g_jadeWeaponTrackExp = 0;",
        "mastery tracking globals")

    source = once(source,
        "    int attack = weapon ? weapon->attack : 0;\n    int defense = weapon ? weapon->defense : 0;\n    int maxHp = weapon ? weapon->maxHp : 0;\n    int daoHeart = weapon ? weapon->daoHeart : 0;",
        "    int attack = 0, defense = 0, maxHp = 0, daoHeart = 0;\n"
        "    g_achievementSystem.GetEquippedWeaponEffectiveBonuses(attack, defense, maxHp, daoHeart);",
        "effective mastery bonuses sync")

    source = once(source,
        "    const EternalWeapon* weapon = g_achievementSystem.GetEquippedWeapon();\n    g_appliedJadeWeaponAttack = weapon ? weapon->attack : 0;\n    g_appliedJadeWeaponDefense = weapon ? weapon->defense : 0;\n    g_appliedJadeWeaponMaxHp = weapon ? weapon->maxHp : 0;\n    g_appliedJadeWeaponDaoHeart = weapon ? weapon->daoHeart : 0;",
        "    int attack = 0, defense = 0, maxHp = 0, daoHeart = 0;\n"
        "    g_achievementSystem.GetEquippedWeaponEffectiveBonuses(attack, defense, maxHp, daoHeart);\n"
        "    g_appliedJadeWeaponAttack = attack;\n"
        "    g_appliedJadeWeaponDefense = defense;\n"
        "    g_appliedJadeWeaponMaxHp = maxHp;\n"
        "    g_appliedJadeWeaponDaoHeart = daoHeart;",
        "effective mastery bonuses load")

    mastery_functions = r'''
void ResetJadeWeaponProgressTracker() { // V0_10_JADE_WEAPON_AWAKENING
    g_jadeWeaponTrackInitialized = false;
}

void TrackJadeWeaponResonanceFromState() {
    if (g_gameState == STATE_MENU || !g_achievementSystem.GetEquippedWeapon()) {
        g_jadeWeaponTrackInitialized = false;
        return;
    }
    if (!g_jadeWeaponTrackInitialized || g_jadeWeaponTrackGeneration != g_generation) {
        g_jadeWeaponTrackInitialized = true;
        g_jadeWeaponTrackGeneration = g_generation;
        g_jadeWeaponTrackRealm = (int)g_player.realm;
        g_jadeWeaponTrackLevel = g_player.level;
        g_jadeWeaponTrackEvents = g_player.totalEvents;
        g_jadeWeaponTrackBattles = g_player.battlesWon;
        g_jadeWeaponTrackExp = g_player.exp;
        return;
    }

    int realmDelta = max(0, (int)g_player.realm - g_jadeWeaponTrackRealm);
    int levelDelta = max(0, g_player.level - g_jadeWeaponTrackLevel);
    int eventDelta = max(0, g_player.totalEvents - g_jadeWeaponTrackEvents);
    int battleDelta = max(0, g_player.battlesWon - g_jadeWeaponTrackBattles);
    bool cultivated = g_player.exp > g_jadeWeaponTrackExp && realmDelta == 0 && levelDelta == 0 && eventDelta == 0;
    int amount = realmDelta * 18 + levelDelta * 4 + eventDelta * 5 + battleDelta * 3 + (cultivated ? 1 : 0);
    wstring reason = realmDelta > 0 ? L"破境" : (eventDelta > 0 ? L"历练" : (battleDelta > 0 ? L"胜战" : L"修炼"));
    if (amount > 0) {
        int oldStage = g_achievementSystem.GetEquippedWeaponStage();
        bool awakened = g_achievementSystem.AddEquippedWeaponResonance(amount, reason);
        int newStage = g_achievementSystem.GetEquippedWeaponStage();
        AppendTraceLog(L"JADE_WEAPON_RESONANCE",
            g_achievementSystem.GetEquippedWeaponName() + L" +" + to_wstring(amount) +
            L"，共鸣" + to_wstring(g_achievementSystem.GetEquippedWeaponResonance()) +
            L"，蓄能" + to_wstring(g_achievementSystem.GetEquippedWeaponCharge()) + L"/100");
        if (awakened || newStage != oldStage) SyncJadeWeaponBonuses();
    }

    g_jadeWeaponTrackRealm = (int)g_player.realm;
    g_jadeWeaponTrackLevel = g_player.level;
    g_jadeWeaponTrackEvents = g_player.totalEvents;
    g_jadeWeaponTrackBattles = g_player.battlesWon;
    g_jadeWeaponTrackExp = g_player.exp;
}

int GetJadeWeaponBreakthroughBonus() {
    return g_achievementSystem.GetEquippedWeaponBreakthroughBonus();
}

int GetJadeWeaponAdventureSuccessBonus() {
    return g_achievementSystem.GetEquippedWeaponAdventureSuccessBonus();
}

wstring InvokeJadeWeaponTechnique() {
    const EternalWeapon* weapon = g_achievementSystem.GetEquippedWeapon();
    if (!weapon) return L"轮回玉中尚无可显圣的兵器。";
    if (!g_achievementSystem.CanInvokeEquippedWeapon()) {
        return weapon->name + L"尚未蓄满显圣之力，当前" +
            to_wstring(g_achievementSystem.GetEquippedWeaponCharge()) + L"/100。修炼、历练、胜战与破境都会积累。";
    }

    wstring style = g_achievementSystem.GetEquippedWeaponStyleName();
    int stage = max(1, g_achievementSystem.GetEquippedWeaponStage());
    int expGain = 40 + (int)g_player.realm * 10 + stage * 28;
    wstring result;
    if (style == L"杀伐") {
        g_player.exp += expGain * 2;
        g_player.spiritStones += 3 + stage * 2;
        result = L"杀伐道影斩开眼前瓶颈，修为+" + to_wstring(expGain * 2) +
            L"，灵石+" + to_wstring(3 + stage * 2) + L"。";
    } else if (style == L"护生") {
        int heal = max(80, g_player.maxHp * (18 + stage * 4) / 100);
        g_player.hp = min(g_player.maxHp, g_player.hp + heal);
        g_player.pills += stage >= 2 ? 1 : 0;
        result = L"护生道影镇住伤势，气血恢复" + to_wstring(heal) +
            (stage >= 2 ? L"，并凝成丹药1枚。" : L"。 ");
    } else if (style == L"问心") {
        g_player.exp += expGain;
        g_player.daoHeart = min(999, g_player.daoHeart + stage);
        result = L"心锋照见当前道途，修为+" + to_wstring(expGain) +
            L"，道心+" + to_wstring(stage) + L"。";
    } else {
        int heal = max(50, g_player.maxHp * (8 + stage * 3) / 100);
        g_player.exp += expGain + stage * 20;
        g_player.hp = min(g_player.maxHp, g_player.hp + heal);
        g_player.daoHeart = min(999, g_player.daoHeart + max(1, stage - 1));
        result = L"万道兵影同时稳住形神，修为+" + to_wstring(expGain + stage * 20) +
            L"，气血恢复" + to_wstring(heal) + L"。";
    }
    NormalizeCultivationProgress();
    g_achievementSystem.ConsumeEquippedWeaponCharge();
    AddMemory(L"轮回玉兵显圣", weapon->name + L"以" + style + L"道法回应今生。" + result);
    AppendTraceLog(L"JADE_WEAPON_INVOKE", weapon->name + L"·" +
        g_achievementSystem.GetEquippedWeaponStageName() + L" | " + result);
    ResetJadeWeaponProgressTracker();
    return weapon->name + L"显圣。" + result;
}

'''
    source = once(source, "void EvaluateLiveAchievements() {", mastery_functions + "void EvaluateLiveAchievements() {", "mastery runtime functions")

    source = once(source,
        "    vector<AchievementUnlockNotice> notices = g_achievementSystem.ConsumeUnlockNotices();",
        "    TrackJadeWeaponResonanceFromState();\n\n"
        "    vector<AchievementUnlockNotice> notices = g_achievementSystem.ConsumeUnlockNotices();",
        "mastery tracker tick")

    # Route-specific gameplay effects.
    source = once(source,
        "            + GetDaoAdventureSuccessModifier()\n            - g_dynamicWorld.GetAdventureRiskBonus() - eraRisk;",
        "            + GetDaoAdventureSuccessModifier() + GetJadeWeaponAdventureSuccessBonus()\n"
        "            - g_dynamicWorld.GetAdventureRiskBonus() - eraRisk;",
        "AI adventure weapon bonus")

    source = once(source,
        "                                GetEraAdventureRiskModifier() - GetDaoAdventureSuccessModifier() -\n                                g_player.karma / 10;",
        "                                GetEraAdventureRiskModifier() - GetDaoAdventureSuccessModifier() -\n"
        "                                GetJadeWeaponAdventureSuccessBonus() - g_player.karma / 10;",
        "traditional adventure weapon bonus")

    source = once(source,
        "                            bool success = g_player.TryBreakthrough(GetEraBreakthroughModifier() + daoBreakthrough);",
        "                            bool success = g_player.TryBreakthrough(GetEraBreakthroughModifier() + daoBreakthrough +\n"
        "                                GetJadeWeaponBreakthroughBonus());",
        "breakthrough weapon bonus")

    source = once(source,
        "                else if (wParam == 'W' || wParam == 'w') {",
        "                else if (wParam == 'J' || wParam == 'j') {\n"
        "                    SetInlineGameFeedback(L\"玉兵显圣\", InvokeJadeWeaponTechnique(), L\"JADE_WEAPON_INVOKE\");\n"
        "                    InvalidateRect(hWnd, NULL, FALSE);\n"
        "                }\n"
        "                else if (wParam == 'W' || wParam == 'w') {",
        "jade weapon invoke key")

    source = once(source,
        "                L\"[A] 成就玉兵\",\n                L\"[Y] 切换玉兵\"",
        "                L\"[A] 成就玉兵\",\n"
        "                L\"[Y] 切换玉兵\",\n"
        "                L\"[J] 玉兵显圣\"",
        "jade invoke command hint")

    source = once(source,
        '    WriteJsonField(ss, L"jadeWeapon", g_achievementSystem.GetEquippedWeaponName());',
        '    WriteJsonField(ss, L"jadeWeapon", g_achievementSystem.GetEquippedWeaponName());\n'
        '    WriteJsonField(ss, L"jadeWeaponStage", g_achievementSystem.GetEquippedWeaponStageName());\n'
        '    WriteJsonField(ss, L"jadeWeaponStyle", g_achievementSystem.GetEquippedWeaponStyleName());\n'
        '    ss << L"\\\"jadeWeaponResonance\\\":" << g_achievementSystem.GetEquippedWeaponResonance() << L",\\n";\n'
        '    ss << L"\\\"jadeWeaponCharge\\\":" << g_achievementSystem.GetEquippedWeaponCharge() << L",\\n";',
        "mastery Agent JSON")

    source = once(source,
        '       << L" | 玉兵 " << g_achievementSystem.GetEquippedWeaponName();',
        '       << L" | 玉兵 " << g_achievementSystem.GetEquippedWeaponName()\n'
        '       << L"·" << g_achievementSystem.GetEquippedWeaponStageName()\n'
        '       << L" 共鸣" << g_achievementSystem.GetEquippedWeaponResonance();',
        "mastery trace digest")

    header = header.rstrip() + "\n"
    source = source.rstrip() + "\n"
    LEGACY.write_text(header, encoding="utf-8")
    SRC.write_text(source, encoding="utf-8")
    print("Applied v0.10: jade weapon resonance, three awakenings and charged signature techniques.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
