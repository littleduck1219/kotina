# Third-Party Notices

## Kiwi 0.23.2

Kotina uses the Kiwi Korean morphological analyzer and its base Korean model by
Min-Hyeong Park.

- Source: https://github.com/bab2min/Kiwi
- Runtime asset: `kiwi_mac_arm64_v0.23.2.tgz`
- Model asset: `kiwi_model_v0.23.2_base.tgz`
- License: GNU Lesser General Public License, version 3.0
- License text: https://www.gnu.org/licenses/lgpl-3.0.html
- Corresponding source: https://github.com/bab2min/Kiwi/tree/v0.23.2

Kotina embeds Kiwi as a replaceable dynamic library in the application bundle. The
downloaded runtime, headers, and model are not committed to this repository; use
`scripts/fetch-kiwi.sh` to obtain the pinned official assets and verify their
SHA-256 checksums before use. Kiwi's complete license and corresponding source are
available from the upstream repository and release linked above.

The release archive keeps `libkiwi.0.dylib` as a separate file under
`Kotina.app/Contents/Frameworks`. An interface-compatible replacement can be put
at that path without modifying the Kotina executable. The base model is copied
unchanged from the checksum-verified upstream model archive.

## llama.cpp b10015

Kotina bundles the macOS arm64 `llama-cli` runtime from llama.cpp to run the
local translation model.

- Source: https://github.com/ggml-org/llama.cpp
- Runtime asset: `llama-b10015-bin-macos-arm64.tar.gz`
- License: MIT License
- License text: https://github.com/ggml-org/llama.cpp/blob/master/LICENSE

The runtime is downloaded by `scripts/fetch-llama.sh` from the pinned upstream
release and verified with its SHA-256 checksum before being added to the app bundle.

## Qwen3-4B Q4_K_M GGUF

Kotina downloads this quantized Qwen3-4B model only after the user selects
`로컬 번역 모델 준비`. It is stored locally and is never uploaded by Kotina.

- Base model: https://huggingface.co/Qwen/Qwen3-4B
- Quantized asset: https://huggingface.co/bartowski/Qwen_Qwen3-4B-GGUF
- Pinned file: `Qwen_Qwen3-4B-Q4_K_M.gguf`
- License: Apache License 2.0
- License text: https://www.apache.org/licenses/LICENSE-2.0

The app verifies the pinned model file's SHA-256 checksum before installing it.
