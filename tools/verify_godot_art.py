# -*- coding: utf-8 -*-
"""Validate the self-contained art inventory for the Godot main edition."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import struct


ROOT = Path(__file__).resolve().parents[1]
ART_ROOT = ROOT / "godot" / "art"
MANIFEST = ART_ROOT / "art_manifest.json"
CHARACTER_ART = ROOT / "godot" / "data" / "character_art_v1.json"
EVENTS = ROOT / "godot" / "data" / "events_v014.json"
STORY_ARCS = ROOT / "godot" / "data" / "story_arcs_v1.json"
IMAGE_SUFFIXES = {
    ".bmp",
    ".gif",
    ".jpeg",
    ".jpg",
    ".png",
    ".svg",
    ".webp",
}
SUPPORTED_SOURCE_TYPES = {"generated", "curated"}
SUPPORTED_RELEASE_STATUSES = {
    "approved",
    "identity_anchor_required",
    "dedicated_anchor_required",
    "style_alignment_required",
    "gender_alignment_required",
    "storyboard_required",
}
REQUIRED_NARRATIVE_ROLES = {"male_protagonist", "female_lead", "primary_antagonist"}
OPEN_REGIONAL_POLICY = "open_regional_palette"
# Audit probes only: catch regional labels accidentally used as blanket negatives.
REGIONAL_LABEL_GUARD_TOKENS = (
    "日式",
    "日系",
    "和风",
    "和式",
    "日本",
    "韩式",
    "韩系",
    "韩国",
    "日韩",
    "日漫",
    "韩漫",
    "japanese",
    "korean",
    "anime",
    "manga",
)
RIG_LAYER_IDS = {"hair_back", "hair_front", "tassel_or_ribbon", "outer_cloth", "local_fx"}
REGIONAL_NARRATIVE_ANCHORS = {
    "ning_zhaoxue": "海雾关",
    "chi_yaoqing": "西域商道",
    "wen_xingdu": "东南海域",
    "han_xuansu": "高原与南亚",
}
LEAD_VISUAL_CONTRACTS = {
    "protagonist": {
        "style_profile": "legacy_xianxia_cg_lead_v1",
        "reference_portrait": "res://art/portraits/protagonist_hooded_close.jpg",
        "reference_sha256": "78323d185fbe99fbe29579a028e2b486a316e190b26d6a4d8d46995f02e75133",
        "face_visibility": "hood_conceals_eyes",
        "must_keep": {
            "low_forward_hood",
            "eyes_hidden",
            "three_quarter_side_or_back_silhouette",
            "black_teal_brocade_cloak",
            "deep_teal_tassels",
            "black_white_reincarnation_jade",
        },
    },
    "jiang_zhaoxue": {
        "style_profile": "legacy_xianxia_cg_lead_v1",
        "reference_portrait": "res://art/portraits/qingyun_sword_heroine.jpg",
        "reference_sha256": "9e845ad2f1e6e6a480823471e02ac3285407c70483616736ba7c1a058d724728",
        "face_visibility": "visible",
        "must_keep": {
            "young_beautiful_adult_identity",
            "long_blue_black_hair",
            "silver_blue_hair_ornaments",
            "small_cyan_forehead_ornament",
            "jade_white_ice_blue_sword_dress",
            "ornate_silver_blue_sword",
        },
    },
}
INTENT_ASSETS = {
    "scenes/lantern_river_spirit_bazaar.png",
    "scenes/void_threshold_temple.png",
}
JPEG_SOF_MARKERS = {
    0xC0,
    0xC1,
    0xC2,
    0xC3,
    0xC5,
    0xC6,
    0xC7,
    0xC9,
    0xCA,
    0xCB,
    0xCD,
    0xCE,
    0xCF,
}


def png_dimensions(payload: bytes) -> tuple[int, int]:
    if payload[:8] != b"\x89PNG\r\n\x1a\n" or payload[12:16] != b"IHDR":
        raise RuntimeError("invalid PNG header")
    return struct.unpack(">II", payload[16:24])


def jpeg_dimensions(payload: bytes) -> tuple[int, int]:
    if payload[:2] != b"\xff\xd8":
        raise RuntimeError("invalid JPEG header")

    offset = 2
    while offset < len(payload):
        if payload[offset] != 0xFF:
            raise RuntimeError("invalid JPEG marker stream")
        while offset < len(payload) and payload[offset] == 0xFF:
            offset += 1
        if offset >= len(payload):
            break

        marker = payload[offset]
        offset += 1
        if marker in {0x01, 0xD8, 0xD9} or 0xD0 <= marker <= 0xD7:
            continue
        if offset + 2 > len(payload):
            break

        segment_length = struct.unpack(">H", payload[offset : offset + 2])[0]
        if segment_length < 2 or offset + segment_length > len(payload):
            raise RuntimeError("invalid JPEG segment length")
        if marker in JPEG_SOF_MARKERS:
            if segment_length < 7:
                raise RuntimeError("invalid JPEG frame header")
            height, width = struct.unpack(">HH", payload[offset + 3 : offset + 7])
            return width, height
        if marker == 0xDA:
            break
        offset += segment_length

    raise RuntimeError("JPEG dimensions were not found")


def image_dimensions(payload: bytes, suffix: str) -> tuple[int, int]:
    if suffix == ".png":
        return png_dimensions(payload)
    if suffix in {".jpg", ".jpeg"}:
        return jpeg_dimensions(payload)
    raise RuntimeError(f"dimension reader does not support {suffix}")


def png_has_alpha(payload: bytes) -> bool:
    if payload[:8] != b"\x89PNG\r\n\x1a\n" or payload[12:16] != b"IHDR":
        return False
    # PNG IHDR byte 25 is the color type; 4 and 6 carry an alpha channel.
    return len(payload) > 25 and payload[25] in (4, 6)


def nonempty_text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def runtime_art_path(path: object) -> str:
    if not isinstance(path, str) or not path.startswith("res://art/"):
        raise RuntimeError(f"invalid runtime art path: {path!r}")
    return path.removeprefix("res://art/")


def validate_character_art(entries: dict[str, dict[str, object]], require_release: bool) -> list[str]:
    catalog = json.loads(CHARACTER_ART.read_text(encoding="utf-8"))
    if catalog.get("schema_version") != 1:
        raise RuntimeError("unexpected character art schema version")
    art_direction = catalog.get("art_direction")
    if not isinstance(art_direction, dict):
        raise RuntimeError("character art catalog has no art direction contract")
    regional_influences = art_direction.get("regional_influences")
    if (
        not isinstance(regional_influences, dict)
        or regional_influences.get("policy") != OPEN_REGIONAL_POLICY
        or not nonempty_text(regional_influences.get("statement"))
        or not nonempty_text(regional_influences.get("rejection_basis"))
    ):
        raise RuntimeError("character art catalog has no open regional-influence policy")
    forbidden = art_direction.get("forbidden")
    if not isinstance(forbidden, list) or not all(nonempty_text(value) for value in forbidden):
        raise RuntimeError("character art forbidden rules must be a non-empty text list")
    forbidden_text = "\n".join(str(value) for value in forbidden)
    forbidden_text_folded = forbidden_text.casefold()
    regional_label_violations = [
        token for token in REGIONAL_LABEL_GUARD_TOKENS if token.casefold() in forbidden_text_folded
    ]
    if regional_label_violations:
        raise RuntimeError(
            "character art rules use regional labels as blanket negatives: "
            + ", ".join(regional_label_violations)
        )
    profiles = catalog.get("motion_profiles")
    if not isinstance(profiles, dict) or not profiles:
        raise RuntimeError("character art catalog has no motion profiles")

    characters = catalog.get("characters")
    if not isinstance(characters, list) or not characters:
        raise RuntimeError("character art catalog has no characters")
    identities: dict[str, dict[str, object]] = {}
    alias_owners: dict[str, str] = {}
    approved_portraits: dict[str, str] = {}
    replacement_targets: dict[str, str] = {}
    roles: set[str] = set()
    blockers: list[str] = []
    for character in characters:
        if not isinstance(character, dict):
            raise RuntimeError("invalid character art entry")
        character_id = character.get("id")
        role = character.get("narrative_role")
        status = character.get("release_status")
        profile_id = character.get("motion_profile")
        if not nonempty_text(character_id) or character_id in identities:
            raise RuntimeError(f"invalid or duplicate character id: {character_id!r}")
        if not nonempty_text(role) or not nonempty_text(character.get("display_name")):
            raise RuntimeError(f"incomplete character identity: {character_id}")
        if status not in SUPPORTED_RELEASE_STATUSES:
            raise RuntimeError(f"invalid release status for {character_id}: {status!r}")
        if profile_id not in profiles:
            raise RuntimeError(f"unknown motion profile for {character_id}: {profile_id!r}")
        if not nonempty_text(character.get("visual_signature")):
            raise RuntimeError(f"missing visual signature for {character_id}")
        regional_anchor = REGIONAL_NARRATIVE_ANCHORS.get(str(character_id))
        if regional_anchor is not None and (
            not nonempty_text(character.get("regional_influence_note"))
            or regional_anchor not in str(character.get("visual_signature", ""))
        ):
            raise RuntimeError(f"missing regional narrative rationale for {character_id}")
        expected_contract = LEAD_VISUAL_CONTRACTS.get(str(character_id))
        if expected_contract is not None:
            reference_portrait = character.get("reference_portrait")
            reference_sha256 = character.get("reference_sha256")
            visual_contract = character.get("visual_contract")
            if (
                character.get("style_profile") != expected_contract["style_profile"]
                or reference_portrait != expected_contract["reference_portrait"]
                or reference_sha256 != expected_contract["reference_sha256"]
                or not isinstance(visual_contract, dict)
                or visual_contract.get("face_visibility") != expected_contract["face_visibility"]
            ):
                raise RuntimeError(f"lead visual contract drifted for {character_id}")
            required_features = visual_contract.get("must_keep")
            rejected_features = visual_contract.get("must_avoid")
            if (
                not isinstance(required_features, list)
                or not expected_contract["must_keep"].issubset(set(required_features))
                or not isinstance(rejected_features, list)
                or not rejected_features
            ):
                raise RuntimeError(f"lead visual requirements are incomplete for {character_id}")
            reference_path = runtime_art_path(reference_portrait)
            reference_entry = entries.get(reference_path)
            if (
                not isinstance(reference_entry, dict)
                or reference_entry.get("sha256") != reference_sha256
            ):
                raise RuntimeError(f"lead visual reference is missing or changed for {character_id}")
            rig_contract = character.get("rig_contract")
            if not isinstance(rig_contract, dict):
                raise RuntimeError(f"missing rig contract for {character_id}")
            canvas_size = rig_contract.get("canvas_size")
            wind_axis = rig_contract.get("wind_axis")
            locked_regions = rig_contract.get("locked_regions")
            allowed_layers = rig_contract.get("allowed_layers")
            if (
                not isinstance(canvas_size, list)
                or len(canvas_size) != 2
                or tuple(int(value) for value in canvas_size) != (1024, 1536)
                or not isinstance(wind_axis, list)
                or len(wind_axis) != 2
                or not isinstance(locked_regions, list)
                or not locked_regions
                or not isinstance(allowed_layers, list)
                or not set(str(value) for value in allowed_layers).issubset(RIG_LAYER_IDS)
                or rig_contract.get("layering_rule") != "same_source_same_canvas_rgba_only"
            ):
                raise RuntimeError(f"invalid rig contract for {character_id}")
            layers = character.get("layers")
            if not isinstance(layers, list):
                raise RuntimeError(f"rig layers must be a list for {character_id}")
            seen_layer_ids: set[str] = set()
            current_runtime_path = runtime_art_path(character.get("current_portrait"))
            for layer in layers:
                if not isinstance(layer, dict):
                    raise RuntimeError(f"invalid rig layer for {character_id}")
                layer_id = str(layer.get("id", ""))
                layer_runtime_path = runtime_art_path(layer.get("path"))
                if (
                    layer_id not in RIG_LAYER_IDS
                    or layer_id in seen_layer_ids
                    or layer_id not in set(str(value) for value in allowed_layers)
                    or not layer_runtime_path.startswith("portraits/layers/")
                    or not layer_runtime_path.endswith(".png")
                    or layer_runtime_path not in entries
                ):
                    raise RuntimeError(f"invalid or unregistered rig layer for {character_id}: {layer_id}")
                layer_entry = entries[layer_runtime_path]
                if (
                    layer_entry.get("source_type") != "generated"
                    or (int(layer_entry.get("width", -1)), int(layer_entry.get("height", -1))) != (1024, 1536)
                    or layer_entry.get("derived_from") != current_runtime_path
                ):
                    raise RuntimeError(f"rig layer provenance drifted for {character_id}: {layer_id}")
                layer_payload = (ART_ROOT / Path(*PurePosixPath(layer_runtime_path).parts)).read_bytes()
                if not png_has_alpha(layer_payload):
                    raise RuntimeError(f"rig layer must be RGBA/alpha PNG for {character_id}: {layer_id}")
                seen_layer_ids.add(layer_id)
        roles.add(str(role))
        identities[str(character_id)] = character
        portrait = character.get("current_portrait")
        if nonempty_text(portrait):
            portrait_path = runtime_art_path(portrait)
            if portrait_path not in entries or not portrait_path.startswith("portraits/"):
                raise RuntimeError(f"unregistered current portrait for {character_id}: {portrait}")
            if status == "approved":
                previous_owner = approved_portraits.get(portrait_path)
                if previous_owner is not None:
                    raise RuntimeError(
                        f"approved identities share one portrait: {previous_owner}, {character_id}"
                    )
                approved_portraits[portrait_path] = str(character_id)
        elif status == "approved":
            raise RuntimeError(f"approved character has no portrait: {character_id}")
        if status != "approved":
            replacement_target = character.get("replacement_target")
            if (
                not nonempty_text(replacement_target)
                or not str(replacement_target).startswith("res://art/portraits/")
                or not str(replacement_target).endswith(".png")
                or replacement_target == portrait
                or replacement_target in replacement_targets
            ):
                raise RuntimeError(f"invalid replacement target for {character_id}")
            replacement_targets[str(replacement_target)] = str(character_id)
            blockers.append(f"{character_id}:{status}")
        aliases = character.get("aliases", [])
        if not isinstance(aliases, list):
            raise RuntimeError(f"aliases must be a list: {character_id}")
        for alias in aliases:
            if not nonempty_text(alias) or alias in alias_owners:
                raise RuntimeError(f"duplicate or empty character alias: {alias!r}")
            alias_owners[str(alias)] = str(character_id)

    missing_roles = sorted(REQUIRED_NARRATIVE_ROLES - roles)
    if missing_roles:
        raise RuntimeError("character art catalog is missing roles: " + ", ".join(missing_roles))

    storyboard_blockers: list[str] = []
    storyboards = catalog.get("storyboards")
    if not isinstance(storyboards, list) or not storyboards:
        raise RuntimeError("character art catalog has no storyboard plan")
    storyboard_ids: set[str] = set()
    for storyboard in storyboards:
        if not isinstance(storyboard, dict):
            raise RuntimeError("invalid storyboard art plan")
        storyboard_id = storyboard.get("id")
        status = storyboard.get("status")
        target = storyboard.get("target")
        if (
            not nonempty_text(storyboard_id)
            or storyboard_id in storyboard_ids
            or status not in {"asset_required", "approved"}
            or not nonempty_text(storyboard.get("brief_section"))
            or not isinstance(target, str)
            or not target.startswith("res://art/scenes/")
            or not target.endswith(".png")
            or storyboard.get("portrait_mode") != "scene_only"
            or storyboard.get("motion_profile") not in profiles
        ):
            raise RuntimeError(f"invalid storyboard art plan: {storyboard_id!r}")
        character_ids = storyboard.get("character_ids")
        if (
            not isinstance(character_ids, list)
            or not character_ids
            or any(character_id not in identities for character_id in character_ids)
        ):
            raise RuntimeError(f"invalid storyboard identities: {storyboard_id}")
        storyboard_ids.add(str(storyboard_id))
        if status == "approved" and runtime_art_path(target) not in entries:
            raise RuntimeError(f"approved storyboard is not registered: {storyboard_id}")
        if status != "approved":
            storyboard_blockers.append(f"storyboard:{storyboard_id}")

    def validate_binding(binding: dict[str, object], context: str) -> None:
        character_id = binding.get("character_id")
        profile_id = binding.get("motion_profile")
        portrait_mode = binding.get("portrait_mode", "focus")
        if character_id not in identities:
            raise RuntimeError(f"unknown character id in {context}: {character_id!r}")
        if profile_id not in profiles:
            raise RuntimeError(f"unknown motion profile in {context}: {profile_id!r}")
        scene_path = runtime_art_path(binding.get("scene"))
        if portrait_mode not in {"focus", "scene_only"}:
            raise RuntimeError(f"invalid portrait mode in {context}: {portrait_mode!r}")
        if scene_path not in entries:
            raise RuntimeError(f"unregistered art binding in {context}")
        if portrait_mode == "focus":
            portrait_path = runtime_art_path(binding.get("portrait"))
            if portrait_path not in entries:
                raise RuntimeError(f"unregistered portrait binding in {context}")
            current_portrait = identities[str(character_id)].get("current_portrait")
            if nonempty_text(current_portrait) and portrait_path != runtime_art_path(current_portrait):
                raise RuntimeError(f"portrait does not match identity in {context}: {character_id}")

    events = json.loads(EVENTS.read_text(encoding="utf-8"))
    if not isinstance(events, list):
        raise RuntimeError("event catalog must be a list")
    for event in events:
        if not isinstance(event, dict):
            raise RuntimeError("invalid event art binding")
        validate_binding(event, f"event {event.get('id', '<unknown>')}")

    story = json.loads(STORY_ARCS.read_text(encoding="utf-8"))
    for arc in story.get("arcs", []):
        if not isinstance(arc, dict):
            raise RuntimeError("invalid story arc art binding")
        validate_binding(arc, f"story arc {arc.get('id', '<unknown>')}")
        for phase in ("main", "echo"):
            for node in arc.get(phase, []):
                if not isinstance(node, dict):
                    raise RuntimeError("invalid story node art binding")
                override = node.get("art", {})
                if not isinstance(override, dict):
                    raise RuntimeError(f"invalid stage art override: {node.get('id', '<unknown>')}")
                merged = {**arc, **override}
                validate_binding(merged, f"story node {node.get('id', '<unknown>')}")

    all_blockers = blockers + storyboard_blockers
    if require_release and all_blockers:
        raise RuntimeError("product art release blocked by: " + ", ".join(all_blockers))
    return all_blockers


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--release",
        action="store_true",
        help="fail when any registered character still needs a product-art replacement",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("manifest_version") != 1:
        raise RuntimeError("unexpected Godot art manifest version")
    if manifest.get("runtime_root") != "res://art":
        raise RuntimeError("Godot art runtime root must be res://art")
    if not nonempty_text(manifest.get("rights_notice")):
        raise RuntimeError("rights notice must not be empty")

    files = manifest.get("files")
    if not isinstance(files, list) or not files:
        raise RuntimeError("Godot art manifest contains no files")

    entries: dict[str, dict[str, object]] = {}
    casefold_paths: set[str] = set()
    for entry in files:
        if not isinstance(entry, dict) or not nonempty_text(entry.get("path")):
            raise RuntimeError("every manifest entry needs a path")
        path_text = str(entry["path"])
        relative = PurePosixPath(path_text)
        if (
            relative.is_absolute()
            or ".." in relative.parts
            or "\\" in path_text
            or str(relative) != path_text
        ):
            raise RuntimeError(f"unsafe or non-canonical art path: {path_text}")
        if path_text in entries or path_text.casefold() in casefold_paths:
            raise RuntimeError(f"duplicate art path: {path_text}")
        entries[path_text] = entry
        casefold_paths.add(path_text.casefold())

    registered_paths = set(entries)
    if list(entries) != sorted(entries):
        raise RuntimeError("manifest files must remain sorted by path")

    actual_paths = {
        path.relative_to(ART_ROOT).as_posix()
        for path in ART_ROOT.rglob("*")
        if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES
    }
    missing = sorted(registered_paths - actual_paths)
    unregistered = sorted(actual_paths - registered_paths)
    if missing:
        raise RuntimeError("missing registered Godot art: " + ", ".join(missing))
    if unregistered:
        raise RuntimeError("unregistered Godot art: " + ", ".join(unregistered))

    source_counts = {source_type: 0 for source_type in SUPPORTED_SOURCE_TYPES}
    for path_text, entry in entries.items():
        source_type = entry.get("source_type")
        if source_type not in SUPPORTED_SOURCE_TYPES:
            raise RuntimeError(f"invalid source_type for {path_text}: {source_type!r}")
        source_counts[str(source_type)] += 1

        eras = entry.get("eras")
        if (
            not isinstance(eras, list)
            or not eras
            or not all(nonempty_text(era) for era in eras)
        ):
            raise RuntimeError(f"eras must be a non-empty text list: {path_text}")
        if not nonempty_text(entry.get("purpose")):
            raise RuntimeError(f"purpose must not be empty: {path_text}")

        path = ART_ROOT.joinpath(*PurePosixPath(path_text).parts)
        payload = path.read_bytes()
        if len(payload) != int(entry.get("bytes", -1)):
            raise RuntimeError(f"byte-size mismatch: {path_text}")
        digest = hashlib.sha256(payload).hexdigest()
        if digest != entry.get("sha256"):
            raise RuntimeError(f"SHA-256 mismatch: {path_text}")
        dimensions = image_dimensions(payload, path.suffix.lower())
        expected_dimensions = (int(entry.get("width", -1)), int(entry.get("height", -1)))
        if dimensions != expected_dimensions:
            raise RuntimeError(
                f"dimension mismatch: {path_text} (actual {dimensions}, expected {expected_dimensions})"
            )

    for path_text in INTENT_ASSETS:
        entry = entries.get(path_text, {})
        intent = entry.get("generation_intent")
        if entry.get("source_type") != "generated":
            raise RuntimeError(f"new render asset must remain generated: {path_text}")
        if not isinstance(intent, dict) or not all(
            nonempty_text(intent.get(field)) for field in ("concept", "mood", "story_use")
        ):
            raise RuntimeError(f"generation intent is incomplete: {path_text}")

    blockers = validate_character_art(entries, args.release)

    print(
        "Godot art verified: "
        f"{len(entries)} registered images, {source_counts['generated']} generated, "
        f"{source_counts['curated']} curated, no missing or unregistered images, "
        f"{len(blockers)} product-art replacement blockers."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
