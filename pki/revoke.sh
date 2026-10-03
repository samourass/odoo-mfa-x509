#!/usr/bin/env bash
# Révoque un certificat client, régénère la CRL et recharge Nginx.
# Usage : pki/revoke.sh NOM
# Variable optionnelle : CA_PASS
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:?Usage: $0 NOM}"
PASSIN=${CA_PASS:+-passin env:CA_PASS}
cd "$ROOT/pki/ca"
# shellcheck disable=SC2086
openssl ca -config openssl-ca.cnf $PASSIN -revoke "$ROOT/pki/clients/$NAME.crt" -crl_reason keyCompromise
# shellcheck disable=SC2086
openssl ca -config openssl-ca.cnf $PASSIN -gencrl -out crl/ca.crl.pem
sudo systemctl reload nginx
echo "Certificat '$NAME' révoqué dans la PKI : la CRL est rechargée par Nginx."
echo "Pensez aussi à passer l'état à « Revoked » dans Odoo si nécessaire."
