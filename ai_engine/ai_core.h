// AI引擎核心接口
// 这是一个可扩展的架构，后续可以接入真实的llama.cpp
#pragma once
#include <string>
#include <vector>
#include <map>
#include <random>
#include <fstream>
#include <limits>
#include <sstream>
#include <algorithm>
#include <iterator>
#include <windows.h>

using namespace std;

inline string WideToUtf8(const wstring& text) {
    if (text.empty()) return string();
    int size = WideCharToMultiByte(CP_UTF8, 0, text.c_str(), (int)text.size(), nullptr, 0, nullptr, nullptr);
    if (size <= 0) return string();
    string result(size, '\0');
    WideCharToMultiByte(CP_UTF8, 0, text.c_str(), (int)text.size(), &result[0], size, nullptr, nullptr);
    return result;
}

inline wstring Utf8ToWide(const string& text) {
    if (text.empty()) return wstring();
    int size = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), (int)text.size(), nullptr, 0);
    if (size <= 0) return wstring();
    wstring result(size, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, text.c_str(), (int)text.size(), &result[0], size);
    return result;
}

inline wstring CleanModelText(const wstring& text) {
    wstring out;
    for (wchar_t ch : text) {
        if (ch == L'\r' || ch == L'\n' || ch == L'\t' || ch >= 0x20) {
            if (ch != 0xFEFF && ch != 0xFFFD) {
                out.push_back(ch);
            }
        }
    }
    return out;
}

inline bool LooksMojibake(const wstring& text) {
    static const vector<wstring> markers = {
        L"锟", L"Ã", L"Â", L"æ", L"ç", L"濂", L"戠", L"鑰", L"绉", L"杩", L"勬", L"€"
    };
    int hits = 0;
    for (const auto& marker : markers) {
        if (text.find(marker) != wstring::npos) hits++;
    }
    return hits >= 2;
}

inline wstring ReadUtf8FileToWide(const string& path) {
    ifstream file(path, ios::binary);
    if (!file) return L"";
    string bytes((istreambuf_iterator<char>(file)), istreambuf_iterator<char>());
    return CleanModelText(Utf8ToWide(bytes));
}

inline wstring EscapeSaveField(const wstring& text) {
    wstring out;
    for (wchar_t ch : text) {
        if (ch == L'\\') out += L"\\\\";
        else if (ch == L'\n') out += L"\\n";
        else if (ch == L'\r') {}
        else out.push_back(ch);
    }
    return out;
}

inline wstring UnescapeSaveField(const wstring& text) {
    wstring out;
    for (size_t i = 0; i < text.size(); ++i) {
        if (text[i] == L'\\' && i + 1 < text.size()) {
            wchar_t next = text[i + 1];
            if (next == L'n') {
                out.push_back(L'\n');
                ++i;
            } else if (next == L'\\') {
                out.push_back(L'\\');
                ++i;
            } else {
                out.push_back(text[i]);
            }
        } else {
            out.push_back(text[i]);
        }
    }
    return out;
}

// ==================== 玩家上下文 ====================
struct PlayerContext {
    wstring name;
    int realm;
    wstring realmName;
    int karma;
    int age;
    wstring rootState;
    wstring worldState;
    wstring familyState;
    wstring socialState;
    wstring legacyState;
    wstring daoState;

    // 性格标签
    vector<wstring> personality;  // "善良", "邪恶", "谨慎", "冒险"

    // 历史关键事件
    vector<wstring> history;

    // 关系网络
    map<wstring, int> relationships;  // NPC名字 -> 好感度

    // 统计数据
    int killCount;
    int helpCount;
    int betrayalCount;

    PlayerContext() : realm(0), karma(0), age(0), killCount(0), helpCount(0), betrayalCount(0) {}
};

// ==================== AI生成器接口 ====================
class AIGenerator {
private:
    random_device rd;
    mt19937 gen;

    // 事件模板库
    struct EventTemplate {
        vector<wstring> locations;
        vector<wstring> characters;
        vector<wstring> items;
        vector<wstring> actions;
        vector<wstring> consequences;
    };

    EventTemplate templates;

public:
    AIGenerator() : gen(rd()) {
        InitTemplates();
    }

