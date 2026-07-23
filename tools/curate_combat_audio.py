#!/usr/bin/env python3
"""Rebuild the product combat SFX set from pinned official Kenney archives.

The runtime files are byte-identical copies of the published Ogg sources. The
script records both archive and per-file hashes, then measures every selected
asset with the bundled LGPL FFmpeg tools. No downloaded archive is shipped.
"""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDIO_ROOT = ROOT / "godot" / "audio"
MANIFEST_PATH = AUDIO_ROOT / "audio_manifest_v2.json"
CACHE = ROOT / ".tmp" / "audio-upgrade"

PACKAGES = {
    "kenney-interface-sounds-1.0": {
        "page_url": "https://kenney.nl/assets/interface-sounds",
        "archive_url": "https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
        "archive_sha256": "F2193D072726D6758A5F7871B2DCC54DCCE0D5C35C6F0A62F92549B327C81232",
        "cache_name": "kenney_interface.zip",
        "title": "Kenney Interface Sounds 1.0",
    },
    "kenney-rpg-audio-1.0": {
        "page_url": "https://kenney.nl/assets/rpg-audio",
        "archive_url": "https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip",
        "archive_sha256": "6DBEAF8544DA958D8F2ADCB4A4A4B76C1ADE34A05F8AB9EDCCD327DA7375F38B",
        "cache_name": "kenney_rpg-audio.zip",
        "title": "Kenney RPG Audio 1.0",
    },
    "kenney-impact-sounds-1.0": {
        "page_url": "https://kenney.nl/assets/impact-sounds",
        "archive_url": "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip",
        "archive_sha256": "029D734AF1582474EDF3A694D1B0CEBC97C1C152F2F39FA34D4C2BAFC5DE77F8",
        "cache_name": "kenney_impact-sounds.zip",
        "title": "Kenney Impact Sounds 1.0",
    },
    "kenney-digital-audio-1.0": {
        "page_url": "https://kenney.nl/assets/digital-audio",
        "archive_url": "https://kenney.nl/media/pages/assets/digital-audio/216eac4753-1677590265/kenney_digital-audio.zip",
        "archive_sha256": "24E6CE28B76A6D8C89CFF4D331E0965FF5C3DE8A73C612028E9D363CC64E4F06",
        "cache_name": "kenney_digital.zip",
        "title": "Kenney Digital Audio 1.0",
    },
    "kenney-sci-fi-sounds-1.0": {
        "page_url": "https://kenney.nl/assets/sci-fi-sounds",
        "archive_url": "https://kenney.nl/media/pages/assets/sci-fi-sounds/6b296f9ecf-1677589334/kenney_sci-fi-sounds.zip",
        "archive_sha256": "119340F351A5098AD814F78719438C0DA355A9CE8A4C8A3AF6A8D48AA3D49E04",
        "cache_name": "kenney_scifi.zip",
        "title": "Kenney Sci-Fi Sounds 1.0",
    },
    "kenney-music-jingles-1.0": {
        "page_url": "https://kenney.nl/assets/music-jingles",
        "archive_url": "https://kenney.nl/media/pages/assets/music-jingles/f37e530b9e-1677590399/kenney_music-jingles.zip",
        "archive_sha256": "B729BA57959BD58793D2C5CAFA348AAF2655D354F3DA35EC4729E03EC77197B8",
        "cache_name": "kenney_jingles.zip",
        "title": "Kenney Music Jingles 1.0",
    },
}

