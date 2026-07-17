#!/usr/bin/env python3
"""Generate the original classical-era audio vertical slice."""

from __future__ import annotations

import hashlib
import json
import math
import random
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "godot" / "audio" / "generated" / "classical"
MANIFEST = ROOT / "godot" / "audio" / "audio_manifest_v1.json"
SAMPLE_RATE = 48_000
CHANNELS = 2
TAU = math.tau

SPECS = {
    "ui_confirm": (0.34, "UI", False),
    "ui_cancel": (0.34, "UI", False),
    "card_cast": (0.92, "SFX", False),
    "impact": (0.58, "SFX", False),
    "guard": (0.82, "SFX", False),
    "stress": (1.18, "SFX", False),
    "heart_awaken": (1.72, "SFX", False),
    "elite_enter": (1.82, "SFX", False),
    "boss_enter": (2.42, "SFX", False),
    "phase_break": (1.62, "SFX", False),
    "victory": (2.24, "SFX", False),
    "defeat": (1.92, "SFX", False),
    "classical_ambience": (16.0, "Ambience", True),
}

HIGH_FREQUENCY_VARIANTS = ("ui_confirm", "ui_cancel", "card_cast", "impact", "guard")
for base_id in HIGH_FREQUENCY_VARIANTS:
    for variant_number in range(2, 5):
        SPECS[f"{base_id}_{variant_number:02d}"] = SPECS[base_id]

EVENT_IDS = {
    "ui_confirm": ["ui.confirm"],
    "ui_cancel": ["ui.cancel"],
    "card_cast": ["dungeon.card", "combat.spell"],
    "impact": ["combat.impact", "dungeon.impact"],
    "guard": ["combat.guard", "dungeon.guard"],
    "stress": ["dungeon.stress"],
    "heart_awaken": ["dungeon.heart", "reincarnation.enter"],
    "elite_enter": ["dungeon.elite_enter"],
    "boss_enter": ["dungeon.boss_enter"],
    "phase_break": ["dungeon.phase_break"],
    "victory": ["combat.victory", "dungeon.victory"],
    "defeat": ["combat.defeat", "dungeon.defeat"],
    "classical_ambience": [
        "context.menu", "context.world", "context.event", "context.combat",
        "context.dungeon", "context.boss", "context.reincarnation",
    ],
}


def base_asset_id(asset_id: str) -> str:
    for base_id in HIGH_FREQUENCY_VARIANTS:
        if asset_id == base_id or asset_id.startswith(f"{base_id}_"):
            return base_id
    return asset_id


def variant_number(asset_id: str) -> int:
    tail = asset_id.rsplit("_", 1)[-1]
    return int(tail) if tail.isdigit() else 1


def clamp(value: float, low: float = -1.0, high: float = 1.0) -> float:
    return max(low, min(high, value))


def smoothstep(value: float) -> float:
    value = clamp(value, 0.0, 1.0)
    return value * value * (3.0 - 2.0 * value)


def fade_window(t: float, duration: float, attack: float = 0.008, release: float = 0.08) -> float:
    fade_in = smoothstep(t / max(attack, 1e-6))
    fade_out = smoothstep((duration - t) / max(release, 1e-6))
    return fade_in * fade_out


def decaying_partial(t: float, start: float, frequency: float, decay: float,
                     amplitude: float, detune: float = 0.0) -> tuple[float, float]:
    local = t - start
    if local < 0.0:
        return 0.0, 0.0
    envelope = math.exp(-local * decay)
    left = math.sin(TAU * frequency * local) * envelope * amplitude
    right = math.sin(TAU * frequency * (1.0 + detune) * local + 0.07) * envelope * amplitude
    return left, right


def add_pair(target: list[float], pair: tuple[float, float], gain: float = 1.0) -> None:
    target[0] += pair[0] * gain
    target[1] += pair[1] * gain


