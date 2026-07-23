extends SceneTree

const Catalog = preload("res://scripts/combat_visual_catalog.gd")
const OUTPUT_PATH := "res://../.tmp/combat_visual_roster_preview.png"
const DIGITS := {
	"0":["111","101","101","101","111"], "1":["010","110","010","010","111"],
	"2":["111","001","111","100","111"], "3":["111","001","111","001","111"],
	"4":["101","101","111","001","001"], "5":["111","100","111","001","111"],
	"6":["111","100","111","101","111"], "7":["111","001","010","010","010"],
	"8":["111","101","111","101","111"], "9":["111","101","111","001","111"],
}


func _init() -> void:
	var image := Image.create(1920, 1240, false, Image.FORMAT_RGBA8)
	image.fill(Color("081012"))
	_draw_enemy_roster(image)
	_draw_path_roster(image)
	_draw_jade_roster(image)
	var output := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var error := image.save_png(output)
	if error == OK:
		print("COMBAT_VISUAL_ROSTER_PREVIEW_OK: %s" % output)
		quit(0)
	else:
		push_error("COMBAT_VISUAL_ROSTER_PREVIEW_FAILED: %s" % error_string(error))
		quit(1)


func _draw_enemy_roster(image: Image) -> void:
	for index in range(Catalog.enemy_ids().size()):
		var enemy_id: String = Catalog.enemy_ids()[index]
		var profile: Dictionary = Catalog.enemy_profile(enemy_id)
		var column := index % 6
		var row := index / 6
		var tile := Rect2i(16 + column * 316, 16 + row * 194, 304, 182)
		_draw_panel(image, tile, Color("172126"), Color("53636a"))
		_draw_number(image, tile.position + Vector2i(10, 9), index + 1, Color("e2c576"), 2)
		_draw_enemy(image, profile, tile.position + Vector2i(72, 151), false)
		_draw_enemy(image, profile, tile.position + Vector2i(177, 151), true)
		var weapon_id := str(profile.get("weapon_profile_id", ""))
		var weapon := Catalog.enemy_weapon_profile(weapon_id)
		_draw_cells(image, tile.position + Vector2i(278, 82), 2, weapon.get("cells", []), Color("11181a"), true)
		_draw_cells(image, tile.position + Vector2i(278, 82), 2, weapon.get("cells", []),
			Color(str((profile.get("palette", ["#222","#555","#999","#ddb977"]) as Array)[3])))
		var signature := Catalog.signature_vfx_profile(str(profile.get("vfx_profile_id", "")))
		var signature_palette: Array = signature.get("palette", ["#b47571", "#e4c483"])
		_draw_signature(image, tile.position + Vector2i(272, 174), str(signature.get("shape", "shards")),
			Color(str(signature_palette[0])), Color(str(signature_palette[1])))
		# Four swatches identify palette authorship without requiring a font renderer.
		var palette: Array = profile.get("palette", [])
		for palette_index in range(palette.size()):
			image.fill_rect(Rect2i(tile.position + Vector2i(48 + palette_index * 18, 11), Vector2i(14, 8)),
				Color(str(palette[palette_index])))


func _draw_enemy(image: Image, profile: Dictionary, root: Vector2i, attack: bool) -> void:
	var palette: Array = profile.get("palette", ["#171a1e", "#3d4549", "#7d8c8d", "#d6bd7b"])
	var anatomy := Catalog.enemy_anatomy(str(profile.get("enemy_id", "")))
	var order := ["back_arm", "legs", "garment", "torso", "head", "front_arm", "ornament"]
	var colors := {"back_arm":1,"legs":1,"garment":1,"torso":2,"head":2,"front_arm":2,"ornament":3}
	for part_id in order:
		var offset := _enemy_offset(anatomy, str(part_id), attack)
		_draw_cells(image, root + offset * 2, 2, anatomy.get(part_id, []), Color(str(palette[0])), true)
		_draw_cells(image, root + offset * 2, 2, anatomy.get(part_id, []), Color(str(palette[int(colors[part_id])])) )
	var weapon := Catalog.enemy_weapon_profile(str(profile.get("weapon_profile_id", "")))
	var weapon_offset := _enemy_offset(anatomy, "weapon", attack) + (Vector2i(-4,0) if attack else Vector2i.ZERO)
	_draw_cells(image, root + weapon_offset * 2, 2, weapon.get("cells", []), Color("0c1113"), true)
	_draw_cells(image, root + weapon_offset * 2, 2, weapon.get("cells", []), Color(str(palette[3])))


func _enemy_offset(anatomy: Dictionary, part_id: String, attack: bool) -> Vector2i:
	if not attack:
		return Vector2i.ZERO
	var offsets: Dictionary = anatomy.get("attack_offsets", {})
	var value: Variant = offsets.get(part_id, [0,0])
	return Vector2i(int(value[0]), int(value[1])) if value is Array else Vector2i.ZERO


