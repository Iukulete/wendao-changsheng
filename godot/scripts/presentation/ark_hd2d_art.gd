extends RefCounted
## Original source sets retained side-by-side. Selection changes presentation only.
const ORIGINAL := {
	"cabin_boards.png": preload("res://art/hd2d/cabin_boards.png"),
	"dock_planks.png": preload("res://art/hd2d/dock_planks.png"),
	"grass_pixel.png": preload("res://art/hd2d/grass_pixel.png"),
	"protagonist_atlas.png": preload("res://art/hd2d/protagonist_atlas.png"),
	"protagonist_helm.png": preload("res://art/hd2d/protagonist_helm.png"),
	"protagonist_sit.png": preload("res://art/hd2d/protagonist_sit.png"),
	"protagonist_swim.png": preload("res://art/hd2d/protagonist_swim.png"),
	"protagonist_swim_idle.png": preload("res://art/hd2d/protagonist_swim_idle.png"),
	"protagonist_work.png": preload("res://art/hd2d/protagonist_work.png"),
	"resident_atlas.png": preload("res://art/hd2d/resident_atlas.png"),
	"resident_moss_variant.png": preload("res://art/hd2d/resident_moss_variant.png"),
	"resident_sit.png": preload("res://art/hd2d/resident_sit.png"),
	"resident_work.png": preload("res://art/hd2d/resident_work.png"),
	"rock_pixel.png": preload("res://art/hd2d/rock_pixel.png"),
	"roof_shingles.png": preload("res://art/hd2d/roof_shingles.png"),
	"sand_pixel.png": preload("res://art/hd2d/sand_pixel.png"),
	"stone_blocks.png": preload("res://art/hd2d/stone_blocks.png")}
const REFINED := {
	"cabin_boards.png": preload("res://art/hd2d_refined/cabin_boards.png"),
	"cabin_window_warm.png": preload("res://art/hd2d_refined/cabin_window_warm.png"),
	"dock_planks.png": preload("res://art/hd2d_refined/dock_planks.png"),
	"grass_pixel.png": preload("res://art/hd2d_refined/grass_pixel.png"),
	"protagonist_atlas.png": preload("res://art/hd2d_refined/protagonist_atlas.png"),
	"protagonist_helm.png": preload("res://art/hd2d_refined/protagonist_helm.png"),
	"protagonist_sit.png": preload("res://art/hd2d_refined/protagonist_sit.png"),
	"protagonist_swim.png": preload("res://art/hd2d_refined/protagonist_swim.png"),
	"protagonist_swim_idle.png": preload("res://art/hd2d_refined/protagonist_swim_idle.png"),
	"protagonist_work.png": preload("res://art/hd2d_refined/protagonist_work.png"),
	"resident_atlas.png": preload("res://art/hd2d_refined/resident_atlas.png"),
	"resident_moss_variant.png": preload("res://art/hd2d_refined/resident_moss_variant.png"),
	"resident_sit.png": preload("res://art/hd2d_refined/resident_sit.png"),
	"resident_work.png": preload("res://art/hd2d_refined/resident_work.png"),
	"rock_pixel.png": preload("res://art/hd2d_refined/rock_pixel.png"),
	"roof_shingles.png": preload("res://art/hd2d_refined/roof_shingles.png"),
	"sand_pixel.png": preload("res://art/hd2d_refined/sand_pixel.png"),
	"stone_blocks.png": preload("res://art/hd2d_refined/stone_blocks.png")}

const FURNITURE := {
	"bedroll_top_96x68.png": preload("res://art/hd2d_furniture_detail/bedroll_top_96x68.png"),
	"workbench_top_112x78.png": preload("res://art/hd2d_furniture_detail/workbench_top_112x78.png")}

