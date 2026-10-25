extends SceneTree
const Catalog = preload("res://scripts/modules/construction/ark_home_templates.gd")
func _initialize() -> void:
	var empty := {}
	for id in Catalog.COSTS: empty[id] = {"built":false,"position":Vector3.ZERO,"turns":0}
	var origin := Vector3(0,.12,0)
	var starter := Catalog.plan("starter_home",empty,origin)
	var workshop := Catalog.plan("workshop_home",empty,origin)
	assert(starter.ok and starter.wood_cost == 5 and starter.missing == ["shelter","storage"])
	assert(workshop.ok and workshop.wood_cost == 7 and workshop.parts.workbench.turns == 1)
	assert(starter.parts.storage.position == Vector3(2,.12,1.5))
	assert(workshop.parts.storage.position == Vector3(2,.12,1.5) and workshop.parts.workbench.position == Vector3(2,.12,-.5))
	var present := empty.duplicate(true)
	present.shelter = {"built":true,"position":origin,"turns":0}
	var upgrade := Catalog.plan("workshop_home",present,Vector3(4,.12,4))
	assert(upgrade.anchored and upgrade.anchor == origin and upgrade.wood_cost == 4 and not "shelter" in upgrade.missing)
	present.storage = {"built":true,"position":Vector3(2,.12,-1.5),"turns":2}
	var saved := present.duplicate(true)
	var partial := Catalog.plan("workshop_home",present,origin,1)
	assert(partial.wood_cost == 2 and partial.missing == ["workbench"] and partial.parts.storage.position == present.storage.position and partial.parts.storage.turns == 2)
	assert(partial.parts.workbench.position == Vector3(2,.12,.5) and present == saved,"planning is read-only and preserves existing position/turns")
	assert(Catalog.same_proposal(partial,Catalog.plan("workshop_home",present,origin,1)))
	var changed := partial.duplicate(true)
	changed.parts.workbench.position.x += .5
	assert(not Catalog.same_proposal(partial,changed),"stale layout is not the confirmed proposal")
	present.workbench = {"built":true,"position":Vector3(2,.12,.5),"turns":1}
	var complete := Catalog.plan("workshop_home",present,origin)
	assert(complete.missing.is_empty() and complete.wood_cost == 0)
	assert(not Catalog.plan("invented",present,origin).ok and not Catalog.plan("starter_home",present,Vector3.INF).ok)
	present.storage.built = "true"
	assert(not Catalog.plan("starter_home",present,origin).ok,"malformed facts cannot become a plan")
	print("ARK_HOME_TEMPLATE_PLAN_TEST_OK:")
	quit()
