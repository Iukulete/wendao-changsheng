#!/usr/bin/env python3
"""Verify the active 3D Ark product using the pinned official Godot 4.7.1.

Default: source/archive/unit guards, headless import + menu + every Ark
regression, actual resource-pack export + boundary validation + packed menu.
Display-backed capture is deliberately separate: --render-only.
Never downloads an engine, installs drivers, or substitutes another version.
"""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
import shutil

from verify_migration_surface import canonical_tests, verify_pack
from verify_native_simulation import verify_bundle as verify_native_bundle

ROOT = Path(__file__).resolve().parents[1]
ANSI_PATTERN = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
ERROR_PATTERN = re.compile(r"(?m)^\s*(?:SCRIPT ERROR|ERROR|FATAL ERROR|USER ERROR):")
VERSION_PATTERN = re.compile(r"^4\.7\.1\.stable\.official\.[0-9a-f]+$")
RENDER_SCRIPT = "res://tests/ark_render_capture_test.gd"
RENDER_CAPTURES = {"menu_1280x720.png": (1280, 720), "menu_1440x900.png": (1440, 900),
                   "ark_1280x720.png": (1280, 720), "menu_return_1280x720.png": (1280, 720)}

EMMA_CAPTURES = {name + ".png": (1280, 720) for name in (
    "01_game_walk", "02_game_idle", "03_emma_front", "04_emma_back",
    "05_emma_side", "05b_emma_side_stride", "06_emma_swim_pose",
    *(f"{clip}_{frame:02d}" for clip in ("walk", "run") for frame in range(48)))}


def clear_emma_captures(directory: Path) -> None:
    """Old evidence must never satisfy a new run that exits before capturing."""
    directory.mkdir(parents=True, exist_ok=True)
    for name in EMMA_CAPTURES:
        (directory / name).unlink(missing_ok=True)


def verify_emma_captures(directory: Path) -> None:
    """Check complete evidence and motion, not subjective animation quality."""
    hashes: dict[str, str] = {}
    for name, dimensions in EMMA_CAPTURES.items():
        path = directory / name
        data = path.read_bytes()
        if len(data) < 10000 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
            raise RuntimeError(f"Missing, tiny or invalid Emma capture: {path}")
        if struct.unpack(">II", data[16:24]) != dimensions:
            raise RuntimeError(f"Emma capture dimensions differ from {dimensions}: {path}")
        hashes[name] = hashlib.sha256(data).hexdigest()
    # Two cycles intentionally repeat poses; requiring every frame to differ
    # would reject valid evidence. Reject an entirely frozen sequence instead.
    for clip in ("walk", "run"):
        if len({hashes[f"{clip}_{frame:02d}.png"] for frame in range(48)}) < 2:
            raise RuntimeError(f"Emma {clip} captures show no frame changes")


def regression_scripts() -> list[str]:
    return canonical_tests(ROOT)


def run(command: list[str], name: str, log_dir: Path, env: dict[str, str],
        timeout: int, marker: str | None = None, cwd: Path = ROOT) -> str:
    print(f"Running {name}...", flush=True)
    # Engine file logs must not fall back to Windows AppData on C:. Keep the
    # independent engine log beside captured stdout; do not mutate callers.
    if Path(command[0]).name.lower().startswith("godot") and "--version" not in command and "--log-file" not in command:
        command = [*command, "--log-file", str((log_dir / f"{name}-engine.log").resolve())]
    try:
        result = subprocess.run(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, encoding="utf-8",
                                errors="replace", timeout=timeout)
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        (log_dir / f"{name}.log").write_text(output, encoding="utf-8")
        raise RuntimeError(f"{name} exceeded {timeout}s; process terminated") from error
    output = result.stdout
    (log_dir / f"{name}.log").write_text(output, encoding="utf-8")
    print(output, end="" if output.endswith("\n") else "\n", flush=True)
    plain = ANSI_PATTERN.sub("", output)
    marker_found = marker is None or re.search(r"(?m)^\s*" + re.escape(marker), plain) is not None
    if result.returncode or ERROR_PATTERN.search(plain) or not marker_found:
        raise RuntimeError(f"{name} failed: exit={result.returncode}, expected marker={marker!r}; "
                           f"see {log_dir / (name + '.log')}")
    return output


