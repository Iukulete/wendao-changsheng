#!/usr/bin/env python3
"""Build a reviewable full-corpus character census.

The existing character index intentionally focuses on already-canonical
runtime references.  This census has a different job: it scans every authored
chronicle, story/event JSON, and the authored C++ social layer for names that
still need identity review.  It never promotes a heuristic name to a runtime
character automatically.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "godot" / "data"
CHARACTER_DIR = DATA_DIR / "characters"
GENERATED_DIR = DATA_DIR / "generated"

JSON_SOURCES = [
    *sorted((DATA_DIR / "chronicles").glob("*.json")),
    DATA_DIR / "story_arcs_v1.json",
    DATA_DIR / "events_v014.json",
]
CPP_SOURCE = ROOT / "src" / "wendao_enhanced.cpp"

STRUCTURED_KEYS = {
    "speaker",
    "speaker_id",
    "character",
    "character_id",
    "actor",
    "actor_id",
    "npc",
    "npc_id",
    "target",
    "target_id",
    "participants",
    "members",
    "companions",
    "relationship_target",
    "relationship_target_id",
    "combatants",
    "enemy",
    "enemy_id",
    "ally",
    "ally_id",
    "combat_character_id",
    "combatant_id",
    "portrait_character_id",
}

COMMON_SURNAMES = set(
    "赵钱孙李周吴郑王冯陈褚卫蒋沈韩杨朱秦尤许何吕施张孔曹严华金魏陶姜戚谢邹喻柏水窦章云苏潘葛奚范彭郎鲁韦昌马苗凤花方俞任袁柳酆鲍史唐费廉岑薛雷贺倪汤滕殷罗毕郝邬安常乐于时傅皮卞齐康伍余元卜顾孟平黄和穆萧尹姚邵湛汪祁毛禹狄米贝明臧计伏成戴谈宋茅庞熊纪舒屈项祝董梁杜阮蓝闵席季麻强贾路娄危江童颜郭梅盛林刁钟徐邱骆高夏蔡田樊胡凌霍虞万支柯昝管卢莫经房裘缪干解应宗丁宣邓郁单杭洪包诸左石崔吉钮龚程嵇邢滑裴陆荣翁荀羊於惠甄曲家封芮羿储靳汲邴糜松井段富巫乌焦巴弓牧隗山谷车侯宓蓬全郗班仰秋仲伊宫宁仇栾暴甘钭厉戎祖武符刘景詹束龙叶幸司韶郜黎蓟薄印宿白怀蒲邰从鄂索咸籍赖卓蔺屠蒙池乔阴郁胥能苍双闻莘党翟谭贡劳逄姬申扶堵冉宰郦雍郤璩桑桂濮牛寿通边扈燕冀郏浦尚农温别庄晏柴瞿阎充慕连茹习宦艾鱼容向古易慎戈廖庾终暨居衡步都耿满弘匡国文寇广禄阙东欧殳沃利蔚越夔隆师巩厍聂晁勾敖融冷訾辛阚那简饶空曾毋沙乜养鞠须丰巢关蒯相查后荆红游竺权逯盖益桓公仉督晋楚闫法汝鄢涂钦归海岳帅缑亢况后有琴梁"
)
COMPOUND_SURNAMES = {
    "申屠",
    "欧阳",
    "上官",
    "司马",
    "东方",
    "独孤",
    "南宫",
    "诸葛",
    "尉迟",
    "公孙",
    "长孙",
    "皇甫",
    "慕容",
    "令狐",
    "宇文",
    "夏侯",
    "闻人",
    "轩辕",
    "拓跋",
    "赫连",
    "完颜",
}

# These are deliberately conservative.  They stop grammar fragments from
# becoming art tasks, while leaving uncertain names in the review queue.
GRAMMAR_CHARS = set("的了是在有和与及其这那我你他她它们一个各无不未已又也就只还都将把被让从向到于为以而但若如因故能可会要去来过更很最并或此该之所者地时中上下面前后里外")
COMMON_NON_NAMES = {
    "有人",
    "名的",
    "安全地",
    "一名",
    "单一家",
    "重复",
    "克制",
    "现在",
    "其中",
    "随后",
    "此时",
    "已经",
    "没有",
    "不是",
    "只是",
    "什么",
    "如何",
    "为何",
    "不能",
    "可以",
    "所有",
    "那些",
    "他们",
    "她们",
    "这个",
    "那个",
    "明确",
    "方便",
    "全城",
    "任何",
    "任何人",
    "公共频",
    "公开",
    "公开频",
    "冷气",
    "家属盲",
    "宗门",
    "储备库",
    "追责",
}
ROLE_WORDS = (
    "司命",
    "水牢长",
    "水籍司",
    "护城官",
    "执律人",
    "长老",
    "真人",
    "掌门",
    "堂主",
    "队长",
    "官",
    "司",
    "长",
    "使",
    "卫",
    "卒",
    "军",
    "师",
    "医",
    "工",
    "官署",
    "员",
    "管事",
    "老人",
    "老妇",
)
GROUP_SUFFIXES = (
    "队",
    "组",
    "家",
    "院",
    "部",
    "局",
    "司",
    "堂",
    "门",
    "宗",
    "营",
    "军",
    "契",
    "公司",
    "机构",
    "老祖",
    "三号",
)
CONTEXT_FALSE_ENDINGS = (
    "带",
    "抱",
    "接",
    "对",
    "照",
    "知",
    "看",
    "听",
    "替",
    "留",
    "给",
    "拿",
    "牵",
    "希望",
    "回",
    "反",
    "却",
    "询",
    "则",
    "简",
    "旁",
    "近",
    "住",
    "气",
)
ALIAS_PREFIXES = ("阿", "小", "老")
PERSON_SUFFIXES = (
    "男人",
    "女人",
    "男子",
    "女子",
    "少年",
    "少女",
    "孩子",
    "修士",
    "修者",
    "道人",
    "道士",
    "剑修",
    "医师",
    "工匠",
    "阵师",
    "老人",
    "护士",
    "儿子",
    "女儿",
    "兄长",
    "妹妹",
    "哥哥",
    "姐姐",
    "姑娘",
    "前辈",
    "先生",
    "真人",
    "长老",
    "将军",
    "队长",
    "掌柜",
    "大人",
)
ACTION_SUFFIXES = (
    "说",
    "道",
    "问",
    "答",
    "喊",
    "叫",
    "笑",
    "哭",
    "点头",
    "摇头",
    "皱眉",
    "抬头",
    "回头",
    "转身",
    "开口",
    "沉默",
    "低声",
    "冷声",
    "看向",
    "望向",
    "走来",
    "走近",
    "站在",
)

EXPLICIT_NAME_RE = re.compile(
    r"(?:叫作|叫做|名字叫|名叫|自称为|自称|名为|称为|唤作|喊作|旧名为|旧名叫)"
    r"(?:是|为)?[\s\"“”「」『』:：,，、]*"
    r"(?P<name>[\u4e00-\u9fff]{2,4})(?=[的，。、“”\"「」『』；：\s]|$)"
)
TEXT_BOUNDARY = r"(?:^|[，。、“”\"「」『』；：:！？?!（）()、\s])"
NAME_BOUNDARY = (
    r"(?:^|[，。、“”\"「」『』；：:！？?!（）()、\s]|"
    r"对|向|朝|与|和|跟|见|听见|告诉|问|喊|叫|唤|让|由|给|替)"
)
COMPOUND_PATTERN = "|".join(sorted(COMPOUND_SURNAMES, key=len, reverse=True))
CONTEXT_NAME = rf"(?:(?:{COMPOUND_PATTERN})[\u4e00-\u9fff]{{2}}|[\u4e00-\u9fff]{{2,3}})"
ROLE_CONTEXT_RE = re.compile(
    rf"{TEXT_BOUNDARY}(?P<name>{CONTEXT_NAME})(?:的)(?:{'|'.join(PERSON_SUFFIXES)})"
)
ACTION_CONTEXT_RE = re.compile(
    rf"{NAME_BOUNDARY}(?P<name>{CONTEXT_NAME})(?={'|'.join(ACTION_SUFFIXES)})"
)
HONORIFIC_CONTEXT_RE = re.compile(
    rf"{NAME_BOUNDARY}(?P<name>{CONTEXT_NAME})(?={'|'.join(PERSON_SUFFIXES)})"
)


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFKC", value)
    return "".join(value.split()).casefold()


def is_han_name(value: str) -> bool:
    value = value.strip()
    if not 2 <= len(value) <= 4:
        return False
    if any(not ("\u4e00" <= char <= "\u9fff") for char in value):
        return False
    if value in COMMON_NON_NAMES or any(char in GRAMMAR_CHARS for char in value):
        return False
    return True


def has_name_shape(value: str) -> bool:
    if not is_han_name(value):
        return False
    if value.startswith(ALIAS_PREFIXES):
        return True
    if value[:2] in COMPOUND_SURNAMES:
        return len(value) in {3, 4}
    return value[0] in COMMON_SURNAMES and len(value) in {2, 3, 4}


def load_identity_maps() -> tuple[dict[str, str], set[str], set[str], set[str]]:
    registry = load_json(CHARACTER_DIR / "character_registry_v2.json")
    groups = load_json(CHARACTER_DIR / "character_groups_v1.json")
    aliases = load_json(CHARACTER_DIR / "character_aliases_v1.json")

    character_ids = set(registry.get("characters", {}))
    group_ids = set(groups.get("groups", {}))
    lookup: dict[str, str] = {}

    def add(raw: Any, target: str) -> None:
        if isinstance(raw, str) and raw.strip():
            lookup[normalize(raw)] = target

    for character_id, character in registry.get("characters", {}).items():
        add(character_id, character_id)
        identity = character.get("identity", {})
        add(identity.get("display_name"), character_id)
        for alias in identity.get("aliases", []):
            add(alias, character_id)
    for group_id, group in groups.get("groups", {}).items():
        add(group_id, group_id)
        add(group.get("display_name"), group_id)
        for alias in group.get("aliases", []):
            add(alias, group_id)
    for alias, target in aliases.get("aliases", {}).items():
        add(alias, target)
    for scoped in aliases.get("scoped_aliases", []):
        add(scoped.get("alias"), scoped.get("character_id", ""))

    # Story data still uses these short participant aliases in a few legacy
    # route branches; they are canonical references to the protagonist.
    for alias in ("player", "主角", "玩家"):
        add(alias, "protagonist")

    valid_targets = character_ids | group_ids
    lookup = {key: value for key, value in lookup.items() if value in valid_targets}

    combat_ids: set[str] = set()
    for path, key in (
        (DATA_DIR / "combat_sprite_targets_v1.json", "procedural_enemy_targets"),
        (DATA_DIR / "monster_asset_queue_v1.json", "targets"),
    ):
        if not path.exists():
            continue
        data = load_json(path)
        for item in data.get(key, []):
            if isinstance(item, dict) and isinstance(item.get("id"), str):
                combat_ids.add(item["id"])
        combat_ids.update(data.get("named_characters", {}).keys())
    return lookup, character_ids, group_ids, combat_ids


def resolve(raw: str, lookup: dict[str, str]) -> str | None:
    return lookup.get(normalize(raw.strip()))


def iter_json_strings(value: Any, path: str = "") -> Iterable[tuple[str, str]]:
    if isinstance(value, str):
        yield path, value
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from iter_json_strings(child, f"{path}/{index}")
    elif isinstance(value, dict):
        for key, child in value.items():
            yield from iter_json_strings(child, f"{path}/{key}")


def snippet(text: str, start: int, end: int) -> str:
    left = max(0, start - 48)
    right = min(len(text), end + 72)
    return " ".join(text[left:right].replace("\n", " ").split())


def candidate_category(name: str, kind: str) -> str:
    if name in COMMON_NON_NAMES:
        return "noise"
    if name in ROLE_WORDS or any(name.endswith(word) for word in (*ROLE_WORDS, *GROUP_SUFFIXES)):
        return "role_or_group_candidate"
    if has_name_shape(name) or (kind == "explicit_name" and name.startswith(ALIAS_PREFIXES)):
        return "named_person_candidate"
    return "needs_review"


def is_context_candidate(name: str) -> bool:
    return has_name_shape(name) and not any(name.endswith(suffix) for suffix in CONTEXT_FALSE_ENDINGS)


def add_candidate(
    candidates: dict[str, dict[str, Any]],
    *,
    name: str,
    evidence_kind: str,
    source: str,
    source_path: str,
    path: str,
    text: str,
    start: int,
    end: int,
    confidence: float,
) -> None:
    if not is_han_name(name):
        return
    category = candidate_category(name, evidence_kind)
    if category == "noise":
        return
    key = normalize(name)
    record = candidates.setdefault(
        key,
        {
            "name": name,
            "category_guess": category,
            "review_state": "needs_identity_review",
            "evidence_count": 0,
            "evidence_kinds": [],
            "sources": [],
            "source_paths": [],
            "snippets": [],
            "max_confidence": 0.0,
        },
    )
    # Prefer the first readable spelling if the same normalized candidate is
    # encountered with Unicode-normalized punctuation.
    record["evidence_count"] += 1
    if evidence_kind not in record["evidence_kinds"]:
        record["evidence_kinds"].append(evidence_kind)
    if source not in record["sources"]:
        record["sources"].append(source)
    if source_path not in record["source_paths"]:
        record["source_paths"].append(source_path)
    record["max_confidence"] = max(record["max_confidence"], confidence)
    if len(record["snippets"]) < 5:
        record["snippets"].append(
            {
                "source": source,
                "path": path,
                "evidence_kind": evidence_kind,
                "confidence": confidence,
                "text": snippet(text, start, end),
            }
        )


def scan_text(
    *,
    text: str,
    source: str,
    source_path: str,
    path: str,
    known_lookup: dict[str, str],
    candidates: dict[str, dict[str, Any]],
) -> None:
    for match in EXPLICIT_NAME_RE.finditer(text):
        name = match.group("name")
        if resolve(name, known_lookup):
            continue
        add_candidate(
            candidates,
            name=name,
            evidence_kind="explicit_name",
            source=source,
            source_path=source_path,
            path=path,
            text=text,
            start=match.start("name"),
            end=match.end("name"),
            confidence=0.98,
        )

    for regex, kind, confidence in (
        (ROLE_CONTEXT_RE, "person_description", 0.78),
        (HONORIFIC_CONTEXT_RE, "honorific", 0.74),
        (ACTION_CONTEXT_RE, "person_action", 0.68),
    ):
        for match in regex.finditer(text):
            name = match.group("name")
            if not is_context_candidate(name) or resolve(name, known_lookup):
                continue
            add_candidate(
                candidates,
                name=name,
                evidence_kind=kind,
                source=source,
                source_path=source_path,
                path=path,
                text=text,
                start=match.start("name"),
                end=match.end("name"),
                confidence=confidence,
            )


def collect_structured(
    value: Any,
    *,
    source: str,
    source_path: str,
    path: str,
    lookup: dict[str, str],
    combat_ids: set[str],
    counts: Counter[str],
    refs: dict[str, dict[str, Any]],
) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            child_path = f"{path}/{key}"
            if key in STRUCTURED_KEYS:
                raw_values = child if isinstance(child, list) else [child]
                for raw in raw_values:
                    if not isinstance(raw, str) or not raw.strip():
                        continue
                    raw = raw.strip()
                    resolved = resolve(raw, lookup)
                    if resolved is None and raw in combat_ids:
                        resolved = raw
                    counts[raw] += 1
                    item = refs.setdefault(
                        raw,
                        {
                            "raw_value": raw,
                            "resolved_id": resolved,
                            "reference_count": 0,
                            "sources": [],
                            "examples": [],
                        },
                    )
                    item["reference_count"] += 1
                    if source not in item["sources"]:
                        item["sources"].append(source)
                    if len(item["examples"]) < 4:
                        item["examples"].append(
                            {
                                "source": source,
                                "path": f"{source_path}:{child_path}",
                            }
                        )
            collect_structured(
                child,
                source=source,
                source_path=source_path,
                path=child_path,
                lookup=lookup,
                combat_ids=combat_ids,
                counts=counts,
                refs=refs,
            )
    elif isinstance(value, list):
        for index, child in enumerate(value):
            collect_structured(
                child,
                source=source,
                source_path=source_path,
                path=f"{path}/{index}",
                lookup=lookup,
                combat_ids=combat_ids,
                counts=counts,
                refs=refs,
            )


def build() -> dict[str, Any]:
    lookup, character_ids, group_ids, combat_ids = load_identity_maps()
    candidates: dict[str, dict[str, Any]] = {}
    structured_counts: Counter[str] = Counter()
    structured_refs: dict[str, dict[str, Any]] = {}
    scanned_strings = 0
    existing_mentions: Counter[str] = Counter()

    for source_path in JSON_SOURCES:
        if not source_path.exists():
            continue
        authored = load_json(source_path)
        source = source_path.name
        relative = str(source_path.relative_to(ROOT)).replace("\\", "/")
        for path, text in iter_json_strings(authored):
            scanned_strings += 1
            scan_text(
                text=text,
                source=source,
                source_path=relative,
                path=path,
                known_lookup=lookup,
                candidates=candidates,
            )
        collect_structured(
            authored,
            source=source,
            source_path=relative,
            path="",
            lookup=lookup,
            combat_ids=combat_ids,
            counts=structured_counts,
            refs=structured_refs,
        )

    if CPP_SOURCE.exists():
        source_text = CPP_SOURCE.read_text(encoding="utf-8", errors="replace")
        relative = str(CPP_SOURCE.relative_to(ROOT)).replace("\\", "/")
        for line_number, line in enumerate(source_text.splitlines(), start=1):
            if not line.strip():
                continue
            scanned_strings += 1
            scan_text(
                text=line,
                source=CPP_SOURCE.name,
                source_path=relative,
                path=f"line:{line_number}",
                known_lookup=lookup,
                candidates=candidates,
            )

    for raw, item in structured_refs.items():
        if item["resolved_id"]:
            existing_mentions[item["resolved_id"]] += item["reference_count"]

    candidates_list = sorted(
        candidates.values(),
        key=lambda item: (-item["max_confidence"], -item["evidence_count"], item["name"]),
    )
    structured_list = sorted(
        structured_refs.values(),
        key=lambda item: (item["resolved_id"] is None, -item["reference_count"], item["raw_value"]),
    )
    named = [item for item in candidates_list if item["category_guess"] == "named_person_candidate"]
    roles = [item for item in candidates_list if item["category_guess"] == "role_or_group_candidate"]
    review = [item for item in candidates_list if item["category_guess"] == "needs_review"]
    unresolved_structured = [item for item in structured_list if item["resolved_id"] is None]

    return {
        "schema_version": 2,
        "generated_by": "tools/build_character_census.py",
        "review_policy": {
            "heuristic_names_are_not_runtime_characters": True,
            "unknown_or_minor_age_default": "no_fanservice",
            "promotion_requires": ["identity_card", "story_evidence", "alias_review", "age_review"],
        },
        "source_files": [
            str(path.relative_to(ROOT)).replace("\\", "/")
            for path in JSON_SOURCES
            if path.exists()
        ]
        + ([str(CPP_SOURCE.relative_to(ROOT)).replace("\\", "/")] if CPP_SOURCE.exists() else []),
        "summary": {
            "registered_characters": len(character_ids),
            "registered_groups": len(group_ids),
            "combat_asset_ids": len(combat_ids),
            "json_and_cpp_strings_scanned": scanned_strings,
            "unique_structured_values": len(structured_list),
            "unresolved_structured_values": len(unresolved_structured),
            "registered_character_reference_hits": sum(existing_mentions.values()),
            "named_person_candidates": len(named),
            "role_or_group_candidates": len(roles),
            "other_candidates_needing_review": len(review),
            "all_unregistered_candidates": len(candidates_list),
        },
        "registered_reference_hits": dict(sorted(existing_mentions.items())),
        "structured_references": structured_list,
        "candidates": candidates_list,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=GENERATED_DIR / "character_census_v2.json",
        help="generated review report path",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail if source scanning finds unresolved structured values",
    )
    args = parser.parse_args()
    report = build()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    summary = report["summary"]
    print(
        "CHARACTER CENSUS "
        f"registered={summary['registered_characters']} "
        f"combat_ids={summary['combat_asset_ids']} "
        f"strings={summary['json_and_cpp_strings_scanned']} "
        f"structured={summary['unique_structured_values']} "
        f"unresolved_structured={summary['unresolved_structured_values']} "
        f"named_candidates={summary['named_person_candidates']} "
        f"role_candidates={summary['role_or_group_candidates']} "
        f"other_candidates={summary['other_candidates_needing_review']}"
    )
    for item in report["candidates"]:
        print(
            f"CANDIDATE {item['name']}\t{item['category_guess']}\t"
            f"evidence={item['evidence_count']}\tconfidence={item['max_confidence']:.2f}\t"
            f"sources={','.join(item['sources'])}"
        )
    if args.check and summary["unresolved_structured_values"]:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
