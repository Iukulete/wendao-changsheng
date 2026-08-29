# -*- coding: utf-8 -*-
"""Build a conservative, reviewable backlog from the character census.

Heuristic names never become runtime IDs here. The output preserves story
evidence and leaves alias, age, identity-card, and art gates explicit so a
single candidate can be promoted without contaminating the character registry.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CENSUS = ROOT / "godot" / "data" / "generated" / "character_census_v2.json"
QUEUE = ROOT / "godot" / "data" / "characters" / "art_production_queue_v2.json"
REGISTRY = ROOT / "godot" / "data" / "characters" / "character_registry_v2.json"
IDENTITY_CARDS = ROOT / "godot" / "data" / "characters" / "identity_cards_v1.json"
OUTPUT = ROOT / "godot" / "data" / "generated" / "character_art_backlog_v2.json"
GENERIC_ROLE_NAMES = {
    "高阶": "只在原文中作为‘高阶修士’泛称出现，没有独立姓名或个体身份",
    "高阶护": "只在运行时 archetype 字符串‘高阶护道’中出现，属于职业/群体标签",
    "许多": "只作为‘许多少年/许多修士’数量词出现，不是个体姓名",
}


def main() -> int:
    census = json.loads(CENSUS.read_text(encoding="utf-8"))
    queue = json.loads(QUEUE.read_text(encoding="utf-8"))
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    identity_cards = json.loads(IDENTITY_CARDS.read_text(encoding="utf-8"))
    queue_by_id = {
        str(item.get("character_id")): item
        for item in queue.get("targets", [])
        if isinstance(item, dict) and item.get("character_id")
    }
    queue_rank_by_card = {
        str(item.get("identity_card_id")): rank
        for rank, item in enumerate(queue.get("targets", []))
        if isinstance(item, dict) and item.get("identity_card_id")
    }
    registry_by_id = registry.get("characters", {})
    cards_by_id = identity_cards.get("cards", {})
    card_id_by_display_name = {
        str(card.get("display_name", "")).strip(): str(card_id)
        for card_id, card in cards_by_id.items()
        if isinstance(card, dict) and str(card.get("display_name", "")).strip()
    }

    candidates: list[dict[str, Any]] = []
    story_review_pool: list[dict[str, Any]] = []
    for candidate in census.get("candidates", []):
        if not isinstance(candidate, dict):
            continue
        candidate_name = str(candidate.get("name", "")).strip()
        category = str(candidate.get("category_guess", "needs_review"))
        classification_note = GENERIC_ROLE_NAMES.get(candidate_name)
        if classification_note:
            category = "role_or_group_candidate"
        confidence = float(candidate.get("max_confidence", 0))
        evidence_count = int(candidate.get("evidence_count", 0))
        if category == "named_person_candidate" and confidence >= 0.68 and evidence_count >= 3:
            triage_state = "art_backlog_candidate"
        elif category == "named_person_candidate":
            triage_state = "needs_identity_evidence_review"
        elif category == "role_or_group_candidate":
            triage_state = "needs_scope_review"
        else:
            triage_state = "needs_semantic_review"
        story_review_pool.append(
            {
                "review_key": f"census:{category}:{candidate_name or len(story_review_pool)}",
                "display_name": candidate_name,
                "category_guess": category,
                "triage_state": triage_state,
                "census_review_state": candidate.get("review_state", "needs_review"),
                "evidence_count": evidence_count,
                "max_confidence": candidate.get("max_confidence"),
                "evidence_kinds": candidate.get("evidence_kinds", []),
                "sources": candidate.get("sources", []),
                "source_paths": candidate.get("source_paths", []),
                "snippets": candidate.get("snippets", [])[:2],
                **({"classification_note": classification_note} if classification_note else {}),
            }
        )
        if category != "named_person_candidate":
            continue
        if confidence < 0.68 or evidence_count < 3:
            continue
        name = candidate_name
        if not name:
            continue
        card_id = card_id_by_display_name.get(name)
        queued = next(
            (
                item
                for item in queue_by_id.values()
                if card_id and item.get("identity_card_id") == card_id
            ),
            None,
        )
        registry_entry = registry_by_id.get(queued.get("character_id")) if queued else None
        master_status = (
            registry_entry.get("assets", {}).get("portrait_master", {}).get("status")
            if isinstance(registry_entry, dict)
            else None
        )
        identity_ready = bool(
            queued
            and isinstance(registry_entry, dict)
            and master_status in {"planned", "missing"}
        )
        waiting_for = queued.get("blocked_by") if identity_ready else None
        candidates.append(
            {
                "review_key": f"id:{queued.get('character_id')}" if identity_ready else f"name:{name}",
                "display_name": name,
                "stable_id_status": "stable_id_ready" if identity_ready else "pending_alias_review",
                "review_state": (
                    "identity_card_ready_waiting_previous_character"
                    if waiting_for
                    else "identity_card_ready_waiting_portrait"
                    if identity_ready
                    else "needs_identity_card"
                ),
                "queue_stage": queued.get("stage") if identity_ready else "identity_card",
                "blocked_by": waiting_for,
                "safety_gate": "no_fanservice_until_age_review",
                "evidence_count": int(candidate.get("evidence_count", 0)),
                "max_confidence": candidate.get("max_confidence"),
                "evidence_kinds": candidate.get("evidence_kinds", []),
                "sources": candidate.get("sources", []),
                "_queue_rank": queue_rank_by_card.get(card_id, 10**6) if identity_ready else 10**6,
                "snippets": candidate.get("snippets", [])[:3],
            }
        )

    # A promoted identity card is deliberately removed from the census's
    # heuristic-candidate list. Keep it visible here until its portrait gate
    # passes, otherwise the next-art queue appears shorter than it really is.
    census_names = {item.get("display_name") for item in candidates}
    for character_id, queued in queue_by_id.items():
        card_id = queued.get("identity_card_id")
        if not card_id or queued.get("stage") not in {"portrait_master", "identity_card"}:
            continue
        card = cards_by_id.get(card_id)
        registry_entry = registry_by_id.get(character_id)
        if not isinstance(card, dict) or not isinstance(registry_entry, dict):
            continue
        master = registry_entry.get("assets", {}).get("portrait_master", {})
        if master.get("status") not in {"planned", "missing"}:
            continue
        display_name = str(card.get("display_name", "")).strip()
        if not display_name or display_name in census_names:
            continue
        waiting_for = queued.get("blocked_by")
        candidates.append(
            {
                "review_key": f"id:{character_id}",
                "display_name": display_name,
                "stable_id_status": "stable_id_ready",
                "review_state": (
                    "identity_card_ready_waiting_previous_character"
                    if waiting_for
                    else "identity_card_ready_waiting_portrait"
                ),
                "queue_stage": queued.get("stage"),
                "blocked_by": waiting_for,
                "safety_gate": "no_fanservice_until_age_review",
                "evidence_count": len(card.get("story_evidence", [])),
                "max_confidence": 1.0,
                "evidence_kinds": ["identity_card", "story_evidence"],
                "sources": card.get("source_refs", []),
                "_queue_rank": queue_rank_by_card.get(card_id, 10**6),
                "snippets": [
                    {"source": "identity_cards_v1.json", "text": evidence}
                    for evidence in card.get("story_evidence", [])[:3]
                ],
            }
        )
        census_names.add(display_name)

    candidates.sort(
        key=lambda item: (
            -float(item.get("max_confidence", 0)),
            -int(item.get("evidence_count", 0)),
            int(item.get("_queue_rank", 10**6)),
            str(item.get("display_name", "")),
        )
    )
    for item in candidates:
        item.pop("_queue_rank", None)
    report = {
        "schema_version": 2,
        "backlog_id": "wendao_character_art_backlog_v2",
        "source_census": "res://data/generated/character_census_v2.json",
        "promotion_policy": [
            "candidate evidence review",
            "alias and stable ID review",
            "age and presentation review",
            "identity card",
            "single-character portrait generation",
            "identity gate",
            "dialogue and combat derivation only after portrait pass",
        ],
        "summary": {
            "high_confidence_named_candidates": len(candidates),
            "already_in_identity_card_stage": sum(
                item["review_state"] != "needs_identity_card" for item in candidates
            ),
            "not_runtime_characters_yet": sum(
                item["stable_id_status"] != "stable_id_ready" for item in candidates
            ),
            "story_review_pool": len(story_review_pool),
            "named_person_review_pool": sum(
                item["category_guess"] == "named_person_candidate" for item in story_review_pool
            ),
            "role_or_group_review_pool": sum(
                item["category_guess"] == "role_or_group_candidate" for item in story_review_pool
            ),
            "other_review_pool": sum(
                item["category_guess"] not in {"named_person_candidate", "role_or_group_candidate"}
                for item in story_review_pool
            ),
        },
        "candidates": candidates,
        "story_review_pool": story_review_pool,
    }
    OUTPUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        "CHARACTER ART BACKLOG",
        f"high_confidence={len(candidates)}",
        f"identity_card_stage={report['summary']['already_in_identity_card_stage']}",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
