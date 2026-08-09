#!/usr/bin/env python3
"""Hard quality and structure gates for the six playable reincarnation novels."""

from __future__ import annotations

import json
import argparse
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
CHRONICLE_DIR = ROOT / "godot" / "data" / "chronicles"
CHARACTER_ART_PATH = ROOT / "godot" / "data" / "character_art_v1.json"
VOLUMES = {
    "classical": "classical_v1.json",
    "steam": "steam_v1.json",
    "star_network": "star_network_v1.json",
    "wasteland": "wasteland_v1.json",
    "final_age": "final_age_v1.json",
    "immortal_dynasty": "immortal_dynasty_v1.json",
}

MIN_TOTAL_CJK = 500_000
MIN_VOLUME_CJK = 85_000
TARGET_TOTAL_CJK = 660_000
TARGET_VOLUME_CJK = 110_000
MIN_PLAYABLE_ROUTE_CJK = 85_000
TARGET_PLAYABLE_ROUTE_CJK = 110_000
MIN_CHAPTERS = 24
MIN_DESCRIPTION_CJK = 2_400
MIN_OUTCOME_CJK = 70

CJK_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]")
SPACE_RE = re.compile(r"\s+")
SENTENCE_SPLIT_RE = re.compile(r"[。！？!?；;\n]+")
DIALOGUE_RE = re.compile(r"[“「『].+?[”」』]")

OPAQUE_PHRASES = (
    "命运的齿轮",
    "仿佛在诉说着",
    "空气中弥漫着一种",
    "古老而神秘的气息",
    "难以言喻的感觉",
    "说不清道不明",
    "某种不可名状",
    "这一刻时间仿佛",
    "这一刻，时间仿佛",
    "不由得心头一震",
    "故事才刚刚开始",
    "冥冥之中自有安排",
)
STYLE_TERM_LIMITS = {
    "不是": 32,
    "而是": 28,
    "第一次": 20,
    "终于": 20,
    "从此": 14,
    "真正": 18,
    "仿佛": 12,
    "似乎": 12,
    "某种": 10,
    "悄然": 8,
    "不由": 4,
    "这一刻": 6,
    "没有立刻": 12,
    "必须": 80,
    "需要": 70,
    "只能": 60,
    "这意味着": 6,
    "问题在于": 5,
    "更重要的是": 4,
}
CAUSE_MARKERS = (
    "因为", "所以", "于是", "随后", "等到", "先", "再", "才", "却", "当天", "次日",
    "天亮", "入夜", "午后", "半个时辰", "一刻钟", "三日", "七日", "当晚", "翌日",
)
INJURY_MARKERS = (
    "伤", "血", "痛", "裂", "灼", "折", "毒", "创", "断", "烧", "冻", "眩", "麻",
    "骨", "经脉", "皮肉", "气血", "失去知觉",
)
RESOURCE_LABELS = {
    "spirit_stones": ("灵石",),
    "pills": ("丹药", "丹丸", "药丸", "灵丹"),
}
RESOURCE_GAIN_MARKERS = (
    "获", "收", "酬", "赏", "返", "退回", "追回", "卖", "领到", "分得", "交给你", "付给你",
)
RESOURCE_SPEND_MARKERS = (
    "付", "花", "买", "雇", "租", "垫", "交出", "投入", "赔", "耗", "拿出", "凑出", "兑",
)
PERSISTENT_EFFECT_FIELDS = (
    "relationship_deltas",
    "faction_deltas",
    "flags_add",
    "flags_remove",
    "promises_add",
    "promises_resolve",
    "promises_break",
    "debts_add",
    "debts_resolve",
    "debts_forgive",
    "delayed_echoes",
    "statuses_add",
    "statuses_remove",
)
PLAYER_DELTA_FIELDS = {
    "hp", "mp", "exp", "spirit_stones", "pills", "reputation", "karma", "enmity",
    "dao_heart", "lifespan",
}
PATH_IDS = {"compassion", "ambition", "defiance", "insight", "creation", "bonds"}
RELATION_FIELDS = {"trust", "respect", "desire", "agency", "coercion", "dependency", "corruption"}


class ChronicleError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise ChronicleError(message)


