extends SceneTree
const Scene = preload("res://scenes/ark_greybox.tscn")
const Save = preload("res://scripts/ark_greybox_save.gd")
const Table = preload("res://scripts/modules/leisure/ark_lantern_table.gd")
var game: Node3D
var save_root: String

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_MINIMIZED
		root.unfocusable = true
	_run.call_deferred()

func _spawn() -> void:
	game = Scene.instantiate()
	game.save_root_override = save_root
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _interact(id: String) -> void:
	for entry in game.interactables:
		if entry.id == id:
			game.player.global_position = entry.node.global_position
			game.call("_interact")
			return
	assert(false, "missing actual interactable " + id)

func _stand_at_table_resident() -> void:
	for z in range(-10, 11):
		for x in range(-13, 14):
			game.player.global_position = game.ark_root.to_global(game.shelter_position + Vector3(x * .1, .19, z * .1))
			if not game.call("_player_at_shared_table"): continue
			var nearest := ""
			var distance := 2.8
			for entry in game.interactables:
				var target: Node3D = entry.node
				var d: float = game.player.global_position.distance_to(target.global_position)
				if d < distance:
					nearest = entry.id
					distance = d
			if nearest == "resident" and distance >= .5: return
	assert(false, "no actual table approach selects the resident")

func _resident_pose() -> Dictionary:
	var result := {}
	var resident := game.traveler_marker as Node3D
	result["root"] = resident.transform
	for node in resident.find_children("*", "Node3D", true, false):
		if not node is Label3D: result[str(resident.get_path_to(node))] = node.transform
	return result

