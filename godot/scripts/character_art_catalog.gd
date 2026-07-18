class_name CharacterArtCatalog
extends RefCounted

const DATA_PATH := "res://data/character_art_v1.json"
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
