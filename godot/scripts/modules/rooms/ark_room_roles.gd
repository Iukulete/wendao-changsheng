extends RefCounted
## Fixed-template capabilities, independent of Nodes and jobs. Free-form enclosed
## room recognition is intentionally not claimed by this initial catalog.
const ROLES := {
	"refuge":{"title":"起居避风","requires":["shelter"]},
	"storage":{"title":"储藏","requires":["storage"]},
	"workshop":{"title":"工坊","requires":["shelter","storage","workbench"]},
	"galley":{"title":"炊事","requires":["shelter","hearth"]},
	"berth":{"title":"甲板卧铺","requires":["extension","berth"]},
	"guest_cabin":{"title":"独立卧舱","requires":["extension","guest_cabin"]},
}
static func available(role: String,facts: Dictionary) -> bool:
	if not ROLES.has(role): return false
	for required in ROLES[role].requires:
		var value: Variant = facts.get(required)
		if not value is bool or not value: return false
	return true

static func evaluate(facts: Dictionary) -> Dictionary:
	var result := {}
	for role in ROLES: result[role] = available(role,facts)
	return result
