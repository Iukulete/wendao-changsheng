extends RefCounted
## Transient item-management session. Existing Economy and legacy item facts
## remain authoritative; a drag is only an intention, never a carried inventory.
const Transfer = preload("res://scripts/modules/economy/ark_inventory_transfer.gd")
const Equipment = preload("res://scripts/modules/leisure/ark_fishing_equipment.gd")
const ItemLocations = preload("res://scripts/modules/equipment/ark_equipment_items.gd")
const RodProfiles = preload("res://scripts/modules/leisure/ark_fishing_rod_profiles.gd")
const Food = preload("res://scripts/modules/rooms/ark_food_storage.gd")
const Bait = preload("res://scripts/modules/leisure/ark_bait_fishing.gd")
const PanelScript = preload("res://scripts/presentation/ark_inventory_panel.gd")
const ITEMS := [
	["fish","鲜鱼","船边钓获；带到火盆做鲜鱼汤（1鱼→1热汤），也可存箱；这里不直接食用。"],
	["large_fish","肥鱼","用饵钓获；带到火盆做肥鱼汤（1肥鱼→3热汤）。可存入储粮格，每条占1格；生鱼不能直接共餐。"],
	["wood","木料","用于建造和修补；本舟木料格可直接供料。"],
	["shellfish","鲜贝","可做汤、存箱，或明确选择下次用作鱼饵；只有实际下竿才扣随身1份，失败或收竿不返还。"],
	["stew_servings","热汤","鲜贝汤和鲜鱼汤都计作热汤份，制作时分别记下配方；带到饭席共餐；圈外干岸受寒时也可喝1份驱寒，不回血。"],
	["keel_beams","龙骨","用于船艏龙骨扩甲；不能放入此储物箱。"],
	["guest_cabin_frames","客舱骨架","用于听潮客舱建造；不能放入此储物箱。"],
	["utility_core","回收组件","用于日照净水角；已装设备需原封存流程回收。"],
	["rope","好绳","唯一好绳，在筏舷或棚柱按住 E 绑牢；不能存入箱子。"],
	["ancient_parts","古旧灵枢","在阵枢工作台调校旧灯；不能存入箱子。"],
	["tide_relay_cores","旧潮枢","在工作台按已学罗盘图样改造；不能存入箱子。"],
	["pressure_cores","压力炉核心","工作台安装饭釜时仍需明确确认材料；不能存入箱子。"],
	["reef_shell_plates","礁壳片","用于棚顶礁壳风撑；不能存入箱子。"],
	["glass_bead","琉璃舷珠","用于琼华舫客居登记；不能存入箱子。"],
	["guest_pass","留宿帖","已获一次客居资格，到琼华舫客榻使用；不能存入箱子。"],
]
const MOVEMENT_KEYS := [KEY_W,KEY_A,KEY_S,KEY_D,KEY_SPACE,KEY_SHIFT]
var game: Node3D
var ui: Node
var opened := false
var mode := "bag"
var generation := 0
var box_id := 0
var box_transform := Transform3D.IDENTITY
var notice := ""
var detail := ""
var selected := "wood"
var blocked_keys: Dictionary = {}
var last_gesture := 0
var offer_sequence := 0
var offers: Dictionary = {}
var current_offers: Dictionary = {}

func attach(owner_game: Node3D) -> void:
	game=owner_game
	ui=PanelScript.new();game.add_child(ui);ui.setup(game.UI_FONT)
	ui.item_requested.connect(move_equipment_item)
	ui.close_requested.connect(close)
	ui.inspect_requested.connect(inspect)
	ui.unavailable_requested.connect(explain_unavailable)
	ui.intent_requested.connect(transfer)
	ui.resource_intent_requested.connect(set_resource_intent)
	ui.nearby_box_requested.connect(open_box)
	refresh()

func active() -> bool: return opened

func observe_key(event: InputEventKey) -> void:
	if not event.pressed: blocked_keys.erase(event.keycode)
	elif opened and event.keycode in MOVEMENT_KEYS: blocked_keys[event.keycode]=true