def read_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        fail(f"missing chronicle file: {path.relative_to(ROOT)}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        fail(f"cannot parse {path.relative_to(ROOT)}: {error}")
    if not isinstance(value, dict):
        fail(f"chronicle root must be an object: {path.relative_to(ROOT)}")
    return value


def strings(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from strings(child)


def cjk_count(value: Any) -> int:
    return sum(len(CJK_RE.findall(text)) for text in strings(value))


def normalized(text: str) -> str:
    return SPACE_RE.sub("", text).strip()


def paragraphs(text: str) -> list[str]:
    return [part.strip() for part in re.split(r"(?:\r?\n){2,}", text) if part.strip()]


def validate_paragraphs(text: str, location: str, minimum_count: int = 1) -> None:
    parts = paragraphs(text)
    if len(parts) < minimum_count:
        fail(f"{location} needs at least {minimum_count} purposeful paragraphs")
    for index, paragraph in enumerate(parts):
        length = cjk_count(paragraph)
        # Short dialogue or a sharp action beat can be deliberate in mature
        # prose. Reject only near-empty fragments; paragraph purpose is then
        # checked in the mandatory human cross-review.
        if length < 8:
            fail(f"{location} paragraph {index + 1} is too short to carry a readable beat")
        if length > 900:
            fail(f"{location} paragraph {index + 1} is too dense; split it at a real scene beat")


def require_text(value: Any, location: str) -> str:
    if not isinstance(value, str) or not value.strip():
        fail(f"{location} must be non-empty text")
    return value.strip()


def require_dict(value: Any, location: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail(f"{location} must be an object")
    return value


def require_list(value: Any, location: str) -> list[Any]:
    if not isinstance(value, list):
        fail(f"{location} must be an array")
    return value


def authored_prose(container: dict[str, Any], field: str, location: str) -> str:
    """Return exact author-written prose, including explicit paragraph blocks."""
    parts = [require_text(container.get(field), f"{location}.{field}")]
    blocks = container.get(f"{field}_blocks", [])
    if blocks:
        for index, block in enumerate(require_list(blocks, f"{location}.{field}_blocks")):
            parts.append(require_text(block, f"{location}.{field}_blocks[{index}]"))
    return "\n\n".join(parts)


def validate_choice(
    choice: dict[str, Any],
    location: str,
    route_ids: set[str],
    chapter_ids: set[str],
    global_ids: set[str],
    allow_missing_target: bool = False,
) -> None:
    choice_id = require_text(choice.get("id"), f"{location}.id")
    if choice_id in global_ids:
        fail(f"duplicate global id: {choice_id}")
    global_ids.add(choice_id)
    text = require_text(choice.get("text"), f"{location}.text")
    outcome = authored_prose(choice, "outcome", location)
    route_id = require_text(choice.get("route_id"), f"{location}.route_id")
    if route_id not in route_ids:
        fail(f"{location} uses unknown route {route_id}")
    if cjk_count(text) < 6:
        fail(f"{location}.text is too vague to represent a meaningful action")
    if cjk_count(outcome) < MIN_OUTCOME_CJK:
        fail(f"{location}.outcome has fewer than {MIN_OUTCOME_CJK} CJK characters")
    validate_paragraphs(outcome, f"{location}.outcome")
    deltas = require_dict(choice.get("deltas"), f"{location}.deltas")
    path_deltas = require_dict(choice.get("path_deltas"), f"{location}.path_deltas")
    for field, amount in deltas.items():
        if str(field) not in PLAYER_DELTA_FIELDS or not isinstance(amount, int) or isinstance(amount, bool):
            fail(f"{location}.deltas contains ineffective player field {field}")
    for path_id, amount in path_deltas.items():
        if str(path_id) not in PATH_IDS or not isinstance(amount, int) or isinstance(amount, bool):
            fail(f"{location}.path_deltas contains ineffective path field {path_id}")
    if not isinstance(choice.get("flags_add", []), list):
        fail(f"{location}.flags_add must be an array")
    if not isinstance(choice.get("relationship_deltas", {}), dict):
        fail(f"{location}.relationship_deltas must be an object")

    if bool(choice.get("terminal", False)):
        if str(choice.get("target_chapter_id", "")).strip():
            fail(f"{location} cannot be terminal and also target another chapter")
    else:
        target = require_text(choice.get("target_chapter_id"), f"{location}.target_chapter_id")
        if target not in chapter_ids and not allow_missing_target:
            fail(f"{location} points to missing chapter {target}")

    for resource_id, labels in RESOURCE_LABELS.items():
        delta = int(deltas.get(resource_id, 0))
        if not delta:
            continue
        if not any(label in outcome for label in labels):
            fail(f"{location} changes {resource_id} without naming it in the outcome")
        markers = RESOURCE_GAIN_MARKERS if delta > 0 else RESOURCE_SPEND_MARKERS
        if not any(marker in outcome for marker in markers):
            direction = "source" if delta > 0 else "use"
            fail(f"{location} changes {resource_id} without explaining its {direction}")
    if int(deltas.get("hp", 0)) < 0 and not any(marker in outcome for marker in INJURY_MARKERS):
        fail(f"{location} loses HP without describing a concrete injury")


def verify_graph(
    volume_id: str,
    entry_id: str,
    chapters: list[dict[str, Any]],
) -> None:
    chapter_ids = {str(chapter["id"]) for chapter in chapters}
    edges: dict[str, set[str]] = defaultdict(set)
    terminal_count = 0
    for chapter in chapters:
        source = str(chapter["id"])
        for choice in chapter["choices"]:
            if bool(choice.get("terminal", False)):
                terminal_count += 1
            else:
                edges[source].add(str(choice["target_chapter_id"]))
    if terminal_count < 3:
        fail(f"{volume_id} needs at least one terminal decision per persistent route")

    reachable: set[str] = set()
    active: set[str] = set()

    def visit(chapter_id: str) -> None:
        if chapter_id in active:
            fail(f"{volume_id} contains a chapter cycle through {chapter_id}")
        if chapter_id in reachable:
            return
        active.add(chapter_id)
        for target in edges.get(chapter_id, set()):
            visit(target)
        active.remove(chapter_id)
        reachable.add(chapter_id)

    visit(entry_id)
    missing = sorted(chapter_ids - reachable)
    if missing:
        fail(f"{volume_id} has unreachable chapters: {', '.join(missing[:8])}")


def verify_repetition(volume_id: str, text_blocks: list[tuple[str, str]]) -> None:
    exact_owners: dict[str, list[str]] = defaultdict(list)
    sentence_owners: dict[str, set[str]] = defaultdict(set)
    window_owners: dict[str, set[str]] = defaultdict(set)
    for owner, raw in text_blocks:
        compact = normalized(raw)
        if len(compact) >= 80:
            exact_owners[compact].append(owner)
        for sentence in SENTENCE_SPLIT_RE.split(raw):
            compact_sentence = normalized(sentence)
            if len(compact_sentence) >= 48:
                sentence_owners[compact_sentence].add(owner)
        if len(compact) >= 96:
            for index in range(0, len(compact) - 63, 24):
                window_owners[compact[index : index + 64]].add(owner)

    exact_duplicates = [(text, owners) for text, owners in exact_owners.items() if len(owners) > 1]
    if exact_duplicates:
        _, owners = exact_duplicates[0]
        fail(f"{volume_id} repeats a long passage in {', '.join(owners[:4])}")
    repeated_sentences = [(text, owners) for text, owners in sentence_owners.items() if len(owners) >= 3]
    if repeated_sentences:
        text, owners = repeated_sentences[0]
        fail(f"{volume_id} repeats the same long sentence across {len(owners)} blocks: {text[:48]}")
    repeated_windows = [(text, owners) for text, owners in window_owners.items() if len(owners) >= 3]
    if repeated_windows:
        text, owners = repeated_windows[0]
        fail(f"{volume_id} contains template-like repeated prose across {len(owners)} blocks: {text[:48]}")


def verify_volume(
    era_id: str,
    filename: str,
    global_ids: set[str],
    draft: bool = False,
) -> tuple[int, int, int, int]:
    data = read_json(CHRONICLE_DIR / filename)
    if int(data.get("schema_version", 0)) != 1:
        fail(f"{filename} has unsupported schema_version")
    if require_text(data.get("era_id"), f"{filename}.era_id") != era_id:
        fail(f"{filename} era_id does not match {era_id}")
    volume_id = require_text(data.get("id"), f"{filename}.id")
    if volume_id in global_ids:
        fail(f"duplicate global id: {volume_id}")
    global_ids.add(volume_id)
    require_text(data.get("name"), f"{filename}.name")
    require_text(data.get("summary"), f"{filename}.summary")
    require_text(data.get("timespan"), f"{filename}.timespan")
    default_chapter_years = data.get("default_chapter_years", 0)
    if not isinstance(default_chapter_years, int) or isinstance(default_chapter_years, bool) or not 0 <= default_chapter_years <= 20:
        fail(f"{filename}.default_chapter_years must be an integer from 0 to 20")
    art = require_dict(data.get("art"), f"{filename}.art")
    art_catalog = read_json(CHARACTER_ART_PATH)
    characters = {
        str(value.get("id", "")): value
        for value in require_list(art_catalog.get("characters"), "character_art_v1.characters")
        if isinstance(value, dict)
    }
    profiles = require_dict(art_catalog.get("motion_profiles"), "character_art_v1.motion_profiles")
    character_id = require_text(art.get("character_id"), f"{filename}.art.character_id")
    if character_id not in characters:
        fail(f"{filename} uses unknown character art identity {character_id}")
    motion_profile = require_text(art.get("motion_profile"), f"{filename}.art.motion_profile")
    if motion_profile not in profiles:
        fail(f"{filename} uses unknown motion profile {motion_profile}")
    for art_field in ("scene", "portrait"):
        resource_path = require_text(art.get(art_field), f"{filename}.art.{art_field}")
        if not resource_path.startswith("res://"):
            fail(f"{filename}.art.{art_field} must use a res:// path")
        disk_path = ROOT / "godot" / resource_path.removeprefix("res://")
        if not disk_path.is_file():
            fail(f"{filename}.art.{art_field} does not exist: {resource_path}")

    route_list = require_list(data.get("route_ids"), f"{filename}.route_ids")
    route_ids = {require_text(value, f"{filename}.route_ids") for value in route_list}
    if len(route_list) != 3 or len(route_ids) != 3:
        fail(f"{filename} must declare exactly three unique persistent routes")
    resolutions = require_dict(data.get("route_resolutions"), f"{filename}.route_resolutions")
    if set(resolutions) != route_ids:
        fail(f"{filename}.route_resolutions must cover exactly its three routes")
    for route_id in route_ids:
        if cjk_count(require_text(resolutions[route_id], f"{filename}.route_resolutions.{route_id}")) < 60:
            fail(f"{filename} resolution for {route_id} is too thin")

    raw_chapters = require_list(data.get("chapters"), f"{filename}.chapters")
    if not draft and len(raw_chapters) < MIN_CHAPTERS:
        fail(f"{filename} has {len(raw_chapters)} chapters; minimum is {MIN_CHAPTERS}")
    chapters: list[dict[str, Any]] = []
    chapter_ids: set[str] = set()
    for index, value in enumerate(raw_chapters):
        chapter = require_dict(value, f"{filename}.chapters[{index}]")
        chapter_id = require_text(chapter.get("id"), f"{filename}.chapters[{index}].id")
        if chapter_id in chapter_ids or chapter_id in global_ids:
            fail(f"duplicate global id: {chapter_id}")
        chapter_ids.add(chapter_id)
        global_ids.add(chapter_id)
        chapters.append(chapter)

    text_blocks: list[tuple[str, str]] = []
    consequence_counts: Counter[str] = Counter()
    for index, chapter in enumerate(chapters):
        chapter_id = str(chapter["id"])
        location = f"{filename}.{chapter_id}"
        title = require_text(chapter.get("title"), f"{location}.title")
        description = authored_prose(chapter, "description", location)
        chapter_years = chapter.get("time_years", default_chapter_years)
        if not isinstance(chapter_years, int) or isinstance(chapter_years, bool) or not 0 <= chapter_years <= 100:
            fail(f"{location}.time_years must be an integer from 0 to 100")
        if cjk_count(description) < MIN_DESCRIPTION_CJK:
            fail(f"{location}.description has fewer than {MIN_DESCRIPTION_CJK} CJK characters")
        validate_paragraphs(description, f"{location}.description", minimum_count=4)
        spoken_lines = [match for match in DIALOGUE_RE.findall(description) if cjk_count(match) >= 8]
        if len(spoken_lines) < 2:
            fail(f"{location}.description needs at least two concrete lines of dialogue")
        if sum(description.count(marker) for marker in CAUSE_MARKERS) < 3:
            fail(f"{location}.description lacks concrete time or causal transitions")
        text_blocks.append((f"{chapter_id}.description", description))
        text_blocks.append((f"{chapter_id}.title", title))

        variants = require_dict(chapter.get("route_variants", {}), f"{location}.route_variants")
        if index == 0 and variants:
            fail(f"{location}.route_variants must be empty before the player has chosen a route")
        if index > 0 and set(variants) != route_ids:
            fail(f"{location}.route_variants must cover exactly the three persistent routes")
        for route_id, variant in variants.items():
            if isinstance(variant, dict):
                variant_text = authored_prose(
                    variant, "description", f"{location}.route_variants.{route_id}"
                )
            else:
                variant_text = require_text(variant, f"{location}.route_variants.{route_id}")
            if cjk_count(variant_text) < 45:
                fail(f"{location}.route_variants.{route_id} is too thin to carry a prior consequence")
            validate_paragraphs(variant_text, f"{location}.route_variants.{route_id}")
            text_blocks.append((f"{chapter_id}.variant.{route_id}", variant_text))

        choices = require_list(chapter.get("choices"), f"{location}.choices")
        if len(choices) != 3:
            fail(f"{location} must offer exactly three choices")
        choice_texts: set[str] = set()
        outcomes: set[str] = set()
        choice_routes: Counter[str] = Counter()
        chapter_has_relationship = False
        chapter_has_persistent_hook = False
        for choice_index, raw_choice in enumerate(choices):
            choice = require_dict(raw_choice, f"{location}.choices[{choice_index}]")
            validate_choice(
                choice,
                f"{location}.choices[{choice_index}]",
                route_ids,
                chapter_ids,
                global_ids,
                allow_missing_target=draft and index == len(chapters) - 1,
            )
            choice_texts.add(normalized(str(choice["text"])))
            outcomes.add(normalized(str(choice["outcome"])))
            choice_routes[str(choice["route_id"])] += 1
            text_blocks.append((f"{chapter_id}.choice.{choice_index}", str(choice["outcome"])))
            relationship_deltas = choice.get("relationship_deltas", {})
            if relationship_deltas:
                chapter_has_relationship = True
                consequence_counts["relationship_choices"] += 1
                for relation_id in require_dict(
                    relationship_deltas, f"{location}.choices[{choice_index}].relationship_deltas"
                ):
                    if str(relation_id) not in characters:
                        fail(f"{location}.choices[{choice_index}] changes unknown relationship {relation_id}")
                    relation_values = require_dict(
                        relationship_deltas[relation_id],
                        f"{location}.choices[{choice_index}].relationship_deltas.{relation_id}",
                    )
                    for field, amount in relation_values.items():
                        if str(field) in {"stance", "consent_state"}:
                            require_text(
                                amount,
                                f"{location}.choices[{choice_index}].relationship_deltas.{relation_id}.{field}",
                            )
                        elif str(field) not in RELATION_FIELDS or not isinstance(amount, int) or isinstance(amount, bool):
                            fail(
                                f"{location}.choices[{choice_index}] uses invalid relationship delta {relation_id}.{field}"
                            )
            if any(bool(choice.get(field)) for field in PERSISTENT_EFFECT_FIELDS):
                chapter_has_persistent_hook = True
                consequence_counts["persistent_choices"] += 1
            for field in ("flags_add", "flags_remove"):
                value = choice.get(field, [])
                if value:
                    consequence_counts[field] += len(require_list(value, f"{location}.{field}"))
            for field in ("promises_add", "debts_add"):
                value = choice.get(field, [])
                if value:
                    records = require_list(value, f"{location}.{field}")
                    consequence_counts[field] += len(records)
                    for record_index, record in enumerate(records):
                        record_value = require_dict(record, f"{location}.{field}[{record_index}]")
                        require_text(record_value.get("id"), f"{location}.{field}[{record_index}].id")
                        require_text(record_value.get("text"), f"{location}.{field}[{record_index}].text")
            echoes = choice.get("delayed_echoes", [])
            if echoes:
                echo_values = require_list(echoes, f"{location}.delayed_echoes")
                consequence_counts["delayed_echoes"] += len(echo_values)
                for echo_index, echo in enumerate(echo_values):
                    echo_value = require_dict(echo, f"{location}.delayed_echoes[{echo_index}]")
                    require_text(echo_value.get("text"), f"{location}.delayed_echoes[{echo_index}].text")
                    if int(echo_value.get("after_chapters", 0)) < 1:
                        fail(f"{location}.delayed_echoes[{echo_index}] needs a positive after_chapters")
        if len(choice_texts) != 3 or len(outcomes) != 3:
            fail(f"{location} contains duplicate actions or outcomes")
        if set(choice_routes) != route_ids or any(count != 1 for count in choice_routes.values()):
            fail(f"{location} must offer one distinct action for each persistent route")
        if not chapter_has_relationship:
            fail(f"{location} has no choice that changes a named relationship")
        if not chapter_has_persistent_hook:
            fail(f"{location} has no choice that leaves a persistent narrative hook")
        if index < len(chapters) - 1:
            expected_target = str(chapters[index + 1]["id"])
            for choice in choices:
                if bool(choice.get("terminal", False)) or str(choice.get("target_chapter_id", "")) != expected_target:
                    fail(f"{location} must advance all routes to the next authored chapter {expected_target}")
        elif not draft and any(not bool(choice.get("terminal", False)) for choice in choices):
            fail(f"{location} is the final chapter and all three routes must reach a real ending")

    if not draft and consequence_counts["relationship_choices"] < len(chapters):
        fail(f"{filename} does not average one relationship-bearing choice per chapter")
    if not draft and consequence_counts["persistent_choices"] < len(chapters) * 2:
        fail(f"{filename} needs persistent consequences on at least two choices per chapter on average")
    if not draft and consequence_counts["flags_add"] < 12:
        fail(f"{filename} needs at least 12 authored state flags for later scenes to answer")
    if not draft and consequence_counts["promises_add"] + consequence_counts["debts_add"] < 8:
        fail(f"{filename} needs at least eight explicit promises or debts across the volume")
    if not draft and consequence_counts["delayed_echoes"] < 8:
        fail(f"{filename} needs at least eight delayed echoes so prior actions return in play")

    entry_id = require_text(data.get("entry_chapter_id"), f"{filename}.entry_chapter_id")
    if entry_id not in chapter_ids:
        fail(f"{filename} entry chapter does not exist: {entry_id}")
    if not draft:
        verify_graph(volume_id, entry_id, chapters)
    verify_repetition(volume_id, text_blocks)

    compact_joined = normalized("\n".join(strings(data)))
    for phrase in OPAQUE_PHRASES:
        if normalized(phrase) in compact_joined:
            fail(f"{filename} contains forbidden opaque stock phrase: {phrase}")
    for term, limit in STYLE_TERM_LIMITS.items():
        count = compact_joined.count(term)
        if count > limit:
            fail(f"{filename} overuses `{term}` ({count} occurrences; limit {limit})")

    volume_cjk = cjk_count(data)
    if not draft and volume_cjk < MIN_VOLUME_CJK:
        fail(f"{filename} has {volume_cjk:,} CJK characters; minimum is {MIN_VOLUME_CJK:,}")
    route_totals: dict[str, int] = {}
    shared_text: list[Any] = [data.get("summary", "")]
    for chapter in chapters:
        shared_text.extend([
            chapter.get("title", ""),
            authored_prose(chapter, "description", f"{filename}.{chapter.get('id', '')}"),
        ])
    for route_id in route_ids:
        route_text: list[Any] = list(shared_text)
        route_text.append(resolutions[route_id])
        for chapter_index, chapter in enumerate(chapters):
            if chapter_index > 0:
                route_text.append((chapter.get("route_variants", {}) or {}).get(route_id, ""))
            route_choice = next(
                choice for choice in chapter["choices"] if str(choice.get("route_id", "")) == route_id
            )
            route_text.extend([
                route_choice.get("text", ""),
                authored_prose(
                    route_choice,
                    "outcome",
                    f"{filename}.{chapter.get('id', '')}.{route_id}",
                ),
            ])
        route_totals[route_id] = cjk_count(route_text)
    shortest_route = min(route_totals.values())
    if not draft and shortest_route < MIN_PLAYABLE_ROUTE_CJK:
        detail = ", ".join(f"{route}={count:,}" for route, count in sorted(route_totals.items()))
        fail(
            f"{filename} has a playable route shorter than {MIN_PLAYABLE_ROUTE_CJK:,} CJK characters: {detail}"
        )
    return volume_cjk, len(chapters), len(chapters) * 3, shortest_route


def verify_inheritance_links() -> None:
    era_order = list(VOLUMES)
    data_by_era = {
        era_id: read_json(CHRONICLE_DIR / filename) for era_id, filename in VOLUMES.items()
    }
    for era_index, era_id in enumerate(era_order):
        previous_era = era_order[(era_index - 1) % len(era_order)]
        previous_routes = {
            str(value) for value in require_list(
                data_by_era[previous_era].get("route_ids"), f"{previous_era}.route_ids"
            )
        }
        variants = require_dict(
            data_by_era[era_id].get("inheritance_variants"),
            f"{VOLUMES[era_id]}.inheritance_variants",
        )
        if set(variants) != previous_routes:
            fail(
                f"{VOLUMES[era_id]}.inheritance_variants must answer all three routes from {previous_era}"
            )
        descriptions: set[str] = set()
        for route_id, raw_variant in variants.items():
            variant = require_dict(
                raw_variant, f"{VOLUMES[era_id]}.inheritance_variants.{route_id}"
            )
            require_text(
                variant.get("title"), f"{VOLUMES[era_id]}.inheritance_variants.{route_id}.title"
            )
            description = authored_prose(
                variant,
                "description",
                f"{VOLUMES[era_id]}.inheritance_variants.{route_id}",
            )
            if cjk_count(description) < 240:
                fail(
                    f"{VOLUMES[era_id]}.inheritance_variants.{route_id} needs a concrete 240+ CJK bridge"
                )
            validate_paragraphs(
                description,
                f"{VOLUMES[era_id]}.inheritance_variants.{route_id}.description",
                minimum_count=2,
            )
            compact = normalized(description)
            if compact in descriptions:
                fail(f"{VOLUMES[era_id]} reuses the same inheritance bridge for multiple prior routes")
            descriptions.add(compact)


def verify() -> None:
    if set(VOLUMES) != {
        "classical", "steam", "star_network", "wasteland", "final_age", "immortal_dynasty"
    }:
        fail("the verifier itself does not cover the six canonical eras")
    global_ids: set[str] = set()
    totals: Counter[str] = Counter()
    reports: list[str] = []
    for era_id, filename in VOLUMES.items():
        volume_cjk, chapters, choices, shortest_route = verify_volume(era_id, filename, global_ids)
        totals["cjk"] += volume_cjk
        totals["chapters"] += chapters
        totals["choices"] += choices
        target_mark = "达11万语料目标" if volume_cjk >= TARGET_VOLUME_CJK else f"语料距11万差{TARGET_VOLUME_CJK - volume_cjk:,}"
        route_mark = "达11万单线目标" if shortest_route >= TARGET_PLAYABLE_ROUTE_CJK else \
            f"最短单线{shortest_route:,}"
        reports.append(
            f"{era_id}={volume_cjk:,}字/{chapters}章/{choices}选择/{target_mark}/{route_mark}"
        )
    verify_inheritance_links()
    if totals["cjk"] < MIN_TOTAL_CJK:
        fail(f"six-volume total is {totals['cjk']:,} CJK characters; minimum is {MIN_TOTAL_CJK:,}")
    print(
        "CHRONICLE_CONTENT_OK: "
        f"{totals['cjk']:,} CJK characters, {totals['chapters']} chapters, "
        f"{totals['choices']} meaningful choices, "
        f"66万目标完成{totals['cjk'] / TARGET_TOTAL_CJK:.1%}; " + "; ".join(reports)
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--draft-volume",
        choices=tuple(VOLUMES),
        help="validate every completed paragraph and choice in one in-progress volume",
    )
    args = parser.parse_args()
    try:
        if args.draft_volume:
            era_id = args.draft_volume
            filename = VOLUMES[era_id]
            volume_cjk, chapters, choices, shortest_route = verify_volume(
                era_id, filename, set(), draft=True
            )
            print(
                "CHRONICLE_DRAFT_OK: "
                f"{era_id}={volume_cjk:,} CJK characters, {chapters} chapters, "
                f"{choices} choices, shortest current route={shortest_route:,} CJK"
            )
        else:
            verify()
    except ChronicleError as error:
        print(f"CHRONICLE_CONTENT_FAILED: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
