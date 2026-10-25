extends RefCounted
## Physical chest access plus a three-action modal; no duplicate stock owner.
const Rules = preload("res://scripts/modules/rooms/ark_food_storage.gd")
const Placement = preload("res://scripts/ark_fixture_placement.gd")
var pending := false
var cached := {}

func clear() -> void:
	pending = false
	cached.clear()

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

func request(game: Node3D) -> void:
	if game._hud_choice_open() or not accessible(game):
		game.message = "停船站稳，走到本舟储物箱旁再按 G 管理家庭食材。"
		game._update_hud()
		return
	pending = true
	game.message = "家庭储粮 %d/%d：鲜贝 %d，热汤 %d。\n随身鲜贝 %d，热汤 %d。1 存入食物（热汤优先），2 取一份热汤，3 取一份鲜贝，Esc 关闭。守潮人会在傍晚从箱中取料，完成后把汤留给家里；木料仍按 E 存取。" % [Rules.stock(game.economy),Rules.CAPACITY,game.economy.inventory(Rules.OWNER,"shellfish"),game.economy.inventory(Rules.OWNER,"stew_servings"),game.raw_shellfish,game.stew_servings]
	game._update_hud()

func choose(game: Node3D,key: int) -> void:
	if not pending: return
	pending = false
	if key==KEY_ESCAPE:
		game.message = "你合上了储粮格，食材保持原样。"
		game._update_hud()
		return
	if not accessible(game):
		game.message = "你已离开储物箱或正在施工，食材没有移动。"
		game._update_hud()
		return
	var result: Dictionary
	var resource := ""
	if key==KEY_1: result = Rules.deposit(game.economy)
	elif key in [KEY_2,KEY_3]:
		resource = "stew_servings" if key==KEY_2 else "shellfish"
		result = Rules.withdraw(game.economy,resource)
	else: return
	if result.ok and not result.get("duplicate",false):
		var amounts: Dictionary = result.get("amounts",{resource:1})
		game._record_world_event("household_food_stored" if key==KEY_1 else "household_food_withdrawn",{"container_id":Rules.OWNER,"amounts":amounts,"actual_position":game._position_facts(game.ark_root.to_local(game.player.global_position))})
		game.message = "你把食物放进防潮箱的储粮格，空出随身行囊。" if key==KEY_1 else "你从储粮格取出一份热汤，可以带到桌边和大家一起喝。" if key==KEY_2 else "你从储粮格取出一份鲜贝。"
	else: game.message = "随身没有可存的食物，或储粮格已经满了；没有转移物资。" if key==KEY_1 else "储粮格没有这份食物，或行囊暂时装不下；没有转移物资。"
	game._save_progress()
	game._update_hud()
