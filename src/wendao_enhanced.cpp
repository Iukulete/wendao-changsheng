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
    THEME_FINAL_AGE = 4
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
            L"【机缘】道网远讯",
            L"灵网节点忽然向你推送一段跨洲讯息，里面藏着某座高阶宗门遗留的远程试炼入口。",
            {
                {L"接入试炼", {L"你远程闯过一层试炼，获赠算法阵图\n修为+120", L"神识过载，头痛欲裂\n气血-30"}, 6},
                {L"转卖线索", {L"你把入口坐标卖给别人，换得不菲灵石\n灵石+30", L"对方反悔，反向锁定了你的气息\n气血-20"}, 0},
                {L"谨慎断开", {L"你没有贸然接入，但仍记下一丝道网逻辑\n修为+50", L"机缘短暂熄灭，只剩空白提示"}, 2}
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
            L"【因果】末法争井",
            L"一口尚未完全枯竭的灵井引来数方修士对峙，在末法时代，每一缕灵气都像会咬人的肉。",
            {
                {L"强夺灵井", {L"你趁乱夺得灵井余气，破境感悟大涨\n修为+140", L"众人联手围杀，几乎把你逼上绝路\n气血-50"}, -5},
                {L"结盟分润", {L"你与几人暂结同盟，分得一份灵气与人脉\n修为+90，因果+10", L"盟友翻脸，分润变成陷阱\n气血-30"}, 6},
                {L"旁观待变", {L"你等到残局收尾，再捡走被忽略的资源\n灵石+22，修为+50", L"拖得太久，什么也没剩下"}, 0}
            }
        }, THEME_FINAL_AGE);
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
    STATE_INFO = 4
};

GameState g_gameState = STATE_MENU;
Event* g_currentEvent = nullptr;
wstring g_messageText;
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

HWND g_nameInput;
HWND g_btnStart;

void ShowNotice(const wstring& title, const wstring& text);
vector<vector<wstring>> LoadItemDbRows();

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
        L"本世器物", L"当世器物", L"旧世残响", L"纪元转折", L"纪元年表", L"未竟"
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

