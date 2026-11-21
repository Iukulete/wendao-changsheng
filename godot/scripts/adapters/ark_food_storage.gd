extends RefCounted
## Physical chest shortcuts with a read-only deposit preview; no new stock owner.
const Rules = preload("res://scripts/modules/rooms/ark_food_storage.gd")
const Placement = preload("res://scripts/ark_fixture_placement.gd")
var shown_deposit: Dictionary = {}
var cached := {}

func clear() -> void:
	shown_deposit.clear()
	cached.clear()

func forget_hint() -> void:
	shown_deposit.clear()

func fixture(game: Node3D) -> Node3D:
	var box := game._ark_node("BuiltStorage") as Node3D
	if not game.storage_built or not is_instance_valid(box) or box.is_queued_for_deletion() or not box.is_inside_tree() or not box.is_visible_in_tree() or box.process_mode==Node.PROCESS_MODE_DISABLED: return null
	return box

func station(game: Node3D) -> Dictionary:
	var box := fixture(game)
	if box==null: return {}
	var signature := [Engine.get_physics_frames(),box.get_instance_id(),box.global_transform]
	if cached.get("signature")==signature: return cached.result
	var result := {}
	var half: Vector2 = Placement.HALF_SIZES.storage
	var candidates: Array[Vector3] = []
	for offset in [Vector3(0,0,half.y+.44),Vector3(half.x+.44,0,0),Vector3(0,0,-half.y-.44),Vector3(-half.x-.44,0,0)]:
		candidates.append(game.ark_root.to_local(box.to_global(offset)))
	# Prefer the home-facing side, not an apparently clear point isolated in the
	# narrow alley between two fixtures. Four bounded tests, no per-frame A*.
	var boarding: Vector3 = game.RESIDENT_DECK_POSITION
	candidates.sort_custom(func(a: Vector3,b: Vector3) -> bool: return a.distance_squared_to(boarding)<b.distance_squared_to(boarding))
	for target in candidates:
		if game.resident_washing.walk_step_clear(game,target,target) and _use_line_clear(game,game.ark_root.to_global(target),box):
			result = {"node":box,"target":target}
			break
	cached = {"signature":signature,"result":result}
	return result

func accessible(game: Node3D) -> bool:
	var box := fixture(game)
	return box!=null and is_instance_valid(game.player) and game.player.global_position.distance_to(box.global_position)<=2.8 and not game.is_swimming and not game.sailing_mode and not game.building_mode and _use_line_clear(game,game.player.global_position,box)

func _use_line_clear(game: Node3D,from: Vector3,box: Node3D) -> bool:
	var excluded: Array[RID] = game._fixture_collision_rids("storage")
	if is_instance_valid(game.player): excluded.append(game.player.get_rid())
	var query := PhysicsRayQueryParameters3D.create(from+Vector3.UP*.65,box.global_position+Vector3.UP*.65,1,excluded)
	return game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

# Dedicated G/Z/X address the one physical home chest in its ORIGINAL reach.
# They do not replace the ordinary E target or steal its focus ring from an NPC.
func shortcut_available(game: Node3D) -> bool:
	if not game._maintenance_window_focused or game.get_tree().paused or game.get_viewport().gui_get_focus_owner()!=null or game._hud_choice_open(): return false
	if (game.hud_drawer and game.hud_drawer.visible) or (game.world_chart and game.world_chart.visible) or not accessible(game): return false
	# Explicit held maintenance has its own full cost/progress hint; do not hide
	# an unrelated instantaneous food action beneath it.
	return game._maintenance_target().is_empty()

func deposit_preview(game: Node3D) -> Dictionary:
	# Presentation-only projection of Rules.deposit's unchanged soup-first order.
	var room := maxi(0,Rules.CAPACITY-Rules.stock(game.economy))
	var soup := mini(room,game.economy.inventory("player","stew_servings"))
	var shell := mini(room-soup,game.economy.inventory("player","shellfish"))
	var amounts := {}
	if soup>0: amounts["stew_servings"]=soup
	if shell>0: amounts["shellfish"]=shell
	return amounts

func hint(game: Node3D,e_hint: String) -> String:
	var box:=fixture(game)
	if box==null:
		forget_hint()
		return ""
	var amounts:=deposit_preview(game)
	shown_deposit={"node_id":box.get_instance_id(),"transform":box.transform,"amounts":amounts.duplicate()}
	var deposit := "G箱满" if Rules.stock(game.economy)>=Rules.CAPACITY else "G无食可存"
	if not amounts.is_empty():
		deposit="G存"+("%d汤" % amounts.stew_servings if amounts.has("stew_servings") else "")+("%d贝" % amounts.shellfish if amounts.has("shellfish") else "")
	var soup := "Z取1汤" if game.economy.inventory(Rules.OWNER,"stew_servings")>0 else "Z无汤"
	var shell := "X取1贝" if game.economy.inventory(Rules.OWNER,"shellfish")>0 else "X无贝"
	return "%s箱 %s %s %s %d/%d" % [e_hint+"｜" if not e_hint.is_empty() else "",deposit,soup,shell,Rules.stock(game.economy),Rules.CAPACITY]

func transfer(game: Node3D,key: int) -> void:
	if key not in [KEY_G,KEY_Z,KEY_X]: return
	if not shortcut_available(game):
		forget_hint()
		game.message = "先靠近本舟储物箱，看到箱边操作提示再按 G 存食、Z 取汤或 X 取贝；木料仍按 E 存取。"
		game._update_hud()
		return
	var result: Dictionary
	var resource := ""
	if key==KEY_G:
		var box:=fixture(game)
		var current := {"node_id":box.get_instance_id(),"transform":box.transform,"amounts":deposit_preview(game)}
		if shown_deposit != current:
			# Residents may legitimately fetch/deliver between the displayed hint
			# and this key. Never silently transfer a newly different quantity.
			game.message = "储粮或随身食物已有变化；箱边已更新本次存入数量。请看清提示后再按 G，当前没有转移物资。"
			game._update_interaction_hint()
			game._update_hud()
			return
		result = Rules.deposit(game.economy)
	else:
		resource = "stew_servings" if key==KEY_Z else "shellfish"
		result = Rules.withdraw(game.economy,resource)
	if result.ok and not result.get("duplicate",false):
		var amounts: Dictionary = result.get("amounts",{resource:1})
		game._record_world_event("household_food_stored" if key==KEY_G else "household_food_withdrawn",{"container_id":Rules.OWNER,"amounts":amounts,"actual_position":game._position_facts(game.ark_root.to_local(game.player.global_position))})
		game.message = "你把食物放进防潮箱的储粮格，空出随身行囊。" if key==KEY_G else "你从储粮格取出一份热汤，可以带到桌边和大家一起喝。" if key==KEY_Z else "你从储粮格取出一份鲜贝。"
	else: game.message = "随身没有可存的食物，或储粮格已经满了；没有转移物资。" if key==KEY_G else "储粮格没有这份食物，或行囊暂时装不下；没有转移物资。"
	game._save_progress()
	game._update_hud()
	game._update_interaction_hint()
