#!/usr/bin/env bash
# Tests automatiques (T1, T2, T4, T14 + T8 optionnel).
# Usage : ./tests/run-tests.sh [SERVEUR] [CLIENT] [--with-revocation]
# Exécution : depuis /opt/odoo-mfa
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${1:-odoo-mfa-server}"
CLIENT="${2:-samar}"
REV="${3:-}"
CA="$ROOT/pki/ca/ca.crt"
CRT="$ROOT/pki/clients/$CLIENT.crt"
KEY="$ROOT/pki/clients/$CLIENT.key"
R="--resolve $HOST:443:127.0.0.1"
ok=0; ko=0
check() { if [ "$2" = "$3" ]; then echo "[OK]   $1 ($3)"; ok=$((ok+1)); else echo "[FAIL] $1 : attendu $2, obtenu $3"; ko=$((ko+1)); fi; }

code=$(curl -s -o /dev/null -w '%{http_code}' --cacert "$CA" $R "https://$HOST/")
check "T1  Sans certificat client -> refus Nginx" 400 "$code"

code=$(curl -s -o /dev/null -w '%{http_code}' --cacert "$CA" $R --cert "$CRT" --key "$KEY" "https://$HOST/")
check "T2  Certificat valide -> accepté par Nginx" 303 "$code"

body=$(curl -s --cacert "$CA" $R --cert "$CRT" --key "$KEY" "https://$HOST/mfa/certificate/status")
if echo "$body" | grep -q '"verify": "SUCCESS"'; then check "T4  Identité X.509 reçue par Odoo" ok ok; else check "T4  Identité X.509 reçue par Odoo" ok "$body"; fi

code=$(curl -s -o /dev/null -w '%{http_code}' --resolve "$HOST:80:127.0.0.1" "http://$HOST/web/login")
check "T14 HTTP -> HTTPS" 301 "$code"

if [ "$REV" = "--with-revocation" ]; then
  read -r -s -p "Passphrase de la CA : " CA_PASS; echo; export CA_PASS P12_PASS=test
  "$ROOT/pki/issue-client.sh" test-revocation-auto test@odoo-mfa.local >/dev/null 2>&1
  T="$ROOT/pki/clients/test-revocation-auto"
  code=$(curl -s -o /dev/null -w '%{http_code}' --cacert "$CA" $R --cert "$T.crt" --key "$T.key" "https://$HOST/")
  check "T8a Certificat de test valide avant révocation" 303 "$code"
  "$ROOT/pki/revoke.sh" test-revocation-auto >/dev/null 2>&1
  code=$(curl -s -o /dev/null -w '%{http_code}' --cacert "$CA" $R --cert "$T.crt" --key "$T.key" "https://$HOST/")
  check "T8b Certificat révoqué (CRL) -> refus Nginx" 400 "$code"
fi

echo "----- Résultat : $ok OK / $ko échec(s)"
echo "Scénarios T5 à T16 : voir docs/tests.md"
[ "$ko" -eq 0 ]
