import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BACKLOG = ROOT / "godot" / "data" / "generated" / "character_art_backlog_v2.json"


def test_identity_card_targets_are_not_downgraded_to_heuristic_names() -> None:
    report = json.loads(BACKLOG.read_text(encoding="utf-8"))
    by_name = {item["display_name"]: item for item in report["candidates"]}

    assert report["summary"]["already_in_identity_card_stage"] >= 7
    assert by_name["陆绡"]["review_key"] == "id:lu_xiao"
    assert by_name["温照野"]["review_key"] == "id:wen_zhaoye"
    assert by_name["宋鉴"]["review_key"] == "id:song_jian"
    assert by_name["宋鉴"]["review_state"] == "identity_card_ready_waiting_previous_character"
    assert by_name["宋鉴"]["blocked_by"] == "wen_zhaoye"
    assert by_name["单苇青"]["review_key"] == "id:shan_weqing"
    assert by_name["单苇青"]["blocked_by"] == "song_jian"
    assert by_name["秦慢"]["review_key"] == "id:qin_man"
    assert by_name["秦慢"]["blocked_by"] == "shan_weqing"
    assert by_name["桑弦"]["review_key"] == "id:sang_xian"
    assert by_name["桑弦"]["blocked_by"] == "qin_man"
    assert by_name["阿桑"]["review_key"] == "id:a_sang"
    assert by_name["阿桑"]["blocked_by"] == "sang_xian"
    assert "高阶" not in by_name
    assert "白砚秋" not in by_name
    generic = [item for item in report["story_review_pool"] if item["display_name"] == "高阶"]
    assert generic and generic[0]["category_guess"] == "role_or_group_candidate"
    assert "许多" not in by_name
