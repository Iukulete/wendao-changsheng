#!/usr/bin/env python3
import argparse
import json
from collections import Counter
from pathlib import Path

from safetensors.torch import safe_open


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--adapter-dir", required=True)
    parser.add_argument("--converter", default="")
    parser.add_argument("--limit", type=int, default=48)
    return parser.parse_args()


def main():
    args = parse_args()
    adapter_dir = Path(args.adapter_dir)
    config_path = adapter_dir / "adapter_config.json"
    tensor_path = adapter_dir / "adapter_model.safetensors"

    config = json.loads(config_path.read_text(encoding="utf-8"))
    print("base_model:", config.get("base_model_name_or_path"))
    print("target_modules:", ", ".join(config.get("target_modules", [])))
    print("rank:", config.get("r"), "alpha:", config.get("lora_alpha"))

    with safe_open(tensor_path, framework="pt", device="cpu") as tensors:
        keys = list(tensors.keys())
        print("tensor_count:", len(keys))
        for key in keys[: args.limit]:
            print("key:", key, "shape:", tuple(tensors.get_tensor(key).shape))

    suffixes = Counter()
    for key in keys:
        parts = key.split(".")
        if len(parts) >= 4:
            suffixes[".".join(parts[-4:])] += 1
    print("suffix_summary:")
    for suffix, count in suffixes.most_common(24):
        print(f"  {count:4d} {suffix}")

    if args.converter:
        converter = Path(args.converter)
        text = converter.read_text(encoding="utf-8", errors="ignore")
        print("converter:", converter)
        for needle in [
            "q_proj",
            "q_proj.linear",
            "language_model",
            "Gemma4",
            "Gemma",
            "adapter_model",
        ]:
            print(f"converter_has {needle!r}:", needle in text)


if __name__ == "__main__":
    main()
