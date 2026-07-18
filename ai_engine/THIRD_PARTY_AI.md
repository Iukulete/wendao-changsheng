# Third-party AI assets

This project includes an optional portable local AI backend for dynamic event text.

## Model

- File: `models/gemma-4-E4B_q4_0-it.gguf`
- Source: `google/gemma-4-E4B-it-qat-q4_0-gguf` on Hugging Face
- Revision: `99ef3d9bbf819591699ffa9084c4be12db1fbe6c`
- Download: `https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf/resolve/99ef3d9bbf819591699ffa9084c4be12db1fbe6c/gemma-4-E4B_q4_0-it.gguf?download=true`
- Network fallback: `https://hf-mirror.com/google/gemma-4-E4B-it-qat-q4_0-gguf/resolve/99ef3d9bbf819591699ffa9084c4be12db1fbe6c/gemma-4-E4B_q4_0-it.gguf?download=true`
- SHA256: `E8B6A059BA86947A44ACE84D6E5679795BC41862C25C30513142588F0E9DBA1D`
- Base model: Gemma 4 E4B it QAT Q4_0 by Google
- Intended use: local event text generation only

Check the upstream model pages for the current license terms before redistribution.
Gemma 4 E4B it QAT Q4_0 GGUF is published by Google under the upstream model terms.
This project uses only the text GGUF file; the optional multimodal projection file is not needed.
The revision is intentionally pinned because upstream replaced the file on `main`
with a vocabulary-corrected checkpoint after this adapter was trained.

## Wendao LoRA

- File: `lora/wendao_gemma4_lora_text_v7_codex_filtered.gguf`
- Source: `https://github.com/Iukulete/wendao-changsheng/releases/tag/lora-v7`
- Download: `https://github.com/Iukulete/wendao-changsheng/releases/download/lora-v7/wendao_gemma4_lora_text_v7_codex_filtered.gguf`
- SHA256: `36D286CFEC617F33325B60F378C7478414CDBE884D30188708D8A2F0B0A9F3FF`
- Training provenance: project-authored event examples under `ai_engine/lora/`, filtered and adapted for the five-line event format.
- Intended use: style and structure adapter for the pinned Gemma base model.

The project-authored adapter and training utilities are released under the
project license to the extent permitted. The Gemma base-model terms continue
to apply to use of the adapter. Set `WENDAO_LORA_PATH` or create
`ai_engine/lora_path.txt` only when substituting another compatible adapter,
and keep that adapter's license and provenance with the installation.

## Runtime

- Folder: `runtime/llama.cpp/`
- Source: `ggml-org/llama.cpp` Windows Vulkan x64 release, build `b10066`
- Download: `https://github.com/ggml-org/llama.cpp/releases/download/b10066/llama-b10066-bin-win-vulkan-x64.zip`
- SHA256: `57CB5DD3143B2814B8D1D14587867628BFB126536ABFA7085CA9560C4919D998`
- Intended use: portable Vulkan-accelerated local inference through `llama-completion.exe`

The Vulkan build uses a supported local GPU when available and retains CPU
code paths for mixed execution. This is required for interactive latency with
the pinned model; setup performs a real five-line generation test before
reporting the backend ready.

Keep this notice with packaged builds so future maintainers can update or replace
the bundled AI files cleanly.

The setup script may use explicitly listed mirrors when the canonical host is
unreachable. Mirrors are transport fallbacks only: every model, adapter, and
runtime archive must match the pinned SHA-256 before it is installed.
