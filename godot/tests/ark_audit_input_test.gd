extends SceneTree

const ArkTestPaths = preload("res://tests/ark_test_paths.gd")

func _initialize() -> void:
	_run.call_deferred()

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	return event

func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_ark_audit_input").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(save_root), "audit saves must stay in this repository's isolated test directory")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var game := (load("res://scenes/ark_greybox.tscn") as PackedScene).instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.set("wood", 12)
	game.set("stored_wood", 3)
	for modal in ["traveler_choice_pending", "sailmaker_choice_pending", "resident_repair_choice_pending", "preparation_choice_pending", "repair_choice_pending"]:
		game.set(modal, true)
		game.call("_unhandled_key_input", _key(KEY_ESCAPE))
		assert(not bool(game.get(modal)), "Escape must dismiss %s without trapping the controls" % modal)
	assert(int(game.get("wood")) == 12 and int(game.get("stored_wood")) == 3 and bool(game.get("rope_available")), "cancelling proposals must not consume construction/repair resources")
	assert(not bool(game.get("traveler_boarded")) and not bool(game.get("sailmaker_boarded")), "cancelled invitations must not board residents")
	game.call("_toggle_world_chart")
	var chart := game.get("world_chart") as Control
	assert(chart.visible, "the chart should open")
	for keycode in [KEY_R, KEY_E, KEY_B, KEY_F, KEY_T, KEY_SPACE]:
		game.call("_unhandled_key_input", _key(keycode))
	assert(int(game.get("weather_phase")) == 0 and int(game.get("day_period")) == 0, "map input must not advance weather/time behind the overlay")
	assert(not bool(game.get("building_mode")) and not bool(game.get("preparation_choice_pending")), "map input must not activate hidden construction or interaction modes")
	game.call("_unhandled_key_input", _key(KEY_F5))
	var save_notice := game.get("save_status_notice") as Label
	assert(save_notice.visible and not save_notice.text.is_empty(), "F5 feedback must be visible above the open chart, not hidden beneath it")
	game.call("_unhandled_key_input", _key(KEY_ESCAPE))
	assert(not chart.visible, "Escape must still close the chart")
	assert(not save_notice.visible, "the chart notice should not obscure ordinary play after closing")
	game.set("weather_phase", 2)
	game.call("_start_basic_shelter_template")
	assert(bool(game.get("building_mode")), "a stopped ark should still allow construction previews")
	await process_frame
	var panel := game.get("hud_panel") as PanelContainer
	var hud := game.get("hud") as Label
	var note := game.get("note") as Label
	assert(panel.custom_minimum_size == Vector2(360.0, 0.0) and hud.visible and note.visible, "new construction must use the compact preview HUD instead of covering the deck")
	assert(note.text.contains("3 木") and note.text.contains("Esc") and note.text.contains("位置"), "compact construction retains cost, controls and placement feedback")
	game.call("_toggle_sailing")
	assert(not bool(game.get("sailing_mode")) and bool(game.get("building_mode")), "a live preview must be confirmed/cancelled before the helm can engage")
	game.call("_cancel_build", false)
	game.call("_update_hud")
	assert(panel.custom_minimum_size == Vector2(360.0, 0.0) and hud.visible, "leaving build mode must restore the regular HUD")
	game.call("_toggle_sailing")
	assert(bool(game.get("sailing_mode")), "cancelling the preview must leave the helm available")
	for starter in ["_start_basic_shelter_template", "_start_starter_home_template", "_start_build"]:
		game.call(starter)
		assert(not bool(game.get("building_mode")), "every starter construction UI must reject active sailing")
	assert(not bool(game.call("_try_place_shelter", Vector3.ZERO)), "placement commits must also reject active sailing")
	assert(not bool(game.get("shelter_built")) and int(game.get("wood")) == 12, "blocked sailing construction must preserve the structure and materials")
	game.call("_toggle_sailing")
	assert(not bool(game.call("_is_valid_shelter_position", Vector3(NAN, 0.12, 0.0))), "non-finite shelter previews are never legal")
	assert(bool(game.call("_try_place_shelter", Vector3.ZERO)), "ordinary construction must recover after leaving the helm")
	assert(int(game.get("wood")) == 9, "recovered construction must charge exactly one normal cost")
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()
	print("ARK_AUDIT_INPUT_TEST_OK:")
	quit()
