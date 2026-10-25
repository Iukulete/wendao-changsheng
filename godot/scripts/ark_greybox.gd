extends Node3D

## Active open-world home-building prototype; entered from the sole Ark menu.

const GatheringScript = preload("res://scripts/modules/residents/ark_gathering.gd")
var gathering = GatheringScript.new()
const HouseholdWorkScript = preload("res://scripts/adapters/ark_household_simulation.gd")
var household_work = HouseholdWorkScript.new()
var household_work_choice_pending := false
var household_work_route_retry := 0.0
var household_work_bench_side := 0
var household_target_cache: Dictionary = {}
const EconomyScript = preload("res://scripts/modules/economy/ark_economy.gd")
const ConstructionScript = preload("res://scripts/modules/construction/ark_construction.gd")
const MemoryScript = preload("res://scripts/modules/memory/ark_memory.gd")
const WaterScript = preload("res://scripts/adapters/ark_analytic_water.gd")
const NavigationScript = preload("res://scripts/adapters/ark_vessel_navigation.gd")
var economy = EconomyScript.new()
var construction = ConstructionScript.new()
var memories = MemoryScript.new()
var water = WaterScript.new()
var vessel_navigation = NavigationScript.new()
var _modules_ready := false
var _restoring_progress := false
var _pending_modules: Dictionary = {}
var _construction_sequence := 0
var _new_water_session := false
const NearfutureHudScript = preload("res://scripts/presentation/ark_nearfuture_hud.gd")
var nearfuture_hud: Node
const LanternTableScript = preload("res://scripts/modules/leisure/ark_lantern_table.gd")
const LanternTableUIScript = preload("res://scripts/presentation/ark_lantern_table_ui.gd")
const LanternTablePropsScript = preload("res://scripts/presentation/ark_lantern_table_props.gd")
var lantern_table = LanternTableScript.new()
var lantern_table_ui: Control
var lantern_table_props = LanternTablePropsScript.new()
const ModernUtilitiesScript = preload("res://scripts/modules/modern/ark_modern_utilities.gd")
const ModernUtilityProps = preload("res://scripts/presentation/ark_modern_utility_props.gd")
var modern_utilities = ModernUtilitiesScript.new()
var modern_status: Label
var modern_action_button: Button
var modern_pack_choice_pending := false
const ResidentWashingScript = preload("res://scripts/adapters/ark_resident_washing.gd")
var resident_washing = ResidentWashingScript.new()
const FixturePlacement = preload("res://scripts/ark_fixture_placement.gd")
const HomeTemplateCatalog = preload("res://scripts/modules/construction/ark_home_templates.gd")
const HomeTemplatesScript = preload("res://scripts/adapters/ark_home_templates.gd")
var home_templates = HomeTemplatesScript.new()
var home_template_buttons := {}
const RoomRoles = preload("res://scripts/modules/rooms/ark_room_roles.gd")
const KitchenScript = preload("res://scripts/modules/residents/ark_kitchen_work.gd")
const ResidentKitchenScript = preload("res://scripts/adapters/ark_resident_kitchen.gd")
var kitchen = KitchenScript.new()
var resident_kitchen = ResidentKitchenScript.new()
const FoodStorageRules = preload("res://scripts/modules/rooms/ark_food_storage.gd")
const FoodStorageScript = preload("res://scripts/adapters/ark_food_storage.gd")
var food_storage = FoodStorageScript.new()
const HomeDemandScript = preload("res://scripts/adapters/ark_home_demand.gd")
var home_demand = HomeDemandScript.new()
var kitchen_button: Button

# Online life only: one period every three active minutes; no offline catch-up.
const LIFE_PERIOD_SECONDS := 180.0
const SHORE_SUPPLIES := [
	["DriftwoodNear", "wood", Vector3(-4.0, 0.15, 1.5), 2],
	["DriftwoodShore", "wood", Vector3(9.0, 0.22, -4.0), 2],
	["DriftwoodRidge", "wood", Vector3(19.0, 0.22, -5.5), 3],
	["MoonbackDriftwood", "wood", Vector3(-20.0, 0.22, 18.0), 2],
	["JadeSailDriftwood", "wood", Vector3(-47.0, 0.22, -48.0), 3],
	["TidalShellsNear", "shellfish", Vector3(8.4, 0.1, -6.1), 1],
	["TidalShellsCove", "shellfish", Vector3(13.8, 0.12, -11.8), 1],
	["MoonbackTidalShells", "shellfish", Vector3(-23.0, 0.12, 14.0), 2],
	["JadeSailTidalShells", "shellfish", Vector3(-60.0, 0.12, -49.0), 2],
	["JadeSailTidalShellsWest", "shellfish", Vector3(-48.0, 0.12, -50.5), 1],
	["JadeSailTidalShellsNorth", "shellfish", Vector3(-56.0, 0.12, -39.5), 1],
]
const WALK_SPEED := 1.2
const SPRINT_SPEED := 5.0
const SWIM_SPEED := 2.9
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
const ENVIRONMENT_PUSH_SECONDS := 0.32
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
const TIDE_STATION_POSITION := preload("res://scripts/terrain/ark_moonback_terrain.gd").STATION
const JADE_SAIL_ARK_POSITION := Vector3(-53.0, 0.2, -45.0)
const PRESSURE_WRECK_POSITION := Vector3(92.0, 0.2, 86.0)
const PRESSURE_VENT_NOTICE_RADIUS := 9.0
const PRESSURE_VENT_DANGER_RADIUS := 2.9
const PRESSURE_VENT_WINDUP_SECONDS := 1.4
const PRESSURE_VENT_COOLDOWN_SECONDS := 5.5
const BASE_SAIL_SPEED := 3.6
const TUNED_SAIL_SPEED := 4.6
const BUILD_COST = HomeTemplateCatalog.COSTS.shelter
const STORAGE_COST = HomeTemplateCatalog.COSTS.storage
const WORKBENCH_COST = HomeTemplateCatalog.COSTS.workbench
const RAFT_EXTENSION_WOOD_COST := 4
const RAFT_EXTENSION_KEEL_COST := 1
const GUEST_CABIN_WOOD_COST := 3
const GUEST_CABIN_FRAME_COST := 1
const PRESSURE_GALLEY_WOOD_COST := 3
const GUEST_CABIN_SAILMAKER_POSITION := Vector3(-0.85, 0.12, -4.34)
# These clear floor positions are temporary refuge, not extra beds. The Cot
# remains the player's; dedicated resident accommodation comes from expansion.
const TIDEKEEPER_REFUGE_REST_OFFSET := Vector3(0.5, 0.12, -0.5)
const SAILMAKER_REFUGE_REST_OFFSET := Vector3(-0.72, 0.12, 0.25)
# Keep the full-size meal mat left of the player's Cot, with one resident
# approaching each long edge rather than putting a body against the bed.
const SHARED_MEAL_MAT_OFFSET := Vector3(-0.55, 0.25, 0.4)
const TIDEKEEPER_SHARED_MEAL_OFFSET := Vector3(-0.95, 0.12, -0.15)
const SAILMAKER_SHARED_MEAL_OFFSET := Vector3(0.05, 0.12, 0.95)
const TIDEKEEPER_BOX_SHORE_POSITION := Vector3(14.25, 0.08, -6.45)
const TIDEKEEPER_BOX_ARK_POSITION := Vector3(2.15, 0.12, -0.45)
const RESIDENT_AUTO_GATHER_RADIUS := 11.0
const RESIDENT_AUTO_GATHER_SPEED := 1.8
const RESIDENT_AUTO_GATHER_PICKUP_SECONDS := 0.65
const RESIDENT_ROUTE_CELL_SIZE := 0.75
const RESIDENT_ROUTE_MARGIN := 4.5
const RESIDENT_ROUTE_MAX_SPAN := 32.0
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
const SAILMAKER_AWNING_SEW_SECONDS := SaveScript.SAILMAKER_AWNING_SEW_SECONDS
const SAILMAKER_AWNING_INSTALL_SECONDS := SaveScript.SAILMAKER_AWNING_INSTALL_SECONDS
const SAILMAKER_AWNING_MAX_STEP := 0.1
const SAILMAKER_AWNING_ARRIVAL_TOLERANCE := 0.06
const SAILMAKER_AWNING_ROUTE_RETRY_SECONDS := 0.5
const SAILMAKER_AWNING_SEW_OFFSET := Vector3(-0.72, 0.12, 0.9)
# Stand outside the future canvas footprint, including real head/face extents
# and the arrival tolerance, rather than creating the old low awning through her.
const SAILMAKER_AWNING_INSTALL_OFFSET := Vector3(-0.2, 0.12, 0.2)
# Clear both residents at the existing refuge/meal positions, below the unchanged roof.
const SAILMAKER_AWNING_CANVAS_OFFSET := Vector3(0.0, 1.95, -0.72)
const WorldChartScript = preload("res://scripts/ark_world_chart.gd")
const UI_FONT = WorldChartScript.UI_FONT
const LandmassBuilderScript = preload("res://scripts/ark_landmass_builder.gd")
const SurfaceSampleScript = preload("res://scripts/presentation/ark_surface_sample.gd")
var surface_sample = SurfaceSampleScript.new()
const HomeArtSampleScript = preload("res://scripts/presentation/ark_home_art_sample.gd")
var home_art_sample = HomeArtSampleScript.new()
var home_art_button: Button
# Presentation policy only. Historical raw-material fixtures opt out explicitly;
# ordinary play, save/load, navigation and production package use the default.
@export var start_with_home_art := true
const OpeningCoastScript = preload("res://scripts/terrain/ark_opening_coast.gd")
const MoonbackTerrainScript = preload("res://scripts/terrain/ark_moonback_terrain.gd")
const GroundSamplerScript = preload("res://scripts/terrain/ark_ground_sampler.gd")
const CoastMaterialsScript = preload("res://scripts/presentation/ark_coast_materials.gd")
const CoastNatureScript = preload("res://scripts/presentation/ark_coast_nature.gd")
const RidgeCampScript = preload("res://scripts/presentation/ark_ridge_camp.gd")
const MoonbackLandingScript = preload("res://scripts/presentation/ark_moonback_landing.gd")
const RegionalRouteScript = preload("res://scripts/adapters/ark_regional_walk_route.gd")
var moonback_landing = MoonbackLandingScript.new()
var opening_coast = OpeningCoastScript.new()
var opening_coast_result: Dictionary = {}
var moonback_terrain = MoonbackTerrainScript.new()
var moonback_terrain_result: Dictionary = {}
var ground_sampler = GroundSamplerScript.new()
# Frozen run02 directional calibration; unchanged day/weather profiles own time.
const COAST_SUN_ENERGY_SCALE := 0.36453125

enum WeatherPhase { FORECAST, STORM, AFTER }
enum DayPeriod { MORNING, DAY, EVENING, NIGHT }

@export var save_root_override := ""

var player: CharacterBody3D
var ark_root: Node3D
var camera: Camera3D
const OrbitCameraScript = preload("res://scripts/adapters/ark_orbit_camera.gd")
var orbit_camera = OrbitCameraScript.new()
var hud_panel: PanelContainer
var hud_stack: VBoxContainer
var hud_edit_layout := false
var hud_details: Label
var hud_drawer: PanelContainer
var hud_toggle: Button
var note_panel: PanelContainer
var note_scroll: ScrollContainer
var hud: Label
var note: Label
var interaction_hint: Label
var interaction_focus_ring: MeshInstance3D
var world_chart: Control
var save_status_notice: Label
var raft_expansion_blueprint_button: Button
var guest_cabin_blueprint_button: Button
var reef_shell_brace_button: Button
var raft_fenders_button: Button
var ridge_camp_searched := false
var raft_fenders_installed := false
var wood: int = 1:
	get:
		return economy.inventory("player", "wood")
	set(value):
		economy.sync_inventory("player", "wood", value)
var player_health := PLAYER_MAX_HEALTH
var raw_shellfish: int = 0:
	get:
		return economy.inventory("player", "shellfish")
	set(value):
		economy.sync_inventory("player", "shellfish", value)
var stew_servings: int = 0:
	get:
		return economy.inventory("player", "stew_servings")
	set(value):
		economy.sync_inventory("player", "stew_servings", value)
var shared_meal_day := 0
var shared_meal_count := 0
var shared_meal_gathering_pending := false
var shared_meal_paused := false
var shared_meal_participants: Array[String] = []
var resident_keepsake_present := false
var shelter_built := false
var shelter_position := Vector3.ZERO
var storage_built := false
var storage_position := Vector3.ZERO
var storage_quarter_turns := 0
var storage_collision_enabled := false
var stored_wood: int = 0:
	get:
		return economy.inventory("storage", "wood")
	set(value):
		economy.sync_inventory("storage", "wood", value)
var workbench_built := false
var workbench_position := Vector3.ZERO
var workbench_quarter_turns := 0
var workbench_collision_enabled := false
var keel_beams: int = 0:
	get:
		return economy.inventory("player", "keel_beams")
	set(value):
		economy.sync_inventory("player", "keel_beams", value)
var keel_wreck_searched := false
var learned_blueprint_ids: Array[String] = ["starter_shelter", "starter_home"]
var raft_extension_built := false
var guest_cabin_built := false
var guest_cabin_frames: int = 0:
	get:
		return economy.inventory("player", "guest_cabin_frames")
	set(value):
		economy.sync_inventory("player", "guest_cabin_frames", value)
var lantern_tuned := false
var resident_met := false
var traveler_boarded := false
var traveler_choice_pending := false
var resident_repair_choice_pending := false
var resident_repair_pending := false
var resident_repair_part := ""
var resident_gather_policy := "balanced"
var resident_gather_policy_choice_pending := false
var resident_task_id := ""
var jade_task_id := ""
var resident_gather_pending := false
var resident_gather_phase := ""
var resident_gather_target_id := ""
var resident_gather_resource := ""
var resident_gather_target_position := Vector3.ZERO
var resident_gather_route := PackedVector3Array()
var resident_gather_route_index := 0
var resident_regional_route_retry_at := 0
var resident_regional_route_jobs := {}
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
var jade_sail_industry_shellfish: int = 0:
	get:
		return economy.inventory("jade_sail", "shellfish")
	set(value):
		economy.sync_inventory("jade_sail", "shellfish", value)
var jade_sail_industry_wood: int = 0:
	get:
		return economy.inventory("jade_sail", "wood")
	set(value):
		economy.sync_inventory("jade_sail", "wood", value)
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
var environment_push_remaining := 0.0
var environment_push_velocity := Vector3.ZERO
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
var editing_fixture_id := ""
var preview_quarter_turns := 0
var fixture_preview_error := ""
var fixture_preview_checked_position := Vector3.INF
var fixture_preview_checked_turns := -1
var fixture_preview_checked_msec := 0
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
var sailmaker_awning_phase := "unstarted"
var sailmaker_awning_sewing_elapsed := 0.0
var sailmaker_awning_install_elapsed := 0.0
var sailmaker_awning_route_retry_remaining := 0.0
var sailmaker_awning_route_starts_blocked := false
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
var life_period_elapsed := 0.0
var last_shore_replenish_day := 1
var day_count := 1
var day_period := DayPeriod.MORNING
var world_events: Array[Dictionary] = []
var event_sequence := 0


func _init() -> void:
	economy.seed_inventory("player", {"wood": 1, "shellfish": 0, "stew_servings": 0, "keel_beams": 0, "guest_cabin_frames": 0})
	economy.seed_inventory("storage", {"wood": 0})
	economy.seed_inventory("jade_sail", {"wood": 0, "shellfish": 0})
	FoodStorageRules.initialize(economy)


func _ready() -> void:
	_build_world()
	_build_player()
	_build_hud()
	if not opening_coast_result.get("ok", false):
		_block_coast_load(opening_coast_result.get("errors", []))
		_update_hud()
		_ensure_nearfuture_hud()
		return
	save_service = SaveScript.new(save_root_override)
	vessel_navigation.configure(ark_root, "starter_ark")
	vessel_navigation.bind_actor("player", player, "deck")
	_load_progress()
	player_inside_refuge = _is_within_ark_refuge()
	_update_hud()
	_ensure_nearfuture_hud()
	home_art_sample.set_enabled(self, start_with_home_art)
	if home_art_button:
		home_art_button.set_pressed_no_signal(home_art_sample.enabled)


# Scene-owned presentation only; attach after the world, saved state and native
# HUD are initialized. Repeated setup reuses the same reversible adapter.
func _ensure_nearfuture_hud() -> bool:
	if not is_instance_valid(nearfuture_hud):
		nearfuture_hud = NearfutureHudScript.new()
	if nearfuture_hud.attach(self):
		if not nearfuture_hud.choice_requested.is_connected(_on_hud_choice_requested):
			nearfuture_hud.choice_requested.connect(_on_hud_choice_requested)
		return true
	nearfuture_hud.queue_free()
	nearfuture_hud = null
	return false


# Rebuilds must expose the same presentation immediately as a fresh load, not
# leave replacement nameplates in their legacy visibility for one frame.
func _refresh_nearfuture_hud() -> void:
	if not _restoring_progress and is_instance_valid(nearfuture_hud):
		nearfuture_hud.refresh()
	if not _restoring_progress:
		home_art_sample.apply(self)


func _toggle_home_art_sample() -> void:
	home_art_sample.set_enabled(self, not home_art_sample.enabled)
	if home_art_button:
		home_art_button.set_pressed_no_signal(home_art_sample.enabled)


func _physics_process(_delta: float) -> void:
	if not _camera_input_allowed(): orbit_camera.release()
	_step_water(_delta)
	_tick_life_clock(_delta)
	if _lantern_table_open():
		if player: player.velocity = Vector3.ZERO
		_update_follow_camera()
		return
	if hud_drawer and hud_drawer.visible:
		if player:
			player.velocity = Vector3.ZERO
		return
	if player == null:
		return
	player_attack_cooldown = maxf(0.0, player_attack_cooldown - _delta)
	reef_beast_recovery_remaining = maxf(0.0, reef_beast_recovery_remaining - _delta)
	reef_beast_hit_flash_remaining = maxf(0.0, reef_beast_hit_flash_remaining - _delta)
	if reef_beast_hit_flash_remaining <= 0.0 and reef_beast_marker and is_instance_valid(reef_beast_marker):
		reef_beast_marker.scale = Vector3.ONE
	if world_chart and world_chart.visible:
		player.velocity = Vector3.ZERO
		_update_follow_camera()
		world_chart.refresh(player.global_position, _world_chart_destinations())
		return
	if vessel_navigation.has_active_task("player"):
		if sailing_mode:
			_sail_step(_delta, float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S)), float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)))
		vessel_navigation.step(_delta)
		_update_follow_camera()
		return
	if sailing_mode:
		var throttle := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
		var steer := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		_sail_step(_delta, throttle, steer)
		_update_follow_camera()
		_refresh_refuge_state()
		return
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_key_pressed(KEY_D): input.x += 1.0
	if Input.is_key_pressed(KEY_W): input.y -= 1.0
	if Input.is_key_pressed(KEY_S): input.y += 1.0
	input = input.normalized()
	var move: Vector3 = orbit_camera.movement(input)
	var was_swimming := is_swimming
	is_swimming = player.global_position.y <= float(water.query(player.global_position).height) - 0.45 + 0.08 and not player.is_on_floor() and player.velocity.y <= 0.0
	var current_speed := SWIM_SPEED * _cold_movement_multiplier() if is_swimming else _current_walk_speed()
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
	if environment_push_remaining > 0.0:
		environment_push_remaining = maxf(0.0, environment_push_remaining - _delta)
		var push_strength := environment_push_remaining / ENVIRONMENT_PUSH_SECONDS
		player.velocity.x += environment_push_velocity.x * push_strength
		player.velocity.z += environment_push_velocity.z * push_strength
		if environment_push_remaining <= 0.0:
			environment_push_velocity = Vector3.ZERO
	if is_swimming and player.velocity.y <= 0.0:
		player.global_position.y = float(water.query(player.global_position).height) - 0.45
		player.velocity.y = 0.0
	elif not player.is_on_floor():
		player.velocity.y -= 22.0 * _delta
	elif player.velocity.y <= 0.0:
		# Preserve the positive launch set by Space until move_and_slide leaves
		# the floor; only resting/downward grounded motion needs the floor bias.
		player.velocity.y = -0.1
	player.move_and_slide()
	_apply_player_world_edge()
	_apply_reef_surge(_delta)
	_process_reef_beast(_delta)
	_process_pressure_vent(_delta)
	if avatar_visual:
		if move.length_squared() > 0.001:
			# Input/velocity are world-space; the avatar inherits the vessel/actor basis.
			var local_direction := avatar_visual.get_parent_node_3d().global_basis.inverse() * move
			avatar_visual.rotation.y = lerp_angle(avatar_visual.rotation.y, atan2(local_direction.x, local_direction.z), 1.0 - exp(-12.0 * _delta))
	if was_swimming != is_swimming:
		_update_hud()
	_refresh_refuge_state()
	if building_mode:
		_update_build_preview()
	_update_follow_camera()


func _update_follow_camera() -> void:
	if not _camera_input_allowed(): orbit_camera.release()
	# Keep direct-space queries inside actual physics frames, including when
	# threaded physics is enabled later. Input handlers only change orbit state.
	orbit_camera.apply(camera, player, get_world_3d() if Engine.is_in_physics_frame() else null)


func _camera_input_allowed() -> bool:
	return not building_mode and not _hud_choice_open() and not (hud_drawer and hud_drawer.visible) and not (world_chart and world_chart.visible)


func _input(event: InputEvent) -> void:
	# Read-only diagnostics are a global shortcut, including when GUI controls
	# own keyboard focus. Never rely on their unhandled-key propagation.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8 and is_instance_valid(nearfuture_hud):
		nearfuture_hud.toggle_metrics()
		get_viewport().set_input_as_handled()
		return
	# Release before GUI handling, even if the pointer moved onto a panel.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		orbit_camera.release()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		orbit_camera.release()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		orbit_camera.release()


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
	if ark_root == null or get_world_3d() == null or not candidate.is_finite() or absf(candidate.x) > 130.0 or absf(candidate.z) > 130.0:
		return false
	var hull_shape := BoxShape3D.new()
	hull_shape.size = ARK_HULL_CLEARANCE
	var hull_offset := ARK_HULL_QUERY_OFFSET
	if raft_extension_built:
		# The new bow is at -6.25; excluding its own colliders from this query
		# must not also exclude the added deck from shoreline clearance.
		var stern_edge := ARK_HULL_QUERY_OFFSET.z + ARK_HULL_CLEARANCE.z * 0.5
		var bow_edge := -6.45
		hull_shape.size.z = stern_edge - bow_edge
		hull_offset.z = (stern_edge + bow_edge) * 0.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hull_shape
	query.transform = Transform3D(Basis(Vector3.UP, ark_root.global_rotation.y), candidate + Basis(Vector3.UP, ark_root.global_rotation.y) * hull_offset)
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
	if building_mode:
		message = "先确认或取消正在进行的施工，再回到舵位启航。"
		_update_hud()
		return
	if weather_phase == WeatherPhase.STORM:
		message = "风雨正急，暂时不能掌舵；仙舟留在当前海面。按 R 等雨势过去，再检查筏舷。"
	elif raft_edge_damaged:
		message = "筏舷还没修牢，暂时不能安全掌舵。先补好受损处。"
	else:
		var resident_recalled := _recall_resident_gatherer("ark_departure")
		_clear_player_knockback()
		sailing_mode = true
		player.velocity = Vector3.ZERO
		_pause_shared_table_meal()
		_record_world_event("ark_sailing_started", {"position": _position_facts(ark_root.global_position)})
		message = "你握住舵柄。W/S 前后航行，A/D 转向；再按 E 或 Esc 离舵。靠近岸礁時船身会被挡住。"
		if resident_recalled:
			message += " 守潮人收起近岸营生，随舟出发；已经带回的物资留在船上。"
	_save_progress()
	_update_hud()


func _current_walk_speed() -> float:
	var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	return speed * _cold_movement_multiplier()


func _cold_movement_multiplier() -> float:
	var exposure_multipliers := [1.0, 0.62, 0.42, 0.28]
	return float(exposure_multipliers[_effective_cold_exposure_level()])


func _push_player_from_environment(velocity: Vector3) -> void:
	# Hazard callbacks run after move_and_slide; retain the impulse for the
	# following physics frames instead of losing it to normal input velocity.
	environment_push_velocity = velocity
	environment_push_remaining = ENVIRONMENT_PUSH_SECONDS
	player.velocity.x += velocity.x
	player.velocity.z += velocity.z


func _clear_player_knockback() -> void:
	reef_beast_knockback_remaining = 0.0
	reef_beast_knockback_velocity = Vector3.ZERO
	environment_push_remaining = 0.0
	environment_push_velocity = Vector3.ZERO


func _apply_reef_surge(delta: float) -> void:
	reef_surge_cooldown = maxf(0.0, reef_surge_cooldown - delta)
	if not is_swimming or player == null or reef_surge_cooldown > 0.0:
		return
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	if player_xz.distance_to(REEF_SURGE_CENTER) > REEF_SURGE_RADIUS:
		return
	_push_player_from_environment(Vector3(REEF_SURGE_PUSH.x, 0.0, REEF_SURGE_PUSH.y) * 4.2)
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
	_clear_player_knockback()
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


func _pressure_vent_source() -> Node3D:
	var wreck := get_node_or_null("PressureWreck") as Node3D
	if wreck == null or wreck.is_queued_for_deletion() or not wreck.is_inside_tree():
		return null
	var vent := wreck.get_node_or_null("BentVent") as Node3D
	if vent == null or vent.is_queued_for_deletion() or not vent.is_inside_tree():
		return null
	return vent


func _process_pressure_vent(delta: float) -> void:
	if player == null:
		return
	var vent := _pressure_vent_source()
	if vent == null or pressure_wreck_searched:
		# An absent or unloading wreck must never leave a phantom hazard behind.
		pressure_vent_warning_active = false
		pressure_vent_warning_remaining = 0.0
		pressure_vent_cooldown_remaining = 0.0
		pressure_vent_burst_remaining = 0.0
		var inactive_steam := get_node_or_null("PressureWreck/SteamBurst") as GPUParticles3D
		if inactive_steam:
			inactive_steam.emitting = false
		_refresh_pressure_vent_visual()
		return
	pressure_vent_burst_remaining = maxf(0.0, pressure_vent_burst_remaining - maxf(0.0, delta))
	if pressure_vent_burst_remaining <= 0.0:
		var steam := get_node_or_null("PressureWreck/SteamBurst") as GPUParticles3D
		if steam:
			steam.emitting = false
	# Damage, knockback, event facts and the ground telegraph share this live XZ
	# center, including the wreck's rotation and any authored vent displacement.
	var vent_position := vent.global_position
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	var vent_xz := Vector2(vent_position.x, vent_position.z)
	var distance := player_xz.distance_to(vent_xz)
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
		_record_world_event("pressure_vent_warning", {"site_id": "steam_wreck_islet", "position": _position_facts(player.global_position), "source_position": _position_facts(vent_position), "radius": PRESSURE_VENT_DANGER_RADIUS, "windup_seconds": PRESSURE_VENT_WINDUP_SECONDS, "damage": 0})
		message = "蒸汽阀发出尖锐的两段鸣响，喷口正在蓄压！退到地面亮起的警示圈外，就能避开热汽。"
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
		_push_player_from_environment(Vector3(away.x, 0.0, away.y) * 5.0)
		_record_world_event("pressure_vent_hit", {"site_id": "steam_wreck_islet", "position": _position_facts(player.global_position), "source_position": _position_facts(vent_position), "radius": PRESSURE_VENT_DANGER_RADIUS, "damage": health_before - player_health, "player_health_after": player_health, "inventory_lost": false, "recovery": "shelter_cot_or_shared_meal"})
		if player_health <= 0:
			_knock_out_player_from_pressure_vent()
		else:
			message = "高压热汽擦过肩背，生命 %d/%d。你被推离喷口，没有丢失行囊；下次蓄压时退到警示圈外，等阀门重新泄压。" % [player_health, PLAYER_MAX_HEALTH]
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
	_clear_player_knockback()
	if ark_root:
		player.global_position = ark_root.to_global(Vector3(0.0, 1.1, 1.55))
	_record_world_event("player_knocked_out", {"cause": "pressure_vent", "position": _position_facts(knocked_out_position), "recovery_position": _position_facts(player.global_position), "health_after": player_health, "inventory_lost": false})
	message = "高压热汽将你撞倒。你醒来时已被同伴送回自家仙舟，行囊完整，但只剩 1 点生命；休息或共餐能恢复。"
	_refresh_refuge_state()


func _refresh_pressure_vent_visual() -> void:
	var wreck := get_node_or_null("PressureWreck") as Node3D
	var vent := _pressure_vent_source()
	var warning_visible := pressure_vent_warning_active and vent != null and not pressure_wreck_searched
	var warning_ring := wreck.get_node_or_null("VentWarningRing") as MeshInstance3D if wreck else null
	if warning_ring:
		warning_ring.visible = warning_visible
		if vent:
			# The island's flat ground is 0.16m below the wreck origin. Keep the
			# rim just above it and world-sized even if the wreck is scaled.
			var ground_center := vent.global_position
			ground_center.y = wreck.global_position.y - 0.1
			warning_ring.global_transform = Transform3D(Basis.IDENTITY, ground_center)
		var ring_material := warning_ring.material_override as StandardMaterial3D
		if ring_material:
			var pulse := 0.89 + sin(pressure_vent_warning_remaining * 18.0) * 0.11
			var base_color := Color("ffd080")
			ring_material.albedo_color = Color(base_color.r * pulse, base_color.g * pulse, base_color.b * pulse)
			ring_material.emission_energy_multiplier = 1.4 * pulse
	var glow := wreck.get_node_or_null("PressureGlow") as OmniLight3D if wreck else null
	if glow:
		glow.light_energy = 0.0 if vent == null else 1.8 if warning_visible else (2.2 if pressure_vent_burst_remaining > 0.0 else 0.16 if pressure_wreck_searched else 0.6)
	var sign_node := get_node_or_null("PressureWreckInteractable/Name") as Label3D
	if sign_node:
		if pressure_wreck_searched:
			sign_node.text = "蒸潮机坞 · 核心已回收"
		elif vent == null:
			sign_node.text = "蒸潮机坞 · 阀门已静"
		elif warning_visible:
			sign_node.text = "压力阀蓄压 · 退到警示圈外"
		else:
			sign_node.text = "蒸潮机坞 · 间歇喷汽"


