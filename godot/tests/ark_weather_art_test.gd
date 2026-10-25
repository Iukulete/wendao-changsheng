extends "res://tests/ark_cabin_furniture_test.gd"
## Finite real house builds inherited. Weather/cover/poses here are explicit
## visual fixtures; no calendar advance or invented storm resources/events.
func _capture(stage: String) -> void:
	if stage == "01_paid_starter_home": _starter_weather()
	elif stage == "04_paid_guest_cabin": _guest_weather()

func _starter_weather() -> void:
	var sample = game.home_art_sample
	var weather = sample.weather
	var before: Dictionary = game._build_save_state()
	var phase: int = game.weather_phase
	var collisions := _collisions()
	var lights := _lights()
	var player_pose: Transform3D = game.player.global_transform
	var ark_pose: Transform3D = game.ark_root.global_transform
	assert(is_instance_valid(weather.root) and not weather.rain.emitting and not weather.root.visible)
	var root_id: int = weather.root.get_instance_id()
	game.weather_phase = game.WeatherPhase.STORM
	for i in 60: game._process(1.0/60.0)
	assert(weather.rain.amount==768 and weather.rain.draw_passes==1 and weather.rain.emitting and weather.root.visible)
	assert(not weather.rain.local_coords and not weather.rain.cast_shadow)
	assert(weather.root.find_children("*","CollisionObject3D",true,false).is_empty() and weather.root.find_children("*","Light3D",true,false).is_empty())
	var shelter := game._ark_node("BuiltShelter") as Node3D
	game.player.global_position = shelter.to_global(Vector3(0,.2,.3))
	game._update_shelter_roof_cutaway()
	assert(weather.material.get_shader_parameter("primary_active") and weather.material.get_shader_parameter("primary_cutaway"))
	var inverse: Transform3D = weather.material.get_shader_parameter("primary_from_world")
	assert((inverse*shelter.global_position).length()<.001)
	game.ark_root.position = Vector3(-8,0,3)
	game.ark_root.rotation.y = .65
	game._update_shelter_roof_cutaway()
	inverse = weather.material.get_shader_parameter("primary_from_world")
	assert((inverse*shelter.to_global(Vector3(.5,.8,.5))).is_equal_approx(Vector3(.5,.8,.5)),"rain cover follows translated/yawed live rooms")
	game.ark_root.global_transform = ark_pose
	game.shelter_roof_damaged = true
	game._update_shelter_roof_cutaway()
	assert(not weather.material.get_shader_parameter("primary_active"),"actual damage flag disables shelter coverage even before its visual refresh")
	game.shelter_roof_damaged = false
	var roof := shelter.get_node("Roof") as Node3D
	shelter.remove_child(roof)
	game._update_shelter_roof_cutaway()
	assert(not weather.material.get_shader_parameter("primary_active"),"no invisible rain roof after the actual roof leaves the tree")
	shelter.add_child(roof)
	game._update_shelter_roof_cutaway()
	assert(weather.material.get_shader_parameter("primary_active"))
	var strength: float = weather.strength
	for delta in [0.0,-1.0,NAN,INF]: weather.update(game,delta)
	assert(weather.strength==strength)
	_key(KEY_F7)
	assert(not game.has_node("ArkWeatherArt") and not is_instance_valid(weather.root))
	game._process(1.0/60.0)
	assert(not game.has_node("ArkWeatherArt"),"disabled presentation cannot respawn its rain")
	_key(KEY_F7)
	assert(weather.root.get_instance_id()!=root_id and weather.rain.emitting and weather.strength==1.0)
	root_id = weather.root.get_instance_id()
	for i in 100: sample.apply(game)
	assert(weather.root.get_instance_id()==root_id and game.find_children("ArkWeatherArt","Node3D",false,false).size()==1)
	game.weather_phase = game.WeatherPhase.AFTER
	for i in 60: game._process(1.0/60.0)
	assert(not weather.rain.emitting and not weather.root.visible)
	game.weather_phase = phase
	game.player.global_transform = player_pose
	game._update_shelter_roof_cutaway()
	assert(collisions==_collisions() and lights==_lights() and game.MemoryScript.facts_equal(before,game._build_save_state()),"rain never edits resources, weather, facts, collision or lighting")
	assert(game._save_progress())
	for i in 3:
		game._load_progress()
		assert(game.find_children("ArkWeatherArt","Node3D",false,false).size()==1)
		assert(game.MemoryScript.facts_equal(_disk_view(before),_disk_view(game._build_save_state())))

func _guest_weather() -> void:
	var before: Dictionary = game._build_save_state()
	var phase: int = game.weather_phase
	var player_pose: Transform3D = game.player.global_transform
	var collisions := _collisions()
	var lights := _lights()
	var guest := game._ark_node("BuiltRaftExtension/GuestCabin") as Node3D
	var weather = game.home_art_sample.weather
	game.weather_phase = game.WeatherPhase.STORM
	game.player.global_position = guest.to_global(Vector3(0,.3,.3))
	for i in 60: game._process(1.0/60.0)
	assert(weather.material.get_shader_parameter("guest_active") and weather.material.get_shader_parameter("guest_cutaway"))
	var inverse: Transform3D = weather.material.get_shader_parameter("guest_from_world")
	assert((inverse*guest.to_global(Vector3(.3,.7,-.5))).is_equal_approx(Vector3(.3,.7,-.5)))
	var canopy := guest.get_node("CanvasAwning")
	guest.remove_child(canopy)
	game._update_shelter_roof_cutaway()
	assert(not weather.material.get_shader_parameter("guest_active"))
	guest.add_child(canopy)
	game._update_shelter_roof_cutaway()
	assert(weather.material.get_shader_parameter("guest_active"))
	game.weather_phase = phase
	game.player.global_transform = player_pose
	for i in 60: game._process(1.0/60.0)
	assert(collisions==_collisions() and lights==_lights() and game.MemoryScript.facts_equal(before,game._build_save_state()))
	print("ARK_WEATHER_ART_TEST_OK: bounded GPU rain, real frame/fade, live roof transforms/cutaway/damage/removal, F7/rebuild/load and no simulation ownership")
