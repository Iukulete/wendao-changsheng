# Third-party AI assets

This project includes an optional portable local AI backend for dynamic event text.

## Model

- File: `models/Qwen_Qwen3-0.6B-Q4_K_M.gguf`
- Source: `bartowski/Qwen_Qwen3-0.6B-GGUF` on Hugging Face
- Download: `https://huggingface.co/bartowski/Qwen_Qwen3-0.6B-GGUF/resolve/main/Qwen_Qwen3-0.6B-Q4_K_M.gguf?download=true`
- SHA256: `9ACFC1E001311F34B4252001B626F2E466D592A42065F66571BFF3790D4E1B14`
- Base model: Qwen3-0.6B by Qwen
- Intended use: local event text generation only

Check the upstream model pages for the current license terms before redistribution.
Qwen3 base models are published by Qwen; the bundled GGUF is a quantized conversion.

## Runtime

- Folder: `runtime/llama.cpp/`
- Source: `ggml-org/llama.cpp` Windows CPU x64 release
- Download: `https://github.com/ggml-org/llama.cpp/releases/download/b9803/llama-b9803-bin-win-cpu-x64.zip`
- SHA256: `4D942D5FCB7F3AB026844208306C5EEBECF4530F4E52EED5C4717DBDF9FE3C5D`
- Intended use: portable CPU inference through `llama-cli.exe`

Keep this notice with packaged builds so future maintainers can update or replace
the bundled AI files cleanly.