func _draw_path_roster(image: Image) -> void:
	var y := 608
	for index in range(Catalog.path_ids().size()):
		var path_id: String = Catalog.path_ids()[index]
		var profile := Catalog.path_profile(path_id)
		var tile := Rect2i(16 + index * 316, y, 304, 176)
		_draw_panel(image, tile, Color("142025"), Color("5f7478"))
		_draw_number(image, tile.position + Vector2i(10, 9), index + 1, Color("8fd0cb"), 2)
		_draw_player(image, tile.position + Vector2i(146, 149), profile, {}, "idle")


func _draw_jade_roster(image: Image) -> void:
	var y := 804
	for index in range(Catalog.jade_weapon_ids().size()):
		var weapon_id: String = Catalog.jade_weapon_ids()[index]
		var jade := Catalog.jade_weapon_profile(weapon_id)
		var column := index % 8
		var row := index / 8
		var tile := Rect2i(16 + column * 237, y + row * 208, 225, 194)
		_draw_panel(image, tile, Color("181f22"), Color("706a55"))
		_draw_number(image, tile.position + Vector2i(9, 8), index + 1, Color("e4c56f"), 2)
		_draw_player(image, tile.position + Vector2i(40, 161), Catalog.path_profile("insight"), jade, "idle")
		_draw_player(image, tile.position + Vector2i(92, 161), Catalog.path_profile("insight"), jade, "charge")
		_draw_player(image, tile.position + Vector2i(144, 161), Catalog.path_profile("insight"), jade, "attack")
		_draw_player(image, tile.position + Vector2i(196, 161), Catalog.path_profile("insight"), jade, "guard")
		var palette: Array = jade.get("palette", ["#c9bd83", "#fff3bd"])
		_draw_cells(image, tile.position + Vector2i(171, 148), 3, jade.get("cells", []), Color("101719"), true)
		_draw_cells(image, tile.position + Vector2i(171, 148), 3, jade.get("cells", []), Color(str(palette[0])))


func _draw_player(image: Image, root: Vector2i, path: Dictionary, jade: Dictionary, pose: String) -> void:
	var palette: Array = path.get("palette", ["#203238", "#466d73", "#9ab9ae", "#e2c578"])
	_draw_cells(image, root, 2, path.get("backpiece", []), Color("10181a"), true)
	_draw_cells(image, root, 2, path.get("backpiece", []), Color(str(palette[0])))
	_draw_cells(image, root, 2, [[-6,-8,5,10],[2,-8,5,10]], Color("10181a"), true)
	_draw_cells(image, root, 2, [[-6,-8,5,10],[2,-8,5,10]], Color(str(palette[0])))
	_draw_cells(image, root, 2, path.get("mantle", []), Color(str(palette[1])))
	_draw_cells(image, root, 2, path.get("garment", []), Color("10181a"), true)
	_draw_cells(image, root, 2, path.get("garment", []), Color(str(palette[1])))
	_draw_cells(image, root, 2, [[-4,-31,9,9],[-5,-34,11,4]], Color("10181a"), true)
	_draw_cells(image, root, 2, [[-4,-31,9,9],[-5,-34,11,4]], Color(str(palette[2])))
	_draw_cells(image, root, 2, path.get("headgear", []), Color(str(palette[3])))
	_draw_cells(image, root, 2, path.get("sigil", []), Color(str(palette[3])))
	if not jade.is_empty():
		var jade_palette: Array = jade.get("palette", ["#c9bd83", "#fff3bd"])
		var offset := Vector2i.ZERO
		if pose == "charge": offset = Vector2i(-2,-8)
		elif pose == "attack": offset = Vector2i(9,3)
		elif pose == "guard": offset = Vector2i(-5,-4)
		if pose == "attack":
			for echo in range(1,3):
				_draw_cells(image, root + offset * 2 - Vector2i(echo * 5, echo) * 2, 2,
					jade.get("cells", []), Color(str(jade_palette[0]), 0.28))
		_draw_cells(image, root + offset * 2, 2, jade.get("mark", []), Color(str(jade_palette[1])))
		_draw_cells(image, root + offset * 2, 2, jade.get("cells", []), Color("101719"), true)
		_draw_cells(image, root + offset * 2, 2, jade.get("cells", []), Color(str(jade_palette[0])))


