extends RefCounted
## Test-only inverse projection of independently validated intentional coast changes.
## Never use this for raw same-runtime geometry/material/state comparison.
const OLD_FIXTURE := "res://tests/support/coast_prechange_geometry.json"
const OLD_FIXTURE_SHA := "f7e830e94761cb6025685fc106ee5dafe8cf8bab03e9c89b6508b3b3e8010ce5"
const FOCUS_FIXTURE := "res://tests/support/coast_prechange_focus_ring.json"
const FOCUS_FIXTURE_SHA := "c727626ae70ff4d0b503244bdd8b2c4b4a7f721a3b12bd3d83d46cf84c134ad3"
# These two aliases already occur twice in the byte-pinned pre-coast capture.
# No other duplicate path or additional multiplicity is permitted.
const BASELINE_DUPLICATE_PATHS := {
	"CanvasLayer#0/ArkContextPanel/ScrollContainer#0/TextureRect#0": 2,
	"CanvasLayer#0/ArkHelpBuildDrawer/VBoxContainer#0/ArkHelpScroll/TextureRect#0": 2,
}
const LEGACY_REFERENCE := "res://tests/support/ark_opening_coast_reference.gd"
const LEGACY_REFERENCE_SHA := "58d1615de1aba4c4eea3d3da369214f23d74b1a4e81850b4a84402bac8a0e543"
const REFERENCE := "res://tests/support/ark_coast_v2_reference.gd"
const REFERENCE_SHA := "a30ed6a56c2da8f42c1d68b266d677099e5608998c0571c66f0e4d551abf1556"
const OLD_WATER_SHA := "d299ba4c27686391afd65aec79687873c4edc1c54036f7fcfce5caedf4837841"
const WATER_SHA := "89daf71344da795262bd94dc726ac7ef710fb17b7257d03ced764be3ea12e994"
const COAST_SHADER_SHA := "8bdd654a5834a239dc0abe0902a10a5637efe419f82731dfa289d3399daa624d"
const V2Additions = preload("res://tests/support/coast_v2_additions_contract.gd")
const MoonbackContract = preload("res://tests/support/moonback_terrain_contract.gd")
const LandingContract = preload("res://tests/support/moonback_landing_contract.gd")
var landing_contract = LandingContract.new()
var moonback_contract = MoonbackContract.new()
var additions = V2Additions.new()
const SUN_SCALE := .36453125
const PIVOT := "CoastVisualGroundOffset"
const PIVOT_ROOTS := ["residentMarker", "sailmakerMarker", "TidekeeperFloatboxInteractable",
	"DriftwoodShore", "DriftwoodRidge", "TidalShellsNear", "TidalShellsCove", "ShoreRuin",
	"ShoreRuin/RuinBrokenStone", "ShoreRuin/RuinPillarRight"]
const LABEL_BASES := {"residentMarker": 2.7, "sailmakerMarker": 1.85,
	"TidekeeperFloatboxInteractable": .68, "TidalShellsNear": .62,
	"TidalShellsCove": .62, "ShoreRuin": 2.55}
const NEW_UNIFORMS := ["opening_heights", "depth_tint", "shallow_tint", "foam_tint", "ripple_probe"]
var game: Node3D
var observer: Object
var old_rows: Dictionary = {}
var old_focus_row: Dictionary = {}
var expected_focus_y := NAN
var expected_top: ArrayMesh
var expected_rock_a: ArrayMesh
var expected_rock_b: ArrayMesh
var expected_materials: Dictionary = {}
var expected_heights := PackedByteArray()

func configure(world: Node3D, test: Object) -> void:
	game = world
	observer = test
	_check(FileAccess.get_sha256(OLD_FIXTURE) == OLD_FIXTURE_SHA, "old observed fixture bytes must remain pinned")
	_check(FileAccess.get_sha256(REFERENCE) == REFERENCE_SHA, "approved geometry reference must remain byte-exact")
	_check(FileAccess.get_sha256(LEGACY_REFERENCE) == LEGACY_REFERENCE_SHA, "V2 must preserve the original V1 reference bytes")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OLD_FIXTURE))
	for row in document.rows:
		old_rows[row.path] = row
	_check(FileAccess.get_sha256(FOCUS_FIXTURE) == FOCUS_FIXTURE_SHA, "old observed focus-ring fixture bytes must remain pinned")
	var focus_document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOCUS_FIXTURE))
	old_focus_row = focus_document.row
	_check(old_focus_row.path == "ArkInteractionFocusRing" and _focus_fixture_value(old_focus_row.transform[1]) == _focus_fixture_value([1300000,34500,-600000]), "historical focus-ring fixture must remain the exact independently observed position")
	_build_expected_materials()

