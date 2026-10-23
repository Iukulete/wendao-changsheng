extends RefCounted

## A bounded surface candidate, not a replacement for the environment art.
## Exactly four opening-world meshes and the eight existing cabin floorboards.
## Terrain uses existing local XZ UVs; ship meshes keep local triplanar mapping.
## Both follow their mesh transforms without per-frame work.
const TERRAIN_DETAIL = preload("res://art/surface_sample/terrain_detail.png")
const WOOD_GRAIN = preload("res://art/surface_sample/wood_grain.png")
const DECK_PLANKS = preload("res://art/surface_sample/deck_planks.png")
const SHORE_SCALE := Vector3.ONE / 1.8
const GRASS_SCALE := Vector3.ONE / 2.8
# Four lanes in the tile match the existing cabin's 0.37 m board pitch.
# Grain follows local Z on horizontal faces, not the moving world's axes.
const WOOD_SCALE := Vector3(1.0 / 1.48, 1.0 / 1.48, 1.0 / 3.2)

var _materials: Dictionary = {}


func apply_world(world: Node3D) -> void:
	_apply(world.get_node_or_null("IslandLandmass/Shoreline") as MeshInstance3D, "shore", TERRAIN_DETAIL, SHORE_SCALE, false)
	_apply(world.get_node_or_null("IslandLandmass/Grassland") as MeshInstance3D, "grass", TERRAIN_DETAIL, GRASS_SCALE, false)
	_apply(_unique_mesh(world.get_node_or_null("ArkRoot/RaftTop")), "deck", DECK_PLANKS, WOOD_SCALE)
	_apply(_unique_mesh(world.get_node_or_null("ArkRoot/RaftBoardingGangplank")), "gangplank", DECK_PLANKS, WOOD_SCALE)


func apply_shelter(structure: Node3D) -> void:
	for index in range(8):
		var visual := structure.get_node_or_null("CabinFloorboards/FloorPlank%d" % index) as MeshInstance3D
		_apply(visual, "floor_%d" % index, WOOD_GRAIN, WOOD_SCALE)


func _unique_mesh(parent: Node) -> MeshInstance3D:
	if parent == null:
		push_error("Surface sample target is missing")
		return null
	var found: MeshInstance3D = null
	for child in parent.get_children():
		if child is MeshInstance3D:
			if found != null:
				push_error("Surface sample target must have exactly one direct mesh")
				return null
			found = child as MeshInstance3D
	return found


func _apply(visual: MeshInstance3D, key: String, texture: Texture2D, mapping_scale: Vector3, local_triplanar: bool = true) -> void:
	if visual == null or not visual.material_override is StandardMaterial3D:
		push_error("Surface sample expected an existing StandardMaterial3D at " + key)
		return
	if not _materials.has(key):
		# Duplicate, never mutate shared source material or generic _material().
		# All base shading/colour/culling properties remain exactly as authored.
		var material := visual.material_override.duplicate() as StandardMaterial3D
		material.albedo_texture = texture
		material.uv1_triplanar = local_triplanar
		material.uv1_world_triplanar = false
		material.uv1_scale = mapping_scale
		_materials[key] = material
	visual.material_override = _materials[key] as StandardMaterial3D
