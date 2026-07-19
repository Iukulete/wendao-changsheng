class_name CharacterArtCatalog
extends RefCounted

const DATA_PATH := "res://data/character_art_v1.json"
const OPEN_REGIONAL_POLICY := "open_regional_palette"
# Audit probes only: reject a regional label if it is mistakenly written as a blanket negative.
const REGIONAL_LABEL_GUARD_TOKENS := [
	"日式", "日系", "和风", "和式", "日本", "韩式", "韩系", "韩国", "日韩",
	"日漫", "韩漫", "japanese", "korean", "anime", "manga"
]
const RIG_LAYER_IDS := ["hair_back", "hair_front", "tassel_or_ribbon", "outer_cloth", "local_fx"]
const REGIONAL_NARRATIVE_ANCHORS := {
	"ning_zhaoxue": "海雾关",
	"chi_yaoqing": "西域商道",
	"wen_xingdu": "东南海域",
	"han_xuansu": "高原与南亚",
}
const LEAD_VISUAL_CONTRACTS := {
	"protagonist": {
		"style_profile": "legacy_xianxia_cg_lead_v1",
		"reference_portrait": "res://art/portraits/protagonist_hooded_close.jpg",
		"face_visibility": "hood_conceals_eyes",
		"must_keep": [
			"low_forward_hood", "eyes_hidden", "three_quarter_side_or_back_silhouette",
			"black_teal_brocade_cloak", "deep_teal_tassels", "black_white_reincarnation_jade"
		]
	},
	"jiang_zhaoxue": {
		"style_profile": "legacy_xianxia_cg_lead_v1",
		"reference_portrait": "res://art/portraits/qingyun_sword_heroine.jpg",
		"face_visibility": "visible",
		"must_keep": [
			"young_beautiful_adult_identity", "long_blue_black_hair", "silver_blue_hair_ornaments",
			"small_cyan_forehead_ornament", "jade_white_ice_blue_sword_dress", "ornate_silver_blue_sword"
		]
	}
}
const RELEASE_STATUSES := [
	"approved",
	"identity_anchor_required",
	"dedicated_anchor_required",
	"style_alignment_required",
	"gender_alignment_required",
	"storyboard_required",
]
const MOTION_FIELDS := [
	"breath_x",
	"breath_y",
	"sway_radians",
	"portrait_parallax_px",
	"scene_parallax_px",
	"scene_overscan_px",
	"drift_px",
	"speed",
]

static var _cache: Dictionary = {}


static func load_catalog() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		_cache = (parsed as Dictionary).duplicate(true)
	return _cache