func _check(ok: bool, message: String) -> void:
	observer.call("_check", ok, "COAST_HISTORICAL: " + message)

func _resource(value: Resource) -> Dictionary:
	return observer.call("_resource", value)

func _bytes(value: Variant) -> PackedByteArray:
	return var_to_bytes(value)

# JSON parses its integer-looking coordinates as floats. Canonicalize numeric
# TYPE only for this small historical focus fixture; no rounding, tolerance,
# omitted fields or use in raw same-runtime mesh/material/state comparisons.
func _focus_fixture_value(value: Variant) -> Variant:
	if value is int or value is float:
		return float(value)
	if value is Array:
		var out: Array = []
		for entry in value:
			out.append(_focus_fixture_value(entry))
		return out
	if value is Dictionary:
		var out := {}
		for key in value:
			out[key] = _focus_fixture_value(value[key])
		return out
	return value

func historical_path(path: String) -> String:
	var result := ""
	for segment in path.split("/"):
		if segment == PIVOT and result in PIVOT_ROOTS:
			continue
		result += ("/" if not result.is_empty() else "") + segment
	return result

func _is_pivot(path: String) -> bool:
	return path.get_file() == PIVOT and historical_path(path.get_base_dir()) in PIVOT_ROOTS

func _new_root(path: String) -> String:
	if path == "IslandLandmass/SubmergedVisualCap" or path == "ShelteredGrassGroups":
		return path
	for index in range(9):
		var root := "CoastClusterRock%02d" % index
		if path == root or path.begins_with(root + "/"):
			return root
	return ""

func _only_mesh(root: Node) -> MeshInstance3D:
	var found: MeshInstance3D
	for child in root.get_children():
		if child is MeshInstance3D:
			_check(found == null, "expected one direct rock mesh")
			found = child
	return found

func _only_shape(root: Node) -> CollisionShape3D:
	var found: CollisionShape3D
	for child in root.get_children():
		if child is CollisionShape3D:
			_check(found == null, "expected one direct rock shape")
			found = child
	return found

func _check_mesh(actual: MeshInstance3D, expected: ArrayMesh, label: String) -> void:
	_check(actual != null and actual.mesh is ArrayMesh, label + " must use an actual ArrayMesh")
	if actual == null or not actual.mesh is ArrayMesh:
		return
	_check(actual.mesh.get_surface_count() == 1, label + " has exactly one surface")
	_check(_bytes(actual.mesh.surface_get_arrays(0)) == _bytes(expected.surface_get_arrays(0)), label + " raw vertex/normal/UV/tangent/index arrays differ from frozen approved geometry in this runtime")

