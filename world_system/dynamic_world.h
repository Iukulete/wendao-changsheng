// 动态世界系统 - NPC会自己"活动"
#pragma once
#include <string>
#include <vector>
#include <random>
#include <algorithm>
#include <fstream>
#include <limits>
#include <sstream>

using namespace std;

// ==================== NPC数据结构 ====================
struct DynamicNPC {
    wstring name;
    int realm;
    int shownRealm;
    int level;
    int age;
    int lifespan;
    int karma;

    // NPC目标
    enum Goal {
        GOAL_BREAKTHROUGH,  // 追求突破
        GOAL_REVENGE,       // 寻仇
        GOAL_WEALTH,        // 积累资源
        GOAL_FAME,          // 追求名声
        GOAL_PEACE          // 平静修炼
    };
    Goal goal;

    // NPC性格
    enum Personality {
        AGGRESSIVE,   // 好战
        CAUTIOUS,     // 谨慎
        FRIENDLY,     // 友好
        CUNNING,      // 狡猾
        RIGHTEOUS     // 正义
    };
    Personality personality;

    // 关系网
    wstring ally;        // 盟友
    wstring enemy;       // 敌人
    int playerRelation;  // 与玩家的关系 (-100 到 100)

    // 状态
    bool isAlive;
    bool hasAscended;

    DynamicNPC(wstring n, int r) : name(n), realm(r), shownRealm(r), level(1), age(20),
                                   lifespan(100), karma(0), playerRelation(0),
                                   isAlive(true), hasAscended(false) {
        goal = static_cast<Goal>(rand() % 5);
        personality = static_cast<Personality>(rand() % 5);
        if (rand() % 100 < 24 && shownRealm > 1) {
            shownRealm -= 1 + rand() % min(2, shownRealm);
        }
    }
};

// ==================== 世界事件 ====================
struct WorldEvent {
    wstring title;
    wstring description;
    int turnsRemaining;
    bool isActive;

    enum EventType {
        SECT_WAR,       // 宗门战争
        TREASURE_APPEAR,// 宝物出现
        DEMON_INVASION, // 魔族入侵
        HEAVENLY_VISION,// 天降异象
        ANCIENT_RUIN    // 上古遗迹
    };
    EventType type;

    WorldEvent(wstring t, wstring d, int turns, EventType et)
        : title(t), description(d), turnsRemaining(turns), isActive(true), type(et) {}
};

// ==================== 动态世界管理器 ====================
class DynamicWorld {
private:
    vector<DynamicNPC> npcs;
    vector<WorldEvent> worldEvents;
    int worldTime;  // 游戏内时间（年）
    random_device rd;
    mt19937 gen;

    vector<wstring> npcNames = {
        L"剑痴·李云天", L"丹仙·林若雪", L"魔修·血煞", L"阵法师·王大力",
        L"琴仙·萧月", L"体修·铁山", L"符师·张三丰", L"暗修·影无痕",
        L"佛修·慧能", L"妖修·白狐", L"散修·江南", L"剑宗·独孤求败",
        L"魔君·天魔", L"仙子·紫霞", L"道君·玄天"
    };

public:
    DynamicWorld() : worldTime(0), gen(rd()) {
        InitNPCs();
        InitWorldEvents();
    }

    void Reset() {
        npcs.clear();
        worldEvents.clear();
        worldHistory.clear();
        worldTime = 0;
        InitNPCs();
        InitWorldEvents();
    }

    void InitNPCs() {
        // 生成15个初始NPC
        for (int i = 0; i < min(15, (int)npcNames.size()); i++) {
            int realm = 1 + rand() % 5;  // 炼气期到化神期
            npcs.push_back(DynamicNPC(npcNames[i], realm));
        }

        // 建立部分关系
        if (npcs.size() >= 3) {
            npcs[0].ally = npcs[1].name;
            npcs[1].ally = npcs[0].name;
            npcs[0].enemy = npcs[2].name;
            npcs[2].enemy = npcs[0].name;
        }
    }

    void InitWorldEvents() {
        worldEvents.push_back(WorldEvent(
            L"【天降异象】灵气暴动",
            L"天地灵气异常活跃，修炼速度翻倍！",
            10,
            WorldEvent::HEAVENLY_VISION
        ));
    }

    // 世界更新（每次玩家行动调用）
    void Update() {
        worldTime++;

        // 更新所有NPC
        for (auto& npc : npcs) {
            if (!npc.isAlive) continue;

            NPCAction(npc);
            CheckNPCDeath(npc);
        }

        // 更新世界事件
        UpdateWorldEvents();

        // 有概率触发新的世界事件
        if (rand() % 20 == 0) {
            TriggerRandomWorldEvent();
        }
    }