func _record_world_event(event_id: String, facts: Dictionary = {}) -> void:
	if _modules_ready:
		memories.record(event_id, facts, day_count, day_period)
		world_events = memories.events()
		event_sequence = memories.sequence()
	else:
		event_sequence += 1
		world_events.append({"sequence": event_sequence, "id": event_id, "day": day_count, "period": day_period, "facts": facts.duplicate(true)})
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
	if _lantern_table_open():
		resident_washing.clear()
		resident_kitchen.clear()
		opening_coast.refresh_moving_actors()
		_update_shelter_roof_cutaway()
		return
	_reconcile_household_work()
	resident_kitchen.reconcile(self)
	resident_washing.reconcile(self)
	home_demand.step(self,delta)
	if traveler_boarded and traveler_marker != null and is_instance_valid(traveler_marker):
		traveler_motion_clock += delta
		var moving := false
		if resident_gather_pending:
			moving = _process_resident_gathering(delta)
		elif resident_kitchen.selected(self):
			moving = resident_kitchen.step(self,delta)
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
		_try_begin_household_work()
		_update_sailmaker_schedule()
		var sailmaker_moving := false
		if _household_work_can_run():
			sailmaker_moving = _process_household_work(delta)
		elif _sailmaker_awning_work_can_run():
			sailmaker_moving = _process_sailmaker_awning_work(delta)
		elif not building_mode:
			sailmaker_moving = _move_ark_resident_toward(sailmaker_marker, sailmaker_target_position, delta, 0.64, "sailmaker")
		_update_sailmaker_work_visuals()
		_update_household_work_pose()
		if sailmaker_body:
			sailmaker_body.position.y = sin(sailmaker_motion_clock * (8.0 if sailmaker_moving else 2.0)) * (0.03 if sailmaker_moving else 0.007)
			if not sailmaker_moving:
				_record_sailmaker_guest_cabin_occupancy()
	if shared_meal_gathering_pending and (not _can_share_with_both_residents() or not _player_at_shared_table()):
		_pause_shared_table_meal()
	resident_washing.step(self,delta)
	opening_coast.refresh_moving_actors()
	resident_washing.present(self)
	resident_kitchen.present(self)
	# Place cabin labels after the residents' final rendered poses, not one step behind.
	_update_shelter_roof_cutaway()
	_update_interaction_hint()


func _move_ark_resident_toward(marker: Node3D, target: Vector3, delta: float, speed: float, resident_id: String, strict_work_route: bool = false) -> bool:
	var route := traveler_routine_route if resident_id == "tidekeeper" else sailmaker_routine_route
	var route_index := traveler_routine_route_index if resident_id == "tidekeeper" else sailmaker_routine_route_index
	var previous_target := traveler_routine_route_target if resident_id == "tidekeeper" else sailmaker_routine_route_target
	var target_set := traveler_routine_route_target_set if resident_id == "tidekeeper" else sailmaker_routine_route_target_set
	var target_changed := not target_set or not target.is_equal_approx(previous_target)
	var finished_route_displaced := not route.is_empty() and route_index >= route.size() and marker.position.distance_to(target) > 0.06
	if target_changed or finished_route_displaced:
		if strict_work_route:
			var start_point := Vector2(marker.position.x, marker.position.z)
			sailmaker_awning_route_starts_blocked = _ark_local_walk_cell_blocked(start_point, [], 0.25) or _shared_meal_route_point_blocked(start_point, _shared_meal_route_obstacles(target))
		var full_route := strict_work_route or modern_utilities.commissioned() or (resident_id == "tidekeeper" and resident_kitchen.selected(self))
		route = _build_ark_local_walk_route(marker.position, target, full_route)
		if full_route: resident_washing.prepare_route(self,resident_id,route)
		route_index = 1 if route.size() > 1 else 0
		previous_target = target
		target_set = true
	var distance_remaining := maxf(0.0, delta) * speed
	while route_index < route.size() and distance_remaining > 0.0:
		var movement_target := route[route_index]
		var offset := movement_target - marker.position
		var distance_to_target := offset.length()
		# Only numerical-zero waypoints may be skipped, without moving the actor.
		# Every real residual, even inside the arrival tolerance, spends its budget.
		if distance_to_target <= 0.00001:
			route_index += 1
			continue
		var step_distance := minf(distance_remaining, distance_to_target)
		var next_position := marker.position.move_toward(movement_target, step_distance)
		if (modern_utilities.commissioned() or (resident_id == "tidekeeper" and resident_kitchen.selected(self))) and not resident_washing.route_step_clear(self,resident_id,marker.position,next_position,route_index,target):
			route.clear()
			route_index = 0
			break
		if strict_work_route and not _sailmaker_awning_walk_step_clear(marker.position, next_position, target, sailmaker_awning_route_starts_blocked and route_index <= 1):
			route.clear()
			route_index = 0
			break
		marker.position = next_position
		distance_remaining -= step_distance
		var facing := Vector3(offset.x, 0.0, offset.z).normalized()
		if not facing.is_zero_approx():
			# All resident figures face +Z; this offset is in their ark-local frame.
			marker.rotation.y = atan2(facing.x, facing.z)
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


func _build_ark_local_walk_route(start: Vector3, destination: Vector3, full_deck_route: bool = false) -> PackedVector3Array:
	var route := PackedVector3Array()
	if ark_root == null or get_world_3d() == null or not start.is_finite() or not destination.is_finite() or start.distance_to(destination) <= 0.06:
		return route
	if not _ark_local_walk_position_supported(Vector2(start.x, start.z)) or not _ark_local_walk_position_supported(Vector2(destination.x, destination.z)):
		return route
	# The Cot and hearth are visual-only fixtures. Meal and awning work routes
	# still walk around their footprint without changing player collision.
	var meal_obstacles := _shared_meal_route_obstacles(destination)
	if full_deck_route: meal_obstacles = _home_routine_furniture_obstacles()
	var saved_start := start
	start = _shared_meal_route_clear_start(start, meal_obstacles)
	if not start.is_finite():
		return route
	var margin := 2.0
	var minimum := Vector2(minf(start.x, destination.x), minf(start.z, destination.z)) - Vector2.ONE * margin
	var maximum := Vector2(maxf(start.x, destination.x), maxf(start.z, destination.z)) + Vector2.ONE * margin
	# A wash destination can be on the opposite side of a furnished house.
	# Keep the search finite, but include the actual whole deck for this job;
	# a two-metre start/destination box can cut off the only clear corridor.
	if full_deck_route:
		minimum = Vector2(-3,-6.5 if raft_extension_built else -2.5)
		maximum = Vector2(3,2.5)
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
			# The 0.23-radius body needs a small planning margin: two clear grid
			# nodes can otherwise connect tangentially through a cabin door corner.
			if _ark_local_walk_cell_blocked(local_xz, [], 0.28 if full_deck_route else 0.25) or _shared_meal_route_point_blocked(local_xz, meal_obstacles):
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
	route.append(saved_start)
	if not saved_start.is_equal_approx(start):
		route.append(start)
	for index in range(1, cell_path.size() - 1):
		var cell: Vector2i = cell_path[index]
		route.append(Vector3(minimum.x + float(cell.x) * cell_size, start.y, minimum.y + float(cell.y) * cell_size))
	if start.distance_to(destination) > 0.06:
		route.append(destination)
	return route


func _shared_meal_route_obstacles(destination: Vector3) -> Array[Rect2]:
	var meal_destination := destination.is_equal_approx(shelter_position + TIDEKEEPER_SHARED_MEAL_OFFSET) or destination.is_equal_approx(shelter_position + SAILMAKER_SHARED_MEAL_OFFSET)
	var work_destination := destination.is_equal_approx(_sailmaker_awning_work_target(false)) or destination.is_equal_approx(_sailmaker_awning_work_target(true)) or (household_work.active() and destination.is_equal_approx(_household_work_target()))
	if not shelter_built or not (meal_destination or work_destination):
		return []
	return _home_routine_furniture_obstacles()


func _home_routine_furniture_obstacles() -> Array[Rect2]:
	var obstacles: Array[Rect2] = []
	if not shelter_built:
		return obstacles
	for id in ["Cot", "HearthStone"]:
		var fixture := _ark_node("BuiltShelter/" + id) as Node3D
		if fixture == null or fixture.get_child_count() == 0:
			continue
		var visual := fixture.get_child(0) as MeshInstance3D
		if visual == null or not visual.mesh is BoxMesh:
			continue
		var bounds := visual.get_aabb()
		var minimum := Vector2(INF, INF)
		var maximum := Vector2(-INF, -INF)
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					var point := ark_root.to_local(visual.to_global(Vector3(x, y, z)))
					minimum = minimum.min(Vector2(point.x, point.z))
					maximum = maximum.max(Vector2(point.x, point.z))
		obstacles.append(Rect2(minimum, maximum - minimum).grow(0.25))
	return obstacles


func _shared_meal_route_point_blocked(point: Vector2, obstacles: Array[Rect2]) -> bool:
	for bounds in obstacles:
		if bounds.has_point(point):
			return true
	return false


func _shared_meal_route_clear_start(start: Vector3, obstacles: Array[Rect2]) -> Vector3:
	var point := Vector2(start.x, start.z)
	if not _shared_meal_route_point_blocked(point, obstacles):
		return start
	# Old active meals can resume inside the Cot's new exclusion footprint.
	# Add a short outward walking leg; never teleport or rewrite saved positions.
	var nearest := Vector3.INF
	for bounds in obstacles:
		if not bounds.has_point(point):
			continue
		for candidate in [Vector2(floorf((bounds.position.x - 0.01) / 0.25) * 0.25, point.y), Vector2(ceilf((bounds.end.x + 0.01) / 0.25) * 0.25, point.y), Vector2(point.x, floorf((bounds.position.y - 0.01) / 0.25) * 0.25), Vector2(point.x, ceilf((bounds.end.y + 0.01) / 0.25) * 0.25)]:
			if _shared_meal_route_point_blocked(candidate, obstacles) or _ark_local_walk_cell_blocked(candidate, [], 0.25):
				continue
			var clear := Vector3(candidate.x, start.y, candidate.y)
			var steps := maxi(1, ceili(start.distance_to(clear) / 0.05))
			var clear_leg := true
			for step in range(1, steps + 1):
				var sample := point.lerp(candidate, float(step) / float(steps))
				if _ark_local_walk_cell_blocked(sample, [], 0.25):
					clear_leg = false
					break
			if clear_leg and start.distance_squared_to(clear) < start.distance_squared_to(nearest):
				nearest = clear
	return nearest


func _ark_local_walk_position_supported(local_xz: Vector2, actor_radius: float = 0.23) -> bool:
	# A collision-free point is not necessarily a floor: residents must not
	# bypass a blocked corridor by walking out over the surrounding sea.
	var bow_edge := -6.25 if raft_extension_built else -2.25
	return local_xz.is_finite() and absf(local_xz.x) <= 3.0 - actor_radius and local_xz.y >= bow_edge + actor_radius and local_xz.y <= 2.25 - actor_radius


func _ark_local_walk_cell_blocked(local_xz: Vector2, extra_excluded: Array[RID] = [], actor_radius: float = 0.23) -> bool:
	if not _ark_local_walk_position_supported(local_xz, actor_radius):
		return true
	var actor_center := ark_root.to_global(Vector3(local_xz.x, 1.15, local_xz.y))
	var capsule := CapsuleShape3D.new()
	capsule.radius = actor_radius
	capsule.height = 1.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis(Vector3.UP, ark_root.global_rotation.y), actor_center)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var excluded: Array[RID] = extra_excluded.duplicate()
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
	var modal_choice_open := _hud_choice_open()
	if player == null or building_mode or sailing_mode or modal_choice_open or (hud_drawer and hud_drawer.visible) or (world_chart and world_chart.visible):
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
		if str(nearest.get("id", "")) in ["storage", "workbench"]:
			interaction_hint.text += "    F · 搬移/旋转"
		var focus_target := nearest.get("node") as Node3D
		if interaction_focus_ring and focus_target and is_instance_valid(focus_target):
			interaction_focus_ring.global_position = focus_target.global_position + Vector3(0.0, 0.045, 0.0)
			interaction_focus_ring.visible = true
	elif interaction_focus_ring:
		interaction_focus_ring.visible = false
	if opening_coast.initialized:
		opening_coast.ground_focus_ring()


func _interaction_hint_action(interactable_id: String) -> String:
	if shared_meal_gathering_pending and _player_at_shared_table() and interactable_id in ["resident", "sailmaker", "hearth"]:
		return "重新招呼大家喝汤" if shared_meal_paused else "一起喝汤" if _shared_table_ready() else "在桌边等大家"
	match interactable_id:
		"wood": return "拾取漂木"
		"shellfish": return "采集潮池鲜贝"
		"resident": return "与守潮人交谈"
		"tidekeeper_box": return "查看守潮人的浮标箱"
		"sailmaker": return "与缝帆人交谈"
		"cot": return "在自己的床铺休息"
		"hearth": return "使用火盆煮汤"
		"storage": return "存取木料；G 管理家庭食材"
		"workbench": return "查看阵灯工作台"
		"home": return "整备仙舟"
		"helm": return "掌舵仙舟"
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
		"modern_wash": return "查看净水角 / 温水洗漱"
		_: return "查看附近物件"


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _lantern_table_open():
		if event.keycode == KEY_ESCAPE: _on_lantern_table_action("close")
		elif event.keycode == KEY_F5: _on_lantern_table_action("save")
		elif event.keycode == KEY_1: _on_lantern_table_action("hit" if lantern_table.view().phase == "playing" else "again")
		elif event.keycode == KEY_2: _on_lantern_table_action("stand")
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_F7:
		_toggle_home_art_sample()
		get_viewport().set_input_as_handled()
		return
	if world_chart and world_chart.visible:
		if event.keycode in [KEY_M, KEY_ESCAPE]:
			_toggle_world_chart()
		elif event.keycode == KEY_F5:
			_manual_save_progress()
		return
	if hud_drawer and hud_drawer.visible:
		if event.keycode in [KEY_H, KEY_ESCAPE]:
			_toggle_hud_drawer()
		elif event.keycode == KEY_F5:
			_manual_save_progress()
		elif event.keycode == KEY_M:
			hud_drawer.hide()
			_toggle_world_chart()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_M:
		_toggle_world_chart()
		return
	if event.keycode==KEY_G and not _hud_choice_open():
		food_storage.request(self)
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
	if food_storage.pending:
		if event.keycode in [KEY_1,KEY_2,KEY_3,KEY_ESCAPE]: food_storage.choose(self,event.keycode)
		return
	if modern_pack_choice_pending:
		if event.keycode == KEY_1: _choose_pack_modern_utilities(true)
		elif event.keycode in [KEY_2,KEY_ESCAPE]: _choose_pack_modern_utilities(false)
		return
	if household_work_choice_pending:
		if event.keycode == KEY_1:
			_choose_household_work(true)
		elif event.keycode == KEY_2:
			_choose_household_work(false)
		elif event.keycode == KEY_ESCAPE:
			household_work_choice_pending = false
			message = "家务分工保持原样。"
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
		elif event.keycode in [KEY_2, KEY_ESCAPE]:
			_choose_traveler_boarding(false)
		return
	if sailmaker_choice_pending:
		if event.keycode == KEY_1:
			_choose_sailmaker_boarding(true)
		elif event.keycode in [KEY_2, KEY_ESCAPE]:
			_choose_sailmaker_boarding(false)
		return
	if resident_repair_choice_pending:
		if event.keycode == KEY_1:
			_choose_resident_repair(true)
		elif event.keycode in [KEY_2, KEY_ESCAPE]:
			_choose_resident_repair(false)
		return
	if preparation_choice_pending:
		if event.keycode == KEY_ESCAPE:
			preparation_choice_pending = false
			message = "你先收起准备安排，绳索仍留在手中。"
			_update_hud()
			return
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
		elif event.keycode in [KEY_3, KEY_ESCAPE]:
			repair_choice_pending = false
			message = "你先记下损伤，等找到合适木料再修。"
			_update_hud()
		return
	if event.keycode == KEY_H:
		_toggle_hud_drawer()
		return
	if event.keycode == KEY_HOME and not building_mode:
		orbit_camera.reset()
		_update_follow_camera()
		get_viewport().set_input_as_handled()
		return
	if not editing_fixture_id.is_empty():
		if event.keycode == KEY_R:
			_rotate_fixture_preview()
		elif event.keycode in [KEY_ESCAPE, KEY_B, KEY_F]:
			_cancel_build()
		elif event.keycode == KEY_F5:
			_manual_save_progress() # Only committed transforms are persisted, never the ghost.
		return
	if event.keycode == KEY_F:
		_start_nearby_fixture_edit()
	elif event.keycode == KEY_Q:
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
		_manual_save_progress()
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
	var surface: Dictionary = water.query(player.global_position)
	var near_water := player.global_position.y <= float(surface.height) - 0.45 + 0.08
	if player.is_on_floor() or (near_water and player.velocity.y <= 0.0):
		# Keep the flat-water apex without ground buffs or repeated airborne boosts.
		var trough := clampf(float(surface.mean_height) - float(surface.height), 0.0, 0.5) if near_water and not player.is_on_floor() else 0.0
		player.velocity.y = sqrt(8.6 * 8.6 + 2.0 * 22.0 * trough)
		is_swimming = false
		if near_water:
			message = "你划水蹬开，借着浪头朝浅滩或木筏游去。"
			_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if hud_drawer and hud_drawer.visible:
		return
	if not building_mode:
		if _camera_input_allowed() and orbit_camera.handle(event):
			get_viewport().set_input_as_handled()
		return
	if not building_mode or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if not editing_fixture_id.is_empty():
			if preview_valid:
				_try_move_fixture(preview_position, preview_quarter_turns)
		elif build_type == "workshop_home_template":
			_try_place_workshop_home_template(preview_position)
		elif build_type == "starter_home_template":
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
	sea_mesh.subdivide_width = 199
	sea_mesh.subdivide_depth = 199
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
	add_child(landmass_builder.build_island("IslandLandmass", Vector3(11, 0, -14), Vector2(12, 10), 1.2, Color("536d50"), Color("77735b"), true))
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
	for supply in SHORE_SUPPLIES:
		_spawn_shore_supply(supply)
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
	surface_sample.apply_world(self)
	var coast_materials: Dictionary = CoastMaterialsScript.new().build()
	opening_coast_result = opening_coast.initialize(self, coast_materials.materials) if coast_materials.ok else coast_materials
	moonback_terrain_result = moonback_terrain.initialize(self, coast_materials.materials) if coast_materials.ok else coast_materials
	if not moonback_terrain_result.get("ok",false):
		opening_coast_result = moonback_terrain_result
	ground_sampler.rebuild(self)
	if moonback_terrain_result.get("ok",false): moonback_landing.build(self,ground_sampler)
	if opening_coast_result.get("ok", false):
		sea_material.set_shader_parameter("opening_heights", opening_coast.height_texture)
		CoastNatureScript.new().build(self, opening_coast)
		RidgeCampScript.build(self)
		sun_light.shadow_enabled = true
		sun_light.shadow_opacity = 0.62
		sun_light.shadow_bias = 0.04
		sun_light.shadow_normal_bias = 0.8
		sun_light.directional_shadow_max_distance = 45.0
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
	sign.font = UI_FONT
	sign.name = "Name"
	sign.text = "浮标箱"
	sign.position = Vector3(0.0, 0.68, 0.0)
	sign.font_size = 20
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_style_nearby_world_label(sign)
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
	avatar_visual = preload("res://scripts/presentation/ark_emma_protagonist.gd").new()
	player.add_child(avatar_visual)
	ark_root.add_child(player)
	avatar_visual.setup(player, self)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 54.0
	add_child(camera)
	var pixel_trial := preload("res://scripts/presentation/ark_pixel_protagonist.gd").new()
	player.add_child(pixel_trial)
	pixel_trial.setup(player, avatar_visual, camera)
	pixel_trial.set_enabled(false)


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
	# Keep Chinese readable on clean systems after the legacy global theme is gone.
	var ark_theme := Theme.new()
	ark_theme.default_font = UI_FONT
	var layer := CanvasLayer.new()
	add_child(layer)
	storm_overlay = ColorRect.new()
	storm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	storm_overlay.color = Color(0.08, 0.14, 0.2, 0.32)
	storm_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	storm_overlay.visible = false
	layer.add_child(storm_overlay)
	var panel := PanelContainer.new()
	panel.theme = ark_theme
	hud_panel = panel
	panel.name = "ArkCompactStatusPanel"
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(360, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	hud_stack = stack
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stack)
	hud = Label.new()
	hud.name = "ArkCompactStatus"
	hud.add_theme_font_size_override("font_size", 18)
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(hud)
	hud.minimum_size_changed.connect(func(): hud_panel.reset_size.call_deferred())
	note = Label.new()
	note.name = "ArkContextMessage"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.y = 54
	note.add_theme_font_size_override("font_size", 16)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_panel = PanelContainer.new()
	note_panel.name = "ArkContextPanel"
	note_panel.theme = ark_theme
	layer.add_child(note_panel)
	note_scroll = ScrollContainer.new()
	note_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	note_panel.add_child(note_scroll)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_scroll.add_child(note)
	hud_toggle = Button.new()
	hud_toggle.name = "ArkHelpToggleButton"
	hud_toggle.theme = ark_theme
	hud_toggle.text = "操作 / 建造 · H"
	hud_toggle.custom_minimum_size = Vector2(184, 40)
	hud_toggle.focus_mode = Control.FOCUS_NONE
	hud_toggle.pressed.connect(_toggle_hud_drawer)
	layer.add_child(hud_toggle)
	hud_drawer = PanelContainer.new()
	hud_drawer.name = "ArkHelpBuildDrawer"
	hud_drawer.theme = ark_theme
	hud_drawer.visible = false
	layer.add_child(hud_drawer)
	var drawer_root := VBoxContainer.new()
	hud_drawer.add_child(drawer_root)
	var close_button := Button.new()
	close_button.name = "ArkHelpCloseButton"
	close_button.text = "收起操作与建造 · H / Esc"
	close_button.custom_minimum_size.y = 40
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_toggle_hud_drawer)
	drawer_root.add_child(close_button)
	var drawer_scroll := ScrollContainer.new()
	drawer_scroll.name = "ArkHelpScroll"
	drawer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	drawer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer_root.add_child(drawer_scroll)
	stack = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	drawer_scroll.add_child(stack)
	hud_details = Label.new()
	hud_details.name = "ArkDetailedStatus"
	hud_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_details.add_theme_font_size_override("font_size", 16)
	stack.add_child(hud_details)
	var controls := Label.new()
	controls.text = "WASD 行走/游泳 · Shift 快跑 · Space 跳跃/蹬水 · Q 近身反击 · E 互动 · T 等待 · M 潮痕图 · R 天气 · F 家具搬移 · F5 存档\n每3分钟自动换时段；清晨补回采空的漂木/潮贝，不叠加库存。"
	controls.name = "ArkControlsHelp"
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_font_size_override("font_size", 16)
	stack.add_child(controls)
	interaction_hint = Label.new()
	interaction_hint.theme = ark_theme
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
	var build_buttons := VBoxContainer.new()
	build_buttons.add_theme_constant_override("separation", 8)
	stack.add_child(build_buttons)
	var basic_shelter_button := Button.new()
	basic_shelter_button.name = "ArkBasicShelterTemplateButton"
	basic_shelter_button.text = "基础避风棚 · 3 木"
	basic_shelter_button.tooltip_text = "开局避难所：玩家床铺与暖灯，另可临时接纳两位避难者；居民专用床位须后续扩建。"
	basic_shelter_button.pressed.connect(func(): _activate_hud_action(_start_basic_shelter_template))
	build_buttons.add_child(basic_shelter_button)
	var template_button := Button.new()
	template_button.name = "ArkStarterHomeTemplateButton"
	template_button.text = "模板：潮棚之家 · 5 木"
	template_button.tooltip_text = "预览后确认搭建；已有棚屋或家具时只补齐缺少的部分，不重复扣料或移动原布置。"
	template_button.pressed.connect(func(): _activate_hud_action(_start_starter_home_template))
	build_buttons.add_child(template_button)
	var workshop_button := Button.new()
	workshop_button.name = "ArkWorkshopHomeTemplateButton"
	workshop_button.text = "模板：起居工坊 · 7 木"
	workshop_button.tooltip_text = "整套避风棚、储物箱与工作台；先校验通路再施工。玩家床铺另计，两位居民仍为临时避难。"
	workshop_button.pressed.connect(func(): _activate_hud_action(_start_workshop_home_template))
	build_buttons.add_child(workshop_button)
	home_template_buttons = {"starter_home":template_button,"workshop_home":workshop_button}
	var free_build_button := Button.new()
	free_build_button.name = "ArkFreeBuildButton"
	free_build_button.text = "自由逐件搭建 · B"
	free_build_button.tooltip_text = "保留逐件放置方式；各结构可按自己的布局摆放。"
	free_build_button.pressed.connect(func(): _activate_hud_action(_start_build))
	build_buttons.add_child(free_build_button)
	raft_expansion_blueprint_button = Button.new()
	raft_expansion_blueprint_button.name = "ArkRaftExpansionBlueprintButton"
	raft_expansion_blueprint_button.text = "蓝图：龙骨扩甲 · 探索远礁沉筏解锁"
	raft_expansion_blueprint_button.tooltip_text = "远礁寻回龙骨时发现的扩建方案；保留普通构件的自由摆放。"
	raft_expansion_blueprint_button.disabled = true
	raft_expansion_blueprint_button.pressed.connect(func(): _activate_hud_action(_start_raft_expansion_blueprint))
	stack.add_child(raft_expansion_blueprint_button)
	guest_cabin_blueprint_button = Button.new()
	guest_cabin_blueprint_button.name = "ArkGuestCabinBlueprintButton"
	guest_cabin_blueprint_button.text = "蓝图：听潮客舱 · 探索琼华舫解锁"
	guest_cabin_blueprint_button.tooltip_text = "从豪华仙舟遗址带回的客居舱方案；学会后永久收录，建造需要 3 块木料与 1 根舱骨。"
	guest_cabin_blueprint_button.disabled = true
	guest_cabin_blueprint_button.pressed.connect(func(): _activate_hud_action(_start_guest_cabin_template))
	stack.add_child(guest_cabin_blueprint_button)
	reef_shell_brace_button = Button.new()
	reef_shell_brace_button.name = "ArkReefShellBraceBlueprintButton"
	reef_shell_brace_button.text = "蓝图：礁壳风撑 · 击退远礁礁背兽解锁"
	reef_shell_brace_button.tooltip_text = "探索或击败礁背兽获得永久知识；安装在已建避风棚上，需要 2 块木料与 1 片礁壳，可抵御后续风雨对棚顶的损伤。"
	reef_shell_brace_button.disabled = true
	reef_shell_brace_button.pressed.connect(func(): _activate_hud_action(_install_reef_shell_brace))
	stack.add_child(reef_shell_brace_button)
	raft_fenders_button = Button.new()
	raft_fenders_button.name = "ArkRaftFendersBlueprintButton"
	raft_fenders_button.text = "蓝图：浮木护舷 · 岩脊旧营地解锁"
	raft_fenders_button.tooltip_text = "沿首岛岩脊寻找旧营地，永久学会图样。回到本舟，用 4 块木料安装；防护普通风浪造成的筏舷损伤，不保护棚顶。"
	raft_fenders_button.pressed.connect(func(): _activate_hud_action(_install_raft_fenders))
	stack.add_child(raft_fenders_button)
	modern_status = Label.new()
	modern_status.name = "ArkModernUtilityStatus"
	modern_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(modern_status)
	var modern_button := Button.new()
	modern_action_button = modern_button
	modern_button.name = "ArkModernUtilityBuildButton"
	modern_button.text = "日照净水角 · 4 木 + 1 套回收组件"
	modern_button.tooltip_text = "蒸潮机坞找回图样与组件；装在龙骨甲板的空位。太阳能、蓄电、净水与温水洗漱共用真实资源。"
	modern_button.pressed.connect(func(): _activate_hud_action(_request_pack_modern_utilities if modern_utilities.installed else _install_modern_utilities))
	stack.add_child(modern_button)
	var purifier_button := Button.new()
	purifier_button.name = "ArkPurifierToggleButton"
	purifier_button.text = "切换自动净水（保留电量）"
	purifier_button.pressed.connect(_toggle_modern_purifier)
	stack.add_child(purifier_button)
	var return_button := Button.new()
	return_button.name = "ArkReturnToMainButton"
	return_button.text = "保存并返回主菜单"
	return_button.custom_minimum_size.y = 36.0
	return_button.pressed.connect(_return_to_main_menu)
	home_art_button = Button.new()
	home_art_button.name = "ArkHomeArtCandidateButton"
	home_art_button.text = "家园美术 · F7 灰盒对照"
	home_art_button.tooltip_text = "甲板、生活舱、现代设备与首岛海岸的统一材质；F7 临时切换灰盒，不改玩法、存档或人物。"
	home_art_button.toggle_mode = true
	home_art_button.pressed.connect(_toggle_home_art_sample)
	stack.add_child(home_art_button)
	stack.add_child(return_button)
	home_art_button.custom_minimum_size.y = 40
	var household_button := Button.new()
	household_button.name = "ArkHouseholdWorkButton"
	household_button.text = "居民分工 / 房间用途"
	household_button.custom_minimum_size.y = 40
	household_button.focus_mode = Control.FOCUS_NONE
	household_button.pressed.connect(_open_household_work_board)
	stack.add_child(household_button)
	kitchen_button = Button.new()
	kitchen_button.name = "ArkKitchenWorkButton"
	kitchen_button.custom_minimum_size.y = 40
	kitchen_button.focus_mode = Control.FOCUS_NONE
	kitchen_button.tooltip_text = "守潮人傍晚走到火盆旁加工4秒，每日最多一锅，只补到2份。蒸汽饭釜加工2秒。完工才花1鲜贝；暂停或离位不扣料，手动煮汤不变。"
	kitchen_button.pressed.connect(_toggle_kitchen_policy)
	stack.add_child(kitchen_button)
	var lantern_button := Button.new()
	lantern_button.name = "ArkLanternTableButton"
	lantern_button.text = "灯下牌局 · 邀居民坐一会儿"
	lantern_button.custom_minimum_size.y = 40
	lantern_button.focus_mode = Control.FOCUS_NONE
	lantern_button.pressed.connect(_open_lantern_table)
	stack.add_child(lantern_button)
	for button in [basic_shelter_button, template_button, free_build_button, raft_expansion_blueprint_button, guest_cabin_blueprint_button, reef_shell_brace_button, raft_fenders_button, return_button]:
		button.custom_minimum_size.y = 40
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
	world_chart = WorldChartScript.new()
	world_chart.theme = ark_theme
	world_chart.name = "ArkWorldChart"
	world_chart.visible = false
	world_chart.destination_selected.connect(_on_world_chart_destination_selected)
	layer.add_child(world_chart)
	# The chart covers the ordinary HUD; explicit F5 feedback must remain above it.
	save_status_notice = Label.new()
	save_status_notice.theme = ark_theme
	save_status_notice.name = "ArkSaveStatus"
	save_status_notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	save_status_notice.offset_left = 24.0
	save_status_notice.offset_right = -24.0
	save_status_notice.offset_top = -90.0
	save_status_notice.offset_bottom = -18.0
	save_status_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_status_notice.add_theme_color_override("font_color", Color("ffe0a0"))
	save_status_notice.add_theme_color_override("font_shadow_color", Color.BLACK)
	save_status_notice.add_theme_constant_override("shadow_offset_x", 2)
	save_status_notice.add_theme_constant_override("shadow_offset_y", 2)
	save_status_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_status_notice.visible = false
	layer.add_child(save_status_notice)
	get_viewport().size_changed.connect(_layout_hud_panels)
	_layout_hud_panels()


