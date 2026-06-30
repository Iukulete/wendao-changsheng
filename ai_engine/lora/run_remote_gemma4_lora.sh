#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-$HOME/wendao_lora}"
MODEL_ID="${MODEL_ID:-google/gemma-4-E4B-it-qat-q4_0-unquantized}"
CONTAINER_OUT_DIR="${CONTAINER_OUT_DIR:-/workspace/out/wendao_gemma4_lora}"
TRAIN_COUNT="${TRAIN_COUNT:-900}"
EVAL_COUNT="${EVAL_COUNT:-90}"
EPOCHS="${EPOCHS:-1}"
MAX_LENGTH="${MAX_LENGTH:-768}"
GRAD_ACCUM="${GRAD_ACCUM:-16}"
LORA_R="${LORA_R:-8}"
LORA_ALPHA="${LORA_ALPHA:-16}"

mkdir -p "$WORK_DIR/data" "$WORK_DIR/out" "$WORK_DIR/logs"

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

docker run --rm \
  "${GPU_DEVICES[@]}" \
  -v /usr/lib/x86_64-linux-gnu:/host-libs:ro \
  -v "$WORK_DIR:/workspace" \
  -v "$HOME/.cache/huggingface:/hf-cache" \
  -v "$HOME/.cache/pip:/root/.cache/pip" \
  -v "$HOME/llama.cpp:/llama.cpp" \
  -e HF_HOME=/hf-cache \
  -e HF_ENDPOINT=https://hf-mirror.com \
  -e TRANSFORMERS_CACHE=/hf-cache/hub \
  -e HF_XET_HIGH_PERFORMANCE=1 \
  -e PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  -e TOKENIZERS_PARALLELISM=false \
  nvidia/cuda:12.4.1-devel-ubuntu22.04 \
  bash -lc "
    set -euo pipefail
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip python3-venv git ca-certificates
    mkdir -p /root/.cache/pip
    chown -R root:root /root/.cache/pip || true
    python3 -m pip install --upgrade pip
    python3 -m pip install --index-url https://download.pytorch.org/whl/cu124 torch
    python3 -m pip install 'transformers>=4.56.0' accelerate peft bitsandbytes safetensors sentencepiece protobuf hf_transfer 'huggingface_hub[hf_xet]'
    export LD_LIBRARY_PATH=/host-libs:/usr/local/cuda/lib64:\${LD_LIBRARY_PATH:-}
    python3 /workspace/scripts/build_wendao_lora_dataset.py --out-dir /workspace/data --train-count '$TRAIN_COUNT' --eval-count '$EVAL_COUNT'
    python3 /workspace/scripts/train_gemma4_lora.py \
      --model-id '$MODEL_ID' \
      --train-file /workspace/data/train.jsonl \
      --eval-file /workspace/data/eval.jsonl \
      --out-dir '$CONTAINER_OUT_DIR' \
      --epochs '$EPOCHS' \
      --max-length '$MAX_LENGTH' \
      --grad-accum '$GRAD_ACCUM' \
      --lora-r '$LORA_R' \
      --lora-alpha '$LORA_ALPHA' \
      --load-in-4bit \
      --skip-kbit-prepare
    python3 /llama.cpp/convert_lora_to_gguf.py '$CONTAINER_OUT_DIR' --outfile '$CONTAINER_OUT_DIR/wendao_gemma4_lora.gguf' || true
  "