func key_pressed(code: Key) -> bool:
	return not opened and not blocked_keys.has(code) and Input.is_key_pressed(code)

func regain_focus() -> void:
	# Lost focus may swallow an OS key-up. Clear only physically released keys;
	# a key still down remains latched until the player really releases it.
	for code in blocked_keys.keys():
		if not Input.is_key_pressed(code): blocked_keys.erase(code)

func _latch_movement() -> void:
	for code in MOVEMENT_KEYS:
		if Input.is_key_pressed(code): blocked_keys[code]=true

func _can_open() -> bool:
	return is_instance_valid(game) and not game._hud_choice_open() and not (game.hud_drawer and game.hud_drawer.visible) and not (game.world_chart and game.world_chart.visible) and game._maintenance_window_focused and not game.get_tree().paused

func open_bag() -> void:
	if opened: close();return
	if not _can_open(): return
	if game.building_mode: game._cancel_build()
	_begin("bag")

func open_box() -> void:
	# Construction deliberately blocks chest access even when already in reach.
	# Explain that mode boundary rather than sending the player towards the box.
	if _can_open() and game.building_mode:
		game.message="先按 Esc 退出营造，再按 E 打开储物箱。"
		game._update_hud()
		return
	if not _can_open() or not game.food_storage.accessible(game):
		game.message="先靠近本舟储物箱，并避开墙体遮挡，再按 E 打开。"
		game._update_hud()
		return
	var box: Node3D=game.food_storage.fixture(game)
	box_id=box.get_instance_id();box_transform=box.transform
	_begin("chest")

func _begin(kind: String) -> void:
	opened=true;mode=kind;generation+=1;last_gesture=0;notice=""
	offers.clear();current_offers.clear()
	_latch_movement();game._cancel_maintenance_hold();game.food_storage.forget_hint();game.orbit_camera.release()
	if is_instance_valid(ui): ui.cancel_drag()
	refresh();game._update_interaction_hint()

func close() -> void:
	_latch_movement();opened=false;generation+=1;box_id=0;notice=""
	offers.clear();current_offers.clear()
	if is_instance_valid(ui): ui.cancel_drag();refresh()
	if is_instance_valid(game): game._update_interaction_hint()

func clear() -> void:
	close();detail="";selected="wood"
	if is_instance_valid(ui):ui.clear_rod_notice()

func _box_valid() -> bool:
	var box: Node3D=game.food_storage.fixture(game)
	return mode=="chest" and box!=null and box.get_instance_id()==box_id and box.transform==box_transform and game.food_storage.accessible(game)

func _count(resource: String) -> int:
	if resource in ["wood","shellfish","stew_servings","fish","large_fish","keel_beams","guest_cabin_frames","utility_core"]: return game.economy.inventory("player",resource)
	if resource=="rope": return 1 if game.rope_available else 0
	if resource=="glass_bead": return 1 if game.jade_sail_guest_bead_collected else 0
	if resource=="guest_pass": return 1 if game.jade_sail_guest_pass_active else 0
	return int(game.get(resource))

func inspect(resource: String) -> void:
	for item in ITEMS:
		if item[0]==resource:
			selected=resource;detail="%s：%s" % [item[1],item[2]];refresh();return

func _bait_action() -> Dictionary:
	var pending: bool=is_instance_valid(game.fishing) and game.fishing.pending_bait
	var count:=_count("shellfish")
	var blocked:=""
	if not opened or mode!="bag": blocked="请在个人背包中选择随身鲜贝。"
	elif not _can_open(): blocked="窗口失焦或已暂停；请恢复后重新选择。"
	elif game.sailing_mode: blocked="请先停船，再选择鱼饵。"
	elif game.building_mode: blocked="请先结束营造，再选择鱼饵。"
	elif game._fishing_active(): blocked="请先结束本次钓鱼，再选择下一竿。"
	elif not is_instance_valid(game.fishing): blocked="钓鱼当前不可操作。"
	var status:="已选下次用饵 · 尚未扣除；实际下竿扣随身1份，之后恢复免费钓。" if pending else "尚未选择鱼饵 · 免费钓仍可用；不会自动取用箱内鲜贝。"
	if not blocked.is_empty(): status+="\n"+blocked
	elif count<=0: status+="\n随身鲜贝不足1份；请先取回或采集。"
	return {"resource":"shellfish","source":"player","count":count,"pending":pending,"enabled":blocked.is_empty(),"can_arm":blocked.is_empty() and count>0 and not pending,"can_cancel":blocked.is_empty() and pending,"status":status}

