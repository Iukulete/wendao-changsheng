# -*- coding: utf-8 -*-
"""Add persistent Dao-heart, reputation and enmity dimensions.

The game historically used one karma number for morality, social standing,
luck and breakthrough assistance. Long Agent runs therefore pushed karma into
the thousands and flattened most choices. This idempotent build-time patch:

* keeps karma as fate/debt, but applies diminishing returns to checks;
* adds persistent daoHeart, reputation and enmity player values;
* derives modest changes from event wording and choice intent;
* exposes the values in status UI, Agent JSON and AI context;
* upgrades saves to SAVE_V5 while retaining SAVE_V4 loading.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
MARKER = "V0_6_PATH_DIMENSIONS"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"Unable to patch {label}: anchor not found")
    return text.replace(old, new, 1)


def main() -> int:
    if not SRC.exists():
        raise FileNotFoundError(f"Source file not found: {SRC}")

    content = SRC.read_text(encoding="utf-8")
    if MARKER in content:
        print("v0.6 path dimensions already applied.")
        return 0

    content = replace_once(
        content,
        "// ==================== 玩家类（增强五行系统） ====================\nclass Player {",
        "// ==================== 玩家类（增强五行系统） ====================\n"
        "int GetEffectiveKarmaScore(int karma); // V0_6_PATH_DIMENSIONS\n\n"
        "class Player {",
        "karma helper declaration",
    )

    content = replace_once(
        content,
        "    int attackPower, defense;\n    int totalEvents, battlesWon, npcsMet;",
        "    int attackPower, defense;\n"
        "    int daoHeart, reputation, enmity; // V0_6_PATH_DIMENSIONS\n"
        "    int totalEvents, battlesWon, npcsMet;",
        "player path fields",
    )

    content = replace_once(
        content,
        "               attackPower(0), defense(0), totalEvents(0), battlesWon(0), npcsMet(0),",
        "               attackPower(0), defense(0), daoHeart(0), reputation(0), enmity(0),\n"
        "               totalEvents(0), battlesWon(0), npcsMet(0),",
        "player constructor",
    )

    content = replace_once(
        content,
        "        karma += family.fame / 20;",
        "        karma += family.fame / 20;\n"
        "        reputation = max(-20, min(20, family.fame / 2));",
        "birth reputation",
    )

    content = replace_once(
        content,
        "        ss << L\"因果: \" << karma << L\"\\n\";",
        "        ss << L\"因果: \" << karma << L\"（判定有效值 \" << GetEffectiveKarmaScore(karma) << L\"）\\n\";\n"
        "        ss << L\"道心: \" << daoHeart << L\" | 名望: \" << reputation\n"
        "           << L\" | 仇怨: \" << enmity << L\"\\n\";",
        "status path dimensions",
    )

    helper_block = r'''
int GetEffectiveKarmaScore(int karma) { // V0_6_PATH_DIMENSIONS
    int sign = karma < 0 ? -1 : 1;
    int value = abs(karma);
    int effective = min(value, 40);
    if (value > 40) effective += (value - 40) / 8;
    return sign * min(120, effective);
}

wstring GetPathDimensionDigest() {
    wstringstream ss;
    ss << L"道心" << g_player.daoHeart
       << L" · 名望" << g_player.reputation
       << L" · 仇怨" << g_player.enmity
       << L" · 因果有效值" << GetEffectiveKarmaScore(g_player.karma);
    return ss.str();
}

'''
    content = replace_once(
        content,
        "// ==================== 事件系统 ====================",
        helper_block + "// ==================== 事件系统 ====================",
        "path helper definitions",
    )

    effect_block = r'''
void ApplyPathDimensionEffects(const Event& event, const Choice& choice,
                               wstring& outcome, bool successLike) { // V0_6_PATH_DIMENSIONS
    auto containsAny = [](const wstring& text, initializer_list<const wchar_t*> words) {
        for (const wchar_t* word : words) {
            if (text.find(word) != wstring::npos) return true;
        }
        return false;
    };
    auto clampStat = [](int value, int low, int high) {
        return max(low, min(high, value));
    };

    const wstring allText = event.title + L" " + event.description + L" " +
                            choice.description + L" " + outcome;
    const int explicitKarma = ExtractValue(outcome, L"因果+") -
                              ExtractValue(outcome, L"因果-");
    const int totalKarma = explicitKarma + choice.karmaChange;

    int daoDelta = min(8, ExtractValue(outcome, L"掌道+") / 2);
    int reputationDelta = totalKarma / 6;
    int enmityDelta = 0;

    if (containsAny(choice.description,
        {L"稳", L"守", L"问", L"听", L"观", L"护", L"救", L"克制", L"不贪", L"拒绝强取"})) {
        daoDelta += successLike ? 2 : 1;
    }
    if (!successLike && containsAny(choice.description,
        {L"强夺", L"硬闯", L"抢先", L"赌", L"逼", L"杀"})) {
        daoDelta -= 1;
    }

    if (successLike && containsAny(allText,
        {L"宗门", L"道庭", L"掌律", L"仙朝", L"名册", L"坊市", L"救下", L"护送", L"作证"})) {
        reputationDelta += 2;
    }
    if (containsAny(allText,
        {L"记恨", L"追杀", L"围杀", L"仇家", L"报复", L"盯上", L"暗杀", L"通缉"})) {
        enmityDelta += successLike ? 1 : 3;
    }
    if (containsAny(choice.description,
        {L"强夺", L"威逼", L"抢先", L"拒不", L"反杀", L"拆穿"})) {
        enmityDelta += 1;
    }
    if (successLike && containsAny(choice.description,
        {L"护送", L"救", L"调解", L"作证", L"分润", L"留情"})) {
        enmityDelta -= 1;
    }

    daoDelta = max(-3, min(10, daoDelta));
    reputationDelta = max(-8, min(8, reputationDelta));
    enmityDelta = max(-3, min(8, enmityDelta));

    int oldDao = g_player.daoHeart;
    int oldReputation = g_player.reputation;
    int oldEnmity = g_player.enmity;
    g_player.daoHeart = clampStat(g_player.daoHeart + daoDelta, -100, 500);
    g_player.reputation = clampStat(g_player.reputation + reputationDelta, -200, 500);
    g_player.enmity = clampStat(g_player.enmity + enmityDelta, 0, 500);

    int actualDao = g_player.daoHeart - oldDao;
    int actualReputation = g_player.reputation - oldReputation;
    int actualEnmity = g_player.enmity - oldEnmity;
    if (actualDao || actualReputation || actualEnmity) {
        outcome += L"\n道途余波:";
        if (actualDao) outcome += L" 道心" + FormatSignedInt(actualDao);
        if (actualReputation) outcome += L" 名望" + FormatSignedInt(actualReputation);
        if (actualEnmity) outcome += L" 仇怨" + FormatSignedInt(actualEnmity);
    }
}

'''
    content = replace_once(
        content,
        "wstring BuildPlayerVisibleOutcomeText(wstring text) {",
        effect_block + "wstring BuildPlayerVisibleOutcomeText(wstring text) {",
        "path outcome effects",
    )

    content = replace_once(
        content,
        "        int successRate = 60 + g_player.karma / 5 + GetDaoAdventureSuccessModifier()",
        "        int successRate = 60 + GetEffectiveKarmaScore(g_player.karma) / 5\n"
        "            + g_player.daoHeart / 20 + g_player.reputation / 35 - g_player.enmity / 30\n"
        "            + GetDaoAdventureSuccessModifier()",
        "AI event success formula",
    )

    content = replace_once(
        content,
        "    bool successLike = isAIEvent\n"
        "        ? (aiSuccess && IsPositiveOutcomeText(g_messageText))\n"
        "        : ((outcomeIndex == 0) && IsPositiveOutcomeText(g_messageText));\n"
        "    AppendAdventureResourceSpoils(*g_currentEvent, successLike, g_messageText);",
        "    bool successLike = isAIEvent\n"
        "        ? (aiSuccess && IsPositiveOutcomeText(g_messageText))\n"
        "        : ((outcomeIndex == 0) && IsPositiveOutcomeText(g_messageText));\n"
        "    ApplyPathDimensionEffects(*g_currentEvent, choice, g_messageText, successLike);\n"
        "    AppendAdventureResourceSpoils(*g_currentEvent, successLike, g_messageText);",
        "event path effect call",
    )

    content = replace_once(
        content,
        "    ctx.karma = g_player.karma;",
        "    ctx.karma = GetEffectiveKarmaScore(g_player.karma);",
        "AI context effective karma",
    )

    content = replace_once(
        content,
        "    ctx.rootState = g_player.GetRootQuality() + L\"；\" + g_player.GetRootDetails() +\n"
        "        L\"；形态:\" + g_player.GetRootShapeLabel() +\n"
        "        L\"；时代适性:\" + g_player.GetRootEraTraitText();",
        "    ctx.rootState = g_player.GetRootQuality() + L\"；\" + g_player.GetRootDetails() +\n"
        "        L\"；形态:\" + g_player.GetRootShapeLabel() +\n"
        "        L\"；时代适性:\" + g_player.GetRootEraTraitText() +\n"
        "        L\"；道途维度:\" + GetPathDimensionDigest();",
        "AI context path dimensions",
    )

    content = replace_once(
        content,
        "    WriteJsonField(ss, L\"roots\", g_player.GetRootDetails(), false);",
        "    WriteJsonField(ss, L\"roots\", g_player.GetRootDetails());\n"
        "    ss << L\"\\\"daoHeart\\\":\" << g_player.daoHeart << L\",\\n\";\n"
        "    ss << L\"\\\"reputation\\\":\" << g_player.reputation << L\",\\n\";\n"
        "    ss << L\"\\\"enmity\\\":\" << g_player.enmity << L\",\\n\";\n"
        "    ss << L\"\\\"effectiveKarma\\\":\" << GetEffectiveKarmaScore(g_player.karma) << L\"\\n\";",
        "Agent path fields",
    )

    content = replace_once(
        content,
        "            DrawLabelValue(graphics, statFont, statFont, mutedBrush, whiteBrush, leftFormat, L\"因果\",\n"
        "                to_wstring(g_player.karma), leftPanel.X + 18, y, leftPanel.Width - 36);\n"
        "            y += 28;",
        "            DrawLabelValue(graphics, statFont, statFont, mutedBrush, whiteBrush, leftFormat, L\"因果\",\n"
        "                to_wstring(g_player.karma) + L\" / 有效\" + to_wstring(GetEffectiveKarmaScore(g_player.karma)),\n"
        "                leftPanel.X + 18, y, leftPanel.Width - 36);\n"
        "            y += 28;\n"
        "            DrawLabelValue(graphics, statFont, statFont, mutedBrush, whiteBrush, leftFormat, L\"道途\",\n"
        "                L\"心\" + to_wstring(g_player.daoHeart) + L\" 名\" + to_wstring(g_player.reputation) +\n"
        "                L\" 仇\" + to_wstring(g_player.enmity), leftPanel.X + 18, y, leftPanel.Width - 36);\n"
        "            y += 28;",
        "main UI path dimensions",
    )

    # Save slot reader: accept both versions and consume the three new fields only for V5.
    content = replace_once(
        content,
        "    if (marker != L\"SAVE_V4\") {",
        "    bool isV5 = (marker == L\"SAVE_V5\");\n"
        "    bool isV4 = (marker == L\"SAVE_V4\");\n"
        "    if (!isV4 && !isV5) {",
        "save slot version check",
    )
    content = replace_once(
        content,
        "    int karma = 0;\n    int age = 0;",
        "    int karma = 0;\n"
        "    int daoHeart = 0;\n"
        "    int reputation = 0;\n"
        "    int enmity = 0;\n"
        "    int age = 0;",
        "save slot path locals",
    )
    content = replace_once(
        content,
        "    file >> karma >> age >> lifespan >> spiritStones >> pills;",
        "    file >> karma;\n"
        "    if (isV5) file >> daoHeart >> reputation >> enmity;\n"
        "    else reputation = max(-20, min(20, karma / 2));\n"
        "    file >> age >> lifespan >> spiritStones >> pills;",
        "save slot path read",
    )
    content = replace_once(
        content,
        "        L\" · 历练\" + to_wstring(max(0, totalEvents)) +",
        "        L\" · 道心\" + to_wstring(daoHeart) + L\" 名望\" + to_wstring(reputation) +\n"
        "        L\" · 历练\" + to_wstring(max(0, totalEvents)) +",
        "save slot detail",
    )

    content = replace_once(content, '    file << L"SAVE_V4\\n";', '    file << L"SAVE_V5\\n";', "save version")
    content = replace_once(
        content,
        "    file << g_player.karma << L\"\\n\";\n    file << g_player.age << L\"\\n\";",
        "    file << g_player.karma << L\"\\n\";\n"
        "    file << g_player.daoHeart << L\"\\n\";\n"
        "    file << g_player.reputation << L\"\\n\";\n"
        "    file << g_player.enmity << L\"\\n\";\n"
        "    file << g_player.age << L\"\\n\";",
        "save path values",
    )

    content = replace_once(
        content,
        "    bool isV4 = (firstLine == L\"SAVE_V4\");\n    if (!isV4) return false;",
        "    bool isV5 = (firstLine == L\"SAVE_V5\");\n"
        "    bool isV4 = (firstLine == L\"SAVE_V4\");\n"
        "    if (!isV4 && !isV5) return false;",
        "load version check",
    )
    content = replace_once(
        content,
        "    file >> g_player.karma >> g_player.age >> g_player.lifespan;",
        "    file >> g_player.karma;\n"
        "    if (isV5) {\n"
        "        file >> g_player.daoHeart >> g_player.reputation >> g_player.enmity;\n"
        "    } else {\n"
        "        g_player.daoHeart = 0;\n"
        "        g_player.reputation = max(-20, min(20, g_player.karma / 2));\n"
        "        g_player.enmity = max(0, -g_player.karma / 5);\n"
        "    }\n"
        "    file >> g_player.age >> g_player.lifespan;",
        "load path values",
    )

    content = replace_once(
        content,
        "    g_player.karma += reputationBonus;",
        "    g_player.karma += reputationBonus;\n"
        "    g_player.reputation = max(-200, min(500, g_player.reputation + reputationBonus));\n"
        "    g_player.daoHeart = max(-100, min(500, g_player.daoHeart + max(0, memoryBonus / 6)));",
        "next-life path inheritance",
    )

    SRC.write_text(content, encoding="utf-8")
    print("Applied v0.6 path dimensions: dao heart, reputation, enmity, SAVE_V5 and karma diminishing returns.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
