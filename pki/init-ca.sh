#!/usr/bin/env bash
# Crée la CA racine interne et une CRL initiale.
# Dossier d'exécution : n'importe lequel (le script se positionne tout seul).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKI="$ROOT/pki"
mkdir -p "$PKI/ca/newcerts" "$PKI/ca/crl" "$PKI/server" "$PKI/clients"
cp -n "$PKI/openssl-ca.cnf" "$PKI/ca/openssl-ca.cnf"
cd "$PKI/ca"
[ -f ca.key ] && { echo "CA déjà existante : $PKI/ca/ca.key. Abandon."; exit 1; }
touch index.txt
echo 1000 > serial
echo 1000 > crlnumber

echo "[*] Clé privée de la CA (choisissez une passphrase forte et notez-la)"
# CA_PASS (optionnel) évite la question interactive.
PASSOUT=${CA_PASS:+-passout env:CA_PASS}
PASSIN=${CA_PASS:+-passin env:CA_PASS}
# shellcheck disable=SC2086
openssl genrsa -aes256 $PASSOUT -out ca.key 4096
chmod 400 ca.key
# shellcheck disable=SC2086
openssl req -x509 -new -config openssl-ca.cnf -key ca.key $PASSIN -sha256 -days 1825 \
  -out ca.crt -subj "/C=TN/O=Odoo MFA Lab/OU=PKI/CN=Odoo MFA Root CA"

echo "[*] CRL initiale"
# shellcheck disable=SC2086
openssl ca -config openssl-ca.cnf $PASSIN -gencrl -out crl/ca.crl.pem
echo "CA prête : $PKI/ca/ca.crt (la clé ca.key ne doit jamais quitter cette machine)"
