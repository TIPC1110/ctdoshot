#!/usr/bin/env bash
# Build release binary, assemble .app, sign with a *stable* identity when possible.
#
# Why permission resets every rebuild:
#   codesign --sign -  (ad-hoc) embeds a CDHash of the binary. TCC Screen Recording
#   on modern macOS often keys off that hash → new build = "new app" = re-prompt.
#   Signing with the same certificate identity keeps TCC across rebuilds.
#
# Usage:
#   ./scripts/ensure-signing-identity.sh   # once per machine
#   ./scripts/package-app.sh
#
# Optional:
#   CTDOSHOT_SIGN_IDENTITY="Apple Development: …" ./scripts/package-app.sh
#   CTDOSHOT_INSTALL=1 ./scripts/package-app.sh   # also copy to /Applications
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUNDLE_ID="com.ctdoshot.app"
APP_NAME="ctdoshot"
CERT_CN="${CTDOSHOT_CERT_CN:-ctdoshot Developer}"
APP_DIR="$ROOT/build/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

can_sign_as() {
  local id="$1" f
  f="$(mktemp)"
  echo test >"$f"
  if codesign -f -s "$id" "$f" >/dev/null 2>&1; then
    rm -f "$f"
    return 0
  fi
  rm -f "$f"
  return 1
}

pick_identity() {
  if [[ -n "${CTDOSHOT_SIGN_IDENTITY:-}" ]] && can_sign_as "$CTDOSHOT_SIGN_IDENTITY"; then
    echo "$CTDOSHOT_SIGN_IDENTITY"
    return
  fi
  # Named local cert (created by ensure-signing-identity.sh) — may not show as
  # "valid" in find-identity -v but still works for codesign -s.
  if can_sign_as "$CERT_CN"; then
    echo "$CERT_CN"
    return
  fi
  local line id
  line="$(security find-identity -v -p codesigning 2>/dev/null | grep -E 'Apple Development|Developer ID Application' | head -1 || true)"
  if [[ -n "$line" ]]; then
    id="$(echo "$line" | sed -E 's/.*"([^"]+)".*/\1/')"
    if can_sign_as "$id"; then
      echo "$id"
      return
    fi
  fi
  echo ""
}

ARCH="${CTDOSHOT_ARCH:-}"
if [[ "$*" == *"--universal"* ]] || [[ "$ARCH" == "universal" ]]; then
  echo "==> building Universal Binary (arm64 + x86_64)..."
  swift build -c release --triple arm64-apple-macosx13.0
  swift build -c release --triple x86_64-apple-macosx13.0
  BIN_ARM64="$ROOT/.build/arm64-apple-macosx/release/${APP_NAME}"
  BIN_X86_64="$ROOT/.build/x86_64-apple-macosx/release/${APP_NAME}"
  BIN_FAT="$ROOT/.build/release/${APP_NAME}_universal"
  mkdir -p "$ROOT/.build/release"
  lipo -create -output "$BIN_FAT" "$BIN_ARM64" "$BIN_X86_64"
  BIN="$BIN_FAT"
elif [[ "$*" == *"--intel"* ]] || [[ "$ARCH" == "x86_64" ]]; then
  echo "==> building Intel x86_64 binary..."
  swift build -c release --triple x86_64-apple-macosx13.0
  BIN="$ROOT/.build/x86_64-apple-macosx/release/${APP_NAME}"
else
  echo "==> swift build -c release"
  swift build -c release
  BIN="$ROOT/.build/release/${APP_NAME}"
fi

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

IDENTITY="$(pick_identity)"
if [[ -z "$IDENTITY" ]]; then
  echo ""
  echo "WARN: no code-signing certificate found — using ad-hoc sign (-)."
  echo "      Screen Recording permission will RESET on every rebuild."
  echo "      Fix once:"
  echo "        ./scripts/ensure-signing-identity.sh"
  echo "        ./scripts/package-app.sh"
  echo ""
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
else
  echo "==> codesign with stable identity: $IDENTITY"
  codesign --force --deep \
    --sign "$IDENTITY" \
    --identifier "${BUNDLE_ID}" \
    --entitlements "$ROOT/packaging/ctdoshot.entitlements" \
    --options runtime \
    "$APP_DIR"
fi

echo "==> verify"
codesign -dv --verbose=2 "$APP_DIR" 2>&1 | sed -n '1,25p'
echo "Identifier check:"
codesign -d --verbose=2 "$APP_DIR" 2>&1 | grep -E 'Identifier|Signature|TeamIdentifier|Authority' || true

if [[ "${CTDOSHOT_INSTALL:-}" == "1" ]]; then
  echo "==> install /Applications/${APP_NAME}.app"
  rm -rf "/Applications/${APP_NAME}.app"
  cp -R "$APP_DIR" "/Applications/${APP_NAME}.app"
  echo "OK: open -a ${APP_NAME}"
else
  echo ""
  echo "OK: open \"$APP_DIR\""
  echo "Tip: install a stable copy (same path every day):"
  echo "  CTDOSHOT_INSTALL=1 ./scripts/package-app.sh"
  echo "  open -a ctdoshot"
fi

SIG_LINE="$(codesign -d --verbose=2 "$APP_DIR" 2>&1 | grep -E '^(Signature|Authority)' | head -3 || true)"
if echo "$SIG_LINE" | grep -qi 'adhoc\|Signature=adhoc'; then
  echo ""
  echo "NOTE: ad-hoc signature → macOS may ask Screen Recording again after each rebuild."
fi
