// 多周目传承系统
#pragma once
#include <string>
#include <vector>
#include <map>
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

// ==================== 传承系统 ====================
class LegacySystem {
private:
    vector<PastLife> pastLives;
    int currentGeneration;
    vector<LegacyItem> inheritedLegacies;  // 当前世继承的传承

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
        }
    }

    // 结束当前一世，记录传承
    void EndCurrentLife(PastLife& life) {
        life.generation = currentGeneration;

        // 根据成就生成传承
        GenerateLegacies(life);

        pastLives.push_back(life);
    }

    void GenerateLegacies(PastLife& life) {
        // 境界高可以留下功法
        if (life.realmReached >= 10) {
            life.legacies.push_back(LegacyItem(
                LEGACY_TECHNIQUE,
                L"道祖心法",
                L"前世证道时的顿悟",
                100
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
                ss << L"  效果: +" << legacy.power << L"\n\n";
            }
        }

        return ss.str();
    }

    int GetGeneration() { return currentGeneration; }
    vector<PastLife>& GetPastLives() { return pastLives; }
    vector<LegacyItem>& GetInheritedLegacies() { return inheritedLegacies; }

    void Save(wofstream& file) {
        file << L"LEGACY_V1\n";
        file << currentGeneration << L"\n";
        file << inheritedLegacies.size() << L"\n";
        for (auto& legacy : inheritedLegacies) {
            file << (int)legacy.type << L"\n" << legacy.name << L"\n"
                 << legacy.description << L"\n" << legacy.power << L"\n";
        }

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
        if (marker != L"LEGACY_V1") return false;

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

        if (generation >= 10 && !achievements[6].unlocked) {
            achievements[6].unlocked = true;
        }

        if (life.legacies.size() >= 5 && !achievements[7].unlocked) {
            achievements[7].unlocked = true;
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
