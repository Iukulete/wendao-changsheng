extends Node3D

## Standalone, art-free proof of the open-world home-building direction.
## This scene intentionally does not replace the existing game's main scene yet.

const WALK_SPEED := 5.0
const SAIL_SPEED := 3.6
const SAIL_TURN_SPEED := 0.72
const ARK_REFUGE_RADIUS := 8.0
const TUNED_LANTERN_REFUGE_RADIUS := 15.0
const ARK_HULL_CLEARANCE := Vector3(6.2, 1.0, 5.9)
const ARK_HULL_QUERY_OFFSET := Vector3(0.0, 0.08, 0.52)
const REEF_SURGE_CENTER := Vector2(35.0, -35.5)
const REEF_SURGE_RADIUS := 2.0
const REEF_SURGE_PUSH := Vector2(-0.52, -0.85)
const REEF_SURGE_COOLDOWN := 1.6
const REEF_BEAST_CENTER := Vector2(44.5, -27.5)
const REEF_BEAST_TRIGGER_RADIUS := 3.6
const REEF_BEAST_ESCAPE_RADIUS := 5.0
const REEF_BEAST_WINDUP_SECONDS := 1.25
const REEF_BEAST_KNOCKBACK_SECONDS := 0.32
const REEF_BEAST_MAX_HEALTH := 3
const REEF_BEAST_ATTACK_RANGE := 3.1
const REEF_BEAST_RECOVERY_SECONDS := 1.0
const REEF_BEAST_DAMAGE := 1
const PLAYER_MAX_HEALTH := 4
const PLAYER_ATTACK_COOLDOWN_SECONDS := 0.38
const REEF_SHELL_BRACE_WOOD_COST := 2
const TIDE_STATION_POSITION := Vector3(-28.0, 0.2, 23.0)
const JADE_SAIL_ARK_POSITION := Vector3(-53.0, 0.2, -45.0)
const PRESSURE_WRECK_POSITION := Vector3(92.0, 0.2, 86.0)
const PRESSURE_VENT_NOTICE_RADIUS := 9.0
const PRESSURE_VENT_DANGER_RADIUS := 2.9
const PRESSURE_VENT_WINDUP_SECONDS := 1.4
const PRESSURE_VENT_COOLDOWN_SECONDS := 5.5
const BASE_SAIL_SPEED := 3.6
const TUNED_SAIL_SPEED := 4.6
const BUILD_COST := 3
const STORAGE_COST := 2
const WORKBENCH_COST := 2
const RAFT_EXTENSION_WOOD_COST := 4
const RAFT_EXTENSION_KEEL_COST := 1
const GUEST_CABIN_WOOD_COST := 3
const GUEST_CABIN_FRAME_COST := 1
const PRESSURE_GALLEY_WOOD_COST := 3
const GUEST_CABIN_SAILMAKER_POSITION := Vector3(-0.85, 0.12, -4.34)
const TIDEKEEPER_BOX_SHORE_POSITION := Vector3(14.25, 0.08, -6.45)
const TIDEKEEPER_BOX_ARK_POSITION := Vector3(2.15, 0.12, -0.45)
const RESIDENT_AUTO_GATHER_RADIUS := 11.0
const RESIDENT_AUTO_GATHER_SPEED := 1.8
const RESIDENT_AUTO_GATHER_PICKUP_SECONDS := 0.65
const RESIDENT_ROUTE_CELL_SIZE := 0.75
const RESIDENT_ROUTE_MARGIN := 4.5
const RESIDENT_ROUTE_BLOCKER_HEIGHT := 0.5
const RESIDENT_ROUTE_SURFACE_OFFSET := 0.12
const RESIDENT_DECK_POSITION := Vector3(-1.0, 0.12, 0.85)
const JADE_INDUSTRY_REPAIR_WOOD_COST := 3
const JADE_INDUSTRY_AFFILIATION_WOOD_COST := 3
const JADE_INDUSTRY_TITLE_TRANSFER_WOOD_COST := 3
const JADE_INDUSTRY_GATHER_RADIUS := 14.0
const JADE_INDUSTRY_GATHER_SPEED := 1.8
const JADE_INDUSTRY_PICKUP_SECONDS := 0.65
const JADE_INDUSTRY_HOME_POSITION := Vector3(-53.0, 0.12, -41.8)
const JADE_GUEST_BERTH_POSITION := Vector3(-0.35, 1.0, -0.15)
const JADE_GUEST_REGISTRY_POSITION := Vector3(1.2, 1.0, 0.42)
const JADE_GUEST_BEAD_POSITION := Vector3(1.25, 1.0, -0.48)
const JADE_INDUSTRY_RESOURCE_IDS := ["JadeSailTidalShells", "JadeSailTidalShellsWest", "JadeSailTidalShellsNorth"]
const JADE_INDUSTRY_WOOD_IDS := ["JadeSailDriftwood"]
const MAX_WORLD_EVENTS := 256
const WATER_SURFACE_Y := -1.05
const WATER_FLOAT_ROOT_Y := WATER_SURFACE_Y - 0.45
const PLAYER_WORLD_EDGE_LIMIT := 140.0
const PLAYER_WORLD_EDGE_RELEASE_MARGIN := 4.0
const SaveScript = preload("res://scripts/ark_greybox_save.gd")
const WorldChartScript = preload("res://scripts/ark_world_chart.gd")
const LandmassBuilderScript = preload("res://scripts/ark_landmass_builder.gd")

enum WeatherPhase { FORECAST, STORM, AFTER }
enum DayPeriod { MORNING, DAY, EVENING, NIGHT }

@export var save_root_override := ""

var player: CharacterBody3D
var ark_root: Node3D
var camera: Camera3D
var hud: Label
var note: Label
var interaction_hint: Label
var interaction_focus_ring: MeshInstance3D
var world_chart: Control
var raft_expansion_blueprint_button: Button
var guest_cabin_blueprint_button: Button
var reef_shell_brace_button: Button
var wood := 1
var player_health := PLAYER_MAX_HEALTH
var raw_shellfish := 0
var stew_servings := 0
var shared_meal_day := 0
var shared_meal_count := 0
var shared_meal_gathering_pending := false
var shared_meal_participants: Array[String] = []
var resident_keepsake_present := false
var shelter_built := false
var shelter_position := Vector3.ZERO
var storage_built := false
var storage_position := Vector3.ZERO
var stored_wood := 0
var workbench_built := false
var workbench_position := Vector3.ZERO
var keel_beams := 0
var keel_wreck_searched := false
var learned_blueprint_ids: Array[String] = ["starter_shelter", "starter_home"]
var raft_extension_built := false
var guest_cabin_built := false
var guest_cabin_frames := 0
var lantern_tuned := false
var resident_met := false
var traveler_boarded := false
var traveler_choice_pending := false
var resident_repair_choice_pending := false
var resident_repair_pending := false
var resident_repair_part := ""
var resident_gather_policy := "balanced"
var resident_gather_policy_choice_pending := false
var resident_gather_pending := false
var resident_gather_phase := ""
var resident_gather_target_id := ""
var resident_gather_resource := ""
var resident_gather_target_position := Vector3.ZERO
var resident_gather_route := PackedVector3Array()
var resident_gather_route_index := 0
var resident_gather_payload := 0
var resident_gather_pickup_remaining := 0.0
var resident_gather_last_day := 0
var weather_phase := WeatherPhase.FORECAST
var resolved_storm_count := 0
var next_storm_day := 0
var last_resolved_storm_facts: Dictionary = {}
var tidekeeper_last_storm_reflection := 0
var rope_available := true
var rope_use := "none"
var shelter_roof_damaged := false
var raft_edge_damaged := false
var safe_channel_marked := false
var ruin_searched := false
var cold_exposure := false
var cold_exposure_level := 0
var ancient_parts := 0
var tide_station_searched := false
var tide_relay_cores := 0
var tide_compass_tuned := false
var jade_sail_ark_searched := false
var jade_sail_keeper_met := false
var jade_sail_guest_choice_pending := false
var jade_sail_guest_bead_collected := false
var jade_sail_guest_pass_active := false
var jade_sail_guest_stay_used := false
var jade_sail_industry_choice_pending := false
var jade_sail_industry_choice_kind := ""
var jade_sail_industry_active := false
var jade_sail_industry_acquired := false
var jade_sail_vessel_title_owned := false
var jade_sail_industry_shellfish := 0
var jade_sail_industry_wood := 0
var jade_sail_industry_last_day := 0
var jade_sail_industry_pending := false
var jade_sail_industry_phase := ""
var jade_sail_industry_resource := ""
var jade_sail_industry_target_id := ""
var jade_sail_industry_target_position := Vector3.ZERO
var jade_sail_industry_payload := 0
var jade_sail_industry_pickup_remaining := 0.0
var jade_sail_industry_deliveries := 0
var pressure_wreck_searched := false
var pressure_cores := 0
var pressure_galley_built := false
var pressure_galley_choice_pending := false
var pressure_vent_warning_active := false
var pressure_vent_warning_remaining := 0.0
var pressure_vent_cooldown_remaining := 0.0
var pressure_vent_burst_remaining := 0.0
var is_swimming := false
var player_world_edge_blocked := false
var sailing_mode := false
var player_inside_refuge := false
var reef_surge_cooldown := 0.0
var reef_beast_marker: Node3D
var reef_beast_warning: Node3D
var reef_beast_spooked := false
var reef_beast_defeated := false
var reef_beast_health := REEF_BEAST_MAX_HEALTH
var reef_shell_plates := 0
var reef_shell_brace_installed := false
var reef_beast_charge_remaining := 0.0
var reef_beast_recovery_remaining := 0.0
var reef_beast_knockback_remaining := 0.0
var reef_beast_knockback_velocity := Vector3.ZERO
var player_attack_cooldown := 0.0
var reef_beast_hit_flash_remaining := 0.0
var ark_save_distance := 0.0
var ark_navigation_blocked := false
var preparation_choice_pending := false
var repair_choice_pending := false
var raft_extension_dismantle_pending := false
var message := "几块浮木、一盏旧灯。先找些木料，再回木筏搭起避风处。"
var interactables: Array[Dictionary] = []
var collected_ids: Array[String] = []
var save_service: RefCounted
var building_mode := false
var build_type := ""
var build_preview: Node3D
var preview_valid_material: StandardMaterial3D
var preview_invalid_material: StandardMaterial3D
var preview_position := Vector3.ZERO
var preview_valid := false
var weather_environment: Environment
var sky_material: ProceduralSkyMaterial
var sun_light: DirectionalLight3D
var storm_overlay: ColorRect
var traveler_marker: Node3D
var traveler_body: Node3D
var tidekeeper_box_marker: Node3D
var traveler_target_position := Vector3.ZERO
var traveler_action := ""
var traveler_motion_clock := 0.0
var traveler_routine_route := PackedVector3Array()
var traveler_routine_route_index := 0
var traveler_routine_route_target := Vector3.ZERO
var traveler_routine_route_target_set := false
var sailmaker_met := false
var sailmaker_boarded := false
var sailmaker_joined_day := 0
var sailmaker_choice_pending := false
var sailmaker_awning_raised := false
var sailmaker_marker: Node3D
var sailmaker_body: Node3D
var sailmaker_target_position := Vector3.ZERO
var sailmaker_action := ""
var sailmaker_motion_clock := 0.0
var sailmaker_routine_route := PackedVector3Array()
var sailmaker_routine_route_index := 0
var sailmaker_routine_route_target := Vector3.ZERO
var sailmaker_routine_route_target_set := false
var sailmaker_guest_cabin_first_night := false
var jade_sail_keeper_marker: Node3D
var jade_sail_keeper_body: Node3D
var jade_sail_keeper_action := ""
var jade_sail_keeper_motion_clock := 0.0
var avatar_visual: Node3D
var avatar_clock := 0.0
var day_count := 1
var day_period := DayPeriod.MORNING
var world_events: Array[Dictionary] = []
var event_sequence := 0


func _ready() -> void:
	_build_world()
	_build_player()
	_build_hud()
	save_service = SaveScript.new(save_root_override)
	_load_progress()
	player_inside_refuge = _is_within_ark_refuge()
	_update_hud()


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	player_attack_cooldown = maxf(0.0, player_attack_cooldown - _delta)
	reef_beast_recovery_remaining = maxf(0.0, reef_beast_recovery_remaining - _delta)
	reef_beast_hit_flash_remaining = maxf(0.0, reef_beast_hit_flash_remaining - _delta)
	if reef_beast_hit_flash_remaining <= 0.0 and reef_beast_marker and is_instance_valid(reef_beast_marker):
		reef_beast_marker.scale = Vector3.ONE
	if world_chart and world_chart.visible:
		player.velocity = Vector3.ZERO
		if camera:
			var chart_target := player.global_position + Vector3(0, 1.0, 0)
			camera.global_position = chart_target + Vector3(0, 8.5, 10.5)
			camera.look_at(chart_target, Vector3.UP)
		world_chart.refresh(player.global_position, _world_chart_destinations())
		return
	if sailing_mode:
		var throttle := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
		var steer := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		_sail_step(_delta, throttle, steer)
		if avatar_visual:
			avatar_clock += _delta
			avatar_visual.position.y = sin(avatar_clock * 2.0) * 0.006
		if camera:
			var sail_target := player.global_position + Vector3(0, 1.0, 0)
			camera.global_position = sail_target + Vector3(0, 8.5, 10.5)
			camera.look_at(sail_target, Vector3.UP)
		_refresh_refuge_state()
		return
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_key_pressed(KEY_D): input.x += 1.0
	if Input.is_key_pressed(KEY_W): input.y -= 1.0
	if Input.is_key_pressed(KEY_S): input.y += 1.0
	input = input.normalized()
	var move := Vector3(input.x, 0.0, input.y)
	var was_swimming := is_swimming
	is_swimming = player.global_position.y <= WATER_FLOAT_ROOT_Y + 0.08 and not player.is_on_floor() and player.velocity.y <= 0.0
	var current_speed := _current_walk_speed() * (0.58 if is_swimming else 1.0)
	if reef_beast_knockback_remaining > 0.0:
		reef_beast_knockback_remaining = maxf(0.0, reef_beast_knockback_remaining - _delta)
		var shove_strength := reef_beast_knockback_remaining / REEF_BEAST_KNOCKBACK_SECONDS
		player.velocity.x = reef_beast_knockback_velocity.x * shove_strength
		player.velocity.z = reef_beast_knockback_velocity.z * shove_strength
		if reef_beast_knockback_remaining <= 0.0:
			reef_beast_knockback_velocity = Vector3.ZERO
	else:
		player.velocity.x = move.x * current_speed
		player.velocity.z = move.z * current_speed
	if is_swimming and player.velocity.y <= 0.0:
		player.global_position.y = WATER_FLOAT_ROOT_Y
		player.velocity.y = 0.0
	elif not player.is_on_floor():
		player.velocity.y -= 22.0 * _delta
	else:
		player.velocity.y = -0.1
	player.move_and_slide()
	_apply_player_world_edge()
	_apply_reef_surge(_delta)
	_process_reef_beast(_delta)
	_process_pressure_vent(_delta)
	if avatar_visual:
		avatar_clock += _delta
		var walking := move.length_squared() > 0.001 and not is_swimming
		if walking:
			avatar_visual.rotation.y = atan2(move.x, move.z)
		avatar_visual.position.y = sin(avatar_clock * (11.0 if walking else 2.0)) * (0.025 if walking else 0.006)
	if was_swimming != is_swimming:
		_update_hud()
	_refresh_refuge_state()
	if building_mode:
		_update_build_preview()
	if camera:
		var target := player.global_position + Vector3(0, 1.0, 0)
		camera.global_position = target + Vector3(0, 8.5, 10.5)
		camera.look_at(target, Vector3.UP)


func _apply_player_world_edge() -> void:
	if player == null:
		return
	var position := player.global_position
	var reached_edge := false
	if absf(position.x) > PLAYER_WORLD_EDGE_LIMIT:
		var edge_sign := signf(position.x)
		position.x = edge_sign * PLAYER_WORLD_EDGE_LIMIT
		if player.velocity.x * edge_sign > 0.0:
			player.velocity.x = 0.0
		reached_edge = true
	if absf(position.z) > PLAYER_WORLD_EDGE_LIMIT:
		var edge_sign := signf(position.z)
		position.z = edge_sign * PLAYER_WORLD_EDGE_LIMIT
		if player.velocity.z * edge_sign > 0.0:
			player.velocity.z = 0.0
		reached_edge = true
	if reached_edge:
		player.global_position = position
		if not player_world_edge_blocked:
			player_world_edge_blocked = true
			message = "外海涌流把你推回了已知海域。前方没有可辨认的岛屿；沿着潮痕图标记的方向，仍可自由驶向任何已发现的海岸。"
			_update_hud()
	elif player_world_edge_blocked and absf(position.x) < PLAYER_WORLD_EDGE_LIMIT - PLAYER_WORLD_EDGE_RELEASE_MARGIN and absf(position.z) < PLAYER_WORLD_EDGE_LIMIT - PLAYER_WORLD_EDGE_RELEASE_MARGIN:
		player_world_edge_blocked = false


func _sail_step(delta: float, throttle: float, steer: float) -> bool:
	if not sailing_mode or ark_root == null:
		return false
	var previous_position := ark_root.global_position
	var previous_yaw := ark_root.rotation.y
	var turn := steer * SAIL_TURN_SPEED * delta
	var travel := clampf(throttle, -1.0, 1.0) * _current_sail_speed() * delta
	var travel_steps := ceili(absf(travel) / 0.65)
	var turn_steps := ceili(absf(turn) / deg_to_rad(8.0))
	var substeps := maxi(1, maxi(travel_steps, turn_steps))
	for step in range(substeps):
		ark_root.rotation.y = previous_yaw + turn * float(step + 1) / float(substeps)
		if is_zero_approx(travel) and is_zero_approx(turn):
			continue
		var forward := -ark_root.global_transform.basis.z
		var candidate := ark_root.global_position + forward * travel / float(substeps)
		if not _is_ark_position_navigable(candidate):
			ark_root.global_position = previous_position
			ark_root.rotation.y = previous_yaw
			if not ark_navigation_blocked:
				ark_navigation_blocked = true
				_record_world_event("ark_navigation_blocked", {"position": _position_facts(ark_root.global_position), "reason": "shore_or_world_edge"})
				message = "仙舟碰上礁岸，停在了原處。可調整船頭或倒退離開，再沿着更開闊的水道前行。"
				_save_progress()
				_update_hud()
			return false
		ark_root.global_position = candidate
	ark_navigation_blocked = false
	ark_save_distance += absf(travel)
	if ark_save_distance >= 6.0:
		ark_save_distance = 0.0
		_save_progress()
	return true


func _is_ark_position_navigable(candidate: Vector3) -> bool:
	if absf(candidate.x) > 130.0 or absf(candidate.z) > 130.0:
		return false
	var hull_shape := BoxShape3D.new()
	hull_shape.size = ARK_HULL_CLEARANCE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hull_shape
	query.transform = Transform3D(Basis(Vector3.UP, ark_root.global_rotation.y), candidate + Basis(Vector3.UP, ark_root.global_rotation.y) * ARK_HULL_QUERY_OFFSET)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var excluded: Array[RID] = []
	if player:
		excluded.append(player.get_rid())
	for collider in ark_root.find_children("*", "CollisionObject3D", true, false):
		if collider is CollisionObject3D:
			excluded.append((collider as CollisionObject3D).get_rid())
	query.exclude = excluded
	var hits := get_world_3d().direct_space_state.intersect_shape(query, 1)
	return hits.is_empty()


func _toggle_sailing() -> void:
	if sailing_mode:
		sailing_mode = false
		_record_world_event("ark_sailing_stopped", {"position": _position_facts(ark_root.global_position)})
		message = "你离开舵位，仙舟停在当前海面。WASD 恢复步行与游泳。"
		_save_progress()
		_update_hud()
		return
	if weather_phase != WeatherPhase.AFTER:
		message = "风雨尚未过去，先把这段浅滩的避风与修理安排妥当，再离岸迁徙。"
	elif raft_edge_damaged:
		message = "筏舷还没修牢，暂时不能安全掌舵。先补好受损处。"
	else:
		var resident_recalled := _recall_resident_gatherer("ark_departure")
		sailing_mode = true
		_record_world_event("ark_sailing_started", {"position": _position_facts(ark_root.global_position)})
		message = "你握住舵柄。W/S 前后航行，A/D 转向；再按 E 或 Esc 离舵。靠近岸礁時船身会被挡住。"
		if resident_recalled:
			message += " 守潮人收起近岸营生，随舟出发；已经带回的物资留在船上。"
	_save_progress()
	_update_hud()


func _current_walk_speed() -> float:
	var exposure_multipliers := [1.0, 0.62, 0.42, 0.28]
	return WALK_SPEED * float(exposure_multipliers[_effective_cold_exposure_level()])


func _apply_reef_surge(delta: float) -> void:
	reef_surge_cooldown = maxf(0.0, reef_surge_cooldown - delta)
	if not is_swimming or player == null or reef_surge_cooldown > 0.0:
		return
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	if player_xz.distance_to(REEF_SURGE_CENTER) > REEF_SURGE_RADIUS:
		return
	player.velocity.x += REEF_SURGE_PUSH.x * 4.2
	player.velocity.z += REEF_SURGE_PUSH.y * 4.2
	reef_surge_cooldown = REEF_SURGE_COOLDOWN
	_record_world_event("reef_surge_deflected", {"site_id": "far_reef_surge_channel", "position": _position_facts(player.global_position), "damage": 0, "recovery": "climb_onto_reef_or_swim_clear"})
	message = "碎浪从礁脚横扫过来，把你推回浅海。前方的白沫标出水道；沿着较高礁脊绕行，仍能抵达沉筏。"
	_update_hud()


func _process_reef_beast(delta: float) -> void:
	if reef_beast_spooked or reef_beast_defeated or player == null:
		return
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	var distance := player_xz.distance_to(REEF_BEAST_CENTER)
	if reef_beast_charge_remaining <= 0.0:
		if reef_beast_recovery_remaining > 0.0:
			return
		if not sailing_mode and not is_swimming and distance <= REEF_BEAST_TRIGGER_RADIUS:
			reef_beast_charge_remaining = REEF_BEAST_WINDUP_SECONDS
			_record_world_event("reef_beast_warning", {"site_id": "far_reef_beast_nest", "position": _position_facts(player.global_position), "windup_seconds": REEF_BEAST_WINDUP_SECONDS})
			message = "碎壳和拖痕忽然指向你身后——礁背兽正从石缝里蓄势。Q 可用修船钩近身反击；也可离开领地或绕到北侧高礁。"
			_refresh_reef_beast_visual()
			_save_progress()
			_update_hud()
		return
	if sailing_mode or is_swimming or distance >= REEF_BEAST_ESCAPE_RADIUS:
		var escape_reason := "boarded_ark" if sailing_mode else "entered_water" if is_swimming else "left_territory"
		_record_reef_beast_escape(escape_reason)
		return
	reef_beast_charge_remaining = maxf(0.0, reef_beast_charge_remaining - maxf(0.0, delta))
	if reef_beast_charge_remaining <= 0.0:
		var away := player_xz - REEF_BEAST_CENTER
		if away.length_squared() < 0.001:
			away = Vector2(-1.0, 0.0)
		away = away.normalized()
		reef_beast_knockback_velocity = Vector3(away.x * 6.5, 0.0, away.y * 6.5)
		reef_beast_knockback_remaining = REEF_BEAST_KNOCKBACK_SECONDS
		reef_beast_recovery_remaining = REEF_BEAST_RECOVERY_SECONDS
		var health_before := player_health
		player_health = maxi(0, player_health - REEF_BEAST_DAMAGE)
		_record_world_event("reef_beast_rushed", {"site_id": "far_reef_beast_nest", "position": _position_facts(player.global_position), "damage": health_before - player_health, "player_health_after": player_health, "inventory_lost": false, "recovery": "shelter_cot_or_shared_meal"})
		if player_health <= 0:
			_knock_out_player_from_reef_beast()
		else:
			message = "礁背兽撞中你，生命 %d/%d；没有丢失物资。它退开喘息片刻，仍可继续战斗或撤出领地。" % [player_health, PLAYER_MAX_HEALTH]
		_refresh_reef_beast_visual()
		_save_progress()
		_update_hud()


func _record_reef_beast_escape(reason: String) -> void:
	reef_beast_charge_remaining = 0.0
	_record_world_event("reef_beast_evaded", {"site_id": "far_reef_beast_nest", "position": _position_facts(player.global_position), "reason": reason, "damage": 0})
	message = "你及时退出了礁背兽的领地。它没有追入浅海；沉筏还在原处，等你从高礁或更开阔的水道绕回。"
	_refresh_reef_beast_visual()
	_save_progress()
	_update_hud()


func _attack_reef_beast() -> void:
	if player == null or sailing_mode or is_swimming or building_mode or reef_beast_spooked or reef_beast_defeated:
		return
	if player_attack_cooldown > 0.0:
		return
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	var distance := player_xz.distance_to(REEF_BEAST_CENTER)
	if distance > REEF_BEAST_ATTACK_RANGE:
		message = "修船钩够不到礁背兽。它离你还远；可以继续绕行，不必开战。"
		_update_hud()
		return
	if reef_beast_charge_remaining <= 0.0:
		_process_reef_beast(0.0)
		if reef_beast_charge_remaining <= 0.0:
			return
	player_attack_cooldown = PLAYER_ATTACK_COOLDOWN_SECONDS
	reef_beast_health = maxi(0, reef_beast_health - 1)
	reef_beast_charge_remaining = minf(REEF_BEAST_WINDUP_SECONDS, reef_beast_charge_remaining + 0.3)
	reef_beast_hit_flash_remaining = 0.12
	if reef_beast_marker and is_instance_valid(reef_beast_marker):
		reef_beast_marker.scale = Vector3(1.12, 0.9, 1.12)
	_record_world_event("reef_beast_hit", {"site_id": "far_reef_beast_nest", "position": _position_facts(player.global_position), "damage": 1, "enemy_health_after": reef_beast_health, "attack": "repair_hook"})
	if reef_beast_health <= 0:
		reef_beast_defeated = true
		reef_beast_charge_remaining = 0.0
		reef_beast_recovery_remaining = 0.0
		reef_shell_plates = 1
		_learn_blueprint("reef_shell_storm_brace", "far_reef_beast")
		_record_world_event("reef_beast_defeated", {"site_id": "far_reef_beast_nest", "shell_plates": 1, "blueprint_id": "reef_shell_storm_brace", "unique_reward": true})
		message = "礁背兽终于退回石缝。你收下一片坚实的背甲，并把风撑结构记入蓝图册；学会后可用 2 块木料和甲片加固自家棚顶。"
		_refresh_reef_beast_visual()
		_save_progress()
		_update_hud()
		return
	message = "修船钩敲中礁背兽的甲壳，裂纹又深了一道（%d/%d）。它的冲势被打断了一瞬。" % [reef_beast_health, REEF_BEAST_MAX_HEALTH]
	_refresh_reef_beast_visual()
	_save_progress()
	_update_hud()


func _knock_out_player_from_reef_beast() -> void:
	var knocked_out_position := player.global_position
	player_health = 1
	player.velocity = Vector3.ZERO
	if ark_root:
		player.global_position = ark_root.to_global(Vector3(0.0, 1.1, 1.55))
	reef_beast_charge_remaining = 0.0
	reef_beast_recovery_remaining = REEF_BEAST_RECOVERY_SECONDS
	_record_world_event("player_knocked_out", {"cause": "reef_beast", "position": _position_facts(knocked_out_position), "recovery_position": _position_facts(player.global_position), "health_after": player_health, "inventory_lost": false})
	message = "你被礁背兽撞昏，醒来时已被同伴送回自家仙舟。行囊完整，但只剩 1 点生命；休息或共餐能恢复。"
	_refresh_refuge_state()
	_update_hud()


func _refresh_reef_beast_visual() -> void:
	if reef_beast_marker != null and is_instance_valid(reef_beast_marker):
		reef_beast_marker.visible = not reef_beast_spooked and not reef_beast_defeated
	if reef_beast_warning != null and is_instance_valid(reef_beast_warning):
		var sign := reef_beast_warning.get_node_or_null("Name") as Label3D
		if sign:
			if reef_beast_defeated:
				sign.text = "旧巢已静 · 礁壳风撑蓝图可学"
			elif reef_beast_spooked:
				sign.text = "爪痕已静 · 北侧高礁可绕行"
			elif reef_beast_charge_remaining > 0.0:
				sign.text = "礁背兽 %d/%d · 蓄势 %0.1fs · Q 反击" % [reef_beast_health, REEF_BEAST_MAX_HEALTH, reef_beast_charge_remaining]
			else:
				sign.text = "礁背兽 %d/%d · 碎壳拖痕" % [reef_beast_health, REEF_BEAST_MAX_HEALTH]


func _process_pressure_vent(delta: float) -> void:
	if player == null:
		return
	pressure_vent_burst_remaining = maxf(0.0, pressure_vent_burst_remaining - maxf(0.0, delta))
	if pressure_vent_burst_remaining <= 0.0:
		var steam := get_node_or_null("PressureWreck/SteamBurst") as GPUParticles3D
		if steam:
			steam.emitting = false
	var vent_position := PRESSURE_WRECK_POSITION + Vector3(1.65, 0.0, -0.12)
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	var vent_xz := Vector2(vent_position.x, vent_position.z)
	var distance := player_xz.distance_to(vent_xz)
	if pressure_wreck_searched:
		pressure_vent_warning_active = false
		pressure_vent_warning_remaining = 0.0
		pressure_vent_burst_remaining = 0.0
		_refresh_pressure_vent_visual()
		return
	if sailing_mode or is_swimming or distance > PRESSURE_VENT_NOTICE_RADIUS:
		if pressure_vent_warning_active:
			pressure_vent_warning_active = false
			pressure_vent_warning_remaining = 0.0
			pressure_vent_cooldown_remaining = minf(pressure_vent_cooldown_remaining, 0.8)
			_refresh_pressure_vent_visual()
		pressure_vent_cooldown_remaining = maxf(0.0, pressure_vent_cooldown_remaining - maxf(0.0, delta))
		return
	if pressure_vent_cooldown_remaining > 0.0:
		pressure_vent_cooldown_remaining = maxf(0.0, pressure_vent_cooldown_remaining - maxf(0.0, delta))
		if pressure_vent_cooldown_remaining > 0.0:
			return
	if not pressure_vent_warning_active:
		pressure_vent_warning_active = true
		pressure_vent_warning_remaining = PRESSURE_VENT_WINDUP_SECONDS
		_record_world_event("pressure_vent_warning", {"site_id": "steam_wreck_islet", "position": _position_facts(player.global_position), "windup_seconds": PRESSURE_VENT_WINDUP_SECONDS, "damage": 0})
		message = "蒸汽阀发出尖锐的两段鸣响，喷口正在蓄压！离开亮起的铜管附近就能避开。"
		_refresh_pressure_vent_visual()
		_save_progress()
		_update_hud()
		return
	pressure_vent_warning_remaining = maxf(0.0, pressure_vent_warning_remaining - maxf(0.0, delta))
	if pressure_vent_warning_remaining > 0.0:
		_refresh_pressure_vent_visual()
		return
	pressure_vent_warning_active = false
	pressure_vent_cooldown_remaining = PRESSURE_VENT_COOLDOWN_SECONDS
	pressure_vent_burst_remaining = 0.95
	var steam := get_node_or_null("PressureWreck/SteamBurst") as GPUParticles3D
	if steam:
		steam.restart()
	_record_world_event("pressure_vent_burst", {"site_id": "steam_wreck_islet", "position": _position_facts(vent_position), "radius": PRESSURE_VENT_DANGER_RADIUS})
	if distance <= PRESSURE_VENT_DANGER_RADIUS:
		var health_before := player_health
		player_health = maxi(0, player_health - 1)
		var away := player_xz - vent_xz
		if away.length_squared() < 0.001:
			away = Vector2(-1.0, 0.0)
		away = away.normalized()
		player.velocity.x = away.x * 5.0
		player.velocity.z = away.y * 5.0
		_record_world_event("pressure_vent_hit", {"site_id": "steam_wreck_islet", "damage": health_before - player_health, "player_health_after": player_health, "inventory_lost": false, "recovery": "shelter_cot_or_shared_meal"})
		if player_health <= 0:
			_knock_out_player_from_pressure_vent()
		else:
			message = "高压热汽擦过肩背，生命 %d/%d。你被推离喷口，没有丢失行囊；退到安全距离，等阀门重新泄压。" % [player_health, PLAYER_MAX_HEALTH]
		_refresh_refuge_state()
	else:
		message = "压力阀轰然喷出白汽，幸好你已经退开。热浪散去后，蒸潮坞仍能继续探索。"
	_refresh_pressure_vent_visual()
	_save_progress()
	_update_hud()


func _knock_out_player_from_pressure_vent() -> void:
	var knocked_out_position := player.global_position
	player_health = 1
	player.velocity = Vector3.ZERO
	if ark_root:
		player.global_position = ark_root.to_global(Vector3(0.0, 1.1, 1.55))
	_record_world_event("player_knocked_out", {"cause": "pressure_vent", "position": _position_facts(knocked_out_position), "recovery_position": _position_facts(player.global_position), "health_after": player_health, "inventory_lost": false})
	message = "高压热汽将你撞倒。你醒来时已被同伴送回自家仙舟，行囊完整，但只剩 1 点生命；休息或共餐能恢复。"
	_refresh_refuge_state()


func _refresh_pressure_vent_visual() -> void:
	var wreck := get_node_or_null("PressureWreck") as Node3D
	var warning_ring := wreck.get_node_or_null("VentWarningRing") as MeshInstance3D if wreck else null
	if warning_ring:
		warning_ring.visible = pressure_vent_warning_active
		var pulse := 1.0 + sin(pressure_vent_warning_remaining * 18.0) * 0.12
		warning_ring.scale = Vector3.ONE * pulse
	var glow := wreck.get_node_or_null("PressureGlow") as OmniLight3D if wreck else null
	if glow:
		glow.light_energy = 1.8 if pressure_vent_warning_active else (2.2 if pressure_vent_burst_remaining > 0.0 else 0.16 if pressure_wreck_searched else 0.6)
	var sign_node := get_node_or_null("PressureWreckInteractable/Name") as Label3D
	if sign_node:
		if pressure_wreck_searched:
			sign_node.text = "蒸潮机坞 · 核心已回收"
		elif pressure_vent_warning_active:
			sign_node.text = "压力阀蓄压 · 快离开喷口"
		else:
			sign_node.text = "蒸潮机坞 · 间歇喷汽"


func _record_world_event(event_id: String, facts: Dictionary = {}) -> void:
	event_sequence += 1
	world_events.append({
		"sequence": event_sequence,
		"id": event_id,
		"day": day_count,
		"period": day_period,
		"facts": facts.duplicate(true),
	})
	while world_events.size() > MAX_WORLD_EVENTS:
		world_events.pop_front()


func _position_facts(position: Vector3) -> Dictionary:
	return {"x": snappedf(position.x, 0.01), "y": snappedf(position.y, 0.01), "z": snappedf(position.z, 0.01)}


func _distance_to_ark() -> float:
	if ark_root == null:
		return INF
	if player == null:
		return INF
	var target := player.global_position
	return Vector2(target.x - ark_root.global_position.x, target.z - ark_root.global_position.z).length()


func _is_within_ark_refuge() -> bool:
	return _distance_to_ark() <= _current_refuge_radius()


func _current_refuge_radius() -> float:
	return TUNED_LANTERN_REFUGE_RADIUS if lantern_tuned else ARK_REFUGE_RADIUS


func _effective_cold_exposure_level() -> int:
	return clampi(maxi(cold_exposure_level, 1 if cold_exposure else 0), 0, 3)


func _raise_cold_exposure(source: String) -> int:
	var previous_level := _effective_cold_exposure_level()
	cold_exposure_level = mini(3, previous_level + 1)
	cold_exposure = cold_exposure_level > 0
	if cold_exposure_level > previous_level:
		_record_world_event("cold_exposure_worsened", {
			"source": source,
			"previous_level": previous_level,
			"exposure_level": cold_exposure_level,
			"maximum_level": 3,
		})
		_update_hud()
	return cold_exposure_level


func _relieve_cold_exposure(source: String, levels: int = 3) -> int:
	var previous_level := _effective_cold_exposure_level()
	cold_exposure_level = maxi(0, previous_level - maxi(0, levels))
	cold_exposure = cold_exposure_level > 0
	if cold_exposure_level < previous_level:
		_record_world_event("cold_exposure_relieved", {
			"source": source,
			"previous_level": previous_level,
			"exposure_level": cold_exposure_level,
			"levels_relieved": previous_level - cold_exposure_level,
		})
		_update_hud()
	return cold_exposure_level


func _restore_player_health(source: String, amount: int = PLAYER_MAX_HEALTH) -> int:
	var previous_health := player_health
	player_health = mini(PLAYER_MAX_HEALTH, player_health + maxi(0, amount))
	if player_health > previous_health:
		_record_world_event("player_health_recovered", {"source": source, "previous_health": previous_health, "health_after": player_health, "amount": player_health - previous_health})
	return player_health - previous_health


func _current_sail_speed() -> float:
	return TUNED_SAIL_SPEED if tide_compass_tuned else BASE_SAIL_SPEED


func _refresh_refuge_state() -> void:
	var inside_now := _is_within_ark_refuge()
	var refuge_changed := inside_now != player_inside_refuge
	if not refuge_changed and not (inside_now and cold_exposure):
		return
	player_inside_refuge = inside_now
	if refuge_changed and inside_now:
		_record_world_event("ark_refuge_entered", {"radius": _current_refuge_radius(), "position": _position_facts(player.global_position)})
	if refuge_changed and not inside_now:
		_record_world_event("ark_refuge_left", {"radius": _current_refuge_radius(), "distance": snappedf(_distance_to_ark(), 0.1), "position": _position_facts(player.global_position)})
		message = "你离开了仙舟的庇护圈。附近仍可自由探索，但风雨中的寒意会更难熬。"
	elif inside_now and cold_exposure:
		var previous_level := _effective_cold_exposure_level()
		_relieve_cold_exposure("ark_refuge")
		_record_world_event("ark_refuge_warmed", {"radius": _current_refuge_radius(), "previous_exposure_level": previous_level, "position": _position_facts(player.global_position)})
		message = "你回到仙舟的庇护圈。阵灯与船上的暖意驱散了积下的寒意。"
	elif refuge_changed:
		message = "仙舟的灯火重新映入眼中；你已回到它的庇护范围。"
	_update_hud()


