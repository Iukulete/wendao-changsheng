class_name DialogueConditionEvaluator
extends RefCounted

## Conditions are data, not script expressions.  Every authored predicate is
## evaluated against the current save state with a small, auditable operator
## set.

static func evaluate(condition: Variant, state: Dictionary) -> bool:
	if condition == null:
		return true
	if not condition is Dictionary:
		return false
	var predicate: Dictionary = condition
	if predicate.is_empty():
		return true
	var op := str(predicate.get("op", ""))
	if op == "all":
		var args: Variant = predicate.get("args", [])
		if not args is Array:
			return false
		for child in args as Array:
			if not evaluate(child, state):
				return false
		return true
	if op == "any":
		var args: Variant = predicate.get("args", [])
		if not args is Array or (args as Array).is_empty():
			return false
		for child in args as Array:
			if evaluate(child, state):
				return true
		return false
	if op == "not":
		return not evaluate(predicate.get("arg", {}), state)
	if op == "flag":
		var flags := _story_dictionary(state, "flags")
		return _compare(flags.get(str(predicate.get("flag", "")), false), predicate)
	if op == "relation":
		var character_id := str(predicate.get("character_id", ""))
		var relation_map := _story_dictionary(state, "relationships")
		var relation_value: Variant = relation_map.get(character_id, {})
		var relation: Dictionary = relation_value if relation_value is Dictionary else {}
		return _compare(relation.get(str(predicate.get("stat", "trust")), 0), predicate)
	if op == "reputation" or op == "karma":
		var player: Dictionary = state.get("player", {}) if state.get("player", {}) is Dictionary else {}
		return _compare(player.get(op, 0), predicate)
	if op == "stat":
		var player: Dictionary = state.get("player", {}) if state.get("player", {}) is Dictionary else {}
		return _compare(player.get(str(predicate.get("stat", "")), 0), predicate)
	if op == "variable":
		var dialogue: Dictionary = state.get("dialogue", {}) if state.get("dialogue", {}) is Dictionary else {}
		var variables: Dictionary = dialogue.get("variables", {}) if dialogue.get("variables", {}) is Dictionary else {}
		return _compare(variables.get(str(predicate.get("name", ""))), predicate)
	if op == "generation":
		return _compare(state.get("generation", 1), predicate)
	return false


static func _story_dictionary(state: Dictionary, field: String) -> Dictionary:
	var story_value: Variant = state.get("story", {})
	var story: Dictionary = story_value if story_value is Dictionary else {}
	var field_value: Variant = story.get(field, {})
	return field_value if field_value is Dictionary else {}


static func _compare(actual: Variant, predicate: Dictionary) -> bool:
	var operator := str(predicate.get("operator", "=="))
	var expected: Variant = predicate.get("value")
	if operator == "exists":
		return actual != null
	if typeof(actual) == TYPE_BOOL or typeof(expected) == TYPE_BOOL:
		var actual_bool := bool(actual)
		var expected_bool := bool(expected)
		return _compare_numbers(int(actual_bool), int(expected_bool), operator)
	if _is_numeric(actual) and _is_numeric(expected):
		return _compare_numbers(float(actual), float(expected), operator)
	var actual_text := str(actual)
	var expected_text := str(expected)
	match operator:
		"==": return actual_text == expected_text
		"!=": return actual_text != expected_text
		"contains": return actual_text.contains(expected_text)
		"begins_with": return actual_text.begins_with(expected_text)
	return false


static func _compare_numbers(actual: float, expected: float, operator: String) -> bool:
	match operator:
		"==": return is_equal_approx(actual, expected)
		"!=": return not is_equal_approx(actual, expected)
		">": return actual > expected
		">=": return actual >= expected
		"<": return actual < expected
		"<=": return actual <= expected
	return false


static func _is_numeric(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