func _draw_signature(image: Image, root: Vector2i, shape: String, primary: Color, secondary: Color) -> void:
	match shape:
		"droplets", "rain":
			for index in range(8):
				_line_cells(image, root, 2, Vector2i(-25 + index * 7, -43 + index % 3 * 3),
					Vector2i(-27 + index * 7, -9), primary)
			_line_cells(image, root, 2, Vector2i(-31, 5), Vector2i(31, 5), secondary)
		"shards", "refraction", "rollback":
			for index in range(10):
				var angle := float(index) * TAU / 10.0
				var point := Vector2i(roundi(cos(angle) * 25.0), roundi(-20 + sin(angle) * 18.0))
				_draw_cells(image, root, 2, [[point.x,point.y,2 + index % 2,4]], primary)
		"ink", "unbound":
			_line_cells(image, root, 2, Vector2i(-31,-39), Vector2i(31,-10), primary)
			_line_cells(image, root, 2, Vector2i(-25,-28), Vector2i(25,-4), secondary)
			for index in range(5):
				_draw_cells(image, root, 2, [[-24 + index * 11,-9 + index % 2 * 3,7,2]], primary)
		"vents", "receipt", "silence":
			for index in range(6):
				var y := -42 + index * 8
				_line_cells(image, root, 2, Vector2i(-28 + index * 2,y), Vector2i(28 - index * 2,y), primary)
				_draw_cells(image, root, 2, [[-3,y-2,7,4]], Color("081012"))
		"seal", "law":
			for inset in range(3):
				var left := -28 + inset * 6
				var top := -40 + inset * 6
				var width := 56 - inset * 12
				_line_cells(image, root, 2, Vector2i(left,top), Vector2i(left+width,top), primary)
				_line_cells(image, root, 2, Vector2i(left,top), Vector2i(left,top+35-inset*10), primary)
		"furnace", "eclipse":
			for index in range(4):
				_line_cells(image, root, 2, Vector2i(-22+index*7,-6), Vector2i(-15+index*10,-39-index*2), primary)
			_draw_cells(image, root, 2, [[-9,-28,18,10],[-4,-34,8,6]], secondary)
		"scan", "meridian":
			for index in range(6):
				var y := -42 + index * 8
				_line_cells(image, root, 2, Vector2i(-30,y), Vector2i(30,y+index%2*3), primary)
		"plunder":
			for index in range(6):
				_line_cells(image, root, 2, Vector2i(30,-40+index*7), Vector2i(-5,-30+index*4), primary)
				_draw_cells(image, root, 2, [[-24+index*5,-27+index%3*6,5,3]], secondary)
		_:
			_line_cells(image, root, 2, Vector2i(-25,-35), Vector2i(25,-10), primary)


func _line_cells(image: Image, root: Vector2i, scale_value: int, from_cell: Vector2i,
		to_cell: Vector2i, color: Color) -> void:
	var x := from_cell.x
	var y := from_cell.y
	var dx := absi(to_cell.x - from_cell.x)
	var sx := 1 if from_cell.x < to_cell.x else -1
	var dy := -absi(to_cell.y - from_cell.y)
	var sy := 1 if from_cell.y < to_cell.y else -1
	var error := dx + dy
	while true:
		_draw_cells(image, root, scale_value, [[x,y,1,1]], color)
		if x == to_cell.x and y == to_cell.y:
			break
		var doubled := error * 2
		if doubled >= dy:
			error += dy
			x += sx
		if doubled <= dx:
			error += dx
			y += sy


func _draw_cells(image: Image, root: Vector2i, scale_value: int, cells_value: Variant,
		color: Color, outline: bool = false) -> void:
	if not cells_value is Array:
		return
	for value in cells_value:
		if not value is Array or (value as Array).size() < 4:
			continue
		var cell: Array = value
		var position := root + Vector2i(int(cell[0]), int(cell[1])) * scale_value
		var dimensions := Vector2i(maxi(1, int(cell[2])) * scale_value,
			maxi(1, int(cell[3])) * scale_value)
		if outline:
			image.fill_rect(Rect2i(position - Vector2i.ONE * scale_value,
				dimensions + Vector2i.ONE * scale_value * 2), color)
		else:
			image.fill_rect(Rect2i(position, dimensions), color)


func _draw_panel(image: Image, rect: Rect2i, fill: Color, border: Color) -> void:
	image.fill_rect(rect, border)
	image.fill_rect(Rect2i(rect.position + Vector2i.ONE * 2, rect.size - Vector2i.ONE * 4), fill)


func _draw_number(image: Image, position: Vector2i, value: int, color: Color, scale_value: int) -> void:
	var text := "%02d" % value
	for character_index in range(text.length()):
		var rows: Array = DIGITS.get(text[character_index], [])
		for row in range(rows.size()):
			var bits := str(rows[row])
			for column in range(bits.length()):
				if bits[column] == "1":
					image.fill_rect(Rect2i(position + Vector2i(character_index * 5 + column, row) * scale_value,
						Vector2i.ONE * scale_value), color)
