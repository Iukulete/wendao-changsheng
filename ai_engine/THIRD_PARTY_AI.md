# Third-party AI assets

This project includes an optional portable local AI backend for dynamic event text.

## Model

- File: `models/Qwen_Qwen3-0.6B-Q4_K_M.gguf`
- Source: `bartowski/Qwen_Qwen3-0.6B-GGUF` on Hugging Face
- Base model: Qwen3-0.6B by Qwen
- Intended use: local event text generation only

Check the upstream model pages for the current license terms before redistribution.
Qwen3 base models are published by Qwen; the bundled GGUF is a quantized conversion.

## Runtime

- Folder: `runtime/llama.cpp/`
- Source: `ggml-org/llama.cpp` Windows CPU x64 release
- Intended use: portable CPU inference through `llama-cli.exe`

Keep this notice with packaged builds so future maintainers can update or replace
the bundled AI files cleanly.