def verify_captures(directory: Path) -> None:
    hashes: dict[str, str] = {}
    for name, dimensions in RENDER_CAPTURES.items():
        path = directory / name
        data = path.read_bytes()
        if len(data) < 10000 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
            raise RuntimeError(f"Missing, tiny or invalid render capture: {path}")
        if struct.unpack(">II", data[16:24]) != dimensions:
            raise RuntimeError(f"Render capture dimensions differ from {dimensions}: {path}")
        digest = hashlib.sha256(data).hexdigest()
        # Returning to the unchanged menu is allowed to produce identical pixels.
        if name != "menu_return_1280x720.png" and digest in hashes:
            raise RuntimeError(f"Distinct render states share identical pixels: {name}, {hashes[digest]}")
        hashes[digest] = name


def packed_scene_smoke(engine: Path, pack: Path, logs: Path, env: dict[str, str], temp: Path,
                       native_source: Path | None = None) -> None:
    # This probe lives outside the resource pack: tests are never shipped. It
    # loads the configured menu and enters the real 3D scene using only packed
    # dependencies, with a unique repository-local throwaway save root.
    probe = temp / "packed_scene_smoke.gd"
    probe.write_text("""extends SceneTree
func _initialize() -> void:
    _run.call_deferred()
func _run() -> void:
    var save_root := OS.get_environment("ARK_VALIDATION_SAVE_ROOT")
    assert(save_root.is_absolute_path() and save_root.get_file().begins_with("test_ark_pack_"))
    var scene := load(str(ProjectSettings.get_setting("application/run/main_scene"))) as PackedScene
    assert(scene != null)
    var menu := scene.instantiate()
    menu.set("save_root_override", save_root)
    root.add_child(menu)
    current_scene = menu
    await process_frame
    menu.call("_enter_ark")
    for frame in range(4):
        await process_frame
    var game := current_scene
    assert(game is Node3D, "packed menu must enter the actual 3D Ark")
    assert(game.get("household_work").backend_status().backend == "native-flecs", "PCK must load the copied external native bundle")
    var coast = game.get("opening_coast")
    coast.refresh_moving_actors()
    var support_queries: int = coast.actor_support_sample_count
    coast.refresh_moving_actors()
    assert(coast.actor_support_sample_count == support_queries, "packed static residents must reuse terrain support")
    for actor in coast.actor_contacts:
        assert(actor.feet.size() > 0 and actor.feet.size() < 2688, "packed neutral probes must be deduplicated")
    assert(str(game.get("save_root_override")) == save_root)
    var service = game.get("save_service")
    assert(str(service.call("get_save_path")).begins_with(save_root + "/"))
    assert(not ResourceLoader.exists("res://tests/ark_menu_integration_test.gd"))
    assert(ProjectSettings.get_setting("display/window/size/mode", 0) == 0)
    assert(not ProjectSettings.get_setting("display/window/flags/no_focus", false))
    game.set("wood", 20)
    assert(game.call("_try_place_shelter", Vector3.ZERO))
    var paid: int = game.get("wood")
    assert(game.get("home_art_sample").enabled)
    assert(game.get("home_art_sample").timber_texture().get_size() == Vector2(1254, 1254))
    assert(game.get_node_or_null("ArkRoot/BuiltShelter/HomeArtCandidate") != null)
    assert(game.get("wood") == paid and game.get("economy").audit().ok)
    game.call("_toggle_home_art_sample")
    assert(not game.get("home_art_sample").enabled)
    game.call("_toggle_home_art_sample")
    assert(game.get("home_art_sample").enabled)
    assert(game.call("_save_progress"))
    game.call("_return_to_main_menu")
    for frame in range(4):
        await process_frame
    assert(current_scene is Control, "packed Ark must return to the menu")
    assert(str(current_scene.get("save_root_override")) == save_root)
    current_scene.call("_enter_ark")
    for frame in range(4):
        await process_frame
    game = current_scene
    assert(game is Node3D and not game.get_meta("save_load_blocked", false))
    assert(game.get("home_art_sample").enabled and game.get("home_art_button").button_pressed, "packed cold reload uses the real production art default")
    assert(game.get("shelter_built") and game.get("wood") == paid)
    assert(game.get_node_or_null("ArkRoot/BuiltShelter") != null)
    assert(game.get("economy").audit().ok)
    var orbit = game.get("orbit_camera")
    var press := InputEventMouseButton.new()
    press.button_index = MOUSE_BUTTON_RIGHT
    press.pressed = true
    game.call("_unhandled_input", press)
    var drag := InputEventMouseMotion.new()
    drag.relative = Vector2(80, 10)
    drag.button_mask = MOUSE_BUTTON_MASK_RIGHT
    game.call("_unhandled_input", drag)
    await physics_frame
    assert(orbit.adjusted and orbit.yaw < -0.4 and game.get("camera").fov == 54.0)
    orbit.reset()
    game.call("_update_follow_camera")
    var metrics := InputEventKey.new()
    metrics.keycode = KEY_F8
    metrics.pressed = true
    game.call("_input", metrics)
    assert(game.get("nearfuture_hud").get("_metrics_enabled"))
    game.call("_input", metrics)
    assert(not game.get("nearfuture_hud").get("_metrics_enabled"))
    game.call("_load_progress")
    assert(game.get("wood") == paid and game.get("economy").audit().ok)
    # Explicit synthetic compatibility fixture, NOT evidence of earned rooms,
    # admission or repairs. Release must execute restore outside debug asserts.
    game.set_process(false)
    game.set_physics_process(false)
    game.set("sailmaker_met", true)
    game.set("sailmaker_boarded", true)
    game.set("storage_built", true)
    game.set("workbench_built", true)
    game.set("raft_edge_damaged", true)
    game.get("household_work").enabled = true
    var began_work: bool = game.get("household_work").begin("raft_edge")
    assert(began_work)
    var expected_work: Dictionary = game.get("household_work").snapshot()
    assert(game.call("_save_progress"))
    game.call("_load_progress")
    assert(game.get("household_work").snapshot() == expected_work)
    assert(game.get("household_work").enabled and game.get("household_work").active())
    assert(game.get("household_work").backend_status().backend == "native-flecs")
    # Packed-only resource/rule/view check; the separate earned-home regression
    # tests the genuine harvest/meal/controller flow rather than this fixture.
    var table = load("res://scripts/modules/leisure/ark_lantern_table.gd").new()
    var began_round: bool = table.begin("tidekeeper", 1)
    assert(began_round and table.view().phase == "playing")
    var table_ui = load("res://scripts/presentation/ark_lantern_table_ui.gd").new()
    var layer := CanvasLayer.new()
    game.add_child(layer)
    var ui_theme := Theme.new()
    ui_theme.default_font = load("res://art/fonts/ark_ui_font.tres")
    table_ui.theme = ui_theme
    layer.add_child(table_ui)
    table_ui.present(table.view(), "归舟灯下，不押物资。")
    assert(table_ui.visible)
    assert(load("res://art/lantern_table/cloth_albedo_v1.png").get_size() == Vector2(1254, 1254))
    assert(table_ui.get("player_cards").get_child_count() == 2)
    var held_round: Dictionary = table.snapshot()
    var next_card: int = held_round.deck[int(held_round.cursor)]
    var took_card: bool = table.hit()
    assert(took_card and table.snapshot().player.back() == next_card)
    var restored_round: bool = table.restore(held_round)
    assert(restored_round and table.snapshot() == held_round)
    layer.queue_free()
    await process_frame
    print("ARK_PACK_SCENE_SMOKE_OK: menu/build/candidate-assets/save/return/recreate/repeat-load/orbit/metrics/native active-work restore/packed lantern rules and cloth UI, normal window, isolated synthetic fixtures, no packaged tests")
    quit()
""", encoding="utf-8")
    local = ROOT / ".local"
    local.mkdir(exist_ok=True)
    native_copy = temp / "packed-native"
    shutil.copytree(native_source or ROOT / ".local/native/ark_simulation", native_copy, dirs_exist_ok=True)
    verify_native_bundle(native_copy)
    with tempfile.TemporaryDirectory(prefix="test_ark_pack_", dir=local) as save_root:
        probe_env = {**env, "ARK_VALIDATION_SAVE_ROOT": Path(save_root).as_posix(),
                     "ARK_SIMULATION_EXTENSION": (native_copy / "ark_simulation.gdextension").as_posix()}
        run([str(engine), "--headless", "--audio-driver", "Dummy", "--main-pack", str(pack),
             "--quit-after", "600", "--script", str(probe)], "packed_scene_smoke", logs,
            probe_env, 180, "ARK_PACK_SCENE_SMOKE_OK:", cwd=temp)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True, help="Verified official Godot 4.7.1 binary")
    parser.add_argument("--render-only", action="store_true", help="Run only the separate real-display capture gate")
    parser.add_argument("--display-driver", choices=("windows", "x11", "wayland"), help="Display backend for capture; never headless")
    args = parser.parse_args()
    engine = args.godot.resolve()
    if not engine.is_file():
        raise RuntimeError(f"Godot binary not found: {engine}")
    if os.name == "nt" and ROOT.drive.lower() != "d:":
        raise RuntimeError("Windows project and validation data must remain on D:")
    temp = ROOT / ".tmp/godot-verify"
    logs = temp / "logs"
    logs.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(TEMP=str(temp), TMP=str(temp), TMPDIR=str(temp),
               XDG_CACHE_HOME=str(temp / "cache"), XDG_CONFIG_HOME=str(temp / "config"),
               XDG_DATA_HOME=str(temp / "data"), PYTHONUTF8="1")
    for directory in ("cache", "config", "data"):
        (temp / directory).mkdir(exist_ok=True)
    version = run([str(engine), "--version"], "version", logs, env, 30).strip()
    if not VERSION_PATTERN.fullmatch(version):
        raise RuntimeError(f"Godot version drift detected: {version}")
    native_dir = ROOT / ".local/native/ark_simulation"
    run([sys.executable, "-X", "utf8", str(ROOT / "native/ark_simulation/build.py"),
         "--godot", str(engine), "--out", str(native_dir)], "native_simulation_build", logs, env, 600, "ARK_SIMULATION_EXTENSION=")
    verify_native_bundle(native_dir)
    env["ARK_SIMULATION_EXTENSION"] = (native_dir / "ark_simulation.gdextension").as_posix()
    common = [str(engine), "--audio-driver", "Dummy", "--path", str(ROOT / "godot")]
    if args.render_only:
        captures = ROOT / ".tmp/ark-render-captures"
        captures.mkdir(parents=True, exist_ok=True)
        for name in RENDER_CAPTURES:
            (captures / name).unlink(missing_ok=True)
        display = ["--display-driver", args.display_driver] if args.display_driver else []
        # Set no-focus/minimized before startup; window managers can clamp offscreen
        # positions, so a negative position is not a background-window guarantee.
        render_project = temp / "render-project/godot"
        shutil.copytree(ROOT / "godot", render_project, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns(".godot"))
        config = render_project / "project.godot"
        text = config.read_text(encoding="utf-8")
        text = re.sub(r"(?m)^window/(?:size/mode|flags/no_focus)=.*\n", "", text)
        text = text.replace("[display]", "[display]\nwindow/size/mode=1\nwindow/flags/no_focus=true", 1)
        config.write_text(text, encoding="utf-8")
        render_common = [str(engine), "--audio-driver", "Dummy", "--path", str(render_project)]
        run([*render_common, "--headless", "--import"], "render_import", logs, env, 600)
        env["ARK_RENDER_CAPTURE_ROOT"] = captures.as_posix()
        run([*render_common, *display, "--rendering-method", "gl_compatibility",
             "--resolution", "1440x900", "--quit-after", "10000", "--script", RENDER_SCRIPT],
            "ark_render_capture_test", logs, env, 600, "ARK_RENDER_CAPTURE_TEST_OK:")
        verify_captures(captures)
        for name, output_env, output_dir in [
                ("ark_gerstner_render_test", "ARK_GERSTNER_ARTIFACT_ROOT", ".tmp/gerstner-render"),
                ("ark_pixel_protagonist_render_test", "ARK_PIXEL_ARTIFACT_ROOT", ".tmp/pixel-render")]:
            env[output_env] = (ROOT / output_dir).as_posix()
            run([*render_common, *display, "--rendering-method", "gl_compatibility",
                 "--resolution", "64x64", "--quit-after", "10000", "--script", f"res://tests/{name}.gd"],
                name, logs, env, 600, name.upper() + "_OK:")
        emma_captures = ROOT / ".tmp/emma-preview"
        clear_emma_captures(emma_captures)
        env["ARK_EMMA_ARTIFACT_ROOT"] = emma_captures.as_posix()
        run([*render_common, *display, "--rendering-method", "gl_compatibility",
             "--resolution", "64x64", "--quit-after", "10000", "--script",
             "res://tests/ark_emma_protagonist_test.gd"],
            "ark_emma_protagonist_render", logs, env, 600, "ARK_EMMA_PROTAGONIST_TEST_OK:")
        verify_emma_captures(emma_captures)
        print(f"ARK_RENDER_VALIDATION_OK: menu/Ark, Gerstner geometry/normals, pixel and Emma presentation; {captures}")
        return 0
    run([sys.executable, "-X", "utf8", "-m", "unittest", "discover", "-s", "tools", "-p", "test_*.py"],
        "python_guards", logs, env, 600)
    for script, marker in (("verify_migration_surface.py", "MIGRATION_SURFACE_OK:"),
                           ("verify_source_archive.py", "SOURCE_ARCHIVE_OK:")):
        run([sys.executable, "-X", "utf8", str(ROOT / "tools" / script)], Path(script).stem, logs, env, 600, marker)
    headless = [*common, "--headless"]
    run([*headless, "--import"], "import", logs, env, 1200)
    run([*headless, "--quit-after", "5"], "main_smoke", logs, env, 120, "ARK_MENU_READY_OK:")
    scripts = regression_scripts()
    for script in scripts:
        name = Path(script).stem
        frames = 30000 if name in {"ark_world_travel_test", "ark_multifloor_risk_test"} else 10000 if name == "ark_mooring_test" else 6000
        run([*headless, "--quit-after", str(frames), "--script", script], name,
            logs, env, 900 if frames > 600 else 180, name.upper() + "_OK:")
    # Exported pack proof is portable and does not pretend Linux ran a Windows EXE.
    pack = temp / "ark-validation.pck"
    pack.unlink(missing_ok=True)
    run([*headless, "--export-pack", "Windows Desktop", str(pack)], "export_pack", logs, env, 600)
    count = verify_pack(pack)
    print(f"ARK_PACK_BOUNDARY_OK: {count} verified resource entries")
    run([str(engine), "--headless", "--audio-driver", "Dummy", "--main-pack", str(pack), "--quit-after", "5"],
        "packed_main_smoke", logs, env, 120, "ARK_MENU_READY_OK:", cwd=temp)
    packed_scene_smoke(engine, pack, logs, env, temp)
    print(f"GODOT_VALIDATION_OK: {version}; {len(scripts)} Ark regressions; exported pack + packed menu/3D/return; logs: {logs}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"GODOT_VALIDATION_FAILED: {error}", file=sys.stderr)
        raise SystemExit(2) from error
