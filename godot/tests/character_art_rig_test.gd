extends SceneTree

const CharacterArtRigScript = preload("res://scripts/character_art_rig.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(512.0, 768.0)
	root.add_child(host)
	var rig := CharacterArtRigScript.new() as CharacterArtRig
	host.add_child(rig)
	var profile := {
		"breath_x": 0.0015,
		"breath_y": 0.004,
		"sway_radians": 0.0012,
		"portrait_parallax_px": 0.0,
		"speed": 1.0,
	}
	rig.configure(
		load("res://art/portraits/protagonist_hooded_close.jpg") as Texture2D,
		[{
			"id": "hair_front",
			"path": "res://art/portraits/imperial_sky_inspector_v2.png",
			"amplitude_px": 1.6,
			"tangent_px": 0.3,
			"rotation_deg": 0.2,
			"frequency": 0.9,
		}],
		profile,
		"rig-test",
		Vector2(1024.0, 1536.0),
		Vector2(0.92, 0.2)
	)
	rig.set_layout_rect(Vector2(12.0, 18.0), Vector2(512.0, 768.0))
	await process_frame

	_expect(rig.base_portrait != null and rig.base_portrait.texture != null,
		"角色动态必须保留一个稳定底图")
	_expect(rig.layer_count() == 1 and rig.has_layer("hair_front"),
		"角色动态只应载入登记过的透明层标识")
	_expect(rig.find_children("*", "TextureRect", true, false).size() == 2,
		"一个角色动态容器只能包含底图与同源登记层，不能出现第二个角色容器")
	var hair_layer := rig.layer_nodes.get("hair_front") as TextureRect
	var initial_layer_position := hair_layer.position if hair_layer != null else Vector2.ZERO
	for _frame in range(45):
		await process_frame
	_expect(hair_layer != null and hair_layer.position.distance_to(initial_layer_position) > 0.01 and
		hair_layer.position.length() <= 2.0,
		"发丝层必须有克制且有上限的独立风动")
	_expect(rig.base_portrait.position == Vector2.ZERO and
		absf(rig.scale.x - 1.0) <= 0.0031 and absf(rig.scale.y - 1.0) <= 0.0061,
		"底图身份区只能呼吸，不能被局部层拖动或大幅缩放")
	_expect(rig.position.distance_to(Vector2(12.0, 18.0)) <= 0.01,
		"关闭视差时角色构图注册点必须稳定")

	if failures.is_empty():
		print("CHARACTER_ART_RIG_TEST_OK: single coherent rig, stable identity base and restrained registered layers passed")
		quit(0)
	else:
		for failure in failures:
			push_error("CHARACTER_ART_RIG_TEST_FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
