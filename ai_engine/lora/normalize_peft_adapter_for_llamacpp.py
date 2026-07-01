#!/usr/bin/env python3
import argparse
import json
import shutil
from pathlib import Path

from safetensors.torch import load_file, save_file


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--adapter-dir", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--skip-substrings", default="audio_tower,vision_tower")
    parser.add_argument("--strip-linear-wrapper", action="store_true", default=True)
    return parser.parse_args()


def normalize_key(key, strip_linear_wrapper):
    if strip_linear_wrapper:
        key = key.replace(".linear.lora_A.weight", ".lora_A.weight")
        key = key.replace(".linear.lora_B.weight", ".lora_B.weight")
    return key


def main():
    args = parse_args()
    src = Path(args.adapter_dir)
    dst = Path(args.out_dir)
    skips = [item.strip() for item in args.skip_substrings.split(",") if item.strip()]

    if not (src / "adapter_config.json").is_file():
        raise FileNotFoundError(src / "adapter_config.json")
    if not (src / "adapter_model.safetensors").is_file():
        raise FileNotFoundError(src / "adapter_model.safetensors")

    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True)

    for item in src.iterdir():
        if item.name in {"adapter_model.safetensors", "wendao_gemma4_lora.gguf"}:
            continue
        if item.is_file():
            shutil.copy2(item, dst / item.name)

    config_path = dst / "adapter_config.json"
    config = json.loads(config_path.read_text(encoding="utf-8"))
    config["target_modules"] = [
        module.replace(".linear", "")
        for module in config.get("target_modules", [])
    ]
    config["exclude_modules"] = ".*audio_tower.*"
    config_path.write_text(
        json.dumps(config, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    tensors = load_file(src / "adapter_model.safetensors", device="cpu")
    normalized = {}
    skipped = 0
    renamed = 0
    for key, tensor in tensors.items():
        if any(fragment in key for fragment in skips):
            skipped += 1
            continue
        new_key = normalize_key(key, args.strip_linear_wrapper)
        if new_key != key:
            renamed += 1
        if new_key in normalized:
            raise RuntimeError(f"duplicate normalized tensor key: {new_key}")
        normalized[new_key] = tensor

    save_file(normalized, dst / "adapter_model.safetensors")
    print(
        f"wrote {dst}: kept={len(normalized)} skipped={skipped} renamed={renamed}",
        flush=True,
    )


if __name__ == "__main__":
    main()