def synth_event(asset_id: str, duration: float, seed: int) -> tuple[list[float], list[float]]:
    # Keep event semantics stable while producing independently seeded timbral
    # variants for inputs players can trigger many times per minute.
    sound_id = base_asset_id(asset_id)
    rng = random.Random(seed)
    count = round(duration * SAMPLE_RATE)
    left = [0.0] * count
    right = [0.0] * count
    noise_l = 0.0
    noise_r = 0.0
    for index in range(count):
        t = index / SAMPLE_RATE
        sample = [0.0, 0.0]
        white_l = rng.uniform(-1.0, 1.0)
        white_r = rng.uniform(-1.0, 1.0)
        noise_l = noise_l * 0.86 + white_l * 0.14
        noise_r = noise_r * 0.84 + white_r * 0.16

        if sound_id == "ui_confirm":
            for frequency, gain, decay in [(920, 0.30, 13), (1380, 0.20, 16), (2070, 0.10, 20)]:
                add_pair(sample, decaying_partial(t, 0.0, frequency, decay, gain, 0.002))
            add_pair(sample, decaying_partial(t, 0.085, 1240, 14, 0.22, -0.002))
            transient = math.exp(-t * 52.0) * 0.07
            sample[0] += noise_l * transient
            sample[1] += noise_r * transient
        elif sound_id == "ui_cancel":
            frequency = 760.0 - 250.0 * smoothstep(t / duration)
            envelope = math.exp(-t * 9.0) * fade_window(t, duration)
            sample[0] += math.sin(TAU * frequency * t) * envelope * 0.25
            sample[1] += math.sin(TAU * frequency * 0.997 * t + 0.05) * envelope * 0.25
            sample[0] += noise_l * math.exp(-t * 45.0) * 0.06
            sample[1] += noise_r * math.exp(-t * 45.0) * 0.06
        elif sound_id == "card_cast":
            swell = smoothstep(t / 0.42) * smoothstep((duration - t) / 0.18)
            frequency = 230.0 + 790.0 * (t / duration) ** 1.7
            sample[0] += math.sin(TAU * frequency * t) * swell * 0.16
            sample[1] += math.sin(TAU * frequency * 1.006 * t + 0.1) * swell * 0.16
            sample[0] += noise_l * swell * 0.14
            sample[1] += noise_r * swell * 0.14
            add_pair(sample, decaying_partial(t, 0.48, 1110, 5.2, 0.24, 0.003))
        elif sound_id == "impact":
            thump = math.sin(TAU * (76.0 - 22.0 * t) * t) * math.exp(-t * 10.0) * 0.42
            crack = math.exp(-t * 34.0) * 0.30
            sample[0] += thump + noise_l * crack
            sample[1] += thump + noise_r * crack
            add_pair(sample, decaying_partial(t, 0.018, 438, 7.0, 0.18, 0.004))
            add_pair(sample, decaying_partial(t, 0.018, 692, 9.0, 0.12, -0.003))
        elif sound_id == "guard":
            whoosh = math.sin(math.pi * clamp(t / duration, 0.0, 1.0)) ** 1.7
            sample[0] += noise_l * whoosh * 0.15
            sample[1] += noise_r * whoosh * 0.15
            for frequency, gain in [(520, 0.25), (780, 0.16), (1040, 0.10)]:
                add_pair(sample, decaying_partial(t, 0.20, frequency, 4.4, gain, 0.003))
        elif sound_id == "stress":
            pulse = 0.55 + 0.45 * math.sin(TAU * 3.2 * t)
            envelope = fade_window(t, duration, 0.08, 0.18)
            sample[0] += (math.sin(TAU * 173 * t) + math.sin(TAU * 181 * t)) * pulse * envelope * 0.10
            sample[1] += (math.sin(TAU * 169 * t) + math.sin(TAU * 179 * t)) * pulse * envelope * 0.10
            sample[0] += noise_l * envelope * 0.08
            sample[1] += noise_r * envelope * 0.08
        elif sound_id == "heart_awaken":
            envelope = fade_window(t, duration, 0.12, 0.28)
            pulse = 0.62 + 0.38 * math.sin(TAU * 2.4 * t) ** 2
            for frequency, gain in [(92, 0.18), (137, 0.13), (211, 0.10)]:
                sample[0] += math.sin(TAU * frequency * t) * envelope * pulse * gain
                sample[1] += math.sin(TAU * frequency * 1.008 * t + 0.12) * envelope * pulse * gain
            sample[0] += noise_l * envelope * (0.06 + t / duration * 0.10)
            sample[1] += noise_r * envelope * (0.06 + t / duration * 0.10)
        elif sound_id in {"elite_enter", "boss_enter"}:
            boss = sound_id == "boss_enter"
            start = 0.34 if boss else 0.22
            base = 58.0 if boss else 92.0
            swell = smoothstep(t / start) * smoothstep((duration - t) / 0.35)
            sample[0] += noise_l * swell * (0.09 if boss else 0.06)
            sample[1] += noise_r * swell * (0.09 if boss else 0.06)
            ratios = [1.0, 1.62, 2.47, 3.71, 5.18] if boss else [1.0, 1.67, 2.58, 3.92]
            for part, ratio in enumerate(ratios):
                add_pair(sample, decaying_partial(t, start, base * ratio, 1.5 + part * 0.55,
                                                  0.24 / (1.0 + part * 0.28), 0.0025))
        elif sound_id == "phase_break":
            thump = math.sin(TAU * (68.0 - 18.0 * t) * t) * math.exp(-t * 7.5) * 0.34
            crack_env = math.exp(-abs(t - 0.18) * 24.0) * (1.0 if t >= 0.18 else 0.25)
            rise = smoothstep(t / duration) * fade_window(t, duration, 0.02, 0.18)
            frequency = 310 + 1180 * (t / duration) ** 2
            sample[0] += thump + noise_l * crack_env * 0.30 + math.sin(TAU * frequency * t) * rise * 0.13
            sample[1] += thump + noise_r * crack_env * 0.30 + math.sin(TAU * frequency * 1.004 * t) * rise * 0.13
        elif sound_id == "victory":
            notes = [(0.0, 392.0), (0.30, 523.25), (0.60, 659.25), (0.94, 783.99)]
            for start, frequency in notes:
                add_pair(sample, decaying_partial(t, start, frequency, 2.8, 0.20, 0.002))
                add_pair(sample, decaying_partial(t, start, frequency * 2.01, 4.1, 0.08, -0.002))
            add_pair(sample, decaying_partial(t, 1.08, 1174.7, 1.9, 0.13, 0.003))
        elif sound_id == "defeat":
            envelope = fade_window(t, duration, 0.02, 0.32)
            frequency = 310.0 * math.exp(-t * 0.62) + 54.0
            sample[0] += math.sin(TAU * frequency * t) * envelope * 0.23
            sample[1] += math.sin(TAU * frequency * 0.994 * t + 0.09) * envelope * 0.23
            sample[0] += noise_l * envelope * 0.07
            sample[1] += noise_r * envelope * 0.07

        window = fade_window(t, duration)
        left[index] = sample[0] * window
        right[index] = sample[1] * window
    apply_variant_colour(left, right, variant_number(asset_id))
    return left, right


