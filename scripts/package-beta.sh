#!/bin/bash

set -euo pipefail

fail() {
    echo "error: $1" >&2
    exit 1
}

VERSION="${1:-}"
[[ -n "$VERSION" ]] || fail "usage: scripts/package-beta.sh <version>"
[[ "$VERSION" =~ ^[0-9A-Za-z][0-9A-Za-z._-]*$ ]] || fail "invalid version: $VERSION"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="/private/tmp/KotinaReleaseDerivedData"
STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/kotina-beta.XXXXXX")"
OUTPUT_DIR="$ROOT_DIR/dist/$VERSION"
APP_PATH="$DERIVED_DATA/Build/Products/Release/Kotina.app"
EXECUTABLE="$APP_PATH/Contents/MacOS/Kotina"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
ARCHIVE_NAME="Kotina-$VERSION-macOS-arm64.zip"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"

cleanup() {
    rm -rf "$STAGING_ROOT"
}
trap cleanup EXIT

command -v xcodegen >/dev/null || fail "xcodegen is required"
command -v xcodebuild >/dev/null || fail "xcodebuild is required"
command -v ditto >/dev/null || fail "ditto is required"
[[ -f "$ROOT_DIR/Vendor/Kiwi/lib/libkiwi.0.dylib" ]] \
    || fail "Kiwi runtime is missing; run scripts/fetch-kiwi.sh"
[[ -f "$ROOT_DIR/Vendor/Kiwi/models/cong/base/cong.mdl" ]] \
    || fail "Kiwi base model is missing; run scripts/fetch-kiwi.sh"
[[ -x "$ROOT_DIR/Vendor/Llama/llama-cli" ]] \
    || fail "llama.cpp runtime is missing; run scripts/fetch-llama.sh"
[[ -s "$ROOT_DIR/THIRD_PARTY_NOTICES.md" ]] || fail "third-party notice is missing"
[[ -s "$ROOT_DIR/README.md" ]] || fail "README is missing"

cd "$ROOT_DIR"
xcodegen generate
xcodebuild -quiet \
    -project Kotina.xcodeproj \
    -scheme Kotina \
    -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$DERIVED_DATA" \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=YES \
    build

[[ -x "$EXECUTABLE" ]] || fail "Release executable was not built"
[[ "$(lipo -archs "$EXECUTABLE")" == "arm64" ]] || fail "Release executable is not arm64-only"
[[ "$(plutil -extract LSUIElement raw -o - "$INFO_PLIST")" == "true" ]] \
    || fail "LSUIElement must be true"
[[ "$(plutil -extract LSMinimumSystemVersion raw -o - "$INFO_PLIST")" == "15.0" ]] \
    || fail "minimum macOS version must be 15.0"
[[ -f "$APP_PATH/Contents/Frameworks/libkiwi.0.dylib" ]] \
    || fail "embedded Kiwi runtime is missing"
[[ -f "$APP_PATH/Contents/Resources/base/cong.mdl" ]] \
    || fail "embedded Kiwi model is missing"
[[ -x "$APP_PATH/Contents/Resources/Llama/llama-cli" ]] \
    || fail "embedded llama.cpp runtime is missing"
[[ -f "$APP_PATH/Contents/Resources/THIRD_PARTY_NOTICES.md" ]] \
    || fail "embedded third-party notice is missing"

LINKS="$(otool -L "$EXECUTABLE")"
grep -Fq '@rpath/libkiwi.0.dylib' <<<"$LINKS" \
    || fail "Release executable does not link embedded Kiwi"
if grep -Eq '/opt/homebrew|/Users/|Vendor/Kiwi' <<<"$LINKS"; then
    fail "Release executable contains a local Kiwi dependency path"
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
PACKAGE_ROOT="$STAGING_ROOT/Kotina-$VERSION"
mkdir -p "$PACKAGE_ROOT"
cp -R "$APP_PATH" "$PACKAGE_ROOT/Kotina.app"
cp "$ROOT_DIR/README.md" "$PACKAGE_ROOT/README.md"
cp "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$PACKAGE_ROOT/THIRD_PARTY_NOTICES.md"

ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_ROOT" "$ARCHIVE_PATH"
(
    cd "$OUTPUT_DIR"
    shasum -a 256 "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
)
unzip -tq "$ARCHIVE_PATH" >/dev/null

echo "Created $ARCHIVE_PATH"
echo "Created $ARCHIVE_PATH.sha256"
