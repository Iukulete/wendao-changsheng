extends SceneTree

const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const Work = preload("res://scripts/modules/residents/ark_household_work.gd")
var game: Node3D
var saver: RefCounted

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_MINIMIZED
		root.unfocusable = true
	_run.call_deferred()

func _capture(name_: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var folder := OS.get_environment("ARK_HOME_ART_CAPTURE_ROOT")
	assert(folder.is_absolute_path() and folder.replace("\\", "/").to_lower().begins_with("d:/"))
	DirAccess.make_dir_recursive_absolute(folder)
	game.call("_update_hud")
	var target: Vector3 = game.player.global_position + Vector3(0, 1.0, 0)
	game.camera.global_position = target + Vector3(0, 8.5, 10.5)
	game.camera.look_at(target, Vector3.UP)
	for frame in range(4):
		game.call("_refresh_nearfuture_hud")
		game.call("_update_shelter_roof_cutaway")
		await process_frame
	# A minimized window has no automatic post-draw signal. Force its offscreen
	# viewport without making it visible or stealing desktop focus.
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(folder.path_join(name_ + ".png")) == OK)

func _tick(count: int) -> void:
	for index in range(count):
		var before: Vector3 = game.sailmaker_marker.position
		game.call("_process", 0.05)
		assert(game.sailmaker_marker.position.distance_to(before) <= 0.64 * 0.05 + 0.00001, "work must walk within its actual budget, never teleport")
		await process_frame

func _until(predicate: Callable, label: String, limit: int = 600) -> void:
	for index in range(limit):
		if predicate.call():
			print("HOUSEHOLD_ARRIVAL: ", label, " ticks=", index, " job=", game.household_work.snapshot())
			return
		if index > 0 and index % 150 == 0:
			print("HOUSEHOLD_ROUTE_OBSERVATION: ", label, " tick=", index, " pos=", game.sailmaker_marker.position, " target=", game.call("_household_work_target"), " job=", game.household_work.snapshot())
		await _tick(1)
	assert(false, "%s: phase=%s pos=%s target=%s action=%s" % [label, game.household_work.snapshot(), game.sailmaker_marker.position, game.call("_household_work_target"), game.sailmaker_action])

func _collect(id: String) -> void:
	var node := game.get_node(id) as Node3D
	game.player.global_position = node.global_position
	game.call("_interact")
	await process_frame

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game.call("_unhandled_key_input", event)

func _same_work(left: Dictionary, right: Dictionary) -> bool:
	for key in ["enabled", "phase", "part", "completed", "last_part"]:
		if left.get(key) != right.get(key):
			return false
	for key in ["prepare_elapsed", "repair_elapsed"]:
		if absf(float(left.get(key, -1)) - float(right.get(key, -2))) > 0.000000000001:
			return false
	return true

func _policy(allow: bool) -> void:
	var button := game.find_child("ArkHouseholdWorkButton", true, false) as Button
	assert(button != null)
	button.pressed.emit()
	assert(game.household_work_choice_pending and game.call("_hud_choice_open"))
	_key(KEY_1 if allow else KEY_2)
	assert(not game.household_work_choice_pending and game.household_work.enabled == allow)

func _unit_contract() -> void:
	var work = Work.new()
	assert(not work.begin("raft_edge"))
	work.enabled = true
	assert(work.begin("raft_edge"))
	var before: Dictionary = work.snapshot()
	work.advance(NAN)
	work.advance(INF)
	work.advance(-1.0)
	assert(work.snapshot() == before)
	work.advance(10000.0)
	assert(work.prepare_elapsed == Work.MAX_STEP, "suspension is not offline labour")
	for index in range(60):
		work.advance(0.1)
	assert(work.ready() and work.operation_id() == "home_work:repair:1")
	assert(work.finish() and not work.finish() and work.completed == 1)
	assert(work.matches_economy({"home_work:repair:1": true}))
	assert(not work.matches_economy({}) and not work.matches_economy({"home_work:repair:01": true}))
	var restored = Work.new()
	assert(restored.restore(JSON.parse_string(JSON.stringify(work.snapshot()))))
	for change in [{"phase":"invalid"}, {"repair_elapsed": -1}, {"completed": 1.5}, {"completed": 0}, {"part":"raft_edge"}, {"enabled":1}]:
		var bad: Dictionary = work.snapshot()
		bad.merge(change, true)
		var unchanged: Dictionary = restored.snapshot()
		assert(not restored.restore(bad) and restored.snapshot() == unchanged)