func validate_geometry() -> void:
	moonback_contract.validate(game,observer)
	landing_contract.validate(game,observer)
	var reference: RefCounted = load(REFERENCE).new()
	var data: Dictionary = reference.call("_refined_topology")
	_check(data.ok and data.faces.size() == 7127, "frozen reference topology must remain7127")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in data.faces:
		reference.call("_triangle", surface, reference.call("_from_parameter", data.vertices[face[0]]), reference.call("_from_parameter", data.vertices[face[1]]), reference.call("_from_parameter", data.vertices[face[2]]))
	expected_top = reference.call("_smooth", surface.commit(), true)
	var constants: Dictionary = load(LEGACY_REFERENCE).get_script_constant_map()
	expected_rock_a = reference.call("_rock_mesh", constants.ROCK_A_POINTS, constants.ROCK_A_FACES)
	expected_rock_b = reference.call("_rock_mesh", constants.ROCK_B_POINTS, constants.ROCK_B_FACES)
	var top := game.get_node("IslandLandmass/Shoreline") as MeshInstance3D
	_check_mesh(top, expected_top, "opening top")
	var shape: ConcavePolygonShape3D = game.get_node("IslandLandmass/ShorelineCollision").shape
	_check(_bytes(shape.get_faces()) == _bytes(expected_top.get_faces()) and shape.backface_collision, "opening collision must exactly equal approved top")
	for row in [["ShoreRockA", expected_rock_a, Vector2(5,-7)], ["ShoreRockB", expected_rock_b, Vector2(18,-13)]]:
		var rock := game.get_node(row[0]) as StaticBody3D
		_check(rock.get_child_count() == 2 and rock.collision_layer == 1 and rock.collision_mask == 1, "main-rock cardinality/collision policy")
		_check(Vector2(rock.position.x, rock.position.z) == row[2], "main-rock XZ must remain authored")
		_check_mesh(_only_mesh(rock), row[1], row[0])
		var rock_shape := _only_shape(rock).shape as ConvexPolygonShape3D
		_check(rock_shape != null and _bytes(rock_shape.points) == _bytes(row[1].get_faces()), "main-rock convex shape must match actual mesh")
	# Pure frozen reference routines only; never call apply/_add_groups or mutate
	# any world through the reference helper.
	reference.set("island", game.get_node("IslandLandmass"))
	reference.set("top_faces_local", expected_top.get_faces())
	reference.call("_build_height_index")
	# Unlike satellites, the two pre-existing rocks use the frozen0.10 inset.
	# Verify the entire installed transform before the historical root-Y inverse;
	# otherwise an isolated vertical rock regression would be silently erased.
	for row in [["ShoreRockA", expected_rock_a, Vector3(5,.7,-7)], ["ShoreRockB", expected_rock_b, Vector3(18,.8,-13)]]:
		var expected := _grounded_transform(reference, row[1].get_faces(), [row[2], Vector3.ONE, 0.0], .10)
		var actual := game.get_node(row[0]) as Node3D
		_check(actual.transform == expected, "main-rock complete transform must retain independent frozen supportY and0.10embedding: " + row[0])
	var height_image: Image = reference.call("build_height_image", 384)
	expected_heights = height_image.get_data()
	# Independent frozen geometry sample at the historical earned-actions target,
	# not the candidate ground_focus_ring() result or a regenerated old golden.
	var focus_point := Vector3(float(old_focus_row.transform[1][0])/100000.0, 0, float(old_focus_row.transform[1][2])/100000.0)
	var focus_height: Variant = reference.call("sample_height", focus_point)
	_check(focus_height != null, "historical shell focus target must have frozen terrain support")
	expected_focus_y = float(focus_height) + .022
	var placements := [
		[Vector3(3.8,0,-7.8),Vector3(.72,.56,.8),.7], [Vector3(6.1,0,-8.0),Vector3(.48,.38,.72),-1.1], [Vector3(4.1,0,-6.7),Vector3(.28,.22,.38),1.4],
		[Vector3(19.1,0,-14.0),Vector3(.88,.66,1.1),.4], [Vector3(19.75,0,-12.95),Vector3(.50,.33,.70),-1.2], [Vector3(18.2,0,-14.8),Vector3(.43,.32,.56),.8],
		[Vector3(17.9,0,-18.6),Vector3(1.25,.64,1.00),-.25], [Vector3(19.0,0,-18.9),Vector3(.75,.42,.88),.5], [Vector3(17.35,0,-18.0),Vector3(.54,.35,.73),-.8],
	]
	for index in range(9):
		var expected := _grounded_transform(reference, expected_rock_a.get_faces(), placements[index])
		var actual := game.get_node("CoastClusterRock%02d" % index) as StaticBody3D
		_check(actual.get_child_count() == 2 and actual.transform == expected, "satellite transform/cardinality " + str(index))
		_check_mesh(_only_mesh(actual), expected_rock_a, "satellite " + str(index))
		var collision := _only_shape(actual).shape as ConvexPolygonShape3D
		_check(collision != null and _bytes(collision.points) == _bytes(expected_rock_a.get_faces()), "satellite collider " + str(index))
	additions.validate(game, reference, observer)
	_check_mesh(game.get_node("ShelteredGrassGroups"), _grass_mesh(reference), "sheltered grass")
	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(96):
		reference.call("_triangle", cap, Vector3(0,-1.60,0), reference.call("terrain_vertex", index, 30), reference.call("terrain_vertex", (index+1)%96, 30), Vector3.DOWN)
	_check_mesh(game.get_node("IslandLandmass/SubmergedVisualCap"), cap.commit(), "submerged cap")
	_validate_ground_labels()

