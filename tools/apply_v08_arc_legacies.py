# -*- coding: utf-8 -*-
"""Install persistent terminal outcomes for the v0.7 narrative arcs."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
MARKER = "V0_8_ARC_LEGACIES"


def once(text, old, new, label):
    if old not in text:
        raise RuntimeError(f"Unable to patch {label}: anchor not found")
    return text.replace(old, new, 1)


def main():
    text = SRC.read_text(encoding="utf-8")
    if MARKER in text:
        print("v0.8 arc legacies already applied.")
        return 0
    if "V0_7_NARRATIVE_ARCS" not in text:
        raise RuntimeError("v0.7 narrative arcs must run first")

    text = once(text, "enum EventTheme {", r'''
struct ArcLegacyState { // V0_8_ARC_LEGACIES
    wstring jade;
    wstring sect;
    wstring family;
    wstring rival;
};

enum EventTheme {''', "legacy type")

    text = once(text,
        "NarrativeArcState g_narrativeArcs;\nvector<HongmengTreasureProgress> g_hongmengProgress;",
        "NarrativeArcState g_narrativeArcs;\nArcLegacyState g_arcLegacy;\n"
        "int g_pendingArc = -1;\nint g_pendingArcStage = -1;\n"
        "int g_lastArcEchoEvent = -1000;\nint g_lastArcEchoKind = -1;\n"
        "vector<HongmengTreasureProgress> g_hongmengProgress;", "legacy globals")

    helpers = r'''
wstring& ArcLegacyRef(int arc) {
    if (arc == ARC_SECT) return g_arcLegacy.sect;
    if (arc == ARC_FAMILY) return g_arcLegacy.family;
    if (arc == ARC_RIVAL) return g_arcLegacy.rival;
    return g_arcLegacy.jade;
}

bool HasArcLegacy() {
    return !g_arcLegacy.jade.empty() || !g_arcLegacy.sect.empty() ||
           !g_arcLegacy.family.empty() || !g_arcLegacy.rival.empty();
}

wstring BuildArcLegacyDigest() {
    vector<wstring> out;
    auto add = [&](const wstring& n, const wstring& v) { if (!v.empty()) out.push_back(n + L"·" + v); };
    add(L"旧玉", g_arcLegacy.jade); add(L"山门", g_arcLegacy.sect);
    add(L"家世", g_arcLegacy.family); add(L"战帖", g_arcLegacy.rival);
    if (out.empty()) return L"暂无跨世定局";
    wstringstream ss;
    for (size_t i = 0; i < out.size(); ++i) { if (i) ss << L"｜"; ss << out[i]; }
    return ss.str();
}

wstring ArcLegacyTag(int arc, const wstring& choice) {
    if (arc == ARC_JADE) return choice == L"握玉静听" ? L"旧我为证" : (choice == L"以今证旧" ? L"今生校旧" : L"封梦自持");
    if (arc == ARC_SECT) return choice == L"据理受验" ? L"守律立道" : (choice == L"借师承入局" ? L"师承共担" : L"自立道统");
    if (arc == ARC_FAMILY) return choice == L"追查旧账" ? L"承认旧脉" : (choice == L"问养育者" ? L"护亲问源" : L"断名自立");
    return choice == L"正面接帖" ? L"照雪宿敌" : (choice == L"同阵合作" ? L"照雪盟友" : L"清醒对手");
}

void ResolveArcOutcome(const Event& event, const Choice& choice, wstring& outcome, bool success) {
    if (g_pendingArc < ARC_JADE || g_pendingArc > ARC_RIVAL || g_pendingArcStage < 0) return;
    if (!TextContainsAny(event.title, {L"【旧玉·", L"【山门·", L"【家世·", L"【战帖·"})) return;
    int arc = g_pendingArc, stage = g_pendingArcStage;
    g_pendingArc = g_pendingArcStage = -1;
    if (stage < 3) { AdvanceNarrativeArc(arc); return; }
    if (!success) {
        outcome += L"\n\n【终局未定】这次取舍没有站稳，分线仍停在终局门前，后续还会再次落笔。";
        AppendTraceLog(L"ARC_LEGACY_RETRY", event.title + L"终局失败，保留3/4进度。");
        return;
    }
    wstring tag = ArcLegacyTag(arc, choice.description);
    ArcLegacyRef(arc) = tag;
    AdvanceNarrativeArc(arc);
    if (arc == ARC_JADE) g_player.daoHeart += 5;
    else if (arc == ARC_SECT) g_player.reputation += 5;
    else if (arc == ARC_FAMILY) { g_player.reputation += 3; g_player.daoHeart += 2; }
    else if (tag == L"照雪宿敌") g_player.enmity += 4;
    else if (tag == L"照雪盟友") g_player.reputation += 4;
    else g_player.daoHeart += 3;
    outcome += L"\n\n【跨世定局】此世终局被写入轮回。永久标签：" + tag;
    AddMemory(L"跨世定局", event.title + L"以“" + tag + L"”收束。此后轮回会记住这次取舍。");
    AppendTraceLog(L"ARC_LEGACY_SET", event.title + L" -> " + choice.description + L" -> " + tag + L"\n" + BuildArcLegacyDigest());
}

wstring ApplyArcLegacyBirth() {
    if (!HasArcLegacy()) return L"";
    vector<wstring> notes;
    auto secret = [&](const wstring& s) {
        if (g_player.family.secret.find(s) != wstring::npos) return;
        if (!g_player.family.secret.empty()) g_player.family.secret += L"；";
        g_player.family.secret += s;
    };
    if (g_arcLegacy.jade == L"旧我为证") { g_player.daoHeart += 3; g_player.exp += 18; notes.push_back(L"旧梦更容易被验证"); }
    else if (g_arcLegacy.jade == L"今生校旧") { g_player.daoHeart += 5; notes.push_back(L"今生判断能校准旧忆"); }
    else if (g_arcLegacy.jade == L"封梦自持") { g_player.daoHeart += 7; notes.push_back(L"危险旧梦被心印隔开"); }
    if (g_arcLegacy.sect == L"守律立道") { g_player.reputation += 5; secret(L"旧宗名册仍记得前世守律之名"); }
    else if (g_arcLegacy.sect == L"师承共担") { g_player.reputation += 3; g_player.daoHeart += 2; secret(L"跨世师承旧约仍有回音"); }
    else if (g_arcLegacy.sect == L"自立道统") { g_player.daoHeart += 4; g_player.enmity += 2; secret(L"前世自立道统之名尚未散尽"); }
    if (g_arcLegacy.family == L"承认旧脉") { g_player.family.fame += 10; g_player.family.wealth += 3; secret(L"祖脉旧契连同旧债一并承认你"); }
    else if (g_arcLegacy.family == L"护亲问源") { g_player.reputation += 3; g_player.family.wealth += 2; secret(L"轮回优先记住养育之恩"); }
    else if (g_arcLegacy.family == L"断名自立") { g_player.daoHeart += 3; secret(L"祖名可查却不能替你定命"); }
    if (g_arcLegacy.rival == L"照雪宿敌") { g_player.attackPower += 3; g_player.enmity += 4; }
    else if (g_arcLegacy.rival == L"照雪盟友") { g_player.defense += 2; g_player.reputation += 4; }
    else if (g_arcLegacy.rival == L"清醒对手") { g_player.attackPower += 1; g_player.defense += 1; g_player.daoHeart += 3; }
    g_player.daoHeart = max(-999, min(999, g_player.daoHeart));
    g_player.reputation = max(-999, min(999, g_player.reputation));
    g_player.enmity = max(0, min(999, g_player.enmity));
    g_player.family.fame = max(-100, min(100, g_player.family.fame));
    g_player.family.wealth = max(0, min(60, g_player.family.wealth));
    return L"跨世定局回到今生：" + BuildArcLegacyDigest() + L"。";
}

void ApplyArcLegacyWorld() {
    if (!HasArcLegacy()) return;
    if (g_arcLegacy.sect == L"守律立道") { g_factionTie.favor = min(90, g_factionTie.favor + 10); g_factionTie.hook += L" 旧宗不敢只用空话约束你。"; }
    else if (g_arcLegacy.sect == L"师承共担") { g_factionTie.favor = min(90, g_factionTie.favor + 7); g_factionTie.binding = true; g_factionTie.hook += L" 跨世师承旧约仍在接引。"; }
    else if (g_arcLegacy.sect == L"自立道统") { g_factionTie.favor = max(-80, g_factionTie.favor - 5); g_factionTie.binding = true; g_factionTie.hook += L" 此势力既想招揽，也防你再次自立。"; }
    if (!g_arcLegacy.rival.empty()) {
        int relation = g_arcLegacy.rival == L"照雪宿敌" ? -22 : (g_arcLegacy.rival == L"照雪盟友" ? 24 : 8);
        AddSocialThread(L"江照雪", L"跨世战帖旧约", g_arcLegacy.rival,
            L"她不让旧情替今生作数，却会按旧约决定是并肩、争胜还是互相校准。",
            relation, L"外显修为不定", true, L"轮回后的真实境界仍不可知");
    }
    wstring hook = L"跨世定局：" + BuildArcLegacyDigest();
    if (find(g_lifeStoryHooks.begin(), g_lifeStoryHooks.end(), hook) == g_lifeStoryHooks.end()) g_lifeStoryHooks.insert(g_lifeStoryHooks.begin(), hook);
    if (g_lifeStoryHooks.size() > 10) g_lifeStoryHooks.resize(10);
    AddMemory(L"跨世定局入世", BuildArcLegacyDigest());
    AppendTraceLog(L"ARC_LEGACY_BIRTH", BuildArcLegacyDigest());
}

bool ShouldTriggerArcLegacyEvent() {
    if (g_generation <= 1 || !HasArcLegacy() || g_player.totalEvents < 2) return false;
    if (g_player.totalEvents - g_lastArcEchoEvent < 5) return false;
    return Random(1, 100) <= min(30, 12 + (g_generation - 1) * 2 + (g_player.totalEvents >= 8 ? 5 : 0));
}

Event BuildArcLegacyEvent() {
    vector<int> arcs;
    for (int a = ARC_JADE; a <= ARC_RIVAL; ++a) if (!ArcLegacyRef(a).empty() && a != g_lastArcEchoKind) arcs.push_back(a);
    if (arcs.empty()) for (int a = ARC_JADE; a <= ARC_RIVAL; ++a) if (!ArcLegacyRef(a).empty()) arcs.push_back(a);
    int arc = arcs.empty() ? ARC_JADE : arcs[Random(0, (int)arcs.size() - 1)];
    g_lastArcEchoKind = arc;
    Event evt;
    static const vector<wstring> titles = {L"【轮回定局】旧玉照今", L"【轮回定局】旧宗来帖", L"【轮回定局】旧名入册", L"【轮回定局】照雪旧约"};
    evt.title = titles[arc];
    evt.description = L"前世以“" + ArcLegacyRef(arc) + L"”收束的决定再次落到今生。旧约可以提供线索，却不能代替当前判断。";
    int exp = 72 + g_player.realm * 7, risk = 18 + g_player.realm * 2;
    evt.choices = {
        {L"沿旧约行事", {L"你承认旧约能提供线索，却重新用今生判断执行它。\n修为+" + to_wstring(exp + 25) + L"，因果+6，掌道+3", L"你照搬前世做法，忽略此世局势已经变化。\n气血-" + to_wstring(risk) + L"，因果-5"}, 4},
        {L"改写旧约", {L"你保留旧约核心，也改掉不适合今生的部分。\n修为+" + to_wstring(exp) + L"，寿命+2，掌道+4", L"旧约牵连者不肯接受改写。\n气血-" + to_wstring(max(10, risk - 5)) + L"，因果-4"}, 3},
        {L"暂不回应", {L"你先收好证据，等待现实再给一次印证。\n修为+" + to_wstring(max(45, exp - 18)) + L"，掌道+2", L"真正可用的线索随之冷却。\n灵石-5"}, 1}
    };
    return evt;
}

'''
    text = once(text, "bool ShouldTriggerLifeStoryProgressEvent() {", helpers + "bool ShouldTriggerLifeStoryProgressEvent() {", "legacy helpers")
    text = once(text, "    AdvanceNarrativeArc(arc);\n    return evt;", "    g_pendingArc = arc;\n    g_pendingArcStage = stage;\n    return evt;", "defer arc advance")
    text = once(text, "    AppendAdventureResourceSpoils(*g_currentEvent, successLike, g_messageText);", "    ResolveArcOutcome(*g_currentEvent, choice, g_messageText, successLike);\n    AppendAdventureResourceSpoils(*g_currentEvent, successLike, g_messageText);", "resolve terminal")
    text = once(text, "    int modifier = directChoice ? 10 : 5;", "    int modifier = directChoice ? 10 : 5;\n    if (g_arcLegacy.jade == L\"旧我为证\") modifier += 4;\n    else if (g_arcLegacy.jade == L\"今生校旧\") modifier += 3;\n    else if (g_arcLegacy.jade == L\"封梦自持\") modifier += 2;", "jade modifier")
    text = once(text, "    wstring birthEcho = ApplyInheritedLegacyToBirth();", "    wstring birthEcho = ApplyInheritedLegacyToBirth();\n    wstring arcEcho = ApplyArcLegacyBirth();\n    if (!arcEcho.empty()) { if (!birthEcho.empty()) birthEcho += L\" \"; birthEcho += arcEcho; }", "birth effects")
    text = once(text, "    g_lifeArtifacts.clear();\n    GenerateSocialRumors();\n    if (!birthEcho.empty()) {", "    g_lifeArtifacts.clear();\n    GenerateSocialRumors();\n    ApplyArcLegacyWorld();\n    if (!birthEcho.empty()) {", "world effects")
    text = once(text, "                    else if (ShouldTriggerLongCharacterEvent()) {", "                    else if (ShouldTriggerArcLegacyEvent()) {\n                        static Event s_arcLegacyEvent;\n                        s_arcLegacyEvent = BuildArcLegacyEvent();\n                        g_lastArcEchoEvent = g_player.totalEvents;\n                        OpenEventPage(&s_arcLegacyEvent, L\"跨世定局历练\");\n                        InvalidateRect(hWnd, NULL, FALSE);\n                    }\n                    else if (ShouldTriggerLongCharacterEvent()) {", "legacy event")

    text = once(text, '    file << L"STORY_STATE_V2\\n";', '    file << L"STORY_STATE_V3\\n";', "save version")
    old_save = "    file << g_narrativeArcs.jadeStage << L\" \"\n         << g_narrativeArcs.sectStage << L\" \"\n         << g_narrativeArcs.familyStage << L\" \"\n         << g_narrativeArcs.rivalStage << L\" \"\n         << g_narrativeArcs.lastArc << L\"\\n\";\n}"
    new_save = old_save[:-2] + "    file << EscapeSaveField(g_arcLegacy.jade) << L\"\\n\";\n    file << EscapeSaveField(g_arcLegacy.sect) << L\"\\n\";\n    file << EscapeSaveField(g_arcLegacy.family) << L\"\\n\";\n    file << EscapeSaveField(g_arcLegacy.rival) << L\"\\n\";\n}"
    text = once(text, old_save, new_save, "save tags")
    text = once(text, '    bool isStoryV2 = (marker == L"STORY_STATE_V2");\n    bool isStoryV1 = (marker == L"STORY_STATE_V1");\n    if (!isStoryV1 && !isStoryV2) return false;', '    bool isStoryV3 = (marker == L"STORY_STATE_V3");\n    bool isStoryV2 = (marker == L"STORY_STATE_V2");\n    bool isStoryV1 = (marker == L"STORY_STATE_V1");\n    if (!isStoryV1 && !isStoryV2 && !isStoryV3) return false;', "load version")
    text = once(text, "    if (isStoryV2) {", "    if (isStoryV2 || isStoryV3) {", "load v3 branch")
    text = once(text, "        g_lifeStoryProgressThisLife = GetNarrativeArcTotalProgress();\n    } else {", "        g_lifeStoryProgressThisLife = GetNarrativeArcTotalProgress();\n        if (isStoryV3) {\n            getline(file, g_arcLegacy.jade); getline(file, g_arcLegacy.sect);\n            getline(file, g_arcLegacy.family); getline(file, g_arcLegacy.rival);\n            g_arcLegacy.jade = UnescapeSaveField(g_arcLegacy.jade);\n            g_arcLegacy.sect = UnescapeSaveField(g_arcLegacy.sect);\n            g_arcLegacy.family = UnescapeSaveField(g_arcLegacy.family);\n            g_arcLegacy.rival = UnescapeSaveField(g_arcLegacy.rival);\n        } else g_arcLegacy = ArcLegacyState();\n    } else {\n        g_arcLegacy = ArcLegacyState();", "load tags")

    text = once(text, '    world << L"- 分线进度: " << BuildNarrativeArcDigest() << L"\\n";', '    world << L"- 分线进度: " << BuildNarrativeArcDigest() << L"\\n";\n    world << L"- 跨世定局: " << BuildArcLegacyDigest() << L"\\n";', "ai digest")
    text = once(text, '    ss << L"主线分线: " << BuildNarrativeArcDigest() << L"\\n\\n";', '    ss << L"主线分线: " << BuildNarrativeArcDigest() << L"\\n";\n    ss << L"跨世定局: " << BuildArcLegacyDigest() << L"\\n\\n";', "main digest")
    text = once(text, '    WriteJsonField(ss, L"storyArcs", BuildNarrativeArcDigest());', '    WriteJsonField(ss, L"storyArcs", BuildNarrativeArcDigest());\n    WriteJsonField(ss, L"arcLegacies", BuildArcLegacyDigest());', "agent digest")
    text = once(text, '    ss << L"\\n此世尚浅，根基、人情与旧债都会从第一步里慢慢浮上来。";', '    if (HasArcLegacy()) ss << L"\\n跨世定局: " << BuildArcLegacyDigest() << L"\\n";\n    ss << L"\\n此世尚浅，根基、人情与旧债都会从第一步里慢慢浮上来。";', "opening digest")
    text = once(text, "    g_lastLifeStoryProgressEventCount = -1000;\n    g_plannedLegacies.clear();", "    g_lastLifeStoryProgressEventCount = -1000;\n    g_lastArcEchoEvent = -1000;\n    g_lastArcEchoKind = -1;\n    g_pendingArc = g_pendingArcStage = -1;\n    g_plannedLegacies.clear();", "reset counters")

    SRC.write_text(text, encoding="utf-8")
    print("Applied v0.8 arc legacies and STORY_STATE_V3.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
