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
    if (hits >= 2) return true;

    for (wchar_t ch : text) {
        if ((ch >= L'A' && ch <= L'Z') || (ch >= L'a' && ch <= L'z')) return true;
        if ((ch >= 0x3040 && ch <= 0x30ff) ||  // Japanese kana
            (ch >= 0xac00 && ch <= 0xd7af) ||  // Hangul
            (ch >= 0x0400 && ch <= 0x04ff) ||  // Cyrillic
            (ch >= 0x0370 && ch <= 0x03ff) ||  // Greek
            (ch >= 0x0590 && ch <= 0x06ff) ||  // Hebrew/Arabic
            (ch >= 0x0900 && ch <= 0x097f) ||  // Devanagari
            (ch >= 0x0980 && ch <= 0x09ff) ||  // Bengali
            (ch >= 0x0e00 && ch <= 0x0e7f) ||  // Thai
            (ch >= 0x1000 && ch <= 0x109f)) {  // Myanmar
            return true;
        }
    }
    return false;
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

    bool ContainsAny(const wstring& text, const vector<wstring>& keys) const {
        for (const auto& key : keys) {
            if (text.find(key) != wstring::npos) return true;
        }
        return false;
    }

    wstring TrimContext(const wstring& text) const {
        size_t start = text.find_first_not_of(L" \t\r\n");
        if (start == wstring::npos) return L"";
        size_t end = text.find_last_not_of(L" \t\r\n");
        return text.substr(start, end - start + 1);
    }

    wstring StripContextPrefix(const wstring& line) const {
        wstring text = TrimContext(line);
        while (!text.empty() && (text[0] == L'-' || text[0] == L'*')) {
            text = TrimContext(text.substr(1));
        }

        static const vector<wstring> labels = {
            L"本世势力牵连", L"本世势力", L"本世器物", L"旧世残响", L"前世未竟因果",
            L"本世主线", L"本世持续线索", L"轮回余烬", L"重大事件", L"纪元转折因由",
            L"纪元转折", L"时代变迁", L"鸿蒙天象", L"天象影响", L"鸿蒙参悟", L"伴生玉佩"
        };
        for (const auto& label : labels) {
            size_t labelPos = text.find(label);
            if (labelPos == wstring::npos) continue;
            size_t colon = text.find(L":", labelPos + label.size());
            size_t cnColon = text.find(L"：", labelPos + label.size());
            if (colon == wstring::npos || (cnColon != wstring::npos && cnColon < colon)) {
                colon = cnColon;
            }
            if (colon != wstring::npos) {
                return TrimContext(text.substr(colon + 1));
            }
        }
        return text;
    }

    wstring ShortContext(const wstring& text, size_t limit = 44) const {
        wstring clean;
        bool lastSpace = false;
        for (wchar_t ch : text) {
            if (ch == L'\r' || ch == L'\n' || ch == L'\t') {
                if (!lastSpace) {
                    clean.push_back(L' ');
                    lastSpace = true;
                }
            } else {
                clean.push_back(ch);
                lastSpace = (ch == L' ');
            }
        }
        clean = TrimContext(clean);
        if (clean.size() > limit) {
            clean = clean.substr(0, limit) + L"…";
        }
        return clean;
    }

    wstring FirstLineContaining(const wstring& text, const vector<wstring>& keys) const {
        wstringstream ss(text);
        wstring line;
        while (getline(ss, line)) {
            if (ContainsAny(line, keys)) {
                return ShortContext(StripContextPrefix(line));
            }
        }
        return L"";
    }

    wstring FirstHistoryContaining(const PlayerContext& player, const vector<wstring>& keys) const {
        for (int i = (int)player.history.size() - 1; i >= 0; --i) {
            if (ContainsAny(player.history[i], keys)) {
                return ShortContext(StripContextPrefix(player.history[i]));
            }
        }
        return L"";
    }

    wstring FirstBulletAfter(const wstring& text, const wstring& header) const {
        size_t pos = text.find(header);
        if (pos == wstring::npos) return L"";
        wstringstream ss(text.substr(pos));
        wstring line;
        bool afterHeader = false;
        while (getline(ss, line)) {
            if (!afterHeader) {
                afterHeader = true;
                continue;
            }
            wstring stripped = StripContextPrefix(line);
            if (!stripped.empty() && stripped != header) {
                return ShortContext(stripped);
            }
        }
        return L"";
    }

    wstring LastBulletAfter(const wstring& text, const wstring& header) const {
        size_t pos = text.find(header);
        if (pos == wstring::npos) return L"";
        wstringstream ss(text.substr(pos));
        wstring line;
        bool afterHeader = false;
        wstring result;
        while (getline(ss, line)) {
            if (!afterHeader) {
                afterHeader = true;
                continue;
            }
            wstring trimmed = TrimContext(line);
            if (trimmed.rfind(L"- ", 0) == 0) break;
            wstring stripped = StripContextPrefix(line);
            if (!stripped.empty() && stripped != header) {
                result = ShortContext(stripped);
            }
        }
        return result;
    }

    wstring PickFallbackFocus(PlayerContext& player) const {
        vector<wstring> candidates;
        auto add = [&](const wstring& focus) {
            if (find(candidates.begin(), candidates.end(), focus) == candidates.end()) {
                candidates.push_back(focus);
            }
        };

        if (player.legacyState.find(L"前世未竟因果") != wstring::npos ||
            player.worldState.find(L"前世未竟因果") != wstring::npos) {
            add(L"unfinished");
        }
        if (player.familyState.find(L"伴生玉佩") != wstring::npos ||
            player.worldState.find(L"伴生玉佩") != wstring::npos ||
            player.legacyState.find(L"伴生玉佩") != wstring::npos) {
            add(L"jade");
        }
        if (player.worldState.find(L"近年大事") != wstring::npos ||
            (player.history.size() > 0 && FirstHistoryContaining(player, {L"天下大事"}) != L"")) {
            add(L"world");
        }
        if (player.worldState.find(L"旧世残响") != wstring::npos ||
            player.legacyState.find(L"旧世残响") != wstring::npos ||
            player.worldState.find(L"纪元转折因由") != wstring::npos) {
            add(L"remnant");
        }
        if (player.worldState.find(L"鸿蒙天象") != wstring::npos ||
            player.worldState.find(L"天象影响") != wstring::npos ||
            player.daoState.find(L"当前当世鸿蒙天象") != wstring::npos) {
            add(L"hongmeng");
        }
        if (player.worldState.find(L"本世持续线索") != wstring::npos ||
            FirstHistoryContaining(player, {L"本世线索推进"}) != L"") {
            add(L"story");
        }
        if (player.worldState.find(L"寿元压力") != wstring::npos &&
            (player.worldState.find(L"寿元危急") != wstring::npos ||
             player.worldState.find(L"寿元压力已经很重") != wstring::npos ||
             player.worldState.find(L"仙帝") != wstring::npos)) {
            add(L"lifespan");
        }
        if (player.daoState.find(L"大道特性") != wstring::npos ||
            player.daoState.find(L"掌道") != wstring::npos) {
            add(L"dao");
        }
        if (player.worldState.find(L"本世器物") != wstring::npos) {
            add(L"artifact");
        }
        if (player.socialState.find(L"本世人脉") != wstring::npos ||
            player.socialState.find(L"近日风声") != wstring::npos ||
            player.socialState.find(L"人情余波") != wstring::npos ||
            player.socialState.find(L"势力余波") != wstring::npos) {
            add(L"social");
        }
        if (player.worldState.find(L"本世势力牵连") != wstring::npos ||
            player.familyState.find(L"本世势力") != wstring::npos) {
            add(L"faction");
        }
        if (candidates.empty()) return L"generic";

        int seed = player.age + player.realm * 3 + (player.karma >= 0 ? player.karma : -player.karma) +
                   (int)player.history.size() * 5;
        return candidates[seed % (int)candidates.size()];
    }

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
        wstring focus = PickFallbackFocus(player);
        if (focus == L"faction") {
            return player.karma < -40 ? L"【危机】势力旧债" : L"【因果】势力来书";
        }
        if (focus == L"artifact") {
            return L"【奇遇】当世器鸣";
        }
        if (focus == L"unfinished") {
            return L"【因果】前世未竟";
        }
        if (focus == L"jade") {
            return L"【因果】玉佩微温";
        }
        if (focus == L"world") {
            return L"【因果】天下余波";
        }
        if (focus == L"remnant") {
            return L"【传承】旧世残响";
        }
        if (focus == L"hongmeng") {
            return L"【传承】鸿蒙天象";
        }
        if (focus == L"story") {
            return L"【因果】本世线头";
        }
        if (focus == L"lifespan") {
            return player.realm >= 18 ? L"【危机】仙寿将尽" : L"【危机】寿元迫近";
        }
        if (focus == L"social") {
            return L"【奇遇】人情暗流";
        }
        if (focus == L"dao") {
            return L"【传承】道痕回声";
        }

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
        wstring focus = PickFallbackFocus(player);
        wstring faction = FirstLineContaining(player.worldState, {L"本世势力牵连", L"本世势力"});
        if (faction.empty()) {
            faction = FirstLineContaining(player.familyState, {L"本世势力"});
        }
        wstring artifact = FirstBulletAfter(player.worldState, L"本世器物");
        if (artifact.empty()) {
            artifact = FirstLineContaining(player.worldState, {L"（当世兵刃", L"（当世法宝", L"本世器物"});
        }
        wstring hook = LastBulletAfter(player.worldState, L"本世持续线索");
        if (hook.empty()) {
            hook = FirstLineContaining(player.worldState, {L"本世主线"});
        }
        wstring remnant = FirstLineContaining(player.worldState + L"\n" + player.legacyState, {L"旧世残响", L"旧世", L"断代"});
        wstring jade = FirstLineContaining(player.familyState + L"\n" + player.worldState + L"\n" + player.legacyState,
            {L"伴生玉佩", L"黑白旧玉", L"梦中玉意", L"阴阳玉痕"});
        wstring hongmengOmen = FirstLineContaining(player.worldState + L"\n" + player.daoState + L"\n" + player.legacyState,
            {L"鸿蒙天象", L"当前当世鸿蒙天象"});
        wstring hongmengInfluence = FirstLineContaining(player.worldState + L"\n" + player.daoState,
            {L"天象影响", L"本世天象偏向"});
        wstring unfinished = FirstLineContaining(player.legacyState + L"\n" + player.worldState, {L"前世未竟因果", L"前世未竟", L"未竟"});
        if (unfinished.empty()) {
            unfinished = FirstHistoryContaining(player, {L"前世未竟", L"未竟因果"});
        }
        wstring worldEvent = FirstBulletAfter(player.worldState, L"近年大事");
        if (worldEvent.empty()) {
            worldEvent = FirstLineContaining(player.worldState, {L"重大事件"});
        }
        if (worldEvent.empty()) {
            worldEvent = FirstHistoryContaining(player, {L"天下大事", L"突破", L"坐化", L"飞升", L"击败", L"挑战"});
        }
        wstring socialAftershock = FirstBulletAfter(player.socialState, L"近日风声");
        wstring social = FirstLineContaining(player.socialState, {
            L"势力牵连", L"父亲", L"母亲", L"同代", L"欺压者", L"竞争者", L"长辈", L"联系人",
            L"功法见证者", L"旧名仰慕者", L"旧名追债人", L"器痕识别者"
        });

        if (focus == L"faction" && !faction.empty()) {
            wstringstream ss;
            ss << L"你外出时，" << faction << L"的旧债忽然被人当众提起；旁观者有人羡慕，也有人等你出错。";
            if (!hook.empty()) ss << L"此事又牵到" << hook;
            return ss.str();
        }
        if (focus == L"artifact" && !artifact.empty()) {
            wstringstream ss;
            ss << L"你随身的" << artifact << L"忽然生出细微裂响，像在提醒你它只是今生器物，却可引出一段器痕因果。";
            return ss.str();
        }
        if (focus == L"unfinished" && !unfinished.empty()) {
            wstringstream ss;
            ss << L"一段前世未了的旧事重新浮上心头：" << unfinished << L"。今生有人借此设局，逼你表态。";
            return ss.str();
        }
        if (focus == L"jade" && !jade.empty()) {
            wstringstream ss;
            ss << L"夜半醒来，" << jade << L"在胸口微微发温，梦里残留几句前世旧语；你仍不知道它真正来历，只知道这不是寻常旧物。";
            return ss.str();
        }
        if (focus == L"world" && !worldEvent.empty()) {
            wstringstream ss;
            ss << L"近年大事没有停在传闻里：" << worldEvent << L"。它正改变路上的人心、资源和试炼规矩。";
            return ss.str();
        }
        if (focus == L"remnant" && !remnant.empty()) {
            wstringstream ss;
            ss << L"你在途中撞见一处被今世重新利用的旧世痕迹：" << remnant << L"。它不像普通秘境，更像上一纪元留下的账本。";
            return ss.str();
        }
        if (focus == L"hongmeng" && !hongmengOmen.empty()) {
            wstringstream ss;
            ss << L"夜色中，" << hongmengOmen << L"的投影压过识海。";
            if (!hongmengInfluence.empty()) {
                ss << hongmengInfluence;
            } else {
                ss << L"各方只敢追逐余光，却有人想借你的前世记忆辨认真伪。";
            }
            return ss.str();
        }
        if (focus == L"story" && !hook.empty()) {
            wstringstream ss;
            ss << L"上一件事没有真正结束：" << hook << L"。如今同一条线索换了面目再度靠近，像是在逼你给今生一个明确态度。";
            return ss.str();
        }
        if (focus == L"lifespan") {
            wstring lifespan = FirstLineContaining(player.worldState, {L"寿元压力"});
            wstringstream ss;
            ss << L"闭关醒来后，你第一次清楚听见寿元在神魂里作响：" << lifespan
               << L"有人拿延寿机缘试探你，也有人等你急着破境露出破绽。";
            return ss.str();
        }
        if (focus == L"social" && !social.empty()) {
            wstringstream ss;
            if (!socialAftershock.empty()) {
                ss << L"近日风声正在发酵：" << socialAftershock
                   << L"。这不是路人传闻，而是你与本世人脉之间继续变化的情绪余波。";
            } else {
                ss << L"近日" << social << L"开始频繁试探你，话里有认可也有轻慢，像是在等你露出前世不该有的破绽。";
            }
            return ss.str();
        }
        if (focus == L"dao") {
            wstringstream ss;
            ss << L"你行至灵气回旋处，心底大道旧痕微微发热；这不是境界压人，而是所掌之道在提醒你取舍。";
            return ss.str();
        }

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
        wstring focus = PickFallbackFocus(player);

        if (focus == L"faction") {
            choices.push_back(L"应约赴会");
            choices.push_back(L"暗查旧债");
            choices.push_back(player.karma < -40 ? L"借势反压" : L"暂避锋芒");
            return choices;
        }
        if (focus == L"artifact") {
            choices.push_back(L"祭出器物");
            choices.push_back(L"封存器痕");
            choices.push_back(L"转手换缘");
            return choices;
        }
        if (focus == L"unfinished") {
            choices.push_back(L"追问旧因");
            choices.push_back(L"稳住今生");
            choices.push_back(L"斩断牵连");
            return choices;
        }
        if (focus == L"jade") {
            choices.push_back(L"握玉静听");
            choices.push_back(L"藏起旧玉");
            choices.push_back(L"追问来历");
            return choices;
        }
        if (focus == L"world") {
            choices.push_back(L"趁势入局");
            choices.push_back(L"旁观风向");
            choices.push_back(L"暗记人名");
            return choices;
        }
        if (focus == L"story") {
            choices.push_back(L"追索线头");
            choices.push_back(L"借题布局");
            choices.push_back(L"暂压不表");
            return choices;
        }
        if (focus == L"lifespan") {
            choices.push_back(L"寻寿药");
            choices.push_back(L"闭死关");
            choices.push_back(player.realm >= 18 ? L"叩道门" : L"缓一缓");
            return choices;
        }
        if (focus == L"remnant") {
            choices.push_back(L"细查遗痕");
            choices.push_back(L"借势破局");
            choices.push_back(L"立刻退走");
            return choices;
        }
        if (focus == L"hongmeng") {
            choices.push_back(L"参悟投影");
            choices.push_back(L"追查显化");
            choices.push_back(L"避开禁忌");
            return choices;
        }
        if (focus == L"social") {
            if (ContainsAny(player.socialState, {L"失传古法", L"失传道法", L"功法见证者"})) {
                choices.push_back(L"藏锋应对");
                choices.push_back(L"请教残页");
                choices.push_back(L"顺势露手");
                return choices;
            }
            if (ContainsAny(player.socialState, {L"旧名仰慕者", L"旧名追债人", L"旧名"})) {
                choices.push_back(L"当众澄清");
                choices.push_back(L"借名递话");
                choices.push_back(L"暗查旧册");
                return choices;
            }
            if (ContainsAny(player.socialState, {L"器痕识别者", L"器痕"})) {
                choices.push_back(L"压住器鸣");
                choices.push_back(L"询问器痕");
                choices.push_back(L"借器破局");
                return choices;
            }
            choices.push_back(L"借势交谈");
            choices.push_back(L"冷眼旁观");
            choices.push_back(player.karma >= 0 ? L"给足体面" : L"反将一军");
            return choices;
        }
        if (focus == L"dao") {
            choices.push_back(L"顺道而行");
            choices.push_back(L"反观本心");
            choices.push_back(L"强压道痕");
            return choices;
        }

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
        ss << L"- 如果上下文出现“情绪”或“NPC情绪代理口吻”，要按该 NPC 的立场写即时反应：长辈可护短夸赞，同辈可嫉妒酸言，执事可冷脸卡资源，仇家可嘴硬设局；不要写成客气旁白。\n";
        ss << L"- NPC 可以傲慢、护短、嘴硬、暗讽、试探或押注，但不要变成无意义骂街；情绪必须服务修仙关系和后续取舍。\n";
        ss << L"- 如果本世人脉里出现“想要”“忌惮”或“下一步”，要让 NPC 按这些动机行动，像活人一样追求目标、回避风险、推进自己的局。\n";
        ss << L"- 如果本世人脉里出现“功法见证者”“旧名仰慕者”“旧名追债人”或“器痕识别者”，要把前世传承写成今生具体的人情压力；可以写懂行者认出失传古法，但不要直接揭穿前世身份。\n";
        ss << L"- 如果上下文出现“失传古法当世解读”，必须按当前时代处理旧法：仙朝定品、道网比对、灵机拆解、末法抢夺、废土重建法统等。\n";
        ss << L"- 如果上下文出现“近日风声”“人情余波”或“势力余波”，优先把它写成 NPC 记恩、记仇、夸赞、嫉妒、护短或设局的后续。\n";
        ss << L"- 如果上下文出现“关系数值”，正数代表亲近、认可或押注，负数代表嫉妒、轻慢、敌意或旧怨；事件要沿着这个关系继续发酵。\n";
        ss << L"- 如果上下文出现“本世势力”或“势力牵连”，优先复用该组织、身份、态度和旧债，不要凭空换一个无关宗门。\n";
        ss << L"- 当前世界不一定是纯古典修仙，也可能已演化到灵机蒸汽、星穹道网、末法裂变或废土返道时代，必须尊重上下文时代风貌。\n";
        ss << L"- 如果上下文出现“纪元转折因由”，要把它当成当前时代形成的前因，而不是可忽略的背景介绍。\n";
        ss << L"- 如果上下文出现“纪元年表”，可以把前几世的纪元变化当成历史压力或旧制度来源来写。\n";
        ss << L"- 如果上下文出现“近年大事”或“天下大事”，要把它写成正在改变人心、资源和试炼规矩的当代余波。\n";
        ss << L"- 如果当前世界里有“本世主线”或“本世持续线索”，优先让事件与其中一条线索产生关联，形成连续剧情。\n";
        ss << L"- 如果上下文出现“玉意梦兆”，要把它当成黑白旧玉给出的线索方向；可以写梦中玉意、阴阳玉痕和旧梦校准，但不能揭示玄牝轮回玉真名。\n";
        ss << L"- 如果上下文出现“旧世残响”，要把它写成上一纪元留下的物证、制度或遗址被当前纪元重新解释，而不是普通秘境。\n";
        ss << L"- 如果上下文出现“前世未竟因果”，优先让其中一条未了之事在今生重新开局，而不是只当背景设定。\n";
        ss << L"- 如果上下文中出现前世传承、旧名、通天灵宝残印、前世梦痕等信息，可以直接把事件写成上一世因果在这一世继续发酵。\n";
        ss << L"- 如果上下文出现“本世器物”，可以让这些兵刃或法宝在今生事件中发挥作用，但必须承认本体会损毁或失散，不能跨世保存。\n";
        ss << L"- 普通兵刃、丹药、材料和当世法宝只能属于这一世；它们会损毁或失散，不能写成跨世继承物。\n";
        ss << L"- 真正能跨过轮回的是记忆、因果、道痕，以及被大道反复祭炼过的通天灵宝残印。\n";
        ss << L"- 主角第一世自带黑白伴生玉佩；它和转世记忆有关，但主角不知道真相。事件里可以写玉佩发热、梦中玉意、阴阳玉痕或轮回回响，不要直接揭示它的鸿蒙至宝真身。\n";
        ss << L"- 如果上下文出现“大道特性”，事件中的优势与代价要贴合具体大道，不要把道祖强弱写成单纯境界碾压。\n";
        ss << L"- 仙帝仍有寿数限制；只有道祖能与所掌大道共生。道祖强弱取决于掌握的大道与掌道深度，不要写成单纯等级碾压。\n";
        ss << L"- 如果上下文出现“寿元压力”，事件要承认时间正在逼迫玩家；仙帝也会寿尽，只有道祖与大道共生后才不再被寿元追赶。\n";
        ss << L"- 九大鸿蒙至宝是创世级恒在之物，不是装备奖励；道祖无法毁灭，只有掌尽诸道的道祖-天道境具备理论毁灭力，但毁灭没有必要。\n";
        ss << L"- 九大鸿蒙至宝各有固定权柄：如果上下文给出某件至宝及其大道，必须按该权柄写，不要把九件混成同一种万能法宝。\n";
        ss << L"- 如果上下文出现“鸿蒙天象”或“天象影响”，优先按本世对应至宝、所映大道和当世影响写事件，不要泛化成普通法宝。\n";
        ss << L"- 如果写到鸿蒙至宝，只能写投影、线索、参悟、拒绝或遥远因果，不要写玩家直接获得或摧毁它们。\n";
        ss << L"- 如果上下文出现“鸿蒙参悟”，可以让对应至宝的投影记忆影响判断、道心或因果，但仍不能写成本体入手。\n";
        ss << L"- 道祖-天道境的意义是掌尽诸道、映射凌驾万道的力量，不是鼓励毁灭鸿蒙至宝。\n";
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
        if (!player.relationships.empty()) {
            ss << L"关系数值:\n";
            int shown = 0;
            for (const auto& pair : player.relationships) {
                ss << L"- " << pair.first << L": "
                   << (pair.second >= 0 ? L"+" : L"") << pair.second << L"\n";
                if (++shown >= 8) break;
            }
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

    wstring GenerateOutcome(PlayerContext& player, int choiceIndex, bool success,
                            const wstring& eventTitle = L"",
                            const wstring& eventDescription = L"",
                            const wstring& choiceText = L"") {
        uniform_int_distribution<> dis(0, templates.consequences.size() - 1);
        wstring consequence = templates.consequences[dis(gen)];
        wstring eventText = eventTitle + L" " + eventDescription + L" " + choiceText;
        auto containsAny = [](const wstring& text, const vector<wstring>& keys) {
            for (const auto& key : keys) {
                if (text.find(key) != wstring::npos) return true;
            }
            return false;
        };
        bool touchesRemnant = containsAny(eventText, {
            L"旧世", L"上一纪元", L"残响", L"断代", L"遗址", L"遗物",
            L"旧朝", L"金册", L"断网", L"残频", L"废炉", L"枯井", L"黑匣", L"古修"
        });
        bool touchesTreasure = eventText.find(L"通天灵宝") != wstring::npos ||
                               eventText.find(L"灵宝") != wstring::npos ||
                               eventText.find(L"道痕") != wstring::npos ||
                               eventText.find(L"器纹") != wstring::npos;
        bool touchesHongmeng = containsAny(eventText, {
            L"鸿蒙", L"创世级", L"天象", L"至宝", L"投影", L"显化",
            L"鸿蒙道印", L"造化青莲", L"玄牝轮回玉", L"太初源炉", L"归墟玄图",
            L"无量天书", L"开界神斧", L"太虚照世镜", L"万道母鼎"
        });
        bool touchesDao = containsAny(eventText, {
            L"大道", L"道祖", L"证道", L"掌道", L"天道", L"道音", L"道痕"
        });
        bool touchesFaction = containsAny(eventText, {
            L"本世势力", L"势力", L"旧债", L"名册", L"工坊", L"道网",
            L"仙朝", L"残宗", L"宗门", L"赴会", L"查债"
        });
        bool touchesArtifact = containsAny(eventText, {
            L"本世器物", L"当世兵刃", L"当世法宝", L"祭出器物",
            L"封存器痕", L"转手换缘", L"今生器物", L"借器痕辨"
        }) || (player.worldState.find(L"本世器物") != wstring::npos &&
              containsAny(eventText, {L"器物", L"兵刃", L"法宝", L"器痕"}));
        bool touchesUnfinished = containsAny(eventText, {
            L"前世未竟", L"未竟因果", L"追问旧因", L"旧因", L"稳住今生",
            L"借前世忆", L"借忆查因", L"以今证旧"
        }) || (!player.legacyState.empty() && player.legacyState.find(L"前世未竟因果") != wstring::npos &&
              containsAny(eventText, {L"前世", L"旧事", L"旧因", L"因果"}));
        bool touchesJade = containsAny(eventText, {
            L"伴生玉佩", L"黑白旧玉", L"玉佩", L"梦中玉意", L"阴阳玉痕",
            L"握玉", L"旧玉", L"握玉辨梦"
        });
        bool touchesStory = containsAny(eventText, {
            L"本世线头", L"本世主线", L"本世持续线索", L"上一件事", L"同一条线索",
            L"追索线头", L"借题布局", L"暂压不表"
        });
        bool touchesLifespan = containsAny(eventText, {
            L"寿元", L"仙寿", L"坐化", L"延寿", L"寿药", L"闭死关", L"叩道门"
        });
        wstring socialRumor = FirstBulletAfter(player.socialState, L"近日风声");
        wstring socialActor = FirstLineContaining(player.socialState, {
            L"功法见证者", L"旧名仰慕者", L"旧名追债人", L"器痕识别者",
            L"父亲", L"母亲", L"长辈", L"同代", L"欺压者", L"竞争者", L"联系人"
        });
        wstring socialContext = eventText + L" " + player.socialState + L" " + socialRumor + L" " + socialActor;
        bool touchesLostTechnique = containsAny(socialContext, {
            L"失传古法", L"失传道法", L"功法见证者", L"藏经", L"残页", L"行功", L"以旧法证"
        });
        bool touchesLegacySocial = containsAny(socialContext, {
            L"旧名仰慕者", L"旧名追债人", L"器痕识别者", L"旧名", L"器痕",
            L"追债", L"借器痕辨", L"借旧识气"
        });
        bool touchesSocial = player.socialState.find(L"本世人脉") != wstring::npos &&
                             (eventText.find(L"修士") != wstring::npos ||
                              eventText.find(L"长辈") != wstring::npos ||
                              eventText.find(L"同辈") != wstring::npos ||
                              eventText.find(L"执事") != wstring::npos ||
                              eventText.find(L"道友") != wstring::npos ||
                              eventText.find(L"父") != wstring::npos ||
                              eventText.find(L"母") != wstring::npos ||
                              eventText.find(L"近日风声") != wstring::npos ||
                              touchesLostTechnique || touchesLegacySocial);

        wstring action = choiceText.empty() ? L"作出抉择" : choiceText;

        wstringstream ss;
        if (success) {
            ss << L"你选择「" << action << L"」，";
            if (touchesJade) {
                ss << L"没有强求答案，只借玉佩温意稳住几段前世碎片，让今生仍由自己作主。";
            } else if (touchesUnfinished) {
                ss << L"没有把前世旧债当成梦兆，而是替今生争回了主动权。";
            } else if (touchesLostTechnique) {
                ss << L"没有急着炫耀旧法，只顺着残页破绽补了一手，让懂行者看见失传古法仍可在今生重开。";
            } else if (touchesLegacySocial) {
                ss << L"把前世留下的旧名、器痕或流言压成今生可用的人情筹码，没有让旁人直接定你的身份。";
            } else if (touchesFaction) {
                ss << L"顺势摸清了对方真正想要的筹码，本世势力对你的评价因此改写。";
            } else if (touchesArtifact) {
                ss << L"让今生器物完成了该做的事，也记住本体终会失散，只有器痕可能入梦。";
            } else if (touchesRemnant) {
                ss << L"没有把眼前线索当成普通机缘，而是看出旧世制度被今世重新改写的痕迹。";
            } else if (touchesHongmeng) {
                ss << L"没有妄求创世级本体，只借至宝投影校准道心，记住了这一缕鸿蒙参悟。";
            } else if (touchesTreasure) {
                ss << L"识海里的通天灵宝残印轻轻一震，像是承认你抓住了这一缕因果。";
            } else if (touchesSocial) {
                ss << L"这一步让旁人重新衡量你，本世人脉里的善意与嫉意都被牵动。";
            } else if (touchesStory) {
                ss << L"你没有把线索当成偶然，而是让它并入本世主线，后续人和事都会沿着这条脉络靠近。";
            } else if (touchesLifespan) {
                ss << L"你没有假装时间还很宽裕，而是用这次机缘替此世多争出一段路。";
            } else if (touchesDao) {
                ss << L"心底的道痕一闪即逝，" << consequence;
            } else {
                ss << L"局势顺着你的判断展开，" << consequence;
            }
            ss << L"\n修为+";
            ss << (50 + player.realm * 10);
            if (touchesRemnant) ss << L"，因果+8";
            if (touchesFaction) ss << L"，因果+6";
            if (touchesUnfinished) ss << L"，因果+10";
            if (touchesLostTechnique) ss << L"，因果+8，掌道+2";
            if (touchesLegacySocial && !touchesLostTechnique) ss << L"，因果+8";
            if (touchesJade) ss << L"，因果+5";
            if (touchesStory) ss << L"，因果+6";
            if (touchesLifespan) ss << L"，寿命+18";
            if (touchesHongmeng) ss << L"，掌道+6，灵宝共鸣+4，因果+6";
            if (touchesTreasure) ss << L"，灵宝共鸣+5";
            if (touchesDao) ss << L"，掌道+3";
            if (touchesArtifact && action.find(L"转手") != wstring::npos) ss << L"，灵石+15";
        } else {
            ss << L"你选择「" << action << L"」，";
            if (touchesJade) {
                ss << L"却太急着追问玉佩来历，梦中旧语反而扰乱心神，今生判断也被带偏。";
            } else if (touchesUnfinished) {
                ss << L"却被前世未竟因果牵着走，今生立场反而被旁人看穿。";
            } else if (touchesLostTechnique) {
                ss << L"却把失传古法露得太直，藏经残页和旁人目光同时压来，今生身份变得更难遮掩。";
            } else if (touchesLegacySocial) {
                ss << L"却让旧名、器痕或追债流言先一步传开，旁人还没确认真相，已经开始按前世影子看你。";
            } else if (touchesFaction) {
                ss << L"却误判了势力旧债的分量，对方没有翻脸，只是把你的名字记得更重。";
            } else if (touchesArtifact) {
                ss << L"但今生器物承受不住这次取舍，裂痕留在本体上，也留在你心里。";
            } else if (touchesRemnant) {
                ss << L"却低估了旧世残响在当代秩序里的反噬，断代旧债顺势缠上心神。";
            } else if (touchesHongmeng) {
                ss << L"却把鸿蒙投影误认成可夺法宝，触犯禁忌后被至宝余光拒绝。";
            } else if (touchesTreasure) {
                ss << L"但今生根基还不足以承受那道器纹，通天灵宝残印很快沉寂下去。";
            } else if (touchesSocial) {
                ss << L"却误判了旁人的立场，本世人脉中有人因此记下了这笔账。";
            } else if (touchesStory) {
                ss << L"却让线索暂时沉入暗处，相关人等没有离开，只是换了更隐蔽的方式观察你。";
            } else if (touchesLifespan) {
                ss << L"却被寿元压力逼乱心神，越急着破局，越觉得此世时间正在变窄。";
            } else if (!player.legacyState.empty() && player.legacyState.find(L"前世") != wstring::npos) {
                ss << L"前世经验没能完全适配今生，" << consequence;
            } else {
                ss << L"情况不太妙，" << consequence;
            }
            ss << L"\n气血-";
            ss << (30 + player.realm * 5);
            if (touchesRemnant || touchesSocial) ss << L"，因果-8";
            if (touchesFaction) ss << L"，因果-6";
            if (touchesUnfinished) ss << L"，因果-10";
            if (touchesLostTechnique || touchesLegacySocial) ss << L"，因果-8";
            if (touchesJade) ss << L"，因果-5";
            if (touchesStory) ss << L"，因果-6";
            if (touchesLifespan) ss << L"，寿命-8";
            if (touchesHongmeng) ss << L"，因果-12";
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