    void InitTemplates() {
        // 地点
        templates.locations = {
            L"幽暗山谷", L"灵气瀑布", L"古老废墟", L"迷雾森林", L"荒芜沙漠",
            L"冰封雪原", L"地底熔洞", L"云海天阶", L"星辰湖畔", L"混沌裂缝",
            L"时光遗迹", L"虚空之门", L"龙骨山脉", L"凤凰巢", L"神树根部"
        };

        // 角色
        templates.characters = {
            L"神秘老者", L"负伤女修", L"疯癫剑客", L"沉默炼丹师", L"优雅琴师",
            L"暴躁器修", L"阴险暗修", L"正气书生", L"诡异孩童", L"飘渺仙子",
            L"魔化妖兽", L"守护灵兽", L"傀儡道人", L"幻境之主", L"时间行者"
        };

        // 物品
        templates.items = {
            L"古修玉简", L"养灵葫芦", L"镇魂铜镜", L"镇狱小塔", L"青冥阵盘",
            L"翠灵丹瓶", L"瞬影符", L"灵石", L"月华草", L"玄铁矿",
            L"当世飞剑", L"残破器纹", L"旧主魂印", L"通天灵宝残印", L"大道真名"
        };

        // 行动
        templates.actions = {
            L"请求帮助", L"发起挑战", L"提供交易", L"讲述故事", L"传授秘法",
            L"寻求指引", L"警告危险", L"邀请同行", L"设下陷阱", L"揭露真相"
        };

        // 后果
        templates.consequences = {
            L"获得意外收获", L"引发连锁反应", L"改变了命运", L"陷入困境",
            L"揭开了秘密", L"结下了因果", L"领悟了真理", L"失去了重要之物",
            L"获得了盟友", L"树立了强敌", L"打开了新道路", L"关闭了旧机会"
        };
    }

    // 根据玩家上下文生成动态事件
    wstring GenerateEventTitle(PlayerContext& player) {
        uniform_int_distribution<> dis(0, templates.locations.size() - 1);
        wstring location = templates.locations[dis(gen)];

        // 根据因果值选择事件类型
        wstring type;
        if (player.karma > 50) {
            type = L"【机遇】";
        } else if (player.karma < -50) {
            type = L"【危机】";
        } else {
            type = L"【奇遇】";
        }

        return type + location;
    }

    wstring GenerateEventDescription(PlayerContext& player) {
        uniform_int_distribution<> charDis(0, templates.characters.size() - 1);
        uniform_int_distribution<> itemDis(0, templates.items.size() - 1);
        uniform_int_distribution<> actionDis(0, templates.actions.size() - 1);

        wstring character = templates.characters[charDis(gen)];
        wstring item = templates.items[itemDis(gen)];
        wstring action = templates.actions[actionDis(gen)];

        // 根据玩家历史调整描述
        wstring contextHint = L"";
        if (player.killCount > 10) {
            contextHint = L"对方似乎听说过你的凶名，显得格外警惕。";
        } else if (player.helpCount > 10) {
            contextHint = L"对方听闻你的善名，态度友好。";
        }

        wstring legacyHint = L"";
        if (player.legacyState.find(L"通天灵宝") != wstring::npos ||
            player.daoState.find(L"通天灵宝") != wstring::npos ||
            player.legacyState.find(L"法宝") != wstring::npos ||
            player.legacyState.find(L"灵宝") != wstring::npos) {
            legacyHint = L"识海深处忽有器鸣一闪而过，仿佛前世祭炼过的重宝也在注视这场相遇。";
        } else if (player.daoState.find(L"掌道深度") != wstring::npos ||
                   player.daoState.find(L"大道") != wstring::npos) {
            legacyHint = L"你心底有一缕大道旧痕微微发热，提醒你这不是偶然。";
        } else if (player.legacyState.find(L"战斗") != wstring::npos ||
                   player.legacyState.find(L"斗法") != wstring::npos) {
            legacyHint = L"你几乎本能地预判了对方下一步动作，这种熟悉感不像今生才有。";
        } else if (player.legacyState.find(L"前世") != wstring::npos ||
                   player.legacyState.find(L"轮回") != wstring::npos) {
            legacyHint = L"这场相逢让你短暂恍神，像是又踩进了一段前世未走完的因果。";
        }

        wstring eraHint = L"";
        if (player.worldState.find(L"灵机蒸汽纪") != wstring::npos) {
            eraHint = L"四周还能看见灵机工坊留下的蒸汽光痕与机关残响。";
        } else if (player.worldState.find(L"星穹道网纪") != wstring::npos) {
            eraHint = L"附近阵台与灵网节点交错运转，连偶遇都像被时代放大。";
        } else if (player.worldState.find(L"末法裂变纪") != wstring::npos) {
            eraHint = L"空气中的灵气明显更薄，谁都不愿轻易浪费任何一份机缘。";
        } else if (player.worldState.find(L"废土返道纪") != wstring::npos) {
            eraHint = L"远处荒野上仍残留古代文明崩毁后的焦黑痕迹，让人不敢久留。";
        }

        wstringstream ss;
        ss << L"你遇到了一位" << character << L"，ta手持" << item << L"，似乎想要" << action << L"。";
        if (!contextHint.empty()) {
            ss << contextHint;
        }
        if (!eraHint.empty()) {
            ss << eraHint;
        }
        if (!legacyHint.empty()) {
            ss << legacyHint;
        }

        return ss.str();
    }