func _process(delta: float) -> void:
	if traveler_boarded and traveler_marker != null and is_instance_valid(traveler_marker):
		traveler_motion_clock += delta
		var moving := false
		if resident_gather_pending:
			moving = _process_resident_gathering(delta)
		else:
			moving = _move_ark_resident_toward(traveler_marker, traveler_target_position, delta, 0.72, "tidekeeper")
		if traveler_body:
			traveler_body.position.y = sin(traveler_motion_clock * (9.0 if moving else 2.0)) * (0.035 if moving else 0.008)
	if jade_sail_keeper_marker != null and is_instance_valid(jade_sail_keeper_marker):
		jade_sail_keeper_motion_clock += delta
		if jade_sail_industry_pending:
			_process_jade_sail_industry_gathering(delta)
		if jade_sail_keeper_body:
			var keeper_moving := jade_sail_industry_pending and jade_sail_industry_phase in ["outbound", "returning"]
			jade_sail_keeper_body.position.y = sin(jade_sail_keeper_motion_clock * (8.0 if keeper_moving else 2.0)) * (0.03 if keeper_moving else 0.007)
	if sailmaker_boarded and sailmaker_marker != null and is_instance_valid(sailmaker_marker):
		sailmaker_motion_clock += delta
		var sailmaker_moving := _move_ark_resident_toward(sailmaker_marker, sailmaker_target_position, delta, 0.64, "sailmaker")
		if sailmaker_body:
			sailmaker_body.position.y = sin(sailmaker_motion_clock * (8.0 if sailmaker_moving else 2.0)) * (0.03 if sailmaker_moving else 0.007)
			if not sailmaker_moving:
				_record_sailmaker_guest_cabin_occupancy()
		if shared_meal_gathering_pending:
			_try_complete_shared_table_meal()
	_update_interaction_hint()


func _move_ark_resident_toward(marker: Node3D, target: Vector3, delta: float, speed: float, resident_id: String) -> bool:
	var route := traveler_routine_route if resident_id == "tidekeeper" else sailmaker_routine_route
	var route_index := traveler_routine_route_index if resident_id == "tidekeeper" else sailmaker_routine_route_index
	var previous_target := traveler_routine_route_target if resident_id == "tidekeeper" else sailmaker_routine_route_target
	var target_set := traveler_routine_route_target_set if resident_id == "tidekeeper" else sailmaker_routine_route_target_set
	var target_changed := not target_set or not target.is_equal_approx(previous_target)
	var finished_route_displaced := not route.is_empty() and route_index >= route.size() and marker.position.distance_to(target) > 0.06
	if target_changed or finished_route_displaced:
		route = _build_ark_local_walk_route(marker.position, target)
		route_index = 1 if route.size() > 1 else 0
		previous_target = target
		target_set = true
	var distance_remaining := maxf(0.0, delta) * speed
	while route_index < route.size() and distance_remaining > 0.0:
		var movement_target := route[route_index]
		var offset := movement_target - marker.position
		var distance_to_target := offset.length()
		if distance_to_target <= 0.06:
			marker.position = movement_target
			route_index += 1
			continue
		var step_distance := minf(distance_remaining, distance_to_target)
		marker.position = marker.position.move_toward(movement_target, step_distance)
		distance_remaining -= step_distance
		var facing := Vector3(offset.x, 0.0, offset.z).normalized()
		if not facing.is_zero_approx():
			marker.rotation.y = atan2(-facing.x, -facing.z)
		if step_distance >= distance_to_target:
			route_index += 1
		else:
			break
	var moving := route_index < route.size()
	if resident_id == "tidekeeper":
		traveler_routine_route = route
		traveler_routine_route_index = route_index
		traveler_routine_route_target = previous_target
		traveler_routine_route_target_set = target_set
	else:
		sailmaker_routine_route = route
		sailmaker_routine_route_index = route_index
		sailmaker_routine_route_target = previous_target
		sailmaker_routine_route_target_set = target_set
	return moving


func _build_ark_local_walk_route(start: Vector3, destination: Vector3) -> PackedVector3Array:
	var route := PackedVector3Array()
	if ark_root == null or get_world_3d() == null or start.distance_to(destination) <= 0.06:
		return route
	var margin := 2.0
	var minimum := Vector2(minf(start.x, destination.x), minf(start.z, destination.z)) - Vector2.ONE * margin
	var maximum := Vector2(maxf(start.x, destination.x), maxf(start.z, destination.z)) + Vector2.ONE * margin
	var cell_size := 0.25
	minimum = Vector2(floorf(minimum.x / cell_size) * cell_size, floorf(minimum.y / cell_size) * cell_size)
	var grid_size := Vector2i(ceili((maximum.x - minimum.x) / cell_size) + 1, ceili((maximum.y - minimum.y) / cell_size) + 1)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, grid_size)
	grid.cell_size = Vector2.ONE * cell_size
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for cell_z in range(grid_size.y):
		for cell_x in range(grid_size.x):
			var local_xz := minimum + Vector2(cell_x, cell_z) * cell_size
			if _ark_local_walk_cell_blocked(local_xz):
				grid.set_point_solid(Vector2i(cell_x, cell_z), true)
	var start_cell := Vector2i(roundi((start.x - minimum.x) / cell_size), roundi((start.z - minimum.y) / cell_size))
	var end_cell := Vector2i(roundi((destination.x - minimum.x) / cell_size), roundi((destination.z - minimum.y) / cell_size))
	if not grid.is_in_boundsv(start_cell) or not grid.is_in_boundsv(end_cell):
		return route
	grid.set_point_solid(start_cell, false)
	grid.set_point_solid(end_cell, false)
	var cell_path := grid.get_id_path(start_cell, end_cell)
	if cell_path.is_empty():
		return route
	route.append(start)
	for index in range(1, cell_path.size() - 1):
		var cell: Vector2i = cell_path[index]
		route.append(Vector3(minimum.x + float(cell.x) * cell_size, start.y, minimum.y + float(cell.y) * cell_size))
	if start.distance_to(destination) > 0.06:
		route.append(destination)
	return route


func _ark_local_walk_cell_blocked(local_xz: Vector2) -> bool:
	var actor_center := ark_root.to_global(Vector3(local_xz.x, 1.15, local_xz.y))
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.23
	capsule.height = 1.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis(Vector3.UP, ark_root.global_rotation.y), actor_center)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var excluded: Array[RID] = []
	if player:
		excluded.append(player.get_rid())
	for resident in [traveler_marker, sailmaker_marker]:
		if resident is CollisionObject3D:
			excluded.append((resident as CollisionObject3D).get_rid())
	query.exclude = excluded
	var collisions := get_world_3d().direct_space_state.intersect_shape(query, 1)
	return not collisions.is_empty()


func _update_interaction_hint() -> void:
	if interaction_hint == null:
		return
	var modal_choice_open := traveler_choice_pending or sailmaker_choice_pending or resident_repair_choice_pending or resident_gather_policy_choice_pending or preparation_choice_pending or repair_choice_pending or raft_extension_dismantle_pending or jade_sail_guest_choice_pending or jade_sail_industry_choice_pending or pressure_galley_choice_pending
	if player == null or building_mode or sailing_mode or modal_choice_open or (world_chart and world_chart.visible):
		interaction_hint.visible = false
		if interaction_focus_ring:
			interaction_focus_ring.visible = false
		return
	var nearest: Dictionary = {}
	var nearest_distance := 2.8
	for entry in interactables:
		var target := entry.get("node") as Node3D
		if target == null or not is_instance_valid(target):
			continue
		var distance := player.global_position.distance_to(target.global_position)
		if distance < nearest_distance:
			nearest = entry
			nearest_distance = distance
	interaction_hint.visible = not nearest.is_empty()
	if interaction_hint.visible:
		interaction_hint.text = "E  ·  " + _interaction_hint_action(str(nearest.get("id", "")))
		var focus_target := nearest.get("node") as Node3D
		if interaction_focus_ring and focus_target and is_instance_valid(focus_target):
			interaction_focus_ring.global_position = focus_target.global_position + Vector3(0.0, 0.045, 0.0)
			interaction_focus_ring.visible = true
	elif interaction_focus_ring:
		interaction_focus_ring.visible = false


func _interaction_hint_action(interactable_id: String) -> String:
	match interactable_id:
		"wood": return "拾取漂木"
		"shellfish": return "采集潮池鲜贝"
		"resident": return "与守潮人交谈"
		"tidekeeper_box": return "查看守潮人的浮标箱"
		"sailmaker": return "与缝帆人交谈"
		"cot": return "在床铺休息"
		"hearth": return "使用火盆煮汤"
		"storage": return "存取木料"
		"workbench": return "查看阵灯工作台"
		"home": return "整备仙舟"
		"ruin": return "搜索风蚀遗迹"
		"keel_wreck": return "打捞远礁沉筏"
		"tide_station": return "调查旧潮讯台"
		"jade_sail_ark": return "探索琼华舫遗址"
		"jade_sail_keeper": return "与琼华舫掌事交谈"
		"jade_sail_cargo": return "查看琼华舫货舱"
		"jade_sail_guest_bead": return "拾取琉璃舷珠"
		"jade_sail_guest_registry": return "查看留宿帖" if jade_sail_guest_pass_active else "登记琼华舫客居"
		"jade_sail_guest_berth": return "在听潮客榻留宿" if jade_sail_guest_pass_active else "查看听潮客榻"
		"guest_cabin": return "查看听潮客舱"
		"lantern": return "查看避风灯"
		"safe_channel": return "查看安全潮沟"
		"sailmaker_awning": return "查看新缝的雨檐"
		"resident_keepsake": return "查看潮贝纪念物"
		"raft_extension": return "管理龙骨甲板"
		"pressure_wreck": return "检查蒸潮坞残舫"
		_: return "查看附近物件"


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if world_chart and world_chart.visible and event.keycode in [KEY_M, KEY_ESCAPE]:
		_toggle_world_chart()
		return
	if event.keycode == KEY_M:
		_toggle_world_chart()
		return
	if raft_extension_dismantle_pending:
		if event.keycode == KEY_1:
			raft_extension_dismantle_pending = false
			_dismantle_raft_extension()
		elif event.keycode in [KEY_2, KEY_ESCAPE]:
			raft_extension_dismantle_pending = false
			message = "你决定先保留龙骨甲板。"
			_update_hud()
		return
	if jade_sail_guest_choice_pending:
		if event.keycode == KEY_1:
			_choose_jade_sail_guest_pass(true)
		elif event.keycode in [KEY_2, KEY_ESCAPE]:
			_choose_jade_sail_guest_pass(false)
		return
	if jade_sail_industry_choice_pending:
		if event.keycode == KEY_1:
			_choose_jade_sail_industry_contract(true)
		elif event.keycode in [KEY_2, KEY_ESCAPE]:
			_choose_jade_sail_industry_contract(false)
		return
	if pressure_galley_choice_pending:
		if event.keycode == KEY_1:
			_build_pressure_galley()
		elif event.keycode in [KEY_2, KEY_ESCAPE]:
			pressure_galley_choice_pending = false
			message = "你先把蒸潮坞的图样收好；材料仍留在原处。"
			_update_hud()
		return
	if resident_gather_policy_choice_pending:
		if event.keycode == KEY_1:
			_choose_resident_gather_policy("wood_first")
		elif event.keycode == KEY_2:
			_choose_resident_gather_policy("shellfish_first")
		elif event.keycode == KEY_3:
			_choose_resident_gather_policy("balanced")
		elif event.keycode == KEY_ESCAPE:
			resident_gather_policy_choice_pending = false
			message = "你决定先让守潮人按原方针自行安排。"
			_update_hud()
		return
	if traveler_choice_pending:
		if event.keycode == KEY_1:
			_choose_traveler_boarding(true)
		elif event.keycode == KEY_2:
			_choose_traveler_boarding(false)
		return
	if sailmaker_choice_pending:
		if event.keycode == KEY_1:
			_choose_sailmaker_boarding(true)
		elif event.keycode == KEY_2:
			_choose_sailmaker_boarding(false)
		return
	if resident_repair_choice_pending:
		if event.keycode == KEY_1:
			_choose_resident_repair(true)
		elif event.keycode == KEY_2:
			_choose_resident_repair(false)
		return
	if preparation_choice_pending:
		if shelter_built:
			if event.keycode == KEY_1:
				_choose_weather_preparation("shelter")
			elif event.keycode == KEY_2:
				_choose_weather_preparation("raft")
			elif event.keycode == KEY_3:
				_choose_weather_preparation("none")
		else:
			if event.keycode == KEY_1:
				_choose_weather_preparation("raft")
			elif event.keycode == KEY_2:
				_choose_weather_preparation("none")
		return
	if repair_choice_pending:
		if event.keycode == KEY_1:
			_repair_damaged_part("shelter")
		elif event.keycode == KEY_2:
			_repair_damaged_part("raft")
		elif event.keycode == KEY_3:
			repair_choice_pending = false
			message = "你先记下损伤，等找到合适木料再修。"
			_update_hud()
		return
	if event.keycode == KEY_Q:
		_attack_reef_beast()
	elif event.keycode == KEY_E:
		_interact()
	elif event.keycode == KEY_R:
		_advance_weather()
	elif event.keycode == KEY_T:
		_wait_one_period()
	elif event.keycode == KEY_B:
		if building_mode:
			_cancel_build()
		else:
			_start_build()
	elif event.keycode == KEY_F5:
		var save_result := _save_progress()
		message = "这一刻已经记在旧玉里。" if save_result else "存档没有写入成功；请检查 D 盘工作目录权限。"
		_update_hud()
	elif event.keycode == KEY_ESCAPE:
		if sailing_mode:
			_toggle_sailing()
		elif building_mode:
			_cancel_build()
		else:
			message = "灰盒原型：WASD 行走，靠近物件按 E，按 B 试搭避风棚。"
			_update_hud()
	elif event.keycode == KEY_SPACE:
		_jump_player()


func _jump_player() -> void:
	if player == null:
		return
	var near_water := player.global_position.y <= WATER_FLOAT_ROOT_Y + 0.08
	if player.is_on_floor() or near_water:
		player.velocity.y = 8.6
		is_swimming = false
		if near_water:
			message = "你划水蹬开，借着浪头朝浅滩或木筏游去。"
			_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not building_mode or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if build_type == "starter_home_template":
			_try_place_starter_home_template(preview_position)
		elif build_type == "guest_cabin_template":
			_try_place_guest_cabin_template(preview_position)
		elif build_type == "shelter":
			_try_place_shelter(preview_position)
		elif build_type == "storage":
			_try_place_storage(preview_position)
		elif build_type == "workbench":
			_try_place_workbench(preview_position)
		else:
			_try_place_raft_extension(preview_position)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_build()
		get_viewport().set_input_as_handled()


func _build_world() -> void:
	var world_environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	env.sky.sky_material = sky_material
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9eb9bd")
	env.ambient_light_energy = 0.55
	world_environment.environment = env
	weather_environment = env
	add_child(world_environment)

	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-48, -28, 0)
	sun_light.light_color = Color("ffe1b2")
	sun_light.light_energy = 1.4
	add_child(sun_light)

	# Keep this visual isolated so a future art pass can replace it without touching water gameplay.
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(300.0, 300.0)
	sea_mesh.subdivide_width = 72
	sea_mesh.subdivide_depth = 72
	sea.mesh = sea_mesh
	sea.position = Vector3(0.0, -1.05, 0.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sea_material := ShaderMaterial.new()
	sea_material.shader = load("res://shaders/ark_ocean.gdshader") as Shader
	sea_material.set_shader_parameter("jade_sail_center", Vector2(JADE_SAIL_ARK_POSITION.x, JADE_SAIL_ARK_POSITION.z))
	sea_material.set_shader_parameter("jade_sail_radii", Vector2(10.0, 8.0))
	sea_material.set_shader_parameter("steam_wreck_center", Vector2(PRESSURE_WRECK_POSITION.x, PRESSURE_WRECK_POSITION.z))
	sea_material.set_shader_parameter("steam_wreck_radii", Vector2(14.0, 11.0))
	sea.material_override = sea_material
	add_child(sea)
	var landmass_builder := LandmassBuilderScript.new()
	add_child(landmass_builder.build_island("IslandLandmass", Vector3(11, 0, -14), Vector2(12, 10), 1.2))
	add_child(landmass_builder.build_island("FarReefLandmass", Vector3(39, 0, -29), Vector2(7.5, 6), 3.7, Color("626451"), Color("b4a274")))
	add_child(landmass_builder.build_island("MoonbackIsland", Vector3(-28, 0, 23), Vector2(14, 12), 5.4, Color("4e615a"), Color("87928a")))
	add_child(landmass_builder.build_island("JadeSailShoal", Vector3(JADE_SAIL_ARK_POSITION.x, 0.0, JADE_SAIL_ARK_POSITION.z), Vector2(10.0, 8.0), 9.1, Color("596856"), Color("a09270")))
	add_child(landmass_builder.build_island("SteamWreckIslet", Vector3(PRESSURE_WRECK_POSITION.x, 0.0, PRESSURE_WRECK_POSITION.z), Vector2(14.0, 11.0), 14.7, Color("555d54"), Color("98795e")))
	ark_root = Node3D.new()
	ark_root.name = "ArkRoot"
	add_child(ark_root)
	_add_box("RaftBase", Vector3(0, -0.18, 0), Vector3(6.0, 0.42, 4.5), Color("805a3c"), true, ark_root)
	_add_box("RaftTop", Vector3(0, 0.055, 0), Vector3(5.9, 0.08, 4.4), Color("b38a5c"), false, ark_root)
	_add_box("RaftBow", Vector3(0, 0.35, -2.2), Vector3(5.2, 0.45, 0.16), Color("805a3c"), true, ark_root)
	_add_box("RaftSternPort", Vector3(-1.575, 0.35, 2.2), Vector3(2.05, 0.45, 0.16), Color("805a3c"), true, ark_root)
	_add_box("RaftSternStarboard", Vector3(1.575, 0.35, 2.2), Vector3(2.05, 0.45, 0.16), Color("805a3c"), true, ark_root)
	_add_box("RaftBoardingGangplank", Vector3(0, 0.04, 2.72), Vector3(1.0, 0.12, 1.2), Color("9a7652"), true, ark_root)
	_add_box("RaftPort", Vector3(-2.95, 0.35, 0), Vector3(0.16, 0.45, 4.3), Color("805a3c"), true, ark_root)
	_add_box("RaftStarboard", Vector3(2.95, 0.35, 0), Vector3(0.16, 0.45, 4.3), Color("805a3c"), true, ark_root)
	_add_raft_lantern(ark_root)
	_add_pile("DriftwoodNear", Vector3(-4.0, 0.15, 1.5), 2)
	_add_pile("DriftwoodShore", Vector3(9.0, 0.22, -4.0), 2)
	_add_pile("DriftwoodRidge", Vector3(19.0, 0.22, -5.5), 3)
	_add_pile("MoonbackDriftwood", Vector3(-20.0, 0.22, 18.0), 2)
	_add_pile("JadeSailDriftwood", Vector3(-47.0, 0.22, -48.0), 3)
	_add_shellfish_patch("TidalShellsNear", Vector3(8.4, 0.1, -6.1), 1)
	_add_shellfish_patch("TidalShellsCove", Vector3(13.8, 0.12, -11.8), 1)
	_add_shellfish_patch("MoonbackTidalShells", Vector3(-31.0, 0.12, 27.0), 2)
	_add_shellfish_patch("JadeSailTidalShells", Vector3(-60.0, 0.12, -49.0), 2)
	_add_shellfish_patch("JadeSailTidalShellsWest", Vector3(-48.0, 0.12, -50.5), 1)
	_add_shellfish_patch("JadeSailTidalShellsNorth", Vector3(-56.0, 0.12, -39.5), 1)
	_add_interactable("home", "木筏", Vector3(0, 0.6, 0.6), ark_root)
	_add_interactable("helm", "舵位 · E 掌舵", Vector3(0, 0.55, 1.55), ark_root)
	_add_interactable("resident", "守潮人", Vector3(13.0, 0.3, -6.0), null)
	_add_tidekeeper_floatbox()
	_add_interactable("sailmaker", "缝帆人", Vector3(16.0, 0.3, -10.0), null)
	_add_box("ShoreRockA", Vector3(5.0, 0.7, -7.0), Vector3(2.0, 1.6, 2.2), Color("686c68"), true)
	_add_box("ShoreRockB", Vector3(18.0, 0.8, -13.0), Vector3(3.0, 1.8, 2.4), Color("686c68"), true)
	_add_distant_warning(Vector3(23, 0.5, -17))
	_add_box("FarReefRockA", Vector3(34.0, 0.95, -28.0), Vector3(2.5, 2.0, 2.4), Color("686c68"), true)
	_add_box("FarReefRockB", Vector3(44.0, 0.8, -32.0), Vector3(3.2, 1.7, 2.4), Color("686c68"), true)
	_add_reef_surge_warning()
	_add_reef_beast()
	_add_keel_wreck(Vector3(39.0, 0.2, -29.0))
	_add_tide_station(TIDE_STATION_POSITION)
	_add_jade_sail_ark(JADE_SAIL_ARK_POSITION)
	_add_pressure_wreck(PRESSURE_WRECK_POSITION)
	_set_weather_visuals()


func _add_tidekeeper_floatbox() -> void:
	var marker := Node3D.new()
	marker.name = "TidekeeperFloatboxInteractable"
	marker.position = TIDEKEEPER_BOX_SHORE_POSITION
	add_child(marker)
	tidekeeper_box_marker = marker
	_add_local_visual_box(marker, "SaltWornCrate", Vector3(0.0, 0.16, 0.0), Vector3(0.66, 0.32, 0.5), Color("7f6549"))
	_add_local_visual_box(marker, "CrateLid", Vector3(0.0, 0.34, 0.0), Vector3(0.7, 0.06, 0.53), Color("9b7954"))
	for side in [-1.0, 1.0]:
		_add_local_visual_box(marker, "LidStrap_%d" % int(side), Vector3(side * 0.22, 0.38, 0.0), Vector3(0.045, 0.025, 0.55), Color("b7a27a"))
		_add_local_visual_box(marker, "CornerBinding_%d" % int(side), Vector3(side * 0.3, 0.16, 0.0), Vector3(0.035, 0.32, 0.52), Color("5f5140"))
	var buoy := MeshInstance3D.new()
	buoy.name = "SpareBuoyFloat"
	var buoy_mesh := SphereMesh.new()
	buoy_mesh.radius = 0.13
	buoy_mesh.height = 0.26
	buoy.mesh = buoy_mesh
	buoy.position = Vector3(0.3, 0.28, -0.23)
	buoy.scale = Vector3(1.0, 0.72, 0.9)
	buoy.material_override = _material(Color("cf8655"))
	marker.add_child(buoy)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "守潮人的浮标箱 · E 查看"
	sign.position = Vector3(0.0, 0.68, 0.0)
	sign.font_size = 20
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("f2dfae")
	marker.add_child(sign)
	interactables.append({"id": "tidekeeper_box", "node": marker, "amount": 0})


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1.1, 1.2)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.65
	shape.shape = capsule
	shape.position.y = 0.82
	player.add_child(shape)
	avatar_visual = _build_graybox_character("PlayerFigure", Color("547c87"), Color("342d32"))
	player.add_child(avatar_visual)
	ark_root.add_child(player)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 54.0
	add_child(camera)


func _build_graybox_character(character_name: String, clothes_color: Color, hair_color: Color) -> Node3D:
	# Temporary volumetric game-piece, not a final character model or art direction.
	var figure := Node3D.new()
	figure.name = character_name
	figure.position.y = 0.0
	_add_figure_mesh(figure, "Body", CapsuleMesh.new(), Vector3(0, 0.77, 0), Vector3(0.43, 0.58, 0.3), clothes_color)
	_add_figure_mesh(figure, "Head", SphereMesh.new(), Vector3(0, 1.31, 0), Vector3(0.43, 0.43, 0.4), Color("e0b995"))
	_add_figure_mesh(figure, "Hair", SphereMesh.new(), Vector3(0, 1.43, -0.055), Vector3(0.46, 0.31, 0.44), hair_color)
	_add_figure_mesh(figure, "HairTail", CapsuleMesh.new(), Vector3(0, 1.13, -0.2), Vector3(0.18, 0.4, 0.18), hair_color)
	_add_figure_mesh(figure, "ArmLeft", CapsuleMesh.new(), Vector3(-0.29, 0.76, 0), Vector3(0.16, 0.46, 0.16), clothes_color)
	_add_figure_mesh(figure, "ArmRight", CapsuleMesh.new(), Vector3(0.29, 0.76, 0), Vector3(0.16, 0.46, 0.16), clothes_color)
	_add_figure_mesh(figure, "LegLeft", CapsuleMesh.new(), Vector3(-0.12, 0.27, 0), Vector3(0.17, 0.42, 0.18), Color("554b47"))
	_add_figure_mesh(figure, "LegRight", CapsuleMesh.new(), Vector3(0.12, 0.27, 0), Vector3(0.17, 0.42, 0.18), Color("554b47"))
	_add_figure_mesh(figure, "Face", SphereMesh.new(), Vector3(0, 1.3, 0.19), Vector3(0.23, 0.16, 0.06), Color("e9c5a4"))
	return figure


func _add_figure_mesh(parent: Node3D, mesh_name: String, mesh: PrimitiveMesh, position: Vector3, scale: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	part.name = mesh_name
	part.mesh = mesh
	part.position = position
	part.scale = scale
	part.material_override = _material(color)
	parent.add_child(part)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	storm_overlay = ColorRect.new()
	storm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	storm_overlay.color = Color(0.08, 0.14, 0.2, 0.32)
	storm_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	storm_overlay.visible = false
	layer.add_child(storm_overlay)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 22)
	panel.custom_minimum_size = Vector2(650, 280)
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 20)
	stack.add_child(hud)
	note = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.y = 54
	note.add_theme_font_size_override("font_size", 16)
	stack.add_child(note)
	var controls := Label.new()
	controls.text = "WASD 行走/游泳 · Space 跳跃/蹬水 · Q 近身反击 · E 互动 · T 等待 · M 潮痕图 · R 天气 · F5 存档"
	controls.add_theme_font_size_override("font_size", 14)
	stack.add_child(controls)
	interaction_hint = Label.new()
	interaction_hint.name = "ArkInteractionHint"
	interaction_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_hint.add_theme_font_size_override("font_size", 20)
	interaction_hint.add_theme_color_override("font_color", Color("fff0c9"))
	interaction_hint.add_theme_color_override("font_outline_color", Color("17252a"))
	interaction_hint.add_theme_constant_override("outline_size", 4)
	interaction_hint.visible = false
	interaction_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	interaction_hint.offset_top = -76.0
	interaction_hint.offset_bottom = -36.0
	layer.add_child(interaction_hint)
	interaction_focus_ring = MeshInstance3D.new()
	interaction_focus_ring.name = "ArkInteractionFocusRing"
	var focus_ring_mesh := TorusMesh.new()
	focus_ring_mesh.inner_radius = 0.39
	focus_ring_mesh.outer_radius = 0.48
	focus_ring_mesh.rings = 32
	focus_ring_mesh.ring_segments = 8
	interaction_focus_ring.mesh = focus_ring_mesh
	interaction_focus_ring.rotation_degrees.x = 90.0
	var focus_ring_material := StandardMaterial3D.new()
	focus_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	focus_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	focus_ring_material.albedo_color = Color("8de5d0")
	focus_ring_material.emission_enabled = true
	focus_ring_material.emission = Color("39bba7")
	focus_ring_material.emission_energy_multiplier = 1.2
	interaction_focus_ring.material_override = focus_ring_material
	interaction_focus_ring.visible = false
	add_child(interaction_focus_ring)
	var build_buttons := HBoxContainer.new()
	build_buttons.add_theme_constant_override("separation", 8)
	stack.add_child(build_buttons)
	var basic_shelter_button := Button.new()
	basic_shelter_button.name = "ArkBasicShelterTemplateButton"
	basic_shelter_button.text = "基础避风棚 · 3 木"
	basic_shelter_button.tooltip_text = "开局实用模板：避风棚、床铺与暖灯；留出入口，可后续扩建。"
	basic_shelter_button.pressed.connect(_start_basic_shelter_template)
	build_buttons.add_child(basic_shelter_button)
	var template_button := Button.new()
	template_button.name = "ArkStarterHomeTemplateButton"
	template_button.text = "模板：潮棚之家 · 5 木"
	template_button.tooltip_text = "一键搭好避风棚、床铺、灯和储物箱；自动留出进出通道。"
	template_button.pressed.connect(_start_starter_home_template)
	build_buttons.add_child(template_button)
	var free_build_button := Button.new()
	free_build_button.name = "ArkFreeBuildButton"
	free_build_button.text = "自由逐件搭建 · B"
	free_build_button.tooltip_text = "保留逐件放置方式；各结构可按自己的布局摆放。"
	free_build_button.pressed.connect(_start_build)
	build_buttons.add_child(free_build_button)
	raft_expansion_blueprint_button = Button.new()
	raft_expansion_blueprint_button.name = "ArkRaftExpansionBlueprintButton"
	raft_expansion_blueprint_button.text = "蓝图：龙骨扩甲 · 探索远礁沉筏解锁"
	raft_expansion_blueprint_button.tooltip_text = "远礁寻回龙骨时发现的扩建方案；保留普通构件的自由摆放。"
	raft_expansion_blueprint_button.disabled = true
	raft_expansion_blueprint_button.pressed.connect(_start_raft_expansion_blueprint)
	stack.add_child(raft_expansion_blueprint_button)
	guest_cabin_blueprint_button = Button.new()
	guest_cabin_blueprint_button.name = "ArkGuestCabinBlueprintButton"
	guest_cabin_blueprint_button.text = "蓝图：听潮客舱 · 探索琼华舫解锁"
	guest_cabin_blueprint_button.tooltip_text = "从豪华仙舟遗址带回的客居舱方案；学会后永久收录，建造需要 3 块木料与 1 根舱骨。"
	guest_cabin_blueprint_button.disabled = true
	guest_cabin_blueprint_button.pressed.connect(_start_guest_cabin_template)
	stack.add_child(guest_cabin_blueprint_button)
	reef_shell_brace_button = Button.new()
	reef_shell_brace_button.name = "ArkReefShellBraceBlueprintButton"
	reef_shell_brace_button.text = "蓝图：礁壳风撑 · 击退远礁礁背兽解锁"
	reef_shell_brace_button.tooltip_text = "探索或击败礁背兽获得永久知识；安装在已建避风棚上，需要 2 块木料与 1 片礁壳，可抵御后续风雨对棚顶的损伤。"
	reef_shell_brace_button.disabled = true
	reef_shell_brace_button.pressed.connect(_install_reef_shell_brace)
	stack.add_child(reef_shell_brace_button)
	var return_button := Button.new()
	return_button.name = "ArkReturnToMainButton"
	return_button.text = "保存并返回山河界面"
	return_button.custom_minimum_size.y = 36.0
	return_button.pressed.connect(_return_to_main_menu)
	stack.add_child(return_button)
	world_chart = WorldChartScript.new()
	world_chart.name = "ArkWorldChart"
	world_chart.visible = false
	world_chart.destination_selected.connect(_on_world_chart_destination_selected)
	layer.add_child(world_chart)


func _return_to_main_menu() -> void:
	if not _save_progress():
		message = "D 盘实地存档写入失败，暂不离开；请先检查工作目录权限。"
		_update_hud()
		return
	var change_error := get_tree().change_scene_to_file("res://scenes/main.tscn")
	if change_error != OK:
		message = "实地已存档，但主界面暂时无法载入。"
		_update_hud()


func _world_chart_destinations() -> Array[Dictionary]:
	var ark_position := Vector3.ZERO
	if ark_root:
		ark_position = ark_root.global_position if ark_root.is_inside_tree() else ark_root.position
	return [
		{"id": "home", "title": "仙舟", "position": ark_position + Vector3(0.0, 0.12, 0.0), "risk": 0, "description": "移动中的家园\n可休息、补给、整备与寻求居民支援。"},
		{"id": "shoal", "title": "浅滩", "position": Vector3(11.0, 0.04, -14.0), "risk": 1, "description": "退潮留下的浅滩\n能找到少量漂木和岸边线索。"},
		{"id": "ruin", "title": "风蚀遗迹", "position": Vector3(23.0, 0.5, -17.0), "risk": 3, "description": "石槽里有尚未辨明的遗物\n寒气明显，旧灯仍可作为归途参照。"},
		{"id": "far_reef", "title": "远礁沉筏", "position": Vector3(39.0, 0.04, -29.0), "risk": 3, "description": "低岸外有碎浪横流，白沫可见，北侧留有新鲜兽迹\n可涉水冒险，也可沿礁脊绕行；遇兽可撤离，不设等级门槛。"},
		{"id": "moonback", "title": "月背泊地", "position": TIDE_STATION_POSITION, "risk": 2, "description": "海雾中的旧潮汐观测台\n断续的蓝光仍在闪烁，岸边没有安全航道标记。"},
		{"id": "jade_sail_ark", "title": "琼华舫遗址", "position": JADE_SAIL_ARK_POSITION, "risk": 3, "description": "远海石脊上搁浅的豪华仙舟\n舱骨与迎客居室图样尚存；没有等级门或航线锁。"},
		{"id": "pressure_wreck", "title": "蒸潮机坞", "position": PRESSURE_WRECK_POSITION, "risk": 2, "description": "外海锈色礁岛上，一艘机关补给舫搁浅\n压力阀仍有微弱热汽；沿礁脊寻找可登陆处。"},
	]


func _toggle_world_chart() -> void:
	if world_chart == null:
		return
	world_chart.visible = not world_chart.visible
	if world_chart.visible:
		world_chart.refresh(player.global_position if player else Vector3.ZERO, _world_chart_destinations())
		message = "潮痕图标出几处可去的岸与礁。它只帮你辨方向，不会替你决定先去哪。"
	else:
		message = "你把潮痕图收起，浪声重新近了。"
	_update_hud()


func _on_world_chart_destination_selected(destination_id: String, title: String) -> void:
	for destination in _world_chart_destinations():
		if str(destination.get("id", "")) != destination_id:
			continue
		var target: Vector3 = destination.get("position", Vector3.ZERO)
		var offset := target - player.global_position
		var distance := Vector2(offset.x, offset.z).length()
		_record_world_event("chart_destination_considered", {"destination_id": destination_id, "distance": roundi(distance)})
		message = "潮痕图上选中了%s，约 %.0f 米外。这里只记下方向，不会传送；要不要去仍由你决定。" % [title, distance]
		_save_progress()
		_update_hud()
		return


func _can_share_with_both_residents() -> bool:
	return shelter_built and traveler_boarded and sailmaker_boarded and not resident_gather_pending and not resident_repair_pending and weather_phase != WeatherPhase.STORM and traveler_marker != null and is_instance_valid(traveler_marker) and sailmaker_marker != null and is_instance_valid(sailmaker_marker)


func _begin_shared_table_meal() -> void:
	if shared_meal_gathering_pending or stew_servings <= 0 or shared_meal_day == day_count or not _can_share_with_both_residents():
		return
	stew_servings -= 1
	shared_meal_day = day_count
	shared_meal_gathering_pending = true
	shared_meal_participants = ["player", "tidekeeper", "sailmaker"]
	traveler_action = "把热汤端到桌边"
	traveler_target_position = shelter_position + Vector3(-0.35, 0.12, -0.12)
	sailmaker_action = "收起针线赴饭"
	sailmaker_target_position = shelter_position + Vector3(0.42, 0.12, -0.12)
	traveler_routine_route_target_set = false
	sailmaker_routine_route_target_set = false
	_update_gatherer_nameplate()
	var sailmaker_sign := sailmaker_marker.get_node_or_null("Name") as Label3D
	if sailmaker_sign:
		sailmaker_sign.text = "缝帆人 · %s" % sailmaker_action
	_record_world_event("resident_meal_gathering_started", {"meal_id": "tidal_shellfish_stew", "day": day_count, "participant_ids": shared_meal_participants.duplicate(), "servings_spent": 1, "gathering_positions": {"tidekeeper": _position_facts(traveler_target_position), "sailmaker": _position_facts(sailmaker_target_position)}})
	_save_progress()
	_update_traveler_schedule()
	_update_sailmaker_schedule()


func _try_complete_shared_table_meal() -> bool:
	if not shared_meal_gathering_pending or traveler_marker == null or not is_instance_valid(traveler_marker) or sailmaker_marker == null or not is_instance_valid(sailmaker_marker):
		return false
	if traveler_marker.position.distance_to(traveler_target_position) > 0.09 or sailmaker_marker.position.distance_to(sailmaker_target_position) > 0.09:
		return false
	_complete_shared_table_meal()
	return true


