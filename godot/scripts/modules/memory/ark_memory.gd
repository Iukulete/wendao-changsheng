extends RefCounted
## Recorded facts only. A missing event is unknown, never an invented memory.
const MAX_EVENTS := 256
var _events: Array[Dictionary] = []
var _sequence := 0
var _durable: Dictionary = {}

func record(event_id: String, facts: Dictionary, day: int, period: int) -> Dictionary:
	if event_id.is_empty() or day < 0 or period < 0 or _sequence >= 2147483647 or not _plain(facts):
		return {}
	_sequence += 1
	var event := {"sequence": _sequence, "id": event_id, "day": day, "period": period, "facts": facts.duplicate(true)}
	_events.append(event)
	_durable[event_id] = event.duplicate(true)
	while _events.size() > MAX_EVENTS:
		_events.pop_front()
	return event.duplicate(true)

func events() -> Array[Dictionary]:
	return _events.duplicate(true)

func sequence() -> int:
	return _sequence

func latest(event_id: String) -> Dictionary:
	if _durable.has(event_id):
		return {"known": true, "event": _durable[event_id].duplicate(true)}
	return {"known": false, "event": {}}

func snapshot() -> Dictionary:
	return {"version": 1, "sequence": _sequence, "events": _events.duplicate(true), "durable": _durable.duplicate(true)}

func import_legacy(saved_events: Array, saved_sequence: int) -> bool:
	return restore({"version": 1, "sequence": saved_sequence, "events": saved_events})

func restore(saved: Dictionary) -> bool:
	if saved.get("version", 0) != 1 or not _integer(saved.get("sequence")) or not saved.get("events") is Array:
		return false
	var candidate: Array[Dictionary] = []
	var previous := 0
	for value in saved.events:
		if not value is Dictionary or not _plain(value):
			return false
		if not value.get("id") is String or value.id.is_empty() or not value.get("facts") is Dictionary:
			return false
		for key in ["sequence", "day", "period"]:
			if not _integer(value.get(key)):
				return false
		if int(value.sequence) <= previous:
			return false
		previous = int(value.sequence)
		candidate.append(value.duplicate(true))
	if int(saved.sequence) < previous:
		return false
	var durable: Dictionary = {}
	if saved.has("durable"):
		if not saved.durable is Dictionary or not _plain(saved.durable):
			return false
		for id in saved.durable:
			var event: Variant = saved.durable[id]
			if not _valid_event(event) or event.id != id or int(event.sequence) > int(saved.sequence):
				return false
			durable[id] = event.duplicate(true)
	for event in candidate:
		if saved.has("durable"):
			if not durable.has(event.id) or int(durable[event.id].sequence) < int(event.sequence):
				return false
			if int(durable[event.id].sequence) == int(event.sequence) and durable[event.id] != event:
				return false
		elif not durable.has(event.id) or int(durable[event.id].sequence) < int(event.sequence):
			durable[event.id] = event.duplicate(true)
	_durable = durable
	_events = candidate.slice(maxi(0, candidate.size() - MAX_EVENTS))
	_sequence = int(saved.sequence)
	return true

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 2147483647.0 and float(value) == floor(float(value))

static func _plain(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	if value == null or value is bool or value is String or value is int:
		return true
	if value is float:
		return is_finite(value)
	if value is Dictionary:
		for key in value:
			if not key is String or not _plain(value[key], depth + 1):
				return false
		return true
	if value is Array:
		for item in value:
			if not _plain(item, depth + 1):
				return false
		return true
	return false

## Exact equality for plain persisted facts: JSON changes integers to floats,
## but never equates booleans, strings, or nearby coordinates with numbers.
static func facts_equal(left: Variant, right: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	if (left is int and right is float) or (left is float and right is int):
		var integer: int = left if left is int else right
		var number: float = right if right is float else left
		# Compare through the integer only after range/integrality checks; casting
		# the integer to float would collapse distinct values above 2^53.
		return is_finite(number) and number >= -9223372036854775808.0 and number < 9223372036854775808.0 and number == floor(number) and int(number) == integer
	if typeof(left) != typeof(right):
		return false
	if left is Dictionary:
		if left.size() != right.size():
			return false
		for key in left:
			if not key is String or not right.has(key) or not facts_equal(left[key], right[key], depth + 1):
				return false
		return true
	if left is Array:
		if left.size() != right.size():
			return false
		for index in range(left.size()):
			if not facts_equal(left[index], right[index], depth + 1):
				return false
		return true
	return _plain(left, depth) and _plain(right, depth) and left == right

static func _valid_event(value: Variant) -> bool:
	if not value is Dictionary or not _plain(value) or not value.get("id") is String or value.id.is_empty() or not value.get("facts") is Dictionary:
		return false
	for key in ["sequence", "day", "period"]:
		if not _integer(value.get(key)):
			return false
	return int(value.sequence) > 0
