extends SceneTree
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
var scene = preload("res://scenes/ark_greybox.tscn")
var save_root: String
func _init() -> void:
	call_deferred("run")
func spawn() -> Node3D:
	var game = scene.instantiate()
	game.save_root_override = save_root
	root.add_child(game)
	await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	return game
func dispose(game: Node) -> void:
	game.free()
	await process_frame
func test_numeric_fact_idempotence() -> void:
	var Memory = preload("res://scripts/modules/memory/ark_memory.gd")
	assert(Memory.facts_equal({"a": [1, 2.5]}, {"a": [1.0, 2.5]}))
	assert(not Memory.facts_equal(1, true))
	assert(not Memory.facts_equal(1, "1"))
	assert(not Memory.facts_equal([1, 2], [2, 1]))
	assert(not Memory.facts_equal({"a": 1}, {"b": 1}))
	assert(not Memory.facts_equal(9007199254740993, 9007199254740992.0))
	assert(Memory.facts_equal(9007199254740992, 9007199254740992.0))
	var Construction = preload("res://scripts/modules/construction/ark_construction.gd")
	var construction = Construction.new()
	var facts := {"structures": {"shelter": {"built": true, "position": {"x": 1, "y": Vector3(0, 0.12, 0).y, "z": -2}, "quarter_turns": 1}}, "nested": [1, {"value": 2}]}
	assert(construction.move("numeric-replay", func(): return true, facts).ok)
	for full_precision in [false, true]:
		var serialized: Dictionary = JSON.parse_string(JSON.stringify(construction.snapshot(), "", true, full_precision))
		var candidate = Construction.new()
		assert(candidate.restore(serialized))
		var untouched := candidate.snapshot()
		assert(candidate.move("numeric-replay", func(): return true, facts).get("duplicate", false), "Vector3 coordinates replay after both legacy and full-precision JSON")
		assert(Construction.structure_facts_equal({"structures": candidate.state()}, {"structures": construction.state()}))
		assert(Memory.facts_equal(candidate.snapshot(), untouched), "coordinate comparison never rewrites persisted facts or receipt sequence")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(construction.snapshot()))
	var restored = Construction.new()
	assert(restored.restore(saved))
	var replay: Dictionary = restored.move("numeric-replay", func(): assert(false, "duplicate must not validate again"), facts)
	assert(replay.get("duplicate", false), "JSON numeric representation must not conflict on identical replay")
	assert(restored.snapshot().sequence == 1 and restored.snapshot().receipts.size() == 1)
	var changed := facts.duplicate(true)
	changed.structures.shelter.position.x = 1.000001
	assert(restored.move("numeric-replay", func(): return true, changed).code == "operation_conflict")
	changed = facts.duplicate(true)
	changed.nested[0] = true
	assert(restored.move("numeric-replay", func(): return true, changed).code == "operation_conflict")
	changed = facts.duplicate(true)
	changed.structures.shelter.position.x = true
	assert(restored.move("numeric-replay", func(): return true, changed).code == "invalid_command")
	for value in [true, "1", 1.000000001]:
		var broken := saved.duplicate(true)
		broken.structures.shelter.position.x = value
		assert(not restored.restore(broken), "corrupt projected structures must reject bool, string and unequal number")
	var bad_built := saved.duplicate(true)
	bad_built.structures.shelter.built = 1
	assert(not restored.restore(bad_built), "projected bool cannot become integer")
	bad_built = saved.duplicate(true)
	bad_built.receipts["numeric-replay"].facts.structures.shelter.built = 1
	bad_built.structures.shelter.built = 1
	assert(not restored.restore(bad_built), "receipt validation still rejects malformed built flag")
	assert(Memory.facts_equal(restored.snapshot(), saved), "failed restore must preserve committed facts")
	var mixed := saved.duplicate(true)
	mixed.structures.shelter.position.x = 1
	assert(restored.restore(mixed), "equal integer/float facts must restore")

