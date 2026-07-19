extends SceneTree

const CharacterArtCatalogScript = preload("res://scripts/character_art_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	var validation: Dictionary = CharacterArtCatalogScript.validate_catalog()
	_expect(bool(validation.get("ok", false)), "角色美术身份表必须通过结构与资源校验")
	_expect(int(validation.get("character_count", 0)) >= 12,
		"角色美术身份表必须覆盖主角、女主、主要女配、群像与反派")
	_expect(int(validation.get("motion_profile_count", 0)) >= 5,
		"角色美术必须提供克制、警觉、对峙与回响等动效档位")
	_expect(int(validation.get("storyboard_count", 0)) >= 3 and
		(validation.get("storyboard_blockers", []) as Array).is_empty(),
		"男主与照雪关键分镜必须全部进入正式美术计划与发布门禁")

	var protagonist: Dictionary = CharacterArtCatalogScript.character("protagonist")
	var heroine: Dictionary = CharacterArtCatalogScript.character("jiang_zhaoxue")
	var antagonist: Dictionary = CharacterArtCatalogScript.character("recurring_antagonist")
	var art_direction: Dictionary = CharacterArtCatalogScript.load_catalog().get("art_direction", {})
	var regional_influences: Dictionary = art_direction.get("regional_influences", {})
	_expect(str(regional_influences.get("policy", "")) == "open_regional_palette" and
		str(regional_influences.get("statement", "")).length() >= 24 and
		str(regional_influences.get("rejection_basis", "")).length() >= 24,
		"美术规范必须允许研究充分且与身份、时代和场景协调的开放地域影响")
	_expect(str(protagonist.get("narrative_role", "")) == "male_protagonist" and
		str(protagonist.get("visual_signature", "")).length() >= 24,
		"男主必须有可供跨分镜复用的稳定身份描述")
	_expect(str(heroine.get("narrative_role", "")) == "female_lead" and
		str(heroine.get("visual_signature", "")).length() >= 24,
		"江照雪必须作为女主拥有独立身份描述")
	var regional_anchors := {
		"ning_zhaoxue": "海雾关",
		"chi_yaoqing": "西域商道",
		"wen_xingdu": "东南海域",
		"han_xuansu": "高原与南亚",
	}
	for regional_id in regional_anchors:
		var regional_character: Dictionary = CharacterArtCatalogScript.character(str(regional_id))
		_expect(str(regional_character.get("regional_influence_note", "")).length() >= 40 and
			str(regional_character.get("visual_signature", "")).contains(str(regional_anchors[regional_id])),
			"地域融合角色必须记录叙事来源：%s" % regional_id)
	_expect(str(antagonist.get("narrative_role", "")) == "primary_antagonist" and
		str(antagonist.get("visual_signature", "")).length() >= 24,
		"主反派必须拥有独立身份与视觉锚点规范")
	var protagonist_contract: Dictionary = protagonist.get("visual_contract", {})
	_expect(str(protagonist.get("style_profile", "")) == "legacy_xianxia_cg_lead_v1" and
		str(protagonist.get("reference_portrait", "")) ==
			"res://art/portraits/protagonist_hooded_close.jpg" and
		str(protagonist_contract.get("face_visibility", "")) == "hood_conceals_eyes" and
		(protagonist_contract.get("must_keep", []) as Array).has("low_forward_hood") and
		(protagonist_contract.get("must_keep", []) as Array).has("eyes_hidden") and
		(protagonist_contract.get("must_keep", []) as Array).has("black_white_reincarnation_jade"),
		"男主高精度升级必须保留旧版遮眼兜帽、侧背轮廓与轮回玉身份")
	var heroine_contract: Dictionary = heroine.get("visual_contract", {})
	_expect(str(heroine.get("style_profile", "")) == "legacy_xianxia_cg_lead_v1" and
		str(heroine.get("reference_portrait", "")) ==
			"res://art/portraits/qingyun_sword_heroine.jpg" and
		str(heroine_contract.get("face_visibility", "")) == "visible" and
		(heroine_contract.get("must_keep", []) as Array).has("young_beautiful_adult_identity") and
		(heroine_contract.get("must_keep", []) as Array).has("long_blue_black_hair") and
		(heroine_contract.get("must_keep", []) as Array).has("jade_white_ice_blue_sword_dress"),
		"江照雪高精度升级必须延续旧版美型、长发、银蓝饰物与白冰蓝剑裙语言")
	for lead in [protagonist, heroine]:
		var rig_contract: Dictionary = lead.get("rig_contract", {})
		var canvas_size: Array = rig_contract.get("canvas_size", [])
		var locked_regions: Array = rig_contract.get("locked_regions", [])
		var allowed_layers: Array = rig_contract.get("allowed_layers", [])
		_expect(str(rig_contract.get("layering_rule", "")) ==
				"same_source_same_canvas_rgba_only" and canvas_size.size() == 2 and
				int(canvas_size[0]) == 1024 and int(canvas_size[1]) == 1536 and
				not locked_regions.is_empty() and allowed_layers.has("hair_front") and
				allowed_layers.has("tassel_or_ribbon") and allowed_layers.has("outer_cloth") and
				lead.get("layers", null) is Array,
			"主角动态必须只接受同源同画布透明层，并锁定脸/兜帽、手和身份饰物")
	for blocker_value in (validation.get("release_blockers", []) as Array):
		var blocker: Dictionary = CharacterArtCatalogScript.character(str(blocker_value))
		_expect(str(blocker.get("replacement_target", "")).begins_with("res://art/portraits/") and
			str(blocker.get("replacement_target", "")).ends_with(".png"),
			"每个未批准角色必须有唯一且版本化的PNG替换目标：%s" % blocker_value)

	for profile_id in ["restrained", "introspective", "vigilant", "confrontation", "spectral"]:
		var profile: Dictionary = CharacterArtCatalogScript.motion_profile(profile_id)
		_expect(CharacterArtCatalogScript.has_motion_profile(profile_id) and not profile.is_empty() and
			float(profile.get("breath_y", 1.0)) <= 0.008 and
			float(profile.get("portrait_parallax_px", 9.0)) <= 4.0,
			"人物动效必须保持身份安全的微幅范围：%s" % profile_id)
	_expect(not CharacterArtCatalogScript.has_motion_profile("unknown_profile"),
		"发布校验不得把未知动效档位静默当成默认档")

	if failures.is_empty():
		print("CHARACTER_ART_CATALOG_TEST_OK: identities, release states and restrained motion profiles passed")
		quit(0)
	else:
		for failure in failures:
			push_error("CHARACTER_ART_CATALOG_TEST_FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