func _complete_shared_table_meal() -> void:
	if not shared_meal_gathering_pending:
		return
	shared_meal_gathering_pending = false
	var meal_day := shared_meal_day
	shared_meal_count += 1
	var participants := shared_meal_participants.duplicate()
	var exposure_before_meal := _effective_cold_exposure_level()
	var health_before_meal := player_health
	var warmth_levels := 2 if pressure_galley_built else 1
	var exposure_after_meal := _relieve_cold_exposure("shared_hot_meal", warmth_levels)
	var health_restored := _restore_player_health("shared_hot_meal", 2 if pressure_galley_built else 1)
	var warmth_restored := exposure_after_meal < exposure_before_meal
	_record_world_event("resident_meal_shared", {"resident_id": "tidekeeper", "participant_ids": participants, "participant_count": participants.size(), "shared_table": true, "day": meal_day, "meal_count": shared_meal_count, "cold_exposure_relieved": warmth_restored, "cold_exposure_levels": warmth_levels, "cold_exposure_level_after": exposure_after_meal, "health_before": health_before_meal, "health_after": player_health, "health_restored": health_restored, "tool_id": "pressure_galley" if pressure_galley_built else "hearth_pot"})
	if not resident_keepsake_present:
		resident_keepsake_present = true
		_add_resident_keepsake()
		_record_world_event("resident_keepsake_placed", {"resident_id": "tidekeeper", "artifact_id": "first_shared_meal_tide_shell", "day": meal_day, "trigger_event": "resident_meal_shared"})
	elif shared_meal_count == 2:
		_add_resident_keepsake()
		_record_world_event("resident_keepsake_pair_completed", {"resident_id": "tidekeeper", "artifact_id": "second_shared_meal_tide_shell", "day": meal_day, "shared_meal_count": shared_meal_count})
	shared_meal_day = maxi(shared_meal_day, day_count)
	traveler_action = "收拾饭后碗盏"
	traveler_target_position = shelter_position + Vector3(-0.35, 0.12, -0.12)
	sailmaker_action = "收好饭碗与针线"
	sailmaker_target_position = shelter_position + Vector3(0.42, 0.12, -0.12)
	shared_meal_participants.clear()
	_update_gatherer_nameplate()
	var sailmaker_sign := sailmaker_marker.get_node_or_null("Name") as Label3D
	if sailmaker_sign:
		sailmaker_sign.text = "缝帆人 · %s" % sailmaker_action
	var warmth_text := "热汤让手脚稍稍回暖。" if warmth_restored and exposure_after_meal > 0 else "热汤也驱散了旅途寒意。" if warmth_restored else ""
	var health_text := "伤处也暖和了些，生命恢复 %d 点。" % health_restored if health_restored > 0 else ""
	if participants.has("sailmaker"):
		message = "你、守潮人与缝帆人围在火盆边分完一锅热汤。缝帆人把针线盒放在脚边：‘我原以为只是在船上搭把手，没想到灯下也给我留了一只碗。’守潮人笑着把空碗收拢。%s%s" % [warmth_text, health_text]
	else:
		message = "你把热汤分给守潮人。她吹凉一口才喝：‘有火、有碗，还有人等我回来，这地方就真像个家了。’%s%s" % [warmth_text, health_text]
	if shared_meal_count == 2:
		message += " 第二次共餐留下的新潮贝，和第一枚并排系在棚梁下。"
	_update_traveler_schedule()
	_update_sailmaker_schedule()
	_save_progress()
	_update_hud()


func _latest_shared_meal_included_sailmaker() -> bool:
	for index in range(world_events.size() - 1, -1, -1):
		var event: Dictionary = world_events[index]
		if str(event.get("id", "")) != "resident_meal_shared":
			continue
		var facts: Dictionary = event.get("facts", {})
		var participants = facts.get("participant_ids", [])
		return participants is Array and participants.has("sailmaker")
	return false