func run() -> void:
	test_numeric_fact_idempotence()
	save_root = ProjectSettings.globalize_path("res://../.local/test_save_module_chain").simplify_path()
	assert(Paths.is_safe_save_root(save_root))
	var helper = Save.new(save_root)
	helper.clear_for_test()
	var game = await spawn()
	game.wood = 30
	assert(game._try_place_shelter(Vector3.ZERO))
	assert(game.wood == 30 - game.BUILD_COST)
	assert(game.construction.structure("shelter").built)
	var paid: int = game.wood
	assert(not game._try_place_shelter(Vector3.ZERO) and game.wood == paid)
	game._record_world_event("resident_meal_shared", {"participant_ids": ["player", "tidekeeper", "sailmaker"]})
	for i in range(300): game._record_world_event("weather_observed", {"index": i})
	assert(game._latest_shared_meal_included_sailmaker(), "durable recorded meal survives short-log clipping")
	var saved: Dictionary = game._build_save_state()
	assert(saved.schema_version == 36 and game.MemoryScript._plain(saved))
	assert(game.economy.audit().ok)
	assert(game._save_progress())
	await dispose(game)
	game = await spawn()
	assert(not game.get_meta("save_load_blocked", false), "valid owned bundle must recreate")
	assert(game.shelter_built and game.wood == paid and game.get_node_or_null("ArkRoot/BuiltShelter") != null)
	assert(game._latest_shared_meal_included_sailmaker())
	game._load_progress()
	assert(game.wood == paid and game.economy.audit().ok, "repeat restore replaces, never replays credit")
	for kind in ["inventory", "orientation", "sequence", "memory", "collected", "node"]:
		var broken := saved.duplicate(true)
		match kind:
			"inventory": broken.wood += 1
			"orientation": broken.storage_quarter_turns = 2
			"sequence": broken.modules.construction_sequence += 1
			"memory": broken.modules.memories.durable["invalid"] = 1
			"collected": broken.collected_ids = null
			"node": broken.modules.gathering["extra"] = game
		assert(not game._prepare_module_restore(broken), "malformed bundle rejected: " + kind)
		assert(game.wood == paid, "preflight is nonmutating")
	# Historical schema ignores unknown future module data, preserving known fields.
	await dispose(game)
	var old := saved.duplicate(true)
	old.schema_version = 33
	old.modules = {"invalid_future_key": true}
	assert(helper.save_state(old).ok)
	game = await spawn()
	assert(game.shelter_built and game.wood == paid and not game.get_meta("save_load_blocked", false))
	# Current ownership persists the actual snapped extension, not the legacy -4.2 default.
	game.wood = 40
	game.keel_beams = game.RAFT_EXTENSION_KEEL_COST
	assert(game._try_place_workbench(Vector3(-2.0, 0.12, 1.5)))
	assert(game._try_place_raft_extension(Vector3(0.0, 0.12, -4.2)))
	var placed: Vector3 = game.get_node("ArkRoot/BuiltRaftExtension").position
	assert(is_equal_approx(placed.z, -4.0))
	assert(game._save_progress())
	await dispose(game)
	game = await spawn()
	assert(not game.get_meta("save_load_blocked", false))
	assert(game.get_node("ArkRoot/BuiltRaftExtension").position.is_equal_approx(placed))
	assert(is_equal_approx(float(game.construction.structure("raft_extension").position.z), placed.z))
	var before_refund: Dictionary = game.economy.snapshot().inventories.player.duplicate(true)
	var occupied := 0
	for amount in before_refund.values(): occupied += int(amount)
	assert(game.economy.set_capacity("player", occupied))
	assert(not game._dismantle_raft_extension(), "full inventory rejects refund before destroying support")
	assert(game.raft_extension_built and game.construction.structure("raft_extension").built)
	assert(game.get_node_or_null("ArkRoot/BuiltRaftExtension") != null)
	assert(game.economy.snapshot().inventories.player == before_refund and game.economy.audit().ok)
	assert(game.economy.set_capacity("player", occupied + 100))
	assert(game._dismantle_raft_extension())
	assert(not game.raft_extension_built and not game.construction.structure("raft_extension").built)
	assert(game.get_node_or_null("ArkRoot/BuiltRaftExtension") == null and game.economy.audit().ok)
	await dispose(game)
	helper.clear_for_test()
	print("ARK_MODULE_CHAIN_TEST_OK: real construction, durable facts, JSON restore, malformed atomic rejection, schema33")
	quit()
