#!/usr/bin/env bash
# Lance PostgreSQL et Odoo 18 sous Podman (réseau dédié « odoo-net »).
# Odoo n'est publié que sur 127.0.0.1:8069 : seul Nginx peut l'atteindre.
# Exécution : depuis /opt/odoo-mfa  ->  ./deploy/20-podman.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
source .env

podman network exists odoo-net || podman network create odoo-net

podman run -d --name odoo-db --network odoo-net --restart=always \
  -e POSTGRES_DB=postgres -e POSTGRES_USER=odoo -e POSTGRES_PASSWORD="$DB_PASSWORD" \
  -v odoo-db-data:/var/lib/postgresql/data:Z \
  docker.io/library/postgres:15

echo "[*] Attente de PostgreSQL..."
until podman exec odoo-db pg_isready -U odoo >/dev/null 2>&1; do sleep 2; done

podman run -d --name odoo --network odoo-net --restart=always \
  -p 127.0.0.1:8069:8069 \
  -v "$ROOT/odoo/addons:/mnt/extra-addons:Z" \
  -v "$ROOT/odoo/config/odoo.conf:/etc/odoo/odoo.conf:Z" \
  -v odoo-web-data:/var/lib/odoo:Z \
  docker.io/library/odoo:18.0

podman ps
