#!/usr/bin/env python3
"""Fail closed on the bundled audio inventory and its measurable properties."""

from __future__ import annotations

import argparse
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
ERA_IDS = (
    "classical", "steam", "star_network", "wasteland", "final_age",
    "immortal_dynasty",
)
MUSIC_STATES = ("exploration", "pressure", "decisive")
MUSIC_DURATION = 64.0
SOUNDSCAPE_LOCATIONS = ("world", "dungeon")
SOUNDSCAPE_LAYERS = ("bed", "weather_points")
SOUNDSCAPE_DURATION = 64.0
MUSIC_ENCODE_ARGS_EXPECTED = (
    "-map_metadata", "-1", "-vn", "-c:a", "libvorbis", "-q:a", "4",
    "-ar", "48000", "-ac", "2", "-fflags", "+bitexact", "-flags:a", "+bitexact",
)
ERA_EVENT_BASES = ("card_cast", "impact", "guard")
ERA_LOW_FREQUENCY_BASES = (
    "stress", "heart_awaken", "elite_enter", "boss_enter", "phase_break",
    "victory", "defeat",
)
SHARED_EVENT_BASES = {"ui_confirm", "ui_cancel"}
REQUIRED = {
    "ui_confirm", "ui_cancel", "card_cast", "impact", "guard", "stress",
    "heart_awaken", "elite_enter", "boss_enter", "phase_break", "victory",
    "defeat", "classical_ambience",
}
for _base_id in ("ui_confirm", "ui_cancel", "card_cast", "impact", "guard"):
    REQUIRED.update(f"{_base_id}_{number:02d}" for number in range(2, 5))
for _era_id in ERA_IDS[1:]:
    REQUIRED.add(f"{_era_id}_ambience")
    for _base_id in ERA_EVENT_BASES:
        REQUIRED.add(f"{_era_id}_{_base_id}")
        REQUIRED.update(f"{_era_id}_{_base_id}_{number:02d}" for number in range(2, 5))
    REQUIRED.update(f"{_era_id}_{base_id}" for base_id in ERA_LOW_FREQUENCY_BASES)
for _era_id in ERA_IDS:
    REQUIRED.update(f"{_era_id}_music_{state}" for state in MUSIC_STATES)
    REQUIRED.add(f"{_era_id}_dungeon_ambience")
    REQUIRED.add(f"{_era_id}_world_detail")
    REQUIRED.add(f"{_era_id}_dungeon_detail")


def dbfs(value: float) -> float:
    return 20.0 * math.log10(max(value, 1.0e-12))


