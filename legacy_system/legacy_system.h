// 多周目传承系统
#pragma once
#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <fstream>
#include <limits>

using namespace std;

// ==================== 传承类型 ====================
enum LegacyType {
    LEGACY_MEMORY,      // 记忆碎片
    LEGACY_TECHNIQUE,   // 功法传承
    LEGACY_TREASURE,    // 法宝遗留
    LEGACY_KNOWLEDGE,   // 知识领悟
    LEGACY_REPUTATION   // 声望影响
};

// ==================== 传承物品 ====================
struct LegacyItem {
    LegacyType type;
    wstring name;
    wstring description;
    int power;          // 效果强度

    LegacyItem(LegacyType t, wstring n, wstring d, int p)
        : type(t), name(n), description(d), power(p) {}
};

// ==================== 前世记录 ====================
struct PastLife {
    int generation;         // 第几世
    wstring name;
    int realmReached;       // 达到的境界
    int ageAtDeath;
    wstring causeOfDeath;   // 死因
    int karma;

    // 成就
    int totalEvents;
    int battlesWon;
    int npcsMet;

    // 留下的传承
    vector<LegacyItem> legacies;

    PastLife() : generation(1), realmReached(0), ageAtDeath(0),
                 karma(0), totalEvents(0), battlesWon(0), npcsMet(0) {}
};

struct LegacyRelic {
    wstring name;
    int resonance;
    int awakenings;
    wstring aspect;
    bool daoLinked;
    wstring daoName;
    int daoDepth;

    LegacyRelic()
        : name(L"通天灵宝残印"), resonance(0), awakenings(0),
          aspect(L"未定道痕"), daoLinked(false),
          daoName(L"未证大道"), daoDepth(0) {}
};

// ==================== 传承系统 ====================
class LegacySystem {
private:
    vector<PastLife> pastLives;
    int currentGeneration;
    vector<LegacyItem> inheritedLegacies;  // 当前世继承的传承
    LegacyRelic relic;

    int KarmaMagnitude(int karma) const {
        return karma >= 0 ? karma : -karma;
    }

    wstring SelectDaoName(const PastLife& life) const {
        if (life.battlesWon >= max(20, life.totalEvents / 3)) return L"杀伐大道";
        if (life.karma >= 120) return L"护生大道";
        if (life.karma <= -120) return L"血煞大道";
        if (life.totalEvents >= 80) return L"因果大道";
        if (life.ageAtDeath >= 500) return L"长生大道";
        if (life.npcsMet >= 20) return L"众生大道";
        return L"本我大道";
    }

    wstring DescribeDao(const wstring& daoName) const {
        if (daoName == L"杀伐大道") return L"以战止战，越是死局越能看见破局之线。";
        if (daoName == L"护生大道") return L"以护道济世立身，善缘会在轮回中反复回响。";
        if (daoName == L"血煞大道") return L"以血债与恐惧铸道，旧怨会比肉身活得更久。";
        if (daoName == L"因果大道") return L"能从偶然里看见必然，从旧事里牵出新局。";
        if (daoName == L"长生大道") return L"不只求寿数绵长，更求与天地法则同息。";
        if (daoName == L"众生大道") return L"道不独行，所结之人与所负之情都会化为路。";
        return L"尚未定型的祖境道痕，仍会随每一世选择而偏转。";
    }

