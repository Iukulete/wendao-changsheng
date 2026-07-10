# -*- coding: utf-8 -*-
"""Add persistent multi-arc story progression after the v0.6 build patch."""
from __future__ import annotations
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
MARKER = "V0_7_NARRATIVE_ARCS"

def replace_once(text: str, old: str, new: str, label: str) -> str:
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
    content = SRC.read_text(encoding="utf-8")
    if MARKER in content:
        print("v0.7 narrative arcs already applied.")
        return 0

    arc_struct = r'''
enum NarrativeArcKind {
    ARC_JADE = 0,
    ARC_SECT = 1,
    ARC_FAMILY = 2,
    ARC_RIVAL = 3
};

struct NarrativeArcState { // V0_7_NARRATIVE_ARCS
    int jadeStage;
    int sectStage;
    int familyStage;
    int rivalStage;
    int lastArc;

    NarrativeArcState()
        : jadeStage(0), sectStage(0), familyStage(0), rivalStage(0), lastArc(-1) {}
};

'''
    content = replace_once(content, "enum EventTheme {", arc_struct + "enum EventTheme {", "arc state types")
    content = replace_once(
        content,
        "StoryState g_storyState;\nvector<HongmengTreasureProgress> g_hongmengProgress;",
        "StoryState g_storyState;\nNarrativeArcState g_narrativeArcs;\nvector<HongmengTreasureProgress> g_hongmengProgress;",
        "arc global",
    )
    content = replace_once(
        content,
        "wstring BuildStoryStateContext();",
        "wstring BuildStoryStateContext();\nwstring BuildNarrativeArcDigest();",
        "arc declaration",
    )

    arc_helpers = r'''
int& GetNarrativeArcStageRef(int arc) {
    if (arc == ARC_SECT) return g_narrativeArcs.sectStage;
    if (arc == ARC_FAMILY) return g_narrativeArcs.familyStage;
    if (arc == ARC_RIVAL) return g_narrativeArcs.rivalStage;
    return g_narrativeArcs.jadeStage;
}

int GetNarrativeArcTotalProgress() {
    return g_narrativeArcs.jadeStage + g_narrativeArcs.sectStage +
           g_narrativeArcs.familyStage + g_narrativeArcs.rivalStage;
}

wstring GetNarrativeArcStageLabel(int stage) {
    static const vector<wstring> labels = {
        L"未起", L"初显", L"入局", L"转折", L"收束"
    };
    return labels[max(0, min(4, stage))];
}

wstring BuildNarrativeArcDigest() {
    wstringstream ss;
    ss << L"旧玉" << g_narrativeArcs.jadeStage << L"/4·"
       << GetNarrativeArcStageLabel(g_narrativeArcs.jadeStage)
       << L"｜山门" << g_narrativeArcs.sectStage << L"/4·"
       << GetNarrativeArcStageLabel(g_narrativeArcs.sectStage)
       << L"｜家世" << g_narrativeArcs.familyStage << L"/4·"
       << GetNarrativeArcStageLabel(g_narrativeArcs.familyStage)
       << L"｜战帖" << g_narrativeArcs.rivalStage << L"/4·"
       << GetNarrativeArcStageLabel(g_narrativeArcs.rivalStage);
    return ss.str();
}

void InitializeNarrativeArcsFromLegacyProgress() {
    int legacyProgress = max(0, min(16, g_lifeStoryProgressThisLife));
    g_narrativeArcs = NarrativeArcState();
    for (int i = 0; i < legacyProgress; ++i) {
        int arc = i % 4;
        int& stage = GetNarrativeArcStageRef(arc);
        stage = min(4, stage + 1);
        g_narrativeArcs.lastArc = arc;
    }
    g_lifeStoryProgressThisLife = GetNarrativeArcTotalProgress();
}

bool IsNarrativeArcAvailable(int arc) {
    if (GetNarrativeArcStageRef(arc) >= 4) return false;
    if (arc == ARC_JADE) return true;
    if (arc == ARC_SECT) {
        return IsClassicalEraName(g_worldEraName) ||
               !g_factionTie.name.empty() || !g_socialThreads.empty();
    }
    if (arc == ARC_FAMILY) return true;
    if (arc == ARC_RIVAL) {
        return g_player.totalEvents >= 3 || g_player.realm >= FOUNDATION;
    }
    return false;
}

int PickNarrativeArc() {
    vector<int> weighted;
    int minimumStage = 4;
    for (int arc = ARC_JADE; arc <= ARC_RIVAL; ++arc) {
        if (IsNarrativeArcAvailable(arc)) {
            minimumStage = min(minimumStage, GetNarrativeArcStageRef(arc));
        }
    }
    for (int arc = ARC_JADE; arc <= ARC_RIVAL; ++arc) {
        if (!IsNarrativeArcAvailable(arc)) continue;
        int stage = GetNarrativeArcStageRef(arc);
        int weight = 2 + (4 - stage) * 2;
        if (stage == minimumStage) weight += 4;
        if (arc == g_narrativeArcs.lastArc) weight = max(1, weight / 3);
        for (int i = 0; i < weight; ++i) weighted.push_back(arc);
    }
    if (weighted.empty()) return -1;
    return weighted[Random(0, (int)weighted.size() - 1)];
}

void AdvanceNarrativeArc(int arc) {
    if (arc < ARC_JADE || arc > ARC_RIVAL) return;
    int& stage = GetNarrativeArcStageRef(arc);
    stage = min(4, stage + 1);
    g_narrativeArcs.lastArc = arc;
    g_lifeStoryProgressThisLife = GetNarrativeArcTotalProgress();
}

'''
    content = replace_once(content, "enum GameState {", arc_helpers + "enum GameState {", "arc helpers")

    story_block = r'''bool ShouldTriggerLifeStoryProgressEvent() {
    if (GetNarrativeArcTotalProgress() >= 16) return false;
    if (g_player.totalEvents - g_lastLifeStoryProgressEventCount < 2) return false;

    int incomplete = 0;
    for (int arc = ARC_JADE; arc <= ARC_RIVAL; ++arc) {
        if (IsNarrativeArcAvailable(arc)) incomplete++;
    }
    if (incomplete <= 0) return false;

    static const int requiredEvents[] = {
        1, 3, 5, 7, 9, 12, 15, 18,
        22, 26, 30, 35, 40, 46, 52, 58
    };
    int progress = max(0, min(15, GetNarrativeArcTotalProgress()));
    if (g_player.totalEvents < requiredEvents[progress]) return false;

    int chance = 22 + incomplete * 4;
    if (progress < 4) chance += 12;
    if (g_player.totalEvents >= requiredEvents[progress] + 4) chance += 18;
    if (!g_lifeStoryHooks.empty()) chance += 4;
    return Random(1, 100) <= max(24, min(72, chance));
}

Event BuildLifeStoryProgressEvent() {
    Event evt;
    int arc = PickNarrativeArc();
    if (arc < 0) arc = ARC_JADE;
    int stage = max(0, min(3, GetNarrativeArcStageRef(arc)));

    static const vector<vector<wstring>> titles = {
        {L"【旧玉·一】夜半微温", L"【旧玉·二】镜中旧名", L"【旧玉·三】生死回响", L"【旧玉·终】不借旧我"},
        {L"【山门·一】测灵余波", L"【山门·二】外院名额", L"【山门·三】掌律问心", L"【山门·终】自择道统"},
        {L"【家世·一】旧仆来信", L"【家世·二】封名玉简", L"【家世·三】旧宅暗门", L"【家世·终】认或不认"},
        {L"【战帖·一】照雪初帖", L"【战帖·二】同阵争先", L"【战帖·三】江氏旧账", L"【战帖·终】敌友由我"}
    };
    static const vector<vector<wstring>> descriptions = {
        {
            L"夜半醒来，黑白伴生玉佩第一次在无人触碰时自行发温。窗纸上映出两道互不相容的影子：一道像今生，一道像尚未发生的死局。",
            L"旧玉把你的脸映成一个陌生旧名。那名字没有记忆，只有近乎本能的警惕，像有人曾用它欠下无法结清的因果。",
            L"一次险境之后，旧玉没有替你挡灾，只把生死之间那一瞬完整留住。它保存的不是答案，而是每次取舍留下的轮廓。",
            L"旧玉终于托起足够多的回响，像要让过去替你决定今生。真正的终局，是决定哪些旧意可以留下，哪些必须止于此世。"
        },
        {
            L"测灵台上的结果已经传遍山门。有人把你当成值得下注的苗子，也有人认为你的家世、旧玉与灵根都该先被审查。",
            L"外院名额忽然少了一席，执事说是资源不足，几名同辈却知道有人在用名额试你的软硬。",
            L"掌律玉简把早年的每次选择串成一份问心案卷。玄衡一脉要证明你只是靠师承庇护才走到今天。",
            L"山门愿意给你更高的位置，代价是让某一脉替你定义道途。走到这一步，你必须决定自己属于谁，又不属于谁。"
        },
        {
            L"一封没有署名的旧信送到手中，字迹像家中长辈，又像多年不曾露面的旧仆。信里只写：不要让旁人先替你认祖。",
            L"家中封存的玉简被人送来，里面记着一个被抹去的名字，也记着父母或养育者曾替你挡下的第一场灾。",
            L"旧宅地基下露出一扇暗门。门后不是宝库，而是家族曾经选错边、欠下债、又拼命藏住你的证据。",
            L"身世真相终于足以改变名望、资源和仇家。可血脉只能解释你从哪里来，不能替你决定要成为谁。"
        },
        {
            L"江照雪递来第一封正式战帖。她没有暗算，也没有客套，只写明地点、时辰和一句：别让长辈替你接剑。",
            L"秘境阵门将你与江照雪锁进同一支队伍。谁都想先拿机缘，可真正危险逼近时，胜负与活命必须重新排序。",
            L"江氏旧账被人翻出，战帖背后多了一层家族压力。她可以借此踩下你，也可能先斩断自家递来的暗箭。",
            L"数次争胜之后，你们都知道对方不是可以轻易抹去的人。最后一帖不只问谁赢，而是问往后做敌、做友，还是做彼此最清醒的对手。"
        }
    };

    evt.title = titles[arc][stage];
    evt.description = descriptions[arc][stage] + L"当前分线：" + BuildNarrativeArcDigest() + L"。";

    int baseExp = 78 + g_player.realm * 8 + stage * 24;
    int majorExp = baseExp + 38;
    int hpRisk = 20 + g_player.realm * 2 + stage * 5;
    int daoGain = max(2, min(12, 3 + stage * 2 + g_player.realm / 4));

    if (arc == ARC_JADE) {
        evt.choices = {
            {L"握玉静听", {
                L"你没有急着认领旧名，只把梦兆里可验证的细节记下。旧玉回声更清晰，却仍不能替你做决定。\n修为+" + to_wstring(majorExp) + L"，灵宝共鸣+" + to_wstring(3 + stage) + L"，掌道+" + to_wstring(daoGain),
                L"旧梦层层压来，你一时把不属于今生的恐惧当成事实。\n气血-" + to_wstring(hpRisk) + L"，因果-5"
            }, 6},
            {L"以今证旧", {
                L"你拿今生见闻逐条核对梦兆，只留下能被现实印证的部分。\n修为+" + to_wstring(baseExp) + L"，寿命+3，因果+7",
                L"你试图一次查清所有旧因，反被真假线索拖进同一团雾里。\n气血-" + to_wstring(max(12, hpRisk - 5)) + L"，因果-6"
            }, 5},
            {L"封住梦兆", {
                L"你暂时封住最危险的回响。能被你压住的过去，才有资格成为今生的工具。\n修为+" + to_wstring(max(50, baseExp - 18)) + L"，掌道+" + to_wstring(max(2, daoGain - 1)),
                L"梦兆被强压回去，却从别处渗出，连日行功都带着陌生节奏。\n气血-" + to_wstring(max(10, hpRisk - 8))
            }, 3}
        };
    } else if (arc == ARC_SECT) {
        evt.choices = {
            {L"据理受验", {
                L"你逐条回应质疑，不借天资压人，也不让门规替旁人定罪。\n修为+" + to_wstring(majorExp) + L"，因果+8，掌道+" + to_wstring(max(2, daoGain - 1)),
                L"你被绕进条文夹层，一句急辩反成新的审查理由。\n气血-" + to_wstring(hpRisk) + L"，因果-8"
            }, 5},
            {L"借师承入局", {
                L"你承认师承给过机会，却没有把全部责任推给长辈。师承成了立足之处，而不是遮罪的盾。\n修为+" + to_wstring(baseExp) + L"，灵石+16，因果+6",
                L"借来的名义太重，旁人开始把每次失误都记到师承头上。\n灵石-8，因果-6"
            }, 4},
            {L"拒绝被定价", {
                L"你要求把规则与代价写明。有人觉得你不识抬举，也有人第一次把你当成能自己立道的人。\n修为+" + to_wstring(max(55, baseExp - 15)) + L"，寿命+2，掌道+" + to_wstring(daoGain),
                L"你拒绝得太硬，资源与人情同时收紧。\n气血-" + to_wstring(max(10, hpRisk - 8)) + L"，灵石-6"
            }, 3}
        };
    } else if (arc == ARC_FAMILY) {
        evt.description += L"此世已知家世：" + (g_player.family.secret.empty() ? GetFamilySummary(g_player.family) : g_player.family.secret) + L"。";
        evt.choices = {
            {L"追查旧账", {
                L"你把信、玉简与旧宅线索逐一对上，查清一部分真相，也把一部分债正式记到自己名下。\n修为+" + to_wstring(majorExp) + L"，灵石+12，因果+10",
                L"旧账背后的人先一步察觉你在追查，家中留下的保护反成指路标。\n气血-" + to_wstring(hpRisk) + L"，因果-9"
            }, 6},
            {L"问养育者", {
                L"你没有越过真正养大你的人。对方终于说出一段此前不敢说的旧事。\n修为+" + to_wstring(baseExp) + L"，寿命+4，因果+7",
                L"你逼问得太急，对方只把旧事藏得更深。\n气血-" + to_wstring(max(10, hpRisk - 7)) + L"，因果-5"
            }, 5},
            {L"不让血脉定命", {
                L"你保留真相，却拒绝拿祖名换取现成位置。家世从枷锁变成证据。\n修为+" + to_wstring(max(55, baseExp - 12)) + L"，掌道+" + to_wstring(daoGain),
                L"你切断得太急，也失去了一条能保护家人的线索。\n灵石-8，因果-4"
            }, 3}
        };
    } else {
        evt.choices = {
            {L"正面接帖", {
                L"你不借旁人造势，也不把旧怨藏进暗手。江照雪收剑时仍不服，却承认这一战值得记住。\n修为+" + to_wstring(majorExp) + L"，因果+8",
                L"你只想压过她，反被争胜心带乱节奏。\n气血-" + to_wstring(hpRisk) + L"，因果-6"
            }, 5},
            {L"同阵合作", {
                L"你们先拆开真正的危局，再回头算谁多走半步。合作没有抹掉竞争，却让彼此都欠下一次正面交代。\n修为+" + to_wstring(baseExp) + L"，灵石+18，因果+7",
                L"你们都留着一手，阵势在最要紧时断开。\n气血-" + to_wstring(max(12, hpRisk - 3)) + L"，灵石-6"
            }, 5},
            {L"不以胜负定敌友", {
                L"你承认争胜，也拒绝让旁人的旧账替你们决定关系。\n修为+" + to_wstring(max(60, baseExp - 10)) + L"，掌道+" + to_wstring(daoGain) + L"，寿命+2",
                L"你的话说得太轻，像在回避一场必须正面承担的冲突。\n因果-5，气血-" + to_wstring(max(8, hpRisk - 10))
            }, 4}
        };
    }

    AdvanceNarrativeArc(arc);
    return evt;
}

'''
    content = replace_region(
        content,
        "bool ShouldTriggerLifeStoryProgressEvent() {",
        "bool HasAnchorCharacterThread",
        story_block,
        "story trigger and builder",
    )

    content = replace_once(
        content,
        "                        g_lastLifeStoryProgressEventCount = g_player.totalEvents;\n"
        "                        g_lifeStoryProgressThisLife++;\n"
        "                        AddMemory(L\"本世主线推进\",\n"
        "                            L\"外出历练时，本世主线进入第\" +\n"
        "                            to_wstring(g_lifeStoryProgressThisLife) + L\"段。\");",
        "                        g_lastLifeStoryProgressEventCount = g_player.totalEvents;\n"
        "                        AddMemory(L\"本世分线推进\",\n"
        "                            L\"外出历练时，一条本世分线继续推进。当前：\" +\n"
        "                            BuildNarrativeArcDigest());",
        "story bookkeeping",
    )

    reset_anchor = "    g_lifeStoryProgressThisLife = 0;"
    if reset_anchor not in content:
        raise RuntimeError("Unable to patch arc reset: anchor not found")
    content = content.replace(
        reset_anchor,
        reset_anchor + "\n    g_narrativeArcs = NarrativeArcState();",
    )

    content = replace_once(
        content,
        '    file << L"STORY_STATE_V1\\n";',
        '    file << L"STORY_STATE_V2\\n";',
        "story save version",
    )
    content = replace_once(
        content,
        "    file << g_storyState.npcMoods.size() << L\"\\n\";\n"
        "    for (const auto& item : g_storyState.npcMoods) {\n"
        "        file << EscapeSaveField(item) << L\"\\n\";\n"
        "    }\n"
        "}",
        "    file << g_storyState.npcMoods.size() << L\"\\n\";\n"
        "    for (const auto& item : g_storyState.npcMoods) {\n"
        "        file << EscapeSaveField(item) << L\"\\n\";\n"
        "    }\n"
        "    file << g_narrativeArcs.jadeStage << L\" \"\n"
        "         << g_narrativeArcs.sectStage << L\" \"\n"
        "         << g_narrativeArcs.familyStage << L\" \"\n"
        "         << g_narrativeArcs.rivalStage << L\" \"\n"
        "         << g_narrativeArcs.lastArc << L\"\\n\";\n"
        "}",
        "story arc save",
    )
    content = replace_once(
        content,
        '    if (marker != L"STORY_STATE_V1") return false;',
        '    bool isStoryV2 = (marker == L"STORY_STATE_V2");\n'
        '    bool isStoryV1 = (marker == L"STORY_STATE_V1");\n'
        '    if (!isStoryV1 && !isStoryV2) return false;',
        "story load version",
    )
    content = replace_once(
        content,
        "    for (size_t i = 0; i < count; ++i) {\n"
        "        wstring item;\n"
        "        getline(file, item);\n"
        "        g_storyState.npcMoods.push_back(UnescapeSaveField(item));\n"
        "    }\n"
        "    RefreshStoryStateStableFields();",
        "    for (size_t i = 0; i < count; ++i) {\n"
        "        wstring item;\n"
        "        getline(file, item);\n"
        "        g_storyState.npcMoods.push_back(UnescapeSaveField(item));\n"
        "    }\n"
        "    if (isStoryV2) {\n"
        "        file >> g_narrativeArcs.jadeStage >> g_narrativeArcs.sectStage\n"
        "             >> g_narrativeArcs.familyStage >> g_narrativeArcs.rivalStage\n"
        "             >> g_narrativeArcs.lastArc;\n"
        "        file.ignore(numeric_limits<streamsize>::max(), L'\\n');\n"
        "        g_narrativeArcs.jadeStage = max(0, min(4, g_narrativeArcs.jadeStage));\n"
        "        g_narrativeArcs.sectStage = max(0, min(4, g_narrativeArcs.sectStage));\n"
        "        g_narrativeArcs.familyStage = max(0, min(4, g_narrativeArcs.familyStage));\n"
        "        g_narrativeArcs.rivalStage = max(0, min(4, g_narrativeArcs.rivalStage));\n"
        "        g_narrativeArcs.lastArc = max(-1, min(3, g_narrativeArcs.lastArc));\n"
        "        g_lifeStoryProgressThisLife = GetNarrativeArcTotalProgress();\n"
        "    } else {\n"
        "        InitializeNarrativeArcsFromLegacyProgress();\n"
        "    }\n"
        "    RefreshStoryStateStableFields();",
        "story arc load",
    )

    content = replace_once(
        content,
        '    world << L"- 本世主线: " << g_lifePremise << L"\\n";',
        '    world << L"- 本世主线: " << g_lifePremise << L"\\n";\n'
        '    world << L"- 分线进度: " << BuildNarrativeArcDigest() << L"\\n";',
        "AI arc context",
    )
    content = replace_once(
        content,
        '    ss << BuildImmediateGoalDigest() << L"\\n\\n";',
        '    ss << BuildImmediateGoalDigest() << L"\\n";\n'
        '    ss << L"主线分线: " << BuildNarrativeArcDigest() << L"\\n\\n";',
        "main arc digest",
    )
    content = replace_once(
        content,
        '    ss << L"\\\"effectiveKarma\\\":" << GetEffectiveKarmaScore(g_player.karma) << L"\\n";',
        '    WriteJsonField(ss, L"storyArcs", BuildNarrativeArcDigest());\n'
        '    ss << L"\\\"effectiveKarma\\\":" << GetEffectiveKarmaScore(g_player.karma) << L"\\n";',
        "Agent arc JSON",
    )

    SRC.write_text(content, encoding="utf-8")
    print("Applied v0.7 narrative arcs: four persistent four-stage chains and STORY_STATE_V2.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
