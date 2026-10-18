extends SceneTree

const CONCEPTS := [
	"res://art/characters/hd2d_protagonist.svg",
	"res://art/characters/hd2d_tidekeeper.svg",
]
const OUTPUT := "res://art/concepts/hd2d_character_prototype_preview.png"


func _initialize() -> void:
	var preview := Image.create(672, 432, false, Image.FORMAT_RGBA8)
	preview.fill(Color("25343c"))
	preview.fill_rect(Rect2i(12, 12, 312, 408), Color("34464a"))
	preview.fill_rect(Rect2i(348, 12, 312, 408), Color("34464a"))
	for index in range(CONCEPTS.size()):
		var source := Image.new()
		var error := source.load_svg_from_string(FileAccess.get_file_as_string(CONCEPTS[index]), 1.0)
		if error != OK:
			push_error("Could not rasterize character concept %s: %s" % [CONCEPTS[index], error])
			quit(1)
			return
		source.resize(288, 384, Image.INTERPOLATE_NEAREST)
		preview.blend_rect(source, Rect2i(0, 0, source.get_width(), source.get_height()), Vector2i(24 + index * 336, 24))
	var save_error := preview.save_png(ProjectSettings.globalize_path(OUTPUT))
	if save_error != OK:
		push_error("Could not write character preview: %s" % save_error)
		quit(1)
		return
	print("HD2D_CHARACTER_PREVIEW_OK ", ProjectSettings.globalize_path(OUTPUT))
	quit()
