extends RefCounted
## Bounded template selection/clearance/preview/commit. No new save owner.
const Catalog = preload("res://scripts/modules/construction/ark_home_templates.gd")
const Placement = preload("res://scripts/ark_fixture_placement.gd")

func snapshot(game: Node3D) -> Dictionary:
	var result := {}
	for id in Catalog.COSTS:
		result[id] = {"built":bool(game.get(id+"_built")),"position":game.get(id+"_position"),"turns":0 if id == "shelter" else int(game.get(id+"_quarter_turns"))}
	return result

func _fixture_path(id: String) -> String:
	return "BuiltShelter" if id == "shelter" else "BuiltStorage" if id == "storage" else "BuiltWorkbench"

func _clearance_error(game: Node3D,proposal: Dictionary,requested: Vector3) -> String:
	if game.sailing_mode: return "请停船并离开舵位后施工。"
	if proposal.missing.is_empty(): return "这套家园设施已经齐备，不再扣料或重复搭建。"
	if proposal.anchored and requested.distance_to(proposal.anchor) > .001: return "补齐模板固定沿用现有棚屋，不会移动已有建筑。"
	for id in proposal.kept:
		var actual := game._ark_node(_fixture_path(id)) as Node3D
		if not is_instance_valid(actual) or actual.get_parent() != game.ark_root or not actual.is_inside_tree() or actual.is_queued_for_deletion() or not actual.is_visible_in_tree() or actual.process_mode == Node.PROCESS_MODE_DISABLED: return "已有设施暂不可用，先恢复它再补齐家园。"
	if "shelter" in proposal.missing and not game._is_valid_shelter_position(proposal.anchor): return "棚屋占地无效，或与已有家具重叠。"
	var fixtures: Array[Dictionary] = []
	for id in ["storage","workbench"]:
		if proposal.parts.has(id): fixtures.append(proposal.parts[id])
	var lantern := game._ark_node("LanternMarker") as Node3D
	for fixture in fixtures:
		var half: Vector2 = Placement.half_size(fixture.id,fixture.turns)
		if not Placement.supported(fixture.position,half) or Placement.overlaps(fixture.position,half,proposal.anchor,Vector2(1.5,1.2),.001): return "家具须落在甲板内，并避开棚屋。"
		if lantern and Placement.overlaps(fixture.position,half,lantern.position,Vector2(.18,.18)): return "家具与固定避风灯重叠。"
		if not fixture.existing:
			var shape := BoxShape3D.new()
			shape.size = Vector3(half.x*2-.02,.7,half.y*2-.02)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = Transform3D(Basis(Vector3.UP,game.ark_root.global_rotation.y),game.ark_root.to_global(fixture.position+Vector3(0,.42,0)))
			query.collision_mask = 1
			query.collide_with_areas = false
			if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return "新家具的位置有实体障碍，暂不施工。"
	if fixtures.size() == 2 and Placement.overlaps(fixtures[0].position,Placement.half_size(fixtures[0].id,fixtures[0].turns),fixtures[1].position,Placement.half_size(fixtures[1].id,fixtures[1].turns)): return "新家具与原有布置重叠；可先按F搬移家具，再选择补齐。"
	for actor in [game.player,game.traveler_marker,game.sailmaker_marker]:
		if not is_instance_valid(actor): continue
		var local: Vector3 = game.ark_root.to_local(actor.global_position)
		if absf(local.y) > 2: continue
		var point := Vector2(local.x,local.z)
		var radius := .40 if actor == game.player else .25
		if "shelter" in proposal.missing and Placement.home_wall_contains(point,proposal.anchor,radius): return "有人站在棚墙位置，请留出空间。"
		for fixture in fixtures:
			if fixture.existing: continue
			if Placement.contains_actor(point,fixture.position,Placement.half_size(fixture.id,fixture.turns),radius): return "有人站在新家具位置，请留出空间。"
	# Virtual geometry includes all existing furniture, even legacy nonsolid
	# crates. Exclude their real bodies once, not arbitrary world obstacles.
	var excluded: Array[RID] = game._fixture_collision_rids("workbench")
	excluded.append_array(game._fixture_collision_rids("storage"))
	var blocked := func(point: Vector2,radius: float) -> bool: return game._ark_local_walk_cell_blocked(point,excluded,radius)
	for radius in [.23,.38]:
		var context := Placement.home_grid(proposal.anchor,fixtures,radius,blocked)
		for target in [Vector3(0,.12,1.5),proposal.anchor+Vector3(0,0,1.55),proposal.anchor+Vector3(.72,0,.2),proposal.anchor+game.TIDEKEEPER_REFUGE_REST_OFFSET,proposal.anchor+game.SAILMAKER_REFUGE_REST_OFFSET,Vector3(0,.12,-1.75)]:
			if not game._fixture_grid_reaches(context.grid,context.minimum,context.cell_size,context.start,target): return "请保留棚门、床边、舵位及通往扩建甲板的通路。"
		for fixture in fixtures:
			if not game._fixture_any_side_reachable(context,fixture.position,Placement.half_size(fixture.id,fixture.turns)): return "请为储物箱和工作台留出可达的使用面。"
	return ""

