#!/usr/bin/env python3
"""Validate the curated, manifest-driven runtime audio set.

The checker intentionally parses Ogg/Vorbis container metadata itself so CI does
not need FFmpeg or a platform audio decoder. Retired procedural audio is not
allowed to remain in the product source tree.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDIO_ROOT = ROOT / "godot" / "audio"
MANIFEST = AUDIO_ROOT / "audio_manifest_v2.json"
AUDIO_LICENSE = AUDIO_ROOT / "LICENSE-AUDIO.txt"
CURATED_DIRS = (AUDIO_ROOT / "music", AUDIO_ROOT / "ambience", AUDIO_ROOT / "sfx")
MUSIC_STATES = ("exploration", "pressure", "decisive")
SOUNDSCAPE_LOCATIONS = ("world", "dungeon")
CORE_EVENT_CATEGORIES = {
    "combat.impact": "weapon_impact",
    "dungeon.impact": "weapon_impact",
    "combat.guard": "shield_guard",
    "dungeon.guard": "shield_guard",
    "combat.spell": "spell_cast",
    "combat.recover": "recovery",
    "combat.heal": "recovery",
    "dungeon.heart": "recovery",
    "combat.status": "status",
    "dungeon.stress": "status",
    "dungeon.phase_break": "phase_change",
    "dungeon.victory": "victory",
    "combat.victory": "victory",
    "dungeon.defeat": "defeat",
    "combat.defeat": "defeat",
}
DISJOINT_CATEGORIES = (
    "weapon_impact", "shield_guard", "spell_cast", "recovery", "status",
    "phase_change", "victory", "defeat",
)
ALLOWED_LICENSES = {
    "CC0-1.0",
    "CC-BY-3.0",
    "CC-BY-4.0",
    "CC-BY-SA-3.0",
    "LicenseRef-Project-Original",
}
FORBIDDEN_RUNTIME_EXTENSIONS = {".mp3", ".flac", ".wav", ".zip", ".7z", ".rar", ".tar", ".gz"}


def _is_hex_digest(value: object) -> bool:
    text = str(value or "")
    if len(text) != 64:
        return False
    try:
        int(text, 16)
    except ValueError:
        return False
    return True


def _inside(parent: Path, child: Path) -> bool:
    parent = parent.resolve()
    child = child.resolve()
    return child != parent and parent in child.parents


def _disk_path_from_runtime(runtime_path: str) -> Path | None:
    prefix = "res://audio/"
    if not runtime_path.startswith(prefix):
        return None
    relative = runtime_path[len(prefix):]
    if not relative or "\\" in relative or relative.startswith("/"):
        return None
    candidate = (AUDIO_ROOT / relative).resolve()
    return candidate if _inside(AUDIO_ROOT, candidate) else None


def main(require_final: bool = False) -> int:
    failures: list[str] = []
    if not MANIFEST.is_file():
        return _fail([f"missing manifest: {MANIFEST}"])
    try:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return _fail([f"invalid manifest JSON: {error}"])
    if not isinstance(manifest, dict):
        return _fail(["manifest root must be an object"])

    if manifest.get("version") != 2:
        failures.append("manifest version must be 2")
    if manifest.get("schema") != "curated-audio-v2":
        failures.append("manifest schema must be curated-audio-v2")
    whitelist = manifest.get("license_whitelist")
    if not isinstance(whitelist, list) or not ALLOWED_LICENSES.issubset(set(whitelist)):
        failures.append("manifest license whitelist is incomplete")
    if not AUDIO_LICENSE.is_file():
        failures.append("audio license notice is missing")
    else:
        license_text = AUDIO_LICENSE.read_text(encoding="utf-8", errors="replace")
        for marker in ("CC BY-SA 3.0", "CC0", "Kenney", "OpenGameArt"):
            if marker not in license_text:
                failures.append(f"audio license notice is missing attribution marker: {marker}")

    raw_entries = manifest.get("assets")
    if not isinstance(raw_entries, list):
        failures.append("assets must be an array")
        raw_entries = []
    entries = [entry for entry in raw_entries if isinstance(entry, dict)]
    if len(entries) != len(raw_entries):
        failures.append("manifest contains a non-object asset entry")
    entries_by_id: dict[str, dict] = {}
    managed_paths: set[Path] = set()
    runtime_paths: set[Path] = set()
    total_bytes = 0
    music_count = 0
    ambience_count = 0
    kenney_sfx_count = 0

    for entry in entries:
        asset_id = str(entry.get("id", ""))
        if not asset_id or asset_id in entries_by_id:
            failures.append(f"asset IDs must be non-empty and unique: {asset_id!r}")
            continue
        entries_by_id[asset_id] = entry
        runtime_path = str(entry.get("runtime_path", ""))
        disk_path = _disk_path_from_runtime(runtime_path)
        relative_file = str(entry.get("file", ""))
        expected_runtime = f"res://audio/{relative_file}" if relative_file else ""
        if disk_path is None or expected_runtime != runtime_path:
            failures.append(f"{asset_id}: unsafe or inconsistent runtime path")
            continue
        if disk_path in runtime_paths:
            failures.append(f"{asset_id}: runtime path is duplicated")
        runtime_paths.add(disk_path)
        managed_paths.add(disk_path)
        if not disk_path.is_file():
            failures.append(f"{asset_id}: runtime file is missing: {relative_file}")
            continue
        total_bytes += disk_path.stat().st_size
        actual_hash = hashlib.sha256(disk_path.read_bytes()).hexdigest().upper()
        if actual_hash != str(entry.get("sha256", "")).upper():
            failures.append(f"{asset_id}: runtime SHA-256 mismatch")
        if disk_path.suffix.lower() != ".ogg":
            failures.append(f"{asset_id}: curated runtime files must be Ogg Vorbis")
        if entry.get("license_spdx") not in ALLOWED_LICENSES:
            failures.append(f"{asset_id}: license is not on the approved whitelist")
        license_file = _disk_path_from_runtime(str(entry.get("license_file", "")))
        if license_file is None or not _inside(AUDIO_ROOT / "licenses", license_file) or not license_file.is_file():
            failures.append(f"{asset_id}: per-source license file is missing or outside audio/licenses")
        if not _is_hex_digest(entry.get("source_sha256")):
            failures.append(f"{asset_id}: source_sha256 must be a 64-character digest")
        if not _is_hex_digest(entry.get("sha256")):
            failures.append(f"{asset_id}: sha256 must be a 64-character digest")
        if not str(entry.get("source_url", "")).startswith("https://"):
            failures.append(f"{asset_id}: source_url must use HTTPS")
        for required in ("creator", "attribution_text", "modifications"):
            if not str(entry.get(required, "")).strip():
                failures.append(f"{asset_id}: provenance field is empty: {required}")
        if entry.get("commercial_use") is not True or entry.get("redistribution_in_game") is not True:
            failures.append(f"{asset_id}: commercial and in-game redistribution rights must be explicit")
        if entry.get("release_state") not in {"candidate", "production_candidate", "final"}:
            failures.append(f"{asset_id}: invalid release_state {entry.get('release_state')!r}")
        if require_final and entry.get("release_state") != "final":
            failures.append(f"{asset_id}: --require-final rejects non-final assets")
        if entry.get("bus") not in {"Music", "Ambience", "SFX", "UI", "VO"}:
            failures.append(f"{asset_id}: invalid audio bus")
        if entry.get("streaming") is not True:
            failures.append(f"{asset_id}: streaming must be true")
        if entry.get("loop") is True:
            if entry.get("loop_start_sample") != 0:
                failures.append(f"{asset_id}: loop_start_sample must be zero")
        elif entry.get("loop_start_sample") is not None or entry.get("loop_end_sample") is not None:
            failures.append(f"{asset_id}: non-loop asset must have null loop points")

        role = str(entry.get("role", ""))
        kind = str(entry.get("kind", ""))
        if role == "music":
            music_count += 1
            if kind != "music" or entry.get("bus") != "Music":
                failures.append(f"{asset_id}: music role/kind/bus mapping is inconsistent")
            if entry.get("loop") is not False:
                failures.append(f"{asset_id}: music must be non-looping")
            if float(entry.get("duration", 0.0)) <= 90.0:
                failures.append(f"{asset_id}: product music track is unexpectedly short")
            if not (-20.0 <= float(entry.get("integrated_lufs", 999.0)) <= -14.0):
                failures.append(f"{asset_id}: music loudness is outside the -20..-14 LUFS-I target")
            if float(entry.get("true_peak_dbtp", 999.0)) > -1.0:
                failures.append(f"{asset_id}: music true peak exceeds -1 dBTP")
        elif role == "ambience":
            ambience_count += 1
            if kind != "soundscape" or entry.get("bus") != "Ambience" or entry.get("loop") is not True:
                failures.append(f"{asset_id}: ambience role/kind/bus/loop mapping is inconsistent")
        elif kind == "sfx":
            if entry.get("bus") not in {"SFX", "UI"}:
                failures.append(f"{asset_id}: SFX must use SFX or UI bus")
            if str(entry.get("creator", "")) == "Kenney":
                kenney_sfx_count += 1
                if not str(entry.get("source_package_id", "")).strip():
                    failures.append(f"{asset_id}: Kenney source_package_id is missing")
                if not _is_hex_digest(entry.get("source_archive_sha256")):
                    failures.append(f"{asset_id}: Kenney source archive hash is missing")
            semantic_category = str(entry.get("semantic_category", ""))
            if semantic_category:
                for measurement in (
                    "duration", "peak_dbfs", "rms_dbfs", "crest_factor_db",
                    "spectral_centroid_hz",
                ):
                    if not isinstance(entry.get(measurement), (int, float)):
                        failures.append(f"{asset_id}: semantic SFX measurement is missing: {measurement}")
                if float(entry.get("duration", 0.0)) <= 0.05:
                    failures.append(f"{asset_id}: semantic SFX is unexpectedly short")
                if "impactpunch" in str(entry.get("source_file", "")).lower():
                    failures.append(f"{asset_id}: retired generic punch source is forbidden")
        else:
            failures.append(f"{asset_id}: unsupported role/kind mapping")

        if disk_path.is_file():
            validate_ogg(disk_path, entry, failures)
            validate_import_settings(disk_path, entry, failures)

    if music_count < 6:
        failures.append("curated runtime requires at least six music tracks")
    if ambience_count < 2:
        failures.append("curated runtime requires at least two curated ambience loops")
    if not 24 <= kenney_sfx_count <= 32:
        failures.append(f"curated runtime requires 24-32 selected Kenney SFX, found {kenney_sfx_count}")

    _validate_source_packages(manifest, entries_by_id, failures)
    _validate_playlists(manifest, entries_by_id, failures)
    _validate_events(manifest, entries_by_id, failures)
    _validate_soundscapes(manifest, entries_by_id, failures)
    _validate_curated_inventory(managed_paths, failures)
    _validate_legacy_boundary(manifest, failures)
    if total_bytes > 80 * 1024 * 1024:
        failures.append(f"curated runtime audio exceeds 80 MiB ({total_bytes} bytes)")

    if failures:
        return _fail(failures)
    print(
        "AUDIO_ASSET_VERIFICATION_OK: "
        f"manifest v2, {len(entries)} curated Ogg assets ({music_count} music, "
        f"{ambience_count} ambience, {kenney_sfx_count} Kenney SFX), "
        f"{total_bytes} bytes; legacy generated assets explicitly excluded"
    )
    return 0


def _validate_playlists(manifest: dict, entries: dict[str, dict], failures: list[str]) -> None:
    playlists = manifest.get("music_playlists")
    if not isinstance(playlists, dict):
        failures.append("music_playlists must be an object")
        return
    minimum_variants = {
        "exploration": 3,
        "pressure": 3,
        "decisive": 2,
    }
    for state in MUSIC_STATES:
        asset_ids = playlists.get(state)
        if not isinstance(asset_ids, list) or not asset_ids:
            failures.append(f"music playlist is empty or missing: {state}")
            continue
        minimum = minimum_variants.get(state, 1)
        if len(asset_ids) < minimum:
            failures.append(f"music playlist needs at least {minimum} variants: {state}")
        for asset_id_value in asset_ids:
            asset_id = str(asset_id_value)
            entry = entries.get(asset_id)
            if entry is None or entry.get("role") != "music":
                failures.append(f"playlist {state} references an unknown/non-music asset: {asset_id}")
            elif state not in (entry.get("playlist_ids") or []):
                failures.append(f"playlist membership is not reciprocal: {state}/{asset_id}")


def _validate_events(manifest: dict, entries: dict[str, dict], failures: list[str]) -> None:
    events = manifest.get("events")
    if not isinstance(events, dict):
        failures.append("events must be an object")
        return
    for event_id, event in events.items():
        if not isinstance(event, dict):
            failures.append(f"event must be an object: {event_id}")
            continue
        asset_ids = event.get("asset_ids")
        if not isinstance(asset_ids, list) or not asset_ids:
            failures.append(f"event has no asset variants: {event_id}")
            continue
        if event.get("bus") not in {"SFX", "UI", "VO"}:
            failures.append(f"event has invalid bus: {event_id}")
        expected_category = CORE_EVENT_CATEGORIES.get(event_id)
        if expected_category and event.get("semantic_category") != expected_category:
            failures.append(
                f"event semantic category mismatch: {event_id} must be {expected_category}"
            )
        for asset_id_value in asset_ids:
            asset_id = str(asset_id_value)
            entry = entries.get(asset_id)
            if entry is None:
                failures.append(f"event references unknown asset: {event_id}/{asset_id}")
            elif event_id not in (entry.get("event_ids") or []):
                failures.append(f"event membership is not reciprocal: {event_id}/{asset_id}")
            elif expected_category and entry.get("semantic_category") != expected_category:
                failures.append(
                    f"event/asset semantic category mismatch: {event_id}/{asset_id}"
                )
            elif expected_category and float(entry.get("peak_dbfs", 99.0)) + float(event.get("gain_db", 0.0)) > -1.0:
                failures.append(f"event gain has insufficient digital headroom: {event_id}/{asset_id}")

    minimum_variants = {
        "ui.confirm": 3,
        "ui.cancel": 3,
        "dungeon.card": 3,
        "combat.impact": 3,
        "combat.guard": 3,
        "combat.spell": 3,
        "combat.recover": 2,
        "combat.status": 2,
    }
    for event_id, minimum in minimum_variants.items():
        event = events.get(event_id, {})
        if len(event.get("asset_ids", [])) < minimum:
            failures.append(f"event needs at least {minimum} semantic variants: {event_id}")

    assets_by_category: dict[str, set[str]] = {category: set() for category in DISJOINT_CATEGORIES}
    for event_id, expected_category in CORE_EVENT_CATEGORIES.items():
        event = events.get(event_id, {})
        assets_by_category[expected_category].update(str(value) for value in event.get("asset_ids", []))
    for index, left in enumerate(DISJOINT_CATEGORIES):
        if not assets_by_category[left]:
            failures.append(f"semantic audio category has no mapped assets: {left}")
        for right in DISJOINT_CATEGORIES[index + 1:]:
            overlap = assets_by_category[left] & assets_by_category[right]
            if overlap:
                failures.append(
                    f"semantic audio categories must not share assets: {left}/{right}: {sorted(overlap)}"
                )

    semantic_hashes: dict[str, str] = {}
    for asset_ids in assets_by_category.values():
        for asset_id in asset_ids:
            digest = str(entries.get(asset_id, {}).get("sha256", "")).upper()
            previous = semantic_hashes.get(digest)
            if digest and previous and previous != asset_id:
                failures.append(f"semantic SFX content hash is duplicated: {previous}/{asset_id}")
            semantic_hashes[digest] = asset_id


def _validate_source_packages(manifest: dict, entries: dict[str, dict], failures: list[str]) -> None:
    packages = manifest.get("source_packages")
    if not isinstance(packages, dict) or not packages:
        failures.append("source_packages must pin every curated source archive")
        return
    for package_id, package in packages.items():
        if not isinstance(package, dict):
            failures.append(f"source package must be an object: {package_id}")
            continue
        if package.get("license_spdx") != "CC0-1.0":
            failures.append(f"source package license is not CC0: {package_id}")
        if not str(package.get("page_url", "")).startswith("https://kenney.nl/assets/"):
            failures.append(f"source package page is not an official Kenney URL: {package_id}")
        if not str(package.get("archive_url", "")).startswith("https://kenney.nl/media/pages/assets/"):
            failures.append(f"source package archive is not an official Kenney URL: {package_id}")
        if not _is_hex_digest(package.get("archive_sha256")):
            failures.append(f"source package archive hash is invalid: {package_id}")
    for asset_id, entry in entries.items():
        package_id = str(entry.get("source_package_id", ""))
        if not package_id:
            continue
        package = packages.get(package_id)
        if not isinstance(package, dict):
            failures.append(f"{asset_id}: unknown source package ID: {package_id}")
            continue
        if entry.get("source_archive_url") != package.get("archive_url"):
            failures.append(f"{asset_id}: source archive URL differs from package lock")
        if str(entry.get("source_archive_sha256", "")).upper() != str(package.get("archive_sha256", "")).upper():
            failures.append(f"{asset_id}: source archive hash differs from package lock")


def _validate_soundscapes(manifest: dict, entries: dict[str, dict], failures: list[str]) -> None:
    soundscapes = manifest.get("soundscapes")
    if not isinstance(soundscapes, dict):
        failures.append("soundscapes must be an object")
        return
    beds: dict[str, str] = {}
    for location in SOUNDSCAPE_LOCATIONS:
        soundscape = soundscapes.get(location)
        if not isinstance(soundscape, dict):
            failures.append(f"soundscape location is missing: {location}")
            continue
        bed_id = str(soundscape.get("bed", ""))
        beds[location] = bed_id
        bed = entries.get(bed_id)
        if bed is None or bed.get("role") != "ambience" or bed.get("loop") is not True:
            failures.append(f"soundscape bed must reference a loop ambience asset: {location}")
        detail_id = str(soundscape.get("detail", ""))
        if detail_id:
            detail = entries.get(detail_id)
            if detail is None or detail.get("role") != "ambience":
                failures.append(f"soundscape detail references an unknown ambience asset: {location}")
    if beds.get("world") and beds.get("world") == beds.get("dungeon"):
        failures.append("world and dungeon soundscapes must not share the same bed")


def _validate_curated_inventory(managed_paths: set[Path], failures: list[str]) -> None:
    for directory in CURATED_DIRS:
        if not directory.is_dir():
            failures.append(f"curated runtime directory is missing: {directory.relative_to(ROOT)}")
            continue
        for path in directory.rglob("*"):
            if not path.is_file():
                continue
            if path.suffix.lower() in FORBIDDEN_RUNTIME_EXTENSIONS:
                failures.append(f"forbidden runtime file in curated directory: {path.relative_to(ROOT)}")
            if path.suffix.lower() == ".ogg" and path.resolve() not in managed_paths:
                failures.append(f"unregistered curated Ogg asset: {path.relative_to(ROOT)}")


def _validate_legacy_boundary(manifest: dict, failures: list[str]) -> None:
    generated = AUDIO_ROOT / "generated"
    if generated.exists():
        failures.append("retired audio/generated directory must be removed from the product tree")
    legacy_manifest = AUDIO_ROOT / "audio_manifest_v1.json"
    if legacy_manifest.exists():
        failures.append("retired audio_manifest_v1.json must be removed from the product tree")


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
    if channels != int(entry.get("channels", -1)) or sample_rate != int(entry.get("sample_rate", -1)):
        failures.append(f"{asset_id}: manifest format differs from Ogg header")
    if not info["bos"] or not info["eos"] or int(info["page_count"]) < 3:
        failures.append(f"{asset_id}: Ogg stream lacks complete BOS/EOS page structure")
    duration = frame_count / max(1, sample_rate)
    if abs(duration - float(entry.get("duration", -1.0))) > 0.1:
        failures.append(f"{asset_id}: decoded duration differs from manifest ({duration:.4f}s)")
    if entry.get("loop") is True:
        if entry.get("loop_end_sample") != frame_count:
            failures.append(f"{asset_id}: loop_end_sample differs from final Ogg granule")
    elif entry.get("loop_start_sample") is not None or entry.get("loop_end_sample") is not None:
        failures.append(f"{asset_id}: non-loop asset declares loop points")


def validate_import_settings(path: Path, entry: dict, failures: list[str]) -> None:
    asset_id = str(entry.get("id", path.stem))
    sidecar = Path(str(path) + ".import")
    if not sidecar.is_file():
        failures.append(f"{asset_id}: Godot import sidecar is missing")
        return
    text = sidecar.read_text(encoding="utf-8", errors="replace")
    if 'importer="oggvorbisstr"' not in text or 'type="AudioStreamOggVorbis"' not in text:
        failures.append(f"{asset_id}: sidecar does not preserve streamable Ogg/Vorbis semantics")
    if "loop=false" not in text or "loop_offset=0" not in text:
        failures.append(f"{asset_id}: importer loop must remain disabled; runtime owns loop policy")


def _fail(failures: list[str]) -> int:
    for failure in failures:
        print(f"AUDIO_ASSET_VERIFICATION_FAILED: {failure}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--require-final", action="store_true",
        help="Reject candidate assets from product builds.",
    )
    args = parser.parse_args()
    raise SystemExit(main(require_final=args.require_final))