    void NPCAction(DynamicNPC& npc) {
        npc.age++;

        // 根据目标行动
        switch (npc.goal) {
            case DynamicNPC::GOAL_BREAKTHROUGH:
                // 修炼
                if (rand() % 10 == 0) {
                    npc.level++;
                    if (npc.level >= 10) {
                        npc.level = 1;
                        npc.realm++;
                        if (npc.shownRealm < npc.realm && rand() % 100 < 35) {
                            npc.shownRealm++;
                        } else if (npc.shownRealm > npc.realm) {
                            npc.shownRealm = npc.realm;
                        }
                        // 境界突破事件
                        AddHistory(npc.name + L" 突破到新境界！");
                    }
                }
                break;

            case DynamicNPC::GOAL_REVENGE:
                // 寻找敌人
                if (!npc.enemy.empty()) {
                    auto enemy = FindNPC(npc.enemy);
                    if (enemy && enemy->isAlive) {
                        // 战斗
                        if (npc.realm > enemy->realm) {
                            enemy->isAlive = false;
                            AddHistory(npc.name + L" 击败了 " + enemy->name);
                            npc.goal = DynamicNPC::GOAL_PEACE;  // 复仇完成
                        }
                    }
                }
                break;

            case DynamicNPC::GOAL_WEALTH:
                // 积累资源（暂时只是模拟）
                break;

            case DynamicNPC::GOAL_FAME:
                // 挑战其他修士
                if (rand() % 15 == 0) {
                    auto target = GetRandomNPC();
                    if (target && target->name != npc.name && target->isAlive) {
                        AddHistory(npc.name + L" 挑战了 " + target->name);
                    }
                }
                break;

            case DynamicNPC::GOAL_PEACE:
                // 平静修炼
                break;
        }
    }

    void CheckNPCDeath(DynamicNPC& npc) {
        // 寿命检查
        if (npc.age >= npc.lifespan) {
            npc.isAlive = false;
            AddHistory(npc.name + L" 寿元耗尽，坐化");
        }

        // 飞升检查
        if (npc.realm >= 10 && rand() % 20 == 0) {
            npc.hasAscended = true;
            npc.isAlive = false;
            AddHistory(npc.name + L" 成功飞升仙界！");
        }
    }

    void UpdateWorldEvents() {
        for (auto& event : worldEvents) {
            if (event.isActive) {
                event.turnsRemaining--;
                if (event.turnsRemaining <= 0) {
                    event.isActive = false;
                    AddHistory(event.title + L" 已结束");
                }
            }
        }
    }

    void TriggerRandomWorldEvent() {
        vector<wstring> titles = {
            L"【魔族入侵】边境告急",
            L"【秘境开启】上古遗迹现世",
            L"【宗门大战】正魔对决",
            L"【天劫降临】有人渡劫",
            L"【宝物出世】众修争夺"
        };

        uniform_int_distribution<> dis(0, titles.size() - 1);
        wstring title = titles[dis(gen)];

        worldEvents.push_back(WorldEvent(
            title,
            L"修真界发生了大事！",
            5 + rand() % 10,
            static_cast<WorldEvent::EventType>(rand() % 5)
        ));

        AddHistory(title);
    }

    // 获取当前活跃的世界事件
    WorldEvent* GetActiveWorldEvent() {
        for (auto& event : worldEvents) {
            if (event.isActive) return &event;
        }
        return nullptr;
    }

    // 获取所有活着的NPC
    vector<DynamicNPC*> GetAliveNPCs() {
        vector<DynamicNPC*> alive;
        for (auto& npc : npcs) {
            if (npc.isAlive) alive.push_back(&npc);
        }
        return alive;
    }

    // 玩家与NPC互动
    void PlayerInteractWithNPC(wstring npcName, int relationChange) {
        auto npc = FindNPC(npcName);
        if (npc) {
            npc->playerRelation += relationChange;
            npc->playerRelation = max(-100, min(100, npc->playerRelation));
        }
    }

    // 获取世界状态摘要
    wstring GetWorldSummary() {
        wstringstream ss;
        ss << L"【修真界现状】\n\n";
        ss << L"世界时间: 第" << worldTime << L"年\n";
        ss << L"存活修士: " << GetAliveNPCs().size() << L"人\n";

        auto event = GetActiveWorldEvent();
        if (event) {
            ss << L"\n当前事件: " << event->title << L"\n";
            ss << event->description << L"\n";
            ss << L"剩余: " << event->turnsRemaining << L"回合";
        } else {
            ss << L"\n当前无重大事件";
        }

        return ss.str();
    }

