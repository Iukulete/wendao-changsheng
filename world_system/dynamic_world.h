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
    wstring worldEraName;
    random_device rd;
    mt19937 gen;

    vector<wstring> npcNames = {
        L"剑痴·李云天", L"丹仙·林若雪", L"魔修·血煞", L"阵法师·王大力",
        L"琴仙·萧月", L"体修·铁山", L"符师·张三丰", L"暗修·影无痕",
        L"佛修·慧能", L"妖修·白狐", L"散修·江南", L"剑宗·独孤求败",
        L"魔君·天魔", L"仙子·紫霞", L"道君·玄天"
    };

    vector<wstring> GetEraNpcNames() const {
        if (worldEraName == L"灵机蒸汽纪") {
            return {
                L"炉师·沈玄枢", L"齿轮修士·陆青铜", L"飞舟司·顾远航", L"阵械师·林百铆",
                L"灵煤商·秦九炉", L"旧宗剑客·叶寒机", L"机关傀师·苏铁心", L"蒸汽丹师·韩白雾",
                L"工坊客卿·楚鸣钟", L"量产符师·白千线", L"巡炉执事·萧赤阀", L"矿脉散修·许黑铲",
                L"灵机女冠·沈听澜", L"飞梭匣主·陆断星", L"铸炉盟使·顾燃灯"
            };
        }
        if (worldEraName == L"星穹道网纪") {
            return {
                L"远讯使·林星回", L"道网客·秦无延", L"星舟剑修·叶渡河", L"万象录师·苏镜台",
                L"节点守·韩九环", L"灵网散人·楚回声", L"榜单修士·白观澜", L"外域客·萧逐星",
                L"神识医修·许闻微", L"数据阁主·沈算天", L"坠星符师·陆拾光", L"远程弟子·顾寒窗",
                L"断链刺客·林暗潮", L"星港管事·秦越洲", L"虚阵师·叶空明"
            };
        }
        if (worldEraName == L"末法裂变纪") {
            return {
                L"枯井守·沈半瓢", L"配给执事·陆算盘", L"阵械破境者·顾残灯", L"争粮散修·林苦渡",
                L"旧派长老·秦守缺", L"灵井猎人·叶断泉", L"替道医修·苏寒针", L"秘境走私客·韩无契",
                L"末法剑客·楚灰刃", L"荒庙符师·白纸灯", L"劫粮体修·萧铁肩", L"枯潮女冠·许冷月",
                L"井盟巡使·沈寸灵", L"裂变术士·陆无常", L"藏丹客·顾一粒"
            };
        }
        if (worldEraName == L"废土返道纪") {
            return {
                L"拾荒修士·沈破罐", L"黑雨镇邪使·陆无伞", L"残宗向导·顾灰路", L"古机猎人·林铁骨",
                L"返道火种·秦守灯", L"荒墟医修·叶缝魂", L"迁徙队长·苏背山", L"废城符师·韩裂墙",
                L"旧库守门人·楚锈锁", L"荒野剑客·白断碑", L"邪祟剥皮客·萧黑雨", L"灵粮师·许半仓",
                L"黑匣译者·沈听噪", L"残塔佛修·陆灰烛", L"返道盟使·顾归墟"
            };
        }
        if (worldEraName == L"仙朝鼎盛纪") {
            return {
                L"天册使·沈承诏", L"隐龙世子·陆怀璧", L"气运榜首·顾青云", L"朝宗剑侍·林听诏",
                L"王族医修·秦明棠", L"册封吏·叶执圭", L"旧盟客卿·苏玄礼", L"金印符师·韩照壁",
                L"仙朝巡狩·楚御风", L"门阀女修·白绛雪", L"榜外散修·萧无籍", L"龙脉阵师·许观玺",
                L"功勋武修·沈破阵", L"密诏暗线·陆无名", L"朝堂丹师·顾清炉"
            };
        }
        return npcNames;
    }

    DynamicNPC::Goal PickEraGoal(int index) const {
        if (worldEraName == L"灵机蒸汽纪") {
            if (index % 4 == 0) return DynamicNPC::GOAL_WEALTH;
            if (index % 4 == 1) return DynamicNPC::GOAL_FAME;
        } else if (worldEraName == L"星穹道网纪") {
            if (index % 3 == 0) return DynamicNPC::GOAL_FAME;
            if (index % 3 == 1) return DynamicNPC::GOAL_BREAKTHROUGH;
        } else if (worldEraName == L"末法裂变纪") {
            if (index % 3 == 0) return DynamicNPC::GOAL_WEALTH;
            if (index % 3 == 1) return DynamicNPC::GOAL_REVENGE;
        } else if (worldEraName == L"废土返道纪") {
            if (index % 3 == 0) return DynamicNPC::GOAL_PEACE;
            if (index % 3 == 1) return DynamicNPC::GOAL_WEALTH;
        } else if (worldEraName == L"仙朝鼎盛纪") {
            if (index % 3 == 0) return DynamicNPC::GOAL_FAME;
            if (index % 3 == 1) return DynamicNPC::GOAL_BREAKTHROUGH;
        }
        return static_cast<DynamicNPC::Goal>(rand() % 5);
    }

