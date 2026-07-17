#!/usr/bin/env python3
"""Generate the original six-era audio runtime set."""

from __future__ import annotations

import hashlib
import json
import math
import os
import random
import struct
import subprocess
import sys
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_ROOT = ROOT / "godot" / "audio" / "generated"
MANIFEST = ROOT / "godot" / "audio" / "audio_manifest_v1.json"
MUSIC_MASTER_ROOT = ROOT / ".tmp" / "audio-masters"
SAMPLE_RATE = 48_000
CHANNELS = 2
TAU = math.tau
MUSIC_DURATION = 64.0
SOUNDSCAPE_DURATION = 64.0
MUSIC_STATES = ("exploration", "pressure", "decisive")
SOUNDSCAPE_LOCATIONS = ("world", "dungeon")
SOUNDSCAPE_LAYERS = ("bed", "weather_points")
MUSIC_ENCODE_ARGS = (
    "-map_metadata", "-1", "-vn", "-c:a", "libvorbis", "-q:a", "4",
    "-ar", str(SAMPLE_RATE), "-ac", str(CHANNELS), "-fflags", "+bitexact",
    "-flags:a", "+bitexact",
)

ERA_IDS = (
    "classical", "steam", "star_network", "wasteland", "final_age",
    "immortal_dynasty",
)
ERA_EVENT_BASES = ("card_cast", "impact", "guard")
ERA_LOW_FREQUENCY_BASES = {
    "stress", "heart_awaken", "elite_enter", "boss_enter", "phase_break",
    "victory", "defeat",
}
SHARED_EVENT_BASES = {"ui_confirm", "ui_cancel"}
ERA_AMBIENCE = {
    "classical": {"tone_scale": 1.00, "pulse_cycles": 3, "brightness": 0.42,
                  "motif": (523.25, 659.25, 440.00)},
    "steam": {"tone_scale": 0.72, "pulse_cycles": 24, "brightness": 0.30,
              "motif": (196.00, 293.66, 392.00)},
    "star_network": {"tone_scale": 1.74, "pulse_cycles": 40, "brightness": 0.78,
                     "motif": (783.99, 987.77, 1318.51)},
    "wasteland": {"tone_scale": 0.54, "pulse_cycles": 5, "brightness": 0.18,
                  "motif": (146.83, 220.00, 174.61)},
    "final_age": {"tone_scale": 0.83, "pulse_cycles": 11, "brightness": 0.55,
                  "motif": (311.13, 466.16, 349.23)},
    "immortal_dynasty": {"tone_scale": 1.18, "pulse_cycles": 16, "brightness": 0.64,
                         "motif": (392.00, 587.33, 783.99)},
}

# Each era keeps the same 120 BPM / 64-second form, so all three intensity
# states can enter at the outgoing normalized phase.  Scale, harmony, timbre,
# density and percussion material remain deliberately era-specific.
ERA_MUSIC = {
    "classical": {
        "root_hz": 110.00, "scale": (0, 3, 5, 7, 10, 12, 15),
        "progression": (0, 5, 3, 7, 0, 10, 5, 7), "mode_third": 3,
        "timbre": "silk", "drone_gain": 0.060, "seed": 821_101,
    },
    "steam": {
        "root_hz": 82.41, "scale": (0, 2, 3, 7, 8, 11, 12),
        "progression": (0, 3, 8, 7, 0, 11, 3, 7), "mode_third": 3,
        "timbre": "brass", "drone_gain": 0.068, "seed": 821_202,
    },
    "star_network": {
        "root_hz": 130.81, "scale": (0, 2, 4, 7, 9, 11, 14),
        "progression": (0, 9, 4, 7, 0, 11, 9, 7), "mode_third": 4,
        "timbre": "stellar", "drone_gain": 0.052, "seed": 821_303,
    },
    "wasteland": {
        "root_hz": 73.42, "scale": (0, 3, 5, 6, 7, 10, 12),
        "progression": (0, 6, 3, 10, 0, 5, 6, 7), "mode_third": 3,
        "timbre": "dust", "drone_gain": 0.074, "seed": 821_404,
    },
    "final_age": {
        "root_hz": 98.00, "scale": (0, 1, 3, 6, 7, 10, 13),
        "progression": (0, 6, 1, 10, 0, 13, 6, 7), "mode_third": 3,
        "timbre": "fracture", "drone_gain": 0.058, "seed": 821_505,
    },
    "immortal_dynasty": {
        "root_hz": 123.47, "scale": (0, 2, 5, 7, 9, 12, 14),
        "progression": (0, 5, 9, 7, 0, 12, 5, 9), "mode_third": 5,
        "timbre": "celestial", "drone_gain": 0.064, "seed": 821_606,
    },
}

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
    # Retained as a non-emitting seed slot so v2 soundscape migration never
    # changes the deterministic hashes of the established short SFX catalog.
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
}

