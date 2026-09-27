#!/bin/zsh
# Creates a self-signed "Advisor OS Local Signing" code-signing identity in the login keychain.
# It gives every build the same signature, so macOS keeps permissions (like Calendar) across rebuilds.
# It is NOT an Apple certificate: other Macs will still see the app as from an unidentified developer.
# Remove it any time in Keychain Access (search "Advisor OS Local Signing").
set -euo pipefail
NAME="Advisor OS Local Signing"
if security find-certificate -c "$NAME" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
  echo "\"$NAME\" already exists."; exit 0
fi
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cert.cnf" -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
PASS=$(openssl rand -hex 16)
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$NAME" -out "$TMP/id.p12" -passout "pass:$PASS"
security import "$TMP/id.p12" -k ~/Library/Keychains/login.keychain-db -P "$PASS" -T /usr/bin/codesign >/dev/null
echo "Created \"$NAME\" in the login keychain."