func _validate_ground_labels() -> void:
	for path in LABEL_BASES:
		var target := game.get_node_or_null(path) as Node3D
		if target == null:
			_check(path in ["TidalShellsNear", "TidalShellsCove"] and (game.get("collected_ids") as Array).has(path), "only confirmed collected ground labels may be absent")
			continue
		var pivot := target.get_node_or_null(PIVOT) as Node3D
		var label := target.get_node_or_null("Name") as Label3D
		_check(pivot != null and label != null, "grounded node requires existing direct Name and one pivot: " + path)
		if pivot != null and label != null:
			_check(label.position.is_equal_approx(Vector3(0, float(LABEL_BASES[path]) + pivot.position.y, 0)), "shore Name must keep exact old XZ and neutral height plus the same visual offset: " + path)

func geometry(rows: Array) -> Array:
	validate_geometry()
	var old_moonback: Dictionary = moonback_contract.legacy_geometry(observer)
	var result: Array = []
	var new_count := 0
	var landing_count := 0
	var pivots := 0
	var paths := {}
	var path_counts := {}
	for source in rows:
		var path := str(source.path)
		if landing_contract.allowed.has(path):
			landing_count += 1
			continue
		if additions.allowed.has(path):
			new_count += 1
			continue
		if not _new_root(path).is_empty():
			new_count += 1
			continue
		if _is_pivot(path):
			_check(source.class == "Node3D" and source.transform[0] == [[100000,0,0],[0,100000,0],[0,0,100000]] and source.transform[1][0] == 0 and source.transform[1][2] == 0, "pivot may only add localY, never hidden geometry/XZ/rotation")
			pivots += 1
			continue
		var row: Dictionary = source.duplicate(true)
		row.path = historical_path(path)
		_check(not paths.has(row.path) or (BASELINE_DUPLICATE_PATHS.has(row.path) and path == row.path and paths[row.path] == path), "historical projection cannot alias distinct actual stable paths or introduce a new duplicate")
		paths[row.path] = path
		path_counts[row.path] = int(path_counts.get(row.path, 0)) + 1
		if row.path == "IslandLandmass/Shoreline":
			row.surfaces = old_rows[row.path].surfaces.duplicate(true)
		elif row.path == "IslandLandmass/ShorelineCollision":
			row.shape.data = old_rows[row.path].shape.data
		elif row.path == "MoonbackIsland/Grassland":
			row.surfaces = [old_moonback.surface.duplicate(true)]
		elif row.path == "MoonbackIsland/GrasslandCollision":
			row.shape.data = old_moonback.data
		elif row.path == "MoonbackTideStation":
			row.transform = [[[100000,0,0],[0,100000,0],[0,0,100000]],[-2800000,20000,2300000]]
		elif row.path in ["MoonbackDriftwood","MoonbackTidalShells"]:
			var old_position := [-2000000,22000,1800000] if row.path == "MoonbackDriftwood" else [-3100000,12000,2700000]
			row.transform = [[[100000,0,0],[0,100000,0],[0,0,100000]],old_position]
		elif row.path == "IslandLandmass/Grassland":
			_check(not row.visible, "legacy grass is intentionally hidden")
			row.visible = true
		elif row.path == "IslandLandmass/GrasslandCollision":
			_check(row.disabled, "legacy grass collider is intentionally disabled")
			row.disabled = false
		elif row.path in ["ShoreRockA", "ShoreRockB"]:
			row.transform[1][1] = old_rows[row.path].transform[1][1]
		elif row.path in ["ShoreRockA/MeshInstance3D#0", "ShoreRockB/MeshInstance3D#0"]:
			row.mesh_class = old_rows[row.path].mesh_class
			row.surfaces = old_rows[row.path].surfaces.duplicate(true)
		elif row.path in ["ShoreRockA/CollisionShape3D#0", "ShoreRockB/CollisionShape3D#0"]:
			row.shape.class = old_rows[row.path].shape.class
			row.shape.erase("points")
			row.shape.size = old_rows[row.path].shape.size.duplicate(true)
		elif row.path == "ArkInteractionFocusRing":
			var actual := game.get_node(row.path) as MeshInstance3D
			_check(actual.position.x == 13.0 and actual.position.z == -6.0 and is_equal_approx(actual.position.y, expected_focus_y), "actual historical focus target must keep XZ and use independent frozen terrain height plus0.022")
			row.transform[1][1] = old_focus_row.transform[1][1]
			_check(_focus_fixture_value(row) == _focus_fixture_value(old_focus_row), "only historical focus-ring Y may differ; XZ/basis/visibility/mesh/shadow/layers stay exactly observed")
		elif row.path.get_file() == "Name" and LABEL_BASES.has(row.path.get_base_dir()):
			row.transform[1][1] = roundi(float(LABEL_BASES[row.path.get_base_dir()])*100000.)
		result.append(row)
	for path in BASELINE_DUPLICATE_PATHS:
		_check(int(path_counts.get(path, 0)) == BASELINE_DUPLICATE_PATHS[path], "existing internal TextureRect stable-path multiplicity must remain exactly two: " + path)
	_check(new_count == 65, "exactly29 original and36 independently validated V2 coast nodes; never broad subtree filtering")
	_check(landing_count == LandingContract.EXPECTED_NODES,"exactly48 separately fingerprinted Moonback landing/nature nodes")
	_check(pivots == 8, "this historical earned-actions fixture has exactly8 surviving pivots including queued shell")
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.path < b.path)
	return result

