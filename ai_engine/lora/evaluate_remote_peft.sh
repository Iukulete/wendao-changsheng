#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-$HOME/wendao_lora}"
MODEL_ID="${MODEL_ID:-google/gemma-4-E4B-it-qat-q4_0-unquantized}"
CONTAINER_ADAPTER_DIR="${CONTAINER_ADAPTER_DIR:-/workspace/out/wendao_gemma4_lora_text_v7_codex_unsloth}"
CONTAINER_OUT_FILE="${CONTAINER_OUT_FILE:-/workspace/out/wendao_gemma4_lora_text_v7_codex_unsloth/peft_quality_eval.txt}"
CONTAINER_VENV="${CONTAINER_VENV:-/workspace/.unsloth_venv}"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

GPU_DEVICES=(
  --device /dev/nvidia0
  --device /dev/nvidiactl
  --device /dev/nvidia-uvm
  --device /dev/nvidia-uvm-tools
  --device /dev/nvidia-modeset
)
if [[ -e /dev/nvidia-caps/nvidia-cap1 ]]; then
  GPU_DEVICES+=(--device /dev/nvidia-caps/nvidia-cap1)
fi
if [[ -e /dev/nvidia-caps/nvidia-cap2 ]]; then
  GPU_DEVICES+=(--device /dev/nvidia-caps/nvidia-cap2)
fi

docker run --rm -i \
  "${GPU_DEVICES[@]}" \
  -v /usr/lib/x86_64-linux-gnu:/host-libs:ro \
  -v "$WORK_DIR:/workspace" \
  -v "$HOME/.cache/huggingface:/hf-cache" \
  -v "$HOME/.cache/pip:/root/.cache/pip" \
  -e HF_HOME=/hf-cache \
  -e HF_ENDPOINT=https://hf-mirror.com \
  -e TRANSFORMERS_CACHE=/hf-cache/hub \
  -e HF_XET_HIGH_PERFORMANCE=1 \
  -e PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  -e TOKENIZERS_PARALLELISM=false \
  -e MODEL_ID="$MODEL_ID" \
  -e CONTAINER_ADAPTER_DIR="$CONTAINER_ADAPTER_DIR" \
  -e CONTAINER_OUT_FILE="$CONTAINER_OUT_FILE" \
  -e CONTAINER_VENV="$CONTAINER_VENV" \
  -e HOST_UID="$HOST_UID" \
  -e HOST_GID="$HOST_GID" \
  nvidia/cuda:12.4.1-devel-ubuntu22.04 \
  bash <<'CONTAINER_SH'
set -euo pipefail

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip python3-venv git ca-certificates
mkdir -p /root/.cache/pip
chown -R root:root /root/.cache/pip || true

if [ ! -x "$CONTAINER_VENV/bin/python" ]; then
  python3 -m venv "$CONTAINER_VENV"
fi

if ! "$CONTAINER_VENV/bin/python" -c "import torch, transformers, peft, bitsandbytes, unsloth" >/dev/null 2>&1; then
  "$CONTAINER_VENV/bin/python" -m pip install --upgrade pip
  "$CONTAINER_VENV/bin/python" -m pip install --index-url https://download.pytorch.org/whl/cu124 torch
  "$CONTAINER_VENV/bin/python" -m pip install -U unsloth trl datasets accelerate peft bitsandbytes safetensors sentencepiece protobuf hf_transfer 'huggingface_hub[hf_xet]'
fi

export LD_LIBRARY_PATH=/host-libs:/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}

adapter_args=()
if [ -n "${CONTAINER_ADAPTER_DIR:-}" ]; then
  adapter_args=(--adapter-dir "$CONTAINER_ADAPTER_DIR")
fi

"$CONTAINER_VENV/bin/python" /workspace/scripts/evaluate_peft_adapter.py \
  --model-id "$MODEL_ID" \
  "${adapter_args[@]}" \
  --out-file "$CONTAINER_OUT_FILE" \
  --loader unsloth \
  --max-seq-length 2048 \
  --load-in-4bit

chown -R "$HOST_UID:$HOST_GID" /workspace/out /workspace/logs || true
CONTAINER_SH