    int GetWorldTime() { return worldTime; }

    int GetCultivationMultiplier() {
        auto event = GetActiveWorldEvent();
        if (event && event->type == WorldEvent::HEAVENLY_VISION) {
            return 2;
        }
        return 1;
    }

    int GetAdventureRiskBonus() {
        auto event = GetActiveWorldEvent();
        if (!event) return 0;
        if (event->type == WorldEvent::DEMON_INVASION || event->type == WorldEvent::SECT_WAR) {
            return 15;
        }
        if (event->type == WorldEvent::TREASURE_APPEAR || event->type == WorldEvent::ANCIENT_RUIN) {
            return -10;
        }
        return 0;
    }

    wstring GetRecentHistoryText(int limit = 8) {
        wstringstream ss;
        ss << L"【近年大事】\n";
        if (worldHistory.empty()) {
            ss << L"暂无";
            return ss.str();
        }

        int start = max(0, (int)worldHistory.size() - limit);
        for (int i = start; i < (int)worldHistory.size(); i++) {
            ss << L"- " << worldHistory[i] << L"\n";
        }
        return ss.str();
    }

    void Save(wofstream& file) {
        file << L"WORLD_V2\n";
        file << worldTime << L"\n";

        file << npcs.size() << L"\n";
        for (auto& npc : npcs) {
            file << npc.name << L"\n";
            file << npc.realm << L" " << npc.shownRealm << L" " << npc.level << L" " << npc.age << L" "
                 << npc.lifespan << L" " << npc.karma << L" " << (int)npc.goal << L" "
                 << (int)npc.personality << L" " << npc.playerRelation << L" "
                 << npc.isAlive << L" " << npc.hasAscended << L"\n";
            file << npc.ally << L"\n";
            file << npc.enemy << L"\n";
        }

        file << worldEvents.size() << L"\n";
        for (auto& event : worldEvents) {
            file << event.title << L"\n";
            file << event.description << L"\n";
            file << event.turnsRemaining << L" " << event.isActive << L" " << (int)event.type << L"\n";
        }

        file << worldHistory.size() << L"\n";
        for (auto& item : worldHistory) {
            file << item << L"\n";
        }
    }

    bool Load(wifstream& file) {
        wstring marker;
        getline(file, marker);
        if (marker.empty()) getline(file, marker);
        if (marker != L"WORLD_V2") return false;

        file >> worldTime;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');

        size_t npcCount = 0;
        file >> npcCount;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        npcs.clear();
        for (size_t i = 0; i < npcCount; i++) {
            wstring name;
            getline(file, name);
            int realm, shownRealm, level, age, lifespan, karma, goal, personality, relation;
            bool alive, ascended;
            file >> realm >> shownRealm >> level >> age >> lifespan >> karma >> goal >> personality
                 >> relation >> alive >> ascended;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');

            DynamicNPC npc(name, realm);
            npc.shownRealm = shownRealm;
            npc.level = level;
            npc.age = age;
            npc.lifespan = lifespan;
            npc.karma = karma;
            npc.goal = static_cast<DynamicNPC::Goal>(goal);
            npc.personality = static_cast<DynamicNPC::Personality>(personality);
            npc.playerRelation = relation;
            npc.isAlive = alive;
            npc.hasAscended = ascended;
            getline(file, npc.ally);
            getline(file, npc.enemy);
            npcs.push_back(npc);
        }

        size_t eventCount = 0;
        file >> eventCount;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        worldEvents.clear();
        for (size_t i = 0; i < eventCount; i++) {
            wstring title, description;
            getline(file, title);
            getline(file, description);
            int turns, type;
            bool active;
            file >> turns >> active >> type;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
            WorldEvent event(title, description, turns, static_cast<WorldEvent::EventType>(type));
            event.isActive = active;
            worldEvents.push_back(event);
        }

        size_t historyCount = 0;
        file >> historyCount;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        worldHistory.clear();
        for (size_t i = 0; i < historyCount; i++) {
            wstring item;
            getline(file, item);
            worldHistory.push_back(item);
        }
        return true;
    }

private:
    DynamicNPC* FindNPC(wstring name) {
        for (auto& npc : npcs) {
            if (npc.name == name) return &npc;
        }
        return nullptr;
    }

    DynamicNPC* GetRandomNPC() {
        auto alive = GetAliveNPCs();
        if (alive.empty()) return nullptr;
        return alive[rand() % alive.size()];
    }

    vector<wstring> worldHistory;
    void AddHistory(wstring event) {
        if (worldHistory.size() > 100) {
            worldHistory.erase(worldHistory.begin());
        }
        worldHistory.push_back(event);
    }
};
