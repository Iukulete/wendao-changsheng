class_name DialogueSocialBridge
extends RefCounted

## Small seam between dialogue effects and the existing persistent social
## state.  It deliberately writes the same relationship shape consumed by
## NarrativeConsequenceSystem, so later migration can replace this seam with
## the native social implementation without changing dialogue JSON.

const RELATION_FIELDS := [
	"trust", "respect", "desire", "agency", "coercion", "dependency", "corruption",
]


static func apply_relation_delta(state: Dictionary, character_id: String,
		stat: String, delta: int) -> Dictionary:
	var safe_character_id := character_id.strip_edges().left(64)
	var safe_stat := stat.strip_edges().left(64)
	if safe_character_id.is_empty() or safe_stat.is_empty() or not RELATION_FIELDS.has(safe_stat):
		return {"ok": false, "code": "invalid_social_relation_target"}
	var story: Dictionary = state.get("story", {}) if state.get("story", {}) is Dictionary else {}
	var relationships: Dictionary = story.get("relationships", {}) if story.get("relationships", {}) is Dictionary else {}
	var relation: Dictionary = relationships.get(safe_character_id, {}) if \
			relationships.get(safe_character_id, {}) is Dictionary else {}
	if not relation.has("id"):
		relation["id"] = safe_character_id
	if not relation.has("name"):
		relation["name"] = safe_character_id
	if not relation.has("age"):
		relation["age"] = 18
	var minimum := 0 if safe_stat in ["agency", "coercion", "dependency", "corruption"] else -100
	relation[safe_stat] = clampi(int(relation.get(safe_stat, 0)) + delta, minimum, 100)
	relation["last_source"] = "dialogue"
	relationships[safe_character_id] = relation
	story["relationships"] = relationships
	state["story"] = story
	return {"ok": true, "code": "social_relation_updated", "character_id": safe_character_id,
		"stat": safe_stat, "delta": delta, "value": int(relation[safe_stat])}


static func relation(state: Dictionary, character_id: String) -> Dictionary:
	var story: Dictionary = state.get("story", {}) if state.get("story", {}) is Dictionary else {}
	var relationships: Dictionary = story.get("relationships", {}) if story.get("relationships", {}) is Dictionary else {}
	var value: Variant = relationships.get(character_id, {})
	return value.duplicate(true) if value is Dictionary else {}