def apply_variant_colour(left: list[float], right: list[float], number: int) -> None:
    """Add subtle, deterministic material variation without changing timing."""
    if number <= 1:
        return
    delays = {2: 29, 3: 47, 4: 67}
    mixes = {2: 0.055, 3: 0.075, 4: 0.095}
    delay = delays.get(number, 29)
    mix = mixes.get(number, 0.055)
    source_left = left.copy()
    source_right = right.copy()
    for index in range(delay, len(left)):
        left[index] = source_left[index] * (1.0 - mix) + source_right[index - delay] * mix
        right[index] = source_right[index] * (1.0 - mix) - source_left[index - delay] * mix * 0.72


def synth_ambience(duration: float, seed: int) -> tuple[list[float], list[float]]:
    rng = random.Random(seed)
    count = round(duration * SAMPLE_RATE)
    left = [0.0] * count
    right = [0.0] * count
    layers = []
    for _ in range(16):
        harmonic = rng.randint(8, 1900)
        frequency = harmonic / duration
        amplitude = rng.uniform(0.008, 0.035) / (1.0 + frequency / 420.0)
        phase = rng.uniform(0.0, TAU)
        pan = rng.uniform(-0.55, 0.55)
        layers.append((frequency, amplitude, phase, pan))
    bell_events = [(3.1, 523.25, 0.055), (8.4, 659.25, 0.045), (12.7, 440.0, 0.050)]
    for index in range(count):
        t = index / SAMPLE_RATE
        # Every continuous bed component completes an integer number of cycles
        # inside the loop.  This makes the source sample-periodic instead of
        # hiding a discontinuity behind a runtime crossfade.
        sample_l = math.sin(TAU * (3.0 / duration) * t) * 0.018
        sample_r = math.sin(TAU * (2.0 / duration) * t + 0.7) * 0.018
        for frequency, amplitude, phase, pan in layers:
            value = math.sin(TAU * frequency * t + phase) * amplitude
            sample_l += value * (1.0 - max(0.0, pan))
            sample_r += value * (1.0 + min(0.0, pan))
        for start, frequency, gain in bell_events:
            local = t - start
            if 0.0 <= local <= 3.0:
                envelope = math.exp(-local * 1.8)
                sample_l += math.sin(TAU * frequency * local) * envelope * gain
                sample_r += math.sin(TAU * frequency * 1.002 * local + 0.08) * envelope * gain
                sample_l += math.sin(TAU * frequency * 2.31 * local) * envelope * gain * 0.28
                sample_r += math.sin(TAU * frequency * 2.29 * local) * envelope * gain * 0.28
        left[index] = sample_l
        right[index] = sample_r
    return left, right