wstring BuildLifeStoryText() {
    wstringstream ss;
    ss << L"【本世主线】\n\n";
    ss << g_lifePremise << L"\n\n";
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
            L"混沌天钟", L"时空定序",
            L"钟声能定住一段时代的因果，使文明在崩塌前多喘一口气。",
            L"万物声息骤停，只有钟纹在时空与因果之间缓缓扩散。",
            L"强改已成历史，会招来时序反噬，把今生也卷入旧日。",
            L"你听懂一个时代将崩前的停顿，知道何时该争一口气。"
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
            L"轮回古镜", L"前尘照命",
            L"不照容貌，只照灵魂在无数世里反复避开的那一道裂痕。",
            L"镜面不照今貌，只照历世反复错过、反复逃避的同一处裂痕。",
            L"沉迷前世会失去今生主位，被旧名替你活完这一世。",
            L"你认出轮回里反复回避的裂痕，终于能在今生正视它。"
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

wstring BuildHongmengTreasureSummary(int limit = 3) {
    const auto& treasures = GetHongmengTreasures();
    wstringstream ss;
    ss << L"【九大鸿蒙至宝】创世级恒在之物，共九件，不属于任何一世，也不会被普通道祖毁灭。\n";
    int count = min(limit, (int)treasures.size());
    for (int i = 0; i < count; ++i) {
        ss << L"- " << treasures[i].name << L"（" << treasures[i].dao << L"）: " << treasures[i].miracle << L"\n";
    }
    ss << L"- 运行规则: 道祖可参悟、借势、被选中或被拒绝，但不可毁灭；掌尽诸道的道祖-天道境才具备理论毁灭力，且毁灭没有意义，只是力量映射。\n";
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
    ss << L"掌道深度: " << relic.daoDepth << L"\n\n";
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
    int unfinishedPressure = (int)unfinishedKarmas.size() * 30;
    int totalEcho = g_legacySystem.GetLegacyBonus(LEGACY_MEMORY) +
                    g_legacySystem.GetLegacyBonus(LEGACY_KNOWLEDGE) +
                    g_legacySystem.GetLegacyBonus(LEGACY_TREASURE) +
                    abs(g_legacySystem.GetLegacyBonus(LEGACY_REPUTATION)) +
                    g_legacySystem.GetRelicResonanceBonus() * 2 +
                    unfinishedPressure;
    if (totalEcho <= 0) return false;

    int chance = 12 + totalEcho / 18 + (int)unfinishedKarmas.size() * 6;
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

Event BuildLegacyEchoEvent() {
    Event evt;

    int memoryEcho = g_legacySystem.GetLegacyBonus(LEGACY_MEMORY);
    int knowledgeEcho = g_legacySystem.GetLegacyBonus(LEGACY_KNOWLEDGE);
    int treasureEcho = g_legacySystem.GetLegacyBonus(LEGACY_TREASURE);
    int reputationEcho = g_legacySystem.GetLegacyBonus(LEGACY_REPUTATION);
    const LegacyRelic& relic = g_legacySystem.GetRelic();
    auto unfinishedKarmas = g_legacySystem.GetLatestUnfinishedKarmas(5);

    if (!unfinishedKarmas.empty() && Random(1, 100) <= 65) {
        return BuildUnfinishedKarmaEchoEvent(unfinishedKarmas);
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

wstring BuildSocialThreadLine(const SocialThread& thread) {
    wstringstream ss;
    ss << thread.name << L"（" << thread.role << L"）";
    ss << L" · " << thread.attitude << L" · " << GetRelationLabel(thread.relation);
    if (!thread.visibleRealm.empty()) {
        ss << L" · 外显" << thread.visibleRealm;
    }
    if (thread.hidesPower || !thread.hiddenHint.empty()) {
        ss << L" · " << (thread.hiddenHint.empty() ? L"可能隐藏实力" : thread.hiddenHint);
    }
    ss << L": " << thread.hook;
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
            AddMemory(L"势力回响",
                g_factionTie.name + L"对你的牵连值由" +
                (oldFavor >= 0 ? L"+" : L"") + to_wstring(oldFavor) + L"变为" +
                (g_factionTie.favor >= 0 ? L"+" : L"") + to_wstring(g_factionTie.favor) +
                L"。起因：" + CompactMemoryFragment(event.title + L"·" + choice.description));
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
            AddMemory(L"人情回响",
                thread.name + L"（" + thread.role + L"）对你的关系由" +
                GetRelationLabel(oldRelation) + L"变为" + GetRelationLabel(thread.relation) +
                L"。起因：" + CompactMemoryFragment(event.title + L"·" + choice.description));
            changed++;
        }
        if (changed >= 2) break;
    }
}

void GenerateSocialThreads() {
    g_socialThreads.clear();

    int totalRoot = g_player.GetTotalRoot();
    bool exceptionalRoot = (totalRoot >= 42 || g_player.hasBalancedRoots);
    bool weakRoot = (totalRoot < 30 && !g_player.hasBalancedRoots);
    int memoryBonus = g_legacySystem.GetLegacyBonus(LEGACY_MEMORY);
    int reputationEcho = g_legacySystem.GetLegacyBonus(LEGACY_REPUTATION);
    auto npcs = g_dynamicWorld.GetAliveNPCs();

    auto npcRealmText = [](DynamicNPC* npc) {
        if (!npc) return wstring();
        Realm shown = static_cast<Realm>(max(0, min(npc->shownRealm, (int)HEAVENLY_DAO)));
        return GetRealmName(shown) + L" " + to_wstring(npc->level) + L"层";
    };
    auto npcHides = [](DynamicNPC* npc) {
        return npc && npc->shownRealm < npc->realm;
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

    wstring sectName = g_worldData.sects.empty() ? L"附近宗门" : g_worldData.sects[0].name;
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
    int treasureEcho = g_legacySystem.GetLegacyBonus(LEGACY_TREASURE);

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

    if (g_socialRumors.size() > 6) {
        g_socialRumors.resize(6);
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
    if (HasFactionTie()) {
        ctx.familyState += L"；本世势力:" + g_factionTie.name + L"(" + g_factionTie.role + L")";
    }
    ctx.socialState = GetSocialDigest();
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
    world << L"- 道祖-天道境进度: " << GetHeavenlyDaoProgressScore() << L" / 360\n";
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
    if (added > 0) {
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
    file << L"WORLD_ERA_V6\n";
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
    if (marker != L"WORLD_ERA_V1" && !isV2 && !isV3 && !isV4 && !isV5 && !isV6) return false;

    getline(file, g_worldEraName);
    getline(file, g_worldEraDescription);
    getline(file, g_worldEraRule);
    getline(file, g_reincarnationEcho);
    getline(file, g_eraTransitionNote);
    if (isV2 || isV3 || isV4 || isV5 || isV6) {
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
        if (isV3 || isV4 || isV5 || isV6) {
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
        if (isV4 || isV5 || isV6) {
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
        if (isV5 || isV6) {
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
        if (isV6) {
            getline(file, g_eraShiftCause);
            g_eraShiftCause = UnescapeSaveField(g_eraShiftCause);
        } else {
            g_eraShiftCause = L"旧存档没有记录纪元转折因由，只能从残留的时代变迁中推断。";
        }
    } else {
        g_lifePremise = L"此世主线来自旧存档，尚未记录明确线索。";
        g_lifeStoryHooks.clear();
        g_eraRemnants.clear();
        g_eraChronicle.clear();
        g_factionTie = FactionTie();
        g_eraShiftCause = L"旧存档没有记录纪元转折因由。";
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
    if (!g_eraRemnants.empty()) {
        add(L"旧世残响仍在：" + g_eraRemnants[0]);
    }
    return karmas;
}

void FinishCurrentLife(const wstring& causeOfDeath) {
    AddMemory(L"一世落幕", causeOfDeath);
    if (!g_lifeArtifacts.empty()) {
        AddMemory(L"当世器物散尽",
            L"随此世落幕，" + to_wstring(g_lifeArtifacts.size()) +
            L"件兵刃或法宝本体终将失散；能随轮回回响的只有记忆、器痕和通天灵宝残印。");
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
    life.memoryFragments = SelectReincarnationMemoryFragments();
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

    int memoryBonus = g_legacySystem.GetLegacyBonus(LEGACY_MEMORY);
    int knowledgeBonus = g_legacySystem.GetLegacyBonus(LEGACY_KNOWLEDGE);
    int reputationBonus = g_legacySystem.GetLegacyBonus(LEGACY_REPUTATION);
    int treasureBonus = g_legacySystem.GetLegacyBonus(LEGACY_TREASURE);
    int relicBonus = g_legacySystem.GetRelicResonanceBonus();

    g_player.exp += memoryBonus + relicBonus * 3;
    g_player.attackPower += knowledgeBonus / 5 + relicBonus / 2;
    g_player.defense += treasureBonus / 12;
    g_player.karma += reputationBonus;

    GenerateWorldEra();
    InitWorldData();
    GenerateFactionTie();
    GenerateLifeStoryHooks();
    g_dynamicWorld.SetEraFlavor(g_worldEraName);
    g_dynamicWorld.Reset();
    g_memoryLog.clear();
    g_discoveredItems.clear();
    g_lifeArtifacts.clear();
    GenerateSocialRumors();

    wstringstream detail;
    detail << L"第" << g_generation << L"世醒来";
    if (memoryBonus || knowledgeBonus || reputationBonus || treasureBonus || relicBonus) {
        detail << L"，继承前世余韵：记忆+" << memoryBonus
               << L"，战斗+" << knowledgeBonus / 5
               << L"，因果" << (reputationBonus >= 0 ? L"+" : L"") << reputationBonus
               << L"，灵宝共鸣+" << relicBonus;
    }
    AddMemory(L"轮回再起", detail.str());
    AddMemory(L"时代更迭", L"此世降生于" + g_worldEraName + L"，" + g_worldEraDescription);
    AddMemory(L"时代变迁", g_eraTransitionNote);
    AddMemory(L"纪元转折", g_eraShiftCause);
    if (!g_eraChronicle.empty()) AddMemory(L"纪元年表", g_eraChronicle.back());
    AddMemory(L"本世主线", g_lifePremise);
    if (!g_eraRemnants.empty()) AddMemory(L"旧世残响", BuildEraRemnantsText(3));
    AddMemory(L"前世余烬", g_reincarnationEcho);
    if (HasFactionTie()) AddMemory(L"本世势力", BuildFactionTieDigest());
    auto rememberedFragments = g_legacySystem.GetLatestMemoryFragments(4);
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

    g_player.age += 1;
    g_player.totalEvents++;
    AdvanceDynamicWorld(L"历练抉择");
    if (eraRisk >= 10 && g_messageText.find(L"修为+") != wstring::npos) {
        AddMemory(L"时代法则", L"此世处于" + g_worldEraName + L"，机缘与凶险总是并行而至。");
    }
    AddMemory(g_currentEvent->title, choice.description + L" -> " + g_messageText);
    if (isAIEvent) {
        AddMemory(L"本地模型抉择",
            g_currentEvent->title + L"；" + choice.description + L"；" + CompactMemoryFragment(g_messageText));
    }

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
                g_lastAiBackend = L"未触发";
                g_lastAiStatus = L"本局尚未触发动态事件。";
                g_memoryLog.clear();
                g_discoveredItems.clear();
                g_lifeArtifacts.clear();
                g_eraChronicle.clear();
                GenerateWorldEra();
                InitWorldData();
                GenerateFactionTie();
                GenerateLifeStoryHooks();
                g_dynamicWorld.SetEraFlavor(g_worldEraName);
                g_dynamicWorld.Reset();
                GenerateSocialRumors();
                AddMemory(L"初入道途", L"凡人之身踏上长生路。");
                AddMemory(L"时代更迭", L"此世正值" + g_worldEraName + L"，" + g_worldEraDescription);
                AddMemory(L"时代变迁", g_eraTransitionNote);
                AddMemory(L"纪元转折", g_eraShiftCause);
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
                        ShowNotice(L"打坐修炼", msg);
                    }
                    InvalidateRect(hWnd, NULL, FALSE);
                }
                else if (wParam == '2') {
                    if (ShouldTriggerLegacyEchoEvent()) {
                        static Event s_legacyEchoEvent;
                        s_legacyEchoEvent = BuildLegacyEchoEvent();
                        g_currentEvent = &s_legacyEchoEvent;
                        AddMemory(L"前世牵动", L"外出历练时触发了前世遗响。");
                        g_gameState = STATE_EVENT;
                        InvalidateRect(hWnd, NULL, FALSE);
                    }
                    // 外出历练 - 不同时代AI事件活跃度不同
                    else if (Random(1, 100) <= GetEraAiEventChance()) {
                        // AI动态事件
                        PlayerContext ctx = BuildPlayerContext();

                        g_aiGen.WritePromptFile(ctx);
                        TryRunLocalModelGenerator();

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
                            if (g_lastAiBackend.empty() || g_lastAiBackend == L"未触发") {
                                g_lastAiBackend = L"模板回退";
                            }
                            if (g_lastAiStatus.empty() || g_lastAiStatus == L"本局尚未触发动态事件。") {
                                g_lastAiStatus = L"未读取到有效 ai_event.txt，已回退到内置模板事件。";
                            }
                            AddMemory(L"动态事件回退", g_lastAiStatus);
                            aiTitle = g_aiGen.GenerateEventTitle(ctx);
                            aiDesc = g_aiGen.GenerateEventDescription(ctx);
                            aiChoices = g_aiGen.GenerateChoices(ctx);
                        }

                        // 创建临时AI事件用于显示
                        Event tempEvent;
                        tempEvent.title = aiTitle;
                        tempEvent.description = aiDesc;

                        // 转换AI选择为传统格式
                        for (auto& choice : aiChoices) {
                            Choice c;
                            c.description = choice;
                            c.outcomes.push_back(L"成功"); // 占位，实际由AI生成
                            c.outcomes.push_back(L"失败");
                            c.karmaChange = 0;
                            tempEvent.choices.push_back(c);
                        }

                        // 保存当前AI上下文到全局
                        g_contextMgr.SetContext(ctx);

                        // 使用传统事件槽位显示AI事件
                        static Event s_aiEvent;
                        s_aiEvent = tempEvent;
                        g_currentEvent = &s_aiEvent;

                        g_gameState = STATE_EVENT;
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
