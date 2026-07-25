extends SceneTree

const CharacterArtCatalogScript = preload("res://scripts/character_art_catalog.gd")
const CharacterArtRigScript = preload("res://scripts/character_art_rig.gd")

const SUPPORTING_IDS := [
	"chi_yaoqing",
	"han_xuansu",
	"pei_zhaowei",
	"sect_lawkeepers",
	"family_covenant_holder",
]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(512, 768)
	for character_id in SUPPORTING_IDS:
		var identity: Dictionary = CharacterArtCatalogScript.character(character_id)
		var portrait_path := str(identity.get("current_portrait", ""))
		var portrait := load(portrait_path) as Texture2D
		var contract: Dictionary = identity.get("rig_contract", {})
		var canvas: Array = contract.get("canvas_size", [])
		var wind: Array = contract.get("wind_axis", [])
		var layers: Array = identity.get("layers", [])
		_expect(portrait != null, "%s底图无法加载" % character_id)
		_expect(canvas.size() == 2 and int(canvas[0]) == 1024 and int(canvas[1]) == 1536,
			"%s动态层画布必须固定为1024x1536" % character_id)
		_expect(wind.size() == 2, "%s缺少有效风向" % character_id)
		_expect(layers.size() == 1 and str((layers[0] as Dictionary).get("id", "")) == "local_fx",
			"%s必须只登记一张同画布local_fx层" % character_id)
		if portrait == null or canvas.size() != 2 or wind.size() != 2:
			continue

		var host := Control.new()
		host.size = Vector2(512.0, 768.0)
		root.add_child(host)
		var rig := CharacterArtRigScript.new() as CharacterArtRig
		host.add_child(rig)
		rig.configure(
			portrait,
			layers,
			CharacterArtCatalogScript.motion_profile(str(identity.get("motion_profile", "restrained"))),
			character_id,
			Vector2(float(canvas[0]), float(canvas[1])),
			Vector2(float(wind[0]), float(wind[1]))
		)
		rig.set_layout_rect(Vector2.ZERO, host.size)
		await process_frame
		var fx := rig.layer_nodes.get("local_fx") as TextureRect
		var initial_position := fx.position if fx != null else Vector2.ZERO
		for _frame in range(45):
			await process_frame
		_expect(rig.base_portrait != null and rig.base_portrait.texture.resource_path == portrait_path,
			"%s没有保持指定身份底图" % character_id)
		_expect(rig.layer_count() == 1 and fx != null and fx.texture != null,
			"%s没有加载唯一local_fx层" % character_id)
		if fx != null and fx.texture != null:
			_expect(fx.texture.get_size() == portrait.get_size(),
				"%s底图和local_fx画布不一致" % character_id)
			_expect(fx.position.distance_to(initial_position) > 0.005 and fx.position.length() <= 1.0,
				"%s的local_fx没有执行克制微动" % character_id)
			_expect(fx.self_modulate.a >= 0.09 and fx.self_modulate.a <= 0.25,
				"%s的local_fx透明度超出身份安全范围" % character_id)
		host.queue_free()
		await process_frame

	if failures.is_empty():
		print("SUPPORTING_CHARACTER_ART_TEST_OK: five supporting portraits and local FX layers passed")
		quit(0)
	else:
		for failure in failures:
			push_error("SUPPORTING_CHARACTER_ART_TEST_FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