func _return_to_main_menu() -> void:
	if not bool(get_meta("save_load_blocked", false)) and not _save_progress():
		message = "存档写入失败，暂不离开；请按下方提示处理后重试。"
		_update_hud()
		return
	# Direct scene runs and injected test roots must survive Ark -> menu too.
	# Empty production roots explicitly clear stale session-only overrides.
	var tree := get_tree()
	if save_root_override.is_empty():
		if tree.has_meta("ark_menu_save_root_override"):
			tree.remove_meta("ark_menu_save_root_override")
	else:
		tree.set_meta("ark_menu_save_root_override", save_root_override)
	var change_error := tree.change_scene_to_file("res://scenes/main.tscn")
	if change_error != OK:
		message = "主界面暂时无法载入，当前仍停留在实地。"
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
		{"id": "moonback", "title": "月背泊地", "position": TIDE_STATION_POSITION, "risk": 2, "description": "东北旧栈桥可接船尾，低岸有漂木与鲜贝；北岸也可自行登陆\n" + ("潮枢已经取走，旧站台仍可辨认归航方向。" if tide_station_searched else "浅色步道沿西侧环坡通往高处蓝光；没有航线或等级门。")},
		{"id": "jade_sail_ark", "title": "琼华舫遗址", "position": JADE_SAIL_ARK_POSITION, "risk": 3, "description": "远海石脊上搁浅的豪华仙舟\n舱骨与迎客居室图样尚存；没有等级门或航线锁。"},
		{"id": "pressure_wreck", "title": "蒸潮机坞", "position": PRESSURE_WRECK_POSITION, "risk": 2, "description": "外海锈色礁岛上，一艘机关补给舫搁浅\n压力阀仍有微弱热汽；沿礁脊寻找可登陆处。"},
	]


func _toggle_world_chart() -> void:
	if hud_drawer:
		hud_drawer.hide()
	if world_chart == null:
		return
	remove_meta("manual_save_notice")
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
	return shelter_built and traveler_boarded and sailmaker_boarded and not resident_gather_pending and not resident_repair_pending and not sailing_mode and weather_phase != WeatherPhase.STORM and traveler_marker != null and is_instance_valid(traveler_marker) and sailmaker_marker != null and is_instance_valid(sailmaker_marker)


func _begin_shared_table_meal() -> void:
	if shared_meal_gathering_pending or stew_servings <= 0 or shared_meal_day == day_count or not _can_share_with_both_residents() or not _player_at_shared_table():
		return
	shared_meal_paused = false
	stew_servings -= 1
	shared_meal_day = day_count
	shared_meal_gathering_pending = true
	shared_meal_participants = ["player", "tidekeeper", "sailmaker"]
	traveler_action = "把热汤端到桌边"
	traveler_target_position = shelter_position + TIDEKEEPER_SHARED_MEAL_OFFSET
	sailmaker_action = "收起针线赴饭"
	sailmaker_target_position = shelter_position + SAILMAKER_SHARED_MEAL_OFFSET
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


func _player_at_shared_table() -> bool:
	if player == null or ark_root == null or not shelter_built or is_swimming:
		return false
	var local := ark_root.to_local(player.global_position)
	var center := shelter_position + Vector3(SHARED_MEAL_MAT_OFFSET.x, 0.19, SHARED_MEAL_MAT_OFFSET.z)
	return local.y >= shelter_position.y + 0.04 and absf(local.y - center.y) <= 0.45 and local.distance_to(center) <= 1.65 and _ark_local_walk_position_supported(Vector2(local.x, local.z))

func _shared_table_ready() -> bool:
	if not shared_meal_gathering_pending or shared_meal_paused or not _can_share_with_both_residents() or not _player_at_shared_table():
		return false
	if shared_meal_participants.size() != 3 or not shared_meal_participants.has("player") or not shared_meal_participants.has("tidekeeper") or not shared_meal_participants.has("sailmaker"):
		return false
	if traveler_marker.get_parent() != ark_root or sailmaker_marker.get_parent() != ark_root:
		return false
	if traveler_target_position.distance_to(shelter_position + TIDEKEEPER_SHARED_MEAL_OFFSET) > 0.2 or sailmaker_target_position.distance_to(shelter_position + SAILMAKER_SHARED_MEAL_OFFSET) > 0.2:
		return false
	return traveler_marker.position.distance_to(traveler_target_position) <= 0.09 and sailmaker_marker.position.distance_to(sailmaker_target_position) <= 0.09

func _pause_shared_table_meal() -> void:
	if not shared_meal_gathering_pending or shared_meal_paused:
		return
	shared_meal_paused = true
	_update_traveler_schedule()
	_update_sailmaker_schedule()
	_refresh_shared_meal_visuals()
	_save_progress()

func _interact_shared_table() -> void:
	if not _player_at_shared_table():
		return
	if shared_meal_paused:
		if not _can_share_with_both_residents():
			message = "汤还留在锅里。先避过风雨、停稳仙舟，等大家手里的事忙完。"
		else:
			shared_meal_paused = false
			_update_traveler_schedule()
			_update_sailmaker_schedule()
			_save_progress()
			message = "你揭开锅盖，招呼大家回来。等人到齐，再按 E 一起喝汤。"
	elif not _try_complete_shared_table_meal():
		message = "你的位置和热汤都留着。等大家来到桌边，再按 E 一起喝汤。"
	_update_hud()

func _try_complete_shared_table_meal() -> bool:
	if not _shared_table_ready():
		return false
	_complete_shared_table_meal()
	return true

func _complete_shared_table_meal() -> void:
	if not _shared_table_ready():
		return
	shared_meal_gathering_pending = false
	shared_meal_paused = false
	var reserved_day := shared_meal_day
	var meal_day := day_count
	shared_meal_count += 1
	var participants := shared_meal_participants.duplicate()
	var exposure_before_meal := _effective_cold_exposure_level()
	var health_before_meal := player_health
	var warmth_levels := 2 if pressure_galley_built else 1
	var exposure_after_meal := _relieve_cold_exposure("shared_hot_meal", warmth_levels)
	var health_restored := _restore_player_health("shared_hot_meal", 2 if pressure_galley_built else 1)
	var warmth_restored := exposure_after_meal < exposure_before_meal
	_record_world_event("resident_meal_shared", {"resident_id": "tidekeeper", "participant_ids": participants, "participant_count": participants.size(), "shared_table": true, "day": meal_day, "reserved_day": reserved_day, "meal_count": shared_meal_count, "cold_exposure_relieved": warmth_restored, "cold_exposure_levels": warmth_levels, "cold_exposure_level_after": exposure_after_meal, "health_before": health_before_meal, "health_after": player_health, "health_restored": health_restored, "tool_id": "pressure_galley" if pressure_galley_built else "hearth_pot"})
	if not resident_keepsake_present:
		resident_keepsake_present = true
		_add_resident_keepsake()
		_record_world_event("resident_keepsake_placed", {"resident_id": "tidekeeper", "artifact_id": "first_shared_meal_tide_shell", "day": meal_day, "trigger_event": "resident_meal_shared"})
	elif shared_meal_count == 2:
		_add_resident_keepsake()
		_record_world_event("resident_keepsake_pair_completed", {"resident_id": "tidekeeper", "artifact_id": "second_shared_meal_tide_shell", "day": meal_day, "shared_meal_count": shared_meal_count})
	shared_meal_day = maxi(shared_meal_day, day_count)
	traveler_action = "收拾饭后碗盏"
	traveler_target_position = shelter_position + TIDEKEEPER_SHARED_MEAL_OFFSET
	sailmaker_action = "收好饭碗与针线"
	sailmaker_target_position = shelter_position + SAILMAKER_SHARED_MEAL_OFFSET
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
	if _modules_ready:
		var remembered: Dictionary = memories.latest("resident_meal_shared")
		if not remembered.known:
			return false
		var participants: Variant = remembered.event.facts.get("participant_ids", [])
		return participants is Array and participants.has("sailmaker")
	for index in range(world_events.size() - 1, -1, -1):
		var event: Dictionary = world_events[index]
		if str(event.get("id", "")) != "resident_meal_shared":
			continue
		var facts: Dictionary = event.get("facts", {})
		var participants = facts.get("participant_ids", [])
		return participants is Array and participants.has("sailmaker")
	return false


func _interact() -> void:
	if sailing_mode:
		_toggle_sailing()
		return
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
	if shared_meal_gathering_pending and _player_at_shared_table() and str(nearest.get("id", "")) in ["resident", "sailmaker", "hearth"]:
		_interact_shared_table()
		return
	match str(nearest.id):
		"wood":
			if not _module_collect_direct(nearest):
				return
			var pile: Node = nearest.node
			var item_id := str(nearest.item_id)
			collected_ids.append(item_id)
			_record_world_event("resource_collected", {"node_id": item_id, "resource": "wood", "amount": int(nearest.amount)})
			interactables.erase(nearest)
			pile.queue_free()
			message = "你把潮水留下的木料拖上岸。它们还带着海盐和湿冷的气味。"
		"shellfish":
			if not _module_collect_direct(nearest):
				return
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
				elif stew_servings > 0 and shared_meal_day != day_count and not sailmaker_boarded and not sailing_mode and not resident_gather_pending and not resident_repair_pending and _player_at_shared_table():
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
					traveler_target_position = shelter_position + TIDEKEEPER_SHARED_MEAL_OFFSET
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
				elif weather_phase != WeatherPhase.STORM:
					resident_gather_policy_choice_pending = true
					message = "守潮人整理浮标箱：‘先看看家里缺什么，再决定去哪一处。木料和晚饭都够，就不必白跑。’\n当前方针：%s。\n1 木料优先　　2 鲜贝优先　　3 按家中缺口自动安排　　Esc 保持原安排\n%s\n只影响下一趟；一天最多一趟。家园受损时只在安全清晨补缺的修材，风暴和启航仍会停工或回来。" % [_resident_gather_policy_label(),home_demand.summary(self)]
				else:
					message = "守潮人看向西边云墙：‘等会儿风会转向。你决定怎么用那条绳，我都能帮着打结。’"
			elif shelter_built:
				if _can_board_resident("tidekeeper"):
					traveler_choice_pending = true
					message = "守潮人看了看棚顶和岸边的旧浮标箱。‘我可以在这里避一晚，但不想欠下没说清的承诺。’\n1 邀请上筏，共同过夜　　2 尊重对方，暂不同行"
				else:
					message = "守潮人愿意同行，但仙舟的避难接纳名额已满。扩建出新的住处后，再来邀请她；她不会因此离开这片海岸。"
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
					message = "缝帆人愿意同行，但仙舟的避难接纳名额已满。扩建出新的住处后，再来邀请她；她会留在这片海域继续缝帆。"
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
		"ridge_camp":
			_search_ridge_camp()
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
			_salvage_modern_utilities()
		"modern_wash":
			_use_modern_wash()
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
					if not economy.transfer("jade_sail", "player", {"wood": withdrawn_wood, "shellfish": withdrawn_shellfish}, "transfer:%d" % Time.get_ticks_usec()).ok:
						return
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
	if str(nearest.id) in ["resident","sailmaker"] and weather_phase != WeatherPhase.STORM:
		var actor := "tidekeeper" if str(nearest.id) == "resident" else "sailmaker"
		var reflection: String = resident_washing.reflection(self,actor)
		if not reflection.is_empty(): message += "\n\n"+reflection
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
	var selected_priority := 99
	var preferred_resource := "wood" if jade_sail_industry_acquired and jade_sail_industry_deliveries % 2 == 0 else "shellfish"
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
		var priority := 0 if resource == preferred_resource else 1
		if distance < JADE_INDUSTRY_GATHER_RADIUS and (priority < selected_priority or (priority == selected_priority and distance < selected_distance)):
			selected = entry
			selected_distance = distance
			selected_priority = priority
	if selected.is_empty():
		_record_world_event("jade_sail_industry_gather_unavailable", {"vessel_id": "jade_sail_ark", "day": day_count, "reason": "no_uncollected_local_supply"})
		return false
	_module_seed_sources()
	var dispatched: Dictionary = gathering.dispatch("ruan_qingyi", str(selected.get("item_id", "")), "jade_sail")
	if not dispatched.ok:
		return false
	jade_task_id = str(dispatched.task_id)
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
	var returning := jade_sail_industry_phase == "returning"
	if returning:
		target_position = JADE_INDUSTRY_HOME_POSITION
	else:
		target_position.y = jade_sail_keeper_marker.global_position.y
	var offset := target_position - jade_sail_keeper_marker.global_position
	# Pickup may stop nearby; a normal delivery must pay for the full 3D home leg.
	var arrival_tolerance := 0.0 if returning else 0.06
	var moving := offset.length() > arrival_tolerance
	if moving:
		var old_position := jade_sail_keeper_marker.global_position
		var moved: Dictionary = gathering.advance_route(old_position, PackedVector3Array([target_position]), 0, delta, JADE_INDUSTRY_GATHER_SPEED, arrival_tolerance)
		jade_sail_keeper_marker.global_position = moved.position
		if returning:
			moving = not bool(moved.arrived)
		var direction := Vector3(offset.x, 0.0, offset.z).normalized()
		if not direction.is_zero_approx() and (not returning or jade_sail_keeper_marker.global_position != old_position):
			jade_sail_keeper_marker.rotation.y = atan2(direction.x, direction.z)
	if jade_sail_industry_phase == "outbound" and not moving:
		if not gathering.mark_collecting(jade_task_id):
			return false
		jade_sail_industry_phase = str(gathering.task(jade_task_id).phase)
		jade_sail_industry_pickup_remaining = float(gathering.collection_tick(jade_task_id, 0.0).remaining)
		jade_sail_keeper_action = "采集潮池鲜贝"
		_update_jade_sail_keeper_nameplate()
		_save_progress()
	elif jade_sail_industry_phase == "collecting":
		var collection: Dictionary = gathering.collection_tick(jade_task_id, maxf(0.0, delta))
		jade_sail_industry_pickup_remaining = float(collection.remaining)
		if collection.ok and collection.complete:
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
		var harvested: Dictionary = gathering.harvest(jade_task_id)
		if not harvested.ok:
			return
		var amount := int(harvested.payload.amount)
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
	if jade_sail_industry_payload > 0:
		if not gathering.deliver(jade_task_id).ok:
			return
	else:
		gathering.cancel(jade_task_id, delivery_mode)
	var target_id := jade_sail_industry_target_id
	var resource := jade_sail_industry_resource
	var amount := jade_sail_industry_payload
	jade_sail_industry_pending = false
	jade_sail_industry_phase = ""
	jade_sail_industry_resource = ""
	jade_sail_industry_target_id = ""
	jade_sail_industry_payload = 0
	jade_sail_industry_pickup_remaining = 0.0
	# Only emergency/cancellation recalls place the keeper without walking.
	if delivery_mode != "vessel_hold":
		jade_sail_keeper_marker.global_position = JADE_INDUSTRY_HOME_POSITION
	jade_sail_keeper_action = "整理琼华舫货舱"
	if amount > 0:
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
	gathering.cancel(jade_task_id, reason)
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
				message = "仙舟现在可以掌舵出航，也可先加固备雨。手里只有一条好绳：\n1 固定避风棚　　2 固定筏舷　　3 暂不使用，接受风雨损伤"
		else:
				message = "风雨尚未抵岸，仙舟现在就能启航。手里只有一条好绳：\n1 固定筏舷　　2 暂不使用，之后可能要修筏"
		return
	if weather_phase == WeatherPhase.FORECAST:
		message = "风雨还未抵岸，完好的仙舟现在就能启航：到船尾舵位按 E，靠岸后再按 E 停船，上岸采集后把木料带回船上营造。M 查看远礁沉筏与航路；不必先推进风雨。\n" + _opening_objective_hint()
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
		message = "饭釜里还留着余温。潮池的鲜贝已经吃完，下一次清晨退潮会为采空且无人搬运的潮池补回一批鲜贝。" if pressure_galley_built else "火盆里还留着温度。潮池的鲜贝已经吃完，下一次清晨退潮会为采空且无人搬运的潮池补回一批鲜贝。"
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


func _life_clock_paused() -> bool:
	if not _modules_ready or _restoring_progress or get_tree().paused or building_mode or not editing_fixture_id.is_empty():
		return true
	if (hud_drawer != null and hud_drawer.visible) or (world_chart != null and world_chart.visible):
		return true
	return _hud_choice_open()