static func validate_catalog() -> Dictionary:
	var data := load_catalog()
	if int(data.get("schema_version", 0)) != 1:
		return {"ok": false, "code": "unsupported_character_art_schema"}
	var art_direction_value: Variant = data.get("art_direction", {})
	if not art_direction_value is Dictionary:
		return {"ok": false, "code": "missing_art_direction"}
	var art_direction: Dictionary = art_direction_value
	var regional_value: Variant = art_direction.get("regional_influences", {})
	if not regional_value is Dictionary:
		return {"ok": false, "code": "missing_regional_influence_policy"}
	var regional: Dictionary = regional_value
	if str(regional.get("policy", "")) != OPEN_REGIONAL_POLICY or \
			str(regional.get("statement", "")).is_empty() or \
			str(regional.get("rejection_basis", "")).is_empty():
		return {"ok": false, "code": "invalid_regional_influence_policy"}
	var forbidden_value: Variant = art_direction.get("forbidden", [])
	if not forbidden_value is Array or (forbidden_value as Array).is_empty():
		return {"ok": false, "code": "missing_art_direction_rules"}
	var forbidden_text := ""
	for forbidden_rule in (forbidden_value as Array):
		if str(forbidden_rule).is_empty():
			return {"ok": false, "code": "invalid_art_direction_rule"}
		forbidden_text += "\n" + str(forbidden_rule)
	var forbidden_text_folded := forbidden_text.to_lower()
	for regional_token in REGIONAL_LABEL_GUARD_TOKENS:
		if forbidden_text_folded.contains(str(regional_token).to_lower()):
			return {"ok": false, "code": "regional_label_blanket_negative"}
	var profiles_value: Variant = data.get("motion_profiles", {})
	if not profiles_value is Dictionary or (profiles_value as Dictionary).is_empty():
		return {"ok": false, "code": "missing_motion_profiles"}
	var profiles: Dictionary = profiles_value
	for profile_id_value in profiles.keys():
		var profile_id := str(profile_id_value)
		var profile_value: Variant = profiles[profile_id_value]
		if profile_id.is_empty() or not profile_value is Dictionary:
			return {"ok": false, "code": "invalid_motion_profile"}
		var profile: Dictionary = profile_value
		for field in MOTION_FIELDS:
			if not profile.has(field) or not profile[field] is float and not profile[field] is int:
				return {"ok": false, "code": "invalid_motion_profile", "profile_id": profile_id}

	var characters_value: Variant = data.get("characters", [])
	if not characters_value is Array or (characters_value as Array).is_empty():
		return {"ok": false, "code": "missing_character_art"}
	var seen_ids := {}
	var alias_owners := {}
	var replacement_targets := {}
	var release_blockers: Array[String] = []
	for character_value in (characters_value as Array):
		if not character_value is Dictionary:
			return {"ok": false, "code": "invalid_character_art"}
		var character: Dictionary = character_value
		var character_id := str(character.get("id", ""))
		var display_name := str(character.get("display_name", ""))
		var role := str(character.get("narrative_role", ""))
		var status := str(character.get("release_status", ""))
		var profile_id := str(character.get("motion_profile", ""))
		if character_id.is_empty() or seen_ids.has(character_id) or display_name.is_empty() or role.is_empty():
			return {"ok": false, "code": "invalid_character_identity", "character_id": character_id}
		if not RELEASE_STATUSES.has(status) or not profiles.has(profile_id):
			return {"ok": false, "code": "invalid_character_art_status", "character_id": character_id}
		if str(character.get("visual_signature", "")).is_empty() or int(character.get("production_priority", 0)) not in [1, 2, 3]:
			return {"ok": false, "code": "incomplete_character_identity", "character_id": character_id}
		if REGIONAL_NARRATIVE_ANCHORS.has(character_id) and (
				str(character.get("regional_influence_note", "")).is_empty() or
				not str(character.get("visual_signature", "")).contains(
					str(REGIONAL_NARRATIVE_ANCHORS[character_id]))):
			return {"ok": false, "code": "missing_regional_narrative_rationale",
				"character_id": character_id}
		if LEAD_VISUAL_CONTRACTS.has(character_id):
			var expected_contract: Dictionary = LEAD_VISUAL_CONTRACTS[character_id]
			var visual_contract_value: Variant = character.get("visual_contract", {})
			var visual_contract: Dictionary = visual_contract_value if visual_contract_value is Dictionary else {}
			if str(character.get("style_profile", "")) != str(expected_contract.get("style_profile", "")) or \
					str(character.get("reference_portrait", "")) != str(expected_contract.get("reference_portrait", "")) or \
					str(visual_contract.get("face_visibility", "")) != str(expected_contract.get("face_visibility", "")):
				return {"ok": false, "code": "lead_visual_contract_drift", "character_id": character_id}
			var required_features: Variant = visual_contract.get("must_keep", [])
			var rejected_features: Variant = visual_contract.get("must_avoid", [])
			if not required_features is Array or not rejected_features is Array or (rejected_features as Array).is_empty():
				return {"ok": false, "code": "incomplete_lead_visual_contract", "character_id": character_id}
			for feature in (expected_contract.get("must_keep", []) as Array):
				if not (required_features as Array).has(feature):
					return {"ok": false, "code": "incomplete_lead_visual_contract", "character_id": character_id}
			if not ResourceLoader.exists(str(character.get("reference_portrait", ""))):
				return {"ok": false, "code": "missing_lead_visual_reference", "character_id": character_id}
			var rig_value: Variant = character.get("rig_contract", {})
			if not rig_value is Dictionary:
				return {"ok": false, "code": "missing_rig_contract", "character_id": character_id}
			var rig_contract: Dictionary = rig_value
			var canvas_value: Variant = rig_contract.get("canvas_size", [])
			var wind_value: Variant = rig_contract.get("wind_axis", [])
			var locked_value: Variant = rig_contract.get("locked_regions", [])
			var allowed_value: Variant = rig_contract.get("allowed_layers", [])
			if not canvas_value is Array or (canvas_value as Array).size() != 2 or \
					float((canvas_value as Array)[0]) <= 0.0 or float((canvas_value as Array)[1]) <= 0.0 or \
					not wind_value is Array or (wind_value as Array).size() != 2 or \
					not locked_value is Array or (locked_value as Array).is_empty() or \
					not allowed_value is Array:
				return {"ok": false, "code": "invalid_rig_contract", "character_id": character_id}
			if str(rig_contract.get("layering_rule", "")) != "same_source_same_canvas_rgba_only":
				return {"ok": false, "code": "invalid_rig_layering_rule", "character_id": character_id}
			for layer_id_value in (allowed_value as Array):
				if not RIG_LAYER_IDS.has(str(layer_id_value)):
					return {"ok": false, "code": "invalid_rig_layer_id", "character_id": character_id}
			var layers_value: Variant = character.get("layers", [])
			if not layers_value is Array:
				return {"ok": false, "code": "invalid_rig_layers", "character_id": character_id}
			var seen_layer_ids := {}
			for layer_value in (layers_value as Array):
				if not layer_value is Dictionary:
					return {"ok": false, "code": "invalid_rig_layer", "character_id": character_id}
				var layer: Dictionary = layer_value
				var layer_id := str(layer.get("id", ""))
				var layer_path := str(layer.get("path", ""))
				if not RIG_LAYER_IDS.has(layer_id) or seen_layer_ids.has(layer_id) or \
						not (allowed_value as Array).has(layer_id) or \
						not layer_path.begins_with("res://art/portraits/layers/") or \
						not layer_path.ends_with(".png") or not ResourceLoader.exists(layer_path):
					return {"ok": false, "code": "invalid_rig_layer", "character_id": character_id,
						"layer_id": layer_id}
				var layer_texture := load(layer_path) as Texture2D
				if layer_texture == null or layer_texture.get_size() != Vector2(float((canvas_value as Array)[0]),
						float((canvas_value as Array)[1])):
					return {"ok": false, "code": "rig_layer_canvas_mismatch", "character_id": character_id,
						"layer_id": layer_id}
				seen_layer_ids[layer_id] = true
		var current_portrait := str(character.get("current_portrait", ""))
		if not current_portrait.is_empty() and not ResourceLoader.exists(current_portrait):
			return {"ok": false, "code": "missing_character_portrait", "character_id": character_id}
		if status != "approved":
			var replacement_target := str(character.get("replacement_target", ""))
			if not replacement_target.begins_with("res://art/portraits/") or \
					not replacement_target.ends_with(".png") or replacement_target == current_portrait or \
					replacement_targets.has(replacement_target):
				return {"ok": false, "code": "invalid_replacement_target",
					"character_id": character_id}
			replacement_targets[replacement_target] = character_id
			release_blockers.append(character_id)
		seen_ids[character_id] = true
		for alias_value in (character.get("aliases", []) as Array):
			var alias := str(alias_value)
			if alias.is_empty() or alias_owners.has(alias):
				return {"ok": false, "code": "duplicate_character_alias", "alias": alias}
			alias_owners[alias] = character_id
	var storyboard_blockers: Array[String] = []
	var storyboard_ids := {}
	var storyboards_value: Variant = data.get("storyboards", [])
	if not storyboards_value is Array or (storyboards_value as Array).is_empty():
		return {"ok": false, "code": "missing_storyboard_art_plan"}
	for storyboard_value in (storyboards_value as Array):
		if not storyboard_value is Dictionary:
			return {"ok": false, "code": "invalid_storyboard_art_plan"}
		var storyboard: Dictionary = storyboard_value
		var storyboard_id := str(storyboard.get("id", ""))
		var status := str(storyboard.get("status", ""))
		var target := str(storyboard.get("target", ""))
		var profile_id := str(storyboard.get("motion_profile", ""))
		var mode := str(storyboard.get("portrait_mode", ""))
		if storyboard_id.is_empty() or storyboard_ids.has(storyboard_id) or \
				str(storyboard.get("brief_section", "")).is_empty() or \
				not ["asset_required", "approved"].has(status) or \
				not target.begins_with("res://art/scenes/") or not target.ends_with(".png") or \
				not has_motion_profile(profile_id) or mode != "scene_only":
			return {"ok": false, "code": "invalid_storyboard_art_plan", "storyboard_id": storyboard_id}
		if not storyboard.get("character_ids", []) is Array or (storyboard.get("character_ids", []) as Array).is_empty():
			return {"ok": false, "code": "invalid_storyboard_characters", "storyboard_id": storyboard_id}
		for character_id_value in (storyboard.get("character_ids", []) as Array):
			if not has_character(str(character_id_value)):
				return {"ok": false, "code": "invalid_storyboard_character", "storyboard_id": storyboard_id}
		if status == "approved" and not ResourceLoader.exists(target):
			return {"ok": false, "code": "missing_storyboard_asset", "storyboard_id": storyboard_id}
		storyboard_ids[storyboard_id] = true
		if status != "approved":
			storyboard_blockers.append(storyboard_id)
	return {
		"ok": true,
		"code": "valid",
		"character_count": seen_ids.size(),
		"motion_profile_count": profiles.size(),
		"release_blockers": release_blockers,
		"storyboard_count": storyboard_ids.size(),
		"storyboard_blockers": storyboard_blockers,
	}


static func character(character_id: String) -> Dictionary:
	for character_value in (load_catalog().get("characters", []) as Array):
		var candidate: Dictionary = character_value
		if str(candidate.get("id", "")) == character_id:
			return candidate.duplicate(true)
	return {}


static func has_character(character_id: String) -> bool:
	return not character(character_id).is_empty()


static func motion_profile(profile_id: String) -> Dictionary:
	var profiles: Dictionary = load_catalog().get("motion_profiles", {})
	var selected := profile_id if profiles.has(profile_id) else "restrained"
	var value: Variant = profiles.get(selected, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func has_motion_profile(profile_id: String) -> bool:
	var profiles_value: Variant = load_catalog().get("motion_profiles", {})
	return profiles_value is Dictionary and (profiles_value as Dictionary).has(profile_id)


static func event_motion_profile(event: Dictionary) -> Dictionary:
	var profile_id := str(event.get("motion_profile", ""))
	if profile_id.is_empty():
		var identity := character(str(event.get("character_id", "")))
		profile_id = str(identity.get("motion_profile", "restrained"))
	return motion_profile(profile_id)
