#!/usr/bin/env python3
"""Fail closed on the bundled audio inventory and its measurable properties."""

from __future__ import annotations

import hashlib
import json
import math
import struct
import sys
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDIO_ROOT = ROOT / "godot" / "audio"
MANIFEST = AUDIO_ROOT / "audio_manifest_v1.json"
GENERATOR = ROOT / "tools" / "generate_audio_assets.py"
AUDIO_LICENSE = AUDIO_ROOT / "LICENSE-AUDIO.txt"
REQUIRED = {
    "ui_confirm", "ui_cancel", "card_cast", "impact", "guard", "stress",
    "heart_awaken", "elite_enter", "boss_enter", "phase_break", "victory",
    "defeat", "classical_ambience",
}
for _base_id in ("ui_confirm", "ui_cancel", "card_cast", "impact", "guard"):
    REQUIRED.update(f"{_base_id}_{number:02d}" for number in range(2, 5))


def dbfs(value: float) -> float:
    return 20.0 * math.log10(max(value, 1.0e-12))


def main() -> int:
    failures: list[str] = []
    if not MANIFEST.is_file():
        print(f"AUDIO_ASSET_VERIFICATION_FAILED: missing {MANIFEST}", file=sys.stderr)
        return 1
    try:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"AUDIO_ASSET_VERIFICATION_FAILED: invalid manifest: {error}", file=sys.stderr)
        return 1

    if manifest.get("version") != 1:
        failures.append("manifest version must be 1")
    if not AUDIO_LICENSE.is_file() or "GNU Affero General Public License v3.0-or-later" not in AUDIO_LICENSE.read_text(encoding="utf-8"):
        failures.append("project-original audio license notice is missing or incomplete")
    expected_generator_hash = hashlib.sha256(GENERATOR.read_bytes()).hexdigest().upper()
    if manifest.get("generator_sha256") != expected_generator_hash:
        failures.append("generator hash does not match tools/generate_audio_assets.py")

    entries = manifest.get("assets")
    if not isinstance(entries, list):
        failures.append("assets must be an array")
        entries = []
    ids = [entry.get("id") for entry in entries if isinstance(entry, dict)]
    if len(ids) != len(set(ids)):
        failures.append("asset ids are not unique")
    if set(ids) != REQUIRED:
        failures.append(f"asset id set differs from required vertical slice: {sorted(set(ids) ^ REQUIRED)}")

    entries_by_id = {str(entry.get("id", "")): entry for entry in entries if isinstance(entry, dict)}
    for base_id in ("ui_confirm", "ui_cancel", "card_cast", "impact", "guard"):
        variant_ids = [base_id] + [f"{base_id}_{number:02d}" for number in range(2, 5)]
        variant_hashes = {str(entries_by_id.get(asset_id, {}).get("sha256", "")) for asset_id in variant_ids}
        if len(variant_hashes) != 4 or "" in variant_hashes:
            failures.append(f"{base_id}: four high-frequency variants must have distinct content hashes")

    managed_paths: set[Path] = set()
    total_bytes = 0
    for entry in entries:
        if not isinstance(entry, dict):
            failures.append("manifest contains a non-object asset entry")
            continue
        asset_id = str(entry.get("id", ""))
        relative = str(entry.get("file", ""))
        if not relative or "\\" in relative or relative.startswith("/") or ".." in Path(relative).parts:
            failures.append(f"{asset_id}: unsafe runtime path {relative!r}")
            continue
        path = (AUDIO_ROOT / relative).resolve()
        if AUDIO_ROOT.resolve() not in path.parents:
            failures.append(f"{asset_id}: runtime path escapes audio root")
            continue
        managed_paths.add(path)
        if not path.is_file():
            failures.append(f"{asset_id}: file is missing: {relative}")
            continue
        total_bytes += path.stat().st_size
        actual_hash = hashlib.sha256(path.read_bytes()).hexdigest().upper()
        if actual_hash != str(entry.get("sha256", "")).upper():
            failures.append(f"{asset_id}: sha256 mismatch")
        if entry.get("license") != "LicenseRef-Project-Original":
            failures.append(f"{asset_id}: license must explicitly identify project-original work")
        if entry.get("asset_id") != asset_id or entry.get("runtime_path") != f"res://audio/{relative}":
            failures.append(f"{asset_id}: audit identity/runtime path metadata is inconsistent")
        if entry.get("era_ids") != ["classical"] or not isinstance(entry.get("event_ids"), list) or not entry["event_ids"]:
            failures.append(f"{asset_id}: era/event audit mapping is incomplete")
        if entry.get("commercial_use") is not True or entry.get("redistribution_in_game") is not True:
            failures.append(f"{asset_id}: commercial redistribution rights are not explicit")
        if not entry.get("creator_or_vendor") or not entry.get("generator_and_version") or not entry.get("created_or_acquired_at"):
            failures.append(f"{asset_id}: provenance metadata is incomplete")
        if entry.get("release_state") not in {"production_candidate", "final"}:
            failures.append(f"{asset_id}: invalid release state {entry.get('release_state')!r}")
        if entry.get("release_state") == "production_candidate" and entry.get("manual_qa_status") != "pending_multidevice_listening":
            failures.append(f"{asset_id}: candidate assets must state the pending manual QA gate")
        if entry.get("bus") not in {"Music", "Ambience", "SFX", "UI", "VO"}:
            failures.append(f"{asset_id}: invalid audio bus {entry.get('bus')!r}")
        validate_wav(path, entry, failures)
        validate_import_settings(path, entry, failures)

    unmanaged = {
        path.resolve()
        for path in AUDIO_ROOT.rglob("*")
        if path.is_file() and path.suffix.lower() in {".wav", ".ogg", ".mp3", ".flac"}
    } - managed_paths
    if unmanaged:
        failures.append("unmanaged runtime audio files: " + ", ".join(str(path.relative_to(ROOT)) for path in sorted(unmanaged)))
    mp3_files = list(AUDIO_ROOT.rglob("*.mp3"))
    if mp3_files:
        failures.append("MP3 is forbidden in runtime audio: " + ", ".join(str(path) for path in mp3_files))
    for script in (ROOT / "godot" / "scripts").rglob("*.gd"):
        if script.name != "audio_director.gd" and "AudioStreamPlayer" in script.read_text(encoding="utf-8"):
            failures.append(f"runtime player bypasses AudioDirector: {script.relative_to(ROOT)}")
    if total_bytes > 12 * 1024 * 1024:
        failures.append(f"classical vertical slice exceeds 12 MiB ({total_bytes} bytes)")

    if failures:
        for failure in failures:
            print(f"AUDIO_ASSET_VERIFICATION_FAILED: {failure}", file=sys.stderr)
        return 1
    print(
        "AUDIO_ASSET_VERIFICATION_OK: "
        f"{len(entries)} project-original 48 kHz stereo assets, hashes/levels/loop seam verified, "
        f"{total_bytes} bytes"
    )
    return 0


