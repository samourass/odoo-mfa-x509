#!/usr/bin/env bash
# Prérequis RHEL 9 : Podman, Nginx, OpenSSL, pare-feu, SELinux.
# Exécution : sudo ./deploy/00-prereqs-rhel.sh   (depuis /opt/odoo-mfa)
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "Lancez avec sudo."; exit 1; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

dnf install -y podman nginx openssl firewalld policycoreutils-python-utils chrony vim curl
systemctl enable --now firewalld chronyd

firewall-cmd --permanent --add-service=ssh --add-service=http --add-service=https
firewall-cmd --reload

# Nginx doit pouvoir joindre Odoo sur 127.0.0.1:8069 (SELinux reste en Enforcing)
setsebool -P httpd_can_network_connect 1
# Nginx doit pouvoir lire les certificats de la PKI
semanage fcontext -a -t httpd_sys_content_t "$ROOT/pki(/.*)?" || true
restorecon -Rv "$ROOT/pki" || true

getenforce
echo "Prérequis installés."
