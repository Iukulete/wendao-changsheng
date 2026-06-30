# Third-party AI assets

This project includes an optional portable local AI backend for dynamic event text.

## Model

- File: `models/gemma-4-E4B_q4_0-it.gguf`
- Source: `google/gemma-4-E4B-it-qat-q4_0-gguf` on Hugging Face
- Download: `https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf/resolve/main/gemma-4-E4B_q4_0-it.gguf?download=true`
- SHA256: `E8B6A059BA86947A44ACE84D6E5679795BC41862C25C30513142588F0E9DBA1D`
- Base model: Gemma 4 E4B it QAT Q4_0 by Google
- Intended use: local event text generation only

Check the upstream model pages for the current license terms before redistribution.
Gemma 4 E4B it QAT Q4_0 GGUF is published by Google under the upstream model terms.
This project uses only the text GGUF file; the optional multimodal projection file is not needed.

## Optional LoRA

- Set `WENDAO_LORA_PATH` or create `ai_engine/lora_path.txt` to point to a llama.cpp-compatible LoRA adapter.
- Keep adapter license and training-data provenance with packaged builds.

## Runtime

- Folder: `runtime/llama.cpp/`
- Source: `ggml-org/llama.cpp` Windows CPU x64 release
- Download: `https://github.com/ggml-org/llama.cpp/releases/download/b9843/llama-b9843-bin-win-cpu-x64.zip`
- SHA256: `8EBF156B4543FC8B0A4C3D1FC5CBD952516646AF0CFABB74D1E53BD86321F1E0`
- Intended use: portable CPU inference through `llama-completion.exe`

Keep this notice with packaged builds so future maintainers can update or replace
the bundled AI files cleanly.
