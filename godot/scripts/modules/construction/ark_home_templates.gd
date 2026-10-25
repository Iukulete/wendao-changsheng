extends RefCounted
## Pure, bounded home proposals. Existing pieces are never moved, repaid or
## rebuilt. Scene clearance and resource ownership belong to the adapters.
const COSTS := {"shelter":3,"storage":2,"workbench":2}
const DEFINITIONS := {
	"starter_home":{"title":"潮棚之家","components":["shelter","storage"],"uses":"避风、玩家床铺、炊事与储藏"},
	"workshop_home":{"title":"起居工坊","components":["shelter","storage","workbench"],"uses":"避风、玩家床铺、炊事、储藏与工作台"},
}
const LAYOUTS := [
	{"storage":Vector3(2,0,1.5),"workbench":Vector3(2,0,-.5)},
	{"storage":Vector3(2,0,-1.5),"workbench":Vector3(2,0,.5)},
]

static func plan(id: String,present: Dictionary,position: Vector3,variant: int = 0) -> Dictionary:
	if not DEFINITIONS.has(id) or not position.is_finite() or variant < 0 or variant >= LAYOUTS.size(): return {"ok":false,"error":"无效家园方案。"}
	for key in COSTS:
		var part: Variant = present.get(key)
		if not part is Dictionary or not part.get("built") is bool or not part.get("position") is Vector3 or not part.position.is_finite() or not part.get("turns") is int or part.turns < 0 or part.turns > 3: return {"ok":false,"error":"家园设施状态无效。"}
	var anchor: Vector3 = present.shelter.position if present.shelter.built else position
	var definition: Dictionary = DEFINITIONS[id]
	var missing: Array[String] = []
	var kept: Array[String] = []
	var parts := {}
	var cost := 0
	for key in COSTS:
		var existing: bool = present[key].built
		if not existing and not key in definition.components: continue
		var offset: Vector3 = Vector3.ZERO if key == "shelter" else LAYOUTS[variant][key]
		# New starter homes reserve the same future workbench bay as workshops.
		# Existing older crates keep their exact location, even if a later upgrade
		# requires the player to move one explicitly with the furniture editor.
		parts[key] = {"id":key,"position":present[key].position if existing else anchor+offset,"turns":present[key].turns if existing else (1 if key == "workbench" else 0),"existing":existing}
		if existing: kept.append(key)
		else:
			missing.append(key)
			cost += COSTS[key]
	return {"ok":true,"id":id,"title":definition.title,"uses":definition.uses,"anchor":anchor,"variant":variant,"parts":parts,"missing":missing,"kept":kept,"wood_cost":cost,"anchored":present.shelter.built}

static func same_proposal(a: Dictionary,b: Dictionary) -> bool:
	if not a.get("ok",false) or not b.get("ok",false): return false
	for key in ["id","anchor","wood_cost","missing","kept","parts"]:
		if a.get(key) != b.get(key): return false
	return true