    void InheritEchoesFromLastLife(const PastLife& last) {
        int inheritedCount = 0;
        for (int i = (int)last.legacies.size() - 1; i >= 0 && inheritedCount < 2; --i) {
            const LegacyItem& legacy = last.legacies[i];
            int inheritedPower = max(12, legacy.power / 2);
            wstring inheritedDesc = legacy.description;

            if (legacy.type == LEGACY_TECHNIQUE) {
                inheritedDesc = L"轮回后仍记得部分行功脉络与破境手感，像是前世亲手封存下来的道法残篇。";
            } else if (legacy.type == LEGACY_TREASURE) {
                inheritedDesc = L"上一世祭炼过的灵宝虽不能永存，却仍留下器纹与认主余响，会在梦里回应你。";
            } else if (legacy.type == LEGACY_MEMORY) {
                inheritedDesc = L"前世某些场景会反复重现，你知道那不是幻觉，而是尚未散尽的记忆。";
            } else if (legacy.type == LEGACY_REPUTATION) {
                inheritedDesc = L"前世留下的善名或恶名没有完全散去，这一世仍会以流言和态度的方式追上你。";
            } else if (legacy.type == LEGACY_KNOWLEDGE) {
                inheritedDesc = L"前世沉淀下来的判断与出手习惯仍留在骨子里，不经思考也会自然浮现。";
            }

            inheritedLegacies.push_back(LegacyItem(
                legacy.type,
                L"前世遗响·" + legacy.name,
                inheritedDesc,
                inheritedPower
            ));
            inheritedCount++;
        }
    }

public:
    LegacySystem() : currentGeneration(1) {}

    // 开始新的一世
    void StartNewLife() {
        currentGeneration++;

        // 根据前世成就决定继承什么
        if (!pastLives.empty()) {
            PastLife& last = pastLives.back();

            // 继承一部分前世传承
            if (last.realmReached >= 5) {
                inheritedLegacies.push_back(LegacyItem(
                    LEGACY_MEMORY,
                    L"前世记忆碎片",
                    L"保留了部分前世的修炼心得",
                    last.realmReached * 10
                ));
            }

            if (last.karma > 100) {
                inheritedLegacies.push_back(LegacyItem(
                    LEGACY_REPUTATION,
                    L"善名流传",
                    L"前世的善举让你受人尊敬",
                    50
                ));
            } else if (last.karma < -100) {
                inheritedLegacies.push_back(LegacyItem(
                    LEGACY_REPUTATION,
                    L"恶名昭著",
                    L"前世的罪孽仍被人铭记",
                    -50
                ));
            }

            if (last.battlesWon > 50) {
                inheritedLegacies.push_back(LegacyItem(
                    LEGACY_KNOWLEDGE,
                    L"战斗本能",
                    L"前世的战斗经验化作本能",
                    30
                ));
            }

            if (!last.legacies.empty()) {
                InheritEchoesFromLastLife(last);
            }
        }
    }

    // 结束当前一世，记录传承
    void EndCurrentLife(PastLife& life) {
        life.generation = currentGeneration;

        // 根据成就生成传承
        GenerateLegacies(life);
        AdvanceRelicFromLife(life);

        pastLives.push_back(life);
    }

    void AdvanceRelicFromLife(const PastLife& life) {
        if (life.realmReached < 12) return;

        relic.resonance += 10 + life.realmReached * 2 + life.battlesWon / 3 + life.totalEvents / 10;

        if (life.realmReached >= 17) {
            relic.awakenings += 1;
        }
        if (life.realmReached >= 19) {
            relic.daoLinked = true;
            relic.daoName = SelectDaoName(life);
            relic.daoDepth = min(999, relic.daoDepth + 30 + life.totalEvents / 8 + life.battlesWon / 4 + KarmaMagnitude(life.karma) / 8);
        }

        if (life.realmReached >= 19) {
            relic.aspect = relic.daoName + L"·祖境道痕";
        } else if (life.realmReached >= 17) {
            relic.aspect = L"通天杀伐";
        } else if (life.realmReached >= 14) {
            relic.aspect = L"镇界守御";
        } else if (life.realmReached >= 12) {
            relic.aspect = L"灵机演化";
        }
    }

