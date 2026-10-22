#!/usr/bin/env python3
"""Audit every player-readable string in the six chronicle volumes.

This is deliberately a review aid rather than an automatic prose rewriter.  It
locates passages that deserve a human read: long spoken lines, overloaded
choice labels, bureaucratic clusters, long sentences, and number-heavy
paragraphs.  A match is not automatically an error; the setting may genuinely
need a technical term or a dense account at that moment.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
import json
from pathlib import Path
import re
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
CHRONICLE_DIR = ROOT / "godot" / "data" / "chronicles"
VOLUMES = {
    "classical": "classical_v1.json",
    "steam": "steam_v1.json",
    "star_network": "star_network_v1.json",
    "wasteland": "wasteland_v1.json",
    "final_age": "final_age_v1.json",
    "immortal_dynasty": "immortal_dynasty_v1.json",
}

CJK_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]")
DIALOGUE_RE = re.compile(r"[“「『](.+?)[”」』]", re.DOTALL)
SENTENCE_RE = re.compile(r"[^。！？!?；;\n]+[。！？!?；;]?")
NUMBER_WITH_UNIT_RE = re.compile(
    r"(?:\d+|[零〇一二两三四五六七八九十百千万亿]+)"
    r"(?:个|名|人|户|份|枚|座|条|项|次|日|天|时|刻|息|年|月|层|成|格|"
    r"里|丈|卷|章|件|粒|根|箱|车|站|炉|环|席|页|字|米|钱|班|街|坊|"
    r"城|旬|周|夜|家|口|指|分|斤|套|段|组|处|道|位|艘|场|轮)"
)

MACHINE_FIELDS = {
    "id",
    "era_id",
    "route_id",
    "target_chapter_id",
    "character_id",
    "scene",
    "portrait",
    "motion_profile",
    "portrait_mode",
}
ARCHAIC_SPEECH = (
    "吾",
    "汝",
    "尔等",
    "此乃",
    "何须",
    "莫要",
    "须知",
    "故而",
    "休得",
    "尔敢",
    "贫道",
    "本座",
    "老夫",
    "岂有此理",
)
ADMIN_TERMS = (
    "核验",
    "复核",
    "执行",
    "流程",
    "程序",
    "机制",
    "权限",
    "责任",
    "追责",
    "申诉",
    "审查",
    "保全",
    "证据",
    "记录",
    "名册",
    "名单",
    "条款",
    "期限",
    "授权",
    "签章",
    "签责",
    "名页",
    "议席",
    "轮值",
    "调度",
    "补偿",
    "赔偿",
    "申请",
    "报告",
    "附令",
    "裁决",
    "接口",
    "模板",
    "字段",
    "协议",
    "合同",
    "账户",
    "索引",
    "数据",
    "系统",
    "数据库",
    "监管",
)
FORMULAIC_LINKS = (
    "这意味着",
    "问题在于",
    "更重要的是",
    "换句话说",
    "归根结底",
    "从某种意义上",
    "显而易见",
    "值得注意的是",
)


@dataclass(frozen=True)
class TextUnit:
    volume: str
    chapter_id: str
    kind: str
    path: str
    text: str


@dataclass(frozen=True)
class Issue:
    severity: str
    code: str
    volume: str
    chapter_id: str
    path: str
    metric: int
    excerpt: str


def cjk_count(text: str) -> int:
    return len(CJK_RE.findall(text))


def compact_excerpt(text: str, limit: int = 110) -> str:
    value = re.sub(r"\s+", " ", text).strip()
    return value if len(value) <= limit else value[: limit - 1] + "…"


def term_count(text: str, terms: Iterable[str]) -> int:
    return sum(text.count(term) for term in terms)


def classify(path: tuple[str, ...]) -> str:
    if path[-1] == "title":
        return "title"
    if path[-1] == "summary":
        return "summary"
    if path[-1] == "stance":
        return "relationship_stance"
    if "choices" in path and path[-1] == "text" and not any(
        field in path
        for field in ("delayed_echoes", "promises_add", "debts_add", "statuses_add")
    ):
        return "choice"
    if "outcome" in path or "outcome_blocks" in path:
        return "outcome"
    if "delayed_echoes" in path:
        return "delayed_echo"
    if "promises_add" in path:
        return "promise"
    if "debts_add" in path:
        return "debt"
    if "statuses_add" in path:
        return "status"
    if "route_variants" in path:
        return "route_variant"
    if "inheritance_variants" in path:
        return "inheritance"
    if "route_resolutions" in path:
        return "route_resolution"
    if "description" in path or "description_blocks" in path:
        return "description"
    return "supporting"


def collect_units(volume: str, data: dict[str, Any]) -> list[TextUnit]:
    chapters = data.get("chapters", [])
    chapter_ids = {
        str(index): str(chapter.get("id", f"chapter_{index + 1}"))
        for index, chapter in enumerate(chapters)
        if isinstance(chapter, dict)
    }
    units: list[TextUnit] = []

    def visit(value: Any, path: tuple[str, ...] = ()) -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                visit(child, path + (str(key),))
            return
        if isinstance(value, list):
            for index, child in enumerate(value):
                visit(child, path + (str(index),))
            return
        if not isinstance(value, str) or not path or path[-1] in MACHINE_FIELDS:
            return
        if cjk_count(value) < 4:
            return
        chapter_id = "volume"
        if len(path) >= 2 and path[0] == "chapters" and path[1] in chapter_ids:
            chapter_id = chapter_ids[path[1]]
        units.append(
            TextUnit(
                volume=volume,
                chapter_id=chapter_id,
                kind=classify(path),
                path=".".join(path),
                text=value,
            )
        )

    visit(data)
    return units


def issue(
    unit: TextUnit,
    severity: str,
    code: str,
    metric: int,
    excerpt: str | None = None,
) -> Issue:
    return Issue(
        severity=severity,
        code=code,
        volume=unit.volume,
        chapter_id=unit.chapter_id,
        path=unit.path,
        metric=metric,
        excerpt=compact_excerpt(excerpt if excerpt is not None else unit.text),
    )


def audit(units: list[TextUnit]) -> tuple[list[Issue], Counter[str], Counter[str]]:
    issues: list[Issue] = []
    prefix_owners: dict[tuple[str, str], set[str]] = defaultdict(set)
    formulaic_counts: Counter[str] = Counter()

    for unit in units:
        if unit.kind == "choice":
            length = cjk_count(unit.text)
            if length > 28:
                issues.append(issue(unit, "medium", "choice_long", length))
            if "；" in unit.text or ";" in unit.text:
                issues.append(issue(unit, "high", "choice_semicolon", 1))
            admin_count = term_count(unit.text, ADMIN_TERMS)
            if admin_count >= 3:
                issues.append(issue(unit, "medium", "choice_admin_cluster", admin_count))
            clause_count = unit.text.count("，") + unit.text.count("；") + unit.text.count(";")
            if clause_count >= 3:
                issues.append(issue(unit, "medium", "choice_many_clauses", clause_count))

        for match in DIALOGUE_RE.finditer(unit.text):
            spoken = match.group(1).strip()
            spoken_length = cjk_count(spoken)
            if spoken_length > 45:
                severity = "high" if spoken_length > 55 else "medium"
                issues.append(issue(unit, severity, "dialogue_long", spoken_length, spoken))
            archaic_count = term_count(spoken, ARCHAIC_SPEECH)
            if archaic_count:
                issues.append(issue(unit, "medium", "dialogue_archaic", archaic_count, spoken))
            admin_count = term_count(spoken, ADMIN_TERMS)
            if admin_count >= 3:
                issues.append(issue(unit, "medium", "dialogue_admin_cluster", admin_count, spoken))

        for paragraph in re.split(r"(?:\r?\n){2,}", unit.text):
            paragraph_length = cjk_count(paragraph)
            if paragraph_length < 8:
                continue
            admin_count = term_count(paragraph, ADMIN_TERMS)
            if admin_count >= 7 and admin_count * 100 >= paragraph_length * 5:
                issues.append(
                    issue(unit, "medium", "paragraph_admin_dense", admin_count, paragraph)
                )
            numeric_count = len(NUMBER_WITH_UNIT_RE.findall(paragraph))
            if numeric_count >= 7:
                issues.append(
                    issue(unit, "medium", "paragraph_number_dense", numeric_count, paragraph)
                )
            if paragraph_length > 190:
                issues.append(
                    issue(unit, "medium", "paragraph_long", paragraph_length, paragraph)
                )

        for raw_sentence in SENTENCE_RE.findall(unit.text):
            sentence = raw_sentence.strip()
            sentence_length = cjk_count(sentence)
            if sentence_length < 4:
                continue
            if sentence_length > 68:
                severity = "high" if sentence_length > 80 else "medium"
                issues.append(issue(unit, severity, "sentence_long", sentence_length, sentence))
            prefix = "".join(CJK_RE.findall(sentence))[:8]
            if len(prefix) == 8:
                prefix_owners[(unit.volume, prefix)].add(unit.path)

        for phrase in FORMULAIC_LINKS:
            formulaic_counts[f"{unit.volume}:{phrase}"] += unit.text.count(phrase)

    repeated_prefixes: Counter[str] = Counter()
    for (volume, prefix), owners in prefix_owners.items():
        if len(owners) >= 5:
            repeated_prefixes[f"{volume}:{prefix}"] = len(owners)
    return issues, repeated_prefixes, formulaic_counts


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", type=Path, help="write the complete audit payload as UTF-8 JSON")
    parser.add_argument("--show", type=int, default=80, help="maximum issues to print")
    parser.add_argument(
        "--code",
        action="append",
        help="only print the selected issue code; may be supplied more than once",
    )
    args = parser.parse_args()

    units: list[TextUnit] = []
    chapter_counts: Counter[str] = Counter()
    for volume, filename in VOLUMES.items():
        data = json.loads((CHRONICLE_DIR / filename).read_text(encoding="utf-8"))
        volume_units = collect_units(volume, data)
        units.extend(volume_units)
        chapter_counts[volume] = len(data.get("chapters", []))

    issues, repeated_prefixes, formulaic_counts = audit(units)
    issue_counts = Counter(value.code for value in issues)
    severity_counts = Counter(value.severity for value in issues)
    volume_counts = Counter(value.volume for value in issues)
    dialogue_count = sum(len(DIALOGUE_RE.findall(unit.text)) for unit in units)
    sentence_count = sum(
        1
        for unit in units
        for sentence in SENTENCE_RE.findall(unit.text)
        if cjk_count(sentence) >= 4
    )
    paragraph_count = sum(
        1
        for unit in units
        for paragraph in re.split(r"(?:\r?\n){2,}", unit.text)
        if cjk_count(paragraph) >= 8
    )

    print(
        "CHRONICLE_READABILITY_AUDIT: "
        f"{len(units):,} readable strings, {sum(cjk_count(unit.text) for unit in units):,} CJK, "
        f"{sum(chapter_counts.values())} chapters, {paragraph_count:,} paragraphs, "
        f"{sentence_count:,} sentences, {dialogue_count:,} spoken lines"
    )
    print(
        "ISSUES: "
        + ", ".join(f"{name}={count}" for name, count in sorted(issue_counts.items()))
    )
    print(
        "SEVERITY: "
        + ", ".join(f"{name}={count}" for name, count in sorted(severity_counts.items()))
    )
    print(
        "BY_VOLUME: "
        + ", ".join(f"{name}={volume_counts[name]}" for name in VOLUMES)
    )
    if repeated_prefixes:
        print(
            "REPEATED_PREFIXES: "
            + ", ".join(
                f"{name}={count}" for name, count in repeated_prefixes.most_common(12)
            )
        )
    used_formulaic = [
        (name, count) for name, count in formulaic_counts.most_common() if count
    ]
    if used_formulaic:
        print(
            "FORMULAIC_LINKS: "
            + ", ".join(f"{name}={count}" for name, count in used_formulaic)
        )

    selected = [value for value in issues if not args.code or value.code in args.code]
    severity_order = {"high": 0, "medium": 1, "low": 2}
    selected.sort(
        key=lambda value: (
            severity_order.get(value.severity, 9),
            -value.metric,
            value.volume,
            value.path,
        )
    )
    for value in selected[: max(0, args.show)]:
        print(
            f"[{value.severity.upper()}] {value.code} metric={value.metric} "
            f"{value.volume}/{value.chapter_id} {value.path}: {value.excerpt}"
        )

    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "coverage": {
                "readable_strings": len(units),
                "cjk": sum(cjk_count(unit.text) for unit in units),
                "chapters": sum(chapter_counts.values()),
                "paragraphs": paragraph_count,
                "sentences": sentence_count,
                "spoken_lines": dialogue_count,
            },
            "issue_counts": dict(sorted(issue_counts.items())),
            "severity_counts": dict(sorted(severity_counts.items())),
            "volume_counts": {name: volume_counts[name] for name in VOLUMES},
            "repeated_prefixes": dict(repeated_prefixes.most_common()),
            "formulaic_links": dict(used_formulaic),
            "issues": [asdict(value) for value in issues],
        }
        args.json.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"JSON_REPORT: {args.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
