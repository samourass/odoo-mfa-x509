# Scénarios de test (T1 à T16)

Les commandes s'exécutent sur la VM, depuis `/opt/odoo-mfa`, sauf mention contraire.
Préparation : un certificat `samar` enregistré pour le compte administrateur (`deploy/50-register-cert.sh`).

## Automatiques

```bash
./tests/run-tests.sh odoo-mfa-server samar --with-revocation   # T1, T2, T4, T8, T14
```

## Niveau Nginx (certificat)

| # | Scénario | Commande ou action | Résultat attendu |
|---|---|---|---|
| T1 | Sans certificat | `curl --resolve odoo-mfa-server:443:127.0.0.1 --cacert pki/ca/ca.crt https://odoo-mfa-server/` | 400 « No required SSL certificate was sent » |
| T2 | Certificat valide | même commande avec `--cert pki/clients/samar.crt --key pki/clients/samar.key` | 303 vers `/odoo` |
| T3 | Chrome (Windows) | ouvrir `https://odoo-mfa-server` | fenêtre de sélection du certificat |
| T8 | Révocation PKI | `pki/revoke.sh test-revocation` puis `openssl verify -crl_check` | erreur 23, puis Nginx 400 « The SSL certificate error » |
| T14 | HTTP vers HTTPS | `curl -I http://odoo-mfa-server/web/login` | 301 vers HTTPS |

Vérification manuelle de la CRL :

```bash
cat pki/ca/ca.crt pki/ca/crl/ca.crl.pem > /tmp/ca-with-crl.pem
openssl verify -CAfile /tmp/ca-with-crl.pem -crl_check pki/clients/test-revocation.crt
```

## Niveau module Odoo

Ouvrir PostgreSQL :

```bash
podman exec -it odoo-db psql -U odoo -d odoo_mfa
```

| # | Scénario | Action | Résultat attendu |
|---|---|---|---|
| T4 | Identité reçue | ouvrir `https://odoo-mfa-server/mfa/certificate/status` | `mtls: true`, `verify: SUCCESS`, sujet, émetteur, série |
| T5 | Enregistrement | `SELECT id, name, user_id, serial_number, state FROM mfa_user_certificate;` | ligne du certificat, état `active` |
| T6 | Suspendu | bouton *Suspend* ou `UPDATE mfa_user_certificate SET state='suspended' WHERE serial_number='…';` | « Certificate status is suspended », 403 |
| T7 | Révoqué (Odoo) | bouton *Revoke* | « Certificate status is revoked » |
| T9 | Valide mais non enregistré | émettre `unknown-user`, ne pas l'enregistrer | « Certificate is not registered in Odoo » |
| T10 | Autre utilisateur | enregistrer ce certificat pour un autre compte, se connecter en `admin` | « Certificate does not belong to this Odoo user », 403 |
| T13 | Date de fin dépassée | `UPDATE mfa_user_certificate SET valid_until='2026-09-30 10:00:00' WHERE serial_number='…';` | « Certificate has expired », 403 |

Journaux Odoo (preuve des refus) :

```bash
podman logs --since 5m odoo 2>&1 | grep -Ei "X509|MFA|login|403"
```

## Niveau authentification

| # | Scénario | Résultat attendu |
|---|---|---|
| T11 | Bon certificat, mauvais mot de passe | « Wrong login/password » ; journal « Login failed » |
| T12 | Bon certificat, bon mot de passe | 303 puis 200, page des applications |
| T15 | TOTP activé, mauvais code | « Verification failed, please double-check the 6-digit code » |
| T16 | Utilisateur sans privilèges | connexion acceptée, interface sans application |

Le TOTP s'active dans *Préférences › Sécurité du compte*. La case « Don't ask again on this device » supprime la demande de code : à laisser décochée pour les démonstrations.

## Tests unitaires du module

```bash
# Dossier : /opt/odoo-mfa (sur la VM)
podman exec odoo odoo -c /etc/odoo/odoo.conf -d odoo_mfa_test \
  -i odoo_mfa_certificate --test-tags /odoo_mfa_certificate --stop-after-init --no-http
```
