#!/usr/bin/env bash
# Émet le certificat du serveur Nginx.
# Usage : pki/issue-server.sh [FQDN] [IP]      (ex. odoo-mfa-server 192.168.1.50)
# Variable optionnelle : CA_PASS pour éviter la question de la passphrase.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FQDN="${1:-odoo-mfa-server}"
IP="${2:-$(hostname -I | awk '{print $1}')}"
PASSIN=${CA_PASS:+-passin env:CA_PASS}
cd "$ROOT/pki/ca"

openssl genrsa -out ../server/server.key 2048
chmod 600 ../server/server.key
openssl req -new -key ../server/server.key -out ../server/server.csr \
  -subj "/C=TN/O=Odoo MFA Lab/OU=Servers/CN=$FQDN"
cat > ../server/server.ext <<EXT
[v3_server]
basicConstraints = CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = DNS:$FQDN,IP:$IP
EXT
# shellcheck disable=SC2086
openssl ca -config openssl-ca.cnf -batch -notext -days 365 $PASSIN \
  -extfile ../server/server.ext -extensions v3_server \
  -in ../server/server.csr -out ../server/server.crt
rm -f ../server/server.csr ../server/server.ext
echo "Certificat serveur émis pour $FQDN / $IP"
