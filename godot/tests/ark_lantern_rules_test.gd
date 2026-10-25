extends SceneTree
const Table = preload("res://scripts/modules/leisure/ark_lantern_table.gd")

func _initialize() -> void:
	assert(Table.score([0, 13, 26]) == 13)
	assert(Table.score([0, 9]) == 21)
	assert(Table.score([0, 13, 8]) == 21)
	var table = Table.new()
	assert(Table.valid(table.snapshot()))
	for seed_value in range(2000):
		assert(table.begin("tidekeeper" if seed_value % 2 == 0 else "sailmaker", seed_value))
		assert(Table.valid(table.snapshot()))
		while table.view().phase == "playing":
			var before: Dictionary = table.snapshot()
			var restored = Table.new()
			assert(restored.restore(JSON.parse_string(JSON.stringify(before))))
			assert(restored.view() == table.view(), "JSON restore preserves exact dealt hand and hidden-card view")
			assert(not table.begin("tidekeeper", 23), "an unfinished round cannot be rerolled")
			if Table.score(before.player) < 16:
				assert(table.hit() and restored.hit())
			else:
				assert(table.stand() and restored.stand())
			assert(table.snapshot() == restored.snapshot(), "restore cannot reshuffle the next card")
			assert(Table.valid(table.snapshot()))
		var settled: Dictionary = table.snapshot()
		assert(not table.hit() and not table.stand() and table.snapshot() == settled)
		for mutation in ["duplicate", "cursor", "wrong_hand", "result", "counter", "history", "unknown", "nan"]:
			var bad: Dictionary = settled.duplicate(true)
			match mutation:
				"duplicate": bad.deck[1] = bad.deck[0]
				"cursor": bad.cursor += 1
				"wrong_hand": bad.player[0] = bad.deck[1]
				"result": bad.result = "made_up"
				"counter": bad.wins += 1
				"history": bad.history.clear()
				"unknown": bad.extra = true
				"nan": bad.round = NAN
			assert(not table.restore(bad) and table.snapshot() == settled, mutation + " restore must be atomic")
	assert(table.snapshot().round == 2000 and table.snapshot().history.size() == 3)
	print("ARK_LANTERN_RULES_TEST_OK: 2000 fixed-deck rounds; aces; hidden card; JSON next-card parity; no reroll/duplicate settlement; strict atomic malformed restore; bounded history; no economy dependency")
	quit(0)
