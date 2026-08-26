class_name LegacyEventAdapter
extends RefCounted

## Transitional adapter: old three-choice events can be rendered by the new
## dialogue UI before their authored consequences are migrated to native
## graph nodes.  It does not mutate events_v014.json.

static func to_dialogue_scene(event: Dictionary) -> Dictionary:
	var event_id := str(event.get("id", "legacy_event"))
	var character_id := str(event.get("character_id", "protagonist"))
	var nodes: Array = [
		{
			"id": "legacy_line",
			"type": "line",
			"speaker_id": character_id,
			"expression": "stern",
			"outfit": "default",
			"text": str(event.get("description", event.get("title", "时代事件"))),
			"next": "legacy_choices",
		},
	]
	var choices: Array = []
	for index in range((event.get("choices", []) as Array).size()):
		var choice_value: Variant = (event.get("choices", []) as Array)[index]
		if not choice_value is Dictionary:
			continue
		var choice: Dictionary = choice_value
		var choice_id := str(choice.get("id", "legacy_choice_%d" % index))
		var end_id := "legacy_end_%d" % index
		choices.append({
			"id": choice_id,
			"text": str(choice.get("text", "继续")),
			"next": end_id,
		})
		nodes.append({
			"id": end_id,
			"type": "end",
			"result": str(choice.get("outcome", "legacy_choice_resolved")),
		})
	nodes.insert(1, {
		"id": "legacy_choices",
		"type": "choice",
		"choices": choices,
		})
	return {
		"schema_version": 1,
		"scene_id": "legacy_%s" % event_id,
		"title": str(event.get("title", "时代事件")),
		"entry_node": "legacy_line",
		"participants": [character_id],
		"nodes": nodes,
	}