func _field_stew_action() -> Dictionary:
	if not opened or mode!="bag" or selected!="stew_servings": return {}
	var blocked: String = game._field_stew_block_reason()
	return {"resource":"stew_servings","source":"player","count":_count("stew_servings"),
		"cold":game._effective_cold_exposure_level(),"can_drink":blocked.is_empty(),
		"status":"喝 1 份随身热汤 · 驱寒 1 级，不回血。" if blocked.is_empty() else blocked}

func set_resource_intent(intent: Dictionary) -> void:
	if intent.get("resource","")=="stew_servings":
		if not opened or mode!="bag" or selected!="stew_servings" or not _can_open(): return
		if not is_instance_valid(ui) or not ui._resource_snapshot_current(intent): return
		if intent.get("source","")!="player" or int(intent.get("generation",-1))!=generation or int(intent.get("session",-1))!=generation: return
		if not game._drink_field_stew(int(intent.get("count",-1)),int(intent.get("cold",-1))): refresh()
		return
	# This changes only a one-cast intention. Payment belongs to actual casting;
	# ordinary chest clicks/drag plans never enter this explicit bag-only route.
	if not opened or mode!="bag" or selected!="shellfish" or not _can_open(): return
	if not is_instance_valid(ui) or not ui._resource_snapshot_current(intent): return
	if intent.get("resource","")!="shellfish" or intent.get("source","")!="player" or int(intent.get("generation",-1))!=generation or int(intent.get("session",-1))!=generation: return
	var current:=_bait_action()
	if int(intent.get("count",-1))!=int(current.count) or intent.get("pending")!=current.pending: refresh();return
	var value: bool=bool(intent.get("value",false))
	if not bool(current.can_arm if value else current.can_cancel): refresh();return
	if game.fishing.set_bait_intent(value): notice=""
	refresh();game._update_interaction_hint()

func _large_fish_known() -> bool:
	if _count("large_fish")>0 or game.economy.inventory(Food.OWNER,"large_fish")>0: return true
	var saved: Dictionary=game.economy.snapshot()
	return int(saved.get("streams",{}).get(Bait.CATCH,{}).get("sequence",0))>0

func explain_unavailable(source: String, resource: String) -> void:
	# A released empty plan is feedback only, never permission to create a new
	# transfer if an NPC changed the amount/capacity after mouse-down.
	if not opened or mode!="chest" or not _can_open() or source not in ["player","box"]: return
	if source=="box" and resource not in Transfer.RESOURCES: return
	if not _box_valid(): refresh();return
	for item in ITEMS:
		if item[0]!=resource: continue
		var current:=_row(source,item)
		var reason: String=current.locked_reason
		if reason.is_empty(): reason="数量或可用空间已变化，请重新选择。"
		notice="%s · %s：本次没有转移。%s" % ["随身" if source=="player" else "储物箱",item[1],reason]
		refresh();return

func _plan(source: String, resource: String, action: String) -> Dictionary:
	if not opened or mode!="chest" or resource not in Transfer.RESOURCES or not _box_valid(): return {}
	var result:=Transfer.preview(game.economy,source,resource,action)
	if result.is_empty() or int(result.amount)<=0: return {}
	result["generation"]=generation;result["box_id"]=box_id;result["box_transform"]=box_transform
	var key:=source+":"+resource+":"+action
	var previous: Dictionary=current_offers.get(key,{})
	if previous.get("plan",{})==result and offers.has(previous.get("id")): return offers[previous.id].duplicate(true)
	offer_sequence+=1
	current_offers[key]={"plan":result.duplicate(true),"id":offer_sequence}
	result["offer_id"]=offer_sequence
	offers[offer_sequence]=result.duplicate(true)
	while offers.size()>128: offers.erase(offers.keys()[0])
	return result

