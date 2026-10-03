#!/usr/bin/env bash
# Émet un certificat client + fichier .p12 pour Windows.
# Usage : pki/issue-client.sh NOM EMAIL        (ex. samar samar@odoo-mfa.local)
# Variables optionnelles : CA_PASS (passphrase de la CA), P12_PASS (mot de passe du .p12).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:?Usage: $0 NOM EMAIL}"
EMAIL="${2:?Usage: $0 NOM EMAIL}"
PASSIN=${CA_PASS:+-passin env:CA_PASS}
P12OUT=${P12_PASS:+-passout pass:$P12_PASS}
CL="$ROOT/pki/clients"
cd "$ROOT/pki/ca"

openssl genrsa -out "$CL/$NAME.key" 2048
chmod 600 "$CL/$NAME.key"
openssl req -new -key "$CL/$NAME.key" -out "$CL/$NAME.csr" \
  -subj "/C=TN/O=Odoo MFA Lab/OU=Users/CN=$NAME/emailAddress=$EMAIL"
cat > "$CL/$NAME.ext" <<EXT
[v3_client]
basicConstraints = CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = clientAuth
EXT
# shellcheck disable=SC2086
openssl ca -config openssl-ca.cnf -batch -notext -days 365 $PASSIN \
  -extfile "$CL/$NAME.ext" -extensions v3_client \
  -in "$CL/$NAME.csr" -out "$CL/$NAME.crt"
rm -f "$CL/$NAME.csr" "$CL/$NAME.ext"

# shellcheck disable=SC2086
openssl pkcs12 -export -out "$CL/$NAME.p12" -inkey "$CL/$NAME.key" \
  -in "$CL/$NAME.crt" -certfile ca.crt $P12OUT

echo "----- Certificat client : $CL/$NAME.crt"
openssl x509 -in "$CL/$NAME.crt" -noout -subject -issuer -serial -dates -fingerprint -sha256
echo "Fichier à importer dans Windows : $CL/$NAME.p12"