    vector<wstring> GenerateChoices(PlayerContext& player) {
        vector<wstring> choices;

        // 基础选择
        choices.push_back(L"主动交谈");
        choices.push_back(L"小心观察");

        // 根据性格添加特殊选择
        bool hasPersonality = false;
        for (auto& p : player.personality) {
            if ((p == L"邪恶" || p.find(L"因果沉重") != wstring::npos || p.find(L"杀伐") != wstring::npos) && !hasPersonality) {
                choices.push_back(L"伺机出手");
                hasPersonality = true;
            } else if ((p == L"善良" || p.find(L"善缘") != wstring::npos) && !hasPersonality) {
                choices.push_back(L"援手相助");
                hasPersonality = true;
            } else if (p == L"冒险" && !hasPersonality) {
                choices.push_back(L"大胆尝试");
                hasPersonality = true;
            }
        }

        if (!hasPersonality && !player.daoState.empty() && player.daoState.find(L"大道") != wstring::npos) {
            choices.push_back(L"叩问道痕");
            hasPersonality = true;
        }

        if (!hasPersonality) {
            choices.push_back(L"谨慎离开");
        }

        return choices;
    }

    void WritePromptFile(PlayerContext& player) {
        wstringstream ss;
        ss << L"你是修仙 Roguelike 的事件叙事模型。\n";
        ss << L"请基于玩家上下文生成一个原创事件，严格输出5行：\n";
        ss << L"标题\n描述\n选项1\n选项2\n选项3\n\n";
        ss << L"写作约束:\n";
        ss << L"- 标题必须以【机缘】、【危机】、【奇遇】、【因果】、【传承】之一开头。\n";
        ss << L"- 描述45到90个中文字符，要贴合境界、因果、年龄、家世、人情风波、最近记忆和当前世界。\n";
        ss << L"- 可以写长辈认可、同辈嫉妒、被人巴结、遭人欺压、暗中试探、隐藏修为，但不要写成旁白总结。\n";
        ss << L"- 如果上下文出现“本世人脉”，优先复用其中的人名、态度和恩怨，让 NPC 像持续存在的人，不要每次都换成陌生路人。\n";
        ss << L"- 当前世界不一定是纯古典修仙，也可能已演化到灵机蒸汽、星穹道网、末法裂变或废土返道时代，必须尊重上下文时代风貌。\n";
        ss << L"- 如果当前世界里有“本世主线”或“本世持续线索”，优先让事件与其中一条线索产生关联，形成连续剧情。\n";
        ss << L"- 如果上下文中出现前世传承、旧名、通天灵宝残印、前世梦痕等信息，可以直接把事件写成上一世因果在这一世继续发酵。\n";
        ss << L"- 普通兵刃、丹药、材料和当世法宝只能属于这一世；它们会损毁或失散，不能写成跨世继承物。\n";
        ss << L"- 真正能跨过轮回的是记忆、因果、道痕，以及被大道反复祭炼过的通天灵宝残印。\n";
        ss << L"- 仙帝仍有寿数限制；只有道祖能与所掌大道共生。道祖强弱取决于掌握的大道与掌道深度，不要写成单纯等级碾压。\n";
        ss << L"- 九大鸿蒙至宝是创世级恒在之物，不是装备奖励；道祖无法毁灭，只有掌尽诸道的天道境具备理论毁灭力，但毁灭没有必要。\n";
        ss << L"- 如果写到鸿蒙至宝，只能写投影、线索、参悟、拒绝或遥远因果，不要写玩家直接获得或摧毁它们。\n";
        ss << L"- 三个选项各2到8个中文字符，只写行动短语，不要编号、不要解释、不要“请选择”。\n";
        ss << L"- 这是文字修仙 Roguelike 事件，不要写 UI、按钮、插图、美术包装或系统说明。\n";
        ss << L"- 借鉴修仙小说的节奏和意象，但必须原创，不要复述或仿写现成小说段落。\n\n";
        ss << L"玩家: " << player.name << L"\n";
        ss << L"境界编号: " << player.realm << L"\n";
        if (!player.realmName.empty()) {
            ss << L"境界名称: " << player.realmName << L"\n";
        }
        ss << L"因果: " << player.karma << L"\n";
        ss << L"年龄: " << player.age << L"\n";
        if (!player.rootState.empty()) {
            ss << L"灵根: " << player.rootState << L"\n";
        }
        if (!player.familyState.empty()) {
            ss << L"此世家世: " << player.familyState << L"\n";
        }
        if (!player.socialState.empty()) {
            ss << L"人情风波: " << player.socialState << L"\n";
        }
        if (!player.legacyState.empty()) {
            ss << L"轮回传承:\n" << player.legacyState << L"\n";
        }
        if (!player.daoState.empty()) {
            ss << L"大道与灵宝状态:\n" << player.daoState << L"\n";
        }
        ss << L"杀伐: " << player.killCount << L"\n";
        ss << L"助人: " << player.helpCount << L"\n";

        ss << L"性格: ";
        for (auto& item : player.personality) {
            ss << item << L" ";
        }
        ss << L"\n";

        if (!player.worldState.empty()) {
            ss << L"当前世界:\n" << player.worldState << L"\n";
        }

        ss << L"最近记忆:\n";
        size_t memoryLimit = min(player.history.size(), size_t(8));
        for (size_t i = 0; i < memoryLimit; i++) {
            ss << L"- " << player.history[player.history.size() - 1 - i] << L"\n";
        }

        ofstream file("ai_prompt.txt", ios::binary);
        if (!file) return;
        string utf8 = WideToUtf8(ss.str());
        file.write(utf8.data(), (streamsize)utf8.size());
    }

