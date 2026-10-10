#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
APP_DIR="$PROJECT_DIR/dist/.build.noindex/MacSpaceGuard.app"
DMG_PATH="$PROJECT_DIR/dist/MacSpaceGuard.dmg"
STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

if [[ ! -d "$APP_DIR" ]]; then
  "$SCRIPT_DIR/package_app.sh"
fi

cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH"
hdiutil create -volname "MacSpaceGuard" -srcfolder "$STAGING_DIR" \
  -ov -format UDZO "$DMG_PATH"
echo "$DMG_PATH"