func _click(button: Button) -> void:
	assert(button.is_visible_in_tree() and root.get_visible_rect().encloses(button.get_global_rect()), "click target outside viewport: %s in %s" % [button.get_global_rect(), root.get_visible_rect()])
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func _capture(name_: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var folder := OS.get_environment("ARK_LANTERN_CAPTURE_ROOT")
	assert(folder.is_absolute_path() and folder.to_lower().begins_with("d:/"))
	DirAccess.make_dir_recursive_absolute(folder)
	for tick in range(4): await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(folder.path_join(name_ + ".png")) == OK)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for tick in range(4): await process_frame
	save_root = ProjectSettings.globalize_path("res://../.local/test_lantern_%d" % OS.get_process_id()).simplify_path()
	var service = Save.new(save_root)
	service.clear_for_test()
	await _spawn()
	game.call("_open_lantern_table")
	assert(not game.call("_lantern_table_open") and game.lantern_table.snapshot().round == 0)
	# Real finite harvest -> paid shelter -> cooked meal -> invited resident.
	_interact("wood")
	_interact("wood")
	_interact("shellfish")
	assert(game.call("_try_place_shelter", Vector3.ZERO))
	_interact("resident")
	_interact("resident")
	assert(game.traveler_choice_pending)
	_key(KEY_1)
	assert(game.traveler_boarded and game.resident_met)
	game.call("_interact_hearth")
	assert(game.stew_servings == 1)
	# Let the invited resident reach the home through the actual walking loop.
	# Standing on her entry point on shore is not the same as sharing a meal.
	game.player.global_position = game.ark_root.to_global(game.shelter_position + Vector3(0.35, 0.19, 0.5))
	for tick in range(240): game.call("_process", 1.0 / 60.0)
	assert(game.call("_player_at_shared_table"))
	_stand_at_table_resident()
	game.call("_interact")
	assert(game.shared_meal_count == 1 and game.stew_servings == 0, str(game.message))
	var before_cards: Dictionary = game.call("_build_save_state")
	var stock: Dictionary = game.economy.snapshot()
	# Explicit seeded card fixture for repeatable mouse/restore checks. The room
	# and shared meal above were actually earned, not fabricated historical facts.
	assert(game.lantern_table.begin("tidekeeper", 1))
	assert(game.lantern_table.view().phase == "playing")
	var original_pose := _resident_pose()
	game.call("_open_lantern_table")
	assert(game.call("_lantern_table_open") and game.call("_life_clock_paused"))
	for tick in range(6): await process_frame
	var ui: Control = game.lantern_table_ui
	assert(game.get_node_or_null("ArkRoot/BuiltShelter/LanternTableProps") != null)
	assert(game.get_node("ArkRoot/BuiltShelter/LanternTableProps").find_children("*", "CollisionObject3D", true, false).is_empty())
	assert(str(ui.get("conversation").text).contains("分汤"), "banter may reference the genuinely shared meal")
	await _capture("01_playing")
	var timer: float = game.life_period_elapsed
	var npc_position: Vector3 = game.traveler_marker.position
	game.call("_physics_process", 1.0)
	game.call("_process", 1.0)
	assert(game.life_period_elapsed == timer and game.traveler_marker.position == npc_position)
	var old_cards: Dictionary = game.lantern_table.snapshot()
	_click(ui.get("hit_button") as Button)
	assert(game.lantern_table.snapshot() != old_cards, "real GUI mouse dispatch must draw exactly one card")
	await _capture("02_after_hit")
	if game.lantern_table.view().phase == "playing":
		_key(KEY_F5)
		var held: Dictionary = game.lantern_table.snapshot()
		_key(KEY_ESCAPE)
		assert(not game.call("_lantern_table_open") and game.get_node_or_null("ArkRoot/BuiltShelter/LanternTableProps") == null)
		assert(_resident_pose() == original_pose, "leaving the table restores the resident's exact original local pose")
		game.queue_free()
		await process_frame
		await _spawn()
		assert(game.lantern_table.snapshot() == held and not game.call("_lantern_table_open"), "load preserves the exact round without forcibly reopening a modal")
		game.call("_open_lantern_table")
		ui = game.lantern_table_ui
		assert(game.lantern_table.snapshot() == held)
		_key(KEY_2)
	assert(game.lantern_table.view().phase == "settled")
	var settled: Dictionary = game.lantern_table.snapshot()
	var sequence: int = game.event_sequence
	game.call("_on_lantern_table_action", "stand")
	assert(game.lantern_table.snapshot() == settled and game.event_sequence == sequence)
	assert(JSON.parse_string(JSON.stringify(game.economy.snapshot())) == JSON.parse_string(JSON.stringify(stock)), "no material/food/currency stake or reward: %s / %s" % [stock, game.economy.snapshot()])
	await _capture("03_settled")
	for size_ in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(960, 600)]:
		root.size = size_
		for tick in range(6): await process_frame
		ui.call("_layout")
		await process_frame
		assert(root.get_visible_rect().encloses((ui.get("panel") as Control).get_global_rect()), "table panel must fit the viewport")
		for button in [ui.get("again_button"), ui.find_child("LanternCloseButton", true, false)]:
			assert(button.is_visible_in_tree() and root.get_visible_rect().encloses(button.get_global_rect()), "choices are pinned outside scrolling prose")
	await _capture("05_compact_960x600")
	root.size = Vector2i(1280, 720)
	for tick in range(4): await process_frame
	ui.hide()
	game.orbit_camera.distance = 5.5
	game.orbit_camera.yaw = -.7
	game.orbit_camera.adjusted = true
	game.call("_update_follow_camera")
	await _capture("04_table_world")
	ui.show()
	_key(KEY_ESCAPE)
	assert(game.lantern_table.snapshot() == settled)
	await process_frame
	var nodes_before: int = game.get_tree().get_node_count()
	for repeat in range(6):
		var pose := _resident_pose()
		game.call("_open_lantern_table")
		assert(game.call("_lantern_table_open") and game.find_children("LanternTableProps", "Node3D", true, false).size() == 1)
		_key(KEY_ESCAPE)
		await process_frame
		assert(_resident_pose() == pose and game.lantern_table.snapshot() == settled)
		assert(game.get_tree().get_node_count() == nodes_before, "repeated invitations must not accumulate props, lights or UI layers")
	var state: Dictionary = game.call("_build_save_state")
	assert(state.schema_version == 43 and service.save_state(state).ok)
	var bad := state.duplicate(true)
	bad.lantern_table.deck[0] = bad.lantern_table.deck[1]
	var bytes := FileAccess.get_file_as_bytes(service.get_save_path())
	assert(not service.save_state(bad).ok and FileAccess.get_file_as_bytes(service.get_save_path()) == bytes)
	# A real prior-schema save cannot invent a card game/history during migration.
	before_cards.schema_version = 37
	before_cards.erase("lantern_table")
	game.save_service = null
	game.queue_free()
	await process_frame
	assert(service.save_state(before_cards).ok)
	await _spawn()
	assert(game.lantern_table.snapshot().phase == "idle" and game.lantern_table.snapshot().round == 0)
	game.save_service = null
	game.queue_free()
	await process_frame
	service.clear_for_test()
	print("ARK_LANTERN_TABLE_TEST_OK: finite earned home/meal; resident presence; genuine-memory line; GUI hit/keyboard stand; exact round reload; no inventory stakes; pinned responsive choices; temporary non-colliding props; strict schema41 bad-state rejection and schema37 migration")
	quit(0)
