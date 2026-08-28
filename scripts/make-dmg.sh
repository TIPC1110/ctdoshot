#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/build/ctdoshot.app"
DMG="$ROOT/build/ctdoshot.dmg"
STAGING="$ROOT/build/dmg-staging"
if [[ ! -d "$APP_DIR" ]]; then echo "error: $APP_DIR missing, run package-app.sh first" >&2; exit 1; fi
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "ctdoshot" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
echo "OK: $DMG ($(du -h "$DMG" | cut -f1))"
hdiutil imageinfo "$DMG" | head -n 20
