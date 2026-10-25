extends RefCounted
## A no-stakes household game. Owns only cards and bounded round history;
## never inventory, wall time, NPC navigation, presentation or file access.
const MAX_ROUNDS := 1000000
const OPPONENTS := ["tidekeeper", "sailmaker"]
const RESULTS := ["player_win", "resident_win", "push"]
const FIELDS := ["version", "phase", "round", "opponent", "deck", "cursor", "player", "resident", "result", "wins", "losses", "pushes", "history"]
var _state: Dictionary = _empty()

static func _empty() -> Dictionary:
	return {"version": 1, "phase": "idle", "round": 0, "opponent": "", "deck": [], "cursor": 0, "player": [], "resident": [], "result": "", "wins": 0, "losses": 0, "pushes": 0, "history": []}

static func score(cards: Array) -> int:
	var total := 0
	var aces := 0
	for card in cards:
		var rank := int(card) % 13 + 1
		if rank == 1:
			total += 11
			aces += 1
		else:
			total += mini(rank, 10)
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total

func begin(opponent: String, seed_value: int) -> bool:
	if _state.phase == "playing" or not opponent in OPPONENTS or int(_state.round) >= MAX_ROUNDS:
		return false
	var deck: Array = range(52)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(51, 0, -1):
		var other := rng.randi_range(0, index)
		var card: int = deck[index]
		deck[index] = deck[other]
		deck[other] = card
	_state.merge({"phase": "playing", "round": int(_state.round) + 1, "opponent": opponent,
		"deck": deck, "cursor": 4, "player": [deck[0], deck[2]], "resident": [deck[1], deck[3]], "result": ""}, true)
	if score(_state.player) == 21 or score(_state.resident) == 21:
		_settle()
	return true

func hit() -> bool:
	if _state.phase != "playing": return false
	_state.player.append(_draw())
	if score(_state.player) > 21:
		_settle()
	elif score(_state.player) == 21:
		stand()
	return true

func stand() -> bool:
	if _state.phase != "playing": return false
	# Stand on all17s, including soft17. No hidden difficulty or result rigging.
	while score(_state.resident) < 17:
		_state.resident.append(_draw())
	_settle()
	return true

func _draw() -> int:
	var card: int = _state.deck[int(_state.cursor)]
	_state.cursor = int(_state.cursor) + 1
	return card

static func _result(player: Array, resident: Array) -> String:
	var p := score(player)
	var r := score(resident)
	if p > 21: return "resident_win"
	if r > 21: return "player_win"
	var pn := p == 21 and player.size() == 2
	var rn := r == 21 and resident.size() == 2
	if pn != rn: return "player_win" if pn else "resident_win"
	return "push" if p == r else "player_win" if p > r else "resident_win"

func _settle() -> void:
	if _state.phase != "playing": return
	_state.phase = "settled"
	_state.result = _result(_state.player, _state.resident)
	var counter := "wins" if _state.result == "player_win" else "losses" if _state.result == "resident_win" else "pushes"
	_state[counter] = int(_state[counter]) + 1
	_state.history.append({"round": _state.round, "opponent": _state.opponent, "result": _state.result})
	while _state.history.size() > 3: _state.history.pop_front()

func snapshot() -> Dictionary:
	return _state.duplicate(true)

func view() -> Dictionary:
	var result := _state.duplicate(true)
	result.erase("deck")
	result.erase("cursor")
	if result.phase == "playing":
		result.resident = [result.resident[0], -1]
		result.resident_score = score([result.resident[0]])
	else:
		result.resident_score = score(result.resident)
	result.player_score = score(result.player)
	return result

func restore(saved: Dictionary) -> bool:
	if not valid(saved): return false
	_state = saved.duplicate(true)
	for field in ["version", "round", "cursor", "wins", "losses", "pushes"]: _state[field] = int(_state[field])
	for field in ["deck", "player", "resident"]:
		for index in range(_state[field].size()): _state[field][index] = int(_state[field][index])
	for row in _state.history: row.round = int(row.round)
	return true

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high

