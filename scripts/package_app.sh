#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
BUILD_CONFIGURATION=${BUILD_CONFIGURATION:-release}
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$DIST_DIR/.build/MacSpaceGuard.app"

cd "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/work/clang-module-cache" "$PROJECT_DIR/work/swiftpm-module-cache"

# macOS beta/preview systems occasionally ship a default SDK that is a few
# compiler builds ahead. Allow an explicit SDKROOT, and use the newest stable
# fallback SDK when this known local layout is present.
if [[ -z "${SDKROOT:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
fi
export CLANG_MODULE_CACHE_PATH=${CLANG_MODULE_CACHE_PATH:-"$PROJECT_DIR/work/clang-module-cache"}
export SWIFTPM_MODULECACHE_OVERRIDE=${SWIFTPM_MODULECACHE_OVERRIDE:-"$PROJECT_DIR/work/swiftpm-module-cache"}

BUILD_OPTIONS=(--disable-sandbox -c "$BUILD_CONFIGURATION" --product MacSpaceGuard)
if [[ "$BUILD_CONFIGURATION" == "release" ]]; then
  BUILD_OPTIONS+=(-debug-info-format none)
  # This experimental option is not available in every Swift 6 toolchain.
  SWIFT_BUILD_HELP=$(swift build --help)
  if [[ "$SWIFT_BUILD_HELP" == *"--enable-experimental-strip-products"* ]]; then
    BUILD_OPTIONS+=(--enable-experimental-strip-products)
  fi
fi

swift build "${BUILD_OPTIONS[@]}"
BIN_DIR=$(swift build --disable-sandbox -c "$BUILD_CONFIGURATION" --show-bin-path)

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/MacSpaceGuard" "$APP_DIR/Contents/MacOS/MacSpaceGuard"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/PkgInfo" "$APP_DIR/Contents/PkgInfo"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
chmod +x "$APP_DIR/Contents/MacOS/MacSpaceGuard"
xattr -cr "$APP_DIR"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  codesign --force --deep --options runtime --timestamp \
    --sign "$DEVELOPER_ID_APPLICATION" "$APP_DIR"
else
  codesign --force --deep --sign - "$APP_DIR"
fi

codesign --verify --deep --strict "$APP_DIR"
echo "$APP_DIR"
