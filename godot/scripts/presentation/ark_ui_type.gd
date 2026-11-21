extends RefCounted
## Licensed Noto Sans SC variable faces. Explicit weights, no synthesized bold.
const FACE = preload("res://art/fonts/NotoSansSC-Variable.ttf")
static var _faces: Dictionary = {}
static func face(weight: int = 400) -> FontVariation:
	if not _faces.has(weight):
		var font := FontVariation.new()
		font.base_font = FACE
		font.variation_opentype = {2003265652: float(weight)}
		_faces[weight] = font
	return _faces[weight]
