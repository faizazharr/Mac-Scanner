#!/bin/bash
# One-time setup: creates a self-signed code-signing certificate and imports
# it into the login keychain. Signing the app with this identity (instead of
# ad-hoc `codesign --sign -`) keeps its signature identity STABLE across
# rebuilds, so macOS TCC remembers folder-access grants (Desktop, Documents,
# Downloads, etc) instead of re-prompting every time the app is recompiled.
set -euo pipefail

CERT_NAME="MacScanner Local Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$CERT_NAME"; then
    echo "Signing identity '$CERT_NAME' already exists — nothing to do."
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

openssl req -x509 -newkey rsa:2048 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -days 3650 -nodes -subj "/CN=$CERT_NAME" \
    -addext "extendedKeyUsage=codeSigning" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature"

openssl pkcs12 -export -legacy -out "$TMP/cert.p12" \
    -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -passout pass:temporary 2>/dev/null \
    || openssl pkcs12 -export -out "$TMP/cert.p12" \
    -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -passout pass:temporary

# -A grants every app (incl. codesign) silent access to the private key —
# without it, the first codesign run would trigger a Keychain access prompt.
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P temporary -A -T /usr/bin/codesign

echo "Created signing identity: $CERT_NAME"
