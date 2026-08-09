#!/usr/bin/env bash
# Install a local code-signing cert so Screen Recording permission survives rebuilds.
#
# Ad-hoc signing (`codesign -s -`) changes CDHash every build → macOS treats each
# rebuild as a new app. A named certificate keeps a stable signing authority.
#
# Usage (once per Mac):
#   ./scripts/ensure-signing-identity.sh
#   ./scripts/package-app.sh
set -euo pipefail

CERT_CN="${CTDOSHOT_CERT_CN:-ctdoshot Developer}"
KEYCHAIN="${CTDOSHOT_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
WORKDIR="${TMPDIR:-/tmp}/ctdoshot-codesign-$$"
P12_PASS="ctdoshot-local"

cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

can_sign() {
  local f
  f="$(mktemp)"
  echo test >"$f"
  if codesign -f -s "$CERT_CN" "$f" >/dev/null 2>&1; then
    rm -f "$f"
    return 0
  fi
  rm -f "$f"
  return 1
}

if can_sign; then
  echo "OK: can codesign with: $CERT_CN"
  security find-identity -p codesigning 2>/dev/null | grep -F "$CERT_CN" || true
  exit 0
fi

echo "==> creating certificate: $CERT_CN"
mkdir -p "$WORKDIR"

cat >"$WORKDIR/cert.cnf" <<EOF
[req]
distinguished_name = dn
prompt = no
x509_extensions = v3_req

[dn]
CN = ${CERT_CN}
O = ctdoteam
C = US

[v3_req]
basicConstraints = critical,CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$WORKDIR/key.pem" \
  -out "$WORKDIR/cert.pem" \
  -days 3650 \
  -config "$WORKDIR/cert.cnf" 2>/dev/null

# OpenSSL 3 p12 needs -legacy for macOS security(1) import
openssl pkcs12 -export -legacy \
  -out "$WORKDIR/cert.p12" \
  -inkey "$WORKDIR/key.pem" \
  -in "$WORKDIR/cert.pem" \
  -name "$CERT_CN" \
  -passout "pass:${P12_PASS}" 2>/dev/null

security import "$WORKDIR/cert.p12" \
  -k "$KEYCHAIN" \
  -P "$P12_PASS" \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  -A \
  >/dev/null

security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s -k "" "$KEYCHAIN" 2>/dev/null || true

if can_sign; then
  echo "OK: signing identity ready: $CERT_CN"
  echo "Package with: ./scripts/package-app.sh"
  exit 0
fi

echo "error: certificate imported but codesign still cannot use it."
echo "In Keychain Access → login → My Certificates → '$CERT_CN':"
echo "  double-click → Trust → Code Signing → Always Trust"
echo "Then re-run this script."
exit 1