# Asset ID, package, archive member, runtime filename, semantic category.
SELECTIONS = (
    ("sfx_sword_cut_01", "kenney-rpg-audio-1.0", "Audio/knifeSlice.ogg", "sfx_sword_cut_01.ogg", "weapon_impact"),
    ("sfx_sword_cut_02", "kenney-rpg-audio-1.0", "Audio/knifeSlice2.ogg", "sfx_sword_cut_02.ogg", "weapon_impact"),
    ("sfx_sword_cut_03", "kenney-rpg-audio-1.0", "Audio/chop.ogg", "sfx_sword_cut_03.ogg", "weapon_impact"),
    ("sfx_guard_field_01", "kenney-sci-fi-sounds-1.0", "Audio/forceField_000.ogg", "sfx_guard_field_01.ogg", "shield_guard"),
    ("sfx_guard_field_02", "kenney-sci-fi-sounds-1.0", "Audio/forceField_001.ogg", "sfx_guard_field_02.ogg", "shield_guard"),
    ("sfx_guard_field_03", "kenney-sci-fi-sounds-1.0", "Audio/forceField_002.ogg", "sfx_guard_field_03.ogg", "shield_guard"),
    ("sfx_spell_phase_01", "kenney-digital-audio-1.0", "Audio/phaseJump1.ogg", "sfx_spell_phase_01.ogg", "spell_cast"),
    ("sfx_spell_phase_02", "kenney-digital-audio-1.0", "Audio/phaseJump2.ogg", "sfx_spell_phase_02.ogg", "spell_cast"),
    ("sfx_spell_phase_03", "kenney-digital-audio-1.0", "Audio/phaseJump3.ogg", "sfx_spell_phase_03.ogg", "spell_cast"),
    ("sfx_recover_qi_01", "kenney-digital-audio-1.0", "Audio/powerUp1.ogg", "sfx_recover_qi_01.ogg", "recovery"),
    ("sfx_recover_qi_02", "kenney-digital-audio-1.0", "Audio/powerUp3.ogg", "sfx_recover_qi_02.ogg", "recovery"),
    ("sfx_status_down_01", "kenney-digital-audio-1.0", "Audio/phaserDown1.ogg", "sfx_status_down_01.ogg", "status"),
    ("sfx_status_down_02", "kenney-digital-audio-1.0", "Audio/phaserDown2.ogg", "sfx_status_down_02.ogg", "status"),
    ("sfx_phase_shatter", "kenney-sci-fi-sounds-1.0", "Audio/explosionCrunch_003.ogg", "sfx_phase_shatter.ogg", "phase_change"),
    ("sfx_elite_bell", "kenney-impact-sounds-1.0", "Audio/impactBell_heavy_001.ogg", "sfx_elite_bell.ogg", "encounter_transition"),
    ("sfx_boss_rumble", "kenney-sci-fi-sounds-1.0", "Audio/lowFrequency_explosion_000.ogg", "sfx_boss_rumble.ogg", "encounter_transition"),
    ("sfx_victory_jingle", "kenney-music-jingles-1.0", "Audio/Steel jingles/jingles_STEEL15.ogg", "sfx_victory_jingle.ogg", "victory"),
    ("sfx_defeat_jingle", "kenney-music-jingles-1.0", "Audio/Steel jingles/jingles_STEEL01.ogg", "sfx_defeat_jingle.ogg", "defeat"),
)

