#!/usr/bin/env python3
"""Validate pilot dialogue graphs before they are loaded by Godot."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "godot" / "data"
DIALOGUE = DATA / "dialogue"
CHARACTERS = DATA / "characters"
ALLOWED_TYPES = {"line", "choice", "condition", "check", "effect", "combat", "end"}
EFFECT_TYPES = {
    "relation_delta",
    "reputation_delta",
    "karma_delta",
    "set_flag",
    "character_outfit",
    "character_expression",
    "set_variable",
}


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def combat_ids() -> set[str]:
    result: set[str] = set()
    target_path = DATA / "combat_sprite_targets_v1.json"
    if target_path.exists():
        data = load(target_path)
        result.update(data.get("named_characters", {}).keys())
        result.update(item.get("id") for item in data.get("procedural_enemy_targets", []) if isinstance(item, dict))
    event_path = DATA / "events_v014.json"
    if event_path.exists():
        def walk(value: Any) -> None:
            if isinstance(value, dict):
                if isinstance(value.get("encounter"), dict):
                    enemy_id = value["encounter"].get("enemy_id")
                    if isinstance(enemy_id, str):
                        result.add(enemy_id)
                for child in value.values():
                    walk(child)
            elif isinstance(value, list):
                for child in value:
                    walk(child)
        walk(load(event_path))
    return result


def targets(node: dict[str, Any]) -> list[str]:
    result = [str(node[field]) for field in ("next", "if_true", "if_false", "success", "failure") if node.get(field)]
    if node.get("type") == "choice":
        result.extend(str(choice["next"]) for choice in node.get("choices", []) if isinstance(choice, dict) and choice.get("next"))
    if node.get("type") == "combat":
        result.extend(str(target) for target in node.get("return_routes", {}).values() if target)
    return result


def condition_ok(value: Any) -> bool:
    if value is None:
        return True
    if not isinstance(value, dict):
        return False
    op = value.get("op")
    if op in {"all", "any"}:
        return isinstance(value.get("args"), list) and all(condition_ok(child) for child in value["args"])
    if op == "not":
        return condition_ok(value.get("arg"))
    if op in {"flag", "relation", "reputation", "karma", "stat", "variable", "generation"}:
        return isinstance(value.get("operator", "=="), str) and "value" in value
    return False


def main() -> int:
    errors: list[str] = []
    index = load(DIALOGUE / "dialogue_index_v1.json")
    registry = load(CHARACTERS / "character_registry_v2.json")
    character_ids = set(registry.get("characters", {})) | {"narrator", "player"}
    encounter_ids = combat_ids()
    scenes: dict[str, dict[str, Any]] = {}
    for entry in index.get("scenes", []):
        if not isinstance(entry, dict):
            errors.append("invalid index entry")
            continue
        scene_id = str(entry.get("scene_id", ""))
        path_text = str(entry.get("path", ""))
        if not path_text.startswith("res://"):
            errors.append(f"{scene_id}: path must use res://")
            continue
        path = ROOT / "godot" / path_text.removeprefix("res://")
        if not path.exists():
            errors.append(f"{scene_id}: missing scene file")
            continue
        scene = load(path)
        scenes[scene_id] = scene
        if scene.get("scene_id") != scene_id or scene.get("schema_version") != 1:
            errors.append(f"{scene_id}: header mismatch")
        nodes = scene.get("nodes", [])
        ids = {str(node.get("id")) for node in nodes if isinstance(node, dict)}
        if scene.get("entry_node") not in ids:
            errors.append(f"{scene_id}: entry node missing")
        for node in nodes:
            if not isinstance(node, dict):
                errors.append(f"{scene_id}: non-object node")
                continue
            node_id = str(node.get("id", ""))
            node_type = node.get("type")
            if not node_id or node_type not in ALLOWED_TYPES:
                errors.append(f"{scene_id}/{node_id}: invalid node header")
            if node_type == "line" and node.get("speaker_id") not in character_ids:
                errors.append(f"{scene_id}/{node_id}: unknown speaker {node.get('speaker_id')!r}")
            if node_type == "choice":
                if not isinstance(node.get("choices"), list) or not node["choices"]:
                    errors.append(f"{scene_id}/{node_id}: empty choice node")
                for choice in node.get("choices", []):
                    if not isinstance(choice, dict) or not choice.get("id") or not choice.get("next"):
                        errors.append(f"{scene_id}/{node_id}: malformed choice")
                    if isinstance(choice, dict) and not condition_ok(choice.get("condition")):
                        errors.append(f"{scene_id}/{node_id}/{choice.get('id')}: invalid condition")
                    for effect in choice.get("effects", []) if isinstance(choice, dict) else []:
                        if not isinstance(effect, dict) or effect.get("type") not in EFFECT_TYPES:
                            errors.append(f"{scene_id}/{node_id}: invalid choice effect")
            if node_type == "condition" and not condition_ok(node.get("condition")):
                errors.append(f"{scene_id}/{node_id}: invalid condition")
            if node_type == "check":
                check = node.get("check", {})
                if not isinstance(check, dict) or not check.get("check_id") or not node.get("success") or not node.get("failure"):
                    errors.append(f"{scene_id}/{node_id}: malformed check")
            if node_type == "combat" and node.get("encounter_id") not in encounter_ids:
                errors.append(f"{scene_id}/{node_id}: unknown encounter {node.get('encounter_id')!r}")
            for effect in node.get("effects", []):
                if not isinstance(effect, dict) or effect.get("type") not in EFFECT_TYPES:
                    errors.append(f"{scene_id}/{node_id}: invalid node effect")
                elif effect.get("type") in {"relation_delta", "character_outfit", "character_expression"} and effect.get("character_id") not in character_ids:
                    errors.append(f"{scene_id}/{node_id}: effect references unknown character")
            for target in targets(node):
                if target not in ids:
                    errors.append(f"{scene_id}/{node_id}: broken target {target}")
        reachable = set()
        todo = [scene.get("entry_node", "")]
        by_id = {str(node.get("id")): node for node in nodes if isinstance(node, dict)}
        while todo:
            current = todo.pop()
            if current in reachable or current not in by_id:
                continue
            reachable.add(current)
            todo.extend(targets(by_id[current]))
        if reachable != ids:
            errors.append(f"{scene_id}: unreachable nodes {sorted(ids - reachable)}")

    required_shapes = {
        "qingheng_first_meeting": {"choice", "effect"},
        "xuanheng_first_inquiry": {"condition", "check"},
        "shuangya_first_intercept": {"combat"},
    "lu_xiao_return_tide_rescue": {"choice", "effect"},
    "wen_zhaoye_dry_tide_consent": {"choice", "effect"},
    "song_jian_procedure_boundary": {"choice", "effect"},
    "shan_weqing_memory_boundary": {"choice", "effect"},
    "qin_man_reversible_care": {"choice", "effect"},
    "sang_xian_water_limit": {"choice", "effect"},
    "a_sang_wage_medicine": {"choice", "effect"},
    "du_sanqiu_old_will": {"choice", "effect"},
    "feng_wendi_protocol_pen": {"choice", "effect"},
    "feng_dunjia_name_board": {"choice", "effect"},
    "xiao_he_age_record": {"choice", "effect"},
    "ge_wenji_black_ledger": {"choice", "effect"},
    "lu_hanwei_evidence_chain": {"choice", "effect"},
    "bao_qiyun_filter_price": {"choice", "effect"},
        "zhou_yi_wet_grain": {"choice", "effect"},
        "xiao_man_shift_handoff": {"choice", "effect"},
        "qi_lian_missing_pages": {"choice", "effect"},
        "gu_xianting_narrow_warrant": {"choice", "effect"},
        "qiao_suying_medical_causality": {"choice", "effect"},
        "du_hengqiu_timed_ruling": {"choice", "effect"},
        "liang_zhen_emergency_authority": {"choice", "effect"},
        "mei_lan_clinic_bandwidth": {"choice", "effect"},
        "bai_yao_triage_priority": {"choice", "effect"},
        "xu_dongsuo_piece_rate": {"choice", "effect"},
        "xu_weitang_informed_choice": {"choice", "effect"},
        "lu_ling_family_boundary": {"choice", "effect"},
        "gu_chenbi_covenant_boundary": {"choice", "effect"},
        "lu_shifu_rescue_rule": {"choice", "effect"},
        "a_lu_signal_triage": {"choice", "effect"},
        "tang_kui_child_shelter": {"choice", "effect"},
        "chen_yusuo_wage_care": {"choice", "effect"},
        "meng_duan_injury_wage": {"choice", "effect"},
        "ge_xiulin_data_repair": {"choice", "effect"},
        "gao_sui_legacy_choice": {"choice", "effect"},
        "du_yong_identity_covenant": {"choice", "effect"},
        "huang_ji_maintenance_wage": {"choice", "effect"},
        "luo_wantang_shift_rule": {"choice", "effect"},
        "shan_qiuhe_safety_authority": {"choice", "effect"},
        "bo_li_defense_signal": {"choice", "effect"},
        "tao_sao_flood_compensation": {"choice", "effect"},
        "shen_yanqiu_migration_terms": {"choice", "effect"},
        "zhu_yao_witness_boundary": {"choice", "effect"},
        "jian_tiezhi_drilling_terms": {"choice", "effect"},
        "wen_yin_seed_consent": {"choice", "effect"},
        "a_luo_voice_rights": {"choice", "effect"},
        "ge_sui_gate_duty": {"choice", "effect"},
        "yu_he_heat_wage": {"choice", "effect"},
        "zhou_lan_care_consent": {"choice", "effect"},
        "liang_zhi_wage_boundary": {"choice", "effect"},
        "shao_hongli_ration_debt": {"choice", "effect"},
        "cen_ya_family_memory": {"choice", "effect"},
        "fang_xiaoman_child_welfare": {"choice", "effect"},
        "jiao_wenwei_child_consent": {"choice", "effect"},
        "yi_chenshuang_care_review": {"choice", "effect"},
        "gu_shuying_independent_choice": {"choice", "effect"},
        "shentu_jingjian_resource_terms": {"choice", "effect"},
        "zhu_zhen_gate_responsibility": {"choice", "effect"},
        "wen_zhaolan_evidence_boundary": {"choice", "effect"},
        "cheng_yanhui_shift_boundary": {"choice", "effect"},
        "lu_liao_midwife_ethic": {"choice", "effect"},
        "mu_lianchou_trade_accountability": {"choice", "effect"},
        "yu_baidi_listening_work": {"choice", "effect"},
        "ruan_tongchen_due_process": {"choice", "effect"},
        "zhou_daiping_filter_witness": {"choice", "effect"},
        "tao_xihuai_runner_boundary": {"choice", "effect"},
        "yin_di_medical_boundary": {"choice", "effect"},
        "luo_jin_hearing_boundary": {"choice", "effect"},
        "ying_chaojian_accountability": {"choice", "effect"},
        "zhang_he_archive_boundary": {"choice", "effect"},
        "liu_heting_wage_boundary": {"choice", "effect"},
        "liu_hesheng_identity_boundary": {"choice", "effect"},
        "luo_suzhi_housing_boundary": {"choice", "effect"},
        "duan_qiuhe_proxy_boundary": {"choice", "effect"},
        "lu_hai_shan_care_boundary": {"choice", "effect"},
        "xue_cunyan_slow_consent": {"choice", "effect"},
        "he_qie_pulp_room_boundary": {"choice", "effect"},
        "ruan_he_pool_boundary": {"choice", "effect"},
        "xie_lu_medical_entry": {"choice", "effect"},
        "tao_xi_identity_touch": {"choice", "effect"},
        "wen_tao_scope_boundary": {"choice", "effect"},
        "yu_qing_shift_boundary": {"choice", "effect"},
        "qu_he_shared_relic": {"choice", "effect"},
        "liang_du_conflict_permit": {"choice", "effect"},
        "lu_he_natural_person": {"choice", "effect"},
        "meng_die_archive_scope": {"choice", "effect"},
        "ji_shuangquan_stop_rule": {"choice", "effect"},
    }
    for scene_id, expected in required_shapes.items():
        actual = {node.get("type") for node in scenes.get(scene_id, {}).get("nodes", []) if isinstance(node, dict)}
        if not expected.issubset(actual):
            errors.append(f"{scene_id}: missing pilot node types {sorted(expected - actual)}")

    print("DIALOGUE GRAPH", "PASS" if not errors else "FAIL")
    print(f"SCENES {len(scenes)}")
    print(f"BROKEN NODES {sum('broken target' in error for error in errors)}")
    print(f"ERRORS {len(errors)}")
    for error in errors:
        print(f"ERROR {error}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
