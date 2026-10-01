#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
ICONSET_DIR="$PROJECT_DIR/work/AppIcon.iconset"
SOURCE_PNG="$PROJECT_DIR/Resources/AppIcon-1024.png"

mkdir -p "$ICONSET_DIR"
mkdir -p "$PROJECT_DIR/work/clang-module-cache"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/work/clang-module-cache"
swift "$SCRIPT_DIR/generate_icon.swift" "$SOURCE_PNG"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$SOURCE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  doubled=$((size * 2))
  sips -z "$doubled" "$doubled" "$SOURCE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done

python3 "$SCRIPT_DIR/assemble_icns.py" "$ICONSET_DIR" "$PROJECT_DIR/Resources/AppIcon.icns"
echo "$PROJECT_DIR/Resources/AppIcon.icns"
