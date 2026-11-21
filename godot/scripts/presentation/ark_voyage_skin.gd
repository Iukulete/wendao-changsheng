extends RefCounted
## Presentation-only shared nautical frame. No game state or input ownership.
const FRAME = preload("res://art/ui_icons/voyage_panel.svg")
const TEXT := Color("e5dfcb")
const MUTED := Color("acb1a3")
const ACCENT := Color("c2af7d")
static func panel(padding: float = 14.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = FRAME
	style.set_texture_margin_all(10.0)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style
static func key(hover: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("39453c") if hover else Color("28332d")
	style.border_color = Color("a59a78") if hover else Color("4b5549")
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

static func track() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("15221e")
	style.border_color = Color("455047")
	style.border_width_bottom = 1
	style.content_margin_left = 0
	style.content_margin_right = 0
	return style
static func progress(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.15)
	style.border_width_top = 2
	return style