SOUNDSCAPE_EVENTS = {
    "world": [
        "context.menu", "context.world", "context.event", "context.combat",
        "context.reincarnation",
    ],
    "dungeon": ["context.dungeon", "context.boss"],
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


def synth_event(asset_id: str, duration: float, seed: int,
                era_id: str = "classical") -> tuple[list[float], list[float]]:
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
    apply_era_narrative_signature(left, right, era_id, sound_id)
    apply_era_colour(left, right, era_id, loop=False)
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


def apply_era_narrative_signature(left: list[float], right: list[float],
                                  era_id: str, sound_id: str) -> None:
    """Give rare narrative/combat cues a composed era identity, not just EQ."""
    if era_id == "classical" or sound_id not in ERA_LOW_FREQUENCY_BASES:
        return
    base_hz = {
        "stress": 164.81,
        "heart_awaken": 220.00,
        "elite_enter": 110.00,
        "boss_enter": 73.42,
        "phase_break": 146.83,
        "victory": 329.63,
        "defeat": 98.00,
    }[sound_id]
    semantic_gain = 1.18 if sound_id in {"boss_enter", "phase_break", "heart_awaken"} else 1.0
    duration = len(left) / SAMPLE_RATE
    for index in range(len(left)):
        t = index / SAMPLE_RATE
        window = fade_window(t, duration, 0.035, 0.16)
        if era_id == "steam":
            gear = max(0.0, math.sin(TAU * 7.5 * t)) ** 8
            breath = 0.78 + 0.22 * math.sin(TAU * 1.5 * t) ** 2
            left[index] += (math.sin(TAU * base_hz * t) * 0.040 * breath +
                            math.sin(TAU * base_hz * 2.01 * t) * gear * 0.032) * window * semantic_gain
            right[index] += (math.sin(TAU * base_hz * 0.998 * t + 0.06) * 0.040 * breath +
                             math.sin(TAU * base_hz * 2.02 * t + 0.1) * gear * 0.030) * window * semantic_gain
        elif era_id == "star_network":
            phase = TAU * base_hz * 1.5 * t
            shimmer = math.sin(phase + 0.82 * math.sin(TAU * 9.0 * t))
            pulse = 0.66 + 0.34 * math.sin(TAU * 5.0 * t) ** 2
            left[index] += (shimmer * 0.047 + math.sin(phase * 2.03) * 0.018) * pulse * window * semantic_gain
            right[index] += (math.sin(phase * 1.003 + 0.16 + 0.74 * math.sin(TAU * 9.0 * t + 0.3)) * 0.045 -
                             math.sin(phase * 2.01) * 0.016) * pulse * window * semantic_gain
        elif era_id == "wasteland":
            scarcity = max(0.0, math.sin(TAU * 2.0 * t)) ** 3
            grain = math.sin(TAU * 913.0 * t) * math.sin(TAU * 37.0 * t)
            left[index] += (math.sin(TAU * base_hz * 0.5 * t) * 0.052 * scarcity +
                            grain * 0.013) * window * semantic_gain
            right[index] += (math.sin(TAU * base_hz * 0.503 * t + 0.08) * 0.050 * scarcity -
                             grain * 0.011) * window * semantic_gain
        elif era_id == "final_age":
            fracture = 0.25 + 0.75 * float(math.sin(TAU * 13.0 * t) > -0.18)
            dying = 1.0 - 0.44 * smoothstep(t / max(duration, 1e-6))
            left[index] += (math.sin(TAU * base_hz * t) * 0.043 +
                            math.sin(TAU * base_hz * 1.017 * t) * 0.031) * fracture * dying * window * semantic_gain
            right[index] += (math.sin(TAU * base_hz * 0.991 * t + 0.13) * 0.043 -
                             math.sin(TAU * base_hz * 1.021 * t) * 0.028) * fracture * dying * window * semantic_gain
        elif era_id == "immortal_dynasty":
            decree = 0.76 + 0.24 * max(0.0, math.sin(TAU * 4.0 * t)) ** 6
            left[index] += (math.sin(TAU * base_hz * t) * 0.044 +
                            math.sin(TAU * base_hz * 1.5 * t) * 0.032 +
                            math.sin(TAU * base_hz * 2.0 * t) * 0.019) * decree * window * semantic_gain
            right[index] += (math.sin(TAU * base_hz * 1.002 * t + 0.05) * 0.044 +
                             math.sin(TAU * base_hz * 1.503 * t + 0.12) * 0.030 +
                             math.sin(TAU * base_hz * 2.004 * t) * 0.018) * decree * window * semantic_gain


def apply_era_colour(left: list[float], right: list[float], era_id: str,
                     loop: bool) -> None:
    """Give shared event semantics a stable, recognisable era material."""
    if era_id == "classical":
        return
    source_left = left.copy()
    source_right = right.copy()
    count = len(left)
    delay_by_era = {
        "steam": 73, "star_network": 181, "wasteland": 113,
        "final_age": 149, "immortal_dynasty": 97,
    }
    delay = delay_by_era[era_id]
    for index in range(count):
        t = index / SAMPLE_RATE
        delayed_index = index - delay
        if loop:
            delayed_index %= count
        delayed_l = source_right[delayed_index] if delayed_index >= 0 else 0.0
        delayed_r = source_left[delayed_index] if delayed_index >= 0 else 0.0
        current_l = source_left[index]
        current_r = source_right[index]
        if era_id == "steam":
            drive = 0.88 + 0.12 * math.sin(TAU * 7.5 * t)
            left[index] = math.tanh((current_l * 0.88 + delayed_l * 0.18) * 1.18) * drive
            right[index] = math.tanh((current_r * 0.88 + delayed_r * 0.18) * 1.18) * drive
        elif era_id == "star_network":
            shimmer = 0.92 + 0.08 * math.sin(TAU * 13.0 * t + 0.3)
            left[index] = current_l * 0.78 + delayed_l * 0.24 * shimmer
            right[index] = current_r * 0.78 - delayed_r * 0.20 * shimmer
        elif era_id == "wasteland":
            scarcity = 0.74 + 0.26 * (0.5 + 0.5 * math.sin(TAU * 2.0 * t))
            left[index] = (current_l * 0.82 + delayed_l * 0.10) * scarcity
            right[index] = (current_r * 0.82 + delayed_r * 0.10) * scarcity
        elif era_id == "final_age":
            fracture = 0.54 + 0.46 * (0.5 + 0.5 * math.sin(TAU * 11.0 * t)) ** 2
            left[index] = current_l * fracture + delayed_l * 0.16
            right[index] = current_r * fracture - delayed_r * 0.14
        elif era_id == "immortal_dynasty":
            order = 0.90 + 0.10 * math.sin(TAU * 4.0 * t) ** 8
            left[index] = (current_l * 0.84 + delayed_l * 0.20) * order
            right[index] = (current_r * 0.84 + delayed_r * 0.20) * order


def synth_ambience(duration: float, seed: int,
                   era_id: str = "classical") -> tuple[list[float], list[float]]:
    rng = random.Random(seed)
    profile = ERA_AMBIENCE[era_id]
    count = round(duration * SAMPLE_RATE)
    left = [0.0] * count
    right = [0.0] * count
    layers = []
    for _ in range(16):
        harmonic = rng.randint(8, 1900)
        # Preserve an integer number of cycles inside the loop even while the
        # spectral range changes by era; fractional cycle scaling would create
        # a measurable seam at the exact sample boundary.
        frequency = max(1, round(harmonic * float(profile["tone_scale"]))) / duration
        amplitude = rng.uniform(0.008, 0.035) / (
            1.0 + frequency / (260.0 + 360.0 * float(profile["brightness"]))
        )
        phase = rng.uniform(0.0, TAU)
        pan = rng.uniform(-0.55, 0.55)
        layers.append((frequency, amplitude, phase, pan))
    motif = profile["motif"]
    bell_events = [(3.1, motif[0], 0.055), (8.4, motif[1], 0.045),
                   (12.2, motif[2], 0.050)]
    for index in range(count):
        t = index / SAMPLE_RATE
        # Every continuous bed component completes an integer number of cycles
        # inside the loop.  This makes the source sample-periodic instead of
        # hiding a discontinuity behind a runtime crossfade.
        pulse_cycles = int(profile["pulse_cycles"])
        pulse = 0.82 + 0.18 * math.sin(TAU * (pulse_cycles / duration) * t) ** 2
        sample_l = math.sin(TAU * (3.0 / duration) * t) * 0.018 * pulse
        sample_r = math.sin(TAU * (2.0 / duration) * t + 0.7) * 0.018 * pulse
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
    apply_era_colour(left, right, era_id, loop=True)
    return left, right


def require_numpy():
    try:
        import numpy as np
    except ImportError as error:
        raise SystemExit(
            "Music generation requires NumPy 2.3.3. Run: "
            f"{sys.executable} -m pip install -r tools/audio-requirements.txt"
        ) from error
    if np.__version__ != "2.3.3":
        raise SystemExit(
            f"Music generation is hash-pinned to NumPy 2.3.3, found {np.__version__}. "
            "Install tools/audio-requirements.txt in the generation environment."
        )
    return np


def find_ffmpeg() -> Path:
    configured = os.environ.get("WENDAO_FFMPEG", "").strip()
    if configured:
        candidate = Path(configured).expanduser().resolve()
        if candidate.is_file():
            return candidate
        raise SystemExit(f"WENDAO_FFMPEG does not point to a file: {candidate}")
    cache = ROOT / ".local" / "audio-encoder" / "ffmpeg-n7.1-lgpl-7.1"
    candidates = sorted(cache.rglob("ffmpeg.exe")) if cache.is_dir() else []
    if len(candidates) != 1:
        raise SystemExit(
            "Pinned FFmpeg encoder is missing. Run tools/prepare_audio_encoder.ps1 "
            "before regenerating the audio inventory."
        )
    return candidates[0]


def ffmpeg_identity(ffmpeg: Path) -> tuple[str, str]:
    completed = subprocess.run(
        [str(ffmpeg), "-hide_banner", "-version"], check=True,
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    version = completed.stdout.splitlines()[0].strip()
    if not version.startswith("ffmpeg version n7.1"):
        raise SystemExit(f"Unexpected FFmpeg encoder: {version}")
    return version, hashlib.sha256(ffmpeg.read_bytes()).hexdigest().upper()


def quantized_loop_frequency(frequency: float, duration: float = MUSIC_DURATION) -> float:
    """Return the nearest tuning that completes an integer cycle per loop."""
    return max(1, round(frequency * duration)) / duration


def music_frequency(root_hz: float, semitones: float) -> float:
    return root_hz * (2.0 ** (semitones / 12.0))


def music_wave(np, local, frequency: float, timbre: str, phase_offset: float = 0.0):
    phase = TAU * frequency * local + phase_offset
    if timbre == "silk":
        return (np.sin(phase) + 0.34 * np.sin(phase * 2.0 + 0.08) +
                0.13 * np.sin(phase * 3.0 + 0.16)) / 1.47
    if timbre == "brass":
        source = (np.sin(phase) + 0.42 * np.sin(phase * 2.0) +
                  0.20 * np.sin(phase * 3.0) + 0.08 * np.sin(phase * 5.0)) / 1.70
        return np.tanh(source * 1.45) / math.tanh(1.45)
    if timbre == "stellar":
        return np.sin(phase + 0.72 * np.sin(phase * 0.503 + 0.31)) * 0.78 + np.sin(phase * 2.01) * 0.12
    if timbre == "dust":
        return (np.sin(phase) + 0.26 * np.sin(phase * 0.501 + 0.4) +
                0.11 * np.sin(phase * 2.0)) / 1.37
    if timbre == "fracture":
        carrier = np.sin(phase + 0.38 * np.sin(phase * 1.997 + 0.2))
        return carrier * (0.78 + 0.22 * np.sin(phase * 0.251) ** 2)
    # Celestial: broad but mono-safe fifth and octave reinforcement.
    return (np.sin(phase) + 0.30 * np.sin(phase * 1.5 + 0.12) +
            0.18 * np.sin(phase * 2.0 + 0.04)) / 1.48


def add_music_note(np, left, right, start: float, duration: float, frequency: float,
                   gain: float, timbre: str, pan: float = 0.0,
                   decay: float = 0.0, phase_offset: float = 0.0) -> None:
    begin = max(0, round(start * SAMPLE_RATE))
    end = min(len(left), round((start + duration) * SAMPLE_RATE))
    if end <= begin:
        return
    local = np.arange(end - begin, dtype=np.float64) / SAMPLE_RATE
    attack = min(0.055, max(0.008, duration * 0.16))
    release = min(0.22, max(0.025, duration * 0.30))
    attack_value = np.clip(local / attack, 0.0, 1.0)
    release_value = np.clip((duration - local) / release, 0.0, 1.0)
    envelope = attack_value * attack_value * (3.0 - 2.0 * attack_value)
    envelope *= release_value * release_value * (3.0 - 2.0 * release_value)
    if decay > 0.0:
        envelope *= np.exp(-local * decay)
    source = music_wave(np, local, frequency, timbre, phase_offset) * envelope * gain
    # Most energy stays correlated for reliable mono fold-down; the quiet,
    # detuned component provides width without becoming a gameplay cue.
    width = np.sin(TAU * frequency * 1.0015 * local + phase_offset + 0.17) * envelope * gain * 0.07
    left_gain = math.sqrt(max(0.0, (1.0 - pan) * 0.5)) * math.sqrt(2.0)
    right_gain = math.sqrt(max(0.0, (1.0 + pan) * 0.5)) * math.sqrt(2.0)
    left[begin:end] += (source * left_gain + width * 0.35).astype(np.float32)
    right[begin:end] += (source * right_gain - width * 0.35).astype(np.float32)


def add_kick(np, left, right, start: float, gain: float, material: str) -> None:
    duration = 0.34 if material != "dust" else 0.46
    begin = round(start * SAMPLE_RATE)
    end = min(len(left), begin + round(duration * SAMPLE_RATE))
    if end <= begin:
        return
    local = np.arange(end - begin, dtype=np.float64) / SAMPLE_RATE
    start_hz = 112.0 if material in {"stellar", "fracture"} else 88.0
    end_hz = 42.0 if material != "brass" else 48.0
    sweep = (start_hz - end_hz) / duration
    phase = TAU * (start_hz * local - 0.5 * sweep * local * local)
    envelope = np.sin(np.clip(local / 0.008, 0.0, 1.0) * math.pi * 0.5) * np.exp(-local * 13.0)
    source = np.sin(phase) * envelope * gain
    left[begin:end] += source.astype(np.float32)
    right[begin:end] += (source * 0.98).astype(np.float32)


def add_noise_hit(np, left, right, start: float, gain: float, rng, material: str) -> None:
    duration = 0.18 if material not in {"celestial", "dust"} else 0.28
    begin = round(start * SAMPLE_RATE)
    end = min(len(left), begin + round(duration * SAMPLE_RATE))
    if end <= begin:
        return
    local = np.arange(end - begin, dtype=np.float64) / SAMPLE_RATE
    noise = rng.standard_normal(end - begin)
    high = noise - np.concatenate(([0.0], noise[:-1])) * 0.88
    envelope = np.sin(np.clip(local / 0.006, 0.0, 1.0) * math.pi * 0.5) * np.exp(-local * 18.0)
    if material == "brass":
        high += np.sin(TAU * 1460.0 * local) * np.exp(-local * 22.0) * 0.55
    elif material == "celestial":
        high += np.sin(TAU * 1180.0 * local) * np.exp(-local * 9.0) * 0.42
    elif material == "fracture":
        high *= 0.62 + 0.38 * (np.sin(TAU * 31.0 * local) > 0.0)
    source = high * envelope * gain
    left[begin:end] += source.astype(np.float32)
    right[begin:end] += (source * 0.84).astype(np.float32)


def soundscape_asset_id(era_id: str, location: str, layer: str) -> str:
    if layer == "bed":
        if location == "world":
            return "classical_ambience" if era_id == "classical" else f"{era_id}_ambience"
        return f"{era_id}_dungeon_ambience"
    return f"{era_id}_{location}_detail"


def add_weather_swell(np, left, right, start: float, duration: float,
                      gain: float, rng, timbre: str, pan: float) -> None:
    begin = max(0, round(start * SAMPLE_RATE))
    end = min(len(left), round((start + duration) * SAMPLE_RATE))
    if end <= begin:
        return
    local = np.arange(end - begin, dtype=np.float64) / SAMPLE_RATE
    noise = rng.standard_normal(end - begin)
    kernel_size = {"silk": 36, "brass": 8, "stellar": 18, "dust": 64,
                   "fracture": 12, "celestial": 28}[timbre]
    kernel = np.ones(kernel_size, dtype=np.float64) / kernel_size
    coloured = np.convolve(noise, kernel, mode="same")
    coloured /= max(float(np.max(np.abs(coloured))), 1e-9)
    attack = np.clip(local / min(0.35, duration * 0.22), 0.0, 1.0)
    release = np.clip((duration - local) / min(0.65, duration * 0.32), 0.0, 1.0)
    envelope = np.sin(attack * math.pi * 0.5) * np.sin(release * math.pi * 0.5)
    if timbre == "brass":
        coloured += np.sin(TAU * 780.0 * local) * 0.18
    elif timbre == "stellar":
        coloured += np.sin(TAU * (1320.0 + 170.0 * np.sin(TAU * 0.7 * local)) * local) * 0.12
    elif timbre == "fracture":
        coloured *= 0.68 + 0.32 * (np.sin(TAU * 17.0 * local) > -0.15)
    elif timbre == "celestial":
        coloured += np.sin(TAU * 920.0 * local) * 0.10
    source = coloured * envelope * gain
    left_gain = math.sqrt(max(0.0, (1.0 - pan) * 0.5)) * math.sqrt(2.0)
    right_gain = math.sqrt(max(0.0, (1.0 + pan) * 0.5)) * math.sqrt(2.0)
    left[begin:end] += (source * left_gain).astype(np.float32)
    right[begin:end] += (source * right_gain).astype(np.float32)


def create_soundscape(np, era_id: str, location: str, layer: str):
    profile = ERA_AMBIENCE[era_id]
    music_profile = ERA_MUSIC[era_id]
    timbre = str(music_profile["timbre"])
    count = round(SOUNDSCAPE_DURATION * SAMPLE_RATE)
    left = np.zeros(count, dtype=np.float32)
    right = np.zeros(count, dtype=np.float32)
    t = np.arange(count, dtype=np.float64) / SAMPLE_RATE
    seed = int(music_profile["seed"]) + (31_337 if location == "dungeon" else 0) + (
        73_001 if layer == "weather_points" else 0
    )
    rng = np.random.default_rng(seed)
    location_scale = 0.72 if location == "dungeon" else 1.0
    brightness = float(profile["brightness"]) * (0.72 if location == "dungeon" else 1.0)

    oscillator_count = 12 if layer == "bed" else 5
    for oscillator in range(oscillator_count):
        harmonic = int(rng.integers(5, 1450 if layer == "bed" else 2400))
        cycles = max(1, round(harmonic * float(profile["tone_scale"]) * location_scale))
        frequency = cycles / SOUNDSCAPE_DURATION
        amplitude = float(rng.uniform(0.006, 0.022)) / (
            1.0 + frequency / (180.0 + 420.0 * brightness)
        )
        if layer == "weather_points":
            amplitude *= 0.42
        phase = float(rng.uniform(0.0, TAU))
        pan = float(rng.uniform(-0.64, 0.64))
        motion_cycles = 2 + (oscillator * 3 + ERA_IDS.index(era_id)) % 17
        motion = 0.78 + 0.22 * np.cos(TAU * motion_cycles * t / SOUNDSCAPE_DURATION + phase * 0.3)
        source = np.sin(TAU * frequency * t + phase) * amplitude * motion
        left += (source * (1.0 - max(0.0, pan))).astype(np.float32)
        right += (source * (1.0 + min(0.0, pan))).astype(np.float32)

    pulse_cycles = int(profile["pulse_cycles"]) * (2 if location == "dungeon" else 1)
    pulse_frequency = max(1, pulse_cycles) / SOUNDSCAPE_DURATION
    pulse_gain = 0.012 if layer == "bed" else 0.005
    pulse = np.cos(TAU * pulse_frequency * t) * pulse_gain
    left += pulse.astype(np.float32)
    right += (pulse * 0.94).astype(np.float32)

    motif = tuple(profile["motif"])
    if layer == "bed":
        # Eight widely spaced signatures keep the 64-second bed identifiable
        # without turning ambience into a second melody track.
        for point in range(8):
            start = 3.4 + point * 7.25 + (ERA_IDS.index(era_id) % 3) * 0.37
            frequency = float(motif[(point + (1 if location == "dungeon" else 0)) % len(motif)])
            if location == "dungeon":
                frequency *= 0.5
            add_music_note(np, left, right, start, 1.45, frequency,
                           0.020 if location == "world" else 0.017,
                           timbre, -0.48 if point % 2 else 0.48, decay=1.05)
    else:
        # The detail layer combines weather motion with sparse point gestures.
        # All events stay clear of the loop boundary, so the layer remains
        # sample-periodic while still conveying distance and changing space.
        for point in range(10):
            start = 2.6 + point * 5.85 + float(rng.uniform(-0.65, 0.65))
            duration = float(rng.uniform(0.75, 2.15))
            pan = float(rng.uniform(-0.78, 0.78))
            add_weather_swell(np, left, right, start, duration,
                              0.018 if location == "world" else 0.014,
                              rng, timbre, pan)
            if point % 2 == 0:
                frequency = float(motif[(point // 2 + 1) % len(motif)])
                frequency *= 1.25 if location == "world" else 0.625
                add_music_note(np, left, right, start + duration * 0.42, 0.72,
                               frequency, 0.012, timbre, -pan * 0.7, decay=2.1)
    return left, right


def normalize_soundscape(np, left, right, target_rms: float,
                         peak_ceiling: float) -> tuple[float, float, float]:
    left -= np.float32(np.mean(left, dtype=np.float64))
    right -= np.float32(np.mean(right, dtype=np.float64))
    rms = math.sqrt(float((np.mean(left.astype(np.float64) ** 2) +
                           np.mean(right.astype(np.float64) ** 2)) * 0.5))
    scale = target_rms / max(rms, 1e-9)
    peak = max(float(np.max(np.abs(left))), float(np.max(np.abs(right))), 1e-9)
    scale = min(scale, peak_ceiling / peak)
    np.multiply(left, scale, out=left)
    np.multiply(right, scale, out=right)
    close_music_loop(np, left, right)
    peak = max(float(np.max(np.abs(left))), float(np.max(np.abs(right))), 1e-9)
    rms = math.sqrt(float((np.mean(left.astype(np.float64) ** 2) +
                           np.mean(right.astype(np.float64) ** 2)) * 0.5))
    dc = max(abs(float(np.mean(left, dtype=np.float64))),
             abs(float(np.mean(right, dtype=np.float64))))
    return peak, rms, dc


def create_music_base(np, era_id: str):
    profile = ERA_MUSIC[era_id]
    count = round(MUSIC_DURATION * SAMPLE_RATE)
    left = np.zeros(count, dtype=np.float32)
    right = np.zeros(count, dtype=np.float32)
    t = np.arange(count, dtype=np.float64) / SAMPLE_RATE
    root_hz = float(profile["root_hz"])
    timbre = str(profile["timbre"])
    drone_gain = float(profile["drone_gain"])
    motion_cycles = 3 + ERA_IDS.index(era_id) * 2
    motion = 0.86 + 0.14 * np.cos(TAU * motion_cycles * t / MUSIC_DURATION)
    drone_root = quantized_loop_frequency(root_hz * 0.5)
    drone_fifth = quantized_loop_frequency(root_hz * 0.75)
    source = (np.cos(TAU * drone_root * t) * 0.66 +
              np.cos(TAU * drone_fifth * t) * 0.34) * motion * drone_gain
    if timbre == "brass":
        source = np.tanh(source * 8.0) / 8.0
    elif timbre == "stellar":
        source += np.cos(TAU * quantized_loop_frequency(root_hz * 2.0) * t) * 0.010 * motion
    elif timbre == "dust":
        source *= 0.78 + 0.22 * np.cos(TAU * 5.0 * t / MUSIC_DURATION) ** 2
    elif timbre == "fracture":
        source *= 0.68 + 0.32 * np.cos(TAU * 22.0 * t / MUSIC_DURATION) ** 6
    elif timbre == "celestial":
        source += np.cos(TAU * quantized_loop_frequency(root_hz * 1.5) * t) * 0.014 * motion
    left += source.astype(np.float32)
    right += (source * 0.96).astype(np.float32)

    progression = tuple(profile["progression"])
    third = int(profile["mode_third"])
    # Sixteen four-second phrases fill the complete 64-second form.  The
    # gentle overlap keeps the harmony continuous while each note has clean
    # local boundaries for a codec-safe loop.
    for phrase in range(16):
        chord_root = progression[phrase % len(progression)]
        start = phrase * 4.0
        for chord_index, interval in enumerate((0, third, 7)):
            frequency = music_frequency(root_hz, chord_root + interval)
            pan = (-0.32, 0.18, 0.38)[chord_index]
            add_music_note(
                np, left, right, start, 4.0, frequency,
                0.026 / (1.0 + chord_index * 0.12), timbre, pan,
                decay=0.06, phase_offset=chord_index * 0.21,
            )
        if phrase % 2 == 1:
            signature = music_frequency(root_hz, tuple(profile["scale"])[(phrase // 2) % 7] + 12)
            add_music_note(np, left, right, start + 2.75, 1.05, signature,
                           0.024, timbre, 0.42 if phrase % 4 else -0.42, decay=1.2)
    return left, right


def add_music_state_layers(np, left, right, era_id: str, state: str) -> None:
    profile = ERA_MUSIC[era_id]
    root_hz = float(profile["root_hz"])
    scale = tuple(profile["scale"])
    progression = tuple(profile["progression"])
    timbre = str(profile["timbre"])
    state_index = MUSIC_STATES.index(state)
    rng = np.random.default_rng(int(profile["seed"]) + state_index * 10_003)

    interval = (1.0, 0.5, 0.25)[state_index]
    note_duration = (0.82, 0.43, 0.22)[state_index]
    motif_gain = (0.034, 0.041, 0.046)[state_index]
    step_count = int(MUSIC_DURATION / interval)
    era_shift = ERA_IDS.index(era_id)
    for step in range(step_count):
        # State-independent indexing anchors motifs to the same phrase grid;
        # denser states reveal subdivisions instead of restarting the score.
        if state == "exploration" and (step + era_shift) % 7 in {3, 6}:
            continue
        phrase = int((step * interval) // 4.0)
        degree_index = (step * (2 + era_shift) + phrase * 3 + state_index) % len(scale)
        octave = 12 if state == "decisive" and step % 8 in {5, 6} else 0
        semitone = progression[phrase % len(progression)] + scale[degree_index] + octave
        frequency = music_frequency(root_hz, semitone)
        pan = math.sin((step + 1) * (0.71 + era_shift * 0.09)) * (0.32 + state_index * 0.06)
        add_music_note(np, left, right, step * interval, note_duration,
                       frequency, motif_gain, timbre, pan, decay=0.75 + state_index * 0.35)

    if state == "exploration":
        # A slow answering voice creates long-form variation without turning
        # menu reading into a constant wall of melody.
        for phrase in range(8):
            degree = scale[(phrase * 3 + era_shift) % len(scale)] + 12
            add_music_note(np, left, right, phrase * 8.0 + 5.2, 2.15,
                           music_frequency(root_hz, degree), 0.025, timbre,
                           -0.45 if phrase % 2 else 0.45, decay=0.55)
        return

    beat_count = int(MUSIC_DURATION * 2.0)  # 120 BPM
    bass_step = 2 if state == "pressure" else 1
    for beat in range(0, beat_count, bass_step):
        start = beat * 0.5
        phrase = int(start // 4.0)
        semitone = progression[phrase % len(progression)] - 12
        if state == "decisive" and beat % 8 in {6, 7}:
            semitone += 7
        add_music_note(np, left, right, start, 0.38 if state == "pressure" else 0.27,
                       music_frequency(root_hz, semitone),
                       0.050 if state == "pressure" else 0.057,
                       timbre, 0.0, decay=3.2)

    for beat in range(beat_count):
        beat_in_bar = beat % 4
        start = beat * 0.5
        if beat_in_bar in ({0, 2} if state == "pressure" else {0, 1, 2, 3}):
            add_kick(np, left, right, start,
                     0.090 if state == "pressure" else 0.105, timbre)
        if beat_in_bar in {1, 3}:
            add_noise_hit(np, left, right, start,
                          0.018 if state == "pressure" else 0.024, rng, timbre)
        if timbre in {"brass", "stellar", "fracture"} and beat % (4 if state == "pressure" else 2) == 1:
            metal_hz = {"brass": 1160.0, "stellar": 1740.0, "fracture": 920.0}[timbre]
            add_music_note(np, left, right, start + 0.24, 0.13, metal_hz,
                           0.011 if state == "pressure" else 0.016,
                           timbre, 0.30 if beat % 4 == 1 else -0.30, decay=14.0)

    if state == "decisive":
        for phrase in range(16):
            chord_root = progression[phrase % len(progression)]
            for beat in (0.0, 1.5, 3.0):
                add_music_note(np, left, right, phrase * 4.0 + beat, 0.44,
                               music_frequency(root_hz, chord_root + 12),
                               0.035, timbre, -0.18 if beat == 1.5 else 0.18, decay=2.6)


def close_music_loop(np, left, right) -> float:
    # Oscillators and arrangement are already loop-periodic.  This short,
    # sub-audible correction removes the remaining one-sample derivative
    # difference before lossy encoding and records the exact source seam.
    seam_frames = round(0.05 * SAMPLE_RATE)
    ramp = np.linspace(0.0, 1.0, seam_frames, dtype=np.float64)
    ramp = ramp * ramp * (3.0 - 2.0 * ramp)
    left_delta = float(left[0] - left[-1])
    right_delta = float(right[0] - right[-1])
    left[-seam_frames:] += (left_delta * ramp).astype(np.float32)
    right[-seam_frames:] += (right_delta * ramp).astype(np.float32)
    return max(abs(float(left[0] - left[-1])), abs(float(right[0] - right[-1])))


def normalize_music(np, left, right, target_peak: float) -> tuple[float, float, float]:
    left -= np.mean(left, dtype=np.float64).astype(np.float32)
    right -= np.mean(right, dtype=np.float64).astype(np.float32)
    peak = max(float(np.max(np.abs(left))), float(np.max(np.abs(right))), 1e-9)
    scale = target_peak / peak
    np.multiply(left, scale, out=left)
    np.multiply(right, scale, out=right)
    np.clip(left, -0.98, 0.98, out=left)
    np.clip(right, -0.98, 0.98, out=right)
    rms = math.sqrt(float((np.mean(left.astype(np.float64) ** 2) +
                           np.mean(right.astype(np.float64) ** 2)) * 0.5))
    dc = max(abs(float(np.mean(left, dtype=np.float64))),
             abs(float(np.mean(right, dtype=np.float64))))
    return target_peak, rms, dc


def write_wav_numpy(np, path: Path, left, right) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    interleaved = np.empty(left.size * 2, dtype=np.float32)
    interleaved[0::2] = left
    interleaved[1::2] = right
    pcm = np.rint(np.clip(interleaved, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(CHANNELS)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def encode_music_ogg(ffmpeg: Path, master_path: Path, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    command = [
        str(ffmpeg), "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
        "-i", str(master_path), *MUSIC_ENCODE_ARGS, str(output_path),
    ]
    subprocess.run(command, check=True)
    if not output_path.is_file() or output_path.stat().st_size < 16_384:
        raise RuntimeError(f"FFmpeg did not produce a plausible Ogg stream: {output_path}")


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
    np = require_numpy()
    ffmpeg = find_ffmpeg()
    encoder_version, encoder_executable_hash = ffmpeg_identity(ffmpeg)
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    assets = []
    generator_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest().upper()
    jobs = []
    for asset_id, (duration, bus, loop) in SPECS.items():
        era_ids = list(ERA_IDS) if base_asset_id(asset_id) in SHARED_EVENT_BASES else ["classical"]
        jobs.append((asset_id, asset_id, "classical", duration, bus, loop, era_ids))
    for era_id in ERA_IDS[1:]:
        for asset_id, (duration, bus, loop) in SPECS.items():
            if base_asset_id(asset_id) not in ERA_EVENT_BASES:
                continue
            jobs.append((f"{era_id}_{asset_id}", asset_id, era_id, duration, bus, loop, [era_id]))
        jobs.append((f"{era_id}_ambience_seed_slot", f"{era_id}_ambience", era_id,
                     16.0, "Ambience", True, [era_id]))
    # Append new rare cues after the frozen v1 seed sequence.  This preserves
    # every established SFX hash while allowing each later era to replace the
    # former classical fallback with authored material.
    for era_id in ERA_IDS[1:]:
        for asset_id, (duration, bus, loop) in SPECS.items():
            if base_asset_id(asset_id) not in ERA_LOW_FREQUENCY_BASES:
                continue
            jobs.append((f"{era_id}_{asset_id}", asset_id, era_id, duration, bus, loop, [era_id]))
    for index, (manifest_id, asset_id, era_id, duration, bus, loop, era_ids) in enumerate(jobs):
        if loop:
            continue
        left, right = synth_event(asset_id, duration, 710_000 + index, era_id)
        target_peak = 0.68 if base_asset_id(asset_id) in {"impact", "phase_break"} else 0.56
        peak, rms = normalize(left, right, target_peak)
        output = OUTPUT_ROOT / era_id
        path = output / f"{asset_id}.wav"
        write_wav(path, left, right)
        boundary = max(abs(left[0] - left[-1]), abs(right[0] - right[-1])) if loop else 0.0
        event_key = base_asset_id(asset_id)
        assets.append({
            "id": manifest_id,
            "asset_id": manifest_id,
            "file": f"generated/{era_id}/{asset_id}.wav",
            "runtime_path": f"res://audio/generated/{era_id}/{asset_id}.wav",
            "source_master": f"procedural://tools/generate_audio_assets.py#{manifest_id}",
            "kind": "ambience" if loop else "sfx",
            "role": "ambience" if loop else ("ui" if bus == "UI" else "sfx"),
            "bus": bus,
            "era_ids": era_ids,
            "event_ids": EVENT_IDS[event_key],
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
            "release_state": "final",
            "manual_qa_status": "owner_post_release_playtest",
            "generator": "tools/generate_audio_assets.py",
            "generator_and_version": "Python procedural synthesis v2",
        })

    soundscape_target_rms = {"bed": 0.052, "weather_points": 0.031}
    soundscape_peak_ceiling = {"bed": 0.38, "weather_points": 0.28}
    for era_id in ERA_IDS:
        print(f"Designing two-location soundscape layers for {era_id}...")
        for location in SOUNDSCAPE_LOCATIONS:
            for layer in SOUNDSCAPE_LAYERS:
                left, right = create_soundscape(np, era_id, location, layer)
                peak, rms, dc = normalize_soundscape(
                    np, left, right, soundscape_target_rms[layer],
                    soundscape_peak_ceiling[layer],
                )
                boundary = close_music_loop(np, left, right)
                asset_id = soundscape_asset_id(era_id, location, layer)
                master_path = MUSIC_MASTER_ROOT / era_id / f"{asset_id}_master.wav"
                output_path = OUTPUT_ROOT / era_id / f"{asset_id}.ogg"
                write_wav_numpy(np, master_path, left, right)
                encode_music_ogg(ffmpeg, master_path, output_path)
                relative = f"generated/{era_id}/{asset_id}.ogg"
                assets.append({
                    "id": asset_id,
                    "asset_id": asset_id,
                    "file": relative,
                    "runtime_path": f"res://audio/{relative}",
                    "source_master": f"procedural://tools/generate_audio_assets.py#{asset_id}",
                    "source_master_sha256": hashlib.sha256(master_path.read_bytes()).hexdigest().upper(),
                    "kind": "soundscape",
                    "role": "ambience" if layer == "bed" else "ambience_detail",
                    "soundscape_location": location,
                    "soundscape_layer": layer,
                    "bus": "Ambience",
                    "era_ids": [era_id],
                    "event_ids": SOUNDSCAPE_EVENTS[location],
                    "loop": True,
                    "loop_start_sample": 0,
                    "loop_end_sample": len(left),
                    "sample_rate": SAMPLE_RATE,
                    "channels": CHANNELS,
                    "bits_per_sample": None,
                    "codec": "vorbis",
                    "container": "ogg",
                    "streaming": True,
                    "duration": SOUNDSCAPE_DURATION,
                    "peak_dbfs": round(20.0 * math.log10(max(peak, 1e-9)), 3),
                    "rms_dbfs": round(20.0 * math.log10(max(rms, 1e-9)), 3),
                    "source_dc_offset": round(dc, 9),
                    "loop_boundary_delta": round(boundary, 7),
                    "sha256": hashlib.sha256(output_path.read_bytes()).hexdigest().upper(),
                    "license": "LicenseRef-Project-Original",
                    "license_name": "Project-original procedural composition and sound design",
                    "commercial_use": True,
                    "redistribution_in_game": True,
                    "creator_or_vendor": "Wendao Changsheng project",
                    "attribution_text": "Original soundscape created for Wendao Changsheng.",
                    "created_or_acquired_at": "2026-07-17",
                    "release_state": "final",
                    "manual_qa_status": "owner_post_release_playtest",
                    "generator": "tools/generate_audio_assets.py",
                    "generator_and_version": "Python 3.13 + NumPy 2.3.3 procedural soundscape v2",
                    "encoder_and_version": encoder_version,
                    "encoder_executable_sha256": encoder_executable_hash,
                    "encoding_parameters": list(MUSIC_ENCODE_ARGS),
                })
                del left, right

    # v2 soundscapes replace the six short PCM beds.  Removing these known
    # legacy outputs is part of deterministic regeneration, not a wildcard
    # cleanup of user-authored audio.
    for era_id in ERA_IDS:
        legacy_id = "classical_ambience" if era_id == "classical" else f"{era_id}_ambience"
        for suffix in (".wav", ".wav.import"):
            legacy_path = OUTPUT_ROOT / era_id / f"{legacy_id}{suffix}"
            if legacy_path.is_file():
                legacy_path.unlink()

    music_target_peaks = {"exploration": 0.42, "pressure": 0.48, "decisive": 0.54}
    MUSIC_MASTER_ROOT.mkdir(parents=True, exist_ok=True)
    for era_id in ERA_IDS:
        print(f"Composing synchronized music states for {era_id}...")
        base_left, base_right = create_music_base(np, era_id)
        for state in MUSIC_STATES:
            left = base_left.copy()
            right = base_right.copy()
            add_music_state_layers(np, left, right, era_id, state)
            close_music_loop(np, left, right)
            peak, rms, dc = normalize_music(np, left, right, music_target_peaks[state])
            boundary = close_music_loop(np, left, right)
            master_path = MUSIC_MASTER_ROOT / era_id / f"music_{state}_master.wav"
            output_path = OUTPUT_ROOT / era_id / f"music_{state}.ogg"
            write_wav_numpy(np, master_path, left, right)
            encode_music_ogg(ffmpeg, master_path, output_path)
            manifest_id = f"{era_id}_music_{state}"
            relative = f"generated/{era_id}/music_{state}.ogg"
            assets.append({
                "id": manifest_id,
                "asset_id": manifest_id,
                "file": relative,
                "runtime_path": f"res://audio/{relative}",
                "source_master": f"procedural://tools/generate_audio_assets.py#{manifest_id}",
                "source_master_sha256": hashlib.sha256(master_path.read_bytes()).hexdigest().upper(),
                "kind": "music",
                "role": "music",
                "music_state": state,
                "bus": "Music",
                "era_ids": [era_id],
                "event_ids": [f"music.{state}"],
                "loop": True,
                "loop_start_sample": 0,
                "loop_end_sample": len(left),
                "sample_rate": SAMPLE_RATE,
                "channels": CHANNELS,
                "bits_per_sample": None,
                "codec": "vorbis",
                "container": "ogg",
                "streaming": True,
                "duration": MUSIC_DURATION,
                "tempo_bpm": 120,
                "bar_beats": 4,
                "bar_count": 32,
                "peak_dbfs": round(20.0 * math.log10(max(peak, 1e-9)), 3),
                "rms_dbfs": round(20.0 * math.log10(max(rms, 1e-9)), 3),
                "source_dc_offset": round(dc, 9),
                "loop_boundary_delta": round(boundary, 7),
                "sha256": hashlib.sha256(output_path.read_bytes()).hexdigest().upper(),
                "license": "LicenseRef-Project-Original",
                "license_name": "Project-original procedural composition and sound design",
                "commercial_use": True,
                "redistribution_in_game": True,
                "creator_or_vendor": "Wendao Changsheng project",
                "attribution_text": "Original music created for Wendao Changsheng.",
                "created_or_acquired_at": "2026-07-17",
                "release_state": "final",
                "manual_qa_status": "owner_post_release_playtest",
                "generator": "tools/generate_audio_assets.py",
                "generator_and_version": "Python 3.13 + NumPy 2.3.3 procedural composition v2",
                "encoder_and_version": encoder_version,
                "encoder_executable_sha256": encoder_executable_hash,
                "encoding_parameters": list(MUSIC_ENCODE_ARGS),
            })
            del left, right
        del base_left, base_right
    manifest = {
        "version": 1,
        "generator_sha256": generator_hash,
        "asset_root": "res://audio/",
        "music_sync": {
            "duration_seconds": MUSIC_DURATION,
            "sample_rate": SAMPLE_RATE,
            "tempo_bpm": 120,
            "bar_beats": 4,
            "bar_count": 32,
            "states": list(MUSIC_STATES),
        },
        "soundscape_contract": {
            "duration_seconds": SOUNDSCAPE_DURATION,
            "sample_rate": SAMPLE_RATE,
            "locations": list(SOUNDSCAPE_LOCATIONS),
            "layers": list(SOUNDSCAPE_LAYERS),
            "per_era_asset_count": len(SOUNDSCAPE_LOCATIONS) * len(SOUNDSCAPE_LAYERS),
        },
        "stream_encoder": {
            "archive": "ffmpeg-n7.1-latest-win64-lgpl-7.1.zip",
            "archive_sha256": "985B3477E9A07399675F5923DCFDF57BAE41B3EC0A7B2AD61D9BE5E2DA30C6B3",
            "version": encoder_version,
            "executable_sha256": encoder_executable_hash,
            "parameters": list(MUSIC_ENCODE_ARGS),
            "numpy_version": np.__version__,
        },
        "assets": assets,
    }
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"Generated {len(assets)} original audio assets, including "
        f"{len(ERA_IDS) * len(MUSIC_STATES)} synchronized Ogg music loops and "
        f"{len(ERA_IDS) * len(SOUNDSCAPE_LOCATIONS) * len(SOUNDSCAPE_LAYERS)} layered soundscapes, "
        f"across {len(ERA_IDS)} eras in {OUTPUT_ROOT}"
    )


if __name__ == "__main__":
    main()
