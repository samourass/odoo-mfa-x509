#!/usr/bin/env bash
# Installe la configuration Nginx (mTLS) à partir du modèle.
# Exécution : sudo ./deploy/40-nginx.sh [NOM_SERVEUR]   (depuis /opt/odoo-mfa)
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "Lancez avec sudo."; exit 1; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVER_NAME="${1:-odoo-mfa-server}"
for f in pki/server/server.crt pki/server/server.key pki/ca/ca.crt pki/ca/crl/ca.crl.pem; do
  [ -f "$ROOT/$f" ] || { echo "Manquant : $f (exécutez d'abord pki/init-ca.sh et pki/issue-server.sh)"; exit 1; }
done
sed -e "s|__ROOT__|$ROOT|g" -e "s|__SERVER_NAME__|$SERVER_NAME|g" \
  "$ROOT/nginx/odoo-mfa.conf.template" > /etc/nginx/conf.d/odoo-mfa.conf
nginx -t
systemctl enable --now nginx
systemctl reload nginx
echo "Nginx configuré pour $SERVER_NAME."
