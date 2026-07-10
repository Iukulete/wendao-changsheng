# -*- coding: utf-8 -*-
"""Install v0.9 tiered achievement toasts and reincarnation-jade weapons.

This patch upgrades the legacy achievement registry, adds three visual toast tiers,
and makes achievement weapons permanent meta-progression stored outside ordinary
life artifacts. It runs after v0.8 so narrative progress can be achievement input.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
LEGACY = ROOT / "legacy_system" / "legacy_system.h"
MARKER = "V0_9_ACHIEVEMENT_TOASTS"


def once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"Unable to patch {label}: anchor not found")
    return text.replace(old, new, 1)


ACHIEVEMENT_SECTION = r'''// ==================== 成就与轮回玉藏兵系统 ====================
enum AchievementTier {
    ACHIEVEMENT_TIER_JADE = 0,
    ACHIEVEMENT_TIER_MYSTIC = 1,
    ACHIEVEMENT_TIER_HEAVEN = 2
};

inline wstring GetAchievementTierName(int tier) {
    if (tier >= ACHIEVEMENT_TIER_HEAVEN) return L"天命";
    if (tier >= ACHIEVEMENT_TIER_MYSTIC) return L"玄金";
    return L"灵玉";
}

struct EternalWeapon {
    wstring id;
    wstring name;
    wstring description;
    int tier;
    int attack;
    int defense;
    int maxHp;
    int daoHeart;
    bool unlocked;

    EternalWeapon(wstring id, wstring name, wstring description, int tier,
                  int attack, int defense, int maxHp, int daoHeart)
        : id(id), name(name), description(description), tier(tier),
          attack(attack), defense(defense), maxHp(maxHp), daoHeart(daoHeart),
          unlocked(false) {}
};

struct AchievementUnlockNotice {
    wstring id;
    wstring name;
    wstring description;
    int tier;
    wstring rewardWeapon;
    wstring rewardText;
};

struct Achievement {
    wstring id;
    wstring name;
    wstring description;
    int tier;
    wstring rewardWeaponId;
    bool unlocked;

    Achievement(wstring id, wstring name, wstring description, int tier, wstring rewardWeaponId)
        : id(id), name(name), description(description), tier(tier),
          rewardWeaponId(rewardWeaponId), unlocked(false) {}
};

class AchievementSystem { // V0_9_ACHIEVEMENT_TOASTS
private:
    vector<Achievement> achievements;
    vector<EternalWeapon> jadeWeapons;
    vector<AchievementUnlockNotice> pendingUnlocks;
    int equippedWeapon;
    bool legacyWeaponMigrationPending;

    int FindWeaponIndex(const wstring& id) const {
        for (int i = 0; i < (int)jadeWeapons.size(); ++i) {
            if (jadeWeapons[i].id == id) return i;
        }
        return -1;
    }

    int WeaponScore(const EternalWeapon& weapon) const {
        return weapon.tier * 1000 + weapon.attack * 20 + weapon.defense * 16 +
               weapon.maxHp / 4 + weapon.daoHeart * 18;
    }

    void SelectStrongestUnlockedWeapon() {
        int best = -1;
        int bestScore = -1;
        for (int i = 0; i < (int)jadeWeapons.size(); ++i) {
            if (!jadeWeapons[i].unlocked) continue;
            int score = WeaponScore(jadeWeapons[i]);
            if (score > bestScore) { bestScore = score; best = i; }
        }
        equippedWeapon = best;
    }

    bool UnlockIndex(int index, bool queueNotice = true) {
        if (index < 0 || index >= (int)achievements.size()) return false;
        Achievement& achievement = achievements[index];
        if (achievement.unlocked) return false;
        achievement.unlocked = true;

        int weaponIndex = FindWeaponIndex(achievement.rewardWeaponId);
        wstring weaponName = L"轮回玉回响";
        wstring rewardText = L"此成就已写入轮回玉。";
        if (weaponIndex >= 0) {
            jadeWeapons[weaponIndex].unlocked = true;
            weaponName = jadeWeapons[weaponIndex].name;
            rewardText = jadeWeapons[weaponIndex].description;
            if (equippedWeapon < 0 ||
                WeaponScore(jadeWeapons[weaponIndex]) > WeaponScore(jadeWeapons[equippedWeapon])) {
                equippedWeapon = weaponIndex;
            }
        }

        if (queueNotice) {
            AchievementUnlockNotice notice;
            notice.id = achievement.id;
            notice.name = achievement.name;
            notice.description = achievement.description;
            notice.tier = achievement.tier;
            notice.rewardWeapon = weaponName;
            notice.rewardText = rewardText;
            pendingUnlocks.push_back(notice);
        }
        return true;
    }

    int UnlockedCountInternal() const {
        int count = 0;
        for (const auto& achievement : achievements) if (achievement.unlocked) count++;
        return count;
    }

public:
    AchievementSystem() : equippedWeapon(-1), legacyWeaponMigrationPending(false) {
        InitWeapons();
        InitAchievements();
    }

    void InitWeapons() {
        jadeWeapons.clear();
        jadeWeapons.push_back(EternalWeapon(L"qingxiao", L"青霄问心剑", L"灵玉级心剑；飞升后仍被轮回玉完整保存。攻击+8，道心+2。", 0, 8, 0, 0, 2));
        jadeWeapons.push_back(EternalWeapon(L"zhanjie", L"斩劫古刀", L"百战磨出的古刀；不受纪元锈蚀。攻击+14，防御+2。", 1, 14, 2, 0, 0));
        jadeWeapons.push_back(EternalWeapon(L"qinglian", L"青莲护生杖", L"善缘凝成的护生法杖。防御+8，气血+100，道心+3。", 0, 2, 8, 100, 3));
        jadeWeapons.push_back(EternalWeapon(L"xuesha", L"血煞断魄刀", L"恶名与血债铸成的凶兵。攻击+18，气血+60。", 1, 18, 0, 60, 0));
        jadeWeapons.push_back(EternalWeapon(L"suiyue", L"岁月长生木剑", L"五百年风霜未能磨损的木剑。防御+7，气血+150，道心+4。", 0, 3, 7, 150, 4));
        jadeWeapons.push_back(EternalWeapon(L"zuting", L"祖庭镇世剑", L"道祖名位所化的镇世之剑。攻击+25，防御+12，气血+180。", 2, 25, 12, 180, 5));
        jadeWeapons.push_back(EternalWeapon(L"wandao", L"万道归一刃", L"天道境成就凝成的天命神兵。攻击+34，防御+16，气血+280，道心+10。", 2, 34, 16, 280, 10));
        jadeWeapons.push_back(EternalWeapon(L"lunhui", L"轮回断界刀", L"十世轮回仍能认主的玄金重兵。攻击+20，防御+8，气血+160。", 1, 20, 8, 160, 4));
        jadeWeapons.push_back(EternalWeapon(L"chuancheng", L"承道玉简剑", L"多重传承在轮回玉中叠成剑脊。攻击+9，防御+6，道心+3。", 0, 9, 6, 0, 3));
        jadeWeapons.push_back(EternalWeapon(L"baijie", L"百劫照尘锋", L"百次历练留下的每一道判断都刻在刃上。攻击+12，防御+7。", 0, 12, 7, 0, 2));
        jadeWeapons.push_back(EternalWeapon(L"wugou", L"无垢心锋", L"道心如砥后自然显化的玄金心兵。攻击+15，防御+8，道心+8。", 1, 15, 8, 0, 8));
        jadeWeapons.push_back(EternalWeapon(L"jiuxiao", L"九霄名器", L"众生名望汇成的玄金长枪。攻击+13，防御+11，气血+80。", 1, 13, 11, 80, 2));
        jadeWeapons.push_back(EternalWeapon(L"sixiang", L"四象巡道戟", L"四条本世主线全部收束后形成的玄金道兵。攻击+18，防御+12，道心+5。", 1, 18, 12, 0, 5));
        jadeWeapons.push_back(EternalWeapon(L"heibai", L"黑白轮回剑", L"四项跨世定局共同刻入黑白旧玉。攻击+28，防御+20，气血+220，道心+8。", 2, 28, 20, 220, 8));
        jadeWeapons.push_back(EternalWeapon(L"canxing", L"通天残星枪", L"通天灵宝三次苏醒后分出的玄金器影。攻击+19，防御+10，气血+100。", 1, 19, 10, 100, 4));
        jadeWeapons.push_back(EternalWeapon(L"wuliang", L"无量玉皇兵", L"大量成就共同铸出的天命玉兵；天地可改，玉中真形不改。攻击+38，防御+24，气血+360，道心+12。", 2, 38, 24, 360, 12));
    }

    void InitAchievements() {
        achievements.clear();
        // 前九项保持旧版顺序，便于 ACHIEVEMENTS_V1 无损迁移。
        achievements.push_back(Achievement(L"first_ascension", L"初次飞升", L"第一次踏入半仙之体", 0, L"qingxiao"));
        achievements.push_back(Achievement(L"hundred_battles", L"百战不殆", L"一世赢得100场战斗", 1, L"zhanjie"));
        achievements.push_back(Achievement(L"great_kindness", L"善行千里", L"因果达到200", 0, L"qinglian"));
        achievements.push_back(Achievement(L"demonic_supreme", L"魔道至尊", L"因果低于-200", 1, L"xuesha"));
        achievements.push_back(Achievement(L"long_life", L"长生不老", L"一世活到500岁", 0, L"suiyue"));
        achievements.push_back(Achievement(L"dao_ancestor", L"证道成祖", L"达到道祖境界", 2, L"zuting"));
        achievements.push_back(Achievement(L"heavenly_dao", L"万道归一", L"达到道祖-天道境", 2, L"wandao"));
        achievements.push_back(Achievement(L"ten_lives", L"十世轮回", L"经历10次轮回", 1, L"lunhui"));
        achievements.push_back(Achievement(L"legacy_keeper", L"传承者", L"同时拥有5项以上传承回响", 0, L"chuancheng"));
        achievements.push_back(Achievement(L"hundred_events", L"百劫见真", L"一世完成100次历练", 0, L"baijie"));
        achievements.push_back(Achievement(L"steadfast_heart", L"道心如砥", L"道心达到80", 1, L"wugou"));
        achievements.push_back(Achievement(L"renown", L"名动诸天", L"名望达到100", 1, L"jiuxiao"));
        achievements.push_back(Achievement(L"all_arcs", L"四线收束", L"旧玉、山门、家世、战帖四线全部收束", 1, L"sixiang"));
        achievements.push_back(Achievement(L"four_legacies", L"四世定局", L"四条分线都留下跨世定局", 2, L"heibai"));
        achievements.push_back(Achievement(L"relic_three", L"通天三醒", L"通天灵宝残印苏醒三次", 1, L"canxing"));
        achievements.push_back(Achievement(L"jade_armory", L"玉中万兵", L"解锁十二项其他成就", 2, L"wuliang"));
    }

    void CheckLiveProgress(int realm, int age, int karma, int totalEvents,
                           int battlesWon, int generation, int daoHeart,
                           int reputation, int inheritedLegacyCount,
                           int arcProgress, int arcLegacyCount, int relicAwakenings) {
        if (realm >= 10) UnlockIndex(0);
        if (battlesWon >= 100) UnlockIndex(1);
        if (karma >= 200) UnlockIndex(2);
        if (karma <= -200) UnlockIndex(3);
        if (age >= 500) UnlockIndex(4);
        if (realm >= 19) UnlockIndex(5);
        if (realm >= 20) UnlockIndex(6);
        if (generation >= 10) UnlockIndex(7);
        if (inheritedLegacyCount >= 5) UnlockIndex(8);
        if (totalEvents >= 100) UnlockIndex(9);
        if (daoHeart >= 80) UnlockIndex(10);
        if (reputation >= 100) UnlockIndex(11);
        if (arcProgress >= 16) UnlockIndex(12);
        if (arcLegacyCount >= 4) UnlockIndex(13);
        if (relicAwakenings >= 3) UnlockIndex(14);
        if (UnlockedCountInternal() >= 12) UnlockIndex(15);
    }

    void CheckAchievements(PastLife& life, int generation) {
        CheckLiveProgress(life.realmReached, life.ageAtDeath, life.karma,
            life.totalEvents, life.battlesWon, generation, 0, 0,
            (int)life.legacies.size(), 0, 0, 0);
    }

    vector<AchievementUnlockNotice> ConsumeUnlockNotices() {
        vector<AchievementUnlockNotice> result = pendingUnlocks;
        pendingUnlocks.clear();
        return result;
    }

    bool UnlockForTestingTier(int tier) {
        for (int i = 0; i < (int)achievements.size(); ++i) {
            if (!achievements[i].unlocked && achievements[i].tier == tier) return UnlockIndex(i);
        }
        return false;
    }

    int GetUnlockedCount() const { return UnlockedCountInternal(); }
    int GetTotalCount() const { return (int)achievements.size(); }
    int GetUnlockedWeaponCount() const {
        int count = 0;
        for (const auto& weapon : jadeWeapons) if (weapon.unlocked) count++;
        return count;
    }

    const EternalWeapon* GetEquippedWeapon() const {
        if (equippedWeapon < 0 || equippedWeapon >= (int)jadeWeapons.size() ||
            !jadeWeapons[equippedWeapon].unlocked) return nullptr;
        return &jadeWeapons[equippedWeapon];
    }

    wstring GetEquippedWeaponName() const {
        const EternalWeapon* weapon = GetEquippedWeapon();
        return weapon ? weapon->name : L"尚无玉兵";
    }

    bool EquipNextUnlockedWeapon() {
        if (GetUnlockedWeaponCount() <= 0) return false;
        int start = equippedWeapon;
        for (int offset = 1; offset <= (int)jadeWeapons.size(); ++offset) {
            int index = (max(-1, start) + offset) % (int)jadeWeapons.size();
            if (jadeWeapons[index].unlocked) {
                equippedWeapon = index;
                return true;
            }
        }
        return false;
    }

    bool NeedsLegacyWeaponMigrationApply() const { return legacyWeaponMigrationPending; }
    void ClearLegacyWeaponMigrationFlag() { legacyWeaponMigrationPending = false; }

    wstring GetJadeArmoryText() const {
        wstringstream ss;
        ss << L"【轮回玉藏兵】\n";
        ss << L"这些兵器由成就道痕直接凝成，保存在黑白轮回玉内，不属于当世器物，不受纪元断代、天地侵扰或轮回散失。\n";
        ss << L"已解锁 " << GetUnlockedWeaponCount() << L"/" << jadeWeapons.size()
           << L"；当前共鸣：" << GetEquippedWeaponName() << L"。游戏中按 [Y] 可切换已解锁玉兵。\n\n";
        for (const auto& weapon : jadeWeapons) {
            ss << (weapon.unlocked ? L"◆ " : L"◇ ")
               << L"[" << GetAchievementTierName(weapon.tier) << L"] " << weapon.name << L"\n";
            if (weapon.unlocked) {
                ss << L"  " << weapon.description << L"\n";
                ss << L"  加成：攻击+" << weapon.attack << L"，防御+" << weapon.defense
                   << L"，气血+" << weapon.maxHp << L"，道心+" << weapon.daoHeart << L"\n";
            } else {
                ss << L"  尚未由对应成就唤醒。\n";
            }
        }
        return ss.str();
    }

    wstring GetAchievementsText() const {
        wstringstream ss;
        ss << L"【成就】\n\n";
        for (int tier = ACHIEVEMENT_TIER_HEAVEN; tier >= ACHIEVEMENT_TIER_JADE; --tier) {
            ss << L"—— " << GetAchievementTierName(tier) << L"成就 ——\n";
            for (const auto& achievement : achievements) {
                if (achievement.tier != tier) continue;
                ss << (achievement.unlocked ? L"✓ " : L"  ")
                   << achievement.name << L" - " << achievement.description << L"\n";
            }
            ss << L"\n";
        }
        ss << L"解锁：" << GetUnlockedCount() << L"/" << achievements.size() << L"\n\n";
        ss << GetJadeArmoryText();
        return ss.str();
    }

    void Save(wofstream& file) {
        file << L"ACHIEVEMENTS_V2\n";
        file << achievements.size() << L"\n";
        for (const auto& achievement : achievements) file << achievement.unlocked << L"\n";
        file << jadeWeapons.size() << L"\n";
        for (const auto& weapon : jadeWeapons) file << weapon.unlocked << L"\n";
        file << equippedWeapon << L"\n";
    }

    bool Load(wifstream& file) {
        wstring marker;
        getline(file, marker);
        if (marker.empty()) getline(file, marker);
        bool isV1 = marker == L"ACHIEVEMENTS_V1";
        bool isV2 = marker == L"ACHIEVEMENTS_V2";
        if (!isV1 && !isV2) return false;

        for (auto& achievement : achievements) achievement.unlocked = false;
        for (auto& weapon : jadeWeapons) weapon.unlocked = false;
        pendingUnlocks.clear();
        equippedWeapon = -1;
        legacyWeaponMigrationPending = false;

        size_t count = 0;
        file >> count;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        for (size_t i = 0; i < count; ++i) {
            bool unlocked = false;
            file >> unlocked;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
            if (i < achievements.size()) achievements[i].unlocked = unlocked;
        }

        if (isV2) {
            size_t weaponCount = 0;
            file >> weaponCount;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
            for (size_t i = 0; i < weaponCount; ++i) {
                bool unlocked = false;
                file >> unlocked;
                file.ignore(numeric_limits<streamsize>::max(), L'\n');
                if (i < jadeWeapons.size()) jadeWeapons[i].unlocked = unlocked;
            }
            file >> equippedWeapon;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
            if (equippedWeapon < 0 || equippedWeapon >= (int)jadeWeapons.size() ||
                !jadeWeapons[equippedWeapon].unlocked) SelectStrongestUnlockedWeapon();
        } else {
            for (const auto& achievement : achievements) {
                if (!achievement.unlocked) continue;
                int index = FindWeaponIndex(achievement.rewardWeaponId);
                if (index >= 0) jadeWeapons[index].unlocked = true;
            }
            SelectStrongestUnlockedWeapon();
            legacyWeaponMigrationPending = GetUnlockedWeaponCount() > 0;
        }
        return true;
    }
};
'''


SOURCE_SUPPORT = r'''
struct AchievementToastRuntime { // V0_9_ACHIEVEMENT_TOASTS
    AchievementUnlockNotice notice;
    DWORD startedAt;
    bool active;
    AchievementToastRuntime() : startedAt(0), active(false) {}
};

deque<AchievementUnlockNotice> g_achievementToastQueue;
AchievementToastRuntime g_achievementToast;
const UINT_PTR IDT_ACHIEVEMENT_TOAST_V09 = 0xA903;
int g_appliedJadeWeaponAttack = 0;
int g_appliedJadeWeaponDefense = 0;
int g_appliedJadeWeaponMaxHp = 0;
int g_appliedJadeWeaponDaoHeart = 0;

void ResetJadeWeaponAppliedBonuses();
void SyncJadeWeaponBonuses();
void RestoreJadeWeaponStateAfterLoad();
void TickAchievementSystem(HWND hWnd);
void DrawAchievementToastOverlay(HDC hdc, const RECT& rect);

'''


SOURCE_FUNCTIONS = r'''
int CountArcLegacyTagsForAchievements() {
    int count = 0;
    if (!g_arcLegacy.jade.empty()) count++;
    if (!g_arcLegacy.sect.empty()) count++;
    if (!g_arcLegacy.family.empty()) count++;
    if (!g_arcLegacy.rival.empty()) count++;
    return count;
}

void ResetJadeWeaponAppliedBonuses() {
    g_appliedJadeWeaponAttack = 0;
    g_appliedJadeWeaponDefense = 0;
    g_appliedJadeWeaponMaxHp = 0;
    g_appliedJadeWeaponDaoHeart = 0;
}

void SyncJadeWeaponBonuses() {
    const EternalWeapon* weapon = g_achievementSystem.GetEquippedWeapon();
    int attack = weapon ? weapon->attack : 0;
    int defense = weapon ? weapon->defense : 0;
    int maxHp = weapon ? weapon->maxHp : 0;
    int daoHeart = weapon ? weapon->daoHeart : 0;

    g_player.attackPower += attack - g_appliedJadeWeaponAttack;
    g_player.defense += defense - g_appliedJadeWeaponDefense;
    int hpDelta = maxHp - g_appliedJadeWeaponMaxHp;
    g_player.maxHp = max(1, g_player.maxHp + hpDelta);
    g_player.hp = min(g_player.maxHp, max(1, g_player.hp + hpDelta));
    g_player.daoHeart += daoHeart - g_appliedJadeWeaponDaoHeart;
    g_player.daoHeart = max(-999, min(999, g_player.daoHeart));

    bool changed = attack != g_appliedJadeWeaponAttack || defense != g_appliedJadeWeaponDefense ||
                   maxHp != g_appliedJadeWeaponMaxHp || daoHeart != g_appliedJadeWeaponDaoHeart;
    g_appliedJadeWeaponAttack = attack;
    g_appliedJadeWeaponDefense = defense;
    g_appliedJadeWeaponMaxHp = maxHp;
    g_appliedJadeWeaponDaoHeart = daoHeart;
    if (changed) {
        AppendTraceLog(L"JADE_WEAPON_SYNC", g_achievementSystem.GetEquippedWeaponName());
    }
}

void RestoreJadeWeaponStateAfterLoad() {
    if (g_achievementSystem.NeedsLegacyWeaponMigrationApply()) {
        ResetJadeWeaponAppliedBonuses();
        SyncJadeWeaponBonuses();
        g_achievementSystem.ClearLegacyWeaponMigrationFlag();
        AppendTraceLog(L"JADE_WEAPON_MIGRATION", L"旧成就存档已补发对应轮回玉兵。当前：" + g_achievementSystem.GetEquippedWeaponName());
        return;
    }
    const EternalWeapon* weapon = g_achievementSystem.GetEquippedWeapon();
    g_appliedJadeWeaponAttack = weapon ? weapon->attack : 0;
    g_appliedJadeWeaponDefense = weapon ? weapon->defense : 0;
    g_appliedJadeWeaponMaxHp = weapon ? weapon->maxHp : 0;
    g_appliedJadeWeaponDaoHeart = weapon ? weapon->daoHeart : 0;
}

void QueueAchievementToast(const AchievementUnlockNotice& notice) {
    g_achievementToastQueue.push_back(notice);
    AppendTraceLog(L"ACHIEVEMENT_UNLOCK",
        L"[" + GetAchievementTierName(notice.tier) + L"] " + notice.name +
        L"\n奖励玉兵：" + notice.rewardWeapon + L"\n" + notice.rewardText);
}

void EvaluateLiveAchievements() {
    static bool smokeTriggered = false;
    bool smoke = IsTruthyEnvValue(GetEnvironmentText(L"WENDAO_ACHIEVEMENT_SMOKE"));
    if (smoke && !smokeTriggered) {
        g_achievementSystem.UnlockForTestingTier(ACHIEVEMENT_TIER_JADE);
        g_achievementSystem.UnlockForTestingTier(ACHIEVEMENT_TIER_MYSTIC);
        g_achievementSystem.UnlockForTestingTier(ACHIEVEMENT_TIER_HEAVEN);
        smokeTriggered = true;
    }

    if (g_gameState != STATE_MENU) {
        g_achievementSystem.CheckLiveProgress(
            (int)g_player.realm, g_player.age, g_player.karma,
            g_player.totalEvents, g_player.battlesWon, g_generation,
            g_player.daoHeart, g_player.reputation,
            (int)g_legacySystem.GetInheritedLegacies().size(),
            GetNarrativeArcTotalProgress(), CountArcLegacyTagsForAchievements(),
            g_legacySystem.GetRelic().awakenings);
    }

    vector<AchievementUnlockNotice> notices = g_achievementSystem.ConsumeUnlockNotices();
    for (const auto& notice : notices) QueueAchievementToast(notice);
    if (!notices.empty()) SyncJadeWeaponBonuses();
}

DWORD GetAchievementToastDuration(int tier) {
    if (tier >= ACHIEVEMENT_TIER_HEAVEN) return 6500;
    if (tier >= ACHIEVEMENT_TIER_MYSTIC) return 5600;
    return 4800;
}

void TickAchievementSystem(HWND hWnd) {
    EvaluateLiveAchievements();
    DWORD now = GetTickCount();
    if (!g_achievementToast.active && !g_achievementToastQueue.empty()) {
        g_achievementToast.notice = g_achievementToastQueue.front();
        g_achievementToastQueue.pop_front();
        g_achievementToast.startedAt = now;
        g_achievementToast.active = true;
        AppendTraceLog(L"ACHIEVEMENT_TOAST_START",
            L"[" + GetAchievementTierName(g_achievementToast.notice.tier) + L"] " +
            g_achievementToast.notice.name);
    }
    if (g_achievementToast.active) {
        DWORD elapsed = now - g_achievementToast.startedAt;
        if (elapsed >= GetAchievementToastDuration(g_achievementToast.notice.tier)) {
            AppendTraceLog(L"ACHIEVEMENT_TOAST_END", g_achievementToast.notice.name);
            g_achievementToast.active = false;
        }
        InvalidateRect(hWnd, NULL, FALSE);
    }
}

float EaseOutCubicV09(float value) {
    value = max(0.0f, min(1.0f, value));
    float inv = 1.0f - value;
    return 1.0f - inv * inv * inv;
}

void DrawAchievementToastOverlay(HDC hdc, const RECT& rect) {
    if (!g_achievementToast.active) return;
    DWORD elapsed = GetTickCount() - g_achievementToast.startedAt;
    DWORD duration = GetAchievementToastDuration(g_achievementToast.notice.tier);
    if (elapsed >= duration) return;

    const float enterMs = 520.0f;
    const float exitMs = g_achievementToast.notice.tier >= ACHIEVEMENT_TIER_HEAVEN ? 1050.0f : 850.0f;
    float opacity = 1.0f;
    float slide = 1.0f;
    if (elapsed < enterMs) {
        float p = EaseOutCubicV09((float)elapsed / enterMs);
        slide = p;
        opacity = p;
    } else if ((float)elapsed > (float)duration - exitMs) {
        float p = ((float)elapsed - ((float)duration - exitMs)) / exitMs;
        opacity = 1.0f - p;
        slide = 1.0f - p * 0.35f;
    }

    int tier = g_achievementToast.notice.tier;
    float pulse = 0.5f + 0.5f * (float)sin((double)elapsed / 180.0);
    int alpha = max(0, min(255, (int)(255.0f * opacity)));
    REAL width = min<REAL>(720.0f, max<REAL>(480.0f, (REAL)(rect.right - rect.left) * 0.56f));
    REAL height = tier >= ACHIEVEMENT_TIER_HEAVEN ? 154.0f : (tier >= ACHIEVEMENT_TIER_MYSTIC ? 140.0f : 128.0f);
    REAL targetY = (REAL)rect.bottom - height - 34.0f;
    REAL y = (REAL)rect.bottom + 16.0f + (targetY - ((REAL)rect.bottom + 16.0f)) * slide;
    REAL x = ((REAL)rect.right - width) / 2.0f;
    RectF panel(x, y, width, height);

    Graphics graphics(hdc);
    graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Color accent = tier >= ACHIEVEMENT_TIER_HEAVEN
        ? Color(alpha, 255, 198, 54)
        : (tier >= ACHIEVEMENT_TIER_MYSTIC ? Color(alpha, 188, 116, 255) : Color(alpha, 80, 218, 238));
    Color accent2 = tier >= ACHIEVEMENT_TIER_HEAVEN
        ? Color(alpha, 255, 82, 38)
        : (tier >= ACHIEVEMENT_TIER_MYSTIC ? Color(alpha, 255, 196, 76) : Color(alpha, 126, 244, 255));

    SolidBrush shadow(Color((BYTE)(alpha * 0.52f), 0, 0, 0));
    graphics.FillRectangle(&shadow, RectF(panel.X + 8, panel.Y + 10, panel.Width, panel.Height));
    if (tier >= ACHIEVEMENT_TIER_HEAVEN) {
        for (int i = 4; i >= 1; --i) {
            Pen glow(Color((BYTE)(alpha * (0.05f + 0.03f * pulse)), 255, 128, 32), (REAL)(i * 4));
            graphics.DrawRectangle(&glow, RectF(panel.X - i, panel.Y - i, panel.Width + i * 2, panel.Height + i * 2));
        }
    }

    SolidBrush background(Color((BYTE)(alpha * 0.94f), tier >= 2 ? 28 : 13, 11, tier >= 1 ? 32 : 26));
    graphics.FillRectangle(&background, panel);
    Pen outer(accent, tier >= 2 ? 3.0f : 2.0f);
    graphics.DrawRectangle(&outer, panel);
    if (tier >= ACHIEVEMENT_TIER_MYSTIC) {
        Pen inner(accent2, 1.0f);
        graphics.DrawRectangle(&inner, RectF(panel.X + 7, panel.Y + 7, panel.Width - 14, panel.Height - 14));
    }
    if (tier >= ACHIEVEMENT_TIER_HEAVEN) {
        Pen crown(accent2, 2.0f);
        REAL cx = panel.X + panel.Width / 2.0f;
        graphics.DrawLine(&crown, cx - 42, panel.Y, cx - 18, panel.Y - 13);
        graphics.DrawLine(&crown, cx - 18, panel.Y - 13, cx, panel.Y - 3);
        graphics.DrawLine(&crown, cx, panel.Y - 3, cx + 18, panel.Y - 13);
        graphics.DrawLine(&crown, cx + 18, panel.Y - 13, cx + 42, panel.Y);
    }

    int particles = tier >= 2 ? 18 : (tier >= 1 ? 11 : 6);
    SolidBrush particle(accent2);
    for (int i = 0; i < particles; ++i) {
        double phase = (double)elapsed / (210.0 + i * 9.0) + i * 1.83;
        REAL px = panel.X + 18.0f + (REAL)(fmod(i * 97.0 + elapsed * (0.025 + tier * 0.008), max(40.0, (double)panel.Width - 36.0)));
        REAL py = panel.Y + panel.Height - 14.0f - (REAL)(fmod(elapsed * (0.018 + (i % 3) * 0.005) + i * 23.0, max(30.0, (double)panel.Height - 28.0)));
        REAL radius = (REAL)(1.6 + tier * 0.7 + (sin(phase) + 1.0) * 0.7);
        graphics.FillEllipse(&particle, px - radius, py - radius, radius * 2, radius * 2);
    }

    Font tierFont(L"Microsoft YaHei", 16, FontStyleBold, UnitPixel);
    Font titleFont(L"Microsoft YaHei", tier >= 2 ? 27.0f : 24.0f, FontStyleBold, UnitPixel);
    Font bodyFont(L"Microsoft YaHei", 15, FontStyleRegular, UnitPixel);
    Font rewardFont(L"Microsoft YaHei", 16, FontStyleBold, UnitPixel);
    SolidBrush accentBrush(accent);
    SolidBrush white(Color(alpha, 248, 246, 239));
    SolidBrush soft(Color((BYTE)(alpha * 0.9f), 210, 211, 220));
    StringFormat left;
    left.SetAlignment(StringAlignmentNear);
    left.SetTrimming(StringTrimmingEllipsisCharacter);
    left.SetFormatFlags(StringFormatFlagsLineLimit);

    graphics.DrawString((L"成就达成 · " + GetAchievementTierName(tier)).c_str(), -1, &tierFont,
        RectF(panel.X + 24, panel.Y + 14, panel.Width - 48, 24), &left, &accentBrush);
    graphics.DrawString(g_achievementToast.notice.name.c_str(), -1, &titleFont,
        RectF(panel.X + 24, panel.Y + 38, panel.Width - 48, 34), &left, &white);
    graphics.DrawString(g_achievementToast.notice.description.c_str(), -1, &bodyFont,
        RectF(panel.X + 24, panel.Y + 75, panel.Width - 48, 25), &left, &soft);
    graphics.DrawString((L"轮回玉藏兵 · " + g_achievementToast.notice.rewardWeapon).c_str(), -1, &rewardFont,
        RectF(panel.X + 24, panel.Y + panel.Height - 36, panel.Width - 48, 26), &left, &accentBrush);
}

'''


def main() -> int:
    if not SRC.exists() or not LEGACY.exists():
        raise FileNotFoundError("Required source/header missing")

    header = LEGACY.read_text(encoding="utf-8")
    source = SRC.read_text(encoding="utf-8")
    if MARKER in source and MARKER in header:
        print("v0.9 achievement toasts already applied.")
        return 0
    if "V0_8_ARC_LEGACIES" not in source:
        raise RuntimeError("v0.8 arc legacies must run before v0.9")

    section_start = header.find("// ==================== 成就系统 ====================")
    if section_start < 0:
        raise RuntimeError("Unable to find legacy achievement section")
    header = header[:section_start] + ACHIEVEMENT_SECTION + "\n"
    LEGACY.write_text(header, encoding="utf-8")

    source = once(source, "#include <map>\n", "#include <map>\n#include <deque>\n#include <cmath>\n", "toast includes")
    source = once(source, "wstring PickOne(const vector<wstring>& items) {", SOURCE_SUPPORT + "wstring PickOne(const vector<wstring>& items) {", "toast runtime declarations")
    source = once(source, "void DrawPanel(Graphics& graphics, const RectF& rect, int alpha = 210) {", SOURCE_FUNCTIONS + "void DrawPanel(Graphics& graphics, const RectF& rect, int alpha = 210) {", "achievement runtime functions")

    # Every freshly constructed life receives the currently equipped jade weapon once.
    if "g_player = Player();" not in source:
        raise RuntimeError("Unable to find player reset anchors")
    source = source.replace(
        "g_player = Player();",
        "g_player = Player();\n    ResetJadeWeaponAppliedBonuses();\n    SyncJadeWeaponBonuses();",
    )

    # Old V1 saves need a one-time reward migration; V2 already contains weapon-applied player stats.
    if "g_achievementSystem.Load(file);" in source:
        source = source.replace(
            "g_achievementSystem.Load(file);",
            "g_achievementSystem.Load(file);\n    RestoreJadeWeaponStateAfterLoad();",
            1,
        )
    elif "if (!g_achievementSystem.Load(file))" in source:
        source = source.replace(
            "if (!g_achievementSystem.Load(file))",
            "if (!g_achievementSystem.Load(file))",
            1,
        )
        # Fallback is intentionally conservative; the normal source uses the direct call.
    else:
        raise RuntimeError("Unable to find achievement load call")

    source = once(source,
        "            OnPaint(memDC, rect);\n\n            BitBlt(hdc, 0, 0, rect.right, rect.bottom, memDC, 0, 0, SRCCOPY);",
        "            OnPaint(memDC, rect);\n            DrawAchievementToastOverlay(memDC, rect);\n\n            BitBlt(hdc, 0, 0, rect.right, rect.bottom, memDC, 0, 0, SRCCOPY);",
        "toast paint overlay")

    source = once(source,
        "            } else if (wParam == IDT_AGENT_BRIDGE) {\n                HandleAgentBridgeTick(hWnd);\n            }",
        "            } else if (wParam == IDT_AGENT_BRIDGE) {\n                HandleAgentBridgeTick(hWnd);\n            } else if (wParam == IDT_ACHIEVEMENT_TOAST_V09) {\n                TickAchievementSystem(hWnd);\n            }",
        "toast timer dispatch")

    source = once(source,
        "    AppendTraceLog(L\"APP_START\", L\"窗口已创建，等待输入道号。\");\n",
        "    AppendTraceLog(L\"APP_START\", L\"窗口已创建，等待输入道号。\");\n"
        "    SetTimer(g_hWnd, IDT_ACHIEVEMENT_TOAST_V09, 33, nullptr);\n",
        "toast timer start")

    source = once(source,
        "                else if (wParam == 'W' || wParam == 'w') {",
        "                else if (wParam == 'A' || wParam == 'a') {\n"
        "                    OpenInfoPage(L\"成就与轮回玉兵\", g_achievementSystem.GetAchievementsText(), STATE_GAME);\n"
        "                    InvalidateRect(hWnd, NULL, FALSE);\n"
        "                }\n"
        "                else if (wParam == 'Y' || wParam == 'y') {\n"
        "                    if (g_achievementSystem.EquipNextUnlockedWeapon()) {\n"
        "                        SyncJadeWeaponBonuses();\n"
        "                        SetInlineGameFeedback(L\"轮回玉换兵\", L\"当前共鸣玉兵：\" + g_achievementSystem.GetEquippedWeaponName() + L\"。玉中真形不受天地侵扰。\", L\"JADE_WEAPON_EQUIP\");\n"
        "                    } else {\n"
        "                        SetInlineGameFeedback(L\"轮回玉藏兵\", L\"尚未通过成就唤醒任何永久玉兵。\", L\"JADE_WEAPON_EQUIP\");\n"
        "                    }\n"
        "                    InvalidateRect(hWnd, NULL, FALSE);\n"
        "                }\n"
        "                else if (wParam == 'W' || wParam == 'w') {",
        "achievement keys")

    source = once(source,
        "                L\"[T] 至宝\"\n            }, cmdY);",
        "                L\"[T] 至宝\",\n                L\"[A] 成就玉兵\",\n                L\"[Y] 切换玉兵\"\n            }, cmdY);",
        "achievement command hints")

    source = once(source,
        '    WriteJsonField(ss, L"arcLegacies", BuildArcLegacyDigest());',
        '    WriteJsonField(ss, L"arcLegacies", BuildArcLegacyDigest());\n'
        '    WriteJsonField(ss, L"jadeWeapon", g_achievementSystem.GetEquippedWeaponName());\n'
        '    ss << L"\\\"achievementCount\\\":" << g_achievementSystem.GetUnlockedCount() << L",\\n";\n'
        '    ss << L"\\\"jadeWeaponCount\\\":" << g_achievementSystem.GetUnlockedWeaponCount() << L",\\n";',
        "achievement Agent JSON")

    source = once(source,
        '       << L" | 分线 " << BuildNarrativeArcDigest();',
        '       << L" | 分线 " << BuildNarrativeArcDigest()\n'
        '       << L" | 玉兵 " << g_achievementSystem.GetEquippedWeaponName();',
        "achievement trace digest")

    SRC.write_text(source, encoding="utf-8")
    print("Applied v0.9: three-tier animated achievement toasts and eternal reincarnation-jade weapons.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
