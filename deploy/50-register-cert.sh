#!/usr/bin/env bash
# Enregistre un certificat client dans Odoo et le rattache à un compte.
# Usage : ./deploy/50-register-cert.sh NOM_CERT LOGIN_ODOO [NOM_AFFICHE]
# Exemple : ./deploy/50-register-cert.sh samar admin@odoo-mfa.local "Samar Client Certificate"
# Exécution : depuis /opt/odoo-mfa
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:?Usage: $0 NOM_CERT LOGIN_ODOO [NOM_AFFICHE]}"
LOGIN="${2:?Usage: $0 NOM_CERT LOGIN_ODOO [NOM_AFFICHE]}"
LABEL="${3:-$NAME}"
CRT="$ROOT/pki/clients/$NAME.crt"
[ -f "$CRT" ] || { echo "Introuvable : $CRT"; exit 1; }
PEM="$(cat "$CRT")"

podman exec -i odoo odoo shell -c /etc/odoo/odoo.conf -d odoo_mfa --no-http <<PY
user = env['res.users'].search([('login', '=', '$LOGIN')], limit=1)
if not user:
    raise SystemExit('Utilisateur Odoo introuvable : $LOGIN')
rec = env['mfa.user.certificate'].create_from_pem('''$PEM''', user, '$LABEL')
env.cr.commit()
print('Certificat enregistré : id=%s serial=%s utilisateur=%s' % (rec.id, rec.serial_number, user.login))
PY