func _interact() -> void:
	var warmth_restored := false
	var nearest: Dictionary = {}
	var nearest_distance := 2.8
	for entry in interactables:
		var target: Node3D = entry.get("node")
		if target == null or not is_instance_valid(target):
			continue
		var distance := player.global_position.distance_to(target.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = entry
	if nearest.is_empty():
		message = "附近没有可互动的东西。"
		_update_hud()
		_update_interaction_hint()
		return
	match str(nearest.id):
		"wood":
			wood += int(nearest.amount)
			var pile: Node = nearest.node
			var item_id := str(nearest.item_id)
			collected_ids.append(item_id)
			_record_world_event("resource_collected", {"node_id": item_id, "resource": "wood", "amount": int(nearest.amount)})
			interactables.erase(nearest)
			pile.queue_free()
			message = "你把潮水留下的木料拖上岸。它们还带着海盐和湿冷的气味。"
		"shellfish":
			raw_shellfish += int(nearest.amount)
			var shells: Node = nearest.node
			var shell_site_id := str(nearest.item_id)
			collected_ids.append(shell_site_id)
			_record_world_event("resource_collected", {"node_id": shell_site_id, "resource": "shellfish", "amount": int(nearest.amount)})
			interactables.erase(nearest)
			shells.queue_free()
			message = "你从潮池石缝里捡到几枚鲜贝。回到棚下的火盆边可以煮一锅热汤。"
		"home":
				_interact_home()
		"helm":
				_toggle_sailing()
		"cot":
			_rest_at_cot()
		"hearth":
				_interact_hearth()
		"storage":
			_interact_storage()
		"workbench":
			_interact_workbench()
		"tidekeeper_box":
			if traveler_boarded:
				message = "浮标箱被绑在右舷的承梁上，木扣仍留着盐霜。守潮人把旧标灯和干燥的修补料分格收好；她说这是她原本准备送去旧避难所的东西。"
			else:
				message = "箱扣系着守潮人的私绳，旁边放着她亲手补过的浮标。她守在一旁；里面的东西要等她自己愿意搬上船再看。"
		"resident":
			if not resident_met:
				resident_met = true
				_record_world_event("resident_met", {"resident_id": "tidekeeper", "weather_phase": weather_phase, "shelter_built": shelter_built})
				message = "岸边的旅人扶住一只旧浮标箱，没有立刻靠近木筏：‘潮水要转了。你这条筏，今晚经得住风吗？’"
			elif traveler_boarded:
				if weather_phase == WeatherPhase.STORM:
					message = "守潮人压住棚边的帆布：‘风正顶着筏舷来。先别出去，等这阵过去再看哪里松了。’"
				elif resident_gather_pending:
					message = "守潮人正沿着岸边收集现成的%s；等她回到船上，东西会直接入舱。仙舟仍可随时启航。" % ("漂木" if resident_gather_resource == "wood" else "潮池鲜贝")
				elif _reflect_on_last_storm():
					pass
				elif resident_repair_pending:
					message = "守潮人把木楔抵紧筏舷：‘这一处我已经接手，等我把最后一道绳结收好。’"
				elif shared_meal_gathering_pending:
					message = "热汤已经端到火盆边。守潮人与缝帆人各自停下手头的事，正往灯下的空位走；这顿饭不会被重复消耗。"
				elif stew_servings > 0 and shared_meal_day != day_count and _can_share_with_both_residents():
					_begin_shared_table_meal()
					message = "你把热汤端到火盆边，给两人各留一只碗。守潮人添好柴，缝帆人把针线收起；她们正往灯下走来。"
				elif stew_servings > 0 and shared_meal_day != day_count:
					stew_servings -= 1
					shared_meal_day = day_count
					shared_meal_count += 1
					var exposure_before_meal := _effective_cold_exposure_level()
					var health_before_meal := player_health
					var warmth_levels := 2 if pressure_galley_built else 1
					var exposure_after_meal := _relieve_cold_exposure("shared_hot_meal", warmth_levels)
					var health_restored := _restore_player_health("shared_hot_meal", 2 if pressure_galley_built else 1)
					warmth_restored = exposure_after_meal < exposure_before_meal
					_record_world_event("resident_meal_shared", {"resident_id": "tidekeeper", "day": day_count, "meal_count": shared_meal_count, "cold_exposure_relieved": warmth_restored, "cold_exposure_levels": warmth_levels, "cold_exposure_level_after": exposure_after_meal, "health_before": health_before_meal, "health_after": player_health, "health_restored": health_restored, "tool_id": "pressure_galley" if pressure_galley_built else "hearth_pot"})
					if not resident_keepsake_present:
						resident_keepsake_present = true
						_add_resident_keepsake()
						_record_world_event("resident_keepsake_placed", {"resident_id": "tidekeeper", "artifact_id": "first_shared_meal_tide_shell", "day": day_count, "trigger_event": "resident_meal_shared"})
					elif shared_meal_count == 2:
						_add_resident_keepsake()
						_record_world_event("resident_keepsake_pair_completed", {"resident_id": "tidekeeper", "artifact_id": "second_shared_meal_tide_shell", "day": day_count, "shared_meal_count": shared_meal_count})
					traveler_action = "收拾饭后碗盏"
					traveler_target_position = Vector3(-0.35, 0.12, 0.7)
					if shared_meal_count == 2:
							message = "你们第二次分着喝完热汤。守潮人把一枚海水磨圆的潮贝系到第一枚旁边：‘这回我知道，灯下不只会有我一个人的碗。’%s%s" % ["热汤让手脚稍稍回暖。" if warmth_restored and exposure_after_meal > 0 else "热汤也驱散了旅途寒意。" if warmth_restored else "", "伤处也暖和了些，生命恢复 %d 点。" % health_restored if health_restored > 0 else ""]
					else:
							message = "你把热汤分给守潮人。她吹凉一口才喝：‘有火、有碗，还有人等我回来，这地方就真像个家了。’%s%s今天已经一起吃过饭，明天还可以再一起吃。" % ["热汤让手脚稍稍回暖。" if warmth_restored and exposure_after_meal > 0 else "热汤也驱散了旅途寒意。" if warmth_restored else "", "伤处也暖和了些，生命恢复 %d 点。" % health_restored if health_restored > 0 else ""]
					_update_traveler_schedule()
					_update_sailmaker_schedule()
				elif weather_phase == WeatherPhase.AFTER and (raft_edge_damaged or shelter_roof_damaged) and stored_wood > 0:
					resident_repair_choice_pending = true
					var repair_name := "筏舷" if raft_edge_damaged else "棚顶"
					message = "守潮人检查完损伤：‘储物箱里还有木料，我可以用 1 块修好%s。’\n1 请她来修　　2 我自己处理或稍后再说" % repair_name
				elif weather_phase == WeatherPhase.AFTER:
					resident_gather_policy_choice_pending = true
					message = "守潮人把湿衣挂在灯边，顺手整理浮标箱：‘明早我会自己去收拾附近现成的物资。你若有急需，可以替我定个方针。’\n当前方针：%s。\n1 木料优先　　2 鲜贝优先　　3 就近均衡　　Esc 保持原安排\n方针只影响之后的出工；一天最多一趟，风雨和启航时我会自行停工或回来。" % _resident_gather_policy_label()
				else:
					message = "守潮人看向西边云墙：‘等会儿风会转向。你决定怎么用那条绳，我都能帮着打结。’"
			elif shelter_built:
				if _can_board_resident("tidekeeper"):
					traveler_choice_pending = true
					message = "守潮人看了看棚顶和岸边的旧浮标箱。‘我可以在这里避一晚，但不想欠下没说清的承诺。’\n1 邀请上筏，共同过夜　　2 尊重对方，暂不同行"
				else:
					message = "守潮人愿意同行，但仙舟的居住泊位已满。扩建出新的住处后，再来邀请她；她不会因此离开这片海岸。"
			else:
				message = "守潮人没有登筏：‘先把能挡雨的地方搭起来吧。我要看见它稳，才敢把箱子搬过去。’"
		"sailmaker":
			if not sailmaker_met:
				sailmaker_met = true
				_record_world_event("resident_met", {"resident_id": "sailmaker", "shelter_built": shelter_built})
				message = "礁石边，一位成年缝帆人正把旧帆摊平，针脚细密而从容。她抬眼看了看你的木筏：‘我叫缝帆的。先把能挡雨的地方搭稳，再谈要不要同行。’"
			elif sailmaker_boarded:
				message = "缝帆人把补好的布边压在膝头：‘帆不必新，受过力的地方补牢了，也能陪船走很久。’她手边那卷旧帆布仍留着海风的咸味。"
			elif shelter_built:
				if _can_board_resident("sailmaker"):
					sailmaker_choice_pending = true
					message = "缝帆人看过棚顶和甲板上的空位：‘这处至少能避雨。我可以先同行一程，帆布和针线我自己带。’\n1 邀请上筏　　2 暂不同路"
				else:
					message = "缝帆人愿意同行，但仙舟的居住泊位已满。扩建出新的住处后，再来邀请她；她会留在这片海域继续缝帆。"
			else:
				message = "缝帆人没有收起旧帆：‘棚子还没立稳，我就先留在礁边。你不必为了我赶工。’"
		"sailmaker_awning":
			message = "棚口多了一片细密补过的帆布。缝帆人说这是她自带的旧帆边，遮不住整艘船，却能让进门时少淋一阵雨。"
		"resident_keepsake":
			if _latest_shared_meal_included_sailmaker():
				message = "潮贝并排系在棚梁下。守潮人记得那晚缝帆人把针线盒放到脚边，也记得后来三个人都在灯下留过一只碗。"
			elif shared_meal_count >= 2:
				message = "两枚潮贝并排系在棚梁下。守潮人说，第一枚记着你们第一次分汤，第二枚记着后来那盏灯下不再只有一只碗。"
			else:
				message = "潮贝被细绳系在棚梁上。守潮人说，这是你们第一次分着喝完热汤后，她从潮池边挑的；如今每次回到灯下，都像有人记得那一晚。"
		"raft_extension":
			if sailing_mode:
				message = "航行时不能拆卸仙舟甲板。"
			else:
				raft_extension_dismantle_pending = true
				message = "拆下龙骨甲板会取回 4 块船板和远礁龙骨" + ("，并返还客舱的 3 块木料与舱骨" if guest_cabin_built else "") + "；已学会的图样不会丢失。\n1 确认拆解　　2 保留甲板"
		"safe_channel":
			message = "浅色布条标出一段退潮时仍可踩行的礁沟。你可以沿着它回到岸上，不必依赖守潮人同行。"
		"lantern":
			if cold_exposure:
				_relieve_cold_exposure("old_lantern")
				message = "你在旧灯旁烘暖手指，慢慢找回力气。遗迹里的寒意退了下去。"
			else:
				message = "旧灯的火苗贴着风摇晃。它不明亮，却足够让木筏在暮色里像个可以回去的地方。"
		"ruin":
			if ruin_searched:
				message = "遗迹里只剩冰冷的石屑和空槽。那枚古旧灵枢已经被你带走。"
			else:
				ruin_searched = true
				ancient_parts += 1
				var exposure_level := _raise_cold_exposure("shore_ruin")
				_record_world_event("ruin_searched", {"site_id": "shore_ruin", "relic_count": 1, "cold_exposure": true, "cold_exposure_level": exposure_level})
				message = "你从裂开的石槽中取出一枚古旧灵枢。寒气顺着指节爬上手臂，动作也迟缓起来；木筏旧灯的暖光仍在远处。"
		"keel_wreck":
			if keel_wreck_searched:
				message = "远礁的沉筏已被拆空。你带回的龙骨还在，但这里没有第二份可取。"
			else:
				keel_wreck_searched = true
				keel_beams += 1
				wood += 4
				var exposure_level := _raise_cold_exposure("far_reef_wreck")
				_refresh_keel_wreck_visual()
				_record_world_event("keel_wreck_salvaged", {"site_id": "far_reef_wreck", "keel_beams": 1, "wood": 4, "cold_exposure": true, "cold_exposure_level": exposure_level, "blueprint_id": "keel_deck_expansion"})
				_learn_blueprint("keel_deck_expansion", "far_reef_wreck")
				message = "你从浪蚀沉筏里撬出一根完整龙骨、四块船板，以及刻在舱板背面的扩甲图样。远礁风口没有遮挡，寒意很快透进衣襟；回家后可从蓝图栏预览龙骨扩甲方案。"
		"tide_station":
			if tide_station_searched:
				message = "旧潮讯台只剩一圈发暗的刻度。你带回的潮枢仍在，图样也已记在心里。"
			else:
				tide_station_searched = true
				tide_relay_cores += 1
				var exposure_level := _raise_cold_exposure("moonback_tide_station")
				_refresh_tide_station_visual()
				_learn_blueprint("tide_compass", "moonback_tide_station")
				_record_world_event("tide_station_salvaged", {"site_id": "moonback_tide_station", "relay_cores": 1, "cold_exposure": true, "cold_exposure_level": exposure_level, "blueprint_id": "tide_compass"})
				message = "你从观测台裂开的铜壳里取出一枚还在微振的潮枢，背面压着一张罗盘阵图。残存的蓝光像在回应远处的浪；回到仙舟工作台，也许能让它读懂风向。"
		"pressure_wreck":
			if pressure_wreck_searched:
				message = "蒸潮坞的压力炉核心已经带回。剖开的舱板上还留着一张可复用的蒸汽饭釜图样；珍贵核心不可再生。"
			else:
				pressure_wreck_searched = true
				pressure_vent_warning_active = false
				pressure_vent_warning_remaining = 0.0
				pressure_vent_cooldown_remaining = 0.0
				pressure_vent_burst_remaining = 0.0
				pressure_cores = 1
				var exposure_level := _raise_cold_exposure("steam_wreck_islet")
				_learn_blueprint("pressure_galley", "steam_wreck_islet")
				_refresh_pressure_wreck_visual()
				_record_world_event("pressure_wreck_salvaged", {"site_id": "steam_wreck_islet", "pressure_cores": 1, "cold_exposure": true, "cold_exposure_level": exposure_level, "blueprint_id": "pressure_galley", "tech_style": "steam_mechanism", "vent_disarmed": true})
				message = "锈红色舱板后，一枚压力炉核心还在缓缓吐出热汽。你记下蒸汽饭釜的图样，将核心带回家；礁岛的寒意钻进袖口，但没有挡住归路。"
		"jade_sail_ark":
			if jade_sail_ark_searched:
				message = "琼华舫的客居名册与航路账册已收在你的记忆里。账页写着它曾靠客居、补给与航路服务维持船队；舱骨图样也已永久学会。沿舱侧斜坡可以登上客舱，里面还留着一枚琉璃舷珠。如今的船员仍在这里，经营权必须逐项谈妥。"
			else:
				jade_sail_ark_searched = true
				guest_cabin_frames = 1
				var exposure_level := _raise_cold_exposure("jade_sail_ark_wreck")
				_learn_blueprint("tide_guest_cabin", "jade_sail_ark")
				_refresh_jade_sail_ark_visual()
				_record_world_event("jade_sail_ark_salvaged", {"site_id": "jade_sail_ark", "guest_cabin_frames": 1, "cold_exposure": true, "cold_exposure_level": exposure_level, "blueprint_id": "tide_guest_cabin", "industry_ledger_clue": "guest_stay_supply_and_route_services"})
				message = "琼华舫的舱门被礁石挤裂，里面却还留着一根完整舱骨和迎客舱图样。名册记着船员各自负责客居、补给与航路服务——这艘船曾是一个生意兴旺的家。你把图样记进蓝图册；回舟可用 3 块木料和这根舱骨造出一间客舱。上层还有一处能走进去的留宿舱，舱角那枚琉璃舷珠也许能换来一夜安稳。船尾有人影听见动静，死寂的阵灯仍让寒意沿指节爬上来。"
		"jade_sail_guest_bead":
			if not jade_sail_ark_searched:
				message = "碎裂的舱板还压着舱内物件；先搜过琼华舫的名册，才能看清哪些东西适合带走。"
			elif jade_sail_guest_bead_collected:
				message = "琉璃舷珠已经收在你身上，不会在读档或重复探索时再出现。"
			else:
				jade_sail_guest_bead_collected = true
				_record_world_event("jade_sail_guest_bead_found", {"vessel_id": "jade_sail_ark", "artifact_id": "jade_sail_glass_bead", "unique": true, "location": "upper_guest_cabin"})
				_refresh_jade_sail_guest_visuals()
				message = "你从客舱一角拾起一枚海水磨亮的琉璃舷珠。阮青漪认得这件旧物；若愿交还给琼华舫，可以在完整的客榻住一夜。"
		"jade_sail_guest_registry":
			if not jade_sail_ark_searched:
				message = "柜上的名册被舱灰盖住了。先搜过琼华舫，才知道这里仍保留着什么客居服务。"
			elif not jade_sail_keeper_met:
				message = "客居名册还在，但船员没有确认房间能否开放。先去舱门外认识掌事阮青漪。"
			elif jade_sail_guest_stay_used:
				message = "名册记着你已经用琉璃舷珠换过一夜客居。那张留宿帖已作废；以后若要再住，需要另谈新的服务。"
			elif jade_sail_guest_pass_active:
				message = "阮青漪已把客舱留给你一夜。客榻就在里侧；上去躺下会睡到次日清晨，自己的仙舟、居民与行李仍各自留在原处。"
			elif jade_sail_guest_bead_collected:
				jade_sail_guest_choice_pending = true
				message = "你将琉璃舷珠放在名册旁。阮青漪核过旧账，确认它确是琼华舫失散多年的客居信物：她愿用它换你在完整舱室留宿一夜。只是客居，不转让船体、经营权或船员安排权。\n1 交还舷珠，换一夜留宿　　2 留着舷珠"
			else:
				message = "阮青漪留下的规矩还写在名册里：临时客居不等于收编产业。那枚遗失的琉璃舷珠仍在客舱里，找到它后可以在这里登记一夜留宿。"
		"jade_sail_guest_berth":
			if jade_sail_guest_pass_active:
				_rest_at_jade_sail_guest_berth()
			elif jade_sail_guest_stay_used:
				message = "这张客榻已经为你留过一夜。阮青漪收起了那份一次性留宿帖；你可以回到自己的仙舟，或继续在琼华舫周围探索。"
			else:
				message = "客榻铺着干燥的旧帆布，窗边仍能望见自己的仙舟。先在门边客居名册登记；琉璃舷珠可换一夜留宿，不需要签产业契约。"
		"jade_sail_keeper":
			if not jade_sail_keeper_met:
				jade_sail_keeper_met = true
				jade_sail_keeper_action = "守着旧舫"
				_record_world_event("jade_sail_keeper_met", {"keeper_id": "ruan_qingyi", "vessel_id": "jade_sail_ark", "adult_crew": true})
				message = "掌事阮青漪从舱门边走出来，衣袖沾着礁砂。她先报了姓名，再看向船上仍在等她的船员：‘这艘船不是货物。若要让琼华舫重新营生，得先说清修缮、补给和船员各自的决定权。’"
			elif jade_sail_industry_active:
				if jade_sail_industry_pending:
					message = "阮青漪正在把本次潮池补给带回琼华舫；已经采下的物资只会入这艘船自己的货舱，不会混进你的小仙舟。"
				elif jade_sail_vessel_title_owned:
					message = "阮青漪翻开产业簿：‘琼华舫的船体资产已由原船共同体自愿移交给你；我仍负责日常营生，船员各自保留去留与拒绝差事的权利。鲜贝 %d，漂木 %d。’" % [jade_sail_industry_shellfish, jade_sail_industry_wood]
				elif jade_sail_industry_acquired:
						if jade_sail_industry_deliveries < 3:
							message = "阮青漪翻开经营簿：‘琼华舫的长期营生已归你统筹，船体产权仍属于原船共同体。等累计完成三次真实交货，我们再谈要不要把船体资产也交给你；目前 %d/3 次。’鲜贝 %d，漂木 %d。" % [jade_sail_industry_deliveries, jade_sail_industry_shellfish, jade_sail_industry_wood]
						elif wood < JADE_INDUSTRY_TITLE_TRANSFER_WOOD_COST:
							message = "三次真实交货已经证明营生能够运转。阮青漪代表原船共同体提出自愿移交船体资产；若你愿接手，需另留 %d 块木料作交接后的维护储备。当前有 %d 块，经营权不受影响。" % [JADE_INDUSTRY_TITLE_TRANSFER_WOOD_COST, wood]
						else:
							jade_sail_industry_choice_pending = true
							jade_sail_industry_choice_kind = "vessel_title"
							message = "三次真实交货后，阮青漪代表琼华舫共同体提出自愿移交船体资产：你投入 %d 块木料，作为交接后的维护储备；船员不会随船变成资产，她仍可继续掌管日常营生，每个人保留去留与拒绝差事的权利。你的主仙舟、居民和背包都不改变。\n1 接收琼华舫船体资产　　2 只保留产业经营权" % JADE_INDUSTRY_TITLE_TRANSFER_WOOD_COST
				elif jade_sail_industry_deliveries < 2:
					message = "阮青漪指着试营账目：‘先把合作补给跑稳。真实交货记到两次后，我们再谈长期经营权；目前完成 %d/2 次。’" % jade_sail_industry_deliveries
				elif wood < JADE_INDUSTRY_AFFILIATION_WOOD_COST:
					message = "试营已经有了两次真实交货。若要把琼华舫的长期经营权收编进你的产业，需要再投入 %d 块修缮木料；当前有 %d 块。船员安排权仍会留给阮青漪。" % [JADE_INDUSTRY_AFFILIATION_WOOD_COST, wood]
				else:
					jade_sail_industry_choice_pending = true
					jade_sail_industry_choice_kind = "affiliation"
					message = "两次交货都来自岸上仍存在的资源，试营账目已经对得上。阮青漪提出长期经营契约：再投入 %d 块木料，琼华舫正式收编为你的产业；她继续掌管船员日常，船体和船员不会被当成道具转手。经营范围扩展到附近有限漂木，仍逐件采集、分别入舱。\n1 接受收编经营　　2 保持合作试营" % JADE_INDUSTRY_AFFILIATION_WOOD_COST
			elif not jade_sail_ark_searched:
				message = "阮青漪还不谈经营：‘先看看船舱里的旧名册和货账。弄清这艘船靠什么营生，再决定要不要合作。’"
			elif wood < JADE_INDUSTRY_REPAIR_WOOD_COST:
				message = "阮青漪愿意谈合作，但迎客甲板还缺修材。契约需要你投入 %d 块木料；当前只有 %d 块。她会留在琼华舫，不催你赶工。" % [JADE_INDUSTRY_REPAIR_WOOD_COST, wood]
			else:
					jade_sail_industry_choice_pending = true
					jade_sail_industry_choice_kind = "cooperative"
					message = "阮青漪把一页试营契约推到你面前：投入 %d 块木料修复迎客区，先共同经营潮池补给；她保留船员安排权，船员也可以拒绝不合理的差事。补给来自地图上有限的真实潮池，运回琼华舫独立货舱。两次真实交货后，才有资格继续谈长期收编。\n1 签下合作试营　　2 暂不签" % JADE_INDUSTRY_REPAIR_WOOD_COST
		"jade_sail_cargo":
			if not jade_sail_industry_active:
				message = "琼华舫的货舱还未接入任何经营契约；这里不会出现凭空刷新的货物。"
			else:
				var withdrawn_shellfish := jade_sail_industry_shellfish
				var withdrawn_wood := jade_sail_industry_wood
				if withdrawn_shellfish <= 0 and withdrawn_wood <= 0:
					message = "琼华舫货舱暂时没有可分取的货物。阮青漪只会在游戏内清晨出工，采集现存资源后再入舱。"
				else:
					jade_sail_industry_shellfish = 0
					jade_sail_industry_wood = 0
					raw_shellfish += withdrawn_shellfish
					wood += withdrawn_wood
					if withdrawn_shellfish > 0:
						_record_world_event("jade_sail_industry_supply_withdrawn", {"vessel_id": "jade_sail_ark", "resource": "shellfish", "amount": withdrawn_shellfish, "destination": "player_inventory"})
					if withdrawn_wood > 0:
						_record_world_event("jade_sail_industry_supply_withdrawn", {"vessel_id": "jade_sail_ark", "resource": "wood", "amount": withdrawn_wood, "destination": "player_inventory"})
					message = "你按经营契约从琼华舫独立货舱取出鲜贝 %d、漂木 %d，分别记入自己的背包。" % [withdrawn_shellfish, withdrawn_wood]
					_refresh_jade_sail_ark_visual()
		"guest_cabin":
			if sailmaker_boarded and sailmaker_guest_cabin_first_night:
				message = "缝帆人把针线盒收在床头。她说：‘有一扇能掩上的门，知道灯会为谁亮，这才像自己的家。往后若经营客舫，也该先给船员留一间这样的屋子。’"
			elif sailmaker_boarded and guest_cabin_built:
				message = "听潮客舱已经成了仙舟的一部分。缝帆人知道这里有张空床；等夜深，她会自己决定是否在此歇下。"
			else:
				message = "听潮客舱已经成了仙舟的一部分。它为一位远道而来的居民留出真实床位；收编豪华仙舟时，也应先谈好船员、补给与服务，而不只是把名字记进名册。"
	_update_hud()
	_save_progress()
	_update_interaction_hint()


func _choose_jade_sail_industry_contract(accept: bool) -> void:
	if not jade_sail_industry_choice_pending:
		return
	var choice_kind := jade_sail_industry_choice_kind
	jade_sail_industry_choice_pending = false
	jade_sail_industry_choice_kind = ""
	if not accept:
		if choice_kind == "vessel_title":
			_record_world_event("jade_sail_vessel_title_transfer_declined", {"keeper_id": "ruan_qingyi", "vessel_id": "jade_sail_ark", "wood_preserved": wood, "management_rights_retained": jade_sail_industry_acquired, "vessel_ownership_transferred": false})
			message = "你决定先不接手船体。阮青漪点头：‘经营权照旧，琼华舫还是我们的家。等你准备好承担整艘船的维护，再谈也不迟。’"
		elif choice_kind == "affiliation":
			_record_world_event("jade_sail_industry_affiliation_declined", {"keeper_id": "ruan_qingyi", "vessel_id": "jade_sail_ark", "wood_preserved": wood, "cooperative_contract_retained": jade_sail_industry_active})
			message = "阮青漪把长期经营约收回册中：‘那就先按合作试营走，货舱和船员安排都照旧。以后想扩大经营，再来谈。’"
		else:
			_record_world_event("jade_sail_industry_contract_declined", {"keeper_id": "ruan_qingyi", "vessel_id": "jade_sail_ark", "wood_preserved": wood})
			message = "阮青漪把试营契约收回册中：‘那就先做朋友，不急着谈经营。琼华舫仍是我们的家，你想清楚了再来。’"
	elif choice_kind == "vessel_title":
		if not jade_sail_industry_active or not jade_sail_industry_acquired or jade_sail_vessel_title_owned or not jade_sail_keeper_met or not jade_sail_ark_searched:
			message = "船体移交条件已经变化，琼华舫产权没有改变，现有经营权保持不变。"
		elif jade_sail_industry_deliveries < 3:
			message = "还需要三次真实营生交货作为移交依据；船体产权没有改变。"
		elif wood < JADE_INDUSTRY_TITLE_TRANSFER_WOOD_COST:
			message = "维护储备不足，船体没有移交；原有经营权和木料都保持不变。"
		else:
			wood -= JADE_INDUSTRY_TITLE_TRANSFER_WOOD_COST
			jade_sail_industry_wood += JADE_INDUSTRY_TITLE_TRANSFER_WOOD_COST
			jade_sail_vessel_title_owned = true
			_record_world_event("jade_sail_vessel_title_transferred", {"keeper_id": "ruan_qingyi", "vessel_id": "jade_sail_ark", "previous_owner": "jade_sail_crew_cooperative", "new_owner": "player_industry", "wood_moved_to_maintenance_reserve": JADE_INDUSTRY_TITLE_TRANSFER_WOOD_COST, "keeper_consent": true, "crew_employment_transferred": false, "crew_can_refuse_work": true, "crew_can_leave": true, "crew_authority_retained": true, "management_rights_transferred": true, "vessel_ownership_transferred": true, "player_ark_replaced": false, "trial_deliveries": jade_sail_industry_deliveries})
			_refresh_jade_sail_ark_visual()
			message = "琼华舫共同体自愿完成船体资产移交。你将 %d 块木料转入琼华舫维护储备，取得船体资产与产业经营权；阮青漪继续统筹营生，船员没有被转让，仍可自主去留并拒绝差事。你的小仙舟与居民完全不变。" % JADE_INDUSTRY_TITLE_TRANSFER_WOOD_COST
	elif choice_kind == "affiliation":
		if not jade_sail_industry_active or jade_sail_industry_acquired or not jade_sail_keeper_met or not jade_sail_ark_searched:
			message = "经营资格已经变化，长期经营约没有生效；原有合作状态保持不变。"
		elif jade_sail_industry_deliveries < 2:
			message = "两次真实交货的试营条件尚未满足，长期经营约没有生效。"
		elif wood < JADE_INDUSTRY_AFFILIATION_WOOD_COST:
			message = "修缮木料不足，长期经营约没有生效；原有合作试营不受影响。"
		else:
			wood -= JADE_INDUSTRY_AFFILIATION_WOOD_COST
			jade_sail_industry_acquired = true
			jade_sail_keeper_action = "统筹产业补给"
			_record_world_event("jade_sail_industry_affiliation_signed", {"keeper_id": "ruan_qingyi", "vessel_id": "jade_sail_ark", "industry_type": "supply_and_salvage", "wood_spent": JADE_INDUSTRY_AFFILIATION_WOOD_COST, "keeper_consent": true, "management_rights_transferred": true, "vessel_ownership_transferred": false, "crew_authority_retained": true, "trial_deliveries": jade_sail_industry_deliveries})
			message = "长期经营约生效。你投入 %d 块木料，取得琼华舫补给与近岸打捞营生的经营权；船体仍属原船共同体，阮青漪保留船员日常安排权。此后可从船边有限漂木中采集，所有货物仍先入琼华舫独立货舱。" % JADE_INDUSTRY_AFFILIATION_WOOD_COST
	elif choice_kind != "cooperative":
		message = "这份经营选择已失效，没有扣除物资。"
	elif not jade_sail_keeper_met or not jade_sail_ark_searched:
		message = "旧账册与船员共识尚未齐备，契约没有生效。"
	elif jade_sail_industry_active:
		message = "琼华舫已经开始合作试营，不需要重复签约。"
	elif wood < JADE_INDUSTRY_REPAIR_WOOD_COST:
		message = "木料不够，契约没有生效；阮青漪把已经拟好的条款留给你，等凑齐修材再谈。"
	else:
		wood -= JADE_INDUSTRY_REPAIR_WOOD_COST
		jade_sail_industry_active = true
		jade_sail_industry_last_day = 0
		jade_sail_keeper_action = "安排琼华舫营生"
		_record_world_event("jade_sail_industry_contract_signed", {"keeper_id": "ruan_qingyi", "vessel_id": "jade_sail_ark", "industry_type": "local_supply", "wood_spent": JADE_INDUSTRY_REPAIR_WOOD_COST, "keeper_consent": true, "vessel_transferred": false, "crew_authority_retained": true})
		_refresh_jade_sail_ark_visual()
		message = "契约生效。你投入 %d 块木料修复迎客区；琼华舫以合作产业加入经营簿，阮青漪仍掌管原船员。下一次游戏内清晨，她会查看附近真实潮池，能采到才会把补给送进琼华舫自己的货舱。" % JADE_INDUSTRY_REPAIR_WOOD_COST
	_save_progress()
	_update_hud()


func _choose_jade_sail_guest_pass(accept: bool) -> void:
	if not jade_sail_guest_choice_pending:
		return
	jade_sail_guest_choice_pending = false
	if not accept:
		_record_world_event("jade_sail_guest_pass_declined", {"keeper_id": "ruan_qingyi", "vessel_id": "jade_sail_ark", "artifact_preserved": jade_sail_guest_bead_collected})
		message = "你把琉璃舷珠收回衣袋。阮青漪没有催促：‘客舱会留着，什么时候想住，再来登记。’"
	elif not jade_sail_keeper_met or not jade_sail_ark_searched or not jade_sail_guest_bead_collected or jade_sail_guest_pass_active or jade_sail_guest_stay_used:
		message = "客居登记条件已经变化，名册没有收下舷珠；信物仍在你手里。"
	else:
		jade_sail_guest_bead_collected = false
		jade_sail_guest_pass_active = true
		_record_world_event("jade_sail_guest_pass_granted", {"keeper_id": "ruan_qingyi", "vessel_id": "jade_sail_ark", "artifact_id": "jade_sail_glass_bead", "artifact_spent": true, "nights_granted": 1, "management_rights_transferred": false, "vessel_ownership_transferred": false, "player_ark_replaced": false})
		message = "阮青漪把琉璃舷珠收进客居名册，递给你一张只用一次的留宿帖。一夜客舱已为你留好，可随时去客榻使用；这只是客居服务，不是收编、购船或接管船员。"
	_refresh_jade_sail_guest_visuals()
	_save_progress()
	_update_hud()
	_update_interaction_hint()


func _begin_jade_sail_industry_daily_gather() -> bool:
	if not jade_sail_industry_active or jade_sail_industry_pending or day_period != DayPeriod.MORNING:
		return false
	if day_count <= jade_sail_industry_last_day:
		return false
	jade_sail_industry_last_day = day_count
	if weather_phase == WeatherPhase.STORM or jade_sail_keeper_marker == null or not is_instance_valid(jade_sail_keeper_marker):
		return false
	var selected: Dictionary = {}
	var selected_distance := JADE_INDUSTRY_GATHER_RADIUS
	for entry in interactables:
		var resource := str(entry.get("id", ""))
		var item_id := str(entry.get("item_id", ""))
		var resource_is_eligible := resource == "shellfish" and JADE_INDUSTRY_RESOURCE_IDS.has(item_id)
		resource_is_eligible = resource_is_eligible or (jade_sail_industry_acquired and resource == "wood" and JADE_INDUSTRY_WOOD_IDS.has(item_id))
		if not resource_is_eligible:
			continue
		var target := entry.get("node") as Node3D
		if target == null or not is_instance_valid(target) or collected_ids.has(item_id):
			continue
		var distance := jade_sail_keeper_marker.global_position.distance_to(target.global_position)
		if distance < selected_distance:
			selected = entry
			selected_distance = distance
	if selected.is_empty():
		_record_world_event("jade_sail_industry_gather_unavailable", {"vessel_id": "jade_sail_ark", "day": day_count, "reason": "no_uncollected_local_supply"})
		return false
	var target_node := selected.get("node") as Node3D
	jade_sail_industry_pending = true
	jade_sail_industry_phase = "outbound"
	jade_sail_industry_resource = str(selected.get("id", ""))
	jade_sail_industry_target_id = str(selected.get("item_id", ""))
	jade_sail_industry_target_position = target_node.global_position
	jade_sail_industry_payload = 0
	jade_sail_industry_pickup_remaining = JADE_INDUSTRY_PICKUP_SECONDS
	jade_sail_keeper_action = "前往潮池"
	_record_world_event("jade_sail_industry_gather_started", {"vessel_id": "jade_sail_ark", "keeper_id": "ruan_qingyi", "target_id": jade_sail_industry_target_id, "resource": jade_sail_industry_resource, "day": day_count, "target_position": _position_facts(jade_sail_industry_target_position)})
	_update_jade_sail_keeper_nameplate()
	_save_progress()
	return true


func _process_jade_sail_industry_gathering(delta: float) -> bool:
	if not jade_sail_industry_pending or jade_sail_keeper_marker == null or not is_instance_valid(jade_sail_keeper_marker):
		return false
	if weather_phase == WeatherPhase.STORM:
		_abort_jade_sail_industry_gathering("storm_arrival")
		return false
	if jade_sail_industry_phase in ["outbound", "collecting"] and collected_ids.has(jade_sail_industry_target_id):
		_abort_jade_sail_industry_gathering("resource_taken_before_arrival")
		return false
	var target_position := jade_sail_industry_target_position
	if jade_sail_industry_phase == "returning":
		target_position = JADE_INDUSTRY_HOME_POSITION
	target_position.y = jade_sail_keeper_marker.global_position.y
	var offset := target_position - jade_sail_keeper_marker.global_position
	offset.y = 0.0
	var moving := offset.length() > 0.06
	if moving:
		jade_sail_keeper_marker.global_position = jade_sail_keeper_marker.global_position.move_toward(target_position, maxf(0.0, delta) * JADE_INDUSTRY_GATHER_SPEED)
		var direction := Vector3(offset.x, 0.0, offset.z).normalized()
		jade_sail_keeper_marker.rotation.y = atan2(-direction.x, -direction.z)
	if jade_sail_industry_phase == "outbound" and not moving:
		jade_sail_industry_phase = "collecting"
		jade_sail_industry_pickup_remaining = JADE_INDUSTRY_PICKUP_SECONDS
		jade_sail_keeper_action = "采集潮池鲜贝"
		_update_jade_sail_keeper_nameplate()
		_save_progress()
	elif jade_sail_industry_phase == "collecting":
		jade_sail_industry_pickup_remaining -= maxf(0.0, delta)
		if jade_sail_industry_pickup_remaining <= 0.0:
			_harvest_jade_sail_industry_target()
	elif jade_sail_industry_phase == "returning" and not moving:
		_finish_jade_sail_industry_gathering("vessel_hold")
	return moving


func _harvest_jade_sail_industry_target() -> void:
	if not jade_sail_industry_pending or jade_sail_industry_phase != "collecting":
		return
	for index in range(interactables.size()):
		var entry: Dictionary = interactables[index]
		if str(entry.get("item_id", "")) != jade_sail_industry_target_id or str(entry.get("id", "")) != jade_sail_industry_resource:
			continue
		var node := entry.get("node") as Node3D
		if node == null or not is_instance_valid(node) or collected_ids.has(jade_sail_industry_target_id):
			break
		var amount := maxi(0, int(entry.get("amount", 0)))
		interactables.remove_at(index)
		collected_ids.append(jade_sail_industry_target_id)
		node.queue_free()
		jade_sail_industry_payload = amount
		jade_sail_industry_phase = "returning"
		jade_sail_keeper_action = "把鮮貝帶回貨舱"
		_record_world_event("resource_collected", {"node_id": jade_sail_industry_target_id, "resource": jade_sail_industry_resource, "amount": amount, "collector": "vessel_crew", "resident_id": "ruan_qingyi", "vessel_id": "jade_sail_ark"})
		_record_world_event("jade_sail_industry_gather_harvested", {"vessel_id": "jade_sail_ark", "keeper_id": "ruan_qingyi", "target_id": jade_sail_industry_target_id, "resource": jade_sail_industry_resource, "amount": amount})
		_update_jade_sail_keeper_nameplate()
		_save_progress()
		_update_hud()
		return
	_abort_jade_sail_industry_gathering("resource_taken_before_arrival")


func _finish_jade_sail_industry_gathering(delivery_mode: String) -> void:
	if not jade_sail_industry_pending:
		return
	var target_id := jade_sail_industry_target_id
	var resource := jade_sail_industry_resource
	var amount := jade_sail_industry_payload
	jade_sail_industry_pending = false
	jade_sail_industry_phase = ""
	jade_sail_industry_resource = ""
	jade_sail_industry_target_id = ""
	jade_sail_industry_payload = 0
	jade_sail_industry_pickup_remaining = 0.0
	jade_sail_keeper_marker.global_position = JADE_INDUSTRY_HOME_POSITION
	jade_sail_keeper_action = "整理琼华舫货舱"
	if amount > 0:
		if resource == "wood":
			jade_sail_industry_wood += amount
		else:
			jade_sail_industry_shellfish += amount
		jade_sail_industry_deliveries += 1
		var vessel_cargo := jade_sail_industry_wood if resource == "wood" else jade_sail_industry_shellfish
		_record_world_event("jade_sail_industry_supply_delivered", {"vessel_id": "jade_sail_ark", "keeper_id": "ruan_qingyi", "target_id": target_id, "resource": resource, "amount": amount, "delivery_mode": delivery_mode, "vessel_cargo": vessel_cargo})
		message = "阮青漪把 %d 份%s放进琼华舫自己的货舱，记作产业货物；你的小仙舟库存没有变化。" % [amount, "漂木" if resource == "wood" else "鲜贝"]
	else:
		_record_world_event("jade_sail_industry_gather_cancelled", {"vessel_id": "jade_sail_ark", "target_id": target_id, "reason": delivery_mode, "resource": resource, "resource_preserved": true})
		message = "阮青漪回到琼华舫：这处潮池已被先一步采空，本次没有虚记产出。"
	_update_jade_sail_keeper_nameplate()
	_refresh_jade_sail_ark_visual()
	_save_progress()
	_update_hud()


func _abort_jade_sail_industry_gathering(reason: String) -> bool:
	if not jade_sail_industry_pending:
		return false
	if jade_sail_industry_payload > 0:
		_finish_jade_sail_industry_gathering(reason)
		return true
	var target_id := jade_sail_industry_target_id
	var resource := jade_sail_industry_resource
	jade_sail_industry_pending = false
	jade_sail_industry_phase = ""
	jade_sail_industry_resource = ""
	jade_sail_industry_target_id = ""
	jade_sail_industry_payload = 0
	jade_sail_industry_pickup_remaining = 0.0
	if jade_sail_keeper_marker and is_instance_valid(jade_sail_keeper_marker):
		jade_sail_keeper_marker.global_position = JADE_INDUSTRY_HOME_POSITION
	jade_sail_keeper_action = "守着琼华舫"
	_record_world_event("jade_sail_industry_gather_cancelled", {"vessel_id": "jade_sail_ark", "target_id": target_id, "reason": reason, "resource": resource, "resource_preserved": true})
	message = "风雨或资源变化打断了琼华舫的采集；没有扣物资，也没有重复记账。"
	_update_jade_sail_keeper_nameplate()
	_save_progress()
	_update_hud()
	return true


func _update_jade_sail_keeper_nameplate() -> void:
	if jade_sail_keeper_marker == null or not is_instance_valid(jade_sail_keeper_marker):
		return
	var sign := jade_sail_keeper_marker.get_node_or_null("Name") as Label3D
	if sign:
		var status := jade_sail_keeper_action if not jade_sail_keeper_action.is_empty() else "守着旧舫"
		sign.text = "阮青漪 · %s" % status


func _interact_home() -> void:
	if weather_phase == WeatherPhase.FORECAST and rope_available:
		preparation_choice_pending = true
		if shelter_built:
				message = "旧浮标开始急促地敲石。手里只有一条好绳：\n1 固定避风棚　　2 固定筏舷　　3 暂不使用，接受风雨损伤"
		else:
				message = "云墙将在下一次涨潮时抵岸。手里只有一条好绳：\n1 固定筏舷　　2 暂不使用，之后可能要修筏"
		return
	if weather_phase == WeatherPhase.FORECAST:
		if not shelter_built:
			message = "木筏仍能浮，但外沿已经松了。云墙和浮标的敲击声都在提醒你：下一次涨潮时会有强风雨。可以继续探索，按 R 让时间推进。"
		elif wood >= BUILD_COST:
			message = "棚子已经有了遮蔽。云墙会在下一次涨潮时抵岸；按 R 推进天气，或先继续准备与探索。"
		else:
			message = "木板间已有一处遮蔽，浮标却敲得越来越急。按 R 推进天气，或先继续探索。"
		return
	if weather_phase == WeatherPhase.STORM:
		message = "雨斜着打过浅滩，木筏在浪里摇晃。你仍能行动；按 R 等这阵风雨过去。"
		return
	if shelter_roof_damaged or raft_edge_damaged:
		if wood > 0:
			repair_choice_pending = true
			message = "雨停了，损伤都还可以修。每修一处要用 1 块木料：\n%s%s3 先不修" % ["1 修复棚顶　　" if shelter_roof_damaged else "", "2 修复筏舷　　" if raft_edge_damaged else ""]
		else:
			message = "雨停了。棚顶或筏舷有损，需要木料修补；附近还可以继续探索。"
		return
	if shelter_built:
		message = "棚子和筏舷都撑过了风雨。你可以整理物件、休息，或继续去岛上看看。"
	else:
		message = "木筏在风雨后还浮着，只是筏舷有些松动。找到木料后可以回来修。"


func _interact_hearth() -> void:
	if not shelter_built or (_ark_node("BuiltShelter/HearthPot") == null and _ark_node("BuiltShelter/PressureGalley") == null):
		message = "还没有可以生火做饭的地方。先搭起避风棚，再在棚下安置火盆。"
	elif raw_shellfish < 1:
		message = "饭釜里还留着余温。潮池的鲜贝已经吃完，退潮时可以再去岸边找找。" if pressure_galley_built else "火盆里还留着温度。潮池的鲜贝已经吃完，退潮时可以再去岸边找找。"
	else:
		raw_shellfish -= 1
		stew_servings += 1
		var warmth_levels := 2 if pressure_galley_built else 1
		_record_world_event("meal_prepared", {"meal_id": "tidal_shellfish_stew", "day": day_count, "raw_shellfish_spent": 1, "servings_added": 1, "tool_id": "pressure_galley" if pressure_galley_built else "hearth_pot", "warmth_levels": warmth_levels})
		message = "蒸汽饭釜的压力阀轻响，鲜贝汤很快煨好。热气能多留一会儿，和守潮人分汤时也更能抵住寒意。" if pressure_galley_built else "你把鲜贝放进火盆上的小锅，慢慢煮成一碗热汤。先留着，等守潮人回来可以一起吃。"
		_update_traveler_schedule()
		_update_sailmaker_schedule()
	_save_progress()
	_update_hud()


func _rest_at_cot() -> void:
	if not shelter_built or _ark_node("BuiltShelter/Cot") == null:
		message = "还没有能安稳躺下的地方。先搭起避风棚。"
		return
	var advancement := _advance_world_period("rest")
	var health_restored := _restore_player_health("cot_rest")
	if cold_exposure:
		var previous_exposure_level := _effective_cold_exposure_level()
		_relieve_cold_exposure("cot_rest")
		message = "你在棚下裹紧旧毯，睡到身体重新暖起来。寒意从 %d/3 退到 0/3。醒来时，已是%s。" % [previous_exposure_level, _day_period_label()]
	else:
		message = "你在自己的棚下睡了一觉。醒来时已是%s，灯火和浮标箱旁都有人生活过的痕迹。" % _day_period_label()
	if health_restored > 0:
		message += " 伤势也已养好，生命恢复 %d 点。" % health_restored
	_append_period_outcomes(advancement)
	_save_progress()
	_update_hud()


func _rest_at_jade_sail_guest_berth() -> void:
	if jade_sail_guest_stay_used:
		message = "这张客榻已经为你留过一夜；一次性的客居帖不会重复生效。"
		return
	if not jade_sail_guest_pass_active:
		message = "还没有留宿帖。去舱门边的客居名册登记，琉璃舷珠可以换来一夜客居。"
		return
	var stay_started_day := day_count
	var stay_started_period := day_period
	var exposure_before := _effective_cold_exposure_level()
	var health_before := player_health
	var target_morning_day := day_count + 1
	var period_advancements: Array[Dictionary] = []
	jade_sail_guest_pass_active = false
	jade_sail_guest_stay_used = true
	_record_world_event("jade_sail_guest_night_started", {"vessel_id": "jade_sail_ark", "bed_id": "upper_guest_cabin_berth", "day": stay_started_day, "period": stay_started_period, "pass_spent": true})
	while day_count < target_morning_day or day_period != DayPeriod.MORNING:
		period_advancements.append(_advance_world_period("jade_sail_guest_stay"))
	var exposure_after := _relieve_cold_exposure("jade_sail_guest_stay")
	var health_restored := _restore_player_health("jade_sail_guest_stay")
	_record_world_event("jade_sail_guest_night_completed", {"vessel_id": "jade_sail_ark", "bed_id": "upper_guest_cabin_berth", "from_day": stay_started_day, "from_period": stay_started_period, "to_day": day_count, "to_period": day_period, "periods_slept": period_advancements.size(), "cold_exposure_before": exposure_before, "cold_exposure_after": exposure_after, "health_before": health_before, "health_after": player_health, "health_restored": health_restored, "management_rights_transferred": false, "vessel_ownership_transferred": false, "player_ark_replaced": false})
	message = "你在听潮舱的帆顶下安稳睡到次日清晨。醒来时，琉璃窗透进一线暖光；自己的仙舟、船员和行李都仍留在原处。" + (" 客舱里的干燥暖意也驱散了积下的寒意。" if exposure_after < exposure_before else "")
	if health_restored > 0:
		message += " 睡眠也让伤势恢复了 %d 点。" % health_restored
	for advancement in period_advancements:
		_append_period_outcomes(advancement)
	_refresh_jade_sail_guest_visuals()
	_save_progress()
	_update_hud()
	_update_interaction_hint()


func _wait_one_period() -> void:
	if building_mode or sailing_mode or (world_chart != null and world_chart.visible):
		message = "现在不适合停下脚步；先收起建造、航行或潮痕图界面。"
		_update_hud()
		return
	var advancement := _advance_world_period("wait")
	message = "你停下手边的事，让一段光阴安静流过。现在是%s。" % _day_period_label()
	if cold_exposure:
		message += " 寒意仍在；等待不会替代棚下休息。"
	_append_period_outcomes(advancement)
	_save_progress()
	_update_hud()


func _advance_world_period(cause: String) -> Dictionary:
	var resident_prepared_meal := _complete_resident_cooking()
	var previous_day := day_count
	day_period = (day_period + 1) % 4
	if day_period == DayPeriod.MORNING:
		day_count += 1
	_set_weather_visuals()
	var storm_forecast_became_due := day_period == DayPeriod.MORNING and previous_day < next_storm_day and day_count >= next_storm_day and weather_phase == WeatherPhase.AFTER
	_record_world_event("time_advanced", {"cause": cause, "day": day_count, "period": day_period})
	var sailmaker_awning_completed := false
	if day_period == DayPeriod.MORNING:
		sailmaker_awning_completed = _raise_sailmaker_awning()
	var repaired_part := _complete_resident_repair()
	var resident_gather_started := _begin_resident_daily_gather() if day_period == DayPeriod.MORNING else false
	var jade_industry_gather_started := _begin_jade_sail_industry_daily_gather() if day_period == DayPeriod.MORNING else false
	_update_traveler_schedule()
	_update_sailmaker_schedule()
	return {
		"resident_prepared_meal": resident_prepared_meal,
		"sailmaker_awning_completed": sailmaker_awning_completed,
		"repaired_part": repaired_part,
		"resident_gather_started": resident_gather_started,
		"jade_industry_gather_started": jade_industry_gather_started,
		"storm_forecast_became_due": storm_forecast_became_due,
	}


func _append_period_outcomes(advancement: Dictionary) -> void:
	var repaired_part := str(advancement.get("repaired_part", ""))
	if not repaired_part.is_empty():
		message += "\n守潮人用储物箱里的木料修好了%s。" % repaired_part
	if bool(advancement.get("resident_prepared_meal", false)):
		message += "\n守潮人守着火候煮好了潮滩鲜贝汤，留了一碗给你。"
	if bool(advancement.get("sailmaker_awning_completed", false)):
		message += "\n清晨，缝帆人把自带的旧帆边缝成棚口的小雨檐；她说这挡不了大风，却能让进出的人少淋一阵。"
	if bool(advancement.get("resident_gather_started", false)):
		message += "\n守潮人看见仙舟泊在可步行抵达的岸边，自动去收集附近现存的%s；她会把东西带回船上，不会阻止你启航。" % ("漂木" if resident_gather_resource == "wood" else "潮池鲜贝")
	if bool(advancement.get("jade_industry_gather_started", false)):
		message += "\n阮青漪带着货篓离开琼华舫，去采集最近一处尚未被取走的潮池鲜贝；这趟营生只影响琼华舫自己的货舱。"
	if bool(advancement.get("storm_forecast_became_due", false)):
		message += "\n海面风向又变了：第二场风雨的预报已经抵达。它不会强迫你停下行程；查看仙舟状况后，按 R 可等它来临。"


func _storm_forecast_due() -> bool:
	return weather_phase == WeatherPhase.AFTER and resolved_storm_count > 0 and next_storm_day > 0 and day_count >= next_storm_day


func _complete_resident_cooking() -> bool:
	if not traveler_boarded or day_period != DayPeriod.EVENING or raw_shellfish < 1 or traveler_action != "准备潮滩晚饭":
		return false
	if traveler_marker == null or not is_instance_valid(traveler_marker) or traveler_marker.position.distance_to(traveler_target_position) > 0.12:
		return false
	raw_shellfish -= 1
	stew_servings += 1
	_record_world_event("resident_meal_prepared", {"resident_id": "tidekeeper", "meal_id": "tidal_shellfish_stew", "day": day_count, "raw_shellfish_spent": 1, "servings_added": 1, "tool_id": "pressure_galley" if pressure_galley_built else "hearth_pot"})
	return true


func _choose_resident_repair(accept: bool) -> void:
	if not resident_repair_choice_pending:
		return
	resident_repair_choice_pending = false
	if not accept:
		_record_world_event("resident_repair_declined", {"resident_id": "tidekeeper", "stored_wood_preserved": stored_wood})
		message = "守潮人点点头：‘好，木料先留在箱里。等你决定再说。’"
	elif not traveler_boarded or stored_wood < 1:
		message = "守潮人没有动手；现在没有足够的储备木料可用。"
	elif not raft_edge_damaged and not shelter_roof_damaged:
		message = "守潮人查看后发现损伤已经处理好了，没有动用储备。"
	else:
		resident_repair_part = "raft_edge" if raft_edge_damaged else "shelter_roof"
		stored_wood -= 1
		resident_repair_pending = true
		_record_world_event("resident_repair_started", {"resident_id": "tidekeeper", "part": resident_repair_part, "wood_spent": 1, "source": "storage"})
		_update_traveler_schedule()
		_update_sailmaker_schedule()
		message = "守潮人从箱里取出一块木料，提着木楔走向%s。她要花些时间把它修牢。" % ("筏舷" if resident_repair_part == "raft_edge" else "棚顶")
	_save_progress()
	_update_hud()


func _complete_resident_repair() -> String:
	if not resident_repair_pending or traveler_marker == null or not is_instance_valid(traveler_marker):
		return ""
	if traveler_marker.position.distance_to(traveler_target_position) > 0.12:
		return ""
	var repaired_part := "筏舷" if resident_repair_part == "raft_edge" else "棚顶"
	if resident_repair_part == "raft_edge" and raft_edge_damaged:
		raft_edge_damaged = false
		var mark := _ark_node("RaftDamageMark")
		if mark:
			mark.queue_free()
	elif resident_repair_part == "shelter_roof" and shelter_roof_damaged:
		shelter_roof_damaged = false
		var roof := _ark_node("BuiltShelter/Roof") as Node3D
		if roof:
			roof.visible = true
	else:
		stored_wood += 1
		_record_world_event("resident_repair_cancelled", {"resident_id": "tidekeeper", "part": resident_repair_part, "wood_refunded": 1, "reason": "damage_already_resolved"})
		resident_repair_pending = false
		resident_repair_part = ""
		return ""
	resident_repair_pending = false
	resident_repair_part = ""
	_record_world_event("resident_repair_completed", {"resident_id": "tidekeeper", "part": repaired_part, "wood_spent": 1})
	return repaired_part


func _reflect_on_last_storm() -> bool:
	if last_resolved_storm_facts.is_empty():
		return false
	var storm_number := int(last_resolved_storm_facts.get("storm_number", 0))
	if storm_number <= tidekeeper_last_storm_reflection:
		return false
	tidekeeper_last_storm_reflection = storm_number
	var prepared_target := str(last_resolved_storm_facts.get("rope_use", "none"))
	var shelter_damaged := bool(last_resolved_storm_facts.get("shelter_damaged", false))
	var raft_damaged := bool(last_resolved_storm_facts.get("raft_damaged", false))
	var preparation_line := "你把绳留在手边，没有把选择交给运气。" if prepared_target == "none" else "你把那条绳先留给棚顶。" if prepared_target == "shelter" else "你把那条绳先留给筏舷。"
	var aftermath_line := "那一夜，棚顶和筏舷都守住了。" if not shelter_damaged and not raft_damaged else "棚顶和筏舷都留下了需要修补的地方。" if shelter_damaged and raft_damaged else "棚顶被掀开了，得重新缝牢。" if shelter_damaged else "筏舷裂了一道口子，不过船没有散。"
	message = "守潮人望着棚檐下的雨痕，轻声说：‘%s%s我记得那晚你做的决定；如今能坐在灯下慢慢修，已经很好。’" % [preparation_line, aftermath_line]
	_record_world_event("resident_storm_reflection", {
		"resident_id": "tidekeeper",
		"storm_number": storm_number,
		"rope_use": prepared_target,
		"shelter_damaged": shelter_damaged,
		"raft_damaged": raft_damaged,
	})
	return true


func _interact_storage() -> void:
	if not storage_built:
		message = "还没有可以防潮的储物箱。"
	elif wood > 0:
		stored_wood += wood
		message = "你把 %d 块木料收进储物箱，给下一次扩建留了余量。" % wood
		wood = 0
	elif stored_wood > 0:
		wood = stored_wood
		message = "你从储物箱取出 %d 块木料，准备带去建造或修补。" % stored_wood
		stored_wood = 0
	else:
		message = "储物箱里空空的。沿着礁脊还能找到些漂木。"
	_save_progress()
	_update_hud()


func _interact_workbench() -> void:
	if not workbench_built:
		message = "还没有能处理灵枢的工作台。"
	elif not lantern_tuned and ancient_parts > 0:
		ancient_parts -= 1
		lantern_tuned = true
		_record_world_event("lantern_tuned", {"relic_spent": 1, "previous_refuge_radius": ARK_REFUGE_RADIUS, "home_refuge_radius": TUNED_LANTERN_REFUGE_RADIUS})
		message = "你把古旧灵枢嵌入灯芯，阵纹沿着木筏的绳结逐段亮起。仙舟庇护圈从 8 米扩展到 15 米，归舟的暖意也能陪你走得更远。"
	elif not tide_compass_tuned and tide_relay_cores > 0 and _has_blueprint("tide_compass"):
		tide_relay_cores -= 1
		tide_compass_tuned = true
		_record_world_event("tide_compass_tuned", {"relay_core_spent": 1, "previous_sail_speed": BASE_SAIL_SPEED, "sail_speed": TUNED_SAIL_SPEED})
		message = "你把旧潮枢嵌入舵盘，细密刻度沿木纹亮起。仙舟航速从 %.1f 提升到 %.1f；新海域仍由你亲自掌舵、停泊与探索。" % [BASE_SAIL_SPEED, TUNED_SAIL_SPEED]
	elif _has_blueprint("pressure_galley") and not pressure_galley_built:
		if not shelter_built:
			message = "蒸汽饭釜要安在有遮蔽的家里；先搭起避风棚，给炉管留出安全位置。"
		elif pressure_cores < 1 or wood < PRESSURE_GALLEY_WOOD_COST:
			message = "蒸汽饭釜图样已经学会，还需要 1 枚压力炉核心与 %d 块木料；核心可在蒸潮机坞寻得。" % PRESSURE_GALLEY_WOOD_COST
		else:
			pressure_galley_choice_pending = true
			message = "你可以把压力炉核心嵌进火盆旁的饭釜架。投入 %d 块木料后，蒸汽饭釜会真正落在家里；热汤更能驱寒。\n1 安装饭釜　　2 暂缓" % PRESSURE_GALLEY_WOOD_COST
	elif not lantern_tuned:
		message = "旧灯阵还缺一枚完整灵枢。风蚀遗迹的石槽里，也许留着能对上的旧物。"
	elif not tide_compass_tuned and not _has_blueprint("tide_compass"):
		message = "阵灯已稳定运转。若要改造舵盘，还需要一张真正见过潮汐旧讯台的罗盘图样。"
	elif not tide_compass_tuned:
		message = "潮汐罗盘图样已经学会，还缺一枚旧潮枢；月背泊地的观测台仍有残存信号。"
	else:
		message = "旧灯阵与潮汐罗盘都已调校完成。庇护随舟同行，舵盘也能更快回应风浪。"
	_save_progress()
	_update_hud()


func _build_pressure_galley() -> void:
	if not pressure_galley_choice_pending:
		return
	pressure_galley_choice_pending = false
	if pressure_galley_built or not _has_blueprint("pressure_galley") or not shelter_built or pressure_cores < 1 or wood < PRESSURE_GALLEY_WOOD_COST:
		message = "饭釜安装条件已经变化，图样与材料仍保留；等家和材料都准备好后再来。"
	else:
		pressure_cores -= 1
		wood -= PRESSURE_GALLEY_WOOD_COST
		pressure_galley_built = true
		var shelter := _ark_node("BuiltShelter") as Node3D
		if shelter:
			var old_pot := shelter.get_node_or_null("HearthPot")
			if old_pot:
				shelter.remove_child(old_pot)
				old_pot.queue_free()
			_add_pressure_galley_visual(shelter)
		var hearth_marker := _ark_node("HearthInteractable") as Node3D
		var hearth_sign := hearth_marker.get_node_or_null("Name") as Label3D if hearth_marker else null
		if hearth_sign:
			hearth_sign.text = "蒸汽饭釜 · E 煮鲜贝汤"
		_record_world_event("pressure_galley_built", {"blueprint_id": "pressure_galley", "pressure_cores_spent": 1, "wood_spent": PRESSURE_GALLEY_WOOD_COST, "meal_warmth_levels": 2})
		message = "你把压力炉核心稳稳装进饭釜，铜管沿棚柱贴墙排开。蒸汽没有冒进屋顶，只在锅沿凝成细小水珠；以后分享热汤，可以多驱散一级寒意。"
	_save_progress()
	_update_hud()


func _day_period_label() -> String:
	var labels: Array[String] = ["清晨", "白日", "傍晚", "夜里"]
	return labels[day_period]


func _choose_weather_preparation(target: String) -> void:
	if not preparation_choice_pending:
		return
	preparation_choice_pending = false
	if target == "shelter" and shelter_built:
		rope_use = "shelter"
		rope_available = false
		_record_world_event("storm_prepared", {"target": rope_use, "rope_available_after": rope_available})
		message = "你把唯一一条好绳绕过棚架和帆布，反复拉紧。筏舷只能听天由命了。"
	elif target == "raft":
		rope_use = "raft"
		rope_available = false
		_record_world_event("storm_prepared", {"target": rope_use, "rope_available_after": rope_available})
		message = "你用绳把松动的筏舷重新束紧。棚顶没有加固，风大时可能会被掀开。"
	else:
		rope_use = "none"
		_record_world_event("storm_prepared", {"target": rope_use, "rope_available_after": rope_available})
		message = "你把绳留在手边。也许之后会用得上，但棚架和筏舷都没有额外加固。"
	_save_progress()
	_update_hud()


func _advance_weather() -> void:
	if weather_phase == WeatherPhase.FORECAST:
		preparation_choice_pending = false
		weather_phase = WeatherPhase.STORM
		var storm_start_exposed := not _is_within_ark_refuge()
		var start_exposure_level := _effective_cold_exposure_level()
		if storm_start_exposed:
			start_exposure_level = _raise_cold_exposure("storm_arrival")
		_record_world_event("storm_started", {"storm_number": resolved_storm_count + 1, "day": day_count, "rope_use": rope_use, "shelter_built": shelter_built, "player_exposed": storm_start_exposed, "cold_exposure_level": start_exposure_level})
		if storm_start_exposed:
			_record_world_event("storm_exposure", {"phase": "arrival", "distance_to_ark": snappedf(_distance_to_ark(), 0.1), "refuge_radius": _current_refuge_radius(), "cold_exposure": true, "cold_exposure_level": start_exposure_level})
		_set_weather_visuals()
		_update_traveler_schedule()
		_update_sailmaker_schedule()
		message = "云墙压过礁岛，风雨抵岸。你仍可在岛上行动；圈外的寒意会随着暴露加深，可回仙舟或找棚下恢复。等风势稍缓后再按 R。"
	elif weather_phase == WeatherPhase.AFTER and _storm_forecast_due():
		weather_phase = WeatherPhase.STORM
		var storm_start_exposed := not _is_within_ark_refuge()
		var start_exposure_level := _effective_cold_exposure_level()
		if storm_start_exposed:
			start_exposure_level = _raise_cold_exposure("storm_arrival")
		_record_world_event("storm_started", {"storm_number": resolved_storm_count + 1, "day": day_count, "rope_use": rope_use, "shelter_built": shelter_built, "repeat_storm": true, "player_exposed": storm_start_exposed, "cold_exposure_level": start_exposure_level})
		if storm_start_exposed:
			_record_world_event("storm_exposure", {"phase": "arrival", "distance_to_ark": snappedf(_distance_to_ark(), 0.1), "refuge_radius": _current_refuge_radius(), "cold_exposure": true, "cold_exposure_level": start_exposure_level})
		_set_weather_visuals()
		_update_traveler_schedule()
		_update_sailmaker_schedule()
		message = "第二场风雨按预报抵岸。你当初固定的绳结仍留在原处；未加固的结构仍要留心。圈外寒意会继续加深；等风势稍缓后再按 R。"
	elif weather_phase == WeatherPhase.STORM:
		weather_phase = WeatherPhase.AFTER
		resolved_storm_count += 1
		next_storm_day = day_count + (2 if resolved_storm_count == 1 else 3)
		_apply_storm_damage()
		var storm_exposure := not _is_within_ark_refuge()
		var resolved_exposure_level := _effective_cold_exposure_level()
		if storm_exposure:
			resolved_exposure_level = _raise_cold_exposure("storm_persists")
			_record_world_event("storm_exposure", {"phase": "storm_end", "distance_to_ark": snappedf(_distance_to_ark(), 0.1), "refuge_radius": _current_refuge_radius(), "cold_exposure": true, "cold_exposure_level": resolved_exposure_level})
		last_resolved_storm_facts = {
			"storm_number": resolved_storm_count,
			"day": day_count,
			"rope_use": rope_use,
			"shelter_damaged": shelter_roof_damaged,
			"shelter_roof_protected_by_reef_brace": shelter_built and reef_shell_brace_installed,
			"raft_damaged": raft_edge_damaged,
			"player_exposed": storm_exposure,
			"cold_exposure_level": resolved_exposure_level,
		}
		_record_world_event("storm_resolved", last_resolved_storm_facts.duplicate(true))
		_set_weather_visuals()
		_update_traveler_schedule()
		_update_sailmaker_schedule()
		if storm_exposure:
			message = "风雨里你离仙舟太远，受寒加深至 %d/3。你仍可继续探索，但步速更慢；回到船边或棚下休整可以恢复。" % resolved_exposure_level
		elif shelter_built and not shelter_roof_damaged and not raft_edge_damaged:
			message = "雨停了。棚顶和筏舷都安然无恙，守潮人把灯芯拨亮，浅滩第一次显得像能住人的地方。"
		else:
			message = "雨停后，松脱的木料拍在筏边。损伤没有毁掉木筏；先看看哪里需要修补。"
	else:
		message = "风雨已经过去。天色仍阴，但远处云层正在散开。" if not _storm_forecast_due() else "风雨预报已到。你可先修理、补给或继续探索；准备好后按 R 迎接下一阵风雨。"
	_save_progress()
	_update_hud()


func _apply_storm_damage() -> void:
	if rope_use != "raft":
		raft_edge_damaged = true
	if shelter_built and rope_use != "shelter" and not reef_shell_brace_installed:
		shelter_roof_damaged = true
	if raft_edge_damaged and _ark_node("RaftDamageMark") == null:
		_add_box("RaftDamageMark", Vector3(0, 0.45, -2.18), Vector3(0.9, 0.12, 0.2), Color("574338"), false, ark_root)
	if shelter_built:
		var roof := _ark_node("BuiltShelter/Roof") as Node3D
		if roof:
			roof.visible = not shelter_roof_damaged


func _cancel_resident_repair_if_player_repairs(part: String) -> void:
	var repaired_part := "raft_edge" if part == "raft" else "shelter_roof"
	if not resident_repair_pending or resident_repair_part != repaired_part:
		return
	resident_repair_pending = false
	resident_repair_part = ""
	stored_wood += 1
	_record_world_event("resident_repair_cancelled", {"resident_id": "tidekeeper", "part": repaired_part, "wood_refunded": 1, "reason": "player_repaired"})


func _repair_damaged_part(part: String) -> void:
	if not repair_choice_pending:
		return
	repair_choice_pending = false
	if wood < 1:
		message = "木料不够，先沿岸再找一块能用的板。"
	elif part == "shelter" and shelter_roof_damaged:
		wood -= 1
		shelter_roof_damaged = false
		_cancel_resident_repair_if_player_repairs("shelter")
		_record_world_event("structure_repaired", {"part": part, "wood_spent": 1})
		var roof := _ark_node("BuiltShelter/Roof") as Node3D
		if roof:
			roof.visible = true
		message = "你用一块木料补回棚顶。屋里重新有了不漏雨的干燥角落。"
	elif part == "raft" and raft_edge_damaged:
		wood -= 1
		raft_edge_damaged = false
		_cancel_resident_repair_if_player_repairs("raft")
		_record_world_event("structure_repaired", {"part": part, "wood_spent": 1})
		var mark := _ark_node("RaftDamageMark")
		if mark:
			mark.queue_free()
		message = "你把筏舷重新钉牢，木筏恢复了远行的条件。"
	else:
		message = "这处暂时没有需要修的地方。"
	_update_traveler_schedule()
	_update_sailmaker_schedule()
	_save_progress()
	_update_hud()


func _choose_traveler_boarding(accept: bool) -> void:
	if not traveler_choice_pending:
		return
	traveler_choice_pending = false
	if accept and shelter_built:
		if not _can_board_resident("tidekeeper"):
			_record_world_event("resident_boarding_deferred", {"resident_id": "tidekeeper", "reason": "berth_capacity", "occupancy": _resident_occupancy(), "capacity": _resident_capacity()})
			message = "你愿意邀请她，但眼下没有空余泊位。守潮人理解地点有限，先留在岸边；扩建后仍可再谈。"
		else:
			traveler_boarded = true
			_set_traveler_boarded()
			_record_world_event("resident_invitation_decided", {"resident_id": "tidekeeper", "accepted": true})
			message = "你把棚边让出一块干燥地方，没有替对方许下长期同行的承诺。守潮人自己把浮标箱搬上筏，答应先共度这一夜。"
	else:
		_record_world_event("resident_invitation_decided", {"resident_id": "tidekeeper", "accepted": false})
		message = "你没有催促。守潮人留在岸边看守浮标箱，并在礁石上系了一段浅色布条，标出安全潮沟。明早仍可再来商量。"
		if not safe_channel_marked:
			safe_channel_marked = true
			_add_safe_channel_mark()
	_save_progress()
	_update_hud()


func _choose_sailmaker_boarding(accept: bool) -> void:
	if not sailmaker_choice_pending:
		return
	sailmaker_choice_pending = false
	if accept and shelter_built:
		if not _can_board_resident("sailmaker"):
			_record_world_event("resident_boarding_deferred", {"resident_id": "sailmaker", "reason": "berth_capacity", "occupancy": _resident_occupancy(), "capacity": _resident_capacity()})
			message = "你愿意邀请她，但眼下没有空余泊位。缝帆人不勉强同行；扩建后仍可再谈。"
		else:
			sailmaker_boarded = true
			sailmaker_joined_day = day_count
			_set_sailmaker_boarded()
			_record_world_event("resident_invitation_decided", {"resident_id": "sailmaker", "accepted": true})
			message = "缝帆人把针线和那卷旧帆布收进小包，自己踏上木筏：‘先同行一程。以后住不住下，再看风往哪边吹。’"
	else:
		_record_world_event("resident_invitation_decided", {"resident_id": "sailmaker", "accepted": false})
		message = "你尊重她暂不同行的决定。她把旧帆重新铺回礁石上；想再谈时，仍可以来找她。"
	_save_progress()
	_update_hud()


func _set_traveler_boarded() -> void:
	for entry in interactables:
		if str(entry.get("id", "")) != "resident":
			continue
		var marker: Node3D = entry.get("node")
		if marker and is_instance_valid(marker):
			if marker.get_parent() != ark_root:
				marker.reparent(ark_root, false)
			traveler_marker = marker
			marker.position = RESIDENT_DECK_POSITION
			if resident_gather_pending:
				marker.reparent(self, true)
			_set_tidekeeper_box_aboard()
			_update_traveler_schedule()
			_update_sailmaker_schedule()
		return


func _set_tidekeeper_box_aboard() -> void:
	if tidekeeper_box_marker == null or not is_instance_valid(tidekeeper_box_marker) or ark_root == null:
		return
	if tidekeeper_box_marker.get_parent() != ark_root:
		tidekeeper_box_marker.reparent(ark_root, false)
	tidekeeper_box_marker.position = TIDEKEEPER_BOX_ARK_POSITION


func _set_sailmaker_boarded() -> void:
	for entry in interactables:
		if str(entry.get("id", "")) != "sailmaker":
			continue
		var marker: Node3D = entry.get("node")
		if marker and is_instance_valid(marker):
			if marker.get_parent() != ark_root:
				marker.reparent(ark_root, false)
			sailmaker_marker = marker
			marker.position = Vector3(1.15, 0.12, 0.75)
			_update_sailmaker_schedule()
		return


func _resident_capacity() -> int:
	if not shelter_built:
		return 0
	return 2 + (1 if raft_extension_built else 0) + (1 if guest_cabin_built and raft_extension_built else 0)


func _resident_occupancy() -> int:
	return int(traveler_boarded) + int(sailmaker_boarded)


func _can_board_resident(resident_id: String) -> bool:
	if resident_id == "tidekeeper" and traveler_boarded:
		return true
	if resident_id == "sailmaker" and sailmaker_boarded:
		return true
	return shelter_built and _resident_occupancy() < _resident_capacity()


func _begin_resident_daily_gather() -> bool:
	if not traveler_boarded or resident_gather_pending or resident_repair_pending or sailing_mode or day_period != DayPeriod.MORNING:
		return false
	if day_count <= resident_gather_last_day or weather_phase != WeatherPhase.AFTER:
		return false
	var target_entry: Dictionary = {}
	var best_distance := RESIDENT_AUTO_GATHER_RADIUS + 0.001
	var best_priority := 99
	for entry in interactables:
		var resource_id := str(entry.get("id", ""))
		if not ["wood", "shellfish"].has(resource_id):
			continue
		var node := entry.get("node") as Node3D
		var item_id := str(entry.get("item_id", ""))
		if node == null or not is_instance_valid(node) or item_id.is_empty() or collected_ids.has(item_id):
			continue
		var distance := ark_root.global_position.distance_to(node.global_position)
		if distance > RESIDENT_AUTO_GATHER_RADIUS:
			continue
		var priority := 0
		if resident_gather_policy != "balanced":
			priority = 0 if (resident_gather_policy == "shellfish_first" and resource_id == "shellfish") or (resident_gather_policy == "wood_first" and resource_id == "wood") else 1
		if priority < best_priority or (priority == best_priority and distance < best_distance):
			best_priority = priority
			best_distance = distance
			target_entry = entry
	if target_entry.is_empty():
		return false
	var target_node := target_entry.get("node") as Node3D
	resident_gather_pending = true
	resident_gather_phase = "outbound"
	traveler_routine_route.clear()
	traveler_routine_route_index = 0
	traveler_routine_route_target_set = false
	resident_gather_target_id = str(target_entry.get("item_id", ""))
	resident_gather_resource = str(target_entry.get("id", ""))
	resident_gather_target_position = target_node.global_position
	resident_gather_route.clear()
	resident_gather_route_index = 0
	resident_gather_payload = 0
	resident_gather_pickup_remaining = RESIDENT_AUTO_GATHER_PICKUP_SECONDS
	resident_gather_last_day = day_count
	if traveler_marker.get_parent() != self:
		traveler_marker.reparent(self, true)
	traveler_action = "近岸采集"
	var sign := traveler_marker.get_node_or_null("Name") as Label3D
	if sign:
		sign.text = "守潮人 · 近岸采集"
	_record_world_event("resident_gather_started", {"resident_id": "tidekeeper", "resource": resident_gather_resource, "target_id": resident_gather_target_id, "day": day_count, "policy": resident_gather_policy, "target_position": _position_facts(resident_gather_target_position)})
	_save_progress()
	return true


func _choose_resident_gather_policy(policy: String) -> void:
	if not resident_gather_policy_choice_pending:
		return
	resident_gather_policy_choice_pending = false
	if not ["wood_first", "shellfish_first", "balanced"].has(policy):
		message = "守潮人没有听懂这个方针；她先按原有安排做事。"
		_update_hud()
		return
	var previous_policy := resident_gather_policy
	resident_gather_policy = policy
	if previous_policy != policy:
		_record_world_event("resident_gather_policy_set", {"resident_id": "tidekeeper", "previous_policy": previous_policy, "policy": policy, "applies_to": "next_shift"})
	message = "你们约好%s。守潮人会自己挑选附近真实存在的物资；已经开始的这趟行程不会被临时改掉。" % _resident_gather_policy_label()
	_save_progress()
	_update_hud()
	_update_interaction_hint()


func _resident_gather_policy_label() -> String:
	match resident_gather_policy:
		"wood_first": return "木料优先"
		"shellfish_first": return "鲜贝优先"
		_: return "就近均衡"


func _process_resident_gathering(delta: float) -> bool:
	if not resident_gather_pending or traveler_marker == null or not is_instance_valid(traveler_marker):
		return false
	if weather_phase == WeatherPhase.STORM:
		_abort_resident_gathering("storm_arrival")
		return false
	var target_position := resident_gather_target_position
	if resident_gather_phase == "returning":
		target_position = ark_root.to_global(RESIDENT_DECK_POSITION)
	if resident_gather_route.is_empty():
		resident_gather_route = _build_resident_walk_route(traveler_marker.global_position, target_position)
		resident_gather_route_index = 1 if resident_gather_route.size() > 1 else 0
		if resident_gather_route.is_empty():
			_abort_resident_gathering("no_safe_route")
			return false
	while resident_gather_route_index < resident_gather_route.size():
		var waypoint := resident_gather_route[resident_gather_route_index]
		if waypoint.distance_to(traveler_marker.global_position) > 0.22:
			break
		resident_gather_route_index += 1
	var moving := resident_gather_route_index < resident_gather_route.size()
	if moving:
		var movement_target := resident_gather_route[resident_gather_route_index]
		traveler_marker.global_position = traveler_marker.global_position.move_toward(movement_target, maxf(0.0, delta) * RESIDENT_AUTO_GATHER_SPEED)
		var offset := movement_target - traveler_marker.global_position
		offset.y = 0.0
		var direction := Vector3(offset.x, 0.0, offset.z).normalized()
		traveler_marker.rotation.y = atan2(-direction.x, -direction.z)
	if resident_gather_phase == "outbound" and not moving:
		resident_gather_phase = "collecting"
		resident_gather_pickup_remaining = RESIDENT_AUTO_GATHER_PICKUP_SECONDS
		traveler_action = "拾取" + ("漂木" if resident_gather_resource == "wood" else "鲜贝")
		_update_gatherer_nameplate()
		_save_progress()
	elif resident_gather_phase == "collecting":
		resident_gather_pickup_remaining -= maxf(0.0, delta)
		if resident_gather_pickup_remaining <= 0.0:
			_harvest_resident_gather_target()
	elif resident_gather_phase == "returning" and not moving:
		_finish_resident_gathering("ark_return")
	return moving


func _build_resident_walk_route(start: Vector3, destination: Vector3) -> PackedVector3Array:
	var route := PackedVector3Array()
	var minimum := Vector2(minf(start.x, destination.x), minf(start.z, destination.z)) - Vector2.ONE * RESIDENT_ROUTE_MARGIN
	var maximum := Vector2(maxf(start.x, destination.x), maxf(start.z, destination.z)) + Vector2.ONE * RESIDENT_ROUTE_MARGIN
	var grid_size := Vector2i(ceili((maximum.x - minimum.x) / RESIDENT_ROUTE_CELL_SIZE) + 1, ceili((maximum.y - minimum.y) / RESIDENT_ROUTE_CELL_SIZE) + 1)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, grid_size)
	grid.cell_size = Vector2.ONE * RESIDENT_ROUTE_CELL_SIZE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for cell_z in range(grid_size.y):
		for cell_x in range(grid_size.x):
			var cell := Vector2i(cell_x, cell_z)
			var world := minimum + Vector2(cell_x, cell_z) * RESIDENT_ROUTE_CELL_SIZE
			if _resident_route_cell_blocked(world):
				grid.set_point_solid(cell, true)
	var start_cell := _resident_route_cell(start, minimum, grid_size)
	var end_cell := _resident_route_cell(destination, minimum, grid_size)
	if not grid.is_in_boundsv(start_cell) or not grid.is_in_boundsv(end_cell):
		return route
	grid.set_point_solid(start_cell, false)
	grid.set_point_solid(end_cell, false)
	var cell_path := grid.get_id_path(start_cell, end_cell)
	if cell_path.is_empty():
		return route
	route.append(start)
	for index in range(1, cell_path.size() - 1):
		var cell: Vector2i = cell_path[index]
		var waypoint_x := minimum.x + float(cell.x) * RESIDENT_ROUTE_CELL_SIZE
		var waypoint_z := minimum.y + float(cell.y) * RESIDENT_ROUTE_CELL_SIZE
		var waypoint_position := Vector2(waypoint_x, waypoint_z)
		route.append(Vector3(waypoint_x, _resident_route_surface_y(waypoint_position, start.y), waypoint_z))
	if start.distance_to(destination) > 0.22:
		route.append(destination)
	return route