const NPC64 := {
	"keeper_atlas.png": preload("res://art/hd2d_npc64/keeper_atlas.png"),
	"keeper_idle.png": preload("res://art/hd2d_npc64/keeper_idle.png"),
	"keeper_sit.png": preload("res://art/hd2d_npc64/keeper_sit.png"),
	"keeper_work.png": preload("res://art/hd2d_npc64/keeper_work.png"),
	"sailmaker_atlas.png": preload("res://art/hd2d_npc64/sailmaker_atlas.png"),
	"sailmaker_idle.png": preload("res://art/hd2d_npc64/sailmaker_idle.png"),
	"sailmaker_sit.png": preload("res://art/hd2d_npc64/sailmaker_sit.png"),
	"sailmaker_work.png": preload("res://art/hd2d_npc64/sailmaker_work.png"),
	"tidekeeper_atlas.png": preload("res://art/hd2d_npc64/tidekeeper_atlas.png"),
	"tidekeeper_idle.png": preload("res://art/hd2d_npc64/tidekeeper_idle.png"),
	"tidekeeper_sit.png": preload("res://art/hd2d_npc64/tidekeeper_sit.png"),
	"tidekeeper_work.png": preload("res://art/hd2d_npc64/tidekeeper_work.png")}

const DETAIL_MATERIALS := {
	"canvas_seagreen.png": preload("res://art/hd2d_material_detail/canvas_seagreen.png"),
	"canvas_seagreen_repaired.png": preload("res://art/hd2d_material_detail/canvas_seagreen_repaired.png"),
	"canvas_undyed.png": preload("res://art/hd2d_material_detail/canvas_undyed.png")}

const DETAIL64 := {
	"protagonist_atlas.png": preload("res://art/hd2d_detail64/protagonist_atlas.png"),
	"protagonist_helm.png": preload("res://art/hd2d_detail64/protagonist_helm.png"),
	"protagonist_idle.png": preload("res://art/hd2d_detail64/protagonist_idle.png"),
	"protagonist_sit.png": preload("res://art/hd2d_detail64/protagonist_sit.png"),
	"protagonist_swim.png": preload("res://art/hd2d_detail64/protagonist_swim.png"),
	"protagonist_swim_idle.png": preload("res://art/hd2d_detail64/protagonist_swim_idle.png"),
	"protagonist_work.png": preload("res://art/hd2d_detail64/protagonist_work.png"),
	"resident_atlas.png": preload("res://art/hd2d_detail64/resident_atlas.png"),
	"resident_helm.png": preload("res://art/hd2d_detail64/resident_helm.png"),
	"resident_idle.png": preload("res://art/hd2d_detail64/resident_idle.png"),
	"resident_moss_atlas.png": preload("res://art/hd2d_detail64/resident_moss_atlas.png"),
	"resident_moss_helm.png": preload("res://art/hd2d_detail64/resident_moss_helm.png"),
	"resident_moss_idle.png": preload("res://art/hd2d_detail64/resident_moss_idle.png"),
	"resident_moss_sit.png": preload("res://art/hd2d_detail64/resident_moss_sit.png"),
	"resident_moss_swim.png": preload("res://art/hd2d_detail64/resident_moss_swim.png"),
	"resident_moss_swim_idle.png": preload("res://art/hd2d_detail64/resident_moss_swim_idle.png"),
	"resident_moss_work.png": preload("res://art/hd2d_detail64/resident_moss_work.png"),
	"resident_sit.png": preload("res://art/hd2d_detail64/resident_sit.png"),
	"resident_swim.png": preload("res://art/hd2d_detail64/resident_swim.png"),
	"resident_swim_idle.png": preload("res://art/hd2d_detail64/resident_swim_idle.png"),
	"resident_work.png": preload("res://art/hd2d_detail64/resident_work.png")}

static func refined() -> bool:
	return OS.get_environment("ARK_HD2D_ART") != "original"

static func detailed() -> bool:
	return OS.get_environment("ARK_HD2D_ART") not in ["original", "refined"]

static func identities() -> bool:
	return OS.get_environment("ARK_HD2D_ART") not in ["original", "refined", "detail64"]

static func selection() -> String:
	return "identity64" if identities() else "detail64" if detailed() else "refined" if refined() else "original"

static func texture(name_: String) -> Texture2D:
	if identities() and FURNITURE.has(name_): return FURNITURE[name_] as Texture2D
	if identities() and NPC64.has(name_): return NPC64[name_] as Texture2D
	if detailed() and DETAIL_MATERIALS.has(name_): return DETAIL_MATERIALS[name_] as Texture2D
	if detailed() and DETAIL64.has(name_): return DETAIL64[name_] as Texture2D
	return (REFINED if refined() else ORIGINAL).get(name_) as Texture2D
