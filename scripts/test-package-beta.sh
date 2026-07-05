#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_SCRIPT="$ROOT_DIR/scripts/package-beta.sh"

if [[ ! -x "$PACKAGE_SCRIPT" ]]; then
    echo "Missing executable package script: $PACKAGE_SCRIPT" >&2
    exit 1
fi

if "$PACKAGE_SCRIPT" >/dev/null 2>&1; then
    echo "Package script accepted a missing version" >&2
    exit 1
fi

echo "Package preflight tests passed"