    void GenerateLegacies(PastLife& life) {
        // 境界高可以留下功法
        if (life.realmReached >= 19) {
            life.legacies.push_back(LegacyItem(
                LEGACY_TECHNIQUE,
                SelectDaoName(life) + L"真名",
                L"上一世证成道祖，肉身与仙帝寿元都会走到尽头，唯有掌握的大道可与轮回共鸣。",
                160 + life.totalEvents / 4 + KarmaMagnitude(life.karma) / 6
            ));
        } else if (life.realmReached >= 10) {
            life.legacies.push_back(LegacyItem(
                LEGACY_TECHNIQUE,
                L"登仙道诀",
                L"前世冲过仙门后留下的行功脉络，并非道祖真传，却足以让这一世少走弯路。",
                80
            ));
        } else if (life.realmReached >= 5) {
            life.legacies.push_back(LegacyItem(
                LEGACY_TECHNIQUE,
                L"化神感悟",
                L"前世的修炼心得",
                50
            ));
        }

        // 事件多可以留下记忆
        if (life.totalEvents > 100) {
            life.legacies.push_back(LegacyItem(
                LEGACY_MEMORY,
                L"丰富阅历",
                L"前世的见闻",
                life.totalEvents / 2
            ));
        }

        // 战斗多可以留下战斗经验
        if (life.battlesWon > 30) {
            life.legacies.push_back(LegacyItem(
                LEGACY_KNOWLEDGE,
                L"战斗大师",
                L"无数战斗锤炼的技巧",
                life.battlesWon
            ));
        }

        if (life.realmReached >= 19) {
            life.legacies.push_back(LegacyItem(
                LEGACY_TREASURE,
                L"通天灵宝道胚",
                L"普通兵刃与法宝都会在岁月中朽坏，唯有被大道反复祭炼过的通天灵宝，才会留下可被下一世唤醒的道胚。",
                95 + life.realmReached * 4
            ));
        } else if (life.realmReached >= 17) {
            life.legacies.push_back(LegacyItem(
                LEGACY_TREASURE,
                L"通天灵宝残印",
                L"凡兵终会朽坏，唯有被大道反复祭炼过的重宝，才可能在轮回后留下认主痕迹。",
                70 + life.realmReached * 3
            ));
        } else if (life.realmReached >= 12) {
            life.legacies.push_back(LegacyItem(
                LEGACY_TREASURE,
                L"本命法宝器痕",
                L"前世祭炼过的本命法宝未能长存，却仍有一缕器纹与灵性在轮回里回荡。",
                35 + life.realmReached * 2
            ));
        }

        if (life.karma >= 120) {
            life.legacies.push_back(LegacyItem(
                LEGACY_REPUTATION,
                L"善名道契",
                L"你前世护道济世的因果尚未散尽，这一世更容易得到接引与信任。",
                40
            ));
        } else if (life.karma <= -120) {
            life.legacies.push_back(LegacyItem(
                LEGACY_REPUTATION,
                L"血债回声",
                L"前世种下的仇怨没有随肉身一并腐烂，恶名往往比尸骨活得更久。",
                40
            ));
        }
    }

    // 获取当前继承的加成
    int GetLegacyBonus(LegacyType type) {
        int bonus = 0;
        for (auto& legacy : inheritedLegacies) {
            if (legacy.type == type) {
                bonus += legacy.power;
            }
        }
        return bonus;
    }

    int GetRelicResonanceBonus() const {
        return relic.resonance / 20 + relic.awakenings * 10;
    }

    void AddRelicResonance(int amount) {
        relic.resonance = max(0, min(999, relic.resonance + amount));
    }

    void AddDaoDepth(int amount) {
        if (!relic.daoLinked) return;
        relic.daoDepth = max(0, min(999, relic.daoDepth + amount));
    }

