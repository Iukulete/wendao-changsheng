extends SceneTree
const Demand = preload("res://scripts/modules/residents/ark_home_demand.gd")
func _initialize() -> void:
	var facts := {"storage_built":true,"storage_ready":true,"workbench_built":true,"modern_ready":false,"wood_available":0,"stored_wood":0,"food_available":0,"damage_count":0}
	var original := facts.duplicate(true)
	var review := Demand.plan(facts)
	assert(review.reason=="food_reserve" and Demand.priority(review,"balanced","shellfish")==0 and Demand.priority(review,"balanced","wood")==1)
	assert(facts==original,"review does not write inventory, facts, permission, timers or jobs")
	facts.food_available = 2
	review = Demand.plan(facts)
	assert(review.reason=="wood_reserve" and review.wood_need==2 and Demand.priority(review,"balanced","shellfish")==-1)
	facts.wood_available = 2
	facts.stored_wood = 2
	review = Demand.plan(facts)
	assert(review.reason=="stocked" and Demand.priority(review,"balanced","wood")==-1 and Demand.priority(review,"balanced","shellfish")==-1)
	assert(Demand.priority(review,"wood_first","wood")==0 and Demand.priority(review,"shellfish_first","shellfish")==0,"explicit player preferences still collect above the automatic comfort stock")
	assert(Demand.reason(review,"wood_first","shellfish")=="preference_fallback")
	facts.modern_ready = true
	review = Demand.plan(facts)
	assert(review.reason=="modern_install" and review.wood_target==4 and review.wood_need==2,"only a truly buildable next modern installation changes the target")
	facts.damage_count = 2
	review = Demand.plan(facts)
	assert(review.blocked and review.reason=="await_repair","do not abandon a funded repair for elective upgrades")
	facts.stored_wood = 0
	facts.wood_available = 20
	review = Demand.plan(facts)
	assert(not review.blocked and review.repair_need==2 and Demand.priority(review,"balanced","wood")==0 and Demand.priority(review,"shellfish_first","shellfish")==-1,"actual repairs need stored wood, not the player's private material")
	facts.storage_ready = false
	review = Demand.plan(facts)
	assert(review.blocked and review.reason=="storage_unavailable")
	facts.storage_built = false
	review = Demand.plan(facts)
	assert(review.blocked and review.reason=="repair_requires_storage")
	facts.damage_count = 0
	facts.modern_ready = false
	facts.workbench_built = false
	facts.wood_available = 0
	review = Demand.plan(facts)
	assert(review.reason=="build_storage" and review.wood_target==2 and Demand.priority(review,"balanced","wood")==0)
	facts.storage_built = true
	facts.storage_ready = true
	review = Demand.plan(facts)
	assert(review.reason=="build_workbench" and review.wood_target==2)
	for mutation in [{"storage_ready":1},{"food_available":-1},{"wood_available":0.5},{"stored_wood":1},{"damage_count":3},{"modern_ready":"true"}]:
		var bad := facts.duplicate(true)
		bad.merge(mutation,true)
		assert(not Demand.plan(bad).ok,"malformed facts never schedule a trip")
	for index in 1000:
		var copy := facts.duplicate(true)
		var a := Demand.plan(copy)
		assert(a==Demand.plan(JSON.parse_string(JSON.stringify(copy))))
		assert(copy==facts and a.size()==14,"review stays bounded and deterministic without a growing planner ledger")
	print("ARK_HOME_DEMAND_TEST_OK: real-stock demand priorities, funded repair safety, optional modern target, player preferences, JSON facts and 1000 read-only projections")
	quit()