func _tick_life_clock(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or _life_clock_paused():
		return
	# Do not turn an OS suspend / stalled frame into days of catch-up production.
	var step := minf(delta, 1.0)
	_advance_modern_utilities(minf(step,LIFE_PERIOD_SECONDS-life_period_elapsed))
	life_period_elapsed += step
	if life_period_elapsed < LIFE_PERIOD_SECONDS:
		return
	var advancement := _advance_world_period("life_clock")
	message = "天色渐变，现在是%s。" % _day_period_label()
	_append_period_outcomes(advancement)
	_save_progress()
	_update_hud()


func _spawn_shore_supply(supply: Array) -> void:
	if supply[1] == "wood":
		_add_pile(supply[0], supply[2], supply[3])
	else:
		_add_shellfish_patch(supply[0], supply[2], supply[3])
	opening_coast.ground_resource(get_node_or_null(str(supply[0])) as Node3D)
	if moonback_terrain.initialized: moonback_landing.ground_source(get_node_or_null(str(supply[0])) as Node3D,ground_sampler)


func _replenish_shore_supplies() -> int:
	if day_period != DayPeriod.MORNING or day_count <= last_shore_replenish_day:
		return 0
	last_shore_replenish_day = day_count
	var replenished := 0
	for supply in SHORE_SUPPLIES:
		var id: String = supply[0]
		if not collected_ids.has(id) or gathering.source_in_use(id):
			continue
		var result: Dictionary = economy.replenish_source(id, supply[1], supply[3], "shore_renewal:%d:%s" % [day_count, id])
		if not result.ok or result.get("duplicate", false):
			continue
		collected_ids.erase(id)
		# A same-frame pickup may still have its queued node attached.
		var old_node := get_node_or_null(NodePath(id))
		if old_node != null and old_node.is_queued_for_deletion():
			remove_child(old_node)
		_spawn_shore_supply(supply)
		_record_world_event("shore_supply_replenished", {"node_id":id,"resource":supply[1],"amount":supply[3],"day":day_count,"source":"dawn_tide"})
		replenished += 1
	return replenished


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
	_advance_modern_utilities(maxf(0.0,LIFE_PERIOD_SECONDS-life_period_elapsed))
	life_period_elapsed = 0.0
	_pause_shared_table_meal()
	var resident_prepared_meal := _complete_resident_cooking()
	var previous_day := day_count
	day_period = (day_period + 1) % 4
	if day_period == DayPeriod.MORNING:
		day_count += 1
	_set_weather_visuals()
	var storm_forecast_became_due := day_period == DayPeriod.MORNING and previous_day < next_storm_day and day_count >= next_storm_day and weather_phase == WeatherPhase.AFTER
	_record_world_event("time_advanced", {"cause": cause, "day": day_count, "period": day_period})
	var replenished_sites := _replenish_shore_supplies() if day_period == DayPeriod.MORNING else 0
	var sailmaker_awning_ready := day_period == DayPeriod.MORNING and sailmaker_boarded and not sailmaker_awning_raised and sailmaker_awning_phase == "unstarted" and day_count == sailmaker_joined_day + 1
	var repaired_part := _complete_resident_repair()
	var resident_gather_started := _begin_resident_daily_gather() if day_period == DayPeriod.MORNING else false
	var jade_industry_gather_started := _begin_jade_sail_industry_daily_gather() if day_period == DayPeriod.MORNING else false
	_update_traveler_schedule()
	_update_sailmaker_schedule()
	return {
		"replenished_sites": replenished_sites,
		"resident_prepared_meal": resident_prepared_meal,
		"sailmaker_awning_ready": sailmaker_awning_ready,
		"repaired_part": repaired_part,
		"resident_gather_started": resident_gather_started,
		"jade_industry_gather_started": jade_industry_gather_started,
		"storm_forecast_became_due": storm_forecast_became_due,
	}


func _append_period_outcomes(advancement: Dictionary) -> void:
	if int(advancement.get("replenished_sites", 0)) > 0:
		message += "\n清晨退潮带来了新漂木，也露出新一批鲜贝；已采空且无人搬运的岸边物资点各补回一批，不会囤叠。"
	var repaired_part := str(advancement.get("repaired_part", ""))
	if not repaired_part.is_empty():
		message += "\n守潮人用储物箱里的木料修好了%s。" % repaired_part
	if bool(advancement.get("resident_prepared_meal", false)):
		message += "\n守潮人守着火候煮好了潮滩鲜贝汤，留了一碗给你。"
	if bool(advancement.get("sailmaker_awning_ready", false)):
		message += "\n缝帆人取出了自带的旧帆边，打算闲下来时缝成一片雨檐；还要缝好、带到棚下并亲手安上。"
	if bool(advancement.get("resident_gather_started", false)):
		message += "\n守潮人看见仙舟泊在可步行抵达的岸边，自动去收集附近现存的%s；她会把东西带回船上，不会阻止你启航。" % ("漂木" if resident_gather_resource == "wood" else "潮池鲜贝")
	if bool(advancement.get("jade_industry_gather_started", false)):
		message += "\n阮青漪带着货篓离开琼华舫，去采集最近一处尚未被取走的潮池鲜贝；这趟营生只影响琼华舫自己的货舱。"
	if bool(advancement.get("storm_forecast_became_due", false)):
		message += "\n海面风向又变了：第二场风雨的预报已经抵达。它不会强迫你停下行程；查看仙舟状况后，按 R 可等它来临。"


func _storm_forecast_due() -> bool:
	return weather_phase == WeatherPhase.AFTER and resolved_storm_count > 0 and next_storm_day > 0 and day_count >= next_storm_day


func _complete_resident_cooking() -> bool:
	return resident_kitchen.complete(self)


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
		var deposited := wood
		if not economy.transfer("player", "storage", {"wood": deposited}, "transfer:%d" % Time.get_ticks_usec()).ok:
			return
		message = "你把 %d 块木料收进储物箱，给下一次扩建留了余量。" % deposited
	elif stored_wood > 0:
		var withdrawn := stored_wood
		if not economy.transfer("storage", "player", {"wood": withdrawn}, "transfer:%d" % Time.get_ticks_usec()).ok:
			return
		message = "你从储物箱取出 %d 块木料，准备带去建造或修补。" % withdrawn
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
		elif pressure_cores < 1 or _available_build_wood() < PRESSURE_GALLEY_WOOD_COST:
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
	if not pressure_galley_choice_pending or sailing_mode:
		return
	pressure_galley_choice_pending = false
	if pressure_galley_built or not _has_blueprint("pressure_galley") or not shelter_built or pressure_cores < 1 or _available_build_wood() < PRESSURE_GALLEY_WOOD_COST:
		message = "饭釜安装条件已经变化，图样与材料仍保留；等家和材料都准备好后再来。"
	else:
		if not _spend_home_wood(PRESSURE_GALLEY_WOOD_COST, "pressure_galley"):
			return
		pressure_cores -= 1
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


func _stop_sailing_for_storm() -> void:
	if not sailing_mode:
		return
	sailing_mode = false
	_clear_player_knockback()
	if player:
		player.velocity = Vector3.ZERO
	_record_world_event("ark_sailing_stopped", {"position": _position_facts(ark_root.global_position), "reason": "storm_arrival"})


func _advance_weather() -> void:
	_pause_shared_table_meal()
	if weather_phase == WeatherPhase.FORECAST:
		preparation_choice_pending = false
		weather_phase = WeatherPhase.STORM
		_stop_sailing_for_storm()
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
		message = "云墙压过礁岛，风雨抵岸。仙舟暂不能掌舵，留在当前泊位；你仍可在岛上行动；圈外的寒意会随着暴露加深，可回仙舟或找棚下恢复。等风势稍缓后再按 R。"
	elif weather_phase == WeatherPhase.AFTER and _storm_forecast_due():
		weather_phase = WeatherPhase.STORM
		_stop_sailing_for_storm()
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
		message = "新一场风雨按预报抵岸，仙舟留在当前泊位，暂不能掌舵。你当初固定的绳结仍留在原处；未加固的结构仍要留心。圈外寒意会继续加深；等风势稍缓后再按 R。"
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
			"raft_protected_by_fenders": raft_fenders_installed,
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
	if rope_use != "raft" and not raft_fenders_installed:
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
	if _available_build_wood() < 1:
		message = "木料不够，先沿岸再找一块能用的板。"
	elif part == "shelter" and shelter_roof_damaged:
		if not _spend_home_wood(1, "repair_shelter"):
			return
		shelter_roof_damaged = false
		_cancel_resident_repair_if_player_repairs("shelter")
		_record_world_event("structure_repaired", {"part": part, "wood_spent": 1})
		var roof := _ark_node("BuiltShelter/Roof") as Node3D
		if roof:
			roof.visible = true
		message = "你用一块木料补回棚顶。屋里重新有了不漏雨的干燥角落。"
	elif part == "raft" and raft_edge_damaged:
		if not _spend_home_wood(1, "repair_raft"):
			return
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
			message = "你愿意邀请她，但眼下没有空余避难名额。守潮人理解地点有限，先留在岸边；扩建后仍可再谈。"
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
			message = "你愿意邀请她，但眼下没有空余避难名额。缝帆人不勉强同行；扩建后仍可再谈。"
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
			opening_coast.reset_shore_offset(marker)
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
	opening_coast.reset_shore_offset(tidekeeper_box_marker)
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
			opening_coast.reset_shore_offset(marker)
			marker.position = Vector3(1.15, 0.12, 0.75)
			_update_sailmaker_schedule()
		return


func _resident_capacity() -> int:
	# Acceptance capacity includes temporary refuge; it is not a bed count.
	return _resident_temporary_refuge_capacity() + _resident_berth_capacity()


func _resident_temporary_refuge_capacity() -> int:
	return 2 if shelter_built else 0


func _resident_berth_capacity() -> int:
	# Derive from existing structures, without new ownership or save state.
	# The original Cot is reserved for the player and is never counted here.
	if not shelter_built or not raft_extension_built:
		return 0
	return 1 + int(guest_cabin_built)


func _resident_occupancy() -> int:
	return int(traveler_boarded) + int(sailmaker_boarded)


func _can_board_resident(resident_id: String) -> bool:
	if resident_id == "tidekeeper" and traveler_boarded:
		return true
	if resident_id == "sailmaker" and sailmaker_boarded:
		return true
	return shelter_built and _resident_occupancy() < _resident_capacity()


func _begin_resident_daily_gather() -> bool:
	if not traveler_boarded or not is_instance_valid(traveler_marker) or resident_gather_pending or resident_repair_pending or kitchen.carrying() or sailing_mode or day_period != DayPeriod.MORNING or _life_clock_paused():
		return false
	if day_count <= resident_gather_last_day or weather_phase == WeatherPhase.STORM or not shelter_built:
		return false
	var demand: Dictionary = home_demand.review(self)
	if not demand.ok or demand.blocked: return false
	var target_entry: Dictionary = {}
	var target_route := PackedVector3Array()
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
		if resource_id=="shellfish" and food_storage.fixture(self)!=null and not economy.can_accept(FoodStorageRules.OWNER,{"shellfish":int(entry.get("amount",0))}):
			continue # A full pantry does not dispatch another food load or block wood work.
		var distance := ark_root.global_position.distance_to(node.global_position)
		if distance > RESIDENT_AUTO_GATHER_RADIUS:
			continue
		var priority: int = home_demand.Rules.priority(demand,resident_gather_policy,resource_id)
		if priority<0: continue
		if priority < best_priority or (priority == best_priority and distance < best_distance):
			var candidate_route := PackedVector3Array()
			if RegionalRouteScript.handles(node.global_position):
				var request := _request_regional_route("source:"+item_id,traveler_marker.global_position,node.global_position)
				if not request.ready: return false
				candidate_route = request.route
				if candidate_route.is_empty():
					continue
			best_priority = priority
			best_distance = distance
			target_entry = entry
			target_route = candidate_route
	if target_entry.is_empty():
		return false
	_module_seed_sources()
	var dispatched: Dictionary = gathering.dispatch("tidekeeper", str(target_entry.get("item_id", "")), "player")
	if not dispatched.ok:
		return false
	resident_task_id = str(dispatched.task_id)
	var target_node := target_entry.get("node") as Node3D
	resident_gather_pending = true
	resident_gather_phase = "outbound"
	traveler_routine_route.clear()
	traveler_routine_route_index = 0
	traveler_routine_route_target_set = false
	resident_gather_target_id = str(target_entry.get("item_id", ""))
	resident_gather_resource = str(target_entry.get("id", ""))
	resident_gather_target_position = target_node.global_position
	resident_gather_route = target_route
	resident_gather_route_index = 1 if target_route.size() > 1 else 0
	resident_gather_payload = 0
	resident_gather_pickup_remaining = RESIDENT_AUTO_GATHER_PICKUP_SECONDS
	resident_gather_last_day = day_count
	if traveler_marker.get_parent() != self:
		traveler_marker.reparent(self, true)
	traveler_action = "近岸采集"
	var sign := traveler_marker.get_node_or_null("Name") as Label3D
	if sign:
		sign.text = "守潮人 · 近岸采集"
	var need_id: String = home_demand.Rules.reason(demand,resident_gather_policy,resident_gather_resource)
	_record_world_event("resident_gather_started", {"resident_id": "tidekeeper", "resource": resident_gather_resource, "target_id": resident_gather_target_id, "day": day_count, "policy": resident_gather_policy, "target_position": _position_facts(resident_gather_target_position),"need_id":need_id,"food_available":demand.food_available,"food_target":demand.food_target,"wood_available":demand.wood_available,"wood_target":demand.wood_target,"repair_need":demand.repair_need})
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
		_: return "按家中缺口自动安排"


func _process_resident_gathering(delta: float) -> bool:
	if not resident_gather_pending or traveler_marker == null or not is_instance_valid(traveler_marker):
		return false
	if food_storage.pending: return false
	if weather_phase == WeatherPhase.STORM:
		_abort_resident_gathering("storm_arrival")
		return false
	var target_position := resident_gather_target_position
	var returning := resident_gather_phase == "returning"
	if returning:
		var depot := _resident_storage_delivery_station()
		if _resident_uses_storage() and depot.is_empty():
			traveler_action = "等候储箱使用面空出"
			_update_gatherer_nameplate()
			return false
		target_position = ark_root.to_global(depot.target if not depot.is_empty() else RESIDENT_DECK_POSITION)
		# A cached world route must still end at the ark's current home point.
		if not resident_gather_route.is_empty() and resident_gather_route[-1] != target_position:
			resident_gather_route.clear()
		if _resident_uses_storage() and traveler_marker.global_position.distance_to(target_position)<=.00001:
			_finish_resident_gathering("ark_return")
			return false
	if resident_gather_route.is_empty():
		if RegionalRouteScript.handles(traveler_marker.global_position) and Time.get_ticks_msec() < resident_regional_route_retry_at:
			return false
		if RegionalRouteScript.handles(traveler_marker.global_position) or RegionalRouteScript.handles(target_position):
			var request := _request_regional_route("active:"+resident_gather_phase,traveler_marker.global_position,target_position)
			if not request.ready: return false
			resident_gather_route = request.route
		else:
			resident_gather_route = _build_storage_return_route(traveler_marker.global_position,target_position) if returning and _resident_uses_storage() else _build_resident_walk_route(traveler_marker.global_position, target_position)
		if resident_gather_route.is_empty():
			if RegionalRouteScript.handles(traveler_marker.global_position) or (returning and _resident_uses_storage()):
				# Lost landing access is not remote delivery. Keep the actual task and
				# any carried cargo, wait, then plan again from the resident's position.
				resident_regional_route_retry_at = Time.get_ticks_msec()+500
				traveler_action = "等候安全通路"
				_update_gatherer_nameplate()
				return false
			_abort_resident_gathering("no_safe_route")
			return false
		# The shared planner's short pickup tolerance is not a delivery radius.
		if returning and resident_gather_route[-1] != target_position:
			resident_gather_route.append(target_position)
		resident_gather_route_index = 1 if resident_gather_route.size() > 1 else 0
	var old_position := traveler_marker.global_position
	var regional_trip := RegionalRouteScript.handles(old_position)
	var movement: Dictionary = gathering.advance_route(old_position, resident_gather_route, resident_gather_route_index, delta, RESIDENT_AUTO_GATHER_SPEED, 0.0 if returning or regional_trip else 0.22)
	if regional_trip:
		var guard := RegionalRouteScript.new()
		guard.configure(self)
		if not guard.can_move(old_position,movement.position):
			resident_gather_route.clear()
			resident_regional_route_retry_at = Time.get_ticks_msec()+500
			return false
	traveler_marker.global_position = movement.position
	resident_gather_route_index = int(movement.index)
	var moving := not bool(movement.arrived)
	var direction: Vector3 = movement.position - old_position
	if direction.length_squared() > 0.000001:
		traveler_marker.rotation.y = atan2(direction.x, direction.z)
	if resident_gather_phase == "outbound" and not moving:
		if not gathering.mark_collecting(resident_task_id):
			return false
		resident_gather_phase = str(gathering.task(resident_task_id).phase)
		resident_gather_pickup_remaining = float(gathering.collection_tick(resident_task_id, 0.0).remaining)
		traveler_action = "拾取" + ("漂木" if resident_gather_resource == "wood" else "鲜贝")
		_update_gatherer_nameplate()
		_save_progress()
	elif resident_gather_phase == "collecting":
		var collection: Dictionary = gathering.collection_tick(resident_task_id, maxf(0.0, delta))
		resident_gather_pickup_remaining = float(collection.remaining)
		if collection.ok and collection.complete:
			_harvest_resident_gather_target()
	elif resident_gather_phase == "returning" and not moving:
		_finish_resident_gathering("ark_return")
	return moving




func _build_storage_return_route(start: Vector3,target: Vector3) -> PackedVector3Array:
	# The shore ray grid sees a roof as a tall blocker. Reach the established
	# boarding point first, then use the actual furniture-aware deck planner;
	# do not force open an isolated chest cell or deliver across a wall.
	var boarding: Vector3 = ark_root.to_global(RESIDENT_DECK_POSITION)
	var local_start: Vector3 = ark_root.to_local(start)
	var aboard: bool = _ark_local_walk_position_supported(Vector2(local_start.x,local_start.z)) and absf(local_start.y-.12)<.4
	var route := PackedVector3Array([start]) if aboard else _build_resident_walk_route(start,boarding)
	if route.is_empty(): return route
	if aboard and start.distance_to(target)<=.06 and resident_washing.walk_step_clear(self,local_start,ark_root.to_local(target)):
		route.append(target) # Even the last centimetre must spend walking budget.
		return route
	var local_route := _build_ark_local_walk_route(local_start if aboard else RESIDENT_DECK_POSITION,ark_root.to_local(target),true)
	if local_route.is_empty(): return PackedVector3Array()
	for point in local_route:
		var world: Vector3 = ark_root.to_global(point)
		if route[-1].distance_to(world)>.00001: route.append(world)
	return route


func _build_resident_walk_route(start: Vector3, destination: Vector3) -> PackedVector3Array:
	if RegionalRouteScript.handles(start) or RegionalRouteScript.handles(destination):
		var regional := RegionalRouteScript.new()
		regional.configure(self)
		return regional.build(start,destination)
	var route := PackedVector3Array()
	if not start.is_finite() or not destination.is_finite():
		return route
	for endpoint in [start, destination]:
		if absf(endpoint.x) > PLAYER_WORLD_EDGE_LIMIT or absf(endpoint.z) > PLAYER_WORLD_EDGE_LIMIT:
			return route
	# Gathering is a near-shore trip, never a world-sized grid allocation.
	# This also bounds work when interrupted or malformed task state is resumed.
	if absf(destination.x - start.x) > RESIDENT_ROUTE_MAX_SPAN or absf(destination.z - start.z) > RESIDENT_ROUTE_MAX_SPAN:
		return route
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


func _request_regional_route(key: String, start: Vector3, target: Vector3) -> Dictionary:
	var job: Dictionary = resident_regional_route_jobs.get(key,{})
	var expired: bool = not job.is_empty() and job.planner.done and job.planner.result.is_empty() and Time.get_ticks_msec() >= int(job.retry_at)
	if expired:
		for other in resident_regional_route_jobs:
			# Let a fallback candidate finish before retrying an earlier unreachable
			# source; otherwise a slow time-sliced fallback can be starved forever.
			if other != key and not resident_regional_route_jobs[other].planner.done:
				expired = false
				break
	if job.is_empty() or expired or start.distance_to(job.get("start",start)) > .10 or target != job.get("target",target) or ark_root.global_transform != job.get("ark",ark_root.global_transform):
		var planner := RegionalRouteScript.new()
		planner.configure(self)
		planner.begin(start,target)
		job = {"planner":planner,"start":start,"target":target,"ark":ark_root.global_transform,"retry_at":Time.get_ticks_msec()+500}
		if resident_regional_route_jobs.size() >= 4: resident_regional_route_jobs.clear()
		resident_regional_route_jobs[key] = job
	var was_done: bool = job.planner.done
	job.planner.step(1500)
	if not was_done and job.planner.done: job.retry_at = Time.get_ticks_msec()+500
	return {"ready":job.planner.done,"route":job.planner.result}


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
		var harvested: Dictionary = gathering.harvest(resident_task_id)
		if not harvested.ok:
			return
		var amount := int(harvested.payload.amount)
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




func _resident_uses_storage() -> bool:
	return resident_gather_resource in ["wood","shellfish"] and storage_built

func _resident_storage_delivery_station() -> Dictionary:
	return food_storage.station(self) if _resident_uses_storage() else {}

func _finish_resident_gathering(delivery_mode: String) -> void:
	if not resident_gather_pending:
		return
	var recipient := "player"
	if resident_gather_payload > 0:
		recipient = ("storage" if resident_gather_resource=="wood" else FoodStorageRules.OWNER) if _resident_uses_storage() else "player"
		if delivery_mode=="ark_return" and _resident_uses_storage():
			var station := _resident_storage_delivery_station()
			if station.is_empty() or traveler_marker.global_position.distance_to(ark_root.to_global(station.target))>.09: return
		gathering.set_destination(resident_task_id, recipient)
		if not gathering.deliver(resident_task_id).ok:
			if recipient==FoodStorageRules.OWNER:
				traveler_action = "储粮格已满，等家里腾出空位"
				_update_gatherer_nameplate()
			return
	else:
		gathering.cancel(resident_task_id, delivery_mode)
	if traveler_marker != null and is_instance_valid(traveler_marker):
		if traveler_marker.get_parent() != ark_root:
			traveler_marker.reparent(ark_root, true)
		# Ordinary arrival already walked home; transfer ownership, not position.
		if delivery_mode != "ark_return":
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
		var delivery_destination := "ark_storage" if recipient=="storage" else "food_storage" if recipient==FoodStorageRules.OWNER else "available_supplies" if resource_id=="wood" else "available_food"
		_record_world_event("resident_gather_delivered", {"resident_id": "tidekeeper", "target_id": target_id, "resource": resource_id, "amount": amount, "delivery_mode": delivery_mode, "destination": delivery_destination,"inventory_owner":recipient})
		var destination_label := "可用木料堆" if delivery_destination == "available_supplies" else "防潮储物箱" if delivery_destination == "ark_storage" else "家庭储粮格" if delivery_destination=="food_storage" else "随身行囊"
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
	gathering.cancel(resident_task_id, reason)
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
	if shared_meal_gathering_pending and not shared_meal_paused and weather_phase != WeatherPhase.STORM and shared_meal_participants.has("tidekeeper"):
		traveler_action = "把热汤端到桌边"
		traveler_target_position = shelter_position + TIDEKEEPER_SHARED_MEAL_OFFSET
	elif resident_repair_pending and resident_repair_part == "raft_edge":
		traveler_action = "修补筏舷"
		traveler_target_position = Vector3(0.2, 0.12, -1.55)
	elif resident_repair_pending and resident_repair_part == "shelter_roof":
		traveler_action = "整理棚顶"
		traveler_target_position = Vector3(0.8, 0.12, 1.05)
	elif weather_phase == WeatherPhase.STORM:
		traveler_action = "棚下避雨"
		traveler_target_position = shelter_position + TIDEKEEPER_REFUGE_REST_OFFSET
	elif raft_edge_damaged:
		traveler_action = "查看筏舷"
		traveler_target_position = Vector3(0.2, 0.12, -1.55)
	elif shelter_roof_damaged:
		traveler_action = "整理帆布"
		traveler_target_position = Vector3(0.8, 0.12, 1.05)
	elif resident_washing.selected(self,"tidekeeper"):
		traveler_action = "在水台净手" if resident_washing.routine.phase == "washing" else "去水台洗漱"
		traveler_target_position = ModernUtilityProps.APPROACH
	elif resident_kitchen.environment_ready(self) and (kitchen.active() or kitchen.can_begin(day_count)):
			traveler_action = resident_kitchen.action(self)
			traveler_target_position = resident_kitchen.destination(self).target
	elif day_period == DayPeriod.EVENING and shared_meal_day == day_count:
			traveler_action = "收拾饭后碗盏"
			traveler_target_position = shelter_position + TIDEKEEPER_SHARED_MEAL_OFFSET
	elif day_period == DayPeriod.NIGHT and shelter_built:
		if raft_extension_built and _ark_node("BuiltRaftExtension/Berth") != null:
			traveler_action = "甲板铺位歇息"
			traveler_target_position = Vector3(0.95, 0.24, -5.35)
		else:
			traveler_action = "棚下临时歇脚"
			traveler_target_position = shelter_position + TIDEKEEPER_REFUGE_REST_OFFSET
	elif day_period == DayPeriod.EVENING:
		traveler_action = "照看灯火"
		traveler_target_position = Vector3(0.8, 0.12, -0.35)
	elif day_period == DayPeriod.DAY:
		traveler_action = "整理浮标箱"
		traveler_target_position = Vector3(1.12, 0.12, -0.33)
	else:
		traveler_action = "查看潮势"
		traveler_target_position = Vector3(0.5, 0.12, 1.35)
	if not resident_washing.selected(self,"tidekeeper") and not resident_kitchen.selected(self):
		traveler_target_position = _fixture_safe_routine_target(traveler_target_position)
		traveler_target_position = resident_washing.safe_idle_target(self,traveler_target_position)
	var sign := traveler_marker.get_node_or_null("Name") as Label3D
	if sign:
		sign.text = "守潮人 · %s" % traveler_action


func _update_sailmaker_schedule() -> void:
	if not sailmaker_boarded or sailmaker_marker == null or not is_instance_valid(sailmaker_marker):
		return
	if shared_meal_gathering_pending and not shared_meal_paused and weather_phase != WeatherPhase.STORM and shared_meal_participants.has("sailmaker"):
		sailmaker_action = "收起针线赴饭"
		sailmaker_target_position = shelter_position + SAILMAKER_SHARED_MEAL_OFFSET
	elif weather_phase == WeatherPhase.STORM:
		sailmaker_action = "收拢旧帆"
		sailmaker_target_position = shelter_position + SAILMAKER_REFUGE_REST_OFFSET
	elif _household_work_can_run():
		sailmaker_target_position = _household_work_target()
		sailmaker_action = "在工坊整备木楔" if household_work.phase == "prepare" else "修补棚顶" if household_work.part == "shelter_roof" else "修补筏舷"
	elif household_work.active() and day_period == DayPeriod.NIGHT:
		sailmaker_action = "在听潮客舱歇息" if guest_cabin_built and raft_extension_built else "棚下临时歇脚"
		sailmaker_target_position = GUEST_CABIN_SAILMAKER_POSITION if guest_cabin_built and raft_extension_built else shelter_position + SAILMAKER_REFUGE_REST_OFFSET
	elif raft_edge_damaged or shelter_roof_damaged:
		sailmaker_action = "检查帆缆"
		sailmaker_target_position = Vector3(1.45, 0.12, -1.25)
	elif day_period == DayPeriod.NIGHT and guest_cabin_built and raft_extension_built:
		sailmaker_action = "在听潮客舱歇息"
		sailmaker_target_position = GUEST_CABIN_SAILMAKER_POSITION
	elif day_period == DayPeriod.NIGHT:
		sailmaker_action = "棚下临时歇脚"
		sailmaker_target_position = shelter_position + SAILMAKER_REFUGE_REST_OFFSET
	elif _sailmaker_awning_work_can_run():
		var installing := sailmaker_awning_phase in ["carrying", "installing"]
		sailmaker_target_position = _sailmaker_awning_work_target(installing)
		if installing:
			sailmaker_action = "把旧帆雨檐系在棚下" if sailmaker_awning_phase == "installing" and _sailmaker_at_awning_work_target(sailmaker_target_position) else "抱着缝好的雨檐去棚下"
		else:
			sailmaker_action = "用自带的旧帆边缝雨檐" if sailmaker_awning_phase == "sewing" and _sailmaker_at_awning_work_target(sailmaker_target_position) else "带上针线去缝雨檐"
	elif resident_washing.selected(self,"sailmaker"):
		sailmaker_action = "在水台净手" if resident_washing.routine.phase == "washing" else "去水台洗漱"
		sailmaker_target_position = ModernUtilityProps.APPROACH
	elif day_period == DayPeriod.EVENING:
		sailmaker_action = "晾晒补好的帆布"
		sailmaker_target_position = Vector3(1.05, 0.12, -0.95)
	elif weather_phase == WeatherPhase.FORECAST and day_period == DayPeriod.MORNING:
		sailmaker_action = "看云脚收帆"
		sailmaker_target_position = Vector3(1.1, 0.12, 1.25)
	else:
		sailmaker_action = "缝补旧帆"
		sailmaker_target_position = Vector3(1.35, 0.12, -0.75)
	# A work facility is never substituted by a generic safe routine fallback.
	if not _sailmaker_awning_work_can_run() and not _household_work_can_run() and not resident_washing.selected(self,"sailmaker"):
		sailmaker_target_position = _fixture_safe_routine_target(sailmaker_target_position)
		sailmaker_target_position = resident_washing.safe_idle_target(self,sailmaker_target_position)
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


func _open_household_work_board() -> void:
	if building_mode or sailing_mode or _hud_choice_open() or (world_chart and world_chart.visible):
		return
	if hud_drawer: hud_drawer.hide()
	household_work_choice_pending = true
	message = _room_use_summary() + "\n\n缝帆人：‘若你愿意，我平日替家里修补。修好一处才用储箱 1 块木料；你的随身材料不动。守潮人已接手的地方，我不重复做。’\n1 允许日常修缮　2 暂停自动修缮　Esc 保持原安排"
	_update_hud()


func _choose_household_work(allow: bool) -> void:
	if not household_work_choice_pending:
		return
	household_work_choice_pending = false
	if allow and not _household_facilities_present():
		message = "先建好起居棚、储物箱和工作台，并邀请缝帆人登船，再一起安排家务。"
	else:
		household_work.enabled = allow
		_record_world_event("resident_household_policy_changed", {"resident_id": "sailmaker", "enabled": allow, "wood_source": "storage", "wood_per_repair": 1})
		message = "缝帆人接下了家中的日常修缮。工作台整备、受损处安装，修好才扣储木；风雨、航行、夜歇和共餐时会停工。" if allow else "缝帆人收下你的安排。自动修缮已暂停，未完的手艺进度保留，没有预扣木料。"
	_update_sailmaker_schedule()
	_save_progress()
	_update_hud()


func _household_facilities_present() -> bool:
	if not sailmaker_met or not sailmaker_boarded or ark_root == null or not RoomRoles.available("workshop",_room_role_facts()):
		return false
	for path in ["BuiltShelter", "BuiltStorage", "BuiltWorkbench"]:
		var facility := _ark_node(path) as Node3D
		if facility == null or facility.get_parent() != ark_root or not facility.is_inside_tree() or not facility.is_visible_in_tree() or facility.process_mode == Node.PROCESS_MODE_DISABLED:
			return false
	return true


func _household_part_available(part: String) -> bool:
	if resident_repair_pending and resident_repair_part == part:
		return false
	return shelter_roof_damaged if part == "shelter_roof" else raft_edge_damaged if part == "raft_edge" else false


func _reconcile_household_work() -> void:
	# Never reserve/debit materials before completion, so cancellation needs no
	# synthetic refund. Actual node absence during rebuilding merely pauses work.
	if household_work.active() and (not _household_part_available(household_work.part) or not (sailmaker_boarded and shelter_built and storage_built and workbench_built)):
		var part: String = household_work.part
		household_work.cancel()
		household_work_route_retry = 0.0
		sailmaker_routine_route_target_set = false
		_record_world_event("resident_household_work_cancelled", {"resident_id": "sailmaker", "part": part, "wood_spent": 0, "reason": "target_resolved_or_assigned_or_facility_removed"})
	if household_work.enabled and not (sailmaker_boarded and shelter_built and storage_built and workbench_built):
		household_work.enabled = false


func _household_work_environment_ready() -> bool:
	return household_work.enabled and _household_facilities_present() and not _restoring_progress and not get_tree().paused and weather_phase != WeatherPhase.STORM and not sailing_mode and not building_mode and day_period != DayPeriod.NIGHT and not _hud_choice_open() and not (hud_drawer and hud_drawer.visible) and not (world_chart and world_chart.visible) and not (shared_meal_gathering_pending and not shared_meal_paused and shared_meal_participants.has("sailmaker"))


func _try_begin_household_work() -> void:
	if household_work.active() or not _household_work_environment_ready() or stored_wood < 1:
		return
	var part := "shelter_roof" if _household_part_available("shelter_roof") else "raft_edge" if _household_part_available("raft_edge") else ""
	if not household_work.begin(part):
		return
	household_work_route_retry = 0.0
	household_work_bench_side = 0
	sailmaker_routine_route_target_set = false
	_record_world_event("resident_household_work_started", {"resident_id": "sailmaker", "part": part, "room_id": "workshop", "operation_id": household_work.operation_id(), "wood_spent": 0})
	_save_progress()
	_update_hud()


func _household_work_target() -> Vector3:
	if not household_work.active() or ark_root == null:
		return Vector3.INF
	var facility := _ark_node("BuiltWorkbench" if household_work.phase == "prepare" else "BuiltShelter") as Node3D
	if facility == null:
		return Vector3.INF
	var signature := [Engine.get_physics_frames(), household_work.phase, household_work.part, household_work_bench_side, facility.get_instance_id(), facility.global_transform]
	if household_target_cache.get("signature") == signature:
		return household_target_cache.target
	var target := _resolve_household_work_target(facility)
	household_target_cache = {"signature": signature, "target": target}
	return target


func _resolve_household_work_target(facility: Node3D) -> Vector3:
	if household_work.phase == "prepare":
		# Templates/free placement permit any accessible use-face, not necessarily
		# the bench's front (a rotated front can point over the gunwale).
		var offsets := [Vector3(0, 0, 0.9), Vector3(-0.95, 0, 0), Vector3(0, 0, -0.9), Vector3(0.95, 0, 0)]
		for index in range(4):
			var candidate: Vector3 = ark_root.to_local(facility.to_global(offsets[(household_work_bench_side + index) % 4]))
			var point := Vector2(candidate.x, candidate.z)
			if not _ark_local_walk_cell_blocked(point, [], 0.25) and not _shared_meal_route_point_blocked(point, _home_routine_furniture_obstacles()):
				return candidate
		return Vector3.INF
	if household_work.part == "shelter_roof":
		return ark_root.to_local(facility.to_global(SAILMAKER_REFUGE_REST_OFFSET))
	return Vector3(0.0, 0.12, -1.60)


func _household_work_can_run() -> bool:
	return household_work.active() and _household_part_available(household_work.part) and _household_work_environment_ready() and stored_wood >= 1


func _process_household_work(delta: float) -> bool:
	if not _household_work_can_run() or not is_finite(delta) or delta <= 0.0 or sailmaker_marker == null or sailmaker_marker.get_parent() != ark_root:
		return false
	var target := _household_work_target()
	var position := sailmaker_marker.position
	if not target.is_finite() or not position.is_finite() or position.y < 0.095 or position.y > maxf(maxf(0.12, target.y), shelter_position.y + 0.12) + 0.025 or not _ark_local_walk_position_supported(Vector2(position.x, position.z)):
		return false
	if not _sailmaker_awning_endpoint_clear(target):
		sailmaker_routine_route.clear()
		sailmaker_routine_route_target_set = false
		return false
	var step := minf(delta, HouseholdWorkScript.MAX_STEP)
	if not _sailmaker_at_awning_work_target(target):
		household_work_route_retry = maxf(0.0, household_work_route_retry - step)
		if sailmaker_routine_route.is_empty() and sailmaker_routine_route_target_set:
			if household_work_route_retry > 0.0:
				return false
			sailmaker_routine_route_target_set = false
		var moving := _move_ark_resident_toward(sailmaker_marker, target, step, 0.64, "sailmaker", true)
		if sailmaker_routine_route.is_empty():
			household_work_route_retry = SAILMAKER_AWNING_ROUTE_RETRY_SECONDS
			if household_work.phase == "prepare":
				household_work_bench_side = (household_work_bench_side + 1) % 4
		return moving
	if household_work.advance(step):
		sailmaker_routine_route_target_set = false
		_save_progress()
		_update_hud()
	elif household_work.ready():
		var part: String = household_work.part
		var operation_id: String = household_work.operation_id()
		var payment: Dictionary = economy.consume("storage", {"wood": 1}, operation_id)
		if not payment.get("ok", false) or payment.get("duplicate", false):
			return false
		if part == "shelter_roof":
			shelter_roof_damaged = false
			var roof := _ark_node("BuiltShelter/Roof") as Node3D
			if roof:
				roof.visible = true
		else:
			raft_edge_damaged = false
			var mark := _ark_node("RaftDamageMark")
			if mark:
				mark.queue_free()
		var finished: bool = household_work.finish()
		assert(finished)
		_record_world_event("resident_household_repair_completed", {"resident_id": "sailmaker", "part": part, "operation_id": operation_id, "wood_spent": 1, "source": "storage", "room_id": "workshop", "day": day_count})
		message = "缝帆人从工坊带来整好的木楔，把%s修牢了。她只用了储物箱里的一块木料，接着收好工具，等下一件真正需要做的事。" % ("棚顶" if part == "shelter_roof" else "筏舷")
		_update_traveler_schedule()
		_update_sailmaker_schedule()
		_save_progress()
		_update_hud()
	return false


func _update_household_work_pose() -> void:
	if not _household_work_can_run() or not _sailmaker_at_awning_work_target(_household_work_target()) or sailmaker_body == null:
		return
	var facing_target := workbench_position if household_work.phase == "prepare" else shelter_position if household_work.part == "shelter_roof" else Vector3(0, 0.12, -2.18)
	var facing := facing_target - sailmaker_marker.position
	sailmaker_marker.rotation.y = atan2(facing.x, facing.z)
	for name_ in ["ArmLeft", "ArmRight"]:
		var arm := sailmaker_body.get_node_or_null(name_) as MeshInstance3D
		if arm:
			arm.rotation.x = -1.1 + sin(sailmaker_motion_clock * 8.0) * 0.12


func _household_work_status() -> String:
	if not household_work.enabled:
		return "未授权自动修缮" if not household_work.active() else "已暂停，保留手艺进度"
	if not household_work.active():
		return "等有实际损伤再开工" if not shelter_roof_damaged and not raft_edge_damaged else "等储木或工作条件"
	var task := "整备木楔" if household_work.phase == "prepare" else "修补棚顶" if household_work.part == "shelter_roof" else "修补筏舷"
	if not _household_work_can_run():
		return task + "（休息/暂缓，进度保留）"
	return task + "（先到位再工作）"


func _room_use_summary() -> String:
	var summary := "家园功能区\n工坊：%s；缝帆人%s，已修缮 %d 处。\n储藏：%s；只用本舟储木，完工才扣料。\n起居 / 炊事：%s；鲜贝做汤，居民实际赴桌后再共餐。\n卧舱：居民专用床位 %d；临时避难位置不是床位，夜间停工。" % ["已建工作台" if workbench_built and _ark_node("BuiltWorkbench") != null else "缺工作台", _household_work_status(), household_work.completed, "%d 块木料" % stored_wood if storage_built and _ark_node("BuiltStorage") != null else "缺储物箱", "蒸汽饭釜" if pressure_galley_built else "已有火盆" if shelter_built else "缺起居棚", _resident_berth_capacity()]
	var backend: Dictionary = household_work.backend_status()
	var food := "\n家庭储粮：鲜贝 %d / 热汤 %d（共 %d/%d 格）；箱边 G 存取，木料仍按 E。" % [economy.inventory(FoodStorageRules.OWNER,"shellfish"),economy.inventory(FoodStorageRules.OWNER,"stew_servings"),FoodStorageRules.stock(economy),FoodStorageRules.CAPACITY] if storage_built else "\n家庭储粮：先建防潮储物箱，居民采回的食物会自动入箱。"
	return summary + food + "\n自主采集：" + home_demand.summary(self) + "\n炊事岗位：守潮人" + resident_kitchen.status(self) + "；新岗位已完成 %d 锅。" % kitchen.completed + "\n居民模拟：" + ("原生故障，已停工" if not backend.healthy else "原生 Flecs" if backend.backend == "native-flecs" else "参考内核（原生库未启用）")


func _room_role_facts() -> Dictionary:
	var facts := {}
	for pair in [["shelter","BuiltShelter",shelter_built],["storage","BuiltStorage",storage_built],["workbench","BuiltWorkbench",workbench_built],["extension","BuiltRaftExtension",raft_extension_built],["berth","BuiltRaftExtension/Berth",raft_extension_built],["guest_cabin","BuiltRaftExtension/GuestCabin",guest_cabin_built]]:
		var node := _ark_node(pair[1])
		facts[pair[0]] = bool(pair[2]) and is_instance_valid(node) and not node.is_queued_for_deletion()
	var hearth := _ark_node("BuiltShelter/PressureGalley" if pressure_galley_built else "BuiltShelter/HearthPot")
	facts["hearth"] = shelter_built and is_instance_valid(hearth) and not hearth.is_queued_for_deletion()
	return facts


func _toggle_kitchen_policy() -> void:
	if building_mode or sailing_mode or _hud_choice_open() or (world_chart and world_chart.visible): return
	kitchen.enabled = not kitchen.enabled
	resident_kitchen.pose.clear()
	_record_world_event("resident_kitchen_policy_changed",{"resident_id":"tidekeeper","room_id":"starter.galley","enabled":kitchen.enabled})
	message = "守潮人应下傍晚的炊事：到锅边守够火候再盛汤；每天最多一锅，已有两份就先不添。" if kitchen.enabled else "你让守潮人暂缓备餐。已做的准备留着，鲜贝没有预先扣除；你仍能自己在火盆煮汤。"
	_update_traveler_schedule()
	_save_progress()
	_update_hud()


func _is_on_raft_extension_deck(position: Vector3) -> bool:
	return absf(position.x) <= 2.9 and position.z >= -6.3 and position.z <= -2.05


func _evacuate_residents_from_raft_extension() -> void:
	if traveler_boarded and not resident_gather_pending and traveler_marker != null and is_instance_valid(traveler_marker) and _is_on_raft_extension_deck(traveler_marker.position):
		traveler_marker.position = RESIDENT_DECK_POSITION
	if sailmaker_boarded and sailmaker_marker != null and is_instance_valid(sailmaker_marker) and _is_on_raft_extension_deck(sailmaker_marker.position):
		sailmaker_marker.position = Vector3(1.15, 0.12, 0.75)


# A one-time personal gift, not a production job. Calendar changes only make it
# eligible; all sewing/installing time is earned here at real deck locations.
func _sailmaker_awning_structure() -> Node3D:
	var structure := _ark_node("BuiltShelter") as Node3D
	if not shelter_built or ark_root == null or structure == null or not is_instance_valid(structure):
		return null
	if structure.get_parent() != ark_root or not structure.is_inside_tree() or not structure.is_visible_in_tree() or structure.process_mode == Node.PROCESS_MODE_DISABLED:
		return null
	return structure


func _sailmaker_awning_work_target(installing: bool) -> Vector3:
	var structure := _sailmaker_awning_structure()
	if structure == null:
		return Vector3.INF
	var offset := SAILMAKER_AWNING_INSTALL_OFFSET if installing else SAILMAKER_AWNING_SEW_OFFSET
	return ark_root.to_local(structure.to_global(offset))


func _sailmaker_awning_work_can_run() -> bool:
	if not sailmaker_met or not sailmaker_boarded or sailmaker_awning_raised or day_count <= sailmaker_joined_day or _sailmaker_awning_structure() == null:
		return false
	if weather_phase == WeatherPhase.STORM or sailing_mode or building_mode or day_period == DayPeriod.NIGHT or raft_edge_damaged or shelter_roof_damaged:
		return false
	return not (shared_meal_gathering_pending and not shared_meal_paused and shared_meal_participants.has("sailmaker"))


func _sailmaker_awning_endpoint_clear(target: Vector3) -> bool:
	if not target.is_finite() or ark_root == null or get_world_3d() == null:
		return false
	var point := Vector2(target.x, target.z)
	return not _ark_local_walk_cell_blocked(point, [], 0.25) and not _shared_meal_route_point_blocked(point, _shared_meal_route_obstacles(target))


func _sailmaker_at_awning_work_target(target: Vector3) -> bool:
	if sailmaker_marker == null or not is_instance_valid(sailmaker_marker) or sailmaker_marker.get_parent() != ark_root:
		return false
	if not _sailmaker_awning_endpoint_clear(target) or not sailmaker_marker.position.is_finite():
		return false
	return absf(sailmaker_marker.position.y - target.y) <= 0.025 and sailmaker_marker.position.distance_to(target) <= SAILMAKER_AWNING_ARRIVAL_TOLERANCE


func _process_sailmaker_awning_work(delta: float) -> bool:
	# Do not turn a suspended frame, a wall-clock gap or malformed dt into work.
	if not is_finite(delta) or delta <= 0.0 or not _sailmaker_awning_work_can_run():
		return false
	var active_delta := minf(delta, SAILMAKER_AWNING_MAX_STEP)
	if sailmaker_marker == null or not is_instance_valid(sailmaker_marker) or sailmaker_marker.get_parent() != ark_root:
		return false
	var installing := sailmaker_awning_phase in ["carrying", "installing"]
	var target := _sailmaker_awning_work_target(installing)
	var position := sailmaker_marker.position
	# Ordinary resident routes span the deck and slightly raised shelter floor.
	# An actor above/below those surfaces must not be snapped into a work pose.
	if not position.is_finite() or not target.is_finite() or position.y < 0.12 - 0.025 or position.y > maxf(0.12, target.y) + 0.025 or not _ark_local_walk_position_supported(Vector2(position.x, position.z)):
		return false
	if not _sailmaker_awning_endpoint_clear(target):
		sailmaker_routine_route.clear()
		sailmaker_routine_route_target_set = false
		return false
	if sailmaker_awning_phase == "unstarted":
		sailmaker_awning_phase = "to_sew"
		sailmaker_routine_route_target_set = false
		_save_progress()
	_update_sailmaker_schedule()
	if not _sailmaker_at_awning_work_target(target):
		sailmaker_awning_route_retry_remaining = maxf(0.0, sailmaker_awning_route_retry_remaining - active_delta)
		if sailmaker_routine_route.is_empty() and sailmaker_routine_route_target_set:
			if sailmaker_awning_route_retry_remaining > 0.0:
				return false
			sailmaker_routine_route_target_set = false
		var moving := _move_ark_resident_toward(sailmaker_marker, target, active_delta, 0.64, "sailmaker", true)
		if sailmaker_routine_route.is_empty():
			sailmaker_awning_route_retry_remaining = SAILMAKER_AWNING_ROUTE_RETRY_SECONDS
		return moving
	match sailmaker_awning_phase:
		"to_sew":
			sailmaker_awning_phase = "sewing"
			_save_progress()
		"sewing":
			sailmaker_awning_sewing_elapsed = minf(SAILMAKER_AWNING_SEW_SECONDS, sailmaker_awning_sewing_elapsed + active_delta)
			if sailmaker_awning_sewing_elapsed >= SAILMAKER_AWNING_SEW_SECONDS:
				sailmaker_awning_phase = "carrying"
				sailmaker_routine_route_target_set = false
				_save_progress()
		"carrying":
			sailmaker_awning_phase = "installing"
			_save_progress()
		"installing":
			sailmaker_awning_install_elapsed = minf(SAILMAKER_AWNING_INSTALL_SECONDS, sailmaker_awning_install_elapsed + active_delta)
			if sailmaker_awning_install_elapsed >= SAILMAKER_AWNING_INSTALL_SECONDS:
				_raise_sailmaker_awning()
	_update_sailmaker_schedule()
	_update_sailmaker_work_visuals()
	return false


func _sailmaker_awning_walk_step_clear(from: Vector3, to: Vector3, target: Vector3, allow_initial_escape: bool = false) -> bool:
	var obstacles := _shared_meal_route_obstacles(target)
	var from_point := Vector2(from.x, from.z)
	var was_clear := not _ark_local_walk_cell_blocked(from_point, [], 0.25) and not _shared_meal_route_point_blocked(from_point, obstacles)
	if not was_clear and not allow_initial_escape:
		return false
	# Legacy boarding positions can begin inside a fixture margin. Allow only
	# their existing planned outward walking leg, never a teleport; once clear,
	# every sampled step must stay clear of both real and visual-only fixtures.
	var steps := maxi(1, ceili(from.distance_to(to) / 0.04))
	for index in range(1, steps + 1):
		var sample := from.lerp(to, float(index) / float(steps))
		var point := Vector2(sample.x, sample.z)
		if not _ark_local_walk_position_supported(point, 0.25):
			return false
		var clear := not _ark_local_walk_cell_blocked(point, [], 0.25) and not _shared_meal_route_point_blocked(point, obstacles)
		if was_clear and not clear:
			return false
		was_clear = was_clear or clear
	return true


func _update_sailmaker_work_visuals() -> void:
	if sailmaker_marker == null or not is_instance_valid(sailmaker_marker):
		return
	var bundle := opening_coast.visual_child(sailmaker_marker, "OldSailBundle") as MeshInstance3D
	var spool := opening_coast.visual_child(sailmaker_marker, "ThreadSpool") as Node3D
	if bundle == null or spool == null:
		return
	var prepared := sailmaker_awning_phase in ["carrying", "installing"]
	var work_active := _sailmaker_awning_work_can_run()
	var active_prepared := prepared and work_active
	var sewing := sailmaker_awning_phase == "sewing" and work_active and _sailmaker_at_awning_work_target(_sailmaker_awning_work_target(false))
	var installing := sailmaker_awning_phase == "installing" and work_active and _sailmaker_at_awning_work_target(_sailmaker_awning_work_target(true))
	if sewing or installing:
		var facing_target := _sailmaker_awning_work_target(true)
		if installing:
			facing_target = ark_root.to_local(_sailmaker_awning_structure().to_global(SAILMAKER_AWNING_CANVAS_OFFSET))
		var facing := Vector3(facing_target.x - sailmaker_marker.position.x, 0.0, facing_target.z - sailmaker_marker.position.z)
		if not facing.is_zero_approx():
			sailmaker_marker.rotation.y = atan2(facing.x, facing.z)
	bundle.visible = not sailmaker_awning_raised
	# The prepared personal cloth remains hers during meals/rest/weather, but is
	# folded at her side rather than pretending she is still carrying/installing.
	bundle.scale = Vector3(2.0, 0.65, 1.3) if active_prepared else Vector3(1.6, 0.32, 1.3) if sewing else Vector3(1.25, 0.8, 1.1) if prepared else Vector3.ONE
	# Face and the hands of negatively tilted arms point along figure-local +Z.
	bundle.position = Vector3(0.0, 1.81, 0.6) if installing else Vector3(0.0, 0.78, 0.32) if active_prepared else Vector3(0.0, 0.66, 0.3) if sewing else Vector3(0.42, 0.34, 0.02)
	bundle.rotation = Vector3.ZERO if active_prepared or sewing else Vector3(0, 0, -0.18)
	spool.position = Vector3(-0.25, 0.7, 0.25) if sewing else Vector3(-0.4, 0.18, 0.05)
	if sailmaker_body:
		for arm_name in ["ArmLeft", "ArmRight"]:
			var arm := sailmaker_body.get_node_or_null(arm_name) as MeshInstance3D
			if arm:
				if not arm.has_meta("awning_rest_transform"):
					arm.set_meta("awning_rest_transform", arm.transform)
				var rest_transform: Transform3D = arm.get_meta("awning_rest_transform")
				arm.transform = rest_transform
				if installing:
					# Rotate around the original upper capsule endpoint (shoulder),
					# not its centre: raised hands reach the cloth without floating arms.
					var bounds := arm.get_aabb()
					var shoulder := Vector3(bounds.get_center().x, bounds.end.y, bounds.get_center().z)
					var shoulder_position := rest_transform * shoulder
					arm.rotation.x = -2.3
					arm.position = shoulder_position - arm.basis * shoulder
				elif sewing:
					arm.rotation.x = -1.3 + sin(sailmaker_motion_clock * 11.0) * 0.12
				elif active_prepared:
					arm.rotation.x = -1.4


func _raise_sailmaker_awning() -> bool:
	if not _sailmaker_awning_work_can_run() or sailmaker_awning_phase != "installing" or sailmaker_awning_sewing_elapsed != SAILMAKER_AWNING_SEW_SECONDS or sailmaker_awning_install_elapsed != SAILMAKER_AWNING_INSTALL_SECONDS:
		return false
	if not _sailmaker_at_awning_work_target(_sailmaker_awning_work_target(true)):
		return false
	_add_sailmaker_awning()
	if _ark_node("BuiltShelter/SailmakerAwning") == null:
		return false
	sailmaker_awning_raised = true
	sailmaker_awning_phase = "complete"
	sailmaker_awning_sewing_elapsed = 0.0
	sailmaker_awning_install_elapsed = 0.0
	_record_world_event("resident_sail_awning_raised", {"resident_id": "sailmaker", "day": day_count, "source_material": "personal_sail_scrap", "wood_spent": 0})
	message = "缝帆人把亲手缝好的旧帆雨檐系稳，收起针线。她说这挡不了大风，却能让进出的人少淋一阵。"
	_update_sailmaker_schedule()
	_update_sailmaker_work_visuals()
	_save_progress()
	_update_hud()
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
	cloth.position = SAILMAKER_AWNING_CANVAS_OFFSET
	cloth.rotation.x = -0.1
	cloth.material_override = _material(Color("78908a"))
	awning.add_child(cloth)
	for side in [-1.0, 1.0]:
		var support := MeshInstance3D.new()
		var support_mesh := CylinderMesh.new()
		support_mesh.top_radius = 0.025
		support_mesh.bottom_radius = 0.035
		# Preserve the original lower anchors; extend only to the raised cloth.
		var support_bottom := 0.8
		var support_top := SAILMAKER_AWNING_CANVAS_OFFSET.y + 0.01
		support_mesh.height = support_top - support_bottom
		support.mesh = support_mesh
		support.position = Vector3(side * 0.72, (support_top + support_bottom) * 0.5, -0.72)
		support.material_override = _material(Color("80664c"))
		awning.add_child(support)
	structure.add_child(awning)
	var marker := Node3D.new()
	marker.name = "SailmakerAwningInteractable"
	marker.position = shelter_position + Vector3(0.0, 1.05, -0.92)
	var sign := Label3D.new()
	sign.font = UI_FONT
	sign.name = "Name"
	sign.text = "补好的旧帆 · 棚口雨檐"
	sign.position.y = 0.3
	sign.font_size = 22
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_style_nearby_world_label(sign)
	sign.modulate = Color("fff0c9")
	marker.add_child(sign)
	ark_root.add_child(marker)
	interactables.append({"id": "sailmaker_awning", "node": marker, "amount": 0})


func _fixture_safe_routine_target(target: Vector3) -> Vector3:
	for id in ["storage", "workbench"]:
		if not (storage_collision_enabled if id == "storage" else workbench_collision_enabled):
			continue
		var fixture := _fixture_node(id)
		if fixture == null:
			continue
		var turns := storage_quarter_turns if id == "storage" else workbench_quarter_turns
		if FixturePlacement.contains_actor(Vector2(target.x, target.z), fixture.position, FixturePlacement.half_size(id, turns)):
			var half: Vector2 = FixturePlacement.half_size(id, turns)
			var context := _fixture_walk_grid(id, fixture.position, turns)
			for offset in [Vector3(0.0, 0.0, half.y + 0.42), Vector3(0.0, 0.0, -half.y - 0.42), Vector3(half.x + 0.42, 0.0, 0.0), Vector3(-half.x - 0.42, 0.0, 0.0)]:
				var approach: Vector3 = fixture.position + offset
				approach.y = target.y
				if _fixture_grid_reaches(context.grid, context.minimum, context.cell_size, context.start, approach):
					return approach
			return Vector3(0.0, target.y, 1.55)
	return target


func _fixture_node(fixture_id: String) -> Node3D:
	return _ark_node("BuiltStorage" if fixture_id == "storage" else "BuiltWorkbench") as Node3D


# Old layouts were built with non-solid furniture and can have narrow corridors.
# Activate physical collision only after an explicit, route-validated relocation.
func _set_fixture_collision_enabled(fixture_id: String, enabled: bool) -> void:
	if fixture_id == "storage":
		storage_collision_enabled = enabled
	else:
		workbench_collision_enabled = enabled
	var fixture := _fixture_node(fixture_id)
	if fixture:
		for child in fixture.get_children():
			if child is CollisionObject3D:
				child.collision_layer = 1 if enabled else 0
				child.collision_mask = 1 if enabled else 0


func _fixture_marker(fixture_id: String) -> Node3D:
	return _ark_node("StorageInteractable" if fixture_id == "storage" else "WorkbenchInteractable") as Node3D


func _start_nearby_fixture_edit() -> void:
	if player == null:
		return
	var nearest_id := ""
	var nearest_distance := 2.8
	for fixture_id in ["storage", "workbench"]:
		var marker := _fixture_marker(fixture_id)
		if marker and player.global_position.distance_to(marker.global_position) < nearest_distance:
			nearest_id = fixture_id
			nearest_distance = player.global_position.distance_to(marker.global_position)
	if nearest_id.is_empty():
		message = "靠近已有储物箱或工作台，按 F 布置家具。"
		_update_hud()
	else:
		_start_fixture_edit(nearest_id)


func _start_fixture_edit(fixture_id: String) -> bool:
	if fixture_id not in ["storage", "workbench"] or sailing_mode:
		return false
	if _fixture_node(fixture_id) == null:
		return false
	if building_mode:
		_cancel_build(false)
	editing_fixture_id = fixture_id
	build_type = fixture_id
	building_mode = true
	preview_position = storage_position if fixture_id == "storage" else workbench_position
	preview_quarter_turns = storage_quarter_turns if fixture_id == "storage" else workbench_quarter_turns
	build_preview = Node3D.new()
	build_preview.name = "FixtureMovePreview"
	var ghost := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var half: Vector2 = FixturePlacement.HALF_SIZES[fixture_id]
	mesh.size = Vector3(half.x * 2.0, 0.8, half.y * 2.0)
	ghost.mesh = mesh
	ghost.position.y = 0.45
	build_preview.add_child(ghost)
	# A contrasting front lip makes 180-degree turns visually legible, even for a crate.
	var front := MeshInstance3D.new()
	var front_mesh := BoxMesh.new()
	front_mesh.size = Vector3(half.x * 1.4, 0.08, 0.09)
	front.mesh = front_mesh
	front.position = Vector3(0.0, 0.9, half.y)
	build_preview.add_child(front)
	preview_valid_material = _preview_material(Color("a2d18f"))
	preview_invalid_material = _preview_material(Color("d78277"))
	ark_root.add_child(build_preview)
	_refresh_fixture_preview()
	return true


func _rotate_fixture_preview() -> void:
	if editing_fixture_id.is_empty():
		return
	preview_quarter_turns = FixturePlacement.normalize_turns(preview_quarter_turns + 1)
	_refresh_fixture_preview()


func _refresh_fixture_preview() -> void:
	if editing_fixture_id.is_empty() or not is_instance_valid(build_preview):
		return
	build_preview.position = preview_position
	build_preview.rotation.y = preview_quarter_turns * PI / 2.0
	if preview_position != fixture_preview_checked_position or preview_quarter_turns != fixture_preview_checked_turns or Time.get_ticks_msec() - fixture_preview_checked_msec >= 200:
		fixture_preview_error = _fixture_placement_error(editing_fixture_id, preview_position, preview_quarter_turns)
		fixture_preview_checked_msec = Time.get_ticks_msec()
		fixture_preview_checked_position = preview_position
		fixture_preview_checked_turns = preview_quarter_turns
	preview_valid = fixture_preview_error.is_empty()
	_set_build_preview_material(preview_valid_material if preview_valid else preview_invalid_material)
	message = "搬移%s · %d°\n鼠标选位置 · R 旋转 · 左键确认 · 右键/Esc 取消。不消耗木料。%s" % ["储物箱" if editing_fixture_id == "storage" else "工作台", preview_quarter_turns * 90, "可放置" if preview_valid else fixture_preview_error]
	_update_hud()


func _fixture_collision_rids(fixture_id: String) -> Array[RID]:
	var excluded: Array[RID] = []
	var fixture := _fixture_node(fixture_id)
	if fixture:
		for child in fixture.get_children():
			if child is CollisionObject3D:
				excluded.append(child.get_rid())
	return excluded


func _fixture_geometry_error(fixture_id: String, position: Vector3, quarter_turns: int) -> String:
	if fixture_id not in ["storage", "workbench"] or not position.is_finite():
		return "无效家具或坐标。"
	var half: Vector2 = FixturePlacement.half_size(fixture_id, quarter_turns)
	if not FixturePlacement.supported(position, half):
		return "家具须完整落在原甲板内；本轮不支持移到扩建甲板。"
	var lantern := _ark_node("LanternMarker") as Node3D
	if lantern and FixturePlacement.overlaps(position, half, lantern.position, Vector2(0.18, 0.18)):
		return "这里与固定的避风灯重叠。"
	var other_id := "workbench" if fixture_id == "storage" else "storage"
	var other := _fixture_node(other_id)
	if other:
		var other_turns := workbench_quarter_turns if other_id == "workbench" else storage_quarter_turns
		if FixturePlacement.overlaps(position, half, other.position, FixturePlacement.half_size(other_id, other_turns)):
			return "这里与另一件家具重叠。"
	return ""


func _fixture_placement_error(fixture_id: String, position: Vector3, quarter_turns: int) -> String:
	var geometry_error := _fixture_geometry_error(fixture_id, position, quarter_turns)
	if not geometry_error.is_empty():
		return geometry_error
	var half: Vector2 = FixturePlacement.half_size(fixture_id, quarter_turns)
	# Match the template footprint margin. At x=2 the old 0.01 comparison
	# rounded a valid template crate into the shelter; real routes stay checked.
	if shelter_built and FixturePlacement.overlaps(position, half, shelter_position, Vector2(1.5, 1.2), 0.001):
		return "这里与避风棚、床铺或炉台空间重叠。"
	# Never place a solid fixture through a person currently standing on the deck.
	for actor in [player, traveler_marker, sailmaker_marker]:
		if is_instance_valid(actor) and actor.get_parent() == ark_root:
			var actor_local: Vector3 = actor.position
			if FixturePlacement.contains_actor(Vector2(actor_local.x, actor_local.z), position, half, 0.40 if actor == player else 0.25):
				return "有人站在这里，请留出空间。"
	if not _fixture_routes_clear(fixture_id, position, quarter_turns):
		return "请保留家具使用面、舵位、棚门与居民通路。"
	return ""


func _fixture_walk_grid(fixture_id: String, position: Vector3, quarter_turns: int, actor_radius: float = 0.23) -> Dictionary:
	var excluded := _fixture_collision_rids(fixture_id)
	var minimum := Vector2(-2.5, -6.0 if raft_extension_built else -2.0)
	var cell_size := 0.25
	var grid_size := Vector2i(21, roundi((1.75 - minimum.y) / cell_size) + 1)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, grid_size)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var half: Vector2 = FixturePlacement.half_size(fixture_id, quarter_turns)
	var other_id := "workbench" if fixture_id == "storage" else "storage"
	var other := _fixture_node(other_id)
	var other_turns := workbench_quarter_turns if other_id == "workbench" else storage_quarter_turns
	var other_half: Vector2 = FixturePlacement.half_size(other_id, other_turns)
	var other_solid := workbench_collision_enabled if other_id == "workbench" else storage_collision_enabled
	# Legacy furniture remains nonblocking until its own validated relocation.
	for z in range(grid_size.y):
		for x in range(grid_size.x):
			var point := minimum + Vector2(x, z) * cell_size
			grid.set_point_solid(Vector2i(x, z), FixturePlacement.contains_actor(point, position, half, actor_radius) or (other != null and other_solid and FixturePlacement.contains_actor(point, other.position, other_half, actor_radius)) or _ark_local_walk_cell_blocked(point, excluded, actor_radius))
	var start_cell := Vector2i(roundi(-minimum.x / cell_size), roundi((1.75 - minimum.y) / cell_size))
	return {"grid": grid, "minimum": minimum, "cell_size": cell_size, "start": start_cell, "actor_radius": actor_radius}


