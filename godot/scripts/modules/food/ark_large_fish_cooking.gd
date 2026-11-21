extends RefCounted
## Independent manual 1-large-fish -> 3-soup recipe. No pantry auto-withdrawal.
const Bait = preload("res://scripts/modules/leisure/ark_bait_fishing.gd")
const STREAM := Bait.COOK
static func next(economy: RefCounted) -> int: return Bait.next_cook(economy)
static func cook(economy: RefCounted, sequence: int) -> Dictionary: return Bait.cook(economy, sequence)
static func matches_save(state: Dictionary) -> bool: return Bait.matches_save(state)