    bool TryLoadExternalEvent(wstring& title, wstring& description, vector<wstring>& choices) {
        wstring text = ReadUtf8FileToWide("ai_event.txt");
        if (text.empty()) return false;
        if (LooksMojibake(text)) return false;
        wstringstream ss(text);

        getline(ss, title);
        getline(ss, description);
        title = CleanModelText(title);
        description = CleanModelText(description);
        if (title.empty() || description.empty()) return false;
        if (LooksMojibake(title + description)) return false;

        choices.clear();
        wstring line;
        while (getline(ss, line)) {
            if (!line.empty() && line.back() == L'\r') {
                line.pop_back();
            }
            line = CleanModelText(line);
            if (!line.empty()) {
                choices.push_back(line);
            }
        }

        return choices.size() >= 2;
    }

    wstring GenerateOutcome(PlayerContext& player, int choiceIndex, bool success) {
        uniform_int_distribution<> dis(0, templates.consequences.size() - 1);
        wstring consequence = templates.consequences[dis(gen)];

        wstringstream ss;
        if (success) {
            if (!player.daoState.empty() && player.daoState.find(L"大道") != wstring::npos) {
                ss << L"你心底的道痕一闪即逝，" << consequence << L"\n修为+";
            } else {
                ss << L"你的决定很明智！" << consequence << L"\n修为+";
            }
            ss << (50 + player.realm * 10);
        } else {
            if (!player.legacyState.empty() && player.legacyState.find(L"前世") != wstring::npos) {
                ss << L"前世经验没能完全适配今生，" << consequence << L"\n气血-";
            } else {
                ss << L"情况不太妙..." << consequence << L"\n气血-";
            }
            ss << (30 + player.realm * 5);
        }

        return ss.str();
    }

    // 生成个性化的墓志铭
    wstring GenerateEpitaph(PlayerContext& player) {
        wstringstream ss;
        ss << L"【" << player.name << L"的一生】\n\n";

        if (player.karma > 100) {
            ss << L"此人心怀正道，救人无数，为修真界留下了美名。\n";
        } else if (player.karma < -100) {
            ss << L"此人杀戮成性，恶名昭著，最终遭天谴而亡。\n";
        } else {
            ss << L"此人平平无奇，在修真界没有留下什么痕迹。\n";
        }

        ss << L"\n生平事迹：\n";
        for (size_t i = 0; i < min(player.history.size(), size_t(5)); i++) {
            ss << L"- " << player.history[player.history.size() - 1 - i] << L"\n";
        }

        ss << L"\n享年：" << player.age << L"岁";

        return ss.str();
    }
};

