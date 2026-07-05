#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/Vendor/Kiwi"
VERSION="0.23.2"
BASE_URL="https://github.com/bab2min/Kiwi/releases/download/v$VERSION"
RUNTIME_ARCHIVE="kiwi_mac_arm64_v$VERSION.tgz"
MODEL_ARCHIVE="kiwi_model_v${VERSION}_base.tgz"
RUNTIME_SHA256="ac124e32e013e2089cb4d842e2b735a1e6b4f3b126cdf692d78fda1130b8a382"
MODEL_SHA256="15f35787ab07281688a321f5d6bc24a117008190d9fcccb11dca188e81eba814"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kotina-kiwi.XXXXXX")"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

download_and_verify() {
    local archive="$1"
    local expected_sha256="$2"
    local output="$WORK_DIR/$archive"

    curl --fail --location --silent --show-error \
        "$BASE_URL/$archive" \
        --output "$output"

    local actual_sha256
    actual_sha256="$(shasum -a 256 "$output" | awk '{print $1}')"
    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
        echo "Checksum mismatch for $archive" >&2
        echo "Expected: $expected_sha256" >&2
        echo "Actual:   $actual_sha256" >&2
        exit 1
    fi
}

download_and_verify "$RUNTIME_ARCHIVE" "$RUNTIME_SHA256"
download_and_verify "$MODEL_ARCHIVE" "$MODEL_SHA256"

mkdir -p "$WORK_DIR/runtime" "$WORK_DIR/model"
tar -xzf "$WORK_DIR/$RUNTIME_ARCHIVE" -C "$WORK_DIR/runtime"
tar -xzf "$WORK_DIR/$MODEL_ARCHIVE" -C "$WORK_DIR/model"

rm -rf "$VENDOR_DIR/include" "$VENDOR_DIR/lib" "$VENDOR_DIR/models"
mkdir -p "$VENDOR_DIR/include" "$VENDOR_DIR/lib" "$VENDOR_DIR/models/cong"
cp -R "$WORK_DIR/runtime/include/." "$VENDOR_DIR/include"
cp "$WORK_DIR/runtime/lib/libkiwi.$VERSION.dylib" "$VENDOR_DIR/lib/libkiwi.0.dylib"
ln -s "libkiwi.0.dylib" "$VENDOR_DIR/lib/libkiwi.dylib"
cp -R "$WORK_DIR/model/models/cong/base" "$VENDOR_DIR/models/cong/base"

echo "Installed Kiwi $VERSION arm64 runtime and base model in $VENDOR_DIR"