def validate_wav(path: Path, entry: dict, failures: list[str]) -> None:
    asset_id = str(entry.get("id", path.stem))
    try:
        with wave.open(str(path), "rb") as source:
            channels = source.getnchannels()
            sample_width = source.getsampwidth()
            sample_rate = source.getframerate()
            frame_count = source.getnframes()
            compression = source.getcomptype()
            raw = source.readframes(frame_count)
    except (wave.Error, OSError) as error:
        failures.append(f"{asset_id}: WAV decode failed: {error}")
        return
    if (channels, sample_width, sample_rate, compression) != (2, 2, 48_000, "NONE"):
        failures.append(
            f"{asset_id}: expected PCM 48 kHz/stereo/16-bit, got "
            f"{sample_rate} Hz/{channels} ch/{sample_width * 8} bit/{compression}"
        )
        return
    if entry.get("sample_rate") != sample_rate or entry.get("channels") != channels or entry.get("bits_per_sample") != 16:
        failures.append(f"{asset_id}: manifest format metadata differs from WAV header")
    duration = frame_count / sample_rate
    if abs(duration - float(entry.get("duration", -1.0))) > 1.0 / sample_rate:
        failures.append(f"{asset_id}: duration metadata differs from decoded frames")
    samples = struct.unpack(f"<{len(raw) // 2}h", raw)
    floats = [sample / 32768.0 for sample in samples]
    peak = max(abs(sample) for sample in floats)
    rms = math.sqrt(sum(sample * sample for sample in floats) / max(1, len(floats)))
    dc = abs(sum(floats) / max(1, len(floats)))
    peak_db = dbfs(peak)
    rms_db = dbfs(rms)
    if peak_db > -1.0 or peak_db < -18.0:
        failures.append(f"{asset_id}: peak {peak_db:.2f} dBFS is outside -18..-1 dBFS")
    if rms_db > -8.5 or rms_db < -42.0:
        failures.append(f"{asset_id}: RMS {rms_db:.2f} dBFS is outside -42..-8.5 dBFS")
    if dc > 0.002:
        failures.append(f"{asset_id}: DC offset {dc:.6f} exceeds 0.002")
    if abs(peak_db - float(entry.get("peak_dbfs", 999.0))) > 0.08:
        failures.append(f"{asset_id}: measured peak differs from manifest")
    if abs(rms_db - float(entry.get("rms_dbfs", 999.0))) > 0.08:
        failures.append(f"{asset_id}: measured RMS differs from manifest")

    left_first, right_first = floats[0], floats[1]
    left_last, right_last = floats[-2], floats[-1]
    boundary = max(abs(left_first - left_last), abs(right_first - right_last))
    if bool(entry.get("loop", False)):
        if entry.get("loop_start_sample") != 0 or entry.get("loop_end_sample") != frame_count:
            failures.append(f"{asset_id}: manifest loop sample range differs from decoded WAV")
        if boundary > 0.002:
            failures.append(f"{asset_id}: loop boundary delta {boundary:.7f} exceeds 0.002")
        if abs(boundary - float(entry.get("loop_boundary_delta", -1.0))) > 0.00008:
            failures.append(f"{asset_id}: loop boundary measurement differs from manifest")
        edge_frames = min(frame_count // 8, int(sample_rate * 0.05))
        edge_samples = floats[: edge_frames * channels] + floats[-edge_frames * channels :]
        edge_rms = math.sqrt(sum(sample * sample for sample in edge_samples) / len(edge_samples))
        if dbfs(edge_rms) < -45.0:
            failures.append(f"{asset_id}: loop edges contain an audible ambience dropout")
    elif max(abs(left_first), abs(right_first), abs(left_last), abs(right_last)) > 0.006:
        failures.append(f"{asset_id}: one-shot lacks a clean sub -44 dBFS head/tail boundary")
    elif entry.get("loop_start_sample") is not None or entry.get("loop_end_sample") is not None:
        failures.append(f"{asset_id}: one-shot must not declare loop sample points")


def validate_import_settings(path: Path, entry: dict, failures: list[str]) -> None:
    asset_id = str(entry.get("id", path.stem))
    sidecar = Path(str(path) + ".import")
    if not sidecar.is_file():
        failures.append(f"{asset_id}: Godot import sidecar is missing")
        return
    text = sidecar.read_text(encoding="utf-8")
    if 'importer="wav"' not in text or 'type="AudioStreamWAV"' not in text:
        failures.append(f"{asset_id}: import sidecar does not preserve WAV semantics")
    if "compress/mode=0" not in text:
        failures.append(f"{asset_id}: runtime import must remain lossless")
    if bool(entry.get("loop", False)):
        expected_end = round(float(entry["duration"]) * int(entry["sample_rate"]))
        if "edit/loop_mode=1" not in text or f"edit/loop_end={expected_end}" not in text:
            failures.append(f"{asset_id}: import loop points do not match the manifest sample boundary")


if __name__ == "__main__":
    raise SystemExit(main())