func _fixture_routes_clear(fixture_id: String, position: Vector3, quarter_turns: int) -> bool:
	if ark_root == null or get_world_3d() == null:
		return false
	var context := _fixture_walk_grid(fixture_id, position, quarter_turns)
	var grid: AStarGrid2D = context.grid
	var minimum: Vector2 = context.minimum
	var cell_size: float = context.cell_size
	var start_cell: Vector2i = context.start
	if grid.is_point_solid(start_cell):
		return false
	var targets: Array[Vector3] = [RESIDENT_DECK_POSITION, Vector3(0.0, 0.12, 1.5)]
	if shelter_built:
		targets.append(shelter_position + Vector3(0.0, 0.0, 1.55))
	if raft_extension_built:
		targets.append(Vector3(0.0, 0.12, -2.5))
	for target in targets:
		if not _fixture_grid_reaches(grid, minimum, cell_size, start_cell, target):
			return false
	var player_context := _fixture_walk_grid(fixture_id, position, quarter_turns, 0.38)
	var player_targets: Array[Vector3] = [Vector3(0.0, 0.12, 1.5)]
	if shelter_built:
		player_targets.append(shelter_position + Vector3(0.0, 0.0, 1.55))
	if raft_extension_built:
		player_targets.append(Vector3(0.0, 0.12, -2.5))
	for target in player_targets:
		if not _fixture_grid_reaches(player_context.grid, player_context.minimum, player_context.cell_size, player_context.start, target):
			return false
	# Lid and tabletop can be used from any side. Rotation affects occupied space,
	# not a fictitious one-sided interaction rule that would trap legacy layouts.
	for id in ["storage", "workbench"]:
		var node := _fixture_node(id)
		if node == null:
			continue
		var spot := position if id == fixture_id else node.position
		var turns := quarter_turns if id == fixture_id else storage_quarter_turns if id == "storage" else workbench_quarter_turns
		var size: Vector2 = FixturePlacement.half_size(id, turns)
		if not _fixture_any_side_reachable(context, spot, size) or not _fixture_any_side_reachable(player_context, spot, size):
			return false
	return true


func _fixture_any_side_reachable(context: Dictionary, spot: Vector3, size: Vector2) -> bool:
	# Nearest-cell rounding can pull a sample inward by half a grid cell.
	# Keep the entire actor clear after quantization, not only the ideal point.
	var clearance: float = maxf(0.42, float(context.actor_radius) + float(context.cell_size) * 0.5 + 0.02)
	for offset in [Vector3(size.x + clearance, 0.0, 0.0), Vector3(-size.x - clearance, 0.0, 0.0), Vector3(0.0, 0.0, size.y + clearance), Vector3(0.0, 0.0, -size.y - clearance)]:
		if _fixture_grid_reaches(context.grid, context.minimum, context.cell_size, context.start, spot + offset):
			return true
	return false


func _fixture_grid_reaches(grid: AStarGrid2D, minimum: Vector2, cell_size: float, start: Vector2i, target: Vector3) -> bool:
	var cell := Vector2i(roundi((target.x - minimum.x) / cell_size), roundi((target.z - minimum.y) / cell_size))
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell) and not grid.get_id_path(start, cell).is_empty()


func _try_move_fixture(position: Vector3, quarter_turns: int) -> bool:
	if editing_fixture_id.is_empty() or sailing_mode:
		return false
	var id := editing_fixture_id
	var fixture := _fixture_node(id)
	var marker := _fixture_marker(id)
	if fixture == null or marker == null or not position.is_finite():
		return false
	var snapped_position := Vector3(snappedf(position.x, 0.5), 0.12, snappedf(position.z, 0.5))
	var turns: int = FixturePlacement.normalize_turns(quarter_turns)
	var placement_error := _fixture_placement_error(id, snapped_position, turns)
	if not placement_error.is_empty():
		message = placement_error
		_update_hud()
		return false
	if not _commit_construction({}, {id: {"built": true, "position": _position_exact(snapped_position), "quarter_turns": turns}}, "move", func() -> bool: return _fixture_placement_error(id, snapped_position, turns).is_empty()):
		return false
	# Commit in place, with no rebuilding, inventory writes, or construction costs.
	var previous_position := fixture.position
	var previous_turns := storage_quarter_turns if id == "storage" else workbench_quarter_turns
	if id == "storage":
		storage_position = snapped_position
		storage_quarter_turns = turns
	else:
		workbench_position = snapped_position
		workbench_quarter_turns = turns
	_set_fixture_collision_enabled(id, true)
	fixture.position = snapped_position
	fixture.rotation.y = turns * PI / 2.0
	marker.position = snapped_position + Vector3(0.0, 0.5, 0.0)
	marker.rotation.y = turns * PI / 2.0
	traveler_routine_route.clear()
	sailmaker_routine_route.clear()
	traveler_routine_route_target_set = false
	sailmaker_routine_route_target_set = false
	if resident_gather_pending:
		resident_gather_route.clear()
		resident_gather_route_index = 0
	_update_traveler_schedule()
	_update_sailmaker_schedule()
	_record_world_event("fixture_moved", {"fixture_id": id, "from": _position_facts(previous_position), "to": _position_facts(snapped_position), "previous_quarter_turns": previous_turns, "quarter_turns": turns, "wood_spent": 0})
	_cancel_build(false)
	message = "家具已重新摆好；库存、升级与蓝图保持不变。"
	_save_progress()
	_update_hud()
	return true


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
	if _available_build_wood() < required_wood or (build_type == "raft_extension" and keel_beams < RAFT_EXTENSION_KEEL_COST):
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
	_start_home_template(false)


func _start_workshop_home_template() -> void:
	_start_home_template(true)


func _start_home_template(include_workbench: bool) -> void:
	home_templates.start(self,include_workbench)


func _start_basic_shelter_template() -> void:
	if sailing_mode:
		message = "掌舵时不能施工。先离开舵位，让仙舟停稳。"
		_update_hud()
		return
	if building_mode:
		_cancel_build(false)
	if shelter_built:
		message = "基础避风棚已建好；可选择潮棚之家或起居工坊补齐模板，只付缺少设施的木料。"
		_update_hud()
		return
	if _available_build_wood() < BUILD_COST:
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
	message = "基础避风棚模板 · 3 木（现有 %d）\n含玩家床铺与暖灯；可临时接纳两位避难者，不提供居民专用床位。鼠标选位置，左键确认，右键或 Esc 取消。" % wood
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
	if guest_cabin_frames < GUEST_CABIN_FRAME_COST or _available_build_wood() < GUEST_CABIN_WOOD_COST:
		message = "听潮客舱需要 %d 块木料与 %d 根琼华舫舱骨；可用木料 %d、舱骨 %d。" % [GUEST_CABIN_WOOD_COST, GUEST_CABIN_FRAME_COST, _available_build_wood(), guest_cabin_frames]
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
	message = "听潮客舱模板 · 3 木 + 1 舱骨\n落在龙骨甲板左舷，保留右侧铺位与中央通道；左键确认，右键或 Esc 取消。"
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
	if sailing_mode:
		message = "掌舵时不能施工。先离开舵位，让仙舟停稳。"
	elif reef_shell_brace_installed:
		message = "礁壳风撑已经固定在棚顶，不需要重复施工。"
	elif not _has_blueprint("reef_shell_storm_brace"):
		message = "这套风撑结构还没学会；远礁礁背兽留下的甲片与受力纹路会告诉你怎么做。"
	elif not shelter_built or _ark_node("BuiltShelter") == null:
		message = "先搭好避风棚，礁壳风撑需要固定在真实棚架上。"
	elif reef_shell_plates < 1 or _available_build_wood() < REEF_SHELL_BRACE_WOOD_COST:
		message = "材料还不齐：安装需要 2 块木料和 1 片礁壳；蓝图会一直留在册中。"
	else:
		if not _spend_home_wood(REEF_SHELL_BRACE_WOOD_COST, "reef_shell_brace"):
			return
		reef_shell_plates -= 1
		reef_shell_brace_installed = true
		var shelter := _ark_node("BuiltShelter") as Node3D
		if shelter:
			_add_reef_shell_brace_visual(shelter)
		_record_world_event("reef_shell_brace_installed", {"blueprint_id": "reef_shell_storm_brace", "shell_plates_spent": 1, "wood_spent": REEF_SHELL_BRACE_WOOD_COST, "shelter_roof_protected": true})
		message = "你把礁背甲片嵌进棚架受力处，再用木楔和缆绳固定。它不是一块装饰：以后风雨来时，棚顶不再因未加固而被掀开。"
	_save_progress()
	_update_hud()


func _search_ridge_camp() -> void:
	var camp := get_node_or_null(RidgeCampScript.ROOT) as Node3D
	if camp == null or player == null or sailing_mode or is_swimming or player.global_position.distance_to(camp.global_position) > 1.65 or absf(player.global_position.y - camp.global_position.y) > .65:
		message = "营地在岩脊上。先沿土路走到木匣旁，山脚下够不到它。"
		return
	if ridge_camp_searched:
		message = "木匣里的图样已经记住了。旧营地主人把削圆的浮木绑在船侧——不是华丽的法器，却能替家挡下风浪。"
		return
	ridge_camp_searched = true
	_learn_blueprint(RidgeCampScript.BLUEPRINT, "ridge_old_camp")
	_record_world_event("ridge_camp_searched", {"site_id":"ridge_old_camp", "blueprint_id":RidgeCampScript.BLUEPRINT, "permanent_knowledge":true})
	message = "木匣里压着一张浮木护舷的图样，边上写着：‘船小也要护好，等孩子回来吃饭。’你记住了绑扎方法。回到仙舟，在 H 蓝图栏用 4 块木料安装；图样不占背包，也不会遗失。"


func _install_raft_fenders() -> void:
	if raft_fenders_installed:
		message = "浮木护舷已经装好，不会重复扣料。"
	elif not _has_blueprint(RidgeCampScript.BLUEPRINT):
		message = "还没学会护舷图样。首岛岩脊上的旧营地，也许留着前人护船的办法。"
	elif sailing_mode or _distance_to_ark() > 6.5:
		message = "回到本舟附近、停稳后再装护舷。"
	elif _available_build_wood() < RidgeCampScript.COST:
		message = "需要 4 块木料，可用随身与本舟储箱的木料；材料不足时不会施工。"
	elif _spend_home_wood(RidgeCampScript.COST, "raft_fenders"):
		raft_fenders_installed = true
		RidgeCampScript.add_fenders(ark_root)
		_record_world_event("raft_fenders_installed", {"blueprint_id":RidgeCampScript.BLUEPRINT, "wood_spent":RidgeCampScript.COST, "raft_edge_protected":true, "shelter_roof_protected":false})
		message = "一排削圆的浮木稳稳绑在筏侧。往后的普通风浪不再撞松筏舷；已经受损的地方仍须修补，棚顶也要另行加固。"
	_save_progress()
	_update_hud()


func _salvage_modern_utilities() -> void:
	if modern_utilities.salvaged:
		return
	var marker := get_node_or_null("PressureWreckInteractable") as Node3D
	if marker == null or player == null or sailing_mode or not pressure_wreck_searched or player.global_position.distance_to(marker.global_position) > 2.8:
		return
	var result: Dictionary = economy.collect_direct(ModernUtilitiesScript.SOURCE,"player")
	if not result.get("ok",false):
		return
	modern_utilities.salvaged = true
	collected_ids.append(ModernUtilitiesScript.SOURCE)
	_learn_blueprint(ModernUtilitiesScript.BLUEPRINT,"steam_wreck_islet")
	_record_world_event("modern_utility_components_salvaged",{"site_id":"steam_wreck_islet","utility_core":1,"blueprint_id":ModernUtilitiesScript.BLUEPRINT})
	message += "\n隔水舱里还封着一套旧时代的太阳能板、蓄电池与净水组件，接线图仍然清楚。你把它们一并带回：龙骨甲板建好后，可在 H 安装日照净水角。组件只有这一套，图样会永久记住。"