EVENTS = {
    "combat.spell": (["sfx_spell_phase_01", "sfx_spell_phase_02", "sfx_spell_phase_03"], "spell_cast", -7.0, 42, 80, 2, False),
    "combat.impact": (["sfx_sword_cut_01", "sfx_sword_cut_02", "sfx_sword_cut_03"], "weapon_impact", -4.0, 55, 65, 3, True),
    "dungeon.impact": (["sfx_sword_cut_01", "sfx_sword_cut_02", "sfx_sword_cut_03"], "weapon_impact", -4.0, 56, 65, 3, True),
    "combat.guard": (["sfx_guard_field_01", "sfx_guard_field_02", "sfx_guard_field_03"], "shield_guard", -7.0, 48, 90, 2, False),
    "dungeon.guard": (["sfx_guard_field_01", "sfx_guard_field_02", "sfx_guard_field_03"], "shield_guard", -7.0, 48, 90, 2, False),
    "combat.recover": (["sfx_recover_qi_01", "sfx_recover_qi_02"], "recovery", -7.0, 64, 180, 2, False),
    "combat.heal": (["sfx_recover_qi_01", "sfx_recover_qi_02"], "recovery", -7.0, 64, 180, 2, False),
    "combat.status": (["sfx_status_down_01", "sfx_status_down_02"], "status", -9.0, 58, 220, 2, False),
    "dungeon.stress": (["sfx_status_down_01", "sfx_status_down_02"], "status", -9.0, 58, 260, 1, False),
    "dungeon.heart": (["sfx_recover_qi_01", "sfx_recover_qi_02"], "recovery", -5.0, 72, 900, 1, False),
    "dungeon.elite_enter": (["sfx_elite_bell"], "encounter_transition", -6.0, 76, 1200, 1, True),
    "dungeon.boss_enter": (["sfx_boss_rumble"], "encounter_transition", -7.0, 88, 1500, 1, True),
    "dungeon.phase_break": (["sfx_phase_shatter"], "phase_change", -7.0, 92, 1100, 1, True),
    "dungeon.victory": (["sfx_victory_jingle"], "victory", -9.0, 82, 1000, 1, False),
    "combat.victory": (["sfx_victory_jingle"], "victory", -9.0, 80, 1000, 1, False),
    "dungeon.defeat": (["sfx_defeat_jingle"], "defeat", -10.0, 86, 1000, 1, False),
    "combat.defeat": (["sfx_defeat_jingle"], "defeat", -10.0, 84, 1000, 1, False),
    "reincarnation.enter": (["sfx_recover_qi_01"], "recovery", -7.0, 78, 1600, 1, False),
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def tool(name: str) -> Path:
    candidates = list((ROOT / ".local" / "audio-encoder").rglob(f"{name}.exe"))
    if not candidates:
        raise RuntimeError(f"missing bundled {name}.exe under .local/audio-encoder")
    return candidates[0]


def get_archive(package_id: str) -> Path:
    package = PACKAGES[package_id]
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / package["cache_name"]
    if not path.is_file() or sha256(path.read_bytes()) != package["archive_sha256"]:
        urllib.request.urlretrieve(package["archive_url"], path)
    actual = sha256(path.read_bytes())
    if actual != package["archive_sha256"]:
        raise RuntimeError(f"archive hash mismatch for {package_id}: {actual}")
    return path


def measure(path: Path) -> dict[str, float | int]:
    probe = subprocess.run(
        [str(tool("ffprobe")), "-v", "error", "-select_streams", "a:0",
         "-show_entries", "stream=sample_rate,channels:format=duration", "-of", "json", str(path)],
        check=True, capture_output=True, text=True,
    )
    info = json.loads(probe.stdout)
    stream = info["streams"][0]
    stats = subprocess.run(
        [str(tool("ffmpeg")), "-hide_banner", "-nostats", "-i", str(path),
         "-af", "astats=metadata=0:reset=0", "-f", "null", "NUL"],
        capture_output=True, text=True,
    ).stderr
    peak_values = [float(value) for value in re.findall(r"Peak level dB:\s*(-?[0-9.]+)", stats)]
    rms_values = [float(value) for value in re.findall(r"RMS level dB:\s*(-?[0-9.]+)", stats)]
    spectrum = subprocess.run(
        [str(tool("ffmpeg")), "-hide_banner", "-nostats", "-i", str(path),
         "-af", "aformat=channel_layouts=mono,aspectralstats=measure=centroid,ametadata=print:file=-",
         "-f", "null", "NUL"], capture_output=True, text=True,
    )
    centroids = [float(value) for value in re.findall(
        r"lavfi\.aspectralstats\.1\.centroid=([0-9.]+)", spectrum.stdout)]
    if not peak_values or not rms_values or not centroids:
        raise RuntimeError(f"FFmpeg could not measure {path}")
    peak = max(peak_values)
    rms = max(rms_values)
    return {
        "sample_rate": int(stream["sample_rate"]),
        "channels": int(stream["channels"]),
        "duration": round(float(info["format"]["duration"]), 6),
        "peak_dbfs": round(peak, 3),
        "rms_dbfs": round(rms, 3),
        "crest_factor_db": round(peak - rms, 3),
        "spectral_centroid_hz": round(sum(centroids) / len(centroids), 1),
    }


def main() -> int:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    selected_ids = {item[0] for item in SELECTIONS}
    retired_ids = {str(asset.get("id", "")) for asset in manifest["assets"]
                   if str(asset.get("id", "")).startswith("sfx_impact_punch_")}
    manifest["assets"] = [asset for asset in manifest["assets"]
                          if str(asset.get("id", "")) not in retired_ids | selected_ids]

    package_by_page = {package["page_url"]: (package_id, package)
                       for package_id, package in PACKAGES.items()}
    for asset in manifest["assets"]:
        if str(asset.get("creator", "")) != "Kenney":
            continue
        package_match = package_by_page.get(str(asset.get("source_url", "")))
        if package_match is None:
            raise RuntimeError(f"unlocked Kenney package for {asset.get('id')}")
        package_id, package = package_match
        member = str(asset.get("source_file", ""))
        if "/Audio/" in member:
            member = "Audio/" + member.split("/Audio/", 1)[1]
        archive = get_archive(package_id)
        with zipfile.ZipFile(archive) as source_zip:
            source_data = source_zip.read(member)
        if sha256(source_data) != str(asset.get("source_sha256", "")).upper():
            raise RuntimeError(f"published source hash mismatch for {asset.get('id')}")
        asset["source_package_id"] = package_id
        asset["source_archive_url"] = package["archive_url"]
        asset["source_archive_sha256"] = package["archive_sha256"]
        asset["source_file"] = member

    event_ids_by_asset: dict[str, list[str]] = {asset_id: [] for asset_id in selected_ids}
    for event_id, (asset_ids, category, gain, priority, cooldown, instances, sudden) in EVENTS.items():
        event = {
            "asset_ids": asset_ids,
            "semantic_category": category,
            "bus": "SFX",
            "gain_db": gain,
            "priority": priority,
            "cooldown_ms": cooldown,
            "max_instances": instances,
        }
        if sudden:
            event["sudden"] = True
        manifest["events"][event_id] = event
        for asset_id in asset_ids:
            event_ids_by_asset[asset_id].append(event_id)

    sfx_dir = AUDIO_ROOT / "sfx"
    sfx_dir.mkdir(parents=True, exist_ok=True)
    for path in sfx_dir.glob("sfx_impact_punch_*.ogg"):
        path.unlink()
    for path in sfx_dir.glob("sfx_impact_punch_*.ogg.import"):
        path.unlink()

    for asset_id, package_id, member, runtime_name, category in SELECTIONS:
        package = PACKAGES[package_id]
        archive = get_archive(package_id)
        with zipfile.ZipFile(archive) as source_zip:
            data = source_zip.read(member)
        runtime_path = sfx_dir / runtime_name
        runtime_path.write_bytes(data)
        metrics = measure(runtime_path)
        digest = sha256(data)
        manifest["assets"].append({
            "id": asset_id,
            "runtime_path": f"res://audio/sfx/{runtime_name}",
            "file": f"sfx/{runtime_name}",
            "role": "sfx",
            "kind": "sfx",
            "bus": "SFX",
            "semantic_category": category,
            "era_ids": ["*"],
            "event_ids": event_ids_by_asset[asset_id],
            "loop": False,
            "streaming": True,
            **metrics,
            "sha256": digest,
            "source_package_id": package_id,
            "source_url": package["page_url"],
            "source_archive_url": package["archive_url"],
            "source_archive_sha256": package["archive_sha256"],
            "source_file": member,
            "source_sha256": digest,
            "creator": "Kenney",
            "license_spdx": "CC0-1.0",
            "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
            "license_file": "res://audio/licenses/kenney-cc0.txt",
            "attribution_text": f"{package['title']}, CC0 (credit retained for traceability).",
            "commercial_use": True,
            "redistribution_in_game": True,
            "modifications": "byte-identical copy of the published Ogg; no source audio edits",
            "release_state": "final",
        })

    manifest["source_packages"] = {
        package_id: {
            "title": package["title"],
            "version": "1.0",
            "publisher": "Kenney",
            "page_url": package["page_url"],
            "archive_url": package["archive_url"],
            "archive_sha256": package["archive_sha256"],
            "license_spdx": "CC0-1.0",
            "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
            "license_file": "res://audio/licenses/kenney-cc0.txt",
        }
        for package_id, package in PACKAGES.items()
    }
    manifest["processing"]["sfx_measurement"] = "FFmpeg n7.1 astats + aspectralstats; byte-identical source Ogg"
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"CURATED_COMBAT_AUDIO_OK: {len(SELECTIONS)} semantic SFX from {len(PACKAGES)} pinned CC0 archives")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"CURATED_COMBAT_AUDIO_FAILED: {error}", file=sys.stderr)
        raise SystemExit(1)
