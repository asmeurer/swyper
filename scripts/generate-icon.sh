#!/bin/bash
# Generate AppIcon.icns from AppIcon.svg
# Requires rsvg-convert (from librsvg): brew install librsvg

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SVG="$ROOT_DIR/Resources/AppIcon.svg"
ICONSET="$ROOT_DIR/build/AppIcon.iconset"
ICNS="$ROOT_DIR/Resources/AppIcon.icns"

if ! command -v rsvg-convert &> /dev/null; then
    echo "Error: rsvg-convert not found. Install with: brew install librsvg"
    exit 1
fi

mkdir -p "$ICONSET"

sizes=(16 32 128 256 512)
for size in "${sizes[@]}"; do
    rsvg-convert -w "$size" -h "$size" "$SVG" -o "$ICONSET/icon_${size}x${size}.png"
    double=$((size * 2))
    half=$((size))
    rsvg-convert -w "$double" -h "$double" "$SVG" -o "$ICONSET/icon_${half}x${half}@2x.png"
done

iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$ICONSET"

echo "Generated $ICNS"