func _install_modern_utilities() -> void:
	if modern_utilities.installed:
		message = "日照净水角已经装好。走到洗手台旁按 E 查看并洗漱。"
	elif not modern_utilities.salvaged or not _has_blueprint(ModernUtilitiesScript.BLUEPRINT):
		message = "日照净水角尚未学会。蒸潮机坞的隔水舱里可能保留着旧时代的供电净水设备。"
	elif sailing_mode or building_mode or _distance_to_ark() > 6.5:
		message = "回到本舟附近，停稳并退出其他施工后再安装。"
	elif not raft_extension_built or _ark_node("BuiltRaftExtension") == null:
		message = "设备需要龙骨甲板前侧的独立空位，不占床铺或吃饭的地方。先完成龙骨扩甲。"
	else:
		var shared := {"wood":["storage"]} if storage_built else {}
		var result: Dictionary = modern_utilities.install(economy,shared)
		if not result.ok:
			var reasons := {"materials":"需要4块木料与1套回收组件，材料不足时不会扣除任何东西。","stream_limit":"设备账本暂时无法新增记录，材料与封存状态都未改变。","invalid_install":"设备拆装记录或供料安排无法继续，材料与封存状态都未改变。"}
			message = reasons.get(result.get("code",""),"设备交易未能完成，材料与封存状态都未改变。")
		else:
			ModernUtilityProps.build(self)
			home_art_sample.apply(self)
			_record_world_event("modern_utilities_installed",{"blueprint_id":ModernUtilitiesScript.BLUEPRINT,"wood_spent":4,"utility_core_spent":1,"installation":modern_utilities.installations,"initial_charge":modern_utilities.power.charge,"initial_water":economy.inventory(ModernUtilitiesScript.TANK,"fresh_water")})
			message = "你把接线藏进木槽，将太阳能板装成一小片棚檐。蓄电池与净水机已经接通，但不会凭空有电有水：日间逐渐蓄电，停泊时自动净水；储满6份就停机。你每天可用温水洗漱恢复生命1、缓解寒冷1。同行居民也会在空闲的白天轮流来净手；每人每天一次，实际洗完才用1水和500电，做饭、修缮、避灾与睡眠优先。" if modern_utilities.installations == 1 else "你把同一套设备重新接回甲板。原来的电量、存水、滤水进度与洗漱记录都还在；重装不会刷新今天的使用次数。"
	_save_progress()
	_update_hud()

func _modern_pack_error() -> String:
	if not modern_utilities.installed: return "设备尚未安装，没有可重复拆回的材料。"
	if sailing_mode or building_mode or is_swimming or _hud_choice_open(): return "先停船、站稳并结束其他施工或选择，再收纳设备。"
	var fixture := _ark_node(ModernUtilityProps.ROOT) as Node3D
	if not is_instance_valid(fixture) or fixture.is_queued_for_deletion() or player == null or player.global_position.distance_to(fixture.global_position) > 2.8: return "请走到本舟的净水台旁再收纳，不能在远处拆设备。"
	if resident_washing.using_station(self): return "有人正在水台净手，等她用完再封管收纳。"
	return ""

func _request_pack_modern_utilities() -> void:
	var error := _modern_pack_error()
	if not error.is_empty():
		message = error
	else:
		modern_pack_choice_pending = true
		message = "收纳日照净水角？断电封管后返还4块木料与同一套设备组件。已有电量、清水、滤水进度和洗漱经历都封存；收纳时完全停机，重装仍需4木与该组件，不刷新每日次数。\n1 · 确认收纳　2 / Esc · 保持运行"
	_update_hud()

func _choose_pack_modern_utilities(accept: bool) -> void:
	if not modern_pack_choice_pending: return
	modern_pack_choice_pending = false
	if accept: _pack_modern_utilities()
	else:
		message = "净水角保持原样，材料和设备状态没有变化。"
		_update_hud()

func _pack_modern_utilities() -> bool:
	var error := _modern_pack_error()
	if not error.is_empty():
		message = error
		_update_hud()
		return false
	var result: Dictionary = modern_utilities.pack(economy)
	if not result.ok:
		message = "暂时无法收下全部返还材料，设备和水电都保持原样。先腾出随身空间再试。" if result.get("code","") in ["capacity","quantity_limit"] else "设备收纳交易未能完成，设备、水电和材料都保持原样；没有重复发放材料。"
		_update_hud()
		return false
	resident_washing.clear()
	ModernUtilityProps.clear(self)
	_sync_legacy_from_economy()
	_invalidate_committed_layout()
	_update_traveler_schedule()
	_update_sailmaker_schedule()
	_record_world_event("modern_utilities_packed",{"removal":modern_utilities.removals,"wood_returned":4,"utility_core_returned":1,"retained_charge":modern_utilities.power.charge,"retained_fresh_water":economy.inventory(ModernUtilitiesScript.TANK,"fresh_water"),"retained_filter_us":modern_utilities.filter_us})
	message = "你断开电路、封好水管，把整套设备收进组件箱，收回4块木料。存水与电量随设备封存，不再发电、净水或洗漱；甲板现在可以另行安全拆解。"
	_save_progress()
	_update_hud()
	return true


func _toggle_modern_purifier() -> void:
	if not modern_utilities.installed:
		message = "先装好日照净水角，再安排设备运行。"
	else:
		modern_utilities.automatic = not modern_utilities.automatic
		message = "自动净水已开启；停泊且电量足够时工作。" if modern_utilities.automatic else "自动净水已暂停，太阳能仍会蓄电，已有清水可以照常使用。"
	_save_progress()
	_update_hud()


func _ground_height_at(point: Vector3) -> Variant:
	var ground: Variant = opening_coast.sample_height(point)
	return ground if ground != null else ground_sampler.sample_height(point)


func _modern_intake_ready() -> bool:
	if sailing_mode or ark_root == null: return false
	var intake := ark_root.to_global(ModernUtilityProps.AT + Vector3(1.5,0,0))
	var ground: Variant = _ground_height_at(intake)
	return ground == null or float(ground) < WATER_SURFACE_Y - .15


func _advance_modern_utilities(seconds: float) -> void:
	if not _modules_ready or not modern_utilities.installed or seconds <= 0: return
	var result: Dictionary = modern_utilities.advance(int(round(seconds*1000000.0)),day_period,weather_phase,_modern_intake_ready(),economy)
	if result.get("ok",false) and result.get("produced",0) > 0:
		_record_world_event("fresh_water_filtered",{"amount":result.produced,"total_produced":modern_utilities.produced,"charge_spent":result.produced*ModernUtilitiesScript.FILTER_COST,"tank_owner":ModernUtilitiesScript.TANK})
	_update_modern_status()


func _update_modern_status() -> void:
	ModernUtilityProps.refresh(self)
	if modern_status == null: return
	if modern_action_button:
		modern_action_button.text = "收纳日照净水角 · 返还4木与组件" if modern_utilities.installed else ("重装" if modern_utilities.commissioned() else "安装")+"日照净水角 · 4木 + 1套组件"
		modern_action_button.tooltip_text = "先走到水台旁；需再次确认。收纳保留电量、存水、滤水进度与每日记录，期间完全停机。" if modern_utilities.installed else "需要龙骨甲板、4木与唯一设备组件；重装不重置电量、存水或每日洗漱记录。"
	if not modern_utilities.salvaged:
		modern_status.text = "现代生活 · 蒸潮机坞可探索回收供电净水设备。"
	elif not modern_utilities.installed:
		modern_status.text = "日照净水图样已学会 · 回收组件 %d · 安装需要龙骨甲板。" % economy.inventory("player","utility_core")
		if modern_utilities.commissioned(): modern_status.text += "\n设备已收纳，完全停机 · 封存电 %d · 清水 %d/6；重装恢复，不刷新每日洗漱。" % [modern_utilities.power.charge,economy.inventory(ModernUtilitiesScript.TANK,"fresh_water")]
	else:
		modern_status.text = "日照净水角 · 电 %d / %d · 清水 %d / 6\n%s · %s" % [modern_utilities.power.charge,modern_utilities.power.CAPACITY,economy.inventory(ModernUtilitiesScript.TANK,"fresh_water"),"自动净水" if modern_utilities.automatic else "净水暂停","停泊取水" if _modern_intake_ready() else "航行或取水口离水，净水等待"]
		modern_status.text += "\n"+resident_washing.status(self)


func _use_modern_wash() -> void:
	var fixture := _ark_node(ModernUtilityProps.ROOT) as Node3D
	if fixture == null or player == null or sailing_mode or is_swimming or player.global_position.distance_to(fixture.global_position) > 2.1:
		message = "先停船，走到本舟的净水台旁再洗漱。"
		return
	if resident_washing.using_station(self):
		message = "有人正在水台净手，等她收好手边的东西，再来洗漱。没有扣除你的水电。"
		return
	var result: Dictionary = modern_utilities.wash("player",day_count,economy)
	if not result.ok:
		var reasons := {"already_today":"今天已经洗漱过了，清水留给下一次归家。","water":"储水罐还没有清水；让设备在停泊时净水。","charge":"加热需要 500 电量；先等日照蓄电，或暂停净水保留电量。"}
		message = reasons.get(result.get("code",""),"设备还没准备好，没有消耗水或电。")
	else:
		var before := _effective_cold_exposure_level()
		var after := _relieve_cold_exposure("warm_water_wash",1)
		var restored := _restore_player_health("warm_water_wash",1)
		_record_world_event("resident_washed",{"resident_id":"player","day":day_count,"wash_count":result.count,"fresh_water_spent":1,"charge_spent":500,"health_restored":restored,"cold_levels_relieved":before-after})
		message = "温水冲走手上的盐和尘土。你擦干脸，听见棚檐下电池轻轻工作的声音。消耗 1 份清水与 500 电量；恢复 %d 点生命，缓解 %d 层寒冷。今天已洗漱，不会反复消耗。" % [restored,before-after]
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
	var previous_valid := preview_valid
	if build_type in ["workshop_home_template","starter_home_template"] and shelter_built:
		preview_position = shelter_position
		home_templates.refresh(self,preview_position,build_type == "workshop_home_template")
		return
	if build_type == "guest_cabin_template":
		preview_position = Vector3(0.0, 0.12, -4.2)
		build_preview.position = preview_position
		preview_valid = _is_valid_guest_cabin_position(preview_position)
		_set_build_preview_material(preview_valid_material if preview_valid else preview_invalid_material)
		if previous_valid != preview_valid:
			_update_hud()
		return
	var mouse := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse)
	var ray_direction := camera.project_ray_normal(mouse)
	var floor_plane := Plane(Vector3.UP, ark_root.global_position.y + 0.12)
	var hit = floor_plane.intersects_ray(ray_origin, ray_direction)
	if hit == null:
		preview_valid = false
		_set_build_preview_material(preview_invalid_material)
		if previous_valid != preview_valid:
			_update_hud()
		return
	var point: Vector3 = ark_root.to_local(hit)
	preview_position = Vector3(snappedf(point.x, 0.5), 0.12, snappedf(point.z, 0.5))
	if not editing_fixture_id.is_empty():
		_refresh_fixture_preview()
		return
	if build_type in ["workshop_home_template", "starter_home_template"]:
		home_templates.refresh(self,preview_position,build_type == "workshop_home_template")
		return
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
	if previous_valid != preview_valid:
		_update_hud()


func _set_build_preview_material(ghost_material: StandardMaterial3D) -> void:
	if build_preview is MeshInstance3D:
		(build_preview as MeshInstance3D).material_override = ghost_material
	else:
		for child in build_preview.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).material_override = ghost_material


func _home_template_layout_error(position: Vector3, include_workbench: bool) -> String:
	return home_templates.layout_error(self,position,include_workbench)


func _is_valid_starter_home_template_position(position: Vector3) -> bool:
	return _home_template_layout_error(position, false).is_empty()


func _is_valid_workshop_home_template_position(position: Vector3) -> bool:
	return _home_template_layout_error(position, true).is_empty()


func _try_place_starter_home_template(position: Vector3) -> bool:
	return _try_place_home_template(position, false)


func _try_place_workshop_home_template(position: Vector3) -> bool:
	return _try_place_home_template(position, true)


func _try_place_home_template(position: Vector3, include_workbench: bool) -> bool:
	return home_templates.commit(self,position,include_workbench)

func _is_valid_shelter_position(position: Vector3) -> bool:
	if sailing_mode or not position.is_finite() or shelter_built or absf(position.x) > 1.2 or absf(position.z) > 0.55:
		return false
	if storage_built and _rectangles_overlap(position, Vector2(1.5, 1.2), storage_position, FixturePlacement.half_size("storage", storage_quarter_turns), 0.2):
		return false
	if workbench_built and _rectangles_overlap(position, Vector2(1.5, 1.2), workbench_position, FixturePlacement.half_size("workbench", workbench_quarter_turns), 0.2):
		return false
	return true


func _rectangles_overlap(first: Vector3, first_half_size: Vector2, second: Vector3, second_half_size: Vector2, clearance: float) -> bool:
	return absf(first.x - second.x) < first_half_size.x + second_half_size.x + clearance and absf(first.z - second.z) < first_half_size.y + second_half_size.y + clearance


func _is_valid_storage_position(position: Vector3) -> bool:
	if sailing_mode or storage_built or not _fixture_geometry_error("storage", position, 0).is_empty():
		return false
	var horizontal_distance := Vector2(position.x - shelter_position.x, position.z - shelter_position.z).length()
	return horizontal_distance >= 2.0


func _is_valid_workbench_position(position: Vector3) -> bool:
	if sailing_mode or workbench_built or not _fixture_geometry_error("workbench", position, 0).is_empty():
		return false
	var shelter_distance := Vector2(position.x - shelter_position.x, position.z - shelter_position.z).length()
	var storage_distance := Vector2(position.x - storage_position.x, position.z - storage_position.z).length()
	return shelter_distance >= 2.0 and storage_distance >= 1.35


func _is_valid_raft_extension_position(position: Vector3) -> bool:
	return not sailing_mode and position.is_finite() and workbench_built and not raft_extension_built and keel_beams >= RAFT_EXTENSION_KEEL_COST and _available_build_wood() >= RAFT_EXTENSION_WOOD_COST and absf(position.x) <= 0.25 and absf(position.z + 4.2) <= 0.25


func _is_valid_guest_cabin_position(position: Vector3) -> bool:
	return not sailing_mode and position.is_finite() and _has_blueprint("tide_guest_cabin") and raft_extension_built and not guest_cabin_built and guest_cabin_frames >= GUEST_CABIN_FRAME_COST and _available_build_wood() >= GUEST_CABIN_WOOD_COST and absf(position.x) <= 0.25 and absf(position.z + 4.2) <= 0.25


func _try_place_guest_cabin_template(position: Vector3) -> bool:
	var snapped_position := Vector3(snappedf(position.x, 0.5), 0.12, snappedf(position.z, 0.5))
	if not _is_valid_guest_cabin_position(snapped_position):
		message = "客舱须建在龙骨甲板左舷预留的承重区，并确认蓝图、木料与舱骨都在。"
		_update_hud()
		return false
	var capacity_before := _resident_capacity()
	if not _commit_construction({"wood": GUEST_CABIN_WOOD_COST, "guest_cabin_frames": GUEST_CABIN_FRAME_COST}, {"guest_cabin": {"built": true, "position": _position_exact(snapped_position)}}, "build", func() -> bool: return _is_valid_guest_cabin_position(snapped_position)):
		return false
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
	if _available_build_wood() < BUILD_COST:
		_cancel_build()
		message = "木料不够，暂时搭不起避风棚。"
		_update_hud()
		return false
	if not _commit_construction({"wood": BUILD_COST}, {"shelter": {"built": true, "position": _position_exact(snapped_position)}}, "build", func() -> bool: return _is_valid_shelter_position(snapped_position)):
		return false
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
	if _available_build_wood() < STORAGE_COST:
		_cancel_build()
		message = "木料不够，储物箱还差 %d 块。" % (STORAGE_COST - _available_build_wood())
		_update_hud()
		return false
	if not _commit_construction({"wood": STORAGE_COST}, {"storage": {"built": true, "position": _position_exact(snapped_position), "quarter_turns": 0}}, "build", func() -> bool: return _is_valid_storage_position(snapped_position)):
		return false
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
	if _available_build_wood() < WORKBENCH_COST:
		_cancel_build()
		message = "阵枢工作台还差 %d 块木料。" % (WORKBENCH_COST - _available_build_wood())
		_update_hud()
		return false
	if not _commit_construction({"wood": WORKBENCH_COST}, {"workbench": {"built": true, "position": _position_exact(snapped_position), "quarter_turns": 0}}, "build", func() -> bool: return _is_valid_workbench_position(snapped_position)):
		return false
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
	if not _commit_construction({"wood": RAFT_EXTENSION_WOOD_COST, "keel_beams": RAFT_EXTENSION_KEEL_COST}, {"raft_extension": {"built": true, "position": _position_exact(snapped_position)}}, "build", func() -> bool: return _is_valid_raft_extension_position(snapped_position)):
		return false
	raft_extension_built = true
	_record_world_event("raft_extension_built", {"wood_spent": RAFT_EXTENSION_WOOD_COST, "keel_beams_spent": RAFT_EXTENSION_KEEL_COST, "position": {"x": snapped_position.x, "z": snapped_position.z}, "source_site": "far_reef_wreck", "resident_capacity_before": capacity_before, "resident_capacity_after": _resident_capacity()})
	_build_raft_extension_at(snapped_position)
	_cancel_build(false)
	message = "你把远礁龙骨一端接入原筏的主梁，再将四块船板一一钉牢。筏首向前长出一片新甲板，也多出一处住民泊位。"
	_save_progress()
	_update_hud()
	return true

func _dismantle_raft_extension() -> bool:
	if modern_utilities.installed:
		message = "日照净水角仍接在龙骨甲板上。先走到设备旁，在H确认收纳，再拆除支撑甲板。"
		_update_hud()
		return false
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
	# Recall may deliver carried stock, so refund capacity is checked AFTER recall.
	_restoring_progress = true
	if resident_gather_pending:
		_abort_resident_gathering("raft_extension_dismantled")
	_restoring_progress = false
	var wood_returned := RAFT_EXTENSION_WOOD_COST + (GUEST_CABIN_WOOD_COST if guest_cabin_built else 0)
	var cabin_frame_returned := GUEST_CABIN_FRAME_COST if guest_cabin_built else 0
	var changes := {"raft_extension": {"built": false, "position": {"x": 0.0, "y": 0.12, "z": -4.2}}, "guest_cabin": {"built": false, "position": {"x": 0.0, "y": 0.12, "z": -4.2}}}
	if not _commit_construction({"wood": wood_returned, "keel_beams": RAFT_EXTENSION_KEEL_COST, "guest_cabin_frames": cabin_frame_returned}, changes, "dismantle", func() -> bool: return raft_extension_built and not sailing_mode and _resident_occupancy() <= 2):
		_save_progress()
		return false
	# Move the player back onto the original deck before removing the support surface.
	if player and ark_root:
		player.global_position = ark_root.to_global(Vector3(0.0, 1.1, -1.25))
	_evacuate_residents_from_raft_extension()
	var extension := _ark_node("BuiltRaftExtension")
	if extension:
		# Release the stable node name immediately; a rebuild can be confirmed
		# before queued deletion runs at the end of the frame.
		extension.get_parent().remove_child(extension)
		extension.queue_free()
	_set_raft_rail("RaftBow", Vector3(0, 0.35, -2.2), Vector3(5.2, 0.45, 0.16))
	_set_raft_rail("RaftPort", Vector3(-2.95, 0.35, 0), Vector3(0.16, 0.45, 4.3))
	_set_raft_rail("RaftStarboard", Vector3(2.95, 0.35, 0), Vector3(0.16, 0.45, 4.3))
	for index in range(interactables.size() - 1, -1, -1):
		var entry: Dictionary = interactables[index]
		if str(entry.get("id", "")) in ["raft_extension", "guest_cabin"]:
			var marker: Node = entry.get("node")
			if is_instance_valid(marker):
				if marker.get_parent():
					marker.get_parent().remove_child(marker)
				marker.queue_free()
			interactables.remove_at(index)
	raft_extension_built = false
	guest_cabin_built = false
	traveler_routine_route.clear()
	sailmaker_routine_route.clear()
	traveler_routine_route_target_set = false
	sailmaker_routine_route_target_set = false
	_update_traveler_schedule()
	_update_sailmaker_schedule()
	_record_world_event("raft_extension_dismantled", {"wood_returned": wood_returned, "keel_beams_returned": RAFT_EXTENSION_KEEL_COST, "guest_cabin_frames_returned": cabin_frame_returned, "blueprint_retained": _has_blueprint("keel_deck_expansion"), "guest_cabin_blueprint_retained": _has_blueprint("tide_guest_cabin")})
	message = "你先退回原筏面，再卸下龙骨甲板。四块船板与远礁龙骨都收回了；" + ("听潮客舱的木料和舱骨也一并收回。" if cabin_frame_returned > 0 else "") + "学会的图样仍记在心里，备齐材料便能重建。"
	_refresh_nearfuture_hud()
	_save_progress()
	_update_hud()
	return true


func _cancel_build(show_message: bool = true) -> void:
	var was_editing := not editing_fixture_id.is_empty()
	editing_fixture_id = ""
	preview_quarter_turns = 0
	fixture_preview_checked_position = Vector3.INF
	fixture_preview_checked_turns = -1
	building_mode = false
	preview_valid = false
	if is_instance_valid(build_preview):
		build_preview.queue_free()
	build_preview = null
	if show_message:
		message = "已取消搬移；原家具、朝向和库存都没有改变。" if was_editing else "你收起了搭建预览，木料还在。"
		_update_hud()


func _build_shared_meal_setting(structure: Node3D) -> void:
	if structure.get_node_or_null("SharedMealSetting"):
		return
	var setting := Node3D.new()
	setting.name = "SharedMealSetting"
	structure.add_child(setting)
	_add_local_visual_box(setting, "WovenMat", SHARED_MEAL_MAT_OFFSET, Vector3(1.35, 0.035, 0.55), Color("896646"))
	for index in range(3):
		var x := SHARED_MEAL_MAT_OFFSET.x + float(index - 1) * 0.43
		_add_local_visual_cylinder(setting, "Bowl%d" % index, Vector3(x, 0.30, 0.4), 0.15, 0.09, Color("8d958e"))
		_add_local_visual_cylinder(setting, "Soup%d" % index, Vector3(x, 0.349, 0.4), 0.12, 0.008, Color("de9b4f"))
	_add_local_visual_cylinder(setting, "CoveredPot", Vector3(-1.05, 0.70, -0.75), 0.21, 0.035, Color("b39667"))
	_refresh_shared_meal_visuals()

func _refresh_shared_meal_visuals() -> void:
	if ark_root == null:
		return
	var structure := ark_root.get_node_or_null("BuiltShelter") as Node3D
	if structure == null:
		return
	var setting := structure.get_node_or_null("SharedMealSetting") as Node3D
	if setting == null:
		return
	setting.visible = shared_meal_gathering_pending or shared_meal_count > 0
	for index in range(3):
		(setting.get_node("Soup%d" % index) as Node3D).visible = shared_meal_gathering_pending and not shared_meal_paused
	(setting.get_node("CoveredPot") as Node3D).visible = shared_meal_gathering_pending and shared_meal_paused and not pressure_galley_built
	var pot := structure.get_node_or_null("HearthPot")
	if pot:
		for part in ["PotLid", "LidHandle"]:
			(pot.get_node(part) as Node3D).visible = not shared_meal_gathering_pending or shared_meal_paused

func _clear_shelter_for_rebuild() -> void:
	# Same-scene loads must replace this cabin, not stack an opaque second roof.
	# Only these four interactions belong to it; other fixtures remain untouched.
	_update_shelter_cutaway_nameplates()
	for index in range(interactables.size() - 1, -1, -1):
		var entry: Dictionary = interactables[index]
		if str(entry.get("id", "")) not in ["cot", "hearth", "resident_keepsake", "sailmaker_awning"]:
			continue
		var marker: Node = entry.get("node")
		if is_instance_valid(marker):
			if marker.get_parent():
				marker.get_parent().remove_child(marker)
			marker.queue_free()
		interactables.remove_at(index)
	for path in ["BuiltShelter", "CotInteractable", "HearthInteractable", "ResidentKeepsakeInteractable", "SailmakerAwningInteractable"]:
		var previous := _ark_node(path)
		if previous:
			ark_root.remove_child(previous)
			previous.queue_free()


func _update_shelter_roof_cutaway() -> void:
	var structure := _ark_node("BuiltShelter") as Node3D
	if structure == null:
		home_art_sample.update_visibility(self)
		_update_shelter_cutaway_nameplates()
		return
	var roof := structure.get_node_or_null("Roof") as Node3D
	if roof == null:
		home_art_sample.update_visibility(self)
		_update_shelter_cutaway_nameplates()
		return
	var cutaway := false
	if shelter_built and is_instance_valid(player) and structure.is_visible_in_tree() and not is_swimming:
		var local := structure.to_local(player.global_position)
		var deck_local := ark_root.to_local(player.global_position)
		var was_open := bool(roof.get_meta("cutaway_active", false))
		# Enter at the supported doorway as well as inside. A wider exit region
		# avoids flicker on the threshold or during an ordinary jump.
		var half_width := 1.30 if was_open else 1.05
		var back := -1.00 if was_open else -0.80
		var front := 2.10 if was_open else 1.85
		var low := -0.35 if was_open else -0.25
		var high := 1.85 if was_open else 0.75
		var supported := _ark_local_walk_position_supported(Vector2(deck_local.x, deck_local.z), 0.38)
		if was_open and (player.is_on_floor() or deck_local.y >= 0.03):
			# The conservative entry footprint ends before the actual deck edge.
			# Grounded feet or an ordinary jump above the raft's 0.03 m deck may
			# use the exit band. Its height cap stays below the roof underside;
			# projected feet must still be on deck, never off-boat or underwater.
			# This presentation-only exception does not weaken any route guard.
			supported = _ark_local_walk_position_supported(Vector2(deck_local.x, deck_local.z), 0.0)
		cutaway = absf(local.x) <= half_width and local.z >= back and local.z <= front and local.y >= low and local.y <= high and supported
	roof.set_meta("cutaway_active", cutaway)
	# Roof.visible remains the damage/repair flag. Only its central face and
	# attached surface details yield to the camera; the eaves/frame stay opaque.
	for part in ["CenterFace", "RoofRidgeBinding", "RoofCanvasPatch", "RoofCanvasPatchSeam"]:
		var visual := roof.get_node_or_null(part) as Node3D
		if visual:
			visual.visible = not cutaway
	var brace := structure.get_node_or_null("ReefShellStormBrace") as Node3D
	if brace:
		brace.visible = roof.visible and not cutaway
	home_art_sample.update_visibility(self)
	_update_shelter_cutaway_nameplates(structure, cutaway)


func _update_shelter_cutaway_nameplates(structure: Node3D = null, cutaway: bool = false) -> void:
	# Only the three nearby labels which can cover the cabin's hands/cloth yield.
	# Projected lanes stay ordered when residents move or the raft turns, without
	# changing the camera, text, label style, interaction targets or actor geometry.
	_place_shelter_cutaway_nameplate(_ark_node("HearthInteractable") as Node3D, structure, cutaway, 3.1)
	_place_shelter_cutaway_nameplate(traveler_marker, structure, cutaway and traveler_boarded, 4.2)
	_place_shelter_cutaway_nameplate(sailmaker_marker, structure, cutaway and sailmaker_boarded, 5.3)


func _place_shelter_cutaway_nameplate(marker: Node3D, structure: Node3D, cutaway: bool, lane: float) -> void:
	if not is_instance_valid(marker):
		return
	var sign := marker.get_node_or_null("Name") as Label3D
	if sign == null:
		return
	var nearby := false
	if cutaway and is_instance_valid(structure) and is_instance_valid(camera) and marker.get_parent() == ark_root:
		var local := structure.to_local(marker.global_position)
		nearby = absf(local.x) <= 2.1 and local.z >= -1.6 and local.z <= 2.1 and local.y >= -0.35 and local.y <= 0.8 and camera.global_basis.y.y > 0.1
	if not nearby:
		if sign.has_meta("cutaway_base_position"):
			sign.position = sign.get_meta("cutaway_base_position")
			sign.remove_meta("cutaway_base_position")
		return
	if not sign.has_meta("cutaway_base_position"):
		sign.set_meta("cutaway_base_position", sign.position)
	var base: Vector3 = sign.get_meta("cutaway_base_position")
	var anchor := marker.to_global(base)
	var view := camera.get_camera_transform().affine_inverse()
	var projection := camera.get_camera_projection()
	var local_anchor := view * anchor
	var local_target := view * (structure.global_position + camera.global_basis.y * lane)
	var local_up := view.basis * Vector3.UP
	var clip := projection * Vector4(local_anchor.x, local_anchor.y, local_anchor.z, 1.0)
	var target := projection * Vector4(local_target.x, local_target.y, local_target.z, 1.0)
	var step := projection * Vector4(local_up.x, local_up.y, local_up.z, 0.0)
	# Fresh load can rebuild the cabin before the first normal camera pose.
	if target.w <= 0.0001:
		sign.position = base
		sign.remove_meta("cutaway_base_position")
		return
	# Equal camera-up world heights are not equal screen heights in perspective.
	# Solve (clip.y + lift * step.y) / (clip.w + lift * step.w) for this lane;
	# only world Y changes, so the name keeps its owner's horizontal anchor.
	var target_y := target.y / target.w
	var divisor := step.y - target_y * step.w
	if absf(divisor) > 0.0001:
		anchor.y += (target_y * clip.w - clip.y) / divisor
	sign.position = marker.to_local(anchor)