func _resident_route_cell(position: Vector3, minimum: Vector2, grid_size: Vector2i) -> Vector2i:
	var cell := Vector2i(roundi((position.x - minimum.x) / RESIDENT_ROUTE_CELL_SIZE), roundi((position.z - minimum.y) / RESIDENT_ROUTE_CELL_SIZE))
	return Vector2i(clampi(cell.x, 0, grid_size.x - 1), clampi(cell.y, 0, grid_size.y - 1))


func _resident_route_cell_blocked(position: Vector2) -> bool:
	if get_world_3d() == null:
		return false
	var origin := Vector3(position.x, 4.0, position.y)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 7.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	return hit_position.y > RESIDENT_ROUTE_BLOCKER_HEIGHT


func _resident_route_surface_y(position: Vector2, fallback_y: float) -> float:
	if get_world_3d() == null:
		return fallback_y
	var origin := Vector3(position.x, 4.0, position.y)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 7.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return fallback_y
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	var surface_y := hit_position.y
	if surface_y <= WATER_SURFACE_Y:
		return fallback_y
	return surface_y + RESIDENT_ROUTE_SURFACE_OFFSET


func _harvest_resident_gather_target() -> void:
	if not resident_gather_pending or resident_gather_phase != "collecting":
		return
	for index in range(interactables.size()):
		var entry: Dictionary = interactables[index]
		if str(entry.get("item_id", "")) != resident_gather_target_id or str(entry.get("id", "")) != resident_gather_resource:
			continue
		var node := entry.get("node") as Node3D
		if node == null or not is_instance_valid(node) or collected_ids.has(resident_gather_target_id):
			break
		var amount := maxi(0, int(entry.get("amount", 0)))
		interactables.remove_at(index)
		collected_ids.append(resident_gather_target_id)
		node.queue_free()
		resident_gather_payload = amount
		resident_gather_phase = "returning"
		resident_gather_route.clear()
		resident_gather_route_index = 0
		traveler_action = "带回物资"
		_record_world_event("resource_collected", {"node_id": resident_gather_target_id, "resource": resident_gather_resource, "amount": amount, "collector": "resident", "resident_id": "tidekeeper"})
		_record_world_event("resident_gather_harvested", {"resident_id": "tidekeeper", "target_id": resident_gather_target_id, "resource": resident_gather_resource, "amount": amount})
		_update_gatherer_nameplate()
		_save_progress()
		_update_hud()
		return
	_abort_resident_gathering("resource_taken_before_arrival")


func _finish_resident_gathering(delivery_mode: String) -> void:
	if not resident_gather_pending:
		return
	if traveler_marker != null and is_instance_valid(traveler_marker):
		if traveler_marker.get_parent() != ark_root:
			traveler_marker.reparent(ark_root, true)
		traveler_marker.position = RESIDENT_DECK_POSITION
	var resource_id := resident_gather_resource
	var target_id := resident_gather_target_id
	var amount := resident_gather_payload
	resident_gather_pending = false
	resident_gather_phase = ""
	resident_gather_target_id = ""
	resident_gather_resource = ""
	resident_gather_payload = 0
	resident_gather_pickup_remaining = 0.0
	resident_gather_route.clear()
	resident_gather_route_index = 0
	if amount > 0:
		var delivery_destination := "food_storage"
		if resource_id == "wood":
			if storage_built:
				stored_wood += amount
				delivery_destination = "ark_storage"
			else:
				wood += amount
				delivery_destination = "available_supplies"
		else:
			raw_shellfish += amount
		_record_world_event("resident_gather_delivered", {"resident_id": "tidekeeper", "target_id": target_id, "resource": resource_id, "amount": amount, "delivery_mode": delivery_mode, "destination": delivery_destination})
		var destination_label := "可用木料堆" if delivery_destination == "available_supplies" else "防潮储物箱" if delivery_destination == "ark_storage" else "食材箱"
		message = "守潮人把%s带回仙舟，放进%s。" % ["漂木" if resource_id == "wood" else "潮池鲜贝", destination_label]
	else:
		_record_world_event("resident_gather_cancelled", {"resident_id": "tidekeeper", "target_id": target_id, "reason": delivery_mode})
		message = "守潮人回来时，发现采集点已被取走；她没有重复记账，也没有带回物资。"
	_update_traveler_schedule()
	_save_progress()
	_update_hud()


func _abort_resident_gathering(reason: String, update_schedule: bool = true) -> bool:
	if not resident_gather_pending:
		return false
	if resident_gather_payload > 0:
		_finish_resident_gathering(reason)
		return true
	var target_id := resident_gather_target_id
	resident_gather_pending = false
	resident_gather_phase = ""
	resident_gather_target_id = ""
	resident_gather_resource = ""
	resident_gather_payload = 0
	resident_gather_pickup_remaining = 0.0
	resident_gather_route.clear()
	resident_gather_route_index = 0
	if traveler_marker != null and is_instance_valid(traveler_marker):
		if traveler_marker.get_parent() != ark_root:
			traveler_marker.reparent(ark_root, true)
		traveler_marker.position = RESIDENT_DECK_POSITION
	_record_world_event("resident_gather_cancelled", {"resident_id": "tidekeeper", "target_id": target_id, "reason": reason, "resource_preserved": true})
	if update_schedule:
		_update_traveler_schedule()
	_save_progress()
	return true


func _recall_resident_gatherer(reason: String) -> bool:
	return _abort_resident_gathering(reason)


func _update_gatherer_nameplate() -> void:
	if traveler_marker == null or not is_instance_valid(traveler_marker):
		return
	var sign := traveler_marker.get_node_or_null("Name") as Label3D
	if sign:
		sign.text = "守潮人 · %s" % traveler_action


func _update_traveler_schedule() -> void:
	if not traveler_boarded or traveler_marker == null or not is_instance_valid(traveler_marker):
		return
	if resident_gather_pending and weather_phase == WeatherPhase.STORM:
		_abort_resident_gathering("storm_arrival", false)
	if resident_gather_pending:
		traveler_action = "近岸采集" if resident_gather_phase in ["outbound", "collecting"] else "带回物资"
		var gather_sign := traveler_marker.get_node_or_null("Name") as Label3D
		if gather_sign:
			gather_sign.text = "守潮人 · %s" % traveler_action
		return
	if shared_meal_gathering_pending and shared_meal_participants.has("tidekeeper"):
		traveler_action = "把热汤端到桌边"
		traveler_target_position = shelter_position + Vector3(-0.35, 0.12, -0.12)
	elif resident_repair_pending and resident_repair_part == "raft_edge":
		traveler_action = "修补筏舷"
		traveler_target_position = Vector3(0.2, 0.12, -1.55)
	elif resident_repair_pending and resident_repair_part == "shelter_roof":
		traveler_action = "整理棚顶"
		traveler_target_position = Vector3(0.8, 0.12, 1.05)
	elif weather_phase == WeatherPhase.STORM:
		traveler_action = "棚下避雨"
		traveler_target_position = shelter_position + Vector3(0.45, 0.12, -0.25)
	elif weather_phase == WeatherPhase.FORECAST:
		traveler_action = "查看潮势"
		traveler_target_position = Vector3(0.5, 0.12, 1.35)
	elif raft_edge_damaged:
		traveler_action = "查看筏舷"
		traveler_target_position = Vector3(0.2, 0.12, -1.55)
	elif shelter_roof_damaged:
		traveler_action = "整理帆布"
		traveler_target_position = Vector3(0.8, 0.12, 1.05)
	elif day_period == DayPeriod.EVENING and shared_meal_day == day_count:
			traveler_action = "收拾饭后碗盏"
			traveler_target_position = Vector3(-0.35, 0.12, 0.7)
	elif day_period == DayPeriod.EVENING and raw_shellfish > 0 and shelter_built:
			traveler_action = "准备潮滩晚饭"
			traveler_target_position = shelter_position + Vector3(-1.05, 0.12, -0.75)
	elif day_period == DayPeriod.NIGHT and shelter_built:
		if raft_extension_built and _ark_node("BuiltRaftExtension/Berth") != null:
			traveler_action = "甲板铺位歇息"
			traveler_target_position = Vector3(0.95, 0.24, -5.35)
		else:
			traveler_action = "棚下歇息"
			traveler_target_position = shelter_position + Vector3(0.72, 0.12, 0.2)
	elif day_period == DayPeriod.EVENING:
		traveler_action = "照看灯火"
		traveler_target_position = Vector3(0.8, 0.12, -0.35)
	elif day_period == DayPeriod.DAY:
		traveler_action = "整理浮标箱"
		traveler_target_position = Vector3(1.12, 0.12, -0.33)
	else:
		traveler_action = "查看潮势"
		traveler_target_position = Vector3(0.5, 0.12, 1.35)
	var sign := traveler_marker.get_node_or_null("Name") as Label3D
	if sign:
		sign.text = "守潮人 · %s" % traveler_action


func _update_sailmaker_schedule() -> void:
	if not sailmaker_boarded or sailmaker_marker == null or not is_instance_valid(sailmaker_marker):
		return
	if shared_meal_gathering_pending and shared_meal_participants.has("sailmaker"):
		sailmaker_action = "收起针线赴饭"
		sailmaker_target_position = shelter_position + Vector3(0.42, 0.12, -0.12)
	elif weather_phase == WeatherPhase.STORM:
		sailmaker_action = "收拢旧帆"
		sailmaker_target_position = shelter_position + Vector3(-0.55, 0.12, -0.35)
	elif weather_phase == WeatherPhase.FORECAST:
		sailmaker_action = "看云脚收帆"
		sailmaker_target_position = Vector3(1.1, 0.12, 1.25)
	elif raft_edge_damaged or shelter_roof_damaged:
		sailmaker_action = "检查帆缆"
		sailmaker_target_position = Vector3(1.45, 0.12, -1.25)
	elif day_period == DayPeriod.NIGHT and guest_cabin_built and raft_extension_built:
		sailmaker_action = "在听潮客舱歇息"
		sailmaker_target_position = GUEST_CABIN_SAILMAKER_POSITION
	elif day_period == DayPeriod.NIGHT:
		sailmaker_action = "棚下歇息"
		sailmaker_target_position = shelter_position + Vector3(-0.72, 0.12, 0.25)
	elif day_period == DayPeriod.EVENING:
		sailmaker_action = "晾晒补好的帆布"
		sailmaker_target_position = Vector3(1.05, 0.12, -0.95)
	else:
		sailmaker_action = "缝补旧帆"
		sailmaker_target_position = Vector3(1.35, 0.12, -0.75)
	var sign := sailmaker_marker.get_node_or_null("Name") as Label3D
	if sign:
		sign.text = "缝帆人 · %s" % sailmaker_action


func _record_sailmaker_guest_cabin_occupancy() -> void:
	if not sailmaker_boarded or not guest_cabin_built or not raft_extension_built or day_period != DayPeriod.NIGHT:
		return
	if sailmaker_action != "在听潮客舱歇息" or sailmaker_guest_cabin_first_night:
		return
	if sailmaker_marker == null or not is_instance_valid(sailmaker_marker) or sailmaker_marker.position.distance_to(sailmaker_target_position) > 0.08:
		return
	sailmaker_guest_cabin_first_night = true
	_record_world_event("resident_guest_cabin_occupied", {"resident_id": "sailmaker", "room_id": "tide_guest_cabin", "day": day_count, "day_period": "night"})
	message = "夜深后，缝帆人把针线盒收进新客舱，在门边停了片刻。她说：‘以前我只替别人补好船帆；今晚总算有间能把门掩上的屋子。往后若经营客舫，也该先给船员留一间这样的房。’"
	_save_progress()
	_update_hud()


func _is_on_raft_extension_deck(position: Vector3) -> bool:
	return absf(position.x) <= 2.9 and position.z >= -6.3 and position.z <= -2.05


func _evacuate_residents_from_raft_extension() -> void:
	if traveler_boarded and not resident_gather_pending and traveler_marker != null and is_instance_valid(traveler_marker) and _is_on_raft_extension_deck(traveler_marker.position):
		traveler_marker.position = RESIDENT_DECK_POSITION
	if sailmaker_boarded and sailmaker_marker != null and is_instance_valid(sailmaker_marker) and _is_on_raft_extension_deck(sailmaker_marker.position):
		sailmaker_marker.position = Vector3(1.15, 0.12, 0.75)


func _raise_sailmaker_awning() -> bool:
	if not sailmaker_boarded or sailmaker_awning_raised or day_count <= sailmaker_joined_day:
		return false
	sailmaker_awning_raised = true
	_add_sailmaker_awning()
	_record_world_event("resident_sail_awning_raised", {"resident_id": "sailmaker", "day": day_count, "source_material": "personal_sail_scrap", "wood_spent": 0})
	return true


func _add_sailmaker_awning() -> void:
	var structure := _ark_node("BuiltShelter") as Node3D
	if structure == null or structure.get_node_or_null("SailmakerAwning") != null:
		return
	var awning := Node3D.new()
	awning.name = "SailmakerAwning"
	var cloth := MeshInstance3D.new()
	cloth.name = "PatchedCanvas"
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = Vector3(1.7, 0.07, 1.08)
	cloth.mesh = cloth_mesh
	cloth.position = Vector3(0.0, 1.55, -0.72)
	cloth.rotation.x = -0.1
	cloth.material_override = _material(Color("78908a"))
	awning.add_child(cloth)
	for side in [-1.0, 1.0]:
		var support := MeshInstance3D.new()
		var support_mesh := CylinderMesh.new()
		support_mesh.top_radius = 0.025
		support_mesh.bottom_radius = 0.035
		support_mesh.height = 0.76
		support.mesh = support_mesh
		support.position = Vector3(side * 0.72, 1.18, -0.72)
		support.material_override = _material(Color("80664c"))
		awning.add_child(support)
	structure.add_child(awning)
	var marker := Node3D.new()
	marker.name = "SailmakerAwningInteractable"
	marker.position = shelter_position + Vector3(0.0, 1.05, -0.92)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "补好的旧帆 · 棚口雨檐"
	sign.position.y = 0.3
	sign.font_size = 22
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("fff0c9")
	marker.add_child(sign)
	ark_root.add_child(marker)
	interactables.append({"id": "sailmaker_awning", "node": marker, "amount": 0})


func _start_build() -> void:
	if sailing_mode:
		message = "掌舵时不能施工。先离开舵位，让仙舟停稳。"
		_update_hud()
		return
	if building_mode:
		_cancel_build(false)
	if raft_extension_built:
		message = "木筏已经接上远礁龙骨，甲板多出一段可用空间。接下来可继续探索与营造。"
		_update_hud()
		return
	build_type = "shelter" if not shelter_built else "storage" if not storage_built else "workbench" if not workbench_built else "raft_extension"
	if build_type == "raft_extension" and not _has_blueprint("keel_deck_expansion"):
		message = "这种龙骨扩甲需要先学会相应蓝图；远礁沉筏没有等级门槛，探索即可找到方案。"
		_update_hud()
		return
	var required_wood := BUILD_COST if build_type == "shelter" else STORAGE_COST if build_type == "storage" else WORKBENCH_COST if build_type == "workbench" else RAFT_EXTENSION_WOOD_COST
	var building_name := "避风棚" if build_type == "shelter" else "储物箱" if build_type == "storage" else "阵枢工作台" if build_type == "workbench" else "龙骨甲板"
	if wood < required_wood or (build_type == "raft_extension" and keel_beams < RAFT_EXTENSION_KEEL_COST):
		message = "建造%s需要 %d 块木料%s。远礁沉筏或许能找到稀有龙骨。" % [building_name, required_wood, "与 1 根龙骨" if build_type == "raft_extension" else ""]
		_update_hud()
		return
	building_mode = true
	build_preview = MeshInstance3D.new()
	build_preview.name = "%sBuildPreview" % build_type.capitalize()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.0, 0.12, 2.4) if build_type == "shelter" else Vector3(0.95, 0.72, 0.82) if build_type == "storage" else Vector3(1.1, 0.86, 0.78) if build_type == "workbench" else Vector3(5.7, 0.12, 3.8)
	(build_preview as MeshInstance3D).mesh = mesh
	preview_valid_material = _preview_material(Color("a2d18f"))
	preview_invalid_material = _preview_material(Color("d78277"))
	ark_root.add_child(build_preview)
	message = "移动鼠标选择位置；左键确认，右键或 Esc 取消。%s需要 %d 块木料%s。" % [building_name, required_wood, "与 1 根龙骨" if build_type == "raft_extension" else ""]
	_update_build_preview()
	_update_hud()


func _start_starter_home_template() -> void:
	if building_mode:
		_cancel_build(false)
	if shelter_built or storage_built:
		message = "潮棚之家模板需要一块完整空地；已有棚屋或储物箱时，可继续用自由搭建补齐。"
		_update_hud()
		return
	if wood < BUILD_COST + STORAGE_COST:
		message = "潮棚之家模板需要 5 块木料（避风棚 3、储物箱 2）；先从近岸带些漂木回来。"
		_update_hud()
		return
	building_mode = true
	build_type = "starter_home_template"
	build_preview = Node3D.new()
	build_preview.name = "StarterHomeTemplatePreview"
	preview_valid_material = _preview_material(Color("a2d18f"))
	preview_invalid_material = _preview_material(Color("d78277"))
	_add_shelter_template_ghost(build_preview)
	_add_template_ghost_box(build_preview, "Storage", Vector3(0.98, 0.84, 0.86), Vector3(2.0, 0.54, -1.5))
	ark_root.add_child(build_preview)
	message = "潮棚之家模板：绿影处会一并建好棚屋、床铺、灯与储物箱，并保留正面通道；左键确认，右键或 Esc 取消。"
	_update_build_preview()
	_update_hud()


func _start_basic_shelter_template() -> void:
	if building_mode:
		_cancel_build(false)
	if shelter_built:
		message = "基础避风棚已建好；想扩展储物空间，可选择潮棚之家或自由逐件搭建。"
		_update_hud()
		return
	if wood < BUILD_COST:
		message = "基础避风棚模板需要 3 块木料；先从附近收集漂木。"
		_update_hud()
		return
	building_mode = true
	build_type = "shelter"
	build_preview = Node3D.new()
	build_preview.name = "BasicShelterTemplatePreview"
	preview_valid_material = _preview_material(Color("a2d18f"))
	preview_invalid_material = _preview_material(Color("d78277"))
	_add_shelter_template_ghost(build_preview)
	ark_root.add_child(build_preview)
	message = "基础避风棚模板：预览含棚顶、床铺与暖灯；入口朝筏首，左键确认，右键或 Esc 取消。"
	_update_build_preview()
	_update_hud()


func _add_shelter_template_ghost(parent: Node3D) -> void:
	_add_template_ghost_box(parent, "Floor", Vector3(3.0, 0.12, 2.4), Vector3(0, 0.12, 0))
	_add_template_ghost_box(parent, "Back", Vector3(3.0, 2.2, 0.14), Vector3(0, 1.25, -1.12))
	_add_template_ghost_box(parent, "Left", Vector3(0.14, 2.2, 2.2), Vector3(-1.42, 1.25, 0))
	_add_template_ghost_box(parent, "Right", Vector3(0.14, 2.2, 2.2), Vector3(1.42, 1.25, 0))
	_add_template_ghost_box(parent, "Roof", Vector3(3.2, 0.18, 2.6), Vector3(0, 2.38, 0))
	_add_template_ghost_box(parent, "Cot", Vector3(0.92, 0.34, 0.52), Vector3(0.72, 0.38, 0.2))
	_add_template_ghost_box(parent, "WarmLamp", Vector3(0.28, 0.42, 0.28), Vector3(0, 0.43, -0.5))
	_add_template_ghost_box(parent, "HearthStone", Vector3(0.62, 0.18, 0.52), Vector3(-1.05, 0.21, -0.75))
	_add_template_ghost_box(parent, "CookingPot", Vector3(0.38, 0.3, 0.38), Vector3(-1.05, 0.43, -0.75))


func _start_raft_expansion_blueprint() -> void:
	if not _has_blueprint("keel_deck_expansion"):
		message = "这张扩甲蓝图还没有找到。远礁沉筏没有等级门槛；先准备好归途，再去探索即可。"
		_update_hud()
		return
	if raft_extension_built:
		message = "龙骨扩甲已经落成；后续仍可自由扩建甲板和舱室。"
		_update_hud()
		return
	if not workbench_built:
		message = "蓝图已收录。先自由搭好基础家园与阵枢工作台，再来安装龙骨甲板。"
		_update_hud()
		return
	_start_build()


func _start_guest_cabin_template() -> void:
	if sailing_mode:
		message = "航行时不能施工；先停泊并离开舵位，再安置客舱。"
		_update_hud()
		return
	if not _has_blueprint("tide_guest_cabin"):
		message = "听潮客舱图样尚未学会。琼华舫遗址没有等级门槛，沿潮痕图的方向自行探索即可。"
		_update_hud()
		return
	if guest_cabin_built:
		message = "听潮客舱已经建好；这张永久蓝图仍在册，拆下甲板时会取回材料。"
		_update_hud()
		return
	if not raft_extension_built or _ark_node("BuiltRaftExtension") == null:
		message = "客舱要接在龙骨扩甲上；先把远礁龙骨和船板接成一段可居住甲板。"
		_update_hud()
		return
	if guest_cabin_frames < GUEST_CABIN_FRAME_COST or wood < GUEST_CABIN_WOOD_COST:
		message = "听潮客舱需要 %d 块木料与 %d 根琼华舫舱骨；当前木料 %d、舱骨 %d。" % [GUEST_CABIN_WOOD_COST, GUEST_CABIN_FRAME_COST, wood, guest_cabin_frames]
		_update_hud()
		return
	if building_mode:
		_cancel_build(false)
	building_mode = true
	build_type = "guest_cabin_template"
	build_preview = Node3D.new()
	build_preview.name = "GuestCabinTemplatePreview"
	preview_valid_material = _preview_material(Color("a2d18f"))
	preview_invalid_material = _preview_material(Color("d78277"))
	_add_guest_cabin_template_ghost(build_preview)
	ark_root.add_child(build_preview)
	message = "听潮客舱模板会落在龙骨甲板左舷，保留右侧铺位与中央通道；左键确认，右键或 Esc 取消。"
	_update_build_preview()
	_update_hud()


func _add_guest_cabin_template_ghost(parent: Node3D) -> void:
	_add_template_ghost_box(parent, "CabinFloor", Vector3(2.5, 0.13, 2.65), Vector3(-1.3, 0.15, 0.2))
	_add_template_ghost_box(parent, "CabinBack", Vector3(2.42, 1.8, 0.12), Vector3(-1.3, 1.08, -1.05))
	_add_template_ghost_box(parent, "CabinPort", Vector3(0.12, 1.8, 2.42), Vector3(-2.48, 1.08, 0.2))
	_add_template_ghost_box(parent, "CabinCanopy", Vector3(2.62, 0.12, 1.42), Vector3(-1.3, 2.02, -0.43))
	_add_template_ghost_box(parent, "GuestBed", Vector3(0.82, 0.25, 1.45), Vector3(-0.92, 0.4, -0.35))


func _has_blueprint(blueprint_id: String) -> bool:
	return learned_blueprint_ids.has(blueprint_id)


func _learn_blueprint(blueprint_id: String, source_site: String) -> void:
	if _has_blueprint(blueprint_id):
		return
	learned_blueprint_ids.append(blueprint_id)
	_record_world_event("blueprint_discovered", {"blueprint_id": blueprint_id, "source_site": source_site, "permanent_knowledge": true, "requires_keel_beam": blueprint_id == "keel_deck_expansion", "requires_relay_core": blueprint_id == "tide_compass", "requires_guest_cabin_frame": blueprint_id == "tide_guest_cabin"})


func _install_reef_shell_brace() -> void:
	if reef_shell_brace_installed:
		message = "礁壳风撑已经固定在棚顶，不需要重复施工。"
	elif not _has_blueprint("reef_shell_storm_brace"):
		message = "这套风撑结构还没学会；远礁礁背兽留下的甲片与受力纹路会告诉你怎么做。"
	elif not shelter_built or _ark_node("BuiltShelter") == null:
		message = "先搭好避风棚，礁壳风撑需要固定在真实棚架上。"
	elif reef_shell_plates < 1 or wood < REEF_SHELL_BRACE_WOOD_COST:
		message = "材料还不齐：安装需要 2 块木料和 1 片礁壳；蓝图会一直留在册中。"
	else:
		wood -= REEF_SHELL_BRACE_WOOD_COST
		reef_shell_plates -= 1
		reef_shell_brace_installed = true
		var shelter := _ark_node("BuiltShelter") as Node3D
		if shelter:
			_add_reef_shell_brace_visual(shelter)
		_record_world_event("reef_shell_brace_installed", {"blueprint_id": "reef_shell_storm_brace", "shell_plates_spent": 1, "wood_spent": REEF_SHELL_BRACE_WOOD_COST, "shelter_roof_protected": true})
		message = "你把礁背甲片嵌进棚架受力处，再用木楔和缆绳固定。它不是一块装饰：以后风雨来时，棚顶不再因未加固而被掀开。"
	_save_progress()
	_update_hud()


func _add_template_ghost_box(parent: Node3D, part_name: String, size: Vector3, local_position: Vector3) -> void:
	var ghost := MeshInstance3D.new()
	ghost.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	ghost.mesh = mesh
	ghost.position = local_position
	parent.add_child(ghost)


func _update_build_preview() -> void:
	if not building_mode or camera == null or build_preview == null:
		return
	if build_type == "guest_cabin_template":
		preview_position = Vector3(0.0, 0.12, -4.2)
		build_preview.position = preview_position
		preview_valid = _is_valid_guest_cabin_position(preview_position)
		_set_build_preview_material(preview_valid_material if preview_valid else preview_invalid_material)
		return
	var mouse := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse)
	var ray_direction := camera.project_ray_normal(mouse)
	var floor_plane := Plane(Vector3.UP, ark_root.global_position.y + 0.12)
	var hit = floor_plane.intersects_ray(ray_origin, ray_direction)
	if hit == null:
		preview_valid = false
		_set_build_preview_material(preview_invalid_material)
		return
	var point: Vector3 = ark_root.to_local(hit)
	preview_position = Vector3(snappedf(point.x, 0.5), 0.12, snappedf(point.z, 0.5))
	if build_type == "starter_home_template":
		preview_valid = _is_valid_starter_home_template_position(preview_position)
	elif build_type == "guest_cabin_template":
		preview_valid = _is_valid_guest_cabin_position(preview_position)
	elif build_type == "shelter":
		preview_valid = _is_valid_shelter_position(preview_position)
	elif build_type == "storage":
		preview_valid = _is_valid_storage_position(preview_position)
	elif build_type == "workbench":
		preview_valid = _is_valid_workbench_position(preview_position)
	else:
		preview_valid = _is_valid_raft_extension_position(preview_position)
	build_preview.position = preview_position
	_set_build_preview_material(preview_valid_material if preview_valid else preview_invalid_material)


func _set_build_preview_material(ghost_material: StandardMaterial3D) -> void:
	if build_preview is MeshInstance3D:
		(build_preview as MeshInstance3D).material_override = ghost_material
	else:
		for child in build_preview.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).material_override = ghost_material


func _is_valid_starter_home_template_position(position: Vector3) -> bool:
	if shelter_built or storage_built or not _is_valid_shelter_position(position):
		return false
	var storage_spot := position + Vector3(2.0, 0.0, -1.5)
	return absf(storage_spot.x) <= 2.2 and absf(storage_spot.z) <= 1.55


func _try_place_starter_home_template(position: Vector3) -> bool:
	var snapped_position := Vector3(snappedf(position.x, 0.5), 0.12, snappedf(position.z, 0.5))
	if not _is_valid_starter_home_template_position(snapped_position):
		message = "模板占地或通道放不下；请把棚屋入口朝向筏首，避开筏边。"
		_update_hud()
		return false
	if wood < BUILD_COST + STORAGE_COST:
		_cancel_build()
		message = "木料不足，潮棚之家模板暂时无法完成。"
		_update_hud()
		return false
	var storage_spot := snapped_position + Vector3(2.0, 0.0, -1.5)
	wood -= BUILD_COST + STORAGE_COST
	shelter_built = true
	shelter_position = snapped_position
	storage_built = true
	storage_position = storage_spot
	_record_world_event("shelter_built", {"wood_spent": BUILD_COST, "position": {"x": shelter_position.x, "z": shelter_position.z}, "construction_mode": "starter_home_template"})
	_build_shelter_at(shelter_position)
	_record_world_event("storage_built", {"wood_spent": STORAGE_COST, "position": {"x": storage_position.x, "z": storage_position.z}, "construction_mode": "starter_home_template"})
	_build_storage_at(storage_position)
	_cancel_build(false)
	message = "潮棚之家落成了：棚屋、床铺、灯与储物箱都已就位，正面通道也留了出来。此后仍可自由逐件扩建。"
	_save_progress()
	_update_hud()
	return true


func _is_valid_shelter_position(position: Vector3) -> bool:
	if shelter_built or absf(position.x) > 1.2 or absf(position.z) > 0.55:
		return false
	if storage_built and _rectangles_overlap(position, Vector2(1.5, 1.2), storage_position, Vector2(0.55, 0.48), 0.2):
		return false
	if workbench_built and _rectangles_overlap(position, Vector2(1.5, 1.2), workbench_position, Vector2(0.65, 0.5), 0.2):
		return false
	return true


func _rectangles_overlap(first: Vector3, first_half_size: Vector2, second: Vector3, second_half_size: Vector2, clearance: float) -> bool:
	return absf(first.x - second.x) < first_half_size.x + second_half_size.x + clearance and absf(first.z - second.z) < first_half_size.y + second_half_size.y + clearance


func _is_valid_storage_position(position: Vector3) -> bool:
	if storage_built or absf(position.x) > 2.2 or absf(position.z) > 1.55:
		return false
	var horizontal_distance := Vector2(position.x - shelter_position.x, position.z - shelter_position.z).length()
	return horizontal_distance >= 2.0


func _is_valid_workbench_position(position: Vector3) -> bool:
	if workbench_built or absf(position.x) > 2.2 or absf(position.z) > 1.55:
		return false
	var shelter_distance := Vector2(position.x - shelter_position.x, position.z - shelter_position.z).length()
	var storage_distance := Vector2(position.x - storage_position.x, position.z - storage_position.z).length()
	return shelter_distance >= 2.0 and storage_distance >= 1.35


