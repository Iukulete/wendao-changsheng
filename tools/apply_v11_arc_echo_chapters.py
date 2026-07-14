# -*- coding: utf-8 -*-
"""Install v0.11 second-life chapters for the four persistent arc legacies.

Runs after v0.10. The v0.8 legacy tags stop being isolated random echoes: each
legacy opens a three-stage follow-up chapter in later lives, with persistent
progress, a terminal resolution and modest next-life effects. STORY_STATE_V4
remains backward compatible with V1/V2/V3.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
MARKER = "V0_11_ARC_ECHO_CHAPTERS"


def once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"Unable to patch {label}: anchor not found")
    return text.replace(old, new, 1)


def replace_region(text: str, start_marker: str, end_marker: str, new_text: str, label: str) -> str:
    start = text.find(start_marker)
    if start < 0:
        raise RuntimeError(f"Unable to patch {label}: start marker not found")
    end = text.find(end_marker, start)
    if end < 0:
        raise RuntimeError(f"Unable to patch {label}: end marker not found")
    return text[:start] + new_text + text[end:]


def main() -> int:
    if not SRC.exists():
        raise FileNotFoundError(f"Source file not found: {SRC}")
    text = SRC.read_text(encoding="utf-8")
    if MARKER in text:
        print("v0.11 arc echo chapters already applied.")
        return 0
    if "V0_10_JADE_WEAPON_AWAKENING" not in text or "V0_8_ARC_LEGACIES" not in text:
        raise RuntimeError("v0.8 arc legacies and v0.10 jade weapons must run before v0.11")

    text = once(text,
        "struct ArcLegacyState { // V0_8_ARC_LEGACIES\n"
        "    wstring jade;\n    wstring sect;\n    wstring family;\n    wstring rival;\n};",
        "struct ArcLegacyState { // V0_8_ARC_LEGACIES\n"
        "    wstring jade;\n    wstring sect;\n    wstring family;\n    wstring rival;\n};\n\n"
        "struct ArcEchoState { // V0_11_ARC_ECHO_CHAPTERS\n"
        "    int jadeStage;\n    int sectStage;\n    int familyStage;\n    int rivalStage;\n    int lastArc;\n"
        "    wstring jadeResolution;\n    wstring sectResolution;\n"
        "    wstring familyResolution;\n    wstring rivalResolution;\n\n"
        "    ArcEchoState() : jadeStage(0), sectStage(0), familyStage(0), rivalStage(0), lastArc(-1) {}\n};",
        "arc echo state type")

    text = once(text,
        "NarrativeArcState g_narrativeArcs;\nArcLegacyState g_arcLegacy;\n"
        "int g_pendingArc = -1;\nint g_pendingArcStage = -1;",
        "NarrativeArcState g_narrativeArcs;\nArcLegacyState g_arcLegacy;\n"
        "ArcEchoState g_arcEcho;\n"
        "int g_pendingArc = -1;\nint g_pendingArcStage = -1;\n"
        "int g_pendingArcEcho = -1;\nint g_pendingArcEchoStage = -1;",
        "arc echo globals")

    followup_block = r'''int& ArcEchoStageRef(int arc) { // V0_11_ARC_ECHO_CHAPTERS
    if (arc == ARC_SECT) return g_arcEcho.sectStage;
    if (arc == ARC_FAMILY) return g_arcEcho.familyStage;
    if (arc == ARC_RIVAL) return g_arcEcho.rivalStage;
    return g_arcEcho.jadeStage;
}

wstring& ArcEchoResolutionRef(int arc) {
    if (arc == ARC_SECT) return g_arcEcho.sectResolution;
    if (arc == ARC_FAMILY) return g_arcEcho.familyResolution;
    if (arc == ARC_RIVAL) return g_arcEcho.rivalResolution;
    return g_arcEcho.jadeResolution;
}

wstring ArcEchoStageLabel(int stage) {
    static const vector<wstring> labels = {L"待续", L"再逢", L"转折", L"定章"};
    return labels[max(0, min(3, stage))];
}

wstring BuildArcEchoDigest() {
    auto one = [](const wchar_t* name, int stage, const wstring& resolution) {
        wstringstream ss;
        ss << name << stage << L"/3·" << ArcEchoStageLabel(stage);
        if (!resolution.empty()) ss << L"·" << resolution;
        return ss.str();
    };
    return one(L"旧玉续章", g_arcEcho.jadeStage, g_arcEcho.jadeResolution) + L"｜" +
           one(L"山门续章", g_arcEcho.sectStage, g_arcEcho.sectResolution) + L"｜" +
           one(L"家世续章", g_arcEcho.familyStage, g_arcEcho.familyResolution) + L"｜" +
           one(L"战帖续章", g_arcEcho.rivalStage, g_arcEcho.rivalResolution);
}

bool IsArcEchoSmokeMode() {
    wchar_t value[16] = {};
    DWORD len = GetEnvironmentVariableW(L"WENDAO_ARC_ECHO_SMOKE", value, 16);
    return len > 0 && value[0] != L'0';
}

void PrimeArcEchoSmoke() {
    static bool primed = false;
    if (primed || !IsArcEchoSmokeMode()) return;
    primed = true;
    g_generation = max(2, g_generation);
    if (g_arcLegacy.jade.empty()) g_arcLegacy.jade = L"今生校旧";
    if (g_arcLegacy.sect.empty()) g_arcLegacy.sect = L"自立道统";
    if (g_arcLegacy.family.empty()) g_arcLegacy.family = L"护亲问源";
    if (g_arcLegacy.rival.empty()) g_arcLegacy.rival = L"照雪盟友";
    g_arcEcho = ArcEchoState();
    g_lastArcEchoEvent = -1000;
    AppendTraceLog(L"ARC_ECHO_SMOKE_PRIME", BuildArcLegacyDigest());
}

bool IsArcEchoAvailable(int arc) {
    return !ArcLegacyRef(arc).empty() && ArcEchoStageRef(arc) < 3;
}

int PickArcEcho() {
    vector<int> weighted;
    int minimumStage = 3;
    for (int arc = ARC_JADE; arc <= ARC_RIVAL; ++arc) {
        if (IsArcEchoAvailable(arc)) minimumStage = min(minimumStage, ArcEchoStageRef(arc));
    }
    for (int arc = ARC_JADE; arc <= ARC_RIVAL; ++arc) {
        if (!IsArcEchoAvailable(arc)) continue;
        int stage = ArcEchoStageRef(arc);
        int weight = 3 + (3 - stage) * 3;
        if (stage == minimumStage) weight += 5;
        if (arc == g_arcEcho.lastArc) weight = max(1, weight / 3);
        for (int i = 0; i < weight; ++i) weighted.push_back(arc);
    }
    if (weighted.empty()) return -1;
    return weighted[Random(0, (int)weighted.size() - 1)];
}

wstring ResolveArcEchoTag(int arc, const wstring& choice) {
    if (arc == ARC_JADE) {
        if (choice == L"承认旧证") return L"守证旧我";
        if (choice == L"以今校旧") return L"今身定锚";
        return L"断梦留痕";
    }
    if (arc == ARC_SECT) {
        if (choice == L"续写旧律") return L"旧律新章";
        if (choice == L"与今门共议") return L"两代同门";
        return L"今世开宗";
    }
    if (arc == ARC_FAMILY) {
        if (choice == L"承脉也承债") return L"祖脉共担";
        if (choice == L"先护养育之恩") return L"养恩为先";
        return L"去名留义";
    }
    if (choice == L"再接照雪战帖") return L"再续宿敌";
    if (choice == L"先并肩破局") return L"并肩照雪";
    return L"相争不相害";
}

void ResolveArcEchoOutcome(const Event& event, const Choice& choice, wstring& outcome, bool success) {
    if (g_pendingArcEcho < ARC_JADE || g_pendingArcEcho > ARC_RIVAL || g_pendingArcEchoStage < 0) return;
    if (event.title.find(L"【定局续章·") == wstring::npos) return;
    int arc = g_pendingArcEcho;
    int stage = g_pendingArcEchoStage;
    g_pendingArcEcho = g_pendingArcEchoStage = -1;
    if (IsArcEchoSmokeMode()) success = true;

    if (stage < 2) {
        ArcEchoStageRef(arc) = min(3, stage + 1);
        g_arcEcho.lastArc = arc;
        if (!success) outcome += L"\n\n【续章带伤】这一步虽然付出代价，但旧约与今生的冲突已经无法退回原处。";
        AppendTraceLog(L"ARC_ECHO_STAGE", event.title + L" -> " +
            to_wstring(ArcEchoStageRef(arc)) + L"/3 | " + BuildArcEchoDigest());
        return;
    }

    if (!success) {
        outcome += L"\n\n【续章未定】最终判断尚未站稳，本章仍停在定章之前。";
        AppendTraceLog(L"ARC_ECHO_RETRY", event.title + L"保留2/3进度。");
        return;
    }

    wstring resolution = ResolveArcEchoTag(arc, choice.description);
    ArcEchoResolutionRef(arc) = resolution;
    ArcEchoStageRef(arc) = 3;
    g_arcEcho.lastArc = arc;
    if (arc == ARC_JADE) g_player.daoHeart += 4;
    else if (arc == ARC_SECT) g_player.reputation += 4;
    else if (arc == ARC_FAMILY) { g_player.daoHeart += 2; g_player.reputation += 2; }
    else if (resolution == L"再续宿敌") g_player.enmity += 3;
    else if (resolution == L"并肩照雪") g_player.reputation += 3;
    else g_player.daoHeart += 3;
    g_player.daoHeart = max(-999, min(999, g_player.daoHeart));
    g_player.reputation = max(-999, min(999, g_player.reputation));
    g_player.enmity = max(0, min(999, g_player.enmity));
    outcome += L"\n\n【续章定局】前世旧约经过今生检验，形成新的跨世结论：" + resolution + L"。";
    AddMemory(L"定局续章", event.title + L"以“" + resolution + L"”定章。它不是照搬前世，而是两世共同完成的判断。");
    AppendTraceLog(L"ARC_ECHO_RESOLVE", event.title + L" -> " + choice.description +
        L" -> " + resolution + L"\n" + BuildArcEchoDigest());
}

bool ShouldTriggerArcLegacyEvent() {
    PrimeArcEchoSmoke();
    bool smoke = IsArcEchoSmokeMode();
    if ((!smoke && g_generation <= 1) || !HasArcLegacy()) return false;
    int available = 0;
    for (int arc = ARC_JADE; arc <= ARC_RIVAL; ++arc) if (IsArcEchoAvailable(arc)) available++;
    if (available <= 0) return false;
    int cooldown = smoke ? 1 : 4;
    if (g_player.totalEvents - g_lastArcEchoEvent < cooldown) return false;
    if (smoke) return true;
    if (g_player.totalEvents < 2) return false;
    int progress = g_arcEcho.jadeStage + g_arcEcho.sectStage + g_arcEcho.familyStage + g_arcEcho.rivalStage;
    int chance = 18 + available * 5 + min(16, (g_generation - 1) * 2);
    if (g_player.totalEvents >= 8 + progress * 2) chance += 18;
    return Random(1, 100) <= max(28, min(78, chance));
}

Event BuildArcLegacyEvent() {
    int arc = PickArcEcho();
    if (arc < 0) arc = ARC_JADE;
    int stage = max(0, min(2, ArcEchoStageRef(arc)));
    g_pendingArcEcho = arc;
    g_pendingArcEchoStage = stage;
    g_arcEcho.lastArc = arc;

    static const vector<vector<wstring>> titles = {
        {L"【定局续章·旧玉一】旧梦证词", L"【定局续章·旧玉二】伪忆歧路", L"【定局续章·旧玉终】玉中自证"},
        {L"【定局续章·山门一】旧宗来使", L"【定局续章·山门二】两代门规", L"【定局续章·山门终】道统归属"},
        {L"【定局续章·家世一】祖契来人", L"【定局续章·家世二】养恩与血脉", L"【定局续章·家世终】旧名裁决"},
        {L"【定局续章·战帖一】照雪再逢", L"【定局续章·战帖二】共同危局", L"【定局续章·战帖终】旧约新解"}
    };
    static const vector<vector<wstring>> descriptions = {
        {
            L"轮回玉吐出一段可被现实核验的旧梦。梦里的人认得你，今生的人却说那段往事根本不存在。",
            L"两段互相矛盾的记忆同时显真。真正危险的不是忘记过去，而是把一段伪忆当成自己的意志。",
            L"旧玉终于把前世证词与今生经历并列放在面前。你必须决定谁能作证，谁只能留下痕迹。"
        },
        {
            L"前世山门派来一名今生从未见过的使者，手里却有只属于旧约的印记。",
            L"旧门规与今世山门的制度发生冲突。两边都声称是在保护你，也都想借你证明自己更正统。",
            L"两代山门同时要求一个明确归属。真正的问题不是选哪块牌匾，而是谁有权替你解释道统。"
        },
        {
            L"祖契中的人循着前世定局找到今生。他们带来资源，也带来一份必须有人承担的旧债。",
            L"血脉证据与养育之恩被摆到同一张案上。任何一方被轻易抹去，都会让另一方变成新的枷锁。",
            L"旧名、祖脉和养育者终于共同到场。你要留下的不只是姓氏，而是一套今后仍能承担后果的关系。"
        },
        {
            L"江照雪在另一世再次递帖。她记不得全部旧事，却准确写出了只有你们才懂的落款。",
            L"一场更大的危局迫使你们先并肩。旧约究竟是宿敌、盟友还是清醒对手，将在真正危险中接受检验。",
            L"危局已解，最后一帖重新落到手中。两世争胜之后，你们必须给这段关系一个不靠旁人定义的名字。"
        }
    };

    Event evt;
    evt.title = titles[arc][stage];
    evt.description = descriptions[arc][stage] + L"前世定局：“" + ArcLegacyRef(arc) +
        L"”。当前续章：" + BuildArcEchoDigest() + L"。";
    int exp = 92 + (int)g_player.realm * 9 + stage * 28;
    int risk = 22 + (int)g_player.realm * 2 + stage * 6;
    int dao = 4 + stage * 2;

    if (arc == ARC_JADE) {
        evt.choices = {
            {L"承认旧证", {L"你允许旧梦作证，却要求它接受今生事实的核验。\n修为+" + to_wstring(exp + 30) + L"，掌道+" + to_wstring(dao) + L"，因果+6", L"旧梦趁你松动时反客为主。\n气血-" + to_wstring(risk) + L"，因果-6"}, 4},
            {L"以今校旧", {L"你逐条比对两世经历，只保留能解释现实的部分。\n修为+" + to_wstring(exp) + L"，掌道+" + to_wstring(dao + 1) + L"，寿命+2", L"你把所有旧忆都当成错误，错过了一条真正的警告。\n气血-" + to_wstring(max(10, risk - 5))}, 3},
            {L"留痕断梦", {L"你不销毁过去，只切断它替今生发号施令的权力。\n修为+" + to_wstring(max(60, exp - 18)) + L"，掌道+" + to_wstring(dao + 2), L"封梦过急，识海留下裂隙。\n气血-" + to_wstring(risk + 6)}, 2}
        };
    } else if (arc == ARC_SECT) {
        evt.choices = {
            {L"续写旧律", {L"你保留旧律中真正能护人的部分，并把旧宗也纳入问责。\n修为+" + to_wstring(exp + 25) + L"，因果+7，掌道+" + to_wstring(dao), L"旧宗只想借守律之名恢复控制。\n气血-" + to_wstring(risk) + L"，因果-7"}, 4},
            {L"与今门共议", {L"你让两代山门公开核对权利与代价。\n修为+" + to_wstring(exp) + L"，灵石+16，因果+5", L"两边把协商拖成争夺，你被夹在中间。\n灵石-8，气血-" + to_wstring(max(10, risk - 6))}, 3},
            {L"另立新章", {L"你拒绝继承任何一方的完整答案，只承认自己愿意承担的道统。\n修为+" + to_wstring(max(65, exp - 12)) + L"，掌道+" + to_wstring(dao + 2), L"自立之名引来试探与围堵。\n气血-" + to_wstring(risk + 5) + L"，因果-4"}, 2}
        };
    } else if (arc == ARC_FAMILY) {
        evt.choices = {
            {L"承脉也承债", {L"你接受祖脉能给的资源，也把旧债写进自己可见的账册。\n修为+" + to_wstring(exp + 22) + L"，灵石+18，因果+8", L"祖契只谈血脉，不肯交代旧债。\n气血-" + to_wstring(risk) + L"，因果-8"}, 5},
            {L"先护养育之恩", {L"你先保证养育者不会因血脉真相再次受伤。\n修为+" + to_wstring(exp) + L"，寿命+3，因果+7", L"你保护得太急，反让幕后人摸到软处。\n气血-" + to_wstring(max(12, risk - 4))}, 5},
            {L"去祖名留证据", {L"你留下可查的证据，却拒绝用祖名兑换现成位置。\n修为+" + to_wstring(max(65, exp - 15)) + L"，掌道+" + to_wstring(dao + 2), L"断名时也切断了一条保护线。\n灵石-10，因果-4"}, 2}
        };
    } else {
        evt.choices = {
            {L"再接照雪战帖", {L"你们把两世未尽的胜负放到明面，不让家族旧账代替出剑。\n修为+" + to_wstring(exp + 30) + L"，因果+6", L"争胜心压过判断，旧伤再次重演。\n气血-" + to_wstring(risk + 4) + L"，因果-5"}, 4},
            {L"先并肩破局", {L"你们先斩断真正操纵战帖的人，再回来计算胜负。\n修为+" + to_wstring(exp) + L"，灵石+20，因果+7", L"彼此都留着后手，阵势在关键处断裂。\n气血-" + to_wstring(risk) + L"，灵石-7"}, 5},
            {L"约定只争道途", {L"你们承认竞争，也共同拒绝把仇怨传给下一世。\n修为+" + to_wstring(max(70, exp - 8)) + L"，掌道+" + to_wstring(dao + 2) + L"，寿命+2", L"这份约定说得太早，真正的旧手仍未现身。\n因果-4，气血-" + to_wstring(max(10, risk - 7))}, 3}
        };
    }
    return evt;
}

'''

    text = replace_region(text,
        "bool ShouldTriggerArcLegacyEvent() {",
        "bool ShouldTriggerLifeStoryProgressEvent() {",
        followup_block,
        "arc legacy echo system")

    text = once(text,
        "    ResolveArcOutcome(*g_currentEvent, choice, g_messageText, successLike);",
        "    ResolveArcOutcome(*g_currentEvent, choice, g_messageText, successLike);\n"
        "    ResolveArcEchoOutcome(*g_currentEvent, choice, g_messageText, successLike);",
        "arc echo resolution hook")

    text = once(text,
        "    g_player.daoHeart = max(-999, min(999, g_player.daoHeart));\n"
        "    g_player.reputation = max(-999, min(999, g_player.reputation));",
        "    if (g_arcEcho.jadeResolution == L\"守证旧我\") { g_player.exp += 15; notes.push_back(L\"两世证词可互相核验\"); }\n"
        "    else if (g_arcEcho.jadeResolution == L\"今身定锚\") { g_player.daoHeart += 2; notes.push_back(L\"今生判断成为旧忆锚点\"); }\n"
        "    else if (g_arcEcho.jadeResolution == L\"断梦留痕\") { g_player.daoHeart += 3; notes.push_back(L\"旧梦只能留痕，不能夺舍判断\"); }\n"
        "    if (g_arcEcho.sectResolution == L\"旧律新章\") g_player.reputation += 2;\n"
        "    else if (g_arcEcho.sectResolution == L\"两代同门\") { g_player.reputation += 1; g_player.daoHeart += 1; }\n"
        "    else if (g_arcEcho.sectResolution == L\"今世开宗\") g_player.daoHeart += 2;\n"
        "    if (g_arcEcho.familyResolution == L\"祖脉共担\") g_player.family.wealth += 1;\n"
        "    else if (g_arcEcho.familyResolution == L\"养恩为先\") g_player.reputation += 2;\n"
        "    else if (g_arcEcho.familyResolution == L\"去名留义\") g_player.daoHeart += 2;\n"
        "    if (g_arcEcho.rivalResolution == L\"再续宿敌\") g_player.attackPower += 1;\n"
        "    else if (g_arcEcho.rivalResolution == L\"并肩照雪\") g_player.defense += 1;\n"
        "    else if (g_arcEcho.rivalResolution == L\"相争不相害\") g_player.daoHeart += 1;\n"
        "    g_player.daoHeart = max(-999, min(999, g_player.daoHeart));\n"
        "    g_player.reputation = max(-999, min(999, g_player.reputation));",
        "arc echo birth effects")

    text = once(text, '    file << L"STORY_STATE_V3\\n";', '    file << L"STORY_STATE_V4\\n";', "story v4 save marker")
    text = once(text,
        "    file << EscapeSaveField(g_arcLegacy.jade) << L\"\\n\";\n"
        "    file << EscapeSaveField(g_arcLegacy.sect) << L\"\\n\";\n"
        "    file << EscapeSaveField(g_arcLegacy.family) << L\"\\n\";\n"
        "    file << EscapeSaveField(g_arcLegacy.rival) << L\"\\n\";\n}",
        "    file << EscapeSaveField(g_arcLegacy.jade) << L\"\\n\";\n"
        "    file << EscapeSaveField(g_arcLegacy.sect) << L\"\\n\";\n"
        "    file << EscapeSaveField(g_arcLegacy.family) << L\"\\n\";\n"
        "    file << EscapeSaveField(g_arcLegacy.rival) << L\"\\n\";\n"
        "    file << g_arcEcho.jadeStage << L\" \" << g_arcEcho.sectStage << L\" \"\n"
        "         << g_arcEcho.familyStage << L\" \" << g_arcEcho.rivalStage << L\" \"\n"
        "         << g_arcEcho.lastArc << L\"\\n\";\n"
        "    file << EscapeSaveField(g_arcEcho.jadeResolution) << L\"\\n\";\n"
        "    file << EscapeSaveField(g_arcEcho.sectResolution) << L\"\\n\";\n"
        "    file << EscapeSaveField(g_arcEcho.familyResolution) << L\"\\n\";\n"
        "    file << EscapeSaveField(g_arcEcho.rivalResolution) << L\"\\n\";\n}",
        "story v4 echo save")

    text = once(text,
        "    bool isStoryV3 = (marker == L\"STORY_STATE_V3\");\n"
        "    bool isStoryV2 = (marker == L\"STORY_STATE_V2\");\n"
        "    bool isStoryV1 = (marker == L\"STORY_STATE_V1\");\n"
        "    if (!isStoryV1 && !isStoryV2 && !isStoryV3) return false;",
        "    bool isStoryV4 = (marker == L\"STORY_STATE_V4\");\n"
        "    bool isStoryV3 = (marker == L\"STORY_STATE_V3\");\n"
        "    bool isStoryV2 = (marker == L\"STORY_STATE_V2\");\n"
        "    bool isStoryV1 = (marker == L\"STORY_STATE_V1\");\n"
        "    if (!isStoryV1 && !isStoryV2 && !isStoryV3 && !isStoryV4) return false;",
        "story v4 load marker")
    text = once(text, "    if (isStoryV2 || isStoryV3) {", "    if (isStoryV2 || isStoryV3 || isStoryV4) {", "story v4 load branch")

    old_legacy_load = '''        if (isStoryV3) {
            getline(file, g_arcLegacy.jade); getline(file, g_arcLegacy.sect);
            getline(file, g_arcLegacy.family); getline(file, g_arcLegacy.rival);
            g_arcLegacy.jade = UnescapeSaveField(g_arcLegacy.jade);
            g_arcLegacy.sect = UnescapeSaveField(g_arcLegacy.sect);
            g_arcLegacy.family = UnescapeSaveField(g_arcLegacy.family);
            g_arcLegacy.rival = UnescapeSaveField(g_arcLegacy.rival);
        } else g_arcLegacy = ArcLegacyState();'''
    new_legacy_load = '''        if (isStoryV3 || isStoryV4) {
            getline(file, g_arcLegacy.jade); getline(file, g_arcLegacy.sect);
            getline(file, g_arcLegacy.family); getline(file, g_arcLegacy.rival);
            g_arcLegacy.jade = UnescapeSaveField(g_arcLegacy.jade);
            g_arcLegacy.sect = UnescapeSaveField(g_arcLegacy.sect);
            g_arcLegacy.family = UnescapeSaveField(g_arcLegacy.family);
            g_arcLegacy.rival = UnescapeSaveField(g_arcLegacy.rival);
            if (isStoryV4) {
                file >> g_arcEcho.jadeStage >> g_arcEcho.sectStage
                     >> g_arcEcho.familyStage >> g_arcEcho.rivalStage >> g_arcEcho.lastArc;
                file.ignore(numeric_limits<streamsize>::max(), L'\n');
                getline(file, g_arcEcho.jadeResolution); getline(file, g_arcEcho.sectResolution);
                getline(file, g_arcEcho.familyResolution); getline(file, g_arcEcho.rivalResolution);
                g_arcEcho.jadeResolution = UnescapeSaveField(g_arcEcho.jadeResolution);
                g_arcEcho.sectResolution = UnescapeSaveField(g_arcEcho.sectResolution);
                g_arcEcho.familyResolution = UnescapeSaveField(g_arcEcho.familyResolution);
                g_arcEcho.rivalResolution = UnescapeSaveField(g_arcEcho.rivalResolution);
                g_arcEcho.jadeStage = max(0, min(3, g_arcEcho.jadeStage));
                g_arcEcho.sectStage = max(0, min(3, g_arcEcho.sectStage));
                g_arcEcho.familyStage = max(0, min(3, g_arcEcho.familyStage));
                g_arcEcho.rivalStage = max(0, min(3, g_arcEcho.rivalStage));
                g_arcEcho.lastArc = max(-1, min(3, g_arcEcho.lastArc));
            } else g_arcEcho = ArcEchoState();
        } else { g_arcLegacy = ArcLegacyState(); g_arcEcho = ArcEchoState(); }'''
    text = once(text, old_legacy_load, new_legacy_load, "story v4 legacy and echo load")
    text = once(text,
        "    } else {\n        g_arcLegacy = ArcLegacyState();\n        InitializeNarrativeArcsFromLegacyProgress();",
        "    } else {\n        g_arcLegacy = ArcLegacyState();\n        g_arcEcho = ArcEchoState();\n        InitializeNarrativeArcsFromLegacyProgress();",
        "old story echo reset")

    text = once(text,
        '    world << L"- 跨世定局: " << BuildArcLegacyDigest() << L"\\n";',
        '    world << L"- 跨世定局: " << BuildArcLegacyDigest() << L"\\n";\n'
        '    world << L"- 定局续章: " << BuildArcEchoDigest() << L"\\n";',
        "AI arc echo digest")
    text = once(text,
        '    ss << L"跨世定局: " << BuildArcLegacyDigest() << L"\\n\\n";',
        '    ss << L"跨世定局: " << BuildArcLegacyDigest() << L"\\n";\n'
        '    ss << L"定局续章: " << BuildArcEchoDigest() << L"\\n\\n";',
        "main arc echo digest")
    text = once(text,
        '    WriteJsonField(ss, L"arcLegacies", BuildArcLegacyDigest());',
        '    WriteJsonField(ss, L"arcLegacies", BuildArcLegacyDigest());\n'
        '    WriteJsonField(ss, L"arcEchoes", BuildArcEchoDigest());',
        "Agent arc echo digest")
    text = once(text,
        '    if (HasArcLegacy()) ss << L"\\n跨世定局: " << BuildArcLegacyDigest() << L"\\n";',
        '    if (HasArcLegacy()) ss << L"\\n跨世定局: " << BuildArcLegacyDigest() << L"\\n";\n'
        '    if (g_arcEcho.jadeStage + g_arcEcho.sectStage + g_arcEcho.familyStage + g_arcEcho.rivalStage > 0)\n'
        '        ss << L"定局续章: " << BuildArcEchoDigest() << L"\\n";',
        "opening arc echo digest")
    text = once(text,
        "    g_lastArcEchoEvent = -1000;\n    g_lastArcEchoKind = -1;\n    g_pendingArc = g_pendingArcStage = -1;",
        "    g_lastArcEchoEvent = -1000;\n    g_lastArcEchoKind = -1;\n"
        "    g_pendingArc = g_pendingArcStage = -1;\n"
        "    g_pendingArcEcho = g_pendingArcEchoStage = -1;\n"
        "    g_arcEcho.lastArc = -1;",
        "arc echo life reset")

    SRC.write_text(text, encoding="utf-8")
    print("Applied v0.11: four three-stage second-life legacy chapters and STORY_STATE_V4.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
