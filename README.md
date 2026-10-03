# odoo-mfa-x509

Authentification forte (MFA) pour **Odoo 18** dans le cadre d'un SMSI : **certificat client X.509** (PKI interne, mTLS Nginx) + **mot de passe** + **code TOTP**, avec un module Odoo qui relie chaque certificat à un compte.

> Projet académique : *Mise en place d'un mécanisme d'authentification forte (MFA) conforme aux pratiques de confidentialité dans un SMSI : ERP Open Source (Odoo) avec un module MFA basé sur la certification électronique.*
> Samar Souid · Tek-Up · classe CII-5-J-SSIRF-D · 2026-2027

## Principe

```
Windows (Chrome + certificat .p12) ──HTTPS──► Nginx (mTLS, CA + CRL) ──► Odoo 18 + module MFA ──► PostgreSQL
                                                        ▲
                                             PKI interne (OpenSSL)
```

| Facteur | Catégorie | Contrôlé par |
|---|---|---|
| Certificat client X.509 | Possession (le poste) | Nginx, puis le module `odoo_mfa_certificate` |
| Mot de passe | Connaissance | Odoo (natif) |
| Code TOTP | Possession (le téléphone) | Odoo (`auth_totp`) |

Un certificat valide n'ouvre pas l'accès à lui seul : Odoo vérifie qu'il est **enregistré**, **actif**, **non expiré** et **propriété de l'utilisateur qui se connecte**. Schéma détaillé : [docs/architecture.md](docs/architecture.md).

## Contenu du dépôt

```
odoo-mfa-x509/
├─ odoo/addons/odoo_mfa_certificate/   module Odoo 18 (modèle, contrôleurs, vues, tests)
├─ odoo/config/odoo.conf.template      configuration Odoo (secrets générés au déploiement)
├─ nginx/odoo-mfa.conf.template        frontal TLS + mTLS + en-têtes d'identité
├─ pki/                                CA interne : init, serveur, clients, révocation
├─ deploy/                             scripts 00 à 50 (RHEL, Podman, Odoo, Nginx, enregistrement)
├─ tests/run-tests.sh                  tests automatiques
├─ windows/install-client-cert.ps1     import du certificat côté Windows
└─ docs/                               architecture, tests, ISO 27001, sécurité, présentation (pptx)
```

## Prérequis

- Une VM **RHEL 9** (Red Hat Developer Subscription) avec accès `sudo`, 2 vCPU, 4 Go de RAM.
- Un poste Windows avec Chrome et OpenSSH (`scp`).
- Dépôt cloné dans **`/opt/odoo-mfa`** sur la VM (les scripts s'y positionnent seuls, mais les chemins de la configuration Nginx en dépendent).

## Installation pas à pas

**1. Récupérer le dépôt sur la VM.** *(VM, dossier : /opt)*

```bash
sudo dnf install -y git
sudo git clone https://github.com/<votre-compte>/odoo-mfa-x509.git /opt/odoo-mfa
sudo chown -R "$USER": /opt/odoo-mfa
cd /opt/odoo-mfa
```

**2. Prérequis système.** *(VM, dossier : /opt/odoo-mfa)*

```bash
sudo ./deploy/00-prereqs-rhel.sh
```

**3. PKI interne.** *(VM, dossier : /opt/odoo-mfa)*

```bash
./pki/init-ca.sh                                            # CA racine (notez la passphrase)
./pki/issue-server.sh odoo-mfa-server IP_DE_LA_VM           # certificat du serveur Nginx
./pki/issue-client.sh samar samar@odoo-mfa.local            # certificat client + .p12
```

**4. Secrets, conteneurs, base Odoo.** *(VM, dossier : /opt/odoo-mfa)*

```bash
./deploy/10-env.sh
./deploy/20-podman.sh
./deploy/30-init-odoo.sh
```

**5. Nginx en mTLS.** *(VM, dossier : /opt/odoo-mfa)*

```bash
sudo ./deploy/40-nginx.sh odoo-mfa-server
```

**6. Enregistrer le certificat pour un compte Odoo.** *(VM, dossier : /opt/odoo-mfa)*

```bash
./deploy/50-register-cert.sh samar admin "Samar Client Certificate"
```

Odoo ne contient au départ que le compte `admin` (mot de passe `admin`). Changez ce mot de passe dès la première connexion. Le login utilisé à l'étape 6 doit être celui du compte (par exemple `admin`).

**7. Certificat sur le poste Windows.** *(PowerShell, dossier : le dépôt cloné sur Windows)*

```powershell
.\windows\install-client-cert.ps1 -VmUser USER -VmIp IP_DE_LA_VM -ClientName samar
```

**8. Activer le TOTP.** Ouvrez `https://odoo-mfa-server`, choisissez le certificat `samar`, connectez-vous, puis *Préférences › Sécurité du compte › Activer l'authentification à deux facteurs*.

## Tests

*(VM, dossier : /opt/odoo-mfa)*

```bash
./tests/run-tests.sh odoo-mfa-server samar --with-revocation
```

Les 16 scénarios (certificat absent, révoqué, suspendu, expiré, inconnu, d'un autre utilisateur, mauvais mot de passe, mauvais code TOTP…) sont décrits dans [docs/tests.md](docs/tests.md). Correspondance avec ISO/IEC 27001:2022 : [docs/iso27001.md](docs/iso27001.md).

## Sécurité

À lire avant toute réutilisation : [docs/security-notes.md](docs/security-notes.md). Points clés :

- Odoo n'est publié que sur `127.0.0.1` et Nginx réécrit les en-têtes `X-SSL-Client-*` ; sans cela, l'identité du certificat pourrait être falsifiée.
- Ne versionnez jamais `.env`, `odoo.conf`, les clés (`*.key`), les `.p12` ni la CA : le `.gitignore` les exclut.
- Le TOTP reste facultatif par utilisateur dans Odoo Community.

## Dépannage

| Symptôme | Piste |
|---|---|
| Nginx : `502 Bad Gateway` | SELinux : `sudo setsebool -P httpd_can_network_connect 1` ; vérifier `podman ps` |
| Nginx ne démarre pas, erreur sur un fichier de la PKI | `sudo restorecon -Rv /opt/odoo-mfa/pki` ; vérifier les chemins avec `sudo nginx -t` |
| Erreur 400 dans le navigateur | certificat non importé ou révoqué ; fermer puis rouvrir Chrome |
| Code TOTP refusé | synchroniser l'heure : `chronyc tracking` (VM) et l'heure du téléphone |
| Après une révocation, le certificat passe encore | `sudo systemctl reload nginx` (la CRL est relue au rechargement) |

## Licence

[MIT](LICENSE)
