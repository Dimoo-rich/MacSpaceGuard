#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
DMG_PATH="$PROJECT_DIR/dist/MacSpaceGuard.dmg"

: "${NOTARY_PROFILE:?请设置 NOTARY_PROFILE（由 xcrun notarytool store-credentials 创建）}"

xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
