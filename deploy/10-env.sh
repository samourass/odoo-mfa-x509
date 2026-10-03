#!/usr/bin/env bash
# Génère .env et odoo/config/odoo.conf avec des secrets aléatoires.
# Exécution : depuis /opt/odoo-mfa  ->  ./deploy/10-env.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [ ! -f .env ]; then
  umask 077
  {
    echo "DB_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')"
    echo "ADMIN_PASSWD=$(openssl rand -base64 24 | tr -d '/+=')"
  } > .env
  echo "[*] .env créé"
fi
# shellcheck disable=SC1091
source .env
sed -e "s|__DB_PASSWORD__|$DB_PASSWORD|" -e "s|__ADMIN_PASSWD__|$ADMIN_PASSWD|" \
  odoo/config/odoo.conf.template > odoo/config/odoo.conf
chmod 600 odoo/config/odoo.conf
echo "[*] odoo/config/odoo.conf généré"