func _build_shelter_at(position: Vector3) -> void:
	_clear_shelter_for_rebuild()
	var structure := Node3D.new()
	structure.name = "BuiltShelter"
	structure.position = position
	ark_root.add_child(structure)
	_add_local_box(structure, "Floor", Vector3(0, 0.12, 0), Vector3(3.0, 0.14, 2.4), Color("9b7650"), false)
	_add_local_box(structure, "Back", Vector3(0, 1.25, -1.12), Vector3(3.0, 2.2, 0.14), Color("76593f"), true)
	_add_local_box(structure, "Left", Vector3(-1.42, 1.25, 0), Vector3(0.14, 2.2, 2.2), Color("76593f"), true)
	_add_local_box(structure, "Right", Vector3(1.42, 1.25, 0), Vector3(0.14, 2.2, 2.2), Color("76593f"), true)
	var roof := Node3D.new()
	roof.name = "Roof"
	roof.position = Vector3(0, 2.38, 0)
	structure.add_child(roof)
	# Same outer footprint and material, split into a central face and 18 cm rim.
	_add_local_visual_box(roof, "CenterFace", Vector3.ZERO, Vector3(2.84, 0.18, 2.24), Color("a58b66"))
	for side in [-1.0, 1.0]:
		_add_local_visual_box(roof, "EaveLeft" if side < 0.0 else "EaveRight", Vector3(side * 1.51, 0, 0), Vector3(0.18, 0.18, 2.24), Color("a58b66"))
		_add_local_visual_box(roof, "EaveBack" if side < 0.0 else "EaveFront", Vector3(0, 0, side * 1.21), Vector3(3.2, 0.18, 0.18), Color("a58b66"))
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
	hearth_sign.font = UI_FONT
	hearth_sign.name = "Name"
	hearth_sign.text = "蒸汽饭釜" if pressure_galley_built else "火盆小锅"
	hearth_sign.position.y = 0.8
	hearth_sign.font_size = 24
	hearth_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_style_nearby_world_label(hearth_sign)
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
	_build_shared_meal_setting(structure)
	if resident_keepsake_present:
		_add_resident_keepsake()
	if sailmaker_awning_raised:
		_add_sailmaker_awning()
	_update_lantern_lighting(weather_phase == WeatherPhase.STORM)
	_update_shelter_roof_cutaway()
	surface_sample.apply_shelter(structure)
	if not _restoring_progress:
		home_art_sample.apply(self)


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
	_update_shelter_roof_cutaway()


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
	sign.font = UI_FONT
	sign.name = "Name"
	sign.text = "并排潮贝 · 两次共餐" if shared_meal_count >= 2 else "守潮人留下的潮贝"
	sign.position.y = 0.28
	sign.font_size = 20
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_style_nearby_world_label(sign)
	sign.modulate = Color("fff0c9")
	marker.add_child(sign)
	ark_root.add_child(marker)
	interactables.append({"id": "resident_keepsake", "node": marker, "amount": 0})


func _clear_fixture_for_rebuild(fixture_id: String) -> void:
	if fixture_id not in ["storage", "workbench"]:
		return
	# Only these two builders own these exact ark-local roots and markers.
	# Remove registrations before freeing; interaction/edit lookups use their names.
	for index in range(interactables.size() - 1, -1, -1):
		if str(interactables[index].get("id", "")) == fixture_id:
			interactables.remove_at(index)
	for previous in [_fixture_node(fixture_id), _fixture_marker(fixture_id)]:
		if is_instance_valid(previous):
			ark_root.remove_child(previous)
			# These scriptless subtrees have no callbacks to finish. Free now so
			# repeated rebuilds leave neither queued bodies nor occupied names.
			previous.free()
	if editing_fixture_id == fixture_id:
		if is_instance_valid(build_preview):
			build_preview.get_parent().remove_child(build_preview)
			build_preview.free()
		build_preview = null
		_cancel_build(false)
	# Routes are transient layout caches, not saved work, stock or history.
	traveler_routine_route.clear()
	sailmaker_routine_route.clear()
	traveler_routine_route_target_set = false
	sailmaker_routine_route_target_set = false
	resident_gather_route.clear()
	resident_gather_route_index = 0
	vessel_navigation.invalidate_layout()


func _build_storage_at(position: Vector3) -> void:
	_clear_fixture_for_rebuild("storage")
	var crate := Node3D.new()
	crate.name = "BuiltStorage"
	crate.position = position
	crate.rotation.y = storage_quarter_turns * PI / 2.0
	ark_root.add_child(crate)
	_add_local_box(crate, "Body", Vector3(0, 0.42, 0), Vector3(0.9, 0.72, 0.78), Color("79583e"), true)
	_add_local_box(crate, "Lid", Vector3(0, 0.82, 0), Vector3(0.98, 0.12, 0.86), Color("a47c53"), true)
	_set_fixture_collision_enabled("storage", storage_collision_enabled)
	_add_local_box(crate, "FrontHandle", Vector3(0, 0.55, 0.41), Vector3(0.25, 0.09, 0.06), Color("c4a66b"), false)
	var marker := Node3D.new()
	marker.name = "StorageInteractable"
	marker.rotation.y = storage_quarter_turns * PI / 2.0
	marker.position = position + Vector3(0, 0.5, 0)
	var sign := Label3D.new()
	sign.font = UI_FONT
	sign.name = "Name"
	sign.text = "储物箱\nE 存取木料"
	sign.position.y = 0.3
	sign.no_depth_test = true
	sign.font_size = 24
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_style_nearby_world_label(sign)
	sign.modulate = Color("fff0c9")
	marker.add_child(sign)
	ark_root.add_child(marker)
	interactables.append({"id": "storage", "node": marker, "amount": 0})
	_refresh_nearfuture_hud()


func _build_workbench_at(position: Vector3) -> void:
	_clear_fixture_for_rebuild("workbench")
	var bench := Node3D.new()
	bench.name = "BuiltWorkbench"
	bench.position = position
	bench.rotation.y = workbench_quarter_turns * PI / 2.0
	ark_root.add_child(bench)
	_add_local_box(bench, "Legs", Vector3(0, 0.32, 0), Vector3(1.0, 0.58, 0.68), Color("594d43"), true)
	_add_local_box(bench, "Top", Vector3(0, 0.66, 0), Vector3(1.12, 0.16, 0.78), Color("9a7551"), true)
	_set_fixture_collision_enabled("workbench", workbench_collision_enabled)
	_add_local_box(bench, "SpiritSocket", Vector3(0, 0.79, -0.12), Vector3(0.28, 0.08, 0.24), Color("729c92"), false)
	var marker := Node3D.new()
	marker.name = "WorkbenchInteractable"
	marker.rotation.y = workbench_quarter_turns * PI / 2.0
	marker.position = position + Vector3(0, 0.5, 0)
	var sign := Label3D.new()
	sign.font = UI_FONT
	sign.name = "Name"
	sign.text = "阵枢工作台"
	sign.position.y = 0.75
	sign.font_size = 24
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_style_nearby_world_label(sign)
	sign.modulate = Color("fff0c9")
	marker.add_child(sign)
	ark_root.add_child(marker)
	interactables.append({"id": "workbench", "node": marker, "amount": 0})
	_refresh_nearfuture_hud()


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
	sign.font = UI_FONT
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
	_refresh_nearfuture_hud()


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
	sign.font = UI_FONT
	sign.name = "Name"
	sign.text = "听潮客舱 · 留给远客的一盏灯"
	sign.position.y = 0.78
	sign.font_size = 20
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_style_nearby_world_label(sign)
	sign.modulate = Color("fff0c9")
	marker.add_child(sign)
	ark_root.add_child(marker)
	interactables.append({"id": "guest_cabin", "node": marker, "amount": 0})
	if not _restoring_progress:
		home_art_sample.apply(self)


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
	sign.font = UI_FONT
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
	sign.font = UI_FONT
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
	sign.font = UI_FONT
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
	sign.font = UI_FONT
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
	guest_cabin_sign.font = UI_FONT
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
	sign.font = UI_FONT
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
	warning_ring.top_level = true
	warning_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_mesh := TorusMesh.new()
	# The outer rim is the real damage boundary, not a decorative source glow.
	ring_mesh.inner_radius = PRESSURE_VENT_DANGER_RADIUS - 0.18
	ring_mesh.outer_radius = PRESSURE_VENT_DANGER_RADIUS
	ring_mesh.ring_segments = 8
	ring_mesh.rings = 96
	warning_ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color("ffd080")
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
	sign.font = UI_FONT
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
	sign.font = UI_FONT
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


func _style_nearby_world_label(sign: Label3D) -> void:
	# Default 0.005 world pixels shrink these labels to 5–8 screen pixels at
	# the normal camera distance. Keep raft names readable, with bounded lines.
	# Nearby E/F actions remain in the full-size focused interaction hint.
	sign.font_size = 32
	sign.pixel_size = 0.009
	sign.outline_size = 4
	sign.outline_modulate = Color("17252a")
	sign.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sign.width = 400.0


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
	sign.font = UI_FONT
	sign.name = "Name"
	sign.text = title
	# Stagger the two resident nameplates without moving their interaction targets.
	var label_height := 2.7 if id == "resident" else 1.85 if id == "sailmaker" else 0.1 if id == "home" else 1.25
	sign.position = Vector3(0, label_height, 0)
	sign.font_size = 36
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_style_nearby_world_label(sign)
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
	sign.font = UI_FONT
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
	sign.font = UI_FONT
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
	sign.font = UI_FONT
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
	sign.font = UI_FONT
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
	beast_name.font = UI_FONT
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
	warning_sign.font = UI_FONT
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
	if not editing_fixture_id.is_empty():
		return "布置家园：R 旋转 · 左键确认 · 右键/Esc 取消；只编辑原甲板，不消耗材料。"
	if building_mode:
		return "选择设施落点；左键确认，右键/Esc 取消。"
	if sailing_mode:
		return "家随舟走：W/S 航行、A/D 转向；E 停船后上岸采集，回船建造。M 查看远礁与航路。"
	if weather_phase == WeatherPhase.STORM:
		if not shelter_built:
			return "风雨正急，眼下还没有避风棚；仙舟原位停航，仍可探索。按 R 等雨势过去，再检查筏舷。"
		return "风雨正急，仙舟原位停航；可在棚下避雨或继续探索。按 R 等雨势过去，再检查筏舷。"
	if shelter_roof_damaged or raft_edge_damaged:
		if _available_build_wood() > 0:
			return "回木筏与家园交互，修复受损处（每处 1 木）；筏舷修好即可继续航行。"
		return "先找木料，再回家修复受损的棚顶或筏舷。"
	if not shelter_built:
		if _available_build_wood() < BUILD_COST:
			return "船尾 E 现在就能掌舵；停船上岸收集 %d 块漂木，回船用 3 木搭棚。M 查看航路。" % (BUILD_COST - _available_build_wood())
		return "木料已够：回船用基础避风棚模板或 B 搭棚；房屋随船移动，不必先经历风雨。"
	if not storage_built:
		return "棚屋已能随舟远行。可邀请岸上居民同行；B 用 2 木造储物箱，继续准备工作台与扩甲。"
	if not workbench_built:
		return "停船用 B 建阵枢工作台（2 木）；本舟储箱可直接供料，居民采回的木料不用再搬进背包。"
	if not _has_blueprint("keel_deck_expansion"):
		return "家园已备好：船尾 E 掌舵，M 查看远礁沉筏；靠岸上岛打捞龙骨、4 木与永久扩甲图样。"
	if not raft_extension_built:
		if _available_build_wood() < RAFT_EXTENSION_WOOD_COST or keel_beams < RAFT_EXTENSION_KEEL_COST:
			return "扩甲图样已记住：需要 4 木与 1 龙骨；本舟储箱直接供料，仍缺的材料可上岸寻找。"
		return "远行所得已够：停船后打开 H 的龙骨扩甲蓝图，消耗 4 木与 1 龙骨，添一段甲板和夜铺。"
	return "新甲板已随舟同行。自由选下一处泊地；可邀请居民同行，让她们在船上休息、与守潮人采集共餐。"


func _hud_choice_open() -> bool:
	return _lantern_table_open() or food_storage.pending or modern_pack_choice_pending or household_work_choice_pending or traveler_choice_pending or sailmaker_choice_pending or resident_repair_choice_pending or resident_gather_policy_choice_pending or preparation_choice_pending or repair_choice_pending or raft_extension_dismantle_pending or jade_sail_guest_choice_pending or jade_sail_industry_choice_pending or pressure_galley_choice_pending

# Structured presentation data follows the SAME priority as keyboard dispatch.
# No choice is recovered by parsing dialogue prose; the controller retains intent.
func _hud_choice_view() -> Dictionary:
	if _lantern_table_open() or (world_chart and world_chart.visible) or (hud_drawer and hud_drawer.visible): return {}
	if raft_extension_dismantle_pending: return _choice_view("dismantle", ["确认拆解", "保留甲板"])
	if food_storage.pending: return _choice_view("pantry",["存入随身食物","取出 1 份热汤","取出 1 份鲜贝"],"关闭储粮格")
	if modern_pack_choice_pending: return _choice_view("modern_pack", ["确认收纳", "保持运行"])
	if household_work_choice_pending: return _choice_view("household", ["接受分工", "拒绝"], "保持原样")
	if jade_sail_guest_choice_pending: return _choice_view("guest", ["交还舷珠", "留下舷珠"])
	if jade_sail_industry_choice_pending: return _choice_view("industry", ["接受提案", "暂不接受"])
	if pressure_galley_choice_pending: return _choice_view("galley", ["安装饭釜", "暂缓"])
	if resident_gather_policy_choice_pending: return _choice_view("gather", ["木料优先", "鲜贝优先", "按家中缺口"], "保持原安排")
	if traveler_choice_pending: return _choice_view("tidekeeper", ["邀请上筏", "暂不同行"])
	if sailmaker_choice_pending: return _choice_view("sailmaker", ["邀请上筏", "暂不同路"])
	if resident_repair_choice_pending: return _choice_view("resident_repair", ["请她修理", "自己处理或稍后"])
	if preparation_choice_pending:
		return _choice_view("preparation", ["固定避风棚", "固定筏舷", "不用绳"] if shelter_built else ["固定筏舷", "接受风雨损伤"], "暂不安排")
	if repair_choice_pending: return _choice_view("repair", ["修复棚顶", "修复筏舷", "稍后再修"])
	return {}

func _choice_view(id: String, labels: Array, escape_label: String = "") -> Dictionary:
	var options: Array = []
	for index in range(labels.size()): options.append({"key": KEY_1 + index, "label": "%d · %s" % [index + 1, labels[index]]})
	if not escape_label.is_empty(): options.append({"key": KEY_ESCAPE, "label": "Esc · " + escape_label})
	return {"id": id, "options": options}

func _on_hud_choice_requested(code: int, choice_id: String) -> void:
	# Reject stale clicks after a rebuild/choice change, rather than executing an
	# old button's key against a different modal or against ordinary world input.
	var current := _hud_choice_view()
	if current.is_empty() or current.id != choice_id: return
	for option in current.options:
		if int(option.key) == code:
			var event := InputEventKey.new()
			event.keycode = code
			event.pressed = true
			_unhandled_key_input(event)
			_refresh_nearfuture_hud()
			return

func _lantern_table_open() -> bool:
	return is_instance_valid(lantern_table_ui) and lantern_table_ui.visible

func _lantern_partner(id: String) -> Node3D:
	if id == "sailmaker" and sailmaker_boarded: return sailmaker_marker
	if id == "tidekeeper" and traveler_boarded and not resident_gather_pending and not resident_repair_pending: return traveler_marker
	return null

func _lantern_partner_present(id: String) -> bool:
	var partner := _lantern_partner(id)
	if not is_instance_valid(partner) or partner.get_parent() != ark_root or not partner.is_visible_in_tree(): return false
	var center := shelter_position + Vector3(SHARED_MEAL_MAT_OFFSET.x, .12, SHARED_MEAL_MAT_OFFSET.z)
	return absf(partner.position.y - center.y) < .4 and partner.position.distance_to(center) <= 2.3

func _open_lantern_table() -> void:
	if _hud_choice_open() or building_mode or sailing_mode or (world_chart and world_chart.visible): return
	if hud_drawer: hud_drawer.hide()
	if shared_meal_count < 1 or not _player_at_shared_table() or weather_phase == WeatherPhase.STORM or shared_meal_gathering_pending:
		message = "先和居民在灯下吃过一顿饭，再回到自家火盆旁邀请她坐一会儿。风雨正急或大家还在赴桌时，先把眼前的事安顿好。"
		_update_hud()
		return
	var state: Dictionary = lantern_table.snapshot()
	var partner_id := str(state.opponent) if state.phase != "idle" else "sailmaker" if _lantern_partner_present("sailmaker") else "tidekeeper"
	if not _lantern_partner_present(partner_id):
		message = "牌序还好好收着。等%s回到火边、不在搬运或修理时，再招呼她继续；不会为了重开而偷换这局的牌。" % ("缝帆人" if partner_id == "sailmaker" else "守潮人")
		_update_hud()
		return
	if state.phase == "idle":
		if not lantern_table.begin(partner_id, Time.get_ticks_usec()): return
		_record_world_event("lantern_table_started", {"resident_id": partner_id, "round": 1, "stakes": false, "shared_meal_count": shared_meal_count})
		if lantern_table.view().phase == "settled": _record_lantern_result()
	if not is_instance_valid(lantern_table_ui):
		var layer := CanvasLayer.new()
		layer.name = "LanternTableLayer"
		layer.layer = 30
		add_child(layer)
		lantern_table_ui = LanternTableUIScript.new()
		var theme := Theme.new()
		theme.default_font = UI_FONT
		lantern_table_ui.theme = theme
		layer.add_child(lantern_table_ui)
		lantern_table_ui.action_requested.connect(_on_lantern_table_action)
	var body := sailmaker_body if partner_id == "sailmaker" else traveler_body
	lantern_table_props.open(self, _lantern_partner(partner_id), body)
	lantern_table_ui.present(lantern_table.view(), _lantern_table_line())
	orbit_camera.release()
	_save_progress()

func _lantern_table_line() -> String:
	var view: Dictionary = lantern_table.view()
	var name_ := "守潮人" if view.opponent == "tidekeeper" else "缝帆人"
	if view.phase == "settled":
		var reply := "‘收得很稳，这局我认输。再来？’" if view.result == "player_win" else "‘这回轮到我笑了。别急，热茶还在。’" if view.result == "resident_win" else "‘刚刚好，谁也不占便宜。’"
		return name_ + "把牌拢到桌边：" + reply + "\n这一局不输赢物资，只记在你们共同的闲暇里。"
	var memory := "她将茶盏挪开一点，把一张暗牌压在掌下。"
	if view.opponent == "sailmaker" and household_work.completed > 0:
		memory = "‘船上那些修补，我都记着。手里的牌，我可不会替你补。’"
	elif view.opponent == "sailmaker" and sailmaker_awning_raised:
		memory = "‘门口那片雨檐是我缝的。今晚不缝帆，陪你看看这几张牌。’"
	elif resident_keepsake_present and shared_meal_count >= 2:
		memory = "她望了一眼梁下并排的潮贝：‘第二只碗都留住了，一张牌急什么。’"
	elif shared_meal_count > 0:
		memory = "‘上回分汤时还只顾着吹凉。现在倒能慢慢坐着了。’"
	var advice := "‘想好就亮牌，不必逞强。’" if int(view.player_score) >= 18 else "‘要不要再看一张？我等你。’"
	return name_ + "：" + memory + "\n" + advice

func _record_lantern_result() -> void:
	var view: Dictionary = lantern_table.view()
	_record_world_event("lantern_table_round_completed", {"resident_id": view.opponent, "round": view.round, "result": view.result, "player_score": view.player_score, "resident_score": view.resident_score, "stakes": false})

func _on_lantern_table_action(action: String) -> void:
	if not _lantern_table_open(): return
	if action == "close":
		lantern_table_ui.hide()
		lantern_table_props.close()
		_save_progress()
		_update_hud()
		return
	if action == "save":
		lantern_table_ui.save_feedback(_save_progress())
		return
	var before: Dictionary = lantern_table.view()
	var changed := false
	if action == "hit": changed = lantern_table.hit()
	elif action == "stand": changed = lantern_table.stand()
	elif action == "again":
		changed = lantern_table.begin(str(before.opponent), Time.get_ticks_usec())
		if changed: _record_world_event("lantern_table_started", {"resident_id": before.opponent, "round": lantern_table.view().round, "stakes": false, "shared_meal_count": shared_meal_count})
	if not changed: return
	if lantern_table.view().phase == "settled": _record_lantern_result()
	lantern_table_ui.present(lantern_table.view(), _lantern_table_line())
	_save_progress()

func _toggle_hud_drawer() -> void:
	if hud_drawer == null or _hud_choice_open() or (world_chart and world_chart.visible):
		return
	hud_drawer.visible = not hud_drawer.visible
	_update_hud()
	_update_interaction_hint()

func _activate_hud_action(action: Callable) -> void:
	if hud_drawer:
		hud_drawer.hide()
	action.call()

func _layout_hud_panels() -> void:
	if hud_panel == null or note_panel == null or hud_drawer == null:
		return
	var screen := get_viewport().get_visible_rect().size
	hud_panel.size = Vector2(360, 0)
	hud_toggle.position = Vector2(screen.x - 204, 20)
	hud_toggle.size = Vector2(184, 40)
	hud_drawer.position = Vector2(screen.x - 460, 72)
	hud_drawer.size = Vector2(440, maxf(260, screen.y - 216))
	var message_height := 224.0 if _hud_choice_open() or note.text.length() > 140 else 112.0
	note_panel.position = Vector2(20, screen.y - 144 - message_height)
	note_panel.size = Vector2(minf(620, screen.x - 40), message_height)
	save_status_notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	save_status_notice.position = Vector2(24, screen.y - 128)
	save_status_notice.size = Vector2(screen.x - 48, 48)

func _update_fixture_hud_layout() -> void:
	if hud_panel == null or hud_stack == null:
		return
	if _hud_choice_open() and hud_drawer:
		hud_drawer.hide()
	hud_edit_layout = building_mode
	hud.visible = true
	hud_panel.custom_minimum_size = Vector2(360, 0)
	hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE if building_mode else Control.MOUSE_FILTER_STOP
	note_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE if building_mode else Control.MOUSE_FILTER_STOP
	note_scroll.get_v_scroll_bar().mouse_filter = Control.MOUSE_FILTER_IGNORE if building_mode else Control.MOUSE_FILTER_STOP
	hud_toggle.disabled = _hud_choice_open() or (world_chart and world_chart.visible)
	hud_toggle.text = "收起面板 · H" if hud_drawer.visible else "操作 / 建造 · H"
	note_panel.visible = not (world_chart and world_chart.visible)


func _update_hud() -> void:
	home_templates.update_buttons(self,home_template_buttons)
	if is_instance_valid(kitchen_button): kitchen_button.text = "炊事岗位 · 自动备餐" + ("已开启" if kitchen.enabled else "已暂停")
	_update_modern_status()
	_refresh_shared_meal_visuals()
	_update_fixture_hud_layout()
	if save_status_notice:
		var warning := str(get_meta("save_warning", ""))
		save_status_notice.text = warning if not warning.is_empty() else str(get_meta("manual_save_notice", ""))
		save_status_notice.visible = not warning.is_empty() or (((world_chart and world_chart.visible) or (hud_drawer and hud_drawer.visible)) and not save_status_notice.text.is_empty())
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
		var detailed_text := "第 %d 天·%s  ·  生命 %d/%d\n木料 %d（随身）+ %d（储存） · 鲜贝 %d · 热汤 %d%s%s\n%s  ·  %s%s\n避难者 %d/%d（不含玩家）\n居民专用床位 %d · 临时避难名额 %d\n玩家床铺 %d · %s\n当前目标：%s" % [day_count, _day_period_label(), player_health, PLAYER_MAX_HEALTH, wood, stored_wood, raw_shellfish, stew_servings, exposure_text, swim_text, weather_text, shelter_status, (" · " + damage_text) if not damage_text.is_empty() else "", _resident_occupancy(), _resident_capacity(), _resident_berth_capacity(), _resident_temporary_refuge_capacity(), int(shelter_built), refuge_text, objective_text]
		if _resident_occupancy() > 0:
			detailed_text += "\n居民采集偏好：%s" % _resident_gather_policy_label()
			detailed_text += "\n家中缺口：" + home_demand.summary(self)
		detailed_text += "\n" + _build_supply_label()
		detailed_text += "\n居民营生：缝帆人%s（已修缮 %d 处）；房间用途见分工面板。" % [_household_work_status(), household_work.completed]
		if reef_beast_spooked or reef_beast_defeated:
			var beast_status := "已击退" if reef_beast_defeated else "%d/%d" % [reef_beast_health, REEF_BEAST_MAX_HEALTH]
			detailed_text += "\n远礁：礁背兽 %s · 礁壳 %d · 风撑 %s" % [beast_status, reef_shell_plates, "已安装" if reef_shell_brace_installed else "未安装"]
		hud_details.text = detailed_text
		hud.text = "第 %d 天·%s  生命 %d/%d\n木料 %d（随身）+%d（储存）\n鲜贝 %d · 热汤 %d\n%s%s%s%s\n当前目标：%s" % [day_count, _day_period_label(), player_health, PLAYER_MAX_HEALTH, wood, stored_wood, raw_shellfish, stew_servings, weather_text, exposure_text, swim_text, (" · " + damage_text) if not damage_text.is_empty() else "", objective_text]
	if note:
		var previous_note := note.text
		note.text = ("[搭建预览] " if building_mode else "") + message
		if building_mode and editing_fixture_id.is_empty():
			if build_preview and build_preview.has_meta("home_template_proposal"):
				var proposal: Dictionary = build_preview.get_meta("home_template_proposal")
				var failure := str(proposal.get("error","家园方案无效。"))
				if failure.is_empty() and _available_build_wood() < int(proposal.get("wood_cost",0)): failure = "木料不足：需要 %d，本舟可用 %d。" % [int(proposal.wood_cost),_available_build_wood()]
				note.text += "\n" + ("可确认施工 · 只搭缺少的部分。" if preview_valid else failure)
			else:
				note.text += "\n" + ("可放置" if preview_valid else "位置不合适，请在甲板承重区内选择位置。")
		if note.text != previous_note:
			note_scroll.set_deferred("scroll_vertical", 0)
		if raft_expansion_blueprint_button:
			raft_expansion_blueprint_button.disabled = not _has_blueprint("keel_deck_expansion") or raft_extension_built
			raft_expansion_blueprint_button.text = "蓝图册：龙骨扩甲 · 已学会" if _has_blueprint("keel_deck_expansion") else "蓝图册：龙骨扩甲 · 探索远礁沉筏解锁"
			if guest_cabin_blueprint_button:
				guest_cabin_blueprint_button.disabled = not _has_blueprint("tide_guest_cabin") or guest_cabin_built
				if guest_cabin_built:
					guest_cabin_blueprint_button.text = "蓝图册：听潮客舱 · 已建成"
				elif _has_blueprint("tide_guest_cabin"):
					guest_cabin_blueprint_button.text = "蓝图册：听潮客舱 · 3 木 + 1 舱骨（可用 %d 木、%d 舱骨）" % [_available_build_wood(), guest_cabin_frames]
				else:
					guest_cabin_blueprint_button.text = "蓝图册：听潮客舱 · 探索琼华舫解锁"
			if reef_shell_brace_button:
				reef_shell_brace_button.disabled = not _has_blueprint("reef_shell_storm_brace") or reef_shell_brace_installed or not shelter_built or reef_shell_plates < 1 or _available_build_wood() < REEF_SHELL_BRACE_WOOD_COST
				if reef_shell_brace_installed:
					reef_shell_brace_button.text = "蓝图册：礁壳风撑 · 已安装"
				elif _has_blueprint("reef_shell_storm_brace"):
					reef_shell_brace_button.text = "蓝图册：礁壳风撑 · %d 木 + %d 礁壳（可用 %d 木、%d 礁壳）" % [REEF_SHELL_BRACE_WOOD_COST, 1, _available_build_wood(), reef_shell_plates]
				else:
					reef_shell_brace_button.text = "蓝图册：礁壳风撑 · 击退远礁礁背兽解锁"

	if raft_fenders_button:
		raft_fenders_button.disabled = raft_fenders_installed or not _has_blueprint(RidgeCampScript.BLUEPRINT) or _available_build_wood() < RidgeCampScript.COST or sailing_mode or _distance_to_ark() > 6.5
		raft_fenders_button.text = "蓝图册：浮木护舷 · " + ("已安装，普通风浪护舷" if raft_fenders_installed else "4 木，回到本舟安装" if _has_blueprint(RidgeCampScript.BLUEPRINT) else "岩脊旧营地解锁")
	for button in [raft_expansion_blueprint_button, guest_cabin_blueprint_button, reef_shell_brace_button, raft_fenders_button]:
		if button:
			button.text = button.text.replace(" · ", "\n")
	_layout_hud_panels()


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
	# Keep the storm sky/Sun/overlay intact; retain readable ambient fill at night.
	var ambient_weather_blend := weather_blend
	if day_period == DayPeriod.NIGHT and storm_active:
		ambient_energy_scale = 0.88
		ambient_weather_blend = 0.40
	var base_ambient: Color = daylight["ambient"]
	var base_sky_top: Color = daylight["sky_top"]
	var base_sky_horizon: Color = daylight["sky_horizon"]
	var base_ground: Color = daylight["ground"]
	var base_sun_color: Color = daylight["sun_color"]
	var base_sun_rotation: Vector3 = daylight["sun_rotation"]
	if weather_environment:
		weather_environment.ambient_light_color = base_ambient.lerp(ambient_weather_tint, ambient_weather_blend)
		weather_environment.ambient_light_energy = float(daylight["ambient_energy"]) * ambient_energy_scale
	if sky_material:
		sky_material.sky_top_color = base_sky_top.lerp(sky_weather_top, weather_blend)
		sky_material.sky_horizon_color = base_sky_horizon.lerp(sky_weather_horizon, weather_blend)
		sky_material.ground_bottom_color = base_ground.lerp(ambient_weather_tint.darkened(0.35), weather_blend)
		sky_material.ground_horizon_color = base_sky_horizon.lerp(sky_weather_horizon.darkened(0.12), weather_blend)
	if sun_light:
		sun_light.rotation_degrees = base_sun_rotation
		sun_light.light_energy = float(daylight["sun_energy"]) * sun_energy_scale * COAST_SUN_ENERGY_SCALE
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
				"ambient": Color("8b9caf"), "ambient_energy": 0.85,
				"sun_color": Color("8097b9"), "sun_energy": 0.20,
				"sun_rotation": Vector3(-35.0, 36.0, 0.0),
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
	_sync_economy_from_legacy()
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
		"schema_version": SaveScript.MAX_SCHEMA_VERSION,
		"kitchen": kitchen.snapshot(),
		"modern_utilities": modern_utilities.snapshot(),
		"ridge_camp_searched": ridge_camp_searched,
		"raft_fenders_installed": raft_fenders_installed,
		"household_work": household_work.snapshot(),
		"lantern_table": lantern_table.snapshot(),
		"resident_task_id": resident_task_id,
		"jade_task_id": jade_task_id,
		"modules": _module_snapshot(),
		"water": water.snapshot(),
		"vessel_navigation": vessel_navigation.snapshot(),
		"life_period_elapsed": life_period_elapsed,
		"last_shore_replenish_day": last_shore_replenish_day,
		"day_count": day_count,
		"day_period": day_period,
		"wood": wood,
		"player_health": player_health,
		"raw_shellfish": raw_shellfish,
		"stew_servings": stew_servings,
		"shared_meal_day": shared_meal_day,
		"shared_meal_count": shared_meal_count,
		"shared_meal_gathering_pending": shared_meal_gathering_pending,
		"shared_meal_paused": shared_meal_paused,
		"shared_meal_participants": shared_meal_participants.duplicate(),
		"resident_keepsake_present": resident_keepsake_present,
		"stored_wood": stored_wood,
		"shelter_built": shelter_built,
		"shelter_position": {"x": shelter_position.x, "y": shelter_position.y, "z": shelter_position.z},
		"storage_built": storage_built,
		"storage_quarter_turns": storage_quarter_turns,
		"storage_collision_enabled": storage_collision_enabled,
		"workbench_collision_enabled": workbench_collision_enabled,
		"workbench_quarter_turns": workbench_quarter_turns,
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
		"sailmaker_awning_phase": sailmaker_awning_phase,
		"sailmaker_awning_sewing_elapsed": sailmaker_awning_sewing_elapsed,
		"sailmaker_awning_install_elapsed": sailmaker_awning_install_elapsed,
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
	if _restoring_progress:
		return false
	_reconcile_household_work()
	resident_kitchen.check_dependencies(self)
	if save_service == null:
		return false
	if bool(get_meta("save_load_blocked", false)):
		message = str(get_meta("save_warning", "旧档已保留，本次试玩不会覆盖它。"))
		if player and player.is_inside_tree() and ark_root and ark_root.is_inside_tree():
			_update_hud()
		return false
	var result: Dictionary = save_service.save_state(_build_save_state())
	if bool(result.get("ok", false)):
		set_meta("save_warning", "")
		return true
	message = _save_failure_message(result)
	set_meta("save_warning", message)
	if player and player.is_inside_tree() and ark_root and ark_root.is_inside_tree():
		_update_hud()
	return false


