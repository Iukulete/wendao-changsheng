#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-$HOME/wendao_lora}"
CONTAINER_ADAPTER_DIR="${CONTAINER_ADAPTER_DIR:-/workspace/out/wendao_gemma4_lora}"
CONTAINER_EXPORT_DIR="${CONTAINER_EXPORT_DIR:-/workspace/out/wendao_gemma4_lora_llamacpp}"
CONTAINER_OUTFILE="${CONTAINER_OUTFILE:-/workspace/out/wendao_gemma4_lora_llamacpp/wendao_gemma4_lora.gguf}"
CONTAINER_VENV="${CONTAINER_VENV:-/workspace/.eval_venv}"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

docker run --rm -i \
  -v "$WORK_DIR:/workspace" \
  -v "$HOME/.cache/huggingface:/hf-cache" \
  -v "$HOME/.cache/pip:/root/.cache/pip" \
  -v "$HOME/llama.cpp:/llama.cpp" \
  -e HF_HOME=/hf-cache \
  -e HF_ENDPOINT=https://hf-mirror.com \
  -e TRANSFORMERS_CACHE=/hf-cache/hub \
  -e CONTAINER_ADAPTER_DIR="$CONTAINER_ADAPTER_DIR" \
  -e CONTAINER_EXPORT_DIR="$CONTAINER_EXPORT_DIR" \
  -e CONTAINER_OUTFILE="$CONTAINER_OUTFILE" \
  -e CONTAINER_VENV="$CONTAINER_VENV" \
  -e HOST_UID="$HOST_UID" \
  -e HOST_GID="$HOST_GID" \
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
"$CONTAINER_VENV/bin/python" -m pip install --index-url https://download.pytorch.org/whl/cu124 torch
"$CONTAINER_VENV/bin/python" -m pip install safetensors transformers huggingface_hub sentencepiece protobuf

"$CONTAINER_VENV/bin/python" /workspace/scripts/normalize_peft_adapter_for_llamacpp.py \
  --adapter-dir "$CONTAINER_ADAPTER_DIR" \
  --out-dir "$CONTAINER_EXPORT_DIR" \
  --drop-gemma4-shared-kv

"$CONTAINER_VENV/bin/python" /llama.cpp/convert_lora_to_gguf.py \
  "$CONTAINER_EXPORT_DIR" \
  --outfile "$CONTAINER_OUTFILE"

gguf_bytes="$(wc -c < "$CONTAINER_OUTFILE" || echo 0)"
if [ "$gguf_bytes" -lt 4096 ]; then
  echo "error: GGUF LoRA export is only ${gguf_bytes} bytes, likely metadata-only." >&2
  exit 2
fi

echo "GGUF LoRA export ok: $CONTAINER_OUTFILE (${gguf_bytes} bytes)"
chown -R "$HOST_UID:$HOST_GID" /workspace/out || true
CONTAINER_SH