func _is_valid_raft_extension_position(position: Vector3) -> bool:
	return workbench_built and not raft_extension_built and keel_beams >= RAFT_EXTENSION_KEEL_COST and wood >= RAFT_EXTENSION_WOOD_COST and absf(position.x) <= 0.25 and absf(position.z + 4.2) <= 0.25


func _is_valid_guest_cabin_position(position: Vector3) -> bool:
	return _has_blueprint("tide_guest_cabin") and raft_extension_built and not guest_cabin_built and guest_cabin_frames >= GUEST_CABIN_FRAME_COST and wood >= GUEST_CABIN_WOOD_COST and absf(position.x) <= 0.25 and absf(position.z + 4.2) <= 0.25


func _try_place_guest_cabin_template(position: Vector3) -> bool:
	var snapped_position := Vector3(snappedf(position.x, 0.5), 0.12, snappedf(position.z, 0.5))
	if not _is_valid_guest_cabin_position(snapped_position):
		message = "客舱须建在龙骨甲板左舷预留的承重区，并确认蓝图、木料与舱骨都在。"
		_update_hud()
		return false
	var capacity_before := _resident_capacity()
	wood -= GUEST_CABIN_WOOD_COST
	guest_cabin_frames -= GUEST_CABIN_FRAME_COST
	guest_cabin_built = true
	var extension := _ark_node("BuiltRaftExtension") as Node3D
	if extension:
		_build_guest_cabin_at(extension)
	_update_sailmaker_schedule()
	_record_world_event("guest_cabin_built", {"blueprint_id": "tide_guest_cabin", "source_site": "jade_sail_ark", "wood_spent": GUEST_CABIN_WOOD_COST, "guest_cabin_frames_spent": GUEST_CABIN_FRAME_COST, "resident_capacity_before": capacity_before, "resident_capacity_after": _resident_capacity()})
	_cancel_build(false)
	message = "你把舱骨嵌进左舷承梁，再用木板和旧帆围出一间听潮客舱。灯、床与遮风帘都落在实处，右侧铺位和中间通道仍能使用；仙舟又多了一处真正的居住泊位。"
	_save_progress()
	_update_hud()
	return true


func _try_place_shelter(position: Vector3) -> bool:
	var snapped_position := Vector3(snappedf(position.x, 0.5), 0.12, snappedf(position.z, 0.5))
	if not _is_valid_shelter_position(snapped_position):
		message = "这处位置太靠筏边，或与已有设施重叠；避风棚可以在甲板承重区内调整位置。"
		_update_hud()
		return false
	if wood < BUILD_COST:
		_cancel_build()
		message = "木料不够，暂时搭不起避风棚。"
		_update_hud()
		return false
	wood -= BUILD_COST
	shelter_built = true
	shelter_position = snapped_position
	_record_world_event("shelter_built", {"wood_spent": BUILD_COST, "position": {"x": snapped_position.x, "z": snapped_position.z}})
	_build_shelter_at(shelter_position)
	_cancel_build(false)
	message = "你把木板一根根钉牢，终于搭出能挡风的小棚。回头时，岸上的旅人正朝灯火看来。"
	_save_progress()
	_update_hud()
	return true


func _try_place_storage(position: Vector3) -> bool:
	var snapped_position := Vector3(snappedf(position.x, 0.5), 0.12, snappedf(position.z, 0.5))
	if not _is_valid_storage_position(snapped_position):
		message = "这处位置太靠筏边，或与避风棚挤在一起；给储物箱留一块稳当的空位。"
		_update_hud()
		return false
	if wood < STORAGE_COST:
		_cancel_build()
		message = "木料不够，储物箱还差 %d 块。" % (STORAGE_COST - wood)
		_update_hud()
		return false
	wood -= STORAGE_COST
	storage_built = true
	storage_position = snapped_position
	_record_world_event("storage_built", {"wood_spent": STORAGE_COST, "position": {"x": snapped_position.x, "z": snapped_position.z}})
	_build_storage_at(storage_position)
	_cancel_build(false)
	message = "你把储物箱钉在筏舷内侧。下一趟带回来的木料终于有了干燥去处。"
	_save_progress()
	_update_hud()
	return true


func _try_place_workbench(position: Vector3) -> bool:
	var snapped_position := Vector3(snappedf(position.x, 0.5), 0.12, snappedf(position.z, 0.5))
	if not _is_valid_workbench_position(snapped_position):
		message = "这处空间太窄；工作台要避开棚屋、储物箱和筏边通道。"
		_update_hud()
		return false
	if wood < WORKBENCH_COST:
		_cancel_build()
		message = "阵枢工作台还差 %d 块木料。" % (WORKBENCH_COST - wood)
		_update_hud()
		return false
	wood -= WORKBENCH_COST
	workbench_built = true
	workbench_position = snapped_position
	_record_world_event("workbench_built", {"wood_spent": WORKBENCH_COST, "position": {"x": snapped_position.x, "z": snapped_position.z}})
	_build_workbench_at(workbench_position)
	_cancel_build(false)
	message = "你把旧铜片和剩下的木料拼成一张稳固工作台，终于有地方拆解遗迹带回的灵枢。"
	_save_progress()
	_update_hud()
	return true


func _try_place_raft_extension(position: Vector3) -> bool:
	var snapped_position := Vector3(snappedf(position.x, 0.5), 0.12, snappedf(position.z, 0.5))
	if not _is_valid_raft_extension_position(snapped_position):
		message = "龙骨甲板必须接在筏首，且需要先有工作台、4 块木料与远礁龙骨。"
		_update_hud()
		return false
	var capacity_before := _resident_capacity()
	wood -= RAFT_EXTENSION_WOOD_COST
	keel_beams -= RAFT_EXTENSION_KEEL_COST
	raft_extension_built = true
	_record_world_event("raft_extension_built", {"wood_spent": RAFT_EXTENSION_WOOD_COST, "keel_beams_spent": RAFT_EXTENSION_KEEL_COST, "position": {"x": snapped_position.x, "z": snapped_position.z}, "source_site": "far_reef_wreck", "resident_capacity_before": capacity_before, "resident_capacity_after": _resident_capacity()})
	_build_raft_extension_at(snapped_position)
	_cancel_build(false)
	message = "你把远礁龙骨一端接入原筏的主梁，再将四块船板一一钉牢。筏首向前长出一片新甲板，也多出一处住民泊位。"
	_save_progress()
	_update_hud()
	return true


func _dismantle_raft_extension() -> bool:
	if sailing_mode:
		message = "航行时不能拆卸仙舟甲板；先停船再处理。"
		_update_hud()
		return false
	if not raft_extension_built or _ark_node("BuiltRaftExtension") == null:
		message = "筏首没有可拆卸的龙骨甲板。"
		_update_hud()
		return false
	if _resident_occupancy() > 2:
		message = "甲板上还有住民依赖这处泊位，不能在不安排去处时拆掉它。先让住民迁出，再处理扩建。"
		_update_hud()
		return false
	if resident_gather_pending:
		_abort_resident_gathering("raft_extension_dismantled")
	# Move the player back onto the original deck before removing the support surface.
	if player and ark_root:
		player.global_position = ark_root.to_global(Vector3(0.0, 1.1, -1.25))
	_evacuate_residents_from_raft_extension()
	var extension := _ark_node("BuiltRaftExtension")
	if extension:
		extension.queue_free()
	_set_raft_rail("RaftBow", Vector3(0, 0.35, -2.2), Vector3(5.2, 0.45, 0.16))
	_set_raft_rail("RaftPort", Vector3(-2.95, 0.35, 0), Vector3(0.16, 0.45, 4.3))
	_set_raft_rail("RaftStarboard", Vector3(2.95, 0.35, 0), Vector3(0.16, 0.45, 4.3))
	for index in range(interactables.size() - 1, -1, -1):
		var entry: Dictionary = interactables[index]
		if str(entry.get("id", "")) in ["raft_extension", "guest_cabin"]:
			var marker: Node = entry.get("node")
			if is_instance_valid(marker):
				marker.queue_free()
			interactables.remove_at(index)
	raft_extension_built = false
	var wood_returned := RAFT_EXTENSION_WOOD_COST
	var cabin_frame_returned := 0
	if guest_cabin_built:
		wood_returned += GUEST_CABIN_WOOD_COST
		cabin_frame_returned = GUEST_CABIN_FRAME_COST
		guest_cabin_built = false
		guest_cabin_frames += cabin_frame_returned
	wood += wood_returned
	keel_beams += RAFT_EXTENSION_KEEL_COST
	_update_traveler_schedule()
	_update_sailmaker_schedule()
	_record_world_event("raft_extension_dismantled", {"wood_returned": wood_returned, "keel_beams_returned": RAFT_EXTENSION_KEEL_COST, "guest_cabin_frames_returned": cabin_frame_returned, "blueprint_retained": _has_blueprint("keel_deck_expansion"), "guest_cabin_blueprint_retained": _has_blueprint("tide_guest_cabin")})
	message = "你先退回原筏面，再卸下龙骨甲板。四块船板与远礁龙骨都收回了；" + ("听潮客舱的木料和舱骨也一并收回。" if cabin_frame_returned > 0 else "") + "学会的图样仍记在心里，备齐材料便能重建。"
	_save_progress()
	_update_hud()
	return true


func _cancel_build(show_message: bool = true) -> void:
	building_mode = false
	preview_valid = false
	if is_instance_valid(build_preview):
		build_preview.queue_free()
	build_preview = null
	if show_message:
		message = "你收起了搭建预览，木料还在。"
		_update_hud()


func _build_shelter_at(position: Vector3) -> void:
	var structure := Node3D.new()
	structure.name = "BuiltShelter"
	structure.position = position
	ark_root.add_child(structure)
	_add_local_box(structure, "Floor", Vector3(0, 0.12, 0), Vector3(3.0, 0.14, 2.4), Color("9b7650"), false)
	_add_local_box(structure, "Back", Vector3(0, 1.25, -1.12), Vector3(3.0, 2.2, 0.14), Color("76593f"), true)
	_add_local_box(structure, "Left", Vector3(-1.42, 1.25, 0), Vector3(0.14, 2.2, 2.2), Color("76593f"), true)
	_add_local_box(structure, "Right", Vector3(1.42, 1.25, 0), Vector3(0.14, 2.2, 2.2), Color("76593f"), true)
	_add_local_box(structure, "Roof", Vector3(0, 2.38, 0), Vector3(3.2, 0.18, 2.6), Color("a58b66"), false)
	var roof := structure.get_node("Roof") as Node3D
	roof.visible = not shelter_roof_damaged
	_add_shelter_visual_details(structure, roof)
	if reef_shell_brace_installed:
		_add_reef_shell_brace_visual(structure)
	_add_local_box(structure, "Cot", Vector3(0.72, 0.38, 0.2), Vector3(0.92, 0.34, 0.52), Color("8a684c"), false)
	_add_local_box(structure, "Bedroll", Vector3(0.72, 0.58, 0.2), Vector3(0.76, 0.08, 0.48), Color("c0a589"), false)
	_add_local_box(structure, "HearthStone", Vector3(-1.05, 0.21, -0.75), Vector3(0.62, 0.18, 0.52), Color("69645b"), false)
	_add_local_box(structure, "HearthEmbers", Vector3(-1.05, 0.34, -0.75), Vector3(0.34, 0.06, 0.32), Color("e08a4e"), false)
	if pressure_galley_built:
		_add_pressure_galley_visual(structure)
	else:
		_build_shelter_pot(structure)
	_add_local_visual_box(structure, "QuiltFold", Vector3(0.72, 0.65, 0.2), Vector3(0.54, 0.055, 0.5), Color("b88769"))
	var cot_marker := Node3D.new()
	cot_marker.name = "CotInteractable"
	cot_marker.position = position + Vector3(0.72, 0.5, 0.2)
	ark_root.add_child(cot_marker)
	interactables.append({"id": "cot", "node": cot_marker, "amount": 0})
	var hearth_marker := Node3D.new()
	hearth_marker.name = "HearthInteractable"
	hearth_marker.position = position + Vector3(-1.05, 0.45, -0.75)
	var hearth_sign := Label3D.new()
	hearth_sign.name = "Name"
	hearth_sign.text = "蒸汽饭釜 · E 煮鲜贝汤" if pressure_galley_built else "火盆小锅 · E 煮鲜贝汤"
	hearth_sign.position.y = 0.8
	hearth_sign.font_size = 24
	hearth_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hearth_sign.modulate = Color("fff0c9")
	hearth_marker.add_child(hearth_sign)
	ark_root.add_child(hearth_marker)
	interactables.append({"id": "hearth", "node": hearth_marker, "amount": 0})
	var warm_light := OmniLight3D.new()
	warm_light.name = "WarmLight"
	warm_light.position = Vector3(0, 1.5, -0.4)
	warm_light.light_color = Color("ffca7a")
	warm_light.light_energy = 0.9
	warm_light.omni_range = 4.6
	warm_light.shadow_enabled = true
	structure.add_child(warm_light)
	_build_shelter_lamp(structure)
	_update_lantern_lighting(weather_phase == WeatherPhase.STORM)


func _add_reef_shell_brace_visual(structure: Node3D) -> void:
	if structure.get_node_or_null("ReefShellStormBrace"):
		return
	var brace := Node3D.new()
	brace.name = "ReefShellStormBrace"
	structure.add_child(brace)
	for index in range(5):
		var offset_x := -1.0 + float(index) * 0.5
		_add_local_visual_box(brace, "ShellPlate_%d" % index, Vector3(offset_x, 2.53, 0.0), Vector3(0.42, 0.055, 2.28), Color("638a83") if index % 2 == 0 else Color("756d58"))
	for side in [-1.0, 1.0]:
		_add_local_visual_box(brace, "Lashing_%d" % int(side), Vector3(side * 1.32, 2.46, 0.0), Vector3(0.12, 0.07, 2.36), Color("b69b6c"))


func _add_shelter_visual_details(structure: Node3D, roof: Node3D) -> void:
	var floorboards := Node3D.new()
	floorboards.name = "CabinFloorboards"
	structure.add_child(floorboards)
	var plank_colors: Array[Color] = [Color("a17b54"), Color("ad855c"), Color("96704d"), Color("b18b62")]
	for index in range(8):
		var board_x := -1.3 + float(index) * 0.37
		_add_local_visual_box(floorboards, "FloorPlank%d" % index, Vector3(board_x, 0.215, 0.0), Vector3(0.35, 0.045, 2.28), plank_colors[index % plank_colors.size()])
		_add_local_visual_box(floorboards, "PlankEndGrain%d" % index, Vector3(board_x, 0.241, 1.1), Vector3(0.32, 0.012, 0.025), Color("74563d"))

	var frame := Node3D.new()
	frame.name = "CabinFrameDetails"
	structure.add_child(frame)
	for side in [-1.0, 1.0]:
		for depth in [-1.0, 1.0]:
			var post_x: float = float(side) * 1.31
			var post_z: float = float(depth) * 1.02
			_add_local_visual_cylinder(frame, "FramePost_%d_%d" % [int(side), int(depth)], Vector3(post_x, 1.16, post_z), 0.075, 2.08, Color("6d4b34"))
			_add_local_visual_box(frame, "PostLashing_%d_%d" % [int(side), int(depth)], Vector3(post_x, 1.43, post_z), Vector3(0.19, 0.045, 0.19), Color("b29a73"))
			_add_local_visual_box(frame, "PostFoot_%d_%d" % [int(side), int(depth)], Vector3(post_x, 0.22, post_z), Vector3(0.23, 0.12, 0.23), Color("594232"))
	_add_local_visual_box(frame, "FrontLintel", Vector3(0.0, 2.1, 1.06), Vector3(2.78, 0.14, 0.14), Color("805b3e"))
	_add_local_visual_box(frame, "RearLintel", Vector3(0.0, 2.1, -1.03), Vector3(2.78, 0.14, 0.14), Color("805b3e"))
	_add_local_visual_box(frame, "EntranceCanvas", Vector3(0.0, 2.36, 1.3), Vector3(2.14, 0.055, 0.6), Color("8b9b8b"))
	_add_local_visual_box(frame, "CanvasEdgeBinding", Vector3(0.0, 2.34, 1.58), Vector3(2.17, 0.075, 0.08), Color("6e796e"))
	_add_local_visual_box(frame, "CanvasPatch", Vector3(-0.63, 2.405, 1.38), Vector3(0.48, 0.018, 0.26), Color("b28d64"))
	_add_local_visual_box(frame, "HangingHerbBundle", Vector3(-1.15, 1.73, 0.92), Vector3(0.16, 0.38, 0.12), Color("667a58"))
	_add_local_visual_box(roof, "RoofRidgeBinding", Vector3(0.0, 0.115, 0.0), Vector3(3.12, 0.055, 0.12), Color("76583f"))
	_add_local_visual_box(roof, "RoofCanvasPatch", Vector3(0.82, 0.115, -0.58), Vector3(0.56, 0.035, 0.48), Color("7c8d80"))
	_add_local_visual_box(roof, "RoofCanvasPatchSeam", Vector3(0.82, 0.139, -0.58), Vector3(0.58, 0.018, 0.035), Color("c1a47b"))


func _build_shelter_lamp(parent: Node3D) -> void:
	var lamp := Node3D.new()
	lamp.name = "Lamp"
	lamp.position = Vector3(-0.18, 1.52, -0.48)
	parent.add_child(lamp)
	_add_local_visual_box(lamp, "HangingCord", Vector3(0.0, 0.35, 0.0), Vector3(0.035, 0.28, 0.035), Color("76563d"))
	_add_local_visual_cylinder(lamp, "Cap", Vector3(0.0, 0.19, 0.0), 0.1, 0.07, Color("98734e"))
	var glass := MeshInstance3D.new()
	glass.name = "WarmGlass"
	var glass_mesh := SphereMesh.new()
	glass_mesh.radius = 0.115
	glass_mesh.height = 0.31
	glass_mesh.radial_segments = 12
	glass_mesh.rings = 6
	glass.mesh = glass_mesh
	glass.position = Vector3(0.0, 0.0, 0.0)
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color("ffd38a")
	glass_material.emission_enabled = true
	glass_material.emission = Color("ffb84e")
	glass_material.roughness = 0.32
	glass.material_override = glass_material
	lamp.add_child(glass)
	_add_local_visual_cylinder(lamp, "Base", Vector3(0.0, -0.19, 0.0), 0.095, 0.055, Color("70523b"))
	var lamp_light := OmniLight3D.new()
	lamp_light.name = "LampGlow"
	lamp_light.light_color = Color("ffc36d")
	lamp_light.light_energy = 0.55
	lamp_light.omni_range = 3.2
	lamp_light.shadow_enabled = false
	lamp.add_child(lamp_light)


func _build_shelter_pot(parent: Node3D) -> void:
	var pot := Node3D.new()
	pot.name = "HearthPot"
	pot.position = Vector3(-1.05, 0.53, -0.75)
	parent.add_child(pot)
	_add_local_visual_cylinder(pot, "PotBody", Vector3.ZERO, 0.2, 0.25, Color("42494a"))
	_add_local_visual_cylinder(pot, "PotRim", Vector3(0.0, 0.12, 0.0), 0.225, 0.045, Color("78807b"))
	_add_local_visual_cylinder(pot, "PotLid", Vector3(0.0, 0.15, 0.0), 0.19, 0.025, Color("59635f"))
	_add_local_visual_cylinder(pot, "LidHandle", Vector3(0.0, 0.19, 0.0), 0.045, 0.055, Color("b39667"))


func _add_pressure_galley_visual(parent: Node3D) -> void:
	if parent.get_node_or_null("PressureGalley") != null:
		return
	var galley := Node3D.new()
	galley.name = "PressureGalley"
	galley.position = Vector3(-1.05, 0.53, -0.75)
	parent.add_child(galley)
	_add_local_visual_cylinder(galley, "CopperPressureBody", Vector3.ZERO, 0.235, 0.32, Color("8b6547"))
	_add_local_visual_cylinder(galley, "SealedLid", Vector3(0.0, 0.17, 0.0), 0.25, 0.07, Color("c09a63"))
	_add_local_visual_cylinder(galley, "PressureValve", Vector3(0.0, 0.27, 0.0), 0.065, 0.15, Color("e5bb78"))
	var gauge := _add_local_visual_cylinder(galley, "PressureGauge", Vector3(-0.23, 0.21, 0.0), 0.12, 0.07, Color("d8c9a7"))
	gauge.rotation.z = PI * 0.5
	var gauge_needle := _add_local_visual_box(galley, "GaugeNeedle", Vector3(-0.29, 0.21, 0.0), Vector3(0.12, 0.025, 0.025), Color("a94f3b"))
	gauge_needle.rotation.z = -0.42
	for side in [-1.0, 1.0]:
		var pipe := _add_local_visual_cylinder(galley, "SteamLine%s" % str(side), Vector3(side * 0.32, 0.09, -0.08), 0.045, 0.58, Color("9d7953"))
		pipe.rotation.z = side * 0.5
	var warmth := OmniLight3D.new()
	warmth.name = "PressureGlow"
	warmth.position = Vector3(0.0, 0.31, 0.0)
	warmth.light_color = Color("efa566")
	warmth.light_energy = 0.38
	warmth.omni_range = 2.4
	galley.add_child(warmth)


