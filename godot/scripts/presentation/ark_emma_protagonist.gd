extends Node3D
## Authored Quaternius CC0 locomotion retargeted from T-pose to Emma's rig.
## Presentation only: never moves the actor, changes collisions or writes saves.
const MODEL := preload("res://art/player_emma/emma.glb")
const LOCOMOTION := preload("res://art/player_emma/emma_locomotion.tres")
const BONE_NAMES := {
    "left_arm": "DEFLeftarm", "right_arm": "DEFRightarm",
    "left_elbow": "DEFLeftelbow", "right_elbow": "DEFRightelbow",
    "left_leg": "DEFLeftleg", "right_leg": "DEFRightleg",
    "left_knee": "DEFLeftknee", "right_knee": "DEFRightknee",
    "left_hand": "DEFLeftwrist", "right_hand": "DEFRightwrist",
    "left_foot": "DEFLeftankle", "right_foot": "DEFRightankle",
    "left_toes": "DEFLefttoe", "right_toes": "DEFRighttoe",
    "head": "DEFHead", "spine": "DEFSpine"
}

var model: Node3D
var skeleton: Skeleton3D
var bones: Dictionary = {}
var actor: CharacterBody3D
var controller: Node3D
var previous_position := Vector3.ZERO
var previous_parent_id := 0
var phase := 0.0
var idle_clock := 0.0
var swim_clock := 0.0
var swim_idle_clock := 0.0
var stride := 0.0
var swimming := false
var swim_blend := 0.0
var run_blend := 0.0
var authored_tracks: Array[Dictionary] = []
var ready_to_pose := false

func setup(body: CharacterBody3D, game_controller: Node3D) -> void:
    name = "EmmaProtagonist"
    actor = body
    controller = game_controller
    previous_position = actor.position
    previous_parent_id = actor.get_parent().get_instance_id()
    model = MODEL.instantiate() as Node3D
    model.rotation.y = PI
    model.scale = Vector3.ONE * 1.08
    add_child(model)
    skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
    for key in BONE_NAMES:
        for index in range(skeleton.get_bone_count()):
            var normalized := skeleton.get_bone_name(index).replace("-", "").replace(" ", "").replace("_", "")
            if normalized == BONE_NAMES[key]:
                bones[key] = index
                break
        assert(bones.has(key), "Missing Emma bone: " + key)
    var walk: Animation = LOCOMOTION.get_animation("Walk_Loop")
    for track in range(walk.get_track_count()):
        var bone_name := String(walk.track_get_path(track).get_subname(0))
        var index := skeleton.find_bone(bone_name)
        assert(index >= 0, "Retargeted track has no matching bone: " + bone_name)
        authored_tracks.append({"track": track, "bone": index, "type": walk.track_get_type(track)})
    ready_to_pose = true
    update_pose(Vector3.ZERO, 0.0, false)

func _physics_process(delta: float) -> void:
    if not is_instance_valid(actor): return
    var parent_id := actor.get_parent().get_instance_id()
    # Boarding changes local coordinates even when the actor stays in place.
    # Do not turn that coordinate jump into a one-frame sprint animation.
    var displacement := actor.position - previous_position if parent_id == previous_parent_id else Vector3.ZERO
    previous_position = actor.position
    previous_parent_id = parent_id
    var in_water: bool = is_instance_valid(controller) and controller.get("is_swimming") == true
    update_pose(displacement / maxf(delta, 0.0001), delta, in_water)

func update_pose(motion: Vector3, delta: float, in_water: bool) -> void:
    if not ready_to_pose: return
    swimming = in_water
    var speed := Vector2(motion.x, motion.z).length()
    stride = move_toward(stride, clampf(speed / 0.15, 0.0, 1.0), delta * 5.0)
    swim_blend = move_toward(swim_blend, 1.0 if swimming else 0.0, delta * 4.0)
    run_blend = move_toward(run_blend, smoothstep(2.0, 4.0, speed), delta * 6.0)
    var idle: Animation = LOCOMOTION.get_animation("Idle_Loop")
    var walk: Animation = LOCOMOTION.get_animation("Walk_Loop")
    var running: Animation = LOCOMOTION.get_animation("Jog_Fwd_Loop")
    var swim_idle: Animation = LOCOMOTION.get_animation("Swim_Idle_Loop")
    var swim: Animation = LOCOMOTION.get_animation("Swim_Fwd_Loop")
    idle_clock = fmod(idle_clock + delta, idle.length)
    # Clips have different durations; wrapping the idle clock by the forward
    # clip would truncate treading water and snap its pose every 1.33 seconds.
    swim_clock = fmod(swim_clock + delta, swim.length)
    swim_idle_clock = fmod(swim_idle_clock + delta, swim_idle.length)
    var reference_speed := lerpf(float(walk.get_meta("reference_speed")), float(running.get_meta("reference_speed")), run_blend)
    var playback_rate := clampf(speed / maxf(reference_speed, 0.1), 0.25, 1.7)
    var cycle_length := lerpf(walk.length, running.length, run_blend)
    phase = fmod(phase + delta * TAU / cycle_length * playback_rate * stride, TAU)
    var walk_time := phase / TAU * walk.length
    var run_time := phase / TAU * running.length
    for entry in authored_tracks:
        var track: int = entry.track
        var index: int = entry.bone
        if entry.type == Animation.TYPE_ROTATION_3D:
            var resting := idle.rotation_track_interpolate(track, idle_clock)
            var moving := walk.rotation_track_interpolate(track, walk_time).slerp(running.rotation_track_interpolate(track, run_time), run_blend)
            var land := resting.slerp(moving, stride)
            var water := swim_idle.rotation_track_interpolate(track, swim_idle_clock).slerp(swim.rotation_track_interpolate(track, swim_clock), stride)
            skeleton.set_bone_pose_rotation(index, land.slerp(water, swim_blend))
        elif entry.type == Animation.TYPE_POSITION_3D:
            var moving := walk.position_track_interpolate(track, walk_time).lerp(running.position_track_interpolate(track, run_time), run_blend)
            var land := idle.position_track_interpolate(track, idle_clock).lerp(moving, stride)
            var water := swim_idle.position_track_interpolate(track, swim_idle_clock).lerp(swim.position_track_interpolate(track, swim_clock), stride)
            skeleton.set_bone_pose_position(index, land.lerp(water, swim_blend))
    skeleton.force_update_all_bone_transforms()
    # A per-clip calibrated floor offset preserves the authored pelvis bounce
    # and running flight phase instead of pinning the lower foot every frame.
    var moving_floor := lerpf(float(walk.get_meta("floor_offset", 0.0)), float(running.get_meta("floor_offset", 0.0)), run_blend)
    var floor_offset := lerpf(float(idle.get_meta("floor_offset", 0.0)), moving_floor, stride)
    position.y = lerpf(floor_offset, 0.0, swim_blend)
