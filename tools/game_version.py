#!/usr/bin/env python3
"""Read the custom S.X.Y game version without SemVer/integer normalization."""
from __future__ import annotations

import argparse
import configparser
import json
from pathlib import Path
import re

PROJECT = Path(__file__).resolve().parents[1] / "godot/project.godot"
VERSION_PATTERN = re.compile(r"(?:0|[1-9][0-9]*)\.[0-9]\.[0-9]{3}")


def read_version(project: Path = PROJECT) -> str:
    # ConfigFile's top-level engine config_version precedes the sections.
    config = configparser.ConfigParser(interpolation=None, strict=True)
    config.read_string("[engine]\n" + project.read_text(encoding="utf-8"))
    version = json.loads(config["application"]["config/version"])
    if not isinstance(version, str) or VERSION_PATTERN.fullmatch(version) is None:
        raise ValueError("Game version must be a quoted S.X.Y string: S>=0, X=0..9, Y=000..999")
    return version


def metadata(project: Path = PROJECT) -> dict[str, str]:
    return {"game_version": read_version(project), "version_scheme": "S.X.Y"}


def verify_manifest(path: Path, project: Path = PROJECT) -> None:
    actual = json.loads(path.read_text(encoding="utf-8"))
    if actual != metadata(project):
        raise ValueError("Release game-version.json does not match the project version metadata")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=PROJECT)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write", type=Path)
    mode.add_argument("--verify", type=Path)
    args = parser.parse_args()
    value = metadata(args.project)
    if args.write:
        args.write.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    if args.verify:
        verify_manifest(args.verify, args.project)
    print(value["game_version"])


if __name__ == "__main__":
    main()