func _add_local_visual_box(parent: Node3D, id: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = id
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = position
	visual.material_override = _material(color)
	parent.add_child(visual)
	return visual


func _add_local_visual_cylinder(parent: Node3D, id: String, position: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = id
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.84
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	visual.mesh = mesh
	visual.position = position
	visual.material_override = _material(color)
	parent.add_child(visual)
	return visual


func _add_resident_keepsake() -> void:
	var structure := _ark_node("BuiltShelter") as Node3D
	if structure == null:
		return
	var charm := structure.get_node_or_null("TideShellKeepsake") as Node3D
	if charm == null:
		charm = Node3D.new()
		charm.name = "TideShellKeepsake"
		charm.position = Vector3(0.0, 1.05, -0.96)
		var shell := MeshInstance3D.new()
		shell.name = "PolishedShell"
		var shell_mesh := SphereMesh.new()
		shell_mesh.radius = 0.13
		shell_mesh.height = 0.22
		shell.mesh = shell_mesh
		shell.scale = Vector3(0.78, 0.94, 0.56)
		shell.material_override = _material(Color("dfc7a0"))
		charm.add_child(shell)
		var cord := MeshInstance3D.new()
		cord.name = "Twine"
		var cord_mesh := CylinderMesh.new()
		cord_mesh.top_radius = 0.012
		cord_mesh.bottom_radius = 0.012
		cord_mesh.height = 0.28
		cord.mesh = cord_mesh
		cord.position.y = 0.18
		cord.material_override = _material(Color("806349"))
		charm.add_child(cord)
		structure.add_child(charm)
	if shared_meal_count >= 2 and charm.get_node_or_null("SecondPolishedShell") == null:
		var second_shell := MeshInstance3D.new()
		second_shell.name = "SecondPolishedShell"
		var second_shell_mesh := SphereMesh.new()
		second_shell_mesh.radius = 0.105
		second_shell_mesh.height = 0.18
		second_shell.mesh = second_shell_mesh
		second_shell.scale = Vector3(0.76, 0.92, 0.56)
		second_shell.position = Vector3(0.23, -0.03, 0.01)
		second_shell.material_override = _material(Color("b9d4cd"))
		charm.add_child(second_shell)
	var marker := _ark_node("ResidentKeepsakeInteractable") as Node3D
	if marker:
		var marker_sign := marker.get_node_or_null("Name") as Label3D
		if marker_sign:
			marker_sign.text = "并排潮贝 · 两次共餐" if shared_meal_count >= 2 else "守潮人留下的潮贝"
		return
	marker = Node3D.new()
	marker.name = "ResidentKeepsakeInteractable"
	marker.position = shelter_position + Vector3(0.0, 1.02, -0.96)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "并排潮贝 · 两次共餐" if shared_meal_count >= 2 else "守潮人留下的潮贝"
	sign.position.y = 0.28
	sign.font_size = 20
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("fff0c9")
	marker.add_child(sign)
	ark_root.add_child(marker)
	interactables.append({"id": "resident_keepsake", "node": marker, "amount": 0})


func _build_storage_at(position: Vector3) -> void:
	var crate := Node3D.new()
	crate.name = "BuiltStorage"
	crate.position = position
	ark_root.add_child(crate)
	_add_local_box(crate, "Body", Vector3(0, 0.42, 0), Vector3(0.9, 0.72, 0.78), Color("79583e"), false)
	_add_local_box(crate, "Lid", Vector3(0, 0.82, 0), Vector3(0.98, 0.12, 0.86), Color("a47c53"), false)
	var marker := Node3D.new()
	marker.name = "StorageInteractable"
	marker.position = position + Vector3(0, 0.5, 0)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "储物箱 · E 存取木料"
	sign.position.y = 0.65
	sign.font_size = 24
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("fff0c9")
	marker.add_child(sign)
	ark_root.add_child(marker)
	interactables.append({"id": "storage", "node": marker, "amount": 0})


func _build_workbench_at(position: Vector3) -> void:
	var bench := Node3D.new()
	bench.name = "BuiltWorkbench"
	bench.position = position
	ark_root.add_child(bench)
	_add_local_box(bench, "Legs", Vector3(0, 0.32, 0), Vector3(1.0, 0.58, 0.68), Color("594d43"), false)
	_add_local_box(bench, "Top", Vector3(0, 0.66, 0), Vector3(1.12, 0.16, 0.78), Color("9a7551"), false)
	_add_local_box(bench, "SpiritSocket", Vector3(0, 0.79, -0.12), Vector3(0.28, 0.08, 0.24), Color("729c92"), false)
	var marker := Node3D.new()
	marker.name = "WorkbenchInteractable"
	marker.position = position + Vector3(0, 0.5, 0)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "阵枢工作台 · E 调校旧灯"
	sign.position.y = 0.75
	sign.font_size = 24
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("fff0c9")
	marker.add_child(sign)
	ark_root.add_child(marker)
	interactables.append({"id": "workbench", "node": marker, "amount": 0})


func _build_raft_extension_at(position: Vector3) -> void:
	var extension := Node3D.new()
	extension.name = "BuiltRaftExtension"
	extension.position = position
	ark_root.add_child(extension)
	_add_local_box(extension, "Deck", Vector3(0, -0.08, 0), Vector3(5.9, 0.2, 4.1), Color("a77e54"), true)
	for plank_index in range(8):
		var seam := MeshInstance3D.new()
		seam.name = "DeckSeam%d" % plank_index
		var seam_mesh := BoxMesh.new()
		seam_mesh.size = Vector3(0.035, 0.012, 3.9)
		seam.mesh = seam_mesh
		seam.position = Vector3(-2.55 + plank_index * 0.73, 0.035, 0)
		seam.material_override = _material(Color("76583d"))
		extension.add_child(seam)
	_add_expansion_berth(extension)
	if guest_cabin_built:
		_build_guest_cabin_at(extension)
	# Replace the old bow and side rails with a continuous outline so the upgrade is walkable.
	_set_raft_rail("RaftBow", Vector3(0, 0.35, -6.25), Vector3(5.2, 0.45, 0.16))
	_set_raft_rail("RaftPort", Vector3(-2.95, 0.35, -2.05), Vector3(0.16, 0.45, 8.4))
	_set_raft_rail("RaftStarboard", Vector3(2.95, 0.35, -2.05), Vector3(0.16, 0.45, 8.4))
	var marker := Node3D.new()
	marker.name = "RaftExtensionInteractable"
	marker.position = position + Vector3(0.0, 0.4, 1.45)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "龙骨甲板 · E 管理"
	sign.position.y = 0.9
	sign.font_size = 24
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("fff0c9")
	marker.add_child(sign)
	ark_root.add_child(marker)
	interactables.append({"id": "raft_extension", "node": marker, "amount": 0})
	_update_traveler_schedule()
	_update_sailmaker_schedule()


func _build_guest_cabin_at(extension: Node3D) -> void:
	if extension.get_node_or_null("GuestCabin") != null:
		return
	var cabin := Node3D.new()
	cabin.name = "GuestCabin"
	cabin.position = Vector3(-1.3, 0.08, 0.2)
	extension.add_child(cabin)
	_add_local_box(cabin, "Floor", Vector3(0.0, 0.09, 0.0), Vector3(2.5, 0.14, 2.65), Color("b09068"), false)
	_add_local_box(cabin, "BackWall", Vector3(0.0, 1.02, -1.25), Vector3(2.42, 1.78, 0.12), Color("7c5c45"), true)
	_add_local_box(cabin, "PortWall", Vector3(-1.2, 1.02, 0.0), Vector3(0.12, 1.78, 2.45), Color("775942"), true)
	_add_local_box(cabin, "StarboardWall", Vector3(1.2, 1.02, -0.32), Vector3(0.12, 1.78, 1.78), Color("775942"), true)
	_add_local_visual_box(cabin, "CarvedLintel", Vector3(0.0, 1.95, 1.17), Vector3(2.38, 0.14, 0.14), Color("c3a36f"))
	_add_local_visual_box(cabin, "CanvasAwning", Vector3(0.0, 1.96, -0.47), Vector3(2.56, 0.12, 1.46), Color("748c83"))
	_add_local_visual_box(cabin, "AwningBinding", Vector3(0.0, 1.96, 0.27), Vector3(2.58, 0.08, 0.09), Color("d0b98c"))
	_add_local_visual_box(cabin, "PrivacyCurtain", Vector3(0.84, 1.12, 1.08), Vector3(0.52, 1.46, 0.07), Color("9a7367"))
	_add_local_visual_box(cabin, "BedFrame", Vector3(0.45, 0.29, -0.34), Vector3(0.9, 0.28, 1.48), Color("684b37"))
	_add_local_visual_box(cabin, "Mattress", Vector3(0.45, 0.48, -0.34), Vector3(0.82, 0.14, 1.38), Color("d4c2a2"))
	_add_local_visual_box(cabin, "FoldedQuilt", Vector3(0.45, 0.58, 0.05), Vector3(0.78, 0.08, 0.55), Color("718c84"))
	_add_local_visual_box(cabin, "BedsideChest", Vector3(-0.76, 0.38, -0.72), Vector3(0.42, 0.52, 0.44), Color("79583e"))
	_add_local_visual_box(cabin, "GuestKeepsakeShelf", Vector3(-0.76, 1.2, -1.14), Vector3(0.68, 0.1, 0.24), Color("b8915f"))
	_add_local_visual_cylinder(cabin, "WarmLamp", Vector3(-0.75, 1.48, -0.86), 0.09, 0.25, Color("f2bd6c"))
	var lamp_light := OmniLight3D.new()
	lamp_light.name = "GuestLampLight"
	lamp_light.position = Vector3(-0.75, 1.5, -0.86)
	lamp_light.light_color = Color("ffcd83")
	lamp_light.light_energy = 0.45
	lamp_light.omni_range = 3.2
	cabin.add_child(lamp_light)
	var marker := Node3D.new()
	marker.name = "GuestCabinInteractable"
	marker.position = Vector3(-1.3, 0.52, -4.2 + 1.42)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "听潮客舱 · 留给远客的一盏灯"
	sign.position.y = 0.78
	sign.font_size = 20
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("fff0c9")
	marker.add_child(sign)
	ark_root.add_child(marker)
	interactables.append({"id": "guest_cabin", "node": marker, "amount": 0})


func _add_expansion_berth(extension: Node3D) -> void:
	var berth := Node3D.new()
	berth.name = "Berth"
	extension.add_child(berth)
	_add_local_visual_box(berth, "CotFrame", Vector3(0.95, 0.28, -1.1), Vector3(1.26, 0.22, 0.82), Color("6f503a"))
	_add_local_visual_box(berth, "Mattress", Vector3(0.95, 0.43, -1.1), Vector3(1.16, 0.12, 0.74), Color("c6ad87"))
	_add_local_visual_box(berth, "Bedroll", Vector3(0.95, 0.52, -1.12), Vector3(0.96, 0.07, 0.68), Color("a9aca0"))
	_add_local_visual_box(berth, "Quilt", Vector3(0.95, 0.59, -0.9), Vector3(0.8, 0.055, 0.28), Color("7f9a93"))
	for corner in [Vector3(0.18, 0.82, -1.72), Vector3(1.72, 0.82, -1.72), Vector3(0.18, 0.82, -0.48), Vector3(1.72, 0.82, -0.48)]:
		_add_local_visual_cylinder(berth, "AwningPost", corner, 0.055, 1.2, Color("72553a"))
	_add_local_visual_box(berth, "AwningFrame", Vector3(0.95, 1.42, -1.1), Vector3(1.9, 0.09, 1.6), Color("947f61"))
	_add_local_visual_box(berth, "CanvasAwning", Vector3(0.95, 1.49, -1.1), Vector3(1.82, 0.055, 1.48), Color("82988d"))
	_add_local_visual_box(berth, "CanvasTie", Vector3(0.95, 1.47, -0.36), Vector3(1.72, 0.035, 0.07), Color("d0b98c"))
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "风帆下的夜铺"
	sign.position = Vector3(0.95, 1.78, -1.1)
	sign.font_size = 20
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("fff0c9")
	berth.add_child(sign)


func _set_raft_rail(id: String, position: Vector3, size: Vector3) -> void:
	var rail := _ark_node(id) as StaticBody3D
	if rail == null:
		return
	rail.position = position
	var visual := rail.get_child(0) as MeshInstance3D
	if visual and visual.mesh is BoxMesh:
		(visual.mesh as BoxMesh).size = size
	var collision := rail.get_child(1) as CollisionShape3D
	if collision and collision.shape is BoxShape3D:
		(collision.shape as BoxShape3D).size = size


func _add_local_box(parent: Node3D, id: String, position: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.name = id
	body.position = position
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = _material(color)
	body.add_child(visual)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	parent.add_child(body)


func _add_pile(id: String, position: Vector3, amount: int) -> void:
	var pile := Node3D.new()
	pile.name = id
	pile.position = position
	var wood_material := _material(Color("b58a5e"))
	for index in range(3):
		var plank := MeshInstance3D.new()
		var plank_mesh := BoxMesh.new()
		plank_mesh.size = Vector3(1.2, 0.14, 0.3)
		plank.mesh = plank_mesh
		plank.position = Vector3(0, float(index) * 0.12, float(index % 2) * 0.12)
		plank.rotation.y = 0.12 * float(index)
		plank.material_override = wood_material
		pile.add_child(plank)
	add_child(pile)
	interactables.append({"id": "wood", "item_id": id, "node": pile, "amount": amount})


func _add_shellfish_patch(id: String, position: Vector3, amount: int) -> void:
	if collected_ids.has(id):
		return
	var patch := Node3D.new()
	patch.name = id
	patch.position = position
	for index in range(4):
		var shell := MeshInstance3D.new()
		var shell_mesh := SphereMesh.new()
		shell_mesh.radial_segments = 8
		shell_mesh.rings = 4
		shell_mesh.height = 0.18
		shell_mesh.radius = 0.14
		shell.mesh = shell_mesh
		shell.position = Vector3(-0.22 + 0.14 * float(index), 0.09, 0.04 * float(index % 2))
		shell.scale = Vector3(1.0, 0.42, 0.72)
		shell.material_override = _material(Color("d6c5a1") if index % 2 == 0 else Color("9aab9a"))
		patch.add_child(shell)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "潮池鲜贝 · E 拾取"
	sign.position.y = 0.62
	sign.font_size = 24
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("fff0c9")
	patch.add_child(sign)
	add_child(patch)
	interactables.append({"id": "shellfish", "item_id": id, "node": patch, "amount": amount})


func _add_keel_wreck(position: Vector3) -> void:
	var wreck := Node3D.new()
	wreck.name = "KeelWreck"
	wreck.position = position
	add_child(wreck)
	var timber := _material(Color("58483d"))
	for index in range(3):
		var rib := MeshInstance3D.new()
		var rib_mesh := BoxMesh.new()
		rib_mesh.size = Vector3(0.18, 1.2 + 0.2 * float(index % 2), 3.2)
		rib.mesh = rib_mesh
		rib.position = Vector3(-1.1 + float(index) * 1.1, 0.52, 0)
		rib.rotation.z = -0.18 + 0.08 * float(index)
		rib.rotation.y = 0.12 * float(index)
		rib.material_override = timber
		wreck.add_child(rib)
	if not keel_wreck_searched:
		var beam := MeshInstance3D.new()
		beam.name = "SalvageBeam"
		var beam_mesh := BoxMesh.new()
		beam_mesh.size = Vector3(4.4, 0.2, 0.26)
		beam.mesh = beam_mesh
		beam.position = Vector3(0, 0.16, 0.85)
		beam.rotation.y = -0.08
		beam.material_override = _material(Color("b79565"))
		wreck.add_child(beam)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "遠礁沉筏 · 已拆取龍骨" if keel_wreck_searched else "遠礁沉筏 · 風口無屏障"
	sign.position = Vector3(0, 2.0, 0)
	sign.font_size = 30
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("f1d9aa")
	wreck.add_child(sign)
	interactables.append({"id": "keel_wreck", "node": wreck, "amount": 0})


func _refresh_keel_wreck_visual() -> void:
	var wreck := get_node_or_null("KeelWreck") as Node3D
	if wreck == null:
		return
	var salvage := wreck.get_node_or_null("SalvageBeam")
	if salvage:
		salvage.queue_free()
	var sign := wreck.get_node_or_null("Name") as Label3D
	if sign:
		sign.text = "遠礁沉筏 · 已拆取龍骨"


func _add_tide_station(position: Vector3) -> void:
	var station := Node3D.new()
	station.name = "MoonbackTideStation"
	station.position = position
	add_child(station)
	_add_local_visual_box(station, "StoneFooting", Vector3(0.0, -0.05, 0.0), Vector3(3.4, 0.36, 2.8), Color("555e59"))
	_add_local_visual_box(station, "RustedConsole", Vector3(0.0, 0.46, 0.7), Vector3(1.8, 0.88, 0.54), Color("65594d"))
	_add_local_visual_box(station, "ConsoleGlass", Vector3(0.0, 0.94, 0.68), Vector3(1.35, 0.045, 0.36), Color("789b98"))
	_add_local_visual_cylinder(station, "AntennaMast", Vector3(-0.92, 1.3, -0.62), 0.07, 2.8, Color("5e6760"))
	_add_local_visual_cylinder(station, "AntennaCrossbar", Vector3(-0.92, 2.25, -0.62), 0.045, 1.25, Color("87908a"))
	var mast := station.get_node("AntennaMast") as MeshInstance3D
	mast.rotation.z = -0.1
	var core := _add_local_visual_cylinder(station, "RelayCore", Vector3(0.0, 1.18, -0.32), 0.27, 0.62, Color("91c7c3"))
	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = Color("91c7c3")
	core_material.emission_enabled = true
	core_material.emission = Color("75d8d1")
	core_material.emission_energy_multiplier = 1.8
	core_material.metallic = 0.24
	core.material_override = core_material
	var glow := OmniLight3D.new()
	glow.name = "RelayGlow"
	glow.position = Vector3(0.0, 1.2, -0.32)
	glow.light_color = Color("72d0cb")
	glow.light_energy = 0.65
	glow.omni_range = 5.2
	station.add_child(glow)
	_add_local_visual_box(station, "WarningPlate", Vector3(1.17, 0.95, 0.35), Vector3(0.52, 0.68, 0.08), Color("b27a4f"))
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "旧潮汐观测台 · 信号微弱"
	sign.position = Vector3(0.0, 3.0, 0.0)
	sign.font_size = 27
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("dce2cf")
	station.add_child(sign)
	interactables.append({"id": "tide_station", "node": station, "amount": 0})
	if tide_station_searched:
		_refresh_tide_station_visual()


func _refresh_tide_station_visual() -> void:
	var station := get_node_or_null("MoonbackTideStation") as Node3D
	if station == null:
		return
	var core := station.get_node_or_null("RelayCore")
	if core:
		core.queue_free()
	var glow := station.get_node_or_null("RelayGlow") as OmniLight3D
	if glow:
		glow.light_energy = 0.12
		glow.omni_range = 2.0
	var sign := station.get_node_or_null("Name") as Label3D
	if sign:
		sign.text = "旧潮汐观测台 · 已取走潮枢"


func _add_jade_sail_ark(position: Vector3) -> void:
	var wreck := Node3D.new()
	wreck.name = "JadeSailArk"
	wreck.position = position
	wreck.rotation.y = -0.38
	add_child(wreck)
	# The ship is deliberately a lightweight greybox landmark: warm lacquer, jade
	# glass and brass trim signal a former luxury vessel, while the broken ribs and
	# tilted deck make it read as stranded rather than as a second playable ark.
	_add_local_visual_box(wreck, "ShadowedKeel", Vector3(0.0, 0.22, 0.0), Vector3(9.2, 0.34, 3.3), Color("423a35"))
	_add_local_visual_box(wreck, "PortHull", Vector3(-3.75, 0.52, 0.0), Vector3(1.35, 0.75, 2.95), Color("70443c"))
	_add_local_visual_box(wreck, "CenterHull", Vector3(0.0, 0.48, 0.0), Vector3(6.9, 0.62, 2.75), Color("9a5947"))
	_add_local_visual_box(wreck, "SternHull", Vector3(3.7, 0.42, 0.0), Vector3(1.35, 0.58, 2.6), Color("75463d"))
	_add_local_visual_box(wreck, "InlaidDeck", Vector3(-0.15, 0.82, 0.0), Vector3(6.8, 0.12, 2.55), Color("c09b69"))
	var deck_body := StaticBody3D.new()
	deck_body.name = "GuestDeckWalkable"
	var deck_collision := CollisionShape3D.new()
	var deck_shape := BoxShape3D.new()
	deck_shape.size = Vector3(6.8, 0.12, 2.55)
	deck_collision.shape = deck_shape
	deck_collision.position = Vector3(-0.15, 0.82, 0.0)
	deck_body.add_child(deck_collision)
	wreck.add_child(deck_body)
	_add_box("GuestBoardingRamp", Vector3(1.15, 0.423, 2.35), Vector3(1.15, 0.12, 2.55), Color("957452"), true, wreck)
	var boarding_ramp := wreck.get_node("GuestBoardingRamp") as Node3D
	boarding_ramp.rotation.x = deg_to_rad(18.4)
	_add_box("GuestCabinBackWall", Vector3(0.35, 1.66, -1.02), Vector3(3.25, 1.56, 0.14), Color("76534a"), true, wreck)
	_add_box("GuestCabinPortWall", Vector3(-1.2, 1.66, -0.12), Vector3(0.14, 1.56, 1.85), Color("76534a"), true, wreck)
	_add_box("GuestCabinStarboardWall", Vector3(1.9, 1.66, -0.12), Vector3(0.14, 1.56, 1.85), Color("76534a"), true, wreck)
	_add_box("GuestCabinEntryPort", Vector3(-1.15, 1.66, 0.76), Vector3(0.14, 1.56, 0.14), Color("76534a"), true, wreck)
	_add_box("GuestCabinEntryStarboard", Vector3(1.85, 1.66, 0.76), Vector3(0.14, 1.56, 0.14), Color("76534a"), true, wreck)
	_add_local_visual_box(wreck, "CabinCanopy", Vector3(0.15, 2.74, -0.12), Vector3(3.65, 0.18, 2.15), Color("8b4d47"))
	_add_local_visual_box(wreck, "GuestCabinRug", Vector3(0.15, 0.9, 0.05), Vector3(1.7, 0.035, 1.15), Color("8e594d"))
	_add_local_visual_box(wreck, "GuestBerthFrame", Vector3(-0.35, 0.98, -0.15), Vector3(1.1, 0.18, 0.68), Color("60423a"))
	_add_local_visual_box(wreck, "GuestBerthMattress", Vector3(-0.35, 1.1, -0.15), Vector3(1.02, 0.12, 0.62), Color("d4c5a3"))
	_add_local_visual_box(wreck, "GuestBerthQuilt", Vector3(-0.23, 1.18, -0.13), Vector3(0.67, 0.045, 0.58), Color("78918a"))
	_add_local_visual_box(wreck, "GuestBerthPillow", Vector3(-0.67, 1.19, -0.17), Vector3(0.27, 0.08, 0.36), Color("e4d7bd"))
	_add_local_visual_box(wreck, "GuestRegistryDesk", Vector3(1.22, 1.15, 0.33), Vector3(0.72, 0.52, 0.4), Color("64463c"))
	_add_local_visual_box(wreck, "GuestRegistryBook", Vector3(1.22, 1.43, 0.33), Vector3(0.38, 0.055, 0.28), Color("d2ae73"))
	var guest_bead := MeshInstance3D.new()
	guest_bead.name = "GuestPassBead"
	var guest_bead_mesh := SphereMesh.new()
	guest_bead_mesh.radius = 0.15
	guest_bead_mesh.height = 0.26
	guest_bead.mesh = guest_bead_mesh
	guest_bead.position = JADE_GUEST_BEAD_POSITION
	var guest_bead_material := _material(Color("75c4b7"))
	guest_bead_material.emission_enabled = true
	guest_bead_material.emission = Color("4eb7ab")
	guest_bead_material.emission_energy_multiplier = 0.65
	guest_bead.material_override = guest_bead_material
	wreck.add_child(guest_bead)
	var guest_lantern := OmniLight3D.new()
	guest_lantern.name = "GuestCabinLamp"
	guest_lantern.position = Vector3(0.35, 2.0, -0.84)
	guest_lantern.light_color = Color("ffc984")
	guest_lantern.light_energy = 0.16
	guest_lantern.omni_range = 4.0
	wreck.add_child(guest_lantern)
	var guest_cabin_sign := Label3D.new()
	guest_cabin_sign.name = "GuestCabinName"
	guest_cabin_sign.text = "听潮舱 · 旧帆留客"
	guest_cabin_sign.position = Vector3(0.35, 2.32, -0.91)
	guest_cabin_sign.font_size = 18
	guest_cabin_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	guest_cabin_sign.modulate = Color("f3dcb0")
	wreck.add_child(guest_cabin_sign)
	_add_local_visual_box(wreck, "BrassInlayPort", Vector3(-2.7, 0.91, 1.31), Vector3(1.35, 0.055, 0.06), Color("d0b379"))
	_add_local_visual_box(wreck, "BrassInlayStarboard", Vector3(2.7, 0.91, -1.31), Vector3(1.35, 0.055, 0.06), Color("d0b379"))
	for rib_index in range(5):
		var rib_x := -2.6 + float(rib_index) * 1.25
		_add_local_visual_cylinder(wreck, "BrokenRib%d" % rib_index, Vector3(rib_x, 1.12, -1.25), 0.09, 1.5, Color("69473c"))
	var leaning_mast := _add_local_visual_cylinder(wreck, "FallenMast", Vector3(-3.0, 1.55, -0.62), 0.11, 4.0, Color("705345"))
	leaning_mast.rotation.z = -0.62
	var glass := _add_local_visual_box(wreck, "JadeWindow", Vector3(0.35, 1.52, 0.83), Vector3(0.62, 0.42, 0.045), Color("6faaa0"))
	var glass_material := _material(Color("6faaa0"))
	glass_material.emission_enabled = true
	glass_material.emission = Color("4e8e84")
	glass_material.emission_energy_multiplier = 0.48
	glass.material_override = glass_material
	var lantern := _add_local_visual_box(wreck, "UnlitLantern", Vector3(2.85, 1.2, 0.45), Vector3(0.24, 0.42, 0.24), Color("9a7750"))
	lantern.rotation.z = 0.24
	var salvage_frame := Node3D.new()
	salvage_frame.name = "SalvageFrame"
	wreck.add_child(salvage_frame)
	_add_local_visual_box(salvage_frame, "GoldRib", Vector3(0.0, 0.0, 0.0), Vector3(1.6, 0.12, 0.12), Color("e0bd7c"))
	_add_local_visual_box(salvage_frame, "JadeJoint", Vector3(-0.72, 0.03, 0.0), Vector3(0.22, 0.22, 0.22), Color("84a89c"))
	_add_local_visual_box(salvage_frame, "SplitRib", Vector3(0.68, -0.06, 0.02), Vector3(0.58, 0.1, 0.1), Color("8d664e"))
	salvage_frame.position = Vector3(-0.55, 1.02, 1.56)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "琼华舫遗址 · 阵灯尽熄" if not jade_sail_ark_searched else "琼华舫遗址 · 舱骨已取"
	sign.position = Vector3(0.0, 3.15, 0.0)
	sign.font_size = 28
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("f0d5a4")
	wreck.add_child(sign)
	interactables.append({"id": "jade_sail_ark", "node": wreck, "amount": 0})
	_add_interactable("jade_sail_cargo", "琼华舫货舱", Vector3(2.3, 0.92, 0.62), wreck)
	_add_jade_sail_keeper()
	_refresh_jade_sail_guest_visuals()
	if jade_sail_ark_searched:
		_refresh_jade_sail_ark_visual()


func _refresh_jade_sail_ark_visual() -> void:
	var wreck := get_node_or_null("JadeSailArk") as Node3D
	if wreck == null:
		return
	var frame := wreck.get_node_or_null("SalvageFrame")
	if frame:
		frame.queue_free()
	if jade_sail_ark_searched:
		var sign := wreck.get_node_or_null("Name") as Label3D
		if sign:
				sign.text = "琼华产业舫 · 船体自有" if jade_sail_vessel_title_owned else "琼华产业舫 · 收编经营" if jade_sail_industry_acquired else "琼华客舫 · 合作试营" if jade_sail_industry_active else "琼华舫遗址 · 迎客舱骨已取"
	if jade_sail_industry_active:
		if wreck.get_node_or_null("RepairedTradeApron") == null:
			_add_local_visual_box(wreck, "RepairedTradeApron", Vector3(-2.48, 0.91, 0.0), Vector3(1.42, 0.11, 2.38), Color("c59b63"))
		if wreck.get_node_or_null("WarmServiceLamp") == null:
			var glow := OmniLight3D.new()
			glow.name = "WarmServiceLamp"
			glow.position = Vector3(2.85, 1.46, 0.45)
			glow.light_color = Color("ffca83")
			glow.light_energy = 0.55
			glow.omni_range = 5.5
			wreck.add_child(glow)
		var cargo_marker := wreck.get_node_or_null("jade_sail_cargoMarker") as Node3D
		if cargo_marker:
			var cargo_sign := cargo_marker.get_node_or_null("Name") as Label3D
			if cargo_sign:
				cargo_sign.text = "琼华货舱 · 鲜贝 %d / 木料 %d" % [jade_sail_industry_shellfish, jade_sail_industry_wood]
		_update_jade_sail_keeper_nameplate()
	_refresh_jade_sail_guest_visuals()


func _refresh_jade_sail_guest_visuals() -> void:
	var wreck := get_node_or_null("JadeSailArk") as Node3D
	if wreck == null:
		return
	var bead := wreck.get_node_or_null("GuestPassBead") as MeshInstance3D
	var bead_visible := jade_sail_ark_searched and not jade_sail_guest_bead_collected and not jade_sail_guest_pass_active and not jade_sail_guest_stay_used
	if bead:
		bead.visible = bead_visible
	var bead_marker_name := "jade_sail_guest_beadMarker"
	var bead_marker := wreck.get_node_or_null(bead_marker_name) as Node3D
	if jade_sail_ark_searched and wreck.get_node_or_null("jade_sail_guest_registryMarker") == null:
		_add_interactable("jade_sail_guest_registry", "客居名册", JADE_GUEST_REGISTRY_POSITION, wreck)
	if jade_sail_ark_searched and wreck.get_node_or_null("jade_sail_guest_berthMarker") == null:
		_add_interactable("jade_sail_guest_berth", "听潮客榻", JADE_GUEST_BERTH_POSITION, wreck)
	if bead_visible and bead_marker == null:
		_add_interactable("jade_sail_guest_bead", "琉璃舷珠", JADE_GUEST_BEAD_POSITION, wreck)
	elif not bead_visible and bead_marker != null:
		for index in range(interactables.size() - 1, -1, -1):
			if str(interactables[index].get("id", "")) == "jade_sail_guest_bead":
				interactables.remove_at(index)
		bead_marker.queue_free()
	var registry_marker := wreck.get_node_or_null("jade_sail_guest_registryMarker") as Node3D
	var registry_sign := registry_marker.get_node_or_null("Name") as Label3D if registry_marker else null
	if registry_sign:
		registry_sign.text = "客居名册 · 留宿帖待用" if jade_sail_guest_pass_active else "客居名册 · 已留宿" if jade_sail_guest_stay_used else "客居名册 · 交还琉璃舷珠" if jade_sail_guest_bead_collected else "客居名册"
	var berth_marker := wreck.get_node_or_null("jade_sail_guest_berthMarker") as Node3D
	var berth_sign := berth_marker.get_node_or_null("Name") as Label3D if berth_marker else null
	if berth_sign:
		berth_sign.text = "听潮客榻 · 留宿帖待用" if jade_sail_guest_pass_active else "听潮客榻 · 已留宿" if jade_sail_guest_stay_used else "听潮客榻 · 需客签"
	var guest_lamp := wreck.get_node_or_null("GuestCabinLamp") as OmniLight3D
	if guest_lamp:
		guest_lamp.light_energy = 0.68 if jade_sail_guest_pass_active or jade_sail_guest_stay_used else 0.16
	var cabin_sign := wreck.get_node_or_null("GuestCabinName") as Label3D
	if cabin_sign:
		cabin_sign.text = "听潮舱 · 留宿帖待用" if jade_sail_guest_pass_active else "听潮舱 · 灯火未燃" if not jade_sail_guest_stay_used else "听潮舱 · 留下一夜暖意"


func _add_pressure_wreck(position: Vector3) -> void:
	var wreck := Node3D.new()
	wreck.name = "PressureWreck"
	wreck.position = position
	wreck.rotation.y = -0.28
	add_child(wreck)
	# A compact mechanical-era wreck contrasts with the lacquered Jade Sail without
	# borrowing a legacy chronicle's people, logos, or story facts.
	_add_local_visual_box(wreck, "BlackenedKeel", Vector3(0.0, 0.2, 0.0), Vector3(7.2, 0.42, 2.5), Color("3c403d"))
	_add_local_visual_box(wreck, "CopperDeck", Vector3(0.0, 0.48, 0.0), Vector3(5.8, 0.14, 2.15), Color("795d45"))
	_add_local_visual_box(wreck, "PressureCabin", Vector3(-0.5, 1.12, -0.12), Vector3(2.45, 1.08, 1.58), Color("52514a"))
	_add_local_visual_box(wreck, "CollapsedCanopy", Vector3(-0.48, 1.74, -0.2), Vector3(2.85, 0.16, 1.95), Color("66584a"))
	_add_local_visual_cylinder(wreck, "Boiler", Vector3(1.65, 0.9, -0.12), 0.63, 1.1, Color("7e5940"))
	_add_local_visual_cylinder(wreck, "BoilerCap", Vector3(1.65, 1.49, -0.12), 0.72, 0.12, Color("b08455"))
	var vent := _add_local_visual_cylinder(wreck, "BentVent", Vector3(1.65, 2.0, -0.12), 0.13, 1.1, Color("8f7452"))
	vent.rotation.z = 0.18
	_add_local_visual_box(wreck, "BrokenCondenser", Vector3(-2.0, 0.8, 0.62), Vector3(1.2, 0.68, 0.32), Color("586565"))
	for pipe_index in range(3):
		var pipe := _add_local_visual_cylinder(wreck, "CopperPipe%d" % pipe_index, Vector3(0.85 + float(pipe_index) * 0.28, 1.1 + float(pipe_index % 2) * 0.16, 0.88), 0.055, 1.05, Color("bd8755"))
		pipe.rotation.x = PI * 0.5
	var core := _add_local_visual_cylinder(wreck, "PressureCore", Vector3(1.65, 1.08, -0.12), 0.3, 0.52, Color("d18b52"))
	var core_material := _material(Color("d18b52"))
	core_material.emission_enabled = true
	core_material.emission = Color("d88348")
	core_material.emission_energy_multiplier = 1.1
	core.material_override = core_material
	var warm_glow := OmniLight3D.new()
	warm_glow.name = "PressureGlow"
	warm_glow.position = Vector3(1.65, 1.15, -0.12)
	warm_glow.light_color = Color("ef9d5e")
	warm_glow.light_energy = 0.6
	warm_glow.omni_range = 4.0
	wreck.add_child(warm_glow)
	var warning_ring := MeshInstance3D.new()
	warning_ring.name = "VentWarningRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.28
	ring_mesh.outer_radius = 0.36
	ring_mesh.ring_segments = 16
	ring_mesh.rings = 5
	warning_ring.mesh = ring_mesh
	warning_ring.position = Vector3(1.65, 0.12, -0.12)
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color("ff9b57")
	ring_material.emission_enabled = true
	ring_material.emission = Color("ff6d38")
	ring_material.emission_energy_multiplier = 1.4
	warning_ring.material_override = ring_material
	warning_ring.visible = false
	wreck.add_child(warning_ring)
	var steam_particles := GPUParticles3D.new()
	steam_particles.name = "SteamBurst"
	steam_particles.position = Vector3(1.65, 1.9, -0.12)
	steam_particles.amount = 36
	steam_particles.lifetime = 0.9
	steam_particles.explosiveness = 0.72
	steam_particles.one_shot = true
	steam_particles.emitting = false
	var steam_process := ParticleProcessMaterial.new()
	steam_process.direction = Vector3(0.0, 1.0, 0.0)
	steam_process.spread = 18.0
	steam_process.initial_velocity_min = 0.8
	steam_process.initial_velocity_max = 2.4
	steam_process.gravity = Vector3(0.0, 0.9, 0.0)
	steam_process.scale_min = 0.08
	steam_process.scale_max = 0.28
	steam_process.color = Color("d8e3dd")
	steam_particles.process_material = steam_process
	var steam_puff := SphereMesh.new()
	steam_puff.radius = 0.16
	steam_puff.height = 0.32
	steam_puff.radial_segments = 8
	steam_puff.rings = 4
	var steam_material := StandardMaterial3D.new()
	steam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	steam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam_material.albedo_color = Color("d8e3dd", 0.28)
	steam_puff.material = steam_material
	steam_particles.draw_pass_1 = steam_puff
	wreck.add_child(steam_particles)
	var marker := Node3D.new()
	marker.name = "PressureWreckInteractable"
	marker.position = position + Vector3(0.0, 0.55, 2.8)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "蒸潮机坞 · 锈汽未散"
	sign.position.y = 0.85
	sign.font_size = 26
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("f1d0a2")
	marker.add_child(sign)
	add_child(marker)
	interactables.append({"id": "pressure_wreck", "node": marker, "amount": 0})
	if pressure_wreck_searched:
		_refresh_pressure_wreck_visual()
	else:
		_refresh_pressure_vent_visual()


func _refresh_pressure_wreck_visual() -> void:
	var wreck := get_node_or_null("PressureWreck") as Node3D
	if wreck:
		var core := wreck.get_node_or_null("PressureCore")
		if core:
			core.queue_free()
		var glow := wreck.get_node_or_null("PressureGlow") as OmniLight3D
		if glow:
			glow.light_energy = 0.16
			glow.omni_range = 1.6
	var marker := get_node_or_null("PressureWreckInteractable") as Node3D
	var sign := marker.get_node_or_null("Name") as Label3D if marker else null
	if sign:
		sign.text = "蒸潮机坞 · 核心已回收"
	_refresh_pressure_vent_visual()


func _add_jade_sail_keeper() -> void:
	var marker := Node3D.new()
	marker.name = "JadeSailKeeper"
	marker.position = JADE_INDUSTRY_HOME_POSITION
	var figure := _build_graybox_character("RuanQingyiFigure", Color("8b7466"), Color("40363b"))
	figure.position.y = 0.0
	marker.add_child(figure)
	jade_sail_keeper_body = figure
	var ledger := MeshInstance3D.new()
	ledger.name = "CargoLedger"
	var ledger_mesh := BoxMesh.new()
	ledger_mesh.size = Vector3(0.26, 0.3, 0.08)
	ledger.mesh = ledger_mesh
	ledger.position = Vector3(0.42, 0.76, 0.08)
	ledger.rotation.z = -0.12
	ledger.material_override = _material(Color("d1ad72"))
	marker.add_child(ledger)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.position = Vector3(0.0, 1.6, 0.0)
	sign.font_size = 27
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("fff0c9")
	marker.add_child(sign)
	add_child(marker)
	jade_sail_keeper_marker = marker
	jade_sail_keeper_action = "守着旧舫"
	_update_jade_sail_keeper_nameplate()
	interactables.append({"id": "jade_sail_keeper", "node": marker, "amount": 0})


func _add_interactable(id: String, title: String, position: Vector3, parent: Node) -> void:
	var marker := Node3D.new()
	marker.name = "%sMarker" % id
	marker.position = position
	if id == "resident":
		_add_traveler_placeholder(marker)
	elif id == "sailmaker":
		_add_sailmaker_placeholder(marker)
	elif id in ["jade_sail_guest_bead", "jade_sail_guest_registry", "jade_sail_guest_berth"]:
		pass
	else:
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.06
		pole_mesh.bottom_radius = 0.08
		pole_mesh.height = 1.0
		pole.mesh = pole_mesh
		pole.position.y = 0.5
		pole.material_override = _material(Color("e0ca89"))
		marker.add_child(pole)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = title
	sign.position = Vector3(0, 1.25, 0)
	sign.font_size = 36
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("fff0c9")
	marker.add_child(sign)
	if parent:
		parent.add_child(marker)
	else:
		add_child(marker)
	interactables.append({"id": id, "node": marker, "amount": 0})
	if id == "resident" and traveler_boarded:
		_set_traveler_boarded()
	elif id == "sailmaker" and sailmaker_boarded:
		_set_sailmaker_boarded()


func _add_traveler_placeholder(parent: Node3D) -> void:
	# Companion uses the same readable 3D game-piece language, with a distinct traveler's palette.
	var figure := _build_graybox_character("TidekeeperFigure", Color("8b6260"), Color("44343b"))
	figure.position.y = 0.0
	parent.add_child(figure)
	traveler_body = figure


func _add_sailmaker_placeholder(parent: Node3D) -> void:
	# Original NPC in the opening slice; no legacy-volume identity is implied.
	var figure := _build_graybox_character("SailmakerFigure", Color("657e76"), Color("34343a"))
	figure.position.y = 0.0
	parent.add_child(figure)
	sailmaker_body = figure
	var cloth_bundle := MeshInstance3D.new()
	cloth_bundle.name = "OldSailBundle"
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = Vector3(0.38, 0.22, 0.28)
	cloth_bundle.mesh = cloth_mesh
	cloth_bundle.position = Vector3(0.42, 0.34, 0.02)
	cloth_bundle.rotation.z = -0.18
	cloth_bundle.material_override = _material(Color("b29b77"))
	parent.add_child(cloth_bundle)
	var spool := MeshInstance3D.new()
	spool.name = "ThreadSpool"
	var spool_mesh := CylinderMesh.new()
	spool_mesh.top_radius = 0.06
	spool_mesh.bottom_radius = 0.06
	spool_mesh.height = 0.14
	spool.mesh = spool_mesh
	spool.position = Vector3(-0.4, 0.18, 0.05)
	spool.material_override = _material(Color("c8aa78"))
	parent.add_child(spool)


func _add_safe_channel_mark() -> void:
	if get_node_or_null("SafeChannelMark") != null:
		return
	var marker := Node3D.new()
	marker.name = "SafeChannelMark"
	marker.position = Vector3(10.5, 0.08, -4.2)
	var stake := MeshInstance3D.new()
	var stake_mesh := CylinderMesh.new()
	stake_mesh.top_radius = 0.025
	stake_mesh.bottom_radius = 0.04
	stake_mesh.height = 1.0
	stake.mesh = stake_mesh
	stake.position.y = 0.5
	stake.material_override = _material(Color("705c48"))
	marker.add_child(stake)
	var cloth := MeshInstance3D.new()
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = Vector3(0.52, 0.2, 0.035)
	cloth.mesh = cloth_mesh
	cloth.position = Vector3(0.23, 0.82, 0)
	cloth.material_override = _material(Color("d7c9a5"))
	marker.add_child(cloth)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "退潮安全沟"
	sign.position = Vector3(0, 1.25, 0)
	sign.font_size = 26
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("fff0c9")
	marker.add_child(sign)
	add_child(marker)
	interactables.append({"id": "safe_channel", "node": marker, "amount": 0})


func _add_raft_lantern(parent: Node3D) -> void:
	var marker := Node3D.new()
	marker.name = "LanternMarker"
	marker.position = Vector3(-2.15, 0.12, -0.9)
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.045
	post_mesh.bottom_radius = 0.07
	post_mesh.height = 0.92
	post.mesh = post_mesh
	post.position.y = 0.46
	post.material_override = _material(Color("594632"))
	marker.add_child(post)
	var lamp := MeshInstance3D.new()
	lamp.name = "LampBulb"
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.18
	lamp_mesh.height = 0.28
	lamp.mesh = lamp_mesh
	lamp.position = Vector3(0, 0.92, 0)
	var lamp_material := _material(Color("ffc778"))
	lamp_material.emission_enabled = true
	lamp_material.emission = Color("ffae54")
	lamp_material.emission_energy_multiplier = 1.3
	lamp.material_override = lamp_material
	marker.add_child(lamp)
	var light := OmniLight3D.new()
	light.name = "RaftLanternLight"
	light.position = Vector3(0, 0.9, 0)
	light.light_color = Color("ffbd71")
	light.light_energy = 0.65
	light.omni_range = 5.0
	marker.add_child(light)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "旧灯 · 回木筏取暖"
	sign.position = Vector3(0, 1.35, 0)
	sign.font_size = 26
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("fff0c9")
	marker.add_child(sign)
	parent.add_child(marker)
	interactables.append({"id": "lantern", "node": marker, "amount": 0})


func _add_distant_warning(position: Vector3) -> void:
	var ruin := Node3D.new()
	ruin.name = "ShoreRuin"
	ruin.position = position
	_add_local_box(ruin, "RuinPillarLeft", Vector3(-1.15, 1.0, 0), Vector3(0.48, 2.0, 0.52), Color("665c5a"), false)
	_add_local_box(ruin, "RuinPillarRight", Vector3(1.15, 0.72, 0), Vector3(0.48, 1.45, 0.52), Color("665c5a"), false)
	_add_local_box(ruin, "RuinLintel", Vector3(0, 2.0, 0), Vector3(2.7, 0.42, 0.6), Color("71625b"), false)
	_add_local_box(ruin, "RuinBrokenStone", Vector3(-1.9, 0.24, 0.85), Vector3(1.2, 0.48, 0.8), Color("554d4c"), false)
	var fragment := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	fragment.mesh = mesh
	fragment.position = Vector3(0, 0.42, 0)
	var fragment_material := _material(Color("91c8c1"))
	fragment_material.emission_enabled = true
	fragment_material.emission = Color("62a79e")
	fragment_material.emission_energy_multiplier = 0.55
	fragment.material_override = fragment_material
	ruin.add_child(fragment)
	var glint := OmniLight3D.new()
	glint.position = Vector3(0, 0.55, 0)
	glint.light_color = Color("75b9ad")
	glint.light_energy = 0.22
	glint.omni_range = 2.8
	ruin.add_child(glint)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "遗迹 · 风声像裂帛"
	sign.position = Vector3(0, 2.55, 0)
	sign.font_size = 30
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("e9b6a2")
	ruin.add_child(sign)
	add_child(ruin)
	interactables.append({"id": "ruin", "node": ruin, "amount": 0})


func _add_reef_surge_warning() -> void:
	var marker := Node3D.new()
	marker.name = "ReefSurgeChannelWarning"
	marker.position = Vector3(REEF_SURGE_CENTER.x, 0.06, REEF_SURGE_CENTER.y)
	for index in range(3):
		var foam := MeshInstance3D.new()
		foam.name = "FoamLine%d" % index
		var foam_mesh := BoxMesh.new()
		foam_mesh.size = Vector3(0.86, 0.035, 0.18)
		foam.mesh = foam_mesh
		foam.position = Vector3(float(index - 1) * 0.54, -1.02, float(index - 1) * 0.38)
		foam.rotation.y = -0.55
		var foam_material := _material(Color("d6d6c4"))
		foam_material.emission_enabled = true
		foam_material.emission = Color("89b9b8")
		foam_material.emission_energy_multiplier = 0.2
		foam.material_override = foam_material
		marker.add_child(foam)
	var warning_stake := MeshInstance3D.new()
	var stake_mesh := CylinderMesh.new()
	stake_mesh.top_radius = 0.035
	stake_mesh.bottom_radius = 0.055
	stake_mesh.height = 0.8
	warning_stake.mesh = stake_mesh
	warning_stake.position = Vector3(-1.15, 0.4, 1.0)
	warning_stake.material_override = _material(Color("725348"))
	marker.add_child(warning_stake)
	var warning_cloth := MeshInstance3D.new()
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = Vector3(0.42, 0.18, 0.035)
	warning_cloth.mesh = cloth_mesh
	warning_cloth.position = Vector3(-0.92, 0.63, 1.0)
	warning_cloth.material_override = _material(Color("d58d65"))
	marker.add_child(warning_cloth)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "碎浪水道 · 沿礁脊可绕行"
	sign.position = Vector3(0.0, 1.18, 1.0)
	sign.font_size = 28
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("f1d9b4")
	marker.add_child(sign)
	add_child(marker)


func _add_reef_beast() -> void:
	var beast := Node3D.new()
	beast.name = "ReefBeast"
	beast.position = Vector3(REEF_BEAST_CENTER.x, 0.16, REEF_BEAST_CENTER.y)
	var shell := MeshInstance3D.new()
	shell.mesh = SphereMesh.new()
	shell.scale = Vector3(0.88, 0.48, 0.72)
	shell.position = Vector3(0.0, 0.46, 0.05)
	shell.material_override = _material(Color("66584b"))
	beast.add_child(shell)
	var head := MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	head.scale = Vector3(0.44, 0.35, 0.42)
	head.position = Vector3(0.0, 0.36, -0.63)
	head.material_override = _material(Color("8e7660"))
	beast.add_child(head)
	for side in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		var horn_mesh := CylinderMesh.new()
		horn_mesh.top_radius = 0.015
		horn_mesh.bottom_radius = 0.12
		horn_mesh.height = 0.42
		horn.mesh = horn_mesh
		horn.position = Vector3(side * 0.28, 0.72, -0.77)
		horn.rotation_degrees.x = -24.0
		horn.rotation_degrees.z = side * -20.0
		horn.material_override = _material(Color("c5a578"))
		beast.add_child(horn)
		var eye := MeshInstance3D.new()
		eye.mesh = SphereMesh.new()
		eye.scale = Vector3(0.09, 0.08, 0.06)
		eye.position = Vector3(side * 0.29, 0.42, -0.92)
		var eye_material := _material(Color("e4bd70"))
		eye_material.emission_enabled = true
		eye_material.emission = Color("b58a3e")
		eye_material.emission_energy_multiplier = 0.25
		eye.material_override = eye_material
		beast.add_child(eye)
	for leg_position in [Vector3(-0.55, 0.17, -0.35), Vector3(0.55, 0.17, -0.35), Vector3(-0.55, 0.17, 0.42), Vector3(0.55, 0.17, 0.42)]:
		var leg := MeshInstance3D.new()
		leg.mesh = SphereMesh.new()
		leg.scale = Vector3(0.28, 0.17, 0.34)
		leg.position = leg_position
		leg.material_override = _material(Color("554b43"))
		beast.add_child(leg)
	var beast_name := Label3D.new()
	beast_name.name = "Name"
	beast_name.text = "礁背兽 · 临时灰盒"
	beast_name.position = Vector3(0.0, 1.28, 0.0)
	beast_name.font_size = 24
	beast_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	beast_name.modulate = Color("d6c19a")
	beast.add_child(beast_name)
	add_child(beast)
	reef_beast_marker = beast

	var warning := Node3D.new()
	warning.name = "ReefBeastWarning"
	warning.position = Vector3(REEF_BEAST_CENTER.x + 1.25, 0.06, REEF_BEAST_CENTER.y + 0.4)
	for index in range(3):
		var track := MeshInstance3D.new()
		track.mesh = SphereMesh.new()
		track.scale = Vector3(0.17, 0.025, 0.34)
		track.position = Vector3(float(index - 1) * 0.42, -0.01, float(index % 2) * 0.48)
		track.rotation.y = float(index - 1) * 0.35
		track.material_override = _material(Color("4b4138"))
		warning.add_child(track)
	var warning_sign := Label3D.new()
	warning_sign.name = "Name"
	warning_sign.text = "碎壳拖痕 · 礁背兽出没"
	warning_sign.position = Vector3(0.0, 0.82, 0.52)
	warning_sign.font_size = 25
	warning_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	warning_sign.modulate = Color("e8c69e")
	warning.add_child(warning_sign)
	add_child(warning)
	reef_beast_warning = warning
	_refresh_reef_beast_visual()


func _add_box(id: String, position: Vector3, size: Vector3, color: Color, solid: bool, parent: Node = null) -> void:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.name = id
	body.position = position
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = _material(color)
	body.add_child(visual)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	if parent:
		parent.add_child(body)
	else:
		add_child(body)


func _ark_node(path: String) -> Node:
	return ark_root.get_node_or_null(path) if ark_root else null


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.84
	return mat


func _preview_material(color: Color) -> StandardMaterial3D:
	var mat := _material(color)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.42
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _opening_objective_hint() -> String:
	if building_mode:
		return "选择避风棚落点；要搭建，木料至少 3 块。"
	if weather_phase == WeatherPhase.STORM:
		if not shelter_built:
			return "风雨正急，眼下还没有避风棚；留在稳妥处或继续探索，按 R 等雨势过去。雨后先搭棚。"
		return "风雨正急。靠近避风棚避险，或继续探索；按 R 等待雨势过去。"
	if shelter_roof_damaged or raft_edge_damaged:
		if wood > 0:
			return "回木筏与家园交互，修复受损处（每处 1 木）。"
		return "先找木料，再回家修复受损的棚顶或筏舷。"
	if not shelter_built:
		if wood < BUILD_COST:
			var carried_shortage := BUILD_COST - wood
			if stored_wood >= carried_shortage:
				return "从储物箱取出全部 %d 块木料（多余可留作扩建），再回木筏搭起避风棚。" % stored_wood
			if stored_wood > 0:
				return "还需 %d 块木料；储物箱里另有 %d 块，凑齐后取出再搭避风棚。" % [carried_shortage - stored_wood, stored_wood]
			return "收集 %d 块漂木；凑够 3 块后，回木筏搭起避风棚。" % carried_shortage
		return "回木筏选择基础避风棚模板，或按 B 自由搭建。"
	if weather_phase == WeatherPhase.AFTER:
		if not resident_met:
			return "风雨已过。沿岸寻找守潮人，听听她接下来的打算。"
		if not traveler_boarded:
			return "与守潮人交谈，决定是否邀请她登舟。"
		if not sailmaker_met:
			return "沿岸寻找缝帆人；结伴后可让居民外出采集。"
		return "打开潮痕图规划探索；岛外有船骸、独特资源与新蓝图。"
	if not resident_met:
		return "避风棚已就位。可去见守潮人，也可继续探索，再按 R 推进天气。"
	if not traveler_boarded:
		return "与守潮人交谈，决定是否邀请她登舟；风雨前仍可继续准备。"
	return "风雨将至。检查避风棚与物资，准备好后按 R 推进天气。"


func _update_hud() -> void:
	if hud:
		var weather_labels: Array[String] = ["风雨将至", "风雨正急", "雨后"]
		var weather_text: String = "下一场风雨已预报" if _storm_forecast_due() else weather_labels[weather_phase]
		var damage_text := ""
		if shelter_roof_damaged:
			damage_text += "棚顶松脱 "
		if raft_edge_damaged:
			damage_text += "筏舷松动"
		var exposure_level := _effective_cold_exposure_level()
		var exposure_labels := ["", "轻寒", "重寒", "彻骨"]
		var exposure_multipliers := [1.0, 0.62, 0.42, 0.28]
		var exposure_text := " · %s %d/3（步速 %d%%）" % [exposure_labels[exposure_level], exposure_level, roundi(float(exposure_multipliers[exposure_level]) * 100.0)] if exposure_level > 0 else ""
		var swim_text := " · 游泳" if is_swimming else ""
		var refuge_text := "仙舟庇护圈 %.0fm%s · %s" % [_current_refuge_radius(), "（阵灯增幅）" if lantern_tuned else "", "圈内" if _is_within_ark_refuge() else "圈外 %.0fm" % _distance_to_ark()]
		var shelter_status := "避风棚已建" if shelter_built else "避风棚未建"
		var objective_text := _opening_objective_hint()
		hud.text = "第 %d 天·%s  ·  生命 %d/%d\n木料 %d（随身）+ %d（储存） · 鲜贝 %d · 热汤 %d%s%s\n%s  ·  %s%s\n避难者 %d/%d  ·  %s\n当前目标：%s" % [day_count, _day_period_label(), player_health, PLAYER_MAX_HEALTH, wood, stored_wood, raw_shellfish, stew_servings, exposure_text, swim_text, weather_text, shelter_status, (" · " + damage_text) if not damage_text.is_empty() else "", _resident_occupancy(), _resident_capacity(), refuge_text, objective_text]
		if _resident_occupancy() > 0:
			hud.text += "\n居民采集偏好：%s" % _resident_gather_policy_label()
		if reef_beast_spooked or reef_beast_defeated:
			var beast_status := "已击退" if reef_beast_defeated else "%d/%d" % [reef_beast_health, REEF_BEAST_MAX_HEALTH]
			hud.text += "\n远礁：礁背兽 %s · 礁壳 %d · 风撑 %s" % [beast_status, reef_shell_plates, "已安装" if reef_shell_brace_installed else "未安装"]
	if note:
		note.text = ("[搭建预览] " if building_mode else "") + message
		if raft_expansion_blueprint_button:
			raft_expansion_blueprint_button.disabled = not _has_blueprint("keel_deck_expansion") or raft_extension_built
			raft_expansion_blueprint_button.text = "蓝图册：龙骨扩甲 · 已学会" if _has_blueprint("keel_deck_expansion") else "蓝图册：龙骨扩甲 · 探索远礁沉筏解锁"
			if guest_cabin_blueprint_button:
				guest_cabin_blueprint_button.disabled = not _has_blueprint("tide_guest_cabin") or guest_cabin_built
				if guest_cabin_built:
					guest_cabin_blueprint_button.text = "蓝图册：听潮客舱 · 已建成"
				elif _has_blueprint("tide_guest_cabin"):
					guest_cabin_blueprint_button.text = "蓝图册：听潮客舱 · 3 木 + 1 舱骨（余 %d 木、%d 舱骨）" % [wood, guest_cabin_frames]
				else:
					guest_cabin_blueprint_button.text = "蓝图册：听潮客舱 · 探索琼华舫解锁"
			if reef_shell_brace_button:
				reef_shell_brace_button.disabled = not _has_blueprint("reef_shell_storm_brace") or reef_shell_brace_installed or not shelter_built or reef_shell_plates < 1 or wood < REEF_SHELL_BRACE_WOOD_COST
				if reef_shell_brace_installed:
					reef_shell_brace_button.text = "蓝图册：礁壳风撑 · 已安装"
				elif _has_blueprint("reef_shell_storm_brace"):
					reef_shell_brace_button.text = "蓝图册：礁壳风撑 · %d 木 + %d 礁壳（余 %d 木、%d 礁壳）" % [REEF_SHELL_BRACE_WOOD_COST, 1, wood, reef_shell_plates]
				else:
					reef_shell_brace_button.text = "蓝图册：礁壳风撑 · 击退远礁礁背兽解锁"


func _set_weather_visuals() -> void:
	var storm_active := weather_phase == WeatherPhase.STORM
	if storm_overlay:
		storm_overlay.visible = storm_active
	var daylight := _daylight_profile()
	var weather_blend := 0.0
	var ambient_weather_tint := Color.WHITE
	var sky_weather_top := Color.WHITE
	var sky_weather_horizon := Color.WHITE
	var sun_weather_tint := Color.WHITE
	var ambient_energy_scale := 1.0
	var sun_energy_scale := 1.0
	match weather_phase:
		WeatherPhase.FORECAST:
			weather_blend = 0.22
			ambient_weather_tint = Color("a8c1c7")
			sky_weather_top = Color("547487")
			sky_weather_horizon = Color("b9c2bd")
			sun_weather_tint = Color("d8d7cd")
			ambient_energy_scale = 0.88
			sun_energy_scale = 0.76
		WeatherPhase.STORM:
			weather_blend = 0.72
			ambient_weather_tint = Color("566a7b")
			sky_weather_top = Color("263747")
			sky_weather_horizon = Color("58666e")
			sun_weather_tint = Color("8192a0")
			ambient_energy_scale = 0.58
			sun_energy_scale = 0.18
		WeatherPhase.AFTER:
			weather_blend = 0.14
			ambient_weather_tint = Color("b8a68e")
			sky_weather_top = Color("7c9ba4")
			sky_weather_horizon = Color("d7c6a6")
			sun_weather_tint = Color("f1bb83")
			ambient_energy_scale = 0.94
			sun_energy_scale = 0.82
	var base_ambient: Color = daylight["ambient"]
	var base_sky_top: Color = daylight["sky_top"]
	var base_sky_horizon: Color = daylight["sky_horizon"]
	var base_ground: Color = daylight["ground"]
	var base_sun_color: Color = daylight["sun_color"]
	var base_sun_rotation: Vector3 = daylight["sun_rotation"]
	if weather_environment:
		weather_environment.ambient_light_color = base_ambient.lerp(ambient_weather_tint, weather_blend)
		weather_environment.ambient_light_energy = float(daylight["ambient_energy"]) * ambient_energy_scale
	if sky_material:
		sky_material.sky_top_color = base_sky_top.lerp(sky_weather_top, weather_blend)
		sky_material.sky_horizon_color = base_sky_horizon.lerp(sky_weather_horizon, weather_blend)
		sky_material.ground_bottom_color = base_ground.lerp(ambient_weather_tint.darkened(0.35), weather_blend)
		sky_material.ground_horizon_color = base_sky_horizon.lerp(sky_weather_horizon.darkened(0.12), weather_blend)
	if sun_light:
		sun_light.rotation_degrees = base_sun_rotation
		sun_light.light_energy = float(daylight["sun_energy"]) * sun_energy_scale
		sun_light.light_color = base_sun_color.lerp(sun_weather_tint, weather_blend)
	_update_lantern_lighting(storm_active)


func _update_lantern_lighting(storm_active: bool) -> void:
	var glow_strength := 0.12
	match day_period:
		DayPeriod.DAY:
			glow_strength = 0.04
		DayPeriod.EVENING:
			glow_strength = 0.72
		DayPeriod.NIGHT:
			glow_strength = 1.0
	if storm_active:
		glow_strength = maxf(glow_strength, 0.68)
	var raft_light := _ark_node("LanternMarker/RaftLanternLight") as OmniLight3D
	if raft_light:
		raft_light.light_energy = 0.65 * glow_strength
	var raft_bulb := _ark_node("LanternMarker/LampBulb") as MeshInstance3D
	var raft_bulb_material := raft_bulb.material_override as StandardMaterial3D if raft_bulb else null
	if raft_bulb_material:
		raft_bulb_material.emission_energy_multiplier = 1.3 * glow_strength
	var shelter_light := _ark_node("BuiltShelter/WarmLight") as OmniLight3D
	if shelter_light:
		shelter_light.light_energy = 0.9 * glow_strength
	var shelter_lamp_light := _ark_node("BuiltShelter/Lamp/LampGlow") as OmniLight3D
	if shelter_lamp_light:
		shelter_lamp_light.light_energy = 0.55 * glow_strength
	var shelter_bulb := _ark_node("BuiltShelter/Lamp/WarmGlass") as MeshInstance3D
	var shelter_bulb_material := shelter_bulb.material_override as StandardMaterial3D if shelter_bulb else null
	if shelter_bulb_material:
		shelter_bulb_material.emission_energy_multiplier = glow_strength


func _daylight_profile() -> Dictionary:
	match day_period:
		DayPeriod.MORNING:
			return _daylight_profile_for_morning()
		DayPeriod.DAY:
			return {
				"ambient": Color("9eb9bd"), "ambient_energy": 0.58,
				"sun_color": Color("fff0d3"), "sun_energy": 1.35,
				"sun_rotation": Vector3(-55.0, -28.0, 0.0),
				"sky_top": Color("387b9c"), "sky_horizon": Color("b9d9d9"), "ground": Color("526d70"),
			}
		DayPeriod.EVENING:
			return {
				"ambient": Color("b98d82"), "ambient_energy": 0.38,
				"sun_color": Color("ff9d6d"), "sun_energy": 0.62,
				"sun_rotation": Vector3(-8.0, 126.0, 0.0),
				"sky_top": Color("534b68"), "sky_horizon": Color("e58f69"), "ground": Color("625456"),
			}
		DayPeriod.NIGHT:
			return {
				"ambient": Color("35445f"), "ambient_energy": 0.22,
				"sun_color": Color("8097b9"), "sun_energy": 0.025,
				"sun_rotation": Vector3(5.0, 36.0, 0.0),
				"sky_top": Color("111b35"), "sky_horizon": Color("3e4a67"), "ground": Color("202d45"),
			}
	return _daylight_profile_for_morning()


func _daylight_profile_for_morning() -> Dictionary:
	return {
		"ambient": Color("a8c3ca"), "ambient_energy": 0.46,
		"sun_color": Color("ffd3a0"), "sun_energy": 0.82,
		"sun_rotation": Vector3(-18.0, -58.0, 0.0),
		"sky_top": Color("426d86"), "sky_horizon": Color("e3b992"), "ground": Color("556c70"),
	}


func _build_save_state() -> Dictionary:
	var position := Vector3(0, 1.1, 1.2)
	if player:
		position = player.position
	var traveler_position := Vector3(-1.0, 0.12, 0.85)
	if traveler_marker and is_instance_valid(traveler_marker):
		traveler_position = traveler_marker.global_position if resident_gather_pending and traveler_marker.is_inside_tree() else traveler_marker.position
	var sailmaker_position := Vector3(1.15, 0.12, 0.75)
	if sailmaker_marker and is_instance_valid(sailmaker_marker):
		sailmaker_position = sailmaker_marker.position
	var jade_keeper_position := JADE_INDUSTRY_HOME_POSITION
	if jade_sail_keeper_marker and is_instance_valid(jade_sail_keeper_marker):
		jade_keeper_position = jade_sail_keeper_marker.global_position if jade_sail_keeper_marker.is_inside_tree() else jade_sail_keeper_marker.position
	var ark_position := Vector3.ZERO
	if ark_root:
		ark_position = ark_root.global_position if ark_root.is_inside_tree() else ark_root.position
	return {
		"schema_version": 32,
		"day_count": day_count,
		"day_period": day_period,
		"wood": wood,
		"player_health": player_health,
		"raw_shellfish": raw_shellfish,
		"stew_servings": stew_servings,
		"shared_meal_day": shared_meal_day,
		"shared_meal_count": shared_meal_count,
		"shared_meal_gathering_pending": shared_meal_gathering_pending,
		"shared_meal_participants": shared_meal_participants.duplicate(),
		"resident_keepsake_present": resident_keepsake_present,
		"stored_wood": stored_wood,
		"shelter_built": shelter_built,
		"shelter_position": {"x": shelter_position.x, "y": shelter_position.y, "z": shelter_position.z},
		"storage_built": storage_built,
		"storage_position": {"x": storage_position.x, "y": storage_position.y, "z": storage_position.z},
		"workbench_built": workbench_built,
		"workbench_position": {"x": workbench_position.x, "y": workbench_position.y, "z": workbench_position.z},
		"keel_beams": keel_beams,
		"keel_wreck_searched": keel_wreck_searched,
		"learned_blueprint_ids": learned_blueprint_ids.duplicate(),
		"raft_extension_built": raft_extension_built,
		"guest_cabin_built": guest_cabin_built,
		"guest_cabin_frames": guest_cabin_frames,
		"jade_sail_ark_searched": jade_sail_ark_searched,
		"jade_sail_keeper_met": jade_sail_keeper_met,
		"jade_sail_guest_bead_collected": jade_sail_guest_bead_collected,
		"jade_sail_guest_pass_active": jade_sail_guest_pass_active,
		"jade_sail_guest_stay_used": jade_sail_guest_stay_used,
		"jade_sail_industry_active": jade_sail_industry_active,
		"jade_sail_industry_acquired": jade_sail_industry_acquired,
		"jade_sail_vessel_title_owned": jade_sail_vessel_title_owned,
		"jade_sail_industry_shellfish": jade_sail_industry_shellfish,
		"jade_sail_industry_wood": jade_sail_industry_wood,
		"jade_sail_industry_last_day": jade_sail_industry_last_day,
		"jade_sail_industry_pending": jade_sail_industry_pending,
		"jade_sail_industry_phase": jade_sail_industry_phase,
		"jade_sail_industry_resource": jade_sail_industry_resource,
		"jade_sail_industry_target_id": jade_sail_industry_target_id,
		"jade_sail_industry_target_position": _position_facts(jade_sail_industry_target_position),
		"jade_sail_industry_payload": jade_sail_industry_payload,
		"jade_sail_industry_pickup_remaining": jade_sail_industry_pickup_remaining,
		"jade_sail_industry_deliveries": jade_sail_industry_deliveries,
		"jade_sail_keeper_position": _position_facts(jade_keeper_position),
		"lantern_tuned": lantern_tuned,
		"resident_met": resident_met,
		"traveler_boarded": traveler_boarded,
		"traveler_position": {"x": traveler_position.x, "y": traveler_position.y, "z": traveler_position.z},
		"sailmaker_met": sailmaker_met,
		"sailmaker_boarded": sailmaker_boarded,
		"sailmaker_position": {"x": sailmaker_position.x, "y": sailmaker_position.y, "z": sailmaker_position.z},
		"sailmaker_joined_day": sailmaker_joined_day,
		"sailmaker_awning_raised": sailmaker_awning_raised,
		"sailmaker_guest_cabin_first_night": sailmaker_guest_cabin_first_night,
		"resident_repair_pending": resident_repair_pending,
		"resident_repair_part": resident_repair_part,
		"resident_gather_policy": resident_gather_policy,
		"resident_gather_pending": resident_gather_pending,
		"resident_gather_phase": resident_gather_phase,
		"resident_gather_target_id": resident_gather_target_id,
		"resident_gather_resource": resident_gather_resource,
		"resident_gather_target_position": _position_facts(resident_gather_target_position),
		"resident_gather_payload": resident_gather_payload,
		"resident_gather_pickup_remaining": resident_gather_pickup_remaining,
		"resident_gather_last_day": resident_gather_last_day,
		"weather_phase": weather_phase,
		"resolved_storm_count": resolved_storm_count,
		"next_storm_day": next_storm_day,
		"last_resolved_storm_facts": last_resolved_storm_facts.duplicate(true),
		"tidekeeper_last_storm_reflection": tidekeeper_last_storm_reflection,
		"rope_available": rope_available,
		"rope_use": rope_use,
		"shelter_roof_damaged": shelter_roof_damaged,
		"raft_edge_damaged": raft_edge_damaged,
		"safe_channel_marked": safe_channel_marked,
		"ruin_searched": ruin_searched,
		"cold_exposure": cold_exposure,
		"cold_exposure_level": _effective_cold_exposure_level(),
		"ancient_parts": ancient_parts,
		"tide_station_searched": tide_station_searched,
		"tide_relay_cores": tide_relay_cores,
		"tide_compass_tuned": tide_compass_tuned,
		"pressure_wreck_searched": pressure_wreck_searched,
		"pressure_cores": pressure_cores,
		"pressure_galley_built": pressure_galley_built,
		"reef_beast_spooked": reef_beast_spooked,
		"reef_beast_defeated": reef_beast_defeated,
		"reef_beast_health": reef_beast_health,
		"reef_shell_plates": reef_shell_plates,
		"reef_shell_brace_installed": reef_shell_brace_installed,
		"reef_beast_charge_remaining": reef_beast_charge_remaining,
		"collected_ids": collected_ids.duplicate(),
		"world_events": world_events.duplicate(true),
		"event_sequence": event_sequence,
		"player_position": {"x": position.x, "y": position.y, "z": position.z},
		"ark_position": {"x": ark_position.x, "y": ark_position.y, "z": ark_position.z},
		"ark_yaw": ark_root.rotation.y if ark_root else 0.0,
		"message": message,
	}


func _save_progress() -> bool:
	if save_service == null:
		return false
	var result: Dictionary = save_service.save_state(_build_save_state())
	return bool(result.get("ok", false))


func _load_progress() -> void:
	if save_service == null:
		return
	var result: Dictionary = save_service.load_state()
	if not bool(result.get("ok", false)):
		return
	var saved: Dictionary = result.get("state", {})
	var saved_schema := int(saved.get("schema_version", 0))
	if not saved_schema in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32]:
		return
	var ark_position_value = saved.get("ark_position", {})
	if saved_schema >= 12 and ark_position_value is Dictionary and ark_root:
		ark_root.position = Vector3(float(ark_position_value.get("x", 0.0)), float(ark_position_value.get("y", 0.0)), float(ark_position_value.get("z", 0.0)))
		ark_root.rotation.y = float(saved.get("ark_yaw", 0.0))
	world_events.clear()
	var saved_events = saved.get("world_events", [])
	if saved_events is Array:
		for event in saved_events:
			if event is Dictionary and event.has("sequence") and event.has("id"):
				world_events.append(event.duplicate(true))
	event_sequence = clampi(int(saved.get("event_sequence", world_events.size())), 0, 2147483647)
	if not world_events.is_empty():
		event_sequence = maxi(event_sequence, int(world_events.back().get("sequence", 0)))
	day_count = clampi(int(saved.get("day_count", 1)), 1, 9999)
	day_period = clampi(int(saved.get("day_period", DayPeriod.MORNING)), DayPeriod.MORNING, DayPeriod.NIGHT)
	wood = clampi(int(saved.get("wood", 1)), 0, 999)
	player_health = clampi(int(saved.get("player_health", PLAYER_MAX_HEALTH)), 1, PLAYER_MAX_HEALTH) if saved_schema >= 30 else PLAYER_MAX_HEALTH
	raw_shellfish = clampi(int(saved.get("raw_shellfish", 0)), 0, 999)
	stew_servings = clampi(int(saved.get("stew_servings", 0)), 0, 999)
	shared_meal_day = clampi(int(saved.get("shared_meal_day", 0)), 0, day_count)
	shared_meal_count = clampi(int(saved.get("shared_meal_count", 0)), 0, 9999)
	shared_meal_gathering_pending = saved_schema >= 32 and bool(saved.get("shared_meal_gathering_pending", false))
	shared_meal_participants.clear()
	var saved_meal_participants = saved.get("shared_meal_participants", [])
	if saved_meal_participants is Array:
		for participant in saved_meal_participants:
			var participant_id := str(participant)
			if ["player", "tidekeeper", "sailmaker"].has(participant_id) and not shared_meal_participants.has(participant_id):
				shared_meal_participants.append(participant_id)
	if shared_meal_gathering_pending and (not shared_meal_participants.has("player") or not shared_meal_participants.has("tidekeeper") or not shared_meal_participants.has("sailmaker")):
		shared_meal_gathering_pending = false
		shared_meal_participants.clear()
	resident_keepsake_present = bool(saved.get("resident_keepsake_present", shared_meal_count > 0))
	stored_wood = clampi(int(saved.get("stored_wood", 0)), 0, 9999)
	shelter_built = bool(saved.get("shelter_built", false))
	storage_built = bool(saved.get("storage_built", false))
	workbench_built = bool(saved.get("workbench_built", false))
	keel_beams = clampi(int(saved.get("keel_beams", 0)), 0, 1)
	keel_wreck_searched = bool(saved.get("keel_wreck_searched", false))
	learned_blueprint_ids = ["starter_shelter", "starter_home"]
	var saved_blueprints = saved.get("learned_blueprint_ids", [])
	if saved_blueprints is Array:
		for value in saved_blueprints:
			var blueprint_id := str(value)
			if ["starter_shelter", "starter_home", "keel_deck_expansion", "tide_compass", "tide_guest_cabin", "pressure_galley"].has(blueprint_id) or (saved_schema >= 30 and blueprint_id == "reef_shell_storm_brace"):
				if not learned_blueprint_ids.has(blueprint_id):
					learned_blueprint_ids.append(blueprint_id)
	# Old saves represented this unlock only with the wreck flag; preserve it as permanent knowledge.
	if keel_wreck_searched and not _has_blueprint("keel_deck_expansion"):
		learned_blueprint_ids.append("keel_deck_expansion")
	raft_extension_built = bool(saved.get("raft_extension_built", false))
	jade_sail_ark_searched = saved_schema >= 22 and bool(saved.get("jade_sail_ark_searched", false))
	jade_sail_keeper_met = saved_schema >= 24 and bool(saved.get("jade_sail_keeper_met", false))
	jade_sail_guest_stay_used = saved_schema >= 28 and bool(saved.get("jade_sail_guest_stay_used", false)) and jade_sail_keeper_met and jade_sail_ark_searched
	jade_sail_guest_pass_active = saved_schema >= 28 and bool(saved.get("jade_sail_guest_pass_active", false)) and jade_sail_keeper_met and jade_sail_ark_searched and not jade_sail_guest_stay_used
	jade_sail_guest_bead_collected = saved_schema >= 28 and bool(saved.get("jade_sail_guest_bead_collected", false)) and jade_sail_ark_searched and not jade_sail_guest_pass_active and not jade_sail_guest_stay_used
	jade_sail_industry_active = saved_schema >= 24 and bool(saved.get("jade_sail_industry_active", false)) and jade_sail_keeper_met and jade_sail_ark_searched
	jade_sail_industry_shellfish = clampi(int(saved.get("jade_sail_industry_shellfish", 0)), 0, 999) if jade_sail_industry_active else 0
	jade_sail_industry_last_day = clampi(int(saved.get("jade_sail_industry_last_day", 0)), 0, day_count) if jade_sail_industry_active else 0
	jade_sail_industry_deliveries = clampi(int(saved.get("jade_sail_industry_deliveries", 0)), 0, 9999) if jade_sail_industry_active else 0
	jade_sail_industry_acquired = saved_schema >= 25 and bool(saved.get("jade_sail_industry_acquired", false)) and jade_sail_industry_active and jade_sail_industry_deliveries >= 2
	jade_sail_vessel_title_owned = saved_schema >= 29 and bool(saved.get("jade_sail_vessel_title_owned", false)) and jade_sail_industry_acquired and jade_sail_industry_deliveries >= 3 and jade_sail_keeper_met and jade_sail_ark_searched
	jade_sail_industry_wood = clampi(int(saved.get("jade_sail_industry_wood", 0)), 0, 999) if jade_sail_industry_acquired else 0
	jade_sail_industry_pending = saved_schema >= 24 and bool(saved.get("jade_sail_industry_pending", false)) and jade_sail_industry_active
	jade_sail_industry_phase = str(saved.get("jade_sail_industry_phase", "")) if jade_sail_industry_pending else ""
	jade_sail_industry_resource = str(saved.get("jade_sail_industry_resource", "shellfish")) if jade_sail_industry_pending else ""
	jade_sail_industry_target_id = str(saved.get("jade_sail_industry_target_id", "")) if jade_sail_industry_pending else ""
	jade_sail_industry_payload = clampi(int(saved.get("jade_sail_industry_payload", 0)), 0, 999) if jade_sail_industry_pending else 0
	jade_sail_industry_pickup_remaining = clampf(float(saved.get("jade_sail_industry_pickup_remaining", JADE_INDUSTRY_PICKUP_SECONDS)), 0.0, JADE_INDUSTRY_PICKUP_SECONDS) if jade_sail_industry_pending else 0.0
	var industry_target_value = saved.get("jade_sail_industry_target_position", {})
	jade_sail_industry_target_position = Vector3(float(industry_target_value.get("x", 0.0)), float(industry_target_value.get("y", 0.12)), float(industry_target_value.get("z", 0.0))) if industry_target_value is Dictionary else Vector3.ZERO
	var jade_target_is_valid := jade_sail_industry_resource == "shellfish" and JADE_INDUSTRY_RESOURCE_IDS.has(jade_sail_industry_target_id)
	jade_target_is_valid = jade_target_is_valid or (jade_sail_industry_acquired and jade_sail_industry_resource == "wood" and JADE_INDUSTRY_WOOD_IDS.has(jade_sail_industry_target_id))
	if jade_sail_industry_pending and (not jade_target_is_valid or not ["outbound", "collecting", "returning"].has(jade_sail_industry_phase) or (jade_sail_industry_phase == "returning" and jade_sail_industry_payload <= 0) or (jade_sail_industry_phase != "returning" and jade_sail_industry_payload != 0)):
		jade_sail_industry_pending = false
		jade_sail_industry_phase = ""
		jade_sail_industry_resource = ""
		jade_sail_industry_target_id = ""
		jade_sail_industry_payload = 0
		jade_sail_industry_pickup_remaining = 0.0
	if jade_sail_ark_searched and not _has_blueprint("tide_guest_cabin"):
		learned_blueprint_ids.append("tide_guest_cabin")
	pressure_wreck_searched = saved_schema >= 26 and bool(saved.get("pressure_wreck_searched", false))
	if pressure_wreck_searched and not _has_blueprint("pressure_galley"):
		learned_blueprint_ids.append("pressure_galley")
	pressure_galley_built = saved_schema >= 26 and bool(saved.get("pressure_galley_built", false)) and pressure_wreck_searched and shelter_built and _has_blueprint("pressure_galley")
	pressure_cores = clampi(int(saved.get("pressure_cores", 0)), 0, 1) if pressure_wreck_searched and not pressure_galley_built else 0
	reef_beast_defeated = saved_schema >= 30 and bool(saved.get("reef_beast_defeated", false)) and _has_blueprint("reef_shell_storm_brace")
	reef_beast_spooked = saved_schema >= 27 and bool(saved.get("reef_beast_spooked", false)) and not reef_beast_defeated
	reef_beast_health = 0 if reef_beast_defeated else clampi(int(saved.get("reef_beast_health", REEF_BEAST_MAX_HEALTH)), 1, REEF_BEAST_MAX_HEALTH) if saved_schema >= 30 else REEF_BEAST_MAX_HEALTH
	reef_shell_brace_installed = saved_schema >= 30 and bool(saved.get("reef_shell_brace_installed", false)) and reef_beast_defeated and shelter_built
	reef_shell_plates = clampi(int(saved.get("reef_shell_plates", 0)), 0, 1) if reef_beast_defeated and not reef_shell_brace_installed else 0
	reef_beast_charge_remaining = clampf(float(saved.get("reef_beast_charge_remaining", 0.0)), 0.0, REEF_BEAST_WINDUP_SECONDS) if saved_schema >= 27 and not reef_beast_spooked and not reef_beast_defeated else 0.0
	guest_cabin_built = saved_schema >= 22 and bool(saved.get("guest_cabin_built", false)) and jade_sail_ark_searched and raft_extension_built and _has_blueprint("tide_guest_cabin")
	guest_cabin_frames = clampi(int(saved.get("guest_cabin_frames", 0)), 0, GUEST_CABIN_FRAME_COST) if saved_schema >= 22 and jade_sail_ark_searched else 0
	if guest_cabin_built:
		guest_cabin_frames = 0
	lantern_tuned = bool(saved.get("lantern_tuned", false))
	resident_met = bool(saved.get("resident_met", false))
	traveler_boarded = bool(saved.get("traveler_boarded", false))
	sailmaker_met = bool(saved.get("sailmaker_met", false))
	sailmaker_boarded = bool(saved.get("sailmaker_boarded", false)) and sailmaker_met and shelter_built
	sailmaker_joined_day = clampi(int(saved.get("sailmaker_joined_day", day_count)), 0, day_count) if sailmaker_boarded else 0
	sailmaker_awning_raised = bool(saved.get("sailmaker_awning_raised", false)) and sailmaker_boarded and shelter_built
	sailmaker_guest_cabin_first_night = saved_schema >= 23 and bool(saved.get("sailmaker_guest_cabin_first_night", false)) and sailmaker_boarded
	resident_repair_pending = bool(saved.get("resident_repair_pending", false))
	resident_repair_part = str(saved.get("resident_repair_part", ""))
	resident_gather_policy = str(saved.get("resident_gather_policy", "balanced")) if saved_schema >= 31 else "wood_first"
	if not ["wood_first", "shellfish_first", "balanced"].has(resident_gather_policy):
		resident_gather_policy = "wood_first" if saved_schema < 31 else "balanced"
	if resident_repair_pending and (not traveler_boarded or not ["raft_edge", "shelter_roof"].has(resident_repair_part)):
		resident_repair_pending = false
		resident_repair_part = ""
	resident_gather_pending = saved_schema >= 21 and bool(saved.get("resident_gather_pending", false))
	resident_gather_phase = str(saved.get("resident_gather_phase", "")) if resident_gather_pending else ""
	resident_gather_target_id = str(saved.get("resident_gather_target_id", "")) if resident_gather_pending else ""
	resident_gather_resource = str(saved.get("resident_gather_resource", "")) if resident_gather_pending else ""
	resident_gather_payload = clampi(int(saved.get("resident_gather_payload", 0)), 0, 999) if resident_gather_pending else 0
	resident_gather_pickup_remaining = clampf(float(saved.get("resident_gather_pickup_remaining", RESIDENT_AUTO_GATHER_PICKUP_SECONDS)), 0.0, RESIDENT_AUTO_GATHER_PICKUP_SECONDS) if resident_gather_pending else 0.0
	resident_gather_last_day = clampi(int(saved.get("resident_gather_last_day", 0)), 0, day_count)
	var gather_target_value = saved.get("resident_gather_target_position", {})
	resident_gather_target_position = Vector3(float(gather_target_value.get("x", 0.0)), float(gather_target_value.get("y", 0.15)), float(gather_target_value.get("z", 0.0))) if gather_target_value is Dictionary else Vector3.ZERO
	if resident_gather_pending and (not traveler_boarded or resident_gather_target_id.is_empty() or not ["outbound", "collecting", "returning"].has(resident_gather_phase) or not ["wood", "shellfish"].has(resident_gather_resource) or (resident_gather_phase == "returning" and resident_gather_payload <= 0) or (resident_gather_phase != "returning" and resident_gather_payload != 0)):
		resident_gather_pending = false
		resident_gather_phase = ""
		resident_gather_target_id = ""
		resident_gather_resource = ""
		resident_gather_payload = 0
		resident_gather_pickup_remaining = 0.0
	weather_phase = clampi(int(saved.get("weather_phase", WeatherPhase.FORECAST)), WeatherPhase.FORECAST, WeatherPhase.AFTER)
	resolved_storm_count = clampi(int(saved.get("resolved_storm_count", 1 if weather_phase == WeatherPhase.AFTER else 0)), 0, 9999)
	next_storm_day = clampi(int(saved.get("next_storm_day", day_count + 2 if weather_phase == WeatherPhase.AFTER else 0)), 0, 9999)
	var saved_storm_facts = saved.get("last_resolved_storm_facts", {})
	last_resolved_storm_facts = saved_storm_facts.duplicate(true) if saved_schema >= 18 and saved_storm_facts is Dictionary else {}
	tidekeeper_last_storm_reflection = clampi(int(saved.get("tidekeeper_last_storm_reflection", resolved_storm_count)), 0, resolved_storm_count)
	rope_available = bool(saved.get("rope_available", true))
	rope_use = str(saved.get("rope_use", "none"))
	shelter_roof_damaged = bool(saved.get("shelter_roof_damaged", false))
	raft_edge_damaged = bool(saved.get("raft_edge_damaged", false))
	safe_channel_marked = bool(saved.get("safe_channel_marked", false))
	ruin_searched = bool(saved.get("ruin_searched", false))
	cold_exposure = bool(saved.get("cold_exposure", false))
	cold_exposure_level = clampi(int(saved.get("cold_exposure_level", 1 if cold_exposure else 0)), 0, 3)
	cold_exposure = cold_exposure_level > 0
	ancient_parts = clampi(int(saved.get("ancient_parts", 0)), 0, 999)
	tide_station_searched = bool(saved.get("tide_station_searched", false))
	tide_relay_cores = clampi(int(saved.get("tide_relay_cores", 0)), 0, 1)
	tide_compass_tuned = bool(saved.get("tide_compass_tuned", false))
	if pressure_wreck_searched:
		_refresh_pressure_wreck_visual()
	message = str(saved.get("message", message)).left(500)
	collected_ids.clear()
	for value in saved.get("collected_ids", []):
		collected_ids.append(str(value))
	var shelter_value = saved.get("shelter_position", {})
	if shelter_value is Dictionary:
		shelter_position = Vector3(float(shelter_value.get("x", 0.0)), float(shelter_value.get("y", 0.12)), float(shelter_value.get("z", 0.0)))
	var storage_value = saved.get("storage_position", {})
	if storage_value is Dictionary:
		storage_position = Vector3(float(storage_value.get("x", 0.0)), float(storage_value.get("y", 0.12)), float(storage_value.get("z", 0.0)))
	var workbench_value = saved.get("workbench_position", {})
	if workbench_value is Dictionary:
		workbench_position = Vector3(float(workbench_value.get("x", 0.0)), float(workbench_value.get("y", 0.12)), float(workbench_value.get("z", 0.0)))
	var player_value = saved.get("player_position", {})
	if player_value is Dictionary and player:
		var saved_player_position := Vector3(float(player_value.get("x", 0.0)), float(player_value.get("y", 1.1)), float(player_value.get("z", 1.2)))
		player.position = ark_root.to_local(saved_player_position) if saved_schema <= 11 and ark_root else saved_player_position
	for index in range(interactables.size() - 1, -1, -1):
		var entry: Dictionary = interactables[index]
		if str(entry.get("id", "")) in ["wood", "shellfish"] and collected_ids.has(str(entry.get("item_id", ""))):
			var pile: Node = entry.get("node")
			if is_instance_valid(pile):
				pile.queue_free()
			interactables.remove_at(index)
	if shelter_built:
		_build_shelter_at(shelter_position)
		if resident_keepsake_present:
			_add_resident_keepsake()
		if sailmaker_awning_raised:
			_add_sailmaker_awning()
	if storage_built:
		_build_storage_at(storage_position)
	if workbench_built:
		_build_workbench_at(workbench_position)
	if keel_wreck_searched:
		_refresh_keel_wreck_visual()
	if tide_station_searched:
		_refresh_tide_station_visual()
	if jade_sail_ark_searched:
		_refresh_jade_sail_ark_visual()
	if raft_extension_built:
		_build_raft_extension_at(Vector3(0.0, 0.12, -4.2))
	if traveler_boarded:
		_set_traveler_boarded()
	if sailmaker_boarded:
		_set_sailmaker_boarded()
	var traveler_position_value = saved.get("traveler_position", {})
	if traveler_boarded and traveler_position_value is Dictionary and traveler_marker:
		var saved_traveler_position := Vector3(float(traveler_position_value.get("x", traveler_marker.position.x)), float(traveler_position_value.get("y", traveler_marker.position.y)), float(traveler_position_value.get("z", traveler_marker.position.z)))
		if resident_gather_pending and resident_gather_phase in ["outbound", "collecting"] and collected_ids.has(resident_gather_target_id):
			_abort_resident_gathering("target_already_collected")
		else:
			if traveler_marker.get_parent() != self:
				traveler_marker.reparent(self, true)
			traveler_marker.global_position = saved_traveler_position
			if not resident_gather_pending:
				_update_traveler_schedule()
	elif traveler_position_value is Dictionary and traveler_marker:
		traveler_marker.position = Vector3(float(traveler_position_value.get("x", traveler_marker.position.x)), float(traveler_position_value.get("y", traveler_marker.position.y)), float(traveler_position_value.get("z", traveler_marker.position.z)))
	var sailmaker_position_value = saved.get("sailmaker_position", {})
	if sailmaker_boarded and sailmaker_position_value is Dictionary and sailmaker_marker:
		sailmaker_marker.position = Vector3(float(sailmaker_position_value.get("x", sailmaker_marker.position.x)), float(sailmaker_position_value.get("y", sailmaker_marker.position.y)), float(sailmaker_position_value.get("z", sailmaker_marker.position.z)))
	var jade_keeper_position_value = saved.get("jade_sail_keeper_position", {})
	if jade_sail_keeper_marker:
		if jade_sail_industry_pending and jade_keeper_position_value is Dictionary:
			jade_sail_keeper_marker.global_position = Vector3(float(jade_keeper_position_value.get("x", JADE_INDUSTRY_HOME_POSITION.x)), float(jade_keeper_position_value.get("y", JADE_INDUSTRY_HOME_POSITION.y)), float(jade_keeper_position_value.get("z", JADE_INDUSTRY_HOME_POSITION.z)))
		else:
			jade_sail_keeper_marker.global_position = JADE_INDUSTRY_HOME_POSITION
			var jade_resource_name := "漂木" if jade_sail_industry_resource == "wood" else "潮池鲜贝"
			jade_sail_keeper_action = "前往资源点" if jade_sail_industry_phase == "outbound" else "采集%s" % jade_resource_name if jade_sail_industry_phase == "collecting" else "把%s带回货舱" % jade_resource_name if jade_sail_industry_phase == "returning" else "统筹琼华产业" if jade_sail_industry_acquired else "安排琼华舫营生" if jade_sail_industry_active else "守着旧舫"
		_update_jade_sail_keeper_nameplate()
	if jade_sail_industry_pending and jade_sail_industry_phase in ["outbound", "collecting"]:
		var industry_target_exists := false
		for entry in interactables:
			if str(entry.get("id", "")) == "shellfish" and str(entry.get("item_id", "")) == jade_sail_industry_target_id:
				industry_target_exists = true
				break
		if not industry_target_exists or collected_ids.has(jade_sail_industry_target_id):
			_abort_jade_sail_industry_gathering("saved_target_already_collected_or_missing")
	if raft_edge_damaged and _ark_node("RaftDamageMark") == null:
		_add_box("RaftDamageMark", Vector3(0, 0.45, -2.18), Vector3(0.9, 0.12, 0.2), Color("574338"), false, ark_root)
	if safe_channel_marked:
		_add_safe_channel_mark()
	_set_weather_visuals()
	_refresh_reef_beast_visual()


func _exit_tree() -> void:
	if save_service != null:
		_save_progress()