func _build_expected_materials() -> void:
	_check(FileAccess.get_sha256("res://shaders/ark_coast_textured.gdshader") == COAST_SHADER_SHA, "actual coast shader must match frozen verified bytes")
	var terrain := ShaderMaterial.new()
	terrain.shader = load("res://shaders/ark_coast_textured.gdshader")
	for pair in [["grass","sparse_grass"], ["sand","sand_03"], ["rock","rock_boulder_dry"]]:
		for role in [["diff","diff"], ["normal","nor_gl"], ["rough","rough"]]:
			terrain.set_shader_parameter(pair[0] + "_" + role[0], load("res://art/coast/%s/%s_%s_1k.jpg" % [pair[1], pair[1], role[1]]))
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(.73,.75,.72)
	rock.albedo_texture = load("res://art/coast/rock_boulder_dry/rock_boulder_dry_diff_1k.jpg")
	rock.normal_enabled = true
	rock.normal_texture = load("res://art/coast/rock_boulder_dry/rock_boulder_dry_nor_gl_1k.jpg")
	rock.normal_scale = .38
	rock.roughness_texture = load("res://art/coast/rock_boulder_dry/rock_boulder_dry_rough_1k.jpg")
	rock.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	rock.roughness = 1.0
	rock.metallic_specular = .28
	rock.uv1_triplanar = true
	rock.uv1_triplanar_sharpness = 4.0
	rock.uv1_scale = Vector3.ONE / 1.8
	rock.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color("65704b")
	grass.vertex_color_use_as_albedo = true
	grass.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass.roughness = 1.0
	expected_materials = {"terrain": terrain, "rock": rock, "grass": grass}

func _old_material(color: Color, roughness: float) -> Dictionary:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return _resource(material)

