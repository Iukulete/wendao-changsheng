extends Control
## Read-only scale: exact 90% reel-stop threshold and current line tension.
var value := 0.0
func _draw() -> void:
	for fraction in [0.3,0.6]:
		var x: float = floor(size.x*fraction)
		draw_line(Vector2(x,0),Vector2(x,size.y),Color(0.08,0.15,0.12,0.35),1.0)
	var stop_x: float = floor(size.x*0.9)
	draw_line(Vector2(stop_x,0),Vector2(stop_x,size.y),Color("d6bd7d"),2.0)
	var pointer_x := clampf(floor(size.x*value),1.0,size.x-2.0)
	draw_line(Vector2(pointer_x,0),Vector2(pointer_x,size.y),Color("eee4c8"),2.0)
