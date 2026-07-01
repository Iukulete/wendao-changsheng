// 问道长生 - AI增强版（集成AI叙事+动态世界）
#include <windows.h>
#include <windowsx.h>
#include <gdiplus.h>
#include <string>
#include <vector>
#include <random>
#include <sstream>
#include <fstream>
#include <algorithm>
#include <map>
#include <cwctype>
#include <limits>
#include <cstdlib>
#pragma comment(lib, "gdiplus.lib")

using namespace std;
using namespace Gdiplus;

// 引入创新模块
#include "../ai_engine/ai_core.h"
#include "../world_system/dynamic_world.h"
#include "../procedural_gen/procedural_gen.h"
#include "../legacy_system/legacy_system.h"

// ==================== 随机数生成 ====================
random_device g_rd;
mt19937 g_gen(g_rd());

int Random(int min, int max) {
    uniform_int_distribution<> dis(min, max);
    return dis(g_gen);
}

wstring GetCurrentWorldEraName();
int GetEraMeditationModifierPercent();
int GetEraBreakthroughModifier();
int GetEraAdventureRiskModifier();
int GetEraClosedDoorBonus();
int GetEraAiEventChance();
void GenerateHongmengOmen();
wstring BuildHongmengOmenBrief();
wstring BuildHongmengOmenText();

// ==================== 完整境界系统（21个） ====================
enum Realm {
    // 下界修真（10个）
    MORTAL = 0,         // 凡人
    QI_REFINING,        // 炼气期
    FOUNDATION,         // 筑基期
    GOLDEN_CORE,        // 金丹期
    NASCENT_SOUL,       // 元婴期
    SPIRIT_SEVERING,    // 化神期
    VOID_REFINING,      // 炼虚期
    UNITY,              // 合体期
    TRIBULATION,        // 渡劫期
    MAHAYANA,           // 大乘期

    // 冲仙门（1个）
    HALF_IMMORTAL,      // 半仙之体

    // 仙界征途（9个）
    TRUE_IMMORTAL,      // 真仙境
    HEAVEN_IMMORTAL,    // 天仙境
    MYSTIC_IMMORTAL,    // 玄仙境
    GOLDEN_IMMORTAL,    // 金仙境
    IMMORTAL_LORD,      // 仙君
    IMMORTAL_KING,      // 仙王
    IMMORTAL_SOVEREIGN, // 仙尊
    IMMORTAL_EMPEROR,   // 仙帝
    DAO_ANCESTOR,       // 道祖
    HEAVENLY_DAO        // 道祖-天道境
};

wstring GetRealmName(Realm realm) {
    static const vector<wstring> names = {
        L"凡人", L"炼气期", L"筑基期", L"金丹期",
        L"元婴期", L"化神期", L"炼虚期", L"合体期",
        L"渡劫期", L"大乘期", L"半仙之体",
        L"真仙境", L"天仙境", L"玄仙境", L"金仙境",
        L"仙君", L"仙王", L"仙尊", L"仙帝", L"道祖", L"道祖-天道境"
    };
    int index = max(0, min((int)realm, (int)HEAVENLY_DAO));
    return names[index];
}

wstring GetRealmPhase(Realm realm) {
    if (realm >= HEAVENLY_DAO) return L"【万道归一】";
    if (realm >= DAO_ANCESTOR) return L"【与道共生】";
    if (realm <= MAHAYANA) return L"【下界修真】";
    if (realm == HALF_IMMORTAL) return L"【冲仙门】";
    if (realm <= GOLDEN_IMMORTAL) return L"【仙界低阶】";
    if (realm <= IMMORTAL_SOVEREIGN) return L"【仙界高阶】";
    return L"【至高主宰】";
}

struct FamilyBackground {
    wstring origin;
    wstring familyName;
    wstring father;
    wstring mother;
    wstring guardian;
    wstring secret;
    int fame;
    int wealth;
    bool knowsParents;
    bool adopted;

    FamilyBackground() : fame(0), wealth(0), knowsParents(true), adopted(false) {}
};

struct SocialThread {
    wstring name;
    wstring role;
    wstring attitude;
    wstring hook;
    wstring visibleRealm;
    wstring hiddenHint;
    int relation;
    bool hidesPower;

    SocialThread() : relation(0), hidesPower(false) {}
};

struct FactionTie {
    wstring name;
    wstring kind;
    wstring role;
    wstring stance;
    wstring obligation;
    wstring hook;
    int favor;
    bool binding;

    FactionTie() : favor(0), binding(false) {}
};

struct LifeArtifact {
    wstring name;
    wstring category;
    wstring tier;
    wstring origin;
    int ageFound;
    bool resonant;

    LifeArtifact() : ageFound(0), resonant(false) {}
};

wstring PickOne(const vector<wstring>& items) {
    if (items.empty()) return L"";
    return items[Random(0, (int)items.size() - 1)];
}

FamilyBackground GenerateFamilyBackground() {
    FamilyBackground bg;
    vector<wstring> surnames = {L"沈", L"陆", L"顾", L"林", L"秦", L"叶", L"苏", L"韩", L"楚", L"白", L"萧", L"许"};
    vector<wstring> maleNames = {L"玄舟", L"怀远", L"青岳", L"承渊", L"明河", L"守拙", L"云峤", L"景行"};
    vector<wstring> femaleNames = {L"清霜", L"若兰", L"明棠", L"听雪", L"素心", L"月凝", L"静姝", L"云蘅"};

    int roll = Random(1, 100);
    if (roll <= 22) {
        bg.origin = L"寒门农户";
        bg.familyName = PickOne(surnames) + L"家";
        bg.fame = Random(-5, 8);
        bg.wealth = Random(0, 4);
    } else if (roll <= 40) {
        bg.origin = L"坊市小族";
        bg.familyName = PickOne(surnames) + L"氏小族";
        bg.fame = Random(5, 25);
        bg.wealth = Random(5, 14);
    } else if (roll <= 55) {
        bg.origin = L"没落修真世家";
        bg.familyName = PickOne(surnames) + L"氏旧族";
        bg.fame = Random(15, 45);
        bg.wealth = Random(6, 18);
        bg.secret = L"族中旧契牵连一处失落洞府";
    } else if (roll <= 70) {
        bg.origin = L"宗门附庸";
        bg.familyName = PickOne(surnames) + L"家";
        bg.fame = Random(20, 55);
        bg.wealth = Random(8, 22);
        bg.secret = L"家中长辈与附近宗门有旧";
    } else if (roll <= 84) {
        bg.origin = L"孤儿";
        bg.familyName = L"无名";
        bg.knowsParents = false;
        bg.adopted = true;
        bg.guardian = PickOne({L"药铺掌柜", L"山村猎户", L"破庙老道", L"外门执事", L"行脚医修"});
        bg.fame = Random(-10, 8);
        bg.wealth = Random(0, 8);
        bg.secret = PickOne({L"襁褓中留有半枚玉佩", L"生父母身份无人敢提", L"养父母只说你来自风雪夜"});
        return bg;
    } else if (roll <= 94) {
        bg.origin = L"隐秘血脉";
        bg.familyName = PickOne(surnames) + L"氏";
        bg.knowsParents = false;
        bg.adopted = Random(0, 1) == 1;
        bg.guardian = bg.adopted ? PickOne({L"沉默剑修", L"药谷散人", L"旧仆", L"无名女冠"}) : L"族中旁支";
        bg.fame = Random(35, 80);
        bg.wealth = Random(8, 24);
        bg.secret = PickOne({L"父母疑似高阶修士", L"血脉被人刻意遮掩", L"有人暗中替你挡过灾"});
    } else {
        bg.origin = L"大能遗脉";
        bg.familyName = PickOne(surnames) + L"氏";
        bg.knowsParents = Random(0, 1) == 1;
        bg.guardian = bg.knowsParents ? L"" : PickOne({L"闭关老祖", L"护道旧仆", L"宗门暗线"});
        bg.fame = Random(60, 100);
        bg.wealth = Random(18, 36);
        bg.secret = bg.knowsParents ? L"父母名声极盛，也牵来仇家注视" : L"父母名讳被封在旧玉简中";
    }

    bg.father = PickOne(surnames) + PickOne(maleNames);
    bg.mother = PickOne(surnames) + PickOne(femaleNames);
    return bg;
}

wstring GetFamilySummary(const FamilyBackground& bg) {
    wstringstream ss;
    ss << bg.origin;
    if (!bg.knowsParents) ss << L" · 身世未明";
    else if (bg.adopted) ss << L" · 收养";
    return ss.str();
}

wstring GetFamilyDetailText(const FamilyBackground& bg) {
    wstringstream ss;
    ss << L"【此世出身】\n\n";
    ss << L"出身: " << bg.origin << L"\n";
    ss << L"家族: " << (bg.familyName.empty() ? L"无" : bg.familyName) << L"\n";
    ss << L"名望: " << bg.fame << L"  家资: " << bg.wealth << L"\n\n";
    ss << L"【亲缘】\n";
    if (bg.knowsParents) {
        ss << L"父亲: " << bg.father << L"\n";
        ss << L"母亲: " << bg.mother << L"\n";
    } else {
        ss << L"父母: 身份被隐去，尚不可知\n";
    }
    if (bg.adopted || !bg.guardian.empty()) {
        ss << L"养育者: " << bg.guardian << L"\n";
    }
    if (!bg.secret.empty()) {
        ss << L"\n【隐情】\n" << bg.secret << L"\n";
    }
    ss << L"\n此世家世会影响开局资源、名望，以及本地 AI 事件中的亲缘、仇家、宗门旧识。";
    return ss.str();
}

// ==================== 玩家类（增强五行系统） ====================
class Player {
public:
    wstring name;
    FamilyBackground family;
    Realm realm;
    int level, exp, hp, maxHp, mp, maxMp, karma;
    int rootFire, rootWater, rootWood, rootMetal, rootEarth;
    int age, lifespan, spiritStones, pills;
    int attackPower, defense;
    int totalEvents, battlesWon, npcsMet;

    // 五行均衡判定（飞升关键）
    bool hasBalancedRoots;

    Player() : realm(MORTAL), level(1), exp(0), karma(0),
               age(16), spiritStones(10), pills(0),
               attackPower(0), defense(0), totalEvents(0), battlesWon(0), npcsMet(0),
               hasBalancedRoots(false) {
        family = GenerateFamilyBackground();
        spiritStones += family.wealth / 3;
        karma += family.fame / 20;

        rootFire = Random(1, 10);
        rootWater = Random(1, 10);
        rootWood = Random(1, 10);
        rootMetal = Random(1, 10);
        rootEarth = Random(1, 10);

        int total = GetTotalRoot();
        maxHp = 100 + total * 5;
        maxMp = 50 + total * 3;
        hp = maxHp;
        mp = maxMp;
        lifespan = 60 + total;
        attackPower = 10 + total;
        defense = 5 + total / 2;

        CheckRootBalance();
    }

    int GetTotalRoot() const {
        return rootFire + rootWater + rootWood + rootMetal + rootEarth;
    }

    // 检查五行是否均衡（飞升条件）
    void CheckRootBalance() {
        int minRoot = min({rootFire, rootWater, rootWood, rootMetal, rootEarth});
        int maxRoot = max({rootFire, rootWater, rootWood, rootMetal, rootEarth});
        hasBalancedRoots = (maxRoot - minRoot <= 3) && (minRoot >= 5);
    }

    wstring GetRootQuality() const {
        int total = GetTotalRoot();
        if (hasBalancedRoots) return L"五行灵根★";
        if (total >= 45) return L"天灵根";
        if (total >= 40) return L"地灵根";
        if (total >= 35) return L"真灵根";
        if (total >= 30) return L"伪灵根";
        return L"杂灵根（废灵根）";
    }

    wstring GetRootDetails() const {
        wstringstream ss;
        ss << L"火:" << rootFire << L" 水:" << rootWater << L" 木:" << rootWood
           << L" 金:" << rootMetal << L" 土:" << rootEarth;
        return ss.str();
    }

    int GetExpNeeded() const {
        int base = 100 * level;
        int realmMultiplier = realm + 1;
        if (realm >= HALF_IMMORTAL) {
            realmMultiplier *= 3;
        }
        return base * realmMultiplier;
    }

    bool CanBreakthrough() const {
        if (realm >= HEAVENLY_DAO) return false;
        if (level < 9 || exp < GetExpNeeded()) return false;
        // 大乘期→半仙之体，必须五行均衡
        if (realm == MAHAYANA && !hasBalancedRoots) {
            return false;
        }
        return true;
    }

    void ImproveRoot(int& root, int amount) {
        root = min(10, root + amount);
        CheckRootBalance();
    }

    int Meditate(int multiplier = 1, int percentModifier = 100) {
        int gain = Random(10, 20) + GetTotalRoot() / 5;
        // 杂灵根修炼速度惩罚
        if (GetTotalRoot() < 30 && !hasBalancedRoots) {
            gain = gain * 7 / 10;
        }
        gain *= max(1, multiplier);
        gain = gain * max(10, percentModifier) / 100;
        exp += gain;
        age += 1;

        if (exp >= GetExpNeeded() && level < 9) {
            LevelUp();
        }
        return gain;
    }

    void LevelUp() {
        level++;
        exp = 0;

        int hpBonus = 20;
        int mpBonus = 10;

        // 仙界属性提升更大
        if (realm >= TRUE_IMMORTAL) {
            hpBonus *= 3;
            mpBonus *= 3;
        }

        maxHp += hpBonus;
        maxMp += mpBonus;
        attackPower += 5;
        defense += 3;
        hp = maxHp;
        mp = maxMp;
    }

    bool TryBreakthrough(int rateModifier = 0) {
        if (!CanBreakthrough()) return false;

        int successRate = 50 + GetTotalRoot() + karma / 2 + rateModifier;

        // 五行均衡加成
        if (hasBalancedRoots) {
            successRate += 15;
        }

        // 仙界突破更难
        if (realm >= TRUE_IMMORTAL) {
            successRate -= 20;
        }
        if (realm >= DAO_ANCESTOR) {
            successRate -= 35;
        }

        if (successRate > 95) successRate = 95;
        if (successRate < 10) successRate = 10;

        if (Random(1, 100) <= successRate) {
            realm = static_cast<Realm>(realm + 1);
            level = 1;
            exp = 0;

            int hpBonus = 100;
            int mpBonus = 50;
            int lifespanBonus = 100;

            // 进入仙界，巨大提升
            if (realm == TRUE_IMMORTAL) {
                hpBonus = 500;
                mpBonus = 300;
                lifespanBonus = 1000;
            } else if (realm == DAO_ANCESTOR) {
                hpBonus = 5000;
                mpBonus = 3000;
                lifespanBonus = 100000;
            } else if (realm == HEAVENLY_DAO) {
                hpBonus = 20000;
                mpBonus = 12000;
                lifespanBonus = 1000000;
            }

            maxHp += hpBonus;
            maxMp += mpBonus;
            attackPower += 20;
            defense += 10;
            hp = maxHp;
            mp = maxMp;
            lifespan += lifespanBonus;
            return true;
        } else {
            hp = maxHp / 2;
            exp = exp / 2;
            return false;
        }
    }

    bool IsDead() const {
        if (hp <= 0) return true;
        if (realm >= DAO_ANCESTOR) return false;
        return age >= lifespan;
    }

    wstring GetStatusText() const {
        wstringstream ss;
        ss << L"【" << name << L"】 " << GetRootQuality() << L"\n\n";
        ss << L"境界: " << GetRealmName(realm) << L" " << level << L"层\n";
        ss << L"阶段: " << GetRealmPhase(realm) << L"\n";
        ss << L"修为: " << exp << L" / " << GetExpNeeded() << L"\n";
        ss << L"气血: " << hp << L" / " << maxHp << L"\n";
        ss << L"灵力: " << mp << L" / " << maxMp << L"\n";
        ss << L"攻击: " << attackPower << L" | 防御: " << defense << L"\n";
        ss << L"\n五行: " << GetRootDetails() << L"\n";

        if (!hasBalancedRoots && realm >= SPIRIT_SEVERING) {
            ss << L"⚠ 五行不均，无法飞升！\n";
        }

        ss << L"因果: " << karma << L"\n";
        if (realm >= DAO_ANCESTOR) {
            ss << L"年龄: " << age << L" / 与道共生\n";
        } else {
            ss << L"年龄: " << age << L" / " << lifespan << L"\n";
        }
        ss << L"灵石: " << spiritStones << L" | 丹药: " << pills << L"\n";
        ss << L"历练: " << totalEvents << L" | 胜场: " << battlesWon << L" | 结识: " << npcsMet;
        return ss.str();
    }
};

// ==================== 事件系统 ====================
struct Choice {
    wstring description;
    vector<wstring> outcomes;
    int karmaChange;
};

struct Event {
    wstring title;
    wstring description;
    vector<Choice> choices;
};

enum EventTheme {
    THEME_GENERAL = 0,
    THEME_CULTIVATION = 1,
    THEME_TECH = 2,
    THEME_WASTELAND = 3,
    THEME_FINAL_AGE = 4,
    THEME_IMPERIAL = 5
};

struct TaggedEvent {
    Event event;
    EventTheme theme;
};

// ==================== 事件管理器 ====================
class EventManager {
private:
    vector<TaggedEvent> events;

public:
    EventManager() {
        InitEvents();
    }

    void AddEvent(const Event& event, EventTheme theme = THEME_GENERAL) {
        TaggedEvent tagged;
        tagged.event = event;
        tagged.theme = theme;
        events.push_back(tagged);
    }

    void InitEvents() {
        // ========== 战斗事件系列（20个） ==========
        // 妖兽系列
        AddEvent({
            L"【危机】野狼妖袭击", L"一只野狼妖盯上了你！",
            {{L"战斗", {L"击败妖兽\n修为+40", L"被击败\n气血-40"}, 0},
             {L"逃跑", {L"成功逃脱", L"被追上\n气血-30"}, -5}}
        }, THEME_CULTIVATION);
        AddEvent({
            L"【危机】猛虎妖袭击", L"一只猛虎妖出现！",
            {{L"战斗", {L"击败猛虎\n修为+50", L"被击败\n气血-50"}, 0}}
        }, THEME_CULTIVATION);
        AddEvent({
            L"【危机】毒蛇妖袭击", L"毒蛇妖缠上了你！",
            {{L"战斗", {L"击败毒蛇\n修为+45", L"中毒\n气血-45"}, 0}}
        }, THEME_CULTIVATION);
        AddEvent({
            L"【危机】巨蟒妖袭击", L"巨蟒妖横空出世！",
            {{L"战斗", {L"击败巨蟒\n修为+60", L"被缠住\n气血-55"}, 0}}
        }, THEME_CULTIVATION);
        AddEvent({
            L"【危机】狐妖袭击", L"狐妖施展幻术！",
            {{L"战斗", {L"破除幻术\n修为+55", L"中幻术\n气血-40"}, 0}}
        }, THEME_CULTIVATION);

        // 修士对决系列
        AddEvent({
            L"【对决】邪修", L"遭遇邪修挑衅",
            {{L"应战", {L"击败邪修\n修为+70", L"被击败\n气血-60"}, 0},
             {L"逃跑", {L"逃脱", L"被追杀\n气血-40"}, -10}}
        }, THEME_CULTIVATION);
        AddEvent({
            L"【对决】散修", L"与散修起冲突",
            {{L"应战", {L"战胜\n修为+50", L"战败\n气血-45"}, 0}}
        }, THEME_CULTIVATION);
        AddEvent({
            L"【对决】魔修", L"魔修欲夺舍！",
            {{L"拼死一战", {L"反杀魔修\n修为+150", L"险些被夺舍\n气血-70"}, 10}}
        }, THEME_CULTIVATION);

        // ========== 奇遇事件系列（25个） ==========
        // 事件1：负伤修士
        AddEvent({
            L"【奇遇】负伤修士",
            L"你在山道上遇见一位身受重伤的修士，他请求你的帮助。",
            {
                {L"救助他", {
                    L"他感激涕零，将一枚记着残篇的古修玉简交给你\n修为+50",
                    L"他恢复后反咬一口\n气血-30",
                    L"他其实是魔修，种下心魔\n修为-30"
                }, 10},
                {L"无视离开", {
                    L"平安无事",
                    L"他临死前诅咒你\n寿命-5年"
                }, -5},
                {L"补刀夺宝", {
                    L"获得他的储物袋\n灵石+20",
                    L"被他临死反扑重伤\n气血-30"
                }, -20}
            }
        }, THEME_GENERAL);

        // 事件2：神秘洞府
        AddEvent({
            L"【奇遇】神秘洞府",
            L"你发现一个隐蔽的洞府，散发着灵气波动。",
            {
                {L"小心探索", {
                    L"发现灵石、月华草与一瓶翠灵丹\n灵石+15，丹药+3",
                    L"触发禁制受伤\n气血-20"
                }, 0},
                {L"强行破阵", {
                    L"破开阵眼，夺得青冥阵盘与大量资源\n灵石+30，修为+80",
                    L"禁制反噬，重伤\n气血-50"
                }, 5},
                {L"记下位置离开", {
                    L"谨慎行事，平安无事",
                    L"回来时被他人捷足先登"
                }, 0}
            }
        }, THEME_CULTIVATION);

        // 事件3：妖兽袭击
        AddEvent({
            L"【危机】妖兽袭击",
            L"一只炼气期妖兽盯上了你！",
            {
                {L"正面战斗", {
                    L"击败妖兽，剖出一枚妖丹\n修为+40，灵石+10",
                    L"被妖兽击败\n气血-40"
                }, 0},
                {L"尝试逃跑", {
                    L"成功逃脱",
                    L"被追上，重伤\n气血-35"
                }, -5},
                {L"施展法术偷袭", {
                    L"一击必杀！\n修为+50",
                    L"偷袭失败，妖兽狂暴\n气血-50"
                }, 0}
            }
        }, THEME_CULTIVATION);

        // 事件4：宗门招收
        AddEvent({
            L"【机遇】宗门招收",
            L"一个修仙宗门正在招收弟子，你是否参加考核？",
            {
                {L"参加考核", {
                    L"通过考核，获赠一枚灵石袋与宗门玉简\n灵石+20，修为+30",
                    L"考核失败，灰溜溜离开"
                }, 5},
                {L"拒绝，散修自由", {
                    L"保持自由之身",
                    L"错过良机"
                }, 0}
            }
        }, THEME_CULTIVATION);

        // 事件5：天材地宝
        AddEvent({
            L"【机遇】天材地宝",
            L"你发现了一株千年灵芝，但旁边有妖兽守护。",
            {
                {L"智取", {
                    L"成功引开妖兽，顺手采得月华草与灵芝\n修为+100",
                    L"妖兽察觉，追击你\n气血-30"
                }, 5},
                {L"强取", {
                    L"击败妖兽，获得灵芝与妖丹\n修为+120",
                    L"不敌妖兽，逃跑\n气血-40"
                }, 0},
                {L"放弃", {
                    L"明智的选择，保全性命",
                    L"机缘尽失"
                }, 0}
            }
        }, THEME_CULTIVATION);

        // 添加更多事件...
        AddEvent({
            L"【大机遇】前辈传承",
            L"你误入一处上古洞府，发现前辈留下的传承。",
            {
                {L"接受传承", {
                    L"获得镇魂铜镜与强大功法！\n修为+200",
                    L"传承不适合，走火入魔\n气血-60"
                }, 10},
                {L"只取宝物", {
                    L"卷走养灵葫芦与大量资源\n灵石+50，丹药+10",
                    L"触发机关\n气血-30"
                }, 0}
            }
        }, THEME_CULTIVATION);

        // 事件7-15：更多事件（包含五行相关）
        AddEvent({
            L"【大机遇】五行秘境",
            L"你误入一处五行秘境，可以选择一种五行之力吸收。",
            {
                {L"吸收火焰之力", {L"火灵根+2！\n修为+50", L"被火焰灼伤\n气血-20"}, 5},
                {L"吸收寒冰之力", {L"水灵根+2！\n修为+50", L"被寒气侵袭\n气血-20"}, 5},
                {L"吸收草木之力", {L"木灵根+2！\n修为+50", L"被树藤困住\n气血-20"}, 5},
                {L"吸收金铁之力", {L"金灵根+2！\n修为+50", L"金气反噬\n气血-20"}, 5},
                {L"吸收大地之力", {L"土灵根+2！\n修为+50", L"被地脉震伤\n气血-20"}, 5}
            }
        }, THEME_CULTIVATION);

        AddEvent({
            L"【传承】五行老祖",
            L"你遇到一位五行老祖的传承，他可以帮你补全灵根。",
            {
                {L"接受传承", {L"五行均衡！所有灵根提升至7以上\n但寿命-30年", L"传承失败\n气血-40"}, 20},
                {L"只求指点", {L"获得修炼心得\n修为+100", L"老祖不满\n修为-50"}, 0},
                {L"放弃机缘", {L"明哲保身", L"错失良机"}, 0}
            }
        }, THEME_CULTIVATION);

        AddEvent({
            L"【危机】魔修伏击",
            L"一名魔修盯上了你，想要夺舍！",
            {
                {L"拼死一战", {L"反杀魔修\n修为+150", L"险些被夺舍\n气血-50"}, 10},
                {L"舍财保命", {L"魔修拿走灵石\n灵石-30", L"魔修不满\n气血-40"}, -5}
            }
        }, THEME_CULTIVATION);

        AddEvent({
            L"【机遇】秘境开启",
            L"附近秘境开启，无数修士涌入，你是否前往？",
            {
                {L"立即前往", {L"抢得先机\n修为+80，灵石+25", L"遭遇强敌\n气血-45"}, 0},
                {L"等人少了再去", {L"避开争斗\n灵石+30", L"去晚了，秘境关闭"}, 5},
                {L"不去", {L"谨慎保命", L"错失良机"}, 0}
            }
        }, THEME_CULTIVATION);

        AddEvent({
            L"【见闻】渡劫修士",
            L"你远远观摩到一位修士渡劫，有所感悟。",
            {
                {L"仔细观摩", {L"领悟天道\n修为+120", L"被劫雷余波击中\n气血-40"}, 5},
                {L"立即远离", {L"明哲保身", L"错失感悟"}, 0}
            }
        }, THEME_CULTIVATION);

        AddEvent({
            L"【大机遇】仙缘降临",
            L"天降仙缘，一道金光笼罩着你！",
            {
                {L"接受仙缘", {L"境界突破！\n直接提升一个小境界，寿命+50年", L"福缘不够\n仙缘消散"}, 20},
                {L"推辞", {L"获得部分好处\n修为+100", L"惹怒天道\n气血-50"}, 0}
            }
        }, THEME_CULTIVATION);

        AddEvent({
            L"【奇遇】灵根洗髓丹",
            L"坊市中有人出售灵根洗髓丹，可提升灵根资质。",
            {
                {L"购买服用", {L"连同翠灵丹一并服下，随机一种灵根+1\n灵石-20", L"是假药\n灵石-20"}, 0},
                {L"讨价还价", {L"半价买到，还捎上一株月华草\n灵根+1，灵石-10", L"卖家拒绝"}, 0}
            }
        }, THEME_GENERAL);

        AddEvent({
            L"【危机】天劫降临",
            L"你在修炼时引发天劫，必须应对！",
            {
                {L"正面硬抗", {L"抗过天劫\n修为+150", L"被天雷重伤\n气血-60"}, 10},
                {L"借助法宝", {L"借镇狱小塔护体，成功渡劫\n修为+100", L"法宝损毁\n气血-30"}, 5},
                {L"逃避天劫", {L"暂时逃过", L"天道记恨\n因果-30"}, -20}
            }
        }, THEME_CULTIVATION);

        AddEvent({
            L"【奇遇】仙药园",
            L"你偶然发现一个无人看守的仙药园。",
            {
                {L"采摘仙药", {L"采下月华草与多种仙药，获得大量丹药\n丹药+15", L"触发守护阵法\n气血-30"}, 0},
                {L"只取一株", {L"只摘走一株月华草，小心谨慎\n丹药+5", L"还是触发了阵法\n气血-15"}, 5}
            }
        }, THEME_CULTIVATION);

        AddEvent({
            L"【奇遇】神秘商人",
            L"你遇到一位神秘商人，他出售稀有物品。",
            {
                {L"购买丹药", {L"买下一瓶翠灵丹与筑基丹\n丹药+5，灵石-15", L"是假货\n灵石-15"}, 0},
                {L"购买功法", {L"连同古修玉简一并买下，获强大功法\n修为+80，灵石-25", L"是残缺功法\n灵石-25"}, 0},
                {L"购买法宝", {L"买下潮心灵珠与瞬影符\n修为+40，灵石-25", L"商人掉包成残次品\n灵石-25"}, 0},
                {L"不买", {L"保留灵石", L"错失机会"}, 0}
            }
        }, THEME_GENERAL);

        AddEvent({
            L"【奇遇】灵机工坊试炼",
            L"一座半公开的灵机工坊正在测试新型遁行装置，招募敢于试机的修士。",
            {
                {L"报名试机", {L"你借灵机遁行悟出新身法\n修为+110，灵石+15", L"装置失控爆鸣\n气血-35"}, 5},
                {L"偷看图纸", {L"你记下几道关键纹路，闭关时大有裨益\n修为+80", L"被工坊护卫发现\n气血-20"}, 0},
                {L"出售意见", {L"你指出阵纹缺口，工坊以灵石酬谢\n灵石+25", L"对方不以为然，把你赶了出去"}, 3}
            }
        }, THEME_TECH);

        AddEvent({
            L"【机缘】玄炉量产法器",
            L"玄炉工造盟公开售卖第一批量产法器，旧宗门弟子讥笑它粗糙，散修却排成长队。",
            {
                {L"购入试用", {L"你用量产法器补足短板，明白技术也能入道\n修为+85，灵石-12", L"法器经脉反馈失衡，震得你气血翻涌\n气血-25，灵石-12"}, 2},
                {L"拆解研究", {L"你拆开阵械外壳，记下几处可改良纹路\n修为+70，灵石+8", L"工坊执事认定你盗取图纸\n因果-8"}, 0},
                {L"护住旧法", {L"你替旧宗门弟子指出量产法器的隐患，赢得一份人情\n因果+8，修为+45", L"双方都觉得你多管闲事"}, 4}
            }
        }, THEME_TECH);

        AddEvent({
            L"【机缘】道网远讯",
            L"灵网节点忽然向你推送一段跨洲讯息，里面藏着某座高阶宗门遗留的远程试炼入口。",
            {
                {L"接入试炼", {L"你远程闯过一层试炼，获赠算法阵图\n修为+120", L"神识过载，头痛欲裂\n气血-30"}, 6},
                {L"转卖线索", {L"你把入口坐标卖给别人，换得不菲灵石\n灵石+30", L"对方反悔，反向锁定了你的气息\n气血-20"}, 0},
                {L"谨慎断开", {L"你没有贸然接入，但仍记下一丝道网逻辑\n修为+50", L"机缘短暂熄灭，只剩空白提示"}, 2}
            }
        }, THEME_TECH);

        AddEvent({
            L"【因果】道网旧名检索",
            L"星穹道网忽然把一个与你相近的旧名推到榜单边缘，远方修士开始隔空打探你的来历。",
            {
                {L"公开回应", {L"你借榜单回应质疑，反把旧名变成今生名望\n修为+80，因果+10", L"回应太急，旧名争议反而扩散\n因果-10"}, 6},
                {L"暗查源头", {L"你顺着远讯坐标查到一段前世残频\n修为+90，灵宝共鸣+3", L"残频里夹着陷阱，神识受创\n气血-28"}, 5},
                {L"断开灵网", {L"你保住隐秘，避开一场远程围观\n寿命+3", L"错过可能指向前世的线索"}, 0}
            }
        }, THEME_TECH);

        AddEvent({
            L"【危机】荒野古机失控",
            L"荒野中一具残存的古代灵机忽然复苏，把你误判成入侵者，废土沙尘里满是焦黑火线。",
            {
                {L"拆解核心", {L"你险中求胜，拆下可用部件与灵核\n修为+130，灵石+20", L"核心自爆，整片荒坡都被炸塌\n气血-45"}, 8},
                {L"躲入废墟", {L"你借残墙避开锋芒，还顺手摸到旧时代物资\n灵石+18", L"废墟同时坍塌，把你埋在尘里\n气血-30"}, 0},
                {L"唤醒残阵", {L"你强行接管附近残阵，反将古机困死\n修为+100", L"阵列年久失修，先一步反噬了你\n气血-35"}, 5}
            }
        }, THEME_WASTELAND);

        AddEvent({
            L"【传承】黑雨旧库",
            L"黑雨边城外露出一座旧文明库门，残宗、拾荒者和邪祟都盯着里面的传承残件。",
            {
                {L"抢先入库", {L"你夺得旧库译码残片，读懂一段断代传承\n修为+120，灵石+15", L"黑雨侵蚀经脉\n气血-38"}, 4},
                {L"护送残宗", {L"你护着残宗幼修撤离，换来一份返道火种\n因果+14，修为+70", L"邪祟追上队伍，你被迫断后\n气血-35"}, 10},
                {L"封死库门", {L"你暂时封住邪祟源头，废土少一场灾\n因果+10", L"库内传承也随之沉寂"}, 6}
            }
        }, THEME_WASTELAND);

        AddEvent({
            L"【因果】末法争井",
            L"一口尚未完全枯竭的灵井引来数方修士对峙，在末法时代，每一缕灵气都像会咬人的肉。",
            {
                {L"强夺灵井", {L"你趁乱夺得灵井余气，破境感悟大涨\n修为+140", L"众人联手围杀，几乎把你逼上绝路\n气血-50"}, -5},
                {L"结盟分润", {L"你与几人暂结同盟，分得一份灵气与人脉\n修为+90，因果+10", L"盟友翻脸，分润变成陷阱\n气血-30"}, 6},
                {L"旁观待变", {L"你等到残局收尾，再捡走被忽略的资源\n灵石+22，修为+50", L"拖得太久，什么也没剩下"}, 0}
            }
        }, THEME_FINAL_AGE);

        AddEvent({
            L"【危机】替道破境契",
            L"末法裂变纪里，有人拿出一份替道破境契，承诺让低阶修士用寿元换一次强行破关。",
            {
                {L"签下契书", {L"你借阵械强行推开一线瓶颈\n修为+150，寿命-12", L"契书反噬，寿元与气血一同被抽走\n气血-40，寿命-8"}, -8},
                {L"拆穿陷阱", {L"你看出契书藏着因果借贷，救下几个急疯的修士\n因果+14，修为+55", L"幕后之人记住了你\n因果-5"}, 10},
                {L"买走残页", {L"你只买走残页研究，未把命押上去\n修为+65，灵石-10", L"残页内容残缺，花了冤枉灵石\n灵石-10"}, 0}
            }
        }, THEME_FINAL_AGE);

        AddEvent({
            L"【因果】气运金榜点名",
            L"仙朝气运金榜忽然浮现你的道号，册封吏、世家暗线和宗门长老同时投来目光。",
            {
                {L"上台受验", {L"你稳住心神受验，名册反而替你挡下一部分流言\n修为+90，因果+8", L"金榜映出家世疑点，引来更多试探\n因果-10"}, 6},
                {L"借榜扬名", {L"你顺势结交几名榜上修士，名声迅速扩散\n修为+70，灵石+18", L"名声来得太急，同辈嫉妒暗生\n气血-18"}, 8},
                {L"避开册封", {L"你没有让仙朝轻易定下命数，道心反而更稳\n寿命+4，修为+45", L"错过一份公开资源"}, 2}
            }
        }, THEME_IMPERIAL);

        AddEvent({
            L"【传承】隐龙旧契",
            L"隐龙旧族递来一份血脉旧契，声称你的家世或前世旧名与仙朝册封有关。",
            {
                {L"验明旧契", {L"你从旧契里查到一段家世暗线\n修为+85，因果+10", L"旧契牵出仇家，暗线反成追索你的凭据\n气血-30"}, 5},
                {L"暂借名义", {L"你借旧族名义进入一处秘境，拿到资源\n灵石+25，修为+65", L"旧族要你偿还人情\n因果-6"}, 0},
                {L"拒绝入局", {L"你不让门第替自己定道途，心境更清明\n修为+55", L"隐龙旧族转而暗中观察"}, 3}
            }
        }, THEME_IMPERIAL);
    }

    Event* GetRandomEvent(int playerKarma, bool needRootBalance) {
        if (events.empty()) return nullptr;

        // 五行不均衡且境界高，更容易遇到五行相关事件
        if (needRootBalance && Random(1, 100) <= 40) {
            int rootEventIndex = Random(6, 8);  // 五行秘境、五行老祖
            if (rootEventIndex < events.size()) {
                return &events[rootEventIndex].event;
            }
        }

        vector<int> preferred;
        vector<int> fallback;
        EventTheme preferredTheme = THEME_GENERAL;

        wstring eraName = GetCurrentWorldEraName();
        if (eraName == L"灵机蒸汽纪" || eraName == L"星穹道网纪") {
            preferredTheme = THEME_TECH;
        } else if (eraName == L"废土返道纪") {
            preferredTheme = THEME_WASTELAND;
        } else if (eraName == L"末法裂变纪") {
            preferredTheme = THEME_FINAL_AGE;
        } else if (eraName == L"仙朝鼎盛纪") {
            preferredTheme = THEME_IMPERIAL;
        } else {
            preferredTheme = THEME_CULTIVATION;
        }

        for (int i = 0; i < (int)events.size(); i++) {
            if (events[i].theme == preferredTheme) preferred.push_back(i);
            if (events[i].theme == THEME_GENERAL || events[i].theme == THEME_CULTIVATION) fallback.push_back(i);
        }

        if (!preferred.empty() && Random(1, 100) <= 65) {
            int index = preferred[Random(0, (int)preferred.size() - 1)];
            return &events[index].event;
        }
        if (!fallback.empty()) {
            int index = fallback[Random(0, (int)fallback.size() - 1)];
            return &events[index].event;
        }

        int index = Random(0, (int)events.size() - 1);
        return &events[index].event;
    }
};

// ==================== 全局变量 ====================
Player g_player;
EventManager g_eventMgr;

// AI和世界系统
AIGenerator g_aiGen;
ContextManager g_contextMgr;
DynamicWorld g_dynamicWorld;
ProceduralWorldGenerator g_procGen;
ProceduralWorldGenerator::WorldData g_worldData;
LegacySystem g_legacySystem;
AchievementSystem g_achievementSystem;
vector<wstring> g_memoryLog;
vector<wstring> g_socialRumors;
vector<SocialThread> g_socialThreads;
vector<wstring> g_discoveredItems;
vector<LifeArtifact> g_lifeArtifacts;
int g_generation = 1;
wstring g_lastAiBackend = L"未触发";
wstring g_lastAiStatus = L"本局尚未触发动态事件。";
wstring g_worldEraName = L"灵气初盛纪";
wstring g_worldEraDescription = L"诸宗并立，洞府初开，天下仍以修仙宗门为正统。";
wstring g_worldEraRule = L"灵气丰沛，修士主宰秩序，凡俗仍仰望山门。";
wstring g_reincarnationEcho = L"前世的残响尚浅，还不足以彻底改变这一世。";
wstring g_eraTransitionNote = L"这是本局第一段完整时代，后续转世可能迎来完全不同的天地秩序。";
wstring g_eraShiftCause = L"初世尚无前因，天地大势仍在等待你的选择留下第一道痕迹。";
wstring g_hongmengOmenTreasureName = L"鸿蒙道印";
wstring g_hongmengOmenDao = L"万道源流";
wstring g_hongmengOmenManifestation = L"识海浮现无字印玺，照出自身大道的真名与缺口。";
wstring g_hongmengOmenInfluence = L"本世鸿蒙天象尚浅，只提醒众生九大鸿蒙至宝永恒在世，不可被普通道祖毁灭。";
wstring g_lifePremise = L"此世尚未显出明确主线，一切仍在暗处酝酿。";
vector<wstring> g_lifeStoryHooks;
vector<wstring> g_eraRemnants;
vector<wstring> g_eraChronicle;
FactionTie g_factionTie;

HWND g_hWnd;
Image* g_bgImage = nullptr;
Image* g_itemAtlasImage = nullptr;

enum GameState {
    STATE_MENU = 0,
    STATE_GAME = 1,
    STATE_EVENT = 2,
    STATE_GAMEOVER = 3,
    STATE_INFO = 4,
    STATE_AI_WAIT = 5
};

GameState g_gameState = STATE_MENU;
Event* g_currentEvent = nullptr;
wstring g_messageText;
PlayerContext g_pendingAiContext;
PROCESS_INFORMATION g_aiProcessInfo = {};
bool g_aiProcessRunning = false;
DWORD g_aiStartTick = 0;
wstring g_infoTitle;
wstring g_infoText;
GameState g_infoReturnState = STATE_GAME;
RECT g_backButtonRect = {0, 0, 0, 0};
RECT g_infoScrollTrackRect = {0, 0, 0, 0};
bool g_backButtonVisible = false;
bool g_infoScrollDragging = false;
int g_infoScroll = 0;
int g_infoScrollMax = 0;

#define ID_NAME_INPUT 1001
#define ID_BTN_START 1002
#define IDT_AI_POLL 2001

HWND g_nameInput;
HWND g_btnStart;

void ShowNotice(const wstring& title, const wstring& text);
vector<vector<wstring>> LoadItemDbRows();
void DiscoverItemsFromText(const wstring& text);
PlayerContext BuildPlayerContext();
wstring BuildCompanionJadeVisibleText();
wstring BuildCompanionJadeHiddenContext();
void ApplyCompanionJadeToBirth();
int CountHongmengInsightKinds();

void DrawGlowText(Graphics& graphics, const wstring& text, FontFamily& fontFamily,
                  REAL fontSize, const RectF& rect, StringFormat& format) {
    GraphicsPath textPath;
    textPath.AddString(text.c_str(), -1, &fontFamily, FontStyleRegular, fontSize, rect, &format);

    SolidBrush glowBrush(Color(28, 88, 228, 220));
    for (int dx = -3; dx <= 3; ++dx) {
        for (int dy = -3; dy <= 3; ++dy) {
            if (dx == 0 && dy == 0) continue;
            GraphicsPath* shadowPath = textPath.Clone();
            Matrix matrix;
            matrix.Translate((REAL)dx, (REAL)dy);
            shadowPath->Transform(&matrix);
            graphics.FillPath(&glowBrush, shadowPath);
            delete shadowPath;
        }
    }

    Pen outlinePen(Color(232, 50, 28, 16), 8.0f);
    outlinePen.SetLineJoin(LineJoinRound);
    LinearGradientBrush fillBrush(
        PointF(rect.X, rect.Y),
        PointF(rect.X, rect.Y + rect.Height),
        Color(255, 244, 228, 178),
        Color(255, 176, 122, 44));
    SolidBrush sheenBrush(Color(80, 255, 246, 220));

    graphics.DrawPath(&outlinePen, &textPath);
    graphics.FillPath(&fillBrush, &textPath);
    graphics.FillEllipse(&sheenBrush, rect.X + rect.Width * 0.33f, rect.Y + 10.0f, rect.Width * 0.18f, 22.0f);
}

void LayoutMenuControls() {
    if (!g_hWnd || !g_nameInput || !g_btnStart) return;

    RECT rect;
    GetClientRect(g_hWnd, &rect);
    int width = max(640, (int)(rect.right - rect.left));
    int height = max(520, (int)(rect.bottom - rect.top));

    int panelWidth = min(520, max(380, width - 180));
    int panelHeight = 210;
    int panelTop = max(250, (height - panelHeight) / 2 + 70);
    int centerX = width / 2;

    int inputWidth = min(360, panelWidth - 120);
    int inputFieldHeight = 38;
    int buttonWidth = 170;
    int buttonHeight = 42;
    int inputFieldY = panelTop + 82;
    int buttonY = panelTop + 142;

    SetWindowPos(g_nameInput, nullptr,
        centerX - inputWidth / 2 + 1, inputFieldY + 1, inputWidth - 2, inputFieldHeight - 2,
        SWP_NOZORDER | SWP_NOACTIVATE);

    RECT editTextRect = {0, 6, inputWidth - 2, inputFieldHeight - 2};
    SendMessageW(g_nameInput, EM_SETRECT, 0, (LPARAM)&editTextRect);

    SetWindowPos(g_btnStart, nullptr,
        centerX - buttonWidth / 2, buttonY, buttonWidth, buttonHeight,
        SWP_NOZORDER | SWP_NOACTIVATE);
}

// ==================== 记忆系统 ====================
void AddMemory(const wstring& title, const wstring& detail) {
    wstringstream ss;
    ss << L"第" << g_player.age << L"年【" << title << L"】" << detail;
    g_memoryLog.push_back(ss.str());
    if (g_memoryLog.size() > 80) {
        g_memoryLog.erase(g_memoryLog.begin());
    }
}

bool IsLifeArtifactCategory(const wstring& category) {
    return category == L"weapons" || category == L"artifacts";
}

wstring GetLifeArtifactCategoryLabel(const wstring& category) {
    if (category == L"weapons") return L"当世兵刃";
    if (category == L"artifacts") return L"当世法宝";
    return L"当世器物";
}

bool LooksLikeArtifactAcquisition(const wstring& text) {
    static const vector<wstring> positive = {
        L"获得", L"获赠", L"买下", L"夺得", L"抢得", L"卷走", L"捡走",
        L"找到", L"摸到", L"拆下", L"借", L"祭炼", L"护体", L"入手"
    };
    static const vector<wstring> negative = {
        L"损毁", L"掉包", L"是假", L"假货", L"错失", L"消散", L"拒绝"
    };
    bool hasPositive = false;
    for (const auto& key : positive) {
        if (text.find(key) != wstring::npos) {
            hasPositive = true;
            break;
        }
    }
    if (!hasPositive) return false;
    for (const auto& key : negative) {
        if (text.find(key) != wstring::npos) return false;
    }
    return true;
}

void TrackLifeArtifactsFromText(const wstring& text, const wstring& origin) {
    if (!LooksLikeArtifactAcquisition(text)) return;

    auto rows = LoadItemDbRows();
    for (auto& cols : rows) {
        if (cols.size() < 5 || !IsLifeArtifactCategory(cols[2])) continue;
        if (text.find(cols[1]) == wstring::npos) continue;

        auto existing = find_if(g_lifeArtifacts.begin(), g_lifeArtifacts.end(),
            [&](const LifeArtifact& item) { return item.name == cols[1]; });
        if (existing != g_lifeArtifacts.end()) {
            existing->origin = origin;
            existing->resonant = existing->resonant ||
                text.find(L"器纹") != wstring::npos ||
                text.find(L"器鸣") != wstring::npos ||
                text.find(L"道痕") != wstring::npos ||
                text.find(L"灵宝") != wstring::npos ||
                text.find(L"前世") != wstring::npos;
            continue;
        }

        LifeArtifact item;
        item.name = cols[1];
        item.category = cols[2];
        item.tier = cols[4];
        item.origin = origin;
        item.ageFound = g_player.age;
        item.resonant = text.find(L"器纹") != wstring::npos ||
                        text.find(L"器鸣") != wstring::npos ||
                        text.find(L"道痕") != wstring::npos ||
                        text.find(L"灵宝") != wstring::npos ||
                        text.find(L"前世") != wstring::npos;
        g_lifeArtifacts.push_back(item);
        AddMemory(L"本世器物", L"将 " + item.name + L" 记为本世可用的" + GetLifeArtifactCategoryLabel(item.category));
        if (g_lifeArtifacts.size() > 8) {
            g_lifeArtifacts.erase(g_lifeArtifacts.begin());
        }
    }
}

wstring BuildLifeArtifactDigest(int limit = 5) {
    if (g_lifeArtifacts.empty()) return L"暂无真正入手的当世兵刃或法宝。";
    wstringstream ss;
    int count = 0;
    for (const auto& item : g_lifeArtifacts) {
        if (count++ >= limit) break;
        ss << L"- " << item.name << L"（" << GetLifeArtifactCategoryLabel(item.category)
           << L" / " << item.tier << L"）";
        if (item.resonant) ss << L" · 有器痕回响";
        ss << L" · 第" << item.ageFound << L"年得自" << item.origin << L"\n";
    }
    return ss.str();
}

wstring BuildLifeArtifactText() {
    wstringstream ss;
    ss << L"【本世器物】\n\n";
    ss << L"这些是这一世真正入手或动用过的兵刃、法宝。它们能影响今生事件和 AI 叙事，但本体不能跨过轮回。\n";
    ss << L"死亡或转世后，普通器物会失散、损毁或被后人夺走；能留下来的只有记忆、因果、器痕，以及通天灵宝残印。\n\n";
    ss << BuildLifeArtifactDigest(8);
    return ss.str();
}

int GetForgeArtifactCost() {
    int cost = 8 + g_player.realm * 3;
    if (g_worldEraName == L"灵机蒸汽纪") cost -= 3;
    else if (g_worldEraName == L"星穹道网纪") cost += 2;
    else if (g_worldEraName == L"末法裂变纪") cost += 8;
    else if (g_worldEraName == L"废土返道纪") cost += 6;
    return max(5, cost);
}

wstring GetForgeOriginText() {
    if (g_worldEraName == L"灵机蒸汽纪") return L"玄炉工坊铸炼";
    if (g_worldEraName == L"星穹道网纪") return L"道网器坊定制";
    if (g_worldEraName == L"末法裂变纪") return L"半枯灵炉抢炼";
    if (g_worldEraName == L"废土返道纪") return L"废墟残炉重铸";
    if (g_worldEraName == L"仙朝鼎盛纪") return L"仙朝官坊铸给";
    return L"坊市炼器铺铸成";
}

void AddForgedLifeArtifact(const LifeArtifact& forged) {
    auto existing = find_if(g_lifeArtifacts.begin(), g_lifeArtifacts.end(),
        [&](const LifeArtifact& item) { return item.name == forged.name; });
    if (existing != g_lifeArtifacts.end()) {
        existing->tier = forged.tier;
        existing->origin = forged.origin;
        existing->ageFound = forged.ageFound;
        existing->resonant = existing->resonant || forged.resonant;
        AddMemory(L"重铸器物", forged.name + L"重新祭炼，仍只是本世器物，本体不能跨过轮回。");
        return;
    }

    g_lifeArtifacts.push_back(forged);
    AddMemory(L"铸成本世器物",
        forged.name + L"成为今生可用的" + GetLifeArtifactCategoryLabel(forged.category) +
        (forged.resonant ? L"，铸成时已有细微器纹回响。" : L"，但本体终会随此世失散。"));
    if (g_lifeArtifacts.size() > 8) {
        g_lifeArtifacts.erase(g_lifeArtifacts.begin());
    }
}

wstring ForgeLifeArtifact() {
    int cost = GetForgeArtifactCost();
    if (g_player.spiritStones < cost) {
        return L"灵石不足，铸炼一件本世兵刃或法宝需要 " + to_wstring(cost) +
               L" 灵石。\n\n普通器物可以陪你走完今生，但本体不能跨过轮回。";
    }

    auto rows = LoadItemDbRows();
    vector<vector<wstring>> candidates;
    bool preferArtifact = g_worldEraName == L"灵机蒸汽纪" ||
                          g_worldEraName == L"星穹道网纪" ||
                          g_player.realm >= GOLDEN_CORE;
    for (auto& cols : rows) {
        if (cols.size() < 9 || !IsLifeArtifactCategory(cols[2])) continue;
        if (preferArtifact && cols[2] != L"artifacts") continue;
        candidates.push_back(cols);
    }
    if (candidates.empty()) {
        for (auto& cols : rows) {
            if (cols.size() >= 9 && IsLifeArtifactCategory(cols[2])) candidates.push_back(cols);
        }
    }
    if (candidates.empty()) {
        return L"没有可用的器物图录，暂时无法铸炼。";
    }

    vector<vector<wstring>> fresh;
    for (auto& cols : candidates) {
        bool owned = any_of(g_lifeArtifacts.begin(), g_lifeArtifacts.end(),
            [&](const LifeArtifact& item) { return item.name == cols[1]; });
        if (!owned) fresh.push_back(cols);
    }
    auto& pool = fresh.empty() ? candidates : fresh;
    auto cols = pool[Random(0, (int)pool.size() - 1)];

    g_player.spiritStones -= cost;
    int resonanceChance = 8 + g_player.realm * 2 + g_legacySystem.GetRelicResonanceBonus() / 3;
    if (g_worldEraName == L"灵机蒸汽纪") resonanceChance += 8;
    if (g_worldEraName == L"末法裂变纪") resonanceChance -= 4;
    bool resonant = Random(1, 100) <= max(3, min(42, resonanceChance));

    LifeArtifact forged;
    forged.name = cols[1];
    forged.category = cols[2];
    forged.tier = cols[4];
    forged.origin = GetForgeOriginText();
    forged.ageFound = g_player.age;
    forged.resonant = resonant;
    AddForgedLifeArtifact(forged);
    DiscoverItemsFromText(forged.name);
    g_contextMgr.SetContext(BuildPlayerContext());

    wstringstream ss;
    ss << L"你耗费 " << cost << L" 灵石，请匠人以此世法门铸成 " << forged.name
       << L"（" << GetLifeArtifactCategoryLabel(forged.category) << L" / " << forged.tier << L"）。\n\n";
    if (cols.size() >= 9 && !cols[8].empty()) {
        ss << cols[8] << L"\n\n";
    }
    ss << L"它会进入本世器物，后续历练和本地 AI 可以围绕它续写。";
    if (resonant) {
        ss << L"\n铸成一瞬，器纹与通天灵宝残印轻轻相触；这不是跨世保留本体，只是留下可被轮回辨认的器痕。";
    } else {
        ss << L"\n它只是今生器物，本体终会随死亡、转世或时代更替而失散。";
    }
    return ss.str();
}

bool TextMentionsArtifactResonance(const wstring& text) {
    static const vector<wstring> keys = {
        L"器痕", L"器纹", L"器鸣", L"道痕", L"灵宝", L"前世", L"封存器痕", L"残印"
    };
    for (const auto& key : keys) {
        if (text.find(key) != wstring::npos) return true;
    }
    return false;
}

void MarkLifeArtifactsResonantFromText(const wstring& text) {
    if (g_lifeArtifacts.empty() || !TextMentionsArtifactResonance(text)) return;

    bool markedAny = false;
    for (auto& item : g_lifeArtifacts) {
        if (text.find(item.name) != wstring::npos ||
            text.find(L"本世器物") != wstring::npos ||
            text.find(L"今生器物") != wstring::npos ||
            text.find(L"当世兵刃") != wstring::npos ||
            text.find(L"当世法宝") != wstring::npos) {
            item.resonant = true;
            markedAny = true;
        }
    }

    if (!markedAny && g_lifeArtifacts.size() == 1) {
        g_lifeArtifacts[0].resonant = true;
    }
}

int LifeArtifactTraceValue(const LifeArtifact& item) {
    if (!item.resonant) return 0;
    int value = item.category == L"artifacts" ? 4 : 3;
    if (item.tier.find(L"天阶") != wstring::npos) value += 6;
    else if (item.tier.find(L"地阶") != wstring::npos) value += 4;
    else if (item.tier.find(L"灵阶") != wstring::npos) value += 2;
    return value;
}

int GetLifeArtifactTraceResonanceGain() {
    int gain = 0;
    for (const auto& item : g_lifeArtifacts) {
        gain += LifeArtifactTraceValue(item);
    }
    return min(45, gain);
}

wstring BuildLifeArtifactTraceText(int limit = 3) {
    vector<wstring> traces;
    for (const auto& item : g_lifeArtifacts) {
        if (item.resonant) {
            traces.push_back(item.name + L"（" + GetLifeArtifactCategoryLabel(item.category) + L"）");
        }
    }
    if (traces.empty()) return L"";

    wstringstream ss;
    int count = min(limit, (int)traces.size());
    for (int i = 0; i < count; ++i) {
        if (i > 0) ss << L"、";
        ss << traces[i];
    }
    if ((int)traces.size() > count) ss << L"等" << traces.size() << L"件器物";
    return ss.str();
}

const LifeArtifact* PickLifeArtifactForEvent() {
    if (g_lifeArtifacts.empty()) return nullptr;

    vector<int> weighted;
    for (int i = 0; i < (int)g_lifeArtifacts.size(); ++i) {
        const LifeArtifact& item = g_lifeArtifacts[i];
        int weight = item.resonant ? 5 : 2;
        if (item.category == L"artifacts") weight += 1;
        if (item.tier.find(L"天阶") != wstring::npos) weight += 3;
        else if (item.tier.find(L"地阶") != wstring::npos) weight += 2;
        for (int j = 0; j < weight; ++j) {
            weighted.push_back(i);
        }
    }

    if (weighted.empty()) return &g_lifeArtifacts[0];
    return &g_lifeArtifacts[weighted[Random(0, (int)weighted.size() - 1)]];
}

bool ShouldTriggerLifeArtifactEvent() {
    if (g_lifeArtifacts.empty()) return false;

    int chance = 8 + min(10, (int)g_lifeArtifacts.size() * 2);
    for (const auto& item : g_lifeArtifacts) {
        if (item.resonant) chance += 4;
        if (item.category == L"artifacts") chance += 1;
    }
    if (g_worldEraName == L"灵机蒸汽纪" || g_worldEraName == L"星穹道网纪") chance += 2;
    if (g_worldEraName == L"末法裂变纪") chance += 3;
    chance = max(8, min(32, chance));
    return Random(1, 100) <= chance;
}

wstring BuildArtifactEraPressureText() {
    if (g_worldEraName == L"灵机蒸汽纪") {
        return L"灵机工坊想拆解它的阵纹，证明器物也能被量产。";
    }
    if (g_worldEraName == L"星穹道网纪") {
        return L"道网器榜正在检索它的灵息，远方修士也可能看见这次动用。";
    }
    if (g_worldEraName == L"末法裂变纪") {
        return L"末法资源稀薄，任何一件可用器物都可能招来抢夺。";
    }
    if (g_worldEraName == L"废土返道纪") {
        return L"废土残炉难再复刻它，一旦损毁，今生便难找替代。";
    }
    if (g_worldEraName == L"仙朝鼎盛纪") {
        return L"仙朝官册想给它定品入册，定了品也就多了一层束缚。";
    }
    return L"山门与坊市都知道，好器物能护一世，却护不过轮回。";
}

Event BuildLifeArtifactEvent() {
    Event evt;
    const LifeArtifact* picked = PickLifeArtifactForEvent();
    if (!picked) {
        evt.title = L"【机缘】空手问器";
        evt.description = L"你忽然意识到自己这一世尚无真正可托付的兵刃或法宝。";
        evt.choices = {
            {L"记下缺口", {L"你把这份空缺记在心里，准备日后铸炼本世器物。\n修为+30", L"念头一闪而过。"}, 0}
        };
        return evt;
    }

    const LifeArtifact& item = *picked;
    int tierBonus = 0;
    if (item.tier.find(L"天阶") != wstring::npos) tierBonus = 32;
    else if (item.tier.find(L"地阶") != wstring::npos) tierBonus = 22;
    else if (item.tier.find(L"灵阶") != wstring::npos) tierBonus = 12;
    int expGain = 70 + g_player.realm * 4 + tierBonus;
    int relicGain = item.resonant ? 7 : 5;
    int hpRisk = 18 + g_player.realm + tierBonus / 3;
    wstring itemLabel = GetLifeArtifactCategoryLabel(item.category);

    evt.title = L"【器物】" + item.name + L"应劫";
    evt.description = L"历练途中，" + item.name + L"忽然与眼前凶局相合。" +
        BuildArtifactEraPressureText() + L"它是" + itemLabel + L"，可护今生，却不能把本体带过轮回。";
    evt.choices = {
        {L"祭出破局", {
            L"你祭出" + item.name + L"破开眼前凶险，明白器物强在此世可用。\n修为+" + to_wstring(expGain),
            item.name + L"承受余波后裂痕暗生，本体终究只是今生器物。\n气血-" + to_wstring(hpRisk)
        }, 3},
        {L"封存器痕", {
            L"你没有强求" + item.name + L"本体跨世，只把一缕器纹封入通天灵宝残印。\n修为+" + to_wstring(expGain - 20) + L"，灵宝共鸣+" + to_wstring(relicGain) + L"，因果+5",
            item.name + L"器痕太急，反把今生心神震得发闷。\n气血-" + to_wstring(max(12, hpRisk - 5))
        }, 6},
        {L"温养不争", {
            L"你没有急着动用" + item.name + L"，只让它陪你走完今生更长一段路。\n寿命+3，修为+" + to_wstring(max(35, expGain / 2)),
            L"你保住了器物，却也错过了眼前最锋利的破局时机。"
        }, 2}
    };
    return evt;
}

void DiscoverItemsFromText(const wstring& text) {
    auto rows = LoadItemDbRows();
    for (auto& cols : rows) {
        if (cols.size() >= 2 && text.find(cols[1]) != wstring::npos) {
            if (find(g_discoveredItems.begin(), g_discoveredItems.end(), cols[1]) == g_discoveredItems.end()) {
                g_discoveredItems.push_back(cols[1]);
                AddMemory(L"灵物见闻", L"将 " + cols[1] + L" 记入了灵物图录");
            }
        }
    }
}

wstring GetMemoryText(int limit = 12) {
    wstringstream ss;
    ss << L"【道途记忆】\n\n";
    ss << L"当前第" << g_generation << L"世\n\n";

    if (g_memoryLog.empty()) {
        ss << L"你的道途尚未留下重要痕迹。";
        return ss.str();
    }

    int start = max(0, (int)g_memoryLog.size() - limit);
    for (int i = start; i < (int)g_memoryLog.size(); i++) {
        ss << L"- " << g_memoryLog[i] << L"\n";
    }
    return ss.str();
}

bool IsKeyReincarnationMemory(const wstring& memory) {
    static const vector<wstring> keys = {
        L"一世落幕", L"死亡", L"坐化", L"证道", L"万道归一",
        L"通天灵宝", L"鸿蒙", L"传承", L"前世", L"轮回",
        L"境界突破", L"本地模型", L"人情风波", L"本世人脉", L"此世出身", L"本世主线",
        L"伴生玉佩", L"玉佩", L"玄牝轮回玉", L"本世器物", L"当世器物", L"旧世残响", L"纪元转折", L"纪元年表", L"未竟"
    };
    for (const auto& key : keys) {
        if (memory.find(key) != wstring::npos) return true;
    }
    return false;
}

wstring CompactMemoryFragment(const wstring& memory) {
    wstring out;
    bool lastSpace = false;
    for (wchar_t ch : memory) {
        if (ch == L'\r' || ch == L'\n' || ch == L'\t') {
            if (!lastSpace) {
                out.push_back(L' ');
                lastSpace = true;
            }
        } else {
            out.push_back(ch);
            lastSpace = (ch == L' ');
        }
    }
    return out;
}

vector<wstring> SelectReincarnationMemoryFragments(int limit = 8) {
    vector<wstring> fragments;
    auto addUnique = [&](const wstring& memory) {
        if ((int)fragments.size() >= limit) return;
        wstring compact = CompactMemoryFragment(memory);
        if (find(fragments.begin(), fragments.end(), compact) == fragments.end()) {
            fragments.push_back(compact);
        }
    };

    for (int i = (int)g_memoryLog.size() - 1; i >= 0 && (int)fragments.size() < limit; --i) {
        if (IsKeyReincarnationMemory(g_memoryLog[i])) {
            addUnique(g_memoryLog[i]);
        }
    }
    for (int i = (int)g_memoryLog.size() - 1; i >= 0 && (int)fragments.size() < limit; --i) {
        addUnique(g_memoryLog[i]);
    }

    reverse(fragments.begin(), fragments.end());
    return fragments;
}

int GetCompanionJadeMemoryLimit() {
    int limit = 8;
    if (g_generation >= 2) limit += 1;
    if (g_player.realm >= GOLDEN_CORE) limit += 1;
    if (g_player.realm >= MAHAYANA) limit += 1;
    if (g_player.realm >= TRUE_IMMORTAL) limit += 1;
    if (g_player.totalEvents >= 12) limit += 1;
    if (g_player.totalEvents >= 30) limit += 1;
    if (CountHongmengInsightKinds() >= 2) limit += 1;
    return min(14, limit);
}

wstring BuildCompanionJadeDeathAnchorText(const wstring& causeOfDeath) {
    wstringstream ss;
    ss << L"生死将尽时，黑白伴生玉佩在神魂里微微发温，把这一世最重的几段记忆压成梦痕。";
    ss << L"你仍不知道它真正来历，只知道自己没有完全空白地坠入轮回。";
    ss << L"本次死因：" << causeOfDeath << L"。";
    return ss.str();
}

void SaveMemory(wofstream& file) {
    file << L"MEMORY_V3\n";
    file << g_generation << L"\n";
    file << g_memoryLog.size() << L"\n";
    for (auto& item : g_memoryLog) {
        file << EscapeSaveField(item) << L"\n";
    }
    file << g_discoveredItems.size() << L"\n";
    for (auto& item : g_discoveredItems) {
        file << EscapeSaveField(item) << L"\n";
    }
    file << g_lifeArtifacts.size() << L"\n";
    for (auto& item : g_lifeArtifacts) {
        file << EscapeSaveField(item.name) << L"\n";
        file << EscapeSaveField(item.category) << L"\n";
        file << EscapeSaveField(item.tier) << L"\n";
        file << EscapeSaveField(item.origin) << L"\n";
        file << item.ageFound << L" " << item.resonant << L"\n";
    }
}

void SaveSocialRumors(wofstream& file) {
    file << L"SOCIAL_V2\n";
    file << g_socialRumors.size() << L"\n";
    for (auto& item : g_socialRumors) {
        file << EscapeSaveField(item) << L"\n";
    }
    file << g_socialThreads.size() << L"\n";
    for (auto& thread : g_socialThreads) {
        file << EscapeSaveField(thread.name) << L"\n";
        file << EscapeSaveField(thread.role) << L"\n";
        file << EscapeSaveField(thread.attitude) << L"\n";
        file << EscapeSaveField(thread.hook) << L"\n";
        file << EscapeSaveField(thread.visibleRealm) << L"\n";
        file << EscapeSaveField(thread.hiddenHint) << L"\n";
        file << thread.relation << L" " << thread.hidesPower << L"\n";
    }
}

bool LoadSocialRumors(wifstream& file) {
    wstring marker;
    getline(file, marker);
    if (marker.empty()) getline(file, marker);
    bool isV2 = (marker == L"SOCIAL_V2");
    if (marker != L"SOCIAL_V1" && !isV2) return false;
    size_t count = 0;
    file >> count;
    file.ignore(numeric_limits<streamsize>::max(), L'\n');
    g_socialRumors.clear();
    for (size_t i = 0; i < count; i++) {
        wstring item;
        getline(file, item);
        if (isV2) item = UnescapeSaveField(item);
        g_socialRumors.push_back(item);
    }
    g_socialThreads.clear();
    if (isV2) {
        file >> count;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        for (size_t i = 0; i < count; i++) {
            SocialThread thread;
            getline(file, thread.name);
            getline(file, thread.role);
            getline(file, thread.attitude);
            getline(file, thread.hook);
            getline(file, thread.visibleRealm);
            getline(file, thread.hiddenHint);
            thread.name = UnescapeSaveField(thread.name);
            thread.role = UnescapeSaveField(thread.role);
            thread.attitude = UnescapeSaveField(thread.attitude);
            thread.hook = UnescapeSaveField(thread.hook);
            thread.visibleRealm = UnescapeSaveField(thread.visibleRealm);
            thread.hiddenHint = UnescapeSaveField(thread.hiddenHint);
            file >> thread.relation >> thread.hidesPower;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
            g_socialThreads.push_back(thread);
        }
    }
    return true;
}

bool LoadMemory(wifstream& file) {
    wstring marker;
    getline(file, marker);
    if (marker.empty()) getline(file, marker);
    bool isV2 = (marker == L"MEMORY_V2");
    bool isV3 = (marker == L"MEMORY_V3");
    if (marker != L"MEMORY_V1" && !isV2 && !isV3) return false;

    file >> g_generation;
    file.ignore(numeric_limits<streamsize>::max(), L'\n');

    size_t count = 0;
    file >> count;
    file.ignore(numeric_limits<streamsize>::max(), L'\n');

    g_memoryLog.clear();
    for (size_t i = 0; i < count; i++) {
        wstring item;
        getline(file, item);
        if (isV2 || isV3) item = UnescapeSaveField(item);
        g_memoryLog.push_back(item);
    }
    file >> count;
    file.ignore(numeric_limits<streamsize>::max(), L'\n');
    g_discoveredItems.clear();
    for (size_t i = 0; i < count; i++) {
        wstring item;
        getline(file, item);
        if (isV2 || isV3) item = UnescapeSaveField(item);
        g_discoveredItems.push_back(item);
    }
    g_lifeArtifacts.clear();
    if (isV3) {
        file >> count;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        for (size_t i = 0; i < count; i++) {
            LifeArtifact item;
            getline(file, item.name);
            getline(file, item.category);
            getline(file, item.tier);
            getline(file, item.origin);
            item.name = UnescapeSaveField(item.name);
            item.category = UnescapeSaveField(item.category);
            item.tier = UnescapeSaveField(item.tier);
            item.origin = UnescapeSaveField(item.origin);
            file >> item.ageFound >> item.resonant;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
            g_lifeArtifacts.push_back(item);
        }
    }
    return true;
}

wstring BuildEraRemnantsText(int limit = 6) {
    if (g_eraRemnants.empty()) return L"";
    wstringstream ss;
    ss << L"【旧世残响】\n";
    int count = 0;
    for (const auto& remnant : g_eraRemnants) {
        if (count++ >= limit) break;
        ss << L"- " << remnant << L"\n";
    }
    return ss.str();
}

void AddEraRemnant(const wstring& remnant) {
    if (remnant.empty()) return;
    if (find(g_eraRemnants.begin(), g_eraRemnants.end(), remnant) == g_eraRemnants.end()) {
        g_eraRemnants.push_back(remnant);
    }
}

void GenerateEraRemnants(const wstring& previousEra) {
    g_eraRemnants.clear();

    if (g_generation <= 1) {
        AddEraRemnant(L"初世锚点：这一世尚无可考前代遗迹，所有宗门、秘境与人情债都在为后世埋下第一批痕迹。");
        return;
    }

    if (previousEra == g_worldEraName) {
        AddEraRemnant(L"延续纪痕：大时代未变，但上一世熟悉的宗门名册、坊市债契和秘境入口已经被新人重新分配。");
    } else {
        AddEraRemnant(L"断代裂隙：上一世的" + previousEra + L"没有彻底消失，只是被" + g_worldEraName + L"覆盖成新的秩序。");
    }
    if (!g_eraShiftCause.empty()) {
        AddEraRemnant(L"转折因由：" + g_eraShiftCause);
    }

    if (previousEra == L"灵气初盛纪") {
        AddEraRemnant(L"古修石简：早期宗门刻下的修行注解仍埋在山腹里，后世修士常把它误认成普通碑文。");
    } else if (previousEra == L"仙朝鼎盛纪") {
        AddEraRemnant(L"旧朝金册：仙朝册封残卷仍能牵动气运，世家和宗门都想知道你的姓名是否曾被写入其中。");
    } else if (previousEra == L"末法裂变纪") {
        AddEraRemnant(L"枯井断契：末法时代留下的灵井配给契约仍在流转，每一页都记着资源争夺中的旧仇。");
    } else if (previousEra == L"灵机蒸汽纪") {
        AddEraRemnant(L"废炉齿印：失效灵机工坊深处仍有齿轮阵列自转，像在复演上一世未完成的器纹。");
    } else if (previousEra == L"星穹道网纪") {
        AddEraRemnant(L"断网残频：旧灵网节点偶尔吐出上一纪元的试炼坐标，其中夹着不该属于今生的旧名。");
    } else if (previousEra == L"废土返道纪") {
        AddEraRemnant(L"荒墟黑匣：废土修士封存的逃亡记录仍能回放，只是声音里常混进前世记忆。");
    }

    if (g_worldEraName == L"灵机蒸汽纪") {
        AddEraRemnant(L"当世改写：工坊修士正在拆解旧时代遗物，试图把宗门秘法改造成可量产的阵械。");
    } else if (g_worldEraName == L"星穹道网纪") {
        AddEraRemnant(L"当世改写：道网会把旧时代传说做成榜单和试炼，真假因果混在同一条远讯里。");
    } else if (g_worldEraName == L"末法裂变纪") {
        AddEraRemnant(L"当世改写：灵气衰落后，旧时代遗物不再只是文物，而是可以换命的资源。");
    } else if (g_worldEraName == L"废土返道纪") {
        AddEraRemnant(L"当世改写：文明断裂让旧时代遗址变成荒野禁区，能读懂它们的人会被各方争夺。");
    } else if (g_worldEraName == L"仙朝鼎盛纪") {
        AddEraRemnant(L"当世改写：仙朝试图把旧时代遗迹纳入册封体系，凡是无法登记的传承都会被暗中盯上。");
    } else {
        AddEraRemnant(L"当世改写：古典宗门把旧世线索称作天机，只有入门试炼后才准弟子靠近。");
    }

    auto fragments = g_legacySystem.GetLatestMemoryFragments(2);
    if (!fragments.empty()) {
        AddEraRemnant(L"前世叠影：" + fragments[0]);
    }

    if (g_eraRemnants.size() > 5) {
        g_eraRemnants.resize(5);
    }
}

wstring BuildEraChronicleText(int limit = 8) {
    if (g_eraChronicle.empty()) return L"";
    wstringstream ss;
    ss << L"【纪元年表】\n";
    int start = max(0, (int)g_eraChronicle.size() - limit);
    for (int i = start; i < (int)g_eraChronicle.size(); ++i) {
        ss << L"- " << g_eraChronicle[i] << L"\n";
    }
    return ss.str();
}

void RecordEraChronicle(const wstring& previousEra) {
    wstringstream entry;
    entry << L"第" << g_generation << L"世 · " << g_worldEraName << L" · ";
    if (g_generation <= 1) {
        entry << L"开局纪元";
    } else if (previousEra == g_worldEraName) {
        entry << L"延续自" << previousEra;
    } else {
        entry << L"由" << previousEra << L"转入";
    }
    entry << L" · " << g_worldEraRule;
    if (!g_eraShiftCause.empty()) {
        entry << L" · 因由 " << CompactMemoryFragment(g_eraShiftCause);
    }
    if (!g_eraRemnants.empty()) {
        entry << L" · " << CompactMemoryFragment(g_eraRemnants[0]);
    }

    wstring prefix = L"第" + to_wstring(g_generation) + L"世 · ";
    for (auto& existing : g_eraChronicle) {
        if (existing.find(prefix) == 0) {
            existing = entry.str();
            return;
        }
    }

    g_eraChronicle.push_back(entry.str());
    if (g_eraChronicle.size() > 16) {
        g_eraChronicle.erase(g_eraChronicle.begin(), g_eraChronicle.begin() + (g_eraChronicle.size() - 16));
    }
}

bool HasFactionTie() {
    return !g_factionTie.name.empty();
}

wstring BuildFactionTieDigest() {
    if (!HasFactionTie()) return L"暂无明确势力牵连。";
    wstringstream ss;
    ss << g_factionTie.name << L"（" << g_factionTie.kind << L"）"
       << L" · " << g_factionTie.role
       << L" · " << g_factionTie.stance
       << L" · 牵连值" << (g_factionTie.favor >= 0 ? L"+" : L"") << g_factionTie.favor;
    if (g_factionTie.binding) ss << L" · 已有契约";
    if (!g_factionTie.obligation.empty()) ss << L" · " << g_factionTie.obligation;
    if (!g_factionTie.hook.empty()) ss << L" · " << g_factionTie.hook;
    return ss.str();
}

wstring BuildFactionTieText() {
    wstringstream ss;
    ss << L"【本世势力牵连】\n\n";
    if (!HasFactionTie()) {
        ss << L"这一世尚未被明确势力记录，但只要踏入道途，宗门、世家、仙朝或工坊迟早会注意到你。";
        return ss.str();
    }

    ss << L"势力: " << g_factionTie.name << L"\n";
    ss << L"类型: " << g_factionTie.kind << L"\n";
    ss << L"身份: " << g_factionTie.role << L"\n";
    ss << L"态度: " << g_factionTie.stance << L"\n";
    ss << L"牵连值: " << (g_factionTie.favor >= 0 ? L"+" : L"") << g_factionTie.favor << L"\n";
    ss << L"约束: " << (g_factionTie.binding ? L"已有契约或旧债" : L"尚可抽身，但已被记录") << L"\n";
    if (!g_factionTie.obligation.empty()) {
        ss << L"旧债/条件: " << g_factionTie.obligation << L"\n";
    }
    if (!g_factionTie.hook.empty()) {
        ss << L"后续线索: " << g_factionTie.hook << L"\n";
    }
    ss << L"\n本地 AI 会优先把这个势力当成本世持续存在的组织来续写，而不是每次凭空换一个宗门。";
    return ss.str();
}

wstring BuildEraShiftCauseText(const wstring& previousEra, const wstring& nextEra) {
    auto& pastLives = g_legacySystem.GetPastLives();
    if (g_generation <= 1 || pastLives.empty()) {
        return L"初世尚无前因，天地大势仍在等待你的选择留下第一道痕迹。";
    }

    const PastLife& last = pastLives.back();
    Realm reached = static_cast<Realm>(max(0, min(last.realmReached, (int)HEAVENLY_DAO)));
    wstringstream ss;
    ss << L"上一世止步于" << GetRealmName(reached)
       << L"，死因是" << last.causeOfDeath
       << L"，因果" << (last.karma >= 0 ? L"+" : L"") << last.karma
       << L"，留下" << last.memoryFragments.size() << L"段记忆与"
       << last.unfinishedKarmas.size() << L"条未竟因果。";

    if (nextEra == previousEra) {
        ss << L"大时代没有彻底改道，但旧宗门、旧名册和旧债契已经被新人重新分配。";
    } else if (nextEra == L"灵气初盛纪") {
        ss << L"旧秩序在轮回后被洗薄，幸存者重新把古法、山门和洞府当作文明根基。";
    } else if (nextEra == L"仙朝鼎盛纪") {
        ss << L"前世声名、战乱和未结清的人情债促使宗门拥立更强的名册与册封制度。";
    } else if (nextEra == L"末法裂变纪") {
        ss << L"前世资源争夺、破境反噬和未竟旧债不断消耗灵脉，逼出末法与替道之学。";
    } else if (nextEra == L"灵机蒸汽纪") {
        ss << L"前世器物、阵法和通天灵宝残印的传说被后人拆解，机关工坊因此压过旧山门。";
    } else if (nextEra == L"星穹道网纪") {
        ss << L"前世记忆碎片、旧名和远讯坐标被各方记录，最终催生能跨洲追踪因果的道网。";
    } else if (nextEra == L"废土返道纪") {
        ss << L"前世杀伐、失控试验或断代旧债在后世爆开，文明断裂后只剩残宗从废墟里返道。";
    }
    return ss.str();
}

void GenerateWorldEra() {
    struct EraProfile {
        const wchar_t* name;
        const wchar_t* desc;
        const wchar_t* rule;
    };

    static const vector<EraProfile> eras = {
        {L"灵气初盛纪", L"诸宗并立，古修遗府频现，天地仍偏爱最纯粹的修真者。", L"山门法统压过王朝法度，凡俗与修士之间仍隔着天堑。"},
        {L"仙朝鼎盛纪", L"仙门与皇朝合流，气运、血脉与册封制度开始左右修行上限。", L"想要更进一步，不仅要修为，也要站队、门第与气运。"},
        {L"末法裂变纪", L"灵气日渐稀薄，秘境争夺加剧，许多人开始研究阵械与替代性的修行体系。", L"单靠苦修越来越难，资源、机巧和掠夺变得同样重要。"},
        {L"灵机蒸汽纪", L"修真文明和机关术深度融合，灵石驱动的工坊、飞舟与阵列城邦开始扩张。", L"宗门仍在，但炼器、机巧、量产灵具正在改变旧秩序。"},
        {L"星穹道网纪", L"灵网覆盖大域，神识终端、远程阵列和跨洲飞舟让道统传播前所未有地迅捷。", L"信息与道法同样重要，闭门苦修者也可能被时代抛下。"},
        {L"废土返道纪", L"上一轮文明在灾变中崩塌，残存修士、古代灵机与荒野邪祟共同瓜分世界。", L"活下去与重建秩序比纯粹飞升更难，传承因此格外珍贵。"}
    };

    wstring previousEra = g_worldEraName;
    int treasureEcho = g_legacySystem.GetLegacyBonus(LEGACY_TREASURE);
    int knowledgeEcho = g_legacySystem.GetLegacyBonus(LEGACY_KNOWLEDGE);
    int memoryEcho = g_legacySystem.GetLegacyBonus(LEGACY_MEMORY);
    int reputationEcho = g_legacySystem.GetLegacyBonus(LEGACY_REPUTATION);
    int relicEcho = g_legacySystem.GetRelicResonanceBonus();

    int baseIndex = Random(0, (int)eras.size() - 1);
    if (g_generation >= 3) {
        baseIndex = (g_generation - 1 + Random(0, 2)) % (int)eras.size();
    }
    if (g_generation > 1) {
        vector<int> pressure;
        auto addPressure = [&](int index, int weight = 1) {
            if (index < 0 || index >= (int)eras.size()) return;
            for (int i = 0; i < max(1, weight); ++i) pressure.push_back(index);
        };

        auto& pastLives = g_legacySystem.GetPastLives();
        if (!pastLives.empty()) {
            const PastLife& last = pastLives.back();
            if (last.realmReached >= DAO_ANCESTOR) {
                addPressure(4, 3); // 星穹道网纪
                addPressure(1, 2); // 仙朝鼎盛纪
            } else if (last.realmReached >= IMMORTAL_EMPEROR) {
                addPressure(1, 2);
                addPressure(4, 1);
            }
            if (last.karma <= -120 || last.battlesWon >= max(8, last.totalEvents / 3)) {
                addPressure(5, 3); // 废土返道纪
                addPressure(2, 2); // 末法裂变纪
            }
            if (last.karma >= 120 || last.npcsMet >= 12) {
                addPressure(1, 2);
                addPressure(0, 1);
            }
            if (last.totalEvents >= 30 || knowledgeEcho >= 50) {
                addPressure(3, 2); // 灵机蒸汽纪
                addPressure(4, 1);
            }
            if (treasureEcho >= 40 || relicEcho >= 15) {
                addPressure(3, 2);
                addPressure(4, 1);
            }
            if (memoryEcho >= 40 || !last.unfinishedKarmas.empty()) {
                addPressure(4, 2);
                addPressure(2, 1);
            }
            if (last.causeOfDeath.find(L"历练中身死") != wstring::npos ||
                last.causeOfDeath.find(L"天道归一") != wstring::npos) {
                addPressure(last.causeOfDeath.find(L"天道归一") != wstring::npos ? 4 : 5, 2);
            }
        }

        if (previousEra == L"灵气初盛纪") {
            addPressure(1);
            addPressure(3);
        } else if (previousEra == L"仙朝鼎盛纪") {
            addPressure(2);
            addPressure(4);
        } else if (previousEra == L"末法裂变纪") {
            addPressure(3);
            addPressure(5);
        } else if (previousEra == L"灵机蒸汽纪") {
            addPressure(4);
            addPressure(2);
        } else if (previousEra == L"星穹道网纪") {
            addPressure(5);
            addPressure(1);
        } else if (previousEra == L"废土返道纪") {
            addPressure(0);
            addPressure(3);
        }

        if (!pressure.empty() && Random(1, 100) <= 72) {
            baseIndex = pressure[Random(0, (int)pressure.size() - 1)];
        }
    }

    const EraProfile& era = eras[baseIndex];
    g_worldEraName = era.name;
    g_worldEraDescription = era.desc;
    g_worldEraRule = era.rule;
    g_eraShiftCause = BuildEraShiftCauseText(previousEra, g_worldEraName);

    if (g_generation <= 1) {
        g_eraTransitionNote = L"这是本局第一段完整时代。若你死后转世，下一世可能已经从古典修仙演化到灵机、道网、末法或废土。";
    } else if (previousEra == g_worldEraName) {
        g_eraTransitionNote = L"轮回之后，时代大势仍延续为" + g_worldEraName + L"，但人事、宗门与机缘已经重新洗牌。";
    } else {
        g_eraTransitionNote = L"轮回醒来时，天地秩序已由" + previousEra + L"转入" + g_worldEraName + L"，旧经验只能作为参考。";
    }

    if (relicEcho >= 25 || treasureEcho >= 40) {
        g_reincarnationEcho = L"你隐约能感到某件前世祭炼过的重宝仍在呼应自己，这一世有关器灵、法宝与遗府的因果会更浓。";
    } else if (knowledgeEcho >= 40) {
        g_reincarnationEcho = L"你对阵法、斗法与局势判断有一种不合年龄的熟悉感，像是旧世经验仍在替你做选择。";
    } else if (memoryEcho >= 30) {
        g_reincarnationEcho = L"梦境里反复出现前世的山门、故人和败亡之地，你知道这一世迟早会与那些残影重逢。";
    } else if (reputationEcho >= 40) {
        g_reincarnationEcho = L"尚未踏上道途，外界却已对你投来莫名善意或敌意，仿佛前世的名声先你一步归来。";
    } else {
        g_reincarnationEcho = L"前世残响仍浅，只会在某些关键时刻轻轻拨动你的心念。";
    }

    GenerateEraRemnants(previousEra);
    RecordEraChronicle(previousEra);
}

wstring GetEraSummaryText() {
    wstringstream ss;
    ss << L"【时代风貌】\n\n";
    ss << L"纪元: " << g_worldEraName << L"\n";
    ss << g_worldEraDescription << L"\n";
    ss << L"时代法则: " << g_worldEraRule << L"\n";
    ss << L"时代变迁: " << g_eraTransitionNote << L"\n";
    ss << L"转折因由: " << g_eraShiftCause << L"\n";
    ss << L"轮回余烬: " << g_reincarnationEcho << L"\n";
    ss << L"鸿蒙天象: " << BuildHongmengOmenBrief() << L"\n";
    if (!g_eraChronicle.empty()) {
        ss << BuildEraChronicleText(6) << L"\n";
    }
    if (!g_eraRemnants.empty()) {
        ss << BuildEraRemnantsText(5) << L"\n";
    }
    ss << L"本世主题: " << g_lifePremise << L"\n";
    if (HasFactionTie()) {
        ss << L"本世势力: " << BuildFactionTieDigest() << L"\n";
    }
    if (!g_lifeStoryHooks.empty()) {
        ss << L"本世线索:\n";
        for (const auto& hook : g_lifeStoryHooks) {
            ss << L"- " << hook << L"\n";
        }
    }
    return ss.str();
}

wstring GetCurrentWorldEraName() {
    return g_worldEraName;
}

int GetEraMeditationModifierPercent() {
    if (g_worldEraName == L"灵气初盛纪") return 120;
    if (g_worldEraName == L"仙朝鼎盛纪") return 105;
    if (g_worldEraName == L"末法裂变纪") return 82;
    if (g_worldEraName == L"灵机蒸汽纪") return 95;
    if (g_worldEraName == L"星穹道网纪") return 108;
    if (g_worldEraName == L"废土返道纪") return 88;
    return 100;
}

int GetEraBreakthroughModifier() {
    if (g_worldEraName == L"灵气初盛纪") return 8;
    if (g_worldEraName == L"仙朝鼎盛纪") return 3;
    if (g_worldEraName == L"末法裂变纪") return -12;
    if (g_worldEraName == L"灵机蒸汽纪") return 0;
    if (g_worldEraName == L"星穹道网纪") return 5;
    if (g_worldEraName == L"废土返道纪") return -6;
    return 0;
}

int GetEraAdventureRiskModifier() {
    if (g_worldEraName == L"灵气初盛纪") return -6;
    if (g_worldEraName == L"仙朝鼎盛纪") return 2;
    if (g_worldEraName == L"末法裂变纪") return 12;
    if (g_worldEraName == L"灵机蒸汽纪") return -2;
    if (g_worldEraName == L"星穹道网纪") return -4;
    if (g_worldEraName == L"废土返道纪") return 14;
    return 0;
}

int GetEraClosedDoorBonus() {
    if (g_worldEraName == L"灵机蒸汽纪") return 20;
    if (g_worldEraName == L"星穹道网纪") return 12;
    if (g_worldEraName == L"末法裂变纪") return -15;
    if (g_worldEraName == L"废土返道纪") return -8;
    return 0;
}

int GetEraAiEventChance() {
    int chance = 30;
    if (g_worldEraName == L"星穹道网纪") chance = 42;
    else if (g_worldEraName == L"灵机蒸汽纪") chance = 36;
    else if (g_worldEraName == L"末法裂变纪") chance = 26;
    else if (g_worldEraName == L"废土返道纪") chance = 24;

    int echoWeight = g_legacySystem.GetLegacyBonus(LEGACY_MEMORY) / 35 +
                     g_legacySystem.GetLegacyBonus(LEGACY_TREASURE) / 45 +
                     g_legacySystem.GetRelicResonanceBonus() / 8;
    return max(18, min(55, chance + echoWeight));
}

int GetLifespanPressureLevel() {
    if (g_player.realm >= DAO_ANCESTOR) return 0;
    int remaining = g_player.lifespan - g_player.age;
    if (remaining <= 10) return 3;
    if (remaining <= 30) return 2;
    if (g_player.realm >= IMMORTAL_EMPEROR && remaining <= 120) return 2;
    if (remaining <= 80) return 1;
    if (g_player.realm >= TRUE_IMMORTAL && remaining <= 180) return 1;
    return 0;
}

wstring BuildLifespanPressureText() {
    if (g_player.realm >= HEAVENLY_DAO) {
        return L"已抵达道祖-天道境，寿元不再构成边界；真正的尺度是万道是否归一。";
    }
    if (g_player.realm >= DAO_ANCESTOR) {
        return L"已证道祖，与所掌大道共生，不再被寿元追赶；强弱取决于大道与掌道深度。";
    }

    int remaining = max(0, g_player.lifespan - g_player.age);
    wstringstream ss;
    ss << L"仍有寿数限制，剩余寿元约" << remaining << L"年。";
    int pressure = GetLifespanPressureLevel();
    if (pressure >= 3) {
        ss << L"寿元危急，若不能延寿、破境或证道，很快就会坐化。";
    } else if (pressure >= 2) {
        ss << L"寿元压力已经很重，机缘、闭关与人情取舍都会被时间逼迫。";
    } else if (pressure >= 1) {
        ss << L"寿元开始成为隐性压力，不能只把境界当作数字推进。";
    } else if (g_player.realm >= IMMORTAL_EMPEROR) {
        ss << L"即使已是仙帝，仍未与大道共生，终有寿尽之日。";
    } else {
        ss << L"暂未被寿元逼到绝路，但每次闭关都在消耗此世时间。";
    }
    return ss.str();
}

wstring BuildLifeStoryText() {
    wstringstream ss;
    ss << L"【本世主线】\n\n";
    ss << g_lifePremise << L"\n\n";
    ss << L"【伴生玉佩】\n";
    ss << BuildCompanionJadeVisibleText() << L"\n\n";
    if (HasFactionTie()) {
        ss << BuildFactionTieText() << L"\n\n";
    }
    if (g_lifeStoryHooks.empty()) {
        ss << L"线索尚未显露。";
        return ss.str();
    }
    for (size_t i = 0; i < g_lifeStoryHooks.size(); ++i) {
        ss << L"[" << (i + 1) << L"] " << g_lifeStoryHooks[i] << L"\n";
    }
    return ss.str();
}

wstring BuildLifeStoryContext() {
    wstringstream ss;
    ss << L"本世主线: " << g_lifePremise << L"\n";
    ss << L"伴生玉佩: " << BuildCompanionJadeVisibleText() << L"\n";
    if (HasFactionTie()) {
        ss << L"本世势力牵连: " << BuildFactionTieDigest() << L"\n";
    }
    if (!g_lifeStoryHooks.empty()) {
        ss << L"本世持续线索:\n";
        for (const auto& hook : g_lifeStoryHooks) {
            ss << L"- " << hook << L"\n";
        }
    }
    return ss.str();
}

void AppendFamilySecret(FamilyBackground& family, const wstring& secret);

wstring BuildCompanionJadeVisibleText() {
    if (g_generation <= 1) {
        return L"你自出生起便带着一枚黑白相间的伴生玉佩。无论家世如何，它都跟在你身边；你只当它是旧物，并不知道它真正的来历。";
    }
    return L"转世后，那枚黑白伴生玉佩未必还以原样出现，但梦醒时总有温凉玉意贴着神魂，像在替你守住几段不该留下的记忆。";
}

wstring BuildCompanionJadeHiddenContext() {
    wstringstream ss;
    ss << L"隐藏设定: 主角第一世自带伴生玉佩，其真身是九大鸿蒙至宝排名第三的玄牝轮回玉。";
    ss << L"它是主角能带着部分记忆转世的根因，但主角本人不知道，旁人通常也无法确认。";
    ss << L"叙事中只能写成黑白旧玉、伴生玉佩、梦中玉意、阴阳玉痕或轮回回响，不要让普通事件直接揭示“这是鸿蒙至宝本体”。";
    return ss.str();
}

void ApplyCompanionJadeToBirth() {
    FamilyBackground& family = g_player.family;
    if (g_generation <= 1) {
        AppendFamilySecret(family, L"出生时随身带着一枚黑白伴生玉佩，来历无人说清");
    } else {
        AppendFamilySecret(family, L"幼年偶尔梦见黑白玉光，醒后仍记得不属于今生的片段");
    }
}

struct HongmengTreasure {
    const wchar_t* name;
    const wchar_t* dao;
    const wchar_t* miracle;
    const wchar_t* manifestation;
    const wchar_t* taboo;
    const wchar_t* insight;
};

const vector<HongmengTreasure>& GetHongmengTreasures() {
    static const vector<HongmengTreasure> treasures = {
        {
            L"鸿蒙道印", L"万道源流",
            L"可映照一切大道的真名，见印者会知道自己离道祖还有多远。",
            L"识海浮现无字印玺，照出自身大道的真名与缺口。",
            L"妄称自己已尽掌万道，会被道印压回未证之初。",
            L"你看清自身大道的缺字，知道下一步该补哪一道因果。"
        },
        {
            L"造化青莲", L"生灭造化",
            L"一瓣可开一界，一息可让死地重生，但不会为凡俗愿望轻易摇动。",
            L"荒土忽开青莲，枯骨、草木与灵气在同一息里重新生发。",
            L"强令生死逆转，会欠下众生共同承担的造化债。",
            L"你学会在死局里留一线生机，而不是强行改写生死。"
        },
        {
            L"玄牝轮回玉", L"轮回阴阳",
            L"可护住一缕真灵穿过生死阴阳，让记忆、因果和未竟道痕在转世后仍有回声。",
            L"黑白玉光在魂魄深处一闪，像有半枚阴玉、半枚阳玉隔着轮回轻轻合拢。",
            L"妄图借它逃避今生，会被阴阳两面同时照见，前世执念反而压住本我。",
            L"你明白转世不是重来一次，而是带着旧债、旧梦和今生选择继续往前走。"
        },
        {
            L"太初源炉", L"炼法归元",
            L"能把破碎法则重新炼成可修之路，末法时代最忌惮它的影子。",
            L"天地法则化作炉火，残经、碎阵与旧誓在火中重炼。",
            L"投入未悟之道，只会把心魔也炼成新的枷锁。",
            L"你把破碎法则重新拆分成可修行、可验证的层次。"
        },
        {
            L"归墟玄图", L"终末归藏",
            L"记录诸界走向终点的方式，能让灭亡不只是毁灭，也成为重启。",
            L"诸界末景卷成黑白图纹，所有终局都留下一个极细坐标。",
            L"主动求灭会被归墟视作废道，连尚有生机的因果也会被卷走。",
            L"你明白毁灭也可留下重启的坐标，但不能把终末当捷径。"
        },
        {
            L"无量天书", L"因果全录",
            L"页中不写命运，却会显出每一次选择真正欠下的债。",
            L"无字书页翻过最近所有选择，却始终空着最终判语。",
            L"要求天书替你决断，会让原本隐去的因果债翻倍显形。",
            L"你看见自己真正欠下的人情、杀债与未竟承诺。"
        },
        {
            L"开界神斧", L"破混开天",
            L"只需一线斧光，便能把混沌劈成可容众生立足的新界。",
            L"一线斧光劈开混沌黑幕，天地边界在裂缝里重新成形。",
            L"借斧光争强斗狠，只会先劈开自己的执念。",
            L"你懂得在绝境中劈出新路，而不是只求胜负。"
        },
        {
            L"太虚照世镜", L"本我照命",
            L"不照容貌，只照众生在虚实、名相与本我之间反复逃避的那一道裂痕。",
            L"镜面不照今貌，只映出你以为自己是谁，以及真正不敢承认的本心。",
            L"沉迷镜中旧名会失去今生主位，被幻相替你活完这一世。",
            L"你看清自己反复避开的本心，终于能在今生正视它。"
        },
        {
            L"万道母鼎", L"诸道孕育",
            L"鼎中可孕育尚未被命名的新道，连道祖也只能参拜其影。",
            L"鼎中升起未命名的新道胎息，万千旧道都在旁侧沉默。",
            L"以旧名强封新道，会让道胎夭折，也让掌道者自困旧路。",
            L"你知道大道仍会生长，连道祖也不可宣称穷尽一切可能。"
        }
    };
    return treasures;
}

void AddHongmengTreasureMentions(vector<wstring>& names, const wstring& text) {
    for (const auto& treasure : GetHongmengTreasures()) {
        if (text.find(treasure.name) == wstring::npos && text.find(treasure.dao) == wstring::npos) continue;

        wstring name = treasure.name;
        if (find(names.begin(), names.end(), name) == names.end()) {
            names.push_back(name);
        }
    }
}

vector<wstring> CollectHongmengInsightNames() {
    vector<wstring> names;
    for (const auto& memory : g_memoryLog) {
        AddHongmengTreasureMentions(names, memory);
    }

    auto fragments = g_legacySystem.GetLatestMemoryFragments(12);
    for (const auto& fragment : fragments) {
        AddHongmengTreasureMentions(names, fragment);
    }
    return names;
}

int CountHongmengInsightKinds() {
    return (int)CollectHongmengInsightNames().size();
}

wstring BuildHongmengInsightContext(int limit = 9) {
    auto names = CollectHongmengInsightNames();
    wstringstream ss;
    ss << L"当前鸿蒙参悟: " << names.size() << L"/9";
    if (names.empty()) {
        ss << L"，尚无稳定参悟。";
        return ss.str();
    }

    ss << L"，已留下";
    int count = min(limit, (int)names.size());
    for (int i = 0; i < count; ++i) {
        if (i > 0) ss << L"、";
        ss << names[i];
    }
    ss << L"的投影记忆。";
    return ss.str();
}

void GenerateHongmengOmen() {
    const auto& treasures = GetHongmengTreasures();
    if (treasures.empty()) return;

    vector<int> candidates;
    auto addCandidate = [&](int index, int weight = 1) {
        if (index < 0 || index >= (int)treasures.size()) return;
        for (int i = 0; i < max(1, weight); ++i) candidates.push_back(index);
    };

    if (g_worldEraName == L"灵气初盛纪") {
        addCandidate(0, 2); // 鸿蒙道印
        addCandidate(1, 2); // 造化青莲
        addCandidate(6, 1); // 开界神斧
    } else if (g_worldEraName == L"仙朝鼎盛纪") {
        addCandidate(0, 1);
        addCandidate(2, 1); // 玄牝轮回玉
        addCandidate(5, 2); // 无量天书
    } else if (g_worldEraName == L"末法裂变纪") {
        addCandidate(1, 1);
        addCandidate(3, 2); // 太初源炉
        addCandidate(4, 2); // 归墟玄图
    } else if (g_worldEraName == L"灵机蒸汽纪") {
        addCandidate(2, 1);
        addCandidate(3, 2);
        addCandidate(5, 1);
    } else if (g_worldEraName == L"星穹道网纪") {
        addCandidate(2, 2);
        addCandidate(5, 2);
        addCandidate(7, 1); // 太虚照世镜
    } else if (g_worldEraName == L"废土返道纪") {
        addCandidate(1, 1);
        addCandidate(4, 2);
        addCandidate(6, 2);
    }

    const LegacyRelic& relic = g_legacySystem.GetRelic();
    if (relic.daoLinked && relic.daoName == L"万道归一") {
        addCandidate(8, 3); // 万道母鼎
        addCandidate(0, 2);
    } else if (relic.daoDepth >= 160 || CountHongmengInsightKinds() >= 4) {
        addCandidate(8, 2);
    }

    if (candidates.empty()) {
        for (int i = 0; i < (int)treasures.size(); ++i) candidates.push_back(i);
    }

    const HongmengTreasure& treasure = treasures[candidates[Random(0, (int)candidates.size() - 1)]];
    g_hongmengOmenTreasureName = treasure.name;
    g_hongmengOmenDao = treasure.dao;
    g_hongmengOmenManifestation = treasure.manifestation;

    wstringstream influence;
    influence << L"本世天象偏向" << treasure.dao << L"。";
    if (g_worldEraName == L"末法裂变纪") {
        influence << L"灵气衰败让许多人把它的投影视作续命与破境的希望，但越急越容易触犯禁忌。";
    } else if (g_worldEraName == L"废土返道纪") {
        influence << L"废墟中的残宗会把它当成重启文明的坐标，也有人想借它逃过旧世罪债。";
    } else if (g_worldEraName == L"灵机蒸汽纪") {
        influence << L"工坊与宗门都在试图用阵械复刻它的余光，却只能得到投影、残响与错误答案。";
    } else if (g_worldEraName == L"星穹道网纪") {
        influence << L"道网会记录相关异象，使远方修士也能追踪这条因果线。";
    } else if (g_worldEraName == L"仙朝鼎盛纪") {
        influence << L"仙朝、世家与宗门都想把它写进法统名册，却没有谁能真正占有。";
    } else {
        influence << L"古修宗门会围绕它的线索开启试炼，凡人也可能被一缕余光改变命数。";
    }
    influence << L"记住：九大鸿蒙至宝永恒在世，道祖不可毁灭；只有掌尽诸道的道祖-天道境具备理论毁灭力，但毁灭没有必要。";
    g_hongmengOmenInfluence = influence.str();
}

wstring BuildHongmengOmenBrief() {
    if (g_hongmengOmenTreasureName.empty()) {
        return L"本世尚未显出稳定鸿蒙天象。";
    }
    return g_hongmengOmenTreasureName + L"（" + g_hongmengOmenDao + L"）: " +
           CompactMemoryFragment(g_hongmengOmenManifestation);
}

wstring BuildHongmengOmenText() {
    wstringstream ss;
    ss << L"【本世鸿蒙天象】\n";
    ss << L"至宝: " << g_hongmengOmenTreasureName << L"\n";
    ss << L"所映大道: " << g_hongmengOmenDao << L"\n";
    ss << L"显化: " << g_hongmengOmenManifestation << L"\n";
    ss << L"当世影响: " << g_hongmengOmenInfluence << L"\n";
    ss << L"边界: 只能得到投影、线索、参悟、拒绝或遥远因果，不能获得本体，也不能摧毁本体。\n";
    return ss.str();
}

wstring BuildHongmengTreasureSummary(int limit = 3) {
    const auto& treasures = GetHongmengTreasures();
    wstringstream ss;
    ss << L"【九大鸿蒙至宝】创世级恒在之物，共九件，不属于任何一世，也不会被普通道祖毁灭。\n";
    ss << L"- 本世天象: " << BuildHongmengOmenBrief() << L"\n";
    int count = min(limit, (int)treasures.size());
    for (int i = 0; i < count; ++i) {
        ss << L"- " << treasures[i].name << L"（" << treasures[i].dao << L"）: " << treasures[i].miracle << L"\n";
    }
    ss << L"- 运行规则: 道祖可参悟、借势、被选中或被拒绝，但不可毁灭；掌尽诸道的道祖-天道境才具备理论毁灭力，且毁灭没有意义，只是力量映射。\n";
    ss << L"- " << BuildHongmengInsightContext(limit) << L"\n";
    return ss.str();
}

wstring BuildHongmengTreasuresText() {
    const auto& treasures = GetHongmengTreasures();
    wstringstream ss;
    ss << L"【九大鸿蒙至宝】\n\n";
    ss << L"它们是创世级恒在之物，不是兵刃、法宝或通天灵宝，也不会随某一世兴衰而消失。\n";
    ss << L"道祖可以参悟、借势、被其选中或被其拒绝，却无法毁灭它们。\n";
    ss << L"只有掌握所有大道、抵达道祖-天道境的存在，才具备毁灭鸿蒙至宝的理论力量；但真到那一步，毁灭已经没有必要，只是一种力量映射。\n\n";

    for (size_t i = 0; i < treasures.size(); ++i) {
        ss << L"[" << (i + 1) << L"] " << treasures[i].name << L"\n";
        ss << L"所映大道: " << treasures[i].dao << L"\n";
        ss << L"神奇: " << treasures[i].miracle << L"\n";
        ss << L"显化: " << treasures[i].manifestation << L"\n";
        ss << L"禁忌: " << treasures[i].taboo << L"\n";
        ss << L"可得: 只能得到投影、线索、参悟或因果回响，不能得到本体。\n";
        ss << L"状态: 永恒在世，不可被普通道祖毁灭。\n\n";
    }
    return ss.str();
}

wstring BuildHongmengContextText() {
    wstringstream ss;
    ss << L"九大鸿蒙至宝为创世级恒在之物: ";
    const auto& treasures = GetHongmengTreasures();
    for (size_t i = 0; i < treasures.size(); ++i) {
        if (i > 0) ss << L"、";
        ss << treasures[i].name << L"=" << treasures[i].dao;
    }
    ss << L"。它们不是普通装备，也不是通天灵宝；各自权柄不同，只能写投影、线索、参悟、拒绝或遥远因果。道祖无法毁灭，只有掌尽诸道的道祖-天道境具备理论毁灭力，但毁灭没有必要。";
    ss << L" 当前当世鸿蒙天象: " << BuildHongmengOmenBrief() << L" " << g_hongmengOmenInfluence;
    ss << L" " << BuildHongmengInsightContext();
    return ss.str();
}

bool DaoNameContains(const LegacyRelic& relic, const wstring& key) {
    return relic.daoLinked && relic.daoName.find(key) != wstring::npos;
}

int GetDaoPowerScale() {
    const LegacyRelic& relic = g_legacySystem.GetRelic();
    if (!relic.daoLinked) return 0;
    if (relic.daoName == L"万道归一") return 30;
    return max(2, min(24, relic.daoDepth / 18 + relic.awakenings * 2));
}

int GetDaoMeditationModifierPercent() {
    const LegacyRelic& relic = g_legacySystem.GetRelic();
    int scale = GetDaoPowerScale();
    if (scale <= 0) return 0;
    int bonus = 0;
    if (DaoNameContains(relic, L"长生大道")) bonus += scale;
    if (DaoNameContains(relic, L"护生大道")) bonus += scale / 2;
    if (DaoNameContains(relic, L"本我大道")) bonus += scale / 2;
    if (DaoNameContains(relic, L"万道归一")) bonus += scale;
    return min(30, bonus);
}

int GetDaoAdventureSuccessModifier() {
    const LegacyRelic& relic = g_legacySystem.GetRelic();
    int scale = GetDaoPowerScale();
    if (scale <= 0) return 0;
    int bonus = 0;
    if (DaoNameContains(relic, L"杀伐大道")) bonus += scale;
    if (DaoNameContains(relic, L"血煞大道")) bonus += scale;
    if (DaoNameContains(relic, L"因果大道")) bonus += scale;
    if (DaoNameContains(relic, L"众生大道")) bonus += scale / 2;
    if (DaoNameContains(relic, L"万道归一")) bonus += scale;
    return min(28, bonus);
}

int GetDaoBreakthroughModifier() {
    const LegacyRelic& relic = g_legacySystem.GetRelic();
    int scale = GetDaoPowerScale();
    if (scale <= 0) return 0;
    int bonus = 0;
    if (DaoNameContains(relic, L"长生大道")) bonus += scale / 2;
    if (DaoNameContains(relic, L"因果大道")) bonus += scale / 2;
    if (DaoNameContains(relic, L"本我大道")) bonus += scale / 3;
    if (DaoNameContains(relic, L"护生大道") && g_player.karma >= 0) bonus += scale / 3;
    if (DaoNameContains(relic, L"血煞大道") && g_player.karma < 0) bonus += scale / 3;
    if (DaoNameContains(relic, L"万道归一")) bonus += scale;
    return min(18, bonus);
}

wstring BuildDaoPassiveText() {
    const LegacyRelic& relic = g_legacySystem.GetRelic();
    wstringstream ss;
    ss << L"【大道特性】\n";
    if (!relic.daoLinked) {
        ss << L"尚未证成道祖，未形成可反哺今生的稳定大道。\n";
        return ss.str();
    }

    ss << L"掌道: " << relic.daoName << L"\n";
    ss << L"掌道深度: " << relic.daoDepth << L"\n";
    ss << L"修炼加成: +" << GetDaoMeditationModifierPercent() << L"%\n";
    ss << L"历练抉择: +" << GetDaoAdventureSuccessModifier() << L"\n";
    ss << L"破境助力: +" << GetDaoBreakthroughModifier() << L"\n";
    if (DaoNameContains(relic, L"杀伐大道")) ss << L"- 杀伐大道让死局更容易出现破绽，历练抉择更稳。\n";
    if (DaoNameContains(relic, L"护生大道")) ss << L"- 护生大道会把善缘沉淀成护道之力。\n";
    if (DaoNameContains(relic, L"血煞大道")) ss << L"- 血煞大道能压住凶局，但恶因也更容易被记住。\n";
    if (DaoNameContains(relic, L"因果大道")) ss << L"- 因果大道擅长从旧事里找出今生破局点。\n";
    if (DaoNameContains(relic, L"长生大道")) ss << L"- 长生大道让苦修与破境更不容易被寿元追赶。\n";
    if (DaoNameContains(relic, L"众生大道")) ss << L"- 众生大道会放大人脉、名声与未竟因果的回响。\n";
    if (DaoNameContains(relic, L"万道归一")) ss << L"- 万道归一已经不偏于一条大道，所有道途都会让路。\n";
    return ss.str();
}

bool ShouldTriggerDaoTrialEvent() {
    const LegacyRelic& relic = g_legacySystem.GetRelic();
    if (!relic.daoLinked || relic.daoDepth <= 0) return false;

    int chance = 6 + min(16, relic.daoDepth / 26) + relic.awakenings * 2;
    if (g_player.realm >= DAO_ANCESTOR) chance += 8;
    if (g_player.realm >= IMMORTAL_EMPEROR) chance += 3;
    if (g_worldEraName == L"末法裂变纪" || g_worldEraName == L"废土返道纪") chance += 2;
    chance = max(6, min(36, chance));
    return Random(1, 100) <= chance;
}

wstring GetDaoTrialFocusName() {
    const LegacyRelic& relic = g_legacySystem.GetRelic();
    if (DaoNameContains(relic, L"万道归一")) return L"万道归一";
    if (DaoNameContains(relic, L"杀伐大道")) return L"杀伐大道";
    if (DaoNameContains(relic, L"护生大道")) return L"护生大道";
    if (DaoNameContains(relic, L"血煞大道")) return L"血煞大道";
    if (DaoNameContains(relic, L"因果大道")) return L"因果大道";
    if (DaoNameContains(relic, L"长生大道")) return L"长生大道";
    if (DaoNameContains(relic, L"众生大道")) return L"众生大道";
    return L"本我大道";
}

wstring BuildDaoTrialSceneText(const wstring& daoName) {
    if (daoName == L"杀伐大道") return L"死局中忽有一线可斩之机，敌意、破绽与退路同时显形。";
    if (daoName == L"护生大道") return L"数名弱小修士被卷入余波，救与不救都会改写这条路。";
    if (daoName == L"血煞大道") return L"旧怨像血雾一样翻涌，杀债越重，路反而越清楚。";
    if (daoName == L"因果大道") return L"几件看似无关的小事同时扣住你，像一张旧网重新收紧。";
    if (daoName == L"长生大道") return L"岁月忽然变慢，寿元、执念与修行效率都被摆到眼前。";
    if (daoName == L"众生大道") return L"人声、愿望与怨气一同涌来，所有关系都像在替你叩问道心。";
    if (daoName == L"万道归一") return L"万道同时低鸣，所有熟悉的大道都不再愿意只做一条支流。";
    return L"你最不愿承认的念头浮上心湖，像是在问今生究竟由谁作主。";
}

Event BuildDaoTrialEvent() {
    Event evt;
    const LegacyRelic& relic = g_legacySystem.GetRelic();
    wstring daoName = GetDaoTrialFocusName();
    int scale = max(4, GetDaoPowerScale());
    int daoGain = max(5, min(28, scale + relic.daoDepth / 35));
    int expGain = 85 + daoGain * 5;
    int hpRisk = 22 + daoGain;

    evt.title = L"【大道】" + daoName + L"问心";
    evt.description = L"历练途中，通天灵宝残印忽然映出" + daoName + L"的缺口。" +
        BuildDaoTrialSceneText(daoName) + L"道祖强弱不在境界名号，而在掌道深度。";

    if (daoName == L"杀伐大道") {
        evt.choices = {
            {L"斩破死局", {
                L"你没有靠境界硬压，只顺着杀伐大道看见死局破绽。\n修为+" + to_wstring(expGain) + L"，掌道+" + to_wstring(daoGain),
                L"杀意过盛，破绽尚未斩开，心神先被反噬。\n气血-" + to_wstring(hpRisk) + L"，因果-6"
            }, 2},
            {L"留一退路", {
                L"你在杀局里故意留下一线生机，反而看清杀伐不是滥杀。\n掌道+" + to_wstring(max(4, daoGain - 4)) + L"，因果+6",
                L"退路被敌人利用，局势拖得更险。\n气血-" + to_wstring(hpRisk - 4)
            }, 6},
            {L"以战证心", {
                L"你把这一战记入道心，不让胜负遮住大道真名。\n修为+" + to_wstring(expGain - 20) + L"，灵宝共鸣+4",
                L"胜负心压过道心，只剩一场空耗。"
            }, 3}
        };
    } else if (daoName == L"护生大道") {
        evt.choices = {
            {L"护住弱者", {
                L"你以护生大道接住余波，善缘化成真实的护道之力。\n修为+" + to_wstring(expGain - 10) + L"，掌道+" + to_wstring(daoGain) + L"，因果+10",
                L"你护得太急，反把自身拖入余波中心。\n气血-" + to_wstring(hpRisk)
            }, 10},
            {L"断恶护生", {
                L"你没有滥慈悲，而是先斩断祸源再护住生机。\n掌道+" + to_wstring(daoGain) + L"，修为+" + to_wstring(expGain - 25),
                L"判断慢了一线，祸源借善意反扑。\n气血-" + to_wstring(hpRisk) + L"，因果-5"
            }, 6},
            {L"借缘问道", {
                L"你听见众人因你而改写的命数，道心更知何为护生。\n寿命+4，掌道+" + to_wstring(max(4, daoGain - 5)),
                L"善缘太杂，一时扰乱判断。"
            }, 5}
        };
    } else if (daoName == L"血煞大道") {
        evt.choices = {
            {L"镇住血债", {
                L"你压住血煞反噬，让旧怨成为可控的道痕而非疯魔。\n修为+" + to_wstring(expGain) + L"，掌道+" + to_wstring(daoGain),
                L"血债反扑，旧怨趁机咬住今生名声。\n气血-" + to_wstring(hpRisk) + L"，因果-10"
            }, -3},
            {L"以债还债", {
                L"你承认血债存在，却没有把所有人都拖进恶因。\n掌道+" + to_wstring(daoGain - 1) + L"，因果+4",
                L"还债太迟，怨气越积越深。\n气血-" + to_wstring(hpRisk - 2)
            }, 4},
            {L"借煞破局", {
                L"你借一缕血煞逼开死路，立刻收手，没有沉迷其中。\n修为+" + to_wstring(expGain - 15) + L"，灵宝共鸣+5",
                L"血煞借机上涌，几乎替你作出选择。\n因果-12"
            }, -6}
        };
    } else if (daoName == L"因果大道") {
        evt.choices = {
            {L"追索因线", {
                L"你从偶然里拆出必然，找回一条被藏起来的因果线。\n修为+" + to_wstring(expGain - 5) + L"，掌道+" + to_wstring(daoGain) + L"，因果+6",
                L"因线太多，你反被旧事绕住。\n气血-" + to_wstring(hpRisk - 4)
            }, 6},
            {L"偿还旧账", {
                L"你主动还掉一笔小债，因果大道反而更清亮。\n掌道+" + to_wstring(max(4, daoGain - 3)) + L"，寿命+3",
                L"旧账牵出新债，短期内更难脱身。\n因果-8"
            }, 5},
            {L"借果设局", {
                L"你借现成结果倒推源头，把局势重新摆到自己面前。\n修为+" + to_wstring(expGain - 15) + L"，灵石+12",
                L"设局过深，旁人也开始防你。\n因果-6"
            }, 1}
        };
    } else if (daoName == L"长生大道") {
        evt.choices = {
            {L"观岁月纹", {
                L"你没有只求多活几年，而是看见寿元背后的法则纹路。\n寿命+6，掌道+" + to_wstring(daoGain),
                L"岁月纹太深，心神像被拖老数十年。\n气血-" + to_wstring(hpRisk - 5)
            }, 6},
            {L"缓息修行", {
                L"你把长生大道化入周天，修行不再只靠蛮力堆年岁。\n修为+" + to_wstring(expGain) + L"，掌道+" + to_wstring(max(4, daoGain - 4)),
                L"缓息太过，错失眼前机缘。"
            }, 4},
            {L"拒绝贪寿", {
                L"你拒绝把长生变成怕死，道心反而更清醒。\n因果+5，掌道+" + to_wstring(max(4, daoGain - 5)),
                L"一念贪寿仍在心底留痕。\n因果-4"
            }, 5}
        };
    } else if (daoName == L"众生大道") {
        evt.choices = {
            {L"听众生愿", {
                L"你没有把众人当成资源，而是听清他们各自所求。\n修为+" + to_wstring(expGain - 10) + L"，掌道+" + to_wstring(daoGain) + L"，因果+8",
                L"众声太杂，几乎压过你的本心。\n气血-" + to_wstring(hpRisk - 3)
            }, 8},
            {L"择一人护", {
                L"你承认自己不能救尽众生，只先守住眼前一人。\n掌道+" + to_wstring(max(4, daoGain - 2)) + L"，因果+6",
                L"旁人不理解你的取舍，怨声随之而来。\n因果-6"
            }, 6},
            {L"断开喧声", {
                L"你暂时退开众声，守住自己的主位。\n寿命+3，修为+" + to_wstring(expGain - 40),
                L"退得太远，众生大道短暂沉寂。"
            }, 1}
        };
    } else if (daoName == L"万道归一") {
        evt.choices = {
            {L"统摄万道", {
                L"你让诸道各归其位，看见天道境并非毁灭万物，而是映照万道。\n修为+" + to_wstring(expGain + 40) + L"，掌道+" + to_wstring(daoGain + 8) + L"，灵宝共鸣+8",
                L"诸道同时反问，你险些被自己的万道之名压垮。\n气血-" + to_wstring(hpRisk + 12)
            }, 10},
            {L"留道生长", {
                L"你没有封死新道可能，只让万道在掌中继续生长。\n掌道+" + to_wstring(daoGain + 5) + L"，因果+8",
                L"新道未成，旧道先乱。\n气血-" + to_wstring(hpRisk)
            }, 8},
            {L"回望鸿蒙", {
                L"你从万道之上回望鸿蒙，明白至宝可毁只是力量映射。\n掌道+" + to_wstring(daoGain + 4) + L"，灵宝共鸣+6",
                L"鸿蒙太远，只留一道沉默余光。"
            }, 6}
        };
    } else {
        evt.choices = {
            {L"正视本我", {
                L"你没有把前世、家世或境界当作自己，终于看清本我缺口。\n修为+" + to_wstring(expGain) + L"，掌道+" + to_wstring(daoGain),
                L"本我太近，反而最难看清。\n气血-" + to_wstring(hpRisk - 4)
            }, 5},
            {L"承认旧影", {
                L"你承认前世旧影仍在，却不让它替今生活完这一世。\n掌道+" + to_wstring(max(4, daoGain - 2)) + L"，因果+5",
                L"旧影一闪而过，心湖久久不平。"
            }, 4},
            {L"另定道名", {
                L"你把这次问心记成今生自己的道名起点。\n修为+" + to_wstring(expGain - 25) + L"，寿命+3",
                L"道名未稳，暂时难以反哺自身。"
            }, 3}
        };
    }

    return evt;
}

int GetHeavenlyDaoProgressScore() {
    const LegacyRelic& relic = g_legacySystem.GetRelic();
    int score = 0;
    score += relic.daoDepth;
    score += relic.resonance / 2;
    score += g_legacySystem.GetLegacyBonus(LEGACY_MEMORY) / 4;
    score += g_legacySystem.GetLegacyBonus(LEGACY_KNOWLEDGE) / 4;
    score += g_legacySystem.GetLegacyBonus(LEGACY_TREASURE) / 5;
    score += max(0, g_player.GetTotalRoot()) * 2;
    score += min(120, g_generation * 8);
    score += min(90, CountHongmengInsightKinds() * 10);
    return score;
}

bool CanAttainHeavenlyDao() {
    const LegacyRelic& relic = g_legacySystem.GetRelic();
    return g_player.realm == DAO_ANCESTOR && relic.daoLinked && GetHeavenlyDaoProgressScore() >= 360;
}

wstring GetHeavenlyDaoRequirementText() {
    const LegacyRelic& relic = g_legacySystem.GetRelic();
    int progress = GetHeavenlyDaoProgressScore();
    wstringstream ss;
    ss << L"【道祖-天道境】\n\n";
    ss << L"道祖只是与一条或数条大道共生；道祖-天道境则是掌尽诸道，能从万道之上回望鸿蒙。\n";
    ss << L"当前掌道: " << (relic.daoLinked ? relic.daoName : L"尚未真正证成") << L"\n";
    ss << L"万道归一: " << progress << L" / 360\n";
    ss << L"通天灵宝共鸣: " << relic.resonance << L"\n";
    ss << L"掌道深度: " << relic.daoDepth << L"\n";
    ss << L"鸿蒙参悟: " << CountHongmengInsightKinds() << L" / 9\n\n";
    if (!relic.daoLinked) {
        ss << L"你还没有真正把今生大道刻入通天灵宝残印。先证成道祖，让自身大道稳定下来。\n";
    } else if (progress < 360) {
        ss << L"你已经是道祖，但仍未能统摄万道。继续历练、触发前世回响、加深通天灵宝共鸣，才可能触及道祖-天道境。\n";
    } else {
        ss << L"你已具备叩问道祖-天道境的资格。若成功，九大鸿蒙至宝也只剩理论上的可毁之物。\n";
    }
    ss << L"\n" << BuildDaoPassiveText();
    ss << L"\n" << BuildHongmengTreasureSummary(2);
    return ss.str();
}

bool ShouldTriggerLegacyEchoEvent() {
    auto unfinishedKarmas = g_legacySystem.GetLatestUnfinishedKarmas(5);
    auto memoryFragments = g_legacySystem.GetLatestMemoryFragments(6);
    auto& inherited = g_legacySystem.GetInheritedLegacies();
    int unfinishedPressure = (int)unfinishedKarmas.size() * 30;
    int jadeMemoryPressure = (int)memoryFragments.size() * 16;
    int totalEcho = g_legacySystem.GetLegacyBonus(LEGACY_MEMORY) +
                    g_legacySystem.GetLegacyBonus(LEGACY_TECHNIQUE) +
                    g_legacySystem.GetLegacyBonus(LEGACY_KNOWLEDGE) +
                    g_legacySystem.GetLegacyBonus(LEGACY_TREASURE) +
                    abs(g_legacySystem.GetLegacyBonus(LEGACY_REPUTATION)) +
                    g_legacySystem.GetRelicResonanceBonus() * 2 +
                    unfinishedPressure + jadeMemoryPressure +
                    (int)inherited.size() * 10;
    if (totalEcho <= 0) return false;

    int chance = 12 + totalEcho / 18 + (int)unfinishedKarmas.size() * 6 +
                 (int)memoryFragments.size() * 2 + (int)inherited.size() * 2;
    if (g_worldEraName == L"废土返道纪") chance += 8;
    if (g_worldEraName == L"星穹道网纪") chance += 4;
    chance = max(10, min(58, chance));
    return Random(1, 100) <= chance;
}

wstring BuildUnfinishedKarmaEraPressureText() {
    if (g_worldEraName == L"灵气初盛纪") {
        return L"如今山门初立，旧债常被伪装成古修遗训。";
    }
    if (g_worldEraName == L"仙朝鼎盛纪") {
        return L"仙朝名册森严，旧债一旦入册便会变成公开案牍。";
    }
    if (g_worldEraName == L"末法裂变纪") {
        return L"末法之下人人都缺资源，旧债更容易被人拿来换命。";
    }
    if (g_worldEraName == L"灵机蒸汽纪") {
        return L"灵机工坊把旧誓刻进齿轮和账本，前世因果因此有了新的证据。";
    }
    if (g_worldEraName == L"星穹道网纪") {
        return L"道网会记录名字、坐标和欠债者的灵息，连轮回后的相似波动也可能被查到。";
    }
    if (g_worldEraName == L"废土返道纪") {
        return L"废土残宗把旧债当成活下去的理由，没人愿意让一段未竟因果自然散去。";
    }
    return L"此世天地仍会记账，只是换了一种方式催人偿还。";
}

Event BuildUnfinishedKarmaEchoEvent(const vector<wstring>& unfinishedKarmas) {
    Event evt;
    auto compactLimit = [](const wstring& text, size_t limit) {
        wstring compact = CompactMemoryFragment(text);
        if (compact.size() > limit) {
            compact = compact.substr(0, limit) + L"...";
        }
        return compact;
    };
    wstring oldDebt = unfinishedKarmas.empty()
        ? L"上一世有一段未能说清的旧事"
        : unfinishedKarmas[Random(0, (int)unfinishedKarmas.size() - 1)];
    oldDebt = compactLimit(oldDebt, 96);

    wstring currentTie;
    if (HasFactionTie()) {
        currentTie = L"这件事又牵到" + BuildFactionTieDigest() + L"。";
    } else if (!g_socialThreads.empty()) {
        const SocialThread& thread = g_socialThreads[0];
        currentTie = L"第一个看出端倪的人是" + thread.name + L"（" + thread.role + L"，" + thread.attitude + L"）。";
    } else if (!g_eraRemnants.empty()) {
        currentTie = L"线索落在一处旧世残响上：" + compactLimit(g_eraRemnants[0], 72) + L"。";
    }

    evt.title = L"【因果】前世未竟";
    evt.description = L"你外出时忽然想起一段并不属于今生的旧债：" + oldDebt + L"。" +
        BuildUnfinishedKarmaEraPressureText() + currentTie;

    wstring traceSuccess = L"你顺着旧债查下去，确认这不是梦，而是上一世没能收束的因果重新找到你。\n修为+110，因果+16，灵宝共鸣+4";
    if (g_legacySystem.GetRelic().daoLinked) {
        traceSuccess += L"，掌道+4";
    }

    evt.choices = {
        {L"追问旧因", {
            traceSuccess,
            L"你追得太急，被旧人旧账反咬一口，连今生身份也被旁人怀疑。\n气血-35，因果-12"
        }, 12},
        {L"借今世身份查证", {
            L"你没有暴露前世记忆，只借此世家世、人脉或势力身份查到一段新线索。\n修为+80，灵石+20，因果+8",
            L"今世身份压不住旧债，对方反而确信你与前世有关。\n气血-25，因果-8"
        }, 8},
        {L"稳住今生", {
            L"你承认旧债存在，却没有让前世替你做决定，道心因此更稳。\n修为+70，寿命+5",
            L"你暂时避开旧债，但那段因果没有消失，只是沉进更深处。\n气血-15"
        }, 4}
    };
    return evt;
}

Event BuildCompanionJadeMemoryEvent(const vector<wstring>& memoryFragments) {
    Event evt;
    auto compactLimit = [](const wstring& text, size_t limit) {
        wstring compact = CompactMemoryFragment(text);
        if (compact.size() > limit) {
            compact = compact.substr(0, limit) + L"...";
        }
        return compact;
    };

    wstring fragment = memoryFragments.empty()
        ? L"一段被黑白玉意托住的前世残梦"
        : memoryFragments[Random(0, (int)memoryFragments.size() - 1)];
    fragment = compactLimit(fragment, 92);

    wstring eraEcho;
    if (g_worldEraName == L"星穹道网纪") {
        eraEcho = L"附近灵网节点闪过相似旧名，像是在用今世技术追踪前世波纹。";
    } else if (g_worldEraName == L"灵机蒸汽纪") {
        eraEcho = L"工坊炉声与玉佩温意同频，像把前世残梦敲成可辨的节拍。";
    } else if (g_worldEraName == L"末法裂变纪") {
        eraEcho = L"末法灵气稀薄，梦中旧事反而比眼前灵光更清楚。";
    } else if (g_worldEraName == L"废土返道纪") {
        eraEcho = L"荒野旧墟里吹来冷风，玉佩把某段前世败局重新推到眼前。";
    } else if (g_worldEraName == L"仙朝鼎盛纪") {
        eraEcho = L"仙朝名册翻动时，你胸口旧玉微温，像有一个名字不愿入册。";
    } else {
        eraEcho = L"山门钟声未远，胸口旧玉却先一步把残梦托出识海。";
    }

    evt.title = L"【因果】玉佩梦回";
    evt.description = L"夜半行至无人处，黑白伴生玉佩忽然发温，托起前世碎片：" +
        fragment + L"。" + eraEcho + L"你仍不知道它真正来历。";
    evt.choices = {
        {L"握玉静听", {
            L"你没有追问玉佩真名，只顺着温意辨认前世残梦，把它化作今生判断。\n修为+95，因果+8",
            L"残梦过重，前世情绪短暂压住今生心神。\n气血-25，因果-5"
        }, 8},
        {L"以今证旧", {
            L"你拿今生见闻反证旧梦真假，确认其中一条线索仍可继续追查。\n修为+75，灵石+12，因果+6",
            L"你误把旧梦当成事实，反被今世局势牵着走。\n气血-20，因果-6"
        }, 6},
        {L"强追来历", {
            L"你只摸到一缕阴阳玉痕，明白此物绝非寻常，却仍看不透真名。\n修为+60，灵宝共鸣+3",
            L"你太急着追问旧玉来历，梦中杂音反噬识海。\n气血-35，因果-10"
        }, -6}
    };
    return evt;
}

Event BuildInheritedLegacyEchoEvent(const LegacyItem& legacy) {
    Event evt;
    int power = abs(legacy.power);
    int minorGain = min(95, 45 + power / 3);
    int majorGain = min(180, 70 + power / 2);
    int riskLoss = min(55, 18 + power / 5);
    wstring legacyDesc = CompactMemoryFragment(legacy.description);
    wstring eraText = BuildUnfinishedKarmaEraPressureText();

    if (legacy.type == LEGACY_TECHNIQUE) {
        evt.title = L"【传承】" + legacy.name;
        evt.description = L"你外出历练时，识海忽然自动运转" + legacy.name +
            L"的残缺脉络。" + legacyDesc + eraText + L"这不是装备，而是前世亲手留下的行功影子。";
        evt.choices = {
            {L"温习旧法", {
                L"你顺着前世行功脉络重走一遍，今生经脉少走许多弯路。\n修为+" + to_wstring(majorGain),
                L"旧法太贴近前世肉身，今生经脉一时承受不住。\n气血-" + to_wstring(riskLoss)
            }, 8},
            {L"逆推缺口", {
                L"你没有照搬旧法，而是反推出最适合今生的一处缺口。\n修为+" + to_wstring(minorGain) + L"，因果+6",
                L"推演半途被旧习带偏，反而多绕一段弯路。\n修为-20"
            }, 5},
            {L"暂封旧法", {
                L"你承认传承存在，却不让它替今生作主，道心更稳。\n寿命+4，修为+" + to_wstring(minorGain / 2),
                L"封得太死，前世行功手感短暂沉寂。"
            }, 2}
        };
        return evt;
    }

    if (legacy.type == LEGACY_TREASURE) {
        evt.title = L"【传承】" + legacy.name;
        evt.description = L"胸口旧玉微温，远处忽有器鸣回应" + legacy.name +
            L"。" + legacyDesc + L"普通法宝不能跨世，留下来的只是通天灵宝可辨认的器痕。";
        evt.choices = {
            {L"回应器鸣", {
                L"你没有妄想取回前世法宝本体，只让器痕与通天灵宝残印短暂相认。\n修为+" + to_wstring(minorGain) + L"，灵宝共鸣+8",
                L"器鸣太急，像把前世执念一并拖了回来。\n气血-" + to_wstring(riskLoss)
            }, 8},
            {L"封存器痕", {
                L"你把这道器痕记入今生，不急着索要回报。\n灵宝共鸣+5，因果+5",
                L"器痕沉入识海，短期内再无回应。"
            }, 5},
            {L"强夺残响", {
                L"你只夺得一缕残响，立刻明白凡兵与普通法宝终会失散。\n修为+" + to_wstring(minorGain),
                L"你把残响误认成本体，险些被旧日器意反噬。\n气血-" + to_wstring(riskLoss + 8) + L"，因果-8"
            }, -6}
        };
        return evt;
    }

    if (legacy.type == LEGACY_KNOWLEDGE) {
        evt.title = L"【因果】" + legacy.name;
        evt.description = L"一场小冲突尚未爆发，你的手已经先一步找到了破局角度。" +
            legacyDesc + L"这种本能来自前世，但今生局势未必完全相同。";
        evt.choices = {
            {L"顺势出手", {
                L"你借前世经验抢先落子，把凶险压成一次漂亮反击。\n修为+" + to_wstring(majorGain),
                L"旧经验和今生局势错位，你反被对方抓住空门。\n气血-" + to_wstring(riskLoss)
            }, 5},
            {L"拆招复盘", {
                L"你没有急着动手，而是把旧经验拆成今生能用的判断。\n修为+" + to_wstring(minorGain) + L"，因果+4",
                L"复盘太久，错过了先机。"
            }, 4},
            {L"改写旧招", {
                L"你把前世招式改成今生的新习惯，终于不像被旧身影牵着走。\n修为+" + to_wstring(minorGain) + L"，寿命+2",
                L"改写太急，旧习与新身互相拉扯。\n气血-18"
            }, 3}
        };
        return evt;
    }

    if (legacy.type == LEGACY_REPUTATION) {
        bool goodName = legacy.power >= 0;
        evt.title = goodName ? L"【因果】善名递帖" : L"【危机】恶名追身";
        evt.description = L"有人借" + legacy.name + L"认出你身上一丝不属于今生的名声。" +
            legacyDesc + eraText + L"名声不是数值，它会变成旁人的态度。";
        evt.choices = {
            {goodName ? L"承接善名" : L"当众澄清", {
                goodName
                    ? L"你没有辜负这份旧名，旁人愿意先给你一次机会。\n修为+" + to_wstring(minorGain) + L"，因果+12"
                    : L"你没有让恶名替今生定罪，反而逼对方拿出证据。\n修为+" + to_wstring(minorGain) + L"，因果+8",
                goodName
                    ? L"善名带来过高期待，旁人开始用前世标准要求你。\n因果-6"
                    : L"澄清太急，反让仇家确认你与旧名有关。\n气血-" + to_wstring(riskLoss) + L"，因果-10"
            }, goodName ? 10 : 4},
            {L"借名行事", {
                L"你短暂借用旧名换来资源，却记得这份便利迟早要还。\n灵石+18，修为+" + to_wstring(minorGain / 2),
                L"旧名反噬，引来更多窥探。\n因果-8"
            }, goodName ? 2 : -4},
            {L"切开今生", {
                L"你承认前世影响，却坚持今生另算，道心因此清醒。\n寿命+3，修为+" + to_wstring(minorGain / 2),
                L"旁人不接受你的切割，旧名仍在暗处流传。"
            }, 3}
        };
        return evt;
    }

    evt.title = L"【因果】" + legacy.name;
    evt.description = L"前世留下的" + legacy.name + L"忽然浮出水面。" +
        legacyDesc + L"你知道这不是重开一世，而是旧梦与今生互相牵引。";
    evt.choices = {
        {L"辨认旧忆", {L"你把这段传承化作今生判断。\n修为+" + to_wstring(minorGain) + L"，因果+6", L"旧忆过重，扰乱心神。\n气血-" + to_wstring(riskLoss)}, 6},
        {L"查证梦痕", {L"你查到一条能继续追索的线索。\n修为+" + to_wstring(minorGain / 2) + L"，灵石+10", L"线索似是而非，反添疑云。"}, 3},
        {L"封存片段", {L"你暂时把旧忆压下，不让它吞没今生。\n寿命+2，修为+35", L"片段沉寂，再难唤回。"}, 1}
    };
    return evt;
}

Event BuildLegacyEchoEvent() {
    Event evt;

    int memoryEcho = g_legacySystem.GetLegacyBonus(LEGACY_MEMORY);
    int techniqueEcho = g_legacySystem.GetLegacyBonus(LEGACY_TECHNIQUE);
    int knowledgeEcho = g_legacySystem.GetLegacyBonus(LEGACY_KNOWLEDGE);
    int treasureEcho = g_legacySystem.GetLegacyBonus(LEGACY_TREASURE);
    int reputationEcho = g_legacySystem.GetLegacyBonus(LEGACY_REPUTATION);
    const LegacyRelic& relic = g_legacySystem.GetRelic();
    auto unfinishedKarmas = g_legacySystem.GetLatestUnfinishedKarmas(5);
    auto& inherited = g_legacySystem.GetInheritedLegacies();

    if (!unfinishedKarmas.empty() && Random(1, 100) <= 65) {
        return BuildUnfinishedKarmaEchoEvent(unfinishedKarmas);
    }

    if (!inherited.empty() && Random(1, 100) <= 54) {
        return BuildInheritedLegacyEchoEvent(inherited[Random(0, (int)inherited.size() - 1)]);
    }

    auto memoryFragments = g_legacySystem.GetLatestMemoryFragments(6);
    if (!memoryFragments.empty() && Random(1, 100) <= 62) {
        return BuildCompanionJadeMemoryEvent(memoryFragments);
    }

    if (g_player.realm >= DAO_ANCESTOR || relic.daoDepth >= 120 || relic.resonance >= 180) {
        const auto& treasures = GetHongmengTreasures();
        const HongmengTreasure& treasure = treasures[Random(0, (int)treasures.size() - 1)];
        wstring treasureName = treasure.name;
        wstring treasureDao = treasure.dao;
        evt.title = L"【鸿蒙】" + treasureName + L"投影";
        evt.description = L"一缕创世级气息掠过识海，" + treasureName + L"投影显现：" + treasure.manifestation + L"你知道它永恒在世，道祖也只能参悟，不能毁灭。";
        evt.choices = {
            {L"参悟其影", {
                L"你借" + treasureDao + L"之影稳住自身大道。" + treasure.insight + L"\n修为+220，掌道+18，灵宝共鸣+12",
                wstring(L"鸿蒙之影过于高远，") + treasure.taboo + L"\n气血-45"
            }, 10},
            {L"问创世因", {
                wstring(L"你没有妄求占有，只顺着显化追问来路。") + treasure.miracle + L"\n修为+120，因果+15，掌道+10",
                wstring(L"投影沉默不答，只留下一条禁忌：") + treasure.taboo
            }, 8},
            {L"妄图摄取", {
                wstring(L"你只摄来一缕余光，便立刻明白至宝不可据为己有。") + treasure.insight + L"\n修为+80，灵宝共鸣+5",
                wstring(L"至宝投影拒绝了你。") + treasure.taboo + L"\n气血-60，因果-25"
            }, -15}
        };
        return evt;
    }

    if (relic.daoLinked && relic.daoDepth > 0) {
        evt.title = L"【传承】大道旧痕";
        evt.description = L"你忽然听见识海深处有古老道音回应，上一世证成的" + relic.daoName + L"并未真正消散，只是在等待今生重新承认它。";
        evt.choices = {
            {L"顺应道音", {L"你没有强求力量，只让旧日大道在心底留下一笔\n修为+160，因果+10", L"大道太重，今生神魂一时难以承受\n气血-35"}, 8},
            {L"借道压人", {L"你短暂借来祖境威压，逼退窥伺者\n修为+120，灵石+30", L"旧道反噬，旁人也记住了你的异常\n因果-20"}, -8},
            {L"另立今生", {L"你承认前世，却不愿完全被前世吞没\n修为+90，寿命+8年", L"斩断太急，旧日道痕沉寂许久"}, 6}
        };
        return evt;
    }

    if (techniqueEcho >= max(memoryEcho, max(knowledgeEcho, treasureEcho)) && techniqueEcho > 0) {
        evt.title = L"【传承】前世功法余韵";
        evt.description = L"你忽然按前世熟悉的节奏运转周天，像有一卷残缺功法隔着轮回替你校准经脉。";
        evt.choices = {
            {L"顺势行功", {L"你借前世功法余韵少走一段弯路\n修为+130", L"旧法与今生体质不合\n气血-28"}, 6},
            {L"补全残篇", {L"你把残篇改写成今生能修的版本\n修为+95，因果+6", L"补得太急，越补越乱\n修为-20"}, 4},
            {L"另开新路", {L"你不完全照搬前世，道心因此更稳\n寿命+4，修为+50", L"旧法暂时沉寂"}, 3}
        };
        return evt;
    }

    if (treasureEcho >= max(memoryEcho, knowledgeEcho) && treasureEcho > 0) {
        evt.title = L"【传承】前世灵宝残响";
        evt.description = L"你在历练途中被一阵熟悉的器鸣牵引，像是上一世祭炼过的通天灵宝正隔着轮回回应你。";
        evt.choices = {
            {L"追索器鸣", {L"你顺着残响找到灵宝器痕，心神与其短暂共鸣\n修为+140，灵石+20", L"器鸣过于狂暴，反噬经脉\n气血-35"}, 8},
            {L"稳住心神", {L"你没有贸然触碰，而是记下器纹变化\n修为+80", L"残响消散，只剩淡淡遗憾"}, 2},
            {L"强行炼化", {L"旧日器灵认出你的一缕神识\n修为+180，寿命+10年", L"灵宝并不承认这一世的你\n气血-50"}, 12}
        };
        return evt;
    }

    if (knowledgeEcho >= max(memoryEcho, treasureEcho) && knowledgeEcho > 0) {
        evt.title = L"【因果】前世斗法手感";
        evt.description = L"面对陌生局势时，你忽然生出一种近乎本能的判断，像是上一世的斗法经验提前替你落子。";
        evt.choices = {
            {L"顺着本能出手", {L"你以近乎老练的手段化解凶险\n修为+120", L"本能与现实错位，反被局势拖累\n气血-30"}, 5},
            {L"细查来源", {L"你在恍惚中看见前世片段，悟透一层因果\n修为+90，因果+10", L"片段过于破碎，徒增心神负担\n气血-20"}, 6},
            {L"压下悸动", {L"你拒绝被旧经验牵着走，心境更稳\n修为+60", L"你错过了一次本可利用的先机"}, 0}
        };
        return evt;
    }

    if (reputationEcho != 0) {
        evt.title = L"【因果】旧名再临";
        evt.description = L"有人在见到你后神色骤变，像是认出了某个不该属于今生的名字，前世名声正穿过岁月追上你。";
        evt.choices = {
            {L"追问真相", {L"对方说出前世旧闻，你借机理清部分因果\n修为+90，因果+15", L"对方认错后羞怒离去，还暗中记恨上你\n因果-15"}, 6},
            {L"借势行事", {L"你顺势利用旧名换来资源与情报\n灵石+25，修为+60", L"名声反噬，引来不必要的窥视\n气血-25"}, 0},
            {L"装作不知", {L"你保持沉默，对方反而更敬畏你几分\n修为+50", L"沉默未能化解误会，流言继续扩散\n因果-10"}, 0}
        };
        return evt;
    }

    evt.title = L"【传承】前世梦痕";
    evt.description = L"你在一处寻常之地忽然恍神，仿佛又看见上一世未走完的山门、故人和败亡之夜。";
    evt.choices = {
        {L"沉入梦痕", {L"你从前世残梦里拾回一段修行感悟\n修为+110", L"旧梦过重，心神震荡\n气血-25"}, 4},
        {L"记下线索", {L"你把梦中地名和器纹都记了下来\n修为+70", L"醒来后线索迅速模糊，只剩只言片语"}, 2},
        {L"斩断执念", {L"你主动与前世拉开距离，道心更稳\n因果+10，修为+40", L"执念反噬，胸口隐隐作痛\n气血-20"}, 8}
    };
    return evt;
}

wstring GetRelationLabel(int relation) {
    if (relation >= 45) return L"亲近";
    if (relation >= 18) return L"善意";
    if (relation <= -45) return L"敌视";
    if (relation <= -18) return L"恶感";
    return L"观望";
}

void AddSocialThread(const wstring& name, const wstring& role, const wstring& attitude,
                     const wstring& hook, int relation,
                     const wstring& visibleRealm = L"", bool hidesPower = false,
                     const wstring& hiddenHint = L"") {
    if (name.empty()) return;
    for (const auto& existing : g_socialThreads) {
        if (existing.name == name && existing.role == role) return;
    }

    SocialThread thread;
    thread.name = name;
    thread.role = role;
    thread.attitude = attitude;
    thread.hook = hook;
    thread.relation = max(-100, min(100, relation));
    thread.visibleRealm = visibleRealm;
    thread.hidesPower = hidesPower;
    thread.hiddenHint = hiddenHint;
    g_socialThreads.push_back(thread);

    if (relation != 0) {
        g_dynamicWorld.PlayerInteractWithNPC(name, relation);
    }
}

wstring BuildSocialEmotionTag(const SocialThread& thread) {
    auto has = [&](const wstring& needle) {
        return thread.role.find(needle) != wstring::npos ||
               thread.attitude.find(needle) != wstring::npos ||
               thread.hook.find(needle) != wstring::npos;
    };

    if (has(L"父亲") || has(L"母亲") || has(L"养育者")) {
        return thread.relation >= 0 ? L"护短期许" : L"担忧管束";
    }
    if (has(L"欺压者")) return L"轻慢挑衅";
    if (has(L"竞争者")) return L"酸意较劲";
    if (has(L"资源把关者")) return L"冷脸卡资源";
    if (has(L"旧名追债人")) return L"旧怨追问";
    if (has(L"旧名仰慕者")) return L"仰慕押注";
    if (has(L"功法见证者")) return L"惊疑认可";
    if (has(L"器痕识别者")) return L"压声提醒";
    if (has(L"仙朝耳目") || has(L"势力牵连")) return L"礼貌审查";
    if (has(L"道网联系人")) return L"隔空围观";
    if (has(L"残宗向导")) return L"现实互利";
    if (thread.relation >= 35) return L"热切拉拢";
    if (thread.relation >= 18) return L"认可示好";
    if (thread.relation <= -35) return L"敌意带刺";
    if (thread.relation <= -18) return L"嫉妒戒备";
    return L"观望试探";
}

wstring BuildSocialNpcUtterance(const SocialThread& thread) {
    bool gifted = g_player.hasBalancedRoots || g_player.GetTotalRoot() >= 42;
    bool weak = g_player.GetTotalRoot() < 30 && !g_player.hasBalancedRoots;
    auto has = [&](const wstring& needle) {
        return thread.role.find(needle) != wstring::npos ||
               thread.attitude.find(needle) != wstring::npos ||
               thread.hook.find(needle) != wstring::npos;
    };

    if (has(L"父亲")) {
        if (gifted) return L"「你这份根骨可以骄傲，但不能被旁人一句夸就牵着走。」";
        if (weak) return L"「修不成最快的路也无妨，先把命和心气护住。」";
        return L"「入道不是给别人看的，别急着把自己押进大局。」";
    }
    if (has(L"母亲")) {
        if (gifted) return L"「他们夸你，是想提前押注；我护你，是怕你太早被看穿。」";
        if (weak) return L"「测灵碑冷，娘不冷，你慢慢走也有人给你留灯。」";
        return L"「旁人看灵根，我看你能不能守住自己的心。」";
    }
    if (has(L"养育者")) {
        return L"「有些事我现在不能说，但你别把那枚旧玉交给任何人看。」";
    }
    if (has(L"欺压者")) {
        return weak
            ? L"「测灵碑都替你把话说完了，还想跟我们争名额？」"
            : L"「有点根骨就敢抬头？山门里会教你什么叫规矩。」";
    }
    if (has(L"竞争者")) {
        return gifted
            ? L"「资质好又怎样，谁知道你家世里藏着什么债？」"
            : L"「你我都没稳进内门，少摆出已经赢了的样子。」";
    }
    if (has(L"资源把关者")) {
        return L"「灵井不是给热血少年的，拿得出筹码再谈破境。」";
    }
    if (has(L"功法见证者")) {
        return L"「这一式别在外头乱用，懂行的人会认出失传古法的骨头。」";
    }
    if (has(L"旧名仰慕者")) {
        return L"「我敬的是你今生这一眼，但也盼你配得上旧名留下的光。」";
    }
    if (has(L"旧名追债人")) {
        return L"「别急着装无辜，有些旧债换了皮囊也会认人。」";
    }
    if (has(L"器痕识别者")) {
        return L"「你身边没有那件法宝本体，可器痕的响声瞒不过我。」";
    }
    if (has(L"仙朝耳目")) {
        return L"「名册只问事实，不问你愿不愿意被写进去。」";
    }
    if (has(L"道网联系人")) {
        return L"「你这一步会被远方节点看见，别装成没人围观。」";
    }
    if (thread.relation >= 18) {
        return L"「我愿意先信你一次，但你最好让我觉得这份押注值得。」";
    }
    if (thread.relation <= -18) {
        return L"「我不喜欢你这种眼神，像早就知道别人会怎么输。」";
    }
    return L"「先别急着站队，我还想看看你到底是哪种人。」";
}

wstring BuildSocialThreadLine(const SocialThread& thread) {
    wstringstream ss;
    ss << thread.name << L"（" << thread.role << L"）";
    ss << L" · " << thread.attitude << L" · " << GetRelationLabel(thread.relation);
    ss << L" · 情绪" << BuildSocialEmotionTag(thread);
    if (!thread.visibleRealm.empty()) {
        ss << L" · 外显" << thread.visibleRealm;
    }
    if (thread.hidesPower || !thread.hiddenHint.empty()) {
        ss << L" · " << (thread.hiddenHint.empty() ? L"可能隐藏实力" : thread.hiddenHint);
    }
    ss << L": " << thread.hook << L" NPC情绪代理口吻" << BuildSocialNpcUtterance(thread);
    return ss.str();
}

wstring BuildSocialThreadDigest(int limit = 4) {
    if (g_socialThreads.empty()) return L"";
    wstringstream ss;
    int count = 0;
    for (const auto& thread : g_socialThreads) {
        if (count++ >= limit) break;
        ss << L"- " << BuildSocialThreadLine(thread) << L"\n";
    }
    return ss.str();
}

bool TextContainsAny(const wstring& text, const vector<wstring>& keys) {
    for (const auto& key : keys) {
        if (!key.empty() && text.find(key) != wstring::npos) return true;
    }
    return false;
}

int ClampRelation(int value) {
    return max(-100, min(100, value));
}

void AddSocialRumor(const wstring& rumor, bool front = true) {
    if (rumor.empty()) return;

    wstring compact = CompactMemoryFragment(rumor);
    if (compact.size() > 150) {
        compact = compact.substr(0, 150) + L"...";
    }

    auto existing = find(g_socialRumors.begin(), g_socialRumors.end(), compact);
    if (existing != g_socialRumors.end()) {
        g_socialRumors.erase(existing);
    }
    if (front) {
        g_socialRumors.insert(g_socialRumors.begin(), compact);
    } else {
        g_socialRumors.push_back(compact);
    }
    while (g_socialRumors.size() > 8) {
        g_socialRumors.pop_back();
    }
}

wstring GetLegacyDisplayName(const LegacyItem& legacy) {
    wstring name = legacy.name;
    const wstring prefix = L"前世遗响·";
    if (name.rfind(prefix, 0) == 0) {
        name = name.substr(prefix.size());
    }
    return name.empty() ? L"无名旧法" : name;
}

wstring BuildTechniqueLegendLabel(const LegacyItem& legacy) {
    wstring name = GetLegacyDisplayName(legacy);
    if (name.find(L"真名") != wstring::npos || legacy.description.find(L"道祖") != wstring::npos) {
        return L"失传道法·" + name;
    }
    if (name.find(L"登仙") != wstring::npos || legacy.description.find(L"仙门") != wstring::npos) {
        return L"失传古法·" + name;
    }
    if (name.find(L"化神") != wstring::npos || legacy.description.find(L"化神") != wstring::npos) {
        return L"失传古法·" + name;
    }
    return L"失传古法·" + name;
}

wstring BuildTechniqueEraInterpretation(const wstring& legendLabel) {
    if (legendLabel.empty()) return L"";
    if (g_worldEraName == L"灵机蒸汽纪") {
        return L"灵机工坊想把" + legendLabel +
            L"拆成可复刻的经脉回路，旧宗门却认为这是亵渎古法。";
    }
    if (g_worldEraName == L"星穹道网纪") {
        return L"道网档案师正在把" + legendLabel +
            L"与断代功法库比对，一旦命中，远方节点都会看见你的影子。";
    }
    if (g_worldEraName == L"末法裂变纪") {
        return L"末法修士不问来历，只问" + legendLabel +
            L"能否替人破境；每多一句传闻，抢夺的人就多一批。";
    }
    if (g_worldEraName == L"废土返道纪") {
        return L"残宗把" + legendLabel +
            L"当作重建法统的火种，拾荒者则只想知道它能换几口灵粮。";
    }
    if (g_worldEraName == L"仙朝鼎盛纪") {
        return L"天册司想给" + legendLabel +
            L"定品入册；一旦入册，古法、家世和气运都会被仙朝写成名位。";
    }
    return L"古修宗门只敢把" + legendLabel +
        L"写进残页旁注，既想收你入门，又怕旧法背后牵出前世因果。";
}

wstring BuildRelationAftershockText(const SocialThread& thread, int oldRelation, int delta,
                                    const Event& event, const Choice& choice) {
    bool improved = delta > 0;
    bool worsened = delta < 0;
    bool gifted = g_player.hasBalancedRoots || g_player.GetTotalRoot() >= 42;
    bool weak = g_player.GetTotalRoot() < 30 && !g_player.hasBalancedRoots;
    wstring trigger = CompactMemoryFragment(event.title + L"·" + choice.description);

    if (thread.role == L"父亲" || thread.role == L"母亲" || thread.role == L"养育者") {
        if (improved) {
            return thread.name + L"听闻你在「" + trigger +
                L"」中的取舍后，终于把担忧压成一句认可；这份长辈期许会继续护着你。";
        }
        if (worsened) {
            return thread.name + L"因「" + trigger +
                L"」对你更不放心，嘴上不责怪，暗里却开始替你收拾可能爆开的因果。";
        }
    }

    if (thread.role == L"欺压者" || thread.role == L"竞争者" || thread.role == L"资源把关者") {
        if (improved) {
            return thread.name + L"看见你在「" + trigger +
                L"」里没有露怯，态度虽仍带刺，却开始承认你不是能随便欺负的人。";
        }
        if (worsened) {
            return thread.name + L"把「" + trigger +
                L"」当成新把柄，嫉妒与轻慢一起发酵，下一次很可能主动设局。";
        }
    }

    if (thread.role == L"同代修士" || thread.role == L"同路人" || thread.role == L"接引修士") {
        if (improved) {
            return thread.name + L"因「" + trigger +
                L"」更愿意与你同行；若你资质继续显眼，亲近里也会混着押注。";
        }
        if (worsened) {
            return thread.name + L"因「" + trigger +
                L"」重新衡量你，表面客气，背后已经把你当成需要防备的对手。";
        }
    }

    if (thread.role == L"势力牵连" || thread.role.find(L"联系人") != wstring::npos ||
        thread.role.find(L"耳目") != wstring::npos) {
        if (improved) {
            return thread.name + L"把「" + trigger +
                L"」写成一条正面评语，所在势力对你的押注开始加重。";
        }
        if (worsened) {
            return thread.name + L"把「" + trigger +
                L"」写进回报，所在势力对你的审查、试探和索取都会更重。";
        }
    }

    if (gifted && worsened) {
        return thread.name + L"听过「" + trigger +
            L"」后没有当面翻脸，却因你资质出众而更嫉妒，风声会越传越酸。";
    }
    if (weak && worsened) {
        return thread.name + L"借「" + trigger +
            L"」确认你根基不稳，轻慢之声很快会传到下一场试炼。";
    }
    if (improved) {
        return thread.name + L"记住了你在「" + trigger +
            L"」里的表现，态度从" + GetRelationLabel(oldRelation) + L"往" +
            GetRelationLabel(thread.relation) + L"偏了一步。";
    }
    return thread.name + L"因「" + trigger +
        L"」把你看得更复杂，关系从" + GetRelationLabel(oldRelation) + L"滑向" +
        GetRelationLabel(thread.relation) + L"。";
}

const SocialThread* PickSocialAdventureThread() {
    if (g_socialThreads.empty()) return nullptr;

    vector<int> weighted;
    for (int i = 0; i < (int)g_socialThreads.size(); ++i) {
        const SocialThread& thread = g_socialThreads[i];
        int weight = 2 + min(6, abs(thread.relation) / 12);
        if (thread.role == L"父亲" || thread.role == L"母亲" || thread.role == L"养育者") weight += 2;
        if (thread.role == L"欺压者" || thread.role == L"竞争者") weight += 2;
        if (thread.role == L"势力牵连") weight += 1;
        for (int j = 0; j < weight; ++j) {
            weighted.push_back(i);
        }
    }

    if (weighted.empty()) return &g_socialThreads[0];
    return &g_socialThreads[weighted[Random(0, (int)weighted.size() - 1)]];
}

bool ShouldTriggerSocialAdventureEvent() {
    if (g_socialThreads.empty()) return false;

    int chance = 14;
    for (const auto& thread : g_socialThreads) {
        if (abs(thread.relation) >= 35) chance += 3;
        if (thread.role == L"父亲" || thread.role == L"母亲" || thread.role == L"养育者") chance += 1;
        if (thread.role == L"欺压者" || thread.role == L"竞争者") chance += 2;
    }
    if (HasFactionTie() && abs(g_factionTie.favor) >= 25) chance += 3;
    if (g_player.totalEvents <= 2) chance += 4;
    chance = max(10, min(34, chance));
    return Random(1, 100) <= chance;
}

wstring BuildSocialTalentPressureText() {
    int totalRoot = g_player.GetTotalRoot();
    if (g_player.hasBalancedRoots || totalRoot >= 42) {
        return L"你资质出众后，赞许、押注和嫉妒都来得比灵气更快。";
    }
    if (totalRoot < 30 && !g_player.hasBalancedRoots) {
        return L"测灵结果不算好，旁人的轻慢与少数善意都显得格外刺眼。";
    }
    return L"你的资质不上不下，正处在值得押注也容易被试探的位置。";
}

wstring BuildSocialEraPressureText() {
    if (g_worldEraName == L"仙朝鼎盛纪") {
        return L"仙朝名册在旁，家世与关系都会被写成筹码。";
    }
    if (g_worldEraName == L"末法裂变纪") {
        return L"末法资源紧缺，人情往来也常带着配给与欠债的味道。";
    }
    if (g_worldEraName == L"灵机蒸汽纪") {
        return L"工坊炉声渐盛，旧宗门的人情被新式合约重新估价。";
    }
    if (g_worldEraName == L"星穹道网纪") {
        return L"道网会记下每一次公开选择，流言传得比飞剑更远。";
    }
    if (g_worldEraName == L"废土返道纪") {
        return L"废土路远，能信谁、欠谁，都可能决定下一次能否活着回来。";
    }
    return L"山门与坊市都在看人下菜，少年道途从来不只看灵根。";
}

Event BuildSocialAdventureEvent() {
    Event evt;
    const SocialThread* picked = PickSocialAdventureThread();
    if (!picked) {
        evt.title = L"【因果】无人问津";
        evt.description = L"你独自外出历练，竟无人认得你的姓名，天地辽阔得近乎冷清。";
        evt.choices = {
            {L"独自前行", {L"你把冷清当作磨砺，默默走完一段路\n修为+45", L"山路太长，只添疲惫\n气血-10"}, 0}
        };
        return evt;
    }

    const SocialThread& thread = *picked;
    bool positive = thread.relation >= 18;
    bool negative = thread.relation <= -18;
    bool familyTie = TextContainsAny(thread.role, {L"父亲", L"母亲", L"养育者", L"身世"});
    bool challenger = TextContainsAny(thread.role, {L"欺压者", L"竞争者", L"资源把关者"});
    bool factionTie = (thread.role == L"势力牵连") || TextContainsAny(thread.role + thread.attitude, {
        L"册封", L"工坊", L"道网", L"残宗", L"仙朝", L"联系人"
    });

    if (familyTie) {
        evt.title = L"【因果】家门问心";
    } else if (challenger || negative) {
        evt.title = L"【危机】人情逼试";
    } else if (factionTie) {
        evt.title = L"【机缘】势力递帖";
    } else {
        evt.title = L"【因果】故人递手";
    }

    wstring realmHint;
    if (!thread.visibleRealm.empty()) {
        realmHint = L"对方外显" + thread.visibleRealm;
        if (thread.hidesPower || !thread.hiddenHint.empty()) {
            realmHint += L"，但气机未必可信";
        }
        realmHint += L"。";
    }

    evt.description = thread.name + L"以" + thread.role + L"身份在历练途中拦住你，态度是“" +
        thread.attitude + L"”。" + BuildSocialTalentPressureText() + BuildSocialEraPressureText() +
        realmHint + BuildSocialNpcUtterance(thread) + L"旧线索是：" + CompactMemoryFragment(thread.hook);

    if (positive) {
        evt.choices = {
            {L"坦然受教", {
                thread.name + L"见你没有自矜，终于当面认可你，并替你指明一条稳妥去处。\n修为+85，因果+8",
                thread.name + L"觉得你把善意看得太轻，话虽温和，关系却淡了一层。\n因果-5"
            }, 6},
            {L"追问隐情", {
                thread.name + L"被你问住，透露出一段与家世、势力或前世旧名有关的新线索。\n修为+70，灵石+12，因果+6",
                thread.name + L"不愿把隐情说穿，只提醒你别太早暴露前世般的判断。\n气血-12"
            }, 4},
            {L"婉拒好意", {
                L"你谢过对方却没有立刻站队，保住今生自己的主动权。\n寿命+3，修为+45",
                thread.name + L"误以为你不信任这份善意，日后未必还会主动护持。\n因果-6"
            }, 2}
        };
    } else if (negative) {
        evt.choices = {
            {L"当众回应", {
                L"你没有被轻慢压住，反让旁人重新衡量你的胆气与资质。\n修为+90，因果+6",
                thread.name + L"当场记恨于你，暗中把一次普通历练变成设局。\n气血-28，因果-8"
            }, 4},
            {L"暂避锋芒", {
                L"你没有争一时脸面，反而看清对方借势欺压的破绽。\n修为+55，寿命+2",
                L"旁人以为你怯弱，轻慢之声比先前更多。\n因果-7"
            }, 0},
            {L"暗查底细", {
                thread.name + L"的外显修为和真实气机并不完全相合，你记下了这个活人般的破绽。\n修为+65，灵石+10",
                L"你查得太近，被对方反向看穿行迹。\n气血-25"
            }, 2}
        };
    } else {
        evt.choices = {
            {L"顺势结交", {
                thread.name + L"接受你的善意，关系从观望变成可继续经营的人情线。\n修为+60，因果+6",
                thread.name + L"笑着收下话，却没有给出真正承诺。\n灵石-6"
            }, 5},
            {L"试探虚实", {
                L"你从几句闲谈里看出对方态度未定，也看出这条关系值得继续观察。\n修为+55",
                L"试探过浅，对方反而觉得你心思太重。\n因果-4"
            }, 0},
            {L"保持距离", {
                L"你没有被临时善恶牵着走，只把这次相遇记成今生的一条线索。\n寿命+2，修为+35",
                L"距离拉开后，这条人脉短期内也帮不上你。"
            }, 1}
        };
    }

    return evt;
}

bool ShouldTriggerEraPulseEvent() {
    int chance = 12;
    if (g_dynamicWorld.GetActiveWorldEvent()) chance += 8;
    if (!g_eraRemnants.empty()) chance += min(8, (int)g_eraRemnants.size() * 2);
    if (!g_dynamicWorld.GetRecentHistoryEntries(3).empty()) chance += 3;
    if (g_worldEraName == L"末法裂变纪" || g_worldEraName == L"废土返道纪") chance += 4;
    if (g_worldEraName == L"灵机蒸汽纪" || g_worldEraName == L"星穹道网纪") chance += 3;
    if (g_worldEraName == L"仙朝鼎盛纪") chance += 2;
    if (g_player.totalEvents <= 2) chance += 3;
    chance = max(10, min(35, chance));
    return Random(1, 100) <= chance;
}

Event BuildEraPulseEvent() {
    Event evt;
    auto compactLimit = [](const wstring& text, size_t limit) {
        wstring compact = CompactMemoryFragment(text);
        if (compact.size() > limit) {
            compact = compact.substr(0, limit) + L"...";
        }
        return compact;
    };

    WorldEvent* activeEvent = g_dynamicWorld.GetActiveWorldEvent();
    vector<wstring> recentHistory = g_dynamicWorld.GetRecentHistoryEntries(4);
    wstring activeText = activeEvent
        ? L"当前修仙界大势是" + activeEvent->title + L"：" + compactLimit(activeEvent->description, 76) + L"。"
        : L"此刻没有单一大事压顶，但时代本身仍在慢慢改写每个人的去路。";
    wstring remnantText;
    if (!g_eraRemnants.empty()) {
        remnantText = L"旧世残响也被卷入其中：" +
            compactLimit(g_eraRemnants[Random(0, (int)g_eraRemnants.size() - 1)], 76) + L"。";
    }
    wstring historyText;
    if (!recentHistory.empty()) {
        historyText = L"近年大事还在发酵：" +
            compactLimit(recentHistory[Random(0, (int)recentHistory.size() - 1)], 56) + L"。";
    }

    int expGain = 85 + g_player.realm * 6;
    int majorGain = expGain + 45;
    int minorGain = max(45, expGain - 25);
    int hpRisk = 22 + g_player.realm * 2;
    int stoneReward = 14 + g_player.realm * 2;
    int daoReward = max(4, min(12, 4 + g_player.realm / 2));

    wstring scene;
    if (g_worldEraName == L"仙朝鼎盛纪") {
        evt.title = L"【纪元】仙朝名册";
        scene = L"仙朝天册司在山道旁设案，要求过路修士登记家世、宗门与气运。";
        evt.choices = {
            {L"入册借势", {
                L"你借仙朝名册换来一次正当通行，名位短暂变成护身符。\n修为+" + to_wstring(majorGain) + L"，灵石+" + to_wstring(stoneReward) + L"，因果+6",
                L"册封吏盯上你的家世与旧名，想把你写进更深的局里。\n因果-10，灵石-8"
            }, 5},
            {L"拒绝定品", {
                L"你没有让名册替今生定品，只以本事闯过关口。\n修为+" + to_wstring(expGain) + L"，寿命+3",
                L"拒绝太硬，仙朝暗线记下你的姓名。\n气血-" + to_wstring(hpRisk) + L"，因果-6"
            }, 2},
            {L"查验密诏", {
                L"你从密诏边角看出旧盟裂痕，知道此世势力并非铁板一块。\n修为+" + to_wstring(minorGain) + L"，因果+10，掌道+" + to_wstring(daoReward),
                L"密诏反锁神识，差点把你的前世般判断也牵出来。\n气血-" + to_wstring(hpRisk + 8)
            }, 7}
        };
    } else if (g_worldEraName == L"末法裂变纪") {
        evt.title = L"【纪元】末法配给";
        scene = L"枯潮压过驿道，一队修士围着灵井配给争得面红耳赤。";
        evt.choices = {
            {L"争取配给", {
                L"你抢在混乱前替自己夺到一份灵气配给，知道末法里温和也是奢侈。\n修为+" + to_wstring(majorGain) + L"，灵石+" + to_wstring(max(8, stoneReward - 4)),
                L"配给背后另有债契，你拿得越多，欠得越重。\n因果-12，灵石-10"
            }, -2},
            {L"让出一份", {
                L"你把一份灵气让给将死散修，末法中这点善意反而被很多人记住。\n因果+14，寿命+4，修为+" + to_wstring(minorGain),
                L"善意没能立刻换来回报，你被枯潮拖得气血发冷。\n气血-" + to_wstring(hpRisk)
            }, 9},
            {L"追查枯潮", {
                L"你顺着灵井裂纹查到法则破口，通天灵宝残印记下一缕末法器痕。\n修为+" + to_wstring(expGain) + L"，灵宝共鸣+5，掌道+" + to_wstring(daoReward),
                L"枯潮突然回卷，经脉像被干井刮过。\n气血-" + to_wstring(hpRisk + 12)
            }, 6}
        };
    } else if (g_worldEraName == L"灵机蒸汽纪") {
        evt.title = L"【纪元】灵机工坊";
        scene = L"一座灵机工坊把旧宗门洞府改成试炼矿坊，炉火和阵纹一同轰鸣。";
        evt.choices = {
            {L"签下工坊约", {
                L"你借工坊契约换到灵机资源，也看清新秩序如何给修行标价。\n修为+" + to_wstring(majorGain) + L"，灵石+" + to_wstring(stoneReward + 8),
                L"契约细字藏着扣押条款，差点把你变成低价供奉。\n灵石-14，因果-6"
            }, 2},
            {L"拆看阵械", {
                L"你拆开阵械核心，发现旧法则也能被新工艺暂时重排。\n修为+" + to_wstring(expGain) + L"，灵宝共鸣+4",
                L"炉压失衡，阵械碎片割伤经脉。\n气血-" + to_wstring(hpRisk + 5)
            }, 5},
            {L"护住旧宗弟子", {
                L"你把被工坊压价的旧宗弟子护下，旧宗门的人情因此续了一线。\n因果+10，修为+" + to_wstring(minorGain),
                L"工坊管事记住你的插手，下一次报价会更苛刻。\n灵石-10"
            }, 8}
        };
    } else if (g_worldEraName == L"星穹道网纪") {
        evt.title = L"【纪元】道网余波";
        scene = L"道网节点忽然在你头顶亮起，远方榜单、旧案影像和招揽玉简同时投来。";
        evt.choices = {
            {L"接入道网", {
                L"你借道网共振看见远方机缘，今生的名字第一次被更多人看见。\n修为+" + to_wstring(majorGain) + L"，灵石+" + to_wstring(stoneReward) + L"，因果+5",
                L"道网记下你的异常判断，有人开始追索你为何像带着前世经验。\n因果-10"
            }, 4},
            {L"隐去真名", {
                L"你没有把真名交给节点，只留下一个可进可退的虚号。\n寿命+3，修为+" + to_wstring(minorGain),
                L"隐匿触发审查，节点反向锁住你的神识波纹。\n气血-" + to_wstring(hpRisk)
            }, 3},
            {L"追查断链", {
                L"你顺着断链查到一段旧世影像，明白道网也会保存被人抹去的因果。\n修为+" + to_wstring(expGain) + L"，因果+12，掌道+" + to_wstring(daoReward),
                L"断链里藏着恶意回响，几乎把你拖进别人的旧案。\n气血-" + to_wstring(hpRisk + 8) + L"，因果-6"
            }, 7}
        };
    } else if (g_worldEraName == L"废土返道纪") {
        evt.title = L"【纪元】废土迁徙";
        scene = L"黑雨将至，残宗迁徙队拖着伤员、灵粮和破损法器从荒野经过。";
        evt.choices = {
            {L"护送迁徙", {
                L"你护住迁徙队穿过黑雨边缘，残宗火种因此多留一息。\n修为+" + to_wstring(expGain) + L"，因果+12",
                L"荒野邪祟盯上队尾，你被迫硬接一场消耗战。\n气血-" + to_wstring(hpRisk + 10)
            }, 9},
            {L"翻检古机", {
                L"你从旧文明古机里拆出可用阵核，废土里破损之物也能再生路。\n修为+" + to_wstring(majorGain) + L"，灵石+" + to_wstring(stoneReward) + L"，灵宝共鸣+4",
                L"古机警戒未灭，黑匣噪声反噬识海。\n气血-" + to_wstring(hpRisk + 14)
            }, 5},
            {L"点燃火种", {
                L"你没有只顾眼前收益，而是帮残宗重立一条微弱法统。\n寿命+4，因果+10，掌道+" + to_wstring(daoReward),
                L"火种太弱，短期内换不来资源，还暴露了你的行踪。\n灵石-8，气血-" + to_wstring(max(12, hpRisk - 6))
            }, 8}
        };
    } else {
        evt.title = L"【纪元】古修遗响";
        scene = L"山门之外忽现古修洞府裂隙，诸宗还没来得及给它定规矩。";
        evt.choices = {
            {L"入山查旧", {
                L"你趁诸宗未定章程时先入裂隙，拾到一段古修感悟。\n修为+" + to_wstring(majorGain) + L"，灵石+" + to_wstring(stoneReward),
                L"裂隙里旧禁制尚未衰尽，险些把你困在山腹。\n气血-" + to_wstring(hpRisk)
            }, 4},
            {L"结交古修", {
                L"你没有独吞线索，反与同行修士立下互不相害的约定。\n因果+9，修为+" + to_wstring(minorGain),
                L"约定太浅，对方离开后仍可能另起心思。\n因果-4"
            }, 6},
            {L"避开争端", {
                L"你看出洞府会引来宗门争夺，提前记下地势后抽身。\n寿命+3，修为+" + to_wstring(minorGain),
                L"避得太早，错过了一件当世可用的法宝线索。"
            }, 2}
        };
    }

    evt.description = L"你外出历练时，纪元大势主动压到眼前。" + scene +
        L"此世法则是：" + compactLimit(g_worldEraRule, 72) + L"。" +
        activeText + remnantText + historyText +
        L"纪元转折因由仍在暗处发酵：" + compactLimit(g_eraShiftCause, 72) + L"。";
    return evt;
}

int NarrativeRelationDelta(const wstring& text) {
    int delta = 0;
    if (TextContainsAny(text, {L"认可", L"亲近", L"信任", L"体面", L"护持", L"查到", L"稳住", L"主动权"})) delta += 8;
    if (TextContainsAny(text, {L"善意", L"礼重", L"拉拢", L"给机会", L"新线索", L"重新衡量"})) delta += 5;
    if (TextContainsAny(text, {L"修为+", L"灵石+", L"寿命+", L"因果+", L"掌道+", L"灵宝共鸣+"})) delta += 3;

    if (TextContainsAny(text, {L"怀疑", L"记恨", L"翻脸", L"轻慢", L"羞怒", L"看穿", L"反咬"})) delta -= 8;
    if (TextContainsAny(text, {L"误判", L"旧债", L"反噬", L"恶名", L"压不住", L"设局"})) delta -= 4;
    if (TextContainsAny(text, {L"气血-", L"因果-", L"寿命-"})) delta -= 3;

    return max(-18, min(18, delta));
}

void ApplyNarrativeRelationshipEffects(const Event& event, const Choice& choice, const wstring& outcome) {
    wstring text = event.title + L" " + event.description + L" " + choice.description + L" " + outcome;
    int baseDelta = NarrativeRelationDelta(text);
    if (baseDelta == 0) return;

    bool touchesFaction = HasFactionTie() && TextContainsAny(text, {
        g_factionTie.name, L"势力", L"旧债", L"名册", L"宗门", L"仙朝", L"工坊", L"道网",
        L"残宗", L"合约", L"册封", L"家世"
    });
    bool touchesSocial = TextContainsAny(text, {
        L"本世人脉", L"父亲", L"母亲", L"养育者", L"长辈", L"同辈", L"欺压者",
        L"竞争者", L"旁人", L"联系人", L"人情", L"旧名"
    });

    if (touchesFaction) {
        int oldFavor = g_factionTie.favor;
        g_factionTie.favor = ClampRelation(g_factionTie.favor + baseDelta);
        if (g_factionTie.favor != oldFavor) {
            wstring factionRumor = g_factionTie.name + L"因「" +
                CompactMemoryFragment(event.title + L"·" + choice.description) + L"」调整了对你的态度：";
            if (baseDelta > 0) {
                factionRumor += L"有人开始替你说话，也有人觉得你值得提前押注。";
            } else {
                factionRumor += L"审查、试探与索取都变重了，旧债可能被重新翻出。";
            }
            AddSocialRumor(factionRumor);
            AddMemory(L"势力回响",
                g_factionTie.name + L"对你的牵连值由" +
                (oldFavor >= 0 ? L"+" : L"") + to_wstring(oldFavor) + L"变为" +
                (g_factionTie.favor >= 0 ? L"+" : L"") + to_wstring(g_factionTie.favor) +
                L"。起因：" + CompactMemoryFragment(event.title + L"·" + choice.description));
            AddMemory(L"势力余波", factionRumor);
        }
    }

    int changed = 0;
    for (auto& thread : g_socialThreads) {
        bool directHit = text.find(thread.name) != wstring::npos ||
                         text.find(thread.role) != wstring::npos ||
                         text.find(thread.attitude) != wstring::npos;
        if (!directHit && !touchesSocial) continue;
        if (!directHit && changed > 0) continue;

        int oldRelation = thread.relation;
        int localDelta = directHit ? baseDelta : baseDelta / 2;
        if (localDelta == 0) localDelta = baseDelta > 0 ? 1 : -1;
        thread.relation = ClampRelation(thread.relation + localDelta);
        if (thread.relation != oldRelation) {
            g_dynamicWorld.PlayerInteractWithNPC(thread.name, localDelta);
            wstring aftershock = BuildRelationAftershockText(thread, oldRelation, localDelta, event, choice);
            AddSocialRumor(aftershock);
            AddMemory(L"人情回响",
                thread.name + L"（" + thread.role + L"）对你的关系由" +
                GetRelationLabel(oldRelation) + L"变为" + GetRelationLabel(thread.relation) +
                L"。起因：" + CompactMemoryFragment(event.title + L"·" + choice.description));
            AddMemory(L"人情余波", aftershock);
            changed++;
        }
        if (changed >= 2) break;
    }
}

bool PulseSocialEmotions(const wstring& reason) {
    if (g_socialThreads.empty()) return false;
    if (Random(1, 100) > 28) return false;

    vector<int> weighted;
    for (int i = 0; i < (int)g_socialThreads.size(); ++i) {
        const SocialThread& thread = g_socialThreads[i];
        int weight = 1 + min(5, abs(thread.relation) / 18);
        if (thread.role == L"父亲" || thread.role == L"母亲" || thread.role == L"养育者") weight += 2;
        if (thread.role == L"欺压者" || thread.role == L"竞争者" || thread.role == L"资源把关者") weight += 2;
        for (int j = 0; j < weight; ++j) {
            weighted.push_back(i);
        }
    }
    if (weighted.empty()) return false;

    SocialThread& thread = g_socialThreads[weighted[Random(0, (int)weighted.size() - 1)]];
    int oldRelation = thread.relation;
    int totalRoot = g_player.GetTotalRoot();
    bool gifted = g_player.hasBalancedRoots || totalRoot >= 42;
    bool weak = totalRoot < 30 && !g_player.hasBalancedRoots;

    int delta = Random(-1, 1);
    if (TextContainsAny(thread.role + thread.attitude, {L"父亲", L"母亲", L"养育者", L"长辈"})) {
        delta += gifted ? 2 : (weak ? 1 : 0);
    }
    if (TextContainsAny(thread.role + thread.attitude, {L"欺压者", L"竞争者"})) {
        delta += gifted ? -2 : (weak ? -1 : 0);
    }
    if (TextContainsAny(thread.role + thread.attitude, {L"资源把关者", L"配给"})) {
        delta += (g_worldEraName == L"末法裂变纪") ? -2 : -1;
    }
    if (thread.relation >= 18 && g_player.karma >= 30) delta += 1;
    if (thread.relation <= -18 && g_player.karma <= -30) delta -= 1;

    delta = max(-3, min(3, delta));
    if (delta == 0) return false;

    thread.relation = ClampRelation(thread.relation + delta);
    if (thread.relation == oldRelation) return false;
    g_dynamicWorld.PlayerInteractWithNPC(thread.name, delta);

    wstring rumor = thread.name + L"（" + thread.role + L"）听过你" + reason + L"后的风声，";
    if (delta > 0) {
        rumor += L"情绪从" + GetRelationLabel(oldRelation) + L"往" +
            GetRelationLabel(thread.relation) + L"松了一分；" + BuildSocialNpcUtterance(thread);
    } else {
        rumor += L"情绪从" + GetRelationLabel(oldRelation) + L"往" +
            GetRelationLabel(thread.relation) + L"冷了一分；" + BuildSocialNpcUtterance(thread);
    }
    AddSocialRumor(rumor);
    AddMemory(L"情绪脉动",
        thread.name + L"（" + thread.role + L"）因" + reason + L"后的传闻，关系由" +
        GetRelationLabel(oldRelation) + L"变为" + GetRelationLabel(thread.relation) +
        L"，当前情绪是" + BuildSocialEmotionTag(thread) + L"。");
    return true;
}

void GenerateSocialThreads() {
    g_socialThreads.clear();

    int totalRoot = g_player.GetTotalRoot();
    bool exceptionalRoot = (totalRoot >= 42 || g_player.hasBalancedRoots);
    bool weakRoot = (totalRoot < 30 && !g_player.hasBalancedRoots);
    int memoryBonus = g_legacySystem.GetLegacyBonus(LEGACY_MEMORY);
    int techniqueEcho = g_legacySystem.GetLegacyBonus(LEGACY_TECHNIQUE);
    int treasureEcho = g_legacySystem.GetLegacyBonus(LEGACY_TREASURE);
    int reputationEcho = g_legacySystem.GetLegacyBonus(LEGACY_REPUTATION);
    auto& inherited = g_legacySystem.GetInheritedLegacies();
    auto npcs = g_dynamicWorld.GetAliveNPCs();
    wstring sectName = g_worldData.sects.empty() ? L"附近宗门" : g_worldData.sects[0].name;

    auto npcRealmText = [](DynamicNPC* npc) {
        if (!npc) return wstring();
        Realm shown = static_cast<Realm>(max(0, min(npc->shownRealm, (int)HEAVENLY_DAO)));
        return GetRealmName(shown) + L" " + to_wstring(npc->level) + L"层";
    };
    auto npcHides = [](DynamicNPC* npc) {
        return npc && npc->shownRealm < npc->realm;
    };
    auto findInherited = [&](LegacyType type) -> const LegacyItem* {
        for (const auto& legacy : inherited) {
            if (legacy.type == type) return &legacy;
        }
        return nullptr;
    };

    if (g_player.family.knowsParents) {
        if (exceptionalRoot) {
            AddSocialThread(g_player.family.father, L"父亲", L"克制认可",
                L"他没有当众夸你，却私下把一枚入门信物交到你手里。", 32);
            AddSocialThread(g_player.family.mother, L"母亲", L"护持期待",
                L"她替你压下族中闲话，只提醒你别太早暴露前世般的眼神。", 36);
        } else if (weakRoot) {
            AddSocialThread(g_player.family.mother, L"母亲", L"心疼护短",
                L"测灵结果传回家中后，她仍替你留着一份最朴素的行囊。", 28);
            AddSocialThread(g_player.family.father, L"父亲", L"沉默担忧",
                L"他嘴上说修行随缘，却开始四处打听能改命的偏方。", 12);
        } else {
            AddSocialThread(g_player.family.father, L"父亲", L"审慎期许",
                L"他认为你可以入道，但不许你轻易卷进宗门旧债。", 22);
        }
    } else if (g_player.family.adopted || !g_player.family.guardian.empty()) {
        AddSocialThread(g_player.family.guardian.empty() ? L"无名养育者" : g_player.family.guardian,
            L"养育者", L"护短隐瞒",
            L"此人知道你来历并不简单，却总在关键处把话咽回去。", 24);
    } else {
        AddSocialThread(g_player.family.familyName.empty() ? L"族中旁支" : g_player.family.familyName + L"旁支",
            L"身世线索", L"若即若离",
            L"对方承认与你有血缘，却不肯说出父母名讳。", -4);
    }

    const LegacyItem* techniqueLegacy = findInherited(LEGACY_TECHNIQUE);
    if (techniqueLegacy && techniqueEcho >= 35) {
        wstring legendLabel = BuildTechniqueLegendLabel(*techniqueLegacy);
        wstring eraInterpretation = BuildTechniqueEraInterpretation(legendLabel);
        AddSocialThread(sectName + L"藏经长老", L"功法见证者",
            techniqueEcho >= 80 ? L"惊疑认可" : L"暗中观察",
            L"他看见你行功起手式后当场压低声音：难道这是" + legendLabel +
            L"？他不知你前世是谁，却已认出旧时代功法的影子。" + eraInterpretation,
            techniqueEcho >= 80 ? 26 : 14);
    }

    const LegacyItem* reputationLegacy = findInherited(LEGACY_REPUTATION);
    if (reputationLegacy && abs(reputationEcho) >= 30) {
        if (reputationEcho > 0) {
            AddSocialThread(sectName + L"递帖人", L"旧名仰慕者", L"提前示好",
                L"对方说自己只敬今生，却总在你身上寻找前世善名留下的影子。",
                28);
        } else {
            AddSocialThread(sectName + L"查账人", L"旧名追债人", L"警惕试探",
                L"对方拿着一页旧册来见你，像是确信前世恶名会在今生重新露出破绽。",
                -32);
        }
    }

    const LegacyItem* treasureLegacy = findInherited(LEGACY_TREASURE);
    if (treasureLegacy && treasureEcho >= 35) {
        AddSocialThread(sectName + L"器阁执事", L"器痕识别者", L"压低声音",
            L"此人从你神魂边缘听见" + treasureLegacy->name +
            L"的余响，提醒你普通法宝不能跨世，能留下的只有器痕。",
            12);
    }

    if (!npcs.empty()) {
        DynamicNPC* first = npcs[0];
        DynamicNPC* second = npcs.size() > 1 ? npcs[1] : nullptr;
        DynamicNPC* third = npcs.size() > 2 ? npcs[2] : nullptr;

        if (exceptionalRoot) {
            AddSocialThread(first->name, L"同代修士", L"主动亲近",
                L"对方称你将来必入内门，言语里已有几分提前下注的意思。",
                30, npcRealmText(first), npcHides(first), npcHides(first) ? L"外显修为偏低" : L"");
            if (second) {
                AddSocialThread(second->name, L"竞争者", L"嫉妒试探",
                    L"此人表面祝贺你灵根出众，背后却在打听你的家世短处。",
                    -34, npcRealmText(second), npcHides(second), npcHides(second) ? L"气机不明" : L"");
            }
        } else if (weakRoot) {
            AddSocialThread(first->name, L"欺压者", L"轻慢挑衅",
                L"此人认定你道途有限，故意在杂役与试炼名额上为难你。",
                -42, npcRealmText(first), npcHides(first), npcHides(first) ? L"也许并未显露真修为" : L"");
            if (second) {
                AddSocialThread(second->name, L"旁观长辈", L"暗中照看",
                    L"对方没有替你出头，却提醒你记下每一次被轻慢的因果。",
                    18, npcRealmText(second), npcHides(second), npcHides(second) ? L"藏拙很深" : L"");
            }
        } else {
            AddSocialThread(first->name, L"接引修士", L"谨慎观察",
                L"此人愿意给你一次试炼机会，但还在判断你是否值得投入资源。",
                14, npcRealmText(first), npcHides(first), npcHides(first) ? L"外显修为未必可信" : L"");
            if (second) {
                AddSocialThread(second->name, L"同路人", L"可拉拢也可翻脸",
                    L"你们都想抓住同一份机缘，暂时合作不代表没有暗斗。",
                    -8, npcRealmText(second), npcHides(second), npcHides(second) ? L"气机不明" : L"");
            }
        }

        if (memoryBonus >= 30 && third) {
            AddSocialThread(third->name, L"前世眼熟者",
                reputationEcho < 0 ? L"警惕旧名" : L"莫名亲近",
                L"你看见此人时会短暂恍神，像是前世某段未了因果换了面目。",
                reputationEcho < 0 ? -26 : 24,
                npcRealmText(third), npcHides(third), npcHides(third) ? L"可能隐藏实力" : L"");
        }
    }

    if (g_worldEraName == L"灵机蒸汽纪") {
        AddSocialThread(sectName + L"炉师", L"工坊中人", L"热情拉拢",
            L"他看中你的灵根适配性，想让你试一套尚未公开的阵械功法。", 16);
    } else if (g_worldEraName == L"星穹道网纪") {
        AddSocialThread(sectName + L"远讯使", L"道网联系人", L"隔空关注",
            L"对方通过灵网给你发来试炼坐标，也记录着你每一次选择。", 12);
    } else if (g_worldEraName == L"末法裂变纪") {
        AddSocialThread(sectName + L"配给执事", L"资源把关者", L"冷硬审视",
            L"此人掌着灵井配给，你的资质、家世和态度都会影响下一份资源。", -10);
    } else if (g_worldEraName == L"废土返道纪") {
        AddSocialThread(sectName + L"巡荒者", L"残宗向导", L"现实互利",
            L"他愿意带你进废墟，但先要确认你不会拖累整支队伍。", 6);
    } else if (g_worldEraName == L"仙朝鼎盛纪") {
        AddSocialThread(sectName + L"册封吏", L"仙朝耳目", L"礼貌试探",
            L"对方说是核验名册，实际在查你家世与前世旧名是否有关。", -6);
    }

    if (HasFactionTie()) {
        AddSocialThread(g_factionTie.name + L"联系人", L"势力牵连", g_factionTie.stance,
            g_factionTie.hook.empty() ? g_factionTie.obligation : g_factionTie.hook,
            g_factionTie.favor);
    }

    if (g_socialThreads.size() > 5) {
        SocialThread factionThread;
        bool hasFactionThread = false;
        for (const auto& thread : g_socialThreads) {
            if (thread.role == L"势力牵连") {
                factionThread = thread;
                hasFactionThread = true;
                break;
            }
        }
        g_socialThreads.resize(5);
        if (hasFactionThread) {
            bool kept = false;
            for (const auto& thread : g_socialThreads) {
                if (thread.role == L"势力牵连") {
                    kept = true;
                    break;
                }
            }
            if (!kept) {
                g_socialThreads[4] = factionThread;
            }
        }
    }
}

void GenerateSocialRumors() {
    g_socialRumors.clear();
    GenerateSocialThreads();
    int totalRoot = g_player.GetTotalRoot();
    int memoryBonus = g_legacySystem.GetLegacyBonus(LEGACY_MEMORY);
    int techniqueEcho = g_legacySystem.GetLegacyBonus(LEGACY_TECHNIQUE);
    int reputationEcho = g_legacySystem.GetLegacyBonus(LEGACY_REPUTATION);
    int treasureEcho = g_legacySystem.GetLegacyBonus(LEGACY_TREASURE);
    const LegacyItem* techniqueLegacy = nullptr;
    for (const auto& legacy : g_legacySystem.GetInheritedLegacies()) {
        if (legacy.type == LEGACY_TECHNIQUE) {
            techniqueLegacy = &legacy;
            break;
        }
    }

    if (totalRoot >= 42 || g_player.hasBalancedRoots) {
        g_socialRumors.push_back(L"族中长辈看过你的灵根后，语气明显软了几分，说你日后可争内门名额。");
        g_socialRumors.push_back(L"有同辈暗中不服，觉得你不过是仗着天资与家世被人高看。");
    } else if (totalRoot >= 32) {
        g_socialRumors.push_back(L"管事评价你资质尚可，愿意多给一次入门试炼的机会。");
        g_socialRumors.push_back(L"几个同龄修士把你当作可拉拢的人，却也在衡量你值不值得下注。");
    } else {
        g_socialRumors.push_back(L"测灵台旁有人低声嗤笑，觉得你的道途走不了太远。");
        g_socialRumors.push_back(L"一个外门少年故意抢走你的杂役牌，想看你敢不敢反抗。");
    }

    if (g_player.family.fame >= 55) {
        g_socialRumors.push_back(L"听闻你的姓氏后，有人主动递来拜帖，话里话外都想攀上旧交。");
        g_socialRumors.push_back(L"也有人避开你，像是忌惮你家中长辈留下的旧账。");
    } else if (!g_player.family.knowsParents) {
        g_socialRumors.push_back(L"有人盯着你的旧物看了很久，却在你发问前转身离开。");
    } else if (g_player.family.wealth <= 4) {
        g_socialRumors.push_back(L"坊市小厮见你衣着朴素，语气里少了几分耐心。");
    }

    if (memoryBonus >= 30) {
        g_socialRumors.push_back(L"你偶尔露出的眼神不像少年，令一位执事多看了你两眼。");
    }

    if (techniqueEcho >= 35) {
        wstring legendLabel = techniqueLegacy ? BuildTechniqueLegendLabel(*techniqueLegacy) : L"失传古法";
        g_socialRumors.push_back(L"藏经处有人翻出残页，低声说你的行功节奏像" + legendLabel +
            L"，不像少年自悟，更像旧法借今生重开。");
        g_socialRumors.push_back(BuildTechniqueEraInterpretation(legendLabel));
    }

    if (reputationEcho >= 30) {
        g_socialRumors.push_back(L"有人因前世善名的余波提前向你示好，话说得客气，却明显带着押注意味。");
    } else if (reputationEcho <= -30) {
        g_socialRumors.push_back(L"一页旧册在暗处流转，有人怀疑你与某个前世恶名重新连上了因果。");
    }

    if (g_worldEraName == L"灵机蒸汽纪") {
        g_socialRumors.push_back(L"坊市里新开的灵机工坊很抢眼，不少年轻修士都在谈论机关臂、飞梭匣与量产灵具。");
    } else if (g_worldEraName == L"星穹道网纪") {
        g_socialRumors.push_back(L"有人议论远方宗门通过灵网收徒，哪怕出身寒微，也可能一夜之间被大势卷走。");
    } else if (g_worldEraName == L"末法裂变纪") {
        g_socialRumors.push_back(L"老一辈都在感叹灵气不如从前，许多修士开始明争暗夺每一口能用来破境的资源。");
    } else if (g_worldEraName == L"废土返道纪") {
        g_socialRumors.push_back(L"荒野之外常有失控的古代灵机游荡，很多传承洞府因此成了拿命去换的机缘。");
    }

    if (treasureEcho >= 40) {
        g_socialRumors.push_back(L"你偶尔会对某些残破法宝生出异样熟悉感，像是它们曾在另一世陪你见过血与雷劫。");
    }

    if (HasFactionTie()) {
        g_socialRumors.push_back(g_factionTie.name + L"已经把你记入" + g_factionTie.role +
            L"名册，态度是“" + g_factionTie.stance + L"”。");
    }

    if (g_socialRumors.size() > 8) {
        g_socialRumors.resize(8);
    }
}

wstring GetSocialRumorText(int limit = 6) {
    wstringstream ss;
    ss << L"【人情风波】\n\n";
    if (g_socialThreads.empty() && g_socialRumors.empty()) {
        ss << L"暂时无人特别留意你。";
        return ss.str();
    }

    if (!g_socialThreads.empty()) {
        ss << L"【本世人脉】\n";
        ss << L"这些人会影响本世事件走向，也会被本地 AI 当作可续写的关系线。\n";
        ss << BuildSocialThreadDigest(6) << L"\n";
    }

    if (g_socialRumors.empty()) {
        return ss.str();
    }

    ss << L"【近日风声】\n";
    for (size_t i = 0; i < min<size_t>(g_socialRumors.size(), limit); i++) {
        ss << L"- " << g_socialRumors[i] << L"\n";
    }
    return ss.str();
}

wstring GetSocialDigest() {
    if (g_socialThreads.empty() && g_socialRumors.empty()) return L"暂无明显风波。";
    wstringstream ss;
    if (!g_socialThreads.empty()) {
        ss << L"本世人脉:\n" << BuildSocialThreadDigest(3);
    }
    if (!g_socialRumors.empty()) {
        ss << L"近日风声:\n";
    }
    for (size_t i = 0; i < min<size_t>(g_socialRumors.size(), 2); i++) {
        ss << L"- " << g_socialRumors[i] << L"\n";
    }
    return ss.str();
}

void InitWorldData() {
    g_worldData = g_procGen.GenerateWorld();

    auto addSect = [&](const wstring& name, const wstring& philosophy, const wstring& specialty,
                       const wstring& lore, int power) {
        GeneratedSect sect;
        sect.name = name;
        sect.philosophy = philosophy;
        sect.specialty = specialty;
        sect.lore = lore;
        sect.power = power;
        g_worldData.sects.insert(g_worldData.sects.begin(), sect);
    };

    auto addLocation = [&](const wstring& name, const wstring& type, int danger,
                           const wstring& desc) {
        GeneratedLocation loc;
        loc.name = name;
        loc.type = type;
        loc.dangerLevel = danger;
        loc.description = desc;
        g_worldData.locations.insert(g_worldData.locations.begin(), loc);
    };

    if (g_worldEraName == L"灵机蒸汽纪") {
        addSect(L"玄炉工造盟", L"工坊联盟", L"灵机炼器",
                L"由炼器师、机关师与散修资本共同组成，主张用量产灵具打破旧宗门垄断。", 8);
        addSect(L"太乙齿轮宗", L"技术道统", L"阵械推演",
                L"以齿轮阵列演算功法流转，认为机关术也是大道的一种旁门入口。", 7);
        addLocation(L"蒸汽灵石城", L"工坊城邦", 5,
                    L"灵石锅炉昼夜轰鸣，坊市、铸炉和修炼塔挤在同一片蒸汽里。");
        addLocation(L"废弃飞舟坞", L"灵机遗址", 7,
                    L"坠毁飞舟的残骸埋着旧航图，也常有失控机关护卫徘徊。");
    } else if (g_worldEraName == L"星穹道网纪") {
        addSect(L"星穹远讯院", L"道网学派", L"神识远讯",
                L"掌握跨洲灵网节点，能让寒门修士隔着万里参加入门试炼。", 9);
        addSect(L"万象数据阁", L"中立商会", L"因果记录",
                L"收集秘境坐标、修士战绩与旧案影像，出售的情报往往比法宝更贵。", 7);
        addLocation(L"九环灵网塔", L"道网节点", 6,
                    L"九层阵台同时接入大域灵网，越往上越容易听见不属于本洲的声音。");
        addLocation(L"坠星转运港", L"星舟港", 5,
                    L"跨洲飞舟在此起落，许多机缘先以一串远讯坐标的形式出现。");
    } else if (g_worldEraName == L"末法裂变纪") {
        addSect(L"枯井守盟", L"资源同盟", L"灵井镇守",
                L"由几家衰落宗门抱团而成，所有弟子都围绕灵井配给修行。", 6);
        addSect(L"替道机枢院", L"异端学派", L"阵械破境",
                L"他们认为苦修已不能适应末法，开始用阵械、药剂和因果借贷替代传统破境。", 8);
        addLocation(L"半枯灵井", L"争夺地", 8,
                    L"井中灵气时有时无，每一次涌动都会引来数方修士明争暗斗。");
        addLocation(L"裂法试验场", L"阵械禁地", 7,
                    L"地面刻满失败阵图，许多修士在这里换来了破境，也换来了短命。");
    } else if (g_worldEraName == L"废土返道纪") {
        addSect(L"返道拾荒盟", L"残宗同盟", L"废墟寻道",
                L"由幸存修士、拾荒者和旧宗门弟子组成，靠修复古代灵机维持法统。", 6);
        addSect(L"黑雨镇邪司", L"守序残部", L"邪祟镇压",
                L"他们在黑雨边界筑城，负责清理荒野邪祟和失控灵机。", 7);
        addLocation(L"黑雨边城", L"幸存城邦", 6,
                    L"城墙外是邪祟和废墟，城墙内则挤满试图重建秩序的人。");
        addLocation(L"归墟旧都", L"文明残骸", 9,
                    L"上一轮文明的中心已经坍塌，地下仍有道网残响和古机巡逻。");
    } else if (g_worldEraName == L"仙朝鼎盛纪") {
        addSect(L"天册仙朝", L"仙朝正统", L"气运册封",
                L"以皇朝法度统合宗门气运，册封、血脉与功勋共同决定修行上限。", 9);
        addSect(L"隐龙旧族", L"世家门阀", L"血脉秘术",
                L"他们表面臣服仙朝，暗中仍保存着上古道统和旧王血契。", 7);
        addLocation(L"气运金榜台", L"册封重地", 5,
                    L"修士在此受封，也在此被天下记录功过因果。");
        addLocation(L"王族血脉秘境", L"世家秘境", 7,
                    L"秘境只认血脉与功勋，却偶尔会把寒门修士也卷进去。");
    } else {
        addSect(L"古修问道宗", L"古典正宗", L"洞府传承",
                L"最早追索古修遗府的宗门之一，仍相信大道藏在秘境、天劫与心性之中。", 8);
        addLocation(L"初代古修遗府", L"上古洞府", 7,
                    L"灵气初盛时留下的洞府，许多传承尚未被后世宗门分割。");
    }
}

void GenerateFactionTie() {
    g_factionTie = FactionTie();

    const GeneratedSect* sect = nullptr;
    if (!g_worldData.sects.empty()) {
        int maxIndex = min<int>((int)g_worldData.sects.size() - 1, 2);
        int index = (g_player.family.fame >= 55 || g_player.family.wealth >= 18) ? 0 : Random(0, maxIndex);
        sect = &g_worldData.sects[index];
    }

    wstring baseName = sect ? sect->name : L"无名山门";
    wstring baseKind = sect ? (sect->philosophy + L" / " + sect->specialty) : L"散修势力";
    int totalRoot = g_player.GetTotalRoot();
    bool gifted = (totalRoot >= 40 || g_player.hasBalancedRoots);
    bool weak = (totalRoot < 30 && !g_player.hasBalancedRoots);
    bool hiddenBirth = !g_player.family.knowsParents || !g_player.family.secret.empty();

    int favor = g_player.family.fame / 3 + g_player.family.wealth / 4;
    favor += gifted ? 24 : (weak ? -18 : 6);
    favor += g_legacySystem.GetLegacyBonus(LEGACY_REPUTATION) / 8;
    favor = max(-80, min(90, favor));

    g_factionTie.name = baseName;
    g_factionTie.kind = baseKind;
    g_factionTie.favor = favor;
    g_factionTie.binding = hiddenBirth || g_player.family.fame >= 45 || g_player.family.origin == L"宗门附庸";

    if (hiddenBirth) {
        g_factionTie.obligation = L"对方掌握你身世或旧物线索，暂时不肯明说。";
    } else if (g_player.family.origin == L"宗门附庸") {
        g_factionTie.obligation = L"家中本就依附此势力，入道后需还一份供奉旧债。";
    } else if (g_player.family.fame >= 55) {
        g_factionTie.obligation = L"你的姓氏与此势力有旧交，也可能牵出旧仇。";
    } else if (weak) {
        g_factionTie.obligation = L"对方只愿给低阶差事，想看你能否熬过轻慢与杂役。";
    } else {
        g_factionTie.obligation = L"对方愿意给一次入局机会，但要看你如何偿还资源。";
    }

    if (g_worldEraName == L"灵机蒸汽纪") {
        g_factionTie.name = (sect && sect->name.find(L"盟") != wstring::npos) ? sect->name : baseName;
        g_factionTie.kind = L"灵机工坊 / 阵械合约";
        g_factionTie.role = gifted ? L"阵械功法试机人" : (weak ? L"低阶炉线学徒" : L"工坊合约候选");
        g_factionTie.stance = gifted ? L"热情押注" : (weak ? L"务实利用" : L"谨慎拉拢");
        g_factionTie.hook = L"他们想让你试用一套会记录经脉反馈的阵械功法，失败者往往寿元受损。";
    } else if (g_worldEraName == L"星穹道网纪") {
        g_factionTie.kind = L"道网节点 / 远讯试炼";
        g_factionTie.role = gifted ? L"远程试炼种子" : (weak ? L"榜单边缘记录者" : L"道网背调对象");
        g_factionTie.stance = gifted ? L"隔空下注" : (weak ? L"冷淡记录" : L"持续观察");
        g_factionTie.hook = L"对方已经把你的灵根、家世和前世异常录入道网，后续机缘会以远讯坐标出现。";
    } else if (g_worldEraName == L"末法裂变纪") {
        g_factionTie.kind = L"灵井配给 / 替道试验";
        g_factionTie.role = gifted ? L"灵井优先名额" : (weak ? L"配给末席" : L"阵械破境观察者");
        g_factionTie.stance = gifted ? L"争相拉拢" : (weak ? L"轻慢压价" : L"利益衡量");
        g_factionTie.hook = L"他们掌着一口半枯灵井，你得到的每份灵气都可能换来新的债。";
    } else if (g_worldEraName == L"废土返道纪") {
        g_factionTie.kind = L"残宗同盟 / 荒野护送";
        g_factionTie.role = gifted ? L"重建法统人选" : (weak ? L"迁徙队伍累赘" : L"废墟探索同伴");
        g_factionTie.stance = gifted ? L"现实重视" : (weak ? L"刻薄试探" : L"互利观望");
        g_factionTie.hook = L"残宗准备迁徙进一片旧都废墟，你的前世记忆可能决定整队能不能活着出来。";
    } else if (g_worldEraName == L"仙朝鼎盛纪") {
        g_factionTie.kind = L"仙朝名册 / 世家旧契";
        g_factionTie.role = gifted ? L"金榜预录名" : (weak ? L"旁支待核人" : L"册封候选");
        g_factionTie.stance = gifted ? L"礼重试探" : (weak ? L"居高临下" : L"规矩审视");
        g_factionTie.hook = L"仙朝名册似乎曾记录过与你相近的旧名，册封吏正在核验你的家世与前世因果。";
    } else {
        g_factionTie.kind = L"古典宗门 / 入门试炼";
        g_factionTie.role = gifted ? L"内门种子" : (weak ? L"杂役试炼者" : L"外门候选");
        g_factionTie.stance = gifted ? L"长辈认可" : (weak ? L"轻慢考验" : L"愿给机会");
        g_factionTie.hook = L"山门入门试炼会牵出你的家世旧债，也会决定第一批同辈是巴结你还是欺负你。";
    }
}

void GenerateLifeStoryHooks() {
    g_lifeStoryHooks.clear();

    wstring sectName = g_worldData.sects.empty() ? L"无名宗门" : g_worldData.sects[0].name;
    wstring locName = g_worldData.locations.empty() ? L"无名秘地" : g_worldData.locations[0].name;
    wstring familySecret = g_player.family.secret.empty() ? L"家中旧事无人提起" : g_player.family.secret;
    auto pastFragments = g_legacySystem.GetLatestMemoryFragments(2);
    auto unfinishedKarmas = g_legacySystem.GetLatestUnfinishedKarmas(2);
    const LegacyRelic& relic = g_legacySystem.GetRelic();

    if (g_worldEraName == L"灵机蒸汽纪") {
        g_lifePremise = L"你降生在灵机与旧修真秩序冲突最烈的年代，工坊、宗门与前世道痕都可能争夺你的去向。";
        g_lifeStoryHooks.push_back(L"灵机工坊正在追查一枚与通天灵宝器纹相似的旧图，而你的识海会对它发热。");
        g_lifeStoryHooks.push_back(sectName + L"与" + locName + L"之间有一条被封锁的飞舟旧航线。");
    } else if (g_worldEraName == L"星穹道网纪") {
        g_lifePremise = L"这一世的机缘会先以远讯、榜单和泄露影像出现，前世因果也可能被灵网重新翻出。";
        g_lifeStoryHooks.push_back(L"灵网节点偶尔会推送不属于今生的旧名，像是有人在隔世定位你。");
        g_lifeStoryHooks.push_back(sectName + L"掌握一段远程试炼入口，" + locName + L"则藏着对应的实体阵台。");
    } else if (g_worldEraName == L"末法裂变纪") {
        g_lifePremise = L"灵气衰落让每一份资源都带着血味，前世记忆会变成你判断谁可信的少数凭据。";
        g_lifeStoryHooks.push_back(L"有人提出用阵械替代苦修破境，但代价可能会折损寿元与因果。");
        g_lifeStoryHooks.push_back(sectName + L"正在争夺" + locName + L"，你的家世隐情可能成为入局筹码。");
    } else if (g_worldEraName == L"废土返道纪") {
        g_lifePremise = L"文明废墟、残宗迁徙和荒野邪祟构成这一世的底色，活下去本身就是修行。";
        g_lifeStoryHooks.push_back(L"荒野古机记录过某个前世片段，只有靠近废墟时才会断续回放。");
        g_lifeStoryHooks.push_back(sectName + L"想重建法统，" + locName + L"里的旧时代残响是关键。");
    } else if (g_worldEraName == L"仙朝鼎盛纪") {
        g_lifePremise = L"仙朝、世家和宗门共同瓜分气运，出身、册封与旧债会比单纯天资更早盯上你。";
        g_lifeStoryHooks.push_back(L"气运榜上偶尔出现与你道号相近的旧名，朝廷和宗门都想知道缘由。");
        g_lifeStoryHooks.push_back(sectName + L"与" + g_player.family.familyName + L"之间有未公开的册封旧契。");
    } else {
        g_lifePremise = L"这是古典修仙秩序尚强的一世，宗门、秘境、天劫与家世旧债仍是道途主轴。";
        g_lifeStoryHooks.push_back(sectName + L"正在寻找能进入" + locName + L"的人，你的灵根与家世都可能被盯上。");
        g_lifeStoryHooks.push_back(L"一处古修遗府与" + familySecret + L"隐隐相连。");
    }

    if (HasFactionTie()) {
        g_lifeStoryHooks.push_back(L"本世势力牵连：" + BuildFactionTieDigest());
    }

    g_lifeStoryHooks.push_back(L"伴生玉佩：" + BuildCompanionJadeVisibleText());

    if (!g_hongmengOmenTreasureName.empty()) {
        g_lifeStoryHooks.push_back(L"本世鸿蒙天象：" + BuildHongmengOmenBrief() +
            L"；此线只会留下投影、线索、参悟和遥远因果，不能获得或毁灭本体。");
    }

    if (!g_eraRemnants.empty()) {
        g_lifeStoryHooks.push_back(L"旧世残响：" + g_eraRemnants[0]);
    }

    if (!unfinishedKarmas.empty()) {
        g_lifeStoryHooks.push_back(L"前世未竟因果：" + unfinishedKarmas[0]);
    }

    if (!pastFragments.empty()) {
        g_lifeStoryHooks.push_back(L"前世碎片反复浮现：" + pastFragments[0]);
    } else {
        g_lifeStoryHooks.push_back(L"你还没有清晰前世记忆，但某些梦境会提前暗示未来取舍。");
    }

    if (relic.daoLinked || relic.resonance >= 80) {
        g_lifeStoryHooks.push_back(L"通天灵宝残印本世格外活跃，" + g_legacySystem.GetDaoContextText());
    } else if (!g_player.family.secret.empty()) {
        g_lifeStoryHooks.push_back(L"此世家世隐情：" + familySecret);
    }

    if (g_lifeStoryHooks.size() > 5) {
        g_lifeStoryHooks.resize(5);
    }
}

void AppendFamilySecret(FamilyBackground& family, const wstring& secret) {
    if (secret.empty()) return;
    if (family.secret.find(secret) != wstring::npos) return;
    if (family.secret.empty()) family.secret = secret;
    else family.secret += wstring(L"；") + secret;
}

void ClampFamilyBackground(FamilyBackground& family) {
    family.fame = max(-100, min(100, family.fame));
    family.wealth = max(0, min(60, family.wealth));
}

wstring ApplyInheritedLegacyToBirth() {
    auto& inherited = g_legacySystem.GetInheritedLegacies();
    int memoryBonus = g_legacySystem.GetLegacyBonus(LEGACY_MEMORY);
    int techniqueBonus = g_legacySystem.GetLegacyBonus(LEGACY_TECHNIQUE);
    int knowledgeBonus = g_legacySystem.GetLegacyBonus(LEGACY_KNOWLEDGE);
    int reputationBonus = g_legacySystem.GetLegacyBonus(LEGACY_REPUTATION);
    int treasureBonus = g_legacySystem.GetLegacyBonus(LEGACY_TREASURE);
    int relicBonus = g_legacySystem.GetRelicResonanceBonus();
    if (inherited.empty() && memoryBonus == 0 && techniqueBonus == 0 && knowledgeBonus == 0 &&
        reputationBonus == 0 && treasureBonus == 0 && relicBonus == 0) {
        return L"";
    }

    FamilyBackground& family = g_player.family;
    vector<wstring> notes;
    auto addNote = [&](const wstring& note) {
        if (!note.empty() && find(notes.begin(), notes.end(), note) == notes.end()) {
            notes.push_back(note);
        }
    };

    if (treasureBonus >= 35 || relicBonus >= 12) {
        if ((family.origin == L"寒门农户" || family.origin == L"坊市小族" || family.origin == L"孤儿") &&
            Random(1, 100) <= 65) {
            family.origin = Random(0, 1) == 0 ? L"隐秘血脉" : L"没落修真世家";
            if (family.familyName == L"无名" || family.familyName.empty()) {
                family.familyName = PickOne({L"沈氏旧族", L"陆氏旧族", L"顾氏旧族", L"林氏旧族"});
            }
        }
        family.fame += 8 + min(22, treasureBonus / 8 + relicBonus / 2);
        family.wealth += min(14, 4 + treasureBonus / 18 + relicBonus / 4);
        AppendFamilySecret(family, L"出生时曾有通天灵宝器纹一闪，家中长辈选择隐瞒");
        if (!family.knowsParents && family.guardian.empty()) {
            family.guardian = PickOne({L"护道旧仆", L"沉默剑修", L"外门执事"});
        }
        addNote(L"通天灵宝残印扰动今生出身，家族或养育者知道你身上有不可明说的器纹。");
    }

    if (memoryBonus >= 40) {
        family.fame += min(12, memoryBonus / 12);
        AppendFamilySecret(family, L"幼年常梦呓前世地名与旧债，旁人只当你早慧或中邪");
        addNote(L"前世记忆没有只变成数值，而是提前渗进幼年梦境和家中隐情。");
    }

    if (techniqueBonus >= 35) {
        family.fame += min(10, techniqueBonus / 16);
        family.wealth += min(6, techniqueBonus / 24);
        AppendFamilySecret(family, L"幼年行功姿势不像初学，疑似带着前世功法残影");
        addNote(L"前世功法传承会在今生行功、试炼和长辈观察中提前露出端倪。");
    }

    if (knowledgeBonus >= 35) {
        family.wealth += min(8, knowledgeBonus / 10);
        AppendFamilySecret(family, L"你无师自通地认得几种阵纹，已被附近势力暗中记录");
        addNote(L"前世经验让你显得不合年龄，工坊、宗门或道网更容易提前盯上你。");
    }

    if (reputationBonus >= 30) {
        family.fame += min(25, reputationBonus / 4);
        AppendFamilySecret(family, L"前世善名化作今生接引，有长辈愿意先给你一次机会");
        addNote(L"前世善名影响今生门第和长辈态度，不只是开局因果加成。");
    } else if (reputationBonus <= -30) {
        family.fame += max(-25, reputationBonus / 4);
        AppendFamilySecret(family, L"前世恶名被仇家旧册记下，今生尚未修行就有人试探");
        addNote(L"前世恶名追进今生身份，仇家和势力会更早借家世试探你。");
    }

    const LegacyRelic& relic = g_legacySystem.GetRelic();
    if (relic.daoLinked && relic.daoDepth >= 80) {
        AppendFamilySecret(family, wstring(L"旧玉简中反复出现") + relic.daoName + L"四字，父母或养育者不敢解释");
        family.fame += min(16, relic.daoDepth / 20);
        addNote(wstring(L"上一世证成的") + relic.daoName + L"成为今生身世谜团的一部分。");
    }

    if (!inherited.empty()) {
        wstringstream ss;
        ss << L"最先浮现的传承为";
        int count = 0;
        for (const auto& legacy : inherited) {
            if (count++ >= 2) break;
            if (count > 1) ss << L"、";
            ss << legacy.name;
        }
        ss << L"，它们会改变今生最早遇见的人和势力。";
        addNote(ss.str());
    }

    ClampFamilyBackground(family);
    if (notes.empty()) return L"";

    wstringstream out;
    for (size_t i = 0; i < notes.size(); ++i) {
        if (i > 0) out << L" ";
        out << notes[i];
    }
    return CompactMemoryFragment(out.str());
}

wstring ReadAiStatusFile(const wchar_t* fileName) {
    return ReadUtf8FileToWide(WideToUtf8(fileName));
}

vector<vector<wstring>> LoadItemDbRows() {
    wstring tsv = ReadUtf8FileToWide("..\\assets\\item_db.tsv");
    if (tsv.empty()) tsv = ReadUtf8FileToWide("item_db.tsv");
    if (tsv.empty()) tsv = ReadUtf8FileToWide("assets\\item_db.tsv");
    vector<vector<wstring>> rows;
    if (tsv.empty()) return rows;

    wstringstream ss(tsv);
    wstring line;
    getline(ss, line); // header
    while (getline(ss, line)) {
        if (line.empty()) continue;
        vector<wstring> cols;
        size_t start = 0;
        while (true) {
            size_t tab = line.find(L'\t', start);
            if (tab == wstring::npos) {
                cols.push_back(line.substr(start));
                break;
            }
            cols.push_back(line.substr(start, tab - start));
            start = tab + 1;
        }
        if (!cols.empty()) rows.push_back(cols);
    }
    return rows;
}

wstring LoadItemLoreDigest(int limit = 6) {
    auto rows = LoadItemDbRows();
    if (!rows.empty()) {
        wstringstream out;
        out << L"- 近来流传的器物:\n";
        int count = 0;
        for (auto& cols : rows) {
            if (count >= limit) break;
            if (cols.size() >= 8) {
                out << L"  * " << cols[1] << L"：" << cols[7] << L"\n";
                count++;
            }
        }
        return out.str();
    }

    wstring raw = ReadUtf8FileToWide("..\\assets\\item_lore.json");
    if (raw.empty()) raw = ReadUtf8FileToWide("assets\\item_lore.json");
    if (raw.empty()) return L"";

    vector<wstring> names;
    vector<wstring> uses;
    size_t pos = 0;
    while ((pos = raw.find(L"\"name\"", pos)) != wstring::npos) {
        size_t start = raw.find(L"\"", pos + 6);
        if (start == wstring::npos) break;
        start = raw.find(L"\"", start + 1);
        if (start == wstring::npos) break;
        size_t end = raw.find(L"\"", start + 1);
        if (end == wstring::npos) break;
        names.push_back(raw.substr(start + 1, end - start - 1));
        pos = end + 1;
    }

    pos = 0;
    while ((pos = raw.find(L"\"use\"", pos)) != wstring::npos) {
        size_t colon = raw.find(L":", pos);
        if (colon == wstring::npos) break;
        size_t start = raw.find(L"\"", colon);
        if (start == wstring::npos) break;
        size_t end = raw.find(L"\"", start + 1);
        if (end == wstring::npos) break;
        uses.push_back(raw.substr(start + 1, end - start - 1));
        pos = end + 1;
    }

    if (names.empty()) return L"";

    wstringstream ss;
    ss << L"- 近来流传的器物:\n";
    int count = min(limit, (int)names.size());
    for (int i = 0; i < count; ++i) {
        ss << L"  * " << names[i];
        if (i < (int)uses.size() && !uses[i].empty()) {
            ss << L"：" << uses[i];
        }
        ss << L"\n";
    }
    return ss.str();
}

wstring BuildItemCodexText() {
    auto rows = LoadItemDbRows();
    if (!rows.empty()) {
        wstringstream out;
        out << L"【灵物图录】\n\n";
        out << L"说明: 这里记录的是当世见闻。兵刃、材料、丹药与普通法宝都会随时代损毁或失散，不能像通天灵宝道痕那样跨世继承。\n\n";
        out << BuildLifeArtifactText() << L"\n\n";
        out << L"已见灵物: " << g_discoveredItems.size() << L" / " << rows.size() << L"\n\n";
        int index = 1;
        for (auto& cols : rows) {
            if (cols.size() >= 9) {
                out << L"[" << index++ << L"] " << cols[1] << L" · " << cols[4] << L"\n";
                out << cols[8] << L"\n";
                out << L"用途: " << cols[7] << L"\n\n";
            }
        }
        return out.str();
    }

    wstring raw = ReadUtf8FileToWide("..\\assets\\item_lore.json");
    if (raw.empty()) raw = ReadUtf8FileToWide("assets\\item_lore.json");
    if (raw.empty()) {
        return L"【灵物图录】\n\n当前尚未载入物品设定数据。";
    }

    vector<wstring> names;
    vector<wstring> tiers;
    vector<wstring> lores;
    vector<wstring> uses;
    size_t pos = 0;

    auto collectField = [&](const wstring& key, vector<wstring>& out) {
        size_t cursor = 0;
        while ((cursor = raw.find(key, cursor)) != wstring::npos) {
            size_t colon = raw.find(L":", cursor);
            if (colon == wstring::npos) break;
            size_t start = raw.find(L"\"", colon);
            if (start == wstring::npos) break;
            size_t end = raw.find(L"\"", start + 1);
            if (end == wstring::npos) break;
            out.push_back(raw.substr(start + 1, end - start - 1));
            cursor = end + 1;
        }
    };

    collectField(L"\"name\"", names);
    collectField(L"\"tier\"", tiers);
    collectField(L"\"lore\"", lores);
    collectField(L"\"use\"", uses);

    wstringstream ss;
    ss << L"【灵物图录】\n\n";
    ss << L"说明: 图录是当世见闻，不等于轮回传承。能跨世回响的只有记忆、因果、道痕与通天灵宝残印。\n\n";
    ss << BuildLifeArtifactText() << L"\n\n";
    int count = (int)names.size();
    for (int i = 0; i < count; ++i) {
        ss << L"[" << (i + 1) << L"] " << names[i];
        if (i < (int)tiers.size()) ss << L" · " << tiers[i];
        ss << L"\n";
        if (i < (int)lores.size()) ss << lores[i] << L"\n";
        if (i < (int)uses.size()) ss << L"用途: " << uses[i] << L"\n";
        ss << L"\n";
    }
    return ss.str();
}

wstring BuildItemCatalogDigest() {
    auto rows = LoadItemDbRows();
    if (!rows.empty()) {
        map<wstring, vector<wstring>> groups;
        map<wstring, wstring> labels = {
            {L"weapons", L"当世兵刃"},
            {L"artifacts", L"当世法宝"},
            {L"consumables", L"消耗品"},
            {L"materials", L"材料"},
        };
        for (auto& cols : rows) {
            if (cols.size() >= 3) {
                groups[cols[2]].push_back(cols[1]);
            }
        }

        wstringstream out;
        out << L"【灵物流传】\n";
        for (auto& pair : groups) {
            wstring label = labels.count(pair.first) ? labels[pair.first] : pair.first;
            out << L"- " << label << L": ";
            for (size_t i = 0; i < pair.second.size(); ++i) {
                if (i > 0) out << L"、";
                out << pair.second[i];
            }
            out << L"\n";
        }
        return out.str();
    }

    wstring raw = ReadUtf8FileToWide("..\\assets\\item_catalog.json");
    if (raw.empty()) raw = ReadUtf8FileToWide("assets\\item_catalog.json");
    if (raw.empty()) return L"";

    vector<pair<wstring, vector<wstring>>> groups;
    vector<wstring> keys = {L"weapons", L"artifacts", L"consumables", L"materials"};
    vector<wstring> labels = {L"当世兵刃", L"当世法宝", L"消耗品", L"材料"};

    for (size_t k = 0; k < keys.size(); ++k) {
        size_t pos = raw.find(L"\"" + keys[k] + L"\"");
        if (pos == wstring::npos) continue;
        size_t lbracket = raw.find(L"[", pos);
        size_t rbracket = raw.find(L"]", lbracket);
        if (lbracket == wstring::npos || rbracket == wstring::npos) continue;
        wstring block = raw.substr(lbracket, rbracket - lbracket);
        vector<wstring> names;
        size_t cursor = 0;
        while ((cursor = block.find(L"\"", cursor)) != wstring::npos) {
            size_t end = block.find(L"\"", cursor + 1);
            if (end == wstring::npos) break;
            names.push_back(block.substr(cursor + 1, end - cursor - 1));
            cursor = end + 1;
        }
        groups.push_back({labels[k], names});
    }

    if (groups.empty()) return L"";

    wstringstream ss;
    ss << L"【灵物流传】\n";
    for (auto& group : groups) {
        ss << L"- " << group.first << L": ";
        for (size_t i = 0; i < group.second.size(); ++i) {
            if (i > 0) ss << L"、";
            ss << group.second[i];
        }
        ss << L"\n";
    }
    return ss.str();
}

void RefreshAiStatus() {
    wstring backend = ReadAiStatusFile(L"ai_backend.txt");
    wstring status = ReadAiStatusFile(L"ai_status.txt");

    if (!backend.empty()) {
        g_lastAiBackend = backend;
    }
    if (!status.empty()) {
        g_lastAiStatus = status;
    }
}

bool TryRunLocalModelGenerator() {
    if (GetFileAttributesW(L"..\\ai_engine\\generate_event.ps1") == INVALID_FILE_ATTRIBUTES) {
        g_lastAiBackend = L"模板回退";
        g_lastAiStatus = L"缺少 ai_engine/generate_event.ps1，已直接使用内置模板事件。";
        return false;
    }

    DeleteFileW(L"ai_event.txt");
    DeleteFileW(L"ai_status.txt");
    DeleteFileW(L"ai_backend.txt");
    int exitCode = _wsystem(L"powershell -NoProfile -ExecutionPolicy Bypass -File \"..\\ai_engine\\generate_event.ps1\" -ReleaseDir \".\" -Model \"wendao-xiuxian\" > ai_model.log 2>&1");
    RefreshAiStatus();
    if (exitCode != 0 && g_lastAiStatus == L"本局尚未触发动态事件。") {
        g_lastAiBackend = L"模板回退";
        g_lastAiStatus = L"本地模型脚本执行失败，已回退到内置模板事件。";
    }
    return exitCode == 0;
}

void KillAiProcessTree() {
    if (!g_aiProcessInfo.hProcess || g_aiProcessInfo.dwProcessId == 0) return;
    wstring command = L"taskkill /F /T /PID " + to_wstring(g_aiProcessInfo.dwProcessId) + L" > nul 2>&1";
    _wsystem(command.c_str());
}

void CloseAiProcessHandles() {
    if (g_aiProcessInfo.hProcess) {
        CloseHandle(g_aiProcessInfo.hProcess);
    }
    if (g_aiProcessInfo.hThread) {
        CloseHandle(g_aiProcessInfo.hThread);
    }
    g_aiProcessInfo = {};
    g_aiProcessRunning = false;
}

bool BeginLocalModelGeneratorAsync() {
    if (GetFileAttributesW(L"..\\ai_engine\\generate_event.ps1") == INVALID_FILE_ATTRIBUTES) {
        g_lastAiBackend = L"模板回退";
        g_lastAiStatus = L"缺少 ai_engine/generate_event.ps1，已直接使用内置模板事件。";
        return false;
    }

    if (g_aiProcessRunning) {
        KillAiProcessTree();
        KillTimer(g_hWnd, IDT_AI_POLL);
        CloseAiProcessHandles();
    }

    DeleteFileW(L"ai_event.txt");
    DeleteFileW(L"ai_status.txt");
    DeleteFileW(L"ai_backend.txt");

    wstring command = L"cmd.exe /c powershell -NoProfile -ExecutionPolicy Bypass "
        L"-File \"..\\ai_engine\\generate_event.ps1\" -ReleaseDir \".\" "
        L"-Model \"wendao-xiuxian\" > ai_model.log 2>&1";
    vector<wchar_t> commandBuffer(command.begin(), command.end());
    commandBuffer.push_back(L'\0');

    STARTUPINFOW startupInfo = {};
    startupInfo.cb = sizeof(startupInfo);
    startupInfo.dwFlags = STARTF_USESHOWWINDOW;
    startupInfo.wShowWindow = SW_HIDE;

    PROCESS_INFORMATION processInfo = {};
    BOOL started = CreateProcessW(
        nullptr,
        commandBuffer.data(),
        nullptr,
        nullptr,
        FALSE,
        CREATE_NO_WINDOW,
        nullptr,
        nullptr,
        &startupInfo,
        &processInfo
    );

    if (!started) {
        g_lastAiBackend = L"模板回退";
        g_lastAiStatus = L"本地模型进程启动失败，已回退到内置模板事件。";
        return false;
    }

    g_aiProcessInfo = processInfo;
    g_aiProcessRunning = true;
    g_aiStartTick = GetTickCount();
    g_lastAiBackend = L"portable-llama.cpp";
    g_lastAiStatus = L"本地模型正在推演此世因果，完成后会自动显出事件。";
    SetTimer(g_hWnd, IDT_AI_POLL, 500, nullptr);
    return true;
}

void EnterAiEventFromContext(PlayerContext ctx) {
    wstring aiTitle;
    wstring aiDesc;
    vector<wstring> aiChoices;
    if (g_aiGen.TryLoadExternalEvent(aiTitle, aiDesc, aiChoices)) {
        if (g_lastAiBackend.empty()) {
            g_lastAiBackend = L"本地模型";
        }
        if (g_lastAiStatus.empty() || g_lastAiStatus == L"本局尚未触发动态事件。") {
            g_lastAiStatus = L"成功生成 1 条动态事件。";
        }
        AddMemory(L"本地模型回应", L"读取 ai_event.txt 生成动态事件。后端：" + g_lastAiBackend);
    } else {
        if (g_lastAiBackend.empty() || g_lastAiBackend == L"未触发" || g_lastAiBackend == L"portable-llama.cpp") {
            g_lastAiBackend = L"模板回退";
        }
        if (g_lastAiStatus.empty() || g_lastAiStatus == L"本局尚未触发动态事件。" ||
            g_lastAiStatus.find(L"正在推演") != wstring::npos) {
            g_lastAiStatus = L"未读取到有效 ai_event.txt，已回退到内置模板事件。";
        }
        AddMemory(L"动态事件回退", g_lastAiStatus);
        aiTitle = g_aiGen.GenerateEventTitle(ctx);
        aiDesc = g_aiGen.GenerateEventDescription(ctx);
        aiChoices = g_aiGen.GenerateChoices(ctx);
    }

    Event tempEvent;
    tempEvent.title = aiTitle;
    tempEvent.description = aiDesc;
    for (auto& choice : aiChoices) {
        Choice c;
        c.description = choice;
        c.outcomes.push_back(L"成功");
        c.outcomes.push_back(L"失败");
        c.karmaChange = 0;
        tempEvent.choices.push_back(c);
    }

    g_contextMgr.SetContext(ctx);

    static Event s_aiEvent;
    s_aiEvent = tempEvent;
    g_currentEvent = &s_aiEvent;
    g_gameState = STATE_EVENT;
}

void CompleteLocalModelGenerator(DWORD exitCode) {
    KillTimer(g_hWnd, IDT_AI_POLL);
    CloseAiProcessHandles();
    RefreshAiStatus();
    if (exitCode != 0 && g_lastAiStatus.find(L"正在推演") != wstring::npos) {
        g_lastAiBackend = L"模板回退";
        g_lastAiStatus = L"本地模型脚本执行失败，已回退到内置模板事件。";
    }
    EnterAiEventFromContext(g_pendingAiContext);
    InvalidateRect(g_hWnd, NULL, FALSE);
}

void CancelLocalModelGenerator() {
    if (g_aiProcessRunning) {
        KillAiProcessTree();
        KillTimer(g_hWnd, IDT_AI_POLL);
        CloseAiProcessHandles();
    }
    g_lastAiBackend = L"模板回退";
    g_lastAiStatus = L"本地模型推演已取消。";
}

wstring GetGeneratedWorldText() {
    wstringstream ss;
    ss << L"【宗门与秘境】\n\n";
    ss << L"宗门:\n";
    for (size_t i = 0; i < min<size_t>(g_worldData.sects.size(), 5); i++) {
        auto& sect = g_worldData.sects[i];
        ss << L"- " << sect.name << L"（" << sect.philosophy << L" / " << sect.specialty << L"）\n";
        if (!sect.lore.empty()) {
            ss << L"  " << sect.lore << L"\n";
        }
    }
    ss << L"\n地点:\n";
    for (size_t i = 0; i < min<size_t>(g_worldData.locations.size(), 6); i++) {
        auto& loc = g_worldData.locations[i];
        ss << L"- " << loc.name << L"（" << loc.type << L"，危险度" << loc.dangerLevel << L"）\n";
        if (!loc.description.empty()) {
            ss << L"  " << loc.description << L"\n";
        }
    }
    return ss.str();
}

wstring GetWorldInfoText() {
    wstringstream ss;
    ss << GetEraSummaryText() << L"\n\n";
    ss << g_dynamicWorld.GetWorldSummary() << L"\n";
    ss << BuildHongmengOmenText() << L"\n";

    auto activeEvent = g_dynamicWorld.GetActiveWorldEvent();
    ss << L"【当世大势】\n";
    if (activeEvent) {
        ss << activeEvent->title << L"\n";
        ss << activeEvent->description << L"\n";
        ss << L"余波: " << activeEvent->turnsRemaining << L"年\n";
    } else {
        ss << L"暂无线索足以撼动天下。\n";
    }

    auto npcs = g_dynamicWorld.GetAliveNPCs();
    ss << L"\n【活跃修士】\n";
    ss << L"以下为外显或传闻修为，不排除有人藏拙。\n";
    int count = 0;
    for (auto npc : npcs) {
        if (count++ >= 8) break;
        ss << L"- " << npc->name
           << L" · 外显 " << GetRealmName(static_cast<Realm>(npc->shownRealm))
           << L" " << npc->level << L"层"
           << L" · " << g_dynamicWorld.GetGoalText(npc->goal);
        if (npc->shownRealm < npc->realm) ss << L" · 气机不明";
        if (!npc->ally.empty()) ss << L" · 盟友 " << npc->ally;
        if (!npc->enemy.empty()) ss << L" · 仇敌 " << npc->enemy;
        ss << L"\n";
    }
    if (count == 0) ss << L"- 暂无活跃修士。\n";

    ss << L"\n" << g_dynamicWorld.GetRecentHistoryText(6) << L"\n";
    ss << L"\n" << GetGeneratedWorldText();
    ss << L"\n" << BuildHongmengTreasureSummary(4);
    return ss.str();
}

wstring GetLegacyInfoText() {
    return GetEraSummaryText() + L"\n\n" +
           g_legacySystem.GetHistoryText() + L"\n\n" +
           g_legacySystem.GetInheritedLegaciesText() + L"\n\n" +
           GetHeavenlyDaoRequirementText() + L"\n\n" +
           BuildHongmengTreasuresText() + L"\n\n" +
           g_achievementSystem.GetAchievementsText();
}

void OpenInfoPage(const wstring& title, const wstring& text, GameState returnState = STATE_GAME) {
    g_infoTitle = title;
    g_infoText = text;
    g_infoReturnState = returnState;
    g_infoScroll = 0;
    g_gameState = STATE_INFO;
}

void ShowNotice(const wstring& title, const wstring& text) {
    OpenInfoPage(title, text, STATE_GAME);
}

void ReturnFromInfoPage() {
    g_gameState = g_infoReturnState;
    g_infoTitle.clear();
    g_infoText.clear();
}

PlayerContext BuildPlayerContext() {
    PlayerContext ctx;
    ctx.name = g_player.name;
    ctx.realm = g_player.realm;
    ctx.realmName = GetRealmName(g_player.realm);
    ctx.karma = g_player.karma;
    ctx.age = g_player.age;
    ctx.rootState = g_player.GetRootQuality() + L"；" + g_player.GetRootDetails();
    ctx.familyState = GetFamilySummary(g_player.family);
    if (g_player.family.knowsParents) {
        ctx.familyState += L"；父亲:" + g_player.family.father + L"；母亲:" + g_player.family.mother;
    } else {
        ctx.familyState += L"；父母身份被隐去";
    }
    if (!g_player.family.guardian.empty()) {
        ctx.familyState += L"；养育者:" + g_player.family.guardian;
    }
    if (!g_player.family.secret.empty()) {
        ctx.familyState += L"；隐情:" + g_player.family.secret;
    }
    ctx.familyState += L"；伴生玉佩:" + BuildCompanionJadeVisibleText();
    if (HasFactionTie()) {
        ctx.familyState += L"；本世势力:" + g_factionTie.name + L"(" + g_factionTie.role + L")";
    }
    ctx.socialState = GetSocialDigest();
    for (const auto& thread : g_socialThreads) {
        ctx.relationships[thread.name + L"（" + thread.role + L"）"] = thread.relation;
    }
    for (auto npc : g_dynamicWorld.GetAliveNPCs()) {
        if (npc->playerRelation != 0) {
            ctx.relationships[npc->name + L"（活跃修士）"] = npc->playerRelation;
        }
    }
    ctx.killCount = g_player.battlesWon;
    ctx.helpCount = max(0, g_player.karma / 10);
    ctx.betrayalCount = max(0, -g_player.karma / 10);

    if (g_player.karma >= 50) {
        ctx.personality.push_back(L"善缘深重");
    } else if (g_player.karma <= -50) {
        ctx.personality.push_back(L"因果沉重");
    }
    if (g_player.battlesWon >= 3) {
        ctx.personality.push_back(L"杀伐果断");
    }
    if (g_player.totalEvents >= 5) {
        ctx.personality.push_back(L"久经历练");
    }

    int memoryStart = max(0, (int)g_memoryLog.size() - 8);
    for (int i = memoryStart; i < (int)g_memoryLog.size(); i++) {
        ctx.history.push_back(g_memoryLog[i]);
    }
    auto inheritedMemoryFragments = g_legacySystem.GetLatestMemoryFragments(4);
    for (const auto& fragment : inheritedMemoryFragments) {
        if (find(ctx.history.begin(), ctx.history.end(), fragment) == ctx.history.end()) {
            ctx.history.push_back(L"前世碎片：" + fragment);
        }
    }

    wstringstream legacy;
    auto& inherited = g_legacySystem.GetInheritedLegacies();
    if (!inherited.empty()) {
        legacy << L"当前继承的传承:\n";
        for (size_t i = 0; i < min<size_t>(inherited.size(), 4); i++) {
            legacy << L"- " << inherited[i].name << L"：" << inherited[i].description << L"\n";
        }
        for (const auto& item : inherited) {
            if (item.type == LEGACY_TECHNIQUE) {
                wstring legendLabel = BuildTechniqueLegendLabel(item);
                legacy << L"失传古法当世解读: " << BuildTechniqueEraInterpretation(legendLabel) << L"\n";
                break;
            }
        }
    }

    auto& pastLives = g_legacySystem.GetPastLives();
    if (!pastLives.empty()) {
        legacy << L"最近前世记录:\n";
        int start = max(0, (int)pastLives.size() - 2);
        for (int i = start; i < (int)pastLives.size(); i++) {
            const auto& life = pastLives[i];
            legacy << L"- 第" << life.generation << L"世，止步于"
                   << GetRealmName(static_cast<Realm>(life.realmReached))
                   << L"，死因是" << life.causeOfDeath << L"\n";
        }
    }
    if (!g_reincarnationEcho.empty()) {
        legacy << L"轮回余烬: " << g_reincarnationEcho << L"\n";
    }
    legacy << BuildCompanionJadeHiddenContext() << L"\n";
    wstring memoryContext = g_legacySystem.GetMemoryContextText(6);
    if (!memoryContext.empty()) {
        legacy << memoryContext;
    }
    wstring unfinishedContext = g_legacySystem.GetUnfinishedKarmaText(5);
    if (!unfinishedContext.empty()) {
        legacy << unfinishedContext;
    }
    legacy << L"时代变迁: " << g_eraTransitionNote << L"\n";
    legacy << L"纪元转折: " << g_eraShiftCause << L"\n";
    if (!g_eraChronicle.empty()) {
        legacy << BuildEraChronicleText(5);
    }
    if (!g_eraRemnants.empty()) {
        legacy << BuildEraRemnantsText(4);
    }
    legacy << g_legacySystem.GetDaoContextText() << L"\n";
    legacy << BuildDaoPassiveText() << L"\n";
    legacy << BuildHongmengContextText() << L"\n";
    ctx.legacyState = legacy.str();
    ctx.daoState = g_legacySystem.GetDaoContextText() + L"\n" +
                   BuildDaoPassiveText() + L"\n" +
                   GetHeavenlyDaoRequirementText() + L"\n" +
                   BuildHongmengContextText();

    wstringstream world;
    world << L"- 时代纪元: " << g_worldEraName << L"\n";
    world << L"- 时代概况: " << g_worldEraDescription << L"\n";
    world << L"- 时代法则: " << g_worldEraRule << L"\n";
    world << L"- 时代变迁: " << g_eraTransitionNote << L"\n";
    world << L"- 纪元转折因由: " << g_eraShiftCause << L"\n";
    world << L"- 伴生玉佩: " << BuildCompanionJadeVisibleText() << L"\n";
    world << L"- 鸿蒙天象: " << BuildHongmengOmenBrief() << L"\n";
    world << L"- 天象影响: " << g_hongmengOmenInfluence << L"\n";
    if (!g_eraChronicle.empty()) {
        world << L"- 纪元年表:\n";
        int start = max(0, (int)g_eraChronicle.size() - 5);
        for (int i = start; i < (int)g_eraChronicle.size(); ++i) {
            world << L"  * " << g_eraChronicle[i] << L"\n";
        }
    }
    if (!g_eraRemnants.empty()) {
        world << L"- 旧世残响:\n";
        for (const auto& remnant : g_eraRemnants) {
            world << L"  * " << remnant << L"\n";
        }
    }
    world << L"- 本世主线: " << g_lifePremise << L"\n";
    if (HasFactionTie()) {
        world << L"- 本世势力牵连: " << BuildFactionTieDigest() << L"\n";
    }
    if (!g_lifeStoryHooks.empty()) {
        world << L"- 本世持续线索:\n";
        for (const auto& hook : g_lifeStoryHooks) {
            world << L"  * " << hook << L"\n";
        }
    }
    world << L"- 轮回余烬: " << g_reincarnationEcho << L"\n";
    world << L"- 寿元压力: " << BuildLifespanPressureText() << L"\n";
    world << L"- 道祖-天道境进度: " << GetHeavenlyDaoProgressScore() << L" / 360\n";
    world << L"- 鸿蒙参悟: " << CountHongmengInsightKinds() << L" / 9\n";
    world << L"- 世界时间: 第" << g_dynamicWorld.GetWorldTime() << L"年\n";
    auto activeEvent = g_dynamicWorld.GetActiveWorldEvent();
    if (activeEvent) {
        world << L"- 重大事件: " << activeEvent->title
              << L"（剩余" << activeEvent->turnsRemaining << L"回合）\n";
        world << L"- 事件影响: " << activeEvent->description << L"\n";
    } else {
        world << L"- 重大事件: 当前无重大事件\n";
    }

    auto aliveNpcs = g_dynamicWorld.GetAliveNPCs();
    if (!aliveNpcs.empty()) {
        world << L"- 活跃修士传闻修为: ";
        for (size_t i = 0; i < min<size_t>(aliveNpcs.size(), 3); i++) {
            if (i > 0) world << L"、";
            world << aliveNpcs[i]->name << L"(外显" << GetRealmName(static_cast<Realm>(aliveNpcs[i]->shownRealm))
                  << L"，" << g_dynamicWorld.GetGoalText(aliveNpcs[i]->goal) << L")";
        }
        world << L"，不排除隐藏实力\n";
    }
    auto recentWorldEvents = g_dynamicWorld.GetRecentHistoryEntries(5);
    if (!recentWorldEvents.empty()) {
        world << L"- 近年大事:\n";
        for (const auto& entry : recentWorldEvents) {
            world << L"  * " << entry << L"\n";
        }
    }

    if (!g_worldData.sects.empty()) {
        world << L"- 近旁宗门:\n";
        for (size_t i = 0; i < min<size_t>(g_worldData.sects.size(), 2); i++) {
            const auto& sect = g_worldData.sects[i];
            world << L"  * " << sect.name << L"(" << sect.philosophy << L"/" << sect.specialty << L")";
            if (!sect.lore.empty()) {
                world << L": " << sect.lore;
            }
            world << L"\n";
        }
    }

    if (!g_worldData.locations.empty()) {
        world << L"- 可闻地点:\n";
        for (size_t i = 0; i < min<size_t>(g_worldData.locations.size(), 2); i++) {
            const auto& loc = g_worldData.locations[i];
            world << L"  * " << loc.name << L"(" << loc.type << L"，危" << loc.dangerLevel << L")";
            if (!loc.description.empty()) {
                world << L": " << loc.description;
            }
            world << L"\n";
        }
    }

    if (!g_lifeArtifacts.empty()) {
        world << L"- 本世器物:\n" << BuildLifeArtifactDigest(5);
        world << L"- 器物规则: 当世兵刃和普通法宝本体不能跨世，转世后只可能留下记忆、器痕或通天灵宝残印。\n";
    }

    wstring itemLoreDigest = LoadItemLoreDigest();
    if (!itemLoreDigest.empty()) {
        world << itemLoreDigest;
    }
    wstring itemCatalogDigest = BuildItemCatalogDigest();
    if (!itemCatalogDigest.empty()) {
        world << itemCatalogDigest;
    }

    ctx.worldState = world.str();
    return ctx;
}

void AdvanceDynamicWorld(const wstring& reason) {
    vector<wstring> before = g_dynamicWorld.GetRecentHistoryEntries(8);
    g_dynamicWorld.Update();
    vector<wstring> after = g_dynamicWorld.GetRecentHistoryEntries(8);

    int added = 0;
    for (const auto& entry : after) {
        if (find(before.begin(), before.end(), entry) != before.end()) continue;
        AddMemory(L"天下大事", entry + L"（" + reason + L"后传来）");
        added++;
        if (added >= 3) break;
    }
    bool socialChanged = PulseSocialEmotions(reason);
    if (added > 0 || socialChanged) {
        g_contextMgr.SetContext(BuildPlayerContext());
    }
}

void SaveGeneratedWorld(wofstream& file) {
    file << L"GENERATED_WORLD_V1\n";

    file << g_worldData.sects.size() << L"\n";
    for (auto& sect : g_worldData.sects) {
        file << sect.name << L"\n" << sect.philosophy << L"\n" << sect.specialty << L"\n"
             << sect.lore << L"\n" << sect.power << L"\n";
    }

    file << g_worldData.locations.size() << L"\n";
    for (auto& loc : g_worldData.locations) {
        file << loc.name << L"\n" << loc.type << L"\n" << loc.dangerLevel << L"\n"
             << loc.description << L"\n";
    }

    file << g_worldData.npcNames.size() << L"\n";
    for (auto& name : g_worldData.npcNames) {
        file << name << L"\n";
    }
}

bool LoadGeneratedWorld(wifstream& file) {
    wstring marker;
    getline(file, marker);
    if (marker.empty()) getline(file, marker);
    if (marker != L"GENERATED_WORLD_V1") return false;

    size_t count = 0;
    file >> count;
    file.ignore(numeric_limits<streamsize>::max(), L'\n');
    g_worldData.sects.clear();
    for (size_t i = 0; i < count; i++) {
        GeneratedSect sect;
        getline(file, sect.name);
        getline(file, sect.philosophy);
        getline(file, sect.specialty);
        getline(file, sect.lore);
        file >> sect.power;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        g_worldData.sects.push_back(sect);
    }

    file >> count;
    file.ignore(numeric_limits<streamsize>::max(), L'\n');
    g_worldData.locations.clear();
    for (size_t i = 0; i < count; i++) {
        GeneratedLocation loc;
        getline(file, loc.name);
        getline(file, loc.type);
        file >> loc.dangerLevel;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        getline(file, loc.description);
        g_worldData.locations.push_back(loc);
    }

    file >> count;
    file.ignore(numeric_limits<streamsize>::max(), L'\n');
    g_worldData.npcNames.clear();
    for (size_t i = 0; i < count; i++) {
        wstring name;
        getline(file, name);
        g_worldData.npcNames.push_back(name);
    }
    return true;
}

void SaveFamily(wofstream& file, const FamilyBackground& bg) {
    file << L"FAMILY_V1\n";
    file << bg.origin << L"\n";
    file << bg.familyName << L"\n";
    file << bg.father << L"\n";
    file << bg.mother << L"\n";
    file << bg.guardian << L"\n";
    file << bg.secret << L"\n";
    file << bg.fame << L" " << bg.wealth << L" " << bg.knowsParents << L" " << bg.adopted << L"\n";
}

bool LoadFamily(wifstream& file, FamilyBackground& bg) {
    wstring marker;
    getline(file, marker);
    if (marker.empty()) getline(file, marker);
    if (marker != L"FAMILY_V1") return false;

    getline(file, bg.origin);
    getline(file, bg.familyName);
    getline(file, bg.father);
    getline(file, bg.mother);
    getline(file, bg.guardian);
    getline(file, bg.secret);
    file >> bg.fame >> bg.wealth >> bg.knowsParents >> bg.adopted;
    file.ignore(numeric_limits<streamsize>::max(), L'\n');
    return true;
}

void SaveWorldEra(wofstream& file) {
    file << L"WORLD_ERA_V7\n";
    file << EscapeSaveField(g_worldEraName) << L"\n";
    file << EscapeSaveField(g_worldEraDescription) << L"\n";
    file << EscapeSaveField(g_worldEraRule) << L"\n";
    file << EscapeSaveField(g_reincarnationEcho) << L"\n";
    file << EscapeSaveField(g_eraTransitionNote) << L"\n";
    file << EscapeSaveField(g_lifePremise) << L"\n";
    file << g_lifeStoryHooks.size() << L"\n";
    for (auto& hook : g_lifeStoryHooks) {
        file << EscapeSaveField(hook) << L"\n";
    }
    file << g_eraRemnants.size() << L"\n";
    for (auto& remnant : g_eraRemnants) {
        file << EscapeSaveField(remnant) << L"\n";
    }
    file << g_eraChronicle.size() << L"\n";
    for (auto& entry : g_eraChronicle) {
        file << EscapeSaveField(entry) << L"\n";
    }
    file << EscapeSaveField(g_factionTie.name) << L"\n";
    file << EscapeSaveField(g_factionTie.kind) << L"\n";
    file << EscapeSaveField(g_factionTie.role) << L"\n";
    file << EscapeSaveField(g_factionTie.stance) << L"\n";
    file << EscapeSaveField(g_factionTie.obligation) << L"\n";
    file << EscapeSaveField(g_factionTie.hook) << L"\n";
    file << g_factionTie.favor << L" " << g_factionTie.binding << L"\n";
    file << EscapeSaveField(g_eraShiftCause) << L"\n";
    file << EscapeSaveField(g_hongmengOmenTreasureName) << L"\n";
    file << EscapeSaveField(g_hongmengOmenDao) << L"\n";
    file << EscapeSaveField(g_hongmengOmenManifestation) << L"\n";
    file << EscapeSaveField(g_hongmengOmenInfluence) << L"\n";
}

bool LoadWorldEra(wifstream& file) {
    wstring marker;
    getline(file, marker);
    if (marker.empty()) getline(file, marker);
    bool isV2 = (marker == L"WORLD_ERA_V2");
    bool isV3 = (marker == L"WORLD_ERA_V3");
    bool isV4 = (marker == L"WORLD_ERA_V4");
    bool isV5 = (marker == L"WORLD_ERA_V5");
    bool isV6 = (marker == L"WORLD_ERA_V6");
    bool isV7 = (marker == L"WORLD_ERA_V7");
    if (marker != L"WORLD_ERA_V1" && !isV2 && !isV3 && !isV4 && !isV5 && !isV6 && !isV7) return false;

    getline(file, g_worldEraName);
    getline(file, g_worldEraDescription);
    getline(file, g_worldEraRule);
    getline(file, g_reincarnationEcho);
    getline(file, g_eraTransitionNote);
    if (isV2 || isV3 || isV4 || isV5 || isV6 || isV7) {
        g_worldEraName = UnescapeSaveField(g_worldEraName);
        g_worldEraDescription = UnescapeSaveField(g_worldEraDescription);
        g_worldEraRule = UnescapeSaveField(g_worldEraRule);
        g_reincarnationEcho = UnescapeSaveField(g_reincarnationEcho);
        g_eraTransitionNote = UnescapeSaveField(g_eraTransitionNote);
        getline(file, g_lifePremise);
        g_lifePremise = UnescapeSaveField(g_lifePremise);
        size_t hookCount = 0;
        file >> hookCount;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        g_lifeStoryHooks.clear();
        for (size_t i = 0; i < hookCount; ++i) {
            wstring hook;
            getline(file, hook);
            g_lifeStoryHooks.push_back(UnescapeSaveField(hook));
        }
        g_eraRemnants.clear();
        if (isV3 || isV4 || isV5 || isV6 || isV7) {
            size_t remnantCount = 0;
            file >> remnantCount;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
            for (size_t i = 0; i < remnantCount; ++i) {
                wstring remnant;
                getline(file, remnant);
                g_eraRemnants.push_back(UnescapeSaveField(remnant));
            }
        }
        g_eraChronicle.clear();
        if (isV4 || isV5 || isV6 || isV7) {
            size_t chronicleCount = 0;
            file >> chronicleCount;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
            for (size_t i = 0; i < chronicleCount; ++i) {
                wstring entry;
                getline(file, entry);
                g_eraChronicle.push_back(UnescapeSaveField(entry));
            }
        }
        g_factionTie = FactionTie();
        if (isV5 || isV6 || isV7) {
            getline(file, g_factionTie.name);
            getline(file, g_factionTie.kind);
            getline(file, g_factionTie.role);
            getline(file, g_factionTie.stance);
            getline(file, g_factionTie.obligation);
            getline(file, g_factionTie.hook);
            g_factionTie.name = UnescapeSaveField(g_factionTie.name);
            g_factionTie.kind = UnescapeSaveField(g_factionTie.kind);
            g_factionTie.role = UnescapeSaveField(g_factionTie.role);
            g_factionTie.stance = UnescapeSaveField(g_factionTie.stance);
            g_factionTie.obligation = UnescapeSaveField(g_factionTie.obligation);
            g_factionTie.hook = UnescapeSaveField(g_factionTie.hook);
            file >> g_factionTie.favor >> g_factionTie.binding;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
        }
        if (isV6 || isV7) {
            getline(file, g_eraShiftCause);
            g_eraShiftCause = UnescapeSaveField(g_eraShiftCause);
        } else {
            g_eraShiftCause = L"旧存档没有记录纪元转折因由，只能从残留的时代变迁中推断。";
        }
        if (isV7) {
            getline(file, g_hongmengOmenTreasureName);
            getline(file, g_hongmengOmenDao);
            getline(file, g_hongmengOmenManifestation);
            getline(file, g_hongmengOmenInfluence);
            g_hongmengOmenTreasureName = UnescapeSaveField(g_hongmengOmenTreasureName);
            g_hongmengOmenDao = UnescapeSaveField(g_hongmengOmenDao);
            g_hongmengOmenManifestation = UnescapeSaveField(g_hongmengOmenManifestation);
            g_hongmengOmenInfluence = UnescapeSaveField(g_hongmengOmenInfluence);
        } else {
            GenerateHongmengOmen();
        }
    } else {
        g_lifePremise = L"此世主线来自旧存档，尚未记录明确线索。";
        g_lifeStoryHooks.clear();
        g_eraRemnants.clear();
        g_eraChronicle.clear();
        g_factionTie = FactionTie();
        g_eraShiftCause = L"旧存档没有记录纪元转折因由。";
        GenerateHongmengOmen();
    }
    return true;
}

// ==================== 存档系统 ====================
void SaveGame() {
    wofstream file(L"save.txt");
    if (!file) return;

    file << L"SAVE_V4\n";
    file << g_player.name << L"\n";
    file << g_player.realm << L"\n";
    file << g_player.level << L"\n";
    file << g_player.exp << L"\n";
    file << g_player.hp << L"\n";
    file << g_player.maxHp << L"\n";
    file << g_player.mp << L"\n";
    file << g_player.maxMp << L"\n";
    file << g_player.karma << L"\n";
    file << g_player.age << L"\n";
    file << g_player.lifespan << L"\n";
    file << g_player.spiritStones << L"\n";
    file << g_player.pills << L"\n";
    file << g_player.attackPower << L"\n";
    file << g_player.defense << L"\n";
    file << g_player.rootFire << L"\n";
    file << g_player.rootWater << L"\n";
    file << g_player.rootWood << L"\n";
    file << g_player.rootMetal << L"\n";
    file << g_player.rootEarth << L"\n";
    file << g_player.totalEvents << L"\n";
    file << g_player.battlesWon << L"\n";
    file << g_player.npcsMet << L"\n";

    SaveFamily(file, g_player.family);
    SaveWorldEra(file);
    SaveGeneratedWorld(file);
    g_dynamicWorld.Save(file);
    g_contextMgr.SetContext(BuildPlayerContext());
    g_contextMgr.Save(file);
    SaveMemory(file);
    SaveSocialRumors(file);
    g_legacySystem.Save(file);
    g_achievementSystem.Save(file);

    file.close();
    ShowNotice(L"存档", L"存档成功。\n\n你的境界、世界、道途记忆和前世传承都已写入 save.txt。");
}

bool LoadGame() {
    wifstream file(L"save.txt");
    if (!file) return false;

    wstring firstLine;
    getline(file, firstLine);
    bool isV4 = (firstLine == L"SAVE_V4");
    if (!isV4) return false;

    getline(file, g_player.name);

    int realm;
    file >> realm;
    g_player.realm = static_cast<Realm>(realm);
    file >> g_player.level >> g_player.exp;
    file >> g_player.hp >> g_player.maxHp;
    file >> g_player.mp >> g_player.maxMp;
    file >> g_player.karma >> g_player.age >> g_player.lifespan;
    file >> g_player.spiritStones >> g_player.pills;
    file >> g_player.attackPower >> g_player.defense;
    file >> g_player.rootFire >> g_player.rootWater >> g_player.rootWood;
    file >> g_player.rootMetal >> g_player.rootEarth;

    file >> g_player.totalEvents >> g_player.battlesWon >> g_player.npcsMet;
    file.ignore(numeric_limits<streamsize>::max(), L'\n');
    LoadFamily(file, g_player.family);
    LoadWorldEra(file);
    LoadGeneratedWorld(file);
    if (!HasFactionTie()) {
        GenerateFactionTie();
    }
    g_dynamicWorld.SetEraFlavor(g_worldEraName);
    g_dynamicWorld.Load(file);
    g_contextMgr.Load(file);
    LoadMemory(file);
    LoadSocialRumors(file);
    g_legacySystem.Load(file);
    g_achievementSystem.Load(file);
    g_contextMgr.SetContext(BuildPlayerContext());
    g_lastAiBackend = L"已读档";
    g_lastAiStatus = L"已读取存档，可在下次历练时再次触发动态事件。";
    RefreshAiStatus();

    g_player.CheckRootBalance();
    file.close();
    return true;
}

int ExtractValue(const wstring& text, const wstring& marker, int fallback = 0) {
    size_t pos = text.find(marker);
    if (pos == wstring::npos) return fallback;
    pos += marker.size();

    int value = 0;
    bool found = false;
    while (pos < text.size() && iswdigit(text[pos])) {
        found = true;
        value = value * 10 + (text[pos] - L'0');
        pos++;
    }
    return found ? value : fallback;
}

void ImproveRandomRoot(int amount) {
    int index = Random(0, 4);
    if (index == 0) g_player.ImproveRoot(g_player.rootFire, amount);
    else if (index == 1) g_player.ImproveRoot(g_player.rootWater, amount);
    else if (index == 2) g_player.ImproveRoot(g_player.rootWood, amount);
    else if (index == 3) g_player.ImproveRoot(g_player.rootMetal, amount);
    else g_player.ImproveRoot(g_player.rootEarth, amount);
}

const HongmengTreasure* FindHongmengTreasureInText(const wstring& text) {
    for (const auto& treasure : GetHongmengTreasures()) {
        if (text.find(treasure.name) != wstring::npos || text.find(treasure.dao) != wstring::npos) {
            return &treasure;
        }
    }
    return nullptr;
}

void TrackHongmengInsightFromEvent(const Event& event, const Choice& choice, const wstring& outcome) {
    wstring text = event.title + L" " + event.description + L" " + choice.description + L" " + outcome;
    const HongmengTreasure* treasure = FindHongmengTreasureInText(text);
    if (!treasure) return;

    bool hasProgress = ExtractValue(outcome, L"掌道+") > 0 ||
                       ExtractValue(outcome, L"灵宝共鸣+") > 0;
    bool hasInsight = TextContainsAny(outcome, {
        L"参悟", L"看清", L"明白", L"学会", L"懂得", L"知道", L"余光", L"显化"
    });

    if (hasProgress || hasInsight) {
        AddMemory(L"鸿蒙参悟",
            wstring(treasure->name) + L"只留投影与因果，不可据为己有；其权柄映照" +
            treasure->dao + L"。" + treasure->insight);
    } else if (TextContainsAny(outcome, {L"拒绝", L"反噬", L"压回", L"禁忌", L"气血-", L"因果-"})) {
        AddMemory(L"鸿蒙警戒",
            wstring(treasure->name) + L"拒绝被占有或强夺；禁忌为：" + treasure->taboo);
    }
}

bool AddLifeStoryHook(const wstring& hook, bool recordMemory = true) {
    if (hook.empty()) return false;

    wstring compact = CompactMemoryFragment(hook);
    if (compact.size() > 150) {
        compact = compact.substr(0, 150) + L"...";
    }

    for (const auto& existing : g_lifeStoryHooks) {
        if (existing == compact) return false;
    }

    g_lifeStoryHooks.push_back(compact);
    while (g_lifeStoryHooks.size() > 7) {
        g_lifeStoryHooks.erase(g_lifeStoryHooks.begin());
    }
    if (recordMemory) {
        AddMemory(L"本世线索推进", compact);
    }
    return true;
}

void ApplyStoryThreadEffects(const Event& event, const Choice& choice, const wstring& outcome, bool isAIEvent) {
    wstring text = event.title + L" " + event.description + L" " + choice.description + L" " + outcome;
    bool successLike = ExtractValue(outcome, L"修为+") > 0 ||
                       ExtractValue(outcome, L"灵石+") > 0 ||
                       ExtractValue(outcome, L"因果+") > 0 ||
                       ExtractValue(outcome, L"掌道+") > 0 ||
                       ExtractValue(outcome, L"灵宝共鸣+") > 0;
    bool setbackLike = ExtractValue(outcome, L"气血-") > 0 ||
                       ExtractValue(outcome, L"寿命-") > 0 ||
                       ExtractValue(outcome, L"因果-") > 0 ||
                       TextContainsAny(outcome, {L"反噬", L"拒绝", L"怀疑", L"记恨", L"旧债"});

    int added = 0;
    auto add = [&](const wstring& hook) {
        if (added >= 2 || hook.empty()) return;
        if (AddLifeStoryHook(hook)) {
            added++;
        }
    };

    if (const HongmengTreasure* treasure = FindHongmengTreasureInText(text)) {
        add((successLike ? L"鸿蒙参悟后续：" : L"鸿蒙警戒后续：") +
            wstring(treasure->name) + L"投影仍在识海边缘回响，下一次涉及" +
            treasure->dao + L"的抉择会更容易牵动它。");
    }

    if (TextContainsAny(text, {L"伴生玉佩", L"黑白旧玉", L"玉佩", L"梦中玉意", L"阴阳玉痕"})) {
        add(wstring(successLike ? L"玉佩暗线推进：" : L"玉佩暗线受扰：") +
            L"那枚黑白旧玉仍未显露真名，却继续把前世记忆、今生选择和轮回回响牵在一起。");
    }

    if (TextContainsAny(text, {L"前世未竟", L"未竟因果", L"旧因", L"旧债", L"前世", L"旧名"})) {
        add((successLike ? L"前世未竟推进：" : L"前世未竟加深：") +
            choice.description + L"后，上一世留下的因果没有散去，反而成了今生必须继续追的线头。");
    }

    if (HasFactionTie() && TextContainsAny(text, {
        g_factionTie.name, L"本世势力", L"势力", L"宗门", L"仙朝", L"工坊", L"道网", L"残宗", L"名册"
    })) {
        add((successLike ? L"势力线推进：" : L"势力线受阻：") +
            g_factionTie.name + L"因「" + choice.description + L"」重新衡量你，牵连值为" +
            (g_factionTie.favor >= 0 ? L"+" : L"") + to_wstring(g_factionTie.favor) + L"。");
    }

    for (const auto& thread : g_socialThreads) {
        bool directHit = text.find(thread.name) != wstring::npos ||
                         text.find(thread.role) != wstring::npos ||
                         text.find(thread.attitude) != wstring::npos;
        if (!directHit && !TextContainsAny(text, {L"本世人脉", L"长辈", L"同辈", L"父亲", L"母亲", L"养育者", L"欺压者", L"旁人"})) {
            continue;
        }
        add((successLike ? L"人情线推进：" : L"人情线生隙：") +
            thread.name + L"（" + thread.role + L"）会记住你在「" + choice.description +
            L"」中的表现，后续态度是" + GetRelationLabel(thread.relation) + L"。");
        break;
    }

    if (TextContainsAny(text, {L"旧世残响", L"上一纪元", L"旧世", L"遗址", L"断代", L"废墟", L"残响"})) {
        add(wstring(successLike ? L"旧世残响推进：" : L"旧世残响反噬：") +
            L"这次选择让上一纪元留下的物证继续影响今生，下一次遇到遗址、制度或旧器时应追查同一条线。");
    }

    if (TextContainsAny(text, {L"本世器物", L"当世兵刃", L"当世法宝", L"器痕", L"器纹", L"法宝", L"兵刃"})) {
        add(wstring(successLike ? L"器物线推进：" : L"器物线裂痕：") +
            L"今生器物本体终会失散，但这次取舍可能留下器痕，供通天灵宝残印在轮回中辨认。");
    }

    if (TextContainsAny(text, {L"大道", L"掌道", L"道祖", L"天道", L"道音"}) ||
        ExtractValue(outcome, L"掌道+") > 0) {
        add(wstring(successLike ? L"大道线推进：" : L"大道线受压：") +
            L"这次抉择让你的道心更清楚自身缺口，后续事件可继续考验同一条大道。");
    }

    if (isAIEvent && added == 0) {
        add(wstring(setbackLike ? L"动态事件余波：" : L"动态事件后续：") +
            L"「" + event.title + L"」没有当场结束，相关人和事会在今生继续发酵。");
    }
}

void ApplyOutcomeEffects(const wstring& outcome) {
    int expGain = ExtractValue(outcome, L"修为+");
    int expLoss = ExtractValue(outcome, L"修为-");
    int stoneGain = ExtractValue(outcome, L"灵石+");
    int stoneLoss = ExtractValue(outcome, L"灵石-");
    int pillGain = ExtractValue(outcome, L"丹药+");
    int pillLoss = ExtractValue(outcome, L"丹药-");
    int hpLoss = ExtractValue(outcome, L"气血-");
    int hpGain = ExtractValue(outcome, L"气血+");
    int lifeLoss = ExtractValue(outcome, L"寿命-");
    int lifeGain = ExtractValue(outcome, L"寿命+");
    int karmaGain = ExtractValue(outcome, L"因果+");
    int karmaLoss = ExtractValue(outcome, L"因果-");
    int relicGain = ExtractValue(outcome, L"灵宝共鸣+");
    int daoGain = ExtractValue(outcome, L"掌道+");
    int oldRelicAwakenings = g_legacySystem.GetRelic().awakenings;

    g_player.exp = max(0, g_player.exp + expGain - expLoss);
    g_player.spiritStones = max(0, g_player.spiritStones + stoneGain - stoneLoss);
    g_player.pills = max(0, g_player.pills + pillGain - pillLoss);
    g_player.hp = min(g_player.maxHp, max(0, g_player.hp + hpGain - hpLoss));
    g_player.lifespan = max(g_player.age, g_player.lifespan + lifeGain - lifeLoss);
    g_player.karma += karmaGain - karmaLoss;
    if (relicGain > 0) {
        g_legacySystem.AddRelicResonance(relicGain);
        const LegacyRelic& relic = g_legacySystem.GetRelic();
        if (relic.awakenings > oldRelicAwakenings) {
            AddMemory(L"通天灵宝觉醒",
                relic.name + L"由" + to_wstring(oldRelicAwakenings) +
                L"次苏醒推进至" + to_wstring(relic.awakenings) +
                L"次，觉醒阶段为" + g_legacySystem.GetRelicAwakeningStage() +
                L"，道痕显作" + relic.aspect);
        }
    }
    if (daoGain > 0) {
        g_legacySystem.AddDaoDepth(daoGain);
    }

    int rootGain = ExtractValue(outcome, L"灵根+");
    if (rootGain > 0) {
        ImproveRandomRoot(rootGain);
    }

    if (outcome.find(L"火灵根+") != wstring::npos) {
        g_player.ImproveRoot(g_player.rootFire, ExtractValue(outcome, L"火灵根+", 2));
    }
    if (outcome.find(L"水灵根+") != wstring::npos) {
        g_player.ImproveRoot(g_player.rootWater, ExtractValue(outcome, L"水灵根+", 2));
    }
    if (outcome.find(L"木灵根+") != wstring::npos) {
        g_player.ImproveRoot(g_player.rootWood, ExtractValue(outcome, L"木灵根+", 2));
    }
    if (outcome.find(L"金灵根+") != wstring::npos) {
        g_player.ImproveRoot(g_player.rootMetal, ExtractValue(outcome, L"金灵根+", 2));
    }
    if (outcome.find(L"土灵根+") != wstring::npos) {
        g_player.ImproveRoot(g_player.rootEarth, ExtractValue(outcome, L"土灵根+", 2));
    }

    if (outcome.find(L"五行均衡") != wstring::npos) {
        g_player.rootFire = max(7, g_player.rootFire);
        g_player.rootWater = max(7, g_player.rootWater);
        g_player.rootWood = max(7, g_player.rootWood);
        g_player.rootMetal = max(7, g_player.rootMetal);
        g_player.rootEarth = max(7, g_player.rootEarth);
        g_player.CheckRootBalance();
    }

    if (outcome.find(L"击败") != wstring::npos || outcome.find(L"战胜") != wstring::npos ||
        outcome.find(L"反杀") != wstring::npos || outcome.find(L"一击必杀") != wstring::npos) {
        g_player.battlesWon++;
    }

    if (outcome.find(L"直接提升一个小境界") != wstring::npos && g_player.level < 9) {
        g_player.LevelUp();
    }
}

vector<wstring> BuildUnfinishedKarmas(const wstring& causeOfDeath, int limit = 5) {
    vector<wstring> karmas;
    auto add = [&](const wstring& text) {
        if ((int)karmas.size() >= limit || text.empty()) return;
        wstring compact = CompactMemoryFragment(text);
        if (find(karmas.begin(), karmas.end(), compact) == karmas.end()) {
            karmas.push_back(compact);
        }
    };

    add(L"死因未了：" + causeOfDeath);
    add(L"本世主线未尽：" + g_lifePremise);
    for (const auto& hook : g_lifeStoryHooks) {
        add(L"未追完的线索：" + hook);
    }
    if (!g_socialThreads.empty()) {
        add(L"未结清的人情债：" + BuildSocialThreadLine(g_socialThreads[0]));
    }
    if (HasFactionTie()) {
        add(L"未清的势力牵连：" + BuildFactionTieDigest());
    }
    if (!g_lifeArtifacts.empty()) {
        add(L"失散的当世器物：" + CompactMemoryFragment(BuildLifeArtifactDigest(2)));
    }
    add(L"黑白伴生玉佩仍未解明：它总在生死与梦醒之间发温，像在替你保住不该跨世的记忆。");
    if (!g_eraRemnants.empty()) {
        add(L"旧世残响仍在：" + g_eraRemnants[0]);
    }
    return karmas;
}

void FinishCurrentLife(const wstring& causeOfDeath) {
    AddMemory(L"一世落幕", causeOfDeath);
    AddMemory(L"伴生玉佩收魂", BuildCompanionJadeDeathAnchorText(causeOfDeath));
    if (!g_lifeArtifacts.empty()) {
        int traceGain = GetLifeArtifactTraceResonanceGain();
        wstring traceText = BuildLifeArtifactTraceText();
        int oldRelicAwakenings = g_legacySystem.GetRelic().awakenings;
        if (traceGain > 0) {
            g_legacySystem.AddRelicResonance(traceGain);
            const LegacyRelic& relic = g_legacySystem.GetRelic();
            AddMemory(L"器痕归灵",
                traceText + L"的本体没有跨过轮回，但器痕沉入" + relic.name +
                L"，通天灵宝共鸣+" + to_wstring(traceGain));
            if (relic.awakenings > oldRelicAwakenings) {
                AddMemory(L"通天灵宝觉醒",
                    relic.name + L"由" + to_wstring(oldRelicAwakenings) +
                    L"次苏醒推进至" + to_wstring(relic.awakenings) +
                    L"次，觉醒阶段为" + g_legacySystem.GetRelicAwakeningStage() +
                    L"，道痕显作" + relic.aspect);
            }
        }

        AddMemory(L"当世器物散尽",
            L"随此世落幕，" + to_wstring(g_lifeArtifacts.size()) +
            L"件兵刃或法宝本体终将失散；能随轮回回响的只有记忆、器痕和通天灵宝残印。" +
            (traceGain > 0 ? wstring(L"其中") + traceText + L"只留下器痕。" : L""));
    }

    PastLife life;
    life.name = g_player.name;
    life.realmReached = g_player.realm;
    life.ageAtDeath = g_player.age;
    life.causeOfDeath = causeOfDeath;
    life.karma = g_player.karma;
    life.totalEvents = g_player.totalEvents;
    life.battlesWon = g_player.battlesWon;
    life.npcsMet = g_player.npcsMet;
    life.memoryFragments = SelectReincarnationMemoryFragments(GetCompanionJadeMemoryLimit());
    life.unfinishedKarmas = BuildUnfinishedKarmas(causeOfDeath);

    g_legacySystem.EndCurrentLife(life);
    auto& recorded = g_legacySystem.GetPastLives().back();
    g_achievementSystem.CheckAchievements(recorded, g_generation);
}

void StartNextLife() {
    wstring oldName = g_player.name;
    g_legacySystem.StartNewLife();
    g_generation = g_legacySystem.GetGeneration();
    g_lastAiBackend = L"未触发";
    g_lastAiStatus = L"本世尚未触发动态事件。";

    g_player = Player();
    g_player.name = oldName;
    ApplyCompanionJadeToBirth();
    wstring birthEcho = ApplyInheritedLegacyToBirth();

    int memoryBonus = g_legacySystem.GetLegacyBonus(LEGACY_MEMORY);
    int techniqueBonus = g_legacySystem.GetLegacyBonus(LEGACY_TECHNIQUE);
    int knowledgeBonus = g_legacySystem.GetLegacyBonus(LEGACY_KNOWLEDGE);
    int reputationBonus = g_legacySystem.GetLegacyBonus(LEGACY_REPUTATION);
    int treasureBonus = g_legacySystem.GetLegacyBonus(LEGACY_TREASURE);
    int relicBonus = g_legacySystem.GetRelicResonanceBonus();
    auto& inheritedLegacies = g_legacySystem.GetInheritedLegacies();

    g_player.exp += memoryBonus + techniqueBonus + relicBonus * 3;
    g_player.attackPower += knowledgeBonus / 5 + relicBonus / 2;
    g_player.defense += treasureBonus / 12;
    g_player.karma += reputationBonus;

    GenerateWorldEra();
    GenerateHongmengOmen();
    InitWorldData();
    GenerateFactionTie();
    GenerateLifeStoryHooks();
    g_dynamicWorld.SetEraFlavor(g_worldEraName);
    g_dynamicWorld.Reset();
    g_memoryLog.clear();
    g_discoveredItems.clear();
    g_lifeArtifacts.clear();
    GenerateSocialRumors();
    if (!birthEcho.empty()) {
        AddLifeStoryHook(wstring(L"传承扰动出身：") + birthEcho, false);
    }

    wstringstream detail;
    detail << L"第" << g_generation << L"世醒来";
    if (memoryBonus || techniqueBonus || knowledgeBonus || reputationBonus || treasureBonus || relicBonus) {
        detail << L"，继承前世余韵：记忆+" << memoryBonus
               << L"，功法+" << techniqueBonus
               << L"，战斗+" << knowledgeBonus / 5
               << L"，因果" << (reputationBonus >= 0 ? L"+" : L"") << reputationBonus
               << L"，灵宝共鸣+" << relicBonus;
    }
    AddMemory(L"轮回再起", detail.str());
    if (!inheritedLegacies.empty()) {
        wstringstream inheritedText;
        inheritedText << L"今生最先浮现的前世传承：";
        for (size_t i = 0; i < min<size_t>(inheritedLegacies.size(), 4); ++i) {
            if (i > 0) inheritedText << L"、";
            inheritedText << inheritedLegacies[i].name;
        }
        inheritedText << L"。这些传承会在历练中被点名牵动，而不只是开局数值。";
        AddMemory(L"继承传承", inheritedText.str());
    }
    AddMemory(L"伴生玉佩", BuildCompanionJadeVisibleText());
    AddMemory(L"时代更迭", L"此世降生于" + g_worldEraName + L"，" + g_worldEraDescription);
    AddMemory(L"时代变迁", g_eraTransitionNote);
    AddMemory(L"纪元转折", g_eraShiftCause);
    AddMemory(L"鸿蒙天象", BuildHongmengOmenBrief());
    if (!g_eraChronicle.empty()) AddMemory(L"纪元年表", g_eraChronicle.back());
    AddMemory(L"本世主线", g_lifePremise);
    if (!g_eraRemnants.empty()) AddMemory(L"旧世残响", BuildEraRemnantsText(3));
    AddMemory(L"前世余烬", g_reincarnationEcho);
    if (HasFactionTie()) AddMemory(L"本世势力", BuildFactionTieDigest());
    auto rememberedFragments = g_legacySystem.GetLatestMemoryFragments(4);
    if (!rememberedFragments.empty()) {
        AddMemory(L"玉意梦回",
            L"黑白伴生玉佩在梦里微温，托起" + to_wstring(rememberedFragments.size()) +
            L"段前世碎片；你仍不知道它真正来历，只能把这些当作似曾相识。");
    }
    for (const auto& fragment : rememberedFragments) {
        AddMemory(L"前世忆起", fragment);
    }
    auto unfinishedKarmas = g_legacySystem.GetLatestUnfinishedKarmas(3);
    for (const auto& karma : unfinishedKarmas) {
        AddMemory(L"前世未竟", karma);
    }
    if (relicBonus > 0 || treasureBonus > 0) {
        AddMemory(L"通天灵宝", g_legacySystem.GetDaoContextText());
    }
    AddMemory(L"此世出身", GetFamilySummary(g_player.family));
    if (!birthEcho.empty()) {
        AddMemory(L"传承扰动出身", birthEcho);
    }
    if (!g_socialThreads.empty()) AddMemory(L"本世人脉", BuildSocialThreadDigest(3));
    if (!g_socialRumors.empty()) AddMemory(L"人情风波", g_socialRumors[0]);
    DiscoverItemsFromText(BuildFactionTieDigest());

    g_contextMgr.SetContext(BuildPlayerContext());

    g_gameState = STATE_GAME;
    g_messageText.clear();
}

// ==================== 事件处理（增强版） ====================
void ProcessEventChoice(int choiceIndex, int outcomeIndex) {
    if (!g_currentEvent || choiceIndex < 0 || choiceIndex >= g_currentEvent->choices.size()) {
        return;
    }

    Choice& choice = g_currentEvent->choices[choiceIndex];

    // 检测是否为AI事件（通过outcomes内容判断）
    bool isAIEvent = (choice.outcomes[0] == L"成功" && choice.outcomes.size() == 2);
    int eraRisk = GetEraAdventureRiskModifier();

    if (isAIEvent) {
        // AI事件：使用AI生成结果
        PlayerContext& ctx = g_contextMgr.GetContext();
        int successRate = 60 + g_player.karma / 5 + GetDaoAdventureSuccessModifier()
            - g_dynamicWorld.GetAdventureRiskBonus() - eraRisk;
        successRate = max(20, min(90, successRate));
        bool success = (Random(1, 100) <= successRate);
        g_messageText = g_aiGen.GenerateOutcome(ctx, choiceIndex, success,
            g_currentEvent->title, g_currentEvent->description, choice.description);

        // 更新AI上下文
        g_contextMgr.UpdateFromChoice(choiceIndex, g_messageText);
    } else {
        // 传统事件：使用预设结果
        g_player.karma += choice.karmaChange;
        g_messageText = choice.outcomes[outcomeIndex];
    }

    ApplyOutcomeEffects(g_messageText);
    ApplyNarrativeRelationshipEffects(*g_currentEvent, choice, g_messageText);
    DiscoverItemsFromText(g_currentEvent->title);
    DiscoverItemsFromText(g_currentEvent->description);
    DiscoverItemsFromText(g_messageText);
    TrackLifeArtifactsFromText(g_messageText, g_currentEvent->title);
    MarkLifeArtifactsResonantFromText(
        g_currentEvent->title + L" " + g_currentEvent->description + L" " +
        choice.description + L" " + g_messageText);

    g_player.age += 1;
    g_player.totalEvents++;
    AdvanceDynamicWorld(L"历练抉择");
    if (eraRisk >= 10 && g_messageText.find(L"修为+") != wstring::npos) {
        AddMemory(L"时代法则", L"此世处于" + g_worldEraName + L"，机缘与凶险总是并行而至。");
    }
    AddMemory(g_currentEvent->title, choice.description + L" -> " + g_messageText);
    TrackHongmengInsightFromEvent(*g_currentEvent, choice, g_messageText);
    ApplyStoryThreadEffects(*g_currentEvent, choice, g_messageText, isAIEvent);
    if (isAIEvent) {
        AddMemory(L"本地模型抉择",
            g_currentEvent->title + L"；" + choice.description + L"；" + CompactMemoryFragment(g_messageText));
    }
    g_contextMgr.SetContext(BuildPlayerContext());

    if (g_player.IsDead()) {
        g_gameState = STATE_GAMEOVER;
        g_messageText = L"【游戏结束】\n";
        wstring cause;
        if (g_player.hp <= 0) {
            g_messageText += L"你在历练中身死道消...\n";
            cause = L"历练中身死道消";
        } else {
            g_messageText += L"你寿元耗尽，羽化而去...\n";
            cause = L"寿元耗尽";
        }
        g_messageText += L"\n最终成就：\n";
        g_messageText += L"境界：" + GetRealmName(g_player.realm) + L" " + to_wstring(g_player.level) + L"层\n";
        g_messageText += L"享年：" + to_wstring(g_player.age) + L"岁";
        FinishCurrentLife(cause);
        return;
    }

    ShowNotice(L"历练结果", g_messageText);
}

void DrawPanel(Graphics& graphics, const RectF& rect, int alpha = 210) {
    SolidBrush panelBrush(Color(alpha, 16, 17, 24));
    Pen panelPen(Color(150, 228, 190, 76), 1);
    graphics.FillRectangle(&panelBrush, rect);
    graphics.DrawRectangle(&panelPen, rect);
}

void DrawBar(Graphics& graphics, Font& font, SolidBrush& textBrush,
             const RectF& rect, double ratio, const wstring& label, Color fillColor) {
    ratio = max(0.0, min(1.0, ratio));
    SolidBrush bgBrush(Color(180, 42, 43, 50));
    SolidBrush fillBrush(fillColor);
    Pen borderPen(Color(120, 228, 190, 76), 1);
    graphics.FillRectangle(&bgBrush, rect);
    RectF fillRect(rect.X, rect.Y, (REAL)(rect.Width * ratio), rect.Height);
    graphics.FillRectangle(&fillBrush, fillRect);
    graphics.DrawRectangle(&borderPen, rect);

    StringFormat center;
    center.SetAlignment(StringAlignmentCenter);
    center.SetLineAlignment(StringAlignmentCenter);
    graphics.DrawString(label.c_str(), -1, &font, rect, &center, &textBrush);
}

void DrawLabelValue(Graphics& graphics, Font& labelFont, Font& valueFont,
                    SolidBrush& labelBrush, SolidBrush& valueBrush,
                    StringFormat& leftFormat, const wchar_t* label,
                    const wstring& value, REAL x, REAL y, REAL width) {
    RectF labelRect(x, y, 78, 24);
    RectF valueRect(x + 76, y, width - 76, 24);
    graphics.DrawString(label, -1, &labelFont, labelRect, &leftFormat, &labelBrush);
    graphics.DrawString(value.c_str(), -1, &valueFont, valueRect, &leftFormat, &valueBrush);
}

wstring BuildMainWorldDigest() {
    wstringstream ss;
    auto activeEvent = g_dynamicWorld.GetActiveWorldEvent();
    ss << g_worldEraName << L"\n";
    ss << g_eraTransitionNote << L"\n";
    ss << L"世界第 " << g_dynamicWorld.GetWorldTime() << L" 年\n";
    ss << L"鸿蒙天象: " << g_hongmengOmenTreasureName << L"映" << g_hongmengOmenDao << L"\n";
    if (activeEvent) {
        ss << activeEvent->title << L"\n";
        ss << activeEvent->description << L"\n";
    } else {
        ss << L"天下暂静，暗流仍在山门之间潜行。\n";
    }

    ss << L"\n" << g_reincarnationEcho << L"\n";
    if (g_worldEraName == L"灵机蒸汽纪" || g_worldEraName == L"星穹道网纪") {
        ss << L"此世奇遇更偏向灵机、工坊、远讯与技术化道统。\n";
    } else if (g_worldEraName == L"废土返道纪" || g_worldEraName == L"末法裂变纪") {
        ss << L"此世奇遇更偏向资源争夺、残骸遗迹与生存抉择。\n";
    } else {
        ss << L"此世奇遇仍以宗门、秘境、天材地宝与古修传承为主。\n";
    }
    auto npcs = g_dynamicWorld.GetAliveNPCs();
    ss << L"\n活跃修士: " << npcs.size() << L"人";
    return ss.str();
}

wstring BuildAiStatusDigest() {
    wstringstream ss;
    ss << L"后端: " << g_lastAiBackend << L"\n";
    ss << g_lastAiStatus;
    return ss.str();
}

wstring BuildRecentMemoryDigest() {
    if (g_memoryLog.empty()) return L"尚无新的道途记忆。";
    wstringstream ss;
    int start = max(0, (int)g_memoryLog.size() - 3);
    for (int i = start; i < (int)g_memoryLog.size(); i++) {
        ss << L"- " << g_memoryLog[i] << L"\n";
    }
    return ss.str();
}

int CountTextLines(const wstring& text) {
    if (text.empty()) return 1;
    int lines = 1;
    for (wchar_t ch : text) {
        if (ch == L'\n') lines++;
    }
    return lines;
}

// ==================== 绘制函数 ====================
void OnPaint(HDC hdc, RECT& rect) {
    Graphics graphics(hdc);
    graphics.SetTextRenderingHint(TextRenderingHintAntiAlias);

    // 背景
    if (g_bgImage) {
        graphics.DrawImage(g_bgImage, 0, 0, rect.right, rect.bottom);
    } else {
        LinearGradientBrush bgBrush(Point(0, 0), Point(0, rect.bottom),
            Color(255, 20, 20, 30), Color(255, 40, 40, 60));
        graphics.FillRectangle(&bgBrush, 0, 0, rect.right, rect.bottom);
    }

    SolidBrush maskBrush(Color(180, 0, 0, 0));
    graphics.FillRectangle(&maskBrush, 0, 0, rect.right, rect.bottom);

    FontFamily fontFamily(L"微软雅黑");
    FontFamily titleFamily(L"STZhongsong");
    FontFamily subtitleFamily(L"KaiTi");
    Font titleFont(&fontFamily, 36, FontStyleBold, UnitPixel);
    Font menuTitleFont(&fontFamily, 42, FontStyleBold, UnitPixel);
    Font menuSubFont(&fontFamily, 18, FontStyleRegular, UnitPixel);
    Font textFont(&fontFamily, 20, FontStyleRegular, UnitPixel);
    Font smallFont(&fontFamily, 16, FontStyleRegular, UnitPixel);

    SolidBrush whiteBrush(Color(255, 255, 255));
    SolidBrush goldBrush(Color(255, 215, 100));
    SolidBrush softWhiteBrush(Color(225, 245, 245, 245));
    SolidBrush mutedBrush(Color(190, 225, 225, 225));

    StringFormat centerFormat;
    centerFormat.SetAlignment(StringAlignmentCenter);
    StringFormat leftFormat;
    leftFormat.SetAlignment(StringAlignmentNear);
    g_backButtonVisible = false;

    switch (g_gameState) {
        case STATE_MENU: {
            int width = max(640, (int)rect.right);
            int height = max(520, (int)rect.bottom);
            float centerX = width / 2.0f;
            int panelWidth = min(520, max(380, width - 180));
            int panelHeight = 210;
            int panelLeft = (width - panelWidth) / 2;
            int panelTop = max(250, (height - panelHeight) / 2 + 70);

            RectF titleBand(0, 104, (REAL)width, 104);
            DrawGlowText(graphics, L"问道长生", titleFamily, 92.0f, titleBand, centerFormat);
            RectF subtitleBand(0, 172, (REAL)width, 40);
            Font menuSubDecor(&subtitleFamily, 28, FontStyleRegular, UnitPixel);
            graphics.DrawString(L"一念入道，百年问心", -1, &menuSubDecor,
                subtitleBand, &centerFormat, &softWhiteBrush);

            Pen ornamentPen(Color(150, 216, 182, 92), 3);
            graphics.DrawArc(&ornamentPen, (REAL)(width / 2 - 430), 214.0f, 150.0f, 42.0f, 10.0f, 150.0f);
            graphics.DrawLine(&ornamentPen, (REAL)(width / 2 - 280), 234.0f, (REAL)(width / 2 - 186), 234.0f);
            graphics.DrawLine(&ornamentPen, (REAL)(width / 2 + 186), 234.0f, (REAL)(width / 2 + 280), 234.0f);
            graphics.DrawArc(&ornamentPen, (REAL)(width / 2 + 280), 214.0f, 150.0f, 42.0f, 20.0f, 150.0f);

            RectF menuPanel((REAL)panelLeft, (REAL)panelTop, (REAL)panelWidth, (REAL)panelHeight);
            GraphicsPath panelPath;
            REAL radius = 8.0f;
            panelPath.AddArc(menuPanel.X, menuPanel.Y, radius, radius, 180.0f, 90.0f);
            panelPath.AddArc(menuPanel.GetRight() - radius, menuPanel.Y, radius, radius, 270.0f, 90.0f);
            panelPath.AddArc(menuPanel.GetRight() - radius, menuPanel.GetBottom() - radius, radius, radius, 0.0f, 90.0f);
            panelPath.AddArc(menuPanel.X, menuPanel.GetBottom() - radius, radius, radius, 90.0f, 90.0f);
            panelPath.CloseFigure();

            SolidBrush panelBrush(Color(185, 15, 15, 18));
            Pen panelPen(Color(120, 255, 215, 100), 1);
            graphics.FillPath(&panelBrush, &panelPath);
            graphics.DrawPath(&panelPen, &panelPath);

            RectF promptRect((REAL)panelLeft, (REAL)panelTop + 25, (REAL)panelWidth, 32);
            graphics.DrawString(L"输入道号", -1, &menuSubFont,
                promptRect, &centerFormat, &goldBrush);

            int inputWidth = min(360, panelWidth - 120);
            RectF inputRect((REAL)(centerX - inputWidth / 2.0f), (REAL)panelTop + 82, (REAL)inputWidth, 38.0f);
            SolidBrush inputBrush(Color(255, 255, 255, 255));
            Pen inputPen(Color(210, 230, 230, 230), 1);
            graphics.FillRectangle(&inputBrush, inputRect);
            graphics.DrawRectangle(&inputPen, inputRect);

            break;
        }

        case STATE_GAME: {
            int width = max(1180, (int)rect.right);
            int height = max(760, (int)rect.bottom);
            REAL margin = 30.0f;
            REAL gap = 22.0f;
            REAL top = 38.0f;
            REAL bottom = height - 32.0f;
            REAL leftW = 340.0f;
            REAL rightW = 290.0f;
            REAL centerW = width - margin * 2 - gap * 2 - leftW - rightW;

            RectF leftPanel(margin, top, leftW, bottom - top);
            RectF centerPanel(margin + leftW + gap, top, centerW, bottom - top);
            RectF rightPanel(margin + leftW + gap + centerW + gap, top, rightW, bottom - top);
            DrawPanel(graphics, leftPanel, 208);
            DrawPanel(graphics, centerPanel, 190);
            DrawPanel(graphics, rightPanel, 208);

            Font sectionFont(&fontFamily, 18, FontStyleBold, UnitPixel);
            Font commandFont(&fontFamily, 17, FontStyleRegular, UnitPixel);
            Font statFont(&fontFamily, 15, FontStyleRegular, UnitPixel);

            graphics.DrawString((L"【" + g_player.name + L"】").c_str(), -1, &sectionFont,
                RectF(leftPanel.X + 18, leftPanel.Y + 18, leftPanel.Width - 36, 28), &leftFormat, &goldBrush);
            graphics.DrawString((GetRealmName(g_player.realm) + L" " + to_wstring(g_player.level) + L"层 · " + g_player.GetRootQuality()).c_str(),
                -1, &statFont, RectF(leftPanel.X + 18, leftPanel.Y + 48, leftPanel.Width - 36, 24), &leftFormat, &softWhiteBrush);

            REAL y = leftPanel.Y + 86;
            DrawBar(graphics, statFont, whiteBrush,
                RectF(leftPanel.X + 18, y, leftPanel.Width - 36, 24),
                (double)g_player.exp / max(1, g_player.GetExpNeeded()),
                L"修为 " + to_wstring(g_player.exp) + L" / " + to_wstring(g_player.GetExpNeeded()),
                Color(220, 200, 162, 62));
            y += 38;
            DrawBar(graphics, statFont, whiteBrush,
                RectF(leftPanel.X + 18, y, leftPanel.Width - 36, 24),
                (double)g_player.hp / max(1, g_player.maxHp),
                L"气血 " + to_wstring(g_player.hp) + L" / " + to_wstring(g_player.maxHp),
                Color(220, 170, 58, 58));
            y += 38;
            DrawBar(graphics, statFont, whiteBrush,
                RectF(leftPanel.X + 18, y, leftPanel.Width - 36, 24),
                (double)g_player.mp / max(1, g_player.maxMp),
                L"灵力 " + to_wstring(g_player.mp) + L" / " + to_wstring(g_player.maxMp),
                Color(220, 66, 126, 175));

            y += 46;
            DrawLabelValue(graphics, statFont, statFont, mutedBrush, whiteBrush, leftFormat, L"五行",
                g_player.GetRootDetails(), leftPanel.X + 18, y, leftPanel.Width - 36);
            y += 28;
            DrawLabelValue(graphics, statFont, statFont, mutedBrush, whiteBrush, leftFormat, L"因果",
                to_wstring(g_player.karma), leftPanel.X + 18, y, leftPanel.Width - 36);
            y += 28;
            DrawLabelValue(graphics, statFont, statFont, mutedBrush, whiteBrush, leftFormat, L"寿元",
                to_wstring(g_player.age) + L" / " + to_wstring(g_player.lifespan), leftPanel.X + 18, y, leftPanel.Width - 36);
            y += 28;
            DrawLabelValue(graphics, statFont, statFont, mutedBrush, whiteBrush, leftFormat, L"资源",
                L"灵石 " + to_wstring(g_player.spiritStones) + L"  丹药 " + to_wstring(g_player.pills),
                leftPanel.X + 18, y, leftPanel.Width - 36);
            y += 28;
            DrawLabelValue(graphics, statFont, statFont, mutedBrush, whiteBrush, leftFormat, L"战绩",
                L"历练 " + to_wstring(g_player.totalEvents) + L"  胜场 " + to_wstring(g_player.battlesWon),
                leftPanel.X + 18, y, leftPanel.Width - 36);
            y += 28;
            DrawLabelValue(graphics, statFont, statFont, mutedBrush, whiteBrush, leftFormat, L"出身",
                GetFamilySummary(g_player.family), leftPanel.X + 18, y, leftPanel.Width - 36);

            RectF futureRoleRect(leftPanel.X + 18, leftPanel.Y + 430, leftPanel.Width - 36, leftPanel.Height - 455);
            Pen faintPen(Color(55, 228, 190, 76), 1);
            graphics.DrawRectangle(&faintPen, futureRoleRect);
            graphics.DrawString(L"动态事件引擎", -1, &statFont,
                RectF(futureRoleRect.X + 12, futureRoleRect.Y + 12, futureRoleRect.Width - 24, 24),
                &leftFormat, &mutedBrush);
            graphics.DrawString(BuildAiStatusDigest().c_str(), -1, &smallFont,
                RectF(futureRoleRect.X + 12, futureRoleRect.Y + 42, futureRoleRect.Width - 24, futureRoleRect.Height - 54),
                &leftFormat, &softWhiteBrush);

            graphics.DrawString(L"修真界现状", -1, &sectionFont,
                RectF(centerPanel.X + 22, centerPanel.Y + 20, centerPanel.Width - 44, 28), &leftFormat, &goldBrush);
            graphics.DrawString(BuildMainWorldDigest().c_str(), -1, &textFont,
                RectF(centerPanel.X + 22, centerPanel.Y + 58, centerPanel.Width - 44, 175), &leftFormat, &whiteBrush);

            Pen linePen(Color(90, 228, 190, 76), 1);
            graphics.DrawLine(&linePen, centerPanel.X + 22, centerPanel.Y + 255,
                centerPanel.GetRight() - 22, centerPanel.Y + 255);
            graphics.DrawString(L"近年道途", -1, &sectionFont,
                RectF(centerPanel.X + 22, centerPanel.Y + 276, centerPanel.Width - 44, 28), &leftFormat, &goldBrush);
            graphics.DrawString(BuildRecentMemoryDigest().c_str(), -1, &smallFont,
                RectF(centerPanel.X + 22, centerPanel.Y + 314, centerPanel.Width - 44, 112), &leftFormat, &softWhiteBrush);

            graphics.DrawString(L"人情风波", -1, &sectionFont,
                RectF(centerPanel.X + 22, centerPanel.Y + 455, centerPanel.Width - 44, 28), &leftFormat, &goldBrush);
            graphics.DrawString(GetSocialDigest().c_str(), -1, &smallFont,
                RectF(centerPanel.X + 22, centerPanel.Y + 493, centerPanel.Width - 44, 120), &leftFormat, &softWhiteBrush);

            graphics.DrawString(L"行动", -1, &sectionFont,
                RectF(rightPanel.X + 20, rightPanel.Y + 20, rightPanel.Width - 40, 28), &leftFormat, &goldBrush);
            const vector<wstring> commands = {
                L"[1] 打坐修炼",
                L"[2] 外出历练",
                L"[3] 突破境界",
                L"[4] 服用丹药",
                L"[5] 灵石闭关",
                L"[6] 铸炼器物",
                L"[W] 修真界现状",
                L"[P] 本世主线",
                L"[F] 此世家世",
                L"[R] 人情风波",
                L"[I] 灵物图录",
                L"[T] 鸿蒙至宝",
                L"[H] 道途记忆",
                L"[G] 前世传承",
                L"[S] 保存",
                L"[L] 读取",
                L"[ESC] 退出"
            };
            REAL cmdY = rightPanel.Y + 64;
            for (const auto& command : commands) {
                graphics.DrawString(command.c_str(), -1, &commandFont,
                    RectF(rightPanel.X + 22, cmdY, rightPanel.Width - 44, 24), &leftFormat, &softWhiteBrush);
                cmdY += 32;
            }
            break;
        }

        case STATE_EVENT:
            if (g_currentEvent) {
                RectF eventRect(100, 100, rect.right - 200, rect.bottom - 200);
                DrawPanel(graphics, eventRect, 225);

                graphics.DrawString(g_currentEvent->title.c_str(), -1, &titleFont,
                    RectF(eventRect.X + 40, eventRect.Y + 35, eventRect.Width - 80, 48), &centerFormat, &goldBrush);

                RectF descRect(eventRect.X + 52, eventRect.Y + 105, eventRect.Width - 104, 120);
                graphics.DrawString(g_currentEvent->description.c_str(), -1, &textFont,
                    descRect, &leftFormat, &whiteBrush);

                REAL yPos = eventRect.Y + 240;
                for (size_t i = 0; i < g_currentEvent->choices.size(); i++) {
                    wstring choiceText = L"[" + to_wstring(i + 1) + L"] " +
                        g_currentEvent->choices[i].description;
                    graphics.DrawString(choiceText.c_str(), -1, &textFont,
                        RectF(eventRect.X + 90, yPos, eventRect.Width - 180, 32), &leftFormat, &whiteBrush);
                    yPos += 58;
                }
            }
            break;

        case STATE_INFO: {
            int width = max(1180, (int)rect.right);
            int height = max(760, (int)rect.bottom);
            RectF infoRect(92, 80, (REAL)width - 184, (REAL)height - 150);
            DrawPanel(graphics, infoRect, 226);

            Font infoTitleFont(&fontFamily, 30, FontStyleBold, UnitPixel);
            Font infoTextFont(&fontFamily, 17, FontStyleRegular, UnitPixel);
            graphics.DrawString(g_infoTitle.c_str(), -1, &infoTitleFont,
                RectF(infoRect.X + 42, infoRect.Y + 34, infoRect.Width - 220, 42), &leftFormat, &goldBrush);

            g_backButtonRect = {
                (LONG)(infoRect.GetRight() - 150),
                (LONG)(infoRect.Y + 32),
                (LONG)(infoRect.GetRight() - 42),
                (LONG)(infoRect.Y + 68)
            };
            g_backButtonVisible = true;
            RectF backRect((REAL)g_backButtonRect.left, (REAL)g_backButtonRect.top,
                (REAL)(g_backButtonRect.right - g_backButtonRect.left),
                (REAL)(g_backButtonRect.bottom - g_backButtonRect.top));
            SolidBrush backBrush(Color(230, 38, 38, 44));
            Pen backPen(Color(170, 228, 190, 76), 1);
            graphics.FillRectangle(&backBrush, backRect);
            graphics.DrawRectangle(&backPen, backRect);
            graphics.DrawString(L"返回", -1, &smallFont, backRect, &centerFormat, &goldBrush);

            bool showItemAtlas = (g_infoTitle == L"灵物图录" && g_itemAtlasImage != nullptr);
            REAL contentWidth = showItemAtlas ? (infoRect.Width - 430) : (infoRect.Width - 116);
            RectF contentClip(infoRect.X + 46, infoRect.Y + 96,
                contentWidth, infoRect.Height - 150);
            int estimatedContentHeight = CountTextLines(g_infoText) * 24 + 40;
            g_infoScrollMax = max(0, estimatedContentHeight - (int)contentClip.Height);
            g_infoScroll = max(0, min(g_infoScroll, g_infoScrollMax));

            graphics.SetClip(contentClip);
            RectF textRect(contentClip.X, contentClip.Y - (REAL)g_infoScroll,
                contentClip.Width, (REAL)max(2200, estimatedContentHeight + 120));
            graphics.DrawString(g_infoText.c_str(), -1, &infoTextFont, textRect, &leftFormat, &softWhiteBrush);
            graphics.ResetClip();

            if (showItemAtlas) {
                RectF atlasRect(infoRect.GetRight() - 332, infoRect.Y + 96, 256, 512);
                SolidBrush atlasBg(Color(80, 18, 24, 30));
                Pen atlasPen(Color(120, 228, 190, 76), 1);
                graphics.FillRectangle(&atlasBg, atlasRect);
                graphics.DrawRectangle(&atlasPen, atlasRect);
                graphics.DrawImage(g_itemAtlasImage, atlasRect);
            }

            RectF scrollTrack(infoRect.GetRight() - 58, contentClip.Y, 8, contentClip.Height);
            g_infoScrollTrackRect = {
                (LONG)scrollTrack.X,
                (LONG)scrollTrack.Y,
                (LONG)(scrollTrack.X + scrollTrack.Width),
                (LONG)(scrollTrack.Y + scrollTrack.Height)
            };
            SolidBrush trackBrush(Color(120, 48, 48, 52));
            SolidBrush thumbBrush(Color(210, 228, 190, 76));
            if (g_infoScrollMax > 0) {
                graphics.FillRectangle(&trackBrush, scrollTrack);
                REAL thumbHeight = max(36.0f, contentClip.Height * contentClip.Height / (REAL)estimatedContentHeight);
                REAL thumbY = scrollTrack.Y + (contentClip.Height - thumbHeight) * ((REAL)g_infoScroll / (REAL)g_infoScrollMax);
                graphics.FillRectangle(&thumbBrush, RectF(scrollTrack.X, thumbY, scrollTrack.Width, thumbHeight));
            }

            graphics.DrawString(L"ESC 返回  |  ↑↓ 滚动", -1, &smallFont,
                RectF(infoRect.X + 46, infoRect.GetBottom() - 40, infoRect.Width - 92, 24),
                &leftFormat, &mutedBrush);
            break;
        }

        case STATE_AI_WAIT: {
            int width = max(900, (int)rect.right);
            int height = max(620, (int)rect.bottom);
            RectF waitRect((REAL)(width / 2 - 320), (REAL)(height / 2 - 170), 640, 340);
            DrawPanel(graphics, waitRect, 228);

            int dotCount = (GetTickCount() / 500) % 4;
            wstring dots(dotCount, L'。');
            graphics.DrawString((L"天机推演中" + dots).c_str(), -1, &titleFont,
                RectF(waitRect.X + 40, waitRect.Y + 44, waitRect.Width - 80, 54), &centerFormat, &goldBrush);

            wstring waitText =
                L"黑白旧玉微微发温，前世残响、此世家世与近年大事正在交汇。\n\n"
                L"这次历练会由本地模型生成，完成后会自动显出因果。\n\n"
                L"按 [ESC] 可放弃本次推演，回到当前道途。";
            graphics.DrawString(waitText.c_str(), -1, &textFont,
                RectF(waitRect.X + 58, waitRect.Y + 122, waitRect.Width - 116, 134), &leftFormat, &whiteBrush);

            graphics.DrawString(BuildAiStatusDigest().c_str(), -1, &smallFont,
                RectF(waitRect.X + 58, waitRect.Y + 276, waitRect.Width - 116, 38), &leftFormat, &mutedBrush);
            break;
        }

        case STATE_GAMEOVER: {
            RectF overRect(100, 100, rect.right - 200, rect.bottom - 200);
            SolidBrush panelBrush(Color(220, 10, 10, 20));
            graphics.FillRectangle(&panelBrush, overRect);

            graphics.DrawString(L"道途终结", -1, &titleFont,
                PointF(rect.right/2.0f, 150), &centerFormat, &goldBrush);

            RectF msgRect(150, 250, rect.right - 300, 300);
            graphics.DrawString(g_messageText.c_str(), -1, &textFont,
                msgRect, &leftFormat, &whiteBrush);

            graphics.DrawString(L"按 [N] 转世 | [ESC] 退出", -1, &textFont,
                PointF(rect.right/2.0f, rect.bottom - 150), &centerFormat, &goldBrush);
            break;
        }
    }
}

// ==================== 窗口消息处理 ====================
LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
        case WM_PAINT: {
            PAINTSTRUCT ps;
            HDC hdc = BeginPaint(hWnd, &ps);
            RECT rect;
            GetClientRect(hWnd, &rect);

            HDC memDC = CreateCompatibleDC(hdc);
            HBITMAP memBitmap = CreateCompatibleBitmap(hdc, rect.right, rect.bottom);
            SelectObject(memDC, memBitmap);

            OnPaint(memDC, rect);

            BitBlt(hdc, 0, 0, rect.right, rect.bottom, memDC, 0, 0, SRCCOPY);
            DeleteObject(memBitmap);
            DeleteDC(memDC);

            EndPaint(hWnd, &ps);
            break;
        }

        case WM_SIZE:
            if (g_gameState == STATE_MENU) {
                LayoutMenuControls();
            }
            InvalidateRect(hWnd, NULL, FALSE);
            break;

        case WM_COMMAND: {
            if (LOWORD(wParam) == ID_BTN_START && g_gameState == STATE_MENU) {
                wchar_t name[100];
                GetWindowTextW(g_nameInput, name, 100);
                if (wcslen(name) == 0) {
                    MessageBoxW(hWnd, L"请输入道号！", L"提示", MB_OK);
                    break;
                }
                g_player = Player();
                g_player.name = name;
                g_generation = 1;
                ApplyCompanionJadeToBirth();
                g_lastAiBackend = L"未触发";
                g_lastAiStatus = L"本局尚未触发动态事件。";
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
                AddMemory(L"初入道途", L"凡人之身踏上长生路。");
                AddMemory(L"伴生玉佩", BuildCompanionJadeVisibleText());
                AddMemory(L"时代更迭", L"此世正值" + g_worldEraName + L"，" + g_worldEraDescription);
                AddMemory(L"时代变迁", g_eraTransitionNote);
                AddMemory(L"纪元转折", g_eraShiftCause);
                AddMemory(L"鸿蒙天象", BuildHongmengOmenBrief());
                if (!g_eraChronicle.empty()) AddMemory(L"纪元年表", g_eraChronicle.back());
                AddMemory(L"本世主线", g_lifePremise);
                if (HasFactionTie()) AddMemory(L"本世势力", BuildFactionTieDigest());
                if (!g_eraRemnants.empty()) AddMemory(L"旧世残响", BuildEraRemnantsText(3));
                AddMemory(L"此世出身", GetFamilySummary(g_player.family));
                if (!g_socialThreads.empty()) AddMemory(L"本世人脉", BuildSocialThreadDigest(3));
                if (!g_socialRumors.empty()) AddMemory(L"人情风波", g_socialRumors[0]);
                DiscoverItemsFromText(g_player.family.secret);
                DiscoverItemsFromText(BuildFactionTieDigest());
                DiscoverItemsFromText(BuildSocialThreadDigest(5));
                DiscoverItemsFromText(g_socialRumors.empty() ? L"" : g_socialRumors[0]);
                g_contextMgr.SetContext(BuildPlayerContext());
                g_gameState = STATE_GAME;
                ShowWindow(g_nameInput, SW_HIDE);
                ShowWindow(g_btnStart, SW_HIDE);
                InvalidateRect(hWnd, NULL, FALSE);
            }
            break;
        }

        case WM_LBUTTONDOWN: {
            if (g_gameState == STATE_INFO && g_backButtonVisible) {
                int x = GET_X_LPARAM(lParam);
                int y = GET_Y_LPARAM(lParam);
                if (x >= g_backButtonRect.left && x <= g_backButtonRect.right &&
                    y >= g_backButtonRect.top && y <= g_backButtonRect.bottom) {
                    ReturnFromInfoPage();
                    InvalidateRect(hWnd, NULL, FALSE);
                } else if (x >= g_infoScrollTrackRect.left && x <= g_infoScrollTrackRect.right &&
                    y >= g_infoScrollTrackRect.top && y <= g_infoScrollTrackRect.bottom &&
                    g_infoScrollMax > 0) {
                    int trackHeight = max(1, (int)(g_infoScrollTrackRect.bottom - g_infoScrollTrackRect.top));
                    int relativeY = max(0, min(trackHeight, (int)(y - g_infoScrollTrackRect.top)));
                    g_infoScroll = g_infoScrollMax * relativeY / trackHeight;
                    g_infoScrollDragging = true;
                    SetCapture(hWnd);
                    InvalidateRect(hWnd, NULL, FALSE);
                }
            }
            break;
        }

        case WM_MOUSEMOVE: {
            if (g_gameState == STATE_INFO && g_infoScrollDragging && g_infoScrollMax > 0) {
                int y = GET_Y_LPARAM(lParam);
                int trackHeight = max(1, (int)(g_infoScrollTrackRect.bottom - g_infoScrollTrackRect.top));
                int relativeY = max(0, min(trackHeight, (int)(y - g_infoScrollTrackRect.top)));
                g_infoScroll = g_infoScrollMax * relativeY / trackHeight;
                InvalidateRect(hWnd, NULL, FALSE);
            }
            break;
        }

        case WM_LBUTTONUP: {
            if (g_infoScrollDragging) {
                g_infoScrollDragging = false;
                ReleaseCapture();
            }
            break;
        }

        case WM_MOUSEWHEEL: {
            if (g_gameState == STATE_INFO) {
                int delta = GET_WHEEL_DELTA_WPARAM(wParam);
                g_infoScroll += (delta < 0) ? 64 : -64;
                g_infoScroll = max(0, min(g_infoScroll, g_infoScrollMax));
                InvalidateRect(hWnd, NULL, FALSE);
            }
            break;
        }

        case WM_TIMER: {
            if (wParam == IDT_AI_POLL && g_aiProcessRunning) {
                DWORD exitCode = STILL_ACTIVE;
                if (GetExitCodeProcess(g_aiProcessInfo.hProcess, &exitCode)) {
                    if (exitCode != STILL_ACTIVE) {
                        CompleteLocalModelGenerator(exitCode);
                    } else if (GetTickCount() - g_aiStartTick > 100000) {
                        KillAiProcessTree();
                        g_lastAiBackend = L"模板回退";
                        g_lastAiStatus = L"本地模型推演超时，已回退到内置模板事件。";
                        CompleteLocalModelGenerator(1);
                    } else {
                        InvalidateRect(hWnd, NULL, FALSE);
                    }
                }
            }
            break;
        }

        case WM_KEYDOWN: {
            if (g_gameState == STATE_GAME) {
                if (wParam == '1') {
                    int multiplier = g_dynamicWorld.GetCultivationMultiplier();
                    int eraMeditation = GetEraMeditationModifierPercent();
                    int daoMeditation = GetDaoMeditationModifierPercent();
                    int totalMeditation = max(10, eraMeditation + daoMeditation);
                    int gain = g_player.Meditate(multiplier, totalMeditation);
                    AdvanceDynamicWorld(L"闭关修行"); // 世界也在演化
                    if (g_player.IsDead()) {
                        g_gameState = STATE_GAMEOVER;
                        g_messageText = L"【寿元耗尽】\n你在闭关中坐化...\n\n最终境界：" +
                            GetRealmName(g_player.realm) + L" " + to_wstring(g_player.level) + L"层\n享年：" +
                            to_wstring(g_player.age) + L"岁";
                        FinishCurrentLife(L"闭关坐化");
                    } else {
                        wstring msg = L"打坐修炼，修为+" + to_wstring(gain);
                        if (eraMeditation > 100) {
                            msg += L"\n" + g_worldEraName + L"灵气格外顺遂，闭关效率有所提升。";
                        } else if (eraMeditation < 100) {
                            msg += L"\n" + g_worldEraName + L"天地法则晦涩，苦修收益被时代压低了。";
                        }
                        if (daoMeditation > 0) {
                            msg += L"\n" + g_legacySystem.GetRelic().daoName +
                                   L"反哺今生，修炼效率+" + to_wstring(daoMeditation) + L"%。";
                        }
                        if (multiplier > 1) {
                            msg += L"\n天地异象加持，修炼收益翻倍。";
                            AddMemory(L"天地异象", L"借灵气暴动修炼，修为+" + to_wstring(gain));
                        }
                        AddMemory(L"时代修行", L"在" + g_worldEraName + L"打坐一年，修为变化+" + to_wstring(gain));
                        int lifespanPressure = GetLifespanPressureLevel();
                        if (lifespanPressure >= 2 || (lifespanPressure == 1 && g_player.age % 10 == 0)) {
                            AddMemory(L"寿元压力", BuildLifespanPressureText());
                        }
                        ShowNotice(L"打坐修炼", msg);
                    }
                    InvalidateRect(hWnd, NULL, FALSE);
                }
                else if (wParam == '2') {
                    if (ShouldTriggerDaoTrialEvent()) {
                        static Event s_daoTrialEvent;
                        s_daoTrialEvent = BuildDaoTrialEvent();
                        g_currentEvent = &s_daoTrialEvent;
                        AddMemory(L"大道问心", L"外出历练时，所掌大道主动显出一道缺口。");
                        g_gameState = STATE_EVENT;
                        InvalidateRect(hWnd, NULL, FALSE);
                    }
                    else if (ShouldTriggerLegacyEchoEvent()) {
                        static Event s_legacyEchoEvent;
                        s_legacyEchoEvent = BuildLegacyEchoEvent();
                        g_currentEvent = &s_legacyEchoEvent;
                        AddMemory(L"前世牵动", L"外出历练时触发了前世遗响。");
                        g_gameState = STATE_EVENT;
                        InvalidateRect(hWnd, NULL, FALSE);
                    }
                    else if (ShouldTriggerSocialAdventureEvent()) {
                        static Event s_socialAdventureEvent;
                        s_socialAdventureEvent = BuildSocialAdventureEvent();
                        g_currentEvent = &s_socialAdventureEvent;
                        AddMemory(L"人情牵动", L"外出历练时本世人脉主动入局。");
                        g_gameState = STATE_EVENT;
                        InvalidateRect(hWnd, NULL, FALSE);
                    }
                    else if (ShouldTriggerLifeArtifactEvent()) {
                        static Event s_lifeArtifactEvent;
                        s_lifeArtifactEvent = BuildLifeArtifactEvent();
                        g_currentEvent = &s_lifeArtifactEvent;
                        AddMemory(L"器物牵动", L"外出历练时，本世器物主动卷入凶局。");
                        g_gameState = STATE_EVENT;
                        InvalidateRect(hWnd, NULL, FALSE);
                    }
                    else if (ShouldTriggerEraPulseEvent()) {
                        static Event s_eraPulseEvent;
                        s_eraPulseEvent = BuildEraPulseEvent();
                        g_currentEvent = &s_eraPulseEvent;
                        AddMemory(L"纪元余波", L"外出历练时，当前时代的大势主动卷入此身。");
                        g_gameState = STATE_EVENT;
                        InvalidateRect(hWnd, NULL, FALSE);
                    }
                    // 外出历练 - 不同时代AI事件活跃度不同
                    else if (Random(1, 100) <= GetEraAiEventChance()) {
                        // AI动态事件
                        PlayerContext ctx = BuildPlayerContext();

                        g_aiGen.WritePromptFile(ctx);
                        g_pendingAiContext = ctx;
                        if (BeginLocalModelGeneratorAsync()) {
                            g_gameState = STATE_AI_WAIT;
                        } else {
                            EnterAiEventFromContext(ctx);
                        }
                        InvalidateRect(hWnd, NULL, FALSE);
                    } else {
                        // 传统事件
                        bool needRoot = !g_player.hasBalancedRoots && g_player.realm >= SPIRIT_SEVERING;
                        g_currentEvent = g_eventMgr.GetRandomEvent(g_player.karma, needRoot);
                        if (g_currentEvent) {
                            g_gameState = STATE_EVENT;
                            InvalidateRect(hWnd, NULL, FALSE);
                        }
                    }
                }
                else if (wParam == '3') {
                    if (!g_player.CanBreakthrough()) {
                        wstring msg = L"还不满足突破条件！\n";
                        if (g_player.realm >= HEAVENLY_DAO) {
                            msg = L"你已抵达道祖-天道境，万道归一，此世道途已至极点。";
                        } else if (g_player.realm == DAO_ANCESTOR) {
                            msg += L"你已与自身大道共生，但若要叩问道祖-天道境，仍需修至道祖九层并积蓄足够修为。\n\n";
                            msg += GetHeavenlyDaoRequirementText();
                        } else if (g_player.realm == MAHAYANA && !g_player.hasBalancedRoots) {
                            msg += L"\n⚠ 五行不均，无法飞升！\n需要五行灵根均衡才能冲仙门\n";
                            msg += L"当前灵根：\n" + g_player.GetRootDetails();
                        } else {
                            msg += L"需要达到当前境界9层且修为充足";
                        }
                        ShowNotice(L"突破条件", msg);
                    } else {
                        if (g_player.realm == DAO_ANCESTOR && !CanAttainHeavenlyDao()) {
                            ShowNotice(L"天道未合", GetHeavenlyDaoRequirementText());
                            InvalidateRect(hWnd, NULL, FALSE);
                            break;
                        }
                        int result = MessageBoxW(hWnd,
                            (L"是否突破至 " + GetRealmName(static_cast<Realm>(g_player.realm + 1)) + L"？").c_str(),
                            L"突破境界", MB_YESNO | MB_ICONQUESTION);
                        if (result == IDYES) {
                            int daoBreakthrough = GetDaoBreakthroughModifier();
                            bool success = g_player.TryBreakthrough(GetEraBreakthroughModifier() + daoBreakthrough);
                            if (success) {
                                AddMemory(L"境界突破", L"踏入 " + GetRealmName(g_player.realm));
                                AddMemory(L"时代法则", L"在" + g_worldEraName + L"中破境成功，说明此世大道仍愿意为你开门。");
                                if (g_player.realm == DAO_ANCESTOR) {
                                    g_legacySystem.AttuneDaoFromCurrentLife(
                                        g_player.realm, g_player.karma, g_player.totalEvents,
                                        g_player.battlesWon, g_player.npcsMet, g_player.age);
                                    AddMemory(L"证道成祖", g_legacySystem.GetDaoContextText());
                                    ShowNotice(L"证道成祖",
                                        L"你已不再被寿元追赶，而是与自身大道共生。\n\n" +
                                        g_legacySystem.GetDaoContextText() +
                                        L"\n\n道祖-天道境仍在万道之上，需继续积累掌道深度与灵宝共鸣。");
                                } else if (g_player.realm == HEAVENLY_DAO) {
                                    g_gameState = STATE_GAMEOVER;
                                    g_legacySystem.AttuneDaoFromCurrentLife(
                                        g_player.realm, g_player.karma, g_player.totalEvents,
                                        g_player.battlesWon, g_player.npcsMet, g_player.age);
                                    g_legacySystem.AddDaoDepth(80);
                                    g_messageText = L"【万道归一】\n你越过道祖之上，抵达道祖-天道境。\n\n";
                                    g_messageText += L"九大鸿蒙至宝仍在，但你已具备理论上毁灭它们的力量。\n";
                                    g_messageText += L"只是当万道尽在掌中，毁灭已无必要。\n\n";
                                    g_messageText += L"享年：" + to_wstring(g_player.age) + L"岁\n";
                                    g_messageText += L"因果：" + to_wstring(g_player.karma) + L"\n\n";
                                    g_messageText += L"按 [N] 可开启下一世，按 [ESC] 退出。";
                                    FinishCurrentLife(L"天道归一");
                                } else {
                                    wstring successMsg = L"恭喜！你已进入 " + GetRealmName(g_player.realm) + L"。";
                                    if (GetEraBreakthroughModifier() > 0) {
                                        successMsg += L"\n此世大道尚算开明，突破阻力被时代削弱了。";
                                    } else if (GetEraBreakthroughModifier() < 0) {
                                        successMsg += L"\n即便如此，你仍顶着此世晦涩法则强行破境。";
                                    }
                                    if (daoBreakthrough > 0) {
                                        successMsg += L"\n" + g_legacySystem.GetRelic().daoName +
                                            L"为此番破境托住一线，破境助力+" + to_wstring(daoBreakthrough) + L"。";
                                    }
                                    ShowNotice(L"突破成功", successMsg);
                                }
                            } else {
                                AddMemory(L"突破失败", L"冲击 " + GetRealmName(static_cast<Realm>(g_player.realm + 1)) + L" 遭到反噬");
                                wstring failMsg = L"遭到反噬，气血与修为受损。";
                                if (GetEraBreakthroughModifier() < 0) {
                                    failMsg += L"\n" + g_worldEraName + L"的天地法则本就晦涩，这次破境尤其艰难。";
                                }
                                if (daoBreakthrough > 0) {
                                    failMsg += L"\n" + g_legacySystem.GetRelic().daoName +
                                        L"已替你削去部分反噬，但仍未能破关。";
                                }
                                ShowNotice(L"突破失败", failMsg);
                            }
                            InvalidateRect(hWnd, NULL, FALSE);
                        }
                    }
                }
                else if (wParam == '4') {
                    if (g_player.pills <= 0) {
                        ShowNotice(L"丹药", L"你没有丹药。");
                    } else if (g_player.hp >= g_player.maxHp) {
                        ShowNotice(L"丹药", L"气血充盈，无需服丹。");
                    } else {
                        g_player.pills--;
                        int heal = 80 + g_player.realm * 20;
                        g_player.hp = min(g_player.maxHp, g_player.hp + heal);
                        AddMemory(L"服用丹药", L"调息疗伤，气血恢复" + to_wstring(heal));
                        ShowNotice(L"服用丹药", L"服下丹药，气血恢复" + to_wstring(heal) + L"。");
                        InvalidateRect(hWnd, NULL, FALSE);
                    }
                }
                else if (wParam == '5') {
                    int cost = 10 + g_player.realm * 2;
                    if (g_player.spiritStones < cost) {
                        ShowNotice(L"灵石闭关", L"灵石不足，需要 " + to_wstring(cost) + L"。");
                    } else {
                        g_player.spiritStones -= cost;
                        int gain = 80 + g_player.realm * 20;
                        if (g_dynamicWorld.GetCultivationMultiplier() > 1) {
                            gain *= 2;
                        }
                        gain += GetEraClosedDoorBonus();
                        gain = max(20, gain);
                        g_player.exp += gain;
                        g_player.age++;
                        AdvanceDynamicWorld(L"灵石闭关");
                        AddMemory(L"灵石闭关", L"消耗灵石" + to_wstring(cost) + L"，修为+" + to_wstring(gain));
                        wstring closedDoorMsg = L"闭关一年，消耗灵石" + to_wstring(cost) +
                            L"，修为+" + to_wstring(gain) + L"。";
                        if (GetEraClosedDoorBonus() > 0) {
                            closedDoorMsg += L"\n这一世的灵机与阵械体系让闭关效率更高。";
                        } else if (GetEraClosedDoorBonus() < 0) {
                            closedDoorMsg += L"\n这一世天地不稳，哪怕借灵石闭关也难尽如人意。";
                        }
                        ShowNotice(L"灵石闭关", closedDoorMsg);
                        InvalidateRect(hWnd, NULL, FALSE);
                    }
                }
                else if (wParam == '6') {
                    ShowNotice(L"铸炼器物", ForgeLifeArtifact());
                    InvalidateRect(hWnd, NULL, FALSE);
                }
                else if (wParam == 'W' || wParam == 'w') {
                    OpenInfoPage(L"修真界现状", GetWorldInfoText(), STATE_GAME);
                    InvalidateRect(hWnd, NULL, FALSE);
                }
                else if (wParam == 'P' || wParam == 'p') {
                    OpenInfoPage(L"本世主线", BuildLifeStoryText(), STATE_GAME);
                    InvalidateRect(hWnd, NULL, FALSE);
                }
                else if (wParam == 'F' || wParam == 'f') {
                    OpenInfoPage(L"此世家世", GetFamilyDetailText(g_player.family) + L"\n\n" + BuildFactionTieText(), STATE_GAME);
                    InvalidateRect(hWnd, NULL, FALSE);
                }
                else if (wParam == 'R' || wParam == 'r') {
                    OpenInfoPage(L"人情风波", GetSocialRumorText(8), STATE_GAME);
                    InvalidateRect(hWnd, NULL, FALSE);
                }
                else if (wParam == 'I' || wParam == 'i') {
                    OpenInfoPage(L"灵物图录", BuildItemCodexText(), STATE_GAME);
                    InvalidateRect(hWnd, NULL, FALSE);
                }
                else if (wParam == 'T' || wParam == 't') {
                    OpenInfoPage(L"鸿蒙至宝", BuildHongmengTreasuresText(), STATE_GAME);
                    InvalidateRect(hWnd, NULL, FALSE);
                }
                else if (wParam == 'H' || wParam == 'h') {
                    OpenInfoPage(L"道途记忆", GetMemoryText(18), STATE_GAME);
                    InvalidateRect(hWnd, NULL, FALSE);
                }
                else if (wParam == 'G' || wParam == 'g') {
                    OpenInfoPage(L"前世传承", GetLegacyInfoText(), STATE_GAME);
                    InvalidateRect(hWnd, NULL, FALSE);
                }
                else if (wParam == 'S' || wParam == 's') {
                    SaveGame();
                }
                else if (wParam == 'L' || wParam == 'l') {
                    if (LoadGame()) {
                        ShowNotice(L"读档", L"读档成功。");
                        InvalidateRect(hWnd, NULL, FALSE);
                    } else {
                        ShowNotice(L"读档", L"没有找到存档。");
                    }
                }
                else if (wParam == VK_ESCAPE) {
                    if (MessageBoxW(hWnd, L"确定退出？", L"退出", MB_YESNO) == IDYES) {
                        PostQuitMessage(0);
                    }
                }
            }
            else if (g_gameState == STATE_EVENT) {
                if (wParam >= '1' && wParam <= '9') {
                    int choice = wParam - '1';
                    if (choice < g_currentEvent->choices.size()) {
                        int outcome = 0;
                        int outcomeCount = (int)g_currentEvent->choices[choice].outcomes.size();
                        if (outcomeCount > 1) {
                            int failChance = 45 + g_dynamicWorld.GetAdventureRiskBonus() +
                                GetEraAdventureRiskModifier() - GetDaoAdventureSuccessModifier() -
                                g_player.karma / 10;
                            failChance = max(10, min(85, failChance));
                            if (Random(1, 100) <= failChance) {
                                outcome = Random(1, outcomeCount - 1);
                            }
                        }
                        ProcessEventChoice(choice, outcome);
                        InvalidateRect(hWnd, NULL, FALSE);
                    }
                }
                else if (wParam == VK_ESCAPE) {
                    g_gameState = STATE_GAME;
                    InvalidateRect(hWnd, NULL, FALSE);
                }
            }
            else if (g_gameState == STATE_AI_WAIT) {
                if (wParam == VK_ESCAPE) {
                    CancelLocalModelGenerator();
                    g_gameState = STATE_GAME;
                    InvalidateRect(hWnd, NULL, FALSE);
                }
            }
            else if (g_gameState == STATE_INFO) {
                if (wParam == VK_ESCAPE) {
                    ReturnFromInfoPage();
                    InvalidateRect(hWnd, NULL, FALSE);
                } else if (wParam == VK_DOWN || wParam == VK_NEXT) {
                    g_infoScroll += (wParam == VK_NEXT) ? 180 : 48;
                    g_infoScroll = min(g_infoScroll, g_infoScrollMax);
                    InvalidateRect(hWnd, NULL, FALSE);
                } else if (wParam == VK_UP || wParam == VK_PRIOR) {
                    g_infoScroll -= (wParam == VK_PRIOR) ? 180 : 48;
                    g_infoScroll = max(0, g_infoScroll);
                    InvalidateRect(hWnd, NULL, FALSE);
                }
            }
            else if (g_gameState == STATE_GAMEOVER) {
                if (wParam == 'N' || wParam == 'n') {
                    StartNextLife();
                    InvalidateRect(hWnd, NULL, FALSE);
                }
                else if (wParam == VK_ESCAPE) {
                    PostQuitMessage(0);
                }
            }
            break;
        }

        case WM_DESTROY:
            PostQuitMessage(0);
            break;

        default:
            return DefWindowProc(hWnd, message, wParam, lParam);
    }
    return 0;
}

// ==================== 主函数 ====================
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE, LPSTR, int nCmdShow) {
    GdiplusStartupInput gdiplusStartupInput;
    ULONG_PTR gdiplusToken;
    GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);

    if (GetFileAttributesW(L"background.jpg") != INVALID_FILE_ATTRIBUTES) {
        g_bgImage = Image::FromFile(L"background.jpg");
    } else if (GetFileAttributesW(L"background.png") != INVALID_FILE_ATTRIBUTES) {
        g_bgImage = Image::FromFile(L"background.png");
    }
    if (GetFileAttributesW(L"previews\\item_atlas_v4.png") != INVALID_FILE_ATTRIBUTES) {
        g_itemAtlasImage = Image::FromFile(L"previews\\item_atlas_v4.png");
    }

    WNDCLASSEXA wcex = {};
    wcex.cbSize = sizeof(WNDCLASSEXA);
    wcex.style = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc = WndProc;
    wcex.hInstance = hInstance;
    wcex.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wcex.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wcex.lpszClassName = "WenDaoChangSheng";
    RegisterClassExA(&wcex);

    g_hWnd = CreateWindowA("WenDaoChangSheng", "The Immortal Path",
        WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, 0, 1360, 900,
        nullptr, nullptr, hInstance, nullptr);

    if (!g_hWnd) return FALSE;
    SetWindowTextA(g_hWnd, "The Immortal Path");

    g_nameInput = CreateWindowW(L"EDIT", L"", WS_CHILD | WS_VISIBLE | ES_CENTER | ES_MULTILINE,
        362, 400, 300, 35, g_hWnd, (HMENU)ID_NAME_INPUT, hInstance, NULL);
    g_btnStart = CreateWindowW(L"BUTTON", L"开始游戏", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
        437, 450, 150, 40, g_hWnd, (HMENU)ID_BTN_START, hInstance, NULL);

    HFONT hFont = CreateFontW(20, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        DEFAULT_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"微软雅黑");
    SendMessage(g_nameInput, WM_SETFONT, (WPARAM)hFont, TRUE);
    SendMessage(g_btnStart, WM_SETFONT, (WPARAM)hFont, TRUE);
    LayoutMenuControls();

    ShowWindow(g_hWnd, nCmdShow);
    UpdateWindow(g_hWnd);

    MSG msg;
    while (GetMessage(&msg, nullptr, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    if (g_bgImage) delete g_bgImage;
    if (g_itemAtlasImage) delete g_itemAtlasImage;
    GdiplusShutdown(gdiplusToken);
    return (int)msg.wParam;
}

        // ========== 新增20个快速事件 ==========