static func valid(s: Dictionary) -> bool:
	if s.size() != FIELDS.size(): return false
	for field in FIELDS:
		if not s.has(field): return false
	if not _integer(s.version, 1, 1) or not s.phase is String or not s.phase in ["idle", "playing", "settled"]: return false
	for key in ["round", "wins", "losses", "pushes"]:
		if not _integer(s[key], 0, MAX_ROUNDS): return false
	if not s.opponent is String or not s.result is String: return false
	for key in ["deck", "player", "resident", "history"]:
		if not s[key] is Array: return false
	if not _integer(s.cursor, 0, 52): return false
	if s.phase == "idle":
		return int(s.round) == 0 and int(s.cursor) == 0 and int(s.wins) + int(s.losses) + int(s.pushes) == 0 and s.opponent == "" and s.result == "" and s.deck.is_empty() and s.player.is_empty() and s.resident.is_empty() and s.history.is_empty()
	if int(s.round) < 1 or not s.opponent in OPPONENTS or s.deck.size() != 52: return false
	var seen: Dictionary = {}
	for card in s.deck:
		if not _integer(card, 0, 51) or seen.has(int(card)): return false
		seen[int(card)] = true
	if s.player.size() < 2 or s.resident.size() < 2 or s.player.size() > 22 or s.resident.size() > 22: return false
	if int(s.cursor) != s.player.size() + s.resident.size(): return false
	var expected_player: Array = [s.deck[0], s.deck[2]]
	var expected_resident: Array = [s.deck[1], s.deck[3]]
	expected_player.append_array(s.deck.slice(4, 4 + s.player.size() - 2))
	expected_resident.append_array(s.deck.slice(4 + s.player.size() - 2, int(s.cursor)))
	for key in ["player", "resident"]:
		for card in s[key]:
			if not _integer(card, 0, 51): return false
	if s.player != expected_player or s.resident != expected_resident: return false
	# All intermediate player decisions were legal; 21 or bust cannot request
	# another card. Likewise the resident cannot draw at or above17.
	for count in range(2, s.player.size()):
		if score(s.player.slice(0, count)) >= 21: return false
	for count in range(2, s.resident.size()):
		if score(s.resident.slice(0, count)) >= 17: return false
	var completed := int(s.wins) + int(s.losses) + int(s.pushes)
	if s.phase == "playing":
		if s.result != "" or s.resident.size() != 2 or score(s.player) >= 21 or score(s.resident) == 21: return false
		if completed != int(s.round) - 1: return false
	else:
		if completed != int(s.round) or not s.result in RESULTS or s.result != _result(s.player, s.resident): return false
		var natural: bool = (score(s.player) == 21 and s.player.size() == 2) or (score(s.resident) == 21 and s.resident.size() == 2)
		if natural and (s.player.size() != 2 or s.resident.size() != 2): return false
		if score(s.player) > 21 and s.resident.size() != 2: return false
		if not natural and score(s.player) <= 21 and score(s.resident) < 17: return false
	if s.history.size() != mini(completed, 3): return false
	var counted := {"player_win": 0, "resident_win": 0, "push": 0}
	for index in range(s.history.size()):
		var row: Variant = s.history[index]
		if not row is Dictionary or row.size() != 3: return false
		if not _integer(row.get("round"), 1, MAX_ROUNDS) or int(row.round) != completed - s.history.size() + index + 1: return false
		if not row.get("opponent") is String or not row.opponent in OPPONENTS or not row.get("result") is String or not row.result in RESULTS: return false
		counted[row.result] += 1
	if counted.player_win > int(s.wins) or counted.resident_win > int(s.losses) or counted.push > int(s.pushes): return false
	if s.phase == "settled" and (s.history.back().opponent != s.opponent or s.history.back().result != s.result): return false
	return true
