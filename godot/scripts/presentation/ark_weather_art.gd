extends RefCounted
## Bounded GPU rain; physical weather, roofs, resources and saved facts stay in
## their existing owners. No per-drop CPU queries, collision bodies or lights.
const DROP_BUDGET := 768
const RAIN_SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength = 0.0;
uniform float water_level = -1.05;
uniform bool primary_active = false;
uniform bool guest_active = false;
uniform bool primary_cutaway = false;
uniform bool guest_cutaway = false;
uniform mat4 primary_from_world;
uniform mat4 guest_from_world;
varying vec3 rain_world;
void vertex() { rain_world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
bool covered(vec3 world) {
 if(primary_active) {
  vec3 p=(primary_from_world*vec4(world,1.0)).xyz;
  bool room=abs(p.x)<1.50 && p.z> -1.19 && p.z<1.19 && (p.y<2.48||primary_cutaway);
  bool porch=abs(p.x)<1.07 && p.z>=1.00 && p.z<1.60 && (p.y<2.39||primary_cutaway);
  if(room||porch)return true;
 }
 if(guest_active) {
  vec3 p=(guest_from_world*vec4(world,1.0)).xyz;
  if(abs(p.x)<1.28 && p.z> -1.20 && p.z<.26 && (p.y<2.03||guest_cutaway))return true;
 }
 return false;
}
void fragment() {
 if(rain_world.y<water_level || covered(rain_world))discard;
 float edge=1.0-smoothstep(.12,.50,abs(UV.x-.5));
 float ends=smoothstep(0.0,.18,UV.y)*(1.0-smoothstep(.65,1.0,UV.y));
 ALBEDO=vec3(.55,.72,.78);
 ALPHA=strength*edge*ends*.32;
}
"""
var root: Node3D
var rain: GPUParticles3D
var material: ShaderMaterial
var strength := 0.0
var _signature: Array = []

func _ensure(world: Node3D) -> bool:
	if is_instance_valid(root) and root.is_inside_tree() and root.get_parent() == world: return true
	clear()
	if world.has_node("ArkWeatherArt"): return false # Never adopt another owner.
	root = Node3D.new()
	root.name = "ArkWeatherArt"
	world.add_child(root)
	rain = GPUParticles3D.new()
	rain.name = "LocalStormRain"
	rain.amount = DROP_BUDGET
	rain.lifetime = 1.30
	rain.preprocess = 1.30
	rain.fixed_fps = 30
	rain.interpolate = true
	rain.local_coords = false
	rain.use_fixed_seed = true
	rain.seed = 107313
	rain.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	rain.visibility_aabb = AABB(Vector3(-15,-27,-15),Vector3(30,30,30))
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.emitting = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(9,.08,9)
	process.direction = Vector3(.18,-1,.05).normalized()
	process.spread = 2.0
	process.initial_velocity_min = 14.0
	process.initial_velocity_max = 18.0
	process.gravity = Vector3(2.5,-9.8,.7)
	process.scale_min = .85
	process.scale_max = 1.15
	process.attractor_interaction_enabled = false
	rain.process_material = process
	var shader := Shader.new()
	shader.code = RAIN_SHADER
	material = ShaderMaterial.new()
	material.shader = shader
	var drop := QuadMesh.new()
	drop.size = Vector2(.020,.52)
	drop.material = material
	rain.draw_pass_1 = drop
	root.add_child(rain)
	strength = 1.0 if world.weather_phase == world.WeatherPhase.STORM else 0.0
	return true

func update(world: Node3D, delta: float) -> void:
	if world == null or not _ensure(world): return
	var storm: bool = world.weather_phase == world.WeatherPhase.STORM
	var step := minf(maxf(delta,0),.1) if is_finite(delta) else 0.0
	strength = move_toward(strength,1.0 if storm else 0.0,step*1.4)
	rain.emitting = storm
	root.visible = strength>.001
	var player := world.get("player") as Node3D
	if is_instance_valid(player):
		var center := player.global_position
		center.x = floorf(center.x/4.0)*4.0
		center.z = floorf(center.z/4.0)*4.0
		center.y += 14.0
		root.global_position = center
	var primary := world.get_node_or_null("ArkRoot/BuiltShelter") as Node3D
	var guest := world.get_node_or_null("ArkRoot/BuiltRaftExtension/GuestCabin") as Node3D
	var primary_roof := primary.get_node_or_null("Roof") as Node3D if is_instance_valid(primary) else null
	var primary_valid := is_instance_valid(primary_roof) and primary_roof.is_visible_in_tree() and not bool(world.get("shelter_roof_damaged"))
	var primary_face := primary_roof.get_node_or_null("CenterFace") as Node3D if primary_valid else null
	var guest_face := guest.get_node_or_null("CanvasAwning") as Node3D if is_instance_valid(guest) else null
	var guest_valid := is_instance_valid(guest_face) and guest.is_inside_tree() and guest.is_visible_in_tree()
	var primary_cutaway := is_instance_valid(primary_face) and not primary_face.is_visible_in_tree()
	var guest_cutaway := guest_valid and not guest_face.is_visible_in_tree()
	var primary_pose := primary.global_transform.affine_inverse() if primary_valid else Transform3D.IDENTITY
	var guest_pose := guest.global_transform.affine_inverse() if guest_valid else Transform3D.IDENTITY
	var water_level: float = world.get("water").mean_height
	var signature := [primary_valid,guest_valid,primary_cutaway,guest_cutaway,primary_pose,guest_pose,water_level,strength]
	if signature != _signature:
		material.set_shader_parameter("primary_active",primary_valid)
		material.set_shader_parameter("guest_active",guest_valid)
		material.set_shader_parameter("primary_cutaway",primary_cutaway)
		material.set_shader_parameter("guest_cutaway",guest_cutaway)
		material.set_shader_parameter("primary_from_world",primary_pose)
		material.set_shader_parameter("guest_from_world",guest_pose)
		material.set_shader_parameter("water_level",water_level)
		material.set_shader_parameter("strength",strength)
		_signature = signature

func clear() -> void:
	if is_instance_valid(root): root.free()
	root = null
	rain = null
	material = null
	strength = 0.0
	_signature.clear()
