#!/usr/bin/env bash
# Initialise la base odoo_mfa avec le TOTP natif et le module odoo_mfa_certificate.
# Exécution : depuis /opt/odoo-mfa  ->  ./deploy/30-init-odoo.sh
set -euo pipefail
podman exec odoo odoo -c /etc/odoo/odoo.conf -d odoo_mfa \
  -i base,auth_totp,odoo_mfa_certificate --without-demo=all --stop-after-init --no-http
podman restart odoo
echo "Base initialisée. Connexion initiale : admin / admin -> à changer immédiatement."