// ==================== 上下文管理器 ====================
class ContextManager {
private:
    PlayerContext context;

public:
    void UpdateFromChoice(int choiceIndex, wstring outcome) {
        // 根据选择更新性格标签
        if (outcome.find(L"偷袭") != wstring::npos) {
            AddPersonality(L"邪恶");
            context.killCount++;
        } else if (outcome.find(L"帮助") != wstring::npos) {
            AddPersonality(L"善良");
            context.helpCount++;
        }

        // 添加到历史
        if (context.history.size() > 50) {
            context.history.erase(context.history.begin());
        }
        context.history.push_back(outcome.substr(0, 20) + L"...");
    }

    void AddPersonality(wstring trait) {
        // 检查是否已有
        for (auto& p : context.personality) {
            if (p == trait) return;
        }

        // 最多保留3个性格标签
        if (context.personality.size() >= 3) {
            context.personality.erase(context.personality.begin());
        }
        context.personality.push_back(trait);
    }

    PlayerContext& GetContext() { return context; }
    void SetContext(const PlayerContext& ctx) { context = ctx; }

    void Save(wofstream& file) {
        file << L"AI_CONTEXT_V2\n";
        file << context.name << L"\n";
        file << context.realm << L" " << context.karma << L" " << context.age << L" "
             << context.killCount << L" " << context.helpCount << L" " << context.betrayalCount << L"\n";
        file << EscapeSaveField(context.realmName) << L"\n";
        file << EscapeSaveField(context.rootState) << L"\n";
        file << EscapeSaveField(context.worldState) << L"\n";
        file << EscapeSaveField(context.familyState) << L"\n";
        file << EscapeSaveField(context.socialState) << L"\n";
        file << EscapeSaveField(context.legacyState) << L"\n";
        file << EscapeSaveField(context.daoState) << L"\n";

        file << context.personality.size() << L"\n";
        for (auto& item : context.personality) {
            file << EscapeSaveField(item) << L"\n";
        }

        file << context.history.size() << L"\n";
        for (auto& item : context.history) {
            file << EscapeSaveField(item) << L"\n";
        }

        file << context.relationships.size() << L"\n";
        for (auto& pair : context.relationships) {
            file << pair.first << L"\n" << pair.second << L"\n";
        }
    }

    bool Load(wifstream& file) {
        wstring marker;
        getline(file, marker);
        if (marker.empty()) getline(file, marker);
        bool isV2 = (marker == L"AI_CONTEXT_V2");
        if (marker != L"AI_CONTEXT_V1" && !isV2) return false;

        getline(file, context.name);
        file >> context.realm >> context.karma >> context.age
             >> context.killCount >> context.helpCount >> context.betrayalCount;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');

        if (isV2) {
            getline(file, context.realmName);
            getline(file, context.rootState);
            getline(file, context.worldState);
            getline(file, context.familyState);
            getline(file, context.socialState);
            getline(file, context.legacyState);
            getline(file, context.daoState);
            context.realmName = UnescapeSaveField(context.realmName);
            context.rootState = UnescapeSaveField(context.rootState);
            context.worldState = UnescapeSaveField(context.worldState);
            context.familyState = UnescapeSaveField(context.familyState);
            context.socialState = UnescapeSaveField(context.socialState);
            context.legacyState = UnescapeSaveField(context.legacyState);
            context.daoState = UnescapeSaveField(context.daoState);
        } else {
            context.realmName.clear();
            context.rootState.clear();
            context.worldState.clear();
            context.familyState.clear();
            context.socialState.clear();
            context.legacyState.clear();
            context.daoState.clear();
        }

        size_t count = 0;
        file >> count;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        context.personality.clear();
        for (size_t i = 0; i < count; i++) {
            wstring item;
            getline(file, item);
            if (isV2) item = UnescapeSaveField(item);
            context.personality.push_back(item);
        }

        file >> count;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        context.history.clear();
        for (size_t i = 0; i < count; i++) {
            wstring item;
            getline(file, item);
            if (isV2) item = UnescapeSaveField(item);
            context.history.push_back(item);
        }

        file >> count;
        file.ignore(numeric_limits<streamsize>::max(), L'\n');
        context.relationships.clear();
        for (size_t i = 0; i < count; i++) {
            wstring name;
            int relation;
            getline(file, name);
            file >> relation;
            file.ignore(numeric_limits<streamsize>::max(), L'\n');
            context.relationships[name] = relation;
        }
        return true;
    }
};