func materials(rows: Array, named_rows: bool = false) -> Array:
	if additions.meshes.is_empty(): validate_geometry()
	var result: Array = []
	var removed := 0
	var landing_removed := 0
	for source in rows:
		var path := str(source.get("_history_path", source.get("path", "")))
		var root := _new_root(path)
		if landing_contract.meshes.has(path):
			landing_removed += 1
			continue
		if additions.meshes.has(path):
			removed += 1
			continue
		if not root.is_empty():
			var key := "grass" if root == "ShelteredGrassGroups" else "terrain" if root == "IslandLandmass/SubmergedVisualCap" else "rock"
			_check(source.override == _resource(expected_materials[key]) and source.surfaces == [_resource(expected_materials[key])], "new coast material must exactly match independent specification: " + path)
			removed += 1
			continue
		var row: Dictionary = source.duplicate(true)
		if path == "IslandLandmass/Shoreline":
			_check((game.get_node(path).material_override as ShaderMaterial).shader.code.sha256_text() == COAST_SHADER_SHA, "runtime coast shader code must remain frozen")
			_check(row.override == _resource(expected_materials.terrain) and row.surfaces == [_resource(expected_materials.terrain)], "complete opening terrain material contract")
			row.override = _old_material(Color("77735b"), 1.0)
			row.surfaces = [row.override.duplicate(true)]
		elif path in ["ShoreRockA/MeshInstance3D#0", "ShoreRockB/MeshInstance3D#0"]:
			_check(row.override == _resource(expected_materials.rock) and row.surfaces == [_resource(expected_materials.rock)], "complete main-rock material contract")
			row.override = _old_material(Color("686c68"), .84)
			row.surfaces = [row.override.duplicate(true)]
		elif path == "Sea":
			row.override = _sea_material(row.override)
			for index in range(row.surfaces.size()):
				row.surfaces[index] = _sea_material(row.surfaces[index])
		elif path in ["MoonbackIsland/Grassland","MoonbackIsland/Shoreline"]:
			var actual_material := game.get_node(path).material_override as ShaderMaterial
			_check(actual_material != null and actual_material.shader != null and actual_material.shader.code.sha256_text() == MoonbackContract.SHADER_SHA,"approved Moonback runtime shader bytes before historical projection")
			var expected := _resource(moonback_contract.material_spec())
			_check(row.override == expected and row.surfaces == [expected],"complete independently specified Moonback material before narrow old projection: "+path)
			row.override = _old_material(Color("4e615a") if path.ends_with("Grassland") else Color("87928a"),1.0)
			row.surfaces = [row.override.duplicate(true)]
		if named_rows:
			row.erase("_history_path")
		else:
			row.path = historical_path(path)
		result.append(row)
	_check(removed == 24, "exactly11 original plus13 independently checked camp materials, not broad material exclusions")
	_check(landing_removed == LandingContract.EXPECTED_MATERIAL_ROWS,"exactly21 separately fingerprinted Moonback MeshInstance material rows; five MultiMeshes are checked by the root contract")
	if not named_rows:
		result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.path < b.path)
	return result

