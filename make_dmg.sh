#!/bin/zsh
# Builds BlackScreen.app and packages it as BlackScreen.dmg
# (app + Applications shortcut, compressed).

set -euo pipefail
cd "${0:A:h}"

APP_NAME="BlackScreen"
DMG="$APP_NAME.dmg"

./build.sh

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

echo "💿 Creating $DMG..."
ditto "$APP_NAME.app" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov "$DMG" >/dev/null

hdiutil verify "$DMG" >/dev/null
echo "✅ Built $DMG"
