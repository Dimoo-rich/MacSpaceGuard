#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
APP_DIR="$PROJECT_DIR/dist/.build/MacSpaceGuard.app"
ZIP_PATH="$PROJECT_DIR/dist/MacSpaceGuard.zip"

if [[ ! -d "$APP_DIR" ]]; then
  "$SCRIPT_DIR/package_app.sh"
fi

rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
echo "$ZIP_PATH"
