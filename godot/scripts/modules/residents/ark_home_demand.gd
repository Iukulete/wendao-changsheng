extends RefCounted
## Read-only household demand. No stock, task, timer, save or permission owner.
const Templates = preload("res://scripts/modules/construction/ark_home_templates.gd")
const Modern = preload("res://scripts/modules/modern/ark_modern_utilities.gd")
const FOOD_TARGET := 2
const WOOD_RESERVE := 2
const TITLES := {"repair_wood":"为家中修缮补木","build_storage":"为防潮储箱备木","build_workbench":"为工作台备木","modern_install":"为日照净水角备木","wood_reserve":"补家园备用木料","food_reserve":"补家中两份口粮","stocked":"家中储备已够，先休息","await_repair":"修材已够，等家园修复","repair_requires_storage":"先备可用储箱，再安排修材采集","storage_unavailable":"储箱暂不可用，等待恢复","preference_wood":"按约定先收木料","preference_shellfish":"按约定先收鲜贝","preference_fallback":"优先物资不可采，收另一种可用物资"}

static func plan(facts: Dictionary) -> Dictionary:
	for key in ["storage_built","storage_ready","workbench_built","modern_ready"]:
		if not facts.get(key) is bool: return {"ok":false,"code":"facts"}
	for key in ["wood_available","stored_wood","food_available","damage_count"]:
		var value: Variant = facts.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value<0 or value!=floor(float(value)) or value>2147483647: return {"ok":false,"code":"facts"}
	if facts.damage_count>2 or facts.stored_wood>facts.wood_available: return {"ok":false,"code":"facts"}
	var wood_target := WOOD_RESERVE
	var wood_reason := "wood_reserve"
	if not facts.storage_built:
		wood_target = Templates.COSTS.storage
		wood_reason = "build_storage"
	elif not facts.workbench_built:
		wood_target = Templates.COSTS.workbench
		wood_reason = "build_workbench"
	elif facts.modern_ready:
		wood_target = Modern.WOOD_COST
		wood_reason = "modern_install"
	var wood_need := maxi(0,wood_target-int(facts.wood_available))
	var food_need := maxi(0,FOOD_TARGET-int(facts.food_available))
	# A worker repairs from the household crate, never the player's backpack.
	var repair_need := maxi(0,int(facts.damage_count)-int(facts.stored_wood))
	var result := {"ok":true,"wood_target":wood_target,"food_target":FOOD_TARGET,"wood_need":wood_need,"food_need":food_need,"repair_need":repair_need,"damage_count":int(facts.damage_count),"wood_available":int(facts.wood_available),"food_available":int(facts.food_available),"wood_reason":wood_reason,"shellfish_reason":"food_reserve","priorities":{"wood":-1,"shellfish":-1},"reason":"stocked","blocked":false}
	if facts.storage_built and not facts.storage_ready:
		result.reason = "storage_unavailable"
		result.blocked = true
	elif facts.damage_count>0:
		result.blocked = not (facts.storage_ready and repair_need>0)
		result.reason = "repair_requires_storage" if not facts.storage_ready else "await_repair" if result.blocked else "repair_wood"
		result.wood_reason = "repair_wood"
		if not result.blocked: result.priorities.wood = 0
	elif not facts.storage_built and wood_need>0:
		result.priorities.wood = 0
		if food_need>0: result.priorities.shellfish = 1
		result.reason = wood_reason
	elif food_need>0:
		result.priorities.shellfish = 0
		if wood_need>0: result.priorities.wood = 1
		result.reason = "food_reserve"
	elif wood_need>0:
		result.priorities.wood = 0
		result.reason = wood_reason
	return result

static func priority(review: Dictionary,policy: String,resource: String) -> int:
	if not review.get("ok",false) or review.blocked or resource not in ["wood","shellfish"] or policy not in ["balanced","wood_first","shellfish_first"]: return -1
	if review.damage_count>0 or policy=="balanced": return int(review.priorities[resource])
	return 0 if resource==("wood" if policy=="wood_first" else "shellfish") else 1

static func reason(review: Dictionary,policy: String,resource: String) -> String:
	if priority(review,policy,resource)<0: return ""
	if review.damage_count>0: return "repair_wood"
	if policy=="balanced": return str(review.wood_reason if resource=="wood" else review.shellfish_reason)
	return "preference_"+resource if priority(review,policy,resource)==0 else "preference_fallback"
