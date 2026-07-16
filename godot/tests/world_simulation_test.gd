extends SceneTree

const WorldSimulationScript = preload("res://scripts/world_simulation.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_initialization_and_determinism()
	_test_every_era_has_distinct_factions()
	_test_annual_change_and_persistence()
	_test_era_transition_determinism_continuity_and_idempotence()
	_test_boundaries()
	if failures.is_empty():
		print("WORLD_SIMULATION_TEST_OK: deterministic factions, NPC lives, relations and bounded history passed")
		quit(0)
	else:
		for failure in failures:
			push_error("WORLD_SIMULATION_TEST_FAILED: %s" % failure)
		quit(1)


func _test_initialization_and_determinism() -> void:
	var first := _base_state(20260716, 11)
	var second := first.duplicate(true)
	var first_result: Dictionary = WorldSimulationScript.initialize(first)
	var second_result: Dictionary = WorldSimulationScript.initialize(second)
	_expect(bool(first_result.ok) and bool(second_result.ok), "initialization must succeed")
	_expect(first == second and first_result == second_result,
		"the same seed, cursor and snapshot must produce the same initialized world")
	var factions: Array = first.world.factions
	var npcs: Array = first.world.npcs
	_expect(factions.size() >= 3, "initialization must create at least three era factions")
	_expect(npcs.size() >= 6, "initialization must create at least six persistent NPCs")
	var npc_ids := {}
	for npc_value in npcs:
		var npc: Dictionary = npc_value
		npc_ids[str(npc.id)] = true
		_expect(not str(npc.id).is_empty() and int(npc.age) >= 0,
			"every NPC must have a stable ID and valid age")
		_expect(npc.has("realm_id") and npc.has("stance") and npc.has("relations"),
			"every NPC must expose realm, stance and relationship data")
	_expect(npc_ids.size() == npcs.size(), "NPC IDs must be unique")
	_expect((first.world.history as Array).size() > 0,
		"initialization must leave a readable origin in world history")
	_assert_symmetric_relations(factions, "faction")
	_assert_symmetric_relations(npcs, "NPC")

	var future_a := first.duplicate(true)
	var future_b := first.duplicate(true)
	var advance_a: Dictionary = WorldSimulationScript.advance_year(future_a)
	var advance_b: Dictionary = WorldSimulationScript.advance_year(future_b)
	_expect(future_a == future_b and advance_a == advance_b,
		"annual simulation must be deterministic from an identical save snapshot")


func _test_every_era_has_distinct_factions() -> void:
	var era_ids := ["classical", "steam", "star_network", "wasteland", "final_age", "immortal_dynasty"]
	for era_id in era_ids:
		var state := _base_state(3000 + era_ids.find(era_id), 0)
		state.current_era_id = era_id
		WorldSimulationScript.initialize(state)
		var faction_ids := {}
		for faction_value in state.world.factions:
			var faction: Dictionary = faction_value
			faction_ids[str(faction.id)] = true
			_expect(str(faction.era_id) == era_id,
				"generated factions must belong to the selected era")
		_expect(faction_ids.size() >= 3,
			"every supported era must initialize three distinct factions")


func _test_annual_change_and_persistence() -> void:
	var state := _base_state(770031, 0)
	WorldSimulationScript.initialize(state)
	var old_year := int(state.world.year)
	var old_cursor := int(state.rng_cursor)
	var first_npc: Dictionary = state.world.npcs[0]
	var second_npc: Dictionary = state.world.npcs[1]
	var first_id := str(first_npc.id)
	var second_id := str(second_npc.id)
	first_npc.relations[second_id] = 47
	second_npc.relations[first_id] = 47
	state.world.npcs[0] = first_npc
	state.world.npcs[1] = second_npc
	state.world.history.append("PERSISTENCE_MARKER")
	var old_age := int(first_npc.age)

	var result: Dictionary = WorldSimulationScript.advance_year(state)
	_expect(bool(result.ok) and int(state.world.year) == old_year + 1,
		"advancing a year must increment world time")
	_expect(int(state.rng_cursor) > old_cursor, "advancing a year must persist RNG progress")
	_expect(int((state.world.npcs[0] as Dictionary).age) == old_age + 1,
		"living NPCs must age with the world")
	_expect((state.world.history as Array).has("PERSISTENCE_MARKER"),
		"existing history must survive annual advancement")
	var relationship_after := int((state.world.npcs[0] as Dictionary).relations[second_id])
	_expect(relationship_after >= -100 and relationship_after <= 100,
		"existing NPC relationships must persist as evolving bounded values")
	_expect(relationship_after == int((state.world.npcs[1] as Dictionary).relations[first_id]),
		"evolved relationships must remain symmetric")
	_expect(state.world.has("last_year_summary") and not str(state.world.last_year_summary.detail).is_empty(),
		"each simulated year must store a readable summary")
	_expect((state.world.annual_summaries as Array).size() == 1,
		"the current annual summary must enter persistent world state")

	var doomed: Dictionary = state.world.npcs[0]
	doomed.age = doomed.lifespan
	doomed.alive = true
	state.world.npcs[0] = doomed
	WorldSimulationScript.advance_year(state)
	_expect(not bool((state.world.npcs[0] as Dictionary).alive),
		"an NPC at the end of their lifespan must leave a persistent death record")
	_expect((state.world.npcs[0] as Dictionary).has("death_year"),
		"NPC death must record its world year")


func _test_era_transition_determinism_continuity_and_idempotence() -> void:
	var source := _base_state(441991, 7)
	WorldSimulationScript.initialize(source)
	source.world.history.append("ERA_CONTINUITY_MARKER")
	var old_faction_ids: Array[String] = []
	var old_influence := {}
	for faction_value in source.world.factions:
		var faction: Dictionary = faction_value
		old_faction_ids.append(str(faction.id))
		old_influence[str(faction.id)] = int(faction.influence)
	var old_survivor_ids: Array[String] = []
	for npc_value in source.world.npcs:
		var npc: Dictionary = npc_value
		if bool(npc.alive):
			old_survivor_ids.append(str(npc.id))
	var first_old_npc: Dictionary = source.world.npcs[0]
	var second_old_npc: Dictionary = source.world.npcs[1]
	first_old_npc.relations[str(second_old_npc.id)] = 63
	second_old_npc.relations[str(first_old_npc.id)] = 63
	source.world.npcs[0] = first_old_npc
	source.world.npcs[1] = second_old_npc

	var timeline_a := source.duplicate(true)
	var timeline_b := source.duplicate(true)
	var result_a: Dictionary = WorldSimulationScript.transition_era(timeline_a, "star_network")
	var result_b: Dictionary = WorldSimulationScript.transition_era(timeline_b, "star_network")
	_expect(bool(result_a.ok) and bool(result_a.changed), "a valid cross-era transition must succeed")
	_expect(timeline_a == timeline_b and result_a == result_b,
		"era transitions must be deterministic from identical snapshots")
	_expect(str(timeline_a.current_era_id) == "star_network" and
		str(timeline_a.world.simulated_era_id) == "star_network",
		"the state and simulated world must enter the target era together")

	var transitioned_factions: Array = timeline_a.world.factions
	for old_id in old_faction_ids:
		var old_faction := _find_entity(transitioned_factions, old_id)
		_expect(not old_faction.is_empty(), "normal transitions must retain every old faction")
		if not old_faction.is_empty():
			_expect(bool(old_faction.legacy) and str(old_faction.previous_era_id) == "steam",
				"old factions must be marked as legacies of the previous era")
			_expect(int(old_faction.influence) <= int(old_influence[old_id]),
				"old faction influence must decay across an era boundary")
	var target_faction_count := 0
	for faction_value in transitioned_factions:
		var faction: Dictionary = faction_value
		if str(faction.era_id) == "star_network" and not bool(faction.get("legacy", false)):
			target_faction_count += 1
	_expect(target_faction_count >= 2, "the target era must introduce at least two new factions")

	var transitioned_npcs: Array = timeline_a.world.npcs
	for old_id in old_survivor_ids:
		var old_npc := _find_entity(transitioned_npcs, old_id)
		_expect(not old_npc.is_empty(), "normal transitions must retain every surviving old NPC")
		if not old_npc.is_empty():
			_expect(bool(old_npc.legacy) and str(old_npc.previous_era_id) == "steam",
				"surviving NPCs must carry their previous-era legacy marker")
	var target_npc_count := 0
	for npc_value in transitioned_npcs:
		var npc: Dictionary = npc_value
		if str(npc.get("era_id", "")) == "star_network" and not bool(npc.get("legacy", false)):
			target_npc_count += 1
	_expect(target_npc_count >= 2, "the target era must introduce at least two new NPCs")
	var retained_first := _find_entity(transitioned_npcs, str(first_old_npc.id))
	var retained_second := _find_entity(transitioned_npcs, str(second_old_npc.id))
	_expect(int(retained_first.relations[str(second_old_npc.id)]) == 63 and
		int(retained_second.relations[str(first_old_npc.id)]) == 63,
		"relationships between surviving NPCs must cross the era boundary unchanged")
	_expect((timeline_a.world.history as Array).has("ERA_CONTINUITY_MARKER"),
		"era transitions must preserve old world history")
	_expect(str(timeline_a.world.history[-1]).contains("星穹道网纪"),
		"era transitions must append a readable history entry")
	_expect(_has_event(timeline_a.world.active_events, str(result_a.transition.event_id)),
		"era transitions must publish a persistent active event")
	_assert_symmetric_relations(transitioned_factions, "transitioned faction")
	_assert_symmetric_relations(transitioned_npcs, "transitioned NPC")

	var transitioned_snapshot := timeline_a.duplicate(true)
	var cursor_before_repeat := int(timeline_a.rng_cursor)
	var repeat_result: Dictionary = WorldSimulationScript.transition_era(timeline_a, "star_network")
	_expect(bool(repeat_result.ok) and not bool(repeat_result.changed) and
		str(repeat_result.code) == "already_current_era",
		"repeating the current target era must report an idempotent no-op")
	_expect(timeline_a == transitioned_snapshot and int(timeline_a.rng_cursor) == cursor_before_repeat,
		"an idempotent era transition must not mutate state or consume randomness")


func _test_boundaries() -> void:
	var state := _base_state(99117, 2147483647)
	state.world.qi_tide = 9999
	state.world.stability = -9999
	state.world.era_pressure = 9999
	state.world.year = 2147483647
	state.world.age = 2147483647
	for index in range(180):
		state.world.history.append("old-history-%d" % index)
	for index in range(60):
		state.world.annual_summaries.append({"year": index})
	for index in range(30):
		state.world.active_events.append({"id": "event-%d" % index, "expires_year": 2147483647})
	for index in range(12):
		state.world.factions.append({
			"id": "boundary_faction_%02d" % index,
			"name": "Boundary Faction %d" % index,
			"resources": 900,
			"influence": -100,
			"cohesion": 500,
			"relations": {},
		})
	for index in range(30):
		state.world.npcs.append({
			"id": "boundary_npc_%02d" % index,
			"name": "Boundary NPC %d" % index,
			"age": -20 if index % 2 == 0 else 20000,
			"lifespan": 80,
			"realm_index": 999,
			"stance": "edge",
			"faction_id": "boundary_faction_00",
			"alive": false,
			"relations": {},
		})

	WorldSimulationScript.advance_year(state)
	_expect(int(state.world.qi_tide) >= 0 and int(state.world.qi_tide) <= 100,
		"qi tide must remain bounded")
	_expect(int(state.world.stability) >= 0 and int(state.world.stability) <= 100,
		"stability must remain bounded")
	_expect(int(state.world.era_pressure) >= 0 and int(state.world.era_pressure) <= 100,
		"era pressure must remain bounded")
	_expect(int(state.world.year) <= WorldSimulationScript.MAX_WORLD_YEAR,
		"world year must not overflow")
	_expect((state.world.factions as Array).size() <= WorldSimulationScript.MAX_FACTIONS,
		"faction storage must be bounded")
	_expect((state.world.npcs as Array).size() <= WorldSimulationScript.MAX_NPCS,
		"NPC storage must be bounded")
	_expect((state.world.history as Array).size() <= WorldSimulationScript.MAX_HISTORY_ENTRIES,
		"history storage must be bounded")
	_expect((state.world.annual_summaries as Array).size() <= WorldSimulationScript.MAX_ANNUAL_SUMMARIES,
		"annual summary storage must be bounded")
	_expect((state.world.active_events as Array).size() <= WorldSimulationScript.MAX_ACTIVE_EVENTS,
		"active event storage must be bounded")
	for faction_value in state.world.factions:
		var faction: Dictionary = faction_value
		_expect(int(faction.resources) >= 0 and int(faction.resources) <= 100,
			"faction resources must remain bounded")
	_assert_symmetric_relations(state.world.factions, "bounded faction")
	_assert_symmetric_relations(state.world.npcs, "bounded NPC")

	var transition: Dictionary = WorldSimulationScript.transition_era(state, "star_network")
	_expect(bool(transition.ok) and bool(transition.changed),
		"a full world must still be able to transition eras")
	_expect((state.world.factions as Array).size() <= WorldSimulationScript.MAX_FACTIONS,
		"era transitions must preserve the faction cap")
	_expect((state.world.npcs as Array).size() <= WorldSimulationScript.MAX_NPCS,
		"era transitions must preserve the NPC cap")
	_expect((state.world.faction_archive as Array).size() <= WorldSimulationScript.MAX_FACTION_ARCHIVE,
		"overflow faction continuity must use a bounded archive")
	_expect((state.world.npc_archive as Array).size() <= WorldSimulationScript.MAX_NPC_ARCHIVE,
		"overflow NPC continuity must use a bounded archive")
	_assert_symmetric_relations(state.world.factions, "post-transition bounded faction")
	_assert_symmetric_relations(state.world.npcs, "post-transition bounded NPC")


func _base_state(seed_value: int, cursor: int) -> Dictionary:
	return {
		"world_seed": seed_value,
		"rng_cursor": cursor,
		"current_era_id": "steam",
		"world": {
			"seed": seed_value,
			"year": 1,
			"age": 0,
			"qi_tide": 50,
			"stability": 65,
			"era_pressure": 0,
			"factions": [],
			"npcs": [],
			"history": [],
			"annual_summaries": [],
			"active_events": [],
		},
	}


func _assert_symmetric_relations(entities: Array, label: String) -> void:
	for left_value in entities:
		var left: Dictionary = left_value
		var left_relations: Dictionary = left.relations
		for right_value in entities:
			var right: Dictionary = right_value
			if str(left.id) == str(right.id):
				continue
			_expect(left_relations.has(str(right.id)), "%s relationships must cover every peer" % label)
			if left_relations.has(str(right.id)):
				var right_relations: Dictionary = right.relations
				_expect(int(left_relations[str(right.id)]) == int(right_relations.get(str(left.id), 1000)),
					"%s relationships must be symmetric" % label)


func _find_entity(entities: Array, entity_id: String) -> Dictionary:
	for entity_value in entities:
		var entity: Dictionary = entity_value
		if str(entity.id) == entity_id:
			return entity
	return {}


func _has_event(events: Array, event_id: String) -> bool:
	for event_value in events:
		if event_value is Dictionary and str((event_value as Dictionary).get("id", "")) == event_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
