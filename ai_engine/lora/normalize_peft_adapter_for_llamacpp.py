#!/usr/bin/env python3
import argparse
import json
import re
import shutil
from pathlib import Path

from safetensors.torch import load_file, save_file


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--adapter-dir", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--skip-substrings", default="audio_tower,vision_tower")
    parser.add_argument("--strip-linear-wrapper", action="store_true", default=True)
    parser.add_argument(
        "--drop-gemma4-shared-kv",
        action="store_true",
        help=(
            "Drop Gemma4 LoRA K/V tensors for layers that share K/V weights in the "
            "base GGUF. Gemma 4 E4B has no standalone attn_k/attn_v tensors from "
            "layer 24 onward, and llama.cpp rejects adapters containing them."
        ),
    )
    parser.add_argument("--gemma4-shared-kv-start", type=int, default=24)
    return parser.parse_args()


def normalize_key(key, strip_linear_wrapper):
    if strip_linear_wrapper:
        key = key.replace(".linear.lora_A.weight", ".lora_A.weight")
        key = key.replace(".linear.lora_B.weight", ".lora_B.weight")
    return key


def is_gemma4_missing_shared_kv_key(key, start_layer):
    match = re.search(r"(?:^|\.)(?:layers|blk)\.(\d+)\.", key)
    if match is None:
        return False
    layer = int(match.group(1))
    if layer < start_layer:
        return False
    return (
        ".self_attn.k_proj." in key
        or ".self_attn.v_proj." in key
        or ".attn_k.weight." in key
        or ".attn_v.weight." in key
    )


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
    shared_kv_skipped = 0
    renamed = 0
    for key, tensor in tensors.items():
        if any(fragment in key for fragment in skips):
            skipped += 1
            continue
        if args.drop_gemma4_shared_kv and is_gemma4_missing_shared_kv_key(
            key,
            args.gemma4_shared_kv_start,
        ):
            shared_kv_skipped += 1
            continue
        new_key = normalize_key(key, args.strip_linear_wrapper)
        if args.drop_gemma4_shared_kv and is_gemma4_missing_shared_kv_key(
            new_key,
            args.gemma4_shared_kv_start,
        ):
            shared_kv_skipped += 1
            continue
        if new_key != key:
            renamed += 1
        if new_key in normalized:
            raise RuntimeError(f"duplicate normalized tensor key: {new_key}")
        normalized[new_key] = tensor

    save_file(normalized, dst / "adapter_model.safetensors")
    print(
        f"wrote {dst}: kept={len(normalized)} skipped={skipped} "
        f"shared_kv_skipped={shared_kv_skipped} renamed={renamed}",
        flush=True,
    )


if __name__ == "__main__":
    main()
