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
		(validation.get("storyboard_blockers", []) as Array).size() == 3,
		"男主与照雪关键分镜必须进入正式美术计划与发布门禁")

	var protagonist: Dictionary = CharacterArtCatalogScript.character("protagonist")
	var heroine: Dictionary = CharacterArtCatalogScript.character("jiang_zhaoxue")
	var antagonist: Dictionary = CharacterArtCatalogScript.character("recurring_antagonist")
	_expect(str(protagonist.get("narrative_role", "")) == "male_protagonist" and
		str(protagonist.get("visual_signature", "")).length() >= 24,
		"男主必须有可供跨分镜复用的稳定身份描述")
	_expect(str(heroine.get("narrative_role", "")) == "female_lead" and
		str(heroine.get("visual_signature", "")).length() >= 24,
		"江照雪必须作为女主拥有独立身份描述")
	_expect(str(antagonist.get("narrative_role", "")) == "primary_antagonist" and
		str(antagonist.get("visual_signature", "")).length() >= 24,
		"主反派必须拥有独立身份与视觉锚点规范")
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