def normalize(left: list[float], right: list[float], target_peak: float) -> tuple[float, float]:
    peak = max(max(abs(value) for value in left), max(abs(value) for value in right), 1e-9)
    scale = target_peak / peak
    square_sum = 0.0
    for index in range(len(left)):
        left[index] = clamp(left[index] * scale, -0.98, 0.98)
        right[index] = clamp(right[index] * scale, -0.98, 0.98)
        square_sum += (left[index] ** 2 + right[index] ** 2) * 0.5
    rms = math.sqrt(square_sum / max(1, len(left)))
    return target_peak, rms


def write_wav(path: Path, left: list[float], right: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = bytearray()
    for sample_l, sample_r in zip(left, right):
        frames.extend(struct.pack("<hh", round(sample_l * 32767), round(sample_r * 32767)))
    with wave.open(str(path), "wb") as output:
        output.setnchannels(CHANNELS)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(frames)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    assets = []
    generator_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest().upper()
    for index, (asset_id, (duration, bus, loop)) in enumerate(SPECS.items()):
        if loop:
            left, right = synth_ambience(duration, 710_000 + index)
            target_peak = 0.34
        else:
            left, right = synth_event(asset_id, duration, 710_000 + index)
            target_peak = 0.68 if base_asset_id(asset_id) in {"impact", "phase_break"} else 0.56
        peak, rms = normalize(left, right, target_peak)
        path = OUTPUT / f"{asset_id}.wav"
        write_wav(path, left, right)
        boundary = max(abs(left[0] - left[-1]), abs(right[0] - right[-1])) if loop else 0.0
        assets.append({
            "id": asset_id,
            "asset_id": asset_id,
            "file": f"generated/classical/{asset_id}.wav",
            "runtime_path": f"res://audio/generated/classical/{asset_id}.wav",
            "source_master": f"procedural://tools/generate_audio_assets.py#{asset_id}",
            "kind": "ambience" if loop else "sfx",
            "role": "ambience" if loop else ("ui" if bus == "UI" else "sfx"),
            "bus": bus,
            "era_ids": ["classical"],
            "event_ids": EVENT_IDS[base_asset_id(asset_id)],
            "loop": loop,
            "loop_start_sample": 0 if loop else None,
            "loop_end_sample": len(left) if loop else None,
            "sample_rate": SAMPLE_RATE,
            "channels": CHANNELS,
            "bits_per_sample": 16,
            "duration": duration,
            "peak_dbfs": round(20.0 * math.log10(max(peak, 1e-9)), 3),
            "rms_dbfs": round(20.0 * math.log10(max(rms, 1e-9)), 3),
            "loop_boundary_delta": round(boundary, 7),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest().upper(),
            "license": "LicenseRef-Project-Original",
            "license_name": "Project-original procedural composition and sound design",
            "commercial_use": True,
            "redistribution_in_game": True,
            "creator_or_vendor": "Wendao Changsheng project",
            "attribution_text": "Original audio created for Wendao Changsheng.",
            "created_or_acquired_at": "2026-07-17",
            "release_state": "production_candidate",
            "manual_qa_status": "pending_multidevice_listening",
            "generator": "tools/generate_audio_assets.py",
            "generator_and_version": "Python standard-library procedural synthesis v1",
        })
    manifest = {
        "version": 1,
        "generator_sha256": generator_hash,
        "asset_root": "res://audio/",
        "assets": assets,
    }
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(assets)} original audio assets in {OUTPUT}")


if __name__ == "__main__":
    main()
