extends SceneTree
const Paths = preload("res://tests/ark_test_paths.gd")
var view: SubViewport
func _initialize() -> void:
    if DisplayServer.get_name() != "headless":
        root.set_flag(Window.FLAG_NO_FOCUS, true)
        root.mode = Window.MODE_MINIMIZED
    _run.call_deferred()
func capture(label: String) -> void:
    if DisplayServer.get_name() == "headless": return
    for i in range(5):
        await process_frame
        RenderingServer.force_draw(false)
    var directory := ProjectSettings.globalize_path("res://../.tmp/emma-preview")
    DirAccess.make_dir_recursive_absolute(directory)
    assert(view.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK)
func _run() -> void:
    var save_path := ProjectSettings.globalize_path("res://../.local/test_emma_avatar").simplify_path()
    if DisplayServer.get_name() != "headless": save_path += "_render"
    assert(Paths.is_safe_save_root(save_path))
    var saver := preload("res://scripts/ark_greybox_save.gd").new(save_path)
    saver.clear_for_test()
    view = SubViewport.new()
    view.size = Vector2i(1280, 720)
    view.own_world_3d = true
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    var game = load("res://scenes/ark_greybox.tscn").instantiate()
    game.set("save_root_override", save_path)
    view.add_child(game)
    game.set_process(false)
    game.set_physics_process(false)
    var body: CharacterBody3D = game.player
    var emma = game.avatar_visual
    var pixel = body.get_node("PixelProtagonistTrial")
    emma.set_physics_process(false)
    pixel.set_physics_process(false)
    assert(emma.visible and not pixel.enabled)
    assert(emma.skeleton.get_bone_count() == 331 and emma.bones.size() == 16)
    assert(emma.model.find_children("*", "MeshInstance3D", true, false).size() == 6)
    body.position.x = 1.3
    for tick in range(45): game.call("_physics_process", 1.0 / 60.0)
    # Exercise the actual input/physics route, not only the visual speed blend.
    var initial_transform := body.transform
    body.position = Vector3(0.0, 40.0, 0.0)
    var right := InputEventKey.new()
    right.keycode = KEY_D
    right.pressed = true
    Input.parse_input_event(right.duplicate())
    Input.flush_buffered_events()
    await physics_frame
    game.call("_physics_process", 1.0 / 60.0)
    assert(is_equal_approx(body.velocity.x, game.WALK_SPEED), "plain movement must use natural walking speed")
    var shift := InputEventKey.new()
    shift.keycode = KEY_SHIFT
    shift.physical_keycode = KEY_SHIFT
    shift.shift_pressed = true
    shift.pressed = true
    Input.parse_input_event(shift.duplicate())
    Input.flush_buffered_events()
    await physics_frame
    game.call("_physics_process", 1.0 / 60.0)
    assert(is_equal_approx(body.velocity.x, game.SPRINT_SPEED), "Shift must retain fast ground movement")
    shift.pressed = false
    shift.shift_pressed = false
    Input.parse_input_event(shift.duplicate())
    Input.flush_buffered_events()
    await physics_frame
    game.call("_physics_process", 1.0 / 60.0)
    assert(is_equal_approx(body.velocity.x, game.WALK_SPEED), "releasing Shift must restore walking")
    right.pressed = false
    Input.parse_input_event(right.duplicate())
    Input.flush_buffered_events()
    body.transform = initial_transform
    body.velocity = Vector3.ZERO
    var start := body.transform
    var shape := (body.get_child(0) as CollisionShape3D).shape
    var state: Dictionary = game.call("_build_save_state")
    var rests: Array[Transform3D] = []
    for index in range(emma.skeleton.get_bone_count()):
        rests.append(emma.skeleton.get_bone_rest(index))
    assert(emma.authored_tracks.size() == 50, "49 retargeted human joints plus pelvis translation must be loaded")
    assert(emma.LOCOMOTION.has_animation("Walk_Loop") and emma.LOCOMOTION.has_animation("Idle_Loop"))
    assert(emma.LOCOMOTION.get_animation("Walk_Loop").length > 1.0)
    for tick in range(120):
        emma.update_pose(Vector3(1.2, 0, 0), 1.0 / 60.0, false)
        for entry in emma.authored_tracks:
            var rotation: Quaternion = emma.skeleton.get_bone_pose_rotation(entry.bone)
            assert(rotation.is_finite() and is_equal_approx(rotation.length(), 1.0), "authored joint rotations must stay finite and normalized")
        assert(absf(emma.position.y) <= 0.15)
    var old_phase: float = emma.phase
    emma.phase = 0.0
    emma.update_pose(Vector3(1.2, 0, 0), 0.0, false)
    var ankle_a: Vector3 = emma.skeleton.get_bone_global_pose(emma.bones["left_foot"]).origin
    var wrist_a: Vector3 = emma.skeleton.get_bone_global_pose(emma.bones["left_hand"]).origin
    emma.phase = PI
    emma.update_pose(Vector3(1.2, 0, 0), 0.0, false)
    var ankle_b: Vector3 = emma.skeleton.get_bone_global_pose(emma.bones["left_foot"]).origin
    var wrist_b: Vector3 = emma.skeleton.get_bone_global_pose(emma.bones["left_hand"]).origin
    assert((ankle_a.z - ankle_b.z) * (wrist_a.z - wrist_b.z) < -0.002, "authored walk must swing arms opposite their same-side legs")
    emma.phase = old_phase
    for index in range(rests.size()):
        assert(emma.skeleton.get_bone_rest(index) == rests[index], "posing must preserve the imported bind/rest skeleton")
    for tick in range(30): emma.update_pose(Vector3.ZERO, 1.0 / 60.0, false)
    var leg: int = emma.bones["left_leg"]
    var idle: Quaternion = emma.skeleton.get_bone_pose_rotation(leg)
    for tick in range(12): emma.update_pose(Vector3(1.2, 0, 0), 1.0 / 60.0, false)
    assert(not emma.skeleton.get_bone_pose_rotation(leg).is_equal_approx(idle))
    assert(body.transform == start and game.call("_build_save_state") == state)
    await capture("01_game_walk")
    for tick in range(30): emma.update_pose(Vector3.ZERO, 1.0 / 60.0, false)
    assert(is_zero_approx(emma.stride))
    await capture("02_game_idle")
    # Use actual input dispatch for both directions of the retained F8 switch.
    for enabled in [true, false]:
        var key := InputEventKey.new()
        key.physical_keycode = KEY_F8
        key.pressed = true
        view.push_input(key)
        await process_frame
        assert(pixel.enabled == enabled and emma.visible == not enabled)
        assert(body.transform == start and (body.get_child(0) as CollisionShape3D).shape == shape)
        assert(game.call("_build_save_state") == state)
    # Boarding/navigation can move the body out of ArkRoot. Animation state
    # must still come from the game, with no assumptions about ancestor depth.
    var original_parent := body.get_parent()
    var shore := Node3D.new()
    view.add_child(shore)
    body.reparent(shore)
    game.set("is_swimming", true)
    emma._physics_process(1.0 / 60.0)
    assert(emma.swimming and emma.controller == game)
    assert(is_zero_approx(emma.stride), "reparenting without motion must not trigger running")
    body.reparent(original_parent)
    game.set("is_swimming", false)
    emma._physics_process(1.0 / 60.0)
    assert(not emma.swimming)
    assert(is_zero_approx(emma.stride), "boarding coordinates must not become a false step")
    shore.queue_free()
    for tick in range(30): emma.update_pose(Vector3.ZERO, 1.0 / 60.0, false)
    # Close camera checks textured face, hair and the lowered rest arms.
    # Hide boat geometry and HUD for joint inspection so rails cannot hide feet.
    # Earlier captures retain the normal game camera and world presentation.
    for mesh in game.find_children("*", "GeometryInstance3D", true, false):
        if not emma.model.is_ancestor_of(mesh): mesh.visible = false
    for layer in game.find_children("*", "CanvasLayer", true, false):
        layer.visible = false
    var floor_mesh := MeshInstance3D.new()
    var floor_plane := PlaneMesh.new()
    floor_plane.size = Vector2(6, 6)
    floor_mesh.mesh = floor_plane
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color(0.28, 0.33, 0.35)
    floor_material.roughness = 1.0
    floor_mesh.material_override = floor_material
    view.add_child(floor_mesh)
    floor_mesh.global_position = body.global_position - Vector3(0, 0.005, 0)
    var camera: Camera3D = game.camera
    camera.global_position = body.global_position + Vector3(0, 1.0, 2.7)
    camera.look_at(body.global_position + Vector3(0, 0.85, 0), Vector3.UP)
    emma.rotation.y = 0
    await capture("03_emma_front")
    emma.rotation.y = PI
    await capture("04_emma_back")
    emma.rotation.y = PI * 0.5
    await capture("05_emma_side")
    for tick in range(12): emma.update_pose(Vector3(1.2, 0, 0), 1.0 / 60.0, false)
    await capture("05b_emma_side_stride")
    if DisplayServer.get_name() != "headless":
        # Fixed simulation time produces a repeatable moving preview, regardless
        # of capture/render speed. Sample several complete steps from the side.
        for tick in range(30): emma.update_pose(Vector3(1.2, 0, 0), 1.0 / 60.0, false)
        emma.phase = 0.0
        for frame in range(48):
            # Two complete cycles, with no duplicate endpoint or loop hitch.
            emma.phase = TAU * 2.0 * float(frame) / 48.0
            emma.update_pose(Vector3(1.2, 0, 0), 0.0, false)
            await capture("walk_%02d" % frame)
        for tick in range(30): emma.update_pose(Vector3(5, 0, 0), 1.0 / 60.0, false)
        assert(emma.run_blend > 0.99)
        for frame in range(48):
            emma.phase = TAU * 2.0 * float(frame) / 48.0
            emma.update_pose(Vector3(5, 0, 0), 0.0, false)
            await capture("run_%02d" % frame)
    for tick in range(30): emma.update_pose(Vector3(1, 0, 0), 1.0 / 60.0, true)
    assert(emma.swimming)
    await capture("06_emma_swim_pose")
    view.queue_free()
    await process_frame
    saver.clear_for_test()
    print("ARK_EMMA_PROTAGONIST_TEST_OK:")
    quit()