func _run() -> void:
	_unit_contract()
	var root_path := ProjectSettings.globalize_path("res://../.local/test_household_work_%d" % OS.get_process_id()).simplify_path()
	assert(Paths.is_safe_save_root(root_path))
	saver = Save.new(root_path)
	saver.clear_for_test()
	game = load("res://scenes/ark_greybox.tscn").instantiate()
	game.save_root_override = root_path
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	for id in ["DriftwoodNear", "DriftwoodShore", "DriftwoodRidge"]:
		await _collect(id)
	assert(game.wood == 8)
	game.player.position = Vector3(0, 1.1, 1.75)
	assert(game.call("_try_place_workshop_home_template", Vector3(0, 0.12, 0)))
	game.sailmaker_met = true
	game.sailmaker_choice_pending = true
	game.call("_choose_sailmaker_boarding", true)
	assert(game.sailmaker_boarded and game.call("_household_facilities_present"))
	game.call("_interact_storage")
	assert(game.stored_wood == 1 and game.wood == 0)
	var legacy: Dictionary = game.call("_build_save_state")
	legacy.schema_version = 36
	legacy.erase("household_work")
	assert(saver.save_state(legacy).ok)
	game.call("_load_progress")
	assert(not game.household_work.enabled and game.household_work.completed == 0 and not game.household_work.active(), "old save must not invent authorization or past work")
	game.player.position = Vector3(0, 1.1, 1.75)
	game.call("_advance_weather")
	game.call("_advance_weather")
	assert(game.shelter_roof_damaged and game.raft_edge_damaged)
	await _tick(12)
	assert(not game.household_work.active() and game.stored_wood == 1, "no implicit standing permission")
	(game.find_child("ArkHouseholdWorkButton", true, false) as Button).pressed.emit()
	assert(game.household_work_choice_pending)
	await _capture("01_rooms_and_orders")
	_key(KEY_1)
	await _until(func(): return game.household_work.prepare_elapsed > 0.45, "actual workbench arrival")
	assert(game.household_work.phase == "prepare" and game.stored_wood == 1)
	await _capture("02_workshop_active")
	var progress: Dictionary = game.household_work.snapshot()
	for mode in ["storm", "night", "sailing", "building", "meal", "hidden_facility", "modal"]:
		var weather: int = game.weather_phase
		var period: int = game.day_period
		if mode == "storm": game.weather_phase = game.WeatherPhase.STORM
		if mode == "night": game.day_period = game.DayPeriod.NIGHT
		if mode == "sailing": game.sailing_mode = true
		if mode == "building": game.building_mode = true
		if mode == "meal":
			game.shared_meal_gathering_pending = true
			game.shared_meal_paused = false
			game.shared_meal_participants.assign(["player", "tidekeeper", "sailmaker"])
		if mode == "hidden_facility": game.get_node("ArkRoot/BuiltWorkbench").hide()
		if mode == "modal": game.household_work_choice_pending = true
		for index in range(20): game.call("_process_household_work", 0.1)
		assert(game.household_work.snapshot() == progress and game.stored_wood == 1, "pause preserves progress and materials: " + mode)
		game.weather_phase = weather
		game.day_period = period
		game.sailing_mode = false
		game.building_mode = false
		game.shared_meal_gathering_pending = false
		game.shared_meal_participants.clear()
		game.household_work_choice_pending = false
		game.get_node("ArkRoot/BuiltWorkbench").show()
	_policy(false)
	await _tick(12)
	assert(game.household_work.prepare_elapsed == progress.prepare_elapsed)
	_policy(true)
	assert(game.call("_save_progress"))
	var saved: Dictionary = saver.load_state().state
	assert(saved.schema_version == 43 and _same_work(saved.household_work, game.household_work.snapshot()), "JSON progress roundtrip differs: %s versus %s" % [saved.household_work, game.household_work.snapshot()])
	for change in [{"phase":"oops"}, {"prepare_elapsed": 8}, {"completed": 1}, {"last_part":"shelter_roof"}]:
		var bad: Dictionary = saved.duplicate(true)
		bad.household_work.merge(change, true)
		assert(not saver.save_state(bad).ok and saver.load_state().state == saved)
	game.call("_load_progress")
	assert(_same_work(game.household_work.snapshot(), saved.household_work) and game.stored_wood == 1)
	game.call("_toggle_home_art_sample")
	await _until(func(): return game.household_work.phase == "repair" and game.household_work.repair_elapsed > 0.3, "actual repair arrival")
	await _capture("03_repair_active")
	await _until(func(): return game.household_work.completed == 1, "roof repaired at the real site")
	assert(not game.shelter_roof_damaged and game.raft_edge_damaged and game.stored_wood == 0 and game.wood == 0)
	await _capture("04_roof_repaired_no_stock")
	assert(game.economy.audit().ok)
	await _collect("MoonbackDriftwood")
	assert(game.wood == 2)
	await _tick(15)
	assert(not game.household_work.active() and game.wood == 2, "automation never takes player inventory")
	# Fixture travel is explicit; the work actor still walks every metre normally.
	game.player.position = Vector3(0, 1.1, 1.75)
	game.call("_interact_storage")
	assert(game.stored_wood == 2 and game.wood == 0)
	await _until(func(): return game.household_work.completed == 2, "repeatable second repair")
	assert(not game.raft_edge_damaged and game.stored_wood == 1 and game.economy.audit().ok)
	await _capture("05_two_completed_repairs")
	var consumed: int = game.economy.snapshot().totals.wood.consumed
	await _tick(30)
	assert(game.household_work.completed == 2 and game.economy.snapshot().totals.wood.consumed == consumed, "no manufacture without a real need")
	# Explicit bounded second-damage fixture; no material input is fabricated.
	game.shelter_roof_damaged = true
	await _until(func(): return game.household_work.prepare_elapsed > 0.2, "next order begins")
	game.repair_choice_pending = true
	game.call("_repair_damaged_part", "shelter")
	assert(not game.household_work.active() and game.household_work.completed == 2 and game.stored_wood == 0)
	await _tick(20)
	assert(game.stored_wood == 0 and game.household_work.completed == 2 and game.economy.audit().ok)
	assert(game.call("_save_progress"))
	for repeat in range(3):
		game.call("_load_progress")
		assert(game.household_work.enabled and game.household_work.completed == 2 and not game.household_work.active() and game.economy.audit().ok)
	assert(game.call("_room_use_summary").contains("工坊") and game.call("_room_use_summary").contains("卧舱"))
	assert(game.call("_build_save_state").world_events.filter(func(event): return event.id == "resident_household_repair_completed").size() == 2)
	game.free()
	saver.clear_for_test()
	print("ARK_HOUSEHOLD_WORK_TEST_OK: finite gathered wood; explicit policy; actual workshop/site work; repeated needs; bounded walking; interruptions/reload; no player stock; no duplicate/cancel charge; schema36 migration and schema37 rejection; functional room board")
	quit()