func select(game: Node3D,position: Vector3,workshop: bool) -> Dictionary:
	var current := snapshot(game)
	var first := {}
	for variant in Catalog.LAYOUTS.size():
		var proposal := Catalog.plan("workshop_home" if workshop else "starter_home",current,position,variant)
		if not proposal.ok: return proposal
		var error := _clearance_error(game,proposal,position)
		proposal["error"] = error
		if error.is_empty(): return proposal
		if first.is_empty(): first = proposal
	return first

func layout_error(game: Node3D,position: Vector3,workshop: bool) -> String:
	return str(select(game,position,workshop).get("error","家园方案无效。"))

func start(game: Node3D,workshop: bool) -> void:
	if game.sailing_mode:
		game.message = "掌舵时不能施工。先离开舵位，让仙舟停稳。"
		game._update_hud()
		return
	if game.building_mode: game._cancel_build(false)
	var proposal := Catalog.plan("workshop_home" if workshop else "starter_home",snapshot(game),Vector3(0,.12,0))
	if not proposal.ok or proposal.missing.is_empty():
		game.message = "这套家园设施已经齐备；保留现有布置，不再扣料。"
		game._update_hud()
		return
	game.building_mode = true
	game.build_type = "workshop_home_template" if workshop else "starter_home_template"
	game.build_preview = Node3D.new()
	game.build_preview.name = "WorkshopHomeTemplatePreview" if workshop else "StarterHomeTemplatePreview"
	game.preview_valid_material = game._preview_material(Color("a2d18f"))
	game.preview_invalid_material = game._preview_material(Color("d78277"))
	game.fixture_preview_checked_msec = 0
	game.fixture_preview_checked_position = Vector3(INF,INF,INF)
	game.ark_root.add_child(game.build_preview)
	game.message = "%s%s · 只需 %d 木（本舟可用 %d）\n%s只搭缺少的部分，已有设施、储物和升级不动。左键确认，右键或Esc取消。" % ["补齐：" if proposal.anchored else "模板：",proposal.title,proposal.wood_cost,game._available_build_wood(),"沿现有棚屋固定位置；" if proposal.anchored else "鼠标选择位置；"]
	game._update_build_preview()
	game._update_hud()

func refresh(game: Node3D,position: Vector3,workshop: bool) -> void:
	if position == game.fixture_preview_checked_position and Time.get_ticks_msec()-game.fixture_preview_checked_msec < 200: return
	game.fixture_preview_checked_position = position
	game.fixture_preview_checked_msec = Time.get_ticks_msec()
	var proposal := select(game,position,workshop)
	var old: Dictionary = game.build_preview.get_meta("home_template_proposal",{})
	if not Catalog.same_proposal(old,proposal):
		for child in game.build_preview.get_children():
			game.build_preview.remove_child(child)
			child.queue_free()
		if proposal.get("ok",false):
			if "shelter" in proposal.missing:
				game._add_shelter_template_ghost(game.build_preview)
				_add_use_label(game,"ShelterUseLabel","起居 / 炊事 · 3 木",Vector3(0,2.8,0))
			for id in ["storage","workbench"]:
				if not id in proposal.missing: continue
				var part: Dictionary = proposal.parts[id]
				var half: Vector2 = Placement.half_size(id,part.turns)
				game._add_template_ghost_box(game.build_preview,"Storage" if id == "storage" else "Workbench",Vector3(half.x*2,.84 if id == "storage" else .74,half.y*2),part.position-proposal.anchor+Vector3(0,.42 if id == "storage" else .37,0))
				_add_use_label(game,id+"UseLabel",("储藏" if id == "storage" else "工坊")+" · %d 木" % Catalog.COSTS[id],part.position-proposal.anchor+Vector3(0,1.25,0))
	game.build_preview.set_meta("home_template_proposal",proposal)
	game.build_preview.position = proposal.get("anchor",position)
	game.preview_valid = proposal.get("ok",false) and str(proposal.get("error","invalid")).is_empty() and game._available_build_wood() >= int(proposal.get("wood_cost",0))
	game._set_build_preview_material(game.preview_valid_material if game.preview_valid else game.preview_invalid_material)
	for child in game.build_preview.get_children():
		if child is Label3D: child.modulate = Color("bce8bc") if game.preview_valid else Color("eeafa4")
	game._update_hud()

