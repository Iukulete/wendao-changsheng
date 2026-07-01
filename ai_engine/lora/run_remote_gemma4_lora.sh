#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-$HOME/wendao_lora}"
MODEL_ID="${MODEL_ID:-google/gemma-4-E4B-it-qat-q4_0-unquantized}"
CONTAINER_OUT_DIR="${CONTAINER_OUT_DIR:-/workspace/out/wendao_gemma4_lora}"
CONTAINER_VENV="${CONTAINER_VENV:-/workspace/.venv}"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
TRAIN_COUNT="${TRAIN_COUNT:-900}"
EVAL_COUNT="${EVAL_COUNT:-90}"
EPOCHS="${EPOCHS:-1}"
MAX_LENGTH="${MAX_LENGTH:-768}"
GRAD_ACCUM="${GRAD_ACCUM:-16}"
LORA_R="${LORA_R:-8}"
LORA_ALPHA="${LORA_ALPHA:-16}"
EXCLUDE_MODULES="${EXCLUDE_MODULES:-regex:.*(audio_tower|vision_tower).*}"
FORBID_TRAINABLE_SUBSTRINGS="${FORBID_TRAINABLE_SUBSTRINGS:-audio_tower,vision_tower}"
REQUIRE_TRAINABLE_SUBSTRINGS="${REQUIRE_TRAINABLE_SUBSTRINGS:-language_model}"
TARGET_CHECK_ONLY="${TARGET_CHECK_ONLY:-0}"

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

docker run --rm -i \
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
  -e MODEL_ID="$MODEL_ID" \
  -e CONTAINER_OUT_DIR="$CONTAINER_OUT_DIR" \
  -e CONTAINER_VENV="$CONTAINER_VENV" \
  -e HOST_UID="$HOST_UID" \
  -e HOST_GID="$HOST_GID" \
  -e TRAIN_COUNT="$TRAIN_COUNT" \
  -e EVAL_COUNT="$EVAL_COUNT" \
  -e EPOCHS="$EPOCHS" \
  -e MAX_LENGTH="$MAX_LENGTH" \
  -e GRAD_ACCUM="$GRAD_ACCUM" \
  -e LORA_R="$LORA_R" \
  -e LORA_ALPHA="$LORA_ALPHA" \
  -e EXCLUDE_MODULES="$EXCLUDE_MODULES" \
  -e FORBID_TRAINABLE_SUBSTRINGS="$FORBID_TRAINABLE_SUBSTRINGS" \
  -e REQUIRE_TRAINABLE_SUBSTRINGS="$REQUIRE_TRAINABLE_SUBSTRINGS" \
  -e TARGET_CHECK_ONLY="$TARGET_CHECK_ONLY" \
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

"$CONTAINER_VENV/bin/python" -m pip install --upgrade pip
"$CONTAINER_VENV/bin/python" -m pip install --index-url https://download.pytorch.org/whl/cu124 torch
"$CONTAINER_VENV/bin/python" -m pip install 'transformers>=4.56.0' accelerate peft bitsandbytes safetensors sentencepiece protobuf hf_transfer 'huggingface_hub[hf_xet]'

export LD_LIBRARY_PATH=/host-libs:/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}

if [ "$TARGET_CHECK_ONLY" != "1" ]; then
  "$CONTAINER_VENV/bin/python" /workspace/scripts/build_wendao_lora_dataset.py \
    --out-dir /workspace/data \
    --train-count "$TRAIN_COUNT" \
    --eval-count "$EVAL_COUNT"
fi

target_check_args=()
if [ "$TARGET_CHECK_ONLY" = "1" ]; then
  target_check_args=(--target-check-only)
fi

"$CONTAINER_VENV/bin/python" /workspace/scripts/train_gemma4_lora.py \
  --model-id "$MODEL_ID" \
  --train-file /workspace/data/train.jsonl \
  --eval-file /workspace/data/eval.jsonl \
  --out-dir "$CONTAINER_OUT_DIR" \
  --epochs "$EPOCHS" \
  --max-length "$MAX_LENGTH" \
  --grad-accum "$GRAD_ACCUM" \
  --lora-r "$LORA_R" \
  --lora-alpha "$LORA_ALPHA" \
  --exclude-modules "$EXCLUDE_MODULES" \
  --forbid-trainable-substrings "$FORBID_TRAINABLE_SUBSTRINGS" \
  --require-trainable-substrings "$REQUIRE_TRAINABLE_SUBSTRINGS" \
  "${target_check_args[@]}" \
  --load-in-4bit \
  --skip-kbit-prepare

if [ "$TARGET_CHECK_ONLY" = "1" ]; then
  chown -R "$HOST_UID:$HOST_GID" /workspace/out /workspace/logs || true
  exit 0
fi

export_dir="${CONTAINER_OUT_DIR}_llamacpp"
gguf_path="$CONTAINER_OUT_DIR/wendao_gemma4_lora.gguf"
if "$CONTAINER_VENV/bin/python" /workspace/scripts/normalize_peft_adapter_for_llamacpp.py \
    --adapter-dir "$CONTAINER_OUT_DIR" \
    --out-dir "$export_dir" && \
  "$CONTAINER_VENV/bin/python" /llama.cpp/convert_lora_to_gguf.py "$export_dir" --outfile "$gguf_path"; then
  gguf_bytes="$(wc -c < "$gguf_path" || echo 0)"
  if [ "$gguf_bytes" -lt 4096 ]; then
    echo "error: GGUF LoRA export is only ${gguf_bytes} bytes, likely metadata-only and not usable by llama.cpp yet." >&2
    exit 2
  fi
else
  echo "warning: GGUF LoRA export failed; PEFT adapter was still saved."
fi

chown -R "$HOST_UID:$HOST_GID" /workspace/data /workspace/out /workspace/logs || true
CONTAINER_SH
