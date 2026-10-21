extends RefCounted

## Shared deck-local fixture geometry. Quarter turns avoid drift in saves and previews.
const HALF_SIZES := {"storage": Vector2(0.49, 0.43), "workbench": Vector2(0.56, 0.39)}
const ACTOR_RADIUS := 0.23

static func normalize_turns(turns: int) -> int:
	return posmod(turns, 4)

static func saved_turns(value: Variant) -> int:
	if value is int:
		return normalize_turns(value)
	if value is float and is_finite(value):
		return normalize_turns(int(fmod(value, 4.0)))
	return 0

static func half_size(id: String, turns: int) -> Vector2:
	var size: Vector2 = HALF_SIZES.get(id, Vector2.ZERO)
	return Vector2(size.y, size.x) if normalize_turns(turns) % 2 else size

static func overlaps(a: Vector3, a_half: Vector2, b: Vector3, b_half: Vector2, margin: float = 0.08) -> bool:
	return absf(a.x - b.x) < a_half.x + b_half.x + margin and absf(a.z - b.z) < a_half.y + b_half.y + margin

static func contains_actor(point: Vector2, position: Vector3, half: Vector2, radius: float = ACTOR_RADIUS) -> bool:
	return absf(point.x - position.x) < half.x + radius and absf(point.y - position.z) < half.y + radius

static func supported(position: Vector3, half: Vector2) -> bool:
	# Initial furniture editing deliberately stays on the original load-bearing deck.
	# Extension beds/cabins and dismantling retain their existing independent lifecycle.
	return absf(position.x) + half.x <= 2.7 and absf(position.z) + half.y <= 1.95

static func approach(position: Vector3, id: String, turns: int) -> Vector3:
	var original: Vector2 = HALF_SIZES.get(id, Vector2.ZERO)
	return position + Vector3(0.0, 0.0, original.y + 0.42).rotated(Vector3.UP, normalize_turns(turns) * PI / 2.0)