    void AttuneDaoFromCurrentLife(int realmReached, int karma, int totalEvents,
                                  int battlesWon, int npcsMet, int ageAtAttainment) {
        if (realmReached < 19) return;

        PastLife imprint;
        imprint.realmReached = realmReached;
        imprint.karma = karma;
        imprint.totalEvents = totalEvents;
        imprint.battlesWon = battlesWon;
        imprint.npcsMet = npcsMet;
        imprint.ageAtDeath = ageAtAttainment;

        if (realmReached >= 20) {
            relic.daoLinked = true;
            relic.daoName = L"万道归一";
            relic.aspect = L"天道境·万道归一";
            relic.resonance = min(999, relic.resonance + 120 + battlesWon / 5);
            relic.daoDepth = 999;
            return;
        }

        wstring dao = SelectDaoName(imprint);
        relic.daoLinked = true;
        if (relic.daoName == L"未证大道" || relic.daoName.empty()) {
            relic.daoName = dao;
        } else if (relic.daoName != dao && relic.daoName.find(dao) == wstring::npos) {
            relic.daoName += L"、" + dao;
        }

        relic.aspect = dao + L"·祖境道痕";
        relic.resonance = min(999, relic.resonance + 40 + realmReached * 2 + battlesWon / 5);
        relic.daoDepth = min(999, relic.daoDepth + 45 + totalEvents / 10 + battlesWon / 5 + KarmaMagnitude(karma) / 10);
    }

    wstring GetDaoTier() const {
        if (!relic.daoLinked) return L"未证道祖";
        if (relic.daoDepth >= 240) return L"大道共生";
        if (relic.daoDepth >= 160) return L"祖境稳固";
        if (relic.daoDepth >= 80) return L"初掌大道";
        return L"道痕新成";
    }

    LegacyRelic& GetRelic() { return relic; }
    const LegacyRelic& GetRelic() const { return relic; }

    wstring GetRelicStatusText() const {
        wstringstream ss;
        ss << L"【通天灵宝残印】\n\n";
        ss << L"名号: " << relic.name << L"\n";
        ss << L"当前道痕: " << relic.aspect << L"\n";
        ss << L"共鸣值: " << relic.resonance << L"\n";
        ss << L"苏醒次数: " << relic.awakenings << L"\n";
        ss << L"本世加持: +" << GetRelicResonanceBonus() << L"\n";
        ss << L"掌道: " << (relic.daoLinked ? relic.daoName : L"尚未证成") << L"\n";
        ss << L"掌道深度: " << relic.daoDepth << L"（" << GetDaoTier() << L"）\n";
        if (relic.daoLinked) {
            ss << L"状态: 已沾染祖境余韵，" << DescribeDao(relic.daoName) << L"\n";
        } else {
            ss << L"状态: 仍在轮回中缓慢成形，尚未真正显化为完整灵宝。\n";
        }
        ss << L"\n说明: 凡兵会朽，普通法宝也会坏。能穿过轮回留下来的，不是实物本身，而是反复祭炼后仍未断绝的道痕。";
        return ss.str();
    }

    wstring GetDaoContextText() const {
        wstringstream ss;
        ss << L"通天灵宝: " << relic.name << L"，道痕 " << relic.aspect
           << L"，共鸣 " << relic.resonance << L"，苏醒 " << relic.awakenings << L" 次。";
        if (relic.daoLinked) {
            ss << L" 前世曾证 " << relic.daoName << L"，当前掌道深度 "
               << relic.daoDepth << L"（" << GetDaoTier() << L"）。"
               << DescribeDao(relic.daoName);
        } else {
            ss << L" 尚未真正与大道相连。";
        }
        ss << L" 普通兵刃和当世法宝不可跨世保存，跨世回响只来自记忆、道痕和通天灵宝残印。";
        return ss.str();
    }

    // 获取历史记录文本
    wstring GetHistoryText() {
        wstringstream ss;
        ss << L"【轮回记录】\n\n";
        ss << L"当前: 第" << currentGeneration << L"世\n\n";

        if (pastLives.empty()) {
            ss << L"这是你的第一世。";
        } else {
            ss << L"前世记录:\n";
            for (int i = pastLives.size() - 1; i >= max(0, (int)pastLives.size() - 3); i--) {
                auto& life = pastLives[i];
                ss << L"\n第" << life.generation << L"世: " << life.name << L"\n";
                ss << L"  境界: " << life.realmReached << L"\n";
                ss << L"  享年: " << life.ageAtDeath << L"岁\n";
                ss << L"  死因: " << life.causeOfDeath << L"\n";
                ss << L"  留下传承: " << life.legacies.size() << L"个\n";
            }
        }

        return ss.str();
    }