public:
    DynamicWorld() : worldTime(0), gen(rd()) {
        worldEraName = L"灵气初盛纪";
        InitNPCs();
        InitWorldEvents();
    }

    void SetEraFlavor(const wstring& eraName) {
        worldEraName = eraName.empty() ? L"灵气初盛纪" : eraName;
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
        vector<wstring> names = GetEraNpcNames();
        // 生成15个初始NPC
        for (int i = 0; i < min(15, (int)names.size()); i++) {
            int realm = 1 + rand() % 5;  // 炼气期到化神期
            DynamicNPC npc(names[i], realm);
            npc.goal = PickEraGoal(i);
            if (worldEraName == L"末法裂变纪" || worldEraName == L"废土返道纪") {
                npc.lifespan = max(55, npc.lifespan - 12 - rand() % 18);
                npc.karma -= rand() % 20;
            } else if (worldEraName == L"仙朝鼎盛纪") {
                npc.karma += rand() % 25;
            }
            npcs.push_back(npc);
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
        if (worldEraName == L"灵机蒸汽纪") {
            worldEvents.push_back(WorldEvent(
                L"【灵机浪潮】工坊扩张",
                L"灵石驱动的工坊与阵械城邦快速扩张，修炼不再只靠山门闭关。",
                10,
                WorldEvent::HEAVENLY_VISION
            ));
        } else if (worldEraName == L"星穹道网纪") {
            worldEvents.push_back(WorldEvent(
                L"【道网潮汐】灵网共振",
                L"跨洲灵网短暂共振，远方宗门的试炼、传讯与招揽同时涌来。",
                10,
                WorldEvent::HEAVENLY_VISION
            ));
        } else if (worldEraName == L"末法裂变纪") {
            worldEvents.push_back(WorldEvent(
                L"【末法震荡】灵井枯潮",
                L"多处灵井出现枯潮，修士争夺资源的烈度明显上升。",
                8,
                WorldEvent::SECT_WAR
            ));
        } else if (worldEraName == L"废土返道纪") {
            worldEvents.push_back(WorldEvent(
                L"【废土异动】古机苏醒",
                L"荒野深处有旧文明灵机复苏，残存宗门被迫迁徙或结盟。",
                8,
                WorldEvent::DEMON_INVASION
            ));
        } else if (worldEraName == L"仙朝鼎盛纪") {
            worldEvents.push_back(WorldEvent(
                L"【仙朝册封】气运开榜",
                L"仙朝重开气运榜，宗门、世家与散修都在争夺名位。",
                10,
                WorldEvent::TREASURE_APPEAR
            ));
        } else {
            worldEvents.push_back(WorldEvent(
                L"【古修遗府】山门寻踪",
                L"灵气初盛，诸宗正在追索新出世的古修遗府；机缘更容易现世，但仍要靠胆色、判断和根骨去接。",
                10,
                WorldEvent::ANCIENT_RUIN
            ));
        }
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
        vector<pair<wstring, wstring>> events;
        if (worldEraName == L"灵机蒸汽纪") {
            events = {
                {L"【灵机事故】飞舟坠城", L"一艘大型灵机飞舟坠入坊市，工坊派与旧宗门互相指责。"},
                {L"【阵械竞标】量产灵具", L"数家工坊争夺量产灵具的阵图，散修也被卷入试炼。"},
                {L"【机关兽潮】失控暴走", L"旧型号机关兽成群失控，沿灵石矿脉四处游荡。"},
                {L"【工坊秘约】炼器联盟", L"炼器师们试图绕开宗门垄断，建立新的灵机联盟。"}
            };
        } else if (worldEraName == L"星穹道网纪") {
            events = {
                {L"【道网断链】远讯中止", L"一段跨洲灵网忽然断链，多个宗门怀疑有人篡改阵台。"},
                {L"【星舟归航】外域线索", L"跨洲星舟带回外域秘境坐标，引来高阶修士暗中下注。"},
                {L"【神识泄露】旧案翻出", L"灵网节点泄出旧年影像，许多被掩盖的因果重新浮出。"},
                {L"【远程收徒】寒门入榜", L"大宗门通过灵网收徒，寒门修士也可能一夜改命。"}
            };
        } else if (worldEraName == L"末法裂变纪") {
            events = {
                {L"【灵井争夺】三宗对峙", L"一口未枯灵井引来三宗对峙，低阶修士被迫选择阵营。"},
                {L"【替道实验】阵械破境", L"有人公开用阵械替代苦修破境，旧派修士大为震怒。"},
                {L"【秘境封锁】资源禁令", L"各宗封锁秘境入口，散修开始铤而走险。"},
                {L"【枯潮蔓延】灵气骤降", L"灵气枯潮向外扩散，闭关和突破都变得更昂贵。"}
            };
        } else if (worldEraName == L"废土返道纪") {
            events = {
                {L"【荒野迁徙】残宗结盟", L"数个残存宗门向安全地带迁徙，沿途不断爆发冲突。"},
                {L"【古机苏醒】废墟鸣钟", L"旧文明废墟深处响起钟声，古代灵机开始无差别巡行。"},
                {L"【邪祟潮生】黑雨入城", L"黑雨后荒野邪祟逼近城邦，许多传承洞府被迫开放。"},
                {L"【返道烽火】重建法统", L"幸存修士试图重建道统，却必须先解决粮、灵石和秩序。"}
            };
        } else if (worldEraName == L"仙朝鼎盛纪") {
            events = {
                {L"【仙朝征召】册封入榜", L"仙朝征召修士入榜，册封、气运与宗门利益纠缠不清。"},
                {L"【王族秘境】血脉试炼", L"王族秘境开启，非世家修士也想借机改命。"},
                {L"【气运倾斜】新贵崛起", L"气运榜突然变动，某个小族被推到天下目光中央。"},
                {L"【朝宗暗斗】旧盟破裂", L"仙朝与宗门之间旧盟出现裂痕，暗线修士开始活动。"}
            };
        } else {
            events = {
                {L"【魔族入侵】边境告急", L"魔气从边境裂缝涌出，正魔两道都被迫表态。"},
                {L"【秘境开启】上古遗迹现世", L"一处古修遗迹破土现世，天材地宝与杀机一同浮出。"},
                {L"【宗门大战】正魔对决", L"正魔两道冲突扩大，附近坊市人人自危。"},
                {L"【天劫降临】有人渡劫", L"远处劫云压境，许多修士都赶去观摩或捡漏。"},
                {L"【宝物出世】众修争夺", L"疑似重宝出世，各路修士都在追索气机。"}
            };
        }

        uniform_int_distribution<> dis(0, events.size() - 1);
        auto chosen = events[dis(gen)];
        WorldEvent::EventType type = static_cast<WorldEvent::EventType>(rand() % 5);
        if (chosen.first.find(L"争夺") != wstring::npos || chosen.first.find(L"大战") != wstring::npos || chosen.first.find(L"对峙") != wstring::npos) {
            type = WorldEvent::SECT_WAR;
        } else if (chosen.first.find(L"秘境") != wstring::npos || chosen.first.find(L"宝物") != wstring::npos || chosen.first.find(L"星舟") != wstring::npos) {
            type = WorldEvent::TREASURE_APPEAR;
        } else if (chosen.first.find(L"古机") != wstring::npos || chosen.first.find(L"邪祟") != wstring::npos || chosen.first.find(L"魔族") != wstring::npos) {
            type = WorldEvent::DEMON_INVASION;
        } else if (chosen.first.find(L"异象") != wstring::npos || chosen.first.find(L"道网") != wstring::npos || chosen.first.find(L"气运") != wstring::npos) {
            type = WorldEvent::HEAVENLY_VISION;
        }

        worldEvents.push_back(WorldEvent(
            chosen.first,
            chosen.second,
            5 + rand() % 10,
            type
        ));

        AddHistory(chosen.first);
    }

    wstring GetGoalText(DynamicNPC::Goal goal) const {
        switch (goal) {
            case DynamicNPC::GOAL_BREAKTHROUGH: return L"求突破";
            case DynamicNPC::GOAL_REVENGE: return L"寻仇";
            case DynamicNPC::GOAL_WEALTH: return L"争资源";
            case DynamicNPC::GOAL_FAME: return L"争名位";
            case DynamicNPC::GOAL_PEACE: return L"避世修行";
        }
        return L"未知";
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
        ss << L"时代纪元: " << worldEraName << L"\n";
        ss << L"世界时间: 第" << worldTime << L"年\n";
        ss << L"存活修士: " << GetAliveNPCs().size() << L"人\n";
        auto alive = GetAliveNPCs();
        if (!alive.empty()) {
            ss << L"活跃倾向: ";
            int count = 0;
            for (auto npc : alive) {
                if (count++ >= 3) break;
                if (count > 1) ss << L"、";
                ss << npc->name << L"(" << GetGoalText(npc->goal) << L")";
            }
            ss << L"\n";
        }

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

    vector<wstring> GetRecentHistoryEntries(int limit = 8) const {
        vector<wstring> result;
        if (limit <= 0 || worldHistory.empty()) return result;
        int start = max(0, (int)worldHistory.size() - limit);
        for (int i = start; i < (int)worldHistory.size(); i++) {
            result.push_back(worldHistory[i]);
        }
        return result;
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
