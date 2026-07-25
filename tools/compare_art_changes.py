#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def walk(old: object, new: object, path: str = "") -> None:
    if isinstance(old, dict) and isinstance(new, dict):
        for key in old.keys() & new.keys():
            if key == "portrait" and old[key] != new[key]:
                print(path, old[key], "->", new[key])
            else:
                walk(old[key], new[key], path + "/" + str(key))
    elif isinstance(old, list) and isinstance(new, list):
        for index, (old_value, new_value) in enumerate(zip(old, new)):
            walk(old_value, new_value, path + "/" + str(index))


for relative in ("godot/data/events_v014.json", "godot/data/story_arcs_v1.json"):
    old = json.loads(
        subprocess.check_output(
            ["git", "show", "HEAD:" + relative], cwd=ROOT, text=True, encoding="utf-8"
        )
    )
    new = json.loads((ROOT / relative).read_text(encoding="utf-8"))
    print("\n" + relative)
    walk(old, new)
