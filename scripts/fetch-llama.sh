#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_DIR="$ROOT_DIR/Vendor/Llama"
ARCHIVE="/private/tmp/kotina-llama-b10015.tar.gz"
URL="https://github.com/ggml-org/llama.cpp/releases/download/b10015/llama-b10015-bin-macos-arm64.tar.gz"
SHA256="8d3144eb71a4b9b5b9ed50512f659d1cbcd5772e30aca75e6f9a0d7d68c311a7"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kotina-llama.XXXXXX")"

cleanup() { rm -rf "$WORK_DIR" "$ARCHIVE"; }
trap cleanup EXIT

curl --fail --location --silent --show-error "$URL" --output "$ARCHIVE"
[[ "$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')" == "$SHA256" ]] || exit 1
tar -xzf "$ARCHIVE" -C "$WORK_DIR"
mkdir -p "$RUNTIME_DIR"
rm -f "$RUNTIME_DIR"/*
cp "$WORK_DIR"/llama-b10015/llama-cli "$RUNTIME_DIR/"
cp "$WORK_DIR"/llama-b10015/*.dylib "$RUNTIME_DIR/"
chmod +x "$RUNTIME_DIR/llama-cli"
