extends SceneTree
func _initialize() -> void:
    _run.call_deferred()

func _run() -> void:
    var data = JSON.parse_string(FileAccess.get_file_as_string("res://../.tmp/emma_locomotion.json"))
    var library := AnimationLibrary.new()
    var model := load("res://art/player_emma/emma.glb").instantiate() as Node3D
    root.add_child(model)
    var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
    var anchors: Array[Dictionary] = []
    for name in ["DEF-Left ankle", "DEF-Right ankle"]:
        var index := rig.find_bone(name)
        var rest := rig.get_bone_global_rest(index)
        for z in [-0.10, 0.035]:
            anchors.append({"bone": index, "point": rest.affine_inverse() * Vector3(rest.origin.x, 0, rest.origin.z + z)})
    for name in data.clips:
        var clip: Dictionary = data.clips[name]
        var animation := Animation.new()
        animation.length = clip.duration
        animation.set_meta("reference_speed", clip.reference_speed)
        animation.loop_mode = Animation.LOOP_LINEAR
        animation.resource_name = name + " (Quaternius CC0)"
        for bone in clip.bones:
            var track := animation.add_track(Animation.TYPE_ROTATION_3D)
            animation.track_set_path(track, NodePath("Skeleton3D:" + bone))
            for i in range(clip.frames + 1):
                var q: Array = clip.bones[bone][i]
                animation.rotation_track_insert_key(track, float(i) / clip.frames * clip.duration, Quaternion(q[0], q[1], q[2], q[3]))
        var track := animation.add_track(Animation.TYPE_POSITION_3D)
        animation.track_set_path(track, NodePath("Skeleton3D:" + clip.root))
        for i in range(clip.frames + 1):
            var p: Array = clip.positions[i]
            animation.position_track_insert_key(track, float(i) / clip.frames * clip.duration, Vector3(p[0], p[1], p[2]))
        var floor_y := INF
        if not String(name).begins_with("Swim"):
            for f in range(clip.frames + 1):
                var time: float = float(f) / clip.frames * clip.duration
                for t in range(animation.get_track_count()):
                    var bone := rig.find_bone(String(animation.track_get_path(t).get_subname(0)))
                    if animation.track_get_type(t) == Animation.TYPE_ROTATION_3D:
                        rig.set_bone_pose_rotation(bone, animation.rotation_track_interpolate(t, time))
                    else:
                        rig.set_bone_pose_position(bone, animation.position_track_interpolate(t, time))
                rig.force_update_all_bone_transforms()
                for anchor in anchors:
                    var point: Vector3 = rig.get_bone_global_pose(anchor.bone) * Vector3(anchor.point)
                    floor_y = minf(floor_y, point.y)
            animation.set_meta("floor_offset", -floor_y * 1.08)
        assert(library.add_animation(name, animation) == OK)
    assert(ResourceSaver.save(library, "res://art/player_emma/emma_locomotion.tres") == OK)
    print("EMMA_AUTHORED_LIBRARY_READY")
    quit()
