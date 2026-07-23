extends SceneTree

const CombatStageScript = preload("res://scripts/combat_stage.gd")


func _init() -> void:
	var stage: Control = CombatStageScript.new()
	var validation: Dictionary = stage.debug_validate_pixel_pipeline()
	var art_contract: Dictionary = stage.debug_validate_external_art_contract()
	stage.free()
	if bool(validation.get("ok", false)) and int(validation.get("enemy_count", 0)) == 18 and \
			int(validation.get("pose_count", 0)) == 108 and \
			int(validation.get("path_count", 0)) == 6 and \
			int(validation.get("jade_weapon_count", 0)) == 16 and \
			int(validation.get("vfx_count", 0)) >= 9 and bool(art_contract.get("ok", false)):
		print("COMBAT_STAGE_PIXEL_PIPELINE_TEST_OK: 18 enemies, 108 poses, 6 paths, 16 jade weapons, semantic VFX and layered-art path contract validated")
		quit(0)
		return
	for failure in validation.get("failures", []):
		push_error("COMBAT_STAGE_PIXEL_PIPELINE_TEST_FAILED: %s" % failure)
	if not bool(art_contract.get("ok", false)):
		push_error("COMBAT_STAGE_PIXEL_PIPELINE_TEST_FAILED: layered-art path contract")
	quit(1)
