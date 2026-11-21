extends Button
## Presentation-only suppression for the original management Button.
## Godot 4.7.1 Control._get_tooltip + no _make_custom_tooltip override means
## an empty lookup creates no PopupPanel. tooltip_text remains authoritative.
## This script is installed only where the original script was null; the
## management adapter removes only its own installation on detach.
func _get_tooltip(_at_position: Vector2) -> String:
	return ""
