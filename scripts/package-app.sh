#!/usr/bin/env bash
# Build release binary, assemble .app with stable bundle id, ad-hoc sign.
# Usage: ./scripts/package-app.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUNDLE_ID="com.ctdoshot.app"
APP_NAME="ctdoshot"
APP_DIR="$ROOT/build/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

echo "==> swift build -c release"
swift build -c release

BIN="$ROOT/.build/release/${APP_NAME}"
if [[ ! -x "$BIN" ]]; then
  echo "error: missing binary $BIN" >&2
  exit 1
fi

echo "==> assemble $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp -f "$BIN" "$MACOS_DIR/${APP_NAME}"
chmod +x "$MACOS_DIR/${APP_NAME}"
cp -f "$ROOT/packaging/Info.plist" "$CONTENTS/Info.plist"

# Bind Info.plist into the signature (required for stable TCC identity).
echo "==> codesign --identifier ${BUNDLE_ID}"
codesign --force --deep \
  --sign - \
  --identifier "${BUNDLE_ID}" \
  --entitlements "$ROOT/packaging/ctdoshot.entitlements" \
  --options runtime \
  "$APP_DIR" 2>/dev/null \
|| codesign --force --deep \
  --sign - \
  --identifier "${BUNDLE_ID}" \
  --entitlements "$ROOT/packaging/ctdoshot.entitlements" \
  "$APP_DIR"

echo "==> verify"
codesign -dv --verbose=2 "$APP_DIR" 2>&1 | sed -n '1,20p'
echo "Identifier check:"
codesign -d --verbose=2 "$APP_DIR" 2>&1 | grep -E 'Identifier|Signature|TeamIdentifier|Info.plist' || true

echo ""
echo "OK: open \"$APP_DIR\""
echo "If Screen Recording loops after a rebuild:"
echo "  tccutil reset ScreenCapture ${BUNDLE_ID}"
echo "  open \"$APP_DIR\"   # accept dialog once, enable toggle, relaunch"