func _sea_material(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	_check(result.shader.code_sha256 == WATER_SHA, "actual water shader must match frozen verified bytes")
	var actual := game.get_node("Sea").material_override as ShaderMaterial
	var raster := actual.get_shader_parameter("opening_heights") as Texture2D
	_check(raster != null, "actual water must bind the terrain raster")
	if raster == null:
		return result
	var image: Image = raster.get_image()
	_check(image != null and image.get_size() == Vector2i(384,384) and image.get_format() == Image.FORMAT_RF, "actual height raster must be384 RF, not ellipse or absent texture")
	if expected_heights.is_empty():
		validate_geometry()
	_check(image != null and image.get_data() == expected_heights, "water raster must exactly match frozen approved final triangles in this runtime")
	for row in [["depth_tint",Color(.042,.19,.235,1)], ["shallow_tint",Color(.12,.265,.265,1)], ["foam_tint",Color(.62,.67,.61,1)], ["ripple_probe",false]]:
		var value: Variant = actual.get_shader_parameter(row[0])
		_check(value == null or value == row[1], "new presentation uniform may use only frozen default: " + row[0])
	for uniform_name in NEW_UNIFORMS:
		result.erase("shader_parameter/" + uniform_name)
	result.shader.code_sha256 = OLD_WATER_SHA
	return result

func validate_lighting() -> void:
	var period: int = game.get("day_period")
	var weather: int = game.get("weather_phase")
	var old_energy: float = [0.82,1.35,0.62,0.20][period] * [0.76,0.18,0.82][weather]
	var sun := game.get("sun_light") as DirectionalLight3D
	_check(is_equal_approx(sun.light_energy, old_energy*SUN_SCALE), "actual Sun energy must be independently calibrated without cumulative scaling")
	_check(sun.shadow_enabled and is_equal_approx(sun.shadow_opacity,.62) and is_equal_approx(sun.shadow_bias,.04) and is_equal_approx(sun.shadow_normal_bias,.8) and is_equal_approx(sun.directional_shadow_max_distance,45.), "actual Sun shadow scope must match frozen settings")
	_check(game.find_children("*", "DirectionalLight3D", true, false).size() == 1, "only the existing single Sun is permitted")

func lighting(observation: Dictionary) -> Dictionary:
	# Pure projection: preserve deviations so synthetic mutation calibration still
	# rejects changed energy/shadow and extra lights instead of masking them.
	var result := observation.duplicate(true)
	var period: int = game.get("day_period")
	var weather: int = game.get("weather_phase")
	var old_energy: float = [0.82,1.35,0.62,0.20][period] * [0.76,0.18,0.82][weather]
	var installed := snappedf(old_energy*SUN_SCALE,.000001)
	result.sun.energy = snappedf(old_energy + (float(result.sun.energy)-installed)/SUN_SCALE,.000001)
	result.sun.shadow = not result.sun.shadow
	for light in result.lights:
		if light.class == "DirectionalLight3D":
			light.energy = snappedf(old_energy + (float(light.energy)-installed)/SUN_SCALE,.000001)
			light.shadow = not light.shadow
	return result

func node_path(node: Node) -> String:
	var segments: Array[String] = []
	while node != game:
		var segment := str(node.name)
		if segment.begins_with("@"):
			var ordinal := 0
			for sibling in node.get_parent().get_children():
				if sibling == node:
					break
				if str(sibling.name).begins_with("@") and sibling.get_class() == node.get_class():
					ordinal += 1
			segment = node.get_class() + "#%d" % ordinal
		segments.push_front(segment)
		node = node.get_parent()
	return "/".join(segments)

func _grounded_transform(reference: RefCounted, faces: PackedVector3Array, placement: Array, embed_depth: float = .08) -> Transform3D:
	var probe := Node3D.new()
	probe.position = placement[0]
	probe.scale = placement[1]
	probe.rotation.y = placement[2]
	var transform := probe.transform
	probe.free()
	var low := INF
	var points := PackedVector3Array()
	for vertex in faces:
		var point := transform * vertex
		low = minf(low, point.y)
		points.append(point)
	var gap := INF
	for point in points:
		if point.y <= low + .035:
			var height: Variant = reference.call("sample_height", point)
			if height != null:
				gap = minf(gap, point.y - float(height))
	_check(is_finite(gap), "frozen rock position requires actual terrain support")
	transform.origin.y -= gap + embed_depth
	return transform

func _grass_mesh(reference: RefCounted) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centers := [Vector3(4.8,.51,-8.5),Vector3(18.7,.64,-14.9),Vector3(16.8,.76,-19.2),Vector3(18.7,.72,-19.9),Vector3(14.4,.58,-19.0)]
	for ci in range(centers.size()):
		var center: Vector3 = centers[ci]
		for tuft in range(11):
			var angle := float(tuft)*2.39996 + float(ci)*.7
			var spread := .22 + .15*sqrt(float(tuft))
			var p := Vector3(center.x+cos(angle)*spread,0,center.z+sin(angle)*spread*.7)
			var h: Variant = reference.call("sample_height", p)
			if h == null:
				continue
			p.y = float(h)-.02
			for leaf in range(8):
				var a := angle+leaf*2.39996
				var across := Vector3(cos(a),0,sin(a))
				var width := Vector3(-across.z,0,across.x)*(.028+.009*(leaf%3))
				var height := center.y*(.70+.05*leaf)
				var base := p+across*.045
				var middle := base+Vector3.UP*height*.59+across*.14
				var tip := base+Vector3.UP*height+across*.32+Vector3(.02,0,-.08)
				for tri in [[base-width,base+width,middle+width*.65],[base-width,middle+width*.65,middle-width*.65],[middle-width*.65,middle+width*.65,tip]]:
					var normal: Vector3 = (tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
					for v in tri:
						st.set_normal(normal)
						st.set_color(Color(.72+.025*leaf,.74+.025*leaf,.64+.022*leaf))
						st.set_uv(Vector2.ZERO)
						st.add_vertex(v)
	return st.commit()
