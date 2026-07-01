#!/usr/bin/env python3
import argparse
from collections import Counter
from pathlib import Path

from safetensors import safe_open


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("file")
    parser.add_argument("--contains", default="")
    parser.add_argument("--limit", type=int, default=80)
    return parser.parse_args()


def main():
    args = parse_args()
    path = Path(args.file)
    with safe_open(path, framework="pt", device="cpu") as tensors:
        keys = list(tensors.keys())

    matches = [key for key in keys if args.contains in key]
    print(f"total_keys={len(keys)} matches={len(matches)} contains={args.contains!r}")
    for key in matches[: args.limit]:
        print(key)

    prefixes = Counter()
    for key in matches:
        if ".layers." in key:
            prefixes[key.split(".layers.", 1)[0]] += 1
    if prefixes:
        print("layer_prefixes:")
        for prefix, count in prefixes.most_common(32):
            print(f"  {count:5d} {prefix}")


if __name__ == "__main__":
    main()