func _manual_save_progress() -> void:
	if _save_progress():
		message = "这一刻已经记在旧玉里。"
	set_meta("manual_save_notice", message)
	_update_hud()


func _save_failure_message(result: Dictionary) -> String:
	match str(result.get("code", "")):
		"unsupported_version":
			return "旧档来自更新版本，已保留且不会被覆盖。本次为临时试玩，不会保存；请用匹配版本续接。"
		"corrupt_save":
			return "主档和备份均无法读取，文件已保留。本次为临时试玩，不会保存；请先备份旧档并检查恢复。"
		"invalid_state", "invalid_schema":
			return "本次进度包含无效数据，尚未保存；原有存档保持不变。"
		"save_too_large":
			return "本次进度超过存档容量上限，尚未保存；原有存档保持不变。"
	return "存档未写入，本次进度尚未保存；请检查可用空间与目录权限（%s）。" % str(result.get("error", result.get("code", "unknown")))


func _block_coast_load(dependencies: Array) -> void:
	# A missing required dependency must not manufacture resources or overwrite
	# the original save. Keep menu access and a visible error, but stop simulation.
	set_meta("save_load_blocked", true)
	message = "海岸场景与存档不匹配，进度未应用；请返回主界面后继续，以重新创建场景。"
	set_meta("save_warning", message)
	set_meta("coast_dependency_errors", dependencies.duplicate())
	set_process(false)
	set_physics_process(false)
	_present_progress_warning(message)


func _present_progress_warning(warning: String) -> void:
	# Rejection can stop simulation before the next ordinary HUD update. Make
	# the existing save notice usable immediately, without gameplay selectors.
	if is_instance_valid(save_status_notice):
		save_status_notice.text = warning
		save_status_notice.visible = true
	_refresh_nearfuture_hud()


func _reject_progress_load(warning: String) -> void:
	# A fresh blocked session still needs its ordinary default module bindings.
	# For any initialized session, do not shut down/recreate water or mutate any
	# gameplay module when a load is rejected.
	if not _modules_ready:
		_initialize_module_state()
	set_meta("save_load_blocked", true)
	message = warning
	set_meta("save_warning", warning)
	_present_progress_warning(warning)


func _load_progress() -> void:
	# Read once, and reject a missing *uncollected* scene dependency before any
	# water/module reset. Collection/replenishment remain canonical-owned.
	var loaded: Dictionary = save_service.load_state() if save_service != null else {"ok": false, "code": "no_save"}
	if not loaded.get("ok", false) and str(loaded.get("code", "")) != "no_save":
		_reject_progress_load(_save_failure_message(loaded))
		return
	if loaded.get("ok", false):
		var raw: Dictionary = loaded.get("state", {})
		if int(raw.get("schema_version", 0)) >= 34 and not _prepare_module_restore(raw, false):
			_reject_progress_load("存档模块不一致，原档与当前会话已保留。")
			return
	if loaded.get("ok", false) and opening_coast.initialized:
		var expected_ids: Variant = loaded.get("state", {}).get("collected_ids", [])
		var missing: Array[String] = opening_coast.validate_live_contract(expected_ids if expected_ids is Array else [])
		if not missing.is_empty():
			_block_coast_load(missing)
			return
	_restoring_progress = true
	if _lantern_table_open(): lantern_table_ui.hide()
	lantern_table_props.close()
	_modules_ready = false
	_pending_modules = {}
	_new_water_session = false
	water.shutdown()
	water = WaterScript.new()
	_load_progress_impl(loaded)
	_initialize_module_state()
	if opening_coast.initialized:
		var grounded: Dictionary = opening_coast.refresh_loaded_visuals()
		if grounded.ok:
			opening_coast.reconcile_loaded_player()
			moonback_terrain.reconcile_loaded_player(self,ground_sampler)
			moonback_landing.ground_sources(self,ground_sampler)
			_reconcile_moonback_gather_target()
		else:
			_block_coast_load(grounded.errors)
	_restoring_progress = false
	_update_shelter_roof_cutaway()
	_refresh_nearfuture_hud()


func _reconcile_moonback_gather_target() -> void:
	resident_regional_route_retry_at = 0
	resident_regional_route_jobs.clear()
	if not resident_gather_pending or resident_gather_target_id not in MoonbackLandingScript.SOURCES:
		return
	if resident_gather_phase in ["outbound","collecting"]:
		var node := get_node_or_null(resident_gather_target_id) as Node3D
		if node != null and not node.is_queued_for_deletion():
			resident_gather_target_position = node.global_position
			# A relocated source must be reached again, never harvested remotely
			# from an old collecting pose. Reservation and remaining stock stay intact.
			if resident_gather_phase == "collecting" and traveler_marker.global_position.distance_to(node.global_position) > .3:
				gathering.restart_approach(resident_task_id)
				resident_gather_phase = "outbound"
				resident_gather_pickup_remaining = RESIDENT_AUTO_GATHER_PICKUP_SECONDS
	var planner := RegionalRouteScript.new()
	planner.configure(self)
	var support: Variant = planner.support(traveler_marker.global_position)
	if support != null and traveler_marker.global_position.y < float(support)+.12:
		traveler_marker.global_position.y = float(support)+.12
	resident_gather_route.clear()
	resident_gather_route_index = 0


func _load_progress_impl(result: Dictionary) -> void:
	if save_service == null:
		return
	if not bool(result.get("ok", false)):
		_new_water_session = str(result.get("code", "")) == "no_save"
		if str(result.get("code", "")) != "no_save":
			set_meta("save_load_blocked", true)
			message = _save_failure_message(result)
			set_meta("save_warning", message)
		return
	var raw: Dictionary = result.get("state", {})
	if int(raw.get("schema_version", 0)) >= 34 and not _prepare_module_restore(raw):
		set_meta("save_load_blocked", true)
		set_meta("save_warning", "存档模块不一致，原档已保留。")
		return
	var saved: Dictionary = _sanitize_saved_progress(raw)
	var saved_schema := int(saved.get("schema_version", 0))
	modern_pack_choice_pending = false
	food_storage.clear()
	home_demand.review_remaining = 1.0
	resident_washing.clear()
	resident_kitchen.clear()
	ModernUtilityProps.clear(self)
	modern_utilities = ModernUtilitiesScript.new()
	if saved_schema >= 40:
		var restored_modern: bool = modern_utilities.restore(saved.modern_utilities)
		assert(restored_modern)
	if not saved_schema in range(1, SaveScript.MAX_SCHEMA_VERSION + 1):
		return
	kitchen = KitchenScript.new()
	if saved_schema >= 42:
		var restored_kitchen: bool = kitchen.restore(saved.kitchen)
		if not restored_kitchen:
			_reject_progress_load("炊事岗位状态无法恢复，原档已保留。")
			return
	household_work = HouseholdWorkScript.new()
	if saved_schema >= 37:
		var restored_work: bool = household_work.restore(saved.household_work)
		assert(restored_work)
	lantern_table = LanternTableScript.new()
	if saved_schema >= 38:
		var restored_table: bool = lantern_table.restore(saved.lantern_table)
		assert(restored_table)
	household_work_choice_pending = false
	household_work_route_retry = 0.0
	household_work_bench_side = 0
	household_target_cache.clear()
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
	life_period_elapsed = float(saved.get("life_period_elapsed", 0.0)) if saved_schema >= 35 else 0.0
	last_shore_replenish_day = int(saved.get("last_shore_replenish_day", day_count)) if saved_schema >= 35 else day_count
	wood = clampi(int(saved.get("wood", 1)), 0, 999)
	player_health = clampi(int(saved.get("player_health", PLAYER_MAX_HEALTH)), 1, PLAYER_MAX_HEALTH) if saved_schema >= 30 else PLAYER_MAX_HEALTH
	raw_shellfish = clampi(int(saved.get("raw_shellfish", 0)), 0, 999)
	stew_servings = clampi(int(saved.get("stew_servings", 0)), 0, 999)
	shared_meal_day = clampi(int(saved.get("shared_meal_day", 0)), 0, day_count)
	shared_meal_count = clampi(int(saved.get("shared_meal_count", 0)), 0, 9999)
	shared_meal_gathering_pending = saved_schema >= 32 and bool(saved.get("shared_meal_gathering_pending", false))
	shared_meal_paused = shared_meal_gathering_pending and bool(saved.get("shared_meal_paused", false))
	shared_meal_participants.clear()
	var saved_meal_participants = saved.get("shared_meal_participants", [])
	if saved_meal_participants is Array:
		for participant in saved_meal_participants:
			var participant_id := str(participant)
			if ["player", "tidekeeper", "sailmaker"].has(participant_id) and not shared_meal_participants.has(participant_id):
				shared_meal_participants.append(participant_id)
	if shared_meal_gathering_pending and (not shared_meal_participants.has("player") or not shared_meal_participants.has("tidekeeper") or not shared_meal_participants.has("sailmaker")):
		shared_meal_gathering_pending = false
		shared_meal_paused = false
		shared_meal_participants.clear()
	resident_keepsake_present = bool(saved.get("resident_keepsake_present", shared_meal_count > 0))
	stored_wood = clampi(int(saved.get("stored_wood", 0)), 0, 9999)
	shelter_built = bool(saved.get("shelter_built", false))
	storage_built = bool(saved.get("storage_built", false))
	workbench_built = bool(saved.get("workbench_built", false))
	keel_beams = clampi(int(saved.get("keel_beams", 0)), 0, 1)
	keel_wreck_searched = bool(saved.get("keel_wreck_searched", false))
	learned_blueprint_ids = ["starter_shelter", "starter_home"]
	ridge_camp_searched = saved_schema >= 39 and bool(saved.get("ridge_camp_searched", false))
	raft_fenders_installed = saved_schema >= 39 and bool(saved.get("raft_fenders_installed", false))
	var saved_blueprints = saved.get("learned_blueprint_ids", [])
	if saved_blueprints is Array:
		for value in saved_blueprints:
			var blueprint_id := str(value)
			if ["starter_shelter", "starter_home", "keel_deck_expansion", "tide_compass", "tide_guest_cabin", "pressure_galley"].has(blueprint_id) or (saved_schema >= 30 and blueprint_id == "reef_shell_storm_brace") or (saved_schema >= 39 and blueprint_id == RidgeCampScript.BLUEPRINT) or (saved_schema >= 40 and blueprint_id == ModernUtilitiesScript.BLUEPRINT):
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
	# Legacy completion stays completed without reconstructing unobserved work.
	# Legacy unfinished gifts earn all progress online from an unstarted state.
	sailmaker_awning_phase = str(saved.sailmaker_awning_phase) if saved_schema >= 36 else "complete" if sailmaker_awning_raised else "unstarted"
	sailmaker_awning_sewing_elapsed = float(saved.sailmaker_awning_sewing_elapsed) if saved_schema >= 36 else 0.0
	sailmaker_awning_install_elapsed = float(saved.sailmaker_awning_install_elapsed) if saved_schema >= 36 else 0.0
	# Cached paths belong to the previous live scene layout, never the save.
	# This also matters when reloading into this same already-instantiated scene.
	sailmaker_routine_route.clear()
	sailmaker_routine_route_index = 0
	sailmaker_routine_route_target = Vector3.ZERO
	sailmaker_routine_route_target_set = false
	sailmaker_awning_route_starts_blocked = false
	sailmaker_awning_route_retry_remaining = 0.0
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
	storage_quarter_turns = FixturePlacement.saved_turns(saved.get("storage_quarter_turns", 0)) if saved_schema >= 33 else 0
	workbench_quarter_turns = FixturePlacement.saved_turns(saved.get("workbench_quarter_turns", 0)) if saved_schema >= 33 else 0
	storage_collision_enabled = saved_schema >= 33 and saved.get("storage_collision_enabled", false) is bool and saved.get("storage_collision_enabled", false) == true
	workbench_collision_enabled = saved_schema >= 33 and saved.get("workbench_collision_enabled", false) is bool and saved.get("workbench_collision_enabled", false) == true
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
	else:
		_clear_shelter_for_rebuild()
	if storage_built:
		_build_storage_at(storage_position)
	else:
		_clear_fixture_for_rebuild("storage")
	if workbench_built:
		_build_workbench_at(workbench_position)
	else:
		_clear_fixture_for_rebuild("workbench")
	if keel_wreck_searched:
		_refresh_keel_wreck_visual()
	if tide_station_searched:
		_refresh_tide_station_visual()
	if jade_sail_ark_searched:
		_refresh_jade_sail_ark_visual()
	if raft_extension_built:
		var extension_position := Vector3(0.0, 0.12, -4.2)
		if not _pending_modules.is_empty():
			var p: Dictionary = _pending_modules.construction.structures.raft_extension.position
			extension_position = Vector3(p.x, p.y, p.z)
		_build_raft_extension_at(extension_position)
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
			var restored_parent: Node = self if resident_gather_pending else ark_root
			if traveler_marker.get_parent() != restored_parent:
				traveler_marker.reparent(restored_parent, true)
			if resident_gather_pending:
				traveler_marker.global_position = saved_traveler_position
			else:
				traveler_marker.position = saved_traveler_position
			if not resident_gather_pending:
				_update_traveler_schedule()
	elif traveler_position_value is Dictionary and traveler_marker:
		traveler_marker.position = Vector3(float(traveler_position_value.get("x", traveler_marker.position.x)), float(traveler_position_value.get("y", traveler_marker.position.y)), float(traveler_position_value.get("z", traveler_marker.position.z)))
	var sailmaker_position_value = saved.get("sailmaker_position", {})
	if sailmaker_boarded and sailmaker_position_value is Dictionary and sailmaker_marker:
		sailmaker_marker.position = Vector3(float(sailmaker_position_value.get("x", sailmaker_marker.position.x)), float(sailmaker_position_value.get("y", sailmaker_marker.position.y)), float(sailmaker_position_value.get("z", sailmaker_marker.position.z)))
	_update_sailmaker_schedule()
	_update_sailmaker_work_visuals()
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
	if raft_fenders_installed:
		RidgeCampScript.add_fenders(ark_root)
	elif ark_root.get_node_or_null("RaftStormFenders") != null:
		ark_root.get_node("RaftStormFenders").free()
	_set_weather_visuals()
	_refresh_reef_beast_visual()


func _sanitize_saved_progress(source: Dictionary) -> Dictionary:
	# Keep valid progress in partially malformed historical saves, but never let
	# an unchecked JSON value reach int/float casts or typed collections below.
	var saved := source.duplicate(true)
	var defaults := _build_save_state()
	for key in defaults:
		if not saved.has(key):
			continue
		var value: Variant = saved[key]
		var fallback: Variant = defaults[key]
		if fallback is int or fallback is float:
			if not _finite_saved_number(value):
				saved[key] = fallback
		elif typeof(value) != typeof(fallback):
			saved[key] = fallback
		elif fallback is Dictionary and str(key).ends_with("position"):
			for axis in ["x", "y", "z"]:
				if value.has(axis) and not _finite_saved_number(value[axis]):
					value[axis] = fallback.get(axis, 0.0)
	if saved.get("world_events", []) is Array:
		var events: Array = []
		for event in saved.get("world_events", []):
			if event is Dictionary and _finite_saved_number(event.get("sequence", null)) and event.get("id", null) is String:
				if not event.get("facts", {}) is Dictionary:
					event["facts"] = {}
				events.append(event)
		saved["world_events"] = events.slice(-MAX_WORLD_EVENTS)
	var storm_facts: Dictionary = saved.get("last_resolved_storm_facts", {})
	if not _finite_saved_number(storm_facts.get("storm_number", 0)):
		storm_facts["storm_number"] = 0
	return saved


func _finite_saved_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) < 9223372036854775808.0


func _exit_tree() -> void:
	resident_washing.clear()
	resident_kitchen.clear()
	if save_service != null:
		_save_progress()
	lantern_table_props.close()
	water.shutdown()


# Module boundary: legacy fields remain presentation/compatibility projections.
func _initialize_module_state() -> void:
	construction.configure(economy)
	gathering.configure(economy)
	if _pending_modules.is_empty():
		_initialize_economy_legacy()
		construction.import_legacy(_legacy_structures())
		memories.import_legacy(world_events, event_sequence)
	else:
		economy.restore(_pending_modules.economy)
		construction.restore(_pending_modules.construction)
		gathering.restore(_pending_modules.gathering)
		resident_task_id = str(gathering.active_task("tidekeeper").get("id", ""))
		jade_task_id = str(gathering.active_task("ruan_qingyi").get("id", ""))
		memories.restore(_pending_modules.memories)
		_construction_sequence = int(_pending_modules.construction_sequence)
		water.restore(_pending_modules.water)
		vessel_navigation.restore(_pending_modules.navigation)
		world_events = memories.events()
		event_sequence = memories.sequence()
	# A new finite salvage source is added only after restoring old ownership.
	# Existing collected/installed states never get a replacement component.
	if economy.source(ModernUtilitiesScript.SOURCE).is_empty():
		economy.seed_source(ModernUtilitiesScript.SOURCE,"utility_core",1,"pressure_wreck")
	economy.seed_inventory(ModernUtilitiesScript.TANK,{})
	economy.set_capacity(ModernUtilitiesScript.TANK,6)
	FoodStorageRules.initialize(economy)
	if modern_utilities.installed:
		ModernUtilityProps.build(self)
	if _new_water_session:
		water.enable_gerstner()
	water.configure_backend(OS.get_environment("ARK_WATER_BACKEND") if OS.has_environment("ARK_WATER_BACKEND") else "gdscript", OS.get_environment("ARK_WATER_EXTENSION"))
	water.register_float("starter_ark", ark_root.position, 1.05)
	water.set_sleeping("starter_ark", not sailing_mode)
	water.apply_visual((get_node("Sea") as MeshInstance3D).material_override)
	_modules_ready = true


func _legacy_structures() -> Dictionary:
	var extension_position := Vector3(0.0, 0.12, -4.2)
	var extension := _ark_node("BuiltRaftExtension") as Node3D
	if extension:
		extension_position = extension.position
	return {
		"shelter": {"built": shelter_built, "position": _position_exact(shelter_position)},
		"storage": {"built": storage_built, "position": _position_exact(storage_position), "quarter_turns": storage_quarter_turns},
		"workbench": {"built": workbench_built, "position": _position_exact(workbench_position), "quarter_turns": workbench_quarter_turns},
		"raft_extension": {"built": raft_extension_built, "position": _position_exact(extension_position)},
		"guest_cabin": {"built": guest_cabin_built, "position": _position_exact(extension_position)},
	}


func _position_exact(position: Vector3) -> Dictionary:
	return {"x": position.x, "y": position.y, "z": position.z}


func _module_snapshot() -> Dictionary:
	# Legacy fixture/setup callers still write scalar fields. Convert those writes
	# through one declared structure command before taking an ownership snapshot;
	# no material charge or historical memory is fabricated by this compatibility path.
	var legacy := _legacy_structures()
	if not construction.structure_facts_equal({"structures": construction.state()}, {"structures": legacy}):
		_commit_construction({}, legacy, "move")
	return {"economy": economy.snapshot(), "construction": construction.snapshot(), "gathering": gathering.snapshot(), "memories": memories.snapshot(), "construction_sequence": _construction_sequence}


func _prepare_module_restore(saved: Dictionary, stage: bool = true) -> bool:
	# Validate the entire ownership bundle before the legacy shell can mutate nodes.
	if not KitchenScript.matches_save(saved): return false
	if int(saved.get("schema_version", 0)) >= 37 and not SaveScript.valid_household_work(saved):
		return false
	if int(saved.get("schema_version", 0)) >= 38 and not SaveScript.valid_lantern_table(saved):
		return false
	if int(saved.get("schema_version", 0)) >= 39 and not SaveScript.valid_coast_exploration(saved):
		return false
	if int(saved.get("schema_version", 0)) >= 40 and not ModernUtilitiesScript.matches_save(saved):
		return false
	if not MemoryScript._plain(saved) or not saved.get("collected_ids") is Array:
		return false
	if not saved.get("learned_blueprint_ids") is Array:
		return false
	for blueprint_id in saved.learned_blueprint_ids:
		if not blueprint_id is String:
			return false
	for id in saved.collected_ids:
		if not id is String:
			return false
	for key in ["traveler_boarded", "jade_sail_industry_active", "jade_sail_keeper_met", "jade_sail_ark_searched", "jade_sail_industry_acquired", "shelter_built", "storage_built", "workbench_built", "raft_extension_built", "guest_cabin_built"]:
		if not saved.get(key, false) is bool:
			return false
	if not saved.get("modules") is Dictionary or not saved.get("water") is Dictionary or not saved.get("vessel_navigation") is Dictionary:
		return false
	var bundle: Dictionary = saved.modules
	for key in ["economy", "construction", "gathering", "memories"]:
		if not bundle.get(key) is Dictionary:
			return false
	if not MemoryScript._integer(bundle.get("construction_sequence")):
		return false
	var candidate_economy = EconomyScript.new()
	var candidate_construction = ConstructionScript.new()
	var candidate_tasks = GatheringScript.new()
	var candidate_memories = MemoryScript.new()
	var candidate_water = WaterScript.new()
	candidate_construction.configure(candidate_economy)
	candidate_tasks.configure(candidate_economy)
	if not candidate_economy.restore(bundle.economy) or not candidate_construction.restore(bundle.construction) or not candidate_tasks.restore(bundle.gathering) or not candidate_memories.restore(bundle.memories) or not candidate_water.restore(saved.water):
		return false
	if not vessel_navigation.validate_snapshot(saved.vessel_navigation) or not _validate_gather_mirrors(saved, candidate_economy, candidate_tasks):
		return false
	if int(bundle.construction_sequence) != int(bundle.construction.get("sequence", -1)):
		return false
	var definitions: Dictionary = candidate_construction.state()
	for id in ["shelter", "storage", "workbench", "raft_extension", "guest_cabin"]:
		if not definitions.has(id) or bool(definitions[id].built) != bool(saved.get(id + "_built", false)):
			return false
		if id in ["shelter", "storage", "workbench"] and definitions[id].position != saved.get(id + "_position", {}):
			return false
	for id in ["storage", "workbench"]:
		var turns: Variant = definitions[id].get("quarter_turns", 0)
		if not MemoryScript._integer(turns) or int(turns) > 3 or turns != saved.get(id + "_quarter_turns", 0):
			return false
	if bool(saved.get("guest_cabin_built", false)) and (not bool(saved.get("raft_extension_built", false)) or not "tide_guest_cabin" in saved.get("learned_blueprint_ids", [])):
		return false
	if stage:
		_pending_modules = bundle.duplicate(true)
		_pending_modules["water"] = saved.water.duplicate(true)
		_pending_modules["navigation"] = saved.vessel_navigation.duplicate(true)
	return true


func _step_water(delta: float) -> void:
	if not _modules_ready or ark_root == null:
		return
	water.sync_horizontal("starter_ark", ark_root.global_position)
	water.set_sleeping("starter_ark", not sailing_mode)
	if bool(water.advance(delta).ok) and sailing_mode:
		ark_root.global_position = water.float_pose("starter_ark")
	water.apply_visual((get_node("Sea") as MeshInstance3D).material_override)


func _invalidate_committed_layout() -> void:
	resident_regional_route_jobs.clear()
	gathering.invalidate_routes()
	resident_gather_route.clear()
	resident_gather_route_index = 0
	vessel_navigation.invalidate_layout()
	traveler_routine_route.clear()
	sailmaker_routine_route.clear()
	traveler_routine_route_target_set = false
	sailmaker_routine_route_target_set = false


func _commit_construction(costs: Dictionary, states: Dictionary, kind: String = "build", validate: Callable = Callable()) -> bool:
	_sync_economy_from_legacy()
	var operation_id := "structure:%d" % (_construction_sequence + 1)
	var facts := {"structures": states}
	var validator := validate if validate.is_valid() else func() -> bool: return true
	var result: Dictionary
	if kind == "dismantle":
		result = construction.refund(operation_id, "player", costs, validator, facts)
	elif kind == "move":
		result = construction.move(operation_id, validator, facts)
	else:
		# Only wood in this vessel's actual chest is communal. Other ships' cargo,
		# carried gathering payloads and rare parts are never silently borrowed.
		var shared := {"wood": ["storage"]} if storage_built else {}
		result = construction.commit_shared(operation_id, "player", costs, shared, validator, facts)
	if not result.get("ok", false) or result.get("duplicate", false):
		return false
	_construction_sequence += 1
	_sync_legacy_from_economy()
	_invalidate_committed_layout()
	return true


func _available_build_wood() -> int:
	return wood + (stored_wood if storage_built else 0)


func _build_supply_label() -> String:
	return "可施工木料 %d（随身 %d + 本舟储箱 %d，先用随身）" % [_available_build_wood(), wood, stored_wood if storage_built else 0]


func _spend_home_wood(amount: int, purpose: String) -> bool:
	var shared := {"wood": ["storage"]} if storage_built else {}
	var receipt := "home_supply:%s:%d:%d" % [purpose, Time.get_ticks_usec(), economy.snapshot().receipts.size()]
	var paid: Dictionary = economy.consume_shared("player", {"wood": amount}, receipt, shared)
	if not paid.get("ok", false):
		message = "家园木料已经变化，没有扣除材料；请检查随身与储箱余量。"
		_update_hud()
		return false
	_sync_legacy_from_economy()
	return true

func _module_seed_sources() -> void:
	for entry in interactables:
		var resource := str(entry.get("id", ""))
		var id := str(entry.get("item_id", ""))
		if resource in ["wood", "shellfish"] and not id.is_empty() and not collected_ids.has(id):
			economy.seed_source(id, resource, maxi(0, int(entry.get("amount", 0))), "shore")

func _module_collect_direct(entry: Dictionary) -> bool:
	_module_seed_sources()
	var result: Dictionary = economy.collect_direct(str(entry.get("item_id", "")), "player")
	if not result.ok:
		return false
	var displaced := str(result.get("displaced_task_id", ""))
	if not displaced.is_empty():
		if displaced == resident_task_id:
			_abort_resident_gathering("resource_taken_before_arrival")
		elif displaced == jade_task_id:
			_abort_jade_sail_industry_gathering("resource_taken_before_arrival")
		else:
			gathering.cancel(displaced, "player_takeover")
	return true
func _sync_economy_from_legacy() -> void:
	pass # Compatibility properties already forward every write to the sole owner.

func _sync_legacy_from_economy() -> void:
	pass # Compatibility getters read the sole owner; no mirrored inventory exists.

func _initialize_economy_legacy() -> void:
	gathering.configure(economy)
	_module_seed_sources()
	if resident_gather_pending:
		var imported: Dictionary = gathering.import_legacy_task("tidekeeper",resident_gather_target_id,"storage" if resident_gather_resource == "wood" and storage_built else "player",resident_gather_phase,resident_gather_payload,resident_gather_resource,resident_gather_pickup_remaining)
		resident_task_id = str(imported.get("task_id",""))
	if jade_sail_industry_pending:
		var imported: Dictionary = gathering.import_legacy_task("ruan_qingyi",jade_sail_industry_target_id,"jade_sail",jade_sail_industry_phase,jade_sail_industry_payload,jade_sail_industry_resource,jade_sail_industry_pickup_remaining)
		jade_task_id = str(imported.get("task_id",""))

func _validate_gather_mirrors(saved: Dictionary, candidate_economy: RefCounted, candidate_tasks: RefCounted) -> bool:
	for tuple in [["wood","player","wood"],["raw_shellfish","player","shellfish"],["stew_servings","player","stew_servings"],["stored_wood","storage","wood"],["keel_beams","player","keel_beams"],["guest_cabin_frames","player","guest_cabin_frames"],["jade_sail_industry_wood","jade_sail","wood"],["jade_sail_industry_shellfish","jade_sail","shellfish"]]:
		var amount: Variant = saved.get(tuple[0],0)
		if not candidate_economy._quantity(amount) or int(amount) != candidate_economy.inventory(tuple[1],tuple[2]):
			return false
	var es: Dictionary = candidate_economy.snapshot()
	for id in es.sources:
		if (int(es.sources[id].remaining) == 0) != (id in saved.get("collected_ids", [])):
			return false
	for entry in candidate_tasks.snapshot().tasks.values():
		if entry.resident_id not in ["tidekeeper","ruan_qingyi"]:
			return false
	for tuple in [["resident_gather", "tidekeeper", "resident_task_id"],["jade_sail_industry", "ruan_qingyi", "jade_task_id"]]:
		var prefix: String = tuple[0]
		var pending: Variant = saved.get(prefix + "_pending", false)
		if not pending is bool:
			return false
		var active: Dictionary = candidate_tasks.active_task(tuple[1])
		if pending != not active.is_empty():
			return false
		if not pending:
			continue
		if saved.get(tuple[2], "") != active.id or saved.get(prefix + "_target_id", "") != active.source_id:
			return false
		var phase := str(saved.get(prefix + "_phase", ""))
		if phase not in ["outbound", "collecting", "returning"]:
			return false
		if phase != active.phase and not (phase == "returning" and active.phase == "cancel_return_pending"):
			return false
		if phase == "collecting":
			var remaining: Variant = saved.get(prefix + "_pickup_remaining")
			if not (remaining is int or remaining is float) or not is_finite(float(remaining)) or absf(float(remaining) - (0.65 - float(active.collect_elapsed))) > 0.000001:
				return false
		var payload: Variant = saved.get(prefix + "_payload", 0)
		if not candidate_economy._quantity(payload):
			return false
		var resource := str(saved.get(prefix + "_resource", ""))
		var source: Dictionary = candidate_economy.source(active.source_id)
		if not source.is_empty() and source.get("resource", "") != resource:
			return false
		var carried: Dictionary = candidate_economy.carried(active.id)
		if int(payload) != int(carried.get("amount", 0)) or (int(payload) > 0 and carried.get("resource", "") != resource):
			return false
		if (int(payload) > 0) != (active.source_id in saved.get("collected_ids", [])):
			return false
		if tuple[1] == "tidekeeper" and not saved.get("traveler_boarded", false):
			return false
		if tuple[1] == "ruan_qingyi":
			if not saved.get("jade_sail_industry_active", false) or not saved.get("jade_sail_keeper_met", false) or not saved.get("jade_sail_ark_searched", false):
				return false
			if resource == "wood" and not saved.get("jade_sail_industry_acquired", false):
				return false
	return true
