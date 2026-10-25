#!/usr/bin/env python3
"""Render the bounded home-art candidate in a startup-minimized, no-focus copy.

All project copies, logs, saves and captures stay under this D: worktree. The
production project window configuration is never edited by this helper.
"""
from __future__ import annotations
import argparse
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
WASH_CAPTURE_SCRIPT = '''extends "res://tests/ark_resident_washing_test.gd"
var capture_view: SubViewport
func _spawn() -> void:
    if not is_instance_valid(capture_view):
        capture_view = SubViewport.new()
        capture_view.size = Vector2i(1280,720)
        capture_view.own_world_3d = true
        capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        root.add_child(capture_view)
    game = Scene.instantiate()
    game.save_root_override = save_root
    capture_view.add_child(game)
    game.set_process(false)
    game.set_physics_process(false)
    await physics_frame
func _capture(actor: String) -> void:
    var output := OS.get_environment("ARK_RESIDENT_WASH_CAPTURE_ROOT")
    assert(not output.is_empty() and output.to_lower().begins_with("d:/"))
    game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    game.camera.size = 4.6
    var target: Vector3 = game.ark_root.to_global(game.ModernUtilityProps.AT+Vector3(-.2,.9,.25))
    for layer in game.find_children("*","CanvasLayer",true,false): layer.visible = false
    for index in 6:
        await process_frame
        game.camera.global_position = target+Vector3(4,3,3)
        game.camera.look_at(target)
        game.camera.make_current()
        RenderingServer.force_draw(false)
    var picture := capture_view.get_texture().get_image()
    assert(picture != null and picture.get_size() == Vector2i(1280,720))
    var colors := {}
    for y in range(0,720,23):
        for x in range(0,1280,23): colors[picture.get_pixel(x,y).to_html()] = true
    assert(colors.size() > 30,"reject low-detail flat captures; human visual review is separate")
    assert(picture.save_png(output.path_join(actor+"_washing.png")) == OK)
    print("ARK_RESIDENT_WASH_CAPTURE_OK: ",actor," offscreen actual scene, palette=",colors.size())
'''

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--tag", help="Preserve other review runs in a separate named subdirectory")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--household", action="store_true", help="Capture the real resident/room workflow instead of art comparisons")
    mode.add_argument("--camera", action="store_true", help="Capture real drag/zoom/reset camera input")
    mode.add_argument("--lantern", action="store_true", help="Capture the earned home meal, playable lantern table and temporary 3D props")
    mode.add_argument("--coast", action="store_true", help="Capture the physical ridge, discovered camp and crafted home fenders")
    mode.add_argument("--modern", action="store_true", help="Capture the installed solar/storage/water corner after real ledger commands")
    mode.add_argument("--washing", action="store_true", help="Capture both residents physically washing at the real basin")
    args = parser.parse_args()
    engine = args.godot.resolve(strict=True)
    if os.name == "nt" and ROOT.drive.lower() != "d:":
        raise RuntimeError("Keep preview files on D:")
    workspace = ROOT / (".tmp/washing-preview" if args.washing else ".tmp/modern-preview" if args.modern else ".tmp/coast-preview" if args.coast else ".tmp/lantern-preview" if args.lantern else ".tmp/camera-preview" if args.camera else ".tmp/household-preview" if args.household else ".tmp/home-art-preview")
    if args.tag:
        if not re.fullmatch(r"[A-Za-z0-9_-]+", args.tag): raise ValueError("Use a bounded review tag")
        workspace = workspace / args.tag
        if workspace.exists(): raise FileExistsError(workspace)
    project = workspace / "project/godot"
    captures = workspace / "captures"
    captures.mkdir(parents=True, exist_ok=True)
    wash_script = workspace / "washing_capture.gd"
    if args.washing:
        wash_script.write_text(WASH_CAPTURE_SCRIPT, encoding="utf-8")
    household_captures = ("01_rooms_and_orders", "02_workshop_active", "03_repair_active",
                          "04_roof_repaired_no_stock", "05_two_completed_repairs")
    camera_captures = ("01_default", "02_dragged", "03_zoomed", "04_reset")
    lantern_captures = ("01_playing", "02_after_hit", "03_settled", "04_table_world", "05_compact_960x600")
    coast_captures = ("01_coast_ridge", "02_old_camp", "03_home_fenders")
    modern_captures = ("01_solar_water_corner", "02_device_detail")
    washing_captures = ("tidekeeper_washing", "sailmaker_washing")
    if args.household or args.camera or args.lantern or args.coast or args.modern or args.washing:
        for name in (washing_captures if args.washing else modern_captures if args.modern else coast_captures if args.coast else lantern_captures if args.lantern else camera_captures if args.camera else household_captures):
            (captures / (name + ".png")).unlink(missing_ok=True)
    shutil.copytree(ROOT / "godot", project, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns(".godot"))
    config = project / "project.godot"
    source = config.read_text(encoding="utf-8")
    source = re.sub(r"(?m)^window/(?:size/mode|flags/no_focus)=.*\n", "", source)
    source = source.replace("[display]", "[display]\nwindow/size/mode=1\nwindow/flags/no_focus=true", 1)
    config.write_text(source, encoding="utf-8")
    env = os.environ.copy()
    env.update(TEMP=str(workspace), TMP=str(workspace), TMPDIR=str(workspace), APPDATA=str(workspace / "appdata"), LOCALAPPDATA=str(workspace / "appdata"),
               ARK_RESIDENT_WASH_CAPTURE_ROOT=captures.as_posix(), ARK_MODERN_CAPTURE_ROOT=captures.as_posix(), ARK_HOME_ART_CAPTURE_ROOT=captures.as_posix(), ARK_CAMERA_CAPTURE_ROOT=captures.as_posix(), ARK_LANTERN_CAPTURE_ROOT=captures.as_posix(), ARK_COAST_CAPTURE_ROOT=captures.as_posix())
    descriptor = ROOT / ".local/native/ark_simulation/ark_simulation.gdextension"
    if descriptor.is_file():
        env["ARK_SIMULATION_EXTENSION"] = descriptor.as_posix()
    common = [str(engine), "--audio-driver", "Dummy", "--path", str(project)]
    for name, options in [
        ("import", ["--headless", "--import"]),
        ("render", ["--rendering-method", "gl_compatibility", "--resolution", "1280x720",
                    "--quit-after", "8000" if args.washing else "6000", "--fixed-fps", "60", "--script", str(wash_script) if args.washing else "res://tests/ark_modern_utilities_test.gd" if args.modern else "res://tests/ark_coast_exploration_test.gd" if args.coast else "res://tests/ark_lantern_table_test.gd" if args.lantern else "res://tests/ark_orbit_camera_test.gd" if args.camera else "res://tests/ark_household_work_test.gd" if args.household else "res://tests/ark_home_art_sample_test.gd"]),
    ]:
        result = subprocess.run([*common, "--log-file", str(workspace / (name + "-engine.log")), *options],
                                env=env, cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                                errors="replace", timeout=600, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        output = result.stdout + result.stderr
        (workspace / (name + ".log")).write_text(output, encoding="utf-8")
        if result.returncode or "SCRIPT ERROR:" in output or "ERROR:" in output:
            raise RuntimeError(f"{name} failed ({result.returncode}): {output[-5000:]}")
        marker = "ARK_RESIDENT_WASHING_TEST_OK:" if args.washing else "ARK_MODERN_UTILITIES_TEST_OK:" if args.modern else "ARK_COAST_EXPLORATION_TEST_OK:" if args.coast else "ARK_LANTERN_TABLE_TEST_OK:" if args.lantern else "ARK_ORBIT_CAMERA_TEST_OK:" if args.camera else "ARK_HOUSEHOLD_WORK_TEST_OK:" if args.household else "ARK_HOME_ART_CAPTURES_OK:"
        if name == "render" and marker not in output:
            raise RuntimeError("Render exited without producing the capture marker")
        if name == "render" and args.washing and not all("ARK_RESIDENT_WASH_CAPTURE_OK: " + actor in output for actor in ("tidekeeper", "sailmaker")):
            raise RuntimeError("Both actual offscreen resident images must pass the low-detail flat-frame guard")
        print(f"HOME_ART_{name.upper()}_OK", flush=True)
    if args.household or args.camera or args.lantern or args.coast or args.modern or args.washing:
        for name in (washing_captures if args.washing else modern_captures if args.modern else coast_captures if args.coast else lantern_captures if args.lantern else camera_captures if args.camera else household_captures):
            path = captures / (name + ".png")
            data = path.read_bytes()
            expected_size = (960, 600) if args.lantern and name == "05_compact_960x600" else (1280, 720)
            if data[:8] != b"\x89PNG\r\n\x1a\n" or struct.unpack(">II", data[16:24]) != expected_size or len(data) < 10000:
                raise RuntimeError(f"Invalid household screenshot: {path}")
        print(f"{'WASHING' if args.washing else 'MODERN' if args.modern else 'COAST' if args.coast else 'LANTERN' if args.lantern else 'CAMERA' if args.camera else 'HOUSEHOLD'}_PREVIEW_OK: display-backed workflow captures at {captures}")
        return 0
    for view in ("deck", "cabin", "coast"):
        for weather in ("day", "night", "storm"):
            pair = []
            for variant in ("before", "candidate"):
                path = captures / f"{view}_{weather}_{variant}.png"
                data = path.read_bytes()
                if data[:8] != b"\x89PNG\r\n\x1a\n" or struct.unpack(">II", data[16:24]) != (1280, 720) or len(data) < 10000:
                    raise RuntimeError(f"Invalid screenshot: {path}")
                pair.append(data)
            if pair[0] == pair[1]:
                raise RuntimeError(f"Before/candidate images are identical: {view}/{weather}")
    print(f"HOME_ART_PREVIEW_OK: 18 display-backed comparisons at {captures}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
