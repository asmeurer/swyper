#!/bin/bash
# Generate an .icns app icon from an SVG source.
# Usage: ./scripts/generate-icon.sh [input.svg] [output.icns]
# Requires rsvg-convert (from librsvg): brew install librsvg

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SVG="${1:-$ROOT_DIR/Resources/AppIcon.svg}"
ICNS="${2:-$ROOT_DIR/build/AppIcon.icns}"
TMP_ROOT="${TMPDIR:-/tmp}"
TMP_ROOT="${TMP_ROOT%/}"
WORK_DIR="$(mktemp -d "$TMP_ROOT/swyper-icon.XXXXXX")"
ICONSET="$WORK_DIR/AppIcon.iconset"

cleanup() {
    rm -rf "$WORK_DIR"
}

trap cleanup EXIT

if ! command -v rsvg-convert &> /dev/null; then
    echo "Error: rsvg-convert not found. Install with: brew install librsvg"
    exit 1
fi

if ! command -v iconutil &> /dev/null; then
    echo "Error: iconutil not found. This script must run on macOS."
    exit 1
fi

mkdir -p "$(dirname "$ICNS")"
mkdir -p "$ICONSET"

sizes=(16 32 128 256 512)
for size in "${sizes[@]}"; do
    rsvg-convert -w "$size" -h "$size" "$SVG" -o "$ICONSET/icon_${size}x${size}.png"
    double=$((size * 2))
    half=$((size))
    rsvg-convert -w "$double" -h "$double" "$SVG" -o "$ICONSET/icon_${half}x${half}@2x.png"
done

iconutil -c icns "$ICONSET" -o "$ICNS"

echo "Generated $ICNS from $SVG"