func _row(source: String, item: Array) -> Dictionary:
	var resource: String=item[0]
	var count: int=_count(resource) if source=="player" else game.economy.inventory(Transfer.owner("box",resource),resource)
	var all_plan:=_plan(source,resource,"all")
	var one_plan:=_plan(source,resource,"one")
	var reason:=""
	var summary:=""
	if mode=="bag": reason="点击查看用途；靠近本舟箱按 E 可直接打开双栏。"
	elif resource not in Transfer.RESOURCES: reason="专用材料 / 信物，不可放入此箱。";summary="专用物品 · 不入箱"
	elif count<=0: reason="没有这件物品。";summary="空"
	elif all_plan.is_empty():
		var food_full:=source=="player" and resource!="wood" and Food.stock(game.economy)>=Food.CAPACITY
		reason="储粮格已满（8 份）；请先取出食物。" if food_full else "目标暂不能接收；没有转移。"
		summary="储粮已满 · 先取出" if food_full else "暂不可转移"
	return {"id":resource,"label":item[1],"count":count,"description":item[2],"locked_reason":reason,"summary":summary,"plan_all":all_plan,"plan_one":one_plan}

func refresh() -> void:
	if not is_instance_valid(ui) or not is_instance_valid(game): return
	if opened and mode=="chest" and not _box_valid():
		ui.cancel_drag();generation+=1;mode="bag";box_id=0
		notice="箱子已移动、不可达或被挡住；已关闭箱侧。没有转移物品。"
	var player_rows: Array=[]
	var box_rows: Array=[]
	var large_fish_known:=_large_fish_known()
	for item in ITEMS:
		# Discovery is a projection of actual stock/catches, never a seeded zero.
		# Once known, both empty targets remain available for ordinary transfers.
		if item[0]=="large_fish" and not large_fish_known: continue
		var row:=_row("player",item)
		# Keep familiar transfer kinds as stable empty targets; only owned special
		# materials are shown, rather than a spoiler catalogue of zero-count items.
		if item[0] in Transfer.RESOURCES or int(row.count)>0: player_rows.append(row)
		if mode=="chest" and item[0] in Transfer.RESOURCES: box_rows.append(_row("box",item))
	ui.present({"open":opened,"mode":mode,"title":"背包 ↔ 本舟储物箱" if mode=="chest" else "背包","notice":notice,"save_warning":str(game.get_meta("save_warning","")),"detail":detail if not detail.is_empty() else "选择物品查看用途；拖出窗口只取消，不会掉落或丢失物品。","bait_action":_bait_action(),"field_stew_action":_field_stew_action(),"equipment_slot":_equipment_slot() if opened else {},"item_rows":_item_rows() if opened else [],"items_revision":game.equipment_items.revision(),"item_enabled":not game.sailing_mode and not game._fishing_active(),"rod_enabled":not game.sailing_mode and not game._fishing_active(),"player_rows":player_rows,"box_rows":box_rows,"food_used":Food.stock(game.economy),"food_capacity":Food.CAPACITY,"nearby_box_available":opened and mode=="bag" and game.food_storage.accessible(game),"access_message":("物资拖到对侧 · 工具选中后操作 · 左键整组 / 右键 1 个 · " if mode=="chest" else "点选查看用途 · ")+"B / Esc 关闭；居民照常作业。","generation":generation,"session":generation})