    // 获取当前继承列表
    wstring GetInheritedLegaciesText() {
        wstringstream ss;
        ss << L"【继承的传承】\n\n";

        if (inheritedLegacies.empty()) {
            ss << L"无";
        } else {
            for (auto& legacy : inheritedLegacies) {
                ss << L"◆ " << legacy.name << L"\n";
                ss << L"  " << legacy.description << L"\n";
                if (legacy.type == LEGACY_REPUTATION && legacy.power < 0) {
                    ss << L"  效果: " << legacy.power << L"\n\n";
                } else {
                    ss << L"  效果: +" << legacy.power << L"\n\n";
                }
            }
        }

        ss << L"\n" << GetRelicStatusText();

        return ss.str();
    }

    int GetGeneration() { return currentGeneration; }
    vector<PastLife>& GetPastLives() { return pastLives; }
    vector<LegacyItem>& GetInheritedLegacies() { return inheritedLegacies; }

    void Save(wofstream& file) {
        file << L"LEGACY_V2\n";
        file << currentGeneration << L"\n";
        file << inheritedLegacies.size() << L"\n";
        for (auto& legacy : inheritedLegacies) {
            file << (int)legacy.type << L"\n" << legacy.name << L"\n"
                 << legacy.description << L"\n" << legacy.power << L"\n";
        }
        file << relic.name << L"\n" << relic.resonance << L"\n" << relic.awakenings << L"\n"
             << relic.aspect << L"\n" << relic.daoLinked << L"\n"
             << relic.daoName << L"\n" << relic.daoDepth << L"\n";

        file << pastLives.size() << L"\n";
        for (auto& life : pastLives) {
            file << life.generation << L"\n" << life.name << L"\n"
                 << life.realmReached << L"\n" << life.ageAtDeath << L"\n"
                 << life.causeOfDeath << L"\n" << life.karma << L"\n"
                 << life.totalEvents << L"\n" << life.battlesWon << L"\n"
                 << life.npcsMet << L"\n";

            file << life.legacies.size() << L"\n";
            for (auto& legacy : life.legacies) {
                file << (int)legacy.type << L"\n" << legacy.name << L"\n"
                     << legacy.description << L"\n" << legacy.power << L"\n";
            }
        }
    }

    bool Load(wifstream& file) {
        wstring marker;
        getline(file, marker);
        if (marker.empty()) getline(file, marker);
        bool isV2 = (marker == L"LEGACY_V2");
        if (marker != L"LEGACY_V1" && !isV2) return false;

        file >> currentGeneration;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');

        size_t count = 0;
        file >> count;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        inheritedLegacies.clear();
        for (size_t i = 0; i < count; i++) {
            int type, power;
            wstring name, description;
            file >> type;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
            getline(file, name);
            getline(file, description);
            file >> power;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
            inheritedLegacies.push_back(LegacyItem(static_cast<LegacyType>(type), name, description, power));
        }

        getline(file, relic.name);
        file >> relic.resonance;
        file >> relic.awakenings;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        getline(file, relic.aspect);
        file >> relic.daoLinked;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        if (isV2) {
            getline(file, relic.daoName);
            file >> relic.daoDepth;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
        } else {
            relic.daoName = relic.daoLinked ? L"本我大道" : L"未证大道";
            relic.daoDepth = relic.daoLinked ? relic.resonance / 2 : 0;
        }

        file >> count;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        pastLives.clear();
        for (size_t i = 0; i < count; i++) {
            PastLife life;
            file >> life.generation;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
            getline(file, life.name);
            file >> life.realmReached >> life.ageAtDeath;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
            getline(file, life.causeOfDeath);
            file >> life.karma >> life.totalEvents >> life.battlesWon >> life.npcsMet;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');

            size_t legacyCount = 0;
            file >> legacyCount;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
            for (size_t j = 0; j < legacyCount; j++) {
                int type, power;
                wstring name, description;
                file >> type;
                file.ignore(numeric_limits<streamsize>::max(), L'\n');
                getline(file, name);
                getline(file, description);
                file >> power;
                file.ignore(numeric_limits<streamsize>::max(), L'\n');
                life.legacies.push_back(LegacyItem(static_cast<LegacyType>(type), name, description, power));
            }
            pastLives.push_back(life);
        }
        return true;
    }
};