func _add_use_label(game: Node3D,name_: String,text: String,position: Vector3) -> void:
	var label := Label3D.new()
	label.name = name_
	label.text = text
	label.position = position
	label.font = game.UI_FONT
	label.font_size = 32
	label.pixel_size = .006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	game.build_preview.add_child(label)

func commit(game: Node3D,position: Vector3,workshop: bool) -> bool:
	if not position.is_finite(): return false
	var anchor := Vector3(snappedf(position.x,.5),.12,snappedf(position.z,.5))
	var proposal := select(game,anchor,workshop)
	if not proposal.get("ok",false) or not str(proposal.get("error","invalid")).is_empty():
		game.message = str(proposal.get("error","家园方案无效。"))
		game._update_hud()
		return false
	if game.building_mode and game.build_preview != null and game.build_preview.has_meta("home_template_proposal") and not Catalog.same_proposal(game.build_preview.get_meta("home_template_proposal"),proposal):
		game.fixture_preview_checked_msec = 0
		refresh(game,anchor,workshop)
		game.message = "家中布置已经变化，已重新核对补齐方案；请看清预览后再次确认。"
		game._update_hud()
		return false
	if game._available_build_wood() < proposal.wood_cost:
		game.message = "补齐%s还需 %d 木，本舟可用 %d；预览与取消均不扣料。" % [proposal.title,proposal.wood_cost,game._available_build_wood()]
		game._update_hud()
		return false
	var states := {}
	for id in proposal.missing:
		var part: Dictionary = proposal.parts[id]
		states[id] = {"built":true,"position":game._position_exact(part.position)}
		if id != "shelter": states[id]["quarter_turns"] = part.turns
	var validate := func() -> bool:
		var live := select(game,anchor,workshop)
		return str(live.get("error","invalid")).is_empty() and Catalog.same_proposal(proposal,live)
	if not game._commit_construction({"wood":proposal.wood_cost},states,"build",validate): return false
	var mode := "workshop_home_template" if workshop else "starter_home_template"
	for id in proposal.missing:
		var part: Dictionary = proposal.parts[id]
		game.set(id+"_built",true)
		game.set(id+"_position",part.position)
		if id != "shelter":
			game.set(id+"_quarter_turns",part.turns)
			game.set(id+"_collision_enabled",true)
		game._record_world_event(id+"_built",{"wood_spent":Catalog.COSTS[id],"position":{"x":part.position.x,"z":part.position.z},"construction_mode":mode})
		if id == "shelter": game._build_shelter_at(part.position)
		elif id == "storage": game._build_storage_at(part.position)
		else: game._build_workbench_at(part.position)
	game._record_world_event("home_template_completed",{"template_id":proposal.id,"new_components":proposal.missing.duplicate(),"preserved_components":proposal.kept.duplicate(),"wood_spent":proposal.wood_cost,"existing_layout_preserved":true})
	game._cancel_build(false)
	game.message = "%s%s：只用 %d 木添好缺少的设施。%s；现有储物、家具位置和升级全部保留，居民专用床位仍需另行扩建。" % ["补齐" if not proposal.kept.is_empty() else "建成",proposal.title,proposal.wood_cost,proposal.uses]
	game._save_progress()
	game._update_hud()
	return true

func update_buttons(game: Node3D,buttons: Dictionary) -> void:
	for id in ["starter_home","workshop_home"]:
		var button := buttons.get(id) as Button
		if button == null: continue
		var proposal := Catalog.plan(id,snapshot(game),Vector3(0,.12,0))
		if not proposal.ok: continue
		button.disabled = proposal.missing.is_empty()
		button.text = "%s · 已齐备" % proposal.title if proposal.missing.is_empty() else "%s%s · %d 木" % ["补齐：" if not proposal.kept.is_empty() else "模板：",proposal.title,proposal.wood_cost]
		button.tooltip_text = "%s。预览后确认，只为缺少的设施付料；已有布置不动。\n本舟可用木料 %d；玩家床铺与临时避难不等于居民专用床位。" % [proposal.uses,game._available_build_wood()]