func move_equipment_item(id: String, source: Dictionary, destination: Dictionary, session: int, revision: int) -> void:
	if not opened or session!=generation or not _can_open(): return
	if game._fishing_active() or game.sailing_mode or game.building_mode:
		notice="请先收竿、停船并结束建造，再整理装备。";refresh();return
	if source==ItemLocations.BOX or destination==ItemLocations.BOX:
		if mode!="chest" or not _box_valid():
			notice="箱子当前不可操作；道具位置未变。";refresh();return
	if mode=="bag" and (source==ItemLocations.BOX or destination==ItemLocations.BOX): return
	var result:Dictionary=game.equipment_items.move(id,source,destination,revision,game.economy.snapshot(),game.storage_built)
	if not result.get("ok",false):
		notice="随身空间不足；原道具位置未变。" if result.get("code")=="capacity" else "道具状态已变化；这次没有移动。";refresh();return
	if result.get("duplicate",false): return
	notice="";detail="";ui.rod_hint=""
	if destination==ItemLocations.TOOL and game.message.begins_with("未装备钓竿"):
		game.message=""
	if is_instance_valid(game.fishing):game.fishing.refresh_equipped_gear()
	var saved:bool=game._save_progress()
	game._update_hud();refresh()
	# Follow only an explicitly successful withdrawal. The old command snapshot
	# stays invalid; the panel creates a fresh selection after the model refresh.
	if source==ItemLocations.BOX and destination==ItemLocations.BAG:
		ui.follow_taken_item(id,generation,game.equipment_items.revision())
	var profile:String=game.equipment_items.profile(id)
	var verb:String="已装备" if destination==ItemLocations.TOOL else "已卸下" if source==ItemLocations.TOOL else "已存入" if destination==ItemLocations.BOX else "已取回"
	ui.show_rod_notice(verb+str(RodProfiles.profile(profile).get("title","钓竿"))+("" if saved else " · 尚未保存"))

func _item_row(id: String, location: String) -> Dictionary:
	var profile_id:String=game.equipment_items.profile(id)
	var profile:Dictionary=RodProfiles.profile(profile_id)
	var hint:String="原本的收线手感。" if profile_id=="basic" else "咬钩窗口较宽，持续绷线更易脱鱼。" if profile_id=="light" else "持续绷线容错较长，收线较慢。"
	return {"id":id,"profile":profile_id,"title":profile.get("title","钓竿"),"location":location,"address":game.equipment_items.address(id),"hint":hint}

func _equipment_slot() -> Dictionary:
	var ids:Array=game.equipment_items.at("equipment")
	return {} if ids.is_empty() else _item_row(str(ids[0]),"equipment")

func _item_rows() -> Array:
	var rows:Array=[]
	for location in ["bag","box"]:
		if location=="box" and mode!="chest":continue
		for id in game.equipment_items.at(location):rows.append(_item_row(str(id),location))
	return rows

func transfer(intent: Dictionary) -> void:
	if not opened or mode!="chest" or not _box_valid() or not game._maintenance_window_focused or game.get_tree().paused:
		notice="箱子当前不可操作；没有转移物品。";refresh();return
	var gesture: int=int(intent.get("gesture_id",0))
	if gesture<=last_gesture or gesture<=0: return
	last_gesture=gesture
	var original: Dictionary=intent.duplicate(true)
	original.erase("gesture_id")
	if not offers.has(intent.get("offer_id")) or offers[intent.offer_id]!=original:
		notice="物品意向已失效；请重新选择。没有转移。";refresh();return
	if intent.get("generation")!=generation or intent.get("box_id")!=box_id or intent.get("box_transform")!=box_transform:
		notice="本次操作已失效；请重新选择物品。没有转移。";refresh();return
	var result: Dictionary=Transfer.commit(game.economy,intent,"transfer:%d:%d" % [Time.get_ticks_usec(),gesture])
	if not result.get("ok",false) or result.get("duplicate",false):
		notice="数量或可用空间已变化，请看清新数量后重新操作。没有转移物品。" if result.get("code")=="changed" else "材料、容量或转移条件不满足；没有转移物品。"
		refresh();return
	var resource: String=intent.resource
	var amount: int=intent.amount
	if resource!="wood":
		game._record_world_event("household_food_stored" if intent.source=="player" else "household_food_withdrawn",{"container_id":Food.OWNER,"amounts":{resource:amount},"actual_position":game._position_facts(game.ark_root.to_local(game.player.global_position))})
	var label:=resource
	for item in ITEMS:
		if item[0]==resource: label=item[1];break
	notice="%s %d 份%s。" % ["已存入箱中" if intent.source=="player" else "已取到随身",amount,label]
	game.message=notice
	if not game._save_progress(): notice+=" 当前存档未写入，请查看保存警告。"
	game._update_hud();refresh()