// ==================== 成就系统 ====================
struct Achievement {
    wstring name;
    wstring description;
    bool unlocked;

    Achievement(wstring n, wstring d) : name(n), description(d), unlocked(false) {}
};

class AchievementSystem {
private:
    vector<Achievement> achievements;

public:
    AchievementSystem() {
        InitAchievements();
    }

    void InitAchievements() {
        achievements.push_back(Achievement(L"初次飞升", L"第一次达到飞升境界"));
        achievements.push_back(Achievement(L"百战不殆", L"赢得100场战斗"));
        achievements.push_back(Achievement(L"善行千里", L"因果值达到200"));
        achievements.push_back(Achievement(L"魔道至尊", L"因果值低于-200"));
        achievements.push_back(Achievement(L"长生不老", L"活到500岁"));
        achievements.push_back(Achievement(L"证道成祖", L"达到道祖境界"));
        achievements.push_back(Achievement(L"万道归一", L"达到天道境"));
        achievements.push_back(Achievement(L"十世轮回", L"经历10次轮回"));
        achievements.push_back(Achievement(L"传承者", L"留下5个以上传承"));
    }

    void CheckAchievements(PastLife& life, int generation) {
        // 检查各种成就
        if (life.realmReached >= 10 && !achievements[0].unlocked) {
            achievements[0].unlocked = true;
        }

        if (life.battlesWon >= 100 && !achievements[1].unlocked) {
            achievements[1].unlocked = true;
        }

        if (life.karma >= 200 && !achievements[2].unlocked) {
            achievements[2].unlocked = true;
        }

        if (life.karma <= -200 && !achievements[3].unlocked) {
            achievements[3].unlocked = true;
        }

        if (life.ageAtDeath >= 500 && !achievements[4].unlocked) {
            achievements[4].unlocked = true;
        }

        if (life.realmReached >= 19 && !achievements[5].unlocked) {
            achievements[5].unlocked = true;
        }

        if (life.realmReached >= 20 && !achievements[6].unlocked) {
            achievements[6].unlocked = true;
        }

        if (generation >= 10 && !achievements[7].unlocked) {
            achievements[7].unlocked = true;
        }

        if (life.legacies.size() >= 5 && !achievements[8].unlocked) {
            achievements[8].unlocked = true;
        }
    }

    wstring GetAchievementsText() {
        wstringstream ss;
        ss << L"【成就】\n\n";

        int unlocked = 0;
        for (auto& ach : achievements) {
            if (ach.unlocked) {
                ss << L"✓ ";
                unlocked++;
            } else {
                ss << L"  ";
            }
            ss << ach.name << L" - " << ach.description << L"\n";
        }

        ss << L"\n解锁: " << unlocked << L"/" << achievements.size();

        return ss.str();
    }

    void Save(wofstream& file) {
        file << L"ACHIEVEMENTS_V1\n";
        file << achievements.size() << L"\n";
        for (auto& ach : achievements) {
            file << ach.unlocked << L"\n";
        }
    }

    bool Load(wifstream& file) {
        wstring marker;
        getline(file, marker);
        if (marker.empty()) getline(file, marker);
        if (marker != L"ACHIEVEMENTS_V1") return false;

        size_t count = 0;
        file >> count;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        for (size_t i = 0; i < count && i < achievements.size(); i++) {
            bool unlocked;
            file >> unlocked;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
            achievements[i].unlocked = unlocked;
        }
        return true;
    }
};