def main(require_final: bool = False) -> int:
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
    music_sync = manifest.get("music_sync", {})
    if not isinstance(music_sync, dict) or music_sync != {
        "duration_seconds": MUSIC_DURATION,
        "sample_rate": 48_000,
        "tempo_bpm": 120,
        "bar_beats": 4,
        "bar_count": 32,
        "states": list(MUSIC_STATES),
    }:
        failures.append("music sync contract must pin the shared 64-second/120 BPM form")
    soundscape_contract = manifest.get("soundscape_contract", {})
    if not isinstance(soundscape_contract, dict) or soundscape_contract != {
        "duration_seconds": SOUNDSCAPE_DURATION,
        "sample_rate": 48_000,
        "locations": list(SOUNDSCAPE_LOCATIONS),
        "layers": list(SOUNDSCAPE_LAYERS),
        "per_era_asset_count": 4,
    }:
        failures.append("soundscape contract must pin two locations and two 64-second layers per era")
    stream_encoder = manifest.get("stream_encoder", {})
    if (not isinstance(stream_encoder, dict) or
            stream_encoder.get("archive_sha256") != "985B3477E9A07399675F5923DCFDF57BAE41B3EC0A7B2AD61D9BE5E2DA30C6B3" or
            stream_encoder.get("numpy_version") != "2.3.3" or
            not str(stream_encoder.get("version", "")).startswith("ffmpeg version n7.1") or
            not str(stream_encoder.get("executable_sha256", ""))):
        failures.append("stream encoder provenance is missing or differs from the pinned toolchain")

    entries = manifest.get("assets")
    if not isinstance(entries, list):
        failures.append("assets must be an array")
        entries = []
    ids = [entry.get("id") for entry in entries if isinstance(entry, dict)]
    if len(ids) != len(set(ids)):
        failures.append("asset ids are not unique")
    if set(ids) != REQUIRED:
        failures.append(f"asset id set differs from required six-era runtime set: {sorted(set(ids) ^ REQUIRED)}")

    entries_by_id = {str(entry.get("id", "")): entry for entry in entries if isinstance(entry, dict)}
    for base_id in ("ui_confirm", "ui_cancel", "card_cast", "impact", "guard"):
        variant_ids = [base_id] + [f"{base_id}_{number:02d}" for number in range(2, 5)]
        variant_hashes = {str(entries_by_id.get(asset_id, {}).get("sha256", "")) for asset_id in variant_ids}
        if len(variant_hashes) != 4 or "" in variant_hashes:
            failures.append(f"{base_id}: four high-frequency variants must have distinct content hashes")
    for era_id in ERA_IDS:
        for base_id in ERA_EVENT_BASES:
            prefix = "" if era_id == "classical" else f"{era_id}_"
            variant_ids = [f"{prefix}{base_id}"] + [
                f"{prefix}{base_id}_{number:02d}" for number in range(2, 5)
            ]
            variant_hashes = {
                str(entries_by_id.get(asset_id, {}).get("sha256", ""))
                for asset_id in variant_ids
            }
            if len(variant_hashes) != 4 or "" in variant_hashes:
                failures.append(
                    f"{era_id}/{base_id}: four era variants must have distinct content hashes"
                )
    ambience_hashes = {
        str(entries_by_id.get(
            "classical_ambience" if era_id == "classical" else f"{era_id}_ambience", {}
        ).get("sha256", ""))
        for era_id in ERA_IDS
    }
    if len(ambience_hashes) != len(ERA_IDS) or "" in ambience_hashes:
        failures.append("six era ambience beds must have distinct content hashes")
    soundscape_hashes: set[str] = set()
    for era_id in ERA_IDS:
        soundscape_ids = [
            "classical_ambience" if era_id == "classical" else f"{era_id}_ambience",
            f"{era_id}_world_detail",
            f"{era_id}_dungeon_ambience",
            f"{era_id}_dungeon_detail",
        ]
        era_hashes = {
            str(entries_by_id.get(asset_id, {}).get("sha256", ""))
            for asset_id in soundscape_ids
        }
        if len(era_hashes) != 4 or "" in era_hashes:
            failures.append(f"{era_id}: four location/layer soundscapes must be distinct")
        soundscape_hashes.update(era_hashes)
    if len(soundscape_hashes) != len(ERA_IDS) * 4 or "" in soundscape_hashes:
        failures.append("all 24 six-era soundscapes must have distinct content hashes")
    for era_id in ERA_IDS:
        state_hashes = {
            str(entries_by_id.get(f"{era_id}_music_{state}", {}).get("sha256", ""))
            for state in MUSIC_STATES
        }
        if len(state_hashes) != len(MUSIC_STATES) or "" in state_hashes:
            failures.append(f"{era_id}: exploration/pressure/decisive music must be distinct")
    for state in MUSIC_STATES:
        era_hashes = {
            str(entries_by_id.get(f"{era_id}_music_{state}", {}).get("sha256", ""))
            for era_id in ERA_IDS
        }
        if len(era_hashes) != len(ERA_IDS) or "" in era_hashes:
            failures.append(f"music/{state}: all six era compositions must be distinct")
    for base_id in ERA_EVENT_BASES:
        for suffix in ("", "_02", "_03", "_04"):
            era_hashes = {
                str(entries_by_id.get(
                    f"{'' if era_id == 'classical' else era_id + '_'}{base_id}{suffix}", {}
                ).get("sha256", ""))
                for era_id in ERA_IDS
            }
            if len(era_hashes) != len(ERA_IDS) or "" in era_hashes:
                failures.append(f"{base_id}{suffix}: all six era materials must be distinct")
    for base_id in ERA_LOW_FREQUENCY_BASES:
        era_hashes = {
            str(entries_by_id.get(
                f"{'' if era_id == 'classical' else era_id + '_'}{base_id}", {}
            ).get("sha256", ""))
            for era_id in ERA_IDS
        }
        if len(era_hashes) != len(ERA_IDS) or "" in era_hashes:
            failures.append(f"{base_id}: all six rare-event materials must be distinct")

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
        era_ids = entry.get("era_ids")
        if (not isinstance(era_ids, list) or not era_ids or
                any(era_id not in ERA_IDS for era_id in era_ids) or
                not isinstance(entry.get("event_ids"), list) or not entry["event_ids"]):
            failures.append(f"{asset_id}: era/event audit mapping is incomplete")
        if entry.get("commercial_use") is not True or entry.get("redistribution_in_game") is not True:
            failures.append(f"{asset_id}: commercial redistribution rights are not explicit")
        if not entry.get("creator_or_vendor") or not entry.get("generator_and_version") or not entry.get("created_or_acquired_at"):
            failures.append(f"{asset_id}: provenance metadata is incomplete")
        if entry.get("release_state") not in {"production_candidate", "final"}:
            failures.append(f"{asset_id}: invalid release state {entry.get('release_state')!r}")
        if entry.get("release_state") == "production_candidate" and entry.get("manual_qa_status") != "pending_multidevice_listening":
            failures.append(f"{asset_id}: candidate assets must state the pending manual QA gate")
        if entry.get("release_state") == "final" and entry.get("manual_qa_status") not in {
            "owner_post_release_playtest", "passed_multidevice_listening"
        }:
            failures.append(f"{asset_id}: final asset lacks the declared playtest policy")
        if require_final and entry.get("release_state") != "final":
            failures.append(
                f"{asset_id}: product release requires final state"
            )
        if entry.get("bus") not in {"Music", "Ambience", "SFX", "UI", "VO"}:
            failures.append(f"{asset_id}: invalid audio bus {entry.get('bus')!r}")
        if path.suffix.lower() == ".wav":
            validate_wav(path, entry, failures)
        elif path.suffix.lower() == ".ogg":
            validate_ogg(path, entry, failures)
        else:
            failures.append(f"{asset_id}: unsupported runtime format {path.suffix}")
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
    for era_id in ERA_IDS:
        ambience_id = "classical_ambience" if era_id == "classical" else f"{era_id}_ambience"
        ambience = entries_by_id.get(ambience_id, {})
        if (ambience.get("era_ids") != [era_id] or ambience.get("role") != "ambience" or
                ambience.get("soundscape_location") != "world" or
                ambience.get("soundscape_layer") != "bed"):
            failures.append(f"{era_id}: dedicated ambience mapping is missing")
        for location in SOUNDSCAPE_LOCATIONS:
            for layer in SOUNDSCAPE_LAYERS:
                if location == "world" and layer == "bed":
                    soundscape_id = ambience_id
                elif layer == "bed":
                    soundscape_id = f"{era_id}_dungeon_ambience"
                else:
                    soundscape_id = f"{era_id}_{location}_detail"
                soundscape = entries_by_id.get(soundscape_id, {})
                expected_role = "ambience" if layer == "bed" else "ambience_detail"
                if (soundscape.get("era_ids") != [era_id] or
                        soundscape.get("role") != expected_role or
                        soundscape.get("bus") != "Ambience" or
                        soundscape.get("soundscape_location") != location or
                        soundscape.get("soundscape_layer") != layer):
                    failures.append(
                        f"{era_id}: {location}/{layer} soundscape mapping is incomplete"
                    )
        for base_id in ERA_EVENT_BASES:
            prefix = "" if era_id == "classical" else f"{era_id}_"
            for suffix in ("", "_02", "_03", "_04"):
                entry = entries_by_id.get(f"{prefix}{base_id}{suffix}", {})
                if entry.get("era_ids") != [era_id]:
                    failures.append(f"{era_id}: {base_id}{suffix} is not era-exclusive")
        for base_id in ERA_LOW_FREQUENCY_BASES:
            prefix = "" if era_id == "classical" else f"{era_id}_"
            entry = entries_by_id.get(f"{prefix}{base_id}", {})
            if entry.get("era_ids") != [era_id]:
                failures.append(f"{era_id}: {base_id} rare cue is not era-exclusive")
        for state in MUSIC_STATES:
            music = entries_by_id.get(f"{era_id}_music_{state}", {})
            if (music.get("era_ids") != [era_id] or music.get("role") != "music" or
                    music.get("bus") != "Music" or music.get("music_state") != state or
                    music.get("event_ids") != [f"music.{state}"]):
                failures.append(f"{era_id}: dedicated {state} music mapping is incomplete")
    for base_id in SHARED_EVENT_BASES:
        entry = entries_by_id.get(base_id, {})
        if entry.get("era_ids") != list(ERA_IDS):
            failures.append(f"{base_id}: shared UI base must declare all six eras")
    for base_id in ("ui_confirm", "ui_cancel"):
        for suffix in ("", "_02", "_03", "_04"):
            entry = entries_by_id.get(f"{base_id}{suffix}", {})
            if entry.get("era_ids") != list(ERA_IDS):
                failures.append(f"{base_id}{suffix}: shared UI mapping must declare all six eras")
    if total_bytes > 80 * 1024 * 1024:
        failures.append(f"six-era runtime audio exceeds 80 MiB ({total_bytes} bytes)")

    if failures:
        for failure in failures:
            print(f"AUDIO_ASSET_VERIFICATION_FAILED: {failure}", file=sys.stderr)
        return 1
    print(
        "AUDIO_ASSET_VERIFICATION_OK: "
        f"{len(entries)} project-original six-era 48 kHz stereo assets, including 18 synchronized music loops and "
        "24 two-location layered soundscapes plus 42 era-exclusive rare-event cues, "
        "hashes/levels/loop seams verified, "
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


def parse_ogg_vorbis(path: Path) -> dict:
    """Parse Ogg pages and the Vorbis identification header without a codec DLL."""
    data = path.read_bytes()
    position = 0
    packets: list[bytes] = []
    packet = bytearray()
    serial: int | None = None
    expected_sequence = 0
    last_granule: int | None = None
    page_count = 0
    saw_bos = False
    saw_eos = False
    while position < len(data):
        if position + 27 > len(data) or data[position:position + 4] != b"OggS":
            raise ValueError(f"invalid Ogg capture pattern at byte {position}")
        version = data[position + 4]
        header_type = data[position + 5]
        granule = struct.unpack_from("<Q", data, position + 6)[0]
        page_serial = struct.unpack_from("<I", data, position + 14)[0]
        sequence = struct.unpack_from("<I", data, position + 18)[0]
        segment_count = data[position + 26]
        header_end = position + 27 + segment_count
        if version != 0 or header_end > len(data):
            raise ValueError(f"invalid Ogg page header at byte {position}")
        lacing = data[position + 27:header_end]
        body_end = header_end + sum(lacing)
        if body_end > len(data):
            raise ValueError(f"truncated Ogg page body at byte {position}")
        if serial is None:
            serial = page_serial
        elif page_serial != serial:
            raise ValueError("chained or multiplexed Ogg streams are not allowed")
        if sequence != expected_sequence:
            raise ValueError(f"Ogg page sequence jumped from {expected_sequence} to {sequence}")
        if page_count == 0:
            saw_bos = bool(header_type & 0x02)
        if bool(packet) != bool(header_type & 0x01):
            raise ValueError("Ogg continued-packet flag is inconsistent")
        saw_eos = saw_eos or bool(header_type & 0x04)
        cursor = header_end
        for length in lacing:
            packet.extend(data[cursor:cursor + length])
            cursor += length
            if length < 255:
                packets.append(bytes(packet))
                packet.clear()
        if granule != 0xFFFFFFFFFFFFFFFF:
            last_granule = granule
        position = body_end
        page_count += 1
        expected_sequence += 1
    if position != len(data) or packet:
        raise ValueError("Ogg stream ended with an incomplete packet")
    if not packets or len(packets[0]) < 30 or packets[0][:7] != b"\x01vorbis":
        raise ValueError("Vorbis identification packet is missing")
    identification = packets[0]
    codec_version = struct.unpack_from("<I", identification, 7)[0]
    channels = identification[11]
    sample_rate = struct.unpack_from("<I", identification, 12)[0]
    if codec_version != 0 or not (identification[29] & 0x01):
        raise ValueError("unsupported or malformed Vorbis identification packet")
    if last_granule is None:
        raise ValueError("Ogg stream has no PCM granule position")
    return {
        "channels": channels,
        "sample_rate": sample_rate,
        "frame_count": last_granule,
        "page_count": page_count,
        "bos": saw_bos,
        "eos": saw_eos,
    }


def validate_ogg(path: Path, entry: dict, failures: list[str]) -> None:
    asset_id = str(entry.get("id", path.stem))
    try:
        info = parse_ogg_vorbis(path)
    except (OSError, ValueError, struct.error) as error:
        failures.append(f"{asset_id}: Ogg/Vorbis parse failed: {error}")
        return
    channels = int(info["channels"])
    sample_rate = int(info["sample_rate"])
    frame_count = int(info["frame_count"])
    if channels != 2 or sample_rate != 48_000:
        failures.append(f"{asset_id}: expected Vorbis 48 kHz/stereo, got {sample_rate} Hz/{channels} ch")
    if not info["bos"] or not info["eos"] or int(info["page_count"]) < 3:
        failures.append(f"{asset_id}: Ogg stream lacks complete BOS/EOS page structure")
    duration = frame_count / max(1, sample_rate)
    if abs(duration - float(entry.get("duration", -1.0))) > 2.0 / max(1, sample_rate):
        failures.append(f"{asset_id}: final Ogg granule differs from manifest duration")
    if (entry.get("sample_rate") != sample_rate or entry.get("channels") != channels or
            entry.get("bits_per_sample") is not None or entry.get("codec") != "vorbis" or
            entry.get("container") != "ogg" or entry.get("streaming") is not True):
        failures.append(f"{asset_id}: Ogg/Vorbis streaming metadata is inconsistent")
    if (entry.get("loop") is not True or entry.get("loop_start_sample") != 0 or
            entry.get("loop_end_sample") != frame_count):
        failures.append(f"{asset_id}: Ogg loop range differs from final PCM granule")
    kind = entry.get("kind")
    if kind == "music":
        if entry.get("music_state") not in MUSIC_STATES or entry.get("bus") != "Music":
            failures.append(f"{asset_id}: Ogg music asset lacks a registered state")
    elif kind == "soundscape":
        if (entry.get("soundscape_location") not in SOUNDSCAPE_LOCATIONS or
                entry.get("soundscape_layer") not in SOUNDSCAPE_LAYERS or
                entry.get("bus") != "Ambience"):
            failures.append(f"{asset_id}: Ogg soundscape lacks a registered location/layer")
    else:
        failures.append(f"{asset_id}: Ogg runtime asset has unsupported kind {kind!r}")
    if float(entry.get("duration", 0.0)) < 60.0:
        failures.append(f"{asset_id}: product long-form loop is shorter than one minute")
    peak_db = float(entry.get("peak_dbfs", 999.0))
    rms_db = float(entry.get("rms_dbfs", 999.0))
    dc = abs(float(entry.get("source_dc_offset", 999.0)))
    boundary = abs(float(entry.get("loop_boundary_delta", 999.0)))
    if peak_db > -1.0 or peak_db < -18.0:
        failures.append(f"{asset_id}: source-master peak {peak_db:.2f} dBFS is outside -18..-1 dBFS")
    if rms_db > -8.5 or rms_db < -42.0:
        failures.append(f"{asset_id}: source-master RMS {rms_db:.2f} dBFS is outside -42..-8.5 dBFS")
    if dc > 0.002:
        failures.append(f"{asset_id}: source-master DC offset {dc:.6f} exceeds 0.002")
    if boundary > 0.002:
        failures.append(f"{asset_id}: source-master loop boundary delta {boundary:.7f} exceeds 0.002")
    if (not entry.get("source_master_sha256") or
            not str(entry.get("encoder_and_version", "")).startswith("ffmpeg version n7.1") or
            not entry.get("encoder_executable_sha256") or
            entry.get("encoding_parameters") != list(MUSIC_ENCODE_ARGS_EXPECTED)):
        failures.append(f"{asset_id}: reproducible source/encoder audit metadata is incomplete")


def validate_import_settings(path: Path, entry: dict, failures: list[str]) -> None:
    asset_id = str(entry.get("id", path.stem))
    sidecar = Path(str(path) + ".import")
    if not sidecar.is_file():
        failures.append(f"{asset_id}: Godot import sidecar is missing")
        return
    text = sidecar.read_text(encoding="utf-8")
    if path.suffix.lower() == ".wav":
        if 'importer="wav"' not in text or 'type="AudioStreamWAV"' not in text:
            failures.append(f"{asset_id}: import sidecar does not preserve WAV semantics")
        if "compress/mode=0" not in text:
            failures.append(f"{asset_id}: runtime import must remain lossless")
        if bool(entry.get("loop", False)):
            expected_end = round(float(entry["duration"]) * int(entry["sample_rate"]))
            if "edit/loop_mode=1" not in text or f"edit/loop_end={expected_end}" not in text:
                failures.append(f"{asset_id}: import loop points do not match the manifest sample boundary")
    elif path.suffix.lower() == ".ogg":
        if 'importer="oggvorbisstr"' not in text or 'type="AudioStreamOggVorbis"' not in text:
            failures.append(f"{asset_id}: import sidecar does not preserve streamable Ogg/Vorbis semantics")
        if "loop=true" not in text or "loop_offset=0" not in text:
            failures.append(f"{asset_id}: imported music must retain an exact zero-offset loop")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--require-final", action="store_true",
        help="Reject prototype and production-candidate assets from product builds.",
    )
    arguments = parser.parse_args()
    raise SystemExit(main(require_final=arguments.require_final))
