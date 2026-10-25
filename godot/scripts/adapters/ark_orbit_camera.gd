extends RefCounted

## Presentation-only camera state. No gameplay save fields or mouse capture.
const DEFAULT_OFFSET := Vector3(0.0, 8.5, 10.5)
const DEFAULT_PITCH := atan2(8.5, 10.5)
const DEFAULT_DISTANCE := 13.5092560861063
const MIN_PITCH := deg_to_rad(20.0)
const MAX_PITCH := deg_to_rad(75.0)
const MIN_DISTANCE := 5.0
const MAX_DISTANCE := 26.0
const DRAG_RADIANS_PER_PIXEL := 0.006
var yaw := 0.0
var pitch := DEFAULT_PITCH
var distance := DEFAULT_DISTANCE
var dragging := false
var adjusted := false

func reset() -> void:
	yaw = 0.0
	pitch = DEFAULT_PITCH
	distance = DEFAULT_DISTANCE
	dragging = false
	adjusted = false

func release() -> void:
	dragging = false

func handle(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
			return true
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 0.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.88
			distance = clampf(distance * factor, MIN_DISTANCE, MAX_DISTANCE)
			adjusted = true
			return true
	elif event is InputEventMouseMotion and dragging:
		# Button mask is authoritative too: lost release events must not stick.
		if not (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
			release()
			return false
		if not event.relative.is_finite(): return false
		yaw = wrapf(yaw - event.relative.x * DRAG_RADIANS_PER_PIXEL, -PI, PI)
		pitch = clampf(pitch + event.relative.y * DRAG_RADIANS_PER_PIXEL, MIN_PITCH, MAX_PITCH)
		adjusted = true
		return true
	return false

func offset() -> Vector3:
	# Untouched/reset view stays EXACTLY the legacy camera, including goldens.
	if not adjusted: return DEFAULT_OFFSET
	var horizontal := distance * cos(pitch)
	return Vector3(sin(yaw) * horizontal, sin(pitch) * distance, cos(yaw) * horizontal)

func movement(input: Vector2) -> Vector3:
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)

func apply(camera: Camera3D, actor: Node3D, collision_world: World3D = null) -> void:
	if camera == null or actor == null: return
	var target := actor.global_position + Vector3(0, 1.0, 0)
	var desired := target + offset()
	if adjusted and collision_world != null:
		var query := PhysicsRayQueryParameters3D.create(target, desired, 1)
		if actor is CollisionObject3D: query.exclude = [actor.get_rid()]
		var hit := collision_world.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var toward: Vector3 = (desired - target).normalized()
			var safe_distance := maxf(0.6, target.distance_to(hit.position) - 0.2)
			desired = target + toward * safe_distance
	camera.global_position = desired
	camera.look_at(target, Vector3.UP)
