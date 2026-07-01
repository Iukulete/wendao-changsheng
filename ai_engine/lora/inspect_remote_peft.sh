#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-$HOME/wendao_lora}"
CONTAINER_ADAPTER_DIR="${CONTAINER_ADAPTER_DIR:-/workspace/out/wendao_gemma4_lora}"
CONTAINER_CONVERTER="${CONTAINER_CONVERTER:-/llama.cpp/convert_lora_to_gguf.py}"
CONTAINER_VENV="${CONTAINER_VENV:-/workspace/.eval_venv}"

docker run --rm -i \
  -v "$WORK_DIR:/workspace" \
  -v "$HOME/.cache/pip:/root/.cache/pip" \
  -v "$HOME/llama.cpp:/llama.cpp" \
  -e CONTAINER_ADAPTER_DIR="$CONTAINER_ADAPTER_DIR" \
  -e CONTAINER_CONVERTER="$CONTAINER_CONVERTER" \
  -e CONTAINER_VENV="$CONTAINER_VENV" \
  nvidia/cuda:12.4.1-devel-ubuntu22.04 \
  bash <<'CONTAINER_SH'
set -euo pipefail

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip python3-venv ca-certificates
mkdir -p /root/.cache/pip
chown -R root:root /root/.cache/pip || true

if [ ! -x "$CONTAINER_VENV/bin/python" ]; then
  python3 -m venv "$CONTAINER_VENV"
fi

"$CONTAINER_VENV/bin/python" -m pip install --upgrade pip
"$CONTAINER_VENV/bin/python" -m pip install safetensors

"$CONTAINER_VENV/bin/python" /workspace/scripts/inspect_peft_adapter.py \
  --adapter-dir "$CONTAINER_ADAPTER_DIR" \
  --converter "$CONTAINER_CONVERTER"
CONTAINER_SH
